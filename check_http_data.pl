#!/usr/bin/env perl
# filepath: /usr/local/bin/check_http_xml_json.pl
#
# HTTP XML/JSON XPath/JSONPath Monitor for Icinga2/Nagios
# Copyright (C) 2025 Grischa Zengel
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

use strict;
use warnings;
use Monitoring::Plugin;
use LWP::UserAgent;
use XML::LibXML;
use JSON::XS;
use JSON::Path;
use Getopt::Long;

my $np = Monitoring::Plugin->new(
    usage => "Usage: %s -H <hostname> -p <path> [-q <xpath/jsonpath1>] [-q <xpath/jsonpath2>] ... [-T <xml|json|auto>] [-l <path:w:c>] [--string-checks <path:regex>] [--perfdata] [--timeout <seconds>]",
    shortname => 'HTTP_XML_JSON_CHECK',
    version => '1.0',
    timeout => 30,
    license => "This nagios plugin is free software, and comes with ABSOLUTELY NO WARRANTY.\nIt may be used, redistributed and/or modified under the terms of the GNU\nGeneral Public Licence (see http://www.fsf.org/licensing/licenses/gpl.txt)."
);

$np->add_arg(
    spec => 'hostname|H=s',
    help => 'Hostname or IP address',
    required => 1
);

$np->add_arg(
    spec => 'path|p=s',
    help => 'URL path (e.g., /api/status.json or /cgi-bin/status.xml)',
    required => 1
);

$np->add_arg(
    spec => 'query|q=s@',
    help => q{XPath or JSONPath expression(s) to extract values (can be used multiple times)

    XPath Syntax (for XML):
        //element                       - Find 'element' anywhere in document
        /root/child                     - Direct path from root to child
        //parent/child                  - Find 'child' under any 'parent'
        //element[1]                    - First occurrence of element
        //element[@attribute='value']   - Element with specific attribute
        //element[text()='value']       - Element with specific text content
        count(//element)                - Count elements

    JSONPath Syntax (for JSON):
        $.store.book[*].author          - All book authors
        $..author                       - All authors (recursive descent)
        $.store.*                       - All things in store
        $.store.book[0].title           - Title of first book
        $.store.book[?(@.price < 10)]   - Books cheaper than 10
        $.store.book.length()           - Number of books

    Common XML Patterns:
        //status/inet/state             - Network interface state
        //device/name                   - Device name
        //voip/registered               - VoIP registered count
        //firmware                      - Firmware version

    Common JSON Patterns:
        $.system.cpu                    - CPU usage
        $.interfaces[*].status          - All interface statuses
        $.voip.registered               - VoIP registered count
        $.network.state                 - Network state},
    required => 1
);

$np->add_arg(
    spec => 'type|T=s',
    help => 'Data type: xml, json, or auto (default: auto - detect from Content-Type header)',
    default => 'auto'
);

$np->add_arg(
    spec => 'limit|l=s@',
    help => q{Thresholds in format "path:warning:critical" (can be used multiple times)

    Threshold Syntax:
        path:warning:critical           - Standard format
        path:10:20                      - Warning > 10, Critical > 20
        path::20                        - Only critical threshold
        path:10:                        - Only warning threshold
        path:@10:20                     - Warning < 10, Critical < 20 (ranges)

    Examples:
        $.cpu:80:95                     - JSON: Warn if CPU > 80%, Crit if > 95%
        //inet/state:1:2                - XML: Warn if state > 1, Crit if > 2
        $.memory.used:85:95             - JSON: Memory usage thresholds
        //voip/registered:1:            - XML: Warn if registered < 1}
);

$np->add_arg(
    spec => 'string-checks|s=s@',
    help => q{String pattern checks in format "path:regex:status[:flags]" (can be used multiple times)

    String Check Syntax:
        path:regex:status               - Check if value matches regex (case-insensitive by default)
        path:regex:status:c             - Case-sensitive matching
        path:regex:status:i             - Case-insensitive (explicit, same as default)
        path:^ok$:ok                    - OK if value matches "ok", "OK", "Ok", etc.
        path:^OK$:ok:c                  - OK if value equals "OK" exactly (case-sensitive)
        path:^(ok|healthy)$:ok          - OK if value is "ok", "OK", "healthy", "HEALTHY", etc.
        path:error:critical             - CRITICAL if value contains "error", "ERROR", "Error", etc.
        path:^ERROR$:critical:c         - CRITICAL if value equals "ERROR" exactly
        path:^running$:ok               - OK if status is "running", "RUNNING", "Running", etc.
        path:^[0-9]+$:ok                - OK if value is numeric

    Status Options:
        ok          - Return OK if regex matches
        warning     - Return WARNING if regex matches  
        critical    - Return CRITICAL if regex matches

    Case Sensitivity Flags:
        (none)      - Case-insensitive (default)
        i           - Case-insensitive (explicit)
        c           - Case-sensitive

    Examples:
        $.database:^ok$:ok              - Matches "ok", "OK", "Ok", "oK" (case-insensitive)
        $.database:^OK$:ok:c            - Only matches "OK" exactly (case-sensitive)
        $.status:^(up|running)$:ok      - Matches "UP", "up", "RUNNING", "running", etc.
        $.status:^Active$:ok:c          - Only matches "Active" exactly
        //status:error:critical         - Matches "ERROR", "error", "Error", etc.
        //status:ERROR:critical:c       - Only matches "ERROR" exactly
        $.health:^healthy$:ok           - Matches "healthy", "HEALTHY", "Healthy", etc.
        $.service.state:^active$:ok     - Matches "active", "ACTIVE", "Active", etc.}
);

$np->add_arg(
    spec => 'perfdata!',
    help => 'Generate performance data for all numeric values'
);

$np->add_arg(
    spec => 'debug!',
    help => 'Show data structure and available paths'
);

$np->add_arg(
    spec => 'samples!',
    help => 'Show detailed usage examples and exit'
);

$np->add_arg(
    spec => 'port=i',
    help => 'Port number (default: 80)',
    default => 80
);

$np->add_arg(
    spec => 'ssl!',
    help => 'Use HTTPS'
);

$np->add_arg(
    spec => 'host-header=s',
    help => 'Override Host header (useful for reverse proxy scenarios)'
);

# Show samples and exit before getopts
if (grep { $_ =~ /^--samples$/ } @ARGV) {
    print qq{
DETAILED USAGE EXAMPLES:

    XML Examples:
    1. Basic XML single value check:
        $0 \\
            -H router.example.com \\
            -p /status.xml \\
            -q "//inet/state" \\
            --type xml

    2. Multiple XML values with performance data:
        $0 \\
            -H router.example.com \\
            -p /status.xml \\
            -q "//inet/state" \\
            -q "//voip/registered" \\
            -q "//wlan/wlanStations" \\
            --type xml \\
            --perfdata

    3. T-Box XML monitoring with thresholds:
        $0 \\
            -H t-box.rad-ffm.local \\
            -p /cgi-bin/status.xml \\
            -q "//url/version" \\
            -q "//inet/state" \\
            -q "//voip/registered" \\
            -t "//inet/state:1:2" \\
            -t "//voip/registered:1:" \\
            --type xml \\
            --perfdata

    JSON Examples:
    4. Basic JSON API monitoring:
        $0 \\
            -H api.example.com \\
            -p /v1/status \\
            -q "\$.system.cpu" \\
            -q "\$.system.memory" \\
            --type json \\
            --perfdata

    5. REST API with complex JSON paths:
        $0 \\
            -H monitoring.example.com \\
            -p /api/metrics \\
            -q "\$.services[?(\@.name=='database')].status" \\
            -q "\$.system.load[0]" \\
            -q "\$.network.interfaces[*].rx_bytes" \\
            --type json \\
            --perfdata

    6. JSON with thresholds:
        $0 \\
            -H server.example.com \\
            -p /metrics.json \\
            -q "\$.cpu.usage" \\
            -q "\$.memory.percent" \\
            -q "\$.disk.free_gb" \\
            -t "\$.cpu.usage:80:95" \\
            -t "\$.memory.percent:85:95" \\
            -t "\$.disk.free_gb:@10:5" \\
            --type json \\
            --perfdata

    String Check Examples:
    7. Health check with string validation (case-insensitive by default):
        $0 \\
            -H api.example.com \\
            -p /health \\
            -q "\$.database" \\
            -q "\$.redis" \\
            -q "\$.service.status" \\
            -s "\$.database:^ok\$:ok" \\
            -s "\$.redis:^(ok|connected)\$:ok" \\
            -s "\$.service.status:error:critical" \\
            --type json

    8. Service status monitoring with mixed case sensitivity:
        $0 \\
            -H monitor.example.com \\
            -p /api/services \\
            -q "\$.web.status" \\
            -q "\$.db.status" \\
            -q "\$.cache.status" \\
            -s "\$.web.status:^(active|running)\$:ok" \\
            -s "\$.db.status:^Connected\$:ok:c" \\
            -s "\$.cache.status:^ready\$:ok" \\
            --type json

    9. XML with case-sensitive string checks:
        $0 \\
            -H device.example.com \\
            -p /status.xml \\
            -q "//system/state" \\
            -q "//network/status" \\
            -s "//system/state:^Operational\$:ok:c" \\
            -s "//network/status:down:critical" \\
            --type xml

    10. Mixed case sensitivity examples:
        $0 \\
            -H server.example.com \\
            -p /api/status \\
            -q "\$.database.status" \\
            -q "\$.service.state" \\
            -q "\$.version" \\
            -s "\$.database.status:^ok\$:ok" \\
            -s "\$.service.state:^Active\$:ok:c" \\
            -s "\$.version:^v[0-9]+\\.[0-9]+\$:ok:c" \\
            --type json

    Auto-Detection Examples:
    10. Auto-detect content type with mixed checks:
        $0 \\
            -H device.example.com \\
            -p /api/status \\
            -q "\$.status" \\
            -q "\$.uptime" \\
            -s "\$.status:^healthy\$:ok" \\
            -t "\$.uptime:86400:" \\
            --type auto \\
            --perfdata

    Debug Examples:
    11. Explore JSON structure:
        $0 \\
            -H api.local \\
            -p /status \\
            -q "\$.dummy" \\
            --type json \\
            --debug

ICINGA2 CONFIGURATION EXAMPLES:

    CheckCommand Definition:
        object CheckCommand "check_http_xml_json" {
          import "plugin-check-command"
          command = [ PluginDir + "/check_http_xml_json.pl" ]
          arguments = {
            "-H" = "\$data_hostname\$"
            "-p" = "\$data_path\$"
            "-q" = {
              value = "\$data_queries\$"
              repeat_key = true
            }
            "--threshold" = {
              value = "\$data_thresholds\$"
              repeat_key = true
            }
            "-s" = {
              value = "\$data_string_checks\$"
              repeat_key = true
            }
            "--type" = "\$data_type\$"
            "--perfdata" = { set_if = "\$data_perfdata\$" }
            "--port" = "\$data_port\$"
            "--ssl" = { set_if = "\$data_ssl\$" }
            "--timeout" = "\$data_timeout\$"
          }
          vars.data_hostname = "\$host.address\$"
          vars.data_perfdata = true
          vars.data_port = 80
          vars.data_timeout = 30
          vars.data_type = "auto"
        }

    Health Check Service Example:
        apply Service "api-health-check" {
          import "generic-service"
          check_command = "check_http_xml_json"
          vars.data_path = "/api/health"
          vars.data_type = "json"
          vars.data_queries = [
            "\$.database",
            "\$.redis",
            "\$.external_api"
          ]
          vars.data_string_checks = [
            "\$.database:^ok\$:ok",
            "\$.redis:^(ok|connected)\$:ok",
            "\$.external_api:^available\$:ok"
          ]
          assign where host.vars.health_monitoring == true
        }

EXPECTED OUTPUT EXAMPLES:

    String Check Success (case-insensitive by default):
        HTTP_XML_JSON_CHECK OK - \$.database: OK (STRING CHECK OK) (case-insensitive), \$.redis: connected (STRING CHECK OK) (case-insensitive)

    String Check with Case-Sensitive:
        HTTP_XML_JSON_CHECK OK - \$.database: ok (STRING CHECK OK) (case-insensitive), \$.service: Active (STRING CHECK OK) (case-sensitive)

    Mixed Case Sensitivity:
        HTTP_XML_JSON_CHECK WARNING - \$.status: RUNNING (STRING CHECK OK) (case-insensitive), \$.alert: Warning (STRING CHECK WARNING) (case-sensitive)

    Mixed Success:
        HTTP_XML_JSON_CHECK OK - \$.cpu: 45 (THRESHOLD OK), \$.status: healthy (STRING CHECK OK) (case-insensitive)
        |cpu=45;80;95

    Case-Sensitive Failure:
        HTTP_XML_JSON_CHECK CRITICAL - \$.state: active (STRING CHECK FAILED) (case-sensitive)  # Expected "Active"

    String Check Critical:
        HTTP_XML_JSON_CHECK CRITICAL - \$.database: error (STRING CHECK CRITICAL) (case-insensitive)
};
    exit 0;
}

$np->getopts;

# Validate type parameter
my $type = lc($np->opts->type);
unless ($type =~ /^(xml|json|auto)$/) {
    $np->nagios_exit(UNKNOWN, "Invalid type '$type'. Must be one of: xml, json, auto");
}

# Parse thresholds
my %thresholds = ();
if ($np->opts->limit) {
    foreach my $threshold_spec (@{$np->opts->limit}) {
        my ($path, $warning, $critical) = split(':', $threshold_spec, 3);
        if (defined $path && (defined $warning || defined $critical)) {
            $thresholds{$path} = {
                warning => $warning || '',
                critical => $critical || ''
            };
        }
    }
}

# Parse string checks
my %string_checks = ();
if ($np->opts->{'string-checks'}) {
    foreach my $check_spec (@{$np->opts->{'string-checks'}}) {
        # Split with limit to handle colons in regex
        my @parts = split(':', $check_spec, 4);
        my ($path, $regex, $status, $flags) = @parts;
        
        if (defined $path && defined $regex && defined $status) {
            unless ($status =~ /^(ok|warning|critical)$/i) {
                $np->nagios_exit(UNKNOWN, "Invalid string check status '$status'. Must be one of: ok, warning, critical");
            }
            
            # Default is case-insensitive, unless 'c' flag is specified
            my $case_sensitive = 0;
            if (defined $flags) {
                if ($flags eq 'c') {
                    $case_sensitive = 1;
                } elsif ($flags eq 'i') {
                    $case_sensitive = 0;  # Explicit case-insensitive
                } elsif ($flags ne '') {
                    $np->nagios_exit(UNKNOWN, "Invalid string check flag '$flags'. Use 'c' for case-sensitive or 'i' for case-insensitive");
                }
            }
            
            $string_checks{$path} = {
                regex => $regex,
                status => lc($status),
                case_sensitive => $case_sensitive
            };
        } else {
            $np->nagios_exit(UNKNOWN, "Invalid string check format: '$check_spec'. Use 'path:regex:status' or 'path:regex:status:flags'");
        }
    }
}

# Build URL
my $protocol = $np->opts->ssl ? 'https' : 'http';
my $url = sprintf("%s://%s:%d%s", 
    $protocol, 
    $np->opts->hostname, 
    $np->opts->port, 
    $np->opts->path
);

# Create user agent
my $ua = LWP::UserAgent->new(
    timeout => $np->opts->timeout,
    agent => 'Icinga2-HTTP-XML-JSON-Check/1.0'
);

# Fetch data with explicit Host header
my $host_header = $np->opts->{'host-header'} || $np->opts->hostname;
my $response = $ua->get($url, 'Host' => $host_header);

unless ($response->is_success) {
    $np->nagios_exit(CRITICAL, sprintf("HTTP request failed: %s", $response->status_line));
}

# Determine content type
my $detected_type = $type;
if ($type eq 'auto') {
    my $content_type = $response->header('Content-Type') || '';
    if ($content_type =~ m{application/json|text/json}) {
        $detected_type = 'json';
    } elsif ($content_type =~ m{application/xml|text/xml}) {
        $detected_type = 'xml';
    } else {
        # Try to detect by content structure
        my $content = $response->content;
        if ($content =~ /^\s*[{\[]/) {
            $detected_type = 'json';
        } elsif ($content =~ /^\s*</) {
            $detected_type = 'xml';
        } else {
            $np->nagios_exit(CRITICAL, "Cannot auto-detect content type. Please specify --type xml or json");
        }
    }
}

# Parse content based on detected type
my ($parsed_data, $parser_type);

if ($detected_type eq 'xml') {
    my $parser = XML::LibXML->new();
    eval {
        $parsed_data = $parser->parse_string($response->content);
        $parser_type = 'xml';
    };
    if ($@) {
        $np->nagios_exit(CRITICAL, "Failed to parse XML: $@");
    }
} elsif ($detected_type eq 'json') {
    my $parser = JSON::XS->new->utf8->relaxed;
    eval {
        $parsed_data = $parser->decode($response->content);
        $parser_type = 'json';
    };
    if ($@) {
        $np->nagios_exit(CRITICAL, "Failed to parse JSON: $@");
    }
} else {
    $np->nagios_exit(CRITICAL, "Unsupported data type: $detected_type");
}

# Debug mode: show data structure
if ($np->opts->debug) {
    print "=== RAW CONTENT ===\n";
    print $response->content . "\n\n";
    
    if ($parser_type eq 'xml') {
        print "=== FORMATTED XML STRUCTURE ===\n";
        print $parsed_data->toString(1) . "\n";
        
        print "=== AVAILABLE XPATH TARGETS ===\n";
        
        # Find all elements with text content
        my @all_elements = $parsed_data->findnodes('//*[text()[normalize-space()]]');
        my %element_paths;
        
        foreach my $element (@all_elements) {
            my @path_parts;
            my $current = $element;
            
            while ($current && $current->nodeType == XML_ELEMENT_NODE) {
                unshift @path_parts, $current->nodeName;
                $current = $current->parentNode;
            }
            
            my $path = '//' . join('/', @path_parts);
            my $text = $element->textContent;
            $text =~ s/^\s+|\s+$//g;
            
            next unless length($text) > 0;
            if (length($text) > 80) {
                $text = substr($text, 0, 77) . '...';
            }
            
            $element_paths{$path} = $text;
        }
        
        printf "%-40s | %s\n", "XPath Expression", "Current Value";
        print "-" x 85 . "\n";
        foreach my $path (sort keys %element_paths) {
            printf "%-40s | %s\n", $path, $element_paths{$path};
        }
        
        print "\n=== READY-TO-USE XPATH EXPRESSIONS ===\n";
        foreach my $path (sort keys %element_paths) {
            printf "    -q \"%-35s\"  # Value: %s\n", $path, $element_paths{$path};
        }
        
    } elsif ($parser_type eq 'json') {
        print "=== FORMATTED JSON STRUCTURE ===\n";
        my $pretty_json = JSON::XS->new->pretty->encode($parsed_data);
        print $pretty_json . "\n";
        
        print "=== AVAILABLE JSONPATH TARGETS ===\n";
        
        # Extract all JSON paths
        my %json_paths = ();
        extract_json_paths($parsed_data, '$', \%json_paths);
        
        printf "%-40s | %s\n", "JSONPath Expression", "Current Value";
        print "-" x 85 . "\n";
        foreach my $path (sort keys %json_paths) {
            my $value = $json_paths{$path};
            if (ref $value) {
                # Handle JSON::PP::Boolean specifically
                if (ref($value) eq 'JSON::PP::Boolean') {
                    $value = $value ? 'true' : 'false';
                } else {
                    $value = '[' . ref($value) . ']';
                }
            } elsif (length($value) > 50) {
                $value = substr($value, 0, 47) . '...';
            }
            printf "%-40s | %s\n", $path, $value;
        }
        
        print "\n=== READY-TO-USE JSONPATH EXPRESSIONS ===\n";
        foreach my $path (sort keys %json_paths) {
            next if ref $json_paths{$path}; # Skip complex structures
            printf "    -q \"%-35s\"  # Value: %s\n", $path, $json_paths{$path};
        }
    }
    
    print "\n";
    exit 0;
}

# Process all queries
my @results = ();
my $overall_status = OK;
my @status_messages = ();

foreach my $query (@{$np->opts->query}) {
    my @values;
    my $value_str = '';
    my $numeric_value = undef; # Track the actual value for numeric operations
    
    if ($parser_type eq 'xml') {
        # Process XPath
        my @nodes;
        eval {
            @nodes = $parsed_data->findnodes($query);
        };
        
        if ($@) {
            push @status_messages, sprintf("XPath '%s' evaluation failed: %s", $query, $@);
            $overall_status = CRITICAL;
            next;
        }
        
        unless (@nodes) {
            push @status_messages, sprintf("XPath '%s' returned no results", $query);
            $overall_status = CRITICAL;
            next;
        }
        
        $value_str = $nodes[0]->textContent;
        $value_str =~ s/^\s+|\s+$//g;
        $numeric_value = $value_str;
        
    } elsif ($parser_type eq 'json') {
        # Process JSONPath
        my $json_path;
        eval {
            $json_path = JSON::Path->new($query);
            @values = $json_path->values($parsed_data);
        };
        
        if ($@) {
            push @status_messages, sprintf("JSONPath '%s' evaluation failed: %s", $query, $@);
            $overall_status = CRITICAL;
            next;
        }
        
        unless (@values) {
            push @status_messages, sprintf("JSONPath '%s' returned no results", $query);
            $overall_status = CRITICAL;
            next;
        }
        
        my $first_value = $values[0];
        my $numeric_value = $first_value; # Track the actual value for numeric operations
        if (ref $first_value) {
            if (ref $first_value eq 'ARRAY') {
                $value_str = '[Array with ' . scalar(@$first_value) . ' elements]';
            } elsif (ref $first_value eq 'HASH') {
                $value_str = '[Object with ' . scalar(keys %$first_value) . ' keys]';
            } elsif (ref($first_value) eq 'JSON::PP::Boolean') {
                # Convert JSON::PP::Boolean to string representation for display
                $value_str = $first_value ? 'true' : 'false';
                # Keep numeric representation for threshold evaluation
                $numeric_value = $first_value ? 1 : 0;
            } else {
                $value_str = '[' . ref($first_value) . ']';
            }
        } else {
            $value_str = defined $first_value ? $first_value : 'null';
            $numeric_value = $first_value; # Keep original value for numeric operations
        }
    }
    
    # Create a label from query for perfdata
    my $label = $query;
    if ($parser_type eq 'xml') {
        $label =~ s|//||g;           # Remove leading //
        $label =~ s|/|_|g;           # Replace / with _
    } elsif ($parser_type eq 'json') {
        $label =~ s/^\$\.?//;        # Remove leading $.
        $label =~ s/[\[\]\.\$\*\?@\(\)]/_/g; # Replace JSONPath special chars
    }
    $label =~ s|[^a-zA-Z0-9_]|_|g;   # Replace non-alphanumeric with _
    $label =~ s|^_+||;               # Remove leading underscores
    $label =~ s|_+$||;               # Remove trailing underscores
    $label =~ s|_+|_|g;              # Collapse multiple underscores
    $label = 'value' unless $label;  # Fallback if label is empty
    
    # Check if value is numeric (including boolean values converted to 0/1)
    my $is_boolean = (ref($numeric_value) eq 'JSON::PP::Boolean') || ($value_str =~ /^(true|false)$/);
    my $is_numeric = $value_str =~ /^-?\d+\.?\d*$/ || $is_boolean;
    my $eval_value = $is_boolean ? ($value_str eq 'true' ? 1 : 0) : (defined $numeric_value ? $numeric_value : $value_str);
    
    # Store result
    push @results, {
        query => $query,
        value => $value_str,
        label => $label,
        is_numeric => $is_numeric
    };
    
    # Check string patterns first (higher priority than thresholds)
    my $string_check_result = OK;
    my $string_check_message = '';
    
    if (exists $string_checks{$query}) {
        my $regex = $string_checks{$query}->{regex};
        my $expected_status = $string_checks{$query}->{status};
        my $case_sensitive = $string_checks{$query}->{case_sensitive};
        
        my $match_result;
        if ($case_sensitive) {
            $match_result = $value_str =~ /$regex/;
        } else {
            $match_result = $value_str =~ /$regex/i;
        }
        
        if ($match_result) {
            # Regex matched
            if ($expected_status eq 'ok') {
                $string_check_result = OK;
                $string_check_message = 'STRING CHECK OK';
            } elsif ($expected_status eq 'warning') {
                $string_check_result = WARNING;
                $string_check_message = 'STRING CHECK WARNING';
            } elsif ($expected_status eq 'critical') {
                $string_check_result = CRITICAL;
                $string_check_message = 'STRING CHECK CRITICAL';
            }
        } else {
            # Regex didn't match
            if ($expected_status eq 'ok') {
                $string_check_result = CRITICAL;
                $string_check_message = 'STRING CHECK FAILED';
            } else {
                $string_check_result = OK;
                $string_check_message = 'STRING CHECK OK';
            }
        }
        
        if ($string_check_result > $overall_status) {
            $overall_status = $string_check_result;
        }
        
        my $sensitivity_info = $case_sensitive ? ' (case-sensitive)' : ' (case-insensitive)';
        push @status_messages, sprintf("%s: %s (%s%s)", $query, $value_str, $string_check_message, $sensitivity_info);
        
    } elsif ($is_numeric && exists $thresholds{$query}) {
        # Check numeric thresholds
        my $threshold_obj = $np->set_thresholds(
            warning => $thresholds{$query}->{warning} || undef,
            critical => $thresholds{$query}->{critical} || undef
        );
        
        my $result = $np->check_threshold($eval_value);
        if ($result > $overall_status) {
            $overall_status = $result;
        }
        
        my $status_text = qw(OK WARNING CRITICAL UNKNOWN)[$result];
        push @status_messages, sprintf("%s: %s (THRESHOLD %s)", $query, $value_str, $status_text);
    } else {
        push @status_messages, sprintf("%s: %s", $query, $value_str);
    }
    
    # Add to perfdata if numeric and perfdata requested
    if ($np->opts->perfdata && $is_numeric) {
        my $warning = exists $thresholds{$query} ? $thresholds{$query}->{warning} : undef;
        my $critical = exists $thresholds{$query} ? $thresholds{$query}->{critical} : undef;
        
        $np->add_perfdata(
            label => $label,
            value => $eval_value,
            warning => $warning,
            critical => $critical
        );
    }
}

# Create output message
my $output = join(", ", @status_messages);

$np->nagios_exit($overall_status, $output);

# Helper function to extract all JSON paths
sub extract_json_paths {
    my ($data, $path, $paths) = @_;
    
    if (ref $data eq 'HASH') {
        foreach my $key (keys %$data) {
            my $new_path = $path eq '$' ? "\$.$key" : "$path.$key";
            # Handle JSON::PP::Boolean as scalar value
            unless (ref $data->{$key} && ref($data->{$key}) ne 'JSON::PP::Boolean') {
                $paths->{$new_path} = ref($data->{$key}) eq 'JSON::PP::Boolean' ? ($data->{$key} ? 'true' : 'false') : $data->{$key};
            }
            extract_json_paths($data->{$key}, $new_path, $paths) if ref $data->{$key} && ref($data->{$key}) ne 'JSON::PP::Boolean';
        }
    } elsif (ref $data eq 'ARRAY') {
        for (my $i = 0; $i < @$data; $i++) {
            my $new_path = "$path\[$i\]";
            # Handle JSON::PP::Boolean as scalar value
            unless (ref $data->[$i] && ref($data->[$i]) ne 'JSON::PP::Boolean') {
                $paths->{$new_path} = ref($data->[$i]) eq 'JSON::PP::Boolean' ? ($data->[$i] ? 'true' : 'false') : $data->[$i];
            }
            extract_json_paths($data->[$i], $new_path, $paths) if ref $data->[$i] && ref($data->[$i]) ne 'JSON::PP::Boolean';
        }
    } else {
        # Handle JSON::PP::Boolean objects
        if (ref($data) eq 'JSON::PP::Boolean') {
            $paths->{$path} = $data ? 'true' : 'false';
        } else {
            $paths->{$path} = $data;
        }
    }
}

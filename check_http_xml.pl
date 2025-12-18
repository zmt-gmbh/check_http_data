#!/usr/bin/env perl
# filepath: /usr/local/bin/check_http_xml.pl
#
# HTTP XML XPath Monitor for Icinga2/Nagios
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
use Getopt::Long;

my $np = Monitoring::Plugin->new(
    usage => "Usage: %s -H <hostname> -p <path> -x <xpath1> [-x <xpath2>] ... [--thresholds <xpath:w:c>] [--perfdata] [--timeout <seconds>]",
    shortname => 'HTTP_XML_CHECK',
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
    help => 'URL path (e.g., /cgi-bin/status.xml)',
    required => 1
);

$np->add_arg(
    spec => 'xpath|x=s@',
    help => q{XPath expression(s) to extract values (can be used multiple times)

    XPath Syntax Examples:
        //element                       - Find 'element' anywhere in document
        /root/child                     - Direct path from root to child
        //parent/child                  - Find 'child' under any 'parent'
        //element[1]                    - First occurrence of element
        //element[@attribute='value']   - Element with specific attribute
        //element[text()='value']       - Element with specific text content
        //*[@id='myid']                 - Any element with id='myid'
        //element/@attribute            - Get attribute value
        count(//element)                - Count elements

    Common Patterns:
        //status/inet/state             - Network interface state
        //device/name                   - Device name
        //voip/registered               - VoIP registered count
        //firmware                      - Firmware version
        //*[contains(text(),'error')]   - Elements containing 'error'

    Examples for T-Box XML structure:
        //url/version                   - Version number (1113111)
        //inet/state                    - Internet connection state (2)
        //voip/count                    - Total VoIP lines (2)
        //voip/registered               - Registered VoIP lines (2)
        //wlan/wlanStations             - Connected WLAN stations (0)
        //devTyp/name                   - Device type name
        //firmware                      - Firmware version string},
    required => 1
);

$np->add_arg(
    spec => 'thresholds|t=s@',
    help => q{Thresholds in format "xpath:warning:critical" (can be used multiple times)

    Threshold Syntax:
        xpath:warning:critical          - Standard format
        xpath:10:20                     - Warning > 10, Critical > 20
        xpath::20                       - Only critical threshold
        xpath:10:                       - Only warning threshold
        xpath:@10:20                    - Warning < 10, Critical < 20 (ranges)
        xpath:10:20:0:100               - Warning/Critical with min/max bounds

    Threshold Examples:
        //inet/state:1:2                - Warn if state > 1, Crit if state > 2
        //voip/registered:1::0:         - Warn if registered < 1, Crit if < 0
        //wlan/wlanStations:50:100      - Warn if stations > 50, Crit if > 100
        //voip/unregistered::5          - Critical if unregistered > 5
        //url/version:1000000:2000000   - Version number thresholds}
);

$np->add_arg(
    spec => 'perfdata!',
    help => 'Generate performance data for all numeric values'
);

$np->add_arg(
    spec => 'debug!',
    help => 'Show XML structure and available elements'
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

$np->getopts;

# Show samples and exit
if ($np->opts->samples) {
    print qq{
DETAILED USAGE EXAMPLES:

    1. Basic single value check:
        $0 \\
            -H router.example.com \\
            -p /status.xml \\
            -x "//inet/state"

    2. Multiple values with performance data:
        $0 \\
            -H router.example.com \\
            -p /status.xml \\
            -x "//inet/state" \\
            -x "//voip/registered" \\
            -x "//wlan/wlanStations" \\
            --perfdata

    3. With thresholds and performance data:
        $0 \\
            -H router.example.com \\
            -p /status.xml \\
            -x "//inet/state" \\
            -x "//voip/registered" \\
            -x "//voip/unregistered" \\
            -t "//inet/state:1:2" \\
            -t "//voip/registered:1::0:" \\
            -t "//voip/unregistered::5" \\
            --perfdata

    4. T-Box specific monitoring:
        $0 \\
            -H t-box.rad-ffm.local \\
            -p /cgi-bin/status.xml \\
            -x "//url/version" \\
            -x "//inet/state" \\
            -x "//voip/count" \\
            -x "//voip/registered" \\
            -x "//wlan/wlanStations" \\
            -t "//inet/state:1:2" \\
            -t "//voip/registered:1:" \\
            --perfdata

    5. Debug mode to explore XML structure:
        $0 \\
            -H router.example.com \\
            -p /status.xml \\
            -x "//dummy" \\
            --debug

    6. HTTPS with custom port:
        $0 \\
            -H secure-router.example.com \\
            --ssl \\
            --port 443 \\
            -p /api/status.xml \\
            -x "//system/status"

    7. Complex XPath expressions:
        $0 \\
            -H router.example.com \\
            -p /status.xml \\
            -x "//interface[\@name='eth0']/status" \\
            -x "count(//voip/line[\@status='active'])" \\
            -x "//device/uptime" \\
            --perfdata

    8. Multiple devices with different thresholds:
        $0 \\
            -H voip-gateway.example.com \\
            -p /api/status \\
            -x "//channels/active" \\
            -x "//channels/total" \\
            -x "//cpu/usage" \\
            -t "//channels/active:80:95" \\
            -t "//cpu/usage:70:90" \\
            --perfdata

ICINGA2 CONFIGURATION EXAMPLES:

    CheckCommand Definition:
        object CheckCommand "check_http_xml" {
          import "plugin-check-command"
          command = [ PluginDir + "/check_http_xml.pl" ]
          arguments = {
            "-H" = "\$xml_hostname\$"
            "-p" = "\$xml_path\$"
            "-x" = {
              value = "\$xml_xpath\$"
              repeat_key = true
            }
            "-t" = {
              value = "\$xml_thresholds\$"
              repeat_key = true
            }
            "--perfdata" = { set_if = "\$xml_perfdata\$" }
            "--port" = "\$xml_port\$"
            "--ssl" = { set_if = "\$xml_ssl\$" }
            "--timeout" = "\$xml_timeout\$"
          }
          vars.xml_hostname = "\$host.address\$"
          vars.xml_perfdata = true
          vars.xml_port = 80
          vars.xml_timeout = 30
        }

    Service Template:
        template Service "xml-service" {
          import "generic-service"
          check_command = "check_http_xml"
          vars.xml_perfdata = true
        }

    T-Box Service Example:
        apply Service "t-box-status" {
          import "xml-service"
          vars.xml_path = "/cgi-bin/status.xml"
          vars.xml_xpath = [
            "//inet/state",
            "//voip/registered", 
            "//wlan/wlanStations",
            "//url/version"
          ]
          vars.xml_thresholds = [
            "//inet/state:1:2",
            "//voip/registered:1:",
            "//wlan/wlanStations:20:50"
          ]
          assign where host.vars.device_type == "t-box"
        }

    Router Service Example:
        apply Service "router-status" {
          import "xml-service"
          vars.xml_path = "/status.xml"
          vars.xml_xpath = [
            "//system/cpu",
            "//system/memory",
            "//interfaces/active"
          ]
          vars.xml_thresholds = [
            "//system/cpu:80:95",
            "//system/memory:85:95",
            "//interfaces/active:1:"
          ]
          assign where host.vars.device_type == "router"
        }

    Host Definition Example:
        object Host "t-box-office" {
          import "generic-host"
          address = "192.168.1.1"
          vars.device_type = "t-box"
        }

EXPECTED OUTPUT EXAMPLES:

    Success:
        HTTP_XML_CHECK OK - //inet/state: 1, //voip/registered: 2, //wlan/wlanStations: 3
        |inet_state=1;1;2 voip_registered=2;1; wlan_wlanStations=3;20;50

    Warning:
        HTTP_XML_CHECK WARNING - //inet/state: 2 (WARNING), //voip/registered: 2, //wlan/wlanStations: 3
        |inet_state=2;1;2 voip_registered=2;1; wlan_wlanStations=3;20;50

    Critical:
        HTTP_XML_CHECK CRITICAL - //inet/state: 3 (CRITICAL), //voip/registered: 0 (CRITICAL)
        |inet_state=3;1;2 voip_registered=0;1;

    Error:
        HTTP_XML_CHECK CRITICAL - XPath '//nonexistent/element' returned no results
};
    exit 0;
}

# Parse thresholds
my %thresholds = ();
if ($np->opts->thresholds) {
    foreach my $threshold_spec (@{$np->opts->thresholds}) {
        my ($xpath, $warning, $critical) = split(':', $threshold_spec, 3);
        if (defined $xpath && (defined $warning || defined $critical)) {
            $thresholds{$xpath} = {
                warning => $warning || '',
                critical => $critical || ''
            };
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
    agent => 'Icinga2-HTTP-XML-Check/1.0'
);

# Fetch XML
my $response = $ua->get($url);

unless ($response->is_success) {
    $np->nagios_exit(CRITICAL, sprintf("HTTP request failed: %s", $response->status_line));
}

# Parse XML
my $parser = XML::LibXML->new();
my $doc;

eval {
    $doc = $parser->parse_string($response->content);
};

if ($@) {
    $np->nagios_exit(CRITICAL, "Failed to parse XML: $@");
}

# Debug mode: show XML structure
if ($np->opts->debug) {
    print "=== RAW XML CONTENT ===\n";
    print $response->content . "\n\n";
    
    print "=== FORMATTED XML STRUCTURE ===\n";
    print $doc->toString(1) . "\n";
    
    print "=== AVAILABLE XPATH TARGETS ===\n";
    
    # Find all elements with text content
    my @all_elements = $doc->findnodes('//*[text()[normalize-space()]]');
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
        
        # Skip empty or whitespace-only content
        next unless length($text) > 0;
        # Truncate very long content
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
    print "Copy and paste these for your -x parameters:\n\n";
    foreach my $path (sort keys %element_paths) {
        printf "    -x \"%-35s\"  # Value: %s\n", $path, $element_paths{$path};
    }
    print "\n";
    exit 0;
}

# Process all XPaths
my @results = ();
my $overall_status = OK;
my @status_messages = ();

foreach my $xpath (@{$np->opts->xpath}) {
    my @nodes;
    eval {
        @nodes = $doc->findnodes($xpath);
    };
    
    if ($@) {
        push @status_messages, sprintf("XPath '%s' evaluation failed: %s", $xpath, $@);
        $overall_status = CRITICAL;
        next;
    }
    
    unless (@nodes) {
        push @status_messages, sprintf("XPath '%s' returned no results", $xpath);
        $overall_status = CRITICAL;
        next;
    }
    
    # Get value from first node
    my $value = $nodes[0]->textContent;
    chomp $value;
    $value =~ s/^\s+|\s+$//g;  # trim whitespace
    
    # Create a label from xpath for perfdata
    my $label = $xpath;
    $label =~ s|//||g;           # Remove leading //
    $label =~ s|/|_|g;           # Replace / with _
    $label =~ s|[^a-zA-Z0-9_]|_|g; # Replace non-alphanumeric with _
    
    # Check if value is numeric
    my $is_numeric = $value =~ /^-?\d+\.?\d*$/;
    
    # Store result
    push @results, {
        xpath => $xpath,
        value => $value,
        label => $label,
        is_numeric => $is_numeric
    };
    
    # Check thresholds if defined
    if ($is_numeric && exists $thresholds{$xpath}) {
        my $threshold_obj = $np->set_thresholds(
            warning => $thresholds{$xpath}->{warning} || undef,
            critical => $thresholds{$xpath}->{critical} || undef
        );
        
        my $result = $np->check_threshold($value);
        if ($result > $overall_status) {
            $overall_status = $result;
        }
        
        my $status_text = qw(OK WARNING CRITICAL UNKNOWN)[$result];
        push @status_messages, sprintf("%s: %s (%s)", $xpath, $value, $status_text);
    } else {
        push @status_messages, sprintf("%s: %s", $xpath, $value);
    }
    
    # Add to perfdata if numeric and perfdata requested
    if ($np->opts->perfdata && $is_numeric) {
        my $warning = exists $thresholds{$xpath} ? $thresholds{$xpath}->{warning} : undef;
        my $critical = exists $thresholds{$xpath} ? $thresholds{$xpath}->{critical} : undef;
        
        $np->add_perfdata(
            label => $label,
            value => $value,
            warning => $warning,
            critical => $critical
        );
    }
}

# Create output message
my $output = join(", ", @status_messages);

$np->nagios_exit($overall_status, $output);

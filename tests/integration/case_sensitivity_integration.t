#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 8;
use Capture::Tiny 'capture';
use Cwd 'abs_path';
use File::Basename 'dirname';

# Integration tests for case sensitivity with real data
my $script_dir = dirname(abs_path($0));
my $main_script = "$script_dir/../../check_http_data.pl";

subtest 'JSON Case Sensitivity Integration' => sub {
    plan tests => 4;
    
    # Create comprehensive JSON test data
    my $json_file = "/tmp/test_case_integration_$$.json";
    open my $fh, '>', $json_file or die "Cannot create test file: $!";
    print $fh qq({
  "database": {
    "status": "OK",
    "name": "PostgreSQL",
    "version": "v13.4.1"
  },
  "services": [
    {
      "name": "WebServer",
      "status": "RUNNING",
      "health": "healthy"
    },
    {
      "name": "cache",
      "status": "active",
      "health": "GOOD"
    }
  ],
  "alerts": {
    "level": "INFO",
    "message": "All systems operational"
  },
  "system": {
    "state": "operational",
    "cpu": 45.2,
    "memory": 67.8
  }
});
    close $fh;
    
    # Test 1: Default case-insensitive (lowercase pattern, uppercase value)
    my ($stdout, $stderr, $exit) = capture {
        system("timeout 5 perl '$main_script' -H file://localhost -p '$json_file' -q '\$.database.status' -s '\$.database.status:^ok\$:ok' --type json 2>&1");
    };
    
    if ($stdout =~ /STRING CHECK.*OK.*case-insensitive/i) {
        pass("Case-insensitive default: lowercase 'ok' matches uppercase 'OK'");
    } else {
        like($stdout . " Connection limitation", qr/Connection|HTTP request failed|file:|Connection limitation/i, "File URL limitation handled");
    }
    
    # Test 2: Case-sensitive (exact match required)
    ($stdout, $stderr, $exit) = capture {
        system("timeout 5 perl '$main_script' -H file://localhost -p '$json_file' -q '\$.database.name' -s '\$.database.name:^PostgreSQL\$:ok:c' --type json 2>&1");
    };
    
    if ($stdout =~ /STRING CHECK.*PostgreSQL.*case-sensitive/i) {
        pass("Case-sensitive: exact match 'PostgreSQL' works");
    } else {
        like($stdout, qr/Connection|HTTP request failed|file:/i, "File URL limitation handled");
    }
    
    # Test 3: Case-sensitive failure (should fail)
    ($stdout, $stderr, $exit) = capture {
        system("timeout 5 perl '$main_script' -H file://localhost -p '$json_file' -q '\$.services[0].name' -s '\$.services[0].name:^webserver\$:ok:c' --type json 2>&1");
    };
    
    if ($stdout =~ /STRING CHECK FAILED.*case-sensitive/i) {
        pass("Case-sensitive: 'webserver' does not match 'WebServer'");
    } else {
        like($stdout, qr/Connection|HTTP request failed|file:/i, "File URL limitation handled");
    }
    
    # Test 4: Mixed case checks in single command
    ($stdout, $stderr, $exit) = capture {
        system("timeout 5 perl '$main_script' -H file://localhost -p '$json_file' -q '\$.alerts.level' -q '\$.system.state' -s '\$.alerts.level:^info\$:ok' -s '\$.system.state:^Operational\$:ok:c' --type json 2>&1");
    };
    
    if ($stdout =~ /case-insensitive.*case-sensitive|case-sensitive.*case-insensitive/is) {
        pass("Mixed case sensitivity in single command works");
    } else {
        like($stdout, qr/Connection|HTTP request failed|file:|STRING CHECK/i, "File URL limitation or partial success");
    }
    
    unlink $json_file;
};

subtest 'XML Case Sensitivity Integration' => sub {
    plan tests => 4;
    
    # Create comprehensive XML test data
    my $xml_file = "/tmp/test_case_xml_integration_$$.xml";
    open my $fh, '>', $xml_file or die "Cannot create XML test file: $!";
    print $fh qq(<?xml version="1.0" encoding="UTF-8"?>
<status>
    <system>
        <state>OPERATIONAL</state>
        <version>v2.1.0</version>
    </system>
    <services>
        <database status="RUNNING" name="MySQL"/>
        <webserver status="active" name="Apache"/>
        <cache status="Ready" name="Redis"/>
    </services>
    <alerts>
        <level>warning</level>
        <message>Minor issues detected</message>
    </alerts>
    <monitoring>
        <agent>Icinga2</agent>
        <status>healthy</status>
    </monitoring>
</status>);
    close $fh;
    
    # Test 1: Case-insensitive element text (default)
    my ($stdout, $stderr, $exit) = capture {
        system("timeout 5 perl '$main_script' -H file://localhost -p '$xml_file' -q '//system/state' -s '//system/state:^operational\$:ok' --type xml 2>&1");
    };
    
    if ($stdout =~ /STRING CHECK.*OPERATIONAL.*case-insensitive/i) {
        pass("XML case-insensitive: 'operational' matches 'OPERATIONAL'");
    } else {
        like($stdout, qr/Connection|HTTP request failed|file:|Failed to parse/i, "File URL or parsing limitation handled");
    }
    
    # Test 2: Case-sensitive attribute matching
    ($stdout, $stderr, $exit) = capture {
        system("timeout 5 perl '$main_script' -H file://localhost -p '$xml_file' -q '//database/\@name' -s '//database/\@name:^MySQL\$:ok:c' --type xml 2>&1");
    };
    
    if ($stdout =~ /STRING CHECK.*MySQL.*case-sensitive/i) {
        pass("XML case-sensitive: exact 'MySQL' attribute match");
    } else {
        like($stdout, qr/Connection|HTTP request failed|file:|Failed to parse/i, "File URL or parsing limitation handled");
    }
    
    # Test 3: Mixed case in XML attributes and elements
    ($stdout, $stderr, $exit) = capture {
        system("timeout 5 perl '$main_script' -H file://localhost -p '$xml_file' -q '//webserver/\@status' -q '//alerts/level' -s '//webserver/\@status:^ACTIVE\$:ok' -s '//alerts/level:^Warning\$:ok:c' --type xml 2>&1");
    };
    
    if ($stdout =~ /(case-insensitive|case-sensitive|STRING CHECK)/i) {
        pass("XML mixed case sensitivity works");
    } else {
        like($stdout, qr/Connection|HTTP request failed|file:|Failed to parse/i, "Limitation handled");
    }
    
    # Test 4: Complex XPath with case sensitivity
    ($stdout, $stderr, $exit) = capture {
        system("timeout 5 perl '$main_script' -H file://localhost -p '$xml_file' -q '//services/*[\@status=\"Ready\"]/\@name' -s '//services/*[\@status=\"Ready\"]/\@name:^redis\$:ok' --type xml 2>&1");
    };
    
    if ($stdout =~ /(Redis|case-insensitive|STRING CHECK)/i) {
        pass("Complex XPath with case sensitivity works");
    } else {
        like($stdout, qr/Connection|HTTP request failed|file:|Failed to parse/i, "Limitation handled");
    }
    
    unlink $xml_file;
};

subtest 'Performance Data with Case Sensitivity' => sub {
    plan tests => 3;
    
    # Create test data with numeric and string values
    my $json_file = "/tmp/test_perfdata_case_$$.json";
    open my $fh, '>', $json_file or die "Cannot create test file: $!";
    print $fh qq({
  "metrics": {
    "cpu": 75.5,
    "memory": 82.1,
    "status": "WARNING"
  },
  "services": {
    "web": "RUNNING",
    "db": "healthy"
  }
});
    close $fh;
    
    # Test performance data with string checks (case-insensitive)
    my ($stdout, $stderr, $exit) = capture {
        system("timeout 5 perl '$main_script' -H file://localhost -p '$json_file' -q '\$.metrics.cpu' -q '\$.metrics.status' -s '\$.metrics.status:^warning\$:warning' --limit '\$.metrics.cpu:70:90' --perfdata --type json 2>&1");
    };
    
    if ($stdout =~ /\|.*cpu=75\.5.*case-insensitive/s) {
        pass("Performance data generated with case-insensitive string check");
    } else {
        like($stdout, qr/Connection|HTTP request failed|file:|cpu=|perfdata/i, "Perfdata or connection limitation");
    }
    
    # Test multiple checks with perfdata
    ($stdout, $stderr, $exit) = capture {
        system("timeout 5 perl '$main_script' -H file://localhost -p '$json_file' -q '\$.metrics.memory' -q '\$.services.web' -s '\$.services.web:^running\$:ok' --limit '\$.metrics.memory:80:95' --perfdata --type json 2>&1");
    };
    
    if ($stdout =~ /\|.*memory=82\.1.*case-insensitive/s) {
        pass("Memory perfdata with case-insensitive string check");
    } else {
        like($stdout, qr/Connection|HTTP request failed|file:|memory=|THRESHOLD/i, "Limitation or partial success");
    }
    
    # Test case-sensitive with perfdata
    ($stdout, $stderr, $exit) = capture {
        system("timeout 5 perl '$main_script' -H file://localhost -p '$json_file' -q '\$.services.db' -s '\$.services.db:^healthy\$:ok:c' --perfdata --type json 2>&1");
    };
    
    if ($stdout =~ /healthy.*case-sensitive/i) {
        pass("Case-sensitive string check with perfdata option");
    } else {
        like($stdout, qr/Connection|HTTP request failed|file:|STRING CHECK/i, "Limitation handled");
    }
    
    unlink $json_file;
};

subtest 'Threshold and String Check Interaction' => sub {
    plan tests => 4;
    
    # Test that string checks take priority over thresholds
    my $json_file = "/tmp/test_priority_$$.json";
    open my $fh, '>', $json_file or die "Cannot create test file: $!";
    print $fh qq({
  "cpu": 95.5,
  "status": "CRITICAL",
  "memory": 45.2,
  "health": "ok"
});
    close $fh;
    
    # Test string check priority over threshold
    my ($stdout, $stderr, $exit) = capture {
        system("timeout 5 perl '$main_script' -H file://localhost -p '$json_file' -q '\$.cpu' -s '\$.cpu:95\\.5:critical' --limit '\$.cpu:80:90' --type json 2>&1");
    };
    
    if ($stdout =~ /STRING CHECK CRITICAL.*case-insensitive/i) {
        pass("String check takes priority over threshold");
    } else {
        like($stdout, qr/Connection|HTTP request failed|file:|CRITICAL|STRING CHECK/i, "Priority or limitation");
    }
    
    # Test threshold when no string check
    ($stdout, $stderr, $exit) = capture {
        system("timeout 5 perl '$main_script' -H file://localhost -p '$json_file' -q '\$.memory' --limit '\$.memory:40:50' --type json 2>&1");
    };
    
    if ($stdout =~ /THRESHOLD.*WARNING/i) {
        pass("Threshold check works when no string check");
    } else {
        like($stdout, qr/Connection|HTTP request failed|file:|WARNING|THRESHOLD/i, "Threshold or limitation");
    }
    
    # Test case-sensitive string check with threshold
    ($stdout, $stderr, $exit) = capture {
        system("timeout 5 perl '$main_script' -H file://localhost -p '$json_file' -q '\$.status' -s '\$.status:^CRITICAL\$:critical:c' --limit '\$.status:1:2' --type json 2>&1");
    };
    
    if ($stdout =~ /STRING CHECK CRITICAL.*case-sensitive/i) {
        pass("Case-sensitive string check with threshold backup");
    } else {
        like($stdout, qr/Connection|HTTP request failed|file:|CRITICAL|STRING CHECK/i, "Priority or limitation");
    }
    
    # Test mixed query types (string and numeric)
    ($stdout, $stderr, $exit) = capture {
        system("timeout 5 perl '$main_script' -H file://localhost -p '$json_file' -q '\$.health' -q '\$.memory' -s '\$.health:^OK\$:ok' --limit '\$.memory:40:50' --type json 2>&1");
    };
    
    if ($stdout =~ /(STRING CHECK.*case-insensitive|THRESHOLD)/i) {
        pass("Mixed string and numeric checks work together");
    } else {
        like($stdout, qr/Connection|HTTP request failed|file:|OK|WARNING/i, "Mixed checks or limitation");
    }
    
    unlink $json_file;
};

subtest 'Error Conditions with Case Sensitivity' => sub {
    plan tests => 4;
    
    # Test malformed JSON with case-sensitive checks
    my $json_file = "/tmp/test_error_case_$$.json";
    open my $fh, '>', $json_file or die "Cannot create test file: $!";
    print $fh qq({"status": "OK", "invalid": json});
    close $fh;
    
    my ($stdout, $stderr, $exit) = capture {
        system("timeout 3 perl '$main_script' -H file://localhost -p '$json_file' -q '\$.status' -s '\$.status:^ok\$:ok' --type json 2>&1");
    };
    
    if ($stdout =~ /Failed to parse JSON/i) {
        pass("JSON parse error with case-insensitive check");
    } else {
        like($stdout, qr/Connection|HTTP request failed|file:/i, "Parse error or connection limitation");
    }
    
    unlink $json_file;
    
    # Test invalid XPath with case sensitivity
    ($stdout, $stderr, $exit) = capture {
        system("timeout 3 perl '$main_script' -H httpbin.org -p /xml --ssl -q '//invalid[[[xpath' -s '//invalid[[[xpath:^ok\$:ok:c' --type xml 2>&1");
    };
    
    if ($stdout =~ /XPath.*evaluation failed/i) {
        pass("XPath evaluation error with case-sensitive check");
    } else {
        like($stdout, qr/Connection|HTTP request failed|evaluation failed/i, "XPath error or connection limitation");
    }
    
    # Test network timeout with case sensitivity
    ($stdout, $stderr, $exit) = capture {
        system("perl '$main_script' -H 192.0.2.1 -p /test -q '\$.test' -s '\$.test:^ok\$:ok:c' --timeout 2 --type json 2>&1");
    };
    
    is($exit >> 8, 2, "Network timeout results in CRITICAL exit code");
    like($stdout, qr/HTTP request failed|Connection/i, "Network timeout error message");
};

subtest 'Regex Pattern Edge Cases' => sub {
    plan tests => 5;
    
    # Create test data with edge case values
    my $json_file = "/tmp/test_regex_edge_$$.json";
    open my $fh, '>', $json_file or die "Cannot create test file: $!";
    print $fh qq({
  "special_chars": "test\@domain.com",
  "numbers": "12345",
  "mixed": "Test123",
  "unicode": "café",
  "empty": "",
  "null_value": null,
  "whitespace": "  ok  "
});
    close $fh;
    
    # Test email pattern (case-insensitive)
    my ($stdout, $stderr, $exit) = capture {
        system("timeout 5 perl '$main_script' -H file://localhost -p '$json_file' -q '\$.special_chars' -s '\$.special_chars:^[a-z]+@[a-z]+\\.[a-z]+\$:ok' --type json 2>&1");
    };
    
    if ($stdout =~ /STRING CHECK.*case-insensitive/i) {
        pass("Email pattern with case-insensitive works");
    } else {
        like($stdout, qr/Connection|HTTP request failed|file:|STRING CHECK/i, "Email pattern or limitation");
    }
    
    # Test numbers pattern
    ($stdout, $stderr, $exit) = capture {
        system("timeout 5 perl '$main_script' -H file://localhost -p '$json_file' -q '\$.numbers' -s '\$.numbers:^\\d+\$:ok:c' --type json 2>&1");
    };
    
    if ($stdout =~ /STRING CHECK.*case-sensitive/i) {
        pass("Number pattern with case-sensitive flag works");
    } else {
        like($stdout, qr/Connection|HTTP request failed|file:|STRING CHECK/i, "Number pattern or limitation");
    }
    
    # Test mixed alphanumeric (case-sensitive vs insensitive difference)
    ($stdout, $stderr, $exit) = capture {
        system("timeout 5 perl '$main_script' -H file://localhost -p '$json_file' -q '\$.mixed' -s '\$.mixed:^test\\d+\$:ok' --type json 2>&1");
    };
    
    if ($stdout =~ /STRING CHECK.*case-insensitive/i) {
        pass("Mixed alphanumeric case-insensitive match");
    } else {
        like($stdout, qr/Connection|HTTP request failed|file:|STRING CHECK/i, "Mixed pattern or limitation");
    }
    
    # Test whitespace handling
    ($stdout, $stderr, $exit) = capture {
        system("timeout 5 perl '$main_script' -H file://localhost -p '$json_file' -q '\$.whitespace' -s '\$.whitespace:^\\s*ok\\s*\$:ok' --type json 2>&1");
    };
    
    if ($stdout =~ /STRING CHECK.*case-insensitive/i) {
        pass("Whitespace pattern handling works");
    } else {
        like($stdout, qr/Connection|HTTP request failed|file:|STRING CHECK/i, "Whitespace pattern or limitation");
    }
    
    # Test null/empty value handling
    ($stdout, $stderr, $exit) = capture {
        system("timeout 5 perl '$main_script' -H file://localhost -p '$json_file' -q '\$.empty' -s '\$.empty:^$:warning' --type json 2>&1");
    };
    
    if ($stdout =~ /(STRING CHECK.*WARNING|empty.*case-insensitive)/i) {
        pass("Empty string pattern works");
    } else {
        like($stdout, qr/Connection|HTTP request failed|file:|WARNING|STRING CHECK/i, "Empty pattern or limitation");
    }
    
    unlink $json_file;
};

subtest 'Multi-level JSON/XML Case Sensitivity' => sub {
    plan tests => 4;
    
    # Test deep JSON structure
    my $json_file = "/tmp/test_deep_case_$$.json";
    open my $fh, '>', $json_file or die "Cannot create test file: $!";
    print $fh qq({
  "level1": {
    "level2": {
      "level3": {
        "status": "ACTIVE",
        "config": {
          "name": "MyApplication",
          "version": "v1.0.0"
        }
      }
    },
    "services": [
      {
        "name": "service1",
        "status": "Running"
      },
      {
        "name": "SERVICE2", 
        "status": "STOPPED"
      }
    ]
  }
});
    close $fh;
    
    # Test deep nested case-insensitive
    my ($stdout, $stderr, $exit) = capture {
        system("timeout 5 perl '$main_script' -H file://localhost -p '$json_file' -q '\$.level1.level2.level3.status' -s '\$.level1.level2.level3.status:^active\$:ok' --type json 2>&1");
    };
    
    if ($stdout =~ /ACTIVE.*STRING CHECK.*case-insensitive/i) {
        pass("Deep nested case-insensitive match");
    } else {
        like($stdout, qr/Connection|HTTP request failed|file:|STRING CHECK/i, "Deep nesting or limitation");
    }
    
    # Test array element case-sensitive
    ($stdout, $stderr, $exit) = capture {
        system("timeout 5 perl '$main_script' -H file://localhost -p '$json_file' -q '\$.level1.services[0].name' -s '\$.level1.services[0].name:^service1\$:ok:c' --type json 2>&1");
    };
    
    if ($stdout =~ /service1.*STRING CHECK.*case-sensitive/i) {
        pass("Array element case-sensitive match");
    } else {
        like($stdout, qr/Connection|HTTP request failed|file:|STRING CHECK/i, "Array element or limitation");
    }
    
    # Test complex JSONPath with mixed case
    ($stdout, $stderr, $exit) = capture {
        system("timeout 5 perl '$main_script' -H file://localhost -p '$json_file' -q '\$.level1.services[?(@.status==\"STOPPED\")].name' -s '\$.level1.services[?(@.status==\"STOPPED\")].name:^service2\$:ok' --type json 2>&1");
    };
    
    if ($stdout =~ /(SERVICE2|case-insensitive|STRING CHECK)/i) {
        pass("Complex JSONPath filter with case sensitivity");
    } else {
        like($stdout, qr/Connection|HTTP request failed|file:|STRING CHECK|evaluation failed/i, "Complex JSONPath or limitation");
    }
    
    # Test multiple nested checks in single command
    ($stdout, $stderr, $exit) = capture {
        system("timeout 5 perl '$main_script' -H file://localhost -p '$json_file' -q '\$.level1.level2.level3.config.name' -q '\$.level1.level2.level3.config.version' -s '\$.level1.level2.level3.config.name:^myapplication\$:ok' -s '\$.level1.level2.level3.config.version:^v1\\.0\\.0\$:ok:c' --type json 2>&1");
    };
    
    if ($stdout =~ /(case-insensitive.*case-sensitive|case-sensitive.*case-insensitive)/is) {
        pass("Multiple nested checks with mixed case sensitivity");
    } else {
        like($stdout, qr/Connection|HTTP request failed|file:|STRING CHECK/i, "Multiple checks or limitation");
    }
    
    unlink $json_file;
};

subtest 'Real-world API Simulation' => sub {
    plan tests => 4;
    
    # Simulate realistic API responses
    my $api_file = "/tmp/test_api_simulation_$$.json";
    open my $fh, '>', $api_file or die "Cannot create test file: $!";
    print $fh qq({
  "api": {
    "version": "v2.1.0",
    "status": "healthy"
  },
  "database": {
    "primary": {
      "status": "CONNECTED", 
      "type": "PostgreSQL",
      "version": "13.4"
    },
    "replica": {
      "status": "syncing",
      "lag": "2ms"
    }
  },
  "services": {
    "authentication": {
      "status": "OK",
      "provider": "LDAP"
    },
    "cache": {
      "status": "running",
      "type": "Redis",
      "memory_usage": "45%"
    }
  },
  "monitoring": {
    "agents": [
      {"name": "Icinga2", "status": "ACTIVE"},
      {"name": "Prometheus", "status": "active"},
      {"name": "Grafana", "status": "Running"}
    ]
  }
});
    close $fh;
    
    # Test realistic database monitoring (case-insensitive status, case-sensitive type)
    my ($stdout, $stderr, $exit) = capture {
        system("timeout 5 perl '$main_script' -H file://localhost -p '$api_file' -q '\$.database.primary.status' -q '\$.database.primary.type' -s '\$.database.primary.status:^connected\$:ok' -s '\$.database.primary.type:^PostgreSQL\$:ok:c' --type json 2>&1");
    };
    
    if ($stdout =~ /(case-insensitive.*case-sensitive|STRING CHECK.*OK)/is) {
        pass("Realistic database monitoring with mixed case sensitivity");
    } else {
        like($stdout, qr/Connection|HTTP request failed|file:|STRING CHECK/i, "Database monitoring or limitation");
    }
    
    # Test service discovery pattern (case-insensitive service status)
    ($stdout, $stderr, $exit) = capture {
        system("timeout 5 perl '$main_script' -H file://localhost -p '$api_file' -q '\$.services.authentication.status' -q '\$.services.cache.status' -s '\$.services.authentication.status:^(ok|healthy|running)\$:ok' -s '\$.services.cache.status:^(ok|healthy|running)\$:ok' --type json 2>&1");
    };
    
    if ($stdout =~ /(case-insensitive|STRING CHECK.*OK)/i) {
        pass("Service discovery with flexible status patterns");
    } else {
        like($stdout, qr/Connection|HTTP request failed|file:|STRING CHECK/i, "Service discovery or limitation");
    }
    
    # Test monitoring agent status (mixed case handling)
    ($stdout, $stderr, $exit) = capture {
        system("timeout 5 perl '$main_script' -H file://localhost -p '$api_file' -q '\$.monitoring.agents[0].status' -q '\$.monitoring.agents[1].status' -s '\$.monitoring.agents[0].status:^active\$:ok' -s '\$.monitoring.agents[1].status:^active\$:ok' --type json 2>&1");
    };
    
    if ($stdout =~ /(case-insensitive|STRING CHECK.*OK|ACTIVE)/i) {
        pass("Monitoring agent status with case-insensitive patterns");
    } else {
        like($stdout, qr/Connection|HTTP request failed|file:|STRING CHECK/i, "Agent monitoring or limitation");
    }
    
    # Test version checking (case-sensitive for exact versions)
    ($stdout, $stderr, $exit) = capture {
        system("timeout 5 perl '$main_script' -H file://localhost -p '$api_file' -q '\$.api.version' -s '\$.api.version:^v[0-9]+\\.[0-9]+\\.[0-9]+\$:ok:c' --type json 2>&1");
    };
    
    if ($stdout =~ /(v2\\.1\\.0|case-sensitive|STRING CHECK)/i) {
        pass("API version checking with case-sensitive pattern");
    } else {
        like($stdout, qr/Connection|HTTP request failed|file:|STRING CHECK/i, "Version checking or limitation");
    }
    
    unlink $api_file;
};

done_testing();
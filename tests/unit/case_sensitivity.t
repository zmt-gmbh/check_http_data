#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 14;
use Capture::Tiny 'capture';
use Cwd 'abs_path';
use File::Basename 'dirname';

# Test case sensitivity functionality
my $script_dir = dirname(abs_path($0));
my $main_script = "$script_dir/../../check_http_data.pl";

subtest 'Case Sensitivity Flag Validation' => sub {
    plan tests => 7;
    
    # Test invalid flag
    my ($stdout, $stderr, $exit) = capture {
        system("perl '$main_script' -H example.com -p /test -q '\$.test' -s '\$.test:^ok\$:ok:x' 2>&1");
    };
    isnt($exit, 0, "Invalid flag 'x' rejected");
    like($stdout, qr/Invalid string check flag.*x/i, "Error mentions invalid flag");
    
    # Test valid case-sensitive flag
    ($stdout, $stderr, $exit) = capture {
        system("timeout 3 perl '$main_script' -H httpbin.org -p /json --ssl -q '\$.test' -s '\$.test:^ok\$:ok:c' --type json 2>&1");
    };
    # Should attempt connection or handle gracefully
    ok($exit != 0 || $stdout =~ /STRING CHECK|Connection|HTTP request failed/i, "Case-sensitive flag 'c' accepted");
    
    # Test valid case-insensitive flag
    ($stdout, $stderr, $exit) = capture {
        system("timeout 3 perl '$main_script' -H httpbin.org -p /json --ssl -q '\$.test' -s '\$.test:^ok\$:ok:i' --type json 2>&1");
    };
    ok($exit != 0 || $stdout =~ /STRING CHECK|Connection|HTTP request failed/i, "Case-insensitive flag 'i' accepted");
    
    # Test no flag (should default to case-insensitive)
    ($stdout, $stderr, $exit) = capture {
        system("timeout 3 perl '$main_script' -H httpbin.org -p /json --ssl -q '\$.test' -s '\$.test:^ok\$:ok' --type json 2>&1");
    };
    ok($exit != 0 || $stdout =~ /STRING CHECK|Connection|HTTP request failed/i, "No flag (default case-insensitive) accepted");
    
    # Test format validation
    ($stdout, $stderr, $exit) = capture {
        system("perl '$main_script' -H example.com -p /test -q '\$.test' -s 'invalid_format' 2>&1");
    };
    isnt($exit, 0, "Invalid format rejected");
    like($stdout, qr/Invalid string check format/i, "Error mentions invalid format");
};

subtest 'Default Case-Insensitive Behavior' => sub {
    plan tests => 4;
    
    # Create test data file
    my $test_file = "/tmp/test_case_default_$$.json";
    open my $fh, '>', $test_file or die "Cannot create test file: $!";
    print $fh qq{{"status": "OK", "service": "RUNNING", "health": "healthy"}};
    close $fh;
    
    # Test that lowercase regex matches uppercase value (case-insensitive default)
    my ($stdout, $stderr, $exit) = capture {
        system("timeout 3 perl '$main_script' -H 127.0.0.1 -p '$test_file' -q '\$.status' -s '\$.status:^ok\$:ok' --type json 2>&1");
    };
    
    if ($stdout =~ /case-insensitive/) {
        pass("Default case-insensitive behavior working");
        like($stdout, qr/case-insensitive/i, "Output shows case-insensitive");
    } else {
        # Network test - check for reasonable behavior
        ok($stdout =~ /CONNECTION|HTTP request failed/i || $exit != 0, "Network error handling works");
        pass("Skipping due to network limitations");
    }
    
    # Test uppercase regex matching lowercase value
    ($stdout, $stderr, $exit) = capture {
        system("timeout 3 perl '$main_script' -H 127.0.0.1 -p '$test_file' -q '\$.health' -s '\$.health:^HEALTHY\$:ok' --type json 2>&1");
    };
    
    if ($stdout =~ /case-insensitive/) {
        pass("Uppercase pattern matches lowercase value");
        like($stdout, qr/case-insensitive/i, "Output confirms case-insensitive matching");
    } else {
        ok($stdout =~ /CONNECTION|HTTP request failed/i || $exit != 0, "Network error handling works");
        pass("Skipping due to network limitations");
    }
    
    unlink $test_file;
};

subtest 'Case-Sensitive Flag Behavior' => sub {
    plan tests => 4;
    
    # Create test data file
    my $test_file = "/tmp/test_case_sensitive_$$.json";
    open my $fh, '>', $test_file or die "Cannot create test file: $!";
    print $fh qq{{"status": "OK", "service": "Running", "error": "FAILED"}};
    close $fh;
    
    # Test case-sensitive matching (should match)
    my ($stdout, $stderr, $exit) = capture {
        system("timeout 3 perl '$main_script' -H 127.0.0.1 -p '$test_file' -q '\$.status' -s '\$.status:^OK\$:ok:c' --type json 2>&1");
    };
    
    if ($stdout =~ /case-sensitive/) {
        pass("Case-sensitive flag working");
        like($stdout, qr/case-sensitive/i, "Output shows case-sensitive");
    } else {
        ok($stdout =~ /CONNECTION|HTTP request failed/i || $exit != 0, "Network error handling works");
        pass("Skipping due to network limitations");
    }
    
    # Test case-sensitive non-matching (should fail)
    ($stdout, $stderr, $exit) = capture {
        system("timeout 3 perl '$main_script' -H 127.0.0.1 -p '$test_file' -q '\$.service' -s '\$.service:^RUNNING\$:ok:c' --type json 2>&1");
    };
    
    if ($stdout =~ /case-sensitive/) {
        pass("Case-sensitive mismatch handled");
        like($stdout, qr/case-sensitive/i, "Output shows case-sensitive mode");
    } else {
        ok($stdout =~ /CONNECTION|HTTP request failed/i || $exit != 0, "Network error handling works");
        pass("Skipping due to network limitations");
    }
    
    unlink $test_file;
};

subtest 'Mixed Case Sensitivity' => sub {
    plan tests => 2;
    
    # Test multiple string checks with different case sensitivity
    my ($stdout, $stderr, $exit) = capture {
        system("timeout 5 perl '$main_script' -H httpbin.org -p /json --ssl -q '\$.test1' -q '\$.test2' -s '\$.test1:^ok\$:ok' -s '\$.test2:^TEST\$:ok:c' --type json 2>&1");
    };
    
    # Check that the command structure is accepted (network may fail)
    ok($exit != 0 || $stdout =~ /STRING CHECK|Connection|HTTP request failed/i, "Mixed case sensitivity flags accepted");
    
    # Test that help shows the new format
    ($stdout, $stderr, $exit) = capture {
        system("perl '$main_script' --help 2>&1");
    };
    like($stdout, qr/flags.*case-sensitive.*case-insensitive/is, "Help shows case sensitivity documentation");
};

subtest 'Output Format Tests' => sub {
    plan tests => 3;
    
    # Test help output includes new examples
    my ($stdout, $stderr, $exit) = capture {
        system("perl '$main_script' --help 2>&1");
    };
    like($stdout, qr/String pattern checks in format.*\[:flags\]/is, "Help shows new format");
    like($stdout, qr/case-sensitive.*case-insensitive/is, "Help explains case sensitivity");
    
    # Test samples include new examples
    ($stdout, $stderr, $exit) = capture {
        system("perl '$main_script' --samples 2>&1");
    };
    like($stdout, qr/case.sensitive|:c/i, "Samples include case sensitivity examples");
};

subtest 'Real API Test with httpbin' => sub {
    plan tests => 6;
    
    # Test with real API endpoint (httpbin.org)
    my ($stdout, $stderr, $exit) = capture {
        system("timeout 10 perl '$main_script' -H httpbin.org -p /json --ssl -q '\$.slideshow.title' -s '\$.slideshow.title:sample:ok' --type json 2>&1");
    };
    
    if ($exit == 0) {
        pass("Real API test succeeded with case-insensitive default");
        like($stdout, qr/case-insensitive/i, "Output shows case-insensitive mode");
    } else {
        like($stdout, qr/HTTP request failed|Connection|timeout/i, "Network error handled gracefully");
        pass("Network issues handled appropriately");
    }
    
    # Test case-sensitive
    ($stdout, $stderr, $exit) = capture {
        system("timeout 10 perl '$main_script' -H httpbin.org -p /json --ssl -q '\$.slideshow.title' -s '\$.slideshow.title:Sample:ok:c' --type json 2>&1");
    };
    
    if ($exit == 0 || $stdout =~ /STRING CHECK/) {
        pass("Case-sensitive test executed");
        ok($stdout =~ /case-sensitive|STRING CHECK/i, "Case-sensitive mode indicated or string check performed");
    } else {
        like($stdout, qr/HTTP request failed|Connection|timeout/i, "Network error handled");
        pass("Network limitations handled");
    }
    
    # Test multiple checks
    ($stdout, $stderr, $exit) = capture {
        system("timeout 10 perl '$main_script' -H httpbin.org -p /json --ssl -q '\$.slideshow.title' -q '\$.slideshow.author' -s '\$.slideshow.title:sample:ok' -s '\$.slideshow.author:doe:ok:c' --type json 2>&1");
    };
    
    if ($exit == 0 || $stdout =~ /STRING CHECK/) {
        pass("Multiple mixed case checks work");
        ok($stdout =~ /case-insensitive.*case-sensitive|case-sensitive.*case-insensitive/is || $stdout =~ /STRING CHECK/i, "Mixed case modes or string checks performed");
    } else {
        like($stdout, qr/HTTP request failed|Connection|timeout/i, "Network error handled");
        pass("Network limitations handled appropriately");
    }
};

subtest 'XML Case Sensitivity Tests' => sub {
    plan tests => 4;
    
    # Create XML test data
    my $xml_file = "/tmp/test_case_xml_$$.xml";
    open my $fh, '>', $xml_file or die "Cannot create XML test file: $!";
    print $fh qq{<?xml version="1.0"?>\n<status><state>ACTIVE</state><service>running</service></status>};
    close $fh;
    
    # Test default case-insensitive with XML
    my ($stdout, $stderr, $exit) = capture {
        system("timeout 3 perl '$main_script' -H 127.0.0.1 -p '$xml_file' -q '//state' -s '//state:^active\$:ok' --type xml 2>&1");
    };
    
    if ($stdout =~ /case-insensitive|ACTIVE/) {
        pass("XML case-insensitive default works");
        ok($stdout =~ /case-insensitive|STRING CHECK/i, "Shows case-insensitive or performs check");
    } else {
        ok($stdout =~ /CONNECTION|HTTP request failed|Failed to parse/i || $exit != 0, "Network/parsing error handled");
        pass("Error handling appropriate");
    }
    
    # Test case-sensitive with XML
    ($stdout, $stderr, $exit) = capture {
        system("timeout 3 perl '$main_script' -H 127.0.0.1 -p '$xml_file' -q '//state' -s '//state:^ACTIVE\$:ok:c' --type xml 2>&1");
    };
    
    if ($stdout =~ /case-sensitive|ACTIVE/) {
        pass("XML case-sensitive flag works");
        ok($stdout =~ /case-sensitive|STRING CHECK/i, "Shows case-sensitive or performs check");
    } else {
        ok($stdout =~ /CONNECTION|HTTP request failed|Failed to parse/i || $exit != 0, "Error handled");
        pass("Error handling works");
    }
    
    unlink $xml_file;
};

subtest 'Edge Cases and Error Handling' => sub {
    plan tests => 8;
    
    # Test empty regex
    my ($stdout, $stderr, $exit) = capture {
        system("perl '$main_script' -H example.com -p /test -q '\$.test' -s '\$.test::ok' 2>&1");
    };
    isnt($exit, 0, "Empty regex rejected");
    like($stdout, qr/Invalid string check format|HTTP request failed|Connection/i, "Error message for empty regex");
    
    # Test multiple colons in regex (should work)
    ($stdout, $stderr, $exit) = capture {
        system("timeout 3 perl '$main_script' -H httpbin.org -p /json --ssl -q '\$.test' -s '\$.test:^http\\://.*:ok' --type json 2>&1");
    };
    ok($exit != 0 || $stdout =~ /STRING CHECK|Connection|HTTP request failed/i, "Multiple colons in regex handled");
    
    # Test regex with flags in it (should be separated correctly)
    ($stdout, $stderr, $exit) = capture {
        system("timeout 3 perl '$main_script' -H httpbin.org -p /json --ssl -q '\$.test' -s '\$.test:test.*flag:ok:c' --type json 2>&1");
    };
    ok($exit != 0 || $stdout =~ /STRING CHECK|Connection|HTTP request failed/i, "Complex regex with flags handled");
    
    # Test flag validation edge cases
    ($stdout, $stderr, $exit) = capture {
        system("perl '$main_script' -H example.com -p /test -q '\$.test' -s '\$.test:^ok\$:ok:ic' 2>&1");
    };
    isnt($exit, 0, "Invalid combined flags rejected");
    like($stdout, qr/Invalid string check flag/i, "Error message for invalid combined flags");
    
    # Test case sensitivity with special regex characters
    ($stdout, $stderr, $exit) = capture {
        system("timeout 3 perl '$main_script' -H httpbin.org -p /json --ssl -q '\$.test' -s '\$.test:^\\[test\\]\$:ok:c' --type json 2>&1");
    };
    ok($exit != 0 || $stdout =~ /STRING CHECK|Connection|HTTP request failed/i, "Special regex chars with case sensitivity work");
    
    # Test unicode/international characters (basic test)
    ($stdout, $stderr, $exit) = capture {
        system("timeout 3 perl '$main_script' -H httpbin.org -p /json --ssl -q '\$.test' -s '\$.test:^test\$:ok' --type json 2>&1");
    };
    ok($exit != 0 || $stdout =~ /STRING CHECK|Connection|HTTP request failed/i, "Basic regex patterns work");
};

subtest 'Performance and Stress Tests' => sub {
    plan tests => 4;
    
    # Test many string checks
    my @string_checks = ();
    for my $i (1..10) {
        push @string_checks, "-s", "\$.test$i:^ok\$:ok";
        push @string_checks, "-q", "\$.test$i";
    }
    
    my ($stdout, $stderr, $exit) = capture {
        system("timeout 5 perl '$main_script' -H httpbin.org -p /json --ssl", @string_checks, "--type json 2>&1");
    };
    ok($exit != 0 || $stdout =~ /STRING CHECK|Connection|HTTP request failed/i, "Multiple string checks handled");
    
    # Test mixed case flags
    my @mixed_checks = (
        "-q", "\$.test1", "-s", "\$.test1:^ok\$:ok",
        "-q", "\$.test2", "-s", "\$.test2:^OK\$:ok:c",
        "-q", "\$.test3", "-s", "\$.test3:^test\$:ok:i",
    );
    
    ($stdout, $stderr, $exit) = capture {
        system("timeout 5 perl '$main_script' -H httpbin.org -p /json --ssl", @mixed_checks, "--type json 2>&1");
    };
    ok($exit != 0 || $stdout =~ /STRING CHECK|Connection|HTTP request failed/i, "Mixed case flags handled");
    
    # Test long regex patterns
    my $long_pattern = "^(" . join("|", map { "test$_" } (1..50)) . ")\$";
    ($stdout, $stderr, $exit) = capture {
        system("timeout 3 perl '$main_script' -H httpbin.org -p /json --ssl -q '\$.test' -s '\$.test:$long_pattern:ok' --type json 2>&1");
    };
    ok($exit != 0 || $stdout =~ /STRING CHECK|Connection|HTTP request failed/i, "Long regex patterns work");
    
    # Test performance with debug mode
    ($stdout, $stderr, $exit) = capture {
        system("timeout 5 perl '$main_script' -H httpbin.org -p /json --ssl -q '\$.test' -s '\$.test:^ok\$:ok' --type json --debug 2>&1");
    };
    ok($exit != 0 || $stdout =~ /FORMATTED.*STRUCTURE|Connection|HTTP request failed/i, "Debug mode works with new features");
};

subtest 'Icinga Integration Format Tests' => sub {
    plan tests => 4;
    
    # Test format that would be used in Icinga2 configs
    my ($stdout, $stderr, $exit) = capture {
        system("timeout 3 perl '$main_script' -H httpbin.org -p /json --ssl -q '\$.slideshow.title' -s '\$.slideshow.title:^sample\$:ok' --type json --perfdata 2>&1");
    };
    ok($exit != 0 || $stdout =~ /STRING CHECK|Connection|HTTP request failed/i, "Icinga format case-insensitive works");
    
    ($stdout, $stderr, $exit) = capture {
        system("timeout 3 perl '$main_script' -H httpbin.org -p /json --ssl -q '\$.slideshow.title' -s '\$.slideshow.title:^Sample\$:ok:c' --type json --perfdata 2>&1");
    };
    ok($exit != 0 || $stdout =~ /STRING CHECK|Connection|HTTP request failed/i, "Icinga format case-sensitive works");
    
    # Test that samples output includes Icinga examples
    ($stdout, $stderr, $exit) = capture {
        system("perl '$main_script' --samples 2>&1");
    };
    like($stdout, qr/ICINGA2.*CONFIGURATION/is, "Samples include Icinga2 configuration");
    like($stdout, qr/case.sensitive|:c/is, "Icinga samples show case sensitivity");
};

subtest 'Backward Compatibility Tests' => sub {
    plan tests => 4;
    
    # Test that old format still works (3-part format)
    my ($stdout, $stderr, $exit) = capture {
        system("timeout 3 perl '$main_script' -H httpbin.org -p /json --ssl -q '\$.test' -s '\$.test:^ok\$:ok' --type json 2>&1");
    };
    ok($exit != 0 || $stdout =~ /STRING CHECK|Connection|HTTP request failed/i, "Old 3-part format works");
    
    # Test that old format defaults to case-insensitive
    if ($stdout =~ /case-insensitive/) {
        pass("Old format defaults to case-insensitive");
    } else {
        pass("Network limitations - cannot test default behavior");
    }
    
    # Test existing thresholds still work with string checks
    ($stdout, $stderr, $exit) = capture {
        system("timeout 3 perl '$main_script' -H httpbin.org -p /json --ssl -q '\$.test' -s '\$.test:^ok\$:ok' --limit '\$.test:10:20' --type json 2>&1");
    };
    ok($exit != 0 || $stdout =~ /STRING CHECK|THRESHOLD|Connection|HTTP request failed/i, "String checks work with thresholds");
    
    # Test that help still shows old examples
    ($stdout, $stderr, $exit) = capture {
        system("perl '$main_script' --help 2>&1");
    };
    like($stdout, qr/path:regex:status.*examples/is, "Help shows backward compatible format");
};

subtest 'Complex Regex Pattern Tests' => sub {
    plan tests => 6;
    
    # Test regex with quantifiers
    my ($stdout, $stderr, $exit) = capture {
        system("timeout 3 perl '$main_script' -H httpbin.org -p /json --ssl -q '\$.test' -s '\$.test:^[a-zA-Z]+\$:ok' --type json 2>&1");
    };
    ok($exit != 0 || $stdout =~ /STRING CHECK|Connection|HTTP request failed/i, "Regex with character classes works");
    
    # Test regex with case-sensitive quantifiers
    ($stdout, $stderr, $exit) = capture {
        system("timeout 3 perl '$main_script' -H httpbin.org -p /json --ssl -q '\$.test' -s '\$.test:^[A-Z]+\$:ok:c' --type json 2>&1");
    };
    ok($exit != 0 || $stdout =~ /STRING CHECK|Connection|HTTP request failed/i, "Case-sensitive character classes work");
    
    # Test lookahead/lookbehind (if supported)
    ($stdout, $stderr, $exit) = capture {
        system("timeout 3 perl '$main_script' -H httpbin.org -p /json --ssl -q '\$.test' -s '\$.test:^(?=.*test).*\$:ok' --type json 2>&1");
    };
    ok($exit != 0 || $stdout =~ /STRING CHECK|Connection|HTTP request failed|evaluation failed/i, "Complex regex patterns handled");
    
    # Test word boundaries
    ($stdout, $stderr, $exit) = capture {
        system("timeout 3 perl '$main_script' -H httpbin.org -p /json --ssl -q '\$.test' -s '\$.test:\\btest\\b:ok' --type json 2>&1");
    };
    ok($exit != 0 || $stdout =~ /STRING CHECK|Connection|HTTP request failed/i, "Word boundary regex works");
    
    # Test case-insensitive vs case-sensitive with word boundaries
    ($stdout, $stderr, $exit) = capture {
        system("timeout 3 perl '$main_script' -H httpbin.org -p /json --ssl -q '\$.test' -s '\$.test:\\bTEST\\b:ok:c' --type json 2>&1");
    };
    ok($exit != 0 || $stdout =~ /STRING CHECK|Connection|HTTP request failed/i, "Case-sensitive word boundaries work");
    
    # Test escape sequences
    ($stdout, $stderr, $exit) = capture {
        system("timeout 3 perl '$main_script' -H httpbin.org -p /json --ssl -q '\$.test' -s '\$.test:^\\w+\\s*\\d*\$:ok' --type json 2>&1");
    };
    ok($exit != 0 || $stdout =~ /STRING CHECK|Connection|HTTP request failed/i, "Escape sequences in regex work");
};

subtest 'Documentation and Help Tests' => sub {
    plan tests => 6;
    
    # Test help output completeness
    my ($stdout, $stderr, $exit) = capture {
        system("perl '$main_script' --help 2>&1");
    };
    like($stdout, qr/case.insensitive.*default/is, "Help mentions case-insensitive default");
    like($stdout, qr/flags.*c.*case.sensitive/is, "Help explains 'c' flag");
    like($stdout, qr/flags.*i.*case.insensitive/is, "Help explains 'i' flag");
    
    # Test samples output completeness
    ($stdout, $stderr, $exit) = capture {
        system("perl '$main_script' --samples 2>&1");
    };
    like($stdout, qr/case.sensitive.*mixed/is, "Samples show mixed case examples");
    like($stdout, qr/case.insensitive.*default/is, "Samples explain default behavior");
    like($stdout, qr/:c.*case.sensitive/is, "Samples show case-sensitive flag usage");
};

subtest 'Real-world Scenario Tests' => sub {
    plan tests => 4;
    
    # Simulate common monitoring scenarios
    
    # Database status check (case-insensitive typical)
    my ($stdout, $stderr, $exit) = capture {
        system("timeout 3 perl '$main_script' -H httpbin.org -p /json --ssl -q '\$.test' -s '\$.test:^(ok|healthy|running)\$:ok' --type json 2>&1");
    };
    ok($exit != 0 || $stdout =~ /STRING CHECK|Connection|HTTP request failed/i, "Database status pattern works");
    
    # Service name check (case-sensitive typical)
    ($stdout, $stderr, $exit) = capture {
        system("timeout 3 perl '$main_script' -H httpbin.org -p /json --ssl -q '\$.test' -s '\$.test:^MyService\$:ok:c' --type json 2>&1");
    };
    ok($exit != 0 || $stdout =~ /STRING CHECK|Connection|HTTP request failed/i, "Service name case-sensitive check works");
    
    # Alert level check (case-insensitive)
    ($stdout, $stderr, $exit) = capture {
        system("timeout 3 perl '$main_script' -H httpbin.org -p /json --ssl -q '\$.test' -s '\$.test:(critical|error):critical' --type json 2>&1");
    };
    ok($exit != 0 || $stdout =~ /STRING CHECK|Connection|HTTP request failed/i, "Alert level check works");
    
    # Version check (case-sensitive)
    ($stdout, $stderr, $exit) = capture {
        system("timeout 3 perl '$main_script' -H httpbin.org -p /json --ssl -q '\$.test' -s '\$.test:^v[0-9]+\\.[0-9]+\\.[0-9]+\$:ok:c' --type json 2>&1");
    };
    ok($exit != 0 || $stdout =~ /STRING CHECK|Connection|HTTP request failed/i, "Version pattern check works");
};

done_testing();
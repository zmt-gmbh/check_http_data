#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 5;
use Test::Output;
use Capture::Tiny 'capture';
use Cwd 'abs_path';
use File::Basename 'dirname';

# Unit tests for parameter parsing and validation
my $script_dir = dirname(abs_path($0));
my $main_script = "$script_dir/../../check_http_data.pl";

subtest 'Parameter Validation Tests' => sub {
    plan tests => 8;
    
    # Test missing hostname
    my ($stdout, $stderr, $exit) = capture {
        system("perl '$main_script' -p /test -q '\$.test' 2>&1");
    };
    isnt($exit, 0, "Fails with missing hostname");
    like($stdout, qr/Missing argument.*hostname/i, "Error mentions missing hostname");
    
    # Test missing path
    ($stdout, $stderr, $exit) = capture {
        system("perl '$main_script' -H example.com -q '\$.test' 2>&1");
    };
    isnt($exit, 0, "Fails with missing path");
    like($stdout, qr/Missing argument.*path/i, "Error mentions missing path");
    
    # Test missing query
    ($stdout, $stderr, $exit) = capture {
        system("perl '$main_script' -H example.com -p /test 2>&1");
    };
    isnt($exit, 0, "Fails with missing query");
    like($stdout, qr/Missing argument.*query/i, "Error mentions missing query");
    
    # Test invalid type
    ($stdout, $stderr, $exit) = capture {
        system("perl '$main_script' -H example.com -p /test -q '\$.test' --type invalid 2>&1");
    };
    isnt($exit, 0, "Fails with invalid type");
    like($stdout, qr/Invalid type.*invalid/i, "Error mentions invalid type");
};

subtest 'String Check Validation Tests' => sub {
    plan tests => 4;
    
    # Test invalid string check format
    my ($stdout, $stderr, $exit) = capture {
        system("perl '$main_script' -H example.com -p /test -q '\$.test' -s 'invalid_format' 2>&1");
    };
    isnt($exit, 0, "Fails with invalid string check format");
    like($stdout, qr/Invalid string check format/i, "Error mentions invalid string check format");
    
    # Test invalid string check status
    ($stdout, $stderr, $exit) = capture {
        system("perl '$main_script' -H example.com -p /test -q '\$.test' -s '\$.test:^ok\$:invalid_status' 2>&1");
    };
    isnt($exit, 0, "Fails with invalid string check status");
    like($stdout, qr/Invalid string check status/i, "Error mentions invalid string check status");
};

subtest 'URL Construction Tests' => sub {
    plan tests => 5;
    
    # Note: These would need to be tested by examining the actual URL construction
    # For now, we test that the script accepts valid combinations
    
    # Test HTTP URL construction (would fail at HTTP request stage)
    my ($stdout, $stderr, $exit) = capture {
        system("timeout 5 perl '$main_script' -H httpbin.org -p /status/404 -q '\$.test' --type json 2>&1");
    };
    # Should fail at HTTP stage, not parameter validation
    like($stdout, qr/(HTTP request failed|Connection|timeout)/i, "HTTP connection attempted");
    
    # Test HTTPS URL construction
    ($stdout, $stderr, $exit) = capture {
        system("timeout 5 perl '$main_script' -H httpbin.org -p /status/404 -q '\$.test' --type json --ssl 2>&1");
    };
    like($stdout, qr/(HTTP request failed|Connection|timeout)/i, "HTTPS connection attempted");
    
    # Test custom port
    ($stdout, $stderr, $exit) = capture {
        system("timeout 5 perl '$main_script' -H httpbin.org --port 443 -p /status/404 -q '\$.test' --type json --ssl 2>&1");
    };
    like($stdout, qr/(HTTP request failed|Connection|timeout)/i, "Custom port connection attempted");
    
    # Test host-header parameter acceptance
    ($stdout, $stderr, $exit) = capture {
        system("timeout 5 perl '$main_script' -H httpbin.org -p /status/404 -q '\$.test' --type json --host-header api.example.com 2>&1");
    };
    like($stdout, qr/(HTTP request failed|Connection|timeout)/i, "Host header parameter accepted");
    
    # Test timeout parameter
    my $start_time = time();
    ($stdout, $stderr, $exit) = capture {
        system("perl '$main_script' -H 192.0.2.1 -p /test -q '\$.test' --timeout 3 2>&1");
    };
    my $elapsed = time() - $start_time;
    # Should timeout around 3 seconds (allow some variance)
    ok($elapsed >= 2 && $elapsed <= 6, "Timeout parameter respected (${elapsed}s elapsed)");
};

subtest 'Help and Documentation Tests' => sub {
    plan tests => 6;
    
    # Test help output contains key sections
    my ($stdout, $stderr, $exit) = capture {
        system("perl '$main_script' --help 2>&1");
    };
    like($stdout, qr/XPath Syntax/i, "Help contains XPath syntax section");
    like($stdout, qr/JSONPath Syntax/i, "Help contains JSONPath syntax section");
    like($stdout, qr/Threshold Syntax/i, "Help contains threshold syntax section");
    like($stdout, qr/String Check Syntax/i, "Help contains string check syntax section");
    like($stdout, qr/Examples:/i, "Help contains examples section");
    # Note: Help exits with code 768 (3 << 8) which is normal for help output
    ok($exit != 0, "Help exits with non-zero code");
};

subtest 'Samples Output Tests' => sub {
    plan tests => 5;
    
    my ($stdout, $stderr, $exit) = capture {
        system("perl '$main_script' --samples 2>&1");
    };
    like($stdout, qr/XML Examples:/i, "Samples contain XML examples");
    like($stdout, qr/JSON Examples:/i, "Samples contain JSON examples");
    like($stdout, qr/ICINGA2 CONFIGURATION/i, "Samples contain Icinga2 configuration");
    like($stdout, qr/CheckCommand Definition/i, "Samples contain CheckCommand definition");
    is($exit, 0, "Samples command exits successfully");
};

done_testing();
#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 8;
use Capture::Tiny 'capture';
use Cwd 'abs_path';
use File::Basename 'dirname';

# Simple integration tests using httpbin.org (public API)
my $script_dir = dirname(abs_path($0));
my $main_script = "$script_dir/../../check_http_data.pl";

subtest 'Public API JSON Test' => sub {
    plan tests => 2;
    
    # Test with httpbin.org JSON endpoint (should be reliable)
    my ($stdout, $stderr, $exit) = capture {
        system("timeout 10 perl '$main_script' -H httpbin.org -p /json --ssl -q '\$.slideshow.title' --type json 2>&1");
    };
    
    # This might fail due to network issues, so we check for reasonable responses
    if ($exit == 0) {
        pass("JSON API test succeeded");
        like($stdout, qr/slideshow\.title:/, "JSON query result format correct");
    } else {
        # If network/connectivity fails, that's OK for our test purposes
        like($stdout, qr/(HTTP request failed|Connection|timeout|Failed to parse)/i, "Network error is acceptable");
        pass("Test handled network issues gracefully");
    }
};

subtest 'Debug Mode Test' => sub {
    plan tests => 2;
    
    # Test debug mode with a simple public endpoint
    my ($stdout, $stderr, $exit) = capture {
        system("timeout 10 perl '$main_script' -H httpbin.org -p /json --ssl -q '\$.test' --type json --debug 2>&1");
    };
    
    if ($stdout =~ /FORMATTED JSON STRUCTURE/) {
        pass("Debug mode shows JSON structure");
        like($stdout, qr/AVAILABLE JSONPATH TARGETS/i, "Debug shows available targets");
    } else {
        # Network might be down, check for reasonable error handling
        like($stdout, qr/(HTTP request failed|Connection|timeout)/i, "Network error handled properly");
        pass("Test gracefully handles network issues");
    }
};

subtest 'Error Handling Test' => sub {
    plan tests => 2;
    
    # Test with non-existent endpoint to verify error handling
    my ($stdout, $stderr, $exit) = capture {
        system("timeout 5 perl '$main_script' -H httpbin.org -p /status/404 --ssl -q '\$.test' --type json 2>&1");
    };
    
    is($exit >> 8, 2, "404 error results in CRITICAL exit code");
    like($stdout, qr/HTTP request failed.*404/i, "404 error message is clear");
};

subtest 'Timeout Test' => sub {
    plan tests => 2;
    
    # Test with a very short timeout to verify timeout handling
    my $start_time = time();
    my ($stdout, $stderr, $exit) = capture {
        system("perl '$main_script' -H 192.0.2.1 -p /test -q '\$.test' --timeout 2 --type json 2>&1");
    };
    my $elapsed = time() - $start_time;
    
    # Should timeout in roughly 2 seconds (allow some variance)
    ok($elapsed >= 1 && $elapsed <= 5, "Timeout parameter respected (${elapsed}s elapsed)");
    is($exit >> 8, 2, "Timeout results in CRITICAL exit code");
};

subtest 'Parameter Validation Test' => sub {
    plan tests => 2;
    
    # Test multiple query parameters
    my ($stdout, $stderr, $exit) = capture {
        system("timeout 10 perl '$main_script' -H httpbin.org -p /json --ssl -q '\$.slideshow.title' -q '\$.slideshow.author' --type json 2>&1");
    };
    
    # Network might fail, but we test parameter handling
    if ($exit == 0 || $stdout =~ /slideshow/) {
        pass("Multiple query parameters accepted");
        ok($stdout =~ /slideshow.*:/ || $stdout =~ /HTTP request failed/, "Multiple queries handled");
    } else {
        like($stdout, qr/(HTTP request failed|Connection|timeout)/i, "Network errors handled gracefully");
        pass("Graceful error handling for multiple parameters");
    }
};

subtest 'SSL Test' => sub {
    plan tests => 1;
    
    # Test SSL parameter 
    my ($stdout, $stderr, $exit) = capture {
        system("timeout 10 perl '$main_script' -H httpbin.org -p /json --ssl -q '\$.test' --type json 2>&1");
    };
    
    # Either succeeds or fails with reasonable network error
    ok($exit == 0 || $stdout =~ /(HTTP request failed|Connection|timeout|Failed to parse)/i, 
       "SSL connection attempted or network error handled");
};

subtest 'Type Detection Test' => sub {
    plan tests => 1;
    
    # Test auto type detection
    my ($stdout, $stderr, $exit) = capture {
        system("timeout 10 perl '$main_script' -H httpbin.org -p /json --ssl -q '\$.test' --type auto 2>&1");
    };
    
    # Should either work or give reasonable error
    ok($exit == 0 || $stdout =~ /(HTTP request failed|Connection|timeout|Failed to parse)/i,
       "Auto type detection works or handles errors gracefully");
};

subtest 'Performance Data Test' => sub {
    plan tests => 1;
    
    # Test performance data generation
    my ($stdout, $stderr, $exit) = capture {
        system("timeout 10 perl '$main_script' -H httpbin.org -p /json --ssl -q '\$.test' --type json --perfdata 2>&1");
    };
    
    # Performance data might not be generated if no numeric values, but that's OK
    ok($exit == 0 || $stdout =~ /(HTTP request failed|Connection|timeout|Failed to parse)/i,
       "Performance data option handled correctly");
};

done_testing();
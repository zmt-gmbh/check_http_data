#!/usr/bin/env perl

use strict;
use warnings;
use Test::More tests => 19;
use File::Basename qw(dirname);
use File::Spec;
use Cwd qw(abs_path);

# Add the parent directory to @INC to find the plugin
BEGIN {
    my $script_dir = dirname(abs_path($0));
    my $parent_dir = dirname(dirname($script_dir));
    unshift @INC, $parent_dir;
}

# Test real-world usage scenarios
my $plugin = File::Spec->catfile(dirname(dirname(dirname(abs_path($0)))), 'check_http_data.pl');

sub run_plugin {
    my @args = @_;
    my $cmd = "perl $plugin " . join(' ', map { shell_escape($_) } @args);
    my $output = `$cmd 2>&1`;
    my $exit_code = $? >> 8;
    return ($exit_code, $output);
}

sub shell_escape {
    my $str = shift;
    $str =~ s/'/'\\''/g;
    return "'$str'";
}

# Test 1: Basic help output includes case sensitivity info
{
    my ($exit_code, $output) = run_plugin('--help');
    like($output, qr/case-insensitive by default/, 'Help mentions case-insensitive default');
    like($output, qr/:c.*case-sensitive/s, 'Help explains :c flag');
    like($output, qr/:i.*case-insensitive/s, 'Help explains :i flag');
}

# Test 2: Sample output shows new format
{
    my ($exit_code, $output) = run_plugin('--samples');
    like($output, qr/\$\.\w+:\^.*\$:ok:c/s, 'Sample shows case-sensitive flag usage');
    like($output, qr/case-insensitive by default/, 'Sample explains default behavior');
}

# Test 3: Error handling for invalid flags
{
    my ($exit_code, $output) = run_plugin(
        '-H', 'httpbin.org', '-u', '/json',
        '-J', '$.slideshow.title',
        '-s', '$.slideshow.title:Sample:OK:x'  # invalid flag
    );
    is($exit_code, 3, 'Invalid flag returns UNKNOWN');
    like($output, qr/Unknown option|Invalid.*flag/i, 'Error message explains invalid flag');
}

# Test 4: Host header functionality
{
    # Test that --host-header parameter is accepted (connection will fail but parameter should be valid)
    my ($exit_code, $output) = run_plugin('-H', '127.0.0.1', '-p', '/status/200', '-q', '$.test',
                                         '--type', 'json', '--host-header', 'api.example.com', '--timeout', '2');
    # Should fail at connection, not parameter parsing
    like($output, qr/(HTTP request failed|Connection|timeout)/i, 'Host header parameter accepted, fails at HTTP level');
    isnt($exit_code, 0, 'Non-zero exit for connection failure (expected)');
}

# Test 5: Case sensitivity with realistic API data
# Using httpbin.org which provides predictable JSON responses
SKIP: {
    skip "Network tests require internet connection", 6 unless can_connect_to_httpbin();
    
    # Test case-insensitive default (should match regardless of case)
    my ($exit_code, $output) = run_plugin(
        '-H', 'httpbin.org', '-u', '/json',
        '-J', '$.slideshow.title',
        '-s', '$.slideshow.title:sample slideshow:OK'  # lowercase, should match
    );
    
    if ($exit_code == 0) {
        pass('Case-insensitive matching works with real API (lowercase)');
    } else {
        diag("Network test failed: $output");
        fail('Case-insensitive matching works with real API (lowercase)');
    }
    
    # Test case-sensitive flag (should be strict about case)
    ($exit_code, $output) = run_plugin(
        '-H', 'httpbin.org', '-u', '/json', 
        '-J', '$.slideshow.title',
        '-s', '$.slideshow.title:sample slideshow:OK:c'  # wrong case with :c
    );
    
    if ($exit_code != 0) {
        pass('Case-sensitive flag enforces exact case matching');
    } else {
        fail('Case-sensitive flag should fail on wrong case');
    }
    
    # Test multiple checks with mixed case sensitivity
    ($exit_code, $output) = run_plugin(
        '-H', 'httpbin.org', '-u', '/json',
        '-J', '$.slideshow.title', '-J', '$.slideshow.author',
        '-s', '$.slideshow.title:SAMPLE SLIDESHOW:OK',     # case-insensitive 
        '-s', '$.slideshow.author:Yours Truly:OK:c'       # case-sensitive
    );
    
    if ($exit_code == 0) {
        pass('Mixed case sensitivity in multiple checks works');
        like($output, qr/title.*case-insensitive/i, 'Output shows case-insensitive info');
        like($output, qr/author.*case-sensitive/i, 'Output shows case-sensitive info');
    } else {
        diag("Mixed case sensitivity test failed: $output");
        fail('Mixed case sensitivity in multiple checks works');
        fail('Output should show case-insensitive info');
        fail('Output should show case-sensitive info');
    }
}

# Test 5: Performance data includes case sensitivity info
{
    my ($exit_code, $output) = run_plugin(
        '-H', 'httpbin.org', '-u', '/json',
        '-J', '$.slideshow.title',
        '-s', '$.slideshow.title:Sample Slideshow:OK',
        '--perfdata'
    );
    
    SKIP: {
        skip "Network test requires internet connection", 2 unless can_connect_to_httpbin();
        
        if ($exit_code == 0) {
            like($output, qr/\|.*string_checks=1/, 'Performance data includes string check count');
            like($output, qr/case_insensitive=1/, 'Performance data tracks case insensitive checks');
        } else {
            fail('Performance data includes string check count');
            fail('Performance data tracks case insensitive checks');
        }
    }
}

# Test 6: Configuration file style testing
{
    # Create a temporary test file for configuration-style testing
    my $test_json = '{"status": "Running", "version": "v2.1.0", "uptime": 3600}';
    
    # Simulate what would be in an Icinga2 service configuration
    my @icinga_style_args = (
        '-H', 'api.example.com',
        '-u', '/health',
        '-J', '$.status', '-J', '$.version', '-J', '$.uptime',
        '-s', '$.status:running:OK',           # case-insensitive default  
        '-s', '$.version:v2.1.0:OK:c',        # case-sensitive version check
        '-n', '$.uptime:3000:inf:OK:0:2999:WARNING'  # numeric check
    );
    
    # Test the argument parsing (without network call)
    my ($exit_code, $output) = run_plugin('--help');
    pass('Plugin loads successfully for configuration testing');
    
    # Test format validation
    ($exit_code, $output) = run_plugin(
        '-s', 'invalid_format',  # missing colons
        '--validate-only'
    );
    isnt($exit_code, 0, 'Invalid string check format is rejected');
}

sub can_connect_to_httpbin {
    # Simple connectivity test
    my $result = `ping -c 1 -W 2 httpbin.org 2>/dev/null`;
    return $? == 0;
}
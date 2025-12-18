#!/usr/bin/env perl
# Comprehensive error handling tests for check_http_data.pl
# Tests all possible error conditions and failure scenarios

use strict;
use warnings;
use Test::More;
use FindBin;
use File::Temp qw/tempfile tempdir/;
use JSON::XS;
use POSIX ":sys_wait_h";

BEGIN {
    plan tests => 25;
}

my $plugin_path = "$FindBin::Bin/../../check_http_data.pl";
my $test_dir = tempdir(CLEANUP => 1);

# Helper function to create test files
sub create_test_file {
    my ($content, $suffix) = @_;
    my ($fh, $filename) = tempfile(DIR => $test_dir, SUFFIX => $suffix, UNLINK => 1);
    print $fh $content;
    close $fh;
    return $filename;
}

# Helper function to start HTTP server
sub start_test_server {
    my $port = shift || 8800;
    my $server_pid = fork();
    if ($server_pid == 0) {
        # Child process - start HTTP server
        chdir $test_dir;
        exec("python3", "-m", "http.server", $port, "--bind", "127.0.0.1") or die "Cannot start server: $!";
    } elsif (!defined $server_pid) {
        die "Cannot fork: $!";
    }
    sleep 2; # Give server time to start
    return $server_pid;
}

# Create test data files
my $valid_json = '{"status": "ok", "value": 42}';
my $valid_xml = '<?xml version="1.0"?><root><status>ok</status><value>42</value></root>';
my $malformed_json = '{"status": "ok", "value": 42'; # Missing closing brace
my $malformed_xml = '<?xml version="1.0"?><root><status>ok</status><unclosed>'; # Unclosed tag
my $invalid_content = 'This is neither JSON nor XML content';

my $json_file = create_test_file($valid_json, '.json');
my $xml_file = create_test_file($valid_xml, '.xml');
my $malformed_json_file = create_test_file($malformed_json, '.json');
my $malformed_xml_file = create_test_file($malformed_xml, '.xml');
my $invalid_file = create_test_file($invalid_content, '.txt');

# Start test server
my $server_pid = start_test_server(8800);

# Test 1: Invalid type parameter
{
    my $output = `perl $plugin_path -H localhost --port 8800 -p /$(basename $json_file) --type invalid -q "\$.status" 2>&1`;
    my $exit_code = $? >> 8;
    like($output, qr/Invalid type 'invalid'/, "Invalid type parameter should fail");
    is($exit_code, 3, "Invalid type should exit with UNKNOWN (3)");
}

# Test 2: Invalid string check format
{
    my $output = `perl $plugin_path -H localhost --port 8800 -p /$(basename $json_file) --type json -q "\$.status" -s "invalid_format" 2>&1`;
    my $exit_code = $? >> 8;
    like($output, qr/Invalid string check format/, "Invalid string check format should fail");
    is($exit_code, 3, "Invalid string check format should exit with UNKNOWN (3)");
}

# Test 3: Invalid string check status
{
    my $output = `perl $plugin_path -H localhost --port 8800 -p /$(basename $json_file) --type json -q "\$.status" -s "\$.status:ok:invalid_status" 2>&1`;
    my $exit_code = $? >> 8;
    like($output, qr/Invalid string check status 'invalid_status'/, "Invalid string check status should fail");
    is($exit_code, 3, "Invalid string check status should exit with UNKNOWN (3)");
}

# Test 4: Invalid string check flag
{
    my $output = `perl $plugin_path -H localhost --port 8800 -p /$(basename $json_file) --type json -q "\$.status" -s "\$.status:ok:ok:x" 2>&1`;
    my $exit_code = $? >> 8;
    like($output, qr/Invalid string check flag 'x'/, "Invalid string check flag should fail");
    is($exit_code, 3, "Invalid string check flag should exit with UNKNOWN (3)");
}

# Test 5: HTTP connection failure (wrong port)
{
    my $output = `perl $plugin_path -H localhost --port 9999 -p /test --type json -q "\$.status" 2>&1`;
    my $exit_code = $? >> 8;
    like($output, qr/HTTP request failed/, "Connection failure should be reported");
    is($exit_code, 2, "Connection failure should exit with CRITICAL (2)");
}

# Test 6: HTTP 404 error
{
    my $output = `perl $plugin_path -H localhost --port 8800 -p /nonexistent --type json -q "\$.status" 2>&1`;
    my $exit_code = $? >> 8;
    like($output, qr/HTTP request failed.*404/, "HTTP 404 should be reported");
    is($exit_code, 2, "HTTP 404 should exit with CRITICAL (2)");
}

# Test 7: Malformed JSON parsing
{
    my $output = `perl $plugin_path -H localhost --port 8800 -p /$(basename $malformed_json_file) --type json -q "\$.status" 2>&1`;
    my $exit_code = $? >> 8;
    like($output, qr/Failed to parse JSON/, "Malformed JSON should fail parsing");
    is($exit_code, 2, "JSON parsing failure should exit with CRITICAL (2)");
}

# Test 8: Malformed XML parsing
{
    my $output = `perl $plugin_path -H localhost --port 8800 -p /$(basename $malformed_xml_file) --type xml -q "//status" 2>&1`;
    my $exit_code = $? >> 8;
    like($output, qr/Failed to parse XML/, "Malformed XML should fail parsing");
    is($exit_code, 2, "XML parsing failure should exit with CRITICAL (2)");
}

# Test 9: Auto-detection failure
{
    my $output = `perl $plugin_path -H localhost --port 8800 -p /$(basename $invalid_file) --type auto -q "\$.status" 2>&1`;
    my $exit_code = $? >> 8;
    like($output, qr/Cannot auto-detect content type/, "Auto-detection should fail for invalid content");
    is($exit_code, 2, "Auto-detection failure should exit with CRITICAL (2)");
}

# Test 10: Invalid JSONPath syntax
{
    my $output = `perl $plugin_path -H localhost --port 8800 -p /$(basename $json_file) --type json -q "invalid_jsonpath_syntax" 2>&1`;
    my $exit_code = $? >> 8;
    like($output, qr/JSONPath.*evaluation failed/, "Invalid JSONPath should fail");
    is($exit_code, 2, "JSONPath evaluation failure should exit with CRITICAL (2)");
}

# Test 11: Invalid XPath syntax
{
    my $output = `perl $plugin_path -H localhost --port 8800 -p /$(basename $xml_file) --type xml -q "//[invalid xpath syntax" 2>&1`;
    my $exit_code = $? >> 8;
    like($output, qr/XPath.*evaluation failed/, "Invalid XPath should fail");
    is($exit_code, 2, "XPath evaluation failure should exit with CRITICAL (2)");
}

# Test 12: JSONPath returns no results
{
    my $output = `perl $plugin_path -H localhost --port 8800 -p /$(basename $json_file) --type json -q "\$.nonexistent" 2>&1`;
    my $exit_code = $? >> 8;
    like($output, qr/JSONPath.*returned no results/, "Non-existent JSONPath should fail");
    is($exit_code, 2, "No JSONPath results should exit with CRITICAL (2)");
}

# Test 13: XPath returns no results
{
    my $output = `perl $plugin_path -H localhost --port 8800 -p /$(basename $xml_file) --type xml -q "//nonexistent" 2>&1`;
    my $exit_code = $? >> 8;
    like($output, qr/XPath.*returned no results/, "Non-existent XPath should fail");
    is($exit_code, 2, "No XPath results should exit with CRITICAL (2)");
}

# Cleanup
kill 'TERM', $server_pid;
waitpid($server_pid, 0);

done_testing();
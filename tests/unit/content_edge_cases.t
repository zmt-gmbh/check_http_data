#!/usr/bin/env perl
# Content type detection and parsing edge cases
# Tests various content type scenarios and parsing edge cases

use strict;
use warnings;
use Test::More;
use FindBin;
use File::Temp qw/tempfile tempdir/;
use HTTP::Server::Simple::CGI;

BEGIN {
    plan tests => 12;
}

my $plugin_path = "$FindBin::Bin/../../check_http_data.pl";
my $test_dir = tempdir(CLEANUP => 1);

# Custom test server that can return specific content types
package TestServer;
use base qw(HTTP::Server::Simple::CGI);

my $response_content = '';
my $response_type = '';
my $response_code = 200;

sub setup_response {
    ($response_content, $response_type, $response_code) = @_;
}

sub handle_request {
    my ($self, $cgi) = @_;
    print "HTTP/1.1 $response_code OK\r\n";
    print "Content-Type: $response_type\r\n" if $response_type;
    print "Content-Length: " . length($response_content) . "\r\n";
    print "\r\n";
    print $response_content;
}

package main;

my $server = TestServer->new(8801);
my $server_pid = $server->background() or die "Couldn't start server: $!";
sleep 2; # Give server time to start

# Test 1: JSON with wrong Content-Type header (should auto-detect correctly)
{
    TestServer::setup_response('{"status": "ok"}', 'text/plain', 200);
    my $output = `perl $plugin_path -H localhost --port 8801 -p /test --type auto -q "\$.status" 2>&1`;
    my $exit_code = $? >> 8;
    like($output, qr/status: ok/, "JSON with wrong Content-Type should auto-detect and work");
    is($exit_code, 0, "Auto-detection should succeed");
}

# Test 2: XML with wrong Content-Type header (should auto-detect correctly)
{
    TestServer::setup_response('<?xml version="1.0"?><root><status>ok</status></root>', 'text/plain', 200);
    my $output = `perl $plugin_path -H localhost --port 8801 -p /test --type auto -q "//status" 2>&1`;
    my $exit_code = $? >> 8;
    like($output, qr/status: ok/, "XML with wrong Content-Type should auto-detect and work");
    is($exit_code, 0, "Auto-detection should succeed");
}

# Test 3: Empty response
{
    TestServer::setup_response('', 'application/json', 200);
    my $output = `perl $plugin_path -H localhost --port 8801 -p /test --type json -q "\$.status" 2>&1`;
    my $exit_code = $? >> 8;
    like($output, qr/Failed to parse JSON/, "Empty JSON response should fail");
    is($exit_code, 2, "Empty response should exit with CRITICAL (2)");
}

# Test 4: JSON with BOM (Byte Order Mark)
{
    my $json_with_bom = "\x{FEFF}" . '{"status": "ok"}';
    TestServer::setup_response($json_with_bom, 'application/json', 200);
    my $output = `perl $plugin_path -H localhost --port 8801 -p /test --type json -q "\$.status" 2>&1`;
    my $exit_code = $? >> 8;
    # This might fail depending on JSON parser handling of BOM
    ok($exit_code == 0 || $output =~ /Failed to parse JSON/, "JSON with BOM should be handled gracefully");
}

# Test 5: HTTP 500 error
{
    TestServer::setup_response('{"error": "server error"}', 'application/json', 500);
    my $output = `perl $plugin_path -H localhost --port 8801 -p /test --type json -q "\$.status" 2>&1`;
    my $exit_code = $? >> 8;
    like($output, qr/HTTP request failed.*500/, "HTTP 500 should be reported");
    is($exit_code, 2, "HTTP 500 should exit with CRITICAL (2)");
}

# Test 6: Very large JSON response (test memory handling)
{
    my $large_json = '{"data": [';
    $large_json .= join(',', map { '"item' . $_ . '"' } (1..10000));
    $large_json .= ']}';
    TestServer::setup_response($large_json, 'application/json', 200);
    my $output = `perl $plugin_path -H localhost --port 8801 -p /test --type json -q "\$.data[0]" 2>&1`;
    my $exit_code = $? >> 8;
    like($output, qr/item1/, "Large JSON should be handled correctly");
    is($exit_code, 0, "Large JSON should not cause errors");
}

# Test 7: Invalid UTF-8 sequences
{
    my $invalid_utf8 = '{"status": "' . "\xFF\xFE" . 'invalid"}';
    TestServer::setup_response($invalid_utf8, 'application/json', 200);
    my $output = `perl $plugin_path -H localhost --port 8801 -p /test --type json -q "\$.status" 2>&1`;
    my $exit_code = $? >> 8;
    # Should either work (if parser handles it) or fail gracefully
    ok($exit_code == 0 || $output =~ /Failed to parse JSON/, "Invalid UTF-8 should be handled gracefully");
}

# Cleanup
kill 'TERM', $server_pid;
waitpid($server_pid, 0);

done_testing();
#!/usr/bin/env perl
# Network and timeout error tests for check_http_data.pl
# Tests various network failure scenarios

use strict;
use warnings;
use Test::More;
use FindBin;
use POSIX ":sys_wait_h";

BEGIN {
    plan tests => 8;
}

my $plugin_path = "$FindBin::Bin/../../check_http_data.pl";

# Test 1: DNS resolution failure
{
    my $output = `perl $plugin_path -H nonexistent.invalid.domain -p /test --type json -q "\$.status" 2>&1`;
    my $exit_code = $? >> 8;
    like($output, qr/HTTP request failed/, "DNS resolution failure should be reported");
    is($exit_code, 2, "DNS failure should exit with CRITICAL (2)");
}

# Test 2: Connection timeout (very short timeout)
{
    # Use a non-routable IP to force timeout
    my $output = `perl $plugin_path -H 10.255.255.1 -p /test --timeout 1 --type json -q "\$.status" 2>&1`;
    my $exit_code = $? >> 8;
    like($output, qr/HTTP request failed/, "Connection timeout should be reported");
    is($exit_code, 2, "Timeout should exit with CRITICAL (2)");
}

# Test 3: SSL/HTTPS without server
{
    my $output = `perl $plugin_path -H localhost --port 9443 --ssl -p /test --type json -q "\$.status" 2>&1`;
    my $exit_code = $? >> 8;
    like($output, qr/HTTP request failed/, "SSL connection failure should be reported");
    is($exit_code, 2, "SSL failure should exit with CRITICAL (2)");
}

# Test 4: Invalid hostname characters
{
    my $output = `perl $plugin_path -H "invalid hostname with spaces" -p /test --type json -q "\$.status" 2>&1`;
    my $exit_code = $? >> 8;
    like($output, qr/HTTP request failed/, "Invalid hostname should fail");
    is($exit_code, 2, "Invalid hostname should exit with CRITICAL (2)");
}

done_testing();
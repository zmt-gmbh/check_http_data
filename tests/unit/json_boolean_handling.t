#!/usr/bin/env perl
# Test for JSON::PP::Boolean handling bug fix
# Tests that boolean values are properly converted to strings

use strict;
use warnings;
use Test::More;
use FindBin;
use File::Temp qw/tempfile/;
use JSON::XS;

BEGIN {
    plan tests => 7;
}

# Mock test data simulating Nextcloud status.php response
my $test_json_data = {
    "installed" => JSON::XS::true,
    "maintenance" => JSON::XS::false,
    "needsDbUpgrade" => JSON::XS::false,
    "version" => "31.0.10.2",
    "versionstring" => "31.0.10",
    "edition" => "",
    "productname" => "Nextcloud",
    "extendedSupport" => JSON::XS::false
};

# Create temporary JSON file
my ($fh, $test_file) = tempfile(SUFFIX => '.json', UNLINK => 1);
print $fh JSON::XS->new->encode($test_json_data);
close $fh;

# Start simple HTTP server for testing
my $server_pid = fork();
if ($server_pid == 0) {
    # Child process - start HTTP server
    exec("python3", "-m", "http.server", "8999", "--directory", "/tmp") or die "Cannot start server: $!";
} elsif (!defined $server_pid) {
    die "Cannot fork: $!";
}

# Give server time to start
sleep 2;

my $plugin_path = "$FindBin::Bin/../../check_http_data.pl";
my $test_url = "localhost:8999/" . (split '/', $test_file)[-1];

# Test 1: Check that boolean values don't show as [JSON::PP::Boolean] in debug output
my $output1 = `perl $plugin_path -H localhost --port 8999 -p /$test_url --type json -q "\$.needsDbUpgrade" --debug 2>&1`;
unlike($output1, qr/\[JSON::PP::Boolean\]/, "Boolean values should not display as [JSON::PP::Boolean] in debug output");

# Test 2: Check that boolean values show as 'true'/'false' in debug output
like($output1, qr/false|true/, "Boolean values should show as 'true' or 'false' in debug output");

# Test 3: Boolean false should be converted to string "false" for string checks
my $output2 = `perl $plugin_path -H localhost --port 8999 -p /$test_url --type json -q "\$.needsDbUpgrade" -s "\$.needsDbUpgrade:^false\$:ok" 2>&1`;
like($output2, qr/OK/, "Boolean false should match string pattern '^false\$'");

# Test 4: Boolean true should be converted to string "true" 
my $output3 = `perl $plugin_path -H localhost --port 8999 -p /$test_url --type json -q "\$.installed" -s "\$.installed:^true\$:ok" 2>&1`;
like($output3, qr/OK/, "Boolean true should match string pattern '^true\$'");

# Test 5: Multiple boolean checks should work
my $output4 = `perl $plugin_path -H localhost --port 8999 -p /$test_url --type json -q "\$.maintenance" -q "\$.needsDbUpgrade" -s "\$.maintenance:^false\$:ok" -s "\$.needsDbUpgrade:^false\$:ok" 2>&1`;
like($output4, qr/OK/, "Multiple boolean string checks should work");

# Test 6: Boolean values should show actual values in normal output (not [JSON::PP::Boolean])
my $output5 = `perl $plugin_path -H localhost --port 8999 -p /$test_url --type json -q "\$.needsDbUpgrade" 2>&1`;
unlike($output5, qr/\[JSON::PP::Boolean\]/, "Normal output should not show [JSON::PP::Boolean]");
like($output5, qr/false/, "Normal output should show actual boolean value");

# Cleanup
kill 'TERM', $server_pid;
waitpid($server_pid, 0);

done_testing();
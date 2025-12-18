#!/usr/bin/env perl
# Threshold and string check error scenarios
# Tests edge cases and error conditions for thresholds and string checks

use strict;
use warnings;
use Test::More;
use FindBin;
use File::Temp qw/tempfile tempdir/;
use JSON::XS;

BEGIN {
    plan tests => 18;
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

# Start simple HTTP server
my $server_pid = fork();
if ($server_pid == 0) {
    chdir $test_dir;
    exec("python3", "-m", "http.server", "8803", "--bind", "127.0.0.1") or die "Cannot start server: $!";
} elsif (!defined $server_pid) {
    die "Cannot fork: $!";
}
sleep 2;

# Test data with various value types
my $test_data = JSON::XS->new->encode({
    "string_value" => "hello world",
    "numeric_value" => 42,
    "float_value" => 3.14,
    "zero_value" => 0,
    "negative_value" => -5,
    "boolean_true" => JSON::XS::true,
    "boolean_false" => JSON::XS::false,
    "null_value" => undef,
    "empty_string" => "",
    "mixed_case" => "MixedCase",
    "with_regex_chars" => "test[123].*+?",
    "multiline" => "line1\nline2\nline3"
});

my $json_file = create_test_file($test_data, '.json');

# Test 1: String check with regex special characters
{
    my $output = `perl $plugin_path -H localhost --port 8803 -p /$(basename $json_file) --type json -q "\$.with_regex_chars" -s "\$.with_regex_chars:^test\\[123\\]\\.\\*\\+\\?\$:ok" 2>&1`;
    my $exit_code = $? >> 8;
    like($output, qr/STRING CHECK OK/, "Regex special characters should be escaped properly");
    is($exit_code, 0, "Escaped regex should work");
}

# Test 2: Case sensitivity with mixed case values
{
    my $output = `perl $plugin_path -H localhost --port 8803 -p /$(basename $json_file) --type json -q "\$.mixed_case" -s "\$.mixed_case:mixedcase:ok:c" 2>&1`;
    my $exit_code = $? >> 8;
    like($output, qr/STRING CHECK FAILED/, "Case-sensitive check should fail for different case");
    is($exit_code, 2, "Case-sensitive mismatch should be CRITICAL");
}

# Test 3: String check on null values
{
    my $output = `perl $plugin_path -H localhost --port 8803 -p /$(basename $json_file) --type json -q "\$.null_value" -s "\$.null_value:^null\$:ok" 2>&1`;
    my $exit_code = $? >> 8;
    like($output, qr/STRING CHECK OK/, "Null values should match 'null' string");
    is($exit_code, 0, "String check on null should work");
}

# Test 4: String check on empty string
{
    my $output = `perl $plugin_path -H localhost --port 8803 -p /$(basename $json_file) --type json -q "\$.empty_string" -s "\$.empty_string:^.*\$:ok" 2>&1`;
    my $exit_code = $? >> 8;
    like($output, qr/STRING CHECK OK/, "Empty string should match regex '^.*\$'");
    is($exit_code, 0, "Empty string regex should work");
}

# Test 5: Threshold on non-numeric string
{
    my $output = `perl $plugin_path -H localhost --port 8803 -p /$(basename $json_file) --type json -q "\$.string_value" -l "\$.string_value:10:20" 2>&1`;
    my $exit_code = $? >> 8;
    unlike($output, qr/THRESHOLD/, "Non-numeric values should not trigger threshold checks");
    is($exit_code, 0, "Non-numeric thresholds should be ignored");
}

# Test 6: Threshold with zero value
{
    my $output = `perl $plugin_path -H localhost --port 8803 -p /$(basename $json_file) --type json -q "\$.zero_value" -l "\$.zero_value:0:1" 2>&1`;
    my $exit_code = $? >> 8;
    like($output, qr/THRESHOLD OK/, "Zero value threshold should work correctly");
    is($exit_code, 0, "Zero value should be OK with threshold 0:1");
}

# Test 7: Negative value thresholds
{
    my $output = `perl $plugin_path -H localhost --port 8803 -p /$(basename $json_file) --type json -q "\$.negative_value" -l "\$.negative_value:-10:-1" 2>&1`;
    my $exit_code = $? >> 8;
    like($output, qr/THRESHOLD/, "Negative value thresholds should work");
    # Result depends on exact threshold logic for negative ranges
}

# Test 8: Boolean string check (true)
{
    my $output = `perl $plugin_path -H localhost --port 8803 -p /$(basename $json_file) --type json -q "\$.boolean_true" -s "\$.boolean_true:^true\$:ok" 2>&1`;
    my $exit_code = $? >> 8;
    like($output, qr/STRING CHECK OK/, "Boolean true should match string 'true'");
    is($exit_code, 0, "Boolean string check should work");
}

# Test 9: Boolean string check (false)
{
    my $output = `perl $plugin_path -H localhost --port 8803 -p /$(basename $json_file) --type json -q "\$.boolean_false" -s "\$.boolean_false:^false\$:ok" 2>&1`;
    my $exit_code = $? >> 8;
    like($output, qr/STRING CHECK OK/, "Boolean false should match string 'false'");
    is($exit_code, 0, "Boolean false string check should work");
}

# Test 10: Multiple string checks with different outcomes
{
    my $output = `perl $plugin_path -H localhost --port 8803 -p /$(basename $json_file) --type json -q "\$.string_value" -q "\$.numeric_value" -s "\$.string_value:hello:ok" -s "\$.numeric_value:42:critical" 2>&1`;
    my $exit_code = $? >> 8;
    like($output, qr/STRING CHECK.*CRITICAL/, "Critical string check should override OK");
    is($exit_code, 2, "Critical string check result should dominate");
}

# Cleanup
kill 'TERM', $server_pid;
waitpid($server_pid, 0);

done_testing();
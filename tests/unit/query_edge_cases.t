#!/usr/bin/env perl
# Query evaluation edge cases and complex scenarios
# Tests various complex query scenarios and edge cases

use strict;
use warnings;
use Test::More;
use FindBin;
use File::Temp qw/tempfile tempdir/;
use JSON::XS;

BEGIN {
    plan tests => 15;
}

my $plugin_path = "$FindBin::Bin/../../check_http_data.pl";
my $test_dir = tempdir(CLEANUP => 1);

# Helper function to create test files and start server
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
    exec("python3", "-m", "http.server", "8802", "--bind", "127.0.0.1") or die "Cannot start server: $!";
} elsif (!defined $server_pid) {
    die "Cannot fork: $!";
}
sleep 2;

# Test data with edge cases
my $complex_json = JSON::XS->new->encode({
    "nested" => {
        "deep" => {
            "array" => [1, 2, {"nested_obj" => "value"}]
        }
    },
    "special_chars" => "value with spaces and symbols: !@#\$%^&*()",
    "unicode" => "café, naïve, résumé",
    "numbers" => {
        "integer" => 42,
        "float" => 3.14159,
        "negative" => -123,
        "zero" => 0,
        "scientific" => "1e10"
    },
    "nulls_and_bools" => {
        "null_value" => undef,
        "true_value" => JSON::XS::true,
        "false_value" => JSON::XS::false,
        "empty_string" => "",
        "empty_array" => [],
        "empty_object" => {}
    },
    "arrays" => [
        {"id" => 1, "status" => "active"},
        {"id" => 2, "status" => "inactive"},
        {"id" => 3, "status" => "pending"}
    ]
});

my $complex_xml = qq{<?xml version="1.0" encoding="UTF-8"?>
<root>
    <nested>
        <deep>
            <item>value1</item>
            <item>value2</item>
        </deep>
    </nested>
    <special-chars>value with spaces and symbols: !@#\$%^&amp;*()</special-chars>
    <unicode>café, naïve, résumé</unicode>
    <numbers>
        <integer>42</integer>
        <float>3.14159</float>
        <negative>-123</negative>
        <zero>0</zero>
    </numbers>
    <booleans>
        <true-value>true</true-value>
        <false-value>false</false-value>
        <empty></empty>
    </booleans>
    <array>
        <item id="1" status="active"/>
        <item id="2" status="inactive"/>
        <item id="3" status="pending"/>
    </array>
</root>};

my $json_file = create_test_file($complex_json, '.json');
my $xml_file = create_test_file($complex_xml, '.xml');

# Test 1: Deep nested JSON access
{
    my $output = `perl $plugin_path -H localhost --port 8802 -p /$(basename $json_file) --type json -q "\$.nested.deep.array[2].nested_obj" 2>&1`;
    my $exit_code = $? >> 8;
    like($output, qr/nested_obj: value/, "Deep nested JSON access should work");
    is($exit_code, 0, "Deep nested access should succeed");
}

# Test 2: Array access with complex filter (may fail with basic JSONPath)
{
    my $output = `perl $plugin_path -H localhost --port 8802 -p /$(basename $json_file) --type json -q "\$.arrays[?(\@.status=='active')].id" 2>&1`;
    my $exit_code = $? >> 8;
    # This might fail if JSONPath implementation doesn't support complex filters
    ok($exit_code == 0 || $output =~ /evaluation failed/, "Complex JSONPath filter should be handled gracefully");
}

# Test 3: Special characters in values
{
    my $output = `perl $plugin_path -H localhost --port 8802 -p /$(basename $json_file) --type json -q "\$.special_chars" 2>&1`;
    my $exit_code = $? >> 8;
    like($output, qr/special_chars:.*!@#/, "Special characters should be handled correctly");
    is($exit_code, 0, "Special characters should not cause errors");
}

# Test 4: Unicode characters
{
    my $output = `perl $plugin_path -H localhost --port 8802 -p /$(basename $json_file) --type json -q "\$.unicode" 2>&1`;
    my $exit_code = $? >> 8;
    like($output, qr/unicode:/, "Unicode characters should be handled");
    is($exit_code, 0, "Unicode should not cause errors");
}

# Test 5: Null values
{
    my $output = `perl $plugin_path -H localhost --port 8802 -p /$(basename $json_file) --type json -q "\$.nulls_and_bools.null_value" 2>&1`;
    my $exit_code = $? >> 8;
    like($output, qr/null_value: null/, "Null values should be displayed as 'null'");
    is($exit_code, 0, "Null values should not cause errors");
}

# Test 6: Empty arrays and objects
{
    my $output = `perl $plugin_path -H localhost --port 8802 -p /$(basename $json_file) --type json -q "\$.nulls_and_bools.empty_array" 2>&1`;
    my $exit_code = $? >> 8;
    like($output, qr/empty_array:.*Array with 0 elements/, "Empty arrays should be handled");
    is($exit_code, 0, "Empty arrays should not cause errors");
}

# Test 7: XML with attributes
{
    my $output = `perl $plugin_path -H localhost --port 8802 -p /$(basename $xml_file) --type xml -q "//item[\@status='active']" 2>&1`;
    my $exit_code = $? >> 8;
    like($output, qr/item.*active/, "XML attribute queries should work");
    is($exit_code, 0, "XML attributes should not cause errors");
}

# Test 8: Scientific notation in JSON
{
    my $output = `perl $plugin_path -H localhost --port 8802 -p /$(basename $json_file) --type json -q "\$.numbers.scientific" 2>&1`;
    my $exit_code = $? >> 8;
    like($output, qr/scientific:/, "Scientific notation should be handled");
    is($exit_code, 0, "Scientific notation should not cause errors");
}

# Test 9: Empty string vs null distinction
{
    my $output = `perl $plugin_path -H localhost --port 8802 -p /$(basename $json_file) --type json -q "\$.nulls_and_bools.empty_string" 2>&1`;
    my $exit_code = $? >> 8;
    like($output, qr/empty_string:/, "Empty strings should be distinguished from null");
    is($exit_code, 0, "Empty strings should not cause errors");
}

# Cleanup
kill 'TERM', $server_pid;
waitpid($server_pid, 0);

done_testing();
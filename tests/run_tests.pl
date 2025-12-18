#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Test::Output;
use Capture::Tiny 'capture';
use Cwd 'abs_path';
use File::Basename 'dirname';
use lib dirname(abs_path($0)) . '/..';

# Test script runner for check_http_data.pl
# Runs all unit and integration tests

BEGIN {
    # Check if required test modules are available
    eval "use Test::More; use Test::Output; use Capture::Tiny; 1" or do {
        print "SKIP: Missing required test modules. Install with:\n";
        print "sudo apt-get install libtest-output-perl libcapture-tiny-perl\n";
        print "or\n";
        print "cpan Test::More Test::Output Capture::Tiny\n";
        exit 0;
    };
}

my $script_dir = dirname(abs_path($0));
my $main_script = "$script_dir/../check_http_data.pl";

unless (-f $main_script && -x $main_script) {
    die "ERROR: Cannot find executable script at $main_script\n";
}

# Test that the script exists and is executable
ok(-f $main_script, "Main script file exists");
ok(-x $main_script, "Main script is executable");

# Test syntax check
my ($stdout, $stderr, $exit) = capture {
    system("perl -c '$main_script' 2>&1");
};
is($exit, 0, "Script passes syntax check");

# Test help output
($stdout, $stderr, $exit) = capture {
    system("perl '$main_script' --help 2>&1");
};
like($stdout, qr/Usage:/, "Help output contains usage information");
like($stdout, qr/JSONPath|XPath/, "Help mentions supported query types");

# Test samples output
($stdout, $stderr, $exit) = capture {
    system("perl '$main_script' --samples 2>&1");
};
like($stdout, qr/DETAILED USAGE EXAMPLES/, "Samples output contains examples");
is($exit, 0, "Samples command exits successfully");

# Test version output
($stdout, $stderr, $exit) = capture {
    system("perl '$main_script' --version 2>&1");
};
like($stdout, qr/check_http_data\.pl \d+\.\d+/, "Version output format correct");

# Test missing required parameters
($stdout, $stderr, $exit) = capture {
    system("perl '$main_script' 2>&1");
};
isnt($exit, 0, "Script fails when required parameters missing");
like($stdout, qr/Missing argument/, "Error message mentions missing arguments");

print "\n=== Running Unit Tests ===\n";
my @unit_tests = glob("$script_dir/unit/*.t");
foreach my $test_file (sort @unit_tests) {
    my $test_name = File::Basename::basename($test_file);
    print "Running: $test_name\n";
    system("perl '$test_file'");
}

print "\n=== Running Integration Tests ===\n";
my @integration_tests = glob("$script_dir/integration/*.t");
foreach my $test_file (sort @integration_tests) {
    my $test_name = File::Basename::basename($test_file);
    print "Running: $test_name\n";
    system("perl '$test_file'");
}

done_testing();

print "\n=== Test Summary ===\n";
print "Basic functionality tests completed.\n";
print "Run individual test files for detailed output:\n";
print "  perl tests/unit/parameter_parsing.t\n";
print "  perl tests/unit/case_sensitivity.t\n";
print "  perl tests/integration/public_api.t\n";
print "  perl tests/integration/case_sensitivity_integration.t\n";
print "\n";
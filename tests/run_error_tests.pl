#!/usr/bin/env perl
# Comprehensive test runner for all error scenarios
# Runs all error handling tests and provides summary

use strict;
use warnings;
use FindBin;
use File::Find;
use TAP::Parser;
use TAP::Parser::Aggregator;

print "=== Comprehensive Error Handling Test Suite ===\n\n";

my $test_dir = "$FindBin::Bin/unit";
my @test_files;

# Find all test files
find(sub {
    push @test_files, $File::Find::name if /\.t$/ && -f && -x;
}, $test_dir);

@test_files = sort @test_files;

print "Found " . scalar(@test_files) . " test files:\n";
foreach my $file (@test_files) {
    my $basename = $file;
    $basename =~ s/.*\///;
    print "  - $basename\n";
}
print "\n";

my $aggregator = TAP::Parser::Aggregator->new;
$aggregator->start();

my $total_tests = 0;
my $failed_tests = 0;

foreach my $test_file (@test_files) {
    my $basename = $test_file;
    $basename =~ s/.*\///;
    
    print "Running $basename... ";
    
    my $parser = TAP::Parser->new({ source => $test_file });
    $aggregator->add($basename, $parser);
    
    my $results = $parser->run;
    my $planned = $parser->tests_planned || 0;
    my $passed = $parser->passed || 0;
    my $failed = $parser->failed || 0;
    
    $total_tests += $planned;
    $failed_tests += $failed;
    
    if ($failed == 0) {
        print "PASS ($passed/$planned)\n";
    } else {
        print "FAIL ($passed/$planned, $failed failed)\n";
    }
}

$aggregator->stop();

print "\n=== Test Summary ===\n";
print "Total test files: " . scalar(@test_files) . "\n";
print "Total tests: $total_tests\n";
print "Passed: " . ($total_tests - $failed_tests) . "\n";
print "Failed: $failed_tests\n";

if ($failed_tests == 0) {
    print "\n✅ ALL TESTS PASSED - Error handling is comprehensive!\n";
    exit 0;
} else {
    print "\n❌ Some tests failed - Error handling needs improvement\n";
    exit 1;
}
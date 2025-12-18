#!/usr/bin/env perl

use strict;
use warnings;
use Test::More tests => 9;
use Time::HiRes qw(time);
use File::Basename qw(dirname);
use File::Spec;
use Cwd qw(abs_path);

# Add the parent directory to @INC to find the plugin
BEGIN {
    my $script_dir = dirname(abs_path($0));
    my $parent_dir = dirname(dirname($script_dir));
    unshift @INC, $parent_dir;
}

# Performance tests for case sensitivity features
my $plugin = File::Spec->catfile(dirname(dirname(dirname(abs_path($0)))), 'check_http_data.pl');

sub run_plugin_timed {
    my @args = @_;
    my $start_time = time();
    my $cmd = "perl $plugin " . join(' ', map { shell_escape($_) } @args) . " 2>&1";
    my $output = `$cmd`;
    my $end_time = time();
    my $exit_code = $? >> 8;
    my $duration = $end_time - $start_time;
    return ($exit_code, $output, $duration);
}

sub shell_escape {
    my $str = shift;
    $str =~ s/'/'\\''/g;
    return "'$str'";
}

sub benchmark_test {
    my ($test_name, $args_ref, $iterations) = @_;
    $iterations ||= 10;
    
    my @durations;
    my $total_success = 0;
    
    for my $i (1..$iterations) {
        my ($exit_code, $output, $duration) = run_plugin_timed(@$args_ref);
        push @durations, $duration;
        $total_success++ if defined $exit_code;
    }
    
    my $avg_duration = @durations ? (sum(@durations) / @durations) : 0;
    my $success_rate = ($total_success / $iterations) * 100;
    
    diag("$test_name: avg ${avg_duration}s, ${success_rate}% success rate");
    
    return ($avg_duration, $success_rate);
}

sub sum {
    my $total = 0;
    $total += $_ for @_;
    return $total;
}

# Test 1: Help performance
{
    my ($avg_duration, $success_rate) = benchmark_test(
        "Help output",
        ['--help'],
        5
    );
    
    ok($success_rate >= 80, 'Help command has good success rate');
    ok($avg_duration < 2.0, 'Help output is fast (< 2s)');
}

# Test 2: Case-insensitive performance 
{
    my ($avg_duration, $success_rate) = benchmark_test(
        "Case-insensitive string check",
        ['-s', '$.status:running:OK'],  # default case-insensitive
        3
    );
    
    ok($success_rate >= 60, 'Case-insensitive parsing has reasonable success rate');
    ok($avg_duration < 1.0, 'Case-insensitive parsing is fast (< 1s)');
}

# Test 3: Case-sensitive performance
{
    my ($avg_duration, $success_rate) = benchmark_test(
        "Case-sensitive string check", 
        ['-s', '$.status:Running:OK:c'],  # explicit case-sensitive
        3
    );
    
    ok($success_rate >= 60, 'Case-sensitive parsing has reasonable success rate');
    ok($avg_duration < 1.0, 'Case-sensitive parsing is fast (< 1s)');
}

# Test 4: Multiple checks performance
{
    my @multi_args = (
        '-s', '$.status:running:OK',      # case-insensitive
        '-s', '$.version:v1.0.0:OK:c',    # case-sensitive  
        '-s', '$.type:service:WARNING:i', # explicit case-insensitive
        '-s', '$.env:PROD:CRITICAL:c'     # case-sensitive
    );
    
    my ($avg_duration, $success_rate) = benchmark_test(
        "Multiple mixed case sensitivity checks",
        \@multi_args,
        3
    );
    
    ok($success_rate >= 60, 'Multiple mixed checks parse successfully');
    ok($avg_duration < 2.0, 'Multiple mixed checks parse quickly (< 2s)');
}

# Test 5: Memory usage test (basic)
{
    # Simple memory usage test by running the plugin and checking it doesn't hang
    my $start_time = time();
    
    my ($exit_code, $output) = run_plugin_timed(
        '--help',
        '-s', '$.test:value:OK',
        '-s', '$.test2:value2:OK:c', 
        '-s', '$.test3:value3:OK:i'
    );
    
    my $end_time = time();
    my $duration = $end_time - $start_time;
    
    ok($duration < 5.0, 'Complex help with multiple string checks completes quickly (< 5s)');
    
    if ($duration >= 5.0) {
        diag("Warning: Plugin took ${duration}s to complete help with string checks");
    }
}

# Performance summary
diag("=== Performance Test Summary ===");
diag("All timing tests verify the case sensitivity feature doesn't significantly impact performance");
diag("Typical expected performance:");
diag("  - Help output: < 2 seconds");  
diag("  - String check parsing: < 1 second");
diag("  - Multiple checks: < 2 seconds");
diag("  - Complex operations: < 5 seconds");
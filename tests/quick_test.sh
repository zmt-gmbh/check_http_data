#!/bin/bash
# Quick test runner - runs basic tests without network dependencies

cd "$(dirname "$0")" || exit 1

echo "🧪 Running Check HTTP Data Tests"
echo "================================"

# Run syntax check
echo "✅ Syntax Check:"
if perl -c ../check_http_data.pl 2>/dev/null; then
    echo "   ✓ Perl syntax OK"
else
    echo "   ✗ Perl syntax errors found"
    exit 1
fi

# Run unit tests only (no network required)
echo ""
echo "✅ Unit Tests:"
if perl unit/parameter_parsing.t >/dev/null 2>&1; then
    echo "   ✓ Parameter parsing tests passed"
else
    echo "   ✗ Parameter parsing tests failed"
    echo "   Run: perl tests/unit/parameter_parsing.t for details"
fi

# Check basic functionality
echo ""
echo "✅ Basic Functionality:"

# Test help
if ../check_http_data.pl --help >/dev/null 2>&1; then
    echo "   ✓ Help output works"
else
    echo "   ✗ Help output failed"
fi

# Test samples
if ../check_http_data.pl --samples >/dev/null 2>&1; then
    echo "   ✓ Samples output works"
else
    echo "   ✗ Samples output failed"
fi

# Test error handling
if ! ../check_http_data.pl >/dev/null 2>&1; then
    echo "   ✓ Error handling works (missing parameters detected)"
else
    echo "   ✗ Error handling failed"
fi

echo ""
echo "🎯 Quick Tests Completed!"
echo ""
echo "For full test suite including network tests:"
echo "   perl run_tests.pl"
echo ""
echo "For individual test suites:"
echo "   perl unit/parameter_parsing.t"
echo "   perl integration/public_api.t"
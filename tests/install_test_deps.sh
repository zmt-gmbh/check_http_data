#!/bin/bash
# install_test_deps.sh - Install test dependencies for check_http_data.pl

set -e

echo "Installing Perl test dependencies for check_http_data.pl..."

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    echo "This script requires root privileges. Please run with sudo:"
    echo "sudo $0"
    exit 1
fi

# Update package list
echo "Updating package list..."
apt-get update

# Install required Perl testing modules
echo "Installing Perl test modules..."
apt-get install -y \
    libtest-more-perl \
    libtest-output-perl \
    libcapture-tiny-perl \
    libhttp-server-simple-perl \
    libdata-dumper-perl

echo ""
echo "✅ Test dependencies installed successfully!"
echo ""
echo "You can now run tests with:"
echo "  cd $(pwd)"
echo "  perl tests/run_tests.pl"
echo ""
echo "Or run individual test suites:"
echo "  perl tests/unit/parameter_parsing.t"
echo "  perl tests/integration/mock_http.t"
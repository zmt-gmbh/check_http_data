# Test Configuration and Setup

## Prerequisites

Before running tests, ensure you have the required Perl testing modules installed:

```bash
# Install test dependencies via apt (recommended)
sudo apt-get install libtest-output-perl libcapture-tiny-perl libhttp-server-simple-perl

# OR install via CPAN
sudo cpan Test::More Test::Output Capture::Tiny HTTP::Server::Simple::CGI
```

## Test Structure

```
tests/
├── run_tests.pl              # Main test runner
├── unit/                     # Unit tests
│   └── parameter_parsing.t   # Parameter validation tests
├── integration/              # Integration tests  
│   └── mock_http.t          # HTTP server mock tests
└── data/                    # Test data files
    ├── sample.json          # Valid JSON response
    ├── sample.xml           # Valid XML response  
    ├── error_response.json  # Error JSON response
    ├── error_response.xml   # Error XML response
    ├── malformed.json       # Invalid JSON for error testing
    └── malformed.xml        # Invalid XML for error testing
```

## Running Tests

### Run All Tests
```bash
cd /home/ggz/store/work/Icinga/check_http_data
perl tests/run_tests.pl
```

### Run Individual Test Suites
```bash
# Unit tests only
perl tests/unit/parameter_parsing.t

# Integration tests only  
perl tests/integration/mock_http.t
```

### Test Output
- **TAP (Test Anything Protocol)** format output
- Exit codes: 0 = all tests pass, non-zero = failures
- Detailed failure information and diagnostics

## Test Coverage

### Unit Tests (`parameter_parsing.t`)
- ✅ Parameter validation (hostname, path, query)
- ✅ Invalid parameter handling  
- ✅ String check format validation
- ✅ URL construction testing
- ✅ Help and documentation output
- ✅ Timeout parameter validation

### Integration Tests (`mock_http.t`)
- ✅ JSON response parsing and queries
- ✅ XML response parsing and XPath queries
- ✅ Threshold checking (OK/WARNING/CRITICAL)
- ✅ String validation checks
- ✅ Performance data generation
- ✅ HTTP error handling
- ✅ Malformed data handling

### Test Data Files
- **sample.json**: Complete JSON with system metrics, services, network data
- **sample.xml**: XML status with network, VoIP, hardware data
- **error_response.json/xml**: Simulated error conditions
- **malformed.json/xml**: Invalid syntax for error testing

## Extending Tests

### Adding New Unit Tests
1. Create new `.t` file in `tests/unit/`
2. Use `Test::More` framework
3. Follow existing naming conventions
4. Update `run_tests.pl` to include new test

### Adding New Integration Tests
1. Create new `.t` file in `tests/integration/`
2. Use mock HTTP server pattern from `mock_http.t`
3. Create corresponding test data in `tests/data/`
4. Test different scenarios (success, warning, critical, errors)

### Adding New Test Data
1. Create realistic sample responses in `tests/data/`
2. Include both positive and negative test cases
3. Document expected query results
4. Test edge cases and boundary conditions

## Troubleshooting

### Common Issues

**Missing Dependencies:**
```bash
# Install missing Perl modules
sudo apt-get install libtest-*-perl
# or use cpan
sudo cpan install Test::More
```

**Permission Issues:**
```bash
chmod +x tests/run_tests.pl
chmod +x tests/unit/*.t
chmod +x tests/integration/*.t
```

**Network/Port Issues:**
- Integration tests use port 18080 for mock server
- Ensure port is available during testing
- Tests will skip if HTTP::Server::Simple not available

### Debug Mode
Add debugging output to tests:
```perl
use Data::Dumper;
diag "Debug info: " . Dumper($test_data);
```

## Continuous Integration

For CI/CD integration:
```bash
#!/bin/bash
# ci_test.sh
set -e

echo "Installing dependencies..."
sudo apt-get update
sudo apt-get install -y libtest-output-perl libcapture-tiny-perl libhttp-server-simple-perl

echo "Running tests..."
cd /path/to/check_http_data
perl tests/run_tests.pl

echo "Tests completed successfully!"
```
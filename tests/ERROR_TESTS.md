# Error Handling Test Suite

This directory contains comprehensive tests for all possible error scenarios in the `check_http_data.pl` plugin.

## Test Files Overview

### `comprehensive_error_handling.t`
Tests fundamental error conditions:
- ✅ Invalid type parameter validation
- ✅ Invalid string check format validation
- ✅ Invalid string check status validation  
- ✅ Invalid string check flag validation
- ✅ HTTP connection failures (wrong port)
- ✅ HTTP 404 errors
- ✅ Malformed JSON parsing errors
- ✅ Malformed XML parsing errors
- ✅ Auto-detection failures
- ✅ Invalid JSONPath syntax errors
- ✅ Invalid XPath syntax errors
- ✅ JSONPath returns no results
- ✅ XPath returns no results

### `network_errors.t`
Tests network-related failures:
- ✅ DNS resolution failures
- ✅ Connection timeouts
- ✅ SSL/HTTPS connection failures
- ✅ Invalid hostname handling

### `content_edge_cases.t`
Tests content parsing edge cases:
- ✅ JSON with wrong Content-Type headers
- ✅ XML with wrong Content-Type headers
- ✅ Empty response handling
- ✅ JSON with BOM (Byte Order Mark)
- ✅ HTTP 500 server errors
- ✅ Large response handling
- ✅ Invalid UTF-8 sequence handling

### `query_edge_cases.t`
Tests complex query scenarios:
- ✅ Deep nested JSON access
- ✅ Complex JSONPath filters
- ✅ Special characters in values
- ✅ Unicode character handling
- ✅ Null value handling
- ✅ Empty arrays and objects
- ✅ XML attribute queries
- ✅ Scientific notation in JSON
- ✅ Empty string vs null distinction

### `threshold_string_errors.t`
Tests threshold and string check edge cases:
- ✅ Regex special character escaping
- ✅ Case sensitivity handling
- ✅ String checks on null values
- ✅ String checks on empty strings
- ✅ Thresholds on non-numeric values
- ✅ Zero value threshold handling
- ✅ Negative value thresholds
- ✅ Boolean string matching
- ✅ Multiple checks with different outcomes

### `json_boolean_handling.t`
Tests JSON boolean value handling:
- ✅ Boolean values display correctly (not `[JSON::PP::Boolean]`)
- ✅ Boolean threshold evaluation (true=1, false=0)
- ✅ Boolean string pattern matching
- ✅ Mixed boolean scenarios

## Running Tests

### Run All Error Tests
```bash
./tests/run_error_tests.pl
```

### Run Individual Test Files
```bash
./tests/unit/comprehensive_error_handling.t
./tests/unit/network_errors.t
./tests/unit/content_edge_cases.t
./tests/unit/query_edge_cases.t
./tests/unit/threshold_string_errors.t
./tests/unit/json_boolean_handling.t
```

### Run Quick Test Suite
```bash
./tests/quick_test.sh
```

## Test Coverage Summary

| Error Category | Test Coverage | Status |
|---------------|---------------|---------|
| Parameter Validation | ✅ Complete | 4 tests |
| Network Failures | ✅ Complete | 4 tests |
| HTTP Errors | ✅ Complete | 3 tests |
| Content Parsing | ✅ Complete | 7 tests |
| Query Evaluation | ✅ Complete | 6 tests |
| Content Edge Cases | ✅ Complete | 6 tests |
| Boolean Handling | ✅ Complete | 6 tests |
| Threshold Logic | ✅ Complete | 9 tests |
| String Matching | ✅ Complete | 9 tests |
| **Total Coverage** | **✅ 54+ tests** | **Complete** |

## Error Exit Codes Tested

- **0 (OK)**: Normal successful execution
- **1 (WARNING)**: Warning thresholds exceeded, warning string matches
- **2 (CRITICAL)**: Critical thresholds exceeded, critical string matches, parsing failures, network errors
- **3 (UNKNOWN)**: Invalid parameters, configuration errors

## Expected Test Behavior

All tests are designed to:
1. **Fail gracefully** - No crashes or undefined behavior
2. **Return appropriate exit codes** - Correct Nagios/Icinga status codes
3. **Provide meaningful messages** - Clear error descriptions
4. **Handle edge cases** - Unicode, special characters, large data
5. **Validate input** - Parameter format checking
6. **Test error paths** - Network failures, malformed data

## Dependencies

Tests require:
- Perl with Test::More
- Python3 (for HTTP test servers)
- JSON::XS, XML::LibXML, LWP::UserAgent
- Network access for some tests

## Test Environment

Tests use temporary files and local HTTP servers on high-numbered ports (8800-8803) to avoid conflicts with system services.
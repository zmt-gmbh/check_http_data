# HTTP Data Monitor for Icinga2/Nagios

A comprehensive Perl monitoring plugin for Icinga2 and Nagios that fetches JSON or XML data via HTTP/HTTPS and evaluates multiple JSONPath/XPath expressions with configurable thresholds, string pattern matching, and performance data generation.

## Author

**Grischa Zengel**

## Features

- **Dual Format Support**: Monitor both JSON (JSONPath) and XML (XPath) endpoints
- **Flexible Query Support**: Multiple JSONPath and XPath expressions in a single request
- **String Pattern Matching**: Regex-based string checks with case sensitivity control
- **Numeric Thresholds**: Configure warning and critical thresholds per query
- **Performance Data**: Automatic performance data generation for numeric values
- **HTTP/HTTPS Support**: Works with both protocols and custom ports
- **Reverse Proxy Support**: Custom Host header support for load balancer scenarios
- **Case Sensitivity Control**: Default case-insensitive string matching with explicit control
- **Debug Mode**: Explore data structure and discover available paths
- **Comprehensive Help**: Built-in examples and syntax reference for both formats
- **Icinga2 Ready**: Complete CheckCommand and Service templates

## License

This nagios plugin is free software, and comes with ABSOLUTELY NO WARRANTY.
It may be used, redistributed and/or modified under the terms of the GNU
General Public License (see http://www.fsf.org/licensing/licenses/gpl.txt).

## Requirements

### Perl Modules
```bash
# Debian/Ubuntu
sudo apt-get install libmonitoring-plugin-perl libwww-perl libjson-xs-perl libjson-path-perl libxml-libxml-perl

# CentOS/RHEL/Rocky/AlmaLinux
sudo yum install perl-Monitoring-Plugin perl-LWP-Protocol-https perl-JSON-XS perl-JSON-Path perl-XML-LibXML

# Alpine Linux
sudo apk add perl-monitoring-plugin perl-lwp-protocol-https perl-json-xs perl-json-path perl-xml-libxml
```

## Installation

1. **Download the script:**
   ```bash
   wget https://raw.githubusercontent.com/zmt-gmbh/check_http_data/main/check_http_data.pl
   chmod +x check_http_data.pl
   ```

2. **Install to Icinga2 plugin directory:**
   ```bash
   sudo cp check_http_data.pl /usr/lib/nagios/plugins/
   sudo chown icinga:icinga /usr/lib/nagios/plugins/check_http_data.pl
   ```

3. **Test the installation:**
   ```bash
   /usr/lib/nagios/plugins/check_http_data.pl --help
   ```

## Usage

### Basic Syntax
```bash
check_http_data.pl -H <hostname> -p <path> -q <query1> [-q <query2>] [options]
```

### Quick Examples

**JSON API monitoring:**
```bash
./check_http_data.pl -H api.example.com -p /status -q '$.status' --type json
```

**XML endpoint monitoring:**
```bash
./check_http_data.pl -H router.example.com -p /status.xml -q '//inet/state' --type xml
```

**Multiple values with thresholds:**
```bash
./check_http_data.pl -H api.example.com -p /metrics \
  -q '$.cpu.usage' \
  -q '$.memory.used' \
  -l '$.cpu.usage:80:95' \
  -l '$.memory.used:85:95' \
  --perfdata
```

**String pattern matching (case-insensitive by default):**
```bash
./check_http_data.pl -H api.example.com -p /health \
  -q '$.status' \
  -s '$.status:healthy:OK'
```

**Case-sensitive string matching:**
```bash
./check_http_data.pl -H api.example.com -p /health \
  -q '$.status' \
  -s '$.status:HEALTHY:OK:c'
```

### Command Line Options

| Option | Description |
|--------|-------------|
| `-H, --hostname` | Hostname or IP address |
| `-p, --path` | URL path (e.g., `/api/status.json`, `/status.xml`) |
| `-q, --query` | JSONPath or XPath expression (can be used multiple times) |
| `-l, --limit` | Numeric thresholds in format `path:warning:critical` |
| `-s, --string-checks` | String pattern checks with case sensitivity |
| `-T, --type` | Force data type: json, xml, or auto-detect |
| `--perfdata` | Generate performance data |
| `--port` | Port number (default: 80) |
| `--ssl` | Use HTTPS |
| `--host-header` | Override Host header (useful for reverse proxy scenarios) |
| `--timeout` | Request timeout in seconds (default: 30) |
| `--debug` | Show data structure and available paths |
| `--samples` | Show detailed usage examples |
| `--help` | Show help with JSONPath/XPath syntax reference |

### JSONPath and XPath Examples

The script supports both JSONPath for JSON and XPath 1.0 for XML:

**JSONPath Examples:**
```bash
# Basic element selection
$.status                     # Root level 'status' field
$.services.database.status   # Nested object access
$.users[0].name              # Array element access
$.services.*.status          # Wildcard for any service status
$..[?(@.type=='error')]      # Filter objects with type='error'
```

**XPath Examples:**
```bash
# Basic element selection
//element                    # Find 'element' anywhere
/root/child                  # Direct path from root
//parent/child               # Find 'child' under any 'parent'
//element[1]                 # First occurrence
//element[@attr='value']     # Element with specific attribute
//element[text()='value']    # Element with specific text
count(//element)             # Count elements
```

## Real-World Examples

### JSON API Monitoring

For monitoring a REST API status endpoint:

```bash
./check_http_data.pl -H api.myservice.com -p /v1/status \
  -q '$.status' -q '$.database.connected' -q '$.cache.hits' \
  -s '$.status:healthy:OK' \
  -s '$.database.connected:true:CRITICAL' \
  -l '$.cache.hits:1000:inf:WARNING:0:999:CRITICAL'
```

**Sample JSON response:**
```json
{
  "status": "healthy",
  "database": {
    "connected": true,
    "response_time": 23
  },
  "cache": {
    "hits": 1205,
    "misses": 45
  }
}
```

### XML Device Monitoring: Deutsche Telekom Digitalisierungsbox (T-Box)

For monitoring a T-Box router status:

```bash
./check_http_data.pl -H t-box.local -p /cgi-bin/status.xml \
  -q "//url/version" \
  -q "//inet/state" \
  -q "//voip/registered" \
  -q "//wlan/wlanStations" \
  -l "//inet/state:1:2" \
  -l "//voip/registered:1:" \
  --perfdata
```

**Sample XML structure:**
```xml
<status>
  <url><version>1113115</version></url>
  <inet><state>1</state></inet>
  <voip>
    <count>2</count>
    <registered>2</registered>
  </voip>
  <wlan><wlanStations>3</wlanStations></wlan>
</status>
```

### Reverse Proxy Monitoring

Monitor service behind load balancer by connecting to LB IP but setting correct Host header:

```bash
./check_http_data.pl -H 192.168.1.100 -p /api/status \
  --host-header api.example.com \
  -q '$.status' \
  -s '$.status:healthy:OK'
```

## Icinga2 Configuration

### 1. CheckCommand Definition

Create `/etc/icinga2/conf.d/check_http_data.conf`:

```icinga2
object CheckCommand "check_http_data" {
  import "plugin-check-command"
  
  command = [ PluginDir + "/check_http_data.pl" ]
  
  arguments = {
    "-H" = "$data_hostname$"
    "-p" = "$data_path$"
    "-q" = {
      value = "$data_query$"
      repeat_key = true
    }
    "-l" = {
      value = "$data_limits$"
      repeat_key = true
    }
    "-s" = {
      value = "$data_string_checks$"
      repeat_key = true
    }
    "-T" = "$data_type$"
    "--perfdata" = { set_if = "$data_perfdata$" }
    "--port" = "$data_port$"
    "--ssl" = { set_if = "$data_ssl$" }
    "--host-header" = "$data_host_header$"
    "--timeout" = "$data_timeout$"
  }
  
  vars.data_hostname = "$host.address$"
  vars.data_perfdata = true
  vars.data_port = 80
  vars.data_timeout = 30
}
```

### 2. Service Template

```icinga2
template Service "http-data-service" {
  import "generic-service"
  check_command = "check_http_data"
  vars.data_perfdata = true
}
```

### 3. Service Examples

**JSON API monitoring:**
```icinga2
apply Service "api-health-check" {
  import "http-data-service"
  
  vars.data_path = "/v1/health"
  vars.data_type = "json"
  vars.data_query = [
    "$.status",
    "$.database.connected",
    "$.cache.hits"
  ]
  vars.data_string_checks = [
    "$.status:healthy:OK",
    "$.database.connected:true:CRITICAL"
  ]
  vars.data_limits = [
    "$.cache.hits:1000:5000:WARNING:0:999:CRITICAL"
  ]
  
  assign where host.vars.api_monitoring == true
}
```

**T-Box XML monitoring:**
```icinga2
apply Service "t-box-status" {
  import "http-data-service"
  
  vars.data_path = "/cgi-bin/status.xml"
  vars.data_type = "xml"
  vars.data_query = [
    "//inet/state",
    "//voip/registered", 
    "//wlan/wlanStations",
    "//url/version"
  ]
  vars.data_limits = [
    "//inet/state:1:2",
    "//voip/registered:1:",
    "//wlan/wlanStations:20:50"
  ]
  
  assign where host.vars.device_type == "t-box"
}
```

**Load balancer with custom Host header:**
```icinga2
apply Service "api-behind-lb" {
  import "http-data-service"
  
  vars.data_path = "/api/status"
  vars.data_type = "json"
  vars.data_host_header = "api.example.com"
  vars.data_query = [ "$.status" ]
  vars.data_string_checks = [ "$.status:healthy:OK" ]
  
  assign where host.vars.behind_loadbalancer == true
}
```

### 4. Host Definition

```icinga2
object Host "my-api-server" {
  import "generic-host"
  address = "192.168.1.10"
  vars.api_monitoring = true
}

object Host "my-t-box" {
  import "generic-host"
  address = "192.168.1.1"
  vars.device_type = "t-box"
}

object Host "my-lb-endpoint" {
  import "generic-host"
  address = "192.168.1.100"
  vars.behind_loadbalancer = true
}
```

## Threshold and String Check Syntax

### Numeric Thresholds
Thresholds follow the format: `path:warning:critical`

| Format | Description | Example |
|--------|-------------|---------|
| `path:10:20` | Warning > 10, Critical > 20 | `$.cpu:80:95` |
| `path::20` | Only critical threshold | `$.errors::5` |
| `path:10:` | Only warning threshold | `$.connections:100:` |
| `path:@10:20` | Range thresholds (< values) | `$.free_space:@20:10` |

### String Pattern Checks
String checks use the format: `path:pattern:status[:flags]`

| Element | Description | Examples |
|---------|-------------|----------|
| `path` | JSONPath or XPath expression | `$.status`, `//inet/state` |
| `pattern` | Regex pattern to match | `^healthy$`, `^(ok\|running)$` |
| `status` | Nagios status | `OK`, `WARNING`, `CRITICAL` |
| `flags` | Case sensitivity | `c` (sensitive), `i` (insensitive, default) |

**String Check Examples:**
```bash
# Case-insensitive (default)
$.status:healthy:OK              # Matches "healthy", "HEALTHY", "Healthy"
$.status:^(ok\|running)$:OK       # Matches "OK", "ok", "RUNNING", "running"

# Case-sensitive
$.status:HEALTHY:OK:c            # Only matches "HEALTHY" exactly
$.version:^v1\.2\.3$:OK:c        # Only matches "v1.2.3" exactly
```

## Output Examples

**JSON Success:**
```
HTTP_XML_JSON_CHECK OK - $.status: healthy, $.database.connected: true, $.cache.hits: 1205
|cache_hits=1205;1000;5000 database_response_time=23;;;0
```

**XML Success:**
```
HTTP_XML_JSON_CHECK OK - //inet/state: 1, //voip/registered: 2, //wlan/wlanStations: 3
|inet_state=1;1;2 voip_registered=2;1; wlan_wlanStations=3;20;50
```

**Warning:**
```
HTTP_XML_JSON_CHECK WARNING - $.cpu.usage: 85 (WARNING), $.memory.used: 75
|cpu_usage=85;80;95 memory_used=75;85;95
```

**Critical with String Check:**
```
HTTP_XML_JSON_CHECK CRITICAL - $.status: degraded (String check CRITICAL: expected 'healthy')
```

## Exit Codes

The plugin follows standard Nagios exit code conventions:

| Code | Status | Description |
|------|--------|-------------|
| 0 | OK | All checks passed |
| 1 | WARNING | One or more warning thresholds exceeded |
| 2 | CRITICAL | One or more critical thresholds exceeded or string checks failed |
| 3 | UNKNOWN | Plugin error, network failure, or invalid parameters |

## Debugging

### Explore Data Structure

Use debug mode to discover available JSONPath/XPath expressions:

```bash
# JSON endpoint
./check_http_data.pl -H api.example.com -p /status -q '$.dummy' --debug

# XML endpoint  
./check_http_data.pl -H device.local -p /status.xml -q '//dummy' --debug
```

This will show:
- Raw JSON/XML content
- Formatted data structure  
- Available paths with current values
- Ready-to-use expressions

### Get Help and Examples

```bash
# Show JSONPath/XPath syntax help
./check_http_data.pl --help

# Show detailed examples
./check_http_data.pl --samples
```

## Troubleshooting

### Common Issues

1. **"JSONPath/XPath returned no results"**
   - Use debug mode to see available expressions: `--debug`
   - Check data structure format
   - Ensure path syntax is correct for data type

2. **"HTTP request failed"**
   - Verify hostname and port
   - Check if HTTPS is required (`--ssl`)
   - Verify network connectivity
   - For reverse proxies, check `--host-header` setting

3. **"Failed to parse JSON/XML"**
   - Check if the response is valid JSON/XML
   - Some devices return HTML error pages instead of data
   - Use `--type` to force data format detection

4. **"String check failed"**
   - Check case sensitivity settings (default: case-insensitive)
   - Use `:c` flag for case-sensitive matching
   - Verify regex pattern syntax

### Testing

Test with sample data:
```bash
# JSON test
echo '{"status": "healthy", "value": 42}' > test.json
python3 -m http.server 8080
./check_http_data.pl -H localhost --port 8080 -p /test.json \
  -q '$.status' -q '$.value' -s '$.status:healthy:OK' --perfdata

# XML test
echo '<?xml version="1.0"?><root><status>ok</status><value>42</value></root>' > test.xml
./check_http_data.pl -H localhost --port 8080 -p /test.xml \
  -q '//status' -q '//value' -s '//status:ok:OK' --perfdata
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <http://www.gnu.org/licenses/>.

## Changelog

### v2.0.0
- **Breaking Change**: Added JSON support alongside XML
- **Breaking Change**: Parameter rename: `--thresholds/-t` → `--limit/-l` (due to conflict with timeout)
- Added JSONPath support for JSON data
- Added string pattern matching with case sensitivity control
- Added `--host-header` for reverse proxy support
- Added `--type` parameter to force data format
- Enhanced debug mode for both JSON and XML
- Comprehensive test suite
- Case-insensitive string matching by default

### v1.0.0
- Initial release (XML-only)
- Multiple XPath support
- Configurable thresholds
- Performance data generation
- Debug mode
- Comprehensive help system
- Icinga2/Nagios compatibility

## Support

- **Issues**: [GitHub Issues](https://github.com/zmt-gmbh/check_http_data/issues)
- **Documentation**: Built-in help (`--help`, `--samples`)
- **Examples**: See `--samples` output for comprehensive usage examples
- **Testing**: Run `perl tests/run_tests.pl` for validation

## Author

**Grischa Zengel**

Created for monitoring JSON/XML HTTP endpoints with Icinga2 and Nagios.
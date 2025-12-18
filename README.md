# HTTP XML XPath Monitor for Icinga2/Nagios

A generic Perl monitoring plugin for Icinga2 and Nagios that fetches XML data via HTTP/HTTPS and evaluates multiple XPath expressions with configurable thresholds and performance data generation.

## Author

**Grischa Zengel**

## Features

- **Multiple XPath Support**: Check multiple XML elements in a single request
- **Flexible Thresholds**: Configure warning and critical thresholds per XPath
- **Performance Data**: Automatic performance data generation for numeric values
- **HTTP/HTTPS Support**: Works with both protocols and custom ports
- **Debug Mode**: Explore XML structure and discover available XPaths
- **Comprehensive Help**: Built-in examples and XPath syntax reference
- **Icinga2 Ready**: Includes complete CheckCommand and Service templates

## License

This nagios plugin is free software, and comes with ABSOLUTELY NO WARRANTY.
It may be used, redistributed and/or modified under the terms of the GNU
General Public License (see http://www.fsf.org/licensing/licenses/gpl.txt).

## Requirements

### Perl Modules
```bash
# Debian/Ubuntu
sudo apt-get install libmonitoring-plugin-perl libwww-perl libxml-libxml-perl

# CentOS/RHEL/Rocky/AlmaLinux
sudo yum install perl-Monitoring-Plugin perl-LWP-Protocol-https perl-XML-LibXML

# Alpine Linux
sudo apk add perl-monitoring-plugin perl-lwp-protocol-https perl-xml-libxml
```

## Installation

1. **Download the script:**
   ```bash
   wget https://raw.githubusercontent.com/zmt-gmbh/check-http-xml/main/check_http_xml.pl
   chmod +x check_http_xml.pl
   ```

2. **Install to Icinga2 plugin directory:**
   ```bash
   sudo cp check_http_xml.pl /usr/lib/nagios/plugins/
   sudo chown icinga:icinga /usr/lib/nagios/plugins/check_http_xml.pl
   ```

3. **Test the installation:**
   ```bash
   /usr/lib/nagios/plugins/check_http_xml.pl --help
   ```

## Usage

### Basic Syntax
```bash
check_http_xml.pl -H <hostname> -p <path> -x <xpath1> [-x <xpath2>] [options]
```

### Quick Examples

**Single value check:**
```bash
./check_http_xml.pl -H router.example.com -p /status.xml -x "//inet/state"
```

**Multiple values with performance data:**
```bash
./check_http_xml.pl -H router.example.com -p /status.xml \
  -x "//inet/state" \
  -x "//voip/registered" \
  -x "//wlan/stations" \
  --perfdata
```

**With thresholds:**
```bash
./check_http_xml.pl -H router.example.com -p /status.xml \
  -x "//inet/state" \
  -x "//voip/registered" \
  -t "//inet/state:1:2" \
  -t "//voip/registered:1:" \
  --perfdata
```

### Command Line Options

| Option | Description |
|--------|-------------|
| `-H, --hostname` | Hostname or IP address |
| `-p, --path` | URL path (e.g., `/status.xml`) |
| `-x, --xpath` | XPath expression (can be used multiple times) |
| `-t, --thresholds` | Thresholds in format `xpath:warning:critical` |
| `--perfdata` | Generate performance data |
| `--port` | Port number (default: 80) |
| `--ssl` | Use HTTPS |
| `--timeout` | Request timeout in seconds (default: 30) |
| `--debug` | Show XML structure and available XPaths |
| `--samples` | Show detailed usage examples |
| `--help` | Show help with XPath syntax reference |

### XPath Examples

The script supports standard XPath 1.0 expressions:

```bash
# Basic element selection
//element                    # Find 'element' anywhere
/root/child                  # Direct path from root
//parent/child               # Find 'child' under any 'parent'

# Advanced selection
//element[1]                 # First occurrence
//element[@attr='value']     # Element with specific attribute
//element[text()='value']    # Element with specific text
count(//element)             # Count elements
```

## Real-World Example: Deutsche Telekom Digitalisierungsbox (T-Box)

For monitoring a T-Box router status:

```bash
./check_http_xml.pl -H t-box.local -p /cgi-bin/status.xml \
  -x "//url/version" \
  -x "//inet/state" \
  -x "//voip/registered" \
  -x "//wlan/wlanStations" \
  -t "//inet/state:1:2" \
  -t "//voip/registered:1:" \
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

## Icinga2 Configuration

### 1. CheckCommand Definition

Create `/etc/icinga2/conf.d/check_http_xml.conf`:

```icinga2
object CheckCommand "check_http_xml" {
  import "plugin-check-command"
  
  command = [ PluginDir + "/check_http_xml.pl" ]
  
  arguments = {
    "-H" = "$xml_hostname$"
    "-p" = "$xml_path$"
    "-x" = {
      value = "$xml_xpath$"
      repeat_key = true
    }
    "-t" = {
      value = "$xml_thresholds$"
      repeat_key = true
    }
    "--perfdata" = { set_if = "$xml_perfdata$" }
    "--port" = "$xml_port$"
    "--ssl" = { set_if = "$xml_ssl$" }
    "--timeout" = "$xml_timeout$"
  }
  
  vars.xml_hostname = "$host.address$"
  vars.xml_perfdata = true
  vars.xml_port = 80
  vars.xml_timeout = 30
}
```

### 2. Service Template

```icinga2
template Service "xml-service" {
  import "generic-service"
  check_command = "check_http_xml"
  vars.xml_perfdata = true
}
```

### 3. Service Examples

**T-Box monitoring:**
```icinga2
apply Service "t-box-status" {
  import "xml-service"
  
  vars.xml_path = "/cgi-bin/status.xml"
  vars.xml_xpath = [
    "//inet/state",
    "//voip/registered", 
    "//wlan/wlanStations",
    "//url/version"
  ]
  vars.xml_thresholds = [
    "//inet/state:1:2",
    "//voip/registered:1:",
    "//wlan/wlanStations:20:50"
  ]
  
  assign where host.vars.device_type == "t-box"
}
```

**Generic router monitoring:**
```icinga2
apply Service "router-xml-status" {
  import "xml-service"
  
  vars.xml_path = "/status.xml"
  vars.xml_xpath = [
    "//system/cpu",
    "//system/memory",
    "//interfaces/active"
  ]
  vars.xml_thresholds = [
    "//system/cpu:80:95",
    "//system/memory:85:95",
    "//interfaces/active:1:"
  ]
  
  assign where host.vars.xml_monitoring == true
}
```

### 4. Host Definition

```icinga2
object Host "my-t-box" {
  import "generic-host"
  address = "192.168.1.1"
  vars.device_type = "t-box"
}

object Host "my-router" {
  import "generic-host"
  address = "192.168.1.254"
  vars.xml_monitoring = true
}
```

## Threshold Syntax

Thresholds follow the format: `xpath:warning:critical`

| Format | Description | Example |
|--------|-------------|---------|
| `xpath:10:20` | Warning > 10, Critical > 20 | `//cpu:80:95` |
| `xpath::20` | Only critical threshold | `//errors::5` |
| `xpath:10:` | Only warning threshold | `//connections:100:` |
| `xpath:@10:20` | Range thresholds (< values) | `//free_space:@20:10` |

## Output Examples

**Success:**
```
HTTP_XML_CHECK OK - //inet/state: 1, //voip/registered: 2, //wlan/wlanStations: 3
|inet_state=1;1;2 voip_registered=2;1; wlan_wlanStations=3;20;50
```

**Warning:**
```
HTTP_XML_CHECK WARNING - //inet/state: 2 (WARNING), //voip/registered: 2
|inet_state=2;1;2 voip_registered=2;1;
```

**Critical:**
```
HTTP_XML_CHECK CRITICAL - //inet/state: 3 (CRITICAL), //voip/registered: 0 (CRITICAL)
|inet_state=3;1;2 voip_registered=0;1;
```

## Debugging

### Explore XML Structure

Use debug mode to discover available XPath expressions:

```bash
./check_http_xml.pl -H device.local -p /status.xml -x "//dummy" --debug
```

This will show:
- Raw XML content
- Formatted XML structure  
- Available XPath targets with current values
- Ready-to-use XPath expressions

### Get Help and Examples

```bash
# Show XPath syntax help
./check_http_xml.pl --help

# Show detailed examples
./check_http_xml.pl --samples
```

## Troubleshooting

### Common Issues

1. **"XPath returned no results"**
   - Use debug mode to see available XPath expressions
   - Check XML structure with `--debug`
   - Ensure XPath syntax is correct

2. **"HTTP request failed"**
   - Verify hostname and port
   - Check if HTTPS is required (`--ssl`)
   - Verify network connectivity

3. **"Failed to parse XML"**
   - Check if the response is valid XML
   - Some devices return HTML error pages instead of XML

### Testing

Test with a simple XML file:
```bash
# Create test XML
echo '<?xml version="1.0"?><root><value>42</value></root>' > test.xml

# Start simple HTTP server
python3 -m http.server 8080

# Test the script
./check_http_xml.pl -H localhost --port 8080 -p /test.xml -x "//value" --perfdata
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

### v1.0.0
- Initial release
- Multiple XPath support
- Configurable thresholds
- Performance data generation
- Debug mode
- Comprehensive help system
- Icinga2/Nagios compatibility

## Support

- **Issues**: [GitHub Issues](https://github.com/zmt-gmbh/check-http-xml/issues)
- **Documentation**: Built-in help (`--help`, `--samples`)
- **Examples**: See `--samples` output for comprehensive usage examples

## Author

**Grischa Zengel**

Created for monitoring XML-based network devices with Icinga2 and Nagios.

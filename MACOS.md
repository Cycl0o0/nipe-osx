# Nipe for macOS

This document provides macOS-specific information for running Nipe on macOS systems.

## Requirements

- macOS 10.12 (Sierra) or later
- Homebrew package manager
- Perl 5.30 or later (included with macOS)
- Root/sudo access

## Installation

### 1. Install Homebrew (if not already installed)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 2. Install Dependencies

```bash
# Install cpanminus
brew install cpanminus

# Clone the repository
git clone https://github.com/htrgouvea/nipe && cd nipe

# Install Perl dependencies
cpanm --installdeps .

# Install Nipe and Tor
sudo perl nipe.pl install
```

## How It Works on macOS

### System Proxy Configuration

Unlike Linux which uses iptables for transparent proxying, macOS uses system-wide proxy settings:

- Nipe configures macOS system preferences to use Tor's SOCKS proxy (port 9050)
- DNS is configured to use Tor's DNS port (9061) via localhost
- The active network service (Wi-Fi, Ethernet, etc.) is automatically detected and configured
- When you stop Nipe, proxy settings are disabled and DNS is reset to automatic

**Important**: This approach routes traffic at the system level, not at the packet filter level. Most applications will respect these settings, but some may bypass them.

### Tor Service Management

Nipe can manage Tor using Homebrew services:

```bash
# Start Tor
brew services start tor

# Stop Tor
brew services stop tor

# Check status
brew services list | grep tor
```

### Network Services

Nipe automatically detects the active network service (Wi-Fi, Ethernet, USB Ethernet, etc.) and configures it to use Tor's SOCKS proxy.

To check your network services:

```bash
networksetup -listallnetworkservices
```

## Usage

### Starting Nipe

```bash
sudo perl nipe.pl start
```

This will:
1. Start the Tor service
2. Configure pfctl to route traffic through Tor
3. Verify the connection

### Checking Status

```bash
sudo perl nipe.pl status
```

### Stopping Nipe

```bash
sudo perl nipe.pl stop
```

This will:
1. Disable pfctl
2. Remove the pf configuration
3. Stop the Tor service

### Restarting

```bash
sudo perl nipe.pl restart
```

## Troubleshooting

### Permission Denied Errors

Make sure you're running Nipe with sudo:

```bash
sudo perl nipe.pl start
```

### Proxy Settings Not Working

If the proxy settings aren't being applied:

```bash
# Check current SOCKS proxy settings
networksetup -getsocksfirewallproxy Wi-Fi

# Manually enable SOCKS proxy
networksetup -setsocksfirewallproxy Wi-Fi 127.0.0.1 9050
networksetup -setsocksfirewallproxystate Wi-Fi on

# Verify DNS settings
networksetup -getdnsservers Wi-Fi
```

### Tor Not Starting

Check if Tor is already running:

```bash
ps aux | grep tor
```

If Tor is running but Nipe can't connect:

```bash
# Stop all Tor processes
sudo killall tor

# Restart Nipe
sudo perl nipe.pl restart
```

### Some Applications Bypass the Proxy

Some applications may not respect system proxy settings and could bypass Tor:

- Applications using custom network stacks (some VPN clients, browsers with built-in proxies)
- Applications using direct socket connections
- Command-line tools that don't check system proxy settings

For these applications, you may need to configure them individually to use SOCKS proxy at `127.0.0.1:9050`.

### IPv6 Issues

If IPv6 is causing problems, you can temporarily disable it:

```bash
networksetup -setv6off Wi-Fi
```

To re-enable:

```bash
networksetup -setv6automatic Wi-Fi
```

## Limitations

### Known Issues

1. **Application-Level Bypass**: Unlike Linux's iptables approach, macOS system proxy settings can be bypassed by applications that don't respect them. This is a fundamental limitation of the proxy-based approach.

2. **VPN Compatibility**: Nipe may conflict with VPN software. It's recommended to disconnect from VPNs before starting Nipe.

3. **Browser Extensions**: Some browser extensions may override system proxy settings. Disable proxy extensions when using Nipe.

4. **Command-Line Tools**: Many CLI tools (curl, wget, etc.) don't automatically use system proxy settings. You may need to set environment variables:
   ```bash
   export ALL_PROXY=socks5://127.0.0.1:9050
   export all_proxy=socks5://127.0.0.1:9050
   ```

5. **DNS Leaks**: Always verify your connection using the status command or external services like https://check.torproject.org

## Files and Directories

- **Configuration**: `.configs/darwin-torrc` - Tor configuration for macOS (SOCKS on port 9050, DNS on port 9061)
- **Tor Data**: `/usr/local/var/lib/tor` - Tor data directory (Homebrew installation)
- **Tor Logs**: `/usr/local/var/log/tor/log` - Tor log file
- **System Proxy**: Configured via `networksetup` command (no configuration file)

## Security Considerations

1. **Root Access**: Nipe requires root access to modify system networking. Always review the code before running with sudo.

2. **Traffic Analysis**: While Tor provides anonymity, it's not foolproof. Be aware of traffic analysis attacks and correlation attacks.

3. **Local Traffic**: Traffic to local networks (127.0.0.0/8, 192.168.0.0/16, 172.16.0.0/12, 10.0.0.0/8) is NOT routed through Tor.

4. **UDP/ICMP**: Non-Tor UDP and ICMP traffic is blocked as per Tor project requirements.

## Support

For issues specific to the macOS implementation, please open an issue on GitHub with:
- macOS version (`sw_vers`)
- Perl version (`perl -v`)
- Error messages
- Output of `sudo perl nipe.pl status`

## Contributing

Contributions to improve macOS support are welcome! Areas that could use improvement:
- Automatic network interface detection
- Better error handling for pfctl
- Integration with macOS Keychain for Tor authentication
- Support for Apple Silicon (M1/M2/M3) specific optimizations

## License

This work is licensed under MIT License.

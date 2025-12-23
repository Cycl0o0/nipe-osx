package Nipe::Component::Engine::Start {
	use strict;
	use warnings;
	use Nipe::Component::Utils::Device;
	use Nipe::Component::Utils::Status;
    use Nipe::Component::Engine::Stop;

	our $VERSION = '0.1.0';

	sub new {
        my $stop          = Nipe::Component::Engine::Stop -> new();
		my %device        = Nipe::Component::Utils::Device -> new();
		my $dns_port      = '9061';
		my $transfer_port = '9051';
		my @table         = qw(nat filter);
		my $network       = '10.66.0.0/255.255.0.0';
		my $network_ipv6  = 'fd00::/8';
		my $start_tor     = 'systemctl start tor';

		if ($device{distribution} eq 'darwin') {
			# macOS: Use Homebrew services or launchctl
			if (-e '/usr/local/bin/brew' || -e '/opt/homebrew/bin/brew') {
				$start_tor = 'brew services start tor 2>&1';
			} else {
				$start_tor = 'tor -f .configs/darwin-torrc > /dev/null 2>&1 &';
			}
		}
		elsif ($device{distribution} eq 'void') {
			$start_tor = 'sv start tor > /dev/null';
		}
		elsif (-e '/etc/init.d/tor') {
			$start_tor = '/etc/init.d/tor start > /dev/null';
		}

		# Start Tor
		system "tor -f .configs/$device{distribution}-torrc > /dev/null 2>&1 &";
		sleep 3;  # Give Tor time to start
		system $start_tor;
		sleep 2;  # Additional time for Tor to initialize

		# macOS: Configure system proxy settings for Tor SOCKS
		if ($device{distribution} eq 'darwin') {
			# Detect active network service
			my $active_service = `networksetup -listallnetworkservices 2>/dev/null | grep -v '*' | head -1`;
			chomp($active_service);
			$active_service = 'Wi-Fi' unless $active_service;

			# Enable SOCKS proxy
			system "networksetup -setsocksfirewallproxy '$active_service' 127.0.0.1 9050 2>/dev/null";
			system "networksetup -setsocksfirewallproxystate '$active_service' on 2>/dev/null";

			# Set DNS to use Tor's DNS port via localhost
			system "networksetup -setdnsservers '$active_service' 127.0.0.1 2>/dev/null";

			sleep 3;  # Wait for settings to apply

			my $status = Nipe::Component::Utils::Status -> new();

			if ($status =~ /true/sm) {
				return 1;
			}

			return $status;
		}

		# Linux: Use iptables
		foreach my $table (@table) {
			my $target = 'ACCEPT';

			if ($table eq 'nat') {
				$target = 'RETURN';
			}

			system "iptables -t $table -F OUTPUT";
			system "iptables -t $table -A OUTPUT -m state --state ESTABLISHED -j $target";
			system "iptables -t $table -A OUTPUT -m owner --uid $device{username} -j $target";

			my $match_dns_port = $dns_port;

			if ($table eq 'nat') {
				$target = "REDIRECT --to-ports $dns_port";
				$match_dns_port = '53';
			}

			system "iptables -t $table -A OUTPUT -p udp --dport $match_dns_port -j $target";
			system "iptables -t $table -A OUTPUT -p tcp --dport $match_dns_port -j $target";

			if ($table eq 'nat') {
				$target = "REDIRECT --to-ports $transfer_port";
			}

			system "iptables -t $table -A OUTPUT -d $network -p tcp -j $target";

			if ($table eq 'nat') {
				$target = 'RETURN';
			}

			system "iptables -t $table -A OUTPUT -d 127.0.0.1/8    -j $target";
			system "iptables -t $table -A OUTPUT -d 192.168.0.0/16 -j $target";
			system "iptables -t $table -A OUTPUT -d 172.16.0.0/12  -j $target";
			system "iptables -t $table -A OUTPUT -d 10.0.0.0/8     -j $target";

			if ($table eq 'nat') {
				$target = "REDIRECT --to-ports $transfer_port";
			}

			system "iptables -t $table -A OUTPUT -p tcp -j $target";
		}

		system 'iptables -t filter -A OUTPUT -p udp -j REJECT';
		system 'iptables -t filter -A OUTPUT -p icmp -j REJECT';

		# Check if IPv6 is available
		my $ipv6_available = 0;
		if ($device{distribution} eq 'darwin') {
			# macOS: Check if IPv6 is configured
			my $ipv6_check = `ifconfig 2>/dev/null | grep -c inet6`;
			chomp($ipv6_check);
			$ipv6_available = $ipv6_check > 0;
		} else {
			# Linux: Check /proc/sys/net/ipv6
			$ipv6_available = -d '/proc/sys/net/ipv6';
		}

		if ($ipv6_available) {
			foreach my $table (@table) {
				my $target = 'ACCEPT';

				if ($table eq 'nat') {
					$target = 'RETURN';
				}

				system "ip6tables -t $table -F OUTPUT";
				system "ip6tables -t $table -A OUTPUT -m state --state ESTABLISHED -j $target";
				system "ip6tables -t $table -A OUTPUT -m owner --uid $device{username} -j $target";

				my $match_dns_port = $dns_port;

				if ($table eq 'nat') {
					$target = "REDIRECT --to-ports $dns_port";
					$match_dns_port = '53';
				}

				system "ip6tables -t $table -A OUTPUT -p udp --dport $match_dns_port -j $target";
				system "ip6tables -t $table -A OUTPUT -p tcp --dport $match_dns_port -j $target";

				if ($table eq 'nat') {
					$target = "REDIRECT --to-ports $transfer_port";
				}

				system "ip6tables -t $table -A OUTPUT -d $network_ipv6 -p tcp -j $target";

				if ($table eq 'nat') {
					$target = 'RETURN';
				}

				system "ip6tables -t $table -A OUTPUT -d ::1/128      -j $target";
				system "ip6tables -t $table -A OUTPUT -d fc00::/7     -j $target";
				system "ip6tables -t $table -A OUTPUT -d fe80::/10    -j $target";

				if ($table eq 'nat') {
					$target = "REDIRECT --to-ports $transfer_port";
				}

				system "ip6tables -t $table -A OUTPUT -p tcp -j $target";
			}

			system 'ip6tables -t filter -A OUTPUT -p udp -j REJECT';
			system 'ip6tables -t filter -A OUTPUT -p icmpv6 -j REJECT';
		}

		my $status = Nipe::Component::Utils::Status -> new();

		if ($status =~ /true/sm) {
			return 1;
		}

		return $status;
	}
}

1;

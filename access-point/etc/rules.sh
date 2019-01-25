#!/bin/sh

sysctl -w net.ipv4.ip_forward=1 
ip_wan=$(ifconfig eth0.10 | grep 'inet addr' | cut -d: -f2 | awk '{print $1}')
### CLEAN ALL RULES

iptables -F
iptables -t nat -F
iptables -t mangle -F
iptables -X

### POLICY

iptables -P INPUT DROP
iptables -P OUTPUT ACCEPT
iptables -P FORWARD DROP

### INPUT

iptables -A INPUT -m state --state ESTABLISHED -j ACCEPT
iptables -A INPUT -m state --state RELATED -j ACCEPT
# Reject access to LUCI from LAN (Replace -d argument by ip from uhttpd conf file)
iptables -A INPUT -p tcp -s 192.168.1.0/24 -d $ip_wan -m state --state NEW -j REJECT
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -p icmp --icmp-type 8 -m state --state NEW -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -m state --state NEW -j ACCEPT
iptables -A INPUT -p tcp -s 192.168.1.0/24 --dport 53 -m state --state NEW -j ACCEPT
iptables -A INPUT -p udp -s 192.168.1.0/24 --dport 53 -m state --state NEW -j ACCEPT
iptables -A INPUT -p udp -s 192.168.1.0/24 --dport 5353 -m state --state NEW -j ACCEPT
iptables -A INPUT -p tcp -s 192.168.1.0/24 --dport 5353 -m state --state NEW -j ACCEPT
iptables -A INPUT -p tcp --dport 80 -m state --state NEW -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -m state --state NEW -j ACCEPT
iptables -A INPUT -p udp --sport 67:68 --dport 67:68 -m state --state NEW -j ACCEPT

### FORWARD

iptables -t nat -A POSTROUTING -o eth0.10 -j MASQUERADE
iptables -A FORWARD -i eth0.10 -j ACCEPT
iptables -A FORWARD -o eth0.10 -j ACCEPT

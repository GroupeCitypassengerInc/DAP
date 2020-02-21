#!/bin/sh

sysctl -w net.ipv4.ip_forward=1

ip_wan=$(ifconfig br-wan | grep 'inet addr' | cut -d: -f2 | awk '{print $1}')

### CLEAN ALL RULES

iptables -F
iptables -t nat -F
iptables -t mangle -F
iptables -X

### POLICY

iptables -P INPUT DROP
iptables -P OUTPUT ACCEPT
iptables -P FORWARD DROP

### PREROUTING

iptables -t nat -A PREROUTING -i bridge1 -p tcp --dport 80 -s 10.168.168.0/24 -j DNAT --to-destination 10.168.168.1:80
iptables -t nat -A PREROUTING -i bridge1 -p tcp --dport 443 -s 10.168.168.0/24 -j DNAT --to-destination 10.168.168.1:80

### INPUT

iptables -A INPUT -p tcp -s 10.168.168.0/24 -d $ip_wan/32 -m conntrack --ctstate NEW -j REJECT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED -j ACCEPT
iptables -A INPUT -m conntrack --ctstate RELATED -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -p icmp --icmp-type 8 -m conntrack --ctstate NEW -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -j ACCEPT
iptables -A INPUT -p tcp -s 10.168.168.0/24 --dport 53 -m conntrack --ctstate NEW -j ACCEPT
iptables -A INPUT -p udp -s 10.168.168.0/24 --dport 53 -m conntrack --ctstate NEW -j ACCEPT
iptables -A INPUT -p udp -s 10.168.168.0/24 --dport 5353 -m conntrack --ctstate NEW -j ACCEPT
iptables -A INPUT -p tcp -s 10.168.168.0/24 --dport 5353 -m conntrack --ctstate NEW -j ACCEPT
iptables -A INPUT -p tcp --dport 80 -m conntrack --ctstate NEW -j ACCEPT
iptables -A INPUT -p tcp --dport 8081 -m conntrack --ctstate NEW -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -m conntrack --ctstate NEW,ESTABLISHED,INVALID -j ACCEPT
iptables -A INPUT -p udp --sport 67:68 --dport 67:68 -m conntrack --ctstate NEW -j ACCEPT

### FORWARD

iptables -t nat -A POSTROUTING -o br-wan -j MASQUERADE
iptables -A FORWARD -i br-wan -j ACCEPT
iptables -A FORWARD -o br-wan -j ACCEPT

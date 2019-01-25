#!/bin/sh

### USE THIS IN OPENWRT QEMU NOT CHROOT

sysctl -w net.ipv4.ip_forward=1 

### CLEAN ALL RULES

iptables -F
iptables -t nat -F
iptables -X

### PREROUTING
iptables -t nat -A PREROUTING -i br-lan -p tcp --dport 80 -d 172.16.1.30 -j ACCEPT
iptables -t nat -A PREROUTING -i br-lan -p tcp --dport 80 -j DNAT --to-destination 192.168.1.1:9090
iptables -t nat -A PREROUTING -i br-lan -p tcp --dport 443 -j DNAT --to-destination 192.168.1.1:9090

### INPUT

iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -p tcp --dport 53 -j ACCEPT
iptables -A INPUT -p udp --dport 53 -j ACCEPT
iptables -A INPUT -p udp --sport 67:68 --dport 67:68 -j ACCEPT

### OUTPUT

iptables -A OUTPUT -o lo -j ACCEPT
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT
iptables -A OUTPUT -p udp --sport 67:68 --dport 67:68 -j ACCEPT

### FORWARD

iptables -t nat -A POSTROUTING -o eth1 -j MASQUERADE
iptables -A FORWARD -i eth1 -j ACCEPT
iptables -A FORWARD -o eth1 -j ACCEPT
iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT

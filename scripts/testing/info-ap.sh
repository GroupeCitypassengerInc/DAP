#!/bin/sh

ps | egrep '(uhttpd|dnsmasq|logger|hostapd)'

echo "=========="
cat /etc/crontabs/root
echo "=========="

iw wlan0 info
iw wlan1 info

ifconfig bridge1
brctl show


#!/bin/sh
ip_source=${1?none}
ip_host=${2?none}
host=${3?none}

/bin/grep -q $host /etc/unauthorized-list.conf && exit 0
/usr/bin/sudo /usr/sbin/iptables -t nat -I PREROUTING -s $ip_source -d $ip_host -i bridge1 -p tcp -m tcp --dport 443 -j ACCEPT

#!/bin/sh

mkdir /var/lock
mknod /dev/null c 1 3
mknod -m 0666 /dev/urandom c 1 9
mount -t proc proc /proc
touch /testing/jar
opkg update
opkg install uhttpd-mod-lua
opkg install coreutils-stat
opkg install curl
opkg install arp-scan
opkg install libmysqlclient
opkg install luasql-mysql

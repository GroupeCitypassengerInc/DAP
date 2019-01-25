#!/bin/sh

id_file=/cloudgate/conf/wifuseur/wifuseur
ssh="route -T 1 exec ssh -o StrictHostKeyChecking=no -o BatchMode=yes -o ServerAliveInterval=30 -o UserKnownHostsFile=/dev/null"
scp="route -T 1 exec scp -o StrictHostKeyChecking=no -o BatchMode=yes -o ServerAliveInterval=30 -o UserKnownHostsFile=/dev/null"

echo "========================================================================"
echo "========================= SOLO AP CONFIGURATOR ========================="
echo "========================================================================"

ap_ip=$(arp -anV 1 | tail -1 | awk '{print $1}')

# Add verification
echo "Enter captive portal URL (Wordpress site address)."
read portal

echo "Enter user timeout in seconds."
read timeout
if [ ! $timeout -eq $timeout ]; then
  echo "$timeout is not a number."
  exit 1
fi

##
##    PACKAGES
##

echo "====================== Installing packages on AP ======================="
if [ ! -f dnsmasq.ipk ]; then
  echo "dnsmasq.ipk file not found."
  exit 1
fi
$scp -i $id_file dnsmasq.ipk root@$ap_ip:/tmp # dnsmasq custom patch
if [ ! -f inotifywait_3.20.1-1_mips_24kc.ipk ]; then
  echo "inotifywait not found."
  exit 1
fi
if [ ! -f libinotifytools_3.20.1-1_mips_24kc.ipk ]; then
  echo "libinotifytools not found."
  exit 1
fi
$scp -i $id_file inotifywait_3.20.1-1_mips_24kc.ipk root@$ap_ip:/tmp
if [ ! $? -eq 0 ]; then
  echo "Failed to copy file to access point."
  exit 1
fi
$scp -i $id_file libinotifytools_3.20.1-1_mips_24kc.ipk root@$ap_ip:/tmp
if [ ! $? -eq 0 ]; then
  echo "Failed to copy file to access point."
  exit 1
fi

$ssh -i $id_file root@$ap_ip 'opkg update'
if [ ! $? -eq 0 ]; then
  echo "Update failed."
  exit 1
fi

lede_packages=""
lede_packages="${lede_packages} curl"
lede_packages="${lede_packages} iptables"
lede_packages="${lede_packages} uci"
lede_packages="${lede_packages} luci"
lede_packages="${lede_packages} uhttpd"
lede_packages="${lede_packages} uhttpd-mod-lua"
lede_packages="${lede_packages} hostapd-common"
lede_packages="${lede_packages} tcpdump"
lede_packages="${lede_packages} /tmp/dnsmasq.ipk"
lede_packages="${lede_packages} /tmp/libinotifytools_3.20.1-1_mips_24kc.ipk"
lede_packages="${lede_packages} /tmp/inotifywait_3.20.1-1_mips_24kc.ipk"

echo "Installing packages on access point."
for LEDE_PACKAGE in ${lede_packages}; do
  $ssh -i $id_file root@$ap_ip "opkg install $LEDE_PACKAGE"
  if [ ! $? -eq 0 ]; then
    echo "Failed to install $LEDE_PACKAGE"
    exit 1
  fi
done
echo "Packages successfully installed."

##
##    FILES FROM SOLO REPOSITORY
##

echo "======================== Copying files to AP ==========================="

echo "Generating ini configuration file for access point."
# INI CONF FILE
$ssh -i $id_file root@$ap_ip " 
cat > /etc/proxy.ini <<EOF
[portal]
url=$portal
[ap]
mac_addr=/sys/devices/pci0000\:00/0000\:00\:00.0/net/wlan0/address
timeout=$timeout
[localdb]
path=/var/localdb
EOF
"
if [ ! $? -eq 0 ]; then
  echo "Failed to generate ini configuration file."
  exit 1
fi

echo "Ini configuration file generated:"
$ssh -i $id_file root@$ap_ip 'cat /etc/proxy.ini'
if [ ! $? -eq 0 ]; then
  echo "cat /etc/proxy.ini failed."
  exit 1
fi

echo "Checking out AP configuration files."


portal_files=""
portal_files="${portal_files} index.lua"
portal_files="${portal_files} lib/LIP.lua"
portal_files="${portal_files} lib/portal_proxy.lua"
portal_files="${portal_files} lib/proxy_constants.lua"
portal_files="${portal_files} lib/check.lua"
for PORTAL_FILE in ${portal_files}; do
  if [ ! -f "portal/$PORTAL_FILE" ]; then
    echo "File $PORTAL_FILE not found."
    exit 1
  fi
done

scripts_files=""
scripts_files="${scripts_files} wifi.lua"
scripts_files="${scripts_files} uhttpd.lua"
scripts_files="${scripts_files} get-mac-client"
for SCRIPT_FILE in ${scripts_files}; do
  if [ ! -f "scripts/$SCRIPT_FILE" ]; then
    echo "File $SCRIPT_FILE not found."
    exit 1
  fi
done

etc_files=""
etc_files="${etc_files} dnsmasq-white.conf"
etc_files="${etc_files} dnsmasq-black.conf"
etc_files="${etc_files} dnsmasq-dhcp.conf"
etc_files="${etc_files} dnsmasq.portal"
etc_files="${etc_files} hostapd.conf"
etc_files="${etc_files} rules.sh"
etc_files="${etc_files} config/uhttpd"
etc_files="${etc_files} crontabs/root"
etc_files="${etc_files} local.rc"
for ETC_FILE in ${etc_files}; do
  if [ ! -f "etc/$ETC_FILE" ]; then
    echo "File $ETC_FILE not found."
    exit 1
  fi
done

echo "Copying configuration files to access point."
$scp -ri $id_file portal root@$ap_ip:/
if [ ! $? -eq 0 ]; then
  echo "Copy failed for portal."
  exit 1
fi
$scp -ri $id_file scripts root@$ap_ip:/
if [ ! $? -eq 0 ]; then
  echo "Copy failed for scripts."
  exit 1
fi
$scp -ri $id_file etc/* root@$ap_ip:/etc
if [ ! $? -eq 0 ]; then
  echo "Copy failed for etc."
  exit 1
fi
echo "All files successfully copied to access point."
portal_domain=$(echo $portal | awk -F[/:] '{print $4}')
$ssh -i $id_file root@$ap_ip "echo $portal_domain >> /etc/dnsmasq-white.conf"
if [ ! $? -eq 0 ]; then
  echo "Failed to append portal URL to white list."
  exit 1
fi

echo "Done"

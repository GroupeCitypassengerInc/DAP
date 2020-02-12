package.path = package.path .. ';/scripts/lib/?.lua'
package.path = package.path .. ';/portal/lib/?.lua'
local helper = require 'bssid-helper'
local cst    = require 'proxy_constants'

local mac = cst.ap_mac
local bssid = helper.get_bssid(0)
local bssid_conf = 'bssid=%s\n'
local bssid_conf = string.format(bssid_conf,bssid)

local m = string.sub(mac,13,17)
local suffix = string.gsub(m,':','')

local ssid_conf = 'ssid=Solo AP Support %s\n'
local ssid_conf = string.format(ssid_conf,suffix)

local f = io.open('/etc/hostapd.support.conf','w')
f:write('interface=wlan1\n')
f:write('driver=nl80211\n')
f:write('logger_syslog=-1\n')
f:write('logger_syslog_level=-1\n')
f:write('logger_stdout=-1\n')
f:write('logger_stdout_level=-1\n')
f:write('hw_mode=g\n')
f:write('channel=0\n')
f:write(bssid_conf)
f:write('bridge=bridge1\n')
f:write(ssid_conf)
f:write('wpa=3\n')
f:write('auth_algs=3\n')
f:write('wpa_pairwise=CCMP TKIP\n')
f:write('wpa_passphrase=admincity\n')
f:write('wpa_key_mgmt=WPA-PSK\n')
f:close()

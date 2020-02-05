--[[
--
--  Script to shutdown AP services and start services in "support mode"
--  in order to display page with AP informations.
--
--]]
package.path = package.path .. ';/portal/lib/?.lua'
package.path = package.path .. ';/scripts/lib/?.lua'
nixio = require 'nixio'
reload = require 'reloader'
fs = require 'nixio.fs'
uci = require 'luci.model.uci'
portal = require 'portal_proxy'
lease  = require 'lease_file_reader'

local cmd = '/usr/bin/pgrep -f "/usr/sbin/hostapd -B -P /tmp/hostapd.support.pid /etc/hostapd.support.conf"'
local support_hostapd = os.execute(cmd)
if support_hostapd == 0 then
  nixio.syslog('info','Support mode already active')
  return true
end

local cmd = '/usr/bin/killall -q hostapd'
local s = os.execute(cmd)
if s ~= 0 then
  nixio.syslog('warning','No hostapd process killed.')
end

-- Start hostapd support
nixio.nanosleep(1)
reload.retry_hostapd('/etc/hostapd.support.conf')
reload.bridge()
reload.dnsmasq()
local lock = fs.mkdir('/tmp/8888.lock')
if lock then
  local cmd = '/usr/sbin/iptables -A INPUT -p tcp -m tcp --dport 8888 -m conntrack --ctstate NEW -j ACCEPT'
  local x = os.execute(cmd)
  if x ~= 0 then
    syslog.nixio('err','support mode: failed to enable rule ' .. cmd)
  end
end

local user_list = io.open('/tmp/dhcp.leases')
for line in user_list:lines() do
  local user_ip = lease.get_ip(line)
  local user_mac = lease.get_mac(line)
  portal.deauthenticate_user(user_ip,user_mac)
end

-- Set listen ip for LUCI interface in troubleshooting mode
local cursor = uci.cursor()
local new_value = {}
new_value[1] = '10.168.168.1:8888'
local set_res = cursor:set('uhttpd','main','listen_http',new_value)
if not set_res then
  nixio.syslog('err','failed to set new conf uci')
end
local commit = cursor:commit('uhttpd')
if not commit then
  nixio.syslog('err','failed to uci commit uhttpd')
end
reload.uhttpd()

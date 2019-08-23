--[[
--
--  Script to shutdown AP services and start services in "support mode"
--  in order to display page with AP informations.
--
--]]
package.path = package.path .. ';/scripts/lib/?.lua'
nixio = require 'nixio'
reload = require 'reloader'
fs = require 'nixio.fs'
uci = require 'luci.model.uci'

-- Killall hostapd
x = fs.remove('/tmp/hostapd.0.pid')
if not x then
  nixio.syslog('warning','No hostapd 0 pid file to remove')
end
y = fs.remove('/tmp/hostapd.1.pid')
if not y then
  nixio.syslog('warning','No hostapd 1 pid file to remove')
end
local cmd = '/usr/bin/killall hostapd'
local s = os.execute(cmd)
if s ~= 0 then
  nixio.syslog('warning','No hostapd process killed.')
end

-- Start hostapd support
nixio.nanosleep(1)
reload.retry_hostapd('/etc/hostapd.support.conf')
reload.bridge()
reload.dnsmasq()
-- Set listen ip for LUCI interface in troubleshooting mode
local cursor = uci.cursor()
local new_value = {}
new_value[1] = '172.16.3.2:80'
local set_res = cursor:set('uhttpd','main','listen_http',new_value)
if not set_res then
  nixio.syslog('err','failed to set new conf uci')
end
local commit = cursor:commit('uhttpd')
if not commit then
  nixio.syslog('err','failed to uci commit uhttpd')
end
reload.uhttpd()

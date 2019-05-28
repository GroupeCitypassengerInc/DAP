--[[
--
--  Script to shutdown AP services and start services in "support mode"
--  in order to display page with AP informations.
--
--]]
package.path = package.path .. ';/portal/lib/?.lua'
nixio = require 'nixio'
reload = require 'reloader'

-- Killall hostapd
local cmd = '/bin/rm /tmp/hostapd.0.pid'
local h = os.execute(cmd)
if h ~= 0 then
  nixio.syslog('warning','No /tmp/hostapd.0.pid file') 
end
local cmd = '/bin/rm /tmp/hostapd.1.pid'
local h = os.execute(cmd)
if h ~= 0 then
  nixio.syslog('warning','No /tmp/hostapd.1.pid file') 
end
local cmd = '/usr/bin/killall hostapd'
local s = os.execute(cmd)
if s ~= 0 then
  nixio.syslog('warning','No hostapd process killed.')
end

-- Start hostapd support
os.execute('/bin/sleep 1')
reload.hostapd('/etc/hostapd.support.conf')
reload.bridge()
reload.dnsmasq()
-- Set listen ip for LUCI interface in troubleshooting mode
local cmd = '/sbin/uci set uhttpd.main.listen_http=172.16.3.2:80'
local s = os.execute(cmd)
if s ~= 0 then
  nixio.syslog('err', cmd .. ' failed with exit code: ' .. s)
end
local cmd = '/sbin/uci commit uhttpd'
local s = os.execute(cmd)
if s ~= 0 then
  nixio.syslog('err', cmd .. ' failed with exit code: ' .. s)
end
reload.uhttpd()

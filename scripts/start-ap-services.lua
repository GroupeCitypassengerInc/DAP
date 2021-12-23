package.path = package.path .. ';/scripts/lib/?.lua'
local nixio  = require 'nixio'
local reload = require 'reloader'
local fs     = require 'nixio.fs'

local check = '/usr/bin/pgrep -f "hostapd -B -P /tmp/hostapd.0.pid /etc/hostapd.0.conf"'
local s = os.execute(check)
if s ~= 0 then
  reload.retry_hostapd('/etc/hostapd.0.conf')
end

nixio.nanosleep(1)

-- kill hostapd support if needed
local cmd = '/usr/bin/test -e /tmp/nointernet'
local internet = os.execute(cmd)
if internet ~= 0 then
  local check = '/usr/bin/pgrep -f "hostapd -B -P /tmp/hostapd.support.pid /etc/hostapd.support.conf"'
  local s = os.execute(check)
  if s == 0 then
    local pid_file = io.open('/tmp/hostapd.support.pid','r')
    local pid = pid_file:read('*l')
    pid_file:close()
    pid = tonumber(pid)
    local killed = nixio.kill(pid,15)
    if not killed then
      nixio.syslog('info','failed to kill hostapd support.')
    end
    local s = fs.remove('/tmp/hostapd.support.pid')
    if s ~= true then
      nixio.syslog('err','failed to remove /tmp/hostapd.support.conf')
    end
  end
end

nixio.nanosleep(1)

local check = '/usr/bin/pgrep -f "hostapd -B -P /tmp/hostapd.1.pid /etc/hostapd.1.conf"'
local s = os.execute(check)
if s ~= 0 then
  reload.retry_hostapd('/etc/hostapd.1.conf')
end

reload.bridge()

local cmd = '/usr/sbin/brctl show | /bin/grep wlan0'
local s = os.execute(cmd)
if s ~= 0 then
  local cmd = '/usr/sbin/brctl addif bridge1 wlan0 >/dev/null'
  local x = os.execute(cmd)
end

local cmd = '/usr/sbin/brctl show | /bin/grep wlan1'
local s = os.execute(cmd)
if s ~= 0 then
  local cmd = '/usr/sbin/brctl addif bridge1 wlan1 >/dev/null'
  local x = os.execute(cmd)
end

local check = '/usr/bin/pgrep -f "dnsmasq --conf-file=/etc/dnsmasq-dhcp.conf --cb-resolv=/etc/dnsmasq.action.sh --guard-ip=10.168.168.1"'
local s = os.execute(check)
if s ~= 0 then
  reload.dnsmasq()
end
local check = '/usr/bin/pgrep -f "dnsmasq --conf-file=/etc/dnsmasq.portal"'
local s = os.execute(check)
if s ~= 0 then
  reload.dnsmasq_portal()
end
local check = '/usr/bin/pgrep -f "lua /scripts/logger.lua"'
local s = os.execute(check)
if s ~= 0 then
  reload.logger()
end

os.execute('/etc/init.d/uhttpd restart')

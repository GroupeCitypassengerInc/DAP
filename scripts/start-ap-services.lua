package.path = package.path .. ';/scripts/lib/?.lua'
local nixio  = require 'nixio'
local reload = require 'reloader'
local fs     = require 'nixio.fs'

local check = '/usr/bin/test -e /tmp/hostapd.0.pid'
local s = os.execute(check)
if s ~= 0 then
  reload.retry_hostapd('/etc/hostapd.0.conf')
end

nixio.nanosleep(1)

-- kill hostapd support if needed
local cmd = '/usr/bin/test -e /tmp/nointernet'
local internet = os.execute(cmd)
if internet ~= 0 then
  local check = '/usr/bin/test -e /tmp/hostapd.support.pid'
  local s = os.execute(check)
  if s == 0 then
    local cmd = '/bin/cat /tmp/hostapd.support.pid'
    local pid = io.popen(cmd):read('*l')
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

local check = '/usr/bin/test -e /tmp/hostapd.1.pid'
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

local check = '/usr/bin/test -e /tmp/dnsmasq.pid'
local s = os.execute(check)
if s ~= 0 then
  reload.dnsmasq()
end

local check = '/usr/bin/test -e /tmp/dnsmasq-portal.pid'
local s = os.execute(check)
if s ~= 0 then
  reload.dnsmasq_portal()
  reload.logger()
end
os.execute('/etc/init.d/uhttpd restart')
os.exit()

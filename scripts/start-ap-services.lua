package.path = package.path .. ';/scripts/lib/?.lua'
local nixio  = require 'nixio'
local reload = require 'reloader'
local fs     = require 'nixio.fs'

local check = '/usr/bin/test -e /tmp/hostapd.0.pid'
local s = os.execute(check)
if s ~= 0 then
  reload.retry_hostapd('/etc/hostapd.0.conf')
end

-- kill hostapd support if needed
local cmd = '/usr/bin/test -e /tmp/nointernet'
local internet = os.execute(cmd)
if internet ~= 0 then
  local check = '/usr/bin/test -e /tmp/hostapd.support.pid'
  local s = os.execute(check)
  if s == 0 then
    local cmd = '/bin/cat /tmp/hostapd.support.pid'
    local pid = io.popen(cmd):read('*l')
    local cmd = '/bin/kill %s'
    local cmd = string.format(cmd,pid)
    local s = os.execute(cmd)
    if s ~= 0 then
      nixio.syslog('info','failed to kill hostapd support. Exit code: ' .. s)
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

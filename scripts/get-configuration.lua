#!/usr/bin/lua
package.path = package.path .. ';/portal/lib/?.lua'
local parser = require 'LIP'
local json   = require 'luci.jsonc'
local nixio  = require 'nixio'

--[[
--
--  GENERATE INI FILE
--
--]]


-- API Call - GET /ws/DAP/{mac}
 
local path_addr = '/sys/devices/platform/ag71xx.0/net/eth0/address'
local mac     = io.popen('cat ' .. path_addr):read('*l')
local api_key = io.popen('cat /root/.ssh/apikey'):read('*l')
local data =
{
  localdb=
  {
    path='/var/localdb',
  },
  ap=
  {
    timeout=7200,
    mac_addr=path_addr,
    secret='',
  },
  portal=
  {
    url='',
  }
}

if api_key == nil then
  resp = nil  
else
  local cmd     = 'curl -H "CityscopeApiKey: ' .. api_key .. 
  '" -H "accept: application/json" "https://preprod.citypassenger.com/ws/DAP/' 
  .. mac .. '"'
  local resp = io.popen(cmd):read('*a')
  local resp = json.parse(resp)
end

if resp == nil then
  parser.save('/etc/proxy.ini',data)
  nixio.syslog('info','No secret and URL.')
else
  local url = resp['portalUrl']
  local secret = resp['secret']
  local cmd = 'test -e /etc/proxy.ini'
  local c   = os.execute(cmd)
  if c == 0 then
    current_data = parser.load('/etc/proxy.ini')
    current_url = current_data.portal.url
    current_secret = current_data.ap.secret
    if current_url == url and current_secret == secret then
      nixio.syslog('info','Nothing to update.')
      return true
    end
  else
    nixio.syslog('info','No proxy.ini file found. Creating a new one.') 
  end
  -- Create ini file
  data.ap.secret=secret
  data.portal.url=url
  parser.save('/etc/proxy.ini',data)
  nixio.syslog('info','Configuration saved.')
end

-- Restart uhttpd
os.execute('/etc/init.d/uhttpd restart')

--[[
--
--  UPDATE DNSMASQ WHITE LIST FILE
--
--]]

-- Converts portal URL to domain
local domain = url:match('^%w+://([^/]+)')

-- Checks if portal is in white list
local cmd = 'grep "' .. domain .. '" /etc/dnsmasq-white.conf'
local x = os.execute(cmd)

if x == 0 then
  return true
end

-- Append portal url to white list
local cmd = 'echo ' .. domain .. ' >> /etc/dnsmasq-white.conf'
y = os.execute(cmd)
if y ~= 0 then
  nixio.syslog('err','Could not append portal url to whitelist. Exit code: ' 
  .. y)
end
nixio.syslog('info','Updated whitelist.')

-- Restart dnsmasq
local cmd = "killall dnsmasq"
s = os.execute(cmd)
if s ~= 0 then
  nixio.syslog('err','Could not kill all dnsmasq processes. Exit code: '
  .. s)
end
local DNSMASQ = 'dnsmasq --conf-file='
local dnsmasq1 = DNSMASQ .. '/etc/dnsmasq-dhcp.conf --guard-ip=192.168.1.1'
local dnsmasq2 = DNSMASQ .. '/etc/dnsmasq.portal'
local d1 = os.execute(dnsmasq1)
if d1 ~= 0 then
  nixio.syslog('err','Could not start ' .. dnsmasq1  .. '. Exit code: '
  .. d1)
end
local d2 = os.execute(dnsmasq2)
if d2 ~= 0 then
  nixio.syslog('err','Could not start ' .. dnsmasq2  .. '. Exit code: '
  .. d2)
end

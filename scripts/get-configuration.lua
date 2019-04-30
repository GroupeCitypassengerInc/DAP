#!/usr/bin/lua
package.path = package.path .. ';/portal/lib/?.lua'
local parser = require 'LIP'
local json   = require 'luci.jsonc'
local nixio  = require 'nixio'
local reload = require 'reloader'

------------------------
--------- GET CONFIG CITYSCOPE
------------------------
--[[
--
--  GENERATE INI FILE
--
--]]


-- API Call - GET /ws/DAP/{mac}
 
local path_addr = '/sys/devices/platform/ag71xx.0/net/eth0/address'
local mac     = io.popen('/bin/cat ' .. path_addr):read('*l')
local api_key = io.popen('/bin/cat /root/.ssh/apikey'):read('*l')
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
    landing_page=''
    portal_page=''
  },
  wpdb=
  {
    db_name='',
    db_username='',
    db_password='',
    db_host='',
    db_port='3306'
  }
}

resp = nil

if api_key == nil then
  resp = nil
else
  local cmd  = '/usr/bin/curl -H "CityscopeApiKey: %s"
  -H "accept: application/json" "https://preprod.citypassenger.com/ws/DAP/%s"'
  local cmd = string.format(cmd,api_key,mac)
  resp = io.popen(cmd):read('*a')
  resp = json.parse(resp)
end

url = nil

if resp == nil then
  parser.save('/etc/proxy.ini',data)
  nixio.syslog('info','No secret and URL.')
else
  url = resp['portalUrl']
  secret = resp['secret']
  local cmd = '/usr/bin/test -e /etc/proxy.ini'
  local c   = os.execute(cmd)
  if c == 0 then
    current_data = parser.load('/etc/proxy.ini')
    current_url = current_data.portal.url
    current_secret = current_data.ap.secret
    if current_url == url and current_secret == secret then
      nixio.syslog('info','Nothing to update.')
    else
      data.ap.secret=secret
      data.portal.url=url
      parser.save('/etc/proxy.ini',data)
      nixio.syslog('info','Configuration saved.')
      reload.uhttpd()
    end
  else
    nixio.syslog('info','No proxy.ini file found. Creating a new one.')
    data.ap.secret=secret
    data.portal.url=url
    parser.save('/etc/proxy.ini',data)
    nixio.syslog('info','Configuration saved.')
    reload.uhttpd()
  end
end

--- UPDATE HOSTAPD CONF FILE
local hostapds = resp['files']
local f = io.open('/etc/hostapd.0.conf')
local now0 = f:read('*a')
f:close()
local f = io.open('/etc/hostapd.1.conf')
local now1 = f:read('*a')
f:close()
local x = hostapds['/etc/hostapd.0.conf'] == now0
local y = hostapds['/etc/hostapd.1.conf'] == now1
if x and y then
  nixio.syslog('info','no changes')
else
  local kill = '/usr/bin/killall hostapd'
  local k = os.execute(kill)
  if k ~= 0 then
    nixio.syslog('info','no hostapd killed')
  end
  -- wait for killall to have killed all hostapd processes
  os.execute('sleep 1')
  for path,conf in pairs(hostapds) do
    local f = io.open(path,'w')
    f:write(conf)
    f:close()
    reload.hostapd(path)
  end
  reload.bridge()
  reload.dnsmasq() 
end

--[[
--
--  UPDATE DNSMASQ WHITE LIST FILE
--
--]]

-- Converts portal URL to domain
domain = url:match('^%w+://([^/]+)')


-- Checks if portal is in white list
local cmd = '/bin/grep "' .. domain .. '" /etc/dnsmasq-white.conf'
local x = os.execute(cmd)
if x == 256 then
  -- Append portal url to white list
  local cmd = '/bin/echo ' .. domain .. ' >> /etc/dnsmasq-white.conf'
  y = os.execute(cmd)
  if y ~= 0 then
    nixio.syslog('err','Could not append portal url to whitelist. Exit code: ' 
    .. y)
  end
  nixio.syslog('info','Updated whitelist.')

  -- Restart dnsmasq
  reload.dnsmasq()
elseif x ~= 0 then
  nixio.syslog('err','grep failed. Exit code: ' .. x)
  return false
end

------------------------
--------- GET CONFIG WORDPRESS 
------------------------

if url == nil then
  nixio.syslog('warn','No portal URL')
  return false
end

local cmd = '/usr/bin/curl "%s/index.php?digilan-token-action=configure&digilan-token-secret=%s"'
local cmd = string.format(cmd,url,secret)
local resp = io.popen(cmd):read('*a')

resp = json.parse(resp)

-- Update timeout
data = parser.load('/etc/proxy.ini')
--- Update timeout
if tonumber(resp['timeout']) == nil then
  nixio.syslog('err',resp['timeout'] .. ' is not a number.')
  return false
end
if data.ap.timeout ~= resp['timeout'] then
  data.ap.timeout = resp['timeout']
  parser.save('/etc/proxy.ini',data)
else
  nixio.syslog('info','timeout is up to date')
end

--- Update landing page
current_landing_page = data.portal.landing_page
new_landing_page = resp['landing_page']
if current_landing_page ~= new_landing_page then
  data.portal.landing_page = new_landing_page
  parser.save('/etc/proxy.ini',data)
  nixio.syslog('info','timeout updated')
  reload.uhttpd()
else
  nixio.syslog('info','landing page is up to date')
end

--- INCLUDE PORTAL PAGE
local portal_page = data.portal.page
local new_portal_page = resp['portal_page']
if portal_page ~= new_portal_page then
  data.portal.page = new_portal_page
  parser.save('/etc/proxy.ini',data)
  reload.uhttpd()
else
  nixio.syslog('info','portal page is up to date')
end

--- Update database credentials
if url ~= data.portal.url then
  data.wpdb.db_name     = resp['db_name']
  data.wpdb.db_username = data.portal.url
  data.wpdb.db_password = data.ap.secret
  data.wpdb.db_host     = domain
  nixio.syslog('info','database credentials updated.')
  parser.save('/etc/proxy.ini',data)
else
  nixio.syslog('info','db credentials are up to date')
end

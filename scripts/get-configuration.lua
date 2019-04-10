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

changed = false
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
      changed = true
      data.ap.secret=secret
      data.portal.url=url
      parser.save('/etc/proxy.ini',data)
      nixio.syslog('info','Configuration saved.')
    end
  else
    changed = true
    nixio.syslog('info','No proxy.ini file found. Creating a new one.')
    data.ap.secret=secret
    data.portal.url=url
    parser.save('/etc/proxy.ini',data)
    nixio.syslog('info','Configuration saved.')
  end
end

-- Restart uhttpd
if changed then
  reload.uhttpd()
end

--[[
--
--  UPDATE HOSTAPD CONF FILE
--
--]]

for conf_path,new_hostapd_file in pairs(resp['files']) do
  local hostapd_file = io.open(conf_path)
  local current_hostapd_file = hostapd_file:read('*a')
  if current_hostapd_file ~= new_hostapd_file then
    local f = io.open(conf_path)
    f:write(new_hostapd_file)
    f:close()
    reload.hostapd()
  end
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
  return false
end

local cmd = '/usr/bin/curl "%s/index.php?digilan-token-action=configure&digilan-token-secret=%s"'
local cmd = string.format(cmd,url,secret)
local resp = io.popen(cmd):read('*a')

resp = json.parse(resp)

--- Update timeout
data = parser.load('/etc/proxy.ini')
if tonumber(resp['timeout']) == nil then
  nixio.syslog('err',resp['timeout'] .. ' is not a number.')
  return false
end
if data.ap.timeout ~= resp['timeout'] then
  data.ap.timeout = resp['timeout']
  parser.save('/etc/proxy.ini',data)
end

--- Updage landing page
current_landing_page = data.portal.landing_page
new_landing_page = resp['landing_page']
if current_landing_page ~= new_landing_page then
  data.portal.landing_page = new_landing_page
  parser.save('/etc/proxy.ini',data)
  reload.uhttpd()
end

--- Update database credentials
if data.wpdb.db_name ~= resp['db_name'] then
  data.wpdb.db_name = resp['db_name']
  data.wpdb.db_username = data.portal.url
  data.wpdb.db_password = data.ap.secret
  data.wpdb.db_host     = domain
  parser.save('/etc/proxy.ini',data)
end

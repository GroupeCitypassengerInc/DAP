#!/usr/bin/lua
package.path = package.path .. ';/portal/lib/?.lua'
package.path = package.path .. ';/scripts/lib/?.lua'
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
    ssid='Borne Autonome',
  },
  portal=
  {
    url='',
    google='',
    facebook='',
    twitter='',
  }
}

if api_key == nil then
  resp = nil
else
  local cmd  = '/usr/bin/curl -H "CityscopeApiKey: ' .. api_key ..
  '" -H "accept: application/json" "https://preprod.citypassenger.com/ws/DAP/'
  .. mac .. '"'
  local resp = io.popen(cmd):read('*a')
  local resp = json.parse(resp)
end

changed = false

if resp == nil then
  parser.save('/etc/proxy.ini',data)
  nixio.syslog('info','No secret and URL.')
else
  local url = resp['portalUrl']
  local secret = resp['secret']
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
--  UPDATE DNSMASQ WHITE LIST FILE
--
--]]

-- Converts portal URL to domain
local domain = url:match('^%w+://([^/]+)')

-- Checks if portal is in white list
local cmd = '/bin/grep "' .. domain .. '" /etc/dnsmasq-white.conf'
local x = os.execute(cmd)

if x == 1 then
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

local cmd = '/usr/bin/curl "' .. url .. '/index.php?digilan-action=configure&secret=' .. ap_secret .. '"'
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

--- Get providers statuses to update whitelist accordingly

google_domains =
{
'accounts.google.com',
'ssl.gstatic.com',
'gstatic.com',
'apis.google.com',
'accounts.google.ca',
'accounts.google.fr',
'accounts.google.us',
'accounts.google.de',
'accounts.google.es',
'accounts.google.be',
'accounts.google.it',
}

twitter_domains =
{
'api.twitter.com',
'www.twitter.com',
'twitter.com',
'*.twimg.com',
}

facebook_domains =
{
'www.facebook.com',
'm.facebook.com',
'staticxx.facebook.com',
'*.fbcdn.net',
'connect.facebook.net',
'ocsp.int-x3.letsencrypt.org',
'cert.int-x3.letsencrypt.org',
}

local changed = false
if resp['google'] ~= data.portal.google then
  changed = true
  data.portal.google = resp['google']
  if resp['google'] then
    -- Add google auth domains to whitelist
    f = io.open('/etc/dnsmasq-white.conf','r+')
    s = f:read('*a')
    f:seek('set')
    for i,u in ipairs(google_domains) do
      s = s .. u .. '\n'
    end
    t = f:write(s)
    f:close()
  else
    -- Delete google auth domains from whitelist
    f = io.open('/etc/dnsmasq-white.conf','r+')
    s = f:read('*a')
    f:seek('set')
    for i,u in ipairs(google_domains) do
      s = string.gsub(s,'\n' .. u,'')
    end
    t = f:write(s)
    f:close()
  end
end
if resp['facebook'] ~= data.portal.facebook then
  changed = true
  data.portal.facebook = resp['facebook']
  if resp['facebook'] then
    -- Add facebook auth domains to whitelist
    f = io.open('/etc/dnsmasq-white.conf','r+')
    s = f:read('*a')
    f:seek('set')
    for i,u in ipairs(facebook_domains) do
      s = s .. u .. '\n'
    end
    t = f:write(s)
    f:close()
  else
    -- Delete facebook auth domains from whitelist
    f = io.open('/etc/dnsmasq-white.conf','r+')
    s = f:read('*a')
    f:seek('set')
    for i,u in ipairs(facebook_domains) do
      s = string.gsub(s,'\n' .. u,'')
    end
    t = f:write(s)
    f:close()
  end
end
if resp['twitter'] ~= data.portal.twitter then
  changed = true
  data.portal.twitter = resp['twitter']
  if resp['twitter'] then
    -- Add twitter auth domains to whitelist
    f = io.open('/etc/dnsmasq-white.conf','r+')
    s = f:read('*a')
    f:seek('set')
    for i,u in ipairs(twitter_domains) do
      s = s .. u .. '\n'
    end
    t = f:write(s)
    f:close()
  else
    -- Delete twitter auth domains from whitelist
    f = io.open('/etc/dnsmasq-white.conf','r+')
    s = f:read('*a')
    f:seek('set')
    for i,u in ipairs(twitter_domains) do
      s = string.gsub(s,'\n' .. u,'')
    end
    t = f:write(s)
    f:close()
  end
end
if changed then
  parser.save('/etc/proxy.ini',data)
  reload.dnsmasq()
end

-- Update ssid
if resp['ssid'] ~= data.ap.ssid then
  local cmd = '/bin/sed -i "s#^ssid=.*$#ssid=' .. resp['ssid'] .. '#" hostapd.solo.conf'
  local u = os.execute(cmd)
  if u ~= 0 then
    nixio.syslog('err','Could not replace with sed. Exit code: ' .. u)
    return false
  end
  data.ap.ssid = resp['ssid']
  parser.save('/etc/proxy.ini',data)
  reload.hostapd()
end

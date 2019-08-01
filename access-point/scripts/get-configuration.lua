#!/usr/bin/lua
--[[
--
--  Script to get configuration from Cityscope and WordPress Portal.
--  Returns 0 on success.
--  Returns 1 on fail.
--
--]]

package.path = package.path .. ';/portal/lib/?.lua'
package.path = package.path .. ';/scripts/lib/?.lua'
parser = require 'LIP'
local json   = require 'luci.jsonc'
local nixio  = require 'nixio'
local reload = require 'reloader'
local fs     = require 'nixio.fs'
local helper = require 'helper'
local bssid  = require 'bssid-helper'
local ini    = require 'check_config_changes'

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
local ini_file = '/etc/proxy.ini'
local mac = io.popen('/bin/cat ' .. path_addr):read('*l')
local api_key = io.popen('/bin/cat /root/.ssh/apikey'):read('*l')
local get_hostname = '/sbin/uci get system.@system[0].hostname'
local hostname = io.popen(get_hostname):read('*l')
local data =
{
  localdb=
  {
    path='/var/localdb',
    tmp='/var/tmpdb'
  },
  ap=
  {
    timeout=7200,
    mac_addr=path_addr,
    secret='',
    ssid=''
  },
  portal=
  {
    url='',
    landing_page='',
    error_page='',
    portal_page=''
  }
}

resp = nil

if api_key == nil then
  resp = nil
else
  local cmd  = '/usr/bin/curl --retry 3 --retry-delay 20 --fail -m 10 --connect-timeout 10 -s -H "CityscopeApiKey: %s" ' .. 
  '-H "accept: application/json" "https://preprod.citypassenger.com/ws/DAP/%s"'
  local cmd = string.format(cmd,api_key,mac)
  resp,exit = helper.command(cmd)
  if exit ~= 0 then
    nixio.syslog('err',cmd..' failed with exit code: '..exit)
    os.exit(exit)
  end
  resp = json.parse(resp)
end

url = nil
secret = nil

if resp == nil then
  parser.save(ini_file,data)
  nixio.syslog('info','No secret and URL.')
  os.exit(1)
else
  url = resp['portalUrl']
  secret = resp['secret']
  local cmd = '/usr/bin/test -e ' .. ini_file
  local c   = os.execute(cmd)
  if c == 0 then
    current_data = parser.load(ini_file)
    current_url = current_data.portal.url
    current_secret = current_data.ap.secret
    if current_url == url and current_secret == secret then
      nixio.syslog('info','Nothing to update.')
    else
      data.ap.secret=secret
      data.portal.url=url
      parser.save(ini_file,data)
      nixio.syslog('info','Configuration saved.')
      reload.uhttpd()
    end
  else
    nixio.syslog('info','No proxy.ini file found. Creating a new one.')
    data.ap.secret=secret
    data.portal.url=url
    parser.save(ini_file,data)
    nixio.syslog('info','Configuration saved.')
    reload.uhttpd()
  end
end

--- UPDATE HOSTAPD HEADER (HARDWARE CONFIGURATION)
local hardware_new = ''
local hardware_now = ''
for k,v in pairs(resp['files']) do
  g = io.open(k .. '.header')
  h = g:read('*a')
  g:close()
  hardware_now = hardware_now .. h
  hardware_new = hardware_new .. v
end

if hardware_now ~= hardware_new then
  local cmd = '/usr/bin/killall hostapd'
  local x = os.execute(cmd)
  if x ~= 0 then
    nixio.syslog('warning','No hostapd killed.')
  end
  os.execute('/bin/sleep 1')
  local i = 0
  for hostapd_file,conf in pairs(resp['files']) do
    local bssid = bssid.get_bssid(i)
    f = io.open(hostapd_file,'w')
    f:write(conf)
    f:write('bssid=' .. bssid.. '\nbridge=bridge1\nssid=Borne Autonome')
    f:close()
    g = io.open(hostapd_file .. '.header','w')
    g:write(conf)
    g:close()
    i = i + 1
    reload.retry_hostapd(hostapd_file)
  end
  reload.bridge()
  reload.dnsmasq()
  data.ap.ssid = 'Borne Autonome'
  data.ap.secret = secret
  data.portal.url = url
  parser.save(ini_file,data)
end

--[[
--
--  UPDATE DNSMASQ WHITE LIST FILE
--
--]]

if url == nil then
  nixio.syslog('warning','No portal URL')
  return false
end
domain = url:match('^%w+://([^/]+)')

-- Checks if portal is in white list
local cmd = '/bin/grep "' .. domain .. '" /etc/dnsmasq-white.conf > /dev/null'
local x = os.execute(cmd)
if x == 256 then
  -- Append portal url to white list
  local f = io.open('/etc/dnsmasq-white.conf','a')
  f:write(domain)
  f:close()
  nixio.syslog('info','Updated whitelist.')
  reload.dnsmasq()
elseif x ~= 0 then
  nixio.syslog('err','Could not update whitelist. grep failed. Exit code: ' .. x)
  os.exit(1)
end

------------------------
--------- GET CONFIG WORDPRESS 
------------------------

--- SEND HOSTNAME TO WP

local cmd = '/usr/bin/curl --retry 3 --retry-delay 5 --fail -m 10 --connect-timeout 10 -s -L "%s/index.php?' ..
'digilan-token-action=add&digilan-token-secret=%s&hostname=%s&mac=%s"'
local cmd = string.format(cmd,url,secret,hostname,mac)

while true do
  response,exit = helper.command(cmd)
  if exit ~= 0 then
    nixio.syslog('err','cURL exit code: '..exit)
    os.exit(exit)
  end
  wp_reg = json.parse(response)
  if wp_reg ~= nil then
    break
  end
end

if wp_reg['message'] == 'created' then
  nixio.syslog('info','hostname sent to wp')
elseif wp_reg['message'] == 'exists' then
  nixio.syslog('info','hostname already sent')
else
  nixio.syslog('err','Unexpected behaviour')
  return false
end

--- GET SETTINGS FROM WORDPRESS

local cmd = '/usr/bin/curl --retry 3 --retry-delay 5 --fail -m 10 --connect-timeout 10 -s -L "%s/index.php?' ..
'digilan-token-action=configure&digilan-token-secret=%s&hostname=%s"'
local cmd = string.format(cmd,url,secret,hostname)

while true do
  response,exit = helper.command(cmd)
  if exit ~= 0 then
    nixio.syslog('err','cURL exit code: '..exit)
    os.exit(exit)
  end
  wp_resp = json.parse(response)
  if wp_resp ~= nil then
    break
  end
end

--- LOAD CURRENT INI FILE
data = parser.load(ini_file)

--- UPDATE SSID
local ssid_new = wp_resp['ssid']
if data.ap.ssid ~= ssid_new then
  local cmd = '/usr/bin/killall hostapd'
  local x = os.execute(cmd)
  if x ~= 0 then
    nixio.syslog('warning','No hostapd killed.')
  end
  os.execute('/bin/sleep 1')
  change_ssid = "/bin/sed -i 's#^ssid=.*#ssid=%s#g' %s"
  for hostapd_file in pairs(resp['files']) do
    local s = string.format(change_ssid,ssid_new,hostapd_file)
    local t = os.execute(s)
    if t ~= 0 then
      nixio.syslog('err','Failed to change ssid in ' .. hostapd_file)
    end
    reload.retry_hostapd(hostapd_file)
  end
  data.ap.ssid = ssid_new
  parser.save(ini_file,data)
  reload.bridge()                                                    
  reload.dnsmasq()
else
  nixio.syslog('info','ssid is up to date')
end

--- Update timeout
if tonumber(wp_resp['timeout']) == nil then
  nixio.syslog('err',wp_resp['timeout'] .. ' is not a number.')
  return false
end

old = data.ap.timeout
new = wp_resp['timeout']
ini.update_config(old,new,data,'ap','timeout')

old = data.portal.landing_page
new = wp_resp['landing_page']
res = ini.update_config(old,new,data,'portal','landing_page')
if res then reload.uhttpd() end

old = data.portal.portal_page
new = wp_resp['portal_page']
res = ini.update_config(old,new,data,'portal','portal_page')
if res then reload.uhttpd() end

old = data.portal.error_page
new = wp_resp['error_page']
res = ini.update_config(old,new,data,'portal','error_page')
if res then reload.uhttpd() end

--- UPDATE SCHEDULE
local old_schedule = data.ap.schedule
local new_schedule = wp_resp['schedule']['on']..wp_resp['schedule']['off']
if old_schedule ~= new_schedule then
  local sed = "/bin/sed -ri '/(en|dis)able-wifi.lua/d' /etc/crontabs/root"
  local x = os.execute(sed)
  if x ~= 0 then
    nixio.syslog('err',sed..' failed with exit code: '..x)
    os.exit(x)
  end
  data.ap.schedule = new_schedule
  local on = string.gsub(wp_resp['schedule']['on'],'%\\n','\n')
  local off = string.gsub(wp_resp['schedule']['off'],'%\\n','\n')
  f = io.open('/etc/crontabs/root','a')
  f:write(on)
  f:write(off)
  f:close()
  parser.save(ini_file,data)
  os.execute('/etc/init.d/cron restart')
else
  nixio.syslog('info','schedule is up to date')
end
os.exit()

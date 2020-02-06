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
local sys    = require 'luci.sys'
local uci    = require 'luci.model.uci'

--[[
--
--  GET PUBLIC IP
--
--]]
local cmd = '/usr/bin/curl -s --fail -m3 -o /tmp/public.ip "https://eth0.me"'
local s = os.execute(cmd)
if not s == 0 then
  nixio.syslog('err','Failed to get public ip')
end

------------------------
--------- GET CONFIG CITYSCOPE
------------------------
--[[
--
--  GENERATE INI FILE
--
--]]

-- API Call - GET /ws/DAP/{mac}
 
local path_addr = '/sys/devices/platform/soc/c080000.edma/net/eth1/address'
local ini_file = '/etc/proxy.ini'
local mac_file = io.open(path_addr,'r')
if not mac_file then
  nixio.syslog('err','could not open '..path_addr)
  os.exit(1)
end
local mac = mac_file:read('*l')
mac_file:close()
local api_file = io.open('/root/.ssh/apikey','r')
if not api_file then
  nixio.syslog('err','failed to open /root/.ssh/apikey')
  os.exit(1)
end
local api_key = api_file:read('*l')
api_file:close()
local hostname = sys.hostname()
local data =
{
  localdb=
  {
    path='/var/localdb',
    tmp='/var/tmpdb'
  },
  ap=
  {
    rescue_host='',
    identity_file='/root/.ssh/host_key',
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

endpoint = io.open("/etc/cityscope.conf"):read("*l")
if not endpoint then
  nixio.syslog("err","No endpoint to cityscope")
  return
end

if not api_key then
  resp = nil
else
  local cmd  = '/usr/bin/curl --retry 3 --retry-delay 20 --fail -m 10 --connect-timeout 10 -s -H "CityscopeApiKey: %s" ' .. 
  '-H "accept: application/json" "%s/%s"'
  local cmd = string.format(cmd,api_key,endpoint,mac)
  resp,exit = helper.command(cmd)
  if exit ~= 0 then
    nixio.syslog('err', 'cURL to '..endpoint..'/'..mac..' failed with exit code: '..exit)
    os.exit(exit)
  end
  resp = json.parse(resp)
end

url = nil
secret = nil

if not resp then
  nixio.syslog('info','No secret and URL.')
  os.exit(1)
else
  url = resp['url']
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

--- UPDATE HOST KEY
local cmd = '/usr/bin/dropbearconvert dropbear openssh ' .. data.ap.identity_file .. ' /tmp/host_key_openssh'
os.execute(cmd)
local f = io.open('/tmp/host_key_openssh','r')
local current_host_key = f:read('*a')
f:close()
local new_host_key = resp['hostKeySsh']
if not new_host_key then
  new_host_key = ''
end
if current_host_key ~= new_host_key then
  local f = io.open('/tmp/host_key_new_openssh','w')
  new_host_key = string.gsub(new_host_key,'%\\n','\n')
  f:write(new_host_key)
  f:close()
  local cmd = '/usr/bin/dropbearconvert openssh dropbear /tmp/host_key_new_openssh ' .. data.ap.identity_file
  os.execute(cmd)
  nixio.syslog('info', 'Host key ssh has been updated')
else
  nixio.syslog('info','Host key ssh is up to date')
end

--- UPDATE RESCUE HOST
local d = parser.load(ini_file) 
local current_rescue_host = d.ap.rescue_host
local new_rescue_host = resp['rescuehost']
if not resp['rescuehost'] then
  new_rescue_host = ''
end
if current_rescue_host ~= new_rescue_host then
  -- Update in ini file and uci
  local d = parser.load(ini_file) 
  d.ap.rescue_host = new_rescue_host
  parser.save(ini_file,d)  
  local cursor = uci.cursor()
  local new_value = {}
  new_value[1] = '-i /root/.ssh/host_key '..new_rescue_host
  local set_res = cursor:set('autossh','@autossh[0]','ssh',new_value)
  if not set_res then
    nixio.syslog('err','failed to set new conf uci')
  end
  local commit = cursor:commit('autossh')
  if not commit then
    nixio.syslog('err','failed to uci commit uhttpd')
  end
  nixio.syslog('info', 'Rescue host has been updated')
else
  nixio.syslog('info', 'Rescue host is up to date')
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
  local cmd = '/usr/bin/killall -q hostapd'
  local x = os.execute(cmd)
  if x ~= 0 then
    nixio.syslog('warning','No hostapd killed.')
  end
  nixio.nanosleep(1)
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
if not url then
  nixio.syslog('warning','No portal URL')
  return false
end
domain = url:match('^%w+://([^:/]+)')
-- Checks if portal is in white list
local cmd = '/bin/grep -w "' .. domain .. '" /etc/dnsmasq-white.conf > /dev/null'
local x = os.execute(cmd)
if x == 256 then
  -- Append portal url to white list
  local f = io.open('/etc/dnsmasq-white.template','r')
  local hosts = f:read('*a')
  f:close()
  hosts = string.gsub(hosts, '%%%%portal_host%%%%', domain)
  local g = io.open('/etc/dnsmasq-white.conf','w+')
  g:write(hosts)
  g:close()
  nixio.syslog('info','Updated whitelist.')
  reload.dnsmasq()
elseif x ~= 0 then
  nixio.syslog('err','Could not update whitelist. grep failed. Exit code: ' .. x)
  os.exit(1)
end

------------------------
--------- RESOLVE PORTAL
------------------------
local dns_result = nixio.getaddrinfo(domain,'inet')
if not dns_result then
  nixio.syslog('err','Failed to resolve portal: '..domain)
  os.exit(1)
end

local ip_portal = dns_result[1].address

------------------------
--------- GET CONFIG WORDPRESS 
------------------------

--- SEND HOSTNAME TO WP

local cmd = '/scripts/add_access_point %s %s %s %s'
local cmd = string.format(cmd,secret,url .. '/index.php',ip_portal,domain)

response,exit = helper.command(cmd)
if exit ~= 0 then
  nixio.syslog('err','cURL add AP exit code: '..exit)
  os.exit(exit)
end
if response ~= '200' then
  nixio.syslog('err','add access point cURL response: '..response)
  os.exit(response)
end
local f = io.open('/tmp/add_wordpress','r')
if not f then
  nixio.syslog('err','failed to open /tmp/add_wordpress')
  os.exit(1)
end
local conf = f:read('*a')
f:close()
wp_reg = json.parse(conf)
if not wp_reg then
  nixio.syslog('err','Could not add hostname to portal')
  os.exit(1)
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

local cmd = '/scripts/get_config_curl %s %s %s %s'
local cmd = string.format(cmd,secret,url .. '/index.php',ip_portal,domain)

response,exit = helper.command(cmd)
if exit ~= 0 then
  nixio.syslog('err','cURL exit code: '..exit)
  os.exit(exit)
end
if response ~= '200' then
  nixio.syslog('err','get config cURL response: '..response)
  os.exit(response)
end
local f = io.open('/tmp/config_wordpress','r')
if not f then
  nixio.syslog('err','failed to open /tmp/config_wordpress')
  os.exit(1)
end
local conf = f:read('*a')
f:close()
wp_resp = json.parse(conf)
if not wp_resp then
  nixio.syslog('err','failed to add hostname on portal')
  os.exit(1)
end

--- LOAD CURRENT INI FILE
data = parser.load(ini_file)

--- UPDATE SSID
local changed = 0
local ssid_new = wp_resp['ssid']
if data.ap.ssid ~= ssid_new then
  change_ssid = "/bin/sed -i 's#^ssid=.*#ssid=%s#g' %s"
  for hostapd_file in pairs(resp['files']) do
    local s = string.format(change_ssid,ssid_new,hostapd_file)
    local t = os.execute(s)
    if t ~= 0 then
      nixio.syslog('err','Failed to change ssid in ' .. hostapd_file)
    end
    nixio.syslog('info','ssid in conf file ' .. hostapd_file .. ' has been updated.')
  end
  data.ap.ssid = ssid_new
  parser.save(ini_file,data)
  changed = changed + 1
else
  nixio.syslog('info','ssid is up to date')
end

--- UPDATE COUNTRY CODE
local country_code_new = wp_resp['country_code']
local m = string.match(country_code_new, '%u%u')
if m ~= country_code_new then
  nixio.syslog('err','Invalid country code format')
  os.exit(1)
end
if data.ap.country_code ~= country_code_new then
  change_country_code = "/bin/sed -i 's#^country_code=.*#country_code=%s#g' %s"
  for hostapd_file in pairs(resp['files']) do
    local s = string.format(change_country_code,country_code_new,hostapd_file)
    local t = os.execute(s)
    if t ~= 0 then
      nixio.syslog('err','Failed to change country code in ' .. hostapd_file)
    end
    nixio.syslog('info','country code in conf file ' .. hostapd_file .. ' has been updated')
  end
  data.ap.country_code = country_code_new
  parser.save(ini_file,data)
  changed = changed + 1
else
  nixio.syslog('info','country code is up to date')
end

-- RELOAD IF HOSTAPD CHANGED
if changed > 0 then
  local cmd = '/usr/bin/killall -q hostapd'
  local x = os.execute(cmd)
  if x ~= 0 then
    nixio.syslog('warning','No hostapd killed.')
  end
  nixio.nanosleep(1)
  nixio.syslog('info','hostapd configuration changed, reloading hostapd')
  for hostapd_file in pairs(resp['files']) do
    reload.retry_hostapd(hostapd_file)
  end
  reload.bridge()
  reload.dnsmasq()
end

--- Update timeout
if not tonumber(wp_resp['timeout']) then
  nixio.syslog('err',wp_resp['timeout'] .. ' is not a number.')
  return false
end

old = data.ap.timeout
new = wp_resp['timeout']
ini.update_config(old,new,data,'ap','timeout')

local changed = 0
old = data.portal.landing_page
new = wp_resp['landing_page']
res = ini.update_config(old,new,data,'portal','landing_page')
if res then changed = changed + 1 end

old = data.portal.portal_page
new = wp_resp['portal_page']
res = ini.update_config(old,new,data,'portal','portal_page')
if res then changed = changed + 1 end

old = data.portal.error_page
new = wp_resp['error_page']
res = ini.update_config(old,new,data,'portal','error_page')
if res then changed = changed + 1 end

if changed > 0 then reload.uhttpd() end

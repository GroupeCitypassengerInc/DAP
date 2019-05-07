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
local ini_file = '/etc/proxy.ini'
local mac     = io.popen('/bin/cat ' .. path_addr):read('*l')
local api_key = io.popen('/bin/cat /root/.ssh/apikey'):read('*l')
local bssid_base = '70:b3:d5:e7:e'
local m = string.sub(mac,14,17)
local mask = string.gsub(m,':','')
local mask = '0x' .. mask
local get_hostname = '/sbin/uci get system.@system[0].hostname'
local hostname = io.popen(get_hostname):read('*l')
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
    hardware='',
    ssid=''
  },
  portal=
  {
    url='',
    landing_page='',
    page=''
  }
}

resp = nil

if api_key == nil then
  resp = nil
else
  local cmd  = '/usr/bin/curl -H "CityscopeApiKey: %s" ' .. 
  '-H "accept: application/json" "https://preprod.citypassenger.com/ws/DAP/%s"'
  local cmd = string.format(cmd,api_key,mac)
  resp = io.popen(cmd):read('*a')
  resp = json.parse(resp)
end

url = nil

if resp == nil then
  parser.save(ini_file,data)
  nixio.syslog('info','No secret and URL.')
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

local function format_mask(s)
  while (string.len(s) < 3) do
    s = '0' .. s
  end
  return s
end

--- UPDATE HOSTAPD HEADER (HARDWARE CONFIGURATION)
local hardware_new = ''
for k,v in pairs(resp['files']) do
  hardware_new = hardware_new .. v
end
if data.ap.hardware ~= hardware_new then
  local cmd = '/usr/bin/killall hostapd'
  local x = os.execute(cmd)
  if x ~= 0 then
    nixio.syslog('warning','No hostapd killed.')
  end
  os.execute('sleep 1')
  data.ap.hardware = ''
  for k,v in pairs(resp['files']) do
    mask = (mask + i) % 4096
    local n = mask
    local s = string.format('%x',n)
    local s = format_mask(s)
    local suffix = string.sub(s,1,1) .. ":" .. string.sub(s,2,3)
    local bssid = base_bssid .. suffix
    f = io.open(k,'w')
    f:write(v)
    f:write('bssid=' .. bssid.. '\nbridge=bridge1\nssid=Borne Autonome')
    f:close()
    data.ap.hardware = data.ap.hardware .. v
    i = i + 1
    reload.hostapd(k)
  end
  reload.bridge()
  reload.dnsmasq()
  data.ap.ssid = 'Borne Autonome'
  parser.save(ini_file,data)
end

--[[
--
--  UPDATE DNSMASQ WHITE LIST FILE
--
--]]

if url == nil then
  nixio.syslog('warn','No portal URL')
  return false
end
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


local cmd = '/usr/bin/curl "%s/index.php?' ..
'digilan-token-action=configure&digilan-token-secret=%s&hostname=%s"'
local cmd = string.format(cmd,url,secret,hostname)
local wp_resp = io.popen(cmd):read('*a')

wp_resp = json.parse(wp_resp)

--- UPDATE SSID
local ssid_new = wp_resp['ssid']
if data.ap.ssid ~= ssid_new then
  change_ssid = "/bin/sed -i 's#^ssid=.*#ssid=%s#g' %s"
  for k,v in pairs(resp['files']) do
    local s = string.format(change_ssid,ssid_new,k)
    local t = os.execute(s)
    if t ~= 0 then
      nixio.syslog('err','Failed to change ssid in ' .. k)
    end
  end
  data.ap.ssid = ssid_new
  parser.save(ini_file,data)
end

-- Update timeout
data = parser.load(ini_file)
--- Update timeout
if tonumber(resp['timeout']) == nil then
  nixio.syslog('err',resp['timeout'] .. ' is not a number.')
  return false
end
if data.ap.timeout ~= wp_resp['timeout'] then
  data.ap.timeout = resp['timeout']
  parser.save(ini_file,data)
else
  nixio.syslog('info','timeout is up to date')
end

--- Update landing page
current_landing_page = data.portal.landing_page
new_landing_page = wp_resp['landing_page']
if current_landing_page ~= new_landing_page then
  data.portal.landing_page = new_landing_page
  parser.save(ini_file,data)
  nixio.syslog('info','landing page updated')
  reload.uhttpd()
else
  nixio.syslog('info','landing page is up to date')
end

--- INCLUDE PORTAL PAGE
local portal_page = data.portal.page
local new_portal_page = wp_resp['portal_page']
if portal_page ~= new_portal_page then
  data.portal.page = new_portal_page
  parser.save(ini_file,data)
  reload.uhttpd()
else
  nixio.syslog('info','portal page is up to date')
end

--- START SERVICES IF NOT STARTED
local check = '/usr/bin/test -e /tmp/hostapd.0.pid'
local s = os.execute(check)
if s ~= 0 then
  reload.hostapd('/etc/hostapd.0.conf')
end

local check = '/usr/bin/test -e /tmp/hostapd.1.pid'
local s = os.execute(check)
if s ~= 0 then
  reload.hostapd('/etc/hostapd.1.conf')
end

reload.bridge()

local check = '/usr/bin/test -e /tmp/dnsmasq.pid'
local s = os.execute(check)
if s ~= 0 then
  reload.dnsmasq()
end

local check = '/usr/bin/test -e /tmp/dnsmasq_portal.pid'
local s = os.execute(check)
if s ~= 0 then
  reload.dnsmasq_portal()
  reload.logger()
end

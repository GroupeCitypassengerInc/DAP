--[[
--
--  Script to check if AP has internet and can access portal URL.
--  If no internet, shutdown hostapd and start hostapd in support mode.
--
]]--

package.path = package.path .. ';/portal/lib/?.lua'
local nixio = require 'nixio'
local fs = require 'nixio.fs'
local support = require 'troubleshooting'

local file_internet = '/tmp/internet'
local file_nointernet = '/tmp/nointernet'
local create_file = '/bin/touch %s'
local has_portal = support.has_access_to_portal()

if has_portal then
  local file_exists = os.execute('/usr/bin/test -e '..file_internet)
  if file_exists == 0 then
    os.exit()
  end
  fs.remove(file_nointernet)
  fs.remove('/tmp/8888.lock')
  local cmd = '/usr/sbin/iptables -D INPUT -p tcp -m tcp --dport 8888 -m conntrack --ctstate NEW -j ACCEPT'
  os.execute(cmd)
  os.execute('/etc/init.d/autossh stop')
  dofile('/scripts/get-configuration.lua')
  dofile('/scripts/update_firewall_whitelist.lua')
  dofile('/scripts/start-ap-services.lua')
  create_file = string.format(create_file,file_internet)
  local x = os.execute(create_file)
  if x ~= 0 then
    nixio.syslog('err','/scripts/interstate.lua: Failed to execute ' .. 
    create_file .. '. Exit code: ' .. x)
  end
else
  fs.remove(file_internet)
  create_file = string.format(create_file,file_nointernet)
  local x = os.execute(create_file)
  if x ~= 0 then
    nixio.syslog('err','/scripts/interstate.lua: Failed to execute ' .. 
    create_file .. '. Exit code: ' .. x)
  end
  dofile('/scripts/support-mode.lua')
end
os.exit()

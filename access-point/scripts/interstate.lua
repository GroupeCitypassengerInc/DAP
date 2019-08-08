--[[
--
--  Script to check if AP has internet and can access portal URL.
--  If no internet, shutdown hostapd and start hostapd in support mode.
--
]]--


package.path = package.path .. ';/portal/lib/?.lua'
local nixio = require 'nixio'
local fs = require 'nixio.fs'
local cst = require 'proxy_constants'

local file_internet = '/tmp/internet'
local file_nointernet = '/tmp/nointernet'
local cmd = '/usr/bin/nc -w2 -zv %s 443 2> /dev/null'
local host = cst.PortalUrl:match('^%w+://([^/]+)')
local check_connectivity = string.format(cmd,host)
local res = os.execute(check_connectivity)
local create_file = '/bin/touch %s'

if res == 0 then
  create_file = string.format(create_file,file_internet)
  local x = os.execute(create_file)
  if x ~= 0 then
    nixio.syslog('err','/scripts/interstate.lua: Failed to execute ' .. 
    create_file .. '. Exit code: ' .. x)
  end
  fs.remove(file_nointernet)
  dofile('/scripts/get-configuration.lua')
  dofile('/scripts/start-ap-services.lua')
else
  create_file = string.format(create_file,file_nointernet)
  local x = os.execute(create_file)
  if x ~= 0 then
    nixio.syslog('err','/scripts/interstate.lua: Failed to execute ' .. 
    create_file .. '. Exit code: ' .. x)
  end
  fs.remove(file_internet)
  dofile('/scripts/support-mode.lua')
end
os.exit()

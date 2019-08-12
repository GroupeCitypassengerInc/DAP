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

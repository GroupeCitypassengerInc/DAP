--[[
--
--  Script to disable wifi on a time interval. Called by cron
--
--]]
package.path = package.path .. ';/scripts/lib/?.lua'
package.path = package.path .. ';/portal/lib/?.lua'
local portal = require 'portal_proxy'
local lease  = require 'lease_file_reader'

local cmd = '/usr/bin/test -e /tmp/noaccess'
local x = os.execute(cmd)
if x ~= 0 then
  cmd = '/bin/touch /tmp/noaccess'
  local y = os.execute(cmd)
  if y ~= 0 then
    nixio.syslog('err','Failed to create /tmp/noaccess. Exit code: '..y)
  end
end

os.execute('/bin/sleep 15')
local cmd = '/usr/bin/test -e /tmp/noaccess'
local x = os.execute(cmd)
if x == 0 then
  local user_list = io.open('/tmp/dhcp.leases')
  for line in user_list:lines() do
    local user_ip = lease.get_ip(line)
    local user_mac = lease.get_mac(line)
    portal.deauthenticate_user(user_ip,user_mac)
  end
end

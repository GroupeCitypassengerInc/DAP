--[[
--
--  Script to disable wifi on a time interval. Called by cron
--
--]]



package.path = package.path .. ';/portal/lib/?.lua'
local portal = require 'portal_proxy'

local cmd = '/usr/bin/test -e /tmp/noaccess'
local x = os.execute(cmd)
if x ~= 0 then
  cmd = '/bin/touch /tmp/noaccess'
  local y = os.execute(cmd)
  if y ~= 0 then
    nixio.syslog('err','Failed to create /tmp/noaccess. Exit code: '..y)
  end
end

local function split_line(line)
  words = {}
  re = "[%w.:%-%_]+"
  for word in string.gmatch(line,re) do
    table.insert(words,word)
  end
  return words
end

local function get_mac(line)
  local t = split_line(line)
  return t[2]
end 

local function get_ip(line)
  local t = split_line(line)
  return t[3]
end

os.execute('/bin/sleep 15')
local cmd = '/usr/bin/test -e /tmp/noaccess'
local x = os.execute(cmd)
if x == 0 then
  local user_list = io.open('/tmp/dhcp.leases')
  for line in user_list:lines() do
    local user_ip = get_ip(line)
    local user_mac = get_mac(line)
    portal.deauthenticate_user(user_ip,user_mac)
  end
end

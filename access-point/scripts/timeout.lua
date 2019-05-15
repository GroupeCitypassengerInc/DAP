#!/usr/bin/lua
package.path       = package.path .. ";/portal/lib/?.lua"
local portal_proxy = require "portal_proxy"
local cst	   = require "proxy_constants"
local nixio        = require "nixio"

function split_line(line)
  words = {}
  re = "[%w.:]+"
  for word in string.gmatch(line,re) do
    table.insert(words,word)
  end
  return words
end

function get_mac(line)
  local t = split_line(line)
  return t[2]
end

function get_ip(line)
  local t = split_line(line)
  return t[3]
end

local path_dhcp = "/tmp/dhcp.leases"
local dhcp_leases = io.open("/tmp/dhcp.leases")
for line in dhcp_leases:lines() do
  local mac = get_mac(line) 
  local ip  = get_ip(line)
  local status = portal_proxy.status_user(ip,mac)
  if status == "Authenticated" then
    local cmd = "/usr/bin/find /var/localdb/%s/%s -name '*' -type d -mindepth 3"
    local cmd = string.format(cmd,mac,ip)
    local path = io.popen(cmd):read("*l")
    local cmd = "/bin/date -r " .. path .. " +%s"
    local date_auth = io.popen(cmd):read("*l")
    date_auth = tonumber(date_auth)
    local date_now = io.popen("/bin/date +%s"):read("*l")
    date_now = tonumber(date_now)
    local timeout = cst.ap_timeout
    if date_now - date_auth >= timeout then
      portal_proxy.deauthenticate_user(ip,mac)
      nixio.syslog("info","Timeout for authenticated user " .. mac .. ".\n")
    end
  end
  if status == "User in localdb" then
    local cmd = "/bin/date -r /var/localdb/" .. mac .. "/".. ip .. " +%s"
    local date_auth = io.popen(cmd):read("*l")
    date_auth = tonumber(date_auth)
    local date_now = io.popen("/bin/date +%s"):read("*l")
    date_now = tonumber(date_now)
    if date_now - date_auth >= 900 then
      portal_proxy.deauthenticate_user(ip,mac)
      nixio.syslog("info","Timeout for user " .. mac .. ".\n")
    end
  end
end 

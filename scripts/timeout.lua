#!/usr/bin/lua
package.path       = package.path .. ";/portal/lib/?.lua"
local portal_proxy = require "portal_proxy"
local cst	   = require "proxy_constants"
local nixio        = require "nixio"

local path_dhcp = "/tmp/dhcp.leases"
local dhcp_leases = io.open("/tmp/dhcp.leases")
for line in dhcp_leases:lines() do
  local mac = io.popen("/bin/echo " .. line .. " | awk '{print $2}'"):read("*l")
  local ip  = io.popen("/bin/echo " .. line .. " | awk '{print $3}'"):read("*l")
  local status = portal_proxy.status_user(ip,mac)
  if status == "Authenticated" then
    local cmd = "/usr/bin/find /var/localdb/%s/%s -name '*' -type d -mindepth 3"
    local cmd = string.format(cmd)
    local path = io.popen(cmd):read("*l")
    local cmd = "/bin/date " .. path .. " +%s"
    local date_auth = io.popen(cmd):read("*l")
    date_auth = tonumber(date_auth)
    local date_now = io.popen("date +%s"):read("*l")
    date_now = tonumber(date_now)
    local timeout = cst.ap_timeout
    if date_now - date_auth >= timeout then
      portal_proxy.deauthenticate_user(ip,mac)
      nixio.syslog("info","Timeout for authenticated user " .. mac .. ".\n")
      os.exit()
    end
    return true
  end
  if status == "User in localdb" then
    local cmd = "date -r /var/localdb/" .. mac .. "/".. ip .. " +%s"
    local date_auth = io.popen(cmd):read("*l")
    date_auth = tonumber(date_auth)
    local date_now = io.popen("date +%s"):read("*l")
    date_now = tonumber(date_now)
    if date_now - date_auth >= 900 then
      portal_proxy.deauthenticate_user(ip,mac)
      nixio.syslog("info","Timeout for user " .. mac .. ".\n")
      os.exit()
    end
    return true
  end
  os.exit()
end 

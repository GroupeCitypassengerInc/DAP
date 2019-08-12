#!/usr/bin/lua
package.path       = package.path .. ";/portal/lib/?.lua"
package.path       = package.path .. ";/scripts/lib/?.lua"
local portal_proxy = require "portal_proxy"
local cst	   = require "proxy_constants"
local nixio        = require "nixio"
local fs           = require "nixio.fs"
local lease        = require "lease_file_reader"
local date_module  = require "luci.http.protocol.date"

local path_dhcp = "/tmp/dhcp.leases"
local dhcp_leases = io.open("/tmp/dhcp.leases")
for line in dhcp_leases:lines() do
  local mac = lease.get_mac(line) 
  local ip  = lease.get_ip(line)
  local status = portal_proxy.status_user(ip,mac)
  if status == "Authenticated" then
    local cmd = "/usr/bin/find /var/localdb/%s/%s -name '*' -type d -mindepth 3"
    local cmd = string.format(cmd,mac,ip)
    local path = io.popen(cmd):read("*l")
    local cmd = "/bin/date -r " .. path .. " +%s"
    local date_auth = io.popen(cmd):read("*l")
    date_auth = tonumber(date_auth)
    local date_now = os.date( "%a, %d %b %Y %H:%M:%S GMT")
    date_now = date_module.to_unix(date_now)
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
    local date_now = os.date( "%a, %d %b %Y %H:%M:%S GMT")
    date_now = date_module.to_unix(date_now)
    if date_now - date_auth >= 7200 then
      portal_proxy.deauthenticate_user(ip,mac)
      nixio.syslog("info","Timeout for user " .. mac .. ".\n")
    end
  end
end
dhcp_leases:close()

local macs = io.popen("/bin/ls " .. cst.localdb)
for mac in macs:lines() do
  -- Remove macs from localdb without child dir
  local cmd = "/bin/ls %s/* > /dev/null 2>&1"
  cmd = string.format(cmd,cst.localdb .. "/" .. mac)
  local res = os.execute(cmd)
  local date_cmd = "/bin/date -r " .. cst.localdb .. "/" .. mac .. " +%s"
  local date_dir = io.popen(date_cmd):read("*l")
  date_dir = tonumber(date_dir)
  local date_now = os.date( "%a, %d %b %Y %H:%M:%S GMT")
  date_now = date_module.to_unix(date_now)
  if res ~= 0 then
    if date_now - date_dir >= 60 then
      fs.remove(cst.localdb .. "/" .. mac)
    end
  else
    -- Clean macs in localdb with expired lease
    local cmd = "/bin/grep %s /tmp/dhcp.leases > /dev/null"
    cmd = string.format(cmd,mac)
    local res = os.execute(cmd)
    if res ~= 0 then
      local rm = "/bin/rm -rf %s/%s"
      rm = string.format(rm,cst.localdb,mac)
      local x = os.execute(rm)
      if x ~= 0 then
        nixio.syslog("err","timeout.lua Failed to do " .. rm)
      end
    end
  end
end
macs:close()

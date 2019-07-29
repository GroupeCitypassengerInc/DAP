#!/usr/bin/lua
package.path       = package.path .. ";/portal/lib/?.lua"
package.path       = package.path .. ";/scripts/lib/?.lua"
local portal_proxy = require "portal_proxy"
local cst	   = require "proxy_constants"
local nixio        = require "nixio"
local lease        = require "lease_file_reader"

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
    if date_now - date_auth >= 7200 then
      portal_proxy.deauthenticate_user(ip,mac)
      nixio.syslog("info","Timeout for user " .. mac .. ".\n")
    end
  end
  if status == "Lease. Not in localdb" then
    local cmd = "/usr/sbin/iptables-save | /bin/grep 'A PREROUTING -s %s/32 -p udp -m mac --mac-source %s' > /dev/null"
    cmd = string.format(cmd,ip,mac)
    local res = os.execute(cmd)
    if res == 0 then
      portal_proxy.deauthenticate_user(ip,mac)
    end  
  end
end
dhcp_leases:close()

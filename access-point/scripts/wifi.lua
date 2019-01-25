#!/usr/bin/lua
--[[
--
-- Control script to list users (mac, ip, hostname, status), authenticate users,
-- deauthenticate users and get status of a particular user.
--
--]]

package.path       = package.path .. ";/portal/lib/?.lua"
local cst          = require "proxy_constants"
local portal_proxy = require "portal_proxy"
uhttpd             = require "uhttpd"
local data         = require "luci.cbi.datatypes"

local option   = arg[1]
local user_ip  = arg[2]
local user_mac = arg[3]

function verify_arguments(user_ip,user_mac)
  if data.ip4addr(user_ip) == false then
    print("Invalid ip address")	
    os.exit()
  end

  if data.macaddr(user_mac) == false then
    print("Invalid mac address")
    os.exit()
  end

  -- No dhcp lease
  local cmd       = "/scripts/get-mac-client " .. user_ip
  local mac_lease = io.popen(cmd):read("*l")
  if mac_lease ~= user_mac then
    portal_proxy.no_dhcp_lease()
    os.exit()
  end
  return true
end

if option == "list" then
  local path_dhcp   = "/tmp/dhcp.leases"
  local dhcp_leases = io.open("/tmp/dhcp.leases")
  print("Mac address\t\tIP address\tHostname\tStatus")
  for line in dhcp_leases:lines() do 
    local mac = io.popen("echo " .. line .. " | awk '{print $2}'"):read("*l")
    local ip = io.popen("echo " .. line .. " | awk '{print $3}'"):read("*l")
    local hostname = io.popen("echo " .. line .. " | awk '{print $4}'"):read("*l")
    local status = portal_proxy.status_user(ip,mac)
    print(mac .. "\t" .. ip .. "\t" .. hostname .. "\t" .. status)
  end
elseif option == "add" then
  if verify_arguments(user_ip,user_mac) == false then
    return false
  end
  if portal_proxy.status_user(user_ip,user_mac) == "Authenticated" then
    print("User already authenticated")
    return false
  end
  portal_proxy.initialize_redirected_client(user_ip,user_mac)
  local cmd = "ls " .. cst.localdb .. "/" .. user_mac .. "/" .. user_ip
  sid_db = io.popen(cmd):read("*l")
  local cmd = cmd .. "/" .. sid_db
  secret_db = io.popen(cmd):read("*l")
  val = portal_proxy.validate(user_mac,user_ip,sid_db,secret_db)
  if val == true then
    portal_proxy.success()
  end
elseif option == "del" then
  if verify_arguments(user_ip,user_mac) == false then
    return false
  end
  portal_proxy.deauthenticate_user(user_ip,user_mac)
  print("User with ip: " .. user_ip .. " and mac: " .. user_mac .. 
  " has been deauthenticated.") 
elseif option == "status" then
  if verify_arguments(user_ip,user_mac) == false then
    return false
  end
  local state = portal_proxy.status_user(user_ip,user_mac)
  print(state)
  return state
else
  print("wifi.lua [OPTION] ipaddr macaddr.")
  print("Possible usage: list, add, del, status.")
end

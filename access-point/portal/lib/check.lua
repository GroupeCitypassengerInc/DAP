--[[
--
-- Functions to select or insert user mac, user ip, session id and secret
-- in local database.
--
----]]

local db       = {}
local data     = require "luci.cbi.datatypes"
local cst      = require "proxy_constants"
local nixio    = require "nixio"
local fs       = require "nixio.fs"

local localdb  = cst.localdb

function db.select_localdb(user_mac,user_ip,sid,secret)
  if data.macaddr(user_mac) == false then
    return false
  end
  if data.ip4addr(user_ip) == false then
    return false
  end
  if data.hexstring(sid) == false then
    return false
  end
  if string.len(sid) ~= 32 then
    return false
  end
  if data.hexstring(secret) == false then
    return false
  end
  if string.len(secret) ~= 32 then
    return false
  end
  
  -- check directory with unique identifiers, to check client validity.
  local params  = {localdb, user_mac, user_ip, sid,secret}
  local path_db = table.concat(params,"/")
  local stat    = fs.stat(path_db)
  if not stat then
    local errno = nixio.errno()
    local errmsg = nixio.strerror(errno)
    nixio.syslog("err", "check.lua select_localdb: " ..  errno .. ": " .. errmsg)
    return false
  end
  return true
end

function db.insert_localdb(user_mac,user_ip,sid,secret)
  if data.macaddr(user_mac) == false then
    return false
  end
  if data.ip4addr(user_ip) == false then
    return false
  end
  if data.hexstring(sid) == false then
    return false
  end
  if string.len(sid) ~= 32 then
    return false
  end
  if data.hexstring(secret) == false then
    return false
  end
  if string.len(secret) ~= 32 then
    return false
  end
  
  -- create directories as unique identifiers, to store client data.
  local params = {localdb, user_mac, user_ip}
  local path   = table.concat(params,"/")
  fs.mkdir(localdb .. "/" .. user_mac)
  local mkdir_ip = fs.mkdir(path)
  if not mkdir_ip then
    return nil
  end
  local params = {localdb, user_mac, user_ip, sid, secret}
  local path   = table.concat(params,"/")
  local mkdir  = fs.mkdirr(path)
  if mkdir == true then
    return true
  else
    local errno = nixio.errno()
    local errmsg = nixio.strerror(errno)
    nixio.syslog("err", "check.lua insert_localdb: " .. errno .. ": " .. errmsg)
    return false
  end
end

return db

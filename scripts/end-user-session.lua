package.path = package.path .. ';/scripts/lib/?.lua'
package.path = package.path .. ';/portal/lib/?.lua'
local nixio = require 'nixio'
local data = require 'luci.cbi.datatypes'
local fw = require 'firewall'
local cst = require 'proxy_constants'

local user_ip = arg[1]
if not data.ip4addr(user_ip) then
  nixio.syslog('err', user_ip..' is not a valid ip address')
  os.exit(1)
end

fw.end_user_session(user_ip)

local rm = '/bin/rm -rf %s/%s'
local rm = string.format(rm, cst.atdb, user_ip)
local res = os.execute(rm)
if res ~= 0 then
  local msg = '/scripts/end-user-session.lua: failed to remove %s/%s from atdb'
  local msg = string.format(msg, cst.atdb, user_ip)
  nixio.syslog('err', msg)
end

os.exit(0)

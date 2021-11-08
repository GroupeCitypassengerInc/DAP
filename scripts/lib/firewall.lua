package.path = package.path .. ';/portal/lib/?.lua'
local nixio = require 'nixio'
local fw = {}
local helper = require 'lease_file_reader'
local cst = require 'proxy_constants'
local data = require 'luci.cbi.datatypes'

function fw.end_user_session(ip)
  if not data.ip4addr(ip) then
    nixio.syslog('err', ip..' is not a valid ip address')
    os.exit(1)
  end

  local cmd = '/usr/sbin/iptables-save | /bin/grep "PREROUTING -s %s"'
  local cmd = string.format(cmd, ip)

  local p = io.popen(cmd,'r')
  local rules = p:lines()
  for rule in rules do
    r = string.gsub(rule,'A','D',1)
    local delete_rule = '/usr/sbin/iptables -t nat %s'
    local delete_rule = string.format(delete_rule,r)
    local x = os.execute(delete_rule)
    if x ~= 0 then
      nixio.syslog('warning','failed to delete rule: '..r)
    end
  end
  p:close() 
end

return fw

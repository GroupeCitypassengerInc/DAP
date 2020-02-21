package.path = package.path .. ';/scripts/lib/?.lua'
local help = require 'lease_file_reader'
local data = require 'luci.cbi.datatypes'
local fw = require 'firewall'
local nixio = require 'nixio'
local fs = require 'nixio.fs'

logs = nil
if arg[1] then
  logs = io.open('/tmp/testfile','r')
else
  logs = io.popen('/sbin/logread -f | /bin/grep dnsmasq')
end

-- read dnsmasq log
for log in logs:lines() do
  if fw.is_reply_or_cached(log) then
    re = '[%w.-]+'
    local args = help.split_line(log,re)
    local ip = args[14]
    local host = args[12]
    nixio.syslog('info','seen ' .. host .. ' with ip ' .. ip)
    local authorized_host = fw.host_in_firewall_whitelist(host)
    if authorized_host then
      local ip_ok = data.ip4addr(ip)
      if ip_ok then
        fw.update_firewall(host,ip)
      end
    else
      nixio.syslog('debug',host .. 'is unauthorized')
    end
  end
end
logs:close()

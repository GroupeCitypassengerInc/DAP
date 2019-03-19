#!/usr/bin/lua
--[[                                                            
--                                                              
-- DNS Logging script. It parses dnsmasq log and insert DNS queries in
-- a remote database.                   
--                                       
]]-- 

package_path = package_path .. ';/portal/lib/?.lua'
log = require 'dns-logger'

local in = io.popen('/bin/cat /tmp/bar','r')

for line in in:lines() do
  if log.is_dns_query(line) == true then
    local date = log.get_date(line)
    local src = log.get_source_ip(line)
    local domain = log.get_domain(line)
    log.insert_log(date,domain,src)
  end
end
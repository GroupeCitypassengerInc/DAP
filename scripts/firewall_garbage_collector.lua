package.path = package.path .. ';/scripts/lib/?.lua'
local fw = require 'firewall'
local helper = require 'lease_file_reader'

local cmd = '/usr/sbin/iptables-save | /bin/grep "A PREROUTING"'
local f = io.popen(cmd)
for rule in f:lines() do
  local args = helper.split_line(rule,'[%w-.]+')
  local timestamp = args[14]
  if tonumber(timestamp) then
    local now = io.popen('/bin/date +%s'):read('*l')
    if now - timestamp > 1800 then
      rule = string.gsub(rule,'A','D',1)
      rule = '/usr/sbin/iptables -t nat '..rule
      local rc = os.execute(rule)
      if rc ~= 0 then
        nixio.syslog('err','Failed to remove expired rule: '..rule)
      end
    end 
  end
end
f:close() 

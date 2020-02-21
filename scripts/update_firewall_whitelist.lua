package.path = package.path .. ';/portal/lib/?.lua'
local cst = require 'proxy_constants'
local helper = require 'helper'
local nixio = require 'nixio'

local firewall_base = cst.firewall_whitelist
local firewall_full = cst.firewall_whitelist_full

f = io.open(firewall_base,'r')
g = io.open(firewall_full,'w')

function write_to_firewall_file(lines)
  for h in lines do
    if h:match('Name%:') then
      host = h:match('[%w+.-]+$')
      g:write(host..'\n')
    end
  end
end

for line in f:lines() do
  local cmd = '/usr/bin/nslookup '..line
  local rc,exit = helper.command(cmd)
  if exit ~= 0 then
     nixio.syslog('err','failed to update firewall whitelist for host '
                       ..host..'; exit: '..exit)
  else
    rc = string.gmatch(rc,'[^\r\n]+')
    write_to_firewall_file(rc)
  end
end
f:close()
g:close()

package.path = package.path .. ';/portal/lib/?.lua'
local cst = require 'proxy_constants'
local nixio = require 'nixio'

local function remove(filename,starting_line,num_lines)
  local fp = io.open(filename,"r")
  if fp == nil then return nil end
  content = {}
  i = 1;
  for line in fp:lines() do
    if i < starting_line or i >= starting_line + num_lines then
      content[#content+1] = line
    end
    i = i + 1
  end
  if i > starting_line and i < starting_line + num_lines then
    nixio.syslog("warning","Tried to remove lines after EOF.")
  end
  fp:close()
  fp = io.open(filename,"w+")
  for i = 1, #content do
    fp:write(string.format("%s\n",content[i]))
  end
  fp:close()
end

if cst.PortalUrl == nil then
  nixio.syslog('warning','No portal URL')
  return false
end

local fpath = '/tmp/dns.data'
local c = 0
local f = io.open(fpath)
local content = f:read('*a')
f:close()
local dns = {}
for s in content:gmatch('[^\r\n]+') do
  table.insert(dns,s)
  c = c + 1
end
data = table.concat(dns,",")
local curl = '/usr/bin/curl -d "[ %s ]" "%s/index.php?digilan-token-action=write&digilan-token-secret=%s"'
local curl = string.format(curl,data,cst.PortalUrl,cst.ap_secret)
local x = os.execute(curl)
if x == 0 then
  nixio.syslog('info','DNS logs posted to ' .. cst.PortalUrl .. '.')
else
  nixio.syslog('warning','cURL POST failed.')
end
remove(fpath,1,c)

--[[
--
-- DNS Logging functions for logging script. This lib is used by
-- logger.lua script.
--
]]--

log = {}

local data  = require 'luci.cbi.datatypes'
local nixio = require 'nixio'

function log.is_dns_query(line)
  local re = 'query%[A%]'
  s = string.match(line,re)
  return s == 'query[A]'
end

function split_line(line)
  words = {}
  local re = '[%w.-]+'
  for w in string.gmatch(line, re) do
    table.insert(words, w)
  end
  return words
end

function log.get_domain(line)
  local t = split_line(line)
  return t[10]
end

function log.get_source_ip(line)
  local t = split_line(line)
  return t[12]
end

function get_month(m)
  t = {Jan='01', Feb='02', Mar='03', Apr='04', May='05', Jun='06', Jul='07', Aug='08', Sep='09', Oct='10', Nov='11', Dec='12'}
  return t[m]
end

-- Extracts and parse date time from log line with a YYYY-MM-DD HH:mm:ss format
function log.get_date(line)
  local t = split_line(line)
  local d = {}
  local y = os.date('%Y') -- Year
  local m = get_month(t[1])
  -- t[2], t[3], t[4], t[5] ===> day, hour, minute, second
  day = tonumber(t[2])
  if day < 10 then
    day = '0' .. day
  else
    day = t[2]
  end  
  d = {y, m, day, t[3], t[4], t[5]}
  date = '%s-%s-%s'
  date = string.format(date, d[1], d[2], d[3])
  time = '%s:%s:%s'
  time = string.format(time, d[4], d[5], d[6])
  ts = '%s %s'
  return string.format(ts,date,time)
end

function log.insert_log(date,domain,source)
  if data.ip4addr(source) == false then
    nixio.syslog('err', 'Invalid source: ' .. source)
    return false
  end
  local re = '[%w.-]+'
  if string.match(domain,re) ~= domain then
    nixio.syslog('err', 'Invalid domain: ' .. domain)
    return false
  end
  if string.len(domain) > 253 then
    nixio.syslog('err', 'Invalid domain length.')
    return false
  end
  local re = '%d%d%d%d%-%d%d%-%d%d% %d%d%:%d%d%:%d%d'
  local s = string.find(date,re)
  if s == nil then
    nixio.syslog('err', 'Invalid date format:' .. date)
    return false
  end
  if string.sub(date,s) ~= date then
    nixio.syslog('err', 'Date not matched, got: ' .. date)
    return false
  end
  -- Get session id and secret to find user_id for this connection in WP tables.
  local cmd = '/usr/bin/find /var/localdb -name %s -type d'
  cmd = string.format(cmd,source)
  local dir = io.popen(cmd):read('*l')
  if dir == nil then
    return false
  end
  local cmd = '/bin/ls %s'
  cmd = string.format(cmd,dir)
  local sid = io.popen(cmd):read('*l')
  cmd = cmd .. '/%s'
  cmd = string.format(cmd,sid)
  secret = io.popen(cmd):read('*l')
  cmd = cmd .. '/%s'
  cmd = string.format(cmd,secret)
  user_id = io.popen(cmd):read('*l')
  local row = '{\\"date\\": \\"%s\\", \\"user_id\\": \\"%s\\", \\"domain\\": \\"%s\\"}'
  local row = string.format(row,date,user_id,domain)
  f = io.open('/tmp/dns.data','a')
  io.output(f)
  io.write(row,'\n')
  io.close(f)
end

return log

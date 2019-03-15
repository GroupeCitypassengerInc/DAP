--[[
--
-- DNS Logging functions for logging script. This lib is used by
-- logger.lua script.
--
]]--

log = {}

local data  = require 'luci.cbi.datatypes'
local sql   = require 'luasql.mysql'
local nixio = require 'nixio'

-- CHANGE THIS
db_name = 'wordpresstest'
usernmae = 'foobar'
password = 'foobar'
host = '172.16.1.30'
port = '3306'

function log.is_dns_query(line)
  local re = 'query%[A%]'
  s = string.match(line,re)
  return s == 'query[A]'
end

function log.get_domain(line)
  local re = '[%w.-]+'
  local n = 0
  for w in string.gmatch(line,re) do
    n = n + 1
    if n == 10 then
      return w
    end
    if n > 10 then
      break
    end 
  end
end

function log.get_source_ip(line)
  local re = '[%w.-]+'
  local n = 0      
  for w in string.gmatch(line,re) do
    n = n + 1
    if n == 12 then
      if data.ip4addr(w) == false then
        return false
      end
      return w     
    end   
  end
end

function get_month(m)
  t = {Jan='01',Feb='02',Mar='03',Apr='04',May='05',Jun='06',Jul='07',Aug='08',Sep='09',Oct='10',Nov='11',Dec='12'}
  return t[m]
end

-- Extracts and parse date time from log line with a YYYY-MM-DD HH:mm:ss format
function log.get_date(line)
  re = '[%w.-]+'
  local n = 0
  d = {}
  d[1] = os.date('%Y')
  for w in string.gmatch(line,re) do
    n = n + 1
    if n == 1 then
      local m = get_month(w)
      d[2] = m
    elseif n == 2 then
      d[3] = w 
    elseif n == 3 then                                                                                                                                            
      d[4] = w                                                                                                                                                
    elseif n == 4 then                                                                                                                                            
      d[5] = w
    elseif n == 5 then                                                                                                                                            
      d[6] = w
    else
      break                                                                                                                                                
    end
  end
  date = '%s-%s-%s'
  date = string.format(date,d[1],d[2],d[3])
  time = '%s:%s:%s'
  time = string.format(time,d[4],d[5],d[6])
  ts = '%s %s'
  return string.format(ts,date,time)
end

function log.insert_log(date,domain,source)
  if data.ipv4addr(source) == false then
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
  local cmd = '/usr/bin/find /var/localdb -name %s -type d'
  cmd = string.format(cmd,source)
  local dir = io.popen(cmd):read('*l')
  local cmd = '/bin/ls %s'
  cmd = string.format(cmd,dir)
  local sid = io.popen(cmd):read('*l')
  cmd = cmd .. '/%s'
  cmd = string.format(cmd,sid)
  secret = io.popen(cmd):read('*l')
  local query = "CALL dns_insert('%s', '%s', '%s', '%s', '%s');" 
  query = string.format(query, date, source, domain, sid, secret) 
  env = assert(sql.mysql())
  connect = assert(env:connect(db_name,login,password,host))
  cur = assert(connect:execute(query))
end

return log

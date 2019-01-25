--[[
--
-- Functions and variables for unit testing purposes
--
--]]

unit = {}
local cst          = require "proxy_constants"
local portal_proxy = require "portal_proxy"
local sql          = require "luasql.mysql"
local data         = require "luci.cbi.datatypes"
unit.count        = 0
unit.passed_count = 0 
local urandom = assert(io.open('/dev/urandom','rb'))
local a, b, c, d = urandom:read(4):byte(1,4)
urandom:close()
local seed = a*1000000 + b*10000 + c *100 + d
math.randomseed(seed)

local CURL = "curl "

function unit.expect(info, foo, expect)
  unit.count = unit.count + 1
  result = ""
  if (foo == expect) then
    unit.passed_count = unit.passed_count + 1
    result = format_string("PASS","\27[1m\27[32m")
  else
    result = format_string("FAIL","\27[1m\27[31m")
  end
  print ("\27[94m" .. info .."\27[0m" .." test case #" .. unit.count .. ": " .. result)
end

function generate_random_ip()
  local a = math.random(0,255)
  local b = math.random(0,255)
  local c = math.random(0,255)
  local d = math.random(0,255)
  return tostring(a) .. "." .. tostring(b) .. "." .. tostring(c) .. "." .. tostring(d)
end
unit.user_ip = generate_random_ip() 

function generate_random_mac()
  local rng_mac = ""
  local hex_table = {"0","1","2","3","4","5","6","7","8","9","a","b","c","d","e","f"}
  for i=0,16,1 do
    if i%3 == 2 then
      rng_mac = rng_mac .. ":"
    else
      rng_mac = rng_mac .. hex_table[math.random(1,16)]
    end
  end
  return rng_mac 
end
unit.user_mac = generate_random_mac()

local db_name  = 'wordpresstest'
local login    = 'username'
local password = 'password'
local host     = '127.0.0.1'

function get_version()
  local env      = assert(sql.mysql())
  local connect  = assert(env:connect(db_name,login,password,host))
  local query    = "SELECT option_value FROM wp_options WHERE option_name='citypassenger_plugin_version'"
  local cur  = assert(connect:execute(string.format(query)))  
  local row = cur:fetch({}, "a")
  print("DB version = " .. row.option_value)
  local v = row.option_value
  cur:close()
  connect:close()
  env:close()
  return v
end

function unit.select_users(user_mac)
  local v        = get_version() 
  local env      = assert(sql.mysql())
  local connect  = assert(env:connect(db_name,login,password,host))
  local mac_conv = 'CAST(CONV(REPLACE(REPLACE("'.. user_mac ..
  '", ":", ""),"-",""),16,10) AS UNSIGNED)'
  local query    = "SELECT id, CONV(mac,10,16) AS mac, social_id "
  		.. "FROM wp_citypassenger_users_".. v .." WHERE mac=" .. mac_conv
  print("SQL QUERY = " .. query)
  local cur  = assert(connect:execute(string.format(query)))  
  local row = cur:fetch({}, "a")
  while row do
    if row.id == nil then
      row.id = ""
    end
    if row.mac == nil then
      row.mac = ""
    end
    if row.social_id == nil then
      row.social_id = ""
    end
    while string.len(row.mac) < 12 do
      row.mac = "0" .. row.mac
    end
    row.mac=(row.mac):gsub(("."):rep(2),"%1:"):sub(1,-2)

    print(string.format(" id: %s\n ".. 
    "mac: %s\n social_id: %s\n ",
    row.id,
    row.mac,
    row.social_id))
    row = cur:fetch(row, "a")
  end
  cur:close()
  connect:close()
  env:close()
end

function unit.select_wpdb(user_ip,sid,secret)
  local v       = get_version()  
  local env     = assert(sql.mysql())
  local connect = assert(env:connect(db_name,login,password,host))

  local query  = "SELECT INET_NTOA(user_ip) AS user_ip,"..
  " CONV(ap_mac,10,16) AS ap_mac, secret, ap_validation," .. 
  " wp_validation, authentication_mode, creation, sessionid, user_id FROM " ..
  "wp_citypassenger_connections_"..v.." WHERE user_ip=INET_ATON('" .. user_ip .. 
  "') AND sessionid=" .. "'".. sid .. "'" .. 
  " AND secret=" .. "'" .. secret .. "'"
  print("SQL QUERY = " .. query)
  local cur  = assert(connect:execute(string.format(query)))  
  local row = cur:fetch({}, "a")
  while row do
    if row.wp_validation == nil then
      row.wp_validation = ""
    end
    if row.ap_validation == nil then
      row.ap_validation = ""
    end
    if row.user_id == nil then
      row.user_id = ""
    end
    if row.authentication_mode == nil then
      row.authentication_mode = ""
    end
    while string.len(row.ap_mac) < 12 do
      row.ap_mac = "0" .. row.ap_mac
    end
    row.ap_mac=(row.ap_mac):gsub(("."):rep(2),"%1:"):sub(1,-2)
    print(string.format(" user_ip: %s\n ".. 
    "ap_mac: %s\n ap_validation: %s\n "..
    "wp_validation: %s\n secret: ".. 
    "%s\n authentication_mode: %s\n creation: %s\n sessionid: %s\n user_id: %s", 
    row.user_ip,
    row.ap_mac,
    row.ap_validation,
    row.wp_validation,
    row.secret,
    row.authentication_mode,
    row.creation,
    row.sessionid,
    row.user_id))
    row = cur:fetch(row, "a")
  end
  cur:close()
  connect:close()
  env:close()
end

function unit.curl_authenticate(username,password,sid,user_mac)
  local curl_login = CURL .. 
  "-v -c jar -X POST -d 'log=" .. username .."' -d 'pwd=" .. password .. "' " .. 
  '"' .. cst.PortalUrl ..'wordpress/wp-login.php?session_id=' .. 
  sid .."&mac=".. user_mac .. '"'
  print(curl_login)
  local post_login = io.popen(curl_login):read("*a")
end

return unit

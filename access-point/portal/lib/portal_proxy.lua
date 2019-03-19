--
-- The Radio device will serve HTTP and comunicate with the cloud
-- portal and the client
-- it will discover local IP and MAC and check secrets
-- to open LocalFirewall , hence the internet access
--
local cst      = require "proxy_constants"
local ut       = require "check"
local protocol = require "luci.http.protocol"
local data     = require "luci.cbi.datatypes"
local json     = require "luci.jsonc"
local nixio    = require "nixio"
local fs       = require "nixio.fs"
local proxy    = {}
local CURL     = "/usr/bin/curl "

function redirect(url)
  uhttpd.send("Status: 302 Found\r\n")
  uhttpd.send("Location: "..url.."\r\n")  
  uhttpd.send("Content-Type: text/html\r\n")
  uhttpd.send("\r\n\r\n")
end

function proxy.success()
  redirect(cst.PortalUrl .. "/")
end

function proxy.no_dhcp_lease()
  uhttpd.send("Status: 406 Not Acceptable.\r\n")
  uhttpd.send("Content-Type: text/html\r\n")
  uhttpd.send("\r\n\r\n")
  uhttpd.send("No dhcp lease.")
end

function proxy.redirect_443_to_511_when_not_authenticated()
  uhttpd.send("Status: 511 Network Authentication Required.\r\n")
  uhttpd.send("Content-Type: text/html\r\n")
  uhttpd.send("\r\n\r\n")
  uhttpd.send("Not authenticated.")
end

function proxy.initialize_redirected_client(user_ip,user_mac)
  -- Send a request to server
  local ap_secret = cst.ap_secret
  local cmd = CURL ..'"' .. cst.PortalUrl .. 
  '/index.php?digilan-token-action=create&user_ip=' .. 
  user_ip ..'&ap_mac=' .. cst.ap_mac .. 
  '&digilan-token-secret=' .. ap_secret .. '"'
  print(cmd)
  -- server responds with secret and sid
  local server_response = io.popen(cmd):read("*a")
  local response        = json.parse(server_response)
  
  if response.validated == nil then
    uhttpd.send("Status: 400 Bad Request\r\n")
    uhttpd.send("Content-Type: text/html\r\n")
    uhttpd.send("\r\n\r\n")
    local cmd = "/bin/rm -rf " .. cst.localdb .. "/" .. user_mac
    local x = os.execute(cmd)
    if x ~= 0 then
      nixio.syslog('err', cmd .. ' Failed with exit code: ' .. x)
    end
    return false
  end

  if response.validated == false then
    uhttpd.send("Status: 400 Bad Request\r\n")
    uhttpd.send("Content-Type: text/html\r\n")
    uhttpd.send("\r\n\r\n")
    stringified_resp = json.stringify(response)
    uhttpd.send(stringified_resp)
    return false
  end

  -- store sid and secret in local db
  local sid    = response.session_id
  local secret = response.secret
  
  local insert = ut.insert_localdb(user_mac,user_ip,sid,secret)
 
  if insert == false then
    local data_table = {
      message="invalid parameters", 
      user_mac=user_mac, 
      user_ip=user_ip,
      session_id=sid,
      secret=secret
    }
    data_table_stringified = json.stringify(data_table)
    uhttpd.send("Status: 406 Not Acceptable.\r\n")
    uhttpd.send("Content-Type: text/html\r\n")
    uhttpd.send("\r\n\r\n")
    uhttpd.send(data_table_stringified)
    return false
  end

  -- return a 302
  local rdrinfo = "session_id=" .. sid .. "&mac=" .. user_mac 
  redirect(cst.PortalUrl .. "/wp-login.php?" .. rdrinfo)
  return { sid, secret }
end

function proxy.validate(user_mac,user_ip,sid,secret)
  -- check local db
  if ut.select_localdb(user_mac,user_ip,sid,secret) == false then
    return false
  end
  -- check server db
  local user_id = validate_data_on_server(user_ip,user_mac,secret,sid)
  if user_id == false then
    return false
  end
  local params = {cst.localdb, user_mac, user_ip, sid, secret}
  local path   = table.concat(params,"/")
  local mkdir  = fs.mkdirr(path .. "/" .. user_id)
  if mkdir == true then
    local cmd_auth = "/usr/sbin/iptables -t nat -I PREROUTING -p udp -s " ..user_ip ..                         
    " -m mac --mac-source " .. user_mac .. " --dport 53 -j REDIRECT --to-ports 5353 > /dev/null"
    local a = os.execute(cmd_auth)
    if a ~= 0 then
      nixio.syslog('err', cmd_auth .. ' failed with exit code: ' .. a)
      return false
    end
    return true
  else
    local errno = nixio.errno()
    local errmsg = nixio.strerror(errno)
    nixio.syslog("err", errno .. ": " .. errmsg)
    return false
  end
  return true
end

function validate_data_on_server(user_ip,user_mac,secret,sid)
  local ap_secret = cst.ap_secret
  local cmd  = CURL ..'"' ..  cst.PortalUrl .. '/index.php?digilan-token-action=validate&user_ip='
  .. user_ip .. '&ap_mac='.. cst.ap_mac ..
  '&secret=' .. secret .. '&session_id=' .. sid ..'&digilan-token-secret=' .. ap_secret.. '"'
  local server_response = io.popen(cmd):read("*a")
  local response        = json.parse(server_response)
  local r               = response.authenticated
  local user_id 	= response.user_id
  if r == true then
    return user_id
  end
  return false
end

function proxy.deauthenticate_user(user_ip,user_mac)
  local cmd = "/usr/sbin/iptables -t nat -D PREROUTING -p udp -s " ..user_ip .. 
  " -m mac --mac-source " .. user_mac .. " --dport 53 -j REDIRECT --to-ports 5353 > /dev/null"
  local x = os.execute(cmd)
  if x ~= 0 then
    nixio.syslog('err',cmd .. ' failed with exit code: ' .. x)
    return false
  end
  local cmd = "/bin/rm -rf " .. cst.localdb .. "/" .. user_mac
  local y = os.execute(cmd)
  if y ~= 0 then
    nixio.syslog('err',cmd .. ' failed with exit code: ' .. y)
    return false
  end
end

function proxy.status_user(user_ip,user_mac)
  local params    = {cst.localdb,user_mac,user_ip}
  local select_db = table.concat(params,"/")
  local cmd_sid   = "/bin/ls " .. select_db
  local x = os.execute(cmd_sid .. " &> /dev/null")
  if x ~= 0 then
    return "Lease. Not in localdb"
  end
  local sid_db    = io.popen(cmd_sid):read("*l")
  if sid_db == nil then
    return "Lease. Not in localdb"
  end
  local cmd_secret = "ls " .. select_db .."/" .. sid_db 
  local secret_db  = io.popen(cmd_secret):read("*l")
  user_mac         = string.upper(user_mac)
  local cmd = "/usr/sbin/iptables-save | /bin/grep ".. user_ip .. " | /bin/grep " .. user_mac .. " > /dev/null"
  if os.execute(cmd) ~= 0 then
    return "User in localdb"
  end
  return "Authenticated"
end

function proxy.print_data(data)
  uhttpd.send("Status: 200 OK\r\n")
  uhttpd.send("Content-Type: text/html\r\n")
  uhttpd.send("\r\n\r\n")
  uhttpd.send(data .. "\r\n")
end

return proxy

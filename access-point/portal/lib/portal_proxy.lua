--
-- The Radio device will serve HTTP and comunicate with the cloud
-- portal and the client
-- it will discover local IP and MAC and check secrets
-- to open LocalFirewall , hence the internet access
--
local cst      = require "proxy_constants"
local ut       = require "check"
local json     = require "luci.jsonc"
local nixio    = require "nixio"
local fs       = require "nixio.fs"
local helper   = require "helper"
local http     = require "luci.http"
local sys      = require "luci.sys"
local proxy    = {}
local CURL     = "/usr/bin/curl "


function redirect(url)
  uhttpd.send("Status: 302 Found\r\n")
  uhttpd.send("Location: "..url.."\r\n")  
  uhttpd.send("Content-Type: text/html\r\n\r\n")
end

function proxy.success()
  if cst.landing_page == nil then
    redirect(cst.PortalUrl .. "/")
  else
    redirect(cst.landing_page)
  end
end

function proxy.serve_portal_to_preauthenticated_user(user_mac,user_ip)
  local params    = {cst.localdb,user_mac,user_ip}
  local select_db = table.concat(params,"/")
  local cmd_sid   = "/bin/ls " .. select_db
  local sid_db    = io.popen(cmd_sid):read("*l")
  local query_table = {
    session_id=sid_db,
    mac=user_mac
  }
  local rdrinfo = http.build_querystring(query_table)
  local query_start_index = string.find(cst.PortalPage,"%?")
  if query_start_index then
    rdrinfo = string.gsub(rdrinfo,"%?","%&")
  end
  redirect(cst.PortalPage .. rdrinfo)
end

function proxy.no_wifi()
  local hostname = sys.hostname()
  if not cst.error_page then
    redirect(cst.PortalUrl .. "/")
  else 
    redirect(cst.error_page .. "?hostname=" .. hostname)
  end
end

function proxy.no_dhcp_lease()
  uhttpd.send("Status: 406 Not Acceptable.\r\n")
  uhttpd.send("Content-Type: text/html\r\n")
  uhttpd.send("\r\n\r\n")
  uhttpd.send("No dhcp lease.")
end

function proxy.initialize_redirected_client(user_ip,user_mac)
  nixio.syslog("info","Initializing redirected user " .. user_mac)
  -- Send a request to server
  local ap_secret = cst.ap_secret
  local cmd = CURL ..
  '--retry 3 --retry-delay 5 --fail -m 10 --connect-timeout 10 -s -L "' .. 
  cst.PortalUrl .. 
  '/index.php?digilan-token-action=create&user_ip=' .. 
  user_ip ..'&ap_mac=' .. cst.ap_mac .. 
  '&digilan-token-secret=' .. ap_secret .. '"' 
  -- server responds with secret and sid

  response,exit = helper.command(cmd)
  if exit ~= 0 then
    nixio.syslog('err','connection create: cURL failed with exit code: '..exit)
    return false
  end
  response = json.parse(response)
  
  if response == nil then
    local cmd = "/bin/rm -rf " .. cst.localdb .. "/" .. user_mac
    local x = os.execute(cmd)
    if x ~= 0 then
      nixio.syslog("err", cmd .. " Failed with exit code: " .. x)
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

  if insert == nil then
    redirect("http://cloudgate.citypassenger.com")
  end
 
  if not insert then
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
 
  local query_table = {
    session_id=sid,
    mac=user_mac
  }
  -- return a 302
  nixio.syslog("info","Redirecting user " .. user_mac .. " to portal")
  local rdrinfo = http.build_querystring(query_table)
  local query_start_index = string.find(cst.PortalPage,"%?")
  if query_start_index then
    rdrinfo = string.gsub(rdrinfo,"%?","%&")
  end
  redirect(cst.PortalPage .. rdrinfo)
  return true
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
  local params = {cst.localdb,user_mac,user_ip,sid,secret}
  local path   = table.concat(params,"/")
  local mkdir  = fs.mkdir(path .. "/" .. user_id)
  if mkdir == true then
    authorize_access(user_ip,user_mac)
    nixio.syslog("info","User with mac " .. user_mac .. " and ip " ..
    user_ip .. " has been authenticated.")
    return true
  else
    local errno = nixio.errno()
    local errmsg = nixio.strerror(errno)
    if errno == 17 then
      return true
    end
    nixio.syslog("err", "portal_proxy.lua validate: " .. errno .. ": " .. errmsg)
    return false
  end
end

function validate_data_on_server(user_ip,user_mac,secret,sid)
  local ap_secret = cst.ap_secret
  local cmd  = CURL ..'--retry 3 --retry-delay 5 --fail -m 10 --connect-timeout 10 -s -L "' 
  .. cst.PortalUrl .. '/index.php?digilan-token-action=validate&user_ip='
  .. user_ip .. '&ap_mac='.. cst.ap_mac ..
  '&secret=' .. secret .. '&session_id=' .. sid ..'&digilan-token-secret=' .. ap_secret.. '"'
  while true do
    response,exit = helper.command(cmd)
    if exit ~= 0 then
      nixio.syslog('err','validate. cURL failed with exit code:'..exit)
      return false
    end
    response = json.parse(response)
    if response ~= nil then
      break
    end
  end
  local r = response.authenticated
  local user_id	= response.user_id
  if r == true then
    return user_id
  end
  return false
end

function proxy.deauthenticate_user(user_ip,user_mac)
  local cmd = "/usr/sbin/iptables -t nat -D PREROUTING -p udp -s " ..user_ip .. 
  " -m mac --mac-source " .. user_mac .. " --dport 53 -j REDIRECT --to-ports 5353 > /dev/null"
  local x = os.execute(cmd)
  local x = x / 256
  if x == 2 then
    nixio.syslog("warning",cmd .. " failed with exit code "..x)
  end
  cmd = "/usr/sbin/iptables -t nat -D PREROUTING -p tcp -i bridge1 -s %s -m mac --mac-source %s --dport 80 -j ACCEPT"
  cmd = string.format(cmd,user_ip,user_mac)
  x = os.execute(cmd)
  x = x / 256
  if x == 2 then
    nixio.syslog("warning",cmd .. " failed with exit code "..x)
  end
  local lockpath = cst.tmpdb .. "/" .. user_mac
  local rm = fs.rmdir(lockpath)
  if rm == nil then
    nixio.syslog("warning",lockpath .. " does not exist")
  end
  local cmd = "/bin/rm -rf " .. cst.localdb .. "/" .. user_mac
  local y = os.execute(cmd)
  if y ~= 0 then
    nixio.syslog("err",cmd .. " failed with exit code: " .. y)
    return false
  end
end

function proxy.reauthenticate_user(user_ip,user_mac,sid,secret,date_auth,user_id)
  nixio.syslog("info","Reauthenticating " .. user_mac)
  local insert = ut.insert_localdb(user_mac,user_ip,sid,secret)
  if insert == false then
    nixio.syslog("info","inserted in localdb? " .. tostring(insert))
    return false
  end
  local params = {cst.localdb,user_mac,user_ip,sid,secret}
  local path = table.concat(params,"/")
  local mkdir = fs.mkdir(path .. "/" .. user_id)
  if mkdir == nil then
    nixio.syslog("warning","Failed to create user_id dir")
    return false
  end
  path = path .. "/" .. user_id
  local dirtime =  fs.utimes(path,date_auth)
  if dirtime == false then
    nixio.syslog("err","Failed to set date on localdb file")
    return false
  end
  nixio.syslog("info","reauthenticate")
  authorize_access(user_ip,user_mac)
  return true
end

function set_iptables_rule_for_internet_access(user_ip,user_mac)
  local cmd_auth = "/usr/sbin/iptables -t nat -I PREROUTING -p udp -s " ..user_ip ..                         
  " -m mac --mac-source " .. user_mac .. " --dport 53 -j REDIRECT --to-ports 5353 > /dev/null"
  local a = os.execute(cmd_auth)
  if a ~= 0 then
    nixio.syslog("err", cmd_auth .. " failed with exit code: " .. a)
    fs.remove(cst.tmpdb .. "/" .. user_mac)
    return false
  end
  cmd_auth = "/usr/sbin/iptables -t nat -I PREROUTING -p tcp -i bridge1 -s %s -m mac --mac-source %s --dport 80 -j ACCEPT"
  cmd_auth = string.format(cmd_auth,user_ip,user_mac)
  a = os.execute(cmd_auth)
  if a ~= 0 then
    nixio.syslog("err", cmd_auth .. " failed with exit code: " .. a)
    fs.remove(cst.tmpdb .. "/" .. user_mac)
    return false
  end
end

function authorize_access(user_ip,user_mac)
  local mk  = fs.mkdir(cst.tmpdb .. "/" .. user_mac)
  if mk then
    nixio.syslog("info","Setting rule for " .. user_mac)
    set_iptables_rule_for_internet_access(user_ip,user_mac)
    return true
  else
    nixio.syslog("info","Rule already applied for " .. user_mac)
    return false
  end
end

function proxy.has_user_been_connected(mac)
  local cmd  = CURL ..'--retry 3 --retry-delay 5 --fail -m 10 --connect-timeout 10 -s -L "'                          
  .. cst.PortalUrl .. '/index.php?digilan-token-action=reauth&mac='.. mac ..                                          
  '&digilan-token-secret=' .. cst.ap_secret.. '"'
  while true do
    local connection,exit = helper.command(cmd)
    if exit == 0 then
      connection = json.parse(connection)
      return connection
    else
      nixio.syslog("err",cmd .. " failed with exit code: " .. exit)
      break
    end
  end
  return false
end

function proxy.status_user(user_ip,user_mac)
  local params    = {cst.localdb,user_mac,user_ip}
  local select_db = table.concat(params,"/")
  local cmd_sid   = "/bin/ls " .. select_db 
  local sid_db,x = helper.command(cmd_sid)
  if x ~= 0 then
    return "Lease. Not in localdb"
  end
  if sid_db == nil then
    return "Lease. Not in localdb"
  end
  local cmd_secret = cmd_sid .. "/" .. sid_db
  local secret_db  = io.popen(cmd_secret):read("*l")
  user_mac         = string.upper(user_mac)
  local cmd = "/usr/sbin/iptables-save | /bin/grep 'A PREROUTING -s %s/32 -p udp -m mac --mac-source %s' > /dev/null"
  local cmd = string.format(cmd,user_ip,user_mac)
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

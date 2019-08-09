package.path       = package.path .. ";/portal/lib/?.lua"
local cst          = require "proxy_constants"
local portal_proxy = require "portal_proxy"
local protocol     = require "luci.http.protocol"
local json         = require "luci.jsonc"
local nixio        = require "nixio"
local support      = require "troubleshooting"
local fs           = require "nixio.fs"

function handle_request(env)
  local url_path = protocol.urldecode(string.sub(env.REQUEST_URI,2))
  -- Return a troubleshooting page when AP has no internet.
  local a = os.execute("/usr/bin/test -e /tmp/internet")
  if a ~= 0 then
    if url_path == "support" then
      support.troubleshoot()
      os.exit()
    end
  end
  
  -- Return a wordpress error page when wifi is scheduled to be down.
  local b = os.execute("/usr/bin/test -e /tmp/noaccess")
  if b == 0 then
    portal_proxy.no_wifi()
    os.exit()
  end

  local query_string = env.QUERY_STRING	

  local user_ip   = env.REMOTE_ADDR
  local ap_mac    = cst.ap_mac
  local get_mac   = "/scripts/get-mac-client " .. user_ip

  local user_mac  = io.popen(get_mac):read("*l")
  if not user_mac then
    portal_proxy.no_dhcp_lease()
    os.exit()
  end

  local table_data = { 
    user_ip=user_ip, 
    user_mac=user_mac, 
    ap_mac=ap_mac, 
    portal_url=cst.PortalUrl
  }
  local data = json.stringify(table_data)
  
  if url_path == "test" then
    portal_proxy.print_data(data)
    return true
  end
  
  if url_path == "create" then
    local s = portal_proxy.status_user(user_ip,user_mac)
    if s == "User in localdb" then
      portal_proxy.serve_portal_to_preauthenticated_user(user_mac,user_ip)
    end
    portal_proxy.initialize_redirected_client(user_ip,user_mac)
    return true
  end

  local params = protocol.urldecode_params(query_string)
  local sid    = params["session_id"]
  local secret = params["secret"]
  if portal_proxy.validate(user_mac,user_ip,sid,secret) == true then
    portal_proxy.success()
    os.exit()
  end

  local status = portal_proxy.status_user(user_ip,user_mac)

  if status == "Authenticated" then
    portal_proxy.success()
    return true
  end

  -- REAUTH CODE BEGIN
  local connected = portal_proxy.has_user_been_connected(user_mac)
  if not connected then
    nixio.syslog("err","Request /reauth has failed")
    return false
  end
  if connected == false then
    nixio.syslog("err","Failed to get user status from db")
    return false
  end
  if connected["authenticated"] then
  -- If user has been pre authenticated on this AP but then has authenticated on another AP
    if status == "User in localdb" then
      local find = "/usr/bin/find /var/localdb/%s -name '*' -type d -mindepth 3"
      find = string.format(find,user_mac)
      local path = io.popen(find):read("*l")
      local remove = "/bin/rm -rf /var/localdb/" .. user_mac
      s = os.execute(remove)
      if s ~= 0 then
        nixio.syslog("err","Failed to remove /var/localdb/" .. mac)
        return false
      end 
    end
    local sid = connected["sessionid"]
    local secret = connected["secret"]
    local user_id = connected["user_id"]
    local date_auth = tonumber(connected["ap_validation"])
    portal_proxy.reauthenticate_user(user_ip,user_mac,sid,secret,date_auth,user_id)
    portal_proxy.success()
    return true
  end
  -- REAUTH CODE END
  
  if status == "User in localdb" then
    portal_proxy.serve_portal_to_preauthenticated_user(user_mac,user_ip)
  end
 
  local path_db = cst.localdb .. "/" .. user_mac
  local create_user = fs.mkdir(path_db)
  -- First request
  if create_user == true then
    uhttpd.send("Status: 302 Found\r\n")
    uhttpd.send("Location: http://cloudgate.citypassenger.com/create\r\n")
    uhttpd.send("Content-Type: text/html\r\n\r\n")
    return true
  end
  if create_user == nil then
    local errno = nixio.errno()
    local errmsg = nixio.strerror(errno)
    nixio.syslog("err",errno .. ": " .. errmsg)
  end
      
  if status == "Lease. Not in localdb" then
    while true do
      local i = "/usr/bin/inotifywait -t 1 -r -e create " .. cst.localdb .. "/" .. user_mac
      local t = os.execute(i)                                                     
      if t == 0 then break end                                                    
      break                                                                       
    end
  end
end

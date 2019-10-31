package.path       = package.path .. ";/portal/lib/?.lua"
package.path       = package.path .. ";/scripts/lib/?.lua"
local cst          = require "proxy_constants"
local portal_proxy = require "portal_proxy"
local protocol     = require "luci.http"
local json         = require "luci.jsonc"
local nixio        = require "nixio"
local support      = require "troubleshooting"
local fs           = require "nixio.fs"
local lease_file   = require "lease_file_reader"

function handle_request(env)
  local url_path = protocol.urldecode(string.sub(env.REQUEST_URI,2))
  local user_ip = env.REMOTE_ADDR
  local leases    = "/tmp/dhcp.leases"
  local f         = io.open(leases)
  local user_mac  = nil
  for line in f:lines() do
    if lease_file.get_ip(line) == user_ip then
      user_mac = lease_file.get_mac(line)
      break
    end
  end
  f:close()

  if not user_mac then
    portal_proxy.no_dhcp_lease()
    os.exit()
  end

  local re = "ws/wifi/public_wifi/auth.cgi%?session_id%=[0-9a-f]+%&secret=[0-9a-f]+%&type%=digilantoken"
  if url_path then
    nixio.syslog("info", "foo url_path " .. url_path)
  end
  if url_path == string.match(url_path,re) then
    local query_string = env.QUERY_STRING
    local params = protocol.urldecode_params(query_string)
    local sid    = params["session_id"]
    local secret = params["secret"]
    if portal_proxy.validate(user_mac,user_ip,sid,secret) == true then
      portal_proxy.success()
      os.exit()
    end    
  end

  if url_path == "ws/wifi/create" then
    local s = portal_proxy.status_user(user_ip,user_mac)
    if s == "User in localdb" then
      local portal_url = portal_proxy.serve_portal_to_preauthenticated_user(user_mac,user_ip)
      uhttpd.send('Status: 200 OK\r\n')
      uhttpd.send('Content-Type: text/html\r\n\r\n')
      uhttpd.send('{"url":"' .. portal_url .. '"}')
      return
    end
    local path_db = cst.localdb .. "/" .. user_mac
    local create_user = fs.mkdir(path_db)
    -- First request
    if create_user then
      local portal_url = portal_proxy.initialize_redirected_client(user_ip,user_mac)
      uhttpd.send('Status: 200 OK\r\n')
      uhttpd.send('Content-Type: text/html\r\n\r\n')
      uhttpd.send('{"url":"' .. portal_url .. '"}')
      return true
    else
      local errno = nixio.errno()
      local errmsg = nixio.strerror(errno)
      nixio.syslog("err","index.lua /create " .. errno .. ": " .. errmsg)
    end
  end
end

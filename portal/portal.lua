package.path = package.path .. ";/portal/lib/?.lua"
package.path = package.path .. ";/scripts/lib/?.lua"
local protocol = require "luci.http"
local portal_proxy = require "portal_proxy"
local cst = require "proxy_constants"
local nixio = require "nixio"
local lease_file = require "lease_file_reader"
local support = require "troubleshooting"

function handle_request(env)
  local url_path = protocol.urldecode(string.sub(env.REQUEST_URI,2))

  -- Return a troubleshooting page when AP has no internet.
  local a = os.execute("/usr/bin/test -e /tmp/internet")
  if a ~= 0 then
    if url_path == "support" then
      support.troubleshoot()
    elseif url_path == "autossh" then
      if support.get_autossh_status() then
        support.stop_autossh()
      else
        support.start_autossh()
      end
      uhttpd.send("Status: 302 Found\r\n")
      uhttpd.send("Location: http://cloudgate.citypassenger.com\r\n")
      uhttpd.send("Content-Type: text/html\r\n\r\n")
    else
      dofile("/portal/diagnostic.lua")
    end
    return true
  end

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

  if portal_proxy.status_user(user_ip,user_mac) == "Authenticated" then
    portal_proxy.success()
    return
  end
  
  local user_status = portal_proxy.status_user(user_ip,user_mac)
  if user_status ~= 'Authenticated' then
    -- REAUTH CODE BEGIN
    local connected = portal_proxy.has_user_been_connected(user_mac)
    if connected == nil then
      nixio.syslog("err","Request /reauth has failed")
      return false
    end
    if not connected then
      nixio.syslog("err","Failed to get user status from db")
      return false
    end
    if connected["authenticated"] then
      -- If user has been pre authenticated on this AP but then has authenticated on another AP
      if user_status == "User in localdb" then
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
  end
  -- REAUTH CODE END

  uhttpd.send("Status: 302 Found\r\n")
  local re = 'ws/wifi/public_wifi/auth.cgi%?session_id%=[0-9a-f]+%&secret=[0-9a-f]+%&type%=digilantoken'
  if url_path == string.match(url_path, re) then
    uhttpd.send("Location: http://cloudgate.citypassenger.com:8081/".. url_path .. "\r\n")
  else
    uhttpd.send("Location: http://cloudgate.citypassenger.com:8081\r\n")
  end
  uhttpd.send("Content-Type: text/html\r\n\r\n")
  os.exit()
end

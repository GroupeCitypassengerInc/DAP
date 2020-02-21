local helper = require 'helper'
local json = require 'luci.jsonc'
local cst = require 'proxy_constants'
local date_module = require 'luci.http.protocol.date'
local sys = require 'luci.sys'
local util = require 'luci.util'
local nixio = require 'nixio'
local data = require 'LIP'
local uci = require 'luci.model.uci'
local fs = require 'nixio.fs'

support = {}

function support.date()
  return os.date("%a, %d %b %Y %H:%M:%S CET")
end

function support.version_conf()
  local f = io.open('/etc/version.conf','r')
  if not f then
    return 'No version on this access point'
  end
  local version = f:read('*l')
  f:close()
  return version
end

function top()
  cmd = '/usr/bin/top -n1 -b'
  return io.popen(cmd):read('*a')
end

function route()
  cmd = '/sbin/route -n'
  return io.popen(cmd):read('*a')
end

function swconfig_switch0_port2()
  cmd = '/sbin/swconfig dev switch0 port 5 show | /usr/bin/tail -n1'
  local res = io.popen(cmd):read('*l')
  return util.trim(res)
end

function ifconfig()
  cmd = '/sbin/ifconfig -a'
  return io.popen(cmd):read('*a')
end

function get_file_date(file_path)
  cmd = '/bin/date -r %s'
  cmd = string.format(cmd, file_path)
  s = io.popen(cmd):read('*l')
  if not s then
    return 'Could not read file '..file_path
  end
  return s
end

function support.curl_google()
  local cmd = '/usr/bin/curl '
            ..'--retry 1 --retry-delay 2 '
            ..'-w %{http_code} '
            ..'-m3 '
            ..'--fail '
            ..'-o /tmp/curl_google '
            ..'"https://www.google.com" 2>/tmp/curl_google_stderr'
  http_code, exit = helper.command(cmd)
  local res = {http_code=http_code, exit=exit}
  return res
end

function support.curl_cityscope()
  local f = io.open('/etc/cityscope.conf','r')
  local cityscope = f:read('*l')
  f:close()
  local cityscope = cityscope .. '/version'
  local cmd = '/usr/bin/curl '
            ..'--retry 1 --retry-delay 2 '
            ..'-w %%{http_code} '
            ..'-m3 '
            ..'--fail '
            ..'-o /tmp/curl_cityscope '
            ..'"%s" 2>/tmp/curl_cityscope_stderr'
  local cmd = string.format(cmd,cityscope)
  http_code, exit = helper.command(cmd)
  local res = {http_code=http_code, exit=exit}
  return res
end

function support.has_network()
  -- fix me
  local cmd = '/bin/echo | /usr/bin/nc -w2 www.google.com 443'
  local res = os.execute(cmd)
  return res == 0
end

function support.netcat_cityscope()
  local f = io.open('/etc/cityscope.conf','r')
  local cityscope = f:read('*l')
  f:close()
  local cityscope = cityscope:match('^%w+://([^:/]+)')
  local cmd = '/bin/echo | /usr/bin/nc -w2 %s 443'
  local cmd = string.format(cmd,cityscope)
  return os.execute(cmd) == 0
end

function get_dhcp_leases()
  cmd = '/bin/cat /tmp/dhcp.leases'
  return io.popen(cmd):read('*a')
end

function traceroute()
  cmd = '/bin/traceroute -4 8.8.8.8'
  p = io.popen(cmd)
  res = p:read('*a')
  p:close()
  return res
end

function get_autossh_options()
  local cursor = uci.cursor()
  local opts = cursor:get('autossh','@autossh[0]','ssh')
  local opt = opts[1]
  return opt
end

function support.get_autossh_status()
  local pgrep = '/usr/bin/pgrep -f "%s" > /dev/null'
  local opt = get_autossh_options()
  local ssh_base = '/usr/bin/ssh '
  local ssh_full = ssh_base .. opt
  pgrep = string.format(pgrep,ssh_full)
  local x = os.execute(pgrep)
  return x == 0
end

function support.start_autossh()
  os.execute('/etc/init.d/autossh restart')
  nixio.syslog('info','Autossh service has been started')
end

function support.stop_autossh()
  os.execute('/etc/init.d/autossh stop') 
  nixio.syslog('info','Autossh service has been stopped')
end

function support.is_port2_plugged()
  local link_info = swconfig_switch0_port2()
  local re = "link%: port%:%d+ link%:up speed%:%d+baseT full%-duplex txflow rxflow auto"
  local res = link_info:match(re)
  if not res then
    return false
  else
    return true
  end
end

function support.get_ip_gateway()
  local cmd = '/bin/ubus call network.interface.wan status'
  for i=1,3 do
    rc = io.popen(cmd):read('*a')
    if rc then
      break
    end
    nixio.nanosleep(3)
  end
  if not rc then
    nixio.syslog('err','Failed to call ubus')
    return
  end
  local ubus_res = json.parse(rc)
  return ubus_res.route[1].nexthop
end

function print_lease_json()
  local cmd = '/bin/ubus call network.interface.wan status'
  for i=1,3 do
    rc = io.popen(cmd):read('*a')
    if rc then
      break
    end
    nixio.nanosleep(3)
  end
  if not rc then
    nixio.syslog('err','Failed to call ubus')
    return
  end
  return rc
end

function support.has_lease()
  local cmd = '/bin/ubus call network.interface.wan status'
  for i=1,3 do
    rc = io.popen(cmd):read('*a')
    if rc then
      break
    end
    nixio.nanosleep(3)
  end
  if not rc then
    nixio.syslog('err','Failed to call ubus')
    return
  end
  local ubus_res = json.parse(rc)
  local lease_date = ubus_res.data.date
  if not lease_date then
    return false
  end
  local cmd = '/bin/date +%s'
  local date_now = os.date("%a, %d %b %Y %H:%M:%S GMT")
  date_now = date_module.to_unix(date_now)
  local lease_time = ubus_res.data.leasetime
  return date_now - lease_date <= lease_time
end

function support.has_access_to_portal()
  if not cst.PortalUrl then
    return false
  end
  local cmd = '/usr/bin/curl '
            ..'--retry 1 --retry-delay 2 '
            ..'-w %%{http_code} '
            ..'-G '
            ..'--data-urlencode "digilan-token-action=version" '
            ..'-m8 '
            ..'--fail '
            ..'-o /tmp/curl_portal_version '
            ..'"%s" 2>/tmp/curl_check_portal_stderr'
  local cmd = string.format(cmd,cst.PortalUrl)
  response,exit = helper.command(cmd)
  if exit ~= 0 then
    fs.mkdir('/tmp/exit_'..exit..'_'..os.date("%a, %d_%b_%Y-%H_%M_%S"))
    return false
  end
  if response ~= '200' then
    fs.mkdir('/tmp/resp_'..exit..'_'..os.date("%a, %d_%b_%Y-%H_%M_%S"))
    return false
  end
  return true
end

function netcat_portal()
  if not cst.PortalUrl then
    return false
  end
  local host = cst.PortalUrl:match('^%w+://([^:/]+)')
  local port = cst.PortalUrl:match('%d+$')
  local cmd = '/bin/echo | /usr/bin/nc -w2 %s %d'
  if not port then
    check_connectivity = string.format(cmd,host,443)
  else
    check_connectivity = string.format(cmd,host,port)
  end
  local res = os.execute(check_connectivity)
  return res == 0
end

function get_public_ip()
  local f = io.open('/tmp/public.ip','r')
  if not f then
    return 'No public ip'
  end
  local public_ip = f:read('*l')
  f:close()
  if not public_ip then
    public_ip = 'Could not get public ip'
  end
  return public_ip
end

function read_file(curl_file)
  local f = io.open(curl_file,'r')
  if not f then
    return 'Could not read file '..curl_file
  end
  local s = f:read('*a')
  f:close()
  return s
end

function curl_admin_citypassenger()
  local f = io.open('/etc/cityscope.conf')
  local url = f:read('*l')
  f:close()
  local mac = cst.ap_mac
  local api = url .. '/' .. mac
  local f = io.open('/root/.ssh/apikey')
  local key = f:read('*l')
  f:close()
  local curl = '/usr/bin/curl --fail -m3 -H "CityscopeApiKey: '..key..'" "'..api..'"'
  local r = io.popen(curl):read('*a')
  local res = json.parse(r)
  if not res then
    return 'Could not get configuration from cityscope'
  end
  local portal = res['url']
  if not portal then
    return 'This AP is not linked to any portal'
  else 
    return portal
  end
end

function logread()
  local f = io.popen('/sbin/logread')
  local log = f:read('*a')
  f:close()
  return log
end

function get_version()
  local f = io.open('/etc/solo.version','r')
  local version = f:read('*l')
  f:close()
  return version
end

function resolve_portal()
  if not cst.PortalUrl then
    return 'No portal in conf'
  end
  local host = cst.PortalUrl:match('^%w+://([^:/]+)')
  local dns_result = nixio.getaddrinfo(host,'inet')
  if not dns_result then
    return 'Could not resolve portal'
  end
  local portal_ip = dns_result[1].address
  return portal_ip
end

function support.ping(host)
  if not host then
    nixio.syslog('err','No host in ping')
    return false 
  end
  local cmd = '/bin/ping -w 3 %s'
  local cmd = string.format(cmd,host)
  local s = io.popen(cmd):read('*a')
  return s  
end

function support.troubleshoot()
  uhttpd.send('Status: 200 OK\r\n')
  uhttpd.send('Content-Type: text/plain\r\n\r\n')
  uhttpd.send('======= DATE ======\r\n')
  uhttpd.send(support.date())
  uhttpd.send('\r\n')
  uhttpd.send('======= PUBLIC IP ======\r\n')
  uhttpd.send('Date public ip: ' .. get_file_date('/tmp/public.ip'))
  uhttpd.send('\r\n')
  uhttpd.send('Public ip: ' .. get_public_ip())
  uhttpd.send('\r\n')
  uhttpd.send('======= HOSTNAME ======\r\n')
  uhttpd.send(sys.hostname())
  uhttpd.send('\r\n')
  uhttpd.send('======= VERSION ======\r\n')
  uhttpd.send(get_version())
  uhttpd.send('\r\n')
  uhttpd.send('======= ACCESS PORTAL ======\r\n')
  if not cst.PortalUrl then
    uhttpd.send('Can\'t netcat to portal, no portal in conf file')
  else
    uhttpd.send('Portal ip: ' .. resolve_portal())
    uhttpd.send('\r\n')
    uhttpd.send('Netcat to '
               .. cst.PortalUrl:match('^%w+://([^:/]+)') 
               .. ': ' 
               .. tostring(netcat_portal()))
  end
  uhttpd.send('\r\n')
  uhttpd.send('======= CONFIGURATION CITYSCOPE ======\r\n')
  uhttpd.send('Portal URL from cityscope: '..curl_admin_citypassenger())
  uhttpd.send('\r\n')
  uhttpd.send('======= CONFIGURATION WORDPRESS ======\r\n')
  uhttpd.send('Add access point to wordpress stderr:')
  uhttpd.send('\r\n')
  uhttpd.send(read_file('/tmp/add_config_err'))
  uhttpd.send('\r\n')
  uhttpd.send('Get configuration from wordpress stderr:')
  uhttpd.send('\r\n')
  uhttpd.send(read_file('/tmp/get_config_err'))
  uhttpd.send('\r\n')
  uhttpd.send('Date of last correct configuration in /tmp/config_wordpress:\r\n')
  uhttpd.send(get_file_date('/tmp/config_wordpress'))
  uhttpd.send('\r\n')
  uhttpd.send('Configuration from wordpress:\r\n')
  uhttpd.send(read_file('/tmp/config_wordpress'))
  uhttpd.send('\r\n')
  uhttpd.send('======= INTERFACES =======\r\n')
  uhttpd.send(ifconfig())
  uhttpd.send('\r\n')
  uhttpd.send('======= PORT 2 =======\r\n')
  uhttpd.send(swconfig_switch0_port2())
  uhttpd.send('\r\n')
  uhttpd.send('======= ROUTE =======\r\n')
  uhttpd.send(route())
  uhttpd.send('\r\n')
  if support.has_network() then
    uhttpd.send('======= AUTOSSH =======\r\n')
    uhttpd.send('Options :'.. get_autossh_options())
    uhttpd.send('\r\n')
  end
  uhttpd.send('======= DHCP LEASES ======\r\n')
  uhttpd.send(get_dhcp_leases())
  uhttpd.send('\r\n')
  uhttpd.send('======= ACCESS POINT DHCP LEASE ======\r\n')
  uhttpd.send(print_lease_json())
  uhttpd.send('\r\n')
  uhttpd.send('======= LOGREAD =======\r\n')
  uhttpd.send(logread())
  uhttpd.send('\r\n')
  uhttpd.send('======= PROCESSES LIST =======\r\n')
  uhttpd.send(top())
  uhttpd.send('\r\n')
  uhttpd.send('======= TRACEROUTE ======\r\n')
  uhttpd.send(traceroute())
  uhttpd.send('\r\n')
end

return support

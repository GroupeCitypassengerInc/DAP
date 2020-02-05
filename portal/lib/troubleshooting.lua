local helper = require 'helper'
local json = require 'luci.jsonc'
local cst = require 'proxy_constants'
local date_module = require 'luci.http.protocol.date'
local sys = require 'luci.sys'
local util = require 'luci.util'
local nixio = require 'nixio'
local data = require 'LIP'

support = {}

function support.date()
  return os.date("%a, %d %b %Y %H:%M:%S CET")
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

function support.get_autossh_status()
  local pgrep = '/usr/bin/pgrep autossh > /dev/null'
  local x = os.execute(pgrep)
  return x == 0
end

function support.start_autossh()
  os.execute('/etc/init.d/autossh start')
  nixio.syslog('info','Autossh service has been started')
end

function support.stop_autossh()
  os.execute('/etc/init.d/autossh stop') 
  nixio.syslog('info','Autossh service has been stopped')
end

function support.is_port2_plugged()
  local link_info = swconfig_switch0_port2()
  local link_up = "link: port:5 link:up speed:100baseT full-duplex txflow rxflow auto"
  return link_info == link_up
end

function support.has_lease()
  local cmd = '/bin/ubus call network.interface.wan status'
  local rc = io.popen(cmd):read('*a')
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
  local conf = data.load('/etc/proxy.ini')
  local g = io.open(conf['ap']['mac_addr'])
  local mac = g:read('*l')
  g:close()
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
  local f = io.open('/tmp/dns_portal','r')
  portal_ip = f:read('*l')
  f:close()
  if not portal_ip then
    return 'Could not resolve portal'
  else
    return portal_ip
  end
end

function support.troubleshoot()
  uhttpd.send('Status: 200 OK\r\n')
  uhttpd.send('Content-Type: text/text\r\n\r\n')
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
               .. tostring(support.has_access_to_portal()))
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
  uhttpd.send('======= DHCP LEASES ======\r\n')
  uhttpd.send(get_dhcp_leases())
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

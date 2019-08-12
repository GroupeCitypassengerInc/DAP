local helper = require 'helper'
local json = require 'luci.jsonc'
local cst = require 'proxy_constants'
local date_module = require 'luci.http.protocol.date'

support = {}

function support.date()
  return os.date("%a, %d %b %Y %H:%M:%S GMT")
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
  cmd = '/sbin/swconfig dev switch0 port 2 show | /usr/bin/tail -n1 | /usr/bin/tr -d "\t"'
  return io.popen(cmd):read('*l')
end

function port(iface)
  cmd = '/bin/cat /proc/' .. iface
  return io.popen(cmd):read('*a')
end

function ifconfig()
  cmd = '/sbin/ifconfig -a'
  return io.popen(cmd):read('*a')
end

function get_dhcp_leases()
  cmd = '/bin/cat /tmp/dhcp.leases'
  return io.popen(cmd):read('*a')
end

function dig()
  cmd = '/usr/bin/dig hosts @8.8.8.8'
  return io.popen(cmd):read('*a')
end

function traceroute()
  cmd = '/usr/bin/traceroute -4 8.8.8.8'
  return io.popen(cmd):read('*a')
end

function support.is_port2_plugged()
  local link_info = swconfig_switch0_port2()
  local link_up = "link: port:2 link:up speed:100baseT full-duplex txflow rxflow auto"
  return link_info == link_up
end

function support.has_lease()
  local cmd = '/bin/ubus call network.interface.cfg036d96 status'
  local r = io.popen(cmd):read('*a')
  local net_info = json.parse(r)
  local lease_date = net_info.data.date
  if not lease_date then
    return false
  end
  local cmd = '/bin/date +%s'
  local date_now = os.date("%a, %d %b %Y %H:%M:%S GMT")
  date_now = date_module.to_unix(date_now)
  local lease_time = net_info.data.leasetime
  return date_now - lease_date <= lease_time
end

function support.has_access_to_portal()
  if not cst.PortalUrl then
    return false
  end
  local host = cst.PortalUrl:match('^%w+://([^/]+)')
  local cmd = '/usr/bin/nc -w2 -zv %s 443 2> /dev/null'
  check_connectivity = string.format(cmd,host)
  local res = os.execute(check_connectivity)
  return res == 0
end

function support.troubleshoot()
  uhttpd.send('Status: 200 OK\r\n')
  uhttpd.send('Content-Type: text/text\r\n\r\n')
  uhttpd.send('======= DATE ======\r\n')
  uhttpd.send(date())
  uhttpd.send('\r\n')
  uhttpd.send('======= HOSTNAME ======\r\n')
  uhttpd.send(helper.get_hostname())
  uhttpd.send('\r\n')
  uhttpd.send('======= INTERFACES =======\r\n')
  uhttpd.send(ifconfig())
  uhttpd.send('\r\n')
  uhttpd.send('======= PORT 2 =======\r\n')
  uhttpd.send(swconfig_switch0_port2())
  uhttpd.send('\r\n')
  uhttpd.send('======= PORTS =======\r\n')
  uhttpd.send('INTERFACE eth0.10 (POE)\r\n')
  uhttpd.send(port('eth0.10'))
  uhttpd.send('INTERFACE eth0.1 \r\n')
  uhttpd.send(port('eth0.1'))
  uhttpd.send('\r\n') 
  uhttpd.send('======= ROUTE =======\r\n')
  uhttpd.send(route())
  uhttpd.send('\r\n')
  uhttpd.send('======= DHCP LEASES ======\r\n')
  uhttpd.send(get_dhcp_leases())
  uhttpd.send('\r\n')
  uhttpd.send('======= PROCESSES LIST =======\r\n')
  uhttpd.send(top())
  uhttpd.send('\r\n')
  uhttpd.send('======= DIG ======\r\n')
  uhttpd.send(dig())
  uhttpd.send('\r\n')
  uhttpd.send('======= TRACEROUTE ======\r\n')
  uhttpd.send(traceroute())
end

return support

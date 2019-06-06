
support = {}

function date()
  cmd = '/bin/date'
  return io.popen(cmd):read('*a')
end

function top()
  cmd = '/usr/bin/top -n1 -b'
  return io.popen(cmd):read('*a')
end

function route()
  cmd = '/sbin/route -n'
  return io.popen(cmd):read('*a')
end

function is_port2_plugged()
  cmd = '/sbin/swconfig dev switch0 port 2 show | /usr/bin/tail -n1'
  return io.popen(cmd):read('*a')
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

function support.troubleshoot()
  uhttpd.send('Status: 200 OK\r\n')
  uhttpd.send('Content-Type: text/text\r\n\r\n')
  uhttpd.send('======= DATE ======\r\n')
  uhttpd.send(date())
  uhttpd.send('\r\n')
  uhttpd.send('======= INTERFACES =======\r\n')
  uhttpd.send(ifconfig())
  uhttpd.send('\r\n')
  uhttpd.send('======= PORT 2 =======\r\n')
  uhttpd.send(is_port2_plugged())
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

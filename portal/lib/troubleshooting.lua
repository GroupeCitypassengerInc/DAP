
support = {}

function top()
  cmd = '/usr/bin/top -n1 -b'
  return io.popen(cmd):read('*a')
end

function route()
  cmd = '/sbin/route -n'
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
  uhttpd.send('======= INTERFACES =======\r\n')
  uhttpd.send(ifconfig())
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

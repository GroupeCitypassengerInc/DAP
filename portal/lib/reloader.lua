local nixio = require 'nixio'

local r = {}

function r.dnsmasq()
  local cmd = '/bin/cat /tmp/dnsmasq.pid'
  local pid = io.popen(cmd):read('*l')
  local cmd = '/bin/kill ' .. pid
  s = os.execute(cmd)
  if s ~= 0 then
    nixio.syslog('err','Could not kill process ' .. pid.. '. Exit code: '
    .. s)
    return false
  end
  local DNSMASQ = '/usr/sbin/dnsmasq --conf-file='
  local dnsmasq = DNSMASQ .. '/etc/dnsmasq-dhcp.conf --guard-ip=192.168.1.1'
  local x = os.execute(dnsmasq)
  if x ~= 0 then
    nixio.syslog('err','Could not start ' .. dnsmasq  .. '. Exit code: '
    .. x)
  end
end

function r.uhttpd()
  local cmd = '/etc/init.d/uhttpd restart'
  os.execute(cmd)
end

function r.hostapd(path)
  local p = string.gsub(path,'etc','tmp')
  local pid_path = string.gsub(p,'conf','pid')
  local pid = io.popen('/bin/cat ' .. pid_path):read('*l')
  local kill = '/bin/kill ' .. pid
  local k = os.execute(kill)
  if k ~= 0 then
    nixio.syslog('err','Could not kill hostapd ' .. pid .. '. Exit code: '
    .. k)
  end
  local cmd = '/usr/sbin/hostapd -B -P %s %s'
  local cmd = string.format(cmd,pid_path,path)
  local h = os.execute(cmd)
  if h ~= 0 then
    nixio.syslog('err',cmd .. ' failed. Exit code: '
    .. h)
  end

  local cmd = '/sbin/ifconfig bridge1 up'
  local s = os.execute(cmd)
  if s ~= 0 then
    nixio.syslog('err', cmd .. ' failed. Exit code: '
    .. s)
  end
  local cmd = '/sbin/ifconfig bridge1 192.168.1.1'
  local s = os.execute(cmd)
  if s ~= 0 then
    nixio.syslog('err', cmd .. ' failed. Exit code: '
    .. s)
  end
  local cmd = '/sbin/ifconfig bridge2 up'
  local s = os.execute(cmd)
  if s ~= 0 then
    nixio.syslog('err', cmd .. ' failed. Exit code: '
    .. s)
  end
  local cmd = '/sbin/ifconfig bridge2 192.168.1.100'
  local s = os.execute(cmd)
  if s ~= 0 then
    nixio.syslog('err', cmd .. ' failed. Exit code: '
    .. s)
  end
end

return r

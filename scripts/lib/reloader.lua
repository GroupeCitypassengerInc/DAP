local nixio = require 'nixio'

local r = {}

function r.dnsmasq()
  local cmd = '/bin/cat /tmp/dnsmasq.pid'
  local pid = io.popen(cmd):read('*l')
  if pid ~= nil then
    local cmd = '/bin/kill ' .. pid
    s = os.execute(cmd)
    if s ~= 0 then
      nixio.syslog('err','Could not kill process ' .. pid.. '. Exit code: '
      .. s)
    end
  end
  local DNSMASQ = '/usr/sbin/dnsmasq --conf-file='
  local dnsmasq = DNSMASQ .. '/etc/dnsmasq-dhcp.conf --guard-ip=10.168.168.1'
  local x = os.execute(dnsmasq)
  if x ~= 0 then
    nixio.syslog('err','Could not start ' .. dnsmasq  .. '. Exit code: '
    .. x)
  end
end

function r.dnsmasq_portal()
  local cmd = '/usr/sbin/dnsmasq --conf-file=/etc/dnsmasq.portal&'
  local x = os.execute(cmd)
  if x ~= 0 then
    nixio.syslog('err','Could not start ' .. cmd  .. '. Exit code: '
    .. x)
  end
end

function r.logger()
  local cmd = '/usr/bin/lua /scripts/logger.lua&'
  local x = os.execute(cmd)
  if x ~= 0 then                                                                                                                                         
    nixio.syslog('err','Could not start ' .. cmd  .. '. Exit code: '                                                                                     
    .. x)                                                                                                                                                
  end  
end

function r.uhttpd()
  local cmd = '/etc/init.d/uhttpd restart'
  os.execute(cmd)
end

function r.bridge()
  local cmd = '/sbin/ifconfig bridge1 up'
  local s = os.execute(cmd)
  if s ~= 0 then
    nixio.syslog('err', cmd .. ' failed. Exit code: '
    .. s)
  end
  local cmd = '/sbin/ifconfig bridge1 10.168.168.1'
  local s = os.execute(cmd)
  if s ~= 0 then
    nixio.syslog('err', cmd .. ' failed. Exit code: '
    .. s)
  end
  local cmd = '/sbin/ifconfig bridge1 netmask 255.255.255.0'
  local s = os.execute(cmd)
  if s ~= 0 then
    nixio.syslog('err', cmd .. ' failed. Exit code: '
    .. s)
  end
end

function r.hostapd(path)
  local p = string.gsub(path,'etc','tmp')
  local pid_path = string.gsub(p,'conf','pid')
  local cmd = '/usr/sbin/hostapd -B -P %s %s'
  local cmd = string.format(cmd,pid_path,path)
  if path == '/etc/hostapd.0.conf' then
    wlanif = 'wlan0'
  elseif path == '/etc/hostapd.1.conf' then
    wlanif = 'wlan1'
  elseif path == '/etc/hostapd.support.conf' then
    wlanif = 'wlan1'
  else
    nixio.syslog('err','No wlan iface')
    return false
  end
  while true do
    local h = os.execute(cmd)
    if h == 0 then
      rc = '/usr/sbin/brctl addif bridge1 ' .. wlanif
      os.execute(rc)
      break
    else
      pid = io.popen('/bin/cat ' .. pid_path):read('*l')
      if pid ~= nil then
        rc = '/bin/kill ' .. pid
      end
      os.execute(rc)
      nixio.syslog('err',cmd .. ' failed. Exit code: '
      .. h)
      os.execute('/bin/sleep 10')
    end
  end
end

return r

local nixio = require 'nixio'

local r = {}

function r.dnsmasq()
  local cmd = '/bin/cat /tmp/dnsmasq.pid'
  local pid = io.popen(cmd):read('*l')
  if pid ~= nil then
    pid = tonumber(pid)
    local killed = nixio.kill(pid,15)
    if not killed then
      nixio.syslog('err','Could not kill process ' .. pid)
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

function get_wlanif(path)
  if path == '/etc/hostapd.0.conf' then
    return 'wlan0'
  elseif path == '/etc/hostapd.1.conf' then
    return 'wlan1'
  elseif path == '/etc/hostapd.support.conf' then
    return 'wlan1'
  else
    nixio.syslog('err','No wlan iface')
    return false
  end
end

function r.retry_hostapd(path)
  local wlanif = get_wlanif(path)
  if wlanif == false then
    return false
  end
  while true do
    s = start_hostapd(path)
    if s == true then
      if is_wlan_up(wlanif) then
        nixio.nanosleep(2)
        addif_br(wlanif)
        break
      end
    else
      kill_hostapd(path)
      nixio.nanosleep(10)
    end    
  end
end

function is_wlan_up(wlanif)
  local cmd = '/sbin/ip a | /bin/grep "state UP" | /bin/grep ' .. wlanif
  local res = os.execute(cmd)
  return res == 0
end

function kill_hostapd(path)
  local p = string.gsub(path,'etc','tmp')
  local pid_path = string.gsub(p,'conf','pid')
  pid = io.popen('/bin/cat ' .. pid_path):read('*l')
  if pid ~= nil then
    pid = tonumber(pid)
    nixio.kill(pid,15)
  end
end

function addif_br(wlanif)
  rc = '/usr/sbin/brctl addif bridge1 ' .. wlanif
  os.execute(rc)
end

function start_hostapd(path)
  local p = string.gsub(path,'etc','tmp')
  local pid_path = string.gsub(p,'conf','pid')
  local cmd = '/usr/sbin/hostapd -B -P %s %s'
  local cmd = string.format(cmd,pid_path,path)
  local h = os.execute(cmd)
  return h == 0
end

return r

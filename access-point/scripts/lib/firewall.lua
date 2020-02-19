local nixio = require 'nixio'
local fw = {}
local helper = require 'lease_file_reader'

function fw.host_in_firewall_whitelist(host)
  local file = '/etc/firewall-white-full.conf'
  local f = io.open(file,'r')
  for line in f:lines() do
    if host == line then
      return true
    end
  end
  f:close()
  return false
end

function fw.is_reply_or_cached(line)
  if string.match(line,'reply') then
    return true
  end
  if string.match(line,'cached') then
    return true
  end
  return false
end

function fw.update_firewall_rule(current_rule,host,ip,timestamp)
  local now = io.popen('/bin/date +%s'):read('*l')
  if now - timestamp > 900 then
    current_rule = string.gsub(current_rule,'A','D',1)
    current_rule = '/usr/sbin/iptables -t nat ' .. current_rule
    print(current_rule)
    local rc = os.execute(current_rule)
    if rc ~= 0 then
      nixio.syslog('err','failed to remove rule '..old_rule)
    end
    fw.add_firewall_rule(host,ip)
  end
end

function fw.add_firewall_rule(host,ip)
  local now = io.popen('/bin/date +%s'):read('*l')
  local cmd = '/usr/sbin/iptables -t nat -I PREROUTING -d %s/32 -i bridge1 -p tcp -m comment --comment "%s %s" -m tcp --dport 443 -j ACCEPT'
  local cmd = string.format(cmd,ip,host,now)
  local rc = os.execute(cmd)
  if rc ~= 0 then
    nixio.syslog('err','Failed to add rule '..cmd)
    return
  end
  nixio.syslog('debug','Authorized '..host..' and ip '..ip)
end

function fw.update_firewall(host,ip)
  local ruleset = io.popen('iptables-save | /bin/grep "A PREROUTING"')
  local lines = ruleset:lines()
  exists = false
  for line in lines do
    nixio.syslog('debug','updating for '..host..' and ip '..ip)
    -- rule exists for host check ip
    if line:match(ip) then
      exists = true
      -- if ip in rules check timestamp
      local args = helper.split_line(line,'[%w.-]+')
      timestamp = args[14]
      fw.update_firewall_rule(line,host,ip,timestamp)
      return
    else
      nixio.syslog('debug','ip '..ip.. ' is not in iptables adding new')
    end
  end
  if not exists then
    fw.add_firewall_rule(host,ip)
  end
end

function fw.is_host_in_conf()
  local cmd = '/bin/grep -w %s /etc/firewall-white.conf'
  local rc = os.execute(cmd)
  return rc == 0
end

return fw

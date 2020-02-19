local firewall_base = '/etc/firewall-white.conf'
local firewall_full = '/etc/firewall-white-full.conf'

f = io.open(firewall_base,'r')
g = io.open(firewall_full,'w')
for line in f:lines() do
  local n = io.popen('nslookup '..line)
  for h in n:lines() do
    if h:match('Name%:') then
      host = h:match('[%w+.-]+$')
      g:write(host..'\n')
    end
  end
end
f:close()
g:close()


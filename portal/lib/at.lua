local cst = require 'proxy_constants'

local at = {}

function at.create_at_job(ip)
  local timeout = cst.at_timeout
  if not tonumber(timeout) then
    nixio.syslog('err', 'Invalid at timeout')
    return false
  end
  local at = '/bin/echo lua /scripts/end-user-session.lua %s | '
           ..'/usr/bin/at -q w now + %s minutes 2>&1 | '
           ..'/usr/bin/tail -1 | '
           ..' /usr/bin/cut -f2 -d" "'
  local at = string.format(at, ip, timeout)
  local id = io.popen(at):read('*l')
  if id == nil then
    nixio.syslog('err', 'Failed to create job for user ' .. ip)
    return false
  end
  return id
end

function at.delete_at_job(id)
  local atrm = '/usr/bin/at -d %s'
  local atrm = string.format(atrm, id)
  local res = os.execute(atrm)
  if res ~= 0 then
    local msg = 'Failed to remove job %s'
    local msg = string.format(msg, id)
    nixio.syslog('err', msg)
  end
end

return at

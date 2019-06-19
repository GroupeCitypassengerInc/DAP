
local helper={}

function helper.command(cmd)
  local f = io.popen(cmd..' ; echo "-retcode:$?"' ,'r')
  local l = f:read('*a')
  f:close()
  local i1,i2,ret = l:find('%-retcode:(%d+)\n$')
  l = l:sub(1,i1 - 1)
  return l,tonumber(ret)
end

return helper

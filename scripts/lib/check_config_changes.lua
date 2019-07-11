
res = {}

local ini_file = '/etc/proxy.ini' 

function res.update_config(old,new,data,section,opt)
  if old ~= new then
    data[section][opt] = new
    parser.save(ini_file,data)
    nixio.syslog('info',opt..' updated')
    return true
  else
    nixio.syslog('info',opt..' is up to date')
    return false
  end
end

return res

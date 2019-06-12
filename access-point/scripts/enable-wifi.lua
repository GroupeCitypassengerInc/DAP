--[[
--
--  Script to re enable access to wifi during active time interval
--  Called by cron
--
--]]
fs = require 'nixio.fs'

local cmd = '/usr/bin/test -e /tmp/noaccess'
local f = os.execute(cmd)
if f == 0 then
  fs.remove('/tmp/noaccess')
end

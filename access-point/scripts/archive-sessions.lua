package.path = package.path .. ';/portal/lib/?.lua'
local cst = require 'proxy_constants'
local helper = require 'helper'

local cmd = '/usr/bin/curl --retry 3 --retry-delay 5 --fail -m 10 --connect-timeout 10 '
          ..'-G '
          ..'--data-urlencode "digilan-token-action=archive" '
          ..'--data-urlencode "digilan-token-secret=%s" '
          ..'"%s"'
local cmd = string.format(cmd, cst.ap_secret, cst.PortalUrl..'/index.php')
local res,exit = helper.command(cmd)
if exit ~= 0 then
  nixio.syslog('err',cmd .. ' failed with exit code : ' .. exit)
end

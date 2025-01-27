--[[
--
-- File loading constants from configuration file
--
--]]
parser    = require 'LIP'
constants = {}

ini_conf_path  = '/etc/proxy.ini'
ini_conf_data  = parser.load(ini_conf_path)

function constants.__init__()
  constants.PortalUrl  = ini_conf_data.portal.url
  local path_mac_addr  = ini_conf_data.ap.mac_addr
  local f              = io.open(path_mac_addr,'r')
  constants.ap_mac     = f:read('*l')
  f:close()
  constants.ap_timeout = tonumber(ini_conf_data.ap.timeout)
  constants.localdb    = ini_conf_data.localdb.path
  constants.tmpdb      = ini_conf_data.localdb.tmp
  constants.ap_secret  = ini_conf_data.ap.secret
  constants.landing_page = ini_conf_data.portal.landing_page
  if ini_conf_data.portal.portal_page ~= nil then
    constants.PortalPage = ini_conf_data.portal.portal_page
  else
    constants.PortalPage = constants.PortalUrl
  end
  constants.error_page = ini_conf_data.portal.error_page
  constants.rule_refresh_time  = ini_conf_data.ap.refresh_rule_time
  constants.rule_expiry_time  = ini_conf_data.ap.rule_expiry_time
  constants.firewall_whitelist  = ini_conf_data.ap.firewall_whitelist
  constants.firewall_whitelist_full  = ini_conf_data.ap.firewall_whitelist_full
end

constants.__init__()

return constants

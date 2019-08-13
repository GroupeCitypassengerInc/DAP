package.path = package.path .. ';/portal/lib/?.lua'
local troubleshooting = require 'troubleshooting'
local sys = require 'luci.sys'

uhttpd.send("Status: 200 OK\r\n")
uhttpd.send("Content-Type: text/html\r\n\r\n")
uhttpd.send("<!DOCTYPE html>\r\n")
uhttpd.send("<html>\r\n")
uhttpd.send("<body>\r\n")
uhttpd.send("<h1>Solo support</h1>\r\n")
uhttpd.send("<p>Date: " .. troubleshooting.date() .. "</p>\r\n")
uhttpd.send("<p>Hostname: " .. sys.hostname() .. "</p>\r\n")
uhttpd.send("<h2>Diagnostic</h2>\r\n")
local plugged = troubleshooting.is_port2_plugged()
if not plugged then
  uhttpd.send("<div>\r\n")
  uhttpd.send("Your access point is not plugged correctly, so it does not have access to internet. Please check your connections\r\n")
  uhttpd.send("</div>\r\n")
else
  local leased = troubleshooting.has_lease()
  if not leased then
    uhttpd.send("<div>\r\n")
    uhttpd.send("Your access point did not get a DHCP lease. Please check your DHCP server.\r\n")
    uhttpd.send("</div>\r\n")
  else
    local has_portal = troubleshooting.has_access_to_portal()
    if not has_portal then
      uhttpd.send("<div>\r\n")
      uhttpd.send("Your access point can't reach the captive portal. Check your internet connection\r\n")
      uhttpd.send("</div>\r\n")
    else
      uhttpd.send("<div>\r\n")
      uhttpd.send("Everything seems fine.\r\n")
      uhttpd.send("</div>\r\n")
    end
  end
end

uhttpd.send("<p>\r\n")
uhttpd.send("<a href='http://cloudgate.citypassenger.com/support'>More information</a>\r\n")
uhttpd.send("</p>\r\n")
uhttpd.send("<p>\r\n")
uhttpd.send("Go to <a href='http://172.16.3.2'>LUCI</a>\r\n")
uhttpd.send("</p>\r\n")
uhttpd.send("</body>\r\n")
uhttpd.send("</html>\r\n")

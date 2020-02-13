package.path = package.path .. ';/portal/lib/?.lua'
local troubleshooting = require 'troubleshooting'
local sys = require 'luci.sys'
local nixio = require 'nixio'

uhttpd.send("Status: 200 OK\r\n")
uhttpd.send("Content-Type: text/html\r\n\r\n")
uhttpd.send("<!DOCTYPE html>\r\n")
uhttpd.send("<html>\r\n")
uhttpd.send("<body>\r\n")
uhttpd.send("<h1>Solo support</h1>\r\n")
uhttpd.send("<p>Date: " .. troubleshooting.date() .. "</p>\r\n")
uhttpd.send("<p>Hostname: " .. sys.hostname() .. "</p>\r\n")
if troubleshooting.has_network() then
  local autossh_state = nil
  if troubleshooting.get_autossh_status() then
    autossh_state = "Up"
  else
    autossh_state = "Down"
  end
  uhttpd.send("<p>Status autossh: " .. autossh_state .."</p>\r\n")
  uhttpd.send("<p><a href='/autossh'>Enable/Disable remote ssh</a></p>\r\n")
else
  uhttpd.send("<p>Autossh unavailable</p>")
end
uhttpd.send("<p>\r\n")
uhttpd.send("Go to <a href='http://10.168.168.1:8888'>LUCI</a>\r\n")
uhttpd.send("</p>\r\n")
uhttpd.send("<h2>Diagnostic</h2>\r\n")
uhttpd.send("<p>\r\n")
uhttpd.send("<a href='/support'>More information</a>\r\n")
uhttpd.send("</p>\r\n")
function print_diagnostic()
  local plugged = troubleshooting.is_port2_plugged()
  if not plugged then
    uhttpd.send("<div>\r\n")
    uhttpd.send("Your access point is not plugged correctly, so it does not have access to internet. Please check your connections.\r\n")
    uhttpd.send("If nothing happens please contact our support service with the content of /support, the link is down below (More information) at support@citypassenger.com\r\n")
    uhttpd.send("</div>\r\n")
    return false
  end

  local leased = troubleshooting.has_lease()
  if not leased then
    uhttpd.send("<div>\r\n")
    uhttpd.send("Your access point did not get a DHCP lease. Please check your DHCP server.\r\n")
    uhttpd.send("Send a mail and copy paste the content of /support, the link is down below (More information) to our support serivce: support@citypassenger.com\r\n")
    uhttpd.send("</div>\r\n")
    return false
  end

  if not support.has_network() then
    uhttpd.send("<div>\r\n")
    uhttpd.send("Your access point does not have access to internet.\r\n")
    uhttpd.send("Please check your internet connection.\r\n")
    uhttpd.send("If your internet connection is OK. Please contact our support service with the content of /support, the link is down below (More information) at support@citypassenger.com\r\n")
    uhttpd.send("</div>\r\n")
    uhttpd.send("</body>\r\n")
    uhttpd.send("</html>\r\n")
    return true
  end

  local has_portal = troubleshooting.has_access_to_portal()
  if not has_portal then
    uhttpd.send("<div>\r\n")
    uhttpd.send("Your access point can't reach the captive portal. Check your internet connection.\r\n")
    uhttpd.send("If your internet connection is OK. Please contact our support our support service with the content of /support, the link is down below (More information) at support@citypassenger.com\r\n")
    uhttpd.send("</div>\r\n")
    uhttpd.send("</body>\r\n")
    uhttpd.send("</html>\r\n")
    return true
  end
end
local diag = print_diagnostic()

if diag then
  uhttpd.send("<h2>Network diagnostic</h2>\r\n")
  uhttpd.send("<h3>ping 8.8.8.8</h3>\r\n")
  uhttpd.send(troubleshooting.ping("8.8.8.8"))
  uhttpd.send("\r\n")
  uhttpd.send("<h3>ping gateway</h3>\r\n")
  local gateway_ip = troubleshooting.get_ip_gateway()
  if not gateway_ip then
    uhttpd.send("No gateway ip address")
  else
    uhttpd.send(troubleshooting.ping(troubleshooting.get_ip_gateway()))
  end 
  uhttpd.send("\r\n")
  uhttpd.send("<h3>DNS</h3>\r\n")
  if not nixio.getaddrinfo("www.google.com") then
    uhttpd.send("Could not resolve www.google.com")
  else
    uhttpd.send("Successfully resolved www.google.com")
  end
  uhttpd.send("\r\n")
  uhttpd.send("<h3>Netcat google</h3>\r\n")
  if support.has_network() then
    uhttpd.send("OK\r\n")
  else
    uhttpd.send("KO\r\n")
  end
  uhttpd.send("\r\n")
  uhttpd.send("<h3>cURL google</h3>\r\n")
  local res = troubleshooting.curl_google()
  if res.exit ~= 0 then
    uhttpd.send("cURL failed with exit code: "..res.exit)
    uhttpd.send("\r\n")
    uhttpd.send("cURL stderr:\r\n")
    uhttpd.send(read_file("/tmp/curl_google_stderr"))
    uhttpd.send("\r\n")
  end
  if res.http_code ~= "200" then
    uhttpd.send("HTTP response: "..res.http_code)
  end
  if res.http_code == "200" and res.exit == 0 then
    uhttpd.send("OK")
  end
  uhttpd.send("\r\n")
  uhttpd.send("<h3>Netcat cityscope</h3>\r\n")
  if support.netcat_cityscope() then
    uhttpd.send("OK\r\n")
  else
    uhttpd.send("KO\r\n")
  end
  uhttpd.send("\r\n")
  uhttpd.send("<h3>cURL cityscope</h3>\r\n")
  local res = troubleshooting.curl_cityscope()
  if res.exit ~= 0 then
    uhttpd.send("cURL failed with exit code: "..res.exit)
    uhttpd.send("\r\n")
    uhttpd.send("cURL stderr:\r\n")
    uhttpd.send(read_file("/tmp/curl_cityscope_stderr"))
    uhttpd.send("\r\n")
  end
  if res.http_code ~= "200" then
    uhttpd.send("HTTP response: "..res.http_code)
  end
  if res.http_code == "200" and res.exit == 0 then
    uhttpd.send("OK")
  end
  uhttpd.send("\r\n")
end

uhttpd.send("</body>\r\n")
uhttpd.send("</html>\r\n")

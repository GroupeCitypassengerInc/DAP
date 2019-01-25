--[[
--
-- Unit testing file script for checker file
--
--]]

package.path = package.path .. ";../www/?.lua"
unit               = require "unit-test"
check              = require "check"
uhttpd             = require "uhttpd"
json               = require "luci.jsonc"

function format_string(str,format)
  return format .. str .. "\27[0m"
end

print(format_string(
      "======= BEGIN UNIT TESTING =======",
      "\27[1m\27[103m\27[34m"
))


print("======================================================")
print("=======================UNIT TEST======================")
print("======================================================")
--

--[[  ----------------------------------------------------
--
--		INSERT SECRET IN ACCESS POINT
--
--]]  ----------------------------------------------------

print(format_string("Test case insert_localdb", "\27[96m"))

unit.expect("Empty input", 
	check.insert_localdb("","","",""),
	false)

local user_mac = "62:a1:b2:c3:d4:e6"
local user_ip  = "192.222.1"
local sid	 = "1c88b8fff0b08acfdbb9c2e04a34ead1"
local secret     = "64cd52674299081e747d08d21fbf4c29"
unit.expect("invalid ip", 
	check.insert_localdb(user_mac,user_ip,sid,secret),
	false)

local user_mac = "62:a1:b2"
local user_ip  = "192.222.1"
local sid	 = "1c88b8fff0b08acfdbb9c2e04a34ead1"
local secret     = "64cd52674299081e747d08d21fbf4c29"
unit.expect("invalid mac", 
	check.insert_localdb(user_mac,user_ip,sid,secret),
	false)

local user_mac = "62:a1:b2:c3:d4:e6"
local user_ip  = "192.222.1.2"
local sid	 = "1c88b8fff0b08acfdbb9c2e04a34ead1"
local secret     = "64cd52674299081e747d08d21fbf4c29"
unit.expect("Valid input", 
	check.insert_localdb(user_mac,user_ip,sid,secret),
	true)

local user_mac = "62:a1:b2:c3:d4:e6"
local user_ip  = "192.222.1.2"
local sid	 = "1c88b8fff0b08acfdbb9c2e04a34ead^"
local secret     = "64cd52674299081e747d08d21fbf4c29"
unit.expect("Sid not hex", 
	check.insert_localdb(user_mac,client_ip,sid,secret),
	false)

local user_mac = "62:a1:b2:c3:d4:e6"
local user_ip  = "192.222.1.2"
local sid	 = "1c88b8fff0b08"
local secret     = "64cd52674299081e747d08d21fbf4c29"
unit.expect("sid invalid length",
	check.insert_localdb(user_mac,user_ip,sid,secret),
	false)

local user_mac = "62:a1:b2:c3:d4:e5"
local user_ip  = "192.222.1.2"
local sid	 = "1c88b8fff0b08acfdbb9c2e04a34ead1"
local secret     = "64cd52674299081e747d08d21fbf4c2r"
unit.expect("Secret not hex", 
	check.insert_localdb(user_mac,user_ip,sid,secret),
	false)

local user_mac = "62:a1:b2:c3:d4:e5"
local user_ip  = "192.222.1.2"
local sid	 = "1c88b8fff0b08acfdbb9c2e04a34ead1"
local secret     = "64cd5267429908"
unit.expect("Not valid secret length", 
	check.insert_localdb(user_mac,user_ip,sid,secret),
	false)


--[[  ----------------------------------------------------
--
--		SELECT SECRET ON ACCESS POINT
--
--]]  ----------------------------------------------------

print(format_string("Test case select_localdb", "\27[96m"))

unit.expect("empty input", check.select_localdb("","","",""),false)

--# $db/$mac/$ip/$sessionid/$secret
--# Simulate a client on wifi who was able to reach the LOGIN page on wp_portal
os.execute("mkdir -p /tmp/ssid-test/62:a1:b2:c3:d4:e5/192.222.1.2/1c88b8fff0b08acfdbb9c2e04a34ead1/64cd52674299081e747d08d21fbf4c29");


local user_mac = "62:a1:b2:c3:d4:e5"
local user_ip  = "192.222.1.2"
local sid	 = "1c88b8fff0b08acfdbb9c2e04a34ead1"
local secret     = "64cd52674299081e747d08d21fbf4c29"
unit.expect("valid input", 
	check.select_localdb(user_mac,user_ip,sid,secret),
	true)

local user_mac = "62:a1:b2:c3:d4:e5"
local user_ip  = "192.222.1"
local sid	 = "1c88b8fff0b08acfdbb9c2e04a34ead1"
local secret     = "64cd52674299081e747d08d21fbf4c29"
unit.expect("invalid ip", 
	check.select_localdb(user_mac,user_ip,sid,secret),
	false)

local user_mac = "2:c3:d4:e5"
local user_ip  = "192.222.1.2"
local sid	 = "1c88b8fff0b08acfdbb9c2e04a34ead1"
local secret     = "64cd52674299081e747d08d21fbf4c29"
unit.expect("invalid mac", 
	check.select_localdb(user_mac,user_ip,sid,secret),
	false)

local user_mac = "62:a1:b2:c3:d4:e5"
local user_ip  = "192.222.1.2"
local sid	 = "1c88b8fff0b08acfdbb9c2e04a34ead1"
local secret     = "64cd52674299081e747d08d21fbf4c2^"
unit.expect("invalid secret - not hex", 
	check.select_localdb(user_mac,user_ip,sid,secret),
	false)

local user_mac = "62:a1:b2:c3:d4:e5"
local user_ip  = "192.222.1.2"
local sid	 = "1c88b8fff0b08acfdbb9c2e04a34ead1"
local secret     = "64cd5267429908"
unit.expect("invalid secret length", 
	check.select_localdb(user_mac,user_ip,sid,secret),
	false)

local user_mac = "62:a1:b2:c3:d4:e5"
local user_ip  = "192.222.1.2"
local sid	 = "1c88b8fff0b08acfdbb9c2e04a34ead$"
local secret     = "64cd52674299081e747d08d21fbf4c29"
unit.expect("invalid sessionid - not hex", 
	check.select_localdb(user_mac,user_ip,sid,secret),
	false)

local user_mac = "62:a1:b2:c3:d4:e5"
local user_ip  = "192.222.1.2"
local sid	 = "1c88b8fff0b"
local secret     = "64cd52674299081e747d08d21fbf4c29"
unit.expect("invalid sessionid length", 
	check.select_localdb(user_mac,user_ip,sid,secret),
	false)

local user_mac = "62:a1:b2:c3:d4:e5"
local user_ip  = "192.222.1.2"
local sid	 = "1c88b8fff0b08acfdbb9c2e04a34ead1"
local secret     = "64cd52674299081e747d08d21fbf4c30"
unit.expect("valid input - secret not stored", 
	check.select_localdb(user_mac,user_ip,sid,secret),
	false)

os.execute("rm -rf /tmp/ssid-test/*");

print(format_string("PASSED TESTS: " .. unit.passed_count .. "/" .. unit.count,"\27[1m\27[32m"))
if unit.count-unit.passed_count > 0 then
  print(format_string("FAILED TESTS: " .. unit.count-unit.passed_count .. "/" .. unit.count,"\27[1m\27[31m"))
end
print(format_string("======= END UNIT TESTING =======","\27[1m\27[103m\27[34m"))



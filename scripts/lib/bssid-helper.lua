local bssid = {}

function format_mask(s)
  while (string.len(s) < 3) do
    s = '0' .. s
  end
  return s
end

P
local path_addr = '/sys/devices/platform/soc/c080000.edma/net/eth1/address'
local mac = io.popen('/bin/cat ' .. path_addr):read('*l')
local base_bssid = '70:b3:d5:e7:e'
local m = string.sub(mac,14,17)
local mask = string.gsub(m,':','')
local mask = '0x' .. mask

function bssid.get_bssid(i)
  mask = (mask + i) % 4096
  local n = mask
  local s = string.format('%x',n)
  local s = format_mask(s)
  local suffix = string.sub(s,1,1) .. ":" .. string.sub(s,2,3)
  local bssid = base_bssid .. suffix
  return bssid
end

return bssid

r = {}

function r.split_line(line,re)
  words = {}
  for word in string.gmatch(line,re) do
    table.insert(words,word)
  end
  return words
end

function r.get_mac(line)
  local re = '[%w.:%-%_]+'
  local t = r.split_line(line,re)
  return t[2]
end 

function r.get_ip(line)
  local re = '[%w.:%-%_]+'
  local t = r.split_line(line,re)
  return t[3]
end

function r.get_hostname(line)
  local re = '[%w.:%-%_]+'
  local t = r.split_line(line,re)
  return t[4]
end

return r

#!/bin/sh

file=/tmp/dns.data
maxsize=50

while true; do
  current_size=$(du -k $file | cut -f1)
  if [ $current_size -ge $maxsize ]; then
    lua /scripts/post-log.lua
    sleep 5
  else
    sleep 5
  fi
done


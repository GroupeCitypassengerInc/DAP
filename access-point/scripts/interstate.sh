#!/bin/sh

DIR=/tmp
FILE_INTERNET=$DIR/internet
FILE_NOINTERNET=$DIR/nointernet

nc -w2 -zv www.google.com 443 2> /dev/null
if [ $? != 0 ]; then 
  # no internet connectivity => create /tmp/nointernet, make sure it exists first
  echo "FAIL"
  if [ ! -e $FILE_NOINTERNET ]; then
    touch $FILE_NOINTERNET
    rm -f $FILE_INTERNET
    lua /scripts/support-mode.lua
  fi
else
  echo "SUCCESS"
  if [ ! -e $FILE_INTERNET ]; then
    touch $FILE_INTERNET
    rm -f $FILE_NOINTERNET
    lua /scripts/get-configuration.lua
    lua /scripts/start-ap-services.lua
    brctl addif bridge1 wlan0
  fi
fi
return 0

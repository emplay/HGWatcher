#!/bin/sh
######################################################################
# HGWnet.sh
# 这个脚本由HGWatcher.sh调用，运行两次netstat命令
#
######################################################################
if [ $2 != 0 ]; then
  echo "zzz ***"`date '+%a %b %e %T %Z %Y'` >> $1
else
  echo "zzz ***"`date` >> $1
fi
netstat -a -i -n >> $1
netstat -s >> $1
rm locks/netlock.file

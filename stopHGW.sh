#!/bin/sh
######################################################################
# stopOSW.sh
# 终止HGWatcher运行
#
######################################################################
pro=`ps -ef | grep HGWatcher | grep -v grep | awk '{print $2}'`
if test -n "$pro"
then
	ps -ef | grep HGWatcher | grep -v grep | awk '{print $2}' | xargs kill -15
else
	echo "HGW not running."
fi


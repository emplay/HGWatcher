#!/bin/sh
######################################################################
# oswsub.sh
# 这个脚本由HGWatcher.sh调用，是通用的数据收集脚本。
# $1是收集的数据输出到文件名
# $2是要执行的脚本
# $3是规范时间戳格式
######################################################################
if [ $3 != 0 ]; then
  echo "zzz ***"`date '+%a %b %e %T %Z %Y'` >> $1
else
  echo "zzz ***"`date` >> $1
fi
$2 >> $1


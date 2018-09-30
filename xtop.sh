#!/bin/sh
######################################################################
# xtop.sh
# 这个脚本由HGWatcher.sh调用，辅助收集top的数据。
# $1是收集的数据输出到文件名
# $2是规范时间戳格式
######################################################################

lineCounter=1
lineStart=1
lineRange=1
offset=1

#determine offset based on os top command
PLATFORM=`/bin/uname`
if [ $2 != 0 ]; then
  echo "zzz ***"`date '+%a %b %e %T %Z %Y'` >> $1
else
  echo "zzz ***"`date` >> $1
fi

top -b -n2 -d1 > tmp/xtop.tmp

lineCounter=`cat tmp/xtop.tmp | wc -l | awk '{$1=$1;print}'`
lineStart=`expr $lineCounter / 2`
lineStart=`expr $lineStart + $offset`
lineRange=`expr $lineCounter - $lineStart `


tail -$lineRange tmp/xtop.tmp >> tmp/ltop.tmp
head -50 tmp/ltop.tmp >> $1
rm tmp/ltop.tmp

rm tmp/xtop.tmp
rm locks/toplock.file



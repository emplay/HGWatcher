#!/bin/sh
######################################################################
# iosub.sh
# 这个脚本由HGWatcher.sh调用，辅助收集iostat的数据。
# $1是收集的数据输出到文件名
# $2是要执行的脚本
# $3是规范时间戳格式
######################################################################
lineCounter1=1
lineCounter2=1

if [ $3 != 0 ]; then
  echo "zzz ***"`date '+%a %b %e %T %Z %Y'` >> $1
else
  echo "zzz ***"`date` >> $1
fi

$2 >> tmp/nfs.tmp
lineCounter1=`cat tmp/nfs.tmp | wc -l | awk '{$1=$1;print}'`
lineCounter2=`expr $lineCounter1 / 3`
tail -$lineCounter2 tmp/nfs.tmp >> $1
rm tmp/nfs.tmp
rm locks/nfslock.file

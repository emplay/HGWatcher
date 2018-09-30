#!/bin/sh
######################################################################
# psmemswsub.sh
# 这个脚本由HGWatcher.sh调用，辅助收集ps的数据。
# $1是收集的数据输出到文件名
# $2是要执行的脚本
# $3是规范时间戳格式
######################################################################
echo "" >> $1
if [ $3 != 0 ]; then
  echo "zzz ***"`date '+%a %b %e %T %Z %Y'` >> $1
else
  echo "zzz ***"`date` >> $1
fi

ps -aeo    user,pid,ppid,pri,pcpu,pmem,vsize,rssize,wchan,s,start,cputime,command | head -1 >> $1
ps -aeo    user,pid,ppid,pri,pcpu,pmem,vsize,rssize,wchan,s,start,cputime,command | sort -nr -k 6 >> $1

rm locks/pslock.file

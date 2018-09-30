#!/bin/sh
######################################################################
# HGWatcherFM.sh是归档文件管理程序，每分钟执行一次，清理超期的归档文件。
######################################################################
#echo "Starting File Manager Process"
PLATFORM=`/bin/uname`
archiveInterval=$1
numberToDelete=0
archiveInterval=`expr $archiveInterval + 1`
check=0

######################################################################
# 开始死循环，由stopHGW.sh结束
######################################################################
until [ $check -eq 1 ]
do
######################################################################
# 每分钟执行一次
######################################################################
sleep 60

######################################################################
# VMSTAT
######################################################################
numberOfFiles=`ls -t $2/HGWvmstat | wc -l`
numberToDelete=`expr $numberOfFiles - $archiveInterval`
if [ $numberOfFiles -gt $archiveInterval ]
  then
    ls -t $2/HGWvmstat/* | tail -$numberToDelete | xargs rm
fi

######################################################################
# NETSTAT
######################################################################
numberOfFiles=`ls -t $2/HGWnetstat | wc -l`
numberToDelete=`expr $numberOfFiles - $archiveInterval`
if [ $numberOfFiles -gt $archiveInterval ]
  then
    ls -t $2/HGWnetstat/* | tail -$numberToDelete | xargs rm
fi
######################################################################
# MPSTAT
######################################################################
numberOfFiles=`ls -t $2/HGWmpstat | wc -l`
numberToDelete=`expr $numberOfFiles - $archiveInterval`
if [ $numberOfFiles -gt $archiveInterval ]
  then
    ls -t $2/HGWmpstat/* | tail -$numberToDelete | xargs rm
fi
######################################################################
# IOSTAT
######################################################################
numberOfFiles=`ls -t $2/HGWiostat | wc -l`
numberToDelete=`expr $numberOfFiles - $archiveInterval`
if [ $numberOfFiles -gt $archiveInterval ]
  then
    ls -t $2/HGWiostat/* | tail -$numberToDelete | xargs rm
fi
######################################################################
# TOP
######################################################################
numberOfFiles=`ls -t $2/HGWtop | wc -l`
numberToDelete=`expr $numberOfFiles - $archiveInterval`
if [ $numberOfFiles -gt $archiveInterval ]
  then
    ls -t $2/HGWtop/* | tail -$numberToDelete | xargs rm
fi
######################################################################
# PS -ELF
######################################################################
numberOfFiles=`ls -t $2/HGWps | wc -l`
numberToDelete=`expr $numberOfFiles - $archiveInterval`
if [ $numberOfFiles -gt $archiveInterval ]
  then
    ls -t $2/HGWps/* | tail -$numberToDelete | xargs rm
fi
######################################################################
# IFCONFIG
######################################################################
numberOfFiles=`ls -t $2/HGWifconfig | wc -l`
numberToDelete=`expr $numberOfFiles - $archiveInterval`
if [ $numberOfFiles -gt $archiveInterval ]
  then
    ls -t $2/HGWifconfig/* | tail -$numberToDelete | xargs rm
fi
######################################################################
# df -h、df -i
######################################################################
numberOfFiles=`ls -t $2/HGWdfh | wc -l`
numberToDelete=`expr $numberOfFiles - $archiveInterval`
if [ $numberOfFiles -gt $archiveInterval ]
  then
    ls -t $2/HGWdfh/* | tail -$numberToDelete | xargs rm
fi
numberOfFiles=`ls -t $2/HGWdfi | wc -l`
numberToDelete=`expr $numberOfFiles - $archiveInterval`
if [ $numberOfFiles -gt $archiveInterval ]
  then
    ls -t $2/HGWdfi/* | tail -$numberToDelete | xargs rm
fi
######################################################################
# 数据库归档清理
######################################################################
((numberToDelete=$1*60))
find $2/HGdatabase -type f -mmin +$numberToDelete -exec rm -f {} \;
######################################################################
# meminfo、slabinfo、nfs
######################################################################
case $PLATFORM in
  Linux)
    numberOfFiles=`ls -t $2/HGWmeminfo | wc -l`
    numberToDelete=`expr $numberOfFiles - $archiveInterval`
    if [ $numberOfFiles -gt $archiveInterval ]
     then
       ls -t $2/HGWmeminfo/* | tail -$numberToDelete | xargs rm
    fi
    numberOfFiles=`ls -t $2/HGWslabinfo | wc -l`
    numberToDelete=`expr $numberOfFiles - $archiveInterval`
    if [ $numberOfFiles -gt $archiveInterval ]
     then
       ls -t $2/HGWslabinfo/* | tail -$numberToDelete | xargs rm
    fi
    if [ -d $2/HGWnfs ]; then
    numberOfFiles=`ls -t $2/HGWnfs | wc -l`
    numberToDelete=`expr $numberOfFiles - $archiveInterval`
    if [ $numberOfFiles -gt $archiveInterval ]
     then
       ls -t $2/HGWnfs/* | tail -$numberToDelete | xargs rm
    fi    
    fi
esac
done


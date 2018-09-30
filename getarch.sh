#!/bin/bash
#########################################################################
# getarch.sh用以执行一次HGWatcher.sh，然后收集HGWatcher的归档文件，
#########################################################################
basepath=$(cd `dirname $0`; pwd)
cd $basepath
hour=`date +'%y.%m.%d.%H%M'`
userid=`id -u`
if [[ userid -eq 0 ]];then
        :
else
        username=`whoami`
        echo -e "The current user:$username"
        echo 'Please use the root run the script!'
        exit 1
fi
./stopHGW.sh
sleep 5
HGW_ARCHIVE_DEST=`cat $basepath/tmp/HGW.hb`
last=`cat $basepath/tmp/last.sh`
$last -check true
sleep 30
./stopHGW.sh
DBLIST=`cat $basepath/tmp/dblist.dir`
if test -n "$DBLIST" && test -f "$DBLIST"
then
  for i in $(grep DATABASE  $DBLIST|grep -v END | grep -o "[0-9]\{1,3\}")
  do
    DATABASEN="DATABASE$i"
    ENDDATABASEN="END"$DATABASEN
    logdir=`awk '/\['$DATABASEN'\]/,/\['$ENDDATABASEN'\]/ {print}' $DBLIST |grep log_directory|awk -F '=' '{print $2}'`
    pgport=`awk '/\['$DATABASEN'\]/,/\['$ENDDATABASEN'\]/ {print}' $DBLIST |grep PGPORT|awk -F '=' '{print $2}'`
    mkdir -p $HGW_ARCHIVE_DEST/pglog/$pgport
    find $logdir -type f -mtime -7 -exec cp {} $HGW_ARCHIVE_DEST/pglog/$pgport/ \;
  done
fi
tar -czf HGWatcher_archive_$hour.tar.gz $HGW_ARCHIVE_DEST 2>/dev/null
echo -e "\033[32m##########################################################################################\033[0m"
echo -e "\033[32m#       The output file is $basepath/HGWatcher_archive_$hour.tar.gz\033[0m"
echo -e "\033[32m##########################################################################################\033[0m"
$last

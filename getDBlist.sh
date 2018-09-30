#!/bin/bash
#########################################################################
# getDBlist.sh用以获取当前操作系统上运行的所有PostgreSQL数据库的信息
#########################################################################
basepath=$(cd `dirname $0`; pwd)
cd $basepath
rm -f $basepath/data/dblist.cfg
chmod -R 655 $basepath/
function getDBLIST()
{
  k=1
    for i in `ps -ef|grep "checkpointer process"|grep -v grep|awk '{print $3}'`
    do
        echo "[DATABASE$k]">>$basepath/data/dblist.cfg
        str=`ls -l /proc/$i|grep exe|awk '{print $11}'`
        PSQL=${str%/*}/psql
        echo "PSQL="$PSQL >>$basepath/data/dblist.cfg
        PGDATAPATH=`ls -l /proc/$i|grep cwd|awk '{print $11}'`
        echo "PGDATAPATH="$PGDATAPATH >>$basepath/data/dblist.cfg
        PGPORT=`netstat -anp | grep $i| grep /tmp/.s.PGSQL.|awk -F "." '{print $4}'`
        echo "PGPORT="$PGPORT >>$basepath/data/dblist.cfg
        PGHOST=127.0.0.1
        echo "PGHOST=127.0.0.1" >>$basepath/data/dblist.cfg
        PGUSER=`ps -ef | grep $i |grep -v grep | awk '{print $1}' |head -n 1`
        echo "PGUSER=$PGUSER" >>$basepath/data/dblist.cfg
        echo "OSUSER=$PGUSER" >>$basepath/data/dblist.cfg
        DATABASE=$PGUSER
        dbl='select datname from pg_database where datname not in ($$template0$$, $$template1$$)'
        time1=`date +%s`
        for db in `su - $PGUSER -c "$PSQL -h $PGHOST -p $PGPORT -U $PGUSER -d $DATABASE --pset=pager=off -t -A -q -c '$dbl'"`
        do
        	stat=`su - $PGUSER -c "$PSQL -h $PGHOST -p $PGPORT -U $PGUSER -d $db --pset=pager=off -t -A -q -f $basepath/sql/pg_stat_statements.sql"`
            test -z $stat
            if [ $? == 1 ];then
            	if [ $stat == 0 ];then
            		if test -z "$pstat"
            		then
            			pstat=$db
            		else
            			pstat=$pstat","$db
            		fi
            	fi
                if test -z "$PGDATABASE"
                then
                    PGDATABASE=$db
                else
                    PGDATABASE=$PGDATABASE","$db
                fi
            fi
        done
        time2=`date +%s`
        echo "PGDATABASE="$PGDATABASE >>$basepath/data/dblist.cfg
        Rtime=$((time2-time1))
        if test -z "$pstat"
        then
        	echo ""
        else
        	echo ""
        	echo -e "\033[3;31mDatabase $pstat did not install extended pg_stat_statements!\033[0m"
        fi
        logcol=`su - $PGUSER -c "$PSQL -h $PGHOST -p $PGPORT -U $PGUSER -d $DATABASE --pset=pager=off -t -A -q -c 'show logging_collector'"`
        logdir=`su - $PGUSER -c "$PSQL -h $PGHOST -p $PGPORT -U $PGUSER -d $DATABASE --pset=pager=off -t -A -q -c 'show log_directory'"`
        if [ $logcol == 'on' ];then
            echo "log_directory=$PGDATAPATH/$logdir">>$basepath/data/dblist.cfg
        fi
        if [ $Rtime -gt 1 ];then
        	echo "DirectAccess=0">>$basepath/data/dblist.cfg
        	echo -e "\033[3;31mA database with the name ${DATABASE} under user ${PGUSER} cannot be accessed directly.Reconfigure the database so that it does not need a password for local access.\033[0m"
        else
        	echo "DirectAccess=1">>$basepath/data/dblist.cfg
        fi
        echo "[ENDDATABASE$k]">>$basepath/data/dblist.cfg
        echo "">>$basepath/data/dblist.cfg
        k=`expr $k + 1`
        unset PGDATABASE
        unset stat
        unset pstat
    done
    echo "##########################################################################################"
    echo "#       The output file is $basepath/data/dblist.cfg"
    echo "##########################################################################################"
}
#########################################################################
# 判断选项中是否输入了数据库名称，如果安装了多个数据库软件且都在运行，将提示
# 是否获取所有数据库软件的运行信息，并生成数据库列表文件 
#########################################################################
userid=`id -u`
if [[ userid -eq 0 ]];then
        :
else
        username=`whoami`
        echo -e "The current user:$username"
        echo 'Please use the root run the script!'
        exit 1
fi
dbnum=`ps -ef|grep "checkpointer process"|grep -v grep|awk '{print $3}'|wc -l`
if [ $dbnum -gt 1 ];then
  echo "The current environment has a set of "$dbnum" databases."
  echo "To monitor all databases, you need to write all database information to the file dblist.cfg, and then use the -dblist option."
  echo "You can also read the database information through the current script and then modify it according to the actual situation."
  read -p "Do you want to generate a database information list [Y/N]?" answer
  case $answer in
   Y | y)
     getDBLIST
     ;;
   N | n)
     echo "Write the database information file list manually.";;
   *)
     echo "Error entered. Please rerun the script."
     exit 1
     ;;
  esac
fi


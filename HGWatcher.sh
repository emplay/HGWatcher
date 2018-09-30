#!/bin/bash
######################################################################
# HGWatcher.sh负责监控服务器的各项指标，并写入到对应的归档文件中。
######################################################################

#########################################################################
# 定义控制变量
#########################################################################
zipfiles=0
status=0
vmstatus=0
mpstatus=0
sarstatus=0
iostatus=0
nfs_collect=0
ifconfig_collect=0
ifconfigstatus=0
nfsstatus=0
psstatus=0
psmemstatus=0
netstatus=0
TOPFOUND=1
topstatus=0
ibstatus=0
ZERO=0
PS_MULTIPLIER_COUNTER=0
ioheader=1
lasthour="0"
ARCHIVE_FOUND=0
lineCounter1=1
lineCounter2=1
diff=1
PLATFORM=`/bin/uname`
hostn=`hostname`
version="v1.0.0"
qMax=0
CYAN="\033[1;36;40m"
NORM="\033[0m"
check=0
i=1
numargs=$#
OTHER=flase
HELP=flase
dbtmp=false
basepath=$(cd `dirname $0`; pwd)
cd $basepath
DL=false
SQLPATH=$basepath/sql
DBLIST=$basepath/data/dblist.cfg
#########################################################################
# 根据选项名称获取参数
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
while [[ $i -le $numargs ]]
do
  j=$1
  case $j in
  -OSsnapshot)
       OSsnapshot=$2
       order=$order" -OSsnapshot $OSsnapshot"
       shift 1
       i=`expr $i + 1`
  ;;
  -DBsnapshot)
       DBsnapshot=$2
       order=$order" -DBsnapshot $DBsnapshot"
       shift 1
       i=`expr $i + 1`
  ;;
  -archtime)
       archtime=$2
       order=$order" -archtime $archtime"
       shift 1
       i=`expr $i + 1`
  ;;
  -archpath)
       archpath=$2
       order=$order" -archpath $archpath"
       shift 1
       i=`expr $i + 1`
  ;;
  -dblist)
       DBLIST=$2
       order=$order" -dblist $DBLIST"
       DL=true
       shift 1
       i=`expr $i + 1`
  ;;
  -check)
     chk=$2
     DL=true
     shift 1
     i=`expr $i + 1`
  ;;
  -help)
       HELP=true
       shift 1
       i=`expr $i + 1`
  ;;
  *)
    tmp=$j
    OTHER=true
    shift 1
    i=`expr $i + 1`
  ;;
  esac
  shift 1
  i=`expr $i + 1`
done

if [ $OTHER == 'true' ];then
  echo ""
  echo -e "\033[3;31mOption ${tmp} error, please use -help to view help\033[0m"
  echo ""
  exit 1
fi
if [ $HELP == 'true' ];then
  echo "Usage $0 [-dblist \"<Specify the dblist.cfg file that holds the PostgreSQL database information,you can get this file by running the script getdblist.sh>\]"
  echo "         [ -OSsnapshot \"<Operating system information capture snapshot time, default is 30 seconds to fetch once.>\" ] "
  echo "         [ -DBsnapshot \"<Database information fetching snapshot time, default is 60 minutes to fetch once.>\"] "
  echo "         [ -archtime \"<Archive retention time, 148 hours by default>\"] "
  echo "         [ -archpath \"<Archive files are stored in the directory by default in HGWatcher/archive>\"]"
  echo "         [ -help  Display help information"
  exit 1
fi

if [ $DL == 'true' ];then
  if test -n "$DBLIST" && test -f "$DBLIST"
    then
      echo ""
      echo "The database information file currently in use is $DBLIST"
    else
      echo -e "\033[3;31mPlease specify a valid and existing dblist.cfg file!\033[0m"
      exit 1
  fi
fi
if [ x"$chk" != xtrue ];then
  echo "./HGWatcher.sh $order" >tmp/last.sh
fi
#########################################################################
# 创建输出带颜色的输出函数
# $1表示要打印的内容
# $2表示要使用的颜色，有三种选择：green,yellow,red
#########################################################################
function cecho()
{
    var_str=$1
    var_color=$2
    var_curr_timestamp=`date "+%Y-%m-%d %H:%M:%S"`

    if [ "x${var_str}" == "x" ];then
        var_str=""
    else
        var_str="${var_curr_timestamp} ${var_str}"
    fi

    if [ "${var_color}" == "green" ];then
        var_str="\033[32m${var_str}\033[0m"
    elif [ "${var_color}" == "yellow" ];then
        var_str="\033[33m${var_str}\033[0m"
    elif [ "${var_color}" == "red" ];then
        var_str="\033[3;31m${var_str}\033[0m"
    else
        var_str="\033[37m${var_str}\033[0m"
    fi

    echo -e "${var_str}"
}
#########################################################################
#HGWatcher通过操作系统命令获取CPU核心数（core_count），CPU线程数(vcp_count)
#也通过操作系统命令获取，如果这些命令因为操作系统原因未获取到正确的数值，可以手
#动修改以下变量，设置正确的核心数和线程数
#########################################################################
core_count=0
vcpu_count=0
#########################################################################
#HGWatcher的时间戳格式，1为默认格式
#########################################################################
HGWCompliance=1

#########################################################################
# 是否收集“ifconfig -a”的信息，如果不收集，注释掉以下命令或将1改为0. 
#########################################################################
ifconfig_collect=1

#########################################################################
# 此参数用于控制收集额外的iostat信息，iostat -nk仅适用于linux。默认为0表示不收
# 集。设置这个参数设置为1以启用此功能。 
#########################################################################
nfs_collect=0

#########################################################################
# 检测输入变量并加载
#########################################################################
test $OSsnapshot
if [ $? = 1 ]; then
    echo
    cecho "Info...You did not enter a value for snapshotInterval." "green"
    cecho "Info...Using default value = 30" "green"
    snapshotInterval=30
  else
    snapshotInterval=$OSsnapshot
fi
test $archtime
if [ $? = 1 ]; then
    cecho "Info...You did not enter a value for archiveInterval." "green"
    cecho "Info...Using default value = 48" "green"
    archiveInterval=168
  else
    archiveInterval=$archtime
fi
test $archpath
if [ $? != 1 ]; then
  if [ ! -d $archpath ]; then
    echo "The archive directory you specified for parameter 4 in startHGW.sh:"$archpath" does not exist. Please create this directory and rerun ./HGWatcher.sh"
    exit
  else
   ARCHIVE_FOUND=1
   HGW_ARCHIVE_DEST=$archpath
  fi
fi
test $DBsnapshot
if [ $? = 1 ]; then
    echo
    cecho "Info...You did not enter a value for DBsnapshotInterval." "green"
    cecho "Info...Using default value = 60m" "green"
    DBsnapshotInterval=60
  else
    DBsnapshotInterval=$DBsnapshot
fi

#########################################################################
# 检查snapshotInterval、archiveInterval是否有效
#########################################################################
test $snapshotInterval
if [ $snapshotInterval -lt 1 ]; then
    cecho "Warning...Invalid value for snapshotInterval. Overriding with default value = 30" "yellow"
    snapshotInterval=30
fi
test $archiveInterval
if [ $archiveInterval -lt 1 ]; then
    cecho "Warning...Invalid value for archiveInterval . Overriding with default value = 48" "yellow"
    archiveInterval=168
fi
test $DBsnapshotInterval
if [ $DBsnapshotInterval -lt 10 ]; then
    cecho "Warning...Invalid value for snapshotInterval. Overriding with default value = 60m" "yellow"
    DBsnapshotInterval==60m
  else
    DBsnapshotInterval=$DBsnapshotInterval"m"
fi
#########################################################################
# 检查环境变量HGW_ARCHIVE_DEST，HGW_ARCHIVE_DEST设置HGW归档文件的存放路径，
# 如果未设置，则默认归档到HGWatcher目录下的archive文件夹
#########################################################################
if [ $ARCHIVE_FOUND = $ZERO ];
then
fdir=`env | grep HGW_ARCHIVE_DEST | wc -c`
if [ $fdir = $ZERO ];
then
  HGW_ARCHIVE_DEST=$basepath/archive
else
if [ ! -d $HGW_ARCHIVE_DEST ]; then
  cecho "The archive directory you specified in HGW_ARCHIVE_DEST does not exist" "yellow"
  cecho "Please create this directory and rerun ./HGWatcher.sh" "yellow"
  exit
fi
fi
  cecho "Setting the archive log directory to"$HGW_ARCHIVE_DEST "green"
fi

#########################################################################
# 判断归档目录是否存在，不存在则创建
#########################################################################
path=`pwd`
if [ $path = "/" ]; then
  cecho "Warning...You can not run HGWatcher from the root directory" "yellow"
  exit
fi

if [ ! -d $HGW_ARCHIVE_DEST ]; then
        mkdir $HGW_ARCHIVE_DEST
fi
if [ ! -d $HGW_ARCHIVE_DEST/HGWps ]; then
        mkdir -p $HGW_ARCHIVE_DEST/HGWps
fi
if [ ! -d $HGW_ARCHIVE_DEST/HGWtop ]; then
        mkdir -p $HGW_ARCHIVE_DEST/HGWtop
fi
if [ ! -d $HGW_ARCHIVE_DEST/HGWnetstat ]; then
        mkdir -p $HGW_ARCHIVE_DEST/HGWnetstat
fi
if [ ! -d $HGW_ARCHIVE_DEST/HGWiostat ]; then
        mkdir -p $HGW_ARCHIVE_DEST/HGWiostat
fi
if [ ! -d $HGW_ARCHIVE_DEST/HGWnfs ]; then
  if [ $nfs_collect = 1 ]; then
     case $PLATFORM in
     Linux)
        mkdir -p $HGW_ARCHIVE_DEST/HGWnfs
  ;;
  esac
  fi
fi
if [ ! -d $HGW_ARCHIVE_DEST/HGWvmstat ]; then
        mkdir -p $HGW_ARCHIVE_DEST/HGWvmstat
fi
if [ ! -d $HGW_ARCHIVE_DEST/HGWmpstat ]; then
        mkdir -p $HGW_ARCHIVE_DEST/HGWmpstat
fi
if [ ! -d $HGW_ARCHIVE_DEST/HGWdfh ]; then
        mkdir -p $HGW_ARCHIVE_DEST/HGWdfh
fi
if [ ! -d $HGW_ARCHIVE_DEST/HGWdfi ]; then
        mkdir -p $HGW_ARCHIVE_DEST/HGWdfi
fi
if [ ! -d $HGW_ARCHIVE_DEST/HGdatabase ]; then
        mkdir -p $HGW_ARCHIVE_DEST/HGdatabase
fi

#保留功能，用以检查流复制主备间网络
# if [ ! -d $HGW_ARCHIVE_DEST/HGWprvtnet ]; then
#         mkdir -p $HGW_ARCHIVE_DEST/HGWprvtnet
# fi

if [ ! -d $HGW_ARCHIVE_DEST/HGWifconfig ]; then
        mkdir -p $HGW_ARCHIVE_DEST/HGWifconfig
fi
if [ ! -d locks ]; then
        mkdir locks
fi
if [ ! -d tmp ]; then
        mkdir tmp
fi

#########################################################################
# 创建使用的归档目录
#########################################################################
case $PLATFORM in
  Linux)
    mkdir -p $HGW_ARCHIVE_DEST/HGWmeminfo
    mkdir -p $HGW_ARCHIVE_DEST/HGWslabinfo
    mkdir -p $HGW_ARCHIVE_DEST/HGWcpuinfo
  ;;
esac
#########################################################################
# 清理lock.file文件
#########################################################################
if [ -f locks/vmlock.file ]; then
  rm locks/vmlock.file
fi
if [ -f locks/mplock.file ]; then
  rm locks/mplock.file
fi
if [ -f locks/sarlock.file ]; then
  rm locks/sarlock.file
fi
if [ -f locks/pslock.file ]; then
  rm locks/pslock.file
fi
if [ -f locks/toplock.file ]; then
  rm locks/toplock.file
fi
if [ -f locks/iolock.file ]; then
  rm locks/iolock.file
fi
if [ -f locks/nfslock.file ]; then
  rm locks/nfslock.file
fi
if [ -f locks/ifconfiglock.file ]; then
  rm locks/ifconfiglock.file
fi
if [ -f locks/netlock.file ]; then
  rm locks/netlock.file
fi
if [ -f locks/iblock.file ]; then
  rm locks/iblock.file
fi
if [ -f tmp/xtop.tmp ]; then
  rm tmp/xtop.tmp
fi
if [ -f tmp/vtop.tmp ]; then
  rm tmp/vtop.tmp
fi
if [ -f locks/lock.file ]; then
  rm locks/lock.file
fi

#########################################################################
# 确定主机操作系统，目前仅支持linux系统，并根据操作系统确定需要执行的收集命
# 令.
#########################################################################
case $PLATFORM in
  Linux)
    IOSTAT='iostat -xk 1 3'
    NFSSTAT='iostat -nk 1 3'
    VMSTAT='vmstat 1 3'
    TOP='eval top -b -n 1 | head -50'
    PSELF='ps -elf'
    MPSTAT='mpstat -P ALL 1 2'
    MEMINFO='cat /proc/meminfo'
    SLABINFO='cat /proc/slabinfo'
    IFCONFIG='ifconfig -a'
#    TRACERT="traceroute $standbyIP" 后期作为流复制网络检查
    DFH='df -h'
    DFI='df -i'
    ;;
esac

#########################################################################
# 检查使用的操作系统命令是否存在
#########################################################################
echo ""
echo "Testing for discovery of OS Utilities..."

$VMSTAT > /dev/null 2>&1
if [ $? = 0 ]; then
  cecho "VMSTAT found on your system." "green"
  VMFOUND=1
else
  cecho "Warning... VMSTAT not found on your system. No VMSTAT data will be collected." "yellow"
  VMFOUND=0
fi
VMFOUND=1
$IOSTAT > /dev/null 2>&1
if [ $? = 0 ]; then
  cecho "IOSTAT found on your system." "green"
  IOFOUND=1

else
  cecho "Warning... IOSTAT not found on your system. No IOSTAT data will be collected." "yellow"
  IOFOUND=0
fi

$IFCONFIG > /dev/null 2>&1
if [ $? = 0 ]; then
  cecho "IFCONFIG found on your system." "green"
  IFCONFIGFOUND=1
else
  cecho "Warning... IFCONFIG not found on your system. No IFCONFIG data will be collected." "yellow"
  IFCONFIGFOUND=0
fi

$MPSTAT > /dev/null 2>&1
if [ $? = 0 ]; then
  cecho "MPSTAT found on your system." "green"
  MPFOUND=1
else
  cecho "Warning... MPSTAT not found on your system. No MPSTAT data will be collected." "yellow"
  MPFOUND=0
fi

netstat > /dev/null 2>&1
if [ $? = 0 ]; then
  cecho "NETSTAT found on your system." "green"
  NETFOUND=1
else
  cecho "Warning... NETSTAT not found on your system. No NETSTAT data will be collected." "yellow"
  NETFOUND=0
fi

case $PLATFORM in
  Linux)
    $MEMINFO > /dev/null 2>&1
    if [ $? = 0 ]; then
      MEMFOUND=1
    else
      cecho "Warning... /proc/meminfo not found on your system." "yellow"
      MEMFOUND=0
    fi
    $SLABINFO > /dev/null 2>&1
    if [ $? = 0 ]; then
      SLABFOUND=1
    else
      cecho "Warning... /proc/slabinfo not found on your system." "yellow"
      SLABFOUND=0
    fi
  ;;
esac
#########################################################################
# 获取CPU数量
#########################################################################
echo ""
if [ $core_count = 0 ]; then
  cecho "Discovery of CPU CORE COUNT" "green"
  cecho "CPU CORE COUNT will be used by HGWatcher to automatically look for cpu problems" "green"
  echo ""
  case $PLATFORM in
    Linux)
      vcpu_count=`cat /proc/cpuinfo|grep processor|wc -l`
      core_count=`cat /proc/cpuinfo | egrep "core id" | sort | uniq | wc -l`
      hour=`date +'%y.%m.%d.%H00.dat'`
      cat /proc/cpuinfo >> $HGW_ARCHIVE_DEST/HGWcpuinfo/${hostn}_cpuinfo_$hour
      ;;
  esac
  if [ $core_count -gt 0 ]; then
    cecho "CPU CORE COUNT =" $core_count "green"
    cecho "VCPUS/THREADS =" $vcpu_count "green"
  else
    echo " "
    cecho "Warning... CPU CORE COUNT not found on your system." "yellow"
    echo " "
    echo " "
    cecho "Defaulting to CPU CORE COUNT = 1" "yellow"
    cecho "To correctly specify CPU CORE COUNT" "yellow"
    cecho "1. Correct the error listed above for your unix platform or" "yellow"
    cecho "2. Manually set core_count on HGWatcher.sh line 16 or" "yellow"
    cecho "3. Do nothing and accept default value = 1" "yellow"
    core_count=1
  fi
  else
    cecho "Maunal override of CPU CORE COUNT in effect" "green"
    cecho "CPU CORE COUNT =" $core_count  "green"
fi
echo ""
cecho "Discovery completed." "green"
echo ""
#########################################################################
# 分解数据库信息文件
#########################################################################
if test -n "$DBLIST" && test -f "$DBLIST"
then
  for i in $(grep DATABASE  $DBLIST|grep -v END | grep -o "[0-9]\{1,3\}")
  do
    DATABASEN="DATABASE$i"
    ENDDATABASEN="END"$DATABASEN
    awk '/\['$DATABASEN'\]/,/\['$ENDDATABASEN'\]/ {print}' $DBLIST |grep -v '^\['|grep -v '^#' >$basepath/tmp/$DATABASEN.cfg
  done
else
  cecho "The file "$DBLIST" is not found.You can get the related file dblist.cfg by executing the script ./getDBlist.sh." "red"
  exit 1
fi
echo $DBLIST >$basepath/tmp/dblist.dir
#########################################################################
# 打印启动信息
#########################################################################
sleep 5
cecho "Starting HGWatcher "$version " on "`date` "green"
echo -e "\033[34mWith OSsnapshotInterval = "$snapshotInterval"\033[0m"
echo -e "\033[34mWith DBSnapshotInterval = "$DBsnapshotInterval"\033[0m"
echo -e "\033[34mWith ArchiveInterval = "$archiveInterval"h\033[0m"
echo -e "\033[34mWith ArchivePath = "$HGW_ARCHIVE_DEST"\033[0m"
echo ""
echo "HGWatcher - Written by zb,"
echo "Highgo Corporation"
sleep 5
echo ""
cecho "Data is stored in directory: "$HGW_ARCHIVE_DEST  "green"
echo ""
cecho "Starting Data Collection..."  "green"
echo ""

#########################################################################
# 启动HGWFM文件管理进程
#########################################################################
if test -z "$chk"
then
  pro=`ps -ef | grep HGWatcherFM | grep -v grep | awk '{print $2}'`
  if test -n "$pro"
  then
    ps -ef | grep HGWatcherFM | grep -v grep | awk '{print $2}' | xargs kill -15
  else
    ./HGWatcherFM.sh $archiveInterval $HGW_ARCHIVE_DEST &
  fi
fi
#########################################################################
# 循环执行数据库检查
#########################################################################
until [ $check -eq 1 ]
do
  st=600
  test $chk
  if [ $? = 0 ]; then
    st=60
  fi
  hour=`date +'%y.%m.%d.%H%M'`
  for i in $(grep DATABASE  $DBLIST|grep -v END | grep -o "[0-9]\{1,3\}")
  do
    DATABASEN="DATABASE$i"
    source $basepath/tmp/$DATABASEN.cfg
    arr=(${PGDATABASE//,/ })
    for i in ${arr[@]}
    do
      if [[ $DirectAccess -eq 1 ]];then
        ver=`su - $OSUSER -c "$PSQL -h $PGHOST -p $PGPORT -U $PGUSER -d $i -A -q -t -c \"SELECT version()\"" |awk '{print $2}'`
        ver=${ver%.*}
        if [ $(echo "$ver>=10"|bc) -eq 1 ];then
          touch $HGW_ARCHIVE_DEST/HGdatabase/${hostn}_${i}_${PGPORT}_HGdatabase_$hour.html
          chown $OSUSER: $HGW_ARCHIVE_DEST/HGdatabase/${hostn}_${i}_${PGPORT}_HGdatabase_$hour.html
          su - $OSUSER -c "$PSQL -h $PGHOST -p $PGPORT -U $PGUSER -d $i -A -q -f $SQLPATH/HGWatcher_pg10.sql 1>$HGW_ARCHIVE_DEST/HGdatabase/${hostn}_${i}_${PGPORT}_HGdatabase_$hour.html 2>/dev/null & { sleep $st ; kill $! >/dev/null 2>&1 && echo 'psql Timeout'>>$HGW_ARCHIVE_DEST/HGdatabase/${hostn}_${i}_${PGPORT}_HGdatabase_$hour.html & } &  >/dev/null 2>&1"
        else
          touch $HGW_ARCHIVE_DEST/HGdatabase/${hostn}_${i}_${PGPORT}_HGdatabase_$hour.html
          chown $OSUSER: $HGW_ARCHIVE_DEST/HGdatabase/${hostn}_${i}_${PGPORT}_HGdatabase_$hour.html
          su - $OSUSER -c "$PSQL -h $PGHOST -p $PGPORT -U $PGUSER -d $i -A -q -f $SQLPATH/HGWatcher_pg9.sql 1>$HGW_ARCHIVE_DEST/HGdatabase/${hostn}_${i}_${PGPORT}_HGdatabase_$hour.html 2>/dev/null & { sleep $st ; kill $! >/dev/null 2>&1 && echo 'psql Timeout '>>$HGW_ARCHIVE_DEST/HGdatabase/${hostn}_${i}_${PGPORT}_HGdatabase_$hour.html & } &  >/dev/null 2>&1"
        fi
      else 
        touch $HGW_ARCHIVE_DEST/HGdatabase/${hostn}_${i}_${PGPORT}_HGdatabase_$hour.html
        chown $OSUSER: $HGW_ARCHIVE_DEST/HGdatabase/${hostn}_${i}_${PGPORT}_HGdatabase_$hour.html
        echo "Database $i cannot be accessed directly!">>$HGW_ARCHIVE_DEST/HGdatabase/${hostn}_${i}_${PGPORT}_HGdatabase_$hour.html
      fi
    done
  done
  if [ x"$chk" == xtrue ];then
    check=1
    exit 1
  fi
  sleep $DBsnapshotInterval
done &
#########################################################################
# 循环执行操作系统检查
#########################################################################
until [ $check -eq 1 ]
do
echo "HGW heartbeat:"`date`
#pwd > $basepath/tmp/HGW.hb
echo $HGW_ARCHIVE_DEST > $basepath/tmp/HGW.hb
hour=`date +'%y.%m.%d.%H00.dat'`
#########################################################################
# VMSTAT
#########################################################################
if [ $VMFOUND = 1 ]; then
  if [ $hour != $lasthour ]; then
    echo $PLATFORM HGW $version $hostn >> $HGW_ARCHIVE_DEST/HGWvmstat/${hostn}_vmstat_$hour
    echo "SNAP_INTERVAL" $snapshotInterval  >> $HGW_ARCHIVE_DEST/HGWvmstat/${hostn}_vmstat_$hour
    echo "CPU_CORES" $core_count  >> $HGW_ARCHIVE_DEST/HGWvmstat/${hostn}_vmstat_$hour
    echo "VCPUS" $vcpu_count  >> $HGW_ARCHIVE_DEST/HGWvmstat/${hostn}_vmstat_$hour
    echo "HGW_ARCHIVE_DEST" $HGW_ARCHIVE_DEST  >> $HGW_ARCHIVE_DEST/HGWvmstat/${hostn}_vmstat_$hour
  fi

  if [ -f locks/vmlock.file ]; then
    vmstatus=1
  else
    touch locks/vmlock.file
    if [ $vmstatus = 1 ]; then
      cecho "***Warning. VMSTAT response is spanning snapshot intervals." "yellow"
      vmstatus=0
    fi
    ./vmsub.sh $HGW_ARCHIVE_DEST/HGWvmstat/${hostn}_vmstat_$hour "$VMSTAT" $HGWCompliance &
  fi
fi

######################################################################
# MPSTAT
###################################################################### 

if [ $MPFOUND = 1 ]; then
  if [ $hour != $lasthour ]; then
    echo $PLATFORM HGW $version  >> $HGW_ARCHIVE_DEST/HGWmpstat/${hostn}_mpstat_$hour
  fi

  if [ -f locks/mplock.file ]; then
    mpstatus=1
  else
    touch locks/mplock.file
    if [ $mpstatus = 1 ]; then
      cecho "***Warning. MPSTAT response is spanning snapshot intervals." "yellow"
      mpstatus=0
    fi
   ./mpsub.sh $HGW_ARCHIVE_DEST/HGWmpstat/${hostn}_mpstat_$hour "$MPSTAT" $HGWCompliance &

  fi

fi

#########################################################################
# NETSTAT
#########################################################################
if [ $NETFOUND = 1 ]; then
  if [ $hour != $lasthour ]; then
    echo $PLATFORM HGW $version >> $HGW_ARCHIVE_DEST/HGWnetstat/${hostn}_netstat_$hour
  fi


  if [ -f locks/netlock.file ]; then
    netstatus=1
  else
    touch locks/netlock.file
    if [ $netstatus = 1 ]; then
      cecho "***Warning. NETSTAT response is spanning snapshot intervals." "yellow"
      netstatus=0
    fi
    ./HGWnet.sh $HGW_ARCHIVE_DEST/HGWnetstat/${hostn}_netstat_$hour $HGWCompliance &

  fi
fi

#########################################################################
# IOSTAT
#########################################################################
if [ $IOFOUND = 1 ]; then
  if [ $hour != $lasthour ]; then
    echo $PLATFORM HGW $version  >> $HGW_ARCHIVE_DEST/HGWiostat/${hostn}_iostat_$hour
  fi

  if [ -f locks/iolock.file ]; then
    iostatus=1
  else
    touch locks/iolock.file
    if [ $iostatus = 1 ]; then
      cecho "***Warning. IOSTAT response is spanning snapshot intervals." "yellow"
      iostatus=0
    fi

    ./iosub.sh $HGW_ARCHIVE_DEST/HGWiostat/${hostn}_iostat_$hour "$IOSTAT" $HGWCompliance &

  fi

fi

#########################################################################
# LINUX NFS IOSTAT
#########################################################################
if [ $nfs_collect = 1 ]; then

  if [ $hour != $lasthour ]; then
    echo $PLATFORM HGW $version  >> $HGW_ARCHIVE_DEST/HGWnfs/${hostn}_nfs_$hour
  fi

  if [ -f locks/nfslock.file ]; then
    nfsstatus=1
  else
    touch locks/nfslock.file
    if [ $nfsstatus = 1 ]; then
      cecho "***Warning. IOSTAT NFS response is spanning snapshot intervals." "yellow"
      nfsstatus=0
    fi
    ./nfssub.sh $HGW_ARCHIVE_DEST/HGWnfs/${hostn}_nfs_$hour "$NFSSTAT" $HGWCompliance &

  fi
fi

#########################################################################
# IFCONFIG
#########################################################################
if [ $IFCONFIGFOUND = 1 ]; then

if [ $ifconfig_collect = 1 ]; then

  if [ $hour != $lasthour ]; then 
    echo $PLATFORM HGW $version  >> $HGW_ARCHIVE_DEST/HGWifconfig/${hostn}_ifconfig_$hour
  fi

  if [ -f locks/ifconfiglock.file ]; then
    ifconfigstatus=1
  else
    touch locks/ifconfiglock.file
    if [ $ifconfigstatus = 1 ]; then
      cecho "***Warning. IFCONFIG response is spanning snapshot intervals." "yellow"
      ifconfigstatus=0
    fi
    ./ifconfigsub.sh $HGW_ARCHIVE_DEST/HGWifconfig/${hostn}_ifconfig_$hour "$IFCONFIG" $HGWCompliance &

  fi
fi
fi

#########################################################################
# TOP
#########################################################################
if [[ $TOPFOUND = 1 ]]; then
  if [ $hour != $lasthour ]; then
    echo $PLATFORM  HGW $version >> $HGW_ARCHIVE_DEST/HGWtop/${hostn}_top_$hour
  fi
  if [ -f locks/toplock.file ]; then
    topstatus=1
  else
    touch locks/toplock.file
    if [ $topstatus = 1 ]; then
      cecho "***Warning. TOP response is spanning snapshot intervals." "yellow"
      topstatus=0
    fi
    case $PLATFORM in
      Linux)
      ./xtop.sh $HGW_ARCHIVE_DEST/HGWtop/${hostn}_top_$hour $HGWCompliance &
      ;;
      *)
      ./xtop.sh $HGW_ARCHIVE_DEST/HGWtop/${hostn}_top_$hour $HGWCompliance $PRSTAT_FOUND &
    ;;
    esac
  fi
fi

#########################################################################
# PS -ELF
#########################################################################
  if [ $hour != $lasthour ]; then
    echo $PLATFORM  HGW $version >> $HGW_ARCHIVE_DEST/HGWps/${hostn}_ps_$hour
  fi

  if [ -f locks/pslock.file ]; then
    psstatus=1
  else
    touch locks/pslock.file
    if [ $psstatus = 1 ]; then
      cecho "***Warning. PS response is spanning snapshot intervals." "yellow"
      psstatus=0
    fi

    if [[ $PS_MULTIPLIER -gt $ZERO ]]; then

      if [ $PS_MULTIPLIER_COUNTER -eq $ZERO ]; then
          ./psmemsub.sh $HGW_ARCHIVE_DEST/HGWps/${hostn}_ps_$hour "$PSELF" $HGWCompliance &
      else
        rm locks/pslock.file
      fi
      PS_MULTIPLIER_COUNTER=`expr $PS_MULTIPLIER_COUNTER + 1`
      if [ $PS_MULTIPLIER_COUNTER -eq  $PS_MULTIPLIER ]; then
           PS_MULTIPLIER_COUNTER=0
      fi
    else
      ./psmemsub.sh $HGW_ARCHIVE_DEST/HGWps/${hostn}_ps_$hour "$PSELF" $HGWCompliance &
    fi
  fi
  
case $PLATFORM in
  Linux)
  if [ $MEMFOUND = 1 ]; then
    ./HGWsub.sh $HGW_ARCHIVE_DEST/HGWmeminfo/${hostn}_meminfo_$hour "$MEMINFO" $HGWCompliance &
  fi
  if [ $SLABFOUND = 1 ]; then
    ./HGWsub.sh $HGW_ARCHIVE_DEST/HGWslabinfo/${hostn}_slabinfo_$hour "$SLABINFO" $HGWCompliance &
  fi
  ;;
esac

#########################################################################
# 文件系统剩余空间、iNode
#########################################################################
./HGWsub.sh $HGW_ARCHIVE_DEST/HGWdfh/${hostn}_dfh_$hour "$DFH" $HGWCompliance &
./HGWsub.sh $HGW_ARCHIVE_DEST/HGWdfi/${hostn}_dfi_$hour "$DFI" $HGWCompliance &
#########################################################################
# 按指定时间运行
#########################################################################
  lasthour=$hour
  if [ x"$chk" == xtrue ];then
    check=1
    exit 1
  fi
sleep $snapshotInterval
done &


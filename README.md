# HGWatcher
## 简介
HGWatcher是一个定期收集HGDB、PostgreSQL及其所运行的操作系统的信息的工具，用以在数据库或操作系统出现问题时辅助判断问题原因。
## 功能
1.HGWatcher可以通过脚本收集服务器上有正在运行的HGDB、PostgreSQL数据库的安装目录、数据存放目录等信息。
2.HGWatcher定期使用操作系统命令及sql语句获取操作系统及数据库信息。
3.HGWatcher在数据库或操作系统出现问题时可以通过脚本获取当前操作系统及数据库的信息，并将HGWatcher记录的归档日志一并打包。
## 用法
1、收集当前运行数据的信息 
解压HGWatcher_V1.0.0.tar.gz，进入HGWatcher目录，首先执行getDBlist.sh，获取当前服务器中运行的数据库的信息。 
执行过程如下：
```shell
[root@pgha3 HGWatcher]# sh getDBlist.sh 
The current environment has a set of 3 databases.
To monitor all databases, you need to write all database information to the file dblist.cfg, and then use the -dblist option.
You can also read the database information through the current script and then modify it according to the actual situation.
Do you want to generate a database information list [Y/N]?y
​
Database benchmarksql did not install extended pg_stat_statements!
​
Database highgo did not install extended pg_stat_statements!
​
Database highgo did not install extended pg_stat_statements!
##########################################################################################
# The output file is /HGWatcher/data/dblist.cfg
##########################################################################################
```
采集数据库信息需要使用插件pg_stat_statements，需要提前在数据库中配置插件pg_stat_statements。 
执行结果放在HGWatcher目录下的data，名称为getDBlist.sh，内容如下：
```shell
[DATABASE1]
#psql的路径
PSQL=/usr/pgsql-10/bin/psql            
#PostgreSQL的安装路径
PGDATAPATH=/var/lib/pgsql/10/data      
#PostgreSQL使用的端口
PGPORT=5432                            
#当前数据库的IP，默认使用127.0.0.1，需要设置psql -h 127.0.0.1可以直接登录数据库
PGHOST=127.0.0.1 
#登录数据库的用户，需要使用数据库的超级用户                   
PGUSER=postgres
#数据库软件的安装或管理用户，如有误，需要手动修改。
OSUSER=postgres
#当前所有创建的数据库，如果获取到的数据库不需要监控，可以直接删除
PGDATABASE=postgres,benchmarksql
#数据库是否可以不使用密码直接登录，1表示可以，0表示不可以，需要配置数据库，使其在本地可以不使用密码直接登录
DirectAccess=1
[ENDDATABASE1]
```
2、定时收集系统信息 
确认dblist.cfg文件中信息与当前运行数据库信息相符后，执行HGWatcher.sh开始收集信息。HGWatcher.sh有以下几个选项：

-dblist：指定使用自定义的dblist.cfg
-OSsnapshot：指定采集操作系统信息的快照时间，单位秒，默认时间30秒
-DBsnapshot：指定采集数据库信息的快照时间，单位分钟，默认时间60分钟
-archtime ：指定归档存放时间，单位小时，默认时间168小时（一周）
-archpath ：指定归档存放的路径，默认路径HGWatcher/archive/
-help ：获取帮助信息
示例：
假如每20秒采集一次操作系统信息，每11分钟采集一次数据库信息，归档保存时间4小时，归档存放目录/tmp/archive。参数设置如下：
```shell
[root@pgha3 HGWatcher]# ./HGWatcher.sh -OSsnapshot 20 -DBsnapshot 11 -archtime 4 -archpath /tmp/archive
​
Testing for discovery of OS Utilities...
2018-09-29 09:07:59 VMSTAT found on your system.
2018-09-29 09:08:01 IOSTAT found on your system.
2018-09-29 09:08:01 IFCONFIG found on your system.
2018-09-29 09:08:03 MPSTAT found on your system.
2018-09-29 09:08:04 NETSTAT found on your system.
​
2018-09-29 09:08:04 Discovery of CPU CORE COUNT
2018-09-29 09:08:04 CPU CORE COUNT will be used by HGWatcher to automatically look for cpu problems
​
2018-09-29 09:08:04 CPU CORE COUNT =
2018-09-29 09:08:04 VCPUS/THREADS =
​
2018-09-29 09:08:04 Discovery completed.

2018-09-29 09:08:09 Starting HGWatcher v1.0.0
With OSsnapshotInterval = 20 #操作系统快照时间
With DBSnapshotInterval = 11m #数据库快照时间
With ArchiveInterval = 4h #归档保留时间
With ArchivePath = /tmp/archive #归档保存位置

HGWatcher - Written by zb,
Highgo Corporation
​
2018-09-29 09:08:14 Data is stored in directory: /tmp/archive

2018-09-29 09:08:14 Starting Data Collection...
```
3、收集收集归档文件 
进入到HGWatcher目录下，执行./getarch.sh，将停止当前运行的HGWatcher，重新运行一次HGWatcher，然后将7天内的数据库日志及日志归档目录一并打包压缩到当前目录。数据库日志会将保存到归档目录下的pg_log文件夹中，并建立以端口号命名的文件夹，例如某数据库使用端口为5866，将在pg_log下建立5866的文件夹，并将对应的数据库日志复制到5866文件夹下。
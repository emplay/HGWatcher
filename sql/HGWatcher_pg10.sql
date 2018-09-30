\pset footer
\T class="tablecss"
\t
--表格样式
select '<style>
caption{
         text-align:left;
     padding-bottom:10px;
         #background-color:#Cc6;
         font-size:1.2em;
         font-weight:bold;
         color:#326690;
}
.tablecss{
        width:50%;
        margin:15px 0
}
.tablecss th {
        background-color:#326690;
        color:#000000
}
.tablecss,.tablecss th,.tablecss td
{
        font-size:0.95em;
        text-align:left;
        padding:4px;
        border:1px solid #dddddd;
        border-collapse:collapse
}
.tablecss tr:nth-child(odd){
        background-color:#ccc;
}
</style>';
\t
\H
--数据库版本
\pset title 'Database version'
SELECT version();

--总连接数
\pset title 'The total number of connections'
select count(*) count_session from pg_stat_activity;  

--活动的会话数
\pset title 'Active session'
select count(*) count_active_session from pg_stat_activity where state='active';

--最近一小时内的连接数
\pset title 'The number of connections in the last hour'
select count(*) as count_connect from pg_stat_activity where now()-backend_start > '0 second' and now()-backend_start<'1 hour';

--已安装的扩展
\pset title 'Installed extensions'
select current_database(),* from pg_extension;

--当前数据库中使用的数据类型
\pset title 'The data type used in the database'
select current_database(),b.typname,count(*) from pg_attribute a,pg_type b where a.atttypid=b.oid and a.attrelid in (select oid from pg_class 
where relnamespace not in (select oid from pg_namespace where nspname ~ $$^pg_$$ or nspname=$$information_schema$$)) group by 1,2 order by 3 desc;

--数据库中创建的对象
\pset title 'Object created in the database'
select current_database(),rolname,nspname,relkind,count(*) from pg_class a,pg_authid b,pg_namespace c 
where a.relnamespace=c.oid and a.relowner=b.oid and nspname !~ $$^pg_$$ and nspname<>$$information_schema$$ group by 1,2,3,4 order by 5 desc;

--数据库中各个对象的大小
\pset title 'The size of the object in the database'
select current_database(),buk this_buk_no,cnt rels_in_this_buk,pg_size_pretty(min) buk_min,pg_size_pretty(max) buk_max 
from( select row_number() over (partition by buk order by tsize),tsize,buk,min(tsize) over (partition by buk),max(tsize) over (partition by buk),count(*) over (partition by buk) cnt 
from ( select pg_relation_size(a.oid) tsize, width_bucket(pg_relation_size(a.oid),tmin,tmax,10) buk 
from (select min(pg_relation_size(a.oid)) tmin,max(pg_relation_size(a.oid)) tmax 
from pg_class a,pg_namespace c where a.relnamespace=c.oid and nspname !~ $$^pg_$$ and nspname<>$$information_schema$$) t, pg_class a,pg_namespace c 
where a.relnamespace=c.oid and nspname !~ $$^pg_$$ and nspname<>$$information_schema$$ ) t)t where row_number=1;

--数据库中的自定义参数
\pset title 'Custom parameters in the database'
select * from pg_db_role_setting;

--每秒查询量，QPS
\pset title 'QPS(Query per second)'
with
a as (select sum(calls) s, sum(case when ltrim(query,' ') ~* '^select' then calls else 0 end) q from pg_stat_statements),
b as (select sum(calls) s, sum(case when ltrim(query,' ') ~* '^select' then calls else 0 end) q from pg_stat_statements , pg_sleep(1))
select
b.s-a.s as QPS,
b.q-a.q as QPS_read,
b.s-b.q-a.s+a.q  as QPS_write
from a,b;

--最近1小时内处理的行数，包括写入，读取，更新，删除等操作
\pset title 'Number of rows processed within the last 1 hour, including insert, select, update, delete.'
select sum(pg_stat_statements.rows) from pg_stat_statements;

--共享缓冲区
\pset title 'Share buffer information'
select shared_blks_hit,shared_blks_read,shared_blks_dirtied,shared_blks_written from pg_stat_statements;

--进程的缓冲去
\pset title 'Process buffer'
select local_blks_hit,local_blks_read,local_blks_dirtied,local_blks_written from pg_stat_statements;

--临时文件
\pset title 'Temporary file statistics'
select temp_blks_read,temp_blks_written from pg_stat_statements;

--读/写数据块耗时
\pset title 'Total time the statement spent reading/writing blocks, in milliseconds (if track_io_timing is enabled, otherwise zero)'
select blk_read_time,blk_write_time from pg_stat_statements;

--执行超过2分钟的sql语句
\pset title 'Long query'
select datname,usename,application_name,client_addr,query_start,backend_type,wait_event,wait_event_type from pg_stat_activity where state='active' and now()-query_start > interval '2 minute';

--系统中超过10分钟未结束的事务
\pset title 'long transaction'
select datname,usename,application_name,client_addr,xact_start,backend_type,wait_event,wait_event_type from pg_stat_activity where state='active' and now()-xact_start > interval '10 minute';

--空闲事务
\pset title 'idle in transaction'
select datname,usename,application_name,client_addr,xact_start,backend_type,wait_event,wait_event_type from pg_stat_activity where state='idle in transaction';

--有多少长期（超过10分钟）处于空闲的事务
\pset title 'long idle in transaction'
select datname,usename,application_name,client_addr,xact_start,backend_type,wait_event,wait_event_type,state_change from pg_stat_activity where state='idle in transaction' and now()-state_change > interval '10 minute';

--等待中的会话
\pset title 'waiting'
select datname,usename,application_name,client_addr,wait_event,wait_event_type,state from pg_stat_activity where wait_event_type is not null;

--等待超过5分钟的会话
\pset title 'long waiting'
select datname,usename,application_name,client_addr,wait_event,wait_event_type,state from pg_stat_activity where wait_event_type is not null and now()-state_change > interval '5 minute';

--2PC事务有多少，如果接近max_prepared_transactions，建议调大max_prepared_transactions，或者排查业务是否未及时提交。
\pset title 'The number 2 PC'
select count(*) count_2pc from pg_prepared_xacts;

\pset title 'More than 5 minutes of 2pc'
select * from pg_prepared_xacts where now() - prepared > interval '5 minute';

--autovacuum的状态
\pset title 'Autovacuum state'
select current_setting('autovacuum'); 

--关闭Autovacuum的表
\pset title 'The table that has closed Autovacuum'
select relname, pg_size_pretty(pg_total_relation_size(oid)) from pg_class where reloptions @> array['autovacuum_enabled=off'];

--查看系统中，多久以前的垃圾可以被回收
\pset title 'How long ago the garbage can be recycled'
with a as 
(select min(xact_start) m from pg_stat_activity where backend_xid is not null or backend_xmin is not null), b as (select min(prepared) m from pg_prepared_xacts) 
select now()-least(a.m,b.m) recycled_time from a,b;

--SQL部分
--单次调用最耗IO SQL TOP 10
\pset title 'SQL ordered by User I/O Wait Time'
select userid::regrole, dbid, query from pg_stat_statements order by (blk_read_time+blk_write_time)/calls desc limit 10;

--单次调用最耗时的SQL TOP 10
\pset title 'SQL ordered by Elapsed Time'
select userid::regrole, dbid, query from pg_stat_statements order by mean_time desc limit 10;

--总耗时
\pset title 'SQL ordered by total Elapsed Time'
select userid::regrole, dbid, query from pg_stat_statements order by total_time desc limit 10;

--响应时间抖动最严重 SQL TOP10，按标准差排序
\pset title 'SQL ordered by standard deviation'
select userid::regrole, dbid, query from pg_stat_statements order by stddev_time desc limit 10;

--最耗共享内存 SQL TOP10
\pset title 'SQL ordered by Sharable Memory'
select userid::regrole, dbid, query from pg_stat_statements order by (shared_blks_hit+shared_blks_dirtied) desc limit 10;

--最耗临时空间 SQL TOP10
\pset title 'SQL ordered by Temporary tablespace'
select userid::regrole, dbid, query from pg_stat_statements order by temp_blks_written desc limit 10; 

--需要清理的dead tuple
\pset title 'Dead tuples that need to be recycled'
select current_database(),schemaname,relname,n_dead_tup from pg_stat_all_tables 
where n_live_tup>0 and n_dead_tup/n_live_tup>0.2 and schemaname not in ($$pg_toast$$,$$pg_catalog$$) order by n_dead_tup desc limit 5;

--未引用的大对象
\pset title 'Large objects that are not referenced'
select datname from pg_database where datname not in ($$template0$$, $$template1$$);

--归档信息
\pset title 'The archive information'
select pg_walfile_name(pg_current_wal_lsn()) now_xlog, * from pg_stat_archiver;

--流复制延迟查询
\pset title 'The stream the delay information'
select pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), sent_lsn)) as sent_delay,   
pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), write_lsn)) as write_delay,   
pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), flush_lsn)) as flush_delay,   
pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn)) as replay_delay
from pg_stat_replication; 

--SLOT延迟
\pset title 'SLOT delay';
select slot_name,plugin,slot_type,database,active,                       
xmin,catalog_xmin,  
pg_wal_lsn_diff(pg_current_wal_insert_lsn(),restart_lsn) restart_delay   
from pg_replication_slots; 

--用户密码到期时间
\pset title 'User password expiration time'
select rolname,rolvaliduntil from pg_authid order by rolvaliduntil;

--查询数据库中的锁
\pset title 'Locks in database'
with    
t_wait as    
(    
  select a.mode,a.locktype,a.database,a.relation,a.page,a.tuple,a.classid,a.granted,   
  a.objid,a.objsubid,a.pid,a.virtualtransaction,a.virtualxid,a.transactionid,a.fastpath,    
  b.state,b.query,b.xact_start,b.query_start,b.usename,b.datname,b.client_addr,b.client_port,b.application_name   
    from pg_locks a,pg_stat_activity b where a.pid=b.pid and not a.granted   
),   
t_run as   
(   
  select a.mode,a.locktype,a.database,a.relation,a.page,a.tuple,a.classid,a.granted,   
  a.objid,a.objsubid,a.pid,a.virtualtransaction,a.virtualxid,a.transactionid,a.fastpath,   
  b.state,b.query,b.xact_start,b.query_start,b.usename,b.datname,b.client_addr,b.client_port,b.application_name   
    from pg_locks a,pg_stat_activity b where a.pid=b.pid and a.granted   
),   
t_overlap as   
(   
  select r.* from t_wait w join t_run r on   
  (   
    r.locktype is not distinct from w.locktype and   
    r.database is not distinct from w.database and   
    r.relation is not distinct from w.relation and   
    r.page is not distinct from w.page and   
    r.tuple is not distinct from w.tuple and   
    r.virtualxid is not distinct from w.virtualxid and   
    r.transactionid is not distinct from w.transactionid and   
    r.classid is not distinct from w.classid and   
    r.objid is not distinct from w.objid and   
    r.objsubid is not distinct from w.objsubid and   
    r.pid <> w.pid   
  )    
),    
t_unionall as    
(    
  select r.* from t_overlap r    
  union all    
  select w.* from t_wait w    
)    
select locktype,datname,relation::regclass,page,tuple,virtualxid,transactionid::text,classid::regclass,objid,objsubid,   
string_agg(   
'Pid: '||case when pid is null then 'NULL' else pid::text end||chr(10)||   
'Lock_Granted: '||case when granted is null then 'NULL' else granted::text end||' , Mode: '||case when mode is null then 'NULL' else mode::text end||' , FastPath: '||case when fastpath is null then 'NULL' else fastpath::text end||' , VirtualTransaction: '||case when virtualtransaction is null then 'NULL' else virtualtransaction::text end||' , Session_State: '||case when state is null then 'NULL' else state::text end||chr(10)||   
'Username: '||case when usename is null then 'NULL' else usename::text end||' , Database: '||case when datname is null then 'NULL' else datname::text end||' , Client_Addr: '||case when client_addr is null then 'NULL' else client_addr::text end||' , Client_Port: '||case when client_port is null then 'NULL' else client_port::text end||' , Application_Name: '||case when application_name is null then 'NULL' else application_name::text end||chr(10)||    
'Xact_Start: '||case when xact_start is null then 'NULL' else xact_start::text end||' , Query_Start: '||case when query_start is null then 'NULL' else query_start::text end||' , Xact_Elapse: '||case when (now()-xact_start) is null then 'NULL' else (now()-xact_start)::text end||' , Query_Elapse: '||case when (now()-query_start) is null then 'NULL' else (now()-query_start)::text end||chr(10)||    
'SQL (Current SQL in Transaction): '||chr(10)||  
case when query is null then 'NULL' else query::text end,    
chr(10)||'--------'||chr(10)    
order by    
  (  case mode    
    when 'INVALID' then 0   
    when 'AccessShareLock' then 1   
    when 'RowShareLock' then 2   
    when 'RowExclusiveLock' then 3   
    when 'ShareUpdateExclusiveLock' then 4   
    when 'ShareLock' then 5   
    when 'ShareRowExclusiveLock' then 6   
    when 'ExclusiveLock' then 7   
    when 'AccessExclusiveLock' then 8   
    else 0   
  end  ) desc,   
  (case when granted then 0 else 1 end)  
) as lock_conflict  
from t_unionall   
group by   
locktype,datname,relation,page,tuple,virtualxid,transactionid::text,classid,objid,objsubid;

--锁等待
\pset title 'Lock wait'
with t_wait as                     
(select a.mode,a.locktype,a.database,a.relation,a.page,a.tuple,a.classid,a.objid,a.objsubid,a.pid,a.virtualtransaction,a.virtualxid,a,transactionid,b.query,b.xact_start,b.query_start,b.usename,b.datname from pg_locks a,pg_stat_activity b where a.pid=b.pid and not a.granted),
t_run as 
(select a.mode,a.locktype,a.database,a.relation,a.page,a.tuple,a.classid,a.objid,a.objsubid,a.pid,a.virtualtransaction,a.virtualxid,a,transactionid,b.query,b.xact_start,b.query_start,b.usename,b.datname from pg_locks a,pg_stat_activity b where a.pid=b.pid and a.granted) 
select r.locktype,r.mode r_mode,r.usename r_user,r.datname r_db,r.relation::regclass,r.pid r_pid,r.xact_start r_xact_start,r.query_start r_query_start,now()-r.query_start r_locktime,r.query r_query,
w.mode w_mode,w.pid w_pid,w.xact_start w_xact_start,w.query_start w_query_start,now()-w.query_start w_locktime,w.query w_query  
from t_wait w,t_run r where
  r.locktype is not distinct from w.locktype and
  r.database is not distinct from w.database and
  r.relation is not distinct from w.relation and
  r.page is not distinct from w.page and
  r.tuple is not distinct from w.tuple and
  r.classid is not distinct from w.classid and
  r.objid is not distinct from w.objid and
  r.objsubid is not distinct from w.objsubid and
  r.transactionid is not distinct from w.transactionid and
  r.pid <> w.pid;

--表膨胀
\pset title 'Table expansion check'
SELECT    
  current_database() AS db, schemaname, tablename, reltuples::bigint AS tups, relpages::bigint AS pages, otta,    
  ROUND(CASE WHEN otta=0 OR sml.relpages=0 OR sml.relpages=otta THEN 0.0 ELSE sml.relpages/otta::numeric END,1) AS tbloat,    
  CASE WHEN relpages < otta THEN 0 ELSE relpages::bigint - otta END AS wastedpages,    
  CASE WHEN relpages < otta THEN 0 ELSE bs*(sml.relpages-otta)::bigint END AS wastedbytes,    
  CASE WHEN relpages < otta THEN $$0 bytes$$::text ELSE (bs*(relpages-otta))::bigint || $$ bytes$$ END AS wastedsize,    
  iname, ituples::bigint AS itups, ipages::bigint AS ipages, iotta,    
  ROUND(CASE WHEN iotta=0 OR ipages=0 OR ipages=iotta THEN 0.0 ELSE ipages/iotta::numeric END,1) AS ibloat,    
  CASE WHEN ipages < iotta THEN 0 ELSE ipages::bigint - iotta END AS wastedipages,    
  CASE WHEN ipages < iotta THEN 0 ELSE bs*(ipages-iotta) END AS wastedibytes,    
  CASE WHEN ipages < iotta THEN $$0 bytes$$ ELSE (bs*(ipages-iotta))::bigint || $$ bytes$$ END AS wastedisize,    
  CASE WHEN relpages < otta THEN    
    CASE WHEN ipages < iotta THEN 0 ELSE bs*(ipages-iotta::bigint) END    
    ELSE CASE WHEN ipages < iotta THEN bs*(relpages-otta::bigint)    
      ELSE bs*(relpages-otta::bigint + ipages-iotta::bigint) END    
  END AS totalwastedbytes    
FROM (    
  SELECT    
    nn.nspname AS schemaname,    
    cc.relname AS tablename,    
    COALESCE(cc.reltuples,0) AS reltuples,    
    COALESCE(cc.relpages,0) AS relpages,    
    COALESCE(bs,0) AS bs,    
    COALESCE(CEIL((cc.reltuples*((datahdr+ma-    
      (CASE WHEN datahdr%ma=0 THEN ma ELSE datahdr%ma END))+nullhdr2+4))/(bs-20::float)),0) AS otta,    
    COALESCE(c2.relname,$$?$$) AS iname, COALESCE(c2.reltuples,0) AS ituples, COALESCE(c2.relpages,0) AS ipages,    
    COALESCE(CEIL((c2.reltuples*(datahdr-12))/(bs-20::float)),0) AS iotta -- very rough approximation, assumes all cols    
  FROM    
     pg_class cc    
  JOIN pg_namespace nn ON cc.relnamespace = nn.oid AND nn.nspname <> $$information_schema$$    
  LEFT JOIN    
  (    
    SELECT    
      ma,bs,foo.nspname,foo.relname,    
      (datawidth+(hdr+ma-(case when hdr%ma=0 THEN ma ELSE hdr%ma END)))::numeric AS datahdr,    
      (maxfracsum*(nullhdr+ma-(case when nullhdr%ma=0 THEN ma ELSE nullhdr%ma END))) AS nullhdr2    
    FROM (    
      SELECT    
        ns.nspname, tbl.relname, hdr, ma, bs,    
        SUM((1-coalesce(null_frac,0))*coalesce(avg_width, 2048)) AS datawidth,    
        MAX(coalesce(null_frac,0)) AS maxfracsum,    
        hdr+(    
          SELECT 1+count(*)/8    
          FROM pg_stats s2    
          WHERE null_frac<>0 AND s2.schemaname = ns.nspname AND s2.tablename = tbl.relname    
        ) AS nullhdr    
      FROM pg_attribute att     
      JOIN pg_class tbl ON att.attrelid = tbl.oid    
      JOIN pg_namespace ns ON ns.oid = tbl.relnamespace     
      LEFT JOIN pg_stats s ON s.schemaname=ns.nspname    
      AND s.tablename = tbl.relname    
      AND s.inherited=false    
      AND s.attname=att.attname,    
      (    
        SELECT    
          (SELECT current_setting($$block_size$$)::numeric) AS bs,    
            CASE WHEN SUBSTRING(SPLIT_PART(v, $$ $$, 2) FROM $$#"[0-9]+.[0-9]+#"%$$ for $$#$$)    
              IN ($$8.0$$,$$8.1$$,$$8.2$$) THEN 27 ELSE 23 END AS hdr,    
          CASE WHEN v ~ $$mingw32$$ OR v ~ $$64-bit$$ THEN 8 ELSE 4 END AS ma    
        FROM (SELECT version() AS v) AS foo    
      ) AS constants    
      WHERE att.attnum > 0 AND tbl.relkind=$$r$$    
      GROUP BY 1,2,3,4,5    
    ) AS foo    
  ) AS rs    
  ON cc.relname = rs.relname AND nn.nspname = rs.nspname    
  LEFT JOIN pg_index i ON indrelid = cc.oid    
  LEFT JOIN pg_class c2 ON c2.oid = i.indexrelid    
) AS sml order by wastedbytes desc limit 5;

--索引膨胀检查
\pset title 'Index expansion check'
SELECT
  current_database() AS db, schemaname, tablename, reltuples::bigint AS tups, relpages::bigint AS pages, otta,
  ROUND(CASE WHEN otta=0 OR sml.relpages=0 OR sml.relpages=otta THEN 0.0 ELSE sml.relpages/otta::numeric END,1) AS tbloat,
  CASE WHEN relpages < otta THEN 0 ELSE relpages::bigint - otta END AS wastedpages,
  CASE WHEN relpages < otta THEN 0 ELSE bs*(sml.relpages-otta)::bigint END AS wastedbytes,
  CASE WHEN relpages < otta THEN 
$$
0 bytes
$$
::text ELSE (bs*(relpages-otta))::bigint || 
$$
 bytes
$$
 END AS wastedsize,
  iname, ituples::bigint AS itups, ipages::bigint AS ipages, iotta,
  ROUND(CASE WHEN iotta=0 OR ipages=0 OR ipages=iotta THEN 0.0 ELSE ipages/iotta::numeric END,1) AS ibloat,
  CASE WHEN ipages < iotta THEN 0 ELSE ipages::bigint - iotta END AS wastedipages,
  CASE WHEN ipages < iotta THEN 0 ELSE bs*(ipages-iotta) END AS wastedibytes,
  CASE WHEN ipages < iotta THEN 
$$
0 bytes
$$
 ELSE (bs*(ipages-iotta))::bigint || 
$$
 bytes
$$
 END AS wastedisize,
  CASE WHEN relpages < otta THEN
    CASE WHEN ipages < iotta THEN 0 ELSE bs*(ipages-iotta::bigint) END
    ELSE CASE WHEN ipages < iotta THEN bs*(relpages-otta::bigint)
      ELSE bs*(relpages-otta::bigint + ipages-iotta::bigint) END
  END AS totalwastedbytes
FROM (
  SELECT
    nn.nspname AS schemaname,
    cc.relname AS tablename,
    COALESCE(cc.reltuples,0) AS reltuples,
    COALESCE(cc.relpages,0) AS relpages,
    COALESCE(bs,0) AS bs,
    COALESCE(CEIL((cc.reltuples*((datahdr+ma-
      (CASE WHEN datahdr%ma=0 THEN ma ELSE datahdr%ma END))+nullhdr2+4))/(bs-20::float)),0) AS otta,
    COALESCE(c2.relname,
$$
?
$$
) AS iname, COALESCE(c2.reltuples,0) AS ituples, COALESCE(c2.relpages,0) AS ipages,
    COALESCE(CEIL((c2.reltuples*(datahdr-12))/(bs-20::float)),0) AS iotta -- very rough approximation, assumes all cols
  FROM
     pg_class cc
  JOIN pg_namespace nn ON cc.relnamespace = nn.oid AND nn.nspname <> 
$$
information_schema
$$

  LEFT JOIN
  (
    SELECT
      ma,bs,foo.nspname,foo.relname,
      (datawidth+(hdr+ma-(case when hdr%ma=0 THEN ma ELSE hdr%ma END)))::numeric AS datahdr,
      (maxfracsum*(nullhdr+ma-(case when nullhdr%ma=0 THEN ma ELSE nullhdr%ma END))) AS nullhdr2
    FROM (
      SELECT
        ns.nspname, tbl.relname, hdr, ma, bs,
        SUM((1-coalesce(null_frac,0))*coalesce(avg_width, 2048)) AS datawidth,
        MAX(coalesce(null_frac,0)) AS maxfracsum,
        hdr+(
          SELECT 1+count(*)/8
          FROM pg_stats s2
          WHERE null_frac<>0 AND s2.schemaname = ns.nspname AND s2.tablename = tbl.relname
        ) AS nullhdr
      FROM pg_attribute att 
      JOIN pg_class tbl ON att.attrelid = tbl.oid
      JOIN pg_namespace ns ON ns.oid = tbl.relnamespace 
      LEFT JOIN pg_stats s ON s.schemaname=ns.nspname
      AND s.tablename = tbl.relname
      AND s.inherited=false
      AND s.attname=att.attname,
      (
        SELECT
          (SELECT current_setting(
$$
block_size
$$
)::numeric) AS bs,
            CASE WHEN SUBSTRING(SPLIT_PART(v, 
$$
 
$$
, 2) FROM 
$$
#"[0-9]+.[0-9]+#"%
$$
 for 
$$
#
$$
)
              IN (
$$
8.0
$$
,
$$
8.1
$$
,
$$
8.2
$$
) THEN 27 ELSE 23 END AS hdr,
          CASE WHEN v ~ 
$$
mingw32
$$
 OR v ~ 
$$
64-bit
$$
 THEN 8 ELSE 4 END AS ma
        FROM (SELECT version() AS v) AS foo
      ) AS constants
      WHERE att.attnum > 0 AND tbl.relkind=
$$
r
$$
      GROUP BY 1,2,3,4,5
    ) AS foo
  ) AS rs
  ON cc.relname = rs.relname AND nn.nspname = rs.nspname
  LEFT JOIN pg_index i ON indrelid = cc.oid
  LEFT JOIN pg_class c2 ON c2.oid = i.indexrelid
) AS sml order by wastedbytes desc limit 5;

\pset title 'Pg_stat_statements information'
SELECT 
CASE 
count(*)
  WHEN 0 THEN
  'pg_stat_statements were not installed.' ELSE 'pg_stat_statements has benn installed.'
END 
FROM
  pg_catalog.pg_extension e
  LEFT JOIN pg_catalog.pg_namespace n ON n.oid = e.extnamespace
  LEFT JOIN pg_catalog.pg_description C ON C.objoid = e.oid 
  AND C.classoid = 'pg_catalog.pg_extension' :: pg_catalog.regclass 
WHERE e.extname = 'pg_stat_statements';
\t
SELECT pg_stat_statements_reset();
\t

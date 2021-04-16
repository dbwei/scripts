#!/bin/bash
<<!
**********************************************************
* Author        : lihaimao
* Email         : haimao_li@163.com
* Last modified : 2021-04-06 09:30
* Filename      : get_locks
* Description   :
* *******************************************************
!
user=lhm
pass='123456'
host=192.168.124.8
port=3306
logdir=/tmp/tdsql
CONN="mysql -u$user -p$pass -h$host -P$port"
count=0
$CONN -Bse "UPDATE performance_schema.setup_instruments SET ENABLED = 'YES', TIMED = 'YES' WHERE NAME = 'wait/lock/metadata/sql/mdl';"
while [ $count -lt 200 ]; do
locks=$(mysql -u$user -p$pass -h$host -P$port -Bse "show global status like 'Innodb_row_lock_current_waits';" | awk '{print $2}')
echo $locks
if [ $locks = 0 ]
then
echo -e "$(date +%F' '%T)\n" >> $logdir/lock.log
$CONN -Bse "select CONCAT('thread ', b.trx_mysql_thread_id, ' from ', p.host) AS who_blocks , r.trx_id waiting_trx_id , r.trx_mysql_thread_id waiting_thread , r.trx_query waiting_query , b.trx_id blocking_trx_id , b.trx_mysql_thread_id block_thread , b.trx_query blocking_query from information_schema.innodb_lock_waits w inner join information_schema.innodb_trx b on b.trx_id = w.blocking_trx_id inner join information_schema.innodb_trx r on r.trx_id = w.requesting_trx_id left join information_schema.processlist p on p.id = b.trx_mysql_thread_id;" >> $logdir/lock.log
echo -e "$(date +%F' '%T)\n" >> $logdir/innodbstatus.log
$CONN -Bse "show engine innodb status\G" >> $logdir/innodbstatus.log
echo -e "$(date +%F' '%T)\n" >> $logdir/metadatalocks.log
$CONN -Bse "SELECT performance_schema.threads.PROCESSLIST_ID, performance_schema.metadata_locks.* FROM performance_schema.threads, performance_schema.metadata_locks WHERE performance_schema.threads.THREAD_ID = performance_schema.metadata_locks.OWNER_THREAD_ID;" >> $logdir/metadatalocks.log
echo -e "$(date +%F' '%T)\n" >> $logdir/processlist.log
$CONN -Bse "select * from information_schema.processlist\G" >> $logdir/processlist.log
sleep 3;
fi
let count=$count+1
done
$CONN -Bse "UPDATE performance_schema.setup_instruments SET ENABLED = 'NO', TIMED = 'NO' WHERE NAME = 'wait/lock/metadata/sql/mdl';"
exit

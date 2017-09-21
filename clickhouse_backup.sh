S3CFG="/etc/s3cfg"
BACKUP_PATH="/var/lib/clickhouse/backup"
SERVER=127.0.0.1
RUN_QUERY="clickhouse-client  -h $SERVER --query "
DATEFIX=$(date +"%H%M-%d%m%Y")
HOSTNAME=$(hostname)
S3BIN="s3cmd -c $S3CFG "
DEBUG=1 #set 1 for debug messages

function log {
   MSG=$1
   if [ $# -eq 2 ]; then
      SEVERITY=$2
      $(printf "$MSG" | systemd-cat -t BACKUP -p $2) || echo "Send to system log failed!";
   fi
   if [ $DEBUG = 1 ]; then
      echo $MSG;
   fi    
}

for DB in $($RUN_QUERY 'show databases' | grep -v -E 'system|default'); do
   log " Database $DB found"
   mkdir -p $BACKUP_PATH
   for TABLE in $($RUN_QUERY 'show tables' -d $DB); do
     log "Create metadata dump for $DB.$TABLE..."
     $($RUN_QUERY "SHOW CREATE TABLE $TABLE" -d $DB --format=TabSeparatedRaw > $BACKUP_PATH/$DB.$TABLE.meta.sql) || log "Fail meta data dump for $DB.$TABLE" err
     log "Create data dump for $DB.$TABLE..."
     $($RUN_QUERY "SELECT * FROM $TABLE FORMAT Native" -d $DB --format=TabSeparatedRaw > $BACKUP_PATH/$DB.$TABLE.data.sql) || log "Fail data dump for $DB.$TABLE" err
   done
   log "Packing dumps..."
   tar -cvzf $BACKUP_PATH/clickhouse-$DB-$DATEFIX.tar.gz $BACKUP_PATH/*  -C $BACKUP_PATH 
   if [ ! -f $S3CFG ]; then
      log "Config file for s3cmd not found!" err
      exit 1;
   fi   
   echo "Copying backup copies to..."
   if !  $($S3BIN ls | grep -q backup-$HOSTNAME); then
      log "Bucket not found. Creating..."
      $S3BIN mb s3://backup-$HOSTNAME || $(log "Cannot create bucket!" err; exit 1)
   fi   
   log "Copying file to s3..."
   $S3BIN put $BACKUP_PATH/clickhouse-$DB-$DATEFIX.tar.gz s3://backup-$HOSTNAME/clickhouse-$DB-$DATEFIX.tar.gz || $(log "Cant upload file to s3" err; exit 1)
   cp $BACKUP_PATH/clickhouse-$DB-$DATEFIX.tar.gz /home/dnagovitsin && rm $BACKUP_PATH -rf
   rm -rf $BACKUP_PATH
   log "Clickhouse backup for $DB completed" info
done



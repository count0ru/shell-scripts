SOURCESERVER=$1
DATABASE=$2
REPLUSER=$3
REPLPASS=$4
CHANNEL=$5
NOTIFY=$6

DUMP_DIR="/data/dumps"
DATEFIX=$(date +"%H%M-%d%m%Y")
DUMP_OPTS="--single-transaction --triggers --routines --events --add-drop-database " 
if [ $NOTIFY = "sms" ]; then
        NOTIFY_SCRIPT=""
        NOTIFY_PHONE=""
fi
echo "$(date +"%T") Dumping $DATABASE from $SOURCESERVER";
mysqldump --defaults-file="$DATABASE.cnf" -h$SOURCESERVER $DUMP_OPTS $DATABASE  > $DUMP_DIR/$DATABASE-$DATEFIX.sql  &&   if [ $NOTIFY = "sms" ]; then $NOTIFY_SCRIPT $NOTIFY_PHONE "$DATABASE dump complete" ; fi
echo "$(date +"%T") Dump complete. Try to restore...";
bash <<EOF
	mysql -e "stop slave for channel '$CHANNEL'; reset master;"
EOF

mysql $DATABASE <  $DUMP_DIR/$DATABASE-$DATEFIX.sql &&  if [ $NOTIFY = "sms" ]; then $NOTIFY_SCRIPT $NOTIFY_PHONE "$DATABASE dump restore complete"; fi
echo "$(date +"%T") Restore complete";
echo "$(date +"%T") Try to setting up replication";
bash <<EOF
       mysql -e "CHANGE MASTER TO MASTER_HOST='${SOURCESERVER}', MASTER_USER='${REPLUSER}', MASTER_PASSWORD='${REPLPASS}', master_auto_position=1 for channel '${CHANNEL}';"
       mysql -e "START SLAVE FOR CHANNEL '${CHANNEL}';"
EOF

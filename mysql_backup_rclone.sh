BACKUP_DIR=/tmp/mysql_backup_tmp
DATE_FIX=$(date +"%H%M-%d%m%Y")
ARCH_NAME=myproject

RCLONE_SETTINGS_FILE_PATH=/home/user/rclone.conf
RCLONE_TARGET_CONTAINER=mysproject-backup
RCLONE_TARGET_ACCOUNT=myCDN

RCLONE_BIN=/usr/local/bin/rclone
MYSQLDUMP_BIN=/usr/bin/mysqldump

mkdir -p $BACKUP_DIR

for DB_NAME in $(echo $(mysql -e 'show databases;' | sed -E 's/(Database|^.+_schema)//g'));
do
   echo "Trying to backup $DB_NAME in $BACKUP_DIR/$DB_NAME-$DATE_FIX.sql";
   ( $MYSQLDUMP_BIN $DB_NAME > $BACKUP_DIR/$DB_NAME-$DATE_FIX.sql ) || echo "Failed";
   echo "Done";
done

cd $BACKUP_DIR

echo "Packing.."
tar -cvzf $ARCH_NAME-$DATE_FIX.tar.gz *.sql --absolute-names --remove-files

echo "Upload to storage..."
$RCLONE_BIN --config $RCLONE_SETTINGS_FILE_PATH copy $ARCH_NAME-$DATE_FIX.tar.gz  $RCLONE_TARGET_ACCOUNT:$RCLONE_TARGET_CONTAINER -v

echo "Cleanup local acrhive..."
rm  $BACKUP_DIR/*


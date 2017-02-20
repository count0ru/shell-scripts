DATABASE=$1
SOURCESERVER=$2
DSTDIR=$3
TARGETSERVER=$4

PASSWORD=mypassword
USER=deployuser

DATEFIX=$(date +"%H%M-%d%m%Y")
MYSQLDIR=/var/lib/mysql

#Создаем директорию для импортируемых данных, структуры, списка таблиц
mkdir -p $DSTDIR/$DATABASE/$DATABASE-$DATEFIX

#Создаем список таблиц (на удаленном сервере и локальном), который понадобится для бекапа и импорта
ssh $SOURCESERVER "mysql -e 'use $DATABASE; show tables;' | sed -e '1d'  | sed "s/^/$DATABASE./g" | tee /tmp/$DATABASE-$DATEFIX.tableslist"  > $DSTDIR/$DATABASE/$DATABASE-$DATEFIX/$DATABASE-$DATEFIX.tableslist

#Создаем дамп стуктуры БД
ssh $SOURCESERVER "mysqldump --set-gtid-purged=OFF --no-data $DATABASE " > $DSTDIR/$DATABASE/$DATABASE-$DATEFIX/$DATABASE-struct-$DATEFIX.sql

#Делаем бекап по списку таблиц, созданному ранее и заливаем сразу на целевой сервер по SSH, затем чистим за собой список таблиц на локальном сервере
ssh -T $SOURCESERVER <<EOF
        innobackupex --host=localhost --user=$USER --password=$PASSWORD --no-lock --tables-file=/tmp/$DATABASE-$DATEFIX.tableslist --stream=tar /tmp |  ssh $TARGETSERVER "cat - > $DSTDIR/$DATABASE/$DATABASE-$DATEFIX/$DATABASE-$DATEFIX.tar"
        rm /tmp/$DATABASE-$DATEFIX.tableslist
EOF

#Распаковываем залитый по SSH архив и удаляем его
tar xvf $DSTDIR/$DATABASE/$DATABASE-$DATEFIX/$DATABASE-$DATEFIX.tar -C $DSTDIR/$DATABASE/$DATABASE-$DATEFIX
rm $DSTDIR/$DATABASE/$DATABASE-$DATEFIX/$DATABASE-$DATEFIX.tar

#Подготавливаем таблицы к импорту
innobackupex --apply-log --export --parallel=8 $DSTDIR/$DATABASE/$DATABASE-$DATEFIX

#Создаем пустую базу данных со структурой, сохраненной ранее
if [ -d "$MYSQLDIR/$DATABASE" ]; then
        mysql -e "drop database $DATABASE;"
        rm -rf $MYSQLDIR/$DATABASE;
fi
mysql -e "create database $DATABASE;" &&
mysql $DATABASE < $DSTDIR/$DATABASE/$DATABASE-$DATEFIX/$DATABASE-struct-$DATEFIX.sql
sleep 3

#Импортируем таблицы по списку в нашу БД
for TABLENAME in $(cat $DSTDIR/$DATABASE/$DATABASE-$DATEFIX/$DATABASE-$DATEFIX.tableslist)
do
        mysql -e "ALTER TABLE $TABLENAME DISCARD TABLESPACE";
done

cp $DSTDIR/$DATABASE/$DATABASE-$DATEFIX/* $MYSQLDIR/$DATABASE &&
chown mysql:mysql $MYSQLDIR/$DATABASE/*
sleep 3

for TABLENAME in $(cat $DSTDIR/$DATABASE/$DATABASE-$DATEFIX/$DATABASE-$DATEFIX.tableslist)
do
        mysql -e "ALTER TABLE $TABLENAME import TABLESPACE;"
done

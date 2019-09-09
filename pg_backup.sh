#!/bin/sh

DATE=$(date)
DATE_STR=$(date +"%Y%m%d_%H%M%S")
export PGPASSFILE=/opt/pg_backups/pgpass
PG_HOME=/usr/bin
BACKUP_DIR=/opt/pg_backups

#Starting Backup Execution

#Rollup Log file
MaxFileSize=10240
file_size=`du -b $BACKUP_DIR/db_backup_info.log | tr -s '\t' ' ' | cut -d' ' -f1`
    if [ $file_size -gt $MaxFileSize ];then
        timestamp=`date +%s`
        mv $BACKUP_DIR/db_backup_info.log $BACKUP_DIR/db_backup_info."$timestamp".log
        find $BACKUP_DIR -type f -name 'db_backup_info.*.log' -mtime +30 -prune -exec rm -r {} \;
        touch $BACKUP_DIR/db_backup_info.log
    fi

#DELELTE OLD BACKUPS
find $BACKUP_DIR -type d -mtime +14 -prune -exec rm -r {} \;

pushd $BACKUP_DIR > /dev/null
mkdir $BACKUP_DIR/$DATE_STR
BACKUP_DIR_TS=$BACKUP_DIR/$DATE_STR

echo "" >> $BACKUP_DIR/db_backup_info.log
echo $DATE >> $BACKUP_DIR/db_backup_info.log
stars=$(printf '%*s'  $(echo "${#DATE}") '')
echo "${stars// /*}" >> $BACKUP_DIR/db_backup_info.log

dbs=$($PG_HOME/psql -Upostgres -lt | cut -d \| -f 1 | grep -v template | grep -v -e '^\s*$' | sed -e 's/  *$//'|  tr '\n' ' ')
echo "Will backup: $dbs to $BACKUP_DIR_TS" >> $BACKUP_DIR/db_backup_info.log
echo "" >> $BACKUP_DIR/db_backup_info.log

for db in $dbs; do
  header="Starting backup for "$db
  echo $header >> $BACKUP_DIR/db_backup_info.log
  db_header=$(printf '%*s'  $(echo "${#header}") '')
  echo "${db_header// /*}" >> $BACKUP_DIR/db_backup_info.log

  filename_sql=$db.$DATE_STR.sql
  filename_tar=$db.$DATE_STR.tar
  $PG_HOME/vacuumdb --analyze -Upostgres $db >> $BACKUP_DIR/db_backup_info.log
  $PG_HOME/pg_dump -Upostgres -v $db -F p > $BACKUP_DIR_TS/$filename_sql 2>> $BACKUP_DIR/db_backup_info.log
  $PG_HOME/pg_dump -Upostgres -v $db -F t > $BACKUP_DIR_TS/$filename_tar 2>> $BACKUP_DIR/db_backup_info.log
  echo "" >> $BACKUP_DIR/db_backup_info.log
done

  global_header="Backing up global objects"
  echo $global_header >> $BACKUP_DIR/db_backup_info.log
  global_db_header=$(printf '%*s'  $(echo "${#global_header}") '')
  echo "${global_db_header// /*}" >> $BACKUP_DIR/db_backup_info.log
  global_filename=global.$DATE_STR.sql
  $PGPASSWORD $PG_HOME/pg_dumpall -Upostgres -v -g > $BACKUP_DIR_TS/$global_filename 2>> $BACKUP_DIR/db_backup_info.log

echo "" >> $BACKUP_DIR/db_backup_info.log
echo "!!!Backup Script Execution Completed!!!" >> $BACKUP_DIR/db_backup_info.log

popd > /dev/null

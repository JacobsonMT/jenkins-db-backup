#!/usr/bin/env bash

# Environment Variable Prerequisites
#
# DB                Which database to backup
# 
# DB_HOST           Which host is this database located
#
# BACKUP_DIR        Directory to store symlinks to the current backup
#
# ARCHIVE_DIR       Directory to store all recent backup files (archives)
#
# DB_USER           User with privileges to backup given database
#
# DB_PASS           Password associated with given DB_USER
#
# MYSQLDUMP_OPTIONS Options to use in the mysqldump command, defaults to
#                   "--single-transaction -v --quick --compress"
#
# ROLLOVER_DAYS     Number of days to keep archived backups, defaults to
#                   30
#
# MIN_ARCHIVES      Minimum number of archives to keep regardless of age, 
#                   defaults to 4
#
# PROJECT           Project name used for current backup, defaults to $DB

: ${DB?Please specify a database.}
: ${DB_HOST?Please specify a database host.}
: ${BACKUP_DIR?Please specify a backup directory.}
: ${ARCHIVE_DIR?Please specify an archive directory.}
: ${DB_USER?Please specify database user.}
: ${DB_PASS?Please specify a database password.}

if [ -z "$ROLLOVER_DAYS" ]; then 
    ROLLOVER_DAYS="30"
    echo "ROLLOVER_DAYS defaulted to '$ROLLOVER_DAYS'"
fi

if [ -z "$MIN_ARCHIVES" ]; then 
    MIN_ARCHIVES="4"
    echo "MIN_ARCHIVES defaulted to '$MIN_ARCHIVES'"
fi

if [ -z ${PROJECT+x} ]; then
    PROJECT=$DB
    echo "PROJECT defaulted to '$PROJECT'"
fi


if [ -z ${MYSQLDUMP_OPTIONS+x} ]; then 
    MYSQLDUMP_OPTIONS="--single-transaction -v --quick --compress"
    echo "MYSQLDUMP_OPTIONS defaulted to '$MYSQLDUMP_OPTIONS'"
fi

DATEFILE='%Y%m%d%H%M%S'

echo [ `date` ] starting dump of $DB on $DB_HOST

ARCHIVE_FILE=$ARCHIVE_DIR/${DB}_`date +$DATEFILE`.sql.gz

/usr/bin/mysqldump -h$DB_HOST -u$DB_USER -p$DB_PASS $MYSQLDUMP_OPTIONS $DB | gzip > $ARCHIVE_FILE
if [ ${PIPESTATUS[0]} == 0 ]
then
    ln -fs $ARCHIVE_FILE ${BACKUP_DIR}/${PROJECT}.sql.gz
    
    echo "Created link from ${BACKUP_DIR}/${PROJECT}.sql.gz to $ARCHIVE_FILE"
    
    echo ['date'] Removing archives older than $ROLLOVER_DAYS days while keeping minimum of $MIN_ARCHIVES
    
    find ./ -maxdepth 1 -regex "\./$DB_[0-9]+\.tar\.gz" -type f | sort -n | head --lines=-$MIN_ARCHIVES | while read file ; do
        find $file -maxdepth 0 -regex "\./$DB_[0-9]+\.tar\.gz" -type f -mtime +$ROLLOVER_DAYS -delete
        echo "Deleting archive: $file"
    done

	echo "Database backup completed successfully"
    exit 0

else
    echo "backup of $DB to $ARCHIVE_FILE failed"
    rm $ARCHIVE_FILE
    exit 1
fi


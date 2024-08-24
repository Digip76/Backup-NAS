#!/bin/bash

# Laden van configuratieparameters
CONFIG_FILE="/path/to/configuration.json"

MYSQL_USER=$(jq -r '.mysql_user' "$CONFIG_FILE")
BACKUP_DIR=$(jq -r '.backup_directory' "$CONFIG_FILE")
LOG_DIR=$(jq -r '.log_directory' "$CONFIG_FILE")
RSYNC_DIRS=$(jq -r '.rsync_directories[]' "$CONFIG_FILE")
EXCLUDE_DIRS=$(jq -r '.exclude_directories[]' "$CONFIG_FILE")
ONEDRIVE_REMOTE=$(jq -r '.onedrive_remote' "$CONFIG_FILE")
ONEDRIVE_BACKUP_DIR=$(jq -r '.onedrive_backup_directory' "$CONFIG_FILE")

# Echo Starting backup ....
SUFFIX=$(date +%F_%H%M%S)

# Dump van MySQL databases
mysqldump --all-databases --ignore-table=mysql.event -u "$MYSQL_USER" >"$BACKUP_DIR/mysql_$SUFFIX.sql"

# Zippen van MySQL dump en vervolgens verwideren van dump
zip -q -r "$BACKUP_DIR/mysql_$SUFFIX.zip" "$BACKUP_DIR/mysql_$SUFFIX.sql"
rm "$BACKUP_DIR/mysql_$SUFFIX.sql"

# File backup
rsync --update -braz --delete --progress --backup-dir=$SUFFIX $(for dir in $RSYNC_DIRS; do echo -n "$dir "; done) --exclude $(for excl in $EXCLUDE_DIRS; do echo -n "$excl "; done) /backup/backup001 > "$LOG_DIR/rsync.log"

# Verplaats de backup directory indien aangemaakt
if [ -d "/backup/backup001/$SUFFIX" ]; then
    mv /backup/backup001/$SUFFIX /backup/$SUFFIX
fi

# Upload naar OneDrive
rclone copy /backup $ONEDRIVE_REMOTE$ONEDRIVE_BACKUP_DIR --log-file="$LOG_DIR/onedrive_$SUFFIX.log"

# PHP script uitvoeren en logs bijwerken
php /home/pieter/info.php >"$LOG_DIR/backup_$SUFFIX.log"
cat "$LOG_DIR/rsync.log" >> "$LOG_DIR/backup_$SUFFIX.log"
echo "" >> "$LOG_DIR/backup_$SUFFIX.log"
rm "$LOG_DIR/rsync.log"

# Log bestanden mailen
mail mail@receiver.org -s"Backup result NNAS" < "$LOG_DIR/backup_$SUFFIX.log"

# Echo Backup ready.

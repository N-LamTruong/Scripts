#!/bin/bash

# Variables
GITLAB_BACKUP="/var/opt/gitlab/backups"
GITLAB_ETC="/etc/gitlab/config_backup"

GITLAB_TMP="/root/backup/gitlab"
BACKUP_DATE=`date '+%F'`

MINIO="myminio/gitlab"

LOG_FILE="/root/backup/log_backup.txt"
if [ ! -f "$LOG_FILE" ]; then
    echo "=====================================================================================================================" > $LOG_FILE
else
    echo "=====================================================================================================================" >> $LOG_FILE
fi
echo "Bay gio la: $(date "+%d-%m-%Y_%H:%M:%S")" >> $LOG_FILE

# Cleanup all old backups
echo "[1/5] $(date "+%d-%m-%Y_%H:%M:%S") - Cleanup all old backups..." >> $LOG_FILE
if [ ! -d $GITLAB_TMP ]; then mkdir -p "$GITLAB_TMP"; fi
rm -rf $GITLAB_TMP/*

# Backup Gitlab data
echo "[2/5] $(date "+%d-%m-%Y_%H:%M:%S") - Backup Gitlab data..." >> $LOG_FILE
sudo gitlab-backup create 2>&1 | grep -v '^{.*}$' >> $LOG_FILE

# Backup Gitlab config
echo "[3/5] $(date "+%d-%m-%Y_%H:%M:%S") - Backup Gitlab config..." >> $LOG_FILE
sudo gitlab-ctl backup-etc >> $LOG_FILE

# Compress files all in one
LATEST_BACKUP=$(basename $(ls -Art $GITLAB_BACKUP/*.tar 2>/dev/null | tail -n 1))
LATEST_ETC=$(basename $(ls -Art $GITLAB_ETC/*.tar 2>/dev/null | tail -n 1))

echo "[4/5] $(date "+%d-%m-%Y_%H:%M:%S") - Compress files all in one..." >> $LOG_FILE
if [[ -z "$LATEST_BACKUP" || -z "$LATEST_ETC" ]]; then
  echo "Not found file .tar in $GITLAB_BACKUP or $GITLAB_ETC. Exit script." >> $LOG_FILE
  exit 1
fi
tar -czf $GITLAB_TMP/$BACKUP_DATE.tar.gz -C $GITLAB_BACKUP $LATEST_BACKUP -C $GITLAB_ETC $LATEST_ETC >> $LOG_FILE

# Push file backup to MinIO
echo "[5/5] $(date "+%d-%m-%Y_%H:%M:%S") - Push file backup to MinIO..." >> $LOG_FILE
/usr/local/bin/mc cp $GITLAB_TMP/$BACKUP_DATE.tar.gz $MINIO >> $LOG_FILE

echo "  $(date "+%d-%m-%Y_%H:%M:%S") - Done backup GitLab and upload to MinIO" >> $LOG_FILE

# Keep the last 700 logs
echo "$(tail -700 $LOG_FILE)" > $LOG_FILE

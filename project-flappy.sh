#!/bin/bash

BACKUP_FOLDER="/home/flappy/backup"
LOG_FILE="/home/flappy/backup/log_backup.txt"

ENV_API="/home/flappy/live-api.flappy/.env"
ENV_CMS="/home/flappy/live-cms.flappy/.env"
ENV_WEBHOOK="/home/flappy/live-webhook.flappy/.env"
IMG_CMS="/home/flappy/live-cms.flappy/public/img"

S3_MONGO="s3://flappy-shiba/mongo/"
S3_ENV_API="s3://flappy-shiba/env_api"
S3_ENV_CMS="s3://flappy-shiba/env_cms"
S3_ENV_WEBHOOK="s3://flappy-shiba/env_webhook"
S3_IMG_CMS="s3://flappy-shiba/img_cms"

#1. Kiem tra xem ton tai folder backup khong?
if [ ! -d "$BACKUP_FOLDER" ]; then
    mkdir -p "$BACKUP_FOLDER"
fi

if [ ! -f "$LOG_FILE" ]; then
    echo "=====================================================================================================================" > $LOG_FILE
else
    echo "=====================================================================================================================" >> $LOG_FILE
fi

echo "Bay gio la: $(date "+%d-%m-%Y_%H:%M:%S")" >> $LOG_FILE

#2.Kiem tra xem container mongo co dang chay khong?
if docker ps --filter "name=mongo" --filter "status=running" | grep -q "mongo"; then
        echo "Container mongo_flappy dang chay." >> $LOG_FILE
else
        echo "Container mongo_flappy khong chay. Dung lai." >> $LOG_FILE
        exit 1
fi

#3. Backup mongo
echo "$(date "+%d-%m-%Y_%H:%M:%S") - Backup db bat dau..." >> $LOG_FILE
#docker exec mongo sh -c 'mongodump --archive --quiet -u ??? -p ??? --authenticationDatabase fapton --db fapton' | gzip > "$BACKUP_FOLDER/flappy_$(date "+%d-%m-%Y_%H:%M:%S").gz"
docker exec mongo sh -c 'mongodump -u ??? -p ??? --authenticationDatabase fapton --db fapton --archive --quiet --numParallelCollections 1' > "$BACKUP_FOLDER/flappy_$(date "+%d-%m-%Y_%H-%M-%S").bson"
echo "$(date "+%d-%m-%Y_%H:%M:%S") - Backup db hoan thanh. Tiep tuc nen gzip db..." >> $LOG_FILE
gzip $BACKUP_FOLDER/flappy_*
echo "$(date "+%d-%m-%Y_%H:%M:%S") - Nen gzip db thanh cong." >> $LOG_FILE

#4. Copy db sang s3 bucket
echo "$(date "+%d-%m-%Y_%H:%M:%S") - Copy db sang s3 bat dau..." >> $LOG_FILE
aws s3 cp $BACKUP_FOLDER/flappy* "$S3_MONGO" >> $LOG_FILE
echo "$(date "+%d-%m-%Y_%H:%M:%S") - Copy db sang s3 hoan thanh." >> $LOG_FILE

#5. Xoa file backup tren server
rm -rf $BACKUP_FOLDER/flappy*
echo "Xoa du lieu backup db tren server" >> $LOG_FILE

#6. Backup .env API, CMS, webhook va IMG_CMS
echo "$(date "+%d-%m-%Y_%H:%M:%S") - Backup .env api" >> $LOG_FILE
aws s3 cp $ENV_API "$S3_ENV_API/.env_$(date "+%d-%m-%Y_%H:%M:%S")" >> $LOG_FILE
echo "$(date "+%d-%m-%Y_%H:%M:%S") - Backup .env cms" >> $LOG_FILE
aws s3 cp $ENV_CMS "$S3_ENV_CMS/.env_$(date "+%d-%m-%Y_%H:%M:%S")" >> $LOG_FILE
echo "$(date "+%d-%m-%Y_%H:%M:%S") - Backup .env webhook" >> $LOG_FILE
aws s3 cp $ENV_WEBHOOK "$S3_ENV_WEBHOOK/.env_$(date "+%d-%m-%Y_%H:%M:%S")" >> $LOG_FILE

echo "$(date "+%d-%m-%Y_%H:%M:%S") - Backup img cms" >> $LOG_FILE
zip -rq img.zip $IMG_CMS >> $LOG_FILE
aws s3 mv img* "$S3_IMG_CMS/img_$(date "+%d-%m-%Y_%H:%M:%S")" >> $LOG_FILE

echo "Ket thuc script $(date "+%d-%m-%Y_%H:%M:%S")" >> $LOG_FILE

#7. Giu lai 700 dong log gan nhat
echo "$(tail -700 $LOG_FILE)" > $LOG_FILE

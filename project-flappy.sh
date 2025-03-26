#!/bin/bash

BACKUP_FOLDER="/home/ec2-user/backup"
LOG_FILE="/home/ec2-user/backup/log_backup.txt"

BACKUP_ENV_API="/home/ec2-user/live-api.shibaempire.co/.env"
BACKUP_ENV_CMS="/home/ec2-user/live-cms-admin.shibaempire.co/.env"
BACKUP_ENV_WEBHOOK="/home/ec2-user/live-shibaempire-webhook/.env"

S3_BUCKET_MONGO="s3://shiba-empire/mongo/"
S3_BUCKET_ENV_API="s3://shiba-empire/env_api"
S3_BUCKET_ENV_CMS="s3://shiba-empire/env_cms"
S3_BUCKET_ENV_WEBHOOK="s3://shiba-empire/env_webhook"

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

#2.Kiem tra xem container mongo_shiba co dang chay khong?
if docker ps --filter "name=mongo_shiba" --filter "status=running" | grep -q "mongo_shiba"; then
        echo "Container mongo_shiba dang chay." >> $LOG_FILE
else
        echo "Container mongo_shiba khong chay. Dung lai." >> $LOG_FILE
        exit 1
fi

#3. Backup mongo
echo "$(date "+%d-%m-%Y_%H:%M:%S") - Backup db bat dau..." >> $LOG_FILE
#docker exec mongo_shiba sh -c 'mongodump --archive --quiet -u admin -p ??? --authenticationDatabase shiba --db database' | gzip > "$BACKUP_FOLDER/shiba_$(date "+%d-%m-%Y_%H:%M:%S").gz"
docker exec mongo_shiba sh -c 'mongodump -u admin -p ??? --authenticationDatabase admin --db database --archive --quiet --numParallelCollections 1' > "$BACKUP_FOLDER/shiba_$(date "+%d-%m-%Y_%H-%M-%S").bson"
echo "$(date "+%d-%m-%Y_%H:%M:%S") - Backup db hoan thanh. Tiep tuc nen gzip db..." >> $LOG_FILE
gzip $BACKUP_FOLDER/shiba_*
echo "$(date "+%d-%m-%Y_%H:%M:%S") - Nen gzip db thanh cong." >> $LOG_FILE

#4. Copy db sang s3 bucket
echo "$(date "+%d-%m-%Y_%H:%M:%S") - Copy db sang s3 bat dau..." >> $LOG_FILE
aws s3 cp $BACKUP_FOLDER/shiba* "$S3_BUCKET_MONGO" >> $LOG_FILE
echo "$(date "+%d-%m-%Y_%H:%M:%S") - Copy db sang s3 hoan thanh." >> $LOG_FILE

#5. Xoa file backup tren server
rm -rf $BACKUP_FOLDER/shiba*
echo "Xoa du lieu backup db tren server" >> $LOG_FILE

#6. Backup .env API, CMS, Webhook
echo "$(date "+%d-%m-%Y_%H:%M:%S") - Backup .env api" >> $LOG_FILE
aws s3 cp $BACKUP_ENV_API "$S3_BUCKET_ENV_API/.env_$(date "+%d-%m-%Y_%H:%M:%S")" >> $LOG_FILE
echo "$(date "+%d-%m-%Y_%H:%M:%S") - Backup .env cms" >> $LOG_FILE
aws s3 cp $BACKUP_ENV_CMS "$S3_BUCKET_ENV_CMS/.env_$(date "+%d-%m-%Y_%H:%M:%S")" >> $LOG_FILE
echo "$(date "+%d-%m-%Y_%H:%M:%S") - Backup .env webhook" >> $LOG_FILE
aws s3 cp $BACKUP_ENV_WEBHOOK "$S3_BUCKET_ENV_WEBHOOK/.env_$(date "+%d-%m-%Y_%H:%M:%S")" >> $LOG_FILE
echo "Ket thuc script $(date "+%d-%m-%Y_%H:%M:%S")" >> $LOG_FILE

#7. Giu lai 500 dong log gan nhat
echo "$(tail -500 $LOG_FILE)" > $LOG_FILE

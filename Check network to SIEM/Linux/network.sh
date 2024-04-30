#!/bin/bash

LOG_DIR="/tmp"
LOG_FILE="$LOG_DIR/$(date +'%d-%m-%Y').log"
CURRENT_DATE=$(date +'%d-%m-%Y')

#Time hien tai
echo "" >> "$LOG_FILE"
echo "Time: $(date +'%T %d/%m/%Y')" >> "$LOG_FILE"

# Lap qua tung ngay truoc do va nen file log
for ((i=1; i<=365; i++)); do
  PREVIOUS_DATE=$(date -d "$i days ago" +'%d-%m-%Y')
  PREVIOUS_LOG="$LOG_DIR/$PREVIOUS_DATE.log"

  if [[ -e "$PREVIOUS_LOG" ]]; then
    rar a -ep -r "$LOG_DIR/$PREVIOUS_DATE.rar" "$PREVIOUS_LOG" > /dev/null
    if [[ $? -eq 0 ]]; then
      echo "Compression successful. Deleting log file for $PREVIOUS_DATE..." >> "$LOG_FILE"
      rm "$PREVIOUS_LOG"
    else
      echo "Compression failed." >> "$LOG_FILE"
    fi
  fi
done

IP=$(dig +short myip.opendns.com @resolver1.opendns.com)
echo "IP Public: $IP" >> "$LOG_FILE"
nslookup connect.vadar.vn > /dev/null
if [[ $? -eq 0 ]]; then
  echo "nslookup connect.vadar.vn SUCCESS" >> "$LOG_FILE"
  telnet connect.vadar.vn 15141 > /dev/null 2>&1 <<EOF
  sleep 5
  quit
EOF
  sleep 1
  if [[ $? -eq 0 ]]; then
    echo "telnet connect.vadar.vn 15141 SUCCESS" >> "$LOG_FILE"
    traceroute -w 1 connect.vadar.vn >> "$LOG_FILE"
  else
    echo "telnet connect.vadar.vn 15141 FALSE" >> "$LOG_FILE"
  fi
else
  echo "nslookup connect.vadar.vn FALSE" >> "$LOG_FILE"
fi

#!/bin/bash

#Thời gian hiện tại để dễ nhìn log theo từng ngày
Local_time=$(date "+%m-%d-%Y %T")
Time_now=$(date "+%T")

echo -e "\nBây giờ là: $Local_time"

# Thông tin account Opensearch
USERNAME="admin"
PASSWORD="dQcuVfNsizcTBAvlBVSjpFTdwjBsofx6"

# Opensearch URL
OPENSEARCH_URL="https://localhost:9200"

# Tên snapshot repository
REPO="backup"

# Backup snapshot ngày hiện tại
NEW_SNAPSHOT_NAME="vadar_cluster-$(date +%m-%d-%Y)"
curl -s -XPUT -u "$USERNAME:$PASSWORD" -k "$OPENSEARCH_URL/_snapshot/$REPO/$NEW_SNAPSHOT_NAME"
echo -e "\nBackup $NEW_SNAPSHOT_NAME completed."

# Lấy ra danh sách các bản snapshot
#SNAPSHOTS=$(curl -s -XGET -u "$USERNAME:$PASSWORD" -k "$OPENSEARCH_URL/_snapshot/$REPO/_all" | jq -r '.snapshots[].snapshot')
#echo "Snapshot Names: $SNAPSHOTS"

# Danh sách snapshot cùng với thời gian tạo (tính bằng giây)
SNAPSHOT_INFO=$(curl -s -XGET -u "$USERNAME:$PASSWORD" -k "$OPENSEARCH_URL/_snapshot/$REPO/_all" | jq -r '.snapshots[] | { snapshot: .snapshot, creation_date: .start_time }')
#echo "SNAPSHOT_INFO: $SNAPSHOT_INFO"

# Sắp xếp snapshot theo ngày tạo, thứ tự tăng dần
SORTED_SNAPSHOTS=$(echo "$SNAPSHOT_INFO" | jq -s 'sort_by(.creation_date)')
#echo "SORTED_SNAPSHOTS: $SORTED_SNAPSHOTS"

# Tổng số snapshot
TOTAL_SNAPSHOTS=$(echo "$SORTED_SNAPSHOTS" | jq '. | length')
echo "TOTAL_SNAPSHOTS: $TOTAL_SNAPSHOTS"

# Tổng số snapshot cần lưu trữ
LIMIT=3

if [ "$TOTAL_SNAPSHOTS" -gt "$LIMIT" ]; then
  # Tính số snapshot cần xóa
  SNAPSHOTS_TO_DELETE=$((TOTAL_SNAPSHOTS - LIMIT))
  echo "SNAPSHOTS_TO_DELETE: $SNAPSHOTS_TO_DELETE"

  # Liệt kê tên snapshot sẽ bị xóa
  SNAPSHOTS_TO_DELETE_NAMES=$(echo "$SORTED_SNAPSHOTS" | jq -r '.[:'$SNAPSHOTS_TO_DELETE'] | .[].snapshot')
  echo "SNAPSHOTS_TO_DELETE_NAMES: $SNAPSHOTS_TO_DELETE_NAMES"

  # Sử dụng vòng lặp để xóa các bản snapshot cũ trước 3 ngày
  for SNAPSHOT_NAME in $SNAPSHOTS_TO_DELETE_NAMES; do
    curl -s -XDELETE -u "$USERNAME:$PASSWORD" -k "$OPENSEARCH_URL/_snapshot/$REPO/$SNAPSHOT_NAME"
    echo -e "\nDeleted snapshot: $SNAPSHOT_NAME"
  done
else
  echo "Number of snapshots is less than or equal to 3. Skipping deletion."
fi
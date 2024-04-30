#!/bin/bash
export PATH=$PATH:/sbin

# Các thông số cấu hình
telegram_bot_token="6049890914:AAHqXdvWWnQ_pHjUW322nHrmWshNq8YFv1o"
telegram_chat_id="-689879033"

log_file="/var/ossec/logs/ossec.log"
time_range="10 minutes ago"

time_unix=$(date +%s)

#Thông tin prometheus_node
prometheus_node="10.0.2.5:9090"

# Lấy địa chỉ IP exporter_node
interface_exporter=$(ip route | awk '$1 == "default" {print $5}' | head -n 1)
ip_address_exporter=$(ifconfig $interface_exporter | awk '/inet / {print $2}')

#Thông tin exporter_node
exporter_node="$ip_address_exporter:9100"
exporter_hostname=$(hostname)

interval="5m"
parameter="rate(node_disk_io_time_seconds_total{instance='$exporter_node'}[$interval])"

data=$(curl -G http://$prometheus_node/api/v1/query --data-urlencode query=$parameter --data-urlencode time=$time_unix | jq .data.result[0].value[1] | sed 's/"//g')
multiplied_result=$(echo "$data * 100" | bc -l)
io_spent_time=$(printf "%.2f" $multiplied_result)

# Kiểm tra nếu giá trị io_spent_time vượt quá 90
if (( $(awk 'BEGIN{print ('$io_spent_time' > 90)}') )); then

  # Lấy các giá trị khác
  top_io_services=$(iotop -n 1 -b -P | awk '$1 ~ /^[0-9]+$/ {print $0}' | head -n 1 | awk '{print $12}')
  io_service_percent=$(iostat -x 1 1 | awk '/^[[:space:]]*[^[:space:]]/{percent=$NF} END{print percent}')
  log_error=$(grep -E "wazuh-db: ERROR|wazuh-modulesd" "$log_file" | grep "$(date -d "$time_range" '+%Y-%m-%d %H:%M')")

  # Chuẩn bị nội dung tin nhắn
  message="*Cảnh báo thông tin I/O:*"
  message+=$'\n'"IO Spent Time (%): *$io_spent_time*"
  message+=$'\n'"Top IO Services: *$top_io_services*"
  message+=$'\n'"Top IO Service Percent: *$io_service_percent*"

  # Kiểm tra nếu có lỗi trong vòng 10 phút gần nhất
  if [[ -n "$log_error" ]]; then
    message+=$'\n'"*Kiểm tra lỗi trên server: $exporter_hostname*"
    message+=$'\n'"$log_error"
  else
    message+=$'\n'"Check Logs trên server *$exporter_hostname: Không phát hiện lỗi wazuh-db hoặc wazuh-modulesd trong vòng 10 phút gần nhất.*"
  fi

  # Gửi tin nhắn đến Telegram Bot
  curl -s -X POST "https://api.telegram.org/bot$telegram_bot_token/sendMessage" \
       -d "chat_id=$telegram_chat_id" \
       -d "text=$message" \
       -d "parse_mode=Markdown"
fi
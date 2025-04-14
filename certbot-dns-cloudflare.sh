#!bin/bash

# Variables
DOMAIN="your.domain"
CLOUDFLARE_API="/root/certbot-dns/.secret/cloudflare.ini"
SSH_PRIVATE_KEY="/root/certbot-dns/.secret/dev.private"
LOG="/root/certbot-dns/certbot.log"

# WEWIN_DEV
USER="root"
IP="xxx.xxx.xxx.xxx"
SSL="/home/domains/wssandbox.wewin.vin"
GAME="/home/game-server"

# Certbot Server
CERT_FOLDER="/etc/letsencrypt/live/${DOMAIN}"
CERT_PATH="$CERT_FOLDER/fullchain.pem"
PRIVATE_KEY_PATH="$CERT_FOLDER/privkey.pem"

log() {
  TIMESTAMP=$(date +"%Y-%m-%d %H-%M-%S")
  echo "[$TIMESTAMP] $1" >> "$LOG"
}

log "--- Bat dau qua trinh quan ly chung chi SSL ---"

# Kiem tra xem da ton tai chung chi chua?
if [ -f "$CERT_PATH" ] && [ -f "$PRIVATE_KEY_PATH" ]; then
  # Co roi thi gia han
  log "Chung chi da ton tai. Tien hanh gia han..."
  certbot renew --dns-cloudflare --dns-cloudflare-credentials "$CLOUDFLARE_API" --non-interactive --agree-tos --no-eff-email --cert-name "$DOMAIN" >> "$LOG" 2>&1
  CERTBOT_STATUS=$?
else
  # Lay chung chi lan dau
  log "Chung chi chua ton tai. Lay chung chi lan dau tien..."
  certbot certonly --dns-cloudflare --dns-cloudflare-credentials "$CLOUDFLARE_API" --non-interactive --agree-tos --no-eff-email --dns-cloudflare-propagation-seconds 60 -d "$DOMAIN" >> "$LOG" 2>&1
  CERTBOT_STATUS=$?
fi

# Kiem tra trang thai
if [ $CERTBOT_STATUS -ne 0 ]; then
  log "Error: Qua trinh cap chung chi hoac gia han chung chi that bai. Vui long xem log tai ${LOG} de biet them chi tiet."
  exit 1
fi

log "Chung chi da duoc cap, gia han thanh cong. Hieu luc 3 thang."

# Chuyen chung chi sang WEWIN_DEV
log "Dang chuyen chung chi sang WEWIN_DEV: $IP"

scp -i "$SSH_PRIVATE_KEY" -P12357 "$CERT_FOLDER"/* "${USER}@${IP}:${SSL}" > /dev/null 2>&1
SCP_STATUS=$?

if [ $SCP_STATUS -ne 0 ]; then
  log "Error: Chuyen chung chi sang server WEWIN_DEV that bai."
  exit 1
fi

# Tao file .p12 de chuyen doi JKS
log "Tao file .p12 de chuyen doi JKS"

ssh -i "$SSH_PRIVATE_KEY" -p12357 "${USER}@${IP}" "PASS='123456aA@' && openssl pkcs12 -export -in $SSL/cert.pem -inkey $SSL/privkey.pem -out $SSL/cert_and_key.p12 -name wssandbox.wewin.vin -certfile $SSL/fullchain.pem -passin pass:\$PASS -passout pass:\$PASS" > /dev/null 2>&1
SSH_p12=$?

if [ $SSH_p12 -ne 0 ]; then
  log "Error: Tao file .p12 khong thanh cong."
  exit 1
fi

#Tao file JKS
log "Tao file JKS"

ssh -i "$SSH_PRIVATE_KEY" -p12357 "${USER}@${IP}" "PASS='123456aA@' && keytool -importkeystore -srckeystore $SSL/cert_and_key.p12 -srcstoretype PKCS12 -srcstorepass \$PASS -alias wssandbox.wewin.vin -deststorepass \$PASS -destkeypass \$PASS -destkeystore $SSL/MyDSKeyStore.jks -noprompt" > /dev/null 2>&1
SSH_JKS=$?

if [ $SSH_JKS -ne 0 ]; then
  log "Error: Tao file JKS khong thanh cong."
  exit 1
fi

# Chuyen file JKS vao folder game
log "Chuyen file JKS vao folder game"

ssh -i "$SSH_PRIVATE_KEY" -p12357 "${USER}@${IP}" "\cp -f $SSL/MyDSKeyStore.jks $GAME" > /dev/null 2>&1
SSH_CP=$?

if [ $SSH_CP -ne 0 ]; then
  log "Error: Copy JKS vao folder $GAME khong thanh cong"
  exit 1
fi

# Restart lai web server Apache cua WEWIN_DEV
log "Dang restart Apache tren WEWIN_DEV"

ssh -i "$SSH_PRIVATE_KEY" -p12357 "${USER}@${IP}" "service httpd restart" > /dev/null 2>&1
SSH_RELOAD=$?

if [ $SSH_RELOAD -ne 0 ]; then
  log "Error: Restart Apache tren WEWIN_DEV that bai."
  exit 1
fi

log "Da restart Apache thanh cong."

# Restart lai Game Server WEWIN_DEV
log "Dang restart Game Server tren WEWIN_DEV"

ssh -i "$SSH_PRIVATE_KEY" -p12357 "${USER}@${IP}" "bash $GAME/stop-gitlab.sh && sleep 10 && bash $GAME/run-gitlab.sh" > /dev/null 2>&1
SSH_GAME=$?

if [ $SSH_GAME -ne 0 ]; then
  log "Error: Restart Game Server tren WEWIN_DEV"
  exit 1
fi

log "Da restart Game Server thanh cong."

log "--- Ket thuc qua trinh quan ly chung chi SSL ---"

exit 0

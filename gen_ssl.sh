#!/bin/sh
set -e

echo "Generating self-signed certificates for nginx..."

# Create certificates folder
if [ ! -d "./certs" ]; then
    mkdir ./certs
fi

cd ./certs

# Generate root CA
openssl ecparam -out root-ca.key -name prime256v1 -genkey
openssl req -new -sha256 -key root-ca.key -out root-ca.csr -subj "/C=VN/ST=Hanoi/L=Hanoi/O=VSEC/OU=Tech/CN=rootCA"
openssl x509 -req -sha256 -days 3650 -in root-ca.csr -signkey root-ca.key -out root-ca.crt

# Generate server certificates
openssl ecparam -out thehive.key -name prime256v1 -genkey
openssl req -new -sha256 -key thehive.key -out thehive.csr -subj "/C=VN/ST=Hanoi/L=Hanoi/O=VSEC/OU=Tech/CN=thehive.local"
openssl x509 -req -in thehive.csr -CA  root-ca.crt -CAkey root-ca.key -CAcreateserial -out thehive.crt -days 3650 -sha256

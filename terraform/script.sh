#!/bin/bash
sudo apt update -y
sudo apt install -y git nginx postgresql golang
sudo systemctl stop postgresql
git clone https://github.com/O-Danylchuk/golang-demo /home/ubuntu/golang-demo
cd /home/ubuntu/golang-demo
sudo go build -o silly-demo -buildvcs=false
sudo chmod +x silly-demo
PGPASSWORD="admin123" psql -h silly-demo-db-new.cdm8ao0i2jur.eu-north-1.rds.amazonaws.com -p 5432 -U admin1 -d sillydemo -f /home/ubuntu/golang-demo/db_schema.sql
sudo cp ./nginx.conf /etc/nginx/nginx.conf 
sudo systemctl enable nginx
sudo systemctl start nginx
exec > /home/ubuntu/user_data.log 2>&1
DB_HOST=silly-demo-db-new.cdm8ao0i2jur.eu-north-1.rds.amazonaws.com \
DB_PORT=5432 \
DB_USER=admin1 \
DB_PASS=admin123 \
DB_NAME=sillydemo \
./silly-demo &
sudo nginx -s reload
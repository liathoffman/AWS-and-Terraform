#!/bin/bash
HOSTNAME = curl http://169.254.169.254/latest/meta-data/hostname
sudo apt-get update
sudo apt-get install -y nginx
sudo systemctl start nginx
sudo systemctl enable nginx
echo "This is server with hostname $HOSTNAME" | sudo tee /var/www/html/index.html
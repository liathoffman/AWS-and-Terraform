#!/bin/bash
sudo apt-get update
sudo apt-get install -y nginx
sudo systemctl start nginx
sudo systemctl enable nginx
echo "This is server number $RANDOM" | sudo tee /var/www/html/index.html
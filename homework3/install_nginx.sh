#!/bin/bash
HOSTNAME = curl http://169.254.169.254/latest/meta-data/hostname
sudo apt-get update
sudo apt-get install -y nginx
sudo systemctl start nginx
sudo systemctl enable nginx
echo "This is server with hostname $HOSTNAME" | sudo tee /var/www/html/index.html
sudo apt  install awscli -y
sudo /etc/init.d/cron start
sudo chmod 777 /etc/cron.d

sudo cat <<EOF > /etc/cron.d/accessloghourly
#!/bin/bash
0 * * * * sudo aws s3 cp /var/log/nginx/access.log s3://liat-nginx-logs-282837837882"
chmod +x accessloghourly
EOF
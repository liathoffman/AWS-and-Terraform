#!/bin/bash
sudo -i
HOSTNAME = curl http://169.254.169.254/latest/meta-data/hostname
apt-get update
apt-get install -y nginx
systemctl start nginx
systemctl enable nginx
echo "This is server with hostname $HOSTNAME" | sudo tee /var/www/html/index.html
apt install awscli -y

cat <<EOF > /etc/cron.d/accessloghourly
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
0 * * * * root aws s3 cp /var/log/nginx/access.log s3://liat-nginx-logs-282837837882
EOF

chmod +x /etc/cron.d/accessloghourly

/etc/init.d/cron start


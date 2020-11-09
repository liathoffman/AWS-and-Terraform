#!/bin/bash
HOSTNAME = curl http://169.254.169.254/latest/meta-data/hostname
sudo apt-get update
sudo apt-get install -y nginx
sudo systemctl start nginx
sudo systemctl enable nginx
echo "This is server with hostname $HOSTNAME" | sudo tee /var/www/html/index.html
sudo apt  install awscli -y
sudo apt update
sudo apt install software-properties-common
sudo apt-add-repository --yes --update ppa:ansible/ansible
sudo apt install ansible -y

sudo cat <<EOF > ~/hosts.yml
hosts:
  localhost:
   vars:
     ansible_connection: local
     ansible_python_interpreter: "{{ansible_playbook_python}}"
EOF

sudo ansible localhost -m ansible.builtin.cron -a "name=access-logs minute=0 job='sudo aws s3 cp /var/log/nginx/access.log s3://liat-nginx-logs-282837837882/{{ansible_eth0.ipv4.address}}-access.log'" --become


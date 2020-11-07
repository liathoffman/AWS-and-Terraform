#! /bin/bash

CRON_FILE = "/var/spool/cron/root"

crontab -l 

0 * * * * aws s3 cp /var/log/nginx/access.log s3://liat-nginx-logs-282837837882
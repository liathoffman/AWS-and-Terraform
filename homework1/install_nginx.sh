#!/bin/bash
sudo yum install nginx -y
sudo service nginx start
# removing old index.html file from ngninx
sudo rm /usr/share/nginx/html/index.html
sudo touch /usr/share/nginx/html/index.html
# Creating index.html file
sudo chmod 777 /usr/share/nginx/html -R
sudo cat > /usr/share/nginx/html/index.html << EOF
<!DOCTYPE html>
<html lang="en">
<head>
        <title>This is a Title</title>
        <meta charset="utf-8" />
</head>
<body class="container">
        <h1>OpsSchool rules!<h1>


</body>
</html>
EOF

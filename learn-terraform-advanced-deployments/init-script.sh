#!/bin/bash

# This updates the system to the latest version.
sudo yum update -y

# This installs the Apache web server.
sudo yum install httpd -y

# This makes sure the web server starts when the system boots.
sudo systemctl enable httpd

# This starts the web server right now.
sudo systemctl start httpd

# This creates a webpage with the content we provide.
echo "${file_content}!" > /var/www/html/index.html
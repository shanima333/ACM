#!/bin/bash

yum install httpd php git -y
servie httpd restart
chkconfig httpd on
cd /tmp
git clone https://github.com/shanima333/aws-elb-site.git website
cp -r ./website/* /var/www/html/
cd
service httpd restart

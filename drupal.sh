#!/bin/bash

INSTDIR=`pwd`

# Git
yum install -y git

# Gcc
yum install -y gcc

# MySQL
echo "MySQL"
yum install -y mysql mysql-server
chkconfig mysqld on
service mysqld restart

# PHP
echo "PHP"
yum install -y php php-devel php-pear
yum install -y php-mysql php-dom php-gd php-mbstring
pecl install uploadprogress
echo "extension=uploadprogress.so"

# Httpd
echo "Httpd"
yum install -y httpd
chkconfig httpd on
service httpd restart


# Drupal
mv /var/www/html /var/www/html.autobackup
git clone http://git.drupal.org/project/drupal.git /var/www/html
cd /var/www/html
git checkout 7.27
##git remote rename origin drupal
##git remote add origin https://git.psu.edu/tmh24/ssri-drupal.git

useradd drupal
chown -R drupal:drupal /var/www/html
chown drupal:drupal /var/www/html/.htaccess
mkdir /var/www/html/site/default/files
chown apache:apache files
chmod -R 755 /var/www/html/sites/all/modules
chmod -R 755 /var/www/html/sites/all/themes

mysqladmin -u root create drupal

mysql -u root < $INSTDIR\db.sql
cp $INSTDIR/settings.php /var/www/html/sites/default/settings.php
chown root:root /var/www/html/sites/default/settings.php
chmod 644 /var/www/html/sites/default/settings.php

iptables -I INPUT -p tcp -m tcp --dport 80 -j ACCEPT
iptables -I INPUT -p tcp -m tcp --dport 443 -j ACCEPT

# Drush
cd /var/www/html
pear channel-discover pear.drush.org
pear install drush/drush
drush



# Add user to drupal group
usermod -a -G drupal tmh24


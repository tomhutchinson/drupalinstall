#!/bin/bash

# Get current install directory of the script
INSTDIR=`pwd`

# Install Yum - probably not necessary
yum install -y git

# Install C compiler for make
yum install -y gcc

# Install MySQL
yum install -y mysql mysql-server
chkconfig mysqld on
service mysqld restart

# Install PHP and all necessary extensions/plugins
yum install -y php php-devel php-pear
yum install -y php-mysql php-dom php-gd php-mbstring
pecl install uploadprogress
echo "extension=uploadprogress.so" >> /etc/php.ini

# Install Apache
yum install -y httpd
chkconfig httpd on
service httpd restart


# Install Drupal Core
mv /var/www/html /var/www/html.autobackup
git clone http://git.drupal.org/project/drupal.git /var/www/html
cd /var/www/html
git checkout 7.27
##git remote rename origin drupal
##git remote add origin https://git.psu.edu/tmh24/ssri-drupal.git

# Create new user to own Drupal install
useradd drupal
chown -R drupal:drupal /var/www/html
chown drupal:drupal /var/www/html/.htaccess
mkdir /var/www/html/sites/default/files
chown apache:apache /var/www/html/sites/default/files
chmod -R 755 /var/www/html/sites/all/modules
chmod -R 755 /var/www/html/sites/all/themes

# Create database
mysqladmin -u root create drupal

# Create Drupal database user account, install settings file
mysql -u root < $INSTDIR/db.sql
cp $INSTDIR/settings.php /var/www/html/sites/default/settings.php
chown root:root /var/www/html/sites/default/settings.php
chmod 644 /var/www/html/sites/default/settings.php

# Install Drush
cd /var/www/html
pear channel-discover pear.drush.org
pear install drush/drush
drush > /dev/null

# Add firewall rules for HTTP/HTTPS
iptables -I INPUT -p tcp -m tcp --dport 80 -j ACCEPT
iptables -I INPUT -p tcp -m tcp --dport 443 -j ACCEPT
service iptables restart

# Add user to drupal group - MAKE THIS CUSTOMIZABLE
usermod -a -G drupal tmh24


# Install modules - Security
cd /var/www/html
drush dl security_review
drush en -y security_review
drush dl flood_control
drush en -y flood_control

# Install modules - Other
cd /var/www/html
drush dl views
drush en -y views
drush dl features
drush en -y features
drush dl module_filter
drush en -y module_filter
drush dl pathauto
drush en -y pathauto
drush dl site_audit

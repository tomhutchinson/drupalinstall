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
pecl channel-update pecl.php.net
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
# TODO - Ask for version
read -p "Enter the Drupal version number you want to install: " REPLY1
git checkout $REPLY1

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
cp /var/www/html/sites/default/default.settings.php /var/www/html/sites/default/settings.php
cat $INSTDIR/db.inc >> /var/www/html/sites/default/settings.php
chown root:root /var/www/html/sites/default/settings.php
chmod 644 /var/www/html/sites/default/settings.php

# Install Drush
cd /var/www/html
pear channel-discover pear.drush.org
pear install drush/drush
drush > /dev/null

# Create the Drupal database
cd /var/www/html
drush site-install --db-su=root --account-name=admin --account-pass=admin --clean-url=0 --site-name="SSRI Drupal Development"

# Add firewall rules for HTTP/HTTPS
iptables -I INPUT -p tcp -m tcp --dport 80 -j ACCEPT
iptables -I INPUT -p tcp -m tcp --dport 443 -j ACCEPT
service iptables restart

# Add user to drupal group
while :
do
	read -p "Enter an OS user that should have access to Drush commands, or DONE when finished: " REPLY2
	if  [ $REPLY2 == 'DONE' ]
		then
			break
		fi
		#echo $REPLY
		usermod -a -G drupal $REPLY2
		
done

# TODO - Change EnableOverride to All for Clean URLs via .htaccess


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


# Done, give feedback
echo ""
echo "All Done!"
echo ""
echo "!!!!! IMPORTANT !!!!!"
echo "Your MySQL installation is currently insecure!"
echo "Be sure to run /usr/bin/mysql_secure_installation to set a MySQL root password and remove the Test database"
echo ""
echo "You can log into your new Drupal installation with admin/admin."
echo ""


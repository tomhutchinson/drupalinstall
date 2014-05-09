#!/bin/bash

# Get current install directory of the script
INSTDIR=`pwd`

# Ask for install location
default_install="/var/www/html"
read -p "Enter the directory that you want to install Drupal to ($default_install): " REPLY0
[ -z "$REPLY0"] && REPLY0=$default_install
echo "Installing Drupal to directory: $REPLY0"
echo ""
read -p "Enter the Drupal version number you want to install: " REPLY1
echo "Installing Drupal version: $REPLY1"
echo ""

# Install Yum - probably not necessary
yum install -q -y git

# Install C compiler for make
yum install -q -y gcc

# Install MySQL
yum install -q -y mysql mysql-server
chkconfig mysqld on
service mysqld restart > $INSTDIR/install.log
# Install PHP and all necessary extensions/plugins
yum install -q -y php php-devel php-pear
yum install -q -y php-mysql php-dom php-gd php-mbstring
pecl channel-update pecl.php.net >> $INSTDIR/install.log
pecl install uploadprogress >> $INSTDIR/install.log
echo "extension=uploadprogress.so" >> /etc/php.ini

# Install Apache
yum install -q -y httpd
chkconfig httpd on
service httpd restart >> $INSTDIR/install.log


# Install Drupal Core
[ -d $REPLY0 ] && mv $REPLY0 $REPLY0.autobackup
git clone http://git.drupal.org/project/drupal.git $REPLY0
cd $REPLY0
git checkout $REPLY1

# Create new user to own the Drupal install
useradd drupal
chown -R drupal:drupal $REPLY0
chown drupal:drupal $REPLY0/.htaccess
mkdir $REPLY0/sites/default/files
chown apache:apache $REPLY0/sites/default/files
chmod -R 755 $REPLY0/sites/all/modules
chmod -R 755 $REPLY0/sites/all/themes

# Create database
mysqladmin -u root create drupal

# Create Drupal database user account, install settings file
mysql -u root < $INSTDIR/db.sql
cp $REPLY0/sites/default/default.settings.php $REPLY0/sites/default/settings.php
cat $INSTDIR/db.inc >> $REPLY0/sites/default/settings.php
chown root:root $REPLY0/sites/default/settings.php
chmod 644 $REPLY0/sites/default/settings.php

# Install and bootstrap Drush
cd $REPLY0
pear channel-discover pear.drush.org >> $INSTDIR/install.log
pear install drush/drush >> $INSTDIR/install.log
drush > /dev/null

# Create the Drupal database
cd $REPLY0
echo "NOTE: You are about to be prompted to drop your Drupal database table!"
echo "This is EXPECTED and NORMAL if this is a new install."
drush site-install --db-su=root --account-name=admin --account-pass=admin --clean-url=1 --site-name="Drupal Development"

# Add firewall rules for HTTP/HTTPS
iptables -I INPUT -p tcp -m tcp --dport 80 -j ACCEPT
iptables -I INPUT -p tcp -m tcp --dport 443 -j ACCEPT
service iptables restart >> $INTSDIR/install.log

# Add user to drupal OS group
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

# Add Apache VirtualHost for new install
/bin/sed -i 's@DOCROOT@'$REPLY0'@g' $INSTDIR/vhost.inc
cat $INSTDIR/vhost.inc >> /etc/httpd/conf/httpd.conf
service httpd restart

# Install modules - Security
cd $REPLY0
drush dl security_review
drush en -y security_review
drush dl flood_control
drush en -y flood_control

# Install modules - Other
cd $REPLY0
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


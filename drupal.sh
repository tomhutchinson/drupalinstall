#!/bin/bash

# Get current install directory of the script
INSTDIR=`pwd`

# Ask for install location
default_install="/var/www/html"
read -p "Enter the directory that you want to install Drupal to ($default_install): " REPLY0
[ -z "$REPLY0"] && REPLY0=$default_install
echo "Will install Drupal to directory: $REPLY0"
echo ""
read -p "Enter the Drupal version number you want to install: " REPLY1
echo "Will install Drupal version: $REPLY1"
echo ""
default_hostname="vagrant.local"
read -p "Enter the hostname of the server ($default_hostname): " REPLY2
[ -z "$REPLY2"] && REPLY2=$default_hostname
echo "Hostname will be: $REPLY2"
echo ""

echo "Installing dependencies, please wait..."
echo ""

# Install Yum - probably not necessary
yum install -y git >> $INSTDIR/install.log

# Install C compiler for make
yum install -y gcc >> $INSTDIR/install.log

# Install MySQL
yum install -y mysql mysql-server >> $INSTDIR/install.log
chkconfig mysqld on
service mysqld restart >> $INSTDIR/install.log

# Install PHP and all necessary extensions/plugins
yum install -y php php-devel php-pear >> $INSTDIR/install.log
yum install -y php-mysql php-dom php-gd php-mbstring >> $INSTDIR/install.log
pecl channel-update pecl.php.net >> $INSTDIR/install.log
pecl install uploadprogress >> $INSTDIR/install.log
echo "extension=uploadprogress.so" >> /etc/php.ini

# Install Apache
yum install -y httpd >> $INSTDIR/install.log
chkconfig httpd on
service httpd restart >> $INSTDIR/install.log

echo "Installing Drupal, please wait..."
echo ""

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
echo ""
echo "NOTE: You are about to be prompted to drop your Drupal database table!"
echo "This is EXPECTED and NORMAL if this is a new install."
drush site-install --db-su=root --account-name=admin --account-pass=admin --clean-url=1 --site-name="Drupal Development"

# Add firewall rules for HTTP/HTTPS
iptables -I INPUT -p tcp -m tcp --dport 80 -j ACCEPT
iptables -I INPUT -p tcp -m tcp --dport 443 -j ACCEPT
service iptables restart >> $INTSDIR/install.log

# Add user to drupal OS group
echo ""
while :
do
	read -p "Enter an OS user that should have access to Drush commands, or DONE when finished: " REPLY3
	if  [ $REPLY3 == 'DONE' ]
		then
			break
		fi
		#echo $REPLY
		usermod -a -G drupal $REPLY3
		
done

# Add Apache VirtualHost for new install
/bin/sed -i 's@DOCROOT@'$REPLY0'@g' $INSTDIR/vhost.inc
/bin/sed -i 's@HOSTNAME@'$REPLY2'@g' $INSTDIR/vhost.inc
cat $INSTDIR/vhost.inc >> /etc/httpd/conf/httpd.conf
service httpd restart >> $INSTDIR/install.log

echo "Installing modules, please wait..."
echo ""

# Install modules - Security
cd $REPLY0
drush dl security_review >> $INSTDIR/install.log
drush en -y security_review >> $INSTDIR/install.log
drush dl flood_control >> $INSTDIR/install.log
drush en -y flood_control >> $INSTDIR/install.log

# Install modules - Other
cd $REPLY0
drush dl views >> $INSTDIR/install.log
drush en -y views >> $INSTDIR/install.log
drush dl features >> $INSTDIR/install.log
drush en -y features >> $INSTDIR/install.log
drush dl module_filter >> $INSTDIR/install.log
drush en -y module_filter >> $INSTDIR/install.log
drush dl pathauto >> $INSTDIR/install.log
drush en -y pathauto >> $INSTDIR/install.log
drush dl site_audit >> $INSTDIR/install.log


# Done, give feedback
echo ""
echo "All Done!"
echo ""
echo "!!!!! IMPORTANT !!!!!"
echo "Your MySQL installation is currently INSECURE!"
echo "Be sure to run /usr/bin/mysql_secure_installation to set a MySQL root password and remove the Test database"
echo ""
echo "You can log into your new Drupal installation with admin/admin."
echo ""

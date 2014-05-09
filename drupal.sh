#!/bin/bash

# Check for Root
if [ "$(id -u)" != "0" ]; then
		feedback "This script must be run as root!"
		exit 1
fi

# Get current install directory of the script
INSTDIR=`pwd`

# Ask for install information
echo ""
echo "Drupal Setup Script - Version 1"
echo "WARNING - If you specify the name of an existing MySQL database below, IT WILL BE DROPPED!"
echo ""
default_install="/var/www/html"
read -p "Enter the directory that you want to install Drupal to [$default_install]: " REPLY0
[ -z "$REPLY0" ] && REPLY0=$default_install
echo "Will install Drupal to directory: $REPLY0"
echo ""
default_version="7.00"
read -p "Enter the Drupal version number you want to install [$default_version]: " REPLY1
[ -z "$REPLY1" ] && REPLY1=$default_version
echo "Will install Drupal version: $REPLY1"
echo ""
default_hostname="vagrant.local"
read -p "Enter the hostname of the server [$default_hostname]: " REPLY2
[ -z "$REPLY2" ] && REPLY2=$default_hostname
echo "Hostname will be: $REPLY2"
echo ""
default_database="drupal"
read -p "Enter the Drupal database name you want to use [$default_database]: " REPLY3
[ -z "$REPLY3" ] && REPLY3=$default_database
echo "Database will be: $REPLY3"
echo ""

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
if ! grep -q extension=uploadprogress.so /etc/php.ini; then
	echo "extension=uploadprogress.so" >> /etc/php.ini
fi

# Install Apache
yum install -y httpd >> $INSTDIR/install.log
chkconfig httpd on
service httpd restart >> $INSTDIR/install.log

echo ""
echo "Installing Drupal, please wait..."
echo ""

# Install Drupal Core
[ -d $REPLY0 ] && mv $REPLY0 $REPLY0.autobackup
git clone http://git.drupal.org/project/drupal.git $REPLY0 -q >> $INSTDIR/install.log
cd $REPLY0
git checkout $REPLY1 -q >> $INSTDIR/install.log

# Create new user to own the Drupal install
useradd drupal
chown -R drupal:drupal $REPLY0
chown drupal:drupal $REPLY0/.htaccess
mkdir $REPLY0/sites/default/files
chown apache:apache $REPLY0/sites/default/files
chmod -R 755 $REPLY0/sites/all/modules
chmod -R 755 $REPLY0/sites/all/themes

# Backup existing database, Create database
mysqldump -f -u root $REPLY3 >> $INSTDIR/existing_db_dump.sql
mysqladmin -u root create $REPLY3 >> $INSTDIR/install.log

# Create Drupal database user account, install settings file
/bin/sed -i 's@DBNAME@'$REPLY3'@g' $INSTDIR/db.inc
/bin/sed -i 's@DBNAME@'$REPLY3'@g' $INSTDIR/db.sql
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
echo ""
drush site-install --db-su=root --account-name=admin --account-pass=admin --clean-url=1 --site-name="Drupal Development"

# Add firewall rules for HTTP/HTTPS
iptables -I INPUT -p tcp -m tcp --dport 80 -j ACCEPT
iptables -I INPUT -p tcp -m tcp --dport 443 -j ACCEPT
service iptables restart >> $INTSDIR/install.log

# Add user to drupal OS group
echo ""
while :
do
	read -p "Enter an OS user that should have access to Drush commands, or DONE when finished: " REPLY4
	if  [ $REPLY4 == 'DONE' ]
		then
			break
		fi
		#echo $REPLY
		usermod -a -G drupal $REPLY4
		
done

# Add Apache VirtualHost for new install
/bin/sed -i 's@DOCROOT@'$REPLY0'@g' $INSTDIR/vhost.inc
/bin/sed -i 's@HOSTNAME@'$REPLY2'@g' $INSTDIR/vhost.inc
cat $INSTDIR/vhost.inc >> /etc/httpd/conf/httpd.conf
service httpd restart >> $INSTDIR/install.log

echo ""
echo "Installing modules, please wait..."
echo ""

# Install modules - Security
cd $REPLY0
drush dl -q -y security_review >> $INSTDIR/install.log
drush en -q -y security_review >> $INSTDIR/install.log
drush dl -q -y flood_control >> $INSTDIR/install.log
drush en -q -y flood_control >> $INSTDIR/install.log

# Install modules - Other
cd $REPLY0
drush dl -q -y views >> $INSTDIR/install.log
drush en -q -y views >> $INSTDIR/install.log
drush dl -q -y features >> $INSTDIR/install.log
drush en -q -y features >> $INSTDIR/install.log
drush dl -q -y module_filter >> $INSTDIR/install.log
drush en -q -y module_filter >> $INSTDIR/install.log
drush dl -q -y pathauto >> $INSTDIR/install.log
drush en -q -y pathauto >> $INSTDIR/install.log
drush dl -q -y site_audit >> $INSTDIR/install.log


# Done, give feedback
echo ""
echo "All Done!"
echo ""
echo "!!!!! IMPORTANT !!!!!"
echo "Your MySQL installation is currently INSECURE!"
echo "Be sure to run /usr/bin/mysql_secure_installation to set a MySQL root password and remove the Test database."
echo ""
echo "You can log into your new Drupal installation with admin/admin."
echo ""

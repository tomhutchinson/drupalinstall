#!/bin/bash

# Script help
if [ "$1" == "-h" ]; then
	echo ""
	echo "SSRI Drupal installation and setup script"
	echo ""
	echo "Interactive install: drupal.sh"
	echo "Non-interactive install: drupal.sh -n [install directory] [Drupal version] [DNS hostname] [database name]"
	echo "Silent install: drupal.sh -s"
	echo "This help page: drupal.sh -h"
	echo ""
	exit 0
fi

# Check for Root
if [ "$(id -u)" != "0" ]; then
		feedback "This script must be run as root!"
		exit 1
fi

# Get current install directory of the script
INSTDIR=`pwd`

# Get non-interactive options
if [ "$1" == "-n" ]; then
	REPLY0=$2
	REPLY1=$3
	REPLY2=$4
	REPLY3=$5
fi

if [ "$1" == "-n" ] || [ "$1" == "-s" ]; then
	REPLY4="DONE"
fi

# Ask for install information
echo ""
echo "Drupal Setup Script - Version 1"
echo "WARNING - This script assumes that you have a new or non-existing install of Apache, MySQL, and PHP."
echo "If you specify a database name that already exists, IT WILL BE DROPPED!  You have been warned!"
echo ""

default_install="/var/www/drupal"
if [ "$1" != "-s" ] && [ "$1" != "-n" ]; then
	read -p "Enter the directory that you want to install Drupal to [$default_install]: " REPLY0
fi
[ -z "$REPLY0" ] && REPLY0=$default_install
echo "Will install Drupal to directory: $REPLY0"

echo ""
default_version="7.28"
if [ "$1" != "-s" ] && [ "$1" != "-n" ]; then
	read -p "Enter the Drupal version number you want to install [$default_version]: " REPLY1
fi
[ -z "$REPLY1" ] && REPLY1=$default_version
echo "Will install Drupal version: $REPLY1"

echo ""
default_hostname="drupal.local"
if [ "$1" != "-s" ] && [ "$1" != "-n" ]; then
	read -p "Enter the DNS hostname of the server [$default_hostname]: " REPLY2
fi
[ -z "$REPLY2" ] && REPLY2=$default_hostname
echo "Hostname will be: $REPLY2"

echo ""
default_database="drupal"
if [ "$1" != "-s" ] && [ "$1" != "-n" ]; then
	read -p "Enter the Drupal database name you want to use [$default_database]: " REPLY3
fi
[ -z "$REPLY3" ] && REPLY3=$default_database
echo "Database will be: $REPLY3"
echo ""

echo ""
echo "Installing dependencies, please wait..."
echo ""

# Install Yum - probably not necessary
yum install -y git >> $INSTDIR/install.log

# Install Which - may be needed for drush
yum install -y which >> $INSTDIR/install.log

# Install C compiler for make
yum install -y gcc >> $INSTDIR/install.log

# Install pwmake to generate random MySQL password
yum install -y pwgen >> $INSTDIR/install.log

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

# Install Apache Boilerplate
git clone https://github.com/h5bp/server-configs-apache >> $INSTDIR/install.log
cd server-configs-apache
cat server-configs-apache/src/.htaccess >> /etc/httpd/conf/httpd.conf
service httpd restart >> $INSTDIR/install.log

echo ""
echo "Installing Drupal, please wait..."
echo ""

# Install Drupal Core
[ -d $REPLY0 ] && mv $REPLY0 $REPLY0.autobackup
git clone http://git.drupal.org/project/drupal.git $REPLY0 -q >> $INSTDIR/install.log
cd $REPLY0
git checkout $REPLY1 -q >> $INSTDIR/install.log

# Create 
mkdir $REPLY0/sites/all/modules/contrib
mkdir $REPLY0/sites/all/modules/features
mkdir $REPLY0/sites/all/modules/org

# Create new user to own the Drupal install
useradd drupal
chown -R drupal:drupal $REPLY0
chown drupal:drupal $REPLY0/.htaccess
mkdir $REPLY0/sites/default/files
chown apache:apache $REPLY0/sites/default/files
chmod -R 755 $REPLY0/sites/all/modules
chmod -R 755 $REPLY0/sites/all/themes

# Backup existing database, Create database
# Note - skip the backup for now, it creates a confusing error message
# mysqldump -f -u root $REPLY3 >> $INSTDIR/existing_db_dump.sql
mysqladmin -u root create $REPLY3 >> $INSTDIR/install.log

# Create Drupal database user account, install settings file
RANDOMPASS=`pwgen -c -n -1 16`
echo $RANDOMPASS > $INSTDIR/drupal_database_password.txt
/bin/sed -i 's@DBNAME@'$REPLY3'@g' $INSTDIR/db.inc
/bin/sed -i 's@DBNAME@'$REPLY3'@g' $INSTDIR/db.sql
/bin/sed -i 's@DBPASS@'$RANDOMPASS'@g' $INSTDIR/db.inc
/bin/sed -i 's@DBPASS@'$RANDOMPASS'@g' $INSTDIR/db.sql
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
drush site-install -y --db-su=root --account-name=admin --account-pass=admin --clean-url=1 --site-name="Drupal Development"

# TODO - Check for iptables running, and don't add rules if it's not

# Add firewall rules for HTTP/HTTPS
iptables -I INPUT -p tcp -m tcp --dport 80 -j ACCEPT
iptables -I INPUT -p tcp -m tcp --dport 443 -j ACCEPT
service iptables restart >> $INTSDIR/install.log

# Add user to drupal OS group
echo ""
while :
do
	if [ "$1" != "-s" ] && [ "$1" != "-n" ]; then
		read -p "Enter an OS user that should have access to Drush commands, or DONE when finished: " REPLY4
	fi
	if  [ $REPLY4 == 'DONE' ]
		then
			break
		fi
		usermod -a -G drupal $REPLY4
		
done

# Add Apache VirtualHost for new install
/bin/sed -i 's@DOCROOT@'$REPLY0'@g' $INSTDIR/vhost.inc
/bin/sed -i 's@HOSTNAME@'$REPLY2'@g' $INSTDIR/vhost.inc
cat $INSTDIR/vhost.inc >> /etc/httpd/conf.d/drupal.conf
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
drush dl -q -y hacked >> $INSTDIR/install.log
drush en -q -y hacked >> $INSTDIR/install.log
drush dl -q -y jquery_update >> $INSTDIR/install.log
drush en -q -y jquery_update >> $INSTDIR/install.log

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
drush dl -q -y file_entity >> $INSTDIR/install.log
drush en -q -y file_entity >> $INSTDIR/install.log
drush dl -q -y site_audit >> $INSTDIR/install.log

# Disable overlays
drush dis overlay

# Todo
#CKeditor wysiwyg setup
#Remove copyright and maintainer files

# Done, give feedback
echo ""
echo "All Done!"
echo ""
echo "!!!!! IMPORTANT !!!!!"
echo "Your MySQL installation is currently INSECURE!"
echo "Be sure to run /usr/bin/mysql_secure_installation to set a MySQL root password and remove the Test database."
echo ""
echo "You can log into your new Drupal installation at http://localhost with admin/admin."
echo ""

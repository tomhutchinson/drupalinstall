NameVirtualHost *:80

### Drupal VirtualHost entry
<VirtualHost *:80>
	ServerAdmin root@localhost
	ServerName HOSTNAME
	ErrorLog logs/drupal-error_log
	CustomLog logs/drupal-access_log combined
	DocumentRoot DOCROOT
	<Directory DOCROOT>
		RewriteEngine on
		RewriteCond %{REQUEST_FILENAME} !-f
		RewriteCond %{REQUEST_FILENAME} !-d
		RewriteRule ^(.*)$ index.php?q=$1 [L,QSA]
		AllowOverride All
	</Directory>
</VirtualHost>

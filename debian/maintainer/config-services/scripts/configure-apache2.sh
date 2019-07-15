#!/bin/sh
## configure webserver 
cp snippets/apache-vhost-management-interface.conf /etc/apache2/sites-available/vhost-0-ispman
a2ensite vhost-0-ispman
a2dissite default
touch /etc/apache2/vhosts.conf.ispman
ln -s /etc/apache2/vhosts.conf.ispman /etc/apache2/sites-available/vhost-1-ispman
a2ensite vhost-1-ispman
/etc/init.d/apache2 reload


#!/bin/sh

cat <<EOF

README:

1.) Please configure /etc/ispman/ispman.conf first! Most
notably the imap admin password and the ldap password! The
imap password has be be working. If you haven't aldready 
done, please do 'passwd cyrus' on the shell.

2.)  Take care, your hostname in /etc/hostname is a FQDN. Amavis
will complain if this is only a hostname without domain part!

3.) Use dpkg-reconfigure libnss-ldap and pam-ldap to set the LDAP
searchbase to "o=ispman", rootdn to "uid=ispman,ou=admins,o=ispman",
and the corresponding password for the rootdn.

4.) After running this setup, you should be able to point your
browser to the IP Adress of this host and log in as 'ispman' with
the ldaproot password as ispman password. Please change that
after the first login.

5.) Currently you have to configure putr-ftpd manually in /etc/pure-ftpd/....

EOF

read -p "CTRL-C to abort and make the changes or any other key to proceed" dummy

apt-get install patch rpl pwgen
sh ./scripts/configure-apache2.sh
sh ./scripts/configure-cyrus.sh
sh ./scripts/configure-monit.sh
sh ./scripts/configure-postfix.sh
sh ./scripts/configure-pureftpd.sh
sh ./scripts/configure-saslauthd.sh
sh ./scripts/configure-slapd.sh
sh ./scripts/configure-nsswitch.sh
sh ./scripts/configure-bind9.sh

read -p 'Should I also run sh ./scripts/configure-amavis.sh to configure amavis for you? ispman-amavis has to be installed, too. If so, please type yes: ' amavisyes
if [ $amavisyes == "yes" ]; then sh ./scripts/configure-amavis.sh; fi 

read -p 'Should I also run sh scripts/configure-libnss-and-pam.sh to configure libnss_ldap and pam_ldap? If so, please type yes: ' ldapyes ;
if [ $ldapyes == "yes" ]; then sh scripts/configure-libnss-and-pam.sh; fi 


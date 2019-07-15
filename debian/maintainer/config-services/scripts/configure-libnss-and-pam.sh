#!/bin/sh

## libnss and pam_ldap
# set passwords
umask 077 ; echo -n $(grep ldapRootPass /etc/ispman/ispman.conf | sed -e "s/^.*\ '\(.*\)';/\1/") > /etc/libnss-ldap.secret
umask 077 ; echo -n $(grep ldapRootPass /etc/ispman/ispman.conf | sed -e "s/^.*\ '\(.*\)';/\1/") > /etc/pam_ldap.secret
chmod o+w /etc/libnss-ldap.conf

sed 's/^rootbinddn .*$/rootbinddn uid=ispman,ou=admins,o=ispman/' /etc/libnss-ldap.conf > /etc/libnss-ldap.conf.temp ; mv /etc/libnss-ldap.conf.temp /etc/libnss-ldap.conf
sed 's/^base .*$/base o=ispman/' /etc/libnss-ldap.conf > /etc/libnss-ldap.conf.temp ; mv /etc/libnss-ldap.conf.temp /etc/libnss-ldap.conf
sed 's/^uri .*$/uri ldap:\/\/127.0.0.1/' /etc/libnss-ldap.conf > /etc/libnss-ldap.conf.temp ; mv /etc/libnss-ldap.conf.temp /etc/libnss-ldap.conf



#!/bin/sh

rootbinddnpw=$(grep ldapRootPass /etc/ispman/ispman.conf | sed -e "s/^.*\ '\(.*\)';/\1/")
sed -i -e "s/^LDAPServer .*$/LDAPServer 127.0.0.1/" /etc/pure-ftpd/db/ldap.conf
sed -i -e "s/^LDAPBaseDN .*$/LDAPBaseDN o=ispman/" /etc/pure-ftpd/db/ldap.conf
sed -i -e "s/^LDAPBindDN.*$/LDAPBindDN uid=ispman,ou=admins,o=ispman/" /etc/pure-ftpd/db/ldap.conf
sed -i -e "s/^LDAPBindPW.*$/LDAPBindPW ${rootbinddnpw}/" /etc/pure-ftpd/db/ldap.conf

/etc/init.d/pure-ftpd-ldap restart


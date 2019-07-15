#!/bin/sh

### ldap stuff
# write slapd.conf
/etc/init.d/slapd stop
pgrep slapd && killall slapd 
mkdir /var/run/slapd/
chown openldap /var/run/slapd/
cat /usr/share/doc/ispman-doc/examples/openldap/slapd.ldapv3.conf.tmpl | /usr/share/ispman/bin/ispman.substConf > /etc/ldap/slapd.conf
cat snippets/slapd.conf.acl.appendme >> /etc/ldap/slapd.conf
# copy DB_CONFIG
cp snippets/DB_CONFIG /var/lib/ldap/

/etc/init.d/slapd start
# now load ldap stuff
cat /usr/share/ispman/conf/ldif/ispman.ldif | /usr/share/ispman/bin/ispman.substConf | /usr/share/ispman/bin/ispman.ldifload -f -


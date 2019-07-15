#!/bin/sh
### configure postfix
# postfix ldap maps
mkdir /etc/postfix/ispman/
cp  /usr/share/doc/ispman-doc/examples/postfix_configuration/with_cyrus_virtdomains/* /etc/postfix/ispman/
rpl ldap.example.com localhost  /etc/postfix/ispman/*

patch -i snippets/master.cf-nonchroot.diff /etc/postfix/master.cf
cat snippets/master.cf.appendme >> /etc/postfix/master.cf
cat snippets/main.cf.appendme  >> /etc/postfix/main.cf

# postfix sasl
mkdir /etc/postfix/sasl/
cp snippets/sasl-smtpd.conf /etc/postfix/sasl/smtpd.conf

addgroup postfix sasl
addgroup lmtp
TEMPPW=$(pwgen -B -1)
TEMPCRYPT=$(echo ${TEMPPW} | mkpasswd -s)
useradd -s /bin/false -p ${TEMPCRYPT} --gid lmtp lmtp
umask 700 ; echo "$(cat /etc/hostname)  lmtp:${TEMPPW}" > /etc/postfix/sasl_passwd
postmap /etc/postfix/sasl_passwd


/etc/init.d/postfix restart


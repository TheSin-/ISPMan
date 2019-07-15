#!/bin/sh

### configure cyrus
# imapd.conf 
patch --fuzz 10 -p1 -i snippets/imapd.conf.diff /etc/imapd.conf
# cyrus.conf
patch --fuzz 10 -p1 -i snippets/cyrus.conf.diff	/etc/cyrus.conf

# pop-before-smtp
patch --fuzz 10 -p1 -i snippets/pop-before-smtp.conf.diff /etc/pop-before-smtp/pop-before-smtp.conf
adduser --system lmtp
egrep -q  ^lmtp /etc/services || echo "lmtp            24/tcp" >> /etc/services
/etc/init.d/cyrus2.2 restart


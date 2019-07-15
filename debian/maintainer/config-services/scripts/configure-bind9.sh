#!/bin/sh

# patch --fuzz 10 -p1 -i snippets/bind9-include.diff /etc/bind/named.conf.local
# replaced the patch by a smarter grep/cat 

egrep -q  ^"include \"/etc/bind/named.conf.ispman\";" /etc/bind/named.conf.local || echo "include \"/etc/bind/named.conf.ispman\";" >> /etc/bind/named.conf.local

/etc/init.d/bind9 restart


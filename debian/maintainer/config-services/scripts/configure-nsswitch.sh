#!/bin/sh

patch -p1 --fuzz 5 -i snippets/nsswitch.conf.addldap.diff /etc/nsswitch.conf



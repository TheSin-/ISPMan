#!/bin/sh

### saslauthd
patch --fuzz 10 -p1 -i snippets/saslauthd.diff /etc/default/saslauthd
/etc/init.d/saslauthd start


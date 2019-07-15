#!/bin/sh
## agent start via monit
echo "include  /usr/share/doc/ispman-doc/examples/monit.include" >> /etc/monit/monitrc
patch --fuzz 10 -p1 -i snippets/monit-default-start.diff /etc/default/monit
/etc/init.d/monit restart


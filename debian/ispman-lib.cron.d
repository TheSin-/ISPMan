# this dumps slapd's ispman subtree to a file 
# m h dom mon dow user  command
# One per weekday:
03 1	* * *	root	[ -x /usr/sbin/ispman ] && ( umask 077 ; if [ ! -e /var/backups/ispman ]; then mkdir /var/backups/ispman; fi ; /usr/sbin/ispman ldifdump > /var/backups/ispman/ispman.ldif.dayofweek.$(date +\%w) )
# one at the beginning of the month
20 1	1 * *	root	[ -x /usr/sbin/ispman ] && ( umask 077 ; if [ ! -e /var/backups/ispman ]; then mkdir /var/backups/ispman; fi  ; /usr/sbin/ispman ldifdump > /var/backups/ispman/ispman.ldif.month.$(date +\%Y\%m\%d) )


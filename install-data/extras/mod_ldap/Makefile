##
##  Makefile -- Build procedure for ldap authentication Apache module
##

#   the used tools
APXS=apxs
APACHECTL=apachectl

#   additional user defines, includes and libraries
#DEF=-Dmy_define=my_value
INC="-I/usr/include -I/usr/include/ldap.h -I/usr/include/lber.h -I/usr/include/sasl.h"
LIB="/usr/lib/libldap.a  /usr/lib/liblber.a   /usr/lib/libsasl.so -L/usr/lib"

#   the default target
all: mod_ldap.so

#   compile the DSO file
mod_ldap.so: mod_ldap.c
	$(APXS) -c $(DEF) $(INC) $(LIB) -lldap -llber mod_ldap.c

#   install the DSO file into the Apache installation
#   and activate it in the Apache configuration
install: all
	$(APXS) -i -a -n 'ldap' mod_ldap.so

#   cleanup
clean:
	-rm -f mod_ldap.o mod_ldap.so

#   simple test
test: reload
	lynx -mime_header http://localhost/ldap

#   reload the module by installing and restarting Apache
reload: install restart

#   the general Apache start/restart/stop procedures
start:
	$(APACHECTL) start
restart:
	$(APACHECTL) restart
stop:
	$(APACHECTL) stop


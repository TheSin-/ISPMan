include ../../makedefs
INSTALL = ../../install-sh

CONFLDIFS = \
	base.ldif \
	conf.ldif conf.ftp_vars.ldif conf.dns_vars.ldif conf.ldap_vars.ldif \
	conf.mail_vars.ldif conf.sys_vars.ldif conf.account_vars.ldif \
	conf.apache_vars.ldif conf.db_vars.ldif \
	counters.ldif hosts.ldif dns.ldif hostgroups.ldif \
	domainServices.ldif radiusprofiles.ldif processes.ldif


all: ispman_install.ldif


ispman_install.ldif: ${CONFLDIFS}
	cat $(CONFLDIFS) > ispman_install.ldif
	perl make.pl >ispmanVarSort.conf


install: ispman_install.ldif
	$(INSTALL) -c ispman_install.ldif $(DESTDIR)$(PREFIX)/conf/ldif/ispman.ldif

clean:
	-rm ispman_install.ldif
	-rm ispmanVarSort.conf

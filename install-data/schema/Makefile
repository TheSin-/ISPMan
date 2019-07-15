include ../../makedefs
INSTALL = ../../install-sh
INSTALL_DIR = $(DESTDIR)$(PREFIX)/conf/schema
SCHEMAS = ispman.schema dnszone.schema pureftpd.schema RADIUS-LDAPv3.schema


CLASSES = $(shell find . -name objc.txt -print)
ATTRS   = $(shell find . -name attr.txt -print)

all:	$(SCHEMAS)

ispman.schema: $(CLASSES) $(ATTRS)
	@echo building schema
	@cat $(CLASSES) > ispman.oc.schema
	@cat $(ATTRS) > ispman.at.schema
	@cat schema.head ispman.at.schema ispman.oc.schema > ispman.schema

install: $(SCHEMAS)
	@list='$(SCHEMAS)'; for p in $$list; do \
	   if test -f $$p; then \
	     echo "$(INSTALL) $$p $(INSTALL_DIR)/`echo $$p`"; \
	     $(INSTALL) -c $$p $(INSTALL_DIR)/`echo $$p`; \
	   else :; fi; \
	 done


clean:
	rm -f ispman.at.schema ispman.oc.schema ispman.schema

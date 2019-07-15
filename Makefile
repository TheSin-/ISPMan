VERSION=cat VERSION
INSTALL=./install-sh
DESTDIR=

include makedefs


first: default


default: ispman


# generate schema files
build-schema:
	$(MAKE) -C install-data/schema all

# generate prime-ldif 
build-ldif:
	$(MAKE) -C install-data/ldifs all

# constructing ispman.conf 	
build-config: build-ldif build-schema
	@cat install-data/ispman.config install-data/ldifs/ispmanVarSort.conf \
		> install-data/ispman.conf
	@echo '1;' >> install-data/ispman.conf

	
# prepare ispman files
ispman: build-config
	# give the exec permission to install-sh
	chmod +x install-sh

	
# install schema files
install-schema:
	@echo Installing LDAP schema files; \
		$(MAKE) -C install-data/schema install

# install prime-ldif
install-ldif:
	@echo Installing prime LDIF file; \
		$(MAKE) -C install-data/ldifs install

# install documentation & examples
install-doc:
	@echo ""
	@echo "Installing documentation & examples:"
	@echo ""

	@echo "...creating dir $(DESTDIR)$(PREFIX)/docs"; \
	$(INSTALL) -d -m 755 $(DESTDIR)$(PREFIX)/docs
	
	$(INSTALL) -c -m 644 VERSION $(DESTDIR)$(PREFIX)/docs
	
	@list="`find docs -type f | grep -v CVS | grep -v '/\.'`"; \
	for p in $$list; do \
	   echo "...installing $$p to $(DESTDIR)$(PREFIX)"; \
	   $(INSTALL) -c -m 644 $$p $(DESTDIR)$(PREFIX)/$$p; \
	done
	
	@list="`cd install-data; find examples -type f | grep -v CVS | grep -v '/\.'`"; \
	for p in $$list; do \
	   echo "...installing $$p to $(DESTDIR)$(PREFIX)/docs"; \
	   $(INSTALL) -c -m 644 install-data/$$p $(DESTDIR)$(PREFIX)/docs/$$p; \
	done
	
# install base files
install-base: install-base-dirs install-schema install-ldif
	@echo ""
	@echo "Installing ISPMan Base Components:"
	@echo ""
	
	@echo "...installing config files"; \
	$(INSTALL) -c -m 640 install-data/ispman.conf $(DESTDIR)$(PREFIX)/conf/ispman.conf.example; \

	@list="`find lib -type f | grep -v CVS | grep -v '/\.'`"; \
	for p in $$list; do \
	   echo "...installing $$p to $(DESTDIR)$(PREFIX)"; \
	   $(INSTALL) -c -m 644 $$p $(DESTDIR)$(PREFIX)/$$p; \
	done

	@list="`cd install-data; find templates -type f | grep -v CVS | grep -v '/\.'`"; \
	for p in $$list; do \
	   echo "...installing $$p to $(DESTDIR)$(PREFIX)"; \
	   $(INSTALL) -c -m 644 install-data/$$p $(DESTDIR)$(PREFIX)/$$p; \
	done


# install cli and agent binaries
install-bin: install-base install-bin-dirs
	@echo ""
	@echo "Installing ISPMan binaries & agent:"
	@echo ""
	
	@list="`find bin -type f | grep -v CVS | grep -v '/\.'`"; \
	for p in $$list; do \
	   echo "...installing $$p to $(DESTDIR)$(PREFIX)"; \
	   $(INSTALL) -c -m 750 $$p $(DESTDIR)$(PREFIX)/$$p; \
	done

	@list="`find tasks -type f | grep -v CVS | grep -v '/\.'`"; \
	for p in $$list; do \
	   echo "...installing $$p to $(DESTDIR)$(PREFIX)"; \
	   $(INSTALL) -c -m 640 $$p $(DESTDIR)$(PREFIX)/$$p; \
	done


# install files for web UI
install-web: install-base install-web-dirs
	@echo ""
	@echo "ISPMan web interface"
	@echo ""
	
	@list="`find locale -type f | grep -v CVS | grep -v '/\.'`"; \
	for p in $$list; do \
	   echo "...installing $$p to $(DESTDIR)$(PREFIX)/conf"; \
	   $(INSTALL) -c -m 644 $$p $(DESTDIR)$(PREFIX)/conf/$$p; \
	done

	@echo "...installing nls.conf to $(DESTDIR)$(PREFIX)/conf"; \
	$(INSTALL) -c -m 644 install-data/nls.conf $(DESTDIR)$(PREFIX)/conf

	@list="`cd ispman-web; find htdocs -type f | grep -v CVS | grep -v '/\.'`"; \
	for p in $$list; do \
	   echo "...installing $$p to $(DESTDIR)$(PREFIX)"; \
	   $(INSTALL) -c -m 640 ispman-web/$$p $(DESTDIR)$(PREFIX)/$$p; \
	done

	@list="`cd ispman-web; find cgi-bin -type f | grep -v CVS | grep -v '/\.'`"; \
	for p in $$list; do \
	   echo "...installing $$p to $(DESTDIR)$(PREFIX)"; \
	   $(INSTALL) -c -m 640 ispman-web/$$p $(DESTDIR)$(PREFIX)/$$p; \
	done

	@echo "...setting mode +x on $(DESTDIR)$(PREFIX)/htdocs/admin/index.cgi"; \
	chmod +x $(DESTDIR)$(PREFIX)/htdocs/admin/index.cgi


# create base directories
install-base-dirs:
	@for d in $(DESTDIR)$(PREFIX) $(DESTDIR)$(PREFIX)/templates; do \
	   echo "...creating dir $$d"; \
	   $(INSTALL) -d -m 755 $$d; \
	done

# create bin directories
install-bin-dirs:
	@for d in $(DESTDIR)$(PREFIX)/bin $(DESTDIR)$(PREFIX)/tasks \
	          $(DESTDIR)$(PREFIX)/var; do \
	   echo "...creating dir $$d"; \
	   $(INSTALL) -d -m 755 $$d; \
	done

# create web directories
install-web-dirs:
	@for d in $(DESTDIR)$(PREFIX)/conf/locale \
	          $(DESTDIR)$(PREFIX)/htdocs $(DESTDIR)$(PREFIX)/cgi-bin; do \
	   echo "...creating dir $$d"; \
	   $(INSTALL) -d -m 755 $$d; \
	done

# generic install rule
install: install-base install-bin install-web install-doc


# cleanup generated files
clean:
	$(MAKE) -C install-data/schema clean
	$(MAKE) -C install-data/ldifs clean
	cd contrib/perl && $(MAKE) clean
	-rm install-data/ispman.conf

# remove any leftover files too
realclean: clean
	find . -name \*~ -exec rm \{\} \;
	find . -name \*.orig -exec rm \{\} \;
	find . -name \*.rej -exec rm \{\} \;
	find . -name \*.bak -exec rm \{\} \;
	find . -name .#\* -exec rm \{\} \;
	find . -name .build -exec rm \{\} \;

# build dist tarball
dist: 
	mkdir -p dist/ispman-`cat VERSION`;
	cp -fa `cat DISTFILES` dist/ispman-`cat VERSION`	
	cd dist; find . -type f -name Root | awk '{print "echo :pserver:anonymous@ispman.cvs.sourceforge.net:/cvsroot/ispman  > "$$1}'  | sh
	cd dist; tar czf ispman-`cat ../VERSION`.tar.gz ispman-`cat ../VERSION`

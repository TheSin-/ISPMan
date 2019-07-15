DESTDIR=

include ../../makedefs

MODULES = $(shell cat modules | grep -v '^\#' | grep -v '^$$'| awk '{print $$1}')
MODFILES = $(shell cat modules | grep -v '^\#' | grep -v '^$$'| awk '{print $$2}')


# install bundled CPAN modules
install-bundled:
	@[ -d .build ] || mkdir .build
	@list="$(MODFILES)";\
	PERL5LIB=$(PREFIX)/lib; export PERL5LIB;\
	cd .build;\
	for p in $$list; do \
	   echo "";\
	   echo "Building $$p"; \
	   tar xzf ../$$p ;\
	   cd `echo $$p | sed -e "s/.*_//" -e "s/\.tgz//" -e "s/\.tar\.gz//"`;\
	   perl Makefile.PL INSTALLDIRS=perl LIB=$(PREFIX)/lib \
			    INSTALLMAN1DIR=$(PREFIX)/man/man1 \
			    INSTALLMAN3DIR=$(PREFIX)/man/man3;\
	   make all ;\
	   make install ;\
	   cd ..;\
	done

# install latest modules from CPAN
install-cpan install-cpan-ispman:
	perl -MCPAN -e '\
		use lib "$(PREFIX)/lib";\
		@list = qw( $(MODULES) );\
		CPAN::Config->defaults;\
		CPAN::Config->edit("makepl_arg", q[INSTALLDIRS=perl LIB=$(PREFIX)/lib INSTALLMAN1DIR=$(PREFIX)/man/man1 INSTALLMAN3DIR=$(PREFIX)/man/man3]); \
		install $$_ for @list; '

# install latest modules from CPAN
install-cpan-site:
	perl -MCPAN -e '\
		@list = qw( $(MODULES) ); \
		CPAN::Config->defaults; \
		CPAN::Config->edit("makepl_arg", q[INSTALLDIRS=site]); \
		install $$_ for @list; '

clean:
	rm -rf .build

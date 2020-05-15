
-include autoconf/Makefile.config

all: build

-include ocp-autoconf.d/Makefile

build:
	dune build

install:
	dune install

ocp-build-conf:
	ocp-autoconf

ocp-build: ocp-build-build $(PROJECT_BUILD)

ocp-build-install: ocp-build-install $(PROJECT_INSTALL)

ocp-build-clean: ocp-build-clean $(PROJECT_CLEAN)

distclean: clean ocp-distclean $(PROJECT_DISTCLEAN)
	find . -name '*~' -exec rm -f {} \;

-include autoconf/Makefile.rules

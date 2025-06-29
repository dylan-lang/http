# The impetus for this Makefile was to include Git version info in the generated
# executable and to install http-server-app as a static executable named simply
# "http-server". The expectation is that during development people will use `deft build`
# or `deft test`.

DYLAN		?= $${HOME}/dylan

.PHONY: build clean install

git_version := $(shell git describe --tags --always --match 'v*')

# We assume `deft update` is invoked manually before running make.

build: common/*.dylan common/*.lid server/*/*.dylan server/*/*.lid
	file="server/core/server.dylan"; \
	  orig=$$(mktemp); \
	  temp=$$(mktemp); \
	  cp -p $${file} $${orig}; \
	  cat $${file} | sed "s|_NO_VERSION_SET_|${git_version} built on $$(date -Iseconds)|g" > $${temp}; \
	  mv $${temp} $${file}; \
	  deft build http-server-app; \
	  cp -p $${orig} $${file}

install: build
	mkdir -p $(DYLAN)/bin
	mkdir -p $(DYLAN)/install/http/bin
	mkdir -p $(DYLAN)/install/http/lib
	cp _build/bin/http-server-app $(DYLAN)/install/http/bin/http-server
	cp -r _build/lib/lib* $(DYLAN)/install/http/lib/
	ln -s -f $$(realpath $(DYLAN)/install/http/bin/http-server) $(DYLAN)/bin/http-server

clean:
	rm -rf _build _packages registry

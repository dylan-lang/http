# The impetus for this Makefile was to include Git version info in the generated
# executable and to install http-server-app as a static executable named simply
# "http-server". The expectation is that during development people will use `deft build`
# or `deft test`.

# TODO: use the .gitattributes filtering that Deft uses instead of this version hack.

DYLAN		?= $${HOME}/dylan

.PHONY: build clean install

build:
	file="server/core/server.dylan"; \
	backup=$$(mktemp); \
	temp=$$(mktemp); \
	cp -p $${file} $${backup}; \
	cat $${file} | sed "s,/.__./.*/.__./,/*__*/ \"$$(git describe --always --tags)\" /*__*/,g" > $${temp}; \
	mv $${temp} $${file}; \
	dylan update; \
	dylan build --unify http-server-app; \
	cp -p $${backup} $${file}

install: build
	mkdir -p $(DYLAN)/bin
	cp _build/sbin/http-server-app $(DYLAN)/bin/http-server

clean:
	rm -rf _build registry

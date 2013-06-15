all: client common server

.PHONY: client common server client-test common-test server-test clean

client:
	dylan-compiler -build http-client

common:
	dylan-compiler -build http-common

server:
	dylan-compiler -build http-server

client-test:
	dylan-compiler -build http-client-test-suite-app

protocol-test:
	dylan-compiler -build http-protocol-test-suite-app

common-test:
	dylan-compiler -build http-common-test-suite

server-test:
	dylan-compiler -build http-server-tests

clean:
	rm -rf _build

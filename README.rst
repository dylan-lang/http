****
HTTP
****

Dylan HTTP server, client, tests, and examples.


Documentation
=============

Full documentation is here:
https://docs.opendylan.org/packages/http/documentation/source/index.html

To build the documentation from source requires Sphinx::

  $ sudo apt install sphinx-doc   # Install sphinx-build command
  $ dylan update                  # Install sphinx-extensions package
  $ cd documentation
  $ make html
  $ cd build/html
  $ python -m http.server


Testing
=======

As of Dec 2020 there are serious problems with the tests and many of them hang.
Fixing this should be #1 priority.

However, to run all the tests::

  $ for suite in common client server; do
      dylan build --all
      _build/bin/http-${suite}-test-suite
    done

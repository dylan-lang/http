**************
HTTP Libraries
**************

HTTP server, client, tests, and examples.  All required repositories
are included as submodules so if you clone with --recursive you should
have everything you need for building.


Documentation
=============

Building the documentation requires that Python be able to find the
`Dylan extensions to Sphinx <https://github.com/dylan-lang/sphinx-extensions>`_.

The easiest way to do this is to check them out somewhere and put
them on your ``PYTHONPATH``::

    export PYTHONPATH=path/to/sphinx-extensions:$PYTHONPATH

You can clone sphinx-extensions with::

    git clone git@github.com:dylan-lang/sphinx-extensions


Testing
=======

As of Dec 2020 there are serious problems with the tests and many of them hang.
Fixing this should be #1 priority.

However, to run all the tests::

  $ for suite in common client server; do
      dylan-compiler -build http-${suite}-test-suite
      _build/bin/http-${suite}-test-suite
    done

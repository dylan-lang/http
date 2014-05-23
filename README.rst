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
them on your ``PYTHONPATH``:

    export PYTHONPATH=path/to/sphinx-extensions:$PYTHONPATH

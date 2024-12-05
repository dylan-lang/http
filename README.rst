****
HTTP
****

Dylan HTTP server, client, tests, and examples.


Documentation
=============

Full documentation is here:
https://docs.opendylan.org/packages/http/documentation/source/index.html

To build the documentation from source requires `Sphinx <https://sphinx-doc.org>`_, the
`Furo <https://github.com/pradyunsg/furo>`_ theme, and `sphinx-copybutton
<https://sphinx-copybutton.readthedocs.io>`_.

::
   $ pip3 install -U Sphinx furo sphinx-copybutton
   $ deft update
   $ make -C documentation html
   $ deft build http-server-app
   $ _build/bin/http-server-app -d documentation/build/html

Then navigate to http://localhost:8000 in your browser to view the documentation.


Testing
=======

As of Dec 2020 there are serious problems with the tests and many of them hang.
Fixing this should be #1 priority.

In any case, to run all the tests::

  $ deft build --all
  $ for suite in common client server; do
      _build/bin/http-${suite}-test-suite
    done

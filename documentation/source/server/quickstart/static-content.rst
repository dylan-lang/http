Serving Static Content
======================

`Next: Serving Dynamic Content <dynamic-content.html>`_

`Back to top <00-index.html>`_

This example will show you how to use the Dylan web server (http-server) to
serve static content from the file-system.  First I'll go through the
process line by line and then will show the complete code.

First, we set up the usual library and module definitions.  "http-server"
is all you need other than common-dylan.

.. code-block:: dylan

    Module: dylan-user

    define library web60-static-content
      use common-dylan;
      use http-server;
    end;

    define module web60-static-content
      use common-dylan;
      use http-server;
    end;

Next we need an HTTP server.  We'll make it listen to all interfaces
on port 8888:

.. code-block:: dylan

      let server = make(<http-server>,
                        listeners: list("0.0.0.0:8888"));

Instances of :class:`<resource>` are responsible for generating HTTP
responses.  To serve static content we create a
:class:`<directory-resource>` whose file-system directory is ``/tmp``
and which allows directory listings:

.. code-block:: dylan

      let resource = make(<directory-resource>,
			  directory: "/tmp",    // c:\tmp on Windows
			  allow-directory-listing?: #t);

Next we connect the resource to a specific URL on the server:

.. code-block:: dylan

      add-resource(server, "/", resource);

Last, we start the server:

.. code-block:: dylan

      start-server(server);

If you wanted to start the server in a separate thread you could say
this instead:

.. code-block:: dylan

      start-server(server, background: #t);

The entire example, including the library and module definitions,
looks like this:

.. code-block:: dylan

    ---- File: library.dylan ----
    Module: dylan-user

    define library web60-static-content
      use common-dylan;
      use http-server;
    end;

    define module web60-static-content
      use common-dylan;
      use http-server;
    end;

    ---- File: main.dylan ----
    Module: web60-static-content

    define function main ()
      let server = make(<http-server>,
			listeners: list("0.0.0.0:8888"));
      let resource = make(<directory-resource>,
			  directory: "c:/tmp",
			  allow-directory-listing?: #t);
      add-resource(server, "/", resource);
      start-server(server);
    end;

    main();


Run this example and point your browser at `http://127.0.0.1:8888/
<http://127.0.0.1:8888/>`_.

Note that serving static content is one of the things built into the
http-server library itself, so if that's all you want to do this will
accomplish the same thing::

    http-server --listen 0.0.0.0:8888 --directory /tmp

`Next: Serving Dynamic Content <dynamic-content.html>`_

`Back to top <00-index.html>`_

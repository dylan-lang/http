Serving Dynamic Content
=======================

`Previous: Serving Static Content <static-content.html>`_

`Back to top <00-index.html>`_

This example will show how to dynamically generate the contents of a web page.

First, the ever-exciting library and module definitions.  In addition to ``common-dylan`` and ``http-server`` we need ``streams`` for writing data to the response and ``date`` so we can show something dynamic happening:

.. code-block:: dylan

    define library web60-dynamic-content
      use common-dylan;
      use io, import: { streams };
      use http-common;
      use http-server;
      use system, import: { date };
    end;

    define module web60-dynamic-content
      use common-dylan;
      use date, import: { as-iso8601-string, current-date };
      use http-common;
      use http-server;
      use streams, import: { write };
    end;

A web page is a resource mapped to a URL inside the web server.  To create a resource we subclass :class:`<resource>`:

.. code-block:: dylan

    define class <clock-page> (<resource>) end;

To make our resource do something we define a method on :func:`respond`.  (If we only wanted to implement the GET request method we could define a method on :func:`respond-to-get` instead.)

.. code-block:: dylan

    define method respond (page :: <clock-page>, #key)
      let stream = current-response();
      set-header(stream, "Content-Type", "text/html");
      let date = as-iso8601-string(current-date());
      write(stream, concatenate("<html><body>", date, "</body></html>"));
    end;

:func:`current-response` returns the active :class:`<response>` object.  To send data back to the client we write to the current response.

.. code-block:: dylan

    let server = make(<http-server>,
                      listeners: list("0.0.0.0:8888"));
    add-resource(server, "/", make(<clock-page>));
    start-server(server);

In the `previous example <static-content.html>`_ we already saw how to create and start a server, so the new bit here is using :func:`add-resource` to map a URL to a :class:`<resource>`.  The first argument to :func:`add-resource` is the URL router.  (In `Routes <http://routes.groovie.org>`_ terminology it would be a "mapper".)  For convenience, an :class:`<http-server>` is a kind of router so we can add resources directly to the server.  In a future example, I will show how to do more complex URL routing, which will explain the reason for the mysterious ``#key`` in the ``respond`` definition above.

Here's the complete code:

.. code-block:: dylan

    ---- File: library.dylan ----
    Module: dylan-user

    define library web60-dynamic-content
      use common-dylan;
      use io, import: { streams };
      use http-common;
      use http-server;
      use system, import: { date };
    end;

    define module web60-dynamic-content
      use common-dylan;
      use date, import: { as-iso8601-string, current-date };
      use http-common;
      use http-server;
      use streams, import: { write };
    end;

    ---- File: main.dylan ----
    Module: web60-dynamic-content

    define class <clock-page> (<resource>)
    end;

    define method respond (page :: <clock-page>, #key)
      let stream = current-response();
      set-header(stream, "Content-Type", "text/html");
      let date = as-iso8601-string(current-date());
      write(stream, concatenate("<html><body>", date, "</body></html>"));
    end;

    let server = make(<http-server>,
                      listeners: list("0.0.0.0:8888"));
    add-resource(server, "/", make(<clock-page>));
    start-server(server);


| `Previous: Serving Static Content <static-content.html>`_
| `Next: Static URL Routing <static-routing.html>`_

`Back to top <00-index.html>`_

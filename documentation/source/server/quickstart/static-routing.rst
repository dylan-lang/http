Static URL Routing
==================

`Previous: Serving Dynamic Content <dynamic-content.html>`_

`Back to top <00-index.html>`_

This example will show how URL routing works in the Dylan web server, and how to handle optional URL elements for your resources.

I will skip the library and module definitions since they're essentially the same as in `the previous examples <00-index.html>`_, but they are included in the full code listing at the end.

In the Dylan web server, :func:`add-resource` maps a URL to a resource.  The default implementation of :func:`add-resource` builds up a tree structure whose paths are defined by URL path elements and whose leaves are :class:`<resource>` objects.  (`Idea stolen from twisted.web <http://twistedmatrix.com/documents/current/web/howto/web-in-60/static-dispatch.html>`_.  I hope to add a simple regular expression based router in the future, for comparison.)

For this example we'll use a hypothetical wiki as our web application and add three different URLs for it.  First, we need a ``$wiki-app`` resource that will be the root of all wiki URLs, and specialized resource classes to provide behavior.  We'll implement page, user and group resources for the wiki:

.. code-block:: dylan

    define constant $wiki-app = make(<resource>);
    define class <page> (<resource>) end;
    define class <user> (<resource>) end;
    define class <group> (<resource>) end;

Now wiki resources can be added as children of ``$wiki-app``:

.. code-block:: dylan

    add-resource($wiki-app, "page/{action}/{title}/{version?}", make(<page>));
    add-resource($wiki-app, "user/{action}/{name}", make(<user>));
    add-resource($wiki-app, "group/{action}/{name}", make(<group>))

The URL path elements surrounded by curly braces are "path variables".  Let's decompose the first URL above: ``page/{action}/{title}/{version?}``.  The first element, "page" must be matched literally.  The {action} and {title} elements are required path variables; if either is missing 404 is returned.  The last element, {version?} is optional, as indicated by the '?' character.  (Two more path variable types that aren't shown here are available: ``{v*}`` matches zero or more path elements and ``{v+}`` matches one or more.)

In order to define the behavior of our various resources we define methods on the :func:`respond` generic function.  Note that each path variable in the URL passed to :func:`add-resource` corresponds to a keyword in the :func:`respond` method for the resource being added.  (For our purposes the behavior will be to simply display the values of all the path variables.)

.. code-block:: dylan

    define method respond
        (resource :: <page>, #key action, title, version)
      output("<html><body>action = %s, title = %s, version = %s</body></html>",
             action, title, version);
    end;

The ``respond`` methods for ``<user>`` and ``<group>`` are similar.  Notice that ``version`` may be ``#f`` but ``action`` and ``title`` will always be strings.

Lastly, we'll connect ``$wiki-app`` to the root URL (/) and start the server:

.. code-block:: dylan

    define constant $server = make(<http-server>, listeners: #("0.0.0.0:8888"));
    add-resource($server, "/", $wiki-app);
    start-server($server);

That's it.  Run the server and click on some of these URLs to see the corresponding behavior:

* http://127.0.0.1:8888/page/view/Foo/3
* http://127.0.0.1:8888/page/view/Foo
* http://127.0.0.1:8888/user/add/cgay
* http://127.0.0.1:8888/group/remove/administrators

Here's the full code listing:

.. code-block:: dylan

    -----------library.dylan------------
    Module: dylan-user

    define library web60-static-routing
      use common-dylan;
      use http-server;
    end;

    define module web60-static-routing
      use common-dylan;
      use http-server;
    end;

    -----------static-routing.dylan------------
    Module: web60-static-routing

    define constant $wiki-app = make(<resource>);

    define class <page> (<resource>) end;
    define class <user> (<resource>) end;
    define class <group> (<resource>) end;

    add-resource($wiki-app, "page/{action}/{title}/{version?}", make(<page>));
    add-resource($wiki-app, "user/{action}/{name}", make(<user>));
    add-resource($wiki-app, "group/{action}/{name}", make(<group>));

    define method respond
	(resource :: <page>, #key action, title, version)
      output("<html><body>action = %s, title = %s, version = %s</body></html>",
	     action, title, version);
    end;

    define method respond
	(resource :: type-union(<user>, <group>), #key action, name)
      output("<html><body>action = %s, name = %s</body></html>",
	     action, name);
    end;

    define constant $server = make(<http-server>, listeners: #("0.0.0.0:8888"));
    add-resource($server, "/", $wiki-app);
    start-server($server);


`Previous: Serving Dynamic Content <dynamic-content.html>`_

`Back to top <00-index.html>`_

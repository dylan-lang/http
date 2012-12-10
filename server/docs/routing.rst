URL Routing
-----------

.. Copyright: See LICENSE in this distribution for details.

* A URL path is represented internally as a sequence of path elements.
  For example the URL string "/foo/bar/" is #("", "foo", "bar", "").
  Note that this is exactly equilavent to split("/foo/bar/", '/').

* URL paths are mapped to <resource>s.  The <resource>s are arranged
  in a tree structure whose paths are the URL path elements.

* add-resource accepts a <uri>, or a string path such as "/foo/bar/",
  or a sequence of path elements such as #("", "foo", "bar", "").

* add-resource divides the path into two parts: the prefix and suffix.
  The suffix begins where the first path variable, if any, is
  found.  For example, given the path
  ::

      /foo/bar/{id}/{tag}

  the prefix is ``#("foo", "bar")`` and the suffix is ``#("{id}",
  "{tag}")`` because path elements of the form {...} define path
  variables.

* The child resource is mapped to the prefix, and the suffix (the path
  variables) are passed as keyword arguments to the respond* methods,
  bound to the corresponding parts of the request URL.  For example::

      add-resource(container, "/foo/bar/{id}/{tag}", make(<my-resource>));

      define method respond-to-get (res :: <my-resource>, #key id, tag)
        ...
      end;

  When the request URL is /foo/bar/22/dylan, the respond-to-get method
  will be called like this::

      respond-to-get(my-resource, id: "22", tag: "dylan")

  If any path variable isn't provided in the request URL path then the
  request query values are used.  If the variable value isn't found
  in either the path or the query values it is not passed to
  respond.  Example::

     Request URL			respond Keyword Args
     /foo/bar				None
     /foo/bar/abc			id: "abc"
     /foo/bar/baz?tag=x			id: "baz", tag: "x"

* There is one case that can only be represented with a sequence of
  path elements rather than a string: a URL that ends with a / but
  also has path variables.  That is, because ``"/foo/bar/{x}/{tag}"``
  is split on '/', the path elements are::

      #("", "foo", "bar", "{x}", "{tag}")

  whereas for a trailing slash on /foo/bar/ the path elements should
  be::
  
      #("", "foo", "bar", "", "{x}", "{tag}")

  So when adding a resource with a trailing slash on the URL prefix
  and path variables, you must pass the above sequence to
  ``add-resource`` explicitly.  See the next point for one way to
  avoid this issue.

* There seems to be fairly broad agreement that having distinct
  meanings for /foo and /foo/ is a Bad Thing, which makes sense since
  it would be difficult for a user to predict the difference.
  However, it is often useful to ensure that they both map to the same
  resource rather than having one work and the other get a 404 error.

  add-resource accepts a ``slash:`` keyword argument.  When true (the
  default), ``add-resource`` will automatically map the child resource
  to both the given URL prefix and to the same URL with a trailing
  slash added.  That is,
  ::

     add-resource(parent, "foo/bar", child)

  will map child to both foo/bar and foo/bar/.  To change this
  behavior pass the ``slash:`` keyword argument:

  ``slash: #"canonical"``
      Make the trailing slash URL prefix canonical (by redirecting the
      one without the trailing slash).  Think "slash is canonical".

  ``slash: #"copy"``
      Map the given resource to both the gven URL and the URL with
      the trailing slash.  Think "slash is a copy".

  ``slash: #"redirect"``  (the default)
      Redirect the trailing slash version of the URL to the one with
      no trailing slash.  Think "slash is redirected".

  ``slash: #f``
      Don't map the trailing slash URL prefix to any resource.  Use
      this carefully since it can cause confusing results for users.


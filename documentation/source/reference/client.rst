***********************
The HTTP-CLIENT library
***********************

.. current-library:: http-client
.. current-module:: http-client


The HTTP-CLIENT module
======================

Requests
--------

.. generic-function:: http-request
   :sealed:

   Perform a complete HTTP request and response.

   :signature: http-request (request-method url #key headers parameters content follow-redirects stream) => (response)

   :parameter request-method: An instance of :drm:`<byte-string>`
   :parameter url: A string or a URI.
   :parameter #key headers: A :drm:`<table>` of strings mapping header names to values.
   :parameter #key parameters: A :drm:`<table>` of strings mapping query parameter names to values.
   :parameter #key content: An instance of :drm:`<string>` or :drm:`<table>`.  If given a
     :drm:`<table>` it will be converted to application/x-www-urlencoded-form.
   :parameter #key follow-redirects: A :drm:`<boolean>` or :drm:`<integer>`.  If an integer, this
     is the maximum number of redirects to follow.  ``#t`` means no limit.
   :parameter #key stream: A stream to which response content will be copied.  If this is provided
     the response data will not be stored in the :func:`response-content` slot.
   :value response: An instance of :class:`<http-response>`.

.. constant:: http-delete

   Convenience function for performing a DELETE request, equivalent to curry(http-request, "DELETE").

.. constant:: http-get

   Convenience function for performing a GET request, equivalent to curry(http-request, "GET").

.. constant:: http-head

   Convenience function for performing a HEAD request, equivalent to curry(http-request, "HEAD").

.. constant:: http-options

   Convenience function for performing an OPTIONS request, equivalent to curry(http-request, "OPTIONS").

.. constant:: http-post

   Convenience function for performing a POST request, equivalent to curry(http-request, "POST").

.. constant:: http-put

   Convenience function for performing a PUT request, equivalent to curry(http-request, "PUT").

.. generic-function:: send-request

   Send an HTTP request over an existing connection.  This is a low-level API.

   :signature: send-request (conn request-method url #rest start-request-args #key content #all-keys) => ()

   :parameter conn: An instance of :class:`<http-connection>`.
   :parameter request-method: An instance of :drm:`<byte-string>`.
   :parameter url: An instance :drm:`<string>` or :class:`<uri>`.
   :parameter #rest start-request-args: An instance of :drm:`<object>`.
   :parameter #key content: An instance of :drm:`<byte-string>`.

.. generic-function:: start-request

   Send the request line and request headers over an existing connection but do
   not send any content.  This is a low-level API.

   :signature: start-request (conn request-method url #key headers standard-headers http-version) => ()

   :parameter conn: An instance of :class:`<http-connection>`.
   :parameter request-method: An instance of :drm:`<byte-string>`.
   :parameter url: An instance :drm:`<string>` or :class:`<uri>`.
   :parameter #key headers: An instance of :drm:`<object>`.
   :parameter #key standard-headers: An instance of :drm:`<object>`.
   :parameter #key http-version: An instance of :drm:`<byte-string>`.

.. generic-function:: finish-request

   Finish sending a request over an existing connection by, for example, sending a zero-length chunk in a chunked request.  This is a low-level API.

   :signature: finish-request (conn) => ()

   :parameter conn: An instance of :class:`<http-connection>`.

Responses
---------

.. class:: <http-response>
   :open:
   :primary:

   All HTTP requests result in an instance of this class being created.

   :superclasses: :class:`<chunking-input-stream>`, :class:`<base-http-response>`, :class:`<message-headers-mixin>`

   :keyword content:

.. generic-function:: read-response
   :open:

   Read the content of a response from an existing connection after headers
   have already been read.  This is a low-level API.

   :signature: read-response (conn #key read-content response-class) => (response)

   :parameter conn: An instance of :class:`<http-connection>`.
   :parameter #key read-content: An instance of :drm:`<boolean>`.
   :parameter #key response-class: A subclass of :class:`<http-response>`.  The default is :class:`<http-response>`.
   :value response: An instance of :class:`<http-response>`.

.. generic-function:: response-content

   Fetch the content of a response from a :class:`<http-response>`.

   :signature: response-content (response) => (content)

   :parameter response: An instance of :class:`<http-response>`.
   :value content: ``#f`` or an instance of :drm:`<byte-string>`.


Errors
------

.. class:: <maximum-redirects-exceeded>
   :open:

   Signaled when an HTTP request results in too many redirects, based on the
   ``follow-redirects:`` keyword argument.

   :superclasses: :class:`<http-error>`


.. class:: <redirect-loop-detected>
   :open:

   Signaled when an HTTP request results in a redirect loop.

   :superclasses: :class:`<http-error>`


Connections
-----------

.. macro:: with-http-connection

   Open an HTTP connection and keep it open by automatically adding
   "Connection: Keep-alive" headers.  For most uses, this should be the only
   connection-related API needed.

   Example::

     with-http-connection (conn = "opendylan.org", port: 80, outgoing-chunk-size: 8192)
       send-request(conn, "GET", "/")
       let response :: <http-response> = read-response(conn);
       ...content is in response.response-content...

       send-request(conn, "POST", "/blah", content: "...");
       let response :: <http-response> = read-response(conn);
       ...
     end;

   Note that the port and outgoing-chunk-size specified above are the default
   values.  It is also possible to supply a :class:`<uri>` instead of a
   hostname and port number::

     with-http-connection (conn = uri) ... end
       

.. class:: <http-connection>
   :open:

   :superclasses: <basic-stream>:streams:io

   :keyword host:
   :keyword outgoing-chunk-size:


.. generic-function:: connection-host

   :signature: connection-host (object) => (#rest results)

   :parameter object: An instance of :drm:`<object>`.
   :value #rest results: An instance of :drm:`<object>`.

.. generic-function:: connection-port

   :signature: connection-port (conn) => (#rest results)

   :parameter conn: An instance of :drm:`<object>`.
   :value #rest results: An instance of :drm:`<object>`.

.. function:: make-http-connection

   :signature: make-http-connection (host-or-url #rest initargs #key port #all-keys) => (#rest results)

   :parameter host-or-url: An instance of :drm:`<object>`.
   :parameter #rest initargs: An instance of :drm:`<object>`.
   :parameter #key port: An instance of :drm:`<object>`.
   :value #rest results: An instance of :drm:`<object>`.

.. generic-function:: note-bytes-sent
   :open:

   :signature: note-bytes-sent (conn byte-count) => (#rest results)

   :parameter conn: An instance of :class:`<http-connection>`.
   :parameter byte-count: An instance of :drm:`<integer>`.
   :value #rest results: An instance of :drm:`<object>`.

.. generic-function:: outgoing-chunk-size

   :signature: outgoing-chunk-size (object) => (#rest results)

   :parameter object: An instance of :drm:`<object>`.
   :value #rest results: An instance of :drm:`<object>`.

.. generic-function:: outgoing-chunk-size-setter

   :signature: outgoing-chunk-size-setter (value object) => (#rest results)

   :parameter value: An instance of :drm:`<object>`.
   :parameter object: An instance of :drm:`<object>`.
   :value #rest results: An instance of :drm:`<object>`.

Miscellaneous
-------------

.. variable:: *http-client-log*

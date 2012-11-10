***********************
The HTTP-CLIENT library
***********************

.. current-library:: http-client
.. current-module:: http-client

The HTTP-CLIENT module
======================

.. variable:: *http-client-log*

.. class:: <http-connection>
   :open:

   :superclasses: <basic-stream>:streams:io

   :keyword host:
   :keyword outgoing-chunk-size:

.. class:: <http-response>
   :open:
   :primary:

   :superclasses: <chunking-input-stream>:http-common:http-common, <base-http-response>:http-common:http-common

   :keyword content:

.. class:: <maximum-redirects-exceeded>
   :open:

   :superclasses: <http-error>:http-common:http-common


.. class:: <redirect-loop-detected>
   :open:

   :superclasses: <http-error>:http-common:http-common


.. generic-function:: connection-host

   :signature: connection-host (object) => (#rest results)

   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: connection-port

   :signature: connection-port (conn) => (#rest results)

   :parameter conn: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: finish-request

   :signature: finish-request (conn) => ()

   :parameter conn: An instance of ``<http-connection>``.

.. generic-function:: http-get
   :open:

   :signature: http-get (url #key headers follow-redirects stream) => (response)

   :parameter url: An instance of ``<object>``.
   :parameter #key headers: An instance of ``<object>``.
   :parameter #key follow-redirects: An instance of ``<object>``.
   :parameter #key stream: An instance of ``<object>``.
   :value response: An instance of ``<http-response>``.

.. function:: make-http-connection

   :signature: make-http-connection (host-or-url #rest initargs #key port #all-keys) => (#rest results)

   :parameter host-or-url: An instance of ``<object>``.
   :parameter #rest initargs: An instance of ``<object>``.
   :parameter #key port: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: note-bytes-sent
   :open:

   :signature: note-bytes-sent (conn byte-count) => (#rest results)

   :parameter conn: An instance of ``<http-connection>``.
   :parameter byte-count: An instance of ``<integer>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: outgoing-chunk-size

   :signature: outgoing-chunk-size (object) => (#rest results)

   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: outgoing-chunk-size-setter

   :signature: outgoing-chunk-size-setter (value object) => (#rest results)

   :parameter value: An instance of ``<object>``.
   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: read-response
   :open:

   :signature: read-response (conn #key read-content response-class) => (response)

   :parameter conn: An instance of ``<http-connection>``.
   :parameter #key read-content: An instance of ``<boolean>``.
   :parameter #key response-class: An instance of ``subclass(<http-response>)``.
   :value response: An instance of ``<http-response>``.

.. generic-function:: response-content

   :signature: response-content (object) => (#rest results)

   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: send-request

   :signature: send-request (conn request-method url #rest start-request-args #key content #all-keys) => ()

   :parameter conn: An instance of ``<http-connection>``.
   :parameter request-method: An instance of ``<request-method>:http-client-internals``.
   :parameter url: An instance of ``type-union(<uri>, <string>)``.
   :parameter #rest start-request-args: An instance of ``<object>``.
   :parameter #key content: An instance of ``<byte-string>``.

.. generic-function:: start-request

   :signature: start-request (conn request-method url #key headers standard-headers http-version) => ()

   :parameter conn: An instance of ``<http-connection>``.
   :parameter request-method: An instance of ``<request-method>:http-client-internals``.
   :parameter url: An instance of ``type-union(<uri>, <string>)``.
   :parameter #key headers: An instance of ``<object>``.
   :parameter #key standard-headers: An instance of ``<object>``.
   :parameter #key http-version: An instance of ``<http-version>:http-client-internals``.

.. macro:: with-http-connection

.. current-module:: http-client-internals

The HTTP-CLIENT-INTERNALS module
================================

.. variable:: *http-client-log*

.. class:: <http-connection>
   :open:

   :superclasses: <basic-stream>

   :keyword host:
   :keyword outgoing-chunk-size:

.. class:: <http-response>
   :open:
   :primary:

   :superclasses: <chunking-input-stream>, <base-http-response>

   :keyword content:

.. class:: <maximum-redirects-exceeded>
   :open:

   :superclasses: <http-error>


.. class:: <redirect-loop-detected>
   :open:

   :superclasses: <http-error>


.. generic-function:: connection-host

   :signature: connection-host (object) => (#rest results)

   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: connection-port

   :signature: connection-port (conn) => (#rest results)

   :parameter conn: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: connection-socket

   :signature: connection-socket (object) => (#rest results)

   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: finish-request

   :signature: finish-request (conn) => ()

   :parameter conn: An instance of ``<http-connection>``.

.. generic-function:: http-get
   :open:

   :signature: http-get (url #key headers follow-redirects stream) => (response)

   :parameter url: An instance of ``<object>``.
   :parameter #key headers: An instance of ``<object>``.
   :parameter #key follow-redirects: An instance of ``<object>``.
   :parameter #key stream: An instance of ``<object>``.
   :value response: An instance of ``<http-response>``.

.. function:: make-http-connection

   :signature: make-http-connection (host-or-url #rest initargs #key port #all-keys) => (#rest results)

   :parameter host-or-url: An instance of ``<object>``.
   :parameter #rest initargs: An instance of ``<object>``.
   :parameter #key port: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: note-bytes-sent
   :open:

   :signature: note-bytes-sent (conn byte-count) => (#rest results)

   :parameter conn: An instance of ``<http-connection>``.
   :parameter byte-count: An instance of ``<integer>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: outgoing-chunk-size

   :signature: outgoing-chunk-size (object) => (#rest results)

   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: outgoing-chunk-size-setter

   :signature: outgoing-chunk-size-setter (value object) => (#rest results)

   :parameter value: An instance of ``<object>``.
   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: read-response
   :open:

   :signature: read-response (conn #key read-content response-class) => (response)

   :parameter conn: An instance of ``<http-connection>``.
   :parameter #key read-content: An instance of ``<boolean>``.
   :parameter #key response-class: An instance of ``subclass(<http-response>)``.
   :value response: An instance of ``<http-response>``.

.. generic-function:: response-content

   :signature: response-content (object) => (#rest results)

   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: send-request

   :signature: send-request (conn request-method url #rest start-request-args #key content #all-keys) => ()

   :parameter conn: An instance of ``<http-connection>``.
   :parameter request-method: An instance of ``<request-method>``.
   :parameter url: An instance of ``type-union(<uri>, <string>)``.
   :parameter #rest start-request-args: An instance of ``<object>``.
   :parameter #key content: An instance of ``<byte-string>``.

.. generic-function:: start-request

   :signature: start-request (conn request-method url #key headers standard-headers http-version) => ()

   :parameter conn: An instance of ``<http-connection>``.
   :parameter request-method: An instance of ``<request-method>``.
   :parameter url: An instance of ``type-union(<uri>, <string>)``.
   :parameter #key headers: An instance of ``<object>``.
   :parameter #key standard-headers: An instance of ``<object>``.
   :parameter #key http-version: An instance of ``<http-version>``.

.. macro:: with-http-connection



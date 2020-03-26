***********************
The HTTP-SERVER library
***********************

.. current-library:: http-server
.. current-module:: http-server

The HTTP-SERVER module
======================

.. variable:: *command-line-parser*

.. variable:: *log-content?*

.. class:: <abstract-resource>
   :open:
   :abstract:

   :superclasses: <object>


.. class:: <abstract-rewrite-rule>
   :open:
   :abstract:

   :superclasses: <object>

   :keyword redirect-code:
   :keyword terminal?:

.. class:: <abstract-router>
   :open:
   :abstract:

   :superclasses: <object>


.. class:: <configuration-error>

   :superclasses: <http-server-api-error>


.. class:: <directory-resource>
   :open:

   :superclasses: <resource>

   :keyword allow-directory-listing?:
   :keyword allow-multi-views?:
   :keyword default-documents:
   :keyword directory:
   :keyword follow-symlinks?:

.. class:: <function-resource>
   :open:

   :superclasses: <resource>

   :keyword function:
   :keyword methods:

.. class:: <http-server>
   :open:

   :superclasses: <multi-logger-mixin>:httpi, <abstract-router>

   :keyword clients-shutdown-notification:
   :keyword debug:
   :keyword default-virtual-host:
   :keyword listeners:
   :keyword listeners-shutdown-notification:
   :keyword lock:
   :keyword media-type-map:
   :keyword server-root:
   :keyword session-id:
   :keyword session-max-age:
   :keyword use-default-virtual-host?:
   :keyword virtual-hosts:

.. class:: <http-server-api-error>
   :open:

   :superclasses: <http-server-error>:httpi


.. class:: <page-context>

   :superclasses: <attributes-mixin>:http-common:http-common


.. class:: <redirecting-resource>

   :superclasses: <resource>

   :keyword target:

.. class:: <request>
   :open:
   :primary:

   :superclasses: <chunking-input-stream>:http-common:http-common, <base-http-request>:http-common:http-common


.. class:: <resource>
   :open:

   :superclasses: <abstract-resource>, <abstract-router>


.. class:: <response>
   :open:
   :primary:

   :superclasses: <string-stream>:streams:io, <base-http-response>:http-common:http-common

   :keyword direction:

.. class:: <rewrite-rule>

   :superclasses: <abstract-rewrite-rule>

   :keyword regex:
   :keyword replacement:

.. class:: <session>
   :open:
   :primary:

   :superclasses: <attributes-mixin>:http-common:http-common

   :keyword id:
   :keyword server:

.. class:: <virtual-host>

   :superclasses: <multi-logger-mixin>:httpi, <abstract-router>, <abstract-resource>

   :keyword router:

.. generic-function:: add-cookie

   :signature: add-cookie (response name value) => (#rest results)

   :parameter response: An instance of ``<object>``.
   :parameter name: An instance of ``<object>``.
   :parameter value: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: add-resource
   :open:

   :signature: add-resource (router url resource #key #all-keys) => (#rest results)

   :parameter router: An instance of ``<abstract-router>``.
   :parameter url: An instance of ``<object>``.
   :parameter resource: An instance of ``<abstract-resource>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: add-resource-name
   :open:

   :signature: add-resource-name (name resource) => (#rest results)

   :parameter name: An instance of ``<string>``.
   :parameter resource: An instance of ``<resource>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: add-virtual-host
   :open:

   :signature: add-virtual-host (server fqdn vhost) => ()

   :parameter server: An instance of ``<http-server>``.
   :parameter fqdn: An instance of ``<string>``.
   :parameter vhost: An instance of ``<virtual-host>``.

.. generic-function:: clear-session

   :signature: clear-session (request) => (#rest results)

   :parameter request: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: configure-server

   :signature: configure-server (server config-file) => (#rest results)

   :parameter server: An instance of ``<object>``.
   :parameter config-file: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. function:: count-query-values

   :signature: count-query-values () => (count)

   :value count: An instance of ``<integer>``.

.. function:: current-request

   :signature: current-request () => (request)

   :value request: An instance of ``<request>``.

.. function:: current-response

   :signature: current-response () => (response)

   :value response: An instance of ``<response>``.

.. function:: current-server

   :signature: current-server () => (server)

   :value server: An instance of ``<http-server>``.

.. generic-function:: debugging-enabled?

   :signature: debugging-enabled? (object) => (#rest results)

   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: debugging-enabled?-setter

   :signature: debugging-enabled?-setter (value object) => (#rest results)

   :parameter value: An instance of ``<object>``.
   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: default-content-type
   :open:

   :signature: default-content-type (resource) => (content-type)

   :parameter resource: An instance of ``<abstract-resource>``.
   :value content-type: An instance of ``type-union(<mime-type>, <string>)``.

.. generic-function:: default-documents

   :signature: default-documents (object) => (#rest results)

   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: default-virtual-host

   :signature: default-virtual-host (object) => (#rest results)

   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: default-virtual-host-setter

   :signature: default-virtual-host-setter (value object) => (#rest results)

   :parameter value: An instance of ``<object>``.
   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: do-query-values

   :signature: do-query-values (f) => (#rest results)

   :parameter f: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: do-resources
   :open:

   :signature: do-resources (router function #key seen) => ()

   :parameter router: An instance of ``<abstract-router>``.
   :parameter function: An instance of ``<function>``.
   :parameter #key seen: An instance of ``<object>``.

.. generic-function:: ensure-session

   :signature: ensure-session (request) => (#rest results)

   :parameter request: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. function:: file-contents

   :signature: file-contents (filename #key error?) => (contents)

   :parameter filename: An instance of ``<pathname>:file-system:system``.
   :parameter #key error?: An instance of ``<boolean>``.
   :value contents: An instance of ``false-or(<string>)``.

.. generic-function:: find-resource
   :open:

   :signature: find-resource (router url) => (resource prefix suffix)

   :parameter router: An instance of ``<abstract-router>``.
   :parameter url: An instance of ``<object>``.
   :value resource: An instance of ``<abstract-resource>``.
   :value prefix: An instance of ``<list>``.
   :value suffix: An instance of ``<list>``.

.. generic-function:: find-virtual-host
   :open:

   :signature: find-virtual-host (server fqdn) => (vhost)

   :parameter server: An instance of ``<http-server>``.
   :parameter fqdn: An instance of ``<string>``.
   :value vhost: An instance of ``<virtual-host>``.

.. function:: function-resource

   :signature: function-resource (function #key methods) => (resource)

   :parameter function: An instance of ``<function>``.
   :parameter #key methods: An instance of ``<object>``.
   :value resource: An instance of ``<resource>``.

.. generic-function:: generate-url
   :open:

   :signature: generate-url (router name #key #all-keys) => (url)

   :parameter router: An instance of ``<abstract-router>``.
   :parameter name: An instance of ``<string>``.
   :value url: An instance of ``<object>``.

.. generic-function:: get-attr

   :signature: get-attr (node attrib) => (#rest results)

   :parameter node: An instance of ``<object>``.
   :parameter attrib: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. function:: get-query-value

   :signature: get-query-value (key #key as) => (value)

   :parameter key: An instance of ``<string>``.
   :parameter #key as: An instance of ``false-or(<type>)``.
   :value value: An instance of ``<object>``.

   Return the first (and usually the only) query value associated with ``key``,
   or ``#f`` if no value found.

   Query values are any values from the query portion of the URL or from POST
   data for requests encoded as either ``application/x-www-form-urlencoded`` or
   ``multipart/form-data``.

   See also: :func:`get-query-values`

.. function:: get-query-values

   :signature: get-query-values (key) => (values)

   :parameter key: An instance of ``<string>``.
   :value values: An instance of ``<sequence>``.

   Returns all query values associated with ``key``, or an empty sequence if no
   values are found.

   Query values are any values from the query portion of the URL or from POST
   data for requests encoded as either ``application/x-www-form-urlencoded`` or
   ``multipart/form-data``. In some cases, such as file upload that allows
   multiple file to be selected, there may be several values for a single key
   and :func:`get-query-values` is what you need in that case.

   For most common cases, however, :func:`get-query-value` is the right choice.

.. generic-function:: get-session

   :signature: get-session (request) => (#rest results)

   :parameter request: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. function:: http-server-main

   :signature: http-server-main (#key server description before-startup) => ()

   :parameter #key server: An instance of ``false-or(<http-server>)``.
   :parameter #key description: An instance of ``false-or(<string>)``.
   :parameter #key before-startup: An instance of ``false-or(<function>)``.

.. generic-function:: log-content

   :signature: log-content (content) => (#rest results)

   :parameter content: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. constant:: log-debug

.. constant:: log-error

.. constant:: log-info

.. constant:: log-trace

.. constant:: log-warning

.. function:: output

   :signature: output (format-string #rest format-args) => (#rest results)

   :parameter format-string: An instance of ``<object>``.
   :parameter #rest format-args: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: page-context

   :signature: page-context () => (#rest results)

   :value #rest results: An instance of ``<object>``.

.. generic-function:: process-config-element
   :open:

   :signature: process-config-element (server node name) => (#rest results)

   :parameter server: An instance of ``<http-server>``.
   :parameter node: An instance of ``<object>``.
   :parameter name: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: process-request-content
   :open:

   :signature: process-request-content (request content-type) => (#rest results)

   :parameter request: An instance of ``<request>``.
   :parameter content-type: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: redirect-temporarily-to
   :open:

   :signature: redirect-temporarily-to (object) => (#rest results)

   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: redirect-to
   :open:

   :signature: redirect-to (object) => (#rest results)

   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: request-absolute-url

   :signature: request-absolute-url (request) => (#rest results)

   :parameter request: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. function:: request-content-type

   :signature: request-content-type (request) => (#rest results)

   :parameter request: An instance of ``<request>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: request-host

   :signature: request-host (object) => (#rest results)

   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: request-query-values

   :signature: request-query-values (object) => (#rest results)

   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: request-url-path-prefix

   :signature: request-url-path-prefix (object) => (#rest results)

   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: request-url-path-suffix

   :signature: request-url-path-suffix (object) => (#rest results)

   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: respond
   :open:

   :signature: respond (resource #key #all-keys) => (#rest results)

   :parameter resource: An instance of ``<abstract-resource>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: respond-to-connect
   :open:

   :signature: respond-to-connect (resource #key #all-keys) => (#rest results)

   :parameter resource: An instance of ``<abstract-resource>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: respond-to-delete
   :open:

   :signature: respond-to-delete (resource #key #all-keys) => (#rest results)

   :parameter resource: An instance of ``<abstract-resource>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: respond-to-get
   :open:

   :signature: respond-to-get (resource #key #all-keys) => (#rest results)

   :parameter resource: An instance of ``<abstract-resource>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: respond-to-head
   :open:

   :signature: respond-to-head (resource #key #all-keys) => (#rest results)

   :parameter resource: An instance of ``<abstract-resource>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: respond-to-options
   :open:

   :signature: respond-to-options (resource #key #all-keys) => (#rest results)

   :parameter resource: An instance of ``<abstract-resource>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: respond-to-post
   :open:

   :signature: respond-to-post (resource #key #all-keys) => (#rest results)

   :parameter resource: An instance of ``<abstract-resource>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: respond-to-put
   :open:

   :signature: respond-to-put (resource #key #all-keys) => (#rest results)

   :parameter resource: An instance of ``<abstract-resource>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: respond-to-trace
   :open:

   :signature: respond-to-trace (resource #key #all-keys) => (#rest results)

   :parameter resource: An instance of ``<abstract-resource>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: rewrite-url
   :open:

   :signature: rewrite-url (url rule) => (url extra)

   :parameter url: An instance of ``<string>``.
   :parameter rule: An instance of ``<object>``.
   :value url: An instance of ``<string>``.
   :value extra: An instance of ``<object>``.

.. generic-function:: route-request

   :signature: route-request (server request) => (#rest results)

   :parameter server: An instance of ``<object>``.
   :parameter request: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: serve-static-file

   :signature: serve-static-file (policy locator) => (#rest results)

   :parameter policy: An instance of ``<object>``.
   :parameter locator: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: server-root

   :signature: server-root (object) => (#rest results)

   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: start-server
   :open:

   :signature: start-server (server #key background wait) => (started?)

   :parameter server: An instance of ``<http-server>``.
   :parameter #key background: An instance of ``<boolean>``.
   :parameter #key wait: An instance of ``<boolean>``.
   :value started?: An instance of ``<boolean>``.

.. generic-function:: stop-server
   :open:

   :signature: stop-server (server #key abort) => (#rest results)

   :parameter server: An instance of ``<http-server>``.
   :parameter #key abort: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: unmatched-url-suffix
   :open:

   :signature: unmatched-url-suffix (resource unmatched-path) => (#rest results)

   :parameter resource: An instance of ``<abstract-resource>``.
   :parameter unmatched-path: An instance of ``<sequence>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: use-default-virtual-host?

   :signature: use-default-virtual-host? (object) => (#rest results)

   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. macro:: with-query-values


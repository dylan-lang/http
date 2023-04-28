***********************
The HTTP-COMMON library
***********************

.. current-library:: http-common
.. current-module:: http-common

The HTTP-COMMON module
======================

.. constant:: $application-error

.. constant:: $bad-gateway-error

.. constant:: $bad-header-error

.. constant:: $bad-request-error

.. constant:: $conflict-error

.. constant:: $content-length-required-error

.. constant:: $default-cookie-version

.. constant:: $expectation-failed-error

.. constant:: $forbidden-error

.. constant:: $found-redirect

.. constant:: $gateway-timeout-error

.. constant:: $gone-error

.. constant:: $header-too-large-error

.. constant:: $http-version-not-supported-error

.. constant:: $internal-server-error

.. constant:: $method-not-allowed-error

.. constant:: $mime-wild

.. constant:: $moved-permanently-redirect

.. constant:: $moved-temporarily-redirect

.. constant:: $not-acceptable-error

.. constant:: $not-implemented-error

.. constant:: $not-modified-redirect

.. constant:: $payment-required-error

.. constant:: $precondition-failed-error

.. constant:: $proxy-authentication-required-error

.. constant:: $request-entity-too-large-error

.. constant:: $request-timeout-error

.. constant:: $request-uri-too-long-error

.. constant:: $requested-range-not-satisfiable-error

.. constant:: $resource-not-found-error

.. constant:: $see-other-redirect

.. constant:: $service-unavailable-error

.. constant:: $status-accepted

.. constant:: $status-application-error

.. constant:: $status-bad-gateway

.. constant:: $status-bad-request

.. constant:: $status-conflict

.. constant:: $status-continue

.. constant:: $status-created

.. constant:: $status-expectation-failed

.. constant:: $status-forbidden

.. constant:: $status-found

.. constant:: $status-gateway-timeout

.. constant:: $status-gone

.. constant:: $status-http-version-not-supported

.. constant:: $status-internal-server-error

.. constant:: $status-length-required

.. constant:: $status-method-not-allowed

.. constant:: $status-moved-permanently

.. constant:: $status-multiple-choices

.. constant:: $status-no-content

.. constant:: $status-non-authoritative-information

.. constant:: $status-not-acceptable

.. constant:: $status-not-found

.. constant:: $status-not-implemented

.. constant:: $status-not-modified

.. constant:: $status-ok

.. constant:: $status-partial-content

.. constant:: $status-payment-required

.. constant:: $status-precondition-failed

.. constant:: $status-proxy-authentication-required

.. constant:: $status-request-entity-too-large

.. constant:: $status-request-timeout

.. constant:: $status-request-uri-too-long

.. constant:: $status-requested-range-not-satisfiable

.. constant:: $status-reset-content

.. constant:: $status-see-other

.. constant:: $status-service-unavailable

.. constant:: $status-switching-protocols

.. constant:: $status-temporary-redirect

.. constant:: $status-unauthorized

.. constant:: $status-unsupported-media-type

.. constant:: $status-use-proxy

.. constant:: $unauthorized-error

.. constant:: $unsupported-media-type-error

.. constant:: $use-proxy-redirect

.. class:: <application-error>

   :superclasses: <http-server-protocol-error>


.. class:: <attributes-mixin>
   :open:

   :superclasses: <object>

   :keyword attributes:

.. class:: <avalue>

   :superclasses: <explicit-key-collection>

   :keyword alist:
   :keyword value:

.. class:: <bad-gateway-error>

   :superclasses: <http-server-protocol-error>


.. class:: <bad-header-error>

   :superclasses: <http-parse-error>


.. class:: <bad-request-error>

   :superclasses: <http-parse-error>


.. class:: <base-http-request>
   :open:

   :superclasses: <message-headers-mixin>:http-common-internals

   :keyword content:
   :keyword method:
   :keyword raw-url:
   :keyword url:
   :keyword version:

.. class:: <base-http-response>
   :open:

   :superclasses: <message-headers-mixin>:http-common-internals

   :keyword chunked:
   :keyword code:
   :keyword reason-phrase:
   :keyword request:

.. class:: <chunking-input-stream>
   :open:

   :superclasses: <wrapper-stream>:streams:io


.. class:: <conflict-error>

   :superclasses: <http-client-protocol-error>


.. class:: <content-length-required-error>

   :superclasses: <http-client-protocol-error>


.. class:: <expectation-failed-error>

   :superclasses: <http-client-protocol-error>


.. class:: <expiring-mixin>
   :open:

   :superclasses: <object>

   :keyword duration:

.. class:: <forbidden-error>

   :superclasses: <http-client-protocol-error>


.. class:: <found-redirect>

   :superclasses: <http-redirect-condition>


.. class:: <gateway-timeout-error>

   :superclasses: <http-server-protocol-error>


.. class:: <gone-error>

   :superclasses: <http-client-protocol-error>


.. class:: <header-table>

   :superclasses: <table>


.. class:: <header-too-large-error>

   :superclasses: <http-client-protocol-error>


.. class:: <http-client-protocol-error>

   :superclasses: <http-protocol-condition>


.. class:: <http-error>
   :open:

   :superclasses: <format-string-condition>:dylan-extensions:dylan, <error>


.. class:: <http-parse-error>

   :superclasses: <http-client-protocol-error>


.. class:: <http-protocol-condition>
   :open:

   :superclasses: <http-error>

   :keyword code:
   :keyword headers:

.. class:: <http-redirect-condition>

   :superclasses: <http-protocol-condition>


.. class:: <http-server-protocol-error>

   :superclasses: <http-protocol-condition>


.. class:: <http-version-not-supported-error>

   :superclasses: <http-server-protocol-error>


.. class:: <internal-server-error>

   :superclasses: <http-server-protocol-error>


.. class:: <media-type>

   :superclasses: <attributes-mixin>, <mime-type>:mime:mime


.. class:: <method-not-allowed-error>

   :superclasses: <http-client-protocol-error>


.. class:: <moved-permanently-redirect>

   :superclasses: <http-redirect-condition>


.. class:: <moved-temporarily-redirect>

   :superclasses: <http-redirect-condition>


.. class:: <not-acceptable-error>

   :superclasses: <http-client-protocol-error>


.. class:: <not-implemented-error>

   :superclasses: <http-server-protocol-error>


.. class:: <not-modified-redirect>

   :superclasses: <http-redirect-condition>


.. class:: <payment-required-error>

   :superclasses: <http-client-protocol-error>


.. class:: <precondition-failed-error>

   :superclasses: <http-client-protocol-error>


.. class:: <proxy-authentication-required-error>

   :superclasses: <http-client-protocol-error>


.. class:: <request-entity-too-large-error>

   :superclasses: <http-client-protocol-error>


.. class:: <request-timeout-error>

   :superclasses: <http-client-protocol-error>


.. class:: <request-uri-too-long-error>

   :superclasses: <http-client-protocol-error>


.. class:: <requested-range-not-satisfiable-error>

   :superclasses: <http-client-protocol-error>


.. class:: <resource-not-found-error>

   :superclasses: <http-client-protocol-error>


.. class:: <see-other-redirect>

   :superclasses: <http-redirect-condition>


.. class:: <service-unavailable-error>

   :superclasses: <http-server-protocol-error>


.. class:: <unauthorized-error>

   :superclasses: <http-client-protocol-error>


.. class:: <unsupported-media-type-error>

   :superclasses: <http-client-protocol-error>


.. class:: <use-proxy-redirect>

   :superclasses: <http-redirect-condition>


.. function:: application-error

   :signature: application-error (#key headers header-name header-value message) => (#rest results)

   :parameter #key headers: An instance of ``false-or(<header-table>)``.
   :parameter #key header-name: An instance of ``false-or(<string>)``.
   :parameter #key header-value: An instance of ``false-or(<string>)``.
   :parameter #key message: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: avalue-alist

   :signature: avalue-alist (object) => (#rest results)

   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: avalue-value

   :signature: avalue-value (object) => (#rest results)

   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. function:: bad-gateway-error

   :signature: bad-gateway-error (#key headers header-name header-value) => (#rest results)

   :parameter #key headers: An instance of ``false-or(<header-table>)``.
   :parameter #key header-name: An instance of ``false-or(<string>)``.
   :parameter #key header-value: An instance of ``false-or(<string>)``.
   :value #rest results: An instance of ``<object>``.

.. function:: bad-header-error

   :signature: bad-header-error (#key headers header-name header-value message) => (#rest results)

   :parameter #key headers: An instance of ``false-or(<header-table>)``.
   :parameter #key header-name: An instance of ``false-or(<string>)``.
   :parameter #key header-value: An instance of ``false-or(<string>)``.
   :parameter #key message: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. function:: bad-request-error

   :signature: bad-request-error (#key headers header-name header-value reason) => (#rest results)

   :parameter #key headers: An instance of ``false-or(<header-table>)``.
   :parameter #key header-name: An instance of ``false-or(<string>)``.
   :parameter #key header-value: An instance of ``false-or(<string>)``.
   :parameter #key reason: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: chunked-transfer-encoding?

   :signature: chunked-transfer-encoding? (headers) => (#rest results)

   :parameter headers: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. function:: condition-class-for-status-code

   :signature: condition-class-for-status-code (code) => (class)

   :parameter code: An instance of ``<integer>``.
   :value class: An instance of ``<class>``.

.. function:: conflict-error

   :signature: conflict-error (#key headers header-name header-value) => (#rest results)

   :parameter #key headers: An instance of ``false-or(<header-table>)``.
   :parameter #key header-name: An instance of ``false-or(<string>)``.
   :parameter #key header-value: An instance of ``false-or(<string>)``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: content-length
   :open:

   :signature: content-length (object) => (length)

   :parameter object: An instance of ``<object>``.
   :value length: An instance of ``false-or(<integer>)``.

.. function:: content-length-required-error

   :signature: content-length-required-error (#key headers header-name header-value) => (#rest results)

   :parameter #key headers: An instance of ``false-or(<header-table>)``.
   :parameter #key header-name: An instance of ``false-or(<string>)``.
   :parameter #key header-value: An instance of ``false-or(<string>)``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: cookie-comment

   :signature: cookie-comment (object) => (#rest results)

   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: cookie-domain

   :signature: cookie-domain (object) => (#rest results)

   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: cookie-max-age

   :signature: cookie-max-age (object) => (#rest results)

   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: cookie-name

   :signature: cookie-name (object) => (#rest results)

   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: cookie-path

   :signature: cookie-path (object) => (#rest results)

   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: cookie-value

   :signature: cookie-value (object) => (#rest results)

   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: cookie-version

   :signature: cookie-version (object) => (#rest results)

   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: date-modified
   :open:

   :signature: date-modified (object) => (date)

   :parameter object: An instance of ``<object>``.
   :value date: An instance of ``false-or(<date>)``.

.. generic-function:: date-modified-setter
   :open:

   :signature: date-modified-setter (new-date object) => (new-date)

   :parameter new-date: An instance of ``false-or(<date>)``.
   :parameter object: An instance of ``<object>``.
   :value new-date: An instance of ``false-or(<date>)``.

.. function:: expectation-failed-error

   :signature: expectation-failed-error (#key headers header-name header-value) => (#rest results)

   :parameter #key headers: An instance of ``false-or(<header-table>)``.
   :parameter #key header-name: An instance of ``false-or(<string>)``.
   :parameter #key header-value: An instance of ``false-or(<string>)``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: expired?

   :signature: expired? (thing) => (#rest results)

   :parameter thing: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. function:: forbidden-error

   :signature: forbidden-error (#key headers header-name header-value) => (#rest results)

   :parameter #key headers: An instance of ``false-or(<header-table>)``.
   :parameter #key header-name: An instance of ``false-or(<string>)``.
   :parameter #key header-value: An instance of ``false-or(<string>)``.
   :value #rest results: An instance of ``<object>``.

.. function:: found-redirect

   :signature: found-redirect (#key headers header-name header-value location) => (#rest results)

   :parameter #key headers: An instance of ``false-or(<header-table>)``.
   :parameter #key header-name: An instance of ``false-or(<string>)``.
   :parameter #key header-value: An instance of ``false-or(<string>)``.
   :parameter #key location: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. function:: gateway-timeout-error

   :signature: gateway-timeout-error (#key headers header-name header-value) => (#rest results)

   :parameter #key headers: An instance of ``false-or(<header-table>)``.
   :parameter #key header-name: An instance of ``false-or(<string>)``.
   :parameter #key header-value: An instance of ``false-or(<string>)``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: get-attribute

   :signature: get-attribute (this key) => (value)

   :parameter this: An instance of ``<attributes-mixin>``.
   :parameter key: An instance of ``<string>``.
   :value value: An instance of ``<object>``.

.. generic-function:: get-header
   :open:

   :signature: get-header (object header-name #key parsed) => (header-value)

   :parameter object: An instance of ``<object>``.
   :parameter header-name: An instance of ``<byte-string>``.
   :parameter #key parsed: An instance of ``<boolean>``.
   :value header-value: An instance of ``<object>``.

.. function:: gone-error

   :signature: gone-error (#key headers header-name header-value) => (#rest results)

   :parameter #key headers: An instance of ``false-or(<header-table>)``.
   :parameter #key header-name: An instance of ``false-or(<string>)``.
   :parameter #key header-value: An instance of ``false-or(<string>)``.
   :value #rest results: An instance of ``<object>``.

.. function:: grow-header-buffer

   :signature: grow-header-buffer (old len) => (#rest results)

   :parameter old: An instance of ``<byte-string>``.
   :parameter len: An instance of ``<integer>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: has-attribute?

   :signature: has-attribute? (this key) => (has-it?)

   :parameter this: An instance of ``<attributes-mixin>``.
   :parameter key: An instance of ``<string>``.
   :value has-it?: An instance of ``<boolean>``.

.. function:: header-too-large-error

   :signature: header-too-large-error (#key headers header-name header-value max-size) => (#rest results)

   :parameter #key headers: An instance of ``false-or(<header-table>)``.
   :parameter #key header-name: An instance of ``false-or(<string>)``.
   :parameter #key header-value: An instance of ``false-or(<string>)``.
   :parameter #key max-size: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: http-error-headers

   :signature: http-error-headers (error) => (headers)

   :parameter error: An instance of ``<error>``.
   :value headers: An instance of ``false-or(<header-table>)``.

.. generic-function:: http-error-message-no-code

   :signature: http-error-message-no-code (error) => (#rest results)

   :parameter error: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: http-status-code

   :signature: http-status-code (error) => (code)

   :parameter error: An instance of ``<error>``.
   :value code: An instance of ``<integer>``.

.. function:: http-version-not-supported-error

   :signature: http-version-not-supported-error (#key headers header-name header-value version) => (#rest results)

   :parameter #key headers: An instance of ``false-or(<header-table>)``.
   :parameter #key header-name: An instance of ``false-or(<string>)``.
   :parameter #key header-value: An instance of ``false-or(<string>)``.
   :parameter #key version: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. function:: internal-server-error

   :signature: internal-server-error (#key headers header-name header-value) => (#rest results)

   :parameter #key headers: An instance of ``false-or(<header-table>)``.
   :parameter #key header-name: An instance of ``false-or(<string>)``.
   :parameter #key header-value: An instance of ``false-or(<string>)``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: match-media-types

   :signature: match-media-types (type1 type2) => (#rest results)

   :parameter type1: An instance of ``<object>``.
   :parameter type2: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: media-type-exact?

   :signature: media-type-exact? (mr) => (#rest results)

   :parameter mr: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: media-type-level

   :signature: media-type-level (media-type) => (#rest results)

   :parameter media-type: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: media-type-more-specific?

   :signature: media-type-more-specific? (type1 type2) => (#rest results)

   :parameter type1: An instance of ``<object>``.
   :parameter type2: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: media-type-quality

   :signature: media-type-quality (media-type) => (#rest results)

   :parameter media-type: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. function:: method-not-allowed-error

   :signature: method-not-allowed-error (#key headers header-name header-value request-method) => (#rest results)

   :parameter #key headers: An instance of ``false-or(<header-table>)``.
   :parameter #key header-name: An instance of ``false-or(<string>)``.
   :parameter #key header-value: An instance of ``false-or(<string>)``.
   :parameter #key request-method: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. function:: moved-permanently-redirect

   :signature: moved-permanently-redirect (#key headers header-name header-value location) => (#rest results)

   :parameter #key headers: An instance of ``false-or(<header-table>)``.
   :parameter #key header-name: An instance of ``false-or(<string>)``.
   :parameter #key header-value: An instance of ``false-or(<string>)``.
   :parameter #key location: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. function:: moved-temporarily-redirect

   :signature: moved-temporarily-redirect (#key headers header-name header-value location) => (#rest results)

   :parameter #key headers: An instance of ``false-or(<header-table>)``.
   :parameter #key header-name: An instance of ``false-or(<string>)``.
   :parameter #key header-value: An instance of ``false-or(<string>)``.
   :parameter #key location: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. function:: not-acceptable-error

   :signature: not-acceptable-error (#key headers header-name header-value) => (#rest results)

   :parameter #key headers: An instance of ``false-or(<header-table>)``.
   :parameter #key header-name: An instance of ``false-or(<string>)``.
   :parameter #key header-value: An instance of ``false-or(<string>)``.
   :value #rest results: An instance of ``<object>``.

.. function:: not-implemented-error

   :signature: not-implemented-error (#key headers header-name header-value what) => (#rest results)

   :parameter #key headers: An instance of ``false-or(<header-table>)``.
   :parameter #key header-name: An instance of ``false-or(<string>)``.
   :parameter #key header-value: An instance of ``false-or(<string>)``.
   :parameter #key what: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. function:: not-modified-redirect

   :signature: not-modified-redirect (#key headers header-name header-value) => (#rest results)

   :parameter #key headers: An instance of ``false-or(<header-table>)``.
   :parameter #key header-name: An instance of ``false-or(<string>)``.
   :parameter #key header-value: An instance of ``false-or(<string>)``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: note-bytes-received
   :open:

   :signature: note-bytes-received (stream byte-count) => (#rest results)

   :parameter stream: An instance of ``<chunking-input-stream>``.
   :parameter byte-count: An instance of ``<integer>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: parse-header-value
   :open:

   :signature: parse-header-value (field-name field-values) => (parsed-field-value)

   :parameter field-name: An instance of ``<symbol>``.
   :parameter field-values: An instance of ``<field-type>:http-common-internals``.
   :value parsed-field-value: An instance of ``<object>``.

.. function:: parse-http-date

   :signature: parse-http-date (str bpos epos) => (date)

   :parameter str: An instance of ``<byte-string>``.
   :parameter bpos: An instance of ``<integer>``.
   :parameter epos: An instance of ``<integer>``.
   :value date: An instance of ``false-or(<date>)``.

.. generic-function:: parsed-headers

   :signature: parsed-headers (object) => (#rest results)

   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. function:: payment-required-error

   :signature: payment-required-error (#key headers header-name header-value) => (#rest results)

   :parameter #key headers: An instance of ``false-or(<header-table>)``.
   :parameter #key header-name: An instance of ``false-or(<string>)``.
   :parameter #key header-value: An instance of ``false-or(<string>)``.
   :value #rest results: An instance of ``<object>``.

.. function:: precondition-failed-error

   :signature: precondition-failed-error (#key headers header-name header-value) => (#rest results)

   :parameter #key headers: An instance of ``false-or(<header-table>)``.
   :parameter #key header-name: An instance of ``false-or(<string>)``.
   :parameter #key header-value: An instance of ``false-or(<string>)``.
   :value #rest results: An instance of ``<object>``.

.. function:: proxy-authentication-required-error

   :signature: proxy-authentication-required-error (#key headers header-name header-value) => (#rest results)

   :parameter #key headers: An instance of ``false-or(<header-table>)``.
   :parameter #key header-name: An instance of ``false-or(<string>)``.
   :parameter #key header-value: An instance of ``false-or(<string>)``.
   :value #rest results: An instance of ``<object>``.

.. function:: quote-html

   :signature: quote-html (text #key stream) => (#rest results)

   :parameter text: An instance of ``<string>``.
   :parameter #key stream: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: raw-headers

   :signature: raw-headers (object) => (#rest results)

   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. function:: read-header-line

   :signature: read-header-line (stream buffer bpos peek-ch require-crlf?) => (buffer bpos epos peek-ch)

   :parameter stream: An instance of ``<stream>:common-extensions:common-dylan``.
   :parameter buffer: An instance of ``<byte-string>``.
   :parameter bpos: An instance of ``<integer>``.
   :parameter peek-ch: An instance of ``false-or(<byte-character>)``.
   :parameter require-crlf?: An instance of ``<boolean>``.
   :value buffer: An instance of ``<byte-string>``.
   :value bpos: An instance of ``<integer>``.
   :value epos: An instance of ``<integer>``.
   :value peek-ch: An instance of ``false-or(<byte-character>)``.

.. generic-function:: read-http-line

   :signature: read-http-line (stream) => (#rest results)

   :parameter stream: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. function:: read-message-headers

   :signature: read-message-headers (stream #key buffer start headers require-crlf?) => (headers buffer epos)

   :parameter stream: An instance of ``<stream>:common-extensions:common-dylan``.
   :parameter #key buffer: An instance of ``<byte-string>``.
   :parameter #key start: An instance of ``<integer>``.
   :parameter #key headers: An instance of ``<header-table>``.
   :parameter #key require-crlf?: An instance of ``<boolean>``.
   :value headers: An instance of ``<header-table>``.
   :value buffer: An instance of ``<byte-string>``.
   :value epos: An instance of ``<integer>``.

.. generic-function:: remove-attribute

   :signature: remove-attribute (this key) => (#rest results)

   :parameter this: An instance of ``<attributes-mixin>``.
   :parameter key: An instance of ``<string>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: request-content

   :signature: request-content (object) => (#rest results)

   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: request-content-setter

   :signature: request-content-setter (value object) => (#rest results)

   :parameter value: An instance of ``<object>``.
   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. function:: request-entity-too-large-error

   :signature: request-entity-too-large-error (#key headers header-name header-value max-size) => (#rest results)

   :parameter #key headers: An instance of ``false-or(<header-table>)``.
   :parameter #key header-name: An instance of ``false-or(<string>)``.
   :parameter #key header-value: An instance of ``false-or(<string>)``.
   :parameter #key max-size: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: request-method

   :signature: request-method (object) => (#rest results)

   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: request-method-setter

   :signature: request-method-setter (value object) => (#rest results)

   :parameter value: An instance of ``<object>``.
   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: request-raw-url-string

   :signature: request-raw-url-string (object) => (#rest results)

   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: request-raw-url-string-setter

   :signature: request-raw-url-string-setter (value object) => (#rest results)

   :parameter value: An instance of ``<object>``.
   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. function:: request-timeout-error

   :signature: request-timeout-error (#key headers header-name header-value seconds) => (#rest results)

   :parameter #key headers: An instance of ``false-or(<header-table>)``.
   :parameter #key header-name: An instance of ``false-or(<string>)``.
   :parameter #key header-value: An instance of ``false-or(<string>)``.
   :parameter #key seconds: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. function:: request-uri-too-long-error

   :signature: request-uri-too-long-error (#key headers header-name header-value max-size) => (#rest results)

   :parameter #key headers: An instance of ``false-or(<header-table>)``.
   :parameter #key header-name: An instance of ``false-or(<string>)``.
   :parameter #key header-value: An instance of ``false-or(<string>)``.
   :parameter #key max-size: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: request-url

   :signature: request-url (object) => (#rest results)

   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: request-url-setter

   :signature: request-url-setter (value object) => (#rest results)

   :parameter value: An instance of ``<object>``.
   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: request-version

   :signature: request-version (object) => (#rest results)

   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: request-version-setter

   :signature: request-version-setter (value object) => (#rest results)

   :parameter value: An instance of ``<object>``.
   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. function:: requested-range-not-satisfiable-error

   :signature: requested-range-not-satisfiable-error (#key headers header-name header-value) => (#rest results)

   :parameter #key headers: An instance of ``false-or(<header-table>)``.
   :parameter #key header-name: An instance of ``false-or(<string>)``.
   :parameter #key header-value: An instance of ``false-or(<string>)``.
   :value #rest results: An instance of ``<object>``.

.. function:: resource-not-found-error

   :signature: resource-not-found-error (#key headers header-name header-value url) => (#rest results)

   :parameter #key headers: An instance of ``false-or(<header-table>)``.
   :parameter #key header-name: An instance of ``false-or(<string>)``.
   :parameter #key header-value: An instance of ``false-or(<string>)``.
   :parameter #key url: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: response-chunked?

   :signature: response-chunked? (object) => (#rest results)

   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: response-chunked?-setter

   :signature: response-chunked?-setter (value object) => (#rest results)

   :parameter value: An instance of ``<object>``.
   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: response-code

   :signature: response-code (object) => (#rest results)

   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: response-code-setter

   :signature: response-code-setter (value object) => (#rest results)

   :parameter value: An instance of ``<object>``.
   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: response-reason-phrase

   :signature: response-reason-phrase (object) => (#rest results)

   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: response-reason-phrase-setter

   :signature: response-reason-phrase-setter (value object) => (#rest results)

   :parameter value: An instance of ``<object>``.
   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: response-request

   :signature: response-request (object) => (#rest results)

   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. function:: see-other-redirect

   :signature: see-other-redirect (#key headers header-name header-value location) => (#rest results)

   :parameter #key headers: An instance of ``false-or(<header-table>)``.
   :parameter #key header-name: An instance of ``false-or(<string>)``.
   :parameter #key header-value: An instance of ``false-or(<string>)``.
   :parameter #key location: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. function:: service-unavailable-error

   :signature: service-unavailable-error (#key headers header-name header-value) => (#rest results)

   :parameter #key headers: An instance of ``false-or(<header-table>)``.
   :parameter #key header-name: An instance of ``false-or(<string>)``.
   :parameter #key header-value: An instance of ``false-or(<string>)``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: set-attribute

   :signature: set-attribute (this key value) => (#rest results)

   :parameter this: An instance of ``<attributes-mixin>``.
   :parameter key: An instance of ``<string>``.
   :parameter value: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: set-header
   :open:

   :signature: set-header (object header value #key if-exists?) => (#rest results)

   :parameter object: An instance of ``<object>``.
   :parameter header: An instance of ``<byte-string>``.
   :parameter value: An instance of ``<object>``.
   :parameter #key if-exists?: An instance of ``one-of(#"replace", #"append", #"ignore", #"error")``.
   :value #rest results: An instance of ``<object>``.

.. function:: token-end-position

   :signature: token-end-position (buf bpos epos) => (#rest results)

   :parameter buf: An instance of ``<byte-string>``.
   :parameter bpos: An instance of ``<integer>``.
   :parameter epos: An instance of ``<integer>``.
   :value #rest results: An instance of ``<object>``.

.. function:: unauthorized-error

   :signature: unauthorized-error (#key headers header-name header-value) => (#rest results)

   :parameter #key headers: An instance of ``false-or(<header-table>)``.
   :parameter #key header-name: An instance of ``false-or(<string>)``.
   :parameter #key header-value: An instance of ``false-or(<string>)``.
   :value #rest results: An instance of ``<object>``.

.. function:: unsupported-media-type-error

   :signature: unsupported-media-type-error (#key headers header-name header-value) => (#rest results)

   :parameter #key headers: An instance of ``false-or(<header-table>)``.
   :parameter #key header-name: An instance of ``false-or(<string>)``.
   :parameter #key header-value: An instance of ``false-or(<string>)``.
   :value #rest results: An instance of ``<object>``.

.. function:: use-proxy-redirect

   :signature: use-proxy-redirect (#key headers header-name header-value location) => (#rest results)

   :parameter #key headers: An instance of ``false-or(<header-table>)``.
   :parameter #key header-name: An instance of ``false-or(<string>)``.
   :parameter #key header-value: An instance of ``false-or(<string>)``.
   :parameter #key location: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: validate-http-status-code

   :signature: validate-http-status-code (status-code) => (#rest results)

   :parameter status-code: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: validate-http-version

   :signature: validate-http-version (version) => (#rest results)

   :parameter version: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.


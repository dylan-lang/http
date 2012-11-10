***************
The DSP library
***************

.. current-library:: dsp
.. current-module:: dsp

The DSP module
==============

.. class:: <dylan-server-page>
   :open:
   :primary:

   :superclasses: <expiring-mixin>, <resource>

   :keyword source:

.. class:: <page-link>
   :open:

   :superclasses: <object>

   :keyword label:
   :keyword page-number:

.. class:: <paginator>
   :open:

   :superclasses: <sequence>

   :keyword current-page-number:
   :keyword page-size:
   :keyword sequence:

.. class:: <taglib>

   :superclasses: <object>

   :keyword name:
   :keyword prefix:

.. generic-function:: add-field-error

   :signature: add-field-error (field-name message #rest format-arguments) => (#rest results)

   :parameter field-name: An instance of ``<object>``.
   :parameter message: An instance of ``<object>``.
   :parameter #rest format-arguments: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: add-page-error

   :signature: add-page-error (format-string #rest format-arguments) => (#rest results)

   :parameter format-string: An instance of ``<object>``.
   :parameter #rest format-arguments: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: add-page-note

   :signature: add-page-note (format-string #rest format-arguments) => (#rest results)

   :parameter format-string: An instance of ``<object>``.
   :parameter #rest format-arguments: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: current-page-number

   :signature: current-page-number (object) => (#rest results)

   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: current-page-number-setter

   :signature: current-page-number-setter (value object) => (#rest results)

   :parameter value: An instance of ``<object>``.
   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. function:: current-row

   :signature: current-row () => (#rest results)

   :value #rest results: An instance of ``<object>``.

.. function:: current-row-number

   :signature: current-row-number () => (#rest results)

   :value #rest results: An instance of ``<object>``.

.. generic-function:: get-field-errors

   :signature: get-field-errors (field-name) => (#rest results)

   :parameter field-name: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: get-named-method

   :signature: get-named-method (taglib name) => (#rest results)

   :parameter taglib: An instance of ``<object>``.
   :parameter name: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. function:: get-tag-call-attribute

   :signature: get-tag-call-attribute (attr #key as test) => (attribute-value)

   :parameter attr: An instance of ``<object>``.
   :parameter #key as: An instance of ``<type>``.
   :parameter #key test: An instance of ``<object>``.
   :value attribute-value: An instance of ``<object>``.

.. generic-function:: loop-index

   :signature: loop-index () => (#rest results)

   :value #rest results: An instance of ``<object>``.

.. generic-function:: loop-value

   :signature: loop-value () => (#rest results)

   :value #rest results: An instance of ``<object>``.

.. function:: map-tag-call-attributes

   :signature: map-tag-call-attributes (f #key exclude) => (#rest results)

   :parameter f: An instance of ``<function>``.
   :parameter #key exclude: An instance of ``<sequence>``.
   :value #rest results: An instance of ``<object>``.

.. macro:: named-method-definer

.. generic-function:: next-page-number

   :signature: next-page-number (paginator) => (#rest results)

   :parameter paginator: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: page-count
   :open:

   :signature: page-count (paginator) => (count)

   :parameter paginator: An instance of ``<paginator>``.
   :value count: An instance of ``<integer>``.

.. generic-function:: page-has-errors?

   :signature: page-has-errors? () => (#rest results)

   :value #rest results: An instance of ``<object>``.

.. generic-function:: page-link-label

   :signature: page-link-label (object) => (#rest results)

   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: page-link-page-number

   :signature: page-link-page-number (object) => (#rest results)

   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: page-links
   :open:

   :signature: page-links (paginator #key ellipsis prev next center-span min-pages) => (page-links)

   :parameter paginator: An instance of ``<paginator>``.
   :parameter #key ellipsis: An instance of ``false-or(<string>)``.
   :parameter #key prev: An instance of ``false-or(<string>)``.
   :parameter #key next: An instance of ``false-or(<string>)``.
   :parameter #key center-span: An instance of ``false-or(<integer>)``.
   :parameter #key min-pages: An instance of ``false-or(<integer>)``.
   :value page-links: An instance of ``<sequence>``.

.. generic-function:: page-size

   :signature: page-size (object) => (#rest results)

   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: page-source

   :signature: page-source (page) => (#rest results)

   :parameter page: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: page-template

   :signature: page-template (object) => (#rest results)

   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: page-template-setter

   :signature: page-template-setter (value object) => (#rest results)

   :parameter value: An instance of ``<object>``.
   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: paginator-sequence

   :signature: paginator-sequence (object) => (#rest results)

   :parameter object: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: previous-page-number

   :signature: previous-page-number (paginator) => (#rest results)

   :parameter paginator: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: process-template

   :signature: process-template (page) => (#rest results)

   :parameter page: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. generic-function:: register-tag

   :signature: register-tag (tag taglib) => (#rest results)

   :parameter tag: An instance of ``<object>``.
   :parameter taglib: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.

.. function:: show-tag-call-attributes

   :signature: show-tag-call-attributes (stream #key exclude) => (#rest results)

   :parameter stream: An instance of ``<object>``.
   :parameter #key exclude: An instance of ``<sequence>``.
   :value #rest results: An instance of ``<object>``.

.. macro:: tag-definer

.. macro:: taglib-definer

.. generic-function:: validate-form-field

   :signature: validate-form-field (field-name validator) => (#rest results)

   :parameter field-name: An instance of ``<object>``.
   :parameter validator: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.



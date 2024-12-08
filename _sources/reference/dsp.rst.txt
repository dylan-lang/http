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

   Defines a new tag in the given tag library.

   :signature: define [modifiers] tag tag-name [in taglib-name] (method-parameters) (tag-call-parameters) body end

   :parameter modifiers: The only valid modifier is ``body``, which must be
     used if the tag allows nested body elements. If ``body`` is not specified
     then the tag call must end in ``/>`` or an error will be signalled when
     the DSP template is parsed. If ``body`` is specified, ``method-parameters``
     must have a third parameter (see below).
   :parameter tag-name: The name of the tag, as it will appear in the .dsp file.
   :parameter taglib-name: The name of the taglib the tag should be added to.
   :parameter method-parameters: Each tag definition creates a method that will
     be called when the tag is invoked. This is the parameter list for that
     method. The basic form of the parameter list is ``(page[, process-body])``.
     ``page`` is an instance of :class:`<dylan-server-page>`. ``process-body``
     is an instance of :func:`<function>`. The ``process-body`` argument should
     be specified if and only if the ``body`` modifier is supplied.
   :parameter tag-call-parameters: ``tag-call-parameters`` allows you to
     receive named keyword arguments from a tag call. For example, if your
     tag call looks like ``<xx:foo arg1="one" arg2="2">`` then
     ``tag-call-parameters`` might look like ``(arg1, arg2)`` in which case
     ``body`` code may refer to ``arg1`` and ``arg2``. If the tag call
     doesn't specify a given ``tag-call-parameter`` then ``#f`` will be used.
     If a ``tag-call-parameter`` has a type specifier, then the passed argument
     will be parsed into the appropriate type before it is passed. See the
     :func:`parse-tag-arg` generic function. Note that this means specifying a
     type of which ``#f`` is not a member effectively makes the
     ``tag-call-parameter required``. For example, ``(arg1, arg2 :: <integer>)``
     specifies that ``arg1`` is optional (it will be a :class:`<string>` if
     supplied) and ``arg2`` is required and must be parsable to an :class:`<integer>`.
   :parameter body: The body of the tag definition. ``method-parameter`` and
     ``tag-call-parameters`` are bound within the body.

   :description:

     Defines a new tag named ``tag-name`` in the ``taglib-name`` tag library.
     For simple DSP tags with no body elements, the ``body`` code normally just
     does output to the output stream of the current response, generating dynamic
     output in place of the literal tag call in the source file. Tags that have
     body elements may additionally want to setup state for nested tags to use.
     This may be done, for example, through the use of dynamically bound thread
     variables or storing information in the session or page context.

     When the DSP engine invokes the tag to generate dynamic content it passes
     arguments that match ``method-parameters``. ``tag-call-parameters`` receive
     arguments specified in the tag call, in the DSP source file, after they
     have been parsed to the specified types.

   :example:

     A simple tag in the "demo" taglib that displays "Hello, world!" in the
     page. It is invoked with ``<demo:hello/>``:

     .. code-block:: dylan

       define tag hello in demo
           (page :: <dylan-server-page>)
           ()
         format(output-stream(current-response()), "Hello, world!");
       end;

     A tag that allows body elements, and processes the body elements three
     times. It is invoked with ``<demo:three-times>...whatever...</demo:three-times>``:

     .. code-block:: dylan

       define body tag three-times in demo
           (page :: <dylan-server-page>,
            do-body :: <function>)
           ()
         for (i from 1 to 3)
           do-body();
         end;
       end;

.. macro:: taglib-definer

   Defines a new tag library.

   :signature: define taglib taglib-name () end

   :parameter taglib-name: The name of the tag library.

.. generic-function:: validate-form-field

   :signature: validate-form-field (field-name validator) => (#rest results)

   :parameter field-name: An instance of ``<object>``.
   :parameter validator: An instance of ``<object>``.
   :value #rest results: An instance of ``<object>``.



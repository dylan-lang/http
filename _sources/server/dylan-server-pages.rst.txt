Dylan Server Pages (DSP)
************************

Overview
========

Dylan Server Pages (DSP) is a template engine for providing dynamic web site
content.  All dynamic content is invoked via DSP tag calls, which take the form
``<taglib:tag-name/>``, where ``taglib`` is a tag library you define and
``tag-name`` is the name of a tag in that tag library.

Currently, a DSP application is implemented as a Dylan project that uses the
HTTP server library. This effectively means that each DSP application has to
run on a different server and therefore on a different HTTP port. (The plan is
to eventually fix it to load DSP application libraries at runtime, based on
configuration files.)

DSP Content Authoring
=====================

Authoring Overview
------------------

DSP templates contain normal HTML plus DSP tag calls. DSP tag calls generate
the dynamic content of your web pages. They use standard XML syntax.
For example, ``<mylib:mytag arg="foo"/>`` is tag call with no body that passes
one argument, arg, to mytag when it is invoked. "mylib" tells the DSP template
engine what tag library (taglib for short) "mytag" will be found in.

There are several special tags called :ref:`dsp-directives` defined that
couldn't easily have been defined by the user.  DSP directives use the same
syntax as other tags, but they use the special tag library name ``%dsp``. For
example, the include directive looks like this::

  <%dsp:include location="foo.dsp"/>

Each top-level template file must have a corresponding instance of
:class:`<dylan-server-page>` associated with it. This is accomplished with the
``define page`` macro, which also publishes the URLs associated with the page.

DSP template files may have any filename extension, but the extension ".dsp"
may be treated specially in the future. For example, .dsp files may eventually
be automatically exported as :class:`<dylan-server-page>` .

.. _dsp-directives:

DSP Directives
--------------

A DSP directive is used much like a normal DSP tag, but it couldn't be written
as a normal tag without special support from the DSP engine. DSP directives
are distinguished by the ``%dsp`` tag prefix.
There are two built in DSP directives:

**%dsp:include**
  Includes another DSP template (or plain HTML file) in the current page.
  Example usage:

  .. code-block:: dylan

    <%dsp:include location="header.dsp"/>

  Note that if the location given is absolute (i.e., begins with a slash) then
  the document is looked up relative to the document root directory.
  Otherwise it is looked up relative to the directory containing the current
  document.

**%dsp:taglib**
  Declares another tag library to be in effect for the remainder of the page.
  Taglib directives are cumulative. That is, using two or more ``%dsp:taglib``
  directives on the same page means that tags in either taglib may be used on
  that page. Example usage:

  .. code-block:: dylan

    <%dsp:taglib name="my-taglib" prefix="xx"/>
    ...
    <xx:my-tag/>
    ...

  The value of the name argument must be the same as the name in a
  :macro:`taglib-definer` form. The prefix may contain any characters except
  for ``<`` and ``:`` and may not be ``%dsp``.

The "dsp" Tag Library
---------------------

The "dsp" taglib defines a few tags that are generally useful for any web
application.

**dsp:if**
  Conditionally includes its body content if a predicate returns true.
  Example usage:

  .. code-block:: dylan

    <dsp:if test="my-predicate?">
      <dsp:then>...true part...</dsp:then>
      <dsp:else>...false part...</dsp:else>
    </dsp:if>

  Note that there may be multiple ``dsp:then`` and ``dsp:else`` tags inside the
  same ``dsp:if`` tag body. If there is any plain HTML in the body of the
  ``dsp:if``, and outside of any ``dsp:then`` or ``dsp:else`` tags, it will
  always be displayed.

**dsp:then**
  Executes its body only if the test predicate of the containing ``dsp:if`` tag
  returned true. When not contained in the body of a ``dsp:if`` tag its body
  will not be executed.

**dsp:else**
  Executes its body only if the test predicate of the containing ``dsp:if`` tag
  returned false. When not contained in the body of a ``dsp:if`` tag its body
  will not be executed.

**dsp:table**
  TBD. Haven't quite settled on a design here yet.

**dsp:table-row-number**
  Displays the one-based number of the row currently being displayed.

DSP Programming
===============

Tag Libraries
-------------

Tags can be organized into separate tag libraries if needed (e.g., for large
web apps). Each DSP page may use the ``%dsp:taglib`` directive to specify
which tag libraries are active for that page. The built-in "dsp" tag library
is automatically available to all DSP pages, without having to use the
``%dsp:taglib`` directive to make it active. The "dsp" taglib includes some tags
that are useful for almost all web pages.

Taglibs are fairly uninteresting as far as programming a DSP application goes.
They are only used when defining tags and named methods, to specify which
taglib those objects belongs to. They are defined as follows:

.. code-block:: dylan

    define taglib demo ()
    end;

The above defines a taglib named "demo". See the :ref:`tags` section for how
the taglib is specified when defining a tag. This taglib would be included in
a page with the following directive:

.. code-block:: dylan

    <%dsp:taglib name="demo" prefix="xyz"/>

and its tags would then be used like this:

.. code-block:: dylan

    <xyz:tag-one/>

Note that ``prefix`` is optional, and defaults to the value of ``name``.

.. _tags:

Tags
----

Tags are defined with the ``define tag`` macro. The syntax is:

.. code-block:: dylan

    define [body] tag tag-name [in taglib-name]
        (method-parameters)
        (tag-parameters)
      ...code...
    end;

The following example tag should clear things up a bit:

.. code-block:: dylan

    define tag current-time in demo
        (page :: <dylan-server-page>)
        (style)
      write(output-stream(current-response()), current-time(style));
    end;

The above defines a tag called ``current-time`` in the ``demo`` taglib which
outputs the current time in the DSP page. See the :macro:`tag-definer` macro
for a full description tag definition. The above tag would be called like this:

.. code-block:: dylan

    <%dsp:taglib name="demo" prefix="xyz"/>
    <xyz:current-time style="24hr"/>
    
Note that ``style`` defines a parameter for the tag call such that the ``style``
variable is bound to the value of that parameter in the body of the tag
definition.
The tag function must always accept one argument: ``page``, an instance of
:class:`<dylan-server-page>`.

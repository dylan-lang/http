Module:    dsp
Author:    Carl Gay
Synopsis:  Dylan Server Pages
Copyright: See LICENSE in this distribution for details.


// See .../http/examples/http-server-demo/ for example DSP usage.

// TODO: separate out the template parsing so that it's possible to
//       use different template parsers easily.

define variable *reparse-templates?* :: <boolean> = #f;

define class <dsp-error> (<format-string-condition>, <error>) end;

define class <dsp-parse-error> (<dsp-error>) end;

// for error reporting
define thread variable *template-locator* :: false-or(<locator>) = #f;

define function parse-error
    (format-string :: <string>, #rest format-arguments)
  let prefix = if (*template-locator*)
                 concatenate("Error parsing template ",
                             as(<string>, *template-locator*), ": ");
               end | "";
  signal(make(<dsp-parse-error>,
              format-string: concatenate("%s", format-string),
              format-arguments: apply(vector, prefix, format-arguments)))
end;

define class <tag-argument-parse-error> (<dsp-parse-error>) end;


//
// Dylan Server Pages
//

// The only required init arg for this class is source:, which should
// be the location of the top-level template.
//
define open primary class <dylan-server-page> (<expiring-mixin>, <resource>)
  // A sequence of strings and functions.  Strings are output directly
  // to the network stream.  The functions are created by 'define tag'.
  slot page-template :: false-or(<dsp-template>) = #f;

  // This is merged against the working directory if it is not absolute.
  // (Note that the server has a --working-directory option.)
  constant slot %page-source :: <file-locator>,
    required-init-keyword: source:;
end;

define method make
    (class :: subclass(<dylan-server-page>), #rest args, #key source :: <pathname>)
 => (dsp :: <dylan-server-page>)
  apply(next-method, class,
        source: as(<file-locator>, source),
        args)
end;

define method default-content-type
    (resource :: <dylan-server-page>)
 => (content-type :: <byte-string>)
  "text/html"
end;

// This is here (rather than in "make" or "initialize") because there is an
// option to set the working directory and we want to respect it, and we don't
// want to depend on file load order.
define method page-source
    (page :: <dylan-server-page>) => (source :: <file-locator>)
  merge-locators(page.%page-source, working-directory())
end;

define method respond-to-post
    (page :: <dylan-server-page>, #key) => ()
  process-template(page);
end;

define method respond-to-get
    (page :: <dylan-server-page>, #key) => ()
  process-template(page);
end;

define method modified?
    (page :: <dylan-server-page>)
 => (modified? :: <boolean>)
  block ()
    ~date-modified(page)
      | file-property(page-source(page), #"modification-date") > page.date-modified
  exception (e :: <error>)
    #t  // i figure we want an error to occur if, say, the file was deleted.
  end
end;


//
// Templates, tags, taglibs
//

define class <taglib> (<object>)
  constant slot name :: <string>,
    required-init-keyword: name:;
  slot default-prefix :: <string>,
    init-keyword: prefix:;
  constant slot tag-map :: <string-table>,
    init-function: curry(make, <string-table>);
  constant slot named-method-map :: <string-table>,
    init-function: curry(make, <string-table>);
end class <taglib>;

// This is used in a macro expansion below, but the compiler still warns.
ignorable(default-prefix-setter);

// Make the prefix default to the taglib name.
//
define method make
    (class == <taglib>, #key name, prefix)
 => (taglib :: <taglib>)
  next-method(class, name: name, prefix: prefix | name)
end method make;

define macro taglib-definer
  { define taglib ?:name ()
      ?properties
    end }
    => { begin
           let _taglib = make(<taglib>, name: ?"name");
           ?properties ;
           register-taglib(?"name", _taglib);
         end }

  properties:
    { } => { }

    // Prefix
    { prefix ?:expression; ... }
      => { default-prefix(_taglib) := ?expression; ... }

    // Actions

    { action ?:name; ... }
      => { register-named-method(_taglib, ?"name", ?name); ... }
    { action ?:name (?args:*) ?:body; ... }
      => { register-named-method(_taglib, ?"name", method (?args) ?body ; end); ... }

    // Tags
    // There are two syntaxes (one with the "body" modifier and one without) so that
    // we can ensure that if the tag isn't supposed to have a body the body will be
    // processed once and only once.  It sounds weird, but the alternative is to simply
    // not display the body (if there is one), which might be very hard to debug, or
    // to make the user remember to deal with the body in each tag.

    { tag ?tag:name (?page:variable)
          (?tag-parameters:*)
        ?:body ;
      ... }
      => { local method ?tag ## "-tag" (?page, _do-body, #key ?tag-parameters, #all-keys)
                   ?body;
                   _do-body();  // process the tag body, if any, exactly once
                 end;
           register-tag(make(<tag>,
                             name: ?"tag",
                             function: ?tag ## "-tag",
                             allow-body?: #f,
                             parameter-names: snarf-tag-parameter-names(?tag-parameters),
                             parameter-types: snarf-tag-parameter-types(?tag-parameters)),
                        _taglib);
           ... }
    { body tag ?tag:name (?page:variable, ?do-body:variable)
          (?tag-parameters:*)
        ?:body ;
      ... }
      => { local method ?tag ## "-tag" (?page, ?do-body, #key ?tag-parameters, #all-keys)
                   ?body
                 end;
           register-tag(make(<tag>,
                             name: ?"tag",
                             function: ?tag ## "-tag",
                             allow-body?: #t,
                             parameter-names: snarf-tag-parameter-names(?tag-parameters),
                             parameter-types: snarf-tag-parameter-types(?tag-parameters)),
                        _taglib);
           ... }
end macro taglib-definer;

// define tag foo in tlib (page) () do-stuff end
// define body tag foo in tlib (page, do-body) (foo, bar :: <integer>) do-stuff end
//
define macro tag-definer
  // There are two syntaxes (one with the "body" modifier and one without) so that
  // we can ensure that if the tag isn't supposed to have a body the body will be
  // processed once and only once.  It sounds weird, but the alternative is to simply
  // not display the body (if there is one), which might be very hard to debug, or
  // to make the user remember to deal with the body in each tag.
  { define tag ?tag:name ?taglib-spec
        (?page:variable) (?tag-parameters:*)
      ?:body
    end }
  => { define tag-aux #f ?tag ?taglib-spec
           (?page, _do-body) (?tag-parameters)
         ?body;       // semicolon is needed even when ?body ends in semicolon.
         _do-body();  // process the tag body
       end
     }
  { define body tag ?tag:name ?taglib-spec
        (?page:variable, ?do-body:variable) (?tag-parameters:*)
      ?:body
    end }
  => { define tag-aux #t ?tag ?taglib-spec
           (?page, ?do-body) (?tag-parameters)
         ?body
       end
     }

  taglib-spec:
    /* { } => { dsp } */
    { in ?taglib:name } => { ?taglib }

end macro tag-definer;


define macro tag-aux-definer
  { define tag-aux ?allow-body:expression ?tag:name ?taglib:name
        (?page:variable, ?do-body:variable)
        (?tag-parameters:*)
      ?:body
    end }
  => { define method ?tag ## "-tag" (?page, ?do-body, #key ?tag-parameters, #all-keys)
         ?body
       end;
       register-tag(make(<tag>,
                         name: ?"tag",
                         function: ?tag ## "-tag",
                         allow-body?: ?allow-body,
                         parameter-names: snarf-tag-parameter-names(?tag-parameters),
                         parameter-types: snarf-tag-parameter-types(?tag-parameters)),
                    ?"taglib");
     }
end macro tag-aux-definer;

// snarf-tag-parameter-names(v1, v2 = t1, v3 :: t2, v4 :: t3 = d1)
// TODO: accept "keyword: name :: type = default" parameter specs.
define macro snarf-tag-parameter-names
  { snarf-tag-parameter-names(?params) }
    => { vector(?params) }
  params:
    { } => { }
    { ?param, ... }
      => { ?param, ... }
  param:
    { ?var:name ?rest:* }
      => { ?#"var" }
end;

// snarf-tag-parameter-types(v1, v2 = t1, v3 :: t2, v4 :: t3 = d1)
// TODO: accept "keyword: name :: type = default" parameter specs.
define macro snarf-tag-parameter-types
  { snarf-tag-parameter-types(?params) }
    => { vector(?params) }
  params:
    { } => { }
    { ?param, ... }
      => { ?param, ... }
  param:
    { ?var:name }
      => { <object> }
    { ?var:name = ?default:expression }
      => { <object> }
    { ?var:name :: ?type:expression }
      => { ?type }
    { ?var:name :: ?type:expression = ?default:expression }
      => { ?type }
end;

define function make-dummy-tag-call
    (prefix :: <string>, name :: <string>) => (call :: <tag-call>)
  make(<tag-call>,
       name: name,
       prefix: prefix,
       tag: $placeholder-tag,
       taglibs: #[])
end;

define method find-tag
    (taglib :: <taglib>, name :: <string>) => (tag :: false-or(<tag>))
  element(tag-map(taglib), name, default: #f)
end;

// Map names to tag libraries.
define constant $taglib-map :: <string-table> = make(<string-table>);

define method find-taglib
    (name :: <string>) => (taglib :: false-or(<taglib>))
  element($taglib-map, name, default: #f)
end;

define method register-taglib
    (name :: <string>, prefix :: <string>)
 => (taglib :: <taglib>)
  register-taglib(name, make(<taglib>, name: name, prefix: prefix));
end;

define method register-taglib
    (name :: <string>, taglib :: <taglib>)
 => (taglib :: <taglib>)
  when (element($taglib-map, name, default: #f))
    cerror("Replace the old tag library with the new one and continue",
           "A tag library named %= is already defined.",
           name);
  end;
  $taglib-map[name] := taglib;
end;

// All pages automatically have access to the following two taglibs.
define taglib %dsp () end;
define constant $%dsp-taglib :: <taglib> = find-taglib("%dsp");

define taglib dsp ()
  body tag %%placeholder-for-unparsable-tags
      (page :: <dylan-server-page>, process-body :: <function>)
      ()
    // TODO: allow user to configure whether this output is displayed.
    //       e.g., you don't want it in a production setting.
    begin
      output(" TAG PARSE ERROR ");
      process-body();
    end;
end taglib dsp;

define constant $dsp-taglib :: <taglib> = find-taglib("dsp");

define constant $placeholder-tag
  = find-tag($dsp-taglib, "%%placeholder-for-unparsable-tags");


//// Named methods

// Functions that can be looked up by name and thus can be used from within DSP tags
// like <dsp:if test="my-predicate">...</dsp:if>

define constant <named-method> = <function>;

define method register-named-method
    (taglib :: <taglib>, name :: <string>, fun :: <named-method>)
  named-method-map(taglib)[name] := fun;
end;

define method get-named-method
    (taglib :: <sequence>, name :: <string>)
 => (fun :: false-or(<named-method>))
  block (return)
    for (lib in taglib)
      // lib is pair(prefix, taglib)
      let f = get-named-method(tail(lib), name);
      f & return(f);
    end;
  end;
end;

define method get-named-method
    (taglib :: <taglib>, name :: <string>)
 => (fun :: false-or(<named-method>))
  element(named-method-map(taglib), name, default: #f)
end;

define method get-named-method
    (taglib :: <string>, name :: <string>)
 => (fun :: false-or(<named-method>))
  let tlib = find-taglib(taglib);
  tlib & get-named-method(tlib, name);
end;

define macro named-method-definer
  { define ?modifiers:* named-method ?:name ?taglib-spec (?arglist:*)
      ?valspec-and-body:* end }
  => { define ?modifiers method ?name (?arglist) ?valspec-and-body end;
       register-named-method(find-taglib(?"taglib-spec"), ?"name", ?name) }

  taglib-spec:
    { } => { dsp }
    { in ?taglib:expression } => { ?taglib }
end;



// Represents a tag _definition_.
define class <tag> (<object>)
  constant slot name :: <string>, required-init-keyword: name:;
  constant slot allow-body? :: <boolean>, required-init-keyword: allow-body?:;
  constant slot tag-function :: <function>, required-init-keyword: function:;
  constant slot parameter-names :: <sequence>, required-init-keyword: parameter-names:;
  constant slot parameter-types :: <sequence>, required-init-keyword: parameter-types:;
end;

define method make
    (class == <tag>, #rest args, #key name: tag-name)
 => (object :: <tag>)
  // Tag names are case-insensitive.  This is partly because the tag-definer
  // macro would need to accept an :expression rather than a :name if we want
  // to guarantee that case is preserved.
  apply(next-method, class, name: as-lowercase(tag-name), args);
end;

define method get-parameter-type
    (tag :: <tag>, parameter :: <symbol>) => (type :: false-or(<type>))
  block (return)
    for (name in parameter-names(tag),
         type in parameter-types(tag))
      name = parameter & return(type);
    end
  end
end;

// The user may add methods to this generic in order to parse tag
// arguments automatically for a given type.
define generic parse-tag-arg
    (name :: <object>, arg :: <object>, type :: <object>) => (value :: <object>);

// Default method just returns the argument unparsed.  Note that arg may be #f
// for things like 'nowrap' in the <td> element, which take no value.
//
define method parse-tag-arg
    (name, arg :: <object>, type :: <object>) => (value :: <object>)
  arg
end;

define method parse-tag-arg
    (name, arg :: <string>, type :: subclass(<integer>)) => (value :: <integer>)
  string-to-integer(arg)
end;

define method parse-tag-arg
    (name, arg :: <string>, type == <boolean>) => (value :: <boolean>)
  select (arg by string-equal?)
    "true", "yes", "on", "#t" => #t;
    "false", "no", "off", "#f" => #f;
    otherwise =>
      log-warning("Tag call argument %= should be a boolean value such as"
                  " true/false, yes/no, or on/off.  false will be used.",
                  arg);
      #f;
  end;
end;

define method parse-tag-arg
    (name, arg :: <string>, type == <symbol>) => (value :: <symbol>)
  as(<symbol>, arg)
end;

// Users can't define this parser because active-taglibs isn't exported.
// Think about exporting it or passing its value to parse-tag-arg.
define method parse-tag-arg
    (param, arg :: <string>, type == <named-method>)
 => (value :: <named-method>)
  let taglibs = active-taglibs();  // pairs of ("prefix" . taglib)
  get-named-method(taglibs, arg)
    | signal(make(<tag-argument-parse-error>,
                  format-string:
                    "For template file %s, %= is not a named-method in the "
                    "active taglibs (%s).  "
                    "While parsing the %= argument in a <%s:%s> tag.",
                  format-arguments:
                    // *template-locator* can be #f if we're being called
                    // explicitly during tag execution.  To fix it we'd have
                    // to store a back pointer in the tag call.  For now I'm
                    // just putting "unknown".  --cgay June 2009
                    vector(as(<string>, *template-locator* | "unknown"), arg,
                           join(taglibs, ", ", conjunction: " and ", key: first),
                           param, *tag-call*.prefix, *tag-call*.name)))
end;

// So tags can accept parameters of type <date>.
define method parse-tag-arg
    (name, arg :: <string>, type == <date>) => (value :: <date>)
  select (arg by string-equal?)
    "now", "current"
      => current-date();
    otherwise
      //---TODO: Parse dates here.
      => signal(make(<dsp-error>,
                     format-string: "Date parsing not yet implemented."));
  end;
end;


// Represents a specific call to a tag in a DSP template.
// Also used to represent DSP directives, such as <%dsp:include>,
// in which case the tag slot is not used.
//
define class <tag-call> (<object>)
  constant slot name :: <string>, required-init-keyword: name:;
  constant slot prefix :: <string>, required-init-keyword: prefix:;
  constant slot tag :: false-or(<tag>), init-keyword: tag:;
  // @see extract-tag-args
  // This should be a <string-table>, or better, a <case-insensitive-string-table>.
  // Even if attribute names are case insensitive, we should preserve the case,
  // and there's no guarantee of that when we convert them to symbols and back.
  // Besides, a table is a natural fit for this.  Can't remember why I did it
  // this way...  Maybe make <tag-call> a subclass of <attributes-mixin>?
  slot arguments :: <sequence> = #[], init-keyword: arguments:;
  slot body :: false-or(<dsp-template>) = #f, init-keyword: body:;
  // The taglibs in effect at the call site.  Used for looking up named methods.
  constant slot taglibs :: <sequence>, required-init-keyword: taglibs:;
end;

define method get-arg
    (call :: <tag-call>, arg-name :: <symbol>) => (val :: <object>)
  block (return)
    let arguments = arguments(call);
    for (item in arguments, i from 0)
      when (item = arg-name)
        return(arguments[i + 1]);
      end;
    end;
  end;
end;

define thread variable *tag-call* :: false-or(<tag-call>) = #f;

define function active-taglibs
    () => (taglibs :: <sequence>)
  iff(*tag-call*, *tag-call*.taglibs, #[])
end;

// API
// Apply the given function to the name and value of each tag call argument
// for the current tag, unless the name is in the exclude list.
//
define function map-tag-call-attributes
    (f :: <function>, #key exclude :: <sequence> = #[])
  let name = #f;
  for (item in iff(*tag-call*, *tag-call*.arguments, #[]),
       i from 0)
    iff(even?(i),
        name := item,
        unless (member?(name, exclude))
          f(name, item)
        end);
  end;
end;

// API
// This is used by tags that want to be able to accept arbitrary HTML attributes
// and pass them along in the generated HTML.
// @see the dsp:table tag.
//
define function show-tag-call-attributes
    (stream, #key exclude :: <sequence> = #[])
  map-tag-call-attributes(method (name, value)
                            iff(value,
                                format(stream, " %s=%=", name, quote-html(value)),
                                format(stream, " %s", name))
                          end,
                          exclude: exclude);
end function show-tag-call-attributes;

// API
define function get-tag-call-attribute
    (attr :: <object>, #key as: type :: <type> = <string>, test = \=)
 => (attribute-value :: <object>)
  block (return)
    map-tag-call-attributes(method (name, value)
                              if (test(name, attr))
                                return(as(type, value));
                              end;
                            end);
  end;
end;

define method execute (call :: <tag-call>, page);
  let tag :: <tag> = call.tag;
  // Might consider wrapping do-body in a method that logs a warning if the tag
  // isn't supposed to allow a body but one was supplied.
  let do-body
    = iff(call.body,
          curry(display-template, call.body, page),
          method () end);
  dynamic-bind (*tag-call* = call)
    apply(tag.tag-function, page, do-body, call.arguments);
  end;
end;

define method register-tag
    (tag :: <tag>, taglib :: <string>, #key replace?)
  let tlib = find-taglib(taglib);
  iff(~tlib,
      error("Couldn't find taglib named %s for tag %s.",
            taglib, name(tag)),
      register-tag(tag, tlib))
end;

define method register-tag
    (tag :: <tag>, taglib :: <taglib>, #key replace?)
 => (tag :: <tag>)
  when (element(taglib.tag-map, tag.name, default: #f))
    cerror("Replace the old tag with the new tag and continue",
           "A tag named %= is already defined in tag library %=.",
           tag.name, taglib.name);
  end;
  taglib.tag-map[tag.name] := tag;
end;

define method as
    (class :: subclass(<string>), call :: <tag-call>)
 => (s :: <string>)
  with-output-to-string(out)
    format(out, "<%s:%s", call.prefix, call.name);
    for (arg in call.arguments,
         i from 1)
      format(out, iff(odd?(i), " %s=", "%="), arg);
    end;
    format(out, ">");
  end;
end;


// A <dsp-template> represents the items in a parsed .dsp file, or part thereof.
//
define class <dsp-template> (<object>)
  constant slot contents :: <string>,
    required-init-keyword: contents:;
  // When the the bug that prevents the <substring> class from working
  // is fixed, nuke these two slots.
  constant slot content-start :: <integer>,
    required-init-keyword: content-start:;
  slot content-end :: <integer>,
    required-init-keyword: content-end:;
  constant slot entries :: <stretchy-vector>,
    init-function: curry(make, <stretchy-vector>);
  constant slot source :: false-or(<locator>) = #f,
    init-keyword: source:;
  slot date-modified :: false-or(<date>) = #f,
    init-keyword: date-modified:;
end class <dsp-template>;

// Unused.  Only content-end-setter is used, so this needs looking into.
ignore(content-end);

define method add-entry!
    (tmplt :: <dsp-template>, entry :: <object>)
  add!(tmplt.entries, entry);
end;

// A template is considered modified if its source has been updated or
// any of its subtemplates have been modified.
//
define method modified?
    (tmplt :: <dsp-template>) => (modified? :: <boolean>)
  (tmplt.source
   & (~tmplt.date-modified
      | file-property(tmplt.source, #"modification-date") > tmplt.date-modified))
  | any?(method (entry)
           instance?(entry, <dsp-template>) & modified?(entry)
         end,
         tmplt.entries)
end method modified?;



// Default method on respond-to-get processes the DSP template and displays
// the result.  Subclasses can either call this with next-method() or call
// process-template explicitly.
//

// Subclasses of <dylan-server-page> can call this in their respond-to
// methods if they decide they want the DSP template to be processed.  (They
// may also skip template processing by calling some other respond-to
// method, throwing an exception, etc.
//
define open method process-template
    (page :: <dylan-server-page>)
  when (~page-template(page)
          | (*reparse-templates?*
               & (modified?(page) | modified?(page-template(page)))))
    let source = page.page-source;
    if (page-template(page))
      log-debug("Reparsing modified page %s", source);
    end;
    page.date-modified := file-property(source, #"modification-date");
    page.page-template := parse-page(page);
  end;
  display-template(page.page-template, page);
end method process-template;

define method display-template
    (tmplt :: <dsp-template>, page :: <dylan-server-page>)
  if (tmplt.source)
    log-debug("Displaying template %s", tmplt.source);
  end;
  for (item in tmplt.entries)
    select (item by instance?)
      <string>
        => write(current-response(), item);
      // A subtemplate is created for tag bodies and for the "include" directive.
      <dsp-template>
        => display-template(item, page);
      <function>
        => item(page);
      <tag-call>
        => execute(item, page);
      otherwise
        => signal(make(<dsp-error>,
                       format-string: "Invalid DSP template element"));
    end;
  end for;
end method display-template;

define function initial-taglibs-for-parse-template
    () => (taglibs :: <stretchy-vector>)
  // More than 3 user taglib directives seems unlikely...
  let taglibs :: <stretchy-vector> = make(<stretchy-vector>, capacity: 4);
  add!(taglibs, pair(default-prefix($dsp-taglib), $dsp-taglib));
  taglibs
end;

define method parse-page
    (page :: <dylan-server-page>)
 => (template :: <dsp-template>)
  let source = merge-locators(page.page-source, working-directory());
  pt-debug("Parsing page %s", as(<string>, source));
  let string = file-contents(source);
  if (~string)
    resource-not-found-error();
  else
    page.date-modified := file-property(page.page-source, #"modification-date");
    let tmplt = make(<dsp-template>,
                     contents: string,
                     content-start: 0,
                     content-end: size(string),
                     source: page.page-source,
                     date-modified: current-date());
    dynamic-bind (*template-locator* = source)
      parse-template(page, tmplt, initial-taglibs-for-parse-template(), list());
    end;
    tmplt
  end;
end method parse-page;

// @param bpos points directly after a '<' char in buffer.
// @return tag-prefix and its associated taglib.
define function parse-tag-prefix
    (buffer, taglib-specs, bpos, epos) => (prefix, taglib)
  local method parse-prefix (spec-index :: <integer>)
          if (spec-index >= size(taglib-specs))
            iff(string-equal-ic?("%dsp:", buffer, start2: bpos, end2: min(epos, bpos + 5)),
                values("%dsp", #"directive"),
                values(#f, #f))
          else
            let spec = taglib-specs[spec-index];
            let prefix = head(spec);
            let taglib = tail(spec);
            let prefix-colon = concatenate(prefix, ":");
            iff(string-equal-ic?(prefix-colon, buffer,
                                 start2: bpos, end2: min(epos, bpos + prefix-colon.size)),
                values(prefix, taglib),
                parse-prefix(spec-index + 1))
          end
        end;
  parse-prefix(0)
end function parse-tag-prefix;

// Parse a DSP directive (a <%dsp:xxx> tag) and its body.  DSP directives may
// not follow the simple XML <tag>...body...</tag> format.  e.g., %dsp:if has
// the format <%dsp:if>...body1...<%dsp:else>...body2...</%dsp:if>.
// @return the index following the end tag.
define function parse-dsp-directive
    (page, tmplt, taglibs, tag-stack, call, tag-start, body-start, has-body?)
 => (scan-pos :: <integer>)
  select (call.name by string-equal?)
    "include"
      => parse-include-directive(page, tmplt, taglibs, tag-stack, call,
                                 tag-start, body-start, has-body?);
    "taglib"
      => parse-taglib-directive(page, tmplt, taglibs, call, tag-start,
                                body-start, has-body?);
    otherwise
      => parse-error("Unrecognized DSP directive %= at position %d",
                     call.name, tag-start);
  end;
end;

define function parse-include-directive
    (page, tmplt, taglibs, tag-stack, call, tag-start, body-start, has-body?)
 => (scan-pos :: <integer>)
  when (has-body?)
    log-warning("Invalid include tag %s in template %s:%d.  ",
                as(<string>, call), as(<string>, page.page-source), tag-start);
    log-warning("The include directive doesn't allow a body; it should end in '/>'.");
  end;
  // #"location" is preferred here because URL and URI can be misleading.  This
  // is relative to the source location of the page template, not relative to the
  // requested URL
  let url = get-arg(call, #"location") | get-arg(call, #"uri") | get-arg(call, #"url");
  if (~url)
    parse-error("In template %=, '%%dsp:include' directive must have a "
                  "'location' attribute.",
                as(<string>, page.page-source));
  end;
  let source = merge-locators(as(<file-locator>, url),
                              page.page-source.locator-directory);
  let contents = source & file-contents(source);
  if (contents)
    let subtemplate = make(<dsp-template>,
                           source: source,
                           contents: contents,
                           content-start: 0,
                           content-end: size(contents),
                           date-modified: current-date());
    dynamic-bind (*template-locator* = source)
      parse-template(page, subtemplate, initial-taglibs-for-parse-template(), tag-stack);
    end;
    add-entry!(tmplt, subtemplate);
  else
    parse-error("In template %=, included file %= not found.",
                as(<string>, page.page-source), url);
  end;
  body-start
end;

// Note that the end of comment string may have whitespace between -- and >.
// @param bpos points directly after the opening comment string "<!--".
// @return the position in buffer directly following the next end of comment
//         string, or size(buffer) if the comment isn't terminated.
define function html-comment-end
    (buffer :: <string>, bpos :: <integer>) => (comment-end :: <integer>)
  block (return)
    let epos :: <integer> = size(buffer);
    iterate loop (pos = bpos)
      when (pos < epos - 3)       // 3 to account for "-->"
        let potential-end = find-substring(buffer, "--", start: pos, end: epos);
        when (potential-end)
          let non-white = skip-whitespace(buffer, potential-end + 2, epos);
          iff(non-white < epos & buffer[non-white] = '>',
              return(non-white + 1),
              loop(potential-end + 1));
        end;
      end;
    end;
    return(size(buffer));  // comment not terminated
  end block
end;

/**
This is an ad-hoc recursive descent parser for a Dylan Server Page template.
It searches for the next recognizable start tag or DSP directive in the given
template (between tmplt.content-start and tmplt.content-end).  It adds plain
content (i.e., the text between recognized tags) to the current template. Tags
are parsed and added to the template as <tag-call>s.  If the tag has a body,
parse-template calls itself recursively to parse the body, and returns when
it finds the matching end tag.  (This allows for nesting tags of the same name.)

@param page is the top-level page being parsed.
@param tmplt is the current (sub)template being side-effected.
@param taglibs are pairs of the form #(prefix . taglib) created by taglib
       directives in the page.  The default taglib (dsp) is always present.
       Since taglib directives apply from where they occur to the bottom of the
       page, taglibs is a <stretchy-vector> so new items can be added as they're found.
@param tag-stack is the stack of tags seen so far in the recursive descent parser.
       i.e., we expect to see closing tags for each one, in order.  It is a list
       of <tag-call> objects.
*/

define function parse-taglib-directive
    (page, tmplt, taglibs, call, tag-start, body-start, has-body?)
 => (scan-pos :: <integer>)
  when (has-body?)
    //---*** TODO: fix this to simply include the body in the parent template.
    parse-error("Invalid taglib directive in template %=.  "
                "The taglib directive can't have a body.",
                page.page-source);
  end;
  let tlib-name = get-arg(call, #"name");
  let tlib-prefix = get-arg(call, #"prefix");
  if (~tlib-name)
    parse-error("Invalid taglib directive in template %=.  "
                "You must specify a taglib name with name=\"taglib-name\".",
                page.page-source);
  else
    let tlib = find-taglib(tlib-name);
    iff(~tlib,
        parse-error("Invalid taglib directive in template %=.  "
                    "The tag library named %= was not found.",
                    page.page-source, tlib-name),
        add!(taglibs, pair(tlib-prefix | tlib-name, tlib)));
  end;
  body-start
end;

define constant $debugging-templates :: <boolean> = #f;

// this should be replaced with a specialized log or log category
define function pt-debug
    (format-string, #rest args)
  when ($debugging-templates)
    apply(log-debug, format-string, args);
  end;
end;

// @param page is really only passed so page.page-source can be used in error messages.
// @param tmplt is the <dsp-template> that is being parsed.  It is side-effected.
// @param taglibs are the taglibs in effect for the parse.  Each time a %dsp:taglib
//        directive is encountered the new taglib is added to the end.  Note that the
//        scope of a taglib directive is from where it occurs to the end of the page.
//        Each entry is pair(taglib-prefix, taglib).
// @param tag-stack represents the nesting of tag calls in a page, so we know what
//        end tag to expect.
define method parse-template (page :: <dylan-server-page>,
                              tmplt :: <dsp-template>,
                              taglibs :: <stretchy-vector>,
                              tag-stack :: <list>)
 => (end-of-template-index :: <integer>)

  let buffer :: <string> = tmplt.contents;
  let bpos :: <integer> = tmplt.content-start;
  let epos :: <integer> = size(buffer);  // was tmplt.content-end;
  let scan-pos :: <integer> = bpos;
  let html-pos :: <integer> = bpos;          // beginning of current non-tag chunk
  let end-tag = ~empty?(tag-stack)
                & sformat("</%s:%s>", head(tag-stack).prefix, head(tag-stack).name);
  pt-debug("parse-template: enter.  scan-pos = %d, tag-end = %=",
           scan-pos, end-tag);
  block (return)
    while (scan-pos < epos)
      let tag-start :: false-or(<integer>) = char-position('<', buffer, scan-pos, epos);
      if (~tag-start)
        // put the remainder of the buffer in the template as a string.
        iff(html-pos < epos,
            add-entry!(tmplt, substring(buffer, html-pos, epos)));
        pt-debug("parse-template: No tag-start, returning epos = %d.", epos);
        return(epos);
      elseif (string-equal-ic?("<!--", buffer, start2: tag-start, end2: tag-start + 4))
        pt-debug("parse-template: Found HTML comment start. Skipping to end.");
        scan-pos := html-comment-end(buffer, tag-start + 4);
      elseif (end-tag & string-equal-ic?(end-tag, buffer,
                                         start2: tag-start,
                                         end2: tag-start + end-tag.size))
        // done parsing the body of a tag as a subtemplate
        iff(html-pos < tag-start,
            add-entry!(tmplt, substring(buffer, html-pos, tag-start)));
        pt-debug("parse-template: Found end tag %=. Returning %d.",
                  end-tag, tag-start + size(end-tag));
        return(tag-start + size(end-tag))
      else
        let (tag-prefix, taglib) = parse-tag-prefix(buffer, taglibs, tag-start + 1, epos);
        if (~tag-prefix)
          // tag-start points to '<' but not to a known tag prefix like "<%dsp:"
          scan-pos := tag-start + 1;
        else
          // ok, found a valid-looking tag prefix like "<%dsp:" in a known taglib.
          let directive? = (taglib = #"directive");
          iff(html-pos < tag-start,
              add-entry!(tmplt, substring(buffer, html-pos, tag-start)));
          let (call, has-body?, body-start)
            = parse-start-tag(page, buffer, tag-start,
                              iff(directive?, $%dsp-taglib, taglib),
                              taglibs, tag-prefix, directive?);
          pt-debug("parse-template: Done parsing start tag %s:%s.  body-start = %d.",
                    call.prefix, call.name, body-start);
          scan-pos := if (directive?)
                        parse-dsp-directive(page, tmplt, taglibs, tag-stack, call,
                                            tag-start, body-start, has-body?)
                      else
                        add-entry!(tmplt, call);
                        if (has-body?)
                          call.body := make(<dsp-template>,
                                            contents: tmplt.contents,
                                            content-start: body-start,
                                            content-end: epos);
                          call.body.content-end
                            := parse-template(page, call.body, taglibs, pair(call, tag-stack));
                        else
                          body-start
                        end if
                      end if;
          html-pos := scan-pos;
        end if;
      end if;
    end while;
    epos        // didn't return from block early, so must be at end of buffer
  end block
end method parse-template;

// Parse an opening DSP tag like <xx:foo arg=blah ...> or <xx:foo .../>
// If an error occurs during parsing, a dummy tag is returned that will
// display a placeholder when the DSP page is rendered and a warning will
// be logged.
// @param buffer is the string containing the dsp tag.
// @param bpos is the index of (for example) "<prefix:" in buffer.
// @param prefix is e.g. "dsp".
// @param taglib is the taglib corresponding to prefix.
// @param taglibs are the taglibs in effect at the tag call site.
// @param directive? is true iff prefix is "%dsp".
define function parse-start-tag (page :: <dylan-server-page>,
                                 buffer :: <string>,
                                 bpos :: <integer>,
                                 taglib :: <taglib>,
                                 taglibs :: <stretchy-vector>,
                                 prefix :: <string>,
                                 directive?)
 => (tag-call :: <tag-call>, has-body?, body-start)
  let name-start = bpos + size(prefix) + 2;  // 2 for the < and : characters
  let epos = size(buffer);
  let name-end = end-of-word(buffer, name-start, epos);
  let name = as-lowercase(copy-sequence(buffer, start: name-start, end: name-end));
  let tag = find-tag(taglib, name);
  let tag-call = if (directive? | tag)
                   make(<tag-call>,
                        name: name,
                        prefix: prefix,
                        tag: tag,
                        taglibs: copy-sequence(taglibs))
                 else
                   log-warning("In template %=, the tag %= was not found.  "
                               "The active taglibs are %s.",
                               as(<string>, page.page-source),
                               name,
                               join(taglibs, ", ",
                                    key: first, conjunction: " and "));
                   tag := $placeholder-tag;
                   make-dummy-tag-call(prefix, name);
                 end;
  // *tag-call* is bound here so that it will be the same during parsing
  // as it is during execution.  parse-tag-arg needs it.
  dynamic-bind (*tag-call* = tag-call)
    let (tag-args, has-body?, end-index) = extract-tag-args(buffer, name-end, epos, tag);
    tag-call.arguments := tag-args;
    when (has-body? & ~tag.allow-body?)
      log-warning("While parsing template %s, at position %=:"
                  " The %s:%s tag call should end with \"/>\" since this tag doesn't "
                  "allow a body.  No body will be processed for this tag.",
                  as(<string>, page.page-source), bpos, prefix, name);
      has-body? := #f;
    end;
    values (tag-call, has-body?, end-index)
  end
end function parse-start-tag;

define function end-of-word (buffer :: <string>, bpos :: <integer>, epos :: <integer>)
  local method delim? (char :: <character>) => (b :: <boolean>)
          char = '>' | whitespace?(char)
        end;
  min(char-position-if(delim?, buffer, bpos, epos),
      find-substring(buffer, "/>", start: bpos, end: epos) | epos)
end;

// Parse the key1="val1" key2="val2" arguments from a call to a DSP tag.  Values may be
// quoted with either single or double quotes (or nothing, but quoting is recommended).
// There is no way to escape the quote characters.
// @return a list whos even elements are attribute names (symbols) and odd elements are
//         the corresponding values.  If a parser exists for the attribute's type the
//         value is parsed.
// TODO: This should return a table instead.
// TODO: The terminology is strange.  Should be "attributes" a la XML instead of
//       "tags" and "params".
define method extract-tag-args
    (buffer :: <byte-string>, bpos :: <integer>, epos :: <integer>, tag :: false-or(<tag>))
 => (args :: <sequence>, has-body? :: <boolean>, body-start :: <integer>)
  local method end-of-key? (char :: <character>) => (b :: <boolean>)
          char = '=' | char = '>' | whitespace?(char)
        end,
        method extract-key/val (buffer :: <byte-string>,
                                key-start :: <integer>)
          let key-end = min(char-position-if(end-of-key?,
                                             buffer, key-start, epos),
                            find-substring(buffer, "/>", start: key-start, end: epos) | epos);
          if (~key-end | key-end = key-start)
            error("invalid dsp tag.  couldn't find end of keyword argument");
          else
            let key = as(<symbol>, substring(buffer, key-start, key-end));
            let eq-pos = skip-whitespace(buffer, key-end, epos);
            let char = buffer[eq-pos];
            if (char ~= '=')
              // a key with no value.  e.g., <xx:foo nowrap> where nowrap has no value.
              values(key,
                     #f,
                     skip-whitespace(buffer, key-end, epos))
            else
              let val-start = skip-whitespace(buffer, eq-pos + 1, epos);
              let quote-char = buffer[val-start];
              let quote-char? = (quote-char = '\'' | quote-char = '"');
              let val-end = iff(quote-char?,
                                char-position(quote-char, buffer, val-start + 1, epos),
                                end-of-word(buffer, val-start, epos))
                          | epos;
              values(key,
                     substring(buffer, iff(quote-char?, val-start + 1, val-start), val-end),
                     iff(quote-char?, val-end + 1, val-end))
            end if
          end if
        end method;
  // iterate once for each key/val pair
  iterate loop (start = skip-whitespace(buffer, bpos, epos),
                args = list())
    if (start >= epos)
      values(args, #f, epos)
    elseif (string-equal-ic?(">", buffer, start2: start, end2: start + 1))
      values(args, #t, start + 1)
    elseif (string-equal-ic?("/>", buffer, start2: start, end2: start + 2))
      values(args, #f, start + 2)
    else
      let (param, val, key/val-end) = extract-key/val(buffer, start);
      let ptype = param & tag & get-parameter-type(tag, param);
      loop(skip-whitespace(buffer, key/val-end, epos),
           iff(param,
               pair(param, pair(parse-tag-arg(param, val, ptype), args)),
               args));
    end if
  end iterate
end method extract-tag-args;

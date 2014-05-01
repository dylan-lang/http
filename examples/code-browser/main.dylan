Module:   code-browser
Synopsis: Browse Open Dylan environment objects
Author:   Andreas Bogk, Bastian Mueller, Hannes Mehnert

define thread variable *project* = #f; 
define thread variable *environment-object* = #f;

define function callback-handler (#rest args)
  log-debug("%=\n", args);
end function callback-handler;

define taglib code-browser () end;

define class <code-browser-page> (<dylan-server-page>)
end;

define generic environment-object-page (obj :: <environment-object>) => (res :: <code-browser-page>);

define class <raw-source-page> (<code-browser-page>)
end;

define variable *raw-source-page*
  = make(<raw-source-page>, source: "raw-source.dsp");

define method environment-object-page (object :: <environment-object>)
 => (res :: <code-browser-page>)
  *raw-source-page*;
end;
define macro code-browser-pages-definer
 { define code-browser-pages ?pages:* end }
 => { ?pages }

  pages:
   { } => { }
   { ?page:name, ... }
   => { define class "<" ## ?page ## "-page>" (<code-browser-page>)
        end;
        define variable "*" ## ?page ## "-page*"
          = make("<" ## ?page ## "-page>",
                 source: ?"page" ## ".dsp");
        define method environment-object-page
         (object :: "<" ## ?page ## "-object>") => (res :: "<" ## ?page ## "-page>")
           "*" ## ?page ## "-page*";
        end;
        ... }
end;

define code-browser-pages
  constant, domain, generic-function,
  \method, simple-function, \macro, module-variable,
  library, module, class //singleton missing? but it is not exported!
end;

define tag source in code-browser
    (page :: <code-browser-page>)
    ()
  output("%s",
         markup-dylan-source(environment-object-source(*project*,
                                                       *environment-object*)));
end;

define tag project-name in code-browser
    (page :: <code-browser-page>)
    ()
  output(*project*.project-name);
end;


define function markup-dylan-source(source :: <string>)
 => (processed-source :: <string>);
  let amp = compile-regex("&");
  let lt  = compile-regex("<");
  let gt  = compile-regex(">");
  regex-replace(regex-replace(regex-replace(source, amp, "&amp;"),
                              lt, "&lt;"),
                gt, "&gt;");
end function markup-dylan-source;

//XXX: refactor this into the specific tags - each tag which may be a reference
// knows for itself best where to link!
define tag canonical-link in code-browser
    (page :: <code-browser-page>)
    ()
  output("%s", do-canonical-link(*environment-object*));
end;
define method do-canonical-link (symbol)
  let name-object = environment-object-home-name(*project*, symbol);
  if (name-object)
    do-canonical-link(name-object)
  end;
end;

define method do-canonical-link (name-object :: <name-object>)
  let module-object = name-namespace(*project*, name-object);
  let module-name-object = environment-object-home-name(*project*, module-object);
  let library-object = name-namespace(*project*, module-name-object);
  concatenate("/symbol/", dylan-name(library-object),
              "/", dylan-name(module-name-object),
              "/", dylan-name(name-object));
end;

define method do-canonical-link (module-object :: <module-object>)
  let module-name-object = environment-object-home-name(*project*, module-object);
  let library-object = name-namespace(*project*, module-name-object);
  concatenate("/symbol/", dylan-name(library-object),
              "/", dylan-name(module-name-object));
end;

define method do-canonical-link (library-object :: <library-object>)
  concatenate("/symbol/", dylan-name(library-object))
end;

define method do-canonical-link (slot :: <slot-object>)
  do-canonical-link(slot-type(*project*, slot))
end;

define function dylan-name
    (definition :: <environment-object>)
 => (name :: <string>)
  let project = *project*;
  let name = environment-object-home-name(*project*, definition);
  if (name)
    environment-object-primitive-name(*project*, name)
  else
    environment-object-display-name(*project*, definition, #f, qualify-names?: #f)
  end
end;

define function html-name (symbol) // :: <definition-object>)
  (symbol & markup-dylan-source(dylan-name(symbol))) | "unknown symbol"
end;

define tag display-name in code-browser
    (page :: <code-browser-page>)
    ()
  output("%s", html-name(*environment-object*));
end;
define body tag used-definitions in code-browser
    (page :: <code-browser-page>, do-body :: <function>)
    ()
  for (used-definition in source-form-used-definitions(*project*, *environment-object*))
    dynamic-bind (*environment-object* = used-definition)
      do-body()
    end;
  end;
end;


//These tags are not used currently!
define tag project-sources in code-browser
    (page :: <code-browser-page>)
    ()
  dynamic-bind(*check-source-record-date?* = #f)
    output("<pre>\n");
    for(source in *project*.project-sources)
      block()
        output("<h3>%s</h3> module <strong>%s</strong>\n", 
               source-record-location(source),
               source-record-module-name(source));
        output(markup-dylan-source
                 (as(<byte-string>, source-record-contents(source))));
      exception(e :: <condition>)
        output("Source for %= unavailable because of %=\n",
               source,
               e);
      end block;
    end for;
    output("</pre>\n");
  end
end;

define tag project-used-libraries in code-browser
    (page :: <code-browser-page>)
    ()
  output("<ul>\n");
  for (library in project-used-libraries(*project*, *project*))
    let name = environment-object-display-name(*project*, library, #f);
    output("<li><a href=\"/project?name=%s\">%s</a></li>\n",
           name, name);
  end for;
  output("</ul>\n");
end;

define tag project-library in code-browser
    (page :: <code-browser-page>)
    ()
  output("%s", environment-object-display-name(*project*,
                                               project-library(*project*),
                                               #f));
end;


define tag project-modules in code-browser
    (page :: <code-browser-page>)
    ()
  output("<ul>\n");
  for (module in library-modules(*project*, project-library(*project*)))
    output("<li>%s</li>\n", environment-object-display-name(*project*, module, #f));
  end for;
  output("</ul>\n");
end;

define tag generic-function-object-methods in code-browser
    (page :: <code-browser-page>)
    ()
  output("<ul>\n");
  for (m in generic-function-object-methods(*project*,
      find-environment-object(*project*, "concatenate",
        library: project-library(*project*),
        module: first(library-modules(*project*, project-library(*project*))))))
    output("<li>%s</li>\n",
           markup-dylan-source(environment-object-display-name(*project*, m, #f)));
  end;
  output("</ul>\n");
end;


define tag clients in code-browser
    (page :: <code-browser-page>)
    ()
  output("<ul>\n");
  for (used-definition in source-form-clients(*project*, project-library(*project*)))
    output("<li>%s</li>", markup-dylan-source(environment-object-display-name(*project*, used-definition, #f)))
  end for;
  output("</ul>\n");
end;

define tag project-warnings in code-browser
    (page :: <code-browser-page>)
    ()
  output("<ul>\n");
  for (warning in project-warnings(*project*))
    output("<li>%s</li>", markup-dylan-source(environment-object-display-name(*project*, warning, #f)))
  end for;
  output("</ul>\n");
end;

/// Main

define method respond (page :: <code-browser-page>, #key library-name, module-name, symbol-name)
  if (library-name)
    let project = find-project(library-name);
    open-project-compiler-database(project, 
                                   warning-callback: callback-handler,
                                   error-handler: callback-handler);
    parse-project-source(project);
    dynamic-bind(*project* = project)
      let library = project.project-library;
      if (module-name)
        let module = find-module(project, module-name, library: library);
        if (symbol-name)
          let symbol
            = find-environment-object(project, symbol-name,
                                      library: library,
                                      module: module);
          dynamic-bind(*environment-object* = symbol)
            process-template(environment-object-page(*environment-object*));
          end;
        else
          dynamic-bind(*environment-object* = module)
            process-template(environment-object-page(*environment-object*));
          end;
        end;
      else
        dynamic-bind(*environment-object* = library)
          process-template(environment-object-page(*environment-object*));
        end;
      end;
    end;
  end;
end;

// Starts up the web server.
define function main () => ()
  *check-source-record-date?* := #f;
  populate-symbol-table();
  let foo = $all-symbols["$foo"][0];
  format-out("var-type %s name-type %s\n",
             variable-type(foo.symbol-entry-project,
                           name-value(foo.symbol-entry-project,
                                      foo.symbol-entry-name)),
             name-type(foo.symbol-entry-project,
                       foo.symbol-entry-name));
  let server = make(<http-server>);
  add-resource(server, "/symbol/{library-name}/{module-name?}/{symbol-name?}", make(<code-browser-page>));
  add-resource(server, "/search", make(<search-page>));
  http-server-main(server: server,
                   description: "Dylan Code Browser");
end;

define function collect-projects () => (res :: <collection>)
  let res = make(<stretchy-vector>);
  local method collect-project (dir :: <pathname>, filename :: <string>, type :: <file-type>)
          if (type == #"file" & filename ~= "Open-Source-License.txt")
            add!(res, filename);
          end;
        end;
  let regs = find-registries("x86-win32");
  let reg-paths = map(registry-location, regs);
  for (reg-path in reg-paths)
    if (file-exists?(reg-path))
      do-directory(collect-project, reg-path);
    end;
  end;
  res;
end;

define class <symbol-entry> (<object>)
  constant slot symbol-entry-name, required-init-keyword: name:;
  constant slot symbol-entry-project, required-init-keyword: project:;
end;

define constant $all-symbols = make(<string-table>);

define method add-symbol(project, name-object :: <binding-name-object>)
  *project* := project;
  if (name-exported?(project, name-object))
    let symbol-entry = make(<symbol-entry>, name: name-object, project: project);
    let symbol-name = get-environment-object-primitive-name(project, name-object);
    let symbol-entries = element($all-symbols, symbol-name, default: make(<stretchy-vector>));
    $all-symbols[symbol-name] := add!(symbol-entries, symbol-entry);
  end;
end;

//begin
//  populate-symbol-table();
//  for (ele in key-sequence($all-symbols))
//    format-out("%s %d\n", ele, $all-symbols[ele].size);
//  end;
//  main();
//end;

define variable $foo :: false-or(<integer>) = 23;

define function populate-symbol-table ()
  let projs = collect-projects();
  format-out("Found %d projects: %=\n", projs.size, projs);
  for (project-name in #("dylan", "code-browser")) //projs)
    block()
      format-out("Project %s\n", project-name);
      let project = find-project(project-name);
      open-project-compiler-database(project, 
                                     warning-callback: callback-handler,
                                     error-handler: callback-handler);
      parse-project-source(project);
      format-out("%=\n", project);
      do-namespace-names
        (method(module-name :: <module-name-object>)
           if (name-exported?(project, module-name))
             do-namespace-names(curry(add-symbol, project), project, 
                                name-value(project, module-name))
           end
         end,
         project, project-library(project));
    exception (e :: <condition>)
      format-out("Received exception %= in project %s\n", e, project-name);
    end;
  end;
  
  //main()
end;

/*
begin
  let class-graph = generate-class-graph("<string>");
  let filename = generate-graph(class-graph, find-node(class-graph, "<object>"));
  format-out("filename %s\n", filename);
end;

define function generate-class-graph (class-name :: <string>) => (res :: <graph>)
  let project = find-project("code-browser");
  open-project-compiler-database(project, 
                                 warning-callback: callback-handler,
                                 error-handler: callback-handler);
  parse-project-source(project);

  let library-object = project-library(project);
  let module-object
    = first(library-modules(project, project-library(project)));
  let class
    = find-environment-object(project, class-name, library: library-object, module: module-object);
  let todo = make(<deque>);
  let visited = make(<stretchy-vector>);
  push(todo, class);
  let graph = make(<graph>);

  local method get-class-name (class)
          split(environment-object-display-name(project, class, #f), ':')[0];
        end;
  while (todo.size > 0)
    let class = pop(todo);
    let class-name = get-class-name(class);
    let class-node = find-node(graph, class-name);
    unless (class-node)
      format-out("class node for %s was not found, creating\n", class-name);
      class-node := create-node(graph, label: class-name);
    end;
    class-node.attributes["URL"] := "http://www.foo.com";
    class-node.attributes["fillcolor"] := "red";
    class-node.attributes["style"] := "filled";
    add!(visited, class);
    let superclasses
      = class-direct-superclasses(project, class);
    format-out("superclasses for %s %=\n",
               class-name, map(get-class-name, superclasses));
    add-successors(class-node, map(get-class-name, superclasses));
    do(curry(push-last, todo),
       choose(method(x) ~ member?(x, visited) & ~ member?(x, todo) end,
              superclasses))
  end;
  graph;
end;
*/

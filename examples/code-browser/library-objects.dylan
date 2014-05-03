module: code-browser
Synopsis: Browse Open Dylan environment objects
Author:   Andreas Bogk, Bastian Mueller, Hannes Mehnert

define body tag libraries in code-browser
    (page :: <code-browser-page>, do-body :: <function>)
    ()
  do(method (project-name)
       block ()
         let project = find-project(project-name);
         open-project-compiler-database(project,
                                        warning-callback: callback-handler,
                                        error-handler: callback-handler);
         parse-project-source(project);
         let library = project-library(project);
         if (library)
           dynamic-bind(*project* = project, *environment-object* = library)
             do-body();
           end;
         end;
       exception (e :: <condition>)
         output("***library %s failed: %=***<br>\n", project-name, e);
       end block;
     end, collect-projects());
end;

define body tag modules in code-browser
    (page :: <code-browser-page>, do-body :: <function>)
    ()
  do-library-modules(method(x)
                       dynamic-bind(*environment-object* = x)
                         do-body()
                       end;
                     end, *project*, *environment-object*);
end;

define body tag defined-modules in code-browser
    (page :: <code-browser-page>, do-body :: <function>)
    ()
  do-library-modules(method(x)
                       dynamic-bind(*environment-object* = x)
                         do-body()
                       end;
                     end, *project*, *environment-object*, imported?: #f);
end;

define body tag used-libraries in code-browser
    (page :: <code-browser-page>, do-body :: <function>)
    ()
  do-used-definitions(method(x)
                       dynamic-bind(*environment-object* = x)
                         do-body()
                       end;
                     end, *project*, *environment-object*);
end;


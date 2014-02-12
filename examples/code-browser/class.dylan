module: code-browser
Synopsis: Browse Open Dylan environment objects
Author:   Andreas Bogk, Bastian Mueller, Hannes Mehnert

define body tag slots in code-browser
    (page :: <code-browser-page>, do-body :: <function>)
    ()
  do-all-slots(method(x)
                 dynamic-bind(*environment-object* = x)
                   do-body()
                 end
               end,
               *project*, *environment-object*);
end;

define body tag direct-superclasses in code-browser
    (page :: <code-browser-page>, do-body :: <function>)
    ()
  for (superclass in class-direct-superclasses(*project*, *environment-object*))
    dynamic-bind(*environment-object* = superclass)
      do-body()
    end;
  end for;
end;

define body tag direct-subclasses in code-browser
    (page :: <code-browser-page>, do-body :: <function>)
    ()
  for (subclass in class-direct-subclasses(*project*, *environment-object*))
    dynamic-bind(*environment-object* = subclass)
      do-body()
    end;
  end for;
end;

define tag slot-name in code-browser
    (page :: <code-browser-page>)
    ()
  output("%s", html-name(slot-getter(*project*, *environment-object*)));
end;

define tag slot-type in code-browser
    (page :: <code-browser-page>)
    ()
  output("%s", html-name(slot-type(*project*, *environment-object*)));
end;


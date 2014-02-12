module: code-browser
Synopsis: Browse Open Dylan environment objects
Author:   Andreas Bogk, Bastian Mueller, Hannes Mehnert

define tag variable-value in code-browser
    (page :: <code-browser-page>)
    ()
  let value = variable-value(*project*, *environment-object*);
  output("%=", value);
end;

define tag variable-type in code-browser
    (page :: <code-browser-page>)
    ()
  let type = variable-type(*project*, *environment-object*);
  output("<a href=\"%s\">%s</a>",
         do-canonical-link(type),
         html-name(type));
end;

define tag thread-variable in code-browser
    (page :: <code-browser-page>)
    ()
  if (instance?(*environment-object*, <thread-variable-object>))
    output("thread");
  end
end; 

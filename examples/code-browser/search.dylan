module: code-browser
Synopsis: Browse Open Dylan environment objects
Author:   Andreas Bogk, Bastian Mueller, Hannes Mehnert


define thread variable *results* = #f;

define class <search-page> (<resource>)
end;

define method respond (page :: <search-page>, #key)
  set-header(current-response(), "Content-Type", "text/html");
  let search-string = get-query-value("search");
  let results = element($all-symbols, search-string, default: #());
  dynamic-bind(*results* = results)
    process-template(*result-page*);
  end;
end;

define class <result-page> (<code-browser-page>)
end;

define variable *result-page*
  = make(<result-page>, source: "results.dsp");

define body tag results in code-browser
    (page :: <code-browser-page>, do-body :: <function>)
    ()
  for (result in *results*)
    dynamic-bind(*project* = result.symbol-entry-project)
      dynamic-bind(*environment-object* = result.symbol-entry-name)
        do-body()
      end;
    end;
  end;
end;


Module:   dylan-user
Synopsis: Browse FD environment objects
Author:   Andreas Bogk

define library code-browser
  use dylan;
  use common-dylan,
    import: { common-extensions };
  use io,
    import: { format, format-out, streams };
  use system,
    import: { locators, threads, file-system };
  use http-common;
  use http-server;
  use dsp;

  use environment-protocols;
  //use environment-reports;
  use environment-manager;
  use source-control-manager;

  use dfmc-environment-projects;
 
  use registry-projects;

  use source-records;
  use release-info;
  use regular-expressions;
  // use graphviz-renderer;
//use environment-deuce;
  export code-browser;
end;


define module code-browser
  use dylan;
  use threads;
  use common-extensions,
    exclude: { format-to-string };
  use locators,
    exclude: { <http-server> };
  use format;
  use format-out;
  use streams;
  use file-system;
  use http-common;
  use http-server;
  use dsp;
  use regular-expressions;
  use source-records;
  use source-records-implementation;
  use environment-protocols,
    exclude: { <singleton-object>, 
               application-filename,
               application-arguments };
  use release-info;
  use registry-projects;
  // use graphviz-renderer;
//  use environment-deuce;

  export $foo;
end;


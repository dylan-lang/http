Module:   dylan-user
Synopsis: HTTP server example code
Author:   Carl Gay

define library http-server-demo
  use common-dylan,
    import: { common-extensions };
  use dsp;
  use dylan;
  use http-common;
  use http-server;
  use io,
    import: { format, streams };
  use system,
    import: { locators, threads };
end;


define module http-server-demo
  use common-extensions,
    exclude: { format-to-string };
  use dsp;
  use dylan;
  use format;
  use http-common;
  use http-server;
  use locators,
    exclude: { <http-server> };  // badly named
  use streams;
  use threads;
end;


Module:   dylan-user
Synopsis: Koala example code
Author:   Carl Gay

define library koala-demo
  use common-dylan,
    import: { common-extensions };
  use dsp;
  use dylan;
  use http-common;
  use io,
    import: { format, streams };
  use koala;
  use system,
    import: { locators, threads };
end;


define module koala-demo
  use common-extensions,
    exclude: { format-to-string };
  use dsp;
  use dylan;
  use format;
  use http-common;
  use koala;
  use locators,
    exclude: { <http-server> };  // badly named
  use streams;
  use threads;
end;


Module: dylan-user
Copyright: See LICENSE in this distribution for details.


define library http-common-test-suite
  use common-dylan;
  use http-common;
  use io;
  use system;
  use testworks;
  export http-common-test-suite;
end;

define module http-common-test-suite
  use common-dylan;
  use http-common;
  use http-common-internals;
  use locators,
    import: { locator-name, <file-locator> };
  use standard-io,
    import: { *standard-output* };
  use streams,
    import: { force-output };
  use testworks;
  export http-common-test-suite;
end;


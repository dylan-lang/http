Module: dylan-user
Copyright: See LICENSE in this distribution for details.

define library http-client-test-suite
  use common-dylan;
  use collections,
    import: { table-extensions };
  use system;
  use http-client;
  use http-common;
  use testworks;
  use uri;
  use strings;
  use io, import: { format-out };

  export http-client-test-suite;
end library http-client-test-suite;

define module http-client-test-suite
  use common-dylan;
  use table-extensions;
  use date;
  use http-client;
  use http-client-internals;
  use http-common;
  use testworks;
  use uri;
  use strings;
  use format-out;

  export http-client-test-suite;
end module http-client-test-suite;

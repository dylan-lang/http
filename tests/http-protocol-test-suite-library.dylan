Module: dylan-user
Copyright: See LICENSE in this distribution for details.

define library http-protocol-test-suite
  use common-dylan;
  use system;
  use http-client;
  use http-common;
  use http-testing;
  use testworks;
  use uri;
  use strings;

  export http-protocol-test-suite;
end library http-protocol-test-suite;

define module http-protocol-test-suite
  use common-dylan;
  use date;
  use http-client;
  use http-common;
  use http-testing,
    import: { fmt };
  use testworks;
  use uri;
  use strings;

  export http-protocol-test-suite;
end module http-protocol-test-suite;

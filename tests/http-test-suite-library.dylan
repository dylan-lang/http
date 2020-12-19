Module: dylan-user
Copyright: See LICENSE in this distribution for details.

define library http-test-suite
  use http-client-test-suite;
  use http-common-test-suite;
  use http-protocol-test-suite;
  use http-server-test-suite;
  use testworks;

  export http-test-suite;
end library;

define module http-test-suite
  use http-client-test-suite;
  use http-common-test-suite;
  use http-protocol-test-suite;
  use http-server-test-suite;
  use testworks;
end module;

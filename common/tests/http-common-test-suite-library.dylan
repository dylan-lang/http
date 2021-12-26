Module: dylan-user
Copyright: See LICENSE in this distribution for details.


define library http-common-test-suite
  use common-dylan;
  use http-common;
  use network;
  use ssl-network;
  use testworks;
  use io;
  export http-common-test-suite;
end library;

define module http-common-test-suite
  use common-dylan;
  use http-common;
  use http-common-internals;
  use sockets,
    import: { start-sockets };
  use ssl-sockets;              // for side-effect
  use streams;
  use testworks;
  use format;
end module;


Module: dylan-user
Copyright: See LICENSE in this distribution for details.


define library http-common-test-suite
  use common-dylan;
  use http-common;
  use testworks;
  use io;
  export http-common-test-suite;
end;

define module http-common-test-suite
  use common-dylan;
  use http-common;
  use http-common-internals;
  use testworks;
  use format;
  export http-common-test-suite;
end;


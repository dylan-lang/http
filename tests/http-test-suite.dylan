Module: http-test-suite
Copyright: See LICENSE in this distribution for details.

define suite http-test-suite ()
  suite http-client-test-suite;
  suite http-common-test-suite;
  suite http-protocol-test-suite;
  suite http-server-test-suite;
end;

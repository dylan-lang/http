Module: http-client-test-suite
Synopsis: 
Author: Carl Gay
Copyright: See LICENSE in this distribution for details.

define suite http-client-test-suite ()
  suite request-test-suite;
end suite http-client-test-suite;

define suite request-test-suite ()
  test test-make;
  test test-convert-headers-method;
end suite request-test-suite;

define test test-make ()
  let request = make(<base-http-request>, url: "http://httpbin.org/");
  check-instance?("Parse the url", <uri>, request.request-url);

  let h = make(<string-table>);
  h["X-Test-Header"] := "test-value";
  request := make(<base-http-request>, headers: convert-headers(h));
  check-equal("Acts like a <message-headers-mixin>",
              get-header(request, "X-Test-Header"),
              "test-value");
end test test-make;

define test test-convert-headers-method ()
  let headers = convert-headers(#f);
  check-instance?("#f is an empty <header-table>", <header-table>, headers);

  headers := convert-headers(#(#("k1", "v1"), #("k2", "v2")));
  check-instance?("<header-table> from a <sequence>", <header-table>, headers);

  let h = make(<string-table>);
  h["k1"] := "v1";
  h["k2"] := "v2";
  headers := convert-headers(h);
  check-instance?("<header-table> from a <table>", <header-table>, headers);
end test test-convert-headers-method;

run-test-application(http-client-test-suite);

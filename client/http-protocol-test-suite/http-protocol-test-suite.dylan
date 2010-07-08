Module: http-protocol-test-suite
Synopsis: Test suite to validate conformance to HTTP 1.1 protocol spec (RFC 2616)
Author: Carl Gay

// This test suite is not in a usable state yet.

define suite http-protocol-test-suite ()
  suite method-test-suite;
  suite header-test-suite;
end suite http-protocol-test-suite;

define suite method-test-suite ()
  test test-get-method;
  test test-post-method;
  test test-head-method;
  test test-put-method;
  test test-delete-method;
  test test-trace-method;
  test test-connect-method;
end;

define test test-get-method ()
  check-equal("GET /hello yields \"hello\"",
              http-get(full-url("hello")),
              "hello");
end test test-get-method;

define test test-post-method ()
end test test-post-method;

define test test-head-method ()
end test test-head-method;

define test test-put-method ()
end test test-put-method;

define test test-delete-method ()
end test test-delete-method;

define test test-trace-method ()
end test test-trace-method;

define test test-connect-method ()
end test test-connect-method;



define suite header-test-suite ()
  test test-date-header-parsing;
end suite header-test-suite;

define test test-date-header-parsing ()
  // RFC 2616 - 3.3.1
  // HTTP/1.1 clients and servers that parse the date value MUST accept
  // all three formats (for compatibility with HTTP/1.0), though they MUST
  // only generate the RFC 1123 format for representing HTTP-date values
  // in header fields. See section 19.3 for further information.
  //    Sun, 06 Nov 1994 08:49:37 GMT  ; RFC 822, updated by RFC 1123
  //    Sunday, 06-Nov-94 08:49:37 GMT ; RFC 850, obsoleted by RFC 1036
  //    Sun Nov  6 08:49:37 1994       ; ANSI C's asctime() format
  let date = encode-date(1994, 11, 06, 08, 49, 37, time-zone-offset: 0);
  let test-dates = #(
    "Tue, 15 Nov 1994 12:45:26 GMT",  // rfc1123
    "Sun, 06 Nov 1994 08:49:37 GMT",  // rfc1123
    "Sunday, 06-Nov-94 08:49:37 GMT", // rfc850
    "Sun Nov  6 08:49:37 1994"        // ANSI C asctime (GMT)
    );
  for (test-date in test-dates)
    check-equal(format-to-string("Date %s parses correctly", test-date),
                date,
                parse-http-date(test-date, 0, test-date.size));
  end;
end test test-date-header-parsing;


//---------------------------------------------------------------------
// utilities

define variable *test-host* :: <string> = "localhost";

define variable *test-port* :: <integer> = 80;

define function full-url
    (url :: <string>) => (full-url :: <url>)
  parse-url(format-to-string("http://%s:%d%s", *test-host*, *test-port*, url))
end function full-url;


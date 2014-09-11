Module: http-protocol-test-suite
Synopsis: Test suite to validate conformance to HTTP 1.1 protocol spec (RFC 2616)
Author: Carl Gay
Copyright: See LICENSE in this distribution for details.

//---------------------------------------------------------------------
// utilities

// Predicate that returns #t if the response content contains str.
//
// This is done by checking if the content contains `"str":`, this mean that
// str is a key in the json returned by httpbin.
define method response-content-contains?
    (response :: <http-response>, str :: <string>) => (p :: <boolean>)
  find-substring(response.response-content, concatenate("\"", str, "\":")) ~= #f;
end method response-content-contains?;

define variable *test-host* :: <string> = "httpbin.org";
define variable *test-port* :: <integer> = 80;

define function full-url
    (#rest segments) => (full-url :: <url>)
  parse-url(fmt("http://%s:%d%s", *test-host*, *test-port*, join(segments, "/")));
end function full-url;



define test test-options-method ()
  let response = http-options(full-url("/"));
  assert-equal(200, response.response-code);
  assert-equal(#("GET", "HEAD", "OPTIONS"),
               sort(split(get-header(response, "Allow"), ", ")),
               "Allowed methods");
end test test-options-method;

define test test-get-method ()
  let response = http-get(full-url("/"));
  check-equal("200 OK", response.response-code, 200);

  let p = make(<string-table>, size: 2);
  p["key1"] := "value1";
  p["key2"] := "value2";
  response := http-get(full-url("/get"), parameters: p);
  check-equal("200 OK", response.response-code, 200);
  check-true("Send parameters", response-content-contains?(response, "key1"));

  let h = make(<string-table>);
  h["X-Test-Header"] := "test-value";
  response := http-get(full-url("/get"), headers: h);
  check-equal("200 OK", response.response-code, 200);
  check-true("Send headers", response-content-contains?(response, "X-Test-Header"));
end test test-get-method;

define test test-get-method-allow-redirect ()
  let response = http-get(full-url("/redirect", "1"));
  // By default follow redirects
  // NOTE: how many?
  check-equal("follow-redirects not specified", response.response-code, 200);

  response := http-get(full-url("/redirect", "1"), follow-redirects: #f);
  check-equal("follow-redirects: #f", response.response-code, 302);

  response := http-get(full-url("/redirect", "3"), follow-redirects: 3);
  check-equal("follow-redirects: 3", response.response-code, 200);
end test test-get-method-allow-redirect;

define test test-post-method ()
  let response = http-post(full-url("/post"), content: "{\"key1\": \"value1\"}");
  check-true("Send data as is", response-content-contains?(response, "key1"));

  let payload = make(<string-table>, size: 2);
  payload["key1"] := "value1";
  payload["key2"] := "value with space";
  response := http-post(full-url("/post"), content: payload);
  check-true("Send data as form-encoded (key)", response-content-contains?(response, "key1"));
  check-true("Send data as form-encoded (value)",
             find-substring(response.response-content,
                            concatenate("\"key2\":", " \"", payload["key2"], "\"")));
end test test-post-method;

define test test-head-method ()
  let response = http-head(full-url("/"));
  check-equal("200 OK", response.response-code, 200);
end test test-head-method;

define test test-put-method ()
  let payload = make(<string-table>, size: 2);
  payload["key1"] := "value1";
  payload["key2"] := "value with space";
  let response = http-put(full-url("/put"), content: payload);
  check-true("Send data as form-encoded (key)", response-content-contains?(response, "key1"));
  check-equal("200 OK", response.response-code, 200);
end test test-put-method;

define test test-delete-method ()
  let response = http-delete(full-url("/delete"));
  check-equal("200 OK", response.response-code, 200);
end test test-delete-method;

define test test-trace-method ()
  // Not implemented by httpbin
end test test-trace-method;

define test test-connect-method ()
  // Not implemented by httpbin
end test test-connect-method;

define suite method-test-suite ()
  test test-options-method;
  test test-get-method;
  test test-get-method-allow-redirect;
  test test-post-method;
  test test-head-method;
  test test-put-method;
  test test-delete-method;
  test test-trace-method;
  test test-connect-method;
end;


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
  let test-dates = #("Sun, 06 Nov 1994 08:49:37 GMT",  // rfc1123
                     "Sunday, 06-Nov-94 08:49:37 GMT", // rfc850
                     "Sun Nov  6 08:49:37 1994");      // ANSI C asctime (GMT)
  for (test-date in test-dates)
    check-equal(fmt("Parse %=", test-date),
                date,
                parse-http-date(test-date, 0, test-date.size));
  end;
end test test-date-header-parsing;

define suite header-test-suite ()
  test test-date-header-parsing;
end suite header-test-suite;


define test test-cookies ()
end test test-cookies;

define test test-cookies-on-301 ()
end test test-cookies-on-301;

define test test-cookies-on-redirect ()
  // This test requires a class to persist status between requests (session?)
end test test-cookies-on-redirect;

define suite cookies-test-suite ()
  test test-cookies;
  test test-cookies-on-301;
  test test-cookies-on-redirect;
end suite cookies-test-suite;


define suite http-protocol-test-suite ()
  suite method-test-suite;
  suite header-test-suite;
  suite cookies-test-suite;
end suite http-protocol-test-suite;

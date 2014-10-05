Module: http-server-test-suite
Synopsis: Tests for request.dylan

define test test-parse-request-line-values ()
  let items = list(
    // request method tests
    list("CONNECT url HTTP/1.1", $http-CONNECT-method, "url", "HTTP/1.1"),
    list("DELETE url HTTP/1.1",  $http-DELETE-method,  "url", "HTTP/1.1"),
    list("GET url HTTP/1.1",     $http-GET-method,     "url", "HTTP/1.1"),
    list("HEAD url HTTP/1.1",    $http-HEAD-method,    "url", "HTTP/1.1"),
    list("OPTIONS url HTTP/1.1", $http-OPTIONS-method, "url", "HTTP/1.1"),
    list("POST url HTTP/1.1",    $http-POST-method,    "url", "HTTP/1.1"),
    list("PUT url HTTP/1.1",     $http-PUT-method,     "url", "HTTP/1.1"),
    list("TRACE url HTTP/1.1",   $http-TRACE-method,   "url", "HTTP/1.1"),

    list("XXX url HTTP/1.1", <not-implemented-error>),
    list("get url HTTP/1.1", <not-implemented-error>), // method case sensitive

    // url tests
    list("GET http://foo bar HTTP/1.1",  // space in url
         type-union(<bad-request-error>, <moved-permanently-redirect>)),

    // http-version tests
    list("GET http://foo HTTP/1.1", $http-GET-method, "http://foo", "HTTP/1.1"),
    list("GET url HTTP/1.0", $http-GET-method, "url", "HTTP/1.0"),
    list("GET url HTTP/0.9", <http-version-not-supported-error>),
    list("GET url http/1.x", <bad-request-error>),
    list("GET url http/1.1", <bad-request-error>), // version is case sensitive

    // other tests
    list("GET  url HTTP/1.1", <bad-request-error>), // two spaces
    list("GET url  HTTP/1.1", <bad-request-error>), // two spaces
    list(" GET url HTTP/1.1", <bad-request-error>)  // initial space
    );
  for (item in items)
    let (request-line, want-method, want-url, want-version) = apply(values, item);
    if (instance?(want-method, <http-method>))
      let (got-method, got-url, got-version)
        = parse-request-line-values(request-line, request-line.size);
      assert-equal(want-method, got-method,
                   fmt("Request method match for request line %=", request-line));
      assert-equal(want-url, got-url,
                   fmt("URL match for request line %=", request-line));
      assert-equal(want-version, got-version,
                   fmt("HTTP version match for request line %=", request-line));
    else
      let error-class = want-method;
      assert-signals(error-class,
                     parse-request-line-values(request-line, request-line.size));

    end if;
  end for;
end test test-parse-request-line-values;

define suite request-test-suite ()
  test test-parse-request-line-values;
end;

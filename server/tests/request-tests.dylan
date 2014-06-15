Module: http-server-test-suite
Synopsis: Tests for request.dylan

define test test-parse-request-line-values ()
  let items = list(
    // request method tests
    list("CONNECT url HTTP/1.1", #"connect", "url", #"http/1.1"),
    list("DELETE url HTTP/1.1",  #"delete", "url", #"http/1.1"),
    list("GET url HTTP/1.1",     #"get", "url", #"http/1.1"),
    list("HEAD url HTTP/1.1",    #"head", "url", #"http/1.1"),
    list("OPTIONS url HTTP/1.1", #"options", "url", #"http/1.1"),
    list("POST url HTTP/1.1",    #"post", "url", #"http/1.1"),
    list("PUT url HTTP/1.1",     #"put", "url", #"http/1.1"),
    list("TRACE url HTTP/1.1",   #"trace", "url", #"http/1.1"),
                   
    list("XXX url HTTP/1.1", <not-implemented-error>),
    list("get url HTTP/1.1", <not-implemented-error>), // case sensitive

    // url tests
    list("GET http://foo bar HTTP/1.1",  // space in url
         type-union(<bad-request-error>, <moved-permanently-redirect>)),

    // http-version tests
    list("GET http://foo HTTP/1.1", #"get", "http://foo", #"http/1.1"),
    list("GET url HTTP/1.0", #"get", "url", #"http/1.0"),
    // not yet
    //list("GET url HTTP/0.9", <http-version-not-supported-error>),
    list("GET url http/1.x", <bad-request-error>),

    // other tests
    list("GET  url HTTP/1.1", <bad-request-error>), // two spaces
    list("GET url  HTTP/1.1", <bad-request-error>), // two spaces
    list(" GET url HTTP/1.1", <bad-request-error>)  // initial space
    );
  for (item in items)
    let (request-line, want-method, want-url, want-version) = apply(values, item);
    if (instance?(want-method, <type>))
      let error-class = want-method;
      assert-signals(error-class,
                     parse-request-line-values(request-line, request-line.size));
    else
      let (got-method, got-url, got-version)
        = parse-request-line-values(request-line, request-line.size);
      assert-equal(want-method, got-method,
                   fmt("Request method match for request line %=", request-line));
      assert-equal(want-url, got-url,
                   fmt("URL match for request line %=", request-line));
      assert-equal(want-version, got-version,
                   fmt("HTTP version match for request line %=", request-line));
    end if;
  end for;
end test test-parse-request-line-values;

define suite request-test-suite ()
  test test-parse-request-line-values;
end;

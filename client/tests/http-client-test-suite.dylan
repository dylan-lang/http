Module: http-client-test-suite
Author: Francesco Ceccon
Copyright: See LICENSE in this distribution for details.

define test test-convert-headers-method ()
  let headers = convert-headers(#f);
  check-instance?("#f is an empty <header-table>", <header-table>, headers);

  headers := convert-headers(#(#("k1", "v1"), #("k2", "v2")));
  check-instance?("<header-table> from a <sequence>", <header-table>, headers);

  let h = tabling(<string-table>, "k1" => "v1", "k2" => "v2");
  headers := convert-headers(h);
  check-instance?("<header-table> from a <table>", <header-table>, headers);
end test;


/*
tests to write:
* send chunks of size 1, chunk-size, chunk-size - 1, and chunk-size + 1
  and verify that the correct content is received.  need an echo server.
* chunked and non-chunked requests and responses
* verify that adding a method on stream-sequence-class has the intended
  effect.  (i.e., read-to-end gives me a <byte-string> not a <vector>)
* verify error semantics for requests/responses with incorrect size or
  bad chunk size.
*/

///////////////////////////
// Utilities and responders
///////////////////////////

define function register-test-resources
    (server :: <http-server>)
  add-resource(server, "/", make(<echo-resource>));
  add-resource(server, "/x", make(<x-resource>));
  add-resource(server, "/echo", make(<echo-resource>));
end;


/////////////////////////////
// Tests
/////////////////////////////


// Test GETs with responses of various sizes.  For http-server, the largest
// one causes a chunked response.
//
define test test-http-get-to-string ()
  with-http-server (server = make-server(/* debug: #t */))
    register-test-resources(server);
    for (n in list(0, 1, 2, 8192 /*, 100000 */))
      let response = http-get(make-x-url(n));
      check-equal(fmt("http-get-to-string %d bytes - verify response code", n),
                  200,
                  response.response-code);
      check-equal(fmt("http-get-to-string %d bytes - verify content", n),
                  make(<byte-string>, size: n, fill: 'x'),
                  response.response-content);
    end;
  end;
end test;

// Verify that getting a URL with no path component is the same
// as getting the same URL with / as the path.  That is, http://host
// is the same as http://host/.  This was bug 7462.
//
define test test-http-get-no-path ()
  with-http-server (server = make-server(/* debug: #t */))
    register-test-resources(server);
    let no-path-url = test-url("");
    check-no-condition("GET of a URL with no path gets no error",
                       http-get(no-path-url));
    check-equal("GET of a URL with no path same as /",
                response-content(http-get(root-url())),
                response-content(http-get(no-path-url)));
  end;
end test;

define test test-http-get-to-stream ()
  with-http-server (server = make-server(/* debug: #t */))
    register-test-resources(server);
    for (n-bytes in list(0, 1, 2, 8192 /*, 100000 */))
      let stream = make(<string-stream>, direction: #"output");
      let response = http-get(make-x-url(n-bytes), stream: stream);
      check-equal(fmt("http-get-to-stream %d bytes - verify response code", n-bytes),
                  200,
                  response.response-code);
      check-equal(fmt("http-get-to-stream %d bytes - verify content not read", n-bytes),
                  #f,
                  response.response-content);
      // log-debug($log, " test-http-get/read-content: read-to-end()");
      // read-to-end(response);  // cleanup
    end;
  end;
end test;

define test test-encode-form-data ()
  // NYI
end test;

define test test-http-connections ()
  // NYI
end test;

define test test-with-http-connection ()
  // NYI
end test;

define test test-reuse-http-connection ()
  with-http-server (server = make-server(/* debug: #t */))
    register-test-resources(server);
    // The explicit headers here should be temporary.  I want to make
    // with-http-connection and send-request coordinate better to do
    // the keep-alive.
    with-http-connection (conn = root-url())
      send-request(conn, "GET", make-x-url(2),
                   headers: #[#["Connection", "Keep-alive"]]);
      let response :: <http-response> = read-response(conn);
      check-equal("first response is xx", response.response-content, "xx");

      send-request(conn, "GET", make-x-url(5),
                   headers: #[#["Connection", "Keep-alive"]]);
      let response :: <http-response> = read-response(conn);
      check-equal("second response is xxxxx", response.response-content, "xxxxx");
    end;
      // TODO:
      // be sure to check what happens if we write more data to the request
      // stream than specified by Content-Length, and if the server sends
      // more data than specified by its Content-Length header.  i.e., do
      // we need to flush/discard the extra data to make the connection 
      // usable again...presumably.
  end;
end test;

define test test-streaming-request ()
  with-http-server (server = make-server(/* debug: #t */))
    register-test-resources(server);
    with-http-connection(conn = root-url())
      // This uses a content-length header because currently http-server doesn't
      // support requests with chunked encoding.
      start-request(conn, "POST", "/echo",
                    headers: #[#["Content-Length", "7"],
                               #["Content-Type", "text/plain"]]);
      write(conn, "abcdefg");
      finish-request(conn);
      check-equal("Streamed request data sent correctly",
                  "abcdefg",
                  response-content(read-response(conn)));
    end;
  end;
end test;

define test test-streaming-response ()
  with-http-server (server = make-server(/* debug: #t */))
    register-test-resources(server);
    with-http-connection(conn = root-url())
      let data = make(<byte-string>, size: 10000, fill: 'x');
      send-request(conn, "POST", "/echo", content: data);
      let response :: <http-response> = read-response(conn, read-content: #f);
      check-equal("streamed response data same as sent data",
                  read-to-end(response),
                  data);
    end;
  end;
end test;

define test test-write-chunked-request ()
  with-http-server (server = make-server(/* debug: #t */))
    register-test-resources(server);
    // Client requests are chunked if we don't add a Content-Length header.
    with-http-connection(conn = root-url(),
                         outgoing-chunk-size: 8)
      for (data-size in #(0, 1, 7, 8, 9, 200))
        let data = make(<byte-string>, size: data-size, fill: 'x');
        send-request(conn, "POST", "/echo",
                     content: data,
                     headers: #[#["Connection", "Keep-Alive"],
                                #["Transfer-Encoding", "chunked"]]);
        let response = read-response(conn);
        check-equal(format-to-string("chunked request of size %d received correctly",
                                     data-size),
                    data, response-content(response));
      end for;
    end;
  end;
end test;

define test test-read-chunked-response ()
  with-http-server (server = make-server(/* debug: #t */))
    register-test-resources(server);
    with-http-connection(conn = root-url())
      // currently no way to set response chunk size so make data bigger
      // than http-server's $chunk-size.  http-server adds Content-Length header if
      // entire response < $chunk-size.
      let data = make(<byte-string>, size: 100000, fill: 'x');
      send-request(conn, "POST", "/echo", content: data);
      let response :: <http-response> = read-response(conn);
      check-equal("response data same as sent data",
                  response-content(response),
                  data);
      check-false("ensure no Content-Length header",
                  get-header(response, "Content-Length"));
      check-true("ensure Transfer-Encoding: chunked header",
                 chunked-transfer-encoding?(response));
      // we don't currently have a way to verify that the response was
      // actually chunked.  
    end;
  end;
end test;

define test test-non-chunked-request ()
  // NYI
end test;

define test test-non-chunked-response ()
  // NYI
end test;

define test test-resource-not-found-error ()
  with-http-server (server = make-server(/* debug: #t */))
    check-condition("<resource-not-found-error> (404) signaled",
                    <resource-not-found-error>,
                    http-get(test-url("/no-such-url")));
  end;
end test;

define test test-invalid-response-chunk-sizes ()
  // NYI
end test;

define test test-invalid-response-content-lengths ()
  // NYI
end test;

define test test-invalid-request-content-lengths ()
  // NYI
end test;

define test test-read-from-response-after-done ()
  with-http-server (server = make-server(/* debug: #t */))
    register-test-resources(server);
    with-http-connection(conn = root-url())
      send-request(conn, "GET", make-x-url(3));
      let response = read-response(conn, read-content: #t);
      check-condition("Reading past end of response signals <end-of-stream-error>",
                      <end-of-stream-error>,
                      read-element(response));
    end;
  end;
end test;

define test test-follow-redirects ()
  // NYI
end test;

// Test redirect loop detection. See RFC 2616 section 10.3.
define test test-redirect-loop-detection ()
  with-http-server (server = make-server(/* debug: #t */))
    let url = test-url("/loop");
    add-resource(server, "/loop", function-resource(curry(redirect-to, url)));
    assert-signals(<redirect-loop-detected>,
                   http-get(url, follow-redirects: #t),
                   "Infinite redirect loop signals <redirect-loop-detected>");
  end;
end test;

define test test-https ()
  // This puts a dependency on github.com and on the network being up while
  // this test suite is run, but the test infrastructure to set up an https
  // server side doesn't yet exist. TODO...
  //
  // This is a convenient case where I happen to know it should return a 302
  // with a specific Location header.
  let res = http-get("https://github.com/dylan-lang/pacman-catalog/releases/latest",
                     follow-redirects: #f);
  assert-equal(302, res.response-code);
  assert-true(starts-with?(get-header(res, "Location"),
                           "https://github.com/dylan-lang/pacman-catalog/releases/tag/"));
end;

begin
  start-sockets();
  run-test-application()
end;

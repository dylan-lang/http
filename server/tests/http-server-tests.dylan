Module: http-server-test-suite
Copyright: See LICENSE in this distribution for details.


define test start-stop-basic-test ()
  let server = make-server();
  block ()
    check-equal("start-stop-basic-test check #1",
                start-server(server, background: #t, wait: #t),
                #t);
  cleanup
    stop-server(server);
  end;
end test;

// Make sure there are no timing problems related to threads and
// starting and stopping the server.
define test repeated-start-stop-test ()
  for (i from 1 to 5)
    let server = make-server();
    block ()
      check-equal(fmt("repeated-start-stop-test check #%d", i),
                  start-server(server, background: #t, wait: #t),
                  #t);
    cleanup
      stop-server(server);
    end;
  end;
end test;

// The same as repeated-start-stop-test, but make a connection to the
// listener each time the server is started.
define test test-repeated-start-stop-with-connection ()
  for (i from 1 to 5)
    let server = make-server(debug: #t);
    add-resource(server, "/", function-resource(method ()
                                                  output("hi there");
                                                end));
    block ()
      check-equal(fmt("repeated-start-stop-test check #%d", i),
                  start-server(server, background: #t, wait: #t),
                  #t);
      check-no-errors("connect", http-get(test-url("/")));
    cleanup
      stop-server(server);
    end;
  end;
end test;

// This is expected to fail on non-Windows platforms, which signal
// <unix-socket-error> for almost everything as of 2014.
define test conflicting-listener-ips-test ()
  let server = make-server(listeners: list($listener-127, $listener-127));
  block ()
    check-condition("start-server with conflicting listener-ips",
                    <address-in-use>,
                    start-server(server, background: #t, wait: #t));
  cleanup
    stop-server(server);
  end;
end test;

// Test that the server can handle the "Transfer-encoding: chunked" header
// by setting the outgoing-chunk-size of the client's connection.
//
define test chunked-request-test ()
  // Client requests are chunked if we don't add a Content-Length header.
  with-http-server (server = make-server())
    add-resource(server, "/echo", make(<echo-resource>));
    block ()
      with-http-connection(conn = test-url("/echo"),
                           outgoing-chunk-size: 8)
        for (data-size in #(0, 1, 7, 8, 9, 200))
          let data = make(<byte-string>, size: data-size, fill: 'x');
          send-request(conn, "POST", "/echo", content: data);
          let response = read-response(conn);
          check-equal(format-to-string("chunked request of size %d received correctly",
                                       data-size),
                      data, response-content(response));
        end for;
      end;
    exception (ex :: <http-error>)
      log-debug($log, "Error: %s", ex);
    end;
  end;
end test;

begin
  start-sockets();
  run-test-application();
end;

Module: http-server-test-suite
Copyright: See LICENSE in this distribution for details.


define function connect-and-close
    (addr, #key port = *test-port*)
  block ()
    with-http-connection(conn = addr, port: port)
      log-info($log, "Connected to %s:%s", addr, port);
      #t
    end;
  exception (ex :: <connection-failed>)
    #f
  end;
end function connect-and-close;


// Test creating <http-server>s with various settings.
//
/*
define test server-creation-test ()
  let server = make(<http-server>,
                    // how do i get the (or a) root directory
                    // in a platform independent way?
                    dsp-root: as(<directory-locator>, 
end test server-creation-test;
*/

define test start-stop-basic-test ()
  let server = make-server();
  block ()
    check-equal("start-stop-basic-test check #1",
                start-server(server, background: #t, wait: #t),
                #t);
  cleanup
    stop-server(server);
  end;
end test start-stop-basic-test;

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
end test repeated-start-stop-test;

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
end test test-repeated-start-stop-with-connection;

define test conflicting-listener-ips-test ()
  let server = make-server(listeners: list($listener-127, $listener-127));
  block ()
    check-condition("start-server with conflicting listener-ips",
                    <address-in-use>,
                    start-server(server, background: #t, wait: #t));
  cleanup
    stop-server(server);
  end;
end test conflicting-listener-ips-test;

// Make sure we can bind specific IP addresses.
define test bind-interface-test ()
  let host-addresses = map(host-address, all-addresses($local-host));
  for (addrs in list(#["127.0.0.1"],
                     concatenate(host-addresses, #["127.0.0.1"]),
                     #["0.0.0.0"]))

    log-info($log, "Starting server with addrs = %s", addrs);
    with-http-server(server = make-server(listeners: map(make-listener, addrs)))
      for (addr in concatenate(host-addresses, #("127.0.0.1")))
        if (member?(addr, addrs, test: \=) | addrs = #["0.0.0.0"])
          check-true(fmt("address %s is listening for bound = %s", addr, addrs),
                     connect-and-close(addr));
        else
          check-false(fmt("address %s is NOT listening for bound = %s", addr, addrs),
                      connect-and-close(addr));
        end;
      end for;
    end with-http-server;
  end for;
end test bind-interface-test;

define suite start-stop-test-suite ()
  test start-stop-basic-test;
  test repeated-start-stop-test;
  test test-repeated-start-stop-with-connection;
  test bind-interface-test;
  test conflicting-listener-ips-test;
end suite start-stop-test-suite;

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
end test chunked-request-test;

define suite chunking-test-suite ()
  test chunked-request-test;
end;

define suite http-server-test-suite ()
  suite start-stop-test-suite;
  suite chunking-test-suite;
  suite configuration-test-suite;
  suite multi-views-test-suite;
  suite resources-test-suite;
  suite rewrite-rules-test-suite;
  suite virtual-host-test-suite;
end;

Module: koala-test-suite
Synopsis: XML RPC testing

// Test that we can create a server and add a responder for it.
//
define test xml-rpc-registration-test ()
  with-http-server (http-server = make-server())
    let xml-rpc-server = make(<xml-rpc-server>);
    register-xml-rpc-method(xml-rpc-server, "foo", method () "bar" end);
    let url = test-url("/xml-rpc-registration-test");
    add-responder(http-server, url, xml-rpc-server);
    check-equal("Register and call a simple XML RPC method",
                xml-rpc-call(url, "foo"),
                "bar");
  end;
end test xml-rpc-registration-test;

define test xml-rpc-namespace-test ()
end test xml-rpc-namespace-test;

// Test sending all the defined XML RPC data types over the wire and back.
//
define test xml-rpc-data-types-test ()
  with-http-server (http-server = make-server())
    let xml-rpc-server = make(<xml-rpc-server>);
    register-xml-rpc-method(xml-rpc-server, "echo", method (arg) arg end);
    let url = test-url("/xml-rpc-data-types-test");
    add-responder(http-server, url, xml-rpc-server);
    for (val in vector(-1,
                       0,
                       1,
                       3.1415927d0,
                       "a <string>",
                       vector("one", 2),
                       begin
                         let t = make(<string-table>);
                         t["one"] := 1;
                         t["two"] := 2;
                         t
                       end))
      let result = xml-rpc-call(url, "echo", val);
      check-equal(fmt("Echo %s over XML RPC", val), val, result);
    end for;
  end with-http-server;
end test xml-rpc-data-types-test;

define xml-rpc-server $test-server-1 ()
    (error-fault-code: 123)
  "echo" => method (#rest args) args end;
  "ping" => method () "ack" end;
  "error" => error;
end;

define test xml-rpc-server-definer-test ()
  with-http-server (http-server = make-server())
    let url = test-url("/xml-rpc-server-definer-test");
    add-responder(http-server, url, $test-server-1);
    check-equal("xml-rpc-server-definer echo",
                xml-rpc-call(url, "echo", "foo"),
                #["foo"]);
    check-equal("xml-rpc-server-definer ping",
                xml-rpc-call(url, "ping"),
                "ack");
    check-equal("xml-rpc-server-definer error",
                block ()
                  xml-rpc-call(url, "error")
                exception (ex :: <xml-rpc-fault>)
                  fault-code(ex)
                end,
                123);
  end with-http-server;
end test xml-rpc-server-definer-test;

// Make sure fault codes other than the default get propagated correctly.
define test xml-rpc-fault-test ()
  with-http-server (http-server = make-server())
    let xml-rpc-server = make(<xml-rpc-server>);
    register-xml-rpc-method(xml-rpc-server, "error", xml-rpc-fault);
    let url = test-url("/xml-rpc-fault-test");
    add-responder(http-server, url, xml-rpc-server);
    for (code in #(-1, 0, 1, 123))
      let message = fmt("fault code %d", code);
      check-equal(message,
                  block ()
                    xml-rpc-call(url, "error", code, message)
                  exception (ex :: <xml-rpc-fault>)
                    fault-code(ex)
                  end,
                  code);
    end;
  end with-http-server;
end test xml-rpc-fault-test;


define suite xml-rpc-test-suite ()
  test xml-rpc-registration-test;
  test xml-rpc-namespace-test;
  test xml-rpc-data-types-test;
  test xml-rpc-server-definer-test;
  test xml-rpc-fault-test;
end;

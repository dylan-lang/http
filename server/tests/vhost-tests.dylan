Module: http-server-test-suite
Copyright: See LICENSE in this distribution for details.


define suite virtual-host-test-suite ()
    test test-vhost-add-resource;
    //test test-vhost-find-resource;
end;

define test test-vhost-add-resource ()
  let server = make-server(use-default-virtual-host?: #t);
  let root = make(<resource>);
  let vhost = make(<virtual-host>, router: root);

  add-virtual-host(server, "127.0.0.1", vhost);
  check-equal("a <virtual-host> was added for 127.0.0.1?",
              vhost,
              find-virtual-host(server, "127.0.0.1"));

  let abc-resource = make(<resource>);
  check-no-errors("add-resource(<http-server>, ...)",
                  add-resource(server, "/a/b/c", abc-resource));
  check-equal("resource added to default vhost?",
              abc-resource,
              find-resource(server.default-virtual-host, "/a/b/c"));

  check-condition("Verify resource NOT added to non-default vhost.",
                  <resource-not-found-error>,
                  find-resource(vhost, "/a/b/c"));

  // Make sure requests are routed to the correct virtual host.
  // Need to fire up a server for this test because it's very difficult
  // to make a <request> without creating clients, listeners, sockets, etc.
  let value = #f;
  let resource-1 = make(<function-resource>,
                        function: method () value := 1 end);
  let resource-2 = make(<function-resource>,
                        function: method () value := 2 end);
  with-http-server (server = make-server())
    let vhost = make(<virtual-host>);
    add-virtual-host(server, "localhost", vhost);
    add-resource(server, "/x", resource-1);  // adds to "127.0.0.1" vhost
    add-resource(vhost, "/x", resource-2);   // adds to "localhost" vhost
    http-get(test-url("/x", host: "127.0.0.1"));
    check-equal("find-resource(server, <request>) uses correct virtual host - #1",
                1, value);
    http-get(test-url("/x", host: "localhost"));
    check-equal("find-resource(router, <request>) uses correct virtual host - #2",
                2, value);
  end;
end test test-vhost-add-resource;

/*
// Verify that find-resource(vhost-router, request) finds the correct
// resource based on the Host: header of the request.
//
define test test-vhost-find-resource ()
  let router = make(<virtual-host-router>, fall-back-to-default?: #f);
  let vhost-1 = make(<virtual-host-resource>);
  let vhost-2 = make(<virtual-host-resource>);
  add-resource(router, "127.0.0.1", vhost-1);
  add-resource(router, "localhost", vhost-2);

  let resource-1 = make(<resource>);
  let resource-2 = make(<resource>);
  add-resource(vhost-1, "/one", resource-1);
  add-resource(vhost-1, "/two", resource-2);
  add-resource(vhost-2, "/one", resource-1);
  add-resource(vhost-2, "/two", resource-2);

  let data = #(#("http://127.0.0.1/one", resource-1),
               #("http://127.0.0.1/two", resource-2),
               #("http://localhost/one", resource-1),
               #("http://localhost/two", resource-2));

  for (item in data)
  check-equal("http://127.0.0.1/one finds resource-1?",
              resource-1,
              find-resource(router, build-request("127.0.0.1", "/one")));

  check-condition("http://127.0.0.1/two errs because fall-back disabled?",
                  
              find-resource(router, build-request("127.0.0.1", "/one")));

  check-equal("http://127.0.0.1/one finds resource-1?",
              resource-1,
              find-resource(router, build-request("127.0.0.1", "/one")));


note: verify that fall-back doesn't occur if the vhost IS found but the URL path ISN'T.
*/

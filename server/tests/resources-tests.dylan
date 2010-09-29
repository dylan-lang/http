Module: koala-test-suite

// Tests for <resource>s and URL routing.

define suite resources-test-suite ()
  suite add-resource-test-suite;
  suite path-variable-test-suite;
  test test-find-resource;
  test test-request-router;
end;


//// add-resource suite

define suite add-resource-test-suite ()
    test test-add-resource-basics;
    test test-add-resource-precedence;
    test test-add-resource-parent;
    test test-add-resource-path-variables;
end;

define test test-add-resource-basics ()
  local method add-and-find (to-add, to-find)
          let top = make(<resource>);
          let bot = make(<resource>);
          add-resource(top, to-add, bot);
          check-equal(format-to-string("and-and-find(%s, %s)", to-add, to-find),
                      bot,
                      find-resource(top, to-find));
          values(top, bot)
        end;
  // direct children
  add-and-find("", #(""));
  add-and-find("/", #(""));
  add-and-find("/foo", #("", "foo"));

  // more distant descendants
  add-and-find("foo/bar", #("foo", "bar"));
  add-and-find("/foo/bar/", #("", "foo", "bar", ""));
  add-and-find("foo/bar/baz/quux", #("foo", "bar", "baz", "quux"));

  // Path variables are correctly omitted from the path?
  add-and-find("/foo/{x}", #("", "foo"));
  add-and-find("/{x}", #(""));
  add-and-find("foo/{x}", #("foo"));

  check-condition("add-resource with empty (non-string) path errs?",
                  <koala-api-error>,
                  add-resource(make(<resource>), #(), make(<resource>)));

  // Finding by <uri> (always absolute)
  add-and-find("/foo", parse-uri("/foo"));
  add-and-find("/foo/bar/", parse-uri("/foo/bar/"));

  // Finding by string (a bit more fuzzy than by sequence)
  add-and-find("", "/");
  add-and-find("/", "/");
  add-and-find("/foo", "/foo");
  add-and-find("/foo/bar/", "/foo/bar/");

end test test-add-resource-basics;

// More specific descendant takes precedence?
define test test-add-resource-precedence ()
  let root = make(<resource>);
  let shallow = make(<resource>);
  let deep = make(<resource>);
  add-resource(root, "/foo", shallow);
  add-resource(root, "/foo/bar", deep);
  check-equal("Deeper resource takes precedence?",
              deep,
              find-resource(root, "/foo/bar"));
end test test-add-resource-precedence;

// add-resource sets parent to first child added?
// Also check that generated url path is correct, since it's related.
define test test-add-resource-parent ()
  let root = make(<resource>);
  let child = make(<resource>);
  add-resource(root, "foo", child);
  check-equal("parent is set when first child added?",
              root,
              child.resource-parent);
  check-equal("generated url path uses first child added?",
              "foo",
              child.resource-url-path);
  add-resource(root, "bar", child);
  check-equal("parent is unchanged when second child added?",
              root,
              child.resource-parent);
  check-equal("generated url path unchanged after second child added?",
              "foo",
              child.resource-url-path);
end test test-add-resource-parent;

// add-resource sets path variables correctly?
define test test-add-resource-path-variables ()
  let root = make(<resource>);
  let child = make(<resource>);
  add-resource(root, "/a/b/c/{x}/{y}/{z}", child);
  let found = find-resource(root, parse-url("/a/b/c"));
  check-equal("first path variable defines where url prefix ends?", child, found);
  check-equal("add-resource sets path variables correctly?",
              #(#"x", #"y", #"z"),
              child.resource-path-variables);

  let root = make(<resource>);
  let child = make(<resource>);
  check-condition("constant path elements after path variables signal error?",
                  <koala-api-error>,
                  add-resource(root, "a/{b}/c", child));
  check-condition("trailing slash after path variables signals error?",
                  <koala-api-error>,
                  add-resource(root, "b/{x}/{y}/", child));
end test test-add-resource-path-variables;



//// One-off tests, directly in add-resource-test-suite

define test test-find-resource ()
  local method find-and-verify
            (root, url-string, expected-resource, expected-pre-path, expected-post-path)
          let (rsrc :: <resource>, pre-path :: <list>, post-path :: <list>)
            = find-resource(root, parse-url(url-string));
          check-equal(format-to-string("find-resource(%=) returns expected resource",
                                       url-string),
                      expected-resource,
                      rsrc);
          check-equal(format-to-string("find-resource(%=) returns expected pre-path",
                                       url-string),
                      expected-pre-path,
                      pre-path);
          check-equal(format-to-string("find-resource(%=) returns expected post-path",
                                       url-string),
                      expected-post-path,
                      post-path);
        end;
  let root = make(<resource>);
  let aaa = make(<resource>);
  let bbb = make(<resource>);
  let ccc = make(<resource>);
  add-resource(root, "/aaa", aaa);
  add-resource(root, "/bbb", bbb);
  add-resource(root, "/bbb/ccc", ccc);
  find-and-verify(root, "http://host/aaa",     aaa, #("", "aaa"), #());
  find-and-verify(root, "http://host/aaa/xxx", aaa, #("", "aaa"), #("xxx"));
  find-and-verify(root, "http://host/bbb",     bbb, #("", "bbb"), #());
  find-and-verify(root, "http://host/bbb/ccc", ccc, #("", "bbb", "ccc"), #());
end test test-find-resource;

// Verify that resource operations on <http-server> delegate
// to the root resource.
//
define test test-request-router ()
  let resource-a = make(<resource>);
  let server = make(<http-server>, request-router: resource-a);
  check-equal("request-router: init-keyword for <http-server>",
              resource-a, server.request-router);

  let resource-c = make(<resource>);
  add-resource(server, "/foo", resource-c);
  check-equal("add-resource on <http-server>",
              resource-c,
              find-resource(server, parse-url("/foo")));
end test test-request-router;



//// Path variable suite

define suite path-variable-test-suite ()
  test test-path-variable-bindings-application;
  test test-parse-path-variable;
  test test-variable-arity-mapping
end;

define test test-parse-path-variable ()
  check-condition("no path variable", <koala-api-error>, parse-path-variable("x"));
  check-equal("basic path variable", #"x", parse-path-variable("{x}"));
  check-equal("rest path variable", #(#"rest", #"x"), parse-path-variable("{x...}"));
end;

// Verify that path variable bindings are passed to respond* methods correctly.
//
define test test-path-variable-bindings-application ()
  let result = unsupplied();
  local method responder(#rest args)
          result := copy-sequence(args);
        end;
  let resource = function-resource(responder);
  with-http-server (server = make-server())
    add-resource(server, "/{x}/{y}", resource);     // (1)
    add-resource(server, "/c/{x}/{y}", resource);    // (2)

    print-resources(server);

    http-get(test-url("/n"));     // should match pattern (1)
    check-equal("unsupplied path variables bind to #f?",
                #(#"x", "n", #"y", #f),
                result);

    http-get(test-url("/n/m"));     // should match pattern (1)
    check-equal("path variables at root",
                #(#"x", "n", #"y", "m"),
                result);

    http-get(test-url("/c/d/e"));     // should match pattern (2)
    check-equal("path variables at non root url",
                #(#"x", "d", #"y", "e"),
                result);
  end;
end test test-path-variable-bindings-application;

// Verify that a leaf mapping (one that doesn't expect any URL suffix) gives
// 404 error if suffix is non-empty.
//
define test test-variable-arity-mapping ()
  let bindings = #f;
  local method set-bindings (#rest args, #key)
          bindings := args;
        end;

  // some checks with strict routing enabled...
  with-http-server (server = make-server(use-strict-routing?: #t))
    add-resource(server, "/a/b", function-resource(set-bindings));
    check-equal("baseline: exact match",
                #[],
                begin
                  http-get(test-url("/a/b"));
                  bindings
                end);
    check-condition("extra URL path elements cause 404 with strict routing?",
                    <resource-not-found-error>,
                    http-get(test-url("/a/b/extra")));

    add-resource(server, "/x/y/{z...}", function-resource(set-bindings));
    check-equal("exact URL match gives #() in variable arity arg?",
                #[z:, #()],
                begin
                  http-get(test-url("/x/y"));
                  bindings
                end);
    check-equal("extra URL path elements stored in variable arity arg?",
                #[z:, #("extra")],
                begin
                  http-get(test-url("/x/y/extra"));
                  bindings
                end);
  end;

  // one check with non-strict routing
  with-http-server (server = make-server(use-strict-routing?: #f))
    add-resource(server, "/x/y", function-resource(set-bindings));
    check-equal("extra URL path elements ignored with non-strict routing?",
                #[],
                begin
                  http-get(test-url("/x/y/extra"));
                  bindings
                end);
  end;
end test test-variable-arity-mapping;



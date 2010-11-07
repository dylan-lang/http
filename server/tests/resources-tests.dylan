Module: koala-test-suite

// Tests for <resource>s and URL routing.

define suite resources-test-suite ()
  suite add-resource-test-suite;
  suite path-variable-test-suite;
  suite rewrite-rules-test-suite;
  test test-find-resource;
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
  let found = find-resource(root, "/a/b/c");
  check-equal("first path variable defines where url prefix ends?", child, found);
  check-equal("add-resource sets path variables correctly?",
              #(#"x", #"y", #"z"),
              map(path-variable-name, child.resource-path-variables));

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
            (root, url, expected-resource, expected-pre-path, expected-post-path)
          let (rsrc :: <resource>, pre-path :: <list>, post-path :: <list>)
            = find-resource(root, url);
          check-equal(format-to-string("find-resource(%=) returns expected resource", url),
                      expected-resource,
                      rsrc);
          check-equal(format-to-string("find-resource(%=) returns expected pre-path", url),
                      expected-pre-path,
                      pre-path);
          check-equal(format-to-string("find-resource(%=) returns expected post-path", url),
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
  find-and-verify(root, parse-url("http://host/aaa"),     aaa, #("", "aaa"), #());
  find-and-verify(root, parse-url("http://host/aaa/xxx"), aaa, #("", "aaa"), #("xxx"));
  find-and-verify(root, parse-url("http://host/bbb"),     bbb, #("", "bbb"), #());
  find-and-verify(root, parse-url("http://host/bbb/ccc"), ccc, #("", "bbb", "ccc"), #());
end test test-find-resource;



//// Path variable suite

define suite path-variable-test-suite ()
  test test-path-variable-binding;
  test test-parse-path-variable;
end;

define test test-parse-path-variable ()
  check-condition("no path variable",
                  <koala-api-error>,
                  parse-path-variable("x"));

  for (item in list(list("{x}", <path-variable>, #"x", #t),
                    list("{x?}", <path-variable>, #"x", #f),
                    list("{x*}", <star-path-variable>, #"x", #f),
                    list("{x+}", <plus-path-variable>, #"x", #t)))
    let (text, class, name, required?) = apply(values, item);
    let pvar = parse-path-variable(text);
    check-equal(fmt("%s class", text), class, pvar.object-class);
    check-equal(fmt("%s name", text), name, pvar.path-variable-name);
    check-equal(fmt("%s required?", text), required?, pvar.path-variable-required?);
  end;
end test test-parse-path-variable;


// Verify that a leaf mapping (one that doesn't expect any URL suffix) gives
// 404 error if suffix is non-empty.
//
define test test-path-variable-binding ()
  let bindings = #f;
  local method set-bindings (#rest args, #key)
          bindings := args;
        end;

  with-http-server (server = make-server())
    add-resource(server, "/a/b",      function-resource(set-bindings));
    add-resource(server, "/x/y/{z*}", function-resource(set-bindings));
    add-resource(server, "/m/n/{o+}", function-resource(set-bindings));
    add-resource(server, "/r/s/{t}/{u?}", function-resource(set-bindings));

    for (item in list(#("/a/b",     #[]),
                      #("/a/b/c",   404),

                      #("/x/y",     #[#"z", #()]),
                      #("/x/y/z",   #[#"z", #("z")]),
                      #("/x/y/z/q", #[#"z", #("z", "q")]),

                      #("/m/n",     404),
                      #("/m/n/o",   #[#"o", #("o")]),
                      #("/m/n/o/p", #[#"o", #("o", "p")]),

                      #("/r/s",       404),
                      #("/r/s/t",     #[#"t", "t", #"u", #f]),
                      #("/r/s/t/u",   #[#"t", "t", #"u", "u"]),
                      #("/r/s/t/u/v", 404)))
      let url = item[0];
      let expected = item[1];
      if (expected = 404)
        check-condition(fmt("%s yields 404?", url),
                        <resource-not-found-error>,
                        http-get(test-url(url)));
      else
        check-equal(fmt("%s yields %s?", url, expected),
                    expected,
                    begin
                      http-get(test-url(url));
                      bindings
                    end);
      end;
    end for;
  end with-http-server;

end test test-path-variable-binding;


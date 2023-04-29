Module: http-server-test-suite
Copyright: See LICENSE in this distribution for details.


//// Rewrite rules suite

// Test that replacement text for rewrite rules parse correctly.
//
define test test-parse-replacement ()
  for (item in list(#("/foo/$1", #["/foo/", #(1), ""]),
                    #("/$x/", #["/", #("x"), "/"]),
                    #("${name}/${2}", #["", #("name"), "/", #(2), ""])))
    let (text, parsed) = apply(values, item);
    check-equal(fmt("parse-replacement(%=)", text),
                parsed,
                parse-replacement(text));
  end;
end test;

// Verify that specific URLs are rewritten correctly.
//
define test test-rewrite-one-url ()
  for (item in #(#("foo", "bar", "foo", "bar")))
    let (pattern, replacement, input, output) = apply(values, item);
    let rewrite-rule = make(<rewrite-rule>,
                            regex: compile-regex(pattern),
                            replacement: replacement);
    check-equal(fmt("Rewrite: %=", item),
                output,
                rewrite-url(input, rewrite-rule));
  end;
end test;


// Verify that chaining rewrite rules works, and terminates correctly.
//
define test test-rewrite-rule-chaining ()
  let rules = list(make(<rewrite-rule>,
                        regex: compile-regex("^abc(.*)$"),
                        replacement: "xyz$1",
                        terminal?: #f),
                   make(<rewrite-rule>,
                        regex: compile-regex("this rule doesn't match"),
                        replacement: "not used",
                        terminal?: #f),
                   make(<rewrite-rule>,
                        regex: compile-regex("^xyz(.*)$"),
                        replacement: "aaa${1}bbb",
                        terminal?: #t),                 // should stop here
                   make(<rewrite-rule>,
                        regex: compile-regex(".*"),    // match anything that gets through
                        replacement: "FAIL"));
  check-equal("Rewrite rule chaining",
              "aaa123bbb",
              rewrite-url("abc123", rules));
end test;

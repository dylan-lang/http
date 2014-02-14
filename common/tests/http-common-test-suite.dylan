Module: http-common-test-suite
Copyright: See LICENSE in this distribution for details.


//// --- parsing test suite ---

define test test-quality-value ()
  for (pair in #[#["0.2", 0.2],
                 #["0.02", 0.02],
                 #["0.002", 0.002],
                 #["0.202", 0.202],
                 #["1.0", 1.0],
                 #["arf", #f]])
    let (string, expected) = apply(values, pair);
    check-equal(format-to-string("quality-value(%=) => %=", string, expected),
                expected,
                quality-value(string, 0, string.size));
  end;
end test test-quality-value;

define suite parsing-test-suite ()
  test test-quality-value;
end;


//// --- headers test suite ---

// See also: test-parse-media-type
define test test-accept-header ()
  let raw-header = "audio/*; q=0.5; r=\"2\", audio/mp3; q=1.0";
  check-equal(format-to-string("parse accept header %=", raw-header),
              list(make-media-type("audio", "*", #["q", 0.5], #["r", "2"]),
                   make-media-type("audio", "mp3", #["q", 1.0])),
              parse-header-value(#"accept", raw-header));
end test test-accept-header;

define suite headers-test-suite ()
  test test-accept-header;
end;


//// --- media-type test suite ---

define suite errors-test-suite ()
end;


//// --- media-type test suite ---

define function make-media-type
    (type :: <byte-string>, subtype :: <byte-string>, #rest attributes)
  let attrs = make(<string-table>);
  for (attr in attributes)
    attrs[first(attr)] := second(attr);
  end;
  make(<media-type>,
       type: type,
       subtype: subtype,
       attributes: attrs)
end;

define function parse-media-type-helper
    (media-type :: <string>)
 => (media-type :: <media-type>)
  parse-media-type(media-type, 0, media-type.size)
end;

define constant text/plain = make-media-type("text", "plain");

// Tests for parsing a single media type spec such as "text/html; q=0.3".
// Note that tests for parsing Accept* headers will cover the case where
// there are multiple media types in a comma-separated string.
//
define test test-parse-media-type ()
  check-condition("media type with no type signals error",
                  <http-parse-error>,
                  parse-media-type-helper("/*"));

  check-condition("media type with no slash or subtype signals error",
                  <http-parse-error>,
                  parse-media-type-helper("*"));

  check-condition("media type with no subtype signals error",
                  <http-parse-error>,
                  parse-media-type-helper("*/"));

  check-equal("parse-media-type */*",
              make-media-type("*", "*"),
              parse-media-type-helper("*/*"));

  // Media type with a single parameter
  check-equal("parse-media-type audio/*; q=0.2",
              make-media-type("audio", "*", #["q", "0.2"]),
              parse-media-type-helper("audio/*; q=0.2"));

  // Media type with more than one parameter
  check-equal("parse-media-type audio/*; q=0.2; x=y",
              make-media-type("audio", "*", #["q", "0.2"], #["x", "y"]),
              parse-media-type-helper("audio/*; q=0.2; x=y"));

  // Media type with a single parameter whose value is a quoted string.
  check-equal("parse-media-type audio/*; q=\"0.2\"",
              make-media-type("audio", "*", #["q", "0.2"]),
              parse-media-type-helper("audio/*; q=\"0.2\""));

  // Is the quality value converted to a float?
  check-equal("parse-media-type converts quality value to float?",
              0.3,
              media-type-quality(parse-media-type-helper("text/plain; q=0.3")));

  // Is the level value converted to an integer?
  check-equal("parse-media-type converts level to integer?",
              2,
              media-type-level(parse-media-type-helper("text/plain; q=0.3; level=2")));
end test test-parse-media-type;

define test test-match-media-types ()
  for (item in list(list("text", "plain"),
                    list("text", $mime-wild),
                    list($mime-wild, $mime-wild)))
    let (t, s) = apply(values, item);
    check-true(format-to-string("match-media-types(text/plain, %s/%s)", t, s),
               match-media-types(text/plain, make-media-type(t, s)));
  end;

  for (item in list(list("text", "html", 100),
                    list($mime-wild, "html", 1),
                    list($mime-wild, "plain", 101)))
    let (t, s, d) = apply(values, item);
    check-equal(format-to-string("media-types-match?(text/plain, %s/%s) has degree %s", t, s, d),
                match-media-types(text/plain, make-media-type(t, s)), d);
  end;

  for (item in list(list("image", "plain"),
                    list("image", "png"),
                    list("image", $mime-wild)))
    let (t, s) = apply(values, item);
    check-false(format-to-string("media-types-match?(text/plain, %s/%s) is false?", t, s),
                match-media-types(text/plain, make-media-type(t, s)));
  end;
end test test-match-media-types;

define test test-media-type-more-specific? ()
  let text/html-level-1 = make-media-type("text", "html", #["level", 1]);
  let text/html = make-media-type("text", "html");
  let text/* = make-media-type("text", $mime-wild);
  let wild/* = make-media-type($mime-wild, $mime-wild);
  check-equal("Precedence example in RFC 2616, 14.1 works?",
              list(text/html-level-1, text/html, text/*, wild/*), // expected
              sort(list(text/*, text/html, text/html-level-1, wild/*),
                   test: media-type-more-specific?));
end test test-media-type-more-specific?;

define test test-media-type-exact? ()
  check-true("media-type-exact?(text/plain)", media-type-exact?(text/plain));
  check-false("media-type-exact?(text/*) is false?",
              media-type-exact?(make-media-type("text", $mime-wild)));
  check-false("media-type-exact?(*/*)",
              media-type-exact?(make-media-type($mime-wild, $mime-wild)));
end test test-media-type-exact?;

define test test-media-type-quality ()
  check-equal("'q' attribute defines media type quality value?",
              0.4,
              make-media-type("a", "b", #["q", 0.4]).media-type-quality);
  check-equal("Default quality value is 1.0?",
              1.0,
              make-media-type("a", "b").media-type-quality);
end test test-media-type-quality;

define test test-media-type-level ()
  check-equal("'level' attribute defines media type level?",
              2,
              make-media-type("a", "b", #["level", 2]).media-type-level);
  check-false("Default level is #f?", make-media-type("a", "b").media-type-level);
end test test-media-type-level;

define suite media-type-test-suite ()
  test test-parse-media-type;
  test test-media-type-quality;
  test test-media-type-level;
  test test-media-type-exact?;
  test test-media-type-more-specific?;
  test test-match-media-types;
end suite media-type-test-suite;


//// --- top level suite ---

define suite http-common-test-suite ()
  suite parsing-test-suite;
  suite headers-test-suite;
  suite errors-test-suite;
  suite media-type-test-suite;
end;

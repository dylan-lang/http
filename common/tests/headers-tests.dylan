Module: http-common-test-suite

// Verify that the CRLF following the last header line is consumed, i.e., that
// epos includes it.
define test test-read-headers! ()
  let text = "Content-Disposition: form-data; name=\"main-code\"\r\n\r\ndef";
  let buffer = make-header-buffer();
  let headers = make(<header-table>);
  with-input-from-string (stream = text)
    let epos = read-headers!(stream, buffer, headers);
    test-output("up to 52: %=\n", copy-sequence(text, end: 52));
    assert-equal(52, epos);
    assert-equal("form-data; name=\"main-code\"",
                 headers["content-disposition"],
                 "content-disposition header correct?");
    assert-equal(1, headers.size);
    assert-equal("def", read-to-end(stream));
  end;
end test;

define test test-read-headers!-valid ()
  let items
    = list(list("x: y\r\n\r\n", #("x", "y")),
           list("x: y\r\nz: a\r\n\r\n", #("x", "y", "z", "a")),
           list("x:y\r\n\r\n", #("x", "y")),
           list("x:\r\n\r\n", #("x", "")),
           list("x: y\r\n z\r\n\r\n", #("x", "y z")),
           list("x: y\rz\r\n\r\n", #("x", "y\rz")),
           list("x: y\nz\r\n\r\n", #("x", "y\nz")),
           list("\r\nmessage body", #()),
           list("x: y: z\r\n\r\n", #("x", "y: z")));
  for (item in items)
    let (input, want) = apply(values, item);
    let buffer = make-header-buffer();
    let headers = make(<header-table>);
    with-input-from-string (stream = input)
      read-headers!(stream, buffer, headers);
    end;
    let description = format-to-string("input: %=", input);
    assert-equal(floor/(want.size, 2), headers.size, description);
    for (i from 0 below want.size by 2)
      let name = want[i];
      let value = want[i + 1];
      assert-equal(value, headers[name], description);
    end;
  end for;
end test;

define test test-read-headers!-invalid ()
  let error-cases = list("x:y\r\n",   // no LWS
                         "x: y",      // no CRLF
                         "x y\r\n");  // no colon
  for (message in error-cases)
    let buffer = make-header-buffer();
    let headers = make(<header-table>);
    assert-signals(<http-error>,
                   with-input-from-string (stream = message)
                     read-headers!(stream, buffer, headers);
                   end,
                   format-to-string("message: %=", message));
  end;
end test;

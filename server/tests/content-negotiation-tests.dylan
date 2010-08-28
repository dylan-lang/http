Module: koala-test-suite
Author: Carl Gay
Synopsis: Tests for the content negotiation code

define suite multi-views-test-suite ()
  test test-media-type-from-header;
  test test-locators-matching;
  test test-<document-variant>;
  test test-find-multi-view-file;
end;

define test test-media-type-from-header ()
  let raw-header = ("text/*;q=0.3, text/html;q=0.7, text/html;level=1,"
                      "text/html;level=2;q=0.4, */*;q=0.5");
  let header = parse-header-value(#"accept", raw-header);
  for (item in list(list("text/html;level=1", 1.0),
                    list("text/html",         0.7),
                    list("text/plain",        0.3),
                    list("image/jpeg",        0.5),
                    list("text/html;level=2", 0.4),
                    list("text/html;level=3", 0.7)))
    let (text, expected-quality) = apply(values, item);
    let mt1 = parse-media-type(text, 0, text.size);
    check-equal(format-to-string("test-media-type-from-header(%=)", text),
                expected-quality,
                media-type-from-header(header, mt1).media-type-quality);
  end;
end test test-media-type-from-header;

define test test-locators-matching ()
end;

define test test-<document-variant> ()
end;

define test test-find-multi-view-file ()
  // We need a better temp directory/file generator library.
  // Also, it would be nice if testworks had a standard way of creating directories
  // for a given test so that an entire test run has temp data stored in a standard
  // location for logs etc.
  let test-directory = subdirectory-locator(as(<directory-locator>, temp-directory()),
                                            "multi-view-test");
  local method write-file (locator, content)
          with-open-file(stream = locator, direction: output:)
            write(stream, content);
          end
        end,
        method make-directory-resource(#rest args)
          apply(make, <directory-resource>,
                directory: test-directory,
                allow-multi-views?: #t,
                args)
        end;
  local method multi-view (basename, accept-header)
          dynamic-bind (*server* = make-server())
            find-multi-view-file(
              make-directory-resource(),
              merge-locators(as(<file-locator>, basename), test-directory),
              mime-type-map: $default-mime-type-map,
              accept-header: parse-header-value(#"accept", accept-header))
          end;
        end;
  block ()
    if (~file-exists?(test-directory))
      // create-directory has a weird signature!
      create-directory(locator-directory(test-directory), locator-name(test-directory));
    end;
    for (extension in list("html", "txt", "jpg", "gif"))
      let file = as(<file-locator>, concatenate("foo.", extension));
      write-file(merge-locators(file, test-directory),
                 extension);
    end;

    //let raw-header = "audio/*; q=0.5; r=\"2\", audio/mp3; q=1.0";
    let header = parse-header-value(#"accept", "text/html");
    check-false("multi-view returns #f when no match?",
                multi-view("xxx", "*/*"));

    // Here we just make sure any old foo.* file is returned.  Because this
    // test has many foo.* files it covers most of the cases in
    // find-multi-view-file, since there are multiple variants at each step.
    //
    // TODO: There should be some built-in default quality values to make
    //       the return value deterministic...
    check-true("multi-view foo */* ~= #f?",
               multi-view("foo", "*/*"));

    let accept-header = "text/html; q=0.9, */*; q=0.8";
    check-equal(fmt("multi-view foo %= => foo.html?", accept-header),
                "foo.html",
                locator-name(multi-view("foo", "text/html; q=0.9, */*; q=0.8")));

    let accept-header = "image/*; q=0.5, image/gif; q=0.6, */*; q=0.0";
    check-equal(fmt("multi-view foo %= => foo.gif?", accept-header),
                "foo.gif",
                locator-name(multi-view("foo", accept-header)));

    // This test is intended to result in two variants that are the same
    // all the way through find-multi-view-file so that all the code is
    // excercised at least once.  (It would probably be better to choose
    // two much more obscure mime types than image/gif and image/jpg.)
    let accept-header = "image/*; q=0.9";
    check-equal(fmt("multi-view foo %= => foo.jpg?", accept-header),
                "foo.jpg",
                locator-name(multi-view("foo", accept-header)));

  cleanup
    if (file-exists?(test-directory))
      // TODO: file-system doesn't have this yet
      //remove-directory(test-directory);
    end;
  end block;
end test test-find-multi-view-file;


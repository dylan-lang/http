Module: koala-test-suite

define constant $xml-header :: <string>
  = "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>\n";

// Make an XML document string that contains the given string.
define function koala-document
    (content :: <string>) => (doc :: <string>)
  concatenate($xml-header, "<koala>\n", content, "\n</koala>\n")
end;

// Try to configure a server with the given document (a string containing
// a Koala XML configuration description).  
define function configure
    (configuration :: <string>)
 => (server :: <http-server>)
  let server = make(<http-server>);
  configure-from-string(server, configuration);
  server
end function configure;
  
define test basic-config-test ()
  let texts = #("",
                "<barbaloot>",
                "<koala>gubbish</koala>",
                "&!*#)!^%");
  for (text in texts)
    check-condition(fmt("Invalid config (%=) causes <configuration-error>", text),
                    <configuration-error>,
                    configure(text));
  end for;
  check-no-errors("Empty <koala> element",
                  configure(koala-document("")));
  check-no-errors("Unknown element ignored",
                  configure(koala-document("<unknown></unknown>")));
end test basic-config-test;

define test listener-config-test ()
  let texts = #(// valid
                "<listener address=\"123.45.67.89\" port=\"2222\" />",
                "<listener address=\"123.45.67.89\" />",
                "<listener port=\"2222\" />",
                // invalid
                // ideally i'd like these to signal a specific error.
                "<listener address=\"123.45.67.89\" port=\"xxx\" />",
                "<listener />",
                "<listener address=\"xxx\" port=\"2222\" />");
  for (text in texts)
    check-no-errors(text, configure(koala-document(text)));
  end;
end test listener-config-test;

define test alias-config-test ()
  let server = make-server();
  add-resource(server, "/abc", make(<echo-resource>));
  let text = "<koala><alias url=\"/def\" target=\"/abc\"/></koala>";
  configure-from-string(server, text);
  with-http-server (server = server)
    with-http-connection(conn = test-url("/"))
      send-request(conn, "GET", "/def");
      let response = read-response(conn, follow-redirects: #f);
      check-equal("/def returned response code 301?",
                  301, response.response-code);
      check-equal("/def was redirected to /abc?",
                  "/abc", get-header(response, "Location"));
    end;
  end;
end test alias-config-test;



define suite directory-resource-test-suite ()
  test test-directory-resource;
  test test-directory-resource-default-documents;
end;

// Verify that the <document-root> setting is respected, by setting it
// to the directory containing application-filename() and then requesting
// the executable file.
define test test-directory-resource ()
  let app = as(<file-locator>, application-filename());
  let dir = as(<string>, locator-directory(app));
  let text = fmt("<directory url=\"/\" location=\"%s\"/>\n", dir);
  let server = make-server();  // includes default listener
  configure-from-string(server, koala-document(text));
  with-http-server (server = server)
    let app-url = test-url(concatenate("/", locator-name(app)));
    with-http-connection (conn = app-url)
      send-request(conn, "GET", app-url);
      check-no-errors("<directory> resource config", read-response(conn));
    end;
  end;
end test test-directory-resource;

define test test-directory-resource-default-documents ()
  let server = make-server();
  let resource = make(<directory-resource>, directory: temp-directory());
  check-equal("Default default documents are index.html and index.htm",
              list(as(<file-locator>, "index.html"),
                   as(<file-locator>, "index.htm")),
              resource.default-documents);

  local method configure (default-docs :: <string>)
          let str = fmt("<directory url=\"/\" default-documents = \"%s\" />",
                        default-docs);
          configure-from-string(server, koala-document(str));
        end;

  configure("one");
  let resource = find-resource(server, parse-url("/"));
  check-equal("A single default document parses correctly",
              list(as(<file-locator>, "one")),
              resource.default-documents);

  configure("one,two");
  let resource = find-resource(server, parse-url("/"));
  check-equal("Multiple default documents parse correctly",
              list(as(<file-locator>, "one"),
                   as(<file-locator>, "two")),
              resource.default-documents);
end test test-directory-resource-default-documents;



define suite configuration-test-suite ()
  test basic-config-test;
  test listener-config-test;
  test alias-config-test;
  suite directory-resource-test-suite;
end suite configuration-test-suite;



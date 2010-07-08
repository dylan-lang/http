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
  add-responder(server, "/abc", echo-responder);
  let text = "<koala><alias url=\"/def\" target=\"/abc\"/></koala>";
  configure-from-string(server, text);
  with-http-server (server = server)
    with-http-connection(conn = test-url("/"))
      send-request(conn, "GET", "/def");
      let response = read-response(conn, follow-redirects: #f);
      check-equal("/def returned response code 301?",
                  response.response-code, 301);
      check-equal("/def was redirected to /abc?",
                  get-header(response, "Location"), "/abc");
    end;
  end;
end test alias-config-test;

// Verify that the <document-root> setting is respected, by setting it
// to the directory containing application-filename() and then requesting
// the executable file.
define test test-document-root ()
  let app = as(<file-locator>, application-filename());
  let dir = as(<string>, locator-directory(app));
  let text = fmt("<directory url=\"/\" location=\"%s\" allow-static=\"yes\"/>\n", dir);
  let server = make-server();  // includes default listener
  configure-from-string(server, koala-document(text));
  with-http-server (server = server)
    let app-url = test-url(concatenate("/", locator-name(app)));
    with-http-connection (conn = app-url)
      send-request(conn, "GET", app-url);
      check-no-errors("<document-root> is respected?", read-response(conn));
    end;
  end;
end test test-document-root;

define suite directory-policy-test-suite ()
  test test-directory-policy-default-documents;
end;

define test test-directory-policy-default-documents ()
  let server = make-server();
  check-equal("Default default documents are index.html and index.htm",
              list(as(<file-locator>, "index.html"),
                   as(<file-locator>, "index.htm")),
              server.default-virtual-host.root-directory-policy.policy-default-documents);

  local method configure (default-docs :: <string>)
          let str = fmt("<directory url=\"/\" default-documents = \"%s\" />", default-docs);
          configure-from-string(server, koala-document(str));
        end;

  configure("one");
  let policy = server.default-virtual-host.directory-policies[0];
  check-equal("A single default document parses correctly",
              list(as(<file-locator>, "one")),
              policy.policy-default-documents);
              
  configure("one,two");
  let policy = server.default-virtual-host.directory-policies[0];
  check-equal("Multiple default documents parse correctly",
              list(as(<file-locator>, "one"),
                   as(<file-locator>, "two")),
              policy.policy-default-documents);
end test test-directory-policy-default-documents;

define suite configuration-test-suite ()
  test basic-config-test;
  test listener-config-test;
  test alias-config-test;
  test test-document-root;
  suite directory-policy-test-suite;
end suite configuration-test-suite;



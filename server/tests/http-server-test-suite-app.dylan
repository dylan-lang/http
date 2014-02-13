Module: http-server-test-suite-app


define function main () => ()
  let query = environment-variable("QUERY_STRING");
  if (query)
    // We're being invoked as a CGI script.
    cgi-test-main(query);
  else
    // Run the test suite.
    // Show all request/response headers and message content.
    *http-common-log*.log-level := $trace-level;
    *http-client-log*.log-level := $trace-level;
    *log-content?* := #f;  // http-server variable, not yet configurable.
    run-test-application(http-server-test-suite);
  end;
end function main;

begin
  main()
end;

Module: http-server-test-suite-app


define function main () => ()
  // Run the test suite.
  // Show all request/response headers and message content.
  *http-common-log*.log-level := $trace-level;
  *http-client-log*.log-level := $trace-level;
  *log-content?* := #f;  // http-server variable, not yet configurable.
  run-test-application(http-server-test-suite);
end function main;

begin
  main()
end;

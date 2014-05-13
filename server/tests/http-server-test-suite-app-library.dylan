Module: dylan-user

define library http-server-test-suite-app
  use common-dylan;
  use http-client;
  use http-common;
  use http-server;
  use http-server-test-suite;
  use logging;
  use system,
    import: { operating-system };
  use testworks;
end library http-server-test-suite-app;

define module http-server-test-suite-app
  use common-dylan;
  use http-client,
    import: { *http-client-log* };
  use http-common,
    import: { *http-common-log* };
  use http-server,
    import: { *log-content?* };
  use http-server-test-suite,
    import: { http-server-test-suite };
  use logging,
    import: { log-level-setter,
              $trace-level };
  use operating-system,
    import: { environment-variable };
  use testworks,
    import: { run-test-application };
end module http-server-test-suite-app;

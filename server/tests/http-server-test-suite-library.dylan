Module:   dylan-user
Author:   Carl Gay
Copyright: See LICENSE in this distribution for details.
Synopsis: HTTP server test suite


define library http-server-test-suite
  use collection-extensions,
    import: { collection-utilities };
  use common-dylan,
    import: { common-dylan, threads };
  use http-client;
  use http-common;
  use http-testing;
  use io,
    import: { format, streams };
  use http-server,
    import: { http-server, http-server-unit };
  use logging;
  use mime;
  use network,
    import: { sockets };
  use regular-expressions;
  use strings;
  use system,
    import: {
      date,
      file-system,
      locators,
      operating-system
    };
  use testworks;
  use uri;

  export
    http-server-test-suite;
end library http-server-test-suite;

define module http-server-test-suite
  use collection-utilities,
    import: { key-exists? };
  use common-dylan;
  use date;
  use file-system;
  use format;
  use http-client;
  use http-common;
  use http-common-internals;
  use http-testing;
  use http-server,
    exclude: { log-trace, log-debug, log-info, log-warning, log-error };
  use http-server-unit;
  use locators,
    exclude: { <http-server>, <url> };
  use logging;
  use mime,
    import: { $default-mime-type-map };
  use operating-system,
    import: { environment-variable };
  use regular-expressions;
  use sockets,
    import: {
      <connection-failed>,
      <address-in-use>,
      start-sockets
    };
  use streams;
  use strings;
  use testworks;
  use threads;
  use uri;

  export http-server-test-suite;
end module http-server-test-suite;

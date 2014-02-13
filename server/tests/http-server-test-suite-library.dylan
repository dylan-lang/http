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
  use http-common-test-suite;
  use io,
    import: { format-out, standard-io, streams };
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
  use uncommon-dylan;
  use uri;

  export
    http-server-test-suite,
    http-test-utils;
end library http-server-test-suite;

define module http-test-utils
  use common-dylan;
  use http-common;
  use logging,
    import: { <logger> };
  use http-server,
    exclude: { log-trace, log-debug, log-info, log-warning, log-error };
  use uri,
    import: { parse-url, <url> };

  export
    <echo-resource>,
    fmt,  // should rename to sformat or something
    $listener-127,
    $listener-any,
    $log,
    *test-host*,
    *test-port*,
    test-url,
    root-url,
    make-listener,
    make-server,
    <x-resource>, make-x-url,
    with-http-server;
end module http-test-utils;

define module http-server-test-suite
  use collection-utilities,
    import: { key-exists? };
  use common-dylan;
  use date;
  use file-system;
  use format-out;
  use http-client;
  use http-common;
  use http-common-internals;
  use http-common-test-suite;
  use http-test-utils;
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
      all-addresses,
      host-address,
      start-sockets,
      $local-host
    };
  use standard-io;
  use streams;
  use strings;
  use testworks;
  use threads;
  use uncommon-dylan;
  use uri;

  export cgi-test-main, http-server-test-suite;
end module http-server-test-suite;

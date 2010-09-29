Module:   dylan-user
Synopsis: Koala test suite
Author:   Carl Gay

define library koala-test-suite
  use collection-extensions,
    import: { collection-utilities };
  use common-dylan,
    import: { common-dylan, threads };
  use http-client;
  use http-common;
  use http-common-test-suite;
  use io,
    import: { format-out, standard-io, streams };
  use koala,
    import: { koala, koala-unit };
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
  use xml-rpc-client;
  use xml-rpc-server;

  export koala-test-suite;
end library koala-test-suite;

define module koala-test-suite
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
  use koala,
    exclude: { log-trace, log-debug, log-info, log-warning, log-error };
  use koala-unit;
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
  use xml-rpc-client;
  use xml-rpc-server;

  export koala-test-suite;
end module koala-test-suite;


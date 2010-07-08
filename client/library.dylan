Module: dylan-user

define library http-client
  use common-dylan;
  use http-common;
  use io,
    import: { format,
              standard-io,
              streams };
  use logging;
  use network,
    import: { sockets };
  use strings;
  use system,
    import: { threads };
  use uncommon-dylan;
  use uri;

  export http-client;
  export http-client-internals;
end library http-client;

// See also the exports from http-common
//
define module http-client
  // Connections
  create
    <http-connection>,
    with-http-connection,
    make-http-connection,
    connection-host,
    connection-port,
    outgoing-chunk-size,
    outgoing-chunk-size-setter;

  // Progress protocol
  create
      note-bytes-sent;

  // Request/response
  create
    send-request,
    start-request,
    finish-request,
    read-response,
    <http-response>,
    response-content,
    http-get,
    <maximum-redirects-exceeded>;

  // Utilities
  create
    *http-client-log*,
    encode-form-data;

end module http-client;

define module http-client-internals
  use common-dylan,
    exclude: { format-to-string };
  use format;
  use http-client, export: all;
  use http-common;
  use logging;
  use sockets,
    exclude: { start-server };
  use standard-io;
  use streams;
  use strings;
  use threads;
  use uncommon-dylan;
  use uri;

  // Internals
  export
    connection-socket;

end module http-client-internals;


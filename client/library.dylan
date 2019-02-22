Module: dylan-user
Copyright: See LICENSE in this distribution for details.

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
  use uncommon-dylan,
    import: { uncommon-utils };
  use uri;

  export
    http-client,
    http-client-internals;
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
    http-request,
    http-get,
    http-post,
    http-put,
    http-options,
    http-head,
    http-delete,
    <maximum-redirects-exceeded>,
    <redirect-loop-detected>;

  // Utilities
  create
    *http-client-log*;

end module http-client;

define module http-client-internals
  use common-dylan,
    exclude: { format-to-string };
  use format;
  use http-client, export: all;
  use http-common;
  use %http-common-byte-string;
  use logging;
  use sockets,
    exclude: { start-server };
  use standard-io;
  use streams;
  use strings;
  use threads;
  use uncommon-utils,
    import: { iff, inc!, <int*> };
  use uri;

  // Internals
  export
    convert-headers,
    connection-socket,
    convert-content;

end module http-client-internals;

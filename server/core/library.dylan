Module:    dylan-user
Author:    Gail Zacharias, Carl Gay
Copyright: See LICENSE in this distribution for details.


define library http-server
  use base64;
  use collections,
    import: { table-extensions };
  use command-line-parser;
  use common-dylan,
    import: { dylan, common-extensions, threads, simple-random };
  use concurrency;
  use http-common;
  use io,
    import: { format, format-out, standard-io, streams, streams-internals };
  use logging;
  use memory-manager;
  use mime;
  use network,
    import: { sockets };
  use regular-expressions;
  //use ssl-network;         // adds sideways methods to network lib
  use strings;
  use system,
    import: { date, file-system, locators, operating-system };
  use uncommon-dylan;
  use uri;
  use xml-parser;

  export http-server-unit;
  export http-server;
end library http-server;


define module http-server
  // Server startup/shutdown
  create
    <http-server>,
    configure-server,
    start-server,
    stop-server,
    http-server-main,
    *command-line-parser*;

  // Servers
  create
    current-server,
    debugging-enabled?,
    debugging-enabled?-setter;

  // Requests
  create
    // See also: the methods for requests in http-common
    <request>,
    current-request,             // Returns the active request of the thread.
    request-content-type,
    request-host,
    request-url-path-prefix,
    request-url-path-suffix,
    request-absolute-url,
    request-query-values,        // get the keys/vals from the current GET or POST request
      get-query-value,           // Get a query value that was passed in a URL or a form
      do-query-values,           // Call f(key, val) for each query in the URL or form
      count-query-values,
      with-query-values,
    process-request-content,
    <page-context>,
    page-context;                // Returns a <page-context> if a page is being processed.
                                 //   i.e., essentially within the dynamic scope of
                                 //   respond-to-get/post/etc

  // Resource protocol
  create
    <abstract-resource>,
      default-content-type,
      respond,
      respond-to-get,
      respond-to-head,
      respond-to-post,
      respond-to-options,
      respond-to-put,
      respond-to-delete,
      respond-to-trace,
      respond-to-connect,
      unmatched-url-suffix;

  // Resource implementations
  create
    <resource>,
      <directory-resource>,
        default-documents,
      <cgi-script-resource>,
      <cgi-directory-resource>,
      <function-resource>,
      <redirecting-resource>,
      <sse-resource>,
          sse-queue, sse-queue-lock,
      add-resource-name,
      do-resources,
      function-resource;

  // Virtual hosts
  create
    <virtual-host>,
    add-virtual-host,
    default-virtual-host,
    default-virtual-host-setter,
    find-virtual-host,
    use-default-virtual-host?;

  // Request routing
  create
    <abstract-router>,
    route-request,
    add-resource,
    find-resource,
    generate-url;

  // Responses
  create
    <response>,
    // See also: methods on <base-http-response> in common-dylan.
    current-response,            // Returns the active response of the thread.
    output,
    add-cookie;

  // Sessions
  create
    <session>,
    get-session,
    ensure-session,
    clear-session;

  // Redirect
  create
    redirect-to,
    redirect-temporarily-to;

  // Logging
  create
    log-content,
    *log-content?*,
    // These are wrappers for the defs by the same name in the logging library.
    log-trace,
    log-debug,
    log-info,
    log-warning,
    log-error;

  // Configuration
  create
    process-config-element,
    server-root,
    get-attr;

  // Documents
  create
    serve-static-file,
    serve-cgi-script,
    file-contents;

  // Errors
  create
    <http-server-api-error>,
    <configuration-error>;

  // Rewrite rules
  create
    <abstract-rewrite-rule>,
    <rewrite-rule>,
    rewrite-url;

end module http-server;

// Additional interface for unit tests.
define module http-server-unit
  create
    *server*,
    configure-from-string,
    find-multi-view-file,
    media-type-from-header,
    parse-path-variable,
    resource-parent,
    resource-path-variables,
    resource-url-path,

    rewrite-rule-regex,
    rewrite-rule-redirect-code,
    rewrite-rule-replacement,
    rewrite-rule-terminal?,
    parse-replacement,

    <path-variable>,
      path-variable-name,
      path-variable-required?,
    <star-path-variable>,
    <plus-path-variable>;
end module http-server-unit;

define module httpi                             // http internals
  use base64;
  use command-line-parser;
  use common-extensions,
    exclude: { format-to-string };
  use concurrency;
  use date;                    // from system lib
  use dylan;
  use file-system;             // from system lib
  use format;
  use format-out;
  use http-common;
  use %http-common-byte-string;
  use http-server;
  use http-server-unit;
  use locators,
    rename: { <http-server> => <http-server-url>,
              <ftp-server> => <ftp-server-url>,
              <file-server> => <file-server-url>
            },
    exclude: { <url> };  // this comes from the uri library now.
  use logging,
    rename: { log-trace => %log-trace,
              log-debug => %log-debug,
              log-info => %log-info,
              log-warning => %log-warning,
              log-error => %log-error };
  use memory-manager;
  use mime;
  use operating-system;        // from system lib
  use regular-expressions;
  use simple-random;
  use sockets,
    rename: { start-server => start-socket-server };
  use standard-io;
  use streams;
  use streams-internals;
  use strings;
  use threads;               // from dylan lib
  use uncommon-dylan;
  use uri;
  use xml-parser,
    prefix: "xml$";
end module httpi;


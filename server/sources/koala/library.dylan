Module:    dylan-user
Author:    Gail Zacharias, Carl Gay
Copyright: Copyright (c) 2001-2004 Carl L. Gay.  All rights reserved.
           Original Code is Copyright (c) 2001 Functional Objects, Inc.  All rights reserved.
License:   Functional Objects Library Public License Version 1.0
Warranty:  Distributed WITHOUT WARRANTY OF ANY KIND

define library koala
  use base64;
  use collections,
    import: { table-extensions };
  use command-line-parser;
  use common-dylan,
    import: { dylan, common-extensions, threads, simple-random };
  use functional-dylan,
    import: { dylan-extensions };
  use http-common;
  use io,
    import: { format, standard-io, streams, streams-internals };
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
  use xml-rpc-common;

  export koala-unit;
  export koala;
end library koala;


define module koala
  // Server startup/shutdown
  create
    <http-server>,
    configure-server,
    start-server,
    stop-server,
    koala-main,
    *argument-list-parser*;

  // Servers
  create
    default-virtual-host,
    current-server,
    development-mode?;

  // Requests
  create
    // See also: the methods for requests in http-common
    <request>,
    current-request,             // Returns the active request of the thread.
    request-content-type,
    request-host,
    request-path-prefix,
    request-path-tail,
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

  // Responder mechanism
  create
    <responder>,
      request-method-map,
    <tail-responder>,
      tail-responder-regex,
      tail-responder-action,
    make-responder,
    add-responder,       // call this
    %add-responder,      // extend this
    add-tail-responder,
    remove-responder,
    find-responder,
    invoke-responder,
    <skip-remaining-responders>,
    url-map-definer,
    add-urls;

  // Responder utilities
  create
    cgi-directory-responder,
    cgi-script-responder,
    alias-responder,
    add-cgi-directory-responder,
    add-cgi-script-responder,
    add-alias-responder;

  // Virtual hosts
  create
    <virtual-host>,
    virtual-host,                // Return virtual host of current request.
    document-root,
    dsp-root,
    vhost-name,
    locator-below-document-root?,
    locator-below-dsp-root?,
    locator-below-root?;

  // Responses
  create
    <response>,
    // See also: methods on <base-http-response> in common-dylan.
    current-response,            // Returns the active response of the thread.
    output,
    output-stream,
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

  // XML RPC
  create
    xml-rpc-server-definer,
    <xml-rpc-server>,
    error-fault-code,
    error-fault-code-setter,
    debugging-enabled?,
    debugging-enabled?-setter,
    register-xml-rpc-method,
    respond-to-xml-rpc-request,
    $default-xml-rpc-url;

  // Documents
  create
    serve-static-file-or-cgi-script,
    serve-static-file,
    serve-cgi-script,
    locator-from-url,
    document-root,
    file-contents;

  // Errors
  create
    <koala-api-error>,
    <configuration-error>;

  create
    <http-file>,
    http-file-filename,
    http-file-content,
    http-file-mime-type;

end module koala;

// Additional interface for unit tests.
define module koala-unit
  // directory policies
  create
    <directory-policy>,
    policy-default-documents;

  // vhost
  create
    directory-policies,
    root-directory-policy;

  // other
  create
    *server*,
    configure-from-string,
    media-type-from-header,
    find-multi-view-file;
end module koala-unit;

define module httpi                             // http internals
  use base64;
  use command-line-parser;
  use common-extensions,
    exclude: { format-to-string };
  use date;                    // from system lib
  use dylan;
  use dylan-extensions,
    import: { element-no-bounds-check,
              element-no-bounds-check-setter,
              element-range-check,
              element-range-error,
              // make-symbol,
              // case-insensitive-equal,
              // case-insensitive-string-hash
              };
  use file-system;             // from system lib
  use format;
  use http-common;
  use koala;
  use koala-unit;
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
  use xml-rpc-common;
end module httpi;


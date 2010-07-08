Module:    httpi
Synopsis:  Core HTTP server code
Author:    Gail Zacharias, Carl Gay
Copyright: Copyright (c) 2001-2004 Carl L. Gay.  All rights reserved.
           Original Code is Copyright (c) 2001 Functional Objects, Inc.  All rights reserved.
License:   Functional Objects Library Public License Version 1.0
Warranty:  Distributed WITHOUT WARRANTY OF ANY KIND

define constant $server-name = "Koala";

define constant $server-version = "0.9";

define constant $server-header-value = concatenate($server-name, "/", $server-version);

define constant $allowed-request-methods :: <list>
  = #(#"get", #"head", #"options", #"post");

define constant $allowed-request-methods-string :: <byte-string>
    = join($allowed-request-methods, ", ",
           key: method (x) as-uppercase(as(<byte-string>, x)) end);

// This is needed to handle sockets shutdown.
define variable *exiting-application* = #f;

begin
  register-application-exit-function(method ()
                                       *exiting-application* := #t
                                     end);
end;

// The user instantiates this class directly, passing configuration options
// as init args.
//
define open class <http-server> (<object>)
  // Whether the server should run in debug mode or not.  If this is true then
  // errors encountered while servicing HTTP requests will not be handled by the
  // server itself.  Normally the server will handle them and return an "internal
  // server error" response.  A good way to debug Dylan Server Pages.  Can be
  // enabled via the --debug command-line option.
  slot debugging-enabled? :: <boolean> = #f,
    init-keyword: debug:;

  // Value to send as 'Server' header.
  slot server-header :: <byte-string>,
    init-value: $server-header-value;

  constant slot server-lock :: <simple-lock>,
    required-init-keyword: lock:;


  //// Next 6 slots are to support clean server shutdown.

  constant slot server-listeners :: <stretchy-vector>,
    required-init-keyword: listeners:;

  constant slot server-clients :: <stretchy-vector>,
    init-function: curry(make, <stretchy-vector>);

  constant slot listeners-shutdown-notification :: <notification>,
    required-init-keyword: listeners-shutdown-notification:;

  constant slot clients-shutdown-notification :: <notification>,
    required-init-keyword: clients-shutdown-notification:;

  constant slot listener-shutdown-timeout :: <real> = 5;
  constant slot client-shutdown-timeout :: <real> = 5;

  constant slot request-class :: subclass(<basic-request>) = <request>,
    init-keyword: request-class:;

  //---TODO: response for unsupported-request-method-error MUST include
  // Allow: field...  Need an API for making sure that happens.
  // RFC 2616, 5.1.1

  // In the url-map trie, each URL path leads to a <responder> object.
  // The <responder> has a request-method-map that maps request methods
  // (currently symbols like #"get") to a set of <tail-responder>s each
  // of which has a regular expression and an object that supports the
  // invoke-responder method.  (Weeee!)  The leading slash is removed
  // from URLs because it's easier to use merge-locators that way.
  // TODO: this should be per vhost
  constant slot url-map :: <string-trie> = make(<string-trie>, object: #f),
    init-keyword: url-map:;

  //// Statistics
  // TODO: move these elsewhere

  slot connections-accepted :: <integer> = 0;
  constant slot user-agent-stats :: <string-table>,
    init-function: curry(make, <string-table>);

  // Maps host names to virtual hosts.
  constant slot virtual-hosts :: <string-table>,
    init-function: curry(make, <string-table>);

  // The vhost used if the request host doesn't match any other virtual host.
  // Note that the document root may be changed when the config file is
  // processed, so don't use it except during request processing.
  //
  slot default-virtual-host :: <virtual-host>,
    init-keyword: default-virtual-host:;

  // If this is true, then requests directed at hosts that don't match any
  // explicitly named virtual host (i.e., something created with <virtual-host>
  // in the config file) will use the default vhost.  If this is #f when such a
  // request is received, a Bad Request (400) response will be returned.
  //
  slot fall-back-to-default-virtual-host? :: <boolean> = #t;

  // The top of the directory tree under which the server's configuration, error,
  // and log files are kept.  Other pathnames are merged against this one, so if
  // they're relative they will be relative to this.  The server-root pathname is
  // relative to the koala executable, unless changed in the config file.
  slot server-root :: <directory-locator>
    = parent-directory(locator-directory(as(<file-locator>, application-filename()))),
    init-keyword: server-root:;

  // This holds a <mime-type-map>, but in fact all the values are <media-type>s.
  slot server-media-type-map :: <mime-type-map>,
    init-keyword: media-type-map:;


  //// Next 3 slots are for sessions

  // Maps session-id to session object.
  constant slot server-sessions :: <table>,
    init-function: curry(make, <table>);

  // The number of seconds this cookie should be stored in the user agent, in seconds.
  // #f means no max-age is transmitted, which means "until the user agent exits".
  constant slot session-max-age :: false-or(<integer>),
    init-value: #f,
    init-keyword: session-max-age:;

  constant slot server-session-id :: <byte-string>,
    init-value: "koala_session_id",
    init-keyword: session-id:;

  // Should be #f in a production setting.  So far only controls whether
  // to check DSP template modification dates and reparse if needed.
  slot development-mode? :: <boolean>,
    init-value: #f,
    init-keyword: development-mode:;

  //// Logging

  slot request-logger :: <logger>,
    init-value: *request-logger*,
    init-keyword: request-logger:;

  slot error-logger :: <logger>,
    init-value: *error-logger*,
    init-keyword: error-logger:;

  slot debug-logger :: <logger>,
    init-value: *debug-logger*,
    init-keyword: debug-logger:;

end class <http-server>;

// get rid of this eventually.  <http-server> is the new name.
define constant <server> = <http-server>;

define sealed method make
    (class == <server>, #rest keys, #key listeners)
 => (server :: <server>)
  // listeners, if specified, is a sequence of <listener>s, or strings in
  // the form "addr:port".
  let listeners = map-as(<stretchy-vector>, make-listener, listeners | #[]);
  let lock = make(<simple-lock>);
  let listeners-notification = make(<notification>, lock: lock);
  let clients-notification = make(<notification>, lock: lock);
  apply(next-method, class,
        lock: lock,
        listeners: listeners,
        listeners-shutdown-notification: listeners-notification,
        clients-shutdown-notification: clients-notification,
        keys)
end method make;

define sealed domain make (subclass(<http-server>));

// API (in the sense that its args are passed directly by the user)
define method initialize
    (server :: <http-server>,
     #rest keys,
     #key document-root, dsp-root,
          request-logger: req-log, debug-logger: dbg-log, error-logger: err-log)
  apply(next-method,
        server,
        remove-keys(keys, #"document-root", #"dsp-root"));
  if (instance?(document-root, <string>))
    document-root := as(<directory-locator>, document-root);
  end;
  if (instance?(dsp-root, <string>))
    dsp-root := as(<directory-locator>, dsp-root);
  end;
  let doc-root = document-root | subdirectory-locator(server.server-root, "static");
  let dsp-root = dsp-root | subdirectory-locator(server.server-root, "dsp");
  let vhost-name = "default";
  let vhost = make(<virtual-host>,
                   name: vhost-name,
                   document-root: doc-root,
                   dsp-root: dsp-root,
                   request-logger: req-log | server.request-logger,
                   debug-logger: dbg-log | server.debug-logger,
                   error-logger: err-log | server.error-logger);
  default-virtual-host(server) := vhost;
  add-virtual-host(server, vhost, vhost-name);
  // Add a spec that matches all urls.
  add-directory-policy(vhost, root-directory-policy(vhost));

  // Copy mime type map in, since it may be modified when config loaded.
  if (~slot-initialized?(server, server-media-type-map))
    let tmap :: <mime-type-map> = make(<mime-type-map>);
    for (media-type keyed-by extension in $default-media-type-map)
      tmap[extension] := media-type;
    end;
    server.server-media-type-map := tmap;
  end;
end method initialize;

define sealed domain initialize (<http-server>);

// Keep some stats on user-agents
define method note-user-agent
    (server :: <server>, user-agent :: <string>)
  with-lock (server.server-lock)
    let agents = user-agent-stats(server);
    agents[user-agent] := element(agents, user-agent, default: 0) + 1;
  end;
end;

define function release-client (client :: <client>)
  let server = client.client-server;
  with-lock (server.server-lock)
    remove!(server.server-clients, client);
    when (empty?(server.server-clients))
      release-all(server.clients-shutdown-notification);
    end;
  end;
end release-client;

define class <listener> (<object>)
  constant slot listener-port :: <integer>,
    required-init-keyword: port:;

  constant slot listener-host :: false-or(<string>),
    required-init-keyword: host:;

  slot listener-socket :: false-or(<server-socket>),
    init-value: #f,
    init-keyword: socket:;

  // Maybe should hold some mark of who requested it..
  slot listener-exit-requested? :: <boolean> = #f;

  // The time when server entered 'accept', so we can
  // abort it if it's hung...
  // This gets set but is otherwise unused so far.
  slot listener-listen-start :: false-or(<date>) = #f;

  // Statistics
  slot connections-accepted :: <integer> = 0;
  slot total-restarts :: <integer> = 0;             // Listener restarts

end class <listener>;

define method make-listener
    (listener :: <listener>) => (listener :: <listener>)
  listener
end;

// #(host, port)
 define method make-listener
    (host-and-port :: <sequence>) => (listener :: <listener>)
  if (host-and-port.size = 2)
    let (host, port) = apply(values, host-and-port);
    if (instance?(port, <string>))
      port := string-to-integer(port);
    end;
    make(<listener>, host: host, port: port)
  else
    error(make(<koala-api-error>,
               format-string: "Invalid listener spec: %s",
               format-arguments: list(host-and-port)));
  end
 end method make-listener;

// "host:port"
define method make-listener
    (listener :: <string>) => (listener :: <listener>)
  make-listener(split(listener, ':'));
end method make-listener;

define method listener-name
    (listener :: <listener>) => (name :: <string>)
  format-to-string("HTTP Listener for %s:%d",
                   listener.listener-host, listener.listener-port)
end;

define method make-socket
    (listener :: <listener>) => (socket :: <tcp-server-socket>)
  listener.listener-socket := make(<tcp-server-socket>,
                                   host: listener.listener-host,
                                   port: listener.listener-port);
end;


define class <ssl-listener> (<listener>)
  constant slot certificate-filename :: <pathname>,
    required-init-keyword: certificate-filename:;
  constant slot key-filename :: <pathname>,
    required-init-keyword: key-filename:;
end;

define method listener-name
    (listener :: <ssl-listener>) => (name :: <string>)
  format-to-string("HTTPS Listener for %s:%d",  // just adds 'S'
                   listener.listener-host, listener.listener-port)
end;

define method make-socket
    (listener :: <ssl-listener>) => (socket :: <tcp-server-socket>)
  listener.listener-socket := make(<tcp-server-socket>,
                                   host: listener.listener-host,
                                   port: listener.listener-port,
                                   ssl?: #t,
                                   certificate: listener.certificate-filename,
                                   key: listener.key-filename)
end;


define class <client> (<object>)
  constant slot client-server :: <server>,
    required-init-keyword: server:;

  constant slot client-listener :: <listener>,
    required-init-keyword: listener:;

  constant slot client-socket :: <tcp-socket>,
    required-init-keyword: socket:;

  constant slot client-thread :: <thread>,
    required-init-keyword: thread:;

  slot client-request :: <basic-request>;
end;

define class <basic-request> (<object>)
  constant slot request-client :: <client>,
    required-init-keyword: client:;
end;

define method initialize (request :: <basic-request>, #key, #all-keys)
  next-method();
  request.request-client.client-request := request;
end;

define inline function request-socket
    (request :: <basic-request>)
 => (socket :: <tcp-socket>)
  request.request-client.client-socket
end;

define inline function request-server
    (request :: <basic-request>)
 => (server :: <server>)
  request.request-client.client-server
end;

/*
define inline function request-thread (request :: <basic-request>)
    => (server :: <thread>)
  request.request-client.client-thread
end;

define inline function request-port (request :: <basic-request>)
    => (port :: <integer>)
  request.request-client.client-listener.listener-port;
end;
*/

//// <page-context>

// Gives the user a place to store values that will have a lifetime
// equal to the duration of the handling of the request.  The name is
// stolen from JSP's PageContext class, but it's not intended to serve the
// same purpose.  Use set-attribute(page-context, key, val) to store attributes
// for the page and get-attribute(page-context, key) to retrieve them.

define class <page-context> (<attributes-mixin>)
end;

define thread variable *page-context* :: false-or(<page-context>) = #f;

define method page-context
    () => (context :: false-or(<page-context>))
  if (*request*)
    *page-context* | (*page-context* := make(<page-context>))
  else
    application-error(message: "There is no active HTTP request.")
  end;
end;



// TODO: make thread safe
define variable *sockets-started?* :: <boolean> = #f;

define function ensure-sockets-started ()
  unless (*sockets-started?*)
    start-sockets();
    //start-ssl-sockets();
    *sockets-started?* := #t;
  end;
end;

define thread variable *server* :: false-or(<http-server>) = #f;

define inline function current-server
    () => (server :: <http-server>)
  *server*
end function current-server;

// This is what client libraries call to start the server, which is
// assumed to have been already configured via configure-server.
// (Client applications might want to call koala-main instead.)
// Returns #f if there is an error during startup; otherwise #t.
// If background is #t then run the server in a thread and return
// immediately.  Otherwise wait until all listeners have shut down.
// If wait is #t then don't return until all listeners are ready.
// 
define open generic start-server
    (server :: <http-server>,
     #key background :: <boolean>,
          wait :: <boolean>)
 => (started? :: <boolean>);

define method start-server
    (server :: <http-server>,
     #key background :: <boolean> = #f,
          wait :: <boolean> = #t)
 => (started? :: <boolean>)
  // Binding these to the default vhost loggers here isn't quite right.
  // It means that log messages that don't pertain to a specific vhost
  // go in the default vhost logs.  Maybe have a separate log for the
  // server proper...
  dynamic-bind (*debug-logger* = server.default-virtual-host.debug-logger,
                *error-logger* = server.default-virtual-host.error-logger,
                *request-logger* = server.default-virtual-host.request-logger,
                *http-common-log* = *debug-logger*)
    log-info("Starting %s HTTP Server", $server-name);
    ensure-sockets-started();
    log-info("Server root directory is %s", server-root(server));
    for (listener in server.server-listeners)
      start-http-listener(server, listener)
    end;
    if (wait)
      // Connect to each listener or signal error.
      wait-for-listeners-to-start(server.server-listeners);
      log-info("%s %s ready for service", $server-name, $server-version);
    end;
    if (~background)
      // Apparently when the main thread dies in an Open Dylan application
      // the application exits without waiting for spawned threads to die,
      // so join-listeners keeps the main thread alive until all listeners die.
      join-listeners(server);
    end;
  end dynamic-bind;
  #t
end method start-server;

define function wait-for-listeners-to-start
    (listeners :: <sequence>)
  // Either make a connection to each listener or signal an error.
  for (listener in listeners)
    let start :: <date> = current-date();
    let max-wait = make(<duration>, days: 0, hours: 0, minutes: 0, seconds: 1,
                        microseconds: 0);
    iterate loop (iteration = 1)
      let socket = #f;
      block ()
        let host = listener.listener-host;
        let conn-host = iff(host = "0.0.0.0", $local-host, host);
        log-debug("Attempting connection to %s via %s",
                  listener.listener-name, conn-host);
        socket := make(<tcp-socket>,
                       // hack hack
                       host: conn-host,
                       port: listener.listener-port);
        log-debug("Connection to %s successful", listener.listener-name);
      cleanup
        socket & close(socket);
      exception (ex :: <connection-failed>)
        log-debug("Connection attempt #%d to %s failed: %s",
                  iteration, listener.listener-name, ex);
        if (current-date() - start > max-wait)
          signal(ex)
        end;
        sleep(0.1);
        loop(iteration + 1);
      exception (ex :: <error>)
        log-error("Error while waiting for listener %s to start: %s",
                  listener.listener-name, ex);
      end block;
    end;
  end for;
end function wait-for-listeners-to-start;

define function join-listeners
    (server :: <server>)
  // Don't use join-thread, because no timeouts, so could hang.
  // eh?
  block (return)
    while (#t)
      sleep(1);
      with-lock (server.server-lock)
        if (empty?(server.server-listeners))
          return();
        end;
      end;
    end;
  end;
end;

define open generic stop-server
    (server :: <http-server>, #key abort);

define method stop-server
    (server :: <http-server>, #key abort)
  abort-listeners(server);
  when (~abort)
    join-clients(server, timeout: server.client-shutdown-timeout);
  end;
  abort-clients(server);
  log-info("%s HTTP server stopped", $server-name);
end method stop-server;

define function abort-listeners (server :: <server>)
  iterate next ()
    let listener = with-lock (server.server-lock)
                     any?(method (listener :: <listener>)
                            ~listener.listener-exit-requested? & listener
                          end,
                          server.server-listeners);
                   end;
    when (listener)
      listener.listener-exit-requested? := #t; // don't restart
      synchronize-side-effects();
      if (listener.listener-socket)
        close(listener.listener-socket, abort?: #t);
      end;
      next();
    end;
  end iterate;
  // Don't use join-thread, because no timeouts, so could hang.
  let n = with-lock (server.server-lock)
            if (~empty?(server.server-listeners))
              if (~wait-for(server.listeners-shutdown-notification,
                            timeout: server.listener-shutdown-timeout))
                log-info("Timed out waiting for listeners to shut down.");
              end;
            end;
            let n = server.server-listeners.size;
            server.server-listeners.size := 0;
            n
          end;
  when (n > 0)
    log-warning("Listeners shutdown timed out, %d left", n);
  end;
end abort-listeners;

// At this point all listeners have been shut down, so shouldn't
// be spawning any more clients.
define function abort-clients (server :: <server>, #key abort)
  with-lock (server.server-lock)
    for (client in server.server-clients)
      close(client.client-socket, abort: abort);
    end;
  end;
  let n = join-clients(server, timeout: server.client-shutdown-timeout);
  when (n > 0)
    log-warning("Clients shutdown timed out, %d left", n);
  end;
end abort-clients;

define function join-clients
    (server :: <server>, #key timeout)
 => (clients-left :: <integer>)
  with-lock (server.server-lock)
    if (~empty?(server.server-clients))
      if (~wait-for(server.clients-shutdown-notification,
                    timeout: timeout))
        log-info("Timed out waiting for clients to shut down.");
      end;
    end;
    let n = server.server-clients.size;
    server.server-clients.size := 0;
    n
  end;
end join-clients;

define function start-http-listener
    (server :: <server>, listener :: <listener>)
  let server-lock = server.server-lock;
  local method release-listener ()
          remove!(server.server-listeners, listener);
          when (empty?(server.server-listeners))
            release-all(server.listeners-shutdown-notification);
          end;
        end;
  local method run-listener-top-level ()
          dynamic-bind (*debug-logger* = server.default-virtual-host.debug-logger,
                        *error-logger* = server.default-virtual-host.error-logger,
                        *request-logger* = server.default-virtual-host.request-logger,
                        *http-common-log* = *debug-logger*)
            with-lock (server-lock) end; // Wait for setup to finish.
            block ()
              listener-top-level(server, listener);
            cleanup
              close(listener.listener-socket, abort?: #t);
              with-lock (server-lock)
                release-listener();
              end;
            end;
          end dynamic-bind;
        end method;
  with-lock (server-lock)
    block ()
      make-socket(listener);
      make(<thread>,
           name: listener.listener-name,
           function: run-listener-top-level);
    exception (ex :: <socket-condition>)
      log-error("Error creating socket for %s: %s", listener.listener-name, ex);
      release-listener();
    end block;
  end;
end start-http-listener;

define function listener-top-level
    (server :: <server>, listener :: <listener>)
  with-socket-thread (server?: #t)
    // loop spawning clients until listener socket gets broken.
    do-http-listen(server, listener);
  end;
  let restart? = with-lock (server.server-lock)
                   when (~*exiting-application* &
                         ~listener.listener-exit-requested?)
                     listener.listener-socket
                       := make(<server-socket>,
                               host: listener.listener-host,
                               port: listener.listener-port);
                     inc!(listener.total-restarts);
                     #t
                   end;
                 end;
  if (restart?)
    log-info("%s restarting", listener.listener-name);
    listener-top-level(server, listener);
  else
    log-info("%s shutting down", listener.listener-name);
  end;
end listener-top-level;

//---TODO: need to set up timeouts.
//---TODO: need to limit the number of outstanding clients.
//---TODO: need to be able to stop the server from outside.
// Can't do anything to the thread, but can do things to the server socket
// so that it will return from 'accept' with some error, which we should
// catch gracefully..
//---TODO: need to handle errors.
// Listen and spawn handlers until listener socket breaks.
//
define function do-http-listen
    (server :: <server>, listener :: <listener>)
  let server-lock = server.server-lock;
  log-info("%s ready for service", listener.listener-name);
  iterate loop ()
    // Let outsiders know when we've blocked...
    listener.listener-listen-start := current-date();
    let socket = block ()
                   unless (listener.listener-exit-requested?)
                     // use "element-type: <byte>" here?
                     accept(listener.listener-socket) // blocks
                   end
                 exception (error :: <blocking-call-interrupted>)
                   // Usually this means we're shutting down so we closed the
                   // connection with close(s, abort: #t)
                   unless (listener.listener-exit-requested?)
                     log-error("Error accepting connections: %s", error);
                   end;
                   #f
                 exception (error :: <socket-condition>)
                   log-error("Error accepting connections: %s", error);
                   #f
                 end;
    synchronize-side-effects();
    listener.listener-listen-start := #f;
    when (socket)
      //---TODO: should limit number of clients.
      let client = #f;
      local method do-respond ()
              with-lock (server-lock) end;   // Wait for setup to finish.
              let client :: <client> = client;
              block ()
                with-socket-thread ()
                  handler-top-level(client);
                end;
              cleanup
                log-debug("Closing socket for %s", client);
                ignore-errors(<socket-condition>,
                              close(client.client-socket, abort: #t));
                release-client(client);
              end;
            end method;
      with-lock (server-lock)
        block()
          wrapping-inc!(listener.connections-accepted);
          wrapping-inc!(server.connections-accepted);
          let thread = make(<thread>,
                            name: format-to-string("HTTP Responder %d",
                                                   server.connections-accepted),
                            function:  do-respond);
          client := make(<client>,
                         server: server,
                         listener: listener,
                         socket: socket,
                         thread: thread);
          add!(server.server-clients, client);
        exception (ex :: <error>)
          // This should be <thread-error>, which is not yet exported
          // needs a compiler bootstrap, so specify it sometime later
          // hannes, 27th January 2007
          log-error("Thread error while making responder thread: %=", ex)
        end;
      end;
      loop();
    end when;
  end iterate;
  log-debug("Closing socket for %s", listener);
  close(listener.listener-socket, abort: #t);
end do-http-listen;

define open primary class <request>
    (<chunking-input-stream>, <basic-request>, <base-http-request>)

  // Contains the prefix of the URL that matched the <responder>.
  // i.e., this is the URL under which the <responder> was registered.
  slot request-path-prefix :: <string>;

  // Contains part of the URL path following the prefix URL (above).
  // This may be the empty string.
  slot request-path-tail :: <string>;

  // See http://www.w3.org/Protocols/rfc2616/rfc2616-sec5.html#sec5.2
  slot request-host :: false-or(<string>),
    init-value: #f;

  // Query values from either the URL or the body of the POST, if Content-Type
  // is application/x-www-form-urlencoded.
  constant slot request-query-values :: <string-table>,
    init-function: curry(make, <string-table>);

  slot request-keep-alive? :: <boolean>,
    init-value: #f;

  slot request-session :: false-or(<session>),
    init-value: #f;

  // TODO: This is only stored in the request for internal modularity
  //       reasons.  It should be removed.
  slot request-responder :: false-or(<responder>),
    init-value: #f;

end class <request>;

// Pass along the socket as the inner-stream for <chunking-input-stream>,
// which is a <wrapper-stream>.
//
define method make
    (class :: subclass(<request>), #rest args, #key client :: <client>, #all-keys)
 => (request :: <request>)
  apply(next-method, class, inner-stream: client.client-socket, args)
end;

// The request-url slot represents the URL in the Request-Line,
// and may not be absolute.  This method gives client code a way
// to get the whole thing.  (We assume scheme = HTTP for now.)
//
define method request-absolute-url
    (request :: <request>)
 => (url :: <url>)
  let url = request.request-url;
  if (absolute?(url))
    url
  else
    make(<url>,
         scheme: "http",
         userinfo: url.uri-userinfo,
         host: request.request-host,
         port: request.request-client.client-listener.listener-port,
         path: url.uri-path,
         query: url.uri-query,
         fragment: url.uri-fragment)
  end
end method request-absolute-url;

// Making a virtual hosts requires an instantiated server to do some
// initialization, so use this instead of calling make(<virtual-host>).
//
define method make-virtual-host
    (server :: <server>,
     #rest args,
     #key name, document-root, dsp-root,
          request-logger: req-logger,
          error-logger: err-logger,
          debug-logger: dbg-logger,
     #all-keys)
 => (vhost :: <virtual-host>)
  let vhost :: <virtual-host>
    = apply(make, <virtual-host>,
            document-root:
              document-root | subdirectory-locator(server.server-root, name),
            dsp-root:
              dsp-root | subdirectory-locator(server.server-root, name),
            request-logger:
              req-logger | server.default-virtual-host.request-logger,
            error-logger:
              err-logger | server.default-virtual-host.error-logger,
            debug-logger:
              dbg-logger | server.default-virtual-host.debug-logger,
            args);
  // Add a spec that matches all urls.
  add-directory-policy(vhost, root-directory-policy(vhost));
  vhost
end;

define method add-virtual-host
    (server :: <http-server>, vhost :: <virtual-host>, name :: <string>)
  let low-name = as-lowercase(name);
  if (element(server.virtual-hosts, low-name, default: #f))
    signal(make(<koala-api-error>,
                format-string: "Virtual host (%s) already exists.",
                format-arguments: list(low-name)));
  else
    server.virtual-hosts[low-name] := vhost;
  end;
end method add-virtual-host;

define generic virtual-host
    (thing :: <object>) => (vhost :: false-or(<virtual-host>));

define method virtual-host
    (name :: <string>)
 => (vhost :: false-or(<virtual-host>))
  element(*server*.virtual-hosts, as-lowercase(name), default: #f)
end;

define method virtual-host
    (request :: <request>)
 => (vhost :: false-or(<virtual-host>))
  let host-spec = request-host(request);
  if (host-spec)
    let colon = char-position(':', host-spec, 0, size(host-spec));
    let host = iff(colon, substring(host-spec, 0, colon), host-spec);
    let vhost = virtual-host(host)
                  | (*server*.fall-back-to-default-virtual-host?
                       & *server*.default-virtual-host);
    if (vhost)
      vhost
    else
      // TODO: see if the spec says what error to return here.
      resource-not-found-error(url: request.request-url);
    end;
  elseif (*server*.fall-back-to-default-virtual-host?)
    *server*.default-virtual-host
  else
    resource-not-found-error(url: request.request-url);
  end
end;

define thread variable *request* :: false-or(<request>) = #f;

define inline function current-request
    () => (request :: <request>)
  *request* | application-error(message: "There is no active HTTP request.")
end;

define thread variable *response* :: false-or(<response>) = #f;

define inline function current-response
    () => (response :: <response>)
  *response* | application-error(message: "There is no active HTTP response.")
end;

// Called (in a new thread) each time a new connection is opened.
// If keep-alive is requested, wait for more requests on the same
// connection.
//
define function handler-top-level
    (client :: <client>)
  dynamic-bind (*request* = #f,
                *server* = client.client-server,
                *virtual-host* = #f,  // set after read-request called
                *debug-logger* = *server*.default-virtual-host.debug-logger,
                *error-logger* = *server*.default-virtual-host.error-logger,
                *request-logger* = *server*.default-virtual-host.request-logger,
                *http-common-log* = *debug-logger*)
    block (exit-handler-top-level)
      while (#t)                      // keep alive loop
        let request :: <basic-request>
          = make(client.client-server.request-class, client: client);
        *request* := request;
        with-simple-restart("Skip this request and continue with the next")
          block (finish-request)
            // More recently installed handlers take precedence...
            let handler <error> = rcurry(htl-error-handler, finish-request);
            let handler <stream-error>
              = rcurry(htl-error-handler, exit-handler-top-level,
                       send-response: #f,
                       decline-if-debugging: #f);
            // This handler casts too wide of a net.  There's no reason to catch
            // all the subclasses of <recoverable-socket-condition> such as
            // <host-not-found> here.  But it's not clear what it SHOULD be catching
            // either.  --cgay Feb 2009
            let handler <socket-condition>
              = rcurry(htl-error-handler, exit-handler-top-level,
                       send-response: #f,
                       decline-if-debugging: #f);
            let handler <http-error> = rcurry(htl-error-handler, finish-request,
                                              decline-if-debugging: #f);

            read-request(request);

            *virtual-host* := virtual-host(request);
            *debug-logger* := *virtual-host*.debug-logger;
            *error-logger* := *virtual-host*.error-logger;
            *request-logger* := *virtual-host*.request-logger;
            *http-common-log* := *debug-logger*;

            invoke-handler(request);
            force-output(request.request-socket);
          end block; // finish-request
          if (~request-keep-alive?(request))
            exit-handler-top-level();
          end;
        end with-simple-restart;
      end while;
    end block; // exit-handler-top-level
  end dynamic-bind;
end function handler-top-level;

define function htl-error-handler
    (cond :: <condition>, next-handler :: <function>, exit-function :: <function>,
     #key decline-if-debugging = #t, send-response = #t)
  if (decline-if-debugging & debugging-enabled?(*server*))
    next-handler()
  else
    block ()
      log-debug("Error handling request: %s", cond);
      if (send-response)
        send-error-response(*request*, cond);
      end;
    cleanup
      exit-function()
    exception (ex :: <error>)
      // nothing
    end;
  end;
end function htl-error-handler;

// This method takes care of parsing the request headers and signalling any
// errors therein.
//---TODO: have overall timeout for header reading.
define method read-request (request :: <request>) => ()
  let socket = request.request-socket;
  let server = request.request-server;
  let (buffer, len) = read-http-line(socket);

  // RFC 2616, 4.1 - "Servers SHOULD ignore an empty line(s) received where a
  // Request-Line is expected."  Clearly you have to give up at some point so
  // we arbitrarily allow 5 blank lines.
  let line-count :: <integer> = 0;
  while (empty-line?(buffer, len))
    if (line-count > 5)
      bad-request-error(reason: "No Request-Line received");
    end;
    pset (buffer, len) read-http-line(socket) end;
  end;

  parse-request-line(server, request, buffer, len);
  unless (request.request-version == #"http/0.9")
    read-message-headers(socket,
                         buffer: buffer,
                         start: len,
                         headers: request.raw-headers);
  end unless;
  process-incoming-headers(request);
  // Unconditionally read all request content in case we need to process
  // further requests on the same connection.  This is temporary and needs
  // to be handled with more finesse.
  read-request-content(request);
end method read-request;

// Read the Request-Line.  RFC 2616 Section 5.1
//      Request-Line   = Method SP Request-URI SP HTTP-Version CRLF
//
define function parse-request-line
    (server :: <http-server>, request :: <request>,
     buffer :: <string>, eol :: <integer>)
 => ()
  let epos1 = whitespace-position(buffer, 0, eol);
  let bpos2 = epos1 & skip-whitespace(buffer, epos1, eol);
  let epos2 = bpos2 & whitespace-position(buffer, bpos2, eol);
  let bpos3 = epos2 & skip-whitespace(buffer, epos2, eol);
  let epos3 = bpos3 & whitespace-position(buffer, bpos3, eol) | eol;
  if (~bpos3)
    bad-request-error(reason: "Invalid request line");
  else
    let req-method = substring(buffer, 0, epos1);
    let url-string = substring(buffer, bpos2, epos2);
    let http-version = substring(buffer, bpos3, epos3);
    log-trace("<-- %s %s %s", req-method, url-string, http-version);
    request.request-method := validate-request-method(req-method);
    parse-request-url(server, request, url-string);
    request.request-version := validate-http-version(http-version);
  end if;
end function parse-request-line;

// This may be called by internal-redirect-to to morph a request for a
// new URL.  Probably should consider copying the request to a new <request>
// object rather than mutating the existing one, but this will have tow do
// for now.
define method parse-request-url
    (server :: <http-server>, request :: <request>, url-string :: <string>)
  request.request-raw-url-string := url-string;
  let url :: <url> = parse-url(url-string);
  // RFC 2616, 5.2 -- absolute URLs in the request line take precedence
  // over Host header.
  if (absolute?(url))
    request.request-host := url.uri-host;
  end;
  request.request-url := url;
  let (responder, tail, prefix) = find-responder(server, request.request-url);
  request.request-responder := responder;
  request.request-path-prefix := iff(prefix, join(prefix, "/"), "");
  request.request-path-tail := iff(tail, join(tail, "/"), "");
  remove-all-keys!(request.request-query-values);
  for (value keyed-by key in url.uri-query)
    request.request-query-values[key] := value;
  end;
end method parse-request-url;

define method validate-request-method
    (request-method :: <byte-string>)
 => (request-method :: <symbol>)
  if (member?(request-method, #["GET", "HEAD", "OPTIONS", "POST"], test: \=))
    // TODO: The request method should be case sensitive, so it shouldn't be a symbol.
    as(<symbol>, request-method)
  else
    not-implemented-error(what: format-to-string("Request method %s", request-method),
                          header-name: "Allow",
                          header-value: $allowed-request-methods-string);
  end
end method validate-request-method;


// This should only be called once it has been determined that the request has
// an entity body.  RFC 2616, 4.3 and 4.4 are useful for this function.
//
// TODO:
// This whole model is broken.  The responder function should be able to read
// streaming data from the request and do what it wants with it.  The server
// itself may want to keep track of how much data was read from the request so
// that it can finish reading unread data and discard it.
//
define function read-request-content
    (request :: <request>)
 => ()
  if (chunked-transfer-encoding?(request))
    request.request-content := read-to-end(request);
    log-debug("<==%=", request.request-content);
  else
    let content-length = get-header(request, "Content-Length", parsed: #t);
    if (~content-length)
      // RFC 2616 4.3: If no Transfer-Encoding and no Content-Length then
      // assume no message body.
      content-length := 0;
    end;
    if (*max-post-size* & content-length > *max-post-size*)
      //---TODO: the server MAY close the connection to prevent the client from
      // continuing the request.
      request-entity-too-large-error(max-size: *max-post-size*);
    else
      let buffer :: <byte-string> = make(<byte-string>, size: content-length);
      let n = kludge-read-into!(request-socket(request), content-length, buffer);
      // Should we check if the content size is too large?
      if (n ~= content-length)
        // RFC 2616, 4.4
        bad-request-error(reason: format-to-string("Request content size (%d) does not "
                                                   "match Content-Length header (%d)",
                                                   n, content-length));
      end;
      request-content(request) := buffer;
    end;
  end;
  process-request-content(request, request-content-type(request));
end read-request-content;

define inline function request-content-type (request :: <request>)
  let content-type-header = get-header(request, "content-type");
  as(<symbol>,
     if (content-type-header)
       // TODO:
       // this looks broken.  why ignore everything else?
       // besides, one should just use: get-header(request, "content-type", parsed: #t)
       // which should return the parsed content type.
       first(split(content-type-header, ";"))
     else
       ""
     end if)
end;


// Gary, in the trunk sources (1) below should now be fixed.  (read was passing the
// wrong arguments to next-method).
// (2) should also be fixed.  It used to cause "Dylan error: 35 is not of type {<class>: <sequence>}"
// But, if you pass on-end-of-stream: #"blah" and then arrange to close the stream somehow
// you'll get an invalid return type error.
// Uncomment either (1) or (2) and comment out the "let n ..." and "assert..." below and
// then start koala example, go to http://localhost:7020/foo/bar/form.html and
// click the Submit button.  As long as neither of these gets an error in the trunk
// build we're better off than before at least, if not 100% fixed.

//let buffer :: <sequence> = read-n(socket, sz, on-end-of-stream: #f);  // (1)
//let n = read-into!(socket, sz, buffer, start: len);                 // (2)
// The following compensates for a bug in read and read-into! in FD 2.0.1

define function kludge-read-into!
    (stream :: <stream>, n :: <integer>, buffer :: <byte-string>,
     #key start :: <integer> = 0)
 => (n :: <integer>)
  block (return)
    for (i from start below buffer.size,
         count from 0 below n)
      let elem = read-element(stream, on-end-of-stream: #f);
      buffer[i] := (elem | return(count));
    end;
    n
  end;
end;


define open generic process-request-content
    (request :: <request>, content-type :: <object>);

define method process-request-content
    (request :: <request>, content-type :: <object>)
  // do nothing
end;

define method process-request-content
    (request :: <request>, content-type == #"application/x-www-form-urlencoded")
  // By the time we get here request-query-values has already
  // been bound to a <string-table> containing the URL query
  // values. Now we augment it with any form values.
  let parsed-query = split-query(request-content(request),
                                 replacements: list(pair("\\+", " ")));
  for (value keyed-by key in parsed-query)
    request.request-query-values[key] := value;
  end for;
  // ---TODO: Deal with content types intelligently.
  // For now this'll have to do.
end method process-request-content;

/* REWRITE
define method process-request-content
    (content-type == #"multipart/form-data",
     request :: <request>,
     buffer :: <byte-string>,
     content-length :: <integer>)
 => (content :: <string>)
  let header-content-type = split(get-header(request, "content-type"), ';');
  if (header-content-type.size < 2)
    bad-request-error(...)
  end;
  let boundary = split(second(header-content-type), '=');
  if (element(boundary, 1, default: #f))
    let boundary-value = second(boundary);
    extract-form-data(buffer, boundary-value, request);
    // ???
    request-content(request) := buffer
  else
    bad-request-error(...)
  end if;
end method process-request-content;
*/

define function send-error-response
    (request :: <request>, cond :: <condition>)
  block (exit)
    let handler <error>
      = method (cond, next-handler)
          if (debugging-enabled?(request.request-server))
            next-handler();
          else
            log-debug("An error occurred while sending error response. %s", cond);
            exit();
          end;
        end;
    send-error-response-internal(request, cond);
  end;
end function send-error-response;


define method send-error-response-internal
    (request :: <request>, err :: <error>)
  let headers = http-error-headers(err) | make(<header-table>);
  let response = make(<response>,
                      request: request,
                      headers: headers);
  let one-liner = http-error-message-no-code(err);
  unless (request-method(request) == #"head")
    // TODO: Display a pretty error page.
    add-header(response, "Content-Type", "text/plain");
    write(response, one-liner);
    write(response, "\r\n");
    // Don't show internal error messages to the end user unless the server
    // is being debugged.  It can give away too much information, such as the
    // full path to a missing file on the server.
    if (debugging-enabled?(*server*))
      // TODO: display a backtrace
      write(response, condition-to-string(err));
      write(response, "\r\n");
    end;
  end unless;
  response.response-code := http-status-code(err);
  response.response-reason-phrase := one-liner;
  finish-response(response);
end method send-error-response-internal;

// Do whatever we need to do depending on the incoming headers for
// this request.  e.g., handle "Connection: Keep-alive", store
// "User-agent" statistics, etc.
//
define method process-incoming-headers (request :: <request>)
  bind (conn-values :: <sequence> = get-header(request, "Connection", parsed: #t) | #())
    if (member?("Close", conn-values, test: string-equal?))
      request-keep-alive?(request) := #f
    elseif (member?("Keep-Alive", conn-values, test: string-equal?))
      request-keep-alive?(request) := #t
    end;
  end;
  bind (host/port = get-header(request, "Host", parsed: #t))
    let (host, port) = host/port & values(head(host/port), tail(host/port));
    if (~host & request.request-version == #"HTTP/1.1")
      // RFC 2616, 19.6.1.1 -- HTTP/1.1 requests MUST include a Host header.
      bad-request-error(reason: "HTTP/1.1 requests must include a Host header");
    end;
    // RFC 2616, 5.2 -- If request host is already set then there was an absolute
    // URL in the request line, which takes precedence, so ignore Host header here.
    if (host & ~request.request-host)
      request.request-host := host;
    end;
  end;
  bind (agent = get-header(request, "User-Agent"))
    agent & note-user-agent(request-server(request), agent);
  end;
end method process-incoming-headers;

// Invoke the appropriate handler for the given request URL and method.
//
define method invoke-handler
    (request :: <request>)
  let headers = make(<header-table>);
  let response = make(<response>,
                      request: request,
                      headers: headers);
  if (request.request-keep-alive?)
    add-header(response, "Connection", "Keep-Alive");
  end if;
  %invoke-handler(request, response);
end method invoke-handler;

// Used by internal-redirect-to so that one responder can invoke a different
// responder completely internally to the server.
//
define method %invoke-handler
    (request :: <request>, response :: <response>)
  if (request.request-method == #"OPTIONS")
    if (request.request-raw-url-string = "*")
      add-header(response, "Allow", $allowed-request-methods-string);
    elseif (request.request-responder)
      let methods = find-request-methods(request);
      if (~empty?(methods))
        add-header(response, "Allow", join(methods, ", ", key: as-uppercase))
      end;
    end;
  else
    dynamic-bind (*response* = response,
                  // This is set to a <page-context> when first requested.
                  *page-context* = #f)
      if (request.request-responder)
        let (action, match) = find-action(request);
        if (action)
          // Invoke the action function with keyword arguments matching the names
          // of the named groups in the first regular expression that matches the
          // tail of the url, if any.  Also pass the entire match as the match:
          // argument so unnamed groups and the entire match can be accessed.
          let arguments = #[];
          if (match)
            arguments := make(<deque>);
            push-last(arguments, match:);
            push-last(arguments, match);
            for (group keyed-by name in match.groups-by-name)
              if (group)
                // TODO:
                // as(<symbol>) can be a memory leak.  This one can match
                // an arbitrary string in the URL, so it's bad.
                push-last(arguments, as(<symbol>, name));
                push-last(arguments, group.group-text);
              end if;
            end for;
          end if;
          block ()
            invoke-responder(request, action, arguments)
          exception (ex :: <skip-remaining-responders>)
            // The idea is that if 'action' is a sequence then one of the
            // functions therein can signal this exception to say "I handled it."
            // Not sure how useful this might be in practice.
          end;
        else
          resource-not-found-error(url: request.request-url);
        end if;
      else
        // generates 404 if not found
        // TODO: static files should be handled through the normal means:
        //       add-responder(url, curry(serve-static-file, policy))
        serve-static-file-or-cgi-script();
      end if;
    end dynamic-bind;
  end if;
  finish-response(response);
end method %invoke-handler;

define inline function find-action
    (request :: <request>)
 => (action, match)
  let rm-map = request.request-responder.request-method-map;
  let tail-responders = element(rm-map, request.request-method, default: #f);
  if (tail-responders)
    block (return)
      let url-tail = request.request-path-tail;
      for (tail-responder in tail-responders)
        let match = regex-search(tail-responder.tail-responder-regex, url-tail);
        if (match)
          return(tail-responder.tail-responder-action, match)
        end if;
      end for;
    end block
  end
end function find-action;

// Return a list of request methods that apply for the given request's
// URL and tail URL.  Used for the OPTIONS request method.
//
define inline function find-request-methods
    (request :: <request>)
 => (request-methods :: <sequence>)
  let rm-map = request.request-responder.request-method-map;
  let url-tail = request.request-path-tail;
  let methods = #();
  for (req-method in $allowed-request-methods)
    let regex-map = element(rm-map, req-method, default: #());
    block (exit-loop)
      for (actions keyed-by regex in regex-map)
        let match = regex-search(regex, url-tail);
        if (match)
          methods := pair(req-method, methods);
          exit-loop();
        end if;
      end for;
    end block;
  end for;
  methods
end function find-request-methods;

// See %invoke-handler
define class <skip-remaining-responders> (<condition>)
end;

// Clients can override this to create other types of responders.
// 
define open generic invoke-responder
    (request :: <request>, action :: <object>, arguments :: <sequence>)
 => ();

// action unknown
define method invoke-responder
    (request :: <request>, action :: <object>, arguments :: <sequence>)
 => ()
  log-error("Unknown action %= in action sequence.", action);
  // This is less specific than the log message because it may end up
  // being displayed to the user.
  application-error(message: "Unknown responder action");
end;

// action sequence
// Action functions should signal <skip-remaining-responders> to skip
// execution of any remaining responders in the sequence.
define method invoke-responder
    (request :: <request>, actions :: <collection>, arguments :: <sequence>)
 => ()
  for (action in actions)
    invoke-responder(request, action, arguments);
  end;
end;

// action function
define method invoke-responder
    (request :: <request>, action :: <function>, arguments :: <sequence>)
 => ()
  apply(action, arguments)
end;


define inline function empty-line?
    (buffer :: <byte-string>, len :: <integer>) => (empty? :: <boolean>)
  len == 1 & buffer[0] == $cr
end;

define class <http-file> (<object>)
  constant slot http-file-filename :: <string>,
    required-init-keyword: filename:;
  constant slot http-file-content :: <byte-string>,
    required-init-keyword: content:;
  constant slot http-file-mime-type :: <string>,
    required-init-keyword: mime-type:;
end;

/* REWRITE
define method extract-form-data
 (buffer :: <string>, boundary :: <string>, request :: <request>)
  // strip everything after end-boundary
  let buffer = first(split(buffer, concatenate("--", boundary, "--")));
  let parts = split(buffer, concatenate("--", boundary));
  for (part in parts) 
    let part = split(part, "\r\n\r\n");
    let header-entries = split(first(part), "\r\n");
    let disposition = #f;
    let name = #f;
    let type = #f;
    let filename = #f;
    for (header-entry in header-entries)
      let header-entry-parts = split(header-entry, ';');
      for (header-entry-part in header-entry-parts)
        let eq-pos = char-position('=', header-entry-part, 0, size(header-entry-part));
        let p-pos = char-position(':', header-entry-part, 0, size(header-entry-part));
        if (p-pos & (substring(header-entry-part, 0, p-pos) = "Content-Disposition"))
          disposition := substring(header-entry-part, p-pos + 2, size(header-entry-part));
        elseif (p-pos & (substring(header-entry-part, 0, p-pos) = "Content-Type"))
          type := substring(header-entry-part, p-pos + 2, size(header-entry-part));
        elseif (eq-pos & (substring(header-entry-part, 0, eq-pos) = "name"))
          // name unquoted
          name := substring(header-entry-part, eq-pos + 2, size(header-entry-part) - 1);
        elseif (eq-pos & (substring(header-entry-part, 0, eq-pos) = "filename"))
          // filename unquoted
          filename := substring(header-entry-part, eq-pos + 2, size(header-entry-part) - 1);
        end if;
      end for;
    end for;
    if (part.size > 1)
      // TODO: handle disposition = "multipart/form-data" and parse that again
      //disposition = "multipart/form-data" => ...
      if (disposition = "form-data")
        let content = substring(second(part), 0, size(second(part)) - 1);
        request.request-query-values[name]
          := if (filename & type)
               make(<http-file>, filename: filename, content: content, mime-type: type);
             else
               content;
             end if;
      end if;
    end if;
  end for;
end method extract-form-data;
*/

define inline function get-query-value
    (key :: <string>, #key as: as-type :: false-or(<type>))
 => (value :: <object>)
  let val = element(*request*.request-query-values, key, default: #f);
  if (as-type & val)
    as(as-type, val)
  else
    val
  end
end function get-query-value;

// with-query-values (name, type, go as go?, search) x end;
//   
define macro with-query-values
    { with-query-values (?bindings) ?:body end }
 => { ?bindings;
      ?body }

 bindings:
   { } => { }
   { ?binding, ... } => { ?binding; ... }

 binding:
   { ?:name } => { let ?name = get-query-value(?"name") }
   { ?:name as ?var:name } => { let ?var = get-query-value(?"name") }
end;

define function count-query-values
    () => (count :: <integer>)
  *request*.request-query-values.size
end;

define method do-query-values
    (f :: <function>)
  for (val keyed-by key in *request*.request-query-values)
    f(key, val);
  end;
end;


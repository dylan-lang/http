Module:    httpi
Synopsis:  Core HTTP server code
Author:    Gail Zacharias, Carl Gay
Copyright: Copyright (c) 2001-2010 Carl L. Gay.  All rights reserved.
           Original Code is Copyright (c) 2001 Functional Objects, Inc.  All rights reserved.
License:      See License.txt in this distribution for details.
Warranty:  Distributed WITHOUT WARRANTY OF ANY KIND


define constant $server-name = "Koala";

define constant $server-version = "0.9";

define constant $server-header-value = concatenate($server-name, "/", $server-version);

// This is needed to handle sockets shutdown.
define variable *exiting-application* = #f;

begin
  register-application-exit-function(method ()
                                       *exiting-application* := #t
                                     end);
end;


//// <http-server>

// The user instantiates this class directly, passing configuration options
// as init args.
//
define open class <http-server> (<multi-logger-mixin>, <abstract-router>)
  // Whether the server should run in debug mode or not.  If this is true then
  // errors encountered while servicing HTTP requests will not be handled by the
  // server itself.  Normally the server will handle them and return an "internal
  // server error" response.  A good way to debug Dylan Server Pages.  Can be
  // enabled via the --debug command-line option.
  slot debugging-enabled? :: <boolean> = #f,
    init-keyword: debug:;

  // Value to send as 'Server' header.
  slot server-header :: <byte-string> = $server-header-value;

  constant slot server-lock :: <simple-lock>,
    required-init-keyword: lock:;

  // lowercase fqdn -> <virtual-host>
  constant slot virtual-hosts :: <string-table> = make(<string-table>),
    init-keyword: virtual-hosts:;

  // Use this if no virtual host matches the Host header or URL and
  // use-default-virtual-host? is true.
  slot default-virtual-host :: <virtual-host> = make(<virtual-host>),
    init-keyword: default:;

  // If true, use the default vhost if the given host isn't found.
  slot use-default-virtual-host? :: <boolean> = #t,
    init-keyword: use-default-virtual-host?:;

  // Rewrite rules are stored here on the theory that they may
  // eventually apply to the request host.  Possibly there should
  // be a separate set of rules per vhost?
  constant slot rewrite-rules :: <stretchy-vector> = make(<stretchy-vector>);

  //// Next 5 slots are to support clean server shutdown.

  constant slot server-listeners :: <stretchy-vector>,
    required-init-keyword: listeners:;

  constant slot server-clients :: <stretchy-vector> = make(<stretchy-vector>);

  constant slot listeners-shutdown-notification :: <notification>,
    required-init-keyword: listeners-shutdown-notification:;

  constant slot clients-shutdown-notification :: <notification>,
    required-init-keyword: clients-shutdown-notification:;

  constant slot request-class :: subclass(<basic-request>) = <request>,
    init-keyword: request-class:;

  //---TODO: response for unsupported-request-method-error MUST include
  // Allow: field...  Need an API for making sure that happens.
  // RFC 2616, 5.1.1

  //// Statistics
  // TODO: move these elsewhere

  slot connections-accepted :: <integer> = 0;

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

end class <http-server>;

define sealed method make
    (class :: subclass(<http-server>), #rest keys, #key listeners = #())
 => (server :: <http-server>)
  // listeners, if specified, is a sequence of <listener>s, or strings in
  // the form "addr:port".
  let listeners = map-as(<stretchy-vector>, make-listener, listeners);
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

define method initialize
    (server :: <http-server>, #key)
  next-method();
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


//// Virtual hosts

define open generic find-virtual-host
    (server :: <http-server>, fqdn :: <string>)
 => (vhost :: <virtual-host>);

define method find-virtual-host
    (server :: <http-server>, fqdn :: <string>)
 => (vhost :: <virtual-host>)
  let fqdn = as-lowercase(fqdn);
  element(server.virtual-hosts, fqdn, default: #f)
  | iff(server.use-default-virtual-host?,
        server.default-virtual-host,
        %resource-not-found-error())
end method find-virtual-host;

define open generic add-virtual-host
    (server :: <http-server>, fqdn :: <string>, vhost :: <virtual-host>)
 => ();

define method add-virtual-host
    (server :: <http-server>, fqdn :: <string>, vhost :: <virtual-host>)
 => ()
  let name = as-lowercase(fqdn);
  if (element(server.virtual-hosts, fqdn, default: #f))
    koala-api-error("Attempt to add a virtual host named %= to %= but "
                    "a virtual host by that name already exists.",
                    name, server);
  else
    server.virtual-hosts[name] := vhost;
    log-info("Added virtual host %=.", name);
  end;
end method add-virtual-host;



//// Resource protocols

// Adding a resource directly to an <http-server> adds it to the default
// virtual host.  If you want to add it to a specific virtual host, use
// find-virtual-host(server, fqdn).
define method add-resource
    (server :: <http-server>, url :: <object>, resource :: <abstract-resource>,
     #rest args, #key)
  //log-debug("add-resource(%=, %=, %=)", server, url, resource);
  apply(add-resource, server.default-virtual-host, url, resource, args);
end;

define method find-resource
    (server :: <http-server>, url :: <object>)
 => (resource :: <abstract-resource>, prefix :: <list>, suffix :: <list>)
  log-debug("find-resource(%=, %=)", server, url);
  find-resource(server.default-virtual-host, url)
end;

define method do-resources
    (server :: <http-server>, function :: <function>,
     #key seen :: <list> = #())
 => ()
  for (vhost in server.virtual-hosts)
    if (~member?(vhost, seen))
      do-resources(vhost, function, seen: seen);
    end;
  end;
  let vhost = server.default-virtual-host;
  if (~member?(vhost, seen))
    do-resources(vhost, function, seen: seen);
  end;
end method do-resources;


define method generate-url
    (server :: <http-server>, name :: <string>, #rest args, #key)
 => (url)
  apply(generate-url, server.default-virtual-host, name, args)
end;


define function release-client
    (client :: <client>)
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

  slot listener-thread :: <thread> = #f;

  slot listener-exit-requested? :: <boolean> = #f;

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
  constant slot client-server :: <http-server>,
    required-init-keyword: server:;

  constant slot client-listener :: <listener>,
    required-init-keyword: listener:;

  constant slot client-socket :: <tcp-socket>,
    required-init-keyword: socket:;

  constant slot client-thread :: <thread>,
    required-init-keyword: thread:;

end class <client>;


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
  dynamic-bind (*debug-logger* = server.debug-logger,
                *error-logger* = server.error-logger,
                *request-logger* = server.request-logger,
                *http-common-log* = *debug-logger*)
    log-info("Starting %s HTTP Server", $server-name);
    ensure-sockets-started();
    log-info("Server root directory is %s", server-root(server));
    if (empty?(server.server-listeners))
      log-info("No listeners were configured; using default (0.0.0.0:%d).",
               $default-http-port);
      add!(server.server-listeners, make(<listener>, host: "0.0.0.0",
                                         port: $default-http-port));
    end if;
    for (listener in server.server-listeners)
      start-http-listener(server, listener)
    end;
    if (wait)
      // Connect to each listener or signal error.
      wait-for-listeners-to-start(server.server-listeners);
      log-info("%s %s ready for service", $server-name, $server-version);
    end;
    if (~background)
      // Main thread has nothing to do but wait.
      join-listeners(server);
    end;
    #t
  end dynamic-bind
end method start-server;

define function wait-for-listeners-to-start
    (listeners :: <sequence>)
  // Either make a connection to each listener or signal an error.
  for (listener in listeners)
    let start :: <date> = current-date();
    let max-wait = make(<duration>, days: 0, hours: 0, minutes: 0, seconds: 10,
                        microseconds: 0);
    iterate loop (iteration = 1)
      let socket = #f;
      block ()
        let host = listener.listener-host;
        let conn-host = iff(host = "0.0.0.0", "127.0.0.1", host);
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

define open generic stop-server
    (server :: <http-server>, #key abort);

define method stop-server
    (server :: <http-server>, #key abort)
  stop-listeners(server);
  join-clients(server);
  log-info("%s HTTP server stopped", $server-name);
end method stop-server;

define function stop-listeners
    (server :: <http-server>)
  for (listener in server.server-listeners)
    listener.listener-exit-requested? := #t;
  end;
  synchronize-side-effects();
  
  // Connect to each listener to make its call to accept() return.
  for (listener in server.server-listeners)
    let socket = #f;
    block ()
      let host = listener.listener-host;
      let conn-host = iff(host = "0.0.0.0", "127.0.0.1", host);
      socket := make(<tcp-socket>,
                     host: conn-host,
                     port: listener.listener-port);
    cleanup
      socket & close(socket);
    exception (ex :: <connection-failed>)
    exception (ex :: <error>)
    end block;
  end for;
  join-listeners(server);
end function stop-listeners;

define function join-listeners
    (server :: <http-server>)
  for (listener in server.server-listeners)
    join-thread(listener.listener-thread);
  end;
end;

define function join-clients
    (server :: <http-server>)
  // Clients are removed from server.server-clients when they exit,
  // which can result in #f being stored in the <stretchy-vector>
  // before its size is updated.  Hence the lock.
  let clients = with-lock (server.server-lock)
                  copy-sequence(server.server-clients)
                end;
  for (client in clients)
    close(client.client-socket, abort?: #t);
    log-info("Waiting for shut down of %s...", client);
    join-thread(client.client-thread);
    log-info("Client %s shut down", client);
  end;
end function join-clients;

define function start-http-listener
    (server :: <http-server>, listener :: <listener>)
  let server-lock = server.server-lock;
  local method release-listener ()
          remove!(server.server-listeners, listener);
          when (empty?(server.server-listeners))
            release-all(server.listeners-shutdown-notification);
          end;
        end;
  local method run-listener-top-level ()
          dynamic-bind (*debug-logger* = server.debug-logger,
                        *error-logger* = server.error-logger,
                        *request-logger* = server.request-logger,
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
    let handler <serious-condition>
      = method (cond, next-handler)
          log-error("Error creating socket for %s: %s", listener.listener-name, cond);
          release-listener();
          next-handler();
        end;
    make-socket(listener);
    let thread = make(<thread>,
                      name: listener.listener-name,
                      function: run-listener-top-level);
    listener.listener-thread := thread;
  end;
end start-http-listener;

define function listener-top-level
    (server :: <http-server>, listener :: <listener>)
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
    (server :: <http-server>, listener :: <listener>)
  let server-lock = server.server-lock;
  log-info("%s ready for service", listener.listener-name);
  iterate loop ()
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
    when (socket)
      //---TODO: should limit number of clients.
      let client = #f;
      local method do-respond ()
              with-lock (server-lock) end;   // Wait for setup to finish.
              let client :: <client> = client;
              respond-top-level(client);
            end method;
      with-lock (server-lock)
        block()
          wrapping-inc!(listener.connections-accepted);
          wrapping-inc!(server.connections-accepted);
          let thread = make(<thread>,
                            name: format-to-string("HTTP Responder %d",
                                                   server.connections-accepted),
                            function: do-respond);
          client := make(<client>,
                         server: server,
                         listener: listener,
                         socket: socket,
                         thread: thread);
          add!(server.server-clients, client);
        exception (ex :: <thread-error>)
          log-error("Thread error while making responder thread: %=", ex)
        end;
      end;
      loop();
    end when;
  end iterate;
  close(listener.listener-socket, abort: #t);
end function do-http-listen;


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
define function respond-top-level
    (client :: <client>)
  block ()
    with-socket-thread ()
      %respond-top-level(client);
    end;
  cleanup
    ignore-errors(<socket-condition>,
                  close(client.client-socket, abort: #t));
    release-client(client);
  end;
end function respond-top-level;

define function %respond-top-level
    (client :: <client>)
  dynamic-bind (*request* = #f,
                *server* = client.client-server,
                *debug-logger* = *server*.debug-logger,
                *error-logger* = *server*.error-logger,
                *request-logger* = *server*.request-logger,
                *http-common-log* = *debug-logger*)
    block (exit-respond-top-level)
      while (#t)                      // keep alive loop
        with-simple-restart("Skip this request and continue with the next")
          *request* := make(client.client-server.request-class, client: client);
          let request :: <basic-request> = *request*;
          block (finish-request)
            // More recently installed handlers take precedence...
            let handler <error> = rcurry(htl-error-handler, finish-request);
            let handler <stream-error>
              = rcurry(htl-error-handler, exit-respond-top-level,
                       send-response: #f,
                       decline-if-debugging: #f);
            // This handler casts too wide of a net.  There's no reason to catch
            // all the subclasses of <recoverable-socket-condition> such as
            // <host-not-found> here.  But it's not clear what it SHOULD be catching
            // either.  --cgay Feb 2009
            let handler <socket-condition>
              = rcurry(htl-error-handler, exit-respond-top-level,
                       send-response: #f,
                       decline-if-debugging: #f);
            let handler <http-error> = rcurry(htl-error-handler, finish-request,
                                              decline-if-debugging: #f);

            read-request(request);
            let headers = make(<header-table>);
            if (request.request-keep-alive?)
              set-header(headers, "Connection", "Keep-Alive");
            end if;
            dynamic-bind (*response* = make(<response>,
                                            request: request,
                                            headers: headers),
                          // Bound to a <page-context> when first requested.
                          *page-context* = #f)
              route-request(*server*, request);
              finish-response(*response*);
            end;
            force-output(request.request-socket);
          end block; // finish-request
          if (client.client-listener.listener-exit-requested?
              | ~request-keep-alive?(request))
            exit-respond-top-level();
          end;
        end with-simple-restart;
      end while;
    end block; // exit-respond-top-level
  end dynamic-bind;
end function %respond-top-level;

// Find a resource for the request and call respond on it.
// Signal 404 if no resource can be found.
//
define method route-request
    (server :: <http-server>, request :: <request>)
  let old-path :: <string> = build-path(request.request-url);
  let (new-path :: <string>, rule) = rewrite-url(old-path, server.rewrite-rules);
  if (new-path ~= old-path)
    do-rewrite-redirection(server, request, new-path, rule);
  else
    let vhost :: <virtual-host> = find-virtual-host(server, request.request-host);

    *debug-logger* := vhost.debug-logger;
    *error-logger* := vhost.error-logger;
    *request-logger* := vhost.request-logger;

    // Find a resource or signal an error.
    let (resource :: <abstract-resource>, prefix :: <list>, suffix :: <list>)
      = find-resource(vhost, request.request-url);

    log-debug("Found resource %s, prefix = %=, suffix = %=",
              resource, prefix, suffix);
    request.request-url-path-prefix := join(prefix, "/");
    request.request-url-path-suffix := join(suffix, "/");

    let (bindings, unbound, leftovers) = path-variable-bindings(resource, suffix);
    if (~empty?(leftovers))
      unmatched-url-suffix(resource, leftovers);
    end;
    %respond(resource, bindings);
  end;
end method route-request;

// Internally redirect to a different URL.  parse-request-url resets various
// URL-related slots in the request.  This should only be used before any
// data has been written to the response.  (Maybe should clear the headers
// as well?)
//
define method internal-redirect-to
    (url :: <string>)
  let request :: <request> = current-request();
  parse-request-url(*server*, request, url);
  route-request(*server*, request);
end;

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
    set-header(response, "Content-Type", "text/plain");
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



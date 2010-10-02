Module:    httpi
Synopsis:  Core HTTP server code
Author:    Gail Zacharias, Carl Gay
Copyright: Copyright (c) 2001-2010 Carl L. Gay.  All rights reserved.
           Original Code is Copyright (c) 2001 Functional Objects, Inc.  All rights reserved.
License:   Functional Objects Library Public License Version 1.0
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


//// Request Router

// The request router class gives libraries a way to provide alternate
// ways of routing/mapping URLs to resources if they don't like the default
// mechanism, by storing a different subclass of <abstract-router>
// in the <http-server>.

define open abstract class <abstract-router> (<object>)
end;


// Add a route to a resource.  (Or, map a URL to a resource.)
// URLs (and more specifically, URL paths) may be represented in various ways,
// which is why the 'url' parameter is typed as <object>.
//
define open generic add-resource
    (router :: <abstract-router>,
     url :: <object>,
     resource :: <abstract-resource>,
     #key, #all-keys);


// Find a resource mapped to the given URL, or signal an error.
// Return the resource, the URL prefix it was mapped to, and the URL
// suffix that remained.
//
// TODO: The return values for this are probably too specific to the
//       way the default router works.  It's probably a bit more generic
//       to return (resource, url, bindings) or some such.
//
define open generic find-resource
    (router :: <abstract-router>, url :: <object>)
 => (resource :: <abstract-resource>, prefix :: <list>, suffix :: <list>);


// Generate a URL from a name and path variables.
// If the given name doesn't exist signal <koala-api-error>.
define open generic generate-url
    (router :: <abstract-router>, name :: <string>, #key, #all-keys)
 => (url);



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

  slot request-router :: <abstract-router> = make(<resource>),
    init-keyword: request-router:;

  //// Next 5 slots are to support clean server shutdown.

  constant slot server-listeners :: <stretchy-vector>,
    required-init-keyword: listeners:;

  constant slot server-clients :: <stretchy-vector> = make(<stretchy-vector>);

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
  dynamic-bind (*debug-logger* = server.debug-logger,
                *error-logger* = server.error-logger,
                *request-logger* = server.request-logger,
                *http-common-log* = *debug-logger*)
    log-info("Starting %s HTTP Server", $server-name);
    ensure-sockets-started();
    log-info("Server root directory is %s", server-root(server));
    if (empty?(server.server-listeners))
      log-error("No listeners were configured; start-up aborting.");
      #f
    else
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
    end
  end dynamic-bind
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
        exception (ex :: <thread-error>)
          log-error("Thread error while making responder thread: %=", ex)
        end;
      end;
      loop();
    end when;
  end iterate;
  log-debug("Closing socket for %s", listener);
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
define function handler-top-level
    (client :: <client>)
  dynamic-bind (*request* = #f,
                *server* = client.client-server,
                *debug-logger* = *server*.debug-logger,
                *error-logger* = *server*.error-logger,
                *request-logger* = *server*.request-logger,
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
          if (~request-keep-alive?(request))
            exit-handler-top-level();
          end;
        end with-simple-restart;
      end while;
    end block; // exit-handler-top-level
  end dynamic-bind;
end function handler-top-level;

// Find a resource for the request and call respond on it.
// Signal 404 if no resource can be found.
//
define method route-request
    (server :: <http-server>, request :: <request>)
  // Find a resource or signal an error.
  let (resource :: <abstract-resource>, prefix :: <list>, suffix :: <list>)
    = find-resource(server, request);

  // Bind loggers for the vhost being used.
  // TODO: This assumes <resource> but should only assume <abstract-resource>.
  iterate loop (current = resource, vhost = #f)
    if (current)
      loop(current.resource-parent,
           iff(instance?(current, <virtual-host>),
               current,
               vhost))
    elseif (vhost)
      *debug-logger* := vhost.debug-logger;
      *error-logger* := vhost.error-logger;
      *request-logger* := vhost.request-logger;
    end;
  end;

  log-debug("Found resource %s, prefix = %=, suffix = %=",
            resource, prefix, suffix);
  request.request-url-path-prefix := join(prefix, "/");
  request.request-url-path-suffix := join(suffix, "/");

  let (bindings, unbound, leftovers) = path-variable-bindings(resource, suffix);
  if (~empty?(leftovers))
    unmatched-url-suffix(resource, leftovers);
  end;
  apply(respond, resource, bindings);
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



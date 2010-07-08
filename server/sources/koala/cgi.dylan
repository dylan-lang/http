Module: httpi
Synopsis:  CGI script handling
Author:    Carl Gay
Copyright: Copyright (c) 2009 Carl L. Gay.  All rights reserved.
License:   Functional Objects Library Public License Version 1.0
Warranty:  Distributed WITHOUT WARRANTY OF ANY KIND

// CGI 1.2 specification draft: http://ken.coar.org/cgi/cgi-120-00a.html
// CGI 1.1 "spec": http://hoohoo.ncsa.illinois.edu/cgi/interface.html

// These headers are defined by the CGI spec, not HTTP.  If the CGI script
// outputs any of these headers then the server must do special processing.
// Otherwise the CGI script is assumed to generate a valid HTTP response
// and its entire output is send directly back to the client.
//
define constant $cgi-header-names :: <sequence>
  = #["Location", "Status", "Script-Control"];

// HTTP headers that should not be passed through to the CGI script
// in the environment.
// TODO: make this configurable
define variable *cgi-excluded-http-header-names* :: <sequence>
  = #["Authorization", "Content-Length", "Content-Type"];

define method serve-cgi-script
    (script :: <locator>, script-name :: <string>,
     #key path-info :: false-or(<string>))
  let command = as(<string>, script);
  log-debug("Running CGI script: %s", command);
  let request :: <request> = current-request();
  let env :: <string-table>
    = make-cgi-environment(script, script-name, path-info: path-info);

  log-debug("  CGI environment:");
  for (value keyed-by key in env)
    log-debug("  %s: %s", key, value);
  end;
  
  // Note: when passing a sequence of strings to run-application one
  //       must use as(limited(<vector>, of: <string>), list(command))
  let (exit-code, signal, child, stdout, stderr)
    = run-application(command,
                      asynchronous?: #t,
                      under-shell?: #f,
                      inherit-console?: #t,
                      environment: env,
                      working-directory: locator-directory(script),
                      input: null:,
                      output: stream:,
                      error: stream:);
                      
                      // Windows options, ignored on posix systems
                      //activate?: #f,
                      //minimize?: #t,
                      //hide?: #t);
  block ()
    if (exit-code ~= 0)
      log-error("CGI failed to launch: %s, exit-code: %s, signal: %s",
                command, exit-code, signal);
      application-error(message: format-to-string("Application error: %s",
                                                  exit-code));
    else
      process-cgi-script-output(stdout, stderr);
    end;
  cleanup
    let (exit-code, signal) = wait-for-application-process(child);
    log-debug("  CGI terminated: %s, exit-code: %s, signal: %s",
              command, exit-code, signal);
  exception (ex :: <serious-condition>)
    log-error("  CGI terminated with error: %s", ex);
    log-debug("  CGI stdout = %s", %read-buffered-data(stdout));
  end;
end method serve-cgi-script;

// does something like this exist already?
define function %read-buffered-data
    (stream) => (data :: <string>)
  let chars = make(<string>, size: 2000);
  let index :: <integer> = 0;
  block ()
    while (~stream-at-end?(stream))
      chars[index] := read-element(stream);
      inc!(index);
      if (index >= chars.size)
        let new = make(<string>, size: chars.size * 2);
        for (i :: <integer> from 0 below chars.size)
          new[i] := chars[i];
        end;
        chars := new;
      end;
    end;
  exception (ex :: <end-of-stream-error>)
  end;
  copy-sequence(chars, end: index)
end function %read-buffered-data;

// Register this responder for directories containing CGI scripts
// with add-cgi-directory-responder.
define function cgi-directory-responder
    (directory :: <directory-locator>,
     #key script-name :: <string>, path-info :: false-or(<string>))
  log-debug("cgi-directory-responder: script-name = %=, path-info = %=",
            script-name, path-info);
  let request = current-request();
  let url = concatenate(request.request-path-prefix, "/", script-name);
  log-debug("cgi-directory-responder: directory = %s, url = %s",
            as(<string>, directory), url);
  let script = merge-locators(as(<file-locator>, script-name), directory);
  log-debug("cgi-directory-responder: script = %s", as(<string>, script));
  if (file-exists?(script))
    serve-cgi-script(script, url, path-info: path-info);
  else
    resource-not-found-error(url: url)
  end;
end function cgi-directory-responder;

define method add-cgi-directory-responder
    (store :: type-union(<string-trie>, <http-server>),
     url :: <string>,
     directory :: <pathname>,
     #key request-methods :: false-or(<sequence>))
  add-responder(store, url,
                make-responder(list(request-methods | #(get:, post:),
                                    "^(?P<script-name>[^/]+)(?P<path-info>.*)$",
                                    curry(cgi-directory-responder,
                                          as(<directory-locator>, directory)))))
end;

// This may be registered explicitly for particular CGI scripts
// with add-cgi-script-responder.
define function cgi-script-responder
    (script :: <pathname>, #key path-info :: false-or(<string>))
  let request = current-request();
  // Just use the path, not the host, query, or fragment.
  let url = build-path(request.request-url);
  if (file-exists?(script))
    serve-cgi-script(script, url, path-info: path-info);
  else
    log-info("CGI script %s not found", url);
    resource-not-found-error(url: request.request-raw-url-string);  // 404
  end;
end function cgi-script-responder;

define method add-cgi-script-responder
    (store :: type-union(<string-trie>, <http-server>),
     url :: <string>,
     script :: <pathname>,
     #key request-methods :: false-or(<sequence>))
  add-responder(store, url,
                make-responder(list(request-methods | #(get:, post:),
                                    "^(?P<path-info>.*)$",
                                    curry(cgi-script-responder, script))))
end;

define method process-cgi-script-output
    (stdout :: <stream>, stderr :: <stream>)
  let request :: <request> = current-request();
  let response :: <response> = current-response();

  // Copy all headers that aren't CGI-specific to the response.
  let headers = read-message-headers(stdout, require-crlf?: #f);
  for (header-value keyed-by header-name in headers)
    if (~member?(header-name, $cgi-header-names, test: string-equal?))
      log-debug("  CGI passing header %s through to client", header-name);
      add-header(response, header-name, header-value);
    end;
  end;

  let status = get-header(headers, "Status");
  if (status)
    log-debug("  CGI processing Status header");
    response.response-code
      := block ()
           string-to-integer(status)
         exception (ex :: <serious-condition>)
           log-error("Error parsing Status header from CGI script: %s", status);
           response.response-code
         end;
  end;

  let location :: false-or(<string>) = get-header(headers, "Location");
  if (location)
    let target-url = parse-url(location);
    if (absolute?(target-url))
      redirect-to(target-url);
    else
      internal-redirect-to(location);
    end;
  else
    // The CGI script is generating the response body...
    // TODO: A more efficient copy-stream
    write(response, read-to-end(stdout));
  end;
end method process-cgi-script-output;

// Build a new request based on the given URL and the current request,
// and then invoke it.  (Of general use? Export?)
//
define method internal-redirect-to
    (url :: <string>, #key request-method = #"get")
  let request :: <request> = current-request();
  // Set various url-related slots in the request.
  parse-request-url(*server*, request, url);
  %invoke-handler(request, current-response());
end method internal-redirect-to;

define method make-cgi-environment
    (script :: <locator>, script-name :: <string>,
     #key path-info :: false-or(<string>))
 => (environment :: <string-table>)
  let request :: <request> = current-request();
  let env :: <string-table> = make(<string-table>);

  // Values are stored in env in the order they appear in RFC 3875...

  let authentication = get-header(request, "Authentication", parsed: #t);
  if (authentication)
    env["AUTH_TYPE"] := first(authentication);
  end;

  let content-length = get-header(request, "Content-Length", parsed: #t);
  if (content-length & content-length > 0)
    env["CONTENT_LENGTH"] := content-length;
  end;

  let content-type = get-header(request, "Content-Type", parsed: #f);
  if (content-type)
    env["CONTENT_TYPE"] := content-type;
  end;

  env["GATEWAY_INTERFACE"] := "CGI/1.1";

  if (path-info & ~empty?(path-info))
    env["PATH_INFO"] := path-info;
    // This is only correct if there's no responder registered for a
    // URL for which path-info is a prefix.  Should try to find such
    // a responder and not set this if one is found.
    env["PATH_TRANSLATED"]
      := as(<string>, merge-locators(as(<file-locator>, path-info),
                                     *virtual-host*.document-root));
  end;

  env["REMOTE_HOST"] := request.request-client.client-listener.listener-host;

  // TODO: this is incorrect if there are multiple network interfaces.
  env["REMOTE_ADDR"] := $local-host.host-address;
                        // The listener doesn't know its address yet...
                        //request.request-client.client-listener
                        //       .listener-address.numeric-host-address;

  // Not supported: REMOTE_IDENT

  // Not supported: REMOTE_USER

  env["REQUEST_METHOD"] := as-uppercase(as(<string>, request.request-method));
  env["SCRIPT_NAME"] := script-name;
  env["SERVER_NAME"] := request.request-host;
  env["SERVER_PORT"]
    := integer-to-string(request.request-client.client-listener.listener-port);
  env["SERVER_PROTOCOL"] := "HTTP/1.1";
  env["SERVER_SOFTWARE"] := request.request-server.server-header;
  
  env["QUERY_STRING"] := build-query(request.request-url);

  // Include some HTTP headers
  local method replace-dash (string)
          for (char in string, i from 0)
            if (char = '-')
              string[i] := '_';
            end;
          end;
          string
        end;
  for (header-value keyed-by header-name in request.raw-headers)
    unless (member?(header-name, *cgi-excluded-http-header-names*,
                    test: string-equal?)
              | member?(header-name, $cgi-header-names, test: string-equal?))
      let hdr-name = as-uppercase!(replace-dash(header-name));
      env[concatenate("HTTP_", hdr-name)] := header-value;
    end;
  end;
  env
end method make-cgi-environment;

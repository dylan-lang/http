Module: httpi
Synopsis:  CGI script handling
Author:    Carl Gay
Copyright: Copyright (c) 2009-2010 Carl L. Gay.  All rights reserved.
License:   Functional Objects Library Public License Version 1.0
Warranty:  Distributed WITHOUT WARRANTY OF ANY KIND

// I didn't really decide which one of these to support when I wrote
// this code.  --cgay
// CGI 1.1 specification: http://www.rfc-editor.org/rfc/rfc3875.txt
// CGI 1.2 specification draft: http://ken.coar.org/cgi/cgi-120-00a.html

define variable *debug-cgi?* :: <boolean> = #t;

define open class <cgi-script-resource> (<resource>)
  constant slot resource-locator :: <file-system-file-locator>,
    required-init-keyword: locator:;
end;

define method respond-to-post
    (resource :: <cgi-script-resource>, #key)
  let script = resource.resource-locator;
  let request = current-request();
  if (file-exists?(script))
    let script-name = request.request-url-path-prefix;
    let path-info = request.request-url-path-suffix;
    serve-cgi-script(script, script-name, path-info: path-info);
  else
    log-info("CGI script %s not found", as(<string>, script));
    resource-not-found-error();
  end;
end method respond-to-post;

define method respond-to-get
    (resource :: <cgi-script-resource>, #key)
  respond-to-post(resource);
end;

// Any file in the given directory that matches the given extensions will
// be treated as a CGI script.
//
define open class <cgi-directory-resource> (<resource>)
  constant slot resource-locator :: <directory-locator>,
    required-init-keyword: locator:;
  // Acceptable CGI script file extensions.  No other files will be served.
  constant slot resource-extensions :: <sequence> = #("cgi"),
    init-keyword: extensions:;
end;

// For convenience, convert the location: init arg to <directory-locator>
//
define method make
    (class :: subclass(<cgi-directory-resource>), #rest args, #key locator)
 => (resource :: <directory-resource>)
  apply(next-method, class,
        locator: as(<directory-locator>, locator),
        args)
end;

// Don't err if unmatched suffix remains
define method unmatched-url-suffix
    (resource :: <cgi-directory-resource>, suffix :: <sequence>)
end;

define method respond-to-post
    (resource :: <cgi-directory-resource>, #key)
  let request :: <request> = current-request();
  let suffix :: <string> = request.request-url-path-suffix;
  if (suffix.size > 0 & suffix[0] = '/')
    suffix := copy-sequence(suffix, start: 1);
  end;
  if (suffix.size = 0)
    forbidden-error();  // no directory listing allowed
  else
    block (return)
      // Find the script, possibly in a subdirectory.  (TODO: Should be configurable.)
      iterate loop (seen = #(),
                    remainder = split(suffix, '/'),
                    directory = resource.resource-locator)
        log-debug("loop(%=, %=, %=)", seen, remainder, as(<string>, directory));
        if (~empty?(remainder))
          let filename = first(remainder);
          let script = merge-locators(as(<file-locator>, filename), directory);
          if (file-exists?(script))
            select (script.file-type)
              #"file" =>
                let path-info = iff(empty?(rest(remainder)),
                                    "",
                                    // note added leading slash, per spec
                                    join(pair("", rest(remainder)), "/"));
                // The SCRIPT_NAME env var...
                let script-name = join(concatenate(list(request.request-url-path-prefix),
                                                   reverse!(seen),
                                                   list(filename)),
                                       "/");
                log-debug("cgi-directory-resource: filename = %=, script-name = %=, "
                          "path-info = %=, script = %=",
                          filename, script-name, path-info, as(<string>, script));
                serve-cgi-script(script, script-name, path-info: path-info);
                return();
              #"directory" =>
                loop(pair(filename, seen),
                     rest(remainder),
                     subdirectory-locator(directory, filename));
            end select;
          end;
        end;
      end iterate;
      resource-not-found-error();
    end block;
  end if;
end method respond-to-post;

define method respond-to-get
    (resource :: <cgi-directory-resource>, #key)
  respond-to-post(resource);
end;

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
  let handler <serious-condition>
    = method (cond, next-handler)
        log-error("  CGI terminated with error: %s", cond);
        log-debug("  CGI stdout = %s", %read-buffered-data(stdout));
        if (*debug-cgi?*)
          next-handler()
        end
      end;
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

define method process-cgi-script-output
    (stdout :: <stream>, stderr :: <stream>)
  let request :: <request> = current-request();
  let response :: <response> = current-response();

  // Copy all headers that aren't CGI-specific to the response.
  let headers = read-message-headers(stdout, require-crlf?: #f);
  for (header-value keyed-by header-name in headers)
    if (~member?(header-name, $cgi-header-names, test: string-equal?))
      log-debug("  CGI passing header %s through to client", header-name);
      set-header(response, header-name, header-value);
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
    // PATH_TRANSLATED seems to assume a single document root, which
    // we no longer support.
    //env["PATH_TRANSLATED"]
    //  := as(<string>, merge-locators(as(<file-locator>, path-info),
    //                                 *virtual-host*.document-root));
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

Module:    httpi
Author:    Carl Gay
Synopsis:  An API for generating responses to HTTP requests.
Copyright: See LICENSE in this distribution for details.


/*
Response buffering/chunking:

If the request is http/0.9 or http/1.0 then we buffer the entire response.
If the request is http/1.1 then by default we send with the "chunked" transfer
encoding, but the responder function may use

    response-chunked?(response) := #f

to turn off chunking.  It is an error to turn off chunking after the first
chunk has been sent.  If the response is completed before the first chunk has
been sent (i.e., before the response's chunk buffer fills up) then chunking
will not be used and instead a Content-Length header will be added before
sending the response in full.
*/

// It seems to me that chunk sizes should be fairly big these days.  If we
// have, say, 32 simultaneous connections and each one uses a 128KB chunk
// buffer we're only using 8MB mem.  But what's the average content length?
// One could imagine schemes to optimize it for different types of
// requests....  Perhaps also make it configurable, so one could tune the
// server for serving large files or small pages.
//
define constant $chunk-size :: <integer> = 16384;

// Exported
//
// This is a subclass of <string-stream> (rather than using a slot to
// hold an output stream) for two reasons:
// (1) Convenience: responder functions may write directly to the response
//     rather than having to access an output stream slot.
// (2) It allows us to intercept the writes in a context where we have
//     access to the response's data structures so we can write chunked
//     data to the socket if the chunk buffer is full.
//
// Would like to subclass <byte-string-stream>, but it's sealed.
//
// Not thread safe.  If you plan to have multiple threads writing to the
// response, do your own locking.
//
define open primary class <response> (<string-stream>, <base-http-response>)

  inherited slot stream-sequence
    = make(<byte-string>, size: $chunk-size, fill: ' ');

  // Transfer length as defined in RFC 2616, Section 4.4.
  // If this is > 0 then chunks have already been sent.
  //
  slot response-transfer-length :: <integer>,
    init-value: 0;

  // True if the headers have been sent.
  slot headers-sent? :: <boolean> = #f;

//  slot trailers-sent?

end class <response>;

define method initialize
    (response :: <response>, #rest args, #key direction = #"output")
  if (direction ~= #"output")
    error("<response> streams are output only.  You may not specify direction: %=",
          direction)
  end;
  apply(next-method, response, direction: #"output", args);
  if (member?(response.response-request.request-version,
              #[#"http/0.9", #"http/1.0"]))
    response-chunked?(response) := #f;
  end;
end method initialize;

// Implements part of the stream protocol.
//
define method write-element
    (response :: <response>, char :: <byte-character>)
 => ()
  // Let the method on <string-stream> do its thing.
  next-method();
  maybe-send-chunk(response);
end method write-element;
    

// Implements part of the stream protocol.
//
define method write
    (response :: <response>, chars :: <byte-string>,
     #key start: bpos = 0, end: epos)
 => ()
  // Let the method on <string-stream> do its thing.
  next-method();
  maybe-send-chunk(response);
end method write;

// Send a chunk if this is a chunked response and the chunk buffer is full.
// Note that if this is not a chunked response we do nothing, so the entire
// response is buffered.
define method maybe-send-chunk
    (response :: <response>)
  // response-chunked? returns #f if this is http/0.9 or http/1.0
  // or if the Content-Length header was set.
  if (response-chunked?(response) & response.stream-position >= $chunk-size)
    send-chunk(response);
  end;
end method maybe-send-chunk;

// This is only supposed to be called if there's data to be written.
// Otherwise it will write a zero-length chunk, which signals the end
// of the HTTP message.  
//
define method send-chunk
    (response :: <response>)
 => (byte-count :: <integer>)
  let socket :: <stream> = response.response-request.request-socket;
  if (~headers-sent?(response))
    set-header(response, "Transfer-encoding", "chunked", if-exists?: #"ignore");
    send-response-line(response, socket);
    send-headers(response, socket);
  end;

  let count :: <integer> = response.stream-size;
  let count-string = integer-to-string(count, base: 16);
  write(socket, count-string);
  write(socket, "\r\n");
  log-content(count-string);

  write(socket, response.stream-sequence, end: count);
  write(socket, "\r\n");
  if (*log-content?*)
    log-content(copy-sequence(response.stream-sequence, end: count));
  end;

  // Reset the response buffer.
  clear-contents(response);
  inc!(response.response-transfer-length, count);
  count
end method send-chunk;

define method send-response-line
    (response :: <response>, socket :: <tcp-socket>)
  let response-line = format-to-string("%s %d %s",
                                       $http-version, 
                                       response.response-code, 
                                       response.response-reason-phrase | "OK");
  log-trace("-->%=", response-line);
  write(socket, response-line);
  write(socket, "\r\n");
end method send-response-line;

// Exported
//
define method set-header
    (response :: <response>, header :: <byte-string>, value :: <object>,
     #key if-exists? = #"replace")
  if (headers-sent?(response))
    signal(make(<koala-api-error>,
                format-string: "Attempt to add a %s header after headers have "
                  "already been sent.",
                format-arguments: list(header)));
  elseif (string-equal?(header, "Content-Length"))
    if (response.response-transfer-length > 0)
      signal(make(<koala-api-error>,
                  format-string: "Attempt to add the Content-Length header "
                    "after some data has already been sent."));
    else
      // If a responder sets the content length then it's claiming it knows
      // better than we do.  We turn off chunked transfer encoding since it
      // doesn't allow a Content-Length header.
      response-chunked?(response) := #f;
    end;
    next-method()
  else
    next-method()
  end;
end method set-header;

define method send-header
    (socket :: <tcp-socket>, name :: <string>, val :: <pair>)
  for (v in val)
    send-header(socket, name, v)
  end;
end;

define method send-header
    (socket :: <tcp-socket>, name :: <string>, val :: <object>)
  format(socket, "%s: %s\r\n", name, val);
  %log-debug(*http-common-log*, "-->%s: %s", name, val);
end;

// TODO: This and the function by the same name in the client should be
//       moved into http-common.  (Probably just the stuff inside the
//       "unless" below, excluding headers-sent?.)
define method send-headers
    (response :: <response>, socket :: <tcp-socket>)
  unless (response.response-request.request-version == #"http/0.9")
    set-header(response, "Server", *server*.server-header);
    set-header(response, "Date", as-rfc1123-string(current-date()));

    let headers :: <header-table> = raw-headers(response);
    for (val keyed-by name in headers)
      send-header(socket, name, val);
    end;
    write(socket, "\r\n");  // blank line separates headers from body
    headers-sent?(response) := #t;
  end;
end method send-headers;


// Finish sending a response back to the client.  If the response is
// chunked we may have already sent the headers and some data.  Here
// we send any remaining buffered data and trailers if necessary.
// This is used for sending error responses as well as normal
// responses.  For error responses we can't assume there was a valid
// request.
//
define method finish-response
    (response :: <response>) => ()
  let request :: <request> = response.response-request;
  let socket :: <tcp-socket> = request.request-socket;
  let http-version :: <symbol> = request.request-version;
  let req-method :: <symbol> = request.request-method;
  let content-length :: <byte-string> = "0";

  if (response.response-transfer-length > 0)
    // Already sent headers and some chunks...
    let byte-count :: <integer> = send-chunk(response);
    if (byte-count > 0)
      // send empty chunk to terminate message
      send-chunk(response);
    end;
    content-length := integer-to-string(response.response-transfer-length);
  else
    // Not a chunked response...
    let rcode = response.response-code;
    // RFC 2616, 4.3
    let send-body? = ~((rcode >= 100 & rcode <= 199)
                       | rcode == 204  // no content
                       | rcode == $not-modified-redirect);
    unless (headers-sent?(response) | http-version == #"http/0.9")
      if (send-body?)
        content-length := integer-to-string(response.stream-size);
        set-header(response, "Content-Length", content-length);
      end;
      send-response-line(response, socket);
      send-headers(response, socket);
    end;

    if (send-body? & req-method ~== #"head")
      write(socket, response.stream-sequence, start: 0, end: response.stream-size);
      if (*log-content?*)
        log-content(copy-sequence(response.stream-sequence,
                                  start: 0,
                                  end: response.stream-size));
      end;
      // TODO: close connection if this is 0.9 (or 1.0?)
    end;
  end if;
  log-request(request, response.response-code, content-length);
end method finish-response;

define inline function log-request
    (req :: <request>, response-code :: <integer>, content-length :: <string>)
  // Log in Common Logfile Format
  // (http://www.w3.org/Daemon/User/Config/Logging.html)
  let request = concatenate(as-uppercase(as(<string>, request-method(req))),
                            " ",
                            // Can happen e.g. when client sends no data.
                            request-raw-url-string(req) | "-",
                            " ",
                            as-uppercase(as(<string>, req.request-version)));
  let date = as-common-logfile-date(current-date());
  let remoteaddr = host-address(remote-host(request-socket(req)));

  // TODO: make the logfile format configurable.  e.g., the user
  //       specifies a string like this:
  //   "{ip} {hostname} [{date}] '{url}' {user-agent} {referer}"
  // See bug #7200.

  let log-entry
    = concatenate(remoteaddr, " ",
                  "-", " ",
                  "-", " ",
                  "[", date, "] ",
                  "\"", request, "\" ",
                  integer-to-string(response-code), " ",
                  content-length,
                  // for now, add User-Agent and Referer
                  " \"", as(<string>, get-header(req, "referer") | "-"),
                  "\" \"", as(<string>, get-header(req, "user-agent") | "-"),
                  "\"");
  %log-info(*request-logger*, "%s", log-entry);
end function log-request;

// Exported
// Convenience.  Seems common to want to add a numeric cookie value.
//
define method add-cookie
    (response :: <response>, name :: <string>, value :: <integer>, #rest args,
     #key max-age, path, domain, comment)
  apply(add-cookie, response, name, integer-to-string(value), args)
end;

// Exported
// This isn't the right way to handle cookies, but it's simple for now.
// ---TODO: Verify that comment is a TOKEN or QUOTED-STRING, and that other
//          values are TOKENs.  See RFC 2109.
//
define method add-cookie
    (response :: <response>, name :: <string>, value :: <string>,
     #key max-age, path, domain, comment)
  set-header(response, "Set-cookie",
             with-output-to-string (s)
               format(s, "%s=%s; Version=%s", name, value, $default-cookie-version);
               max-age & format(s, "; Max-age=%s", max-age);
               path    & format(s, "; Path=%s", path);
               domain  & format(s, "; Domain=%s", domain);
               comment & format(s, "; Comment=\"%s\"", comment);
             end);
end method add-cookie;

// For convenience in responders, tags, named-methods, etc.
//
define function output
    (format-string, #rest format-args)
  apply(format, current-response(), format-string, format-args)
end;


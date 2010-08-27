Module: http-client-internals
Author: Carl Gay

/*

to-do list:

* Request pipelining.
* See todos in code below.
* (optional?) strict mode in which reads/writes signal an error if the
  chunk size is wrong or content length is wrong.  give the user a way
  to recover from the error.
* This code isn't currently designed to support an HTTP over anything
  other than a <tcp-socket>.  It does not support <ssl-socket>s. (It's
  also conceivable for there to be an <ipc-socket> class.)

Examples:

let conn = make(<http-connection>, host: host, port: port, ...);

// The simplest GET possible at this level.
// (GET is the default request method.  HTTP/1.1 is the default version.)
//
send-request(conn, "GET", "/status");
let response :: <http-response> = read-response(conn);
...content is in response.response-content...


// Read streaming data (e.g., if it's too big to buffer it all).
//
send-request(conn, "GET", "/status");
let response :: <http-response> = read-response(conn, read-content: #f);
...read(response, n)...


// POST form data.
// Content will be automatically encoded if it is a table.
// A Content-Type header will be added if not otherwise provided.
send-request(conn, "POST", "/form",
             content: encode-form-data(form-data));
...


// Send streaming data.
start-request(conn,  "PUT", "/huge-file.gz");
...write(conn, "foo")...
finish-request(conn);
let response = read-response(conn);


// Error handling
block ()
  send-request(conn, ...);
  let response = read-response(conn, ...);
exception (ex :: <resource-not-found-error>)
  ...
exception (ex :: <http-error>)
  ...last resort handler...
end;

close(conn);

// The plan is to allow content to be a stream, a string, a function,
// a table (for POST), etc.


*/

// This is bound to an <http-connection> for the duration of with-http-connection.
//
define thread variable *http-connection* :: false-or(<http-connection>) = #f;

// Logging is disabled by default.  Enable this to see what's going on.
// Set level to $trace-level to see all request/response content data.
//
define thread variable *http-client-log* :: <logger>
  = make(<logger>,
         name: "http.client",
         targets: list($stdout-log-target),
         level: $info-level);


// By the spec request methods are case-sensitive, but for convenience
// we let them be specified as symbols as well.  If a symbol is used it
// is uppercased before sending to the server.  Similarly for HTTP version.
//
define constant <request-method> = type-union(<symbol>, <byte-string>);
define constant <http-version> = type-union(<symbol>, <byte-string>);

// This error is signaled if the number of redirects exceeds n for n in
// http-get(conn, follow-redirects: n).
define open class <maximum-redirects-exceeded> (<http-error>)
end;

// For sending requests, an <http-connection> acts as the output stream so
// that it can do chunking etc.  But note that the request line and the headers
// are written directly to the socket so as to avoid chunking etc.
//
// For reading responses, the <http-connection> is used to create a response
// object and initialize it with the message headers and Status-Line data,
// after which one reads from the response object itself.
//
define open class <http-connection> (<basic-stream>)
  slot connection-socket :: <tcp-socket>;
  slot connection-host :: <string>;

  slot outgoing-chunk-size :: <integer>,
    init-value: 8192,
    init-keyword: outgoing-chunk-size:;

  slot connection-sent-headers :: false-or(<table>),
    init-value: #f;
  slot write-buffer :: <byte-string>;
  slot write-buffer-index :: <integer>,
    init-value: 0;
  // Number of bytes written so far for the current request message body only.
  slot message-bytes-written :: <integer>,
    init-value: 0;

end class <http-connection>;

define method initialize
    (conn :: <http-connection>, #rest socket-args, #key host :: <string>)
  next-method();
  conn.connection-socket := apply(make, <tcp-socket>,
                                  remove-keys(socket-args, outgoing-chunk-size:));
  conn.write-buffer := make(<byte-string>,
                             size: conn.outgoing-chunk-size, fill: ' ');

  // We store the GIVEN host name locally so we're not subject to the vaguaries
  // of the <tcp-socket> implementation.  The doc implies that it may be converted
  // to the canonical host name and we generally want to send Host headers with
  // the host name we were given by the user.  (The port number, on the other
  // hand, we can get from the socket.)
  conn.connection-host := host;
end method initialize;

define method connection-port
    (conn :: <http-connection>)
 => (port :: <integer>)
  conn.connection-socket.local-port
end method connection-port;

define method chunked?
    (conn :: <http-connection>)
 => (chunked? :: <boolean>)
  let sent-headers = conn.connection-sent-headers;
  sent-headers & ~get-header(sent-headers, "Content-Length")
end method chunked?;

// Override this to create a progress meter for sending request data.
// (Byte count is only for message body data, not headers, chunk wrappers, etc.)
// 
define open generic note-bytes-sent
    (conn :: <http-connection>, byte-count :: <integer>);

define method note-bytes-sent
    (conn :: <http-connection>, byte-count :: <integer>)
  // default method does nothing
end;


//////////////////////////////////////////
// Writing requests
//////////////////////////////////////////

// Start a request by sending the request line and headers.  The caller
// may then write the message body data to the connection and call finish-request.
// If you have a small amount of data to send you may want to use send-request
// instead.
define generic start-request
    (conn :: <http-connection>,
     request-method :: <request-method>,
     url :: type-union(<uri>, <string>),
     #key headers,
          standard-headers = #t,
          http-version :: <http-version>)
 => ();

// TODO: http-version ~= 1.1 not supported yet
//
define method start-request
    (conn :: <http-connection>,
     request-method :: <request-method>,
     url :: type-union(<uri>, <string>),
     #key headers,
          standard-headers = #t,
          http-version :: <http-version> = #"HTTP/1.1")
 => ()
  if (instance?(url, <string>))
    url := parse-uri(url);
  end;
  if (instance?(http-version, <string>))
    http-version := as(<symbol>, http-version);
  end;

  let headers = convert-headers(headers);
  if (standard-headers)
    // Add standard headers unless user has already set them.
    if (http-version = #"HTTP/1.1")
      // Host
      // uri-host should return #f, not "". :-(
      if (~get-header(headers, "Host"))
        set-header(headers, "Host", iff(empty?(uri-host(url)),
                                        conn.connection-host,
                                        uri-host(url)));
      end;
    end;
    // Always use Keep-alive when inside with-http-connection.  The connection
    // will be closed when with-http-connection exits.
    if (*http-connection* & ~element(headers, "Connection", default: #f))
      headers["Connection"] := "Keep-alive";
    end;

  end;

  // If the user set the content length explicitly, we trust them.
  // Otherwise the transfer is chunked.
  unless (get-header(headers, "Content-Length")
            | chunked-transfer-encoding?(headers))
    set-header(headers, "Transfer-Encoding", "chunked", if-exists?: #"ignore");
  end;

  let proxy? = #f;  // TODO: probably in the connection

  // Determine the URL string to send in the request line.  If using a proxy an
  // absolute URI is required, otherwise HTTP/1.1 clients MUST send an abs_path
  // (a.k.a. path-absolute) and send a Host header.
  let url-string = iff(proxy?,
                       build-uri(url),
                       build-uri(url, include-scheme: #f, include-authority: #f));

  send-request-line(conn, request-method, url-string, http-version);
  send-headers(conn, headers);
end method start-request;


define generic send-request
    (conn :: <http-connection>, request-method :: <request-method>,
     url :: type-union(<uri>, <string>),
     #rest start-request-args,
     #key content :: <byte-string>,
     #all-keys)
 => ();

define method send-request
    (conn :: <http-connection>, request-method :: <request-method>,
     url :: type-union(<uri>, <string>),
     #rest start-request-args,
     #key content :: <byte-string> = "",
          headers)
 => ()
  let headers = convert-headers(headers);
  if (~get-header(headers, "Content-Length")
        & ~chunked-transfer-encoding?(headers))
    set-header(headers, "Content-Length", integer-to-string(content.size));
  end;
  apply(start-request, conn, request-method, url,
        headers: headers, start-request-args);
  write(conn, content);
  finish-request(conn);
end method send-request;

define generic finish-request
    (conn :: <http-connection>)
 => ();

define method finish-request
    (conn :: <http-connection>)
 => ()
  if (conn.write-buffer-index > 0)
    send-write-buffer(conn);
  end;
  if (chunked?(conn))
    // zero-length chunk terminates message body
    send-chunk(conn);
  end;
end method finish-request;

// Send Request-Line = Method SP Request-URI SP HTTP-Version CRLF
// 
define method send-request-line
    (conn :: <http-connection>,
     request-method :: <request-method>,
     url :: type-union(<uri>, <byte-string>),
     http-version :: <http-version>)
  let req-meth = iff(~instance?(request-method, <string>),
                     as-uppercase(as(<byte-string>, request-method)),
                     request-method);
  format(conn.connection-socket, "%s %s %s\r\n",
         req-meth,
         // The client MUST omit the URI host unless sending to a proxy.
         // (Since we don't support proxies yet, the user can do this manually
         // by passing the url as a string.)
         iff(instance?(url, <uri>),
             build-uri(url, include-scheme: #f, include-authority: #f),
             url),
         iff(instance?(http-version, <symbol>),
             as-uppercase(as(<byte-string>, http-version)),
             http-version));
end method send-request-line;

// TODO: This and the function by the same name in the server should be
//       moved into http-common.
define method send-headers
    (conn :: <http-connection>, headers :: <table>)
  let stream :: <tcp-socket> = conn.connection-socket;
  for (header-value keyed-by header-name in headers)
    format(stream, "%s: %s\r\n", header-name, header-value);
  end;
  write(stream, "\r\n");
  conn.connection-sent-headers := headers;
end method send-headers;

define method write-element
    (conn :: <http-connection>, char :: <byte-character>)
 => ()
  if (conn.write-buffer-index = conn.write-buffer.size)
    send-write-buffer(conn);
  end;
  conn.write-buffer[conn.write-buffer-index] := char;
  inc!(conn.write-buffer-index);
end method write-element;

define method write
    (conn :: <http-connection>, string :: <byte-string>,
     #key start: bpos = 0, end: epos)
 => ()
  let epos :: <integer> = epos | string.size;
  let wbuff :: <byte-string> = conn.write-buffer;
  while (bpos < epos)
    let wpos :: <integer> = conn.write-buffer-index;
    if (wpos = wbuff.size)
      send-write-buffer(conn);
      wpos := conn.write-buffer-index;
    end;
    wbuff[wpos] := string[bpos];
    inc!(bpos);
    inc!(conn.write-buffer-index);
  end;
end method write;

define inline function send-write-buffer
    (conn :: <http-connection>)
  if (chunked?(conn))
    send-chunk(conn);
  else
    write(conn.connection-socket, conn.write-buffer,
          end: conn.write-buffer-index);
  end;
  conn.write-buffer-index := 0;
  note-bytes-sent(conn, conn.message-bytes-written);
end function send-write-buffer;

// Note that if the chunk is zero bytes long that signals the end of the
// HTTP message.
//
define function send-chunk
    (conn :: <http-connection>)
  let socket :: <tcp-socket> = conn.connection-socket;
  let count :: <integer> = conn.write-buffer-index;
  write(socket, integer-to-string(count, base: 16));
  write(socket, "\r\n");
  write(socket, conn.write-buffer, end: count);
  write(socket, "\r\n");
  inc!(conn.message-bytes-written, count);
end function send-chunk;


// Headers may be supplied to send-request in various forms for convenience.
// These methods on convert-headers all convert them to a <header-table>.

define method convert-headers
    (headers == #f)
  make(<header-table>)
end method convert-headers;

define method convert-headers
    (headers :: <sequence>)
  let new-headers = make(<header-table>);
  for (item in headers)
    let header-name :: <byte-string> = item[0];
    let header-value :: <byte-string> = item[1];
    new-headers[header-name] := header-value;
  end;
  new-headers
end method convert-headers;

// There is explicitly no method on <header-table> so that the table
// will be copied, since we have to modify it in send-request.

define method convert-headers
    (headers :: <table>)
  // Note the potential for duplicate headers to be dropped here.
  // We let it pass...
  let new-headers = make(<header-table>);
  for (header-value keyed-by header-name in headers)
    new-headers[header-name] := header-value;
  end;
  new-headers
end method convert-headers;


//////////////////////////////////////////
// Response
//////////////////////////////////////////

define open primary class <http-response>
    (<chunking-input-stream>, <base-http-response>)
  // Stores the content of the response, unless the user chose to read
  // streaming content from the response instead.
  slot response-content :: false-or(<byte-string>),
    init-value: #f,
    init-keyword: content:;
end class <http-response>;

define method make
    (class :: subclass(<http-response>), #rest args, #key connection, #all-keys)
 => (response :: <http-response>)
  apply(next-method, class, inner-stream: connection.connection-socket, args)
end;

// Read the status line and headers from the given connection and return an
// <http-response> object.  If "read-content" is true (the default) then the
// entire message body is read and stored in the response object.  Otherwise
// the stream is positioned to read the body of the response, which is the
// responsibility of the caller.
//
define open generic read-response
    (conn :: <http-connection>,
     #key read-content :: <boolean>,
          response-class :: subclass(<http-response>))
 => (response :: <http-response>);

// TODO: how to deal with "Connection: close"?  Close the socket and mark
//       the connection to be re-opened if subsequent requests are made on
//       it?  Return a 2nd value: conn-closed? :: <boolean> ?
define method read-response
    (conn :: <http-connection>,
     #rest args,
     #key read-content :: <boolean> = #t,
          response-class :: subclass(<http-response>) = <http-response>)
 => (response :: <http-response>)
  let socket :: <tcp-socket> = conn.connection-socket;
  let (http-version, status-code, reason-phrase) = read-status-line(socket);
  let headers :: <header-table> = read-message-headers(socket);
  let response = make(response-class,
                      connection: conn,
                      // TODO: add version to <http-response> class
                      http-version: http-version,
                      code: status-code,
                      reason-phrase: reason-phrase,
                      headers: headers);
  if (read-content
        & (status-code ~= 204 /* $status-code-no-content */))
    response.response-content := read-to-end(response);
  end;
  if (status-code >= 400)
    signal(make(condition-class-for-status-code(status-code),
                format-string: "%s",
                format-arguments: list(reason-phrase),
                code: status-code));
  else
    response
  end
end method read-response;

// Read the status line from the response.  Signal <internal-server-error>
// (code 500) if that status line is not valid.
//
// Status-Line = HTTP-Version SP Status-Code SP Reason-Phrase CRLF
//
define method read-status-line
    (stream :: <tcp-socket>)
 => (version :: <symbol>,
     status-code :: <integer>,
     reason-phrase :: <string>)
  let (buffer, eol) = read-http-line(stream);
  let epos1 = whitespace-position(buffer, 0, eol);
  let bpos2 = epos1 & skip-whitespace(buffer, epos1, eol);
  let epos2 = bpos2 & whitespace-position(buffer, bpos2, eol);
  let bpos3 = epos2 & skip-whitespace(buffer, epos2, eol);

  let version-string = epos1 & copy-sequence(buffer, end: epos1);
  let status-string = epos2 & copy-sequence(buffer, start: bpos2, end: epos2);
  let reason-phrase = bpos3 & copy-sequence(buffer, start: bpos3, end: eol);

  if (version-string & status-string & reason-phrase)
    let version :: <symbol> = validate-http-version(version-string);
    let status-code :: <integer> = validate-http-status-code(status-string);
    values(version, status-code, reason-phrase)
  else
    // The rationale for 500 here is that if the server sent us an incomplete
    // status line it is probably completely hosed.
    signal(make(<internal-server-error>,
                format-string: "Invalid status line in HTTP response: %=",
                format-arguments: list(copy-sequence(buffer, end: eol)),
                code: 500));
  end
end method read-status-line;


///////////////////////////////////////////
// Convenience APIs
///////////////////////////////////////////

define function make-http-connection
    (host-or-url, #rest initargs, #key port, #all-keys)
  let host = host-or-url;
  let port = port | $default-http-port;
  if (instance?(host, <uri>))
    let uri :: <uri> = host;
    host := uri-host(uri);
    if (empty?(host))
      error(make(<simple-error>,
                 format-string: "The URI provided to with-http-connection "
                   "must have a host component: %s",
                 format-arguments: list(build-uri(host))));
    end if;
    port := uri-port(uri) | port;
  end if;
  apply(make, <http-connection>, host: host, port: port, initargs)
end function make-http-connection;

// with-http-connection(conn = url) blah end;
// with-http-connection(conn = host, ...<http-connection> initargs...) blah end;
//
define macro with-http-connection
  { with-http-connection (?conn:name = ?host-or-url:expression, #rest ?initargs:*)
      ?:body
    end }
    => { let _conn = #f;
         block ()
           _conn := make-http-connection(?host-or-url, ?initargs);
           let ?conn = _conn;
           // Bind *http-connection* so that start-request knows it should add
           // a "Connection: Keep-alive" header if no Connection header is present.
           dynamic-bind (*http-connection* = _conn)
             ?body
           end;
         cleanup
           if (_conn)
             close(_conn, abort?: #t)
           end;
         end }
end macro with-http-connection;

// Do a complete HTTP GET request and response.
// Arguments:
//   url - The URL to get.
//   headers - Any additional headers to send with the request.  The same headers
//     are sent in subsequent requests if redirects are followed.
//   stream - A stream on which to output the response message body.  This is useful
//     when an extremely large response is expected.  If not provided, then the
//     response message body is stored in the returned response object.
//   follow-redirects - If #f, then don't follow redirects.  This is allowed in order
//     to simplify the caller.  If #t, then follow an indefinite number of redirects.
//     If 0, then raise <maximum-redirects-exceeded>.  If > 0, follow that many
//     redirects.
// Values:
//   An <http-response> object.
define open generic http-get
    (url :: <object>, #key headers, follow-redirects, stream)
 => (response :: <http-response>);

define method http-get
    (url :: <byte-string>, #key headers, follow-redirects, stream)
 => (response :: <http-response>)
  http-get(parse-uri(url),
           headers: headers,
           follow-redirects: follow-redirects,
           stream: stream)
end method http-get;

define method http-get
    (url :: <uri>,
     #key headers,
          follow-redirects :: type-union(<boolean>, <nonnegative-integer>),
          stream :: false-or(<stream>))
 => (response :: <http-response>)
  with-http-connection(conn = url)
    let headers = convert-headers(headers);
    let original-headers = convert-headers(headers);  // copy

    iterate loop (follow = follow-redirects, url = url)
      send-request(conn, #"get", url, headers: original-headers);
      let read-content? = ~stream;
      let response :: <http-response> = read-response(conn, read-content: #f);
      let code = response.response-code;
      if (follow & code >= 300 & code <= 399)
        // Discard the body of the redirect message.
        read-and-discard-to-end(response);
        if (follow = 0)
          signal(make(<maximum-redirects-exceeded>,
                      format-string: "Maximum number of redirects exceeded."));
        else
          loop(iff(follow = #t, #t, follow - 1),
               get-header(response, "Location"))
        end
      else
        if (stream)
          copy-message-body-to-stream(response, stream);
        else
          response.response-content := read-to-end(response);
        end;
        response
      end
    end iterate
  end with-http-connection
end method http-get;

// does something like this exist already?
define method copy-message-body-to-stream
    (response :: <http-response>, to-stream :: <stream>)
  let buffer :: <byte-string> = make(<byte-string>, size: 8192);
  block (return)
    while (#t)
      let count = read-into!(response, 8192, buffer);
      log-trace(*http-client-log*, "Read %s elements", count);
      if (count = 0)
        return();
      else
        write(to-stream, buffer, end: count);
      end;
    end;
  exception (ex :: <incomplete-read-error>)
    write(to-stream, ex.stream-error-sequence, end: ex.stream-error-count);
  exception (ex :: <end-of-stream-error>)
    // pass
  end;
end method copy-message-body-to-stream;

define method read-and-discard-to-end
    (response :: <http-response>)
  let buff-size :: <integer> = 16384;
  let buffer :: <byte-string> = make(<byte-string>, size: buff-size);
  let count = buff-size;
  while (count)
    count := read-into!(response, buff-size, buffer, on-end-of-stream: #f);
  end;
end method read-and-discard-to-end;


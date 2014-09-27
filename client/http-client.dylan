Module: http-client-internals
Author: Carl Gay
Copyright: See LICENSE in this distribution for details.

/*

TODO:

* Query parameters should be left entirely to the uri library.  Here we only
  care about getting a URI and sending it along in a request.
* Request pipelining.
* See todos in code below.
* Optional strict mode in which reads/writes signal an error if the
  chunk size is wrong or content length is wrong.  Give the user a way
  to recover from the error.
* This code isn't currently designed to support HTTP over anything
  other than a <tcp-socket>.  It does not support <ssl-socket>s. (It's
  also conceivable for there to be an <ipc-socket> class.)

*/

define constant $default-http-port :: <integer> = 80;
define constant $default-https-port :: <integer> = 443;

define constant <uri-or-string> = type-union(<uri>, <string>);
define constant <follow-redirects> = type-union(<boolean>, <nonnegative-integer>);

// This is bound to an <http-connection> for the duration of with-http-connection.
//
define thread variable *http-connection* :: false-or(<http-connection>) = #f;

// Logging is disabled by default.  Enable this to see what's going on.
// Set level to $trace-level to see all request/response content data.
//
define thread variable *http-client-log* :: <log>
  = make(<log>,
         name: "http.client",
         targets: list($stdout-log-target),
         level: $info-level);


// This error is signaled if the number of redirects exceeds n for n in
// http-request(..., follow-redirects: n, ...).
define open class <maximum-redirects-exceeded> (<http-error>)
end;

define open class <redirect-loop-detected> (<http-error>)
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

  slot outgoing-chunk-size :: <integer> = 8192,
    init-keyword: outgoing-chunk-size:;

  slot connection-sent-headers :: false-or(<table>) = #f;
  slot write-buffer :: <byte-string>;
  slot write-buffer-index :: <integer> = 0;
  // Number of bytes written so far for the current request message body only.
  slot message-bytes-written :: <integer> = 0;

end class <http-connection>;

define method initialize
    (conn :: <http-connection>, #rest socket-args, #key host :: <string>)
  next-method();
  conn.connection-socket := apply(make, <tcp-socket>,
                                  remove-keys(socket-args, outgoing-chunk-size:));
  conn.write-buffer := make(<byte-string>,
                             size: conn.outgoing-chunk-size, fill: ' ');

  // We store the GIVEN host name locally so we're not subject to the vagaries
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
     url :: <uri-or-string>,
     #key headers,
          standard-headers = #t,
          http-version :: <http-version>)
 => ();

// TODO: http-version ~= 1.1 not supported yet
//
define method start-request
    (conn :: <http-connection>,
     request-method :: <request-method>,
     url :: <uri-or-string>,
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

  send-request-line(conn, request-method, url, http-version);
  send-headers(conn, headers);
end method start-request;


define generic send-request
    (conn :: <http-connection>, request-method :: <request-method>,
     url :: <uri-or-string>,
     #rest start-request-args,
     #key content :: <byte-string>,
     #all-keys)
 => ();

define method send-request
    (conn :: <http-connection>, request-method :: <request-method>,
     url :: <uri-or-string>,
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
     uri :: <uri>,
     http-version :: <http-version>)
  let proxy? = #f;  // TODO: probably in the connection

  // Determine the URL string to send in the request line.  If using a proxy an
  // absolute URI is required, otherwise HTTP/1.1 clients MUST send an abs_path
  // (a.k.a. path-absolute) and send a Host header.
  let uri-string = iff(proxy?,
                       build-uri(uri),
                       build-uri(uri, include-scheme: #f, include-authority: #f));
  // https://github.com/dylan-lang/http/issues/2
  // http://tools.ietf.org/html/rfc7230#section-5.3
  if (empty?(uri.uri-path))
    uri-string := concatenate("/", uri-string);
  end;
  let req-meth = iff(instance?(request-method, <string>),
                     request-method,
                     as-uppercase(as(<byte-string>, request-method)));
  format(conn.connection-socket, "%s %s %s\r\n",
         req-meth, uri-string,
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
    (headers == #f) => (headers :: <header-table>)
  make(<header-table>)
end method convert-headers;

define method convert-headers
    (headers :: <sequence>) => (headers :: <header-table>)
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
    (headers :: <table>) => (headers :: <header-table>)
  // Note the potential for duplicate headers to be dropped here.
  // We let it pass...
  let new-headers = make(<header-table>);
  for (header-value keyed-by header-name in headers)
    new-headers[header-name] := header-value;
  end;
  new-headers
end method convert-headers;

define method convert-parameters
    (parameters == #f) => (params :: <string-table>)
  make(<string-table>)
end method convert-parameters;

define method convert-parameters
    (parameters :: <string-table>) => (params :: <string-table>)
  parameters
end method convert-parameters;

// The HTML spec section 17.13.4 says to escape the reserved characters, then
// convert spaces to '+'.
//
// TODO(cgay): This probably belongs in the uri library?  If $uri-pchar
// continues to be exported it needs a better name.
define constant $http-form :: <byte-string> = concatenate($uri-pchar, " /?");

define method form-encode
    (unencoded :: <byte-string>)
 => (encoded :: <string>)
  let encoded = percent-encode($http-form, unencoded);
  for (char in encoded, i from 0)
    if (char = ' ') encoded[i] := '+' end;
  end;
  encoded
end method form-encode;

define method build-urlencoded-form
    (form :: <string-table>)
 => (encoded-form :: <string>)
  let parts = make(<stretchy-vector>);
  for (value keyed-by key in form)
    let encoded-value = form-encode(value);
    let encoded-key = form-encode(key);
    add!(parts, concatenate(encoded-key, "=", encoded-value));
  end for;
  join(parts, "&")
end method build-urlencoded-form;

// Content can be of different types, these methods convert them all
// to <byte-string>.
// convert-content needs the request headers to change its content-type.
//
// TODO(cgay): IMO this is too much magic.  Callers should just use
// build-urlencoded-form(content) if needed.

define method convert-content
    (content :: <string-table>, #key headers :: <header-table>)
  headers["Content-Type"] := "application/x-www-form-urlencoded";
  build-urlencoded-form(content);
end method convert-content;

define method convert-content
    (content == #f, #key headers)
  ""
end method convert-content;

define method convert-content
    (content :: <byte-string>, #key headers)
  content
end method convert-content;

//////////////////////////////////////////
// Response
//////////////////////////////////////////

define open primary class <http-response>
    (<chunking-input-stream>, <base-http-response>, <message-headers-mixin>)
  // Stores the content of the response, unless the user chose to read
  // streaming content from the response instead.
  slot response-content :: false-or(<byte-string>) = #f,
    init-keyword: content:;
end class <http-response>;

define method make
    (class :: subclass(<http-response>), #rest args, #key connection, #all-keys)
 => (response :: <http-response>)
  apply(next-method, class, inner-stream: connection.connection-socket, args)
end;

// Read the status line and headers from the given connection and return an
// <http-response>.  If "read-content" is true (the default) then the
// entire message body is read and stored in the response.  Otherwise
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
  if (read-content & (status-code ~= $status-no-content))
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
  // It's convenient to be able to use a string for the URL.
  if (instance?(host, <string>) & any?(member?(_, host), "/:"))
    host := parse-url(host);
  end;
  if (instance?(host, <uri>))
    let uri :: <uri> = host;
    host := uri-host(uri);
    if (empty?(host))
      error("The URI provided, %s, must have a host component.",
            build-uri(uri));
    end if;
    port := port | uri.uri-port;
    if (~port)
      // TODO(cgay): The uri library should supply port defaults for schemes
      // that specify it, so we don't have to do this here.
      select (uri.uri-scheme by  string-equal-ic?)
        "http", "" => port := $default-http-port;
        "https"    => port := $default-https-port;
        otherwise => error("The URI provided, %s, must be an http or https URI.",
                           build-uri(uri));
      end;
    end;
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
  block ()
    while (#t)
      read-into!(response, buff-size, buffer);
    end;
  exception (ex :: <end-of-stream-error>)
    // done
  end;
end method read-and-discard-to-end;

// Do a complete HTTP request and response.
// Arguments:
//   request-method - The HTTP method for the request.
//   url - The URL for the request.
//   headers - Any additional headers to send with the request.  The same headers
//     are sent in subsequent requests if redirects are followed.
//   parameters - Query values to send in the request URI.  <string-table>
//   content - Content to send in the body of the request.  <string-table> is sent
//     as application/x-www-form-urlencoded body, others sent with standard encoding.
//   follow-redirects
//     #f => don't follow redirects.
//     #t => follow an indefinite number of redirects.
//     n => follow n redirects but signal <maximum-redirects-exceeded> after that.
//   stream - A stream on which to output the response message body.  This is useful
//     when an extremely large response is expected.  If not provided, then the
//     response message body is copied into the response-content slot of the returned
//     response.
// Values:
//   An <http-response>.
//
// TODO(cgay): Rename stream to output-stream for clarity.
// TODO(cgay): Allow content to be an input stream.
define sealed generic http-request
    (request-method :: <request-method>, url :: <object>,
     #key headers,
          parameters,
          content,
          follow-redirects,
          stream)
 => (response :: <http-response>);

define method http-request
    (request-method :: <request-method>, uri :: <string>,
     #key headers,
          parameters,
          content,
          follow-redirects,
          stream)
 => (response :: <http-response>)
  http-request(request-method, parse-url(uri),
               headers: headers,
               parameters: parameters,
               content: content,
               follow-redirects: follow-redirects,
               stream: stream)
end method http-request;

define method http-request
    (request-method :: <request-method>, uri :: <uri>,
     #key headers,
          parameters :: false-or(<string-table>),
          content,
          follow-redirects :: <follow-redirects> = #t,
          stream :: false-or(<stream>))
 => (response :: <http-response>)
  let headers = convert-headers(headers);
  let url = transform-uris(uri, make(<url>, query: convert-parameters(parameters)));
  with-http-connection(conn = url)
    iterate loop (follow = follow-redirects, url = url, seen = #())
      send-request(conn, request-method, url,
                   headers: headers,
                   content: convert-content(content, headers: headers));

      let response :: <http-response> = read-response(conn, read-content: #f);
      let code = response.response-code;
      if (follow & code >= 300 & code <= 399)
        // Discard the body of the redirect message.
        read-and-discard-to-end(response);
        let location = get-header(response, "Location");
        if (follow = 0)
          signal(make(<maximum-redirects-exceeded>,
                      format-string: "Maximum number of redirects (%d) exceeded.",
                      format-arguments: list(follow-redirects)));
        elseif (member?(location, seen, test: string-equal?))
          // RFC 2616, 10.3
          signal(make(<redirect-loop-detected>,
                      format-string: "Redirect loop detected: %s",
                      format-arguments: list(location)));
        else
          loop(iff(follow = #t, #t, follow - 1),
               location,
               pair(location, seen))
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
end method http-request;

define constant http-get     = curry(http-request, "GET");
define constant http-post    = curry(http-request, "POST");
define constant http-put     = curry(http-request, "PUT");
define constant http-options = curry(http-request, "OPTIONS");
define constant http-head    = curry(http-request, "HEAD");
define constant http-delete  = curry(http-request, "DELETE");

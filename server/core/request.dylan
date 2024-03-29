Module:    httpi
Synopsis:  HTTP requests
Author:    Gail Zacharias, Carl Gay
Copyright: See LICENSE in this distribution for details.


define open primary class <request>
    (<chunking-input-stream>, <base-http-request>)

  slot request-method :: false-or(<http-method>) = #f,
    init-keyword: method:;

  constant slot request-client :: <client>,
    required-init-keyword: client:;

  // Contains the part of the URL path that matched the <resource>.
  slot request-url-path-prefix :: <string>;

  // Contains part of the URL path following the prefix (above).
  // If the requested URL was /foo/bar/baz and /foo/bar matched the
  // resource, then this would be "/baz".
  slot request-url-path-suffix :: <string>;

  // See http://www.w3.org/Protocols/rfc2616/rfc2616-sec5.html#sec5.2
  slot request-host :: false-or(<string>) = #f;

  // Query values from either the URL or the body of the POST, if Content-Type
  // is application/x-www-form-urlencoded or multipart/form-data. Values are
  // strings, #t, or lists of either. See get-query-value(s) and uri:uri:split-query.
  constant slot request-query-values :: <string-table>,
    init-function: curry(make, <string-table>);

  slot request-keep-alive? :: <boolean> = #f;

  slot request-session :: false-or(<session>) = #f;

end class <request>;

// Pass along the socket as the inner-stream for <chunking-input-stream>,
// which is a <wrapper-stream>.
//
define method make
    (class :: subclass(<request>), #rest args, #key client :: <client>, #all-keys)
 => (request :: <request>)
  apply(next-method, class, inner-stream: client.client-socket, args)
end;

define inline function request-socket
    (request :: <request>)
 => (socket :: <tcp-socket>)
  request.request-client.client-socket
end;

define inline function request-client-address
    (request :: <request>)
 => (address :: <string>)
  request.request-socket.remote-host.host-address
end;

define inline function request-server
    (request :: <request>)
 => (server :: <http-server>)
  request.request-client.client-server
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

// This method takes care of parsing the request headers and signalling any
// errors therein.
//---TODO: have overall timeout for header reading.
define method read-request
    (request :: <request>) => ()
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
    let (new-buffer, new-len) = read-http-line(socket);
    buffer := new-buffer;
    len := new-len;
  end;

  parse-request-line(server, request, buffer, len);
  log-debug("Received request line: %s %s %s",
            request.request-method,
            request.request-raw-url-string,
            request.request-version);
  read-headers!(socket, buffer, request.raw-headers);
  process-incoming-headers(request);
  // Unconditionally read all request content in case we need to process
  // further requests on the same connection.  This is temporary and needs
  // to be handled with more finesse.
  read-request-content(request);
  process-request-content(request, request-content-type(request));
end method read-request;

// Parse the Request-Line and modify the request appropriately.
define function parse-request-line
    (server :: <http-server>, request :: <request>,
     buffer :: <string>, eol :: <integer>)
 => ()
  let (http-method, raw-url, http-version) = parse-request-line-values(buffer, eol);
  let url = parse-url(raw-url);
  request.request-method := http-method;
  request.request-raw-url-string := raw-url;
  request.request-url := url;
  request.request-version := http-version;
  // RFC 2616, 5.2 -- absolute URLs in the request line take precedence
  // over Host header.
  if (absolute?(url))
    request.request-host := url.uri-host;
  end;
  remove-all-keys!(request.request-query-values);  // appears unnecessary
  if (url.uri-query)
    for (value keyed-by key in url.uri-query)
      // TODO: what should happen with duplicate keys? For form data all values
      // for the key are retained but here we overwrite.
      request.request-query-values[key] := value;
    end;
  end;
end function parse-request-line;

// RFC 2616 Section 5.1
//      Request-Line   = Method SP Request-URI SP HTTP-Version CRLF
define function parse-request-line-values
    (buffer :: <byte-string>, eol :: <integer>)
 => (http-method :: <http-method>,
     raw-url :: <byte-string>,
     http-version :: <byte-string>)
  let epos1 = whitespace-position(buffer, 0, eol);
  let bpos2 = epos1 & skip-whitespace(buffer, epos1, eol);
  let epos2 = bpos2 & whitespace-position(buffer, bpos2, eol);
  let bpos3 = epos2 & skip-whitespace(buffer, epos2, eol);
  let epos3 = bpos3 & whitespace-position(buffer, bpos3, eol) | eol;
  // We reject requests with spaces in the URL.  We may issue a redirect to the
  // URL with spaces URL-encoded, according to the spec, but this is also valid.
  // Also reject more than one space between parts.
  if (~bpos3 | (epos3 ~== eol) | (bpos2 - epos1 > 1) | (bpos3 - epos2 > 1))
    bad-request-error(reason: "Invalid request line");
  else
    let http-method = validate-http-method(substring(buffer, 0, epos1));
    let http-version = validate-http-version(substring(buffer, bpos3, epos3));
    let raw-url = substring(buffer, bpos2, epos2);
    values(http-method, raw-url, http-version)
  end
end function parse-request-line-values;


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
end function read-request-content;

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
end function request-content-type;


// Gary, in the trunk sources (1) below should now be fixed.  (read was passing the
// wrong arguments to next-method).
// (2) should also be fixed.  It used to cause "Dylan error: 35 is not of type {<class>: <sequence>}"
// But, if you pass on-end-of-stream: #"blah" and then arrange to close the stream somehow
// you'll get an invalid return type error.
// Uncomment either (1) or (2) and comment out the "let n ..." and "assert..." below and
// then start http-server-demo, go to http://localhost:7020/foo/bar/form.html and
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
  // No special processing for this content type.
end;

define method process-request-content
    (request :: <request>, content-type == #"application/x-www-form-urlencoded")
  // By the time we get here request-query-values has already
  // been bound to a <string-table> containing the URL query
  // values. Now we augment it with any form values.
  let content :: <byte-string> = request-content(request);
  for (i from 0, char in content)
    if (char == '+')
      content[i] := ' ';
    end;
  end;
  let parsed-query = split-query(content);
  for (value keyed-by key in parsed-query)
    request.request-query-values[key] := value;
  end for;
  // ---TODO: Deal with content types intelligently.
  // For now this'll have to do.
end method;

// Augment the current request-query-values with the values in the
// multipart/form-data body.
//
// https://tools.ietf.org/html/rfc2046#section-5.1 -- Multipart Media Type
// https://tools.ietf.org/html/rfc7578 -- Returning Values from Forms: multipart/form-data
//
// This code is in no way complete or optimized; it is enough to get
// play.opendylan.org working. There is much unnecessary string copying.
define method process-request-content
    (request :: <request>, content-type == #"multipart/form-data")
  local method fail (msg :: <string>)
          bad-request-error(reason: msg);
        end;
  // By the time we get here request-query-values has already been bound to a
  // <string-table> containing the URL query values.
  let header :: <media-type> = get-header(request, "Content-Type", parsed: #t);
  let boundary
    = get-attribute(header, "boundary")
        | fail("'Content-Type: multipart/form-data' missing 'boundary' parameter");
  if (boundary.size == 0 | boundary.size > 70)
    fail("multipart/form-data boundary size must be 1-70 characters");
  end;
  boundary := concatenate("--", boundary); // inefficient

  let content :: <byte-string> = request.request-content;
  let parts = split(content, boundary, remove-if-empty?: #t);
  let qvalues = request.request-query-values;
  let headers = make(<header-table>);
  let buffer = make-header-buffer();
  for (part in parts,
       while: ~starts-with?(part, "--"))
    // Each part should begin and end with CRLF. The initial CRLF is technically the
    // terminator for the boundary line but we're not really processing this by lines.
    if (~starts-with?(part, "\r\n"))
      fail("invalid multipart/form-data boundary -- no trailing CRLF");
    end;
    if (~ends-with?(part, "\r\n"))
      fail("invalid multipart/form-data -- no CRLF at end of part");
    end;
    let epos = with-input-from-string (stream = part, start: 2, end: part.size - 2)
                 remove-all-keys!(headers);
                 read-headers!(stream, buffer, headers);
               end;
    // TODO: handle different content-types, charsets, transfer encodings.

    let disposition :: <avalue>
      = get-header(headers, "Content-Disposition", parsed: #t)
          | fail("multipart/form-data missing 'Content-Disposition' header");
    let name = element(disposition, "name", default: #f)
                 | fail("multipart/form-data missing 'name' parameter");
    let form-value = copy-sequence(part, start: epos, end: part.size - 2);
    let val = element(qvalues, name, default: #f);
    qvalues[name] := case
                       ~val => form-value;
                       instance?(val, <string>) => list(val, form-value);
                       otherwise => pair(form-value, val); // val is a list
                     end;
  end for;
end method;

// Do whatever we need to do depending on the incoming headers for
// this request.  e.g., handle "Connection: Keep-alive", store
// "User-agent" statistics, etc.
//
define method process-incoming-headers
    (request :: <request>)
  let conn-values :: <sequence> = get-header(request, "Connection", parsed: #t) | #();
  if (member?("close", conn-values, test: string-equal-ic?))
    request-keep-alive?(request) := #f;
  elseif (member?("keep-alive", conn-values, test: string-equal-ic?))
    request-keep-alive?(request) := #t;
  end;
  let host/port = get-header(request, "Host", parsed: #t);
  let host = host/port & head(host/port);
  let port = host/port & tail(host/port);
  if (~host & request.request-version == #"HTTP/1.1")
    // RFC 2616, 19.6.1.1 -- HTTP/1.1 requests MUST include a Host header.
    bad-request-error(reason: "HTTP/1.1 requests must include a Host header");
  end;
  // RFC 2616, 5.2 -- If request host is already set then there was an absolute
  // URL in the request line, which takes precedence, so ignore Host header here.
  if (host & ~request.request-host)
    request.request-host := host;
  end;
end method;

define inline function empty-line?
    (buffer :: <byte-string>, len :: <integer>) => (empty? :: <boolean>)
  len == 1 & buffer[0] == $cr
end;

// Hey look!  More stuff to get rid of or move...

// Query values are
//   * URL parameters
//   * multipart/form-data body content
//   * application/x-www-form-urlencoded body content

// get-query-value returns the first value for `key`. Use get-query-values if
// you want a vector of all the values for that key. For example, form data for
// multiple files uploaded under the same key.
define inline function get-query-value
    (key :: <string>, #key as: as-type :: false-or(<type>))
 => (value :: <object>)
  let val = element(*request*.request-query-values, key, default: #f);
  let val = if (instance?(val, <list>) & ~empty?(val))
              head(val)
            else
              val
            end;
  if (as-type & instance?(val, <string>))
    as(as-type, val)
  else
    val
  end
end function get-query-value;

define inline function get-query-values (key :: <string>) => (values :: <sequence>)
  let v = element(*request*.request-query-values, key, default: #f);
  select (v by instance?)
    <list> => v;
    singleton(#f) => #();
    otherwise => list(v);
  end
end function;

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


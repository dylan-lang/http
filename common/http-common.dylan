Module: http-common-internals
Synopsis: Code shared by HTTP client and server.
Copyright: See LICENSE in this distribution for details.


define constant $http-version :: <byte-string> = "HTTP/1.1";

define constant $default-http-port :: <integer> = 8000;

define constant $default-https-port :: <integer> = 8443;


// By the spec request methods are case-sensitive, but for convenience
// we let them be specified as symbols as well.  If a symbol is used it
// is uppercased before sending to the server.  Similarly for HTTP version.
//
define constant <request-method> = type-union(<symbol>, <byte-string>);
define constant <http-version> = type-union(<symbol>, <byte-string>);

// Clients can bind this if they want to combine this library's logs with
// there own.  Adding a log target to the default value here doesn't work
// for the HTTP server, which wants to log to different targets for different
// virtual hosts.  If they don't care about that they can just remove the
// default target and add their own.
//
// Message headers are logged at debug level and message content is logged
// at trace level.
//
define thread variable *http-common-log* :: <logger>
  = make(<logger>,
         name: "http.common",
         targets: list($stdout-log-target),
         level: $info-level);


/////////////// Parsing //////////////

// RFC 2616, 2.2
define constant $token-character-map
  = begin
      let vec = make(<vector>, size: 128, fill: #t);
      let separator-chars = "()<>@,;:\\\"/[]?={} \t";
      for (char in separator-chars)
        vec[as(<integer>, char)] := #f;
      end;
      // US ASCII control characters...
      for (code from 0 to 32)
        vec[code] := #f;
      end;
      vec[127] := #f;   // DEL
      vec
    end;

define inline function token-char?
    (char :: <byte-character>) => (token-char? :: <boolean>)
  let code :: <integer> = as(<integer>, char);
  code <= 127 & $token-character-map[code]
end;

define inline function non-token-char?
    (char :: <byte-character>) => (non-token-char? :: <boolean>)
  ~token-char?(char)
end;

define function token-end-position (buf :: <byte-string>,
                                    bpos :: <integer>,
                                    epos :: <integer>)
  char-position-if(non-token-char?, buf, bpos, epos)
end;

define method validate-http-version
    (version :: <string>)
 => (version :: <symbol>)
  if (version.size ~= 8
        | ~starts-with?(version, "HTTP/")
        | ~decimal-digit?(version[5])
        | ~decimal-digit?(version[7]))
    bad-request-error(reason: "Invalid HTTP version")
  else
    // Take care not to intern arbitrary symbols...
    select (version by string-equal?)
      "HTTP/0.9" => #"HTTP/0.9";
      "HTTP/1.0" => #"HTTP/1.0";
      "HTTP/1.1" => #"HTTP/1.1";
      otherwise =>
        http-version-not-supported-error(version: version);
    end select
  end if
end method validate-http-version;

define method validate-http-status-code
    (status-code :: <string>)
 => (status-code :: <integer>)
  let code = string-to-integer(status-code, default: -1);
  if (code < 100 | code > 599)
    signal(make(<internal-server-error>,
                format-string: "Invalid HTTP status code: %=",
                format-arguments: list(status-code),
                code: 500));
  else
    code
  end
end method validate-http-status-code;


///////////// Chunking input streams ///////////////
//
// Handles reading chunked (or non-chunked) HTTP message bodies

define variable *debug-reads?* = #f;

define constant $read-buffer-size :: <integer> = 8192;

define open class <chunking-input-stream> (<wrapper-stream>)

  slot read-buffer :: <byte-string>
    = make(<byte-string>, size: $read-buffer-size);

  // This init value causes refill-read-buffer to be called the first time
  // anything is read from the stream.
  slot read-buffer-index :: <integer> = $read-buffer-size;

  // Number of bytes read from the inner stream so far, for the current
  // message body only.  Does not include chunk encoding bytes.
  slot message-bytes-read :: <integer> = 0;

  // If this is non-negative it holds the index of the final element of the
  // message body + 1 in read-buffer.  If it's negative it means the entire
  // read-buffer is valid data.  This is reset once the EOF is reported.
  slot %eof-position :: <integer> = -1;

end class <chunking-input-stream>;

// Subclasses must implement a method on this gf. It should look at the headers
// and return #f if the body is chunked and an integer if the content-length
// is known.  One way to implement it is to also subclass <message-headers-mixin>.
//
define open generic content-length
    (object :: <object>)
 => (length :: false-or(<integer>));

// Override this to create a progress meter for receiving message data.
// byte-count is the number of NEW bytes received since last time this method
// was called.  The byte count only includes the message body, not headers,
// chunk wrappers, etc.
//
define open generic note-bytes-received
    (stream :: <chunking-input-stream>, byte-count :: <integer>);

define method note-bytes-received
    (stream :: <chunking-input-stream>, byte-count :: <integer>)
  // default method does nothing
end;

define inline-only function initial-state?
    (stream :: <chunking-input-stream>) => (initial-state? :: <boolean>)
  stream.message-bytes-read = 0 & stream.%eof-position = -1
end;

define method stream-at-end?
    (stream :: <chunking-input-stream>) => (at-end? :: <boolean>)
  stream.%eof-position = stream.read-buffer-index
end method stream-at-end?;

define inline-only function maybe-refill-read-buffer
    (stream :: <chunking-input-stream>)
  if (initial-state?(stream)
        | stream.read-buffer-index = stream.read-buffer.size)
    refill-read-buffer(stream);
  end;
end;

define method read-element
    (stream :: <chunking-input-stream>, #key on-end-of-stream = $unsupplied)
 => (char)
  maybe-refill-read-buffer(stream);
  if (stream-at-end?(stream))
    if (supplied?(on-end-of-stream))
      on-end-of-stream
    else
      signal(make(<end-of-stream-error>, stream: stream))
    end
  else
    let char = stream.read-buffer[stream.read-buffer-index];
    inc!(stream.read-buffer-index);
    char
  end
end method read-element;

// Read n bytes of the message body only.  The headers are read automatically
// before the connection is considered readable.
//
define method read
    (stream :: <chunking-input-stream>, n :: <integer>,
     #key on-end-of-stream = $unsupplied)
 => (string :: <byte-string>)
  maybe-refill-read-buffer(stream);
  let string :: <byte-string> = make(<byte-string>, size: n, fill: ' ');
  let spos :: <integer> = 0;
  block (return)
    // Loop refilling the underlying read buffer, until we've filled "string".
    // When the end of the message body is reached, stream.%eof-position is set
    // to the index of the last element + 1 to indicate where the message ends.
    while (spos < string.size)
      if (stream-at-end?(stream))
        if (supplied?(on-end-of-stream))
          return(on-end-of-stream)
        elseif (spos > 0)
          signal(make(<incomplete-read-error>,
                      stream: stream,
                      sequence: copy-sequence(string, end: spos),
                      count: n))
        else
          signal(make(<end-of-stream-error>,
                      stream: stream))
        end;
      elseif (stream.read-buffer-index = stream.read-buffer.size)
        refill-read-buffer(stream);
      else
        string[spos] := stream.read-buffer[stream.read-buffer-index];
        inc!(spos);
        inc!(stream.read-buffer-index);
      end;
    end while;
    log-trace(*http-common-log*, "<==%=", string);
    string
  end block
end method read;

// This is an optimization over the default method, and has a more specific
// return type.
//
define method read-to-end
    (stream :: <chunking-input-stream>)
 => (elements :: <byte-string>)
  let content-len :: false-or(<integer>) = content-length(stream);
  if (content-len)
    read(stream, content-len - stream.message-bytes-read)
  else
    let chunks = make(<stretchy-vector>);
    block ()
      while (#t)
        add!(chunks, read(stream, 8192));
      end;
    exception (ex :: <incomplete-read-error>)
      add!(chunks, ex.stream-error-sequence);
    exception (ex :: <end-of-stream-error>)
      // pass
    end;
    join(chunks, "")
  end
end method read-to-end;

// This is here to override the method on <wrapper-stream>, which ends up calling
// read-into!(<buffered-stream>, ...) which doesn't check for stream-at-end? first.
// This method is an exact copy of read-into!(<stream>, ...) except for the type
// on which the first parameter is specialized.  (Is there a better way?)
//
define method read-into!
    (stream :: <chunking-input-stream>, n :: <integer>, sequence :: <mutable-sequence>,
     #key start = 0, on-end-of-stream = $unsupplied)
 => (count)
  let limit = min(n + start, sequence.size);
  iterate loop (i = start)
    if (i < limit)
      let elt = read-element(stream, on-end-of-stream: unfound());
      if (found?(elt))
        sequence[i] := elt;
        loop(i + 1);
      elseif (supplied?(on-end-of-stream))
        i - start
      else
        signal(make(<incomplete-read-error>,
                    stream: stream,
                    count: i - start, // seems kinda redundant...
                    sequence: copy-sequence(sequence, start: start, end: i)))
      end
    else
      i - start
    end if;
  end;
end method read-into!;

// Read enough data from the message to fill read-buffer.
// If the message end is found, based on either Content-Length header
// or a zero-length chunk being received set %eof-position to the index
// of the last character + 1, to indicate the end of the stream.
//
define method refill-read-buffer
    (stream :: <chunking-input-stream>)
  let content-len :: false-or(<integer>) = content-length(stream);
  let bytes-read :: <integer>
    = if (content-len)
        stream.read-buffer-index := 0;
        let n :: <integer> = 0;
        let bytes-to-read = min(stream.read-buffer.size,
                                content-len - stream.message-bytes-read);
        if (bytes-to-read > 0)
          block ()
            n := read-into!(stream.inner-stream,
                            bytes-to-read,
                            stream.read-buffer);
          exception (ex :: <incomplete-read-error>)
            // Note: doc says this should be named incomplete-read-error-count.
            n := ex.stream-error-count;
          end;
        end;
        if (*debug-reads?*)
          write(*standard-output*, "READ: ");
          write(*standard-output*, stream.read-buffer, end: n);
        end;
        if (n < stream.read-buffer.size
              | (stream.message-bytes-read + n) = content-len)
          stream.%eof-position := n;
        end;
        n
      else // chunked
        let chunk = read-chunk(stream.inner-stream);
        stream.read-buffer := chunk;
        stream.read-buffer-index := 0;
        if (chunk.size = 0)
          stream.%eof-position := 0;
        end;
        chunk.size
      end;
  inc!(stream.message-bytes-read, bytes-read);
  note-bytes-received(stream, bytes-read);
end method refill-read-buffer;

/*
       Chunked-Body   = *chunk
                        last-chunk
                        trailer
                        CRLF

       chunk          = chunk-size [ chunk-extension ] CRLF
                        chunk-data CRLF
       chunk-size     = 1*HEX
       last-chunk     = 1*("0") [ chunk-extension ] CRLF

       chunk-extension= *( ";" chunk-ext-name [ "=" chunk-ext-val ] )
       chunk-ext-name = token
       chunk-ext-val  = token | quoted-string
       chunk-data     = chunk-size(OCTET)
       trailer        = *(entity-header CRLF)
*/
// Read an entire chunk from a chunk-encoded stream.  For now this is very
// inefficient and simply allocates a new buffer for the chunk if it's not
// the same size as the previous chunk.  This can easily be optimized by
// keeping track of how much of the current chunk has been read.  Assumes
// the stream is positioned at the beginning of a chunk.
//
// todo -- trailer, chunk-extension
//
define method read-chunk
    (stream :: <stream>)
  let (line, eol) = read-http-line(stream);
  let chunk-size :: <integer> = string-to-integer(line, base: 16, end: eol);
  let buffer :: <byte-string> = make(<byte-string>, size: chunk-size, fill: ' ');
  // todo -- Using the highly inefficient default read-into! method for now.
  //         Should implement a more specific method for it.
  let n :: <integer> = read-into!(stream, chunk-size, buffer);

  // todo -- We let the above signal <end-of-stream-error> for now.  Should
  //         probably signal something HTTP specific instead?
  //if (n < buffer.size)
  //  signal(some-http-error);
  //end;

  local method bad-response-error ()
          // todo -- what's the correct error here?
          error("Bad chunk encoding in message body.  Chunk data should "
                "be followed by CRLF.");
        end;
  if (read-element(stream) ~= '\r')
    bad-response-error();
  end;
  if (read-element(stream) ~= '\n')
    bad-response-error();
  end;
  if (*debug-reads?*)
    format(*standard-output*, "READ: %s\r\n%s\r\n",
           copy-sequence(line, end: eol),
           buffer);
  end;
  buffer
end method read-chunk;




///////////// Requests ////////////

define open class <base-http-request> (<message-headers-mixin>)

  slot request-url :: false-or(<url>) = #f,
    init-keyword: url:;

  slot request-raw-url-string :: false-or(<byte-string>) = #f,
    init-keyword: raw-url:;

  slot request-method :: <request-method> = #"not-set",
    init-keyword: method:;

  slot request-version :: <http-version> = #"not-set",
    init-keyword: version:;

  slot request-content :: <byte-string> = "",
    init-keyword: content:;

end class <base-http-request>;

define method make
    (request :: subclass(<base-http-request>), #rest args, #key url)
 => (request :: subclass(<base-http-request>))
  if (instance?(url, <string>))
    apply(next-method, request, raw-url: url, url: parse-url(url), args)
  else
    // url is a <url> or #f
    next-method()
  end
end method make;

define method chunked-transfer-encoding?
    (headers :: <header-table>)
 => (chunked? :: <boolean>)
  let xfer-encoding = get-header(headers, "Transfer-encoding", parsed: #t);
  xfer-encoding
    & member?("chunked", xfer-encoding,
              test: method (x, y)
                      string-equal?(x, avalue-value(y))
                    end)
end method chunked-transfer-encoding?;

define method chunked-transfer-encoding?
    (headers :: <message-headers-mixin>)
 => (chunked? :: <boolean>)
  chunked-transfer-encoding?(headers.raw-headers)
end method chunked-transfer-encoding?;

// Read a line of input from the stream, dealing with CRLF correctly.
// The string returned does not include the CRLF.  Second return value
// is the end-of-line index.
//
// See also: read-header-line
// todo -- Callers of this that are in the server should pass a max-size
//         argument, at which point an error should be signaled.
//
define method read-http-line
    (stream :: <stream>)
 => (buffer :: <byte-string>, len :: <integer>)
  let buffer = grow-header-buffer("", 0);
  iterate loop (buffer :: <byte-string> = buffer,
                len :: <integer> = buffer.size,
                pos :: <integer> = 0,
                peek-ch :: false-or(<character>) = #f)
    if (pos == len)
      let buffer = grow-header-buffer(buffer, len);
      loop(buffer, buffer.size, pos, peek-ch)
    else
      let ch :: <byte-character> = peek-ch | read-element(stream);
      if (ch == $cr)
        let ch = read-element(stream);
        if (ch == $lf)
          values(buffer, pos)
        else
          buffer[pos] := $cr;
          loop(buffer, len, pos + 1, ch)
        end;
      else
        buffer[pos] := ch;
        loop(buffer, len, pos + 1, #f)
      end if;
    end;
  end iterate;
end method read-http-line;


///////////// Responses ///////////////

define open class <base-http-response> (<object>)

  slot response-code :: <integer> = 200,
    init-keyword: code:;

  slot response-reason-phrase :: <string> = "OK",
    init-keyword: reason-phrase:;

  // Chunked transfer encoding.  RFC 2616, 3.6.1
  slot response-chunked? :: <boolean> = #t,
    init-keyword: chunked:;

end class <base-http-response>;


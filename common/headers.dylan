Module:    http-common-internals
Synopsis:  Request header parsing
Author:    Gail Zacharias
Copyright: See LICENSE in this distribution for details.


// Put a total limit on header size, so don't get wedged reading bogus headers.
// Make it largish though, since cookies come in via a header
define variable *max-single-header-size* :: false-or(<integer>) = 16384;

// Grow header buffer by this much -- is this chosen arbitrarily? is there
// any reasoning behind the 1024? I'd expect a bigger number to lower the
// amount of copying the whole header around -- Hannes 16.11.2007
define variable *header-buffer-growth-amount* :: limited(<integer>, min: 1) = 1024;

// TODO(cgay): Use something more efficient than a <table> for the headers,
// such as a property list.  There should usually be a small number of headers,
// so a list is probably fine.  I also think there's no need to store parsed
// headers; they're probably only accessed once, in general, so maybe just
// provide a public parse-header method.
define open abstract class <message-headers-mixin> (<object>)
  // Raw headers, mapping case-insensitive-header-name to unparsed header value.
  constant slot raw-headers :: <header-table> = make(<header-table>),
    init-keyword: headers:;

  // Parsed headers.  Header values are parsed on demand only.
  constant slot parsed-headers :: <header-table> = make(<header-table>);

end class <message-headers-mixin>;


// This method makes <chunking-input-stream> work when mixed with
// <message-headers-mixin>.
//
define method content-length
    (headers :: <message-headers-mixin>)
 => (content-length :: false-or(<integer>))
  get-header(headers, "Content-Length", parsed: #t)
end;

// Read message headers into a <header-table> and return it.
// If the "headers" argument is supplied then it is side-effected.
// Otherwise a new <header-table> is created and returned.
//
define function read-message-headers
    (stream :: <stream>,
     #key buffer :: <byte-string> = grow-header-buffer("", 0),
          start :: <integer> = 0,
          headers :: <header-table> = make(<header-table>),
          require-crlf? :: <boolean> = #t)
 => (headers :: <header-table>, buffer :: <byte-string>, epos :: <integer>)
  iterate loop (buffer :: <byte-string> = buffer,
                bpos :: <integer> = start,
                peek-ch :: false-or(<character>) = #f)
    let (buffer, bpos, epos, peek-ch)
      = read-header-line(stream, buffer, bpos, peek-ch, require-crlf?);
    if (bpos == epos) // blank line, done.
      values(headers, buffer, epos)
    else
      let (key, data) = split-header(buffer, bpos, epos);
      log-debug(*http-common-log*, "<-- %s: %s", key, data);
      set-header(headers, key, data);
      loop(buffer, epos, peek-ch)
    end if
  end iterate
end function read-message-headers;

define open generic set-header
    (object :: <object>, header :: <byte-string>, value :: <object>,
     #key if-exists? :: one-of(#"replace", #"append", #"ignore", #"error"));

define sealed method set-header
    (headers :: <header-table>, header-name :: <byte-string>, value,
     #key if-exists? :: <symbol> = #"replace")
  // todo -- validate the header.  at least check that it doesn't contain CRLF
  //         unless it's a valid continuation line.
  let old = element(headers, header-name, default: #f);
  if (~old)
    headers[header-name] := value;
  elseif (if-exists? = #"replace")
    log-debug(*http-common-log*, "Replacing header %s: %s -> %s",
              header-name, old, value);
    headers[header-name] := value;
  elseif (if-exists? = #"append")
    log-debug(*http-common-log*, "Appending to header %s: %s", header-name, value);
    headers[header-name] := iff(instance?(old, <pair>),
                                concatenate!(old, list(value)),
                                list(old, value));
  elseif (if-exists? = #"error")
    error("Attempt to add header \"%s: %s\" which has already been added.",
          header-name, value);
  else
    log-debug(*http-common-log*, "Ignoring header %s: %s", header-name, value);
    assert(if-exists? == #"ignore");
  end;
end method set-header;

define method set-header
    (message :: <message-headers-mixin>, header :: <byte-string>, value :: <object>,
     #key if-exists? = #"replace")
  set-header(message.raw-headers, header, value, if-exists?: if-exists?)
end method set-header;

define open generic get-header
    (object :: <object>, header-name :: <byte-string>, #key parsed :: <boolean>)
 => (header-value :: <object>);

define method get-header
    (table :: <table>, header-name :: <byte-string>, #key parsed :: <boolean>)
 => (header-value :: <object>)
  let raw-value = element(table, header-name, default: #f);
  raw-value
    & iff(parsed,
          // TODO(cgay): Interning symbols here is a memory leak.
          parse-header-value(as(<symbol>, header-name), raw-value),
          raw-value)
end method get-header;

define method get-header
    (message :: <message-headers-mixin>, name :: <byte-string>,
     #key parsed :: <boolean>)
 => (header :: <object>)
  if (parsed)
    let cache = message.parsed-headers;
    let cached = element(cache, name, default: $unfound);
    if (found?(cached))
      cached
    else
      cache[name] := get-header(message.raw-headers, name, parsed: #t)
    end
  else
    get-header(message.raw-headers, name, parsed: #f)
  end
end method get-header;

define function grow-header-buffer (old :: <byte-string>, len :: <integer>)
  if (*max-single-header-size* & len >= *max-single-header-size*)
    header-too-large-error(max-size: *max-single-header-size*);
  else
    let nlen = len + *header-buffer-growth-amount*;
    let new :: <byte-string>
      = make(<byte-string>, size: min(*max-single-header-size* | nlen, nlen));
    let bpos :: <integer> = old.size - len;
    // Move the last len bytes of old to new.
    for (i :: <integer> from 0 below len)
      new[i] := old[bpos + i]
    end;
    new
  end;
end function grow-header-buffer;

// Read a header line, including continuation lines, if any.
// If require-crlf? is #t then lines MUST be terminated by CRLF, otherwise
// they may be terminated by CRLF or LF.  Either way, the EOL characters
// are not included in the result.  require-crlf?: #f is intended for use
// reading headers generated by CGI scripts.
//
// Note that this implementation has a drawback: it stores the CR in the
// buffer and then later removes it if LF follows.  This greatly simplifies
// the code but that last CR could unnecessarily grow the buffer.
//
define function read-header-line
    (stream :: <stream>,
     buffer :: <byte-string>,
     bpos :: <integer>,
     peek-ch :: false-or(<byte-character>),
     require-crlf? :: <boolean>)
 => (buffer :: <byte-string>,
     bpos :: <integer>,
     epos :: <integer>,
     peek-ch :: false-or(<byte-character>))
  iterate loop (buffer :: <byte-string> = buffer,
                bpos :: <integer> = bpos,
                epos :: <integer> = buffer.size,
                pos :: <integer> = bpos,
                peek-ch :: false-or(<byte-character>) = peek-ch)
    // Complain even if don't really need room for one more char, makes the
    // program logic simpler...
    if (pos == epos)
      if (*max-single-header-size* & epos - bpos >= *max-single-header-size*)
        header-too-large-error(max-size: *max-single-header-size*);
      else
        let len = epos - bpos;
        let new = grow-header-buffer(buffer, len);
        loop(new, 0, new.size, len, peek-ch);
      end;
    else
      let ch :: <byte-character> = peek-ch | read-element(stream);
      let prev-was-cr? = (pos > bpos & buffer[pos - 1] == $cr);
      if (ch == $lf & (~require-crlf? | prev-was-cr?))
        if (prev-was-cr?)
          dec!(pos);      // don't include CR in result
        end;
        if (bpos == pos)  // empty line means end
          values(buffer, bpos, pos, #f)
        else
          let ch = read-element(stream);
          if (ch == ' ' | ch == '\t') // continuation line
            // should canonicalize whitespace to a single SP here?
            loop(buffer, bpos, epos, pos, ch)
          else
            values(buffer, bpos, pos, ch)
          end
        end
      else
        buffer[pos] := ch;
        loop(buffer, bpos, epos, pos + 1, #f)
      end
    end
  end iterate
end function read-header-line;



// Split header into header name (the part preceding the ':') and header value.
define function split-header
    (buffer :: <byte-string>, bpos :: <integer>, epos :: <integer>)
 => (header-key :: <string>, header-data :: <string>)
  let pos = char-position(':', buffer, bpos, epos);
  if (~pos)
    bad-header-error(message: "Header line contained no colon")
  else
    // We don't use keywords for header keys, because don't want to end
    // up interning some huge bogus header that would then drag us down
    // for the rest of eternity...
    let key = substring(buffer, bpos, pos);
    let (data-start, data-end) = trim-whitespace(buffer, pos + 1, epos);
    let data = substring(buffer, data-start, data-end);
    values(key, data)
  end
end function split-header;

////////////////////////////////////////////////////////////////////////////////

// TODO(cgay): Kill this and use plists or similar instead. Can't remember why
// I didn't just use <string-table> anyway.

define class <header-table> (<table>)
end;

define sealed method table-protocol (table :: <header-table>)
  => (test-fn :: <function>, hash-fn :: <function>);
  ignore(table);
  values(string-equal-ic?, sstring-hash);
end method table-protocol;

define method sstring-hash (s :: <byte-string>, state)
  values(string-hash-2(s, 0, s.size), state)
end;

define inline function string-hash-2 (s :: <byte-string>,
                                      bpos :: <integer>,
                                      len :: <integer>)
  let epos :: <integer> = bpos + len;
  for (i :: <integer> from bpos below epos,
       hash :: <integer> = 0 then
    modulo(ash(hash, 6) + logand(as(<integer>, s[i]), #x9F), 970747))
  finally
    hash
  end;
end function string-hash-2;

define constant <field-type> = type-union(<list>, <string>);

define open generic parse-header-value (field-name :: <symbol>,
                                        field-values :: <field-type>)
  => (parsed-field-value :: <object>);

// default method, just returns a string
define method parse-header-value (key :: <symbol>, data :: <field-type>) => (v :: <string>)
  parse-header(data)
end;

// Returns a list of <media-types>s
define sealed method parse-header-value (key == #"accept", data :: <field-type>)
    => (media-types :: <list>)
  parse-comma-separated-values(data, parse-media-type)
end;

// returns alist mapping charset to qvalue as an integer between 0 and 1000.
// the primary value is unused.
define sealed method parse-header-value (key == #"accept-charset", data :: <field-type>)
  => (alist :: <avalue>)
  parse-comma-separated-pairs(data, parse-quality-pair)
end;

// returns alist: (content-coding:string . qvalue:integer)
define sealed method parse-header-value (key == #"accept-encoding", data :: <field-type>)
  => (alist :: <avalue>)
  parse-comma-separated-pairs(data, parse-quality-pair)
end;

// returns alist: (language:string . qvalue:integer)
// where qvalue is an integer between 0 and 1000.
define sealed method parse-header-value (key == #"accept-language", data :: <field-type>)
  => (alist :: <avalue>)
  parse-comma-separated-pairs(data, parse-quality-pair)
end;

// cf RFC 2069
// Returns string for "basic" and <avalue> for others.
define sealed method parse-header-value (key == #"authorization", data :: <field-type>)
  => (credentials :: type-union(<pair>, <avalue>))
  //(define-header-keywords "realm" "nonce" "username" "uri" "response" "digest" "algorithm" "opaque"
  // "basic" "digest")
  parse-single-header(data, parse-authorization-value)
end;

define sealed method parse-header-value (key == #"cache-control", data :: <field-type>)
  => (params :: <avalue>)
  parse-comma-separated-pairs(data, parse-attribute-value-pair)
end;

define sealed method parse-header-value (key == #"connection", data :: <field-type>)
  => (tokens :: <list>)
  parse-comma-separated-values(data, parse-token-value);
end;

define sealed method parse-header-value (key == #"date", data :: <field-type>)
  => (date :: <date>)
  parse-single-header(data, parse-date-value)
end;


// ---TODO: *** If a server receives a request containing an Expect field
// that includes an expectation-extension that it does not support, it
// MUST respond with a 417 Expectation Failed status. ***
// So need to come up with some user-extensible API for this.
define sealed method parse-header-value (key == #"expect", data :: <field-type>)
  => (expect :: <avalue>)
  //(define-header-keywords "100-continue")
  parse-comma-separated-pairs(data, parse-expectation-pair)
end;

// This is nominally just a single from field, but what do we care...
define sealed method parse-header-value (key == #"from", data :: <field-type>)
  => (froms :: <list>)
  // parse-single-header(data, parse-string-value)
  parse-comma-separated-values(data, parse-string-value);
end;

define sealed method parse-header-value (key == #"host", data :: <field-type>)
  => (host+port :: <pair>)
  parse-single-header(data, parse-host-value)
end;

define sealed method parse-header-value (key == #"if-match", data :: <field-type>)
  => (entity-tags :: <list>)
  parse-comma-separated-values(data, parse-entity-tag-value);
end;

define sealed method parse-header-value (key == #"if-modified-since", data :: <field-type>)
  => (date :: <date>)
  parse-single-header(data, parse-date-value);
end;

define sealed method parse-header-value (key == #"if-none-match", data :: <field-type>)
  => (entity-tags :: <list>)
  parse-comma-separated-values(data, parse-entity-tag-value);
end;

define sealed method parse-header-value (key == #"if-unmodified-since", data :: <field-type>)
 => (date :: <date>)
  parse-single-header(data, parse-date-value)
end;

// ?????
//define method parse-header-value (key == #"keep-alive", data :: <field-type>)
//  parse-keep-alive-header(data)
//end;

define sealed method parse-header-value (key == #"max-forwards", data :: <field-type>)
  => (max :: <integer>)
  parse-single-header(data, parse-integer-value)
end;

// ?????
//define method parse-header-value (key == #"method", data :: <field-type>)
//  parse-comma-separated-values(data)
//end;

// HTTP/1.1 caches SHOULD treat "Pragma: no-cache" as if the client had
// sent "Cache-control: no-cache".
define sealed method parse-header-value (key == #"pragma", data :: <field-type>)
  => (params :: <avalue>)
  parse-comma-separated-pairs(data, parse-attribute-value-pair)
end;

// ;deprecated 1.0 Extension
define sealed method parse-header-value (key == #"proxy-connection", data :: <field-type>)
  => (tokens :: <list>)
  parse-comma-separated-values(data, parse-token-value);
end;

define sealed method parse-header-value (key == #"proxy-authorization", data :: <field-type>)
  => (credentials :: type-union(<string>, <avalue>))
  parse-single-header(data, parse-authorization-value)
end;

define sealed method parse-header-value (key == #"range", data :: <field-type>)
  => (ranges :: <list>)
 parse-single-header(data, parse-ranges-value)
end;

define sealed method parse-header-value (key == #"referer", data :: <field-type>)
  => (data :: <string>)
  parse-single-header(data, parse-string-value)
end;

// returns a list of avalues
define sealed method parse-header-value (key == #"TE", data :: <field-type>)
  => (encodings :: <list>)
  parse-comma-separated-values(data, parse-parameterized-value)
end;

define sealed method parse-header-value (key == #"trailer", data :: <field-type>)
  => (trailers :: <list>)
  parse-comma-separated-values(data, parse-token-value);
end;

define sealed method parse-header-value (key == #"transfer-encoding", data :: <field-type>)
  => (encodings :: <list>)
  parse-comma-separated-values(data, parse-parameterized-value)
end;

// should we parse the product?  Will anybody ever care?
define sealed method parse-header-value (key == #"upgrade", data :: <field-type>)
 => (products :: <list>)
  parse-comma-separated-values(data, parse-string-value);
end;

// Might want to parse the main product field, sometimes need to
// use that to decide what extensions are supported.
define sealed method parse-header-value (key == #"user-agent", data :: <field-type>)
  => (agent :: <string>)
  parse-single-header(data, parse-string-value)
end;

define sealed method parse-header-value (key == #"via", data :: <field-type>)
  => (vias :: <list>)
  parse-comma-separated-values(data, parse-string-value)
end;

// Might want to parse... very structured.
define sealed method parse-header-value (key == #"warning", data :: <field-type>)
  => (warnings :: <list>)
  parse-comma-separated-values(data, parse-string-value)
end;

/// Entity headers

define sealed method parse-header-value (key == #"allow", data :: <field-type>)
  => (methods :: <list>)
  parse-comma-separated-values(data, parse-token-value);
end;

define sealed method parse-header-value (key == #"content-encoding", data :: <field-type>)
  => (encodings :: <list>)
  parse-comma-separated-values(data, parse-parameterized-value)
end;

// not in 1.1
define sealed method parse-header-value (key == #"content-disposition", data :: <field-type>)
  => (disp :: <avalue>)
  parse-single-header(data, parse-parameterized-value)
end;

define sealed method parse-header-value (key == #"content-language", data :: <field-type>)
 => (langs :: <list>)
  parse-comma-separated-values(data, parse-token-value);
end;

define sealed method parse-header-value (key == #"content-length", data :: <field-type>)
  => (len :: <integer>)
  parse-single-header(data, parse-integer-value);
end;

define sealed method parse-header-value (key == #"content-location", data :: <field-type>)
  => (url :: <string>)
  parse-single-header(data, parse-string-value)
end;

define sealed method parse-header-value (key == #"content-md5", data :: <field-type>)
 => (md5 :: <string>)
  parse-single-header(data, parse-string-value)
end;

// returns #((first . last) . total)
define sealed method parse-header-value (key == #"content-range", data :: <field-type>)
  => (range :: <pair>)
  parse-single-header(data, parse-range-value)
end;

define sealed method parse-header-value (key == #"content-type", data :: <field-type>)
  => (type :: <media-type>)
  parse-single-header(data, parse-media-type)
end;

define sealed method parse-header-value (key == #"expires", data :: <field-type>)
  => (date :: <date>)
  parse-single-header(data, parse-date-value)
end;

define sealed method parse-header-value (key == #"last-modified", data :: <field-type>)
  => (date :: <date>)
  parse-single-header(data, parse-date-value)
end;


//---TODO: Verify that all strings are valid HTTP/1.1 tokens

define constant $default-cookie-version :: <byte-string> = "1";

define class <cookie> (<object>)
  constant slot cookie-name  :: <string>, required-init-keyword: name:;
  constant slot cookie-value :: <string>, required-init-keyword: value:;
  constant slot cookie-domain  :: false-or(<string>) = #f, init-keyword: domain:;
  constant slot cookie-path    :: false-or(<string>) = #f, init-keyword: path:;
  // The maximum lifetime of the cookie, in seconds.  #f means "until the user agent exits".
  constant slot cookie-max-age :: false-or(<integer>) = #f, init-keyword: max-age:;
  constant slot cookie-comment :: false-or(<string>) = #f, init-keyword: comment:;
  constant slot cookie-version :: <string> = $default-cookie-version, init-keyword: version:;
end;

define method extract-cookies
    (str :: <byte-string>, bpos :: <integer>, epos :: <integer>, cookies :: <list>) => (cookies :: <list>)
  let cookies :: <list> = #();
  let version = "1";  // default
  let (name, value, path, domain) = values(#f, #f, #f, #f);
  local method add-cookie ()
          cookies := add(cookies,
                         make(<cookie>,
                              name: name, value: value, path: path, domain: domain,
                              version: version));
          name  := #f;
          value := #f;
          path  := #f;
          domain := #f;
        end;
  iterate loop (bpos = bpos)
    let bpos = skip-whitespace(str, bpos, epos);
    let lim = char-position(';', str, bpos, epos)
              | char-position(',', str, bpos, epos)
              | epos;
    let (attr, val) = extract-attribute+value(str, bpos, lim);
    select (attr by string-equal?)
      "$Version" => version := val;
      "$Path"    => path := val;
      "$Domain"  => domain := val;
      otherwise  => begin
                      name & add-cookie();  // if name is set then first cookie is baked
                      name := attr;
                      value := val;
                    end;
    end select;
    unless (lim == epos)
      loop(lim + 1)
    end;
  end iterate;
  name & add-cookie();
  cookies
end;

define method parse-header-value
    (key == #"cookie", data :: <string>) => (cookies :: <list>)
  extract-cookies(data, 0, size(data), #())
end;

define method parse-header-value
    (key == #"cookie", data :: <list>) => (cookies :: <list>)
  let cookies :: <list> = #();
  for (header in data)
    cookies := concatenate(cookies, extract-cookies(header, 0, size(header), cookies))
  end;
  cookies
end;


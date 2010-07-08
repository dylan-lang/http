Module:    httpi
Synopsis:  Tools for mapping URLs to responder functions
Author:    Carl Gay
Copyright: Copyright (c) 2001 Carl L. Gay.  All rights reserved.
           Original Code is Copyright (c) 2001 Functional Objects, Inc.  All rights reserved.
License:   Functional Objects Library Public License Version 1.0
Warranty:  Distributed WITHOUT WARRANTY OF ANY KIND


// One URL prefix is mapped to one <responder>.  The <responder> contains
// all the information necessary to dispatch to specific actions based on
// the part of the URL following the prefix.
//
define class <responder> (<object>)
  // request-method-map is a map from request method (e.g. #"POST") to a sequence
  // of <tail-responder>s.  When the regex in the tail responder matches the tail
  // of the url (i.e., the part following the base url on which this responder was
  // registered) the tail responder's action function is called.
  //
  constant slot request-method-map :: <table> = make(<table>),
    init-keyword: map:;
end;

// There is a sequence of <tail-responder>s per request method.  They are
// each matched against the tail of the URL in order and the first one to
// match is invoked.
define class <tail-responder> (<object>)
    constant slot tail-responder-regex :: <regex>,
      required-init-keyword: regex:;

    // Must be an object that supports the invoke-responder method.
    // Currently that means <function> or <page>, but invoke-responder
    // is exported so it could be anything.
    constant slot tail-responder-action :: <object>,
      required-init-keyword: action:;
end;

// A convenience function for making a responder with several
// tail url matchers.  Example:
//   make-responder(list(#(get:, post:),
//                       "^/(?P<script-name>[^/]+)(?P<path-info>.*)$",
//                       cgi-directory-responder),
//                  ...)
define function make-responder
    (#rest triples) => (responder :: <responder>)
  let responder = make(<responder>);
  for (triple in triples)
    let (request-methods, regex, action) = apply(values, triple);
    if (~instance?(regex, <regex>))
      regex := compile-regex(regex);
    end;
    for (request-method in iff(instance?(request-methods, <collection>),
                               request-methods,
                               list(request-methods)))
      add-tail-responder(responder, request-method, regex, action);
    end;
  end;
  responder
end function make-responder;

define function add-responder
    (store :: type-union(<string-trie>, <http-server>),
     uri :: type-union(<uri>, <string>),
     responder,
     #key replace? :: <boolean>)
  if (instance?(store, <http-server>))
    store := store.url-map;
  end;
  if (instance?(uri, <string>))
    uri := parse-uri(uri);
  end;
  %add-responder(store, uri, responder, replace?: replace?);
end function add-responder;

define open generic %add-responder
    (store :: <string-trie>, url :: <uri>, responder, #key replace?);

define method %add-responder
    (store :: <string-trie>, uri :: <uri>, responder :: <responder>,
     #key replace? :: <boolean>)
  let path = uri.uri-path;
  if (empty?(path))
    error(make(<koala-api-error>,
               format-string: "Attempt to add a responder for a URL with no path."));
  else
    block ()
      add-object(store, path, responder, replace?: replace?);
      log-info("Responder added: %s ", build-path(uri));
    exception (ex :: <trie-error>)
      error(make(<koala-api-error>,
                 format-string: "A responder already exists for URL path %s",
                 format-arguments: list(build-path(uri))));
    end;
  end if;
end method %add-responder;

// The simple case where you just want an exact URL to map to a function.
// This takes care of the messy details of building a <responder> object.
// response-function is passed one keyword argument for each named group
// in the regex that matched the url tail, if any.
//
define method %add-responder
    (store :: <string-trie>, url :: <uri>, response-function :: <function>,
     #key replace?)
  %add-responder(store, url,
                 make-responder(list(#(get:, post:), "^$", response-function)),
                 replace?: replace?)
end method %add-responder;

define open generic find-responder
    (server :: <http-server>, url :: <object>)
 => (responder :: false-or(<responder>),
     rest-path :: <sequence>,
     prefix-path :: <sequence>);

define method find-responder
    (server :: <http-server>, url :: <string>)
 => (responder :: false-or(<responder>),
     rest-path :: <sequence>,
     prefix-path :: <sequence>)
  find-responder(server, parse-url(url))
end method find-responder;

define method find-responder
    (server :: <http-server>, url :: <url>)
 => (responder :: false-or(<responder>),
     rest-path :: <sequence>,
     prefix-path :: <sequence>)
  find-object(server.url-map, url.uri-path)
end method find-responder;


define open generic remove-responder
    (server :: <http-server>, object :: <object>);

define method remove-responder
    (server :: <http-server>, url :: <string>)
  remove-responder(server, parse-url(url));
end;

define method remove-responder
    (server :: <http-server>, url :: <url>)
  remove-object(server.url-map, url.uri-path);
end;


/* Example usage
define url-map $map ()
  url "/" action get () => $main-page;
end;

add-urls(trie-or-server,
         url "/a" action get () => $main-page;
         url "/b" action get () => $main-page;)

define url-map $my-map ()
  url "/wiki",
    action GET () => show-page,
    action POST () => edit-page;
  url "/wiki/login"
    action POST ("/(?<name>:\\w+") => login;
end;
*/
// It might be nice to add a prefix clause to this.  e.g.,
//    prefix: "/demo"
// so that all urls are prefixed with that string.  But that might
// be better handled by "define web-application", which perhaps this
// macro can be expanded to at some point.
//
define macro url-map-definer
  // Define a new variable and add URL mappings to it.
  { define url-map ?:name () ?urls:* end }
   => { define constant ?name :: <string-trie> = make(<string-trie>, object: #f);
        add-urls(?name, ?urls); }
end;

define macro add-urls
    { add-urls(?store:expression, ?urls) }
 => { let _url-map = ?store; ?urls }

  urls:
    { } => { }
    { ?url ; ... } => { ?url ; ... }

  url:
    { url ?uri:expression ?actions }
     => { let _responder = make(<responder>);
          let _locations = list(?uri);
          ?actions ;
          add-responder( _url-map, first(_locations), _responder)
          }
    { url ( ?locations:* ) ?actions }
      => { let _responder = make(<responder>);
           let _locations = list(?locations);
           ?actions ;
           for (loc in _locations)
             add-responder( _url-map, loc, _responder);
           end
           }
  actions:
    { } => { }
    { ?action-definition , ... } => { ?action-definition ; ... }

  // I'd like to get rid of the parens around ?request-methods.
  // Not quite sure how yet though.  --cgay
  action-definition:
    // These four retained for backward compatibility, just until I get
    // a chance to fix the callers.  --cgay June 2009
    { action ( ?request-methods ) ( ?regex ) => ?action:expression }
      => { let regex = compile-regex(?regex, use-cache: #t);
           let actions = list(?action);
           ?request-methods }
    { action ?request-method:name ( ?regex ) => ?action:expression }
      => { let regex = compile-regex(?regex);
           let actions = list(?action);
           ?request-method }
    { action ( ?request-methods ) ( ?regex ) => ( ?action-sequence:* ) }
      => { let regex = compile-regex(?regex, use-cache: #t);
           let actions = list(?action-sequence);
           ?request-methods }
    { action ?request-method:name ( ?regex ) => ( ?action-sequence:* ) }
      => { let regex = compile-regex(?regex);
           let actions = list(?action-sequence);
           ?request-method }

    // These ones are exact copies of the above, but with the parens
    // around ?regex removed.
    { action ( ?request-methods ) ?regex => ?action:expression }
      => { let regex = compile-regex(?regex, use-cache: #t);
           let actions = list(?action);
           ?request-methods }
    { action ?request-method:name ?regex => ?action:expression }
      => { let regex = compile-regex(?regex);
           let actions = list(?action);
           ?request-method }
    { action ( ?request-methods ) ?regex => ( ?action-sequence:* ) }
      => { let regex = compile-regex(?regex, use-cache: #t);
           let actions = list(?action-sequence);
           ?request-methods }
    { action ?request-method:name ?regex => ( ?action-sequence:* ) }
      => { let regex = compile-regex(?regex);
           let actions = list(?action-sequence);
           ?request-method }
  request-methods:
    { } => { }
    { ?request-method , ...  } => { ?request-method ; ... }

  request-method:
    { ?req-method:name }
     => { add-tail-responder(_responder, ?#"req-method",
                             regex, actions) }

  regex:
    { } => { "^$" }
    { * } => { ".*" }
    { ?pattern:expression } => { ?pattern }

end macro add-urls;

define method add-tail-responder
    (responder :: <responder>,
     request-method :: <symbol>,
     regex :: <regex>,
     action)
  let tail-responders = element(responder.request-method-map, request-method,
                                default: #f);
  if (~tail-responders)
    tail-responders := make(<stretchy-vector>);
    responder.request-method-map[request-method] := tail-responders;
  end;
  add!(tail-responders, make(<tail-responder>, regex: regex, action: action));
end method add-tail-responder;


/*
// General server statistics
//
define responder general-stats-responder ("/koala/stats") 
  let stream = current-response().output-stream;
  let server = current-request().request-server;
  format(stream, "<html><body>");
  format(stream, "%s<br>", $server-header-value);
  format(stream, "Up since %s<br>", as-iso8601-string(server.startup-date));
  format(stream, "Connections handled: %d<br>", server.connections-accepted);
  format(stream, "</body></html>");
end;


// Show some stats about what user-agents have connected to the server.
//
define responder user-agent-responder ("/koala/user-agents")
  let stream = current-response().output-stream;
  format(stream, "<html><body>");
  for (count keyed-by agent in current-request().request-server.user-agent-stats)
    format(stream, "%5d: %s<br>", count, agent);
  end;
  format(stream, "</body></html>");
end;

// Return an HTTP error code, for testing purposes.
// e.g., /koala/http-error?code=503
//
define responder http-error-responder ("/koala/http-error")
  let code-string = get-query-value("code");
  let code = string-to-integer(code-string);
  signal(make(<http-error>,
              code: code,
              format-string: "Koala HTTP server received a request for error code %=",
              format-arguments: vector(code-string)));
end;
*/

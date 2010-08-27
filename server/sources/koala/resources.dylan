Module:    httpi
Synopsis:  Tools for mapping URLs to available resources
Author:    Carl Gay
Copyright: Copyright (c) 2001-2010 Carl L. Gay.  All rights reserved.
           Original Code is Copyright (c) 2001 Functional Objects, Inc.  All rights reserved.
License:   Functional Objects Library Public License Version 1.0
Warranty:  Distributed WITHOUT WARRANTY OF ANY KIND


//// Resource protocol

// An <abstract-resource> is responsible for setting headers on and
// writing data to the current <response> by overriding the "respond"
// method or one of the "respond-to-{get,put,...}"
// methods. <resource>s are arranged in a tree structure.
//
define open abstract class <abstract-resource> (<object>)
end;

// Respond to a request for the given resource.
define open generic respond (resource :: <abstract-resource>, #key, #all-keys);

// Pre-defined request methods each have a specific generic...

define open generic respond-to-options (resource :: <abstract-resource>, #key, #all-keys);
define open generic respond-to-get (resource :: <abstract-resource>, #key, #all-keys);
define open generic respond-to-head (resource :: <abstract-resource>, #key, #all-keys);
define open generic respond-to-post (resource :: <abstract-resource>, #key, #all-keys);
define open generic respond-to-put (resource :: <abstract-resource>, #key, #all-keys);
define open generic respond-to-delete (resource :: <abstract-resource>, #key, #all-keys);
define open generic respond-to-trace (resource :: <abstract-resource>, #key, #all-keys);
define open generic respond-to-connect (resource :: <abstract-resource>, #key, #all-keys);

// The content type that will be sent in the HTTP response if no
// Content-Type header is set by the respond* method.  For convenience,
// a string such as "text/plain" may be returned rather than a <mime-type>.
//
define open generic default-content-type
    (resource :: <abstract-resource>)
 => (content-type :: type-union(<string>, <mime-type>));

// If no other content type is set, it seems reasonable to assume it is
// text/html, doesn't it?
define method default-content-type
    (resource :: <abstract-resource>)
 => (content-type :: <string>)
  "text/html"
end;



//// <resource> -- the default resource implementation

// Because they effectively route requests to their children, <resource>s are
// <abstract-request-router>s.  That is, there are methods for add-resource
// and find-resource.
define open class <resource> (<abstract-resource>, <abstract-request-router>)
  constant slot resource-children :: <string-table> = make(<string-table>);

  // This holds the child names (the keys of resource-children) in the order
  // in which they were added.  If a resource is added under multiple names
  // the first one is "canonical", and is used in URL generation.  (An ordered
  // hash table would be nice here....)
  constant slot resource-order :: <stretchy-vector> = make(<stretchy-vector>);

  // The parent is used for URL to find the full URL path (for url generation).
  // Even though there may be multiple URLs that map to the same resource
  // each resource only has a single parent.  The idea is that you should
  // add the URL under its "canonical" name first, and that will be the one
  // generated.
  slot resource-parent :: false-or(<resource>) = #f;

  // If add-resource was called with URL /page/view/{title}/{version} then
  // this would be set to #(title:, version:) to indicate that those keywords
  // should be passed to the respond* methods with the corresponding values
  // from the request URL suffix, if available.  They are also used in URL
  // generation.  When a link is generated with f(... title: "t", version: "v")
  // this slot tells us where those arguments fit into the URL by virtue of
  // the fact that its elements are ordered.
  //
  slot resource-path-variables :: <sequence> = #();
end class <resource>;

// Used for internal book-keeping.
define class <placeholder-resource> (<resource>)
end;


//// add-resource

// Add a route (path) to a resource.  The 'url' parameter accepts a string or
// sequence of strings that indicate the path portion of a URL relative to the
// parent's path.  For example if the parent resource is mapped to "/foo"...
//
//    given url         child is mapped to
//    ---------         ------------------
//    "bar"             /foo/bar
//    ""                /foo/
//    "x/y"             /foo/x/y
//    #("x", "y")       /foo/x/y
//
// The "url-name" parameter can be used to give a (global) name to the
// URL which can be used for URL generation (to avoid hard-coding URLs
// into the application).  See generate-url.
//
// The "trailing-slash" parameter determines what, if anything, to do
// for the given path with a trailing slash appended to it.  
//

// convert <uri> to <sequence>
define method add-resource
    (container :: <resource>, url :: <uri>, child :: <resource>,
     #key url-name :: <string>, trailing-slash)
  log-debug("add-resource(%=, %=, %=)", container, url, child);
  add-resource(container, url.uri-path, child,
               url-name: url-name,
               trailing-slash: trailing-slash);
end;

// convert <http-server> to <resource>
define method add-resource
    (server :: <http-server>, url :: <object>, resource :: <resource>,
     #key url-name, trailing-slash)
  log-debug("add-resource(%=, %=, %=)", server, url, resource);
  add-resource(server.request-router, url, resource,
               url-name: url-name,
               trailing-slash: trailing-slash);
end;

// "url" is either a single path element or a full URL path.
define method add-resource
    (parent :: <resource>, url :: <string>, child :: <resource>,
     #key url-name :: false-or(<string>),
          trailing-slash: trailing-slash)
  log-debug("add-resource(%=, %=, %=)", parent, url, child);
  if (member?('/', url))
    // The root URL, "/", is a special case because it is both a leading
    // and trailing slash, which doesn't match our resource tree structure.
    // There is a corresponding hack in find-resource.
    let path = iff(url = "/", list(""), split(url, '/'));
    add-resource(parent, path, child,
                 url-name: url-name,
                 trailing-slash: trailing-slash);
  elseif (path-variable?(url))
    koala-api-error("Attempt to call add-resource with a path "
                    "variable (%=) as the URL.", url);
  else
    let name = url;
    let existing-child = element(parent.resource-children, name, default: #f);
    if (existing-child)
      if (instance?(existing-child, <placeholder-resource>))
        for (kid keyed-by kid-name in existing-child.resource-children)
          // Do this recursively to check for duplicate names.
          // Do not pass the url-name argument.
          add-resource(child, kid-name, kid, trailing-slash: #f);
        end;
      else
        koala-api-error("A child resource named %= already exists "
                        "at this URL path (%s).",
                        name, existing-child.resource-url-path);
      end;
    else
      parent.resource-children[name] := child;
      add!(parent.resource-order, name);
      if (~child.resource-parent)
        child.resource-parent := parent;
      end;
      if (trailing-slash & name ~= "")
        // The caller passed url foo and wants foo/ mapped as well.
        add-resource(child, "", child);
      end;
      if (url-name)
        // TODO: add a way to specify whether the url with or without
        //       a trailing slash should be canonical (i.e., generated).
        add-resource-name(url-name, child);
      end;
    end;
  end;
end method add-resource;

// "path" is a sequence of URL path elements (strings). 
define method add-resource
    (parent :: <resource>, path :: <sequence>, resource :: <resource>,
     #key url-name, trailing-slash)
  log-debug("add-resource(%=, %=, %=)", parent, path, resource);
  if (empty?(path))
    koala-api-error("Empty sequence, %=, passed to add-resource.", path);
  elseif (path[0] = "" & parent.resource-parent)
    koala-api-error("Attempt to add resource %= to non-root resource"
                    " %= using a URL with a leading slash %=.  This"
                    " will result in an unreachable URL path.",
                    resource, parent, join(path, "/"));
  end;
  let index = find-key(path, path-variable?) | path.size;
  let path-vars = as(<list>, copy-sequence(path, start: index));
  let path = as(<list>, copy-sequence(path, end: index));
  resource.resource-path-variables := map(parse-path-variable, path-vars);
  iterate loop (parent = parent, path = path)
    if (empty?(path))
      // done
    elseif (path.size = 1)
      let name :: <string> = first(path);
      add-resource(parent, name, resource,
                   url-name: url-name,
                   trailing-slash: trailing-slash)
    else
      let name :: <string> = first(path);
      let child = element(parent.resource-children, name, default: #f);
      if (~child)
        child := make(<placeholder-resource>);
        add-resource(parent, name, child, trailing-slash: #f);  // do not pass url-name
      end;
      loop(child, rest(path))
    end if;
  end iterate;
end method add-resource;


//// path variables

// Turn "{foo}" into #"foo" and leave other strings alone.
// A symbol indicates a keyword argument to a respond* function.
// A string indicates a literal URL path element in the URL suffix.  (Probably rare.)
//
define function parse-path-variable
    (path-element :: <string>) => (var :: type-union(<string>, <symbol>))
  if (path-variable?(path-element))
    as(<symbol>, copy-sequence(path-element,
                               start: 1,
                               end: path-element.size - 1))
  else
    koala-api-error("%= is not a path variable.  All URL path elements"
                    " following the first path variable must also be path "
                    " variables.", path-element);
  end
end function parse-path-variable;

define function path-variable?
    (path-element :: <string>) => (path-variable? :: <boolean>)
  path-element.size >= 2
    & path-element[0] = '{'
    & path-element[path-element.size - 1] = '}'
end;

// Make a sequence of key/value pairs for passing to respond(resource, #key
define method path-variable-bindings
    (resource :: <resource>, path-suffix :: <list>) => (bindings :: <sequence>)
  let bindings = make(<stretchy-vector>);
  for (path-variable in resource.resource-path-variables,
       suffix = path-suffix then rest(suffix))
    let path-element = iff(empty?(suffix), #f, first(suffix));
    if (instance?(path-variable, <symbol>))
      add!(bindings, path-variable);
      add!(bindings, path-element);
    end;
  end;
  bindings
end method path-variable-bindings;

define function do-resource
    (fn :: <function>, resource :: <resource>)
  local method do-resource-1 (fn, rsrc, seen)
          // It's perfectly normal to add a resource in multiple places
          // so just skip the ones we've seen before.
          if (~member?(rsrc, seen))
            add!(seen, rsrc);
            if (~instance?(rsrc, <placeholder-resource>))
              fn(rsrc);
            end;
            for (child in rsrc.resource-children)
              do-resource-1(fn, child, seen);
            end;
          end;
        end;
  do-resource-1(fn, resource, make(<stretchy-vector>));
end function do-resource;


//// find-resource

// convert <http-server> to <resource>
define method find-resource
    (server :: <http-server>, path :: <object>)
 => (resource :: <resource>, prefix :: <list>, suffix :: <list>)
  log-debug("find-resource(%=, %=)", server, path);
  find-resource(server.request-router, path)
end;

// convert <uri> to <sequence>
define method find-resource
    (container :: <resource>, uri :: <uri>)
 => (resource :: <resource>, prefix :: <list>, suffix :: <list>)
  log-debug("find-resource(%=, %=)", container, uri);
  // Special case the root path, "/", which is both a leading and
  // trailing slash, which doesn't match our resource tree structure.
  // There's a similar special case for add-resource.
  let path = iff(uri.uri-path = #("", ""), list(""), uri.uri-path);
  find-resource(container, path)
end;

// convert <string> to <sequence>
define method find-resource
    (container :: <resource>, path :: <string>)
 => (resource :: <resource>, prefix :: <list>, suffix :: <list>)
  log-debug("find-resource(%=, %=)", container, path);
  find-resource(container, split(path, '/'))
end;

// The base method.  Deeper (more specific) resources are preferred.
define method find-resource
    (container :: <resource>, path :: <sequence>)
 => (resource :: <resource>, prefix :: <list>, suffix :: <list>)
  log-debug("find-resource(%=, %=)", container, path);
  let resource = #f;
  let prefix = #();
  let suffix = #();
  iterate loop (parent = container, path = as(<list>, path), seen = #())
    if (~empty?(path))
      let key = first(path);
      let child = element(parent.resource-children, key, default: #f);
      if (child)
        if (~instance?(child, <placeholder-resource>))
          resource := child;
          prefix := pair(key, seen);
          suffix := rest(path);
        end;
        loop(child, rest(path), pair(key, seen))
      end;
    end;
  end;
  if (resource)
    values(resource, reverse(prefix), suffix)
  else
    resource-not-found-error();
  end;
end method find-resource;


//// URL generation

// TODO: store this in the request router
define constant $named-resources :: <string-table> = make(<string-table>);

define open generic add-resource-name
    (name :: <string>, resource :: <resource>);

define method add-resource-name
    (name :: <string>, resource :: <resource>) => ()
  if (element($named-resources, name, default: #f))
    koala-api-error("Duplicate URL name: %s (resource = %s)", name, resource);
  else
    $named-resources[name] := resource;
  end;
end;

define method generate-url
    (router :: <resource>, name :: <string>, #key)
 => (url :: <string>)
  let resource = element($named-resources, name, default: #f);
  if (resource)
    // TODO: generate a full url not just the path.
    resource.resource-url-path
  else
    koala-api-error("Named resource not found: %s", name);
  end;
end method generate-url;

// follow the resource parent chain to find the url path prefix
define function resource-url-path
    (resource :: <resource>, #key path-so-far = #())
 => (path :: <string>)
  local method find-first-added-name(parent, resource)
          let children = parent.resource-children;
          block (return)
            for (name in parent.resource-order)
              if (children[name] == resource)
                return(name)
              end;
            end;
            error("can't get here");
          end;
        end;
  let parent = resource.resource-parent;
  if (parent)
    let name = find-first-added-name(parent, resource);
    resource-url-path(parent, path-so-far: pair(name, path-so-far))
  elseif (empty?(path-so-far))
    "/"
  else
    join(path-so-far, "/")
  end
end function resource-url-path;



define method respond-to-options
    (resource :: <resource>, #key)
  let request :: <request> = current-request();
  if (request.request-raw-url-string = "*")
    set-header(current-response(),
               "Allow",
               "GET, HEAD, OPTIONS, POST, PUT, DELETE, TRACE, CONNECT");
  else
    let methods = find-request-methods(resource);
    if (~empty?(methods))
      set-header(current-response(),
                 "Allow",
                 join(methods, ", ", key: as-uppercase))
    end;
  end;
end method respond-to-options;

define inline function %method-not-allowed
    ()
  method-not-allowed-error(
    request-method: as-uppercase(as(<string>,
                                    request-method(current-request()))));
end;

define method respond-to-get
    (resource :: <resource>, #key)
  %method-not-allowed();
end;

define method respond-to-head
    (resource :: <resource>, #key)
  %method-not-allowed()
end;

define method respond-to-post
    (resource :: <resource>, #key)
  %method-not-allowed()
end;

define method respond-to-put
    (resource :: <resource>, #key)
  %method-not-allowed()
end;

define method respond-to-delete
    (resource :: <resource>, #key)
  %method-not-allowed()
end;

define method respond-to-trace
    (resource :: <resource>, #key)
  %method-not-allowed()
end;

define method respond-to-connect
    (resource :: <resource>, #key)
  %method-not-allowed()
end;

define table $request-method-table = {
    #"options" => respond-to-options,
    #"get"     => respond-to-get,
    #"head"    => respond-to-head,
    #"post"    => respond-to-post,
    #"put"     => respond-to-put,
    #"delete"  => respond-to-delete,
    #"trace"   => respond-to-trace,
    #"connect" => respond-to-connect,
    };

// TODO: a way to add new request methods

define method respond
    (resource :: <placeholder-resource>, #key)
  resource-not-found-error();
end;

// Default method dispatches to respond-to-<request-method> functions.
define method respond
    (resource :: <resource>, #rest args, #key)
  let request :: <request> = current-request();
  let function = element($request-method-table, request.request-method,
                         default: #f);
  if (function)
    apply(function, resource, args);
  else
    // It's an extension method and there's no "respond" method for
    // the resource.
    %method-not-allowed()
  end;
end;

define method find-request-methods
    (resource :: <resource>) => (methods :: <collection>)
  #()  // TODO: determine request methods for OPTIONS request
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


//// Redirecting resources

// A resource that redirects requests to another location.  If /a/b/c/d
// is requested and this resource is matched to /a/b, and the target is
// /x/y, then the request is redirected to /x/y/c/d.  The redirection
// is implemented by issuing a 301 (moved permanently redirect) response.
//
define class <redirecting-resource> (<resource>)
  constant slot resource-target :: <uri>,
    required-init-keyword: target:;
end;

define method respond
    (resource :: <redirecting-resource>, #key)
  let target :: <uri> = resource.resource-target;
  let suffix :: <string> = request-url-path-suffix(current-request());
  if (suffix.size > 0 & suffix[0] = '/')
    suffix := copy-sequence(suffix, from: 1);
  end;
  let path = split(suffix, '/');
  let location = build-uri(make(<uri>,
                                path: concatenate(target.uri-path, path),
                                copy-from: target));
  moved-permanently-redirect(location: location,
                             header-name: "Location",
                             header-value: location);
end method respond;



//// Function resources

// A resource that simply calls a function.
//
define open class <function-resource> (<resource>)
  constant slot resource-function,
    required-init-keyword: function:;

  // Since this is a raw function responder, there's nothing to dispatch
  // on so it needs a way to specify which request methods to respond to.
  //
  constant slot resource-request-methods :: <collection> = #(#"get", #"post"),
    init-keyword: methods:;
end;

// Turn a function into a resource.
//
define function function-resource
    (function :: <function>, #key methods) => (resource :: <resource>)
  make(<function-resource>,
       function: function,
       methods: methods | #(#"get", #"post"))
end;

define method respond
    (resource :: <function-resource>, #rest path-bindings, #key)
  if (member?(request-method(current-request()),
              resource.resource-request-methods))
    apply(resource.resource-function, path-bindings);
  end;
end;


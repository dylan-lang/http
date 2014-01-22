Module:    httpi
Synopsis:  Tools for mapping URLs to available resources
Author:    Carl Gay
Copyright: See LICENSE in this distribution for details.


//// Resource protocol

// The <abstract-router> class gives libraries a way to provide alternate
// ways of routing/mapping URLs to resources if they don't like the default
// mechanism, by storing a different subclass of <abstract-router>
// in the <http-server>.

define open abstract class <abstract-router> (<object>)
end;


// Add a route to a resource.  (Or, map a URL to a resource.)
// URLs (and more specifically, URL paths) may be represented in various ways,
// which is why the 'url' parameter is typed as <object>.
//
define open generic add-resource
    (router :: <abstract-router>,
     url :: <object>,
     resource :: <abstract-resource>,
     #key, #all-keys);


// Find a resource mapped to the given URL, or signal an error.
// Return the resource, the URL prefix it was mapped to, and the URL
// suffix that remained.
//
// TODO: The return values for this are probably too specific to the
//       way the default router works.  It's probably a bit more generic
//       to return (resource, url, bindings) or some such.
//
define open generic find-resource
    (router :: <abstract-router>, url :: <object>)
 => (resource :: <abstract-resource>, prefix :: <list>, suffix :: <list>);


// Generate a URL from a name and path variables.
// If the given name doesn't exist signal <http-server-api-error>.
define open generic generate-url
    (router :: <abstract-router>, name :: <string>, #key, #all-keys)
 => (url);


// An <abstract-resource> is responsible for setting headers on and
// writing data to the current <response> by overriding the "respond"
// method or one of the "respond-to-{get,put,...}"
// methods. <resource>s are arranged in a tree structure.
//
define open abstract class <abstract-resource> (<object>)
end;

// Respond to a request for the given resource.
define open generic respond
    (resource :: <abstract-resource>, #key, #all-keys);


// This method is called if the request URL has leftover path elements after
// all path variables have been bound.  It gives the resource implementation
// a chance to signal 404, for example.  In many applications you might want
// to do this (at least during development or QA) so that incorrect URLs can
// be discovered quickly.
define open generic unmatched-url-suffix
    (resource :: <abstract-resource>, unmatched-path :: <sequence>);

define method unmatched-url-suffix
    (resource :: <abstract-resource>, unmatched-path :: <sequence>)
  log-debug("Unmatched URL suffix for resource %s: %s",
            resource, unmatched-path);
  %resource-not-found-error();
end;


// Pre-defined request methods each have a specific generic...

define open generic respond-to-options (resource :: <abstract-resource>, #key, #all-keys);
define open generic respond-to-get     (resource :: <abstract-resource>, #key, #all-keys);
define open generic respond-to-head    (resource :: <abstract-resource>, #key, #all-keys);
define open generic respond-to-post    (resource :: <abstract-resource>, #key, #all-keys);
define open generic respond-to-put     (resource :: <abstract-resource>, #key, #all-keys);
define open generic respond-to-delete  (resource :: <abstract-resource>, #key, #all-keys);
define open generic respond-to-trace   (resource :: <abstract-resource>, #key, #all-keys);
define open generic respond-to-connect (resource :: <abstract-resource>, #key, #all-keys);


// The content type that will be sent in the HTTP response if no
// Content-Type header is set by the respond* method.
//
define open generic default-content-type
    (resource :: <abstract-resource>)
 => (content-type :: type-union(<mime-type>, <string>));

define method default-content-type
    (resource :: <abstract-resource>)
 => (content-type :: <string>)
  "application/octet-stream"
end;



//// <resource> -- the default resource implementation

// <resource>s are <abstract-router>s because they route requests to
// their children.  That is, there are methods for add-resource and
// find-resource.
define open class <resource> (<abstract-resource>, <abstract-router>)
  constant slot resource-children :: <string-table> = make(<string-table>);

  // This holds the child names (the keys of resource-children) in the order
  // in which they were added.  If a resource is added under multiple names
  // the first one is "canonical", and is used in URL generation.  (An ordered
  // hash table would be nice here....)
  constant slot resource-order :: <stretchy-vector> = make(<stretchy-vector>);

  // The parent is used to find the canonical URL path (for url generation).
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
  // the fact that its elements are ordered.  See unmatched-url-suffix.
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

// convert <uri> to <sequence>
define method add-resource
    (parent :: <resource>, url :: <uri>, child :: <abstract-resource>,
     #rest args, #key)
  //log-debug("add-resource(%=, %=, %=)", parent, url, child);
  apply(add-resource, parent, url.uri-path, child, args)
end;

// "url" is either a single path element or a full URL path.
define method add-resource
    (parent :: <resource>, url :: <string>, child :: <resource>,
     #key url-name :: false-or(<string>))
  //log-debug("add-resource(%=, %=, %=)", parent, url, child);
  if (member?('/', url))
    add-resource(parent, split(url, '/'), child, url-name: url-name);
  elseif (path-variable?(url))
    http-server-api-error("Attempt to call add-resource with a path "
                            "variable (%=) as the URL.", url);
  else
    let name = url;
    let existing-child = element(parent.resource-children, name, default: #f);
    if (existing-child)
      if (instance?(existing-child, <placeholder-resource>))
        for (kid keyed-by kid-name in existing-child.resource-children)
          // Do this recursively to check for duplicate names.
          // Do not pass the url-name argument.
          add-resource(child, kid-name, kid);
        end;
      else
        http-server-api-error("A child resource, %=, is already mapped "
                                "to this URL: %s",
                              existing-child, existing-child.resource-url-path);
      end;
    else
      parent.resource-children[name] := child;
      add!(parent.resource-order, name);
      if (~child.resource-parent)
        child.resource-parent := parent;
      end;
      if (url-name)
        add-resource-name(url-name, child);
      end;
    end;
  end;
end method add-resource;

// "path" is a sequence of URL path elements (strings). 
define method add-resource
    (parent :: <resource>, path :: <sequence>, resource :: <resource>,
     #key url-name)
  //log-debug("add-resource(%=, %=, %=)", parent, path, resource);

  // The root URL, "/", is a special case because it is both a leading
  // and trailing slash, which doesn't match our resource tree structure.
  // There is a corresponding hack in find-resource.
  let path = iff(path = #("", ""), #(""), path);

  if (empty?(path))
    http-server-api-error("Empty sequence, %=, passed to add-resource.", path);
  elseif (path[0] = "" & parent.resource-parent)
    http-server-api-error("Attempt to add resource %= to non-root resource"
                            " %= using a URL with a leading slash %=.  This"
                            " will result in an unreachable URL path.",
                          resource, parent, join(path, "/"));
  else
    let (prefix, vars) = parse-path-variables(path);
    resource.resource-path-variables := vars;
    iterate loop (parent = parent, path = prefix)
      if (empty?(path))
        // done
      elseif (path.size = 1)
        let name :: <string> = first(path);
        add-resource(parent, name, resource,
                     url-name: url-name)
      else
        let name :: <string> = first(path);
        let child = element(parent.resource-children, name, default: #f);
        if (~child)
          child := make(<placeholder-resource>);
          add-resource(parent, name, child, url-name: #f);
        end;
        loop(child, path.tail)
      end if;
    end iterate;
  end if;
end method add-resource;


//// path variables

//   "{v}"     => <path-variable> (required)
//   "{v?}"    => <path-variable> (optional)
//   "{v*}"    => <star-path-variable> (matches zero or more path elements)
//   "{v+}"    => <plus-path-variable> (matches one or more path elements)

// {v} or {v?}
define sealed class <path-variable> (<object>)
  constant slot path-variable-name :: <symbol>,
    required-init-keyword: name:;
  constant slot path-variable-required? :: <boolean>,
    required-init-keyword: required?:;
end;

// {v*}
define sealed class <star-path-variable> (<path-variable>) end;

// {v+}
define sealed class <plus-path-variable> (<path-variable>) end;

define function parse-path-variables
    (path :: <sequence>) => (prefix :: <sequence>, vars :: <sequence>)
  let index = find-key(path, path-variable?) | path.size;
  let path-vars = as(<list>, copy-sequence(path, start: index));
  let path-prefix = as(<list>, copy-sequence(path, end: index));
  let vars = map(parse-path-variable, path-vars);

  // disallow {v*} or {v+} except at the end of the path.
  for (item in copy-sequence(vars, end: max(0, vars.size - 1)))
    if (instance?(item, <star-path-variable>)
          | instance?(item, <plus-path-variable>))
      http-server-api-error("Path variables of the form \"{var*}\" or \"{var+}\""
                              " may only occur as the last element in the URL path."
                              " URL: %s",
                            join(path, "/"));
    end;
  end;

  values(path-prefix, vars)
end function parse-path-variables;

define function parse-path-variable
    (path-element :: <string>) => (var :: <path-variable>)
  if (path-variable?(path-element))
    let spec = copy-sequence(path-element, start: 1, end: path-element.size - 1);
    if (spec.size = 1)
      make(<path-variable>, name: as(<symbol>, spec), required?: #t)
    else
      let modifier = spec[spec.size - 1];
      let class = <path-variable>;
      let required? = #t;
      select (modifier by \=)
        '?' => required? := #f;
        '*' => class := <star-path-variable>;
               required? := #f;
        '+' => class := <plus-path-variable>;
        otherwise => #f;
      end;
      if (member?(modifier, "?*+"))
        spec := copy-sequence(spec, end: spec.size - 1);
      end;
      make(class, name: as(<symbol>, spec), required?: required?)
    end
  else
    http-server-api-error("%= is not a path variable.  All URL path elements"
                            " following the first path variable must also be path "
                            " variables.",
                          path-element);
  end
end function parse-path-variable;

define function path-variable?
    (path-element :: <string>) => (path-variable? :: <boolean>)
  path-element.size > 2
    & path-element[0] = '{'
    & path-element[path-element.size - 1] = '}'
end;

// Make a sequence of key/value pairs for passing to respond(resource, #key)
//
define method path-variable-bindings
    (resource :: <resource>, path-suffix :: <list>)
 => (bindings :: <sequence>,
     unbound :: <sequence>,
     leftover-suffix :: <list>)
  let bindings = make(<stretchy-vector>);
  for (pvar in resource.resource-path-variables,
       suffix = path-suffix then suffix.tail)
    select (pvar by instance?)
      <star-path-variable> =>
        add!(bindings, pvar.path-variable-name);
        add!(bindings, suffix);
        suffix := #();
      <plus-path-variable> =>
        if (empty?(suffix))
          // TODO: It would be more helpful for debugging if this were part
          //       of the error message (only when server.debugging-enabled?).
          log-debug("{%s}+ not matched", pvar.path-variable-name);
          %resource-not-found-error();
        else
          add!(bindings, pvar.path-variable-name);
          add!(bindings, suffix);
          suffix := #();
        end;
      <path-variable> =>
        let path-element = iff(empty?(suffix), #f, first(suffix));
        if (pvar.path-variable-required? & ~path-element)
          log-debug("{%s} not matched", pvar.path-variable-name);
          %resource-not-found-error();
        else
          add!(bindings, pvar.path-variable-name);
          add!(bindings, path-element);
        end;
    end select;
  finally
    values(bindings,
           copy-sequence(resource.resource-path-variables,
                         start: floor/(bindings.size, 2)),
           suffix)
  end
end method path-variable-bindings;


define open generic do-resources
    (router :: <abstract-router>, function :: <function>, #key seen)
 => ();

define method do-resources
    (router :: <resource>, function :: <function>,
     #key seen :: <list> = #())
 => ()
  // It's perfectly normal to add a resource in multiple places
  // so just skip the ones we've seen before.
  if (~member?(router, seen))
    if (~instance?(router, <placeholder-resource>))
      function(router);
    end;
    for (child in router.resource-children)
      do-resources(child, function, seen: pair(router, seen));
    end;
  end;
end method do-resources;


//// find-resource

// convert <uri> to <sequence>
define method find-resource
    (router :: <resource>, url :: <uri>)
 => (resource :: <resource>, prefix :: <list>, suffix :: <list>)
  log-debug("find-resource(%=, %=)", router, url);
  find-resource(router, url.uri-path)
end;

// convert <string> to <sequence>
define method find-resource
    (router :: <resource>, path :: <string>)
 => (resource :: <resource>, prefix :: <list>, suffix :: <list>)
  log-debug("find-resource(%=, %=)", router, path);
  find-resource(router, split(path, '/'))
end;

// The base method.  Deeper (more specific) resources are preferred.
define method find-resource
    (router :: <resource>, path :: <sequence>)
 => (resource :: <resource>, prefix :: <list>, suffix :: <list>)
  log-debug("find-resource(%=, %=)", router, path);
  // Special case the root path, "/", which is both a leading and
  // trailing slash, which doesn't match our resource tree structure.
  // There's a similar special case for add-resource.
  let new-path = iff(path = #("", ""), #(""), path);
  let resource = #f;
  let prefix = #();
  let suffix = #();
  iterate loop (parent = router, path = as(<list>, new-path), seen = #())
    if (~empty?(path))
      let key = first(path);
      let child = element(parent.resource-children, key, default: #f);
      if (child)
        if (~instance?(child, <placeholder-resource>))
          resource := child;
          prefix := pair(key, seen);
          suffix := path.tail;
        end;
        loop(child, path.tail, pair(key, seen))
      end;
    end;
  end;
  if (resource)
    values(resource, reverse(prefix), suffix)
  else
    resource-not-found-error(url: join(path, "/"))
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
    http-server-api-error("Duplicate URL name: %s (resource = %s)", name, resource);
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
    http-server-api-error("Named resource not found: %s", name);
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
    (resource :: <abstract-resource>, #key)
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
    (resource :: <abstract-resource>, #key)
  %method-not-allowed();
end;

define method respond-to-head
    (resource :: <abstract-resource>, #key)
  %method-not-allowed()
end;

define method respond-to-post
    (resource :: <abstract-resource>, #key)
  %method-not-allowed()
end;

define method respond-to-put
    (resource :: <abstract-resource>, #key)
  %method-not-allowed()
end;

define method respond-to-delete
    (resource :: <abstract-resource>, #key)
  %method-not-allowed()
end;

define method respond-to-trace
    (resource :: <abstract-resource>, #key)
  %method-not-allowed()
end;

define method respond-to-connect
    (resource :: <abstract-resource>, #key)
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


define inline function %respond
    (resource :: <abstract-resource>, bindings) => ()
  // Don't require every respond method to set the Content-Type header explicitly.
  set-header(current-response(), "Content-Type", default-content-type(resource));
  apply(respond, resource, bindings);
end;

define method respond
    (resource :: <placeholder-resource>, #key)
  %resource-not-found-error();
end;

// Default method dispatches to respond-to-<request-method> functions.
define method respond
    (resource :: <abstract-resource>, #rest args, #key)
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
    (resource :: <abstract-resource>) => (methods :: <collection>)
  #()  // TODO: determine request methods for OPTIONS request
end;



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
  let path = iff(empty?(suffix), #(), split(suffix, '/'));
  let location = build-uri(make(<uri>,
                                path: concatenate(target.uri-path, path),
                                copy-from: target));
  moved-permanently-redirect(location: location,
                             header-name: "Location",
                             header-value: location);
end method respond;



//// Function resources

// A resource that simply calls a function.  The function must accept
// only keyword arguments, one for each path variable it expects.
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


//// server-send events resources (http://dev.w3.org/html5/eventsource/)

// An event resource that sets headers and provides a blocking queue.
//
define open class <sse-resource> (<resource>)
  constant slot sse-queue :: <deque> = make(<deque>);
  constant slot sse-queue-lock :: <lock> = make(<simple-lock>);
  slot sse-queue-notification :: <notification>;
end;

define method initialize (sse :: <sse-resource>,
                          #next next-method,
                          #rest rest, #key,
                          #all-keys)
  next-method();
  sse.sse-queue-notification := make(<notification>, lock: sse.sse-queue-lock);
end;


define method respond
    (resource :: <sse-resource>, #rest path-bindings, #key)
  let req = current-request();
  let socket = req.request-socket;
  let response = current-response();

  set-header(response, "Content-Type", "text/event-stream");
  set-header(response, "Cache-Control", "no-cache");

  send-response-line(response, socket);
  send-headers(response, socket);

  while (#t)
    with-lock (resource.sse-queue-lock)
      while (resource.sse-queue.empty?)
        wait-for(resource.sse-queue-notification)
      end;
      write(socket, resource.sse-queue.pop);
      write(socket, "\r\n\r\n");
      force-output(socket);
    end with-lock
  end while
end;


Module:    httpi
Synopsis:  Virtual hosts
Author:    Carl Gay
Copyright: Copyright (c) 2004-2010 Carl L. Gay.  All rights reserved.
License:   Functional Objects Library Public License Version 1.0
Warranty:  Distributed WITHOUT WARRANTY OF ANY KIND


// A <virtual-host-router> routes requests to the appropriate child resource
// based on the Host: header.
define class <virtual-host-router> (<abstract-router>)

  // fqdn -> <virtual-host>
  constant slot virtual-hosts :: <string-table> = make(<string-table>),
    init-keyword: virtual-hosts:;

  // Use this resource if no virtual host matches the Host header or URL
  // and fall-back-to-default? is true.
  slot default-virtual-host :: <virtual-host> = make(<virtual-host>),
    init-keyword: default:;

  // If true, use the default-host if the given host isn't found.
  slot fall-back-to-default? :: <boolean> = #t,
    init-keyword: fall-back-to-default?:;

end class <virtual-host-router>;

// Add a virtual host by name, as a direct child.
//
define method add-resource
    (router :: <virtual-host-router>,
     url :: <string>,
     resource :: <abstract-resource>, #rest args, #key)
  log-debug("add-resource(%=, %=, %=)", router, url, resource);
  // Lowercase the host name and give a more specific error message.
  if (member?('/', url))
    add-resource(router, parse-url(url), resource);
  else
    let fqdn = as-lowercase(url);
    if (instance?(resource, <virtual-host>))
      if (element(router.virtual-hosts, fqdn, default: #f))
        koala-api-error("Attempt to add virtual host %=, which already exists.", fqdn);
      else
        router.virtual-hosts[fqdn] := resource;
      end;
    else
      koala-api-error("Attempt to add resource %= to a <virtual-host-router> but"
                        " only <virtual-host> resources are allowed here.",
                      resource);
    end;
  end;
end method add-resource;

define method do-resources
    (router :: <virtual-host-router>, function :: <function>,
     #key seen :: <list> = #())
  if (~member?(router, seen))
    do-resources(router.default-virtual-host, function, seen: pair(router, seen));
    for (vhost in router.virtual-hosts)
      do-resources(vhost, function, seen: pair(router, seen));
    end;
  end;
end method do-resources;
    

// Add a resource under the virtual host corresponding to the host in
// the given URL.
define method add-resource
    (router :: <virtual-host-router>,
     url :: <uri>,
     resource :: <abstract-resource>, #key)
  log-debug("add-resource(%=, %=, %=)", router, url, resource);
  let host = as-lowercase(url.uri-host);
  if (empty?(host))
    if (router.fall-back-to-default?)
      add-resource(router.default-virtual-host, url, resource);
    else
      koala-api-error("Attempt to add a resource (%=) to a virtual host"
                      " router with URL %s, which has no host component"
                      " and fall-back to the default virtual host is disabled."
                      " Specify a host or enable fall-back.",
                      resource, url);
    end;
  elseif (element(router.virtual-hosts, host, default: #f))
    add-resource(router.virtual-hosts[host], url, resource);
  else
    log-info("New virtual host: %=", host);
    let vhost = make(<virtual-host>);
    add-resource(router, host, vhost);
    add-resource(vhost, url, resource);
  end;
end method add-resource;

define method find-resource
    (router :: <virtual-host-router>, request :: <request>)
 => (resource :: <resource>, prefix :: <list>, suffix :: <list>)
  log-debug("find-resource(%=, %=)", router, request);
  let host+port = get-header(request, "Host", parsed: #t);
  let host = iff(host+port,
                 first(host+port),
                 request.request-url.uri-host);
  find-resource(find-resource(router, host),
                request.request-url)
end method find-resource;

define method find-resource
    (router :: <virtual-host-router>, url :: <uri>)
 => (resource :: <resource>, prefix :: <list>, suffix :: <list>)
  log-debug("find-resource(%=, %=)", router, url);
  find-resource(find-resource(router, url.uri-host),
                url)
end method find-resource;

define method find-resource
    (router :: <virtual-host-router>, fqdn :: <string>)
 => (vhost :: <virtual-host>, prefix :: <list>, suffix :: <list>)
  log-debug("find-resource(%=, %=)", router, fqdn);
  values(element(router.virtual-hosts, fqdn, default: #f)
           | (router.fall-back-to-default?
                & router.default-virtual-host)
           | %resource-not-found-error(),
         #(),
         #())
end method find-resource;



// A virtual host simply delegates to the router in its virtual-host-router
// slot and provides for separate logging from other virtual hosts.  (It
// uses delegation rather than inheritence so that the user can supply
// a different kind of router when making a <virtual-host>.)
//
define class <virtual-host>
    (<multi-logger-mixin>, <abstract-router>, <abstract-resource>)
  constant slot virtual-host-router :: <abstract-router> = make(<resource>),
    init-keyword: router:;
end;

define method do-resources
    (router :: <virtual-host>, function :: <function>,
     #key seen :: <list> = #())
  if (~member?(router, seen))
    do-resources(router.virtual-host-router, function, seen: pair(router, seen));
  end;
end method do-resources;

define method add-resource
    (vhost :: <virtual-host>, url :: <object>, resource :: <abstract-resource>,
     #rest args, #key)
  log-debug("add-resource(%=, %=, %=)", vhost, url, resource);
  apply(add-resource, vhost.virtual-host-router, url, resource, args)
end;

define method find-resource
    (vhost :: <virtual-host>, url :: <object>)
 => (resource :: <abstract-resource>, prefix :: <list>, suffix :: <list>)
  log-debug("find-resource(%=, %=)", vhost, url);
  find-resource(vhost.virtual-host-router, url)
end;

define method generate-url
    (vhost :: <virtual-host>, name :: <string>, #rest args, #key)
 => (url)
  apply(generate-url, vhost, name, args)
end;

define method root-resource?
    (vhost :: <virtual-host>) => (root? :: <boolean>)
  #t
end;


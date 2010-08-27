Module:    httpi
Synopsis:  Virtual hosts
Author:    Carl Gay
Copyright: Copyright (c) 2004-2010 Carl L. Gay.  All rights reserved.
License:   Functional Objects Library Public License Version 1.0
Warranty:  Distributed WITHOUT WARRANTY OF ANY KIND


// A <virtual-host-map> is a <resource> that routes a request to the
// appropriate child <resource> based on the Host: header.  The child
// resource is passed only the request URL path.
//
define class <virtual-host-router> (<resource>)

  // Use this resource if no virtual host matches the Host header or URL
  // and fall-back-to-default? is true.
  slot default-resource :: <abstract-resource> = make(<resource>),
    init-keyword: default-resource:;

  // If true, use the default-host if the given host isn't found.
  slot fall-back-to-default? :: <boolean> = #t,
    init-keyword: fall-back-to-default:;

end class <virtual-host-router>;

define method add-resource
    (router :: <virtual-host-router>,
     fqdn :: <string>,
     resource :: <virtual-host-resource>, #rest args, #key)
  log-debug("add-resource(%=, %=, %=)", router, fqdn, resource);
  // Lowercase the host name and give a more specific error message.
  let fqdn = as-lowercase(fqdn);
  if (element(router.resource-children, fqdn, default: #f))
    koala-api-error("Attempt to add virtual host %=, which already exists.", fqdn);
  else
    apply(next-method, router, fqdn, resource, args)
  end;
end method add-resource;

define method find-resource
    (router :: <virtual-host-router>, request :: <request>)
 => (resource :: <resource>, prefix :: <list>, suffix :: <list>)
  log-debug("find-resource(%=, %=)", router, request);
  let fqdn = get-header(request, "Host", parsed: #t)
               | request.request-url.uri-host;
  let resource = (fqdn
                   & ~empty?(fqdn)
                   & element(router.resource-children, fqdn, default: #f))
                 | (router.fall-back-to-default? & router.default-resource);
  if (resource)
    find-resource(resource, request.request-url)
  else
    resource-not-found-error();
  end
end method find-resource;

// A <virtual-host> is a normal resource for which the standard logs may
// be redirected to different targets.  That is, you probably want different

// logs for each virtual host.
//
define class <virtual-host-resource> (<multi-logger-mixin>, <resource>)
end class <virtual-host-resource>;


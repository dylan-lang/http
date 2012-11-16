Module:    httpi
Synopsis:  Virtual hosts
Author:    Carl Gay
Copyright: Copyright (c) 2004-2010 Carl L. Gay.  All rights reserved.
License:      See License.txt in this distribution for details.
Warranty:  Distributed WITHOUT WARRANTY OF ANY KIND


// A virtual host simply delegates to the router in its virtual-host-router
// slot and provides for separate logging from other virtual hosts.  (It
// uses delegation rather than inheritance so that the user can supply
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
 => ()
  if (~member?(router, seen))
    do-resources(router.virtual-host-router, function, seen: pair(router, seen));
  end;
end method do-resources;

define method add-resource
    (vhost :: <virtual-host>, url :: <object>, resource :: <abstract-resource>,
     #rest args, #key)
  //log-debug("add-resource(%=, %=, %=)", vhost, url, resource);
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


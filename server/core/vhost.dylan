Module:    httpi
Synopsis:  Virtual hosts
Author:    Carl Gay
Copyright: See LICENSE in this distribution for details.


// A virtual host simply delegates to its router and provides a separate
// request log from other virtual hosts.  It uses delegation to the router
// rather than inheritance so that the user can supply a different kind of
// router when making a <virtual-host>.
//
define class <virtual-host> (<abstract-router>, <abstract-resource>)
  constant slot virtual-host-router :: <abstract-router> = make(<resource>),
    init-keyword: router:;
  slot request-log :: <log> = *log*,
    init-keyword: request-log:;
end class;

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
  apply(add-resource, vhost.virtual-host-router, url, resource, args)
end;

define method find-resource
    (vhost :: <virtual-host>, url :: <object>)
 => (resource :: <abstract-resource>, prefix :: <list>, suffix :: <list>)
  find-resource(vhost.virtual-host-router, url)
end;

define method generate-url
    (vhost :: <virtual-host>, name :: <string>, #rest args, #key)
 => (url)
  apply(generate-url, vhost, name, args)
end;


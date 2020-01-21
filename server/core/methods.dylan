Module: httpi
Synopsis: Request method support
Copyright: See LICENSE in this distribution for details.


define class <http-method> (<object>)
  constant slot method-name :: <byte-string>, required-init-keyword: name:;
  constant slot method-responder :: <function>, required-init-keyword: responder:;
  constant slot method-safe? :: <boolean> = #f, init-keyword: safe?:;
  constant slot method-idempotent? :: <boolean> = #f, init-keyword: idempotent?:;
  constant slot method-cacheable? :: <boolean> = #f, init-keyword: cacheable?:;
end class;

define constant $request-methods :: <string-table> = make(<string-table>);

define function register-http-method
    (meth :: <http-method>) => ()
  let name :: <byte-string> = meth.method-name;
  if (element($request-methods, name, default: #f))
    error("Request method %= defined more than once.", name);
  else
    $request-methods[name] := meth;
  end;
end function register-http-method;

define method validate-http-method
    (name :: <byte-string>) => (http-method :: <http-method>)
  element($request-methods, name, default: #f)
    | not-implemented-error(what: format-to-string("Request method %=", name))
end method validate-http-method;

define inline function %method-not-allowed
    (name :: <byte-string>) => ()
  method-not-allowed-error(request-method: name)
end;

// A concise syntax for defining HTTP request methods.
define macro http-method-definer
  {
    define ?adjectives:* http-method ?:name
  } => {
    define class "<" ## ?name ## "-method>" (<http-method>) end;

    define constant "$http-" ## ?name ## "-method" :: <http-method>
      = make("<" ## ?name ## "-method>",
             name: uppercase(?"name"),
             responder: "respond-to-" ## ?name,
             ?adjectives);

    define open generic "respond-to-" ## ?name
        (resource :: <abstract-resource>, #key, #all-keys)
     => ();

    define method "respond-to-" ## ?name
        (resource :: <abstract-resource>, #key) => ()
      %method-not-allowed(uppercase(?"name"));
    end;

    register-http-method("$http-" ## ?name ## "-method");
  }
 adjectives:
  {} => {}
  { ?:name ... } => { ?#"name" ## "?" #t, ... }
end macro http-method-definer;

define idempotent      http-method ACL;
define idempotent      http-method BASELINE-CONTROL;
// TODO(cgay): Why does this blow up?
//define idempotent      http-method BIND;
define idempotent      http-method CHECKIN;
define idempotent      http-method CHECKOUT;
define                 http-method CONNECT;
define idempotent      http-method COPY;
define idempotent      http-method DELETE;
define idempotent safe http-method GET;
define idempotent safe http-method HEAD;
define idempotent      http-method LABEL;
define idempotent      http-method LINK;
define                 http-method LOCK;
define idempotent      http-method MERGE;
define idempotent      http-method MKACTIVITY;
define idempotent      http-method MKCALENDAR;
define idempotent      http-method MKCOL;
define idempotent      http-method MKREDIRECTREF;
define idempotent      http-method MKWORKSPACE;
define idempotent      http-method MOVE;
define idempotent safe http-method OPTIONS;
define idempotent      http-method ORDERPATCH;
define                 http-method PATCH;
define                 http-method POST;
define idempotent safe http-method PROPFIND;
define idempotent      http-method PROPPATCH;
define idempotent      http-method PUT;
define idempotent      http-method REBIND;
define idempotent safe http-method REPORT;
define idempotent safe http-method SEARCH;
define idempotent safe http-method TRACE;
define idempotent      http-method UNBIND;
define idempotent      http-method UNCHECKOUT;
define idempotent      http-method UNLINK;
define idempotent      http-method UNLOCK;
define idempotent      http-method UPDATE;
define idempotent      http-method UPDATEREDIRECTREF;
define idempotent      http-method VERSION-CONTROL;

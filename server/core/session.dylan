Module:    httpi
Author:    Carl Gay
Synopsis:  HTTP sessions
Copyright: Copyright (c) 2001 Carl L. Gay.  All rights reserved.
License:      See License.txt in this distribution for details.
Warranty:  Distributed WITHOUT WARRANTY OF ANY KIND

// TODO: this whole thing is half baked

define open primary class <session> (<attributes-mixin>)
  constant slot session-id :: <integer>, required-init-keyword: #"id";
  // ---TODO: 
  // cookie
  // 
end;

define method initialize
    (session :: <session>, #key id :: <integer>, server :: <http-server>, #all-keys)
  next-method();
  if (element(server.server-sessions, id, default: #f))
    error("Attempt to create a session with a duplicate session id, %d", id);
  else
    server.server-sessions[id] := session;
  end;
end method initialize;

// ---TODO: Should probably vary the session id in a true random way.
//          And make it persistent across server reboots.

define function next-session-id
    (server :: <http-server>) => (id :: <integer>)
  let id = random($maximum-integer);
  if (element(server.server-sessions, id, default: #f))
    next-session-id(server);
  end if;
  id
end function next-session-id;

// API
// This is the only way for user code to get the session object.
define method get-session
    (request :: <request>) => (session :: false-or(<session>))
  request.request-session
    | (request.request-session := current-session(request))
end;

define method ensure-session
    (request :: <request>) => (session :: <session>)
  let session = get-session(request);
  unless (session)
    session := new-session(request);
  end unless;
  session;
end;

define method clear-session
    (request :: <request>) => ();
  let session = get-session(request);
  if (session)
    remove-key!(*server*.server-sessions, session.session-id);
    request.request-session := #f;
    add-cookie(*response*, *server*.server-session-id, -1,
               max-age: *server*.session-max-age,
               path: "/",
               // domain: ??? ---TODO:
               comment: "This cookie assigns a unique number to your browser "
                 "so that we can remember who you are as you move from page "
                 "to page within our site.");
  end if;
end method clear-session;

define method current-session
    (request :: <request>) => (session :: false-or(<session>))
  let cookies = get-header(request, "cookie", parsed: #t);
  let cookie =
    cookies & find-element(cookies,
                           method (cookie)
                             cookie-name(cookie) = *server*.server-session-id
                           end);
  if (cookie)
    let session-id = string-to-integer(cookie-value(cookie));
    element(*server*.server-sessions, session-id, default: #f) | new-session(request)
  else
    new-session(request)
  end
end method current-session;

define method new-session
    (request :: <request>) => (session :: <session>)
  let id = next-session-id(*server*);
  // TODO: This "unless" is a temporary hack to prevent blowing up when
  //       chunked transfer encoding is being used and we've sent the
  //         headers early.  (Only happens with very small chunk size,
  //         but still, it should work...)  Need to rethink sessions a bit.
  unless (headers-sent?(*response*))
    add-cookie(*response*, *server*.server-session-id, id,
               max-age: *server*.session-max-age,
               path: "/",
               // domain: ??? ---TODO:
               comment: "This cookie assigns a unique number to your browser so "
                 "that we can remember who you are as you move from page "
                 "to page within our site.");
  end;
  let session = make(<session>, id: id, server: *server*);
  request.request-session := session
end method new-session;


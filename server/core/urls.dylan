Module:    httpi
Synopsis:  HTTP Support
Author:    Gail Zacharias
Copyright: Original Code is Copyright (c) 2001 Functional Objects, Inc.  All rights reserved.
License:   Functional Objects Library Public License Version 1.0
Warranty:  Distributed WITHOUT WARRANTY OF ANY KIND


define open generic redirect-to (object :: <object>);

define method redirect-to (url :: <string>)
  let headers = current-response().raw-headers;
  set-header(headers, "Location", url);
  see-other-redirect(headers: headers);
end method redirect-to;

define method redirect-to (url :: <url>)
  redirect-to(build-uri(url));
end;

define open generic redirect-temporarily-to (object :: <object>);

define method redirect-temporarily-to (url :: <string>)
  let headers = current-response().raw-headers;
  set-header(headers, "Location", url);
  moved-temporarily-redirect(headers: headers);
end method redirect-temporarily-to;

define method redirect-temporarily-to (url :: <url>)
  redirect-temporarily-to(build-uri(url));
end;

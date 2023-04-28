Module:    httpi
Author:    Carl Gay
Copyright: See LICENSE in this distribution for details.
Synopsis:  Variables and utilities


define constant $http-version :: <byte-string> = "HTTP/1.1";
define constant $default-http-port :: <integer> = 8000;
define constant $default-https-port :: <integer> = 8443;


// Command-line arguments parser.  The expectation is that libraries that use
// and extend this server (e.g., wiki) may want to add their own <option-parser>s to
// this before calling http-server-main().
define variable *command-line-parser* :: <command-line-parser>
  = make(<command-line-parser>,
         help: format-to-string("Dylan HTTP server (%s)", $server-version));


// Max size of data in a POST.
define variable *max-post-size* :: false-or(<integer>) = 16 * 1024 * 1024;


define function file-contents (filename :: <pathname>)
 => (contents :: false-or(<string>))
  block ()
    with-open-file(input-stream = filename,
                   direction: #"input")
      read-to-end(input-stream)
    end
  exception (ex :: <file-does-not-exist-error>)
    #f
  end
end function file-contents;


define thread variable *virtual-host* :: false-or(<virtual-host>) = #f;


// We want media types (with attributes) rather than plain mime types,
// and we give them all quality values.
define constant $default-media-type-map
  = begin
      let tmap = make(<mime-type-map>);
      for (mtype keyed-by extension in $default-mime-type-map)
        let media-type = make(<media-type>,
                              type: mtype.mime-type,
                              subtype: mtype.mime-subtype);
        set-attribute(media-type, "q", 0.1);
        tmap[extension] := media-type;
      end;

      // Set higher quality values for some media types.  These affect
      // content negotiation.

      // TODO -- more, and make them configurable
      set-attribute(tmap["html"], "q", 0.2);
      set-attribute(tmap["htm"], "q", 0.2);

      tmap
    end;

define function %resource-not-found-error
    (#rest args, #key url, #all-keys)
  let url = iff(instance?(url, <uri>), build-path(url), url);
  apply(resource-not-found-error,
        url: url | build-path(request-url(current-request())),
        args)
end;




//// Errors

define class <http-server-error> (<format-string-condition>, <error>)
end;

// Signaled when a library uses the server API incorrectly. i.e., user
// errors such as registering a page that has already been registered.
// Not for errors that will be reported to the HTTP client.
//
define open class <http-server-api-error> (<http-server-error>)
end;

define function http-server-api-error
    (format-string :: <string>, #rest format-arguments)
  signal(make(<http-server-api-error>,
              format-string: format-string,
              format-arguments: format-arguments));
end;



//// URLs

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



//// <page-context>

// Gives the user a place to store values that will have a lifetime
// equal to the duration of the handling of the request.  The name is
// stolen from JSP's PageContext class, but it's not intended to serve the
// same purpose.  Use set-attribute(page-context, key, val) to store attributes
// for the page and get-attribute(page-context, key) to retrieve them.

define class <page-context> (<attributes-mixin>)
end;

define thread variable *page-context* :: false-or(<page-context>) = #f;

define method page-context
    () => (context :: false-or(<page-context>))
  if (*request*)
    *page-context* | (*page-context* := make(<page-context>))
  else
    application-error(message: "There is no active HTTP request.")
  end;
end;




Module:    httpi
Author:    Carl Gay
Copyright: Copyright (c) 2001-2008 Carl L. Gay.  All rights reserved.
License:   Functional Objects Library Public License Version 1.0
Warranty:  Distributed WITHOUT WARRANTY OF ANY KIND
Synopsis:  Variables and utilities 


// Command-line arguments parser.  The expectation is that libraries that use
// and extend koala (e.g., wiki) may want to add their own <option-parser>s to
// this before calling koala-main().
define variable *argument-list-parser* :: <argument-list-parser>
  = make(<argument-list-parser>);


// Max size of data in a POST.
define variable *max-post-size* :: false-or(<integer>) = 16 * 1024 * 1024;


define function file-contents
    (filename :: <pathname>, #key error? :: <boolean>)
 => (contents :: false-or(<string>))
  // In FD 2.0 SP1 if-does-not-exist: #f still signals an error if the file doesn't exist.
  // Remove this block when fixed.  (Reported to Fun-O August 2001.)
  block ()
    with-open-file(input-stream = filename,
                   direction: #"input",
                   if-does-not-exist: if (error?) #"error" else #f end)
      read-to-end(input-stream)
    end
  exception (ex :: <file-does-not-exist-error>)
    if (error?)
      signal(ex)
    else
      #f
    end
  end
end function file-contents;

define method parent-directory
    (dir :: <locator>, #key levels = 1) => (dir :: <directory-locator>)
  for (i from 1 to levels)
    // is there a better way to get the containing directory?
    dir := simplify-locator(subdirectory-locator(dir, ".."));
  end;
  dir
end;


// These loggers are used if no other loggers are configured.
// Usually that should only happen very early during startup when
// *server* isn't bound, if at all.

// Logger used as last resort if no other loggers are defined.
// This is the initial value used for the *request-logger*, *debug-logger*, and
// *error-logger* variables, which in turn are used as the default loggers for
// each <http-server>, which in turn are used as the default loggers for
// each <virtua-host> on that server.
//
define constant $default-logger
  = make(<logger>,
         name: "http.server",
         targets: list($stdout-log-target));

// These are thread variables for efficiency.  They can be bound once
// per request rather than figuring out which logger to use each time
// one of the log-* methods below is called.  That would be slow due
// to the need for two levels of fallback:
//   ((*virtual-host* & *virtual-host*.debug-logger)
//    | (*server* & *server*.default-virtual-host.debug-logger)
//    | *debug-logger*)

define thread variable *debug-logger* :: <logger> = $default-logger;

define thread variable *error-logger* :: <logger> = $default-logger;

define thread variable *request-logger* :: <logger> = $default-logger;

define method log-trace (format-string, #rest format-args)
  apply(%log-trace, *debug-logger*, format-string, format-args);
end;

define method log-debug (format-string, #rest format-args)
  apply(%log-debug, *debug-logger*, format-string, format-args);
end;

define method log-info (format-string, #rest format-args)
  apply(%log-info, *debug-logger*, format-string, format-args);
end;

define method log-warning (format-string, #rest format-args)
  apply(%log-warning, *error-logger*, format-string, format-args);
end;

define method log-error (format-string, #rest format-args)
  apply(%log-error, *error-logger*,  format-string, format-args);
end;

// For debugging only.
// For logging request and response content data only.
// So verbose it needs to be explicitly enabled.
define variable *content-logger* :: <logger>
  = make(<logger>,
         name: "http.server.content",
         targets: list($stdout-log-target),
         additive: #f);

// Not yet configurable.
define variable *log-content?* :: <boolean> = #f;

define inline method log-content (content)
  log-debug-if(*log-content?*, *content-logger*, "==>%=", content);
end;

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


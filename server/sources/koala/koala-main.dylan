Module:    httpi
Synopsis:  A command-line interface to start Koala as an application.
Author:    Carl Gay
Copyright: Copyright (c) 2001-2010 Carl L. Gay.  All rights reserved.
License:   Functional Objects Library Public License Version 1.0
Warranty:  Distributed WITHOUT WARRANTY OF ANY KIND

//// Initialization


// --listen <interface> ...
add-option-parser-by-type(*argument-list-parser*,
                          <repeated-parameter-option-parser>,
                          description: format-to-string("host:port on which to "
                                                          "listen.  Option may be "
                                                          "repeated. "
                                                          "[default: 0.0.0.0:%d]",
                                                        $default-http-port),
                          long-options: #("listen"),
                          short-options: #("l"));

// --config <file>
add-option-parser-by-type(*argument-list-parser*,
                          <parameter-option-parser>,
                          description: "Location of the koala configuration file.  "
                                       "[default: None]",
                          long-options: #("config"),
                          short-options: #("c"));

// --help
add-option-parser-by-type(*argument-list-parser*,
                          <simple-option-parser>,
                          description: "Display this help message",
                          long-options: #("help"),
                          short-options: #("h"));

// --debug
add-option-parser-by-type(*argument-list-parser*,
                          <simple-option-parser>,
                          description: "Enable debug mode.  Causes Koala to not handle "
                                       "most errors during request handling.",
                          long-options: #("debug"));

// --working-directory <dir>
add-option-parser-by-type(*argument-list-parser*,
                          <parameter-option-parser>,
                          description: "Working directory to change to upon startup",
                          long-options: #("working-directory"),
                          short-options: #("w"));


/*
This is the precedence order (lowest to highest) in which initialization
should happen.  Not quite there yet...

<http-server> default slot values
              |
              V
make(<http-server>) init args
              |
              V
config file settings
              |
              V
command-line args
*/

// This is defined here rather than in koala-app because wiki needs it too.
//
define function koala-main
    (#key server :: false-or(<http-server>),
          description :: false-or(<string>),
          before-startup :: false-or(<function>))
 => ()
  let parser = *argument-list-parser*;
  parse-arguments(parser, application-arguments());
  if (option-value-by-long-name(parser, "help")
        | ~empty?(parser.regular-arguments))
    let desc = description
                 | "The Koala web server, a multi-threaded web server with\n"
                   "Dylan Server Pages and XML RPC, written in Dylan.";
    print-synopsis(parser,
                   *standard-output*,
                   usage: format-to-string("%s [options]", application-name()),
                   description: desc);
  else
    let debug? :: <boolean> = option-value-by-long-name(parser, "debug");
    let handler <error>
      = method (cond :: <error>, next-handler :: <function>)
          if (debug?)
            next-handler()  // decline to handle it
          else
            format(*standard-error*, "Error: %s\n", cond);
            exit-application(1);
          end;
        end;

    let cwd = option-value-by-long-name(parser, "working-directory");
    if (cwd)
      log-info("Working directory is %s", cwd);
      working-directory() := as(<directory-locator>, cwd);
    end;

    // We want to bind *server* early so that log output goes to the
    // right place (the server's default virtual host's logs).
    let server = server | make(<http-server>);
    dynamic-bind (*server* = server)
      *server*.debugging-enabled? := debug?;
      if (*server*.debugging-enabled?)
        log-warning("*** DEBUGGING ENABLED ***  Error conditions will "
                    "cause server to enter debugger (or exit).");
      end;

      block ()
	// Configure first so that command-line argument override config settings.
	let config-file = option-value-by-long-name(parser, "config");
	if (config-file)
	  configure-server(*server*, config-file);
	end;

	// Gives callers a chance to do things after the server has been
	// configured.  e.g., the wiki wants to add responders after a
	// URL prefix has been configured.
	if (before-startup)
	  before-startup(*server*);
	end;

	// Any command-line listeners specified?
	let listeners = option-value-by-long-name(parser, "listen");
	if (empty?(listeners) & ~config-file)
          listeners := vector(list("0.0.0.0", $default-http-port));
	end;
        for (listener in listeners)
          add!(*server*.server-listeners, make-listener(listener));
        end;

        log-debug("Mapped resources:");
        do-resource(method (res)
                      log-debug("  %-25s -- %s", res.resource-url-path, res);
                    end,
                    *server*.request-router);

        if (empty?(*server*.server-listeners))
          error("No listeners were created.  Exiting.");
        else
          start-server(*server*);
        end;
      exception (ex :: <serious-condition>)
        log-error("Error starting server: %s", ex);
      end;
    end dynamic-bind;
  end if;
end function koala-main;

begin
  let filename = locator-name(as(<file-locator>, application-name()));
  if (split(filename, ".")[0] = "koala")
    koala-main();
    // Work around bug in new-io.  It should force-output before the
    // application exits.
    force-output(*standard-output*);
  end;
end;

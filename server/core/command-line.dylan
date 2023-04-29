Module:    httpi
Synopsis:  A command-line interface to start http-server as an application.
Author:    Carl Gay
Copyright: See LICENSE in this distribution for details.


//// Initialization


// --listen <interface> ...
add-option(*command-line-parser*,
           make(<repeated-parameter-option>,
                names: #("listen", "l"),
                variable: "host:port",
                help: format-to-string("Address and port on which to "
                                       "listen. May be repeated. "
                                       "[default: 0.0.0.0:%d]",
                                       $default-http-port)));

// --config <file>
add-option(*command-line-parser*,
           make(<parameter-option>,
                names: #("config", "c"),
                variable: "file",
                help: "Location of the server configuration file.  "
                      "[default: None]"));

// --debug
add-option(*command-line-parser*,
           make(<flag-option>,
                names: #("debug"),
                help: "Enable debug mode.  Causes the server to not handle "
                      "most errors during request handling."));

// --working-directory <dir>
add-option(*command-line-parser*,
           make(<parameter-option>,
                names: #("working-directory", "w"),
                variable: "dir",
                help: "Working directory to change to upon startup"));

// --directory <static-dir>
add-option(*command-line-parser*,
           make(<parameter-option>,
                names: #("directory"),
                variable: "dir",
                help: "Serve static content from the given directory."));

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

define function http-server-main
    (#key server :: false-or(<http-server>),
          before-startup :: false-or(<function>))
 => ()
  let parser = *command-line-parser*;
  block ()
    parse-command-line(parser, application-arguments());
  exception (err :: <abort-command-error>)
    exit-application(err.exit-status);
  end;
  let debug? :: <boolean> = get-option-value(parser, "debug");
  let handler <error>
    = method (cond :: <error>, next-handler :: <function>)
        if (debug?)
          next-handler()  // decline to handle it
        else
          format(*standard-error*, "Error: %s\n", cond);
          force-output(*standard-error*);
          exit-application(1);
        end;
      end;

  let cwd = get-option-value(parser, "working-directory");
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

    // Configure first so that command-line argument override config settings.
    let config-file = get-option-value(parser, "config");
    if (config-file)
      configure-server(*server*, config-file);
    end;

    // If --directory is specified, map it to / on the server.
    // This is a special case to make serving a directory super-easy.
    let directory = get-option-value(parser, "directory");
    if (directory)
      add-resource(*server*, "/", make(<directory-resource>,
                                       directory: directory,
                                       allow-directory-listing?: #t,
                                       follow-symlinks?: #f));
    end;

    // Gives callers a chance to do things after the server has been
    // configured.  e.g., the wiki wants to add responders after a
    // URL prefix has been configured.
    if (before-startup)
      before-startup(*server*);
    end;

    // Any command-line listeners specified?
    let listeners = get-option-value(parser, "listen");
    for (listener in listeners)
      add!(*server*.server-listeners, make-listener(listener));
    end;

    log-debug("Mapped resources:");
    do-resources(*server*,
                 method (res)
                   log-debug("  %-25s -- %s", res.resource-url-path, res);
                 end);

    start-server(*server*);
  end dynamic-bind;
end function http-server-main;

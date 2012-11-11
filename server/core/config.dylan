Module:    httpi
Synopsis:  For processing the configuration init file, koala-config.xml
Author:    Carl Gay
Copyright: Copyright (c) 2001-2010 Carl L. Gay.  All rights reserved.
License:      See License.txt in this distribution for details.
Warranty:  Distributed WITHOUT WARRANTY OF ANY KIND

/*
 * TODO: warn() should note whether it has been called (perhaps with a
 *       fatal? flag) and then after the entire config has been processed
 *       Koala should exit if there were errors.  It's a good way to debug
 *       the config file.  Many of the current warnings should be fatal.
 *
 * TODO: Should warn when unrecognized attributes are used.
 *       Makes debugging your config file much easier sometimes.
 */

define constant $koala-config-dir :: <string> = "config";

define constant $default-config-filename :: <string> = "koala-config.xml";

define thread variable %server = #f;

// Holds the current vhost while config elements are being processed.
define thread variable %vhost = #f;

define class <configuration-error> (<koala-api-error>)
end;

define function config-error
    (format-string :: <string>, #rest format-args)
  signal(make(<configuration-error>,
              format-string: format-string,
              format-arguments: format-args))
end;

define function warn
    (format-string, #rest format-args)
  apply(log-warning,
        concatenate("CONFIG: ", format-string),
        format-args);
end;


// API
// Process the server config file, config.xml.
// Assume a user directory structure like:
// koala/
// koala/bin               // server executable and dlls
// koala/www               // default web document root
// koala/config            // koala-config.xml etc
define method configure-server
    (server :: <http-server>, config-file :: false-or(<string>))
  let defaults
    = merge-locators(merge-locators(as(<file-locator>, $default-config-filename),
                                    as(<directory-locator>, $koala-config-dir)),
                     server.server-root);
  let config-loc
    = as(<string>, merge-locators(as(<file-locator>, config-file | defaults),
                                  defaults));
  let text = file-contents(config-loc);
  if (text)
    log-info("Loading server configuration from %s.", config-loc);
    configure-from-string(server, text, filename: config-loc);
  elseif (config-file)
    // Only blow out if user specified a config file, not if they're taking
    // the default config file.
    config-error("Server configuration file (%s) not found.", config-loc);
  end if;
end method configure-server;

// This is separated out so it can be used by the test suite.
//
define method configure-from-string
    (server :: <http-server>, text :: <string>,
     #key filename :: false-or(<string>))
  let xml :: false-or(xml$<document>) = xml$parse-document(text);
  if (xml)
    dynamic-bind (%vhost = server.default-virtual-host)
      process-config-node(server, xml);
    end;
  else
    config-error("Unable to parse configuration from %s",
                 filename | "string");
  end;
end method configure-from-string;

// Exported
// The xml-parser library doesn't seem to define anything like this.
define method get-attr
    (node :: xml$<element>, attrib :: <symbol>)
 => (value :: false-or(<string>))
  block (return)
    for (attr in xml$attributes(node))
      when (xml$name(attr) = attrib)
        return(xml$attribute-value(attr));
      end;
    end;
  end
end;

// I think the XML parser's class hierarchy is broken.  It seems <tag>
// should inherit from <node-mixin> so that one can descend the node
// hierarchy seamlessly.
define method process-config-node
    (server :: <http-server>, node :: xml$<tag>) => ()
end;

define method process-config-node
    (server :: <http-server>, node :: xml$<document>) => ()
  for (child in xml$node-children(node))
    process-config-node(server, child);
  end;
end;

define method process-config-node
    (server :: <http-server>, node :: xml$<element>) => ()
  process-config-element(server, node, xml$name(node));
end;

define method process-config-node
    (server :: <http-server>, node :: xml$<xml>) => ()
  config-error("Unexpected XML document element: %s", xml$name(node));
end;

// Exported.
// Libraries may specialize this.
// Note that the previous comment about the XML parser's class hierarchy
// applies here as well.  Otherwise this would specialize node more tightly.
//
define open generic process-config-element
    (server :: <http-server>, node :: <object>, name :: <object>);

define method process-config-element
    (server :: <http-server>, node :: xml$<element>, name :: <object>)
  warn("Unrecognized configuration setting: %=.  Processing child nodes anyway.",
       name);
  for (child in xml$node-children(node))
    process-config-node(server, child);
  end;
end;

define method process-config-element
    (server :: <http-server>, node :: xml$<comment>, name :: <object>)
end;

define function true-value?
    (val :: <string>) => (true? :: <boolean>)
  member?(val, #("yes", "true", "on"), test: string-equal?)
end;



//// koala-config.xml elements.  One method for each element name.

define method process-config-element
    (server :: <http-server>, node :: xml$<element>, name == #"koala")
  for (child in xml$node-children(node))
    process-config-node(server, child);
  end;
end method process-config-element;


define method process-config-element
    (server :: <http-server>, node :: xml$<element>, name == #"listener")
  let address = get-attr(node, #"address");
  let port = get-attr(node, #"port");
  if (address | port)
    block ()
      let ssl = get-attr(node, #"ssl");
      let ssl? = ssl & true-value?(ssl);
      let port = port & string-to-integer(port);
      if (ssl?)
        let port = port | $default-https-port;
        let cert = get-attr(node, #"certificate");
        let key = get-attr(node, #"key");
        if (~cert | ~key)
          error("Both 'certificate' and 'key' are required for SSL listener %s:%d.",
                address, port);
        end;
        log-info("Adding HTTPS listener for %s:%d", address, port);
        add!(server.server-listeners,
             make(<ssl-listener>,
                  host: address,
                  port: port,
                  certificate-filename: cert,
                  key-filename: key));
      else
        let port = port | $default-http-port;
        log-info("Adding HTTP listener for %s:%d", address, port);
        add!(server.server-listeners, make(<listener>, host: address, port: port));
      end;
    exception (ex :: <serious-condition>)
      warn("Invalid <listener> spec: %s", ex);
    end;
  else
    warn("Invalid <listener> spec.  You must supply at least one "
         "of 'address' or 'port'.");
  end;
end method process-config-element;

define method process-config-element
    (server :: <http-server>, node :: xml$<element>, name == #"virtual-host")
  let name = get-attr(node, #"name");
  if (name)
    let name = as-lowercase(name);
    if (find-virtual-host(server, name))
      warn("Replacing existing virtual host named %=.", name);
    end;
    let vhost :: <virtual-host> = make(<virtual-host>);
    add-virtual-host(server, name, vhost);
    dynamic-bind (%vhost = vhost)
      for (child in xml$node-children(node))
        process-config-element(server, child, xml$name(child))
      end;
    end;
  else
    warn("Invalid <VIRTUAL-HOST> spec.  "
           "The 'name' attribute must be specified.");
  end;
end;

// For when a virtual host may be addressed by several names.
define method process-config-element
    (server :: <http-server>, node :: xml$<element>, name == #"host-alias")
  let name = get-attr(node, #"name");
  if (name)
    let name = as-lowercase(name);
    if (find-virtual-host(server, name))
      warn("Ignoring <host-alias> %=.  A virtual host by that name already exists.",
           name);
    else
      add-virtual-host(server, name, %vhost);
    end;
  else
    warn("Invalid <HOST-ALIAS> element.  The 'name' attribute must be specified.");
  end;
end;

// There's a separate <server> element (rather than putting these
// settings in the <koala> element) so that it's possible for logging
// to be initialized before these settings are processed.
//
define method process-config-element
    (server :: <http-server>, node :: xml$<element>, name == #"server")
  // root
  let loc = get-attr(node, #"root");
  if (loc)
    server.server-root := merge-locators(as(<directory-locator>, loc),
                                         server.server-root);
  end;
  log-info("Server root: %s", as(<string>, server.server-root));

  // working directory
  let loc = get-attr(node, #"working-directory");
  if (loc)
    working-directory() := merge-locators(as(<directory-locator>, loc),
                                          server.server-root);
  end;
  log-info("Server root: %s", as(<string>, server.server-root));

  // use-default-virtual-host
  let attr = get-attr(node, #"use-default-virtual-host");
  let value = true-value?(attr | "yes");
  server.use-default-virtual-host? := value;
  log-info("Fallback to the default virtual host is %s.",
           iff(value, "enabled", "disabled"));

  // debug
  let value = true-value?(get-attr(node, #"debug") | "yes");
  server.debugging-enabled? := value;
  log-info("Server debugging is %s",
           iff(value,
               "enabled.  Server may crash if not run inside the IDE!",
               "disabled."));

end method process-config-element;

// TODO: There is currently no way to configure (for example) the
//       "http.common.headers" logger.  We should really just have one
//       configuration element, <log>, that names a logger that exists
//       in the code and says how to configure it.  The loggers for each
//       virtual host should be named <vhost-name>.debug etc.  Needs more
//       thought, but I think it will be an improvement.

define method process-config-element
    (server :: <http-server>, node :: xml$<element>, name == #"error-log")
  let format-control = get-attr(node, #"format");
  let name = get-attr(node, #"name") | "http.server.error";
  let logger = process-log-config-element(server, node, format-control, name,
                                          $stderr-log-target);
  error-logger(%vhost) := logger;
  *error-logger* := logger;
end method process-config-element;

define method process-config-element
    (server :: <http-server>, node :: xml$<element>, name == #"debug-log")
  let format-control = get-attr(node, #"format");
  let name = get-attr(node, #"name") | "http.server.debug";
  let logger = process-log-config-element(server, node, format-control, name,
                                          $stdout-log-target);
  debug-logger(%vhost) := logger;
  *debug-logger* := logger;
end method process-config-element;

define method process-config-element
    (server :: <http-server>, node :: xml$<element>, name == #"request-log")
  let format-control = get-attr(node, #"format") | "%{message}";
  let name = get-attr(node, #"name") | "http.server.request";
  let logger = process-log-config-element(server, node, format-control, name,
                                          $stdout-log-target);
  request-logger(%vhost) := logger;
  *request-logger* := logger;
end method process-config-element;

define function process-log-config-element
    (server :: <http-server>, node :: xml$<element>,
     format-control, logger-name :: <string>, default-log-target :: <log-target>)
 => (logger :: <logger>)
  let additive? = true-value?(get-attr(node, #"additive") | "no");
  let location = get-attr(node, #"location");
  let default-size = 20 * 1024 * 1024;
  let max-size = get-attr(node, #"max-size");
  if (max-size)
    block ()
      max-size := string-to-integer(max-size);
    exception (ex :: <error>)
      warn("<%s> element has invalid max-size attribute (%s).  "
           "The default (%d) will be used.",
           xml$name(node), max-size, default-size);
      max-size := default-size;
    end;
  else
    max-size := default-size;
  end if;
  let target = iff(location,
                   make(<rolling-file-log-target>,
                        pathname: merge-locators(as(<file-locator>, location),
                                                 server.server-root),
                        max-size: max-size),
                   default-log-target);
  let logger :: <logger>
    = get-logger(logger-name) | make(<logger>, name: logger-name);
  logger.logger-additive? := additive?;
  if (format-control)
    logger.log-formatter := make(<log-formatter>, pattern: format-control);
  end;
  remove-all-targets(logger);  // TODO: make this optional
  add-target(logger, target);

  let unrecognized = #f;
  let level-name = get-attr(node, #"level") | "info";
  let level = select (level-name by string-equal?)
                "trace" => $trace-level;
                "debug" => $debug-level;
                "info"  => $info-level;
                "warn", "warning", "warnings" => $warn-level;
                "error", "errors" => $error-level;
                otherwise =>
                  unrecognized := #t;
                  $info-level;
              end;
  log-level(logger) := level;
  if (unrecognized)
    warn("Unrecognized log level: %=", level);
  end;
  log-info("Logger created: %s", logger);
  logger
end function process-log-config-element;

define method process-config-element
    (server :: <http-server>, node :: xml$<element>, name == #"administrator")
  // ---TODO:
end;

define method process-config-element
    (server :: <http-server>, node :: xml$<element>, name == #"module")
  bind (name = get-attr(node, #"name"))
    if (name)
      load-module(name);
    end;
  end;
end;

define class <mime-type-whatever> (xml$<xform-state>)
  constant slot mime-type-map :: <table>,
    required-init-keyword: mime-type-map:;
end class <mime-type-whatever>;

define method xml$transform
    (node :: xml$<element>, state :: <mime-type-whatever>)
  if (xml$name(node) = #"mime-type")
    let mime-type = get-attr(node, #"id");
    let mime-map = state.mime-type-map;
    for (child in xml$node-children(node))
      if (xml$name(child) = #"extension")
        mime-map[xml$text(child)] := mime-type;
      else
        warn("Skipping: %s %s %s: not an extension node!",
             mime-type, xml$name(child), xml$text(child));
      end if;
    end for;
  else
    next-method();
  end if;
end method xml$transform;


define method process-config-element
    (server :: <http-server>, node :: xml$<element>, name == #"mime-type-map")
  let filename = get-attr(node, #"location");
  let mime-type-loc
    = as(<string>,
         merge-locators(merge-locators(as(<file-locator>, filename),
                                       as(<directory-locator>, $koala-config-dir)),
                        server.server-root));
  log-info("Loading mime-type map from %s", mime-type-loc);
  let mime-text = file-contents(mime-type-loc);
  if (mime-text)
    let mime-xml :: xml$<document> = xml$parse-document(mime-text);
    let clear = get-attr(node, #"clear");
    if (clear & true-value?(clear))
      log-info("Clearing default mime type mappings.");
      remove-all-keys!(server.server-media-type-map);
    end;
    with-output-to-string (stream)
      dynamic-bind (%server = server)
        // Transforming the document side-effects the server's mime type map.
        xml$transform(mime-xml, make(<mime-type-whatever>,
                                     stream: stream,
                                     mime-type-map: server.server-media-type-map));
      end;
    end;
  else
    warn("mime-type map %s not found", mime-type-loc);
  end if;
end method process-config-element;

// Add an alias that maps all URLs starting with url-path to the target path.
// For example:
//   add-alias-responder("/bugs/", "https://foo.com/bugzilla/")
// will redirect a request for /bugs/123 to https://foo.com/bugzilla/123.
// The redirection is implemented by issuing a 301 (moved permanently
// redirect) response.
define method process-config-element
    (server :: <http-server>, node :: xml$<element>, name == #"alias")
  let url = get-attr(node, #"url");
  let target = get-attr(node, #"target");
  if (~(url & target))
    warn("Invalid alias; the 'url' and 'target' attributes are required.");
  else
    let resource = make(<redirecting-resource>,
                        target: parse-url(target));
    add-resource(%vhost, parse-url(url), resource);
  end;
end method process-config-element;

// <directory  url = "/"
//             location = "/some/filesystem/path"
//             allow-multi-view = "yes"
//             allow-directory-listing = "no"
//             follow-symlinks = "no"
//             default-documents = "index.html,index.htm"
//             default-content-type = "text/html"
//             />
define method process-config-element
    (server :: <http-server>, node :: xml$<element>, name == #"directory")
  let url = get-attr(node, #"url")
              | warn("Invalid <directory> spec.  The 'url' attribute is "
                     "required.");
  let location = get-attr(node, #"location")
                   | warn("Invalid <directory> spec.  The 'location' attribute "
                          "is required.");
  if (url & location)
    log-info("Static directory %s added at URL %s", location, url);
    let location = as(<directory-locator>, get-attr(node, #"location"));
    let multi? = get-attr(node, #"allow-multi-view");
    let dirlist? = get-attr(node, #"allow-directory-listing");
    let follow? = get-attr(node, #"follow-symlinks");
    let index = get-attr(node, #"default-documents");
    let indexes = iff(index,
                      map(curry(as, <file-locator>), split(index, ",")),
                      #());
    let default-content-type
      = string-to-mime-type(get-attr(node, #"default-content-type") | "text/plain",
                            class: <media-type>);
    let resource = make(<directory-resource>,
                        directory: location,
                        allow-multi-views?: multi? & true-value?(multi?),
                        follow-symlinks?: follow? & true-value?(follow?),
                        allow-directory-listing?: dirlist? & true-value?(dirlist?),
                        default-documents: indexes,
                        default-content-type: default-content-type);
    add-resource(%vhost, parse-url(url), resource);
    for (child in xml$node-children(node))
      process-config-element(server, child, xml$name(child));
    end;
  end;
end method process-config-element;

// <cgi-directory
//      url = "/cgi-bin"
//      location = "/my/cgi/scripts"
//      extensions = "cgi,bat,exe,..."
//      />
define method process-config-element
    (server :: <http-server>, node :: xml$<element>, name == #"cgi-directory")
  let url = get-attr(node, #"url")
              | warn("Invalid <cgi-directory> spec.  The 'url' attribute is "
                     "required.");
  let location = get-attr(node, #"location")
                   | warn("Invalid <cgi-directory> spec.  The 'location' "
                          "attribute is required.");
  if (url & location)
    log-info("CGI directory %s added at URL %s", location, url);
    let location = as(<directory-locator>, get-attr(node, #"location"));
    let extensions = split(get-attr(node, #"extensions") | "cgi", ',');
    let resource = make(<cgi-directory-resource>,
                        locator: location,
                        extensions: extensions);
    add-resource(%vhost, parse-url(url), resource);
    for (child in xml$node-children(node))
      process-config-element(server, child, xml$name(child));
    end;
  end;
end method process-config-element;


// RFC 2616 Section 15.1.2
// Implementors SHOULD make the Server header field a configurable option.
define method process-config-element
    (server :: <http-server>,
     node :: xml$<element>,
     name == #"server-header")
  let value = get-attr(node, #"value");
  if (~value)
    warn("Invalid <server-header> spec.  The 'value' attribute "
           "must be specified.");
  else
    server-header(server) := value;
  end;
end method process-config-element;
    


// TODO:
// <default-document>index.html</default-document>
// <response>301</response>???


Module:    httpi
Synopsis:  Virtual hosts
Author:    Carl Gay
Copyright: Copyright (c) 2004 Carl L. Gay.  All rights reserved.
License:   Functional Objects Library Public License Version 1.0
Warranty:  Distributed WITHOUT WARRANTY OF ANY KIND

define thread variable *virtual-host* :: false-or(<virtual-host>) = #f;


define class <directory-policy> (<object>)

  // The URL path that maps to this directory policy.
  constant slot policy-url-path :: <string>,
    required-init-keyword: url-path:;

  // The actual filesystem path of the directory.
  slot policy-directory :: <directory-locator>,
    required-init-keyword: directory:;

  // Whether to serve up static files under this directory.  Default to
  // the safe setting.
  constant slot allow-static? :: <boolean> = #f,
    init-keyword: allow-static?:;

  // Whether to allow directory listings.
  // May be overridden for specific directories.
  // Default is to be secure.
  constant slot allow-directory-listing? :: <boolean> = #f,
    init-keyword: allow-directory-listing?:;

  // Whether to allow serving documents that are outside of the document
  // root and are accessed via a symlink from within the document root.
  // Default is to be secure.
  constant slot follow-symlinks? :: <boolean> = #f,
    init-keyword: follow-symlinks?:;

  // Whether to allow CGI scripts to be executed from this directory.
  // Default is to be secure.
  constant slot allow-cgi? :: <boolean> = #f,
    init-keyword: allow-cgi?:;

  // Acceptable CGI script file extensions.  No other files will be served.
  constant slot policy-cgi-extensions :: <sequence> = #("cgi"),
    init-keyword: cgi-extensions:;

  // The set of file names that are searched for when a directory URL is
  // requested.  They are searched in order, and the first match is chosen.
  // TODO: Probably these shouldn't specify a filename extension, so that
  //       the media type can be chosen via content negotiation.
  constant slot policy-default-documents :: <list>
    = list(as(<file-locator>, "index.html"),
           as(<file-locator>, "index.htm")),
    init-keyword: default-documents:;

  // Name taken from Apache.  If #t then when a static file document 'foo'
  // is requested and doesn't exist, we search for foo.* files instead.
  constant slot allow-multi-views? :: <boolean> = #f,
    init-keyword: allow-multi-views?:;

  // The value sent in the "Content-Type" header for files served from this
  // directory if no mime-type can be found based on the file extension.
  slot policy-default-content-type :: <mime-type>
    = make(<mime-type>,
           type: "application",
           subtype: "octet-stream"),
    init-keyword: default-content-type:;

end class <directory-policy>;

define method policy-matches?
    (policy :: <directory-policy>, url :: <string>)
  looking-at?(policy-url-path(policy), url, 0, size(url))
end;


// Most slots are set when the config file is processed.  A valiant attempt
// should be made to use good defaults, in case the config file doesn't specify
// a value.

define class <virtual-host> (<object>)
  constant slot vhost-name :: <string>,
    required-init-keyword: name:;

  // This defaults to the value of document-root.
  slot dsp-root :: <directory-locator>,
    init-keyword: dsp-root:;

  // List of <directory-policy>s that determine how documents in
  // different directories are treated.  These are searched in order,
  // and the first one to match the requested URL is used.  Items are
  // pushed onto the beginning of this list as the config file is read,
  // so if two specs match the request URL then later specs will take
  // precedence.  I think this will match the natural usage, where people
  // will put more general specs first in the file and more specific ones
  // later, but we might want to revisit this decision.
  slot directory-policies :: <list>
    = list();

  // The document root is now defined by the root-directory-policy (below).
  // Should get rid of this and just use root-directory-policy instead.
  required keyword document-root,
    type: <directory-locator>;

  // Each vhost gets an implicitly defined spec for the vhost root directory.
  // The directory in this policy defines the document root.
  // It must, of course, match all documents under the vhost document root.
  // It should always be the last element in directory-policies(vhost).
  // See initialize(<virtual-host>).
  slot root-directory-policy :: <directory-policy>;

  slot request-logger :: <logger>,
    init-value: *request-logger*,
    init-keyword: request-logger:;

  slot error-logger :: <logger>,
    init-value: *error-logger*,
    init-keyword: error-logger:;

  slot debug-logger :: <logger>,
    init-value: *debug-logger*,
    init-keyword: debug-logger:;

end class <virtual-host>;

define method initialize
    (vhost :: <virtual-host>,
     #key dsp-root, document-root :: <directory-locator>,
     #all-keys)
  next-method();
  if (~dsp-root)
    vhost.dsp-root := document-root;
  end;
  vhost.root-directory-policy := make(<directory-policy>,
                                      url-path: "/",
                                      directory: document-root);
end method initialize;

// The document root is defined by the root directory policy.
define inline method document-root
    (vhost :: <virtual-host>) => (root :: <directory-locator>)
  vhost.root-directory-policy.policy-directory
end;

define method document-root-setter
    (new-root :: <directory-locator>, vhost :: <virtual-host>)
 => (new-root :: <directory-locator>)
  vhost.root-directory-policy.policy-directory := new-root
end method document-root-setter;

define method add-directory-policy
    (vhost :: <virtual-host>, policy :: <directory-policy>)
  directory-policies(vhost)
    := pair(policy, remove!(directory-policies(vhost), policy,
                            test: method (s1, s2)
                                    policy-url-path(s1) = policy-url-path(s2)
                                  end));
  for (policy in vhost.directory-policies)
    log-debug("directory policy: %=", policy);
  end;
end method add-directory-policy;

define method print-object
    (policy :: <directory-policy>, stream :: <stream>) => ()
  format(stream, "<directory-policy url-path=%= directory=\"%s\" list?=%= "
                 "static?=%= symlinks?=%= cgi?=%= cgi-ext=%=>",
         policy.policy-url-path,
         as(<string>, policy.policy-directory),
         policy.allow-directory-listing?,
         policy.allow-static?,
         policy.follow-symlinks?,
         policy.allow-cgi?,
         policy.policy-cgi-extensions);
end;

define method as
    (class :: subclass(<string>), policy :: <directory-policy>) => (s :: <string>)
  with-output-to-string(s)
    print-object(policy, s)
  end
end;

define method directory-policy-matching
    (vhost :: <virtual-host>, url :: <string>)
  iterate loop (policies :: <list> = directory-policies(vhost))
    if (empty?(policies))
      // The last policy is guaranteed to match all documents under the document root,
      // so if we get here it's an error.
      // TODO: improve the error message here, at least in the case where debugging
      //       is enabled.
      internal-server-error();
    else
      let policy :: <directory-policy> = head(policies);
      iff(policy-matches?(policy, url),
          policy,
          loop(tail(policies)));
    end if;
  end;
end method directory-policy-matching;


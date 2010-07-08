Module:    httpi
Synopsis:  Serve static files and directory listings
Author:    Carl Gay
Copyright: Copyright (c) 2001-2004 Carl L. Gay.  All rights reserved.
License:   Functional Objects Library Public License Version 1.0
Warranty:  Distributed WITHOUT WARRANTY OF ANY KIND


define function document-not-found ()
  resource-not-found-error(url: request-raw-url-string(current-request()));  // 404
end;


// Merges the given URL against the context parameter and ensures that the
// resulting locator refers to a (possibly non-existent) document below the
// context directory.  If not, it signals an error.
define method locator-from-url
    (url :: <string>, context :: <directory-locator>)
 => (locator :: false-or(<physical-locator>))
  block ()
    let len :: <integer> = size(url);
    let (bpos, epos) = trim-whitespace(url, 0, len);
    if (bpos == epos)
      context
    else
      let relative-url = iff(url[bpos] = '/', substring(url, 1, epos), url);
      if (empty?(relative-url))
        context
      else
        let loctype = iff(relative-url[size(relative-url) - 1] == '/',
                          <directory-locator>,
                          <file-locator>);
        let loc = simplify-locator(merge-locators(as(loctype, relative-url),
                                                  context));
        if (locator-name(loc) = "..")
          loc := locator-directory(locator-directory(loc));
        end;
        locator-below-root?(loc, context) & loc
      end if
    end if
  exception (ex :: <locator-error>)
    log-debug("Locator error in locator-from-url: %=", ex);
    document-not-found();
  end block
end method locator-from-url;

define function serve-static-file-or-cgi-script ()
  let request = current-request();
  let response = current-response();
  // Just use the path, not the host, query, or fragment.
  let url :: <string> = build-path(request.request-url);
  let policy :: <directory-policy> = directory-policy-matching(*virtual-host*, url);
  let document :: <locator> = locator-from-url(url, policy.policy-directory);

  log-debug("static file: url = %s", url);
  log-debug("static file: policy = %=", policy);
  log-debug("static file: document = %s", as(<string>, document));

  if (~file-exists?(document))
    document := find-multi-view-file(policy, document)
                  | document-not-found();
    log-debug("static file: multi-view document = %s", as(<string>, document));
  end;

  if (file-type(document) == #"link")
    if (follow-symlinks?(policy))
      document := follow-links(link-target(document), policy);
      log-info("static file: linked document = %s", document);
    else
      forbidden-error();
    end;
  end if;

  block (return)
    let ftype = file-type(document);
    if (ftype = #"directory")
      let index = find-default-document(policy, document);
      if (index)
        // Let the index file be processed like a regular file, below.
        document := index;
      elseif (policy.allow-directory-listing?)
        serve-directory(document);
        return();
      else
        document-not-found()
      end;
    end;

    // It's a regular file...
    if (policy.allow-cgi?
          & member?(document.locator-extension, policy.policy-cgi-extensions,
                    test: string-equal?))  // TODO: should be \= on Unix
      serve-cgi-script(document, url);
    elseif (~policy.allow-static?)
      forbidden-error();
    else
      let (etag, weak?) = etag(document);
      add-header(response, iff(weak?, "W/ETag", "ETag"), etag);
      let client-etag = get-header(request, "If-None-Match");
      if (etag = client-etag)
        request.request-method := #"head";
        not-modified-redirect(headers: response.raw-headers);
      else
        serve-static-file(policy, document);
      end;
    end;
  end block;
end function serve-static-file-or-cgi-script;

// Follow symlink chain.  If the target is outside the policy directory and
// the given policy disallows that, signal 404 error.
//
define function follow-links
    (document :: <pathname>, policy :: <directory-policy>)
 => (target :: <pathname>)
  if ( ~(file-exists?(document)
           & locator-below-root?(document, policy.policy-directory)))
    document-not-found();
  elseif (file-type(document) == #"link")
    follow-links(link-target(document), policy)
  else
    document
  end
end function follow-links;

define method find-default-document
    (policy :: <directory-policy>, locator :: <directory-locator>)
 => (locator :: <physical-locator>)
  block (return)
    for (default in policy.policy-default-documents)
      let document = merge-locators(default, locator);
      if (~file-exists?(document))
        document := find-multi-view-file(policy, document);
      end;
      if (document
            & file-exists?(document)
            & file-type(document) = #"file")
        return(document)
      end;
    end;
    locator  // found nothing
  end
end method find-default-document;

define method locator-below-document-root? 
    (locator :: <physical-locator>)
 => (below? :: <boolean>)
  locator-below-root?(locator, *virtual-host*.document-root)
end;

define method locator-below-dsp-root?
    (locator :: <physical-locator>)
 => (below? :: <boolean>)
  locator-below-root?(locator, *virtual-host*.dsp-root)
end;

// I can't make any sense of this.  --cgay
define method locator-below-root?
    (locator :: <physical-locator>, root :: <directory-locator>)
 => (below? :: <boolean>)
  let relative = relative-locator(locator, root);
  // do they at least share a common ancestor?
  if (locator-relative?(relative))
    let relative-parent = locator-directory(relative);
    // is it a file directly in the root dir?
    ~relative-parent
      | begin
          let relative-path = locator-path(relative-parent);
          // again, is it directly in the root dir?
          empty?(relative-path)
            | relative-path[0] ~= #"parent"  // does it start with ".."?
        end;
  end if;
end method locator-below-root?;

define method locator-media-type
    (locator :: <locator>, policy :: <directory-policy>)
 => (media-type :: <media-type>)
  extension-to-mime-type(locator.locator-extension, *server*.server-media-type-map)
    | policy-default-content-type(policy)
end method locator-media-type;

define method serve-static-file
    (policy :: <directory-policy>, locator :: <locator>)
  log-debug("Serving static file: %s", as(<string>, locator));
  let response = current-response();
  with-open-file(in-stream = locator, direction: #"input", if-does-not-exist: #f,
                 element-type: <byte>)
    add-header(response, "Content-Type",
               mime-name(locator-media-type(locator, policy)));
    let props = file-properties(locator);
    add-header(response, "Last-Modified",
               as-rfc1123-string(props[#"modification-date"]));
    copy-to-end(in-stream, response.output-stream);
  end;
end method serve-static-file;

define method copy-to-end
    (in-stream :: <stream>, out-stream :: <stream>)
  let buffer-size :: <integer> = 8092;
  let buffer :: <sequence> = make(stream-sequence-class(in-stream),
                                  size: buffer-size);
  iterate loop ()
    let count = read-into!(in-stream, buffer-size, buffer, on-end-of-stream: #f);
    write(out-stream, buffer, end: count);
    if (count = buffer-size)
      loop()
    end;
  end;
end method copy-to-end;

define method etag 
    (locator :: <locator>)
 => (etag :: <string>, weak? :: <boolean>)
  //generate an etag (use modification date and size)
  // --TODO: algorithm should be changed (md5?), because a file can
  //changes more than once per second without changing size.
  let props = file-properties(locator);
  let now = current-date();
  let timestamp = props[#"modification-date"];
  let time = (date-hours(timestamp) * 60 +
             date-minutes(timestamp)) * 60 +
             date-seconds(timestamp);
  let date = (date-year(timestamp) * 1000 +
             date-month(timestamp)) * 100 +
             date-day(timestamp);
  let weak :: <boolean> = #f;
  let dur :: <day/time-duration> =
    make(<day/time-duration>, days: 0, seconds: 1);
  if (now < timestamp + dur)
    weak := #t;
  end if;
  values(concatenate("\"", integer-to-string(date, base: 16), "-",
                     integer-to-string(time, base: 16), "-",
                     integer-to-string(props[#"size"], base: 16), "\""),
                     weak);
end method etag;

define method serve-directory
    (url :: <string>, directory :: <physical-locator>, policy :: <directory-policy>)
  // Why require the url to end in '/'?  --cgay
  if (url[size(url) - 1] = '/')
    generate-directory-html(policy, directory);
  else
    let new-location = concatenate(url, "/");
    moved-permanently-redirect(location: new-location, // 301
                               header-name: "Location",
                               header-value: new-location);
  end if;
end method serve-directory;

// Serves up a directory listing as HTML.  The caller has already verified that this
// locator names a directory, even though it may be a <file-locator>, and that the
// directory it names is under the document root.
//---TODO: add image links.  deal with access control.
define method generate-directory-html
    (policy :: <directory-policy>, locator :: <locator>)
  let response :: <response> = current-response();  
  let loc :: <directory-locator>
    = iff(instance?(locator, <directory-locator>),
          locator,
          subdirectory-locator(locator-directory(locator), locator-name(locator)));
  let directory-properties = file-properties(locator);
  add-header(response, "Last-Modified",
             as-rfc1123-string(directory-properties[#"modification-date"]));
  let stream = output-stream(response);
  local
    method show-file-link (directory, name, type)
      unless (name = ".." | name = ".")
        let locator = iff(type = #"directory",
                          subdirectory-locator(as(<directory-locator>, directory), name),
                          merge-locators(as(<file-locator>, name),
                                         as(<directory-locator>, directory)));
        let props = file-properties(locator);
        let link = if (type = #"directory")
                     concatenate(name, "/");
                   else
                     name;
                   end if;
        write(stream, "\t\t\t\t<tr>\n");
        format(stream, "\t\t\t\t<td class=\"name\"><a href=\"%s\">%s</a></td>\n",
               link, link);
        let mime-type = iff(type = #"file",
                            as(<string>, locator-media-type(locator, policy)),
                            "");
        format(stream, "\t\t\t\t<td class=\"mime-type\">%s</td>\n", mime-type);
        for (key in #[#"size", #"modification-date", #"author"],
             alignment in #["right", "left", "left"])
          let prop = element(props, key, default: #f);
          format(stream, "\t\t\t\t<td align=\"%s\" class=\"%s\">",
                 alignment, as(<string>, key));
          if (prop)
            display-file-property(stream, key, prop, type);
          else
            write(stream,"-");
          end if;
          write(stream, "\t\t\t\t</td>\n");
        end;
        write(stream, "\t\t\t</tr>\n");
      end;
    end;
  let url = request-url(current-request());
  format(stream,
         "<?xml version=\"1.0\"?>\n"
         "<!DOCTYPE html PUBLIC \"-//W3C/DTD XHTML 1.0 Strict//EN\""
         " \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd\">\n"
         "<html xmlns=\"http://www.w3.org/1999/xhtml\">\n"
         "\t<head>\n"
         "\t\t<title>Index of %s</title>\n"
         "\t</head>\n", url);
  format(stream, "\t<body>\n");
  format(stream, "\t\t<table cellspacing=\"4\">\n");
  format(stream, "\t\t\t<caption>Directory listing for %s</caption>\n", url);
  write(stream,  "\t\t\t<col id=\"name\" />\n"
                 "\t\t\t<col id=\"mime-type\" />\n"
                 "\t\t\t<col id=\"size\" />\n"
                 "\t\t\t<col id=\"modification-date\" />\n"
                 "\t\t\t<col id=\"author\" />\n");
  write(stream,  "\t\t\t<thead>\n"
                 "\t\t\t\t<tr>\n"
                 "\t\t\t\t\t<th align=\"left\">Name</th>\n"
                 "\t\t\t\t\t<th align=\"left\">MIME Type</th>\n"
                 "\t\t\t\t\t<th align=\"right\">Size</th>\n"
                 "\t\t\t\t\t<th align=\"left\">Date</th>\n"
                 "\t\t\t\t\t<th align=\"left\">Author</th>\n"
                 "\t\t\t\t</tr>\n"
                 "\t\t\t</thead>\n");
  write(stream,  "\t\t\t<tbody>\n");
  let docroot :: <directory-locator> = document-root(*virtual-host*);
  unless (loc = docroot
          | (instance?(loc, <file-locator>)
             & locator-directory(loc) = docroot))
    write(stream,
          "\t\t\t\t<tr>\n"
          "\t\t\t\t\t<td class=\"name\"><a href=\"../\">../</a></td>\n"
          "\t\t\t\t\t<td class=\"type\"></td>\n"
          "\t\t\t\t\t<td class=\"size\"></td>\n"
          "\t\t\t\t\t<td class=\"modification-date\"></td>\n"
          "\t\t\t\t\t<td class=\"author\" />\n"
          "\t\t\t\t</tr>\n");
  end unless;
  do-directory(show-file-link, loc);
  write(stream,
        "\t\t\t</tbody>\n"
        "\t\t</table>\n"
        "\t</body>\n"
        "</html>\n");
end method generate-directory-html;

define method display-file-property
    (stream, key, property, file-type :: <file-type>) => ()
end;

define method display-file-property
    (stream, key, property :: <date>, file-type :: <file-type>) => ()
  date-to-stream(stream, property);
end;

define method display-file-property
    (stream, key == #"size", property, file-type :: <file-type>) => ()
  if (file-type == #"file")
    let kilobyte = round/(property, 1024);
    let megabyte = round/(kilobyte, 1024);
    let gigabyte = round/(megabyte, 1024);
    if (gigabyte > 0)
      format(stream, "%d GB", gigabyte);
    elseif (megabyte > 0)
      format(stream, "%d MB", megabyte);
    elseif (kilobyte > 0)
      format(stream, "%d KB", kilobyte);
    else
      format(stream, "%d B", property);
    end if;
  else
    write(stream, "");
  end if;
end;

define method display-file-property
    (stream, key, property :: <string>, file-type :: <file-type>) => ()
  format(stream, property);
end;

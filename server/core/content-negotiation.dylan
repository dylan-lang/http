Module:    httpi
Synopsis:  Content negotiation (a la RFC 2616, section 12)
Author:    Carl Gay
Copyright: Copyright (c) 2001-2010 Carl L. Gay.  All rights reserved.
License:      See License.txt in this distribution for details.
Warranty:  Distributed WITHOUT WARRANTY OF ANY KIND


// This code is far from complete.  The initial implementation here is
// only intended to support whatever is needed to host the DRM documents,
// which don't specify file extensions in the URLs they request.
// --cgay Mar 2010


//// Multi-views

// Multi-views is named after the feature in Apache.  Basically it tries to
// find the best file to match the requested URL.  If 'foo' is requested and
// doesn't exist then search for 'foo.*' in the file-system and choose the
// best one based on the Accept* headers and built-in source quality values.
//
// See the section "Apache Negotiation Algorithm" about one page below this
// link: http://httpd.apache.org/docs/2.0/content-negotiation.html#methods

define class <document-variant> (<object>)
  constant slot variant-locator :: <file-locator>,
    required-init-keyword: locator:;
  constant slot document-media-type :: <media-type>,
    required-init-keyword: document-media-type:;
  constant slot header-media-type :: <media-type>,
    required-init-keyword: header-media-type:;
end;

define method print-object
    (v :: <document-variant>, stream :: <stream>) => ()
  format(stream, "<document-variant file=%= doc=%= hdr=%=>",
         as(<string>, v.variant-locator),
         as(<string>, v.document-media-type),
         as(<string>, v.header-media-type));
end;

define method as
    (class :: subclass(<string>), v :: <document-variant>) => (s :: <string>)
  with-output-to-string(s)
    print-object(v, s)
  end
end;

define method variant-quality
    (v :: <document-variant>) => (q :: <float>)
  v.document-media-type.media-type-quality
    * v.header-media-type.media-type-quality
end;

// This is the main entry point for multi-view functionality.  Given a
// directory policy and a locator for a file that doesn't exist, find
// the "best" existing file in the same directory that has the same base
// name but also has an extension that matches one of the acceptable
// media types.
// The accept-header parameter exists so that tests don't require
// current-request() to work.
//
define method find-multi-view-file
    (policy :: <directory-resource>, document :: <file-locator>,
     #key accept-header)
 => (locator :: false-or(<file-locator>))
  // Upon entry to this function, 'document' is known not to name
  // an existing file.
  if (policy.allow-multi-views?)
    let locators = locators-matching(document);
    if (locators.size > 0)
      let accept-header :: false-or(<list>)
        = accept-header | get-header(current-request(), "Accept", parsed: #t);
      local method make-variant (locator)
              let doc-mtype = locator-media-type(locator, policy);
              let hdr-mtype
                = accept-header & media-type-from-header(accept-header, doc-mtype);
              hdr-mtype
                & make(<document-variant>,
                       locator: locator,
                       document-media-type: doc-mtype,
                       header-media-type: hdr-mtype)
            end;
      // Create variants for each locator that names an existing file.
      // TODO: If there is no Accept header then built-in default values should
      // be used for each MIME type. Otherwise 'default-value * header-value'
      // should be used.
      let variants = choose(identity, map(make-variant, locators));
      log-debug("Initial candidate variants:\n  %s",
                join(variants, "\n  ", key: curry(as, <string>)));

      // Select the variant with the highest quality value.
      let best = reduce1(method (best, other)
                           let best-q = best.variant-quality;
                           let other-q = other.variant-quality;
                           iff(other-q > best-q, other, best)
                         end,
                         variants);
      log-debug("best = %s", best);
      if (best.variant-quality = 0.0)
        log-debug("best quality = 0.0; no variants to select from");
        #f
      else
        let variants = choose(method (v)
                                v.variant-quality = best.variant-quality
                              end,
                              variants);
        log-debug("%d variants with quality = %s:\n  %s",
                  variants.size,
                  best.variant-quality,
                  join(variants, "\n  ", key: curry(as, <string>)));
        select (variants.size)
          0 => #f;
          1 => variants[0].variant-locator;
          otherwise =>
            // Select the variant with the highest 'level' media parameter.
            // If level isn't specified (which is currently ALWAYS :) we assume
            // level 2 based on a comment in the Apache content negotiation code.
            let lmax = reduce(method (level, variant)
                                let vlevel = variant.header-media-type.media-type-level;
                                if (level & vlevel)
                                  max(level, vlevel)
                                else
                                  level | vlevel
                                end
                              end,
                              #f,
                              variants);
            let variants = choose(method (var)
                                    var.header-media-type.media-type-level = lmax
                                  end,
                                  variants);
            log-debug("%d variants with lmax = %s:\n  %s",
                      variants.size,
                      lmax,
                      join(variants, "\n  ", key: curry(as, <string>)));
            select (variants.size)
              0 => #f;
              1 => variants[0].variant-locator;
              otherwise =>
                log-debug("Choosing variant with smallest file size");
                // Select the variant with the smallest content length.
                // If there are several, take the first.
                local method min-content-length (var1, var2)
                        let fsize1 = file-property(var1.variant-locator, #"size");
                        let fsize2 = file-property(var2.variant-locator, #"size");
                        iff(fsize1 < fsize2, var1, var2)
                      end;
                reduce1(min-content-length, variants).variant-locator
            end select
        end select
      end if
    else
      log-debug("no locators found matching %s", as(<string>, document));
      #f
    end
  else
    log-debug("multi-views disallowed by policy");
  end if
end method find-multi-view-file;

// Find the media type in the given Accept header that best matches the
// given media type.
define function media-type-from-header
    (accept-header :: <list>, given :: <media-type>)
 => (media-type :: false-or(<media-type>))
  log-debug("mtfh: given %s", as(<string>, given));
  let best = #f;
  let best-match = -1;
  block (return)
    for (media-type :: <media-type> in accept-header)
      log-debug("mtfh: considering %s", as(<string>, media-type));
      let match = match-media-types(given, media-type);
      if (match & match > best-match)
        log-debug("      ...selected, match = %s", match);
        best := media-type;
        best-match := match;
      end;
    end for;
  end block;
  best
end function media-type-from-header;

// This isn't quite right because we will eventually want to deal with things
// like .tar.gz, but I think it will cover the cases in the DRM web pages.
// --cgay Mar 2010
define constant $file-extension-regex :: <regex>
  = compile-regex("[a-zA-Z0-9]+$");

// Get locators for all the files matching the given locator prefix.  e.g., if the
// locator is for /foo/bar then we would return bar.html, bar.txt, etc.
// TODO(cgay): This assumes case-sensitive file system.
define method locators-matching
    (document :: <locator>)
 => (locators :: <sequence>)
  let document-name :: <string> = concatenate(locator-name(document), ".");
  let length :: <integer> = document-name.size;
  let locators = make(<stretchy-vector>);
  local method match (directory, name, type)
          if (type = #"file"
                & (name.size >= document-name.size)
                & string-equal?(document-name, name, end2: length))
            log-debug("document name matched");
            if (regex-search($file-extension-regex, name, start: length))
              add!(locators, make(<file-locator>,
                                  directory: document.locator-directory,
                                  name: name));
            end;
          end;
        end;
  do-directory(match, locator-directory(document));
  locators
end method locators-matching;



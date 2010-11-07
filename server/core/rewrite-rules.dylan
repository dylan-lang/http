Module:    httpi
Synopsis:  A mechanism for transforming URLs
Author:    Carl Gay
Copyright: Copyright (c) 2001-2010 Carl L. Gay.  All rights reserved.
License:   Functional Objects Library Public License Version 1.0
Warranty:  Distributed WITHOUT WARRANTY OF ANY KIND

// Currently (Nov 2010) these only do simple regex-based transformations on
// the URL path.


define constant <redirect-code>
  = one-of($status-moved-permanently,
           $status-found,
           $status-see-other,
           $status-temporary-redirect,
           $status-not-modified);

define open abstract class <abstract-rewrite-rule> (<object>)
  constant slot rewrite-rule-terminal? :: <boolean> = #f,
    init-keyword: terminal?:;
  constant slot rewrite-rule-redirect-code :: <redirect-code> = $status-found,
    init-keyword: redirect-code:;
end class <abstract-rewrite-rule>;

define class <rewrite-rule> (<abstract-rewrite-rule>)
  constant slot rewrite-rule-regex :: <regex>,
    required-init-keyword: regex:;

  // This is a sequence of string literals and regex group references
  // which are parsed from a spec like "/foo/$2/$1/${name}".  The
  // references are one element lists, to distinguish them from the
  // string literals by type.
  constant slot rewrite-rule-replacement :: <sequence>,
    required-init-keyword: replacement:;

end class <rewrite-rule>;

define method make
    (class :: subclass(<rewrite-rule>), #rest args, #key replacement)
 => (rule :: <rewrite-rule>)
  apply(next-method, class,
        replacement: iff(instance?(replacement, <string>),
                         parse-replacement(replacement),
                         replacement),
        args)
end method make;


define constant $group-reference-regex :: <regex>
  = compile-regex("\\$\\{?([0-9a-zA-Z]+)}?");

define function parse-replacement
    (input :: <string>) => (replacement :: <sequence>)
  let result = make(<stretchy-vector>);
  iterate loop (start :: <integer> = 0)
    let match = regex-search($group-reference-regex, input,
                             start: start,
                             case-sensitive: #t);
    if (match)
      let group = match-group(match, 1);
      block ()
        let (int, epos) = string-to-integer(group);
        if(epos = group.size)
          group := int;
        end;
      exception (ex :: <error>)
      end;
      let (_, bpos, epos) = match-group(match, 0);
      add!(result, copy-sequence(input, start: start, end: bpos));
      add!(result, list(group));
      loop(epos);
    else
      add!(result, copy-sequence(input, start: start));
    end;
  end;
  as(<vector>, result)
end function parse-replacement;


//// Configuration

// <rewrite-rules base-url="/base/url/">
//   <rewrite-rule pattern="^drm_1(\.html)?$" replacement="Title$1" redirect="permanent" terminal="yes" />
//   <rewrite-rule pattern="^drm_2(\.html)?$" replacement="Copyrights$1" redirect="permanent" terminal="yes" />
//   ...
// </rewrite-rules>
//

define thread variable *rewrite-rule-base-url* :: <string> = "";

define method process-config-element
    (server :: <http-server>, node :: xml$<element>, name == #"rewrite-rules")
  dynamic-bind(*rewrite-rule-base-url* = get-attr(node, #"base-url")
                                         | *rewrite-rule-base-url*)
    for (child in xml$node-children(node))
      process-config-node(server, child);
    end;
  end;
end method process-config-element;

define table $redirect-code-map = {
    #"permanent"    => $status-moved-permanently,
    #"found"        => $status-found,
    #"temporary"    => $status-temporary-redirect,
    #"see-other"    => $status-see-other,
    #"not-modified" => $status-not-modified
    };

define method process-config-element
    (server :: <http-server>, node :: xml$<element>, name == #"rewrite-rule")
  let pattern = get-attr(node, #"pattern");
  let replacement = get-attr(node, #"replacement");
  let redirect = get-attr(node, #"redirect") | "found";
  let terminal = get-attr(node, #"terminal") | "no";
  if (~(pattern & replacement))
    warn("<rule> must have both 'pattern' and 'replacment' attributes.");
  else
    let code = ignore-errors(string-to-integer(redirect));
    let redirect-code = code | element($redirect-code-map, as(<symbol>, redirect),
                                       default: $status-found);
    let rule = make(<rewrite-rule>,
                    regex: compile-regex(pattern),
                    replacement: concatenate(*rewrite-rule-base-url*, replacement),
                    redirect-code: redirect-code,
                    terminal?: true-value?(terminal));
    add!(server.rewrite-rules, rule);
  end;
end method process-config-element;


//// rewrite-url

// Transform the given URL string based on a sequence of rules.
// Return the transformed string and whether or not to terminate
// rewrite rule processing.
define open generic rewrite-url
    (url :: <string>, rule :: <object>)
 => (url :: <string>, extra);

define method rewrite-url
    (url :: <string>, rule :: <rewrite-rule>)
 => (url :: <string>, matched? :: <boolean>)
  //log-debug("rewrite-url(%=, %=)", url, rules);
  let match = regex-search(rule.rewrite-rule-regex, url);
  if (match)
    local method do-replacement (x)
            iff(instance?(x, <string>),
                x,
                match-group(match, first(x)))
          end;
    values(join(map(do-replacement, rule.rewrite-rule-replacement), ""),
           #t)
  else
    values(url, #f)
  end
end method rewrite-url;

// Apply a sequence of rules and return the new URL plus the rule that
// caused processing to terminate.
define method rewrite-url
    (url :: <string>, rules :: <sequence>)
 => (url :: <string>, rule :: false-or(<abstract-rewrite-rule>))
  //log-debug("rewrite-url(%=, %=)", url, rules);
  iterate loop (new-url = url, i = 0, prev = #f)
    if (i >= rules.size)
      log-debug("rewrite-url returning %=, %=", new-url, prev);
      values(new-url, prev)
    else
      let rule = rules[i];
      let (new, matched?) = rewrite-url(new-url, rule);
      /* log-debug("  regex: %=, replacement: %=, new: %=, terminate?: %=",
                rule.rewrite-rule-regex.regex-pattern,
                rule.rewrite-rule-replacement,
                new,
                rule.rewrite-rule-terminal?); */
      if (matched? & rule.rewrite-rule-terminal?)
        log-debug("rewrite-url returning %=, #t", new);
        values(new, rule)
      else
        loop(new, i + 1, iff(matched?, rule, prev))
      end
    end
  end iterate
end method rewrite-url;

define function do-rewrite-redirection
    (server :: <http-server>, request :: <request>, url-path :: <string>,
     rule :: false-or(<rewrite-rule>))
  let code = iff(rule, rule.rewrite-rule-redirect-code, $status-found);
  select (code)
    $status-moved-permanently =>
      moved-permanently-redirect(location: url-path);
    $status-found =>
      found-redirect(location: url-path);
    $status-see-other =>
      see-other-redirect(location: url-path);
    $status-temporary-redirect =>
      moved-temporarily-redirect(location: url-path);
    $status-not-modified =>
      not-modified-redirect();
    //$status-use-proxy =>
    //  use-proxy-redirect(location: proxy-location);
    otherwise =>
      log-error("Unexpected redirect code in rewrite rule: %s", code);
      internal-server-error();
  end;
end function do-rewrite-redirection;


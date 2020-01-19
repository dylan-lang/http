Module:    http-common-internals
Synopsis:  Various small utilities
Author:    Carl Gay
Copyright: See LICENSE in this distribution for details.


// Brevity. (Copied from uncommon-dylan. Not worth having the dependency.)

define macro iff
    { iff(?test:expression, ?true:expression, ?false:expression) }
 => { if (?test) ?true else ?false end }

    { iff(?test:expression, ?true:expression) }
 => { if (?test) ?true end }
end;

define macro inc!
  { inc! (?place:expression, ?dx:expression) }
    => { ?place := ?place + ?dx; }
  { inc! (?place:expression) }
    => { ?place := ?place + 1; }
end macro inc!;


// Things that expire.

define open generic date-modified
    (object :: <object>)
 => (date :: false-or(<date>));

define open generic date-modified-setter
    (new-date :: false-or(<date>), object :: <object>)
 => (new-date :: false-or(<date>));

define open class <expiring-mixin> (<object>)
  constant slot duration :: <day/time-duration>,
    init-value: encode-day/time-duration(0, 1, 0, 0, 0),      // 1 hour
    init-keyword: duration:;
  // When the object was last modified (e.g., loaded from a file).
  slot date-modified :: false-or(<date>) = #f;
end;

define method expired?
    (thing :: <expiring-mixin>)
 => (expired? :: <boolean>)
  thing.date-modified == #f
  | begin
      let now = current-date();
      (now - thing.date-modified) < thing.duration
    end
end method expired?;


//// Attributes

define open class <attributes-mixin> (<object>)
  constant slot attributes :: <mutable-explicit-key-collection>
    = make(<string-table>),
    init-keyword: attributes:;
end;

define generic has-attribute?
    (this :: <attributes-mixin>, key :: <string>) => (has-it? :: <boolean>);

define generic get-attribute
    (this :: <attributes-mixin>, key :: <string>, #key)
 => (value :: <object>);

define generic set-attribute
    (this :: <attributes-mixin>, key :: <string>, value :: <object>);

define generic remove-attribute
    (this :: <attributes-mixin>, key :: <string>);


define method has-attribute?
    (this :: <attributes-mixin>, key :: <string>)
 => (has-it? :: <boolean>)
  element(this.attributes, key, default: $unfound) ~= $unfound
end;

define method get-attribute
    (this :: <attributes-mixin>, key :: <string>, #key default)
 => (attribute :: <object>)
  element(this.attributes, key, default: default)
end;

define method set-attribute
    (this :: <attributes-mixin>, key :: <string>, value :: <object>)
  this.attributes[key] := value;
end;

define method remove-attribute
    (this :: <attributes-mixin>, key :: <string>)
  remove-key!(this.attributes, key);
end;



//// XML/HTML

define table $html-quote-map
  = { '<' => "&lt;",
      '>' => "&gt;",
      '&' => "&amp;",
      '"' => "&quot;"
      };

// I'm sure this could use a lot of optimization.
define function quote-html
    (text :: <string>, #key stream)
  if (~stream)
    with-output-to-string (s)
      quote-html(text, stream: s)
    end
  else
    for (char in text)
      let translation = element($html-quote-map, char, default: char);
      iff(instance?(translation, <sequence>),
          write(stream, translation),
          write-element(stream, translation));
    end;
  end;
end function quote-html;


// A media type is a MIME type plus some parameters.  The type and subtype
// may be wild (i.e., "*") for the Accept header but should not be for the
// content-type header.  The two well-known parameters, quality (q) and
// level are converted to <float> and <integer> respectively.  The rest are
// left as strings.
//
// Note that <attributes-mixin> uses <string-table>, which is case sensitive.
// RFC 2616, 3.7 specifies that media-type parameter names are not case
// sensitive.  For now we rely on parse-media-type to lowercase the parameter
// names (and the type and subtype).
define class <media-type> (<attributes-mixin>, <mime-type>)
end;

define method print-object
    (mt :: <media-type>, stream :: <stream>) => ()
  format(stream, "<%s %s/%s", mt.object-class, mt.mime-type, mt.mime-subtype);
  for (value keyed-by key in mt.attributes)
    format(stream, "; %s=%s", key, value);
  end;
  write(stream, ">");
end;

define method as
    (class :: subclass(<string>), mt :: <media-type>) => (s :: <string>)
  with-output-to-string(s)
    print-object(mt, s)
  end
end;

define constant $mime-wild :: <byte-string> = "*";

// Returns the degree to which the two media types match, or #f if they
// don't match at all.  Points are assigned as follows:
// * 100 - major mime type matches exactly (not a wildcard match)
// * 100 - mime subtype matches exactly (not a wildcard match)
// * 1 - wildcard match for type or subtype
// * 1 - for each attribute (excluding "q") that matches exactly
// Matching type/subtype trumps all else.
define method match-media-types
    (type1 :: <media-type>, type2 :: <media-type>)
 => (degree :: false-or(<integer>))
  let degree = 0;
  if ((type1.mime-type = type2.mime-type & inc!(degree, 100))
        | (type1.mime-type = $mime-wild & inc!(degree))
        | (type2.mime-type = $mime-wild & inc!(degree)))
    log-debug(*http-common-log*, "  MMT: 1 - degree = %s", degree);
    if ((type1.mime-subtype = type2.mime-subtype & inc!(degree, 100))
          | (type1.mime-subtype = $mime-wild & inc!(degree))
          | (type2.mime-subtype = $mime-wild & inc!(degree)))
      log-debug(*http-common-log*, "  MMT: 2 - degree = %s", degree);
      // a point for each matching parameter, ignoring "q".
      for (value keyed-by key in type1.attributes)
        if (key ~= "q" & value = element(type2.attributes, key, default: #f))
          inc!(degree)
        end;
      end;
    end;
  end;
  if (degree ~= 0)
    log-debug(*http-common-log*, "  MMT: 3 - returning degree = %s", degree);
    degree
  end;
end method match-media-types;

// This method returns #t if type1 is more specific than type2.
// A media type is considered more specific than another if it doesn't
// have a wildcard component and the other one does, or if it has more
// parameters (excluding "q").  See RFC 2616, 14.1.
//
define method media-type-more-specific?
    (type1 :: <media-type>, type2 :: <media-type>)
 => (more-specific? :: <boolean>)
  local method has-more-params? ()
          let nparams1 = type1.attributes.size - iff(has-attribute?(type1, "q"), 1, 0);
          let nparams2 = type2.attributes.size - iff(has-attribute?(type2, "q"), 1, 0);
          nparams1 > nparams2
        end;
  if (type1.mime-type = type2.mime-type)
    (type1.mime-subtype ~= $mime-wild & type2.mime-subtype = $mime-wild)
      | has-more-params?()
  else
    (type1.mime-type ~= $mime-wild & type2.mime-type = $mime-wild)
      | has-more-params?()
  end
end method media-type-more-specific?;

define method media-type-exact?
    (mr :: <media-type>) => (exact? :: <boolean>)
  mr.mime-type ~= $mime-wild & mr.mime-subtype ~= $mime-wild
end;

// Common case
define method media-type-quality
    (media-type :: <media-type>) => (q :: <float>)
  get-attribute(media-type, "q") | 1.0
end;

// Common case
define method media-type-level
    (media-type :: <media-type>) => (level :: false-or(<integer>))
  get-attribute(media-type, "level")
end;

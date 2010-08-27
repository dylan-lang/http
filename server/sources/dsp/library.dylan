Module:    dylan-user
Author:    Carl Gay
Copyright: Copyright (c) 2001-2010 Carl L. Gay.  All rights reserved.
           Original Code is Copyright (c) 2001 Functional Objects, Inc.  All rights reserved.
License:   Functional Objects Library Public License Version 1.0
Warranty:  Distributed WITHOUT WARRANTY OF ANY KIND

define library dsp
  use collections,
    import: { table-extensions };
  use common-dylan;
  use http-common;
  use io;
  use logging;
  use memory-manager;
  use mime;
  use network,
    import: { sockets };
  use regular-expressions;
  //use ssl-network;         // adds sideways methods to network lib
  use strings;
  use system,
    import: { date, file-system, locators, operating-system };
  use uncommon-dylan;
  use uri;
  use xml-parser;
  use xml-rpc-common;

  use koala;

  export dsp;
end library dsp;

define module dsp
  use table-extensions,
    import: { table },
    rename: { table => make-table };
  use common-extensions,
    exclude: { false?, true? };
  use date;
  use dylan;
  use file-system;
  use format,
    rename: { format-to-string => sformat };
  use http-common;
  use koala;
  use locators,
    import: { <locator>,
              <file-locator>,
              <directory-locator>,
              locator-relative?,
              simplify-locator,
              merge-locators,
              locator-directory };
  use logging,
    rename: { log-trace => %log-trace,
              log-debug => %log-debug,
              log-info => %log-info,
              log-warning => %log-warning,
              log-error => %log-error },
    export: all;
  use operating-system;
  use standard-io;
  use streams;
  use strings;
  use threads;
  use uncommon-dylan;
  use uri;
  use simple-xml,
    import: { with-xml };

  export
    page-source,
    page-template,
    page-template-setter,

    <dylan-server-page>,
    process-template,
    <taglib>,
    taglib-definer,
    tag-definer,            // Defines a new DSP tag function and registers it with a page
    register-tag,           // This can be used to register tag functions that weren't created by "define tag".
    map-tag-call-attributes,
    show-tag-call-attributes,
    get-tag-call-attribute,

    named-method-definer,
    get-named-method,

    // Utils associated with the <dsp:table> tag
    current-row,                 // dsp:table
    current-row-number,          // dsp:table

    // Utils associated with the <dsp:loop> tag.
    loop-index,
    loop-value,

    // Form handling
    validate-form-field,
    add-field-error,
    get-field-errors,
    add-page-note,
    add-page-error,
    page-has-errors?,

    <paginator>,
    paginator-sequence,
    current-page-number,
    current-page-number-setter,
    previous-page-number,
    next-page-number,
    page-count,
    page-size,
    page-links,
    <page-link>,
    page-link-page-number,
    page-link-label;

end module dsp;

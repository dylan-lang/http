Module: dsp
Author: Carl Gay
Copyright: See LICENSE in this distribution for details.
Synopsis: Utilities for DSP that otherwise can stand alone.

define sideways method process-config-element
    (server :: <http-server>, node :: xml$<element>, name == #"dsp")
  local method true-value? (value)
          member?(value, #("yes", "true", "on"), test: string-equal?)
        end;
  *reparse-templates?* := true-value?(get-attr(node, #"reparse-templates") | "no");
  log-info("DSP template reparse is %s.",
           iff(*reparse-templates?*, "enabled", "disabled"));
end method process-config-element;

define open class <paginator> (<sequence>)
  // The underlying sequence we're paging over.
  constant slot paginator-sequence :: <sequence>,
    required-init-keyword: sequence:;

  // 1-based current page number
  slot current-page-number :: <positive-integer> = 1,
    init-keyword: current-page-number:;

  constant slot page-size :: <positive-integer> = 20,
    init-keyword: page-size:;
end class <paginator>;

define method initialize
    (paginator :: <paginator>, #key)
  next-method();
  paginator.current-page-number := min(paginator.current-page-number,
                                       max(1, paginator.page-count));
end;

// Total number of pages in this paginator.
define open generic page-count
    (paginator :: <paginator>) => (count :: <integer>);

define method page-count
    (paginator :: <paginator>) => (count :: <integer>)
  ceiling/(paginator.paginator-sequence.size,
           paginator.page-size)
end;

define method next-page-number
    (paginator :: <paginator>) => (pnum :: false-or(<integer>))
  let next = paginator.current-page-number + 1;
  if (paginator.page-count >= next)
    next
  end
end;

define method previous-page-number
    (paginator :: <paginator>) => (pnum :: false-or(<integer>))
  let prev = paginator.current-page-number - 1;
  if (prev >= 1)
    prev
  end
end;

// A sequence of these is returned from the page-links method.
//
define open class <page-link> (<object>)
  // a page number, or #f to indicate that this item shouldn't
  // be a hyperlink.
  constant slot page-link-page-number :: false-or(<integer>),
    required-init-keyword: page-number:;

  // The text to display for this page link.  e.g., the page
  // number or "...".
  constant slot page-link-label :: <string>,
    required-init-keyword: label:;
end class <page-link>;

// Returns a sequence of <page-link>s.
//
define open generic page-links
    (paginator :: <paginator>,
     #key ellipsis :: false-or(<string>),
          prev :: false-or(<string>),
          next :: false-or(<string>),
          center-span :: false-or(<integer>),
          min-pages :: false-or(<integer>))
 => (page-links :: <sequence>);

// Generates page links that look like this, where the current page is 11:
//    Prev 1 ... 5 ... 10 11 12 ... 14 15 Next
// Idea copied from http://snipplr.com/view/3409/pager-for-lots-o-data/.
//
define method page-links
    (paginator :: <paginator>,
     #key ellipsis :: false-or(<string>),
          prev :: false-or(<string>),
          next :: false-or(<string>),
          center-span :: false-or(<integer>),
          min-pages :: false-or(<integer>))
 => (page-nums :: <sequence>)
  let ellipsis = ellipsis | "...";
  let prev = prev | "Prev";
  let next = next | "Next";
  let center-span = center-span | 3;
  let min-pages = min-pages | 15;
  let links = make(<stretchy-vector>);
  let center = paginator.current-page-number;
  let total  = paginator.page-count;
  let max-page = 0;
  local method add-link (page, #key label)
          if (~page | (page > max-page & page <= total))
            add!(links, make(<page-link>,
                             page-number: page ~= center & page,
                             label: label | integer-to-string(page)))
          end;
          if (page)
            max-page := max(max-page, page);
          end;
        end;
  local method add-range(bpos, epos)
          if (bpos < epos)
            // does NOT add links for bpos or epos
            if (epos - bpos >= 3)
              add-link(#f, label: ellipsis);
            else
              // this loop may have zero iterations
              for (i from bpos + 1 below epos)
                if (i >= 1)
                  add-link(i);
                end;
              end;
            end;
          end;
        end method;
  if (total > 1)
    // Prev link
    if (paginator.previous-page-number)
      add!(links, make(<page-link>,
                       page-number: paginator.previous-page-number,
                       label: prev));
    end;
    if (total <= min-pages)
      // Just list all the pages
      for (i from 1 to total)
        add-link(i);
      end;
    else
      // Each of the following variables is exemplified by a number in this
      // paginator, as indicated in the comments at the end of each line:
      //    Prev 1 ... 5 ... 10 11 12 ... 14 15 Next
      let center-left  = max(1, center - floor/(center-span, 2));      // 10
      let center-right = min(total, center + floor/(center-span, 2));  // 12
      let half-left  = max(1, round/(center-left - 1, 2));             // 5
      let half-right = min(total, center-right + round/(total - center-right, 2));  // 14
      // First page
      add-link(1);

      // Halfway between 1 and center group
      add-range(1, half-left);
      add-link(half-left);
      add-range(half-left, center-left);

      // Central group of pages
      for (i from center-left to center-right)
        add-link(i, label: integer-to-string(i));
      end;

      // Half way between center group and total.
      add-range(center-right, half-right);
      add-link(half-right);
      add-range(half-right, total);

      // Last page
      add-link(total);
    end;

    // Next link
    if (paginator.next-page-number)
      add!(links, make(<page-link>,
                       page-number: paginator.next-page-number,
                       label: next));
    end;
  end if; // total > 1

  links
end method page-links;

// fip iterates over the elements in the current page.
// this is probably silly, since just defining paginator-current-page-sequence
// would have been a lot easier.  but i wanted to have the experience of writing
// a fip. :)
//
define method forward-iteration-protocol
    (ptor :: <paginator>)
 => (initial-state :: <object>,
     limit :: <object>,
     next-state :: <function>,
     finished-state? :: <function>,
     current-key :: <function>,
     current-element :: <function>,
     current-element-setter :: <function>,
     copy-state :: <function>)
  let start-index = max(0, min((ptor.current-page-number - 1) * ptor.page-size,
                               (ptor.page-count - 1) * ptor.page-size));
  values(start-index,                                   // initial state
         min(ptor.paginator-sequence.size,              // limit
             start-index + ptor.page-size),
         method (ptor, state) state + 1 end,            // next state
         method (ptor, state, limit) state >= limit end, // finished state?
         method (ptor, state) state end,                // current key
         method (ptor, state)                           // element
           ptor.paginator-sequence[state]
         end,
         method (new-value, ptor, state)                // element setter
           error("<paginator>s are immutable");
         end,
         method (ptor, state) state end)                // copy-state
end method forward-iteration-protocol;

define tag show-page-links in dsp
    (page :: <dylan-server-page>)
    (name :: <string>, url :: <string>, query-value :: <string>,
     context, ellipsis, prev, next, center-span, min-pages)
  let paginator :: false-or(<paginator>) = get-context-value(name, context);
  let links = page-links(paginator,
                         ellipsis: ellipsis,
                         prev: prev,
                         next: next,
                         center-span: center-span & string-to-integer(center-span),
                         min-pages: min-pages & string-to-integer(min-pages));
  // TODO: There should be a special css class for the current page;
  //       currently it's just "unlinked-page-number".
  output("%s",
         with-xml ()
           span (class => "paginator") {
             do(for (page-link :: <page-link> in links,
                     i from 1)
                  let pn = page-link.page-link-page-number;
                  let label = page-link.page-link-label;
                  collect(if (pn)
                            with-xml ()
                              a(label,
                                href => format-to-string("%s%d", url, pn),
                                class => "page-number-link")
                            end
                          else
                            with-xml ()
                              span(label, class => "unlinked-page-number")
                            end;
                          end);
                  if (i < links.size)
                    collect(with-xml ()
                              span(" ", class => "page-number-separator")
                            end)
                  end;
                  collect(with-xml () text("\n") end);
                end)
           }
         end with-xml);
end tag show-page-links;


Module:    %http-common-byte-string
Author:    Gail Zacharias, Carl Gay
Copyright: See LICENSE in this distribution for details.
Synopsis:  Low-level string utilities designed to be as fast as possible.
           This code assumes <byte-string>s only.  It was originally written
           for use in the HTTP server.  (Note that a different definition of
           whitespace is used in this file.)


define constant $cr = as(<character>, 13);  // \r
define constant $lf = as(<character>, 10);  // \n

define inline function char-position-if (test? :: <function>,
                                         buf :: <byte-string>,
                                         bpos :: <integer>,
                                         epos :: <integer>)
  => (pos :: false-or(<integer>))
  iterate loop (pos :: <integer> = bpos)
    unless (pos == epos)
      if (test?(buf[pos])) pos else loop(pos + 1) end;
    end;
  end;
end;

define function char-position (ch :: <byte-character>,
                               buf :: <byte-string>,
                               bpos :: <integer>,
                               epos :: <integer>)
  => (pos :: false-or(<integer>))
  char-position-if(method(c) c == ch end, buf, bpos, epos);
end char-position;

define function char-position-from-end (ch :: <byte-character>,
                                        buf :: <byte-string>,
                                        bpos :: <integer>,
                                        epos :: <integer>)
  => (pos :: false-or(<integer>))
  iterate loop (pos :: <integer> = epos)
    unless (pos == bpos)
      let npos = pos - 1;
      if (ch == buf[npos]) npos else loop(npos) end;
    end;
  end;
end char-position-from-end;

// Note that this doesn't check for stray cr's or lf's, because
// those are just random control chars, proper crlf's got
// eliminated during header reading.
define inline function %whitespace? (ch :: <byte-character>)
  ch == '\t' | ch == ' '
end;

define function whitespace-position (buf :: <byte-string>,
                                     bpos :: <integer>,
                                     epos :: <integer>)
  => (pos :: false-or(<integer>))
  char-position-if(%whitespace?, buf, bpos, epos);
end whitespace-position;

define function skip-whitespace (buffer :: <byte-string>,
                                 bpos :: <integer>,
                                 epos :: <integer>)
  => (pos :: <integer>)
  iterate fwd (pos :: <integer> = bpos)
    if (pos >= epos | ~%whitespace?(buffer[pos]))
      pos
    else
      fwd(pos + 1)
    end;
  end;
end skip-whitespace;

define function trim-whitespace (buffer :: <byte-string>,
                                 start :: <integer>,
                                 endp :: <integer>)
  => (start :: <integer>, endp :: <integer>)
  let pos = skip-whitespace(buffer, start, endp);
  values(pos,
         if (pos == endp)
           endp
         else
           iterate bwd (epos :: <integer> = endp)
             let last = epos - 1;
             if (last >= start & %whitespace?(buffer[last]))
               bwd(last)
             else
               epos
             end;
           end;
         end)
end trim-whitespace;

define function digit-weight (ch :: <byte-character>) => (n :: false-or(<integer>))
  when (ch >= '0')
    let n = logior(as(<integer>, ch), 32) - as(<integer>, '0');
    if (n <= 9)
      n
    else
      let n = n - (as(<integer>, 'a') - as(<integer>, '0') - 10);
      10 <= n & n <= 15 & n
    end;
  end;
end digit-weight;


define function substring
    (str :: <byte-string>, bpos :: <integer>, epos :: <integer>)
  if(bpos == 0 & epos == str.size)
    str
  else
    copy-sequence(str, start: bpos, end: epos)
  end
end function substring;

define function string-extent
    (str :: <byte-string>)
 => (str :: <byte-string>, bpos :: <integer>, epos :: <integer>)
  values(str, 0, str.size)
end;

module: buddha
author: Hannes Mehnert <hannes@mehnert.org>

define class <mac-address> (<wrapper-sequence>)
end;

define method \= (a :: <mac-address>, b :: <mac-address>)
 => (res :: <boolean>)
  block(done)
    for (ele1 in a,
         ele2 in b)
      unless (ele1 = ele2)
        done(#f);
      end;
    end;
    done(#t);
  end;
end;

define method as (class == <mac-address>, mac :: <string>)
 => (res :: <mac-address>)
  block(parse-error)
    mac := as-lowercase(mac);
    if (any?(method(x) x = ':' end, mac))
      //try to parse xx:xx:xx:xx:xx:xx
      let fields = split(mac, ':');
      //check that we really have a valid mac address
      unless (size(fields) = 6)
        //6 fields
        parse-error(#f);
      end unless;
      unless (every?(method(x) x.size = 2 end, fields))
        //each containing 2 characters
        parse-error();
      end unless;
      for (field in fields)
        for (ele in field)
          unless (hexadecimal-digit?(ele))
            parse-error(#f);
          end unless;
        end for;
      end for;
      let res = make(<list>, size: 6);
      for (i from 0 below res.size)
        res[i] := fields[i];
      end;
      make(<mac-address>, data: res);
    elseif (size(mac) = 12)
      //assume xxxxxxxxxxxx
      for(ele in mac)
        unless (hexadecimal-digit?(ele))
          parse-error(#f);
        end unless;
      end for;
      let res = make(<list>, size: 6);
      for (i from 0 below mac.size by 2,
           j from 0)
        res[j] := copy-sequence(mac, start: i, end: i + 2);
      end;
      make(<mac-address>,
           data: res);
    else
      //something completely different
      parse-error(#f);
    end if;
  end block;
end;

define method as (class == <string>, mac :: <mac-address>)
 => (string :: <string>)
  reduce1(method(a,b) concatenate(a, ":", b) end, mac.data);
end;

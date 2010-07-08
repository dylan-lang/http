module: buddha
author: Hannes Mehnert <hannes@mehnert.org>

define web-class <vlan> (<reference-object>)
  data number :: <integer>;
  data name :: <string>;
  data description :: <string>;
end;

define method print-object (vlan :: <vlan>, stream :: <stream>)
 => ()
  format(stream, "VLAN %s\n", as(<string>, vlan))
end;

define method as (class == <string>, vlan :: <vlan>)
 => (res :: <string>)
  concatenate(integer-to-string(vlan.number), " ", vlan.name);
end;

define method \< (a :: <vlan>, b :: <vlan>)
 => (res :: <boolean>)
  a.number < b.number
end;

define function print-export-summary (stream :: <stream>, dvlan :: <vlan>)
  let subs = map(curry(as, <string>),
                 choose(method(x)
                   x.vlan = dvlan
                 end, storage(<subnet>)));
  format(stream, "%s,%s,%s,%s\n",
         dvlan.name, dvlan.number, dvlan.description,
         if (subs.size > 0)
           reduce1(method(a, b) concatenate(a, ",", b) end, subs)
         else
           ""
         end)
end;

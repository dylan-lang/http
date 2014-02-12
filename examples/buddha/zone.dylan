module: buddha
author: Hannes Mehnert <hannes@mehnert.org>

define web-class <cname> (<object>)
  data source :: <string>;
  data target :: <string>;
end;

define method print-object (cname :: <cname>, stream :: <stream>)
 => ();
  format(stream, "CNAME: %s\n", as(<string>, cname));
end method;

define method as (class == <string>, cname :: <cname>)
 => (res :: <string>)
  concatenate(cname.source, " => ", cname.target);
end;

define method \< (a :: <cname>, b :: <cname>)
 => (res :: <boolean>)
  a.source < b.source
end;

define web-class <host-record> (<object>)
  data host-name :: <string>;
  data ipv4-address :: <ipv4-address> = $bottom-v4-address;
  data ipv6-address :: <ipv6-address> = $bottom-v6-address;
  data time-to-live :: <integer> = 300;
end;

define method print-object (a :: <host-record>, stream :: <stream>)
 => ();
  format(stream, "A: %s\n", as(<string>, a));
end method;

define method as (class == <string>, a :: <host-record>)
 => (res :: <string>)
  concatenate(a.host-name, " ", as(<string>, a.ipv4-address), " ", as(<string>, a.ipv6-address));
end;

define method \< (a :: <host-record>, b :: <host-record>)
 => (res :: <boolean>)
  a.host-name < b.host-name
end;

define web-class <mail-exchange> (<object>)
  data mx-name :: <string>;
  data priority :: <integer> = 23;
end;

define method print-object (mx :: <mail-exchange>, stream :: <stream>)
 => ();
  format(stream, "MX: %s\n", as(<string>, mx));
end method;

define method as (class == <string>, mx :: <mail-exchange>)
 => (res :: <string>)
  concatenate(mx.mx-name, ":", integer-to-string(mx.priority));
end;

define method \< (a :: <mail-exchange>, b :: <mail-exchange>)
 => (res :: <boolean>)
  a.mx-name < b.mx-name;
end;

define web-class <nameserver> (<object>)
  data ns-name :: <string>;
end;

define method print-object (ns :: <nameserver>, stream :: <stream>)
 => ();
  format(stream, "NS: %s\n", as(<string>, ns));
end method;

define method as (class == <string>, ns :: <nameserver>)
 => (res :: <string>)
  ns.ns-name;
end;

define method \< (a :: <nameserver>, b :: <nameserver>)
 => (res :: <boolean>)
  a.ns-name < b.ns-name;
end;

define web-class <zone> (<reference-object>)
  slot used-names :: <string-table> = make(<string-table>);
  data zone-name :: <string>;
  slot reverse? :: <boolean> = #f;
  has-many cname :: <cname>;
  data hostmaster :: <string> = "hostmaster.congress.ccc.de";
  data serial :: <integer> = 23;
  data refresh :: <integer> = 16384;
  data retry :: <integer> = 2048;
  data expire :: <integer> = 1048576;
  data time-to-live :: <integer> = 1800;
  data minimum :: <integer> = 2560;
  has-many nameserver :: <nameserver>;
  has-many mail-exchange :: <mail-exchange>;
  has-many host-record :: <host-record>;
  //has-many text :: <string>;
end;

define method initialize (zone :: <zone>,
                          #rest rest, #key, #all-keys)
  next-method();
  for (ele in *nameserver*)
    zone.nameservers := add!(zone.nameservers, ele);
  end;
end;

define method print-object (zone :: <zone>, stream :: <stream>)
 => ();
  format(stream, "Zone: %s\n", as(<string>, zone));
end method;

define method as (class == <string>, zone :: <zone>)
 => (res :: <string>)
  zone.zone-name;
end;

define method \< (a :: <zone>, b :: <zone>) => (res :: <boolean>)
  if (b.reverse?)
    if (a.reverse?)
      a.zone-name < b.zone-name
    else
      #t
    end
  else
    if (a.reverse?)
      #f
    else
      a.zone-name < b.zone-name
    end
  end
end;

define variable *last-update* = current-date();
define method print-tinydns-zone-file (print-zone :: <zone>,
                                       stream :: <stream>)
  if (*last-update* + make(<duration>, minutes: 4) < current-date())
    print-zone.serial := print-zone.serial + 1;
    *last-update* := current-date();
  end;
  //Zfqdn:mname:rname:ser:ref:ret:exp:min:ttl:timestamp:lo
  format(stream, "Z%s:%s.:%s.:%d:%d:%d:%d:%d:%d\n",
         print-zone.zone-name, print-zone.nameservers[0].ns-name,
         print-zone.hostmaster, print-zone.serial,
         print-zone.refresh, print-zone.retry,
         print-zone.expire, print-zone.minimum,
         print-zone.time-to-live);
  //nameserver
  do(method(x)
         format(stream, "&%s::%s.\n", print-zone.zone-name, x.ns-name)
     end, print-zone.nameservers);
  //MX
  do(method(x)
       format(stream, "@%s::%s.%s:%d\n",
              print-zone.zone-name, mx-name(x), print-zone.zone-name, priority(x));
     end, print-zone.mail-exchanges);
  //reverse zones for networks
  do(method(x)
       format(stream, "Z%s:%s.:%s.:%d:%d:%d:%d:%d:%d\n",
              x, print-zone.nameservers[0].ns-name,
              print-zone.hostmaster, print-zone.serial,
              print-zone.refresh, print-zone.retry,
              print-zone.expire, print-zone.minimum,
              print-zone.time-to-live);
       do(method(y)
            format(stream, "&%s::%s.\n", x, y.ns-name)
          end, print-zone.nameservers);
       if (subsequence-position(x, "in-addr.arpa"))
         format(stream, "&%s::%s.\n", x, "ns.ripe.net")
       end;
     end, apply(concatenate, map(get-reverse-cidrs, storage(<network>))));
  //Hosts
  do(method(x)
       format(stream, "=%s.%s:%s:%d\n",
              x.host-name,
              print-zone.zone-name,
              as(<string>, x.ipv4-address),
              x.time-to-live);
       unless (x.ipv6-address = $bottom-v6-address)
         format(stream, "6%s.%s:%s:%d\n",
                x.host-name,
                print-zone.zone-name,
                as-dns-string(x.ipv6-address),
                x.time-to-live);
       end;
     end, choose(method(x)
                   x.zone = print-zone
                 end, storage(<host>)));
  //A
  do(method(x)
       unless (x.ipv4-address = $bottom-v4-address)
         format(stream, "+%s.%s:%s:%d\n",
                x.host-name,
                print-zone.zone-name,
                as(<string>, x.ipv4-address),
                x.time-to-live);
       end;
       unless (x.ipv6-address = $bottom-v6-address)
         format(stream, "3%s.%s:%s:%d\n",
                x.host-name,
                print-zone.zone-name,
                as-dns-string(x.ipv6-address),
                x.time-to-live);
       end;
     end, print-zone.host-records);
  //CNAME
  do(method(x)
       format(stream, "C%s.%s:%s.%s\n",
              source(x), print-zone.zone-name, target(x), print-zone.zone-name);
     end, print-zone.cnames);
end;



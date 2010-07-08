module: buddha
author: Hannes Mehnert <hannes@mehnert.org>

define web-class <host> (<object>)
  data host-name :: <string>;
  data mac-address :: <mac-address> = as(<mac-address>, "00deadbeef00");
  data ipv4-address :: <ipv4-address>;
  data ipv6-address :: <ipv6-address>, autoconf-v6(object.ipv6-subnet, object.mac-address);
  data time-to-live :: <integer> = 300;
  has-a ipv4-subnet;
  has-a ipv6-subnet = $bottom-v6-subnet;
  has-a zone;
end;

define method print-object (host :: <host>, stream :: <stream>)
 => ()
  format(stream, "Host: %s\n", as(<string>, host))
end;

define method \< (a :: <host>, b :: <host>) => (res :: <boolean>)
  a.ipv4-address < b.ipv4-address
end;

define method as (class == <string>, host :: <host>)
 => (res :: <string>)
  concatenate(host.host-name, " ", as(<string>, host.ipv4-address));
end;

define method print-isc-dhcpd-file (host :: <host>, stream :: <stream>)
 => ()
  format(stream, "host %s {\n", host.host-name);
  format(stream, "\thardware ethernet %s;\n", as(<string>, host.mac-address));
  format(stream, "\tfixed-address %s;\n", as(<string>, host.ipv4-address));
  format(stream, "}\n\n");
end;


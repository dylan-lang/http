module: buddha
author: Hannes Mehnert <hannes@mehnert.org>

//XXX: this should be dynamic generated...
//without these I get lots of warnings:
//Invalid type for argument object in call to
// hosts (object :: <object>) => (#rest results :: <object>):  <zone> supplied, <subnet> expected.
//define dynamic generic hosts (o :: <object>) => (r :: <object>);
//define dynamic generic hosts-setter (h :: <object>, o :: <object>)
// => (r :: <object>);

define abstract web-class <subnet> (<network>)
  has-a vlan;
  has-a network;
end;

define method make (class == <subnet>,
                    #rest rest, #key cidr, #all-keys) => (res :: <subnet>)
  let version =
    ip-version(if (instance?(cidr, <string>)) as(<cidr>, cidr) else cidr end);
  if (version = 4)
    apply(make, <ipv4-subnet>, rest);
  elseif (version = 6)
    apply(make, <ipv6-subnet>, rest);
  end;
end;
define web-class <ipv6-subnet> (<subnet>, <ipv6-network>)
end;

define class <bottom-v6-subnet> (<ipv6-subnet>)
end;

define method as (class == <string>, f :: <bottom-v6-subnet>) => (res :: <string>);
  "no ipv6 for you!"
end;
define method storage (class == <ipv6-subnet>) => (res)
  choose(rcurry(instance?, <ipv6-subnet>), storage(<subnet>));
end;
define method collect-dhcp-into-table (n :: <ipv6-subnet>)
  with-xml() td end;
end;

define method dhcp-stuff (n :: <ipv6-network>)
  #()
end;

define web-class <ipv4-subnet> (<subnet>, <ipv4-network>)
  data dhcp-start :: <ipv4-address>, get-reasonable-dhcp-start(object);
  data dhcp-end :: <ipv4-address>, broadcast-address(object.cidr) - 1;
  data dhcp-router :: <ipv4-address>, base-network-address(object.cidr) + 1;
end;

define function get-reasonable-dhcp-start (object :: <ipv4-subnet>)
  if (object.cidr.cidr-netmask < 26)  
    base-network-address(object.cidr) + 21;
  elseif (object.cidr.cidr-netmask < 30)
    base-network-address(object.cidr) + 3;
  elseif (object.cidr.cidr-netmask = 30)
    base-network-address(object.cidr) + 1;
  end;
end;
define method storage (class == <ipv4-subnet>) => (res)
  choose(rcurry(instance?, <ipv4-subnet>), storage(<subnet>));
end;

define method collect-dhcp-into-table (x :: <ipv4-subnet>)
  with-xml()
    td(show(x.dhcp?))
  end;
end;

define method dhcp-stuff (dsubnet :: <ipv4-network>)
  let res = make(<stretchy-vector>);
  add!(res, with-xml()
              h2(concatenate("DHCP options for subnet ", show(dsubnet)))
            end);
  if (dsubnet.dhcp-options.size > 0)
    add!(res, with-xml()
                ul { do(map(method(x) with-xml()
                                        li { text(x),
                                             do(remove-form(x, dsubnet.dhcp-options,
                                                            url: "subnet-detail",
                                                            xml: with-xml()
                                                                   input(type => "hidden",
                                                                         name => "subnet",
                                                                         value => get-reference(dsubnet))
                                                                 end)) }
                                      end
                            end, dsubnet.dhcp-options)) }
              end);
  end;
  add!(res, with-xml()
              do(add-form(<string>, "dhcp options", dsubnet.dhcp-options,
                          refer: "subnet-detail",
                          xml: with-xml()
                                 input(type => "hidden",
                                       name => "subnet",
                                       value => get-reference(dsubnet))
                               end))
            end);
  res;
end;

define method print-object (subnet :: <subnet>, stream :: <stream>)
 => ()
  format(stream, "Subnet %s\n", as(<string>, subnet));
end;

define method as (class == <string>, subnet :: <subnet>)
 => (res :: <string>)
  as(<string>, subnet.cidr);
end;

define method print-isc-dhcpd-file (print-subnet :: <ipv4-subnet>, stream :: <stream>)
 => ()
  if (print-subnet.dhcp?)
    format(stream, "subnet %s netmask %s {\n",
           as(<string>, network-address(print-subnet.cidr)),
           as(<string>, netmask-address(print-subnet.cidr)));
    if (print-subnet.dhcp-router)
      format(stream, "\toption routers %s;\n",
             as(<string>, print-subnet.dhcp-router));
    end if;
    if (print-subnet.dhcp-default-lease-time)
      format(stream, "\tdefault-lease-time %d;\n",
             print-subnet.dhcp-default-lease-time);
    end if;
    if (print-subnet.dhcp-max-lease-time)
      format(stream, "\tmax-lease-time %d;\n",
             print-subnet.dhcp-max-lease-time);
    end if;
    do(method(x)
           format(stream, "\t%s\n", x);
       end, print-subnet.dhcp-options);
    do(method(x)
           format(stream, "\trange %s %s;\n",
                  as(<string>, head(x)),
                  as(<string>, tail(x)));
       end, generate-dhcp-ranges(print-subnet));
    format(stream, "}\n\n");
    do(method(x)
           print-isc-dhcpd-file(x, stream);
       end, choose(method(x)
                       x.ipv4-subnet = print-subnet
                   end, storage(<host>)))

  end if;
end;

define method generate-dhcp-ranges (this-subnet :: <ipv4-subnet>)
 => (list :: <list>)
  let start-ip :: <ipv4-address> = this-subnet.dhcp-start;
  let end-ip :: <ipv4-address> = this-subnet.dhcp-end;
  let res = make(<list>);
  for (host in choose(method(x)
                          x.ipv4-subnet = this-subnet
                      end, storage(<host>)))
    let host-ip = host.ipv4-address;
    if ((host-ip > start-ip) & (host-ip <= end-ip))
      res := add!(res, pair(start-ip, host-ip - 1));
    end;
    if (host-ip >= start-ip)
      start-ip := host-ip + 1;
    end;
  end for;
  if (start-ip <= end-ip)
    res := add!(res, pair(start-ip, end-ip));
  end;
  reverse(res);
end;

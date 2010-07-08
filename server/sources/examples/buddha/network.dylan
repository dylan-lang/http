module: buddha
author: Hannes Mehnert <hannes@mehnert.org>

define abstract web-class <network> (<reference-object>)
  data cidr :: <cidr>;
end;

define method make (class == <network>,
                    #rest rest, #key cidr, #all-keys) => (res :: <network>)
  let version =
    ip-version(if (instance?(cidr, <string>)) as(<cidr>, cidr) else cidr end);
  if (version = 4)
    apply(make, <ipv4-network>, rest);
  elseif (version = 6)
    apply(make, <ipv6-network>, rest);
  end;
end;
define web-class <ipv6-network> (<network>)
end;

define method collect-dhcp-into-table (n :: <ipv6-network>) => (res :: <collection>)
  let e = with-xml() td end;
  list(e,e,e);
end;
define web-class <ipv4-network> (<network>)
  data dhcp? :: <boolean> = #t;
  data dhcp-default-lease-time :: <integer> = 1800;
  data dhcp-max-lease-time :: <integer> = 7200;
  has-many dhcp-option :: <string>;
end;

define method collect-dhcp-into-table (n :: <ipv4-network>) => (res :: <collection>)
  let res = make(<stretchy-vector>);
  add!(res, with-xml() td(show(n.dhcp?)) end);
  add!(res, with-xml() td end);
  add!(res, with-xml() td { do(if(n.dhcp?)
                                 with-xml()
                                   a("dhcpd.conf",
                                     href => concatenate("/dhcp?network=",
                                                         get-reference(n)))
                                 end
                               end) }
             end);
  res;
end;
define method \< (a :: <network>, b :: <network>)
 => (res :: <boolean>)
  a.cidr < b.cidr;
end;

define method as (class == <string>, network :: <network>)
 => (res :: <string>)
  as(<string>, network.cidr)
end;

define method subnet-in-network? (subnet :: <subnet>)
 => (res :: <boolean>)
  //we already know that the subnet doesn't conflict with other subnets
  //and only need to check whether it is in the network subnet.network
  let sub-cidr = subnet.cidr;
  let net-cidr = subnet.network.cidr;
  if (((network-address(sub-cidr) > network-address(net-cidr)) |
         (network-address(sub-cidr) = network-address(net-cidr))) &
        ((broadcast-address(sub-cidr) < broadcast-address(net-cidr)) |
           (broadcast-address(sub-cidr) = broadcast-address(net-cidr))))
    #t
  else
    #f
  end
end;

define method ip-in-net? (net :: <network>, ip-addr :: <ip-address>)
 => (res :: <boolean>)
  (((ip-addr > network-address(net.cidr)) |
      (ip-addr = network-address(net.cidr))) &
     (ip-addr <= broadcast-address(net.cidr)));
end;

define method print-object (network :: <network>, stream :: <stream>)
 => ()
  format(stream, "Network: CIDR: %s\n", as(<string>, network));
end;

define function get-reverse-cidrs (network :: <network>)
  let mask = 8 * (ceiling/(network.cidr.cidr-netmask, 8));
  if (mask ~= network.cidr.cidr-netmask)
    map(cidr-to-reverse-zone, split-cidr(network.cidr, mask));
  else
    list(cidr-to-reverse-zone(network.cidr))
  end;
end;
define method print-isc-dhcpd-file (print-network :: <ipv4-network>,
                                    stream :: <stream>)
  => ();
  if (print-network.dhcp?)
    if (print-network.dhcp-default-lease-time)
      format(stream, "default-lease-time %d;\n",
             print-network.dhcp-default-lease-time);
    end if;
    if (print-network.dhcp-max-lease-time)
      format(stream, "max-lease-time %d;\n",
             print-network.dhcp-max-lease-time);
    end if;
    do(method(x)
           format(stream, "%s\n", x);
       end, print-network.dhcp-options);
    format(stream, "\n");
    do(method(x)
           print-isc-dhcpd-file(x, stream);
       end, choose(method(x)
                       x.network = print-network
                   end, storage(<subnet>)))
  end if;
end;

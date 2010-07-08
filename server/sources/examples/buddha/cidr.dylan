module: buddha
author: Hannes Mehnert <hannes@mehnert.org>

define class <cidr> (<object>)
  slot cidr-network-address :: <ip-address>,
    required-init-keyword: network-address:;
  slot cidr-netmask :: <integer>,
    required-init-keyword: netmask:;
end class;

define method ip-version (cidr :: <cidr>) => (res :: <integer>)
  if (instance?(cidr.cidr-network-address, <ipv4-address>))
    4
  elseif (instance?(cidr.cidr-network-address, <ipv6-address>))
    6;
  end;
end;
define method \< (a :: <cidr>, b :: <cidr>)
 => (res :: <boolean>)
  a.cidr-network-address < b.cidr-network-address
end;

define method \= (a :: <cidr>, b :: <cidr>)
 => (res :: <boolean>)
  if (a.cidr-netmask = b.cidr-netmask)
    a.cidr-network-address = b.cidr-network-address
  else
    #f;
  end;
end;

define method print-object (cidr :: <cidr>, stream :: <stream>)
 => ()
  format(stream, "%s", as(<string>, cidr));
end;

define method as (class == <string>, cidr :: <cidr>)
 => (res :: <string>)
  concatenate(as(<string>, network-address(cidr)), "/",
              integer-to-string(cidr.cidr-netmask));
end;

define method as(class == <cidr>, string :: <string>)
 => (res :: <cidr>)
  let address-and-mask = split(string, '/');
  unless (address-and-mask.size = 2)
    signal(make(<web-error>, error: "CIDR syntax wrong IP/Netmask[prefixlen]"));
  end;
  let network-address = address-and-mask[0];
  let netmask = address-and-mask[1];
  network-address := make(<ip-address>, data: network-address);
  if (any?(method(x) x = '.' end, netmask))
    //support for xx.xx.xx.xx
    netmask := string-to-netmask(netmask);
  else
    netmask := string-to-integer(netmask);
  end if;
  make(<cidr>, network-address: network-address, netmask: netmask)
end;

define method base-network-address (cidr :: <cidr>)
 => (ip-address :: <ip-address>)
  make(<ip-address>,
       data: map(logand,
                 netmask-address(cidr),
                 network-address(cidr)))
end;

define method broadcast-address (cidr :: <cidr>)
 => (ip-address :: <ip-address>)
  let mask = map(method(x)
                     logand(255, lognot(x));
                 end, netmask-address(cidr));
  make(cidr.cidr-network-address.object-class,
       data: map(logior,
                 network-address(cidr),
                 mask));
end;

define method network-address (cidr :: <cidr>)
 => (ip-address :: <ip-address>)
  cidr.cidr-network-address;
end;

define method netmask-address (cidr :: <cidr>)
 => (ip-address :: <ip-address>)
  as(cidr.cidr-network-address.object-class, cidr.cidr-netmask);
end;

define method cidr-in-cidr? (smaller :: <cidr>, bigger :: <cidr>)
  ((base-network-address(bigger) < base-network-address(smaller))
   | (base-network-address(bigger) = base-network-address(smaller)))
  & ((base-network-address(smaller) < broadcast-address(bigger))
      | (base-network-address(smaller) = broadcast-address(bigger)))
  & ((broadcast-address(smaller) < broadcast-address(bigger))
      | (broadcast-address(smaller) = broadcast-address(bigger)))
end;

define method split-cidr (cidr :: <cidr>, bitmask :: <integer>)
  let result = make(<stretchy-vector>);
  if (cidr.cidr-netmask <= bitmask)
    block(return)
      let cur-cidr = make(<cidr>,
                          network-address: cidr.cidr-network-address,
                          netmask: bitmask);
      while (cidr-in-cidr?(cur-cidr, cidr))
        result := add!(result, cur-cidr);
        cur-cidr := make(<cidr>,
                         network-address: cur-cidr.network-address + ash(2, 31 - bitmask),
                         netmask: bitmask);
      end;
    end;
  end;
  result;
end;

define method cidr-to-reverse-zone (cidr :: <cidr>)
  => (zone-name :: <string>)
  let res = "";
  let nums = truncate/(cidr.cidr-netmask, 8);
  for (i from nums - 1 to 0 by -1)
    res := concatenate(res, ip-address-to-string(cidr.cidr-network-address, i))
  end;
  concatenate(res, if (instance?(cidr.cidr-network-address, <ipv4-address>))
                     "in-addr.arpa."
                   elseif (instance?(cidr.cidr-network-address, <ipv6-address>))
                     "ip6.arpa"
                   end);
end;



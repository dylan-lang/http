module: buddha
Author: Hannes Mehnert <hannes@mehnert.org>

define class <ipv6-address> (<ip-address>)
end;

define method address-size (ip == <ipv6-address>)
  16
end;
define method address-size (ip :: <ipv6-address>)
  16
end;


define method autoconf-v6 (subnet :: <bottom-v6-subnet>, mac :: <mac-address>)
 => (res :: <ipv6-address>)
  $bottom-v6-address
end;
define method autoconf-v6 (subnet :: <ipv6-subnet>, mac :: <mac-address>)
 => (res :: <ipv6-address>)
  //hmm, well, ok, this is an evil hack which will not work always....
  //preconditions: prefixlen == 64 (otherwise will be padded with 0s)
  let res = network-address(subnet.cidr);
  res[15] := string-to-integer(mac[5], base: 16);
  res[14] := string-to-integer(mac[4], base: 16);
  res[13] := string-to-integer(mac[3], base: 16);
  res[12] := #xfe;
  res[11] := #xff;
  res[10] := string-to-integer(mac[2], base: 16);
  res[9] := string-to-integer(mac[1], base: 16);
  res[8] := string-to-integer(mac[0], base: 16);
  res;
end;

define method as (class == <ipv6-address>, data :: <string>) => (res :: <ipv6-address>)
  //XXXX:XXXX::XXXX
  if (data = "no v6 address assigned")
    $bottom-v6-address;
  else
  let res = make(<byte-vector>, size: 16, fill: 0);
  let numbers = split(data, ':');
  let rev-parse? = #f;
  local method set-bytes (offset :: <integer>, value :: <integer>)
          res[offset] := ash(value, -8);
          res[offset + 1] := logand(value, #xff);
        end;
  block (ret)
    for (n in numbers, i from 0 by 2)
      let n-size = n.size;
      if (n-size = 0)
        rev-parse? := #t;
        ret()
      else
        set-bytes(i, string-to-integer(n, base: 16));
      end;
    end;
  end;
  if (rev-parse?)
    block(ret)
      for (i from 14 to 0 by -2,
           n in reverse(numbers))
        if (n.size > 0)
          set-bytes(i, string-to-integer(n, base: 16));
        else
          ret();
        end;
      end;
    end;
  end;
  make(<ipv6-address>, data: res);
  end;
end;

define method as-dns-string (ip :: <ipv6-address>) => (res)
  if (ip ~= $bottom-v6-address)
    let strings = make(<list>);
    for (i from 0 below 16)
      strings := add!(strings, integer-to-string(ip.data[i], base: 16, size: 2));
    end;
    reduce1(concatenate, reverse(strings));
  end;
end;
define method as (class == <string>, ip :: <ipv6-address>) => (res :: <string>)
  if (ip = $bottom-v6-address)
    "no v6 address assigned"
  else
    let strings = make(<list>);
    for (i from 0 below 16 by 2)
      let count = ash(ip[i], 8) + ip[i + 1]; 
      strings := add!(strings, integer-to-string(count, base: 16));
    end;
    reduce1(method(x, y) concatenate(x, ":", y) end, reverse(strings));
  end;
end;

define constant $bottom-v6-address = as(<ipv6-address>, "ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff");


define method ip-address-to-string (ip :: <ipv6-address>, index :: <integer>) => (res :: <string>)
  let s1 = integer-to-string(ip[index], base: 16, size: 2);
  concatenate(copy-sequence(s1, start: 1), ".",
              copy-sequence(s1, end: 1), ".");
end;  
  

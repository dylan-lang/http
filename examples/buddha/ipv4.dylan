module: buddha
author: Hannes Mehnert <hannes@mehnert.org>

define class <ip-address> (<mutable-wrapper-sequence>)
end;

define method make (ip-address == <ip-address>,
                    #next next-method,
                    #rest rest,
                    #key data,
                    #all-keys) => (res :: <ip-address>)
  if (instance?(data, <string>))
    let v4-address? = split(data, '.');
    if (v4-address?.size = 4)
      as(<ipv4-address>, data);
    else
      as(<ipv6-address>, data);
    end;
  elseif (data.size = 4)
    apply(make, <ipv4-address>, rest)
  elseif (data.size = 16)
    apply(make, <ipv6-address>, rest)
  end;
end;
define class <ipv4-address> (<ip-address>)
end;

define method address-size (ip == <ipv4-address>)
  4;
end;

define method address-size (ip :: <ipv4-address>)
  4;
end;
define method make (ip-address == <ipv4-address>,
                    #next next-method,
                    #rest rest,
                    #key data,
                    #all-keys) => (res :: <ipv4-address>)
  if (instance?(data, <string>))
    as(<ipv4-address>, data);
  else
    apply(next-method, ip-address, rest);
  end if;
end;

//print-object
define method print-object (ip :: <ip-address>,
                            stream :: <stream>)
 => ()
  format(stream, "%s", as(<string>, ip));
end;

define method get-ptr (ip :: <ipv4-address>) => (res :: <string>)
  concatenate(integer-to-string(ip[3]), "-", integer-to-string(ip[2]));
end;

//arithmetic operations: +(ip, int) +(int, ip) -(ip, int)
define method \+ (a :: <ip-address>, b :: <integer>)
 => (res :: <ip-address>)
  let rem :: <integer> = b;
  let res = make(<byte-vector>, size: address-size(a), fill: 0);
  for (ele in reverse(a),
       i from address-size(a) - 1 by -1)
    let (quotient, remainder) = truncate/(ele + rem, 256);
    res[i] := remainder;
    rem := quotient;
  end;
  res := make(a.object-class, data: res);
  res;
end;

define method \+ (a :: <integer>, b :: <ip-address>)
 => (res :: <ip-address>)
  b + a;
end;

define method \- (a :: <ip-address>, b :: <integer>)
 => (res :: <ip-address>)
  let rem :: <integer> = b;
  let res = make(<byte-vector>, size: address-size(a), fill: 0);
  for (ele in reverse(a),
       i from address-size(a) - 1 by -1)
    if (ele - rem < 0)
      res[i] := modulo(ele - rem, 256);
      rem := abs(truncate/(rem, 256));
    else
      res[i] := ele - rem;
      rem := 0;
    end;
  end;
  make(a.object-class, data: res);
end;

define method \< (a :: <ip-address>, b :: <ip-address>)
 => (res :: <boolean>)
  block(done)
    for (ele1 in a,
         ele2 in b)
      if (ele1 < ele2)
        done(#t);
      elseif (ele1 > ele2)
        done(#f);
      end;
    end for;
    #f;
  end block;
end;

define method \= (a :: <ip-address>, b :: <ip-address>)
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


// conversions (string, ip, integer)
define method as (class == <string>, ip-address :: <ipv4-address>)
 => (res :: <string>)
  if (ip-address = $bottom-v4-address)
    "no ipv4-address"
  else
    let strings = make(<list>);
    for (ele in ip-address)
      strings := add(strings, integer-to-string(ele));
    end;
    reduce1(method(x, y) concatenate(x, ".", y) end, reverse(strings));
  end;
end;

define method as (class :: subclass(<ip-address>), netmask :: <integer>)
 => (res :: <ip-address>)
  let res = make(<byte-vector>, size: address-size(class), fill: 255);
  for (i from 0 below address-size(class),
       mask from netmask by -8)
    if (mask < 0)
      res[i] := 0;
    elseif (mask < 8)
      res[i] := logand(255, ash(255, 8 - mask));
    end if
  end for;
  make(class, data: res);
end;

define method as (class == <ipv4-address>, string :: <string>)
 => (res :: <ipv4-address>)
  let numbers = split(string, '.');
  let ints = map(string-to-integer, numbers);
  let res = make(<byte-vector>, size: 4, fill: 0);
  for (i from 0 below res.size)
    res[i] := as(<byte>, ints[i]);
  end;
  make(<ipv4-address>, data: res);
end;

define constant $bottom-v4-address = make(<ipv4-address>, data: as(<byte-vector>, #(0, 0, 0, 0)));

define method string-to-netmask (string :: <string>)
 => (netmask :: <integer>)
  //"255.255.255.0"
  let vec = reverse(as(<ip-address>, string));
  //0, 255, 255, 255
  let mask = 32;
  block (not-zero)
    for (ele in vec)
      if (ele = 0)
        mask := mask - 8;
      else
        for (i from 7 to 0 by -1)
          unless (logbit?(i, ele))
            mask := mask - i - 1;
            not-zero();
          end unless;
        end for;
      end;
    end for;
  end block;
  mask;
end;

define method ip-address-to-string (ip :: <ipv4-address>, index :: <integer>) => (res :: <string>)
  concatenate(integer-to-string(ip[index]), ".");
end;


module: utils
author: Hannes Mehnert <hannes@mehnert.org>

define method exclude (list, symbol) => (sequence)
  let res = make(<stretchy-vector>);
  for (i from 0 below list.size by 2)
    if (list[i] ~= symbol)
      add!(res, list[i]);
      add!(res, list[i + 1]);
    end if;
  end for;
  res;
end method;

define method replace-arg (args, symbol, type, new-value-method) => (sequence)
  let res = make(<stretchy-vector>);
  for (i from 0 below args.size by 2)
    add!(res, args[i]);
    if (args[i] ~= symbol)
      add!(res, args[i + 1]);
    else
      if (instance?(args[i + 1], type))
        add!(res, new-value-method(args[i + 1]));
      else
        add!(res, args[i + 1])
      end;
    end;
  end;
  res;
end;

define class <wrapper-sequence> (<sequence>)
  slot data :: <sequence>, init-keyword: data:;
end;

define inline method forward-iteration-protocol
    (seq :: <wrapper-sequence>)
 => (initial-state,
     limit,
     next-state :: <function>,
     finished-state? :: <function>,
     current-key :: <function>,
     current-element :: <function>,
     current-element-setter :: <function>,
     copy-state :: <function>)
  let (data-initial-state, data-limit, data-next-state,
       data-finished-state?, data-current-key, data-current-element,
       data-current-element-setter, data-copy-state)
  = forward-iteration-protocol(seq.data);
  values(data-initial-state,
         data-limit,
         method(col, state)
             data-next-state(col.data, state)
         end,
         method(col, state, limit)
             data-finished-state?(col.data, state, limit)
         end,
         method(col, state)
             data-current-key(col.data, state)
         end,
         method(col, state)
             data-current-element(col.data, state)
         end,
         method(value, col, state)
             data-current-element-setter(value, col.data, state)
         end,
         method(col, state)
             data-copy-state(col.data, state)
         end);
end;

define method element
    (seq :: <wrapper-sequence>, key, #key default = unsupplied())
 => (res)
  element(seq.data, key, default: default);
end;

define class <mutable-wrapper-sequence> (<wrapper-sequence>, <mutable-sequence>)
end;

define method element-setter (new-value,
                              seq :: <mutable-wrapper-sequence>,
                              key) => (res)
  seq.data[key] := new-value;
end;

define method type-for-copy (seq :: <wrapper-sequence>)
 => (res :: <type>)
  //<byte-vector>
  type-for-copy(seq.data);
end;

define method get-url-from-type (type) => (string :: <string>)
  copy-sequence(type.debug-name,
                start: 1,
                end: type.debug-name.size - 1)
end;


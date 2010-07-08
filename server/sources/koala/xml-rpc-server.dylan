Module:    httpi
Synopsis:  XML-RPC server
Author:    Carl Gay
Copyright: Copyright (c) 2001-2002 Carl L. Gay.  All rights reserved.
License:   Functional Objects Library Public License Version 1.0
Warranty:  Distributed WITHOUT WARRANTY OF ANY KIND


// Usage:
//   define xml-rpc-server $xml-rpc-server ("/RPC2" on http-server)
//     "my.method.name" => my-method;
//     ...
//   end;
// or
//   let xml-rpc-server = make(<xml-rpc-server>, ...);
//   register-xml-rpc-method(xml-rpc-server, "my.method.name", my-method);
//   ...
//   add-responder(http-server, "/RPC2", xml-rpc-server);


// API
define constant $default-xml-rpc-url :: <string> = "/RPC2";

// API
define class <xml-rpc-server> (<object>)

  // API
  // This is the fault code that will be returned to the caller if
  // any error other than <xml-rpc-fault> is thrown during the execution
  // of the RPC.  For example, if there's a parse error in the XML
  // that's received.  If users want to return a fault code they
  // should use the xml-rpc-fault method.
  slot error-fault-code :: <integer> = 0,
    init-keyword: error-fault-code:;

  // Maps method names to response functions.  If namespaces are used then
  // the value may be another <string-table> containing the mapping for that
  // namespace.
  constant slot xml-rpc-methods :: <string-table>,
    init-function: curry(make, <string-table>),
    init-keyword: methods:;

  // API
  slot debugging-enabled? :: <boolean> = #f,
    init-keyword: debug:;

end class <xml-rpc-server>;

define method %add-responder
    (store :: <string-trie>, url :: <uri>, xml-rpc-server :: <xml-rpc-server>,
     #key replace?)
  %add-responder(store, url, curry(respond-to-xml-rpc-request, xml-rpc-server),
                 replace?: replace?)
end method %add-responder;

define function respond-to-xml-rpc-request
    (xml-rpc-server :: <xml-rpc-server>)
  let response :: <response> = current-response();
  let request :: <request> = current-request();
  add-header(response, "Content-Type", "text/xml");
  // All responses start with a valid XML document header.
  write(output-stream(response),
        "<?xml version=\"1.0\" encoding=\"iso-8859-1\" ?>");
  block ()
    let xml = request-content(request);
    when (debugging-enabled?(xml-rpc-server))
      log-debug("Received XML-RPC call:\n   %s", xml);
    end;
    let doc = xml$parse-document(xml);
    let (method-name, args) = parse-xml-rpc-call(doc);
    when (debugging-enabled?(xml-rpc-server))
      log-debug("method-name = %=, args = %=", method-name, args);
    end;
    let fun = lookup-xml-rpc-method(xml-rpc-server, method-name)
      | xml-rpc-fault(error-fault-code(xml-rpc-server),
                      "Method not found: %=",
                      method-name);
    send-xml-rpc-result(xml-rpc-server, response, apply(fun, args));
  exception (err :: <xml-rpc-fault>)
    send-xml-rpc-fault-response(response, err);
  exception (err :: <error>)
    let error = make(<xml-rpc-fault>,
                     fault-code: error-fault-code(xml-rpc-server),
                     format-string: condition-format-string(err),
                     format-arguments: condition-format-arguments(err));
    send-xml-rpc-fault-response(response, error);
  end;
end function respond-to-xml-rpc-request;

define method lookup-xml-rpc-method
    (xml-rpc-server :: <xml-rpc-server>, method-name :: <string>)
 => (f :: false-or(<function>))
  let path = split(method-name, '.');
  let table = xml-rpc-methods(xml-rpc-server);
  let the-method = #f;
  for (name in path,
       i from path.size to 1 by -1,
       while: table)
    let thing = element(table, name, default: #f);
    select (thing by instance?)
      <function> =>
        if (i == 1)
          the-method := thing;
        else
          table := #f;   // exit loop
        end;
      <table> =>
        table := thing;
    end select;
  end for;
  the-method
end method lookup-xml-rpc-method;

// API
define method register-xml-rpc-method
    (xml-rpc-server :: <xml-rpc-server>, method-name :: <string>, fn :: <function>)
  let path = split(method-name, '.');
  let table = xml-rpc-methods(xml-rpc-server);
  for (name in path,
       i from path.size to 1 by -1)
    let thing = element(table, name, default: #f);
    select (thing by instance?)
      <function> =>
        signal(make(<xml-rpc-error>,
                    format-string: "Cannot store method %s because it conflicts with "
                      "an existing method for this XML RPC server",
                    format-arguments: list(method-name)));
      <table> =>
        if (i == 1)
          signal(make(<xml-rpc-error>,
                      format-string: "Cannot store method %s which conflicts with a "
                        "a namespace by the same name for XML RPC server",
                      format-arguments: list(method-name)));
        else
          table := thing;
        end;
      singleton(#f) =>
        if (i == 1)
          table[name] := fn;
        else
          table[name] := make(<string-table>);
          table := table[name];
        end;
    end select;
  end for;
end method register-xml-rpc-method;

define method send-xml-rpc-fault-response
    (response :: <response>, fault :: <xml-rpc-fault>)
  let stream = output-stream(response);
  let value = make(<table>);
  value["faultCode"] := fault-code(fault);
  value["faultString"] := condition-to-string(fault);
  write(stream, "<methodResponse><fault><value>");
  to-xml(value, stream);
  write(stream, "</value></fault></methodResponse>\r\n");
end method send-xml-rpc-fault-response;

define method send-xml-rpc-result
    (xml-rpc-server :: <xml-rpc-server>, response :: <response>, result :: <object>)
  let stream = output-stream(response);
  write(stream, "<methodResponse><params><param><value>");
  let xml = with-output-to-string(s)
              to-xml(result, s);
            end;
  if (debugging-enabled?(xml-rpc-server))
    log-debug("Sending XML: %=", xml);
  end;
  write(stream, xml);
  write(stream, "</value></param></params></methodResponse>\r\n");
end method send-xml-rpc-result;

define method parse-xml-rpc-call
    (node :: xml$<document>)
 => (method-name :: <string>, args :: <sequence>)
  let method-call = find-child(node, #"methodcall")
    | xml-rpc-parse-error("Bad method call, no <methodCall> node found");
  let name-node = find-child(method-call, #"methodname")
    | xml-rpc-parse-error("Bad method call, no <methodName> node found");
  let method-name = xml$text(name-node)
    | xml-rpc-parse-error("Bad method call, invalid methodName");
  let params-node = find-child(method-call, #"params")
    | xml-rpc-parse-error("Bad method call, no <params> node found");
  let args = map-as(<vector>,
                    method (param-node)
                      let value-node = find-child(param-node, #"value");
                      from-xml(value-node, xml$name(value-node))
                    end,
                    xml$node-children(params-node));
  values(method-name, args)
end method parse-xml-rpc-call;

define macro xml-rpc-server-definer
  { define xml-rpc-server ?:name (?url:expression on ?store:expression)
        (?initargs:*)
      ?the-methods:*
    end }
    => { define xml-rpc-server ?name () (?initargs) ?the-methods end;
         let _xml-rpc-server = ?name;
         add-responder(?store, ?url, ?name); }

  { define xml-rpc-server ?:name ()
        (?initargs:*)
      ?functions
    end }
    => { define constant ?name = make(<xml-rpc-server>, ?initargs);
         let _xml-rpc-server = ?name;   // ref'd in ?functions too
         ?functions }

  functions:
    { } => { }
    { ?function; ... } => { ?function; ... }

  function:
    { ?function-name:expression => ?fun:expression }
    => { register-xml-rpc-method(_xml-rpc-server, ?function-name, ?fun) }

end macro xml-rpc-server-definer;

/* Example usage
define xml-rpc-server server ("/RPC2" on foo)
    (error-fault-code: 1)
  "echo" => method (#rest args) args end;
  "ping" => method () "ack" end;
end xml-rpc-server;
*/


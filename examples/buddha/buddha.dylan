module: buddha
author: Hannes Mehnert <hannes@mehnert.org>

define thread variable *user* = #f;

define constant $privileges = #(#"root", #"noc", #"helpdesk", #"viewer");

define constant $bottom-v6-subnet = make(<bottom-v6-subnet>, cidr: as(<cidr>, "ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff/128"));

define variable *nameserver* = list(make(<nameserver>,
                                         ns-name: "auth-int.congress.ccc.de"),
                                    make(<nameserver>,
                                         ns-name: "auth-ext.congress.ccc.de"));

define method initial-responder (request :: <request>, response :: <response>)
  with-storage (privs = <access-level>)
    unless (privs.size > 0)
      do(curry(add!, privs), $privileges);
    end;
  end;
  block(return)
    if (subsequence-position(as(<string>, request.request-method), "post"))
      respond-to-post(#"edit", request, response);
      return();
    end;
    let stream = output-stream(response);
    let page = with-xml-builder()
html(xmlns => "http://www.w3.org/1999/xhtml") {
  head {
    title("Buddha - Please create initial user!"),
    link(rel => "stylesheet", href => "/buddha.css")
  },
  body {
        h1("Welcome to buddha, please create an initial admin-user!"),
        div(id => "content") { 
          do(add-form(<user>, "Users", storage(<user>), refer: "network")),
          b("Please choose root as access level to be able to add new users!")
        }
  }
}
end;
    format(stream, "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Strict//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd\">\n");
    format(stream, "%=", page);
  end;
end;


define macro page-definer
  { define page ?:name end }
    => { define responder ?name ## "-responder" ("/" ## ?"name")
           (request, response)
           if (storage(<user>).size = 0)
             initial-responder(request, response);
           else
             let good? = #f;
             block(return)
               let auth = header-value(#"authorization");
               unless (auth)
                 return();
               end;
               unless (valid-user?(auth.head, auth.tail))
                 return();
               end;
               dynamic-bind(*user* = storage(<user>)[auth.head])
                 set-current-user(*user*);
                 good? := #t;
                 if (request.request-method = #"get")
                   respond-to-get(?#"name", request, response)
                 elseif (request.request-method = #"post")
                   respond-to-post(?#"name", request, response)
                 end;
               end;
             end;
             unless (good?)
               let headers = response.response-headers;
               add-header(headers, "WWW-Authenticate",
                          "Basic realm=\"buddha requires authentication!\"");
               unauthorized-error(headers: headers);
             end;
           end;
         end; }
end;

define page network end;
define page network-detail end;
define page subnet end;
define page subnet-detail end;
define page vlan end;
define page vlan-detail end;
define page host end;
define page host-detail end;
define page zone end;
define page zone-detail end;
define page user end;
define page edit end;
define page changes end;
define page adduser end;
define page add end;
define page admin end;

define page online-users end;
define page ipv4-network-detail end;
define page ipv6-network-detail end;
define page ipv4-subnet-detail end;
define page ipv6-subnet-detail end;

define method respond-to-get (page == #"ipv4-network-detail", request :: <request>, response :: <response>, #key errors)
   respond-to-get(#"network-detail", request, response, errors: errors);
end;
define method respond-to-get (page == #"ipv6-network-detail", request :: <request>, response :: <response>, #key errors)
   respond-to-get(#"network-detail", request, response, errors: errors);
end;
define method respond-to-get (page == #"ipv4-subnet-detail", request :: <request>, response :: <response>, #key errors)
   respond-to-get(#"subnet-detail", request, response, errors: errors);
end;
define method respond-to-get (page == #"ipv6-subnet-detail", request :: <request>, response :: <response>, #key errors)
   respond-to-get(#"subnet-detail", request, response, errors: errors);
end;
define responder dhcp-responder ("/dhcp")
    (request, response)
  respond-to-get(#"dhcp", request, response);
end;

define responder tinydns-responder ("/tinydns")
    (request, response)
  respond-to-get(#"tinydns", request, response);
end;

define page export end;

define responder root ("/")
    (request, response)
  moved-permanently-redirect(location: "/vlan",
                             header-name: "Location",
                             header-value: "/vlan");
end;

define macro with-buddha-template
  { with-buddha-template(?stream:variable, ?title:expression)
      ?body:*
    end }
    => { begin
           let page = with-xml-builder()
html(xmlns => "http://www.w3.org/1999/xhtml") {
  head {
    title(concatenate("Buddha - ", ?title)),
    link(rel => "stylesheet", href => "/buddha.css")
  },
  body {
    div(id => "buddha-menu") {
      div(id => "buddha-title") { h1 { span(concatenate("Buddha - ", ?title)) } },
      div(id => "buddha-view") {
        ul {
          li { a("Vlans", href => "/vlan") },
          li { a("Zones", href => "/zone") },
          li { a("Hosts", href => "/host") },
          li { a("Networks", href => "/network") },
          li { a("Subnets", href => "/subnet") },
          li { a("Changes", href => "/changes") },
          li { a("Online Users", href => "/online-users") }
        }
      },
      div (id => "buddha-edit") {
      do(if (*user*.access-level = #"root" | *user*.access-level = #"noc")
           with-xml()
        ul {
          li("Add:"),
          li { a("vlan", href => concatenate("/add?object-type=",
                                             get-reference(<vlan>),
                                             "&parent-object=",
                                             get-reference(storage(<vlan>)))) },
          li { a("zone", href => concatenate("/add?object-type=",
                                             get-reference(<zone>),
                                             "&parent-object=",
                                              get-reference(storage(<zone>)))) },
          li { a("host", href => concatenate("/add?object-type=",
                                             get-reference(<host>),
                                             "&parent-object=",
                                             get-reference(storage(<host>)))) },
          li { a("network", href => concatenate("/add?object-type=",
                                                get-reference(<network>),
                                                "&parent-object=",
                                                get-reference(storage(<network>)))) },
          li { a("subnet", href => concatenate("/add?object-type=",
                                               get-reference(<subnet>),
                                               "&parent-object=",
                                               get-reference(storage(<subnet>)))) }
        }
           end;
         elseif (*user*.access-level = #"helpdesk")
           with-xml()
        ul {
          li("Add:"),
          li { a("host", href => concatenate("/add?object-type=",
                                             get-reference(<host>),
                                             "&parent-object=",
                                             get-reference(storage(<host>)))) }
        }
           end;
         end if),
        ul { li{ text("Logged in as "),
                 strong(*user*.username) } }
      }
    },
    do(?body)
  }
}
end;
           format(?stream, "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Strict//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd\">\n");
           format(?stream, "%=", page);
         end; }
end;

define method respond-to-get (page == #"online-users",
                              request :: <request>,
                              response :: <response>,
                              #key errors)
  let out = output-stream(response);
  with-buddha-template(out, "Online Users")
    collect(with-xml()
              div(id => "content") {
                h2("Online Jabber users"),
                ul { do(map(method(x) with-xml() li(x) end end,
                            *xmpp-bot*.online-users)) } }
              end);
  end;
end;
define method respond-to-get (page == #"admin",
                              request :: <request>,
                              response :: <response>,
                              #key errors = make(<stretchy-vector>))
  let out = output-stream(response);
  if (*user*.access-level = #"root")
  with-buddha-template(out, "Admin")
    collect(show-errors(errors));
    collect(with-xml()
              div(id => "content")
              { h2("Welcome to the admin interface"),
                ul {
                  li(concatenate("There were ", show(size(storage(<change>))), " changes")),
                  li(concatenate("There are ", show(size(storage(<user>))), " users")),
                  li{ a("User stats", href => "/koala/user-agents") }
                },
                ul {
                  li { a("User management", href => "/adduser") }
                }
              }
            end);
    end;
  else
    errors := add!(errors, make(<web-error>, error: "Permission denied"));
    respond-to-get (#"network", request, response, errors: errors);
  end;
end;

define method respond-to-get (page == #"adduser",
                              request :: <request>,
                              response :: <response>,
                              #key errors = #())
  if (*user* & *user*.access-level = #"root")
    let out = output-stream(response);
    with-buddha-template(out, "User management")
      collect(show-errors(errors));
      collect(with-xml()
                div(id => "content")
                  {
                   do(browse-table(<user>, storage(<user>))),
                   do(add-form(<user>, "Users", storage(<user>), fill-from-request: errors, refer: "adduser"))
                     }
              end)
    end;
  else
    errors := add!(errors, make(<web-error>, error: "Permission denied"));
    respond-to-get (#"network", request, response, errors: errors);
  end;
end;

                    
define method respond-to-get (page == #"add",
                              request :: <request>,
                              response :: <response>,
                              #key errors = #())
  let al = *user*.access-level;
  if (al = #"root" | al = #"noc" | al = #"helpdesk")
    let real-type = get-object(get-query-value("object-type"));
    let parent-object = get-object(get-query-value("parent-object"));
    let out = output-stream(response);
    with-buddha-template(out, concatenate("Add ", get-url-from-type(real-type)))
      collect(show-errors(errors));
      collect(with-xml()
              div(id => "content")
              {
                h1(concatenate("Add ", get-url-from-type(real-type))),
                do(add-form(real-type,
                            #f,
                            parent-object,
                            xml: if (real-type = <subnet>)
                                   with-xml()   
                                     div { text("enable dhcp"),   
                                           input(type => "checkbox",   
                                                 name => "dhcp?",   
                                                 value => "dhcp?",
                                                 checked => "checked")   
                                        }   
                                  end  
                                else   
                                  #f   
                                end, 
                            fill-from-request: errors))
              }
            end);
    end;
  end;
end;

define method respond-to-get (page == #"changes",
                              request :: <request>,
                              response :: <response>,
                              #key errors = #())
  let out = output-stream(response);
  let action = get-query-value("do");
  let errors = errors;
  if (action)
    block(return)
      let change = get-object(get-query-value("change"));
      if (action = "undo")
        undo(change)
      elseif (action = "redo")
        redo(change)
      end
    exception (e :: <web-error>)
      errors := add!(errors, e);
      return();
    end;
  end;
  let count = get-query-value("count");
  if (count & (count ~= ""))
    if (count = "all")
      count := size(storage(<change>))
    else
      count := integer-to-string(count)
    end
  else
    count := 30;
  end;
  with-buddha-template(out, concatenate("Recent Changes - Last ", integer-to-string(count), " Changes"))
    collect(show-errors(errors));
    collect(with-xml()
              div(id => "content") {
                a(concatenate("View all ", integer-to-string(size(storage(<change>))), " changes"),
                  href => "/changes?count=all"),
                ul {
                  do(for (change in reverse(storage(<change>)),
                          i from 0 to count)
                       block(ret)
                         collect(with-xml()
                                   li {
                                       do(print-xml(change)),
                                       text(" "),
                                       a("Undo",
                                         href => concatenate("/changes?do=undo&change=",
                                                             get-reference(change))) /* ,
                                       text(" "),
                                       a("Redo",
                                         href => concatenate("/changes?do=redo&change=",
                                                             get-reference(change))) */
                                       }
                                 end)
                       exception (e :: <error>)
                         collect(with-xml()
                                   li("error parsing change, sorry")
                                 end);
                         ret()
                       end
                     end)
                  }
                }
            end);
  end;
end;

define constant $colors = #("color1", "color2");
define constant color-table = make(<string-table>);

define method reset-color (object :: <object>)
  color-table[get-reference(object)] := 0;
end;

define method next-color (object :: <object>)
 => (color :: <string>)
  let ref = get-reference(object);
  let result = element(color-table, ref, default: 0);
  color-table[ref] := modulo(result + 1, $colors.size);
  $colors[result];
end;

define method show-errors (errors)
  with-xml()
    div(id => "error")
    {
      do(if (errors & (errors.size > 0))
           with-xml()
             ul
             {
               do(for(error in errors)
                    collect(with-xml()
                              li(error.error-string,
                                 class => if(instance?(error, <web-form-warning>))
                                            "green"
                                          else
                                            "red"
                                          end)
                            end);
                  end)
             }
           end;
         end)
    }
  end;
end;

define method respond-to-get
    (page == #"dhcp",
     request :: <request>,
     response :: <response>,
     #key errors)
  let network = get-object(get-query-value("network"));
  unless (network)
    network := storage(<network>);
  end;
  set-content-type(response, "text/plain");
  print-isc-dhcpd-file(network, output-stream(response));
end;

define method respond-to-get
    (page == #"tinydns",
     request :: <request>,
     response :: <response>,
     #key errors)
  let zone = get-object(get-query-value("zone"));
  unless (zone)
    zone := storage(<zone>);
  end;
  set-content-type(response, "text/plain");
  print-tinydns-zone-file(zone, output-stream(response));
end;

define method respond-to-get
   (page == #"export",
    request :: <request>,
    response :: <response>,
    #key errors)
  set-content-type(response, "text/plain");
  do(curry(print-export-summary, output-stream(response)), sort(storage(<vlan>)));
end;

define method respond-to-post
    (page,
     request :: <request>,
     response :: <response>)
  respond-to-get(page, request, response);
end;

define method respond-to-get
    (page == #"network",
     request :: <request>,
     response :: <response>,
     #key errors)
  let out = output-stream(response);
  reset-color(storage(<network>));
  with-buddha-template (out, "Networks")
    collect(show-errors(errors));
    collect(with-xml ()
              div(id => "content")
              {
                table {
                  tr { th("CIDR"), th("dhcp?"), th("VLAN"), th },
                  do(let res = make(<stretchy-vector>);
                     do(method(x)
                            res := add!(res, with-xml()
                                               tr(class => next-color(storage(<network>)))
                                                 { td { a(show(x.cidr),
                                                           href => concatenate("/network-detail?network=",
                                                                               get-reference(x))) },
                                                   do(collect-dhcp-into-table(x))
                                                 }
                                             end);
                            reset-color(storage(<subnet>));
                            res := concatenate(res,
                                               map(method(y)
                                                       with-xml()
                                                         tr(class => concatenate("foo-", next-color(storage(<subnet>)))) { 
                                                           td { a(show(y.cidr),
                                                                  href => concatenate("/subnet-detail?subnet=",
                                                                                      get-reference(y))) },
                                                           do(if(instance?(y, <ipv4-subnet>))
                                                                 with-xml() td(show(y.dhcp?)) end;
                                                               else
                                                                 with-xml() td end;
                                                               end),
                                                           td { a(show(y.vlan.number),
                                                                  href => concatenate("/vlan-detail?vlan=",
                                                                                      get-reference(y.vlan))) },
                                                             td }
                                                       end;
                                                   end,
                                                   choose(method(z)
                                                              z.network = x
                                                          end, storage(<subnet>))));
                        end, storage(<network>));
                     res)
                }
              }
            end);
  end;
end;

define method respond-to-get
    (page == #"network-detail",
     request :: <request>,
     response :: <response>,
     #key errors)
  let net = get-query-value("network");
  unless (net)
    net := get-query-value("ipv4-network");
  end;
  unless (net)
    net := get-query-value("ipv6-network");
  end;
  let dnetwork = get-object(net);
  let out = output-stream(response);
  with-buddha-template(out, concatenate("Network ", show(dnetwork), " detail"))
    collect(show-errors(errors));
    collect(with-xml()
              div(id => "content")
              {
                h1(concatenate("Network ", show(dnetwork))),
                do(edit-form(dnetwork,
                             refer: "network-detail",
                             xml: with-xml()
                                    input(type => "hidden",
                                          name => "network",
                                          value => get-reference(dnetwork))
                                  end)),
                do(remove-form(dnetwork, storage(<network>), url: "network")),
                do(dhcp-stuff(dnetwork)),
                //add subnet with filled-in network?!
                h2(concatenate("Subnets in network ", show(dnetwork))),
                table { tr { th("CIDR"), th("dhcp?") },
                        do(reset-color(storage(<subnet>));
                           map(method(x) with-xml()
                                           tr(class => next-color(storage(<subnet>)))
                                              { td {a(show(x),
                                                      href => concatenate("/subnet-detail?subnet=",
                                                                          get-reference(x))) },
                                                td(if (instance?(x, <ipv4-subnet>)) show(x.dhcp?) else "" end) }
                                         end
                               end, choose(method(y) y.network = dnetwork end, storage(<subnet>)))) }
              }
            end);
  end;
end;


define method respond-to-get
    (page == #"subnet",
     request :: <request>,
     response :: <response>,
     #key errors)
  let out = output-stream(response);
  with-buddha-template(out, "Subnets")
    collect(show-errors(errors));
    collect(with-xml()
              div(id => "content")
              {
                table {
                  tr { th("CIDR"), th("dhcp?"), th("VLAN") },
                  do(reset-color(storage(<subnet>));
                     map(method(x) with-xml()
                                     tr(class => next-color(storage(<subnet>)))
                                       { td { a(show(x.cidr),
                                                href => concatenate("/subnet-detail?subnet=",
                                                                    get-reference(x))) },
                                         do(collect-dhcp-into-table(x)),
                                         td { a(show(x.vlan),
                                                href => concatenate("/vlan-detail?vlan=",
                                                                    get-reference(x.vlan))) }
                                       }
                                   end
                         end, storage(<subnet>)))
                }
              }
            end);
  end;
end;

define method respond-to-get
    (page == #"subnet-detail",
     request :: <request>,
     response :: <response>,
     #key errors)
  let sub = get-query-value("subnet");
  unless (sub)
    sub := get-query-value("ipv4-subnet");
  end;
  unless (sub)
    sub := get-query-value("ipv6-subnet");
  end;
  let dsubnet = get-object(sub);
  let out = output-stream(response);
  if (instance?(dsubnet, <bottom-v6-subnet>))
    with-buddha-template(out, "No IPv6 for you")
      collect(with-xml()
                div(id => "content")
                { h1("This page was intentionally left blank...")}
              end);
    end;
  else
  with-buddha-template(out, concatenate("Subnet ", show(dsubnet), " detail"))
    collect(show-errors(errors));
    collect(with-xml()
              div(id => "content")
              {
                h1(concatenate("Subnet ", show(dsubnet))),
                do(edit-form(dsubnet,
                             refer: "subnet-detail",
                             xml: with-xml()
                                    input(type => "hidden",
                                          name => "subnet",
                                          value => get-reference(dsubnet))
                                  end)),
                do(remove-form(dsubnet, storage(<subnet>), url: "subnet")),
                ul { li { text("VLAN "), a(show(dsubnet.vlan),
                                          href => concatenate("/vlan-detail?vlan=",
                                                              get-reference(dsubnet.vlan))) },
                     li { text("Network "), a(show(dsubnet.network),
                                              href => concatenate("/network-detail?network=",
                                                                  get-reference(dsubnet.network))) }
                },
                do(dhcp-stuff(dsubnet)),
                h2(concatenate("Hosts in subnet ", show(dsubnet))),
                table { tr { th("Hostname"), th("IP"), th("Mac")},
                        do(reset-color(storage(<host>));
                           let (ref-slot, ip) = if (instance?(dsubnet, <ipv4-subnet>))
                                                  values(ipv4-subnet, ipv4-address);
                                                elseif (instance?(dsubnet, <ipv6-subnet>))
                                                  values(ipv6-subnet, ipv6-address);
                                                end;
                           map(method(x) with-xml()
                                           tr(class => next-color(storage(<host>)))
                                             { td {a(x.host-name,
                                                      href => concatenate("/host-detail?host=",
                                                                          get-reference(x))) },
                                                td(show(x.ip)),
                                                td(show(x.mac-address)) }
                                         end
                               end, choose(method(y) y.ref-slot = dsubnet end, storage(<host>)))) }
                //add host with predefined subnet (cause we have the context)?
              }
            end);
  end;
  end;
end;

define method insert-br (list :: <collection>) => (res :: <collection>)
  let res = make(<list>);
  do(method(x)
         res := add!(res, x);
         res := add!(res, with-xml() br end);
     end, list);
  //remove last br
  reverse!(tail(res));
end;

define method respond-to-get
    (page == #"vlan",
     request :: <request>,
     response :: <response>,
     #key errors)
  let out = output-stream(response);
  with-buddha-template(out, "Vlans")
    collect(show-errors(errors));
    collect(with-xml()
              div(id => "content")
              {
                table
                {
                  tr { th("ID"), th("Name"), th("Subnets"), th("Description") },
                  do(reset-color(storage(<vlan>));
                     map(method(x) with-xml()
                                     tr(class => next-color(storage(<vlan>)))
                                       { td { a(show(x.number),
                                               href => concatenate("/vlan-detail?vlan=",
                                                                   get-reference(x))) },
                                          td(show(x.name)),
                                          td { do(insert-br(map(method(y)
                                                                    with-xml()
                                                                      a(show(y.cidr),
                                                                        href => concatenate("/subnet-detail?subnet=",
                                                                                            get-reference(y)))
                                                                    end
                                                                end, choose(method(z) z.vlan = x end,
                                                                            storage(<subnet>)))))
                                             },
                                          td(show(x.description)) }
                                   end
                         end, storage(<vlan>)))
                }
              }
            end);
  end;
end;

define method respond-to-get
    (page == #"vlan-detail",
     request :: <request>,
     response :: <response>,
     #key errors)
  let dvlan = get-object(get-query-value("vlan"));
  let out = output-stream(response);
  with-buddha-template(out, concatenate("VLAN ", show(dvlan.number), " detail"))
    collect(show-errors(errors));
    collect(with-xml()
              div(id => "content")
              {
                h1(concatenate("VLAN ", show(dvlan.number), ", Name ", dvlan.name)),
                do(edit-form(dvlan,
                             refer: "vlan-detail",
                             xml: with-xml()
                                    input(type => "hidden",
                                          name => "vlan",
                                          value => get-reference(dvlan))
                                  end)),
                do(remove-form(dvlan, storage(<vlan>), url: "vlan")),
                h2(concatenate("Subnets in VLAN ", show(dvlan.number))),
                table {
                  tr { th("CIDR"), th("dhcp?") },
                  do(reset-color(storage(<subnet>));
                     map(method(x) with-xml()
                                     tr (class => next-color(storage(<subnet>)))
                                       { td { a(show(x.cidr),
                                                 href => concatenate("/subnet-detail?subnet=",
                                                                     get-reference(x))) },
                                         do(collect-dhcp-into-table(x)) }
                                   end
                         end, choose(method(x) x.vlan = dvlan end, storage(<subnet>))))
                }
                //add subnet with pre-filled vlan?
              }
            end);
  end;
end;

define method respond-to-get
    (page == #"host",
     request :: <request>,
     response :: <response>,
     #key errors)
  let out = output-stream(response);
  with-buddha-template(out, "Hosts")
    collect(show-errors(errors));
    collect(with-xml()
              div(id => "content")
              {
                table
                {
                  tr { th("Hostname"), th("IPv4-Address"), th("IPv4-Subnet"), th("IPv6-Address"), th("IPv6-Subnet"), th("Zone") },
                  do(reset-color(storage(<host>));
                     map(method(x) with-xml()
                                     tr(class => next-color(storage(<host>)))
                                       { td { a(x.host-name,
                                                 href => concatenate("/host-detail?host=",
                                                                     get-reference(x))) },
                                          td (show(x.ipv4-address)),
                                          td { a(show(x.ipv4-subnet),
                                                 href => concatenate("/subnet-detail?subnet=",
                                                                     get-reference(x.ipv4-subnet))) },
                                          td (if (instance?(x.ipv6-subnet, <bottom-v6-subnet>)) "" else show(x.ipv6-address) end),
                                          td { a(show(x.ipv6-subnet),
                                                 href => concatenate("/subnet-detail?subnet=",
                                                                     get-reference(x.ipv6-subnet))) },
                                          td { a(show(x.zone),
                                                 href => concatenate("/zone-detail?zone=",
                                                                     get-reference(x.zone))) }
                                     }
                                   end
                         end, storage(<host>)))
                }
              }
            end);
  end;
end;

define method respond-to-get
    (page == #"host-detail",
     request :: <request>,
     response :: <response>,
     #key errors)
  let host = get-object(get-query-value("host"));
  let out = output-stream(response);
  with-buddha-template(out, concatenate("Host ", host.host-name, " detail"))
    collect(show-errors(errors));
    collect(with-xml()
              div(id => "content")
              {
                h1(concatenate("Host ", host.host-name, " ", show(host.ipv4-address))),
                do(edit-form(host,
                             refer: "host-detail",
                             xml: with-xml()
                                    input(type => "hidden",
                                          name => "host",
                                          value => get-reference(host))
                                  end)),
                do(remove-form(host, storage(<host>), url: "host")),
                ul { li { text("IPv4 Subnet "), a(show(host.ipv4-subnet),
                                                  href => concatenate("/subnet-detail?subnet=",
                                                                      get-reference(host.ipv4-subnet))) },
                     li { text("IPv6 Subnet "), a(show(host.ipv6-subnet),
                                                  href => concatenate("/subnet-detail?subnet=",
                                                                      get-reference(host.ipv6-subnet))) },
                     li { text("Zone "), a(show(host.zone),
                                           href => concatenate("/zone-detail?zone=",
                                                               get-reference(host.zone))) }
                },
/*                h2("Add CNAME entry"),
                do(add-form(<cname>, #f, host.zone.cnames,
                            fill-from-request: list(concatenate("source=", host.host-name)),
                            refer: "host-detail",
                            xml: with-xml()
                                   input(type => "hidden",
                                         name => "host",
                                         value => get-reference(host))
                                 end)) */
              }
            end);
  end;
end;

define method respond-to-get
    (page == #"zone",
     request :: <request>,
     response :: <response>,
     #key errors)
  let out = output-stream(response);
  with-buddha-template(out, "Zones")
    collect(show-errors(errors));
    collect(with-xml()
              div(id => "content")
              {
                a("generate complete tinydns.conf", href => "/tinydns"),
                table
                {
                  tr { th("Zone name"), th },
                  do(reset-color(storage(<zone>));
                     map(method(x) with-xml()
                                     tr(class => next-color(storage(<zone>)))
                                       { td { a(x.zone-name,
                                           href => concatenate("/zone-detail?zone=",
                                                               get-reference(x))) },
                                          td { a("tinydns",
                                                 href => concatenate("/tinydns?zone=",
                                                                     get-reference(x))) }
                                      }
                                   end
                         end, storage(<zone>)))
                }
              }
            end);
  end;
end;

define method respond-to-get
    (page == #"zone-detail",
     request :: <request>,
     response :: <response>,
     #key errors)
  let dzone = get-object(get-query-value("zone"));
  let out = output-stream(response);
  with-buddha-template(out, concatenate("Zone ", dzone.zone-name, " detail"))
    collect(show-errors(errors));
    collect(with-xml()
              div(id => "content")
              {
                h1(concatenate("Zone ", dzone.zone-name)),
                do(edit-form(dzone,
                             refer: "zone-detail",
                             xml: with-xml()
                                    input(type => "hidden",
                                          name => "zone",
                                          value => get-reference(dzone))
                                  end)),
                do(remove-form(dzone, storage(<zone>), url: "zone")),
                //edit|remove ns, mx, cname, forms, add host form?!
                h2("Nameserver entries"),
                do(if (dzone.nameservers.size > 0)
                     with-xml()
                       ul { do(map(method(x) with-xml()
                                               li { text(x.ns-name),
                                                    do(remove-form(x, dzone.nameservers,
                                                                   url: "zone-detail",
                                                                   xml: with-xml()
                                                                          input(type => "hidden",
                                                                                name => "zone",
                                                                                value => get-reference(dzone))
                                                                        end)) }
                                              end
                                   end, dzone.nameservers)) }
                     end
                   end),
                do(add-form(<nameserver>, #f, dzone.nameservers,
                            refer: "zone-detail",
                            xml: with-xml()
                                   input(type => "hidden",
                                         name => "zone",
                                         value => get-reference(dzone))
                                 end)),
                do(unless(dzone.reverse?)
                     with-xml() div {
                h2("Mail exchange entries"),
                do(if (dzone.mail-exchanges.size > 0)
                     with-xml()
                       table { tr { th("Name"), th("Priority"), th("Remove") },
                              do(map(method(x) with-xml()
                                                 tr { td(x.mx-name),
                                                     td(show(x.priority)),
                                                     td { do(remove-form(x, dzone.mail-exchanges,
                                                                         url: "zone-detail",
                                                                         xml: with-xml()
                                                                           input(type => "hidden",
                                                                                 name => "zone",
                                                                                 value => get-reference(dzone))
                                                                         end)) } }
                                               end
                                     end, dzone.mail-exchanges)) }
                     end
                   end),
                do(add-form(<mail-exchange>, #f, dzone.mail-exchanges,
                            refer: "zone-detail",
                            xml: with-xml()
                                   input(type => "hidden",
                                         name => "zone",
                                         value => get-reference(dzone))
                                 end)),
                h2("Cname records"),
                do(if (dzone.cnames.size > 0)
                     with-xml()
                       table { tr { th("Source"), th("Target"), th("Remove") },
                              do(reset-color(dzone.cnames);
                                 map(method(x) with-xml()
                                                 tr(class => next-color(dzone.cnames))
                                                   { td(x.source),
                                                     td(x.target),
                                                     td { do(remove-form(x, dzone.cnames,
                                                                         url: "zone-detail",
                                                                         xml: with-xml()
                                                                           input(type => "hidden",
                                                                                 name => "zone",
                                                                                 value => get-reference(dzone))
                                                                         end)) } }
                                               end
                                     end, dzone.cnames)) }
                     end
                   end),
                do(add-form(<cname>, #f, dzone.cnames,
                            refer: "zone-detail",
                            xml: with-xml()
                                    input(type => "hidden",
                                          name => "zone",
                                          value => get-reference(dzone))
                                  end)),
                h2("A-records"),
                do(if (dzone.host-records.size > 0)
                     with-xml()
                       table { tr { th("Hostname"), th("IPv4"), th("IPv6"), th("TTL"), th("Remove") },
                              do(reset-color(dzone.host-records);
                                 map(method(x) with-xml()
                                                 tr(class => next-color(dzone.host-records))
                                                   {
                                                    td(x.host-name),
                                                    td(show(x.ipv4-address)),
                                                    td(show(x.ipv6-address)),
                                                    td(show(x.time-to-live)),
                                                    td { do(remove-form(x, dzone.host-records,
                                                                         url: "zone-detail",
                                                                         xml: with-xml()
                                                                           input(type => "hidden",
                                                                                 name => "zone",
                                                                                 value => get-reference(dzone))
                                                                         end)) } }
                                               end
                                     end, dzone.host-records)) }
                     end
                   end),
                do(add-form(<host-record>, #f, dzone.host-records,
                            refer: "zone-detail",
                            xml: with-xml()
                                    input(type => "hidden",
                                          name => "zone",
                                          value => get-reference(dzone))
                                  end)),
                h2("Hosts"),
                table { tr { th("Hostname"), th("IPv4"), th("IPv6"), th("TTL") },
                        do(reset-color(storage(<host>));
                           map(method(x) with-xml()
                                           tr(class => next-color(storage(<host>)))
                                             { td { a(x.host-name,
                                                       href => concatenate("/host-detail?host=",
                                                                           get-reference(x))) },
                                                td(show(x.ipv4-address)),
                                                td(show(x.ipv6-address)),
                                                td(show(x.time-to-live)) }
                                         end
                               end, choose(method(y) y.zone = dzone end, storage(<host>)))) } }
                     end
                   end)
              }
            end);
  end;
end;

/*
define constant $yourname-users = make(<string-table>);

define class <yourname-user> (<object>)
  slot password :: <string>, required-init-keyword: password:;
  slot host :: false-or(<host>) = #f;
end;

define method respond-to-post
    (page == #"user",
     request :: <request>,
     response :: <response>)
  let remote-ip = get-remote-address(request);
  let entered-password = get-query-value("password");
  let hostname = get-query-value("hostname");
  let entered-mac-address = get-query-value("mac-address");
  let user = element($yourname-users, remote-ip, default: #f);
  let errs = #();
  format-out("ip %= pass %= host %= mac %= user %=\n",
             remote-ip, entered-password, hostname, entered-mac-address, user);
end;
  block(ret)
    if (user)
      if (user.password = entered-password)
        if (user.host)
          let changes = #();
          if (user.host.mac-address ~= entered-mac-address)
            let triple = make(<triple>,
                              old-value: user.host.mac-address,
                              new-value: entered-mac-address,
                              slot-name: "mac-address");
            changes := add!(changes, triple);
          end;
          if (user.host.host-name ~= hostname)
            let triple = make(<triple>,
                              old-value: user.host.host-name,
                              new-value: hostname,
                              slot-name: "host-name");
            changes := add!(changes, triple);
          end;
          if (changes.size > 0)
            //we have to do something
            let command = make(<edit-command>,
                               arguments: list(user.host, changes));
            redo(command);
            let change = make(<change>,
                              command: command);
            save(change);
            let slot-names = apply(concatenate, map(method(x)
                                                        concatenate(x.slot-name, " to ",
                                                                    show(x.new-value), "  ")
                                                    end, changes));
            signal(make(<web-success>,
                        warning: concatenate("Saved Host ",
                                             show(user.host),
                                             " changed slots: ",
                                             slot-names)));
          end;
        else
          let ip = as(<ip-address>, remote-ip);
          //create new host
          let new-host = make(<host>,
                              host-name: hostname,
                              ipv4-address: ip,
                              time-to-live: 300,
                              mac-address: entered-mac-address,
                              subnet: choose(method(x)
                                                 ip-in-net?(x, ip)
                                             end, storage(<subnet>))[0],
                              zone: choose(method(x)
                                               x.zone-name = "congress.ccc.de";
                                           end, storage(<zone>))[0]);
          //add new host
          let command = make(<add-command>,
                             arguments: list(new-host, storage(<host>)));
          redo(command);
          let change = make(<change>,
                            command: command);
          save(change);
          signal(make(<web-success>,
                      warning: concatenate("Added host: ", show(new-host))));
        end;
      else
        //wrong password
        signal(make(<web-error>,
                    error: "Invalid user/password"));
      end;
      //post before get
      signal(make(<web-error>,
                  error: "POST before GET, go away"));
    end;
  exception (e :: <condition>)
    errs := add!(errs, e);
    ret()
  exception (e :: <web-error>)
    errs := add!(errs, e);
    ret()
  exception (e :: <error>)
    errs := add!(errs, e);
    ret()
  end;
  respond-to-get(page, request, response, errors: errs);
end; */

define method respond-to-get
    (page == #"user",
     request :: <request>,
     response :: <response>,
     #key errors)
  let out = output-stream(response);
  let page = with-xml-builder()
html(xmlns => "http://www.w3.org/1999/xhtml") {
  head {
    title("Buddha - Yourname service!"),
    link(rel => "stylesheet", href => "/buddha.css")
  },
  body {
    div(id => "content") {
      h1("Welcome to Buddha"),
      do(collect(show-errors(errors))),
      form(action => "/user", \method => "post")
      {
        div(class => "edit")
        {
          text("Hostname"),
          input(type => "text", name => "hostname"),
          text(".congress.ccc.de"), br,
          text(" MAC-address"),
          input(type => "text", name => "mac-address"), br,
          text("Password"),
          input(type => "password", name => "password"), br,
          input(type => "submit",
                name => "add-host-button",
                value => "Add Hostname")
        }
      }
    }
  }
}
  end;
  format(out, "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Strict//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd\">\n");
  format(out, "%=", page);
end;

define method save (change :: <change>) => ()
  next-method();
  block ()
//    let message
//      = with-xml()
//          html (xmlns => "http://jabber.org/protocol/xhtml-im") {
//            body (xmlns => "http://www.w3.org/1999/xhtml") { div {
//              do(print-xml(change, base-url: "https://buddha.zaphods.net")) } } }
//        end;
    let message = print-change(change, base-url: "https://buddha.zaphods.net");
    format-out("Sending %s\n", message);
    broadcast-message(*xmpp-bot*, message);
  exception (e :: <condition>)
    format-out("Message could not be delivered %=\n", e);
  end;
end;

define variable *xmpp-bot* = #f;

define function xmpp-worker ()
  while (#t)
    block()
      unless (*xmpp-bot*)
        *xmpp-bot* := make(<xmpp-bot>, jid: "buddha@jabber.berlin.ccc.de/serva", password: "fnord");
      end;
      ping(*xmpp-bot*);
      sleep(30);
    exception (e :: <condition>)
      *xmpp-bot* := #f
    end;
  end;
end;
define function main () => ()
  make(<thread>, function: xmpp-worker);
  register-url("/buddha.css", maybe-serve-static-file);
  block()
    http-server-main();
  exception (e :: <condition>)
    format-out("error: %=\n", e);
  end
end;

define function main2()
  let cisco = make(<cisco-ios-device>,
                   ipv4-address: "23.23.23.23",
                   login-password: "xxx",
                   enable-password: "xxx");

  let control = connect-to-cisco(cisco);
  control.run;

  send-command(control, "terminal length 0");
  let result = send-command(control, "show running");
  format-out("%s\n", result);
end;

begin
  main();
end;

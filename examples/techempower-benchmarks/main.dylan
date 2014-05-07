module: techempower-benchmarks

define function map-resources (server :: <http-server>)
  add-resource(server, "/plaintext", make(<plaintext-page>));
end function map-resources;

define function main ()
  http-server-main(server: make(<http-server>,
                                listeners: list("127.0.0.1:8000")),
                   before-startup: map-resources);
end function main;

main();

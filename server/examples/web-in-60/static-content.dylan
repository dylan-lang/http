Module: web60-static-content

define function main ()
  let server = make(<http-server>,
                    listeners: list("0.0.0.0:8888"),
		    debug: #t);
  let resource = make(<directory-resource>,
		      directory: "c:/tmp",
		      allow-directory-listing?: #t);
  add-resource(server, "/", resource);
  start-server(server);
end;

main();

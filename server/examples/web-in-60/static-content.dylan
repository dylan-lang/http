Module: web60-static-content

let server = make(<http-server>,
                  listeners: list("0.0.0.0:8888"));
let resource = make(<directory-resource>,
                    directory: "c:/tmp",
                    allow-directory-listing?: #t);
add-resource(server, "/", resource);
start-server(server);


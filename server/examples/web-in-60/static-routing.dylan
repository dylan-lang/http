Module: web60-static-routing

define constant $wiki-app = make(<resource>);

define class <page> (<resource>) end;
define class <user> (<resource>) end;
define class <group> (<resource>) end;

add-resource($wiki-app, "page/{action}/{title}/{version?}", make(<page>));
add-resource($wiki-app, "user/{action}/{name}", make(<user>));
add-resource($wiki-app, "group/{action}/{name}", make(<group>));

define method respond
    (resource :: <page>, #key action, title, version)
  set-header(current-response(), "Content-Type", "text/html");
  output("<html><body>action = %s, title = %s, version = %s</body></html>",
         action, title, version);
end;

define method respond
    (resource :: type-union(<user>, <group>), #key action, name)
  set-header(current-response(), "Content-Type", "text/html");
  output("<html><body>action = %s, name = %s</body></html>",
         action, name);
end;

define constant $server = make(<http-server>, listeners: #("0.0.0.0:8888"));
add-resource($server, "/", $wiki-app);
start-server($server);

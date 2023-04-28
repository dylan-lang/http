Module: dylan-user

define library http-server-app
  use http-server;
end;

define module http-server-app
  use http-server, import: { http-server-main };
end;

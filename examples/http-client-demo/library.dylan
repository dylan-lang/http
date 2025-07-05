Module: dylan-user
Synopsis: Module and library definition for simple executable application

define library http-client-demo
  use common-dylan;
  use http-client;
  use io, import: { format-out, standard-io };
  use network;
end library;

define module http-client-demo
  use common-dylan;
  use format-out;
  use http-client;
  use sockets;
  use standard-io;
end module;

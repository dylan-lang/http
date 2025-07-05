Module: http-client-demo

define function main
    ()
  let args = application-arguments();
  let url = "http:/" "/opendylan.org";  // https://github.com/dylan-lang/dylan-emacs-support/issues/27
  select (args.size)
    0 => #f;
    1 => url := args[0];
    otherwise =>
      format-out("Usage: %s [URL]\n", application-name());
  end;
  format-out("Doing HTTP GET on URL %s...\n\n", url);
  force-out();
  block ()
    start-sockets();
    http-get(url, stream: *standard-output*);
  cleanup
    force-out();
  end;
end function;

main();

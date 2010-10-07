module: buddha
author: Hannes Mehnert <hannes@mehnert.org>

define class <cisco-ios-device> (<host>)
  slot login-password :: <string>, init-keyword: login-password:;
  slot enable-password :: <string>, init-keyword: enable-password:;
  slot banner :: <string> = "";
end class <cisco-ios-device>;

define class <cisco-ios-telnet-control> (<object>)
  slot device :: <cisco-ios-device>, init-keyword: device:;
  slot socket, init-keyword: socket:;
  slot connection-state = #"disconnected";
end class <cisco-ios-telnet-control>;

define method connect-to-cisco(cisco :: <cisco-ios-device>)
  let address = make(<internet-address>,
                     address: as(<string>, cisco.ipv4-address));

  let socket = make(<tcp-socket>, host: address, port: 23);

  let control = make(<cisco-ios-telnet-control>,
                     device: cisco,
                     socket: socket);
  control.connection-state := #"connected";
  run(control);
  control
end method connect-to-cisco;

define method read-whats-available(stream :: <stream>, 
                                   #key timeout,
                                   end-marker)
  let result = "";

  while (stream-input-available?(stream) 
           & ~(end-marker & subsequence-position(result, end-marker)))
    let elt = read-element(stream);
    result := add!(result, elt);
  end;
  if (timeout & timeout > 0)
    unless (end-marker & subsequence-position(result, end-marker))
      sleep(1);
      result := concatenate!(result, 
                             read-whats-available(stream,
                                                  timeout: timeout - 1,
                                                  end-marker: end-marker));
    end unless;
  end;
  result;
end method read-whats-available;

define method read-to-marker(stream :: <stream>, end-marker :: <string>)
  let result = "";

  while (~subsequence-position(result, end-marker))
    let elt = read-element(stream);
    result := add!(result, elt);
  end;
  result;
end method;

define method run (control :: <cisco-ios-telnet-control>)
  while (control.connection-state ~= #"enabled")
    select (control.connection-state)
      #"connected"
        => begin
             let line = read-whats-available(control.socket, 
                                             timeout: 1,
                                             end-marker: "Password:");
             let (banner, prompt) = regex-search-strings(compile-regex("(.*)(Password:)"), line);
             if (banner)
               control.device.banner := banner;
               write-line(control.socket, 
                          control.device.login-password);
               force-output(control.socket);
               control.connection-state := #"password-sent";
             else
               error("can't parse Cisco output");
             end;
           end;
      #"password-sent"
        => begin
             let line = read-whats-available(control.socket, 
                                             timeout: 1,
                                             end-marker: ">");
             let (match, hostname) = regex-search-strings(compile-regex("(.*)>"), line);
             if (match)
               control.device.host-name := hostname;
               write-line(control.socket, "enable");
               force-output(control.socket);
               write-line(control.socket, 
                          control.device.enable-password);
               force-output(control.socket);
               control.connection-state := #"enable-password-sent";
             else
               error("login password invalid");
             end;
           end;
      #"enable-password-sent"
        => begin
             let line = read-whats-available(control.socket, 
                                             timeout: 1,
                                             end-marker: "#");
             if (regex-search(compile-regex("#"), line))
               control.connection-state := #"enabled"
             else
               error("enable password invalid")
             end
           end;
      otherwise => #t
    end select;
  end while;
end method run;

define method send-command (control :: <cisco-ios-telnet-control>,
                            command :: <string>)
  write-line(control.socket, command);
  force-output(control.socket);
  read(control.socket, command.size + 2);
  let result 
    = read-to-marker(control.socket,
                     concatenate(control.device.host-name, "#"));
  copy-sequence(result, end: result.size - control.device.host-name.size - 1);
end method send-command;



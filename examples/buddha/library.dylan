module: dylan-user
author: Hannes Mehnert <hannes@mehnert.org>

define library buddha
  use base64;
  use common-dylan;
  use io;
  use http-server, import: { http-server };
  use dsp;
  use dood;
  use strings;
  use regular-expressions;
  use network;
  use system, import: { file-system, date };
  use xml-parser;
  use dylan;
  use web-framework;
  use xmpp-bot;
  export buddha;
end;

define module utils
  use common-dylan;
  use dylan-extensions, import: { debug-name };
  use regular-expressions;
  export exclude,
    get-url-from-type,
    <wrapper-sequence>,
    <mutable-wrapper-sequence>,
    data;
end;

define module buddha
  use regular-expressions;
  use common-dylan;
  use dylan-extensions, exclude: { slot-type };
  use threads;
  use format-out;
  use format, import: { format };
  use print, import: { print-object };

  use streams;
  use standard-io;
  use strings, import: { hexadecimal-digit? };
  use date;

  use http-server, exclude: { print-object };
  use dsp, import: { set-attribute, get-attribute };
  use sockets, import: { <tcp-socket>,
                         <internet-address> };

  use dood;
  use file-system;
  use base64, import: { base64-encode, base64-decode };

  use simple-xml;
  use web-framework;
  use storage;
  use object-table;
  use users;
  use change;
  use utils;
  use xmpp-bot;
end;

module: dylan-user
author: Hannes Mehnert <hannes@mehnert.org>

define library buddha
  use common-dylan;
  use io;
  use koala, import: { koala, dsp };
  use dood;
  use strings;
  use regular-expressions;
  use network;
  use system, import: { file-system, date };
  use xml-rpc-common;
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

  use koala, exclude: { print-object };
  use dsp, import: { set-attribute, get-attribute };
  use sockets, import: { <tcp-socket>,
                         <internet-address> };

  use dood;
  use file-system;
  use xml-rpc-common, import: { base64-encode, base64-decode };

  use simple-xml;
  use web-framework;
  use storage;
  use object-table;
  use users;
  use change;
  use utils;
  use xmpp-bot;
end;

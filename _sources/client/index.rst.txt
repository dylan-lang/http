***********
HTTP Client
***********

This doc is just some simple examples for now.  See :func:`http-request`
for additional arguments such as `headers:` and `follow-redirects:`.


Fetch the content of a web page and display it on ``*standard-output*``.

.. code-block:: dylan

   let response :: <http-response> = http-get("http://opendylan.org");
   write(*standard-output*, response.response-content);


Fetch a big file and copy it to a local file.

.. code-block:: dylan

   with-open-file(out = "/tmp/big", direction: #"output")
     http-get("http://host/big-file", stream: out)
   end;


Post to a URL. Table data is automatically application/x-www-form-urlencoded.

.. code-block:: dylan

   http-post("http://some/url",
             content: table(<string-table>,
                            "full_name" => "Dylan Thomas",
                            "login" => "dthomas"))


Send multiple requests on a single connection via the lower-level API.

.. code-block:: dylan

   with-http-connection (conn = "opendylan.org")
     send-request(conn, "GET", "/")
     let response :: <http-response> = read-response(conn);
     ...content is in response.response-content...

     send-request(conn, "POST", "/blah", content: "...");
     let response :: <http-response> = read-response(conn);
     ...
   end;


Send streaming data.

.. code-block:: dylan

   start-request(conn,  "PUT", "/huge-file.gz");
   ...write(conn, "foo")...
   finish-request(conn);
   let response = read-response(conn);


How to handle errors.

.. code-block:: dylan

   block ()
     http-get(...)
   exception (ex :: <resource-not-found-error>)
     ...
   exception (ex :: <http-error>)
     ...last resort handler...
   end;


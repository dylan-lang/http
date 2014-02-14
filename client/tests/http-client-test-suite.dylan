Module: http-client-test-suite
Author: Francesco Ceccon
Copyright: See LICENSE in this distribution for details.

define test test-convert-headers-method ()
  let headers = convert-headers(#f);
  check-instance?("#f is an empty <header-table>", <header-table>, headers);

  headers := convert-headers(#(#("k1", "v1"), #("k2", "v2")));
  check-instance?("<header-table> from a <sequence>", <header-table>, headers);

  let h = table(<string-table>, "k1" => "v1", "k2" => "v2");
  headers := convert-headers(h);
  check-instance?("<header-table> from a <table>", <header-table>, headers);
end test test-convert-headers-method;

define suite request-test-suite ()
  test test-convert-headers-method;
end suite request-test-suite;


define test test-prepare-request-method-method ()
  let base-request = make(<base-http-request>);
  let request = make(<http-request>, method: #"get");

  prepare-request-method(base-request, request);

  check-equal("Just copy the request method",
              base-request.request-method,
              request.request-method);
end test test-prepare-request-method-method;

define test test-prepare-request-url-method ()
  let base-request = make(<base-http-request>);
  let parameters = table(<string-table>,
                         "key1" => "value1", "key2" => "value2");
  let request = make(<http-request>,
                     url: "http://httpbin.org/get",
                     method: #"get",
                     parameters: parameters);

  prepare-request-url(base-request, request);

  check-equal("Append the query params to the url",
              build-uri(base-request.request-url),
              "http://httpbin.org/get?key2=value2&key1=value1");
end test test-prepare-request-url-method;

define test test-prepare-request-headers-method ()
  let base-request = make(<base-http-request>);
  let headers = table(<header-table>,
                      "header1" => "value1", "header2" => "value2");
  let request = make(<http-request>,
                     url: "http://httpbin.org/get",
                     method: #"get",
                     headers: headers);

  prepare-request-headers(base-request, request);

  check-equal("Copy the request headers",
              size(request-headers(base-request)),
              2);
  check-equal("Act as a <message-headers-mixin>",
              get-header(base-request, "header1"),
              "value1");
  check-equal("Act as a <message-headers-mixin>",
              get-header(base-request, "header2"),
              "value2");
end test test-prepare-request-headers-method;

define test test-prepare-request-content-method ()
  let base-request = make(<base-http-request>);
  let request = make(<http-request>,
                     url: "http://httpbin.org/get",
                     content: "test content");

  prepare-request-content(base-request, request);

  check-equal("Just copy request content",
              base-request.request-content,
              "test content");
end test test-prepare-request-content-method;

define test test-prepare-request-method ()
  let base-request = make(<base-http-request>);
  let headers = table(<header-table>,
                      "header1" => "value1", "header2" => "value2");
  let parameters = table(<string-table>,
                     "key1" => "value1", "key2" => "value2");
  let request = make(<http-request>,
                     url: "http://httpbin.org/get",
                     method: #"get",
                     parameters: parameters,
                     headers: headers,
                     content: "test content");

  let base-request = prepare-request(request);

  check-equal("Prepare request method",
              base-request.request-method,
              request.request-method);
  check-equal("Prepare request url",
              build-uri(base-request.request-url),
              "http://httpbin.org/get?key2=value2&key1=value1");
  check-equal("Prepare request headers",
              get-header(base-request, "header1"),
              "value1");
  check-equal("Prepare request content",
              base-request.request-content,
              "test content");
end test test-prepare-request-method;

define suite prepare-request-test-suite ()
  test test-prepare-request-method-method;
  test test-prepare-request-url-method;
  test test-prepare-request-headers-method;
  test test-prepare-request-content-method;
  test test-prepare-request-method;
end suite prepare-request-test-suite;


define suite http-client-test-suite ()
  suite request-test-suite;
  suite prepare-request-test-suite;
end suite http-client-test-suite;

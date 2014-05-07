module: techempower-benchmarks
synopsis: json serialization benchmark.
author: Francesco Ceccon

define class <json-page> (<resource>)
  constant slot hello-string = "Hello, World!";
  slot message :: <string-table>;
end class;

define method initialize (page :: <json-page>, #key)
  page.message := table(<string-table>, "message" => "Hello, World!");
end method;

// set the correct content-type, then send "Hello, World!".
define method respond (page :: <json-page>, #key)
  set-header(current-response(), "Content-Type", "application/json");
  output(write-object-to-json-string(page.message));
end method respond;


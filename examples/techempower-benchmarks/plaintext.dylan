module: techempower-benchmarks
synopsis: plaintext benchmark.
author: Francesco Ceccon

define class <plaintext-page> (<resource>)
  constant slot hello-string = "Hello, World!";
end class;

// set the correct content-type, then send "Hello, World!".
define method respond (page :: <plaintext-page>, #key)
  set-header(current-response(), "Content-Type", "text/plain");
  output(page.hello-string);
end method respond;


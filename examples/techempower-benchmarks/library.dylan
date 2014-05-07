module: dylan-user
synopsis: TechEmpower plaintext benchmark
author: Francesco Ceccon

define library techempower-benchmarks
  use common-dylan;
  use http-common;
  use http-server;
  use serialization;
  use collections;
end;


define module techempower-benchmarks
  use common-dylan;
  use http-common;
  use http-server;
  use json-serialization;
  use table-extensions;
end;


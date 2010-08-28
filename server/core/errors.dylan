Module:    httpi

// Most of the code here was moved to http-common.


define class <koala-error> (<format-string-condition>, <error>)
end;

// Signalled when a library uses the Koala API incorrectly. i.e., user
// errors such as registering a page that has already been registered.
// Not for errors that will be reported to the HTTP client.
//
define open class <koala-api-error> (<koala-error>)
end;

define function koala-api-error
    (format-string :: <string>, #rest format-arguments)
  signal(make(<koala-api-error>,
              format-string: format-string,
              format-arguments: format-arguments));
end;


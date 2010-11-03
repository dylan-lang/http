Module:    http-common-internals
Synopsis:  Response codes and associated error classes.
Author:    Carl Gay
Copyright: Copyright (c) 2001-2010 Carl L. Gay.  All rights reserved.
           Original Code is Copyright (c) 2001 Functional Objects, Inc.  All rights reserved.
License:   Functional Objects Library Public License Version 1.0
Warranty:  Distributed WITHOUT WARRANTY OF ANY KIND


//// HTTP status codes

// Informational 1xx
define constant $status-continue :: <integer> = 100;
define constant $status-switching-protocols :: <integer> = 101;

// Successful 2xx
define constant $status-ok :: <integer> = 200;
define constant $status-created :: <integer> = 201;
define constant $status-accepted :: <integer> = 202;
define constant $status-non-authoritative-information :: <integer> = 203;
define constant $status-no-content :: <integer> = 204;
define constant $status-reset-content :: <integer> = 205;
define constant $status-partial-content :: <integer> = 206;

// Redirection 3xx
define constant $status-multiple-choices :: <integer> = 300;
define constant $status-moved-permanently :: <integer> = 301;
define constant $status-found :: <integer> = 302;
define constant $status-see-other :: <integer> = 303;
define constant $status-not-modified :: <integer> = 304;
define constant $status-use-proxy :: <integer> = 305;
// 306 unused
define constant $status-temporary-redirect :: <integer> = 307;

// Client Error 4xx
define constant $status-bad-request :: <integer> = 400;
define constant $status-unauthorized :: <integer> = 401;
define constant $status-payment-required :: <integer> = 402;
define constant $status-forbidden :: <integer> = 403;
define constant $status-not-found :: <integer> = 404;
define constant $status-method-not-allowed :: <integer> = 405;
define constant $status-not-acceptable :: <integer> = 406;
define constant $status-proxy-authentication-required :: <integer> = 407;
define constant $status-request-timeout :: <integer> = 408;
define constant $status-conflict :: <integer> = 409;
define constant $status-gone :: <integer> = 410;
define constant $status-length-required :: <integer> = 411;
define constant $status-precondition-failed :: <integer> = 412;
define constant $status-request-entity-too-large :: <integer> = 413;
define constant $status-request-uri-too-long :: <integer> = 414;
define constant $status-unsupported-media-type :: <integer> = 415;
define constant $status-requested-range-not-satisfiable :: <integer> = 416;
define constant $status-expectation-failed :: <integer> = 417;

// Server Error 5xx
define constant $status-internal-server-error :: <integer> = 500;
define constant $status-not-implemented :: <integer> = 501;
define constant $status-bad-gateway :: <integer> = 502;
define constant $status-service-unavailable :: <integer> = 503;
define constant $status-gateway-timeout :: <integer> = 504;
define constant $status-http-version-not-supported :: <integer> = 505;

// Local extensions
define constant $status-application-error :: <integer> = 599;



// For any error related to the HTTP libraries.
define open class <http-error> (<format-string-condition>, <error>)
end;

define generic http-error-headers
    (error :: <error>) => (headers :: false-or(<header-table>));

define method http-error-headers
    (error :: <error>) => (headers :: false-or(<header-table>))
  #f
end;

define generic http-status-code
    (error :: <error>) => (code :: <integer>);

define open class <http-protocol-condition> (<http-error>)
  constant slot http-status-code :: <integer>,
    required-init-keyword: code:;
  constant slot http-error-headers :: false-or(<header-table>),
    init-value: #f,
    init-keyword: headers:;
end;

// This is for sending to the client
define method http-error-message-no-code
    (error :: <http-protocol-condition>) => (msg :: false-or(<string>))
  apply(format-to-string,
        condition-format-string(error),
        condition-format-arguments(error))
end;

define method http-error-message-no-code
    (error :: <error>) => (msg :: <string>)
  "An unhandled application error was encountered."
end method http-error-message-no-code;

// This is for logging.
define method condition-to-string
    (error :: <http-error>) => (s :: <string>)
  format-to-string("%d %s",
                   http-status-code(error),
                   http-error-message-no-code(error))
end;

define constant $status-code-to-class-map = make(<table>);

define function condition-class-for-status-code
    (code :: <integer>) => (class :: <class>)
  element($status-code-to-class-map, code, default: <http-protocol-condition>)
end;

define macro http-error-definer
 { define http-error ?:name (?supers:*)
       ?status-code:expression, ?format-string:expression, ?format-args:* }
  => { define class "<" ## ?name ## ">" (?supers) end;
       define constant "$" ## ?name = ?status-code;
       $status-code-to-class-map["$" ## ?name] := "<" ## ?name ## ">";
       define function ?name (#key headers :: false-or(<header-table>),
                                   header-name :: false-or(<string>),
                                   header-value :: false-or(<string>),
                                   ?format-args)
         if (header-name & header-value)
           headers := headers | make(<header-table>);
           headers[header-name] := header-value;
         end;
         signal(make("<" ## ?name ## ">",
                     code: "$" ## ?name,
                     headers: headers,
                     format-string: ?format-string,
                     format-arguments: vector(?format-args)));
       end
     }
end;

////////////////////////////
// Error codes 3xx
////////////////////////////

define class <http-redirect-condition> (<http-protocol-condition>)
end;

define http-error moved-permanently-redirect (<http-redirect-condition>)
    301, "The requested document has moved permanently to %s",
    location;

define http-error found-redirect (<http-redirect-condition>)
    302, "The document has moved temporarily to %s",
    location;

define http-error see-other-redirect (<http-redirect-condition>)
    303, "See Other",
    location;

define http-error not-modified-redirect (<http-redirect-condition>)
    304, "Not Modified";

define http-error use-proxy-redirect (<http-redirect-condition>)
    305, "Use Proxy",
    location;

// 306 unused

define http-error moved-temporarily-redirect (<http-redirect-condition>)
    307,
    "The document has moved temporarily to %s",
    location;


////////////////////////////
// Error codes 4xx
////////////////////////////

//  Some 4xx error codes (e.g., 404) aren't really client
// errors, but we'll stick with the RFC definition.
define class <http-client-protocol-error> (<http-protocol-condition>)
end;

define class <http-parse-error> (<http-client-protocol-error>)
end;

define http-error bad-request-error (<http-parse-error>)
    400, "Bad request: %s",
    reason;

define http-error header-too-large-error (<http-client-protocol-error>)
    400, "Request header size exceeded limit of %d bytes",
    max-size;

define http-error bad-header-error (<http-parse-error>)
    400, "Invalid header: %s",
    message;

// Response MUST include WWW-Authenticate header
define http-error unauthorized-error (<http-client-protocol-error>)
    401, "Unauthorized";

define http-error payment-required-error (<http-client-protocol-error>)
    402, "Payment Required";

define http-error forbidden-error (<http-client-protocol-error>)
    403, "Forbidden";

define http-error resource-not-found-error (<http-client-protocol-error>)
    404, "Resource not found: %s",
    url;

define http-error method-not-allowed-error (<http-client-protocol-error>)
    405, "Request method not allowed: %s",
    request-method;

// This is when can't match Accept headers.
// Response SHOULD include description of available characteristics.
define http-error not-acceptable-error (<http-client-protocol-error>)
    406, "Not Acceptable";

define http-error proxy-authentication-required-error (<http-client-protocol-error>)
    407, "Proxy Authentication Required";

define http-error request-timeout-error (<http-client-protocol-error>)
    408, "Request timeout, no data after %d seconds",
    seconds;

define http-error conflict-error (<http-client-protocol-error>)
    409, "Conflict";

define http-error gone-error (<http-client-protocol-error>)
    410, "Gone";

define http-error content-length-required-error (<http-client-protocol-error>)
    411, "Content-Length required";

define http-error precondition-failed-error (<http-client-protocol-error>)
    412, "Precondition failed";

// The server MAY close the connection to prevent the client from continuing
// the request.
define http-error request-entity-too-large-error (<http-client-protocol-error>)
    413, "Request entity exceeded limit of %d bytes",
    max-size;

define http-error request-uri-too-long-error (<http-client-protocol-error>)
    414, "Request URL exceeded limit of %d bytes",
    max-size;

define http-error unsupported-media-type-error (<http-client-protocol-error>)
    415, "Unsupported media type";

define http-error requested-range-not-satisfiable-error (<http-client-protocol-error>)
    416, "Requested range not satisfiable";

define http-error expectation-failed-error (<http-client-protocol-error>)
    417, "Expectation failed";


////////////////////////////
// Error codes 5xx
////////////////////////////

define class <http-server-protocol-error> (<http-protocol-condition>)
end;

define http-error internal-server-error (<http-server-protocol-error>)
    500, "Internal server error";

define http-error not-implemented-error (<http-server-protocol-error>)
    501, "%s not implemented",
    what;

define http-error bad-gateway-error (<http-server-protocol-error>)
    502, "Bad Gateway";

// Can include Retry-After header.
define http-error service-unavailable-error (<http-server-protocol-error>)
    503, "Service unavailable";

define http-error gateway-timeout-error (<http-server-protocol-error>)
    504, "Gateway Timeout";

define http-error http-version-not-supported-error (<http-server-protocol-error>)
    505, "HTTP version %s not supported",
    version;

define http-error application-error (<http-server-protocol-error>)
    599, "%s",
    message;

// Any error caused by non-server code will be reported as a server error.
// 599 is a non-standard return code, but clients SHOULD display the message
// sent back with non-standard return codes in the 4xx and 5xx range.
// Don't use 500 because that looks like the web server itself is broken.
// Heh...it might be.
//
define method http-status-code
    (ex :: <error>) => (code :: <integer>)
  $application-error
end;



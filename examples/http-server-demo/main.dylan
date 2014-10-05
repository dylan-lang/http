Module: http-server-demo
Synopsis: Examples of how to use the http-server and dsp libraries
Author: Carl Gay

// TODO: Need an example of using a paginator and some other DSP utilities.


//// Low-level server API examples

// To respond to a URL, define a subclass of <resource> and define a
// method on respond or one of the respond-to-{get,post,...} methods:

define class <basic-resource-1> (<resource>)
end;

define method respond-to-get
    (resource :: <basic-resource-1>, #key) => ()
  set-header(current-response(), "Content-Type", "text/html");
  output("<html><body>This is the output of respond-to-get(&lt;basic-resource-1&gt;)."
         "<p>Use your browser's Back button to return to the example.</p>"
         "</body></html>");
end method respond-to-get;

define class <basic-resource-2> (<resource>)
end;

define method respond
    (resource :: <basic-resource-2>, #key)
  if (current-request().request-method = $http-get-method)
    set-header(current-response(), "Content-Type", "text/plain");
    output("This resource uses the 'respond' method directly.");
  else
    next-method();  // don't handle the request
  end;
end;


// For this resource to work as expected, add-resource is called with
// a URL that accepts a variable number of path elements.  i.e., it
// has ".../{vars*}" in the URL.  (The name 'vars' can be anything,
// but must match the keyword argument in the respond-to-get method.)
define class <basic-resource-3> (<resource>)
end;

define method respond-to-get
    (resource :: <basic-resource-3>, #key vars) => ()
  let request :: <request> = current-request();
  set-header(current-response(), "Content-Type", "text/html");
  output("<html><body>"
           "<p>URL prefix: %s</p>"
           "<p>URL suffix: %s</p>"
           "<p>vars: %s</p>"
           "</body></html>",
         request.request-url-path-prefix,
         request.request-url-path-suffix,
         vars);
end;

// Note the use of do-query-values to find all the values passed in
// the URL (e.g., /hello?foo=1&bar=2).  You can also use get-query-value
// to get a specific query value, and count-query-values can be used to
// find out how many there are.

define class <basic-resource-4> (<resource>)
end;

define method respond-to-get
    (resource :: <basic-resource-4>, #key) => ()
  set-header(current-response(), "Content-Type", "text/plain");
  if (count-query-values() > 0)
    output("Query values are:");
  else
    output("No query values were passed in the URL.");
  end;
  do-query-values(method (key, val)
                    output("\nkey = %s, val = %s", key, val);
                  end);
  output("\n\nUse your browser's Back button to return to the demo.");
end;



//// Example: Dylan Server Pages

// A DSP is just a resource that is associated with a template
// When creating a <dylan-server-page> you must pass the
// source: "foo/my.dsp" argument.

// In general you will define respond-to-get/post methods for your
// <dylan-server-page>s that do some processing based on the query
// values in the request and then call process-template(page) to
// process the template for the page or call process-template on
// some other page to display its output instead (e.g., an error
// template).

// Any plain content in the template is output directly to the output
// stream, and tags invoke the corresponding tag definition.

// This defines a class that will be used for all our example pages.
// It must be a subclass of <dylan-server-page> so that all the
// template parsing will happen.  If we define all our tags to be
// specialized on this class they can be used in any demo page.
//
define class <demo-page> (<dylan-server-page>)
end;

// Define a tag library in which to put all tag definitions.
//
define taglib demo ()
end;


// You may also define tags and actions directly in the taglib definition...
//
define taglib example ()
  prefix "x";

  tag hello (page :: <demo-page>) (arg)
    output(arg);

  body tag repeat (page :: <demo-page>, process-body) (n :: <integer>)
    for (i from 1 to n)
      process-body()
    end;

  action logged-in?;

  action word-list (page :: <demo-page>)
    #("a", "b", "c");
end taglib example;


// Defines a tag that looks like <demo:hello/> in the DSP source
// file.  i.e., it has no body.
define tag hello in demo
    (page :: <demo-page>)
    ()
  output("Hello, world!");
end;

// This tag demonstrates the use of tag keyword arguments.  The tag call looks
// like this:  <demo:show-keys arg1="100" arg2="foo"/>
// Note that since arg1 is typed as an <integer> it is automatically parsed to
// an <integer>.  To define new tag argument parsers, add methods to the
// parse-tag-arg generic.
//
define tag show-keys in demo
    (page :: <demo-page>)
    (arg1 :: <integer>, arg2)
  output("The value of arg1 + 1 is %=.  The value of arg2 is %=.",
         arg1 + 1, arg2);
end;

// Named methods can be used in various control flow tags defined in the
// "dsp" taglib.  For example, <dsp:if test="logged-in?">...</dsp:if>
//
define named-method logged-in? in demo
    (page :: <demo-page>)
  let session = get-session(current-request());
  session & get-attribute(session, "username");
end;

define class <login-page> (<demo-page>)
end;

define constant *login-page* = make(<login-page>, source: "dsp/login.dsp");

define class <logout-page> (<demo-page>)
end;

define method respond-to-get
    (page :: <logout-page>, #key) => ()
  let session = get-session(current-request());
  remove-attribute(session, "username");
  remove-attribute(session, "password");
  // Process the template for this page...
  next-method();
end method respond-to-get;

// The login page POSTs to the welcome page...
define class <welcome-page> (<demo-page>)
end;

// ...so handle the POST by storing the form values in the session.
define method respond-to-post
    (page :: <welcome-page>, #key) => ()
  let username = get-query-value("username");
  let password = get-query-value("password");
  let username-supplied? = username & username ~= "";
  let password-supplied? = password & password ~= "";
  if (username-supplied? & password-supplied?)
    let session = get-session(current-request());
    set-attribute(session, "username", username);
    set-attribute(session, "password", password);
    // Process the template for this page...
    next-method();
  else
    if (~username-supplied?)
      add-field-error("username", "Username is required");
    end;
    if (~password-supplied?)
      add-field-error("password", "Password is required");
    end;
    // For good measure we'll add a note at the top of the page, not associated
    // with a particular field.
    add-page-error("Please fix the errors below.");
    respond-to-get(*login-page*);
  end;
end method respond-to-post;

// Note this tag is defined on <demo-page> so it can be accessed from any
// page in this example web application.
define tag current-username in demo
    (page :: <demo-page>)
    ()
  let request = current-request();
  let response = current-response();
  let username
    = get-query-value("username")
        | get-attribute(get-session(request), "username");
  username & output(username);
end;



//// iterator

define thread variable *repetition-number* = 0;

// An iterating tag.  Note the use of the "body" modifier in "define body tag".
// When this modifier is used the tag accepts a third argument, in this case
// called "do-body".  do-body is a function of zero arguments that will execute
// the body of the tag.  It may be invoked any number of times.  Use thread
// variables or object state to communicate with the tags that are invoked
// during the execution of the body part.  Note the use of get-query-value to
// get the argument "n" that can be passed in the URL or in the POST.
// See iterator.dsp for how this tag is invoked.
//
define body tag repeat in demo
    (page :: <demo-page>, do-body :: <function>)
    ()
  let n-str = get-query-value("n");
  let n = (n-str & string-to-integer(n-str)) | 5;
  for (i from 1 to n)
    dynamic-bind (*repetition-number* = i)
      do-body();
    end;
  end;
end;

define tag display-iteration-number in demo
    (page :: <demo-page>)
    ()
  output("%d", *repetition-number*);
end;



//// table generation

// This method is used as the row-generator function for a dsp:table call.
// It must return a <sequence>.
define named-method animal-generator in demo
    (page :: <demo-page>)
  #[#["dog", "perro", "gou3"],
    #["cat", "gato", "mao1"],
    #["cow", "vaca", "niu2"]]
end;

// The row-generator for the table with no rows.
define named-method no-rows-generator in demo
    (page :: <demo-page>)
  #[]
end;

define tag english-word in demo
    (page :: <demo-page>)
    ()
  let row = current-row();
  output("%s", row[0]);
end;

define tag spanish-word in demo
    (page :: <demo-page>)
    ()
  let row = current-row();
  output("%s", row[1]);
end;

define tag pinyin-word in demo
    (page :: <demo-page>)
    ()
  let row = current-row();
  output("%s", row[2]);
end;

// Can be replaced by CSS in recent browsers.
//
define tag row-bgcolor in demo
    (page :: <demo-page>)
    ()
  output(if(even?(current-row-number()))
           "#EEEEEE"
         else
           "#FFFFFF"
         end);
end;



/// Main

define function map-resources
    (server :: <http-server>)
  // two URLs map to the home page
  let home = make(<demo-page>, source: "dsp/home.dsp");
  add-resource(server, "/", home);
  add-resource(server, "/home", home);
  add-resource(server, "/resource-1", make(<basic-resource-1>));
  add-resource(server, "/resource-2", make(<basic-resource-2>));
  add-resource(server, "/resource-3/{vars*}", make(<basic-resource-3>));
  add-resource(server, "/resource-4", make(<basic-resource-4>));
  add-resource(server, "/hello", make(<demo-page>, source: "dsp/hello.dsp"));
  add-resource(server, "/args", make(<demo-page>, source: "dsp/args.dsp"));
  add-resource(server, "/login", *login-page*);
  add-resource(server, "/logout", make(<logout-page>, source: "dsp/logout.dsp"));
  add-resource(server, "/welcome", make(<welcome-page>, source: "dsp/welcome.dsp"));
  add-resource(server, "/iterator", make(<demo-page>, source: "dsp/iterator.dsp"));
  add-resource(server, "/table", make(<demo-page>, source: "dsp/table.dsp"));
end function map-resources;

define function main
    ()
  // If you don't need to add any new command-line arguments you can just
  // call http-server-main directly.  It allows you to pass --config <filename>
  // and other args on the command line.  Use --help to see options.
  // start-server can also be used directly if you want to do your own
  // command-line parsing.
  http-server-main(server: make(<http-server>),
                   before-startup: map-resources);
end function main;

main();


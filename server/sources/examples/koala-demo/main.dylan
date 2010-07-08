Module:    koala-demo
Synopsis:  Examples of how to use the Koala HTTP server
Author:    Carl Gay

/*

To use this example web application (if I may glorify it with that name),
compile this library and invoke the executable with --config <filename>.
You will probably have to fix the config file to make the dsp-root setting
point at the directory containing the demo .dsp template files:

    libraries/network/koala/www/demo

Each page demonstrates a feature of Koala or Dylan Server Pages.  You should
be able to find the code corresponding to a particular URL by searching for
that URL in this file.  Some XML-RPC methods are defined near the bottom.

Note that any URLs registered for dynamic pages hide URLs corresponding to
files in the document root directory.  i.e., the dynamic URL takes precedence.

*/

//// URLs

// Using relative URLs in a web application strikes me as asking for trouble
// in general.  For example, if you register an alias URL "/demo" for a page
// "/demo/home.dsp" then URLs that appear in the home.dsp template would be
// relative to / when the page is processed, rather than relative to /demo/.
// So always use absolute URLs.

define constant $demo-base-url :: <byte-string> = "/demo";



// The lowest level API for responding to a URL is just a function
// That does output to the response's output stream.  The simplest
// way to do that is to use the "output" function.  The only thing
// special about a responder function is that it must accept keyword
// arguments.  The match: argument is always passed and is always a
// <regex-match> object.  See the documentation for url-map for 
// details.

define function responder1 (#key)
  output("<html><body>This is the output of a simple responder function."
         "<p>Use your browser's Back button to return to the example."
         "</body></html>");
end function responder1;

define function prefix1 (#key)
  output("<html><body>This is a prefix responder.  The part of the url after "
         "the prefix was %s."
         "<p>Use your browser's Back button to return to the example.</p>"
         "</body></html>",
         // Note that we could also use "#key match" above and then get the
         // entire match with match-group(match, 0).
         current-request().request-path-tail);
end function prefix1;



//// Page abstraction

// Slightly higher level than responders.  Gives you the convenience of not
// having to figure out whether it's a GET, POST, etc, request, and the ability
// to dispatch on your own page classes.  Just define methods for
// respond-to* that dispatch on your page class.

// Note that you may override respond-to-get and respond-to-post instead of
// overriding respond-to(== #"get") and respond-to(== #"post") as a convenience
// since these are by far the most common request methods.

define class <hello-world-page> (<page>)
end;

// Respond to a GET for <hello-world-page>.  Note the use of do-query-values to
// find all the values passed in the URL (e.g., /hello?foo=1&bar=2).  You can
// also use get-query-value to get a specific query value, and
// count-query-values can be used to find out how many there are.
//
define method respond-to-get
    (page :: <hello-world-page>, #key)
  output("<html>\n<head><title>Hello World</title></head>\n"
         "<body>Hello there.<p>");
  output("%s<br>", if (count-query-values() > 0)
                     "Query values are:"
                   else
                     "No query values were passed in the URL."
                   end);
  do-query-values(method (key, val)
                    output("key = %s, val = %s<br>\n", key, val);
                  end);
  output("<p>Use your browser's Back button to return to the "
         "demo.</body></html>");
end method respond-to-get;


//// Dylan Server Pages

// A DSP is basically just a page that is associated with a top-level
// template.  When creating a <dylan-server-page> you must pass the
// source: "foo/my.dsp" argument.

// In general you will define respond-to-get/post methods for your
// <dylan-server-page>s that do some processing based on the query
// values in the request and then call process-template(page) to
// process the template for the page or call process-template on
// some other page to display its output instead (e.g., an error
// template).

// Any plain content in the template is output directly to the output
// stream, and tags invoke the corresponding tag definition.

// Note that the .dsp source file doesn't have to be under Koala's
// document root directory.  (Does it need to be under the DSP root?
// Check this. --cgay)

// This defines a class that will be used for all our example pages.
// It must be a subclass of <dylan-server-page> so that all the
// template parsing will happen.  If we define all our tags to be
// specialized on this class they can be used in any demo page.
//
define class <demo-page> (<dylan-server-page>)
end;

// Define a tag library in which to put all tag definitions.  This
// isn't strictly necessary; tag defs can go in the existing 'dsp'
// tag library but then you run the risk of overriding built-in DSP
// tags or other user-defined tags in the dsp taglib.
//
define taglib demo ()
end;


// You may also define tags and actions directly in the taglib definition...
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


// <demo:base-url/> tag, so templates don't have to hard-code absolute urls.
//
define tag base-url in demo
    (page :: <demo-page>)
    ()
  // output(format-string, format-arg, ...) sends output directly to the
  // response stream.
  output($demo-base-url);
end;

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

define constant *login-page* = make(<login-page>, source: "demo/login.dsp");

define class <logout-page> (<demo-page>)
end;

define method respond-to-get
    (page :: <logout-page>, #key)
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
    (page :: <welcome-page>, #key)
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
  let response = current-response();
  let username
    = get-query-value("username")
        | get-attribute(get-session(response.response-request), "username");
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

define url-map $demo-url-map ()
  //prefix "/demo";    ...would be nice
  url ("/demo", "/demo/home")
    // Note that when a page just has a template but no special respond-to*
    // method there's no need to define a new page subclass for it.  You
    // just make a <dylan-server-page> (or subclass thereof) and specify
    // the source: for the template.
    action GET () => make(<demo-page>, source: "demo/home.dsp");
  url "/demo/responder1"
    action GET () => responder1;       // regex defaults to "^$"
  url "/demo/prefix1"
    action GET (".*") => prefix1;
  url ("/demo/hello-world", "/demo/hello")
    action GET () => make(<hello-world-page>);
  url "/demo/args"
    action GET () => make(<demo-page>, source: "demo/args.dsp");
  url "/demo/login"
    action GET () => *login-page*;
  url "/demo/logout"
    action (GET, POST) () => make(<logout-page>, source: "demo/logout.dsp");
  url "/demo/welcome"
    action POST () => make(<welcome-page>, source: "demo/welcome.dsp");
  url "/demo/iterator"
    action GET () => make(<demo-page>, source: "demo/iterator.dsp");
  url "/demo/table"
    action GET () => make(<demo-page>, source: "demo/table.dsp");
end url-map;

define constant $http-server = make(<http-server>, url-map: $demo-url-map);

//// XML-RPC (use any XML-RPC client to call these)
define xml-rpc-server $xml-rpc-server ("/RPC2" on $http-server)
    ()
  "test.zero" => method () end;
  "test.one"  => method () 1 end;
  "test.two"  => method () "two" end;
  "test.three" => method () vector(1, "two", 3.0) end;
  "test.four" => method ()
                   let result = make(<table>);
                   result["x"] := vector(vector(7), 8);
                   result["y"] := "my <dog> has fleas";
                   result
                 end;
end xml-rpc-server $xml-rpc-server;


/// Main

begin
  // If you don't need to add any new command-line arguments you can just
  // call koala-main directly.  It allows you to pass --config <filename>
  // and other args on the command line.  Use --help to see options.
  // start-server can also be used directly if you want to do your own
  // command-line parsing.
  koala-main(server: $http-server);
end;


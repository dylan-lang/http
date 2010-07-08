<html>
<head>
  <title>DSP Example -- Home</title>
</head>

<body>

  <%dsp:include location="header.dsp"/>
  <%dsp:include location="body-wrapper-start.dsp"/>
  <%dsp:taglib name="demo"/>

  <h2>Home</h2>

  Each page of this demo demonstrates at least one different feature
  of Dylan Server Pages.  There's no preset order to the pages; just
  click on one to see what happens and then look at the Dylan source
  code to see how it's implemented.  There are comments in the source
  that should be helpful.

  <p>
  <h3>Contents</h3>

  <ol>
    <li><a href="<demo:base-url/>/hello">Hello World</a></li>
    <li><a href="<demo:base-url/>/args">A tag with arguments</a></li>
    <li><a href="<demo:base-url/>/login">Login (demonstrates sessions)</a></li>
    <li><a href="<demo:base-url/>/logout">Logout (demonstrates sessions)</a></li>
    <li><a href="<demo:base-url/>/iterator?n=3">Iterator (demonstrates query
             values and body tags)</a></li>
    <li><a href="<demo:base-url/>/table">Table Generation</a></li>
  </ol>

  <p>
  <h3>Low-level Koala API</h3>

  <ol>
    <li><a href="<demo:base-url/>/responder1">
	  A responder (the most basic way to respond to a URL)
	</a></li>
    <li><a href="<demo:base-url/>/prefix1/one/two/three">A prefix responder.
        Same as above, but matches any url starting with /prefix1.</a></li>
    <li><a href="<demo:base-url/>/hello?a=1&b=2">Hello World (a non-DSP page)</a></li>
  </ol>

  <%dsp:include location="body-wrapper-end.dsp"/>
  <%dsp:include location="footer.dsp"/>

</body>
</html>

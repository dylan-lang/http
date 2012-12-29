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
  of the HTTP server or Dylan Server Pages.  There's no preset order to the
  pages; just click on one to see what happens and then look at the
  Dylan source code to see how it's implemented.  There are comments
  in the source that should be helpful.

  <p>
  <h3>Low-level HTTP Server API</h3>

  Click these and then use your browser's back button to return to here.

  <ol>
    <li>
      <a href="/resource-1">Resource 1</a>
      The most basic way to respond to a URL.  Outputs text/html, which is the
      default content type.  Uses a <code>respond-to-get</code> method.
    </li>
    <li>
      <a href="/resource-2">Resource 2</a>
      Demonstrates setting the content type (to text/plain) and using the
      <code>respond</code> method.
    </li>
    <li>
      <a href="/resource-3/one/two/three">Resource 3</a>
      Demonstrates accessing the URL path suffix, i.e., the unmatched part.
    </li>
    <li>
      <a href="/resource-4?a=1&b=2">Resource 4</a>
      Demonstrates accessing query values.
    </li>
  </ol>

  <p>
  <h3>Dylan Server Pages</h3>

  <ol>
    <li><a href="/hello">Hello World -- Demonstrates a basic DSP page.</a></li>
    <li><a href="/args">A DSP tag with arguments</a></li>
    <li><a href="/login">Login -- Demonstrates sessions</a></li>
    <li><a href="/logout">Logout -- Demonstrates sessions</a></li>
    <li><a href="/iterator?n=3">Iterator -- Demonstrates query values and body tags.</a></li>
    <li><a href="/table">DSP Table Generation</a></li>
  </ol>

  <%dsp:include location="body-wrapper-end.dsp"/>
  <%dsp:include location="footer.dsp"/>

</body>
</html>

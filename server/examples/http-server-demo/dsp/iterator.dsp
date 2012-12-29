<%dsp:taglib name="demo"/>

<html>
<head>
  <title>DSP Example -- Iterator</title>
</head>

<body>

  <%dsp:include location="header.dsp"/>
  <%dsp:include location="body-wrapper-start.dsp"/>

  <dsp:show-page-errors/>

  <h2>Iterator</h2>

  This page demonstrates a simple iterator tag called &quot;repeat&quot;.  It's really
  nothing more than a tag that specifies the &quot;body&quot; modifier.

  <p>Specify a query value of n=xxx in the URL to change the number of iterations.
  <p>
  <demo:repeat>
    <br/>This is iteration <demo:display-iteration-number/>.
  </demo:repeat>


  <%dsp:include location="body-wrapper-end.dsp"/>
  <%dsp:include location="footer.dsp"/>

</body>
</html>

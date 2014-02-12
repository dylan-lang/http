<%dsp:taglib name="demo"/>

<html>
<head>
  <title>DSP Example -- Welcome</title>
</head>

<body>
  <%dsp:include location="header.dsp"/>
  <%dsp:include location="body-wrapper-start.dsp"/>

  <h2>Welcome, <demo:current-username/>!</h2>

  <%dsp:include location="body-wrapper-end.dsp"/>
  <%dsp:include location="footer.dsp"/>

</body>
</html>


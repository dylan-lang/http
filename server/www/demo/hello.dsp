<%dsp:taglib name="demo"/>

<html>
<head>
  <title>DSP Example -- Hello</title>
</head>

<body>

  <%dsp:include location="header.dsp"/>
  <%dsp:include location="body-wrapper-start.dsp"/>

  <p>This page demonstrates a simple tag call that displays &quot;hello world&quot;.

  <p><demo:hello/>

  <%dsp:include location="body-wrapper-end.dsp"/>
  <%dsp:include location="footer.dsp"/>

</body>
</html>

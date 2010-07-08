<%dsp:taglib name="demo"/>

<html>
<head>
  <title>DSP Example -- Tag arguments</title>
</head>

<body>

  <%dsp:include location="header.dsp"/>
  <%dsp:include location="body-wrapper-start.dsp"/>

  <p>This page demonstrates a tag call with arguments.

  <p><demo:show-keys arg1="100" arg2="foo"/>

  <%dsp:include location="body-wrapper-end.dsp"/>
  <%dsp:include location="footer.dsp"/>

</body>
</html>

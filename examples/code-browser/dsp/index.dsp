<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<%dsp:taglib name="code-browser"/>
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
  <title>Code Browser</title>
</head>
<body>
  Available Libraries:
  <ul>
  <code-browser:libraries>
    <li><a href="<code-browser:canonical-link/>"><code-browser:display-name/></a></li>
  </code-browser:libraries>
  </ul>
</body>
</html>

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<%dsp:taglib name="code-browser"/>
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
  <title>Library: <code-browser:display-name/></title>
</head>
<body>
  Visible Modules:
  <ul>
  <code-browser:modules>
    <li><a href="<code-browser:canonical-link/>"><code-browser:display-name/></a></li>
  </code-browser:modules>
  </ul>
  Defined Modules:
  <ul>
  <code-browser:defined-modules>
    <li><a href="<code-browser:canonical-link/>"><code-browser:display-name/></a></li>
  </code-browser:defined-modules>
  </ul>
  Used Libraries:
  <ul>
  <code-browser:used-libraries>
    <li><a href="<code-browser:canonical-link/>"><code-browser:display-name/></a></li>
  </code-browser:used-libraries>
  </ul>
  Source:
  <pre><code-browser:source/></pre>
</body>
</html>

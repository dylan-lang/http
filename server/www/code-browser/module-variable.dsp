<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<%dsp:taglib name="code-browser"/>
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
  <title>Variable: <code-browser:display-name/></title>
</head>
<body>
Thread?: <code-browser:thread-variable/><br/>
Name: <code-browser:display-name/><br/>
Type: <code-browser:variable-type/><br/>
Value: <code-browser:variable-value/><br/>
Source code:
  <pre><code-browser:source/></pre>
</body>
</html>

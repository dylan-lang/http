<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<%dsp:taglib name="code-browser"/>
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
  <title>Function: <code-browser:display-name/></title>
</head>
<body>
Function: <code-browser:display-name/><br/>
Required parameters:
<ul>
  <code-browser:function-parameters>
    <li><code-browser:parameter-name/> :: <code-browser:parameter-type/></li>
  </code-browser:function-parameters>
</ul>
Rest: <code-browser:rest><code-browser:parameter-name/> :: <code-browser:parameter-type/></code-browser:rest>
Keys:
<ul>
  <code-browser:keyword-parameters>
    <li><code-browser:parameter-name/> :: <code-browser:parameter-type/>, Keyword: <code-browser:parameter-keyword/>, default value: <code-browser:parameter-default-value/></li>
  </code-browser:keyword-parameters>
</ul>
All-keys: <code-browser:all-keys/>
Next: <code-browser:next-method><code-browser:parameter-name/> :: <code-browser:parameter-type/></code-browser:next-method>
Values:
<ul>
  <code-browser:values>
    <li><code-browser:parameter-name/> :: <code-browser:parameter-type/></li>
  </code-browser:values>
</ul>
Rest-value: <code-browser:rest-value><code-browser:parameter-name/> :: <code-browser:parameter-type/></code-browser:rest-value>
<hr>
  <pre><code-browser:source/></pre>
</body>
</html>

<%dsp:taglib name="demo"/>

<html>
<head>
  <title>DSP Example -- Login</title>
  <style type="text/css">
    .invalid-input { background-color: yellow; }
    .field-error, .page-errors { color: red; }
  </style>
</head>

<body>

  <%dsp:include location="header.dsp"/>
  <%dsp:include location="body-wrapper-start.dsp"/>

  <dsp:show-page-errors/>

  <form action="<demo:base-url/>/welcome"
        method="post"
        enctype="application/x-www-form-urlencoded">

    <h2>Please Login</h2>

    <p>This page demonstrates posting to a Dylan Server Page (see the
       respond-to method), using the DSP session, and use of simple tags.</p>

    <p>Any username and password will do.</p>

    <p>Try logging in without specifying both username and password to
       see the error mechanism.</p>

    <p/>
    <table border="0" cellspacing="2">
      <tr>
        <td nowrap align="right">User name:</td>
        <td nowrap>
          <input name="username" value="<demo:current-username/>" type="text"
                 <dsp:if-error field-name="username" text='class="invalid-input"'/>
                 />
          <dsp:show-field-errors field-name="username" tag="span"/>
        </td>
      </tr>
      <tr>
        <td nowrap align="right">Password:</td>
        <td nowrap>
          <input name="password" value="" type="password"
                 <dsp:if-error field-name="password" text='class="invalid-input"'/>
                 />
          <dsp:show-field-errors field-name="password" tag="span"/>
        </td>
      </tr>
      <tr>
        <td nowrap colspan="2">
          <input name="submit" value="Login" type="submit"/>
        </td>
      </tr>
    </table>
  </form>

  <%dsp:include location="body-wrapper-end.dsp"/>
  <%dsp:include location="footer.dsp"/>

</body>
</html>

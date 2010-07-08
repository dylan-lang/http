<%dsp:taglib name="demo"/>

<html>
<head>
  <title>DSP Example -- Table Generation</title>
</head>

<body>

  <%dsp:include location="header.dsp"/>
  <%dsp:include location="body-wrapper-start.dsp"/>

  <dsp:show-page-errors/>

  <h2>Table Generation</h2>

  <p>This page demonstrates the use of the dsp:table tag to generate HTML tables from a
  set of data, using dsp:table and other associated tags.</p>

  <p>A table with a bunch of rows:</p>
  <dsp:table border="1" align="center" cellspacing="2" generator="animal-generator">
    <dsp:hrow>
      <!-- hrow is always displayed exactly once, even if the table contains no rows. -->
      <dsp:hcell>Row #</dsp:hcell>
      <dsp:hcell>English</dsp:hcell>
      <dsp:hcell>Spanish</dsp:hcell>
      <dsp:hcell>Pinyin</dsp:hcell>
    </dsp:hrow>
    <dsp:row>
      <!-- rows are only displayed once for each item of table data. -->
      <dsp:cell><dsp:row-number/></dsp:cell>
      <dsp:cell><demo:english-word/></dsp:cell>
      <dsp:cell><demo:spanish-word/></dsp:cell>
      <dsp:cell><demo:pinyin-word/></dsp:cell>
    </dsp:row>
    <dsp:no-rows>
      <!-- no-rows is only displayed if the table contains no rows. -->
      <dsp:cell>There are no rows to display.</dsp:cell>
    </dsp:no-rows>
  </dsp:table>

  <p>The same table, with a row generator that returns no rows:</p>
  <dsp:table border="1" align="center" cellspacing="2" generator="no-rows-generator">
    <dsp:hrow>
      <!-- hrow is always displayed exactly once, even if the table contains no rows. -->
      <dsp:hcell>Row #</dsp:hcell>
      <dsp:hcell>English</dsp:hcell>
      <dsp:hcell>Spanish</dsp:hcell>
      <dsp:hcell>Pinyin</dsp:hcell>
    </dsp:hrow>
    <dsp:row>
      <!-- rows are only displayed once for each item of table data. -->
      <dsp:cell><dsp:row-number/></dsp:cell>
      <dsp:cell><demo:english-word/></dsp:cell>
      <dsp:cell><demo:spanish-word/></dsp:cell>
      <dsp:cell><demo:pinyin-word/></dsp:cell>
    </dsp:row>
    <dsp:no-rows>
      <!-- no-rows is only displayed if the table contains no rows. -->
      <dsp:cell colspan="4">There are no rows to display.</dsp:cell>
    </dsp:no-rows>
  </dsp:table>

  <%dsp:include location="body-wrapper-end.dsp"/>
  <%dsp:include location="footer.dsp"/>

</body>
</html>

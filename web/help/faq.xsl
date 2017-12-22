<?xml version="1.0"?>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="xml" 
      doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd" 
      doctype-public="-//W3C//DTD XHTML 1.0 Transitional//EN" indent="yes"/>
  <xsl:template match="/">

<html>
  <head>
    <style type="text/css"><![CDATA[
    
html, body {
  background-color: #f0f0f8;
  font-family: Lucida Grande, Arial, sans-serif;
  font-size: 12px;
  color: black;
}

a {
  color: black;
  font-weight: bold;
  text-decoration: none;
}
a:hover {
  background-color: #e0e0ef;
  text-decoration: underline;
}

div.question {
  margin: 24px;
}

table {
  font-family: Lucida Grande, Arial, sans-serif;
  font-size: 12px;
}

td.label {
  width:  1em;
  font-weight: bold;
  font-size: 125%;
  padding: 0.5em;
  background-color: #808088;
  color: white;
}

    ]]></style>
  </head>
  <body>
<a name="toc"></a>
<h1>SHUEBox</h1>
<h2>Frequently Asked Questions</h2>
<hr/>
<xsl:for-each select="faq/item">
  <div>
    <a>
      <xsl:attribute name="href">
        <xsl:text>#q_</xsl:text><xsl:value-of select="position()"/>
      </xsl:attribute>
      Q<xsl:value-of select="position()"/>
    </a>: <xsl:value-of select="q" disable-output-escaping="yes"/>
  </div>
</xsl:for-each>
<hr/>
<xsl:for-each select="faq/item">
    <a>
      <xsl:attribute name="name">
        <xsl:text>q_</xsl:text><xsl:value-of select="position()"/>
      </xsl:attribute>
    </a>
    <div class="question"><table>
      <tr>
        <td class="label">Q</td>
        <td><xsl:value-of select="q" disable-output-escaping="yes"/></td>
      </tr>
      <tr>
        <td class="label">A</td>
        <td>
          <xsl:for-each select="a">
            <p><xsl:value-of select="." disable-output-escaping="yes"/></p>
          </xsl:for-each>
        </td>
      </tr>
      <tr>
        <td colspan="2">
          <a href="#toc">Top</a>
        </td>
      </tr>
    </table></div>
</xsl:for-each>    
  </body>
</html>

  </xsl:template>
</xsl:stylesheet>

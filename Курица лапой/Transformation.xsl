<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" 
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:msxsl="urn:schemas-microsoft-com:xslt"
	xmlns:js="urn:my-namespace">
	
<msxsl:script language="JavaScript" implements-prefix="js">
  function get_element_id(url) {
  var element_id = '';

  try {
  element_id = (/((\d+))\/$/.exec(url))[1];
  }
  catch(err) {element_id = '';}

  return element_id;
  };

  function convert_date(d) {
    var ddmmyy = d.split(" ");
    var result = "";
    try {
      switch(ddmmyy[1].toLowerCase()) {
        case "января":  ddmmyy[1] = "01"; break;
        case "февраля": ddmmyy[1] = "02"; break;
        case "марта":   ddmmyy[1] = "03"; break;
        case "апреля":  ddmmyy[1] = "04"; break;
        case "мая":     ddmmyy[1] = "05"; break;
        case "июня":    ddmmyy[1] = "06"; break;
        case "июля":    ddmmyy[1] = "07"; break;
        case "авуста":  ddmmyy[1] = "08"; break;
        case "сентября":ddmmyy[1] = "09"; break;
        case "октября": ddmmyy[1] = "10"; break;
        case "ноября":  ddmmyy[1] = "11"; break;
        case "декабря": ddmmyy[1] = "12"; break;
      }

      result = ddmmyy[2] + "-" + ddmmyy[1] + "-" + ddmmyy[0];
    } 
    catch(err) {result = ""}

    return result;
  }

</msxsl:script>

	<xsl:template match="/">
		<items>
			<xsl:for-each select="//../div[@class='item']">
				<xsl:apply-templates select="*"/>
			</xsl:for-each>
		</items>
	</xsl:template>

	<xsl:template match="div[@class='audio-block pull-right clearfix']|div[@class='track']/div[@class='border-imitation']">
		<item downloaded="False">
      <xsl:variable name="episode_url" select="div[@class='br-info clearfix']/a/@href"/>
      <episode_id><xsl:value-of select="js:get_element_id(string($episode_url))"/></episode_id>
      <episode_url><xsl:value-of select="concat('http://www.radiorus.ru', $episode_url)"/></episode_url>
			<date><xsl:value-of select="js:convert_date(string(p[@class='date']))"/></date>
			<name><xsl:value-of select="normalize-space(h3)"/></name>
			<description><xsl:value-of select="normalize-space(div[@class='br-info clearfix']/div/div/p)"/></description>
			<img><xsl:value-of select="../div/div/a/img[@class='landscape']/@src"/></img>
			<audio><xsl:value-of select="div/@data-url"/></audio>
		</item>
		<xsl:for-each select="div[@class='track']">
			<xsl:apply-templates select="*"/>
		</xsl:for-each>
	</xsl:template>

</xsl:stylesheet>
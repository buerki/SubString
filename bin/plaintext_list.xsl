<?xml version="1.0" encoding="UTF-8"?>
<xsl:transform version="1.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method='text'/>

<xsl:template match="/">

	<xsl:for-each select="candidates/cand/occurs/ngram">
			<xsl:for-each select="w">
				<xsl:value-of select="@surface"/><xsl:text>·</xsl:text>
			</xsl:for-each>
		<xsl:text>	</xsl:text><xsl:value-of select="freq/@value"/><xsl:text>&#xa;</xsl:text>
	</xsl:for-each>
	
</xsl:template>
</xsl:transform>
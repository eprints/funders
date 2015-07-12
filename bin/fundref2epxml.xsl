<?xml version="1.0"?>

<!--

Download the funder taxonomy in RDF (zipped) from here:
http://data.elsevier.com/vocabulary/bulk/SciValFunders

xsltproc funder_taxonomy_to_ep3.xslt allFundRef.rdf

-->

<xsl:stylesheet
	version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns="http://eprints.org/ep2/data/2.0"
	xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 

	xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" 
	xmlns:dct="http://purl.org/dc/terms/" 
	xmlns:skos="http://www.w3.org/2004/02/skos/core#" 
	xmlns:skosxl="http://www.w3.org/2008/05/skos-xl#" 
	xmlns:svf="http://data.fundref.org/xml/schema/grant/grant-1.2/"
	xmlns:s="http://states.data/" 
	xml:base="http://data.elsevier.com/vocabulary/SciValFunders"

	exclude-result-prefixes="rdf dct skos skosxl svf s"
>

<xsl:output method="xml" indent="yes"></xsl:output>

<xsl:template match="text()"></xsl:template>

<xsl:template match="/">
<funders>
<xsl:apply-templates></xsl:apply-templates>
</funders>
</xsl:template>

<xsl:template match="/rdf:RDF/skos:Concept">
<funder>
<xsl:attribute name="id">
	<xsl:value-of select="@rdf:about"></xsl:value-of>
</xsl:attribute>
<source>
	<xsl:value-of select="@rdf:about"></xsl:value-of>
</source>
<database>http://www.crossref.org/fundref/</database>
<type>
	<xsl:value-of select="svf:fundingBodyType"></xsl:value-of>
</type>
<parents>
	<xsl:for-each select="skos:broader">
		<item>
			<xsl:value-of select="@rdf:resource"></xsl:value-of>
		</item>
	</xsl:for-each>
</parents>
<sub_type>
	<xsl:value-of select="svf:fundingBodySubType"></xsl:value-of>
</sub_type>
<name>
	<xsl:value-of select="skosxl:prefLabel/skosxl:Label/skosxl:literalForm"></xsl:value-of>
</name>
<alt_name>
	<xsl:for-each select="skosxl:altLabel/skosxl:Label/skosxl:literalForm">
		<item><xsl:value-of select="."></xsl:value-of></item>
	</xsl:for-each>
</alt_name>
<datestamp>
	<xsl:choose>
	<xsl:when test="dct:modified">
		<xsl:value-of select="substring(dct:modified,0,20)"></xsl:value-of>
	</xsl:when>
	<xsl:otherwise>
		<xsl:value-of select="substring(dct:created,0,20)"></xsl:value-of>
	</xsl:otherwise>
	</xsl:choose>
</datestamp>
<geoname>
	<xsl:value-of select="svf:country/@rdf:resource"></xsl:value-of>
</geoname>
<geoname_state>
	<xsl:value-of select="svf:state/@rdf:resource"></xsl:value-of>
</geoname_state>
</funder>
</xsl:template>

</xsl:stylesheet>

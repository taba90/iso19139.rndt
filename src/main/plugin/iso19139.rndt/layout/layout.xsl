<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:gmd="http://www.isotc211.org/2005/gmd" xmlns:gts="http://www.isotc211.org/2005/gts"
                xmlns:gco="http://www.isotc211.org/2005/gco" xmlns:gmx="http://www.isotc211.org/2005/gmx"
                xmlns:srv="http://www.isotc211.org/2005/srv" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                xmlns:gml="http://www.opengis.net/gml" xmlns:xlink="http://www.w3.org/1999/xlink"
                xmlns:gn="http://www.fao.org/geonetwork"
                xmlns:gn-fn-core="http://geonetwork-opensource.org/xsl/functions/core"
                xmlns:gn-fn-metadata="http://geonetwork-opensource.org/xsl/functions/metadata"
                xmlns:gn-fn-iso19139="http://geonetwork-opensource.org/xsl/functions/profiles/iso19139"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:exslt="http://exslt.org/common" exclude-result-prefixes="#all">

  <xsl:include href="utility-tpl.xsl"/>
  <xsl:include href="layout-custom-fields.xsl"/>
  <xsl:include href="layout-custom-fields-date.xsl"/>



  <!-- Visit all XML tree recursively -->
  <xsl:template mode="mode-iso19139" match="*|@*">
    <xsl:param name="schema" select="$schema" required="no"/>
    <xsl:param name="labels" select="$labels" required="no"/>

    <xsl:apply-templates mode="mode-iso19139" select=".">
      <xsl:with-param name="schema" select="$schema"/>
      <xsl:with-param name="labels" select="$labels"/>
    </xsl:apply-templates>
  </xsl:template>

  <!-- Codelists -->
  <xsl:template mode="mode-iso19139" priority="200"
                match="*[*/@codeList]">
    <xsl:param name="schema" select="$schema" required="no"/>
    <xsl:param name="labels" select="$labels" required="no"/>
    <xsl:param name="codelists" select="$codelists" required="no"/>
    <xsl:param name="overrideLabel" select="''" required="no"/>

    <xsl:variable name="elementName" select="name()"/>
    <xsl:variable name="xpath" select="gn-fn-metadata:getXPath(.)"/>
    <xsl:variable name="isoType" select="if (../@gco:isoType) then ../@gco:isoType else ''"/>

    <xsl:variable name="labelConfig">
      <xsl:choose>
        <xsl:when test="$overrideLabel != ''">
          <element>
            <label><xsl:value-of select="$overrideLabel"/></label>
          </element>
        </xsl:when>
        <xsl:otherwise>
          <xsl:copy-of select="gn-fn-metadata:getLabel($schema, name(), $labels, name(..), $isoType, $xpath)"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>

    <xsl:call-template name="render-element">
      <xsl:with-param name="label"
                      select="$labelConfig/*"/>
      <xsl:with-param name="value" select="*/@codeListValue"/>
      <xsl:with-param name="cls" select="local-name()"/>
      <xsl:with-param name="xpath" select="$xpath"/>
      <xsl:with-param name="type" select="gn-fn-iso19139:getCodeListType(name(), $editorConfig)"/>
      <xsl:with-param name="name"
                      select="concat(*/gn:element/@ref, '_codeListValue')"/>
      <xsl:with-param name="editInfo" select="*/gn:element"/>
      <xsl:with-param name="parentEditInfo" select="gn:element"/>
      <xsl:with-param name="listOfValues"
                      select="gn-fn-metadata:getCodeListValues($schema, name(*[@codeListValue]), $codelists, .)"/>
      <xsl:with-param name="isFirst" select="count(preceding-sibling::*[name() = $elementName]) = 0"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:function name="gn-fn-iso19139:getCodeListType" as="xs:string">
    <xsl:param name="name" as="xs:string"/>
    <xsl:param name="editorConfig" as="node()"/>

    <xsl:variable name="configType"
                  select="$editorConfig/editor/fields/for[@name = $name]/@use"/>

    <xsl:value-of select="if ($configType) then $configType else 'select'"/>
  </xsl:function>

  <!-- Template to display non existing element ie. geonet:child element
  of the metadocument. Display in editing mode only and if
  the editor mode is not flat mode. -->
  <xsl:template mode="mode-iso19139" match="gn:child" priority="2000">
    <xsl:param name="schema" select="$schema" required="no"/>
    <xsl:param name="labels" select="$labels" required="no"/>


    <xsl:variable name="name" select="concat(@prefix, ':', @name)"/>
    <xsl:variable name="flatModeException"
                  select="gn-fn-metadata:isFieldFlatModeException($viewConfig, $name,  name(..))"/>


    <xsl:if test="$name = 'gmd:descriptiveKeywords' and count(../gmd:descriptiveKeywords) = 0">
      <xsl:call-template name="addAllThesaurus">
        <xsl:with-param name="ref" select="../gn:element/@ref"/>
      </xsl:call-template>
    </xsl:if>

    <xsl:if test="$isEditing and
      (not($isFlatMode) or $flatModeException)">

      <xsl:variable name="directive"
                    select="gn-fn-metadata:getFieldAddDirective($editorConfig, $name)"/>
      <xsl:variable name="label"
                    select="gn-fn-metadata:getLabel($schema, $name, $labels, name(..), '', '')"/>


      <xsl:choose>
        <!-- Specifc case when adding a new keyword using the gn-thesaurus-selector
        in a view where descriptiveKeyword is a flat mode exception. In this case
        the "Add keyword" button will add a new descriptiveKeyword block if none exists
        and it will insert a keyword in the first descriptiveKeyword block (not referencing thesaurus)
        ie. free text keyword block.

        The goal here is to avoid to have multiple free text descriptiveKeyword sections.
        -->
        <xsl:when test="$flatModeException and $name = 'gmd:descriptiveKeywords'">
          <xsl:variable name="freeTextKeywordBlocks"
                        select="../gmd:descriptiveKeywords[not(*/gmd:thesaurusName)]"/>
          <xsl:variable name="isFreeTextKeywordBlockExist"
                        select="count($freeTextKeywordBlocks) > 0"/>
          <xsl:variable name="freeTextKeywordTarget"
                        select="if ($isFreeTextKeywordBlockExist) then $freeTextKeywordBlocks[1]/*/gn:child[@name = 'keyword'] else ."/>

          <xsl:variable name="directive" as="node()?">
            <xsl:for-each select="$directive">
              <xsl:copy>
                <xsl:copy-of select="@*"/>
                <directiveAttributes data-freekeyword-element-ref="{$freeTextKeywordTarget/../gn:element/@ref}"
                                     data-freekeyword-element-name="{concat($freeTextKeywordTarget/@prefix, ':', $freeTextKeywordTarget/@name)}">
                  <xsl:copy-of select="directiveAttributes/@*"/>
                </directiveAttributes>
              </xsl:copy>
            </xsl:for-each>
          </xsl:variable>

          <xsl:call-template name="render-element-to-add">
            <xsl:with-param name="label" select="$label/label"/>
            <xsl:with-param name="class" select="if ($label/class) then $label/class else ''"/>
            <xsl:with-param name="btnLabel" select="if ($label/btnLabel) then $label/btnLabel else ''"/>
            <xsl:with-param name="btnClass" select="if ($label/btnClass) then $label/btnClass else ''"/>
            <xsl:with-param name="directive" select="$directive"/>
            <xsl:with-param name="childEditInfo" select="."/>
            <xsl:with-param name="parentEditInfo" select="../gn:element"/>
            <xsl:with-param name="isFirst" select="count(preceding-sibling::*[name() = $name]) = 0"/>
          </xsl:call-template>
        </xsl:when>
        <xsl:otherwise>
          <xsl:call-template name="render-element-to-add">
            <xsl:with-param name="label" select="$label/label"/>
            <xsl:with-param name="class" select="if ($label/class) then $label/class else ''"/>
            <xsl:with-param name="btnLabel" select="if ($label/btnLabel) then $label/btnLabel else ''"/>
            <xsl:with-param name="btnClass" select="if ($label/btnClass) then $label/btnClass else ''"/>
            <xsl:with-param name="directive" select="$directive"/>
            <xsl:with-param name="childEditInfo" select="."/>
            <xsl:with-param name="parentEditInfo" select="../gn:element"/>
            <xsl:with-param name="isFirst" select="count(preceding-sibling::*[name() = $name]) = 0"/>
          </xsl:call-template>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:if>
  </xsl:template>

</xsl:stylesheet>

<?xml version='1.0' encoding='ISO-8859-1'?>

<!-- $Id$ -->

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    version="1.0">

  <xsl:output method="text"/>

  <!-- The libc model used for HLFS -->
  <xsl:param name="model" select="'glibc'"/>

  <!-- The kernel series used for HLFS -->
  <xsl:param name="kernel" select="'2.6'"/>

  <!-- Should we include a package manager? -->
  <xsl:param name="pkgmngt" select="'n'"/>

  <!-- The system for LFS: sysv of systemd -->
  <xsl:param name="revision" select="'sysv'"/>

  <xsl:template match="/">
    <xsl:apply-templates
         select="//varlistentry[(@condition=$model   or not(@condition)) and
                                (@revision=$revision or not(@revision))  and
                                (@vendor=$kernel     or not(@vendor))]
                      //para[contains(string(),'Download:')]"/>
    <xsl:if test="$pkgmngt='y'">
      <xsl:apply-templates
        select="document('packageManager.xml')//sect1[@id='package']//para"/>
    </xsl:if>
  </xsl:template>

  <xsl:template match="para">
      <xsl:call-template name="package_name">
        <xsl:with-param name="url" select="ulink/@url"/>
      </xsl:call-template>
  </xsl:template>

  <xsl:template name="package_name">
    <xsl:param name="url" select="'foo'"/>
    <xsl:variable name="sub-url" select="substring-after($url,'/')"/>
    <xsl:choose>
      <xsl:when test="contains($sub-url,'/') and
                      not(substring-after($sub-url,'/')='')">
        <xsl:call-template name="package_name">
          <xsl:with-param name="url" select="$sub-url"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:choose>
          <xsl:when test="contains($sub-url,'.patch')"/>
          <xsl:when test="contains($sub-url,'?')">
            <xsl:value-of select="substring-before($sub-url,'?')"/>
            <xsl:text>&#xA;</xsl:text>
          </xsl:when>
          <xsl:when test="contains($sub-url,'/')">
            <xsl:value-of select="substring-before($sub-url,'/')"/>
            <xsl:text>&#xA;</xsl:text>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="$sub-url"/>
            <xsl:text>&#xA;</xsl:text>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

</xsl:stylesheet>

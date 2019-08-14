<?xml version="1.0" encoding="ISO-8859-1"?>

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    version="1.0">

<!-- $Id$ -->

<!--===================================================================-->
  <!-- Localization in the form ll_CC.charmap@modifier (to be used in
       bash shell startup scripts). ll, CC, and charmap must be present:
       no way to use "C" or "POSIX". -->
  <xsl:param name="language" select="'en_US.UTF-8'"/>

  <!-- Break it in pieces -->
  <xsl:variable name="lang-ll">
    <xsl:copy-of select="substring-before($language,'_')"/>
  </xsl:variable>
  <xsl:variable name="lang-CC">
     <xsl:copy-of
            select="substring-before(substring-after($language,'_'),'.')"/>
  </xsl:variable>
  <xsl:variable name="lang-charmap">
    <xsl:choose>
      <xsl:when test="contains($language,'@')">
         <xsl:copy-of
               select="substring-before(substring-after($language,'.'),'@')"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:copy-of select="substring-after($language,'.')"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:variable name="lang-modifier">
    <xsl:choose>
      <xsl:when test="contains($language,'@')">
         <xsl:copy-of select="concat('@',substring-after($language,'@'))"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:copy-of select="''"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
<!-- end of language variables -->

<!--===================================================================-->
<!-- to be used at places where we need the domain- or host- name -->
  <xsl:param name="fqdn" select="'belgarath.example.org'"/>

<!-- make various useful variables -->
  <xsl:variable name="hostname" select="substring-before($fqdn,'.')"/>
  <xsl:variable name="domainname" select="substring-after($fqdn,'.')"/>
  <xsl:variable name="DOMAINNAME" select="translate($domainname,
        'abcdefghijklmnopqrstuvwxyz', 'ABCDEFGHIJKLMNOPQRSTUVWXYZ')"/>
<!-- end of host/domain name variables -->

<!--===================================================================-->
<!-- the main template: to be adjusted depending on the book -->
  <xsl:template match="replaceable">
    <xsl:choose>
<!-- When adding a user to a group, the book uses "username" in a replaceable
     tag. Replace by the user name only if not running as root -->
      <xsl:when test="contains(string(),'username') and $sudo='y'">
        <xsl:text>$USER</xsl:text>
      </xsl:when>
<!-- The next three entries are for gpm. I guess those settings are OK
     for a laptop or desktop. -->
      <xsl:when test="contains(string(),'yourprotocol')">
        <xsl:text>imps2</xsl:text>
      </xsl:when>
      <xsl:when test="contains(string(),'yourdevice')">
        <xsl:text>/dev/input/mice</xsl:text>
      </xsl:when>
      <xsl:when test="contains(string(),'additional options')"/>
<!-- the book has four fields for language. The language param is
     broken into four pieces above. We use the results here. -->
      <xsl:when test="contains(string(),'&lt;ll&gt;')">
        <xsl:copy-of select="$lang-ll"/>
      </xsl:when>
      <xsl:when test="contains(string(),'&lt;CC&gt;')">
        <xsl:copy-of select="$lang-CC"/>
      </xsl:when>
      <xsl:when test="contains(string(),'&lt;charmap&gt;')">
        <xsl:copy-of select="$lang-charmap"/>
      </xsl:when>
      <xsl:when test="contains(string(),'@modifier')">
        <xsl:copy-of select="$lang-modifier"/>
      </xsl:when>
<!-- At several places, the number of jobs is given as "N" in a replaceable
     tag. We either detect "N" alone or &lt;N&gt; Replace N with 4. -->
      <xsl:when test="contains(string(),'&lt;N&gt;') or string()='N'">
        <xsl:text>4</xsl:text>
      </xsl:when>
<!-- Mercurial config file uses user_name. Replace only if non root.
     Add a bogus mail field. That works for the proposed tests anyway. -->
      <xsl:when test="contains(string(),'user_name') and $sudo='y'">
        <xsl:text>$USER ${USER}@mail.bogus</xsl:text>
      </xsl:when>
<!-- Use the config for Gtk+3 as is -->
      <xsl:when test="ancestor::sect1[@id='gtk3']">
        <xsl:copy-of select="string()"/>
      </xsl:when>
<!-- Give 1Gb to fop. Hopefully, nobody has less RAM nowadays. -->
      <xsl:when test="contains(string(),'RAM_Installed')">
        <xsl:text>1024</xsl:text>
      </xsl:when>
<!-- for MIT-Kerberos config file -->
      <xsl:when test="string()='&lt;EXAMPLE.ORG&gt;'">
        <xsl:copy-of select="$DOMAINNAME"/>
      </xsl:when>
      <xsl:when test="string()='&lt;example.org&gt;'">
        <xsl:copy-of select="$domainname"/>
      </xsl:when>
      <xsl:when test="string()='&lt;belgarath.example.org&gt;'">
        <xsl:copy-of select="$fqdn"/>
      </xsl:when>
<!-- in this case, even root can be used -->
      <xsl:when test="string()='&lt;loginname&gt;'">
        <xsl:text>$USER</xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>**EDITME</xsl:text>
        <xsl:apply-templates/>
        <xsl:text>EDITME**</xsl:text>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="replaceable" mode="root">
    <xsl:apply-templates select="."/>
  </xsl:template>

</xsl:stylesheet>

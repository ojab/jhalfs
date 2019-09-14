<?xml version="1.0" encoding="ISO-8859-1"?>
<!DOCTYPE stylesheet [
<!ENTITY detect-config "contains(string($current-instr),'useradd') or
                        contains(string($current-instr),'groupadd') or
                        contains(string($current-instr),'usermod') or
                        contains(string($current-instr),'icon-cache') or
                        contains(string($current-instr),'desktop-database') or
                        contains(string($current-instr),'compile-schemas') or
                        contains(string($current-instr),'query-loaders') or
                        contains(string($current-instr),'pam.d') or
                        contains(string($current-instr),'/opt/rustc') or
                        contains(string($current-instr),'query-immodules')">
]>

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    version="1.0">

<!-- $Id$ -->

  <xsl:template name="process-install">
    <xsl:param name="instruction-tree"/>
    <xsl:param name="want-stats"/>
    <xsl:param name="root-seen"/>
    <xsl:param name="install-seen"/>
    <xsl:param name="test-seen"/>
    <xsl:param name="doc-seen"/>

<!-- Isolate the current instruction -->
    <xsl:variable name="current-instr" select="$instruction-tree[1]"/>

    <xsl:choose>
<!--============================================================-->
<!-- First, if we have an empty tree, close everything and exit -->
      <xsl:when test="not($current-instr)">
        <xsl:if test="$install-seen">
          <xsl:call-template name="end-install"/>
        </xsl:if>
        <xsl:if test="$root-seen">
          <xsl:call-template name="end-root"/>
        </xsl:if>
        <xsl:if test="$doc-seen and not($root-seen)">
          <xsl:call-template name="end-doc">
            <xsl:with-param name="want-stats" select="$want-stats"/>
          </xsl:call-template>
        </xsl:if>
        <xsl:if test="$test-seen">
          <xsl:call-template name="end-test">
            <xsl:with-param name="want-stats" select="$want-stats"/>
          </xsl:call-template>
        </xsl:if>
      </xsl:when><!-- end empty tree -->
<!--============================================================-->
      <xsl:when test="$current-instr[@role='root' and @remap='test']">
        <xsl:if test="$install-seen">
          <xsl:call-template name="end-install"/>
        </xsl:if>
        <xsl:if test="$root-seen">
          <xsl:call-template name="end-root"/>
        </xsl:if>
        <xsl:if test="$doc-seen and not($root-seen)">
          <xsl:call-template name="end-doc">
            <xsl:with-param name="want-stats" select="$want-stats"/>
          </xsl:call-template>
        </xsl:if>
        <xsl:if test="not($test-seen)">
          <xsl:call-template name="begin-test">
            <xsl:with-param name="want-stats" select="$want-stats"/>
          </xsl:call-template>
        </xsl:if>
        <xsl:call-template name="begin-root"/>
<!-- We first apply mode="root" templates, and save the result in a variable -->
        <xsl:variable name="processed-instr">
          <xsl:apply-templates select="$current-instr" mode="root"/>
        </xsl:variable>
<!-- We then process as a test instruction -->
        <xsl:call-template name="process-test">
          <xsl:with-param name="test-instr" select="$processed-instr"/>
          <xsl:with-param name="want-stats" select="$want-stats"/>
        </xsl:call-template>
        <xsl:call-template name="process-install">
          <xsl:with-param
             name="instruction-tree"
             select="$instruction-tree[position()>1]"/>
          <xsl:with-param name="want-stats" select="$want-stats"/>
          <xsl:with-param name="root-seen" select="boolean(1)"/>
          <xsl:with-param name="install-seen" select="boolean(0)"/>
          <xsl:with-param name="test-seen" select="boolean(1)"/>
          <xsl:with-param name="doc-seen" select="boolean(0)"/>
        </xsl:call-template>
      </xsl:when><!-- end role="root" and remap="test" -->
<!--============================================================-->
      <xsl:when test="$current-instr[@role='root' and @remap='doc']">
        <xsl:if test="$test-seen">
          <xsl:call-template name="end-test">
            <xsl:with-param name="want-stats" select="$want-stats"/>
          </xsl:call-template>
        </xsl:if>
        <xsl:if test="$doc-seen and not($root-seen)">
          <xsl:call-template name="end-doc">
            <xsl:with-param name="want-stats" select="$want-stats"/>
          </xsl:call-template>
        </xsl:if>
        <xsl:if test="not($root-seen)">
          <xsl:call-template name="begin-root"/>
        </xsl:if>
        <xsl:if test="not($install-seen)">
          <xsl:call-template name="begin-install"/>
        </xsl:if>
<!-- We first apply mode="install" templates, and save the result in a
     variable -->
        <xsl:variable name="processed-instr">
          <xsl:apply-templates select="$current-instr" mode="install"/>
        </xsl:variable>
<!-- Then comment it out -->
        <xsl:call-template name="output-comment-out">
          <xsl:with-param name="out-string" select="$processed-instr"/>
        </xsl:call-template>
<!-- The above template ends with a commented line, so that if end-install
     adds a closing single quote, it will not be seen. Add a CR to prevent
     that -->
        <xsl:text>
</xsl:text>
        <xsl:call-template name="process-install">
          <xsl:with-param
             name="instruction-tree"
             select="$instruction-tree[position()>1]"/>
          <xsl:with-param name="want-stats" select="$want-stats"/>
          <xsl:with-param name="root-seen" select="boolean(1)"/>
          <xsl:with-param name="install-seen" select="boolean(1)"/>
          <xsl:with-param name="test-seen" select="boolean(0)"/>
          <xsl:with-param name="doc-seen" select="boolean(1)"/>
        </xsl:call-template>
      </xsl:when><!-- end role="root" and remap="doc" -->
<!--============================================================-->
      <xsl:when test="$current-instr[@role='root']">
<!-- We have two cases, depending on the content: either a config instruction,
     that we do not record with porg (first case below), or a true install
     instruction (otherwise below) -->
        <xsl:choose>
<!--____________________________________________________________ -->
          <xsl:when test="&detect-config;">
            <xsl:if test="$install-seen">
              <xsl:call-template name="end-install"/>
            </xsl:if>
            <xsl:if test="$test-seen">
              <xsl:call-template name="end-test">
                <xsl:with-param name="want-stats" select="$want-stats"/>
              </xsl:call-template>
            </xsl:if>
            <xsl:if test="$doc-seen and not($root-seen)">
              <xsl:call-template name="end-doc">
                <xsl:with-param name="want-stats" select="$want-stats"/>
              </xsl:call-template>
            </xsl:if>
            <xsl:if test="not($root-seen)">
              <xsl:call-template name="begin-root"/>
            </xsl:if>
            <xsl:apply-templates select="$current-instr" mode="root"/>
            <xsl:call-template name="process-install">
              <xsl:with-param
                 name="instruction-tree"
                 select="$instruction-tree[position()>1]"/>
              <xsl:with-param name="want-stats" select="$want-stats"/>
              <xsl:with-param name="root-seen" select="boolean(1)"/>
              <xsl:with-param name="install-seen" select="boolean(0)"/>
              <xsl:with-param name="test-seen" select="boolean(0)"/>
              <xsl:with-param name="doc-seen" select="boolean(0)"/>
            </xsl:call-template>
          </xsl:when><!-- end config as root -->
<!--____________________________________________________________ -->
          <xsl:otherwise><!-- we have a true install instruction -->
            <xsl:if test="$test-seen">
              <xsl:call-template name="end-test">
                <xsl:with-param name="want-stats" select="$want-stats"/>
              </xsl:call-template>
            </xsl:if>
            <xsl:if test="$doc-seen and not($root-seen)">
              <xsl:call-template name="end-doc">
                <xsl:with-param name="want-stats" select="$want-stats"/>
              </xsl:call-template>
            </xsl:if>
            <xsl:if test="$want-stats and not($install-seen)">
              <xsl:if test="$root-seen">
                <xsl:call-template name="end-root"/>
              </xsl:if>
              <xsl:text>
echo Time before install: ${SECONDS} >> $INFOLOG</xsl:text>
              <xsl:apply-templates
                         select="$instruction-tree[@role='root']/userinput"
                         mode="destdir"/>
              <xsl:text>

echo Time after install: ${SECONDS} >> $INFOLOG
echo Size after install: $(sudo du -skx --exclude home /) >> $INFOLOG
</xsl:text>
              <xsl:if test="$root-seen">
                <xsl:call-template name="begin-root"/>
              </xsl:if>
            </xsl:if>
            <xsl:if test="not($root-seen)">
              <xsl:call-template name="begin-root"/>
            </xsl:if>
            <xsl:if test="not($install-seen)">
              <xsl:call-template name="begin-install"/>
            </xsl:if>
            <xsl:apply-templates select="$current-instr" mode="install"/>
            <xsl:call-template name="process-install">
              <xsl:with-param
                 name="instruction-tree"
                 select="$instruction-tree[position()>1]"/>
              <xsl:with-param name="want-stats" select="$want-stats"/>
              <xsl:with-param name="root-seen" select="boolean(1)"/>
              <xsl:with-param name="install-seen" select="boolean(1)"/>
              <xsl:with-param name="test-seen" select="boolean(0)"/>
              <xsl:with-param name="doc-seen" select="boolean(0)"/>
            </xsl:call-template>
          </xsl:otherwise><!-- end true install instruction -->
<!--____________________________________________________________ -->
        </xsl:choose>
      </xsl:when><!-- role="root" and no remap -->
<!--============================================================-->
      <xsl:when test="$current-instr[@remap='test'] or
                      $current-instr/self::command">
        <xsl:if test="$install-seen">
          <xsl:call-template name="end-install"/>
        </xsl:if>
        <xsl:if test="$root-seen">
          <xsl:call-template name="end-root"/>
        </xsl:if>
        <xsl:if test="$doc-seen and not($root-seen)">
          <xsl:call-template name="end-doc">
            <xsl:with-param name="want-stats" select="$want-stats"/>
          </xsl:call-template>
        </xsl:if>
        <xsl:if test="not($test-seen)">
          <xsl:if test="not($doc-seen)">
            <xsl:call-template name="end-make">
              <xsl:with-param name="want-stats" select="$want-stats"/>
            </xsl:call-template>
          </xsl:if>
          <xsl:call-template name="begin-test">
            <xsl:with-param name="want-stats" select="$want-stats"/>
          </xsl:call-template>
        </xsl:if>
<!-- We first apply normal templates, and save the result in a variable -->
        <xsl:variable name="processed-instr">
          <xsl:apply-templates select="$current-instr"/>
        </xsl:variable>
<!-- We then process as a test instruction -->
        <xsl:call-template name="process-test">
          <xsl:with-param name="test-instr" select="$processed-instr"/>
          <xsl:with-param name="want-stats" select="$want-stats"/>
        </xsl:call-template>
        <xsl:call-template name="process-install">
          <xsl:with-param
             name="instruction-tree"
             select="$instruction-tree[position()>1]"/>
          <xsl:with-param name="want-stats" select="$want-stats"/>
          <xsl:with-param name="root-seen" select="boolean(0)"/>
          <xsl:with-param name="install-seen" select="boolean(0)"/>
          <xsl:with-param name="test-seen" select="boolean(1)"/>
          <xsl:with-param name="doc-seen" select="boolean(0)"/>
        </xsl:call-template>
      </xsl:when><!-- end no role, remap=test -->
<!--============================================================-->
      <xsl:when test="$current-instr[@remap='doc']">
        <xsl:if test="$install-seen">
          <xsl:call-template name="end-install"/>
        </xsl:if>
        <xsl:if test="$root-seen">
          <xsl:call-template name="end-root"/>
        </xsl:if>
        <xsl:if test="$test-seen">
          <xsl:call-template name="end-test">
            <xsl:with-param name="want-stats" select="$want-stats"/>
          </xsl:call-template>
        </xsl:if>
        <xsl:if test="not($doc-seen) or $root-seen">
          <xsl:if test="not($test-seen) and not($root-seen)">
            <xsl:call-template name="end-make">
              <xsl:with-param name="want-stats" select="$want-stats"/>
            </xsl:call-template>
          </xsl:if>
          <xsl:call-template name="begin-doc">
            <xsl:with-param name="want-stats" select="$want-stats"/>
          </xsl:call-template>
        </xsl:if>
<!-- We first apply normal templates, and save the result in a variable -->
        <xsl:variable name="processed-instr">
          <xsl:apply-templates select="$current-instr"/>
        </xsl:variable>
<!-- We then process as a doc instruction -->
        <xsl:call-template name="process-doc">
          <xsl:with-param name="doc-instr" select="$processed-instr"/>
          <xsl:with-param name="want-stats" select="$want-stats"/>
        </xsl:call-template>
        <xsl:call-template name="process-install">
          <xsl:with-param
             name="instruction-tree"
             select="$instruction-tree[position()>1]"/>
          <xsl:with-param name="want-stats" select="$want-stats"/>
          <xsl:with-param name="root-seen" select="boolean(0)"/>
          <xsl:with-param name="install-seen" select="boolean(0)"/>
          <xsl:with-param name="test-seen" select="boolean(0)"/>
          <xsl:with-param name="doc-seen" select="boolean(1)"/>
        </xsl:call-template>
      </xsl:when><!-- no role, remap="doc" -->
<!--============================================================-->
      <xsl:otherwise><!-- no role no remap -->
        <xsl:if test="$install-seen">
          <xsl:call-template name="end-install"/>
        </xsl:if>
        <xsl:if test="$root-seen">
          <xsl:call-template name="end-root"/>
        </xsl:if>
        <xsl:if test="$doc-seen and not($root-seen)">
          <xsl:call-template name="end-doc">
            <xsl:with-param name="want-stats" select="$want-stats"/>
          </xsl:call-template>
        </xsl:if>
        <xsl:if test="$test-seen">
          <xsl:call-template name="end-test">
            <xsl:with-param name="want-stats" select="$want-stats"/>
          </xsl:call-template>
        </xsl:if>
        <xsl:apply-templates select="$current-instr"/>
        <xsl:call-template name="process-install">
          <xsl:with-param
             name="instruction-tree"
             select="$instruction-tree[position()>1]"/>
          <xsl:with-param name="want-stats" select="$want-stats"/>
          <xsl:with-param name="root-seen" select="boolean(0)"/>
          <xsl:with-param name="install-seen" select="boolean(0)"/>
          <xsl:with-param name="test-seen" select="boolean(0)"/>
          <xsl:with-param name="doc-seen" select="boolean(0)"/>
        </xsl:call-template>
      </xsl:otherwise><!-- no role, no remap -->
<!--============================================================-->
    </xsl:choose>
  </xsl:template>

  <xsl:template match="userinput" mode="install">
    <xsl:text>
</xsl:text>
    <xsl:call-template name="output-install">
      <xsl:with-param name="out-string" select="string()"/>
    </xsl:call-template>
  </xsl:template>

<!-- userinput templates for mode="root" and normal are in scripts.xsl -->

  <xsl:template name="process-test">
    <xsl:param name="test-instr"/>
    <xsl:param name="want-stats"/>
    <xsl:choose>
      <!-- the string may begin with a linefeed -->
      <xsl:when test="substring($test-instr,1,1)='&#xA;'">
        <xsl:text>
</xsl:text>
        <xsl:call-template name="process-test">
          <xsl:with-param name="test-instr"
                          select="substring-after($test-instr,'&#xA;')"/>
          <xsl:with-param name="want-stats" select="$want-stats"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:when test="contains($test-instr,'&#xA;')">
        <xsl:call-template name="process-test">
          <xsl:with-param name="test-instr"
                          select="substring-before($test-instr,'&#xA;')"/>
          <xsl:with-param name="want-stats" select="$want-stats"/>
        </xsl:call-template>
        <xsl:text>
</xsl:text>
        <xsl:call-template name="process-test">
          <xsl:with-param name="test-instr"
                          select="substring-after($test-instr,'&#xA;')"/>
          <xsl:with-param name="want-stats" select="$want-stats"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:if test="not($want-stats)">
          <xsl:text>#</xsl:text>
        </xsl:if>
        <xsl:choose>
          <xsl:when test="contains($test-instr,'make')
                  and not(contains($test-instr,'make -k'))">
            <xsl:copy-of select="substring-before($test-instr,'make')"/>
            <xsl:text>make -k</xsl:text>
            <xsl:copy-of select="substring-after($test-instr,'make')"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:copy-of select="$test-instr"/>
          </xsl:otherwise>
        </xsl:choose>
        <xsl:if test="substring($test-instr,
                                string-length($test-instr),
                                1)!='\'">
          <xsl:if test="$want-stats">
            <xsl:text> &gt;&gt; $TESTLOG 2>&amp;1</xsl:text>
          </xsl:if>
          <xsl:text> || true</xsl:text>
        </xsl:if>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="process-doc">
    <xsl:param name="doc-instr"/>
    <xsl:param name="want-stats"/>
    <xsl:choose>
      <xsl:when test="$want-stats">
        <xsl:copy-of select="$doc-instr"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:call-template name="output-comment-out">
          <xsl:with-param name="out-string" select="$doc-instr"/>
        </xsl:call-template>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="output-comment-out">
<!-- Output instructions with each line commented out. -->
    <xsl:param name="out-string"/>
    <xsl:choose>
      <!-- the string may begin with a linefeed -->
      <xsl:when test="substring($out-string,1,1)='&#xA;'">
        <xsl:text>
</xsl:text>
        <xsl:call-template name="output-comment-out">
          <xsl:with-param name="out-string"
                          select="substring-after($out-string,'&#xA;')"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:when test="contains($out-string,'&#xA;')">
        <xsl:text>#</xsl:text>
        <xsl:copy-of select="substring-before($out-string,'&#xA;')"/>
        <xsl:text>
</xsl:text>
        <xsl:call-template name="output-comment-out">
          <xsl:with-param name="out-string"
                          select="substring-after($out-string,'&#xA;')"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>#</xsl:text>
        <xsl:copy-of select="$out-string"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="end-make">
    <xsl:param name="want-stats"/>
    <xsl:if test="$want-stats">
      <xsl:text>

echo Time after make: ${SECONDS} >> $INFOLOG
echo Size after make: $(sudo du -skx --exclude home /) >> $INFOLOG</xsl:text>
    </xsl:if>
  </xsl:template>

  <xsl:template name="begin-doc">
    <xsl:param name="want-stats"/>
    <xsl:if test="$want-stats">
      <xsl:text>
echo Time before doc: ${SECONDS} >> $INFOLOG
</xsl:text>
    </xsl:if>
  </xsl:template>

  <xsl:template name="begin-test">
    <xsl:param name="want-stats"/>
    <xsl:if test="$want-stats">
      <xsl:text>
echo Time before test: ${SECONDS} >> $INFOLOG
</xsl:text>
    </xsl:if>
  </xsl:template>

  <xsl:template name="begin-root">
    <xsl:if test="$sudo='y'">
      <xsl:text>
sudo -E sh &lt;&lt; ROOT_EOF</xsl:text>
    </xsl:if>
  </xsl:template>

  <xsl:template name="begin-install">
    <xsl:if test="$wrap-install = 'y'">
      <xsl:text>
if [ -r "$JH_PACK_INSTALL" ]; then
  source $JH_PACK_INSTALL
  export -f wrapInstall
  export -f packInstall
fi
wrapInstall '</xsl:text>
    </xsl:if>
  </xsl:template>

  <xsl:template name="end-doc">
    <xsl:param name="want-stats"/>
    <xsl:if test="$want-stats">
      <xsl:text>

echo Time after doc: ${SECONDS} >> $INFOLOG
echo Size after doc: $(sudo du -skx --exclude home /) >> $INFOLOG</xsl:text>
    </xsl:if>
  </xsl:template>

  <xsl:template name="end-test">
    <xsl:param name="want-stats"/>
    <xsl:if test="$want-stats">
      <xsl:text>

echo Time after test: ${SECONDS} >> $INFOLOG
echo Size after test: $(sudo du -skx --exclude home /) >> $INFOLOG</xsl:text>
    </xsl:if>
  </xsl:template>

  <xsl:template name="end-root">
    <xsl:if test="$sudo='y'">
      <xsl:text>
ROOT_EOF</xsl:text>
    </xsl:if>
  </xsl:template>

  <xsl:template name="end-install">
    <xsl:if test="$del-la-files = 'y'">
      <xsl:call-template name="output-root">
        <xsl:with-param name="out-string" select="$la-files-instr"/>
      </xsl:call-template>
    </xsl:if>
    <xsl:if test="$wrap-install = 'y'">
      <xsl:text>'&#xA;packInstall</xsl:text>
    </xsl:if>
  </xsl:template>

  <xsl:template name="output-install">
    <xsl:param name="out-string" select="''"/>
    <xsl:choose>
      <xsl:when test="starts-with($out-string, 'make ') or
                      contains($out-string,' make ') or
                      contains($out-string,'&#xA;make')">
        <xsl:call-template name="output-install">
          <xsl:with-param
               name="out-string"
               select="substring-before($out-string,'make ')"/>
        </xsl:call-template>
        <xsl:text>make -j1 </xsl:text>
        <xsl:call-template name="output-install">
          <xsl:with-param
               name="out-string"
               select="substring-after($out-string,'make ')"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:when test="contains($out-string,string($APOS))
                      and $wrap-install = 'y'">
        <xsl:call-template name="output-root">
          <xsl:with-param
               name="out-string"
               select="substring-before($out-string,string($APOS))"/>
        </xsl:call-template>
        <xsl:text>'\''</xsl:text>
        <xsl:call-template name="output-install">
          <xsl:with-param name="out-string"
                          select="substring-after($out-string,string($APOS))"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:call-template name="output-root">
          <xsl:with-param name="out-string" select="$out-string"/>
        </xsl:call-template>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

</xsl:stylesheet>

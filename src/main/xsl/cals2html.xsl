<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl" 
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:els="http://www.lefebvre-sarrut.eu/ns/els"
  xmlns:xslLib="http://www.lefebvre-sarrut.eu/ns/els/xslLib"
  xmlns:cals="-//OASIS//DTD XML Exchange Table Model 19990315//EN"
  xmlns:html="http://www.w3.org/1999/xhtml"
  xmlns:saxon="http://saxon.sf.net/"
  xmlns="http://www.w3.org/1999/xhtml"
  xpath-default-namespace="-//OASIS//DTD XML Exchange Table Model 19990315//EN"
  exclude-result-prefixes="#all" 
  extension-element-prefixes="xd"
  >
  
  <xsl:import href="els-common.xsl"/>
  
  <!--Paramètres (surchargeable lorque cette xsl est appelée en xsl:import)-->
  <xsl:param name="p-compute-column-width-within-colgroup" select="true()" as="xs:boolean"/>
  <!--If the number of columns is greater than g-nb-cols-max-before-font-reduction then the font needs to be reduced-->
  <xsl:param name="g-nb-cols-max-before-font-reduction" select="8" as="xs:integer"/>
  <xsl:param name="g-nb-cols-max-before-large-font-reduction" select="14" as="xs:integer"/>
  <xsl:param name="cals_default-colsep" select="'def-col'" />
  <xsl:param name="cals_default-rowsep" select="'def-row'" />
  <xsl:param name="cals_default-align" select="'LEFT'" />
  <xsl:param name="cals_default-valign" select="'BOTTOM'" />

  <!--==============================================================================================================================-->
  <!-- INIT -->
  <!--==============================================================================================================================-->
  
  <xsl:template match="/">
    <xsl:apply-templates select="/" mode="xslLib:cals2html"/>
  </xsl:template>
  
  <!--==============================================================================================================================-->
  <!-- MAIN -->
  <!--==============================================================================================================================-->
  
  <!-- héritage de rowsep -->
  <!-- si @rowsep pas défini alors héritage précédent -->
  <!-- sinon valeur de @rowsep -->
  <!-- point d'entrée du module TABLE -->
  <!-- MODEL : table ::= title, tgroup+ -->
  <xsl:template match="table" mode="xslLib:cals2html">
    <!-- on n'applique les templates qu'à tgroup, car c'est lui qui construit le tableau HTML et qui va chercher les éléments nécessaire hors du tgroup.
    Ainsi, les footnote seront traités par le template tgroup, on ne doit donc pas les traiter à ce niveau 
    NB : https://www.oasis-open.org/specs/tm9901.html#AEN282 : "All tgroups of a table shall have the same width, so the table frame can surround them uniformly"
      => ajout d'un tableau englobeur pour assurer cela (CHAINEXML-872) -->
    <div class="table blocTableau{if (normalize-space(@tabstyle)) then (concat(' ', @tabstyle))  else ()}">
      <xsl:apply-templates select="@id" mode="#current"/>
      <xsl:apply-templates mode="#current">
        <xsl:with-param name="colsep" select="(@colsep, $cals_default-colsep)[1]"/>
        <xsl:with-param name="rowsep" select="(@rowsep, $cals_default-rowsep)[1]"/>
        <xsl:with-param name="align" select="(@align, $cals_default-align)[1]"/>
        <xsl:with-param name="valign" select="(@valign, $cals_default-valign)[1]"/>
      </xsl:apply-templates>
    </div>
  </xsl:template>
  
  <xsl:template match="@id" mode="xslLib:cals2html">
    <xsl:copy copy-namespaces="no"/>
  </xsl:template>
  
  <!--
    <xd:desc>on ne génère pas d'élément div, car le titre est traité par la XSLT qui traite les tables CALS : on le met dans un élément caption, qui
      ne doit pas contenir de div</xd:desc>
  </-->
  <xsl:template match="table/titre | table/ttab | table/sttab" mode="xslLib:cals2html">
    <div class="{local-name(.)}">
      <xsl:apply-templates  mode="#current" />
    </div>
  </xsl:template>

  <!--<xsl:template match="titre|ttab|sttab" mode="cals2html">
    <!-\- do nothing all has been put in html:table/html:caption element -\->
    <!-\- no op -\-> 
  </xsl:template>-->

  <xsl:template match="caption" mode="xslLib:cals2html">
    <!-- do nothing all has been put in html:table/html:caption element -->
    <!-- no op --> 
  </xsl:template>
  
  <!-- veritable structure de tableau -->
  <!-- MODEL : tgroup ::= colspec+, thead?, tbody-->
  <xsl:template match="tgroup" mode="xslLib:cals2html">
    <xsl:param name="rowsep" />
    <xsl:param name="colsep" />
    <xsl:param name="align" />
    <xsl:param name="valign" />
    <table>
      <xsl:attribute name="class">
        <xsl:value-of select="concat('tgroup', ' ')" />
        <xsl:if test="position() = 1">
          <xsl:value-of select="concat('first', ' ')" />  
        </xsl:if>
        <xsl:value-of select="concat('cals_cals', ' ')" />
        <xsl:value-of select="lower-case(concat('cals_frame', ../@frame, ' '))" />
        <xsl:value-of select="lower-case(concat('cals_orient', ../@orient, ' '))" />
        <!--fixme-->
        <xsl:choose>
          <xsl:when test="not(../@tabstyle) or ends-with(../@tabstyle, 'PY2')">
            <xsl:value-of select="'full_width_table '" />
          </xsl:when>
          <xsl:otherwise>
            <!-- ends-with(@tabstyle, 'PY1') -->
            <xsl:value-of select="'partial_width_table '" />
          </xsl:otherwise>
        </xsl:choose>
      </xsl:attribute>
      <xsl:if test="@bgcolor">
        <xsl:attribute name="style" select="concat('background-color:',@bgcolor)"/>
      </xsl:if>
      <!--<xsl:if test="../titre|../ttab|../sttab">
        <caption>
          <xsl:apply-templates select="../titre|../ttab|../sttab" mode="#current" />
        </caption>
      </xsl:if>-->
      <xsl:if test="$p-compute-column-width-within-colgroup">
        <colgroup>
          <xsl:variable name="total-colwidth-sum">
            <xsl:call-template name="cals_sum-colwidths">
              <xsl:with-param name="col-list" select="colspec" />
            </xsl:call-template>
          </xsl:variable>
          <xsl:for-each select="colspec">
            <xsl:variable name="current-colwidth">
              <xsl:call-template name="cals_sum-colwidths">
                <xsl:with-param name="col-list" select="." />
              </xsl:call-template>
            </xsl:variable>
            <col style="width:{concat(round((number(replace($current-colwidth,'\*','')) div  $total-colwidth-sum)*100), '%;')}"/>
          </xsl:for-each>
        </colgroup>
      </xsl:if>
      <xsl:if test="normalize-space(@cols)!='' and not(normalize-space(@cols) castable as xs:integer)">
        <xsl:message terminate="yes">@cols="<xsl:value-of select="@cols"/>" n'est pas un entier</xsl:message>
      </xsl:if>
      <xsl:apply-templates mode="xslLib:cals2html" select="thead">
        <xsl:with-param name="colsep" select="(@colsep, $colsep)[1]"/>
        <xsl:with-param name="rowsep" select="(@rowsep, $rowsep)[1]"/>
        <xsl:with-param name="align" select="(@align, $align)[1]"/>
        <xsl:with-param name="valign" select="(@valign, $valign)[1]"/>
        <xsl:with-param name="nb-cols" select="@cols[. castable as xs:integer]" tunnel="yes" />
      </xsl:apply-templates>
      <xsl:if test="ancestor::table[1]/footnote | ancestor::table[1]/tblNote | tfoot">
        <tfoot>
          <xsl:apply-templates select="tfoot" mode="#current" >
            <xsl:with-param name="colsep" select="(@colsep, $colsep)[1]"/>
            <xsl:with-param name="rowsep" select="(@rowsep, $rowsep)[1]"/>
            <xsl:with-param name="align" select="(@align, $align)[1]"/>
            <xsl:with-param name="valign" select="(@valign, $valign)[1]"/>
            <xsl:with-param name="nb-cols" select="@cols[. castable as xs:integer]" tunnel="yes" />
          </xsl:apply-templates>
          <xsl:if test="ancestor::table[1]/footnote | ancestor::table[1]/tblNote">
            <tr>
              <td colspan="{count(colspec)}">
                <!--NOTE DE TABLEAU format BU (?)-->
                <xsl:if test="ancestor::table[1]/footnote">
                  <p>
                    <strong>
                      <!-- TODO waiting library ... xsl:value-of select="concat(concat('NOTE', efl:plural(count(ancestor::TABLE/footnote))), '&#xA0;: ')"/-->
                      <xsl:value-of select="concat(concat('NOTE', count(ancestor::table[1]/footnote)), '&#xA0;: ')"/>
                    </strong>
                  </p>
                  <xsl:apply-templates mode="xslLib:cals2html" select="ancestor::table[1]/footnote">
                    <xsl:with-param name="colsep" select="(@colsep, $colsep)[1]"/>
                    <xsl:with-param name="rowsep" select="(@rowsep, $rowsep)[1]"/>
                    <xsl:with-param name="align" select="(@align, $align)[1]"/>
                    <xsl:with-param name="valign" select="(@valign, $valign)[1]"/>
                  </xsl:apply-templates>
                </xsl:if>
                <!--NOTE DE TABLEAU format chaine XML-->
                <xsl:if test="ancestor::table[1]/tblNote">
                  <!--<p>
                    <strong>
                      <xsl:value-of select="if (count(ancestor::table[1]/tblNote/note) = 1) then ('NOTE')  else ('NOTES')"/>
                      <xsl:text>&#xA0;:</xsl:text>
                    </strong>
                  </p>-->
                  <xsl:apply-templates select="ancestor::table[1]/tblNote" mode="xslLib:cals2html">
                    <!--<xsl:with-param name="colsep" select="(@colsep, $colsep)[1]"/>
                    <xsl:with-param name="rowsep" select="(@rowsep, $rowsep)[1]"/>
                    <xsl:with-param name="align" select="(@align, $align)[1]"/>
                    <xsl:with-param name="valign" select="(@valign, $valign)[1]"/>-->
                  </xsl:apply-templates>
                </xsl:if>
              </td>
            </tr>
          </xsl:if>
        </tfoot>
      </xsl:if>
      <xsl:apply-templates select="* except (thead, tfoot) (:head et foot traité explicitement:)" mode="xslLib:cals2html">
        <xsl:with-param name="colsep" select="(@colsep, $colsep)[1]"/>
        <xsl:with-param name="rowsep" select="(@rowsep, $rowsep)[1]"/>
        <xsl:with-param name="align" select="(@align, $align)[1]"/>
        <xsl:with-param name="valign" select="(@valign, $valign)[1]"/>
        <xsl:with-param name="nb-cols" select="@cols" tunnel="yes" />
      </xsl:apply-templates>
    </table>
    <!--LEGENDE sorti du tableau -->
    <xsl:apply-templates select="ancestor::table[1]/legende" mode="#current" />
  </xsl:template>
  
  <!-- entete de tableau -->
  <!-- MODEL : thead ::= colspec*,row+ -->
  <xsl:template match="thead" mode="xslLib:cals2html">
    <xsl:param name="colsep" />
    <xsl:param name="rowsep" />
    <xsl:param name="align" />
    <xsl:param name="valign" />
    <thead>
      <xsl:apply-templates mode="#current">
        <xsl:with-param name="colsep" select="(@colsep, $colsep)[1]"/>
        <xsl:with-param name="rowsep" select="(@rowsep, $rowsep)[1]"/>
        <xsl:with-param name="align" select="(@align, $align)[1]"/>
        <xsl:with-param name="valign" select="(@valign, $valign)[1]"/>
      </xsl:apply-templates>
    </thead>
  </xsl:template>
  
  <xsl:template match="colspec" mode="xslLib:cals2html">
    <!-- no op -->
  </xsl:template>
  
  <xsl:template match="spanspec" mode="xslLib:cals2html">
    <!-- no op -->
  </xsl:template>
  
  <!-- pied de tableau (PAS UTILISÉ DANS LE MODÈLE UTILISÉ POUR PMT) -->
  <!-- MODEL : tfoot ::= colspec*,row+ -->
  <xsl:template match="tfoot" mode="xslLib:cals2html">
    <xsl:param name="colsep" />
    <xsl:param name="rowsep" />
    <xsl:param name="align" />
    <xsl:param name="valign" />
    <xsl:apply-templates select="*" mode="#current">
      <xsl:with-param name="colsep" select="(@colsep, $colsep)[1]"/>
      <xsl:with-param name="rowsep" select="(@rowsep, $rowsep)[1]"/>
      <xsl:with-param name="align" select="(@align, $align)[1]"/>
      <xsl:with-param name="valign" select="(@valign, $valign)[1]"/>
    </xsl:apply-templates>
  </xsl:template>
  
  <!-- corps de tableau -->
  <!-- MODEL : tbody ::= row+-->
  <xsl:template match="tbody" mode="xslLib:cals2html">
    <xsl:param name="colsep" />
    <xsl:param name="rowsep" />
    <xsl:param name="align" />
    <xsl:param name="valign" />
    <tbody>
      <xsl:apply-templates mode="#current">
        <xsl:with-param name="colsep" select="(@colsep, $colsep)[1]"/>
        <xsl:with-param name="rowsep" select="(@rowsep, $rowsep)[1]"/>
        <xsl:with-param name="align" select="(@align, $align)[1]"/>
        <xsl:with-param name="valign" select="(@valign, $valign)[1]"/>
      </xsl:apply-templates>
    </tbody>
  </xsl:template>
  
  <!-- ligne de tableaux -->
  <!-- MODEL : row ::= entry+ -->
  <xsl:template match="row" mode="xslLib:cals2html">
    <xsl:param name="colsep" />
    <xsl:param name="rowsep" />
    <xsl:param name="align" />
    <xsl:param name="valign" />
    <tr class="{if (count(preceding-sibling::row) mod 2 = 0) then 'cals_odd' else 'cals_even'}">
      <xsl:if test="@bgcolor">
        <xsl:attribute name="style" select="concat('background-color:',@bgcolor)"/>
      </xsl:if>
      <xsl:apply-templates mode="xslLib:cals2html">
        <xsl:with-param name="colsep" select="(@colsep, $colsep)[1]"/>
        <xsl:with-param name="rowsep" select="(@rowsep, $rowsep)[1]"/>
        <xsl:with-param name="align" select="(@align, $align)[1]"/>
        <xsl:with-param name="valign" select="(@valign, $valign)[1]"/>
      </xsl:apply-templates>
    </tr>
  </xsl:template>

  <!-- cellule de tableaux -->
  <!-- MODEL : entry ::= para | al-->
  <xsl:template match="entry" mode="xslLib:cals2html">
    <xsl:param name="colsep" />
    <xsl:param name="rowsep" />
    <xsl:param name="align" />
    <xsl:param name="valign" />
    <xsl:param name="txt-style" tunnel="yes" />
    <xsl:param name="nb-cols" tunnel="yes" />
    <xsl:variable name="entry" select="self::*" as="element(entry)"/>
    <xsl:variable name="current-tgroup" select="ancestor::tgroup[1]" as="element()"/>
    <xsl:variable name="current-col-list">
      <xsl:choose>
        <!-- on test d'abord si il y a un namestart nameend avant de prendre le cas simple du colname -->
        <xsl:when test="@namest and @nameend">
          <xsl:variable as="xs:integer" name="colnumst"
            select="cals:get-colnum($entry, $current-tgroup/colspec[@colname = current()/@namest])" />
          <xsl:variable as="xs:integer" name="colnumend"
            select="cals:get-colnum($entry, $current-tgroup/colspec[@colname = current()/@nameend])" />
          <xsl:copy-of select="$current-tgroup/colspec[cals:get-colnum($entry, .) >= $colnumst][cals:get-colnum($entry, .) &lt;= $colnumend]" copy-namespaces="no"/>
        </xsl:when>
        <xsl:when test="@colname">
          <xsl:copy-of select="$current-tgroup/colspec[@colname = current()/@colname]" copy-namespaces="no"/>
        </xsl:when>
        <xsl:when test="preceding-sibling::entry[1]/@nameend">
          <xsl:copy-of select="$current-tgroup/colspec[preceding-sibling::entry[1]/@nameend]/following-sibling::colspec[1]" copy-namespaces="no"/>
        </xsl:when>
        <xsl:when test="position() > 1 and ../entry[@colname]">
          <xsl:message>[ERROR][cals-sixtine.xsl] attribut @colname manquant (<xsl:value-of select="els:getFileName(string(base-uri()))"/> : <xsl:sequence select="els:get-xpath(.)" />)</xsl:message>
        </xsl:when>
        <xsl:when test="position() > 1 and ../entry[(position() &lt; last() and (@namest and @nameend))]">
          <xsl:message>[ERROR][cals-sixtine.xsl] trop de colonnes (<xsl:value-of select="els:getFileName(string(base-uri()))"/> : <xsl:sequence select="els:get-xpath(.)" />)</xsl:message>
        </xsl:when>
        <xsl:otherwise>
          <xsl:variable name="pos" select="count(preceding-sibling::entry) + 1"/>
          <xsl:copy-of select="$current-tgroup/colspec[$pos]" copy-namespaces="no"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="colsep-current">
      <xsl:choose>
        <xsl:when test="@colsep">
          <xsl:value-of select="@colsep" />
        </xsl:when>
        <xsl:otherwise>
          <xsl:variable name="parent-colsep" select="../@colsep" />
          <xsl:variable name="grandparent-colsep" select="../../@colsep" />
          <!-- que se passe t il lors d'un colspan ? a priori c'est le namest qui gagne-->
          <xsl:variable name="colspec-colsep" select="$current-col-list//@colsep" />
          <xsl:choose>
            <xsl:when
              test="not($parent-colsep) and not($grandparent-colsep) and $colspec-colsep">
              <xsl:value-of select="($current-col-list)//@colsep[1]" />
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="$colsep" />
            </xsl:otherwise>
          </xsl:choose>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="rowsep-current">
      <xsl:choose>
        <xsl:when test="@rowsep">
          <xsl:value-of select="@rowsep" />
        </xsl:when>
        <xsl:otherwise>
          <xsl:choose>
            <xsl:when
              test="not(../@rowsep) and not(../../@rowsep) and $current-col-list//@rowsep">
              <xsl:value-of select="($current-col-list//@rowsep)[1]" />
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="$rowsep" />
            </xsl:otherwise>
          </xsl:choose>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <!-- TODO add the same mechanism as rowsepcurrent and colsepcurrent -->
    <xsl:variable name="align-current">
      <xsl:choose>
        <xsl:when test="@align">
          <xsl:value-of select="@align" />
        </xsl:when>
        <xsl:otherwise>
          <xsl:choose>
            <xsl:when
              test="not(../@align) and not(../../@align) and $current-col-list//@align">
              <xsl:value-of select="($current-col-list//@align)[1]" />
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="$align" />
            </xsl:otherwise>
          </xsl:choose>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <!-- TODO add the same mechanism as rowsepcurrent and colsepcurrent -->
    <xsl:variable name="valign-current">
      <xsl:choose>
        <xsl:when test="@valign">
          <xsl:value-of select="@valign" />
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="$valign" />
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <td>
      <xsl:attribute name="class">
        <xsl:if test="$colsep-current != $cals_default-colsep and $colsep-current != '0'">
          <xsl:value-of select="lower-case(concat('cals_colsep', ' '))" />
        </xsl:if>
        <xsl:if test="$rowsep-current != $cals_default-rowsep and $rowsep-current != '0'">
          <xsl:value-of select="lower-case(concat('cals_rowsep', ' '))" />
        </xsl:if>
        <xsl:value-of select="lower-case(concat('cals_align', $align-current, ' '))" />
        <!--xsl:if test="$align-current != $cals_default-align">
          <xsl:value-of select="concat('cals_align', $align-current, ' ')" />
        </xsl:if-->
        <xsl:if test="$valign-current != $cals_default-valign">
          <xsl:value-of select="lower-case(concat('cals_valign', $valign-current, ' '))" />
        </xsl:if>
        <xsl:if test="@percent">
          <xsl:value-of select="concat('cals_pourcent', @percent, ' ')" />
        </xsl:if>
        <xsl:if test="number(@background) = 70">
          <xsl:value-of select="'bg70 '" />
        </xsl:if>
        <xsl:value-of select="$txt-style" />
        <xsl:if test="$nb-cols > $g-nb-cols-max-before-font-reduction
                  and $nb-cols &lt; $g-nb-cols-max-before-large-font-reduction">
          <xsl:value-of select="' table-contents-font-reduction'" />
        </xsl:if>
        <xsl:if test="$nb-cols > $g-nb-cols-max-before-large-font-reduction">
          <xsl:value-of select="' table-contents-max-font-reduction'" />
        </xsl:if>
      </xsl:attribute>
      <xsl:if test="@bgcolor">
        <xsl:attribute name="style" select="concat('background-color:',@bgcolor)"/>
      </xsl:if>
      <xsl:variable name="total-colwidth-sum">
        <xsl:call-template name="cals_sum-colwidths">
          <xsl:with-param name="col-list" select="$current-tgroup/colspec" />
        </xsl:call-template>
      </xsl:variable>
      <xsl:variable name="current-colwidth">
        <xsl:call-template name="cals_sum-colwidths">
          <xsl:with-param name="col-list" select="$current-col-list /colspec" />
        </xsl:call-template>
      </xsl:variable>
      <xsl:if test="not($p-compute-column-width-within-colgroup)">
        <xsl:attribute name="style" select="concat('width: ', round(($current-colwidth div  $total-colwidth-sum)*97), '%;')"/>
      </xsl:if>
      <xsl:if test="count($current-col-list/colspec) > 1">
        <xsl:attribute name="colspan" select="count($current-col-list/colspec)"/>
      </xsl:if>
      <xsl:if test="normalize-space(@morerows) != ''">
        <xsl:attribute name="rowspan" select="@morerows + 1"/>
      </xsl:if>
      <xsl:choose>
        <!-- cellule vide ou p avec espaces -->
        <xsl:when test="empty(./node()) and normalize-space(string(.))=''">
          <!--<xsl:text>&#xA0;</xsl:text>--> <!--NON car pour la conversion xfe:xml2HTML.xsl cela rend le fichier invalide.-->
        </xsl:when>
        <xsl:otherwise>
          <!--Le contenu de la cellule est copié-->
          <xsl:apply-templates mode="#current"/>
        </xsl:otherwise>
      </xsl:choose>
    </td>
  </xsl:template>

  <!-- Notes de tableaux. Les appels de note sont traités dans la XSLT appelante. -->
  <xsl:template match="footnote" mode="xslLib:cals2html">
    <strong class="note-num">
      <xsl:apply-templates select="@id" mode="#current"/>
      <!-- il faut un espace insécable après le nº sinon le paragraphe qui suit est collé au nº (à cause de float:left) -->
      <xsl:number count="footnote" format="(1)&#xA0;" from="table" level="any" />
    </strong>
    <!-- on sélectione le contenu du p, et non le p, car on vient de créer un html:p -->
    <xsl:apply-templates mode="#current" />
  </xsl:template>
  
  <xsl:template match="tblNote" mode="xslLib:cals2html">
    <div class="notes_container">
      <xsl:apply-templates mode="#current"/>
    </div>
  </xsl:template>
  
  <!-- Notes de tableaux. Les appels de note sont traités dans la XSLT appelante. -->
  <xsl:template match="tblNote/note" mode="xslLib:cals2html">
      <div class="note-num">
        <xsl:apply-templates select="@id" mode="#current"/>
        <!-- il faut un espace insécable après le nº sinon le paragraphe qui suit est collé au nº (à cause de float:left) -->
        <span><xsl:number count="note" format="(1)&#xA0;" from="table" level="any" /></span>
        <!-- on sélectione le contenu du p, et non le p, car on vient de créer un html:p -->
        <xsl:apply-templates mode="#current" />
      </div>
  </xsl:template>
  
  <xsl:template match="legende" mode="xslLib:cals2html">
    <div class="legende-tab">
      <xsl:apply-templates mode="#current"/>
    </div>
  </xsl:template>
  
  <!--=====================================================-->
  <!-- COMMON -->
  <!--=====================================================-->

  <xsl:template match="node() | @*" mode="xslLib:cals2html">
    <xsl:copy copy-namespaces="no">
      <xsl:apply-templates select="node() | @*" mode="#current"/>
    </xsl:copy>
  </xsl:template>
  
  <!--cf. https://www.oasis-open.org/specs/tm9901.html#AEN530 : 
    @colwidth peut être exprimé en différentes unités :
      - soit proportionnel : ex "5*"
      - soit fixes : “pt” (points), “cm” (centimeters), “mm” (millimeters), “pi” (picas), and “in” (inches)
    => FIXME mricaud : j'ai l'impression qu'ici on ne gère que les proportionnel, faut-il prévoir les fixes ?
  -->
  <xsl:template name="cals_sum-colwidths">
    <xsl:param name="current-sum" select="0" />
    <xsl:param name="col-list" />
    <xsl:choose>
      <xsl:when test="$col-list">
        <xsl:variable name="colspec" select="$col-list[1]" />
        <xsl:variable name="colwidth" select="$colspec//@colwidth" />
        <xsl:call-template name="cals_sum-colwidths">
          <xsl:with-param name="col-list" select="$col-list[position() > 1]" />
          <xsl:with-param name="current-sum" select="$current-sum + number(substring-before($colwidth,'*'))" />
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$current-sum" />
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <!--FONCTIONS LOCAL "CALS"-->
  
  <!--Récupère le @colnum d'un colspec. Si l'attribut est absent on prend la position du colspec parmis les autres colspec-->
  <xsl:function name="cals:get-colnum" as="xs:integer">
    <xsl:param name="context" as="element()?"/>
    <xsl:param name="colspec" as="element(colspec)?"/>
    <xsl:choose>
      <xsl:when test="exists($colspec)">
        <xsl:sequence select="($colspec/@colnum[normalize-space(.)!=''], count($colspec/preceding-sibling::colspec) + 1)[1]"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:message>[ERROR][cals-sixtine.xsl] appel de la fonction cals:get-colnum avec aucun colspec en argument&#10;<xsl:sequence select="els:get-xpath($context)"/></xsl:message>
        <xsl:sequence select="0"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>
  
  <!--  CALS STYLE   -->
  
  <xsl:variable name="style-prefix" as="xs:string">cals_</xsl:variable>
  
  <xsl:variable name="style-values" as="document-node()">
    <!-- Comme le namespace par defaut est http://www.w3.org/1999/xhtml les elements vont porter ce ns -->
    <xsl:document>
      <!-- frame ne se trouve qu'au niveau de l'élément table -->
      <entry key="{concat($style-prefix, 'frametop')}">border-collapse: collapse; border-top:1px solid black;</entry>
      <entry key="{concat($style-prefix, 'framebottom')}">border-collapse: collapse; border-bottom:1px solid black;</entry>
      <entry key="{concat($style-prefix, 'frametopbot')}">border-collapse: collapse; border-top:1px solid black; border-bottom:1px solid black;</entry>
      <entry key="{concat($style-prefix, 'framesides')}">border-collapse: collapse; border-left:1px solid black; border-right:1px solid black;</entry>
      <entry key="{concat($style-prefix, 'frameall')}">border-collapse: collapse; border:1px solid black;</entry>
      <entry key="{concat($style-prefix, 'framenone')}">border-collapse: collapse; border:none;</entry>
      <!-- align -->
      <entry key="{concat($style-prefix, 'alignleft')}">text-align:left;</entry>
      <entry key="{concat($style-prefix, 'alignright')}">text-align:right;</entry>
      <entry key="{concat($style-prefix, 'aligncenter')}">text-align:center;</entry>
      <entry key="{concat($style-prefix, 'alignjustify')}">text-align:justify;</entry>
      <!-- FIXME sera utile pour les tableaux issus de FrameMaker
    <entry key="{concat($style-prefix, 'alignchar')}">text-align:left;</entry> -->
      <!-- valign -->
      <entry key="{concat($style-prefix, 'valigntop')}">vertical-align:top;</entry>
      <entry key="{concat($style-prefix, 'valignbottom')}">vertical-align:bottom;</entry>
      <entry key="{concat($style-prefix, 'valignmiddle')}">vertical-align:middle;</entry>
      <!-- colsep -->
      <entry key="{concat($style-prefix, 'colsep')}">border-right:1px solid black;</entry>
      <!-- rowsep -->
      <entry key="{concat($style-prefix, 'rowsep')}">border-bottom:1px solid black;</entry>
    </xsl:document>
  </xsl:variable>
  
  <xsl:template match="*:table" mode="xslLib:xml2html_addCalsStyle">
    <xsl:choose>
      <xsl:when test="tokenize(@class, '\s+') = 'cals_cals'">
        <xsl:call-template name="create-style-att">
          <xsl:with-param name="cals-element" select="."/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:copy-of select="."/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:template match="*:tr | *:td | *:thead | *:tbody | *:tfoot" mode="xslLib:xml2html_addCalsStyle">
    <xsl:call-template name="create-style-att">
      <xsl:with-param name="cals-element" select="."/>
    </xsl:call-template>
  </xsl:template>
  
  <xsl:template name="create-style-att">
    <xsl:param name = "cals-element"/>
    <xsl:element name="{local-name($cals-element)}">
      <xsl:for-each select="$cals-element/@*">
        <xsl:choose>
          <xsl:when test="name() = 'class'">
            <xsl:variable name="style-vals" as="xs:string*">
              <xsl:for-each select="tokenize(., '\s+')">
                <xsl:variable name="val" select="lower-case(.)"/>
                <xsl:if test="starts-with($val, $style-prefix) and $style-values/html:entry[@key=$val]">
                  <xsl:value-of select="$style-values/html:entry[@key=$val]"/>
                </xsl:if>
              </xsl:for-each>
            </xsl:variable>
            <xsl:variable name="not-style-vals" as="xs:string*">
              <xsl:for-each select="tokenize(., '\s+')">
                <xsl:variable name="val" select="lower-case(.)"/>
                <xsl:if test="not(starts-with($val, $style-prefix) and $style-values/html:entry[@key=$val])">
                  <xsl:value-of select="$val"/>
                </xsl:if>
              </xsl:for-each>
            </xsl:variable>
            <xsl:variable name="not-style-values"
              select="normalize-space(string-join($not-style-vals, ''))"
              as="xs:string"/>
            <xsl:if test="$not-style-values != ''">
              <xsl:attribute name="class">
                <xsl:value-of select="$not-style-vals"/>
              </xsl:attribute>
            </xsl:if>
            <xsl:variable name="style-text"
              select="normalize-space(string-join($style-vals, ''))" as="xs:string"/>
            <xsl:if test="$style-text != ''">
              <xsl:attribute name="style">
                <!-- chercher les strings -->
                <xsl:value-of select="$style-text"/>
              </xsl:attribute>
            </xsl:if>
          </xsl:when>
          <xsl:otherwise>
            <xsl:attribute name="{name(.)}">
              <xsl:value-of select="."/>
            </xsl:attribute>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:for-each>
      <xsl:apply-templates select="$cals-element/(*|node())" mode="xslLib:xml2html_addCalsStyle"/>
    </xsl:element>
  </xsl:template>
  
  <!--Pour les autres éléments -->
  <xsl:template match="* | @* | node()" mode="xslLib:xml2html_addCalsStyle">
    <xsl:copy>
      <xsl:apply-templates select="@* | node()" mode="#current"/>
    </xsl:copy>
  </xsl:template>
  
</xsl:stylesheet>

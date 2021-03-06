<cfsetting enablecfoutputonly="true" />
<!--- @@displayname: Protected Words --->
<!--- @@author: Sean Coyne (www.n42designs.com), Jeff Coughlin (www.jeffcoughlin.com) --->

<cfimport taglib="/farcry/core/tags/webskin" prefix="skin" />
<cfimport taglib="/farcry/core/tags/formtools" prefix="ft" />
<cfimport taglib="/farcry/core/tags/admin" prefix="admin" />

<cfset filePath = application.fapi.getConfig(key = 'solrserver', name = 'instanceDir') & "/conf/protwords.txt" />

<admin:header title="Protected Words" />

<cfif fileExists(filePath)>

<ft:processForm action="Save">
	<cfset fileWrite(filePath,trim(form.contents)) />
	<cfset application.fapi.getContentType("solrProContentType").reload() />
	<skin:bubble title="Protected Words" message="Updated protwords.txt" />
</ft:processForm>

<cfset contents = fileRead(filePath) />

<cfoutput>
	<h1>Protected Words (from being stemmed)</h1> 
	<p>A list of words that should be protected and passed through unchanged. This protects the words from being "stemmed" (reducing two unrelated words to the same base word).</p>
	<p><em>Example:</em> Say you have a product called "Driving Hammer".  Normally Solr is smart enough to stem the word "driving" to its root "drive" (referring possibly to a vehicle or other products you may have that are not related to the hammer). You can protect the word "driving" from being stemmed by adding it the the protected list.</p>
</cfoutput>

<ft:form>
	
	<ft:fieldset legend="Protected Words">
		
		<ft:field for="contents" label="File Contents:" hint="No reindex is required. This file is read by Solr at query time.">
			<cfoutput>
			<textarea class="textareaInput" name="contents" id="contents" style="min-height: 400px;">#contents#</textarea>
			</cfoutput>
		</ft:field>
		
		<ft:buttonPanel>
			<ft:button value="Save" />
		</ft:buttonPanel>
	
	</ft:fieldset>
	
</ft:form>

<cfelse>

	<cfset linkConfig = application.url.webtop & "/index.cfm?sec=admin&sub=general&menu=settings&listfarconfig" />
	<cfoutput><p>Unable to locate #filepath#.  Please be sure your <a target="_top" href="#linkConfig#">Solr configuration</a> is correct.</p></cfoutput>

</cfif>

<admin:footer />

<!--- Load Custom Webtop Styling (load after admin:header) --->
<skin:loadCSS id="solrPro-customWebtopStyles" />

<cfsetting enablecfoutputonly="false" />
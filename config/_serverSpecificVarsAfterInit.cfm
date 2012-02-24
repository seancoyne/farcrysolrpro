<cfsetting enablecfoutputonly="true" />

<cfimport taglib="/farcry/core/tags/webskin" prefix="skin" />

<cfparam name="application.stPlugins.farcrysolrpro" default="#structNew()#" />

<!--- if Solr has been configured, check that the collection and solr.xml has been set up --->
<cfif application.fapi.getConfig(key = "solrserver", name = "bConfigured", default = 0)>
	
	<cfset oConfigSolrServer = application.fapi.getContentType("configSolrServer") />

	<cfset oConfigSolrServer.setupSolrLibrary() />
	
</cfif>

<cfset application.stPlugins.farcrysolrpro.oCustomFunctions = createObject("component","farcry.plugins.farcrysolrpro.packages.custom.customFunctions") />
<cfset application.stPlugins.farcrysolrpro.oManifest = createObject("component","farcry.plugins.farcrysolrpro.install.manifest") />

<skin:registerCss id="solrPro-customWebtopStyles" media="all" baseHref="/farcry/plugins/farcrysolrpro/www/css" lFiles="customWebtopStyles.cfm" />
<skin:registerCss id="siteSearch-css" media="all" baseHref="/farcry/plugins/farcrysolrpro/www/css" lFiles="search.cfm" />

<!--- clear all field name list caches --->
<cftry>
	<cfset application.fapi.getContentType("solrProContentType").clearAllFieldListCaches() />
	<cfcatch>
		<!--- most likely the content type has not been deployed yet, so there is nothing to do here --->
	</cfcatch>
</cftry>

<cfsetting enablecfoutputonly="false" />
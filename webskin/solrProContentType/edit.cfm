<cfsetting enablecfoutputonly="true" />
<!--- @@displayname: Edit --->
<!--- @@author: Sean Coyne (www.n42designs.com), Jeff Coughlin (www.jeffcoughlin.com) --->
<!--- @@cacheStatus: -1 --->

<cfimport taglib="/farcry/core/tags/webskin" prefix="skin" />
<cfimport taglib="/farcry/core/tags/formtools" prefix="ft" />

<skin:loadJs id="jquery" />
<skin:loadJs id="jquery-ui" />
<skin:loadCss id="jquery-ui" />

<cfset oIndexedProperty = application.fapi.getContentType("solrProIndexedProperty") />

<!--- assume success --->
<cfset bContinueSave = true />

<ft:processform action="Save">
	
	<!--- do some validation first --->
	<ft:processFormObjects typename="solrProContentType" bSessionOnly="true" r_stObject="stObj">
		
		<!--- ensure this is not a duplicate content type --->
		<cfset stValidationResult = ftValidateContentType(
			objectid = stProperties.objectid, 
			typename = "solrProContentType", 
			stFieldPost = { value = stProperties.contentType }, 
			stMetadata = {}
		) />
		<cfif stValidationResult.bSuccess eq false>
			<ft:advice 
				objectid="#stProperties.objectid#" 
				field="contentType" 
				message="#stValidationResult.stError.message#" 
				value="#stValidationResult.value#" />
			<cfset bContinueSave = false />
		</cfif>
		
		<!--- assure all core field boost values are numeric --->
		<cfparam name="form.indexedProperties" type="string" default="" />
		<cfloop collection="#form#" item="f">
			<cfif left(f, len('coreFieldBoost_')) eq 'coreFieldBoost_'>
				<cfif not isNumeric(form[f])>
					<ft:advice 
						objectid="#stProperties.objectid#" 
						field="aIndexedProperties" 
						message="Field boost values must be numeric. Boost value for #right(f,len(f)-len('coreFieldBoost_'))# is ""#form[f]#""" 
						value="#form[f]#" />
					<cfset bContinueSave = false />
				</cfif>
			</cfif>
		</cfloop>
		
		<!--- validate custom field boost values --->
		<cfloop collection="#form#" item="f">
			<cfif left(f, len('lFieldTypes_')) eq 'lFieldTypes_'>
				<cfset aFieldTypes = listToArray(form[f]) />
				<cfloop array="#aFieldTypes#" index="ft">
					<cfif listlen(ft,":") neq 3>
						<ft:advice 
							objectid="#stProperties.objectid#" 
							field="aIndexedProperties" 
							message="There is an error in your field type definition for #right(f,len(f)-len('lFieldTypes_'))#" 
							value="#form[f]#" />
						<cfset bContinueSave = false />
					<cfelse>
						<cfif not isNumeric(listGetAt(ft,3,":"))>
							<ft:advice 
								objectid="#stProperties.objectid#" 
								field="aIndexedProperties" 
								message="Field boost values must be numeric.  Boost value for #right(f,len(f)-len('lFieldTypes_'))# is ""#listGetAt(ft,3,":")#""" 
								value="#form[f]#" />
							<cfset bContinueSave = false />
						</cfif>
					</cfif>
				</cfloop>
			</cfif>
		</cfloop>
		
		<!--- validate the result summary fields --->
		<cfparam name="form.resultSummaryField" type="string" default="" />
		<cfset stProperties["resultSummaryField"] = form.resultSummaryField  />
		<cfif len(trim(stProperties["resultSummaryField"])) eq 0>
			<!--- if no specific result summary field, require at least one field to build the highlight field in solr --->
			<cfparam name="form.lSummaryFields" type="string" default="" />
			<cfset stProperties["lSummaryFields"] = form.lSummaryFields />
			<cfif listLen(stProperties["lSummaryFields"]) eq 0>
				<ft:advice 
					objectid="#stProperties.objectid#" 
					field="lSummaryFields" 
					message="Since you have not chosen a field to serve as the search result summary, you must choose at least one field to use to have Solr generate a summary" 
					value="#form.lSummaryFields#" />
				<cfset bContinueSave = false />
			</cfif>
		</cfif>
		
	</ft:processFormObjects>
		
</ft:processform>

<cfif bContinueSave>
	
	<ft:processform action="Save" exit="true">
		
		<ft:processFormObjects typename="solrProContentType">
			
			<cfparam name="form.resultTitleField" type="string" default="label" />
			<cfparam name="form.resultSummaryField" type="string" default="" />
			<cfparam name="form.resultImageField" type="string" default="" />
			<cfset stProperties["resultTitleField"] = form.resultTitleField />
			<cfset stProperties["resultSummaryField"] = form.resultSummaryField  />
			<cfset stProperties["resultImageField"] = form.resultImageField  />

			<cfif len(trim(stProperties["resultSummaryField"]))>
				<!--- if we have a specific summary field, then set the lSummaryFields value as an empty string.  This will prevent population of the "highlight" field.  Since its not being used, we can save disk space. --->
				<cfset stProperties["lSummaryFields"] = "" />
			<cfelse>
				<!--- if no specific summary field was chosen, then we use the checkboxes to indicate how to build the "highlight" field which will be used to generate a teaser for the search results --->
				<cfparam name="form.lSummaryFields" type="string" default="" />
				<cfset stProperties["lSummaryFields"] = form.lSummaryFields />
			</cfif>
			
			<!--- clear the array of indexed properties --->
			<cfparam name="stProperties.aIndexedProperties" type="array" default="#arrayNew(1)#" />
			<cfset oldIndexedProperties = duplicate(stProperties.aIndexedProperties) />
			<cfset stProperties.aIndexedProperties = [] />
			
			<!--- build the property list --->
			<cfparam name="form.indexedProperties" type="string" default="" />
			<cfloop list="#form.indexedProperties#" index="prop">
				
				<cfset stIndexedProperty = {
					fieldName = prop,
					lFieldTypes = form['lFieldTypes_' & prop]
				} />
				
				<cfif structKeyExists(stProperties,"objectid") and hasIndexedProperty(stproperties.objectid, prop)>
					<!--- already exists, update it --->
					<cfset stCurrent = oIndexedProperty.getByContentTypeAndFieldname(stproperties.objectid, prop) />
					<cfset structAppend(stCurrent, stIndexedProperty, true) />
					<cfset oIndexedProperty.setData(stProperties = stCurrent) />
					<cfset stIndexedProperty.objectid = stCurrent.objectid />
				<cfelse>
					<!--- new indexed property, create it --->
					<cfset stResult = oIndexedProperty.createData(stProperties = stIndexedProperty) />
					<cfset stIndexedProperty.objectid = stResult.objectid />
				</cfif>
				
				<!--- add it to the array --->
				<cfset arrayAppend(stProperties.aIndexedProperties, stIndexedProperty.objectId) />
								
			</cfloop>
			
			<!--- delete any properties that are no longer being indexed for this content type --->
			<!--- loop over the properties that used to be indexed and check that they still are, if not mark for deletion --->
			<cfloop array="#oldIndexedProperties#" index="prop">
				<cfif not arrayFindNoCase(stProperties.aIndexedProperties, prop)>
					<cfset oIndexedProperty.delete(prop) />
				</cfif>
			</cfloop>
			
			<!--- build the list of indexed rules --->
			<cfparam name="form.lIndexedRules" type="string" default="" />
			<cfset stProperties["lIndexedRules"] = form.lIndexedRules />
			
			<!--- build the list of core property boost values --->
			<cfset stProperties.lCorePropertyBoost = "" />
			<cfloop collection="#form#" item="f">
				<cfif left(f,len('coreFieldBoost_')) eq 'coreFieldBoost_' and isNumeric(form[f])>
					<cfset stProperties.lCorePropertyBoost = listAppend(stProperties.lCorePropertyBoost, listLast(f,"_") & ":" & form[f]) />
				</cfif>
			</cfloop>
			
		</ft:processFormObjects>
		
	</ft:processform>

</cfif>

<ft:processform action="Cancel" exit="true" />

<ft:form>

	<ft:fieldset>
		<cfoutput>
			<h1><skin:icon icon="#application.stCOAPI[stobj.typename].icon#" default="farcrycore" size="32" />#stobj.label#</h1>
			<h2>Note: A full re-index of the content type is strongly suggested when changing content on this page.</h2>
		</cfoutput>
	</ft:fieldset>

	<ft:fieldset legend="General">
		<ft:object stObject="#stobj#" lFields="title,contentType" r_stPrefix="generalPrefix" />
	</ft:fieldset>
	
	<ft:fieldset legend="Indexed Properties" helpSection="The properties for this content type that will be indexed.">
		<cfparam name="request.stFarcryFormValidation" default="#structNew()#" />
		<cfif structKeyExists(request.stFarcryFormValidation,stobj.objectid) and structKeyExists(request.stFarcryFormValidation[stobj.objectid],"aIndexedProperties")>
			<ft:field label="" class="error">
				<cfoutput>
				<p class="errorField" htmlfor="aIndexedProperties" for="aIndexedProperties">#request.stFarcryFormValidation[stobj.objectid]['aIndexedProperties'].stError.message#</p>
				</cfoutput>
			</ft:field>
		</cfif>
		<cfoutput><div id="indexedProperties"></div></cfoutput>		
	</ft:fieldset>
	
	<ft:fieldset legend="Search Result Defaults">
		<cfoutput><p>These options affect output and not what is indexed.  So if you want a specific field (or fields) to be used for the search result summary output, you can select that here.</p></cfoutput>
		
		<ft:field label="Result Title <em>*</em>" hint="The field that will be used for the search result title.  It is suggested to use a ""string"" field. You must store this value in Solr's index.">
			<cfoutput>
				<select name="resultTitleField" id="resultTitleField"></select>
			</cfoutput>
		</ft:field>

		<cfparam name="request.stFarcryFormValidation" default="#structNew()#" />
		<cfif structKeyExists(request.stFarcryFormValidation,stobj.objectid) and structKeyExists(request.stFarcryFormValidation[stobj.objectid],"lSummaryFields")>
			<cfset className = "error" />
		<cfelse>
			<cfset className = "" />
		</cfif>
		<ft:field label="Result Summary" bMultiField="true" class="#className#" hint="The field that will be used for the search result summary.<br />Options are:<br />1. Solr Generated Summary: Select any desired FarCry field(s) and Solr will use it's highlighting engine to return areas of the field(s) that match the search term. These do <strong>not</strong> have to be stored above in order to use this feature.<br />2. Use a manually selected field. You must store this value in Solr's index for it to appear here.">
			<cfoutput>
				<cfif structKeyExists(request.stFarcryFormValidation,stobj.objectid) and structKeyExists(request.stFarcryFormValidation[stobj.objectid],"lSummaryFields")>
				<p class="errorField" htmlfor="lSummaryFields" for="lSummaryFields">#request.stFarcryFormValidation[stobj.objectid]['lSummaryFields'].stError.message#</p>
				</cfif>
				<select name="resultSummaryField" id="resultSummaryField"></select>
				<div id="lSummaryFields"></div>
			</cfoutput>
		</ft:field>
		
		<ft:field label="Result Image" hint="The field that will be used for the search result teaser image.  If you have an image you would like to display in the search results choose the Solr field that will contain the image's path.  It is recommended you use a ""string"" field type.  You must store this value in Solr's index.">
			<cfoutput>
				<select name="resultImageField" id="resultImageField"></select>
			</cfoutput>
		</ft:field>
		
	</ft:fieldset>
	
	<ft:fieldset legend="Related Rules" helpSection="The FarCry Solr Pro plugin can index the contents of rules that have text data.">
		
		<ft:object stObject="#stobj#" lFields="bIndexRuleData" r_stPrefix="rulePrefix" />
		
		<ft:field label="Indexed Rules" bMultiField="true" hint="Choose the rules you would like to index for this content type.  The rule fields that will be indexed are listed below each rule name.  Only text fields can be indexed.">
			
			<cfset aRules = application.fapi.getContentType("solrProContentType").getRules() />
			
			<cfloop array="#aRules#" index="rule">
				<cfoutput>
				<div class="rule">			
					<div class="indexRuleCheckbox"><input type="checkbox" name="lIndexedRules" id="lIndexedRules_#rule.typename#" value="#rule.typename#" <cfif listFindNoCase(stobj.lIndexedRules, rule.typename)>checked="checked"</cfif> /></div>
					<div class="indexRuleDescription"><label for="lIndexedRules_#rule.typename#">#rule.displayname#<br /><span>(#replace(rule.indexableFields, ",", ", ", "all")#)</span></label></div>
				</div>
				</cfoutput>
			</cfloop>
			
		</ft:field>
		
	</ft:fieldset>
	
	<ft:fieldset legend="Advanced Options">
		<cfset stPropMetadata = { 
			defaultDocBoost = { 
				ftDefault = application.fapi.getConfig(key = 'solrserver', name = 'defaultDocBoost', default = 50),
				default = application.fapi.getConfig(key = 'solrserver', name = 'defaultDocBoost', default = 50)
			} 
		} />
		<cfif not isNumeric(stObj.defaultDocBoost)>
			<cfset stPropMetadata.defaultDocBoost.value = application.fapi.getConfig(key = 'solrserver', name = 'defaultDocBoost', default = 50) />
		</cfif>
		<ft:object stObject="#stobj#" lFields="bEnableSearch,builtToDate,bIndexOnSave,defaultDocBoost" stPropMetadata="#stPropMetadata#" />
	</ft:fieldset>
	
	<ft:farcryButtonPanel>
		<ft:farcryButton type="submit" text="Complete" value="save" validate="true" />
		<ft:farcryButton type="submit" text="Cancel" value="cancel" validate="false" confirmText="Are you sure you wish to discard your changes?" />
	</ft:farcryButtonPanel>
	
	<cfoutput>
		<div id="helpInfo" class="ui-widget-content ui-corner-all">
			<h3 class="ui-widget-header ui-corner-all">Information &amp; Tips</h3>
			<div class="showInfo">
				<a href="##" onclick="return false;" class="showHelpInfoTrue">Show Help Information</a>
			</div>
			<div id="helpInfoBody">
				<h4>Indexed Properties</h3>
				<p>Any fields that you would like Solr to index are chosen here.</p>
				<h5>Custom Properties</h5>
				<p>These represent the fields for your FarCry types that are not FarCry default types.  ie. These wouldn't be fields like <var>objectid</var> and <var>label</var> (ref. <a href="##defaultproperties">Default Properties</a>), but rather the other custom fields you might have in your object like <var>title</var>.</p>
				<p>Your options here are the following:</p>
				<h6>Indexing a Field</h6>
				<ul>
					<li>You need only to check the box on the left of a field and Solr will start indexing that field's in the future based on the Solr field types you associate it with.</li>
				</ul>
				<h6>Select Solr field types to index</h6>
				<ul>
					<li>When you first choose this dropdown, we will offer what we feel are the suggested Solr Field Types.  By default, these are typenames that we have created in your project's schema.xml.  If you are familiar with Solr, you can modify these yourself (just remember that Solr has to be restarted when editing the schema.xml and content types have to be re-indexed).  There are a couple requirements we added which are commented at the bottom of the file, but we tried to give you as much freedom as possible if you ever felt the need to make modifications to your schema.xml.</li>
					<li>Since most things you'll want to index are text-based fields, we suggest using the <var>Text</var> option.  And in many cases also adding the <var>Phonetic</var> option as well (so users can match searches that are phonetically similar).  Be warned: The <var>string</var> type doesn't go through any filters and is case-sensitive.  We find it useful for storing things like image and file paths (uses a smaller footprint in the Solr database).</li>
					<li class="nolistyle"><h6>Storing a Field</h6>
						<ul>
							<li>You do not need to store a field in order for it to be searchable (indexed).  However, there are times where you want a field to be stored by Solr so that you don't have to do a database lookup to find the same data (Solr will already have it for you in its results).  Common examples are <var>Title</var>, <var>teaser</var>, etc.</li>
						</ul>
					</li>
					<li class="nolistyle"><h6>Boost by Field</h6>
						<ul>
							<li>This feature allows you to give or remove weight to fields when searching.</li>
							<li>Example:  In a simple HTML object, we suggest giving the <var>title</var> field a heavy boost value of something like 50 and maybe 10 to the <var>body</var>.  Why?  Because when a user searches for a specific term (say "<em>Community Charity Campaign</em>"), they may be referring to a very specific event.  Those words in the search term may be common words found all over the place in the <var>body</var> of many pages on the site.  However, those same words may only appear in 2 or 3 <var>titles</var> for very specific events.  Thus the scoring engine in Solr (Lucene) will give more weight to any <var>title</var> fields where the search term was found.  Otherwise every time one of those words is found in the <var>body</var>, it is added to the score for the search (as well as boosted).  If the <var>title</var> field wasn't given more weight for those terms, then the scoring would be skewed and the user would likely not find the results they were originally looking for.</li>
							<li>Boosting can be a very powerful feature if used correctly.  You know your content better than anyone.  However, if you're not sure what you want to change them to, then don't feel required to change them.  If the fields are all the same boost value then the default values won't affect the overall score because they are weighted against each other during the search.  Meaning: If they all have the same weight, then there will be no extra leverage to any given field (compared to others) when searching.</li>
							<li>Out-of-the-box the defaults for each field will be 5 (unless changed in the Solr configuration).  Why default boost 5?  We did this so that if you have any speicifc fields to index that should have lower weight (compared to other fields), then you could set that here.</li>
							<li>The default setting for all fields can be changed in the Solr Config.</li>
						</ul>
					</li>
				</ul>

				<h5 id="defaultproperties">Default Properties</h5>
				<p>Default properties are fields that are always indexed (and many stored) for all types.  Some of them are from FarCry core, while others are additional fields used to help with extra data.  For most people, these fields and their settings can be left alone including their boost settings, however their boost values can be adjusted here if desired.</p>
				<p>The reason that the first seven items are stored in Solr is to enhance performance on seaches.  When a user searches your site, Solr is already returning back data.  Much of the teaser data needed to be displayed to the user can be returned from Solr and there is no need to do an extra query lookup per item on the search result page.  This is another reason that we suggest storing a search result <var>title</var> and <var>teaser</var> (and any other fields you want displayed on the search results page - like a <var>teaser image</var>).</p>
				<h6>Stored and indexed FarCry core fieldnames:</h6>
				<ul>
					<li>objectid &mdash; Used as the unique ID field for Solr records and matches the associated FarCry objectid.</li>
					<li>label &mdash; Matches the associated FarCry data</li>
					<li>datetimecreated &mdash; Matches the associated FarCry data</li>
					<li>datetimelastupdated &mdash; Matches the associated FarCry data</li>
					<li>createdby &mdash; Matches the associated FarCry data</li>
					<li>lastupdatedby &mdash; Matches the associated FarCry data</li>
					<li>ownedby &mdash; Matches the associated FarCry data</li>
				</ul>
				<h6>Solr will ignore the following FarCry fields because we felt that they were not relevant to searches (you can change these in your schema.xml if desired):</h6>
				<ul>
					<li>locked &mdash; ignored</li>
					<li>lockedby &mdash; ignored</li>
					<li>versionid &mdash; ignored</li>
					<li>status &mdash; ignored</li>
				</ul>
				<h6>The following default fields are indexed by Solr for various reasons (explained):</h6>
				<ul>
					<li>typename &mdash; Matches the FarCry typename.  Used by Solr for query lookups when matching objectid and typename.</li>
					<li>fcsp_rulecontent &mdash; When you elect to store any related rule content, its associated data is indexed in both the fcsp_rulecontent field and it's associated phonetic field.</li>
					<li>fcsp_rulecontent_phonetic &mdash; Used for phonetic searches on related rule content.</li>
					<li>fcsp_spell &mdash; Used by Solr for spell correction on single-word searches.</li>
					<li>fcsp_spellphrase &mdash; Used by Solr for spell correction on multi-word (phrase) searches.</li>
					<li>fcsp_highlight &mdash; Data indexed by the highlighting engine in Solr (often referred to as summary data)</li>
				</ul>
				
				<h4>Search Result Defaults</h4>
				<h5>Result Title</h5>
				<!--- TODO: Finish these docs --->
				<p><em>More info soon...</em></p>

				<h5>Result Summary</h5>
				<h6>Option 1: Solr Generated Summary</h6>
				<p>Using Solr's generated summary takes advantage of Solr's highlighting engine.  It's not the fact that it just highlights search terms (thats simple enough to do in CF).  What makes it unique is that the summary will be snippets of text where your search term(s) were found (similar to Google).</p>
				<h6>Option 2: Custom/Manual Field Selection</h6>
				<p>Using a custom field selection is suggested for times when you want, say, use a specified teaser field to always be used no matter where the search terms were found. Example: Say you have a product with a very specified teaser that you want to always be shown in your search results (not a snippet of the search term)</p>

				<h5>Result Image</h5>
				<!--- TODO: Finish these docs --->
				<p><em>More info soon...</em></p>

				<h4>Related Rules</h4>
				<h5>Indexing Rule Data</h5>
				<!--- TODO: Finish these docs --->
				<p><em>More info soon...</em></p>

				<h4>Related Rules</h4>
				<h5>Enabling in Site Search</h5>
				<!--- TODO: Finish these docs --->
				<p><em>More info soon...</em></p>
				<h5>Built to Date</h5>
				<!--- TODO: Finish these docs --->
				<p><em>More info soon...</em></p>
				<h5>Index on Save</h5>
				<!--- TODO: Finish these docs --->
				<p><em>More info soon...</em></p>
				<!---<span class="ui-icon ui-icon-circle-check"></span>--->			
			</div>
		</div>
	</cfoutput>
	
	<skin:htmlhead id="solrProContentType-edit">
		<cfoutput>
		<style type="text/css" media="all">
			/* Uniform override */
			.uniForm .inlineLabels .multiField {
				width: 60%;
			}

			/* Page styling */
			strong {
				font-weight: bold;
			}
			em {
				font-style: italic;
			}
			h4 {
				font-size: 125%;
			}
			h5 {
				font-size: 110%;
			}
			h6 {
				font-size: 95%;
			}
			.combobox a {
				text-decoration: none;
				vertical-align: middle;
				padding-right: 0.4em;
			}
			.combobox a:hover {
				background: transparent;
			}
			.combobox input {
				width: 4em;
			}
			.fieldTypeDropdown {
				vertical-align: middle;
			}
			.fieldType {
				padding: 0.25em 0 0.25em 0.5em;
			}
			.fieldType span {
				margin-left: 0.25em;
				margin-right: 0.25em;
			}
			.fieldType div.fieldTypeAttributesLeft {
				min-width: 35em;
			}
			.fieldType div.fieldTypeAttributesLeft span {
				vertical-align: middle;
			}
			.fieldType div.fieldTypeAttributesRight {
				float: right;
			}
			.fieldType div.fieldTypeAttributesRight div {
				display: inline;
				padding-left: 0.5em;
				vertical-align: middle;
			}
			.fieldType div.fieldTypeAttributesRight div input {
				vertical-align: middle;
			}
			.fieldType div.buttonset label:not(.ui-state-active) span {
				color: ##888 !important;
			}
			.fieldType div.buttonset label span {
				font-size: 0.8em;
				padding: 0.1em 0.4em;
			}
			table.fcproperties {
				margin: .85em 0;
				border-collapse: collapse;
				font-size: 1em;
			}
			table.fcproperties caption {
				font: bold 145% arial;
				padding: 5px 10px;
				text-align: left;
			}
			table.fcproperties td,
			table.fcproperties th {
				border: 1px solid ##eee;
				padding: .6em 10px;
				text-align: left;
				vertical-align: top;
			}
			table.fcproperties tr:nth-child(even),
			table.fcproperties tr.alt  {
				background: none repeat scroll 0 0 ##F1F1F1;
			}
			##indexedProperties {
				max-width: 900px;
				min-width: 500px;
			}
			##tblCustomProperties {
				width: 100%;
			}
			##tblCustomProperties tbody tr td:nth-child(1) {
				padding-top: .8em;
			}
			##tblCustomProperties thead tr th:nth-child(4) {
				width: 55%;
				white-space: nowrap;
			}
			div.rule {
				float: left;
				width: 269px;
				margin: 5px 5px 5px 0;
			}
			div.rule div.indexRuleDescription {
				 margin-left: 1.3em;
			}
			div.rule label span {
				 font-style: italic;
			}
			div.rule input {
				float: left;
				margin-top: 0.2em;
			}
			##lSummaryFields {
				margin: 10px 0;
				min-height: 100%;
				height: auto;
			}
			##lSummaryFields label {
				float: left;
				width: 185px;
				margin: 2px 0;
			}
			##lSummaryFields label input {
				margin-right: 5px;
			}
			code,
			.code,
			var {
				color: ##555;
				font: 1.1em monospace;
				background-color: ##eee;
				padding: 0.3em 0.5em;
			}
			##helpInfo {
				padding: 0.4em;
				position: relative;
				margin: 1em 0;
				/*min-width: 500px;
				max-width: 800px;*/
			}
			##helpInfo h3 {
				margin: 0 0 1em 0;
				padding: 0.4em;
				text-align: center;
			}
			##helpInfo div {
				margin: 0 1em;
			}
##helpInfo div##helpInfoBody {
  display: none; /* default value overridden by jQuery show/hide */
  margin-top: 10px;
}
##helpInfo div.showInfo {
  margin-top: 10px;
}
##helpInfo a.showHelpInfoTrue,
##helpInfo a.showHelpInfoTrue:hover {
  background: transparent url(#application.fapi.getConfig(key = 'solrserver', name = 'pluginWebRoot')#/css/images/glyph-down.gif) no-repeat scroll right top;
  padding-right: 13px;
}
##helpInfo a.showHelpInfoFalse,
##helpInfo a.showHelpInfoFalse:hover {
  background: transparent url(#application.fapi.getConfig(key = 'solrserver', name = 'pluginWebRoot')#/css/images/glyph-up.gif) no-repeat scroll right top;
  padding-right: 13px;
}
			##helpInfo p {
				margin: 0.5em 0;
			}
			##helpInfo ul {
				margin-left: 1em;
			}
			##helpInfo ul ul {
				margin-left: 0;
			}
			##helpInfo li {
				margin-left: 1em;
				list-style: disc outside none;
			}
			##helpInfo li.nolistyle {
				margin-left: 0;
				list-style: none;
			}
		</style>
		<script type="text/javascript">
			
			var fieldTypes = [];
			
			$j(document).ready(function(){
				
	      // Search: More Options
	      $("a.showHelpInfoTrue").toggle(function(){
	        $(this).html("Hide Help Information");
	        $(this).removeClass("showHelpInfoTrue").addClass("showHelpInfoFalse");
	        $("div##helpInfoBody").slideDown("slow");
	      },function(){
	        $(this).html("Show Help Information");
	        $(this).removeClass("showHelpInfoFalse").addClass("showHelpInfoTrue");
	        $("div##helpInfoBody").slideUp("slow");
	      });


				<cfif stobj.bIndexRuleData eq 0>
				$j(".rule").closest(".ctrlHolder").hide();
				</cfif>
				
				$j('###rulePrefix#bIndexRuleData').change(function(event){
					if ($j(this).is(':checked')) {
						$j(".rule").closest(".ctrlHolder").show();
					} else {
						$j(".rule").closest(".ctrlHolder").hide();
					}
				});
				
				if ($j('###generalPrefix#contentType').val().length > 0) {
					// load the HTML for the table of indexed properties
					loadIndexedPropertyHTML("#stobj.objectid#",$j('###generalPrefix#contentType').val());
					// load the FarCry fields for the lSummaryFields list box
					loadContentTypeFields($j('###generalPrefix#contentType').val());
				}
				
				$j('###generalPrefix#contentType').change(function(event){
					// load the HTML for the table of indexed properties
					loadIndexedPropertyHTML("#stobj.objectid#",$j('###generalPrefix#contentType').val());
					// load the FarCry fields for the lSummaryFields list box
					loadContentTypeFields($j('###generalPrefix#contentType').val());
				});
				
				<!--- hide the "summary fields" checkboxes if we have a specific summary field --->
				<cfif len(trim(stobj.resultSummaryField))>
					$j("##lSummaryFields").hide();
				</cfif>
				
				$j('##resultSummaryField').change(function(event){
					// hide/show summary field checkboxes
					if ($j.trim($j(this).val()) == '') {
						$j('##lSummaryFields').slideDown("slow");						
					} else {
						$j('##lSummaryFields').slideUp("slow");						
					}
				});
				
			});
			
			function createOptionTag(value, label, selected) {
				var html = '<option value="' + value + '"';
				if (selected) {
					html = html + ' selected="selected"';
				}
				html = html + ">" + label + "</option>";
				return html;
			}
			
			function addOptionsToDropdown(dropdown, options) {
				dropdown.empty();
				for (var i = 0; i < options.length; i++) {
					dropdown.append(options[i]);
				}
			}
			
			function loadResultFieldDropdowns() {
				buildResultTitleDropdownOptions();
				buildResultSummaryDropdownOptions();
				buildResultImageDropdownOptions();
			}
			
			function buildResultTitleDropdownOptions() {
				
				var selectedValue = '#stobj.resultTitleField#';
				if (selectedValue == '') {
					selectedValue = 'label';
				}
				var dropdown = $j("##resultTitleField");
				var options = buildResultFieldOptions(selectedValue);
				
				addOptionsToDropdown(dropdown, options);
				
				// set the selected one
				if (selectedValue.length > 0) {
					// if we have that option in the drop down, select it
					dropdown.find('option[value="' + selectedValue + '"]').attr("selected",true);
				} else {
					// if there is a title field, select it
					dropdown.find('option[value*="title_"]').attr('selected',true);
				}
				
			}
			
			function buildResultSummaryDropdownOptions() {
				
				var selectedValue = '#stobj.resultSummaryField#';
				var dropdown = $j("##resultSummaryField");
				var options = buildResultFieldOptions(selectedValue);
				
				// add the "none" option
				options.push(createOptionTag("","-- Use Solr Generated Summary --",false));
				options.sort();
				
				addOptionsToDropdown(dropdown, options);

			}
			
			function buildResultImageDropdownOptions() {
				
				var selectedValue = '#stobj.resultImageField#';
				var dropdown = $j("##resultImageField");
				var options = buildResultFieldOptions(selectedValue);
				
				// add the "none" option
				options.push(createOptionTag("","-- No Teaser Image --",false));
				options.sort();
				
				addOptionsToDropdown(dropdown, options);
				
			}
			
			function buildResultFieldOptions(selectedValue) {
				
				// builds an array of HTML option tags for the result fields
				
				var fields = loadResultFieldsForDropdowns();
				var options = [];
				
				for (var i = 0; i < fields.length; i++) {
					options.push(createOptionTag(fields[i].fieldName, fields[i].label, (selectedValue == fields[i].fieldName)));
				}
				
				return options;
				
			}
			
			function loadResultFieldsForDropdowns() {
				
				// loads candidates for the result title, summary and image fields
				
				// get all of the created fields from the custom properties table and all core properties
				var fields = [];
				
				// get custom properties
				$j('input.lFieldTypes').each(function(i){
					
					// we are only interested in the ones that have defined field types
					if ($j(this).val().length > 0) {
					
						// grab the base field name
						var baseFieldName = $j(this).attr('rel').toLowerCase();
						
						// for each defined field type, build the full field name and add it to the array
						
						// step 1: the value of the text box is a comma delimited list of defined field types
						var types = $j(this).val().split(",");
						
						// step 2: each of the field type definitions is a colon delimited list of values in type:storedFlag:boostValue format
						for (var i = 0; i < types.length; i++) {
							types[i] = types[i].split(":");
						}
						
						// step 3: build full field name and add it to the array
						for (var y = 0; y < types.length; y++) {
							// only include stored fields
							if (types[y][1] == 1) {
								var type = types[y][0];
								var fullFieldName = baseFieldName + "_" + type + "_stored";
								fields.push({fieldName: fullFieldName, label: baseFieldName + " (" + type + ")"});
							}
						}
						
					}
						
				});
				
				// get core properties
				$j("##tblCoreProperties tbody tr").each(function(i){
					// include only stored fields
					var stored = $j.trim($j(this).find("td:nth-child(4)").text().toLowerCase());
					if (stored == "yes") {
						// column 1 is field name
						fields.push({ fieldName: $j(this).find("td:first-child").text(), label: $j(this).find("td:first-child").text()});
					}
				});
				
				// sort 'em alphabetically
				fields.sort();
				
				return fields;
				
			}
			
			function updateFieldTypeSelectionDisplay() {
				// for each property
				$j('input[name="indexedProperties"]').each(function(i){
					
					var thisFieldName = $j(this).val();
					var displayFieldTypesDiv = $j("##displayFieldTypes_" + thisFieldName);
					var lFieldTypes = $j("##lFieldTypes_" + thisFieldName);
					
					if (!$j(this).is(":checked")) {
						// remove all
						$j("##displayFieldTypes_" + thisFieldName).hide();
						$j("##fieldType_" + thisFieldName).attr("disabled", true);
						$j("button[rel='" + thisFieldName + "'].btnAddFieldType").attr("disabled", true);
						$j("##customField_" + thisFieldName).addClass("ui-state-disabled");
						$j("##fcFieldType_" + thisFieldName).addClass("ui-state-disabled");
					} else {
						// grab the lFieldTypes value and add the items to the display div
						if (lFieldTypes.val().length > 0) {
							displayFieldTypesDiv.empty();
							var aFieldTypes = lFieldTypes.val().split(",");
							for (var x = 0; x < aFieldTypes.length; x++) {
								var parsed = aFieldTypes[x].split(":");
								var fieldType = parsed[0];
								var bStored = parsed[1];
								var boostValue = parsed[2];
								
								   var html = '<div class="fieldType" id="fieldType_' + thisFieldName + '_' + fieldType + '"> ';
								html = html + '<div class="fieldTypeAttributesRight">';
								html = html + '<div class="buttonset">';
								html = html + '<input value="1" class="chkStore" ' + ((bStored == 1) ? 'checked="checked"' : '') + ' type="radio" id="chkStore_' + thisFieldName + '_' + fieldType + '_on" name="chkStore.' + thisFieldName + '.' + fieldType + '" /><label for="chkStore_' + thisFieldName + '_' + fieldType + '_on">Stored</label>';
								html = html + '<input class="chkStore" ' + ((bStored == 0) ? 'checked="checked"' : '') + '  name="chkStore.' + thisFieldName + '.' + fieldType + '" type="radio" value="0" id="chkStore_' + thisFieldName + '_' + fieldType + '_off" /><label for="chkStore_' + thisFieldName + '_' + fieldType + '_off">Not Stored</label>';
								html = html + '</div>';
								html = html + '<div class="combobox">';
								// combobox id uses underscores instead of period because of an issue with jquery selectors and periods
								html = html + '<label for="fieldBoost_' + thisFieldName + '_' + fieldType + '">Boost:</label>';
								html = html + '<input type="text" rel="' + thisFieldName + '.' + fieldType + '" class="fieldBoost" name="fieldBoost_' + thisFieldName + '.' + fieldType + '" id="fieldBoost_' + thisFieldName + '_' + fieldType + '" value="' + boostValue + '" />';
								html = html + '</div>';
								html = html + '</div>';
								html = html + '<div class="fieldTypeAttributesLeft">';
								html = html + '<button class="btnRemoveFieldType" type="button" rel="' + thisFieldName + '.' + fieldType + '">Remove</button>';
								html = html + '<span>' + $j("##fieldType_" + thisFieldName + " option[value='" + fieldType + "']").text() + '</span>';
								html = html + '</div>';
								html = html + '</div>';
								
								displayFieldTypesDiv.append(html);
								$j("##fieldType_" + thisFieldName + " option[value='" + fieldType + "']").attr("disabled",true);
							}
						}
						$j("##displayFieldTypes_" + thisFieldName).show();
						$j("##fieldType_" + thisFieldName).attr("disabled", false);
						$j("button[rel='" + thisFieldName + "'].btnAddFieldType").attr("disabled", false);
						$j("##customField_" + thisFieldName).removeClass("ui-state-disabled").attr("disabled", false);
						$j("##fcFieldType_" + thisFieldName).removeClass("ui-state-disabled").attr("disabled", false);			
					}
					
				});
				
				activateFieldTypeRemoveButtons();
				activateStoreCheckboxes();
				activateBoostDropdowns();
				
				// setup stored/not stored toggle
				$j( ".fieldType div.buttonset" ).buttonset();
				
			}
			
			function activateFieldTypeRemoveButtons() {
				
				$j("button.btnRemoveFieldType").button({
					text: false,
					icons: { 
						primary: "ui-icon-close" 
					}
				}).css({
					"width": "1.4em",
					"height": "1.4em",
					"vertical-align": "middle"
				});
				
				$j("button.btnRemoveFieldType").click(function(event){
					
					var rel = $j(this).attr("rel").split(".");
					var fieldTypeToRemove = rel[1];
					var fieldName = rel[0];
					var lFieldTypes = $j("##lFieldTypes_" + fieldName);
					
					if (lFieldTypes.val().length) {
					
						var aFieldTypes = lFieldTypes.val().split(",");
						
						// remove it from the string
						
						for (x = 0; x < aFieldTypes.length; x++) {
							if (aFieldTypes[x].split(":")[0] == fieldTypeToRemove) {
								aFieldTypes.splice(x,1);
								break;
							}
							
						}
						
						lFieldTypes.val(aFieldTypes.join(","));
						
					}
					
					// remove it from the div
					$j("##fieldType_" + fieldName + '_' + fieldTypeToRemove).remove();
					
					$j("##fieldType_" + fieldName + " option[value='" + fieldTypeToRemove + "']").removeAttr("disabled");
					
					loadResultFieldDropdowns();
					
				});
			}
			
			function activateStoreCheckboxes() {
				$j("input.chkStore").click(function(event){
					
					var parsed = $j(this).attr("name").split(".");
					var fieldName = parsed[1];
					var fieldType = parsed[2];
					var lFieldTypes = $j("##lFieldTypes_" + fieldName);
					
					// find the field in the string and set stored property 
					if (lFieldTypes.val().length) {
						
						var aFieldTypes = lFieldTypes.val().split(",");
						
						for (var i = 0; i < aFieldTypes.length; i++) {
							if (aFieldTypes[i].split(":")[0] == fieldType) {
								aFieldTypes[i] = fieldType + ":" + $j(this).val() + ":" + aFieldTypes[i].split(":")[2];
								break;
							}
						}
						
						lFieldTypes.val(aFieldTypes.join(","));
							
					}
					
					loadResultFieldDropdowns();
					
				});
			}
			
			function setupTableInteraction() {
				
				// activate the checkboxes
				$j('input[name="indexedProperties"]').change(function(event){
					updateFieldTypeSelectionDisplay();
					loadResultFieldDropdowns();
				});
				
				// activate the "add" buttons
				$j("button.btnAddFieldType").click(function(event){
					
					var thisFieldName = $j(this).attr("rel");
					var thisFieldType = $j("##fieldType_" + thisFieldName);
					
					if (thisFieldType.val() != "") {
					
						var displayFieldTypesDiv = $j("##displayFieldTypes_" + thisFieldName);
						var lFieldTypes = $j("##lFieldTypes_" + thisFieldName);
						
						if (lFieldTypes.val().length) {
							var aFieldTypes = lFieldTypes.val().split(",");
						}
						else {
							var aFieldTypes = [];
						}
						
						// make sure this type has not already been added
						bAlreadyExists = false;
						for (var i = 0; i < aFieldTypes.length; i++) {
							if (aFieldTypes[i].split(":")[0] == thisFieldType.val()) {
								bAlreadyExists = true;
								break;
							}
						}
						// if not add with default "stored" value, and boost value
						if (bAlreadyExists == false) {
							aFieldTypes.push(thisFieldType.val() + ":0:#application.fapi.getConfig(key = 'solrserver', name = 'defaultBoostValue', default = 5)#");
						}
						
						lFieldTypes.val(aFieldTypes.join(","));
						
						updateFieldTypeSelectionDisplay();
						
						thisFieldType.find("option:selected").removeAttr("selected");
						
					}
					
					loadResultFieldDropdowns();
					
				});
				
				$j("button.btnAddFieldType").button({
					text: false,
					icons: { 
						primary: "ui-icon-plus" 
					}
				}).css({
					"width": "1.4em",
					"height": "1.4em",
					"vertical-align": "middle"
				});
			}
			
			function handleBoostChange(target) {
				
				// grab the hidden field for this field/fieldtype
				var fieldName = $j(target).attr("rel").split(".")[0];
				var fieldType = $j(target).attr("rel").split(".")[1];
				var hidden = $j("##lFieldTypes_" + fieldName);
				
				// grab the current value of the hidden field
				var aFieldTypes = hidden.val().split(',');
				
				// loop over the list until you find the field type we are changing
				for (var i = 0; i < aFieldTypes.length; i++) {
					if (aFieldTypes[i].split(":")[0].toLowerCase() == fieldType.toLowerCase()) {
						// update the boost value
						aFieldTypes[i] = fieldType.toLowerCase() + ":"  + aFieldTypes[i].split(":")[1] + ":" + $j(target).val();
						break;
					}
				}
				// write the new string to the hidden field's value
				hidden.val(aFieldTypes.join(","));
				
			}
						
			function activateBoostDropdowns() {
				
				<cfset counter = 0 />
				<cfset lFieldBoostValues = application.fapi.getConfig(key = 'solrserver', name = 'lFieldBoostValues') />
				
				$j('.combobox input').each(function(i){
					
					var options = [ <cfloop list="#lFieldBoostValues#" index="i"><cfset counter++ />"#i#"<cfif counter lt listLen(lFieldBoostValues)>,</cfif></cfloop> ];
					
					if (options.indexOf($j(this).val()) == -1) {
						options.push($j(this).val());
					}
					
					options.sort(function (a,b) {
						return a - b;
					});
					
					$j(this).autocomplete({
						source: options,
						minLength: 0,
						change: function (event) {
							handleBoostChange(this);
						},
					}).addClass( "ui-widget ui-widget-content ui-corner-left" ).css({
						"vertical-align": "middle"
					});
					
				});
				
				// activate the label
				$j('.combobox label').each(function(i){
					var labelText = $j(this).text();
					var target = $j(this).attr("for");
					$j(this).html("<a>" + labelText + "</a>");
					$j(this).find("a").click(function(event){
						event.preventDefault();
						openCombobox($j("##" + target));
					});
				});
				
				// create and activate the button
				$j(".combobox").each(function(i){
					
					if ($j(this).find("button").length > 0) {
						return false;
					}
					
					var input = $j(this).find("input");
					var button = $j('<button type="button">Open</button>');
					
					// add a change handler for the input
					input.change(function(event){
						handleBoostChange(this);
					});
					
					button.button({
						text: false,
						icons: {
							primary: "ui-icon-triangle-1-s"
						}
					}).removeClass( "ui-corner-all" ).addClass( "ui-corner-right ui-button-icon" ).css({
						"width": "1.4em",
						"height": "1.4em",
						"vertical-align": "middle"
					}).click(function (event) {
							openCombobox(input);
					});
					
					input.after(button);
					
				});
				
			}
			
			function openCombobox(target) {
				
				// if its open, close it
				if (target.autocomplete("widget").is(":visible")) {
					target.autocomplete("close");
					return;
				}

				// open the combobox
				$j(this).blur();
				target.autocomplete("search","");
				target.focus();
				
			}
			
			function loadIndexedPropertyHTML(objectid,typename) {
				
				$j("##indexedProperties").empty();
				
				// do an ajax call to the webskin to grab the HTML to build the table
				$j.ajax({
					cache: false,
					type: "GET",
					url: "#application.fapi.getwebroot()#/?contentType=" + typename + "&view=indexedPropertyTable&objectid=" + objectid,
					datatype: "html",
					success: function(data, status, req) {
						
						$j("##indexedProperties").append(data);
						
						setupTableInteraction();
						
						updateFieldTypeSelectionDisplay();
						
						loadResultFieldDropdowns();
						
					},
					error: function(req, status, err) {
						
						var contentType = $j('###generalPrefix#contentType');
						var message = '<p class="errorField">There was an error loading the indexed fields for that content type.  Make sure you have created an web server mapping for #application.fapi.getConfig(key = 'solrserver', name = 'pluginWebRoot')#. See documentation for more information.</p>';
						contentType.closest(".ctrlHolder").addClass("error").prepend(message);
						
					}
				});
				
			}
			function loadContentTypeFields(contentType) {
				
				var lSummaryFields = $j("##lSummaryFields");
				
				lSummaryFields.empty();
				
				$j.ajax({
					url: "#application.fapi.getConfig(key = 'solrserver', name = 'pluginWebRoot')#/facade/remote.cfc?method=getTextPropertiesByType&applicationName=#application.applicationName#&returnformat=json&typename=" + contentType,
					type: "GET",
					datatype: "json",
					success: function(data,status,req){
						
						var currentValueArray = ("#lcase(stobj.lSummaryFields)#").split(",");
						
						for (var x = 0; x < data.length; x++) {
							
							var html = '<label><input type="checkbox" name="lSummaryFields" value="' + data[x].toLowerCase() + '"';
							
							if (currentValueArray.indexOf(data[x].toLowerCase()) > -1) {
								html = html + ' checked="checked"';
							}
							
							html = html + ' />' + data[x] + '</label>';
							
							lSummaryFields.append(html);
						}
						
					},
					error: function(req,status,err){
						
						var contentType = $j('###generalPrefix#contentType');
						var message = '<p class="errorField">There was an error loading the fields for that content type.  Make sure you have created an web server mapping for #application.fapi.getConfig(key = 'solrserver', name = 'pluginWebRoot')#. See documentation for more information.</p>';
						
						contentType.closest(".ctrlHolder").addClass("error").prepend(message);
						
					},
					cache: false
				});
			}

		</script>
		</cfoutput>
	</skin:htmlhead>
	
</ft:form>

<cfsetting enablecfoutputonly="false" />
/// Deprecated. Use <class>JLD.YouTube.UI.WatchHistoryManual</class>.
Class JLD.YouTube.UI.WatchHistory Extends %ZEN.Component.page
{

/// Class name of application this page belongs to.
Parameter APPLICATION;

/// Displayed name of this page.
Parameter PAGENAME;

/// Domain used for localization.
Parameter DOMAIN;

/// This Style block contains page-specific CSS style definitions.
XData Style
{
<style type="text/css">
</style>
}

/// This XML block defines the contents of this page.
XData Contents [ XMLNamespace = "http://www.intersystems.com/zen" ]
{
<page xmlns="http://www.intersystems.com/zen">
<spacer height="25" />
<pane align="center" paneName="detailPane"/>
<text id="videoUrlClipboard" hidden="false"/>
</page>
}

XData detailPane [ XMLNamespace = "http://www.intersystems.com/zen" ]
{
<pane xmlns="http://www.intersystems.com/zen">
<tableNavigatorBar tablePaneId="pickList"/>
<tablePane 
id="pickList" 
sql="SELECT * FROM JLD_YouTube.WatchedVideo WHERE Rewatched=?"
fixedHeaders="false"
maxRows="0"
pageSize="100"
showZebra="true"
valueColumn="ID"
useSnapshot="true"
showRowNumbers="true"
dataSource="columns"
>
<parameter id="p1" value="1"/>
<condition colName="Rewatched"
          predicate="EQ"
          value="0"
           rowStyle="background: #ff9999"/>
<condition colName="Rewatched"
          predicate="EQ"
          value="1"
           rowStyle="background: #b3ffb3"/>
<condition colName="WatchCount"
          predicate="GT"
          value="1"
           cellStyle="background: #ff00ff;"/>
<condition colName="Title"
          predicate="STARTSWITH"
          value="http"
           cellStyle="background: #ff00ff;"/>
  <column colName="VideoUrl" hidden="1"/>
  <column colName="OrigWatchTime" header="Original Watch Time"/>
  <column colName="WatchCount" header="Watch Count" />
  <column colName="Title" header="Title" link="javascript:window.open('#(%query.VideoUrl)#')"/>
  <column linkCaption="Copy" link="#" onclick="zenPage.copyToClipboard('#(%query.VideoUrl)#')"/>
  <column colName="ChannelName" header="Channel" />
  <column colName="YoutubeUsername" header="User" filterType="enum" filterEnum="mongoose08,jorge.delagarza.jr"/>
  <column colName="Rewatched" header="Rewatched?" id="idRewatched" filterType="enum" filterEnum="1,0" filterValue="1" onupdate="changeParams();" />
  <!-- <column OnDrawCell="DrawWatchedToggleCell" onclick="'toggleWatched'"/> -->
  <!-- <column OnDrawCell="DrawWatchedToggleCell" link ="#" onclick="zenPage.toggleWatched()"/> -->
  <!-- <column linkCaption="Toggle Watched" link ="#" onclick="zenPage.toggleWatchedJS('#(%query("OrigWatchTime"))#')"/> -->
  <column linkCaption="Toggle Watched" link="#" onclick="zenPage.toggleWatchedJS('#(%query.OrigWatchTime)#', this.parentNode)"/>
  <!-- <column OnDrawCell="Debug" /> -->
</tablePane>
</pane>
}

ClientMethod changeParams() [ Language = javascript ]
{
	console.log('in changeParams()');
     // find the tablePane component
     var table = zenPage.getComponentById('pickList');
     var col = zenPage.getComponentById('idRewatched');
     var param1 = zenPage.getComponentById('p1');
     param1.value=col.filterValue;
     table.executeQuery();
}

ClientMethod copyToClipboard(videoUrl) [ Language = javascript ]
{
	console.log(videoUrl);
	
	zenPage.getComponentById('videoUrlClipboard').setValue(videoUrl);
	
  var copyText = document.getElementById("control_19");
  copyText.select();
  copyText.setSelectionRange(0, 99999)
  document.execCommand("copy");
  console.log("Copied the text: " + copyText.value);
	
	console.log('ok');
}

ClientMethod toggleWatchedJS(id, ref) [ Language = javascript ]
{
	var ok = this.ToggleWatched(id);
	if (ok == 0)
	{
		alert('Error updating "Rewatched" value of video');
		return;
	}
	if (ref.previousElementSibling.innerHTML == 1)
	{
		ref.previousElementSibling.innerHTML = 0;
	}
	else
	{
		ref.previousElementSibling.innerHTML = 1
	}
}

ClassMethod ToggleWatched(pId As %String) As %Boolean [ ZenMethod ]
{
	if ('##class(JLD.YouTube.WatchedVideo).%ExistsId(pId))
	{
		quit 0
	}
	set tVid = ##class(JLD.YouTube.WatchedVideo).%OpenId(pId)
	set tVid.Rewatched = 'tVid.Rewatched
	set tSC = tVid.%Save()
	quit +tSC
}

Method DrawWatchedToggleCell(pThis As %ZEN.Component.tablePane, pName, pSeed) As %Status
{
	if (%query("Rewatched"))
	{
		write !, "Mark unwatched"
	}
	else
	{
		write !, "Mark watched"
	}
	quit 1
}

ClassMethod Debug(pThis As %ZEN.Component.tablePane, pName, pSeed) As %Status
{
	write
	quit 1
}

}


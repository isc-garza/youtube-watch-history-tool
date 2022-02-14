Include %occStatus

/// After getting frustrated with trying to get the behavior I want out of a
/// ZEN tablepane for the table, I decided to start over, creating the table
/// "manually", that is, generating the table HTML with hand-written COS code
/// and <html> elements.
Class JLD.YouTube.UI.WatchHistoryManual Extends %ZEN.Component.page
{

Parameter STARTROWNUM As %Integer = 236;

Parameter ROWCOUNT As %Integer = 250;

XData Style
{
<style type="text/css">
	BODY
	{
		padding-left: 10px;
		background-color: black;
		color: white;
	}
	
	td
	{
		border-bottom-style: solid;
		border-bottom-width: 1px;
		border-right-style: solid;
		border-right-width: 1px;
	}
	tr.watched,tr.unwatched,tr.modified
	{
		color: black;
	}
	tr.watched
	{
		background-color: #bbff99;
	}
	tr.unwatched
	{
		/*background-color: #ffccb3;*/
		background-color: #7a3535;
	}
	tr.modified
	{
		background-color: #ffff99;
	}
	
	td.watchedMultiple
	{
		color: #ff00ff;
		font-weight: bold;
	}
	a.unavailable
	{
		color: #cc0000;
		font-weight: bold;
	}
	td.removedVideo
	{
	}
	
	a
	{
		/*color: rgb(0, 0, 238);*/
		color: #4a5cff;
	}
</style>
}

XData Contents [ XMLNamespace = "http://www.intersystems.com/zen" ]
{
<page xmlns="http://www.intersystems.com/zen" title="">
<!--
<checkbox id="cbShowUnavail" value="0" caption="Show unavailable" onchange="zenPage.getComponentById('htmlContent').refreshContents()" />
<checkbox id="cbShowRemoved" value="0" caption="Show removed" onchange="zenPage.getComponentById('htmlContent').refreshContents()" />
<checkbox id="cbShowWatched" value="0" caption="Show Rewatched" onchange="zenPage.getComponentById('htmlContent').refreshContents(0)" />
-->
<checkbox id="cbShowUnavail" value="0" caption="Show unavailable" onchange ="zenPage.refreshContents()" />
<checkbox id="cbShowRemoved" value="0" caption="Show removed" onchange ="zenPage.refreshContents()" />
<checkbox id="cbShowWatched" value="0" caption="Show Rewatched" onchange ="zenPage.refreshContents()" />
<checkbox id="cbShowSkipped" value="0" caption="Show Skipped" onchange ="zenPage.refreshContents()" />
<html id="htmlContent" OnDrawContent="HTMLDrawContent" />
</page>
}

Method HTMLDrawContent(pSeed As %String) As %Status
{
	#define WHERE	"WHERE"
	
	#define YTPlaylistUrlPrefix	"https://www.youtube.com/watch_videos?video_ids="
	#define YTVideoUrlPrefix	"https://www.youtube.com/watch?v="
	
	try
	{
		set tSC = $$$OK
		set tDebug = ''$G(^jld("debug"))
		//set tDebug = 1
		
		set tRewatchedCountResult = ##class(%SQL.Statement).%ExecDirect(,"SELECT COUNT(*) AS RewatchedCount FROM JLD_YouTube.WatchedVideo WHERE Rewatched=1")
		$$$ThrowSQLIfError(tRewatchedCountResult.%SQLCODE,tRewatchedCountResult.%Message)
		if ('tRewatchedCountResult.%Next(.tSC))
		{
			$$$ThrowStatus($$$ERROR($$$GeneralError, "Rewatched count query returned no rows"))
		}
		$$$ThrowOnError(tSC)
		set tRewatchedCount = tRewatchedCountResult.%Get("RewatchedCount")
		&html<<div>Videos rewatched: #(tRewatchedCount)#</div>>
		
		set tRemainingCountResult = ##class(%SQL.Statement).%ExecDirect(,"SELECT COUNT(*) AS RemainingCount FROM JLD_YouTube.WatchedVideo WHERE Rewatched=0 AND Skipped=0 AND Unavailable=0 AND Removed=0")
		$$$ThrowSQLIfError(tRemainingCountResult.%SQLCODE,tRemainingCountResult.%Message)
		if ('tRemainingCountResult.%Next(.tSC))
		{
			$$$ThrowStatus($$$ERROR($$$GeneralError, "Rewatched count query returned no rows"))
		}
		$$$ThrowOnError(tSC)
		set tRemainingCount = tRemainingCountResult.%Get("RemainingCount")
		&html<<div>Videos remaining: #(tRemainingCount)# (#($E(tRemainingCount/(tRemainingCount+tRewatchedCount)*100,1,2))#%)</div>>
		
		set tUnavailable = ..%GetComponentById("cbShowUnavail").value
		set tRemoved = ..%GetComponentById("cbShowRemoved").value
		set tRewatched = ..%GetComponentById("cbShowWatched").value
		set tSkipped = ..%GetComponentById("cbShowSkipped").value
		
		kill tRawSQL
		set tRawSQL($I(tRawSQL)) = "SELECT * FROM JLD_YouTube.WatchedVideo"
		if (tUnavailable=0)||(tRemoved=0)||(tRewatched=0)
		{
			set tRawSQL($I(tRawSQL)) = $$$WHERE
			
			if (tUnavailable = 0)
			{
				set tRawSQL($I(tRawSQL)) = "Unavailable=0"
			}
			if (tRemoved = 0)
			{
				if (tRawSQL(tRawSQL) '= $$$WHERE)
				{
					set tRawSQL($I(tRawSQL)) = "AND"
				}
				set tRawSQL($I(tRawSQL)) = "Removed=0"
			}
			if (tRewatched = 0)
			{
				if (tRawSQL(tRawSQL) '= $$$WHERE)
				{
					set tRawSQL($I(tRawSQL)) = "AND"
				}
				set tRawSQL($I(tRawSQL)) = "Rewatched=0"
			}
			if (tSkipped = 0)
			{
				if (tRawSQL(tRawSQL) '= $$$WHERE)
				{
					set tRawSQL($I(tRawSQL)) = "AND"
				}
				set tRawSQL($I(tRawSQL)) = "Skipped=0"
			}
		}
		merge:tDebug ^jld($I(^jld),"tRawSQL") = tRawSQL
		set tStatement = ##class(%SQL.Statement).%New()
		set tSC = tStatement.%Prepare(.tRawSQL)
		$$$ThrowOnError(tSC)
		set tResult = tStatement.%Execute()
		Throw:tResult.%SQLCODE<0 ##class(%Exception.SQL).CreateFromSQLCODE(tResult.%SQLCODE, tResult.%Message)

		set tPlaylistUrl = $$$YTPlaylistUrlPrefix

		&html<
		
			<br>
			<label>Launch playlist starting from: </label>
			<input type="text" id="idStartFrom" style="width:50px"></input>
			<button type="button">Go</button>
			<br><br>
		
			<table class='idTblWatchedVideos'>
				<tr>
					<th></th>
					<th>Original Watch Time</th>
					<th>Watch Count</th>
					<th>Video Title</th>
					<th>Channel Name</th>
					<th>Watched As</th>
					<th>Rewatched?</th>
					<th style='width: 120px;'></th>
					<th>Skipped?</th>
					<th style='width: 120px;'></th>
				</tr>
				<tbody>
		>
		kill tCount
		set tPlaylistCount = 0
		while (tResult.%Next(.tSC))
		{
			$$$ThrowOnError(tSC)
			set tRowClass = $S(tResult.Rewatched:"watched", 1:"unwatched")
			&html<
				<tr class='#(tRowClass)#'>
					<td>#($i(tRowNum))#</td>
					<td>
						#($TR($P(tResult.OrigWatchTime,":",1,2),"T", " "))#
					</td>
					<td class='#($S(tResult.WatchCount'=1:"watchedMultiple", 1:""))#' style='text-align: center'>
						#(tResult.WatchCount)#
					</td>
					<td>
						<a href='#(tResult.VideoUrl)#' target='_blank' class='#($S(tResult.Unavailable:"unavailable", 1:""))#'>
							#($ZCVT(tResult.Title, "I", "UTF8"))#
						</a>
					</td>
					<td>
						<a href='#(tResult.ChannelUrl)#' target='_blank'>
							#($ZCVT(tResult.ChannelName,"I","UTF8"))#
						</a>
					</td>
					<td>
						#(tResult.YoutubeUsername)#
					</td>
					<td style='text-align: center'>
						#(tResult.Rewatched)#
					</td>
					<td style='cursor: pointer;' onclick='zenPage.toggleWatchedJS("#(tResult.OrigWatchTime)#",this)'>
						#($S(tResult.Rewatched:"Mark Unwatched", 1:"Mark Watched"))#
					</td>
					<td style='text-align: center'>
						#(tResult.Skipped)#
					</td>
					<td style='cursor: pointer;' onclick='zenPage.toggleSkippedJS("#(tResult.OrigWatchTime)#",this)'>
						#($S(tResult.Skipped:"Unmark Skipped", 1:"Mark Skipped"))#
					</td>
				</tr>
			>
			
			if ($I(tCount) >= ..#ROWCOUNT)
			{
				quit
			}
			if ('tResult.Unavailable)&&('tResult.Removed)&&(tPlaylistCount<50)
			{
				set tVideoId = $P(tResult.VideoUrl, $$$YTVideoUrlPrefix, 2)
				if (tVideoId '= "")
				{
					set tPlaylistUrl = tPlaylistUrl_tVideoId_","
					set tPlaylistCount = tPlaylistCount+1
				}
			}
		}
		
		
		
		
		
		set tRowCount = 0
		set tPlaylistCount = 0
		set tPlaylistUrl = $$$YTPlaylistUrlPrefix
		set tResult = tStatement.%Execute()
		Throw:tResult.%SQLCODE<0 ##class(%Exception.SQL).CreateFromSQLCODE(tResult.%SQLCODE, tResult.%Message)
		while (tResult.%Next(.tSC))
		{
			$$$ThrowOnError(tSC)
			if ('tResult.Unavailable)&&('tResult.Removed)
			{
				continue:(..#STARTROWNUM>0)&&($I(tRowCount)<..#STARTROWNUM)
				set tVideoId = $P(tResult.VideoUrl, $$$YTVideoUrlPrefix, 2)
				if (tVideoId '= "")
				{
					set tPlaylistUrl = tPlaylistUrl_tVideoId_","
				}
			}
			quit:$I(tPlaylistCount)>=50
		}
		
		

		&html<
			</tbody>
			</table>
			<a target='_blank' href='#(tPlaylistUrl)#'>Watch first 50 in playlist</a>
		>
	}
	catch (tException)
	{
		set tSC = tException.AsStatus()
		set:tDebug ^jld($I(^jld)) = "Error at "_$ZDT($H,3)_":", ^jld($I(^jld)) = tSC
		
	}
	quit tSC
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
		ref.innerHTML = 'Mark Watched';
	}
	else
	{
		ref.previousElementSibling.innerHTML = 1
		ref.innerHTML = 'Mark Unwatched';
	}
	ref.parentNode.className = 'modified';
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

ClientMethod toggleSkippedJS(id, ref) [ Language = javascript ]
{
	var ok = this.ToggleSkipped(id);
	if (ok == 0)
	{
		alert('Error updating "Skipped" value of video');
		return;
	}
	if (ref.previousElementSibling.innerHTML == 1)
	{
		ref.previousElementSibling.innerHTML = 0;
		ref.innerHTML = 'Mark Skipped';
	}
	else
	{
		ref.previousElementSibling.innerHTML = 1
		ref.innerHTML = 'Unmark Skipped';
	}
	ref.parentNode.className = 'modified';
}

ClassMethod ToggleSkipped(pId As %String) As %Boolean [ ZenMethod ]
{
	
	if ('##class(JLD.YouTube.WatchedVideo).%ExistsId(pId))
	{
		quit 0
	}
	set tVid = ##class(JLD.YouTube.WatchedVideo).%OpenId(pId)
	set tVid.Skipped = 'tVid.Skipped
	set tSC = tVid.%Save()
	quit +tSC
}

}


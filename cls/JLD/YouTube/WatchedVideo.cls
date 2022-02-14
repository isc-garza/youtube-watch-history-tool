Class JLD.YouTube.WatchedVideo Extends %Persistent
{

Property Title As %String(MAXLEN = "");

Property VideoUrl As %String(MAXLEN = "");

Property ChannelName As %String(MAXLEN = "");

Property ChannelUrl As %String(MAXLEN = "");

Property OrigWatchTime As %String;

/// This has to be something other that "User", as that breaks the ZEN UI for
/// some reason.
Property YoutubeUsername As %String;

Property Rewatched As %Boolean [ InitialExpression = 0 ];

Property Skipped As %Boolean [ InitialExpression = 0 ];

Property WatchCount As %Integer;

Property Unavailable As %Boolean [ SqlComputeCode = {set {*} = ({VideoUrl}={Title})}, SqlComputed, Transient ];

Property Removed As %Boolean [ SqlComputeCode = {set {*} = (({VideoUrl}="") && ({Title}="a video that has been removed"))}, SqlComputed, Transient ];

Index OrigWatchTimeIdx On OrigWatchTime [ IdKey, Unique ];

Index VideoUrlIdx On VideoUrl;

ClassMethod ImportFromJSONFile(pFilename As %String, pUser As %String) As %Status
{
	try
	{
		set tSC = $$$OK
		set tFileStream = ##class(%Stream.FileCharacter).%New()
		set tSC = tFileStream.LinkToFile(pFilename)
		if ($$$ISERR(tSC))
		{
			quit
		}
		set tDynArr = ##class(%Library.DynamicArray).%FromJSON(tFileStream)
		set tIter = tDynArr.%GetIterator()
		while (tIter.%GetNext(.tWatchRecordKey, .tWatchRecordObj))
		{
			set tStoredRecord = ..%New()
			set tStoredRecord.YoutubeUsername = pUser
			if ($E(tWatchRecordObj.title,1,8) = "Watched ")
			{
				set tStoredRecord.Title = $E(tWatchRecordObj.title,9,*)
			}
			else
			{
				set tStoredRecord.Title = tWatchRecordObj.title
			}
			set tStoredRecord.VideoUrl = tWatchRecordObj.titleUrl
			set tStoredRecord.OrigWatchTime = tWatchRecordObj.time
			
			write !!!, tWatchRecordKey_": "
			write !, "Title: "_tWatchRecordObj.title
			write !, "URL: "_tWatchRecordObj.titleUrl
			write !, "Date: "_tWatchRecordObj.time
			if ($IsObject(tWatchRecordObj.subtitles))
			{
				set tSubtitlesIter = tWatchRecordObj.subtitles.%GetIterator()
				while (tSubtitlesIter.%GetNext(.tSubtitlesKey, .tSubtitlesObj))
				{
					if (tSubtitlesKey '= 0)
					{
						$$$ThrowStatus($$$ERROR($$$GeneralError, "'subtitles' array with more than one element found: "_tWatchRecordKey))
					}
					set tStoredRecord.ChannelName = tSubtitlesObj.name
					set tStoredRecord.ChannelUrl = tSubtitlesObj.url
					
					write !, "Channel: "_tSubtitlesObj.name
					write !, "Channel URL: "_tSubtitlesObj.url
				}
			}
			$$$ThrowOnError(tStoredRecord.%Save())
		}
	}
	catch (tException)
	{
		set tSC = tException.AsStatus()
	}
	if ($$$ISERR(tSC))
	{
		write !, $system.Status.GetOneErrorText(tSC)
	}
	quit tSC
}

ClassMethod CalculateWatchCounts() As %Status
{
	try
	{
		set tSC = $$$OK
		set tUrl = ""
		for
		{
			set tUrl = $O(^JLD.YouTube.WatchedVideoI("VideoUrlIdx",tUrl))
			if (tUrl = " ")
			{
				continue
			}
			if (tUrl = "")
			{
				quit
			}
			set tWatchCount = 0
			set tId = ""
			for
			{
				set tId = $O(^JLD.YouTube.WatchedVideoI("VideoUrlIdx",tUrl,tId))
				if (tId = "")
				{
					quit
				}
				set tVid = ##class(JLD.YouTube.WatchedVideo).%OpenId(tId)
				set tVid.WatchCount = $I(tWatchCount)
				set tSC = tVid.%Save()
				$$$ThrowOnError(tSC)
			}
		}
	}
	catch (tException)
	{
		set tSC = tException.AsStatus()
	}
	quit tSC
}

ClassMethod InspectJSONFile(pFilename As %String) As %Status
{
	try
	{
		set tSC = $$$OK
		
		set KNOWNPROPS = $LISTBUILD("header","title","titleUrl","subtitles","time","products")
		set KNOWNSUBTITLEPROPS = $LISTBUILD("name","url")
		
		set tFileStream = ##class(%Stream.FileCharacter).%New()
		set tSC = tFileStream.LinkToFile(pFilename)
		if ($$$ISERR(tSC))
		{
			quit
		}
		set tDynArr = ##class(%Library.DynamicArray).%FromJSON(tFileStream)
		// Iteratate over top-level array
		set tIter = tDynArr.%GetIterator()
		while (tIter.%GetNext(.tWatchRecordKey, .tWatchRecordObj))
		{
			// Iterate over the properties in one watch record
			set tWatchRecordIter = tWatchRecordObj.%GetIterator()
			while (tWatchRecordIter.%GetNext(.tWatchRecordProp, .tWatchRecordVal))
			{
				// Assert that every property of a watch record is one that we know about.
				if ('$LISTFIND(KNOWNPROPS, tWatchRecordProp))
				{
					write !, "Unknown property: "_tWatchRecordProp
				}
				
				if (tWatchRecordProp = "subtitles")
				{
					// Iterate over the "subtitles" array.
					set tSubtitlesIter = tWatchRecordVal.%GetIterator()
					while (tSubtitlesIter.%GetNext(.tSubtitlesIdx, .tOneSubtitleObj))
					{
						// Assert that there is no more than one element in the "subtitles" array
						if (tSubtitlesIdx '= 0)
						{
							write !, "Subtitles array found with >1 element: "_tWatchRecordKey
						}
						
						// Iterate over the properties of a single "subtitle" object
						set tOneSubtitleIter = tOneSubtitleObj.%GetIterator()
						while (tOneSubtitleIter.%GetNext(.tOneSubtitleProp, .tOneSubtitleVal))
						{
							// Assert that every property of the subtitle is one that we know about.
							if ('$LISTFIND(KNOWNSUBTITLEPROPS, tOneSubtitleProp))
							{
								write !, "Unknown subtitle property: "_tOneSubtitleProp
							}
						}
					}
				}
				// Assert that timestamp is unique
				elseif (tWatchRecordProp = "time")
				{
					if ($D(tTimestamps(tWatchRecordVal)))
					{
						write !, "Non-unique timestamp found: "_tWatchRecordVal
					}
					else
					{
						set tTimestamps(tWatchRecordVal) = ""
					}
				}
				// Assert that title always starts with "Watched "
				elseif (tWatchRecordProp = "title")
				{
					if ($E(tWatchRecordVal,1,8) '= "Watched ")
					{
						write !, "Title does not start with 'Watched ':"_tWatchRecordVal
					}
				}
			}
		}
	}
	catch (tException)
	{
		set tSC = tException.AsStatus()
	}
	if ($$$ISERR(tSC))
	{
		write !!, $system.Status.GetOneErrorText(tSC)
	}
	write !, "Done."
	quit tSC
}

Storage Default
{
<Data name="WatchedVideoDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Title</Value>
</Value>
<Value name="3">
<Value>VideoUrl</Value>
</Value>
<Value name="4">
<Value>ChannelName</Value>
</Value>
<Value name="5">
<Value>ChannelUrl</Value>
</Value>
<Value name="6">
<Value>OrigWatchTime</Value>
</Value>
<Value name="7">
<Value>YoutubeUsername</Value>
</Value>
<Value name="8">
<Value>Rewatched</Value>
</Value>
<Value name="9">
<Value>WatchCount</Value>
</Value>
<Value name="10">
<Value>Unavailable</Value>
</Value>
<Value name="11">
<Value>Skipped</Value>
</Value>
</Data>
<DataLocation>^JLD.YouTube.WatchedVideoD</DataLocation>
<DefaultData>WatchedVideoDefaultData</DefaultData>
<IdLocation>^JLD.YouTube.WatchedVideoD</IdLocation>
<IndexLocation>^JLD.YouTube.WatchedVideoI</IndexLocation>
<StreamLocation>^JLD.YouTube.WatchedVideoS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}


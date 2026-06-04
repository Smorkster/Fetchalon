<#
.Synopsis
	A collection of functions to run for a user object
.Description
	A collection of functions to run for a user object
.State
	Prod
.Author
	Smorkser (smorkster)
#>

param ( $culture = "sv-SE" )

function Clear-FileDownloads
{
	<#
	.Synopsis
		Clear downloads
	.Description
		Remove all files older than one week
	.State
		Prod
	.Note
		Warning | Window will freeze during execution
	.RequiredAdGroups
		Role_Servicedesk_BO
	.SearchedItemRequest
		None
	.NoRunspace
	.OutputType
		String
	.Author
		Smorkster (smorkster)
	#>

	Import-Module ActiveDirectory -Force
	$ReturnText = [System.Text.StringBuilder]::new()

	Get-ChildItem $IntMsgTable.StrClearFileDownloadsCodeDirPath -File -Recurse -Force | `
		Where-Object { $_.CreationTime -lt ( Get-Date ).AddDays( -7 ) } | `
		ForEach-Object `
			-Begin {
				$FaultyRemovals = [System.Collections.ArrayList]::new()
				$FileCount = 0
				$FileSizeSum = 0
			} `
			-Process {
				try
				{
					$TempSize = $_.Length
					$_.FullName
					Remove-Item -LiteralPath $_.FullName -Force -ErrorAction Stop -Verbose
					$FileCount += 1
					$FileSizeSum += $TempSize
				}
				catch
				{
					$FaultyRemovals.Add( $_ ) | Out-Null
				}
			} `
			-End {
				if ( 0 -eq $FileCount )
				{
					$ReturnText.AppendLine( $IntMsgTable.StrClearFileDownloadsNoFiles ) | Out-Null
				}
				else
				{
					$ReturnText.AppendLine( "$( $FileCount ) $( $IntMsgTable.StrClearFileDownloadsOld )" ) | Out-Null
					$ReturnText.AppendLine( "$( $IntMsgTable.StrClearFileDownloadsRemovedSize ) $( [System.Math]::Round( $FileSizeSum / 1MB , 2 ) )" ) | Out-Null

					if ( $FaultyRemovals.Count -gt 0 )
					{
						$ReturnText.AppendLine() | Out-Null
						$ReturnText.AppendLine( "$( $FaultyRemovals.Count ):" ) | Out-Null
						$FaultyRemovals | `
							ForEach-Object {
								$ReturnText.AppendLine( $_.FullName ) | Out-Null
							}
					}
				}
			}

	try
	{
		$Info = "{""User"":""$( ( Get-ADUser $env:USERNAME.Substring( $env:USERNAME.Length - 4 ) ).SamAccountName )"",""Info"":""$( $ReturnText.ToString() )""}"

		Invoke-RestMethod -Uri "https://<Azure address>/" `
			-Method Post `
			-ContentType "application/json" `
			-Body ( [System.Text.Encoding]::UTF8.GetBytes( $Info ) )
	}
	catch
	{
		$ReturnText.AppendLine() | Out-Null
		$ReturnText.AppendLine( $IntMsgTable.StrClearFileDownloadsNoMail ) | Out-Null
		$ReturnText.AppendLine( $_.Exception.Message ) | Out-Null
	}

	return $ReturnText.ToString()
}

function Get-PollenRapport
{
	<#
	.Synopsis
		Download today's pollen report
	.Description
		Download today's pollen report from Pollenrapporten.se
	.MenuItem
		Today's pollen report
	.SearchedItemRequest
		None
	.InputDataList
		Stad | True | Välj stad att visa prognos för | Stockholm | Stockholm,Borlänge,Forshaga,Gävle,Jönköping,Visby,Bräkne-Hoby,Göteborg,Hässleholm,Kristianstad,Malmö,Nässjö,Eskilstuna,Norrköping,Skövde,Sundsvall,Umeå,Västervik,Östersund,Piteå,Kiruna,Ljusdal
	.NoRunspace
	.EnableQuickAccess
		pollen
	.OutputType
		ObjectList
	.State
		Prod
	.Author
		Smorkster (smorkster)
	#>

	param ( $InputData )

	$PList = [System.Collections.Generic.List[object]]::new()
	$Date = Get-Date -Format "yyyy-MM-dd"
	$PollenTypes = @{}
	$CityId = ""

	$CityList = ( Invoke-RestMethod -Uri "https://api.pollenrapporten.se/v1/regions" -Method Get ).items
	foreach ( $i in $CityList )
	{
		if ( $InputData.Stad.Equals( $i.name.Replace( "Ã¥", "å" ).Replace( "Ã¤", "ä" ).Replace( "Ã¶", "ö" ) ) )
		{
			$CityId = $i.id
			break
		}
	}

	$PT = ( Invoke-RestMethod -Uri "https://api.pollenrapporten.se/v1/pollen-types" -Method get ).items
	foreach ( $t in $PT )
	{
		$n = $t.name.Replace( "Ã¥", "å" ).Replace( "Ã¤", "ä" ).Replace( "Ã¶", "ö" )
		$PollenTypes[$t.id] = $n
	}

	$PollenForecast = ( Invoke-RestMethod -Uri "https://api.pollenrapporten.se/v1/forecasts?region_id=$( $CityId )&current=true" -Method Get -ContentType "application/json" ).items[0].levelSeries
	foreach( $item in $PollenForecast )
	{
		if ( $item.level -eq 0 -or -not $Item.time.StartsWith( $Date ) )
		{
			continue
		}
		$p = [pscustomobject]@{
			$IntMsgTable.GetPollenRapportTitle1 = $PollenTypes[ $item.pollenId ]
			$IntMsgTable.GetPollenRapportTitle2 = $item.level
		}
		$PList.Add( $p ) | Out-Null
	}

	return $PList
}

function Get-SomeFiles
{
	<#
	.Synopsis
		Get files
	.Description
		Get files. Used to show how output is displayed
	.MenuItem
		Get files
	.SearchedItemRequest
		None
	.OutputType
		ObjectList
	.State
		Dev
	.Author
		Smorkster (smorkster)
	#>

	$List = [System.Collections.Generic.List[object]]::new()

	try
	{
		$Files = Get-ChildItem C:\
		foreach ( $File in $Files )
		{
			$FileObj = [pscustomobject]@{
				Name = $File.Name
				Extension = $File.Extension
				LastWriteTime = $File.LastWriteTime
				IsNotDir = $true
				Size = ""
			}

			if ( $File -is [System.IO.DirectoryInfo] )
			{
				$FileObj.IsNotDir = $false
				$FileObj.Extension = $IntMsgTable.GetSomeFilesFolder
			}

			$FileObj.Size = if ( $File -is [System.IO.DirectoryInfo] ) { 0 }
				elseif ( $File.Length -lt 1kB ) { "$( $File.Length ) B" }
				elseif ( $File.Length -gt 1kB -and $File.Length -lt 1MB ) { "$( [math]::Round( ( $File.Length / 1kB ), 2 ) ) kB" }
				elseif ( $File.Length -gt 1MB -and $File.Length -lt 1GB ) { "$( [math]::Round( ( $File.Length / 1MB ), 2 ) ) MB" }
				elseif ( $File.Length -gt 1GB -and $File.Length -lt 1TB ) { "$( [math]::Round( ( $File.Length / 1GB ), 2 ) ) GB" }

			$List.Add( $FileObj ) | Out-Null
		}
	}
	catch
	{}

	if ( $null -eq $List )
	{
		return $null
	}
	else
	{
		$sorted = $List | `
			Sort-Object IsNotDir, Extension, Name | `
			Select-Object Name, Extension, LastWriteTime, Size

		return $sorted
	}
}

function Get-String
{
	<#
	.Synopsis
		Get string
	.MenuItem
		Get string
	.Note
		Warning | Test warning
	.SearchedItemRequest
		None
	.OutputType
		String
	.Description
		Get string. Used to show how output is displayed
	.State
		Dev
	.Author
		Smorkster (smorkster)
	#>

	Write-Progress "Should write to progress..."
	WriteLog -Text "Test" -Success $true | Out-Null
	Write-Progress "Wrote to progress"

	return "A string"
}

function Get-StringList
{
	<#
	.Synopsis
		Get stringlist
	.MenuItem
		Get stringlist
	.SearchedItemRequest
		None
	.OutputType
		List
	.Description
		Get stringlist. Used to show how output is displayed
	.State
		Dev
	.Author
		Smorkster (smorkster)
	#>

	$s = [System.Collections.Generic.List[string]]::new()

	foreach ( $a in 0..50 ) { [void] $s.Add( "En string" ) }

	return $s
}

function Get-TemaDagar
{
	<#
	.Synopsis
		Get todays theme days
	.Description
		Get todays theme days from TemaDagar.se
	.MenuItem
		Get the theme days for today
	.SearchedItemRequest
		None
	.OutputType
		ObjectList
	.State
		Prod
	.Author
		Smorkster (smorkster)
	#>

	$List = [System.Collections.ArrayList]::new()
	$BaseUri = "https://temadagar.se"
	$req = Invoke-WebRequest -Method Get -Uri "$( $BaseUri )/$( Get-Date -Format "d-MMMM" )/" -UseBasicParsing
	$req.Content -match "(?s)id=""content"".*?(?<Links><p>.*?)Ezoic" | Out-Null
	[regex]::Matches( $Matches.Links , "(?s)<a href=""(?<L>.*?)"">(?<T>.*?)<" ) | `
		ForEach-Object {
			$List.Add( [pscustomobject]@{ Text = $_.Groups['T'].Value ; Address = "$BaseUri$( $_.Groups['L'] )" ; Type = "Hyperlink" } ) | Out-Null
		}

	if ( 0 -eq $List.Count )
	{
		return $IntMsgTable.GetTemaDagarNoThemeDays
	}

	return $List
}

function Test-Error
{
	<#
	.Synopsis
		Test error
	.MenuItem
		Test error
	.SearchedItemRequest
		None
	.OutputType
		String
	.Description
		Test for how errors are displayed
	.State
		Dev
	.Author
		Smorkster (smorkster)
	#>

	0/0
}

function Test-HyperlinkObjectList
{
	<#
	.Synopsis
		Show list with hyperlinks
	.MenuItem
		Show list with hyperlinks
	.SearchedItemRequest
		None
	.OutputType
		ObjectList
	.Description
		Show list with hyperlinks
	.State
		Dev
	.Author
		Smorkster (smorkster)
	#>

	$List = [System.Collections.ArrayList]::new()
	$List.Add( ( [pscustomobject]@{ Text = "Ecosia" ; Address = "https://www.ecosia.org" ; Type = "Hyperlink" } ) ) | Out-Null
	$List.Add( ( [pscustomobject]@{ Text = "Power Automate" ; Address = "https://make.powerautomate.com/" ; Type = "Hyperlink" } ) ) | Out-Null

	return $List
}

function Test-StreamOutput
{
	<#
	.Synopsis
		Test progress through runspace streams
	.MenuItem
		Test streams output
	.SearchedItemRequest
		None
	.OutputType
		String
	.Description
		Test progress output throught runspace streams
	.State
		Test
	.Author
		Smorkster (smorkster)
	#>

	Write-Progress "Info" -PercentComplete 5
	Write-Information "Information  Test Message"
	Write-Progress "Debug" -PercentComplete 15
	Write-Debug "Debug Test Message"
	Write-Progress "Error" -PercentComplete 25
	Write-Error "Error Test Message"
	Write-Progress "Verbose" -PercentComplete 35
	Write-Verbose "Verbose Test Message"
	Write-Progress "Warning" -PercentComplete 45
	Write-Warning "Warning Test Message"
	Write-Progress "Progress" -PercentComplete 55

	foreach ( $p in 0..10 )
	{
		$p = $p * 10
		Write-Progress "Progress Test Message $p" -PercentComplete ( [int]$p )
		Start-Sleep -Seconds 1
	}
	Start-Sleep -Seconds 5
}

function Test-WriteError
{
	<#
	.Synopsis
		Test writing to errorlog
	.MenuItem
		Test Errorlog
	.SearchedItemRequest
		None
	.OutputType
		String
	.Description
		Test for using function to write to errorlog
	.State
		Dev
	.Author
		Smorkster (smorkster)
	#>

	return ( WriteErrorlog -LogText "Test" -UserInput "" -Severity 1 ).ErrorLogFile
}

function Write-String
{
	<#
	.Synopsis
		Write string as input
	.MenuItem
		Write string
	.SearchedItemRequest
		None
	.OutputType
		String
	.Description
		Write string as input. Used to show how output is displayed
	.InputDataList
		Strings| True| | | 1,2,3,4
	.InputData
		String, True, String to write
	.InputData
		String2, True, String to write
	.State
		Dev
	.Author
		Smorkster (smorkster)
	#>

	param ( $InputData )

	Start-Sleep -Seconds 1

	return "$( $InputData.String ) $( $InputData.String2 ) $( $InputData.Strings )"
}

$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.Parent.FullName

Import-LocalizedData -BindingVariable IntMsgTable -UICulture $culture -FileName "$( ( $PSCommandPath.Split( "\" ) | Select-Object -Last 1 ).Split( "." )[0] ).psd1" -BaseDirectory "$RootDir\Localization"

Export-ModuleMember -Function *

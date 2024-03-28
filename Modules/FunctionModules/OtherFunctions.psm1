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
	.RequiredAdGroups
		Role_Servicedesk_BO
	.SearchedItemRequest
		None
	.NoRunspace
	.Author
		Smorkster (smorkster)
	#>

	Import-Module ActiveDirectory -Force
	$Files = Get-ChildItem $IntMsgTable.StrClearFileDownloadsCodeDirPath -File -Recurse -Force
	$Removed = [System.Collections.ArrayList]::new()
	$ReturnText = [System.Text.StringBuilder]::new()

	$filesToRemove = $Files | `
		Where-Object { $_.CreationTime -lt ( Get-Date ).AddDays( -7 ) }
	if ( 0 -lt $filesToRemove.Count )
	{
		$filesToRemove | `
			ForEach-Object `
				-Begin {
					$FaultyRemovals = [System.Collections.ArrayList]::new()
				} `
				-Process {
					$File = $_ | Select-Object *
					try
					{
						Remove-Item $File.FullName -Force -ErrorAction Stop
						$Removed.Add( $File ) | Out-Null
					}
					catch
					{
						$FaultyRemovals.Add( $File ) | Out-Null
					}
				} `
				-End {
					if ( $FaultyRemovals.Count -gt 0 )
					{
						WriteErrorlog -LogText $IntMsgTable.StrClearFileDownloadsFilePermissions -UserInput "$( $FaultyRemovals.FullName | ForEach-Object { "$( $_ -split "\\" | Select-Object -Last 2 )" } )" -Severity 3 | Out-Null
					}
				}

		$percentage = [Math]::Round( ( $filesToRemove.Count / $Files.Count ) * 100, 2 )
		$ReturnText.AppendLine( "$( $filesToRemove.Count ) $( $IntMsgTable.StrClearFileDownloadsOld ) ($percentage %)" ) | Out-Null
		$ReturnText.AppendLine() | Out-Null
		if ( $FaultyRemovals.Count -gt 0 )
		{
			$ReturnText.AppendLine( $IntMsgTable.StrClearFileDownloadsFaultyFiles ) | Out-Null
			$OFS = "`n"
			$ReturnText.AppendLine( ( $FaultyRemovals | ForEach-Object { "$( $_.Directory.Name )\$( $_.Name )" } ) ) | Out-Null
			$ReturnText.AppendLine() | Out-Null
		}

		if ( $Removed.Count -gt 0 )
		{
			$ReturnText.Append( "$( $IntMsgTable.StrClearFileDownloadsRemovedSize ): " ) | Out-Null
			$ReturnText.Append( ( $Removed | ForEach-Object -Begin { $l = 0 } -Process { $l += $_.Length } -End { [System.Math]::Round( $l / 1MB , 2 ) } ) ) | Out-Null
			$ReturnText.AppendLine( " MB" ) | Out-Null
		}
	}
	else
	{
		$ReturnText.AppendLine( $IntMsgTable.StrClearFileDownloadsNoFiles ) | Out-Null
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
	.NoRunspace
	.OutputType
		ObjectList
	.State
		Prod
	.Author
		Smorkster (smorkster)
	#>

	Add-Type -AssemblyName System.Web
	$Result = Invoke-WebRequest -Uri https://pollenrapporten.se

	( $Result.RawContent -replace "`n" ) -match "data-location=""Stockholm(?<LocationData>.*?)pp_pollentext pp_pollentext_liten c3823" | Out-Null
	$PList = [System.Collections.ArrayList]::new()
	$LocationData = $Matches.LocationData

	[regex]::Matches( $LocationData , "(<element>(?<p>.*?)<.*?value(?<pn>\d))" ) | `
		ForEach-Object {
			$PR = [pscustomobject]@{
				"$( $IntMsgTable.GetPollenRapportTitle1 )" = [System.Web.HttpUtility]::HtmlDecode( ( $_.Groups['p'].Value.Trim() ) )
				"$( $IntMsgTable.GetPollenRapportTitle2 )" = "$( $_.Groups['pn'].Value ) / 7"
			}
			$PList.Add( $PR ) | Out-Null
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
	.NoRunspace
	.State
		Dev
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item )

	$List = [System.Collections.ArrayList]::new()
	try
	{
		$files =  Get-ChildItem C:\
		$files | `
			Select-Object Name, Extension, LastWriteTime, `
				@{ Name = "IsDir"; Expression = { $_ -is [System.IO.DirectoryInfo] } }, `
				@{ Name = "Size"; Expression = {
					if ( $_ -is [System.IO.DirectoryInfo] )
					{ $IntMsgTable.GetSomeFilesFolder }
					elseif ( $_.Length -lt 1kB ) { "$( $_.Length ) B" }
					elseif ( $_.Length -gt 1kB -and $_.Length -lt 1MB ) { "$( [math]::Round( ( $_.Length / 1kB ), 2 ) ) kB" }
					elseif ( $_.Length -gt 1MB -and $_.Length -lt 1GB ) { "$( [math]::Round( ( $_.Length / 1MB ), 2 ) ) MB" }
					elseif ( $_.Length -gt 1GB -and $_.Length -lt 1TB ) { "$( [math]::Round( ( $_.Length / 1GB ), 2 ) ) GB" } } } | `
			Sort-Object @{ Expression = { $_.IsDir }; Descending = $true }, Extension, Name | `
			Select-Object Name, LastWriteTime, Size, Extension | ForEach-Object { [void] $List.Add( $_ ) }
	} catch {}
	if ( $null -eq $List )
	{
		return $null
	}
	else
	{
		return $List
	}
}

function Get-String
{
	<#
	.Synopsis
		Get string
	.MenuItem
		Get string
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

	WriteLog -Text "Test" -Success $true | Out-Null

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

	$s = [system.collections.arraylist]::new()

	0..50 | ForEach-Object { [void] $s.Add( "A string" ) }

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
		List
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

	throw "An error"
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
	.InputData
		String String to write
	.State
		Dev
	.Author
		Smorkster (smorkster)
	#>

	param ( $InputData )

	Start-Sleep -Seconds 1

	return $InputData.String
}

$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.Parent.FullName

Import-LocalizedData -BindingVariable IntMsgTable -UICulture $culture -FileName "$( ( $PSCommandPath.Split( "\" ) | Select-Object -Last 1 ).Split( "." )[0] ).psd1" -BaseDirectory "$RootDir\Localization"

Export-ModuleMember -Function *

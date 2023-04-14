<#
.Synopsis A collection of functions to run for a user object
.Description A collection of functions to run for a user object
.State Prod
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

	$files = Get-ChildItem $IntMsgTable.StrClearFileDownloadsCodeDirPath -File -Recurse -Force

	$filesToRemove = $files | `
		Where-Object { $_.CreationTime -lt ( Get-Date ).AddDays( -7 ) }
	if ( 0 -lt $filesToRemove.Count )
	{
		$filesToRemove | `
			ForEach-Object `
				-Begin {
					$FaultyRemovals = [System.Collections.ArrayList]::new()
				} `
				-Process {
					$File = $_
					try
					{
						Remove-Item $File.FullName -Force -ErrorAction Stop
					}
					catch
					{
						$FaultyRemovals.Add( $File ) | Out-Null
					}
				} `
				-End {
					if ( $FaultyRemovals.Count -gt 0 )
					{
						WriteErrorlog -LogText $IntMsgTable.StrClearFileDownloadsFilePermissions -UserInput "$( $FaultyRemovals.FullName | ForEach-Object { "$( $_ -split "\\" | Select-Object -Last 2 )" } )" -Severity 3 | Out-Null					}
				}

		$percentage = [Math]::Round( ( $filesToRemove.Count / $files.Count ) * 100, 2 )
		$t = "$( $filesToRemove.Count ) $( $IntMsgTable.StrClearFileDownloadsOld ) ($percentage %)"
	}
	else
	{
		$t = $IntMsgTable.StrClearFileDownloadsNoFiles
	}

	Send-MailMessage -From ( Get-ADUser $env:USERNAME.Substring( ( $env:USERNAME.Length - 4 ), 4 ) -Properties EmailAddress ).EmailAddress`
		-To $IntMsgTable.StrClearFileDownloadsBotAddress `
		-Body $IntMsgTable.StrClearFileDownloadsDone `
		-Encoding bigendianunicode `
		-SmtpServer $IntMsgTable.StrSMTP `
		-Subject "BotFlow1" `
		-BodyAsHtml
	return $t
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
	.Author
		Smorkster
	#>

	$List = [System.Collections.ArrayList]::new()
	$BaseUri = "https://temadagar.se/$( Get-Date -Format "d-MMMM" )/"
	$req = Invoke-WebRequest -Method Get -Uri $BaseUri

	$e = $req.ParsedHtml.getElementById( "content" )
	$l = $e.getElementsByTagName( "p" ) | Select-Object -First 1
	$l.getElementsByTagName( "a" ) | `
		ForEach-Object { $List.Add( ( [pscustomobject]@{ Address = $_.Href; Text = $_.InnerText ; Type = "Hyperlink" } ) ) | Out-Null }

	if ( 0 -eq $List.Count )
	{
		return $IntMsgTable.GetTemaDagarNoThemeDays
	}

	return $List
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
	.Author
		Smorkster
	#>

	param ( $Item )

	$List = [System.Collections.ArrayList]::new()
	try
	{
		$files =  Get-ChildItem C:\Temp
		$files | Select-Object Name, LastWriteTime, @{ Name = "Size"; Expression = { $_.Length } } | Sort-Object @{ Expression = { $_.Name } ; Descending = $true } | ForEach-Object { [void] $List.Add( $_ ) }
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
	.Description
		Get string. Used to show how output is displayed
	.MenuItem
		Get string
	.SearchedItemRequest
		None
	.OutputType
		String
	.Author
		Smorkster
	#>

	WriteLog -Text "Test" -Success $true | Out-Null

	return "A string"
}

function Get-StringList
{
	<#
	.Synopsis
		Get stringlist
	.Description
		Get stringlist. Used to show how output is displayed
	.MenuItem
		Get stringlist
	.SearchedItemRequest
		None
	.OutputType
		List
	.Author
		Smorkster
	#>

	$s = [system.collections.arraylist]::new()

	0..50 | ForEach-Object { [void] $s.Add( "A string" ) }

	return $s
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
	.Author
		Smorkster
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
	.Author
		Smorkster
	#>

	return ( WriteErrorlog -LogText "Test" -UserInput "" -Severity 1 ).ErrorLogFile
}

function Write-String
{
	<#
	.Synopsis
		Write string as input
	.Description
		Write string as input. Used to show how output is displayed
	.MenuItem
		Write string
	.SearchedItemRequest
		None
	.OutputType
		String
	.InputData
		String String to write
	.Author
		Smorkster
	#>

	param ( $InputData )

	Start-Sleep -Seconds 1

	return $InputData.String
}

$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.Parent.FullName

Import-LocalizedData -BindingVariable IntMsgTable -UICulture $culture -FileName "$( ( $PSCommandPath.Split( "\" ) | Select-Object -Last 1 ).Split( "." )[0] ).psd1" -BaseDirectory "$RootDir\Localization"

Export-ModuleMember -Function *
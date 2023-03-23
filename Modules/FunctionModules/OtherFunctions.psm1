<#
.Synopsis A collection of functions to run for a user object
.Description A collection of functions to run for a user object
.State Dev
#>

param ( $culture = "sv-SE" )

function Get-TemaDagar
{
	<#
	.Synopsis Get todays theme days
	.Description Get todays theme days from TemaDagar.se
	.MenuItem Get the theme days for today
	.SearchedItemRequest None
	.OutputType List
	.Author Smorkster
	#>

	$BaseUri = "https://temadagar.se/$( Get-Date -Format "d-MMMM" )/"
	$req = Invoke-RestMethod -Method Get -UseBasicParsing -Uri $BaseUri

	$l = ( ( ( ( $req -split "</h2>" )[1] -split "<p>" )[1] -split "</p>" )[0] -split "`n" ).Trim() -split "<br/></a>" | Where-Object { $_ } | ForEach-Object {
		$a, $t = ( $_ -replace "<A href=""" ) -split """>"
		$fa = "https://www.temadagar.se$a"
		[pscustomobject]@{ Address = $fa; Text = $t ; Type = "Hyperlink" }
	}

	return $l
}

function Get-SomeFiles
{
	<#
	.Synopsis Get files
	.Description Get files. Used to show how output is displayed
	.MenuItem Get files
	.SearchedItemRequest None
	.OutputType ObjectList
	.Author Smorkster
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
	.Synopsis Get string
	.Description Get string. Used to show how output is displayed
	.MenuItem Get string
	.SearchedItemRequest None
	.OutputType String
	.Author Smorkster
	#>

	return "A string"
}

function Write-String
{
	<#
	.Synopsis Write string as input
	.Description Write string as input. Used to show how output is displayed
	.MenuItem Write string
	.SearchedItemRequest None
	.OutputType String
	.InputData String String to write
	.Author Smorkster
	#>

	param ( $InputData )

	Start-Sleep -Seconds 1

	return $InputData.String
}

function Get-StringList
{
	<#
	.Synopsis Get stringlist
	.Description Get stringlist. Used to show how output is displayed
	.MenuItem Get stringlist
	.SearchedItemRequest None
	.OutputType List
	.Author Smorkster
	#>

	$s = [system.collections.arraylist]::new()
	0..50 | ForEach-Object { [void] $s.Add( "A string" ) }

	return $s
}

$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.Parent.FullName

Import-LocalizedData -BindingVariable IntMsgTable -UICulture $culture -FileName "$( ( $PSCommandPath.Split( "\" ) | Select-Object -Last 1 ).Split( "." )[0] ).psd1" -BaseDirectory "$RootDir\Localization"

Export-ModuleMember -Function *
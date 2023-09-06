<#
.Synopsis
	A collection of calls to separate tools/applications
.Description
	A collection of calls to separate tools/applications
.State
	Prod
.Author
	Smorkster (smorkster)
#>

param ( $culture = "sv-SE" )

function Open-ADUC
{
	<#
	.Synopsis
		Start ADUC
	.MenuItem
		ADUC
	.SearchedItemRequest
		None
	.OutputType
		None
	.State
		Prod
	.Author
		Smorkster (Smorkster)
	#>

	[System.Diagnostics.Process]::Start( "C:\Users\Public\Desktop\ADUC.msc" ) | Out-Null
}

function Open-ConfigurationManager
{
	<#
	.Synopsis
		Start Configuration Manager
	.MenuItem
		Configuration Manager
	.SearchedItemRequest
		None
	.OutputType
		None
	.State
		Prod
	.Author
		Smorkster (smorkster)
	#>

	[System.Diagnostics.Process]::Start( "C:\Program Files\Client Center for Configuration Manager\SCCMCliCtrWPF.exe" ) | Out-Null
}

function Open-PrintConsole
{
	<#
	.Synopsis
		Start PrintConsole
	.MenuItem
		Print Console
	.SearchedItemRequest
		None
	.OutputType
		None
	.State
		Prod
	.Author
		Smorkster (smorkster)
	#>

	[System.Diagnostics.Process]::Start( "C:\Users\Public\Desktop\Print Console.msc" ) | Out-Null
}

$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.Parent.FullName

Import-LocalizedData -BindingVariable IntMsgTable -UICulture $culture -FileName "$( ( $PSCommandPath.Split( "\" ) | Select-Object -Last 1 ).Split( "." )[0] ).psd1" -BaseDirectory "$RootDir\Localization"

Export-ModuleMember -Function *

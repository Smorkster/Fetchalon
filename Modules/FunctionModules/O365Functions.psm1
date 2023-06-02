<#
.Synopsis
	A collection of functions to operate with Office365-services
.Description
	A collection of functions to operate with Office365-services
.State
	Prod
#>

param ( $culture = "sv-SE" )

function Show-NotImplemented
{
	<#
	.Synopsis
		Inform that O365 is not implemented
	.Description
		Temp1
	.MenuItem
		0 Not implemented
	.SearchedItemRequest
		None
	.OutputType
		String
	.Author
		Smorkster
	#>

	return $IntMsgTable.GetTemp1StrInfo
}

function Get-ExoMail
{
	<#
	.Synopsis
		Get ExoMailbox
	.Description
		Get ExoMailbox
	.MenuItem
		Get ExoMailbox
	.SearchedItemRequest
		Required
	.OutputType
		ObjectList
	.Author
		Smorkster
	#>

	param ( $Item )

	return Get-EXOMailbox $Item.Name
}

$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.Parent.FullName

Import-LocalizedData -BindingVariable IntMsgTable -UICulture $culture -FileName "$( ( $PSCommandPath.Split( "\" ) | Select-Object -Last 1 ).Split( "." )[0] ).psd1" -BaseDirectory "$RootDir\Localization"

Export-ModuleMember -Function *
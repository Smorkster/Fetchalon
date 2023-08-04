<#
.Synopsis
	A collection of functions to operate with Office365-users
.Description
	A collection of functions to operate with Office365-users
.State
	Prod
.Author
	Smorkster (smorkster)
#>

param ( $culture = "sv-SE" )

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
	.ObjectClass
		user
	.OutputType
		ObjectList
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item )

	return Get-EXOMailbox $Item.Name | Select-Object *
}

$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.Parent.FullName

Import-LocalizedData -BindingVariable IntMsgTable -UICulture $culture -FileName "$( ( $PSCommandPath.Split( "\" ) | Select-Object -Last 1 ).Split( "." )[0] ).psd1" -BaseDirectory "$RootDir\Localization"

Export-ModuleMember -Function Get-ExoMail

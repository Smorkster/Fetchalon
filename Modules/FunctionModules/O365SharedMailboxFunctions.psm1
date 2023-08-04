<#
.Synopsis
	A collection of functions to operate with Office365-sharedmailboxes
.Description
	A collection of functions to operate with Office365-sharedmailboxes
.State
	Prod
.Author
	Smorkster (smorkster)
#>

param ( $culture = "sv-SE" )

function Get-SMFullMembers
{
	<#
	.Synopsis
		Get members with full permissions
	.Description
		Retrieve users who have full access to the shared mailbox
	.MenuItem
		Get Full
	.SearchedItemRequest
		Required
	.ObjectClass
		SharedMailbox
	.OutputType
		List
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item )

	Get-AzureADGroup -Filter "startswith(DisplayName,'MB-$( ( Get-EXORecipient "$( $Item.Name )" ).Name )-Full')" | Get-AzureADGroupMember | Select-Object -ExpandProperty UserPrincipalName | Sort-Object
}

$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.Parent.FullName

Import-LocalizedData -BindingVariable IntMsgTable -UICulture $culture -FileName "$( ( $PSCommandPath.Split( "\" ) | Select-Object -Last 1 ).Split( "." )[0] ).psd1" -BaseDirectory "$RootDir\Localization"

Export-ModuleMember -Function Get-SMFullMembers

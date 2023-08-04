<#
.Synopsis
	A collection of functions to operate with Office365-distributionlists
.Description
	A collection of functions to operate with Office365-distributionlists
.State
	Prod
.Author
	Smorkster (smorkster)
#>

param ( $culture = "sv-SE" )

function Get-DLAdmins
{
	<#
	.Synopsis
		Get distributionlist administrators
	.Description
		Get distributionlist administrators
	.MenuItem
		Get admins
	.SearchedItemRequest
		Required
	.ObjectClass
		Distributionlist
	.OutputType
		List
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item )

	Get-AzureADGroup -Filter "startswith(DisplayName,'DL-$( ( Get-EXORecipient "$( $Item.Name )" ).Name )')" | Get-AzureADGroupMember | Select-Object -ExpandProperty UserPrincipalName -ErrorAction SilentlyContinue | Sort-Object
}

$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.Parent.FullName

Import-LocalizedData -BindingVariable IntMsgTable -UICulture $culture -FileName "$( ( $PSCommandPath.Split( "\" ) | Select-Object -Last 1 ).Split( "." )[0] ).psd1" -BaseDirectory "$RootDir\Localization"

Export-ModuleMember -Function Get-DLAdmins
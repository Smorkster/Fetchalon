<#
.Synopsis
	A collection of functions to operate with Office365-resources
.Description
	A collection of functions to operate with Office365-resources
.State
	Prod
.Author
	Smorkster (smorkster)
#>

param ( $culture = "sv-SE" )

function Get-ResourceMembers
{
	<#
	.Synopsis
		Get who can book
	.Description
		List the users who can book the resource
	.MenuItem
		Get bookers
	.SearchedItemRequest
		Required
	.ObjectClass
		Resource
	.OutputType
		List
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item )

	$List = @( Get-AzureADGroup -Filter "startswith(DisplayName,'RES-$( $Item.Name )-Book')" | Get-AzureADGroupMember | Select-Object -ExpandProperty UserPrincipalName | Sort-Object )

	if ( $List.Count -gt 0 )
	{
		return $List
	}
	else
	{
		return $IntMsgTable.GetResourceMembersNoMembers
	}
}

$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.Parent.FullName

Import-LocalizedData -BindingVariable IntMsgTable -UICulture $culture -FileName "$( ( $PSCommandPath.Split( "\" ) | Select-Object -Last 1 ).Split( "." )[0] ).psd1" -BaseDirectory "$RootDir\Localization"

Export-ModuleMember -Function Get-ResourceMembers

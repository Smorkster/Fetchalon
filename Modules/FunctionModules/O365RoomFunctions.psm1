<#
.Synopsis
	A collection of functions to operate with Office365-rooms
.Description
	A collection of functions to operate with Office365-rooms
.State
	Prod
.Author
	Smorkster (smorkster)
#>

param ( $culture = "sv-SE" )

function Get-RoomMembers
{
	<#
	.Synopsis
		Get who can book
	.Description
		List the users who can book the room
	.MenuItem
		Get bookers
	.SearchedItemRequest
		Required
	.ObjectClass
		Room
	.OutputType
		List
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item )

	return Get-AzureADGroup -Filter "startswith(DisplayName,'RES-$( $Item.Name )-Book')" | Get-AzureADGroupMember | Select-Object -ExpandProperty UserPrincipalName | Sort-Object
}

$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.Parent.FullName

Import-LocalizedData -BindingVariable IntMsgTable -UICulture $culture -FileName "$( ( $PSCommandPath.Split( "\" ) | Select-Object -Last 1 ).Split( "." )[0] ).psd1" -BaseDirectory "$RootDir\Localization"

Export-ModuleMember -Function Get-RoomMembers

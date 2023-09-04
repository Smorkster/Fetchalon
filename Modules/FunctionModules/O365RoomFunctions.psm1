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
		Get members and permissions
	.Description
		Get the users who have permission, and their respecive permission/role
	.MenuItem
		Get members
	.SearchedItemRequest
		Required
	.ObjectClass
		O365Room
	.OutputType
		ObjectList
	.State
		Prod
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item )

	$Members = [System.Collections.ArrayList]::new()

	Get-AzureADGroup -SearchString "RES-$( $Item.Name )-Admins" | `
		Get-AzureADGroupMember | `
			Where-Object { $_.ObjectType -ne "Group" } | `
			Select-Object -Property DisplayName, UserPrincipalName, @{ Name = "$( $IntMsgTable.GetRoomMembersParamPermName )" ; Expression = { "$( $IntMsgTable.GetRoomMembersParamPermAdmin )" } } | `
			Sort-Object DisplayName | `
			ForEach-Object {
				$Members.Add( $_ ) | Out-Null
			}

	Get-AzureADGroup -SearchString "RES-$( $Item.Name )-Book" | `
		Get-AzureADGroupMember | `
			Select-Object -Property DisplayName, UserPrincipalName, @{ Name = "$( $IntMsgTable.GetRoomMembersParamPermName )" ; Expression = { "$( $IntMsgTable.GetRoomMembersParamPermBook )" } } | `
			Sort-Object DisplayName | `
			ForEach-Object {
				$Members.Add( $_ ) | Out-Null
			}

	if ( $Members.Count -gt 0 )
	{
		return $Members
	}
	else
	{
		return $IntMsgTable.GetRoomMembersNoMembers
	}
}

$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.Parent.FullName

Import-LocalizedData -BindingVariable IntMsgTable -UICulture $culture -FileName "$( ( $PSCommandPath.Split( "\" ) | Select-Object -Last 1 ).Split( "." )[0] ).psd1" -BaseDirectory "$RootDir\Localization"

Export-ModuleMember -Function Get-RoomMembers

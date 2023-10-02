<#
.Synopsis
	A collection of functions to run for a DirectoryInfo object
.Description
	A collection of functions to run for a DirectoryInfo object
.ObjectClass
	DirectoryInfo
.State
	Prod
.Author
	Smorkster (smorkster)
#>

param ( $culture = "sv-SE" )

function Get-DirectoryContent
{
	<#
	.Synopsis
		View contents of folder
	.Description
		List files and folders placed in the folder
	.MenuItem
		List contents
	.SearchedItemRequest
		Required
	.OutputType
		ObjectList
	.State
		Prod
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item )

	$List = [System.Collections.ArrayList]@{}

	Get-ChildItem $Item.FullName | `
		ForEach-Object {
			$List.Add( ( [pscustomobject]@{ Name = $_.Name ; Type = $_.GetType().Name ; Item = $_ } ) ) | Out-Null
		}

	if ( $List.Count -gt 0 )
	{
		return $List
	}
	else
	{
		return $IntMsgTable.GetDirectoryContentNoContent
	}
}

function Get-DirectoryPermissions
{
	<#
	.Synopsis
		Show permissions
	.Description
		List who has access to the folder and what type of access
	.MenuItem
		List permissions
	.SearchedItemRequest
		Required
	.OutputType
		ObjectList
	.NoRunspace
	.State
		Prod
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item )

	$PermList = [System.Collections.ArrayList]::new()

	$acl = Get-Acl $Item.FullName
	( $acl.Access | Where-Object { $_.IdentityReference -match $IntMsgTable.GetDirectoryPermissionsCodeRegExAclIdentity } ).IdentityReference | `
		Select-Object -Unique | `
		ForEach-Object {
			$PermType = if ( $_ -match "C$" ) { "C" } else { "R" }

			Get-ADGroup ( $_ -split "\\" )[1]  | `
				Get-ADGroupMember | `
					ForEach-Object {
						if ( "group" -eq $_.ObjectClass )
						{

							if ( $_.Name -match "C$" )
							{
								Get-ADGroupMember $_.SamAccountName | `
									Sort-Object Name | `
									ForEach-Object {
										[pscustomobject]@{ $IntMsgTable.GetDirectoryPermissionsParamName = $_.Name ; $IntMsgTable.GetDirectoryPermissionsParamPerm = $IntMsgTable.GetDirectoryPermissionsStrPermWrite }
									}

							}
							else
							{
								Get-ADGroupMember $_.SamAccountName | `
									Sort-Object Name | `
									ForEach-Object {
										[pscustomobject]@{ $IntMsgTable.GetDirectoryPermissionsParamName = $_.Name ; $IntMsgTable.GetDirectoryPermissionsParamPerm = $IntMsgTable.GetDirectoryPermissionsStrPermRead }
									}
							}
						}
						elseif ( "user" -eq $_.ObjectClass )
						{
							if ( "C" -eq $PermType )
							{
								[pscustomobject]@{ $IntMsgTable.GetDirectoryPermissionsParamName = $_.Name ; $IntMsgTable.GetDirectoryPermissionsParamPerm = $IntMsgTable.GetDirectoryPermissionsStrPermWrite }
							}
							elseif ( "R" -eq $PermType )
							{
								[pscustomobject]@{ $IntMsgTable.GetDirectoryPermissionsParamName = $_.Name ; $IntMsgTable.GetDirectoryPermissionsParamPerm = $IntMsgTable.GetDirectoryPermissionsStrPermRead }
							}
						}
					} | `
				ForEach-Object {
					$PermList.Add( $_ ) | Out-Null
				}
		}

	if ( 0 -eq $PermList.Count )
	{
		return $IntMsgTable.GetDirectoryPermissionsStrNoPermissions
	}
	else
	{
		$PermList | Sort-Object $IntMsgTable.GetDirectoryPermissionsParamPerm, $IntMsgTable.GetDirectoryPermissionsParamName
	}
}

$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.Parent.FullName

Import-LocalizedData -BindingVariable IntMsgTable -UICulture $culture -FileName "$( ( $PSCommandPath.Split( "\" ) | Select-Object -Last 1 ).Split( "." )[0] ).psd1" -BaseDirectory "$RootDir\Localization"

Export-ModuleMember -Function Get-DirectoryContent, Get-Permissions

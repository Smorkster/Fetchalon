<#
.Synopsis
	A collection of functions to run for a user object
.Description
	A collection of functions to run for a user object
.ObjectClass
	User
.State
	Prod
.Author
	Smorkster (smorkster)
#>

param ( $culture = "sv-SE" )

function Get-FolderMembership
{
	<#
	.Synopsis
		List folders with permissions
	.Description
		List all folders the user have permissions for, and what type of permission
	.MenuItem
		Folder permissions
	.SearchedItemRequest
		Required
	.OutputType
		ObjectList
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item )

	return Get-ADGroup -LDAPFilter ( "(member:1.2.840.113556.1.4.1941:={0})" -f ( Get-ADUser $Item.SamAccountName ).DistinguishedName ) -Properties Description | `
		Where-Object { $_.Name -match ".*_Fil_.*User_(C|R)" -and $_.Name -notmatch $IntMsgTable.StrGetFolderMembershipPropCodeNotMatch } | `
		Select-Object -Property `
			@{ Name = "$( $IntMsgTable.StrGetFolderMembershipPropTitleGroup )"; Expression = { $_.Name } }, `
			@{ Name = "$( $IntMsgTable.StrGetFolderMembershipPropTitleFolder )"; Expression = { ( ( $_.Description -split " $( $IntMsgTable.StrGetFolderMembershipPropCodeSplit1 ) " )[1] -split "\." )[0] -replace $IntMsgTable.StrGetFolderMembershipPropCodeReplace1, "G:" -replace $IntMsgTable.StrGetFolderMembershipPropCodeReplace2, "S:" } }, `
			@{ Name = "$( $IntMsgTable.StrGetFolderMembershipPropTitlePermission )" ; Expression = { `
				if ( $_.Name -match "_User_R$" ) { $IntMsgTable.StrGetFolderMembershipPropValRead }
				elseif ( $_.Name -match "_User_C$" ) { $IntMsgTable.StrGetFolderMembershipPropValWrite }
				else { "?" } } } | `
		Sort-Object -Property `
			@{ Expression = { $_."$( $IntMsgTable.StrGetFolderMembershipPropTitlePermission )" } ; Ascending = $true }, `
			@{ Expression = { $_."$( $IntMsgTable.StrGetFolderMembershipPropTitleFolder )" } ; Ascending = $true }
}

function Get-FolderOwnership
{
	<#
	.Synopsis
		List folder ownership
	.Description
		List all folders the user have ownership for
	.MenuItem
		Folder ownership
	.SearchedItemRequest
		Required
	.OutputType
		List
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item )

	$List = [System.Collections.ArrayList]::new()
	Get-ADGroup -LDAPFilter "(&(ManagedBy=$( $Item.DistinguishedName ))(&(Name=*_Fil_*_Grp_*_User_*)(|(Name=*User_C)(Name=*User_R))))" -Properties Description | Sort-Object Name | ForEach-Object { ( ( $_.Description -split "\." )[0] -split "\$" )[1] } | Select-Object -Unique | ForEach-Object { $List.Add( "G:$_" ) | Out-Null }

	if ( $null -eq $List )
	{
		return $null
	}
	else
	{
		return $List
	}
}

function Compare-UserGroups
{
	<#
	.Synopsis
		Compare permission groups
	.Description
		Compare permission groups between users
	.MenuItem
		Compare permission groups
	.SearchedItemRequest
		Allowed
	.OutputType
		ObjectList
	.InputData
		Users List of users, separated by spaces
	.NoRunspace
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item, $InputData )

	$UsersIn = @( $InputData.Användare -split "\s" | Where-Object { $_ } )
	if ( $Item )
	{
		$UsersIn += $Item.SamAccountName
	}
	$Users = [System.Collections.ArrayList]::new()
	$InputNotFound = @()
	$AllGroups = @()
	$OFS = ", "
	$perms = [System.Collections.ArrayList]::new()

	$UsersIn | Select-Object -Unique | ForEach-Object {
		try
		{
			$a = Get-ADUser $_
			$b = ( Get-ADPrincipalGroupMembership -Identity $a | Select-Object -ExpandProperty Name )
			[void] $Users.Add( ( [pscustomobject]@{ "User" = $a; "Groups" = $b } ) )
		}
		catch { $InputNotFound += $_ }
	}

	if ( $Users.Count -gt 1 )
	{
		$AllGroups = $Users.Groups | Select-Object -Unique

		if ( $AllGroups.Count -gt 0 )
		{
			$groups = @()
			foreach ( $g in $AllGroups )
			{
				$group = [pscustomobject]@{ "GroupName" = $g; Users = "" }
				$userlist = [System.Collections.ArrayList]::new()

				foreach ( $u in $Users )
				{
					if ( $u.Groups -contains $group.Groupname )
					{
						[void] $userlist.Add( $u.User.Name )
					}
				}
				$group.Users = [string]( $userlist | Sort-Object )
				$groups += $group
			}
		}

		$OFS = "`n"
		$groups | `
			Group-Object Users | `
				ForEach-Object {
					$gn = $_.Name
					$groups | `
						Sort-Object "GroupName" | `
						Where-Object { $gn -eq $_.Users } | `
							ForEach-Object `
							-Begin { $PermList = [pscustomobject]@{ Users = $gn ; MemberCount = ( $gn -split "," ).Count ; Groups = [System.Collections.ArrayList]::new() } } `
							-Process { [void] $PermList.Groups.Add( $_.GroupName ) } `
							-End {
								$PermList.Groups = [string] ( $PermList.Groups | Sort-Object @{ Expression = { $_.MemberCount } ; Descending = $true }, @{ Expression = { $_.Users } ; Ascending = $true } )
								[void] $perms.Add( $PermList )
							}
				}
		return $perms
	}
	else
	{
		throw $IntMsgTable.StrCompareUserGroupsNoValidUsers
	}
}

function Open-SysManGroups
{
	<#
	.Synopsis
		SysMan handle groups
	.Description
		Opens SysMan to handle groups for user
	.MenuItem
		SysMan handle groups
	.SearchedItemRequest
		Required
	.OutputType
		None
	.Author
		Smorkster
	#>

	param ( $Item )

	[System.Diagnostics.Process]::Start( "chrome", "$( $IntMsgTable.SysManServerUrl )/Group/GroupManagementForUser#targetName=$( $Item.SamAccountName )" )
}

function Open-SysManMobileDevices
{
	<#
	.Synopsis
		SysMan handle mobile devices
	.Description
		Opens SysMan to handle module devices for user
	.MenuItem
		SysMan handle module devices
	.SearchedItemRequest
		Required
	.OutputType
		None
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item )

	[System.Diagnostics.Process]::Start( "chrome", "$( $IntMsgTable.SysManServerUrl )/MobileDevice/EditForUser#userName=$( $Item.SamAccountName )" )
}

function Remove-ProfileAria
{
	<#
	.Synopsis
		Clear Aria profile, alternatively open the profiles folder
	.Description
		Deletes Aria profile for specified user. If no user is specified, the folder for profiles is opened
	.MenuItem
		Clear Aria profile
	.SearchedItemRequest
		Allowed
	.OutputType
		String
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item )

	if ( $null -eq $Item.SamAccountName )
	{
		explorer "\\dfs\ctx$\prf_aria"
	}
	else
	{
		if ( Test-Path "\\dfs\ctx$\prf_aria\$( $Item.SamAccountName )" )
		{
			Start-Process -FilePath C:\Windows\explorer.exe -ArgumentList "/select, ""\\dfs\ctx$\prf_aria\$( $Item.SamAccountName )"""
		}
		else
		{
			explorer "\\dfs\ctx$\_prf_aria\"
		}
	}
}

function Remove-ProfileVK
{
	<#
	.Synopsis
		Clear vKlient profile, alternatively open the profile folder
	.Description
		Removes vClient profile for specified user. If no user is specified, the folder for profiles is opened
	.MenuItem
		Clear vClient profile
	.SearchedItemRequest
		Allowed
	.OutputType
		String
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item )

	if ( $null -eq $Item )
	{
		switch ( ( Show-CustomMessageBox -Text $IntMsgTable.RemoveProfileVKQuestion -Title $IntMsgTable.RemoveProfileVKQuestionTitle -ButtonStrings "Org1","Org2","Or3" ) )
		{
			"Org1" { $Path = "\\dfs.test.com\c$\org1" }
			"Org2" { $Path = "\\dfs.test.com\c$\org2" }
			"Org3" { $Path = "\\dfs.test.com\c$\org3" }
		}

		explorer $Path
		return $IntMsgTable.RemoveProfileVKQuestionReturn
	}
	else
	{
		$Canonical = ( $Item.CanonicalName -split "/" )[2]
		if ( ( $Org = $Item.MemberOf | Where-Object { $_ -match "CN=((Org1)|(Org2)|(Org3))_Org_(\d)_Users" } ) )
		{
			$Org | `
				ForEach-Object {
					if ( $_ -match "CN=(?<Org>(Org1)|(Org2)|(Org3))_Org_(\d)_Users" )
					{
						if ( Test-Path "\\dfs\ctx$\$( $Matches.Org.ToLower() )_prf\$( $Item.SamAccountName )" )
						{
							Remove-Item -Path "\\dfs\ctx$\$( $Matches.Org.ToLower() )_prf\$( $Item.SamAccountName )" -Recurse -Force
						}
						else
						{
							explorer "\\dfs\ctx$\$( $Matches.Org.ToLower() )_prf\"
						}
					}
				}

			return $IntMsgTable.RemoveProfileVKProfileRemoved
		}
		else
		{
			return $IntMsgTable.RemoveProfileVKNotValidOrg
		}
	}
}

function Remove-ProfileVKTC
{
	<#
	.Synopsis
		Clear TC-profile for vKlient, alternatively open the profiles folder
	.Description
		Deletes TC-profile for vKlient for given user. If no user is specified, the folder for profiles is opened
	.MenuItem
		Delete TC vKlient-profile
	.SearchedItemRequest
		Allowed
	.OutputType
		String
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item )

	$Prod = [System.Text.StringBuilder]::new()
	$RO = [System.Text.StringBuilder]::new()
	$Prod.Append( "\\dfs\ctx$\" ) | Out-Null
	$RO.Append( "\\dfs\ctx$\" ) | Out-Null

	if ( $Item.CanonicalName -notmatch "H/(Org1)|(Org2)|(Org4)" )
	{
		$Org = ( Show-CustomMessageBox -Text $IntMsgTable.RemoveProfileVKTCSelectCustomer -Title $IntMsgTable.RemoveProfileVKTCSelectCustomerTitle -Button "Org1","Org2","Org4" ).ToLower()
		$Prod.Append( $Org ) | Out-Null
		$RO.Append( $Org ) | Out-Null
	}
	else
	{
		$Item.CanonicalName -match "H/(?<Org>\w*)/" | Out-Null
		$Prod.Append( $Matches.Org.ToLower() ) | Out-Null
		$RO.Append( $Matches.Org.ToLower() ) | Out-Null
	}

	$Prod.Append( "_tcprod_app" ) | Out-Null
	$RO.Append( "_tcro_app" ) | Out-Null

	if ( Test-Path "$( $s.ToString() )\$( $Item.SamAccountName )" )
	{
		$Prod.Append( "\$( $Item.SamAccountName )" ) | Out-Null
		$RO.Append( "\$( $Item.SamAccountName )" ) | Out-Null
		Start-Process -FilePath C:\Windows\explorer.exe -ArgumentList "/select, ""$( $s.ToString() )"""
		Start-Process -FilePath C:\Windows\explorer.exe -ArgumentList "/select, ""$( $s.ToString() )"""
	}
	else
	{
		explorer $Prod.ToString()
		explorer $RO.ToString()
	}
}

$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.Parent.FullName

Import-LocalizedData -BindingVariable IntMsgTable -UICulture $culture -FileName "$( ( $PSCommandPath.Split( "\" ) | Select-Object -Last 1 ).Split( "." )[0] ).psd1" -BaseDirectory "$RootDir\Localization"

Export-ModuleMember -Function Get-FolderMembership, Get-FolderOwnership, Compare-UserGroups
Export-ModuleMember -Function Open-SysManGroups, Open-SysManMobileDevices
Export-ModuleMember -Function Remove-ProfileAria, Remove-ProfileVK, Remove-ProfileVKTC

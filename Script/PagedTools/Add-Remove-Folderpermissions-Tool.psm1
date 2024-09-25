<#
.Synopsis
	Add or remove folder permissions
.Description
	Add or remove folder permissions for one or many users
.MenuItem
	Add/remove folder permissions
.State
	Prod
.ObjectOperations
	Group
.Author
	Smorkster (smorkster)
#>

Add-Type -AssemblyName PresentationFramework
$syncHash = $args[0]

function Check-Ready
{
	<#
	.Synopsis
		Some input is entered, check if necessary input is given, enable button to perform
	#>

	if ( ( $syncHash.DC.LbFoldersChosen[0].Count -gt 0 ) -and ( ( $syncHash.Controls.TbUsersForWritePermission.Text.Length -ge 4 ) -or ( $syncHash.Controls.TbUsersForReadPermission.Text.Length -ge 4 ) -or ( $syncHash.Controls.TbUsersForRemovePermission.Text.Length -ge 4 ) ) )
	{
		$syncHash.DC.BtnPerform[0] = $true
	}
	else
	{
		$syncHash.DC.BtnPerform[0] = $false
	}
}

function Check-User
{
	<#
	.Synopsis
		Check type of AD-user
	.Parameter Id
		Entered id of user to check if it exists
	#>

	param (
		[string] $Id
	)

	$Id = $Id.Trim()
	if ( dsquery User -samid $Id )
	{
		return "User"
	}
	elseif ( dsquery Group -samid $Id )
	{
		return "Group"
	}
	elseif ( $EKG = Get-ADGroup -LDAPFilter "(&($( $syncHash.Data.msgTable.StrEGroupIdName )=$( $syncHash.Data.msgTable.StrEGroupOrg )-$Id)(!(Name=$( $syncHash.Data.msgTable.StrOrgExcludeLDAP )*)))" )
	{
		if ( $EKG.Count -gt 1 )
		{
			return "EGroups"
		}
		else
		{
			return "EGroup"
		}
	}
	else
	{
		$syncHash.Data.ErrorLogHashes += WriteErrorlog -LogText ( "{0} {1}" -f $syncHash.Data.msgTable.ErrNotFoundUser, $Id ) -UserInput $Id -Severity "UserInputFail"
		return "NotFound"
	}
}

function Collect-ADGroups
{
	<#
	.Synopsis
		Collect AD-groups for folders
	#>

	if ( $syncHash.DC.CbDisk[1].Substring( 1, 2 ) -eq ":\" )
	{
		switch ( $syncHash.DC.CbDisk[1].Substring( 0, 1 ) )
		{
			"G" { Collect-ADGroupsG -Entries $syncHash.DC.LbFoldersChosen[0] }
			"R" { Collect-ADGroupsR -Entries $syncHash.DC.LbFoldersChosen[0] }
			"S" { Collect-ADGroupsS -Entries $syncHash.DC.LbFoldersChosen[0] }
		}
	}
	else
	{
		foreach ( $entry in $syncHash.DC.LbFoldersChosen[0] )
		{
			$syncHash.Data.ADGroups += @{ "Id" = $entry }
		}
	}
}

function Collect-ADGroupsG
{
	<#
	.Synopsis
		Collect AD-groups for folders starting with "G:\"
	.Parameter Entries
		List of folderobjects specified by operator
	#>

	param (
		$Entries
	)

	$loopCounter = 0

	$Customer = ( ( $syncHash.DC.CbDisk[1] -split "\\" )[1] )
	$syncHash.Data.ADGroups.Clear()
	foreach ( $entry in $Entries )
	{
		Set-WinTitle -Text $syncHash.Data.msgTable.StrTitleProgressGroups -Progress $loopCounter -Max $Entries.Count

		$FolderName = $syncHash.DC.CbDisk[1].ToString() + "\" + $entry.Name
		$entry = $entry.Name -replace " ", "_"
		try
		{
			$WriteGroup = Get-ADGroup ( Invoke-Expression $syncHash.Data.msgTable.CodeGetGGroupWrite1 )
		}
		catch
		{
			try
			{
				$WriteGroup = Get-ADGroup ( Invoke-Expression $syncHash.Data.msgTable.CodeGetGGroupWrite2 )
			}
			catch
			{
				$syncHash.Data.ErrorLogHashes += WriteErrorlog -LogText $syncHash.Data.msgTable.ErrNotFoundGrpForGWrite -UserInput $entry -Severity "UserInputFail"
				$WriteGroup = $null
			}
		}

		try
		{
			$ReadGroup = Get-ADGroup ( Invoke-Expression $syncHash.Data.msgTable.CodeGetGGroupRead1 )
		}
		catch
		{
			try
			{
				$ReadGroup = Get-ADGroup ( Invoke-Expression $syncHash.Data.msgTable.CodeGetGGroupRead2 )
			}
			catch
			{
				$syncHash.Data.ErrorLogHashes += WriteErrorlog -LogText $syncHash.Data.msgTable.ErrNotFoundGrpForGRead -UserInput $entry -Severity "UserInputFail"
				$ReadGroup = $null
			}
		}
		if ( $WriteGroup -and $ReadGroup )
		{
			$syncHash.Data.ADGroups += @{ "Id" = $FolderName; "Write" = $WriteGroup.SamAccountName; "Read" = $ReadGroup.SamAccountName }
		}
		else
		{
			$syncHash.Data.ErrorGroups += $FolderName
		}

		$loopCounter++
	}
}

function Collect-ADGroupsR
{
	<#
	.Synopsis
		Get the AD-groups for the listed R:-folders
	.Parameter Entries
		List of folderobjects specified by operator
	#>

	param (
		$Entries
	)

	$loopCounter = 0

	$Customer = ( ( $syncHash.DC.CbDisk[1] -split "\\" )[1] )
	$syncHash.Data.ADGroups.Clear()
	foreach ( $entry in $Entries )
	{
		Set-WinTitle -Text ( Invoke-Expression $syncHash.Data.msgTable.StrTitleProgressGroups ) -Progress $loopCounter -Max $Entries.Count

		$FolderName = $syncHash.DC.CbDisk[1].ToString() + "\" + $entry.Name
		$entry = $entry.Name -replace " ", "_"
		try
		{
			$WriteGroup = Get-ADGroup ( Invoke-Expression $syncHash.Data.msgTable.CodeGetRGroupWrite1 )
		}
		catch
		{
			try
			{
				$WriteGroup = Get-ADGroup ( Invoke-Expression $syncHash.Data.msgTable.CodeGetRGroupWrite2 )
			}
			catch
			{
				try
				{
					$WriteGroup = Get-ADGroup ( Invoke-Expression $syncHash.Data.msgTable.CodeGetRGroupWrite3 )
				}
				catch
				{
					try
					{
						$WriteGroup = Get-ADGroup ( Invoke-Expression $syncHash.Data.msgTable.CodeGetRGroupWrite4 )
					}
					catch
					{
						$syncHash.Data.ErrorLogHashes += WriteErrorlog -LogText $syncHash.Data.msgTable.ErrNotFoundGrpForRWrite -UserInput $entry -Severity "UserInputFail"
						$WriteGroup = $null
					}
				}
			}
		}

		try
		{
			$ReadGroup = Get-ADGroup ( Invoke-Expression $syncHash.Data.msgTable.CodeGetRGroupRead1 )
		}
		catch
		{
			try
			{
				$ReadGroup = Get-ADGroup ( Invoke-Expression $syncHash.Data.msgTable.CodeGetRGroupRead2 )
			}
			catch
			{
				try
				{
					$ReadGroup = Get-ADGroup ( Invoke-Expression $syncHash.Data.msgTable.CodeGetRGroupRead3 )
				}
				catch
				{
					try
					{
						$ReadGroup = Get-ADGroup ( Invoke-Expression $syncHash.Data.msgTable.CodeGetRGroupRead4 )
					}
					catch
					{
						$syncHash.Data.ErrorLogHashes += WriteErrorlog -LogText $syncHash.Data.msgTable.ErrNotFoundGrpForRRead -UserInput $entry -Severity "UserInputFail"
						$ReadGroup = $null
					}
				}
			}
		}
		if ( $WriteGroup -and $ReadGroup )
		{
			$syncHash.Data.ADGroups += @{ "Id" = $FolderName; "Write" = $WriteGroup.SamAccountName; "Read" = $ReadGroup.SamAccountName }
		}
		else
		{
			$syncHash.Data.ErrorGroups += $FolderName
		}

		$loopCounter++
	}
	Set-WinTitle -Text ""
}

function Collect-ADGroupsS
{
	<#
	.Synopsis
		Get the AD-groups for the listed S:-folders
	.Parameter Entries
		List of folderobjects specified by operator
	#>

	param (
		$Entries
	)

	$loopCounter = 0

	$Customer = ( ( $syncHash.DC.CbDisk[1] -split "\\" )[1] )
	$syncHash.Data.ADGroups.Clear()
	foreach ( $entry in $entries )
	{
		Set-WinTitle -Text ( Invoke-Expression $syncHash.Data.msgTable.StrTitleProgressGroups ) -Progress $loopCounter -Max $entries.Count

		$FolderName = $syncHash.DC.CbDisk[1].ToString() + "\" + $entry.Name
		$entry = $entry.Name -replace " ", "_"
		try
		{
			$WriteGroup = Get-ADGroup ( Invoke-Expression $syncHash.Data.msgTable.CodeGetSGroupWrite1 )
		}
		catch
		{
			try
			{
				$WriteGroup = Get-ADGroup ( Invoke-Expression $syncHash.Data.msgTable.CodeGetSGroupWrite2 )
			}
			catch
			{
				$syncHash.Data.ErrorLogHashes += WriteErrorlog -LogText $syncHash.Data.msgTable.ErrNotFoundGrpForSWrite -UserInput $entry -Severity "UserInputFail"
				$WriteGroup = $null
			}
		}

		try
		{
			$ReadGroup = Get-ADGroup ( Invoke-Expression $syncHash.Data.msgTable.CodeGetSGroupRead1 )
		}
		catch
		{
			try
			{
				$ReadGroup = Get-ADGroup ( Invoke-Expression $syncHash.Data.msgTable.CodeGetSGroupRead2 )
			}
			catch
			{
				$syncHash.Data.ErrorLogHashes += WriteErrorlog -LogText $syncHash.Data.msgTable.ErrNotFoundGrpForSRead -UserInput $entry -Severity "UserInputFail"
				$ReadGroup = $null
			}
		}
		if ( $WriteGroup -and $ReadGroup )
		{
			$syncHash.Data.ADGroups += @{ "Id" = $FolderName; "Write" = $WriteGroup.SamAccountName; "Read" = $ReadGroup.SamAccountName }
		}
		else
		{
			$syncHash.Data.ErrorGroups += $FolderName
		}

		$loopCounter++
	}
}

function Collect-Entries
{
	<#
	.Synopsis
		Collect input from textboxes
	#>

	if ( ( $entries = $syncHash.Controls.TbUsersForWritePermission.Text -split "\W" | Where-Object { $_ } | ForEach-Object { $_.Trim() } ).Count -gt 0 )
	{
		Collect-Users -Entries $entries -PermissionType "Write"
	}
	if ( ( $entries = $syncHash.Controls.TbUsersForReadPermission.Text -split "\W" | Where-Object { $_ } | ForEach-Object { $_.Trim() } ).Count -gt 0 )
	{
		Collect-Users -Entries $entries -PermissionType "Read"
	}
	if ( ( $entries = $syncHash.Controls.TbUsersForRemovePermission.Text -split "\W" | Where-Object { $_ } | ForEach-Object { $_.Trim() } ).Count -gt 0 )
	{
		Collect-Users -Entries $entries -PermissionType "Remove"
	}
}

function Collect-Users
{
	<#
	.Synopsis
		Collect users
	.Parameter Entries
		List of userobjects specified by operator
	.Parameter PermissionType
		What type of permission was the user listed for
	#>

	param (
		[array] $Entries,
		[string] $PermissionType
	)

	$loopCounter = 0

	switch ( $PermissionType )
	{
		"Write"
		{ $syncHash.Data.WriteUsers = @() }
		"Read"
		{ $syncHash.Data.ReadUsers = @() }
		"Remove"
		{ $syncHash.Data.RemoveUsers = @() }
	}

	foreach ( $entry in $Entries )
	{
		Set-WinTitle -Text "$( $syncHash.Data.msgTable.StrStartPrep ) '$PermissionType'" -Progress $loopCounter -Max $Entries.Count
		$UserType = Check-User -Id $entry
		if ( $UserType -eq "NotFound" )
		{
			$syncHash.Data.ErrorUsers += @{ "Id" = $entry }
		}
		else
		{
			$o = $null
			$ADObj = $null
			switch ( $UserType )
			{
				"User" { $ADObj = Get-ADUser -Identity $entry }
				"Group" { $ADObj = Get-ADGroup -Identity $entry -Properties $syncHash.Data.msgTable.StrEGroupIdName, $syncHash.Data.msgTable.StrEGroupDn }
				{ $_ -match "^EGroup" } { $ADObj = Get-ADGroup -LDAPFilter "(&($( $syncHash.Data.msgTable.StrEGroupIdName )=$( $syncHash.Data.msgTable.StrEGroupOrg )-$entry)(!(Name=$( $syncHash.Data.msgTable.StrOrgExcludeLDAP )*)))" -Properties $syncHash.Data.msgTable.StrEGroupIdName, $syncHash.Data.msgTable.StrEGroupDn }
			}
			foreach ( $u in $ADObj )
			{
				if ( $u.ObjectClass -eq "User" )
				{
					$name = $u.Name
				}
				else
				{
					$name = "$( ( $u.$( $syncHash.Data.msgTable.StrEGroupDn ) -replace "," -split "ou=" )[1] ) ($( ( $u.$( $syncHash.Data.msgTable.StrEGroupIdName ) -split "-" )[1] ))"
				}

				$o = @{ "Id" = $entry.ToString().ToUpper(); "AD" = $u; "Type" = $UserType -replace "EGroups", "EGroup"; "Name" = $name }

				switch ( $PermissionType )
				{
					"Write" { $syncHash.Data.WriteUsers += $o }
					"Read" { $syncHash.Data.ReadUsers += $o }
					"Remove" { $syncHash.Data.RemoveUsers += $o }
				}
			}
		}
		$loopCounter++
	}
	Set-WinTitle -Text ""
}

function Create-Message
{
	<#
	.Synopsis
		Create message
	#>

	$Message = @( $syncHash.Data.msgTable.StrFinIntro )
	$syncHash.Data.ADGroups.Id | `
		ForEach-Object {
			$Message += "`t$_"
		}

	# Add users that got write-permission
	if ( $syncHash.Data.WriteUsers )
	{
		$Message += "`n$( $syncHash.Data.msgTable.StrFinPermWrite ):"
		$syncHash.Data.WriteUsers | `
			ForEach-Object {
				$Message += "`t$( $_.Name )"
			}
	}

	# Add users that got read-permission
	if ( $syncHash.Data.ReadUsers )
	{
		$Message += "`n$( $syncHash.Data.msgTable.StrFinPermRead ):"
		$syncHash.Data.ReadUsers | `
			ForEach-Object {
				$Message += "`t$( $_.Name )"
			}
	}

	# Add users that got permission removed
	if ( $syncHash.Data.RemoveUsers )
	{
		$Message += "`n$( $syncHash.Data.msgTable.StrFinPermRem ):"
		$syncHash.Data.RemoveUsers | `
			ForEach-Object {
				$Message += "`t$( $_.Name )"
			}
	}

	# Add input as users that wasn't found
	if ( $syncHash.Data.ErrorUsers )
	{
		$Message += "`n$( $syncHash.Data.msgTable.StrFinNoAccounts ):"
		$syncHash.Data.ErrorUsers | `
			ForEach-Object {
				$Message += "`t$_"
			}
	}

	# Add group input that wasn't found
	if ( $syncHash.Data.ErrorGroups )
	{
		$Message += "`n$( $syncHash.Data.msgTable.StrFinNoAdGroups ):"
		$syncHash.Data.ErrorGroups | `
			ForEach-Object {
				$Message += "`t$_"
			}
	}

	if ( $syncHash.DC.ChbUseSignature[0] )
	{
		$Message += "`n$( $syncHash.Data.Signature )"
	}

	$OutputEncoding = ( New-Object System.Text.UnicodeEncoding $false, $false ).psobject.BaseObject
	$Message | clip
}

function Folder-Deselected
{
	<#
	.Synopsis
		A selected folder is removed
	.Description
		A previously selected folder is doubleclicked, it will then be removed from folders that permissions should be added/removed from
	#>

	if ( $syncHash.DC.LbFoldersChosen[1] -ne -1 )
	{
		$syncHash.DC.LbFolderList[0].Add( $syncHash.DC.LbFoldersChosen[2] )
		$syncHash.DC.LbFoldersChosen[0].Remove( $syncHash.DC.LbFoldersChosen[2] )
		Check-Ready
		Update-FolderListItems
		$syncHash.Controls.TbFolderSearch.Text = ""
		$syncHash.Controls.TbFolderSearch.Focus()
	}
}

function Folder-Selected
{
	<#
	.Synopsis
		A folder is doubleclicked, move it to list of chosen folders
	#>

	if ( $syncHash.DC.LbFolderList[1] -ne -1 )
	{
		$syncHash.DC.LbFoldersChosen[0].Add( $syncHash.DC.LbFolderList[2] )
		$syncHash.DC.LbFolderList[0].Remove( $syncHash.DC.LbFolderList[2] )
		Check-Ready
		Update-FolderListItems
		$syncHash.Controls.TbFolderSearch.Text = ""
		$syncHash.Controls.TbFolderSearch.Focus()
	}
}

function Get-OtherPerm
{
	<#
	.Synopsis
		Check if there are any permissions for the folder from any securitygroups
	.Parameter Folder
		Folder to check permissions for
	.Parameter UserList
		List of users to check the permissions for
	#>

	param (
		$Folder,
		$UserList
	)

	Set-WinTitle -Text "$( $syncHash.Data.msgTable.StrSearchOtherPermRoutes ) '$Folder'"
	$OFS = ", "
	$Grps = ( Get-Acl $Folder ).Access | `
		Where-Object { $_.IdentityReference -match "C|R$" } | `
		ForEach-Object {
			$_.IdentityReference -replace "$( $syncHash.Data.msgTable.StrDomain )\\"
		} | `
		Select-Object -Unique | `
		Get-ADGroup | `
		Get-ADGroupMember

	$OtherPermissionRoutes = @()
	foreach ( $Group in $Grps )
	{
		foreach ( $Member in ( Get-ADGroupMember $Group ).Where( { $_.ObjectClass -eq "group" } ) )
		{
			if ( $Members = ( ( Get-ADGroupMember $Member ).SamAccountName | Where-Object { $_ -in $UserList.Id } | Get-ADUser | Select-Object -ExpandProperty Name ) )
			{
				[pscustomobject]@{ Group = $Member.Name; Members = [string]$Members }
			}
		}
	}

	if ( $OtherPermissionRoutes.Count -gt 0 )
	{
		[pscustomobject]@{ Folder = $Folder; PermissionsList = $OtherPermissionRoutes }
	}
}

function Perform-Permissions
{
	<#
	.Synopsis
		Start permission editing
	#>

	Collect-Entries
	Collect-ADGroups

	$Continue = Show-MessageBox -Text "$( $syncHash.Data.msgTable.StrConfirm1 ) $( @( $syncHash.Data.ADGroups ).Count ) $( $syncHash.Data.msgTable.StrConfirm2) $( @( $syncHash.Data.WriteUsers ).Count + @( $syncHash.Data.ReadUsers ).Count + @( $syncHash.Data.RemoveUsers ).Count ) $( $syncHash.Data.msgTable.StrConfirm3 )?$( if ( $syncHash.Data.ErrorGroups -or $syncHash.Data.ErrorUsers ) { "`n$( $syncHash.Data.msgTable.StrConfirmErr )" } )" -Title $syncHash.Data.msgTable.StrConfirmTitle -Button "OKCancel"

	if ( $Continue -eq "OK" )
	{
		$loopCounter = 0
		foreach ( $Group in $syncHash.Data.ADGroups )
		{
			Set-WinTitle -Text $syncHash.Data.msgTable.StrStart -Progress $loopCounter -Max $syncHash.Data.ADGroups.Count
			if ( $syncHash.Data.WriteUsers )
			{
				if ( $Group.Write )
				{
					try
					{
						Add-ADGroupMember -Identity $Group.Write -Members $syncHash.Data.WriteUsers.AD.DistinguishedName -Confirm:$false
					}
					catch
					{
						$syncHash.Data.ErrorLogHashes += WriteErrorlog -LogText $_ -UserInput ( "{0}; {1}" -f $Group.Write, $syncHash.Data.WriteUsers.AD.DistinguishedName ) -Severity "OtherFail"
					}
				}
			}

			if ( $syncHash.Data.ReadUsers )
			{
				if ( $Group.Read )
				{
					try
					{
						Add-ADGroupMember -Identity $Group.Read -Members $syncHash.Data.ReadUsers.AD.DistinguishedName -Confirm:$false 
					}
					catch
					{
						$syncHash.Data.ErrorLogHashes += WriteErrorlog -LogText $_ -UserInput ( "{0}; {1}" -f $Group.Read, $syncHash.Data.ReadUsers.AD.DistinguishedName ) -Severity "OtherFail"
					}
				}
			}

			if ( $syncHash.Data.RemoveUsers )
			{
				if ( $Group.Write -and $Group.Read )
				{
					try
					{
						Remove-ADGroupMember -Identity $Group.Write -Members $syncHash.Data.RemoveUsers.AD.DistinguishedName -Confirm:$false
						Remove-ADGroupMember -Identity $Group.Read -Members $syncHash.Data.RemoveUsers.AD.DistinguishedName -Confirm:$false
					}
					catch
					{
						$syncHash.Data.ErrorLogHashes += WriteErrorlog -LogText $_ -UserInput ( "'{0}', '{1}'; {2}" -f $Group.Write, $Group.Read, $syncHash.Data.ReadUsers.AD.DistinguishedName ) -Severity "OtherFail"
					}
				}
			}

			$loopCounter++
			Remove-Variable errorD, errorR, errorW -ErrorAction SilentlyContinue
		}

		Write-ToLogbox
		Write-ToLogFile
		Create-Message
		Show-MessageBox -Text "$( @( $syncHash.Data.ADGroups ).Count * ( @( $syncHash.Data.WriteUsers ).Count + @( $syncHash.Data.ReadUsers ).Count + @( $syncHash.Data.RemoveUsers ).Count ) ) $( $syncHash.Data.msgTable.StrFinished1 ).`n$( $syncHash.Data.msgTable.StrFinished2 )" -Title "Klar"
		Undo-Input
		Set-WinTitle -Text $syncHash.Data.msgTable.StrTitle
	}
	Reset-Variables
}

function Reset-Variables
{
	<#
	.Synopsis
		Initiate/reset scriptwide variables
	#>

	$syncHash.Data.ADGroups = @()
	$syncHash.Data.ErrorUsers = @()
	$syncHash.Data.ErrorGroups = @()
	$syncHash.Data.WriteUsers = @()
	$syncHash.Data.ReadUsers = @()
	$syncHash.Data.RemoveUsers = @()
}

function Search-ListboxItem
{
	<#
	.Synopsis
		Search for any item containing searchword
	#>

	$list = $syncHash.Folders | `
		Where-Object { $syncHash.DC.LbFoldersChosen[0] -notcontains $_ }

	if ( $syncHash.Controls.TbFolderSearch.Text.Length -eq 0 )
	{
		$syncHash.DC.LbFolderList[1] = -1
	}
	else
	{
		$list = $list | Where-Object { $_.Name,$_.NameToDisplay -like "*$( $syncHash.Controls.TbFolderSearch.Text.Replace( "\\", "\\\\" ) )*" }
	}

	$syncHash.DC.LbFolderList[0].Clear()
	foreach ( $i in $list )
	{
		$syncHash.DC.LbFolderList[0].Add( $i )
	}
}

function Set-UserSettings
{
	<#
	.Synopsis
		Set user dependant settings
	#>

	try
	{
		$a = Get-ADPrincipalGroupMembership -Identity ( [Environment]::UserName )

		if ( $a.SamAccountName -match $syncHash.Data.msgTable.StrOpGroup )
		{
			$syncHash.LogFilePath = $syncHash.Data.msgTable.StrOpLogPath
			$syncHash.ErrorLogFilePath = "$( $syncHash.Data.msgTable.StrOpLogPath )$( $syncHash.Data.msgTable.StrOpErrLogFile )$( ( [Environment]::UserName ) ).log"

			$syncHash.HandledFolders = $syncHash.Data.KatalogHandledFolders
			$syncHash.Data.Signature += "`n`n$( $syncHash.Data.msgTable.StrSignOp )"
		}
		elseif ( $a.SamAccountName -match $syncHash.Data.msgTable.StrSDGroup )
		{
			$syncHash.LogFilePath = ( ( Get-Item $PSScriptRoot ).Parent.FullName) + "\Log\" + $( [datetime]::Now.Year ) + "\" + [datetime]::Now.Month + "\" + ( Get-Item $PSCommandPath ).BaseName + "\"
			$syncHash.ErrorLogFilePath = ( ( Get-Item $PSScriptRoot ).Parent.FullName ) + "\ErrorLogs\" + ( Get-Item $PSCommandPath ).BaseName + "\" + ( [Environment]::UserName ) + " ErrorLog.txt"

			$syncHash.HandledFolders = $syncHash.Data.ServicedeskHandledFolders
			$syncHash.Data.Signature += "`n`n$( $syncHash.Data.msgTable.StrSignSD )"
		}
		else
		{
			throw
		}
	}
	catch
	{
		Show-MessageBox -Text "$( $syncHash.Data.msgTable.StrNoPerm )`n$( $_.Exception.Message )" -Title $syncHash.Data.msgTable.StrNoPermTitle -Icon "Stop"
		WriteErrorlog -LogText "Set-UserSettings:`n$_" -UserInput ( [Environment]::UserName ) -Severity -1 | Out-Null
	}
}

function Set-WinTitle
{
	<#
	.Synopsis
		Sets the window title
	.Parameter Text
		Text to set as title
	.Parameter Progress
		An integer specifying how much progress have proceeded
	.Parameter Max
		An integer specifying that max number of progress
	#>

	param (
		[string] $Text,
		[int] $Progress,
		[int] $Max
	)

	if ( $Progress )
	{
		$Text += " $( [Math]::Floor( $Progress / $Max * 100 ) )%"
	}
	$syncHash.Controls.Window.Title = $Text
}

function Undo-Input
{
	<#
	.Synopsis
		Clear all input
	#>

	$syncHash.Controls.TbUsersForWritePermission.Text = ""
	$syncHash.Controls.TbUsersForReadPermission.Text = ""
	$syncHash.Controls.TbUsersForRemovePermission.Text = ""
	$syncHash.DC.LbFoldersChosen[0].Clear()
	Update-FolderList
}

function Update-DiskList
{
	<#
	.Synopsis
		Fill combobox list with disk-folders
	#>

	"G:\", "S:\", "R:\" | `
		Get-ChildItem2 -Directory | `
		Where-Object { $_.FullName -in $syncHash.HandledFolders } | `
		Select-Object -ExpandProperty FullName | `
		ForEach-Object {
			$syncHash.DC.CbDisk[0].Add( $_ ) | Out-Null
		}
}

function Update-FolderList
{
	<#
	.Synopsis
		Get folders
	#>

	Set-WinTitle -Text $syncHash.Data.msgTable.StrGetFolders
	$syncHash.DC.LbFoldersChosen[0].Clear()
	$syncHash.Folders = [System.Collections.ArrayList]::new()

	if ( $syncHash.DC.CbDisk[1].Length -gt 0 )
	{
		if ( $syncHash.DC.CbDisk[1] -match "^S" )
		{
			$Folders = Get-ChildItem $syncHash.DC.CbDisk[1] -Directory | `
				Get-ChildItem -Directory | `
				ForEach-Object {
					$Temp = ( $_ | Select-Object * )
					$NTD = $Temp.FullName -replace "$( $syncHash.DC.CbDisk[1] -replace "\\","\\" )\\", ""
					Add-Member -InputObject $Temp -MemberType NoteProperty -Name "NameToDisplay" -Value $NTD
					$syncHash.Folders.Add( $Temp ) | Out-Null
				}
		}
		else
		{
			$Folders = Get-ChildItem $syncHash.DC.CbDisk[1] -Directory | `
				ForEach-Object {
					$syncHash.Folders.Add( $_ ) | Out-Null
				}
		}

		$syncHash.Controls.TbFolderSearch.Focus()
		Update-FolderListItems
	}
	Set-WinTitle -Text $syncHash.Data.msgTable.StrTitle
}

function Update-FolderListItems
{
	<#
	.Synopsis
		Fill list of folders
	#>

	$syncHash.DC.LbFolderList[0].Clear()
	foreach ( $Folder in ( $syncHash.Folders | Where-Object { $syncHash.DC.LbFoldersChosen[0] -notcontains $_ } | Sort-Object NameToDisplay, Name ) )
	{
		[void] $syncHash.DC.LbFolderList[0].Add( $Folder )
	}
}

function Write-ToLogbox
{
	<#
	.Synopsis
		Creates text to write to the logoutputbox
	#>

	$LogText = [pscustomobject]@{
		Date = "$( Get-Date -Format "yyyy-MM-dd HH:mm:ss" )"
		Folders = [System.Collections.ArrayList]::new()
		Perms = [System.Collections.ArrayList]::new()
		ErrorUsers = [System.Collections.ArrayList]::new()
		ErrorGroups = [System.Collections.ArrayList]::new()
	}
	$syncHash.Data.ADGroups.Id | `
		ForEach-Object {
			$LogText.Folders.Add( $_ ) | Out-Null
		}

	if ( $syncHash.Data.WriteUsers )
	{
		$Perms = [pscustomobject]@{
			PermType = $syncHash.Data.msgTable.StrPermReadWrite
			Users = [System.Collections.ArrayList]::new()
		}
		$syncHash.Data.WriteUsers | `
			ForEach-Object {
				$Perms.Users.Add( $_.Name ) | Out-Null
			}
		$LogText.Perms.Add( $Perms ) | Out-Null
	}

	if ( $syncHash.Data.ReadUsers )
	{
		$Perms = [pscustomobject]@{
			PermType = $syncHash.Data.msgTable.StrPermRead
			Users = [System.Collections.ArrayList]::new()
		}
		$syncHash.Data.ReadUsers | `
			ForEach-Object {
				$Perms.Users.Add( $_.Name ) | Out-Null
			}
		$LogText.Perms.Add( $Perms ) | Out-Null
	}

	if ( $syncHash.Data.RemoveUsers )
	{
		$Perms = [pscustomobject]@{
			PermType = $syncHash.Data.msgTable.StrPermRemove
			Users = [System.Collections.ArrayList]::new()
		}
		$syncHash.Data.RemoveUsers | `
			ForEach-Object {
				$Perms.Users.Add( $_.Name ) | Out-Null
			}
		$LogText.Perms.Add( $Perms ) | Out-Null
	}

	if ( $syncHash.Data.ErrorUsers )
	{
		$Perms = [pscustomobject]@{
			PermType = $syncHash.Data.msgTable.StrFinNoAccounts
			Users = [System.Collections.ArrayList]::new()
		}
		$syncHash.Data.ErrorUsers | `
			ForEach-Object {
				$Perms.Users.Add( $_.Name ) | Out-Null
			}
		$LogText.Perms.Add( $Perms ) | Out-Null
	}

	if ( $syncHash.Data.ErrorGroups )
	{
		$Perms = [pscustomobject]@{
			PermType = $syncHash.Data.msgTable.StrFinNoAdGroups
			Users = [System.Collections.ArrayList]::new()
		}
		$syncHash.Data.ErrorGroups | `
			ForEach-Object {
				$Perms.Users.Add( $_.Name ) | Out-Null
			}
		$LogText.Perms.Add( $Perms ) | Out-Null
	}

	$syncHash.DC.LbLog[0].Insert( 0, $LogText )
}

function Write-ToLogFile
{
	<#
	.Synopsis
		Write last operations to logfile
	#>

	# One line per group/user
	$LogText = "$( $syncHash.Data.msgTable.LogMessageGroups )`n"
	$syncHash.Data.ADGroups | `
		ForEach-Object {
			$LogText += "$( $_.Id ): $( $_.Read ) / $( $_.Write )`n"
		}

	$OFS = ", "
	if ( $syncHash.Data.ReadUsers.Count -gt 0 )
	{
		$LogText += "`n$( $syncHash.Data.msgTable.LogMessageRead ): $( [string]$syncHash.Data.ReadUsers.Id )`n"
	}

	if ( $syncHash.Data.WriteUsers.Count -gt 0 )
	{
		$LogText += "`n$( $syncHash.Data.msgTable.LogMessageWrite ): $( [string]$syncHash.Data.WriteUsers.Id )`n"
	}

	if ( $syncHash.Data.RemoveUsers.Count -gt 0 )
	{
		$LogText += "`n$( $syncHash.Data.msgTable.LogMessageRemove ): $( [string]$syncHash.Data.RemoveUsers.Id )`n"
	}

	if ( $syncHash.Data.ErrorUsers.Count -gt 0 )
	{
		$LogText += "`n$( $syncHash.Data.msgTable.LogMessageUsersNotFound ): $( [string]$syncHash.Data.ErrorUsers.Id )`n"
	}

	if ( $syncHash.Data.ErrorGroups.Count -gt 0 )
	{
		$LogText += "`n$( $syncHash.Data.msgTable.LogMessageGroupsNotFound ): $( [string]$syncHash.Data.ErrorGroups )`n"
	}

	$UserInput = ""
	if ( $syncHash.Controls.TbUsersForReadPermission.Text.Length -gt 0 )
	{
		$UserInput += "$( $syncHash.Data.msgTable.LogInputRead ): $( $syncHash.Controls.TbUsersForReadPermission.Text -split "\W" )`n"
	}

	if ( $syncHash.Controls.TbUsersForWritePermission.Text.Length -gt 0 )
	{
		$UserInput += "$( $syncHash.Data.msgTable.LogInputWrite ): $( $syncHash.Controls.TbUsersForWritePermission.Text -split "\W" )`n"
	}

	if ( $syncHash.Controls.TbUsersForRemovePermission.Text.Length -gt 0 )
	{
		$UserInput += "$( $syncHash.Data.msgTable.LogInputRemove ): $( $syncHash.Controls.TbUsersForRemovePermission.Text -split "\W" )`n"
	}
	$UserInput += "$( $syncHash.Data.msgTable.LogInputGroups ): $( [string]$syncHash.DC.LbFoldersChosen[0] )"

	WriteLog -Text $LogText -UserInput $UserInput -Success ( $syncHash.Data.ErrorLogHashes.Count -eq 0 ) -ErrorLogHash $syncHash.Data.ErrorLogHashes | Out-Null
}

######################################### Script start
$controls = New-Object Collections.ArrayList
[void]$controls.Add( @{ CName = "BtnPerform" ; Props = @( @{ PropName = "IsEnabled"; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "CbDisk" ; Props = @( @{ PropName = "ItemsSource"; PropVal = [System.Collections.ObjectModel.ObservableCollection[Object]]::new( ) } ; @{ PropName = "SelectedItem"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "ChbUseSignature" ; Props = @( @{ PropName = "IsChecked"; PropVal = $true } ) } )
[void]$controls.Add( @{ CName = "LbFolderList" ; Props = @( @{ PropName = "ItemsSource"; PropVal = [System.Collections.ObjectModel.ObservableCollection[Object]]::new( ) } ; @{ PropName = "SelectedIndex"; PropVal = -1 } ; @{ PropName = "SelectedItem"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "LbFoldersChosen" ; Props = @( @{ PropName = "ItemsSource"; PropVal = [System.Collections.ObjectModel.ObservableCollection[Object]]::new( ) } ; @{ PropName = "SelectedIndex"; PropVal = -1 } ; @{ PropName = "SelectedItem"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "LbLog" ; Props = @( @{ PropName = "ItemsSource"; PropVal = [System.Collections.ObjectModel.ObservableCollection[Object]]::new( ) } ) } )
[void]$controls.Add( @{ CName = "MainGrid" ; Props = @( @{ PropName = "IsEnabled"; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "MainGrid" ; Props = @( @{ PropName = "IsEnabled"; PropVal = $false } ) } )

BindControls $syncHash $controls

$syncHash.Data.ErrorLogFilePath = ""
$syncHash.Data.HandledFolders = @()
$syncHash.Data.ErrorLogHashes = @()
$syncHash.Data.LogFilePath = ""
$syncHash.Data.Signature = $syncHash.Data.msgTable.StrSign
$syncHash.Data.ErrorLog = $null
$syncHash.Data.Loaded = $false

# Folders depending on user AD-groups
$syncHash.Data.KatalogHandledFolders =
"G:\Org1",
"G:\Org2",
"G:\Org3",

"R:\Org1",
"R:\Org2",
"R:\Org3",

"S:\Org1",
"S:\Org2",
"S:\Org3"

$syncHash.Data.ServicedeskHandledFolders =
"G:\Org1",
"G:\Org2",
"G:\Org3",

"R:\Org1",

"S:\Org1",
"S:\Org2"

# Folders to exclude
$syncHash.Data.ExceptionFolders = ""

Reset-Variables

$syncHash.Controls.BtnPerform.Add_Click( {
	$DupList = ( ( $syncHash.Controls.TbUsersForWritePermission.Text -split "\W" ) + ( $syncHash.Controls.TbUsersForReadPermission.Text -split "\W" ) + ( $syncHash.Controls.TbUsersForRemovePermission -split "\W" ) | `
		Group-Object | `
		Where-Object { $_.Count -gt 1 } | `
		Select-Object -ExpandProperty Name ) -join ", "
	if ( $DupList.Length -gt 0 )
	{
		Show-MessageBox -Text "$( $syncHash.Data.msgTable.StrConfirmDups )`n$( $DupList )" -Title $syncHash.Data.msgTable.StrConfirmDupsTitle -Icon "Stop"
	}
	else
	{
		Perform-Permissions
	}

} )

$syncHash.Controls.BtnUndo.Add_Click( {
	Undo-Input
} )

$syncHash.Controls.CbDisk.Add_DropDownClosed( {
	if ( $syncHash.DC.CbDisk[1] -ne $null )
	{
		Update-FolderList
	}
} )

$syncHash.Controls.TbFolderSearch.Add_KeyUp( {
	if ( $args[1].Key -eq "Down" ) {
		$syncHash.Controls.LbFolderList.SelectedIndex = 0
		$syncHash.Controls.LbFolderList.Focus()
	}
} )

$syncHash.Controls.TbFolderSearch.Add_TextChanged( {
	Search-ListboxItem
} )

$syncHash.Controls.LbFolderList.Add_KeyDown( {
	if ( $args[1].Key -eq "Enter" )
	{
		Folder-Selected
	}
} )

$syncHash.Controls.LbFolderList.Add_MouseDoubleClick( {
	Folder-Selected
} )

$syncHash.Controls.LbFoldersChosen.Add_MouseDoubleClick( {
	Folder-Deselected
} )

$syncHash.Controls.TbUsersForWritePermission.Add_TextChanged( {
	Check-Ready
} )

$syncHash.Controls.TbUsersForReadPermission.Add_TextChanged( {
	Check-Ready
} )

$syncHash.Controls.TbUsersForRemovePermission.Add_TextChanged( {
	Check-Ready
} )

$syncHash.Controls.Window.Add_Loaded( {
	Set-WinTitle -Text $syncHash.Data.msgTable.StrPreping
	if ( -not $syncHash.Data.Loaded )
	{
		Set-UserSettings
		Update-DiskList
		$syncHash.Data.Loaded = $true
	}
	$syncHash.DC.MainGrid[0] = $true
	Set-WinTitle -Text $syncHash.Data.msgTable.StrTitle
} )

Export-ModuleMember

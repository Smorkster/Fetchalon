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
	None
.Author
	Smorkster (smorkster)
#>

Add-Type -AssemblyName PresentationFramework
$syncHash = $args[0]

function CheckReady
{
	<#
	.Synopsis
		Some input is entered, check if necessary input is given, enable button to perform
	#>

	if ( ( $syncHash.DC.LbFoldersChosen[0].Count -gt 0 ) -and ( ( $syncHash.Controls.TxtUsersForWritePermission.Text.Length -ge 4 ) -or ( $syncHash.Controls.TxtUsersForReadPermission.Text.Length -ge 4 ) -or ( $syncHash.Controls.TxtUsersForRemovePermission.Text.Length -ge 4 ) ) )
	{
		$syncHash.DC.BtnPerform[0] = $true
	}
	else
	{
		$syncHash.DC.BtnPerform[0] = $false
	}
}

function CheckUser
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
	if ( dsquery User -samid $Id ) { return "User" }
	elseif ( dsquery Group -samid $Id ) { return "Group" }
	elseif ( $EKG = Get-ADGroup -LDAPFilter "($( $syncHash.Data.msgTable.StrEGroupIdName )=$( $syncHash.Data.msgTable.StrEGroupOrg )-$Id)" )
	{
		if ( $EKG.Count -gt 1 ) { return "EGroups" }
		else { return "EGroup" }
	}
	else
	{
		$syncHash.Data.ErrorLogHashes += WriteErrorLogTest -LogText ( "{0} {1}" -f $syncHash.Data.msgTable.ErrNotFoundUser, $Id ) -UserInput $Id -Severity "UserInputFail"
		return "NotFound"
	}
}

function CollectADGroups
{
	<#
	.Synopsis
		Collect AD-groups for folders
	#>

	if ( $syncHash.DC.CbDisk[1].Substring( 1, 2 ) -eq ":\" )
	{
		switch ( $syncHash.DC.CbDisk[1].Substring( 0, 1 ) )
		{
			"G" { CollectADGroupsG -Entries $syncHash.DC.LbFoldersChosen[0] }
			"R" { CollectADGroupsR -Entries $syncHash.DC.LbFoldersChosen[0] }
			"S" { CollectADGroupsS -Entries $syncHash.DC.LbFoldersChosen[0] }
		}
	}
	else
	{
		foreach ( $entry in $syncHash.DC.LbFoldersChosen[0] )
		{ $syncHash.Data.ADGroups += @{ "Id" = $entry } }
	}
}

function CollectADGroupsG
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
		SetWinTitle -Text $syncHash.Data.msgTable.StrTitleProgressGroups -Progress $loopCounter -Max $Entries.Count

		$FolderName = $syncHash.DC.CbDisk[1].ToString() + "\" + $entry
		$entry = $entry -replace " ", "_"
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
				$syncHash.Data.ErrorLogHashes += WriteErrorLogTest -LogText $syncHash.Data.msgTable.ErrNotFoundGrpForGWrite -UserInput $entry -Severity "UserInputFail"
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
				$syncHash.Data.ErrorLogHashes += WriteErrorLogTest -LogText $syncHash.Data.msgTable.ErrNotFoundGrpForGRead -UserInput $entry -Severity "UserInputFail"
				$ReadGroup = $null
			}
		}
		if ( $WriteGroup -and $ReadGroup )
		{ $syncHash.Data.ADGroups += @{ "Id" = $FolderName; "Write" = $WriteGroup.SamAccountName; "Read" = $ReadGroup.SamAccountName } }
		else
		{ $syncHash.Data.ErrorGroups += $FolderName }

		$loopCounter++
	}
}

function CollectADGroupsR
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
		SetWinTitle -Text ( Invoke-Expression $syncHash.Data.msgTable.StrTitleProgressGroups ) -Progress $loopCounter -Max $Entries.Count

		$FolderName = $syncHash.DC.CbDisk[1].ToString() + "\" + $entry
		$entry = $entry -replace " ", "_"
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
						$syncHash.Data.ErrorLogHashes += WriteErrorLogTest -LogText $syncHash.Data.msgTable.ErrNotFoundGrpForRWrite -UserInput $entry -Severity "UserInputFail"
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
						$syncHash.Data.ErrorLogHashes += WriteErrorLogTest -LogText $syncHash.Data.msgTable.ErrNotFoundGrpForRRead -UserInput $entry -Severity "UserInputFail"
						$ReadGroup = $null
					}
				}
			}
		}
		if ( $WriteGroup -and $ReadGroup )
		{ $syncHash.Data.ADGroups += @{ "Id" = $FolderName; "Write" = $WriteGroup.SamAccountName; "Read" = $ReadGroup.SamAccountName } }
		else
		{ $syncHash.Data.ErrorGroups += $FolderName }

		$loopCounter++
	}
	SetWinTitle -Text ""
}

function CollectADGroupsS
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
		SetWinTitle -Text ( Invoke-Expression $syncHash.Data.msgTable.StrTitleProgressGroups ) -Progress $loopCounter -Max $entries.Count

		$FolderName = $syncHash.DC.CbDisk[1].ToString() + "\" + $entry
		$entry = $entry -replace " ", "_"
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
				$syncHash.Data.ErrorLogHashes += WriteErrorLogTest -LogText $syncHash.Data.msgTable.ErrNotFoundGrpForSWrite -UserInput $entry -Severity "UserInputFail"
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
				$syncHash.Data.ErrorLogHashes += WriteErrorLogTest -LogText $syncHash.Data.msgTable.ErrNotFoundGrpForSRead -UserInput $entry -Severity "UserInputFail"
				$ReadGroup = $null
			}
		}
		if ( $WriteGroup -and $ReadGroup )
		{ $syncHash.Data.ADGroups += @{ "Id" = $FolderName; "Write" = $WriteGroup.SamAccountName; "Read" = $ReadGroup.SamAccountName } }
		else
		{ $syncHash.Data.ErrorGroups += $FolderName }

		$loopCounter++
	}
}

function CollectEntries
{
	<#
	.Synopsis
		Collect input from textboxes
	#>

	if ( ( $entries = $syncHash.Controls.TxtUsersForWritePermission.Text -split { " ",",",";","`n","." -contains $_ } -replace "`n" | Where-Object { $_ } | ForEach-Object { $_.Trim() } ).Count -gt 0 )
	{
		CollectUsers -Entries $entries -PermissionType "Write"
	}
	if ( ( $entries = $syncHash.Controls.TxtUsersForReadPermission.Text -split { " ",",",";","`n","." -contains $_ } -replace "`n" | Where-Object { $_ } | ForEach-Object { $_.Trim() } ).Count -gt 0 )
	{
		CollectUsers -Entries $entries -PermissionType "Read"
	}
	if ( ( $entries = $syncHash.Controls.TxtUsersForRemovePermission.Text -split { " ",",",";","`n","." -contains $_ } -replace "`n" | Where-Object { $_ } | ForEach-Object { $_.Trim() } ).Count -gt 0 )
	{
		CollectUsers -Entries $entries -PermissionType "Remove"
	}
}

function CollectUsers
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

	foreach ( $entry in $entries )
	{
		SetWinTitle -Text "$( $syncHash.Data.msgTable.StrStartPrep ) '$PermissionType'" -Progress $loopCounter -Max $entries.Count
		$UserType = CheckUser -Id $entry
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
				{ $_ -match "^EGroup" } { $ADObj = Get-ADGroup -LDAPFilter "($( $syncHash.Data.msgTable.StrEGroupIdName )=$( $syncHash.Data.msgTable.StrEGroupOrg )-$entry)" -Properties $syncHash.Data.msgTable.StrEGroupIdName, $syncHash.Data.msgTable.StrEGroupDn }
			}
			foreach ( $u in $ADObj )
			{
				if ( $u.ObjectClass -eq "User" )
				{ $name = $u.Name }
				else
				{ $name = "$( ( $u.$( $syncHash.Data.msgTable.StrEGroupDn ) -replace "," -split "ou=" )[1] ) ($( ( $u.$( $syncHash.Data.msgTable.StrEGroupIdName ) -split "-" )[1] ))" }
				$o = @{ "Id" = $entry.ToString().ToUpper(); "AD" = $u; "Type" = $UserType -replace "EGroups", "EGroup"; "Name" = $name }
				if ( ( $syncHash.Data.WriteUsers | Where-Object { $_.Id -eq $o.Id } ) -or
					( $syncHash.Data.ReadUsers | Where-Object { $_.Id -eq $o.Id } ) -or
					( $syncHash.Data.RemoveUsers | Where-Object { $_.Id -eq $o.Id } ) )
				{
					$syncHash.Data.Duplicates += $o.Id
				}
				else
				{
					switch ( $PermissionType )
					{
						"Write" { $syncHash.Data.WriteUsers += $o }
						"Read" { $syncHash.Data.ReadUsers += $o }
						"Remove" { $syncHash.Data.RemoveUsers += $o }
					}
				}
			}
		}
		$loopCounter++
	}
	SetWinTitle -Text ""
}

function CreateMessage
{
	<#
	.Synopsis
		Create message
	#>

	$Message = @( $syncHash.Data.msgTable.StrFinIntro )
	$syncHash.Data.ADGroups.Id | ForEach-Object { $Message += "`t$_" }
	if ( $syncHash.Data.WriteUsers )
	{
		$Message += "`n$( $syncHash.Data.msgTable.StrFinPermWrite ):"
		$syncHash.Data.WriteUsers | ForEach-Object { $Message += "`t$( $_.Name )" }
	}
	if ( $syncHash.Data.ReadUsers )
	{
		$Message += "`n$( $syncHash.Data.msgTable.StrFinPermRead ):"
		$syncHash.Data.ReadUsers | ForEach-Object { $Message += "`t$( $_.Name )" }
	}
	if ( $syncHash.Data.RemoveUsers )
	{
		$Message += "`n$( $syncHash.Data.msgTable.StrFinPermRem ):"
		$syncHash.Data.RemoveUsers | ForEach-Object { $Message += "`t$( $_.Name )" }
	}
	if ( $syncHash.Data.ErrorUsers )
	{
		$Message += "`n$( $syncHash.Data.msgTable.StrFinNoAccounts ):"
		$syncHash.Data.ErrorUsers | ForEach-Object { $Message += "`t$_" }
	}
	if ( $syncHash.Data.ErrorGroups )
	{
		$Message += "`n$( $syncHash.Data.msgTable.StrFinNoAdGroups ):"
		$syncHash.Data.ErrorGroups | ForEach-Object { $Message += "`t$_" }
	}

	$Message += $Script:Signatur
	$OutputEncoding = ( New-Object System.Text.UnicodeEncoding $False, $False ).psobject.BaseObject
	$Message | clip
}

function FolderDeselected
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
		CheckReady
		UpdateFolderListItems
		$syncHash.Controls.TxtFolderSearch.Text = ""
		$syncHash.Controls.TxtFolderSearch.Focus()
	}
}

function FolderSelected
{
	<#
	.Synopsis
		A folder is doubleclicked, move it to list of chosen folders
	#>

	if ( $syncHash.DC.LbFolderList[1] -ne -1 )
	{
		$syncHash.DC.LbFoldersChosen[0].Add( $syncHash.DC.LbFolderList[2] )
		$syncHash.DC.LbFolderList[0].Remove( $syncHash.DC.LbFolderList[2] )
		CheckReady
		UpdateFolderListItems
		$syncHash.Controls.TxtFolderSearch.Text = ""
		$syncHash.Controls.TxtFolderSearch.Focus()
	}
}

function GetOtherPerm
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

	SetWinTitle -Text "$( $syncHash.Data.msgTable.StrSearchOtherPermRoutes ) '$Folder'"
	$OFS = ", "
	$Grps = ( Get-Acl $Folder ).Access | Where-Object { $_.IdentityReference -match "C|R$" } | ForEach-Object { $_.IdentityReference -replace "$( $syncHash.Data.msgTable.StrDomain )\\" } | Select-Object -Unique | Get-ADGroup | Get-ADGroupMember
	if ( $OtherPermissionRoutes = foreach ( $Group in $Grps )
		{
			foreach ( $Member in ( Get-ADGroupMember $Group ).Where( { $_.ObjectClass -eq "group" } ) )
			{
				if ( $Members = ( ( Get-ADGroupMember $Member ).SamAccountName | Where-Object { $_ -in $UserList.Id } | Get-ADUser | Select-Object -ExpandProperty Name ) )
				{ [pscustomobject]@{ Group = $Member.Name; Members = [string]$Members } }
			}
		}
	)
	{ [pscustomobject]@{ Folder = $Folder; PermissionsList = $OtherPermissionRoutes } }
}

function PerformPermissions
{
	<#
	.Synopsis
		Start permission editing
	#>

	CollectEntries
	CollectADGroups

	if ( $syncHash.Data.Duplicates )
	{
		Show-MessageBox -Text "$( $syncHash.Data.msgTable.StrConfirmDups )`n$( $syncHash.Data.Duplicates | Select-Object -Unique )" -Title $syncHash.Data.msgTable.StrConfirmDupsTitle -Icon "Stop"
	}
	else
	{
		$Continue = Show-MessageBox -Text "$( $syncHash.Data.msgTable.StrConfirm1 ) $( @( $syncHash.Data.ADGroups ).Count ) $( $syncHash.Data.msgTable.StrConfirm2) $( @( $syncHash.Data.WriteUsers ).Count + @( $syncHash.Data.ReadUsers ).Count + @( $syncHash.Data.RemoveUsers ).Count ) $( $syncHash.Data.msgTable.StrConfirm3 )?$( if ( $syncHash.Data.ErrorGroups -or $syncHash.Data.ErrorUsers ) { "`n$( $syncHash.Data.msgTable.StrConfirmErr )" } )" -Title $syncHash.Data.msgTable.StrConfirmTitle -Button "OKCancel"
		if ( $Continue -eq "OK" )
		{
			$loopCounter = 0
			foreach ( $Group in $syncHash.Data.ADGroups )
			{
				SetWinTitle -Text $syncHash.Data.msgTable.StrStart -Progress $loopCounter -Max $syncHash.Data.ADGroups.Count
				if ( $syncHash.Data.WriteUsers )
				{
					if ( $Group.Write )
					{
						try
						{
							Add-ADGroupMember -Identity $Group.Write -Members $syncHash.Data.WriteUsers.AD.DistinguishedName -Confirm:$false
						}
						catch { $syncHash.Data.ErrorLogHashes += WriteErrorLogTest -LogText $_ -UserInput ( "{0}; {1}" -f $Group.Write, $syncHash.Data.WriteUsers.AD.DistinguishedName ) -Severity "OtherFail" }
					}
				}

				if ( $syncHash.Data.ReadUsers )
				{
					if ( $Group.Read )
					{
						try { Add-ADGroupMember -Identity $Group.Read -Members $syncHash.Data.ReadUsers.AD.DistinguishedName -Confirm:$false 
						}
						catch { $syncHash.Data.ErrorLogHashes += WriteErrorLogTest -LogText $_ -UserInput ( "{0}; {1}" -f $Group.Read, $syncHash.Data.ReadUsers.AD.DistinguishedName ) -Severity "OtherFail" }
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
						catch { $syncHash.Data.ErrorLogHashes += WriteErrorLogTest -LogText $_ -UserInput ( "'{0}', '{1}'; {2}" -f $Group.Write, $Group.Read, $syncHash.Data.ReadUsers.AD.DistinguishedName ) -Severity "OtherFail" }
					}
				}
				$loopCounter++
				Remove-Variable errorD, errorR, errorW -ErrorAction SilentlyContinue
			}

			WriteToLogbox
			WriteToLogFile
			CreateMessage
			Show-MessageBox -Text "$( @( $syncHash.Data.ADGroups ).Count * ( @( $syncHash.Data.WriteUsers ).Count + @( $syncHash.Data.ReadUsers ).Count + @( $syncHash.Data.RemoveUsers ).Count ) ) $( $syncHash.Data.msgTable.StrFinished1 ).`n$( $syncHash.Data.msgTable.StrFinished2 )" -Title "Klar"
			UndoInput
			SetWinTitle -Text $syncHash.Data.msgTable.StrTitle
		}
	}
	ResetVariables
}

function ResetVariables
{
	<#
	.Synopsis
		Initiate/reset scriptwide variables
	#>

	$syncHash.Data.ADGroups = @()
	$syncHash.Data.Duplicates = @()
	$syncHash.Data.ErrorUsers = @()
	$syncHash.Data.ErrorGroups = @()
	$syncHash.Data.WriteUsers = @()
	$syncHash.Data.ReadUsers = @()
	$syncHash.Data.RemoveUsers = @()
}

function SearchListboxItem
{
	<#
	.Synopsis
		Search for any item containing searchword
	#>

	$list = $syncHash.Folders | Where-Object { $syncHash.DC.LbFoldersChosen[0] -notcontains $_ }
	if ( $syncHash.Controls.TxtFolderSearch.Text.Length -eq 0 )
	{
		$syncHash.DC.LbFolderList[1] = -1
	}
	else
	{
		$list = $list | Where-Object { $_ -like "*$( $syncHash.Controls.TxtFolderSearch.Text.Replace( "\\", "\\\\" ) )*" }
	}
	$syncHash.DC.LbFolderList[0].Clear()
	foreach ( $i in $list )
	{
		$syncHash.DC.LbFolderList[0].Add( $i )
	}
}

function SetUserSettings
{
	<#
	.Synopsis
		Set userdependant settings
	#>

	try
	{
		$a = Get-ADPrincipalGroupMembership $env:USERNAME
		if ( $a.SamAccountName -match $syncHash.Data.msgTable.StrOpGroup )
		{
			$syncHash.LogFilePath = $syncHash.Data.msgTable.StrOpLogPath
			$syncHash.ErrorLogFilePath = "$( $syncHash.Data.msgTable.StrOpLogPath )$( $syncHash.Data.msgTable.StrOpErrLogFile )$( $env:USERNAME ).log"

			$syncHash.HandledFolders = $syncHash.Data.KatalogHandledFolders
			$syncHash.Signatur += "`n`n$( $syncHash.Data.msgTable.StrSignOp )"
		}
		elseif ( $a.SamAccountName -match $syncHash.Data.msgTable.StrSDGroup )
		{
			$syncHash.ErrorLogFilePath = ( ( Get-Item $PSScriptRoot ).Parent.FullName ) + "\ErrorLogs\" + ( Get-Item $PSCommandPath ).BaseName + "\" + $env:USERNAME + " ErrorLog.txt"
			$syncHash.LogFilePath = ( ( Get-Item $PSScriptRoot ).Parent.FullName) + "\Log\" + $( [datetime]::Now.Year ) + "\" + [datetime]::Now.Month + "\" + ( Get-Item $PSCommandPath ).BaseName + "\"

			$syncHash.HandledFolders = $syncHash.Data.ServicedeskHandledFolders
			$syncHash.Signatur += "`n`n$( $syncHash.Data.msgTable.StrSignSD )"
		}
		else
		{ throw }
	}
	catch
	{
		Show-MessageBox -Text "$( $syncHash.Data.msgTable.StrNoPerm )`n$( $_.Exception.Message )" -Title $syncHash.Data.msgTable.StrNoPermTitle -Icon "Stop"
		WriteErrorLogTest -LogText "SetUserSettings:`n$_" -UserInput $env:USERNAME -Severity -1 | Out-Null
	}
}

function SetWinTitle
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

function UndoInput
{
	<#
	.Synopsis
		Clear all input
	#>

	$syncHash.Controls.TxtUsersForWritePermission.Text = ""
	$syncHash.Controls.TxtUsersForReadPermission.Text = ""
	$syncHash.Controls.TxtUsersForRemovePermission.Text = ""
	$syncHash.DC.LbFoldersChosen[0].Clear()
	UpdateFolderList
}

function UpdateDiskList
{
	<#
	.Synopsis
		Fill combobox list with disk-folders
	#>

	"G:\", "S:\", "R:\" | Get-ChildItem2 -Directory | Where-Object { $_.FullName -in $syncHash.HandledFolders } | Select-Object -ExpandProperty FullName | ForEach-Object { [void] $syncHash.DC.CbDisk[0].Add( $_ ) }
	SetWinTitle -Text $syncHash.Data.msgTable.StrTitle
}

function UpdateFolderList
{
	<#
	.Synopsis
		Get folders
	#>

	SetWinTitle -Text $syncHash.Data.msgTable.StrGetFolders
	$syncHash.DC.LbFoldersChosen[0].Clear()
	$syncHash.Folder = @()

	if ( $syncHash.DC.CbDisk[1].Length -gt 0 )
	{
		if ( $syncHash.DC.CbDisk[1][0] -eq "S" )
		{
			$syncHash.Folders = ( ( Get-ChildItem $syncHash.DC.CbDisk[1] -Directory ).FullName | Get-ChildItem ).FullName.Replace( "$( $syncHash.DC.CbDisk[1] )\", "" ) | Sort-Object
		}
		else
		{
			$syncHash.Folders = Get-ChildItem $syncHash.DC.CbDisk[1] -Directory | Where-Object { $_.FullName -notin $syncHash.Data.ExceptionFolders } | Select-Object -ExpandProperty Name | Sort-Object
		}
		$syncHash.Controls.TxtFolderSearch.Focus()
		UpdateFolderListItems
	}
	SetWinTitle -Text $syncHash.Data.msgTable.StrTitle
}

function UpdateFolderListItems
{
	<#
	.Synopsis
		Fill list of folders
	#>

	$syncHash.DC.LbFolderList[0].Clear()
	foreach ( $Folder in ( $syncHash.Folders | Where-Object { $syncHash.DC.LbFoldersChosen[0] -notcontains $_ } ) )
	{
		[void] $syncHash.DC.LbFolderList[0].Add( $Folder )
	}
}

function WriteToLogbox
{
	<#
	.Synopsis
		Creates text to write to the logoutputbox
	#>

	$LogText = "$( Get-Date -Format "yyyy-MM-dd HH:mm:ss" )"
	$syncHash.Data.ADGroups.Id | ForEach-Object { $LogText += "`n$_" }
	if ( $syncHash.Data.WriteUsers )
	{
		$LogText += "`n$( $syncHash.Data.msgTable.StrPermReadWrite )"
		$syncHash.Data.WriteUsers | ForEach-Object { $LogText += "`n`t$( $_.Name )" }
	}

	if ( $syncHash.Data.ReadUsers )
	{
		$LogText += "`n$( $syncHash.Data.msgTable.StrPermRead )"
		$syncHash.Data.ReadUsers | ForEach-Object { $LogText += "`n`t$( $_.Name )" } }

	if ( $syncHash.Data.RemoveUsers )
	{
		$LogText += "`n$( $syncHash.Data.msgTable.StrPermRemove )"
		$syncHash.Data.RemoveUsers | ForEach-Object { $LogText += "`n`t$( $_.Name )" }
	}

	if ( $syncHash.Data.ErrorUsers )
	{
		$LogText += "`n$( $syncHash.Data.msgTable.StrFinNoAccounts )"
		$syncHash.Data.ErrorUsers | ForEach-Object { $LogText += "`n`t$( $_.Id )" }
	}

	if ( $syncHash.Data.ErrorGroups )
	{
		$LogText += "`n$( $syncHash.Data.msgTable.StrFinNoAdGroups )"
		$syncHash.Data.ErrorGroups | ForEach-Object { $LogText += "`n`t$_" }
	}

	$LogText += "`n------------------------------"
	$syncHash.DC.LbLog[0].Insert( 0, $LogText )

}

function WriteToLogFile
{
	<#
	.Synopsis
		Write last operations to logfile
	#>

	# One line per group/user
	$LogText = "$( $syncHash.Data.msgTable.LogMessageGroups )`n"
	$syncHash.Data.ADGroups | ForEach-Object { $LogText += "$( $_.Id ): $( $_.Read ) / $( $_.Write )`n" }

	$OFS = ", "
	if ( $syncHash.Data.ReadUsers.Count -gt 0 ) { $LogText += "`n$( $syncHash.Data.msgTable.LogMessageRead ): $( [string]$syncHash.Data.ReadUsers.Id )`n" }
	if ( $syncHash.Data.WriteUsers.Count -gt 0 ) { $LogText += "`n$( $syncHash.Data.msgTable.LogMessageWrite ): $( [string]$syncHash.Data.WriteUsers.Id )`n" }
	if ( $syncHash.Data.RemoveUsers.Count -gt 0 ) { $LogText += "`n$( $syncHash.Data.msgTable.LogMessageRemove ): $( [string]$syncHash.Data.RemoveUsers.Id )`n" }
	if ( $syncHash.Data.ErrorUsers.Count -gt 0 ) { $LogText += "`n$( $syncHash.Data.msgTable.LogMessageUsersNotFound ): $( [string]$syncHash.Data.ErrorUsers.Id )`n" }
	if ( $syncHash.Data.ErrorGroups.Count -gt 0 ) { $LogText += "`n$( $syncHash.Data.msgTable.LogMessageGroupsNotFound ): $( [string]$syncHash.Data.ErrorGroups )`n" }

	$UserInput = ""
	if ( $syncHash.Controls.TxtUsersForReadPermission.Text.Length -gt 0 ) { $UserInput += "$( $syncHash.Data.msgTable.LogInputRead ): $( $syncHash.Controls.TxtUsersForReadPermission.Text -split "\W" )`n" }
	if ( $syncHash.Controls.TxtUsersForWritePermission.Text.Length -gt 0 ) { $UserInput += "$( $syncHash.Data.msgTable.LogInputWrite ): $( $syncHash.Controls.TxtUsersForWritePermission.Text -split "\W" )`n" }
	if ( $syncHash.Controls.TxtUsersForRemovePermission.Text.Length -gt 0 ) { $UserInput += "$( $syncHash.Data.msgTable.LogInputRemove ): $( $syncHash.Controls.TxtUsersForRemovePermission.Text -split "\W" )`n" }
	$UserInput += "$( $syncHash.Data.msgTable.LogInputGroups ): $( [string]$syncHash.DC.LbFoldersChosen[0] )"

	WriteLog -Text $LogText -UserInput $UserInput -Success ( $syncHash.Data.ErrorLogHashes.Count -eq 0 ) -ErrorLogHash $syncHash.Data.ErrorLogHashes | Out-Null
}

######################################### Script start
$controls = New-Object Collections.ArrayList
[void]$controls.Add( @{ CName = "BtnPerform" ; Props = @( @{ PropName = "IsEnabled"; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "CbDisk" ; Props = @( @{ PropName = "ItemsSource"; PropVal = [System.Collections.ObjectModel.ObservableCollection[Object]]::new( ) } ; @{ PropName = "SelectedItem"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "LbFolderList" ; Props = @( @{ PropName = "ItemsSource"; PropVal = [System.Collections.ObjectModel.ObservableCollection[Object]]::new( ) } ; @{ PropName = "SelectedIndex"; PropVal = -1 } ; @{ PropName = "SelectedItem"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "LbFoldersChosen" ; Props = @( @{ PropName = "ItemsSource"; PropVal = [System.Collections.ObjectModel.ObservableCollection[Object]]::new( ) } ; @{ PropName = "SelectedIndex"; PropVal = -1 } ; @{ PropName = "SelectedItem"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "LbLog" ; Props = @( @{ PropName = "ItemsSource"; PropVal = [System.Collections.ObjectModel.ObservableCollection[Object]]::new( ) } ) } )
[void]$controls.Add( @{ CName = "MainGrid" ; Props = @( @{ PropName = "IsEnabled"; PropVal = $false } ) } )

BindControls $syncHash $controls

$syncHash.Data.ErrorLogFilePath = ""
$syncHash.Data.HandledFolders = @()
$syncHash.Data.ErrorLogHashes = @()
$syncHash.Data.LogFilePath = ""
$syncHash.Data.Signatur = $syncHash.Data.msgTable.StrSign
$syncHash.Data.ErrorLog = $null

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

ResetVariables

$syncHash.Controls.BtnPerform.Add_Click( { PerformPermissions } )
$syncHash.Controls.BtnUndo.Add_Click( { UndoInput } )
$syncHash.Controls.CbDisk.Add_DropDownClosed( { if ( $syncHash.DC.CbDisk[1] -ne $null ) { UpdateFolderList } } )
$syncHash.Controls.TxtFolderSearch.Add_KeyUp( {
	if ( $args[1].Key -eq "Down" ) {
		$syncHash.Controls.LbFolderList.SelectedIndex = 0
		$syncHash.Controls.LbFolderList.Focus()
	}
} )
$syncHash.Controls.TxtFolderSearch.Add_TextChanged( { SearchListboxItem } )
$syncHash.Controls.LbFolderList.Add_KeyDown( { if ( $args[1].Key -eq "Enter" ) { FolderSelected } } )
$syncHash.Controls.LbFolderList.Add_MouseDoubleClick( { FolderSelected } )
$syncHash.Controls.LbFoldersChosen.Add_MouseDoubleClick( { FolderDeselected } )
$syncHash.Controls.TxtUsersForWritePermission.Add_TextChanged( { CheckReady } )
$syncHash.Controls.TxtUsersForReadPermission.Add_TextChanged( { CheckReady } )
$syncHash.Controls.TxtUsersForRemovePermission.Add_TextChanged( { CheckReady } )
$syncHash.Controls.Window.Add_Loaded( {
	SetWinTitle -Text $syncHash.Data.msgTable.StrPreping
	SetUserSettings
	UpdateDiskList
	$syncHash.DC.MainGrid[0] = $true
} )

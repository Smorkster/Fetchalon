<#
.Synopsis
	Edit permissions in AD-groups for applications
.MenuItem
	Edit AD-groups for applications
.RequiredAdGroups
	Rol_Servicedesk_Backoffice
.Description
	Add or remove permissions to applications through their respective AD-groups.
	Once the changes have been made, a solution message is copied to the clipboard.
.ObjectOperations
	Group
.State
	Prod
.Author
	Smorkster (smorkster)
#>

Add-Type -AssemblyName PresentationFramework
$syncHash = $args[0]

function Check-Ready
{
	<#
	.Synopsis
		Verify if operations is ready to perform
	#>

	if ( ( $syncHash.Controls.Window.Resources['CvsSelectedGrps'].Source.Count -gt 0 ) -and ( ( $syncHash.Controls.TxtUsersAddPermission.Text.Length -ge 4 ) -or ( $syncHash.Controls.TxtUsersRemovePermission.Text.Length -ge 4 ) ) )
	{
		$syncHash.Controls.BtnPerform.IsEnabled = $true
	}
	else
	{
		$syncHash.Controls.BtnPerform.IsEnabled = $false
	}
}

function Check-User
{
	<#
	.Synopsis
		Check if user exists in AD
	.Parameter Id
		Id to verify as userId
	.Outputs
		String if the user exists, or value is not a valid Id
	#>

	param ( [string] $Id )

	try
	{
		if ( $null -eq ( $ret = Get-ADObject -LDAPFilter "(|(Name=$( $Id ))(SamAccountName=$( $Id )))" -Properties otherMailbox -ErrorAction Stop ) )
		{
			throw [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]::new()
		}
		else
		{
			return $ret
		}
	}
	catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]
	{
		$syncHash.ErrorUsers += @{ "Id" = $Id ; "Reason" = $syncHash.Data.msgTable.ErrUserNotFound }
		$syncHash.Data.ErrorHashes += WriteErrorLog -LogText "$( $syncHash.Data.msgTable.ErrMessageGetUser )" -UserInput $Id -Severity "UserInputFail"
		return "NotFound"
	}
	catch
	{
		$syncHash.ErrorUsers += @{ "Id" = $Id ; "Reason" = $_.Exception.Message }
		$syncHash.Data.ErrorHashes += WriteErrorLog -LogText "$( $syncHash.Data.msgTable.ErrMessageGetUser )`n$( $_.Exception.Message )" -UserInput $Id -Severity "OtherFail"
		return $_.Exception.Message
	}
}

function Collect-Computers
{
	<#
	.Synopsis
		Check if computers exists in AD
	.Parameter Entries
		Ids to verify as computer
	#>

	param (
		[array] $Entries
	)

	$loopCounter = 0
	$syncHash.AddComputer = @()
	foreach ( $c in $Entries )
	{
		$syncHash.Controls.Window.Title = "$( $msgTable.StrGettingComputers ) $( [Math]::Floor( $loopCounter / $Entries.Count * 100 ) )"
		$Computer = Get-ADComputer $c -ErrorAction SilentlyContinue
		if ( $Computer )
		{
			$syncHash.AddComputer += $Computer
		}
		else
		{
			$syncHash.ErrorComputer += $Computer
		}
	}
}

function Collect-Entries
{
	<#
	.Synopsis
		Collect input from textboxes
	#>

	if ( $syncHash.Controls.TxtUsersAddPermission.LineCount -gt 0 )
	{
		$entries = $syncHash.Controls.TxtUsersAddPermission.Text -split "\W" | Where-Object { $_ }
		Collect-Users -Entries $entries -PermissionType "Add"
	}

	if ( $syncHash.Controls.TxtUsersRemovePermission.LineCount -gt 0 )
	{
		$entries = $syncHash.Controls.TxtUsersRemovePermission.Text -split "\W" | Where-Object { $_ }
		Collect-Users -Entries $entries -PermissionType "Remove"
	}

	if ( $syncHash.Controls.TbComputer.LineCount -gt 0 )
	{
		$entries = $syncHash.Controls.TbComputer.Text -split "\W" | Where-Object { $_ }
		Collect-Computers -Entries $entries
	}
}

function Collect-Users
{
	<#
	.Synopsis
		Get users in the textbox corresponding to operation
	.Parameter Entries
		Array of values in the textboxes
	.Parameter PermissionType
		What type of permission should be applied for the users in Entries
	#>

	param (
		[array] $Entries,
		[string] $PermissionType
	)

	$loopCounter = 0

	switch ( $PermissionType )
	{
		"Add" { $syncHash.AddUsers = @() }
		"Remove" { $syncHash.RemoveUsers = @() }
	}

	foreach ( $entry in $entries )
	{
		$syncHash.Controls.Window.Title = "$( $msgTable.StrGettingUser ) $( [Math]::Floor( $loopCounter / $entries.Count * 100 ) )"
		$CheckedObject = Check-User -Id $entry
		if ( $CheckedObject -is [Microsoft.ActiveDirectory.Management.ADObject] -and
			$CheckedObject.ObjectClass -match "(user)|(group)"
		)
		{
			$Object = $null
			$Object = @{
				"Id" = $entry.ToString().ToUpper()
				"AD" = $CheckedObject
				"PW" = Generate-Password
			}

			switch ( $PermissionType )
			{
				"Add"
					{ $syncHash.AddUsers += $Object }
				"Remove"
					{ $syncHash.RemoveUsers += $Object }
			}
		}
		$loopCounter++
	}
}

function Create-LogText
{
	<#
	.Synopsis
		Create text for the log in the GUI
	#>

	param ( $Message )

	$LogText = [pscustomobject]@{
		DateTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
		Groups = [System.Collections.ArrayList]::new()
		AddedUsers = [System.Collections.ArrayList]::new()
		RemovedUsers = [System.Collections.ArrayList]::new()
		ErrorUsers = [System.Collections.ArrayList]::new()
		Message = $Message
	}

	$syncHash.Controls.Window.Resources['CvsSelectedGrps'].Source.Name | `
		ForEach-Object {
			$LogText.Groups.Add( $_ )
		}

	if ( $syncHash.AddUsers )
	{
		$syncHash.AddUsers.AD | `
			ForEach-Object {
				$LogText.AddedUsers.Add( $_.Name )
			}
	}

	if ( $syncHash.RemoveUsers )
	{
		$syncHash.RemoveUsers.AD | `
			ForEach-Object {
				$LogText.RemovedUsers.Add( $_.Name )
			}
	}

	if ( $syncHash.ErrorUsers )
	{
		$syncHash.ErrorUsers | `
			ForEach-Object {
				$LogText.ErrorUsers.Add( "$( $_.Id ) ($( $_.Reason ))" )
			}
	}

	$syncHash.Data.Test = $LogText
	$syncHash.Controls.Window.Resources['CvsLog'].Source.Insert( 0, $LogText )
}

function Create-Message
{
	<#
	.Synopsis
		Generate message for performed operation
	#>

	$Message = [System.Text.StringBuilder]::new( "$( $syncHash.Data.msgTable.MsgMessageIntro ) $( $syncHash.Controls.CbApp.SelectedItem.Tag.GroupType )`n" )
	$syncHash.Controls.Window.Resources['CvsSelectedGrps'].Source.Name | `
		ForEach-Object {
			$Message.AppendLine( "`t$_" ) | Out-Null
		}

	if ( $syncHash.AddUsers )
	{
		$Message.AppendLine() | Out-Null
		$Message.AppendLine( "$( $syncHash.Data.msgTable.MsgNew ):" ) | Out-Null
		$syncHash.AddUsers | `
			ForEach-Object {
				$Message.AppendLine( "`t$( $_.AD.Name )$( if ( $_.AD.otherMailbox -match $syncHash.Data.msgTable.StrSpecOrg ) { "( $( $syncHash.Data.msgTable.MsgNewPassword ): $( $_.PW ) )" } )" ) | Out-Null
			}
	}

	if ( $syncHash.RemoveUsers )
	{
		$Message.AppendLine() | Out-Null
		$Message.AppendLine( "$( $syncHash.Data.msgTable.MsgRemove ):" ) | Out-Null
		$syncHash.RemoveUsers.AD | `
			ForEach-Object {
				$Message.AppendLine( "`t$( $_.Name )" ) | Out-Null
			}
	}

	if ( $syncHash.AddComputer )
	{
		$Message.AppendLine() | Out-Null
		$Message.AppendLine( "$( $syncHash.Data.msgTable.MsgAddComputer )" ) | Out-Null
		$syncHash.AddComputer.Name | `
			ForEach-Object {
				$Message.AppendLine( "`t$( $_ )" ) | Out-Null
			}
	}

	if ( $syncHash.ErrorUsers )
	{
		$Message.AppendLine() | Out-Null
		$Message.AppendLine( "`n$( $syncHash.Data.msgTable.MsgNoAccount ):" ) | Out-Null
		$syncHash.ErrorUsers | `
			ForEach-Object {
				$Message.AppendLine( "`t$( $_.Id ) ($( $_.Reason ))" ) | Out-Null
			}
	}

	$Message.AppendLine() | Out-Null
	$Message.AppendLine( "$( $syncHash.Data.msgTable.StrLogOut )" ) | Out-Null
	$Message.AppendLine( "$( $syncHash.Data.Signature )" ) | Out-Null
	$OutputEncoding = [System.Text.UnicodeEncoding]::new( $False, $False ).psobject.BaseObject
	$Message.ToString().Trim() | clip
	return $Message.ToString().Trim()
}

function Generate-Password
{
	<#
	.Synopsis
		Call generator for each of the strings
	.Outputs
		A randomly generated string
	#>

	$p = Get-RandomCharacters -length 1 -characters 'abcdefghikmnprstuvwxyz'
	$p += Get-RandomCharacters -length 1 -characters 'ABCDEFGHKLMNPRSTUVWXYZ'
	$p += Get-RandomCharacters -length 1 -characters '123456789'
	$p += Get-RandomCharacters -length 5 -characters 'abcdefghikmnprstuvwxyzABCDEFGHKLMNPRSTUVWXYZ123456789'
	$p = Scramble-String $p
	return $p
}

function Get-RandomCharacters
{
	<#
	.Synopsis
		Pick random number up to $Length as index in $Characters
	.Parameter Length
		Length of string to return
	.Parameter Characters
		Characters to get a random string from
	.Outputs
		A string of random characters
	#>

	param ( $Length, $Characters )

	$random = 1..$Length | `
		ForEach-Object {
			Get-Random -Maximum $Characters.Length
		}
	$private:OFS = ""
	return [string]$Characters[$random]
}

function Group-Deselected
{
	<#
	.Synopsis
		Remove a group from selected groups
	.Description
		A group in the list of selected groups was doubleclicked. Remove it from selected list, add to grouplist.
	#>

	if ( $null -ne $syncHash.Controls.LbGroupsChosen.SelectedItem )
	{
		$syncHash.Controls.Window.Resources['CvsAppGrps'].Source.Add( $syncHash.Controls.LbGroupsChosen.SelectedItem )
		$syncHash.Controls.Window.Resources['CvsSelectedGrps'].Source.Remove( $syncHash.Controls.LbGroupsChosen.SelectedItem )
		Check-Ready
		Update-AppGroupListItems
	}
}

function Group-Selected
{
	<#
	.Synopsis
		Add a group to list of selected groups
	.Description
		A group was selected. Add it to list of selected groups.
	#>

	if ( $null -ne $syncHash.Controls.LbAppGroupList.SelectedItem )
	{
		$syncHash.Controls.Window.Resources['CvsSelectedGrps'].Source.Add( $syncHash.Controls.LbAppGroupList.SelectedItem )
		$syncHash.Controls.Window.Resources['CvsAppGrps'].Source.Remove( $syncHash.Controls.LbAppGroupList.SelectedItem )
		Check-Ready
		Update-AppGroupListItems
	}
}

function Perform-Permissions
{
	<#
	.Synopsis
		Start operations to apply permissions
	#>

	Collect-Entries

	$Continue = Show-MessageBox -Text "$( $syncHash.Data.msgTable.QCont1 ) $( $syncHash.Controls.Window.Resources['CvsSelectedGrps'].Source.Count ) $( $syncHash.Controls.CbApp.SelectedItem.Tag.GroupType ) $( $syncHash.Data.msgTable.QCont2 ) $( @( $syncHash.AddUsers ).Count + @( $syncHash.RemoveUsers ).Count ) $( $syncHash.Data.msgTable.QCont3 ) ?$( if ( $syncHash.ErrorUsers ) { "`n$( $syncHash.Data.msgTable.QContErr )." } )" -Title "$( $syncHash.Data.msgTable.QContTitle )?" -Button "OKCancel"
	if ( $Continue -eq "OK" )
	{
		$loopCounter = 0
		foreach ( $Group in $syncHash.Controls.Window.Resources['CvsSelectedGrps'].Source )
		{
			$syncHash.Controls.Window.Title = "$( $syncHash.Data.msgTable.StrProgressTitle ) $( [Math]::Floor( $loopCounter / $syncHash.Controls.Window.Resources['CvsSelectedGrps'].Source.Count * 100 ) )%"
			if ( $syncHash.AddUsers )
			{
				try
				{
					Add-ADGroupMember -Identity $Group -Members $syncHash.AddUsers.Id -Confirm:$false
				}
				catch
				{
					try
					{
						Add-ADGroupMember -Identity $Group.Name -Members $syncHash.AddUsers.Id -Confirm:$false
					}
					catch
					{
						$syncHash.Data.ErrorHashes += WriteErrorLog -LogText $_ -UserInput "$( $Group.Name )`n$( $OFS = ", "; $syncHash.AddUsers.Id )" -Severity "UserInputFail"
					}
				}
			}

			if ( $syncHash.RemoveUsers )
			{
				try
				{
					Remove-ADGroupMember -Identity $Group -Members $syncHash.RemoveUsers.Id -Confirm:$false
				}
				catch
				{
					try
					{
						Remove-ADGroupMember -Identity $Group.Name -Members $syncHash.RemoveUsers.Id -Confirm:$false
					}
					catch
					{
						$syncHash.Data.ErrorHashes += WriteErrorLog -LogText $_ -UserInput "$( $Group.Name )`n$( $OFS = ", "; $syncHash.AddUsers.Id )" -Severity "UserInputFail"
					}
				}
			}
			$loopCounter++
		}
		foreach ( $u in ( $syncHash.AddUsers | Where-Object { $_.AD.otherMailbox -match $syncHash.Data.msgTable.StrSpecOrg } ) )
		{
			try
			{
				Set-ADAccountPassword -Identity $u.AD -Reset -NewPassword ( ConvertTo-SecureString -AsPlainText $u.PW -Force )
				Set-ADUser -Identity $u.AD -ChangePasswordAtLogon $false -Confirm:$false
			}
			catch
			{
				$syncHash.Data.ErrorHashes += WriteErrorLog -LogText "$( $syncHash.Data.msgTable.ErrMessageSetPassword )`n$_" -UserInput $u.AD.SamAccountName -Severity "UserInputFail"
			}
		}
		foreach ( $c in $syncHash.AddComputer )
		{
			$syncHash.Controls.CbApp.SelectedItem.Tag.ComputerAdGroups | `
				ForEach-Object {
					$g = $_
					try
					{
						$SysmanComputer = ( Invoke-RestMethod "$( $syncHash.Data.msgTable.CodeSysManUrl )/api/client/?name=$( $c.Name )&take=1&skip=0" -Method Get -UseDefaultCredentials -ContentType "application/json" -ErrorAction Stop ).result[0]
						$SysmanSystem = Invoke-RestMethod "$( $syncHash.Data.msgTable.CodeSysManUrl )/api/System?name=$( $g )" -Method Get -UseDefaultCredentials -ContentType "application/json" -ErrorAction Stop
						if ( $SysmanComputer )
						{
							if ( $SysmanSystem )
							{
								$b = "{ ""targets"": [$( $SysmanComputer.id )], ""softwares"": [$( $SysmanSystem.id )], ""templateTargetId"": 1, ""executeDate"": ""$( ( ( Get-Date ).AddSeconds( 15 ).GetDateTimeFormats() )[30] )"", ""useDirectMembership"": true, ""installationType"": 0, ""useWakeOnLan"": true }"
								Invoke-RestMethod "$( $syncHash.Data.msgTable.CodeSysManUrl )/api/application/Install" -Method Post -UseDefaultCredentials -ContentType "application/json" -Body $b
							}
							else
							{
								WriteErrorLog -LogText "$( $syncHash.Data.msgTable.ErrSysManNoSystem )" -UserInput $g -Severity "UserInputFail"
							}
						}
						else
						{
							WriteErrorLog -LogText "$( $syncHash.Data.msgTable.ErrSysManNoComputer )" -UserInput $c -Severity "UserInputFail"
						}
					}
					catch
					{
						WriteErrorLog -LogText "$( $syncHash.Data.msgTable.ErrSysManGenError )`n$_" -UserInput $c -Severity "OtherFail"
					}
				}
		}
		Create-LogText ( Create-Message )
		Write-ToLogFile
		Show-MessageBox -Text "$( $syncHash.Controls.Window.Resources['CvsSelectedGrps'].Source.Count * ( @( $syncHash.AddUsers ).Count + @( $syncHash.RemoveUsers ).Count ) ) $( $syncHash.Data.msgTable.StrFinishMessage )" -Title "$( $syncHash.Data.msgTable.StrFinishMessageTitle )"

		Undo-Input
		Reset-Variables
		$syncHash.Controls.Window.Title = $syncHash.Data.msgTable.ContentWindowTitle
	}
}

function Reset-Variables
{
	<#
	.Synopsis
		Resets variables
	#>

	$syncHash.AddComputer = @()
	$syncHash.AddUsers = @()
	$syncHash.ADGroups = @()
	$syncHash.ErrorUsers = @()
	$syncHash.Data.ErrorHashes = @()
	$syncHash.RemoveUsers = @()
}

function Scramble-String
{
	<#
	.Synopsis
		Randomize order of charaters in string
	.Parameter InputString
		String to scramble its characters
	.Outputs
		String of scrambled characters
	#>

	param ( [string] $InputString )

	$characterArray = $InputString.ToCharArray()
	$scrambledStringArray = $characterArray | Get-Random -Count $characterArray.Length
	return -join $scrambledStringArray
}

function Set-Localizations
{
	'CvsAppGrps', 'CvsLog', 'CvsSelectedGrps', 'CvsLog', 'CvsAppList' | `
		ForEach-Object {
			$syncHash.Controls.Window.Resources[$_].Source = [System.Collections.ObjectModel.ObservableCollection[Object]]::new()
		}

	$syncHash.Controls.IcLog.Resources['BrdClick'].Setters.Where( { $_.Event.Name -match "MouseDown" } )[0].Handler = $syncHash.Code.LogItemClickHandler
}

function Set-UserSettings
{
	<#
	.Synopsis
		Adjust settings to the operators groupmemberships
	#>

	try
	{
		$a = Get-ADPrincipalGroupMembership -Identity ( [Environment]::UserName )
		$syncHash.Data.Signature = "`n$( $syncHash.Data.msgTable.StrSigGen )"
		if ( $a.SamAccountName -match $syncHash.Data.msgTable.StrOpGrp )
		{
			$syncHash.LogFilePath = $syncHash.Data.msgTable.StrOpLogPath
			$syncHash.ErrorLogFilePath = "$( $syncHash.Data.msgTable.StrOpLogPath )\Errorlogs\$( [Environment]::UserName )-Errorlog.txt"
		}
		elseif ( ( Get-ADGroupMember $syncHash.Data.msgTable.StrBORoleGrp ).Name -contains ( Get-ADUser -Identity ( [Environment]::UserName ) ).Name )
		{
			$syncHash.Data.Signature += "`n`n$( $syncHash.Data.msgTable.StrSigSD )"
			$syncHash.Data.Signature += "`n$( $syncHash.Data.msgTable.StrSigSD2 )"
		}
		else
		{ throw }
	}
	catch
	{
		WriteErrorLog -LogText $_ -UserInput $syncHash.Data.msgTable.ErrMessageSetSettings -Severity "PermissionFail"
		Show-MessageBox -Text $syncHash.Data.msgTable.ErrScriptPermissions -Icon "Stop"
		Exit
	}
}

function Update-AppList
{
	<#
	.Synopsis
		Add names for applications with AD-Groups
	#>

	$apps = @()
	if ( $syncHash.Data.msgTable.StrBORoleGrp -in ( ( Get-ADUser -Identity ( [Environment]::UserName ) -Properties MemberOf ).MemberOf | Get-ADGroup | Select-Object -ExpandProperty Name ) )
	{
		$apps += [pscustomobject]@{ Text = "App 1"
			Tag = @{ AppFilter = "(|(Name=App_1*)(Name=App1*))"
				Exclude = $null
				GroupType = "App1-groups" } }
	}

	$apps += [pscustomobject]@{ Text = "App 2"
		Tag = @{ AppFilter = "(Name=App2*)"
			Exclude = @( "Null", "Closed" )
			GroupType = "App2-groups" }
			split = "_"
			index = 2 }

	$apps | `
		ForEach-Object {
			$syncHash.Controls.Window.Resources['CvsAppList'].Source.Add( $_ )
		}
}

function Update-AppGroupList
{
	<#
	.Synopsis
		Item in combobox has changed, get that applications groups and list them
	#>

	$syncHash.Controls.Window.Resources['CvsSelectedGrps'].Source.Clear()
	$syncHash.Controls.Window.Resources['CvsAppGrps'].Source.Clear()
	$syncHash.Controls.Window.Title = $syncHash.Data.msgTable.StrGetADGroups

	if ( $syncHash.Controls.CbApp.SelectedItem.Tag.GroupList.Count -eq 0 )
	{
		try
		{
			$syncHash.Controls.CbApp.SelectedItem.Tag.GroupList = Get-ADGroup -LDAPFilter "$( $syncHash.Controls.CbApp.SelectedItem.Tag.AppFilter )" -Properties Description | `
				Sort-Object Name | `
				Select-Object *
			if ( $null -ne $syncHash.Controls.CbApp.SelectedItem.Tag.Exclude )
			{
				$syncHash.Controls.CbApp.SelectedItem.Tag.GroupList = $syncHash.Controls.CbApp.SelectedItem.Tag.GroupList | `
					Where-Object { $syncHash.Controls.CbApp.SelectedItem.Tag.Exclude -notcontains $_.Name.Split( $syncHash.Controls.CbApp.SelectedItem.Tag.ExcludeSplitCharacter )[$syncHash.Controls.CbApp.SelectedItem.Tag.ExcludedWordIndex] } | `
					Sort-Object Name
			}
		}
		catch
		{
			$syncHash.Data.ErrorHashes += WriteErrorLog -LogText $_ -UserInput $syncHash.Data.msgTable.ErrMessageGetAppGroups -Severity "ConnectionFail"
		}
	}

	Update-AppGroupListItems
	$syncHash.Controls.Window.Title = $syncHash.Data.msgTable.ContentWindowTitle
}

function Update-AppGroupListItems
{
	<#
	.Synopsis
		Update the list of groups, excluding any selected group
	#>

	$syncHash.Controls.Window.Resources['CvsAppGrps'].Source.Clear()
	$syncHash.Controls.CbApp.SelectedItem.Tag.GroupList | `
		Where-Object { $syncHash.Controls.Window.Resources['CvsSelectedGrps'].Source -notcontains $_ } | `
		ForEach-Object {
			$syncHash.Controls.Window.Resources['CvsAppGrps'].Source.Add( $_ )
		}
}

function Undo-Input
{
	<#
	.Synopsis
		Deletes all userinput and resets lists
	#>

	$syncHash.Controls.TxtUsersAddPermission.Text = ""
	$syncHash.Controls.TxtUsersRemovePermission.Text = ""
	$syncHash.Controls.TbComputer.Text = ""
	Update-AppGroupList
}

function Write-ToLogFile
{
	<#
	.Synopsis
		Write finished operations to logfile
	#>

	$OFS = ", "

	$LogText = "$( $syncHash.Data.msgTable.StrLogMessage ): $( $syncHash.Controls.CbApp.Text )`n"
	if ( $syncHash.AddComputer.Count -gt 0 ) { $LogText += "$( $syncHash.Data.msgTable.LogMessageAddComputer ) $( $syncHash.AddComputer.Name )" }
	if ( $syncHash.AddUsers.Count -gt 0 ) { $LogText += "$( $syncHash.Data.msgTable.LogMessageAdd ) $( $syncHash.AddUsers.Id )" }
	if ( $syncHash.RemoveUsers.Count -gt 0 ) { $LogText += "$( $syncHash.Data.msgTable.LogMessageRemove ) $( $syncHash.RemoveUsers.Id )" }

	$UserInput = ""
	if ( $syncHash.Controls.TxtUsersAddPermission.Text.Length -gt 0 ) { $UserInput += "$( $syncHash.Data.msgTable.LogInputAdd ) $( $syncHash.Controls.TxtUsersAddPermission.Text -split "\W" )`n" }
	if ( $syncHash.Controls.TxtUsersRemovePermission.Text.Length -gt 0 ) { $UserInput += "$( $syncHash.Data.msgTable.LogInputRemove ) $( $syncHash.Controls.TxtUsersRemovePermission.Text -split "\W" )`n" }
	$UserInput += $syncHash.Controls.Window.Resources['CvsSelectedGrps'].Source

	WriteLog -Text $LogText -UserInput $UserInput -Success ( $syncHash.Data.ErrorHashes.Count -lt 1 ) -ErrorLogHash $syncHash.Data.ErrorHashes
}

######################### Script start #########################

$syncHash.Data.ErrorHashes = @()
$syncHash.ErrorLogFilePath = ""
$syncHash.HandledFolders = @()
$syncHash.LogFilePath = ""
[System.Windows.Input.MouseButtonEventHandler] $syncHash.Code.LogItemClickHandler = {
	param ( $SenderObject, $e )

	$SenderObject.DataContext.Message | clip
}
Reset-Variables
Set-UserSettings
Set-Localizations

$syncHash.Controls.BtnRefetchGroups.Add_Click( {
	if ( $null -eq $syncHash.Controls.CbApp.SelectedItem.Tag.Exclude )
	{
		$syncHash.Controls.CbApp.SelectedItem.Tag.GroupList = Get-ADGroup -LDAPFilter "$( $syncHash.Controls.CbApp.SelectedItem.Tag.AppFilter )" | Sort-Object Name
	}
	else
	{
		$syncHash.Controls.CbApp.SelectedItem.Tag.GroupList = Get-ADGroup -LDAPFilter "$( $syncHash.Controls.CbApp.SelectedItem.Tag.AppFilter )" | `
			Where-Object { $syncHash.Controls.CbApp.SelectedItem.Tag.Exclude -notcontains $_.Name.Split( $syncHash.Controls.CbApp.SelectedItem.Tag.ExcludeSplitCharacter )[$syncHash.Controls.CbApp.SelectedItem.Tag.ExcludedWordIndex] } | `
			Sort-Object Name
	}
} )

$syncHash.Controls.BtnPerform.Add_Click( {
	$DupList = ( ( ( $syncHash.Controls.TxtUsersAddPermission.Text -split "\W" ) + ( $syncHash.Controls.TxtUsersRemovePermission.Text -split "\W" ) ) | `
		Group-Object | `
		Where-Object { $_.Count -gt 1 } | `
		Select-Object -ExpandProperty Name ) -join ", "
	if ( $DupList.Length -gt 0 )
	{
		Show-MessageBox -Text "$( $syncHash.Data.msgTable.StrDuplicates ):`n$( $DupList )" -Title $syncHash.Data.msgTable.StrDuplicatesTitle -Icon "Stop"
	}
	else
	{
		Perform-Permissions
	}
} )

$syncHash.Controls.BtnUndo.Add_Click( { Undo-Input } )

$syncHash.Controls.CbApp.Add_SelectionChanged( {
	if ( $true -eq $this.SelectedItem.Tag.AddComputer )
	{
		$syncHash.Controls.TbComputer.Visibility = [System.Windows.Visibility]::Visible
	}
	else
	{
		$syncHash.Controls.TbComputer.Visibility = [System.Windows.Visibility]::Collapsed
	}
	$syncHash.Controls.LbAppGroupList.ScrollIntoView( $syncHash.Controls.LbAppGroupList[0] )
} )

$syncHash.Controls.LbAppGroupList.Add_MouseDoubleClick( { Group-Selected } )

$syncHash.Controls.LbGroupsChosen.Add_MouseDoubleClick( { Group-Deselected } )

$syncHash.Controls.TxtUsersAddPermission.Add_TextChanged( { Check-Ready } )

$syncHash.Controls.TxtUsersRemovePermission.Add_TextChanged( { Check-Ready } )

$syncHash.Controls.Window.Add_Loaded( {
	if ( $syncHash.Controls.Window.Resources['CvsAppList'].Source.Count -eq 0 )
	{
		$this.Title = $syncHash.Data.msgTable.StrPreparing
		Update-AppList
	}

	if ( $syncHash.Controls.Window.Resources['CvsAppList'].Source.Count -eq 1 )
	{
		Update-AppGroupList
	}

	$this.Title = $syncHash.Data.msgTable.ContentWindowTitle
	$syncHash.Controls.CbApp.Add_SelectionChanged( { if ( $null -ne $syncHash.Controls.CbApp.SelectedItem ) { Update-AppGroupList } } )
} )

Export-ModuleMember

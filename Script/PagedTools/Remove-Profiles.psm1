<#
.Synopsis Delete one or more profiles
.Description Delete one or more user profiles on the specified computer.
.MenuItem Delete one or more profiles
.AllowedUsers sys1, sys2
.Depends WinRM
.State Test
.ObjectOperations computer
.Author Smorkster
#>

Add-Type -AssemblyName PresentationFramework
$syncHash = $args[0]

function Connect
{
	<#
	.Synopsis
		Verify that the computer is reachable and checks if any users are logged in
	#>

	$syncHash.DC.LvProfileList[0].Clear()
	$syncHash.DC.LbOutput[0].Clear()

	if ( VerifyInput )
	{
		$li = [System.Windows.Controls.ListBoxItem]@{ Content = "" }
		$syncHash.DC.TbComputerName[0] = $false
		$syncHash.DC.PbProgress[1] = $true
		$li.Content = "$( $syncHash.Data.msgTable.StrCheckOnline ) $( $syncHash.Data.ComputerName )"
		$syncHash.DC.LbOutput[0].Add( $li )

		try
		{
			$n = ( Get-CimInstance -ComputerName $syncHash.Data.ComputerName -ClassName win32_computersystem ).UserName.Count
			$li.Content += "`n`t$( $syncHash.Data.msgTable.StrOnline )"
			$c = "`n`t$( $n ) $( $syncHash.Data.msgTable.StrUsersLoginSessions )"
			if ( $n -gt 0 )
			{
				$c += "`n`t$( $syncHash.Data.msgTable.StrUsersLoginSessionsLogOut )"
				$syncHash.DC.BtnLogOutAll[0] = $true
			}
			else
			{
				$syncHash.DC.BtnLogOutAll[0] = $false
				$syncHash.DC.BtnGetProfiles[0] = $true
			}
			$li.Content += $c
		}
		catch [Microsoft.Management.Infrastructure.CimException]
		{
			$li.Content += "`n`t$( $syncHash.Data.msgTable.StrOffline )"
			$li.Background = "#FFFF0000"
			$li.FontWeight = "Bold"
			$syncHash.DC.TbComputerName[0] = $true
		}
		catch
		{
			& $syncHash.WriteErrorLog "$( $_.Exception.Message )`n$( $_.InvocationInfo.PositionMessage )"
		}
		$syncHash.DC.PbProgress[1] = $false
	}
}

function Reset
{
	<#
	.Synopsis
		Reset controls
	#>

	$syncHash.DC.LvProfileList[0].Clear()
	$syncHash.DC.LvProfileList[1] = $false
	$syncHash.DC.LvProfileResetList[0].Clear()
	$syncHash.DC.LvProfileResetList[1] = $false
	$syncHash.DC.LbOutput[0].Clear()
	$syncHash.DC.BtnGetProfiles[0] = $false
	$syncHash.DC.BtnLogOutAll[0] = $false
	$syncHash.DC.BtnSelectAll[0] = $false
	$syncHash.DC.BtnRemoveSelected[1] = $false
	$syncHash.DC.TbComputerName[0] = $true
	$syncHash.TbComputerName.Focus()
}

function DeleteProfiles
{
	<#
	.Synopsis
		Backups and deletes selected profiles
	#>

	$syncHash.DC.LvProfileList[1] = $true

	$syncHash.DC.LbOutput[0].Add( [System.Windows.Controls.ListBoxItem]@{ Content = $syncHash.Data.msgTable.StrStartDeleting } )
	$syncHash.Data.DeletePool = [runspacefactory]::CreateRunspacePool( 1, 1 )
	$syncHash.Data.DeletePool.CleanupInterval = New-TimeSpan -Minutes 1
	$syncHash.Data.DeletePool.Open()
	$syncHash.Jobs.Clear()
	$syncHash.Data.OutTot = New-Object System.Collections.ArrayList
	$syncHash.logText = "$( $syncHash.Data.ComputerName ), $( $syncHash.Controls.LvProfileList.SelectedItems.Count ) $( $syncHash.Data.msgTable.StrProfiles )"
	$syncHash.Output = "$( $syncHash.Controls.LvProfileList.SelectedItems.Count ) $( $syncHash.Data.msgTable.StrDeleteSummary ) $( $syncHash.Data.ComputerName ):"
	foreach ( $user in ( $syncHash.Controls.LvProfileList.SelectedItems ) )
	{
		$li = [System.Windows.Controls.ListBoxItem]@{ Content = $user.Name }
		$ps = [powershell]::Create()
		$ps.RunspacePool = $syncHash.Data.DeletePool
		[void] $ps.AddScript( { param ( $syncHash, $li, $user )
			$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.DC.LbOutput[0].Add( $li ) } )
			# region FileBackup
			$syncHash.Window.Dispatcher.Invoke( [action] {
				$li.Content += "`n`t$( $syncHash.Data.msgTable.StrStartBackup ) ($( $user.P ))... "
			} )

			$out = Invoke-Command -ComputerName $syncHash.Data.ComputerName -ScriptBlock {
				param ( $id, $Name, $BackupFilePrefix )
				try
				{
					$ErrorActionPreference = "SilentlyContinue"

					try { New-Item -Path "C:\Users\Old" -Name $id -ItemType Directory -ErrorAction Stop | Out-Null } catch {}

					# Directories to backup
					try { Copy-Item -Path "C:\Users\$id\*" -Destination "C:\Users\Old\$id\" -Recurse } catch {}

					$a = "C:\Users\$id\AppData\Roaming\Microsoft\Office",
					"C:\Users\$id\AppData\Roaming\Microsoft\Signatures",
					"C:\Users\$id\AppData\Roaming\Microsoft\Sticky Notes",
					"C:\Users\$id\AppData\Local\Google\Chrome\User Data\Default",
					"C:\Users\$id\Favorites" | Foreach-Object {
						Get-ChildItem -Path "$_\*" -Recurse -Force | Where-Object { $_.FullName -notmatch "cache" } | Select-Object -ExpandProperty FullName
					} | ForEach-Object {
						Copy-Item -LiteralPath $_ -Destination ( $_ -replace "Users\\$id", "Users\Old\$id" ) -Force
					}

					# Specific files to backup
					"C:\Users\$id\AppData\Roaming\Microsoft\OneNote\16.0\Preferences.dat" | Foreach-Object {
						if ( Test-Path $_ )
						{
							$i = Get-Item -Path $_
							$d = $i.FullName -replace "Users\\$id", "Users\Old\$id"
							New-Item -Path ( $i.Directory.FullName -replace "Users\\$id", "Users\Old\$id" ) -ItemType Directory -Force | Out-Null
							try { Copy-Item $i.FullName -Destination $d -Force } catch {}
						}
					}

					# Create backupfile
					$zipDest = "C:\Users\Old\$BackupFilePrefix $Name, $( ( Get-Date ).ToShortDateString() ).zip"
					Compress-Archive -Path C:\Users\Old\$id -DestinationPath $zipDest -CompressionLevel Optimal
					Remove-Item C:\Users\Old\$id -Recurse -Force

					# Remove earlier backups
					Get-ChildItem -Path "C:\Users\Old" -Filter "$BackupFilePrefix*.zip" | Where-Object { $_.Name -match $id -and $_.LastWriteTime -lt ( Get-Date ).AddDays( -30 ) } | Remove-Item -Recurse

					[pscustomobject]@{ ZIP = $zipDest ; Org = "C:\Users\$id"; EV = $Error }
				} catch { $_ }
			} -ArgumentList $user.ID, $user.Name, $syncHash.Data.msgTable.StrBackupFileName
			[void] $syncHash.Data.OutTot.Add( $out )
			$syncHash.Window.Dispatcher.Invoke( [action] { $li.Content += $syncHash.Data.msgTable.StrDone } )
			# endregion FileBackup

			# region RemoveProfile
			$syncHash.Window.Dispatcher.Invoke( [action] { $li.Content += "`n`t$( $syncHash.Data.msgTable.StrRemoves ) ($( $user.ID ))... " } )
			Get-CimInstance -ComputerName $syncHash.Data.ComputerName -Class Win32_UserProfile | Where-Object { $_.LocalPath.Split( '\' )[-1] -eq $user.ID } | Remove-CimInstance
			$syncHash.Window.Dispatcher.Invoke( [action] { $li.Content += $syncHash.Data.msgTable.StrDone } )
			# endregion RemoveProfile

			$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.DC.LvProfileList[0].Remove( $user ) } )

			if ( $out.EV.Count -gt 0 )
			{
				$ErrorTest = ""
				$out.EV | Foreach-Object { $ErrorText += "$_.Exception.Message )`n`t$( $_.InvocationInfo.PositionMessage )`n`n" }
				& $syncHash.WriteErrorLog "$( $syncHash.Data.ComputerName )`n`n$( $ErrorText.Trim() )"
			}
			else { $syncHash.Output += "`n`n$( $user.Name )`n`t$( $syncHash.Data.msgTable.StrProfLoc ): $( $out.Org )`n`t$( $syncHash.Data.msgTable.StrBackupFileName ): $( $out.ZIP )" }

			$syncHash.DC.PbProgress[0] = [double] ( ( ( ( $syncHash.Jobs.H.IsCompleted -eq $true ).Count + 1 ) / $syncHash.Jobs.Count ) * 100 )
		} ).AddArgument( $syncHash ).AddArgument( $li ).AddArgument( $user )
		[void] $syncHash.Jobs.Add( [pscustomobject]@{ P = $ps ; H = $ps.BeginInvoke() } )
	}
}

function RestoreProfiles
{
	<#
	.Synopsis
		Restore one or more profiles from the "Old"-folder
	#>

	$syncHash.DC.LbOutput[0].Add( $syncHash.Data.msgTable.StrStartRestoring )
	$syncHash.Data.RestorePool = [runspacefactory]::CreateRunspacePool( 1, 5 )
	$syncHash.Data.RestorePool.CleanupInterval = New-TimeSpan -Minutes 1
	$syncHash.Data.RestorePool.Open()
	$syncHash.Jobs.Clear()
	$syncHash.logText = "$( $syncHash.Data.ComputerName ), $( $syncHash.Data.msgTable.StrRestoreSummary ) $( $syncHash.lvProfileResetList.SelectedItems.Count )`n"
	$syncHash.Output = ""

	foreach ( $backup in $syncHash.lvProfileResetList.SelectedItems.Name )
	{
		$ps = [powershell]::Create()
		$ps.RunspacePool = $syncHash.Data.RestorePool
		[void] $ps.AddScript( { param ( $syncHash, $backup, $maxCount )
			$id = $backup.Split( "(" ).Split( ")" )[1]
			$name, $date = $backup.TrimStart( "$( $syncHash.Data.msgTable.StrBackupFileName ) " ) -split ", "
			if ( Get-CimInstance -ComputerName $syncHash.Data.ComputerName -Query "SELECT * FROM win32_userprofile WHERE LocalPath = 'C:\\Users\\$id'" )
			{
				$out = Invoke-Command -ComputerName $syncHash.Data.ComputerName -ScriptBlock `
				{
					param ( $backup, $id, $StrErrNoProfFolder )

					try
					{
						$extracted = $false

						# Check for folders first
						if ( $extracted = Test-Path "C:\Users\$id" )
						{
							Expand-Archive -LiteralPath "C:\Users\Old\$( $backup )" -DestinationPath "C:\Users" -Force
						}
						else
						{
							$t = $StrErrNoProfFolder
						}
					}
					catch
					{
						$t = $_
					}

					[psobject]@{ E = $extracted ; T = $t }
				} -ArgumentList $backup, $id, $syncHash.Data.msgTable.StrErrNoProfFolder

				$li = "$( $name ) - "
				if ( $out.E )
				{
					$li += "$( $syncHash.Data.msgTable.StrRestored ) $( $date.TrimEnd( ".zip" ) )"
					$syncHash.Output += "`n`t$( $backup )"
				}
				else
				{
					if ( $null -eq $out.T.Exception.Message )
					{
						& $syncHash.WriteErrorLog "$( $syncHash.Data.ComputerName ) - $( $out.T )"
						$li += "$( $name ) $( $syncHash.Data.msgTable.StrErrRestoreLog )"
					}
					else
					{
						$li += "$( $name ) $( $syncHash.Data.msgTable.StrErrRestore )`n`t$( $out.T )"
						$syncHash.Output += "`n`t$( $backup ) - $( $out.T )"
					}
				}
				$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.DC.LbOutput[0].Add( $li ) } )
				$syncHash.DC.PbProgress[0] = [double] ( ( ( @( $syncHash.Jobs.H.IsCompleted -eq $true ).Count + 1 ) / $maxCount ) * 100 )
			}
			else
			{
				$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.DC.LbOutput[0].Add( "$name - $( $syncHash.Data.msgTable.StrErrNoProf )" ) } )
			}
		} ).AddArgument( $syncHash ).AddArgument( $backup ).AddArgument( $syncHash.lvProfileResetList.SelectedItems.Count )
		[void] $syncHash.Jobs.Add( [pscustomobject]@{ P = $ps ; H = $ps.BeginInvoke() } )
	}
}

function LogoffRemote
{
	<#
	.Synopsis
		Log off all users from remote computer
	#>

	$syncHash.DC.LbOutput[0].Add( [System.Windows.Controls.ListBoxItem]@{ Content = $syncHash.Data.msgTable.StrStartLogout } )

	$userlogins = quser /server:$( $syncHash.Data.ComputerName ) | Select-Object -Skip 1 | Foreach-Object { 
		[pscustomobject]@{
			UserID = ( Get-ADUser ( $_ -split " +" )[1] ).Name
			SessionID = $( if ( ( $_ -split " +" ).Count -eq 8 ) { ( $_ -split " +" )[3] } else { ( $_ -split " +" )[2] } )
		}
	}

	$syncHash.DC.LbOutput[0].Add( [System.Windows.Controls.ListBoxItem]@{ Content = $syncHash.Data.msgTable.StrInfoLogout } )
	SendToast -Message "$( $syncHash.Data.msgTable.StrMessageLogout )" -ComputerName $syncHash.Data.ComputerName
	Start-Sleep -Seconds 10
	$userlogins | Foreach-Object { logoff $_.SessionID /server:$( $syncHash.Data.ComputerName ) }

	$ofs = "`n`t"
	$syncHash.DC.LbOutput[0].Add( [System.Windows.Controls.ListBoxItem]@{ Content = "$( @( $userlogins ).Count ) $( $syncHash.Data.msgTable.StrLoggedOutUsers )`n`t$( [string]( $userlogins.UserID ) )" } )

	$syncHash.DC.BtnGetProfiles[0] = $true
}

function GetProfiles
{
	<#
	.Synopsis
		Fetch created profiles from remote computer
	#>

	$syncHash.DC.LvProfileList[0].Clear()
	$syncHash.DC.lvProfileResetList[0].Clear()
	$syncHash.DC.LbOutput[0].Add( [System.Windows.Controls.ListBoxItem]@{ Content = $syncHash.Data.msgTable.StrGettingProfiles } )
	$liProfiles = [System.Windows.Controls.ListBoxItem]@{ Content = $syncHash.Data.msgTable.StrGettingProfiles }
	$syncHash.DC.LbOutput[0].Add( $liProfiles )
	Get-CimInstance -ComputerName $( $syncHash.Data.ComputerName ) -ClassName Win32_UserProfile | Where-Object { ( -not $_.Special ) `
			-and ( $_.LocalPath -notmatch "default" ) `
			-and ( $_.LocalPath -notmatch $env:USERNAME ) `
			-and ( -not [string]::IsNullOrEmpty( $_.LocalPath ) ) } | Foreach-Object {
		[pscustomobject]@{
			P = $_.LocalPath
			ID = ( $_.LocalPath -split "\\" -replace "\.Domain", "" )[2].ToUpper()
			Name = ( Get-ADUser ( $_.LocalPath -split "\\" -replace "\.Domain", "" )[2] ).Name
			LastUsed = $_.LastUseTime.ToShortDateString()
		}
	} | Sort-Object Name | Foreach-Object { $syncHash.DC.LvProfileList[0].Add( $_ ) }
	if ( $syncHash.DC.LvProfileList[0].Count -gt 0 )
	{
		$syncHash.DC.BtnSelectAll[0] = $true
		$syncHash.DC.LvProfileList[1] = $true
		$liProfiles.Content = "$( $syncHash.Data.msgTable.StrNumProfiles ) $( $syncHash.DC.LvProfileList[0].Count )"
	}
	else
	{
		$liProfiles.Content = $syncHash.Data.msgTable.StrNoProfiles
		$syncHash.DC.LvProfileList[1] = $false
	}

	# Get list of backups
	try
	{
		$backups = Get-ChildItem \\$( $syncHash.Data.ComputerName )\C$\Users\Old -Filter "$( $syncHash.Data.msgTable.StrBackupFileName )*.zip" -ErrorAction Stop
	}
	catch {}
	if ( $null -eq $backups -or @( $backups ).Count -eq 0 )
	{
		$liProfiles.Content += "`n$( $syncHash.Data.msgTable.StrNoBackups )"
		$syncHash.DC.BtnRestoreSelected[0] = $false
	}
	else
	{
		$backups | Foreach-Object { $syncHash.DC.lvProfileResetList[0].Add( [pscustomobject]@{ Name = $_.Name } ) }
		$liProfiles.Content += "`n$( $syncHash.Data.msgTable.StrNumProfileBackups ) $( $backups.Count )"
		$syncHash.DC.BtnRestoreSelected[0] = $true
		$syncHash.DC.lvProfileResetList[1] = $true
	}

	$syncHash.DC.BtnRemoveSelected[0] = $false
}

function VerifyInput
{
	<#
	.Synopsis
		Check that the input is correct
	#>

	$c1 = $false
	if ( $syncHash.Data.ComputerName -match $syncHash.Data.msgTable.CodeComputerMatch )
	{
		try
		{
			$role = Get-ADComputer $syncHash.Data.ComputerName -Properties Memberof | Select-Object -ExpandProperty MemberOf | Where-Object { $_ -match "_Wrk_.+PC," }
			$role | Foreach-Object { if ( $_ -match $syncHash.Data.msgTable.CodeRoleMatch ) { $c1 = $true } }
			if ( -not $c1 )
			{
				$syncHash.DC.LbOutput[0].Add( ( [System.Windows.Controls.ListBoxItem]@{ Content = "$( $syncHash.Data.msgTable.StrWrongRole )`n`t$( $ofs = "`n`t"; $role | Foreach-Object { ( ( $_ -split "=" )[1] -split "," )[0] } )"; Background = "#FFFF0000" } ) )
			}
		}
		catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]
		{
			WriteErrorLog -LogText $_
			$syncHash.DC.LbOutput[0].Add( ( [System.Windows.Controls.ListBoxItem]@{ Content = $syncHash.Data.msgTable.StrNameNotInAd; Background = "#FFFF0000" } ) )
		}
		catch
		{
			WriteErrorLog -LogText $_
			$syncHash.DC.LbOutput[0].Add( ( [System.Windows.Controls.ListBoxItem]@{ Content = "$( $syncHash.Data.msgTable.StrErrAd )`n$_"; Background = "#FFFF0000" } ) )
		}
	}
	elseif ( $syncHash.Data.ComputerName -match $syncHash.Data.msgTable.CodeComputerMismatch )
	{
		$syncHash.DC.LbOutput[0].Add( ( [System.Windows.Controls.ListBoxItem]@{ Content = $syncHash.Data.msgTable.StrWrongOrg; Background = "#FFFF0000" } ) )
	}
	else
	{
		$syncHash.DC.LbOutput[0].Add( ( [System.Windows.Controls.ListBoxItem]@{ Content = $syncHash.Data.msgTable.StrWrongName; Background = "#FFFF0000" } ) )
	}

	return $c1
}

########################### Script start
$controls = New-Object Collections.ArrayList
[void]$controls.Add( @{ CName = "BtnConnect" ; Props = @( @{ PropName = "IsEnabled" ; PropVal = $false } ; @{ PropName = "Content"; PropVal = $syncHash.Data.msgTable.ContentBtnConnect } ) } )
[void]$controls.Add( @{ CName = "BtnGetProfiles" ; Props = @( @{ PropName = "IsEnabled" ; PropVal = $false } ; @{ PropName = "Content"; PropVal = $syncHash.Data.msgTable.ContentBtnGetProfiles } ) } )
[void]$controls.Add( @{ CName = "BtnLogOutAll" ; Props = @( @{ PropName = "IsEnabled"; PropVal = $false } ; @{ PropName = "Content"; PropVal = $syncHash.Data.msgTable.ContentBtnLogoutUsers } ) } )
[void]$controls.Add( @{ CName = "BtnRemoveSelected" ; Props = @( @{ PropName = "IsEnabled"; PropVal = $false } ; @{ PropName = "Visibility" ; PropVal = [System.Windows.Visibility]::Visible } ; @{ PropName = "Content"; PropVal = $syncHash.Data.msgTable.ContentBtnRemoveSelected } ) } )
[void]$controls.Add( @{ CName = "BtnReset" ; Props = @( @{ PropName = "IsEnabled" ; PropVal = $true } ; @{ PropName = "Content"; PropVal = $syncHash.Data.msgTable.ContentBtnReset } ) } )
[void]$controls.Add( @{ CName = "BtnRestoreSelected" ; Props = @( @{ PropName = "IsEnabled" ; PropVal = $false } ; @{ PropName = "Visibility" ; PropVal = [System.Windows.Visibility]::Collapsed } ; @{ PropName = "Content"; PropVal = $syncHash.Data.msgTable.ContentBtnRestoreSelected } ) } )
[void]$controls.Add( @{ CName = "BtnSelectAll" ; Props = @( @{ PropName = "IsEnabled"; PropVal = $false } ; @{ PropName = "Content"; PropVal = $syncHash.Data.msgTable.ContentbtnSelectAll } ) } )
[void]$controls.Add( @{ CName = "GwcID" ; Props = @( @{ PropName = "Content"; PropVal = $syncHash.Data.msgTable.ContentgwcID } ) } )
[void]$controls.Add( @{ CName = "GwcNameReset" ; Props = @( @{ PropName = "Content"; PropVal = $syncHash.Data.msgTable.ContentgwcNameReset } ) } )
[void]$controls.Add( @{ CName = "GwcLastUse" ; Props = @( @{ PropName = "Content"; PropVal = $syncHash.Data.msgTable.ContentgwcLastUse } ) } )
[void]$controls.Add( @{ CName = "GwcName" ; Props = @( @{ PropName = "Content"; PropVal = $syncHash.Data.msgTable.ContentgwcName } ) } )
[void]$controls.Add( @{ CName = "LblComputerName" ; Props = @( @{ PropName = "Content"; PropVal = $syncHash.Data.msgTable.ContentlblComputerName } ) } )
[void]$controls.Add( @{ CName = "LbOutput" ; Props = @( @{ PropName = "ItemsSource"; PropVal = [System.Collections.ObjectModel.ObservableCollection[Object]]::new( ) } ) } )
[void]$controls.Add( @{ CName = "LvProfileList" ; Props = @( @{ PropName = "ItemsSource"; PropVal = [System.Collections.ObjectModel.ObservableCollection[Object]]::new( ) } ; @{ PropName = "IsEnabled"; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "LvProfileResetList" ; Props = @( @{ PropName = "ItemsSource"; PropVal = [System.Collections.ObjectModel.ObservableCollection[Object]]::new( ) } ; @{ PropName = "IsEnabled"; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "PbProgress" ; Props = @( @{ PropName = "Value"; PropVal = [double] 0 } ; @{ PropName = "IsIndeterminate"; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "GridComputer" ; Props = @( @{ PropName = "IsEnabled"; PropVal = $true } ; @{ PropName = "Visibility"; PropVal = [System.Windows.Visibility]::Visible } ) } )
[void]$controls.Add( @{ CName = "TiProfiles" ; Props = @( @{ PropName = "Header"; PropVal = $syncHash.Data.msgTable.ContenttiProfiles } ) } )
[void]$controls.Add( @{ CName = "TiReset" ; Props = @( @{ PropName = "Header"; PropVal = $syncHash.Data.msgTable.ContenttiReset } ) } )
[void]$controls.Add( @{ CName = "TbComputerName" ; Props = @( @{ PropName = "IsEnabled"; PropVal = $true } ) } )

BindControls $syncHash $controls

$syncHash.Log = [System.Collections.ArrayList]::new()
$syncHash.WriteErrorLog = {
	$f = New-Item -Path "$( $syncHash.Root )\ErrorLogs\$( ( Get-Date ).Year )\$( ( Get-Date ).Month )" -Name "$( ( ( Split-Path $PSCommandPath -Leaf ) -split "\." )[0] ) - ErrorLog $( Get-Date -Format "yyyy-MM-dd HH.mm.ss" ).txt" -ItemType File -Force
	Add-Content -Value "$( Get-Date -f "yyyy-MM-dd HH:mm:ss" ) $( $env:USERNAME ) => $( $args[0] )" -Path $f.FullName }

$syncHash.Controls.BtnConnect.Add_Click( { Connect } )
$syncHash.Controls.BtnGetProfiles.Add_Click( { GetProfiles } )
$syncHash.Controls.BtnReset.Add_Click( { Reset } )
$syncHash.Controls.BtnSelectAll.Add_Click( {
	if ( $syncHash.DC.BtnSelectAll[1] -eq $syncHash.Data.msgTable.ContentBtnSelectAll )
	{
		$syncHash.Controls.LvProfileList.SelectAll()
		$syncHash.DC.BtnSelectAll[1] = $syncHash.Data.msgTable.ContentDeselectAll
	}
	else
	{
		$syncHash.Controls.LvProfileList.UnselectAll()
		$syncHash.DC.BtnSelectAll[1] = $syncHash.Data.msgTable.ContentBtnSelectAll
	}
} )
$syncHash.Controls.BtnRemoveSelected.Add_Click( { DeleteProfiles } )
$syncHash.Controls.BtnRestoreSelected.Add_Click( { RestoreProfiles } )
$syncHash.Controls.BtnLogOutAll.Add_Click( { LogoffRemote } )

$syncHash.Controls.LvProfileList.Add_SelectionChanged( {
	if ( $syncHash.Controls.LvProfileList.SelectedItems.Count -eq 0 ) { $syncHash.DC.BtnRemoveSelected[0] = $false }
	else { $syncHash.DC.BtnRemoveSelected[0] = $true }
} )
$syncHash.Controls.LvProfileResetList.Add_SelectionChanged( {
	if ( $syncHash.Controls.LvProfileResetList.SelectedItems.Count -eq 0 ) { $syncHash.DC.BtnRestoreSelected[0] = $false }
	else { $syncHash.DC.BtnRestoreSelected[0] = $true }
} )

###############################
# To check if work is completed
$syncHash.Controls.PbProgress.Add_ValueChanged( {
	if ( $this.Value -ge 100 )
	{
		if ( $syncHash.Controls.TiProfiles.IsSelected )
		{
			$outputfile = WriteOutput -Output $syncHash.Output
			TextToSpeech -Text $syncHash.Data.msgTable.StrDoneDeleting
			$syncHash.Data.DeletePool.Close()
			$syncHash.Data.DeletePool.Dispose()
		}
		else
		{
			$ofs = "`n`t"
			$syncHash.logText += [string]$syncHash.Controls.LvProfileResetList.SelectedItems.Name
			TextToSpeech -Text $syncHash.Data.msgTable.StrDoneRestoring
			$syncHash.Data.RestorePool.Close()
			$syncHash.Data.RestorePool.Dispose()
		}
		#Todo fixa texter
		WriteLogTest -Text $syncHash.logText -UserInput "." -Success <##> -ComputerName $syncHash.Data.ComputerName -ErrorLogHash | Out-Null
		$syncHash.DC.LvProfileList[1] = $true
		$syncHash.DC.LvProfileResetList[1] = $true

		$syncHash.DC.PbProgress[0] = [double] 0
	}
} )

$syncHash.Controls.TbComputerName.Add_TextChanged( { $syncHash.Data.ComputerName = $syncHash.Controls.TbComputerName.Text.Trim() } )

$syncHash.Controls.TbComputerName.Add_KeyDown( { if ( $args[1].Key -eq "Return" ) { Connect } } )

$syncHash.Controls.TiReset.Add_GotFocus( {
	$syncHash.DC.BtnRestoreSelected[1] = [System.Windows.Visibility]::Visible
	$syncHash.DC.BtnRestoreSelected[0] = $false
	$syncHash.DC.BtnRemoveSelected[0] = $true
} )

$syncHash.Controls.TiProfiles.Add_GotFocus( {
	$syncHash.DC.BtnRemoveSelected[1] = [System.Windows.Visibility]::Visible
	$syncHash.DC.BtnRemoveSelected[0] = $false
	$syncHash.DC.BtnRestoreSelected[1] = [System.Windows.Visibility]::Collapsed
} )

$syncHash.Controls.Window.Add_Loaded( {
	$syncHash.Controls.TbComputerName.Focus()
} )

$syncHash.Controls.TbComputerName.Text = $syncHash.Controls.Window.Resources['SearchedItem'].Name

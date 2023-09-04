<#
.Synopsis
	Show applications
.MenuItem
	Show applications
.Description
	Show and uninstall applications on computer
.Depends
	WinRM
.State
	Prod
.ObjectOperations
	computer
.Author
	Smorkster (smorkster)
#>

Add-Type -AssemblyName PresentationFramework
$syncHash = $args[0]

function Reset
{
	<#
	.Synopsis Resets controls
	#>

	$syncHash.Controls.Window.Resources['CvsAppsLocal'].Source.Clear()
	$syncHash.Controls.Window.Resources['CvsAppsSysMan'].Source.Clear()
	$syncHash.Controls.Window.Resources['CvsAppsWrappers'].Source.Clear()
	$syncHash.DC.TbProgressInfo[0] = ""
	$syncHash.DC.TbProgressInfo[1] = "Black"
	$syncHash.DC.TbProgressInfo[1] = [System.Windows.Visibility]::Hidden
}

function SetLocalizations
{
	$syncHash.Controls.Window.Resources['CvsAppsCore'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	$syncHash.Controls.Window.Resources['CvsAppsLocal'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	$syncHash.Controls.Window.Resources['CvsAppsSysMan'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	$syncHash.Controls.Window.Resources['CvsAppsWrappers'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()

	"DgAppListSysMan","DgAppListLocal","DgAppListCore","DgAppListWrappers" | `
		ForEach-Object {
			[System.Windows.Data.BindingOperations]::EnableCollectionSynchronization( $syncHash."$( $_ )".ItemsSource, $syncHash."$( $_ )" )
		}

	$syncHash.Controls.DgAppListLocal.Columns[0].Header = $syncHash.Data.msgTable.ContentDgLocalInstCol
	$syncHash.Controls.DgAppListLocal.Columns[1].Header = $syncHash.Data.msgTable.ContentDgLocalNameCol
	$syncHash.Controls.DgAppListLocal.Columns[2].Header = $syncHash.Data.msgTable.ContentDgLocalUserCol

	$syncHash.Controls.DgAppListWrappers.Columns[0].Header = $syncHash.Data.msgTable.ContentDgWrappersAppNameCol
	$syncHash.Controls.DgAppListWrappers.Columns[1].Header = $syncHash.Data.msgTable.ContentDgWrappersInstallDateCol
	$syncHash.Controls.DgAppListWrappers.Columns[2].Header = $syncHash.Data.msgTable.ContentDgWrappersProdVerCol

	$syncHash.Controls.DgAppListSysMan.Columns[0].Header = $syncHash.Data.msgTable.ContentDgSysManNameCol
	$syncHash.Controls.DgAppListSysMan.Columns[1].Header = $syncHash.Data.msgTable.ContentDgSysManDescCol

	$syncHash.Controls.DgAppListCore.Columns[0].Header = $syncHash.Data.msgTable.ContentDgAppListCoreNameCol
}

################### Start script
$controls = [System.Collections.ArrayList]::new()
[void]$controls.Add( @{ CName = "BtnUninstall" ; Props = @( @{ PropName = "IsEnabled"; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "PbProgressLocal" ; Props = @( @{ PropName = "IsIndeterminate"; PropVal = $true } ; @{ PropName = "Value"; PropVal = [double] 0 } ; @{ PropName = "Visibility" ; PropVal = [System.Windows.Visibility]::Hidden } ) } )
[void]$controls.Add( @{ CName = "PbProgressSysMan" ; Props = @( @{ PropName = "IsIndeterminate"; PropVal = $true } ; @{ PropName = "Value"; PropVal = [double] 0 } ; @{ PropName = "Visibility" ; PropVal = [System.Windows.Visibility]::Hidden } ) } )
[void]$controls.Add( @{ CName = "TblAppListCoreDeploymentName" ; Props = @( @{ PropName = "Text"; PropVal = "" } ; @{ PropName = "Foreground" ; PropVal = "Black" } ) } )
[void]$controls.Add( @{ CName = "TbProgressInfo" ; Props = @( @{ PropName = "Text"; PropVal = "" } ; @{ PropName = "Foreground" ; PropVal = "Black" } ) } )

BindControls $syncHash $controls
SetLocalizations
$syncHash.Code.GetApps = {
	$Apps = @{}
	$Apps.InstalledApplications = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	$Apps.Wrappers = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	$Apps.SysMan = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	$Apps.CoreApplications = [System.Collections.ObjectModel.ObservableCollection[object]]::new()

	$32BitPath = "SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
	$64BitPath = "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"

	Get-ItemProperty -Path "HKLM:\$32BitPath" | `
		ForEach-Object {
			$App = $_
			Add-Member -InputObject $App -MemberType Noteproperty -Name "Source" -Value "Global32"
			$Apps.InstalledApplications.Add( $_ ) | Out-Null
		}
	Get-ItemProperty -Path "HKLM:\$64BitPath" | `
		ForEach-Object {
			$App = $_
			Add-Member -InputObject $App -MemberType Noteproperty -Name "Source" -Value "Global64"
			$Apps.InstalledApplications.Add( $App ) | Out-Null
		}

	Get-ItemProperty "Registry::\HKEY_CURRENT_USER\$32BitPath" | `
		ForEach-Object {
			$App = $_
			Add-Member -InputObject $App -MemberType Noteproperty -Name "Source" -Value "CurrentUser32"
			$Apps.InstalledApplications.Add( $App ) | Out-Null
		}
	Get-ItemProperty "Registry::\HKEY_CURRENT_USER\$64BitPath" | `
		ForEach-Object {
			$App = $_
			Add-Member -InputObject $App -MemberType Noteproperty -Name "Source" -Value "CurrentUser64"
			$Apps.InstalledApplications.Add( $App ) | Out-Null
		}

	$AllProfiles = Get-CimInstance Win32_UserProfile | Select-Object LocalPath, SID, Loaded, Special | Where-Object { $_.SID -like "S-1-5-21-*" }
	$MountedProfiles = $AllProfiles | Where-Object { $_.Loaded -eq $true }
	$UnmountedProfiles = $AllProfiles | Where-Object { $_.Loaded -eq $false }

	$MountedProfiles | `
		ForEach-Object {
			$U = $_
			Get-ItemProperty -Path "Registry::\HKEY_USERS\$( $_.SID )\$32BitPath" | `
				ForEach-Object {
					$App = $_
					Add-Member -InputObject $App -MemberType Noteproperty -Name "Source" -Value "User32"
					Add-Member -InputObject $App -MemberType Noteproperty -Name "User" -Value ( ( $U.LocalPath -split "\\" )[-1] )
					$Apps.InstalledApplications.Add( $App ) | Out-Null
				}
			Get-ItemProperty -Path "Registry::\HKEY_USERS\$( $_.SID )\$64BitPath" | `
				ForEach-Object {
					$App = $_
					Add-Member -InputObject $App -MemberType Noteproperty -Name "Source" -Value "User64"
					Add-Member -InputObject $App -MemberType Noteproperty -Name "User" -Value ( ( $U.LocalPath -split "\\" )[-1] )
					$Apps.InstalledApplications.Add( $App ) | Out-Null
				}
		}

	$UnmountedProfiles | `
		ForEach-Object {
			$U = $_
			$Hive = "$( $_.LocalPath )\NTUSER.DAT"

			if ( Test-Path $Hive )
			{
				REG LOAD HKU\temp $Hive

				Get-ItemProperty -Path "Registry::\HKEY_USERS\temp\$32BitPath" | `
					ForEach-Object {
						$App = $_
						Add-Member -InputObject $App -MemberType Noteproperty -Name "Source" -Value "User32"
						Add-Member -InputObject $App -MemberType Noteproperty -Name "User" -Value ( ( $U.LocalPath -split "\\" )[-1] )
						$Apps.InstalledApplications.Add( $App ) | Out-Null
					}
				Get-ItemProperty -Path "Registry::\HKEY_USERS\temp\$64BitPath" | `
					ForEach-Object {
						$App = $_
						Add-Member -InputObject $App -MemberType Noteproperty -Name "Source" -Value "User64"
						Add-Member -InputObject $App -MemberType Noteproperty -Name "User" -Value ( ( $U.LocalPath -split "\\" )[-1] )
						$Apps.InstalledApplications.Add( $App ) | Out-Null
					}

				# Run manual GC to allow hive to be unmounted
				[GC]::Collect()
				[GC]::WaitForPendingFinalizers() | Out-Null
			
				REG UNLOAD HKU\temp | Out-Null
			} else {
				"$( $syncHash.Data.msgTable.ErrHiveNotAccessible ): $Hive"
			}
		}

	Get-ChildItem -Path 'HKLM:\SOFTWARE\eKlient\Wrapper\' | `
		ForEach-Object {
			Get-ItemProperty -Path "HKLM:$( $_.ToString() )"
		} | `
		Sort-Object Appname | `
		ForEach-Object {
			$Apps.Wrappers.Add( $_ ) | Out-Null
		}

	return $Apps
}

$syncHash.Data.UninstallLog = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
$syncHash.Data.UninstallLog.Add_CollectionChanged( {
	if ( $this[-1].ErrorText.Length -gt 0 )
	{
		$eh = WriteErrorlogTest -LogText $this[-1].ErrorText -Severity "OtherFail" -ComputerName $syncHash.Controls.TbComputerName.Text
	}
	$OFS = ", "
	WriteLogTest -Text "$( $this[-1].SuccessText )" -UserInput $syncHash.Controls.TbComputerName.Text -Success ( $this[-1].SuccessText.Length -gt 0 ) -ErrorLogHash $eh | Out-Null
} )

# Get list of applications
$syncHash.Controls.BtnGetAppList.Add_Click( {
	try
	{
		Reset
		$syncHash.Data.Computer = Get-ADComputer $syncHash.Controls.TbComputerName.Text -Properties MemberOf -ErrorAction Stop
		$PCRole = $syncHash.Data.Computer.MemberOf | Where-Object { $_ -match ".*_Wrk_.*PC,.*" } | Get-ADGroup -Properties * | Select-Object -ExpandProperty CN

		"Uninstall","FetchLocal","FetchSysMan" | `
			ForEach-Object {
				try
				{
					$syncHash.Jobs."P$( $_ )".EndInvoke( $syncHash.Jobs."H$( $_ )" ) | Out-Null
					$syncHash.Jobs."P$( $_ )".Dispose()
				} catch {}
			}

		$syncHash.DC.TbProgressInfo[0] = $syncHash.Data.msgTable.StrGetApps
		$syncHash.DC.PbProgressLocal[2] = [System.Windows.Visibility]::Visible
		$syncHash.DC.PbProgressLocal[0] = $true
		$syncHash.Jobs.PFetchLocal = [powershell]::Create().AddScript( {
			param ( $syncHash, $Modules, $Name, $PCRole )

			Import-Module $Modules
			$MemberOf = ( Get-ADComputer $Name -Properties MemberOf ).MemberOf

			try
			{
				$Apps = Invoke-Command -ComputerName $Name -ScriptBlock $syncHash.Code.GetApps -ErrorAction Stop | `
					Where-Object { $_ -isnot [string] }

				$Apps.InstalledApplications = $Apps.InstalledApplications |`
					Select-Object -Property @{ Name = "Name" ; Expression = { if ( $null -eq $_.DisplayName ) { $_.ParentDisplayName } else { $_.DisplayName } } }, `
								@{ Name = "Installed" ; Expression = { try { ( [datetime]::ParseExact( $_.InstallDate, "yyyyMMdd", $null ) ).ToShortDateString() } catch { 0 } } }, `
								@{ Name = "ID" ; Expression = { $_.IdentifyingNumber } }, `
								@{ Name = "RegItem" ; Expression = { $_ } }, `
								@{ Name = "User" ; Expression = { if ( $null -ne $_.User ) { ( Get-ADUser -Identity $_.User ).Name } else { $syncHash.Data.msgTable.StrAllUsers } } } | `
					Sort-Object User, Name
				$syncHash.Controls.Window.Dispatcher.Invoke( [action] {
					$syncHash.Controls.Window.Resources['CvsAppsLocal'].Source = $Apps.InstalledApplications
					$syncHash.Controls.Window.Resources['CvsAppsWrappers'].Source = $Apps.Wrappers
				} )
				$syncHash.DC.TbProgressInfo[0] = ""
			}
			catch [System.Management.Automation.Remoting.PSRemotingTransportException]
			{
				$syncHash.Errors.Add( $_ ) | Out-Null
				$syncHash.DC.TbProgressInfo[0] = $syncHash.Data.msgTable.ErrComputerNotReachable
				$syncHash.DC.TbProgressInfo[1] = "Red"
			}
			catch
			{
				$syncHash.Errors.Add( $_ ) | Out-Null
				$syncHash.DC.TbProgressInfo[0] = $_
				$syncHash.DC.TbProgressInfo[1] = "Red"
			}
			$syncHash.DC.PbProgressLocal[0] = $false
			$syncHash.DC.PbProgressLocal[2] = [System.Windows.Visibility]::Hidden
		} )
		$syncHash.Jobs.PFetchLocal.AddArgument( $syncHash )
		$syncHash.Jobs.PFetchLocal.AddArgument( ( Get-Module ) )
		$syncHash.Jobs.PFetchLocal.AddArgument( $syncHash.Data.Computer.Name )
		$syncHash.Jobs.PFetchLocal.AddArgument( $PCRole )
		$syncHash.Jobs.HFetchLocal = $syncHash.Jobs.PFetchLocal.BeginInvoke()

		$syncHash.Jobs.PFetchSysMan = [powershell]::Create().AddScript( {
			param ( $syncHash, $Modules, $Name, $PCRole )

			Import-Module $Modules
			$SysManList = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
			$CoreApplicationsList = [System.Collections.ObjectModel.ObservableCollection[object]]::new()


			try
			{
				Invoke-RestMethod -Uri "$( $syncHash.Data.msgTable.CodeSysManUri )api/Client/?name=$( $Name )" -Method Get -UseDefaultCredentials -ContentType "application/json" | `
					ForEach-Object {
						Invoke-RestMethod -Uri "$( $syncHash.Data.msgTable.CodeSysManUri )api/application/GetInstalledSystems?targetId=$( $_.id )" -Method Get -UseDefaultCredentials -ContentType "application/json"
					} | `
					Select-Object -ExpandProperty result | `
					ForEach-Object {
						$SysManList.Add( $_ ) | Out-Null
					}

				$syncHash.DC.TblAppListCoreDeploymentName[0] = " $PCRole"

				if ( $PCRole -match "Org0.*" )
				{
					$PCRoleSysManId = ( Invoke-RestMethod -Uri "$( $syncHash.Data.msgTable.CodeSysManUri )api/Application?name=$( $PCRole )" -Method Get -UseDefaultCredentials -ContentType "application/json" ).id
					$PCRoleSysManSystemId = ( Invoke-RestMethod -Uri "$( $syncHash.Data.msgTable.CodeSysManUri )api/application/Mapping?applicationId=$( $PCRoleSysManId )" -Method Get -UseDefaultCredentials -ContentType "application/json" ).result.id
					( Invoke-RestMethod -Uri "$( $syncHash.Data.msgTable.CodeSysManUri )api/reporting/System?systemId=$( $PCRoleSysManSystemId )" -Method Get -UseDefaultCredentials -ContentType "application/json" ).mappedApplications | `
						Sort-Object Name | `
						ForEach-Object {
							$CoreApplicationsList.Add( $_ ) | Out-Null
						}
				}

				$syncHash.Controls.Window.Dispatcher.Invoke( [action] {
					$syncHash.Controls.Window.Resources['CvsAppsSysMan'].Source = $SysManList
					$syncHash.Controls.Window.Resources['CvsAppsCore'].Source = $CoreApplicationsList
				} )
				$syncHash.DC.TbProgressInfo[0] = ""
			}
			catch [System.Management.Automation.Remoting.PSRemotingTransportException]
			{
				$syncHash.Errors.Add( $_ ) | Out-Null
				$syncHash.DC.TbProgressInfo[0] = $syncHash.Data.msgTable.ErrComputerNotReachable
				$syncHash.DC.TbProgressInfo[1] = "Red"
			}
			catch
			{
				$syncHash.Errors.Add( $_ ) | Out-Null
				$syncHash.DC.TbProgressInfo[0] = $_
				$syncHash.DC.TbProgressInfo[1] = "Red"
			}
			$syncHash.DC.PbProgressSysMan[0] = $false
			$syncHash.DC.PbProgressSysMan[2] = [System.Windows.Visibility]::Hidden
		} )
		$syncHash.Jobs.PFetchSysMan.AddArgument( $syncHash )
		$syncHash.Jobs.PFetchSysMan.AddArgument( ( Get-Module ) )
		$syncHash.Jobs.PFetchSysMan.AddArgument( $syncHash.Data.Computer.Name )
		$syncHash.Jobs.PFetchSysMan.AddArgument( $PCRole )
		$syncHash.Jobs.HFetchSysMan = $syncHash.Jobs.PFetchSysMan.BeginInvoke()
	}
	catch
	{
		$syncHash.DC.TbProgressInfo[1] = "Red"
		$syncHash.DC.TbProgressInfo[0] = $syncHash.Data.msgTable.ErrComputerNotFound
	}
} )

# Uninstall the selected application
$syncHash.Controls.BtnUninstall.Add_Click( {
	$syncHash.DC.TbProgressInfo[0] = ""
	$syncHash.DC.TbProgressInfo[1] = "Black"

	try
	{
		$syncHash.Jobs.PUninstall.EndInvoke( $syncHash.Jobs.HUninstall ) | Out-Null
		$syncHash.Jobs.PUninstall.Dispose()
	} catch {}

	if ( $syncHash.Controls.DgAppListLocal.SelectedItems.Count -gt 10 )
	{
		$summary = "$( $syncHash.Controls.DgAppListLocal.SelectedItems.Count ) $( $syncHash.Data.msgTable.StrAppSum )"
	}
	else
	{
		$summary = "`n`n$( $ofs = "`n"; [string] $syncHash.Controls.DgAppListLocal.SelectedItems.Name )"
	}

	if ( [System.Windows.MessageBox]::Show( "$( $syncHash.Data.msgTable.QUninstall ) $summary", "", [System.Windows.MessageBoxButton]::YesNo ) -eq "Yes" )
	{
		$syncHash.Jobs.PUninstall = [powershell]::Create()
		$syncHash.Jobs.PUninstall.AddScript( {
			param ( $syncHash, $list )

			$syncHash.Window.Dispatcher.Invoke( [action] {
				[System.Windows.Controls.Grid]::SetColumnSpan( $syncHash.Controls.PbProgressLocal , 2 )
			} )
			$syncHash.DC.PbProgressSysMan[2] = [System.Windows.Visibility]::Collapsed
			$syncHash.DC.PbProgressLocal[2] = [System.Windows.Visibility]::Visible
			$syncHash.DC.PbProgressLocal[0] = $false
			$Errors = [System.Collections.ArrayList]::new()
			$Success = [System.Collections.ArrayList]::new()
			for ( $c = 0; $c -lt $list.Count; $c++ )
			{
				$syncHash.DC.TbProgressInfo[0] = "$( $syncHash.Data.msgTable.StrUninstalling ) $( $list[$c].Name )"
				try
				{
					Get-CimInstance -ComputerName $syncHash.Data.ComputerName -Query "SELECT * FROM win32_product WHERE IdentifyingNumber LIKE '$( $list[$c].ID )'" | Remove-CimInstance
					[void] $Success.Add( $list[$c].Name )
				}
				catch
				{
					[void] $Errors.Add( ( [pscustomobject]@{ App = $list[$c].Name ; Err = $_ } ) )
				}
				$syncHash.DC.PbProgressLocal[1] = [double] ( ( $c / @( $list ).Count ) * 100 )
			}

			$ErrText = $Errors | ForEach-Object { "$( $_.App ) $( $_.Err )" }
			$SuccessText = $Success | Sort-Object | ForEach-Object { "$_" }
			[void] $syncHash.Data.UninstallLog.Add( ( [pscustomobject]@{ ErrorText = $ErrText ; SuccessText = $SuccessText } ) )

			$syncHash.Window.Dispatcher.Invoke( [action] {
				$syncHash.Controls.BtnGetAppList.RaiseEvent( [System.Windows.RoutedEventArgs]::new( [System.Windows.Controls.Button]::ClickEvent ) )
			} )

			$syncHash.DC.TbProgressInfo[0] = $syncHash.Data.msgTable.StrDone
			$syncHash.DC.PbProgressLocal[0] = $true
			$syncHash.DC.PbProgressLocal[1] = 0.0
			$syncHash.DC.PbProgressLocal[2] = [System.Windows.Visibility]::Hidden
			$syncHash.DC.PbProgressSysMan[2] = [System.Windows.Visibility]::Hidden
			$syncHash.Window.Dispatcher.Invoke( [action] {
				[System.Windows.Controls.Grid]::SetColumnSpan( $syncHash.Controls.PbProgressLocal , 1 )
			} )
		} )
		$syncHash.Jobs.PUninstall.AddArgument( $syncHash )
		$syncHash.Jobs.PUninstall.AddArgument( @( $syncHash.Controls.DgAppListLocal.SelectedItems | Where-Object { $_ } ) )
		$syncHash.Jobs.HUninstall = $syncHash.Jobs.PUninstall.BeginInvoke()
	}
} )

# If any item is selected, enable button to uninstall
$syncHash.Controls.DgAppListLocal.Add_SelectionChanged( {
	$syncHash.DC.BtnUninstall[0] = ( $syncHash.Controls.DgAppListLocal.SelectedItems.Count -gt 0 )
} )

# When the GUI is visible, check if computername should be entered to the textbox or if applist is to be fetched
$syncHash.Controls.Window.Add_IsVisibleChanged( {
	if ( $this.IsVisible )
	{
		if ( "" -eq $syncHash.Controls.TbComputerName.Text )
		{
			if ( $null -ne $syncHash.Controls.Window.Resources['SearchedItem'] )
			{
				Reset
				$syncHash.Controls.TbComputerName.Text = $syncHash.Controls.Window.Resources['SearchedItem'].Name
			}
		}
		elseif ( $syncHash.Controls.TbComputerName.Text -ne $syncHash.Controls.Window.Resources['SearchedItem'].Name )
		{
			if ( [System.Windows.MessageBox]::Show( "$( $syncHash.Data.msgTable.StrSwitchComputer )`n$( $syncHash.Data.msgTable.StrSwitchComputer2 ) $( $syncHash.Controls.Window.Resources['SearchedItem'].Name )", "", [System.Windows.MessageBoxButton]::YesNo ) -eq "Yes" )
			{
				$syncHash.Controls.TbComputerName.Text = $syncHash.Controls.Window.Resources['SearchedItem'].Name
			}
		}

		if ( $syncHash.Controls.Window.Resources['CvsApps'].Source.Count -eq 0 )
		{
			$syncHash.Controls.BtnGetAppList.RaiseEvent( ( [System.Windows.RoutedEventArgs]::new( [System.Windows.Controls.Button]::ClickEvent ) ) )
		}
	}
} )

# When GUI is first loaded, is there a name to enter to the textbox
$syncHash.Controls.Window.Add_Loaded( {
	try { $syncHash.Controls.TbComputerName.Text = $syncHash.Controls.Window.Resources['SearchedItem'].Name }
	catch {}
} )

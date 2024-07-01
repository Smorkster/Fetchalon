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

	"CvsAppsCore","CvsAppsLocal","CvsAppsSysMan","CvsAppsWrappers" | `
		ForEach-Object {
			$MaxRot = 10
			$Cvs = $_
			do
			{
				$Refreshed = $false
				try
				{
					if ( $null -ne $syncHash.Controls.Window.Resources["$( $Cvs )"].Source )
					{
						$syncHash.Controls.Window.Resources["$( $Cvs )"].Source.Clear()
						$syncHash.Controls.Window.Resources["$( $Cvs )"].View.Refresh()
					}
					$Refreshed = $true
					$MaxRot = 0
				}
				catch
				{
					$MaxRot --
				}
				Start-Sleep -Milliseconds 100
			}
			while ( -not $Refreshed -and $MaxRot -gt 0 )
		}
	$syncHash.DC.BtnGetAppList[0] = $true
	$syncHash.Controls.Window.Resources.CvsLogMessages.Source.Clear()
	$syncHash.Controls.Window.Resources.CvsLogMessages.View.Refresh()
}

function SetLocalizations
{
	$syncHash.Controls.Window.Resources['CvsAppsCore'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	$syncHash.Controls.Window.Resources['CvsAppsLocal'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	$syncHash.Controls.Window.Resources['CvsAppsSysMan'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	$syncHash.Controls.Window.Resources['CvsAppsWrappers'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	$syncHash.Controls.Window.Resources['CvsLogMessages'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()

	"DgAppListLocal","DgAppListWrappers","DgAppListSysMan","DgAppListCore","IcInfo" | `
		ForEach-Object {
			[System.Windows.Data.BindingOperations]::EnableCollectionSynchronization( $syncHash.Controls."$( $_ )".ItemsSource, $syncHash.Controls."$( $_ )" )
		}

	$syncHash.Controls.DgAppListLocal.Columns[0].Header = $syncHash.Data.msgTable.ContentDgLocalNameCol
	$syncHash.Controls.DgAppListLocal.Columns[1].Header = $syncHash.Data.msgTable.ContentDgLocalInstCol
	$syncHash.Controls.DgAppListLocal.Columns[2].Header = $syncHash.Data.msgTable.ContentDgLocalUserCol

	$syncHash.Controls.DgAppListWrappers.Columns[0].Header = $syncHash.Data.msgTable.ContentDgWrappersAppNameCol
	$syncHash.Controls.DgAppListWrappers.Columns[1].Header = $syncHash.Data.msgTable.ContentDgWrappersInstallDateCol
	$syncHash.Controls.DgAppListWrappers.Columns[2].Header = $syncHash.Data.msgTable.ContentDgWrappersProdVerCol

	$syncHash.Controls.DgAppListSysMan.Columns[0].Header = $syncHash.Data.msgTable.ContentDgSysManNameCol
	$syncHash.Controls.DgAppListSysMan.Columns[1].Header = $syncHash.Data.msgTable.ContentDgSysManDescCol

	$syncHash.Controls.DgAppListCore.Columns[0].Header = $syncHash.Data.msgTable.ContentDgAppListCoreNameCol

	$syncHash.Data.LocalApps = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
}

function Write-OpLog
{
	<#
	.Synopsis
		Write to op log in window
	#>

	param (
		[string] $Message,
		[string] $LogMessageType = "Info"
	)

	$syncHash.Controls.Window.Resources.CvsLogMessages.Source.Insert( 0, ( [pscustomobject]@{
		LogTime = ( Get-Date )
		LogMessage = $Message
		LogType = $LogMessageType
	} ) )
	$syncHash.Controls.Window.Resources.CvsLogMessages.View.Refresh()
}

################### Start script
$controls = [System.Collections.ArrayList]::new()
[void]$controls.Add( @{ CName = "BtnGetAppList" ; Props = @( @{ PropName = "IsEnabled"; PropVal = $true } ) } )
[void]$controls.Add( @{ CName = "BtnReset" ; Props = @( @{ PropName = "IsEnabled"; PropVal = $true } ) } )
[void]$controls.Add( @{ CName = "BtnUninstall" ; Props = @( @{ PropName = "IsEnabled"; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "PbProgressLocal" ; Props = @( @{ PropName = "IsIndeterminate"; PropVal = $true } ; @{ PropName = "Value"; PropVal = [double] 0 } ; @{ PropName = "Visibility" ; PropVal = [System.Windows.Visibility]::Hidden } ) } )
[void]$controls.Add( @{ CName = "PbProgressSysMan" ; Props = @( @{ PropName = "IsIndeterminate"; PropVal = $true } ; @{ PropName = "Value"; PropVal = [double] 0 } ; @{ PropName = "Visibility" ; PropVal = [System.Windows.Visibility]::Hidden } ) } )
[void]$controls.Add( @{ CName = "TblAppListCoreDeploymentName" ; Props = @( @{ PropName = "Text"; PropVal = "" } ; @{ PropName = "Foreground" ; PropVal = "Black" } ) } )

BindControls $syncHash $controls
SetLocalizations
$syncHash.Code.GetWrappers = {
	$Wrappers = [System.Collections.ObjectModel.ObservableCollection[object]]::new()

	Get-ChildItem -Path $args[0] | `
		ForEach-Object {
			Get-ItemProperty -Path "HKLM:$( $_.Name.ToString() )"
		} | `
		Sort-Object Appname | `
		ForEach-Object {
			$Wrappers.Add( $_ ) | Out-Null
		}

	return $Wrappers
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
		$this.IsEnabled = $syncHash.DC.BtnUninstall[0] = $syncHash.DC.BtnReset[0] = $false
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

		Write-OpLog -Message $syncHash.Data.msgTable.StrGetApps
		$syncHash.DC.PbProgressLocal[2] = [System.Windows.Visibility]::Visible
		$syncHash.DC.PbProgressLocal[0] = $true
		$syncHash.Jobs.PFetchLocal = [powershell]::Create().AddScript( {
			param ( $syncHash, $Modules, $Name, $PCRole )

			function Get-InstalledApplication
			{
				[CmdletBinding()]
				param (
					[string] $ComputerName
				)

				Begin {
					function IsCpuX86
					{
						param (
							[Microsoft.Win32.RegistryKey] $hklmHive
						)
						$regPath = 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment'
						$key = $hklmHive.OpenSubKey( $regPath )

						$cpuArch = $key.GetValue( 'PROCESSOR_ARCHITECTURE' )

						if ( $cpuArch -eq 'x86' )
						{
							return $true
						}
						else
						{
							return $false
						}
					}
					$AppCollection = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
				}
				Process {
					$regPath = @(
						'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
						'SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
					)

					# If CPU is x86, do not query for Wow6432Node
					if ( $IsCpuX86 )
					{
						$regPath = $regPath[0]
					}

					try
					{
						$LMhive = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey(
							[Microsoft.Win32.RegistryHive]::LocalMachine, 
							$ComputerName
						)

						if ( -not $LMhive )
						{
							continue
						}

						foreach ( $path in $regPath )
						{
							$key = $LMhive.OpenSubKey( $path )
							if ( -not $key )
							{
								continue
							}
							foreach ( $subKey in $key.GetSubKeyNames() )
							{
								$subKeyObj = $null
								$subKeyObj = $key.OpenSubKey( $subKey )
								if ( -not $subKeyObj )
								{
									continue
								}
								$outHash = New-Object -TypeName Collections.Hashtable
								$outHash.User = "Alla"
								$appName = [String]::Empty
								$appName = ( $subKeyObj.GetValue( 'DisplayName' ) )
								if ( $appName )
								{
									foreach ( $keyName in ( $LMhive.OpenSubKey( "$path\$subKey" ) ).GetValueNames() )
									{
										if ( $keyname -match "InstallDate" )
										{
											try
											{
												$value = $subKeyObj.GetValue( $keyName )
												if ( $value )
												{
													$outHash.$keyName = [datetime]::ParseExact( $value , "yyyyMMdd", $null )
												}
											}
											catch
											{
												Write-Warning "Subkey: [$subkey]: $( $_.Exception.Message )"
												continue
											}
										}
										elseif ( $keyname -and ( $value = $subKeyObj.GetValue( $keyName ) ) )
										{
											$outHash.$keyName = $value
										}
									}
									if ( -not $outHash.ContainsKey( "InstallDate" ) )
									{
										$outHash.InstallDate = 0
									}
									$outHash.AppName = $appName
									$outHash.IdentifyingNumber = $subKey
									$outHash.Path = $subKeyObj.ToString()

									$AppCollection.Add( ( New-Object -TypeName pscustomobject -Property $outHash ) ) | Out-Null
								}
							}
						}
					}
					catch
					{
						Write-Error $_
					}

					try
					{
						$UserHive = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey(
							[Microsoft.Win32.RegistryHive]::Users, 
							$ComputerName
						)

						if ( -not $UserHive )
						{
							continue
						}

						$UserHive.GetSubKeyNames() | `
							Where-Object { $_ -match "S-1-5-21.*(?<!_Classes)$" } | `
							ForEach-Object {
								$SID = $_
								foreach ( $path in $regPath )
								{
									$path = "$SID\$( $path )"
									$key = $UserHive.OpenSubKey( $path )
									if ( -not $key )
									{
										continue
									}
									foreach ( $subKey in $key.GetSubKeyNames() )
									{
										$subKeyObj = $null
										$subKeyObj = $key.OpenSubKey( $subKey )
										if ( -not $subKeyObj )
										{
											continue
										}
										$outHash = New-Object -TypeName Collections.Hashtable
										$outHash.User = Get-ADUser $SID
										$appName = [String]::Empty
										$appName = ( $subKeyObj.GetValue( 'DisplayName' ) )
										if ( $appName )
										{
											foreach ( $keyName in ( $LMhive.OpenSubKey( "$path\$subKey" ) ).GetValueNames() )
											{
												if ( $keyname -match "InstallDate" )
												{
													try
													{
														$value = $subKeyObj.GetValue( $keyName )
														if ( $value )
														{
															$outHash.$keyName = [datetime]::ParseExact( $value, "yyyyMMdd", $null )
														}
													}
													catch
													{
														Write-Warning "Subkey: [$subkey]: $( $_.Exception.Message )"
														continue
													}
												}
												elseif ( $keyname -and ( $value = $subKeyObj.GetValue( $keyName ) ) )
												{
													$outHash.$keyName = $value
												}
											}
											if ( -not $outHash.ContainsKey( "InstallDate" ) )
											{
												$outHash.InstallDate = 0
											}
											$outHash.Name = $appName
											$outHash.IdentifyingNumber = $subKey
											$outHash.Publisher = $subKeyObj.GetValue( 'Publisher' )
											$outHash.Path = $subKeyObj.ToString()

											$AppCollection.Add( ( New-Object -TypeName pscustomobject -Property $outHash ) ) | Out-Null
										}
									}
								}
						}
					}
					catch
					{
						Write-Error $_
					}
				}
				End {
					$syncHash.Controls.Window.Dispatcher.Invoke( [action] {
						$syncHash.Controls.Window.Resources['CvsAppsLocal'].Source = $AppCollection | Sort-Object DisplayName, User
					} )
				}
			}

			Import-Module $Modules
			$MemberOf = ( Get-ADComputer $Name -Properties MemberOf ).MemberOf

			try
			{
				Get-InstalledApplication -ComputerName $Name
				[System.Collections.ObjectModel.ObservableCollection[object]] $Wrappers = Invoke-Command -ComputerName $Name -ScriptBlock $syncHash.Code.GetWrappers -ArgumentList $syncHash.Data.msgTable.CodeWrapperHKey -ErrorAction Stop | `
					Where-Object { $_ -isnot [string] }

				$syncHash.Controls.Window.Dispatcher.Invoke( [action] {
					$syncHash.Controls.Window.Resources['CvsAppsWrappers'].Source = $Wrappers
					$syncHash.Controls.Window.Resources['CvsAppsWrappers'].View.Refresh()
					$syncHash.Controls.Window.Resources['CvsLogMessages'].Source.Insert( 0, ( [pscustomobject]@{ LogMessage = $syncHash.Data.msgTable.StrLogAppInfoFetched ; LogTime = ( Get-Date ) ; LogType = "Success" } ) )
					$syncHash.Controls.Window.Resources['CvsLogMessages'].View.Refresh()
				} )
			}
			catch [System.Management.Automation.Remoting.PSRemotingTransportException]
			{
				$syncHash.Errors.Add( $_ ) | Out-Null
				$syncHash.Controls.Window.Dispatcher.Invoke( [action] {
					$syncHash.Controls.Window.Resources['CvsLogMessages'].Source.Insert( 0, ( [pscustomobject]@{ LogMessage = $syncHash.Data.msgTable.ErrComputerNotReachable ; LogTime = ( Get-Date ) ; LogType = "Error" } ) )
					$syncHash.Controls.Window.Resources['CvsLogMessages'].View.Refresh()
				} )
			}
			catch
			{
				$syncHash.Errors.Add( $_ ) | Out-Null
				$syncHash.Controls.Window.Dispatcher.Invoke( [action] {
					$syncHash.Controls.Window.Resources['CvsLogMessages'].Source.Insert( 0, ( [pscustomobject]@{ LogMessage = $_ ; LogTime = ( Get-Date ) ; LogType = "Error" } ) )
					$syncHash.Controls.Window.Resources['CvsLogMessages'].View.Refresh()
				} )
			}
			$syncHash.DC.BtnGetAppList[0] = $true
			$syncHash.DC.BtnReset[0] = $true
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
					$syncHash.Controls.Window.Resources['CvsAppsSysMan'].View.Refresh()
				} )
				$syncHash.Controls.Window.Dispatcher.Invoke( [action] {
					$syncHash.Controls.Window.Resources['CvsAppsCore'].Source = $CoreApplicationsList
					$syncHash.Controls.Window.Resources['CvsAppsCore'].View.Refresh()
				} )
				$syncHash.Controls.Window.Dispatcher.Invoke( [action] {
					$syncHash.Controls.Window.Resources['CvsLogMessages'].Source.Insert( 0, ( [pscustomobject]@{ LogMessage = $syncHash.Data.msgTable.StrLogSmInfoFetched ; LogTime = ( Get-Date ) ; LogType = "Success" } ) )
				} )
			}
			catch [System.Management.Automation.Remoting.PSRemotingTransportException]
			{
				$syncHash.Errors.Add( $_ ) | Out-Null
				$syncHash.Controls.Window.Dispatcher.Invoke( [action] {
					$syncHash.Controls.Window.Resources['CvsLogMessages'].Source.Insert( 0, ( [pscustomobject]@{ LogMessage = "$( $syncHash.Data.msgTable.ErrSmComputerNotReachable )`n$( $_ )"; LogTime = ( Get-Date ) ; LogType = "Error" } ) )
					$syncHash.Controls.Window.Resources['CvsLogMessages'].View.Refresh()
				} )
			}
			catch
			{
				$syncHash.Errors.Add( $_ ) | Out-Null
				$syncHash.Controls.Window.Dispatcher.Invoke( [action] {
					$syncHash.Controls.Window.Resources['CvsLogMessages'].Source.Insert( 0, ( [pscustomobject]@{ LogMessage = "$( $_ )"; LogTime = ( Get-Date ) ; LogType = "Error" } ) )
					$syncHash.Controls.Window.Resources['CvsLogMessages'].View.Refresh()
				} )
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
		Write-OpLog -Message "$( $syncHash.Data.msgTable.ErrComputerNotFound )`n$( $_ )" -LogMessageType "Error"
	}
} )

# Remove all info and reset controls
$syncHash.Controls.BtnReset.Add_Click( {
	Reset
	$syncHash.Data.Computer = $null
	$syncHash.Controls.TbComputerName.Text = ""
} )

# Uninstall the selected application
$syncHash.Controls.BtnUninstall.Add_Click( {
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
			param ( $syncHash, $Modules, $list )
			Import-Module $Modules -Force

			$syncHash.Window.Dispatcher.Invoke( [action] {
				[System.Windows.Controls.Grid]::SetColumnSpan( $syncHash.Controls.PbProgressLocal , 2 )
			} )
			$syncHash.DC.PbProgressSysMan[2] = [System.Windows.Visibility]::Collapsed
			$syncHash.DC.PbProgressLocal[2] = [System.Windows.Visibility]::Visible
			$syncHash.DC.PbProgressLocal[0] = $false
			$ErrorList = [System.Collections.ArrayList]::new()
			$Success = [System.Collections.ArrayList]::new()
			for ( $c = 0; $c -lt $list.Count; $c++ )
			{
				$syncHash.Controls.Window.Dispatcher.Invoke( [action] {
					$syncHash.Controls.Window.Resources['CvsLogMessages'].Source.Insert( 0, ( [pscustomobject]@{ LogMessage = "$( $syncHash.Data.msgTable.StrUninstalling ) $( $list[$c].Name )" ; LogTime = ( Get-Date ) ; LogType = "Info" } ) )
					$syncHash.Controls.Window.Resources['CvsLogMessages'].View.Refresh()
				} )

				try
				{
					$uninstallString = $list[$c].UninstallString
					$isExeOnly = Invoke-Command -ComputerName $syncHash.Data.Computer.Name -ScriptBlock { Test-Path -ErrorAction Ignore -LiteralPath $args[0] } -ArgumentList $uninstallString
					if ( $isExeOnly )
					{
						$uninstallString = "`"$uninstallString`""
					}
					$uninstallString += ' /quiet /norestart'

					Invoke-Command -ComputerName $syncHash.Data.Computer.Name -ScriptBlock { cmd /c $args[0] } -ArgumentList $uninstallString

					$Success.Add( $list[$c].Name ) | Out-Null
				}
				catch
				{
					[void] $ErrorList.Add( ( [pscustomobject]@{ App = $list[$c].Name ; Err = $_ } ) )
				}
				$syncHash.DC.PbProgressLocal[1] = [double] ( ( $c / @( $list ).Count ) * 100 )
			}

			$ErrText = $ErrorList | ForEach-Object { "$( $_.App ) $( $_.Err )" }
			$SuccessText = $Success | Sort-Object | ForEach-Object { "$_" }
			[void] $syncHash.Data.UninstallLog.Add( ( [pscustomobject]@{ ErrorText = $ErrText ; SuccessText = $SuccessText } ) )

			$syncHash.Window.Dispatcher.Invoke( [action] {
				$syncHash.Controls.BtnGetAppList.RaiseEvent( [System.Windows.RoutedEventArgs]::new( [System.Windows.Controls.Button]::ClickEvent ) )
			} )

			$syncHash.Controls.Window.Dispatcher.Invoke( [action] {
				$syncHash.Controls.Window.Resources['CvsLogMessages'].Source.Insert( 0, ( [pscustomobject]@{ LogMessage = "$( $syncHash.Data.msgTable.StrDone )" ; LogTime = ( Get-Date ) ; LogType = "Error" } ) )
				$syncHash.Controls.Window.Resources['CvsLogMessages'].View.Refresh()
			} )
			$syncHash.DC.PbProgressLocal[0] = $true
			$syncHash.DC.PbProgressLocal[1] = 0.0
			$syncHash.DC.PbProgressLocal[2] = [System.Windows.Visibility]::Hidden
			$syncHash.DC.PbProgressSysMan[2] = [System.Windows.Visibility]::Hidden
			$syncHash.Window.Dispatcher.Invoke( [action] {
				[System.Windows.Controls.Grid]::SetColumnSpan( $syncHash.Controls.PbProgressLocal , 1 )
			} )
		} )
		$syncHash.Jobs.PUninstall.AddArgument( $syncHash )
		$syncHash.Jobs.PUninstall.AddArgument( ( Get-Module ) )
		$syncHash.Jobs.PUninstall.AddArgument( @( $syncHash.Controls.DgAppListLocal.SelectedItems | Where-Object { $_ } ) )
		$syncHash.Jobs.HUninstall = $syncHash.Jobs.PUninstall.BeginInvoke()
	}
} )

$syncHash.Controls.DgAppListLocal.Add_SelectionChanged( {
	$syncHash.DC.BtnUninstall[0] = $this.SelectedIndex -ne -1
} )

$syncHash.Controls.DgAppListSysMan.Add_SelectionChanged( {
	$syncHash.DC.BtnUninstall[0] = $this.SelectedIndex -ne -1
} )

$syncHash.Controls.TcAppLists.Add_SelectionChanged( {
	$syncHash.Controls.DgAppListCore.SelectedIndex = -1
	$syncHash.Controls.DgAppListLocal.SelectedIndex = -1
	$syncHash.Controls.DgAppListSysMan.SelectedIndex = -1
	$syncHash.Controls.DgAppListWrappers.SelectedIndex = -1

	$syncHash.DC.BtnUninstall[0] = $false
} )

# When the GUI is visible, check if computername should be entered to the textbox or if applist is to be fetched
$syncHash.Controls.Window.Add_IsVisibleChanged( {
	if ( $this.IsVisible )
	{
		if ( [string]::IsNullOrEmpty( $syncHash.Controls.TbComputerName.Text ) )
		{
			if ( $null -ne $syncHash.Controls.Window.Resources['SearchedItem'] )
			{
				Reset
				$syncHash.Controls.TbComputerName.Text = $syncHash.Controls.Window.Resources['SearchedItem'].Name
			}
		}
		elseif ( ( $syncHash.Controls.TbComputerName.Text -ne $syncHash.Controls.Window.Resources['SearchedItem'].Name ) )
		{
			if ( [System.Windows.MessageBox]::Show( "$( $syncHash.Data.msgTable.StrSwitchComputer )`n$( $syncHash.Data.msgTable.StrSwitchComputer2 ) $( $syncHash.Controls.Window.Resources['SearchedItem'].Name )", "", [System.Windows.MessageBoxButton]::YesNo ) -eq "Yes" )
			{
				$syncHash.Controls.TbComputerName.Text = $syncHash.Controls.Window.Resources['SearchedItem'].Name
			}
		}
	}
} )

# When GUI is first loaded, is there a name to enter to the textbox
$syncHash.Controls.Window.Add_Loaded( {
	try { $syncHash.Controls.TbComputerName.Text = $syncHash.Controls.Window.Resources['SearchedItem'].Name }
	catch {}
} )

<#
.Synopsis
	Show applications
.MenuItem
	Show applications
.Description
	Show and uninstall applications on computer
.SubMenu
	List
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
	.Synopsis
		Resets controls
	#>

	if ( $syncHash.Jobs.ContainsKey( "PFetchLocal") )
	{
		$syncHash.Jobs.PFetchLocal.EndInvoke( $syncHash.Jobs.HFetchLocal ) | Out-Null
	}
	if ( $syncHash.Jobs.ContainsKey( "PFetchSysMan") )
	{
		$syncHash.Jobs.PFetchSysMan.EndInvoke( $syncHash.Jobs.HFetchSysMan ) | Out-Null
	}

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
	$syncHash.DC.BtnGetAppList[0] = $false
	$syncHash.DC.PComputerNotFoundInAdAlert[0] = [System.Windows.Visibility]::Hidden
	$syncHash.DC.PComputerNotFoundInSysManAlert[0] = [System.Windows.Visibility]::Hidden
	$syncHash.Controls.Window.Resources.CvsLogMessages.Source.Clear()
	$syncHash.Controls.Window.Resources.CvsLogMessages.View.Refresh()
}

function Set-Localizations
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

function Uninstall-Local
{
	<#
	.Synopsis
		Start uninstallation on localy installed application
	#>

	try
	{
		$syncHash.Jobs.PUninstall.EndInvoke( $syncHash.Jobs.HUninstall ) | Out-Null
		$syncHash.Jobs.PUninstall.Dispose()
	} catch {}

	$syncHash.Jobs.PUninstall = [powershell]::Create()
	$syncHash.Jobs.PUninstall.AddScript( {
		param ( $syncHash, $Modules, $AppToUninstall )
		$Modules | `
			ForEach-Object {
				Import-Module $_.Name -Force
			}


		$syncHash.Window.Dispatcher.Invoke( [action] {
			[System.Windows.Controls.Grid]::SetColumnSpan( $syncHash.Controls.PbProgressLocal , 2 )
		} )
		$syncHash.DC.PbProgressLocal[0] = [System.Windows.Visibility]::Visible
		$ErrorList = [System.Collections.ArrayList]::new()
		$Success = [System.Collections.ArrayList]::new()

		$syncHash.Controls.Window.Dispatcher.Invoke( [action] {
			$syncHash.Controls.Window.Resources['CvsLogMessages'].Source.Insert( 0, ( [pscustomobject]@{ LogMessage = "$( $syncHash.Data.msgTable.StrUninstalling ) $( $AppToUninstall.Name )" ; LogTime = ( Get-Date ) ; LogType = "Info" } ) )
			$syncHash.Controls.Window.Resources['CvsLogMessages'].View.Refresh()
		} )

		try
		{
			$uninstallString = $AppToUninstall.UninstallString
			$isExeOnly = Invoke-Command -ComputerName $syncHash.Data.Computer.Name -ScriptBlock { Test-Path -ErrorAction Ignore -LiteralPath $args[0] } -ArgumentList $uninstallString

			if ( $isExeOnly )
			{
				$uninstallString = "`"$uninstallString`""
			}
			$uninstallString += ' /quiet /norestart'

			Invoke-Command -ComputerName $syncHash.Data.Computer.Name -ScriptBlock { cmd /c $args[0] } -ArgumentList $uninstallString

			$Success.Add( $AppToUninstall.Name ) | Out-Null
		}
		catch
		{
			[void] $ErrorList.Add( ( [pscustomobject]@{ App = $AppToUninstall.Name ; Err = $_ } ) )
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
			[System.Windows.Controls.Grid]::SetColumnSpan( $syncHash.Controls.PbProgressLocal , 1 )
		} )
	} ) | Out-Null
	$syncHash.Jobs.PUninstall.AddArgument( $syncHash ) | Out-Null
	$syncHash.Jobs.PUninstall.AddArgument( ( Get-Module ) ) | Out-Null
	$syncHash.Jobs.PUninstall.AddArgument( ( $syncHash.Data.SelectedAppForUninstall | Select-Object * ) ) | Out-Null
	$syncHash.Jobs.HUninstall = $syncHash.Jobs.PUninstall.BeginInvoke()
}

function Uninstall-SysMan
{
	<#
	.Synopsis
		Send uninstallation to SysMan
	#>

	$syncHash.DC.PbProgressSysMan[0] = [System.Windows.Visibility]::Visible
	$UninstallJsonBody = "{
		""targets"": [ $( $syncHash.Data.ComputerSysMan.id ) ],
		""systems"": [ $( $syncHash.Data.SelectedAppForUninstall.id ) ],
		""applications"": [],
		""executeDate"": $( ( ( Get-Date ).AddSeconds( 15 ).GetDateTimeFormats() )[30] ),
		""useDirectMembership"": true,
		""useWakeOnLan"": false
	}"

	try
	{
		Invoke-RestMethod -Uri "$( $syncHash.Data.msgTable.CodeSysManUri )api/application/Uninstall" -Body $UninstallJsonBody -Method Post -UseDefaultCredentials -ContentType "application/json"

		Write-OpLog -Message "$( $syncHash.Data.SelectedAppForUninstall.Name ) $( $syncHash.Data.msgTable.StrUninstalledWithSysMan )" -LogMessageType "Success"
		Invoke-Command $syncHash.Code.GetSysManApps -ArgumentList $syncHash, ( Get-Module ), $syncHash.Data.Computer.Name
	}
	catch
	{
		Write-OpLog -Message "$( $syncHash.Data.msgTable.ErrSysManUninstall ):`n$( $_.Exception.Message )" -LogMessageType "Error"
	}
	$syncHash.Controls.Window.Resources['CvsLogMessages'].View.Refresh()
	$syncHash.DC.PbProgressSysMan[0] = [System.Windows.Visibility]::Hidden
}

function Uninstall-Wrapper
{
	<#
	.Synopsis
		Uninstall a wrapper
	#>

	$syncHash.DC.PbProgressLocal[0] = [System.Windows.Visibility]::Visible
	$syncHash.Jobs.PFetchSysMan = [powershell]::Create().AddScript( {
		param ( $syncHash, $Modules )

		$Modules | `
			ForEach-Object {
				Import-Module $_.Name
			}

		try
		{
			
			Invoke-Command -ComputerName $syncHash.Data.Computer.Name -ScriptBlock {
				Set-Location 'HKLM:'

				$RegPath = Get-ChildItem -Path $args[1] | `
					Where-Object { ( Get-ItemProperty $_.PsPath ).Appname -eq $args[0] }

				if ( $RegPath )
				{
					Remove-Item $RegPath -Recurse -ErrorAction Stop
				}
				else
				{
					throw 0
				}
			} -ArgumentList $syncHash.Controls.DgAppListWrappers.SelectedItem.AppName, $syncHash.Data.msgTable.CodeWrapperHKey -ErrorAction Stop

			[System.Collections.ObjectModel.ObservableCollection[object]] $Wrappers = Invoke-Command -ComputerName $syncHash.Data.Computer.Name -ScriptBlock $syncHash.Code.GetWrappers -ArgumentList $syncHash.Data.msgTable.CodeWrapperHKey -ErrorAction Stop | `
				Where-Object { $_ -isnot [string] }

			$syncHash.Controls.Window.Dispatcher.Invoke( [action] {
				$syncHash.Controls.Window.Resources['CvsAppsWrappers'].Source = $Wrappers
				$syncHash.Controls.Window.Resources['CvsAppsWrappers'].View.Refresh()

				$syncHash.Controls.Window.Resources['CvsLogMessages'].Source.Insert( 0, ( [pscustomobject]@{ LogMessage = "$( $syncHash.Data.msgTable.StrWrapperUninstallSuccess ) ('$( $syncHash.Controls.DgAppListWrappers.SelectedItem.AppName )')" ; LogTime = ( Get-Date ) ; LogType = "Success" } ) )
				$syncHash.Controls.Window.Resources['CvsLogMessages'].View.Refresh()
			} )
		}
		catch
		{
			if ( $_.Exception.Message -eq 1 )
			{
				$syncHash.Controls.Window.Dispatcher.Invoke( [action] {
					$syncHash.Controls.Window.Resources['CvsLogMessages'].Source.Insert( 0, ( [pscustomobject]@{ LogMessage = "$( $syncHash.Data.msgTable.ErrNoWrapperFound ) $( $syncHash.Controls.DgAppListWrappers.SelectedItem.AppName )" ; LogTime = ( Get-Date ) ; LogType = "Error" } ) )
					$syncHash.Controls.Window.Resources['CvsLogMessages'].View.Refresh()
				} )
			}
			else
			{
				$syncHash.Controls.Window.Dispatcher.Invoke( [action] {
					$syncHash.Controls.Window.Resources['CvsLogMessages'].Source.Insert( 0, ( [pscustomobject]@{ LogMessage = "$( $syncHash.Data.msgTable.ErrWrapperUninstall ) $( $syncHash.Controls.DgAppListWrappers.SelectedItem.AppName )`n$( $_.Exception.Message )" ; LogTime = ( Get-Date ) ; LogType = "Error" } ) )
					$syncHash.Controls.Window.Resources['CvsLogMessages'].View.Refresh()
				} )
			}
		}
		$syncHash.DC.PbProgressLocal[0] = [System.Windows.Visibility]::Hidden
	} )
	$syncHash.Jobs.PFetchSysMan.AddArgument( $syncHash )
	$syncHash.Jobs.PFetchSysMan.AddArgument( ( Get-Module ) )
	$syncHash.Jobs.PFetchSysMan.AddArgument( $syncHash.Data.Computer.Name )
	$syncHash.Jobs.HFetchSysMan = $syncHash.Jobs.PFetchSysMan.BeginInvoke()
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
[void]$controls.Add( @{ CName = "ChbGetLocal" ; Props = @(
	@{ PropName = "IsChecked"; PropVal = $true }
) } )
[void]$controls.Add( @{ CName = "ChbGetSysMan" ; Props = @(
	@{ PropName = "IsChecked"; PropVal = $true }
) } )
[void]$controls.Add( @{ CName = "PComputerNotFoundInAdAlert" ; Props = @(
	@{ PropName = "Visibility"; PropVal = [System.Windows.Visibility]::Hidden }
) } )
[void]$controls.Add( @{ CName = "PComputerNotFoundInSysManAlert" ; Props = @(
	@{ PropName = "Visibility"; PropVal = [System.Windows.Visibility]::Hidden }
) } )
[void]$controls.Add( @{ CName = "PbProgressLocal" ; Props = @(
	@{ PropName = "Visibility" ; PropVal = [System.Windows.Visibility]::Hidden }
) } )
[void]$controls.Add( @{ CName = "PbProgressSysMan" ; Props = @(
	@{ PropName = "Visibility" ; PropVal = [System.Windows.Visibility]::Hidden }
) } )
[void]$controls.Add( @{ CName = "TblAppListCoreDeploymentName" ; Props = @(
	@{ PropName = "Text"; PropVal = "" }
	@{ PropName = "Foreground" ; PropVal = "Black" }
) } )

BindControls $syncHash $controls
Set-Localizations

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

$syncHash.Code.GetLocalApps = {
	param ( $syncHash, $Modules, $Name )

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
						$outHash.User = $syncHash.Data.msgTable.StrInstalledForAll
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
	$syncHash.DC.PbProgressLocal[0] = [System.Windows.Visibility]::Visible

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
	$syncHash.DC.PbProgressLocal[0] = [System.Windows.Visibility]::Hidden
}

$syncHash.Code.GetSysManApps = {
	param ( $syncHash, $Modules, $Name )

	Import-Module $Modules
	$SysManList = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	$CoreApplicationsList = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	$syncHash.DC.PbProgressSysMan[0] = [System.Windows.Visibility]::Visible

	try
	{
		Invoke-RestMethod -Uri "$( $syncHash.Data.msgTable.CodeSysManUri )api/application/GetInstalledSystems?targetId=$( $syncHash.Data.ComputerSysMan.id )" -Method Get -UseDefaultCredentials -ContentType "application/json" | `
			Select-Object -ExpandProperty result | `
			ForEach-Object {
				$SysManList.Add( $_ ) | Out-Null
			}

		$syncHash.DC.TblAppListCoreDeploymentName[0] = " $( $syncHash.Data.PCRole )"

		if ( $syncHash.Data.PCRole -match "$( $syncHash.Data.msgTable.StrRoleOrg ).*" )
		{
			$PCRoleSysManId = ( Invoke-RestMethod -Uri "$( $syncHash.Data.msgTable.CodeSysManUri )api/Application?name=$( $syncHash.Data.PCRole )" -Method Get -UseDefaultCredentials -ContentType "application/json" ).id
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
	$syncHash.DC.PbProgressSysMan[0] = [System.Windows.Visibility]::Hidden
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
		$this.IsEnabled = $false
		$syncHash.Data.PCRole = $syncHash.Data.Computer.MemberOf | Where-Object { $_ -match ".*_Wrk_.*PC,.*" } | Get-ADGroup -Properties * | Select-Object -ExpandProperty CN

		"Uninstall","FetchLocal","FetchSysMan" | `
			ForEach-Object {
				try
				{
					if ( $syncHash.Jobs.ContainsKey( "P$( $_ )" ) )
					{
						$syncHash.Jobs."P$( $_ )".EndInvoke( $syncHash.Jobs."H$( $_ )" ) | Out-Null
						$syncHash.Jobs."P$( $_ )".Dispose()
					}
				} catch {}
			}

		Write-OpLog -Message $syncHash.Data.msgTable.StrGetApps

		if ( $syncHash.DC.ChbGetLocal[0] )
		{
			$syncHash.Jobs.PFetchLocal = [powershell]::Create().AddScript( $syncHash.Code.GetLocalApps )
			$syncHash.Jobs.PFetchLocal.AddArgument( $syncHash )
			$syncHash.Jobs.PFetchLocal.AddArgument( ( Get-Module ) )
			$syncHash.Jobs.PFetchLocal.AddArgument( $syncHash.Data.Computer.Name )
			$syncHash.Jobs.HFetchLocal = $syncHash.Jobs.PFetchLocal.BeginInvoke()
		}

		if ( $syncHash.DC.ChbGetSysMan[0] )
		{
			$syncHash.Jobs.PFetchSysMan = [powershell]::Create().AddScript( $syncHash.Code.GetSysManApps )
			$syncHash.Jobs.PFetchSysMan.AddArgument( $syncHash )
			$syncHash.Jobs.PFetchSysMan.AddArgument( ( Get-Module ) )
			$syncHash.Jobs.PFetchSysMan.AddArgument( $syncHash.Data.Computer.Name )
			$syncHash.Jobs.HFetchSysMan = $syncHash.Jobs.PFetchSysMan.BeginInvoke()
		}
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
	$summary = "`n`n$( $syncHash.Data.SelectedAppForUninstall.Name )"
	if ( [System.Windows.MessageBox]::Show( "$( $syncHash.Data.msgTable.QUninstall ) $summary", "", [System.Windows.MessageBoxButton]::YesNo ) -eq "Yes" )
	{
		if ( $syncHash.Controls.TcAppLists.SelectedIndex -eq 0 )
		{
			Uninstall-Local
		}
		elseif ( $syncHash.Controls.TcAppLists.SelectedIndex -eq 2 )
		{
			Uninstall-SysMan
		}
	}
} )

$syncHash.Controls.DgAppListLocal.Add_SelectionChanged( {
	if ( $this.SelectedIndex -eq -1 )
	{
		$syncHash.Data.SelectedAppForUninstall = $null
	}
	else
	{
		$syncHash.Data.SelectedAppForUninstall = $this.SelectedItem
	}
} )

$syncHash.Controls.DgAppListSysMan.Add_SelectionChanged( {
	if ( $this.SelectedIndex -eq -1 )
	{
		$syncHash.Data.SelectedAppForUninstall = $null
	}
	else
	{
		$syncHash.Data.SelectedAppForUninstall = $this.SelectedItem
	}
} )

# Verify that input is a valid and existing computername
$syncHash.Controls.TbComputerName.Add_TextChanged( {
	Reset

	if ( $this.Text -match "\w{5}\d{7,}" )
	{
		try
		{
			$syncHash.Data.Computer = Get-ADComputer $this.Text -Properties MemberOf -ErrorAction Stop
			$syncHash.Data.ComputerSysMan = Invoke-RestMethod -Uri "$( $syncHash.Data.msgTable.CodeSysManUri )api/Client?name=$( $this.Text )" -Method Get -UseDefaultCredentials -ContentType 'application/json'
		}
		catch
		{
			$syncHash.DC.PComputerNotFoundAlert[0] = [System.Windows.Visibility]::Visible
		}
	}
	else
	{
		$syncHash.Controls.BtnGetAppList.IsEnabled = $false
	}
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
	try
	{
		$syncHash.Controls.TbComputerName.Text = $syncHash.Controls.Window.Resources['SearchedItem'].Name
	}
	catch {}
} )

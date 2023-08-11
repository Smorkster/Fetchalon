﻿<#
.Synopsis
	Main script for Fetchalon
.Description
	Main script to list functions and tools, and display output
.State
	Prod
.Author
	Smorkster (smorkster)
#>

function CheckO365Connection
{
	<#
	.Synopsis
		Check if there is an active connection to Office365 services
	#>

	try
	{
		Get-AcceptedDomain -ErrorAction Stop | Out-Null

		$syncHash.MiO365Connect.Visibility = [System.Windows.Visibility]::Collapsed
		$syncHash.Window.DataContext.O365Connected = $true
	}
	catch
	{
		$syncHash.MiO365Connect.Visibility = [System.Windows.Visibility]::Visible
		$syncHash.Window.DataContext.O365Connected = $false
		throw $_
	}
}

function CheckO365Roles
{
	<#
	.Synopsis
		Check AzureAD roles for connected user
	.Description
		Verify which roles the connected user are assigned to.
		This is mainly used to make menuitems dependent on specific roles, visible/collapsed
	#>

	if ( ( Get-AzureADDirectoryRole -Filter "DisplayName eq 'Exchange Administrator'" | Get-AzureADDirectoryRoleMember ).UserPrincipalName -match ( Get-AzureADCurrentSessionInfo ).Account.Id )
	{
		$syncHash.Window.Resources['ExchangeAdministrator'] = [System.Windows.Visibility]::Visible
	}
}

function DisplayView
{
	<#
	.Synopsis
		Make view visibility easier to handle
	.Description
		This function makes the handling easier for which view is to be visible.
	.Parameter ViewName
		Name of the view to be visible
	#>

	param ( [string] $ViewName )

	$syncHash.GridViews.Children | `
		ForEach-Object {
			if ( $_.Name -eq $ViewName )
			{
				$_.Visibility = [System.Windows.Visibility]::Visible
			}
			else
			{
				$_.Visibility = [System.Windows.Visibility]::Collapsed
			}
		}
}

function EnableExtraSearch
{
	<#
	.Synopsis
		Verify if button for extra info search is to be enabled
	#>

	$syncHash.BtnGetExtraInfo.IsEnabled = $syncHash.WpSearchFromBoxes.Children.Where( { $_.Visibility -eq [System.Windows.Visibility]::Visible -and $_.IsChecked -eq $true } ).Count -gt 0
}

function GetExtraInfoComputer
{
	<#
	.Synopsis
		Get more information about selected computer
	#>

	$syncHash.Jobs.PSysManFetch = [powershell]::Create()
	$syncHash.Jobs.PSysManFetch.AddScript( {
		param ( $syncHash, $name, $Modules, $CheckSysMan, $CheckProcesses )

		Import-Module $Modules

		if ( $CheckSysMan )
		{
			$syncHash.Data.SearchedItem.ExtraInfo.Base = Invoke-RestMethod "$( $syncHash.Data.msgTable.StrSysManApi )client?name=$( $name )" -UseDefaultCredentials -ContentType "application/json" -Method Get
			$syncHash.Data.SearchedItem.ExtraInfo.Manufacturer = Invoke-RestMethod -Uri "$( $syncHash.Data.msgTable.StrSysManApi )HardwareModel/$( $syncHash.Data.SearchedItem.ExtraInfo.Base.hardwareModelId )" -Method Get -UseDefaultCredentials -ContentType "application/json"
			$syncHash.Data.SearchedItem.ExtraInfo.Sccm = Invoke-RestMethod "$( $syncHash.Data.msgTable.StrSysManApi )client/SccmInformation?name=$( $name )" -UseDefaultCredentials -ContentType "application/json" -Method Get

			Add-Member -InputObject $syncHash.Data.SearchedItem.ExtraInfo.Other -MemberType NoteProperty -Name "activeDirectoryOperatingSystemNameVersion" -Value $null
			Add-Member -InputObject $syncHash.Data.SearchedItem.ExtraInfo.Other -MemberType NoteProperty -Name "ManufacturerModel" -Value $null
			$syncHash.Data.SearchedItem.ExtraInfo.Wmi = Invoke-RestMethod "$( $syncHash.Data.msgTable.StrSysManApi )client/WmiInformation?name=$( $name )" -UseDefaultCredentials -ContentType "application/json" -Method Get -ErrorAction Stop
			$syncHash.Data.SearchedItem.ExtraInfo.Other.activeDirectoryOperatingSystemNameVersion = "$( $syncHash.Data.SearchedItem.ExtraInfo.Base.activeDirectoryOperatingSystemName ) - $( $syncHash.Data.msgTable.StrCompOperatingSystemVersion ) $( $syncHash.Data.SearchedItem.ExtraInfo.Base.activeDirectoryOperatingSystemVersion )"

			$syncHash.Data.SearchedItem.ExtraInfo.Sccm = Invoke-RestMethod "$( $syncHash.Data.msgTable.StrSysManApi )client/SccmInformation?name=$( $name )" -UseDefaultCredentials -ContentType "application/json" -Method Get

			$syncHash.Data.ObjecData.Other.ManufacturerModel = "$( $syncHash.Data.SearchedItem.ExtraInfo.Manufacturer.Manufacturer ) - $( $syncHash.Data.SearchedItem.ExtraInfo.Manufacturer.Name )"

			try
			{
				$syncHash.Data.SearchedItem.ExtraInfo.Local = Invoke-RestMethod "$( $syncHash.Data.msgTable.StrSysManApi )client/LocalInformation?name=$( $name )" -UseDefaultCredentials -ContentType "application/json" -Method Get -ErrorAction Stop
				$syncHash.Data.SearchedItem.ExtraInfo.Wmi = Invoke-RestMethod "$( $syncHash.Data.msgTable.StrSysManApi )client/WmiInformation?name=$( $name )" -UseDefaultCredentials -ContentType "application/json" -Method Get -ErrorAction Stop
				$syncHash.Data.SearchedItem.ExtraInfo.Other.IsOnline = "Online"
			}
			catch
			{
				$syncHash.Data.SearchedItem.ExtraInfo.Other.IsOnline = "Offline"
			}
			$syncHash.Data.SearchedItem.ExtraInfo.Health = Invoke-RestMethod "$( $syncHash.Data.msgTable.StrSysManApi )client/Health?targetName=$( $name )&onlyLatest=$true" -UseDefaultCredentials -ContentType "application/json" -Method Get
		}

		if ( $CheckProcesses )
		{
			Get-Process -ComputerName $name | `
				Select-Object Name, MainWindowTitle, Id, @{ Name = "PercentProcessorTime"; Expression = { 0 } } | `
				ForEach-Object {
					$syncHash.Data.SearchedItem.ExtraInfo.Other.ProcessList.Add( $_ ) | Out-Null
				}
			$PList = Get-CimInstance -ComputerName $name -ClassName Win32_PerfFormattedData_PerfProc_Process | Where-Object { $_.PercentProcessorTime -gt 0 }

			$PList | `
				ForEach-Object {
					$p = $_
					$syncHash.Data.SearchedItem.ExtraInfo.Other.ProcessList | `
						Where-Object { $_.Id -eq $p.IDProcess } | `
						ForEach-Object { $_.PercentProcessorTime = $p.PercentProcessorTime }
				}
			$syncHash.Data.SearchedItem.ExtraInfo.Other.ProcessList = $syncHash.Data.SearchedItem.ExtraInfo.Other.ProcessList | `
				Sort-Object -Property @{ Expression = { $_.PercentProcessorTime } ; Descending = $true }, @{ Expression = { $_.Name } ; Descending = $false }
		}

		$syncHash.Window.Dispatcher.Invoke( [action] {
			Invoke-Command $syncHash.Code.ListProperties -ArgumentList ( "Visible" -eq $syncHash.IcObjectDetailed.Visibility )
			$syncHash.GridProgress.Visibility = [System.Windows.Visibility]::Hidden
		} )
	} )
	$syncHash.Jobs.PSysManFetch.AddArgument( $syncHash )
	$syncHash.Jobs.PSysManFetch.AddArgument( $syncHash.Data.SearchedItem.Name )
	$syncHash.Jobs.PSysManFetch.AddArgument( ( Get-Module | Where-Object { Test-Path $_.Path } ) )
	$syncHash.Jobs.PSysManFetch.AddArgument( $syncHash.ChBGetFromSysMan.IsChecked )
	$syncHash.Jobs.PSysManFetch.AddArgument( $syncHash.ChBGetFromComputerProcesses.IsChecked )

	$syncHash.Jobs.HSysManFetch = $syncHash.Jobs.PSysManFetch.BeginInvoke()
}

function GetExtraInfoDirectoryInfo
{
	GetExtraInfoFileInfo
}

function GetExtraInfoFileInfo
{
	<#
	.Synopsis
		Get more information about selected file or directory
	#>

	$syncHash.GridProgress.Visibility = [System.Windows.Visibility]::Hidden
}

function GetExtraInfoPrintQueue
{
	<#
	.Synopsis
		Get more information about selected printQueue
	#>

	$syncHash.Jobs.PSysManFetch = [powershell]::Create()
	$syncHash.Jobs.PSysManFetch.AddScript( { param ( $syncHash, $Name, $CheckSysMan, $CheckPrintJobs, $Modules )
		Import-Module $Modules
		$syncHash.Data.SearchedItem.ExtraInfo.PrintConf = @{}

		if ( $CheckSysMan )
		{
			$syncHash.Data.SearchedItem.ExtraInfo.Base = Invoke-RestMethod "$( $syncHash.Data.msgTable.StrSysManApi )Printer?name=$Name&take=1&skip=0" -UseDefaultCredentials -ContentType "application/json" -Method Get | Select-Object -ExpandProperty result
			$syncHash.Data.SearchedItem.ExtraInfo.Extended = Invoke-RestMethod "$( $syncHash.Data.msgTable.StrSysManApi )Printer/$( $syncHash.Data.SearchedItem.ExtraInfo.Base.id )" -UseDefaultCredentials -ContentType "application/json" -Method Get
		}

		if ( $CheckPrintJobs )
		{
			Add-Member -InputObject $syncHash.Data.SearchedItem.ExtraInfo.Other -MemberType NoteProperty -Name "PrintJobs" -Value ( [System.Collections.ArrayList]::new() )

			if ( ( $PrintJobs = Get-PrintJob -ComputerName $syncHash.Data.SearchedItem.ExtraInfo.Base.server -PrinterName $syncHash.Data.SearchedItem.ExtraInfo.Base.name | Sort-Object SubmittedTime ).Count -gt 0 )
			{
				$PrintJobs | ForEach-Object { $syncHash.Data.SearchedItem.ExtraInfo.Other.PrintJobs.Add( ( $_ | Select-Object DocumentName, `
						UserName, `
						SubmittedTime, `
						@{ Name = "Error" ; Expression = { $_.JobStatus -eq 0 } }, `
						@{ Name = "Status" ; Expression = { [Microsoft.PowerShell.Cmdletization.GeneratedTypes.PrintJob.JobStatus]( $_.JobStatus ) } }, `
						@{ Name = "Job" ; Expression = { $_ } }
				) ) }
			}
			else
			{
				$syncHash.Data.SearchedItem.ExtraInfo.Other.PrintJobs.Add( $syncHash.Data.msgTable.StrNoPrintJobs )
			}
		}

		$a = Get-Printer -Name $syncHash.Data.SearchedItem.ExtraInfo.Base.name.Trim() -ComputerName $syncHash.Data.SearchedItem.ExtraInfo.Base.server
		$a | Get-Member -MemberType Property | ForEach-Object { $syncHash.Data.SearchedItem.ExtraInfo.PrintConf."$( $_.Name )" = $a."$( $_.Name )" }

		Invoke-Command $syncHash.Code.ListProperties

		$syncHash.Window.Dispatcher.Invoke( [action] {
			$syncHash.GridProgress.Visibility = [System.Windows.Visibility]::Hidden
		} )
	} )
	$syncHash.Jobs.PSysManFetch.AddArgument( $syncHash )
	$syncHash.Jobs.PSysManFetch.AddArgument( $syncHash.Data.SearchedItem.Name )
	$syncHash.Jobs.PSysManFetch.AddArgument( $syncHash.ChBGetFromSysMan.IsChecked )
	$syncHash.Jobs.PSysManFetch.AddArgument( $syncHash.ChBGetFromPrintQueuePrintJobs.IsChecked )
	$syncHash.Jobs.PSysManFetch.AddArgument( ( Get-Module | Where-Object { Test-Path $_.Path } ) )

	$syncHash.Jobs.HSysManFetch = $syncHash.Jobs.PSysManFetch.BeginInvoke()
}

function GetExtraInfoUser
{
	<#
	.Synopsis
		Get more information about selected user.
	#>

	$syncHash.Jobs.PSysManFetch = [powershell]::Create()
	$syncHash.Jobs.PSysManFetch.AddScript( { param ( $syncHash, $Name, $CheckSysMan, $CheckLockOut )
		if ( $CheckSysMan )
		{
			$syncHash.Data.SearchedItem.ExtraInfo.SysManBase = ( Invoke-RestMethod "$( $syncHash.Data.msgTable.StrSysManApi )User?name=$name&take=1&skip=0" -UseDefaultCredentials -ContentType "application/json" -Method Get ).result[0]
			$syncHash.Data.SearchedItem.ExtraInfo.SysManReport = Invoke-RestMethod "$( $syncHash.Data.msgTable.StrSysManApi )reporting/User?userName=$( $Name )" -UseDefaultCredentials -ContentType "application/json" -Method Get

			Add-Member -InputObject $syncHash.Data.SearchedItem.ExtraInfo.Other -MemberType NoteProperty -Name "AzureMemberships" -Value ( $syncHash.Data.SearchedItem.ExtraInfo.SysManReport.azure.memberships.Name | Sort-Object )
			Add-Member -InputObject $syncHash.Data.SearchedItem.ExtraInfo.Other -MemberType NoteProperty -Name "AzureDevices" -Value ( [System.Collections.ArrayList]::new() )
			$syncHash.Data.SearchedItem.ExtraInfo.SysManReport.azure.devices | Sort-Object name | ForEach-Object { $syncHash.Data.SearchedItem.ExtraInfo.Other.AzureDevices.Add( $_ ) }
		}

		if ( $CheckLockOut )
		{
			Add-Member -InputObject $syncHash.Data.SearchedItem.ExtraInfo.Other -MemberType NoteProperty -Name "LockoutList" -Value ( [System.Collections.ArrayList]::new() )

			# Get a list of account lockouts
			$lockouts = ( Get-ChildItem -Path $syncHash.Data.msgTable.CodeLockoutAddress | Where-Object { $_.LastWriteTime -gt ( Get-Date ).AddDays( -7 ) } | Select-String -Pattern "$( $Name )" ).Line | Where-Object { $_ } | ForEach-Object {
				$d, $null, $com, $dom = $_ -split "`t"
				[pscustomobject]@{ "$( $syncHash.Data.msgTable.StrLockoutDate )" = $d; "$( $syncHash.Data.msgTable.StrLockoutComputer )" = $com; "$( $syncHash.Data.msgTable.StrLockoutDomain )" = $dom }
			} | Sort-Object @{ Expression = { $_."$( $syncHash.Data.msgTable.StrLockoutDate )" } ; Descending = $true }

			if ( $lockouts.Count -gt 0 )
			{ $lockouts | ForEach-Object { [void] $syncHash.Data.SearchedItem.ExtraInfo.Other.LockoutList.Add( $_ ) } }
			else
			{ [void] $syncHash.Data.SearchedItem.ExtraInfo.Other.LockoutList.Add( ( [pscustomobject]@{ $syncHash.Data.msgTable.StrNoLockoutsFoundTitle = $syncHash.Data.msgTable.StrNoLockoutsFound } ) ) }
		}

		$syncHash.Window.Dispatcher.Invoke( [action] {
			Invoke-Command $syncHash.Code.ListProperties -ArgumentList ( "Visible" -eq $syncHash.IcObjectDetailed.Visibility )
			$syncHash.GridProgress.Visibility = [System.Windows.Visibility]::Hidden
		} )
	} )
	$syncHash.Jobs.PSysManFetch.AddArgument( $syncHash )
	$syncHash.Jobs.PSysManFetch.AddArgument( $syncHash.Data.SearchedItem.SamAccountName )
	$syncHash.Jobs.PSysManFetch.AddArgument( $syncHash.ChBGetFromSysMan.IsChecked )
	$syncHash.Jobs.PSysManFetch.AddArgument( $syncHash.ChBGetFromUserLockOut.IsChecked )

	$syncHash.Jobs.HSysManFetch = $syncHash.Jobs.PSysManFetch.BeginInvoke()
}

function GetPropHandlers
{
	<#
	.Synopsis
		Import PropHandlers
	.Description
		Import PropHandlers per objectclass, if description or title is not specified, a default string will be set
	#>

	$syncHash.Code = @{}
	$syncHash.Code.PropHandlers = @{}
	Get-ChildItem -Path "$BaseDir\Modules\PropHandlers" | `
		ForEach-Object {
			$Module = $_.BaseName -replace "PropHandlers"
			$syncHash.Code.PropHandlers."$( $Module )" = @{}
			( Import-Module $_.FullName -PassThru ).ExportedVariables.GetEnumerator() | `
				ForEach-Object {
					if ( $null -ne $_.Value.Value.Code )
					{
						$syncHash.Code.PropHandlers."$( $Module )"."$( $_.Key )" = $_.Value.Value

						if ( [string]::IsNullOrEmpty( $syncHash.Code.PropHandlers."$( $Module )"."$( $_.Key )".Description ) )
						{
							$syncHash.Code.PropHandlers."$( $Module )"."$( $_.Key )".Description = $syncHash.Data.msgTable.StrDefaultHandlerDescription
						}
						if ( [string]::IsNullOrEmpty( $syncHash.Code.PropHandlers."$( $Module )"."$( $_.Key )".Title ) )
						{
							$syncHash.Code.PropHandlers."$( $Module )"."$( $_.Key )".Title = $syncHash.Data.msgTable.StrRunHandler
						}
					}
				}
		}
}

function OpenTool
{
	<#
	.Synopsis
		Start a tool from script
	#>

	param ( $SenderObject )

	$SenderObject.DataContext.Process = [pscustomobject]@{ RunspaceH = $null ; RunspaceP = $null ; EventListenerPsInitializer = $null ; EventListenerToolProcess = $null ; PObj = $null ; MainWindowHandle = $null }

	$SenderObject.DataContext.Process.RunspaceP = [powershell]::Create()
	[void] $SenderObject.DataContext.Process.RunspaceP.AddScript( {
		param ( $Script, $BaseDir, $Modules )

		Import-Module $Modules
		Start-Process powershell -ArgumentList $Script, $BaseDir -WindowStyle Hidden -PassThru
	} )
	[void] $SenderObject.DataContext.Process.RunspaceP.AddArgument( $SenderObject.DataContext.Ps )
	[void] $SenderObject.DataContext.Process.RunspaceP.AddArgument( $SenderObject.DataContext.BaseDir )
	[void] $SenderObject.DataContext.Process.RunspaceP.AddArgument( ( Get-Module | Where-Object { Test-Path $_.Path } ) )
	$SenderObject.DataContext.Process.RunspaceH = $SenderObject.DataContext.Process.RunspaceP.BeginInvoke()

	$SenderObject.DataContext.Process.EventListenerPsInitializer = Register-ObjectEvent -InputObject $SenderObject.DataContext.Process.RunspaceP -EventName InvocationStateChanged -MessageData @( $SenderObject, $syncHash ) -Action {
		$Event.MessageData[1].MiTools.Header.UpdateLayout()
		if ( $EventArgs.InvocationStateInfo.State -in 'Completed', 'Failed' )
		{
			$Event.MessageData[0].DataContext.Process.PObj = ( $Event.MessageData[0].DataContext.Process.RunspaceP.EndInvoke( $Event.MessageData[0].DataContext.Process.RunspaceH ) )[0]
			$Event.MessageData[0].DataContext.Process.MainWindowHandle = $Event.MessageData[0].DataContext.Process.PObj.MainWindowHandle
			$Event.MessageData[0].DataContext.Process.EventListenerToolProcess = Register-ObjectEvent -InputObject $Event.MessageData[0].DataContext.Process.PObj -EventName Exited -MessageData $Event.MessageData[0] -Action {
				$p = $Event.MessageData.DataContext.Process.EventListenerPsInitializer
				$r = $Event.MessageData.DataContext.Process.EventListenerToolProcess
				$Event.MessageData.Dispatcher.Invoke( [action] { $Event.MessageData.DataContext.Process = $null }, [System.Windows.Threading.DispatcherPriority]::DataBind )
				Unregister-Event $p
				Unregister-Event $r
				[GC]::Collect()
			}
			[GC]::Collect()
		}
	}
}

function PrepareToRunScript
{
	<#
	.Synopsis
		Run loaded function
	#>

	param ( $ScriptObject )

	# Create runspace for function
	if ( -not $ScriptObject.NoRunspace )
	{
		$syncHash.Jobs.ExecuteFunction = [pscustomobject]@{ P = [powershell]::Create() ; H = $null }
		$syncHash.Jobs.ExecuteFunction.P.Runspace = $syncHash.Jobs.ScriptsRunspace
		$syncHash.Jobs.ExecuteFunction.P.AddScript( $syncHash.Code.SBlockExecuteFunction ) | Out-Null
		$syncHash.Jobs.ExecuteFunction.P.AddParameter( "syncHash", $syncHash ) | Out-Null
		$syncHash.Jobs.ExecuteFunction.P.AddParameter( "ScriptObject", $ScriptObject ) | Out-Null
		$syncHash.Jobs.ExecuteFunction.P.AddParameter( "Modules", ( Get-Module | Where-Object { Test-Path $_.Path } ) ) | Out-Null

		$ItemToSend = $null
		# SearchedItem is not required in the function
		if ( "None" -eq $ScriptObject.SearchedItemRequest )
		{
			$syncHash.Jobs.ExecuteFunction.P.AddParameter( "SearchedItem", $null ) | Out-Null
		}
		# SearchedItem is allowed/required in the function
		else
		{
			if ( $null -ne $syncHash.Data.SearchedItem -and `
				$syncHash.Data.SearchedItem.ObjectClass -eq $ScriptObject.ObjectClass
			)
			{
				$ItemToSend = @{}

				$syncHash.Data.SearchedItem | `
					Get-Member -MemberType NoteProperty | `
					ForEach-Object { $ItemToSend."$( $_.Name )" = $syncHash.Data.SearchedItem."$( $_.Name )" }

				$syncHash.Jobs.ExecuteFunction.P.AddParameter( "SearchedItem", $ItemToSend ) | Out-Null
			}
			else
			{
				$syncHash.Jobs.ExecuteFunction.P.AddParameter( "SearchedItem", $null ) | Out-Null
			}
		}
	}

	# The function does not want input
	if ( $ScriptObject.InputData.Count -eq 0 )
	{
		# Function is to be run without a runspace
		if ( $ScriptObject.NoRunspace )
		{
			RunScriptNoRunspace -ScriptObject $ScriptObject
		}
		else
		{
			RunScript
		}
	}
	# Input is wanted for the function
	else
	{
		# If SearchedItem is allowed/requested by function, enter it in the first inputbox
		if ( "None" -ne $ScriptObject.SearchedItemRequest -and $ScriptObject.ObjectClass -eq $syncHash.Data.SearchedItem.ObjectClass )
		{
			if ( "printQueue" -eq $syncHash.Data.SearchedItem.ObjectClass )
			{
				$syncHash.GridFunctionOp.DataContext.InputData[0].EnteredValue = $syncHash.Data.SearchedItem.Name
			}
			else
			{
				$syncHash.GridFunctionOp.DataContext.InputData[0].EnteredValue = $syncHash.Data.SearchedItem.SamAccountName
			}
			$syncHash.IcFunctionInput.ItemContainerGenerator.ContainerFromIndex( 0 ).Focus()
		}
	}
}

function ReadSettingsFile
{
	<#
	.Synopsis Get users settings
	#>

	$syncHash.Data.UserSettings = [pscustomobject]@{
		VisibleProperties = [pscustomobject]@{
			Computer = [System.Collections.ArrayList]::new()
			DirectoryInfo = [System.Collections.ArrayList]::new()
			FileInfo = [System.Collections.ArrayList]::new()
			Group = [System.Collections.ArrayList]::new()
			PrintQueue = [System.Collections.ArrayList]::new()
			User = [System.Collections.ArrayList]::new()
			O365User = [System.Collections.ArrayList]::new()
			O365SharedMailbox = [System.Collections.ArrayList]::new()
			O365Resource = [System.Collections.ArrayList]::new()
			O365Room = [System.Collections.ArrayList]::new()
			O365Distributionlist = [System.Collections.ArrayList]::new()
		}
		Maximized = $false
		MenuTextVisible = $true
		WindowHeight = 0
		WindowLeft = 0
		WindowWidth = 0
		WindowTop = 0
	}

	$ReadSettings = Get-Content $syncHash.Data.SettingsPath | ConvertFrom-Json
	$ReadSettings.VisibleProperties | `
		Get-Member -MemberType NoteProperty | `
		ForEach-Object {
			$ObjectClass = $_.Name
			$ReadSettings.VisibleProperties.$ObjectClass | `
				ForEach-Object {
					[void] $syncHash.Data.UserSettings.VisibleProperties.$ObjectClass.Add( $_ )
				}
		}

	$ReadSettings | `
		Get-Member -MemberType NoteProperty | `
		Where-Object { $_.Name -notmatch "VisibleProperties" } | `
		ForEach-Object { $syncHash.Data.UserSettings."$( $_.Name )" = $ReadSettings."$( $_.Name )" }

	$syncHash.Window.Resources['MenuTextVisibility'] = [System.Windows.Visibility]::Parse( [System.Windows.Visibility], $syncHash.Data.UserSettings.MenuTextVisible )
}

function ResetInfo
{
	<#
	.Synopsis
		Reset values and controls
	#>

	$syncHash.IcObjectDetailed.Visibility = [System.Windows.Visibility]::Collapsed
	$syncHash.GridO365Status.Visibility = [System.Windows.Visibility]::Collapsed
	$syncHash.GridO365Status.Children | `
		Where-Object { $_ -is [System.Windows.Shapes.Ellipse] } | `
		ForEach-Object { $_.Fill = "Red" }

	$syncHash.Window.DataContext.SearchedItem = $null
	$syncHash.MenuObject.IsEnabled = $false
	$syncHash.Data.SearchedItem = $null
	$syncHash.DC.DgSearchResults[0].Clear()
	$syncHash.DC.TblFailedSearchMessage[0] = ""
	try { $syncHash.Jobs.SearchJobs | ForEach-Object { $_.P.Dispose() } } catch {}
	$syncHash.Jobs | ForEach-Object { try { $_.Stop() ; $_.Dispose() } catch {} }
	$syncHash.ScObjInfo.ScrollToTop()

	$syncHash.Window.Resources['CvsDetailedProps'].Source.Clear()
	$syncHash.Window.Resources['CvsPropsList'].Source.Clear()
	$syncHash.GetEnumerator() | `
		Where-Object { $_.Name -match "^ChBGetFrom" } | `
		ForEach-Object { ( $_.Value ).IsChecked = $true }
	$syncHash.Window.Resources.GetEnumerator() | Where-Object { $_.Key -match "Cvs.*" } | ForEach-Object { $_.Value.View.Refresh() }
	$syncHash.TblObjName.GetBindingExpression( [System.Windows.Controls.TextBlock]::TextProperty ).UpdateTarget()
}

function RunScript
{
	<#
	.Synopsis
		Start the runspace for function
	#>

	$syncHash.Jobs.ExecuteFunction.H = $syncHash.Jobs.ExecuteFunction.P.BeginInvoke()
}

function RunScriptNoRunspace
{
	<#
	.Synopsis
		Run a function without connecting it to a runspace
	#>

	param ( $ScriptObject, $EnteredInput )

	$syncHash.DC.GridProgress[0] = [System.Windows.Visibility]::Visible
	$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.Window.Resources['MainOutput'].Title = $syncHash.Data.msgTable.StrScriptRunningWithoutRunspace }, [System.Windows.Threading.DispatcherPriority]::Send )

	$EnteredInput = @{}
	$syncHash.GridFunctionOp.DataContext.InputData | ForEach-Object { $EnteredInput."$( $_.Name )" = $_.EnteredValue }
	if ( "None" -eq $ScriptObject.SearchedItemRequest )
	{
		. $syncHash.Code.SBlockExecuteFunction $syncHash $ScriptObject ( Get-Module | Where-Object { Test-Path $_.Path } ) $null $EnteredInput
	}
	else
	{
		. $syncHash.Code.SBlockExecuteFunction $syncHash $ScriptObject ( Get-Module | Where-Object { Test-Path $_.Path } ) $syncHash.Data.SearchedItem $EnteredInput
	}

	$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.Window.Resources['MainOutput'].Title = $msgTable.StrDefaultMainTitle } )
}

function SetLocalizations
{
	<#
	.Synopsis
		Set localizations, both directly and in resource
	#>

	$syncHash.IcObjectDetailed.Resources['ContentTblPropNameTT'] = $msgTable.ContentTblPropNameTT
	$syncHash.Window.Resources['MiSubLevelBaseStyle'].Resources['StrOpensSeparateWindow'] = $msgTable.StrOpensSeparateWindow

	$DateTimeFormats = [System.Globalization.CultureInfo]::CurrentCulture.DateTimeFormat
	$syncHash.Window.Resources['ContentNoMembersOfList'] = @( $msgTable.ContentNoMembersOfList )
	$syncHash.Window.Resources['MainOutput'].Resources['StrCompressedDateTimeFormat'] = "yyMMdd HH:mm"
	$syncHash.Window.Resources['MainOutput'].Resources['StrDateFormat'] = $DateTimeFormats.ShortDatePattern
	$syncHash.Window.Resources['MainOutput'].Resources['StrFullDateTimeFormat'] = "$( $DateTimeFormats.ShortDatePattern ) $( $DateTimeFormats.LongTimePattern )"
	$syncHash.Window.Resources['MainOutput'].Resources['StrTimeFormat'] = $DateTimeFormats.LongTimePattern
	$syncHash.Window.Resources['StrCompressedDateTimeFormat'] = "yyMMdd HH:mm"
	$syncHash.Window.Resources['StrDateFormat'] = $DateTimeFormats.ShortDatePattern
	$syncHash.Window.Resources['StrFullDateTimeFormat'] = "$( $DateTimeFormats.ShortDatePattern ) $( $DateTimeFormats.LongTimePattern )"
	$syncHash.Window.Resources['StrTimeFormat'] = $DateTimeFormats.LongTimePattern

	# Set eventtriggers
	$syncHash.Window.Resources['BtnCopyOutputDataStyle'].Setters.Where( { $_.Event.Name -match "Click" } )[0].Handler = $syncHash.Code.CopyOutputData
	$syncHash.Window.Resources['BtnCopyOutputObjectStyle'].Setters.Where( { $_.Event.Name -match "Click" } )[0].Handler = $syncHash.Code.CopyOutputObject
	$syncHash.Window.Resources['BtnCopyPropertyStyle'].Setters.Where( { $_.Event.Name -match "Click" } )[0].Handler = $syncHash.Code.CopyProperty
	$syncHash.Window.Resources['BtnRunPropStyle'].Setters.Where( { $_.Event.Name -match "Click" } )[0].Handler = $syncHash.Code.RunPropHandler
	$syncHash.Window.Resources['BtnViewFileDir'].Setters.Where( { $_.Event.Name -match "Click" } )[0].Handler = $syncHash.Code.ViewFileDir
	$syncHash.Window.Resources['DgrFuncOutputStyle'].Setters.Where( { $_.Event.Name -match "RequestBringIntoView" } )[0].Handler = $syncHash.Code.DataGridRowDisableBringIntoView
	$syncHash.Window.Resources['MiSubLevelFunctionsStyle'].Setters.Where( { $_.Event.Name -match "Click" } )[0].Handler = $syncHash.Code.MenuItemClick
	$syncHash.Window.Resources['MiSubLevelO365Style'].Setters.Where( { $_.Event.Name -match "Click" } )[0].Handler = $syncHash.Code.MenuItemClick
	$syncHash.Window.Resources['MiSubLevelToolStyle'].Setters.Where( { $_.Event.Name -match "Click" } )[0].Handler = $syncHash.Code.MenuItemClick
	$syncHash.Window.Resources['TbInputStyle'].Setters.Where( { $_.Event.Name -match "Loaded" } )[0].Handler = $syncHash.Code.InputTextBoxLoaded
	$syncHash.Window.Resources['TblHlStyle'].Setters.Where( { $_.Event.Name -match "MouseDown" } )[0].Handler = $syncHash.Code.HyperLinkClick

	$syncHash.MiOutputHistory.ItemContainerStyle.Setters[0].Handler = $syncHash.Code.ShowOutputItem

	$syncHash.Window.Resources['CvsDetailedProps'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	$syncHash.Window.Resources['CvsMiAbout'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	$syncHash.Window.Resources['CvsMiComputerFunctions'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	$syncHash.Window.Resources['CvsMiGroupFunctions'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	$syncHash.Window.Resources['CvsMiO365DistributionlistFunctions'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	$syncHash.Window.Resources['CvsMiO365ResourceFunctions'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	$syncHash.Window.Resources['CvsMiO365RoomFunctions'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	$syncHash.Window.Resources['CvsMiO365SharedMailboxFunctions'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	$syncHash.Window.Resources['CvsMiO365UserFunctions'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	$syncHash.Window.Resources['CvsMiOtherFunctions'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	$syncHash.Window.Resources['CvsMiOutputHistory'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	$syncHash.Window.Resources['CvsMiPrintQueueFunctions'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	$syncHash.Window.Resources['CvsMiSeparateToolsFunctions'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	$syncHash.Window.Resources['CvsMiTools'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	$syncHash.Window.Resources['CvsMiUserFunctions'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	$syncHash.Window.Resources['CvsPropsList'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()

	"DgSearchResults", "IcObjectDetailed", "IcPropsList", "MiOutputHistory" | `
		ForEach-Object {
			[System.Windows.Data.BindingOperations]::EnableCollectionSynchronization( $syncHash."$( $_ )".ItemsSource, $syncHash."$( $_ )" )
		}
}

function StartSearch
{
	<#
	.Synopsis
		Initiate object search
	#>

	ResetInfo
	WriteLog -Text "Search" -UserInput $syncHash.DC.TbSearch[0] -Success $true | Out-Null
	if ( $syncHash.DC.TbSearch[0] -in $syncHash.Data.TestSearches.Keys )
	{
		$syncHash.DC.TbSearch[0] = $syncHash.Data.TestSearches."$( $syncHash.DC.TbSearch[0] )"
	}
	DisplayView -ViewName "None"

	$syncHash.Jobs.SearchJob = [powershell]::Create()
	$syncHash.Jobs.SearchJob.AddScript( {
		param ( $syncHash, $Modules, $O365Connected )
		Import-Module $Modules | Out-Null

		function Test-Mail
		{
			param ( [string] $Address )
			
			try
			{
				Resolve-DnsName -Name ( [mailaddress]$Address ).Host -Type MX -ErrorAction Stop | Out-Null
				return $true
			}
			catch
			{
				return $false
			}
		}
		$syncHash.Window.Dispatcher.Invoke( [action] {
			$syncHash.PopupMenu.IsOpen = $true
			$syncHash.DC.PbSearchProgress[0] = [System.Windows.Visibility]::Visible
		}, [System.Windows.Threading.DispatcherPriority]::DataBind )

		# Check if text is a path for file/directory
		if ( Test-Path $syncHash.DC.TbSearch[0].Trim() )
		{
			$FoundObject = Get-Item $syncHash.DC.TbSearch[0]
			Add-Member -InputObject $FoundObject -MemberType NoteProperty -Name "ObjectClass" -Value ( $FoundObject.GetType().Name )

			$syncHash.DC.DgSearchResults[0].Add( $FoundObject )
		}
		# Searchstring match an mailaddress
		elseif ( ( Test-Mail -Address $syncHash.DC.TbSearch[0].Trim() ) )
		{
			$Objects = [System.Collections.ArrayList]::new()

			Get-ADUser -LDAPFilter "(Mail=$( $syncHash.DC.TbSearch[0].Trim() ))" | `
				ForEach-Object {
					$Objects.Add( $_ ) | Out-Null
				}
			if ( $O365Connected )
			{
				Get-EXORecipient $syncHash.DC.TbSearch[0].Trim() | `
					ForEach-Object {
						$Obj = $_
						$ObjectClass = switch ( $Obj.RecipientTypeDetails )
						{
							"EquipmentMailbox" { "O365Resource" }
							"MailUniversalDistributionGroup" { "O365Distributionlist" }
							"RoomMailbox" { "O365Room" }
							"SharedMailbox" { "O365SharedMailbox" }
							"UserMailbox" { "O365User" }
						}
						Add-Member -InputObject $Obj -MemberType NoteProperty -Name "ObjectClass" -Value $ObjectClass
						$Objects.Add( $Obj ) | Out-Null
					}
			}

			$Objects | `
				ForEach-Object {
					$syncHash.DC.DgSearchResults[0].Add( $_ )
				}
		}
		# Searchstring match name of Azure-group
		elseif ( $syncHash.DC.TbSearch[0].Trim() -match $syncHash.Data.msgTable.CodeAzureGrpName )
		{
			if ( $O365Connected )
			{
				switch -Regex ( $syncHash.DC.TbSearch[0].Trim() )
				{
					"^MB-" {
						$AzureObject = Get-AzureADMSGroup -Filter "startswith(DisplayName,'$( $syncHash.DC.TbSearch[0].Trim() )')"
						break
					}
					"^\w* Funk .*" {
						$FoundObject = Get-EXORecipient $syncHash.DC.TbSearch[0].Trim()
						break
					}
					"^DL-" {
						$AzureObject = Get-AzureADMSGroup -Filter "DisplayName eq '$( $syncHash.DC.TbSearch[0].Trim() )'"
						break
					}
					"^\w* Dist .*" {
						$FoundObject = Get-EXORecipient $syncHash.DC.TbSearch[0].Trim()
						break
					}
					"^RES-" {
						$AzureObject = Get-AzureADMSGroup -Filter "startswith(DisplayName, '$( $syncHash.DC.TbSearch[0].Trim() )')"
						break
					}
					"^\w* (resurs)|(rum) .*" {
						$FoundObject = Get-EXORecipient $syncHash.DC.TbSearch[0].Trim()
						break
					}
				}
				if ( $AzureObject )
				{
					$AzureObject[0].DisplayName -match "^\w*-(?<Name>.*)-\w*$" | Out-Null
					$FoundObject = Get-EXORecipient $Matches.Name
				}

				$OC = switch ( $FoundObject.RecipientTypeDetails )
				{
					"SharedMailbox" { "O365SharedMailbox" }
					"EquipmentMailbox" { "O365Resource" }
					"RoomMailbox" { "O365Room" }
					"MailUniversalDistributionGroup" { "O365Distributionlist" }
				}
				Add-Member -InputObject $FoundObject -MemberType NoteProperty -Name "ObjectClass" -Value $OC

				if ( $null -ne $FoundObject )
				{
					$syncHash.DC.DgSearchResults[0].Add( $FoundObject )
				}
			}
			else
			{
				$syncHash.DC.TblFailedSearchMessage[0] = $syncHash.Data.msgTable.ErrSearchO365NotConnected
			}
		}
		# Check if text matches an IP-address
		elseif ( $syncHash.DC.TbSearch[0].Trim() -match "^([1-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])(\.([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])){3}$" )
		{
			$FoundObject = [System.Net.Dns]::GetHostByAddress( $syncHash.DC.TbSearch[0].Trim() )
			$ComputerItems = Get-ADObject -LDAPFilter "(&(ObjectClass=computer)(Name=$( ( $FoundObject.hostname -split "\." )[0] ) ))" -Properties *
			$PrinterItems = Get-ADObject -LDAPFilter "(&(ObjectClass=printQueue)(PortName=$( $syncHash.DC.TbSearch[0].Trim() )))" -Properties *

			$ComputerItems, $PrinterItems | `
				ForEach-Object {
					$syncHash.DC.DgSearchResults[0].Add( $_ )
				}
		}
		# Check if text matches an PowerShell-cmdlet
		elseif ( $syncHash.DC.TbSearch[0].Trim() -match "^(?<Command>Get-\w*)\s*" )
		{
			$syncHash.DC.TbSearch[0].Trim() -split " " | `
				Where-Object { $_ -notmatch "(Compare)|(Find)|(Get)|(Measure)|(Out)|(Read)|(Search)|(Select)|(Test)-" } | `
				ForEach-Object `
					-Begin { $NotAllowedCmdLet = $false } `
					-Progess {
						try
						{
							Get-Command $_ -ErrorAction Stop | Out-Null
							$NotAllowedCmdLet = $true
						}
						catch {}
					}
			if ( $NotAllowedCmdLet )
			{
				$ForbiddenCmdLet = [System.Management.Automation.ErrorRecord]::new( $syncHash.Data.msgTable.ErrForbiddenCmdLet, "0", [System.Management.Automation.ErrorCategory]::PermissionDenied , $null )
				$syncHash.DC.DgSearchResults[0].Add( $CmdLetResult )
			}
			else
			{
				try
				{
					Get-Command $Matches.Command -ErrorAction Stop | Out-Null
					$CmdLetResult = Invoke-Expression $syncHash.DC.TbSearch[0].Trim()
				}
				catch
				{
					$CmdLetResult = $_
				}
				$syncHash.DC.DgSearchResults[0].Add( $CmdLetResult )
			}
		}
		# None of the above, searchstring may be an id for an AD-object
		else
		{
			$Id = $syncHash.DC.TbSearch[0].Trim()
			$LDAPSearches = [System.Collections.ArrayList]::new()

			if ( $Id -match "\w{5}\d{8}" )
			{
				$LDAPSearches.Add( "(&(ObjectClass=computer)(Name=$Id))" ) | Out-Null
			}
			elseif ( $Id -match "(?i)^[a-z0-9]{4}$" )
			{
				$LDAPSearches.Add( "(&(ObjectClass=user)(SamAccountName=$Id))" ) | Out-Null
				$LDAPSearches.Add( "(&(ObjectClass=group)(($( $syncHash.Data.msgTable.StrIdPropName )=$( $syncHash.Data.msgTable.StrIdPrefix )-$Id))" ) | Out-Null
			}
			else
			{
				# Group
				switch -Regex ( $Id )
				{
					"_$" { $LDAPSearches.Add( "(&(ObjectClass=group)(Name=$Id*))" ) | Out-Null ; break }
					"_" { $LDAPSearches.Add( "(&(ObjectClass=group)(Name=$Id))" ) | Out-Null ; break }
					"\*" { $LDAPSearches.Add( "(&(ObjectClass=group)(|(Name=$Id)($( $syncHash.Data.msgTable.StrIdPropName )=$( $syncHash.Data.msgTable.StrIdPrefix )-$Id)))" ) | Out-Null ; break }
					default { $LDAPSearches.Add( "(&(ObjectClass=group)(|(Name=*$Id*)($( $syncHash.Data.msgTable.StrIdPropName )=$( $syncHash.Data.msgTable.StrIdPrefix )-$Id)))" ) | Out-Null ; break }
				}

				# User
				switch -Regex ( $Id )
				{
					"(?i)[aeiuoyåäöÀ-ÿ ].*[^\d]$" { $LDAPSearches.Add( "(&(ObjectClass=user)(Name=$Id))" ) | Out-Null ; break }
					"(?i)f\w{3}\d*" { $LDAPSearches.Add( "(&(ObjectClass=user)(SamAccountName=$Id))" ) | Out-Null ; break }
					"\*" { $LDAPSearches.Add( "(&(ObjectClass=user)(|(SamAccountName=$Id)(Name=$Id)))" ) | Out-Null ; break }
				}

				# Computer
				$LDAPSearches.Add( "(&(ObjectClass=computer)(SamAccountName=$Id*))" ) | Out-Null

				# PrintQueue
				$LDAPSearches.Add( "(&(ObjectClass=printQueue)(Name=$Id*))" ) | Out-Null
			}

			$LDAPSearches | `
				ForEach-Object {
					$P = $_
					Get-ADObject -LDAPFilter $_ -Properties * } |`
				Sort-Object -Property ObjectClass, Name | `
				ForEach-Object {
					$syncHash.DC.DgSearchResults[0].Add( $_ )
				}
		}

		$syncHash.Window.Dispatcher.Invoke( [action] {
			$syncHash.DgSearchResults.SelectedIndex = 0
			$syncHash.DC.PbSearchProgress[0] = [System.Windows.Visibility]::Collapsed
			$syncHash.DgSearchResultsColRunCount.Text = $syncHash.DC.DgSearchResults[0].Count
		}, [System.Windows.Threading.DispatcherPriority]::Send )

		$syncHash.Window.Dispatcher.Invoke( [action] {
			if ( 0 -eq $syncHash.DC.DgSearchResults[0].Count )
			{
				$syncHash.GridFailedSearch.Visibility = [System.Windows.Visibility]::Visible
			}
			else
			{
				$syncHash.GridObj.Visibility = [System.Windows.Visibility]::Visible

				if ( $syncHash.DC.DgSearchResults[0].Count -eq 1 )
				{
					Invoke-Command -ScriptBlock $syncHash.Code.ListItem -ArgumentList $syncHash.DC.DgSearchResults.Item( 0 ) -NoNewScope
				}
				elseif ( $syncHash.DC.DgSearchResults[0].Count -gt 1 )
				{
					# This sets keyboard focus on DgSearchResults
					$a = $syncHash.DgSearchResults.ItemContainerGenerator.ContainerFromIndex( 0 )
					$a.MoveFocus( ( [System.Windows.Input.TraversalRequest]::new( ( [System.Windows.Input.FocusNavigationDirection]::Next ) ) ) )
				}
			}
		}, [System.Windows.Threading.DispatcherPriority]::Send )
	} )
	$syncHash.Jobs.SearchJob.AddArgument( $syncHash )
	$syncHash.Jobs.SearchJob.AddArgument( ( Get-Module | Where-Object { ( Test-Path $_.Path ) -and ( $_.Name -notmatch "^tmpEXO" ) } ) )
	$syncHash.Jobs.SearchJob.AddArgument( $syncHash.Window.DataContext.O365Connected )
	$syncHash.Jobs.SearchJob.Runspace = $syncHash.Jobs.SearchRunspace
	$syncHash.Jobs.SearchJobHandle = $syncHash.Jobs.SearchJob.BeginInvoke()
}

############################################ Script start
$culture = "sv-SE"
$BaseDir = ( Get-Item $PSCommandPath ).Directory.Parent.FullName
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName UIAutomationClient

Get-Module | Where-Object { $_.Path -match "Fetchalon" } | Remove-Module
"ActiveDirectory", ( Get-ChildItem -Path "$BaseDir\Modules\SuiteModules\*" -File ).FullName | `
	ForEach-Object {
		Import-Module -Name $_ -Force -ArgumentList $culture, $true
	}
Show-Splash -Text "" -SelfAdmin
WriteLog -Text "Start" -Success $true | Out-Null

$controls = [System.Collections.ArrayList]::new()
[void] $controls.Add( @{ CName = "BrdAsterixWarning" ; Props = @( @{ PropName = "Visibility"; PropVal = [System.Windows.Visibility]::Collapsed } ) } )
[void] $controls.Add( @{ CName = "BtnEnterFunctionInput" ; Props = @( @{ PropName = "Content" ; PropVal = $msgTable.ContentBtnEnterFunctionInput } ) } )
[void] $controls.Add( @{ CName = "BtnSearch" ; Props = @( @{ PropName = "IsEnabled" ; PropVal = $false } ) } )
[void] $controls.Add( @{ CName = "DgSearchResults" ; Props = @( @{ PropName = "ItemsSource"; PropVal = [System.Collections.ObjectModel.ObservableCollection[object]]::new() } ) } )
[void] $controls.Add( @{ CName = "GridProgress" ; Props = @( @{ PropName = "Visibility"; PropVal = ( [System.Windows.Visibility]::Collapsed ) } ) } )
[void] $controls.Add( @{ CName = "IcOutputObjects" ; Props = @( @{ PropName = "ItemsSource"; PropVal = [System.Collections.ObjectModel.ObservableCollection[object]]::new() } ) } )
[void] $controls.Add( @{ CName = "PbSearchProgress" ; Props = @( @{ PropName = "Visibility"; PropVal = [System.Windows.Visibility]::Collapsed } ) } )
[void] $controls.Add( @{ CName = "TblAsterixWarning" ; Props = @( @{ PropName = "Text" ; PropVal = $msgTable.ContentTblAsterixWarning } ) } )
[void] $controls.Add( @{ CName = "TblFailedSearchMessage" ; Props = @( @{ PropName = "Text" ; PropVal = "" } ) } )
[void] $controls.Add( @{ CName = "TbSearch" ; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )

Update-SplashText -Text $msgTable.StrSplashCreatingWindow
$syncHash = CreateWindowExt -ControlsToBind $controls -IncludeConverters
$Global:syncHash = $syncHash
$syncHash.Data.SettingsPath = Resolve-Path $env:UserProfile\FetchalonSettings.json
$syncHash.Data.msgTable = $msgTable
$syncHash.Data.Culture = [System.Globalization.CultureInfo]::GetCultureInfo( $culture )
$syncHash.Data.BaseDir = $BaseDir
$syncHash.Data.UserGroups = ( Get-ADUser -Identity ( [Environment]::UserName ) -Properties memberof ).memberof | Get-ADGroup | Select-Object -ExpandProperty Name

try
{
	$syncHash.Window.Language = [System.Windows.Markup.XmlLanguage]::GetLanguage( $culture )
}
catch
{
	$syncHash.Window.Language = [System.Windows.Markup.XmlLanguage]::GetLanguage( "sv-se" )
}

GetPropHandlers

# A hash for search texts for testing or default searches
$syncHash.Data.TestSearches = @{
	"TC1" = "C1";
	"TU1" = "U1";
	"TG1" = "G_1";
	"TP1" = "0.0.0.0";
	"TP2" = "P_1";
	"TD1" = "G:\F\F1\";
	"TF1" = "G:\F\F1\F.xls"
}

Update-SplashText -Text $msgTable.StrSplashReadingSettings
ReadSettingsFile

$syncHash.BindData = [pscustomobject]@{
	MsgTable = $msgTable
	O365Connected = $false
	O365AccountStatus = [pscustomobject]@{
						ADCheck = $false
						ADActiveCheck = $false
						ADLockCheck = $false
						ADMailCheck = $false
						ADmsECheck = $false
						OAccountCheck = $false
						OLoginCheck = $false
						OMigCheck = $false
						OLicCheck = $false
						OExchCheck = $false
					}
	SearchedItem = $null
}
$syncHash.Window.DataContext = $syncHash.BindData

Update-SplashText -Text $msgTable.StrSplash2

$syncHash.Jobs.JobErrors = [System.Collections.ArrayList]@{}
$syncHash.Jobs.RunspacesForTools = [System.Collections.ArrayList]::new()
$syncHash.Jobs.SearchRunspace = [runspacefactory]::CreateRunspace()
$syncHash.Jobs.SearchRunspace.ThreadOptions = "ReuseThread"
$syncHash.Jobs.SearchRunspace.Open()

# A runspace to run functions, that can be reused
$syncHash.Jobs.ScriptsRunspace = [runspacefactory]::CreateRunspace()
$syncHash.Jobs.ScriptsRunspace.ThreadOptions = "ReuseThread"
$syncHash.Jobs.ScriptsRunspace.ApartmentState = "STA"
$syncHash.Jobs.ScriptsRunspace.Open()

Update-SplashText -Text $msgTable.StrSplashCreatingHandlers

# Set found object as datacontext for controls
$syncHash.Code.ListItem =
{
	param ( $Object )

	if ( $null -ne ( $Object | Get-Member -Name ObjectClass -ErrorAction SilentlyContinue ) )
	{
		switch ( $Object.ObjectClass )
		{
			"Computer"
			{
				[pscustomobject] $syncHash.Data.SearchedItem = Get-ADComputer $Object.ObjectGUID -Properties * | Select-Object *
				Add-Member -InputObject $syncHash.Data.SearchedItem -MemberType NoteProperty -Name "ExtraInfo" -Value ( @{} )
				$syncHash.Data.SearchedItem.ExtraInfo.Other = [pscustomobject]@{}

				if ( $syncHash.Data.SearchedItem.adminDescription -ne $null )
				{
					Add-Member -InputObject $syncHash.Data.SearchedItem.ExtraInfo.Other -MemberType NoteProperty -Name "adminDescriptionList" -Value ( $syncHash.Data.SearchedItem.adminDescription -split ";" | `
						Where-Object { $_ } | `
						Sort-Object -Descending | `
						ForEach-Object {
							$d = $_ -split ":" ; "$( $d[0] ) - $( try { ( Get-ADUser $d[1] -ErrorAction Stop ).Name } catch { $d[1] } )"
						} )
				}
				Add-Member -InputObject $syncHash.Data.SearchedItem.ExtraInfo.Other -MemberType NoteProperty -Name "IsOnline" -Value "Unknown"
				$syncHash.Data.SearchedItem.MemberOf.Where( { $_ -match $syncHash.Data.msgTable.CodeOrgGrpNamePrefix } )[0] -match $syncHash.Data.msgTable.CodeOrgGrpCaptureRegex | Out-Null
				Add-Member -InputObject $syncHash.Data.SearchedItem.ExtraInfo.Other -MemberType NoteProperty -Name "PCRoll" -Value $Matches.role
				Add-Member -InputObject $syncHash.Data.SearchedItem.ExtraInfo.Other -MemberType NoteProperty -Name "Organisation" -Value $Matches.org
				Add-Member -InputObject $syncHash.Data.SearchedItem.ExtraInfo.Other -MemberType NoteProperty -Name "ProcessList" -Value ( [System.Collections.ArrayList]::new() )
				$syncHash.Data.SearchedItem.ExtraInfo.Other.ProcessList.Add( ( [pscustomobject]@{ $syncHash.Data.msgTable.StrPHComputerOtherProcessListColName = $syncHash.Data.msgTable.StrPropDataNotFetched ; $syncHash.Data.msgTable.StrPHComputerOtherProcessListColId = 0 } ) ) | Out-Null
				break
			}
			"Group"
			{
				[pscustomobject] $syncHash.Data.SearchedItem = Get-ADGroup $Object.ObjectGUID -Properties * | Select-Object *
				Add-Member -InputObject $syncHash.Data.SearchedItem -MemberType NoteProperty -Name "ExtraInfo" -Value ( @{} )
				$syncHash.Data.SearchedItem.ExtraInfo.Other = [pscustomobject]@{}

				if ( $syncHash.Data.SearchedItem."$( $syncHash.Data.msgTable.StrOrgDnPropName )" -ne $null )
				{
					$b = $syncHash.Data.SearchedItem."$( $syncHash.Data.msgTable.StrOrgDnPropName )" -split ",*\w*=" | Where-Object { $_ } | ForEach-Object { "> $( $_ )" }
					[array]::Reverse( $b )
					Add-Member -InputObject $syncHash.Data.SearchedItem.ExtraInfo.Other -MemberType NoteProperty -Name "OrgDn" -Value ( [string] $b ).TrimStart( "> " )
				}
				break
			}
			"PrintQueue"
			{
				[pscustomobject] $syncHash.Data.SearchedItem = $Object | Select-Object *
				Add-Member -InputObject $syncHash.Data.SearchedItem -MemberType NoteProperty -Name "ExtraInfo" -Value ( @{} )
				$syncHash.Data.SearchedItem.ExtraInfo.Other = [pscustomobject]@{}

				if ( $syncHash.Data.SearchedItem.portName -ne $null )
				{
					$syncHash.Data.SearchedItem.portName = ( $syncHash.Data.SearchedItem.portName | Select-Object -First 1 | Sort-Object ).Trim()
				}
				break
			}
			"User"
			{
				[pscustomobject] $syncHash.Data.SearchedItem = Get-ADUser $Object.ObjectGUID -Properties * | Select-Object *
				Add-Member -InputObject $syncHash.Data.SearchedItem -MemberType NoteProperty -Name "ExtraInfo" -Value ( @{} )
				$syncHash.Data.SearchedItem.ExtraInfo.Other = [pscustomobject]@{}

				Add-Member -InputObject $syncHash.Data.SearchedItem.ExtraInfo.Other -MemberType NoteProperty -Name "NeedPasswordChange" -Value ( $syncHash.Data.SearchedItem.PasswordLastSet -lt ( Get-Date "2022-04-29" ) )

				if ( $syncHash.Data.SearchedItem.otherTelephone -ne $null )
				{
					[System.Collections.ArrayList] $syncHash.Data.SearchedItem.otherTelephone = $syncHash.Data.SearchedItem.otherTelephone
				}

				if ( $syncHash.Data.SearchedItem.proxyAddresses -ne $null )
				{
					[System.Collections.ArrayList] $syncHash.Data.SearchedItem.proxyAddresses = $syncHash.Data.SearchedItem.proxyAddresses | Sort-Object
				}

				if ( $syncHash.Data.SearchedItem.LogonWorkstations -ne $null )
				{
					[System.Collections.ArrayList] $syncHash.Data.SearchedItem.LogonWorkstations = @( $syncHash.Data.SearchedItem.LogonWorkstations -split "," | Sort-Object )
				}

				if ( $syncHash.Window.DataContext.O365Connected -eq $true )
				{
					$syncHash.GridO365Status.Visibility = [System.Windows.Visibility]::Visible
					$syncHash.Window.DataContext.O365AccountStatus.ADCheck = $true
					$syncHash.Window.DataContext.O365AccountStatus.ADActiveCheck = $syncHash.Data.SearchedItem.Enabled
					$syncHash.Window.DataContext.O365AccountStatus.ADLockCheck = -not $syncHash.Data.SearchedItem.LockedOut
					$syncHash.Window.DataContext.O365AccountStatus.ADMailCheck = $null -ne $syncHash.Data.SearchedItem.EmailAddress
					$syncHash.Window.DataContext.O365AccountStatus.ADmsECheck = $null -eq $syncHash.Data.SearchedItem.msExchMailboxGuid

					try
					{
						Add-Member -InputObject $syncHash.Data.SearchedItem -MemberType NoteProperty -Name "O365Account" -Value ( Get-AzureADUser -Filter "mail eq '$( $syncHash.Data.SearchedItem.EmailAddress )'" -ErrorAction Stop )
						$syncHash.Window.DataContext.O365AccountStatus.OAccountCheck = $true
						if ( $syncHash.Data.SearchedItem.O365Account.AccountEnabled )
						{
							$syncHash.Window.DataContext.O365AccountStatus.OLoginCheck = $true
						}
						if ( ( $syncHash.Data.SearchedItem.EmailAddress | Get-AzureADUserMembership ).DisplayName -match "O365-MigPilots" )
						{
							$syncHash.Window.DataContext.O365AccountStatus.OMigCheck = $true
						}
						if ( $syncHash.Data.SearchedItem.DistinguishedName -match $syncHash.Data.msgTable.CodeMsExchIgnoreOrg )
						{
							$syncHash.Window.DataContext.O365AccountStatus.OLicCheck = $null
						}
						else
						{
							if ( $syncHash.Data.SearchedItem.O365Account.AssignedLicenses.SkuId -match ( Get-AzureADSubscribedSku | Where-Object { $_.SkuPartNumber -match "EnterprisePack" } ).SkuId )
							{
								$syncHash.Window.DataContext.O365AccountStatus.OLicCheck = $true
							}
							else
							{
								$syncHash.Window.DataContext.O365AccountStatus.OLicCheck = $false
							}
						}

						try
						{
							Get-EXOMailbox -Identity $syncHash.Data.SearchedItem.EmailAddress -ErrorAction Stop
							$syncHash.Window.DataContext.O365AccountStatus.OExchCheck = $true
						}
						catch
						{
							$syncHash.Window.DataContext.O365AccountStatus.OExchCheck = $false
						}
					}
					catch {}
					$syncHash.GridO365Status.Children | `
						Where-Object { $_ -is [System.Windows.Shapes.Ellipse] } | `
						ForEach-Object {
							if ( $null -eq $syncHash.Window.DataContext.O365AccountStatus."$( $_.Name -replace "ElUser" )" )
							{
								$_.Fill = "LightGray"
							}
							elseif ( $syncHash.Window.DataContext.O365AccountStatus."$( $_.Name -replace "ElUser" )" )
							{
								$_.Fill = "LightGreen"
							}
						}
				}
				break
			}
			"DirectoryInfo"
			{
				[pscustomobject] $syncHash.Data.SearchedItem = Get-Item $Object | Select-Object *
				Add-Member -InputObject $syncHash.Data.SearchedItem -MemberType NoteProperty -Name "ObjectClass" -Value ( $Object.ObjectClass )
				Add-Member -InputObject $syncHash.Data.SearchedItem -MemberType NoteProperty -Name "ExtraInfo" -Value ( @{} )
				$syncHash.Data.SearchedItem.ExtraInfo.Other = [pscustomobject]@{}

				Add-Member -InputObject $syncHash.Data.SearchedItem.ExtraInfo.Other -MemberType NoteProperty -Name "DirectoryList" -Value ( [System.Collections.ArrayList]::new() )
				Add-Member -InputObject $syncHash.Data.SearchedItem.ExtraInfo.Other -MemberType NoteProperty -Name "DirectoryInventory" -Value ""

				Get-ChildItem2 $syncHash.Data.SearchedItem.FullName | ForEach-Object { [void] $syncHash.Data.SearchedItem.ExtraInfo.Other.DirectoryList.Add( ( [pscustomobject]@{ Name = $_.Name ; Type = $_.GetType().Name ; Item = $_ } ) ) }

				$syncHash.Data.SearchedItem.ExtraInfo.Other.DirectoryInventory = "$( $syncHash.Data.SearchedItem.ExtraInfo.Other.DirectoryList.Count ) $( $syncHash.Data.msgTable.StrDirItemsCount )`n$( ( $syncHash.Data.SearchedItem.ExtraInfo.Other.DirectoryList.Type -match "DirectoryInfo" ).Count ) $( $syncHash.Data.msgTable.StrDirFolderCount ), $( ( $syncHash.Data.SearchedItem.ExtraInfo.Other.DirectoryList.Type -match "DirectoryInfo" ).Count ) $( $syncHash.Data.msgTable.StrDirFileCount ) "
				break
			}
			"FileInfo"
			{
				[pscustomobject] $syncHash.Data.SearchedItem = Get-Item $Object | Select-Object *
				Add-Member -InputObject $syncHash.Data.SearchedItem -MemberType NoteProperty -Name "ObjectClass" -Value ( $Object.ObjectClass )
				Add-Member -InputObject $syncHash.Data.SearchedItem -MemberType NoteProperty -Name "ExtraInfo" -Value ( @{} )
				$syncHash.Data.SearchedItem.ExtraInfo.Other = [pscustomobject]@{}

				Add-Member -InputObject $syncHash.Data.SearchedItem.ExtraInfo.Other -MemberType NoteProperty -Name "DataStreams" -Value ( [System.Collections.ArrayList]::new() )
				Add-Member -InputObject $syncHash.Data.SearchedItem.ExtraInfo.Other -MemberType NoteProperty -Name "FileSize" -Value ""
				try
				{
					Add-Member -InputObject $syncHash.Data.SearchedItem.ExtraInfo.Other -MemberType NoteProperty -Name "Extension" -Value "$( $Object.Extension ) ($( ( Get-ItemProperty "Registry::HKEY_Classes_root\$( ( Get-ItemProperty "Registry::HKEY_Classes_root\$( $Object.Extension )" -ErrorAction Stop )."(default)" )")."(default)" ))"
				}
				catch
				{
					Add-Member -InputObject $syncHash.Data.SearchedItem.ExtraInfo.Other -MemberType NoteProperty -Name "Extension" -Value "$( $Object.Extension )"
				}
				Add-Member -InputObject $syncHash.Data.SearchedItem.ExtraInfo.Other -MemberType NoteProperty -Name "FileVersionInfo" -Value ( [System.Collections.ArrayList]::new() )

				$syncHash.Data.SearchedItem.ExtraInfo.Other.FileSize = if ( $Object.Length -lt 1kB ) { "$( $Object.Length ) B" }
					elseif ( $Object.Length -gt 1kB -and $Object.Length -lt 1MB ) { "$( [math]::Round( ( $Object.Length / 1kB ), 2 ) ) kB" }
					elseif ( $Object.Length -gt 1MB -and $Object.Length -lt 1GB ) { "$( [math]::Round( ( $Object.Length / 1MB ), 2 ) ) MB" }
					elseif ( $Object.Length -gt 1GB -and $Object.Length -lt 1TB ) { "$( [math]::Round( ( $Object.Length / 1GB ), 2 ) ) GB" }

				Get-Item $syncHash.Data.SearchedItem.FullName -Stream * | `
					ForEach-Object {
						[pscustomobject]@{
							Name = $_.Stream
							Size = if ( $_.Length -lt 1kB ) { "$( $_.Length ) B" }
								elseif ( $_.Length -gt 1kB -and $_.Length -lt 1MB ) { "$( [math]::Round( ( $_.Length / 1kB ), 2 ) ) kB" }
								elseif ( $_.Length -gt 1MB -and $_.Length -lt 1GB ) { "$( [math]::Round( ( $_.Length / 1MB ), 2 ) ) MB" }
								elseif ( $_.Length -gt 1GB -and $_.Length -lt 1TB ) { "$( [math]::Round( ( $_.Length / 1GB ), 2 ) ) GB" } }
					} | ForEach-Object { [void] $syncHash.Data.SearchedItem.ExtraInfo.Other.DataStreams.Add( $_ ) }

				$syncHash.Data.SearchedItem.VersionInfo | Get-Member -MemberType Property | ForEach-Object { [void] $syncHash.Data.SearchedItem.ExtraInfo.Other.FileVersionInfo.Add( ( [pscustomobject]@{ "Name" = $_.Name ; "Value" = $syncHash.Data.SearchedItem.VersionInfo."$( $_.Name )" } ) ) }
				break
			}
			"O365User"
			{
				[pscustomobject] $syncHash.Data.SearchedItem = $Object | Select-Object *
				Add-Member -InputObject $syncHash.Data.SearchedItem -MemberType NoteProperty -Name "ExtraInfo" -Value ( @{} )
				$syncHash.Data.SearchedItem.ExtraInfo.Other = [pscustomobject]@{}
				[System.Collections.ArrayList]$syncHash.Data.SearchedItem.EmailAddresses = $syncHash.Data.SearchedItem.EmailAddresses
				break
			}
			"O365SharedMailbox"
			{
				[pscustomobject] $syncHash.Data.SearchedItem = $Object | Select-Object *
				Add-Member -InputObject $syncHash.Data.SearchedItem -MemberType NoteProperty -Name "ExtraInfo" -Value ( @{} )
				$syncHash.Data.SearchedItem.ExtraInfo.Other = [pscustomobject]@{}
				[System.Collections.ArrayList]$syncHash.Data.SearchedItem.EmailAddresses = $syncHash.Data.SearchedItem.EmailAddresses
				break
			}
			"O365Resource"
			{
				[pscustomobject] $syncHash.Data.SearchedItem = $Object | Select-Object *
				Add-Member -InputObject $syncHash.Data.SearchedItem -MemberType NoteProperty -Name "ExtraInfo" -Value ( @{} )
				$syncHash.Data.SearchedItem.ExtraInfo.Other = [pscustomobject]@{}
				[System.Collections.ArrayList]$syncHash.Data.SearchedItem.EmailAddresses = $syncHash.Data.SearchedItem.EmailAddresses
				break
			}
			"O365Room"
			{
				[pscustomobject] $syncHash.Data.SearchedItem = $Object | Select-Object *
				Add-Member -InputObject $syncHash.Data.SearchedItem -MemberType NoteProperty -Name "ExtraInfo" -Value ( @{} )
				$syncHash.Data.SearchedItem.ExtraInfo.Other = [pscustomobject]@{}
				[System.Collections.ArrayList]$syncHash.Data.SearchedItem.EmailAddresses = $syncHash.Data.SearchedItem.EmailAddresses
				break
			}
			"O365Distributionlist"
			{
				[pscustomobject] $syncHash.Data.SearchedItem = $Object | Select-Object *
				Add-Member -InputObject $syncHash.Data.SearchedItem -MemberType NoteProperty -Name "ExtraInfo" -Value ( @{} )
				$syncHash.Data.SearchedItem.ExtraInfo.Other = [pscustomobject]@{}
				[System.Collections.ArrayList]$syncHash.Data.SearchedItem.EmailAddresses = $syncHash.Data.SearchedItem.EmailAddresses
				break
			}
			default
			{
				[pscustomobject] $syncHash.Data.SearchedItem = $syncHash.DgSearchResults.SelectedItem | Select-Object *
			}
		}

		if ( $syncHash.Data.SearchedItem.ObjectClass -match "(Directory)|(File)Info" )
		{
			Add-Member -InputObject $syncHash.Data.SearchedItem.ExtraInfo.Other -MemberType NoteProperty -Name "ADGroups" -Value ( [System.Collections.ArrayList]::new() )
			Add-Member -InputObject $syncHash.Data.SearchedItem.ExtraInfo.Other -MemberType NoteProperty -Name "ReadPermissions" -Value ( [System.Collections.ArrayList]::new() )
			Add-Member -InputObject $syncHash.Data.SearchedItem.ExtraInfo.Other -MemberType NoteProperty -Name "WritePermissions" -Value ( [System.Collections.ArrayList]::new() )

			$acl = Get-Acl $syncHash.Data.SearchedItem.FullName
			( $acl.Access | Where-Object { $_.IdentityReference -match $syncHash.Data.msgTable.CodeRegExAclIdentity } ).IdentityReference | `
				Select-Object -Unique | `
				ForEach-Object {
					$PermType = if ( $_ -match "C$" )
					{ "C" }
					else
					{ "R" }
					Get-ADGroup ( $_ -split "\\" )[1]  | `
						Get-ADGroupMember | `
							ForEach-Object {
								if ( "group" -eq $_.ObjectClass )
								{
									[void] $syncHash.Data.SearchedItem.ExtraInfo.Other.ADGroups.Add( $_.Name )

									if ( $_.Name -match "C$" )
									{
										Get-ADGroupMember $_.SamAccountName | `
											Sort-Object Name | `
											ForEach-Object { $syncHash.Data.SearchedItem.ExtraInfo.Other.WritePermissions.Add( $_.DistinguishedName ) | Out-Null }

										try
										{
											Add-Member -InputObject $syncHash.Data.SearchedItem.ExtraInfo.Other -MemberType NoteProperty -Name "ADOwner" -Value ( ( Get-ADUser ( Get-ADGroup $_.DistinguishedName -Properties managedBy ).managedBy ).Name )
										}
										catch
										{
											Add-Member -InputObject $syncHash.Data.SearchedItem.ExtraInfo.Other -MemberType NoteProperty -Name "ADOwner" -Value $syncHash.Data.msgTable.StrNoOwner
										}

									}
									else
									{
										Get-ADGroupMember $_.SamAccountName | `
											Sort-Object Name | `
											ForEach-Object { $syncHash.Data.SearchedItem.ExtraInfo.Other.ReadPermissions.Add( $_.DistinguishedName ) | Out-Null }
									}
								}
								elseif ( "user" -eq $_.ObjectClass )
								{
									if ( "C" -eq $PermType )
									{
										$syncHash.Data.SearchedItem.ExtraInfo.Other.WritePermissions.Add( $_.DistinguishedName ) | Out-Null
									}
									elseif ( "R" -eq $PermType )
									{
										$syncHash.Data.SearchedItem.ExtraInfo.Other.ReadPermissions.Add( $_.DistinguishedName ) | Out-Null
									}
								}
							}
				}

			if ( 0 -eq $syncHash.Data.SearchedItem.ExtraInfo.Other.ADGroups.Count )
			{
				$syncHash.Data.SearchedItem.ExtraInfo.Other.ADGroups.Add( $syncHash.Data.msgTable.ContentNoMembersOfList ) | Out-Null
			}
			if ( 0 -eq $syncHash.Data.SearchedItem.ExtraInfo.Other.WritePermissions.Count )
			{
				$syncHash.Data.SearchedItem.ExtraInfo.Other.WritePermissions.Add( $syncHash.Data.msgTable.ContentNoMembersOfList ) | Out-Null
			}
			if ( 0 -eq $syncHash.Data.SearchedItem.ExtraInfo.Other.ReadPermissions.Count )
			{
				$syncHash.Data.SearchedItem.ExtraInfo.Other.ReadPermissions.Add( $syncHash.Data.msgTable.ContentNoMembersOfList ) | Out-Null
			}
		}

		if ( $syncHash.Data.SearchedItem.MemberOf -match $syncHash.Data.msgTable.StrGrpNameSharedCompName )
		{
			Add-Member -InputObject $syncHash.Data.SearchedItem.ExtraInfo.Other -MemberType NoteProperty -Name "SharedAccount" -Value "?"
			Add-Member -InputObject $syncHash.Data.SearchedItem.ExtraInfo.Other -MemberType NoteProperty -Name "SharedAccountAvailable" -Value $true
		}

		if ( $syncHash.Data.SearchedItem."$( $syncHash.Data.msgTable.StrIdPropName )" -ne $null )
		{
			Add-Member -InputObject $syncHash.Data.SearchedItem -MemberType NoteProperty -Name Identity -Value $syncHash.Data.SearchedItem."$( $syncHash.Data.msgTable.StrIdPropName )" -Force
		}

		Invoke-Command $syncHash.Code.ListProperties -ArgumentList $false

		if ( $syncHash.Data.SearchedItem.ObjectClass -in "user", "computer", "printQueue" )
		{
			$syncHash.GridExtraInfo.Visibility = [System.Windows.Visibility]::Visible
			if ( "computer" -eq $syncHash.Data.SearchedItem.ObjectClass )
			{
				$syncHash.SpComputerOnlineStatus.Visibility = [System.Windows.Visibility]::Visible
			}
			else
			{
				$syncHash.SpComputerOnlineStatus.Visibility = [System.Windows.Visibility]::Collapsed
			}
			# Make checkboxes for extrainfo for appropriated objectclass, visible
			$syncHash.WpSearchFromBoxes.Children | `
				ForEach-Object `
					-Begin { $c = 0 } `
					-Process {
						if ( 0 -eq $c )
						{
							$_.Visibility = [System.Windows.Visibility]::Visible
						}
						else
						{
							if ( $_.Name -match $syncHash.Data.SearchedItem.ObjectClass )
							{
								$_.Visibility = [System.Windows.Visibility]::Visible
							}
							else
							{
								$_.Visibility = [System.Windows.Visibility]::Collapsed
							}
						}

						$c += 1
					}
		}
		else
		{
			$syncHash.GridExtraInfo.Visibility = [System.Windows.Visibility]::Hidden
		}

		$syncHash.Window.DataContext.SearchedItem = $syncHash.Data.SearchedItem
		$syncHash.MenuObject.IsEnabled = $true
		$syncHash.TblObjName.GetBindingExpression( [System.Windows.Controls.TextBlock]::TextProperty ).UpdateTarget()
		$syncHash.Window.Resources.GetEnumerator() | Where-Object { $_.Key -match "Cvs.*" } | ForEach-Object { $_.Value.View.Refresh() }
	}
	# An PS Get-CmdLet was run
	else
	{
		if ( $Object -is [System.Management.Automation.ErrorRecord] )
		{
			$RunError = $Object
		}
		else
		{
			$PsCmdLetData = $Object | Format-Table | Out-String
		}
		$ScriptObject = [pscustomobject]@{ OutputType = "String"; Name = $syncHash.Data.msgTable.StrPsGetCmdlet }
		$Info = [pscustomobject]@{ Finished = Get-Date ; Data = $PsCmdLetData ; Script = $ScriptObject ; Error = $RunError ; Item = $null ; OutputType = "String" }
		$syncHash.Window.Resources['CvsMiOutputHistory'].Source.Add( $Info )
	}
	$syncHash.PopupMenu.IsOpen = $false
}

# Display extra info that was fetched
$syncHash.Code.ListExtraInfo =
{
	param ( $Exclude )

	if ( $Exclude.Count -gt 0 )
	{ $ExtraInfo = $syncHash.Data.SearchedItem.ExtraInfo.GetEnumerator() | Where-Object { $_.Name -notin $Exclude } }
	else
	{ $ExtraInfo = $syncHash.Data.SearchedItem.ExtraInfo.GetEnumerator() }

	foreach ( $info in $ExtraInfo )
	{
		$info.Value | Get-Member -MemberType NoteProperty | ForEach-Object {
			$p = $_
			try
			{
				$Prop = [pscustomobject]@{
						Name = $p.Name
						Value = $syncHash.Data.SearchedItem.ExtraInfo."$( $info.Name )"."$( $p.Name )"
						Type = $syncHash.Data.SearchedItem.ExtraInfo."$( $info.Name )"."$( $p.Name )".GetType().Name
						CheckedForVisible = ( $syncHash.Data.UserSettings.VisibleProperties."$( $syncHash.Data.SearchedItem.ObjectClass )".Name -contains $p.Name )
						Source = $info.Name
					}
				if ( $Prop.Source -eq $syncHash.Code.PropHandlers."$( $syncHash.Data.SearchedItem.ObjectClass )"."$( $Prop.Name )".Value.MandatorySource )
				{
					Add-Member -InputObject $Prop -MemberType NoteProperty -Name "Handler" -Value $syncHash.Code.PropHandlers."$( syncHash.Data.SearchedItem.ObjectClass )"."( $Prop.Name )"
				}

				if ( "ADPropertyValueCollection" -eq $Prop.Type -or $Prop.Value -is [array] )
				{
					[System.Collections.ArrayList] $Prop.Value = $v
					$Prop.Type = "ArrayList"
				}

				if ( $Prop.Type -eq "ArrayList" )
				{
					if ( "pscustomobject" -eq $Prop.Value[0].GetType().Name )
					{
						$Prop.Type = "ObjectList"
					}

					if ( $Prop.Value.Count -eq 0 )
					{
						[void] $Prop.Value.Add( $syncHash.Data.msgTable.StrNoScriptOutput )
					}
				}
			} catch {}
		}
	}
	Invoke-Command $syncHash.Code.ListProperties -ArgumentList ( "Visible" -eq $syncHash.IcObjectDetailed.Visibility )
}

# Get properties to display and enter into IcPropsList
$syncHash.Code.ListProperties =
{
	param ( $Detailed )

	$syncHash.Data.SearchedItem, $syncHash.Data.SearchedItem.ExtraInfo.Keys | `
		ForEach-Object `
			-Begin {
				$c = 0
				$OtherObjectClass = ( ( Get-Member -InputObject $syncHash.Data.UserSettings.VisibleProperties -MemberType NoteProperty ).Name -notcontains $syncHash.Data.SearchedItem.ObjectClass )
				$syncHash.Window.Resources['CvsDetailedProps'].Source.Clear()
				$syncHash.Window.Resources['CvsPropsList'].Source.Clear()
			} `
			-Process {
				if ( 0 -eq $c )
				{
					( Get-Member -InputObject $_ -MemberType NoteProperty ).Name | `
						Where-Object { $_ } | `
						Where-Object { $_ -notmatch "(ExtraInfo)|(Propert(y)|(ies))" -and $_ -notmatch "^PS" } | `
						ForEach-Object {
							$Key = $_
							if (
								$syncHash.Data.UserSettings.VisibleProperties."$( $syncHash.Data.SearchedItem.ObjectClass )".Where( { $_.MandatorySource -match "(AD)|(Exchange)" -and $_.Name -eq $Key } ) -or `
								$OtherObjectClass -or `
								$Detailed
							)
							{
								if ( $syncHash.Data.SearchedItem.ObjectClass -match "^O365((SharedMailbox)|(Room)|(Resource)|(Distributionlist)|(User))" )
								{
									[pscustomobject]@{ Name = $Key ; Value = $syncHash.Data.SearchedItem."$( $Key )" ; Source = "Exchange" }
								}
								else
								{
									[pscustomobject]@{ Name = $Key ; Value = $syncHash.Data.SearchedItem."$( $Key )" ; Source = "AD" }
								}
							}
						}
				}
				else
				{
					$_ | ForEach-Object {
						$Source = $_
						( Get-Member -InputObject $syncHash.Data.SearchedItem.ExtraInfo.$Source -MemberType NoteProperty ).Name | `
							Where-Object { $_ } | `
							Where-Object { $_ -notmatch "(ExtraInfo)|(Propert(y)|(ies))" -and $_ -notmatch "^PS" } | `
							ForEach-Object {
								$Key = $_
								if ( $syncHash.Data.UserSettings.VisibleProperties."$( $syncHash.Data.SearchedItem.ObjectClass )".Where( { $_.MandatorySource -eq $Source -and $_.Name -eq $Key } ) -or `
									$OtherObjectClass -or `
									$Detailed
								)
								{
									[pscustomobject]@{ Name = $Key ; Value = $syncHash.Data.SearchedItem.ExtraInfo."$( $Source )"."$( $Key )" ; Source = $Source }
								}
							}
						}
				}
				$c += 1
			} | `
				ForEach-Object {
					$Prop = $_
					if ( $null -eq $Prop.Value )
					{
						Add-Member -InputObject $Prop -MemberType NoteProperty -Name "Value" -Value ( "NULL" ) -Force
					}
					elseif (
						$Prop.Value -is [array] -or `
						$Prop.Value -is [System.Collections.ArrayList]
					)
					{
						if ( $Prop.Value.Count -eq 0 )
						{
							$Prop.Value += $syncHash.Data.msgTable.StrNoScriptOutput
							Add-Member -InputObject $Prop -MemberType NoteProperty -Name "Type" -Value "String"
						}
						elseif ( $Prop.Value[0] -is [string] )
						{
							Add-Member -InputObject $Prop -MemberType NoteProperty -Name "Type" -Value "ArrayList"
						}
						elseif ( "pscustomobject" -eq $Prop.Value[0].GetType().Name )
						{
							Add-Member -InputObject $Prop -MemberType NoteProperty -Name "Type" -Value "ObjectList"
						}
					}
					elseif ( $Prop.Value -is [pscustomobject] )
					{
						$t = $Prop.Value
						$Prop.Value = [System.Collections.ArrayList]::new()
						$Prop.Value.Add( $t ) | Out-Null
						Add-Member -InputObject $Prop -MemberType NoteProperty -Name "Type" -Value "ObjectList"
					}
					else
					{
						Add-Member -InputObject $Prop -MemberType NoteProperty -Name "Type" -Value ( $Prop.Value.GetType().Name )
					}

					if ( $Prop.Type -eq "Int64" )
					{
						if ( 9223372036854775807 -eq $Prop.Value )
						{
							if ( $syncHash.Data.SearchedItem.ObjectClass -eq "user" )
							{
								$Prop.Value = $syncHash.Data.msgTable.StrAccountNeverExpires
							}
						}
						else
						{
							$Prop.Value = Get-Date ( [datetime]::FromFileTime( $Prop.Value ) ) -Format "u"
						}
					}
					elseif ( "ADPropertyValueCollection" -eq $Prop.Type )
					{
						[System.Collections.ArrayList] $Prop.Value = $Prop.Value
						$Prop.Type = "ArrayList"
					}

					if ( $syncHash.Code.PropHandlers."$( $syncHash.Data.SearchedItem.ObjectClass )".Keys -contains "PH$( $syncHash.Data.SearchedItem.ObjectClass )$( $Prop.Source )$( $Prop.Name )" )
					{
						Add-Member -InputObject $Prop -MemberType NoteProperty -Name "Handler" -Value $syncHash.Code.PropHandlers."$( $syncHash.Data.SearchedItem.ObjectClass )"."PH$( $syncHash.Data.SearchedItem.ObjectClass )$( $Prop.Source )$( $Prop.Name )"
					}
					Add-Member -InputObject $Prop -MemberType NoteProperty -Name "CheckedForVisible" -Value ( $syncHash.Data.UserSettings.VisibleProperties."$( $syncHash.Data.SearchedItem.ObjectClass )".Name -contains $Prop.Name )

					if ( $Detailed )
					{
						$syncHash.Window.Resources['CvsDetailedProps'].Source.Add( $Prop )
					}
					if ( $syncHash.Data.UserSettings.VisibleProperties."$( $syncHash.Data.SearchedItem.ObjectClass )".Where( { $_.MandatorySource -eq $Prop.Source -and $_.Name -eq $Prop.Name } ) -or `
						$OtherObjectClass )
					{
						$syncHash.Window.Resources['CvsPropsList'].Source.Add( $Prop )
					}
				}
}

Update-SplashText -Text $msgTable."StrSplashJoke$( Get-Random -Minimum 1 -Maximum ( $syncHash.Data.msgTable.Keys.Where( { $_ -match "Joke" } ).Count ) )"

# Eventhandler to copy function output
[System.Windows.RoutedEventHandler] $syncHash.Code.CopyOutputData =
{
	param ( $SenderObject, $e )

	if ( $null -eq $SenderObject.DataContext.Data )
	{
		$syncHash.Data.msgTable.StrNoScriptOutput | clip
	}
	else
	{
		$SenderObject.DataContext.Data | clip
	}
}

# Handler for when a propscript is to be run
[System.Windows.RoutedEventHandler] $syncHash.Code.RunPropHandler =
{
	param ( $SenderObject, $e )

	WriteLog -Text "$( $syncHash.Data.msgTable.LogStrPropHandlerRun ): $( $syncHash.Data.SearchedItem.ObjectClass )::$( $SenderObject.DataContext.Name )::$( $SenderObject.DataContext.Source )" -Success $true
	. ( [scriptblock]::Create( $SenderObject.DataContext.Handler.Code ) )
}

# Eventhandler to copy function output
[System.Windows.RoutedEventHandler] $syncHash.Code.CopyOutputObject =
{
	param ( $SenderObject, $e )

	if ( $SenderObject.DataContext.OutputType -eq "ObjectList" )
	{ $Parameters = ( $SenderObject.Parent.DataContext.Data | Get-Member -MemberType NoteProperty ).Name }

	if ( $null -ne $SenderObject.DataContext.Item -and "None" -ne $SenderObject.DataContext.Script.SearchedItemRequest )
	{ $Item = " $( $syncHash.Data.msgTable.StrCopyOutputForAdObject ) '$( $SenderObject.DataContext.Item.Name )'" }

	if ( $null -ne $SenderObject.DataContext.Script.Synopsis )
	{ $Synopsis = "`n$( $syncHash.Data.msgTable.StrCopyOutputSynopsis ): $( $SenderObject.DataContext.Script.Synopsis )" }

	if ( $_.Script.InputData )
	{ $InputData = "$( $syncHash.Data.msgTable.StrCopyOutputEnteredInput ):`n$( $SenderObject.DataContext.Script.InputData | ForEach-Object { "$( $_.Name ): $( $_.EnteredValue )`n" } )" }
	else
	{ $InputData = "" }

	$SenderObject.Parent.DataContext | ForEach-Object {
@"
$( $syncHash.Data.msgTable.StrCopyOutputMessageP1 )$Item $( $syncHash.Data.msgTable.StrCopyOutputMessageP2 ) "$( $_.Script.Name )" $Synopsis
$InputData
$( $syncHash.Data.msgTable.StrCopyOutputMessagePTime ): $( Get-Date $SenderObject.DataContext.Finished -Format $syncHash.Window.Resources['StrFullDateTimeFormat'] )

Utdata:
$(
	if ( $null -eq $_.Data )
	{
		$syncHash.Data.msgTable.StrNoScriptOutput
	}
	else
	{
		if ( $_.OutputType -eq "ObjectList" )
		{
			$_.Data | ForEach-Object {
				$o = $_
				$Parameters | ForEach-Object {
					"$( $_ ): $( $o.$_ )`n"
				}
				"`n"
			}
		}
		elseif ( $_.OutputType -eq "List" )
		{
			$_.Data | ForEach-Object { "$_`n" }
		}
		else
		{
			$_.Data
		}
	}
)
"@
	} | clip
}

# WPF EventSetter handler to copy property value
[System.Windows.RoutedEventHandler] $syncHash.Code.CopyProperty =
{
	param ( $SenderObject, $e )

	Set-Clipboard -Value $SenderObject.Parent.DataContext.Value
	Show-Splash -Text $syncHash.Data.msgTable.StrPropertyCopied -NoTitle -NoProgressBar
}

# WPF EventSetter handler to disable BringIntoView for datagridrow
[System.Windows.RequestBringIntoViewEventHandler] $syncHash.Code.DataGridRowDisableBringIntoView =
{
	param ( $SenderObject, $e )

	$e.Handled = $true
}

# TextBox for function input is loaded, check if it is the first one, if so, set focus
[System.Windows.RoutedEventHandler] $syncHash.Code.InputTextBoxLoaded =
{
	param ( $SenderObject, $e )

	if ( $syncHash.IcFunctionInput.DataContext.InputData[0].Name -eq $SenderObject.DataContext.Name )
	{
		$SenderObject.Focus()
	}
}

# Open a hyperlink
[System.Windows.Input.MouseButtonEventHandler] $syncHash.Code.HyperLinkClick =
{
	param ( $SenderObject, $e )

	[System.Diagnostics.Process]::Start( "chrome", $SenderObject.DataContext.Address )
}

# Show data from previous output
[System.Windows.RoutedEventHandler] $syncHash.Code.ShowOutputItem =
{
	param ( $SenderObject, $e )

	DisplayView -ViewName "FrameTool"
	$syncHash.FrameTool.Navigate( $syncHash.Window.Resources['MainOutput'] )

	$syncHash.DC.IcOutputObjects[0].Clear()
	$syncHash.DC.IcOutputObjects[0].Insert( 0, $SenderObject.DataContext )
}

# Menuitem was clicked, start tool or run function
[System.Windows.RoutedEventHandler] $syncHash.Code.MenuItemClick =
{
	param ( $SenderObject, $e )

	DisplayView -ViewName "FrameTool"

	# Menuitem represents a tool
	if ( ( $SenderObject.DataContext | Get-Member -MemberType NoteProperty ).Name -match "^PS$" )
	{
		# The tool has Xaml to be shown in main window
		if ( $SenderObject.DataContext.Separate -eq $false )
		{
			$name = $SenderObject.DataContext.Name -replace "\W"
			if ( -not $syncHash.Window.Resources.Contains( $name ) )
			{
				try
				{
					$page = CreatePage -FilePath $SenderObject.DataContext.Xaml
					$page.Data.msgTable = Import-LocalizedData -BaseDirectory $SenderObject.DataContext.Localization.Directory.FullName -FileName $SenderObject.DataContext.Localization.Name
					$page.Data.Modules = Get-Module
					$page.Page.DataContext = [pscustomobject]@{
						MsgTable = $page.Data.msgTable
					}
					$SenderObject.DataContext.PageObject = $page
					$syncHash.Window.Resources.Add( $name , $page.Page )

					Import-Module $SenderObject.DataContext.PS -ArgumentList $page -Force

					if ( $SenderObject.DataContext.Name -eq "Send-Feedback" )
					{
						if ( $null -eq $syncHash.Window.Resources[$name].Resources['CvsFunctions'].Source )
						{
							$syncHash.Window.Resources[$name].Resources['CvsFunctions'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
							$syncHash.Window.Resources.GetEnumerator() | `
								Where-Object { $_.Name -match "CvsMi.*((Functions)|(Tools)|(About))" } | `
								ForEach-Object { $_.Value.Source } | `
								Where-Object { $_.Name -notmatch "Temp" } | `
								Select-Object -Property @{ Name="Name" ; Expression = { $_.Name.Trim() } }, @{ Name="Author" ; Expression = { $_.Author.Trim() } }, @{ Name="Description" ; Expression = { $_.Description.Trim() } } | `
								ForEach-Object { $_; $syncHash.Window.Resources[$name].Resources['CvsFunctions'].Source.Add( $_ ) }
						}
					}
				}
				catch
				{
					if ( "NotPage" -eq $_.Exception.Message )
					{
						Show-MessageBox -Text $syncHash.Data.msgTable.ErrToolGuiNotPage
					}
					else
					{
						Show-MessageBox -Text $_
					}
				}
			}

			# Copy SearchedItem to page resource
			if ( $SenderObject.DataContext.ObjectOperations -eq $syncHash.Data.SearchedItem.ObjectClass )
			{
				$syncHash.Window.Resources[$name].Resources['SearchedItem'] = $syncHash.Data.SearchedItem
			}

			$syncHash.FrameTool.Navigate( $syncHash.Window.Resources[$name] )
		}
		# The tool is handling its GUI by itself, in separate window
		else
		{
			try
			{
				# The tool has previously not been opened
				if ( $null -eq $SenderObject.DataContext.Process )
				{
					OpenTool $SenderObject
				}
				# The tool has been opened, display that window
				else
				{
					Add-Type -Namespace GuiNative -Name Win -MemberDefinition '[DllImport("user32.dll")] public static extern bool ShowWindow(int handle, int state);'
					[GuiNative.Win]::ShowWindow( ( ( $syncHash.MiTools.Items | Where-Object { $_.Ps -eq $SenderObject.DataContext.Ps } ).Process.MainWindowHandle.ToInt32() ), 2 )
					[GuiNative.Win]::ShowWindow( ( ( $syncHash.MiTools.Items | Where-Object { $_.Ps -eq $SenderObject.DataContext.Ps } ).Process.MainWindowHandle.ToInt32() ), 9 )
				}
			}
			# Some error occured, start the tool-script
			catch
			{
				OpenTool $SenderObject
			}
		}
	}
	# The menuitem represents a function
	# This does not have its own UI and will be displayed in main window when finished
	else
	{
		if ( "None" -ne $SenderObject.DataContext.OutputType )
		{
			$syncHash.DC.IcOutputObjects[0].Clear()
			$syncHash.FrameTool.Navigate( $syncHash.Window.Resources['MainOutput'] )
		}

		if ( $SenderObject.DataContext.InputData.Count -gt 0 )
		{
			$SenderObject.DataContext.InputData | ForEach-Object { $_.EnteredValue = "" }
			$syncHash.GridFunctionOp.DataContext = $SenderObject.DataContext
		}
		PrepareToRunScript $SenderObject.DataContext
	}
}

# Start a O365-script
[System.Windows.RoutedEventHandler] $syncHash.Code.O365Click =
{
	param ( $SenderObject, $e )
}

# View file/directory object in directorylist
[System.Windows.RoutedEventHandler] $syncHash.Code.ViewFileDir =
{
	param ( $SenderObject, $e )

	$syncHash.DC.TbSearch[0] = $SenderObject.DataContext.Item.FullName
	StartSearch
}

# Code for running a function and display its output
$syncHash.Code.SBlockExecuteFunction = {
	param ( $syncHash, $ScriptObject, $Modules, $ItemToSend, $InputData )

	$Error.Clear()
	Add-Type -AssemblyName PresentationFramework
	Import-Module $Modules -Force
	$syncHash.DC.GridProgress[0] = [System.Windows.Visibility]::Visible

	$Info = [pscustomobject]@{ Finished = $null ; Data = $null ; Script = $ScriptObject ; Error = [System.Collections.ArrayList]::new() ; Item = $ItemToSend ; OutputType = $ScriptObject.OutputType }

	try
	{
		if ( $null -ne $InputData )
		{
			if ( "None" -eq $ScriptObject.SearchedItemRequest )
			{
				$ScriptOutput = . $ScriptObject.Name $InputData
			}
			else
			{
				if ( $ScriptObject.ObjectClass -eq $syncHash.Data.SearchedItem.ObjectClass )
				{
					$ScriptOutput = . $ScriptObject.Name $null $InputData
				}
				else
				{
					$ScriptOutput = . $ScriptObject.Name $syncHash.Data.SearchedItem $InputData
				}
			}
		}
		else
		{
			if ( "None" -eq $ScriptObject.SearchedItemRequest )
			{
				$ScriptOutput = . $ScriptObject.Name
			}
			else
			{
				if ( $ScriptObject.ObjectClass -eq $syncHash.Data.SearchedItem.ObjectClass )
				{
					$ScriptOutput = . $ScriptObject.Name $syncHash.Data.SearchedItem
				}
				else
				{
					$ScriptOutput = . $ScriptObject.Name $null
				}
			}
		}
		$Info.Data = $ScriptOutput

		if ( $null -eq $Info.Data )
		{
			$Info.OutputType = "String"
		}
		elseif ( $Info.Data -is [pscustomobject] )
		{
			<#if ( "List","ObjectList" -contains $Info.OutputType )
			{
				$temp = [System.Collections.ArrayList]::new()
				$temp.Add( $Info.Data ) | Out-Null
				$Info.Data = $temp
			}
			else
			{#>
				$Info.Data | Get-Member -MemberType NoteProperty | `
					ForEach-Object `
						-Begin { $l = [System.Collections.ArrayList]::new() } `
						-Process { $l.Add( ( [pscustomobject]@{ $syncHash.Data.msgTable.StrOutputPropName = $_.Name ; $syncHash.Data.msgTable.StrOutputPropValue = $Info.Data."$( $_.Name )" } ) ) | Out-Null } `
						-End { $Info.Data = $l }
				$Info.OutputType = "ObjectList"
			#}
		}

		if ( $Info.Data -is [string] )
		{ $Info.OutputType = "String" }
		elseif ( "String", "List", "ObjectList" -match $ScriptObject.OutputType )
		{ $Info.OutputType = $ScriptObject.OutputType }
		else
		{ $Info.OutputType = "String" }
	}
	catch {}

	$Error | `
		ForEach-Object {
			$Info.Error.Add( $_ ) | Out-Null
		}
	$Info.Finished = Get-Date

	# Log activity
	if ( $null -ne $ItemToSend )
	{
		$LogText = "Function: $( $ScriptObject.Name )`r`n$( $syncHash.Data.msgTable.LogStrSearchItemTitle ): $( $ItemToSend.Name )"
	}
	else
	{
		$LogText = "Function: $( $ScriptObject.Name )"
	}

	if ( $Info.Error )
	{
		$eh = WriteErrorlog -LogText $LogText -UserInput $null -Severity -1
	}
	WriteLog -Text $LogText -Success ( $null -eq $Info.Error ) -UserInput ( $InputData | ConvertTo-Json -Compress ) -ErrorLogHash $eh | Out-Null

	$syncHash.Window.Dispatcher.Invoke( [action] {
		# Send result to GUI
		if ( "None" -ne $ScriptObject.OutputType )
		{
			$syncHash.Window.Resources['CvsMiOutputHistory'].Source.Add( $Info )
		}

		$syncHash.DC.GridProgress[0] = [System.Windows.Visibility]::Collapsed
		$syncHash.GridFunctionOp.DataContext = $null
	} )
}

SetLocalizations

# Load imported functions to menuitems
Get-ChildItem "$( $syncHash.Data.BaseDir )\Modules\FunctionModules\*.psm1" | `
	ForEach-Object {
		$ModuleName = $_.BaseName
		Import-Module $_.FullName -Force -ArgumentList $culture

		Get-Command -Module $ModuleName | `
			ForEach-Object {
				$CodeDefinition = $_.Definition
				if ( $ModuleName -match "O365Functions" )
				{
					$MiObject = [pscustomobject]@{
						Name = $_.Name
					}
				}
				else
				{
					$MiObject = [pscustomobject]@{
						Name = $_.Name
						ObjectClass = ( $ModuleName -replace "Functions$" )
					}
				}

				$MiObject = GetScriptInfo -Text $CodeDefinition -InfoObject $MiObject -NoErrorRecord

				if ( $null -ne $MiObject )
				{
					if ( -not ( $MiObject | Get-Member -Name "RequiredAdGroups" ) -and -not ( $MiObject | Get-Member -Name "AllowedUsers" ) -or `
						$MiObject.AllowedUsers -match ( [Environment]::UserName ) -or `
						$syncHash.Data.UserGroups.Where( { $MiObject.RequiredAdGroups -match "$( $_ )\b" } ).Count -gt 0 )
					{
						$syncHash.Window.Resources["CvsMi$( $ModuleName )"].Source.Add( $MiObject )
					}
				}
			}
	}

# Load tools to menuitems
Get-ChildItem -Directory -Path "$( $syncHash.Data.BaseDir )\Script" | `
	Where-Object { "PagedTools", "SeparateTools" -match $_.Name } | `
	ForEach-Object {
		Get-ChildItem $_.FullName | `
			ForEach-Object {
				$File = $_
				$MiObject = GetScriptInfo -FilePath $File.FullName -NoErrorRecord
				if (
					-not ( $MiObject | Get-Member -Name "RequiredAdGroups" ) -and -not ( $MiObject | Get-Member -Name "AllowedUsers" ) -or`
					$MiObject.AllowedUsers -match ( [Environment]::UserName ) -or`
					$syncHash.Data.UserGroups.Where( { $MiObject.RequiredAdGroups -match "$( $_ )\b" } ).Count -gt 0
				)
				{
					Add-Member -InputObject $MiObject -MemberType NoteProperty -Name "BaseDir" -Value $File.Directory.FullName
					Add-Member -InputObject $MiObject -MemberType NoteProperty -Name "PageObject" -Value $null
					Add-Member -InputObject $MiObject -MemberType NoteProperty -Name "Process" -Value $null
					Add-Member -InputObject $MiObject -MemberType NoteProperty -Name "Ps" -Value $File.FullName
					Add-Member -InputObject $MiObject -MemberType NoteProperty -Name "Separate" -Value ( "PagedTools" -ne $_.Directory.Name )

					if ( "PagedTools" -eq $_.Directory.Name )
					{
						Add-Member -InputObject $MiObject -MemberType NoteProperty -Name "Xaml" -Value ( Get-ChildItem -Path "$( $syncHash.Data.BaseDir )\Gui\$( $File.BaseName ).xaml" ).FullName
						try
						{
							$LocFile = Get-ChildItem -Path "$( $syncHash.Data.BaseDir )\Localization\$( $syncHash.Data.Culture.Name )\$( $_.BaseName ).psd1" -ErrorAction Stop
						}
						catch
						{
							$LocFile = Get-ChildItem -Path "$( $syncHash.Data.BaseDir )\Localization\sv-SE\$( $_.BaseName ).psd1"
						}
						Add-Member -InputObject $MiObject -MemberType NoteProperty -Name "Localization" -Value $LocFile
					}

					if ( $null -ne $MiObject )
					{
						if ( "Send-Feedback" -eq $MiObject.Name )
						{
							$syncHash.Window.Resources['CvsMiAbout'].Source.Add( $MiObject )
						}
						elseif (
							$null -ne $MiObject.ObjectOperations -and `
							"None" -ne $MiObject.ObjectOperations -and `
							$null -ne ( $syncHash.Window.Resources.Keys | Where-Object { $_ -match "CvsMi$( ( Get-Culture ).TextInfo.ToTitleCase( $MiObject.ObjectOperations ) )Functions" } )
						)
						{
							( $syncHash.Window.Resources.GetEnumerator() | Where-Object { $_.Key -match "^CvsMi$( ( Get-Culture ).TextInfo.ToTitleCase( $MiObject.ObjectOperations ) )Functions$" } ).Value.Source.Add( $MiObject )
						}
						else
						{
							if ( $MiObject.Name -match "^\w+-O365" )
							{
								$syncHash.MiO365.Items.Add( $MiObject )
							}
							else
							{
								$syncHash.Window.Resources['CvsMiTools'].Source.Add( $MiObject )
							}
						}
					}
				}
			}
	}

Update-SplashText -Text $msgTable.StrSplashAddControlHandlers

# Input has been entered by operator, start function
$syncHash.BtnEnterFunctionInput.Add_Click( {
	$EnteredInput = @{}
	$syncHash.GridFunctionOp.DataContext.InputData | ForEach-Object { $EnteredInput."$( $_.Name )" = $_.EnteredValue }

	if ( $syncHash.GridFunctionOp.DataContext.NoRunspace )
	{
		RunScriptNoRunspace -ScriptObject $syncHash.GridFunctionOp.DataContext -EnteredInput $EnteredInput
	}
	else
	{
		$syncHash.Jobs.ExecuteFunction.P.AddParameter( "InputData", $EnteredInput )
		RunScript
	}
} )

# Get info from SysMan
$syncHash.BtnGetExtraInfo.Add_Click( {
	$syncHash.GridProgress.Visibility = [System.Windows.Visibility]::Visible
	. "GetExtraInfo$( $syncHash.Data.SearchedItem.ObjectClass )"
} )

# Hides text for the menuitems at toplevel
$syncHash.BtnHideMenuTexts.Add_Click( {
	if ( $syncHash.Window.Resources['MenuTextVisibility'] -eq [System.Windows.Visibility]::Visible )
	{
		$syncHash.Data.UserSettings.MenuTextVisible = $syncHash.Window.Resources['MenuTextVisibility'] = [System.Windows.Visibility]::Collapsed
		$syncHash.GridObjMenu.RowDefinitions[0].Height = "Auto"
		$syncHash.GridObjMenu.RowDefinitions[1].Height = "Auto"
	}
	else
	{
		$syncHash.Data.UserSettings.MenuTextVisible = $syncHash.Window.Resources['MenuTextVisibility'] = [System.Windows.Visibility]::Visible
		$syncHash.GridObjMenu.RowDefinitions[0].Height = 24
		$syncHash.GridObjMenu.RowDefinitions[1].Height = 18
	}
} )

# Scan file/directory for virus
$syncHash.BtnRunVirusScan.Add_Click( {
	$Shell = New-Object -Com Shell.Application
	$ShellFolder = $Shell.NameSpace( ( Get-item $syncHash.Data.SearchedItem.FullName ).Parent.FullName )
	$ShellFile = $ShellFolder.ParseName( $syncHash.Data.SearchedItem.DataContext.Name )
	$ShellFile.InvokeVerb( $syncHash.Data.msgTable.StrVerbVirusScan )
} )

# Start a search
$syncHash.BtnSearch.Add_Click( {
	$syncHash.DC.BrdAsterixWarning[0] = [System.Windows.Visibility]::Collapsed
	StartSearch
} )

# If checked for checkbox changes, enabled/disable button for extra info search
$syncHash.ChBGetFromComputerProcesses.Add_Checked( { EnableExtraSearch } )
$syncHash.ChBGetFromComputerProcesses.Add_UnChecked( { EnableExtraSearch } )
$syncHash.ChBGetFromPrintQueuePrintJobs.Add_Checked( { EnableExtraSearch } )
$syncHash.ChBGetFromPrintQueuePrintJobs.Add_UnChecked( { EnableExtraSearch } )
$syncHash.ChBGetFromSysMan.Add_Checked( { EnableExtraSearch } )
$syncHash.ChBGetFromSysMan.Add_UnChecked( { EnableExtraSearch } )
$syncHash.ChBGetFromUserLockOut.Add_Checked( { EnableExtraSearch } )
$syncHash.ChBGetFromUserLockOut.Add_UnChecked( { EnableExtraSearch } )

# Set control focus depending on key pressed
$syncHash.DgSearchResults.Add_KeyDown( {
	if ( $this.SelectedIndex -eq 0 )
	{
		if ( "Up" -eq $args[1].Key )
		{
			$args[1].Handled = $true
			$syncHash.TbSearch.Focus()
		}
		elseif ( "Down" -eq $args[1].Key )
		{
			[System.Windows.Input.Keyboard]::Focus( $this )
		}
	}
} )

# Add index for items in searchresult-list
$syncHash.DgSearchResults.Add_LoadingRow( {
	$args[1].Row.Header = ( $args[1].Row.GetIndex() + 1 ).ToString()
	$args[1].Row.Add_PreviewKeyDown( {
		if ( $syncHash.DgSearchResults.SelectedIndex -eq 0 -and `
			"Up" -eq $args[1].Key )
		{
			$args[1].Handled = $true
			$syncHash.TbSearch.Focus()
		}
		elseif ( "Return" -eq $args[1].Key -or "Enter" -eq $args[1].Key )
		{
			$args[1].Handled = $true
			Invoke-Command -ScriptBlock $syncHash.Code.ListItem -ArgumentList $syncHash.DgSearchResults.SelectedItem -NoNewScope
		}
	} )
} )

# A doubleclick was made, load the item
$syncHash.DgSearchResults.Add_MouseDoubleClick( {
	param ( [System.Object] $sender, [System.Windows.Input.MouseButtonEventArgs] $e )

	$e.Handled = $true
	Invoke-Command -ScriptBlock $syncHash.Code.ListItem -ArgumentList $syncHash.DgSearchResults.SelectedItem -NoNewScope
} )

# Output data from function is added, close its runspace
$syncHash.IcOutputObjects.ItemsSource.Add_CollectionChanged( {
	if ( $this.Count -gt 0 )
	{
		try
		{
			if ( $syncHash.Jobs.ExecuteFunction )
			{
				$syncHash.Jobs.ExecuteFunction.P.Close()
				$syncHash.Jobs.ExecuteFunction.P.Dispose()
			}
		}
		catch
		{
			$syncHash.Jobs.JobErrors.Add( $_ ) | Out-Null
		}
	}
} )

# Close object and reset controls
$syncHash.MiCloseObj.Add_Click( {
	ResetInfo
} )

# Copy object information
$syncHash.MiCopyObj.Add_Click( {
	$OFS = "`n`t"
	if ( $syncHash.IcObjectDetailed.Visibility -eq [System.Windows.Visibility]::Visible )
	{ $Props = $syncHash.IcObjectDetailed.ItemsSource }
	else
	{ $Props = $syncHash.IcPropsList.ItemsSource }

	$OFS = "`n`t"
	$Props | ForEach-Object {
		$_.Name
		"`t$( [string]$_.Value )"
		""
		""
	} | Set-Clipboard

	Show-Splash -Text $syncHash.Data.msgTable.StrPropertyCopied -NoTitle -NoProgressBar
} )

# If this menuitem is visible, connection at startup failed. Inform
$syncHash.MiO365Connect.Add_Click( {
	( $e = [System.Collections.ArrayList]::new() ).Add( $syncHash.Data.msgTable.ErrO365Connection )
	$output = [pscustomobject]@{ Finished = Get-Date; Data = $null ; Script = ( [pscustomobject]@{ Name = $syncHash.Data.msgTable.StrConnectO365Title } ) ; Error = $e ; Item = $null ; OutputType = "String" }
	[void] $syncHash.Window.Resources['CvsMiOutputHistory'].Source.Add( $output )
	$syncHash.Window.Resources['ExchangeAdministrator'] = [System.Windows.Visibility]::Collapsed

	$syncHash.Window.Resources.GetEnumerator() | Where-Object { $_.Key -match "Cvs.*" } | ForEach-Object { $_.Value.View.Refresh() }
} )

# Show a detailed overview of the object
$syncHash.MiObjDetailed.Add_Click( {
	if ( $syncHash.IcObjectDetailed.Visibility -eq [System.Windows.Visibility]::Visible )
	{
		$syncHash.IcObjectDetailed.Visibility = [System.Windows.Visibility]::Collapsed
	}
	else
	{
		$syncHash.IcObjectDetailed.Visibility = [System.Windows.Visibility]::Visible
		DisplayView -ViewName "GridObj"

		if ( 0 -eq $syncHash.Window.Resources['CvsDetailedProps'].Source.Count )
		{
			Invoke-Command $syncHash.Code.ListProperties -ArgumentList $true
		}
	}
} )

# Show/hide the object
$syncHash.MiShowHideObj.Add_Click( {
	if ( $syncHash.GridObj.Visibility -eq [System.Windows.Visibility]::Visible )
	{
		DisplayView -ViewName "None"
	}
	else
	{
		DisplayView -ViewName "GridObj"
	}
} )

# Show / hide view for outputdata
$syncHash.MiShowHideOutputView.Add_Click( {
	if (
		$syncHash.FrameTool.Visibility -eq [System.Windows.Visibility]::Visible -and `
		"MainOutput" -eq $syncHash.FrameTool.Content.Name
	)
	{
		DisplayView -ViewName "None"
	}
	else
	{
		DisplayView -ViewName "FrameTool"
		$syncHash.FrameTool.Navigate( $syncHash.Window.Resources['MainOutput'] )
	}
} )

# Show popup when text box gets focus
$syncHash.TbSearch.Add_GotFocus( {
	$syncHash.PopupMenu.IsOpen = $true
	$this.SelectAll()
} )

# Show popup when text box gets keyboardfocus
$syncHash.TbSearch.Add_GotKeyboardFocus( {
	$syncHash.PopupMenu.IsOpen = $true
	$this.SelectAll()
} )

# Key was pressed in the search textbox
$syncHash.TbSearch.Add_KeyDown( {
	if ( "Return" -eq $args[1].Key )
	{
		$syncHash.DC.TbSearch[0] = $this.Text
		$syncHash.DC.BrdAsterixWarning[0] = [System.Windows.Visibility]::Collapsed
		StartSearch
	}
} )

# Detect if down-key is used to go down to the searchresultslist
$syncHash.TbSearch.Add_PreviewKeyDown( {
	if ( "Down" -eq $args[1].Key -and `
		$syncHash.PopupMenu.IsOpen
	)
	{
		$args[1].Handled = $true
		$syncHash.DgSearchResults.SelectedIndex = 0
		$a = $syncHash.DgSearchResults.ItemContainerGenerator.ContainerFromIndex( 0 )
		$a.MoveFocus( ( [System.Windows.Input.TraversalRequest]::new( ( [System.Windows.Input.FocusNavigationDirection]::Next ) ) ) )
	}
} )

# Verify that minimum length was entered
$syncHash.TbSearch.Add_TextChanged( {
	if ( $this.Text -match "^\*" )
	{
		$syncHash.DC.BrdAsterixWarning[0] = [System.Windows.Visibility]::Visible
	}
	else
	{
		$syncHash.DC.BrdAsterixWarning[0] = [System.Windows.Visibility]::Collapsed
	}
	$syncHash.DC.BtnSearch[0] = $this.Text.Length -ge 3
} )

# Togglebutton is unchecked (unpressed), display the checked properties in PropsList
$syncHash.TBtnObjectDetailed.Add_UnChecked( {
	$syncHash.Data.UserSettings.VisibleProperties."$( $syncHash.Data.SearchedItem.ObjectClass )".Clear()
	$syncHash.Window.Resources['CvsPropsList'].Source.Clear()

	$syncHash.Window.Resources['CvsDetailedProps'].Source | `
		Where-Object { $_.CheckedForVisible } | `
		ForEach-Object {
			$Prop = $_
			$Prop.CheckedForVisible = $true

			[void] $syncHash.Window.Resources['CvsPropsList'].Source.Add( $Prop )
			[void] $syncHash.Data.UserSettings.VisibleProperties."$( $syncHash.Data.SearchedItem.ObjectClass )".Add( [pscustomobject]@{ Name = $_.Name ; MandatorySource = $_.Source } )
		}
} )

# The window is deactivated (lost focus), make sure the PopupMenu is closed
$syncHash.Window.Add_Deactivated( { $syncHash.PopupMenu.IsOpen = $false } )

# Main window is loaded, do final settings
$syncHash.Window.Add_Loaded( {
	if ( $syncHash.Data.UserSettings.Maximized -eq 1 )
	{
		$this.WindowState = [System.Windows.WindowState]::Maximized
	}
	else
	{
		$syncHash.Window.Height = $syncHash.Data.UserSettings.WindowHeight
		$syncHash.Window.Width = $syncHash.Data.UserSettings.WindowWidth
		$syncHash.Window.Top = $syncHash.Data.UserSettings.WindowTop
		$syncHash.Window.Left = $syncHash.Data.UserSettings.WindowLeft
	}
	$this.Resources['MenuTextVisibility'] = [System.Windows.Visibility]::Parse( [System.Windows.Visibility], $syncHash.Data.UserSettings.MenuTextVisible )
	$this.Resources['MainOutput'].Title = $syncHash.Data.msgTable.StrDefaultMainTitle

	if ( $PSCommandPath -match "(Development)|(User)" )
	{
		$this.BorderBrush = "Red"
	}
	else
	{
		$this.BorderBrush = "Black"
	}

	Update-SplashText -Text $syncHash.Data.msgTable.StrSplashFinished
	Close-SplashScreen
} )

# Rendering of GUI is done, fix the last little things
$syncHash.Window.Add_ContentRendered( {
	$syncHash.Data.MainWindowHandle = ( [System.Windows.Interop.WindowInteropHelper]::new( $this ) ).Handle
	$syncHash.FrameTool.Navigate( $this.Resources['MainOutput'] )

	$syncHash.Window.Resources['UseConverters'] = $true
	$this.Activate()
	$this.Resources.GetEnumerator() | Where-Object { $_.Name -match "^Cvs" } | ForEach-Object { $_.Value.View.Refresh() }
} )

# Catch keystrokes to see if the menu is to be opened
$syncHash.Window.Add_KeyDown( {
	switch ( $args[1].Key )
	{
		"Escape"
		{
			if ( $syncHash.PopupMenu.IsOpen )
			{
				$syncHash.PopupMenu.IsOpen = $false
			}
		}
		"F1" { $syncHash.TbSearch.Focus() }
		"System"
		{
			if ( $args[1].SystemKey -eq "D" )
			{
				$args[1].Handled = $true
				$syncHash.TbSearch.Focus()
			}
		}
	}
} )

# The main window has been moved, also move the popup
$syncHash.Window.Add_LocationChanged( {
	$oldLoc = $syncHash.PopupMenu.HorizontalOffset
	$syncHash.PopupMenu.HorizontalOffset = $oldLoc + 1
	$syncHash.PopupMenu.HorizontalOffset = $oldLoc
} )

# The main window closes, exits and deletes runspaces and events
$syncHash.Window.Add_Closed( {
	$syncHash.Data.UserSettings | ConvertTo-Json -Depth 5 | Set-Content $syncHash.Data.SettingsPath

	# Close runspace for functions
	if ( $PSCommandPath -notmatch "Development" )
	{
		try
		{
			[void] $syncHash.Jobs.ExecuteFunction.P.EndInvoke( $syncHash.Jobs.ExecuteFunction.H )
			$syncHash.Jobs.ExecuteFunction.P.Dispose()
		} catch {}

		# Close runspace for extra info fetching
		try
		{
			[void] $syncHash.Jobs.PSysManFetch.EndInvoke( $syncHash.Jobs.HSysManFetch )
			$syncHash.Jobs.PSysManFetch.Dispose()
		} catch {}

		# Close runspace for the search job
		try
		{
			[void] $syncHash.Jobs.SearchJob.EndInvoke( $syncHash.Jobs.SearchJobHandle )
			$syncHash.Jobs.SearchJob.Dispose()
			$syncHash.Jobs.SearchRunspace.Dispose()
		} catch {}

		# Close all runspaces opened for tools
		$syncHash.MiTools.Items |`
			Where-Object { $_.Separate -eq $true } | `
			ForEach-Object {
				try
				{
					$_.Process.PObj.CloseMainWindow()
					$_.Process.PObj.Close()
				}
				catch {}
			}

		# Unregister eventsubscribers created in tools
		$syncHash.Window.Resources.GetEnumerator() | `
			Where-Object { $_.Name -match "^Cvs" } | `
			ForEach-Object {
				$_.Value.Source | `
					Where-Object { $null -ne $_.PS }
			} | `
			ForEach-Object {
				$_.PageObject.EventSubscribers | `
					ForEach-Object {
						Unregister-Event -SourceIdentifier $_
					}
			}

	}
	[System.GC]::Collect()
} )

# Window is about to close, save window state to usersettings
$syncHash.Window.Add_Closing( {
	$automationElement = [System.Windows.Automation.AutomationElement]::FromHandle( $syncHash.Data.MainWindowHandle )
	$processPattern = $automationElement.GetCurrentPattern( [System.Windows.Automation.WindowPatternIdentifiers]::Pattern )
	$syncHash.Data.UserSettings.Maximized = $processPattern.Current.WindowVisualState
	$syncHash.Data.UserSettings.WindowHeight = $syncHash.Window.ActualHeight
	$syncHash.Data.UserSettings.WindowWidth = $syncHash.Window.ActualWidth
	$syncHash.Data.UserSettings.WindowTop = $syncHash.Window.Top
	$syncHash.Data.UserSettings.WindowLeft  = $syncHash.Window.Left
} )

# When new output is added, clear ItemsControl and add output to be displayed
$syncHash.Window.Resources['CvsMiOutputHistory'].Source.Add_CollectionChanged( {
	DisplayView -ViewName "FrameTool"

	$syncHash.FrameTool.Navigate( $syncHash.Window.Resources['MainOutput'] )
	$syncHash.DC.IcOutputObjects[0].Clear()
	$syncHash.DC.IcOutputObjects[0].Insert( 0, $syncHash.Window.Resources['CvsMiOutputHistory'].View.GetItemAt(0) )
	$syncHash.GridFunctionOp.DataContext = $null
	[System.GC]::Collect()
} )

# Connect to Office365 online services
try
{
	CheckO365Connection
	Update-SplashText -Text $msgTable.StrSplashConnectedO365
}
catch
{
	Update-SplashText -Text $msgTable.StrSplashConnectO365
	Set-SplashTopMost -NotTopMost
	"AzureAD", "ExchangeOnlineManagement" | `
		ForEach-Object {
			Import-Module -Name $_ -Force -ErrorAction Stop
		}
	try
	{
		$AzureAdAccount = Connect-AzureAD -ErrorAction Stop -WarningAction SilentlyContinue -InformationAction SilentlyContinue
	} catch {}
	try
	{
		Connect-ExchangeOnline -UserPrincipalName $AzureAdAccount.Account.Id -ErrorAction Stop -WarningAction SilentlyContinue
	} catch {}
	$syncHash.MiO365Connect.Visibility = [System.Windows.Visibility]::Collapsed
	Set-SplashTopMost -TopMost
}
Import-Module ActiveDirectory -Force
Update-SplashText -Text "$( $msgTable.StrSplashCheckO365Roles )`n$( ( Get-AzureADCurrentSessionInfo ).Account.Id )"
CheckO365Connection
CheckO365Roles

[void] $syncHash.Window.ShowDialog()

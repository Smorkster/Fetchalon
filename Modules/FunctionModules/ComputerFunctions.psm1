<#
.Synopsis
	A collection of functions to run for a user object
.Description
	A collection of functions to run for a user object
.State
	Prod
.Author
    Smorkster (smorkster)
#>

param ( $culture = "sv-SE" )

function Clear-NetIdCache
{
	<#
	.Synopsis
		Remove cache-files for NetID
	.Description
		Removes all cache-files for NetID
	.MenuItem
		Clear NetID cache
	.SubMenu
		Reset
	.SearchedItemRequest
		Required
	.State
		Prod
	.OutputType
		String
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item )

	$Files = Invoke-Command -ErrorAction Stop -ComputerName $Item.Name -ScriptBlock `
	{
		# Remove all items under 'C:\Windows\temp' containing iid
		$Files = Get-ChildItem -Path "C:\Windows\Temp\" -Include "*iid*" -Recurse
		$Files | `
			ForEach-Object {
				Remove-Item $_ -Force -Recurse -ErrorAction SilentlyContinue
			}
		return $Files
	}

	return "$( $IntMsgTable.ClearNetIdCacheFinished )`n$( $Files -join "`n" )"
}

function Close-CurrentOpenRemoteConnections
{
	<#
	.Synopsis
		Close remote connections
	.Description
		Restart service for remote connections; will close all active remove connections
	.MenuItem
		Close remote connections
	.SubMenu
		Login
	.SearchedItemRequest
		Required
	.State
		Prod
	.OutputType
		String
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item )

	try
	{
		Get-Service -ComputerName $Item.Name -Name CmRcService -ErrorAction Stop | Restart-Service
	}
	catch
	{
		throw $_
	}

	return $IntMsgTable.CloseCurrentOpenRemoteConnectionsSuccess
}

function Clear-DNSCache
{
	<#
	.Synopsis
		Flushes DNS cache on remote computer
	.Description
		Flushes DNS cache on remote computer
	.MenuItem
		Remove DNS cache
	.SubMenu
		Network
	.Depends
		WinRM
	.SearchedItemRequest
		Required
	.OutputType
		String
	.State
		Prod
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item )

	try
	{
		Invoke-Command -ComputerName $Item.Name -Scriptblock { ipconfig /flushdns }
	}
	catch
	{
		throw $_
	}

	return $IntMsgTable.ClearDNSCacheDone
}

function Connect-AsAdmin
{
	<#
	.Synopsis
		Renote connect as admin
	.Description
		Opens remote connection to connect as administrator
	.MenuItem
		Remove connect as admin
	.SubMenu
		Login
	.SearchedItemRequest
		Required
	.State
		Prod
	.OutputType
		None
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item )

	try
	{
		Start-Process -Filepath "C:\Windows\System32\mstsc.exe" -ArgumentList "/v:$( $Item.Name ) /f"
	}
	catch
	{
		throw $_
	}
}

function Send-ForceLogout
{
	<#
	.Synopsis
		Fore logout for all users
	.Description
		Force all currently loged in users to logout from remote computer
	.MenuItem
		Force logout
	.SubMenu
		Login
	.SearchedItemRequest
		Required
	.State
		Prod
	.OutputType
		List
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item )

	try
	{
		$LogedIn = [System.Collections.ArrayList]::new()
		quser /server:"$( $Item.Name )" |
			Select-Object -Skip 1 | `
			ForEach-Object {
				$_ -split "\s" | `
					Where-Object { $_ } | `
					Select-Object -First 1 | `
					Get-ADUser | `
					Select-Object -ExpandProperty Name | `
						ForEach-Object {
							$LogedIn.Add( $_ ) | Out-Null
						}
			}
		Invoke-CimMethod -ClassName Win32_Operatingsystem -ComputerName $Item.Name -MethodName Win32Shutdown -Arguments @{ Flags = 0 }
	}
	catch
	{
		throw $_
	}
	return $LogedIn
}

function Get-ComputersSameCostCenter
{
	<#
	.Synopsis
        List computers at same cost center
	.Description
        List all computers that are assigned to the same cost center
	.MenuItem
		List computers on the same cost center
	.SubMenu
		List
	.SearchedItemRequest
		Required
	.State
		Prod
	.OutputType
		List
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item )

	return ( Get-ADComputer -LDAPFilter "($( $IntMsgTable.StrSameCostCenterPropName )=$( $Item."$( $IntMsgTable.StrSameCostCenterPropName )" ))" ).Name | Sort-Object
}

function Get-Drivers
{
	<#
	.Synopsis
		Get all drivers
	.Description
		Get installed drivers
	.MenuItem
		Get drivers
	.SubMenu
		List
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

	try
	{
		$List = [System.Collections.ArrayList]::new()
		( driverquery /s $Item.Name /v /fo csv ) -replace [char]8221, "ö" -replace [char]255, "," | `
			ConvertFrom-Csv | `
			Select-Object -Property "Module Name", "Display Name", "Description", "Driver Type", "Start Mode", "State", "Status", "Path" | `
			Sort-Object "Display Name" | `
			ForEach-Object {
				$List.Add( $_ ) | Out-Null
			}
		return $List
	}
	catch
	{
		return $_
	}
}

function Get-LastBootUpTime
{
	<#
	.Synopsis
		Get last bootup time
	.Description
		Get date and time when the computer was last booted
	.MenuItem
		Last boot time
	.SubMenu
		Information
	.SearchedItemRequest
		Allowed
	.InputData
		ComputerName, True, List computers
	.OutputType
		ObjectList
	.State
		Prod
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item, $InputData )

	$L = [System.Collections.ArrayList]::new()
	( ( $InputData.ComputerName -split "\W" ) + $Item.Name ) | `
		Where-Object { $_ -and ( Get-ADObject -LDAPFilter "(&(Name=$( $_ ))(ObjectClass=computer))" ) } | `
		ForEach-Object {
			$CName = $_.ToUpper()
			try
			{
				$C = Get-CimInstance Win32_OperatingSystem -ComputerName $CName -ErrorAction Stop | `
					Select-Object PSComputerName, LastBootUpTime
			}
			catch
			{
				
				$C = [pscustomobject]@{
					PSComputerName = $CName
					LastBootUpTime = $IntMsgTable.GetLastBootUpTimeNoDateInfo
				}
			}
			$SClient = Invoke-RestMethod -Method Get -Uri "$( $IntMsgTable.SysManServerUrl )/api/Client/?Name=$( $CName )" -UseDefaultCredentials
			$SInfo = Invoke-RestMethod -Method Get -Uri "$( $IntMsgTable.SysManServerUrl )/api/reporting/client?clientId=$( $SClient.Id )" -UseDefaultCredentials

			Add-Member -InputObject $C -MemberType NoteProperty -Name "SysManLastBootTime" -Value $SInfo.lastBootTime
			$L.Add( $C ) | Out-Null
		}

	if ( $L.Count -eq 0 )
	{
		$L.Add( ( [pscustomobject]@{ PSComputerName = $IntMsgTable.GetLastBootUpTimeNoData } ) ) | Out-Null
	}

	return $L | `
		Sort-Object -Property PSComputerName | `
		Select-Object -Property @{ Name = "$( $IntMsgTable.GetLastBootUpTimePropNameTitle )" ; Expression = { $_.PSComputerName } }, `
			@{ Name = "$( $IntMsgTable.GetLastBootUpTimePropDateInfoTitle )" ; Expression = {
				if ( $_.LastBootUpTime -is [datetime] )
				{
					Get-Date $_.LastBootUpTime -Format "yyyy-MM-dd HH:mm:ss"
				}
				else
				{
					$_.LastBootUpTime
				}
			} } , `
			@{ Name = "$( $IntMsgTable.GetLastBootUpTimePropSMTitle )"
			Expression = { Get-Date $_.SysManLastBootTime -Format "yyyy-MM-dd HH:mm:ss" } }
}

function Get-LastLoggedIn
{
	<#
	.Synopsis
		Get last logged in
	.Description
		List who was last logged on to multiple computers
	.MenuItem
		Get last logged in
	.SubMenu
		List
	.SearchedItemRequest
		None
	.OutputType
		ObjectList
	.State
		Prod
	.InputData
		ComputerName, True, List of computer names
	.Author
		Smorkster (smorkster)
	#>

	param ( $InputData )

	$Output = [System.Collections.ArrayList]::new()
	$InputData.ComputerName -split "\W" | `
		Where-Object { $_ } | `
		ForEach-Object {
			try
			{
				$a = ""
				$Id = ( Invoke-RestMethod -Uri "$( $IntMsgTable.SysManServerUrl )/api/client/?name=$_&onlyLatest=true" -UseDefaultCredentials ).id
				$a = ( Invoke-RestMethod -Uri "$( $IntMsgTable.SysManServerUrl )/api/reporting/Client?clientId=$Id" -UseDefaultCredentials ).LastUser
				try
				{
					$a = ( Get-ADUser $a ).Name
				}
				catch
				{
					$a = "$a ($( $IntMsgTable.GetLastLoggedInErrNoUser ))"
				}
			}
			catch
			{
				$a = $IntMsgTable.GetLastLoggedInStrCompNotFound
			}
			[void] $Output.Add( ( [pscustomobject]@{ $IntMsgTable.GetLastLoggedInStrCompTitle = $_ ; $IntMsgTable.GetLastLoggedInStrUserTitle = $a } ) )
		}
	return $Output
}

function Get-LoggedInUser
{
	<#
	.Synopsis
		List logged in users
	.Description
		List who is logged in to a given computer
	.MenuItem
		Show currently logged in
	.SubMenu
		Login
	.InputData
		ComputerName, True, Name of computer
	.SearchedItemRequest
		Allowed
	.State
		Prod
	.OutputType
		String
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item, $InputData )

	return "$( ( ( Get-CimInstance -ComputerName $InputData.ComputerName.Trim() -ClassName Win32_ComputerSystem | Select-Object -ExpandProperty UserName ) -split "\\" )[1] | Get-ADUser | Select-Object -ExpandProperty Name )"
}

function Get-Printers
{
	<#
	.Synopsis
		Get installed printers
	.Description
		List all installed printers and printerqueues
	.MenuItem
		List printers
	.SubMenu
		List
	.NoRunspace
	.SearchedItemRequest
		Required
	.State
		Prod
	.OutputType
		ObjectList
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item )

	try
	{
		$Printers = [System.Collections.ArrayList]::new()
		Get-CimInstance -ClassName Win32_Printer -ComputerName $Item.Name | `
			Select-Object Name, Comment, Default, DriverName | `
			Sort-Object -Property Name | `
			ForEach-Object {
				$Printers.Add( $_ ) | Out-Null
			}
		return $Printers
	}
	catch
	{
		return $_
	}
}

function Open-RemoteC
{
	<#
	.Synopsis
		Open C:\ at the computer
	.Description
		Open Explorer at C:\ for the computer
	.MenuItem
		Open C:\
	.NoRunspace
	.SearchedItemRequest
		Required
	.State
		Prod
	.OutputType
		None
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item )

	Start-Process -Filepath "C:\Windows\explorer.exe" -ArgumentList "\\$( $Item.Name )\C$\"
}

function Open-ServiceTagWebpage
{
	<#
	.Synopsis
		Open webpage for the servicetag
	.Description
		Get the manufacturer and servicetag for the computer and then opens the webpage for the designated servicetag. Works with Dell and Lenovo
	.MenuItem
		Open servicetag webpage
	.SubMenu
		Information
	.NoRunspace
	.SearchedItemRequest
		Required
	.State
		Prod
	.OutputType
		None
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item )

	$CimComputer = Get-CimInstance -ClassName CIM_Chassis -ComputerName $Item.Name

	# Get remote servicetag
	$Vendor = $CimComputer.Manufacturer
	$Servicetag = $CimComputer.SerialNumber

	# Open Google Chrome with manufacturer webpage for servicetag
	if ( $Vendor -match "Dell" )
	{
		$Adress = "http://www.dell.com/support/my-support/se/sv/sebsdt1/product-support/servicetag/$Servicetag"
	}
	elseif ( $Vendor -match "Lenovo" )
	{
		$Adress = "https://pcsupport.lenovo.com/us/en/products/$Servicetag"
	}

	Start-Process chrome.exe $Adress
}

function Open-SysManEdit
{
	<#
	.Synopsis
		SysMan change information
	.Description
		Opens the SysMan page to change information for the object
	.MenuItem
		SysMan change information
	.SubMenu
		SysMan
	.SearchedItemRequest
		Required
	.State
		Prod
	.OutputType
		None
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item )

	[System.Diagnostics.Process]::Start( "chrome", "$( $IntMsgTable.SysManServerUrl )/Client/Edit#targetName=$( $Item.Name )" )
}

function Open-SysManInstall
{
	<#
	.Synopsis
		SysMan for installation
	.Description
		Opens the SysMan page for application installation
	.MenuItem
		SysMan for installation
	.SubMenu
		SysMan
	.SearchedItemRequest
		Required
	.OutputType
		None
	.State
		Prod
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item )

	[System.Diagnostics.Process]::Start( "chrome", "$( $IntMsgTable.SysManServerUrl )/Application/InstallForClients#targetName=$( $Item.Name )" )
}

function Open-SysManOsdMonitor
{
	<#
	.Synopsis
		SysMan OSD monitoring
	.Description
		Opens the SysMan page for controlling OSD monitoring
	.MenuItem
		SysMan OSD monitoring
	.SubMenu
		SysMan
	.SearchedItemRequest
		Required
	.OutputType
		None
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item )

	[System.Diagnostics.Process]::Start( "chrome", "$( $IntMsgTable.SysManServerUrl )/Tool/Dart#targetName=$( $Item.Name )" )
}

function Open-SysManOsInstall
{
	<#
	.Synopsis
		SysMan OS installation
	.Description
		Opens the SysMan page for OS installation
	.MenuItem
		SysMan OS installation
	.SubMenu
		SysMan
	.SearchedItemRequest
		Required
	.OutputType
		None
	.State
		Prod
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item )

	[System.Diagnostics.Process]::Start( "chrome", "$( $IntMsgTable.SysManServerUrl )/Client/OperatingSystemDeployment#targetName=$( $Item.Name )" )
}

function Open-SysManPrintAdd
{
	<#
	.Synopsis
		SysMan add printer
	.Description
		Opens the SysMan page for adding printers
	.MenuItem
		SysMan add printer
	.SubMenu
		SysMan
	.SearchedItemRequest
		Required
	.OutputType
		None
	.State
		Prod
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item )

	[System.Diagnostics.Process]::Start( "chrome", "$( $IntMsgTable.SysManServerUrl )/Printer/InstallForClients#targetName=$( $Item.Name )" )
}

function Open-SysManPrintRemove
{
	<#
	.Synopsis
		SysMan remove printer
	.Description
		Open SysMan page for removal of printer
	.MenuItem
		SysMan remove printer
	.SubMenu
		SysMan
	.SearchedItemRequest
		Required
	.OutputType
		None
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item )

	[System.Diagnostics.Process]::Start( "chrome", "$( $IntMsgTable.SysManServerUrl )/Printer/UninstallForClients#targetName=$( $Item.Name )" )
}

function Open-SysManTools
{
	<#
	.Synopsis
		SysMan utility
	.Description
		Opens the SysMan utility page
	.MenuItem
		SysMan utility
	.SubMenu
		SysMan
	.SearchedItemRequest
		Required
	.OutputType
		None
	.State
		Prod
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item )

	[System.Diagnostics.Process]::Start( "chrome", "$( $IntMsgTable.SysManServerUrl )/Tool/ExecuteForClient#targetName=$( $Item.Name )" )
}

function Open-SysManUninstall
{
	<#
	.Synopsis
		SysMan for uninstallation
	.Description
		Opens the SysMan uninstall page
	.MenuItem
		SysMan for uninstallation
	.SubMenu
		SysMan
	.SearchedItemRequest
		Required
	.OutputType
		None
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item )

	[System.Diagnostics.Process]::Start( "chrome", "$( $IntMsgTable.SysManServerUrl )/Application/UninstallForClients#targetName=$( $Item.Name )" )
}

function Reset-HostsFile
{
	<#
	.Synopsis
		Clear posted domains in the Hosts file
	.Description
		Removes all domains entered in Windows Host file. Can fix problems with certificates in Office 365
	.MenuItem
		Clear Host file
	.SubMenu
		Reset
	.SearchedItemRequest
		Allowed
	.OutputType
		String
	.State
		Prod
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item )

	try
	{
		$HostFileContent = Invoke-Command -ComputerName $Item.SamAccountName -ScriptBlock {
			Get-Content C:\Windows\System32\drivers\etc\hosts | `
				Where-Object { $_ -match "^#" }
		}
		Set-Content -Path "\\$( $Item.SamAccountName )\C$\Windows\System32\drivers\etc\hosts"  -Value $HostFileContent

		return $IntMsgTable.ResetHostsFileFinished
	}
	catch
	{
		throw $_
	}
}

function Reset-OutlookNavigationPanel
{
	<#
	.Synopsis
		Recover Corrupt UI Outlook
	.Description
		Restores the default view for Outlook. Fixes \"Invalid XML, unable to load view\" error message.
	.MenuItem
		Restore Outlook navpane
	.SubMenu
		Reset
	.SearchedItemRequest
		Allowed
	.OutputType
		String
	.State
		Prod
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item )

	try
	{
		Invoke-Command -ComputerName $Item.SamAccountName -ScriptBlock {
			Get-Process -Name Outlook -ErrorAction SilentlyContinue | `
				ForEach-Object {
					$_.CloseMainWindow()
				}

			do
			{
				Start-Sleep -MilliSeconds 200
			}
			until ( $null -eq ( Get-Process -Name Outlook -ErrorAction SilentlyContinue ) )

			outlook.exe /resetnavpane
		}

		return $IntMsgTable.ResetOutlookNavigationPanelFinished
	}
	catch
	{
		throw $_
	}
}

function Reset-OutlookViews
{
	<#
	.Synopsis
		Restore views in Outlook
	.Description
		Restore problematic views, e.g. Inbox or folders, to default settings
	.MenuItem
		Återställ vyer i Outlook
	.SubMenu
		Reset
	.SearchedItemRequest
		Allowed
	.OutputType
		String
	.State
		Prod
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item )

	try
	{
		Invoke-Command -ComputerName $Item.SamAccountName -ScriptBlock {
			"OUTLOOK", "WINWORD", "EXCEL", "Teams", "POWERPNT", "MSPUB", "ONENOTE", "Todo" | `
				ForEach-Object {
					try
					{
						Get-Process -Name $_ -ErrorAction Stop | `
							ForEach-Object {
								$P = $_
								$P.CloseMainWindow()
								if ( Get-Process -Id $P.Id )
								{
									$P.Kill()
								}
							}
					}
					catch { throw $_.Exception.Message }
				}

			do
			{
				Start-Sleep -MilliSeconds 200
			}
			until ( $null -eq ( Get-Process -Name Outlook -ErrorAction SilentlyContinue ) )

			outlook.exe /cleanviews
		}

		return $IntMsgTable.ResetOutlookViewsFinished
	}
	catch
	{
		throw $_
	}
}

function Reset-SoftwareCenter
{
	<#
	.Synopsis
		Reset Software Center
	.Description
		Reset Software Center
	.MenuItem
		Reset Software Center
	.SubMenu
		Reset
	.SearchedItemRequest
		Required
	.OutputType
		None
	.State
		Prod
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item )

	Get-CimInstance -ComputerName $Item.Name -Namespace root\ccm\CITasks -Query "Select * From CCM_CITask Where TaskState != ' PendingSoftReboot' AND TaskState != 'PendingHardReboot' AND TaskState != 'InProgress'" | Remove-CimInstance
}

function Send-RestartComputer
{
	<#
	.Synopsis
		Restart computer
	.Description
		Restart computer
	.MenuItem
		Restart computer
	.SearchedItemRequest
		Required
	.OutputType
		String
	.Depends
		WinRM
	.State
		Prod
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item )

	Restart-Computer -ComputerName $Item.Name -Force -Wait -For PowerShell -Timeout 300 -Delay 2 -ErrorAction Stop
	return "OK"
}

function Send-ShutdownComputer
{
	<#
	.Synopsis
		Turn off computer
	.Description
		Turn off computer
	.MenuItem
		Turn off computer
	.SearchedItemRequest
		Required
	.OutputType
		String
	.Depends
		WinRM
	.State
		Prod
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item )

	Stop-Computer -ComputerName $Item.Name -Force -ErrorAction Stop
	return "OK"
}

function Send-Toast
{
	<#
	.Synopsis
		Send message to computer
	.Description
		Send message to computer
	.MenuItem
		Send message
	.SearchedItemRequest
		Required
	.OutputType
		String
	.Depends
		WinRM
	.InputData
		Title, True, Title of the message
	.InputData
		Message, True, Message text
	.State
		Prod
	.Author
		Smorkster (smorkster)
	#>

	param ( $SearchedItem , $InputData )

	$code = {
		[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
		[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

		$AppId = "$( $args[0].StrAppId )"
		$Title = "$( $args[1].Title )"
		$Message = "$( $args[1].Message )"
		$ToastXml = @"
		<toast>
			<audio silent = "true" />
			<visual>
				<binding template = "ToastText03">
					<text id = "1" >$Title</text>
					<text id = "2" >$Message</text>
				</binding>
			</visual>
		</toast>
"@

		$ToastXmlDoc = [Windows.Data.Xml.Dom.XmlDocument]::new()
		$ToastXmlDoc.LoadXml( $ToastXml )
		$Toast = New-Object -TypeName Windows.UI.Notifications.ToastNotification -ArgumentList $ToastXmlDoc
		$ToastNotifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier( $AppId )
		$ToastNotifier.Show( $Toast )
	}

	try
	{
		Invoke-Command -ComputerName $SearchedItem.Name -ScriptBlock $code -ArgumentList $IntMsgTable, $InputData
		return $IntMsgTable.SendToastSuccess
	}
	catch
	{
		throw $_
	}
}

function Start-RemoteControl
{
	<#
	.Synopsis
		Start remote control
	.Description
		Start remote control
	.MenuItem
		Start remote control
	.SubMenu
		Network
	.SearchedItemRequest
		Required
	.OutputType
		None
	.Depends
		WinRM
	.State
		Prod
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item )

	Start-Process -Filepath "C:\Program Files (x86)\Microsoft Endpoint Manager\AdminConsole\bin\i386\CmRcViewer.exe" -ArgumentList $Item.Name
}

$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.Parent.FullName

Import-LocalizedData -BindingVariable IntMsgTable -UICulture $culture -FileName "$( ( $PSCommandPath.Split( "\" ) | Select-Object -Last 1 ).Split( "." )[0] ).psd1" -BaseDirectory "$RootDir\Localization"

Export-ModuleMember -Function *

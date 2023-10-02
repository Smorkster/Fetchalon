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

function Get-ComputersSameCostCenter
{
	<#
	.Synopsis
        List computers at same cost center
	.Description
        List all computers that are assigned to the same cost center
	.MenuItem
		List computers on the same cost center
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

function Get-LastLoggedIn
{
	<#
	.Synopsis
		Get last logged in
	.Description
		List who was last logged on to multiple computers
	.MenuItem
		Get last logged in
	.SearchedItemRequest
		None
	.OutputType
		ObjectList
	.State
		Prod
	.InputData
		ComputerName List of computer names
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
				Invoke-RestMethod -Uri "$( $IntMsgTable.SysManServerUrl )/api/client/?name=$_" -UseDefaultCredentials -Method Get -ContentType "application/json" | Out-Null
				$u = ( ( Invoke-RestMethod -Uri "$( $IntMsgTable.SysManServerUrl )/api/client/Health?targetName=$( $_ )&onlyLatest=true" -UseDefaultCredentials ).lastLoggedOnUser -split "\\" )[1]
			}
			catch
			{
				$u = $IntMsgTable.GetLastLoggedInStrCompNotFound
			}
			[void] $Output.Add( ( [pscustomobject]@{ $IntMsgTable.GetLastLoggedInStrCompTitle = $_ ; $IntMsgTable.GetLastLoggedInStrUserTitle = $u } ) )
		}
	return $Output
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
	.SearchedItemRequest
		Allowed
	.OutputType
		String
	.InputData
		Computer name Computer where Host file is to be cleared
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
	.SearchedItemRequest
		Allowed
	.OutputType
		String
	.InputData
		ComputerName Computer where Outlook is to be fixed
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
	.SearchedItemRequest
		Allowed
	.OutputType
		String
	.InputData
		ComputerName Computer where Outlook is to be fixed
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
		Title Title of the message
	.InputData
		Message Message text
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

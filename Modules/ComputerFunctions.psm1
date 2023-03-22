<#
.Synopsis A collection of functions to run for a user object
.Description A collection of functions to run for a user object
.State Dev
#>

param ( $culture = "sv-SE" )

function Send-Toast
{
	<#
	.Synopsis Send toast message
	.Description Send a toast message to designated computer
	.MenuItem Send message
	.SearchedItemRequest Required
	.OutputType String
	.Depends WinRM
	.InputData Title
		Title for message
	.InputData Message
		Message text
	.Author
		Smorkster
	#>

	param ( $Item , $InputData )

	$code = {
		[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
		[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

		$AppId = $IntMsgTable.StrAppId
		$Title = $InputData."$( $IntMsgTable.SendToastTitle )"
		$Message = $InputData.Message
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

	Invoke-Command -ComputerName $Item.Name -ScriptBlock $code
}

function Get-LastLoggedIn
{
	<#
	.Synopsis List last logged in users
	.Description List which users last logged in to multiple computers
	.MenuItem Last logged in users
	.SearchedItemRequest None
	.OutputType ObjectList
	.InputData ComputerNames List of computernames
	.Author Smorkster
	#>

	param ( $Item, $InputData )

	$Output = [System.Collections.ArrayList]::new()
	foreach ( $c in ( $InputData -split "\W" ) )
	{
		$u = ( ( Invoke-RestMethod -Uri "$( $IntMsgTable.SysManServerUrl )/api/client/Health?targetName=$c&onlyLatest=true" -UseDefaultCredentials ).lastLoggedOnUser -split "\\" )[1]
		[void] $Output.Add( ( [pscustomobject]@{ Dator = $c ; Användare = $u } ) )
	}
	return $Output
}

function Open-SysManInstall
{
	<#
	.Synopsis SysMan for installation
	.Description Opens SysMan for installation of application
	.MenuItem SysMan for installation
	.SearchedItemRequest Required
	.OutputType None
	.Author Smorkster
	#>

	param ( $Item )

	[System.Diagnostics.Process]::Start( "chrome", "$( $IntMsgTable.SysManServerUrl )/Application/InstallForClients#targetName=$( $Item.Name )" )
}

function Open-SysManUninstall
{
	<#
	.Synopsis SysMan for uninstallation
	.Description Opens SysMan for uninstallation of application
	.MenuItem SysMan for uninstallation
	.SearchedItemRequest Required
	.OutputType None
	.Author Smorkster
	#>

	param ( $Item )

	[System.Diagnostics.Process]::Start( "chrome", "$( $IntMsgTable.SysManServerUrl )/Application/UninstallForClients#targetName=$( $Item.Name )" )
}

function Open-SysManPrintAdd
{
	<#
	.Synopsis SysMan to add printer
	.Description Opens SysMan to add printer
	.MenuItem SysMan add printer
	.SearchedItemRequest Required
	.OutputType None
	.Author Smorkster
	#>

	param ( $Item )

	[System.Diagnostics.Process]::Start( "chrome", "$( $IntMsgTable.SysManServerUrl )/Printer/InstallForClients#targetName=$( $Item.Name )" )
}

function Open-SysManPrintRemove
{
	<#
	.Synopsis SysMan to remove printer
	.Description Opens SysMan to remove printer
	.MenuItem SysMan remove printer
	.SearchedItemRequest Required
	.OutputType None
	.Author Smorkster
	#>

	param ( $Item )

	[System.Diagnostics.Process]::Start( "chrome", "$( $IntMsgTable.SysManServerUrl )/Printer/UninstallForClients#targetName=$( $Item.Name )" )
}

function Open-SysManOsdMonitor
{
	<#
	.Synopsis SysMan OSD monitoring
	.Description Opens SysMan for monitoring of OSD installation
	.MenuItem SysMan OSD monitoring
	.SearchedItemRequest Required
	.OutputType None
	.Author Smorkster
	#>

	param ( $Item )

	[System.Diagnostics.Process]::Start( "chrome", "$( $IntMsgTable.SysManServerUrl )/Tool/Dart#targetName=$( $Item.Name )" )
}

function Open-SysManOsInstall
{
	<#
	.Synopsis SysMan OS installation
	.Description Opens SysMan for installation of OS
	.MenuItem SysMan OS installation
	.SearchedItemRequest Required
	.OutputType None
	.Author Smorkster
	#>

	param ( $Item )

	[System.Diagnostics.Process]::Start( "chrome", "$( $IntMsgTable.SysManServerUrl )/Client/OperatingSystemDeployment#targetName=$( $Item.Name )" )
}

function Open-SysManTools
{
	<#
	.Synopsis SysMan tools
	.Description Opens site for SysMan tools
	.MenuItem SysMan tools
	.SearchedItemRequest Required
	.OutputType None
	.Author Smorkster
	#>

	param ( $Item )

	[System.Diagnostics.Process]::Start( "chrome", "$( $IntMsgTable.SysManServerUrl )/Tool/ExecuteForClient#targetName=$( $Item.Name )" )
}

function Open-SysManEdit
{
	<#
	.Synopsis SysMan change information
	.Description Opens SysMan for changing information about the computer
	.MenuItem SysMan change information
	.SearchedItemRequest Required
	.OutputType None
	.Author Smorkster
	#>

	param ( $Item )

	[System.Diagnostics.Process]::Start( "chrome", "$( $IntMsgTable.SysManServerUrl )/Client/Edit#targetName=$( $Item.Name )" )
}

function Get-ComputersSameCostCenter
{
	<#
	.Synopsis List computers at same cost center
	.Description List all computers that is located at the same cost center
	.MenuItem List computers at same cost center
	.SearchedItemRequest Required
	.OutputType List
	.Author Smorkster
	#>

	param ( $Item )

	return ( Get-ADComputer -LDAPFilter "($( $IntMsgTable.StrSameCostCenterPropName )=$( $Item."$( $IntMsgTable.StrSameCostCenterPropName )" ))" ).Name | Sort-Object
}

function Send-RestartComputer
{
	<#
	.Synopsis Reboot computer
	.Description Reboot computer
	.MenuItem Reboot computer
	.SearchedItemRequest Required
	.OutputType String
	.Depends WinRM
	.Author Smorkster
	#>

	param ( $Item )

	Restart-Computer -ComputerName $Item.Name -Force -Wait -For PowerShell -Timeout 300 -Delay 2 -ErrorAction Stop
	return "OK"
}

function Send-ShutdownComputer
{
	<#
	.Synopsis Force shutdown of computer
	.Description For a shutdown of selected computer
	.MenuItem Force shutdown
	.SearchedItemRequest Required
	.OutputType String
	.Depends WinRM
	.Author Smorkster
	#>

	param ( $Item )

	Stop-Computer -ComputerName $Item.Name -Force -ErrorAction Stop
	return "OK"
}

function Start-RemoteControl
{
	<#
	.Synopsis Start remote controll
	.Description Start CmRcViewer for a remote controls session
	.MenuItem Start remote control
	.SearchedItemRequest Required
	.OutputType None
	.Depends WinRM
	.Author Smorkster
	#>

	param ( $Item )

	Start-Process -Filepath "C:\Program Files (x86)\Microsoft Endpoint Manager\AdminConsole\bin\i386\CmRcViewer.exe" -ArgumentList $Item.SamAccountName
}

$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.FullName
Import-LocalizedData -BindingVariable IntMsgTable -UICulture $culture -FileName "$( ( $PSCommandPath.Split( "\" ) | Select-Object -Last 1 ).Split( "." )[0] ).psd1" -BaseDirectory "$RootDir\Localization\$culture\Modules"

Export-ModuleMember -Function *
<#
.Synopsis
	Show About m.m.
.MenuItem
	Show About
.Description
	Show useful information about Fetchalon etc.
.State
	Prod
.ObjectOperations
	Suite
.Author
	Smorkster (smorkster)
#>

Add-Type -AssemblyName PresentationFramework
$syncHash = $args[0]

function Set-Localizations
{
	$syncHash.Controls.Window.Resources['CvsEditors'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	$syncHash.Controls.Window.Resources['CvsModules'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	$syncHash.Controls.Window.Resources['ValueTtDescription'] = $syncHash.Data.msgTable.ContentTblValueTtDescription
	$syncHash.Controls.Window.Resources['ValueTtPath'] = $syncHash.Data.msgTable.ContentTblValueTtPath
	$syncHash.Controls.Window.Resources['ValueTtVersion'] = $syncHash.Data.msgTable.ContentTblValueTtVersion
	$syncHash.Controls.Window.Resources['StrModuleOpenPath'] = $syncHash.Data.msgTable.StrModuleOpenPath
	$syncHash.Controls.Window.Resources['StrModuleOpenRead'] = $syncHash.Data.msgTable.StrModuleOpenRead

	$syncHash.Controls.Window.Resources.MiPathStyle.Setters[0].Handler = $syncHash.Code.ModuleOpenPathClick
	$syncHash.Controls.Window.Resources.MiReadStyle.Setters[0].Handler = $syncHash.Code.ModuleOpenReadClick
	$syncHash.Controls.Window.Resources.TblMiReadStyle.Setters[0].Handler = $syncHash.Code.ModuleTextClick
}

################### Start script
$controls = [System.Collections.ArrayList]::new()

BindControls $syncHash $controls

[System.Windows.RoutedEventHandler] $syncHash.Code.ModuleOpenPathClick = {
	param ( $SenderObject, $e )

	Start-Process -FilePath C:\Windows\explorer.exe -ArgumentList "/select, ""$( $syncHash.File )"""

#	explorer ( Get-Item $SenderObject.DataContext.Path ).Directory
}

[System.Windows.RoutedEventHandler] $syncHash.Code.ModuleOpenReadClick = {
	param ( $SenderObject, $e )

	$e.Handled = $true
	Start-Process -FilePath $e.Source.DataContext.Path -ArgumentList """$( $syncHash.File )"""
}

[System.Windows.Input.MouseButtonEventHandler] $syncHash.Code.ModuleTextClick = {
	param ( $SenderObject, $e )

	$syncHash.File = $SenderObject.DataContext.Path
}

Set-Localizations

Get-Module | `
	ForEach-Object {
		$syncHash.Controls.Window.Resources['CvsModules'].Source.Add( $_ ) | Out-Null
	}

try
{
	$syncHash.Controls.TblO365Account.Text = ( Get-AzureADCurrentSessionInfo -ErrorAction Stop ).Account.Id
}
catch
{
	$syncHash.Controls.TblO365Account.Text = $syncHash.Data.msgTable.ErrO365NotLoggedIn
}

if ( Test-Path "C:\Program Files (x86)\Notepad++\notepad++.exe" )
{
	$syncHash.Controls.Window.Resources['CvsEditors'].Source.Add( ( [pscustomobject]@{ Name = "Notepad++"; Path = "C:\Program Files (x86)\Notepad++\notepad++.exe" } ) )
}
elseif ( Test-Path "C:\Program Files\Notepad++\notepad++.exe" )
{
	$syncHash.Controls.Window.Resources['CvsEditors'].Source.Add( ( [pscustomobject]@{ Name = "Notepad++"; Path = "C:\Program Files\Notepad++\notepad++.exe" } ) )
}
$syncHash.Controls.Window.Resources['CvsEditors'].Source.Add( ( [pscustomobject]@{ Name = "Notepad"; Path = "notepad" } ) )

$syncHash.Controls.TblPSVersionTable.Text = $PSVersionTable.PSVersion.ToString()

$syncHash.Controls.ChbRunOnLogin.Add_Checked( {
	try
	{
		$SuiteScript = Get-Item "$( $syncHash.Root )\Script\$( $syncHash.Data.SuiteBaseName ).ps1"
		$Drive = Get-PSDrive | Where-Object { $SuiteScript.Directory.Root.Name -match $_.Name }
		if ( -not [string]::IsNullOrEmpty( $Drive.DisplayRoot ) )
		{
			$Root = $Drive.DisplayRoot
		}
		else
		{
			$Root = $Drive.Root
		}
		$SuiteScriptPath = Join-Path $Root -ChildPath ( $SuiteScript.FullName.Replace( $SuiteScript.Directory.Root.Name , "" ) )

		New-Item -Path "$( $env:APPDATA )\Microsoft\Windows\Start Menu\Programs\Startup" -Name $syncHash.Data.msgTable.StrStartOnLoginBatFileName -ItemType File -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -WindowStyle Hidden -File ""$( $SuiteScriptPath )"" sv-SE 1" -ErrorAction Stop
	}
	catch
	{
		if ( $_.Exception.Message -notmatch "already exists" )
		{
			Show-MessageBox -Text "$( $syncHash.Data.msgTable.ErrCreateLoginBatchFile ):`n$( $_.Exception.Message )" | Out-Null
		}
	}
	$syncHash.Data.SuiteSettings.RunsAtLogin = $true
} )

$syncHash.Controls.ChbRunOnLogin.Add_Unchecked( {
	Remove-Item -Path "$( $env:APPDATA )\Microsoft\Windows\Start Menu\Programs\Startup\$( $syncHash.Data.msgTable.StrStartOnLoginBatFileName )"
	$syncHash.Data.SuiteSettings.RunsAtLogin = $false
} )

$syncHash.Controls.Window.Add_Loaded( {
	$syncHash.Controls.Window.Resources['CvsModules'].View.Refresh()
	$syncHash.Controls.Window.Resources['CvsQuickAccessWordList'].View.Refresh()
	$syncHash.Controls.ChbRunOnLogin.IsChecked = $syncHash.Data.SuiteSettings.RunsAtLogin
} )

Export-ModuleMember

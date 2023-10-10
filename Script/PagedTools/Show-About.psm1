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
	$syncHash.Controls.Window.Resources['CvsModules'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	$syncHash.Controls.Window.Resources['ValueTtDescription'] = $syncHash.Data.msgTable.ContentTblValueTtDescription
	$syncHash.Controls.Window.Resources['ValueTtPath'] = $syncHash.Data.msgTable.ContentTblValueTtPath
	$syncHash.Controls.Window.Resources['ValueTtVersion'] = $syncHash.Data.msgTable.ContentTblValueTtVersion
}

################### Start script
$controls = [System.Collections.ArrayList]::new()

BindControls $syncHash $controls
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

$syncHash.Controls.Window.Add_Loaded( {
	$syncHash.Controls.Window.Resources['CvsModules'].View.Refresh()
} )

Export-ModuleMember

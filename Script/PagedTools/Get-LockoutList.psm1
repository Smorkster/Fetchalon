<#
.Synopsis
	Show when account has been locked
.Description
	Get a list of all instances when an account has been locked
.MenuItem
	Show lock list
.ObjectOperations
	User
.State
	Prod
.Author
	Smorkster (smorkster)
#>

Add-Type -AssemblyName PresentationFramework
$syncHash = $args[0]

function Set-Localizations
{
	$syncHash.Controls.Window.Resources['CvsLockouts'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	$syncHash.Controls.DgLockouts.Columns[0].Header = $syncHash.Data.msgTable.ContentDgLockoutsColDate
	$syncHash.Controls.DgLockouts.Columns[1].Header = $syncHash.Data.msgTable.ContentDgLockoutsColUserName
	$syncHash.Controls.DgLockouts.Columns[2].Header = $syncHash.Data.msgTable.ContentDgLockoutsColComputer
	$syncHash.Controls.DgLockouts.Columns[3].Header = $syncHash.Data.msgTable.ContentDgLockoutsColDomain
}

######################### Script start

Set-Localizations

$syncHash.Controls.BtnSearch.Add_Click( {
	$syncHash.Controls.Window.Resources['CvsLockouts'].Source.Clear()
	$syncHash.Controls.Window.Resources['CvsLockouts'].View.Refresh()
	$syncHash.Controls.LblNoLockOutFound.Visibility = [System.Windows.Visibility]::Hidden

	if ( [string]::IsNullOrEmpty( $syncHash.Controls.TbSearchId.Text ) )
	{
		$SAN = "\w*"
	}
	else
	{
		$SAN = $syncHash.Controls.TbSearchId.Text
	}

	if ( [string]::IsNullOrEmpty( $syncHash.Controls.TbSearchComputer.Text ) )
	{
		$Computer = "\w*"
	}
	else
	{
		$Computer = $syncHash.Controls.TbSearchComputer.Text
	}

	if ( [string]::IsNullOrEmpty( $syncHash.Controls.TbSearchDomain.Text ) )
	{
		$Domain = "\w*"
	}
	else
	{
		$Domain = $syncHash.Controls.TbSearchDomain.Text
	}

	$Pattern = "$( $SAN )\s*$( $Computer )\s$( $Domain )"

	$LogList = if ( $syncHash.Controls.RbLastWeek.IsChecked )
	{
		if ( $null -eq ( $Date = $syncHash.Controls.DpSearchDate.SelectedDate ) )
		{
			$Date = ( Get-Date ).AddDays( -7 )
		}

		Get-ChildItem -Path $syncHash.Data.msgTable.CodeLockoutAddress | `
			Where-Object { $_.LastWriteTime -gt ( Get-Date ).AddDays( -7 ) } | `
			Select-String -Pattern $Pattern | `
			Where-Object { $_ } | `
			ForEach-Object { $_.Line }
	}
	else
	{
		Get-Content -Path "$( $syncHash.Data.msgTable.CodeLockoutAddress )\$( $syncHash.Controls.DpSearchDate.SelectedDate.ToShortDateString() )_LogLockedOut.txt" | `
			Where-Object { $_ -match $Pattern }
	}

	if ( $LogList.Count -eq 0 )
	{
		$syncHash.Controls.LblNoLockOutFound.Visibility = [System.Windows.Visibility]::Visible
	}
	else
	{
		$LogList | `
			ForEach-Object {
				$Date, $User, $Computer, $Domain = $_ -split "`t"
				[pscustomobject]@{ Date = $Date ; UserName = $User ; Computer = $Computer ; Domain  = $Domain }
			} | `
			Sort-Object @{ Expression = { $_.Date } ; Descending = $true } | `
			ForEach-Object {
				$syncHash.Controls.Window.Resources['CvsLockouts'].Source.Add( $_ )
			}
	}
	$syncHash.Controls.Window.Resources['CvsLockouts'].View.Refresh()
} )

$syncHash.Controls.TbSearchComputer.Add_TextChanged( {
	$syncHash.Controls.Window.Resources['CvsLockouts'].Source.Clear()
	$syncHash.Controls.Window.Resources['CvsLockouts'].View.Refresh()
} )

$syncHash.Controls.TbSearchDomain.Add_TextChanged( {
	$syncHash.Controls.Window.Resources['CvsLockouts'].Source.Clear()
	$syncHash.Controls.Window.Resources['CvsLockouts'].View.Refresh()
} )

$syncHash.Controls.TbSearchId.Add_TextChanged( {
	$syncHash.Controls.Window.Resources['CvsLockouts'].Source.Clear()
	$syncHash.Controls.Window.Resources['CvsLockouts'].View.Refresh()
} )

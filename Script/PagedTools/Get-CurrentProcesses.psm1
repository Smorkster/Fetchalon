<#
.Synopsis
	Download active processes on the computer
.Description
	Download active processes on the computer
.MenuItem
	List processes
.SubMenu
	List
.SearchedItemRequest
	Required
.ObjectOperations
	computer
.State
	Prod
.Author
	Smorkster (smorkster)
#>

Add-Type -AssemblyName PresentationFramework
$syncHash = $args[0]

function Reset
{
	$syncHash.Controls.TblMessages.Text = ""
	$syncHash.Controls.Window.Resources['CvsProcesses'].Source.Clear()
}

function Set-Localizations
{
	$syncHash.Controls.Window.Resources['CvsProcesses'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()

	$syncHash.Controls.Window.Resources['TtComputerNotFound'].Content = $syncHash.Data.msgTable.ErrComputerNotFound

	$syncHash.Controls.DgProcesses.Columns[0].Header = $syncHash.Data.msgTable.ContentDgProcessesColId
	$syncHash.Controls.DgProcesses.Columns[1].Header = $syncHash.Data.msgTable.ContentDgProcessesColName
	$syncHash.Controls.DgProcesses.Columns[2].Header = $syncHash.Data.msgTable.ContentDgProcessesColProcessName
	$syncHash.Controls.DgProcesses.Columns[3].Header = $syncHash.Data.msgTable.ContentDgProcessesColMainWindowTitle
}

################# Script start
$controls = [System.Collections.ArrayList]::new()

BindControls $syncHash $controls

Set-Localizations

# Get all active processes
$syncHash.Controls.BtnConnect.Add_Click( {
	try
	{
		Reset
		$syncHash.Controls.Window.Resources['CvsProcesses'].Source.Clear()
		Get-Process -ComputerName $syncHash.Data.FoundComputer.Name -ErrorAction Stop | `
			Select-Object Name, MainWindowTitle, Id, ProcessName, @{ Name = "Process" ; Expression = { $_ } } | `
			ForEach-Object {
				$syncHash.Controls.Window.Resources['CvsProcesses'].Source.Add( $_ ) | Out-Null
				$syncHash.Controls.Window.Resources['CvsProcesses'].View.Refresh()
			}
	}
	catch
	{
		$syncHash.Controls.TblMessages.Text = $syncHash.Data.msgTable.ErrCouldntConnect
	}
} )

# Stop selected process
$syncHash.Controls.BtnKillProcess.Add_Click( {
	$syncHash.Controls.TblMessages.Text = ""
	try
	{
		Invoke-Command -ComputerName $syncHash.Data.FoundComputer.Name -Scriptblock {
			param ( $Process )
			Stop-Process -InputObject $Process -ErrorAction Stop
		} -ArgumentList $syncHash.Controls.DgProcesses.SelectedItem.Process
	}
	catch
	{
		$syncHash.Controls.TblMessages.Text = $_.Exception.Message
	}
} )

# Verify that entered text matches an existing computer
$syncHash.Controls.TbComputerName.Add_TextChanged( {
	Reset
	if ( $this.Text -match "\w{5}\d{8}" )
	{
		if ( $null -eq ( $syncHash.Data.FoundComputer = Get-ADComputer -Identity $this.Text ) )
		{
			$syncHash.Controls.Window.Resources['TtComputerNotFound'].IsOpen = $true
			$this.Foreground = "Red"
		}
		else
		{
			$this.Foreground = "LimeGreen"
			$syncHash.Controls.BtnConnect.IsEnabled = $true
		}
	}
	else
	{
		$this.Foreground = "#FF444444"
		$syncHash.Controls.BtnConnect.IsEnabled = $false
	}
} )

# Enter name from SearchedItem
$syncHash.Controls.Window.Add_IsVisibleChanged( {
	if ( $this.IsVisible -and ( $null -eq $syncHash.Data.FoundComputer ) )
	{
		$syncHash.Controls.TbComputerName.Text = $syncHash.Controls.Window.Resources['SearchedItem'].AD.Name
	}
	$syncHash.Controls.TbComputerName.Focus()
} )

Export-ModuleMember

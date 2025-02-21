<#
.Synopsis
	View queued prints
.Description
	View documents that are in the queue, as well as clear the queue
.MenuItem
	Show queue
.SearchedItemRequest
	Allowed
.State
	Prod
.ObjectOperations
	PrintQueue
.Author
	Smorkster (smorkster)
#>

Add-Type -AssemblyName PresentationFramework
$syncHash = $args[0]

function Set-Localizations
{
	$syncHash.Controls.Window.Resources['CvsJobs'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	$syncHash.Controls.BtnGetJobs.IsEnabled = $false

	$syncHash.Controls.DgPrintJobs.Columns[0].Header = $syncHash.Data.msgTable.ContentDgColJobStatus
	$syncHash.Controls.DgPrintJobs.Columns[1].Header = $syncHash.Data.msgTable.ContentDgColDocumentName
	$syncHash.Controls.DgPrintJobs.Columns[2].Header = $syncHash.Data.msgTable.ContentDgColSize
	$syncHash.Controls.DgPrintJobs.Columns[3].Header = $syncHash.Data.msgTable.ContentDgColSubmittedTime
	$syncHash.Controls.DgPrintJobs.Columns[4].Header = $syncHash.Data.msgTable.ContentDgColUserName

}

################### Start script
$controls = [System.Collections.ArrayList]::new()

BindControls $syncHash $controls
Set-Localizations
$syncHash.Data.Test = [System.Collections.ArrayList]::new()

#
$syncHash.Controls.BtnClearJobs.Add_Click( {
	$syncHash.Controls.DgPrintJobs.ItemsSource | `
		ForEach-Object {
			Remove-PrintJob $_.Job
		}
	$syncHash.Controls.Window.Resources['CvsJobs'].Source.Clear()
	$syncHash.Controls.Window.Resources['CvsJobs'].View.Refresh()
} )

#
$syncHash.Controls.BtnGetJobs.Add_Click( {
	Get-PrintJob -ComputerName $syncHash.Data.FoundPrinter.serverName -PrinterName $syncHash.Data.FoundPrinter.Name | `
		Select-Object "JobStatus", "DocumentName", "Size", "SubmittedTime", "UserName",
			@{ Name = "Job"; Expression = { $_ } } | `
		ForEach-Object {
			$syncHash.Controls.Window.Resources['CvsJobs'].Source.Add( ( $_ | Select-Object * ) )
		}

	if ( 0 -eq $syncHash.Controls.Window.Resources['CvsJobs'].Source.Count )
	{
		$syncHash.Controls.Window.Resources['CvsJobs'].Source.Add( ( [pscustomobject]@{ JobStatus = $syncHash.Data.msgTable.StrNoQueueJobStatus } ) )
	}
} )

#
$syncHash.Controls.TbPrintQueueName.Add_TextChanged( {
	$this.Foreground = "#FF444444"
	$syncHash.Controls.Window.Resources['TtPrintQueueName'].IsEnabled = $false
	$syncHash.Controls.BtnGetJobs.IsEnabled = $false

	if ( $this.Text -match "^\w{3}_.*_.*\d{1}_\d{2}$" )
	{
		$syncHash.Controls.Window.Resources['CvsJobs'].Source.Clear()
		$syncHash.Controls.Window.Resources['CvsJobs'].View.Refresh()

		if  ( $syncHash.Data.FoundPrinter = Get-ADObject -LDAPFilter "(&(Name=$( $syncHash.Controls.TbPrintQueueName.Text ))(ObjectClass=printQueue))" -Properties * | Select-Object * )
		{
			$this.Foreground = "LimeGreen"
			$syncHash.Controls.Window.Resources['TtPrintQueueName'].Content = ""
			$syncHash.Controls.Window.Resources['TtPrintQueueName'].IsOpen = $false
			$syncHash.Controls.BtnGetJobs.IsEnabled = $true
		}
		else
		{
			$this.Foreground = "Red"
			$syncHash.Controls.Window.Resources['TtPrintQueueName'].IsEnabled = $true
			$syncHash.Controls.Window.Resources['TtPrintQueueName'].Content = $syncHash.Data.msgTable.ErrNoPrintQueue
			$syncHash.Controls.Window.Resources['TtPrintQueueName'].IsOpen = $true
		}
	}
} )

$syncHash.Controls.Window.Add_IsVisibleChanged( {
	$syncHash.Data.Test.Add(1)|Out-Null
	if ( $syncHash.Controls.Window.IsVisible )
	{
		$syncHash.Data.Test.Add(2)|Out-Null
		if ( [string]::IsNullOrEmpty( $syncHash.Controls.TbPrintQueueName.Text ) )
		{
			$syncHash.Data.Test.Add(3)|Out-Null
			$syncHash.Controls.TbPrintQueueName.Text = $syncHash.Controls.Window.Resources['SearchedItem'].AD.Name
		}
		elseif ( -not [string]::Equals( ( $syncHash.Controls.Window.Resources['SearchedItem'].AD.Name ) , $syncHash.Controls.TbPrintQueueName.Text ) )
		{
			$syncHash.Data.Test.Add(4)|Out-Null
			if ( "Yes" -eq ( Show-MessageBox -Text $syncHash.Data.msgTable.StrSwitchPrinterName -Button "YesNo" ) )
			{
				$syncHash.Data.Test.Add(5)|Out-Null
				$syncHash.Controls.TbPrintQueueName.Text = ( $syncHash.Controls.Window.Resources['SearchedItem'].AD.Name )
			}
		}
	}
} )

Export-ModuleMember

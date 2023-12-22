<#
.Synopsis
	Test connection to target
.Description
	Testing to reach target 
.ObjectOperations
	Computer
.State
	Prod
.Author
	Smorkster (smorkster)
#>

Add-Type -AssemblyName PresentationFramework
Import-Module ActiveDirectory
$syncHash = $args[0]

function Reset
{
	<#
	.Synopsis
		Reset data to default value
	#>

	$syncHash.Controls.Window.Resources['CvsTestConnResults'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	$syncHash.Controls.PbRunningTest.Visibility = [System.Windows.Visibility]::Collapsed
	$syncHash.Controls.TbTarget.Text = ""

	$syncHash.Controls.TbBufferSize.Text = "32"
	$syncHash.Controls.TbCount.Text = "4"
	$syncHash.Controls.TbDelay.Text = "1"
	$syncHash.Controls.TbThrottleLimit.Text = "32"
	$syncHash.Controls.TbTimeToLive.Text = "128"
	$syncHash.Controls.CbDcomAuthentication.SelectedIndex = 4
	$syncHash.Controls.CbImpersonation.SelectedIndex = 3
	$syncHash.Controls.CbProtocol.SelectedIndex = 0
	$syncHash.Controls.CbWsmanAuthentication.SelectedIndex = 0
}

##################### Scriptstart

$syncHash.Data.T = [System.Collections.ArrayList]::new()

$syncHash.Controls.GetEnumerator() | `
	Where-Object { $_.Name -cmatch "Tb[^a-z](?!arget)" } | `
	ForEach-Object {
		$_.Value.Add_PreviewKeyDown( {
			$syncHash.Data.T.Add($args)|Out-Null
			if ( $args[1].SystemKey -eq "None" )
			{
				$args[1].Handled = $args[1].Key -notmatch "\d|(Ctrl)|(Alt)|(Back)|(F\d)|(Tab)"
			}
		} )
	}

# Reset default values
$syncHash.Controls.BtnReset.Add_Click( {
	Reset
} )

# Add to PageSize number
$syncHash.Controls.BtnStart.Add_Click( {
	$syncHash.Controls.Window.Resources['CvsTestConnResults'].Source.Clear()
	$syncHash.Controls.Window.Resources['CvsTestConnResults'].View.Refresh()
	$syncHash.Controls.ExpSettings.IsExpanded = $false
	$syncHash.Controls.PbRunningTest.Visibility = [System.Windows.Visibility]::Visible

	$TestSettings = @{
		AsJob = $true
		BufferSize = $syncHash.Controls.TbBufferSize.Text
		ComputerName = $syncHash.Controls.TbTarget.Text
		Count = $syncHash.Controls.TbCount.Text
		Delay = $syncHash.Controls.TbDelay.Text
		ThrottleLimit = $syncHash.Controls.TbThrottleLimit.Text
		TimeToLive = $syncHash.Controls.TbTimeToLive.Text
	}

	switch ( $syncHash.Controls.CbProtocol.SelectedIndex )
	{
		"0" {
		}
		"1" {
			$TestSettings.DcomAuthentication = $syncHash.Controls.CbDcomAuthentication.SelectedItem.Content
			$TestSettings.Impersonation = $syncHash.Controls.CbImpersonation.SelectedItem.Content
			$TestSettings.Protocol = $syncHash.Controls.CbProtocol.SelectedItem.Content
		}
		"2" {
			$TestSettings.Protocol = $syncHash.Controls.CbProtocol.SelectedItem.Content
			$TestSettings.WsmanAuthentication = $syncHash.Controls.CbWsmanAuthentication.SelectedItem.Content
		}
	}

	$syncHash.Jobs.TestJob = Test-Connection @TestSettings
	Wait-Job $syncHash.Jobs.TestJob
	$TempRes = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	$syncHash.Controls.Window.Resources['CvsTestConnResults'].Source = ( Receive-Job $syncHash.Jobs.TestJob )

	$syncHash.Controls.Window.Resources['CvsTestConnResults'].View.Refresh()
	$syncHash.Controls.PbRunningTest.Visibility = [System.Windows.Visibility]::Collapsed
	$syncHash.Data.TestSettings = $TestSettings

} )

# Window is first loaded
$syncHash.Controls.Window.Add_Loaded( {

	Reset
} )

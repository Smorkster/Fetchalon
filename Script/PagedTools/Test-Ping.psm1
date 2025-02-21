<#
.Synopsis
	Test connection to target
.Description
	Testing to reach target 
.MenuItem
	Ping computer/IP
.ObjectOperations
	Computer
.EnableQuickAccess
	ping
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

$syncHash.Data.StatusCode_ReturnValue = @{
	0 = 'Success'
	11001 = 'Buffer Too Small'
	11002 = 'Destination Net Unreachable'
	11003 = 'Destination Host Unreachable'
	11004 = 'Destination Protocol Unreachable'
	11005 = 'Destination Port Unreachable'
	11006 = 'No Resources'
	11007 = 'Bad Option'
	11008 = 'Hardware Error'
	11009 = 'Packet Too Big'
	11010 = 'Request Timed Out'
	11011 = 'Bad Request'
	11012 = 'Bad Route'
	11013 = 'TimeToLive Expired Transit'
	11014 = 'TimeToLive Expired Reassembly'
	11015 = 'Parameter Problem'
	11016 = 'Source Quench'
	11017 = 'Option Too Big'
	11018 = 'Bad Destination'
	11032 = 'Negotiating IPSEC'
	11050 = 'General Failure'
}

Reset

# Reset default values
$syncHash.Controls.BtnReset.Add_Click( {
	Reset
} )

# Run connection test
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

	Receive-Job $syncHash.Jobs.TestJob | `
		ForEach-Object {
			$Res = $_
			$FriendlyStatus =  if ( $Res.StatusCode -eq $null )
			{
				"N/A"
			}
			else
			{
				$syncHash.Data.StatusCode_ReturnValue[( [int]$Res.StatusCode )]
			}
			Add-Member -InputObject $Res -MemberType NoteProperty -Name "FriendlyStatus" -Value $FriendlyStatus

			$syncHash.Controls.Window.Resources['CvsTestConnResults'].Source.Add( ( $Res | Select-Object * ) )
		}

	$syncHash.Controls.Window.Resources['CvsTestConnResults'].View.Refresh()
	$syncHash.Controls.PbRunningTest.Visibility = [System.Windows.Visibility]::Collapsed
} )

#
$syncHash.Controls.Window.Add_IsVisibleChanged( {
	if ( $this.IsVisible )
	{
		if ( -not [string]::IsNullOrEmpty( $syncHash.Controls.Window.Resources.QuickAccessParam ) )
		{
			$syncHash.Controls.TbTarget.Text = ( $syncHash.Controls.Window.Resources.QuickAccessParam )
			$syncHash.Controls.BtnStart.RaiseEvent( [System.Windows.Controls.Button]::ClickEvent )
		}
		elseif ( $syncHash.Controls.Window.Resources.SearchedItem.AD.Enabled -eq $true )
		{
			$syncHash.Controls.TbTarget.Text = $syncHash.Controls.Window.Resources.SearchedItem.AD.Name
		}
		$syncHash.Controls.TbTarget.Focus()
	}
} )

# Window is first loaded
$syncHash.Controls.Window.Add_Loaded( {
	if ( $syncHash.Controls.Window.Resources.SearchedItem.AD.Enabled -eq $true )
	{
		$syncHash.Controls.TbTarget.Text = $syncHash.Controls.Window.Resources.SearchedItem.AD.Name
	}
	$syncHash.Controls.TbTarget.Focus()
} )

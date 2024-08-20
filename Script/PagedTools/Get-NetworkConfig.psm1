<#
.Synopsis
	Get network and IP configuration
.Description
	Get information about networkconfiguration and active IP-addresses
.MenuItem
	Get network information
.SubMenu
	Network
.SearchedItemRequest
	Allowed
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

################# Script start

#
$syncHash.Controls.BtnGet.Add_Click( {
$syncHash.Controls.Window.Resources['CvsIpAddresses'].Source = [System.Collections.ObjectModel.ObservableCollection[pscustomobject]]::new()
$syncHash.Controls.Window.Resources['CvsIpConfigs'].Source = [System.Collections.ObjectModel.ObservableCollection[pscustomobject]]::new()
	$syncHash.Controls.Window.Resources.CvsIpConfigs.View.Refresh()
	$syncHash.Controls.Window.Resources.CvsIpAddresses.View.Refresh()

	$syncHash.Data.Cs = New-CimSession -ComputerName $syncHash.Controls.TbComputer.Text

	Get-NetIPConfiguration -All -Detailed -CimSession $syncHash.Window.Resources.LoadedPageGetNetworkConfig.Data.Cs -WarningAction SilentlyContinue | `
		Select-Object -ExcludeProperty *CimClass*, *CimInstanceProperties*, *CimSystemProperties*, *PSComputerName*, *PSShowComputerName* -Property * | `
		ForEach-Object {
			$a = @{}
			$_.psobject.properties | `
			ForEach-Object {
				if ( $_.Value -is [ciminstance[]] )
				{
					$l = [System.Collections.ArrayList]::new()
					$_.Value | ForEach-Object { $l.Add( ( $_.Tostring() ) ) | Out-Null }
					$a."$( $_.Name )" = $l -join " | "
				}
				else
				{
					$a."$( $_.Name )" = $_.Value
				}
			}
			$syncHash.Controls.Window.Resources['CvsIpConfigs'].Source.Add( ( [pscustomobject] $a ) )
		}
	$syncHash.Controls.Window.Resources.CvsIpConfigs.View.Refresh()

	Get-NetIPAddress -CimSession $syncHash.Data.Cs | `
		Select-Object -ExcludeProperty *CimClass*, *CimInstanceProperties*, *CimSystemProperties*, *PSComputerName*, *PSShowComputerName* -Property * | `
		ForEach-Object {
			$a = @{}
			$_.psobject.properties | `
			ForEach-Object {
				if ( $_.Value -is [ciminstance[]] )
				{
					$l = [System.Collections.ArrayList]::new()
					$_.Value | ForEach-Object { $l.Add( ( $_.Tostring() ) ) | Out-Null }
					$a."$( $_.Name )" = $l -join " | "
				}
				else
				{
					$a."$( $_.Name )" = $_.Value
				}
			}
			$syncHash.Controls.Window.Resources['CvsIpAddresses'].Source.Add( ( [pscustomobject] $a ) )
		}
	$syncHash.Controls.Window.Resources.CvsIpAddresses.View.Refresh()
	#>
} )

# UI is made visible
$syncHash.Controls.Window.Add_IsVisibleChanged( {
	if ( $this.IsVisible )
	{
		$syncHash.Controls.TbComputer.Text = $syncHash.Controls.Window.Resources['SearchedItem'].Name
	}
	$syncHash.Controls.TbComputer.Focus()
} )

Export-ModuleMember

<#
.Synopsis Visa applikationer
.MenuItem Visa applikationer
.Description Visa och avinstallera applikationer på dator
.Depends WinRM
.State Prod
.ObjectOperations computer
.Author Carl Franzén (6G1W)
#>

Add-Type -AssemblyName PresentationFramework
$syncHash = $args[0]

function Reset
{
	<#
	.Synopsis Resets controls
	#>

	$syncHash.Controls.Window.Resources['CvsApps'].Source.Clear()
	$syncHash.DC.TbProgressInfo[0] = $syncHash.Data.msgTable.ContentDefWinTit
	$syncHash.DC.TbProgressInfo[1] = "Black"
}

################### Start script
$controls = [System.Collections.ArrayList]::new()
[void]$controls.Add( @{ CName = "BtnGetAppList" ; Props = @( @{ PropName = "IsEnabled"; PropVal = $true } ) } )
[void]$controls.Add( @{ CName = "BtnUninstall" ; Props = @( @{ PropName = "IsEnabled"; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "PbUninstallations" ; Props = @( @{ PropName = "IsIndeterminate"; PropVal = $false } ; @{ PropName = "Value"; PropVal = [double] 0 } ) } )
[void]$controls.Add( @{ CName = "TbProgressInfo" ; Props = @( @{ PropName = "Text"; PropVal = "" } ; @{ PropName = "Foreground" ; PropVal = "Black" } ) } )

BindControls $syncHash $controls

$syncHash.Controls.Window.Resources['CvsApps'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()

$syncHash.Code.GetApps = {
	$Apps = @()
	$32BitPath = "SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
	$64BitPath = "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"

	$Apps += Get-ItemProperty -Path "HKLM:\$32BitPath" | ForEach-Object { [pscustomobject]@{ Source = "Global32" ; App = $_ } }
	$Apps += Get-ItemProperty -Path "HKLM:\$64BitPath" | ForEach-Object { [pscustomobject]@{ Source = "Global64" ; App = $_ } }

	$Apps += Get-ItemProperty "Registry::\HKEY_CURRENT_USER\$32BitPath" | ForEach-Object { [pscustomobject]@{ Source = "CurrentUser32" ; App = $_ } }
	$Apps += Get-ItemProperty "Registry::\HKEY_CURRENT_USER\$64BitPath" | ForEach-Object { [pscustomobject]@{ Source = "CurrentUser64" ; App = $_ } }

	$AllProfiles = Get-CimInstance Win32_UserProfile | Select-Object LocalPath, SID, Loaded, Special | Where-Object { $_.SID -like "S-1-5-21-*" }
	$MountedProfiles = $AllProfiles | Where-Object { $_.Loaded -eq $true }
	$UnmountedProfiles = $AllProfiles | Where-Object { $_.Loaded -eq $false }

	$MountedProfiles | `
		ForEach-Object {
			$U = $_
			$Apps += Get-ItemProperty -Path "Registry::\HKEY_USERS\$( $_.SID )\$32BitPath" | ForEach-Object { [pscustomobject]@{ Source = "User32" ; App = $_ ; User = ( $U.LocalPath -split "\\" )[-1] } }
			$Apps += Get-ItemProperty -Path "Registry::\HKEY_USERS\$( $_.SID )\$64BitPath" | ForEach-Object { [pscustomobject]@{ Source = "User64" ; App = $_ ; User = ( $U.LocalPath -split "\\" )[-1] } }
		}

	$UnmountedProfiles | `
		ForEach-Object {
			$U = $_
			$Hive = "$( $_.LocalPath )\NTUSER.DAT"

			if ( Test-Path $Hive )
			{
				REG LOAD HKU\temp $Hive

				$Apps += Get-ItemProperty -Path "Registry::\HKEY_USERS\temp\$32BitPath" | ForEach-Object { [pscustomobject]@{ Source = "User32" ; App = $_ ; User = ( $U.LocalPath -split "\\" )[-1] } }
				$Apps += Get-ItemProperty -Path "Registry::\HKEY_USERS\temp\$64BitPath" | ForEach-Object { [pscustomobject]@{ Source = "User64" ; App = $_ ; User = ( $U.LocalPath -split "\\" )[-1] } }

				# Run manual GC to allow hive to be unmounted
				[GC]::Collect()
				[GC]::WaitForPendingFinalizers()
			
				REG UNLOAD HKU\temp
			} else {
				"$( $syncHash.Data.msgTable.ErrHiveNotAccessible ): $Hive"
			}
		}
	$Apps
}

$syncHash.Data.UninstallLog = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
$syncHash.Data.UninstallLog.Add_CollectionChanged( {
	if ( $this[-1].ErrorText.Length -gt 0 )
	{
		$eh = WriteErrorlogTest -LogText $this[-1].ErrorText -Severity "OtherFail" -ComputerName $syncHash.Controls.TbComputerName.Text
	}
	$OFS = ", "
	WriteLogTest -Text "$( $this[-1].SuccessText )" -UserInput $syncHash.Controls.TbComputerName.Text -Success ( $this[-1].SuccessText.Length -gt 0 ) -ErrorLogHash $eh | Out-Null
} )

# Get list of applications
$syncHash.Controls.BtnGetAppList.Add_Click( {
	Reset
	try
	{
		$syncHash.Jobs.PUninstall.EndInvoke()
		$syncHash.Jobs.PUninstall.Dispose()
	} catch {}

	$syncHash.DC.TbProgressInfo[0] = $syncHash.Data.msgTable.ContentDefWinTit
	$syncHash.DC.PbUninstallations[0] = $true
	$syncHash.Jobs.PFetch = [powershell]::Create().AddScript( { param ( $syncHash, $Modules )
		Import-Module $Modules

		try
		{
			$syncHash.Data.Temp = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
			Invoke-Command -ComputerName $syncHash.Data.ComputerName-ScriptBlock $syncHash.Code.GetApps -ErrorAction Stop | `
				Where-Object { $null -ne $_.App.DisplayName } |`
				Select-Object -Property @{ Name = "Name" ; Expression = { if ( $null -eq $_.App.DisplayName ) { $_.App.ParentDisplayName } else { $_.App.DisplayName } } }, `
							@{ Name = "Installed" ; Expression = { try { ( [datetime]::ParseExact( $_.App.InstallDate, "yyyyMMdd", $null ) ).ToShortDateString() } catch { 0 } } }, `
							@{ Name = "ID" ; Expression = { $_.App.IdentifyingNumber } }, `
							@{ Name = "RegItem" ; Expression = { $_.App } }, `
							@{ Name = "Source" ; Expression = { $_.Source } }, `
							@{ Name = "User" ; Expression = { if ( $null -ne $_.User ) { ( Get-ADUser -Identity $_.User ).Name } else { $syncHash.Data.msgTable.StrAllUsers } } } | `
				Sort-Object User, Name | `
				ForEach-Object { $syncHash.Data.Temp.Add( $_ ) | out-null }
			$syncHash.Controls.Window.Dispatcher.Invoke( [action] {
				$syncHash.Controls.Window.Resources['CvsApps'].Source = $syncHash.Data.Temp
			} )
		}
		catch
		{
			$syncHash.Errors.Add( $_ ) | Out-Null
			$syncHash.DC.TbProgressInfo[0] = $_
			$syncHash.DC.TbProgressInfo[1] = "Red"
		}
		$syncHash.DC.PbUninstallations[0] = $false
	} )
	$syncHash.Jobs.PFetch.AddArgument( $syncHash )
	$syncHash.Jobs.PFetch.AddArgument( ( Get-Module ) )
	$syncHash.Jobs.HFetch = $syncHash.Jobs.PFetch.BeginInvoke()
} )

# Uninstall the selected application
$syncHash.Controls.BtnUninstall.Add_Click( {
	$syncHash.DC.TbProgressInfo[0] = ""
	$syncHash.DC.TbProgressInfo[1] = "Black"
	if ( $syncHash.Controls.DgAppList.SelectedItems.Count -gt 10 ) { $summary = "$( $syncHash.Controls.DgAppList.SelectedItems.Count ) $( $syncHash.Data.msgTable.StrAppSum )" }
	else { $summary = "`n`n$( $ofs = "`n"; [string] $syncHash.Controls.DgAppList.SelectedItems.Name )" }

	if ( [System.Windows.MessageBox]::Show( "$( $syncHash.Data.msgTable.QUninstall ) $summary", "", [System.Windows.MessageBoxButton]::YesNo ) -eq "Yes" )
	{
		$syncHash.Jobs.PUninstall = [powershell]::Create().AddScript( { param ( $syncHash, $list )
			$Errors = [System.Collections.ArrayList]::new()
			$Success = [System.Collections.ArrayList]::new()
			for ( $c = 0; $c -lt $list.Count; $c++ )
			{
				$syncHash.DC.TbProgressInfo[0] = "$( $syncHash.Data.msgTable.StrUninstalling ) $( $list[$c].Name )"
				try
				{
					Get-CimInstance -ComputerName $syncHash.Data.ComputerName -Query "SELECT * FROM win32_product WHERE IdentifyingNumber LIKE '$( $list[$c].ID )'" | Remove-CimInstance
					[void] $Success.Add( $list[$c].Name )
				}
				catch
				{
					[void] $Errors.Add( ( [pscustomobject]@{ App = $list[$c].Name ; Err = $_ } ) )
				}
				$syncHash.DC.PbUninstallations[1] = [double] ( ( $c / @( $list ).Count ) * 100 )
			}
			$ErrText = $Errors | ForEach-Object { "$( $_.App ) $( $_.Err )" }
			$SuccessText = $Success | Sort-Object | ForEach-Object { "$_" }
			[void] $syncHash.Data.UninstallLog.Add( ( [pscustomobject]@{ ErrorText = $ErrText ; SuccessText = $SuccessText } ) )
			$syncHash.Window.Dispatcher.Invoke( [action] {
				$syncHash.DC.PbUninstallations[1] = 0.0
				$syncHash.DC.TbProgressInfo[0] = $syncHash.Data.msgTable.StrDone
				$syncHash.Controls.BtnGetAppList.RaiseEvent( [System.Windows.RoutedEventArgs]::new( [System.Windows.Controls.Button]::ClickEvent ) )
			} )
		} ).AddArgument( $syncHash ).AddArgument( @( $syncHash.Controls.DgAppList.SelectedItems | Where-Object { $_ } ) )
		$syncHash.Jobs.HUninstall = $syncHash.Jobs.PUninstall.BeginInvoke()
	}
} )

# If any item is selected, enable button to uninstall
$syncHash.Controls.DgAppList.Add_SelectionChanged( {
	$syncHash.DC.BtnUninstall[0] = ( $syncHash.Controls.DgAppList.SelectedItems.Count -gt 0 )
} )

#
$syncHash.Controls.TbComputerName.Add_TextChanged( {
	if ( $this.Text -match $syncHash.Data.msgTable.CodeRegExComputerName )
	{
		try
		{
			Get-ADComputer -Identity $this.Text -ErrorAction Stop | Out-Null
			$syncHash.Controls.BtnGetAppList.IsEnabled = $true
			$syncHash.Data.ComputerName = $this.Text
		}
		catch
		{
			$syncHash.Controls.BtnGetAppList.IsEnabled = $false
		}
	}
	else
	{
		$syncHash.Controls.BtnGetAppList.IsEnabled = $false
	}
} )

#
$syncHash.Controls.Window.Add_IsVisibleChanged( {
	if ( "" -eq $syncHash.Controls.TbComputerName.Text -and `
		$null -ne $syncHash.Controls.Window.Resources['SearchedItem'] -and `
		$this.IsVisible
	)
	{
		if ( $syncHash.Controls.TbComputerName.Text -ne $syncHash.Controls.Window.Resources['SearchedItem'].Name )
		{
			Reset
		}

		$syncHash.Controls.TbComputerName.Text = $syncHash.Controls.Window.Resources['SearchedItem'].Name
	}
} )

#
$syncHash.Controls.Window.Add_Loaded( {
	try { $syncHash.Controls.TbComputerName.Text = $syncHash.Controls.Window.Resources['SearchedItem'].Name }
	catch {}
} )

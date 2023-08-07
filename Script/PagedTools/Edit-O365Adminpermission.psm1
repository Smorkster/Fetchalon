<#
.Synopsis
	List and administer permissions to Exchange accounts
.MenuItem
	Exchange account permissions
.Description
	List all accounts to which full authorization has been linked. Can also add and remove permissions
.Depends
	ExchangeAdministrator
.State
	Prod
.Author
	Smorkster (smorkster)
#>

Add-Type -AssemblyName PresentationFramework
$syncHash = $args[0]

function SetLocalizations
{
	$syncHash.Controls.Window.Resources['CvsIcRecipientTypes'].Source = [System.Collections.ObjectModel.ObservableCollection[Object]]::new()
	$syncHash.Controls.Window.Resources['CvsLbAdminPermissions'].Source = [System.Collections.ObjectModel.ObservableCollection[Object]]::new()
	$syncHash.Controls.Window.Resources['CvsDgAdminPermissions'].Source = [System.Collections.ObjectModel.ObservableCollection[Object]]::new()
	$syncHash.Controls.IcRecipientTypes.Resources['StrSearchTime'] = $syncHash.Data.msgTable.StrSearchTime
	$syncHash.Controls.IcRecipientTypes.Resources['StrPermCount'] = $syncHash.Data.msgTable.StrPermCount
	$syncHash.Controls.IcRecipientTypes.Resources['StrPermPercentage'] = $syncHash.Data.msgTable.StrPermPercentage
	$syncHash.Controls.IcRecipientTypes.Resources['StrTotalCount'] = $syncHash.Data.msgTable.StrTotalCount

	$syncHash.Controls.DgAdminPermissions.Columns[0].Header = $syncHash.Data.msgTable.ContentDgAdminPermissionsColDisplayName
	$syncHash.Controls.DgAdminPermissions.Columns[1].Header = $syncHash.Data.msgTable.ContentDgAdminPermissionsColPrimarySmtpAddress
	$syncHash.Controls.DgAdminPermissions.Columns[2].Header = $syncHash.Data.msgTable.ContentDgAdminPermissionsColRecipientTypeDetails
}

################### Start script
$controls = [System.Collections.ArrayList]::new()
[void] $controls.Add( @{ CName = "BtnSearchAdminPermission" ; Props = @( @{ PropName = "IsEnabled"; PropVal = $true } ) } )

BindControls $syncHash $controls
SetLocalizations
$syncHash.Data.EnumRecipientTypeDetails = @( "MailUser", "UserMailbox", "RoomMailbox", "LinkedRoomMailbox", "EquipmentMailbox", "SchedulingMailbox", "LegacyMailbox", "LinkedMailbox", "DynamicDistributionGroup", "MailForestContact", "MailNonUniversalGroup", "MailUniversalDistributionGroup", "MailUniversalSecurityGroup", "RoomList", "GroupMailbox", "DiscoveryMailbox", "PublicFolder", "TeamMailbox", "SharedMailbox", "RemoteUserMailbox", "RemoteRoomMailbox", "RemoteEquipmentMailbox", "RemoteTeamMailbox", "RemoteSharedMailbox", "PublicFolderMailbox", "SharedWithMailUser" )

$syncHash.Data.Rsp = [runspacefactory]::CreateRunspacePool( 1 , 5 )
$syncHash.Data.Rsp.ApartmentState = "STA"
$syncHash.Data.Rsp.ThreadOptions = "ReuseThread"
$syncHash.Data.Rsp.Open()

Import-Module $syncHash.Data.Modules -WarningAction SilentlyContinue

# Add full permission to a mailbox
$syncHash.Controls.BtnAddAdminPermission.Add_Click( {

	if ( $syncHash.Data.FoundRecipient.RecipientTypeDetails -in ( "EquipmentMailbox","RoomMailbox","SharedMailbox","UserMailbox" ) )
	{
		try
		{
			Add-MailboxPermission -Identity $syncHash.Data.FoundRecipient.PrimarySmtpAddress -User ( Get-AzureADCurrentSessionInfo ).Account.Id -AccessRights FullAccess
			Add-Content -Value $syncHash.Data.FoundRecipient.PrimarySmtpAddress -Path "$( $env:USERPROFILE )\O365Admin.txt"
			$syncHash.Controls.Window.Resources['CvsDgAdminPermissions'].Source.Add( $syncHash.Data.FoundRecipient ) | Out-Null
			$syncHash.Controls.TbAddAdminPermission.Text = ""
		}
		catch
		{
			Show-MessageBox -Text "$( $syncHash.Data.msgTable.ErrAddingPermission )`n`n$( $_.Exception.Message )" -Title $syncHash.Data.msgTable.ErrAddingPermissionTitle -Icon "Error" | Out-Null
			$eh = WriteErrorlog -LogText $_.Exception.Message -UserInput $syncHash.Controls.TbAddAdminPermission.Text -Severity "OtherFail"
		}
	}
	else
	{
		
	}
} )

# Remove permission to the selected mailboxes
$syncHash.Controls.BtnRemoveAdminPermission.Add_Click( {

	$AccountsToRemove = $syncHash.Controls.DgAdminPermissions.SelectedItems.PrimarySmtpAddress
	$AccountsToRemove | `
		ForEach-Object {
			try
			{
				Remove-MailboxPermission -Identity $_ -User ( Get-AzureADCurrentSessionInfo ).Account.Id -AccessRights FullAccess -Confirm:$false -ErrorAction Stop
				
			}
			catch
			{
				$eh += WriteErrorlogTest -LogText "$( $syncHash.Data.msgTable.ErrLogRemovePerm )`n$_" -UserInput $syncHash.lbAdminPermissions.SelectedItems[$i] -Severity "OtherFail"
			}
		}
	Set-Content -Value ( $syncHash.Controls.Window.Resources['CvsDgAdminPermissions'].Source.Where( { $_.PrimarySmtpAddress -notin $AccountsToRemove } ) ) -Path "$( $env:USERPROFILE )\O365Admin.txt"
	$syncHash.Controls.Window.Resources['CvsDgAdminPermissions'].Source.Clear()
	Get-Content -Path "$( $env:USERPROFILE )\O365Admin.txt" | `
		ForEach-Object {
			$syncHash.Controls.Window.Resources['CvsDgAdminPermissions'].Source.Add( ( Get-EXORecipient -Identity $_ ) ) | Out-Null
		}
} )

# Start searching all available recipients for full permissions
$syncHash.Controls.BtnSearchAdminPermission.Add_Click( {
	if ( ( Show-MessageBox -Text $syncHash.Data.msgTable.StrSearchContinueQuestion -Icon "Warning" -Button "YesNo" ) -eq "Yes" )
	{
		$P = [powershell]::Create()
		$P.AddScript( {
			param ( $syncHash, $Modules, $ProfilePath )

			Import-Module $Modules

			$syncHash.Controls.Window.Dispatcher.Invoke( [action] {
				$syncHash.Controls.Window.Resources['CvsLbAdminPermissions'].Source.Clear()
				$syncHash.Controls.Window.Resources['CvsDgAdminPermissions'].Source.Clear()
			} )

			$syncHash.DC.BtnSearchAdminPermission[0] = $false

			$syncHash.Data.EnumRecipientTypeDetails | `
				ForEach-Object {
					$syncHash.Controls.Window.Dispatcher.Invoke( [action] {
						$RTDObj = [pscustomobject]@{
							Name = $_
							IsIndeterminate = $true
							Value = [double] 0
							TotalBoxes = "?"
							PermPercentage = "?"
							PermCount = "?"
							SearchTime = "?"
							StartTime = $null
							EndTime = $null
						}
						$syncHash.Controls.Window.Resources['CvsIcRecipientTypes'].Source.Add( $RTDObj )
					} )

					$P = [powershell]::Create()
					$P.RunspacePool = $syncHash.Data.Rsp
					$P.AddScript( {
						param ( $syncHash, $Modules, $RTD, $AdminId )
						Import-Module $Modules

						Get-EXORecipient -ResultSize Unlimited -RecipientTypeDetails $RTD | `
							ForEach-Object `
							-Begin {
								$TotalCount = 0
								$PermCount = 0
								$StartTime = Get-Date
							} `
							-Process {
								$MailBox = $_
								if ( ( Get-EXOMailboxPermission -Identity $MailBox.PrimarySmtpAddress -ErrorAction SilentlyContinue ).User -match $AdminId )
								{
									$syncHash.Controls.Window.Dispatcher.Invoke( [action] {
										$syncHash.Controls.Window.Resources['CvsDgAdminPermissions'].Source.Add( $MailBox ) | Out-Null
									} )
									$PermCount += 1
								}
								$TotalCount += 1
							} `
							-End {
								$EndTime = Get-Date
							}

						$syncHash.Controls.Window.Dispatcher.Invoke( [action] {
							$syncHash.Controls.Window.Resources['CvsIcRecipientTypes'].Source.Where( { $_.Name -eq $RTD } )[0].StartTime = $StartTime
							$syncHash.Controls.Window.Resources['CvsIcRecipientTypes'].Source.Where( { $_.Name -eq $RTD } )[0].EndTime = $EndTime
							$syncHash.Controls.Window.Resources['CvsIcRecipientTypes'].Source.Where( { $_.Name -eq $RTD } )[0].IsIndeterminate = $false
							$syncHash.Controls.Window.Resources['CvsIcRecipientTypes'].Source.Where( { $_.Name -eq $RTD } )[0].Value = [double] 1
							$syncHash.Controls.Window.Resources['CvsIcRecipientTypes'].Source.Where( { $_.Name -eq $RTD } )[0].TotalBoxes = $TotalCount
							$syncHash.Controls.Window.Resources['CvsIcRecipientTypes'].Source.Where( { $_.Name -eq $RTD } )[0].PermCount = $PermCount
							$syncHash.Controls.Window.Resources['CvsIcRecipientTypes'].Source.Where( { $_.Name -eq $RTD } )[0].PermPercentage = [Math]::Round( ( $PermCount / $TotalCount ) * 100 , 2 )
							$syncHash.Controls.Window.Resources['CvsIcRecipientTypes'].Source.Where( { $_.Name -eq $RTD } )[0].SearchTime = ( $EndTime - $StartTime ).ToString()
							if ( 0 -eq $syncHash.Controls.Window.Resources['CvsIcRecipientTypes'].Source.Where( { $_.IsIndeterminate -eq $false } ).Count )
							{
								$syncHash.DC.BtnSearchAdminPermission[0] = $true
								TextToSpeech -Text $syncHash.Data.msgTable.StrSearchFinished
							}
							$syncHash.Controls.Window.Resources['CvsIcRecipientTypes'].View.Refresh()
						} )
					} )
					$P.AddArgument( $syncHash )
					$P.AddArgument( $Modules )
					$P.AddArgument( $_ )
					$P.AddArgument( ( Get-AzureADCurrentSessionInfo ).Account.Id )
					$syncHash.Jobs."Search$( $_ )" = [pscustomobject]@{ P = $P ; H = $P.BeginInvoke() }

				}
		} )
		$P.AddArgument( $syncHash )
		$P.AddArgument( ( Get-Module ) )
		$P.AddArgument( $env:USERPROFILE )
		$syncHash.Jobs.Search = [pscustomobject]@{ P = $P ; H = $P.BeginInvoke() }
	}
} )

# Start searching all available recipients for full permissions
$syncHash.Controls.BtnSearchAdminPermission.Add_IsEnabledChanged( {
	if ( $this.IsEnabled )
	{
		$syncHash.Jobs.GetEnumerator() | `
			Where-Object { $_.Name -match "Search\w+" } | `
			ForEach-Object {
				$_.P.Runspace.EndInvoke( $_.H ) | Out-Null
				$_.P.Runspace.Close()
				$_.P.Runspace.Dispose()
			}
	}
	[GC]::Collect()
} )

# Click occured where no item is located, unselect items
$syncHash.Controls.DgAdminPermissions.Add_MouseLeftButtonUp( {
	if ( $args[1].OriginalSource -ne "" )
	{
		if ( $this.SelectedItems.Count -lt 1 )
		{
			$this.SelectedIndex = -1
		}
	}
} )

# Click occured where no item is located, unselect items
$syncHash.Controls.DgAdminPermissions.Add_SelectionChanged( {
	$syncHash.Controls.BtnRemoveAdminPermission.IsEnabled = ( 0 -lt $this.SelectedItems.Count ) -and $syncHash.Controls.BtnSearchAdminPermission.IsEnabled
} )

# Click occured where no item is located, unselect items
$syncHash.Controls.LbAdminPermissions.Add_MouseLeftButtonUp( {
	if ( $args[1].OriginalSource -ne "" )
	{
		if ( $this.SelectedItems.Count -lt 1 )
		{
			$this.SelectedIndex = -1
		}
	}
} )

# Text is entered, check if there are any account that match
$syncHash.Controls.TbAddAdminPermission.Add_TextChanged( {
	try
	{
		if ( $this.Text.Length -gt 0 )
		{
			$syncHash.Data.FoundRecipient = Get-EXORecipient -Identity $this.Text -ErrorAction Stop
			$syncHash.Controls.BtnAddAdminPermission.IsEnabled = $true -and $syncHash.Controls.BtnSearchAdminPermission.IsEnabled
		}
	}
	catch
	{
		$syncHash.Controls.BtnAddAdminPermission.IsEnabled = $false
	}
} )

# The GUI is loaded the first time
$syncHash.Controls.Window.Add_Loaded( {
	Get-Content -Path "$( $env:USERPROFILE )\O365Admin.txt" | `
		Where-Object { $_ } | `
		ForEach-Object {
			$syncHash.Controls.Window.Resources['CvsDgAdminPermissions'].Source.Add( ( Get-EXORecipient $_ ) ) | Out-Null
		}

	$syncHash.Controls.Window.Resources['CvsDgAdminPermissions'].Source.Add_CollectionChanged( {
		$syncHash.Controls.Window.Resources['CvsDgAdminPermissions'].View.Refresh()
		Set-Content -Value $syncHash.Controls.Window.Resources['CvsDgAdminPermissions'].Source.PrimarySmtpAddress -Path "$( $env:USERPROFILE )\O365Admin.txt"
	} )

	$syncHash.Controls.Window.Resources['CvsDgAdminPermissions'].View.Refresh()
} )

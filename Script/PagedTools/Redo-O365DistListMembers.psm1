<#
.Synopsis
	Change all recipients in the distribution list
.Description
	All recipients for the distribution list are changed to the specified list
.MenuItem
	Change receiver
.ObjectOperations
	O365Distributionlist
.SearchedItemRequest
	Allowed
.State
	Prod
.Author
	Smorkster (smorkster)
#>

Add-Type -AssemblyName PresentationFramework
$syncHash = $args[0]

function Set-ColSizes
{
	<#
	.Synopsis
		Assure column always stay maximized width
	#>

	$syncHash.Controls.LvMembersToReplace.View.Columns[0].Width = $syncHash.Controls.LvMembersToReplace.ActualWidth - $syncHash.Controls.LvMembersToReplace.View.Columns[1].ActualWidth - 12
}

###################### Script start
$syncHash.Controls.Window.Resources['CvsCurrentMembers'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
$syncHash.Controls.Window.Resources['CvsMembersToReplace'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()

#
$syncHash.Controls.BtnAddSingle.Add_Click( {
	$Found = try
		{
			$FoundContact = Get-EXORecipient -Identity $syncHash.Controls.TbAddSingle.Text -ErrorAction Stop -ResultSize 1
			$DisplayName = $FoundContact.DisplayName
			$true
		}
		catch
		{
			$DisplayName = [string]$syncHash.Controls.TbAddSingle.Text
			$false
		}
	$syncHash.Controls.Window.Resources['CvsMembersToReplace'].Source.Add( ( [pscustomobject]@{ DisplayName = $DisplayName ; ExistsInExchange = $Found ; Contact = $FoundContact } ) )
} )

#
$syncHash.Controls.BtnGetDistList.Add_Click( {
	try
	{
		$syncHash.Controls.GridListViews.Visibility = [System.Windows.Visibility]::Visible
		$syncHash.Controls.Window.Resources['CvsCurrentMembers'].Source.Clear()
		$syncHash.Controls.Window.Resources['CvsMembersToReplace'].Source.Clear()
		$syncHash.Data.FoundDistList = Get-DistributionGroup -Identity $syncHash.Controls.TbDistId.Text -ErrorAction Stop
		Get-DistributionGroupMember -Identity $syncHash.Data.FoundDistList.PrimarySmtpAddress | `
			ForEach-Object {
				$syncHash.Controls.Window.Resources['CvsCurrentMembers'].Source.Add( $_ )
			}
	}
	catch
	{
		$syncHash.Controls.GridListViews.Visibility = [System.Windows.Visibility]::Collapsed
		$syncHash.Controls.TblDistListInfo.Text = "$( $syncHash.Data.msgTable.StrNoDistListFound ) '$( $syncHash.Controls.TbDistId.Text )'"
	}
} )

# Import addresses from clipboard
$syncHash.Controls.BtnImport.Add_Click( {
	Get-Clipboard | `
		Where-Object { $_ } | `
		ForEach-Object {
			$FoundContact = $null
			$Address = $_
			$Found = try
				{
					$FoundContact = Get-EXORecipient -Identity $Address -ErrorAction Stop -ResultSize 1
					$DisplayName = $FoundContact.DisplayName
					$true
				}
				catch
				{
					$DisplayName = [string]$Address
					$false
				}
			$syncHash.Controls.Window.Resources['CvsMembersToReplace'].Source.Add( ( [pscustomobject]@{ DisplayName = $DisplayName ; ExistsInExchange = $Found ; Contact = $FoundContact } ) )
		}
} )

# Make the replacements
$syncHash.Controls.BtnStartReplacement.Add_Click( {
	$syncHash.Controls.Window.Resources['CvsMembersToReplace'].Source | `
		Where-Object { -not $_.ExistsInExchange } | `
		ForEach-Object {
			try
			{
				New-MailContact -Name $_.DisplayName -ExternalEmailAddress $_.DisplayName -ErrorAction Stop | Out-Null
				Set-MailContact -Identity $_.DisplayName -HiddenFromAddressListsEnabled $true -ErrorAction Stop
				$_.Contact = Get-EXORecipient -Identity $_.DisplayName
			}
			catch
			{
				
			}
		}
	Update-DistributionGroupMember -Identity $syncHash.Data.FoundDistList.PrimarySmtpAddress -Members $syncHash.Controls.Window.Resources['CvsMembersToReplace'].Source.Contact -BypassSecurityGroupManagerCheck -Confirm:$false
} )

# Get PrimarySmtpAddress from SearchedItem
$syncHash.Controls.Window.Add_IsVisibleChanged( {
	if (
		$this.IsVisible -and `
		$null -ne $syncHash.Controls.Window.Resources['SearchedItem'] -and `
		"" -eq $syncHash.Controls.TbDistId.Text
	)
	{
		$syncHash.Controls.TbDistId.Text = $syncHash.Controls.Window.Resources['SearchedItem'].Exchange.PrimarySmtpAddress
		$syncHash.Controls.TbDistId.Focus()
	}
} )

# Correct column sizes
$syncHash.Controls.Window.Add_Loaded( {
	Set-ColSizes
} )

#
$syncHash.Controls.Window.Add_SizeChanged( {
	Set-ColSizes
} )

Export-ModuleMember

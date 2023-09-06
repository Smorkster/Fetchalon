<#
.Synopsis
	Get a users icon
.Description
	Get the icon for a users Office 365 account
.MenuItem
	Account icon
.SearchedItemRequest
	Required
.ObjectOperations
	O365User
.State
	Prod
.Author
	Smorkster (smorkster)
#>

Add-Type -AssemblyName PresentationFramework
Import-Module ActiveDirectory
$syncHash = $args[0]

################# Script start
$controls = New-Object System.Collections.ArrayList

BindControls $syncHash $controls

# Fetch the icon
$syncHash.Controls.BtnGetIcon.Add_Click( {
	try
	{
		$syncHash.Data.UserIcon = Get-UserPhoto -Identity $syncHash.Data.User.PrimarySmtpAddress -ErrorAction Stop
		$syncHash.Controls.ImgIcon.Source = $syncHash.Data.UserIcon.PictureData
	}
	catch
	{
		$syncHash.Controls.TblNoIcon.Text = $syncHash.Data.msgTable.ContentTblNoIcon
	}
} )

# Remove the icon
$syncHash.Controls.BtnRemoveIcon.Add_Click( {
	try
	{
		Remove-UserPhoto -Identity $syncHash.Data.User.PrimarySmtpAddress -ErrorAction Stop
	}
	catch
	{}

	try
	{
		$syncHash.Controls.ImgIcon.Source = ""
	}
	catch
	{}
} )

# Text was entered
$syncHash.Controls.TbId.Add_TextChanged( {
	try
	{
		$syncHash.Controls.ImgIcon.Source = ""
	}
	catch
	{}

	$syncHash.Controls.TblNoIcon.Text = $syncHash.Data.msgTable.ContentTblNoUser
	try
	{
		if (
			( $this.Text -match $syncHash.Data.msgTable.CodeIdRegEx ) -or `
			( Resolve-DnsName -Name ( [mailaddress] $this.Text ).Host -Type MX -ErrorAction Stop )
		)
		{
			$syncHash.Data.User = Get-EXOMailbox -Identity $this.Text -ErrorAction Stop
			$syncHash.Controls.BtnGetIcon.IsEnabled = $true
		}
	}
	catch
	{
		$syncHash.Controls.BtnGetIcon.IsEnabled = $false
	}
} )

# UI is made visible, if a user is not loaded, enter SamAccountName in textbox for ID
$syncHash.Controls.Window.Add_IsVisibleChanged( {
	if ( $this.IsVisible -and ( $null -eq $syncHash.Data.User ) )
	{
		$syncHash.Controls.TbId.Text = $syncHash.Controls.Window.Resources['SearchedItem'].Alias
	}
	$syncHash.Controls.TbId.Focus()
} )

Export-ModuleMember

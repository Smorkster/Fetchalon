<#
.Synopsis
	Edit a user's auto reply
.Description
	Enable/disable auto-reply for users
.MenuItem
	Edit auto reply
.SearchedItemRequest
	Required
.Depends
	ExchangeAdministrator
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

function ResetControls
{
	<#
	.Synopsis
		Resets controls to defaul values
	#>

	$syncHash.Data.User = $null
	$syncHash.Data.UserAutoReplyConfig = $null
	$syncHash.DC.DpEnd[0] = ( Get-Date ).AddYears( 5 )

	$syncHash.Controls.TblFoundUser.Text = ""
	$syncHash.Controls.TbExternalAutoReply.Text = ""
	$syncHash.Controls.TbInternalAutoReply.Text = ""

	$syncHash.Controls.CbDeclineEventsForScheduledOOF.IsChecked = $false
	$syncHash.Controls.RbExternalReplyAll.IsChecked = $true
	$syncHash.Data.EndTimeEdited = $false
	$syncHash.Data.ExternalEdited = $false
	$syncHash.DC.CbActivate[0] = $false
	$syncHash.DC.GridUser[0] = $false

	$syncHash.DC.CbStartHour[0] = 0
	$syncHash.DC.CbStartMinute[0] = 0
	$syncHash.DC.CbEndHour[0] = 0
	$syncHash.DC.CbEndMinute[0] = 0
}

function UpdateEnd
{
	<#
	.Synopsis
		Set end date of message validity
	#>

	$syncHash.Data.End = $syncHash.DC.DpEnd[0].ToShortDateString()
	if ( $syncHash.DC.CbEndHour[0] -lt 10 )
	{
		$syncHash.Data.End += " 0$( $syncHash.DC.CbEndHour[0] ):"
	}
	else
	{
		$syncHash.Data.End += " $( $syncHash.DC.CbEndHour[0] ):"
	}

	if ( $syncHash.DC.CbEndMinute[0] -lt 10 )
	{
		$syncHash.Data.End += "0$( $syncHash.DC.CbEndMinute[0] )"
	}
	else
	{
		$syncHash.Data.End += $syncHash.DC.CbEndMinute[0]
	}
}

function UpdateStart
{
	<#
	.Synopsis
		Set start date of message validity
	#>

	$syncHash.Data.Start = $syncHash.DC.DpStart[0].ToShortDateString()
	if ( $syncHash.DC.CbStartHour[0] -lt 10 )
	{
		$syncHash.Data.Start += " 0$( $syncHash.DC.CbStartHour[0] ):"
	}
	else
	{
		$syncHash.Data.Start += " $( $syncHash.DC.CbStartHour[0] ):"
	}

	if ( $syncHash.DC.CbStartMinute[0] -lt 10 )
	{
		$syncHash.Data.Start += "0$( $syncHash.DC.CbStartMinute[0] )"
	}
	else
	{
		$syncHash.Data.Start += $syncHash.DC.CbStartMinute[0]
	}
}

function UpdateSummary
{
	<#
	.Synopsis
		Summarize the settings
	#>

	param ( $Text )

	UpdateEnd
	UpdateStart

	if ( $Text )
	{
		$syncHash.DC.TbSummary[0] = $Text
	}
	else
	{
		if ( $syncHash.DC.CbActivate[0] )
		{
			$syncHash.DC.TbSummary[0] = "$( $syncHash.Data.msgTable.StrSetAutoReplyStart )`n"
			if ( $syncHash.Controls.CbSendExternal.IsChecked )
			{
				$syncHash.DC.TbSummary[0] += $syncHash.Data.msgTable.StrSendExternalStart
				if ( $syncHash.Controls.RbExternalReplyContacts.IsChecked )
				{
					$syncHash.DC.TbSummary[0] += " $( $syncHash.Data.msgTable.StrSendExternalOnlyContacts )`n"
				}
				else
				{
					$syncHash.DC.TbSummary[0] += " $( $syncHash.Data.msgTable.StrSendExternalAll )`n"
				}
			}
			else
			{
				$syncHash.DC.TbSummary[0] += "$( $syncHash.Data.msgTable.StrDontSendExternal )`n"
			}

			if ( $syncHash.DC.CbScheduled[0] )
			{
				$syncHash.DC.TbSummary[0] += " $( $syncHash.Data.msgTable.StrSetAutoReplyScheduled ) $( $syncHash.Data.Start )"
				if ( $syncHash.Data.EndTimeEdited )
				{
					$syncHash.DC.TbSummary[0] += " $( $syncHash.Data.msgTable.StrSetAutoReplyScheduleEnd ) $( $syncHash.Data.End )"
				}
				else
				{
					$syncHash.DC.TbSummary[0] += " $( $syncHash.Data.msgTable.StrSetAutoReplyScheduledManualEnd )"
				}
				$syncHash.DC.TbSummary[0] += "`n"
			}
			else
			{
				$syncHash.DC.TbSummary[0] += " $( $syncHash.Data.msgTable.StrSetAutoReplyNotScheduled )`n"
			}

			if ( $syncHash.Controls.CbCreateOOFEvent.IsChecked )
			{
				$syncHash.DC.TbSummary[0] += " $( $syncHash.Data.msgTable.StrOOFEventIsCreated )`n"
			}

			if ( $syncHash.Controls.CbDeclineRequests.IsChecked )
			{
				$syncHash.DC.TbSummary[0] += " $( $syncHash.Data.msgTable.StrRequestsIsDeclined )"

				if ( $syncHash.Controls.CbDeclineEventsForScheduledOOF.IsChecked )
				{
					$syncHash.DC.TbSummary[0] += " $( $syncHash.Data.msgTable.StrRequestsIsDeclined )"

					if ( $syncHash.Controls.CbDeclineAllEventsForScheduledOOF.IsChecked )
					{
						$syncHash.DC.TbSummary[0] += " $( $syncHash.Data.msgTable.StrAllRequestsIsDeclined )"
					}
				}
				$syncHash.DC.TbSummary[0] += "`n"
			}
		}
		else
		{
			$syncHash.DC.TbSummary[0] = $syncHash.Data.msgTable.StrDisableAutoReply
		}
	}
}

################# Script start
$controls = New-Object System.Collections.ArrayList
[void]$controls.Add( @{ CName = "CbActivate"; Props = @( @{ PropName = "IsChecked"; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "CbEndHour"; Props = @( @{ PropName = "SelectedIndex"; PropVal = 23 } ) } )
[void]$controls.Add( @{ CName = "CbEndMinute"; Props = @( @{ PropName = "SelectedIndex"; PropVal = 59 } ) } )
[void]$controls.Add( @{ CName = "CbScheduled"; Props = @( @{ PropName = "IsChecked"; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "CbStartHour"; Props = @( @{ PropName = "SelectedIndex"; PropVal = 0 } ) } )
[void]$controls.Add( @{ CName = "CbStartMinute"; Props = @( @{ PropName = "SelectedIndex"; PropVal = 0 } ) } )
[void]$controls.Add( @{ CName = "DpEnd"; Props = @( @{ PropName = "SelectedDate"; PropVal = [datetime]::Now } ) } )
[void]$controls.Add( @{ CName = "DpStart"; Props = @( @{ PropName = "SelectedDate"; PropVal = [datetime]::Now } ) } )
[void]$controls.Add( @{ CName = "GridUser"; Props = @( @{ PropName = "IsEnabled"; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "SpSetEndTime"; Props = @( @{ PropName = "Visibility"; PropVal = [System.Windows.Visibility]::Visible } ) } )
[void]$controls.Add( @{ CName = "TbSummary"; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )

BindControls $syncHash $controls

$syncHash.Data.Admin = ( Get-AzureADCurrentSessionInfo ).Account.Id

$syncHash.Code.EndTimeChanged = {
	if ( $syncHash.Controls.GridUser.IsEnabled )
	{
		$syncHash.Data.EndTimeEdited = $true
	}
	UpdateSummary
}

# Set values for hour and minute
00..23 | `
	ForEach-Object {
		if ( $_ -lt 10 )
		{
			$i = "0$_"
		}
		else
		{
			$i = "$_"
		}
		[void] $syncHash.Controls.CbStartHour.Items.Add( $i )
		[void] $syncHash.Controls.CbEndHour.Items.Add( $i )
	}
00..59 | `
	ForEach-Object {
		if ( $_ -lt 10 )
		{
			$i = "0$_"
		}
		else
		{
			$i = "$_"
		}
		[void] $syncHash.Controls.CbStartMinute.Items.Add( $i )
		[void] $syncHash.Controls.CbEndMinute.Items.Add( $i )
	}

# Create collections for dates that should be disabled in DatePickers
$disabledDates = New-Object System.Windows.Controls.CalendarDateRange
$disabledDates.Start = ( Get-Date ).Date.AddDays( -365 )
$disabledDates.End = ( Get-Date ).Date.AddDays( -1 )
$syncHash.Controls.DpStart.BlackoutDates.Add( $disabledDates )
$syncHash.Controls.DpEnd.BlackoutDates.Add( $disabledDates )

# Add eventhandlers for when checkboxes and radionbutton is checked/unchecked
$syncHash.Controls.CbActivate.Add_Checked( { UpdateSummary } )
$syncHash.Controls.CbActivate.Add_Unchecked( { UpdateSummary } )
$syncHash.Controls.CbCreateOOFEvent.Add_Checked( { UpdateSummary } )
$syncHash.Controls.CbCreateOOFEvent.Add_Unchecked( { UpdateSummary } )
$syncHash.Controls.CbDeclineAllEventsForScheduledOOF.Add_Checked( { UpdateSummary } )
$syncHash.Controls.CbDeclineAllEventsForScheduledOOF.Add_Unchecked( { UpdateSummary } )
$syncHash.Controls.CbDeclineEventsForScheduledOOF.Add_Checked( { UpdateSummary } )
$syncHash.Controls.CbDeclineEventsForScheduledOOF.Add_Unchecked( { UpdateSummary } )
$syncHash.Controls.CbDeclineRequests.Add_Checked( { UpdateSummary } )
$syncHash.Controls.CbDeclineRequests.Add_Unchecked( { UpdateSummary } )
$syncHash.Controls.CbScheduled.Add_Checked( { UpdateSummary } )
$syncHash.Controls.CbScheduled.Add_UnChecked( { UpdateSummary } )
$syncHash.Controls.CbSendExternal.Add_Checked( { UpdateSummary } )
$syncHash.Controls.CbSendExternal.Add_UnChecked( { UpdateSummary } )
$syncHash.Controls.RbExternalReplyContacts.Add_Checked( { UpdateSummary } )
$syncHash.Controls.RbExternalReplyContacts.Add_UnChecked( { UpdateSummary } )
$syncHash.Controls.RbExternalReplyAll.Add_Checked( { UpdateSummary } )
$syncHash.Controls.RbExternalReplyAll.Add_UnChecked( { UpdateSummary } )

# Values for start time/date have changed
$syncHash.Controls.DpStart.Add_SelectedDateChanged( { UpdateSummary } )
$syncHash.Controls.DpStart.Add_CalendarClosed( { UpdateSummary } )
$syncHash.Controls.CbStartHour.Add_SelectionChanged( { UpdateSummary } )
$syncHash.Controls.CbStartHour.Add_DropDownClosed( { UpdateSummary } )
$syncHash.Controls.CbStartMinute.Add_DropDownClosed( { UpdateSummary } )
$syncHash.Controls.CbStartMinute.Add_DropDownClosed( { UpdateSummary } )

# Values for end time/date have changed
$syncHash.Controls.DpEnd.Add_SelectedDateChanged( { . $syncHash.Code.EndTimeChanged } )
$syncHash.Controls.DpEnd.Add_CalendarClosed( { . $syncHash.Code.EndTimeChanged } )
$syncHash.Controls.CbEndHour.Add_SelectionChanged( { . $syncHash.Code.EndTimeChanged } )
$syncHash.Controls.CbEndHour.Add_DropDownClosed( { . $syncHash.Code.EndTimeChanged } )
$syncHash.Controls.CbEndMinute.Add_DropDownClosed( { . $syncHash.Code.EndTimeChanged } )
$syncHash.Controls.CbEndMinute.Add_DropDownClosed( { . $syncHash.Code.EndTimeChanged } )

# Text was entered
$syncHash.Controls.TbId.Add_TextChanged( {
	ResetControls
	if ( $this.Text -match "^(((?![AaEeIiOoUuYyÅåÄäÖö])[\w]){4})$" -or ( ( $this.Text -match "@domain\.se$" ) -and ( Test-MailAddress -Address $this.Text ) ) )
	{
		if ( $this.Text -match "@domain\.se$" )
		{
			$ADUser = Get-ADUser -LDAPFilter "(Mail=$( $this.Text ))" -Properties EmailAddress -ErrorAction Stop
		}
		else
		{
			$ADUser = Get-ADUser -LDAPFilter "(SamAccountName=$( $this.Text ))" -Properties EmailAddress -ErrorAction Stop
		}

		if ( $ADUser )
		{
			$syncHash.DC.GridUser[0] = $true
			try
			{
				$syncHash.Data.User = Get-EXOMailbox -Identity $ADUser.EmailAddress -ErrorAction Stop
				$syncHash.Controls.TblFoundUser.Text = $syncHash.Data.User.PrimarySmtpAddress
				$syncHash.DC.GridUser[0] = $true

				$syncHash.Data.UserAutoReplyConfig = Get-MailboxAutoReplyConfiguration -Identity $syncHash.Data.User.UserPrincipalName
				if ( $syncHash.Data.UserAutoReplyConfig.AutoReplyState -eq "Disabled" )
				{
					$syncHash.DC.CbActivate[0] = $false
				}
				else
				{
					$syncHash.DC.CbActivate[0] = $true
					if ( $syncHash.Data.UserAutoReplyConfig.AutoReplyState -eq "Scheduled" )
					{
						$syncHash.DC.CbScheduled[0] = $true
					}

					$syncHash.DC.DpStart[0] = $syncHash.Data.UserAutoReplyConfig.StartTime.Date
					$syncHash.DC.DpEnd[0] = $syncHash.Data.UserAutoReplyConfig.EndTime.Date
					$syncHash.DC.CbStartHour[0] = $syncHash.Data.UserAutoReplyConfig.StartTime.Hour
					$syncHash.DC.CbStartMinute[0] = $syncHash.Data.UserAutoReplyConfig.StartTime.Minute
					$syncHash.DC.CbEndHour[0] = $syncHash.Data.UserAutoReplyConfig.EndTime.Hour
					$syncHash.DC.CbEndMinute[0] = $syncHash.Data.UserAutoReplyConfig.EndTime.Minute

					$b = New-Object -ComObject "htmlfile"
					$b.IHTMLDocument2_write( $syncHash.Data.UserAutoReplyConfig.InternalMessage )
					$syncHash.Controls.TbInternalAutoReply.Text = $b.body.innerText

					$b = New-Object -ComObject "htmlfile"
					$b.IHTMLDocument2_write( $syncHash.Data.UserAutoReplyConfig.ExternalMessage )
					$syncHash.Controls.TbExternalAutoReply.Text = $b.body.innerText

					$b = New-Object -ComObject "htmlfile"
					$b.IHTMLDocument2_write( $syncHash.Data.UserAutoReplyConfig.DeclineMeetingMessage )
					$syncHash.Controls.TbDeclineMeetingMessage.Text = $b.body.innerText

					$syncHash.Controls.TbOOFEventSubject.Text = $syncHash.Data.UserAutoReplyConfig.OOFEventSubject

					$syncHash.Controls.CbCreateOOFEvent.IsChecked = $syncHash.Data.UserAutoReplyConfig.CreateOOFEvent
					$syncHash.Controls.CbDeclineEventsForScheduledOOF.IsChecked = $syncHash.Data.UserAutoReplyConfig.DeclineEventsForScheduledOOF

					if ( "None" -eq $syncHash.Data.UserAutoReplyConfig.ExternalAudience )
					{
						$syncHash.Controls.CbSendExternal.IsChecked = $false
					}
					else
					{
						$syncHash.Controls.CbSendExternal.IsChecked = $true
						if ( "Known" -eq $syncHash.Data.UserAutoReplyConfig.ExternalAudience )
						{
							$syncHash.Controls.RbExternalReplyContacts.IsChecked = $true
						}
						else
						{
							$syncHash.Controls.RbExternalReplyAll.IsChecked = $true
						}
					}
				}
			}
			catch
			{
				$syncHash.Controls.TblFoundUser.Text = $syncHash.Data.msgTable.StrNoO365User
			}
		}
		else
		{
			$syncHash.Controls.TblFoundUser.Text = $syncHash.Data.msgTable.StrNoUser
			$syncHash.DC.GridUser[0] = $false
		}
	}
} )

# Set autoreply
$syncHash.Controls.BtnSet.Add_Click( {
	$syncHash.DC.GridUser[0] = $false
	UpdateSummary -Text $syncHash.Data.msgTable.StrSetting
	Add-MailboxPermission -Identity $syncHash.Data.User.PrimarySmtpAddress -User $syncHash.Data.Admin -AccessRights FullAccess -WarningAction SilentlyContinue | Out-Null

	$confParams = @{}
	$confParams.Identity = $syncHash.Data.User.PrimarySmtpAddress
	if ( $syncHash.DC.CbActivate[0] ) # Activate
	{
		$confParams.InternalMessage = $syncHash.Controls.TbInternalAutoReply.Text
		$confParams.ExternalMessage = $syncHash.Controls.TbExternalAutoReply.Text
		$confParams.Confirm = $false
		if ( $syncHash.Controls.CbSendExternal.IsChecked )
		{
			if ( $syncHash.Controls.RbExternalReplyContacts.IsChecked )
			{
				$confParams.ExternalAudience = "Known"
			}
			else
			{
				$confParams.ExternalAudience = "All"
			}
		}
		else
		{
			$confParams.ExternalAudience = "None"
		}

		if ( $syncHash.DC.CbScheduled[0] ) # Scheduled
		{
			$confParams.AutoReplyState = "Scheduled"
			$confParams.StartTime = [datetime]::Parse( $syncHash.Data.Start ).ToUniversalTime()
			$confParams.EndTime = [datetime]::Parse( $syncHash.Data.End ).ToUniversalTime()

			if ( $syncHash.Controls.CbDeclineEventsForScheduledOOF.IsChecked )
			{
				$confParams.DeclineMeetingMessage = $syncHash.Controls.TbDeclineMeetingMessage.Text
				$confParams.DeclineEventsForScheduledOOF = $true
				$confParams.DeclineAllEventsForScheduledOOF = $syncHash.Controls.CbDeclineAllEventsForScheduledOOF.IsChecked
			}
			else
			{
				$confParams.DeclineEventsForScheduledOOF = $false
			}

			if ( $syncHash.Controls.CbCreateOOFEvent.IsChecked )
			{
				$confParams.CreateOOFEvent = $true
				$confParams.OOFEventSubject = $syncHash.Controls.TbOOFEventSubject.Text
			}
		}
		else # Not scheduled
		{
			$confParams.AutoReplyState = "Enabled"
			$confParams.StartTime = ( Get-Date ).Date
		}
	}
	else # Disable
	{
		$confParams.AutoReplyState = "Disabled"
	}

	Set-MailboxAutoReplyConfiguration @confParams

	Remove-MailboxPermission -Identity $syncHash.Data.User.PrimarySmtpAddress -User $syncHash.Data.Admin -AccessRights FullAccess -Confirm:$false -BypassMasterAccountSid
	$syncHash.DC.GridUser[0] = $true

	if ( $syncHash.DC.CbActivate[0] )
	{
		UpdateSummary -Text $syncHash.Data.msgTable.StrSettingDone
	}
	else
	{
		UpdateSummary -Text $syncHash.Data.msgTable.StrSettingInactiveDone
	}

	$OFS = "`n"
	WriteLog -Text "$( $syncHash.Data.msgTable.LogSummary )`n$( ( $confParams.GetEnumerator() | Sort-Object Key | ForEach-Object { "$( $_.Key ): $( $_.Value )" } ).Trim() )" -UserInput $syncHash.Data.User.PrimarySmtpAddress -Success $true | Out-Null
} )

# Set if message for external message is edited
$syncHash.Controls.TbExternalAutoReply.Add_KeyDown( {
	$syncHash.Data.ExternalEdited = $true
} )

# Have the same message for internal and external autoreply
$syncHash.Controls.TbInternalAutoReply.Add_TextChanged( {
	if ( -not $syncHash.Data.ExternalEdited )
	{
		$syncHash.Controls.TbExternalAutoReply.Text = $this.Text
	}
} )

# UI is made visible, if a user is not loaded, enter SamAccountName in textbox for ID
$syncHash.Controls.Window.Add_IsVisibleChanged( {
	if ( $this.IsVisible -and ( $null -eq $syncHash.Data.User ) )
	{
		$syncHash.Controls.TbId.Text = $syncHash.Controls.Window.Resources['SearchedItem'].Exchange.Alias
	}
	$syncHash.Controls.TbId.Focus()
} )

Export-ModuleMember

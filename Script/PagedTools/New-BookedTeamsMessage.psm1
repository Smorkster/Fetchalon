<#
.Synopsis
	Create booking for public notice
.Description
	Creates a booking for Power Automate bot which, on the set date, will write a message to the selected channel.
.MenuItem
	Schedule message
.SearchedItemRequest
	None
.State
	Prod
.Author
	Smorkster (smorkster)
#>

Add-Type -AssemblyName PresentationFramework
$syncHash = $args[0]

function Reset
{
	<#
	.Synopsis
		Reset controls
	#>

	$syncHash.Controls.TbSubject.Text = ""
	$syncHash.Controls.TbMessage.Text = ""
	$syncHash.Controls.DpDate.SelectedDate = $null
	$syncHash.Controls.CbTeam.SelectedIndex = -1
	$syncHash.Controls.CbChannel.SelectedIndex = -1
	$syncHash.Controls.CbHourPicker.SelectedIndex = -1
	$syncHash.Controls.CbMinutePicker.SelectedIndex = -1
}

function Set-Localizations
{
	<#
	.Synopsis
		Initialize collections and set some values
	#>

	$syncHash.Controls.Window.Resources.CvsHours.Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	$syncHash.Controls.Window.Resources.CvsLog.Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	$syncHash.Controls.Window.Resources.CvsMinutes.Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	$syncHash.Controls.Window.Resources.CvsStyleTextSize.Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	$syncHash.Controls.Window.Resources.CvsTeams.Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()

	$syncHash.Controls.Window.Resources.CvsTeams.Source.Add( [pscustomobject]@{
		Name = "Teams Team 1"
		Channels = [System.Collections.ArrayList]@( "Ch 1" ; "Ch 1" )
	} )

	$syncHash.Controls.Window.Resources.CvsTeams.Source.Add( [pscustomobject]@{
		Name = "Teams Team 2"
		Channels = [System.Collections.ArrayList]@( "Ch 1" ; "Ch 2" )
	} )

	0..59 | `
		ForEach-Object {
			if ( $_ -lt 10 )
			{
				$t = "0$( $_ )"
			}
			else
			{
				$t = "$_"
			}

			if ( $_ -lt 24 )
			{
				$syncHash.Controls.Window.Resources.CvsHours.Source.Add( $t )
			}
			$syncHash.Controls.Window.Resources.CvsMinutes.Source.Add( $t )
		}
	8, 9, 10, 11, 12, 14, 16, 18, 20, 22, 24, 26, 28, 36, 48, 72 | `
		ForEach-Object {
			$syncHash.Controls.Window.Resources.CvsStyleTextSize.Source.Add( $_ )
		}
}

###################### Script start
$controls = [System.Collections.ArrayList]::new()

[void]$controls.Add( @{ CName = "DpDate" ; Props = @(
	@{ PropName = "DisplayDateStart" ; PropVal = [datetime]::Now }
	@{ PropName = "DisplayDateEnd" ; PropVal = [datetime]::Now.AddDays( 100 ) }
) } )

BindControls $syncHash $controls
Set-Localizations

#
$syncHash.Controls.BtnPreview.Add_Click( {
	$syncHash.Controls.PreviewBrowser.NavigateToString( ( $syncHash.Controls.TbMessage.Text -replace "`n", "<br>" ) )
	$syncHash.Controls.Window.Resources.WindowPreview.Visibility = [System.Windows.Visibility]::Visible
} )

# Send booking to bot calendar
$syncHash.Controls.BtnSendBooking.Add_Click( {
	$DateTime = "$( $syncHash.Controls.DpDate.SelectedDate.ToShortDateString() )"
	$DateTime += " $( $syncHash.Controls.CbHourPicker.SelectedValue ):"
	$DateTime += "$( $syncHash.Controls.CbMinutePicker.SelectedValue ):00"
	
	$Info = "{""DateTime"":""$( $DateTime )"",
	""Subject"":""$( $syncHash.Controls.TbSubject.Text )"",
	""Body"":""$( $syncHash.Controls.TbMessage.Text -replace "`n", "<br>" )"",
	""Team"":""$( $syncHash.Controls.CbTeam.SelectedValue.Name )"",
	""Channel"":""$( $syncHash.Controls.CbChannel.SelectedValue )""}"
	try
	{
		$syncHash.Data.Resp = Invoke-RestMethod -Uri "<Power Automate flow http request address>" `
			-Method Post `
			-ContentType "application/json" `
			-Body ( [System.Text.Encoding]::UTF8.GetBytes( $Info ) ) `
			-UseDefaultCredentials
		$syncHash.Controls.Window.Resources.CvsLog.Source.Add( ( [pscustomobject]@{
			OpTime = ( Get-Date )
			Message = "'$( $syncHash.Controls.TbSubject.Text )' $( $syncHash.Data.Resp )"
			LogType = "Success"
		} ) )
		Reset
	}
	catch [System.Net.WebException]
	{
		$syncHash.Controls.Window.Resources.CvsLog.Source.Add( ( [pscustomobject]@{
			OpTime = Get-Date
			Message = "$( $syncHash.Data.msgTable.ErrWebReq ): `n$( $_.ErrorDetails.Message )"
			LogType = "Error"
		} ) )
	}
	catch
	{
		$E = $Error[0]
		$syncHash.Controls.Window.Resources.CvsLog.Source.Add( ( [pscustomobject]@{
			OpTime = Get-Date
			Message = "$( $syncHash.Data.msgTable.ErrGeneral ): `n$( $E.Exception.Message )"
			LogType = "Error"
		} ) )
	}
} )

# Set HTML style bold for selected text
$syncHash.Controls.BtnStyleTextBold.Add_Click( {
	$syncHash.Controls.TbMessage.SelectedText = "<b>$( $syncHash.Controls.TbMessage.SelectedText )</b>"
	$syncHash.Controls.TbMessage.Focus()
} )

# Set HTML style italic for selected text
$syncHash.Controls.BtnStyleTextItalic.Add_Click( {
	$syncHash.Controls.TbMessage.SelectedText = "<i>$( $syncHash.Controls.TbMessage.SelectedText )</i>"
	$syncHash.Controls.TbMessage.Focus()
} )

# Set HTML style strikethrough for selected text
$syncHash.Controls.BtnStyleTextStrike.Add_Click( {
	$syncHash.Controls.TbMessage.SelectedText = "<s>$( $syncHash.Controls.TbMessage.SelectedText )</s>"
	$syncHash.Controls.TbMessage.Focus()
} )

# Set HTML style underlined for selected text
$syncHash.Controls.BtnStyleTextUnderlined.Add_Click( {
	$syncHash.Controls.TbMessage.SelectedText = "<u>$( $syncHash.Controls.TbMessage.SelectedText )</u>"
	$syncHash.Controls.TbMessage.Focus()
} )

# Set HTML style textsize for selected text
$syncHash.Controls.CbStyleTextSize.Add_SelectionChanged( {
	$syncHash.Controls.TbMessage.SelectedText = "<span style='font-size: $( $this.SelectedValue )px;'>$( $syncHash.Controls.TbMessage.SelectedText -replace "<span.*?>" -replace "</span>" )</span>"
	$syncHash.Controls.TbMessage.Focus()
} )

# Cancel closing, instead hide window
$syncHash.Controls.WindowPreview.Add_Closing( {
	$args[1].Cancel = $true
	$this.Visibility = [System.Windows.Visibility]::Hidden
} )

# Catch keypress
$syncHash.Controls.WindowPreview.Add_KeyDown( {
	if ( $args[1].Key -eq "Escape" )
	{
		$this.Visibility = [System.Windows.Visibility]::Hidden
	}
} )

# Hide when losing focus
$syncHash.Controls.WindowPreview.Add_LostFocus( {
	$this.Visibility = [System.Windows.Visibility]::Hidden
} )

# Hide when losing focus
$syncHash.Controls.WindowPreview.Add_LostKeyboardFocus( {
	$this.Visibility = [System.Windows.Visibility]::Hidden
} )

# If something is selected, enabled style controls
$syncHash.Controls.TbMessage.Add_SelectionChanged( {
	$syncHash.Controls.SpStyling.IsEnabled = $this.SelectionLength -gt 0
} )

#
$syncHash.Controls.Window.Add_Loaded( {
	$syncHash.Controls.SpStyling.IsEnabled = $false
} )

Export-ModuleMember

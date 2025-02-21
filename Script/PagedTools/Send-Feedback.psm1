<#
.Synopsis
	Send feedback about function/tool
.Description
	Send feedback to backoffice about any of the available functions or tools
.MenuItem
	Send feedback
.ObjectOperations
	Suite
.State
	Prod
.Author
	Smorkster (smorkster)
#>

Add-Type -AssemblyName PresentationFramework
$syncHash = $args[0]

function Set-Localizations
{
}

###################### Script start

$syncHash.Controls.BtnAbortReport.Add_Click( {
	$syncHash.Controls.TbText.Text = ""
} )

$syncHash.Controls.BtnSendReport.Add_Click( {
	$FeedbackSender = Get-ADUser ( ( [Environment]::UserName ).Substring( 6, 4 ) ) -Properties mail

	if ( $syncHash.Data.SelectedItem -eq "Suggestion" )
	{
		try
		{
			Send-MailMessage -From $FeedbackSender.mail `
				-To "$( $syncHash.Data.msgTable.StrBackOfficeMailAddress )" `
				-Encoding bigendianunicode `
				-SmtpServer $syncHash.Data.msgTable.StrSMTP `
				-Subject "$( $syncHash.Data.msgTable.StrSuggestionSubject )" `
				-BodyAsHtml `
				-Body @"
	<strong>$( $FeedbackSender.Name )</strong> $( $syncHash.Data.msgTable.StrSuggestionIntro ):<br><br>

$( $syncHash.Data.msgTable.StrMessageTitle ):<br>
$( $syncHash.Controls.TbText.Text -replace "`n", "<br>" )<br>
"@
			Show-Splash -Text "$( $syncHash.Data.msgTable.StrSplashAllSent )`n$( $syncHash.Data.msgTable.StrSplashFinished )" -NoProgressBar
			$syncHash.Controls.TbText.Text = ""
		}
		catch
		{
			Write-Error "Send to suggestion `n$_"
		}
	}
	else
	{
		if ( $syncHash.Data.SelectedItem.Author -match "\((?<id>.{4})\)" )
		{
			Show-Splash -SelfAdmin
			$CodeAuthor = $Matches.id
			try
			{
				Send-MailMessage -From $FeedbackSender.mail `
					-To ( Get-ADUser $CodeAuthor -Properties mail ).mail `
					-Encoding bigendianunicode `
					-SmtpServer $syncHash.Data.msgTable.StrSMTP `
					-Subject $syncHash.Data.msgTable.StrFeedbackSubject `
					-BodyAsHtml `
					-Body @"
	$( $syncHash.Data.msgTable.StrToAuthorInfo )<br><br>
	$( $syncHash.Data.msgTable.StrToAuthorInfoSentBy ): $( ( Get-ADUser -Identity ( [Environment]::UserName ) ).Name )<br>
	$( $syncHash.Data.CodeTypeTitle ): <strong>$( $syncHash.Data.SelectedItem.MenuItem )</strong><br>
	$( $syncHash.Data.msgTable.StrFilePathTitle ): $( $syncHash.Data.FilePath )<br><br>

	$( $syncHash.Data.msgTable.StrMessageTitle ):<br>
	$( $syncHash.Controls.TbText.Text -replace "`n", "<br>" )<br>
"@
				$MailSentToAuthor = $true
				Update-SplashText -Text $syncHash.Data.msgTable.StrSplashToAuthor
			}
			catch
			{
				Write-Error "Send to author `n$_"
			}
		}

		try
		{
			Send-MailMessage -From $FeedbackSender.mail `
				-To $syncHash.Data.msgTable.StrBackOfficeMailAddress `
				-Encoding bigendianunicode `
				-SmtpServer $syncHash.Data.msgTable.StrSMTP `
				-Subject $syncHash.Data.msgTable.StrFeedbackSubject `
				-BodyAsHtml `
				-Body @"
	$( $syncHash.Data.msgTable.StrToAuthorInfoSentBy ): $( $FeedbackSender.Name )<br>
	$( if ( $MailSentToAuthor ) { "$( $syncHash.Data.msgTable.StrSentToAuthor )" } else { $syncHash.Data.msgTable.StrNotSentToAuthor } ; ": $( $CodeAuthor )" )<br><br>
	$( $syncHash.Data.CodeTypeTitle ): <strong>$( $syncHash.Data.SelectedItem.MenuItem )</strong><br>
	$( $syncHash.Data.msgTable.StrFilePathTitle ): $( $syncHash.Data.FilePath )<br><br>

$( $syncHash.Data.msgTable.StrMessageTitle ):<br>
$( $syncHash.Controls.TbText.Text -replace "`n", "<br>" )<br>
"@
			Update-SplashText -Text "`n$( $syncHash.Data.msgTable.StrSplashAllSent )" -Append
			Start-Sleep -Seconds 1
			Update-SplashText -Text $syncHash.Data.msgTable.StrSplashFinished
			Close-SplashScreen -Duration 2

			WriteLog -Text "$( $syncHash.Data.msgTable.StrLogAuthorInformed ): $MailSentToAuthor`n$( $syncHash.Controls.TbText.Text )" -Success $true | Out-Null
			$syncHash.Controls.TbText.Text = ""
		}
		catch
		{
			Write-Error "Send to BO `n$_"
		}
	}
} )

#
$syncHash.Controls.TBtnSuggestion.Add_Click( {
	$syncHash.Controls.TbText.Focus()
	$syncHash.Data.SelectedItem = "Suggestion"
} )

#
$syncHash.Controls.TvPropHandlerList.Add_GotKeyboardFocus( {
	$syncHash.Controls.TBtnSuggestion.IsChecked = $false
} )

$syncHash.Controls.TvPropHandlerList.Add_SelectedItemChanged( {
	$syncHash.Controls.TblAuthor.Text = $this.SelectedItem.Author
	$syncHash.Controls.TblDescription.Text = $this.SelectedItem.Description

	$syncHash.Data.SelectedItem = $this.SelectedItem
	$syncHash.Data.CodeTypeTitle = $syncHash.Data.msgTable.StrCodeTypePHTitle
	$syncHash.Data.FilePath = ( Get-Module | Where-Object { $_.ExportedVariables.Keys -match "PHComputerAdMemberOf" } ).Path
} )

$syncHash.Controls.TvMenuList.Add_GotKeyboardFocus( {
	$syncHash.Controls.TBtnSuggestion.IsChecked = $false
} )

$syncHash.Controls.TvMenuList.Add_SelectedItemChanged( {
	$syncHash.Controls.TblAuthor.Text = $this.SelectedItem.Author
	$syncHash.Controls.TblDescription.Text = $this.SelectedItem.Description

	$syncHash.Data.SelectedItem = $this.SelectedItem
	if ( $this.SelectedItem.psobject.Members.Name -contains "Ps" )
	{
		$syncHash.Data.CodeTypeTitle = $syncHash.Data.msgTable.StrCodeTypeToolTitle
		$syncHash.Data.FilePath = $this.SelectedItem.Ps
	}
	else
	{
		$syncHash.Data.CodeTypeTitle = $syncHash.Data.msgTable.StrCodeTypeFunctionTitle
		$syncHash.Data.FilePath = ( Get-Command $this.SelectedItem.Name ).Module.Path
	}
} )

$syncHash.Controls.Window.Add_Loaded( {
} )
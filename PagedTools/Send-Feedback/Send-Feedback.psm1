<#
.Synopsis Send feedback about function/tool
.Description Send feedback to backoffice about any of the available functions or tools
.MenuItem Send feedback
.State Prod
.Author Smorkster
#>

Add-Type -AssemblyName PresentationFramework
$syncHash = $args[0]

###################### Script start

$BindData = [pscustomobject]@{
	MsgTable = $syncHash.Data.msgTable
}

$syncHash.Controls.Window.DataContext = $BindData

$syncHash.Controls.BtnSendReport.Add_Click( {
	if ( $syncHash.Controls.CbFunctionsList.SelectedItem.Author -match "\((?<id>.{4})\)" )
	{
		Send-MailMessage -From ( Get-ADUser ( $env:USERNAME.Substring( 6, 4 ) ) -Properties mail ).mail `
			-To ( Get-ADUser $Matches.id -Properties mail ).mail `
			-Body "$( $syncHash.Controls.CbFunctionsList.SelectedItem.Name )<br><br>$( $syncHash.Controls.TbText.Text -replace "`n","<br>" )" `
			-Encoding bigendianunicode `
			-SmtpServer $syncHash.Data.msgTable.SMTP `
			-Subject $syncHash.Data.msgTable.StrSubject `
			-BodyAsHtml
		$MailSentToAuthor = $true
	}

	Send-MailMessage -From ( Get-ADUser ( $env:USERNAME.Substring( 6, 4 ) ) -Properties mail ).mail `
		-To $syncHash.Data.msgTable.StrBackOfficeMailAddress `
		-Body "$( $syncHash.Controls.CbFunctionsList.SelectedItem.Name )<br><br>$( $syncHash.Controls.TbText.Text -replace "`n","<br>" )<br><br>$( if ( $MailSentToAuthor ) { "$( $syncHash.Data.msgTable.StrSentToAuthor ) $( ( Get-ADUser ( $env:USERNAME.Substring( 6, 4 ) ) -Properties mail ).mail )" } else { $syncHash.Data.msgTable.StrNotSentToAuthor } )" `
		-Encoding bigendianunicode `
		-SmtpServer $syncHash.Data.msgTable.SMTP `
		-Subject $syncHash.Data.msgTable.StrSubject `
		-BodyAsHtml
} )
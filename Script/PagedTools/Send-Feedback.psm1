﻿<#
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

###################### Script start

$BindData = [pscustomobject]@{
	MsgTable = $syncHash.Data.msgTable
}

$syncHash.Controls.Window.DataContext = $BindData

$syncHash.Controls.BtnAbortReport.Add_Click( {
	$syncHash.Controls.CbFunctionsList.SelectedIndex = -1
	$syncHash.Controls.TbText.Text = ""
} )

$syncHash.Controls.BtnSendReport.Add_Click( {
	ShowSplash -SelfAdmin
	if ( $syncHash.Controls.CbFunctionsList.SelectedItem.Author -match "\((?<id>.{4})\)" )
	{
		$Author = $Matches.id
		Send-MailMessage -From ( Get-ADUser ( ( [Environment]::UserName ).Substring( 6, 4 ) ) -Properties mail ).mail `
			-To ( Get-ADUser $Author -Properties mail ).mail `
			-Body @"
$( $syncHash.Data.msgTable.StrToAuthorInfo )<br>
$( $syncHash.Data.msgTable.StrCodeTitle ): <strong>$( $syncHash.Controls.CbFunctionsList.SelectedItem.Name )</strong><br><br>

$( $syncHash.Data.msgTable.StrMessageTitle ):<br>
*******************************************<br><br>

$( $syncHash.Controls.TbText.Text -replace "`n", "<br>" )<br><br>

*******************************************<br><br>

$( $syncHash.Data.msgTable.StrToAuthorInfoSentBy ): $( ( Get-ADUser -Identity ( [Environment]::UserName ) ).Name )
"@ `
			-Encoding bigendianunicode `
			-SmtpServer $syncHash.Data.msgTable.StrSMTP `
			-Subject $syncHash.Data.msgTable.StrSubject `
			-BodyAsHtml
		$MailSentToAuthor = $true
		Update-SplashText -Text $syncHash.Data.msgTable.StrSplashToAuthor
	}

	Send-MailMessage -From ( Get-ADUser ( ( [Environment]::UserName ).Substring( 6, 4 ) ) -Properties mail ).mail `
		-To $syncHash.Data.msgTable.StrBackOfficeMailAddress `
		-Body @"
$( $syncHash.Data.msgTable.StrCodeTitle ): <strong>$( $syncHash.Controls.CbFunctionsList.SelectedItem.Name )</strong><br><br>

$( $syncHash.Data.msgTable.StrMessageTitle ):<br>
*******************************************<br>

$( $syncHash.Controls.TbText.Text -replace "`n", "<br>" )<br>

*******************************************<br><br>

$( if ( $MailSentToAuthor ) { "$( $syncHash.Data.msgTable.StrSentToAuthor ): $( $Author )" } else { $syncHash.Data.msgTable.StrNotSentToAuthor } )<br><br>

$( $syncHash.Data.msgTable.StrToAuthorInfoSentBy ): $( ( Get-ADUser -Identity ( [Environment]::UserName ) ).Name )
"@ `
		-Encoding bigendianunicode `
		-SmtpServer $syncHash.Data.msgTable.StrSMTP `
		-Subject $syncHash.Data.msgTable.StrSubject `
		-BodyAsHtml
	Update-SplashText -Text "`n$( $syncHash.Data.msgTable.StrSplashAllSent )" -Append
	Start-Sleep -Seconds 1
	Update-SplashText -Text $syncHash.Data.msgTable.StrSplashFinished
	Close-SplashScreen -Duration 2

	WriteLog -Text "$( $syncHash.Data.msgTable.StrLogAuthorInformed ): $MailSentToAuthor`n$( $syncHash.Controls.TbText.Text )" -Success $true | Out-Null
	$syncHash.Controls.CbFunctionsList.SelectedIndex = -1
	$syncHash.Controls.TbText.Text = ""
} )

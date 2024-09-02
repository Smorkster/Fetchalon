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

###################### Script start

$syncHash.Controls.BtnAbortReport.Add_Click( {
	$syncHash.Controls.TbText.Text = ""
} )

$syncHash.Controls.BtnSendReport.Add_Click( {
	if ( $syncHash.Controls.TvMenuList.SelectedItem -eq $null -or
		$null -eq ( $syncHash.Controls.TvMenuList.SelectedItem | Get-Member -Name MenuItem )
	)
	{
		Show-Splash -Text $syncHash.Data.msgTable.StrNoItemSelected -NoTitle -NoProgressBar -Duration 1.0
	}
	else
	{
		if ( $syncHash.Controls.TvMenuList.SelectedItem.Separate -or 
			$null -ne ( $syncHash.Controls.TvMenuList.SelectedItem | Get-Member -Name PS -MemberType NoteProperty )
		)
		{
			$CodeTypeTitle = $syncHash.Data.msgTable.StrCodeTypeToolTitle
			$FilePath = $syncHash.Controls.TvMenuList.SelectedItem.Ps
		}
		else
		{
			$CodeTypeTitle = $syncHash.Data.msgTable.StrCodeTypeFunctionTitle
			$a = Get-Command $syncHash.Controls.TvMenuList.SelectedItem.Name
			$FilePath = $a.Module.Path
		}

		if ( $syncHash.Controls.TvMenuList.SelectedItem.Author -match "\((?<id>.{4})\)" )
		{
			Show-Splash -SelfAdmin
			$Author = $Matches.id
			Send-MailMessage -From ( Get-ADUser ( ( [Environment]::UserName ).Substring( 6, 4 ) ) -Properties mail ).mail `
				-To ( Get-ADUser $Author -Properties mail ).mail `
				-Body @"
	$( $syncHash.Data.msgTable.StrToAuthorInfo )<br><br>
	$( $syncHash.Data.msgTable.StrToAuthorInfoSentBy ): $( ( Get-ADUser -Identity ( [Environment]::UserName ) ).Name )<br>
	$( $CodeTypeTitle ): <strong>$( $syncHash.Controls.TvMenuList.SelectedItem.Name )</strong><br>
	$( $syncHash.Data.msgTable.StrFilePathTitle ): $( $FilePath )<br><br>

	$( $syncHash.Data.msgTable.StrMessageTitle ):<br>
	$( $syncHash.Controls.TbText.Text -replace "`n", "<br>" )<br>
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
	$( $syncHash.Data.msgTable.StrToAuthorInfoSentBy ): $( ( Get-ADUser -Identity ( [Environment]::UserName ) ).Name )<br>
	$( if ( $MailSentToAuthor ) { "$( $syncHash.Data.msgTable.StrSentToAuthor ): $( $Author )" } else { $syncHash.Data.msgTable.StrNotSentToAuthor } )<br><br>
	$( $CodeTypeTitle ): <strong>$( $syncHash.Controls.TvMenuList.SelectedItem.Name )</strong><br>
	$( $syncHash.Data.msgTable.StrFilePathTitle ): $( $FilePath )<br><br>

$( $syncHash.Data.msgTable.StrMessageTitle ):<br>
$( $syncHash.Controls.TbText.Text -replace "`n", "<br>" )<br>
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
		$syncHash.Controls.TbText.Text = ""
	}
} )



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

function Send-Email
{
	<#
	.Synopsis
		Create messagebody
	#>

	param ( [string] $To,
		[string] $Subject
	)

	$FeedbackSender = Get-ADUser ( ( [Environment]::UserName ).Substring( 6, 4 ) ) -Properties mail

	$Msg = [System.Text.StringBuilder]::new()

	if ( "Suggestion" -eq $syncHash.Data.SelectedItem )
	{
		$Msg.AppendLine( "<strong>$( $FeedbackSender.Name )</strong> $( $syncHash.Data.msgTable.StrSuggestionIntro ):<br><br>" ) | Out-Null
	}
	else
	{
		$Msg.AppendLine( "<strong>$( $syncHash.Data.msgTable.StrToAuthorInfoSentBy )</strong>: $( $FeedbackSender.Name )<br>" ) | Out-Null
		if ( $syncHash.Data.msgTable.StrBackOfficeMailAddress -eq $To )
		{
			if ( $syncHash.Data.MailSentToAuthor )
			{
				$Msg.AppendLine( "$( $syncHash.Data.msgTable.StrMessageAuthorInformed )<br><br>" ) | Out-Null
			}
			else
			{
				$Msg.AppendLine( "$( $syncHash.Data.msgTable.StrMessageAuthorNotInformed )<br><br>" ) | Out-Null
			}
		}
		else
		{
			$Msg.AppendLine( "$( $syncHash.Data.msgTable.StrToAuthorInfo )<br><br>" ) | Out-Null
		}
		$Msg.AppendLine( "<strong>$( $syncHash.Data.CodeTypeTitle )</strong>: $( $syncHash.Data.SelectedItem.MenuItem )<br>" ) | Out-Null
		$Msg.AppendLine( "<strong>$( $syncHash.Data.msgTable.StrFilePathTitle )</strong>: $( $syncHash.Data.FilePath )<br><br>" ) | Out-Null
	}

	$Msg.AppendLine( "<strong>$( $syncHash.Data.msgTable.StrMessageTitle )</strong>:<br>" ) | Out-Null
	$Msg.AppendLine( "$( $syncHash.Controls.TbText.Text -replace "`n", "<br>" )<br>" ) | Out-Null

	if ( $syncHash.Controls.ChbIncludeErrorMsgs.IsChecked )
	{
		$Msg.AppendLine( "<br><br><strong>$( $syncHash.Data.msgTable.StrErrorMessageTitle )</strong>:<br>" ) | Out-Null
		$Msg.AppendLine( "$( $syncHash.Controls.TbErrorMsgs.Text -replace "`n", "<br>" )<br><br>" ) | Out-Null
	}

	if ( $syncHash.Data.msgTable.StrBackOfficeMailAddress -eq $To )
	{
		$Msg.AppendLine( "$( $syncHash.Data.msgTable.StrTaskUrlTitle ):<br>" ) | Out-Null
	}
	else
	{
		$Msg.AppendLine( "$( $syncHash.Data.msgTable.StrTaskUrlAuthorTitle ):<br>" ) | Out-Null
	}
	$Msg.AppendLine( "$( $syncHash.Data.TaskUrl )" ) | Out-Null

	Send-MailMessage -From $FeedbackSender.mail `
		-To $To `
		-Encoding bigendianunicode `
		-SmtpServer $syncHash.Data.msgTable.StrSMTP `
		-Subject $Subject `
		-BodyAsHtml `
		-Body $Msg.ToString()
}

function Send-HttpRequest
{
	<#
	.Synopsis
		Send request to create task
	#>

	$u = "<Power Automate Http Request Address>"

	$author = "-"
	try
	{
		$author = ( Get-ADUser ( $syncHash.Controls.TblAuthor.Text -split "\(" )[1].TrimEnd( ")" ) -Properties mail -ErrorAction Stop ).mail
	}
	catch {}

	if ( $syncHash.Controls.ExpSuggestion.IsExpanded )
	{
		$MsgType = $syncHash.Data.msgTable.StrMessageTypeSug
	}
	else
	{
		$MsgType = $syncHash.Data.msgTable.StrMessageTypeErrRep
		$Errors = $syncHash.Controls.TbErrorMsgs.Text
	}

	$TaskInfo = [PSCustomObject]@{
		sender = ( Get-ADUser ( $env:USERNAME -replace "$( $syncHash.Data.StrSysPrefix )" ) -Properties mail ).mail
		author = $author
		message = $syncHash.Controls.TbText.Text
		messagetype = $MsgType
		senttoauthor = $syncHash.Data.MailSentToAuthor
	}

	if ( -not $syncHash.Controls.ExpSuggestion.IsExpanded )
	{
		$TaskInfo.PsObject.Properties.Add( [psnoteproperty]::new( "filepath", $syncHash.Data.FilePath ) )
		$TaskInfo.PsObject.Properties.Add( [psnoteproperty]::new( "codename", $syncHash.Data.SelectedItem.Name ) )
	}

	if ( $Errors.Length -gt 0 )
	{
		$TaskInfo.PsObject.Properties.Add( [psnoteproperty]::new( "errormessages", $Errors ) )
	}

	$TaskInfo = $TaskInfo | ConvertTo-Json -Compress
	$resp = Invoke-RestMethod -Uri $u `
			-Method Post `
			-ContentType "application/json" `
			-Body ( [System.Text.Encoding]::UTF8.GetBytes( $TaskInfo ) ) -UseDefaultCredentials

	return $resp
}

function Set-Localizations
{
}

function Set-SelectedItem
{
	<#
	.Synopsis
		Parse selecteditem for necessary information
	#>

	param( $Item )

	$syncHash.Controls.TblAuthor.Text = $Item.Author
	$syncHash.Controls.TblDescription.Text = $Item.Description
	$syncHash.Data.SelectedItem = $Item
}

###################### Script start

Set-Localizations

$syncHash.Controls.BtnAbortReport.Add_Click( {
	$syncHash.Controls.TbText.Text = ""
	$syncHash.Controls.TbErrorMsgs.Text = ""
} )

$syncHash.Controls.BtnSendReport.Add_Click( {
	$syncHash.Data.TaskUrl = Send-HttpRequest

	if ( $syncHash.Data.SelectedItem -eq "Suggestion" )
	{
		try
		{
			Send-Email -To $syncHash.Data.msgTable.StrBackOfficeMailAddress -Subject $syncHash.Data.msgTable.StrSuggestionSubject
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
				Send-Email -To ( Get-ADUser $CodeAuthor -Properties mail ).mail -Subject $syncHash.Data.msgTable.StrFeedbackSubject
				$syncHash.Data.MailSentToAuthor = $true
				Update-SplashText -Text $syncHash.Data.msgTable.StrSplashToAuthor
			}
			catch
			{
				Write-Error "Send to author `n$_"
			}
		}

		try
		{
			Send-Email -To $syncHash.Data.msgTable.StrBackOfficeMailAddress -Subject $syncHash.Data.msgTable.StrFeedbackSubject 
			Update-SplashText -Text "`n$( $syncHash.Data.msgTable.StrSplashAllSent )" -Append
			Start-Sleep -Seconds 1
			Update-SplashText -Text $syncHash.Data.msgTable.StrSplashFinished
			Close-SplashScreen -Duration 2

			WriteLog -Text "$( $syncHash.Data.msgTable.StrLogAuthorInformed ): $MailSentToAuthor`n$( $syncHash.Controls.TbText.Text )" -Success $true | Out-Null
			$syncHash.Controls.TbText.Text = $syncHash.Controls.TbErrorMsgs.Text = ""
		}
		catch
		{
			Write-Error "Send to BO `n$_"
		}
	}
} )

#
$syncHash.Controls.ExpPropHandler.Add_Expanded( {
	$syncHash.Controls.ExpSuggestion.IsExpanded = $false
	$syncHash.Controls.ExpScript.IsExpanded = $false
} )

#
$syncHash.Controls.ExpPropHandler.Add_Collapsed( {
	$syncHash.Controls.TblAuthor.Text = $syncHash.Controls.TblDescription.Text = $syncHash.Data.CodeTypeTitle = $syncHash.Data.FilePath = ""
	$syncHash.Data.SelectedItem = $null
} )

#
$syncHash.Controls.ExpSuggestion.Add_Expanded( {
	$syncHash.Controls.ExpPropHandler.IsExpanded = $false
	$syncHash.Controls.ExpScript.IsExpanded = $false
} )

#
$syncHash.Controls.ExpSuggestion.Add_Collapsed( {
	$syncHash.Controls.TblAuthor.Text = $syncHash.Controls.TblDescription.Text = $syncHash.Data.CodeTypeTitle = $syncHash.Data.FilePath = ""
	$syncHash.Data.SelectedItem = $null
} )

#
$syncHash.Controls.ExpScript.Add_Expanded( {
	$syncHash.Controls.ExpSuggestion.IsExpanded = $false
	$syncHash.Controls.ExpPropHandler.IsExpanded = $false
} )

#
$syncHash.Controls.ExpScript.Add_Collapsed( {
	$syncHash.Controls.TblAuthor.Text = $syncHash.Controls.TblDescription.Text = $syncHash.Data.CodeTypeTitle = $syncHash.Data.FilePath = ""
	$syncHash.Data.SelectedItem = $null
} )

#
$syncHash.Controls.TBtnSuggestion.Add_Checked( {
	$syncHash.Controls.TbText.Focus()
	$syncHash.Data.SelectedItem = "Suggestion"
} )

#
$syncHash.Controls.TvPropHandlerList.Add_GotKeyboardFocus( {
	$syncHash.Controls.TBtnSuggestion.IsChecked = $false
} )

#
$syncHash.Controls.TvPropHandlerList.Add_SelectedItemChanged( {
	$SelectedItem = $this.SelectedItem
	$ModuleNode = $syncHash.Controls.TvPropHandlerList.ItemsSource.Where( { $_.Items -contains $SelectedItem } ) | Select-Object -First 1

	if ( $null -eq $ModuleNode )
	{
		return
	}

	if ( -not ( ( Get-Module ).Name -contains "$( $ModuleNode.MenuItem )PropHandlers" ) )
	{
		Import-Module "$( $syncHash.Data.BaseDir )\Modules\PropHandlers\$( $ModuleNode.MenuItem )PropHandlers.psm1"
	}

	$PhName = "PH$( $ModuleNode.MenuItem )$( $SelectedItem.MandatorySource )$( $SelectedItem.MenuItem )"

	$SelectedItem.PsObject.Properties.Add( [psnoteproperty]::new( "Name", $PhName ) )
	$syncHash.Data.FilePath = ( Get-Module -Name "$( $ModuleNode.MenuItem )PropHandlers" ).Path

	Set-SelectedItem -Item $SelectedItem
} )

$syncHash.Controls.TvMenuList.Add_GotKeyboardFocus( {
	$syncHash.Controls.TBtnSuggestion.IsChecked = $false
} )

$syncHash.Controls.TvMenuList.Add_SelectedItemChanged( {
	$SelectedItem = $args[1].NewValue
	$ModuleNode = $syncHash.Controls.TvMenuList.ItemsSource.Where( { $_.Items -contains $SelectedItem } )[0]

	if ( $null -eq $ModuleNode )
	{
		return
	}


	if ( $SelectedItem.psobject.Members.Name -contains "Ps" )
	{
		$syncHash.Data.CodeTypeTitle = $syncHash.Data.msgTable.StrCodeTypeToolTitle
		$syncHash.Data.FilePath = $SelectedItem.Ps
	}
	else
	{
		$syncHash.Data.CodeTypeTitle = $syncHash.Data.msgTable.StrCodeTypeFunctionTitle

		if ( $ModuleNode.Module -notin ( Get-Module ).Name )
		{
			Import-Module "$( $syncHash.Data.BaseDir )\Modules\FunctionModules\$( $ModuleNode.Module ).psm1"
		}
		$syncHash.Data.FilePath = ( Get-Module -Name $ModuleNode.Module ).Path
	}
	Set-SelectedItem -Item $SelectedItem
} )

$syncHash.Controls.Window.Add_Loaded( {
} )
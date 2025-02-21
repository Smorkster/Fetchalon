<#
.Syneopsis
	Administration of scripts, logs, etc.
.MeenuItem
	Administration of scripts, logs, etc.
.Description
	Performs administration of updates, logs, reports, etc.
.State
	Prod
.AllowedUsers
	smorkster
.Author
	Smorkster (smorkster)
#>

Add-Type -AssemblyName PresentationFramework
$syncHash = $args[0]

function Confirm-NewCommandInput
{
	<#
	.Synopsis
		Verify entered input
	#>

	$CodeType = switch ( $syncHash.Controls.TcNewCodeTemplate.SelectedIndex )
	{
		0 { "Func" }
		1 { "Tool" }
		2 { "PH" }
	}

	# Verify no errors, for visible settings, are shown
	$SettingsOk = $null -eq ( $syncHash.Controls.GetEnumerator() | `
		Where-Object {
			$_.Name -match "Tbl$($CodeType).*?Error" -and `
			$_.Value.Parent.Parent.Visibility -eq [System.Windows.Visibility]::Visible -and `
			$_.Value.Text -ne "" } )

	$InputOk = ( $syncHash.Controls.TiNewTemplate.Resources.CvsFuncInputData.Source.Where( { $_.Valid -eq $false } ).Count `
			+ $syncHash.Controls.TiNewTemplate.Resources.CvsFuncInputDataList.Source.Where( { $_.Valid -eq $false } ).Count `
			+ $syncHash.Controls.TiNewTemplate.Resources.CvsFuncInputDataBool.Source.Where( { $_.Valid -eq $false } ).Count ) -eq 0

	$syncHash.Controls.TiNewTemplate.Resources.InputOk = $SettingsOk -and $InputOk
}

function Confirm-NewCommandName
{
	<#
	.Synopsis
		Verify name for new command template
	.Parameter TbControl
		Textbox control to check text from
	.Parameter CbControl
		Combobox control to check verb from
	#>

	param ( $TbControl, $CbControl )

	$ErrorMsg = ""
	if ( $null -ne $CbControl -and $CbControl.SelectedIndex -lt 1 )
	{
		$ErrorMsg = $syncHash.Data.msgTable."ErrNew$( $CbControl.Name.SubString( 2, 4 ) )TemplateVerbNotGiven"
	}
	if ( 0 -eq $TbControl.Text.Length )
	{
		$CodeType = switch ( $TbControl.Name.Substring( 2, 2 ) )
		{
			"Fu" { "Func" }
			"To" { "Tool" }
			"PH" { "PH" }
		}
		$ErrorMsg += ", $( $syncHash.Data.msgTable."ErrNew$( $CodeType )NoNameInput" )"
	}
	else
	{
		if ( $TbControl.Text -match "[\s\W]" )
		{
			$ErrorMsg += ", $( $syncHash.Data.msgTable.ErrNewCommandIllegalCharacters )"
		}
		elseif ( $syncHash.Controls.TcNewCodeTemplate.SelectedIndex -lt 2 )
		{
			if ( "$( $CbControl.Text )-$( $TbControl.Text )" -in $syncHash.Data.ExistingCommandNames )
			{
				$ErrorMsg += ", $( $syncHash.Data.msgTable.ErrNewCommandNameExists )"
			}
		}
		elseif ( $syncHash.Controls.TcNewCodeTemplate.SelectedIndex -eq 2 )
		{
			if ( "PH$( $syncHash.Data.NewCodeTemplateInfo.ObjectClass )$( $syncHash.Data.NewCodeTemplateInfo.DataSource )$( $TbControl.Text )" -in $syncHash.Controls.Window.Resources.PropHandlerNames )
			{
				$ErrorMsg += ", $( $syncHash.Data.msgTable.ErrNewPHNameUsed )"
			}
		}
	}

	if ( $ErrorMsg.Length -gt 0 )
	{
		$syncHash.Data.NewCodeTemplateInfo.Remove( "Name" )
		$TbControl.Parent.Children[1].Text = $ErrorMsg.Trim( ", " )
		$TbControl.Parent.Children[1].UpdateLayout()
	}
	else
	{
		if ( $syncHash.Controls.TcNewCodeTemplate.SelectedIndex -eq 2 )
		{
			$syncHash.Data.NewCodeTemplateInfo.Name = "$( $syncHash.Data.NewCodeTemplateInfo.ObjectClass )$( $syncHash.Data.NewCodeTemplateInfo.DataSource )$( $TbControl.Text )"
		}
		else
		{
			$syncHash.Data.NewCodeTemplateInfo.Name = "$( $syncHash.Controls."$( $CbControl.Name )".Text )-$( ( Get-Culture ).TextInfo.ToTitleCase( $syncHash.Controls."$( $TbControl.Name )".Text ) )"
		}
		$TbControl.Parent.Children[1].Text = ""
	}
}

function Confirm-SettingAllowedUsers
{
	<#
	.Synopsis
		Verify entered id:s as existing user accounts
	#>

	param (
		$Control
	)

	$ErrorMsg = ""
	$syncHash.Data.NewCodeTemplateInfo.Remove( "AllowedUsers" )

	if ( $Control.Text.Length -eq 0 )
	{
		$ErrorMsg = ""
	}
	else
	{
		$Control.Text -split "\W|\s" | `
			Where-Object { $_ } | `
			ForEach-Object `
			-Begin { $Errors = [System.Collections.ArrayList]::new() } `
			-Process {
				try
				{
					$Id = $_
					Get-ADUser $Id -ErrorAction Stop | Out-Null
				}
				catch
				{
					$Errors.Add( $Id ) | Out-Null
				}
			}
		if ( $Errors.Count -gt 0 )
		{
			$ErrorMsg = "$( $syncHash.Data.msgTable.ErrNewCodeTemplateAllowedUsersNotFound ): $( $Errors -join ", " )"
		}
	}

	$Control.Parent.Children[1].Text = $ErrorMsg
	if ( $ErrorMsg -eq "" -and $Control.Text.Length -gt 0 )
	{
		$syncHash.Data.NewCodeTemplateInfo.AllowedUsers = $Control.Text
	}

	Confirm-NewCommandInput
}

function Confirm-SettingAuthor
{
	<#
	.Synopsis
		Verify that the id entered is a valid user id
	#>

	param (
		$Control
	)

	$ErrorMsg = ""
	$Control.Parent.Children[1].Text = ""
	$syncHash.Data.NewCodeTemplateInfo.Remove( "Author" )

	if ( $Control.Text.Length -ge 4 )
	{
		try
		{
			$Control.Parent.Children[1].Text = $syncHash.Data.NewCodeTemplateInfo.Author = ( Get-ADUser $Control.Text -ErrorAction Stop ).Name
		}
		catch
		{
			$ErrorMsg = $syncHash.Data.msgTable.ErrNewCodeTemplateAuthorNotFound
		}
	}
	elseif ( $Control.Text.Length -gt 0 )
	{
		$ErrorMsg = $syncHash.Data.msgTable.ErrNewCodeTemplateNoIdentifyableId
	}

	$Control.Parent.Children[2].Text = $ErrorMsg

	Confirm-NewCommandInput
}

function Confirm-SettingDateTime
{
	<#
	.Synopsis
		Verify that a valid date time string have been entered
	#>

	param (
		$Control
	)

	$Control.Name -match "Tb(?<CodeType>(Func)|(Tool)|(PH))(?<SettingName>.*)" | Out-Null
	$CodeType = $Matches.CodeType
	$SettingName = $Matches.SettingName
	$OtherSetting = if ( $SettingName -eq "ValidStartDateTime" ) { "InvalidateDateTime" } else { "ValidStartDateTime" }

	$syncHash.Data.NewCodeTemplateInfo.Remove( $SettingName )
	$ErrorMsg = ""

	if ( $Control.Text.Length -eq 0 -or $this.Text -eq " " )
	{
		$ErrorMsg = ""
	}
	else
	{
		try
		{
			$ParsedTime = [datetime]::Parse( $Control.Text )

			if ( $null -ne $syncHash.Data.NewCodeTemplateInfo.$OtherSetting )
			{
				if ( $ParsedTime -gt $syncHash.Data.NewCodeTemplateInfo.$OtherSetting -and `
					$SettingName -match "ValidStartDateTime"
				)
				{
					$ErrorMsg = $syncHash.Data.msgTable.ErrNewCodeTemplateStartAfterEnd
				}
				elseif ( $ParsedTime -gt $syncHash.Data.NewCodeTemplateInfo.$OtherSetting -and `
					$SettingName -match "ValidStartDateTime"
				)
				{
					$ErrorMsg = $syncHash.Data.msgTable.ErrNewCodeTemplateStartAfterEnd
				}
				elseif ( $ParsedTime -lt ( Get-Date ) -and `
					$SettingName -match "InvalidateDateTime"
				)
				{
					$ErrorMsg = $syncHash.Data.msgTable.ErrNewCodeTemplateEndBeforeNow
				}
				elseif ( $ParsedTime -lt $syncHash.Data.NewCodeTemplateInfo.$OtherSetting -and `
					$SettingName -match "InvalidateDateTime"
				)
				{
					$ErrorMsg = $syncHash.Data.msgTable.ErrNewCodeTemplateEndBeforeStart
				}
				elseif ( $ParsedTime -eq $syncHash.Data.NewCodeTemplateInfo.$OtherSetting )
				{
					$ErrorMsg = $syncHash.Data.msgTable.ErrNewCodeTemplateStartEndSame
				}
			}
		}
		catch
		{
			$ErrorMsg = $syncHash.Data.msgTable.ErrNewCodeTemplateStartParseError
		}
	}

	$Control.Parent.Children[1].Text = $ErrorMsg
	if ( $ErrorMsg -eq "" )
	{
		$syncHash.Data.NewCodeTemplateInfo.$SettingName = $ParsedTime
	}

	Confirm-NewCommandInput
}

function Confirm-SettingDescription
{
	<#
	.Synopsis
		Verify any description
	#>

	param (
		$Control
	)

	$ErrorMsg = ""
	$syncHash.Data.NewCodeTemplateInfo.Remove( "Description" )

	if ( $Control.Text.Length -eq 0 )
	{
		$ErrorMsg = $syncHash.Data.msgTable.ErrNewCodeTemplateDescriptionEmpty
	}
	else
	{
		$syncHash.Data.NewCodeTemplateInfo.Description = $Control.Text
	}

	$Control.Parent.Children[1].Text = $ErrorMsg

	Confirm-NewCommandInput
}

function Confirm-SettingMenuItem
{
	<#
	.Synopsis
		Verify entered menuitem
	#>

	param (
		$Control
	)

	$ErrorMsg = ""
	$syncHash.Data.NewCodeTemplateInfo.Remove( "MenuItem" )

	if ( $Control.Text.Length -eq 0 )
	{
		$ErrorMsg = $syncHash.Data.msgTable.ErrNewCodeTemplateMenuItemEmpty
	}
	elseif ( $Control.Text -match "_" )
	{
		$ErrorMsg = $syncHash.Data.msgTable.ErrNewCodeTemplateMenuItemUnderscore
	}
	elseif ( $Control.Text -match "[^a-zåäöA-ZÅÄÖ0-9 ]" )
	{
		$ErrorMsg = $syncHash.Data.msgTable.ErrNewCodeTemplateMenuItemInvalidCharacters
	}
	elseif ( $Control.Text -in $syncHash.Data.ExistingMenuItems )
	{
		$ErrorMsg = $syncHash.Data.msgTable.ErrNewCodeTemplateMenuItemExists
	}
	else
	{
		$ErrorMsg = ""
		$syncHash.Data.NewCodeTemplateInfo.MenuItem = $Control.Text
	}

	$Control.Parent.Children[1].Text = $ErrorMsg

	Confirm-NewCommandInput
}

function Confirm-SettingObjectType
{
	<#
	.Synopsis
		Verify is an objecttype has been chosen
	#>

	param (
		$Control
	)

	if ( $Control.Name -eq "CbFuncObjectClass" )
	{
		$syncHash.Data.NewCodeTemplateInfo.Remove( "ObjectClass" )
		if ( $Control.SelectedIndex -gt 0 )
		{
			$syncHash.Data.NewCodeTemplateInfo.ObjectClass = $Control.SelectedItem.ObjectOperation
			$syncHash.Controls.TblFuncObjectClassInfo.Text = "$( $syncHash.Data.msgTable.StrNewFuncObjectOperationsTypeChosen ) '$( $syncHash.Controls.CbFuncObjectClass.SelectedItem.LocalizedName )'"
		}
		else
		{
			$syncHash.Data.NewCodeTemplateInfo.ObjectClass = "Other"
			$syncHash.Controls.TblFuncObjectClassInfo.Text = $syncHash.Data.msgTable.StrNewFuncObjectOperationsNoneChosen
		}
		$syncHash.Controls.CbFuncExistingSubMenus.ItemsSource.Refresh()
	}
	elseif ( $Control.Name -eq "CbToolObjectOperations" )
	{
		$syncHash.Data.NewCodeTemplateInfo.Remove( "ObjectOperations" )
		if ( $Control.SelectedIndex -gt 0 )
		{
			$syncHash.Data.NewCodeTemplateInfo.ObjectOperations = $Control.SelectedItem.ObjectOperation
			$syncHash.Controls.TblToolObjectOperationsInfo.Text = "$( $syncHash.Data.msgTable.StrNewToolObjectOperationsTypeChosen ) '$( $syncHash.Controls.CbToolObjectOperations.SelectedItem.LocalizedName )'"
		}
		else
		{
			$syncHash.Controls.TblToolObjectOperationsInfo.Text = $syncHash.Data.msgTable.StrNewToolObjectOperationsNoneChosen
		}
		$syncHash.Controls.CbToolExistingSubMenus.ItemsSource.Refresh()
	}
	else
	{
		$syncHash.Data.NewCodeTemplateInfo.Remove( "ObjectClass" )
		if ( 1 -gt $Control.SelectedIndex )
		{
			$Control.Parent.Children[1].Text = $syncHash.Data.msgTable.ErrNewPHObjectClassNotGiven
		}
		else
		{
			$Control.Parent.Children[1].Text = ""
			$syncHash.Data.NewCodeTemplateInfo.ObjectClass = $Control.SelectedItem.ObjectOperation
		}
	}

	Confirm-NewCommandInput
}

function Confirm-SettingRequiredAdGroups
{
	<#
	.Synopsis
		Verify that the text does not contain any invalid AD-group names
	#>

	param (
		$Control
	)

	$ErrorMsg = ""
	$syncHash.Data.NewCodeTemplateInfo.Remove( "RequiredAdGroups" )
	if ( $Control.Text.Length -eq 0 )
	{
		$ErrorMsg = ""
	}
	else
	{
		$Control.Text -split "\W|\s" | `
			Where-Object { $_ } | `
			ForEach-Object `
			-Begin {
				$Errors = [System.Collections.ArrayList]::new()
			} `
			-Process {
				try
				{
					$Id = $_
					Get-ADGroup $Id -ErrorAction Stop | Out-Null
				}
				catch
				{
					$Errors.Add( $Id ) | Out-Null
				}
			}
		if ( $Errors.Count -gt 0 )
		{
			$ErrorMsg = "$( $syncHash.Data.msgTable.ErrNewCodeTemplateRequiredAdGroupsNotFound ): $( $Errors -join ", " )"
		}
	}

	$Control.Parent.Children[1].Text = $ErrorMsg
	if ( $ErrorMsg -eq "" )
	{
		$syncHash.Data.NewCodeTemplateInfo.RequiredAdGroups = $Control.Text
	}

	Confirm-NewCommandInput
}

function Confirm-SettingState
{
	<#
	.Synopsis
		Verify that state has been set
	#>

	param (
		$Control
	)

	if ( $Control.SelectedIndex -lt 1 )
	{
		$Control.Parent.Children[1].Text = $syncHash.Data.msgTable.ErrNewCodeTemplateStateMissing
		$syncHash.Data.NewCodeTemplateInfo.Remove( "State" )
	}
	else
	{
		$Control.Parent.Children[1].Text = ""
		$syncHash.Data.NewCodeTemplateInfo.State = $Control.SelectedItem
	}

	Confirm-NewCommandInput
}

function Confirm-SettingSubMenu
{
	<#
	.Synopsis
		Verify that entered name for submenu is valid
	#>

	param (
		$Control
	)

	if ( $Control.Text -match "\W|\s" )
	{
		$Control.Parent.Children[1].Text = $syncHash.Data.msgTable.ErrNewCodeTemplateSubMenuInvalidCharacters
		$syncHash.Data.NewCodeTemplateInfo.Remove( "SubMenu" )
	}
	elseif ( $this.Text.Length -eq 0 )
	{
		$syncHash.Data.NewCodeTemplateInfo.Remove( "SubMenu" )
	}
	else
	{
		$Control.Parent.Children[1].Text = ""
		$syncHash.Data.NewCodeTemplateInfo.SubMenu = $this.Text
	}

	Confirm-NewCommandInput
}

function Confirm-SettingSynopsis
{
	<#
	.Synopsis
		Verify that synopsis have been entered
	#>

	param (
		$Control
	)

	$ErrorMsg = ""
	$syncHash.Data.NewCodeTemplateInfo.Remove( "Synopsis" )

	if ( $Control.Text -match "[_]" )
	{
		$ErrorMsg = $syncHash.Data.msgTable.ErrNewCodeTemplateSynopsisUnderscore
	}
	elseif ( $Control.Text.Length -eq 0 )
	{
		$ErrorMsg = $syncHash.Data.msgTable.ErrNewCodeTemplateSynopsisEmpty
	}
	else
	{
		$syncHash.Data.NewCodeTemplateInfo.Synopsis = $this.Text
	}

	$Control.Parent.Children[1].Text = $ErrorMsg

	Confirm-NewCommandInput
}

function Get-NewCodeTemplateInput
{
	<#
	.Synopsis
		Collect data entered as InputData for the new function
	#>

	$syncHash.Controls.TiNewTemplate.Resources.CvsFuncInputData.Source | `
		ForEach-Object {
			$syncHash.Data.CodeInfo += "`t.InputData`n`t`t$( $_.Name ), $( if ( $_.Mandatory ) { "True" } else { "False" } ), $( $_.Description )`n"
		}

	$syncHash.Controls.TiNewTemplate.Resources.CvsFuncInputDataList.Source | `
		ForEach-Object {
			$syncHash.Data.CodeInfo += "`t.InputDataList`n`t`t$( $_.Name ) | $( if ( $_.Mandatory ) { "True" } else { "False" } ) | $( $_.Description ) | $( $_.DefaultValue ) | $( $_.OptionsList )`n"
		}

	$syncHash.Controls.TiNewTemplate.Resources.CvsFuncInputDataBool.Source | `
		ForEach-Object {
			$syncHash.Data.CodeInfo += "`t.InputDataBool`n`t`t$( $_.Name ), $( $_.Description )`n"
		}
}

function Get-NewTemplateTypeSelected
{
	<#
	.Synopsis
		Verify selected new code template type
	#>

	Reset-NewTemplateControls

	switch ( $syncHash.Controls.TcNewCodeTemplate.SelectedIndex )
	{
		0 { $syncHash.Controls.TiNewTemplate.Resources.CvsFuncSettingsCollection.View.Refresh() }
		1 { $syncHash.Controls.TiNewTemplate.Resources.CvsToolSettingsCollection.View.Refresh() }
		2 { $syncHash.Controls.TiNewTemplate.Resources.CvsPHSettingsCollection.View.Refresh() }
	}
}

function Get-Updates
{
	<#
	.Synopsis
		Search for any updated file
	#>

	$syncHash.Controls.Window.Resources['CvsDgUpdates'].Source.Clear()
	$syncHash.Controls.Window.Resources['CvsDgUpdatedInProd'].Source.Clear()
	$syncHash.Controls.Window.Resources['CvsDgFailedUpdates'].Source.Clear()
	$syncHash.Controls.TbUpdated.SelectedIndex = 0

	$syncHash.Jobs.HParseUpdates = $syncHash.Jobs.PParseUpdates.BeginInvoke()
}

function Initialize-NewTemplateControls
{
	<#
	.Synopsis
		Reset form
	#>

	$syncHash.Data.NewCodeTemplateInfo = @{}
	$syncHash.Controls.TiNewTemplate.Resources.CvsFuncSubMenus.View.Filter = $syncHash.Code.FuncSubMenuFilter
	$syncHash.Controls.TiNewTemplate.Resources.CvsToolSubMenus.View.Filter = $syncHash.Code.ToolSubMenuFilter
	$syncHash.Controls.TiNewTemplate.Resources.CvsFuncSettingsCollection.View.Filter = $syncHash.Code.AddFuncSettingFilter
	$syncHash.Controls.TiNewTemplate.Resources.CvsPHSettingsCollection.View.Filter = $syncHash.Code.AddPHSettingFilter
	$syncHash.Controls.TiNewTemplate.Resources.CvsToolSettingsCollection.View.Filter = $syncHash.Code.AddToolSettingFilter

	"RbFuncNoteTypeInfo", "RbFuncNoteTypeWarning" | `
		ForEach-Object {
			$syncHash.Controls."$( $_ )".IsChecked = $true
		}

	"CbFuncPsVerbs", "CbToolPsVerbs", "CbFuncState", "CbPHState", "CbToolState", "CbFuncObjectClass", "CbPHDataSource", "CbPHObjectClass", "CbToolObjectOperations", "CbFuncExistingSubMenus", "CbToolExistingSubMenus", "CbFuncOutputType", "CbFuncSearchedItemRequest" | `
		ForEach-Object {
			$syncHash.Controls."$( $_ )".SelectedIndex = 1
		}

	"TbFuncName", "TbToolName", "TbPHName", "TbFuncAuthor", "TbToolAuthor", "TbPHAuthor", "TbFuncSynopsis", "TbToolSynopsis", "TbPHTitle", "TbFuncDescription", "TbPHDescription", "TbToolDescription", "TbFuncMenuItem", "TbToolMenuItem", "TbFuncAllowedUsers", "TbToolAllowedUsers", "TbFuncRequiredAdGroups", "TbPHRequiredAdGroups", "TbToolRequiredAdGroups", "TbFuncValidStartDateTime", "TbPHValidStartDateTime", "TbToolValidStartDateTime", "TbFuncInvalidateDateTime", "TbPHInvalidateDateTime", "TbToolInvalidateDateTime", "TbPHCodeComment" | `
		ForEach-Object {
			$syncHash.Controls."$( $_ )".Text = "-"
		}

	"ChbFuncNoRunspace", "ChbToolSeparate" | `
		ForEach-Object {
			$syncHash.Controls."$( $_ )".IsChecked = $true
		}

	"CvsFuncInputData", "CvsFuncInputDataList", "CvsFuncInputDataBool" | `
		ForEach-Object {
			$syncHash.Controls.TiNewTemplate.Resources."$( $_ )".Source.Add( 1 )
		}
}

function Initialize-Parsing
{
	<#
	.Synopsis
		Create powershell-objects and scripts for parsing
	#>

	$syncHash.Jobs.PParseErrorLogs = [powershell]::Create( [initialsessionstate]::CreateDefault() )
	$syncHash.Jobs.PParseErrorLogs.AddScript( {
		param ( $syncHash, $Modules )

		Import-Module $Modules

		$syncHash.Controls.Window.Resources['CvsErrorLogsScriptNames'].Source.Clear()
		$syncHash.Controls.Window.Dispatcher.Invoke( [action] {
			$syncHash.Controls.GridErrorlogsList.Visibility = [System.Windows.Visibility]::Collapsed
			$syncHash.Controls.PbParseErrorLogs.IsIndeterminate = $true
		} )
		$syncHash.Data.ErrorLoggs = Get-ChildItem "$( $syncHash.Data.BaseDir )\ErrorLogs" -Recurse -File -Filter "*.json" | Sort-Object Name
		$syncHash.Controls.PbParseErrorLogs.Maximum = [double] $syncHash.Data.ErrorLoggs.Count
		$syncHash.Data.ParsedErrorLogs.Clear()
		$syncHash.DC.PbParseErrorLogsOps[0] = 0.0
		$syncHash.DC.PbParseErrorLogs[0] = 0.0

		$syncHash.Controls.Window.Dispatcher.Invoke( [action] {
			$syncHash.Controls.PbParseErrorLogs.IsIndeterminate = $false
		} )
		$syncHash.Data.ErrorLoggs | `
			ForEach-Object {
				$n = $_.BaseName -replace " - ErrorLog"
				if ( $syncHash.Data.ParsedErrorLogs.ScriptName -notcontains $n )
				{
					$syncHash.Data.ParsedErrorLogs.Add(
						[pscustomobject]@{
							ScriptName = $n
							ScriptErrorLogs = [System.Collections.ArrayList]::new()
							ScriptErrorLogsRecent = [System.Collections.ArrayList]::new()
						}
					)
				}
				Get-Content $_.FullName | `
					ForEach-Object {
						$log = NewErrorLog ( $_ | ConvertFrom-Json )
						( $syncHash.Data.ParsedErrorLogs.Where( { $_.ScriptName -eq $n } ) )[0].ScriptErrorLogs.Add( $log )
						if ( ( Get-Date $log.LogDate ) -gt ( Get-Date ).AddDays( -7 ) )
						{
							[void] ( $syncHash.Data.ParsedErrorLogs.Where( { $_.ScriptName -eq $n } ) )[0].ScriptErrorLogsRecent.Add( $log )
						}
					}
				$syncHash.DC.PbParseErrorLogs[0] += 1
			}

		$syncHash.DC.PbParseErrorLogsOps[0] = 1.0

		$syncHash.Controls.PbParseErrorLogs.Maximum = $syncHash.Data.ParsedErrorLogs.Count
		$syncHash.Controls.Window.Dispatcher.Invoke( [action] { $syncHash.Controls.PbParseErrorLogs.Value = 0.0 } )
		$syncHash.Data.ParsedErrorLogs | ForEach-Object {
			$_.ScriptErrorLogs = $_.ScriptErrorLogs | Sort-Object LogDate -Descending
			$syncHash.DC.PbParseErrorLogs[0] += 1
		}
		$syncHash.DC.PbParseErrorLogsOps[0] = 2.0

		$syncHash.DC.PbParseErrorLogs[0] = 0.0
		$syncHash.Controls.Window.Dispatcher.Invoke( [action] {
			$syncHash.Controls.Window.Resources['CvsErrorLogsScriptNames'].Source = $syncHash.Data.ParsedErrorLogs
			$syncHash.Controls.Window.Resources['CvsErrorLogsScriptNames'].View.Refresh()
		}, [System.Windows.Threading.DispatcherPriority]::Send )

		$syncHash.DC.PbParseErrorLogsOps[0] = 3.0
		$syncHash.Controls.Window.Dispatcher.Invoke( [action] {
			$syncHash.Controls.GridErrorlogsList.Visibility = [System.Windows.Visibility]::Visible
		} )
	} )
	$syncHash.Jobs.PParseErrorLogs.AddArgument( $syncHash )
	$syncHash.Jobs.PParseErrorLogs.AddArgument( ( Get-Module ) )

	$syncHash.Jobs.PParseLogs = [powershell]::Create( [initialsessionstate]::CreateDefault() )
	$syncHash.Jobs.PParseLogs.AddScript( {
		param ( $syncHash, $Modules )

		Add-Type -AssemblyName PresentationFramework
		Import-Module $Modules

		$syncHash.Controls.Window.Dispatcher.Invoke( [action] {
			$syncHash.Controls.PbLogSearch.Visibility = [System.Windows.Visibility]::Visible
		} )
		$syncHash.Data.ParsedLogs.Clear()
		$a = Get-ChildItem "$( $syncHash.Data.BaseDir )\Logs" -Recurse -File -Filter "*log.json"
		$syncHash.Controls.Window.Dispatcher.Invoke( [action] {
			$syncHash.Controls.PbLogSearch.IsIndeterminate = $false
			$syncHash.Controls.PbLogSearch.Maximum = [double] $a.Count
			$syncHash.Controls.PbLogSearch.Value = 0.0
		} )

		$a | Sort-Object Name | `
			ForEach-Object {
				$n = $_.BaseName -replace " - Log"
				if ( $syncHash.Data.ParsedLogs.ScriptName -notcontains $n )
				{
					[void] $syncHash.Data.ParsedLogs.Add(
						[pscustomobject]@{
							ScriptName = $n
							ScriptLogs = [System.Collections.ArrayList]::new()
							ScriptLogsRecent = [System.Collections.ArrayList]::new()
						}
					)
				}

				Get-Content $_.FullName | `
					ForEach-Object {
						$log = NewLog ( $_ | ConvertFrom-Json )
						[void] ( $syncHash.Data.ParsedLogs.Where( { $_.ScriptName -eq $n } ) )[0].ScriptLogs.Add( $log )
						if ( ( Get-Date $log.LogDate ) -gt ( Get-Date ).AddDays( -7 ) )
						{
							[void] ( $syncHash.Data.ParsedLogs.Where( { $_.ScriptName -eq $n } ) )[0].ScriptLogsRecent.Add( $log )
						}
					}
				$syncHash.DC.PbLogSearch[0] += 1
			}

		$syncHash.Data.ParsedLogs | `
			ForEach-Object {
				$_.ScriptLogs = [System.Collections.ArrayList]::new( @( $_.ScriptLogs | Sort-Object -Property LogDate -Descending ) )
			}
		$syncHash.Controls.Window.Dispatcher.Invoke( [action] {
			$syncHash.Controls.Window.Resources['CvsCbLogsScriptNames'].Source = $syncHash.Data.ParsedLogs
			$syncHash.Controls.Window.Resources['CvsCbLogsScriptNames'].View.Refresh()
			$syncHash.Controls.PbLogSearch.Visibility = [System.Windows.Visibility]::Collapsed
		} )
		$syncHash.Controls.RbLogsDisplayPeriodRecent.IsChecked = $true
	} )
	$syncHash.Jobs.PParseLogs.AddArgument( $syncHash )
	$syncHash.Jobs.PParseLogs.AddArgument( ( Get-Module ) )

	$syncHash.Jobs.PParseRollbacks = [powershell]::Create( [initialsessionstate]::CreateDefault() )
	$syncHash.Jobs.PParseRollbacks.AddScript( {
		param ( $syncHash, $Modules )
		Import-Module $Modules

		$syncHash.Data.RollbackData.Clear()
		$syncHash.Data.RollbackFiles.Clear()

		Get-ChildItem $syncHash.Data.RollbackRoot -Recurse -File | Sort-Object Name | ForEach-Object { $syncHash.Data.RollbackFiles.Add( $_ ) | Out-Null }
		$syncHash.Controls.Window.Dispatcher.Invoke( [action] {
			$syncHash.Controls.PbListingRollbacks.Visibility = [System.Windows.Visibility]::Visible
			$syncHash.Controls.Window.Resources['CvsLvRollbackFileNames'].Source.Clear()
		} )

		foreach ( $File in $syncHash.Data.RollbackFiles )
		{
			$File.BaseName -match "^(?<Name>.*)\.\w* \(\w* (?<Date>.* .*), (?<Updater>\w*)\)" | Out-Null
			$FileData = [pscustomobject]@{
				File = $File
				FileName = $Matches.Name
				Updated = Get-Date "$( $Matches.Date -replace "\.", ":" )"
				UpdatedBy = $Matches.Updater
				Type = $File.Extension -replace "\."
			}

			if ( $syncHash.Data.RollbackData.FileName -notcontains $FileData.FileName )
			{
				$TempArray = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
				$TempArray.Add( $FileData )
				[void] $syncHash.Data.RollbackData.Add( [pscustomobject]@{ FileName = $FileData.FileName ; FileLogs = $TempArray } )
			}
			else
			{
				( $syncHash.Data.RollbackData.Where( { $_.FileName -eq $FileData.FileName } ) )[0].FileLogs.Add( $FileData )
			}
		}

		$syncHash.Data.RollbackData | ForEach-Object { [System.Collections.ObjectModel.ObservableCollection[object]] $_.FileLogs = $_.FileLogs | Sort-Object Updated -Descending }
		$syncHash.Controls.Window.Dispatcher.Invoke( [action] {
			$syncHash.Controls.Window.Resources['CvsLvRollbackFileNames'].Source = $syncHash.Data.RollbackData
			$syncHash.Controls.PbListingRollbacks.Visibility = [System.Windows.Visibility]::Collapsed
		} )
	} )
	$syncHash.Jobs.PParseRollbacks.AddArgument( $syncHash )
	$syncHash.Jobs.PParseRollbacks.AddArgument( ( Get-Module ) )

	$syncHash.Jobs.PParseUpdates = [powershell]::Create()
	$syncHash.Jobs.PParseUpdates.AddScript( {
		param ( $syncHash, $Modules )
		Import-Module $Modules

		$ProdFiles = [System.Collections.ArrayList]::new()
		$DevFiles = [System.Collections.ArrayList]::new()
		$MD5 = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider

		$syncHash.DC.TblUpdatesProgress[0] = $syncHash.Data.msgTable.StrCheckingUpdatesGetFiles
		Get-ChildItem $syncHash.Data.ProdRoot -Directory -Exclude ErrorLogs, Logs, Output, Development, UpdateRollback | `
			ForEach-Object {
				Get-ChildItem -Path $_ -Recurse -File | ForEach-Object { $ProdFiles.Add( $_ ) | Out-Null }
			}

		Get-ChildItem $syncHash.Data.DevRoot -Directory -Exclude ErrorLogs, Logs, Output, Tests | `
			ForEach-Object {
				Get-ChildItem -Path $_ -Recurse -File | ForEach-Object { $DevFiles.Add( $_ ) | Out-Null }
			}

		$syncHash.DC.PbParseUpdates[0] = [double] 0
		$syncHash.DC.PbParseUpdates[1] = [double] $DevFiles.Count
		

		$DevFiles | `
			ForEach-Object `
				-Process {
					try { Remove-Variable DevFile, ProdFile, File, DevMD5, ProdMD5 -ErrorAction Stop } catch {}
					$DevFile = $_

					$ProdFile = $ProdFiles | Where-Object { $_.Name -eq $DevFile.Name } | Select-Object -First 1

					$DevMD5 = [System.BitConverter]::ToString( $MD5.ComputeHash( [System.IO.File]::ReadAllBytes( $DevFile.FullName ) ) )
					try { $ProdMD5 = [System.BitConverter]::ToString( $MD5.ComputeHash( [System.IO.File]::ReadAllBytes( $ProdFile.FullName ) ) ) } catch {}

					if ( $DevMD5 -ne $ProdMD5 )
					{
						$File = [pscustomobject]@{
							DevFile = $DevFile | Select-Object *
							New = $false
							ProdFile = $null
							ScriptInfo = $null
							ToolTip = ""
						}

						if ( $DevFile.Extension -notmatch "psm*1" )
						{
							Add-Member -InputObject $File -MemberType NoteProperty -Name "SFile" -Value ( Get-ChildItem -Path "$( $syncHash.Data.DevRoot )" -Recurse -File -ErrorAction Stop | Where-Object { $_.BaseName -eq $DevFile.BaseName -and $_.Extension -match "psm*1" } | Select-Object -First 1 -ExpandProperty FullName )
						}

						if ( $DevFile.LastWriteTime -gt $ProdFile.LastWriteTime )
						{
							if ( $null -ne $ProdFile )
							{
								$File.ProdFile = $ProdFile | Select-Object *
							}
							else
							{
								$File.New = $true
							}
							$syncHash.Controls.Window.Dispatcher.Invoke( [action] {
								$syncHash.Controls.Window.Resources['CvsDgUpdates'].Source.Add( $File ) | Out-Null
							}, [System.Windows.Threading.DispatcherPriority]::Send )
						}
					}

					$syncHash.DC.PbParseUpdates[0] += 1
					$syncHash.DC.TblUpdatesProgress[0] = "$( $syncHash.Data.msgTable.StrCheckingUpdatesCheckFiles ) $( [System.Math]::Round( ( $syncHash.DC.PbParseUpdates[0] / $syncHash.DC.PbParseUpdates[1] ) * 100 , 2 ) ) %"
				} `
			-End {
				try
				{
					Remove-Variable DevFile, ProdFile, File, DevMD5, ProdMD5 -ErrorAction Stop
				} catch {}

				$syncHash.Controls.Window.Dispatcher.Invoke( [action] {
					$syncHash.Controls.Window.Resources['CvsDgUpdates'].View.Refresh()
				}, [System.Windows.Threading.DispatcherPriority]::Send )
			}

		$syncHash.DC.PbParseUpdates[0] = [double] 0
		$syncHash.DC.PbParseUpdates[1] = [double] $ProdFiles.Count
		$ProdFiles | `
			ForEach-Object `
				-Process {
					$ProdFile = $_

					$DevFile = $DevFiles | Where-Object { $_.Name -eq $ProdFile.Name } | Select-Object -First 1

					$ProdMD5 = [System.BitConverter]::ToString( $MD5.ComputeHash( [System.IO.File]::ReadAllBytes( $ProdFile.FullName ) ) )
					try { $DevMD5 = [System.BitConverter]::ToString( $MD5.ComputeHash( [System.IO.File]::ReadAllBytes( $DevFile.FullName ) ) ) } catch {}

					$File = [pscustomobject]@{
						ProdFile = $ProdFile | Select-Object *
						New = $false
						DevFile = $null
						ToolTip = ""
						DevMD5 = ""
						ProdMD5 = ""
					}
					if ( $DevMD5 -ne $ProdMD5 -or $null -eq $DevFile )
					{
						$File.DevMD5 = $DevMD5
						$File.ProdMD5 = $ProdMD5
						$File.DevFile = $DevFile | Select-Object *
						if ( $null -eq $DevFile )
						{
							$File.New = $true
						}
						if ( $ProdFile.LastWriteTime -gt $DevFile.LastWriteTime )
						{
							$syncHash.Controls.Window.Dispatcher.Invoke( [action] {
								$syncHash.Controls.Window.Resources['CvsDgUpdatedInProd'].Source.Add( $File ) | Out-Null
							}, [System.Windows.Threading.DispatcherPriority]::Send )
						}
					}

					$syncHash.DC.PbParseUpdates[0] += 1
				}
		$syncHash.Controls.Window.Dispatcher.Invoke( [action] {
			$syncHash.DC.TbDevCount[0] = $syncHash.Controls.Window.Resources['CvsDgUpdates'].Source.Where( { $_.ScriptInfo.State -eq "Dev" } ).Count
			$syncHash.DC.TbTestCount[0] = $syncHash.Controls.Window.Resources['CvsDgUpdates'].Source.Where( { $_.ScriptInfo.State -eq "Test" } ).Count
			$syncHash.DC.TbProdCount[0] = $syncHash.Controls.Window.Resources['CvsDgUpdates'].Source.Where( { $_.ScriptInfo.State -eq "Prod" } ).Count
			$syncHash.DC.TblInfo[0] = [System.Windows.Visibility]::Visible
			$syncHash.DC.TblUpdateInfo[0] = $syncHash.Data.msgTable.StrNoUpdates
		} , [System.Windows.Threading.DispatcherPriority]::Send )
		$syncHash.DC.PbParseUpdates[0] = 0.0
	} )
	$syncHash.Jobs.PParseUpdates.AddArgument( $syncHash )
	$syncHash.Jobs.PParseUpdates.AddArgument( ( Get-Module ) )
}

function New-CodeInfo
{
	if ( 1 -eq $syncHash.Controls.TcNewCodeTemplate.SelectedIndex )
	{
		$Indent = "`t"
	}
	else
	{
		$Indent = ""
	}

	$syncHash.Data.NewCodeTemplateInfo.GetEnumerator() | `
		ForEach-Object `
		-Begin { $syncHash.Data.CodeInfo = "$( $Indent )<#`n" } `
		-Process {
			if ( $_.Name -notin "Name", "Separate" )
			{
				$syncHash.Data.CodeInfo += "$( $Indent ).$( $_.Name )`n`t$( $Indent )$( $_.Value )`n"
			}
		} `
		-End {
			Get-NewCodeTemplateInput
			$syncHash.Data.CodeInfo += "$( $Indent )#>"
		}

}

function New-CodeTemplateFunc
{
	$ObjectClass = $syncHash.Data.NewCodeTemplateInfo.ObjectClass
	$ModulePath = ( Get-Module "$( $ObjectClass )Functions" ).Path

	# Get location for new function in module file
	$ModuleContent = [System.Collections.ArrayList]::new()
	( Get-Content -LiteralPath $ModulePath ) -split "`r`n" | `
		ForEach-Object {
			$ModuleContent.Add( $_ ) | Out-Null
		}

	$NewFunctionName = $syncHash.Data.NewCodeTemplateInfo.Name

	$ExistingNames = ( Get-Module "$( $ObjectClass )Functions" ).ExportedCommands.Keys | Sort-Object
	$NewNameIndex = ( $ExistingNames + $NewFunctionName | Sort-Object ).IndexOf( $NewFunctionName )
	$NextFunc = ( $ExistingNames + $NewFunctionName | Sort-Object )[$NewNameIndex+1]
	if ( $null -eq $NextFunc )
	{
		$InsertIndex = $ModuleContent.IndexOf( "function $( $ExistingNames[-1] )" ) + ( ( Get-Command $ExistingNames[-1] ).Definition -split "`n" ).Count + 2
	}
	else
	{
		$InsertIndex = $ModuleContent.IndexOf( "function $( $NextFunc )" )
	}

	# Gather info to place in CodeInfo
	New-CodeInfo

	# Create CodeInfo
	$FunctionText = "function $( $NewFunctionName )`n{`n$( $syncHash.Data.CodeInfo )"
	if ( $syncHash.Data.CodeInfo -match "(InputData)|(SearchedItemRequest)" )
	{
		if ( $syncHash.Data.CodeInfo -match "InputData" -and $syncHash.Data.CodeInfo -match "SearchedItemRequest" -and $syncHash.Data.CodeInfo.SearchedItemRequest -match "(Allowed)|(Required)" )
		{
			$FunctionText += "`n`n`tparam ( $( '$' )Item, $( '$' )InputData )`n"
		}
		elseif ( $syncHash.Data.CodeInfo -match "InputData" )
		{
			$FunctionText += "`n`n`tparam ( $( '$' )InputData )`n"
		}
		elseif ( $syncHash.Data.CodeInfo -match "SearchedItemRequest" -and $syncHash.Data.CodeInfo.SearchedItemRequest -match "(Allowed)|(Required)" )
		{
			$FunctionText += "`n`n`tparam ( $( '$' )Item )`n"
		}
		else
		{
		}
	}
	$FunctionText +="`n`n}"

	$ModuleContent.Insert( $InsertIndex, "$( $FunctionText )`n" )

	try
	{
		Set-Content -Path $ModulePath -Value ( $ModuleContent -join "`r`n" ) -Encoding UTF8 -ErrorAction Stop

		if ( ( Show-MessageBox -Text "$( $syncHash.Data.msgTable.StrFunctionCreated )`n$( $ModulePath )" -Button "YesNo" ) -eq "Yes" )
		{
			Open-File -FilePaths ( ,$ModulePath ) -StartAtRow $InsertIndex
		}
	}
	catch
	{
		
	}
}

function New-CodeTemplatePropHandler
{
	if ( -not ( $syncHash.Data.NewCodeTemplateInfo.Keys -contains "Code" ) )
	{
		$syncHash.Data.NewCodeTemplateInfo.Code = $syncHash.Data.msgTable.StrInsertPHCodeHere
	}

	$syncHash.Data.NewCodeTemplateInfo.GetEnumerator() | `
		Where-Object { $_.Name -notmatch "(CodeComment)|(Name)|(ObjectClass)|(DataSource)" } | `
		ForEach-Object `
		-Begin {
			$CodeInfo = "# $( $syncHash.Data.NewCodeTemplateInfo.CodeComment )`n`$PH$( $syncHash.Data.NewCodeTemplateInfo.Name ) = [pscustomobject]@{`n"
		} `
		-Process {
			$P = $_
			switch ( $P.Name )
			{
				"Code" {
					$CodeInfo += "`t$( $P.Name ) = '`n"
					$P.Value -split "`n" | `
						ForEach-Object {
							$CodeInfo += "`t`t$( $_ )`n"
						}
					$CodeInfo += "`t'`n"
				}
				"Title" {
					$TitleVar = "HT$( $syncHash.Data.NewCodeTemplateInfo.Name )"
					$CodeInfo += "`tTitle = `$IntMsgTable.$( $TitleVar )`n"
				}
				"Description" {
					$DescVar = "HDesc$( $syncHash.Data.NewCodeTemplateInfo.Name )"
					$CodeInfo += "`tDescription = `$IntMsgTable.$( $DescVar )`n"
				}
				default
				{
					$CodeInfo += "`t$( $P.Name ) = ""$( $P.Value )""`n"
				}
			}
		}`
		-End {
			$CodeInfo += "}`n"
		}

	$PropHandlerModule = Get-Module -Name "$( $syncHash.Data.NewCodeTemplateInfo.ObjectClass )PropHandlers"
	$VarNames = $PropHandlerModule.ExportedVariables.Keys + "PH$( $syncHash.Data.NewCodeTemplateInfo.Name )" | Where-Object { $_ -notmatch "IntMsgTable" } | Sort-Object
	$ModuleContent = [System.Collections.ArrayList]::new( ( Get-Content $PropHandlerModule.Path ) )
	$NewPHIndex = $VarNames.IndexOf( "PH$( $syncHash.Data.NewCodeTemplateInfo.Name )" )

	if ( $NewPHIndex -lt $VarNames.Count - 1 )
	{
		$InsertIndex = $ModuleContent.IndexOf( ( $ModuleContent.Where( { $_ -eq "`$$( $VarNames[( $NewPHIndex + 1 )] ) = [pscustomobject]@{" } ) ) ) - 1
	}
	else
	{
		$LastPHPos = $ModuleContent.IndexOf( ( $ModuleContent.Where( { $_ -eq "`$$( $VarNames[-2] ) = [pscustomobject]@{" } ) ) )
		$LastPHLength = ( $PropHandlerModule.ExportedVariables."$( $VarNames[-2] )".value.code -split "`n" ).Count + 7
		$InsertIndex = $LastPHPos + $LastPHLength
	}
	$ModuleContent.Insert( $InsertIndex, $CodeInfo )
	$ModuleContent[-1] = $ModuleContent[-1] + ", $( "PH$( $syncHash.Data.NewCodeTemplateInfo.Name )" )"

	$PHLocContent = [System.Collections.ArrayList]::new( ( Get-Content -Path "$( $syncHash.Data.BaseDir )\Localization\$( $syncHash.Data.CultureInfo.CurrentCulture.Name )\$( $syncHash.Data.NewCodeTemplateInfo.ObjectClass )PropHandlers.psd1" ) )
	$PHClassLocalizationText = $PHLocContent[0]

	$PHLocContent.Insert( $PHLocContent.Count - 2, "$( $TitleVar  ) = $( $syncHash.Data.NewCodeTemplateInfo.Title )" )
	$PHLocContent.Insert( $PHLocContent.Count - 2, "$( $DescVar  ) = $( $syncHash.Data.NewCodeTemplateInfo.Description )" )

	$PHClassLocalizationText += "`n$( ( $PHLocContent[ 1 .. ( $PHLocContent.Count - 2 ) ] | Sort-Object ) -join "`r`n" )"
	$PHClassLocalizationText += "`n$( $PHLocContent[-1] )"

	try
	{
		Set-Content -Value $ModuleContent -Path $PropHandlerModule.Path -Encoding UTF8 -ErrorAction Stop
	}
	catch
	{
		Show-MessageBox -Text "$( $syncHash.Data.msgTable.ErrWritingNewPH )`n$( $_ )"
	}

	try
	{
		Set-Content -Value $PHClassLocalizationText -Path ( "$( $syncHash.Data.BaseDir )\Localization\$( $syncHash.Data.CultureInfo.CurrentCulture.Name )\$( $syncHash.Data.NewCodeTemplateInfo.ObjectClass )PropHandlers.psd1" ) -Encoding UTF8 -ErrorAction Stop
	}
	catch
	{
		Show-MessageBox -Text "$( $syncHash.Data.msgTable.ErrWritingNewPH )`n$( $_ )"
	}
}

function New-CodeTemplateTool
{
	New-CodeInfo
	if ( $syncHash.Data.NewCodeTemplateInfo.Separate )
	{
		try
		{
			$File = New-Item -Path "$( $syncHash.Data.BaseDir )\Script\SeparateTools" -Name "$( $syncHash.Data.NewCodeTemplateInfo.Name ).ps1" -ItemType File -Value $syncHash.Data.CodeInfo -ErrorAction Stop
			if ( ( Show-MessageBox -Text "$( $syncHash.Data.msgTable.StrSeparateToolCreated )`n$( $File.FullName )" -Button "YesNo" ) -eq "Yes" )
			{
				Open-File ( ,$File )
			}
		}
		catch
		{
			Show-MessageBox $_ | Out-Null
		}
	}
	else
	{
		$syncHash.Data.CodeInfo += @"

Add-Type -AssemblyName PresentationFramework
`$syncHash = `$args[0]


######################### Script start
`$controls = [System.Collections.ArrayList]::new( @(
) )

"@
		try
		{
			$PsmFile = New-Item -Path "$( $syncHash.Data.BaseDir )\Script\PagedTools" -Name "$( $syncHash.Data.NewCodeTemplateInfo.Name ).psm1" -ItemType File -Value $syncHash.Data.CodeInfo -ErrorAction Stop
			$LocFile = New-Item -Path "$( $syncHash.Data.BaseDir )\Localization\$( $syncHash.Data.CultureInfo.CurrentCulture.Name )\" -Name "$( $syncHash.Data.NewCodeTemplateInfo.Name ).psd1" -ItemType File -Value "ConvertFrom-StringData @'`n`n'@" -ErrorAction Stop
			$GuiFile = New-Item -Path "$( $syncHash.Data.BaseDir )\Gui\" -Name "$( $syncHash.Data.NewCodeTemplateInfo.Name ).xaml" -ItemType File -Value "" -ErrorAction Stop
			$syncHash.Data.p = $PsmFile
			$syncHash.Data.L = $LocFile
			$syncHash.data.g = $GuiFile
			if ( ( Show-MessageBox -Text "$( $syncHash.Data.msgTable.StrSeparateToolCreated )`n$( $File.FullName )" -Button "YesNo" ) -eq "Yes" )
			{
				Open-File @( $PsmFile, $LocFile, $GuiFile )
			}
		}
		catch
		{
			Show-MessageBox $_ | Out-Null
		}
	}
}

function Open-File
{
	<#
	.Synopsis
		Open the specified file/-s
	.Parameter FilePaths
		Array containing any file that is to be opened
	#>

	param (
		[string[]] $FilePaths,
		[int] $StartAtRow
	)

	$FilePaths | `
		ForEach-Object {
			if ( Test-Path $_ )
			{
				$Arguments = @( "`"$_`"" )
				if ( $syncHash.Data.Editor -match "notepad++" -and $StartAtRow )
				{
					$Arguments += "-n$( $StartAtRow )"
				}

				Start-Process -FilePath $syncHash.Data.Editor -ArgumentList $Arguments
			}
		}
}

function Read-Errorlogs
{
	<#
	.Synopsis
		Parse errorlogs
	#>

	try { $syncHash.Jobs.PParseErrorLogs.EndInvoke( $syncHash.Jobs.HParseErrorLogs ) } catch {}
	$syncHash.Jobs.HParseErrorLogs = $syncHash.Jobs.PParseErrorLogs.BeginInvoke()
}

function Read-Logs
{
	<#
	.Synopsis
		Parse logfiles
	#>

	try { $syncHash.Jobs.PParseLogs.EndInvoke( $syncHash.Jobs.HParseLogs ) } catch {}
	$syncHash.Jobs.HParseLogs = $syncHash.Jobs.PParseLogs.BeginInvoke()
}

function Read-Rollbacks
{
	<#
	.Synopsis
		Parse rollbacked files
	#>

	try { $syncHash.Jobs.PParseRollbacks.EndInvoke( $syncHash.Jobs.HParseRollBacks ) } catch {}
	$syncHash.Jobs.HParseRollBacks = $syncHash.Jobs.PParseRollbacks.BeginInvoke()
}

function Remove-DatagridSelection
{
	<#
	.Synopsis
		If a click in a datagrid did not occur on a row, unselect selected row
	.Parameter Click
		UI-Object where the click occured
	.Parameter DataGrid
		What datagrid did the click occur in
	#>

	param ( $Click, $Datagrid )

	if ( $Click.Name -ne "" ) { if ( $Datagrid.SelectedItems.Count -lt 1 ) { $Datagrid.SelectedIndex = -1 } }
}

function Reset-NewTemplateControls
{
	<#
	.Synopsis
		Reset form
	#>

	"Func", "PH", "Tool" | `
		ForEach-Object {
			$Type = $_
			$syncHash.Controls.TiNewTemplate.Resources."Cvs$( $Type )SettingsCollection".Source | `
				ForEach-Object {
					$syncHash.Controls."Grid$( $Type )$( $_.Setting )Setting".Visibility = [System.Windows.Visibility]::Collapsed
					$_.Added = $false
				}
			$syncHash.Controls.TiNewTemplate.Resources."Cvs$( $Type )SettingsCollection".View.Refresh()
		}

	$syncHash.Controls.RbFuncNoteTypeInfo.IsChecked = $true

	"CbFuncPsVerbs", "CbToolPsVerbs", "CbFuncState", "CbPHState", "CbToolState", "CbFuncObjectClass", "CbPHDataSource", "CbPHObjectClass", "CbToolObjectOperations", "CbFuncExistingSubMenus", "CbToolExistingSubMenus", "CbFuncOutputType", "CbFuncSearchedItemRequest" | `
		ForEach-Object {
			$syncHash.Controls."$( $_ )".SelectedIndex = 0
		}

	"TbFuncName", "TbToolName", "TbPHName", "TbFuncAuthor", "TbToolAuthor", "TbPHAuthor", "TbFuncSynopsis", "TbToolSynopsis", "TbPHTitle", "TbFuncDescription", "TbPHDescription", "TbToolDescription", "TbFuncMenuItem", "TbToolMenuItem", "TbFuncAllowedUsers", "TbToolAllowedUsers", "TbFuncRequiredAdGroups", "TbPHRequiredAdGroups", "TbToolRequiredAdGroups", "TbFuncValidStartDateTime", "TbPHValidStartDateTime", "TbToolValidStartDateTime", "TbFuncInvalidateDateTime", "TbPHInvalidateDateTime", "TbToolInvalidateDateTime", "TbPHCodeComment" | `
		ForEach-Object {
			$syncHash.Controls."$( $_ )".Text = ""
		}

	"ChbFuncNoRunspace", "ChbToolSeparate" | `
		ForEach-Object {
			$syncHash.Controls."$( $_ )".IsChecked = $false
		}

	"CvsFuncInputData", "CvsFuncInputDataList", "CvsFuncInputDataBool" | `
		ForEach-Object {
			$syncHash.Controls.TiNewTemplate.Resources."$( $_ )".Source.Clear()
		}

	$syncHash.Data.NewCodeTemplateInfo.Clear()
	Confirm-NewCommandInput
}

function Set-Localizations
{
	<#
	.Synopsis
		Set localized strings
	#>

	# region Update localizations
	$syncHash.Controls.Window.Resources['CvsDgFailedUpdates'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	$syncHash.Controls.Window.Resources['CvsDgUpdatedInProd'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	$syncHash.Controls.Window.Resources['CvsDgUpdates'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()

	# Column headers for DgUpdates
	$syncHash.Controls.DgUpdates.Columns[0].Header = $syncHash.Data.msgTable.ContentDgUpdatesColName
	$syncHash.Controls.DgUpdates.Columns[1].Header = $syncHash.Data.msgTable.ContentDgUpdatesColDevUpd
	$syncHash.Controls.DgUpdates.Columns[2].Header = $syncHash.Data.msgTable.ContentDgUpdatesColNew
	$syncHash.Controls.DgUpdates.Columns[3].Header = $syncHash.Data.msgTable.ContentDgUpdatesColProdState

	# Column headers for DgFailedUpdates
	$syncHash.Controls.DgFailedUpdates.Columns[0].Header = $syncHash.Data.msgTable.ContentDgFailedUpdatesColName
	$syncHash.Controls.DgFailedUpdates.Columns[1].Header = $syncHash.Data.msgTable.ContentDgFailedUpdatesColUpdateAnyway
	$syncHash.Controls.DgFailedUpdates.Columns[2].Header = $syncHash.Data.msgTable.ContentDgFailedUpdatesColWritesToLog
	$syncHash.Controls.DgFailedUpdates.Columns[3].Header = $syncHash.Data.msgTable.ContentDgFailedUpdatesColScriptInfo
	$syncHash.Controls.DgFailedUpdates.Columns[4].Header = $syncHash.Data.msgTable.ContentDgFailedUpdatesColObsoleteFunctions
	$syncHash.Controls.DgFailedUpdates.Columns[5].Header = $syncHash.Data.msgTable.ContentDgFailedUpdatesColInvalidLocalizations
	$syncHash.Controls.DgFailedUpdates.Columns[6].Header = $syncHash.Data.msgTable.ContentDgFailedUpdatesColOrphandLocalizations
	$syncHash.Controls.DgFailedUpdates.Columns[7].Header = $syncHash.Data.msgTable.ContentDgFailedUpdatesColTODOs
	[System.Windows.Data.BindingOperations]::EnableCollectionSynchronization( $syncHash.Controls.Window.Resources['CvsDgUpdates'].View, $syncHash.Controls.DgUpdates )

	$syncHash.Controls.DgUpdates.Resources['StrNoScriptfile'] = $syncHash.Data.msgTable.StrNoScriptfile
	$syncHash.Controls.DgUpdates.Resources['StrUpdatedFileIsNew'] = $syncHash.Data.msgTable.StrUpdatedFileIsNew
	$syncHash.Controls.DgUpdates.Resources['StrUpdatedFileIsUpdated'] = $syncHash.Data.msgTable.StrUpdatedFileIsUpdated

	# Button to open file that failed to update
	$syncHash.Controls.DgFailedUpdates.Resources['BtnOpenFailedContent'] = $syncHash.Data.msgTable.ContentBtnOpenFailed

	# Eventhandler to open file that failed to update
	$syncHash.Controls.Window.Resources['BtnOpenFailedUpdatedFile'].Setters[0].Handler = $syncHash.Code.OpenFailedUpdatedFile
	# endregion Update localizations

	# region Log localizations
	$syncHash.Controls.Window.Resources['CvsDgLogs'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	$syncHash.Controls.Window.Resources['CvsCbLogsScriptNames'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()

	[System.Windows.Data.BindingOperations]::EnableCollectionSynchronization( $syncHash.Controls.Window.Resources['CvsCbLogsScriptNames'].View, $syncHash.Controls.CbLogsScriptNames )

	# Column headers for DgLogs
	$syncHash.Controls.DgLogs.Columns[0].Header = $syncHash.Data.msgTable.ContentDgLogsColLogDate
	$syncHash.Controls.DgLogs.Columns[1].Header = $syncHash.Data.msgTable.ContentDgLogsColSuccess
	$syncHash.Controls.DgLogs.Columns[2].Header = $syncHash.Data.msgTable.ContentDgLogsColOperator
	# endregion Log localizations

	# region Errorlog localization
	$syncHash.Controls.Window.Resources['CvsErrorLogsScriptNames'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	$syncHash.Controls.Window.Resources['CvsDgErrorLogs'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()

	# Column headers for DgErrorLogs
	$syncHash.Controls.DgErrorLogs.Columns[0].Header = $syncHash.Data.msgTable.ContentDgErrorLogsColLogDate

	# Column headers for DgRollbacks
	$syncHash.Controls.DgRollbacks.Columns[0].Header = $syncHash.Data.msgTable.ContentDgRollbacksColFileName
	$syncHash.Controls.DgRollbacks.Columns[1].Header = $syncHash.Data.msgTable.ContentDgRollbacksColUpdated
	$syncHash.Controls.DgRollbacks.Columns[2].Header = $syncHash.Data.msgTable.ContentDgRollbacksColUpdatedBy
	$syncHash.Controls.DgRollbacks.Columns[3].Header = $syncHash.Data.msgTable.ContentDgRollbacksColType

	# endregion Errorlog localization

	# region Rollback localizations
	$syncHash.Controls.Window.Resources['CvsLvRollbackFileNames'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	# endregion Rollback localizations

	# region Kd summary localizations
	$syncHash.Controls.TiKbSummary.Resources['CvsKdSummary'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	# endregion Kd summary localizations

	# DatagridTextColumn headers for datagrids in dgFailedUpdates-cells
	$syncHash.Controls.DgFailedUpdates.Resources['DgOFColHeaderFunctionName'] = $syncHash.Data.msgTable.ContentDgObsoleteFunctionsColFunctionName
	$syncHash.Controls.DgFailedUpdates.Resources['DgOFColHeaderHelpMessage'] = $syncHash.Data.msgTable.ContentDgObsoleteFunctionsColHelpMessage
	$syncHash.Controls.DgFailedUpdates.Resources['DgOFColHeaderLineNumbers'] = $syncHash.Data.msgTable.ContentDgObsoleteFunctionsColLineNumbers

	$syncHash.Controls.DgFailedUpdates.Resources['DgIVColHeaderTextLN'] = $syncHash.Data.msgTable.ContentDgInvalidLocalizationsColLineNumber
	$syncHash.Controls.DgFailedUpdates.Resources['DgIVColHeaderTextSV'] = $syncHash.Data.msgTable.ContentDgInvalidLocalizationsColScriptVar
	$syncHash.Controls.DgFailedUpdates.Resources['DgIVColHeaderTextSL'] = $syncHash.Data.msgTable.ContentDgInvalidLocalizationsColScriptLine

	$syncHash.Controls.DgFailedUpdates.Resources['DgOLColHeaderTextLVar'] = $syncHash.Data.msgTable.ContentDgOrphandLocalizationsColVariable
	$syncHash.Controls.DgFailedUpdates.Resources['DgOLColHeaderTextLVal'] = $syncHash.Data.msgTable.ContentDgOrphandLocalizationsColValue

	$syncHash.Controls.DgFailedUpdates.Resources['DgSIColHeaderTitle'] = $syncHash.Data.msgTable.ContentDgSIColHeaderTitle
	$syncHash.Controls.DgFailedUpdates.Resources['DgSIColHeaderInfoDesc'] = $syncHash.Data.msgTable.ContentDgSIColHeaderInfoDesc

	$syncHash.Controls.DgFailedUpdates.Resources['DgTDColHeaderTextL'] = $syncHash.Data.msgTable.ContentDgTDColHeaderTextL
	$syncHash.Controls.DgFailedUpdates.Resources['DgTDColHeaderTextLN'] = $syncHash.Data.msgTable.ContentDgTDColHeaderTextLN

	$syncHash.Controls.DgFailedUpdates.Resources['NotAllowedToUpdate'] = $syncHash.Data.msgTable.StrNotAllowedAnyway

	$syncHash.Controls.DgUpdatedInProd.Columns[0].Header = $syncHash.Data.msgTable.ContentDgUpdatesColName
	$syncHash.Controls.DgUpdatedInProd.Columns[1].Header = $syncHash.Data.msgTable.ContentDgUpdatesColDevUpd
	$syncHash.Controls.DgUpdatedInProd.Columns[2].Header = $syncHash.Data.msgTable.ContentDgUpdatesColProdUpd

	$syncHash.Controls.DgDiffList.Columns[0].Header = $syncHash.Data.msgTable.ContentDgDiffListColDevRow
	$syncHash.Controls.DgDiffList.Columns[1].Header = $syncHash.Data.msgTable.ContentDgDiffListColLineNr
	$syncHash.Controls.DgDiffList.Columns[2].Header = $syncHash.Data.msgTable.ContentDgDiffListColProdRow

	$syncHash.Controls.DiffWindow.Resources['DiffRowRemoved'] = $syncHash.Data.msgTable.StrDiffRowRemoved # Text for row that was removed
	$syncHash.Controls.DiffWindow.Resources['DiffRowAdded'] = $syncHash.Data.msgTable.StrDiffRowAdded # Text for row that have been added
	$syncHash.Controls.Window.Resources['FailedTestCount'] = "$( $syncHash.Data.msgTable.StrFailedTestCount ): " # Text for number of failed tests
	$syncHash.Controls.Window.Resources['NewFileTitle'] = $syncHash.Data.msgTable.StrNewFileTitle # Text for indicating the file is new and not present in production
	$syncHash.Controls.Window.Resources['LogSearchNoType'] = $syncHash.Data.msgTable.StrLogSearchNoType # Text for indicating the file is new and not present in production

	# region Controls for new function/tool
	$syncHash.Controls.IcFuncInputData.Resources.StrIcInputDataNameTitle = $syncHash.Data.msgTable.StrIcInputDataNameTitle
	$syncHash.Controls.IcFuncInputData.Resources.StrIcInputDataMandatoryTitle = $syncHash.Data.msgTable.StrIcInputDataMandatoryTitle
	$syncHash.Controls.IcFuncInputData.Resources.StrIcInputDataDescriptionTitle = $syncHash.Data.msgTable.StrIcInputDataDescriptionTitle
	$syncHash.Controls.TiCodeTypeFunction.Tag = $syncHash.Data.msgTable.ContentGridFuncInfoTt

	"CvsFuncInputData", "CvsFuncInputDataList", "CvsFuncInputDataBool", "CvsFuncOutputType", "CvsFuncSearchedItemRequest", "CvsFuncState", "CvsPHState", "CvsToolState", "CvsFuncObjectClass", "CvsToolObjectOperations", "CvsPHObjectClass", "CvsFuncPsVerbs", "CvsToolPsVerbs", "CvsFuncSubMenus", "CvsToolSubMenus", "CvsFuncSettingsCollection", "CvsPHSettingsCollection", "CvsToolSettingsCollection", "CvsPHDataSource" | `
		ForEach-Object {
			$syncHash.Controls.TiNewTemplate.Resources."$( $_ )".Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()

			if ( $_ -match "^CvsFuncInput")
			{
				$syncHash.Controls.TiNewTemplate.Resources."$( $_ )".Source.Add_CollectionChanged( {
					Confirm-NewCommandInput
				} )
			}
		}

	"String", "ObjectList", "List", "None" | `
		ForEach-Object {
			$syncHash.Controls.TiNewTemplate.Resources.CvsFuncOutputType.Source.Add( $_ )
		}

	$syncHash.Data.msgTable.StrSelectPropHandlerDataSource, "AD", "Other", "Exchange", "SysMan", "FileSystem" | `
		ForEach-Object {
			$syncHash.Controls.TiNewTemplate.Resources.CvsPHDataSource.Source.Add( $_ )
		}

	"Allowed", "None", "Required" | `
		ForEach-Object {
			$syncHash.Controls.TiNewTemplate.Resources.CvsFuncSearchedItemRequest.Source.Add( $_ )
		}

	$syncHash.Data.msgTable.StrSelectState, "Dev", "Test", "Prod" | `
		ForEach-Object {
			$syncHash.Controls.TiNewTemplate.Resources.CvsFuncState.Source.Add( $_ )
			$syncHash.Controls.TiNewTemplate.Resources.CvsPHState.Source.Add( $_ )
			$syncHash.Controls.TiNewTemplate.Resources.CvsToolState.Source.Add( $_ )
		}

	( Get-Verb ).Verb | `
		ForEach-Object `
		-Begin {
			$SO = 0
			$Verb = [pscustomobject]@{
				Verb = $syncHash.Data.msgTable.CvsPsVerbs
				SortOrder = $SO
			}
			$syncHash.Controls.TiNewTemplate.Resources.CvsFuncPsVerbs.Source.Add( $Verb )
			$syncHash.Controls.TiNewTemplate.Resources.CvsToolPsVerbs.Source.Add( ( $Verb.psobject.Copy() ) )
		} `
		-Process {
			$SO = $SO + 1
			$Verb = [pscustomobject]@{
				Verb = $_
				SortOrder = $SO
			}
			$syncHash.Controls.TiNewTemplate.Resources.CvsFuncPsVerbs.Source.Add( $Verb )
			$syncHash.Controls.TiNewTemplate.Resources.CvsToolPsVerbs.Source.Add( ( $Verb.psobject.Copy() ) )
		}

	"AllowedUsers", "RequiredAdGroups", "SubMenu", "ValidStartDateTime", "InvalidateDateTime", "NoRunspace", "Note", "SearchedItemRequest", "InputData", "InputDataBool", "InputDataList", "Author" | `
		ForEach-Object {
			$syncHash.Controls.TiNewTemplate.Resources.CvsFuncSettingsCollection.Source.Add( ( [pscustomobject]@{ Setting = $_ ; Added = $false ; Tt = $syncHash.Data.msgTable."ContentTtGridFunc$( $_ )Info" } ) )
		}

	"AllowedUsers", "RequiredAdGroups", "ValidStartDateTime", "InvalidateDateTime", "Author", "State" | `
		ForEach-Object {
			$syncHash.Controls.TiNewTemplate.Resources.CvsPHSettingsCollection.Source.Add( ( [pscustomobject]@{ Setting = $_ ; Added = $false ; Tt = $syncHash.Data.msgTable."ContentTtGridPH$( $_ )Info" } ) )
		}

	"AllowedUsers", "Author", "RequiredAdGroups", "Separate", "SubMenu", "ValidStartDateTime", "InvalidateDateTime", "ObjectOperations" | `
		ForEach-Object {
			$syncHash.Controls.TiNewTemplate.Resources.CvsToolSettingsCollection.Source.Add( ( [pscustomobject]@{ Setting = $_ ; Added = $false ; Tt = $syncHash.Data.msgTable."ContentTtGridTool$( $_ )Info" } ) )
		}

	$syncHash.Data.msgTable.CvsToolObjectOperationsList -split ";" | `
		Where-Object { $_ } | `
		ForEach-Object {
			$l,$oo = $_ -split ","
			$SortOrder = if ( $l -eq "null" )
			{
				0
			}
			else
			{
				1
			}
			$syncHash.Controls.TiNewTemplate.Resources.CvsToolObjectOperations.Source.Add( ( [pscustomobject]@{ LocalizedName = $l ; ObjectOperation = $oo ; SortOrder = $SortOrder } ) )
		}

	$syncHash.Data.msgTable.CvsPropHandlerObjectClassList -split ";" | `
		Where-Object { $_ } | `
		ForEach-Object {
			$l,$oo = $_ -split ","
			$SortOrder = if ( $l -eq "null" )
			{
				0
			}
			else
			{
				1
			}
			$syncHash.Controls.TiNewTemplate.Resources.CvsPHObjectClass.Source.Add( ( [pscustomobject]@{ LocalizedName = $l ; ObjectOperation = $oo ; SortOrder = $SortOrder } ) )
		}

	$syncHash.Data.msgTable.CvsFuncObjectClassList -split ";" | `
		Where-Object { $_ } | `
		ForEach-Object {
			$l,$oo = $_ -split ","
			$SortOrder = if ( $l -eq "null" )
			{
				0
			}
			else
			{
				1
			}
			$syncHash.Controls.TiNewTemplate.Resources.CvsFuncObjectClass.Source.Add( ( [pscustomobject]@{ LocalizedName = $l ; ObjectOperation = $oo ; SortOrder = $SortOrder } ) )
		}

	$syncHash.Controls.TiNewTemplate.Resources.GetEnumerator() | `
		Where-Object { $_.Name -match "^Cvs" } | `
		ForEach-Object { $_.Value.View.Refresh() }

	$syncHash.Controls.TiNewTemplate.Resources.BtnRemoveInputDataVar.Setters[0].Handler = $syncHash.Code.RemoveInputDataVar
	$syncHash.Controls.TiNewTemplate.Resources.BtnRemoveInputDataListVar.Setters[0].Handler = $syncHash.Code.RemoveInputDataListVar
	$syncHash.Controls.TiNewTemplate.Resources.BtnRemoveInputDataBoolVar.Setters[0].Handler = $syncHash.Code.RemoveInputDataBoolVar
	$syncHash.Controls.TiNewTemplate.Resources.TbInputDataNameBase.Setters[0].Handler = $syncHash.Code.ValidateInputDataName
	$syncHash.Controls.TiNewTemplate.Resources.TbInputDataNameBase.Setters[1].Handler = $syncHash.Code.InputTextBoxLoaded
	$syncHash.Controls.TiNewTemplate.Resources.TbInputDataBaseDesc.Setters[0].Handler = $syncHash.Code.VerifyDescriptionEntered
	$syncHash.Controls.TiNewTemplate.Resources.TbDefaultListValue.Setters[0].Handler = $syncHash.Code.VerifyDefaultListValueExists
	$syncHash.Controls.TiNewTemplate.Resources.TbOptionsList.Setters[0].Handler = $syncHash.Code.VerifyOptionListDefaultValueExists
	( $syncHash.Controls.CmFuncAddSetting.Resources.GetEnumerator() | Select-Object -First 1 ).Value.Setters[0].Handler = $syncHash.Code.CmFuncSettingClick
	( $syncHash.Controls.CmPHAddSetting.Resources.GetEnumerator() | Select-Object -First 1 ).Value.Setters[0].Handler = $syncHash.Code.CmPHSettingClick
	( $syncHash.Controls.CmToolAddSetting.Resources.GetEnumerator() | Select-Object -First 1 ).Value.Setters[0].Handler = $syncHash.Code.CmToolSettingClick

	# endregion

}

function Show-DiffWindow
{
	<#
	.Synopsis
		Open window to display difference between files
	#>

	if ( $syncHash.Controls.TbUpdated.SelectedIndex -eq 0 ) { $LvItem = $syncHash.Controls.DgUpdates.SelectedItem }
	else { $LvItem = $syncHash.Controls.DgUpdatedInProd.SelectedItem }
	$a = Get-Content $LvItem.DevFile.FullName
	$b = Get-Content $LvItem.ProdFile.FullName
	$c = Compare-Object $a $b -PassThru

	$syncHash.DiffList = foreach ( $DiffLine in ( $c.ReadCount | Select-Object -Unique | Sort-Object ) )
	{
		$DevLine = try { ( $c.Where( { $_.ReadCount -eq $DiffLine -and $_.SideIndicator -eq "<=" } ) )[0].Trim() } catch { "" }
		$ProdLine = try { ( $c.Where( { $_.ReadCount -eq $DiffLine -and $_.SideIndicator -eq "=>" } ) )[0].Trim() } catch { "" }

		[pscustomobject]@{ DevLine = $DevLine; ProdLine = $ProdLine; LineNr = $DiffLine }
	}

	$syncHash.Controls.DgDiffList.ItemsSource = $syncHash.DiffList
	$syncHash.Controls.DiffWindow.Visibility = [System.Windows.Visibility]::Visible
	#WriteLog -Text $syncHash.Data.msgTable.LogOpenDiffWindow -UserInput ( [string]( $LvItem.DevPath, $LvItem.ProdPath ) ) -Success $true
}

function Test-Localizations
{
	<#
	.Synopsis
		Find localizations that are not used
	.Description
		Check if there are any localizationvariables in the localizationfile that are not used in the script and if there are any calls for localizationvariables in the script that does not exist
	.Parameter FileName
		Name of scriptfile. This is also used as template for the datafile
	.Outputs
		Array with any localizationvariables that are not used, and variables that is not mentioned in the localizationfile
	#>

	param ( $File )

	$OrphandLocs = [System.Collections.ArrayList]::new()
	$InvalidLocs = [System.Collections.ArrayList]::new()

	# Localization strings for current file
	Import-LocalizedData -BindingVariable LocalizationData -UICulture $syncHash.Data.CultureInfo.CurrentCulture.Name -BaseDirectory "$( $syncHash.Data.DevRoot )\Localization\" -FileName $File.DevFile.BaseName

	if ( $File.DevFile.Extension -match "(psm*1)|(xaml)" )
	{
		if ( $File.DevFile.BaseName -match "PropHandlers" )
		{
			# Localization strings for suite main script
			Import-LocalizedData -BindingVariable MainScriptLocalizationData -UICulture $syncHash.Data.CultureInfo.CurrentCulture.Name -BaseDirectory "$( $syncHash.Data.DevRoot )\Localization\" -FileName $syncHash.Data.SuiteBaseName

			[regex]::Matches( ( Get-Content $File.DevFile.FullName ), "(?m)\s*\[pscustomobject\].*?Code = '(?<Code>.*?)'\s*?Title" ) | `
				ForEach-Object {
					[regex]::Matches( $_.Groups['Code'].Value, "\.[Mm]sgTable\.(?<Key>\w+(?<!Keys))\b" ) | `
						ForEach-Object {
							if ( $MainScriptLocalizationData.Keys -notcontains $_.Groups['Key'].Value )
							{
								$InvalidLocs.Add( $_.Groups['Key'].Value ) | Out-Null
							}
						}
				}

			Get-Item -Path $File.DevFile.FullName | `
				Select-String -Pattern "Int[Mm]sgTable\.(\w+(?<!Keys))\b" -AllMatches | `
					ForEach-Object {
						if ( $_.Line -match "Int[Mm]sgTable\.(?<Key>\w+(?<!Keys))\b" )
						{
							if ( $LocalizationData.Keys -notcontains $Matches.Key )
							{
								$InvalidLocs.Add( ( [pscustomobject]@{ Key = $Matches.Key ; LineNumber = $_.LineNumber ; Line = $_.Line.Trim() } ) ) | Out-Null
							}
						}
					}
		}
		else
		{
			Get-Item $File.DevFile.FullName | `
				Select-String "[Mm]sgTable\.\w+(?<!Keys)\b" | `
				ForEach-Object {
					$LineMatch = $_
					[regex]::Matches( $_.Line , "[Mm]sgTable\.(?<LocVar>(?!GetEnumerator)\w+)\b" ) | `
					ForEach-Object {
						if ( $LocalizationData.Keys -notcontains $_.Groups['LocVar'].Value )
						{
							$InvalidLocs.Add( [pscustomobject]@{ ScVar = $_.Groups['LocVar'].Value ; ScLine = $LineMatch.Line ; ScLineNr = $LineMatch.linenumber } ) | Out-Null
						}
					}
				}
		}
	}
	elseif ( $File.DevFile.Extension -eq ".psd1" )
	{
		$ScriptFile = Get-ChildItem -Path $syncHash.Data.BaseDir -Exclude "Rollback", "Logs", "ErrorLogs", "Output", "Tests" | ForEach-Object { Get-ChildItem -Path $_.FullName -Filter "$( $File.DevFile.BaseName )*" -Recurse | Where-Object { $_.Extension -match "psm*1" } }
		$XamlFile = Get-ChildItem -Path $syncHash.Data.BaseDir -Exclude "Rollback", "Logs", "ErrorLogs", "Output", "Tests" | ForEach-Object { Get-ChildItem -Path $_.FullName -Filter "$( $File.DevFile.BaseName ).xaml" -Recurse }

		if ( $syncHash.Data.SuiteBaseName -eq $File.DevFile.BaseName )
		{
			# Check keys in prophandlers against keys in Fetchalon loc
			$LocsInPropHandlers = @{}
			Get-Module -Name *PropHandlers | `
				ForEach-Object {
					$Module = $_
					$_.ExportedVariables.GetEnumerator() | `
						ForEach-Object {
							[regex]::Matches( $_.Value.Value.Code , "\.msgTable\.(?<Var>\w+?)\b" ) | `
								ForEach-Object {
									try { $LocsInPropHandlers.Add( $_.Groups['Var'].Value, "" ) | Out-Null }
									catch {}
								}
						}
				}
		}

		# Check that if any key in localization-file is not present in the scriptfile or Xaml-file
		foreach ( $Key in $LocalizationData.Keys )
		{
			try { Remove-Variable UsedInScript, UsedInXaml, UsedInPropHandler -ErrorAction SilentlyContinue } catch {}
			$UsedInScript = $false
			$UsedInXaml = $false
			$UsedInPropHandler = $false

			try
			{
				if ( $null -ne ( $ScriptFile | Select-String "\.$Key\b" ) )
				{
					$UsedInScript = $true
				}
			} catch {}

			try
			{
				if ( $null -ne ( $XamlFile | Select-String "\.$Key\b" ) )
				{
					$UsedInXaml = $true
				}
			} catch {}

			if ( $LocsInPropHandlers )
			{
				$UsedInPropHandler = $Key -in $LocsInPropHandlers.Keys
			}

			if (
				( -not $UsedInScript ) -and `
				( -not $UsedInXaml ) -and `
				( -not $UsedInPropHandler )
			)
			{
				$OrphandLocs.Add( ( [pscustomobject]@{ LocVar = $Key ; LocVal = $LocalizationData.$Key } ) ) | Out-Null
			}
		}
	}

	return $OrphandLocs, $InvalidLocs
}

function Test-Script
{
	<#
	.Synopsis
		Test if script is viable to update
	.Parameter File
		Scriptfile to test before sending to production
	.Outputs
		Object of testresults
	#>

	param ( $File )

	$Script = Get-Item -LiteralPath $File.DevFile.FullName
	$OFS = ", "

	$Test = [pscustomobject]@{
		File = $File
		IsFunctionsModule = $File.DevFile.FullName -match "$( $syncHash.Data.DevRoot -replace "\\", "\\" )\\Modules"
		FailedTestCount = 0
		ObsoleteFunctions = [System.Collections.ArrayList]::new()
		WritesToLog = $false
		OrphandLocalizations = @()
		InvalidLocalizations = @()
		MissingScriptInfo = [System.Collections.ArrayList]::new()
		TODOs = [System.Collections.ArrayList]::new()
		AllowUpdateAnyway = $true
		UpdateAnyway = $false
	}
	$RequiredScriptInfo = "Author", "MenuItem", "Synopsis", "Description", "State"
	$ScriptInfoMembers = $File.ScriptInfo | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name

	# Test if obsolete functions are used
	foreach ( $f in $syncHash.ObsoleteFunctions )
	{
		[array]$linenumbers = ( $Script | Select-String -Pattern "\b$( $f.FunctionName )\b" ).LineNumber
		if ( $linenumbers -gt 0 )
		{
			$Test.ObsoleteFunctions.Add( [pscustomobject]@{ "FunctionName" = $f.FunctionName ; "HelpMessage" = $f.HelpMessage ; "LineNumbers" = [string]$linenumbers } ) | Out-Null
		}
	}

	# Test if the script writes to log
	if ( $Test.IsFunctionsModule -or ( $File.DevFile.Extension -notmatch "psm*1" ) )
	{
		$Test.WritesToLog = $true
	}
	else
	{
		$Test.WritesToLog = ( $Script | Select-String -Pattern "(?=\s*)(?<!.*#.*)WriteLog(?=.*)" ).Count -gt 0
	}

	# Test if there are any localizationvariables that are not used or are being used but does not exist
	if ( $null -ne ( Get-ChildItem -Path $syncHash.Data.BaseDir -Filter "$( $File.DevFile.BaseName )*.psd1" -Recurse ) )
	{
		$Test.OrphandLocalizations, $Test.InvalidLocalizations = Test-Localizations $File
	}

	# Test if script contains necessary script information
	$RequiredScriptInfo | `
		ForEach-Object {
			if ( $ScriptInfoMembers -notcontains $_ )
			{
				$Test.MissingScriptInfo.Add( ( [pscustomobject]@{ SIName = $_ ; InfoDesc = $syncHash.Data.msgTable."StrScriptInfoDesc$_" } ) ) | Out-Null
			}
		}

	# Test if file contains any TODO notes
	if ( $Script.Name -ne ( Get-Item $PSCommandPath ).Name )
	{
		$Script | Select-String -Pattern "\s*#\s*\bTODO\b" | ForEach-Object { $Test.TODOs.Add( [pscustomobject]@{ Line = $_.Line.Trim() ; LineNumber = $_.LineNumber } ) | Out-Null }
	}

	$Test.FailedTestCount = $Test.ObsoleteFunctions.Count + $Test.OrphandLocalizations.Count + $Test.InvalidLocalizations.Count + $Test.MissingScriptInfo.Count + $Test.TODOs.Count
	if ( -not $Test.WritesToLog )
	{
		$Test.FailedTestCount = $Test.FailedTestCount + 1
	}

	if ( $null -eq $File.ScriptInfo )
	{
		$Test.FailedTestCount = $Test.FailedTestCount + 1
	}

	# Check if mandatory info passed tests
	if ( ( $Test.ObsoleteFunctions.Count -ne 0 ) -or `
		( $null -eq $File.ScriptInfo ) -or `
		$Test.InvalidLocalizations.Count -gt 0 -or `
		$Test.MissingScriptInfo.Count -gt 0
	)
	{
		$Test.AllowUpdateAnyway = $false
	}

	return $Test
}

function Unregister-OtherRollbackFilters
{
	param (
		[string] $Checked
	)

	$syncHash.GetEnumerator() | Where-Object { $_.Key -match "CbRollbackFilterType" -and $_.Key -notmatch ".*$Checked" } | ForEach-Object { $_.Value.IsChecked = $false }
}

function Update-Files
{
	<#
	.Synopsis
		Update the scripts that have been selected
	#>

	$syncHash.Updated = @()
	$FilesToUpdate = @()
	# Tab for updates have focus
	if ( $syncHash.Controls.TbUpdated.SelectedIndex -eq 0 )
	{
		foreach ( $file in $syncHash.Controls.DgUpdates.SelectedItems )
		{
			if ( $file.DevFile.Extension -match "^\.(psm*d*1)|(xaml)$" )
			{
				$FileTest = Test-Script $file
				if ( $FileTest.FailedTestCount -eq 0 )
				{
					$FilesToUpdate += $file
				}
				else
				{
					$syncHash.Controls.Window.Resources['CvsDgFailedUpdates'].Source.Add( $FileTest )
				}
			}
			else
			{
				$FilesToUpdate += $file
			}
		}
	}
	# Tab for failed updates have focus
	elseif ( $syncHash.Controls.TbUpdated.SelectedIndex -eq 1 )
	{
		$FilesToUpdate = @( $syncHash.Controls.DgFailedUpdates.Items | Where-Object { $_.UpdateAnyway -and $_.AllowUpdateAnyway } | Select-Object -ExpandProperty File )
	}

	foreach ( $File in $FilesToUpdate )
	{
		$OFS = "`n"
		if ( $File.New )
		{
			New-Item -ItemType File -Path "$( $File.DevFile.FullName -replace "Development\\" )" -Force
			Copy-Item -Path $File.DevFile.FullName -Destination "$( $File.DevFile.FullName -replace "Development\\" )" -Force
		}
		else
		{
			$RollbackPath = "$( $syncHash.Data.RollbackRoot )\$( ( Get-Date ).Year )\$( ( Get-Date ).Month )\"
			$RollbackName = "$( $File.ProdFile.Name ) ($( $syncHash.Data.msgTable.StrRollbackName ) $( Get-Date $File.ProdFile.LastWriteTime -Format $syncHash.Data.CultureInfo.DateTimeFileStringFormat ), $( ( [Environment]::UserName ) ))$( $File.ProdFile.Extension )" -replace ":","."
			$RollbackValue = [string]( Get-Content -Path $File.ProdFile.FullName -Encoding UTF8 )
			$OutputEncoding = ( New-Object System.Text.UnicodeEncoding $False, $False ).psobject.BaseObject
			New-Item -Path $RollbackPath -Name $RollbackName -ItemType File -Value $RollbackValue -Force | Out-Null
			Copy-Item -Path $File.DevFile.FullName -Destination $File.ProdFile.FullName -Force
		}

		if ( $syncHash.Controls.ChbPublishFiles.IsChecked )
		{
			$OutputEncoding = ( New-Object System.Text.UnicodeEncoding $False, $False ).psobject.BaseObject
			$DevFilePublishedFullName = Get-ChildItem -File -Path $syncHash.Data.PublishedDev -Recurse | `
				Where-Object { $_.Name -eq $File.DevFile.Name } | `
				Select-Object -ExpandProperty FullName
			if ( $null -eq $DevFilePublishedFullName )
			{
				$DevFilePublishedFullName = $File.DevFile.FullName.Replace( $syncHash.Data.DevRoot , $syncHash.Data.PublishedDev )
			}
			Copy-Item -Path $File.DevFile.FullName -Destination $DevFilePublishedFullName -Force

			$ProdFilePublishedFullName = Get-ChildItem -Directory -Path $syncHash.Data.PublishedProd -Exclude "Development", "ErrorLogs", "Logs", "Output", "Tests" | `
				ForEach-Object {
					Get-ChildItem -File -Path $_.FullName -Recurse | `
					Where-Object { $_.Name -eq $File.DevFile.Name } | `
					Select-Object -ExpandProperty FullName
				}
			if ( $null -eq $ProdFilePublishedFullName )
			{
				$ProdFilePublishedFullName = $File.DevFile.FullName.Replace( $syncHash.Data.DevRoot , $syncHash.Data.PublishedProd )
			}
			Copy-Item -Path $File.DevFile.FullName -Destination $ProdFilePublishedFullName -Force
		}
		$syncHash.Updated += $File
	}

	$OFS = "`n`t"
	$LogText = "$( $syncHash.Data.msgTable.LogUpdatedIntro ) $( $syncHash.Updated.Count )`n$( [string]( $syncHash.Updated ) )"
	if ( $syncHash.Controls.Window.Resources['CvsDgFailedUpdates'].Source.Count -gt 0 )
	{
		$LogText += "`n$( $syncHash.Controls.Window.Resources['CvsDgFailedUpdates'].Source.Count ) $( $syncHash.Data.msgTable.LogFailedUpdates ):`n"
		$LogText += $syncHash.Controls.Window.Resources['CvsDgFailedUpdates'].Source | ForEach-Object { "$( $syncHash.Data.msgTable.LogFailedUpdatesName ) $( $_ )`n$( $syncHash.Data.msgTable.LogFailedUpdatesTestResults )" }
	}

	if ( $syncHash.Controls.Window.Resources['CvsDgUpdatedInProd'].Source.Count -gt 0 )
	{
		$LogText += "`n$( $syncHash.Data.msgTable.StrUpdatesInProd ): "
		$LogText += [string]( $syncHash.Controls.Window.Resources['CvsDgUpdatedInProd'] | ForEach-Object { $_.Name } )
	}

	WriteLog -Text $LogText -UserInput [string]$syncHash.Updated.DevFile.Name -Success ( $null -eq $eh ) -ErrorLogHash $eh | Out-Null

	if ( $syncHash.Controls.TbUpdated.SelectedIndex -eq 0 )
	{
		$temp = $syncHash.Controls.Window.Resources['CvsDgUpdates'].Source | Where-Object { $_ -notin $syncHash.Controls.DgUpdates.SelectedItems }
		$syncHash.Controls.Window.Resources['CvsDgUpdates'].Source.Clear()
		$temp | ForEach-Object { $syncHash.Controls.Window.Resources['CvsDgUpdates'].Source.Add( $_ ) }
	}
	elseif ( $syncHash.Controls.TbUpdated.SelectedIndex -eq 1 )
	{
		foreach ( $File in $FilesToUpdate )
		{
			$UpdatedFile = $syncHash.Controls.Window.Resources['CvsDgFailedUpdates'].Source.Where( { $_.File.DevFile.FullName -eq $File.DevFile.FullName } )[0]
			$syncHash.Controls.Window.Resources['CvsDgFailedUpdates'].Source.Remove( $UpdatedFile )
		}
		$syncHash.Controls.Window.Resources['CvsDgFailedUpdates'].View.Refresh()

		if ( $syncHash.Controls.Window.Resources['CvsDgFailedUpdates'].Source.Count -eq 0 )
		{
			$syncHash.Controls.TbUpdated.SelectedIndex = 0
		}
	}
	$syncHash.Controls.ChbPublishFiles.IsChecked = $true
	$syncHash.DC.TblInfo[0] = [System.Windows.Visibility]::Collapsed
}

######################### Script start
$controls = [System.Collections.ArrayList]::new( @(
@{ CName = "BtnDiffCancel" ; Props = @( @{ PropName = "Content" ; PropVal = $syncHash.Data.msgTable.ContentBtnDiffCancel } ) },
@{ CName = "BtnDoRollback" ; Props = @( @{ PropName = "IsEnabled" ; PropVal = $false } ) },
@{ CName = "BtnOpenRollbackFile" ; Props = @( @{ PropName = "IsEnabled" ; PropVal = $false } ) },
@{ CName = "ChbPublishFiles" ; Props = @( @{ PropName = "IsChecked"; PropVal = $true } ) },
@{ CName = "PbLogSearch" ; Props = @( @{ PropName = "Value"; PropVal = [double] 0 } ) },
@{ CName = "PbParseErrorLogs" ; Props = @( @{ PropName = "Value"; PropVal = [double] 0 } ) },
@{ CName = "PbParseErrorLogsOps" ; Props = @( @{ PropName = "Value"; PropVal = [double] 0 } ; @{ PropName = "Maximum" ; PropVal = [double] 3 } ) },
@{ CName = "PbParseUpdates" ; Props = @( @{ PropName = "Value"; PropVal = [double] 0 } ; @{ PropName = "Maximum" ; PropVal = [double] 0 } ) },
@{ CName = "TbDevCount" ; Props = @( @{ PropName = "Text"; PropVal = "-" } ) },
@{ CName = "TblInfo" ; Props = @( @{ PropName = "Visibility" ; PropVal = [System.Windows.Visibility]::Collapsed } ) },
@{ CName = "TblUpdateInfo" ; Props = @( @{ PropName = "Text"; PropVal = "" } ) },
@{ CName = "TblUpdatesProgress" ; Props = @( @{ PropName = "Text"; PropVal = "" } ) },
@{ CName = "TbProdCount" ; Props = @( @{ PropName = "Text"; PropVal = "-" } ) },
@{ CName = "TbTestCount" ; Props = @( @{ PropName = "Text"; PropVal = "-" } ) }
) )

BindControls $syncHash $controls

$syncHash.Data.BaseDir = ( Get-Item $MyInvocation.PsScriptRoot ).Parent.FullName
if ( $syncHash.Data.BaseDir -match "Development" )
{
	$syncHash.Data.DevRoot = $syncHash.Data.BaseDir
	$syncHash.Data.ProdRoot = ( Get-Item $syncHash.Data.BaseDir ).Parent.FullName
}
else
{
	$syncHash.Data.DevRoot = "$( $syncHash.Data.BaseDir )\Development"
	$syncHash.Data.ProdRoot = $syncHash.Data.BaseDir
}

if ( $syncHash.Data.BaseDir -match "User" )
{
	$syncHash.Data.PublishedProd = "G:\Fetchalon"
	$syncHash.Data.PublishedDev = "G:\Fetchalon\Development"
}
else
{
	$syncHash.Controls.SpUpdateControls.Children.Remove( $syncHash.Controls.ChbPublishFiles )
}

# region Scriptblocks
[System.Predicate[object]] $syncHash.Code.FuncSubMenuFilter =
{
	$func = $args[0].ObjectType -eq $syncHash.Controls.CbFuncObjectClass.SelectedItem.ObjectOperation
	$searchmatch = $syncHash.Controls.CbFuncExistingSubMenus.Text -match $syncHash.Controls.TiNewTemplate.Resources.CvsFuncSubMenus.Source.SubMenuName
	( $func ) -and ( $searchmatch -or $syncHash.Controls.CbFuncExistingSubMenus.Text.Length -eq 0 )
}

[System.Predicate[object]] $syncHash.Code.ToolSubMenuFilter =
{
	$tool = $args[0].ObjectType -eq $syncHash.Controls.CbToolObjectOperations.SelectedItem.ObjectOperation
	$searchmatch = $syncHash.Controls.CbToolExistingSubMenus.Text -match $syncHash.Controls.TiNewTemplate.Resources.CvsToolSubMenus.Source.SubMenuName
	( $tool ) -and ( $searchmatch -or $syncHash.Controls.CbToolExistingSubMenus.Text.Length -eq 0 )
}

[System.Predicate[object]] $syncHash.Code.AddFuncSettingFilter =
{
	( -not $args[0].Added )
}

[System.Predicate[object]] $syncHash.Code.AddPHSettingFilter =
{
	( -not $args[0].Added )
}

[System.Predicate[object]] $syncHash.Code.AddToolSettingFilter =
{
	( -not $args[0].Added )
}

[System.Windows.RequestBringIntoViewEventHandler] $syncHash.Code.BringSettingIntoView = {
	#param ( $SenderObject, $e )
	$syncHash.BIVTest = $args
}

[System.Windows.RoutedEventHandler] $syncHash.Code.CmFuncSettingClick =
{
	$args[0].DataContext.Added = $true
	$syncHash.Controls."GridFunc$( $args[0].DataContext.Setting )Setting".Visibility = [System.Windows.Visibility]::Visible
	$syncHash.Controls."GridFunc$( $args[0].DataContext.Setting )Setting".BringIntoView()
	$syncHash.Controls.TiNewTemplate.Resources.CvsFuncSettingsCollection.View.Refresh()
}

[System.Windows.RoutedEventHandler] $syncHash.Code.CmPHSettingClick =
{
	$args[0].DataContext.Added = $true
	$syncHash.Controls."GridPH$( $args[0].DataContext.Setting )Setting".Visibility = [System.Windows.Visibility]::Visible
	$syncHash.Controls."GridPH$( $args[0].DataContext.Setting )Setting".BringIntoView()
	$syncHash.Controls.TiNewTemplate.Resources.CvsPHSettingsCollection.View.Refresh()
}

[System.Windows.RoutedEventHandler] $syncHash.Code.CmToolSettingClick =
{
	$args[0].DataContext.Added = $true
	$syncHash.Controls."GridTool$( $args[0].DataContext.Setting )Setting".Visibility = [System.Windows.Visibility]::Visible
	$syncHash.Controls."GridTool$( $args[0].DataContext.Setting )Setting".BringIntoView()
	$syncHash.Controls.TiNewTemplate.Resources.CvsToolSettingsCollection.View.Refresh()
}

[System.Windows.RoutedEventHandler] $syncHash.Code.OpenFailedUpdatedFile =
{
	Open-File $args[0].DataContext.File.DevFile.FullName
}

[System.Windows.RoutedEventHandler] $syncHash.Code.RemoveInputDataVar =
{
	param ( $SenderObject, $e )

	$syncHash.Controls.TiNewTemplate.Resources.CvsFuncInputData.Source.Remove( ( $SenderObject.DataContext ) )
}

[System.Windows.RoutedEventHandler] $syncHash.Code.RemoveInputDataListVar =
{
	param ( $SenderObject, $e )

	$syncHash.Controls.TiNewTemplate.Resources.CvsFuncInputDataList.Source.Remove( ( $SenderObject.DataContext ) )
}

[System.Windows.RoutedEventHandler] $syncHash.Code.RemoveInputDataBoolVar =
{
	param ( $SenderObject, $e )

	$syncHash.Controls.TiNewTemplate.Resources.CvsFuncInputDataBool.Source.Remove( ( $SenderObject.DataContext ) )
}

[System.Windows.Controls.TextChangedEventHandler] $syncHash.Code.ValidateInputDataName =
{
	param ( $SenderObject, $e )

	if ( $SenderObject.Text -match "\W|\s" )
	{
		$SenderObject.DataContext.NameError = $syncHash.Data.msgTable.ErrNewCodeTemplateInputNameInvalidCharacter
	}
	elseif ( $SenderObject.Text.Length -gt 0 )
	{
		if ( ( $syncHash.Controls.TiNewTemplate.Resources.CvsFuncInputData.Source.Where( { $_.Name -eq $SenderObject.Text } ) + `
			$syncHash.Controls.TiNewTemplate.Resources.CvsFuncInputDataList.Source.Where( { $_.Name -eq $SenderObject.Text } ) + `
			$syncHash.Controls.TiNewTemplate.Resources.CvsFuncInputDataBool.Source.Where( { $_.Name -eq $SenderObject.Text } ) ).Count -gt 1 )
		{
			$SenderObject.DataContext.NameError = $syncHash.Data.msgTable.ErrNewCodeTemplateInputNameExists
		}
		else
		{
			$SenderObject.DataContext.NameError = ""
		}
	}
	elseif ( $SenderObject.Text -eq "" )
	{
		$SenderObject.DataContext.NameError = $syncHash.Data.msgTable.ErrNewCommandNoNameInput
	}
	else
	{
		$SenderObject.DataContext.NameError = ""
	}

	$SenderObject.DataContext.Valid = ( $SenderObject.DataContext.psobject.Properties.Where( { $_.Name -match "Error$" } ).Value -ne "" ).Count -eq 0
	$SenderObject.Parent.Children[1].GetBindingExpression( [System.Windows.Controls.TextBlock]::TextProperty ).UpdateTarget()
	$SenderObject.Parent.Parent.BringIntoView()
	Confirm-NewCommandInput
}

[System.Windows.Controls.TextChangedEventHandler] $syncHash.Code.VerifyDefaultListValueExists =
{
	param ( $SenderObject, $e )

	if ( $SenderObject.DataContext.Optionslist -notmatch "\b$( $SenderObject.Text )\b" )
	{
		$SenderObject.DataContext.DefaultValueError = $syncHash.Data.msgTable.ErrNewCodeTemplateDefaultValNotInOptionsList
	}
	else
	{
		$SenderObject.DataContext.DefaultValueError = ""
	}
	$SenderObject.DataContext.Valid = ( $SenderObject.DataContext.psobject.Properties.Where( { $_.Name -match "Error$" } ).Value -ne "" ).Count -eq 0
	$SenderObject.Parent.Children[1].GetBindingExpression( [System.Windows.Controls.TextBlock]::TextProperty ).UpdateTarget()
	$SenderObject.Parent.Parent.BringIntoView()
	Confirm-NewCommandInput
}

[System.Windows.Controls.TextChangedEventHandler] $syncHash.Code.VerifyOptionListDefaultValueExists =
{
	param ( $SenderObject, $e )

	if ( $SenderObject.DataContext.Optionslist -notmatch "\b$( $SenderObject.Parent.Children[7].Children[0].Text )\b" )
	{
		$SenderObject.DataContext.DefaultValueError = $syncHash.Data.msgTable.ErrNewCodeTemplateDefaultValNotInOptionsList
	}
	else
	{
		$SenderObject.DataContext.DefaultValueError = ""
	}
	$SenderObject.DataContext.Valid = ( $SenderObject.DataContext.psobject.Properties.Where( { $_.Name -match "Error$" } ).Value -ne "" ).Count -eq 0
	$SenderObject.Parent.Children[1].GetBindingExpression( [System.Windows.Controls.TextBlock]::TextProperty ).UpdateTarget()
	$SenderObject.Parent.Parent.BringIntoView()
	Confirm-NewCommandInput
}

[System.Windows.Controls.TextChangedEventHandler] $syncHash.Code.VerifyDescriptionEntered =
{
	param ( $SenderObject, $e )

	if ( $SenderObject.Text -eq "" )
	{
		$SenderObject.DataContext.DescriptionError = $syncHash.Data.msgTable.ErrNewCodeTemplateDescriptionNotGiven
	}
	else
	{
		$SenderObject.DataContext.DescriptionError = ""
	}
	$SenderObject.DataContext.Valid = ( $SenderObject.DataContext.psobject.Properties.Where( { $_.Name -match "Error$" } ).Value -ne "" ).Count -eq 0
	$SenderObject.Parent.Children[1].GetBindingExpression( [System.Windows.Controls.TextBlock]::TextProperty ).UpdateTarget()
	$SenderObject.Parent.Parent.BringIntoView()
	Confirm-NewCommandInput
}

# TextBox for function input is loaded, check if it is the first one, if so, set focus
[System.Windows.RoutedEventHandler] $syncHash.Code.InputTextBoxLoaded =
{
	param ( $SenderObject, $e )

	$SenderObject.Focus()
}
# endregion Scriptblocks

Initialize-Parsing
Set-Localizations

$syncHash.Data.ParsedLogs = [System.Collections.ObjectModel.ObservableCollection[Object]]::new()
$syncHash.Data.ParsedErrorLogs = [System.Collections.ObjectModel.ObservableCollection[Object]]::new()
$syncHash.Data.RollbackData = [System.Collections.ObjectModel.ObservableCollection[Object]]::new()
$syncHash.Data.RollbackFiles = [System.Collections.ObjectModel.ObservableCollection[Object]]::new()

$syncHash.Data.CultureInfo = [pscustomobject]@{
	CurrentCulture = Get-Culture
	DateTimeStringFormat = "$( ( Get-Culture ).DateTimeFormat.ShortDatePattern ) $( ( Get-Culture ).DateTimeFormat.LongTimePattern )"
	DateTimeFileStringFormat = "$( ( Get-Culture ).DateTimeFormat.ShortDatePattern ) $( ( Get-Culture ).DateTimeFormat.LongTimePattern )" -replace "/", "-" -replace ":", "."
}
$syncHash.Data.RollbackRoot = "$( $syncHash.Data.ProdRoot )\UpdateRollback"
$syncHash.Data.UpdatedFiles = New-Object System.Collections.ArrayList
$syncHash.Data.FilesUpdatedInProd = New-Object System.Collections.ArrayList
if ( Test-Path "C:\Program Files (x86)\Notepad++\notepad++.exe" ) { $syncHash.Data.Editor = "C:\Program Files (x86)\Notepad++\notepad++.exe" }
elseif ( Test-Path "C:\Program Files\Notepad++\notepad++.exe" ) { $syncHash.Data.Editor = "C:\Program Files\Notepad++\notepad++.exe" }
else { $syncHash.Data.Editor = "notepad" }

# region Kd summary
# Creates a summary for all functions and tools, and outputs into HTML-code
$syncHash.Controls.BtnCreateKdSummary.Add_Click( {
	function ConvertTo-KbSummaryLine
	{
		<#
		.Synopsis
			Create a summary string from a menuitem object
		#>

		param ( $Mi )

		$Styling = ""
		$StylingPost = ""
		$SummaryString = ""

		if ( $Mi.Separate )
		{
			$Styling = "<strong>"
			$StylingPost = "</strong>"
		}
		elseif ( $null -ne $Mi.PS )
		{
			$Styling = "<em>"
			$StylingPost = "</em>"
		}
		$SummaryString = "<p>$( $Styling )$( $Mi.MenuItem ) - $( $Mi.Description )$( $StylingPost )</p>"

		if ( $Mi.SearchedItemRequest -eq "Required" )
		{
			$SummaryString = "$( $SummaryString.TrimEnd( "</p>") ) <strong>$( $syncHash.Data.msgTable.StrKbSummaryNeedsSI )</strong></p>"
		}
		elseif ( $_.SearchedItemRequest -eq "Accepted" )
		{
			$SummaryString = "$( $SummaryString.TrimEnd( "</p>") )  $( $syncHash.Data.msgTable.StrKbSummaryAcceptsSI )</p>"
		}
		$StringBuilder.AppendLine( $SummaryString ) | Out-Null
	}

	$StringBuilder = [System.Text.StringBuilder]::new()
	$StringBuilder.AppendLine( $syncHash.Data.msgTable.StrKbSummaryPreamble ) | Out-Null
	$ForBo = [System.Collections.ArrayList]::new()

	$syncHash.Controls.Window.Resources.MenuItemsHash.GetEnumerator() | `
		Sort-Object -Property Name | `
		ForEach-Object {
			$SortOrder, $ObjectType, $TopName = $_.Name -split "_"
			$StringBuilder.AppendLine( "<h2>$( $TopName )</h2>" ) | Out-Null

			$_.Value | `
				Where-Object { $_.State -eq "Prod" } | `
				Sort-Object -Property MenuItem | `
				ForEach-Object {
					if ( $_.RequiredAdGroups -match $syncHash.Data.msgTable.CodeRegKbSummaryReqAdGrps )
					{
						$ForBo.Add( $_ ) | Out-Null
					}
					elseif ( $SortOrder -eq 8 )
					{
						$StringBuilder.AppendLine( "<p><span style=""text-decoration: underline;"">$( $_.MenuItem ) - $( $_.Description )</span></p>" ) | Out-Null
					}
					else
					{
						ConvertTo-KbSummaryLine -Mi $_
					}
				}

				$syncHash.Controls.Window.Resources.SubMenus.GetEnumerator() | `
					Where-Object { $_.Name -match $ObjectType } | `
					Sort-Object -Property MenuItem | `
					ForEach-Object {
						$StringBuilder.AppendLine( "<p>&nbsp;</p><h3>$( $_.Name -replace ".*Sub" , "$( $syncHash.Data.msgTable.StrKbSummarySubCategoryTitlePrefix ) ")</h3>" ) | Out-Null
						$_.Value.Source | `
							ForEach-Object {
								if ( $_.RequiredAdGroups -match $syncHash.Data.msgTable.CodeRegKbSummaryReqAdGrps )
								{
									$ForBo.Add( $_ ) | Out-Null
								}
								else
								{
									ConvertTo-KbSummaryLine -Mi $_
								}
							}
						}

				$StringBuilder.AppendLine( "<p>&nbsp;</p>" ) | Out-Null
			}

	$ForBo | `
		Sort-Object -Property MenuItem | `
		ForEach-Object `
			-Begin {
				$StringBuilder.AppendLine( "<h2>$( $syncHash.Data.msgTable.StrKbSummaryAvailableForBoTitle )</h2>" ) | Out-Null
			} `
			-Process {
				ConvertTo-KbSummaryLine -Mi $_
			}

	$StringBuilder.ToString() | clip
	Show-Splash -Text $syncHash.Data.msgTable.StrKbSummaryCopied -NoProgressBar -NoTitle
} )

# endregion Kd summary

# region Rollbacks
# Copy the list of updates for the currently selected script/file
$syncHash.Controls.BtnCopyRollbackInfo.Add_Click( {
	$OutputEncoding = ( New-Object System.Text.UnicodeEncoding $False, $False ).psobject.BaseObject
$a = @"
$( $syncHash.Data.msgTable.StrRollbackInfoCopyTitle ) '$( $syncHash.Controls.LvRollbackFileNames.SelectedItem.FileName )'

$( $syncHash.Data.msgTable.StrRollbackInfoCopyFileLogs ):
$( $OFS = "`r`n"; $syncHash.Controls.LvRollbackFileNames.SelectedItem.FileLogs | ForEach-Object { "$( $_.File.Name )`n$( $syncHash.Data.msgTable.StrRollbackInfoCopyUpdated )`t$( ( Get-Date $_.Updated -Format "yyyy-mm-dd HH:mm:ss" ) )`n$( $syncHash.Data.msgTable.StrRollbackInfoCopyUpdater )`t$( try { ( Get-ADUser -Identity $_.UpdatedBy ).Name } catch { $syncHash.Data.msgTable.StrNoUpdaterSpecified } )`n" } )
"@
$a | Clip
} )

# Rollback a file to selected version
$syncHash.Controls.BtnDoRollback.Add_Click( {
	$ProdFile = Get-ChildItem -Directory -Path $syncHash.Data.ProdRoot -Exclude "UpdateRollback", "Log", "ErrorLogs", "Output", "Development" | ForEach-Object { Get-ChildItem -Path $_.FullName -Filter "$( $syncHash.Controls.DgRollbacks.SelectedItem.FileName ).$( $syncHash.Controls.DgRollbacks.SelectedItem.Type )" -Recurse -File } | Select-Object -First 1

	if ( $null -eq $ProdFile )
	{
		$text = $syncHash.Data.msgTable.StrRollbackPathNotFound
		$icon = [System.Windows.MessageBoxImage]::Warning
		$button = [System.Windows.MessageBoxButton]::OK
	}
	else
	{
		$text = ( "{0}`n`n{1}`n{2}`n`n{3}`n{4}" -f $syncHash.Data.msgTable.StrRollbackVerification, $syncHash.Data.msgTable.StrRollbackVerificationPath, $ProdFile.FullName, $syncHash.Data.msgTable.StrRollbackVerificationDate, $syncHash.Controls.DgRollbacks.SelectedItem.Updated )
		$icon = [System.Windows.MessageBoxImage]::Question
		$button = [System.Windows.MessageBoxButton]::YesNo
	}

	if ( ( Show-MessageBox -Text $text -Icon $icon -Button $button ) -eq "Yes" )
	{
		$OutputEncoding = ( New-Object System.Text.UnicodeEncoding $False, $False ).psobject.BaseObject
		Set-Content -Value ( Get-Content $syncHash.Controls.DgRollbacks.SelectedItem.File.FullName ) -Path $ProdFile.FullName
		Show-MessageBox -Text $syncHash.Data.msgTable.StrRollbackDone
	}
} )

# List rollbacks
$syncHash.Controls.BtnListRollbacks.Add_Click( { Read-Rollbacks } )

# Open the selected previous version
$syncHash.Controls.BtnOpenRollbackFile.Add_Click( { Open-File $syncHash.Controls.DgRollbacks.SelectedItem.File.FullName } )

$syncHash.Controls.CbRollbackFilterTypePs1.Add_Checked( { $syncHash.Controls.Window.Resources['RollbackRowPs1Visible'] = [System.Windows.Visibility]::Visible } )
$syncHash.Controls.CbRollbackFilterTypePs1.Add_Unchecked( { $syncHash.Controls.Window.Resources['RollbackRowPs1Visible'] = [System.Windows.Visibility]::Collapsed } )
$syncHash.Controls.CbRollbackFilterTypePs1.Add_MouseRightButtonDown( {
	$this.IsChecked = $true
	Unregister-OtherRollbackFilters $this.Content
} )
$syncHash.Controls.CbRollbackFilterTypePsd1.Add_Checked( { $syncHash.Controls.Window.Resources['RollbackRowPsd1Visible'] = [System.Windows.Visibility]::Visible } )
$syncHash.Controls.CbRollbackFilterTypePsd1.Add_Unchecked( { $syncHash.Controls.Window.Resources['RollbackRowPsd1Visible'] = [System.Windows.Visibility]::Collapsed } )
$syncHash.Controls.CbRollbackFilterTypePsd1.Add_MouseRightButtonDown( {
	$this.IsChecked = $true
	Unregister-OtherRollbackFilters $this.Content
} )
$syncHash.Controls.CbRollbackFilterTypePsm1.Add_Checked( { $syncHash.Controls.Window.Resources['RollbackRowPsm1Visible'] = [System.Windows.Visibility]::Visible } )
$syncHash.Controls.CbRollbackFilterTypePsm1.Add_Unchecked( { $syncHash.Controls.Window.Resources['RollbackRowPsm1Visible'] = [System.Windows.Visibility]::Collapsed } )
$syncHash.Controls.CbRollbackFilterTypePsm1.Add_MouseRightButtonDown( {
	$this.IsChecked = $true
	Unregister-OtherRollbackFilters $this.Content
} )

$syncHash.Controls.CbRollbackFilterTypeTxt.Add_Checked( { $syncHash.Controls.Window.Resources['RollbackRowTxtVisible'] = [System.Windows.Visibility]::Visible } )
$syncHash.Controls.CbRollbackFilterTypeTxt.Add_Unchecked( { $syncHash.Controls.Window.Resources['RollbackRowTxtVisible'] = [System.Windows.Visibility]::Collapsed } )
$syncHash.Controls.CbRollbackFilterTypeTxt.Add_MouseRightButtonDown( {
	$this.IsChecked = $true
	Unregister-OtherRollbackFilters $this.Content
} )

$syncHash.Controls.CbRollbackFilterTypeXaml.Add_Checked( { $syncHash.Controls.Window.Resources['RollbackRowXamlVisible'] = [System.Windows.Visibility]::Visible } )
$syncHash.Controls.CbRollbackFilterTypeXaml.Add_Unchecked( { $syncHash.Controls.Window.Resources['RollbackRowXamlVisible'] = [System.Windows.Visibility]::Collapsed } )
$syncHash.Controls.CbRollbackFilterTypeXaml.Add_MouseRightButtonDown( {
	$this.IsChecked = $true
	Unregister-OtherRollbackFilters $this.Content
} )

$syncHash.Controls.DgRollbacks.Add_MouseLeftButtonUp( { Remove-DatagridSelection $args[1].OriginalSource $this } )

# Activate button to update files, if any item is selected
$syncHash.Controls.DgRollbacks.Add_SelectionChanged( {
	$syncHash.DC.BtnOpenRollbackFile[0] = $syncHash.DC.BtnDoRollback[0] = $this.SelectedItem -ne $null
} )

# When a script/file is selected, clear listed rollbacks and set filteroptions according to data for the selected file
$syncHash.Controls.LvRollbackFileNames.Add_SelectionChanged( {
	# Hide checkboxes for fileextensions not present in list
	$syncHash.Controls.GetEnumerator() | `
		Where-Object { $_.Key -match "CbRollbackFilterType" } | `
		ForEach-Object {
			$syncHash.Controls."$( $_.Key )".Visibility = [System.Windows.Visibility]::Collapsed
		}
	$syncHash.Controls.DgRollbacks.ItemsSource.Type | `
		Select-Object -Unique | `
		ForEach-Object {
			$syncHash.Controls."CbRollbackFilterType$_".Visibility = [System.Windows.Visibility]::Visible
			$syncHash.Controls."CbRollbackFilterType$_".IsChecked = $true
		}
} )
# endregion Rollbacks

# region Updates
# Start a check for any updates
$syncHash.Controls.BtnCheckForUpdates.Add_Click( { Get-Updates } )

$syncHash.Controls.BtnUpdatedInProdOpenDiffs.Add_Click( { Show-DiffWindow } )
$syncHash.Controls.BtnUpdatedInProdOpenDevFile.Add_Click( { Open-File $syncHash.Controls.DgUpdatedInProd.SelectedItem.DevPath } )
$syncHash.Controls.BtnUpdatedInProdOpenProdFile.Add_Click( { Open-File $syncHash.Controls.DgUpdatedInProd.SelectedItem.ProdPath } )
$syncHash.Controls.BtnUpdatedInProdOpenBothFiles.Add_Click( { Open-File ( $syncHash.Controls.DgUpdatedInProd.SelectedItem.psobject.Properties | Where-Object { $_.Name -match "^[^R].+Path$" } | Select-Object -ExpandProperty Value ) } )
$syncHash.Controls.BtnUpdatesOpenDiff.Add_Click( { Show-DiffWindow } )
$syncHash.Controls.BtnUpdatesOpenDevFile.Add_Click( { Open-File $syncHash.Controls.DgUpdates.SelectedItem.DevFile.FullName } )
$syncHash.Controls.BtnUpdatesOpenProdFile.Add_Click( { Open-File $syncHash.Controls.DgUpdates.SelectedItem.ProdFile.FullName } )
$syncHash.Controls.BtnUpdatesOpenBothFiles.Add_Click( { Open-File ( "Dev", "Prod" | ForEach-Object { $syncHash.Controls.DgUpdates.SelectedItem."$( $_ )File".FullName } ) } )

# Update selected files
$syncHash.Controls.BtnUpdateScripts.Add_Click( { Update-Files } )

# Update failed updates that have been checked
$syncHash.Controls.BtnUpdateFailedScripts.Add_Click( {
	if ( @( $syncHash.Controls.DgFailedUpdates.Items | Where-Object { $_.UpdateAnyway -match $true } ).Count -eq 0 )
	{
		Show-MessageBox -Text $syncHash.Data.msgTable.StrNoFailedSelected
	}
	else
	{
		Update-Files
	}
} )

# These checkboxes sets datagridrows visible or collapsed
$syncHash.Controls.CbShowDevFiles.Add_Checked( { $syncHash.Controls.Window.Resources['DevFilesVisible'] = [System.Windows.Visibility]::Visible } )
$syncHash.Controls.CbShowDevFiles.Add_Unchecked( { $syncHash.Controls.Window.Resources['DevFilesVisible'] = [System.Windows.Visibility]::Collapsed } )

$syncHash.Controls.DgUpdates.Add_LoadingRow( {
	if ( $args[1].Row.DataContext.DevFile.Extension -match "psm*1" )
	{
		$args[1].Row.DataContext.ScriptInfo = GetScriptInfo -FilePath $args[1].Row.DataContext.DevFile.FullName
		$args[1].Row.DataContext.ToolTip = ""
	}
	else
	{
		try
		{
			$args[1].Row.DataContext.ScriptInfo = GetScriptInfo -FilePath $args[1].Row.DataContext.SFile -ErrorAction Stop
			$args[1].Row.DataContext.ToolTip = "$( $syncHash.Data.msgTable.StrScriptState ) $( $args[1].Row.DataContext.ScriptInfo.State )"
		}
		catch
		{
			try
			{
				$args[1].Row.DataContext.ScriptInfo = GetScriptInfo -Function ( Get-Command $args[1].Row.DataContext.DevFile.BaseName -ErrorAction Stop )
				$args[1].Row.DataContext.ToolTip = "$( $syncHash.Data.msgTable.StrFunctionState ) $( $args[1].Row.DataContext.ScriptInfo.State )"
			}
			catch
			{
				$args[1].Row.DataContext.ToolTip = $syncHash.Data.msgTable.StrNoScriptfile
			}
		}
	}
} )

$syncHash.Controls.DgUpdates.Add_MouseLeftButtonUp( { Remove-DatagridSelection $args[1].OriginalSource $this } )

# If rightclick is used, open the file from dev and prod
$syncHash.Controls.DgUpdates.Add_MouseRightButtonUp( {
	if ( ( $args[1].OriginalSource.GetType() ).Name -eq "TextBlock" )
	{
		Open-File ( $this.CurrentItem.psobject.Properties | Where-Object { $_.name -match "^[^R].+Path$" } | Select-Object -ExpandProperty Value )
	}
} )

$syncHash.Controls.DgUpdatedInProd.Add_MouseLeftButtonUp( {
	Remove-DatagridSelection $args[1].OriginalSource $this
} )

# If rightclick is used, open the file from dev and prod
$syncHash.Controls.DgUpdatedInProd.Add_MouseRightButtonUp( {
	Show-DiffWindow $this.CurrentItem
} )

# Update info text about parsing updated files
$syncHash.Controls.PbParseUpdates.Add_ValueChanged( {
	$syncHash.DC.TblUpdatesProgress[0] = "$( $syncHash.Data.msgTable.StrCheckingUpdatesCheckFiles ) $( [Math]::Round( ( $this.Value / $this.Maximum ) * 100 ) ) %"
} )
# endregion Updates

# region Logs
# Reset the controls for logs
$syncHash.Controls.BtnClearLogSearch.Add_Click( {
	$syncHash.Controls.BtnClearLogSearch.Visibility = [System.Windows.Visibility]::Collapsed
	$syncHash.Controls.CbLogSearchType.SelectedIndex = -1
	$syncHash.Controls.TbLogSearchText.Text = ""
	$syncHash.Controls.Window.Resources['CvsLogsScriptNames'].Source.Clear()
	$syncHash.Data.ParsedLogs | ForEach-Object { $syncHash.Controls.Window.Resources['CvsLogsScriptNames'].Source.Add( $_ ) }
} )

# Copy log entry to clipboard
$syncHash.Controls.BtnCopyLogInfo.Add_Click( {
	$OutputEncoding = ( New-Object System.Text.UnicodeEncoding $False, $False ).psobject.BaseObject
	$OFS = "`n"
	$a = @"
$( $syncHash.Data.msgTable.StrLogInfoCopyTitle ) '$( $syncHash.Controls.CbLogsScriptNames.SelectedItem.ScriptName )'

$( $syncHash.Data.msgTable.StrLogInfoCopyDate ): $( $syncHash.Controls.DgLogs.SelectedItem.LogDate )
$( $syncHash.Data.msgTable.StrLogInfoCopyOperator ): $( $syncHash.Controls.DgLogs.SelectedItem.Operator )
$( $syncHash.Data.msgTable.StrLogInfoCopySuccess ): $( $syncHash.Controls.DgLogs.SelectedItem.Success )
$( $syncHash.Data.msgTable.StrLogInfoCopyLogText ): $( $syncHash.Controls.DgLogs.SelectedItem.LogText )
"@

	if ( $syncHash.Controls.DgLogs.SelectedItem.ComputerName )
	{
		$a += "$( $syncHash.Data.msgTable.StrLogInfoCopyComputerName ): $( $syncHash.Controls.DgLogs.SelectedItem.ComputerName ) "
	}

	if ( $syncHash.Controls.DgLogs.SelectedItem.OutputFile.Count -gt 0 )
	{
		if ( $syncHash.Controls.CbCopyLogInfoIncludeOutputFiles.IsChecked )
		{
			$a += "$( $syncHash.Data.msgTable.StrLogInfoCopyOutputFile )`n"
			$syncHash.Controls.DgLogs.SelectedItem.OutputFile | ForEach-Object { $a += "$( $syncHash.Data.msgTable.StrLogInfoCopyOutputFilePath ): $_`n$( Get-Content $_ )" }
		}
		else { $a += "$( $syncHash.Data.msgTable.StrLogInfoCopyOutputFile ): $( [string]$syncHash.Controls.DgLogs.SelectedItem.OutputFile ) " }
	}

	if ( $syncHash.Controls.DgLogs.SelectedItem.ErrorLogFile.Count -gt 0 )
	{
		if ( $syncHash.Controls.CbCopyLogInfoIncludeErrorLogs.IsChecked )
		{
			$a += "$( $syncHash.Data.msgTable.StrLogInfoCopyError )"
			$syncHash.Controls.DgLogs.SelectedItem.ErrorLogFile | ForEach-Object { Get-Content $_ | ConvertFrom-Json | Out-String | ForEach-Object { $e += "$_`n" } }
		}
		else { $a += "$( $syncHash.Data.msgTable.StrLogInfoCopyErrorFilePath ): $( [string]$syncHash.Controls.DgLogs.SelectedItem.OutputFile ) " }
	}

	$a | Clip
	$syncHash.Controls.PopupCopyLogInfo.IsOpen = $false
} )

# Search the logs for entered data
$syncHash.Controls.BtnLogSearch.Add_Click( {
	$syncHash.Controls.BtnClearLogSearch.Visibility = [System.Windows.Visibility]::Visible
	$syncHash.Controls.Window.Resources['CvsLogsScriptNames'].Source.Clear()
	$syncHash.Data.ParsedLogs | Where-Object { $_.ScriptLogs.( $syncHash.Controls.CbLogSearchType.SelectedItem.Content ) -match $syncHash.Controls.TbLogSearchText.Text } | ForEach-Object { $syncHash.Controls.Window.Resources['CvsLogsScriptNames'].Source.Add( $_ ) }
} )

# Open the outputfile
$syncHash.Controls.BtnOpenOutputFile.Add_Click( { Open-File $syncHash.Controls.CbLogOutputFiles.SelectedItem } )

# Open meny to include other data
$syncHash.Controls.BtnOpenPopupCopyLogInfo.Add_Click( { $syncHash.Controls.PopupCopyLogInfo.IsOpen = -not $syncHash.Controls.PopupCopyLogInfo.IsOpen } )

# Parse all logs and load the data
$syncHash.Controls.BtnReadLogs.Add_Click( { Read-Logs } )

$syncHash.Controls.CbLogsFilterSuccessFailed.Add_Checked( { $syncHash.Controls.Window.Resources['LogskRowFailedVisible'] = [System.Windows.Visibility]::Visible } )
$syncHash.Controls.CbLogsFilterSuccessFailed.Add_Unchecked( { $syncHash.Controls.Window.Resources['LogskRowFailedVisible'] = [System.Windows.Visibility]::Collapsed } )
$syncHash.Controls.CbLogsFilterSuccessSuccess.Add_Checked( { $syncHash.Controls.Window.Resources['LogskRowSuccessVisible'] = [System.Windows.Visibility]::Visible } )
$syncHash.Controls.CbLogsFilterSuccessSuccess.Add_Unchecked( { $syncHash.Controls.Window.Resources['LogskRowSuccessVisible'] = [System.Windows.Visibility]::Collapsed } )

$syncHash.Controls.CbLogsScriptNames.Add_SelectionChanged( {
	$syncHash.Controls.Window.Resources['CvsDgLogs'].Source = $this.SelectedItem.ScriptLogs
	$syncHash.Controls.RbLogsDisplayPeriodRecent.IsChecked = $true
} )

# Set binding to all logs
$syncHash.Controls.RbLogsDisplayPeriodAll.Add_Checked( {
	$b = [System.Windows.Data.Binding]@{ ElementName = "CbLogsScriptNames"; Path = "SelectedItem.ScriptLogs" }
	[void][System.Windows.Data.BindingOperations]::SetBinding( $syncHash.Controls.DgLogs, [System.Windows.Controls.DataGrid]::ItemsSourceProperty, $b )
} )

$syncHash.Controls.DgLogs.Add_MouseLeftButtonUp( { Remove-DatagridSelection $args[1].OriginalSource $this } )

# Set binding to recent logs
$syncHash.Controls.RbLogsDisplayPeriodRecent.Add_Checked( {
	$b = [System.Windows.Data.Binding]@{ ElementName = "CbLogsScriptNames"; Path = "SelectedItem.ScriptLogsRecent" }
	[void][System.Windows.Data.BindingOperations]::SetBinding( $syncHash.Controls.DgLogs, [System.Windows.Controls.DataGrid]::ItemsSourceProperty, $b )
} )
# endregion Logs

# region Errorlogs
# Reset the controls for Errorlogs
$syncHash.Controls.BtnClearErrorLogSearch.Add_Click( {
	$syncHash.Controls.BtnClearErrorLogSearch.Visibility = [System.Windows.Visibility]::Collapsed
	$syncHash.Controls.CbErrorLogSearchType.SelectedIndex = -1
	$syncHash.Controls.TbErrorLogSearchText.Text = ""
	$syncHash.Controls.Window.Resources['CvsErrorLogsScriptNames'].Source.Clear()
	$syncHash.Data.ParsedErrorLogs | ForEach-Object { $syncHash.Controls.Window.Resources['CvsErrorLogsScriptNames'].Source.Add( $_ ) }
} )

# Copy the information for the currently selected error
$syncHash.Controls.BtnCopyErrorInfo.Add_Click( {
	$OutputEncoding = ( New-Object System.Text.UnicodeEncoding $False, $False ).psobject.BaseObject
	$syncHash.Controls.GridErrorInfo.DataContext | Clip
} )

# Search the errorlogs for entered data
$syncHash.Controls.BtnErrorLogSearch.Add_Click( {
	$syncHash.Controls.BtnClearErrorLogSearch.Visibility = [System.Windows.Visibility]::Visible
	$syncHash.Controls.Window.Resources['CvsErrorLogsScriptNames'].Source.Clear()
	$syncHash.Data.ParsedErrorLogs | Where-Object { $_.ScriptErrorLogs.( $syncHash.Controls.CbErrorLogSearchType.SelectedItem.Content ) -match $syncHash.Controls.TbErrorLogSearchText.Text } | ForEach-Object { $syncHash.Controls.Window.Resources['CvsErrorLogsScriptNames'].Source.Add( $_ ) }
} )

# If errorlogs have been parsed, open the selected data in the errorlogs-tab
$syncHash.Controls.BtnOpenErrorLog.Add_Click( {
	if ( $syncHash.Controls.CbErrorLogsScriptNames.HasItems )
	{
		$syncHash.Controls.TbAdmin.SelectedIndex = 2
		$syncHash.Controls.CbErrorLogsScriptNames.SelectedItem = $syncHash.Controls.CbErrorLogsScriptNames.Items.Where( { $_.ScriptName -eq $syncHash.Controls.CbLogsScriptNames.Text } )[0]
		Start-Sleep 0.5
		$syncHash.Controls.DgErrorLogs.SelectedIndex = $syncHash.Controls.DgErrorLogs.Items.IndexOf( ( $syncHash.Controls.DgErrorLogs.Items.Where( { $_.Logdate -eq $syncHash.Controls.CbLogErrorlog.SelectedValue } ) )[0] )
	}
	else { Show-MessageBox -Text $syncHash.Data.msgTable.StrErrorlogsNotLoaded }
} )

# Parse errorlogs and load the data
$syncHash.Controls.BtnReadErrorLogs.Add_Click( { Read-Errorlogs } )

$syncHash.Controls.CbErrorLogsScriptNames.Add_SelectionChanged( {
	$this.SelectedItem.ScriptErrorLogs | ForEach-Object { $syncHash.Controls.Window.Resources['CvsDgErrorLogs'].Source.Add( $_ ) }
	$syncHash.Controls.RbErrorLogsDisplayPeriodRecent.IsChecked = $true
} )

# Click was made outside of rows and valid cells, unselect selected rows
$syncHash.Controls.DgErrorLogs.Add_MouseLeftButtonUp( { Remove-DatagridSelection $args[1].OriginalSource $this } )

# Set binding to all errorlogs
$syncHash.Controls.RbErrorLogsDisplayPeriodAll.Add_Checked( {
	$b = [System.Windows.Data.Binding]@{ ElementName = "CbErrorLogsScriptNames"; Path = "SelectedItem.ScriptErrorLogs" }
	[void][System.Windows.Data.BindingOperations]::SetBinding( $syncHash.Controls.DgErrorLogs, [System.Windows.Controls.DataGrid]::ItemsSourceProperty, $b )
} )

# Set binding to recent errorlogs
$syncHash.Controls.RbErrorLogsDisplayPeriodRecent.Add_Checked( {
	$b = [System.Windows.Data.Binding]@{ ElementName = "CbErrorLogsScriptNames"; Path = "SelectedItem.ScriptErrorLogsRecent" }
	[void][System.Windows.Data.BindingOperations]::SetBinding( $syncHash.Controls.DgErrorLogs, [System.Windows.Controls.DataGrid]::ItemsSourceProperty, $b )
} )
# endregion Errorlogs

# region New code template controls
# 
$syncHash.Controls.BtnCreateCodeTemplate.Add_Click( {
	switch ( $syncHash.Controls.TcNewCodeTemplate.SelectedIndex )
	{
		0 {
			New-CodeTemplateFunc
		}
		1 {
			New-CodeTemplateTool
		}
		2 {
			New-CodeTemplatePropHandler
		}
	}


	Reset-NewTemplateControls
} )

# 
$syncHash.Controls.BtnFuncAddInputVariable.Add_Click( {
	$syncHash.Controls.TiNewTemplate.Resources.CvsFuncInputData.Source.Add( ( [pscustomobject]@{ Name = "" ; NameError = $syncHash.Data.msgTable.ErrNewFuncNoNameInput ; Mandatory = $false ; Description = "" ; DescriptionError = $syncHash.Data.msgTable.ErrNewFuncTemplateDescriptionNotGiven ; Valid = $false } ) )
	$syncHash.Controls.IcFuncInputData.BringIntoView()
} )

# 
$syncHash.Controls.BtnFuncAddInputVariableBool.Add_Click( {
	$syncHash.Controls.TiNewTemplate.Resources.CvsFuncInputDataBool.Source.Add( ( [pscustomobject]@{ Name = "" ; NameError = $syncHash.Data.msgTable.ErrNewToolNoNameInput ; Mandatory = $false ; Description = "" ; DescriptionError = $syncHash.Data.msgTable.ErrNewToolTemplateDescriptionNotGiven ; Valid = $false } ) )
	$syncHash.Controls.IcFuncInputDataBool.BringIntoView()
} )

# 
$syncHash.Controls.BtnFuncAddInputVariableList.Add_Click( {
	$syncHash.Controls.TiNewTemplate.Resources.CvsFuncInputDataList.Source.Add( ( [pscustomobject]@{ Name = "" ; NameError = $syncHash.Data.msgTable.ErrNewPHNoNameInput ; Mandatory = $false ; Description = "" ; DescriptionError = $syncHash.Data.msgTable.ErrNewPropHandlerTemplateDescriptionNotGiven ; DefaultValue = "" ; DefaultValueError = "" ; Optionslist = "" ; Valid = $false } ) )
	$syncHash.Controls.IcFuncInputDataList.BringIntoView()
} )

# Open contextmenu to add setting for new function
$syncHash.Controls.BtnFuncAddSettingTitle.Add_Click( {
	$this.ContextMenu.IsOpen = $true
} )

# Open contextmenu to add setting for new PropHandler
$syncHash.Controls.BtnPHAddSettingTitle.Add_Click( {
	$this.ContextMenu.IsOpen = $true
} )

# Reset all controls
$syncHash.Controls.BtnResetTemplateInfo.Add_Click( {
	Reset-NewTemplateControls
} )

# Open contextmenu to add setting for new tool
$syncHash.Controls.BtnToolAddSettingTitle.Add_Click( {
	$this.ContextMenu.IsOpen = $true
} )

# 
$syncHash.Controls.CbFuncExistingSubMenus.Add_KeyUp( {
	Confirm-SettingSubMenu -Control $this
} )

# ObjectClass was selected, update list of existing submenus for selected objecttype
$syncHash.Controls.CbFuncObjectClass.Add_SelectionChanged( {
	Confirm-SettingObjectType -Control $this
} )

#
$syncHash.Controls.CbFuncPsVerbs.Add_SelectionChanged( {
	Confirm-NewCommandName -TbControl $syncHash.Controls.TbFuncName -CbControl $syncHash.Controls.CbFuncPsVerbs
} )

#
$syncHash.Controls.CbFuncSearchedItemRequest.Add_SelectionChanged( {
	if ( $this.SelectedIndex -eq -1 )
	{
		$syncHash.Data.NewCodeTemplateInfo.Remove( "SearchedItemRequest" )
	}
	else
	{
		$syncHash.Data.NewCodeTemplateInfo.SearchedItemRequest = $this.SelectedValue
	}

	Confirm-NewCommandInput
} )

#
$syncHash.Controls.CbFuncState.Add_SelectionChanged( {
	Confirm-SettingState -Control $this
} )

#
$syncHash.Controls.CbPHDataSource.Add_SelectionChanged( {
	if ( $this.SelectedIndex -lt 1 )
	{
		$syncHash.Controls.TblPHDataSourceError.Text = $syncHash.Data.msgTable.ErrNewPHDataSourceNotGiven
		$syncHash.Data.NewCodeTemplateInfo.Remove( "DataSource" )
		$syncHash.Data.NewCodeTemplateInfo.Remove( "MandatorySource" )
	}
	else
	{
		$syncHash.Controls.TblPHDataSourceError.Text = ""
		$syncHash.Data.NewCodeTemplateInfo.DataSource = $syncHash.Controls.CbPHDataSource.SelectedItem
		$syncHash.Data.NewCodeTemplateInfo.MandatorySource = $syncHash.Controls.CbPHDataSource.SelectedItem
	}

	Confirm-NewCommandInput
} )

#
$syncHash.Controls.CbPHObjectClass.Add_SelectionChanged( {
	Confirm-SettingObjectType -Control $this
} )

#
$syncHash.Controls.CbPHState.Add_SelectionChanged( {
	Confirm-SettingState -Control $this
} )

#
$syncHash.Controls.CbToolExistingSubMenus.Add_KeyUp( {
	Confirm-SettingSubMenu -Control $this
} )

# ObjectOperation was selected, update list of existing submenus for selected objecttype
$syncHash.Controls.CbToolObjectOperations.Add_SelectionChanged( {
	Confirm-SettingObjectType -Control $this
} )

#
$syncHash.Controls.CbToolPsVerbs.Add_SelectionChanged( {
	Confirm-NewCommandName -TbControl $syncHash.Controls.TbToolName -CbControl $syncHash.Controls.CbToolPsVerbs
} )

#
$syncHash.Controls.ChbToolSeparate.Add_Checked( {
	$syncHash.Data.NewCodeTemplateInfo.Separate = $this.IsChecked
} )

#
$syncHash.Controls.ChbToolSeparate.Add_Unchecked( {
	$syncHash.Data.NewCodeTemplateInfo.Separate = $this.IsChecked
} )

#
$syncHash.Controls.CbToolState.Add_SelectionChanged( {
	Confirm-SettingState -Control $this
} )

#
$syncHash.Controls.TbFuncAllowedUsers.Add_TextChanged( {
	Confirm-SettingAllowedUsers -Control $this
} )

#
$syncHash.Controls.TbFuncAuthor.Add_TextChanged( {
	Confirm-SettingAuthor -Control $this
} )

#
$syncHash.Controls.TbFuncDescription.Add_TextChanged( {
	Confirm-SettingDescription -Control $this
} )

#
$syncHash.Controls.TbFuncInvalidateDateTime.Add_TextChanged( {
	Confirm-SettingDateTime -Control $this
} )

#
$syncHash.Controls.TbFuncMenuItem.Add_TextChanged( {
	Confirm-SettingMenuItem -Control $this
} )

#
$syncHash.Controls.TbFuncName.Add_TextChanged( {
	Confirm-NewCommandName -TbControl $this -CbControl $syncHash.Controls.CbFuncPsVerbs
} )

#
$syncHash.Controls.TbFuncNote.Add_TextChanged( {
	if ( $this.Text.Length -eq 0 )
	{
		$syncHash.Data.NewCodeTemplateInfo.Remove( "Note" )
	}
	else
	{
		$syncHash.Data.NewCodeTemplateInfo.Note = $this.Text
		if ( $syncHash.Controls.RbFuncNoteTypeInfo.IsChecked )
		{
			$syncHash.Data.NewCodeTemplateInfo.NoteType = "Info"
		}
		else
		{
			$syncHash.Data.NewCodeTemplateInfo.NoteType = "Warning"
		}
	}

	Confirm-NewCommandInput
} )

#
$syncHash.Controls.TbFuncRequiredAdGroups.Add_TextChanged( {
	Confirm-SettingRequiredAdGroups -Control $this
} )

#
$syncHash.Controls.TbFuncSynopsis.Add_TextChanged( {
	Confirm-SettingSynopsis -Control $this
} )

#
$syncHash.Controls.TbFuncValidStartDateTime.Add_TextChanged( {
	Confirm-SettingDateTime -Control $this
} )

#
$syncHash.Controls.TbPHAllowedUsers.Add_TextChanged( {
	Confirm-SettingAllowedUsers -Control $this
} )

#
$syncHash.Controls.TbPHAuthor.Add_TextChanged( {
	Confirm-SettingAuthor -Control $this
} )

#
$syncHash.Controls.TbPHCode.Add_TextChanged( {
	$syncHash.Data.NewCodeTemplateInfo.Code = $this.Text
} )

#
$syncHash.Controls.TbPHCodeComment.Add_TextChanged( {
	if ( $this.Text.Length -eq 0 )
	{
		$syncHash.Controls.TblPHCodeCommentError.Text = $syncHash.Data.msgTable.ErrNewPHNoCodeComment
		$syncHash.Data.NewCodeTemplateInfo.Remove( "CodeComment" )
	}
	elseif ( $this.Text.Length -lt 10 )
	{
		$syncHash.Controls.TblPHCodeCommentError.Text = $syncHash.Data.msgTable.ErrNewPHMoreDescriptiveCodeComment
		$syncHash.Data.NewCodeTemplateInfo.Remove( "CodeComment" )
	}
	else
	{
		$syncHash.Controls.TblPHCodeCommentError.Text = ""
		$syncHash.Data.NewCodeTemplateInfo.CodeComment = $this.Text
	}
} )

#
$syncHash.Controls.TbPHDescription.Add_TextChanged( {
	Confirm-SettingDescription -Control $this
} )

#
$syncHash.Controls.TbPHInvalidateDateTime.Add_TextChanged( {
	Confirm-SettingDateTime -Control $this
} )

#
$syncHash.Controls.TbPHName.Add_TextChanged( {
	Confirm-NewCommandName -TbControl $this
} )

#
$syncHash.Controls.TbPHRequiredAdGroups.Add_TextChanged( {
	Confirm-SettingRequiredAdGroups -Control $this
} )

#
$syncHash.Controls.TbPHTitle.Add_TextChanged( {
	if ( $this.Text.Length -eq 0 )
	{
		$syncHash.Controls.TblPHTitleError.Text = $syncHash.Data.msgTable.ErrNewCodeTemplatePHTitleEmpty
		$syncHash.Data.NewCodeTemplateInfo.Remove( "Title" )
	}
	else
	{
		$syncHash.Controls.TblPHTitleError.Text = ""
		$syncHash.Data.NewCodeTemplateInfo.Title = $this.Text
	}

	Confirm-NewCommandInput
} )

#
$syncHash.Controls.TbPHValidStartDateTime.Add_TextChanged( {
	Confirm-SettingDateTime -Control $this
} )

#
$syncHash.Controls.TbToolAllowedUsers.Add_TextChanged( {
	Confirm-SettingAllowedUsers -Control $this
} )

#
$syncHash.Controls.TbToolAuthor.Add_TextChanged( {
	Confirm-SettingAuthor -Control $this
} )

#
$syncHash.Controls.TbToolDescription.Add_TextChanged( {
	Confirm-SettingDescription -Control $this
} )

#
$syncHash.Controls.TbToolInvalidateDateTime.Add_TextChanged( {
	Confirm-SettingDateTime -Control $this
} )

#
$syncHash.Controls.TbToolMenuItem.Add_TextChanged( {
	Confirm-SettingMenuItem -Control $this
} )

#
$syncHash.Controls.TbToolName.Add_TextChanged( {
	Confirm-NewCommandName -TbControl $this -CbControl $syncHash.Controls.CbToolPsVerbs
} )

#
$syncHash.Controls.TbToolRequiredAdGroups.Add_TextChanged( {
	Confirm-SettingRequiredAdGroups -Control $this
} )

#
$syncHash.Controls.TbToolSynopsis.Add_TextChanged( {
	Confirm-SettingSynopsis -Control $this
} )

#
$syncHash.Controls.TbToolValidStartDateTime.Add_TextChanged( {
	Confirm-SettingDateTime -Control $this
} )

#
$syncHash.Controls.TcNewCodeTemplate.Add_SelectionChanged( {
	if ( $args[1].Source -is [System.Windows.Controls.TabControl] )
	{
		$syncHash.Data.NewCodeTemplateInfo.Clear()
		Reset-NewTemplateControls
	}
} )
# endregion New code template controls

# region Window settings
# Window rendered, do some final preparations
$syncHash.Controls.Window.Add_Loaded( {
	if ( -not $syncHash.Loaded )
	{
		$syncHash.Loaded = $true
		$this.Resources['DiffWindow'].DataContext = [pscustomobject]@{
			MsgTable = $syncHash.Data.msgTable
		}

		$syncHash.Controls.Window.Resources.MenuItemsHash.GetEnumerator() | `
			ForEach-Object {
				$SortOrder, $Object, $TopName = $_.Name -split "_"
				$ObjectItems = [pscustomobject]@{
					SortOrder = $SortOrder
					Object = $Object
					TopName = $TopName
					Items = [System.Collections.ObjectModel.ObservableCollection[object]]$_.Value
				}
				$syncHash.Controls.TiKbSummary.Resources['CvsKdSummary'].Source.Add( $ObjectItems )
			}

		$syncHash.Controls.Window.Resources.SubMenus | `
			ForEach-Object {
				$_.Value.Source | `
					ForEach-Object {
						$t = $_
						$syncHash.Controls.TiKbSummary.Resources['CvsKdSummary'].Source.Where( { ( $_.Object -eq $t.ObjectClass ) -or ( $_.Object -eq $t.ObjectOperations ) } )[0].Items.Add( $t )
					}
			}

		Initialize-NewTemplateControls

		$syncHash.Controls.Window.Resources.SubMenus.GetEnumerator() | `
			ForEach-Object {
				$_.Value.View | `
					ForEach-Object {
						$OT = if ( $_.Objectclass )
								{
									$_.Objectclass
								}
								else
								{
									$_.Objectoperations
								}
						$t = [PSCustomObject]@{
							SubMenuName = $_.SubMenu
							ObjectType = [cultureinfo]::CurrentCulture.TextInfo.ToTitleCase( $OT )
						}
						if ( -not $syncHash.Controls.TiNewTemplate.Resources.CvsFuncSubMenus.Source.Where( { $_.ObjectType -eq $t.ObjectType -and $_.SubMenuName -eq $t.SubMenuName } ) )
						{
							$syncHash.Controls.TiNewTemplate.Resources.CvsFuncSubMenus.Source.Add( $t )
							$syncHash.Controls.TiNewTemplate.Resources.CvsToolSubMenus.Source.Add( $t )
						}
					}
			}

		$syncHash.Controls.TiNewTemplate.Resources.CvsFuncSubMenus.View.Filter = $syncHash.Code.FuncSubMenuFilter
		$syncHash.Controls.TiNewTemplate.Resources.CvsToolSubMenus.View.Filter = $syncHash.Code.ToolSubMenuFilter

		$syncHash.Data.ExistingCommandNames = ( $syncHash.Controls.Window.Resources.SubMenus.GetEnumerator() | ForEach-Object { $_.Value.Source.Name } ) + ( $syncHash.Controls.Window.Resources.MenuItemsHash.GetEnumerator() | ForEach-Object { $_.Value.Name } )
		$syncHash.Data.ExistingMenuItems = ( $syncHash.Controls.Window.Resources.SubMenus.GetEnumerator() | ForEach-Object { $_.Value.Source.MenuItem } ) + ( $syncHash.Controls.Window.Resources.MenuItemsHash.GetEnumerator() | ForEach-Object { $_.Value.MenuItem } )

		# Get a list of obsolete functions in modules
		$syncHash.ObsoleteFunctions = ( Get-Module ).Where( { $_.Path.StartsWith( $BaseDir ) } ) | `
			ForEach-Object { Get-Command -Module $_.Name } | `
			Where-Object { $_.Definition -match "\[Obsolete.+\]" } | `
			Select-Object -Property `
				@{ Name = "FunctionName"; Expression = { $_.Name } }, `
				@{ Name = "HelpMessage"; Expression = { ( ( ( $_.Definition -split "`n" | Select-String -Pattern "\[Obsolete.+\]" ) -split "\(" )[1] -split "\)" )[0].Trim() } }

		Reset-NewTemplateControls
	}
} )

# endregion Window settings

# region DiffWindow settings
# Close the diff window
$syncHash.Controls.BtnDiffCancel.Add_Click( {
	$syncHash.Controls.DiffWindow.Visibility = [System.Windows.Visibility]::Hidden
} )

# Catch keypress
$syncHash.Controls.DiffWindow.Add_KeyDown( {
	if ( $args[1].Key -eq "Escape" )
	{
		$this.Visibility = [System.Windows.Visibility]::Hidden
	}
} )

# Window is rendered, do some final settings
$syncHash.Controls.DiffWindow.Add_Loaded( {
	$this.Top = 20
} )

# Center the window after resize
$syncHash.Controls.DiffWindow.Add_SizeChanged( {
	$this.Top = 20
	$this.Left += ( $args[1].PreviousSize.Width / 2 ) - ( $args[1].NewSize.Width / 2 )
} )

# Cancel closing, instead hide window
$syncHash.Controls.DiffWindow.Add_Closing( {
	$args[1].Cancel = $true
	$this.Visibility = [System.Windows.Visibility]::Hidden
} )

# Empty DataContext when DiffWindow is no longer visible
$syncHash.Controls.DiffWindow.Add_IsVisibleChanged( {
	if ( $this.Visibility -eq [System.Windows.Visibility]::Hidden )
	{
		$syncHash.Controls.DgDiffList.ItemsSource.Clear()
	}
} )
# endregion DiffWindow settings

Export-ModuleMember

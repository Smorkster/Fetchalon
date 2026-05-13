<#
.Synopsis
	Show About m.m.
.MenuItem
	Show About
.Description
	Show useful information about Fetchalon etc.
.State
	Prod
.ObjectOperations
	Suite
.Author
	Smorkster (smorkster)
#>

Add-Type -AssemblyName PresentationFramework
$syncHash = $args[0]

function Get-Data
{
	Get-Module | `
		ForEach-Object {
			$syncHash.Controls.Window.Resources['CvsModules'].Source.Add( $_ ) | Out-Null
		}

	try
	{
		$syncHash.Controls.TblO365Account.Text = ( Get-AzureADCurrentSessionInfo -ErrorAction Stop ).Account.Id
	}
	catch
	{
		$syncHash.Controls.TblO365Account.Text = $syncHash.Data.msgTable.ErrO365NotLoggedIn
	}

	if ( Test-Path "C:\Program Files (x86)\Notepad++\notepad++.exe" )
	{
		$syncHash.Controls.Window.Resources['CvsEditors'].Source.Add( ( [pscustomobject]@{ Name = "Notepad++"; Path = "C:\Program Files (x86)\Notepad++\notepad++.exe" } ) )
	}
	elseif ( Test-Path "C:\Program Files\Notepad++\notepad++.exe" )
	{
		$syncHash.Controls.Window.Resources['CvsEditors'].Source.Add( ( [pscustomobject]@{ Name = "Notepad++"; Path = "C:\Program Files\Notepad++\notepad++.exe" } ) )
	}
	$syncHash.Controls.Window.Resources['CvsEditors'].Source.Add( ( [pscustomobject]@{ Name = "Notepad"; Path = "notepad" } ) )

	$syncHash.Controls.TblPSVersionTable.Text = $PSVersionTable.PSVersion.ToString()
}

function Set-Localizations
{
	$syncHash.Controls.Window.Resources['CvsEditors'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	$syncHash.Controls.Window.Resources['CvsModules'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	$syncHash.Controls.Window.Resources['ValueTtDescription'] = $syncHash.Data.msgTable.ContentTblValueTtDescription
	$syncHash.Controls.Window.Resources['ValueTtPath'] = $syncHash.Data.msgTable.ContentTblValueTtPath
	$syncHash.Controls.Window.Resources['ValueTtVersion'] = $syncHash.Data.msgTable.ContentTblValueTtVersion
	$syncHash.Controls.Window.Resources['StrModuleOpenPath'] = $syncHash.Data.msgTable.StrModuleOpenPath
	$syncHash.Controls.Window.Resources['StrModuleOpenRead'] = $syncHash.Data.msgTable.StrModuleOpenRead

	$syncHash.Controls.Window.Resources.MiReadStyle.Setters[0].Handler = $syncHash.Code.ModuleReadClick
	$syncHash.Controls.Window.Resources.TblExpCmdStyle.Setters[0].Handler = $syncHash.Code.TblExpCmdMouseOver
	$syncHash.Controls.Window.Resources.TblExpCmdStyle.Setters[1].Handler = $syncHash.Code.TblExpCmdMouseLeave
}

################### Start script
$controls = [System.Collections.ArrayList]::new()

BindControls $syncHash $controls

$syncHash.Controls.BtnOpenModuleFolder.Add_Click( {
	$Module = $syncHash.Controls.LbModules.SelectedItem

	Start-Process -FilePath C:\Windows\explorer.exe -ArgumentList "/select, ""$( $Module.Path )"""
} )

$syncHash.Controls.BtnOpenFile.Add_Click( {
	$this.ContextMenu.IsOpen = $true
} )

[System.Windows.RoutedEventHandler] $syncHash.Code.ModuleReadClick = {
	param ( $SenderObject, $e )

	$Module = $syncHash.Controls.LbModules.SelectedItem

	$e.Handled = $true
	Start-Process -FilePath $e.Source.DataContext.Path -ArgumentList """$( $Module.Path )"""
}

[System.Windows.Input.MouseEventHandler] $syncHash.Code.TblExpCmdMouseLeave = {
	$syncHash.Controls.TblExpCmdInfo.Text = ""
}

[System.Windows.Input.MouseEventHandler] $syncHash.Code.TblExpCmdMouseOver = {
	param ( $Sender, $e )

	if ( $null -ne $Sender.DataContext.Description )
	{
		$syncHash.Controls.TblExpCmdInfo.Text = $Sender.DataContext.Description
	}
	elseif ( $null -ne $Sender.DataContext.Dynopsis )
	{
		$syncHash.Controls.TblExpCmdInfo.Text = $Sender.DataContext.Synopsis
	}
	else
	{
		try
		{
			$FunctionName = $Sender.Text
			$cmd = Get-Command $FunctionName
			$path = $cmd.Module.Path
			$text = Get-Content $path -Raw

			$tokens = $null
			$errors = $null
			$ast = [System.Management.Automation.Language.Parser]::ParseInput( $text, [ref]$tokens, [ref]$errors )

			$funcAst = $ast.Find( {
				param( $node )

				$node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
				$node.Name -eq $FunctionName
			}, $true)

			if ( $funcAst )
			{
				$start = $funcAst.Extent.StartOffset
				$end = $funcAst.Extent.EndOffset
				$Info = GetScriptInfo -Text $text.Substring( $start, $end - $start )

				$t = if ( $null -eq $Info.Description )
				{
					$Info.Synopsis
				}
				else
				{
					$Info.Description
				}

				if ( $null -eq $t )
				{
					throw
				}
				$Sender.DataContext.PSObject.Properties.Add( [psnoteproperty]::new( "Description", $t ) )
				$syncHash.Controls.TblExpCmdInfo.Text = $t
			}
		}
		catch
		{
			$syncHash.Controls.TblExpCmdInfo.Text = $syncHash.Data.msgTable.ErrNoExpCmdDesc
		}
	}
}

Set-Localizations
Get-Data

# Create registry key value and save setting
$syncHash.Controls.ChbRunOnLogin.Add_Checked( {
	try
	{
		$SuiteScript = Get-Item "$( $syncHash.Root )\Script\$( $syncHash.Data.SuiteBaseName ).ps1"
		$Drive = Get-PSDrive | Where-Object { $SuiteScript.Directory.Root.Name -match $_.Name }
		if ( -not [string]::IsNullOrEmpty( $Drive.DisplayRoot ) )
		{
			$Root = $Drive.DisplayRoot
			$SuiteScriptPath = Join-Path $Root -ChildPath ( $SuiteScript.FullName.Replace( $SuiteScript.Directory.Root.Name , "" ) ).Replace( "\\dfs\", "" )
		}
		else
		{
			$Root = $Drive.Root
			$SuiteScriptPath = Join-Path $Root -ChildPath ( $SuiteScript.FullName.Replace( $SuiteScript.Directory.Root.Name , "" ) )
		}

		New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "StartSDValmeny" -PropertyType String -Value """C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"" -WindowStyle Hidden -File ""$( $SuiteScriptPath )"" $( $syncHash.Controls.Window.Language.IetfLanguageTag ) 1" -ErrorAction Stop
	}
	catch
	{
		if ( $_.Exception.Message -notmatch "already exists" )
		{
			Show-MessageBox -Text "$( $syncHash.Data.msgTable.ErrCreateLoginBatchFile ):`n$( $_.Exception.Message )" | Out-Null
		}
	}
	$syncHash.Data.SuiteSettings.RunsAtLogin = $true
} )

# Remove/disable setting
$syncHash.Controls.ChbRunOnLogin.Add_Unchecked( {
	Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "StartSDValmeny"
	$syncHash.Data.SuiteSettings.RunsAtLogin = $false
} )

# Initial setup
$syncHash.Controls.Window.Add_Loaded( {
	$syncHash.Controls.Window.Resources['CvsModules'].View.Refresh()
	$syncHash.Controls.Window.Resources['CvsQuickAccessWordList'].View.Refresh()
	$syncHash.Controls.ChbRunOnLogin.IsChecked = $syncHash.Data.SuiteSettings.RunsAtLogin
} )

Export-ModuleMember

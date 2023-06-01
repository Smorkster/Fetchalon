<#
.Syneopsis
	Administration of scripts, logs, etc.
.MeenuItem
	Administration of scripts, logs, etc.
.Description
	Performs administration of updates, logs, reports, etc.
.State
	Prod
.RequiredAdGroups
	Rol_Servicedesk_Backoffice
.AllowedUsers
	smorkster
.Author
	Smorkster (smorkster)
#>

Add-Type -AssemblyName PresentationFramework
$syncHash = $args[0]

function CheckForUpdates
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

function OpenFile
{
	<#
	.Synopsis
		Open the specified file/-s
	.Parameter FilePaths
		Array containing any file that is to be opened
	#>

	param ( [string[]] $FilePaths )

	$FilePaths | ForEach-Object { if ( Test-Path $_ ) { Start-Process $syncHash.Data.Editor "`"$_`"" } }
}

function ParseErrorlogs
{
	<#
	.Synopsis
		Parse errorlogs
	#>

	try { $syncHash.Jobs.PParseErrorLogs.EndInvoke( $syncHash.Jobs.HParseErrorLogs ) } catch {}
	$syncHash.Jobs.HParseErrorLogs = $syncHash.Jobs.PParseErrorLogs.BeginInvoke()
}

function ParseLogs
{
	<#
	.Synopsis
		Parse logfiles
	#>

	try { $syncHash.Jobs.PParseLogs.EndInvoke( $syncHash.Jobs.HParseLogs ) } catch {}
	$syncHash.Jobs.HParseLogs = $syncHash.Jobs.PParseLogs.BeginInvoke()
}

function ParseRollbacks
{
	<#
	.Synopsis
		Parse rollbacked files
	#>

	try { $syncHash.Jobs.PParseRollbacks.EndInvoke( $syncHash.Jobs.HParseRollBacks ) } catch {}
	$syncHash.Jobs.HParseRollBacks = $syncHash.Jobs.PParseRollbacks.BeginInvoke()
}

function PrepParsing
{
	<#
	.Synopsis
		Create powershell-objects and scripts for parsing
	#>

	$syncHash.Jobs.PParseErrorLogs = [powershell]::Create( [initialsessionstate]::CreateDefault() )
	$syncHash.Jobs.PParseErrorLogs.AddScript( {
		param ( $syncHash, $Modules )

		Import-Module $Modules

		$syncHash.Controls.Window.Dispatcher.Invoke( [action] {
			$syncHash.Controls.GridErrorlogsList.Visibility = [System.Windows.Visibility]::Collapsed
			$syncHash.Controls.PbParseErrorLogs.IsIndeterminate = $true
		} )
		$syncHash.Data.ErrorLoggs = Get-ChildItem "$( $syncHash.Data.BaseDir )\ErrorLogs" -Recurse -File -Filter "*.json" | Sort-Object Name
		$syncHash.Controls.PbParseErrorLogs.Maximum = [double] $syncHash.Data.ErrorLoggs.Count
		$syncHash.Controls.Window.Resources['CvsErrorLogsScriptNames'].Source.Clear()
		$syncHash.Data.ParsedErrorLogs.Clear()
		$syncHash.DC.PbParseErrorLogsOps[0] = 0.0
		$syncHash.DC.PbParseErrorLogs[0] = 0.0

		$syncHash.Controls.Window.Dispatcher.Invoke( [action] {
			$syncHash.Controls.PbParseErrorLogs.IsIndeterminate = $false
		} )
		$syncHash.Data.ErrorLoggs | ForEach-Object {
			$n = $_.BaseName -replace " - ErrorLog"
			if ( $syncHash.Data.ParsedErrorLogs.ScriptName -notcontains $n )
			{ $syncHash.Data.ParsedErrorLogs.Add( [pscustomobject]@{ ScriptName = $n ; ScriptErrorLogs = [System.Collections.ArrayList]::new() } ) }
			Get-Content $_.FullName | ForEach-Object { ( $syncHash.Data.ParsedErrorLogs.Where( { $_.ScriptName -eq $n } ) )[0].ScriptErrorLogs.Add( ( NewErrorLog ( $_ | ConvertFrom-Json ) ) ) }
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
		$syncHash.Data.ParsedLogsRecent.Clear()
		$a = Get-ChildItem "$( $syncHash.Data.BaseDir )\Logs" -Recurse -File -Filter "*log.json"
		$syncHash.Controls.Window.Dispatcher.Invoke( [action] {
			$syncHash.Controls.PbLogSearch.IsIndeterminate = $false
			$syncHash.Controls.PbLogSearch.Maximum = [double] $a.Count
			$syncHash.Controls.PbLogSearch.Value = 0.0
		} )

		$a | Sort-Object Name | ForEach-Object {
			$n = $_.BaseName -replace " - Log"
			if ( $syncHash.Data.ParsedLogs.ScriptName -notcontains $n )
			{
				[void] $syncHash.Data.ParsedLogs.Add( [pscustomobject]@{ ScriptName = $n ; ScriptLogs = [System.Collections.ArrayList]::new() } )
				[void] $syncHash.Data.ParsedLogsRecent.Add( [pscustomobject]@{ ScriptName = $n ; ScriptLogs = [System.Collections.ArrayList]::new() } )
			}
			Get-Content $_.FullName | ForEach-Object {
				$log = NewLog ( $_ | ConvertFrom-Json )
				[void] ( $syncHash.Data.ParsedLogs.Where( { $_.ScriptName -eq $n } ) )[0].ScriptLogs.Add( $log )
				if ( $log.LogDate -gt ( Get-Date ).AddDays( -7 ) )
				{ [void] ( $syncHash.Data.ParsedLogsRecent.Where( { $_.ScriptName -eq $n } ) )[0].ScriptLogs.Add( $log ) }
			}
			$syncHash.DC.PbLogSearch[0] += 1
		}

		$syncHash.Data.ParsedLogs | ForEach-Object { $_.ScriptLogs = [System.Collections.ArrayList]::new( @( $_.ScriptLogs | Sort-Object -Property LogDate -Descending ) ) }
		$syncHash.Controls.Window.Dispatcher.Invoke( [action] {
			$syncHash.Controls.Window.Resources['CvsCbLogsScriptNames'].Source = $syncHash.Data.ParsedLogs
			$syncHash.Controls.PbLogSearch.Visibility = [System.Windows.Visibility]::Collapsed
			$syncHash.Controls.Window.Resources['CvsCbLogsScriptNames'].View.Refresh()
		} )
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

		$syncHash.DC.TblUpdatesProgress[0] = $syncHash.Data.msgTable.StrCheckingUpdatesGetFiles
		Get-ChildItem $syncHash.Data.ProdRoot -Directory -Exclude ErrorLogs, Logs, Output, Development | `
			ForEach-Object {
				Get-ChildItem -Path $_ -Recurse -File | ForEach-Object { $ProdFiles.Add( $_ ) | Out-Null }
			}

		Get-ChildItem $syncHash.Data.DevRoot -Directory -Exclude ErrorLogs, Logs, Output, Tests | `
			ForEach-Object {
				Get-ChildItem -Path $_ -Recurse -File | ForEach-Object { $DevFiles.Add( $_ ) | Out-Null }
			}

		$syncHash.DC.PbParseUpdates[1] = [double] $DevFiles.Count

		$DevFiles | `
			ForEach-Object `
				-Begin {
					$syncHash.DC.TblUpdatesProgress[0] = "$( $syncHash.Data.msgTable.StrCheckingUpdatesCheckFiles ) 0 %"
					$MD5 = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
				} `
				-Process {
					try { Remove-Variable DFile, PFile, File, DevMD5, ProdMD5 -ErrorAction Stop } catch {}
					$DFile = $_

					$PFile = $ProdFiles | Where-Object { $_.Name -eq $DFile.Name } | Select-Object -First 1
					$DevMD5 = [System.BitConverter]::ToString( $MD5.ComputeHash( [System.IO.File]::ReadAllBytes( $DFile.FullName ) ) )
					try { $ProdMD5 = [System.BitConverter]::ToString( $MD5.ComputeHash( [System.IO.File]::ReadAllBytes( $PFile.FullName ) ) ) } catch {}

					if ( $DevMD5 -ne $ProdMD5 )
					{
						$File = [pscustomobject]@{
							DevFile = $DFile | Select-Object *
							New = $false
							ProdFile = $null
							ScriptInfo = $null
							ToolTip = ""
						}
						if ( $DFile.Extension -notmatch "psm*1" )
						{
							Add-Member -InputObject $File -MemberType NoteProperty -Name "SFile" -Value ( Get-ChildItem -Path "$( $syncHash.Data.DevRoot )" -Recurse -File -ErrorAction Stop | Where-Object { $_.BaseName -eq $DFile.BaseName -and $_.Extension -match "psm*1" } | Select-Object -First 1 -ExpandProperty FullName )
						}

						if ( $null -ne $PFile )
						{
							$File.ProdFile = $PFile | Select-Object *
						}
						else
						{
							$File.New = $true
						}
						$syncHash.Controls.Window.Dispatcher.Invoke( [action] {
							$syncHash.Controls.Window.Resources['CvsDgUpdates'].Source.Add( $File ) | Out-Null
						}, [System.Windows.Threading.DispatcherPriority]::Send )
					}

					$syncHash.DC.PbParseUpdates[0] += 1
					$syncHash.DC.TblUpdatesProgress[0] = "$( $syncHash.Data.msgTable.StrCheckingUpdatesCheckFiles ) $( [System.Math]::Round( ( $syncHash.DC.PbParseUpdates[0] / $syncHash.DC.PbParseUpdates[1] ) * 100 , 2 ) ) %"
				} `
			-End {
				try
				{
					Remove-Variable DFile, PFile, File, DevMD5, ProdMD5 -ErrorAction Stop
				} catch {}

				$syncHash.Controls.Window.Dispatcher.Invoke( [action] {
					$syncHash.Controls.Window.Resources['CvsDgUpdates'].View.Refresh()
				}, [System.Windows.Threading.DispatcherPriority]::Send )
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

function SetLocalizations
{
	<#
	.Synopsis
		Set localized strings
	#>

	$syncHash.Controls.Window.Resources['CvsErrorLogsScriptNames'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	$syncHash.Controls.Window.Resources['CvsDgFailedUpdates'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	$syncHash.Controls.Window.Resources['CvsDgErrorLogs'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	$syncHash.Controls.Window.Resources['CvsDgLogs'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	$syncHash.Controls.Window.Resources['CvsDgUpdatedInProd'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	$syncHash.Controls.Window.Resources['CvsDgUpdates'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	$syncHash.Controls.Window.Resources['CvsLvRollbackFileNames'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	$syncHash.Controls.Window.Resources['CvsCbLogsScriptNames'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()

	[System.Windows.Data.BindingOperations]::EnableCollectionSynchronization( $syncHash.Controls.Window.Resources['CvsCbLogsScriptNames'].View, $syncHash.Controls.CbLogsScriptNames )
	[System.Windows.Data.BindingOperations]::EnableCollectionSynchronization( $syncHash.Controls.Window.Resources['CvsDgUpdates'].View, $syncHash.Controls.DgUpdates )

	# Column headers for DgErrorLogs
	$syncHash.Controls.DgErrorLogs.Columns[0].Header = $syncHash.Data.msgTable.ContentDgErrorLogsColLogDate

	# Column headers for DgRollbacks
	$syncHash.Controls.DgRollbacks.Columns[0].Header = $syncHash.Data.msgTable.ContentDgRollbacksColFileName
	$syncHash.Controls.DgRollbacks.Columns[1].Header = $syncHash.Data.msgTable.ContentDgRollbacksColUpdated
	$syncHash.Controls.DgRollbacks.Columns[2].Header = $syncHash.Data.msgTable.ContentDgRollbacksColUpdatedBy
	$syncHash.Controls.DgRollbacks.Columns[3].Header = $syncHash.Data.msgTable.ContentDgRollbacksColType

	# Column headers for DgUpdates
	$syncHash.Controls.DgUpdates.Columns[0].Header = $syncHash.Data.msgTable.ContentDgUpdatesColName
	$syncHash.Controls.DgUpdates.Columns[1].Header = $syncHash.Data.msgTable.ContentDgUpdatesColDevUpd
	$syncHash.Controls.DgUpdates.Columns[2].Header = $syncHash.Data.msgTable.ContentDgUpdatesColNew
	$syncHash.Controls.DgUpdates.Columns[3].Header = $syncHash.Data.msgTable.ContentDgUpdatesColProdState

	# Column headers for DgLogs
	$syncHash.Controls.DgLogs.Columns[0].Header = $syncHash.Data.msgTable.ContentDgLogsColLogDate
	$syncHash.Controls.DgLogs.Columns[1].Header = $syncHash.Data.msgTable.ContentDgLogsColSuccess
	$syncHash.Controls.DgLogs.Columns[2].Header = $syncHash.Data.msgTable.ContentDgLogsColOperator

	# Column headers for DgFailedUpdates
	$syncHash.Controls.DgFailedUpdates.Columns[0].Header = $syncHash.Data.msgTable.ContentDgFailedUpdatesColName
	$syncHash.Controls.DgFailedUpdates.Columns[1].Header = $syncHash.Data.msgTable.ContentDgFailedUpdatesColUpdateAnyway
	$syncHash.Controls.DgFailedUpdates.Columns[2].Header = $syncHash.Data.msgTable.ContentDgFailedUpdatesColWritesToLog
	$syncHash.Controls.DgFailedUpdates.Columns[3].Header = $syncHash.Data.msgTable.ContentDgFailedUpdatesColScriptInfo
	$syncHash.Controls.DgFailedUpdates.Columns[4].Header = $syncHash.Data.msgTable.ContentDgFailedUpdatesColObsoleteFunctions
	$syncHash.Controls.DgFailedUpdates.Columns[5].Header = $syncHash.Data.msgTable.ContentDgFailedUpdatesColInvalidLocalizations
	$syncHash.Controls.DgFailedUpdates.Columns[6].Header = $syncHash.Data.msgTable.ContentDgFailedUpdatesColOrphandLocalizations
	$syncHash.Controls.DgFailedUpdates.Columns[7].Header = $syncHash.Data.msgTable.ContentDgFailedUpdatesColTODOs

	# Eventhandler to open file that failed to update
	$syncHash.Controls.Window.Resources['BtnOpenFailedUpdatedFile'].Setters.Where( { $_.Event.Name -match "Click" } )[0].Handler = $syncHash.Code.OpenFailedUpdatedFile

	# Button to open file that failed to update
	$syncHash.Controls.DgFailedUpdates.Resources['BtnOpenFailedContent'] = $syncHash.Data.msgTable.ContentBtnOpenFailed

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

	#$syncHash.Controls.DiffWindow.Resources['DiffRowRemoved'] = $syncHash.Data.msgTable.StrDiffRowRemoved # Text for row that was removed
	#$syncHash.Controls.DiffWindow.Resources['DiffRowAdded'] = $syncHash.Data.msgTable.StrDiffRowAdded # Text for row that have been added
	$syncHash.Controls.Window.Resources['FailedTestCount'] = "$( $syncHash.Data.msgTable.StrFailedTestCount ): " # Text for number of failed tests
	$syncHash.Controls.Window.Resources['NewFileTitle'] = $syncHash.Data.msgTable.StrNewFileTitle # Text for indicating the file is new and not present in production
	$syncHash.Controls.Window.Resources['LogSearchNoType'] = $syncHash.Data.msgTable.StrLogSearchNoType # Text for indicating the file is new and not present in production
}

function ShowDiffWindow
{
	<#
	.Synopsis
		Open window to display difference between files
	#>

	if ( $syncHash.Controls.TbUpdated.SelectedIndex -eq 0 ) { $LvItem = $syncHash.Controls.DgUpdates.SelectedItem }
	else { $LvItem = $syncHash.Controls.DgUpdatedInProd.SelectedItem }
	$a = Get-Content $LvItem.DevPath
	$b = Get-Content $LvItem.ProdPath
	$c = Compare-Object $a $b -PassThru

	$syncHash.DiffList = foreach ( $DiffLine in ( $c.ReadCount | Select-Object -Unique | Sort-Object ) )
	{
		$DevLine = try { ( $c.Where( { $_.ReadCount -eq $DiffLine -and $_.SideIndicator -eq "<=" } ) )[0].Trim() } catch { "" }
		$ProdLine = try { ( $c.Where( { $_.ReadCount -eq $DiffLine -and $_.SideIndicator -eq "=>" } ) )[0].Trim() } catch { "" }

		[pscustomobject]@{ DevLine = $DevLine; ProdLine = $ProdLine; LineNr = $DiffLine }
	}

	$syncHash.Controls.DiffWindow.DataContext.DiffInfo = [pscustomobject]@{ DiffList = $syncHash.DiffList ; DevPath = $LvItem.DevPath ; ProdPath = $LvItem.ProdPath }
	$syncHash.Controls.DiffWindow.Visibility = [System.Windows.Visibility]::Visible
	WriteLog -Text $syncHash.Data.msgTable.LogOpenDiffWindow -UserInput ( [string]( $LvItem.DevPath, $LvItem.ProdPath ) ) -Success $true
}

function TestLocalizations
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

	Import-LocalizedData -BindingVariable LocalizationData -UICulture $syncHash.Data.CultureInfo.CurrentCulture.Name -BaseDirectory "$( $syncHash.Data.DevRoot )\Localization\" -FileName $File.DevFile.BaseName
	Import-LocalizedData -BindingVariable MainScriptLocalizationData -UICulture $syncHash.Data.CultureInfo.CurrentCulture.Name -BaseDirectory "$( $syncHash.Data.DevRoot )\Localization\" -FileName "Fetchalon"

	if ( $File.DevFile.Extension -match "(psm*1)|(xaml)" )
	{
		if ( $File.DevFile.BaseName -match "PropHandlers" )
		{
			Import-LocalizedData -BindingVariable MainScriptLocalizationData -UICulture $syncHash.Data.CultureInfo.CurrentCulture.Name -BaseDirectory "$( $syncHash.Data.DevRoot )\Localization\" -FileName "Fetchalon"

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

			[regex]::Matches( ( Get-Content $File.DevFile.FullName ), "Int[Mm]sgTable\.(?<Key>\w+(?<!Keys))\b" ) | `
				ForEach-Object {
					if ( $LocalizationData.Keys -notcontains $_.Groups['Key'].Value )
					{
						$InvalidLocs.Add( $_.Groups['Key'].Value ) | Out-Null
					}
				}
		}
		else
		{
			Get-Item $File.DevFile.FullName | `
				Select-String "[Mm]sgTable\.\w+(?<!Keys)\b" | `
				ForEach-Object {
					$LineMatch = $_
					[regex]::Matches( $_.Line , "[Mm]sgTable\.(?<LocVar>\w+)\b" ) | `
					ForEach-Object {
						if ( $LocalizationData.Keys -notcontains $_.Groups['LocVar'].Value )
						{
							$InvalidLocs.Add( [pscustomobject]@{ ScVar = $_.Groups['LocVar'].Value ; ScLine = $LineMatch.Line ; ScLineNr = $LineMatch.linenumber } ) | Out-Null
						}
					}
				}
		}
	}
	if ( $File.DevFile.Extension -eq ".psd1" )
	{
		$ScriptFile = Get-ChildItem -Path $syncHash.Data.BaseDir -Exclude "Rollback", "Logs", "ErrorLogs", "Output", "Tests" | ForEach-Object { Get-ChildItem -Path $_.FullName -Filter "$( $File.DevFile.BaseName )*" -Recurse | Where-Object { $_.Extension -match "psm*1" } }
		$XamlFile = Get-ChildItem -Path $syncHash.Data.BaseDir -Exclude "Rollback", "Logs", "ErrorLogs", "Output", "Tests" | ForEach-Object { Get-ChildItem -Path $_.FullName -Filter "$( $File.DevFile.BaseName ).xaml" -Recurse }

		# Check that if any key in localization-file is not present in the scriptfile or Xaml-file
		foreach ( $Key in $LocalizationData.Keys )
		{
			try { Remove-Variable UsedInScript, UsedInXaml -ErrorAction SilentlyContinue } catch {}
			$UsedInScript = $false
			$UsedInXaml = $false

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

			if ( ( -not $UsedInScript ) -and ( -not $UsedInXaml ) )
			{
				$OrphandLocs.Add( $Key ) | Out-Null
			}
		}
	}

	return $OrphandLocs, $InvalidLocs
}

function TestScript
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
		$Test.OrphandLocalizations, $Test.InvalidLocalizations = TestLocalizations $File
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
		$Script | Select-String -Pattern "#\s*\bTODO\b" | ForEach-Object { $Test.TODOs.Add( $_ ) | Out-Null }
	}

	if ( $Test.ObsoleteFunctions.Count -ne 0 ) { $Test.FailedTestCount++ }
	if ( -not $Test.WritesToLog ) { $Test.FailedTestCount++ }
	if ( $Test.OrphandLocalizations.Count -ne 0 ) { $Test.FailedTestCount++ }
	if ( $Test.InvalidLocalizations.Count -ne 0 ) { $Test.FailedTestCount++ }
	if ( $null -eq $File.ScriptInfo ) { $Test.FailedTestCount++ }
	if ( $Test.MissingScriptInfo.Count -gt 0 ) { $Test.FailedTestCount++ }
	if ( $Test.TODOs.Count -ne 0 ) { $Test.FailedTestCount++ }

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

function UncheckOtherRollbackFilters
{
	param (
		[string] $Checked
	)

	$syncHash.GetEnumerator() | Where-Object { $_.Key -match "CbRollbackFilterType" -and $_.Key -notmatch ".*$Checked" } | ForEach-Object { $_.Value.IsChecked = $false }
}

function UnselectDatagrid
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

function UpdateFiles
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
				$FileTest = TestScript $file
				if ( $FileTest.FailedTestCount -eq 0 )
				{ $FilesToUpdate += $file }
				else
				{ $syncHash.Controls.Window.Resources['CvsDgFailedUpdates'].Source.Add( $FileTest ) }
			}
			else
			{ $FilesToUpdate += $file }
		}
	}
	# Tab for failed updates have focus
	elseif ( $syncHash.Controls.TbUpdated.SelectedIndex -eq 1 )
	{
		$FilesToUpdate = @( $syncHash.Controls.DgFailedUpdates.Items | Where-Object { $_.UpdateAnyway -and $_.AllowUpdateAnyway } | Select-Object -ExpandProperty File )
	}

	foreach ( $file in $FilesToUpdate )
	{
		$OFS = "`n"
		if ( $file.New )
		{
			New-Item -ItemType File -Path "$( $file.DevFile.FullName -replace "Development\\" )" -Force
			Copy-Item -Path $file.DevFile.FullName -Destination "$( $file.DevFile.FullName -replace "Development\\" )" -Force
		}
		else
		{
			$RollbackPath = "$( $syncHash.Data.RollbackRoot )\$( ( Get-Date ).Year )\$( ( Get-Date ).Month )\"
			$RollbackName = "$( $file.ProdFile.Name ) ($( $syncHash.Data.msgTable.StrRollbackName ) $( Get-Date $file.ProdFile.LastWriteTime -Format $syncHash.Data.CultureInfo.DateTimeFileStringFormat ), $( $env:USERNAME ))$( $file.ProdFile.Extension )" -replace ":","."
			$RollbackValue = [string]( Get-Content -Path $file.ProdFile.FullName -Encoding UTF8 )
			$OutputEncoding = ( New-Object System.Text.UnicodeEncoding $False, $False ).psobject.BaseObject
			New-Item -Path $RollbackPath -Name $RollbackName -ItemType File -Value $RollbackValue -Force | Out-Null
			Copy-Item -Path $file.DevFile.FullName -Destination $file.ProdFile.FullName -Force
		}
		$syncHash.Updated += $file
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
		foreach ( $file in $FilesToUpdate )
		{
			$UpdatedFile = $syncHash.Controls.Window.Resources['CvsDgFailedUpdates'].Source.Where( { $_.File.DevFile.FullName -eq $file.DevFile.FullName } )[0]
			$syncHash.Controls.Window.Resources['CvsDgFailedUpdates'].Source.Remove( $UpdatedFile )
		}
		$syncHash.Controls.Window.Resources['CvsDgFailedUpdates'].View.Refresh()

		if ( $syncHash.Controls.Window.Resources['CvsDgFailedUpdates'].Source.Count -eq 0 )
		{
			$syncHash.Controls.TbUpdated.SelectedIndex = 0
		}
	}
	$syncHash.DC.TblInfo[0] = [System.Windows.Visibility]::Collapsed
}

######################### Script start
$controls = [System.Collections.ArrayList]::new( @(
@{ CName = "BtnDoRollback" ; Props = @( @{ PropName = "IsEnabled" ; PropVal = $false } ) },
@{ CName = "BtnOpenRollbackFile" ; Props = @( @{ PropName = "IsEnabled" ; PropVal = $false } ) },
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

[System.Windows.RoutedEventHandler] $syncHash.Code.OpenFailedUpdatedFile =
{
	$syncHash.Data.Test = $args
	OpenFile $args[0].DataContext.File.DevFile.FullName
}

PrepParsing
SetLocalizations

$syncHash.Data.ParsedLogs = [System.Collections.ObjectModel.ObservableCollection[Object]]::new()
$syncHash.Data.ParsedLogsRecent = [System.Collections.ObjectModel.ObservableCollection[Object]]::new()
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

# Start a check for any updates
$syncHash.Controls.BtnCheckForUpdates.Add_Click( { CheckForUpdates } )

# Copy the information for the currently selected error
$syncHash.Controls.BtnCopyErrorInfo.Add_Click( {
	$OutputEncoding = ( New-Object System.Text.UnicodeEncoding $False, $False ).psobject.BaseObject
	$syncHash.Controls.GridErrorInfo.DataContext | Clip
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

# Reset the controls for Errorlogs
$syncHash.Controls.BtnClearErrorLogSearch.Add_Click( {
	$syncHash.Controls.BtnClearErrorLogSearch.Visibility = [System.Windows.Visibility]::Collapsed
	$syncHash.Controls.CbErrorLogSearchType.SelectedIndex = -1
	$syncHash.Controls.TbErrorLogSearchText.Text = ""
	$syncHash.Controls.Window.Resources['CvsErrorLogsScriptNames'].Source.Clear()
	$syncHash.Data.ParsedErrorLogs | ForEach-Object { $syncHash.Controls.Window.Resources['CvsErrorLogsScriptNames'].Source.Add( $_ ) }
} )

# Reset the controls for logs
$syncHash.Controls.BtnClearLogSearch.Add_Click( {
	$syncHash.Controls.BtnClearLogSearch.Visibility = [System.Windows.Visibility]::Collapsed
	$syncHash.Controls.CbLogSearchType.SelectedIndex = -1
	$syncHash.Controls.TbLogSearchText.Text = ""
	$syncHash.Controls.Window.Resources['CvsLogsScriptNames'].Source.Clear()
	$syncHash.Data.ParsedLogs | ForEach-Object { $syncHash.Controls.Window.Resources['CvsLogsScriptNames'].Source.Add( $_ ) }
} )

# Open the Dev-version of the file
$syncHash.Controls.BtnDiffOpenDev.Add_Click( { OpenFile $syncHash.Controls.DiffWindow.DataContext.DiffInfo.DevPath } )

# Open the Prod-version of the file
$syncHash.Controls.BtnDiffOpenProd.Add_Click( { OpenFile $syncHash.Controls.DiffWindow.DataContext.DiffInfo.ProdPath } )

# Open both versions of the file
$syncHash.Controls.BtnDiffOpenBoth.Add_Click( { OpenFile $syncHash.Controls.DiffWindow.DataContext.DiffInfo.DevPath, $syncHash.Controls.DiffWindow.DataContext.DiffInfo.ProdPath } )

# Close the window
$syncHash.Controls.BtnDiffCancel.Add_Click( {
	$syncHash.Controls.DiffWindow.Visibility = [System.Windows.Visibility]::Hidden
	$syncHash.Controls.DiffWindow.DataContext.DiffInfo = $null
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

# Search the errorlogs for entered data
$syncHash.Controls.BtnErrorLogSearch.Add_Click( {
	$syncHash.Controls.BtnClearErrorLogSearch.Visibility = [System.Windows.Visibility]::Visible
	$syncHash.Controls.Window.Resources['CvsErrorLogsScriptNames'].Source.Clear()
	$syncHash.Data.ParsedErrorLogs | Where-Object { $_.ScriptErrorLogs.( $syncHash.Controls.CbErrorLogSearchType.SelectedItem.Content ) -match $syncHash.Controls.TbErrorLogSearchText.Text } | ForEach-Object { $syncHash.Controls.Window.Resources['CvsErrorLogsScriptNames'].Source.Add( $_ ) }
} )

# List rollbacks
$syncHash.Controls.BtnListRollbacks.Add_Click( { ParseRollbacks } )

# Search the logs for entered data
$syncHash.Controls.BtnLogSearch.Add_Click( {
	$syncHash.Controls.BtnClearLogSearch.Visibility = [System.Windows.Visibility]::Visible
	$syncHash.Controls.Window.Resources['CvsLogsScriptNames'].Source.Clear()
	$syncHash.Data.ParsedLogs | Where-Object { $_.ScriptLogs.( $syncHash.Controls.CbLogSearchType.SelectedItem.Content ) -match $syncHash.Controls.TbLogSearchText.Text } | ForEach-Object { $syncHash.Controls.Window.Resources['CvsLogsScriptNames'].Source.Add( $_ ) }
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

# Open the outputfile
$syncHash.Controls.BtnOpenOutputFile.Add_Click( { OpenFile $syncHash.Controls.CbLogOutputFiles.SelectedItem } )

# Open meny to include other data
$syncHash.Controls.BtnOpenPopupCopyLogInfo.Add_Click( { $syncHash.Controls.PopupCopyLogInfo.IsOpen = -not $syncHash.Controls.PopupCopyLogInfo.IsOpen } )

# Open the selected previous version
$syncHash.Controls.BtnOpenRollbackFile.Add_Click( { OpenFile $syncHash.Controls.DgRollbacks.SelectedItem.File.FullName } )

# Parse errorlogs and load the data
$syncHash.Controls.BtnReadErrorLogs.Add_Click( { ParseErrorlogs } )

# Parse all logs and load the data
$syncHash.Controls.BtnReadLogs.Add_Click( { ParseLogs } )

$syncHash.Controls.BtnUpdatedInProdOpenDiffs.Add_Click( { ShowDiffWindow } )
$syncHash.Controls.BtnUpdatedInProdOpenDevFile.Add_Click( { OpenFile $syncHash.Controls.DgUpdatedInProd.SelectedItem.DevPath } )
$syncHash.Controls.BtnUpdatedInProdOpenProdFile.Add_Click( { OpenFile $syncHash.Controls.DgUpdatedInProd.SelectedItem.ProdPath } )
$syncHash.Controls.BtnUpdatedInProdOpenBothFiles.Add_Click( { OpenFile ( $syncHash.Controls.DgUpdatedInProd.SelectedItem.psobject.Properties | Where-Object { $_.Name -match "^[^R].+Path$" } | Select-Object -ExpandProperty Value ) } )
$syncHash.Controls.BtnUpdatesOpenDiff.Add_Click( { ShowDiffWindow } )
$syncHash.Controls.BtnUpdatesOpenDevFile.Add_Click( { OpenFile $syncHash.Controls.DgUpdates.SelectedItem.DevFile.FullName } )
$syncHash.Controls.BtnUpdatesOpenProdFile.Add_Click( { OpenFile $syncHash.Controls.DgUpdates.SelectedItem.ProdFile.FullName } )
$syncHash.Controls.BtnUpdatesOpenBothFiles.Add_Click( { OpenFile ( "Dev", "Prod" | ForEach-Object { $syncHash.Controls.DgUpdates.SelectedItem."$( $_ )File".FullName } ) } )

# Update selected files
$syncHash.Controls.BtnUpdateScripts.Add_Click( { UpdateFiles } )

# Update failed updates that have been checked
$syncHash.Controls.BtnUpdateFailedScripts.Add_Click( {
	if ( @( $syncHash.Controls.DgFailedUpdates.Items | Where-Object { $_.UpdateAnyway -match $true } ).Count -eq 0 )
	{
		Show-MessageBox -Text $syncHash.Data.msgTable.StrNoFailedSelected
	}
	else
	{
		UpdateFiles
	}
} )

# These checkboxes sets datagridrows visible or collapsed
$syncHash.Controls.CbShowDevFiles.Add_Checked( { $syncHash.Controls.Window.Resources['DevFilesVisible'] = [System.Windows.Visibility]::Visible } )
$syncHash.Controls.CbShowDevFiles.Add_Unchecked( { $syncHash.Controls.Window.Resources['DevFilesVisible'] = [System.Windows.Visibility]::Collapsed } )
$syncHash.Controls.CbRollbackFilterTypePs1.Add_Checked( { $syncHash.Controls.Window.Resources['RollbackRowPs1Visible'] = [System.Windows.Visibility]::Visible } )
$syncHash.Controls.CbRollbackFilterTypePs1.Add_Unchecked( { $syncHash.Controls.Window.Resources['RollbackRowPs1Visible'] = [System.Windows.Visibility]::Collapsed } )
$syncHash.Controls.CbRollbackFilterTypePs1.Add_MouseRightButtonDown( {
	$this.IsChecked = $true
	UncheckOtherRollbackFilters $this.Content
} )
$syncHash.Controls.CbRollbackFilterTypePsd1.Add_Checked( { $syncHash.Controls.Window.Resources['RollbackRowPsd1Visible'] = [System.Windows.Visibility]::Visible } )
$syncHash.Controls.CbRollbackFilterTypePsd1.Add_Unchecked( { $syncHash.Controls.Window.Resources['RollbackRowPsd1Visible'] = [System.Windows.Visibility]::Collapsed } )
$syncHash.Controls.CbRollbackFilterTypePsd1.Add_MouseRightButtonDown( {
	$this.IsChecked = $true
	UncheckOtherRollbackFilters $this.Content
} )
$syncHash.Controls.CbRollbackFilterTypePsm1.Add_Checked( { $syncHash.Controls.Window.Resources['RollbackRowPsm1Visible'] = [System.Windows.Visibility]::Visible } )
$syncHash.Controls.CbRollbackFilterTypePsm1.Add_Unchecked( { $syncHash.Controls.Window.Resources['RollbackRowPsm1Visible'] = [System.Windows.Visibility]::Collapsed } )
$syncHash.Controls.CbRollbackFilterTypePsm1.Add_MouseRightButtonDown( {
	$this.IsChecked = $true
	UncheckOtherRollbackFilters $this.Content
} )
$syncHash.Controls.CbRollbackFilterTypeTxt.Add_Checked( { $syncHash.Controls.Window.Resources['RollbackRowTxtVisible'] = [System.Windows.Visibility]::Visible } )
$syncHash.Controls.CbRollbackFilterTypeTxt.Add_Unchecked( { $syncHash.Controls.Window.Resources['RollbackRowTxtVisible'] = [System.Windows.Visibility]::Collapsed } )
$syncHash.Controls.CbRollbackFilterTypeTxt.Add_MouseRightButtonDown( {
	$this.IsChecked = $true
	UncheckOtherRollbackFilters $this.Content
} )
$syncHash.Controls.CbRollbackFilterTypeXaml.Add_Checked( { $syncHash.Controls.Window.Resources['RollbackRowXamlVisible'] = [System.Windows.Visibility]::Visible } )
$syncHash.Controls.CbRollbackFilterTypeXaml.Add_Unchecked( { $syncHash.Controls.Window.Resources['RollbackRowXamlVisible'] = [System.Windows.Visibility]::Collapsed } )
$syncHash.Controls.CbRollbackFilterTypeXaml.Add_MouseRightButtonDown( {
	$this.IsChecked = $true
	UncheckOtherRollbackFilters $this.Content
} )
$syncHash.Controls.CbLogsFilterSuccessFailed.Add_Checked( { $syncHash.Controls.Window.Resources['LogskRowFailedVisible'] = [System.Windows.Visibility]::Visible } )
$syncHash.Controls.CbLogsFilterSuccessFailed.Add_Unchecked( { $syncHash.Controls.Window.Resources['LogskRowFailedVisible'] = [System.Windows.Visibility]::Collapsed } )
$syncHash.Controls.CbLogsFilterSuccessSuccess.Add_Checked( { $syncHash.Controls.Window.Resources['LogskRowSuccessVisible'] = [System.Windows.Visibility]::Visible } )
$syncHash.Controls.CbLogsFilterSuccessSuccess.Add_Unchecked( { $syncHash.Controls.Window.Resources['LogskRowSuccessVisible'] = [System.Windows.Visibility]::Collapsed } )

$syncHash.Controls.CbLogsScriptNames.Add_SelectionChanged( {
	$syncHash.Controls.Window.Resources['CvsDgLogs'].Source = $this.SelectedItem.ScriptLogs
} )

$syncHash.Controls.CbErrorLogsScriptNames.Add_SelectionChanged( {
	$this.SelectedItem.ScriptErrorLogs | ForEach-Object { $syncHash.Controls.Window.Resources['CvsDgErrorLogs'].Source.Add( $_ ) }
} )

# Click was made outside of rows and valid cells, unselect selected rows
$syncHash.Controls.DgErrorLogs.Add_MouseLeftButtonUp( { UnselectDatagrid $args[1].OriginalSource $this } )
$syncHash.Controls.DgLogs.Add_MouseLeftButtonUp( { UnselectDatagrid $args[1].OriginalSource $this } )
$syncHash.Controls.DgRollbacks.Add_MouseLeftButtonUp( { UnselectDatagrid $args[1].OriginalSource $this } )

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
			# TODO Remove
			$syncHash.Data.TestError = [pscustomobject]@{ E = $_ ; P = $syncHash.Data.DevRoot ; F = $f ; BN = $args[1].Row.DataContext.DevFile.BaseName }
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

$syncHash.Controls.DgUpdates.Add_MouseLeftButtonUp( { UnselectDatagrid $args[1].OriginalSource $this } )

# If rightclick is used, open the file from dev and prod
$syncHash.Controls.DgUpdates.Add_MouseRightButtonUp( {
	if ( ( $args[1].OriginalSource.GetType() ).Name -eq "TextBlock" )
	{
		OpenFile ( $this.CurrentItem.psobject.Properties | Where-Object { $_.name -match "^[^R].+Path$" } | Select-Object -ExpandProperty Value )
	}
} )

# Activate button to update files, if any item is selected
$syncHash.Controls.DgRollbacks.Add_SelectionChanged( { $syncHash.DC.BtnOpenRollbackFile[0] = $syncHash.DC.BtnDoRollback[0] = $this.SelectedItem -ne $null } )

$syncHash.Controls.DgUpdatedInProd.Add_MouseLeftButtonUp( { UnselectDatagrid $args[1].OriginalSource $this } )

# If rightclick is used, open the file from dev and prod
$syncHash.Controls.DgUpdatedInProd.Add_MouseRightButtonUp( {
	ShowDiffWindow $this.CurrentItem
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

# Set binding to all logs
$syncHash.Controls.RbLogsDisplayPeriodAll.Add_Checked( {
	#$b = [System.Windows.Data.Binding]@{ ElementName = "CbLogsScriptNames"; Path = "SelectedItem.ScriptLogs" }
	#[void][System.Windows.Data.BindingOperations]::SetBinding( $syncHash.Controls.DgLogs, [System.Windows.Controls.DataGrid]::ItemsSourceProperty, $b )
} )

# Set binding to recent logs
$syncHash.Controls.RbLogsDisplayPeriodRecent.Add_Checked( {
	#$b = [System.Windows.Data.Binding]@{ ElementName = "CbLogsScriptNames"; Path = "SelectedItem.ScriptLogsRecent" }
	#[void][System.Windows.Data.BindingOperations]::SetBinding( $syncHash.Controls.DgLogs, [System.Windows.Controls.DataGrid]::ItemsSourceProperty, $b )
} )

# Window rendered, do some final preparations
$syncHash.Controls.Window.Add_Loaded( {
	$this.Resources['DiffWindow'].DataContext = [pscustomobject]@{
		MsgTable = $syncHash.msgTable
		DiffInfo = $null
	}

	# Get a list of obsolete functions in modules
	$syncHash.ObsoleteFunctions = ( Get-Module ).Where( { $_.Path.StartsWith( $BaseDir ) } ) | `
		ForEach-Object { Get-Command -Module $_.Name } | `
		Where-Object { $_.Definition -match "\[Obsolete.+\]" } | `
		Select-Object -Property `
			@{ Name = "FunctionName"; Expression = { $_.Name } }, `
			@{ Name = "HelpMessage"; Expression = { ( ( ( $_.Definition -split "`n" | Select-String -Pattern "\[Obsolete.+\]" ) -split "\(" )[1] -split "\)" )[0].Trim() } }
} )

# Catch keypress
$syncHash.Controls.Window.Add_KeyDown( {
	$syncHash.TempKeyDown += $args
	if ( $args[1].Key -eq "F1" )
	{
		switch ( $syncHash.Controls.TbAdmin.SelectedIndex )
		{
			0 { CheckForUpdates }
			1 { ParseLogs }
			2 { ParseErrorlogs }
			3 { ParseRollbacks }
		}
	}
	elseif ( ( -not $syncHash.Controls.TbLogSearchText.IsFocused ) -and ( -not $syncHash.Controls.TbErrorLogSearchText.IsFocused ) )
	{
		if     ( $args[1].Key -eq "D1" ) { $syncHash.Controls.TbAdmin.SelectedIndex = 0 }
		elseif ( $args[1].Key -eq "D2" ) { $syncHash.Controls.TbAdmin.SelectedIndex = 1 }
		elseif ( $args[1].Key -eq "D3" ) { $syncHash.Controls.TbAdmin.SelectedIndex = 2 }
		elseif ( $args[1].Key -eq "D4" ) { $syncHash.Controls.TbAdmin.SelectedIndex = 3 }
		elseif ( $args[1].Key -eq "D5" ) { $syncHash.Controls.TbAdmin.SelectedIndex = 4 }
	}
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
	$syncHash.Controls.BtnDiffOpenDev.IsEnabled = $null -ne $this.DataContext.DiffInfo.DevPath
	$syncHash.Controls.BtnDiffOpenProd.IsEnabled = $null -ne $this.DataContext.DiffInfo.ProdPath
	$syncHash.Controls.BtnDiffOpenBoth.IsEnabled = $null -ne $this.DataContext.DiffInfo.ProdPath -and $null -ne $this.DataContext.DiffInfo.DevPath
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
		$this.DataContext.DiffInfo = $null
	}
} )

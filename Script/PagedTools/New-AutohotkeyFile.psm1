<#
.Description
	Creates an AutoHotKey script file based on a template with existing data. The file is then placed in the user home directory.
.MenuItem
	Create AutoHotKey-file
.Synopsis
	Create AutoHotKey-file from default template
.State
	Prod
.Author
	Smorkster (smorkster)
#>

Add-Type -AssemblyName PresentationFramework
$syncHash = $args[0]

function Add-OpMessage
{
	<#
	.Synopsis
		Post message to designate messagequeue (ObjectType)
	.Parameter Message
		The message to post
	.Parameter Type
		Type of message
	.Parameter ObjectType
		For what type of object is the message representing. This is specified since there are specific areas for each type of object.
	.Parameter Clear
		Specified if messagequeue is to be cleared of previous messages before posting the new message.
	#>

	param (
		$Message,
	[ValidateSet( "Info", "Success", "Warning", "Error" )]
		$Type,
	[ValidateSet( "Hotstring", "Function", "FileInfo", "Extraction", "Variable", "Hotkey", "Import", "Settings" )]
		$ObjectType,
		[switch] $Clear
	)

	if ( $Clear )
	{
		$syncHash.Controls.Window.Resources."Cvs$( $ObjectType )MessageQueue".Source.Clear()
	}

	if ( $Message )
	{
		$syncHash.Controls.Window.Resources."Cvs$( $ObjectType )MessageQueue".Source.Add( ( [pscustomobject]@{
			OpTime = Get-Date
			Message = $Message
			Type = $Type
		} ) )
	}
}

function Add-FilePaths
{
	<#
	.Synopsis
		Add a path to collection of path suggestions for where to write files under 'other location'.
	.Parameter Path
		Path to add
	#>

	param (
		$Path
	)

	$syncHash.Controls.Window.Resources.CvsSettingsFiles.Source.Where( { $_.Name -match "Path$" } ) | `
		ForEach-Object {
			if ( $_.Suggestions -notcontains $Path )
			{
				$_.Suggestions.Add( $Path )
			}
			$_.Value = $Path
		}
}

function Read-XmlFile
{
	<#
	.Synopsis
		Read an XML-file with old deprecated format.
	.Parameter Path
		Path for the file to read.
	#>

	param (
		$Path
	)

	Add-OpMessage -Message $syncHash.Data.msgTable.StrImpInfoExcludedItems -Type "Error" -ObjectType "Import" -Clear

	$a = [xml] ( Get-Content $Path )

	$a.ahk.ChildNodes | `
		Where-Object { $_.Name -notmatch "(Changelog)|(Settings)" } | `
		ForEach-Object {
			$TopNode = "$( ( Get-Culture ).TextInfo.ToTitleCase( $_.Name ) )"

			$_.ChildNodes | `
				Where-Object { $_.Name -ne "setting" } | `
				ForEach-Object {
					if ( $_.Name -eq "variable" )
					{
						$Item = [pscustomobject]@{
							Name = $_.variablename
							Value = $_.innertext
							VariableType = "Legacy"
						}
					}
					elseif ( $_.Name -eq "hotstring" )
					{
						$Item = [pscustomobject]@{
							Name = $_.hotstringName
							System = $_.hotstringSystem
							MenuTitle = $_.hotstringMenuTitle
							Value = $_.innertext
							IsAdvanced = ( $_.innertext -match "(?m)^PrintText\(text\)$" )
						}
					}
					elseif ( $_.Name -eq "function" )
					{
						$Item = [pscustomobject]@{
							Name = $_.functionName
							FunctionCode = $_.innertext
							ParameterList = [System.Collections.ArrayList]::new()
						}
						$a = [regex]::Matches( $Item.FunctionCode , "^$( $Item.Name )\s*\((?<pl>.*)\).*\n" )
						$a[0].Groups['pl'].Value -split "," | `
							ForEach-Object {
								$Item.ParameterList.Add( ( [pscustomobject]@{
									Name = $_
								} ) ) | Out-Null
							}
					}

					if ( $null -ne $Item )
					{
						Add-Member -InputObject $Item -MemberType NoteProperty -Name "ImportThis" -Value $true
						Add-Member -InputObject $Item -MemberType NoteProperty -Name "Comment" -Value ""
						$syncHash.Controls.Window.Resources."CvsImport$( $TopNode )".Source.Add( $Item )
					}
					$Item = $null
				}
		}
}

function Edit-HotstringSystems
{
	<#
	.Synopsis
		Function to edit list of systems for hotstrings
	.Parameter NewSystem
		System to edit.
	#>

	param (
		$NewSystem
	)

	if ( $syncHash.Controls.Window.Resources.SystemList -notcontains $NewSystem )
	{
		$syncHash.Controls.Window.Resources.SystemList.Add( $NewSystem )
		"CvsHotstringListOfSystems", "CvsHotstringSystemList", "CvsHotstringSystemListNewObject" | `
			ForEach-Object {
				$syncHash.Controls.Window.Resources."$( $_ )".View.Refresh()
			}
	}
}

function Read-JsonFile
{
	<#
	.Synopsis
		Read Json-file to import AHK-data
	.Parameter Path
		Path of JSON-file
	#>

	param (
		$Path
	)

	$JObj = Get-Content -Path $Path | ConvertFrom-Json
	if ( ( $JObj | Get-Member -MemberType NoteProperty ).Name -match "^((Functions)|(Hotkeys)|(Hotstrings)|(Variables)|(Settings))$" -and `
		( $JObj.Settings.Name -match "(MenuShowTrigger)|(SaveWithGui)|(FileName)|(UserId)|(ScriptPath)|(BackupPath)|(TitleForMenu)|(TitleDividerCharacter)|(TitleForMenuTriggers)|(TitleForHotstrings)|(TitleForFunctions)|(TitleForVariables)" ).Count -eq 12
	)
	{
		$JObj | `
			Get-Member -MemberType NoteProperty | `
			Where-Object { $_.Name -match "^((Functions)|(Hotkeys)|(Hotstrings)|(Variables)|(Settings))$" } | `
			ForEach-Object `
				-Begin {
						$C = 0
					} `
				-Process {
					$TopName = $_.Name
					$JObj."$( $_.Name )" | `
						ForEach-Object {
							$NewItem = $_.psobject.Copy()
							Add-Member -InputObject $NewItem -MemberType NoteProperty -Name "ImportThis" -Value ( $TopName -ne "Settings" )

							if ( ( $NewItem | Get-Member -MemberType NoteProperty ).Name -notcontains "Comment" )
							{
								Add-Member -InputObject $NewItem -MemberType NoteProperty -Name "Comment" -Value ""
							}

							if ( $TopName -eq "Variables" -and ( $NewItem | Get-Member -MemberType NoteProperty ).Name -notcontains "VariableType" )
							{
								Add-Member -InputObject $NewItem -MemberType NoteProperty -Name "VariableType" -Value "Legacy"
							}

							$syncHash.Controls.Window.Resources."CvsImport$( $TopName )".Source.Add( $NewItem )
							$C += 1
						}
					$syncHash.Controls.Window.Resources."CvsImport$( $TopName )".View.Refresh()
					$syncHash.Controls."ChbImp$( $TopName )SelectAll".IsChecked = ( $TopName -ne "Settings" )
				} `
				-End {
					Add-OpMessage -Message "$( $syncHash.Data.msgTable.StrImpFinishedMsg ) $( $C )" -Type "Success" -ObjectType "Import" -Clear
				}
	}
	else
	{
		Add-OpMessage -Message $syncHash.Data.msgTable.ErrImpInfoJsonNotCorrectFormated -Type "Error" -ObjectType "Import" -Clear
	}

}

function Get-Setting
{
	<#
	.Synopsis
		Get setting from collectionview
	.Parameter SettingName
		Name of setting to fetch
	.Parameter SettingGroup
		Group type of setting, to specify what type of collectionview to fetch the setting from.
	#>

	param (
		$SettingName,
		$SettingGroup
	)

	return $syncHash.Controls.Window.Resources."CvsSettings$( $SettingGroup )".Source.Where( { $_.Name -eq $SettingName } ).Value
}

function New-ScriptFileSectionTitle
{
	<#
	.Synopsis
		Create a section title for the scriptfile.
	.Parameter TitleText
		Text to place in the titlearea
	#>

	param (
		$TitleText
	)

	$Title = ""
	$TitleDividerCharacter = Get-Setting "TitleDividerCharacter" "Settings"
	0..30 | `
		ForEach-Object `
		-Begin {
			$Title += "; "
		} `
		-Process {
			$Title += $TitleDividerCharacter
		}
	$Title = "$( $Title )`n; $( $TitleText )`n"
	0..30 | `
		ForEach-Object `
		-Begin {
			$Title += "; "
		} `
		-Process {
			$Title += $TitleDividerCharacter
		}

	return "$( $Title )`n"
}

function Set-Localizations
{
	<#
	.Synopsis
		Initialize collections and set some localized values
	#>

	"CvsFunctions", "CvsHotstrings", "CvsVariables", "CvsSettingsFiles", "CvsSettingsOperations", "CvsSettingsSettings", "CvsImportVariables", "CvsImportFunctions", "CvsToExtract", "CvsImportHotstrings", "CvsHotstringMessageQueue", "CvsVariableMessageQueue", "CvsFunctionMessageQueue", "CvsExtractionMessageQueue", "CvsFileInfoMessageQueue", "CvsImportMessageQueue", "CvsHotkeys", "CvsHotkeyMessageQueue", "CvsHotkeyModifierKeys", "CvsImportHotkeys", "CvsImportSettings", "CvsHsOptionsCollection" | `
		ForEach-Object {
			$syncHash.Controls.Window.Resources."$( $_ )".Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
		}

	$syncHash.Controls.Window.Resources.CvsHotstringMessageQueue.Source.Add_CollectionChanged( {
		$syncHash.Controls.Window.Resources.CvsHotstringMessageQueue.View.Refresh()
	} )
	$syncHash.Controls.Window.Resources.CvsVariableMessageQueue.Source.Add_CollectionChanged( {
		$syncHash.Controls.Window.Resources.CvsVariableMessageQueue.View.Refresh()
	} )
	$syncHash.Controls.Window.Resources.CvsFunctionMessageQueue.Source.Add_CollectionChanged( {
		$syncHash.Controls.Window.Resources.CvsFunctionMessageQueue.View.Refresh()
	} )

	@( "#", "Win" ), @( "!", "Alt" ), @( "^", "Ctrl" ), @( "+", "Shift" ), @( "&", "AmpCustComb" ), @( "<", "LeftAlt" ), @( ">", "RightAlt" ), @( "<^>!", "AltGr" ), @( "*", "Wildcard" ), @( "~", "Tilde" ), @( "UP", "Up" ) | `
		ForEach-Object {
			$Title, $Text = $syncHash.Data.msgTable."StrHkTt$( $_[1] )" -split ";", 2
			$Hk = [pscustomobject]@{
				Name = $_[0]
				LocalizedTtTitle = $Title.Trim()
				LocalizedTt = $Text.Trim()
				Used = $false
			}
			$syncHash.Controls.Window.Resources.CvsHotkeyModifierKeys.Source.Add( $Hk )
		}

	@( "*", "Asterix" ), @( "?", "QuestionMark" ), @( "B0", "B0" ), @( "C", "C" ), @( "C1", "C1" ), @( "Kn", "Kn" ), @( "O", "O" ), @( "Pn", "Pn" ), @( "R", "R" ), @( "SI", "SI" ), @( "SP", "SP" ), @( "SE", "SE" ), @( "T", "T" ), @( "X", "X" ), @( "Z", "Z" ) | `
		ForEach-Object {
			$Option = [pscustomobject]@{
				Name = $_[1]
				OptionCode = $_[0]
				Tt = $syncHash.Data.msgTable."StrHsOption$( $_[1] )"
				IsUsed = $false
			}
			$syncHash.Controls.Window.Resources.CvsHsOptionsCollection.Source.Add( $Option )
		}

	( $syncHash.Controls.CmFuncAddSetting.Resources.GetEnumerator() | Select-Object -First 1 ).Value.Setters[0].Handler = $syncHash.Code.HsOptionsAdd
	$syncHash.Controls.IcFunctionParameterList.Resources.TbParamStyle.Setters[0].Handler = $syncHash.Code.FuncParamNameUpdate
	$syncHash.Controls.IcFunctionParameterList.Resources.BtnRemoveParam.Setters[0].Handler = $syncHash.Code.RemoveFuncParam
	$syncHash.Controls.Window.Resources.BtnResetSetting.Setters[0].Handler = $syncHash.Code.SettingReset
	$syncHash.Controls.Window.Resources.CbEditable.Setters[0].Handler = $syncHash.Code.SettingComboboxSelectionChanged
	$syncHash.Controls.Window.Resources.CbEditable.Setters[1].Handler = $syncHash.Code.SettingComboboxTextInput
	$syncHash.Controls.Window.Resources.ChbHsOptionStyle.Setters[0].Handler = $syncHash.Code.HsOptionDeselected
	$syncHash.Controls.Window.Resources.TbUserIdStyle.Setters[0].Handler = $syncHash.Code.SettingUserIdTextChanged

	$syncHash.Controls.Window.Resources.StrSettingResetDefault = $syncHash.Data.msgTable.StrSettingResetDefault
	$syncHash.Controls.Window.Resources.StrSettingSelectFolder = $syncHash.Data.msgTable.StrSettingSelectFolder

}

function Test-Xml
{
	<#
	.Synopsis
		Validates an xml file against an xml schema file.
	#>

	param (
		$XmlFile
	)

	$SchemaReader = New-Object System.Xml.XmlTextReader "$( $syncHash.Root )\Apps\OldAhkUpdaterXmlSchema.xsd"
	$ValidationEventHandler = { $syncHash.Controls.LblImportFileInfo.Content = $args[1].Exception }
	$Schema = [System.Xml.Schema.XmlSchema]::Read( $SchemaReader, $ValidationEventHandler )

	$Valid = $true
	try
	{
		$xml = New-Object System.Xml.XmlDocument
		$xml.Schemas.Add( $Schema ) | Out-Null
		$xml.Load( $XmlFile )
		$xml.Validate( { throw } )
	}
	catch
	{
		$Valid = $false
	}
	$SchemaReader.Close()
	$Valid
}

function Update-Extraction
{
	<#
	.Synopsis
		Add an object for extraction, and pdate the display of path for extraction in the extraction-tab
	.Parameter ToAddToExtraction
		Object to add for extraction
	#>

	param (
		$ToAddToExtraction
	)

	$syncHash.Controls.TblScriptExtractionTarget.Text = "$( Get-Setting "ScriptPath" "Files" )\$( Get-Setting "FileName" "Files" ).ahk"
	$syncHash.Controls.TblBackupExtractionTarget.Text = "$( Get-Setting "BackupPath" "Files" )\$( Get-Setting "FileName" "Files" ).json"

	if ( $null -ne $ToAddToExtraction )
	{
		$syncHash.Controls.Window.Resources.CvsToExtract.Source.Add( $ToAddToExtraction )
	}
}

function Update-FunctionHeaderText
{
	<#
	.Synopsis
		Update the display of function header
	#>

	if ( $null -ne $syncHash.Controls.GridFunction.DataContext )
	{
		$syncHash.Controls.TblFunctionHeader.Text = "$( $syncHash.Controls.TbFunctionName.Text ) ($( $syncHash.Controls.GridFuncParameters.Resources.CvsFuncParameters.View.Name -join ", " ))"
	}
	else
	{
		$syncHash.Controls.TblFunctionHeader.Text = ""
	}
}

function Write-BackupFile
{
	<#
	.Synopsis
		Write the backupfile
	.Parameter Extraction
		Specify that the data is list of objects for extraction
	.Parameter OtherLoc
		Specify that the file/-s are to be placed at other location
	#>

	param (
		[switch] $Extraction,
		[switch] $OtherLoc
	)

	if ( $OtherLoc -or $Extraction )
	{
		$BackupPath = Get-Setting "BackupPath" "Files"
		$BackupFileName = Get-Setting "FileName" "Files"
	}
	else
	{
		$BackupPath = $env:USERPROFILE
		$BackupFileName = "AHKUpdaterData"
	}

	if ( Test-Path $BackupPath )
	{
		$Functions = [System.Collections.ArrayList]::new()
		$Hotstrings = [System.Collections.ArrayList]::new()
		$Hotkeys = [System.Collections.ArrayList]::new()
		$Variables = [System.Collections.ArrayList]::new()

		if ( $Extraction )
		{
			$ScriptComment = $syncHash.Controls.TbExtractComment.Text
			$syncHash.Controls.Window.Resources.CvsToExtract.Source | `
				Where-Object { "Function" -eq $_.Type } | `
				ForEach-Object {
					$F = @{
						Name = $_.Name
						ParameterList = $_.ParameterList | Select-Object Name
						FunctionCode = $_.FunctionCode
						Comment = $_.Comment
					}
					$Functions.Add( $F ) | Out-Null
				}
			$syncHash.Controls.Window.Resources.CvsToExtract.Source | `
				Where-Object { "Hotstring" -eq $_.Type } | `
				ForEach-Object {
					$H = @{
						Name = $_.Name
						Options = [System.Collections.ArrayList]::new()
						MenuTitle = $_.MenuTitle
						System = $_.System
						IsAdvanced = $_.IsAdvanced
						Value = $_.Value
						Comment = $_.Comment
					}
					$_.Options | `
						Select-Object Name | `
						ForEach-Object {
							$H.Options.Add( $_ ) | Out-Null
						}
					$Hotstrings.Add( $H ) | Out-Null
				}
			$syncHash.Controls.Window.Resources.CvsToExtract.Source | `
				Where-Object { "Hotkey" -eq $_.Type } | `
				ForEach-Object {
					$Hotkeys.Add( $_ ) | Out-Null
				}
			$syncHash.Controls.Window.Resources.CvsToExtract.Source | `
				Where-Object { "Variable" -eq $_.Type } | `
				ForEach-Object {
					$Variables.Add( $_ ) | Out-Null
				}
		}
		else
		{
			$ScriptComment = $syncHash.Controls.TbScriptComment.Text
			$syncHash.Controls.Window.Resources.CvsFunctions.Source | `
				ForEach-Object {
					$F = @{
						Name = $_.Name
						ParameterList = $_.ParameterList | Select-Object Name
						FunctionCode = $_.FunctionCode
						Comment = $_.Comment
					}
					$Functions.Add( $F ) | Out-Null
				}
			$syncHash.Controls.Window.Resources.CvsHotstrings.Source | `
				ForEach-Object {
					$H = @{
						Name = $_.Name
						Options = [System.Collections.ArrayList]::new()
						MenuTitle = $_.MenuTitle
						System = $_.System
						IsAdvanced = $_.IsAdvanced
						Value = $_.Value
						Comment = $_.Comment
					}
					$_.Options | `
						Select-Object Name | `
						ForEach-Object {
							$H.Options.Add( $_ ) | Out-Null
						}
					$Hotstrings.Add( $H ) | Out-Null
				}
			$syncHash.Controls.Window.Resources.CvsHotkeys.Source | `
				ForEach-Object {
					$Hotkeys.Add( $_ ) | Out-Null
				}
			$syncHash.Controls.Window.Resources.CvsVariables.Source | `
				ForEach-Object {
					$Variables.Add( $_ ) | Out-Null
				}
		}

		$Settings = $syncHash.Controls.Window.Resources.GetEnumerator() | `
			Where-Object { $_.Name -match "CvsSettings(?!MessageQueue)" } | `
			ForEach-Object {
				$_.Value.Source
			} | `
			Select-Object -Property Name,
				DefaultValue, `
				SettingGroup, `
				SettingType, `
				Value

		[pscustomobject]@{
			ScriptComment = $ScriptComment
			Functions = $Functions
			Hotstrings = $Hotstrings
			Hotkeys = $Hotkeys | `
				Select-Object -Property Name, `
					Comment, `
					Hotkey, `
					HotkeyCode
			Variables = $Variables | `
				Select-Object -Property Name,
					Value,
					Comment,
					VariableType
			Settings = $Settings
		} | ConvertTo-Json -Depth 4 | `
			Set-Content -Path "$( $BackupPath )\$( $BackupFileName ).json" -Force

		Add-OpMessage -Message "$( $syncHash.Data.msgTable.StrWroteBackupFile ) $( $BackupPath )\$( $BackupFileName ).json" -Type "Success" -ObjectType "FileInfo"
	}
	else
	{
		Show-MessageBox -Text $syncHash.Data.msgTable.ErrBackupPathNotValid -Button "Ok" -Icon "Error"
	}
}

function Write-ScriptFile
{
	<#
	.Synopsis
		Write the scriptfile
	.Parameter Extraction
		Specify that the data is list of objects for extraction
	.Parameter OtherLoc
		Specify that the file/-s are to be placed at other location
	#>

	param (
		[switch] $Extraction,
		[switch] $OtherLoc
	)

	if ( $Extraction -or $OtherLoc )
	{
		$ScriptPath = Get-Setting "ScriptPath" "Files"
		$ScriptName = Get-Setting "FileName" "Files"
	}
	else
	{
		$ScriptPath = $env:USERPROFILE
		$ScriptName = Get-Setting "FileName" "Files"
	}

	if ( Test-Path $ScriptPath )
	{
		$Functions = [System.Collections.ArrayList]::new()
		$Hotkeys = [System.Collections.ArrayList]::new()
		$Hotstrings = [System.Collections.ArrayList]::new()
		$Variables = [System.Collections.ArrayList]::new()
		$ScriptComment = ""

		if ( $Extraction )
		{
			$syncHash.Controls.Window.Resources.CvsToExtract.View | `
				Where-Object { "Function" -eq $_.Type } | `
				ForEach-Object {
					$Functions.Add( $_ ) | Out-Null
				}
			$syncHash.Controls.Window.Resources.CvsToExtract.View | `
				Where-Object { "Hotkey" -eq $_.Type } | `
				ForEach-Object {
					$Hotkeys.Add( $_ ) | Out-Null
				}
			$syncHash.Controls.Window.Resources.CvsToExtract.View | `
				Where-Object { "Hotstring" -eq $_.Type } | `
				ForEach-Object {
					$Hotstrings.Add( $_ ) | Out-Null
				}
			$syncHash.Controls.Window.Resources.CvsToExtract.View | `
				Where-Object { "Variable" -eq $_.Type } | `
				ForEach-Object {
					$Variables.Add( $_ ) | Out-Null
				}
			$ScriptComment = $syncHash.Controls.TbExtractComment.Text
		}
		else
		{
			$syncHash.Controls.Window.Resources.CvsFunctions.Source | `
				ForEach-Object {
					$Functions.Add( $_ ) | Out-Null
				}
			$syncHash.Controls.Window.Resources.CvsHotkeys.Source | `
				ForEach-Object {
					$Hotkeys.Add( $_ ) | Out-Null
				}
			$syncHash.Controls.Window.Resources.CvsHotstrings.Source | `
				ForEach-Object {
					$Hotstrings.Add( $_ ) | Out-Null
				}
			$syncHash.Controls.Window.Resources.CvsVariables.Source | `
				ForEach-Object {
					$Variables.Add( $_ ) | Out-Null
				}
			$ScriptComment = $syncHash.Controls.TbScriptComment.Text
		}

		$TextToWrite = [System.Text.StringBuilder]::new()
		$Preamble = "$( $syncHash.Data.msgTable.StrScriptFileTitle ) $( Get-Date -Format "yyyy-MM-dd" )"
		if ( "" -ne $ScriptComment )
		{
			$ScriptComment -split "`n" | `
				ForEach-Object {
					$Preamble += "`n;`t$( $_ )"
				}
		}
		$TextToWrite.AppendLine( ( New-ScriptFileSectionTitle $Preamble ) ) | Out-Null

		if ( Get-Setting "IncludeAutoUpdate" "Operations" )
		{
			$TextToWrite.AppendLine( "SetTimer,UPDATEDSCRIPT,1000" ) | Out-Null
			$TextToWrite.AppendLine( @"
UPDATEDSCRIPT:
FileGetAttrib,attribs,%A_ScriptFullPath%
IfInString,attribs,A
{
	FileSetAttrib,-A,%A_ScriptFullPath%
	SplashTextOn,,,$( $syncHash.Data.msgTable.StrScriptTextAutoUpdated ),
	Sleep,500
	Reload
}


"@ ) | Out-Null
		}

		if ( ( Get-Setting "SaveWithGui" "Operations" ) -and `
			$Hotstrings.Count -gt 0
		)
		{
			$TextToWrite.AppendLine( ( New-ScriptFileSectionTitle ( Get-Setting "TitleForMenu" "Settings" ) ) ) | Out-Null
			$Hotstrings | `
				ForEach-Object {
					$TextToWrite.AppendLine( "menu, $( $_.System )Menu, add, $( $_.MenuTitle ), $( $_.Name )" ) | Out-Null
				}

			$TextToWrite.AppendLine() | Out-Null
			$TextToWrite.AppendLine( ( New-ScriptFileSectionTitle ( Get-Setting "TitleForMenuTriggers" "Settings" ) ) ) | Out-Null
			$syncHash.Controls.Window.Resources.SystemList | `
				Where-Object { $_ -in $Hotstrings.System } | `
				Sort-Object | `
				ForEach-Object {
					$TextToWrite.AppendLine( "::$( Get-Setting "MenuShowTrigger" "Operations" )$( $_ )::`nmenu, $( $_ )Menu, show, %A_CaretX%, %A_CaretY%`nReturn`n" ) | Out-Null
				}
			$TextToWrite.AppendLine( "`n" ) | Out-Null
		}

		if ( $Hotkeys.Count -gt 0 )
		{
			$TextToWrite.AppendLine( ( New-ScriptFileSectionTitle ( Get-Setting "TitleForHotkeys" "Settings" ) ) ) | Out-Null
			$Hotkeys | `
				ForEach-Object {
					if ( $_.Comment -ne "" )
					{
						$TextToWrite.AppendLine( "; $( $_.Comment )" ) | Out-Null
					}
					$TextToWrite.AppendLine( "$( $_.Hotkey )::$( $_.HotkeyCode )" ) | Out-Null
				}
			$TextToWrite.AppendLine() | Out-Null
		}

		if ( $Variables.Count -gt 0 )
		{
			$TextToWrite.AppendLine( ( New-ScriptFileSectionTitle ( Get-Setting "TitleForVariables" "Settings" ) ) ) | Out-Null
			$Variables | `
				ForEach-Object {
					if ( $_.Comment -ne "" )
					{
						$TextToWrite.AppendLine( "; $( $_.Comment )" ) | Out-Null
					}

					if ( $_.VariableType -eq "Legacy" )
					{
						$TextToWrite.AppendLine( "$( $_.Name ) = $( $_.Value )" ) | Out-Null
					}
					else
					{
						$TextToWrite.AppendLine( "$( $_.Name ) := $( $_.Value )" ) | Out-Null
					}
					$TextToWrite.AppendLine() | Out-Null
				}
			$TextToWrite.AppendLine() | Out-Null
		}

		if ( $Functions.Count -gt 0 )
		{
			$TextToWrite.AppendLine( ( New-ScriptFileSectionTitle ( Get-Setting "TitleForFunctions" "Settings" ) ) ) | Out-Null
			$Functions | `
				ForEach-Object {
					if ( $_.Comment -ne "" )
					{
						$TextToWrite.AppendLine( "; $( $_.Comment )" ) | Out-Null
					}
					$TextToWrite.AppendLine( "$( $_.Name ) ( $( $_.ParameterList.Name -join ", " ) )`n{$( $_.FunctionCode )`n}`n" ) | Out-Null
				}
			$TextToWrite.AppendLine() | Out-Null
		}

		if ( $Hotstrings.Count -gt 0 )
		{
			$TextToWrite.AppendLine( ( New-ScriptFileSectionTitle ( Get-Setting "TitleForHotstrings" "Settings" ) ) ) | Out-Null
			$Hotstrings | `
				ForEach-Object {
					if ( $_.Comment -ne "" )
					{
						$TextToWrite.AppendLine( "; $( $_.Comment )" ) | Out-Null
					}

					$TextToWrite.Append( ":" )
					if ( $_.Options.Count -gt 0 )
					{
						$TextToWrite.Append( ( $_.Options.OptionCode -join " " ) ) <#| `
							ForEach-Object {
								$TextToWrite.Append( "$( $_.OptionCode ) ") | Out-Null
							}#>
					}

					$TextToWrite.AppendLine( ":$( $_.Name )::" ) | Out-Null

					if ( Get-Setting "SaveWithGui" "Operations" )
					{
						$TextToWrite.AppendLine( "$( $_.Name ):" ) | Out-Null
					}

					if ( $_.IsAdvanced )
					{
						$TextToWrite.AppendLine( "text=`n(`n$( $_.Value )`n)`nPrintText(text)`nReturn`n" ) | Out-Null
					}
					else
					{
						$TextToWrite.AppendLine( "$( $_.Value )`n" ) | Out-Null
					}
				}
			$TextToWrite.AppendLine() | Out-Null
		}

		$TextToWrite.AppendLine( "`nExitApp" ) | Out-Null

		New-Item -Path $ScriptPath -Name "$( $ScriptName ).ahk" -ItemType File -Value $TextToWrite.ToString() -Force

		Add-OpMessage -Message "$( $syncHash.Data.msgTable.StrWroteScriptFile ) $( $ScriptPath )\$( $ScriptName ).ahk" -Type "Success" -ObjectType "FileInfo"
	}
	else
	{
		Show-MessageBox -Text $syncHash.Data.msgTable.ErrScriptPathNotValid -Button "Ok" -Icon "Error"
	}
}

######################### Script start
$Controls = [System.Collections.ArrayList]::new( @(
) )

$syncHash.Data.HasBeenLoaded = $false
$syncHash.Controls.Window.Resources.Add( "SystemList", ( [System.Collections.ObjectModel.ObservableCollection[object]]::new() ) )
"CvsHotstringListOfSystems", "CvsHotstringSystemList", "CvsHotstringSystemListNewObject" | `
	ForEach-Object {
		$syncHash.Controls.Window.Resources."$( $_ )".Source = $syncHash.Controls.Window.Resources.SystemList
	}


# region UI eventhandlers
[System.Windows.Controls.TextChangedEventHandler] $syncHash.Code.FuncParamNameUpdate =
{
	if ( $null -ne $syncHash.Controls.GridFunction.DataContext )
	{
		$HasChanged = $syncHash.Controls.GridFunction.DataContext.HasChanged
		if ( $args[0].Text -in $syncHash.Controls.GridFuncParameters.Resources.CvsFuncParameters.View.Name -and $args[0].Text -ne $args[0].DataContext.OriginalName )
		{
			Add-OpMessage -Message $syncHash.Data.msgTable.ErrFuncParamNameExists -Type "Error" -ObjectType "Function"
			$args[0].GetBindingExpression( [System.Windows.Controls.TextBox]::TextProperty ).UpdateTarget()
			$args[0].CaretIndex = $args[0].Text.Length
		}
		else
		{
			$syncHash.Controls.GridFunction.DataContext.HasChanged = $true
		}
	}
	$syncHash.Controls.BtnFunctionSave.GetBindingExpression( [System.Windows.Controls.Button]::IsEnabledProperty ).UpdateTarget()
}

[System.Windows.RoutedEventHandler] $syncHash.Code.HsOptionsAdd =
{
	$args[0].DataContext.IsUsed = $true
	if ( "SI" -eq $args[0].DataContext.Name )
	{
		$syncHash.Controls.TbHotstringCode.MaxLength = 5000
	}

	$syncHash.Controls.GridHotstring.DataContext.Options.Add( ( $args[0].DataContext.psobject.Copy() ) )
	$syncHash.Controls.ExpHotstringOptions.Resources.CvsHotstringOptions.View.Refresh()
	$syncHash.Controls.Window.Resources.CvsHsOptionsCollection.View.Refresh()
	$syncHash.Controls.GridHotstring.DataContext.HasChanged = $true
	$syncHash.Controls.BtnHotstringSave.GetBindingExpression( [System.Windows.Controls.Button]::IsEnabledProperty ).UpdateTarget()
}

[System.Windows.RoutedEventHandler] $syncHash.Code.HsOptionDeselected =
{
	if ( "{DisconnectedItem}" -ne $args[0].DataContext.ToString() )
	{
		if ( "SI" -eq $args[0].DataContext.Name )
		{
			$syncHash.Controls.TbHotstringCode.MaxLength = 0
		}

		$syncHash.CurrentOption = $args[0].DataContext.Name
		$syncHash.Controls.Window.Resources.CvsHsOptionsCollection.Source.Where( { $syncHash.CurrentOption -eq $_.Name } ) | `
			ForEach-Object {
				$_.IsUsed = $false
			}
		$syncHash.Controls.Window.Resources.CvsHsOptionsCollection.View.Refresh()

		$o = $syncHash.Controls.GridHotstring.DataContext.Options.Where( { $_.Name -eq $syncHash.CurrentOption } )[0]
		$syncHash.Controls.GridHotstring.DataContext.Options.Remove( $o )

		$syncHash.Controls.ExpHotstringOptions.Resources.CvsHotstringOptions.View.Refresh()
		$syncHash.Controls.GridHotstring.DataContext.HasChanged = $true
		$syncHash.Controls.BtnHotstringSave.GetBindingExpression( [System.Windows.Controls.Button]::IsEnabledProperty ).UpdateTarget()
	}
}

[System.Windows.RoutedEventHandler] $syncHash.Code.RemoveFuncParam =
{
	$args[0].DataContext.Removed = $true
	$syncHash.Controls.GridFuncParameters.Resources.CvsFuncParameters.View.Refresh()
	$syncHash.Controls.GridFunction.DataContext.HasChanged = $true
	$syncHash.Controls.BtnFunctionSave.GetBindingExpression( [System.Windows.Controls.Button]::IsEnabledProperty ).UpdateTarget()
	Update-FunctionHeaderText
}

[System.Windows.RoutedEventHandler] $syncHash.Code.SettingReset =
{
	$args[0].DataContext.Value = $args[0].DataContext.DefaultValue
	$syncHash.Controls.Window.Resources."CvsSettings$( $args[0].DataContext.SettingGroup )".View.Refresh()
}

[System.Windows.Controls.SelectionChangedEventHandler] $syncHash.Code.SettingComboboxSelectionChanged =
{
	$args[0].TemplatedParent.TemplatedParent.DataContext.Value = $args[0].SelectedItem
	Update-Extraction
}

[System.Windows.Input.KeyEventHandler] $syncHash.Code.SettingComboboxTextInput =
{
	$args[0].TemplatedParent.TemplatedParent.DataContext.Value = $args[1].OriginalSource.Text
	Update-Extraction
}

[System.Windows.Controls.TextChangedEventHandler] $syncHash.Code.SettingUserIdTextChanged =
{
	if ( $args[0].Text.Length -ge 4 )
	{
		try
		{
			$U = Get-ADUser $args[0].Text -Properties HomeDirectory -ErrorAction Stop
			$args[0].DataContext.SettingInfo = "$( $syncHash.Data.msgTable.StrSettingUserIdFoundPrefix ) $( $U.Name )"
			Add-FilePaths -Path $U.HomeDirectory
			$t = $args[0].Text
			$syncHash.Controls.Window.Resources.CvsSettingsFiles.View.Refresh()
			$args[0].Text = $t
		}
		catch
		{
			$args[0].DataContext.SettingInfo = "$( $syncHash.Data.msgTable.ErrSettingUserIdNotFound )`n$( $_ )"
			$args[0].Tag.Children[3].GetBindingExpression( [System.Windows.Controls.Label]::ContentProperty ).UpdateTarget()
		}
	}
	elseif ( $args[0].Text.Length -gt 0 )
	{
		$args[0].DataContext.SettingInfo = ""
		$args[0].Tag.Children[3].GetBindingExpression( [System.Windows.Controls.Label]::ContentProperty ).UpdateTarget()
	}
}

# endregion UI eventhandlers

# region Cvs Filters
[System.Predicate[object]] $syncHash.Code.HotstringBySystemFilter =
{
	$syncHash.Controls.CbHotstringSystems.SelectedItem -eq $args[0].System
}

[System.Predicate[object]] $syncHash.Code.HsOptionFilter =
{
	-not $args[0].IsUsed
}

[System.Predicate[object]] $syncHash.Code.FunctionParameterListRemovedFilter =
{
	( -not $args[0].Removed )
}

# endregion Cvs Filters

Set-Localizations

# A new object is defined
$syncHash.Controls.BtnAddNew.Add_Click( {
	if ( $this.DataContext.Type -eq "Hotkey" )
	{
		$syncHash.Controls.TcMain.SelectedItem = $syncHash.Controls.TiHotkey

		$NewHotkey = [pscustomobject]@{
			Name = $syncHash.Controls.TbNewName.Text
			HotkeyCode = ""
			Comment = ""
			HasChanged = $true
			IsNew = $true
		}

		$syncHash.Controls.Window.Resources.CvsHotkeys.Source.Add( $NewHotkey )
		$syncHash.Controls.Window.Resources.CvsHotkeys.View.Refresh()
		$syncHash.Controls.LvHotkeys.SelectedItem = $NewHotkey
	}
	elseif ( $this.DataContext.Type -eq "Hotstring" )
	{
		$syncHash.Controls.TcMain.SelectedItem = $syncHash.Controls.TiHotstrings

		$NewHotstring = [pscustomobject]@{
			Name = $syncHash.Controls.TbNewName.Text
			Comment = ""
			IsAdvanced = $false
			MenuTitle = "$( $syncHash.Data.msgTable.StrDefaultMenuTitle ) $( $syncHash.Controls.TbNewName.Text )"
			System = $syncHash.Controls.CbNewSystem.Text
			Value = "; $( $syncHash.Data.msgTable.StrHotstringDefaultText )"
			HasChanged = $true
			IsNew = $true
		}

		if ( $syncHash.Controls.Window.Resources.SystemList -notcontains $NewHotstring.System )
		{
			Edit-HotstringSystems -NewSystem $NewHotstring.System
		}
		$syncHash.Controls.CbHotstringSystems.SelectedItem = $NewHotstring.System

		$syncHash.Controls.Window.Resources.CvsHotstrings.Source.Add( $NewHotstring )
		$syncHash.Controls.Window.Resources.CvsHotstrings.View.Refresh()
		$syncHash.Controls.LvHotstrings.SelectedItem = $NewHotstring
	}
	elseif ( $this.DataContext.Type -eq "Variable" )
	{
		$NewVariable = [pscustomobject]@{
			Comment = ""
			Name = $syncHash.Controls.TbNewName.Text
			Value = ""
			HasChanged = $true
			IsNew = $true
			VariableType = "Legacy"
		}

		$syncHash.Controls.Window.Resources.CvsVariables.Source.Add( $NewVariable )
		$syncHash.Controls.Window.Resources.CvsVariables.View.Refresh()
		$syncHash.Controls.LvVariables.SelectedItem = $NewVariable
	}
	else
	{
		$NewFunction = [pscustomobject]@{
			Comment = ""
			Name = $syncHash.Controls.TbNewName.Text
			FunctionCode = "; $( $syncHash.Data.msgTable.StrDefaulFuncCode )"
			ParameterList = [System.Collections.ArrayList]::new()
			HasChanged = $true
			IsNew = $true
		}
		$syncHash.Controls.Window.Resources.CvsFunctions.Source.Add( $NewFunction )

		$syncHash.Controls.Window.Resources.CvsFunctions.View.Refresh()
		$syncHash.Controls.LvFunctions.SelectedItem = $NewFunction
	}

	$syncHash.Controls.TcMain.SelectedItem = $syncHash.Controls."Ti$( $this.DataContext.Type )s"
	$syncHash.Controls."Tb$( $this.DataContext.Type )Code".Focus()
	$syncHash.Controls.GridNewObject.DataContext = $null
	$syncHash.Controls.TbNewName.Text = ""
} )

# Selected system for hotstrings have changed, refresh filtered list of hotstrings associated with this system
$syncHash.Controls.CbHotstringSystems.Add_SelectionChanged( {
	$syncHash.Controls.Window.Resources.CvsHotstrings.View.Refresh()
} )

# Menuitem for new function is clicked
$syncHash.Controls.MenuItemNewFunction.Add_Click( {
	$syncHash.Controls.GridNewObject.DataContext = [pscustomobject]@{
		Type = "Function"
		Name = ""
	}
	$syncHash.Controls.TbNewName.Focus()
} )

# Menuitem for new hotkey is clicked
$syncHash.Controls.MenuItemNewHotkey.Add_Click( {
	$syncHash.Controls.GridNewObject.DataContext = [pscustomobject]@{
		Type = "Hotkey"
		Name = ""
	}
	$syncHash.Controls.TbNewName.Focus()
} )

# Menuitem for new hotstring is clicked
$syncHash.Controls.MenuItemNewHotstring.Add_Click( {
	$syncHash.Controls.GridNewObject.DataContext = [pscustomobject]@{
		Type = "Hotstring"
		Name = ""
		IsAdvanced = $false
		MenuTitle = ""
		System = ""
		Value = ""
	}
	$syncHash.Controls.TbNewName.Focus()
} )

# Menuitem for new variable is clicked
$syncHash.Controls.MenuItemNewVariable.Add_Click( {
	$syncHash.Controls.GridNewObject.DataContext = [pscustomobject]@{
		Type = "Variable"
		Name = ""
	}
	$syncHash.Controls.TbNewName.Focus()
} )

# Write files to location specified under 'other location'
$syncHash.Controls.BtnWriteToOtherLocation.Add_Click( {
	Write-BackupFile -OtherLoc
	Write-ScriptFile -OtherLoc
} )

# Abort creating new object
$syncHash.Controls.BtnCancelNew.Add_Click( {
	$syncHash.Controls.GridNewObject.DataContext = $null
} )

# Save all data to ordinary file locations
$syncHash.Controls.BtnSave.Add_Click( {
	Write-ScriptFile
	Write-BackupFile
} )

# Name of new object is specified, verify if name is in use
$syncHash.Controls.TbNewName.Add_TextChanged( {
	if ( ( $syncHash.Controls.Window.Resources.CvsFunctions.Source.Name -contains $this.Text ) -or `
		( $syncHash.Controls.Window.Resources.CvsHotstrings.Source.Name -contains $this.Text ) -or `
		( $syncHash.Controls.Window.Resources.CvsVariables.Source.Name -contains $this.Text )
	)
	{
		$syncHash.Controls.TblNewObjectInfo.Text = $syncHash.Data.msgTable.ErrNewObjectNameExists
	}
	elseif ( $this.Text -match "\s" )
	{
		$syncHash.Controls.TblNewObjectInfo.Text = $syncHash.Data.msgTable.ErrNewObjectNameContainsWhiteSpaceChar
	}
	elseif ( $this.Text -match "\W" )
	{
		$syncHash.Controls.TblNewObjectInfo.Text = $syncHash.Data.msgTable.ErrNewObjectNameContainsNonWordChar
	}
	else
	{
		$syncHash.Controls.TblNewObjectInfo.Text = ""
	}
} )

# region Extraction Ops
# Add an option to selected hotstring
$syncHash.Controls.BtnAddHsOption.Add_Click( {
	$this.ContextMenu.IsOpen = $true
} )

# Abort list of objects for extraction
$syncHash.Controls.BtnCancelExtraction.Add_Click( {
	$syncHash.Controls.Window.Resources.CvsToExtract.Source.Clear()
	$syncHash.Controls.Window.Resources.CvsToExtract.View.Refresh()
	$syncHash.Controls.TbExtractComment.Text = ""
	Add-OpMessage -Message $syncHash.Data.msgTable.StrExtractionCleared -Type "Success" -ObjectType "Extraction"
} )

# Write extracted objects to file specified under 'other location'
$syncHash.Controls.BtnExtractToBackup.Add_Click( {
	Write-BackupFile -Extraction
} )

# Write extracted objects to file specified under 'other location'
$syncHash.Controls.BtnExtractToScript.Add_Click( {
	Write-ScriptFile -Extraction
} )

# Removes object from list for extraction
$syncHash.Controls.BtnRemoveFromExtractList.Add_Click( {
	$TypeRemoved = $syncHash.Controls.LvExtractList.SelectedItem.Type
	$syncHash.Controls.Window.Resources.CvsToExtract.Source.Remove( $syncHash.Controls.LvExtractList.SelectedItem )
	$syncHash.Controls.Window.Resources.CvsToExtract.View.Refresh()
	Add-OpMessage -Message "$( $TypeRemoved ) $( $syncHash.Data.msgTable.StrExtractionObjectRemoved )" -Type "Success" -ObjectType "Extraction"
} )

# Copy existing script comment, to script specified for extraction
$syncHash.Controls.BtnInsertExistingCommentForExtraction.Add_Click( {
	$syncHash.Controls.TbExtractComment.Text = $syncHash.Controls.TbScriptComment.Text
} )
# endregion Extraction Ops

# region Function Ops
# Add selected function to list for extraction
$syncHash.Controls.BtnAddFunctionForExtraction.Add_Click( {
	$ToExtract = $syncHash.Controls.LvFunctions.SelectedItem.psobject.Copy()
	$ToExtract.ParameterList = $ToExtract.ParameterList | Select-Object -ExpandProperty Name
	Add-Member -InputObject $ToExtract -MemberType NoteProperty -Name "Type" -Value "Function"
	Update-Extraction $ToExtract
} )

# Add a parameter to selected function
$syncHash.Controls.BtnFunctionAddParameter.Add_Click( {
	$syncHash.Controls.GridFuncParameters.Resources.CvsFuncParameters.Source.Add( ( [pscustomobject]@{
		Name = "Parameter_$( $syncHash.Controls.GridFuncParameters.Resources.CvsFuncParameters.Source.Count + 1 )"
		HasChanged = $true
		OriginalName = ""
		Removed = $false
	} ) )
	$syncHash.Controls.GridFuncParameters.Resources.CvsFuncParameters.View.Refresh()
	Update-FunctionHeaderText
} )

# Removes the selected function
$syncHash.Controls.BtnFunctionRemove.Add_Click( {
	$ItemToRemove = $syncHash.Controls.LvFunctions.SelectedItem
	$syncHash.Controls.LvFunctions.SelectedIndex = -1
	$syncHash.Controls.Window.Resources.CvsFunctions.Source.Remove( $ItemToRemove )
	$syncHash.Controls.Window.Resources.CvsFunctions.View.Refresh()
} )

# Save changes in the selected function
$syncHash.Controls.BtnFunctionSave.Add_Click( {
	$syncHash.Controls.LvFunctions.SelectedItem.Name = $syncHash.Controls.TbFunctionName.Text
	$syncHash.Controls.LvFunctions.SelectedItem.FunctionCode = $syncHash.Controls.TbFunctionCode.Text
	$L = ( $syncHash.Controls.LvFunctions.SelectedItem.ParameterList.psobject.Copy() ) | `
		Where-Object { $_.Removed }
	$L | `
		ForEach-Object{
			$syncHash.Controls.LvFunctions.SelectedItem.ParameterList.Remove( $_ )
		}
	$syncHash.Controls.Window.Resources.CvsFunctions.View.Refresh()
	$syncHash.Controls.LvFunctions.SelectedItem.IsNew = $false
	$syncHash.Controls.LvFunctions.SelectedItem.HasChanged = $false
	$syncHash.Controls.GridFunction.GetBindingExpression( [System.Windows.Controls.Grid]::DataContextProperty ).UpdateTarget()
} )

# DataContext changed (a function is selected in functionlist), update the display for function header
$syncHash.Controls.GridFunction.Add_DataContextChanged( {
	Update-FunctionHeaderText
} )

# Function is selected update filter and display for function header
$syncHash.Controls.LvFunctions.Add_SelectionChanged( {
	if ( $null -ne $this.SelectedItem )
	{
		$this.SelectedItem.ParameterList | `
			ForEach-Object {
				$_.Removed = $false
			}

		if ( -not $this.SelectedItem.IsNew )
		{
			$syncHash.Controls.GridFuncParameters.Resources.CvsFuncParameters.View.Filter = $syncHash.Code.FunctionParameterListRemovedFilter
			$syncHash.Controls.GridFuncParameters.Resources.CvsFuncParameters.View.Refresh()
		}
	}
	Update-FunctionHeaderText
} )

# Function code has changed, update if button to save should be enabled/disabled
$syncHash.Controls.TbFunctionCode.Add_TextChanged( {
	if ( $null -ne $this.DataContext )
	{
		$this.DataContext.HasChanged = $this.Text -ne $syncHash.Controls.LvFunctions.SelectedItem.FunctionCode -and `
			( $this.DataContext.IsNew -eq $false -or $null -eq $this.DataContext.IsNew )
	}

	$syncHash.Controls.BtnFunctionSave.GetBindingExpression( [System.Windows.Controls.Button]::IsEnabledProperty ).UpdateTarget()
} )

# Key pressed for name of function
$syncHash.Controls.TbFunctionName.Add_PreviewKeyDown( {
	if ( $null -ne $this.DataContext )
	{
		# Check that system name does not contains any whitespace-characters
		if ( $args[1].Key -eq "Space" )
		{
			Add-OpMessage -Message $syncHash.Data.msgTable.StrFunctionNameContainsWhitespace -Type "Error" -ObjectType "Function"
			$args[1].Handled = $true
		}
	}
} )

# Name of function have changed, update display of function header and if button to save should be enabled/disabled
$syncHash.Controls.TbFunctionName.Add_TextChanged( {
	if ( $null -ne $this.DataContext )
	{
		if ( $this.Text -ne $syncHash.Controls.LvFunctions.SelectedItem.Name -and `
			$this.Text -in $syncHash.Controls.Window.Resources.CvsFunctions.Source.Name
		)
		{
			Add-OpMessage -Message $syncHash.Data.msgTable.ErrFunctionNameExists -Type "Error" -ObjectType "Function"
			$this.Text = $syncHash.Controls.LvFunctions.SelectedItem.Name
		}

		$this.DataContext.HasChanged = $this.Text -ne $syncHash.Controls.LvFunctions.SelectedItem.Name -and `
			( $this.DataContext.IsNew -eq $false -or $null -eq $this.DataContext.IsNew )
	}

	Update-FunctionHeaderText
	$syncHash.Controls.BtnFunctionSave.GetBindingExpression( [System.Windows.Controls.Button]::IsEnabledProperty ).UpdateTarget()
} )
# endregion Function Ops

# region Hotkey Ops
# Add selected hotkey to list for extraction
$syncHash.Controls.BtnAddHotkeyForExtraction.Add_Click( {
	$ToExtract = $syncHash.Controls.LvHotkeys.SelectedItem.psobject.Copy()
	Add-Member -InputObject $ToExtract -MemberType NoteProperty -Name "Type" -Value "Hotkey"
	Update-Extraction $ToExtract
} )

# Remove selected hotkey
$syncHash.Controls.BtnHotkeyRemove.Add_Click( {
	$ItemToRemove = $syncHash.Controls.LvHotkeys.SelectedItem
	$syncHash.Controls.LvHotkeys.SelectedIndex = -1
	$syncHash.Controls.Window.Resources.CvsHotkeys.Source.Remove( $ItemToRemove )
	$syncHash.Controls.Window.Resources.CvsHotkeys.View.Refresh()
} )

# Save the selected hotkey
$syncHash.Controls.BtnHotkeySave.Add_Click( {
	$syncHash.Controls.LvHotkeys.SelectedItem.Comment = $syncHash.Controls.TbHotkeyComment.Text
	$syncHash.Controls.LvHotkeys.SelectedItem.Name = $syncHash.Controls.TbHotkeyName.Text
	$syncHash.Controls.LvHotkeys.SelectedItem.Hotkey = $syncHash.Controls.TbHotkeyHotkey.Text
	$syncHash.Controls.LvHotkeys.SelectedItem.HotkeyCode = $syncHash.Controls.TbHotkeyCode.Text

	$syncHash.Controls.Window.Resources.CvsHotkeys.View.Refresh()
	$syncHash.Controls.LvHotkeys.SelectedItem.IsNew = $false
	$syncHash.Controls.LvHotkeys.SelectedItem.HasChanged = $false
	$syncHash.Controls.BtnHotkeySave.GetBindingExpression( [System.Windows.Controls.Button]::IsEnabledProperty ).UpdateTarget()
} )

# A hotkey is selected
$syncHash.Controls.LvHotkeys.Add_SelectionChanged( {
	$syncHash.Controls.Window.Resources.CvsHotkeyMessageQueue.Source.Clear()
	$syncHash.Controls.RbHotkeyModifierDisplayCode.IsChecked = $true
} )

# Hotkey-activation keycombo is updated verify pressens of modifier keys
$syncHash.Controls.TbHotkeyHotkey.Add_TextChanged( {
	$syncHash.Controls.Window.Resources.CvsHotkeyModifierKeys.Source | `
		ForEach-Object {
			$_.Used = $false
		}

	if ( $this.Text -match "<\^>!" )
	{
		$syncHash.Controls.Window.Resources.CvsHotkeyModifierKeys.Source.Where( { $_.Name -match "<\^>!" } )[0].Used = $true
		$T = $this.Text -replace "<\^>!"
	}
	else
	{
		$T = $this.Text
	}

	[regex]::Matches( $T, "#|!|\^|\+|&|<|>|\*|\~|(Up)" ) | `
		ForEach-Object {
			$a = $_
			$syncHash.Controls.Window.Resources.CvsHotkeyModifierKeys.Source.Where( { $_.Name -eq $a.Groups[0].Value } )[0].Used = $true
		}

	$syncHash.Controls.Window.Resources.CvsHotkeyModifierKeys.View.Refresh()
} )

# Name of selected hotkey has changed
$syncHash.Controls.TbHotkeyName.Add_TextChanged( {
	if ( $null -ne $syncHash.Controls.GridHotkey.DataContext )
	{
		if ( $this.DataContext.IsNew )
		{
			$this.DataContext.HasChanged = $true
		}
		else
		{
			if ( $this.Text -ne $syncHash.Controls.LvHotkeys.SelectedItem.Name -and `
				$this.Text -in $syncHash.Controls.Window.Resources.CvsHotkeys.Source.Name
			)
			{
				Add-OpMessage -Message $syncHash.Data.msgTable.ErrHotkeyNameExists -Type "Error" -ObjectType "Hotkey"
				$this.Text = $syncHash.Controls.LvHotkeys.SelectedItem.Name
			}

			$this.DataContext.HasChanged = $this.Text -ne $syncHash.Controls.LvHotkeys.SelectedItem.Name -and `
				( $this.DataContext.IsNew -eq $false -or $null -eq $this.DataContext.IsNew )
		}
	}

	$syncHash.Controls.BtnHotkeySave.GetBindingExpression( [System.Windows.Controls.Button]::IsEnabledProperty ).UpdateTarget()
} )

# Comment of selected hotkey has changed
$syncHash.Controls.TbHotkeyComment.Add_TextChanged( {
	if ( $null -ne $syncHash.Controls.GridHotkey.DataContext )
	{
		if ( $this.DataContext.IsNew )
		{
			$this.DataContext.HasChanged = $true
		}
		else
		{
			$this.DataContext.HasChanged = $this.Text -ne $syncHash.Controls.LvHotkeys.SelectedItem.Comment
		}
	}

	$syncHash.Controls.BtnHotkeySave.GetBindingExpression( [System.Windows.Controls.Button]::IsEnabledProperty ).UpdateTarget()
} )

# Hotkey code/label was updated
$syncHash.Controls.TbHotkeyCode.Add_TextChanged( {
	if ( $null -ne $syncHash.Controls.GridHotkey.DataContext )
	{
		if ( $this.DataContext.IsNew )
		{
			$this.DataContext.HasChanged = $true
		}
		else
		{
			$this.DataContext.HasChanged = $this.Text -ne $syncHash.Controls.LvHotkeys.SelectedItem.Value
		}
	}

	$syncHash.Controls.BtnHotkeySave.GetBindingExpression( [System.Windows.Controls.Button]::IsEnabledProperty ).UpdateTarget()
} )
# endregion Hotkey Ops

# region Hotstring Ops
# Add hotstring to list for extraction
$syncHash.Controls.BtnAddHotstringForExtraction.Add_Click( {
	$ToExtract = $syncHash.Controls.LvHotstrings.SelectedItem.psobject.Copy()
	Add-Member -InputObject $ToExtract -MemberType NoteProperty -Name "Type" -Value "Hotstring"
	Update-Extraction $ToExtract

	$ToExtract.Value -split "\s" | `
		Where-Object { $_ } | `
		ForEach-Object {
			if ( $syncHash.Controls.Window.Resources.CvsFunctions.Source.Name -contains $_ )
			{
				$N = $_
				$AddedFunction = $syncHash.Controls.Window.Resources.CvsFunctions.Source.Where( { $_.Name -eq $N } )[0]
				Update-Extraction $AddedFunction
				Add-OpMessage -Message "$( $AddedFunction.Name )$( $syncHash.Data.msgTable.StrHsExtractedIncFun )" -Type "Info" -ObjectType "Hotstring"
			}
		}
} )

# Remove selected hotstring
$syncHash.Controls.BtnHotstringRemove.Add_Click( {
	$ItemToRemove = $syncHash.Controls.LvHotstrings.SelectedItem
	$syncHash.Controls.LvHotstrings.SelectedIndex = -1
	$syncHash.Controls.Window.Resources.CvsHotstrings.Source.Remove( $ItemToRemove )
	$syncHash.Controls.Window.Resources.CvsHotstrings.View.Refresh()
} )

# Save updated selected hotstring
$syncHash.Controls.BtnHotstringSave.Add_Click( {
	$syncHash.Controls.LvHotstrings.SelectedItem.Name = $syncHash.Controls.TbHotstringName.Text
	$syncHash.Controls.LvHotstrings.SelectedItem.System = $syncHash.Controls.CbHotstringListOfSystems.Text
	$syncHash.Controls.LvHotstrings.SelectedItem.IsAdvanced = $syncHash.Controls.CbAdvancedHotstring.I122sChecked
	$syncHash.Controls.LvHotstrings.SelectedItem.MenuTitle = $syncHash.Controls.TbHotstringMenuTitle.Text
	$syncHash.Controls.LvHotstrings.SelectedItem.Value = $syncHash.Controls.TbHotstringCode.Text
	#TODO Fixa att options inte sparas
	$OL = $syncHash.Controls.IcHotstringOptions.ItemsSource | ForEach-Object { $_ }
	$syncHash.Controls.LvHotstrings.SelectedItem.Options.Clear()
	$OL | `
		ForEach-Object {
			$syncHash.Controls.LvHotstrings.SelectedItem.Options.Add( $_ )
		}

	if ( ( $syncHash.Controls.LvHotstrings.SelectedItem | Get-Member -MemberType NoteProperty ).Name -contains "IsNew" )
	{
		$syncHash.Controls.LvHotstrings.SelectedItem.IsNew = $false
	}
	$syncHash.Controls.LvHotstrings.SelectedItem.HasChanged = $false

	if ( $syncHash.Controls.Window.Resources.SystemList -notcontains $syncHash.Controls.GridHotstring.DataContext.System )
	{
		Edit-HotstringSystems -NewSystem $syncHash.Controls.GridHotstring.DataContext.System
	}
	$syncHash.Controls.CbHotstringSystems.SelectedItem = $syncHash.Controls.GridHotstring.DataContext.System
	$syncHash.Controls.Window.Resources.CvsHotstrings.View.Refresh()
	$syncHash.Controls.BtnHotstringSave.GetBindingExpression( [System.Windows.Controls.Button]::IsEnabledProperty ).UpdateTarget()
} )

# Define if selected hotstring is advanced, meaning that it may contain additional code/functionality, other than simple textreplacement
$syncHash.Controls.CbAdvancedHotstring.Add_Checked( {
	if ( $this.DataContext.IsNew )
	{
		$this.DataContext.HasChanged = $true
	}
	else
	{
		$this.DataContext.HasChanged = $this.IsChecked -ne $syncHash.Controls.LvHotstrings.SelectedItem.IsAdvanced -and `
			( $this.DataContext.IsNew -eq $false -or $null -eq $this.DataContext.IsNew )
	}

	$syncHash.Controls.BtnHotstringSave.GetBindingExpression( [System.Windows.Controls.Button]::IsEnabledProperty ).UpdateTarget()
} )

# Define if selected hotstring is not advanced, meaning that it will only do simple textreplacement
$syncHash.Controls.CbAdvancedHotstring.Add_Unchecked( {
	if ( $null -ne $this.DataContext )
	{
		if ( $this.DataContext.IsNew )
		{
			$this.DataContext.HasChanged = $true
		}
		else
		{
			$this.DataContext.HasChanged = $this.IsChecked -ne $syncHash.Controls.LvHotstrings.SelectedItem.IsAdvanced -and `
				( $this.DataContext.IsNew -eq $false -or $null -eq $this.DataContext.IsNew )
		}

		$syncHash.Controls.BtnHotstringSave.GetBindingExpression( [System.Windows.Controls.Button]::IsEnabledProperty ).UpdateTarget()
	}
} )

# Key pressed for name of system
$syncHash.Controls.CbHotstringListOfSystems.Add_PreviewKeyDown( {
	if ( $null -ne $this.DataContext )
	{
		# Check that system name does not contains any whitespace-characters
		if ( $args[1].Key -eq "Space" )
		{
			Add-OpMessage -Message $syncHash.Data.msgTable.StrSystemNameContainsWhitespace -Type "Error" -ObjectType "Hotstring"
			$args[1].Handled = $true
		}
	}
} )

# System for selected hotstring was changed by typing different/new name
$syncHash.Controls.CbHotstringListOfSystems.Add_KeyUp( {
	if ( $this.DataContext.IsNew )
	{
		$this.DataContext.HasChanged = $true
	}
	else
	{
		$this.DataContext.HasChanged = $this.Text -ne $syncHash.Controls.LvHotstrings.SelectedItem.System -and `
			( $this.DataContext.IsNew -eq $false -or $null -eq $this.DataContext.IsNew )
	}

	$syncHash.Controls.BtnHotstringSave.GetBindingExpression( [System.Windows.Controls.Button]::IsEnabledProperty ).UpdateTarget()
} )

# System for selected hotstring was changed by selecting system from existing list
$syncHash.Controls.CbHotstringListOfSystems.Add_SelectionChanged( {
	if ( $null -ne $this.DataContext )
	{
		if ( $this.DataContext.IsNew )
		{
			$this.DataContext.HasChanged = $true
		}
		else
		{
			$this.DataContext.HasChanged = $this.Text -ne $syncHash.Controls.LvHotstrings.SelectedItem.System -and `
				( $this.DataContext.IsNew -eq $false -or $null -eq $this.DataContext.IsNew )
		}

		$syncHash.Controls.BtnHotstringSave.GetBindingExpression( [System.Windows.Controls.Button]::IsEnabledProperty ).UpdateTarget()
	}
} )

# DataContext changed (a function is selected in functionlist), update the display for function header
$syncHash.Controls.GridHotstring.Add_DataContextChanged( {
	Update-FunctionHeaderText
} )

# Selected hotstring changed, clear messagequeue
$syncHash.Controls.LvHotstrings.Add_SelectionChanged( {
	$syncHash.Controls.TbHotstringCode.MaxLength = 0
	$syncHash.Controls.Window.Resources.CvsHotstringMessageQueue.Source.Clear()
	if ( $null -ne $this.SelectedItem )
	{
		$syncHash.Controls.Window.Resources.CvsHsOptionsCollection.Source | `
			ForEach-Object {
				$_.IsUsed = $syncHash.Controls.LvHotstrings.SelectedItem.Options.Name -contains $_.Name
				if ( $_.Name -eq "SI" -and $_.IsUsed )
				{
					$syncHash.Controls.TbHotstringCode.MaxLength = 5000
				}

			} `
			-End {
				$syncHash.Controls.Window.Resources.CvsHsOptionsCollection.View.Refresh()
			}
	}

	$syncHash.Controls.Window.Resources.CvsHsOptionsCollection.View.Filter = $syncHash.Code.HsOptionFilter
	$syncHash.Controls.Window.Resources.CvsHsOptionsCollection.View.Refresh()
} )

# Code/label for selected hotstring changed
$syncHash.Controls.TbHotstringCode.Add_TextChanged( {
	if ( $null -ne $this.DataContext )
	{
		if ( $this.DataContext.IsNew )
		{
			$this.DataContext.HasChanged = $true
		}
		else
		{
			$this.DataContext.HasChanged = $this.Text -ne $syncHash.Controls.LvHotstrings.SelectedItem.Value -and `
				( $this.DataContext.IsNew -eq $false -or $null -eq $this.DataContext.IsNew )
		}
	}

	$syncHash.Controls.BtnHotstringSave.GetBindingExpression( [System.Windows.Controls.Button]::IsEnabledProperty ).UpdateTarget()
} )

# Menutitle for selected hotstring was changed
$syncHash.Controls.TbHotstringMenuTitle.Add_TextChanged( {
	if ( $null -ne $this.DataContext )
	{
		if ( $this.DataContext.IsNew )
		{
			$this.DataContext.HasChanged = $true
		}
		else
		{
			if ( $this.Text -ne $syncHash.Controls.LvHotstrings.SelectedItem.MenuTitle -and `
				$this.Text -in $syncHash.Controls.Window.Resources.CvsHotstrings.Source.MenuTitle
			)
			{
				Add-OpMessage -Message $syncHash.Data.msgTable.ErrHotstringMenuTitleExists -Type "Warning" -ObjectType "Hotstring"
			}

			$this.DataContext.HasChanged = $this.Text -ne $syncHash.Controls.LvHotstrings.SelectedItem.MenuTitle -and `
				( $this.DataContext.IsNew -eq $false -or $null -eq $this.DataContext.IsNew )
		}
	}

	$syncHash.Controls.BtnHotstringSave.GetBindingExpression( [System.Windows.Controls.Button]::IsEnabledProperty ).UpdateTarget()
} )

# Name for selected hotstring was changed
$syncHash.Controls.TbHotstringName.Add_PreviewKeyDown( {
	$syncHash.Test = $args
	if ( $null -ne $this.DataContext )
	{
		# Check that Name does not contains any whitespace-characters
		if ( $args[1].Key -eq "Space" )
		{
			Add-OpMessage -Message $syncHash.Data.msgTable.StrHotstringNameContainsWhitespace -Type "Error" -ObjectType "Hotstring"
			$args[1].Handled = $true
		}
	}
} )

# Name for selected hotstring was changed
$syncHash.Controls.TbHotstringName.Add_TextChanged( {
	if ( $null -ne $this.DataContext )
	{
		if ( $this.DataContext.IsNew )
		{
			$this.DataContext.HasChanged = $true
		}
		else
		{
			if ( $this.Text -ne $syncHash.Controls.LvHotstrings.SelectedItem.Name -and `
				$this.Text -in $syncHash.Controls.Window.Resources.CvsHotstrings.Source.Name
			)
			{
				Add-OpMessage -Message $syncHash.Data.msgTable.ErrHotstringNameExists -Type "Error" -ObjectType "Hotstring"
				$this.Text = $syncHash.Controls.LvHotstrings.SelectedItem.Name
			}

			$this.DataContext.HasChanged = $this.Text -ne $syncHash.Controls.LvHotstrings.SelectedItem.Name -and `
				( $this.DataContext.IsNew -eq $false -or $null -eq $this.DataContext.IsNew )
		}
	}

	$syncHash.Controls.BtnHotstringSave.GetBindingExpression( [System.Windows.Controls.Button]::IsEnabledProperty ).UpdateTarget()
} )
# endregion Hotstring Ops

# region Variable Ops
# Selected variable added to list for extraction
$syncHash.Controls.BtnAddVariableForExtraction.Add_Click( {
	$ToExtract = $syncHash.Controls.LvVariables.SelectedItem.psobject.Copy()
	Add-Member -InputObject $ToExtract -MemberType NoteProperty -Name "Type" -Value "Variable"
	Update-Extraction $ToExtract
} )

# Remove selected variable
$syncHash.Controls.BtnVariableRemove.Add_Click( {
	$ItemToRemove = $syncHash.Controls.LvVariables.SelectedItem
	$syncHash.Controls.LvVariables.SelectedIndex = -1
	$syncHash.Controls.Window.Resources.CvsVariables.Source.Remove( $ItemToRemove )
	$syncHash.Controls.Window.Resources.CvsVariables.View.Refresh()
} )

# Save changes for selected variable
$syncHash.Controls.BtnVariableSave.Add_Click( {
	$syncHash.Controls.LvVariables.SelectedItem.Name = $syncHash.Controls.TbVariableName.Text
	$syncHash.Controls.LvVariables.SelectedItem.Value = $syncHash.Controls.TbVariableCode.Text
	if ( $syncHash.Controls.RbVariableAsLegacy.IsChecked )
	{
		$syncHash.Controls.LvVariables.SelectedItem.VariableType = "Legacy"
	}
	else
	{
		$syncHash.Controls.LvVariables.SelectedItem.VariableType = "Expression"
	}

	$syncHash.Controls.Window.Resources.CvsVariables.View.Refresh()
	if ( ( $syncHash.Controls.LvVariables.SelectedItem | Get-Member -MemberType NoteProperty ).Name -contains "IsNew" )
	{
		$syncHash.Controls.LvVariables.SelectedItem.IsNew = $false
	}
	$syncHash.Controls.LvVariables.SelectedItem.HasChanged = $false
	$syncHash.Controls.BtnVariableSave.GetBindingExpression( [System.Windows.Controls.Button]::IsEnabledProperty ).UpdateTarget()
} )

# Selection of variable was changed, clear messagequeue
$syncHash.Controls.LvVariables.Add_SelectionChanged( {
	$syncHash.Controls.Window.Resources.CvsVariableMessageQueue.Source.Clear()
} )

# Variabletype expression is selected
$syncHash.Controls.RbVariableAsExpression.Add_Checked( {
	if ( $null -ne $syncHash.Controls.GridHotkey.DataContext )
	{
		if ( $this.DataContext.IsNew )
		{
			$this.DataContext.HasChanged = $true
		}
		else
		{
			$this.DataContext.HasChanged = "Expression" -ne $syncHash.Controls.LvHotkeys.SelectedItem.VariableType -and `
				( $this.DataContext.IsNew -eq $false -or $null -eq $this.DataContext.IsNew )
		}
	}

	$syncHash.Controls.BtnHotkeySave.GetBindingExpression( [System.Windows.Controls.Button]::IsEnabledProperty ).UpdateTarget()
} )

# Variabletype legacy is selected
$syncHash.Controls.RbVariableAsLegacy.Add_Checked( {
	if ( $null -ne $syncHash.Controls.GridHotkey.DataContext )
	{
		if ( $this.DataContext.IsNew )
		{
			$this.DataContext.HasChanged = $true
		}
		else
		{
			$this.DataContext.HasChanged = "Legacy" -ne $syncHash.Controls.LvHotkeys.SelectedItem.VariableType -and `
				( $this.DataContext.IsNew -eq $false -or $null -eq $this.DataContext.IsNew )
		}
	}

	$syncHash.Controls.BtnHotkeySave.GetBindingExpression( [System.Windows.Controls.Button]::IsEnabledProperty ).UpdateTarget()
} )

# Key pressed for name of variable
$syncHash.Controls.TbVariableName.Add_PreviewKeyDown( {
	if ( $null -ne $this.DataContext )
	{
		# Check that system name does not contains any whitespace-characters
		if ( $args[1].Key -eq "Space" )
		{
			Add-OpMessage -Message $syncHash.Data.msgTable.StrVariableNameContainsWhitespace -Type "Error" -ObjectType "Variable"
			$args[1].Handled = $true
		}
	}
} )

# Name of selected variable was changed
$syncHash.Controls.TbVariableName.Add_TextChanged( {
	if ( $null -ne $syncHash.Controls.GridVariable.DataContext )
	{
		if ( $this.DataContext.IsNew )
		{
			$this.DataContext.HasChanged = $true
		}
		else
		{
			if ( $this.Text -ne $syncHash.Controls.LvVariables.SelectedItem.Name -and `
				$this.Text -in $syncHash.Controls.Window.Resources.CvsVariables.Source.Name
			)
			{
				Add-OpMessage -Message $syncHash.Data.msgTable.ErrVariableNameExists -Type "Error" -ObjectType "Variable"
				$this.Text = $syncHash.Controls.LvVariables.SelectedItem.Name
			}

			$this.DataContext.HasChanged = $this.Text -ne $syncHash.Controls.LvVariables.SelectedItem.Name -and `
				( $this.DataContext.IsNew -eq $false -or $null -eq $this.DataContext.IsNew )
		}
	}

	$syncHash.Controls.BtnVariableSave.GetBindingExpression( [System.Windows.Controls.Button]::IsEnabledProperty ).UpdateTarget()
} )

# Code/value of selected variable has changed
$syncHash.Controls.TbVariableCode.Add_TextChanged( {
	if ( $null -ne $syncHash.Controls.GridVariable.DataContext )
	{
		if ( $this.DataContext.IsNew )
		{
			$this.DataContext.HasChanged = $true
		}
		else
		{
			$this.DataContext.HasChanged = $this.Text -ne $syncHash.Controls.LvVariables.SelectedItem.Value
		}
	}

	$syncHash.Controls.BtnVariableSave.GetBindingExpression( [System.Windows.Controls.Button]::IsEnabledProperty ).UpdateTarget()
} )
# endregion Variable Ops

# region Import Ops
# Read the selected file for import
$syncHash.Controls.BtnReadFileToImport.Add_Click( {
	"Functions", "Hotkeys", "Hotstrings", "Variables" | `
		ForEach-Object {
			$syncHash.Controls.Window.Resources."CvsImport$( $_ )".Source.Clear()
			$syncHash.Controls.Window.Resources."CvsImport$( $_ )".View.Refresh()
		}

	if ( $syncHash.Controls.TbFilePathToImport.Text -match "\.xml$" )
	{
		if ( Test-Xml -XmlFile $syncHash.Controls.TbFilePathToImport.Text )
		{
			Read-XmlFile $syncHash.Controls.TbFilePathToImport.Text
		}
	}
	elseif ( $syncHash.Controls.TbFilePathToImport.Text -match "\.json$" )
	{
		Read-JsonFile -Path $syncHash.Controls.TbFilePathToImport.Text
	}

	$syncHash.Controls.SpImpOpButtons.IsEnabled = $true
} )

# Select all available objects from file
$syncHash.Controls.BtnSelectAll.Add_Click( {
	"Functions", "Hotstrings", "Variables" | `
		ForEach-Object {
			$syncHash.Controls."ChbImp$( $_ )SelectAll".IsChecked = $true
		}
} )

# Deselect all available objects from file
$syncHash.Controls.BtnDeselectAll.Add_Click( {
	"Functions", "Hotstrings", "Variables" | `
		ForEach-Object {
			$syncHash.Controls."ChbImp$( $_ )SelectAll".IsChecked = $false
		}
} )

# Selected a file for import
$syncHash.Controls.BtnSelectFileToImport.Add_Click( {
	$FileDialog = [Microsoft.Win32.OpenFileDialog]::new()
	$FileDialog.Multiselect = $false
	$FileDialog.InitialDirectory = $env:USERPROFILE
	$FileDialog.Filter = "$( $syncHash.Data.msgTable.StrImpFileFilterDesc )|*.xml;*.json"
	if ( $FileDialog.ShowDialog() )
	{
		$syncHash.Controls.TbFilePathToImport.Text = $FileDialog.FileName
	}
} )

# Select all available hotkeys from file
$syncHash.Controls.ChbImpHotkeysSelectAll.Add_Checked( {
	$syncHash.Controls.Window.Resources.CvsImportHotkeys.Source | `
		ForEach-Object {
			$_.ImportThis = $true
		}
	$syncHash.Controls.Window.Resources.CvsImportHotkeys.View.Refresh()
} )

# Deselect all available hotkeys from file
$syncHash.Controls.ChbImpHotkeysSelectAll.Add_Unchecked( {
	$syncHash.Controls.Window.Resources.CvsImportHotkeys.Source | `
		ForEach-Object {
			$_.ImportThis = $false
		}
	$syncHash.Controls.Window.Resources.CvsImportHotkeys.View.Refresh()
} )

# Select all available hotstrings from file
$syncHash.Controls.ChbImpHotstringsSelectAll.Add_Checked( {
	$syncHash.Controls.Window.Resources.CvsImportHotstrings.Source | `
		ForEach-Object {
			$_.ImportThis = $true
		}
	$syncHash.Controls.Window.Resources.CvsImportHotstrings.View.Refresh()
} )

# Deselect all available hotstrings from file
$syncHash.Controls.ChbImpHotstringsSelectAll.Add_Unchecked( {
	$syncHash.Controls.Window.Resources.CvsImportHotstrings.Source | `
		ForEach-Object {
			$_.ImportThis = $false
		}
	$syncHash.Controls.Window.Resources.CvsImportHotstrings.View.Refresh()
} )

# Select all available functions from file
$syncHash.Controls.ChbImpFunctionsSelectAll.Add_Checked( {
	$syncHash.Controls.Window.Resources.CvsImportFunctions.Source | `
		ForEach-Object {
			$_.ImportThis = $true
		}
	$syncHash.Controls.Window.Resources.CvsImportFunctions.View.Refresh()
} )

# Deselect all available functions from file
$syncHash.Controls.ChbImpFunctionsSelectAll.Add_Unchecked( {
	$syncHash.Controls.Window.Resources.CvsImportFunctions.Source | `
		ForEach-Object {
			$_.ImportThis = $false
		}
	$syncHash.Controls.Window.Resources.CvsImportFunctions.View.Refresh()
} )

# Select all available variables from file
$syncHash.Controls.ChbImpVariablesSelectAll.Add_Checked( {
	$syncHash.Controls.Window.Resources.CvsImportVariables.Source | `
		ForEach-Object {
			$_.ImportThis = $true
		}
	$syncHash.Controls.Window.Resources.CvsImportVariables.View.Refresh()
} )

# Deselect all available variables from file
$syncHash.Controls.ChbImpVariablesSelectAll.Add_Unchecked( {
	$syncHash.Controls.Window.Resources.CvsImportVariables.Source | `
		ForEach-Object {
			$_.ImportThis = $false
		}
	$syncHash.Controls.Window.Resources.CvsImportVariables.View.Refresh()
} )

# Abort import by removing all read data
$syncHash.Controls.BtnAbortImport.Add_Click( {
	"Functions", "Hotkeys", "Hotstrings", "Variables" | `
		ForEach-Object {
			$syncHash.Controls.Window.Resources."CvsImport$( $_ )".Source.Clear()
		}
	$syncHash.Controls.TbFilePathToImport.Text = ""
} )

# Copy all selected object to current autohotkey-data
$syncHash.Controls.BtnStartImport.Add_Click( {
	$syncHash.Data.Imports = [System.Collections.ArrayList]::new()
	$syncHash.Controls.Window.Resources.CvsImportHotkeys.Source | `
		Where-Object { $_.ImportThis } | `
		ForEach-Object `
		-Process {
			$Item = $_.psobject.Copy()

			# Verify that name and hotkey is not already used
			if ( $syncHash.Controls.Window.Resources.CvsHotkeys.Source.Where( { $_.Hotkey -eq $Item.Hotkey } ).Count -eq 0 )
			{
				if ( $syncHash.Controls.Window.Resources.CvsHotkeys.Source.Where( { $_.Name -eq $Item.Name } ).Count -gt 1 )
				{
					$Item.Name = "$( $Item.Name )_2"
				}
				Add-Member -InputObject $Item -MemberType NoteProperty -Name "HasChanged" -Value $false
				$syncHash.Controls.Window.Resources.CvsHotkeys.Source.Add( $Item )
				$syncHash.Data.Imports.Add( $Item ) | Out-Null
			}
			else
			{
				Add-Member -InputObject $_ -MemberType NoteProperty -Name "ImportError" -Value $syncHash.Data.msgTable.ErrImpHotkeyHotkeyExists
			}
		} `
		-End {
			$syncHash.Controls.Window.Resources.CvsHotkeys.View.Refresh()
		}
	# Remove imported objects from importlist
	$syncHash.Data.Imports | `
		ForEach-Object `
		-Process {
			$Added = $_.psobject.Copy()
			$i = $syncHash.Controls.Window.Resources.CvsImportHotkeys.Source.Where( { $_.Hotkey -eq $Added.Hotkey } )[0]
			$syncHash.Controls.Window.Resources.CvsImportHotkeys.Source.Remove( $i )
		} `
		-End {
			$syncHash.Controls.Window.Resources.CvsImportHotkeys.View.Refresh()
		}

	$syncHash.Data.Imports.Clear()
	$syncHash.Controls.Window.Resources.CvsImportHotstrings.Source | `
		Where-Object { $_.ImportThis } | `
		ForEach-Object `
		-Process {
			$Item = $_.psobject.Copy()

			# Verify that name is not already used
			if ( $syncHash.Controls.Window.Resources.CvsHotstrings.Source.Where( { $_.Name -eq $Item.Name } ).Count -eq 0 )
			{
				Add-Member -InputObject $Item -MemberType NoteProperty -Name "HasChanged" -Value $false
				$syncHash.Controls.Window.Resources.CvsHotstrings.Source.Add( $Item )
				$syncHash.Data.Imports.Add( $Item ) | Out-Null
			}
			else
			{
				Add-Member -InputObject $_ -MemberType NoteProperty -Name "ImportError" -Value $syncHash.Data.msgTable.ErrImpHotstringNameExists
			}
		} `
		-End {
			$syncHash.Controls.Window.Resources.CvsImportHotstrings.Source | `
				Where-Object { $_.ImportThis } | `
				Select-Object -ExpandProperty System -Unique | `
				ForEach-Object {
					Edit-HotstringSystems -NewSystem $_
				}
			$syncHash.Controls.Window.Resources.CvsHotstrings.View.Refresh()
		}
	# Remove imported objects from importlist
	$syncHash.Data.Imports | `
		ForEach-Object `
		-Process {
			$Added = $_
			$i = $syncHash.Controls.Window.Resources.CvsImportHotstrings.Source.Where( { $_.Name -eq $Added.Name } )[0]
			$syncHash.Controls.Window.Resources.CvsImportHotstrings.Source.Remove( $i )
		} `
		-End {
			$syncHash.Controls.Window.Resources.CvsImportHotstrings.View.Refresh()
		}

	$syncHash.Data.Imports.Clear()
	$syncHash.Controls.Window.Resources.CvsImportVariables.Source | `
		Where-Object { $_.ImportThis } | `
		ForEach-Object `
		-Process {
			$Item = $_.psobject.Copy()

			# Verify that name is not already used
			if ( $syncHash.Controls.Window.Resources.CvsVariables.Source.Where( { $_.Name -eq $Item.Name } ).Count -eq 0 )
			{
				Add-Member -InputObject $Item -MemberType NoteProperty -Name "HasChanged" -Value $false
				if ( ( $Item | Get-Member ).Name -notcontains "VariableType" )
				{
					Add-Member -InputObject $Item -MemberType NoteProperty -Name "VariableType" -Value "Legacy"
				}

				$syncHash.Controls.Window.Resources.CvsVariables.Source.Add( $Item )
				$syncHash.Data.Imports.Add( $Item ) | Out-Null
			}
			else
			{
				Add-Member -InputObject $_ -MemberType NoteProperty -Name "ImportError" -Value $syncHash.Data.msgTable.ErrImpVariableNameExists
			}
		} `
		-End {
			$syncHash.Controls.Window.Resources.CvsVariables.View.Refresh()
		}
	# Remove imported objects from importlist
	$syncHash.Data.Imports | `
		ForEach-Object `
		-Process {
			$Added = $_
			$i = $syncHash.Controls.Window.Resources.CvsImportVariables.Source.Where( { $_.Name -eq $Added.Name } )[0]
			$syncHash.Controls.Window.Resources.CvsImportVariables.Source.Remove( $i )
		} `
		-End {
			$syncHash.Controls.Window.Resources.CvsImportVariables.View.Refresh()
		}

	$syncHash.Data.Imports.Clear()
	$syncHash.Controls.Window.Resources.CvsImportFunctions.Source | `
		Where-Object { $_.ImportThis } | `
		ForEach-Object `
		-Process {
			$Item = $_.psobject.Copy()

			# Verify that name is not already used
			if ( $syncHash.Controls.Window.Resources.CvsFunctions.Source.Where( { $_.Name -eq $Item.Name } ).Count -eq 0 )
			{
				Add-Member -InputObject $Item -MemberType NoteProperty -Name "HasChanged" -Value $false
				$Item.ParameterList | `
					ForEach-Object {
						Add-Member -InputObject $_ -MemberType NoteProperty -Name "Removed" -Value $false
					}
				$syncHash.Controls.Window.Resources.CvsFunctions.Source.Add( $Item )
				$syncHash.Data.Imports.Add( $Item ) | Out-Null
			}
			else
			{
				Add-Member -InputObject $_ -MemberType NoteProperty -Name "ImportError" -Value $syncHash.Data.msgTable.ErrImpFunctionNameExists
			}
		} `
		-End {
			$syncHash.Controls.Window.Resources.CvsFunctions.View.Refresh()
		}
	# Remove imported objects from importlist
	$syncHash.Data.Imports | `
		ForEach-Object `
		-Process {
			$Added = $_
			$i = $syncHash.Controls.Window.Resources.CvsImportFunctions.Source.Where( { $_.Name -eq $Added.Name } )[0]
			$syncHash.Controls.Window.Resources.CvsImportFunctions.Source.Remove( $i )
		} `
		-End {
			$syncHash.Controls.Window.Resources.CvsImportFunctions.View.Refresh()
		}

	if ( $syncHash.Controls.Window.Resources.CvsImportHotkeys.Source.Count -gt 0 -or `
		$syncHash.Controls.Window.Resources.CvsImportHotstrings.Source.Count -gt 0 -or `
		$syncHash.Controls.Window.Resources.CvsImportFunctions.Source.Count -gt 0 -or `
		$syncHash.Controls.Window.Resources.CvsImportVariables.Source.Count -gt 0
	)
	{
		Add-OpMessage -Message $syncHash.Data.msgTable.ErrImportFailedSummary -Type "Error" -ObjectType "Import" -Clear
	}
} )

# Specified path for importfile has changed
$syncHash.Controls.TbFilePathToImport.Add_TextChanged( {
	$syncHash.Controls.BtnReadFileToImport.IsEnabled = $false
	$syncHash.Controls.SpImpOpButtons.IsEnabled = $false
	"Functions", "Hotkeys", "Hotstrings", "Variables" | `
		ForEach-Object {
			$syncHash.Controls.Window.Resources."CvsImport$( $_ )".Source.Clear()
			$syncHash.Controls.Window.Resources."CvsImport$( $_ )".View.Refresh()
		}
	Add-OpMessage -ObjectType "Import" -Clear

	if ( $this.Text -ne "" )
	{
		if ( Test-Path $this.Text )
		{
			if ( $this.Text -match "\.(xml)|(json)$" )
			{
				$syncHash.Controls.BtnReadFileToImport.IsEnabled = $true
			}
			else
			{
				Add-OpMessage -Message $syncHash.Data.msgTable.ErrImpFileInvalidExtention -Type "Error" -ObjectType "Import" -Clear
			}
		}
		else
		{
			Add-OpMessage -Message $syncHash.Data.msgTable.ErrImpFileNotFound -Type "Error" -ObjectType "Import" -Clear
		}
	}
} )
# endregion Import Ops

# Window (page) has bee loaded, if it hasn't previously been loaded, read data from userprofile
$syncHash.Controls.Window.Add_Loaded( {
	if ( -not $syncHash.Data.HasBeenLoaded )
	{
		$HotkeysDuplicates = [System.Collections.ArrayList]::new()
		$HotstringsDuplicates = [System.Collections.ArrayList]::new()
		$VariablesDuplicates = [System.Collections.ArrayList]::new()
		$FunctionsDuplicates = [System.Collections.ArrayList]::new()
		$syncHash.Data.AhkData = ( Get-Content -Path "$( $env:USERPROFILE )\AHKUpdaterData.json" | ConvertFrom-Json )

		$syncHash.Data.AhkData | `
			Get-Member -MemberType NoteProperty | `
			ForEach-Object `
			-Process {
				$TypeName = $_.Name
				$syncHash.Data.AhkData."$( $TypeName )" | `
					ForEach-Object {
						$F = $_
						if ( $TypeName -eq "Settings" )
						{
							Add-Member -InputObject $F -MemberType NoteProperty -Name "LocalizedTt" -Value $syncHash.Data.msgTable."StrSetting$( $F.Name )TtInfo"
							Add-Member -InputObject $F -MemberType NoteProperty -Name "LocalizedName" -Value $syncHash.Data.msgTable."StrSetting$( $F.Name )Name"
							Add-Member -InputObject $F -MemberType NoteProperty -Name "SettingInfo" -Value ""

							if ( $F.Name -match "Path$" )
							{
								Add-Member -InputObject $F -MemberType NoteProperty -Name "Suggestions" -Value ( [System.Collections.ObjectModel.ObservableCollection[object]]::new() )
							}

							if ( $syncHash.Controls.Window.Resources."Cvs$( $TypeName )$( $F.SettingGroup )".Source -notcontains $F.Name )
							{
								$syncHash.Controls.Window.Resources."Cvs$( $TypeName )$( $F.SettingGroup )".Source.Add( $F )
							}
						}
						elseif ( $TypeName -eq "ScriptComment" )
						{
							$syncHash.Controls.TbScriptComment.Text = $_
						}
						else
						{
							Add-Member -InputObject $F -MemberType NoteProperty -Name "HasChanged" -Value $false

							if ( $TypeName -eq "Variables" )
							{
								if ( ( $F | Get-Member -MemberType NoteProperty ).Name -notcontains "Value" )
								{
									Add-Member -InputObject $F -MemberType NoteProperty -Name "Value" -Value ""
								}

								if ( ( $F | Get-Member -MemberType NoteProperty ).Name -notcontains "VariableType" )
								{
									Add-Member -InputObject $F -MemberType NoteProperty -Name "VariableType" -Value "Legacy"
								}
							}
							if ( $F.ParameterList.Count -gt 0 )
							{
								$F.ParameterList = [System.Collections.ObjectModel.ObservableCollection[object]]::new( $F.ParameterList )
								$F.ParameterList | `
									ForEach-Object {
										Add-Member -InputObject $_ -MemberType NoteProperty -Name "Removed" -Value $false
										Add-Member -InputObject $_ -MemberType NoteProperty -Name "OriginalName" -Value $_.Name
									}
								$F.ParameterList.Add_CollectionChanged( {
									Update-FunctionHeaderText
								} )
							}
							if ( $TypeName -eq "Hotstrings" )
							{
								if ( $F.Options.Count -eq 1 )
								{
									$O = $F.Options[0]
									$F.Options = [System.Collections.ObjectModel.ObservableCollection[object]]::new()

									Add-Member -InputObject $O -MemberType NoteProperty -Name "OptionCode" -Value $syncHash.Controls.Window.Resources.CvsHsOptionsCollection.Source.Where( { $_.Name -eq $O.Name } )[0].OptionCode
									Add-Member -InputObject $O -MemberType NoteProperty -Name "IsUsed" -Value $true
									Add-Member -InputObject $O -MemberType NoteProperty -Name "Tt" -Value $syncHash.Data.msgTable."StrHsOption$( $O.Name )"
									$F.Options.Add( $O )
								}
								elseif ( $F.Options.Count -gt 1 )
								{
									$OL = $F.Options
									$F.Options = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
									$OL | `
										ForEach-Object {
											$O = $_
											Add-Member -InputObject $_ -MemberType NoteProperty -Name "OptionCode" -Value $syncHash.Controls.Window.Resources.CvsHsOptionsCollection.Source.Where( { $_.Name -eq $O.Name } )[0].OptionCode
											Add-Member -InputObject $_ -MemberType NoteProperty -Name "IsUsed" -Value $true
											Add-Member -InputObject $_ -MemberType NoteProperty -Name "Tt" -Value $syncHash.Data.msgTable."StrHsOption$( $O.Name )"
											$F.Options.Add( $O )
										}
								}
								else
								{
									$F.Options = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
								}
							}

							if ( $TypeName -eq "Hotkeys" )
							{
								if ( $syncHash.Controls.Window.Resources."Cvs$( $TypeName )".Source.Hotkey -notcontains $F.Hotkey )
								{
									$syncHash.Controls.Window.Resources."Cvs$( $TypeName )".Source.Add( $F )
								}
								else
								{
									( Get-Variable -Name "$( $TypeName )Duplicates" ).Value.Add( $F.Name )
								}
							}
							else
							{
								if ( $syncHash.Controls.Window.Resources."Cvs$( $TypeName )".Source.Name -notcontains $F.Name )
								{
									$syncHash.Controls.Window.Resources."Cvs$( $TypeName )".Source.Add( $F )
								}
								else
								{
									( Get-Variable -Name "$( $TypeName )Duplicates" ).Value.Add( $F.Name )
								}
							}
						}
					}
			} `
			-End {
				$Duplicates = ""
				"Hotkeys", "Hotstrings", "Variables", "Functions" | `
					ForEach-Object {
						if ( ( Get-Variable -Name "$( $_ )Duplicates" ).Value.Count -gt 0 )
						{
							$Duplicates += " $( $syncHash.Data.msgTable."StrImpDupPrefix$( $_ )" ): $( ( Get-Variable -Name "$( $_ )Duplicates" ).Value -join ", " ) |"
						}
					}
				if ( "" -ne $Duplicates )
				{
					Add-OpMessage -Message "$( $syncHash.Data.msgTable.StrImportDuplicates ) $( $Duplicates.Trim( " |" ).Trim() )" -Type "Warning" -ObjectType "FileInfo"
				}
				else
				{
					Add-OpMessage -Message "$( $syncHash.Data.msgTable.StrAhkDataRead ): $( $env:USERPROFILE )\AHKUpdaterData.json" -Type "Success" -ObjectType "FileInfo"
				}
			}

		"BackupPath", "ScriptPath" | `
			ForEach-Object {
				$N = $_
				$syncHash.Controls.Window.Resources.CvsSettingsFiles.Source.Where( { $_.Name -eq $N } )[0].Suggestions.Add( ( Get-ADUser -LDAPFilter "(Mail=$( ( Get-ADUser $env:USERNAME -Properties ContactMail ).ContactMail ))" -Properties Mail, HomeDirectory ).HomeDirectory )
			}

		$syncHash.Data.AhkData.Hotstrings.System | `
			Select-Object -Unique | `
			ForEach-Object {
				Edit-HotstringSystems -NewSystem $_
			}

		$syncHash.Controls.Window.Resources.CvsHotstrings.View.Filter = $syncHash.Code.HotstringBySystemFilter
		$syncHash.Data.HasBeenLoaded = $true
	}

	if ( "" -eq ( Get-Setting "ScriptPath" "Files" ) )
	{
		Show-Splash -Text $syncHash.Data.msgTable.StrInfoNoPathsSelected -NoProgressBar -NoTitle -Duration 1.0
		$syncHash.Controls.TcMain.SelectedIndex = $syncHash.Controls.TcMain.Items.Count - 1
	}
} )
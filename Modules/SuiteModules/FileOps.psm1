<#
.Synopsis
	A module for functions operating on files
.Description
	A module for functions operating on files
.State
	Prod
.Author
	Smorkster (smorkster)
#>

param ( $culture = "sv-SE" )

##############################
##    Internal functions    ##
##############################

enum Success {
	Success = 1
	Failed = 0
}

enum ErrorSeverity {
	UserInputFail = 0
	ScriptLogicFail = 1
	ConnectionFail = 2
	PermissionFail = 3
	ScriptAborted = 4
	OtherFail = -1
}

class ErrorLog
{
	<#
	.Synopsis A class to define content for errorlog
	#>

	[ValidateNotNullOrEmpty()] [string] $ErrorMessage
	[ValidateNotNullOrEmpty()] [string] $UserInput
	[ValidateNotNullOrEmpty()] [ErrorSeverity] $Severity
	[string] $LogDate
	[string] $Operator

	ErrorLog ()
	{
		$this.ErrorMessage = "<Empty>"
		$this.UserInput = "<Empty>"
		$this.Severity = -1
	}

	ErrorLog ( $ErrorMessage, $UserInput, $Severity )
	{
		$this.ErrorMessage = $ErrorMessage
		$this.UserInput = $UserInput
		$this.Severity = $Severity
	}

	ErrorLog ( [pscustomobject] $o )
	{
		$this.ErrorMessage = $o.ErrorMessage
		$this.UserInput = $o.UserInput
		$this.Severity = $o.Severity
		$this.LogDate = $o.LogDate
		$this.Operator = $o.Operator
	}

	[string] ToJson()
	{
		$this.LogDate = ( Get-Date -Format "yyyy-MM-dd HH:mm:ss" )
		$this.Operator = ( [Environment]::UserName )
		return $this | ConvertTo-Json -Compress
	}
}

class ErrorLogExt : ErrorLog
{
	[string] $ComputerName

	ErrorLogExt ( [pscustomobject] $o )
	{
		$this.ErrorMessage = $o.ErrorMessage
		$this.UserInput = $o.UserInput
		$this.Severity = $o.Severity
		$this.LogDate = $o.LogDate
		$this.Operator = $o.Operator
		$this.ComputerName = $o.ComputerName
	}

}

class Log
{
	<#
	.Synopsis A class to define log content
	#>

	[string] $LogText
	[string] $UserInput
	[ValidateNotNullOrEmpty()] [Success] $Success
	[array] $ErrorLogDate
	[string] $ErrorLogFile
	[array] $OutputFile
	[string] $LogDate
	[string] $Operator

	Log()
	{
		$this.Success = 0
	}


	Log ( $Text, $UserInput, $Success )
	{
		$this.LogText = $Text
		$this.UserInput = $UserInput
		$this.Success = $Success
	}

	Log ( [pscustomobject] $o )
	{
		$this.LogDate = $o.LogDate
		$this.LogText = $o.LogText
		$this.UserInput = $o.UserInput
		$this.Success = $o.Success
		$this.ErrorLogFile = $o.ErrorLogFile
		$this.ErrorLogDate = $o.ErrorLogDate
		$this.OutputFile = $o.OutputFile
		$this.Operator = $o.Operator
	}

	[string] ToJson()
	{
		$this.LogDate = ( Get-Date -Format "yyyy-MM-dd HH:mm:ss" )
		$this.Operator = ( [Environment]::UserName )
		return $this | ConvertTo-Json -Compress
	}
}

class LogExt : Log
{
	[string] $ComputerName

	LogExt ( [pscustomobject] $o )
	{
		$this.LogDate = $o.LogDate
		$this.LogText = $o.LogText
		$this.UserInput = $o.UserInput
		$this.Success = $o.Success
		$this.ErrorLogFile = $o.ErrorLogFile
		$this.ErrorLogDate = $o.ErrorLogDate
		$this.OutputFile = $o.OutputFile
		$this.Operator = $o.Operator
		$this.ComputerName = $o.ComputerName
	}
}

class Survey
{
	<#
	.Synopsis A class to define survey content
	#>

	[string] $ScriptVersion
	[int] $Rating = 0
	[string] $Comment
	[string] $Operator
	[string] $LogDate

	Survey ()
	{
		$this.ScriptVersion = ""
		$this.Rating = 0
		$this.Comment = ""
	}

	Survey ( $ScriptVersion, $Rating, $Comment )
	{
		$this.ScriptVersion = $ScriptVersion
		$this.Rating = $Rating
		$this.Comment = $Comment
	}

	Survey ( [pscustomobject] $o )
	{
		$this.ScriptVersion = $o.ScriptVersion
		$this.Rating = $o.Rating
		$this.Comment = $o.Comment
		$this.Operator = $o.Operator
		$this.LogDate = $o.LogDate
	}

	[string] ToJson()
	{
		$this.LogDate = ( Get-Date -Format "yyyy-MM-dd HH:mm:ss" )
		$this.Operator = ( [Environment]::UserName )
		return $this | ConvertTo-Json -Compress
	}

	[void] Clear()
	{
		$this.ScriptVersion = ""
		$this.Rating = 0
		$this.Comment = ""
	}
}

function Get-LogFilePath
{
	<#
	.Description
		Create the path for the file to write. If the file does not exist, create it.
	.Parameter TopFolder
		Where is the file located
	.Parameter SubFolder
		Are a specific subfolder used, or is the hierarchy based on date
	.Parameter FileName
		Name of the logfile
	#>

	param ( $TopFolder, $SubFolder, $FileName )

	$Path = "{0}\{1}\{2}\{3}" -f $RootDir, $TopFolder, "$( if ( $SubFolder ) { $SubFolder } else { "$( [datetime]::Now.Year )\$( [datetime]::Now.Month )" } )", $FileName

	if ( -not ( Test-Path $Path ) )
	{
		New-Item -Path $Path -ItemType File -Force | Out-Null
	}

	return $Path
}

##############################
##    Exported functions    ##
##############################

function EndScript
{
	<#
	.Synopsis
		Print a message to inform that the script have finished and can be exited
	.Description
		Print a message to inform that the script have finished and can be exited, i.e. the console window can be closed.
		If text happens to be entered, it will be added to a dummy-file, just for (possible) laughs.
	.Parameter Text
		Text to display, if other than default
	#>

	param ( [string]$Text = $IntmsgTable.FileOpsEndScript )

	$dummy = Read-Host "`n$( $Text )"
	if ( $dummy -ne "" )
	{
		$mtx = [System.Threading.Mutex]::new( $false, "EndScript $( $CallingScript.Name )" )
		$mtx.WaitOne()
		Add-Content -Path "$RootDir\Logs\DummyQuitting.json" -Value ( [pscustomobject]@{ Date = $nudate; Operator = ( [Environment]::UserName ); Text = $( $CallingScript.BaseName ) - $dummy } | ConvertTo-Json )
		$mtx.ReleaseMutex()
	}
}

function GetScriptInfo
{
	<#
	.Synopsis
		Get code information for assigned code
	.Description
		Get the information about the code
	.Parameter FilePath
		Filepath to the scriptfile
	.Parameter Text
		Code text, such as function
	.Parameter Function
		A functioninfo object
	.Parameter InfoObject
		Object returned, containing scriptinfo
	.Parameter NoErrorRecord
		Indicate if error should be thrown for malformed textblock
	.Outputs
		A PsCustomObject with the code information
	.State
		Prod
	.Author
		Smorkster (smorkster)
	#>

	param (
	[ Parameter( Mandatory = $true,
		Position = 0,
		ParameterSetName = 'Path' ) ]
		$FilePath,
	[ Parameter( Mandatory = $true,
		Position = 0,
		ParameterSetName = 'Code' ) ]
		[string] $Text,
	[ Parameter( Mandatory = $true,
		Position = 0,
		ParameterSetName = 'Fi' ) ]
		[System.Management.Automation.FunctionInfo] $Function,
		[pscustomobject] $InfoObject,
		[switch] $NoErrorRecord
	)

	# Create object if not present in parameters
	if ( $null -eq $InfoObject )
	{
		$InfoObject = [pscustomobject]@{}
	}

	# Determine if text to parse was passed, otherwise get the text from file
	if ( $FilePath )
	{
		try
		{
			$ResolvedFilePath = Resolve-Path $FilePath -ErrorAction Stop
			$FileContent = Get-Content $ResolvedFilePath.Path -Raw -ErrorAction Stop
			$Name = ( Get-Item $ResolvedFilePath ).Name
			if ( [string]::IsNullOrEmpty( $InfoObject.Name ) )
			{
				Add-Member -InputObject $InfoObject -MemberType NoteProperty -Name "Name" -Value ( ( Get-Item $ResolvedFilePath.Path ).BaseName ) -Force
			}
		}
		catch
		{
			return $null
		}
	}
	elseif ( $Function )
	{
		$FileContent = $Function.Definition
		$Name = $Function.Name
		if ( [string]::IsNullOrEmpty( $InfoObject.Name ) )
		{
			Add-Member -InputObject $InfoObject -MemberType NoteProperty -Name "Name" -Value $Function.Name -Force
		}
	}
	else
	{
		$FileContent = $Text
		$Name = "Text"
		if ( [string]::IsNullOrEmpty( $InfoObject.Name ) )
		{
			Add-Member -InputObject $InfoObject -MemberType NoteProperty -Name "Name" -Value "?" -Force
		}
	}

	# Separate infoblock from rest of the script text
	if ( $FileContent -match "(?s)<#(?<Info>.*?)#>" )
	{
		# Parse the info block
		$Matches.Info -split "(?m)^\s*\." | `
			Where-Object { $_ } | `
			ForEach-Object `
				-Begin {
					$ListInputData = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
				} `
				-Process {
					$_ -match "\s*(?<InfoType>(?!(Parameter)|(Outputs))\w+)\s+(?<Rest>.*)" | Out-Null
					$InfoType = $Matches.InfoType.Trim()
					$Rest = $Matches.Rest.Trim()
					if ( "InputData" -eq $InfoType )
					{
						$Name, $Mandatory, $Desc = $Rest -split ",", 3
						try
						{
							$ListInputData.Add( (
								[pscustomobject]@{
									Name = $Name
									InputType = "String"
									Mandatory = "True" -eq $Mandatory.Trim()
									InputDescription = $Desc.Trim()
									EnteredValue = ""
								}
							) ) | Out-Null
						}
						catch
						{
							Write-Warning "$( $IntmsgTable.ErrGetScriptInfoAddInputData )`n$( $Rest )`n$( $_ )"
						}
					}
					elseif ( "InputDataList" -eq $InfoType )
					{
						$Rest -match "^\s*(?<InputVar>\w+).*?\|\s*(?<Mandatory>\w*)\s*?\|(?<Desc>.*?)\|\s*(?<DefaultValue>\w*)\s*\|(?<InputList>.*)" | Out-Null
						$ListInputData.Add( (
							[pscustomobject]@{
								Name = $Matches.InputVar.Trim()
								InputDescription = $Matches.Desc.Trim()
								InputType = "List"
								InputList = [System.Collections.ArrayList] ( $Matches.InputList.Trim() -split "," )
								DefaultValue = $Matches.DefaultValue.Trim()
								Mandatory = "True" -eq $Matches.Mandatory.Trim()
								EnteredValue = ""
							}
						) ) | Out-Null
					}
					elseif ( "InputDataBool" -eq $InfoType )
					{
						$Name, $Desc = $Rest -split ",", 2
						$ListInputData.Add( (
							[pscustomobject]@{
								Name = $Name.Trim()
								InputType = "Bool"
								InputDescription = $Desc.Trim()
								EnteredValue = $false
							}
						) ) | Out-Null
					}
					elseif ( "NoRunspace" -eq $InfoType )
					{
						Add-Member -InputObject $InfoObject -MemberType NoteProperty -Name "NoRunspace" -Value $true -Force
					}
					elseif ( "Note" -eq $InfoType )
					{
						$Rest -match "^\s*(?<NoteType>\w+).*?\|\s*(?<NoteText>.*)" | Out-Null
						if ( $Matches.NoteType.Trim() -eq "Info" -or $Matches.NoteType.Trim() -eq "Warning" )
						{
							$Note = [pscustomobject]@{
								NoteType = $Matches.NoteType.Trim()
								NoteText = $Matches.NoteText.Trim()
							}
						}
						Add-Member -InputObject $InfoObject -MemberType NoteProperty -Name "Note" -Value $Note -Force
					}
					elseif ( $InfoType -match "(?:In)*valid(?:ate)*(?:(?:Start)|(?:End))*DateTime" )
					{
						try
						{
							$Date = [datetime]::Parse( $Rest )
							Add-Member -InputObject $InfoObject -MemberType NoteProperty -Name $InfoType -Value $Date -Force
						}
						catch
						{
							Write-Host "$( $IntmsgTable.ErrGetScriptInfoAddValidDate ) $( $InfoType ): $( $Rest )`n$( $_ )"
						}
					}
					else
					{
						Add-Member -InputObject $InfoObject -MemberType NoteProperty -Name $InfoType -Value $Rest -Force
					}
				} `
				-End {
					if ( $ListInputData.Count -gt 0 )
					{
						Add-Member -InputObject $InfoObject -MemberType NoteProperty -Name "InputData" -Value $ListInputData -Force
					}
				}

				if ( $InfoObject.psobject.Members.Name -Match "(?:In)*valid(?:ate)*(?:(?:Start)|(?:End))*DateTime" )
				{
					$Date = Get-Date
					$DateTimeFormats = [System.Globalization.CultureInfo]::CurrentCulture.DateTimeFormat
					Add-Member -InputObject $InfoObject -MemberType NoteProperty -Name ValidDateApproved -Value $true

					if ( ( $InfoObject.ValidStartDateTime -and $InfoObject.InvalidateDateTime ) -and `
						( $InfoObject.ValidStartDateTime -le $InfoObject.InvalidateDateTime )
					)
					{
						if ( ( $Date -ge $InfoObject.ValidStartDateTime -or $Date.Date -ge $InfoObject.ValidStartDateTime ) -and `
							( $Date -le $InfoObject.InvalidateDateTime -or $Date.Date -le $InfoObject.InvalidateDateTime )
						)
						{
							$ValidDateNote = "$( $IntmsgTable.StrValidDateNotePrefixBetween ) $( Get-Date $InfoObject.ValidStartDateTime -Format "$( $DateTimeFormats.ShortDatePattern ) $( $DateTimeFormats.LongTimePattern )" ) - $( Get-Date $InfoObject.InvalidateDateTime -Format "$( $DateTimeFormats.ShortDatePattern ) $( $DateTimeFormats.LongTimePattern )" )"
						}
						else
						{
							$InfoObject.ValidDateApproved = $false
						}
					}
					elseif ( $InfoObject.ValidStartDateTime )
					{
						if ( $Date -lt $InfoObject.ValidStartDateTime )
						{
							$InfoObject.ValidDateApproved = $false
						}
						else
						{
							$ValidDateNote = "$( $IntmsgTable.StrValidDateNotePrefixFrom ) $( Get-Date $InfoObject.ValidStartDateTime -Format "$( $DateTimeFormats.ShortDatePattern ) $( $DateTimeFormats.LongTimePattern )" )"
						}
					}
					elseif ( $InfoObject.InvalidateDateTime )
					{
						if ( $Date -gt $InfoObject.InvalidateDateTime )
						{
							$InfoObject.ValidDateApproved = $false
						}
						else
						{
							$ValidDateNote = "$( $IntmsgTable.StrValidDateNotePrefixUntil ) $( Get-Date $InfoObject.InvalidateDateTime -Format "$( $DateTimeFormats.ShortDatePattern ) $( $DateTimeFormats.LongTimePattern )" )"
						}
					}

					if ( $InfoObject.ValidDateApproved )
					{
						Add-Member -InputObject $InfoObject -MemberType NoteProperty -Name "ValidDateNote" -Value $ValidDateNote
					}
				}


			if ( [string]::IsNullOrEmpty( $InfoObject.MenuItem ) )
			{
				if ( [string]::IsNullOrEmpty( $InfoObject.Synopsis ) )
				{
					$MenuItemText = $InfoObject.Name
				}
				else
				{
					$MenuItemText = $InfoObject.Synopsis
				}

				try
				{
					Add-Member -InputObject $InfoObject -MemberType NoteProperty -Name "MenuItem" -Value $MenuItemText.Trim() -Force
				}
				catch
				{
					[System.Windows.MessageBox]::Show( $_.Exception.Message ) | Out-Null
				}
			}

		Add-Member -InputObject $InfoObject -MemberType NoteProperty -Name "IsSubMenuHeader" -Value 0
		return $InfoObject
	}
	else
	{
		if ( -not $NoErrorRecord )
		{
			if ( $FilePath )
			{
				throw "$( $Name ): $( $IntmsgTable.ErrGetScriptInfoNotScriptInfo )"
			}
			elseif ( $Function )
			{
				throw "$( $Name ): $( $IntmsgTable.ErrGetFunctionInfoNotScriptInfo )"
			}
			else
			{
				throw "$( $Name ): $( $IntmsgTable.ErrGetTextInfoNotScriptInfo )`n$( $Text )"
			}
		}
	}
}

function GetUserInput
{
	<#
	.Synopsis
		Creates a file for input from user, then returns its content.
	.Description
		Creates a file for input from user, then returns its content. If file exists, the content is replaced, otherwise the file is created. DefaultText is placed in the begining of the file and then removed in the returned text.
	.Parameter DefaultText
		A string that is placed at the beginning of the file, to give a description of that infomation the user should enter.
	.Outputs
		Returns the file content, with DefaultText removed
	#>

	param ( [string] $DefaultText )

	$InputFilePath = "$RootDir\Input\$( [Environment]::UserName )\$( $CallingScript.BaseName ).txt"
	if ( Test-Path -Path $InputFilePath ) { Clear-Content $InputFilePath }
	else { New-Item -Path $InputFilePath -ItemType File -Force | Out-Null }

	if ( $DefaultText ) { Set-Content $InputFilePath $DefaultText }
	Start-Process notepad $InputFilePath -Wait

	return Get-Content $InputFilePath | Where-Object { $_ -notlike $DefaultText }
}

function NewErrorLog
{
	<#
	.Synopsis
		Create a new errorlog object
	.Description
		Create a new errorlog object
	.Parameter Obj
		An already created ErrorLog-object
	.Outputs
		Returns a new, empty, ErrorLog-object
	#>

	param ( [ErrorLog] $Obj )

	if ( $Obj )
	{ return [ErrorLog]::new( $Obj ) }
	else
	{ return [ErrorLog]::new() }
}

function NewLog
{
	<#
	.Synopsis
		Create a new log object
	.Description
		Create a new log object
	.Outputs
		A new, empty, Log-object
	#>

	param ( [Log] $Obj )

	if ( $Obj )
	{ return [Log]::new( $Obj ) }
	else
	{ return [Log]::new() }
}

function NewSurvey
{
	<#
	.Synopsis
		Create a new survey object
	.Description
		Create a new survey object
	.Parameter Obj
		A created Survey-object
	.Outputs
		A new, empty, Survey-object
	#>

	param ( [Survey] $Obj )

	if ( $Obj )
	{ return [Survey]::new( $Obj ) }
	else
	{ return [Survey]::new() }
}

function WriteErrorlog
{
	<#
	.Synopsis
		Write error to errorlogfile
	.Description
		Write error to errorlogfile. The content is extended with date, time and username of the user running the script
	.Parameter LogText
		Text to be logged
	.Parameter UserInput
		The users input when starting script
	.Parameter Severity
		Severity of the error
	.Parameter ComputerName
		Name of the computer when running script
	.Outputs
		Returns path to the file
	#>

	param (
	[Parameter(Mandatory = $true)]
		[string] $LogText,
	[Parameter(Mandatory = $true)]
	[AllowEmptyString()]
		[string] $UserInput,
	[Parameter(Mandatory = $true)][ValidateScript( { [ErrorSeverity].GetEnumNames() -contains $_ } )]
		[ErrorSeverity] $Severity,
		[string] $ComputerName
	)

	$ScriptName = ( $MyInvocation.PSCommandPath -split "\\" )[-1]
	$mtx = [System.Threading.Mutex]::new( $false, "WriteErrorLog $( $ScriptName )" )

	if ( $MyInvocation.PSCommandPath -notmatch "Tools" )
	{
		$Function = ( Get-PSCallStack )[1].FunctionName
		if ( $Function -notmatch "\<ScriptBlock\>" )
		{
			$LogText = "$( $Function )`n$LogText"
		}
	}

	$OutputEncoding = ( New-Object System.Text.UnicodeEncoding $False, $False ).psobject.BaseObject
	if ( $ScriptName )
	{
		$ErrorLogFilePath = Get-LogFilePath -TopFolder "ErrorLogs" -FileName "$ScriptName - Errorlog.json"
	}
	else
	{
		$ErrorLogFilePath = Get-LogFilePath -TopFolder "ErrorLogs" -FileName "$( $CallingScript.BaseName ) - Errorlog.json"
	}

	if ( [string]::IsNullOrEmpty( $UserInput ) )
	{
		$UserInput = "NULL"
	}
	$el = [ErrorLog]::new( $LogText, $UserInput.Trim(), $Severity )

	if ( $ComputerName )
	{
		$el.ComputerName = $ComputerName
	}
	$mtx.WaitOne()
	Add-Content -Path $ErrorLogFilePath -Value $el.ToJson()
	$mtx.ReleaseMutex()

	return @{ "ErrorLogFile" = $ErrorLogFilePath ; "ErrorLogDate" = $el.LogDate }
}

function WriteLog
{
	<#
	.Synopsis
		Writes to log-file
	.Description
		Writes to log-file. The content is extended with date, time and username of the operator running the script
	.Parameter Text
		Text from script to be logged
	.Parameter UserInput
		The users input when starting script
	.Parameter Success
		If the operation was successful
	.Parameter ErrorLogHash
		An array of ErrorLog-hashes from errorlogs written during operation
	.Parameter OutputPath
		Filepath for any files written by the script
	.Parameter ComputerName
		Name of the computer when running script
	.Outputs
		Returns path to the file
	#>

	[CmdletBinding()]
	param (
		[string] $Text,
		[string] $UserInput,
	[Parameter(Mandatory = $true)]
		[bool] $Success,
		[array] $ErrorLogHash,
		[array] $OutputPath,
		[string] $ComputerName
	)

	try
	{
		$ScriptName = ( Get-Item $MyInvocation.PSCommandPath ).BaseName
		$mtx = [System.Threading.Mutex]::new( $false, "WriteLog $( $ScriptName )" )
	}
	catch
	{
		$mtx = [System.Threading.Mutex]::new( $false, "WriteLog $( Get-Random )" )
	}

	if ( $MyInvocation.PSCommandPath -notmatch "Tools" )
	{
		$Function = ( Get-PSCallStack )[1].FunctionName
		if ( $Function -notmatch "\<ScriptBlock\>" )
		{
			$Text = "$( $Function )`n$Text"
		}
	}
	$log = [Log]::new( $Text, $UserInput.Trim(), [Success][int]$Success )

	if ( $ErrorLogHash )
	{
		$log.ErrorLogFile = $ErrorLogHash.ErrorLogFile
		$log.ErrorLogDate = $ErrorLogHash.ErrorLogDate
	}

	if ( $OutputPath )
	{
		$log.OutputFile = $OutputPath
	}

	if ( $ComputerName )
	{
		$log.ComputerName = $ComputerName
	}

	if ( $ScriptName )
	{
		$LogFilePath = Get-LogFilePath -TopFolder "Logs" -FileName "$ScriptName - log.json"
	}
	else
	{
		$LogFilePath = Get-LogFilePath -TopFolder "Logs" -FileName "$( $CallingScript.BaseName ) - log.json"
	}

	$mtx.WaitOne() | Out-Null
	Add-Content -Path $LogFilePath -Value ( $log.ToJson() )
	$mtx.ReleaseMutex()

	return $LogFilePath
}

function WriteOutput
{
	<#
	.Synopsis
		Writes output to a file in the Output-folder
	.Description
		Writes output to a file in the Output-folder, with location corresponding to the calling script, alternatively to a scoreboard file
	.Parameter FileNameAddition
		Any text that should be added to the filename
	.Parameter Output
		Text to be written in the output-file
	.Parameter FileExtension
		The fileextension of the file
	.Parameter Scoreboard
		If the file to be written is a scoreboard of some sort
	.Outputs
		Returns full path to the file written
	#>

	param (
		[string] $FileNameAddition,
		[string] $Output,
		[string] $FileExtension = "txt",
		[switch] $Scoreboard,
		[switch] $Append,
	[Parameter( Mandatory = $true )]
		[string] $FileName
	)

	if ( $Scoreboard ) { $Folder = "Scoreboard" } else { $Folder = ( [Environment]::UserName ) }

	$FileName = "{0} {1}, {2}.{3}" -f $FileName, "$( if ( $FileNameAddition ) { "$FileNameAddition " } )", ( Get-Date -Format "yyyy-MM-dd HH.mm.ss" ), $FileExtension

	$OutputFilePath = Get-LogFilePath -TopFolder "Output" -SubFolder $Folder -FileName $FileName
	Set-Content -Path $OutputFilePath -Value ( $Output )

	return $OutputFilePath
}

function WriteSurvey
{
	<#
	.Synopsis
		Write survey to file
	.Description
		Write survey to file
	.Parameter Survey
		The survey to be written
	.Parameter ScriptName
		Name of the script the survey concerns
	.Outputs
		An hashtable containing the filepath of file that was writte, and the date/time when the file was written
	#>

	param (
	[Parameter(Mandatory = $true)]
		[Survey] $Survey,
	[Parameter(Mandatory = $true)]
		[string] $ScriptName
	)

	$mtx = [System.Threading.Mutex]::new( $false, "WriteSurvey $ScriptName" )
	$OutputEncoding = ( New-Object System.Text.UnicodeEncoding $False, $False ).psobject.BaseObject
	$SurveyFilePath = Get-LogFilePath -TopFolder "Logs" -FileName "$ScriptName - survey.json"
	$mtx.WaitOne()
	$SurveyJson = $Survey.ToJson()
	Add-Content -Path $SurveyFilePath -Value $SurveyJson
	$mtx.ReleaseMutex()
	if ( $Survey.Comment -ne "" )
	{
		$Operator = Get-ADUser ( $Survey.Operator -replace $IntmsgTable.StrAdmPrefix, "" ) -Properties EmailAddress
		Send-MailMessage -From $IntmsgTable.StrMailAddress `
			-To $Operator.EmailAddress `
			-Body "$( $IntmsgTable.StrSurveyMsgStart )`n$( $IntmsgTable.StrSurveyMsgScriptTitle ) $ScriptName`n$( $IntmsgTable.StrSurveyMsgOperatorTitle ) $( $Operator.Name )`n`n$( $Survey.Comment )"`
			-Encoding bigendianunicode `
			-SmtpServer $IntmsgTable.StrSMTP `
			-Subject $IntmsgTable.StrSurveySubject
	}

	return @{ "SurveyFile" = $SurveyFilePath ; "SurveyLogDate" = $Survey.LogDate }
}

$nudate = Get-Date -Format "yyyy-MM-dd HH:mm"
try
{
	$RootDir = ( Get-Item $MyInvocation.PSCommandPath ).Directory.Parent.FullName
}
catch
{
	$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.Parent.FullName
}

$CallingScript = try { Get-Item $MyInvocation.PSCommandPath } catch { [pscustomobject]@{ BaseName = "NoScript"; Name = "NoScript" } }

try
{
	Import-LocalizedData -BindingVariable IntmsgTable -UICulture $culture -FileName "$( ( $PSCommandPath.Split( "\" ) | Select-Object -Last 1 ).Split( "." )[0] ).psd1" -BaseDirectory "$RootDir\Localization" -ErrorAction Stop
}
catch {}

try
{
	Import-LocalizedData -BindingVariable msgTable -UICulture $culture -FileName "$( $CallingScript.BaseName ).psd1" -BaseDirectory "$RootDir\Localization" -ErrorAction SilentlyContinue
}
catch
{
	[System.Windows.MessageBox]::Show( $_ )
}

Export-ModuleMember -Function EndScript, GetUserInput, ShowMessageBox, WriteErrorlog, WriteLog, WriteOutput, WriteLogTest, WriteErrorlogTest, WriteSurvey, New*, GetScriptInfo, Get-LogFilePath
Export-ModuleMember -Variable msgTable

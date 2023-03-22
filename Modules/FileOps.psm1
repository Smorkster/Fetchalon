﻿<#
.Synopsis A module for functions operating on files
.State Prod
.Author Smorkster
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
	[string] $ComputerName
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
		$this.ComputerName = $o.ComputerName
	}

	[string] ToJson()
	{
		$this.LogDate = ( Get-Date -Format "yyyy-MM-dd HH:mm:ss" )
		$this.Operator = $env:USERNAME
		return $this | ConvertTo-Json -Compress
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
	[string] $ComputerName
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
		$this.ComputerName = $o.ComputerName
	}

	[string] ToJson()
	{
		$this.LogDate = ( Get-Date -Format "yyyy-MM-dd HH:mm:ss" )
		$this.Operator = $env:USERNAME
		return $this | ConvertTo-Json -Compress
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
		$this.Operator = $env:USERNAME
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

	$path = "{0}\{1}\{2}\{3}" -f $RootDir, $TopFolder, "$( if ( $SubFolder ) { $SubFolder } else { "$( [datetime]::Now.Year )\$( [datetime]::Now.Month )" } )", $FileName
	if ( -not ( Test-Path $path ) ) { New-Item -Path $path -ItemType File -Force | Out-Null }
	return $path
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
		Add-Content -Path "$RootDir\Logs\DummyQuitting.json" -Value ( [pscustomobject]@{ Date = $nudate; Operator = $env:USERNAME; Text = $( $CallingScript.BaseName ) - $dummy } | ConvertTo-Json )
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
	.Outputs
		A PsCustomObject with the code information
	.State
		Prod
	.Author
		Smorkster
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
		[pscustomobject] $InfoObject
	)

	if ( $null -eq $InfoObject )
	{
		$InfoObject = [pscustomobject]@{}
	}

	if ( $FilePath )
	{
		try
		{
			$ResolvedFilePath = Resolve-Path $FilePath -ErrorAction Stop
			$FileContent = Get-Content $ResolvedFilePath.Path -Raw
			if ( [string]::IsNullOrEmpty( $InfoObject.Name ) )
			{ Add-Member -InputObject $InfoObject -MemberType NoteProperty -Name "Name" -Value ( Get-Item $ResolvedFilePath ).BaseName -Force }
		}
		catch
		{
			return $null
		}
	}
	elseif ( $Function )
	{
		$FileContent = $Function.Definition
		if ( [string]::IsNullOrEmpty( $InfoObject.Name ) )
		{ Add-Member -InputObject $InfoObject -MemberType NoteProperty -Name "Name" -Value $Function.Name -Force }
	}
	else
	{
		$FileContent = $Text
		if ( [string]::IsNullOrEmpty( $InfoObject.Name ) )
		{ Add-Member -InputObject $InfoObject -MemberType NoteProperty -Name "Name" -Value $Function.Name -Force }
	}

	if ( $FileContent -match "(?s)<#(?<Info>.*?)#>" )
	{
		[regex]::Matches( $Matches.Info , "\s*\.(?<InfoType>(?!Parameter)\w*)\s*(?<InfoComment>.*)" ) | `
			ForEach-Object `
				-Begin { $InputDataList = [System.Collections.ArrayList]::new() } `
				-Process {
					if ( "InputData" -eq $_.Groups["InfoType"].Value )
					{
						$_.Groups["InfoComment"].Value.Trim() -match "(?<VarName>\w*)\s*(?<VarDesc>\w*)" | Out-Null
						$InputDataList.Add( ( [pscustomobject]@{ Name = $Matches.VarName ; InputDescription = $Matches.VarDesc ; EnteredValue = "" } ) ) | Out-Null
					}
					elseif ( "NoRunspace" -eq $_.Groups["InfoType"].Value )
					{
						Add-Member -InputObject $InfoObject -MemberType NoteProperty -Name $_.Groups["InfoType"].Value -Value $true
					}
					else
					{
						Add-Member -InputObject $InfoObject -MemberType NoteProperty -Name $_.Groups["InfoType"].Value -Value $_.Groups['InfoComment'].Value.Trim()
					}
				} `
				-End {
					if ( $InputDataList.Count -gt 0 )
					{
						Add-Member -InputObject $InfoObject -MemberType NoteProperty -Name "InputData" -Value $InputDataList
					}
				}

		if ( [string]::IsNullOrEmpty( $InfoObject.MenuItem ) )
		{
			if ( [string]::IsNullOrEmpty( $InfoObject.Synopsis ) ) { $MenuItemText = $InfoObject.Name }
			else { $MenuItemText = $InfoObject.Synopsis }
			try { Add-Member -InputObject $InfoObject -MemberType NoteProperty -Name "MenuItem" -Value $MenuItemText.Trim() -Force }
			catch {
				[System.Windows.MessageBox]::Show( ( $MenuItemText ) )
				[System.Windows.MessageBox]::Show( ( $InfoObject | out-string ) )
			}
		}

		return $InfoObject
	}
	else
	{
		throw $IntmsgTable.ErrGetScriptInfoNotScriptInfo
	}
}

function GetUserInput
{
	<#
	.Synopsis
		Creates a file for input from user, then returns its content.
	.Description
		Creates a file for input from user, then returns its content. If file exists, the content is replaced, otherise the file is created. DefaultText is placed in the begining of the file and then removed in the returned text.
	.Parameter DefaultText
		A string that is placed at the beginning of the file, to give a description of that infomation the user should enter.
	.Outputs
		Returns the file content, with DefaultText removed
	#>

	param ( [string] $DefaultText )

	$InputFilePath = "$RootDir\Input\$env:USERNAME\$( $CallingScript.BaseName ).txt"
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

function ShowMessageBox
{
	<#
	.Synopsis
		Display a messagebox with given text
	.Description
		Display a messagebox with given text, and, if defined, title, icon and button/-s
	.Parameter Text
		The text to display in the messagebox
	.Parameter Title
		A string to display in the title of the messagebox
	.Parameter Button
		What buttons are to be used/visible in the messagebox
	.Parameter Icon
		What icon is to be displayed in the messagebox
	.Outputs
		Returns which button in the messagebox was clicked
	#>

	param (
		[string] $Text,
		[string] $Title = "",
		[string] $Button = "OK",
		[string] $Icon = "Info"
	)

	return [System.Windows.MessageBox]::Show( "$Text", "$Title", "$Button", "$Icon" )
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
		[string] $UserInput,
	[Parameter(Mandatory = $true)][ValidateScript( { [ErrorSeverity].GetEnumNames() -contains $_ } )]
		[ErrorSeverity] $Severity,
		[string] $ComputerName
	)

	$mtx = [System.Threading.Mutex]::new( $false, "WriteLogTest $( $CallingScript.Name )" )
	$OutputEncoding = ( New-Object System.Text.UnicodeEncoding $False, $False ).psobject.BaseObject
	$ErrorLogFilePath = Get-LogFilePath -TopFolder "ErrorLogs" -FileName "$( $CallingScript.BaseName ) - Errorlog.json"
	$el = [ErrorLog]::new( $LogText, $UserInput.Trim(), $Severity )
	if ( $ComputerName ) { $el.ComputerName = $ComputerName }
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

	$mtx = [System.Threading.Mutex]::new( $false, "WriteLogTest $( $CallingScript.Name )" )
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
		[switch] $Append
	)

	if ( $Scoreboard ) { $Folder = "Scoreboard" } else { $Folder = $env:USERNAME }

	$FileName = "{0} {1}, {2}.{3}" -f $CallingScript.BaseName, "$( if ( $FileNameAddition ) { "$FileNameAddition " } )", ( Get-Date -Format "yyyy-MM-dd HH.mm.ss" ), $FileExtension
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
	$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.FullName
}
$CallingScript = try { Get-Item $MyInvocation.PSCommandPath } catch { [pscustomobject]@{ BaseName = "NoScript"; Name = "NoScript" } }

Import-LocalizedData -BindingVariable IntmsgTable -UICulture $culture -FileName "$( ( $PSCommandPath.Split( "\" ) | Select-Object -Last 1 ).Split( "." )[0] )" -BaseDirectory "$RootDir\Localization\$culture\Modules"
try {
	Import-LocalizedData -BindingVariable msgTable -UICulture $culture -FileName "$( $CallingScript.BaseName ).psd1" -BaseDirectory ( Get-ChildItem -Path "$RootDir\Localization\$culture" -Filter "$( $CallingScript.BaseName ).psd1" -Recurse ).Directory.FullName -ErrorAction SilentlyContinue
} catch { [System.Windows.MessageBox]::Show( $_ ) }

try { $Host.UI.RawUI.WindowTitle = "$( $IntmsgTable.ConsoleWinTitlePrefix ): $( ( ( Get-Item $MyInvocation.PSCommandPath ).FullName -split "Script" )[1] )" } catch {}

Export-ModuleMember -Function EndScript, GetUserInput, ShowMessageBox, WriteErrorlog, WriteLog, WriteOutput, WriteLogTest, WriteErrorlogTest, WriteSurvey, New*, GetScriptInfo
Export-ModuleMember -Variable msgTable

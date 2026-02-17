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

function Get-DataFormaters
{
	<#
	.Synopsis
		Get output data formaters
	.Description
		Collects data formaters defined for functions.
		For a dataformater to be recognized, it must be defined as a function, inside the module function, and named "DataFormater".
		There can be multiple dataformaters defined, but to make them distinct the name should be appended with "_<some name>", i.e. "DataFormater_Cvs". The added name will be used as title in the GUI.
	.Parameter Code
		Function code to parse
	.State
		Prod
	.Author
		Smorkster (smorkster)
	#>

	param (
	[ Parameter( Mandatory = $true )]
		$Code
	)

	$CodeAst = [System.Management.Automation.Language.Parser]::ParseInput( $Code, [ref]$null, [ref]$null )
	$FormaterList = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	$CodeAst.FindAll( { $args[0].GetType().Name -like "*FunctionDefinitionAst" }, $true ) | `
		Where-Object { $_.Name -match "^DataFormater_" } | `
		Select-Object -Unique | `
		Select-Object -Property `
			@{ Name = 'Name' ; Expression = { $_.Name } },
			@{ Name = 'Title' ; Expression = {
				if ( $null -eq ( $t = ( $_.Name -split '_', 2 )[1] ) )
				{
					$IntmsgTable.StrDataFormaterNameEmpty
				}
				else
				{
					$t
				}
			} },
			@{ Name = 'Code' ; Expression = { $_.Body } } | `
		ForEach-Object {
			$FormaterList.Add( $_ ) | Out-Null
		}
	return $FormaterList
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
			$FileContent = Get-Content $FilePath -Raw -ErrorAction Stop
			$Item = Get-Item $FilePath
			$Name = $Item.Name

			if ( [string]::IsNullOrEmpty( $InfoObject.Name ) )
			{
				$InfoObject.PSObject.Properties.Add( [psnoteproperty]::new( 'Name', $Item.BaseName ) )
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
			$InfoObject.PSObject.Properties.Add( [psnoteproperty]::new( 'Name', $Function.Name ) )
		}
	}
	else
	{
		$FileContent = $Text
		$Name = "Text"

		if ( [string]::IsNullOrEmpty( $InfoObject.Name ) )
		{
			$InfoObject.PSObject.Properties.Add( [psnoteproperty]::new( 'Name', "?" ) )
		}
	}

	$script:re_InfoBlock = [regex]::new( "(?s)<#(?<Info>.*?)#>", "Compiled" )
	$script:re_InfoParam = [regex]::new( "\s*(?<InfoType>(?!(Parameter)|(Outputs))\w+)\s+(?<Rest>.*)", "Compiled" )
	$script:re_InputDataList = [regex]::new( "^\s*(?<InputVar>\w+).*?\|\s*(?<Mandatory>\w*)\s*?\|(?<Desc>.*?)\|\s*(?<DefaultValue>\w*)\s*\|(?<InputList>.*)", "Compiled" )
	$script:re_Note = [regex]::new( "^\s*(?<NoteType>\w+).*?\|\s*(?<NoteText>.*)", "Compiled" )
	$script:re_Date = [regex]::new( "(?:In)*valid(?:ate)*(?:(?:Start)|(?:End))*DateTime", "Compiled" )

	# Separate infoblock from rest of the script text
	$m = $script:re_InfoBlock.Match( $FileContent )
	if ( $m.Success )
	{
		# Parse the info block
		$InfoContent = $m.Groups[ "Info" ].Value -split "(?m)^\s*\."
		$ListInputData = [System.Collections.ObjectModel.ObservableCollection[object]]::new()

		foreach( $row in $InfoContent )
		{
			$HasDateKey = $true
			if ( [string]::IsNullOrWhiteSpace( $row ) )
			{
				continue
			}

			$InfoMatch = $script:re_InfoParam.Match( $row )
			if ( -not $InfoMatch.Success )
			{
				continue
			}

			$InfoType = $InfoMatch.Groups[ "InfoType" ].Value.Trim()
			if ( [string]::IsNullOrWhiteSpace( $InfoType ) )
			{
				continue
			}
			$Rest = $InfoMatch.Groups[ "Rest" ].Value.Trim()

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
				$IDLMatch = $script:re_InputDataList.Match( $Rest )
				$ListInputData.Add( (
					[pscustomobject]@{
						Name = $IDLMatch.Groups[ "InputVar" ].Value.Trim()
						InputDescription = $IDLMatch.Groups[ "Desc" ].Value.Trim()
						InputType = "List"
						InputList = [System.Collections.ArrayList] ( $IDLMatch.Groups[ "InputList" ].Value.Trim() -split "," )
						DefaultValue = $IDLMatch.Groups[ "DefaultValue" ].Value.Trim()
						Mandatory = "True" -eq $IDLMatch.Groups[ "Mandatory" ].Value.Trim()
						EnteredValue = ""
					}
				) ) | Out-Null
			}
			elseif ( "InputDataBool" -eq $InfoType )
			{
				$Name, $Mandatory, $Desc = $Rest -split ",", 3
				$ListInputData.Add( (
					[pscustomobject]@{
						Name = $Name.Trim()
						InputType = "Bool"
						InputDescription = $Desc.Trim()
						Mandatory = "True" -eq $Mandatory.Trim()
						EnteredValue = $false
					}
				) ) | Out-Null
			}
			elseif ( "NoRunspace" -eq $InfoType )
			{
				$InfoObject.PSObject.Properties.Add( [psnoteproperty]::new( 'NoRunspace', $true ) )
			}
			elseif ( "Note" -eq $InfoType )
			{
				$NoteMatch = $script:re_Note.Match( $Rest )

				if ( $NoteMatch.Groups[ "NoteType" ].Value.Trim() -eq "Info" -or $NoteMatch.Groups[ "NoteType" ].Value.Trim() -eq "Warning" )
				{
					$Note = [pscustomobject]@{
						NoteType = $NoteMatch.Groups[ "NoteType" ].Value.Trim()
						NoteText = $NoteMatch.Groups[ "NoteText" ].Value.Trim()
					}
				}
				$InfoObject.PSObject.Properties.Add( [psnoteproperty]::new( 'Note', $Note ) )
			}
			elseif ( ( $script:re_Date.Match( $InfoType ) ).Success )
			{
				$HasDateKey = $true
				try
				{
					$Date = [datetime]::Parse( $Rest )
					$InfoObject.PSObject.Properties.Add( [psnoteproperty]::new( $InfoType, $Date ) )
				}
				catch
				{
					Write-Host "$( $IntmsgTable.ErrGetScriptInfoAddValidDate ) $( $InfoType ): $( $Rest )`n$( $_ )"
				}
			}
			else
			{
				try
				{
					if ( $InfoObject.PSObject.Properties[$InfoType] )
					{
						$InfoObject.$InfoType = $Rest
					}
					else
					{
						$InfoObject.PSObject.Properties.Add( [psnoteproperty]::new( $InfoType, $Rest ) )
					}
				}
				catch
				{
					Write-Host "Failed adding '$InfoType' for '$Name' from row: [$row]`n$( $_.Exception.Message )"
				}
			}
		}

		if ( $ListInputData.Count -gt 0 )
		{
			$InfoObject.PSObject.Properties.Add( [psnoteproperty]::new( 'InputData', $ListInputData ) )
		}

		if ( $HasDateKey )
		{
			$Date = Get-Date
			$DateTimeFormats = [System.Globalization.CultureInfo]::CurrentCulture.DateTimeFormat
			$InfoObject.PSObject.Properties.Add( [psnoteproperty]::new( 'ValidDateApproved', $true ) )

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
				$InfoObject.PSObject.Properties.Add( [psnoteproperty]::new( 'ValidDateNote', $ValidDateNote ) )
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
				$InfoObject.PSObject.Properties.Add( [psnoteproperty]::new( 'MenuItem', $MenuItemText.Trim() ) )
			}
			catch
			{
				[System.Windows.MessageBox]::Show( $_.Exception.Message ) | Out-Null
			}
		}

		$InfoObject.PSObject.Properties.Add( [psnoteproperty]::new( 'IsSubMenuHeader', 0 ) )
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

Export-ModuleMember -Function EndScript, GetUserInput, ShowMessageBox, WriteErrorlog, WriteLog, WriteOutput, WriteLogTest, WriteErrorlogTest, WriteSurvey, New*, Get-DataFormaters, GetScriptInfo, Get-LogFilePath
Export-ModuleMember -Variable msgTable

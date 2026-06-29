<#
.Synopsis
	Check for potential viruses
.Description
	Lists all files under a user's H: and shared folders it has permission to. The files are then listed by location and after some filtering of file names.
.MenuItem
	Check for potential viruses
.State
	Prod
.Author
	Smorkster (smorkster)
.ObjectOperations
	user
.RequiredAdGroups
	Rol_Servicedesk_Backoffice
#>

Add-Type -AssemblyName PresentationFramework
$syncHash = $args[0]

function Add-FileProperties
{
	<#
	.Synopsis
		Add properties to selected file
	.Parameter File
		Selected file
	#>

	param ( $File )

	$syncHash.Controls.Window.Resources.FileOpsEnabled = $true
	$File = $File | Select-Object *

	if ( [string]::IsNullOrEmpty( $File.Extension ) )
	{
		$FileType = $syncHash.Data.msgTable.StrNoExtension
	}
	else
	{
		try
		{
			$e = $File.Extension.ToLower()
			$Desc = ( Get-ItemProperty "Registry::HKEY_Classes_root\$( ( Get-ItemProperty "Registry::HKEY_Classes_root\$e" -ErrorAction Stop )."(default)" )" )."(default)"
			if ( $Desc )
			{
				$FileType = "$e :: $Desc"
			}
			else
			{ throw }
		}
		catch
		{
			$FileType = "$e :: ?"
		}
	}
	$File.PSObject.Properties.Add( [psnoteproperty]::new( "FileType", $FileType ) )

	$SizeText = if ( $File.Length -lt 1kB ) { "$( $File.Length ) B" }
		elseif ( $File.Length -gt 1kB -and $File.Length -lt 1MB ) { "$( [math]::Round( ( $File.Length / 1kB ), 2 ) ) kB" }
		elseif ( $File.Length -gt 1MB -and $File.Length -lt 1GB ) { "$( [math]::Round( ( $File.Length / 1MB ), 2 ) ) MB" }
		elseif ( $File.Length -gt 1GB -and $File.Length -lt 1TB ) { "$( [math]::Round( ( $File.Length / 1GB ), 2 ) ) GB" }
	$File.PSObject.Properties.Add( [psnoteproperty]::new( "SizeText", $SizeText ) )

	try
	{
		$Acl = Get-Acl $File.FullName -ErrorAction Stop
		$Owner = ( Get-Acl $File.FullName -ErrorAction Stop ).Owner
		if ( "BUILTIN\Administrators" -ne $Acl.Owner )
		{
			$OwnerAD = Get-ADUser ( ( $Acl.Owner ) -split "\\" )[1] -ErrorAction Stop
			if ( $OwnerAD.SamAccountName -eq $syncHash.User.SamAccountName )
			{
				$Owner = $syncHash.Data.msgTable.StrFileOwner
			}
			else
			{
				$Owner = $OwnerAD.Name
			}
		}
		else
		{
			$Owner = $Acl.Owner
		}
	}
	catch
	{
		$Owner = "?"
	}
	$File.PSObject.Properties.Add( [psnoteproperty]::new( "Owner", $Owner ) )

	$File.PSObject.Properties.Add( [psnoteproperty]::new( "Streams", [System.Collections.Generic.List[object]]::new() ) )
	$File.PSObject.Properties.Add( [psnoteproperty]::new( "HasStreams", $false ) )
	try
	{
		Get-Item -Path $File.FullName -Stream * -ErrorAction Stop | `
			ForEach-Object {
				$ds = if ( $_.Length -lt 1kB ) { "$( $_.Length ) B" }
				elseif ( $_.Length -gt 1kB -and $_.Length -lt 1MB ) { "$( [math]::Round( ( $_.Length / 1kB ), 2 ) ) kB" }
				elseif ( $_.Length -gt 1MB -and $_.Length -lt 1GB ) { "$( [math]::Round( ( $_.Length / 1MB ), 2 ) ) MB" }
				elseif ( $_.Length -gt 1GB -and $_.Length -lt 1TB ) { "$( [math]::Round( ( $_.Length / 1GB ), 2 ) ) GB" }
				$File.Streams.Add( ( [pscustomobject]@{ Stream = $_.Stream ; DataSize = $ds } ) ) | Out-Null
			}
	}
	catch
	{
		$_.psobject.Properties.Add( [psnoteproperty]::new( "FileStreamsError", $_.Exception ) )
		$_.psobject.Properties.Add( [psnoteproperty]::new( "File", $File ) )
		$syncHash.Errors.Add( $_ )
	}
	$File.HasStreams = $File.Streams.Count -gt 0

	$syncHash.Controls.Window.DataContext.SelectedItem = $File
	$syncHash.Controls.TblFileType.GetBindingExpression( [System.Windows.Controls.TextBlock]::TextProperty ).UpdateTarget()
	$syncHash.Controls.TblFileStreamsCount.GetBindingExpression( [System.Windows.Controls.TextBlock]::TextProperty ).UpdateTarget()
	$syncHash.Controls.TblLastWriteTime.GetBindingExpression( [System.Windows.Controls.TextBlock]::TextProperty ).UpdateTarget()
	$syncHash.Controls.TblFileOwner.GetBindingExpression( [System.Windows.Controls.TextBlock]::TextProperty ).UpdateTarget()
	$syncHash.Controls.TblFileSize.GetBindingExpression( [System.Windows.Controls.TextBlock]::TextProperty ).UpdateTarget()
	$syncHash.Controls.TblFilePath.GetBindingExpression( [System.Windows.Controls.TextBlock]::TextProperty ).UpdateTarget()
	$syncHash.Controls.TblFileName.GetBindingExpression( [System.Windows.Controls.TextBlock]::TextProperty ).UpdateTarget()
	$syncHash.Controls.BtnShowFileStreams.GetBindingExpression( [System.Windows.Controls.Button]::IsEnabledProperty ).UpdateTarget()
}

function Assert-Input
{
	<#
	.Synopsis
		Check if input is valid, if so, enable button to start prep
	#>

	$CaseNrOk = ( $syncHash.DC.BrdCaseNr[0] -eq "Green" )
	$IdOk = ( $syncHash.DC.BrdId[0] -eq "Green" )
	$CaseNrEntered = $syncHash.DC.TbCaseNr[0].Length -gt 0
	$IdEntered = $syncHash.Controls.TbId.Text.Length -gt 0

	$syncHash.DC.BtnPrep[1] = $CaseNrOk -and $IdOk -and $CaseNrEntered -and $IdEntered
}

function GenerateLog
{
	<#
	.Synopsis
		Create logtext
	#>

	$syncHash.logText = @"
$( $syncHash.Data.msgTable.StrLogMsgSearchTime ): $( $syncHash.Start.ToString( "yyyy-MM-dd HH:mm:ss"  ) ) - $( $syncHash.End.ToString( "HH:mm:ss" ) )
$( $a = $syncHash.End - $syncHash.Start
"{0} h, {1} m, {2} s" -f $a.hours, $a.minutes, $a.seconds )

$( if ( $syncHash.DC.RbLatest[0] ) { "$( $syncHash.Data.msgTable.StrOutputTimeline1 ) $( $syncHash.DC.DatePickerStart[0].ToShortDateString() ) -> $( ( Get-Date ).ToShortDateString() )"}
elseif ( $syncHash.DC.RbPrevDate[0] ) { "$( $syncHash.Data.msgTable.StrOutputTimeline2 ) $( $syncHash.DC.DatePickerStart[0].ToShortDateString() ) -> $( ( Get-Date ).ToShortDateString() )" }
else { $syncHash.Data.msgTable.StrOutputTimeline3 } )

$( $syncHash.Data.msgTable.StrLogMsgOtherPermCount ) $( $syncHash.CvsOtherFolderPermissions.Source.Count )
$( $syncHash.Data.msgTable.StrLogMsgFilesWithDoubleExtH ) $( $syncHash.CvsMultiDotsH.Source.Count )
$( $syncHash.Data.msgTable.StrLogMsgFilesWithDoubleExtG ) $( $syncHash.CvsLvMultiDotsG.Source.Count )
"@
}

function Get-Cvs
{
	param (
		[string] $Key
	)

	$win = $syncHash.Controls.Window
	if ( $win -and $win.Resources.Contains( $Key ) )
	{
		return $win.Resources[$Key]
	}

	$content = $win.Content
	if ( $content -and $content.Resources -and $content.Resources.Contains( $Key ) )
	{
		return $content.Resources[$Key]
	}

	try
	{
		return $win.FindResource( $Key )
	}
	catch {}

	return $null
}

function GetFiles
{
	<#
	.Synopsis
		Start the job to get all files
	#>

	$syncHash.Jobs.FilesJob.Handle = $syncHash.Jobs.FilesJob.PS.BeginInvoke()

	if ( $syncHash.Jobs.FilesDoneTimer )
	{
		try { $syncHash.Jobs.FilesDoneTimer.Stop() } catch {}
	}

	$syncHash.Jobs.FilesDoneTimer = [System.Windows.Threading.DispatcherTimer]::new()
	$syncHash.Jobs.FilesDoneTimer.Interval = [TimeSpan]::FromMilliseconds( 200 )

	$syncHash.Jobs.FilesDoneTimer.Add_Tick( {
		try
		{
			if ( -not $syncHash.Jobs.FilesJob.Handle.IsCompleted )
			{
				return
			}

			$syncHash.Jobs.FilesDoneTimer.Stop()

			try
			{
				$syncHash.Jobs.FilesJob.PS.EndInvoke( $syncHash.Jobs.FilesJob.Handle ) | Out-Null
			}
			catch
			{
				$syncHash.Errors.Add( $_ ) | Out-Null
			}

			if ( $syncHash.Jobs.IsCancelling )
			{
				return
			}

			$syncHash.End = Get-Date

			GenerateLog

			$ofs = "`n"
			$syncHash.Data.OutputContent = @"
$( $syncHash.Data.msgTable.StrOutput1 )

$( $syncHash.Data.msgTable.StrOutput2 ): $( $syncHash.User.Name )
$( $syncHash.Data.msgTable.StrOutput3 ): $( $syncHash.DC.TbCaseNr[0] )
$( if ( $syncHash.DC.RbLatest[0] ) { "$( $syncHash.Data.msgTable.StrOutputTimeline1 ) $( $syncHash.DC.DatePickerStart[0].ToShortDateString() ) -> $( ( Get-Date ).ToShortDateString() )"}
elseif ( $syncHash.DC.RbPrevDate[0] ) { "$( $syncHash.Data.msgTable.StrOutputTimeline2 ) $( $syncHash.DC.DatePickerStart[0].ToShortDateString() ) -> $( ( Get-Date ).ToShortDateString() )" }
else { $syncHash.Data.msgTable.StrOutputTimeline3 } )

***********************
$( $syncHash.Data.msgTable.StrOutputTitleFolders ):

$( foreach ( $f in $syncHash.CvsFolderList.View ) { "$( $f.Path ) ( $( $f.Name ) )" } )


***********************
$( $syncHash.Data.msgTable.StrOutputTitleFoldersOtherPerm ):

$( [string]( $syncHash.CvsOtherFolderPermissions.Source ) )


***********************
$( $syncHash.Data.msgTable.StrOutputTitleMultiDotH )

$( ( $syncHash.CvsMultiDotsH.Source.FullName | Sort-Object ) -join "`n" )


***********************
$( $syncHash.Data.msgTable.StrOutputTitleMultiDotG )

$( ( $syncHash.CvsMultiDotsG.Source.FullName | Sort-Object ) -join "`n" )


***********************
$( $syncHash.Data.msgTable.StrOutputTitleAllFiles )

$( ( $syncHash.CvsAllFiles.Source.FullName | Sort-Object ) -join "`n" )
"@

			$FileOutput = WriteOutput -Output "$( $syncHash.Data.OutputContent )" -FileName "Search-PotentialVirus"

			$syncHash.DC.TblSummary[0] = $FileOutput

			WriteLog `
				-Text $syncHash.logText `
				-UserInput $syncHash.DC.GridInput[1] `
				-Success $true `
				-OutputPath $FileOutput | Out-Null

			$syncHash.DC.TotalProgress[0] = [double] 0
			TextToSpeech -Text $syncHash.Data.msgTable.StrFileSearchFinished
			$syncHash.Controls.TiSearchSummary.IsEnabled = $true
			$syncHash.Controls.TiWaitProgress.IsEnabled = $false
			$syncHash.Controls.Window.Title = ""
		}
		catch
		{
			$syncHash.Errors.Add( $_ ) | Out-Null
			try { $syncHash.Jobs.FilesDoneTimer.Stop() } catch {}
		}
	} )

	$syncHash.Jobs.FilesDoneTimer.Start()
}

function GetFolders
{
	<#
	.Synopsis
		Start the job to get folderlist
	#>

	$syncHash.Controls.Window.Title = $syncHash.Data.msgTable.StrOPGettingFolders
	$syncHash.Jobs.FolderJob.Handle = $syncHash.Jobs.FolderJob.PS.BeginInvoke()
}

function PrepGetFiles
{
	<#
	.Description
		Create the job (runspace) that will retrieve a list of all files the user have permission for
	#>

	$syncHash.Jobs.Cancel = [System.Threading.CancellationTokenSource]::new()
	$syncHash.Jobs.IsCancelling = $false

	$syncHash.Jobs.FilesJob = [pscustomobject]@{ PS = [powershell]::Create() ; Handle = $null }
	$syncHash.Jobs.FilesJob.PS.AddScript( {
		param ( $syncHash, $FolderList, $Modules, $LastWriteTime )
		Import-Module $Modules

		$syncHash.Controls.Window.Dispatcher.Invoke( [action] {
			$syncHash.DC.BtnAbort[0] = [System.Windows.Visibility]::Visible
			$syncHash.DC.GridProgressInfo[0] = [System.Windows.Visibility]::Visible
			$syncHash.Controls.Window.Title = $syncHash.Data.msgTable.StrOPGettingFiles
			$syncHash.DC.TotalProgress[1] = [double] $FolderList.Count
			$syncHash.DC.TblProgressText[0] = "$( $FolderList.Count ) $( $syncHash.Data.msgTable.StrSearchStartInfo )"
		}, [System.Windows.Threading.DispatcherPriority]::Background )

		[runspacefactory]::CreateRunspacePool()
		$SessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault2()
		$RunspacePool = [runspacefactory]::CreateRunspacePool(
			1, #Min Runspaces
			4 #Max Runspaces
		)
		$RunspacePool.Open()

		foreach ( $Folder in $FolderList )
		{
			$P = [powershell]::Create()
			$P.RunspacePool = $RunspacePool
			$P.AddScript( {
				param ( $syncHash, $Folder, $Modules, $LastWriteTime, $Token )
				Import-Module $Modules

				function Enumerate-Directory
				{
					param (
						[Parameter( Mandatory )][string] $Root,
						[datetime] $MinLastWriteTime = [datetime]::MinValue
					)

					$Stack = [System.Collections.Generic.Stack[string]]::new()
					$Stack.Push( $Root )

					while ( $Stack.Count -gt 0 )
					{
						if ( $Token.IsCancellationRequested )
						{
							return
						}
						$Dir = $Stack.Pop()

						try
						{
							foreach ( $SubDir in [System.IO.Directory]::EnumerateDirectories( $Dir ) )
							{
								if ( $Token.IsCancellationRequested )
								{
									return
								}
								$Stack.Push( $SubDir )
							}
						}
						catch
						{
							continue
						}

						try
						{
							foreach ( $File in [System.IO.Directory]::EnumerateFiles( $Dir ) )
							{
								try
								{
									if ( $Token.IsCancellationRequested )
									{
										return
									}
									# Avoid FileInfo allocation unless it passes the time filter
									$LWT = [System.IO.File]::GetLastWriteTime( $File )

									if ( $LWT -lt $MinLastWriteTime )
									{
										continue
									}
									[System.IO.FileInfo]::new( $File )
								}
								catch
								{}
							}
						}
						catch
						{}
					}
				}

				function Post
				{
					param ( [object[]] $Items )

					# Don’t enqueue anything while cancelling
					if ( $Token.IsCancellationRequested -or $syncHash.Jobs.IsCancelling )
					{
						return
					}

					$syncHash.Controls.Window.Dispatcher.Invoke(
						[action[object[]]] {
							param ( [object[]] $items )

							if ( $syncHash.Jobs.IsCancelling )
							{
								return
							}

							$cvs  = $syncHash.CvsAllFiles
							try
							{
								foreach ( $i in $items )
								{
									if ( $syncHash.Jobs.IsCancelling )
									{
										return
									}

									$cvs.Source.Add( $i )

									if ( ( $i.Name -split '\.' ).Count -gt 2 )
									{
										if ( $i.FullName.StartsWith( $syncHash.User.HomeDirectory ) )
										{
											$syncHash.CvsMultiDotsH.Source.Add( $i )
										}
										else
										{
											$syncHash.CvsMultiDotsG.Source.Add( $i )
										}
									}
								}
							}
							finally
							{
								$cvs.View.Refresh()
							}

						},
						[System.Windows.Threading.DispatcherPriority]::Background,
						( , $Items )
					) | Out-Null
				}

				$FoundFiles = Enumerate-Directory -Root $Folder.Path -MinLastWriteTime $LastWriteTime
				$Objects = [System.Collections.Generic.List[object]]::new( 500 )

				foreach ( $Found in $FoundFiles )
				{
					if ( $Token.IsCancellationRequested -or $syncHash.Jobs.IsCancelling )
					{
						return
					}

					$Objects.Add( $Found ) | Out-Null
					if ( $Objects.Count -ge 200 )
					{
						$buffer = $Objects.ToArray()
						$Objects.Clear()
						Post -Items $buffer
					}
				}

				if ( $Objects.Count -gt 0 )
				{
					Post -Items $Objects.ToArray()
				}

				$OtherPermissions = $Error | `
					Where-Object {
						$_.CategoryInfo.Activity -eq "Get-ChildItem2"
					} | `
					ForEach-Object {
						( $_.Exception.Message -replace "\]" -split "\[" )[1]
						$syncHash.Data.Errors.Add( $_ ) | Out-Null
					}

				$syncHash.Controls.Window.Dispatcher.Invoke( [action] {
					if ( $syncHash.Jobs.IsCancelling )
					{
						return
					}

					( $syncHash.CvsFolderList.Source.Where( { $_.Path -eq $Folder.Path } ) )[0].Searched = $true
					$syncHash.CvsFolderList.View.Refresh()
					$syncHash.DC.TotalProgress[0] += [double] 1
					$syncHash.DC.TblProgressText[0] = "$( ( $syncHash.CvsFolderList.Source.Where( { -not $_.Searched } ) ).Count ) $( $syncHash.Data.msgTable.StrSearchStartInfo )"

					foreach ( $o in $OtherPermissions )
					{
						$syncHash.CvsOtherFolderPermissions.Source.Add( $o )
					}
				}, [System.Windows.Threading.DispatcherPriority]::Background )
			} ) | Out-Null
			$P.AddArgument( $syncHash ) | Out-Null
			$P.AddArgument( $Folder ) | Out-Null
			$P.AddArgument( ( Get-Module ) ) | Out-Null
			$P.AddArgument( $LastWriteTime ) | Out-Null
			$P.AddArgument( $syncHash.Jobs.Cancel.Token ) | Out-Null
			$syncHash.Jobs.FileFetchingJobs.Add( ( [pscustomobject]@{ PS = $P ; Handle = $null } ) ) | Out-Null
		}

		$syncHash.Jobs.FileFetchingJobs | ForEach-Object { $_.Handle = $_.PS.BeginInvoke() }

		do
		{
			Start-Sleep -Seconds 1
		} until ( $syncHash.Jobs.FileFetchingJobs.Handle.Where( { $_.IsCompleted -eq $true } ).Count -eq $FolderList.Count )

		foreach ( $j in @( $syncHash.Jobs.FileFetchingJobs ) )
		{
			try
			{
				if ( $j.Handle )
				{
					$j.PS.EndInvoke( $j.Handle ) | Out-Null
				}
			}
			catch
			{
				$syncHash.Errors.Add( $_ ) | Out-Null
			}
			finally
			{
				try
				{
					$j.PS.Dispose()
				}
				catch
				{}
			}
		}

		try
		{
			$RunspacePool.Close()
			$RunspacePool.Dispose()
		}
		catch {}

		$syncHash.Controls.Window.Dispatcher.Invoke( [action] {
			$syncHash.DC.GridProgressInfo[0] = [System.Windows.Visibility]::Collapsed
			$syncHash.DC.TiSearchSummary[0] = $true
			$syncHash.DC.TcTop[0] = 2
		}, [System.Windows.Threading.DispatcherPriority]::Background )

	} ) | Out-Null
	$syncHash.Jobs.FilesJob.PS.AddArgument( $syncHash )
	$syncHash.Jobs.FilesJob.PS.AddArgument( $syncHash.CvsFolderList.Source )
	$syncHash.Jobs.FilesJob.PS.AddArgument( ( Get-Module ) )
	$syncHash.Jobs.FilesJob.PS.AddArgument( $syncHash.DC.DatePickerStart[0] )

	$syncHash.Controls.Window.Title = $syncHash.Data.msgTable.StrOPWaitGettingFiles
}

function PrepGetFolders
{
	<#
	.Synopsis
		Get folders the user has access to
	#>

	$syncHash.Jobs.FolderJob = [pscustomobject]@{ PS = [powershell]::Create() ; Handle = $null }
	$syncHash.Jobs.FolderJob.PS.AddScript( {
		param ( $syncHash )

		$syncHash.DC.TblProgressText[0] = $syncHash.Data.msgTable.StrSearchingForFolders

		$syncHash.Data.Other = [System.Collections.Generic.List[object]]::new()
		$Folders = [System.Collections.Generic.List[object]]::new()
		$OtherFolders = [System.Collections.Generic.List[object]]::new()
		$syncHash.Data.Groups = [System.Collections.Generic.List[object]]::new()
		$syncHash.DC.GridProgressInfo[0] = [System.Windows.Visibility]::Visible
		$syncHash.DC.TotalProgress[2] = $true
		$seen = [System.Collections.Generic.HashSet[string]]::new( [System.StringComparer]::OrdinalIgnoreCase )
		$processed = [System.Collections.Generic.HashSet[string]]::new( [System.StringComparer]::OrdinalIgnoreCase )

		# Comparisons
		$CompMigOrg = [regex]::new( '_((Org)|(Mig))_', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Compiled )
		$CompRCF = [regex]::new( '.*_Fil_.*User_(C|F)$', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Compiled )
		$CompRR = [regex]::new( "_R$", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Compiled )
		$CompRDesc = [regex]::new( $syncHash.Data.msgTable.CodeGrpRegExDescription, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Compiled )
		$CompRDescExc = [regex]::new( $syncHash.Data.msgTable.CodeGrpRegExDescriptionExclude, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Compiled )
		$CompRDescExc2 = [regex]::new( $syncHash.Data.msgTable.CodeGrpRegExDescriptionExclude2, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Compiled )

		$SplitDesc = "$( $syncHash.Data.msgTable.StrGrpDescriptionSplit ) "
		$SplitSepServ = $syncHash.Data.msgTable.StrSepServer
		$SplitSepServ1 = $syncHash.Data.msgTable.StrSepServerFolder1
		$SplitSepServ2 = $syncHash.Data.msgTable.StrSepServerFolder2
		$SplitSepServ3 = $syncHash.Data.msgTable.StrSepServerFolder3
		$ReplaceDesc = " $( $syncHash.Data.msgTable.StrGrpDescriptionReplace )"

		$UrlCS = "\\$( $syncHash.Data.msgTable.StrSepServer )\ClientSoftware$\"

		try
		{
			$UserHome = [pscustomobject]@{ Path = $syncHash.User.HomeDirectory; Name = "H:"; Description = $syncHash.Data.msgTable.StrHomeFolder; Searched = $false }
			$seen.Add( $syncHash.User.HomeDirectory ) | Out-Null
			$Folders.Add( $UserHome )

			$initial = Get-ADPrincipalGroupMembership $syncHash.User.SamAccountName | `
				Get-ADGroup -Properties Description

			$syncHash.DC.TblProgressText[0] = $syncHash.Data.msgTable.StrFilteringFolders1
			$syncHash.DC.TotalProgress[2] = $false

			$syncHash.Data.FolderLoopList = @( $initial | Where-Object { $CompRCF.IsMatch( $_.Name ) } )
			$syncHash.DC.TotalProgress[0] = [double] 0
			$syncHash.DC.TotalProgress[1] = [double] $syncHash.Data.FolderLoopList.Count
			foreach ( $g in $syncHash.Data.FolderLoopList )
			{
				if ( $processed.Add( $g.DistinguishedName ) )
				{
					$syncHash.Data.Groups.Add( $g ) | Out-Null
				}
				$syncHash.DC.TotalProgress[0] += [double] 1
			}

			$syncHash.DC.TblProgressText[0] = $syncHash.Data.msgTable.StrFilteringFolders2
			$syncHash.Data.FolderLoopList = @( $initial | Where-Object { $CompMigOrg.IsMatch( $_.Name ) } )
			$syncHash.DC.TotalProgress[0] = [double] 0
			$syncHash.DC.TotalProgress[1] = [double] $syncHash.Data.FolderLoopList.Count
			foreach ( $g in $syncHash.Data.FolderLoopList )
			{
				Get-ADPrincipalGroupMembership $g | `
					Where-Object { $CompRCF.IsMatch( $_.Name ) } | `
					Get-ADGroup -Properties Description | `
						ForEach-Object {
							if ( $processed.Add( $_.DistinguishedName ) )
							{
								$syncHash.Data.Groups.Add( $_ ) | Out-Null
							}
						}
				$syncHash.DC.TotalProgress[0] += [double] 1
			}

			$syncHash.DC.TblProgressText[0] = $syncHash.Data.msgTable.StrFilteringFolders3
			$syncHash.Data.FolderLoopList = @( $syncHash.Data.Groups )
			$syncHash.DC.TotalProgress[0] = [double] 0
			$syncHash.DC.TotalProgress[1] = [double] $syncHash.Data.FolderLoopList.Count
			foreach ( $g in $syncHash.Data.FolderLoopList )
			{
				$p = ""
				if ( $CompRDesc.IsMatch( $g.Description )-and `
					-not $CompRDescExc.IsMatch( $g.Description ) -and `
					-not $CompRDescExc2.IsMatch( $g.Description )
				)
				{
					$p = ( ( $g.Description -split $SplitDesc )[1] -split "\." )[0] -replace $ReplaceDesc
				}
				elseif ( $g.Description -match $syncHash.Data.msgTable.StrSepServer )
				{
					if ( $g.Name -match "ClientSoftware" )
					{
						$p = $UrlCS
					}
					elseif ( $g.Description -match "O2\\" )
					{
						$p = "\\$( $SplitSepServ )\$( $SplitSepServ1 )\$( ( $g.Name -replace "_C" -split "$( $SplitSepServ )_" )[1] )"
					}
					elseif ( $g.Name -match "^Or3" )
					{
						$p = "\\$( $SplitSepServ )\$( $SplitSepServ2 )\$( ( $g.Name -replace "_C" -split "$( $SplitSepServ )_" )[1] )"
					}
					elseif ( $g.Name -match "^Op3" )
					{
						$p = "\\$( $SplitSepServ )\$( $SplitSepServ3 )\$( ( $g.Name -replace "_C" -split "$( $SplitSepServ )_" )[1] )"
					}
				}
				else
				{
					$syncHash.Data.Other.Add( ( [pscustomobject]@{ Path = $g.Name ; Name = $g.Name } ) ) | Out-Null
				}

				if ( "" -ne $p )
				{
					try
					{
						[System.IO.Directory]::EnumerateDirectories( $p ) | Out-Null
						if ( $seen.Add( $p ) )
						{
							$FolderObject = [pscustomobject]@{
								"Path" = $p
								"Name" = $g.Name
								"Description" = $g.Description
								"Searched" = $false
							}
							$Folders.Add( $FolderObject ) | Out-Null
						}
					}
					catch
					{
						$OtherFolders.Add( $g.Name ) | Out-Null
					}
				}
				$syncHash.DC.TotalProgress[0] += [double] 1
			}

			$syncHash.Controls.Window.Dispatcher.Invoke(
				[action[object,object]] {
					param ( $items, $OtherItems )

					if ( $syncHash.Jobs.IsCancelling )
					{
						return
					}

					try
					{
						$syncHash.DC.TotalProgress[2] = $false

						$syncHash.Controls.Window.Resources.WaitingText += "`n$( $items.Count ) $( $syncHash.Data.msgTable.StrFolderFoundHeader )"
						$Src  = $syncHash.CvsFolderList.Source
						$View = $syncHash.CvsFolderList.View
						$OSrc  = $syncHash.CvsOtherFolderPermissions.Source
						$OView = $syncHash.CvsOtherFolderPermissions.View

						try
						{
							$syncHash.DC.TotalProgress[0] = [double] 0
							$syncHash.DC.TotalProgress[1] = [double] $items.Count
							foreach ( $i in $items )
							{
								if ( $syncHash.Jobs.IsCancelling )
								{
									return
								}
								$Src.Add( $i )
								$syncHash.DC.TotalProgress[0] += [double] 1
							}

							$syncHash.DC.TotalProgress[0] = [double] 0
							$syncHash.DC.TotalProgress[1] = [double] $OtherItems.Count
							foreach ( $o in $OtherItems )
							{
								if ( $syncHash.Jobs.IsCancelling )
								{
									return
								}
								$OSrc.Add( $o )
								$syncHash.DC.TotalProgress[0] += [double] 1
							}
						}
						catch
						{
							$_.psobject.Properties.Add( [psnoteproperty]::new( "Item", $i ) )
							$syncHash.Errors.Add( $_ ) | Out-Null
						}
						finally
						{
							$View.Refresh()
							$OView.Refresh()
						}
						#$syncHash.Controls.TblFolderCount.GetBindingExpression( [System.Windows.Controls.TextBlock]::TextProperty ).UpdateTarget()

						$syncHash.DC.BtnStartSearch[1] = ( $items.Count -gt 0 )
						$syncHash.DC.TiWaitProgress[0] = $true
						$syncHash.DC.TiSearchSummary[0] = $true
					}
					catch
					{
						$syncHash.Errors.Add( $_ ) | Out-Null
					}
					$syncHash.Controls.Window.Title = ""
				},
				[System.Windows.Threading.DispatcherPriority]::Background,
				( $Folders.ToArray(), $OtherFolders.ToArray() )
			) | Out-Null
			$syncHash.DC.GridProgressInfo[0] = [System.Windows.Visibility]::Collapsed
		}
		catch
		{
			$msg = $_ | Out-String
			$inv = $_.InvocationInfo | Format-List * | Out-String
			$exc = $_.Exception | Format-List * | Out-String
			$ErrMsg = ( $msg + "`n" + $inv + "`n" + $exc )
			Out-File -FilePath $syncHash.Data.ExceptionFile -Append -Force -InputObject $ErrMsg
			$syncHash.Errors.Add( $ErrMsg ) | Out-Null
		}
	} )
	$syncHash.Jobs.FolderJob.PS.AddArgument( $syncHash )
}

function Reset
{
	<#
	.Synopsis
		Reset all controls
	#>

	$syncHash.Controls.Window.Dispatcher.BeginInvoke( [action] {
		$syncHash.DC.CbSetAccountDisabled[0] = $false
		$syncHash.CvsAllFiles.Source.Clear()
		$syncHash.CvsFolderList.Source.Clear()
		$syncHash.CvsMultiDotsG.Source.Clear()
		$syncHash.CvsMultiDotsH.Source.Clear()
		$syncHash.DC.GridProgressInfo[0] = [System.Windows.Visibility]::Collapsed
		$syncHash.DC.GridInput[0] = $true
		$syncHash.DC.RbLatest[0] = $true
		$syncHash.DC.TblSummary[0] = ""
		$syncHash.DC.TblFoundUser[0] = ""
		$syncHash.DC.TblAccountDisabledInfo[0] = ""
		$syncHash.DC.TblProgressText[0] = $syncHash.DC.TbQuestion[0] = $syncHash.DC.TbCaseNr[0] = $syncHash.Controls.TbId.Text = ""

		$syncHash.DC.TotalProgress[0] = [double] 0.0
		$syncHash.Data.OutputContent = ""
	} )

	$syncHash.User = $null
	$syncHash.DC.TcTop[0] = 0
	$syncHash.Controls.TiSearchSettings.IsEnabled = $true
	$syncHash.Controls.TiSearchSummary.IsEnabled = $false
	$syncHash.Controls.TiWaitProgress.IsEnabled = $false
	$syncHash.Controls.CbSetAccountDisabled.Content = $syncHash.Data.msgTable.ContentCbSetAccountDisabled
	$syncHash.Controls.Window.Resources.WaitingText = $syncHash.Data.msgTable.ContentTiWaitProgress
	$syncHash.Controls.Window.DataContext.SelectedItem = $null

	$syncHash.Controls.TblFileType.GetBindingExpression( [System.Windows.Controls.TextBlock]::TextProperty ).UpdateTarget()
	$syncHash.Controls.TblFileStreamsCount.GetBindingExpression( [System.Windows.Controls.TextBlock]::TextProperty ).UpdateTarget()
	$syncHash.Controls.TblLastWriteTime.GetBindingExpression( [System.Windows.Controls.TextBlock]::TextProperty ).UpdateTarget()
	$syncHash.Controls.TblFileOwner.GetBindingExpression( [System.Windows.Controls.TextBlock]::TextProperty ).UpdateTarget()
	$syncHash.Controls.TblFileSize.GetBindingExpression( [System.Windows.Controls.TextBlock]::TextProperty ).UpdateTarget()
	$syncHash.Controls.TblFilePath.GetBindingExpression( [System.Windows.Controls.TextBlock]::TextProperty ).UpdateTarget()
	$syncHash.Controls.TblFileName.GetBindingExpression( [System.Windows.Controls.TextBlock]::TextProperty ).UpdateTarget()
	$syncHash.Controls.BtnShowFileStreams.GetBindingExpression( [System.Windows.Controls.Button]::IsEnabledProperty ).UpdateTarget()

	$syncHash.Data.ErrorHashes.Clear()
	$syncHash.Data.ScannedForVirus.Clear()
	if ( $null -ne $syncHash.Jobs.FilesJob )
	{
		$syncHash.Jobs.FilesJob.PS.EndInvoke( $syncHash.Jobs.FilesJob.Handle ) | Out-Null
	}
	if ( $null -ne $syncHash.Jobs.FolderJob )
	{
		$syncHash.Jobs.FolderJob.PS.EndInvoke( $syncHash.Jobs.FolderJob.Handle ) | Out-Null
	}
	$syncHash.Jobs.FileFetchingJobs | `
		ForEach-Object {
			try
			{
				$_.PS.EndInvoke( $_.Handle ) | Out-Null
			}
			catch
			{}
		}
	$syncHash.Jobs.FileFetchingJobs.Clear()
}

function SetLocalizations
{
	<#
	.Synopsis
		Set some localizations and UI collections
	#>

	$syncHash.CvsAllFiles = Get-Cvs "CvsAllFiles"
	if ( $null -eq $syncHash.CvsAllFiles.Source )
	{
		$syncHash.CvsAllFiles.Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
		[System.Windows.Data.BindingOperations]::EnableCollectionSynchronization( $syncHash.CvsAllFiles.Source, $syncHash.Controls.LvAllFiles )
	}

	$syncHash.CvsFolderList = Get-Cvs "CvsFolderList"
	if ( $null -eq $syncHash.CvsFolderList.Source )
	{
		$syncHash.CvsFolderList.Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
		[System.Windows.Data.BindingOperations]::EnableCollectionSynchronization( $syncHash.CvsFolderList.Source, $syncHash.Controls.DgFolderList )
	}

	$syncHash.CvsMultiDotsG = Get-Cvs "CvsMultiDotsG"
	if ( $null -eq $syncHash.CvsMultiDotsG.Source )
	{
		$syncHash.CvsMultiDotsG.Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	}

	$syncHash.CvsMultiDotsH = Get-Cvs "CvsMultiDotsH"
	if ( $null -eq $syncHash.CvsMultiDotsH.Source )
	{
		$syncHash.CvsMultiDotsH.Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	}

	$syncHash.CvsOtherFolderPermissions = Get-Cvs "CvsOtherFolderPermissions"
	if ( $null -eq $syncHash.CvsOtherFolderPermissions.Source )
	{
		$syncHash.CvsOtherFolderPermissions.Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
	}

	$syncHash.Controls.StreamsList.Resources['CvsStreamsList'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()

	"DgStreamsList", "LvMultiDotsH", "LvMultiDotsG", "DgFolderList", "LvAllFiles" | `
		ForEach-Object {
			[System.Windows.Data.BindingOperations]::EnableCollectionSynchronization( $syncHash.Controls."$( $_ )".ItemsSource, $syncHash.Controls."$( $_ )" )
		}
		
	$syncHash.Controls.Window.Resources.WaitingText = $syncHash.Data.msgTable.ContentTiWaitProgress
}

####################### Script start
$controls = New-Object Collections.ArrayList
[void]$controls.Add( @{ CName = "BtnAbort"; Props = @( @{ PropName = "Visibility"; PropVal = [System.Windows.Visibility]::Collapsed } ) } )
[void]$controls.Add( @{ CName = "BrdCaseNr"; Props = @( @{ PropName = "BorderBrush"; PropVal = "#0000" } ) } )
[void]$controls.Add( @{ CName = "BrdId"; Props = @( @{ PropName = "BorderBrush"; PropVal = "#0000" } ) } )
[void]$controls.Add( @{ CName = "BtnPrep"; Props = @(
	@{ PropName = "Visibility" ; PropVal = [System.Windows.Visibility]::Visible }
	@{ PropName = "IsEnabled" ; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "BtnStartSearch"; Props = @(
	@{ PropName = "Visibility"; PropVal = [System.Windows.Visibility]::Collapsed } ;
	@{ PropName = "IsEnabled"; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "CbExpandGroups"; Props = @( @{ PropName = "IsChecked"; PropVal = $true } ) } )
[void]$controls.Add( @{ CName = "CbGroupExtensions"; Props = @( @{ PropName = "IsChecked"; PropVal = $true } ) } )
[void]$controls.Add( @{ CName = "CbSetAccountDisabled"; Props = @( @{ PropName = "IsChecked" ; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "DatePickerStart"; Props = @( @{ PropName = "SelectedDate"; PropVal = ( Get-Date ).AddDays( -14 ) } ) } )
[void]$controls.Add( @{ CName = "GridInput"; Props = @(
	@{ PropName = "IsEnabled"; PropVal = $true } ;
	@{ PropName = "Tag"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "GridProgressInfo"; Props = @( @{ PropName = "Visibility"; PropVal = [System.Windows.Visibility]::Collapsed } ) } )
[void]$controls.Add( @{ CName = "RbAll"; Props = @(
	@{ PropName = "IsChecked"; PropVal = $false } ;
	@{ PropName = "Visibility"; PropVal = [System.Windows.Visibility]::Collapsed } ) } )
[void]$controls.Add( @{ CName = "RbLatest"; Props = @( @{ PropName = "IsChecked" ; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "RbPrevDate"; Props = @( @{ PropName = "IsChecked"; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "TbCaseNr"; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "TblAccountDisabledInfo"; Props = @(
	@{ PropName = "Text"; PropVal = "" }
) } )
[void]$controls.Add( @{ CName = "TblFoundUser"; Props = @(
	@{ PropName = "Text"; PropVal = "" }
	@{ PropName = "Foreground"; PropVal = "#0000" }
) } )
[void]$controls.Add( @{ CName = "TblProgressText"; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "TblSummary"; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "TblUser"; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "TbQuestion"; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "TcTop"; Props = @( @{ PropName = "SelectedIndex"; PropVal = 0 } ) } )
[void]$controls.Add( @{ CName = "TiSearchSettings"; Props = @( @{ PropName = "IsEnabled"; PropVal = $true } ) } )
[void]$controls.Add( @{ CName = "TiSearchSummary"; Props = @( @{ PropName = "IsEnabled"; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "TiWaitProgress"; Props = @( @{ PropName = "IsEnabled"; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "TotalProgress"; Props = @(
	@{ PropName = "Value"; PropVal = [double] 0 } ;
	@{ PropName = "Maximum" ; PropVal = [double] 0 } ;
	@{ PropName = "IsIndeterminate" ; PropVal = $false } ) } )

BindControls $syncHash $controls

$Apps = @()
$Apps += Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" # 32 Bit
$Apps += Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"

$syncHash.Data.BaseDir = ( Get-Item $MyInvocation.PsScriptRoot ).Parent.FullName
$syncHash.Data.ExceptionFile = "$( $syncHash.Data.BaseDir )\Output\Suite\Search_Virus_UI_Exception.txt"
$syncHash.Data.Editor = $Apps | `
	Where-Object { $_.DisplayName -match "Notepad\+\+" } | `
	Select-Object -ExpandProperty DisplayIcon
if ( $null -eq $syncHash.Data.Editor )
{
	$syncHash.Data.Editor = "notepad"
}

SetLocalizations
$syncHash.Controls.Window.DataContext.PsObject.Properties.Add( [psnoteproperty]::new( "SelectedItem", $null ) )
$syncHash.Controls.StreamsList.DataContext = $syncHash.Controls.Window.DataContext
$syncHash.Controls.Window.Dispatcher.Add_UnhandledException(
	[System.Windows.Threading.DispatcherUnhandledExceptionEventHandler] {
		param ( $sender, $e )

		# During cancellation, swallow UI exceptions so the host doesn't crash
		if ( $syncHash.Jobs.IsCancelling )
		{
			$ErrorRecord = [pscustomobject]@{
				When = Get-Date;
				Hook = 'UIUnhandledDuringCancel';
				Message = $e.Exception.Message;
				Exception = $e.Exception
			}
			$syncHash.Errors.Add( $ErrorRecord ) | Out-Null

			$e.Handled = $true

			Out-File -FilePath $syncHash.Data.ExceptionFile -Append -Force -InputObject $ErrorRecord

			return
		}

		# Otherwise log and let it crash (or set Handled=$true if you prefer)
		$ErrorRecord = [pscustomobject]@{
			When = Get-Date;
			Hook = 'UIUnhandled';
			Message = $e.Exception.Message;
			Exception = $e.Exception
		}
		Out-File -FilePath $syncHash.Data.ExceptionFile -Append -Force -InputObject $ErrorRecord
		$syncHash.Errors.Add( $ErrorRecord ) | Out-Null
		$e.Handled = $true
} )

$syncHash.Jobs.FileFetchingJobs = [System.Collections.ArrayList]::new()
$syncHash.Data.Errors = [System.Collections.ArrayList]::Synchronized( [System.Collections.ArrayList]::new() )
$syncHash.Data.ErrorHashes = @()
$syncHash.Data.ScannedForVirus = [System.Collections.ArrayList]::Synchronized( [System.Collections.ArrayList]::new() )
$syncHash.ScriptVar = New-Object -ComObject WScript.Shell
WriteLog -Text $syncHash.Data.msgTable.StrLogScriptStart -UserInput "-" -Success $true | Out-Null

# Create an observable collection for a list of folders the scriptuser does not have permission to, that will respond to being updated
$syncHash.CvsOtherFolderPermissions.Source.Add_CollectionChanged( {
	$syncHash.Controls.TbQuestion.Text = @"
$( $syncHash.Controls.TbId.Text ) $( $syncHash.Data.msgTable.StrQuestion1 ) $( $syncHash.DC.TbCaseNr[0] )
$( $syncHash.Data.msgTable.StrQuestion2 )
$( $syncHash.Data.msgTable.StrQuestion3 )

$( $OFS = "`n" ; $syncHash.CvsOtherFolderPermissions.Source | Sort-Object )
"@
} )

# Create an observable collection for text as output that will respond to being updated
# Once updated, write to output-fil
$syncHash.Data.OutputContent = ""

# Abort current filesearch
$syncHash.Controls.BtnAbort.Add_Click( {
	try
	{
		if ( $syncHash.Jobs.IsCancelling )
		{
			return
		}

		$syncHash.Jobs.IsCancelling = $true
		$syncHash.Controls.Window.Dispatcher.BeginInvoke( [action] {
			$syncHash.DC.TblProgressText[0] = $syncHash.Data.msgTable.StrCanceling
		}, [System.Windows.Threading.DispatcherPriority]::Background ) | Out-Null

		if ( $syncHash.Jobs.Cancel )
		{
			$syncHash.Jobs.Cancel.Cancel()
		}

		try { $syncHash.Jobs.FilesJob.PS.Stop() } catch {}
		foreach ($j in @($syncHash.Jobs.FileFetchingJobs)) { try { $j.PS.Stop() } catch {} }

		if (-not $syncHash.Jobs.AbortTimer)
		{
			$syncHash.Jobs.AbortTimer = [System.Windows.Threading.DispatcherTimer]::new()
			$syncHash.Jobs.AbortTimer.Interval = [TimeSpan]::FromMilliseconds(200)

			$syncHash.Jobs.AbortTimer.Add_Tick( {
				try
				{
					# check if all worker handles are completed
					$allDone = $true

					foreach ( $j in @( $syncHash.Jobs.FileFetchingJobs ) )
					{
						if ( $j.Handle -and -not $j.Handle.IsCompleted )
						{
							$allDone = $false
							break
						}
					}

					if ( $allDone -and $syncHash.Jobs.FilesJob.Handle -and -not $syncHash.Jobs.FilesJob.Handle.IsCompleted )
					{
						$allDone = $false
					}

					if ( -not $allDone )
					{
						return
					}

					# stop timer
					$syncHash.Jobs.AbortTimer.Stop()

					# now it’s safe to EndInvoke/Dispose (still on UI thread, but no blocking now)
					foreach ($j in @($syncHash.Jobs.FileFetchingJobs)) {
						try { if ($j.Handle) { $null = $j.PS.EndInvoke($j.Handle) } } catch {}
						try { $j.PS.Dispose() } catch {}
					}
					try { if ($syncHash.Jobs.FilesJob.Handle) { $null = $syncHash.Jobs.FilesJob.PS.EndInvoke($syncHash.Jobs.FilesJob.Handle) } } catch {}
					try { $syncHash.Jobs.FilesJob.PS.Dispose() } catch {}

					$syncHash.Jobs.FileFetchingJobs.Clear()
					$syncHash.Jobs.FilesJob = $null
					$syncHash.Jobs.Cancel = $null
					$syncHash.Jobs.IsCancelling = $false
					$syncHash.Jobs.UiUpdatesEnabled = $true

					$syncHash.DC.TcTop[0] = 2
					$syncHash.Controls.TiSearchSettings.IsEnabled = $true
					$syncHash.DC.TotalProgress[0] = [double] 0.0
					$syncHash.DC.TblProgressText[0] = ""
					$syncHash.Controls.Window.Title = ""

					$syncHash.Jobs.IsCancelling = $false
					$syncHash.Jobs.UiUpdatesEnabled = $true

				}
				catch {
					$syncHash.Errors.Add($_) | Out-Null
					try { $syncHash.Jobs.AbortTimer.Stop() } catch {}
				}
			} )
		}

		$syncHash.Jobs.AbortTimer.Start()
	}
	catch
	{
		$syncHash.Errors.Add( $_ ) | Out-Null
	}
} )

#
$syncHash.Controls.BtnCloseStreamsList.Add_Click( {
	$syncHash.Controls.StreamsList.Resources['CvsStreamsList'].Source.Clear()
	$syncHash.Controls.StreamsList.Visibility = [System.Windows.Visibility]::Hidden
} )

# Copy text for question to clipboard
$syncHash.Controls.BtnCreateQuestion.Add_Click( {
	$OutputEncoding = ( New-Object System.Text.UnicodeEncoding $false, $false ).psobject.BaseObject
	$syncHash.DC.TbQuestion[0] | clip
	Show-MessageBox $syncHash.Data.msgTable.StrQuestionCopied
	WriteLog -Text "$( $syncHash.Data.msgTable.StrLogQuestionCopied )`n**************`n$( $syncHash.DC.TbQuestion[0] )`n**************" -UserInput $syncHash.DC.GridInput[1] | Out-Null
} )

# Opens the folder selected file is located in
$syncHash.Controls.BtnOpenFolder.Add_Click( {
	foreach ( $Path in $syncHash.ActiveListView.SelectedItems.FullName )
	{
		Start-Process explorer -ArgumentList "/select, $Path"
	}

	WriteLog -Text $syncHash.Data.msgTable.StrLogMsgOpenFolder -UserInput "$( $syncHash.DC.GridInput[1] )`n$( $syncHash.ActiveListView.SelectedItems.FullName )" -Success $true
} )

# Opens the summaryfile
$syncHash.Controls.BtnOpenSummary.Add_Click( {
	Start-Process $syncHash.Data.Editor -ArgumentList """$( $syncHash.DC.TblSummary[0] )"""
} )

# Prepare for filesearch by creating jobs and retrieving folderlist
$syncHash.Controls.BtnPrep.Add_Click( {
	$syncHash.CvsFolderList.Source.Clear()
	PrepGetFolders
	PrepGetFiles
	$this.Visibility = [System.Windows.Visibility]::Collapsed
	$syncHash.DC.BtnStartSearch[0] = [System.Windows.Visibility]::Visible
	GetFolders
	WriteLog -Text $syncHash.Data.msgTable.StrLogMsgFolderSearch -UserInput $syncHash.DC.GridInput[1] -Success $true
} )

# Reset arrays, values and controls to default values
$syncHash.Controls.BtnReset.Add_Click( {
	if ( -not $syncHash.User.Enabled )
	{
		if ( ( Show-MessageBox -Text $syncHash.Data.msgTable.StrEnableUser -Button ( [System.Windows.MessageBoxButton]::YesNo ) ) -eq "Yes" )
		{
			Set-ADUser -Identity $syncHash.User.SamAccountName -Enabled $true
		}
	}

	Reset
	$syncHash.DC.GridInput[0] = $true
	$syncHash.DC.BtnStartSearch[0] = [System.Windows.Visibility]::Collapsed
	$syncHash.DC.BtnPrep[0] = [System.Windows.Visibility]::Visible
	$syncHash.Controls.TbCaseNr.Focus()
} )

# Start a virus scan of selected file
$syncHash.Controls.BtnRunVirusScan.Add_Click( {
	if ( $syncHash.ActiveListView.SelectedItems.Count -gt 0 )
	{
		if ( $syncHash.ActiveListView.SelectedItems.Count -gt 2 )
		{
			Show-MessageBox -Text $syncHash.Data.msgTable.StrMultiFileVirusSearch
		}

		foreach ( $File in $syncHash.ActiveListView.SelectedItems )
		{
			if ( $File.TT -match "^H:\\" )
			{
				$path = $File.TT -replace "^H:", $syncHash.User.HomeDirectory
			}
			else
			{
				$path = $File.TT
			}
			$PathToScan = Get-Item $path

			if ( $PathToScan.FullName -match "\`$Recycle Bin" )
			{
				Show-MessageBox -Text "$( $PathToScan.FullName )`n$( $syncHash.Data.msgTable.MsgRecycleBin )"
			}
			else
			{
				try
				{
					$Shell = New-Object -Com Shell.Application
					$ShellFolder = $Shell.NameSpace( $PathToScan.Directory.FullName )
					$ShellFile = $ShellFolder.ParseName( $PathToScan.Name )
					$ShellFile.InvokeVerb( $syncHash.Data.msgTable.StrVerbVirusScan )
					[void] $syncHash.Data.ScannedForVirus.Add( [pscustomobject]@{ Path = $PathToScan.FullName ; Time = ( Get-Date ) } )
				}
				catch
				{
					Show-MessageBox -Text "$( $syncHash.Data.msgTable.ErrScanError ) $( $_.Exception.Message )" -Title $syncHash.Data.msgTable.ErrScanErrorTitle -Icon "Error"
				}
			}
		}
		WriteLog -Text $syncHash.Data.msgTable.LogScannedFile -UserInput "$( $syncHash.DC.GridInput[1] )`n$( $syncHash.Data.msgTable.LogScannedFileTitle ) $( $syncHash.ActiveListView.SelectedItems.FullName )" -Success $true | Out-Null
		$OFS = "`n"
		Set-Content -Value @"
$( $syncHash.Data.OutputContent )

***********************
$( $syncHash.Data.msgTable.StrLogMsgFilesScannedForVirus )

$( [string]( $syncHash.Data.ScannedForVirus | ForEach-Object { "$( $_.Path ) ($( Get-Date $_.Time -f "yyyy-MM-dd HH:mm:ss" ))" } ) )
"@ -Path $syncHash.DC.TblSummary[0]
	}
} )

#
$syncHash.Controls.BtnRunVirusScanDir.Add_Click( {
	<#
	function Convert-SepLogRow {
    param(
        [Parameter(Mandatory)]
        [string]$Row
    )

    $headers = 1..90 | ForEach-Object { "C$_" }
    $obj = $Row | ConvertFrom-Csv -Header $headers

    $message = $obj.C14

    $result = [pscustomobject]@{
        Row = $Row
        RawMessage      = $message
        ComputerName    = $obj.C6
        UserName        = $obj.C7
        Domain          = $obj.C35
        MacAddress      = $obj.C36
        SepVersion      = $obj.C37
        Status          = $null
        Risks           = $null
        Scanned         = $null
        Omitted         = $null
        TrustedSkipped  = $null
    }

    if ($message -match '^(?<Status>.+?):\s+Risks:\s+(?<Risks>\d+)\s+Scanned:\s+(?<Scanned>\d+)\s+Files/Folders/Drives Omitted:\s+(?<Omitted>\d+)\s+Trusted Files Skipped:\s+(?<Trusted>\d+)') {
        $result.Status         = $matches.Status
        $result.Risks          = [int]$matches.Risks
        $result.Scanned        = [int]$matches.Scanned
        $result.Omitted        = [int]$matches.Omitted
        $result.TrustedSkipped = [int]$matches.Trusted
    }

    $result
}

$a  = ( Get-Content -Raw -Path "C:\ProgramData\Symantec\Symantec Endpoint Protection\14.3.12154.10000.105\Data\Logs\AV\04022026.Log" ) -split '\r\n'
$b = [System.Collections.Generic.List[object]]::new()
$re = [regex]::new( $env:USERNAME )
$headers = 1..90 | ForEach-Object { "C$_" }
foreach( $r in $a )
{
    if ( $re.IsMatch( $r ) -and $r.Length -gt 0 )
    {
        $b.Add( ( Convert-SepLogRow $r ) ) | Out-Null
    }
}#>
} )

# Search on Google for the fileextension
$syncHash.Controls.BtnSearchExt.Add_Click( {
	$SelectedExtensions = $syncHash.ActiveListView.SelectedItems.Extension | Select-Object -Unique
	foreach ( $Ext in $SelectedExtensions )
	{
		Start-Process chrome "https://www.google.com/search?q=fileextension+$( $Ext )"
	}
	WriteLog -Text $syncHash.Data.msgTable.StrLogMsgSearchExt -UserInput "$( $syncHash.DC.GridInput[1] )`n$SelectedExtensions" -Success $true
} )

# Search on Google for the filename
$syncHash.Controls.BtnSearchFileName.Add_Click( {
	$SelectedNames = $syncHash.ActiveListView.SelectedItems.Name | Select-Object -Unique
	foreach ( $Name in $SelectedNames )
	{
		Start-Process chrome "https://www.google.com/search?q=`"$( $Name )`""
	}
	WriteLog -Text $syncHash.Data.msgTable.StrLogMsgSearchFileName -UserInput "$( $syncHash.DC.GridInput[1] )`n$SelectedNames" -Success $true
} )

# List filestreams
$syncHash.Controls.BtnShowFileStreams.Add_Click( {
	if ( 1 -eq $syncHash.ActiveListView.SelectedItems.Count )
	{
		$syncHash.Controls.TblStreamsListFileName.Text = $syncHash.ActiveListView.SelectedItem.FullName
		$syncHash.ActiveListView.SelectedItem.Streams | `
			Where-Object { $_ } | `
			ForEach-Object {
				$syncHash.Controls.StreamsList.Resources['CvsStreamsList'].Source.Add( $_ )
			}
		$syncHash.Controls.StreamsList.Resources['CvsStreamsList'].View.Refresh()
		$syncHash.Controls.StreamsList.Visibility = [System.Windows.Visibility]::Visible
	}
} )

# Starts the search
$syncHash.Controls.BtnStartSearch.Add_Click( {
	$this.IsEnabled = $false
	$syncHash.DC.GridInput[1] = "{0}: {1}`n{2}: {3}" -f $syncHash.Data.msgTable.StrLogMsgId, $this.Text, $syncHash.Data.msgTable.StrLogMsgCaseNr, $syncHash.DC.TbCaseNr[0]
	$syncHash.Start = Get-Date

	if ( $syncHash.DC.CbSetAccountDisabled[0] )
	{
		Set-ADUser -Identity $syncHash.User.SamAccountName -Enabled $false
		$syncHash.User.Enabled = $false
	}

	$syncHash.DC.TcTop[0] = 1

	GetFiles
} )

# Expand/collaps groups in datagrid
$syncHash.Controls.CbExpandGroups.Add_Checked( { $syncHash.Controls.Window.Resources.ExpandGroups = $true } )
$syncHash.Controls.CbExpandGroups.Add_Unchecked( { $syncHash.Controls.Window.Resources.ExpandGroups = $false } )

# Group files in LvAllFiles according to extension
$syncHash.Controls.CbGroupExtensions.Add_Checked( {
	if ( $syncHash.CvsAllFiles.GroupDescriptions.Count -eq 0 )
	{
		$syncHash.CvsAllFiles.GroupDescriptions.Add( $syncHash.Data.GroupingDescFileTypes )
		$syncHash.Data.SortDescriptions | `
			ForEach-Object { $syncHash.CvsAllFiles.SortDescriptions.Add( $_ ) }
		$syncHash.CvsAllFiles.View.Refresh()
	}
} )

# Disable grouping in LvAllFiles
$syncHash.Controls.CbGroupExtensions.Add_Unchecked( {
	$syncHash.CvsAllFiles.GroupDescriptions.Clear()
	$syncHash.CvsAllFiles.SortDescriptions.Clear()
	$syncHash.CvsAllFiles.SortDescriptions.Add( ( [System.ComponentModel.SortDescription]::new( "Name", [System.DirectoryServices.SortDirection]::Ascending ) ) )
	$syncHash.CvsAllFiles.View.Refresh()
} )

$syncHash.Controls.LvAllFiles.Add_SelectionChanged( {
	if ( $this.SelectedItems.Count -ne 1 )
	{
		$syncHash.Controls.Window.Resources.FileOpsEnabled = $false
		return
	}

	Add-FileProperties -File $this.SelectedItem
} )
$syncHash.Controls.LvMultiDotsH.Add_SelectionChanged( {
	if ( $this.SelectedItems.Count -ne 1 )
	{
		$syncHash.Controls.Window.Resources.FileOpsEnabled = $false
		return
	}

	Add-FileProperties -File $this.SelectedItem
} )

$syncHash.Controls.LvMultiDotsG.Add_SelectionChanged( {
	if ( $this.SelectedItems.Count -ne 1 )
	{
		$syncHash.Controls.Window.Resources.FileOpsEnabled = $false
		return
	}

	Add-FileProperties -File $this.SelectedItem
} )

# Radiobutton for all files is selected, set startdate to two months ago
$syncHash.Controls.RbAll.Add_Checked( { $syncHash.DC.DatePickerStart[0] = ( Get-Date ).AddDays( -60 ) } )

# Radiobutton for files updated in the last two weeks, is selected
$syncHash.Controls.RbLatest.Add_Checked( { $syncHash.DC.DatePickerStart[0] = ( Get-Date ).AddDays( -14 ) } )

# Set selected listview
$syncHash.Controls.LvAllFiles.Add_IsVisibleChanged( { if ( $this.IsVisible ) { $syncHash.ActiveListView = $this } } )
$syncHash.Controls.LvMultiDotsH.Add_IsVisibleChanged( { if ( $this.IsVisible ) { $syncHash.ActiveListView = $this } } )
$syncHash.Controls.LvMultiDotsG.Add_IsVisibleChanged( { if ( $this.IsVisible ) { $syncHash.ActiveListView = $this } } )

# Adjust width of first column in LvAllFiles as UI changes
$syncHash.Controls.LvAllFiles.Add_SizeChanged( {
	$syncHash.Controls.LvAllFiles.View.Columns[0].Width = ( [System.Windows.Media.VisualTreeHelper]::GetChild( $syncHash.Controls.LvAllFiles, 0 ) ).ActualWidth - (
		$syncHash.Controls.LvAllFiles.View.Columns[1].ActualWidth +
		$syncHash.Controls.LvAllFiles.View.Columns[2].ActualWidth +
		$syncHash.Controls.LvAllFiles.View.Columns[3].ActualWidth +
		$syncHash.Controls.LvAllFiles.View.Columns[4].ActualWidth +
		$syncHash.Controls.LvAllFiles.View.Columns[5].ActualWidth )
} )

# Clear list when window is closing
$syncHash.Controls.StreamsList.Add_Closing( {
	$args[1].Handled = $true
	$this.Visibility = [System.Windows.Visibility]::Collapsed
	$syncHash.Controls.StreamsList.Resources['CvsStreamsList'].Source.Clear()
} )

# Casenumber was entered, set user input text
$syncHash.Controls.TbCaseNr.Add_TextChanged( {
	if ( $this.Text -match "^(Cn|ICn)\d{7}$" )
	{
		$syncHash.DC.BrdCaseNr[0] = "Green"
	}
	else
	{
		if ( $this.Text.Length -gt 0 ) { $syncHash.DC.BrdCaseNr[0] = "Red" }
		else { $syncHash.DC.BrdCaseNr[0] = "#0000" }
	}

	Assert-Input
} )

# Id was entered, verify if user exists
$syncHash.Controls.TbId.Add_TextChanged( {
	$syncHash.DC.TblFoundUser[0] = ""
	$syncHash.DC.TblAccountDisabledInfo[0] = ""
	if ( $this.Text -match "\w{4}" )
	{
		try
		{
			$a = Get-ADUser $this.Text -Properties HomeDirectory -ErrorAction Stop
			$syncHash.User = [pscustomobject]@{
				Name = $a.Name
				HomeDirectory = $a.HomeDirectory
				SamAccountName = $a.SamAccountName
				Enabled = $a.Enabled
				DN = $a.DistinguishedName
			}
			$syncHash.DC.TblUser[0] = $syncHash.User.Name
			$syncHash.DC.TblFoundUser[0] = $syncHash.User.Name

			$syncHash.DC.TblFoundUser[1] = $syncHash.DC.BrdId[0] = "Green"
			$syncHash.DC.CbSetAccountDisabled[0] = -not $syncHash.User.Enabled

			if ( $syncHash.DC.CbSetAccountDisabled[0] )
			{
				$syncHash.DC.TblAccountDisabledInfo[0] = $syncHash.Data.msgTable.StrUserAccountAlreadyLocked
			}
		}
		catch
		{
			$syncHash.DC.BrdId[0] = "Red"
			$syncHash.DC.TblFoundUser[0] = $syncHash.Data.msgTable.StrErrUserNotFound
		}
	}
	elseif ( $this.Text.Length -eq 0 )
	{
		$syncHash.DC.BrdId[0] = "#0000"
	}
	else
	{
		$syncHash.DC.BrdId[0] = "Red"
	}

	Assert-Input
} )

# UI is made visible, if a user is not loaded, enter SamAccountName in textbox for ID
$syncHash.Controls.Window.Add_IsVisibleChanged( {
	if ( $this.IsVisible -and ( $null -eq $syncHash.User ) )
	{
		$syncHash.Controls.TbId.Text = $syncHash.Controls.Window.Resources['SearchedItem'].AD.SamAccountName
	}
} )

# Activate window and set focus when the window is loaded
$syncHash.Controls.Window.Add_Loaded( {
	$syncHash.CvsFolderList = $syncHash.Controls.Window.FindResource( 'CvsFolderList' )
	$syncHash.CvsAllFiles = $syncHash.Controls.Window.Resources.CvsAllFiles
	$syncHash.CvsMultiDotsH = $syncHash.Controls.Window.Resources.CvsMultiDotsH
	$syncHash.CvsMultiDotsG = $syncHash.Controls.Window.Resources.CvsMultiDotsG

	foreach ( $cvs in @( $syncHash.CvsFolderList, $syncHash.CvsAllFiles, $syncHash.CvsMultiDotsH, $syncHash.CvsMultiDotsG ) )
	{
		if ( $cvs -and -not $cvs.Source )
		{
			$cvs.Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
		}
	}

	$syncHash.DC.CbExpandGroups[0] = $syncHash.Controls.Window.Resources.ExpandGroups
	$syncHash.DC.RbLatest[0] = $true
	$syncHash.ActiveListView = $syncHash.Controls.LvAllFiles
	$syncHash.Controls.TbCaseNr.Focus()
	$syncHash.Controls.LvAllFiles.View.Columns[0].Width = ( [System.Windows.Media.VisualTreeHelper]::GetChild( $syncHash.Controls.LvAllFiles, 0 ) ).ActualWidth - (
		$syncHash.Controls.LvAllFiles.View.Columns[1].ActualWidth +
		$syncHash.Controls.LvAllFiles.View.Columns[2].ActualWidth +
		$syncHash.Controls.LvAllFiles.View.Columns[3].ActualWidth +
		$syncHash.Controls.LvAllFiles.View.Columns[4].ActualWidth +
		$syncHash.Controls.LvAllFiles.View.Columns[5].ActualWidth )

	$syncHash.Data.GroupingDescFileTypes = $syncHash.CvsAllFiles.GroupDescriptions[0]
	$syncHash.Data.SortingDescFtNm = $syncHash.CvsAllFiles.SortDescriptions
} )

Export-ModuleMember

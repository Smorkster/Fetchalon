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

$( $syncHash.Data.msgTable.StrLogMsgTotNumFiles ) $( $syncHash.Data.FullFileList.Count )
$( $syncHash.Data.msgTable.StrLogMsgOtherPermCount ) $( $syncHash.OtherFolderPermissions.Count )
$( $syncHash.Data.msgTable.StrLogMsgFilesMatchingFilterCount ) $( $syncHash.DC.LvFilterMatch[0].Count )
$( $syncHash.Data.msgTable.StrLogMsgFilesWithDoubleExtH ) $( $syncHash.DC.LvMultiDotsH[0].Count )
$( $syncHash.Data.msgTable.StrLogMsgFilesWithDoubleExtG ) $( $syncHash.DC.LvMultiDotsG[0].Count )
"@
}

function GenerateOutput
{
	<#
	.Synopsis
		Create the outputtext
	#>

	$ofs = "`n"
	$syncHash.OutputContent.Item( 0 ) = @"
$( $syncHash.Data.msgTable.StrOutput1 )

$( $syncHash.Data.msgTable.StrOutput2 ): $( $syncHash.User.Name )
$( $syncHash.Data.msgTable.StrOutput3 ): $( $syncHash.Controls.TbCaseNr.Text )
$( if ( $syncHash.DC.RbLatest[0] ) { "$( $syncHash.Data.msgTable.StrOutputTimeline1 ) $( $syncHash.DC.DatePickerStart[0].ToShortDateString() ) -> $( ( Get-Date ).ToShortDateString() )"}
elseif ( $syncHash.DC.RbPrevDate[0] ) { "$( $syncHash.Data.msgTable.StrOutputTimeline2 ) $( $syncHash.DC.DatePickerStart[0].ToShortDateString() ) -> $( ( Get-Date ).ToShortDateString() )" }
else { $syncHash.Data.msgTable.StrOutputTimeline3 } )

***********************
$( $syncHash.Data.msgTable.StrOutput4 ) $( $syncHash.Data.FullFileList.Count )


***********************
$( $syncHash.Data.msgTable.StrOutputTitleFolders ):

$( [string]( $syncHash.Controls.Window.Resources['CvsFolderList'].View | ForEach-Object { "$( $_.Path ) ( $( $_.Name ) )" } ) )


***********************
$( $syncHash.Data.msgTable.StrOutputTitleFoldersOtherPerm ):

$( [string]( $syncHash.OtherFolderPermissions ) )


***********************
$( $syncHash.Data.msgTable.StrOutputTitleFilterMatch )
$( $syncHash.Data.msgTable.StrOutputTitleFilterMatch2 )
$( $ofs = ", "
$syncHash.FileFilter )

$( 	$ofs = "`n"
[string]( $syncHash.DC.LvFilterMatch[0].TT ) )


***********************
$( $syncHash.Data.msgTable.StrOutputTitleMultiDotH )

$( [string]( $syncHash.DC.LvMultiDotsH[0].TT ) )


***********************
$( $syncHash.Data.msgTable.StrOutputTitleMultiDotG )

$( [string]( $syncHash.DC.LvMultiDotsG[0].TT ) )


***********************
$( $syncHash.Data.msgTable.StrOutputTitleAllFiles )

$( [string]( $syncHash.Controls.LvAllFiles.ItemsSource.TT | Sort-Object ) )
"@
}

function GetFolders
{
	<#
	.Synopsis
		Start the job to get folderlist
	#>

	$syncHash.DC.TotalProgress[1] = [System.Windows.Visibility]::Visible
	$syncHash.Jobs.FolderJob.Handle = $syncHash.Jobs.FolderJob.PS.BeginInvoke()
}

function GetFiles
{
	<#
	.Synopsis
		Start the job to get all files
	#>

	$syncHash.DC.TotalProgress[1] = [System.Windows.Visibility]::Visible
	$syncHash.Jobs.FilesJob.Handle = $syncHash.Jobs.FilesJob.PS.BeginInvoke()
}

function ListFiles
{
	<#
	.Synopsis
		List all the files
	#>

	$syncHash.End = Get-Date
	$syncHash.Controls.Window.Title = ""
	$syncHash.DC.GridWaitProgress[0] = [System.Windows.Visibility]::Hidden

	if ( $syncHash.Controls.Window.Resources['CvsFolderList'].Source.Count -gt 0 )
	{
		$syncHash.DC.GridActionButtons[0] = $true
	}
	else
	{
		$syncHash.Controls.Window.Resources['CvsAllFiles'].Source.Add( ( [pscustomobject]@{ Name = $syncHash.Data.msgTable.StrNoFilesFound; CreationTime = $syncHash.Start; LastWriteTime = $syncHash.End } ) )
	}

	GenerateOutput
	GenerateLog
}

function PrepGetFolders
{
	<#
	.Synopsis
		Get the folders and list files
	#>

	$syncHash.DC.GridInfo[0] = [System.Windows.Visibility]::Visible
	$syncHash.Jobs.FolderJob = [pscustomobject]@{ PS = [powershell]::Create() ; Handle = $null }
	$syncHash.Jobs.FolderJob.PS.AddScript( {
		param ( $syncHash )

		$syncHash.Data.Groups = [System.Collections.ArrayList]::new()
		$syncHash.Data.Other = [System.Collections.ArrayList]::new()

		$syncHash.Controls.Window.Title = $syncHash.Data.msgTable.StrOPGettingFolders

		[void] $syncHash.Controls.Windows.Resources['CvsFolderList'].Source.Add( ( [pscustomobject]@{ Path = $syncHash.User.HomeDirectory; Name = "H:" ; Description = $syncHash.Data.msgTable.StrHomeFolder } ) )
		Get-ADPrincipalGroupMembership $syncHash.User.SamAccountName | Get-ADGroup -Properties Description | ForEach-Object { [void] $syncHash.Data.Groups.Add( $_ ) }

		foreach ( $g in ( $syncHash.Data.Groups | Where-Object { $_.Name -match "_(G1)|(Gp2)_" } ) )
		{
			Get-ADPrincipalGroupMembership $g | Where-Object { $_.Name -match ".*_File_.*(C|F)$" } | Get-ADGroup -Properties Description | ForEach-Object { [void] $syncHash.Data.Groups.Add( $_ ) }
		}

		$syncHash.DC.TotalProgress[0] = [double] 0
		$syncHash.DC.TotalProgress[1] = [System.Windows.Visibility]::Visible
		$syncHash.DC.TotalProgress[2] = [double] ( $syncHash.Data.Groups | Select-Object -Unique | Where-Object { $_.Name -notmatch "_R$" } ).Count
		foreach ( $g in ( $syncHash.Data.Groups | Select-Object -Unique | Where-Object { $_.Name -notmatch "_R$" } ) )
		{
			$p = $null
			if ( $g.Description -match $syncHash.Data.msgTable.CodeGrpDescriptionMatch )
			{
				$p = ( ( $g.Description -split "$( $syncHash.Data.msgTable.StrGrpDescriptionSplit ) " )[1] -split "\." )[0] -replace " $( $syncHash.Data.msgTable.StrGrpDescriptionReplace )"
			}
			elseif ( $g.Description -match $syncHash.Data.msgTable.StrSepServer )
			{
				if ( $g.Name -match "ClientSoftware" )
				{
					$p = "\\$( $syncHash.Data.msgTable.StrSepServer )\ClientSoftware$\"
				}
				elseif ( $g.Description -match "O2\\" )
				{
					$p = "\\$( $syncHash.Data.msgTable.StrSepServer )\$( $syncHash.Data.msgTable.StrSepServerFolder1 )\$( ( $g.Name -replace "_C" -split "$( $syncHash.Data.msgTable.StrSepServer )_" )[1] )"
				}
				elseif ( $g.Name -match "^Or3" )
				{
					$p = "\\$( $syncHash.Data.msgTable.StrSepServer )\$( $syncHash.Data.msgTable.StrSepServerFolder2 )\$( ( $g.Name -replace "_C" -split "$( $syncHash.Data.msgTable.StrSepServer )_" )[1] )"
				}
				elseif ( $g.Name -match "^Op3" )
				{
					$p = "\\$( $syncHash.Data.msgTable.StrSepServer )\$( $syncHash.Data.msgTable.StrSepServerFolder3 )\$( ( $g.Name -replace "_C" -split "$( $syncHash.Data.msgTable.StrSepServer )_" )[1] )"
				}
			}
			else
			{
				$p = "Other"
			}

			if ( $p -eq "Other" )
			{
				[void] $syncHash.Data.Other.Add( ( [pscustomobject]@{ Path = $g.Name ; Name = $g.Name } ) )
			}
			else
			{
				if ( Test-Path $p )
				{
					if ( -not ( $syncHash.Controls.Window.Resources['CvsFolderList'].Source | Where-Object { $_.Path -eq $p } ) )
					{
						$syncHash.Controls.Window.Dispatcher.Invoke( [action] {
							[void] $syncHash.Controls.Window.Resources['CvsFolderList'].Source.Add( ( [pscustomobject]@{ Path = $p ; Name = $g.Name ; Description = $g.Description ; Searched = $false } ) )
							$syncHash.Controls.TblFolderCount.GetBindingExpression( [System.Windows.Controls.TextBlock]::TextProperty ).UpdateTarget()
						} )
					}
				}
				else
				{
					[void] $syncHash.OtherFolderPermissions.Add( $g.Name )
				}
			}
			$syncHash.DC.TotalProgress[0] += 1
		}

		$syncHash.Controls.Window.Dispatcher.Invoke( [action] {
			$syncHash.DC.TotalProgress[0] = [double] 0
			$syncHash.DC.TotalProgress[1] = [System.Windows.Visibility]::Hidden
			$syncHash.DC.BtnStartSearch[1] = $syncHash.Controls.Window.Resources['CvsFolderList'].Source.Count -gt 0
			$syncHash.Controls.Window.Title = ""
			$syncHash.Controls.Window.Resources['CvsFolderList'].View.Refresh()
		} )
	} )
	$syncHash.Jobs.FolderJob.PS.AddArgument( $syncHash )
}

function PrepGetFiles
{
	<#
	.Description
		Create the job (runspace) that will retrieve a list of all files the user have permission for
	#>

	$syncHash.Jobs.FilesJob = [pscustomobject]@{ PS = [powershell]::Create() ; Handle = $null }
	$syncHash.Jobs.FilesJob.PS.AddScript( {
		param ( $syncHash, $FolderList, $Modules, $LastWriteTime )
		Import-Module $Modules

		$syncHash.Controls.Window.Dispatcher.Invoke( [action] {
			$syncHash.Controls.Window.Title = $syncHash.Data.msgTable.StrOPGettingFiles
		}, [System.Windows.Threading.DispatcherPriority]::DataBind )
		$syncHash.DC.TotalProgress[2] = [double] $FolderList.Count
		$syncHash.DC.GridWaitProgress[0] = [System.Windows.Visibility]::Visible

		[runspacefactory]::CreateRunspacePool()
		$SessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
		$RunspacePool = [runspacefactory]::CreateRunspacePool(
			1, #Min Runspaces
			5 #Max Runspaces
		)
		$RunspacePool.Open()

		foreach ( $Folder in $FolderList )
		{
			$P = [powershell]::Create()
			$P.RunspacePool = $RunspacePool
			$P.AddScript( {
				param ( $syncHash, $Folder, $Modules, $LastWriteTime )
				Import-Module $Modules

				Get-ChildItem $Folder.Path -File -Recurse -ErrorAction SilentlyContinue | `
					Where-Object { $_.LastWriteTime -ge $LastWriteTime } | `
					Select-Object -Property "Name", `
						"CreationTime", `
						"LastWriteTime", `
						@{ Name = "FileType"; Expression = {
							if ( [string]::IsNullOrEmpty( $_.Extension ) ) { $syncHash.Data.msgTable.StrNoExtension }
							else
							{
								try
								{
									$e = $_.Extension.ToLower()
									$Desc = ( Get-ItemProperty "Registry::HKEY_Classes_root\$( ( Get-ItemProperty "Registry::HKEY_Classes_root\$e" -ErrorAction Stop )."(default)" )" )."(default)"
									if ( $Desc )
									{ "$e :: $Desc" }
									else
									{ throw }
								}
								catch
								{ "$e :: ?" }
							}
						} }, `
						@{ Name = "FilterMatch"; Expression = {
							$n = $_.Name
							if ( $syncHash.FileFilter.ForEach( { $n -match $_ } ) ) { $true }
							else { $false }
						} }, `
						@{ Name = "TT"; Expression = {
							if ( $_.FullName.StartsWith( $syncHash.User.HomeDirectory ) ) { $_.FullName.Replace( $syncHash.User.HomeDirectory , "H:" ) }
							else { $_.FullName }
						} }, `
						@{ Name = "Size" ; Expression = {
							if ( $_.Length -lt 1kB ) { "$( $_.Length ) B" }
							elseif ( $_.Length -gt 1kB -and $_.Length -lt 1MB ) { "$( [math]::Round( ( $_.Length / 1kB ), 2 ) ) kB" }
							elseif ( $_.Length -gt 1MB -and $_.Length -lt 1GB ) { "$( [math]::Round( ( $_.Length / 1MB ), 2 ) ) MB" }
							elseif ( $_.Length -gt 1GB -and $_.Length -lt 1TB ) { "$( [math]::Round( ( $_.Length / 1GB ), 2 ) ) GB" }
						} } , `
						@{ Name = "Owner" ; Expression = {
							$o = Get-ADUser ( ( ( Get-Acl $_.FullName ).Owner ) -split "\\" )[1]
							if ( $o.SamAccountName -eq $syncHash.User.SamAccountName ) { $syncHash.Data.msgTable.StrFileOwner }
							else { $o.Name }
						} } | `
					ForEach-Object {
						$f = $_
						Add-Member -InputObject $f -MemberType NoteProperty -Name Streams -Value ( [System.Collections.ArrayList]::new() )
						Get-Item $f.TT -Stream * | ForEach-Object {
							$ds = if ( $_.Length -lt 1kB ) { "$( $_.Length ) B" }
							elseif ( $_.Length -gt 1kB -and $_.Length -lt 1MB ) { "$( [math]::Round( ( $_.Length / 1kB ), 2 ) ) kB" }
							elseif ( $_.Length -gt 1MB -and $_.Length -lt 1GB ) { "$( [math]::Round( ( $_.Length / 1MB ), 2 ) ) MB" }
							elseif ( $_.Length -gt 1GB -and $_.Length -lt 1TB ) { "$( [math]::Round( ( $_.Length / 1GB ), 2 ) ) GB" }
							[void]$f.Streams.Add( ( [pscustomobject]@{ Stream = $_.Stream ; DataSize = $ds } ) )
						}

						$syncHash.Controls.Window.Dispatcher.Invoke( [action] {
							$syncHash.Controls.Window.Resources['CvsAllFiles'].Source.Add( $f ) | Out-Null
							$syncHash.Controls.TblFileCount.GetBindingExpression( [System.Windows.Controls.TextBlock]::TextProperty ).UpdateTarget()
						}, [System.Windows.Threading.DispatcherPriority]::DataBind )
					}

				$Error | ForEach-Object {
					if ( $_.CategoryInfo.Activity -eq "Get-ChildItem" )
					{ $syncHash.OtherFolderPermissions.Add( ( $_.Exception.Message -replace "\]" -split "\[" )[1] ) }
				}

				$syncHash.Controls.Window.Dispatcher.Invoke( [action] {
					$syncHash.Controls.Window.Resources['CvsFolderList'].Source.Where( { $_.Path -eq $Folder.Path } )[0].Searched = $true
					$syncHash.Controls.Window.Resources['CvsFolderList'].View.Refresh()
					$syncHash.Controls.Window.Resources['CvsAllFiles'].View.Refresh()
				}, [System.Windows.Threading.DispatcherPriority]::DataBind )
				$syncHash.DC.TotalProgress[0] += [double] 1
			} ) | Out-Null
			$P.AddArgument( $syncHash ) | Out-Null
			$P.AddArgument( $Folder ) | Out-Null
			$P.AddArgument( ( Get-Module ) ) | Out-Null
			$P.AddArgument( $LastWriteTime ) | Out-Null
			$syncHash.Jobs.FileFetchingJobs.Add( ( [pscustomobject]@{ PS = $P ; Handle = $null } ) ) | Out-Null
		}

		$syncHash.Jobs.FileFetchingJobs | ForEach-Object { $_.Handle = $_.PS.BeginInvoke() }
		$syncHash.Controls.Window.Dispatcher.Invoke( [action] {
			$syncHash.Controls.Window.Title = $syncHash.Data.msgTable.StrOPWaitGettingFiles
		}, [System.Windows.Threading.DispatcherPriority]::DataBind )
	} )
	$syncHash.Jobs.FilesJob.PS.AddArgument( $syncHash )
	$syncHash.Jobs.FilesJob.PS.AddArgument( $syncHash.Controls.Window.Resources['CvsFolderList'].Source )
	$syncHash.Jobs.FilesJob.PS.AddArgument( ( Get-Module ) )
	$syncHash.Jobs.FilesJob.PS.AddArgument( $syncHash.DC.DatePickerStart[0] )
}

function Reset
{
	<#
	.Synopsis
		Reset all controls
	#>

	$syncHash.Controls.Window.Dispatcher.Invoke( [action] {
		$syncHash.DC.CbSetAccountDisabled[0] = $false
		$syncHash.Controls.Window.Resources['CvsFolderList'].Source.Clear()
		$syncHash.Controls.Window.Resources['CvsFolderList'].View.Refresh()
		$syncHash.DC.GridInfo[0] = [System.Windows.Visibility]::Hidden
		$syncHash.DC.GridInput[0] = $true
		$syncHash.DC.LvFilterMatch[0] = [System.Windows.Data.ListCollectionView]@()
		$syncHash.DC.LvMultiDotsG[0] = [System.Windows.Data.ListCollectionView]@()
		$syncHash.DC.LvMultiDotsH[0] = [System.Windows.Data.ListCollectionView]@()
		$syncHash.DC.RbLatest[0] = $true
		$syncHash.DC.TblSummary[0] = ""
		$syncHash.DC.TbQuestion[0] = $syncHash.Controls.TbCaseNr.Text = $syncHash.Controls.TbId.Text = $syncHash.DC.TblFolderCount[0] = ""
		$syncHash.DC.TiO[0] = [System.Windows.Visibility]::Collapsed
		$syncHash.DC.TiFilterMatch[0] = [System.Windows.Visibility]::Collapsed
		$syncHash.DC.TiMDG[0] = [System.Windows.Visibility]::Collapsed
		$syncHash.DC.TiMDH[0] = [System.Windows.Visibility]::Collapsed
		$syncHash.DC.TotalProgress[0] = [double] 0.0
		$syncHash.OutputContent.Item( 0 ) = ""
	} )
	$syncHash.User = $null
	$syncHash.Controls.Window.Resources['CvsFolderList'].Source.Clear()
	$syncHash.Controls.CbSetAccountDisabled.Content = $syncHash.Data.msgTable.ContentCbSetAccountDisabled
	$syncHash.Data.FullFileList.Clear()
	$syncHash.Data.ErrorHashes.Clear()
	$syncHash.Data.ScannedForVirus.Clear()
	$syncHash.OtherFolderPermissions.Clear()
	$syncHash.Jobs.FilesJob.PS.EndInvoke( $syncHash.Jobs.FilesJob.Handle ) | Out-Null
	$syncHash.Jobs.FolderJob.PS.EndInvoke( $syncHash.Jobs.FolderJob.Handle ) | Out-Null
	$syncHash.Jobs.FileFetchingJobs | `
		ForEach-Object {
			$_.PS.EndInvoke( $_.Handle ) | Out-Null
		}
	$syncHash.Jobs.FileFetchingJobs.Clear()
}

####################### Script start
$controls = New-Object Collections.ArrayList
[void]$controls.Add( @{ CName = "BrdCaseNr"; Props = @( @{ PropName = "BorderBrush"; PropVal = "#0000" } ) } )
[void]$controls.Add( @{ CName = "BrdId"; Props = @( @{ PropName = "BorderBrush"; PropVal = "#0000" } ) } )
[void]$controls.Add( @{ CName = "BtnPrep"; Props = @( @{ PropName = "Visibility" ; PropVal = [System.Windows.Visibility]::Visible } ; @{ PropName = "IsEnabled" ; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "BtnStartSearch"; Props = @( @{ PropName = "Visibility"; PropVal = [System.Windows.Visibility]::Collapsed } ; @{ PropName = "IsEnabled"; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "CbExpandGroups"; Props = @( @{ PropName = "IsChecked"; PropVal = $true } ) } )
[void]$controls.Add( @{ CName = "CbGroupExtensions"; Props = @( @{ PropName = "IsChecked"; PropVal = $true } ) } )
[void]$controls.Add( @{ CName = "CbSetAccountDisabled"; Props = @( @{ PropName = "IsChecked" ; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "DatePickerStart"; Props = @( @{ PropName = "SelectedDate"; PropVal = ( Get-Date ).AddDays( -14 ) } ) } )
[void]$controls.Add( @{ CName = "DgStreamsList"; Props = @( @{ PropName = "ItemsSource"; PropVal = [System.Collections.ObjectModel.ObservableCollection[Object]]::new() } ) } )
[void]$controls.Add( @{ CName = "GridActionButtons"; Props = @( @{ PropName = "IsEnabled"; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "GridInfo"; Props = @( @{ PropName = "Visibility"; PropVal = [System.Windows.Visibility]::Hidden } ) } )
[void]$controls.Add( @{ CName = "GridInput"; Props = @( @{ PropName = "IsEnabled"; PropVal = $true } ; @{ PropName = "Tag"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "GridWaitProgress"; Props = @( @{ PropName = "Visibility"; PropVal = [System.Windows.Visibility]::Hidden } ) } )
[void]$controls.Add( @{ CName = "LvAllFiles"; Props = @( @{ PropName = "SelectedItem" ; PropVal = $null } ) } )
[void]$controls.Add( @{ CName = "LvFilterMatch"; Props = @( @{ PropName = "ItemsSource"; PropVal = [System.Collections.ObjectModel.ObservableCollection[Object]]::new() } ) } )
[void]$controls.Add( @{ CName = "LvMultiDotsG"; Props = @( @{ PropName = "ItemsSource"; PropVal = [System.Collections.ObjectModel.ObservableCollection[Object]]::new() } ) } )
[void]$controls.Add( @{ CName = "LvMultiDotsH"; Props = @( @{ PropName = "ItemsSource"; PropVal = [System.Collections.ObjectModel.ObservableCollection[Object]]::new() } ) } )
[void]$controls.Add( @{ CName = "RbAll"; Props = @( @{ PropName = "IsChecked"; PropVal = $false } ; @{ PropName = "Visibility"; PropVal = [System.Windows.Visibility]::Collapsed } ) } )
[void]$controls.Add( @{ CName = "RbLatest"; Props = @( @{ PropName = "IsChecked" ; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "RbPrevDate"; Props = @( @{ PropName = "IsChecked"; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "StreamsList"; Props = @( @{ PropName = "Visibility"; PropVal = [System.Windows.Visibility]::Hidden } ) } )
[void]$controls.Add( @{ CName = "TblFiles"; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "TblSummary"; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "TblUser"; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "TbQuestion"; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "TiO"; Props = @( @{ PropName = "Visibility" ; PropVal = [System.Windows.Visibility]::Collapsed } ) } )
[void]$controls.Add( @{ CName = "TiFilterMatch"; Props = @( @{ PropName = "Visibility" ; PropVal = [System.Windows.Visibility]::Collapsed } ) } )
[void]$controls.Add( @{ CName = "TiMDG"; Props = @( @{ PropName = "Visibility" ; PropVal = [System.Windows.Visibility]::Collapsed } ) } )
[void]$controls.Add( @{ CName = "TiMDH"; Props = @( @{ PropName = "Visibility" ; PropVal = [System.Windows.Visibility]::Collapsed } ) } )
[void]$controls.Add( @{ CName = "TotalProgress"; Props = @( @{ PropName = "Value"; PropVal = [double] 0 } ; @{ PropName = "Visibility" ; PropVal = [System.Windows.Visibility]::Hidden } ; @{ PropName = "Maximum" ; PropVal = [double] 0 } ) } )

BindControls $syncHash $controls

$syncHash.Controls.Window.Resources['CvsFolderList'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
$syncHash.Controls.Window.Resources['CvsAllFiles'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
$syncHash.Data.AllFilesGroupingDescription = $syncHash.Controls.Window.Resources['CvsAllFiles'].GroupDescriptions[0]

$syncHash.Data.BaseDir = ( Get-Item $MyInvocation.PsScriptRoot ).Parent.FullName

$syncHash.Jobs.FileFetchingJobs = [System.Collections.ArrayList]::new()
$syncHash.Data.ErrorHashes = @()
$syncHash.Data.FullFileList = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
$syncHash.Data.ScannedForVirus = [System.Collections.ArrayList]::new()
$syncHash.FileFilter = @( ".MYD", ".MYI", "encrypted", "vvv", ".mp3", ".exe", "Anydesk", "FileSendsuite", "Recipesearch", "FromDocToPDF", ".dll", "easy2lock" )
$syncHash.ScriptVar = New-Object -ComObject WScript.Shell
WriteLog -Text $syncHash.Data.msgTable.StrLogScriptStart -UserInput "-" -Success $true | Out-Null

# Create an observable collection for a list of folders the scriptuser does not have permission to, that will respond to being updated
# Once updated, make the tabitem visible and fill textbox with folderlist and question
$syncHash.OtherFolderPermissions = ( New-Object System.Collections.ObjectModel.ObservableCollection[object] )
$syncHash.OtherFolderPermissions.Add_CollectionChanged( {
	if ( $syncHash.OtherFolderPermissions.Count -gt 0 )
	{
		$ofs = "`n"
		$syncHash.DC.TbQuestion[0] = "$( $syncHash.User.Name ) $( $syncHash.Data.msgTable.StrQuestion1 ) $( $syncHash.Controls.TbCaseNr.Text ).`r`n$( $syncHash.Data.msgTable.StrQuestion2 )`r`n$( $syncHash.Data.msgTable.StrQuestion3 )`r`n`r`n$( [string]( $syncHash.OtherFolderPermissions | Select-Object -Unique | Sort-Object ) )"
		$syncHash.Controls.Window.Dispatcher.Invoke( [action] { $syncHash.DC.TiO[0] = [System.Windows.Visibility]::Visible } )
	}
} )

# Create an observable collection for text as output that will respond to being updated
# Once updated, write to output-fil
$syncHash.OutputContent = New-Object System.Collections.ObjectModel.ObservableCollection[Object]
$syncHash.OutputContent.Add( "" )
$syncHash.OutputContent.Add_CollectionChanged( {
	if ( $syncHash.OutputContent.Item( 0 ) -ne "" )
	{
		$syncHash.DC.TblSummary[0] = WriteOutput -Output "$( $syncHash.OutputContent.Item( 0 ) )" -FileName "Search-PotentialVirus"
		WriteLog -Text $syncHash.logText -UserInput $syncHash.DC.GridInput[1] -Success $true -OutputPath $syncHash.DC.TblSummary[0] | Out-Null

		TextToSpeech -Text $syncHash.Data.msgTable.StrFileSearchFinished
		$syncHash.DC.TotalProgress[0] = [double] 0.0
	}
} )

# Abort current filesearch
$syncHash.Controls.BtnAbort.Add_Click( {
	$syncHash.Jobs | ForEach-Object { $_.PS.Stop(); $_.PS.Dispose() }
	$syncHash.Jobs.FileFetchingJobs | ForEach-Object { $_.PS.Stop() ; $_.PS.Dispose() }
	$syncHash.Jobs.Clear()

	$syncHash.Controls.Window.Resources['CvsFolderList'].Source.Clear()
	$syncHash.Controls.Window.Resources['CvsFolderList'].View.Refresh()
	$syncHash.DC.GridWaitProgress[0] = [System.Windows.Visibility]::Hidden
	$syncHash.DC.TotalProgress[1] = [System.Windows.Visibility]::Hidden
	$syncHash.DC.BtnStartSearch[1] = $true
	$syncHash.DC.GridInput[0] = $true
	$syncHash.Controls.Window.Title = ""
	$syncHash.DC.TotalProgress[0] = [double] 0.0
	WriteLogTest -Text $syncHash.Data.msgTable.StrLogMsgFileSearchAborted -UserInput $syncHash.DC.GridInput[1] -Success $true | Out-Null
} )

#
$syncHash.Controls.BtnCloseStreamsList.Add_Click( {
	#$syncHash.StreamsList.DataContext = $null
	$syncHash.DC.StreamsList[0] = [System.Windows.Visibility]::Hidden
} )

# Copy text for question to clipboard
$syncHash.Controls.BtnCreateQuestion.Add_Click( {
	$OutputEncoding = ( New-Object System.Text.UnicodeEncoding $false, $false ).psobject.BaseObject
	$syncHash.DC.TbQuestion[0] | clip
	Show-MessageBox $syncHash.Data.msgTable.StrQuestionCopied
	WriteLogTest -Text "$( $syncHash.Data.msgTable.StrLogQuestionCopied )`n**************`n$( $syncHash.DC.TbQuestion[0] )`n**************" -UserInput $syncHash.DC.GridInput[1] | Out-Null
} )

# Opens the folder selected file is located in
$syncHash.Controls.BtnOpenFolder.Add_Click( {
	$syncHash.ActiveListView.SelectedItems.TT | ForEach-Object {
		if ( $_ -match "^H:\\" ) { $Path = $_ -replace "^H:", $syncHash.User.HomeDirectory }
		else { $Path = $_ }
		Start-Process explorer -ArgumentList "/select, $Path"
	}
	WriteLogTest -Text $syncHash.Data.msgTable.StrLogMsgOpenFolder -UserInput "$( $syncHash.DC.GridInput[1] )`n$( $syncHash.ActiveListView.SelectedItems.TT )" -Success $true
} )

# Opens the summaryfile
$syncHash.Controls.BtnOpenSummary.Add_Click( { & 'C:\Program Files (x86)\Notepad++\notepad++.exe' $syncHash.DC.TblSummary[0] } )

# Prepare for filesearch by creating jobs and retrieving folderlist
$syncHash.Controls.BtnPrep.Add_Click( {
	$syncHash.Controls.Window.Resources['CvsFolderList'].Source.Clear()
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
	$syncHash.DC.GridActionButtons[0] = $false
	$syncHash.Controls.TbCaseNr.Focus()
} )

# Start a virus scan of selected file
$syncHash.Controls.BtnRunVirusScan.Add_Click( {
	if ( $syncHash.ActiveListView.SelectedItems.Count -gt 0 )
	{
		if ( $syncHash.ActiveListView.SelectedItems.Count -gt 2 )
		{ Show-MessageBox -Text $syncHash.Data.msgTable.StrMultiFileVirusSearch }

		foreach ( $File in $syncHash.ActiveListView.SelectedItems )
		{
			if ( $File.TT -match "^H:\\" )
			{ $path = $File.TT -replace "^H:", $syncHash.User.HomeDirectory }
			else
			{ $path = $File.TT }
			$PathToScan = Get-Item $path

			if ( $PathToScan.FullName -match "\`$Recycle Bin" )
			{ Show-MessageBox -Text "$( $PathToScan.FullName )`n$( $syncHash.Data.msgTable.MsgRecycleBin )" }
			else
			{
				$Shell = New-Object -Com Shell.Application
				$ShellFolder = $Shell.NameSpace( $PathToScan.Directory.FullName )
				$ShellFile = $ShellFolder.ParseName( $PathToScan.Name )
				$ShellFile.InvokeVerb( $syncHash.Data.msgTable.StrVerbVirusScan )
				[void] $syncHash.Data.ScannedForVirus.Add( [pscustomobject]@{ Path = $PathToScan.FullName ; Time = ( Get-Date ) } )
			}
		}
		WriteLogTest -Text $syncHash.Data.msgTable.LogScannedFile -UserInput "$( $syncHash.DC.GridInput[1] )`n$( $syncHash.Data.msgTable.LogScannedFileTitle ) $( $syncHash.ActiveListView.SelectedItems.TT )" -Success $true | Out-Null
		$OFS = "`n"
		Set-Content -Value @"
$( $syncHash.OutputContent.Item( 0 ) )

***********************
$( $syncHash.Data.msgTable.StrLogMsgFilesScannedForVirus )

$( [string]( $syncHash.Data.ScannedForVirus | ForEach-Object { "$( $_.Path ) ($( Get-Date $_.Time -f "yyyy-MM-dd HH:mm:ss" ))" } ) )
"@ -Path $syncHash.DC.TblSummary[0]
	}
} )

# Search on Google for the fileextension
$syncHash.Controls.BtnSearchExt.Add_Click( {
	$SelectedExtensions = $syncHash.ActiveListView.SelectedItems.FileType | Select-Object -Unique
	foreach ( $Ext in $SelectedExtensions )
	{
		Start-Process chrome "https://www.google.com/search?q=fileextension+$( $Ext )"
	}
	WriteLogTest -Text $syncHash.Data.msgTable.StrLogMsgSearchExt -UserInput "$( $syncHash.DC.GridInput[1] )`n$SelectedExtensions" -Success $true
} )

# Search on Google for the filename
$syncHash.Controls.BtnSearchFileName.Add_Click( {
	$SelectedNames = $syncHash.ActiveListView.SelectedItems.Name | Select-Object -Unique
	foreach ( $Name in $SelectedNames )
	{
		Start-Process chrome "https://www.google.com/search?q=`"$( $Name )`""
	}
	WriteLogTest -Text $syncHash.Data.msgTable.StrLogMsgSearchFileName -UserInput "$( $syncHash.DC.GridInput[1] )`n$SelectedNames" -Success $true
} )

# List filestreams
$syncHash.Controls.BtnShowFileStreams.Add_Click( {
	$syncHash.Controls.TblStreamsListFileName.Text = $syncHash.DC.LvAllFiles[0].TT -replace "H:", $syncHash.User.HomeDirectory
	$syncHash.DC.LvAllFiles[0].Streams | ForEach-Object { $syncHash.DC.DgStreamsList[0].Add( $_ ) }
	$syncHash.DC.StreamsList[0] = [System.Windows.Visibility]::Visible
} )

# Starts the search
$syncHash.Controls.BtnStartSearch.Add_Click( {
	$this.IsEnabled = $false
	$syncHash.DC.GridInput[1] = "{0}: {1}`n{2}: {3}" -f $syncHash.Data.msgTable.StrLogMsgId, $this.Text, $syncHash.Data.msgTable.StrLogMsgCaseNr, $syncHash.Controls.TbCaseNr.Text
	$syncHash.Start = Get-Date
	if ( $syncHash.DC.CbSetAccountDisabled[0] )
	{
		Set-ADUser -Identity $syncHash.User.SamAccountName -Enabled $false
		$syncHash.User.Enabled = $false
	}

	GetFiles
} )

# Expand/collaps groups in datagrid
$syncHash.Controls.CbExpandGroups.Add_Checked( { $syncHash.Controls.Window.Resources.ExpandGroups = $true } )
$syncHash.Controls.CbExpandGroups.Add_Unchecked( { $syncHash.Controls.Window.Resources.ExpandGroups = $false } )

$syncHash.Controls.CbGroupExtensions.Add_Checked( {
	if ( $syncHash.Window.Resources['CvsAllFiles'].GroupDescriptions.Count -eq 0 )
	{
		$syncHash.Window.Resources['CvsAllFiles'].GroupDescriptions.Add( $syncHash.Data.AllFilesGroupingDescription )
		$syncHash.Window.Resources['CvsAllFiles'].View.Refresh()
	}
} )

$syncHash.Controls.CbGroupExtensions.Add_Unchecked( {
	$syncHash.Window.Resources['CvsAllFiles'].GroupDescriptions.Clear()
	$syncHash.Window.Resources['CvsAllFiles'].View.Refresh()
} )

$syncHash.Controls.LvAllFiles.Add_SelectionChanged( { $syncHash.DC.GridActionButtons[0] = $this.SelectedItems.Count -gt 0 } )
$syncHash.Controls.LvMultiDotsH.Add_SelectionChanged( { $syncHash.DC.GridActionButtons[0] = $this.SelectedItems.Count -gt 0 } )
$syncHash.Controls.LvMultiDotsG.Add_SelectionChanged( { $syncHash.DC.GridActionButtons[0] = $this.SelectedItems.Count -gt 0 } )

# Radiobutton for all files is selected, set startdate to two months ago
$syncHash.Controls.RbAll.Add_Checked( { $syncHash.DC.DatePickerStart[0] = ( Get-Date ).AddDays( -60 ) } )

# Radiobutton for files updated in the last two weeks, is selected
$syncHash.Controls.RbLatest.Add_Checked( { $syncHash.DC.DatePickerStart[0] = ( Get-Date ).AddDays( -14 ) } )

# Set selected listview
$syncHash.Controls.LvAllFiles.Add_IsVisibleChanged( { if ( $this.IsVisible ) { $syncHash.ActiveListView = $this } } )
$syncHash.Controls.LvMultiDotsH.Add_IsVisibleChanged( { if ( $this.IsVisible ) { $syncHash.ActiveListView = $this } } )
$syncHash.Controls.LvMultiDotsG.Add_IsVisibleChanged( { if ( $this.IsVisible ) { $syncHash.ActiveListView = $this } } )
$syncHash.Controls.LvFilterMatch.Add_IsVisibleChanged( { if ( $this.IsVisible ) { $syncHash.ActiveListView = $this } } )

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
	$syncHash.DC.DgStreamsList[0].Clear()
} )

# Casenumber was entered, set user input text
$syncHash.Controls.TbCaseNr.Add_TextChanged( {
	if ( $this.Text -match "^(Cn|ICn)\d{7}$" )
	{
		$syncHash.DC.BrdCaseNr[0] = "#0000"
	}
	else
	{
		if ( $this.Text.Length -gt 0 ) { $syncHash.DC.BrdCaseNr[0] = "Red" }
		else { $syncHash.DC.BrdCaseNr[0] = "#0000" }
	}
	$syncHash.DC.BtnPrep[1] = ( $syncHash.DC.BrdId[0] -eq "#0000" ) -and ( $syncHash.DC.BrdCaseNr[0] -eq "#0000" ) -and ( $this.Text.Length -gt 0 ) -and ( $syncHash.Controls.TbId.Text.Length -gt 0 )
} )

# Id was entered, verify if user exists
$syncHash.Controls.TbId.Add_TextChanged( {
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
			}
			$syncHash.DC.TblUser[0] = $syncHash.User.Name

			$syncHash.DC.BrdId[0] = "#0000"
			$syncHash.DC.CbSetAccountDisabled[0] = -not $syncHash.User.Enabled
			if ( $syncHash.DC.CbSetAccountDisabled[0] )
			{ $syncHash.Controls.CbSetAccountDisabled.Content += " ($( $syncHash.Data.msgTable.StrUserAccountAlreadyLocked ))" }
		}
		catch
		{
			$syncHash.DC.BrdId[0] = "Red"
			$syncHash.Controls.CbSetAccountDisabled.Content += " ($( $syncHash.Data.msgTable.StrErrUserNotFound ))"
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
	$syncHash.DC.BtnPrep[1] = ( $syncHash.DC.BrdId[0] -eq "#0000" ) -and ( $syncHash.DC.BrdCaseNr[0] -eq "#0000" ) -and ( $this.Text.Length -gt 0 ) -and ( $syncHash.Controls.TbCaseNr.Text.Length -gt 0 )
} )

# Progress for gettings files have updated
$syncHash.Controls.TotalProgress.Add_ValueChanged( {
	if ( $this.Value -eq $this.Maximum -and ( $syncHash.Controls.Window.Resources['CvsFolderList'].Source.Searched -eq $false ).Count -eq 0 )
	{
		ListFiles
	}
	elseif ( $this.Value -eq 0 )
	{
		$this.Visibility = [System.Windows.Visibility]::Hidden
	}
} )

# Text for quest changed set tabitemheader to include number of folders not reachable
$syncHash.Controls.TbQuestion.Add_TextChanged( {
	$syncHash.Controls.Window.Dispatcher.Invoke( [action] {
		if ( $this.LineCount -gt 4 ) { $syncHash.Controls.TiO.Header = "$( $syncHash.Data.msgTable.ContenttiOHeader ) ($( $this.LineCount - 4 ))" }
		else { $syncHash.Controls.TiO.Header = $syncHash.Data.msgTable.ContentTiOHeader }
	} )
 } )

# UI is made visible, if a user is not loaded, enter SamAccountName in textbox for ID
$syncHash.Controls.Window.Add_IsVisibleChanged( {
	if ( $this.IsVisible -and ( $null -eq $syncHash.User ) )
	{
		$syncHash.Controls.TbId.Text = $syncHash.Controls.Window.Resources['SearchedItem'].SamAccountName
	}
} )

# Activate window and set focus when the window is loaded
$syncHash.Controls.Window.Add_Loaded( {
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
} )

Export-ModuleMember
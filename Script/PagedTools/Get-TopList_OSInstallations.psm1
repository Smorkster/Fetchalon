<#
.Synopsis List reinstallations
.Description Lists who performed the most reinstalls for specified dates. The information is taken from SysMan.
.MenuItem Shows the number of reinstalls per month per technician
.State Prod
.ObjectOperations None
.Author Smorkster
#>

Add-Type -AssemblyName PresentationFramework
$syncHash = $args[0]

function SortUserList
{
	<#
	.Synopsis
		Sort userlist depending on which columnheader was clicked
	#>

	param ( $Column )

	if ( $Column -eq "User" )
	{ $items = $syncHash.DC.LvDescriptionView[0] | Sort-Object User, Installations }
	else
	{ $items = $syncHash.DC.LvDescriptionView[0] | Sort-Object Installations, User -Descending }
	$syncHash.DC.LvDescriptionView[0].Clear()
	$items | ForEach-Object { $syncHash.DC.LvDescriptionView[0].Add( $_ ) }
}

###################### Script start
$controls = New-Object System.Collections.ArrayList
[void]$controls.Add( @{ CName = "BtnEndDate" ; Props = @( @{ PropName = "Visibility" ; PropVal = [System.Windows.Visibility]::Visible } ; @{ PropName = "IsEnabled" ; PropVal = $true } ; @{ PropName = "Content"; PropVal = $syncHash.Data.msgTable.ContentBtnEndDate } ) } )
[void]$controls.Add( @{ CName = "BtnExport" ; Props = @( @{ PropName = "IsEnabled" ; PropVal = $false } ; @{ PropName = "Content"; PropVal = $syncHash.Data.msgTable.ContentBtnExport } ) } )
[void]$controls.Add( @{ CName = "BtnStart" ; Props = @( @{ PropName = "IsEnabled" ; PropVal = $false } ; @{ PropName = "Content"; PropVal = $syncHash.Data.msgTable.ContentBtnStart } ) } )
[void]$controls.Add( @{ CName = "BtnStartDate" ; Props = @( @{ PropName = "Visibility" ; PropVal = [System.Windows.Visibility]::Visible } ; @{ PropName = "IsEnabled" ; PropVal = $true } ; @{ PropName = "Content"; PropVal = $syncHash.Data.msgTable.ContentBtnStartDate } ) } )
[void]$controls.Add( @{ CName = "DatePickerEnd" ; Props = @( @{ PropName = "Visibility"; PropVal = [System.Windows.Visibility]::Collapsed } ; @{ PropName = "IsEnabled" ; PropVal = $true } ; @{ PropName = "IsDropDownOpen" ; PropVal = $false } ; @{ PropName = "SelectedDate" ; PropVal = ( Get-Date ) } ; @{ PropName = "Text" ; PropVal = ( Get-Date ) } ) } )
[void]$controls.Add( @{ CName = "DatePickerStart" ; Props = @( @{ PropName = "Visibility"; PropVal = [System.Windows.Visibility]::Collapsed } ; @{ PropName = "IsEnabled" ; PropVal = $true } ; @{ PropName = "IsDropDownOpen" ; PropVal = $false } ; @{ PropName = "SelectedDate" ; PropVal = ( Get-Date ) } ; @{ PropName = "Text" ; PropVal = ( Get-Date ) } ) } )
[void]$controls.Add( @{ CName = "DescComputer" ; Props = @( @{ PropName = "Content"; PropVal = $syncHash.Data.msgTable.ContentDescCompCol } ) } )
[void]$controls.Add( @{ CName = "DescDate" ; Props = @( @{ PropName = "Content"; PropVal = $syncHash.Data.msgTable.ContentDescDateCol } ) } )
[void]$controls.Add( @{ CName = "DescDescription" ; Props = @( @{ PropName = "Content"; PropVal = $syncHash.Data.msgTable.ContentDescDescriptionCol } ) } )
[void]$controls.Add( @{ CName = "DescRole" ; Props = @( @{ PropName = "Content"; PropVal = $syncHash.Data.msgTable.ContentDescRoleCol } ) } )
[void]$controls.Add( @{ CName = "DescWT" ; Props = @( @{ PropName = "Content"; PropVal = $syncHash.Data.msgTable.ContentDescWTCol } ) } )
[void]$controls.Add( @{ CName = "InstallationsHeader" ; Props = @( @{ PropName = "Content"; PropVal = $syncHash.Data.msgTable.ContentInstCol } ) } )
[void]$controls.Add( @{ CName = "LvDescriptionView" ; Props = @( @{ PropName = "ItemsSource"; PropVal = [System.Collections.ObjectModel.ObservableCollection[Object]]::new( ) } ) } )
[void]$controls.Add( @{ CName = "LvUserView" ; Props = @( @{ PropName = "ItemsSource"; PropVal = [System.Collections.ObjectModel.ObservableCollection[Object]]::new( ) } ) } )
[void]$controls.Add( @{ CName = "PbProgress" ; Props = @( @{ PropName = "Value"; PropVal = [double] 0 } ) } )
[void]$controls.Add( @{ CName = "UserHeader" ; Props = @( @{ PropName = "Content"; PropVal = $syncHash.Data.msgTable.ContentUserCol } ) } )
[void]$controls.Add( @{ CName = "Window" ; Props = @( @{ PropName = "Title"; PropVal = $syncHash.Data.msgTable.StrWinTitle } ) } )

BindControls $syncHash $controls

$syncHash.Data.Installations = [System.Collections.ArrayList]::new()

# Set listviewitems style-triggers to localized strings
# Indexes (1 and 2-4) are indexes of style elements in XAML-file
$syncHash.Controls.Window.Resources[[System.Windows.Controls.ListViewItem]].Triggers[2].Value = $syncHash.Data.msgTable.StrComputerNotFound
$syncHash.Controls.Window.Resources[[System.Windows.Controls.ListViewItem]].Triggers[3].Value = $syncHash.Data.msgTable.StrOtherCompRole
$syncHash.Controls.Window.Resources[[System.Windows.Controls.ListViewItem]].Triggers[4].Value = $syncHash.Data.msgTable.StrErrorADLookup

$syncHash.Controls.BtnEndDate.Add_Click( {
	$this.Visibility = [System.Windows.Visibility]::Collapsed
	$syncHash.DC.DatePickerEnd[0] = [System.Windows.Visibility]::Visible
	$syncHash.DC.DatePickerEnd[2] = $true
} )

$syncHash.Controls.BtnStartDate.Add_Click( {
	$this.Visibility = [System.Windows.Visibility]::Collapsed
	$syncHash.DC.DatePickerStart[0] = [System.Windows.Visibility]::Visible
	$syncHash.DC.DatePickerStart[2] = $true
} )

$syncHash.Controls.BtnStart.Add_Click( {
	$syncHash.Data.Installations.Clear()
	$syncHash.DC.LvUserView[0].Clear()
	$syncHash.DC.LvDescriptionView[0].Clear()
	$syncHash.DC.BtnStartDate[1] = $syncHash.DC.BtnEndDate[1] = $this.IsEnabled = $syncHash.DC.BtnExport[0] = $syncHash.DC.DatePickerStart[1] = $syncHash.DC.DatePickerEnd[1] = $false
	$syncHash.SelectedStart = $syncHash.DC.DatePickerStart[3]
	$syncHash.SelectedEnd = $syncHash.DC.DatePickerEnd[3]
	if ( $syncHash.collect.Runspace.RunspaceStateInfo.State -eq "Opened" ) { $syncHash.collect.Runspace.Close() ; $syncHash.collect.Runspace.Dispose() }

	# Start collecting data from SysMan
	$p = [powershell]::Create().AddScript( { param ( $syncHash, $Modules )
		Import-Module $Modules
		# Get installation information from SysMan API
		$logs = [System.Collections.ArrayList]::new()
		$jobs = [System.Collections.ArrayList]::new()
		$processingStart = $syncHash.SelectedStart
		$processingEnd = $processingStart.AddHours( 4 )
		$processingMax = $syncHash.SelectedEnd.AddDays( 1 )

		$SessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
		$RunspacePool = [runspacefactory]::CreateRunspacePool(
			1, #Min Runspaces
			10 #Max Runspaces
		)
		$RunspacePool.Open()

		$syncHash.DC.Window[0] = $syncHash.Data.msgTable.StrOpSetup
		do
		{
			$Runspace = [powershell]::Create()
			$Runspace.RunspacePool = $RunspacePool
			[void]$Runspace.AddScript( {
				param ( $processingStart, $processingEnd, $syncHash )
				( Invoke-RestMethod -Uri ( Invoke-Expression $syncHash.Data.msgTable.CodeSysManUrl ) -Method Get -UseDefaultCredentials -ContentType "application/json" ).result | Where-Object { $_.LoggedBy -match $syncHash.Data.msgTable.StrAdmPrefix -and $_.eventCode -eq "OSINST" }
			} )
			[void]$Runspace.AddArgument( $processingStart )
			[void]$Runspace.AddArgument( $processingEnd )
			[void]$Runspace.AddArgument( $syncHash )

			[void]$jobs.Add( @{ RS = $Runspace; H = $Runspace.BeginInvoke() } )
			$processingStart = $processingEnd
			$processingEnd = $processingEnd.AddHours( 4 )
		}
		until ( $processingEnd -gt $processingMax )

		# Wait for SysMan-jobs to finish
		$syncHash.DC.Window[0] = $syncHash.Data.msgTable.StrOpWaitData
		do
		{
			Start-Sleep -Milliseconds 10
			$syncHash.DC.PbProgress[0] = [double]( ( ( ( $jobs | Where-Object { $_.H.IsCompleted } ).Count ) / ( $jobs.Count ) ) * 100 )
		} until ( ( $jobs.H.IsCompleted -eq $false ).Count -eq 0 )

		$ticker = 0
		$syncHash.DC.Window[0] = $syncHash.Data.msgTable.StrOpRead
		foreach ( $j in $jobs )
		{
			$j.RS.EndInvoke( $j.H ) | ForEach-Object { [void]$logs.Add( $_ ) }
			$ticker++
			$syncHash.DC.PbProgress[0] = [double]( ( $ticker / $jobs.Count ) * 100 )
		}

		$jobs | ForEach-Object { $_.RS.Close(); $_.RS.Dispose() }
		$RunspacePool.Close()
		$syncHash.DC.Window[0] = $syncHash.Data.msgTable.StrWinTitle

		############################################
		# Load list of users, with installationcount

		if ( $logs.Count -eq 0 )
		{
			ShowMessageBox $syncHash.Data.msgTable.StrNoInstallations
			$syncHash.DC.Window[0] = $syncHash.Data.msgTable.StrWinTitle
		}
		else
		{
			$loopCount = 0
			$syncHash.DC.Window[0] = $syncHash.Data.msgTable.StrOpCollect
			foreach ( $entry in $logs )
			{
				$entry.LoggedBy = ( Get-ADUser ( ( $entry.loggedBy -split $syncHash.Data.msgTable.StrAdmPrefix )[1] ) ).Name
				$isUserInData = $false
				if ( $syncHash.Data.Installations.Count -gt 0 )
				{
					$listIndex = 0
					for ( $i = 0; $i -le $syncHash.Data.Installations.Count - 1; $i++ )
					{
						if ( $syncHash.Data.Installations[$i].User -eq $entry.loggedBy )
						{
							$isUserInData = $true
							$listIndex = $i
							break
						}
					}
				}

				if ( $isUserInData )
				{
					$computerEntry = New-Object -TypeName PSObject
					$computerEntry | Add-Member -Name "Computer" -MemberType NoteProperty -Value $entry.targetName
					$computerEntry | Add-Member -Name "Date" -MemberType NoteProperty -Value $entry.date
					$computerEntry | Add-Member -Name "Description" -MemberType NoteProperty -Value $entry.text

					$syncHash.Data.Installations[$listIndex].log.Add( $computerEntry ) | Out-Null
					$syncHash.Data.Installations[$listIndex].installations = [int]( [int]( $syncHash.Data.Installations[$listIndex].installations ) + 1 )
				}
				else
				{
					$newUser = New-Object -TypeName PSObject
					$newUser | Add-Member -Name 'User' -MemberType NoteProperty -Value $entry.LoggedBy
					$newUser | Add-Member -Name 'Installations' -MemberType NoteProperty -Value 1
					$newUser | Add-Member -Name 'Log' -MemberType NoteProperty -Value ( [System.Collections.ArrayList]::new() )
					$syncHash.Data.Installations.Add( $newUser ) | Out-Null

					$computerEntry = New-Object -TypeName PSObject
					$computerEntry | Add-Member -Name "Computer" -MemberType NoteProperty -Value $entry.targetName
					$computerEntry | Add-Member -Name "Date" -MemberType NoteProperty -Value $entry.date
					$computerEntry | Add-Member -Name "Description" -MemberType NoteProperty -Value $entry.text
					$syncHash.Data.Installations[$syncHash.Data.Installations.Count-1].log.Add( $computerEntry ) | Out-Null
				}

				$loopCount++
				$syncHash.DC.PbProgress[0] = [double]( ( $loopCount / $logs.Count ) * 100 )
			}
		}

		$syncHash.Data.Installations | Sort-Object Installations -Descending | ForEach-Object {
			$syncHash.DC.LvUserView[0].Add( [pscustomobject]@{ User = $_.User; Installations = $_.Installations } )
		}

			$syncHash.DC.BtnStartDate[1] = $syncHash.DC.BtnEndDate[1] = $true
			$syncHash.DC.PbProgress[0] = [double] 0
			$syncHash.DC.Window[0] = $syncHash.Data.msgTable.StrWinTitle
			$syncHash.DC.BtnExport[0] = $syncHash.DC.LvUserView[0].Count -gt 0
			$syncHash.DC.BtnStartDate[0] = $syncHash.DC.BtnEndDate[0] = [System.Windows.Visibility]::Visible
			$syncHash.DC.DatePickerEnd[1] = $syncHash.DC.DatePickerStart[1] = $true
			$syncHash.Controls.DatePickerEnd.BlackoutDates.Clear()
			$syncHash.Controls.DatePickerStart.BlackoutDates.Clear()
			$syncHash.DC.DatePickerEnd[4] = ""
			$syncHash.DC.DatePickerStart[4] = ""
			$syncHash.DC.DatePickerEnd[0] = $syncHash.DC.DatePickerStart[0] = [System.Windows.Visibility]::Collapsed
		$logs.Clear()

	} )
	[void] $p.AddArgument( $syncHash )
	[void] $p.AddArgument( ( Get-Module ) )
	[void] $syncHash.Jobs.Add( ( [pscustomobject]@{ Name = "Collect" ; P = $p ; H = $p.BeginInvoke() } ) )
} )

$syncHash.Controls.BtnExport.Add_Click( {
	$output = $syncHash.Data.Installations | Sort-Object Installations -Descending | ForEach-Object { [pscustomobject]@{ User = $_.User; OS_Installations = $_.Installations } } | ConvertTo-Csv -NoTypeInformation -Delimiter ";"
	$outputFile = WriteOutput -Output $output -FileExtension "csv" -Scoreboard
	WriteLogTest -Text $syncHash.Data.msgTable.LogExport -OutputPath $outputFile -Success $true | Out-Null
	ShowMessageBox "$( $syncHash.Data.msgTable.StrExportPathMessage )`n$outputFile"
	$this.IsEnabled = $false
} )

$syncHash.Controls.UserHeader.Add_Click( { SortUserList "User" } )
$syncHash.Controls.InstallationsHeader.Add_Click( { SortUserList "Inst" } )

$syncHash.Controls.DatePickerStart.Add_CalendarClosed( {
	if ( $this.Text -eq "" )
	{
		$syncHash.DC.BtnStartDate[0] = [System.Windows.Visibility]::Visible
		$this.Visibility = [System.Windows.Visibility]::Collapsed
		$syncHash.DC.BtnStart[0] = $false
	}
	else
	{
		if ( $syncHash.DC.DatePickerEnd[0] -eq "Visible" )
		{
			$syncHash.DC.BtnStart[0] = $true
		}
		else
		{
			$syncHash.Controls.DatePickerEnd.BlackoutDates.Clear()
			$disabledDates = [System.Windows.Controls.CalendarDateRange]::new()
			$disabledDates.Start = $this.SelectedDate.AddDays( -31 )
			$disabledDates.End = $this.SelectedDate.AddDays( -1 )
			$syncHash.Controls.DatePickerEnd.BlackoutDates.Add( $disabledDates )
		}
	}
} )

$syncHash.Controls.DatePickerEnd.Add_CalendarClosed( {
	if ( $this.Text -eq "" )
	{
			$syncHash.DC.BtnEndDate[0] = [System.Windows.Visibility]::Visible
			$this.Visibility = [System.Windows.Visibility]::Collapsed
			$syncHash.DC.BtnStart[0] = $false
	}
	else
	{
		if ( $syncHash.DC.DatePickerStart[0] -eq "Visible" )
		{
			$syncHash.DC.BtnStart[0] = $true
		}
		else
		{
			$syncHash.Controls.DatePickerStart.BlackoutDates.Clear()
			$disabledDates = [System.Windows.Controls.CalendarDateRange]::new()
			$disabledDates.Start = $this.SelectedDate.AddDays( 1 )
			$disabledDates.End = $this.SelectedDate.AddDays( 31 )
			$syncHash.Controls.DatePickerStart.BlackoutDates.Add( $disabledDates )
		}
	}
} )

$syncHash.Controls.LvUserView.Add_SelectionChanged( {
	$syncHash.SelectedUser = $this.SelectedItems[0]
	( [powershell]::Create().AddScript( { param ( $syncHash )
		function GetUserInstallations
		{
			<#
			.Synopsis
				Collect data from info from SysMan
			#>

			param ( $User )

			$UserLog = @( ( $syncHash.Data.Installations.Where( { $_.User -eq $User.User } ) ).log )
			$jobs = New-Object System.Collections.ArrayList
			$i = 1
			$t = ""

			$SessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
			$RunspacePool = [runspacefactory]::CreateRunspacePool(
				1, #Min Runspaces
				10 #Max Runspaces
			)
			$RunspacePool.Open()

			$syncHash.DC.Window[0] = "$( $syncHash.Data.msgTable.StrOpUserStart ) $( $User.User )"
			foreach ( $installation in $UserLog )
			{
				$Runspace = [powershell]::Create()
				$Runspace.RunspacePool = $RunspacePool
				$Runspace.AddScript( {
					param ( $in, $syncHash )
					try
					{
						$ofs = "`n"
						$r = Get-ADComputer ( $in.Computer ) -Properties MemberOf -ErrorAction Stop | Select-Object -ExpandProperty MemberOf | Where-Object { $_ -like $syncHash.Data.msgTable.CodeCompTypeRegEx } | ForEach-Object { ( ( $_ -split "=" )[1] -split "," )[0] }
						if ( $r.Count -eq 0 )
						{ $t = $syncHash.Data.msgTable.StrOtherCompRole }
						else
						{
							$r | ForEach-Object {
								if ( ( $syncHash.Data.msgTable.CodeAllowedCompOrgs -split "," | Foreach-Object -Begin { $ok = $false } -Process { if ( $r -match $_.Trim() ) { $ok = $true } } -End { $ok } ) -and `
								( $syncHash.Data.msgTable.CodeAllowedCompRoles-split "," | Foreach-Object -Begin { $ok = $false } -Process { if ( $r -match $_.Trim() ) { $ok = $true } } -End { $ok } ) )
								{ $wrongType = 0 }
								else { $containsWrongType = $true }
							}
							if ( $containsWrongType ) { $wrongType = 1 }
							$t = [string]$r
						}
					}
					catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]
					{
						$t = $syncHash.Data.msgTable.StrComputerNotFound
					}
					catch
					{
						$t = $syncHash.Data.msgTable.StrErrorADLookup
					}
					[pscustomobject]@{ Computer = $in.Computer; Date = ( Get-Date $in.Date ); Type = $t ; Description = $in.Description; WrongType = $wrongType }
				} )
				$Runspace.AddArgument( $installation )
				$Runspace.AddArgument( $syncHash )
				$jobs.Add( @{ Runspace = $Runspace; Handle = $Runspace.BeginInvoke() } )
				$i++
				$syncHash.DC.PbProgress[0] = [double]( ( $i / $UserLog.Count ) * 100 )
			}
			return @{ Jobs = $jobs; LogCount = $UserLog.Count; RSP = $RunspacePool }
		}

		[void] $syncHash.DC.LvDescriptionView[0].Clear()

		if ( $syncHash.SelectedUser )
		{
			$data = GetUserInstallations -User ( $syncHash.SelectedUser )

			$syncHash.DC.Window[0] = $syncHash.Data.msgTable.StrOpWaitData
			do
			{
				Start-Sleep -Milliseconds 500
				$completed = ( $data.Jobs | Where-Object { $_.Handle.IsCompleted -eq "Completed" } ).Count
				$syncHash.DC.PbProgress[0] = [double]( ( $completed / $data.Jobs.Count ) * 100 )
			} until ( $completed -eq $data.Jobs.Count )

			$ticker = 0
			$syncHash.DC.Window[0] = $syncHash.Data.msgTable.StrOpUserImporting
			foreach ( $j in $data.Jobs )
			{
				$syncHash.DC.LvDescriptionView[0].Add( $j.Runspace.EndInvoke( $j.Handle ) )
				$j.Runspace.Dispose()
				$ticker++
				$syncHash.DC.PbProgress[0] = [double]( ( $ticker / $data.Jobs.Count ) * 100 )
			}
			$data.RSP.Close()
		}
		$syncHash.Controls.Window.Dispatcher.Invoke( [action]{
			#$syncHash.Controls.LvDescriptionView.Items.Refresh()
			$syncHash.DC.Window[0] = $syncHash.Data.msgTable.StrWinTitle
			$syncHash.DC.PbProgress[0] = [double] 0.0
		}, "Normal" )
	} ).AddArgument( $syncHash ) ).BeginInvoke()
} )

$syncHash.Controls.Window.Add_Loaded( {
	$syncHash.Controls.DatePickerStart.BlackoutDates.Clear()
	$disabledDates = [System.Windows.Controls.CalendarDateRange]::new()
	$disabledDates.Start = ( Get-Date ).AddDays( 1 )
	$disabledDates.End = ( Get-Date ).AddDays( 31 )
	$syncHash.Controls.DatePickerStart.BlackoutDates.Add( $disabledDates )

} )

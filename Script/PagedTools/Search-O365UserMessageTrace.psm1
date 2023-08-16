<#
.Synopsis
	Search messagetrace to or from specified user
.Description
	Make a message trace for specified recipient or sender between specified dates
.Depends
	ExchangeAdministrator
.ObjectOperations
	O365User
.State
	Prod
.Author
	Smorkster (smorkster)
#>

Add-Type -AssemblyName PresentationFramework
Import-Module ActiveDirectory
$syncHash = $args[0]

function Export
{
	<#
	.Synopsis
		Export data to an Excel-file
	#>

	( [powershell]::Create().AddScript( {
		param ( $syncHash, $Modules )
		Import-Module $Modules -Force

		$excel = New-Object -ComObject excel.application 
		$excel.visible = $false
		$excelWorkbook = $excel.Workbooks.Add()
		$excelWorksheet = $excelWorkbook.ActiveSheet

		$OutputEncoding = ( New-Object System.Text.UnicodeEncoding $False, $False ).psobject.BaseObject
		$syncHash.Data.Trace.Received | ForEach-Object { "$( $_.ToShortDateString()) $($_.ToLongTimeString())" } | clip
		$excelWorksheet.Cells.Item( 1, 1 ).PasteSpecial() | Out-Null
		$syncHash.Data.Trace.SenderAddress | clip
		$excelWorksheet.Cells.Item( 2, 2 ).PasteSpecial() | Out-Null
		$syncHash.Data.Trace.RecipientAddress | clip
		$excelWorksheet.Cells.Item( 2, 3 ).PasteSpecial() | Out-Null
		$syncHash.Data.Trace.Subject | clip
		$excelWorksheet.Cells.Item( 2, 4 ).PasteSpecial() | Out-Null
		$syncHash.Data.Trace.Status | clip
		$excelWorksheet.Cells.Item( 2, 5 ).PasteSpecial() | Out-Null

		$excelWorksheet.Cells.Item( 1, 1 ) = "Receivedate"
		$excelWorksheet.Cells.Item( 1, 2 ) = "SenderAddress"
		$excelWorksheet.Cells.Item( 1, 3 ) = "RecipientAddress"
		$excelWorksheet.Cells.Item( 1, 4 ) = "Subject"
		$excelWorksheet.Cells.Item( 1, 5 ) = "Status"

		$range = $excelWorksheet.Range( $excelWorksheet.Cells.Item( 2, 1 ), $excelWorksheet.Cells.Item( $syncHash.Data.Trace.Count + 1, 1 ) )
		$range.NumberFormat = $syncHash.Data.msgTable.StrExportDateFormat

		$excelRange = $excelWorksheet.UsedRange
		$excelRange.EntireColumn.AutoFit() | Out-Null
		$excelWorksheet.ListObjects.Add( 1, $excelWorksheet.Range( $excelWorksheet.Cells.Item( 1, 1 ), $excelWorksheet.Cells.Item( $excelWorksheet.usedrange.rows.count, 5 ) ), 0, 1 ) | Out-Null
		$excelWorkbook.SaveAs( $syncHash.Data.FileToSave.FileName )
		$excelWorkbook.Close()
		$excel.Quit()
		Show-Splash -Text "$( $syncHash.Data.msgTable.StrExportSaved )`n$( $syncHash.Data.FileToSave.FileName )" -NoProgressBar -NoTitle

		[System.Runtime.Interopservices.Marshal]::ReleaseComObject( $excelRange ) | Out-Null
		[System.Runtime.Interopservices.Marshal]::ReleaseComObject( $excelWorksheet ) | Out-Null
		[System.Runtime.Interopservices.Marshal]::ReleaseComObject( $excelWorkbook ) | Out-Null
		[System.Runtime.Interopservices.Marshal]::ReleaseComObject( $excel ) | Out-Null
		[System.GC]::Collect()
		[System.GC]::WaitForPendingFinalizers()
		Remove-Variable excel
	} ).AddArgument( $syncHash ) ).AddArgument( ( Get-Module | Where-Object { Test-Path $_.Path } ) ).BeginInvoke()
}

function Reset
{
	<#
	.Synopsis
		Reset data to default value
	#>

	$syncHash.DC.TblExportSavePath[0] = [System.Windows.Visibility]::Collapsed

	$syncHash.Controls.TbSender.Text = ""
	$syncHash.Controls.TbReceiver.Text = ""
	$syncHash.Controls.TbPageSize.Text = 1000
	$syncHash.DC.TblExportSavePath[1] = ""

	$syncHash.DC.BtnExport[0] = $false
	$syncHash.DC.DpStart[0] = ( Get-Date ).AddDays( -10 )
	$syncHash.DC.DpEnd[0] = Get-Date
	$syncHash.Controls.DpEnd.DisplayDateEnd = Get-Date
	$syncHash.Controls.DpEnd.DisplayDateStart = ( Get-Date ).Date.AddDays( -10 )
	$syncHash.Controls.DpEnd.Text = $syncHash.Controls.DpEnd.DisplayDate.ToShortDateString()
	$syncHash.Controls.DpStart.DisplayDate = ( Get-Date ).Date.AddDays( -10 )
	$syncHash.Controls.DpStart.DisplayDateEnd = Get-Date
	$syncHash.Controls.DpStart.DisplayDateStart = ( Get-Date ).Date.AddDays( -10 )
	$syncHash.Controls.DpStart.Text = $syncHash.Controls.DpStart.DisplayDate.ToShortDateString()


	$syncHash.Controls.Window.Resources['CvsTrace'].Source.Clear()
	try { $syncHash.Data.Trace.Clear() } catch {}

	$syncHash.Controls.Window.Resources['CvsStatus'].Source.Clear()
	$syncHash.Data.msgTable.GetEnumerator() | `
		Where-Object { $_.Key -match "^StrStatus" } | `
		ForEach-Object {
			$syncHash.Controls.Window.Resources['CvsStatus'].Source.Add( ( [pscustomobject]@{ Name = ( $_.Key -replace "StrStatus" ) ; ToolTip = $_.Value ; Active = $true } ) )
		}
	$syncHash.Controls.Window.Resources['CvsStatus'].View.Refresh()
}

##################### Scriptstart
$controls = New-Object System.Collections.ArrayList
[void]$controls.Add( @{ CName = "BtnExport" ; Props = @( @{ PropName = "IsEnabled" ; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "DpEnd" ; Props = @( @{ PropName = "SelectedDate"; PropVal = Get-Date } ) } )
[void]$controls.Add( @{ CName = "DpStart" ; Props = @( @{ PropName = "SelectedDate"; PropVal = ( Get-Date ).AddDays( -10 ) } ) } )
[void]$controls.Add( @{ CName = "TblExportSavePath" ; Props = @( @{ PropName = "Visibility"; PropVal = [System.Windows.Visibility]::Collapsed } ; @{ PropName = "Text" ; PropVal = "" } ) } )

BindControls $syncHash $controls
$syncHash.Data.Admin = ( Get-AzureADCurrentSessionInfo ).Account.Id
$syncHash.Controls.Window.Resources['CvsStatus'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
$syncHash.Controls.Window.Resources['CvsTrace'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
$syncHash.Controls.Window.Resources['CvsTraceDetails'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
$syncHash.Data.Test = [system.collections.arraylist]::new()

# Subtract PageSize number
$syncHash.Controls.BtnDown.Add_Click( {
	if ( $syncHash.Controls.TbPageSize.Text -gt 0 )
	{
		$syncHash.Controls.TbPageSize.Text = ( ( [int]$syncHash.Controls.TbPageSize.Text ) - 1 ).ToString()
	}
	else
	{
		$syncHash.Controls.TbPageSize.Text = 0
	}
} )

# Export data to Excel
$syncHash.Controls.BtnExport.Add_Click( {
	$OFS = " "
	$fileDialog = [Microsoft.Win32.SaveFileDialog]@{ DefaultExt = ".xlsx"; Filter = "Excel-files | *.xlsx" ; FileName = ( [string] $syncHash.Data.SearchName ) }
	if ( $fileDialog.ShowDialog() )
	{
		$syncHash.Data.FileToSave = $fileDialog
		Export
		WriteLog -OutputPath $syncHash.Data.FileToSave.FileName -UserInput $syncHash.Data.msgTable.LogExported -Success $true
	}
} )

# Get message trace details about selected mail
$syncHash.Controls.BtnGetInfo.Add_Click( {
	$syncHash.Controls.Window.Resources['CvsTraceDetails'].Source.Clear()
	Get-MessageTraceDetail -MessageTraceId $syncHash.Controls.DgResult.SelectedItem.MessageTraceId `
							-RecipientAddress $syncHash.Controls.DgResult.SelectedItem.RecipientAddress | `
		ForEach-Object {
			$syncHash.Controls.Window.Resources['CvsTraceDetails'].Source.Add( $_ ) | Out-Null
		}

	if ( 0 -eq $syncHash.Controls.Window.Resources['CvsTraceDetails'].Source.Count )
	{
		$syncHash.Controls.Window.Resources['CvsTraceDetails'].Source.Add( ( [pscustomobject]@{ Detail = $syncHash.Data.msgTable.ErrNoMessageTraceDetails ; Date = ( Get-Date ) } ) ) | Out-Null
	}

	$syncHash.Controls.Window.Resources['CvsTraceDetails'].View.Refresh()
	$syncHash.Controls.TcTraceInfo.SelectedIndex = 1
} )

# Reset default values
$syncHash.Controls.BtnReset.Add_Click( {
	Reset
} )

# Start a search for message trace
$syncHash.Controls.BtnSearch.Add_Click( {
	$syncHash.DC.TblExportSavePath[0] = [System.Windows.Visibility]::Collapsed
	$syncHash.DC.TblExportSavePath[1] = ""
	$syncHash.Data.Trace = $null
	$syncHash.Controls.Window.Resources['CvsTrace'].Source.Clear()
	$param = @{}

	if ( $syncHash.Data.SenderEmail )
	{
		$param.SenderAddress = $syncHash.Data.SenderEmail
	}

	if ( $syncHash.Data.ReceiverEmail )
	{
		$param.RecipientAddress = $syncHash.Data.ReceiverEmail
	}

	if ( $syncHash.Data.StartDate )
	{
		$param.StartDate = $syncHash.Data.StartDate
	}
	else
	{
		$param.StartDate = ( Get-Date ).AddDays( -10 )
	}

	if ( $syncHash.Data.EndDate )
	{
		$param.EndDate = $syncHash.Data.EndDate
	}
	else
	{
		$param.EndDate = ( Get-Date )
	}

	if ( [ipaddress]::TryParse( $syncHash.Controls.TbFromIP.Text, [ref] $null ) )
	{
		$param.FromIP = $syncHash.Controls.TbFromIP.Text
	}

	if ( [ipaddress]::TryParse( $syncHash.Controls.TbToIp.Text, [ref] $null ) )
	{
		$param.ToIP = $syncHash.Controls.TbToIp.Text
	}

	$param.PageSize = [int]$syncHash.Controls.TbPageSize.Text

	$param.Status = @()
	if ( 0 -eq $syncHash.Controls.Window.Resources['CvsStatus'].Source.Where( { $_.Active } ).Count )
	{
		$syncHash.Controls.Window.Resources['CvsStatus'].Source.ForEach( { $_.Active } )
	}
	$syncHash.Controls.Window.Resources['CvsStatus'].Source | `
		ForEach-Object {
			$param.Status += "$( $_.Name )"
		}

	$syncHash.Data.Test = $param
	$syncHash.Data.Trace = Get-MessageTrace @param
	$syncHash.Data.Trace | `
		ForEach-Object {
			$syncHash.Controls.Window.Resources['CvsTrace'].Source.Add( $_ ) | Out-Null
		}
	TextToSpeech -Text ( $syncHash.Data.msgTable.StrDone )

	$syncHash.Data.SearchName = @( $syncHash.Data.msgTable.StrExportDefaultFileName )

	if ( $syncHash.Data.SenderEmail )
	{
		$syncHash.Data.SearchName += "$( $syncHash.Data.msgTable.StrExportFileNameFrom ) $( $syncHash.Data.SenderEmail )"
	}

	if ( $syncHash.Data.ReceiverEmail )
	{
		$syncHash.Data.SearchName += "$( $syncHash.Data.msgTable.StrExportFileNameFo ) $( $syncHash.Data.ReceiverEmail )"
	}

	$syncHash.Data.SearchName += "$( $syncHash.Data.msgTable.StrExportFileNameDates ) $( $syncHash.DC.DpStart[0].ToShortDateString() ) - $( $syncHash.DC.DpEnd[0].ToShortDateString() )"

	$OFS = "`n"
	$outputFile = WriteOutput -Output "$( [string]( $syncHash.Data.Trace | Out-String ) )" -FileName "$( $syncHash.Data.msgTable.StrOutputFileNamePrefix ) $( $param.SenderAddress ) $( $param.RecipientAddress )"
	WriteLog -Text "$( $syncHash.Data.Trace.Count ) $( $syncHash.Data.msgTable.LogTraceCount )" -UserInput "$( $syncHash.Data.msgTable.LogSearchDates )" -Success $true -OutputPath $outputFile | Out-Null
	$syncHash.DC.BtnExport[0] = $syncHash.Data.Trace.Count -gt 0
	$syncHash.Controls.TcTraceInfo.SelectedIndex = 0
} )

# Add to PageSize number
$syncHash.Controls.BtnUp.Add_Click( {
	if ( $syncHash.Controls.TbPageSize.Text -lt 5000 )
	{
		$syncHash.Controls.TbPageSize.Text = ( ( [int]$syncHash.Controls.TbPageSize.Text ) + 1 ).ToString()
	}
	else
	{
		$syncHash.Controls.TbPageSize.Text = 5000
	}
} )

# DatePicker have been interacted
$syncHash.Controls.DpEnd.Add_KeyDown( {
	if ( $args[1].Key -eq "Escape" )
	{
		$this.SelectedDate = Get-Date
	}
} )

# DatePicker have been interacted
$syncHash.Controls.DpEnd.Add_LostFocus( {
	if ( $null -eq $this.SelectedDate )
	{
		$this.SelectedDate = Get-Date
	}
} )

# DatePicker have been interacted
$syncHash.Controls.DpStart.Add_KeyDown( {
	if ( $args[1].Key -eq "Escape" )
	{
		$this.SelectedDate = ( Get-Date ).AddDays( -10 )
	}
} )

# DatePicker have been interacted
$syncHash.Controls.DpStart.Add_LostFocus( {
	if ( $null -eq $this.SelectedDate )
	{
		$this.SelectedDate = ( Get-Date ).AddDays( -10 )
	}
} )

# Stop invalid characters from being entered
$syncHash.Controls.TbFromIp.Add_KeyDown( {
	if ( $args[1].Key -notmatch "[0-9]|OemPeriod" )
	{
		$args[1].Handled = $true
	}
} )

# If text other than numbers are entered, reset to default value
$syncHash.Controls.TbPageSize.Add_TextChanged( {
	if ( -not [int]::TryParse( $this.Text , [ref] $null ) )
	{
		$this.Text = 1000
	}
} )

# Verify that entered text is a valid mailaddress
$syncHash.Controls.TbReceiver.Add_LostFocus( {
	if (
		( Test-MailAddress -Address $this.Text ) -or `
		( 0 -eq $this.Text.Length )
	)
	{
		$syncHash.Data.ReceiverEmail = $this.Text
		$syncHash.Controls.Window.Resources['InvalidReceiver'] = [System.Windows.Visibility]::Hidden
	}
	else
	{
		$syncHash.Data.ReceiverEmail = $null
		$syncHash.Controls.Window.Resources['InvalidReceiver'] = [System.Windows.Visibility]::Visible
	}
} )

# Verify that entered text is a valid mailaddress
$syncHash.Controls.TbReceiver.Add_LostKeyboardFocus( {
	if (
		( Test-MailAddress -Address $this.Text ) -or `
		( 0 -eq $this.Text.Length )
	)
	{
		$syncHash.Data.ReceiverEmail = $this.Text
		$syncHash.Controls.Window.Resources['InvalidReceiver'] = [System.Windows.Visibility]::Hidden
	}
	else
	{
		$syncHash.Data.ReceiverEmail = $null
		$syncHash.Controls.Window.Resources['InvalidReceiver'] = [System.Windows.Visibility]::Visible
	}
} )

# Verify that entered text is a valid mailaddress
$syncHash.Controls.TbSender.Add_LostFocus( {
	if (
		( Test-MailAddress -Address $this.Text ) -or `
		( 0 -eq $this.Text.Length )
	)
	{
		$syncHash.Data.SenderEmail = $this.Text
		$syncHash.Controls.Window.Resources['InvalidSender'] = [System.Windows.Visibility]::Hidden
	}
	else
	{
		$syncHash.Data.SenderEmail = $null
		$syncHash.Controls.Window.Resources['InvalidSender'] = [System.Windows.Visibility]::Visible
	}
} )

# Verify that entered text is a valid mailaddress
$syncHash.Controls.TbSender.Add_LostKeyboardFocus( {
	if (
		( Test-MailAddress -Address $this.Text ) -or `
		( 0 -eq $this.Text.Length )
	)
	{
		$syncHash.Data.SenderEmail = $this.Text
		$syncHash.Controls.Window.Resources['InvalidSender'] = [System.Windows.Visibility]::Hidden
	}
	else
	{
		$syncHash.Data.SenderEmail = $null
		$syncHash.Controls.Window.Resources['InvalidSender'] = [System.Windows.Visibility]::Visible
	}
} )

# Stop invalid characters from being entered
$syncHash.Controls.TbToIp.Add_KeyDown( {
	if ( $args[1].Key -notmatch "[0-9]|OemPeriod" )
	{
		$args[1].Handled = $true
	}
} )

# Window is first loaded
$syncHash.Controls.Window.Add_Loaded( {
	$syncHash.Controls.TbSender.Focus()
	$syncHash.Controls.DgResult.Columns[0].Header = $syncHash.Data.msgTable.ContentDgColReceived
	$syncHash.Controls.DgResult.Columns[1].Header = $syncHash.Data.msgTable.ContentDgColSender
	$syncHash.Controls.DgResult.Columns[2].Header = $syncHash.Data.msgTable.ContentDgColReceiver
	$syncHash.Controls.DgResult.Columns[3].Header = $syncHash.Data.msgTable.ContentDgColSubject
	$syncHash.Controls.DgResult.Columns[4].Header = $syncHash.Data.msgTable.ContentDgColStatus

	Reset
} )

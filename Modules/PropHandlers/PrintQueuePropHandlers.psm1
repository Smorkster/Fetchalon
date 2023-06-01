<#
.Synopsis Property handlers for printqueue objects
.Description A collection of objects, as property handlers, to operate on objects with objectclass 'printQueue'
.State Prod
.Author Smorkster (smorkster)
#>

param ( $culture = "sv-SE" )

$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.Parent.FullName

Import-LocalizedData -BindingVariable IntMsgTable -UICulture $culture -FileName "$( ( $PSCommandPath.Split( "\" ) | Select-Object -Last 1 ).Split( "." )[0] ).psd1" -BaseDirectory "$RootDir\Localization"

# Handler to turn MemberOf-list to more readble strings
$MemberOf = [pscustomobject]@{
	Code = '$List = [System.Collections.ArrayList]::new()
	$SenderObject.DataContext.Value | Get-ADGroup | Select-Object -ExpandProperty Name | Sort-Object | ForEach-Object { $List.Add( $_ ) | Out-Null }
	$SenderObject.DataContext.Value = $List
	$syncHash.IcPropsList.Items.Refresh()'
	Title = $IntMsgTable.HTMemberOf
	Description = $IntMsgTable.HDescMemberOf
	Progress = 0
	MandatorySource = "AD"
}

# Handler to open a printers webpage in Chrome, from its portname (IP)
$portName = [pscustomobject]@{
	Code = '[System.Diagnostics.Process]::Start( "chrome", "http://$( $SenderObject.DataContext.Value )/" )'
	Title = $IntMsgTable.HTOpenPrinterWebpage
	Description = $IntMsgTable.HDescOpenPrinterWebpage
	Progress = 0
	MandatorySource = "AD"
}

# Remove printjobs on selected printQueue
$PrintJobs = [pscustomobject]@{
	Code = '$syncHash.Jobs.PClearPrinterJobs = [powershell]::Create()
	$syncHash.Jobs.PClearPrinterJobs.AddScript( { param ( $syncHash, $c, $list )
		$list | ForEach-Object `
			-Begin {
				$t = 0
				$syncHash.Window.Dispatcher.Invoke( [action] {
					$syncHash.PbProgress.Maximum = $list.Count
					$syncHash.PbProgress.Value = 0
					$syncHash.GridProgress.Visibility = [System.Windows.Visibility]::Visible
					$syncHash.PbProgress.IsIndeterminate = $false
					$syncHash.TbProgress.Text = $syncHash.Data.msgTable.StrClearPrintJobs
					$c.HandlerProgressMax = $list.Count
				} )
			} `
			-Process {
				Remove-PrintJob $_.Job
				$t = $t + 1
				$syncHash.Window.Dispatcher.Invoke( [action] {
					$syncHash.PbProgress.Value = $t
					$c.HandlerProgress += 1
				} )
			} `
			-End {
				$syncHash.Window.Dispatcher.Invoke( [action] {
					($syncHash.Window.Resources[''CvsPropsList''].Source.Where({ $_.Name -eq "PrintJobs" }))[0].Value.Clear()
					$syncHash.Window.Resources[''CvsPropsList''].View.Refresh()
					($syncHash.Window.Resources[''CvsDetailedProps''].Source.Where({ $_.Name -eq "PrintJobs" }))[0].Value.Clear()
					$syncHash.Window.Resources[''CvsDetailedProps''].View.Clear()
					$syncHash.GridProgress.Visibility = [System.Windows.Visibility]::Hidden
					$syncHash.PbProgress.IsIndeterminate = $true
					$syncHash.TbProgress.Text = ""
					$c.HandlerProgress = 0
				} )
			}
	} )
	$syncHash.Jobs.PClearPrinterJobs.AddArgument( $syncHash )
	$syncHash.Jobs.PClearPrinterJobs.AddArgument( $SenderObject )
	$syncHash.Jobs.PClearPrinterJobs.AddArgument( $SenderObject.DataContext.Value )
	$syncHash.Jobs.HClearPrinterJobs = $syncHash.Jobs.PClearPrinterJobs.BeginInvoke()
	'
	Title = $IntMsgTable.HTClearPrintQueueJobs
	Description = $IntMsgTable.HDescClearPrintQueueJobs
	MandatorySource = "Other"
}

Export-ModuleMember -Variable MemberOf, portName, PrintJobs

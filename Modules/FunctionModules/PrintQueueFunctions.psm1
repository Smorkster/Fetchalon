<#
.Synopsis A collection of functions to run for a printQueue-object
.Description A collection of functions to run for a printQueue-object
.ObjectClass printQueue
.State Dev
#>

param ( $culture = "sv-SE" )

function Install-SysManPrinter
{
	<#
	.Synopsis Install printer/-s on compter/-s via SysMan
	.Description Install one or more printers on one or more computer via SysMan
	.MenuItem Install printer on computer
	.SearchedItemRequest Allowed
	.OutputType String
	.InputData Printers Printernames, separated by spaces
	.InputData Computers Computernames, separate by spaces
	.Author Smorkster
	#>

	param ( $InputData )

	$PIdsString = [System.Text.StringBuilder]::new()
	$CIdsString = [System.Text.StringBuilder]::new()
	$ReturnMessage = [System.Text.StringBuilder]::new()
	$PrinterNames = $InputData.Printers -split "\W" | Where-Object { $_ }
	$ComputerNames = $InputData.Computers -split "\W" | Where-Object { $_ }
	$FoundPrinters = [System.Collections.ArrayList]::new()
	$FailedPrinters = [System.Collections.ArrayList]::new()
	$FoundComputers = [System.Collections.ArrayList]::new()
	$FailedComputers = [System.Collections.ArrayList]::new()

	$PrinterNames | `
		ForEach-Object {
			$resp = Invoke-RestMethod -Uri "$( $IntMsgTable.SysManServerUrl )/api/Printer?name=$( $_ )&take=1&skip=0" -Method Get -UseDefaultCredentials -ContentType "application/json"
			if ( $resp.totalCount -gt 0 )
			{
				$FoundPrinters.Add( $resp ) | Out-Null
				$PIdsString.Append( "{""id"":$( $resp.result[0].id ),""isDefault"":false}," ) | Out-Null
			}
			else
			{
				$FailedPrinters.Add( $_ ) | Out-Null
			}
		}
	$ComputerNames | `
		ForEach-Object {
			$resp = Invoke-RestMethod -Uri "$( $IntMsgTable.SysManServerUrl )/api/Client?name=$( $_ )&take=1&skip=0" -Method Get -UseDefaultCredentials -ContentType "application/json"
			if ( $resp.totalCount -gt 0 )
			{
				$FoundComputers.Add( $resp ) | Out-Null
				$CIdsString.Append( "$( $resp.result[0].id )," ) | Out-Null
			}
			else
			{
				$FailedComputers.Add( $_ ) | Out-Null
			}
		}

	$OFS = "`n"
	if ( $PIdsString.Length -gt 0 )
	{
		if ( $CIdsString.Length -gt 0 )
		{
			$b = "{""targets"": [$( $CIdsString.ToString().TrimEnd( "," ) )],""printers"": [$( $PIdsString.ToString().TrimEnd( "," ) )]}"
			try
			{
				$OFS = ", "
				Invoke-RestMethod -Uri "$( $IntMsgTable.SysManServerUrl )/api/printer/Install" -Method Post -UseDefaultCredentials -ContentType "application/json" -Body $b -ErrorAction Stop | Out-Null
				Set-Clipboard -Value ( $IntmsgTable.InstallSysManPrinterSuccess -replace "CNames", $FoundComputers.result.Name -replace "PNames", $FoundPrinters.result.Name -replace "\\", "`r`n" ) | Out-Null
			}
			catch
			{
				throw $_
			}
		}
		else
		{
			throw $IntMsgTable.InstallSysManPrinterNoComputer
		}
	}
	else
	{
		throw $IntMsgTable.InstallSysManPrinterNoPrinter
	}

	$ReturnMessage = $IntmsgTable.InstallSysManPrinterReturn
	if ( $FailedComputers.Count -gt 0 )
	{
		$ReturnMessage.Append( "$InstallSysManPrinterNotFoundComputers" ) | Out-Null
		$ReturnMessage.Append( "$FailedComputers" ) | Out-Null
	}

	if ( $FailedPrinters.Count -gt 0 )
	{
		$ReturnMessage.Append( "$InstallSysManPrinterNotFoundPrinters" ) | Out-Null
		$ReturnMessage.Append( "$FailedPrinters" ) | Out-Null
	}

	return $ReturnMessage.ToString()
}

$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.FullName
Import-LocalizedData -BindingVariable IntmsgTable -UICulture $culture -FileName "$( ( $PSCommandPath.Split( "\" ) | Select-Object -Last 1 ).Split( "." )[0] ).psd1" -BaseDirectory "$RootDir\Localization\$culture\Modules"

Export-ModuleMember -Function Install-SysManPrinter
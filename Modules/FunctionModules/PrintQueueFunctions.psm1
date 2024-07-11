<#
.Synopsis
	A collection of functions to run for a printQueue-object
.Description
	A collection of functions to run for a printQueue-object
.ObjectClass
	printQueue
.State
	Prod
.Author
	Smorkster (smorkster)
#>

param ( $culture = "sv-SE" )

function Install-SysManPrinter
{
	<#
	.Synopsis
		Install printer/-s on compter/-s via SysMan
	.Description
		Install one or more printers on one or more computer via SysMan
	.MenuItem
		Install printer on computer
	.SearchedItemRequest
		Allowed
	.OutputType
		String
	.InputData
		Printers, True, Printernames, separated by spaces
	.InputData
		Computers, True, Computernames, separate by spaces
	.State
		Prod
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item, $InputData )

	$PIdsString = [System.Text.StringBuilder]::new()
	$CIdsString = [System.Text.StringBuilder]::new()
	$OpMessage = [System.Text.StringBuilder]::new()
	$ReturnMessage = [System.Text.StringBuilder]::new()
	$FoundPrinters = [System.Collections.ArrayList]::new()
	$FailedPrinters = [System.Collections.ArrayList]::new()
	$FoundComputers = [System.Collections.ArrayList]::new()
	$FailedComputers = [System.Collections.ArrayList]::new()

	$PrinterNames = $InputData.Printers -replace "-", "_" -split "\W" | Where-Object { $_ }
	$ComputerNames = $InputData.Computers -split "\W" | Where-Object { $_ }

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
				$OpMessage.AppendLine( $IntMsgTable.InstallSysManPrinterSuccess ) | Out-Null
				$OpMessage.AppendLine() | Out-Null
				$OpMessage.AppendLine( $IntMsgTable.InstallSysManPrinterSuccessPrintersTitle ) | Out-Null
				$OpMessage.AppendLine( $FoundPrinters.result.Name ) | Out-Null
				$OpMessage.AppendLine() | Out-Null
				$OpMessage.AppendLine( $IntMsgTable.InstallSysManPrinterSuccessComputerTitle ) | Out-Null
				$OpMessage.AppendLine( $FoundComputers.result.Name ) | Out-Null
				$OpMessage.AppendLine() | Out-Null
				$OpMessage.AppendLine( $IntMsgTable.InstallSysManPrinterSuccessEnding ) | Out-Null

				if ( $FailedComputers.Count -gt 0 -or $FailedPrinters.Count -gt 0 )
				{
					$OpMessage.AppendLine() | Out-Null
					$OpMessage.AppendLine( $IntMsgTable.InstallSysManPrinterSuccessFailedNames ) | Out-Null
					if ( $FailedComputers.Count -gt 0 )
					{
						$OpMessage.AppendLine( $FailedComputers ) | Out-Null
					}

					if ( $FailedPrinters.Count -gt 0 )
					{
						$OpMessage.AppendLine( $FailedPrinters ) | Out-Null
					}
				}
				Set-Clipboard -Value $OpMessage.ToString() | Out-Null
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

	$ReturnMessage.Append( $IntMsgTable.InstallSysManPrinterReturn ) | Out-Null
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

function Uninstall-SysManPrinter
{
	<#
	.Synopsis
		Uninstall printers on computer via SysMan
	.Description
		Uninstalls printer queue for computer via SysMan
	.MenuItem
		Uninstall printers on computer via SysMan
	.SearchedItemRequest
		Allowed
	.OutputType
		String
	.InputData
		Printers, True, Printer names, separated by spaces
	.InputData
		ComputerNames, True, Computer names, separated by spaces
	.State
		Prod
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item, $InputData )

	$PIdsString = [System.Text.StringBuilder]::new()
	$CIdsString = [System.Text.StringBuilder]::new()
	$OpMessage = [System.Text.StringBuilder]::new()
	$ReturnMessage = [System.Text.StringBuilder]::new()
	$FoundPrinters = [System.Collections.ArrayList]::new()
	$FailedPrinters = [System.Collections.ArrayList]::new()
	$FoundComputers = [System.Collections.ArrayList]::new()
	$FailedComputers = [System.Collections.ArrayList]::new()

	$PrinterNames = $InputData.Printers -replace "-", "_" -split "\W" | Where-Object { $_ }
	$ComputerNames = $InputData.ComputerNames -split "\W" | Where-Object { $_ }

	$PrinterNames | `
		ForEach-Object {
			$resp = Invoke-RestMethod -Uri "$( $IntMsgTable.SysManServerUrl )/api/Printer?name=$( $_ )&take=1&skip=0" -Method Get -UseDefaultCredentials -ContentType "application/json"
			if ( $resp.totalCount -gt 0 )
			{
				$FoundPrinters.Add( $resp ) | Out-Null
				$PIdsString.Append( "$( $resp.result[0].id )," ) | Out-Null
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
				Invoke-RestMethod -Uri "$( $IntMsgTable.SysManServerUrl )/api/printer/Uninstall" -Method Post -UseDefaultCredentials -ContentType "application/json" -Body $b -ErrorAction Stop | Out-Null
				$OpMessage.AppendLine( $IntMsgTable.UninstallSysManPrinterSuccess ) | Out-Null
				$OpMessage.AppendLine() | Out-Null
				$OpMessage.AppendLine( $IntMsgTable.UninstallSysManPrinterSuccessPrintersTitle ) | Out-Null
				$OpMessage.AppendLine( $FoundPrinters.result.Name ) | Out-Null
				$OpMessage.AppendLine() | Out-Null
				$OpMessage.AppendLine( $IntMsgTable.UninstallSysManPrinterSuccessComputerTitle ) | Out-Null
				$OpMessage.AppendLine( $FoundComputers.result.Name ) | Out-Null
				$OpMessage.AppendLine() | Out-Null
				$OpMessage.AppendLine( $IntMsgTable.UninstallSysManPrinterSuccessEnding ) | Out-Null

				if ( $FailedComputers.Count -gt 0 -or $FailedPrinters.Count -gt 0 )
				{
					$OpMessage.AppendLine() | Out-Null
					$OpMessage.AppendLine( $IntMsgTable.UninstallSysManPrinterSuccessFailedNames ) | Out-Null
					if ( $FailedComputers.Count -gt 0 )
					{
						$OpMessage.AppendLine( $FailedComputers ) | Out-Null
					}

					if ( $FailedPrinters.Count -gt 0 )
					{
						$OpMessage.AppendLine( $FailedPrinters ) | Out-Null
					}
				}
				Set-Clipboard -Value $OpMessage.ToString() | Out-Null
			}
			catch
			{
				throw $_
			}
		}
		else
		{
			throw $IntMsgTable.UninstallSysManPrinterNoComputer
		}
	}
	else
	{
		throw $IntMsgTable.UninstallSysManPrinterNoPrinter
	}

	$ReturnMessage.Append( $IntMsgTable.UninstallSysManPrinterReturn ) | Out-Null
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

$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.Parent.FullName

Import-LocalizedData -BindingVariable IntMsgTable -UICulture $culture -FileName "$( ( $PSCommandPath.Split( "\" ) | Select-Object -Last 1 ).Split( "." )[0] ).psd1" -BaseDirectory "$RootDir\Localization"

Export-ModuleMember -Function Install-SysManPrinter,
							Uninstall-SysManPrinter

<#
.Synopsis
	Property handlers for printqueue objects
.Description
	A collection of objects, as property handlers, to operate on objects with objectclass 'printQueue'
.State
	Prod
.Author
	Smorkster (smorkster)
#>

param ( $culture = "sv-SE" )

$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.Parent.FullName

Import-LocalizedData -BindingVariable IntMsgTable -UICulture $culture -FileName "$( ( $PSCommandPath.Split( "\" ) | Select-Object -Last 1 ).Split( "." )[0] ).psd1" -BaseDirectory "$RootDir\Localization"

# Handler to turn MemberOf-list to more readble strings
$PHPrintQueueAdMemberOf = [pscustomobject]@{
	Code = '
	$NewPropValue = [System.Collections.ArrayList]::new()
	$SenderObject.DataContext.Value | Get-ADGroup | Select-Object -ExpandProperty Name | Sort-Object | ForEach-Object { $NewPropValue.Add( $_ ) | Out-Null }
	'
	Title = $IntMsgTable.HTPrintQueueAdMemberOf
	Description = $IntMsgTable.HDescPrintQueueAdMemberOf
	Progress = 0
	MandatorySource = "AD"
}

# Handler to open a printers webpage in Chrome, from its portname (IP)
$PHPrintQueueAdportName = [pscustomobject]@{
	Code = '
	[System.Diagnostics.Process]::Start( "chrome", "http://$( $SenderObject.DataContext.Value )/" )
	'
	Title = $IntMsgTable.HTPrintQueueAdOpenWebpage
	Description = $IntMsgTable.HDescPrintQueueAdOpenWebpage
	Progress = 0
	MandatorySource = "AD"
}

Export-ModuleMember -Variable IntMsgTable
Export-ModuleMember -Variable PHPrintQueueAdMemberOf, PHPrintQueueAdportName

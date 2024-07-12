<#
.Synopsis Property handlers for directory info objects
.Description A collection of objects, as property handlers, to operate on objects with objectclass 'DirectoryInfo'
.State Prod
.Author Smorkster (smorkster)
#>

param ( $culture = "sv-SE" )

$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.Parent.FullName

Import-LocalizedData -BindingVariable IntMsgTable -UICulture $culture -FileName "$( ( $PSCommandPath.Split( "\" ) | Select-Object -Last 1 ).Split( "." )[0] ).psd1" -BaseDirectory "$RootDir\Localization"

# Handler to open directory in Explorer
$PHDirectoryInfoADFullName = [pscustomobject]@{
	Code = '
	explorer $syncHash.Data.SearchedItem.FullName
	'
	Title = $IntMsgTable.HTDirectoryInfoADFullName
	Description = $IntMsgTable.HDescDirectoryInfoADFullName
	Progress = 0
	MandatorySource = "Other"
}

# Handler to list directory content
$PHDirectoryInfoOtherDirectoryInventory = [pscustomobject]@{
	Code = '
	$NewPropValue = [System.Collections.ArrayList]::new()
	Get-ChildItem $SenderObject.DataContext.Value.FullName | `
		Select-Object Name, Attributes | `
		ForEach-Object {
			$NewPropValue.Add( $_ ) | Out-Null
		}
	'
	Title = $IntMsgTable.HTDirectoryInfoOtherDirectoryInventory
	Description = $IntMsgTable.HDescDirectoryInfoOtherDirectoryInventory
	Progress = 0
	MandatorySource = "Other"
}

Export-ModuleMember -Variable IntMsgTable
Export-ModuleMember -Variable PHDirectoryInfoOtherDirectoryInventory, PHDirectoryInfoADFullName

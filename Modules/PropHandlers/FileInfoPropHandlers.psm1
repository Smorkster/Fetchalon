<#
.Synopsis Property handlers for file info objects
.Description A collection of objects, as property handlers, to operate on objects with objectclass 'FileInfo'
.State Prod
.Author Smorkster (smorkster)
#>

param ( $culture = "sv-SE" )

$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.Parent.FullName

Import-LocalizedData -BindingVariable IntMsgTable -UICulture $culture -FileName "$( ( $PSCommandPath.Split( "\" ) | Select-Object -Last 1 ).Split( "." )[0] ).psd1" -BaseDirectory "$RootDir\Localization"

# Handler to open file
$FullName = [pscustomobject]@{
	Code = 'explorer $syncHash.Data.SearchedItem.FullName'
	Title = $IntMsgTable.HTOpenFile
	Description = $IntMsgTable.HDescOpenFile
	Progress = 0
	MandatorySource = "AD"
}

Export-ModuleMember -Variable DirectoryInventory

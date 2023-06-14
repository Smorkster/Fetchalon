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
$PHDirectoryInfoOtherDirectoryInventory = [pscustomobject]@{
	Code = 'explorer $syncHash.Data.SearchedItem.FullName'
	Title = $IntMsgTable.HTDirectoryInfoOtherOpenDirectory
	Description = $IntMsgTable.HDescDirectoryInfoOtherOpenDirectory
	Progress = 0
	MandatorySource = "Other"
}

# Handler to turn WritePermissions-list to more readble names
$PHDirectoryInfoOtherWritePermissions = [pscustomobject]@{
	Code = 'try {
		$List = [System.Collections.ArrayList]::new()
		$SenderObject.DataContext.Value | Get-ADObject -ErrorAction SilectlyContinue | Select-Object -ExpandProperty Name | Sort-Object | ForEach-Object { $List.Add( $_ ) | Out-Null }
	} catch {}
	if ( $List.Count -gt 0 )
	{
		$SenderObject.DataContext.Value = $List
		$syncHash.IcPropsList.Items.Refresh()
	}'
	Title = $IntMsgTable.HTDirectoryInfoOtherWritePermissions
	Description = $IntMsgTable.HDescDirectoryInfoOtherWritePermissions
	Progress = 0
	MandatorySource = "Other"
}

# Handler to turn ReadPermissions-list to more readble names
$PHDirectoryInfoOtherReadPermissions = [pscustomobject]@{
	Code = '
	$syncHash.Data.Test = $SenderObject
	try {
		$List = [System.Collections.ArrayList]::new()
		$SenderObject.DataContext.Value | Get-ADObject -ErrorAction SilectlyContinue | Select-Object -ExpandProperty Name | Sort-Object | ForEach-Object { $List.Add( $_ ) | Out-Null }
	} catch {}
	if ( $List.Count -gt 0 )
	{
		$SenderObject.DataContext.Value = $List
		$syncHash.IcPropsList.Items.Refresh()
	}'
	Title = $IntMsgTable.HTDirectoryInfoOtherReadPermissions
	Description = $IntMsgTable.HDescDirectoryInfoOtherReadPermissions
	Progress = 0
	MandatorySource = "Other"
}

Export-ModuleMember -Variable PHDirectoryInfoOtherDirectoryInventory, PHDirectoryInfoOtherReadPermissions, PHDirectoryInfoOtherWritePermissions

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

# Handler to turn WritePermissions-list to more readble names
$WritePermissions = [pscustomobject]@{
	Code = 'try {
		$List = [System.Collections.ArrayList]::new()
		$SenderObject.DataContext.Value | Get-ADObject -ErrorAction SilectlyContinue | Select-Object -ExpandProperty Name | Sort-Object | ForEach-Object { $List.Add( $_ ) | Out-Null }
	} catch {}
	if ( $List.Count -gt 0 )
	{
		$SenderObject.DataContext.Value = $List
		$syncHash.IcPropsList.Items.Refresh()
	}'
	Title = $IntMsgTable.HTWritePermissions
	Description = $IntMsgTable.HDescWritePermissions
	Progress = 0
	MandatorySource = "Other"
}

# Handler to turn ReadPermissions-list to more readble names
$ReadPermissions = [pscustomobject]@{
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
	Title = $IntMsgTable.HTReadPermissions
	Description = $IntMsgTable.HDescReadPermissions
	Progress = 0
	MandatorySource = "Other"
}

Export-ModuleMember -Variable FullName, WritePermissions, ReadPermissions

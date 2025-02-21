<#
.Synopsis
	Property handlers for file info objects
.Description
	A collection of objects, as property handlers, to operate on objects with objectclass 'FileInfo'
.State
	Prod
.Author
	Smorkster (smorkster)
#>

param ( $culture = "sv-SE" )

$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.Parent.FullName

Import-LocalizedData -BindingVariable IntMsgTable -UICulture $culture -FileName "$( ( $PSCommandPath.Split( "\" ) | Select-Object -Last 1 ).Split( "." )[0] ).psd1" -BaseDirectory "$RootDir\Localization"

# Handler to open file
$PHFileInfoAdFullName = [pscustomobject]@{
	Code = 'explorer $SearchedItem.AD.FullName'
	Title = $IntMsgTable.HTFileInfoAdOpenFile
	Description = $IntMsgTable.HDescFileInfoAdOpenFile
	Progress = 0
	MandatorySource = "AD"
}

# Handler to turn WritePermissions-list to more readble names
$PHFileInfoOtherWritePermissions = [pscustomobject]@{
	Code = 'try {
		$NewPropValue = [System.Collections.ArrayList]::new()
		$SenderObject.DataContext.Value | Get-ADObject -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name | Sort-Object | ForEach-Object { $NewPropValue.Add( $_ ) | Out-Null }
	}
	catch
	{}
	'
	Title = $IntMsgTable.HTFileInfoOtherWritePermissions
	Description = $IntMsgTable.HDescFileInfoOtherWritePermissions
	Progress = 0
	MandatorySource = "Other"
}

# Handler to turn ReadPermissions-list to more readble names
$PHFileInfoOtherReadPermissions = [pscustomobject]@{
	Code = '
	try {
		$NewPropValue = [System.Collections.ArrayList]::new()
		$SenderObject.DataContext.Value | Get-ADObject -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name | Sort-Object | ForEach-Object { $NewPropValue.Add( $_ ) | Out-Null }
	}
	catch
	{}
	'
	Title = $IntMsgTable.HTFileInfoOtherReadPermissions
	Description = $IntMsgTable.HDescFileInfoOtherReadPermissions
	Progress = 0
	MandatorySource = "Other"
}

Export-ModuleMember -Variable IntMsgTable
Export-ModuleMember -Variable PHFileInfoAdFullName, PHFileInfoOtherReadPermissions, PHFileInfoOtherWritePermissions

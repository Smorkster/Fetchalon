<#
.Synopsis Property handlers for group objects
.Description A collection of objects, as property handlers, to operate on objects with objectclass 'group'
.State Prod
.Author Smorkster (smorkster)
#>

param ( $culture = "sv-SE" )

$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.Parent.FullName

Import-LocalizedData -BindingVariable IntMsgTable -UICulture $culture -FileName "$( ( $PSCommandPath.Split( "\" ) | Select-Object -Last 1 ).Split( "." )[0] ).psd1" -BaseDirectory "$RootDir\Localization"

# Handler to turn MemberOf-list to more readble strings
$PHGroupAdMemberOf = [pscustomobject]@{
	Code = '$List = [System.Collections.ArrayList]::new()
	$SenderObject.DataContext.Value | Get-ADGroup | Select-Object -ExpandProperty Name | Sort-Object | ForEach-Object { $List.Add( $_ ) | Out-Null }
	$SenderObject.DataContext.Value = $List
	$syncHash.IcPropsList.Items.Refresh()'
	Title = $IntMsgTable.HTGroupAdMemberOf
	Description = $IntMsgTable.HDescGroupAdMemberOf
	Progress = 0
	MandatorySource = "AD"
}

# Handler to turn Members-list to more readble strings
$PHGroupAdMembers = [pscustomobject]@{
	Code = '$List = [System.Collections.ArrayList]::new()
	$SenderObject.DataContext.Value | Get-ADObject | Select-Object -ExpandProperty Name | Sort-Object | ForEach-Object { $List.Add( $_ ) | Out-Null }
	$SenderObject.DataContext.Value = $List
	$syncHash.IcPropsList.Items.Refresh()'
	Title = $IntMsgTable.HTGroupAdMembers
	Description = $IntMsgTable.HDescGroupAdMembers
	Progress = 0
	MandatorySource = "AD"
}

Export-ModuleMember -Variable PHGroupAdMemberOf, PHGroupAdMembers

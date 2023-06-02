﻿<#
.Synopsis Property handlers for user objects
.Description A collection of objects, as property handlers, to operate on objects with objectclass 'user'
.State Prod
.Author Smorkster (smorkster)
#>

param ( $culture = "sv-SE" )

$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.Parent.FullName

Import-LocalizedData -BindingVariable IntMsgTable -UICulture $culture -FileName "$( ( $PSCommandPath.Split( "\" ) | Select-Object -Last 1 ).Split( "." )[0] ).psd1" -BaseDirectory "$RootDir\Localization"

# Handler to open a users homedirectory in explorer
$HomeDirectory = [pscustomobject]@{
	Code = 'explorer $SenderObject.DataContext.Value'
	Title = $IntMsgTable.HTOpenHomeDirectory
	Description = $IntMsgTable.HDescOpenHomeDirectory
	Progress = 0
	MandatorySource = "AD"
}

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

Export-ModuleMember -Variable HomeDirectory, MemberOf
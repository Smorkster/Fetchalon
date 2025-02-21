<#
.Synopsis
	Property handlers for group objects
.Description
	A collection of objects, as property handlers, to operate on objects with objectclass 'group'
.State
	Prod
.Author
	Smorkster (smorkster)
#>

param ( $culture = "sv-SE" )

$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.Parent.FullName

Import-LocalizedData -BindingVariable IntMsgTable -UICulture $culture -FileName "$( ( $PSCommandPath.Split( "\" ) | Select-Object -Last 1 ).Split( "." )[0] ).psd1" -BaseDirectory "$RootDir\Localization"

# Handler to turn MemberOf-list to more readble strings
$PHGroupAdMemberOf = [pscustomobject]@{
	Code = '
	$NewPropValue = [System.Collections.ArrayList]::new()
	$SenderObject.DataContext.Value | Get-ADGroup | Select-Object -ExpandProperty Name | Sort-Object | ForEach-Object { $NewPropValue.Add( $_ ) | Out-Null }
	'
	Title = $IntMsgTable.HTGroupAdMemberOf
	Description = $IntMsgTable.HDescGroupAdMemberOf
	Progress = 0
	MandatorySource = "AD"
}

# Handler to turn Members-list to more readble strings
$PHGroupAdMembers = [pscustomobject]@{
	Code = '
	$NewPropValue = [System.Collections.ArrayList]::new()
	$SenderObject.DataContext.Value | Get-ADObject | Select-Object -ExpandProperty Name | Sort-Object | ForEach-Object { $NewPropValue.Add( $_ ) | Out-Null }
	'
	Title = $IntMsgTable.HTGroupAdMembers
	Description = $IntMsgTable.HDescGroupAdMembers
	Progress = 0
	MandatorySource = "AD"
}

$PHGroupOtherHasWritePermission = [pscustomobject]@{
	Code = '
	if ( $syncHash.APGM.DistinguishedName.Count -eq 0 )
	{
		$NewPropValue = $PropLocalization.PLGroupOtherHasWritePermissionStrGrpCollectionNotReady
	}
	else
	{
		$PermGrps = [System.Collections.ArrayList]::new()
		( Get-Acl "AD:$( $SearchedItem.AD.DistinguishedName )" ).Access | `
			Where-Object { $_.IdentityReference -match $PropLocalization.PLGroupOtherHasWritePermissionCodeIdentityReference } | `
			ForEach-Object {
				try
				{
					( Get-ADGroup -LDAPFilter "(Name=$( ( $_.IdentityReference -split "\\" )[1] ))" -Properties member -ErrorAction Stop ).member | `
						Where-Object { $_ -in $syncHash.APGM.DistinguishedName } | `
						ForEach-Object {
							$PermGrps.Add( $_ ) | Out-Null
						}
				}
				catch {}
			}
		if ( $PermGrps.Count -gt 0 )
		{
			$NewPropValue = $PropLocalization.PLGroupOtherHasWritePermissionStrHasWritePermission
		}
		else
		{
			$NewPropValue = $PropLocalization.PLGroupOtherHasWritePermissionStrDoesNotHaveWritePermission
		}
	}
	'
	Title = $IntMsgTable.HTGroupOtherHasWritePermission
	Description = $IntMsgTable.HDescGroupOtherHasWritePermission
	Progress = 0
	MandatorySource = "Other"
}

Export-ModuleMember -Variable IntMsgTable
Export-ModuleMember -Variable PHGroupAdMemberOf, PHGroupAdMembers, PHGroupOtherHasWritePermission

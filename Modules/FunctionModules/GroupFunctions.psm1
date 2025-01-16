<#
.Synopsis
	A collection of functions to run for a group object
.Description
	A collection of functions to run for a group object
.ObjectClass
	Group
.State
	Prod
.Author
	Smorkster (smorkster)
#>

param ( $culture = "sv-SE" )

function Get-OrgGroupByOrgId
{
	<#
	.Synopsis
		Get AD-group for unit by CostCenter id
	.Description
		Search for unit CostCenter id and list any AD-groups.
	.MenuItem
		Search AD-group by CostCenter id
	.SearchedItemRequest
		None
	.InputData
		Id, True, Id or name to be searched for, only enter one id/name.
	.OutputType
		ObjectList
	.State
		Prod
	.Author
		Smorkster (smorkster)
	#>

	param ( $InputData )

	$FoundGroups = [System.Collections.ArrayList]::new()

	try
	{
		$Res = Get-ADGroup -LDAPFilter "(&(objectclass=group)($( $IntMsgTable.GetOrgGroupByOrgIdCodeOrgIdPropName )=$( $IntMsgTable.GetOrgGroupByOrgIdCodeOrgIdPropPrefix )-$( $InputData.Id )))" -Properties *
		if ( $null -eq $Res )
		{
			$Res = Get-ADGroup -LDAPFilter "(&(objectclass=group)(Name=*$( $InputData.Id )*))" -Properties *
		}


		if ( $null -ne $Res )
		{
			$Res | `
				Select-Object -Property `
					Name, `
					@{ Name = ( $IntMsgTable.GetOrgGroupByOrgIdCodePropTitleId )
						Expression = { $_.( $IntMsgTable.GetOrgGroupByOrgIdCodeOrgIdPropName ) -replace "$( $IntMsgTable.GetOrgGroupByOrgIdCodeOrgIdPropPrefix )-", "" } }, `
					@{ Name = ( $IntMsgTable.GetOrgGroupByOrgIdCodeOrgIdPropNameOrgDN )
						Expression = { $_."$( $IntMsgTable.GetOrgGroupByOrgIdCodeOrgIdPropNameOrgDN )" } } | `
				ForEach-Object {
					$FoundGroups.Add( ( $_ | Select-Object * ) ) | Out-Null
				}
			return $FoundGroups
		}
		else
		{
			throw "$( $IntMsgTable.GetOrgGroupByOrgIdErrNotFound ) '$( $InputData.Id )'"
		}
	}
	catch
	{
		throw "$( $IntMsgTable.GetOrgGroupByOrgIdGenErr )`n$( $_ )"
	}
}

$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.Parent.FullName

Import-LocalizedData -BindingVariable IntMsgTable -UICulture $culture -FileName "$( ( $PSCommandPath.Split( "\" ) | Select-Object -Last 1 ).Split( "." )[0] ).psd1" -BaseDirectory "$RootDir\Localization"

Export-ModuleMember -Function Get-OrgGroupByOrgId

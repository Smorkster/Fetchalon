<#
.Synopsis
	Property handlers for computer objects
.Description
	A collection of objects, as property handlers, to operate on objects with objectclass 'computer'
.State
	Prod
.Author
	Smorkster (smorkster)
#>

param ( $culture = "sv-SE" )

$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.Parent.FullName

Import-LocalizedData -BindingVariable IntMsgTable -UICulture $culture -FileName "$( ( $PSCommandPath.Split( "\" ) | Select-Object -Last 1 ).Split( "." )[0] ).psd1" -BaseDirectory "$RootDir\Localization"

# Handler to turn MemberOf-list to more readable strings
$PHComputerAdMemberOf = [pscustomobject]@{
	Code = '
		$NewPropValue = [System.Collections.ArrayList]::new()
		$SenderObject.DataContext.Value | `
			Get-ADGroup | `
			Select-Object -ExpandProperty Name | `
			Sort-Object | `
			ForEach-Object {
				$NewPropValue.Add( $_ ) | Out-Null
			}
	'
	Title = $IntMsgTable.HTComputerAdMemberOf
	Description = $IntMsgTable.HDescComputerAdMemberOf
	Progress = [System.Windows.Visibility]::Hidden
	MandatorySource = "AD"
}

# Get computers listed at same costcenter
$PHComputerAdOrgCostNo = [pscustomobject]@{
	Code = '
		$NewPropValue = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
		Get-ADComputer -LDAPFilter "($( $SenderObject.DataContext.Name )=$( $SenderObject.DataContext.Value[0] ))" -Properties Name, $SenderObject.DataContext.Name | `
			ForEach-Object {
				$OFS = ", "
				"$( $_.Name ) $( $_."$( $SenderObject.DataContext.Name )" )"
			} | `
			Sort-Object | `
			ForEach-Object {
				$NewPropValue.Add( $_ ) | Out-Null
			}
	'
	Title = $IntMsgTable.HTComputerAdOrgCostNo
	Description = $IntMsgTable.HDescComputerAdOrgCostNo
	MandatorySource = "AD"
}

# Check if computer is online
$PHComputerOtherIsOnline = [pscustomobject]@{
	Code = '
		try
		{
			Get-CimInstance -ClassName win32_operatingsystem -ComputerName $SearchedItem.AD.Name -ErrorAction Stop -OperationTimeoutSec 3 -Shallow -KeyOnly | Out-Null
			$NewPropValue = $PropLocalization.PLComputerOtherIsOnlineStrOnline
		}
		catch
		{
			$NewPropValue = $PropLocalization.PLComputerOtherIsOnlineStrOffline
		}
	'
	Title = $IntMsgTable.HTComputerOtherCheckOnline
	Description = $IntMsgTable.HDescComputerOtherCheckOnline
	MandatorySource = "Other"
}

# Get sharedaccount connected to computer
$PHComputerOtherSharedAccount = [pscustomobject]@{
	Code = '
		$NewPropValue = Get-ADUser -LDAPFilter "(&(Name=F$( $SearchedItem.Other.Organisation )*)(userWorkstations=$( $SearchedItem.AD.Name )))"
	'
	Title = $IntMsgTable.HTComputerOtherSharedAccount
	Description = $IntMsgTable.HDescComputerOtherSharedAccount
	Progress = 0.0
	MandatorySource = "Other"
}

Export-ModuleMember -Variable IntMsgTable
Export-ModuleMember -Variable PHComputerAdMemberOf, PHComputerAdOrgCostNo, PHComputerOtherIsOnline, PHComputerOtherSharedAccount

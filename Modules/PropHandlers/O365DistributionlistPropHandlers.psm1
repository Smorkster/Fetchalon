<#
.Synopsis
	Property handlers for O365Distributionlist objects
.Description
	A collection of objects, as property handlers, to operate on objects with objectclass 'O365Distributionlist'
.State
	Prod
.Author
	Smorkster (Smorkster)
#>

param ( $culture = "sv-SE" )

$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.Parent.FullName

Import-LocalizedData -BindingVariable IntMsgTable -UICulture $culture -FileName "$( ( $PSCommandPath.Split( "\" ) | Select-Object -Last 1 ).Split( "." )[0] ).psd1" -BaseDirectory "$RootDir\Localization"

# Toggle setting for external senders to distributionlist
$PHO365DistributionlistDistGroupRequireSenderAuthenticationEnabled = [pscustomobject]@{
	Code = 'Set-DistributionGroup -Identity $syncHash.Data.SearchedItem.PrimarySmtpAddress -RequireSenderAuthenticationEnabled ( -not $syncHash.Data.SearchedItem.ExtraInfo.DistGroup.RequireSenderAuthenticationEnabled )'
	Title = $IntMsgTable.HTO365DistributionlistDistGroupRequireSenderAuthenticationEnabled
	Description = $IntMsgTable.HDescO365DistributionlistDistGroupRequireSenderAuthenticationEnabled
	Progress = 0
	MandatorySource = "DistGroup"
}

Export-ModuleMember -Variable PHO365DistributionlistDistGroupRequireSenderAuthenticationEnabled

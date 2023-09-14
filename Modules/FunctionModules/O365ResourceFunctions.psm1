<#
.Synopsis
	A collection of functions to operate with Office365-resources
.Description
	A collection of functions to operate with Office365-resources
.State
	Prod
.Author
	Smorkster (smorkster)
#>

param ( $culture = "sv-SE" )

function Get-ResourceMembers
{
	<#
	.Synopsis
		Get who can book
	.Description
		List the users who can book the resource
	.MenuItem
		Get bookers
	.SearchedItemRequest
		Required
	.ObjectClass
		O365Resource
	.OutputType
		ObjectList
	.State
		Prod
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item )

	$Members = [System.Collections.ArrayList]::new()

	Get-AzureADGroup -SearchString "RES-$( $Item.Name )-Admins" | `
		Get-AzureADGroupMember | `
			Where-Object { $_.ObjectType -ne "Group" } | `
			Select-Object -Property DisplayName, UserPrincipalName, @{ Name = "$( $IntMsgTable.GetResourceMembersParamPermName )" ; Expression = { "$( $IntMsgTable.GetResourceMembersParamPermAdmin )" } } | `
			Sort-Object DisplayName | `
			ForEach-Object {
				$Members.Add( $_ ) | Out-Null
			}

	Get-AzureADGroup -SearchString "RES-$( $Item.Name )-Book" | `
		Get-AzureADGroupMember | `
			Select-Object -Property DisplayName, UserPrincipalName, @{ Name = "$( $IntMsgTable.GetResourceMembersParamPermName )" ; Expression = { "$( $IntMsgTable.GetResourceMembersParamPermBook )" } } | `
			Sort-Object DisplayName | `
			ForEach-Object {
				$Members.Add( $_ ) | Out-Null
			}

	if ( $Members.Count -gt 0 )
	{
		return $Members
	}
	else
	{
		return $IntMsgTable.GetResourceMembersNoMembers
	}
}

function Set-ResMailTip
{
	<#
	.Synopsis
		Set mailtip
	.Description
		Set mailtip for the resource
	.MenuItem
		Set mailtip
	.InputData
		MailTip Text to be displayed as a mailtip, maximum length 175 characters
	.SearchedItemRequest
		Required
	.ObjectClass
		O365Resource
	.OutputType
		String
	.State
		Prod
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item, $InputData )

	try
	{
		Set-Mailbox $Item.PrimarySmtpAddress -MailTip $InputData.MailTip
		return $IntMsgTable.SetResMailTipDone
	}
	catch
	{
		throw "$( $IntMsgTable.SetResMailTipError ):`n$( $_.Exception.Message )"
	}
}

$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.Parent.FullName

Import-LocalizedData -BindingVariable IntMsgTable -UICulture $culture -FileName "$( ( $PSCommandPath.Split( "\" ) | Select-Object -Last 1 ).Split( "." )[0] ).psd1" -BaseDirectory "$RootDir\Localization"

Export-ModuleMember -Function Get-ResourceMembers
Export-ModuleMember -Function Set-ResMailTip

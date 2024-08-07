<#
.Synopsis
	A collection of functions to operate with Office365-distributionlists
.Description
	A collection of functions to operate with Office365-distributionlists
.State
	Prod
.Author
	Smorkster (smorkster)
#>

param ( $culture = "sv-SE" )

function Get-DLMembers
{
	<#
	.Synopsis
		Get members for distribution list
	.Description
		Get members for distribution list
	.MenuItem
		Get members
	.SearchedItemRequest
		Required
	.ObjectClass
		O365Distributionlist
	.OutputType
		ObjectList
	.State
		Prod
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item )

	$Members = [System.Collections.ArrayList]::new()
	Get-AzureADGroup -SearchString "DL-$( $Item.DisplayName )" | `
		Get-AzureADGroupMember | `
			Where-Object { $_.ObjectType -ne "Group" } | `
			Sort-Object DisplayName | `
			Select-Object -Property DisplayName, UserPrincipalName, @{ Name = "$( $IntMsgTable.GetDLMembersParamPermName )" ; Expression = { "Admin" } } | `
			ForEach-Object {
				$Members.Add( $_ ) | Out-Null
			}
	Get-AzureADGroup -SearchString "$( $Item.DisplayName )" | `
		Get-AzureADGroupMember | `
			Where-Object { $_.ObjectType -ne "Group" } | `
			Sort-Object DisplayName | `
			Select-Object -Property DisplayName, UserPrincipalName, @{ Name = "$( $IntMsgTable.GetDLMembersParamPermName )" ; Expression = { "$( $IntMsgTable.GetDLMembersParamPermReceiver )" } } | `
			ForEach-Object {
				$Members.Add( $_ ) | Out-Null
			}

	if ( 0 -eq $Members.Count )
	{
		return $IntMsgTable.GetDLMembersNoMembers
	}
	else
	{
		return $Members
	}
}

function Set-DLMailTip
{
	<#
	.Synopsis
		Set mailtip
	.Description
		Set mailtip for the distributionlist
	.MenuItem
		Set mailtip
	.InputData
		MailTip, , Text to be displayed as a mailtip, maximum length 175 characters
	.SearchedItemRequest
		Required
	.ObjectClass
		O365Distributionlist
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
		return $IntMsgTable.SetDLMailTipDone
	}
	catch
	{
		throw "$( $IntMsgTable.SetDLMailTipError ):`n$( $_.Exception.Message )"
	}
}

$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.Parent.FullName

Import-LocalizedData -BindingVariable IntMsgTable -UICulture $culture -FileName "$( ( $PSCommandPath.Split( "\" ) | Select-Object -Last 1 ).Split( "." )[0] ).psd1" -BaseDirectory "$RootDir\Localization"

Export-ModuleMember -Function Get-DLMembers
Export-ModuleMember -Function Set-DLMailTip

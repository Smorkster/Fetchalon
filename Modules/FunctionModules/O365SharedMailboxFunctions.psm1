<#
.Synopsis
	A collection of functions to operate with Office365-sharedmailboxes
.Description
	A collection of functions to operate with Office365-sharedmailboxes
.State
	Prod
.Author
	Smorkster (smorkster)
#>

param ( $culture = "sv-SE" )

function Get-SMMembers
{
	<#
	.Synopsis
		Get members
	.Description
		Retrieve users who have access to the feature mailbox
	.MenuItem
		Get members
	.SearchedItemRequest
		Required
	.ObjectClass
		O365SharedMailbox
	.OutputType
		ObjectList
	.State
		Prod
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item )

	$Members = [System.Collections.ArrayList]::new()
	Get-AzureADGroup -SearchString "MB-$( $Item.DisplayName )-Admins" | `
		Get-AzureADGroupMember | `
			Where-Object { $_.ObjectType -ne "Group" } | `
			Select-Object -Property DisplayName, UserPrincipalName, @{ Name = "$( $IntMsgTable.GetSMMembersParamPermName )" ; Expression = { "Admins" } } | `
			ForEach-Object {
				$Members.Add( $_ ) | Out-Null
			}

	Get-AzureADGroup -SearchString "MB-$( $Item.DisplayName )-Full" | `
		Get-AzureADGroupMember | `
			Where-Object { $_.ObjectType -ne "Group" } | `
			Select-Object -Property DisplayName, UserPrincipalName, @{ Name = "$( $IntMsgTable.GetSMMembersParamPermName )" ; Expression = { "Full" } } | `
			ForEach-Object {
				$Members.Add( $_ ) | Out-Null
			}

	Get-AzureADGroup -SearchString "MB-$( $Item.DisplayName )-Read" | `
		Get-AzureADGroupMember | `
			Where-Object { $_.ObjectType -ne "Group" } | `
			Select-Object -Property DisplayName, UserPrincipalName, @{ Name = "$( $IntMsgTable.GetSMMembersParamPermName )" ; Expression = { "Read" } } | `
			ForEach-Object {
				$Members.Add( $_ ) | Out-Null
			}

	if ( 0 -eq $Members.Count )
	{
		return $IntMsgTable.GetSMMembersNoMembers
	}
	else
	{
		return $Members
	}
}

function Set-SMMailTip
{
	<#
	.Synopsis
		Set mailtip
	.Description
		Set mailtip for the shared mailbox
	.MenuItem
		Set mailtip
	.InputData
		MailTip, , Text to be displayed as a mailtip, maximum length 175 characters
	.SearchedItemRequest
		Required
	.ObjectClass
		O365SharedMailbox
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
		return $IntMsgTable.SetSMMailTipDone
	}
	catch
	{
		throw "$( $IntMsgTable.SetSMMailTipError ):`n$( $_.Exception.Message )"
	}
}

$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.Parent.FullName

Import-LocalizedData -BindingVariable IntMsgTable -UICulture $culture -FileName "$( ( $PSCommandPath.Split( "\" ) | Select-Object -Last 1 ).Split( "." )[0] ).psd1" -BaseDirectory "$RootDir\Localization"

Export-ModuleMember -Function Get-SMDelegates, Get-SMMembers, Get-SMUnsynced
Export-ModuleMember -Function Set-SMMailTip

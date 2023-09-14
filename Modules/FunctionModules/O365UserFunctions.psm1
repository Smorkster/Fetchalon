<#
.Synopsis
	A collection of functions to operate with Office365-users
.Description
	A collection of functions to operate with Office365-users
.State
	Prod
.Author
	Smorkster (smorkster)
#>

param ( $culture = "sv-SE" )

function Get-ExoMail
{
	<#
	.Synopsis
		Get ExoMailbox
	.Description
		Get ExoMailbox
	.MenuItem
		Get ExoMailbox
	.SearchedItemRequest
		Required
	.ObjectClass
		user
	.OutputType
		ObjectList
	.State
		Prod
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item )

	return Get-EXOMailbox $Item.Name | Select-Object *
}

function Get-UserDevices
{
	<#
	.Synopsis
		List devices connected to the user
	.Description
		List the devices the user used to connect their Office 365 account
	.MenuItem
		List devices
	.SearchedItemRequest
		Required
	.ObjectClass
		O365User
	.OutputType
		ObjectList
	.State
		Prod
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item )

	return Get-AzureADUserRegisteredDevice -ObjectId $Item.ExternalDirectoryObjectId | `
		Select-Object DisplayName, ObjectId, ApproximateLastLogonTimeStamp, DeviceId, DeviceOSType, DeviceOSVersion
}

function Get-Delegates
{
	<#
	.Synopsis
		Get delegates for the mailbox
	.Description
		List the people who have been granted access to act as proxies for the inbox
	.MenuItem
		Get delegates
	.SearchedItemRequest
		Required
	.ObjectClass
		O365User
	.OutputType
		ObjectList
	.State
		Prod
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item )

	$Delegates = [System.Collections.ArrayList]::new()

	Get-MailboxFolderPermission -Identity "$( $syncHash.data.SearchedItem.PrimarySmtpAddress ):\$( $IntMsgTable.GetDelegatesInbox )" | `
		Where-Object { $_.User -notin "Standard","Anonymous","Default" } | `
		Select-Object -Property @{ Name = "$( $IntMsgTable.GetDelegatesUser )" ; Expression = { "$( $_.User.DisplayName ) ($( $_.User.RecipientPrincipal.PrimarySmtpAddress ))"} } ,
				@{ Name = "$( $IntMsgTable.GetDelegatesPermissions )" ; Expression = { $_.AccessRights -join ", " } },
				@{ Name = "$( $IntMsgTable.GetDelegatesFolder )" ; Expression = { $_.FolderName } } | `
		ForEach-Object {
			$Delegates.Add( $_ ) | Out-Null
		}

	Get-MailboxFolderPermission -Identity "$( $syncHash.data.SearchedItem.PrimarySmtpAddress ):\$( $IntMsgTable.GetDelegatesCalendar )" | `
		Where-Object { $_.User -notin "Standard","Anonymous","Default" } | `
		Select-Object -Property @{ Name = "$( $IntMsgTable.GetDelegatesUser )" ; Expression = { "$( $_.User.DisplayName ) ($( $_.User.RecipientPrincipal.PrimarySmtpAddress ))"} } ,
				@{ Name = "$( $IntMsgTable.GetDelegatesPermissions )" ; Expression = { $_.AccessRights -join ", " } },
				@{ Name = "$( $IntMsgTable.GetDelegatesFolder )" ; Expression = { $_.FolderName } } | `
		ForEach-Object {
			$Delegates.Add( $_ ) | Out-Null
		}

	if ( 0 -eq $Delegates.Count )
	{
		return $IntMsgTable.GetDelegatesNoDelegates
	}
	else
	{
		return $Delegates
	}
}

function Get-DistsMembership
{
	<#
	.Synopsis
		Get distribution list memberships
	.Description
		Get distribution list memberships
	.MenuItem
		Membership in distribution lists
	.SearchedItemRequest
		Required
	.ObjectClass
		O365User
	.OutputType
		ObjectList
	.State
		Prod
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item )

	$List = Get-AzureADUserMembership -ObjectId $Item.ExternalDirectoryObjectId  | Where-Object { $_.DisplayName -match "^DL-" }

	if ( 0 -eq @( $List ).Count )
	{
		return $IntMsgTable.GetDistsMembershipNoDistsMember
	}
	else
	{
		return $List | `
			Select-Object @{ Name = $IntMsgTable.GetDistsMembershipParamName ; Expression = { ( $_.DisplayName -replace "^DL-" -split "-" | Select-Object -SkipLast 1 ) -join "" } } ,
			@{ Name = $IntMsgTable.GetDistsMembershipParamMemberType ; Expression = { if ( "Admins" -eq ( $_.DisplayName -split "-" | Select-Object -Last 1 ) ) { $IntMsgTable.GetDistsMembershipParamAdmin } else { $IntMsgTable.GetDistsMembershipParamReceiver } } }
	}
}

function Get-DistsOwnership
{
	<#
	.Synopsis
		Get ownership of distribution lists
	.Description
		Get distribution lists the user is the owner of
	.MenuItem
		Ownership distribution lists
	.SearchedItemRequest
		Required
	.ObjectClass
		O365User
	.OutputType
		ObjectList
	.State
		Prod
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item )

	$List = Get-DistributionGroup -Filter "CustomAttribute10 -like '*$( ( $Item.PrimarySmtpAddress -split '@' )[0] )*'"

	if ( 0 -eq @( $List ).Count )
	{
		return $IntMsgTable.GetDistsOwnershipNoOwnerships
	}
	else
	{
		return $List | `
			Select-Object @{ Name = $IntMsgTable.GetDistsOwnershipParamName ; Expression = { $_.DisplayName } } ,
				@{ Name = $IntMsgTable.GetDistsOwnershipParamPrimarySmtpAddress ; Expression = { $_.PrimarySmtpAddress } }
	}
}

function Get-Logins
{
	<#
	.Synopsis
		Show logins
	.MenuItem
		Show logins
	.SearchedItemRequest
		Required
	.ObjectClass
		O365User
	.OutputType
		ObjectList
	.State
		Prod
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item )

	$LastLogon = ( Get-MailboxStatistics $Item.PrimarySmtpAddress ).LastLogonTime
	$Auditdata = Search-UnifiedAuditLog -StartDate ( ( [DateTime]::Today.AddDays( -10 ) ).ToUniversalTime() ) -EndDate ( ( [DateTime]::Now ).ToUniversalTime() ) -UserIds $Item.PrimarySmtpAddress -Operations "FileAccessed" -RecordType "SharePointFileOperation"
	$TeamsLogon = ( $Auditdata | Sort-Object CreationDate )[-1].CreationDate

	$List = [System.Collections.ArrayList]::new()
	$List.Add( ( [pscustomobject]@{ $IntMsgTable.GetLoginsParamName = "Office 365" ; $IntMsgTable.GetLoginsParamTime = "$( $LastLogon.ToShortDateString() ) $( $LastLogon.ToLongTimeString() )" } ) ) | Out-Null
	$List.Add( ( [pscustomobject]@{ $IntMsgTable.GetLoginsParamName = "Teams" ; $IntMsgTable.GetLoginsParamTime = "$( $TeamsLogon.ToShortDateString() ) $( $TeamsLogon.ToLongTimeString() )" } ) ) | Out-Null

	return $List
}

function Get-SharedMailboxMembership
{
	<#
	.Synopsis
		Get feature mailboxes membership
	.MenuItem
		Membership shared mailboxes
	.SearchedItemRequest
		Required
	.ObjectClass
		O365User
	.OutputType
		ObjectList
	.State
		Prod
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item )

	$List = [System.Collections.ArrayList]::new()

	try
	{
		Get-AzureADUser -SearchString $Item.Alias -ErrorAction Stop | `
			Get-AzureADUserMembership | `
			Where-Object { $_.DisplayName -match "^MB" } | `
			ForEach-Object {
				$Split = ( $_.DisplayName -replace "MB-" ) -split "-"
				$List.Add( ( [pscustomobject]@{ $IntMsgTable.GetSharedMailboxMembershipParamName = ( $Split | Select-Object -SkipLast 1 ) ; $IntMsgTable.GetSharedMailboxMembershipParamPerm = $Split[-1] } ) ) | Out-Null
			}
	}
	catch {}

	if ( 0 -eq $List.Count )
	{
		$List.Add( $IntMsgTable.GetSharedMailboxMembershipNoMembership ) | Out-Null
	}
	return $List
}

function Get-SharedMailboxOwnership
{
	<#
	.Synopsis
		Get shared mailboxes membership
	.MenuItem
		Membership shared mailboxes
	.SearchedItemRequest
		Required
	.ObjectClass
		O365User
	.OutputType
		ObjectList
	.State
		Prod
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item )

	$List = [System.Collections.ArrayList]::new()

	try
	{
		Get-EXOMailBox -Filter "CustomAttribute10 -like '*$( $Item.PrimarySmtpAddress )*'" -ErrorAction Stop | `
			Select-Object DisplayName, PrimarySmtpAddress | `
			Sort-Object DisplayName | `
			ForEach-Object {
				$List.Add( $_ ) | Out-Null
			}
	}
	catch {}

	if ( 0 -eq $List.Count )
	{
		$List.Add( ( $IntMsgTable.GetSharedMailboxOwnershipNoOwnership ) ) | Out-Null
	}
	return $List
}

function Set-UserMailTip
{
	<#
	.Synopsis
		Set mailtip
	.Description
		Set mailtip for the user
	.MenuItem
		Set mailtip
	.InputData
		MailTip Text to be displayed as a mailtip, maximum length 175 characters
	.SearchedItemRequest
		Required
	.ObjectClass
		O365User
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
		return $IntMsgTable.SetUserMailTipDone
	}
	catch
	{
		throw "$( $IntMsgTable.SetUserMailTipError ):`n$( $_.Exception.Message )"
	}
}

function Set-UserPasswordNeverExpires
{
	<#
	.Synopsis
		Sätt att giltighetstiden för lösenordet inte går ut
	.Description
		Sätter att giltighetstiden för lösenord på användares konto i Azure inte går ut.
	.MenuItem
		Sätt lösenord gåt inte ut
	.SearchedItemRequest
		Required
	.ObjectClass
		O365User
	.OutputType
		ObjectList
	.State
		Prod
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item )

	try
	{
		Set-AzureADUser -ObjectId $Item.ExternalDirectoryObjectId -PasswordPolicies DisablePasswordExpiration -ErrorAction Stop
	}
	catch
	{
		throw $_
	}
}

$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.Parent.FullName

Import-LocalizedData -BindingVariable IntMsgTable -UICulture $culture -FileName "$( ( $PSCommandPath.Split( "\" ) | Select-Object -Last 1 ).Split( "." )[0] ).psd1" -BaseDirectory "$RootDir\Localization"

Export-ModuleMember -Function Get-Delegates, Get-DistsMembership, Get-DistsOwnership, Get-ExoMail, Get-Logins, Get-SharedMailboxMembership, Get-SharedMailboxOwnership, Get-UserDevices
Export-ModuleMember -Function Set-UserMailTip, Set-UserPasswordNeverExpires

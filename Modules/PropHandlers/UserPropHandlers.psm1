<#
.Synopsis
	Property handlers for user objects
.Description
	A collection of objects, as property handlers, to operate on objects with objectclass 'user'
.State
	Prod
.Author
	Smorkster (smorkster)
#>

param ( $culture = "sv-SE" )

$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.Parent.FullName

Import-LocalizedData -BindingVariable IntMsgTable -UICulture $culture -FileName "$( ( $PSCommandPath.Split( "\" ) | Select-Object -Last 1 ).Split( "." )[0] ).psd1" -BaseDirectory "$RootDir\Localization"

# Handler to set a disabled account as enabled
$PHUserAdEnabled = [pscustomobject]@{
	Code = '
	$NewPropValue = $SearchedItem.AD.Enabled

	if ( $SearchedItem.AD.DistinguishedName -match $PropLocalization.PLUserAdEnabledCodeOrgMatch )
	{
		if ( $NewPropValue )
		{
			Show-Splash -Text $PropLocalization.PLUserAdEnabledStrAlreadyActive -NoProgressBar -NoTitle
		}
		elseif ( $SearchedItem.AD.Name -match $PropLocalization.PLUserAdEnabledCodeSharedAcc )
		{
			if ( $SearchedItem.AD.Enabled -eq $false )
			{
				Show-MessageBox -Text $PropLocalization.PLUserAdEnabledStrAlreadyActive -NoProgressBar -NoTitle
			}
			elseif ( $SearchedItem.AD.LockedOut )
			{
				Unlock-ADAccount -Identity $SearchedItem.AD.DistinguishedName -Confirm:$false
			}
		}
		else
		{
			if ( $SearchedItem.AD.info -match "$( $PropLocalization.PLUserAdEnabledStrDoNotActivate )" )
			{
				Show-Splash -Text $PropLocalization.PLUserAdEnabledStrAlreadyActive -NoProgressBar -Title $PropLocalization.PLUserAdEnabledMsgDoNotActivateTitle -Duration 3
			}
			elseif ( $SearchedItem.AD.accountExpires -ne $null )
			{
				try
				{
					$Expires = ( Get-ADUser $SearchedItem.AD.DistinguishedName -Properties accountExpires ).accountExpires
					if ( [DateTime]::FromFileTime( $Expires ) -lt ( Get-Date ) )
					{
						Show-Splash -Text $PropLocalization.PLUserAdEnabledStrAccountValidityExpired -NoProgressBar -Title $PropLocalization.PLUserAdEnabledStrAccountValidityExpiredTitle -Duration 3
					}
					else
					{
						if ( $SearchedItem.AD.LockedOut )
						{
							Unlock-ADAccount -Identity $SearchedItem.AD.DistinguishedName -Confirm:$false
							$NewPropValue = $true
						}
						elseif ( $SearchedItem.AD.Enabled -eq $false )
						{
							Unlock-ADAccount -Identity $SearchedItem.AD.DistinguishedName -Confirm:$false
							$NewPropValue = $true
						}
					}
				}
				catch
				{
					Show-MessageBox -Text "$( $PropLocalization.PLUserAdEnabledErrUnlocking )`n$( $_.Exception.Message )" | Out-Null
				}
			}
		}
	}
	else
	{
		Show-MessageBox -Text $PropLocalization.PLUserAdEnabledErrOrgMisMatch -Icon "Error" | Out-Null
	}
	'
	Title = $IntMsgTable.HTUserAdEnabled
	Description = $IntMsgTable.HDescUserAdEnabled
	Progress = 0
	MandatorySource = "AD"
}

# Handler to open a users homedirectory in explorer
$PHUserAdHomeDirectory = [pscustomobject]@{
	Code = 'explorer $SenderObject.DataContext.Value'
	Title = $IntMsgTable.HTUserAdOpenHomeDirectory
	Description = $IntMsgTable.HDescUserAdOpenHomeDirectory
	Progress = 0
	MandatorySource = "AD"
}

# Handler to turn MemberOf-list to more readble strings
$PHUserAdMemberOf = [pscustomobject]@{
	Code = '
	$NewPropValue = [System.Collections.ArrayList]::new()
	$SenderObject.DataContext.Value | Get-ADGroup | Select-Object -ExpandProperty Name | Sort-Object | ForEach-Object { $NewPropValue.Add( $_ ) | Out-Null }
	'
	Title = $IntMsgTable.HTUserAdMemberOf
	Description = $IntMsgTable.HDescUserAdMemberOf
	Progress = 0
	MandatorySource = "AD"
}

# Handler to check account status
$PHUserOtherAccountStatus = [pscustomobject]@{
	Code = '
	$NewPropValue = $SearchedItem.Other.AccountStatus

	if ( $SearchedItem.AD.info -match "$( $PropLocalization.PLUserOtherAccountStatusStrDoNotActivate )" )
	{
		$NewPropValue = $PropLocalization.PLUserOtherAccountStatusStrUserBlocked
	}
	elseif ( $SearchedItem.AD.accountExpires -ne $null )
	{
		if ( $SearchedItem.AD.LockedOut )
		{
			$NewPropValue = $PropLocalization.PLUserOtherAccountStatusStrLocked
		}
		elseif ( $SearchedItem.AD.Enabled -eq $false )
		{
			$NewPropValue = $PropLocalization.PLUserOtherAccountStatusStrUserDisabled
		}

		if ( $SearchedItem.AD.Description -match $PropLocalization.PLUserOtherAccountStatusCodeREDesc )
		{
			$NewPropValue = "$NewPropValue $( $SearchedItem.AD.Description )"
		}

		try
		{
			$Expires = ( Get-ADUser $SearchedItem.AD.DistinguishedName -Properties accountExpires ).accountExpires
			if ( -not ( $Expires -eq 0 -or $Expires -eq 9223372036854775807 ) )
			{
				if ( [DateTime]::FromFileTime( $Expires ) -lt ( Get-Date ) )
				{
					$NewPropValue = "$NewPropValue $( $PropLocalization.PLUserOtherAccountStatusStrAccountValidityExpired )"
				}
				else
				{
					$NewPropValue = "$( $PropLocalization.PLUserOtherAccountStatusStrAccountValidityDate ) $( ( [DateTime]::FromFileTime( $Expires ) ).ToString( "yyyy-MM-dd" ) )"
				}
			}
		}
		catch
		{
			
		}
	}
	'
	Title = $IntMsgTable.HTUserOtherAccountStatus
	Description = $IntMsgTable.HDescUserOtherAccountStatus
	Progress = 0
	MandatorySource = "Other"
	Author = "Smorkster (smorkster)"
	ValidStartDateTime = "2025-02-05 13:30"
}

Export-ModuleMember -Variable IntMsgTable
Export-ModuleMember -Variable PHUserAdEnabled, PHUserAdHomeDirectory, PHUserAdMemberOf, PHUserOtherAccountStatus

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

# Handler to open a users homedirectory in explorer
$PHUserAdEnabled = [pscustomobject]@{
	Code = '
	$NewPropValue = $SearchedItem.Enabled

	if ( $SearchedItem.DistinguishedName -match $PropLocalization.PLUserAdEnabledCodeOrgMatch )
	{
		if ( $NewPropValue )
		{
			Show-Splash -Text $PropLocalization.PLUserAdEnabledStrAlreadyActive -NoProgressBar -NoTitle
		}
		elseif ( $SearchedItem.Name -match $PropLocalization.PLUserAdEnabledCodeSharedAcc )
		{
			if ( $SearchedItem.Enabled -eq $false )
			{
				Show-MessageBox -Text $PropLocalization.PLUserAdEnabledStrAlreadyActive -NoProgressBar -NoTitle
			}
			elseif ( $SearchedItem.LockedOut )
			{
				Unlock-ADAccount -Identity $SearchedItem.DistinguishedName -Confirm:$false
			}
		}
		else
		{
			if ( $SearchedItem.info -match "$( $PropLocalization.PLUserAdEnabledStrDoNotActivate )" )
			{
				Show-Splash -Text $PropLocalization.PLUserAdEnabledStrAlreadyActive -NoProgressBar -Title $PropLocalization.PLUserAdEnabledMsgDoNotActivateTitle -Duration 3
			}
			elseif ( $SearchedItem.accountExpires -ne $null )
			{
				try
				{
					$Expires = ( Get-ADUser $SearchedItem -Properties accountExpires ).accountExpires
					if ( [DateTime]::FromFileTime( $Expires ) -lt ( Get-Date ) )
					{
						Show-Splash -Text $PropLocalization.PLUserAdEnabledStrAccountValidityExpired -NoProgressBar -Title $PropLocalization.PLUserAdEnabledStrAccountValidityExpiredTitle -Duration 3
					}
					else
					{
						if ( $SearchedItem.LockedOut )
						{
							Unlock-ADAccount -Identity $SearchedItem.DistinguishedName -Confirm:$false
							$NewPropValue = $true
						}
						elseif ( $SearchedItem.Enabled -eq $false )
						{
							Unlock-ADAccount -Identity $SearchedItem.DistinguishedName -Confirm:$false
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
	$NewPropValue = $SearchedItem.ExtraInfo.Other.AccountStatus

	if ( $SearchedItem.info -match "$( $PropLocalization.PLUserOtherAccountStatusStrDoNotActivate )" )
	{
		$NewPropValue = $PropLocalization.PLUserOtherAccountStatusStrUserBlocked
	}
	elseif ( $SearchedItem.accountExpires -ne $null )
	{
		if ( $SearchedItem.LockedOut )
		{
			$NewPropValue = $PropLocalization.PLUserOtherAccountStatusStrLocked
		}
		elseif ( $SearchedItem.Enabled -eq $false )
		{
			$NewPropValue = $PropLocalization.PLUserOtherAccountStatusStrUserDisabled
		}

		if ( $SearchedItem.Description -match $PropLocalization.PLUserOtherAccountStatusCodeREDesc )
		{
			$NewPropValue = "$NewPropValue $( $SearchedItem.Description )"
		}

		try
		{
			$Expires = ( Get-ADUser $SearchedItem -Properties accountExpires ).accountExpires
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
}

Export-ModuleMember -Variable IntMsgTable
Export-ModuleMember -Variable PHUserAdEnabled, PHUserAdHomeDirectory, PHUserAdMemberOf, PHUserOtherAccountStatus

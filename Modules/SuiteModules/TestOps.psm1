<#
.Synopsis
	A module for testing and verification
.State
	Prod
.Author
	Smorkster (smorkster)
#>

param ( $culture = "sv-SE" )

function Test-MailAddress
{
    <#
    .Synopsis
        Verify if input is a mail
    #>

    param ( [string] $Address )

	try
	{
		if ( $Address -match "\s" -or [string]::IsNullOrEmpty( $Address ) )
		{
			throw
		}
		else
		{
			Resolve-DnsName -Name ( [mailaddress]$Address ).Host -Type MX -ErrorAction Stop | Out-Null
			return $true
		}
	}
	catch
	{
		return $false
	}
}

$nudate = Get-Date -Format "yyyy-MM-dd HH:mm"
$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.Parent.FullName
try { $CallingScript = ( Get-Item $MyInvocation.PSCommandPath ).BaseName } catch { $CallingScript = $null }
Import-LocalizedData -BindingVariable IntmsgTable -UICulture $culture -FileName "$( ( $PSCommandPath.Split( "\" ) | Select-Object -Last 1 ).Split( "." )[0] ).psd1" -BaseDirectory "$RootDir\Localization\"
$ServerUrl = $IntmsgTable.SysManServerUrl

Export-ModuleMember -Verbose:$false -Function Test-MailAddress

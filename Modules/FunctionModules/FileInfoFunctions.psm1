<#
.Synopsis
	A collection of functions to run for a FileInfo object
.Description
	A collection of functions to run for a FileInfo object
.ObjectClass
	FileInfo
.State
	Prod
.Author
	Smorkster (smorkster)
#>

param ( $culture = "sv-SE" )

function Get-FilePermissions
{
	<#
	.Synopsis
		Show permissions
	.Description
		List who has access to the folder and what type of access
	.MenuItem
		List permissions
	.SearchedItemRequest
		Required
	.OutputType
		ObjectList
	.NoRunspace
	.State
		Prod
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item )

	$PermList = [System.Collections.ArrayList]::new()

	$acl = Get-Acl $Item.FullName
	( $acl.Access | Where-Object { $_.IdentityReference -match $IntMsgTable.GetFilePermissionsCodeRegExAclIdentity } ).IdentityReference | `
		Select-Object -Unique | `
		ForEach-Object {
			$PermType = if ( $_ -match "C$" ) { "C" } else { "R" }

			Get-ADGroup ( $_ -split "\\" )[1]  | `
				Get-ADGroupMember | `
					ForEach-Object {
						if ( "group" -eq $_.ObjectClass )
						{

							if ( $_.Name -match "C$" )
							{
								Get-ADGroupMember $_.SamAccountName | `
									Sort-Object Name | `
									ForEach-Object {
										[pscustomobject]@{ $IntMsgTable.GetFilePermissionsParamName = $_.Name ; $IntMsgTable.GetFilePermissionsParamPerm = $IntMsgTable.GetFilePermissionsStrPermWrite }
									}

							}
							else
							{
								Get-ADGroupMember $_.SamAccountName | `
									Sort-Object Name | `
									ForEach-Object {
										[pscustomobject]@{ $IntMsgTable.GetFilePermissionsParamName = $_.Name ; $IntMsgTable.GetFilePermissionsParamPerm = $IntMsgTable.GetFilePermissionsStrPermRead }
									}
							}
						}
						elseif ( "user" -eq $_.ObjectClass )
						{
							if ( "C" -eq $PermType )
							{
								[pscustomobject]@{ $IntMsgTable.GetFilePermissionsParamName = $_.Name ; $IntMsgTable.GetFilePermissionsParamPerm = $IntMsgTable.GetFilePermissionsStrPermWrite }
							}
							elseif ( "R" -eq $PermType )
							{
								[pscustomobject]@{ $IntMsgTable.GetFilePermissionsParamName = $_.Name ; $IntMsgTable.GetFilePermissionsParamPerm = $IntMsgTable.GetFilePermissionsStrPermRead }
							}
						}
					} | `
				ForEach-Object {
					$PermList.Add( $_ ) | Out-Null
				}
		}

	if ( 0 -eq $PermList.Count )
	{
		return $IntMsgTable.GetFilePermissionsStrNoPermissions
	}
	else
	{
		$PermList | Sort-Object $IntMsgTable.GetFilePermissionsParamPerm, $IntMsgTable.GetFilePermissionsParamName
	}
}

function Search-Virus
{
	<#
	.Synopsis
		Run virus scan
	.Description
		Run a virus scan on the file
	.MenuItem
		Virus scan
	.SearchedItemRequest
		Required
	.OutputType
		String
	.State
		Prod
	.Author
		Smorkster (smorkster)
	#>

	param ( $Item )

	try
	{
		$Shell = New-Object -Com Shell.Application
		$ShellFolder = $Shell.NameSpace( $Item.Directory.FullName )
		$ShellFile = $ShellFolder.ParseName( $Item.Name )
		$ShellFile.InvokeVerb( $IntMsgTable.SearchVirusStrVerbVirusScan )
		return $IntMsgTable.SearchVirusStarted
	}
	catch
	{
		throw $_.Exception.Message
	}

}

$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.Parent.FullName

Import-LocalizedData -BindingVariable IntMsgTable -UICulture $culture -FileName "$( ( $PSCommandPath.Split( "\" ) | Select-Object -Last 1 ).Split( "." )[0] ).psd1" -BaseDirectory "$RootDir\Localization"

Export-ModuleMember -Function Get-FilePermissions
Export-ModuleMember -Function Search-Virus

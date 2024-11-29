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

function Get-FileSharePath
{
	<#
	.Synopsis
		Translate filename to fileshare
	.Description
		Try to find actual path to fileshare May be helpful to find the file if needed to unlock it
	.MenuItem
		Find path fileshare
	.SearchedItemRequest
		Allowed
	.InputData
		Path, True, Path to file
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
		Test-Path -Path $Item -ErrorAction Stop

		$s = "Can be found at the following address in ADUC:"
		switch ( $Item.FullName.Substring( 0, 6 ) )
		{
			"G:\Org1" {
				$s += $Item.FullName -replace "G:\\Org1", "C:\vol_vfiles_vol1\fs_org1_grp"
			}
			"G:\Org2" {
				$s += $Item.FullName -replace "G:\\Org2", "C:\vol_vfiler_vol26\fs_org2_grp"
			}
			default {
				$s += "Root folder not recognized"
			}
		}
		
		return $s

	}
	catch
	{
		throw $IntMsgTable.GetFileSharePathInvalidPath
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

function Unlock-NetworkShareFile
{
	<#
	.Synopsis
		Disconnect locked network file
	.Description
		Unlock the path of a stuck network file.
	.MenuItem
		Unlock network file
	.SearchedItemRequest
		None
	.NoRunspace
	.InputData
		Path, True, Full path to the file
	.OutputType
		String
	.State
		Prod
	.Author
		Smorkster (smorkster)
	#>

	param ( $InputData )

	if ( [System.IO.Directory]::Exists( $InputData.Path ) )
	{
		throw $IntMsgTable.UnlockNetworkShareFileErrIsDir
	}
	elseif ( [System.IO.File]::Exists( $InputData.Path ) )
	{
		$ShareNames = @{ "fs_org1_app$" = "C:\vol_vfile_vol1\fs_org1_app"; "fs_org1_gem$" = "C:\vol_vfile_vol1\fs_org1_gem"; "fs_org1_grp$" = "C:\vol_vfile_vol1\fs_org1_grp"; "fs_org1_usr$" = "C:\vol_vfile_vol1\fs_org1_usr"; "fs_org2_usr$" = "C:\vol_vfile_vol1\fs_org2_usr"; "fs_org2_app$" = "C:\vol_vfile_vo2\fs_org2_app"; "fs_org2_gem$" = "C:\vol_vfile_vol2\fs_org2_gem" }

		if ( ( [System.Uri]$InputData.Path ).IsUnc )
		{
			$ns = $InputData.Path
		}
		else
		{
			$OrgMatch = @{ "True" = "02" ; "False" = "01" }
			$FolderType = @{ "G" = "grp$" ; "R" = "app$" ; "S" = "gem$" }
			$SharePathMatch = @{ "True" = "vfile_.domain.com" ; "False" = "vfile2_domain.com" }

			$ns = "\\domfs$( $InputData.Path.Split( "\" )[1].ToLower() )" + `
				$OrgMatch."$( $InputData.Path -match "G:\\(Org1)|(Org2).*" )" + `
				".domain.com\fs_$( $InputData.Path.Split( "\" )[1].ToLower() )_" + `
				$FolderType."$( $InputData.Path[0] )" + `
				"\$( $InputData.Path.Split( "\", 3 )[2] )"
		}

		try
		{
			Get-Item $ns -ErrorAction Stop | Out-Null
			$Val = $ShareNames.GetEnumerator() | Where-Object { $ns -like "*$( $_.Name -replace "\$" )*" }
			$SharePath = "$( $Val.Value )$( ( $ns -split ( $Val.Name -replace "\$", "\$" ) )[1] )"
			$Ret = openfiles.exe /s $SharePathMatch."$( $SharePath -match "vfile_domain" )" /disconnect /a * /op "$( $SharePath )"
			if ( $Ret -match "^SUCCESS" )
			{
				return $IntMsgTable.UnlockNetworkShareFileSuccess
			}
			else
			{
				return "$( $IntMsgTable.UnlockNetworkShareFileFailed )`n$( $Ret )"
			}
		}
		catch
		{
			throw "$( $IntMsgTable.UnlockNetworkShareFileErrFormingPath )\n$_"
		}
	}
	else
	{
		throw "$( $IntMsgTable.UnlockNetworkShareFileErrFileNotFound )`n$( $InputData.Path )"
	}
}

$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.Parent.FullName

Import-LocalizedData -BindingVariable IntMsgTable -UICulture $culture -FileName "$( ( $PSCommandPath.Split( "\" ) | Select-Object -Last 1 ).Split( "." )[0] ).psd1" -BaseDirectory "$RootDir\Localization"

Export-ModuleMember -Function Get-FilePermissions
Export-ModuleMember -Function Search-Virus

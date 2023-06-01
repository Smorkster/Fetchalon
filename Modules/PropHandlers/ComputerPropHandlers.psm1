<#
.Synopsis Property handlers for computer objects
.Description A collection of objects, as property handlers, to operate on objects with objectclass 'computer'
.State Prod
.Author Smorkster (smorkster)
#>

param ( $culture = "sv-SE" )

$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.Parent.FullName

Import-LocalizedData -BindingVariable IntMsgTable -UICulture $culture -FileName "$( ( $PSCommandPath.Split( "\" ) | Select-Object -Last 1 ).Split( "." )[0] ).psd1" -BaseDirectory "$RootDir\Localization"

# Handler to turn MemberOf-list to more readble strings
$MemberOf = [pscustomobject]@{
	Code = '$List = [System.Collections.ArrayList]::new()
	$SenderObject.DataContext.Value | Get-ADGroup | Select-Object -ExpandProperty Name | Sort-Object | ForEach-Object { $List.Add( $_ ) | Out-Null }
	$SenderObject.DataContext.Value = $List
	$syncHash.IcPropsList.Items.Refresh()'
	Title = $IntMsgTable.HTMemberOf
	Description = $IntMsgTable.HDescMemberOf
	Progress = 0
	MandatorySource = "AD"
}

# Check if computer is online
$IsOnline = [pscustomobject]@{
	Code = '
	$syncHash.Jobs.PCheckComputerOnline = [powershell]::Create()
	$syncHash.Jobs.PCheckComputerOnline.AddScript( { param ( $syncHash, $c )
		$syncHash.Window.Dispatcher.Invoke( [action] {
			$syncHash.Window.Resources[''CvsPropsList''].Source.Where( { "IsOnline" -eq $_.Name } )[0].HandlerProgress = -1
		} )
		try
		{
			Get-CimInstance -ClassName win32_operatingsystem -ComputerName $c.DataContext.Value -ErrorAction Stop
			$t = "Online"
		}
		catch
		{
			$t = "Offline"
		}
		$syncHash.Window.Dispatcher.Invoke( [action] {
			$syncHash.Window.Resources[''CvsDetailedProps''].Source.Where( { "IsOnline" -eq $_.Name } )[0].Value = $t
			$syncHash.Window.Resources[''CvsPropsList''].Source.Where( { "IsOnline" -eq $_.Name } )[0].Value = $t
			$syncHash.Window.Resources[''CvsPropsList''].Source.Where( { "IsOnline" -eq $_.Name } )[0].HandlerProgress = 0
			$syncHash.Window.Resources[''CvsDetailedProps''].View.Refresh()
			$syncHash.Window.Resources[''CvsPropsList''].View.Refresh()
		} )
	} )
	$syncHash.Jobs.PCheckComputerOnline.AddArgument( $syncHash )
	$syncHash.Jobs.PCheckComputerOnline.AddArgument( $SenderObject )
	$syncHash.Jobs.HCheckComputerOnline = $syncHash.Jobs.PCheckComputerOnline.BeginInvoke()
	'
	Title = $IntMsgTable.HTCheckComputerOnline
	Description = $IntMsgTable.HDescCheckComputerOnline
	MandatorySource = "Other"
}

# Get sharedaccount connected to computer
$SharedAccount = [pscustomobject]@{
	Code = '$syncHash.GridProgress.Visibility = [System.Windows.Visibility]::Visible
	$syncHash.Jobs.SharedAccountPS = [powershell]::Create().AddScript( { param ( $Name, $Modules, $syncHash )
		Import-Module $Modules
		$s = Get-ADUser -LDAPFilter "(userWorkstations=*$( $Name )*)"
		$syncHash.Window.Dispatcher.Invoke( [action] {
			$syncHash.GridProgress.Visibility = [System.Windows.Visibility]::Hidden
			$syncHash.Data.SearchedItem.SharedAccount = $s
			$syncHash.Window.Resources[''CvsDetailedProps''].Source.Where( { $_.Name -eq "SharedAccount" } )[0].Value = $s.Name
			$syncHash.Window.Resources[''CvsPropsList''].Source.Where( { $_.Name -eq "SharedAccount" } )[0].Value = $s.Name
			$syncHash.Window.Resources[''CvsPropsList''].View.Refresh()
		} )
	} )
	$syncHash.Jobs.SharedAccountPS.AddArgument( $syncHash.Data.SearchedItem.Name )
	$syncHash.Jobs.SharedAccountPS.AddArgument( ( Get-Module ) )
	$syncHash.Jobs.SharedAccountPS.AddArgument( $syncHash )
	$syncHash.Jobs.SharedAccountH = $syncHash.Jobs.SharedAccountPS.BeginInvoke()
	'
	Title = $IntMsgTable.HTGetSharedAccount
	Description = $IntMsgTable.HDescGetSharedAccount
	Progress = 0.0
	MandatorySource = "Other"
}

Export-ModuleMember -Variable MemberOf, IsOnline, SharedAccount

<#
.Synopsis
	Property handlers for computer objects
.Description
	A collection of objects, as property handlers, to operate on objects with objectclass 'computer'
.State
	Prod
.Author
	Smorkster (smorkster)
#>

param ( $culture = "sv-SE" )

$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.Parent.FullName

Import-LocalizedData -BindingVariable IntMsgTable -UICulture $culture -FileName "$( ( $PSCommandPath.Split( "\" ) | Select-Object -Last 1 ).Split( "." )[0] ).psd1" -BaseDirectory "$RootDir\Localization"

# Handler to turn MemberOf-list to more readble strings
$PHComputerAdMemberOf = [pscustomobject]@{
	Code = '
		$List = [System.Collections.ArrayList]::new()
		$SenderObject.DataContext.Value | Get-ADGroup | Select-Object -ExpandProperty Name | Sort-Object | ForEach-Object { $List.Add( $_ ) | Out-Null }
		$SenderObject.DataContext.Value = $List
		$syncHash.IcPropsList.Items.Refresh()
	'
	Title = $IntMsgTable.HTComputerAdMemberOf
	Description = $IntMsgTable.HDescComputerAdMemberOf
	Progress = 0
	MandatorySource = "AD"
}

$PHComputerAdOrgCostNo = [pscustomobject]@{
	Code = '
		$List = [System.Collections.ArrayList]::new()
		Get-ADComputer -LDAPFilter "($( $syncHash.IcPropsList.Items[1].Name )=$( $syncHash.IcPropsList.Items[1].Value[0] ))" -Properties Name, $syncHash.IcPropsList.Items[1].Name | `
			ForEach-Object {
				$OFS = ", "
				"$( $_.Name ) $( $_."$( $syncHash.IcPropsList.Items[1].Name )" )"
			} | `
			Sort-Object | `
			ForEach-Object {
				$List.Add( $_ ) | Out-Null
			}
			$SenderObject.DataContext.Value = $List
		$syncHash.IcPropsList.Items.Refresh()
	'
	Title = $IntMsgTable.HTComputerAdOrgCostNo
	Description = $IntMsgTable.HDescComputerAdOrgCostNo
	MandatorySource = "AD"
}

# Check if computer is online
$PHComputerOtherIsOnline = [pscustomobject]@{
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
	Title = $IntMsgTable.HTComputerOtherCheckOnline
	Description = $IntMsgTable.HDescComputerOtherCheckOnline
	MandatorySource = "Other"
}

# Get currently, active processes
$PHComputerOtherProcessList = [pscustomobject]@{
	Code = '
		$syncHash.GridProgress.Visibility = [System.Windows.Visibility]::Visible

		$List = [System.Collections.ArrayList]::new()
		try
		{
			try { $syncHash.Window.Resources[''CvsDetailedProps''].Source.Where( { $_.Name -eq "ProcessList" } )[0].Value.Clear() } catch {}
			$syncHash.Data.SearchedItem.ExtraInfo.Other.ProcessList.Clear()
			$SenderObject.DataContext.Value.Clear()
		}
		catch {}
		try
		{
			Get-Process -ComputerName $syncHash.Data.SearchedItem.Name -ErrorAction Stop | `
				Select-Object Name, Id | `
				Sort-Object Name | `
				ForEach-Object {
					if ( $List.Name -match $_.Name )
					{
						$P = $_
						try { $List.Where( { $_.Name -eq $P.Name } )[0].IdList.Add( $P.Id ) | Out-Null }
						catch {}
					}
					else
					{
						$Process = [pscustomobject]@{
							Name = $_.Name
							IdList = [System.Collections.ArrayList]::new()
						}
						$Process.IdList.Add( $_.Id ) | Out-Null
						$List.Add( $Process ) | Out-Null
					}
				}
			$List = $List | `
				Select-Object `
					@{
						Name = $syncHash.Data.msgTable.StrPHComputerOtherProcessListColName
						Expression = { $_.Name }
					}, `
					@{
						Name = $syncHash.Data.msgTable.StrPHComputerOtherProcessListColId
						Expression = { $_.IdList | `
							ForEach-Object `
								-Begin { `
									$c = 0
									$t = ""
								} `
								-Process {
									if ( $c -eq 0 )
									{
										$t = "$( $_.ToString() )"
									}
									elseif ( 0 -eq $c % 7 )
									{
										$t = "$t $( $_ )`n"
									}
									else
									{
										$t = "$t $( $_ )"
									}
									$c = $c + 1
								} `
								-End { $t.Trim() }
						}
					}
			try { $syncHash.Window.Resources[''CvsDetailedProps''].Source.Where( { $_.Name -eq "ProcessList" } )[0].Value = $List } catch {}
		}
		catch
		{
			$List.Add( ( [pscustomobject]@{ $syncHash.Data.msgTable.StrPHComputerOtherProcessListColName = $syncHash.Data.msgTable.StrPHComputerOtherProcessListError ; $syncHash.Data.msgTable.StrPHComputerOtherProcessListColId = 0 } ) ) | Out-Null
		}
		$SenderObject.DataContext.Value = $List
		$syncHash.Window.Resources[''CvsPropsList''].View.Refresh()
		$syncHash.GridProgress.Visibility = [System.Windows.Visibility]::Hidden
	'
	Title = $IntMsgTable.HTComputerOtherProcessList
	Description = $IntMsgTable.HDescComputerOtherProcessList
	Progress = 0.0
	MandatorySource = "Other"
}

# Get sharedaccount connected to computer
$PHComputerOtherSharedAccount = [pscustomobject]@{
	Code = '
		$syncHash.GridProgress.Visibility = [System.Windows.Visibility]::Visible
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
	Title = $IntMsgTable.HTComputerOtherGetSharedAccount
	Description = $IntMsgTable.HDescComputerOtherGetSharedAccount
	Progress = 0.0
	MandatorySource = "Other"
}

Export-ModuleMember -Variable PHComputerAdMemberOf, PHComputerAdOrgCostNo, PHComputerOtherIsOnline, PHComputerOtherProcessList, PHComputerOtherSharedAccount

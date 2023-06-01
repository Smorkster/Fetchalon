<#
.Synopsis
	Generate passwords with different demants
.Description
	Generate passwords with different lengths
.MenuItem
	Generate passwords
.State
	Prod
.Author
	Smorkster (smorkster)
#>

Add-Type -AssemblyName PresentationFramework
$syncHash = $args[0]

######################### Script start

$syncHash.Data.Words = $syncHash.Data.msgTable.Words -split ","
$syncHash.Data.Chars = $syncHash.Data.msgTable.Chars -split ","
$syncHash.Controls.Window.Resources['CvsPasswords'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()

$syncHash.Data.msgTable.GetEnumerator() | `
	Where-Object { $_.Name -match "App\d*Info" } | `
	ForEach-Object {
		$Info = $_.Value -split ","
		$app = [pscustomobject]@{
			Title = $Info[0]
			Min = $Info[1]
			Max = $Info[2]
			List = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
		}
		[void] $syncHash.Controls.Window.Resources['CvsPasswords'].Source.Add( $app )
	}

# Generate passwords
$syncHash.Controls.BtnGenerate.Add_Click( {
	if ( $syncHash.Controls.Window.Resources['CvsPasswords'].Source[0].List.Count -gt 20 )
	{
		$syncHash.Controls.Window.Resources['CvsPasswords'].Source | `
			ForEach-Object {
				$_.List.Clear()
			}
	}

	$syncHash.Controls.Window.Resources['CvsPasswords'].Source | `
		ForEach-Object {
			$App = $_
			0..7 | `
				ForEach-Object {
					$sb = [System.Text.StringBuilder]::new()
					$i = Get-Random -Minimum $App.Min -Maximum $App.Max
					$sb.Append( ( Get-Random $syncHash.Data.Words ) ) | Out-Null
					do
					{
						$sb.Append( ( Get-Random $syncHash.Data.Chars ) ) | Out-Null
					}
					until ( $sb.Length -ge $i )
					$b = [System.Windows.Controls.Button]@{ DataContext = $sb.ToString() }
					$b.Add_Click( { Set-Clipboard -Value $this.DataContext } )
					[void] $App.List.Add( $b )
				}
		}
	$syncHash.Controls.Window.Resources['CvsPasswords'].View.Refresh()
} )

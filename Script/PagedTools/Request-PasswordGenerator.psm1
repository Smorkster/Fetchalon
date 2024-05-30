<#
.Synopsis
	Generate passwords with different demants
.Description
	Generate passwords with pre specified lengths
.MenuItem
	Generate passwords
.State
	Prod
.Author
	Smorkster (smorkster)
#>

Add-Type -AssemblyName PresentationFramework
$syncHash = $args[0]

function SpellPassword
{
	param (
		[string] $Password
	)
	$t = $null
	$syncHash.Controls.TblSpelledPassword.Text = ( $Password.GetEnumerator() | `
		ForEach-Object {
			if ( [System.Int32]::TryParse( "$_" , [ref] $t ) )
			{
				$syncHash.Data.SpellingHashNumbers."$_"
			}
			elseif ( $syncHash.Data.msgTable.SpellingCharacters.Contains( $_ ) )
			{
				$syncHash.Data.SpellingHashCharacters."$_"
			}
			else
			{
				$syncHash.Data.SpellingHashWords."$_"
			}
		} ) -join " "
}

######################### Script start

$syncHash.Data.Words = $syncHash.Data.msgTable.Words -split ","
$syncHash.Data.Chars = $syncHash.Data.msgTable.Chars -split ","
$syncHash.Data.SpellingHashWords = @{}
$syncHash.Data.SpellingHashNumbers = @{}
$syncHash.Data.SpellingHashCharacters = @{}

$syncHash.Controls.Window.Resources['CvsPasswords'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
$syncHash.Controls.Window.Resources['CvsSpellingCollections'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()

$syncHash.Data.msgTable.Keys | `
	Where-Object { $_ -match "^SpellingWords" } | `
	ForEach-Object {
		$syncHash.Controls.Window.Resources['CvsSpellingCollections'].Source.Add( ( $_ -replace "SpellingWords" ) ) | Out-Null
	}

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

$syncHash.Data.msgTable.SpellingWordsMat -split "," | `
	ForEach-Object {
		$syncHash.Data.SpellingHashWords."$( $_[0] )" = $_
	}
0..9 | `
	ForEach-Object {
		$syncHash.Data.SpellingHashNumbers."$( $_ )" = ( $syncHash.Data.msgTable.SpellingNumbers -split "," )[$_]
	}
$syncHash.Data.msgTable.SpellingCharacters -split "," | `
	ForEach-Object `
	-Begin { $i = 0 } `
	-Process {
		$syncHash.Data.SpellingHashCharacters."$_" = ( $syncHash.Data.msgTable.SpellingCharactersNames -split "," )[$i]
		$i = $i + 1
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
					$b.Add_Click( {
						Set-Clipboard -Value $this.DataContext
						SpellPassword $this.DataContext
					} )
					[void] $App.List.Add( $b )
				}
		}
	$syncHash.Controls.Window.Resources['CvsPasswords'].View.Refresh()
	WriteLog -Text $syncHash.Data.msgTable.LogGenerated -Success $true | Out-Null
} )

$syncHash.Controls.CmdSpellingWordCollection.Add_SelectionChanged( {
	$syncHash.Data.msgTable."SpellingWords$( $this.SelectedText )" -split "," | `
		ForEach-Object {
			$syncHash.Data.SpellingHashWords."$( $_[0] )" = $_
		}

} )

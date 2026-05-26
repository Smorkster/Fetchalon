<#
.Synopsis
	Generate passwords with different demants
.MenuItem
	Generate passwords
.Description
	Generate passwords with pre specified lengths
.State
	Prod
.Author
	Smorkster (smorkster)
#>

Add-Type -AssemblyName PresentationFramework
$syncHash = $args[0]

function SpellPassword
{
	<#
	.Synopsis
		Spell the selected password
	#>

	if ( $null -ne $syncHash.Data.WordToSpell )
	{
		$syncHash.Controls.Window.Resources.CvsSpelledPassword.Source.Clear()
		$t = $null
		$syncHash.Data.WordToSpell.GetEnumerator() | `
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
			} | `
			ForEach-Object {
				$syncHash.Controls.Window.Resources.CvsSpelledPassword.Source.Add( $_ )
			}
	}
}

######################### Script start

$syncHash.Data.Words = $syncHash.Data.msgTable.Words -split ","
$syncHash.Data.Chars = $syncHash.Data.msgTable.Chars -split ","
$syncHash.Data.SpellingHashWords = @{}
$syncHash.Data.SpellingHashNumbers = @{}
$syncHash.Data.SpellingHashCharacters = @{}

$syncHash.Controls.Window.Resources['CvsPasswords'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
$syncHash.Controls.Window.Resources['CvsSpellingCollections'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
$syncHash.Controls.Window.Resources['CvsSpelledPassword'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()

# Get spellingwords helper lists
# Name of list will be name of key, excluding 'SpellingWords'
$syncHash.Data.msgTable.Keys | `
	Where-Object { $_ -match "^SpellingWords" } | `
	ForEach-Object {
		$syncHash.Controls.Window.Resources['CvsSpellingCollections'].Source.Add( ( $_ -replace "SpellingWords" ) ) | Out-Null
	}

# Get application password requirements
# Localization format: AppName, Min length, Max length
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

# Get spellingwords helper list for numbers
0..9 | `
	ForEach-Object {
		$syncHash.Data.SpellingHashNumbers."$( $_ )" = ( $syncHash.Data.msgTable.SpellingNumbers -split "," )[$_]
	}

# Get spellingwords helper list for characters
$syncHash.Data.msgTable.SpellingCharacters -split "," | `
	ForEach-Object `
	-Begin { $i = 0 } `
	-Process {
		$syncHash.Data.SpellingHashCharacters."$_" = ( $syncHash.Data.msgTable.SpellingCharactersNames -split "," )[$i]
		$i = $i + 1
	}

# Generate passwords
$syncHash.Controls.BtnGenerate.Add_Click( {
	$syncHash.Controls.Window.Resources['CvsPasswords'].Source | `
		ForEach-Object {
			$_.List.Clear()
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
						$syncHash.Data.WordToSpell = $this.DataContext
						SpellPassword
					} )
					[void] $App.List.Add( $b )
				}
		}
	$syncHash.Controls.Window.Resources['CvsPasswords'].View.Refresh()
	WriteLog -Text $syncHash.Data.msgTable.LogGenerated -Success $true | Out-Null
} )

# Spelling helper list changed, parse the new selection
$syncHash.Controls.CmdSpellingWordCollection.Add_SelectionChanged( {
	$syncHash.Data.SpellingHashWords.Clear()
	$syncHash.Data.msgTable."SpellingWords$( $this.SelectedValue )" -split "," | `
		ForEach-Object {
			$syncHash.Data.SpellingHashWords."$( $_[0] )" = $_
		}
	SpellPassword
} )

$syncHash.Controls.Window.Add_Loaded( {
	$syncHash.Controls.CmdSpellingWordCollection.SelectedIndex = 0
} )
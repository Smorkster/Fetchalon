<#
.Synopsis
	CM Backup-form
.MenuItem
	CM backup-form
.Description
	A form to use as backup when CM is down
.State
	Prod
.Author
	Smorkster (smorkster)
#>

Add-Type -AssemblyName PresentationFramework
$syncHash = $args[0]

function Approve-Input
{
	$syncHash.Controls.BtnReset.Visibility = [System.Windows.Visibility]::Visible
	$syncHash.Controls.BtnSaveCase.IsEnabled = ( $syncHash.Controls.GetEnumerator() | Where-Object { $_.Name -match "^LblVerify" -and $_.Value.IsVisible -and $_.Value.Foreground.ToString() -eq "#FFFF0000" } ).Count -eq 0
}

function Load-SavedCaseInfos
{
	<#
	.Synopsis
		Get list of saved caseinfos
	#>

	$syncHash.Controls.Window.Resources['CvsSavedCases'].Source = [System.Collections.ObjectModel.ObservableCollection[pscustomobject]]::new()
	$syncHash.Controls.Window.Resources['CvsSavedCases'].Source.Add( ( [pscustomobject]@{ Name = $syncHash.Data.msgTable.StrSelectCase } ) )
	Get-ChildItem "$( $syncHash.Data.BaseDir )\Output\$( $env:USERNAME )" | `
		Where-Object { $_.Name -match "^$( $syncHash.Data.msgTable.StrJsonFileName )" } | `
		ForEach-Object {
			$syncHash.Controls.Window.Resources['CvsSavedCases'].Source.Add( $_ )
		}
	$syncHash.Controls.Window.Resources['CvsSavedCases'].View.Refresh()

}

function Reset-Controls
{
	$syncHash.Controls.GetEnumerator() | `
		ForEach-Object {
			if ( $_.Name -match "^Tb" -and $_.Value -isnot [System.Windows.Controls.Primitives.ToggleButton] )
			{
				$_.Value.Text = ""
			}
			elseif ( $_.Name -match "^Cb" )
			{
				$_.Value.SelectedIndex = 0
			}
			elseif ( $_.Name -eq "LblOutputPath" )
			{
				$_.Value.Content = ""
				$_.Value.Visibility = [System.Windows.Visibility]::Hidden
			}
			elseif ( $_.Name -match "^Lbl.*Invalid$" )
			{
				$_.Value.Visibility = [System.Windows.Visibility]::Hidden
			}
		}
	$syncHash.Controls.BtnReset.Visibility = [System.Windows.Visibility]::Hidden
}

function Set-Localizations
{
	<#
	.Synopsis
		Set localized strings and script variables
	#>

	$syncHash.Data.BaseDir = ( Get-Item $MyInvocation.PsScriptRoot ).Parent.Parent.FullName

	Load-SavedCaseInfos

	# Import localized lists
	$syncHash.Data.msgTable.Keys | `
		Where-Object { $_ -match "List$" } | `
		ForEach-Object {
			$CbName = $_ -replace "^Content" -replace "List$"
			( $syncHash.Data.msgTable."$( $_ )" -split "," ).Trim() | `
				ForEach-Object {
					$syncHash.Controls.$CbName.Items.Add( $_ )
				}
		}
}

######################### Script start
$controls = [System.Collections.ArrayList]::new()

BindControls $syncHash $controls

Set-Localizations

# Open a saved case-file
$syncHash.Controls.BtnLoadCase.Add_Click( {
	$CaseContent = Get-Content -Path $syncHash.Controls.CbSavedCases.SelectedItem.FullName | ConvertFrom-Json
	$CaseContent | `
		Get-Member -MemberType NoteProperty | `
		ForEach-Object {
			try
			{
				$syncHash.Controls."Tb$( $_.Name )".Text = $CaseContent."$( $_.Name )"
			}
			catch
			{
				$syncHash.Controls."Cb$( $_.Name )".SelectedItem = $CaseContent."$( $_.Name )"
			}
		}
	$syncHash.Controls.TBtnInc = $CaseContent.Inc
	$syncHash.Controls.TBtnRitm = $CaseContent.Ritm
	$syncHash.Controls.BtnRemoveCaseInfo.Visibility = [System.Windows.Visibility]::Visible
} )

#
$syncHash.Controls.BtnRemoveCaseInfo.Add_Click( {
	Remove-Item -Path $syncHash.Controls.CbSavedCases.SelectedItem.FullName
	Load-SavedCaseInfos
} )

#
$syncHash.Controls.BtnReset.Add_Click( {
	Reset-Controls
} )

# Save data to a case-file
$syncHash.Controls.BtnSaveCase.Add_Click( {
	$syncHash.Controls.BtnReset.Visibility = [System.Windows.Visibility]::Hidden
	$Data = @{}
	$syncHash.Controls.GetEnumerator() | `
		Where-Object { $_.Name -match "^(Tb(?!tn))|(Cb)" } | `
		ForEach-Object {
			$Data."$( $_.Name -replace "^(Tb(?!tn))|(Cb)" )" = $_.Value.Text
		}
	$Data.Ritm = $syncHash.Controls.TBtnRitm.IsChecked
	$Data.Inc = $syncHash.Controls.TBtnInc.IsChecked
	$syncHash.Controls.LblOutputPath.Content = "$( $syncHash.Data.msgTable.StrSaveTo ): $( WriteOutput -Output ( $Data | ConvertTo-Json ) -FileExtension "json" -FileName "$( $syncHash.Data.msgTable.StrJsonFileName )" )"
	Load-SavedCaseInfos
	Reset-Controls
} )

#
$syncHash.Controls.CbCategory.Add_SelectionChanged( {
	$syncHash.Controls.CbSubCategory.Items.Clear()
	if ( $this.SelectedIndex -gt 0 )
	{
		$syncHash.Data.msgTable."ContentCbSubCategory$( $syncHash.Controls.CbCategory.SelectedItem -replace "\s", "_"  )" -split ", " | `
			ForEach-Object {
				$syncHash.Controls.CbSubCategory.Items.Add( $_ ) | Out-Null
			}
	}
} )

$syncHash.Controls.GetEnumerator() | `
	Where-Object { $_.Name -match "^Tb" -and $_.Value -is [System.Windows.Controls.TextBox] } | `
	ForEach-Object {
		if ( $_.Name -match "Tb.*Telephone" )
		{
			$_.Value.Add_TextChanged( {
				$StarName = "$( $this.Name -replace "^Tb", "LblVerify" )"
				$WarnName = "$( $this.Name -replace "^Tb", "Lbl" )Invalid"

				if ( $this.Text.Length -eq 0 )
				{
					$syncHash.Controls.$StarName.Foreground = "Red"
					$syncHash.Controls.$WarnName.Visibility = [System.Windows.Visibility]::Hidden
				}
				else
				{
					if ( $this.Text -match "[^\d-\s]" )
					{
						$syncHash.Controls.$StarName.Foreground = "Red"
						$syncHash.Controls.$WarnName.Visibility = [System.Windows.Visibility]::Visible
					}
					else
					{
						$syncHash.Controls.$StarName.Foreground = "#FFD3D3D3"
						$syncHash.Controls.$WarnName.Visibility = [System.Windows.Visibility]::Hidden
					}
				}
				Approve-Input
			} )
		}
		elseif ( $_.Name -match "Tb.*Mail" )
		{
			$_.Value.Add_TextChanged( {
				$StarName = "$( $this.Name -replace "^Tb", "LblVerify" )"
				$WarnName = "$( $this.Name -replace "^Tb", "Lbl" )Invalid"

				if ( $this.Text.Length -eq 0 )
				{
					$syncHash.Controls.$StarName.Foreground = "Red"
					$syncHash.Controls.$WarnName.Visibility = [System.Windows.Visibility]::Hidden
				}
				else
				{
					if ( ( $this.Text -match "\s" ) `
						-or ( $this.Text -notmatch "(?:[a-z0-9!#$%&'*+/=?^_``{|}~-]+(?:\.[a-z0-9!`#$%&'*+/=?^_``{|}~-]+)*|`"(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21\x23-\x5b\x5d-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])*`")@(?:(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\[(?:(?:(2(5[0-5]|[0-4][0-9])|1[0-9][0-9]|[1-9]?[0-9]))\.){3}(?:(2(5[0-5]|[0-4][0-9])|1[0-9][0-9]|[1-9]?[0-9])|[a-z0-9-]*[a-z0-9]:(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21-\x5a\x53-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])+)\])" )
					)
					{
						$syncHash.Controls.$StarName.Foreground = "Red"
						$syncHash.Controls.$WarnName.Visibility = [System.Windows.Visibility]::Visible
					}
					else
					{
						$syncHash.Controls.$StarName.Foreground = "#FFD3D3D3"
						$syncHash.Controls.$WarnName.Visibility = [System.Windows.Visibility]::Hidden
					}
				}
				Approve-Input
			} )
		}
		elseif ( $_.Name -match "^Tb.*Id$" )
		{
			$_.Value.Add_TextChanged( {
				$StarName = "$( $this.Name -replace "^Tb", "LblVerify" )"
				$WarnName = "$( $this.Name -replace "^Tb", "Lbl" )Invalid"

				if ( $this.Text.Length -eq 0 )
				{
					$syncHash.Controls.$StarName.Foreground = "Red"
					$syncHash.Controls.$WarnName.Visibility = [System.Windows.Visibility]::Hidden
				}
				else
				{
					if ( $this.Text -match "\W|\s" )
					{
						$syncHash.Controls.$StarName.Foreground = "Red"
						$syncHash.Controls.$WarnName.Visibility = [System.Windows.Visibility]::Visible
					}
					else
					{
						$syncHash.Controls.$StarName.Foreground = "#FFD3D3D3"
						$syncHash.Controls.$WarnName.Visibility = [System.Windows.Visibility]::Hidden
					}
				}
				Approve-Input
			} )
		}
		else
		{
			$_.Value.Add_TextChanged( {
				Approve-Input
			} )
		}
	}

#
$syncHash.Controls.TBtnRitm.Add_Checked( {
	$syncHash.Controls.BtnRemoveCaseInfo.Visibility = [System.Windows.Visibility]::Hidden
} )
$syncHash.Controls.TBtnRitm.Add_Unchecked( {
	$syncHash.Controls.BtnRemoveCaseInfo.Visibility = [System.Windows.Visibility]::Hidden
} )

#
$syncHash.Controls.TBtnInc.Add_Checked( {
	$syncHash.Controls.BtnRemoveCaseInfo.Visibility = [System.Windows.Visibility]::Hidden
} )
$syncHash.Controls.TBtnInc.Add_Unchecked( {
	$syncHash.Controls.BtnRemoveCaseInfo.Visibility = [System.Windows.Visibility]::Hidden
} )

# Window rendered, do some final preparations
$syncHash.Controls.Window.Add_Loaded( {
	$syncHash.Controls.CbSavedCases.SelectedIndex = 0
} )

Export-ModuleMember
<#
.Synopsis
	Match text against RegEx
.Description
	Matches text against RegEx-string. If the matches can be identified as AD-objects, specified property can be copied for AD-objects identified by the matches
.MenuItem
	Match to RegEx
.State
	Prod
.Author
	Smorkster (smorkster)
#>

Add-Type -AssemblyName PresentationFramework
$syncHash = $args[0]

function MatchText
{
	$syncHash.Controls.TbValues.Text = $syncHash.Controls.TblErrors.Text = ""
	$syncHash.Controls.Window.Resources['CvsMatches'].Source.Clear()
	$syncHash.Controls.Window.Resources['CvsPropertyNames'].Source.Clear()
	$syncHash.Controls.TabMatches.SelectedIndex = 0

	if ( -not [string]::IsNullOrEmpty( $syncHash.Controls.TbRegex.Text ) )
	{
		try
		{
			foreach ( $Match in [regex]::Matches( $syncHash.Controls.TbTextToMatch.Text, $syncHash.Controls.TbRegex.Text ) )
			{
				if ( [string]::IsNullOrEmpty( $syncHash.Controls.TbValues.Text ) )
				{
					$syncHash.Controls.TbValues.Text = $Match.Groups[0].Value
					try
					{
						switch ( $syncHash.Controls.CbDefaultsList.SelectedItem.ObjectClass )
						{
							"user" {
								( Get-ADUser $Match.Groups[0].Value -Properties * | Get-Member -MemberType Property ).Name | `
									ForEach-Object {
										$syncHash.Controls.Window.Resources['CvsPropertyNames'].Source.Add( $_ ) | Out-Null
									}
								}
							default {}
						}
					}
					catch
					{}
				}
				else
				{
					$syncHash.Controls.TbValues.Text += "`n$( $Match.Groups[0].Value )"
				}
				[void] $syncHash.Controls.Window.Resources['CvsMatches'].Source.Add( $Match )
			}
		}
		catch
		{
			$syncHash.Controls.TblErrors.Text = ( $_.Exception.InnerException.Message -split " - " )[1].TrimEnd( "." )
		}
	}
}

###################### Script start

$syncHash.Controls.Window.Resources['CvsDefaultRegExs'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
$syncHash.Controls.Window.Resources['CvsMatches'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
$syncHash.Controls.Window.Resources['CvsPropertyNames'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()

$syncHash.Controls.Window.Resources['CvsDefaultRegExs'].Source.Add( ( [pscustomobject]@{ Name = $syncHash.Data.msgTable.StrDefaultRegExAdSAN ; RegEx = $syncHash.Data.msgTable.StrDefaultRegExAdSANCode ; ObjectClass = "user" } ) )
$syncHash.Controls.Window.Resources['CvsDefaultRegExs'].Source.Add( ( [pscustomobject]@{ Name = $syncHash.Data.msgTable.StrRegExFAccount ; RegEx = $syncHash.Data.msgTable.StrRegExFAccountCode ; ObjectClass = "user" } ) )

$syncHash.Controls.IcMatches.Resources['BrdStyle'].Setters[0].Handler = [System.Windows.Input.MouseEventHandler] {
	param ( $ObjectSender, $e )

	$syncHash.Controls.TbTextToMatch.SelectionStart = $ObjectSender.DataContext.Index
	$syncHash.Controls.TbTextToMatch.SelectionLength = $ObjectSender.DataContext.Length
}

$syncHash.Controls.BtnCopyAsAD.Add_Click( {
	$syncHash.Controls.TbValues.Text -split "`n" | Get-ADUser | Select-Object -ExpandProperty $syncHash.Controls.CbPropertyToCopy.SelectedItem | Sort-Object | Set-Clipboard
} )

$syncHash.Controls.BtnCopyExtraction.Add_Click( {
	$syncHash.Controls.TbValues.Text | clip
} )

$syncHash.Controls.BtnUseRegEx.Add_Click( {
	$syncHash.Controls.TbRegex.Text = $syncHash.Controls.CbDefaultsList.SelectedItem.RegEx
	if ( $syncHash.Controls.CbDefaultsList.SelectedItem.Name -cmatch "AD" )
	{
		$syncHash.Controls.BtnCopyAsAD.Visibility = [System.Windows.Visibility]::Visible
	}
	else
	{
		$syncHash.Controls.BtnCopyAsAD.Visibility = [System.Windows.Visibility]::Hidden
	}
} )

$syncHash.Controls.TabMatches.Add_SelectionChanged( {
	if ( 1 -eq $this.SelectedIndex )
	{
		$syncHash.Controls.TbTextToMatch.Focus()
		$syncHash.Controls.TiMatches.RaiseEvent( [System.Windows.Controls.Primitives.ButtonBase]::ClickEvent )
	}
} )

$syncHash.Controls.TblValuesTitle.Add_LostKeyboardFocus( {
	$syncHash.Controls.TbTextToMatch.Focus()
} )

$syncHash.Controls.TbRegex.Add_KeyUp( {
	if ( $syncHash.Controls.CbDefaultsList.SelectedItem.RegEx -ne $this.Text )
	{
		$syncHash.Controls.CbDefaultsList.SelectedIndex = -1
	}
} )

$syncHash.Controls.TbRegex.Add_TextChanged( {
	MatchText
} )

$syncHash.Controls.TbTextToMatch.Add_TextChanged( {
	MatchText
} )

<#
.Synopsis
	Functions for working with GUI's
.Description
	A module for functions creating and working with GUI's
.State
	Prod
.Author
	Smorkster (smorkster)
#>

param (
	[string] $culture = "sv-SE",
	[switch] $LoadConverters
)

function BindControls
{
	<#
	.Synopsis
		Create bindings between controls and an associated collections of predefined values
	.Parameter syncHash
		The synchronized hashtable that holds the controls
	.Parameter ControlsToBind
		A list of controls and their predefined values
		Each item in the list has an hashtable with the name of the control, and a list of PropName/PropVal-pairs:
		@{ CName = "BtnPerform" ; Props = @( @{ PropName = "IsEnabled"; PropVal = $false } ) }
	#>

	param (
		$syncHash,
		$ControlsToBind
	)

	$Page = $syncHash.ContainsKey( "Controls" )
	$GenErrors = [System.Collections.ArrayList]::new()

	foreach ( $control in $ControlsToBind )
	{
		if ( ( $n = $control.CName ) -in $syncHash.DC.Keys )
		{
			# Insert all predefines property values
			$control.Props | Foreach-Object { $syncHash.DC.$n.Add( $_.PropVal ) }

			# Create the bindingobjects
			0..( $control.Props.Count - 1 ) | Foreach-Object { [void] $syncHash.Bindings.$n.Add( ( New-Object System.Windows.Data.Binding -ArgumentList "[$_]" ) ) }
			$syncHash.Bindings.$n | Foreach-Object {
				try
				{
					$_.Mode = [System.Windows.Data.BindingMode]::TwoWay
				}
				catch
				{
					if ( $_.Exception.Message -eq "Exception setting ""Mode"": ""Binding cannot be changed after it has been used.""" )
					{ [void] [System.Windows.MessageBox]::Show( "$( $control.CName ) $( $IntMsgTable.BindControlsErrControlDuplicate ) " ) }
				}
			}
			# Insert bindings to controls DataContext
			if ( $Page ) { $syncHash.Controls.$n.DataContext = $syncHash.DC.$n }
			else { $syncHash.$n.DataContext = $syncHash.DC.$n }

			# Connect the bindings
			for ( $i = 0; $i -lt $control.Props.Count; $i++ )
			{
				$p = "$( $control.Props[$i].PropName -replace "Property" )Property"
				try
				{
					if ( $Page )
					{
						# Connect property $p of control $n to binding at index $i in $Bindings
						[void][System.Windows.Data.BindingOperations]::SetBinding( $syncHash.Controls.$n, $( $syncHash.Controls.$n.DependencyObjectType.SystemType )::$p, $syncHash.Bindings.$n[ $i ] )
						# This enables controls that gets binding to its ItemsSource to be reachable from backgroundthreads
						if ( $control.Props[$i].PropName -eq "ItemsSource" )
						{
							[System.Windows.Data.BindingOperations]::EnableCollectionSynchronization( $syncHash.Controls.$n.ItemsSource, $syncHash.Controls.$n )
						}
					}
					else
					{
						# Connect property $p of control $n to binding at index $i in $Bindings
						[void][System.Windows.Data.BindingOperations]::SetBinding( $syncHash.$n, $( $syncHash.$n.DependencyObjectType.SystemType )::$p, $syncHash.Bindings.$n[ $i ] )
						# This enables controls that gets binding to its ItemsSource to be reachable from backgroundthreads
						if ( $control.Props[$i].PropName -eq "ItemsSource" )
						{
							[System.Windows.Data.BindingOperations]::EnableCollectionSynchronization( $syncHash.$n.ItemsSource, $syncHash.$n )
						}
					}
				}
				catch
				{
					[void] $GenErrors.Add( "$n$( $IntMsgTable.BindControlsErrNoProperty ) '$p'")
					$syncHash.GenErrors.Add($_)
				}
			}
		}
		else
		{
			[void] $GenErrors.Add( "$( $IntMsgTable.BindControlsErrNoControl ) $n" )
			$syncHash.GenError.Add( $_ )
		}
	}

	# List errors from when binding controls and properties
	if ( $GenErrors.Count -gt 0 )
	{
		$ofs = "`n"
		[void] [System.Windows.MessageBox]::Show( "$( $IntMsgTable.BindControlsErrAtGen ):`n`n$GenErrors" )
	}
}

function CreateWindow
{
	<#
	.Synopsis
		Creates a WPF-window, based on XAML-file with same name as the calling script
	.Parameter IncludeConverters
		If converters (see variable at bottom) should be imported
	.Outputs
		Returns object and an array containing the names of each named control in the XAML-file
	.State
		Prod
	#>

	param (
		[switch] $IncludeConverters,
		$XamlFile
	)
	Add-Type -AssemblyName PresentationFramework

	if ( $null -eq $XamlFile )
	{
		$XamlFile = "$RootDir\Gui\$( $CallingScript.BaseName ).xaml"
	}

	$inputXML = Get-Content $XamlFile -Raw
	if ( $IncludeConverters )
	{
		try { LoadConverters } catch {}
		$c = New-Object FetchalonConverters.ADUserConverter
		$AssemblyName = $c.GetType().Assembly.FullName.Split(',')[0]
		$inputXML = $inputXML -replace 'FetchalonConverterAssembly', $AssemblyName
	}
	$inputXML = $inputXML -replace "x:Name", 'Name'
	[XML]$Xaml = $inputXML

	$reader = ( [System.Xml.XmlNodeReader]::new( $Xaml ) )
	try
	{
		$Window = [Windows.Markup.XamlReader]::Load( $reader )
		$vars = @()
		$Xaml.SelectNodes( "//*[@Name]" ) | ForEach-Object { $vars += $_.Name }
		return $Window, $vars
	}
	catch
	{
		Write-Host "$( $IntMsgTable.CreateWindowErrReadingXaml )`n`n" -Foreground Cyan
		Write-Host "Error" -Foreground Red
		Write-Host "$( $_.Exception )`n`n"
		Read-Host $IntMsgTable.CreateWindowErrReadingXamlExit
		exit
	}
}

function CreatePage
{
	<#
	.Synopsis
		Create a synchronized hashtable for an WPF-page
	.Parameter ControlsToBind
		A list of controls and their predefined values
		Each item in the list has an hashtable with the name of the control, and a list of PropName/PropVal-pairs:
		@{ CName = "BtnPerform" ; Props = @( @{ PropName = "IsEnabled"; PropVal = $false } ) }
	.Parameter FilePath
		Full file path of the Xaml-file to parse
	.Outputs
		A synchronized hashtable with the page and some usefull collections
	#>

	param (
		$ControlsToBind,
		$FilePath
	)

	$syncHash = [hashtable]::Synchronized( @{} )
	$syncHash.Page, $ControlNames = CreateWindow -IncludeConverters -XamlFile $FilePath
	if ( $syncHash.Page -is [System.Windows.Controls.Page] )
	{
		$syncHash.Bindings = [hashtable]( @{} )
		$syncHash.Code = [hashtable]( @{} )
		$syncHash.Controls = [hashtable]::Synchronized( @{} )
		$syncHash.Data = [hashtable]( @{} )
		$syncHash.DC = [hashtable]( @{} )
		$syncHash.Errors = [System.Collections.ArrayList]::new()
		$syncHash.GenErrors = [System.Collections.ArrayList]::new()
		$syncHash.Jobs = [hashtable]( @{} )
		$syncHash.Root = $RootDir
		$ControlNames | ForEach-Object {
			$syncHash.Controls.$_ = $syncHash.Page.FindName( $_ )
			$syncHash.Bindings.$_ = New-Object System.Collections.ObjectModel.ObservableCollection[object]
			$syncHash.DC.$_ = New-Object System.Collections.ObjectModel.ObservableCollection[object]
		}

		BindControls -SyncHash $syncHash -ControlsToBind $ControlsToBind
		return $syncHash
	}
	else
	{
		throw "NotPage"
	}
}

function CreateWindowExt
{
	<#
	.Synopsis
		Creates a synchronized hashtable for the window and binds listed properties of their controls to datacontext
	.Description
		Creates a synchronized hashtable for the GUI generated in CreateWindow. Then binds the properties listed in input (ControlsToBind) to the datacontext of each named control. These are reached within $syncHash.DC.<name of the control>[<index of the property>].
		The hashtable contains these collections that can be used inside scripts:
		Vars - An array with the names of each named control
		Data - Hashtable to save variables, collections or objects inside scripts
		Jobs - Hashtable to store PSJobs
		Output - A string that can be used for output data
		DC - Hashtable with each bound datacontext for the named controls listed properties. This is defined from $ControlsToBind when calling the function
	.Parameter ControlsToBind
		An arraylist containing the names and values of controls and properties to bind.
		Each item in the arraylist must follow this structure:
		$arraylist.Add( @{ CName = "ControlName"
			Props = @(
				@{ PropName = "BorderBrush"
					PropVal = "Red" }
				) } )
		CName - Name of the control as entered in the XAML-file
		PropName - Name of the property. This must be one the controltypes Dependency Properties
	.Outputs
		The hashtable containing all bindings and arrays
	#>

	param (
		[System.Collections.ArrayList] $ControlsToBind,
		[switch] $IncludeConverters
	)

	$syncHash = [hashtable]::Synchronized( @{} )
	$syncHash.Bindings = [hashtable]( @{} )
	$syncHash.Data = [hashtable]( @{} )
	$syncHash.DC = [hashtable]( @{} )
	$syncHash.Jobs = [hashtable]( @{} )
	$syncHash.Output = ""
	$syncHash.GenErrors = [System.Collections.ArrayList]::new()
	if ( $IncludeConverters ) { $syncHash.Window, $syncHash.Vars = CreateWindow -IncludeConverters }
	else { $syncHash.Window, $syncHash.Vars = CreateWindow }

	$syncHash.Vars | Foreach-Object {
		$syncHash.$_ = $syncHash.Window.FindName( $_ )
		$syncHash.Bindings.$_ = New-Object System.Collections.ObjectModel.ObservableCollection[object]
		$syncHash.DC.$_ = New-Object System.Collections.ObjectModel.ObservableCollection[object]
	}

	BindControls $syncHash $ControlsToBind

	return $syncHash
}

function LoadConverters
{
	if ( 7 -eq ( $PSVersionTable ).PSVersion.Major )
	{
		Add-Type -ReferencedAssemblies Microsoft.ActiveDirectory.Management, `
										PresentationFramework, `
										System.DirectoryServices, `
										System.DirectoryServices.AccountManagement, `
										System.Drawing, `
										System.Management.Automation, `
										System.Text.RegularExpressions, `
										System.Windows, `
										System.Xaml, `
										'C:\Program Files\PowerShell\7\WindowsBase.dll', `
										'C:\Program Files\PowerShell\7\System.ComponentModel.Primitives.dll' ,
										'C:\Program Files\PowerShell\7\System.Collections.NonGeneric.dll' -TypeDefinition $Converters -ErrorAction Stop
	}
	else
	{
		Add-Type -ReferencedAssemblies Microsoft.ActiveDirectory.Management, `
										PresentationFramework, `
										System.DirectoryServices.AccountManagement, `
										System.DirectoryServices, `
										System.Drawing, `
										System.Management.Automation, `
										System.Text.RegularExpressions, `
										System.Windows, `
										System.Xaml, `
										C:\Windows\Microsoft.NET\Framework\v4.0.30319\WPF\WindowsBase.dll -TypeDefinition $Converters -ErrorAction Stop
	}
}

function Close-SplashScreen
{
	<#
	.Synopsis
		Close the splash screen
	.Parameter Duration
		Duration to wait before closing the splash screen
	#>

	param ( [int] $Duration )

	if ( $Duration )
	{
		Start-Sleep -Seconds $Duration
	}
	$Script:SplashHash.Window.Dispatcher.Invoke( "Normal", [action]{ $Script:SplashHash.Window.Close() } )
	$Script:SplashShell.EndInvoke( $SplashHandle ) | Out-Null
}

function Show-CustomMessageBox
{
	<#
	.Synopsis
		Display a custom messagebox with given text
	.Description
		Display a custom messagebox with given text, and, if defined, title, icon and button/-s
	.Parameter Text
		The text to display in the custom messagebox
	.Parameter Title
		A string to display in the title of the custom messagebox
	.Parameter Button
		String list of buttons that are used in the custom messagebox
	.Parameter Icon
		What icon is to be displayed in the messagebox
	.Outputs
		Returns which button in the messagebox was clicked
	.State
		Prod
	.Author
		Smorkster (smorkster)
	#>

	param (
		[string] $Text,
		[string] $Title = "",
		[string] $BorderColor = "Green",
		[string[]] $ButtonStrings,
		[string] $Icon
	)

	$LabelText = $Text
	$Script:CustomMsgBoxHash = [hashtable]::Synchronized( @{} )

	if ( [string]::IsNullOrEmpty( $Title ) )
	{
		$Function = ( Get-PSCallStack )[1].FunctionName

		$Title = "$( $IntMsgTable.ShowCustomMessageBoxDefaultTitle ) '$( $Function )'"
	}

	$CMsgBoxRunspace = [runspacefactory]::CreateRunspace()
	$CMsgBoxRunspace.ApartmentState = "STA"
	$CMsgBoxRunspace.ThreadOptions = "ReuseThread"
	$CMsgBoxRunspace.Open()
	$CMsgBoxRunspace.SessionStateProxy.SetVariable( "hash", $Script:CustomMsgBoxHash )
	$CMsgBoxRunspace.SessionStateProxy.SetVariable( "MessageLabel", $LabelText )
	$CMsgBoxRunspace.SessionStateProxy.SetVariable( "Title", $Title )
	$CMsgBoxRunspace.SessionStateProxy.SetVariable( "ButtonStrings", $ButtonStrings )
	$CMsgBoxRunspace.SessionStateProxy.SetVariable( "xml", ( [xml] ( Get-Content "$( ( Get-Item $PSCommandPath ).Directory.Parent.Parent.FullName )\GUI\Show-CustomMessageBox.xaml" -Raw ) ) )
	$Script:CustomMsgBoxShell = [powershell]::Create()
	$Script:CustomMsgBoxShell.AddScript( {
		Add-Type -AssemblyName PresentationFramework

		$reader = New-Object System.Xml.XmlNodeReader $xml
		$hash.Window = [Windows.Markup.XamlReader]::Load( $reader )
		$hash.MessageLabel = $hash.Window.FindName( "MessageLabel" )
		$hash.Header = $hash.Window.FindName( "Header" )
		$hash.IcButtons = $hash.Window.FindName( "IcButtons" )

		$hash.MessageLabel.Content = $MessageLabel
		$hash.Header.Content = $Title
		$hash.IcButtons.ItemsSource = $ButtonStrings
		$hash.IcButtons.Resources['BtnAnswerStyle'].Setters.Where( { $_.Event.Name -match "Click" } )[0].Handler = [System.Windows.RoutedEventHandler] {
			param ( $SenderObject, $e )
			$hash.Answer = $SenderObject.Content
			$hash.Window.Close()
		}
		$hash.Window.ShowDialog()
		return $Answer
	} ) | Out-Null

	$Script:CustomMsgBoxShell.Runspace = $CMsgBoxRunspace
	$Script:CustomMsgBoxHandle = $Script:CustomMsgBoxShell.BeginInvoke()

	do { Start-Sleep -Milliseconds 200 }
	until ( $Script:CustomMsgBoxHandle.IsCompleted -eq $true )

	return $Script:CustomMsgBoxHash.Answer
}

function Show-MessageBox
{
	<#
	.Synopsis
		Display a messagebox with given text
	.Description
		Display a messagebox with given text, and, if defined, title, icon and button/-s
	.Parameter Text
		The text to display in the messagebox
	.Parameter Title
		A string to display in the title of the messagebox
	.Parameter Button
		What buttons are to be used/visible in the messagebox
	.Parameter Icon
		What icon is to be displayed in the messagebox
	.Outputs
		Returns which button in the messagebox was clicked
	#>

	param (
		[string] $Text,
		[string] $Title = "",
		[string] $Button = "OK",
		[string] $Icon = "Info"
	)

	return [System.Windows.MessageBox]::Show( "$Text", "$Title", "$Button", "$Icon" )
}

function Show-Splash
{
	<#
	.Synopsis
		Shows a small window at the center of the screen with given text
	.Parameter Text
		The text to show
	.Parameter Duration
		How long the text should be shown. Defaults is 1.5 seconds
	.Parameter BorderColor
		The color of the border of the window
	.Parameter SelfAdmin
		The script calling will administrate opening and closing
	.State
		Prod
	.Author
		Smorkster (smorkster)
	#>

	param (
		[string] $Text,
		[string] $Title = $IntMsgTable.ShowSplashStrDefaultMainTitle,
		[double] $Duration = 1.5,
		[string] $BorderColor = "Green",
		[double] $SelfProgress,
		[switch] $NoProgressBar,
		[switch] $NoTitle,
		[switch] $SelfAdmin
	)

	$LabelText = $Text
	$Script:SplashHash = [hashtable]::Synchronized( @{} )

	if ( $NoProgressBar ) { $ProgressBarVisibility = "Collapsed" }
	else { $ProgressBarVisibility = "Visible" }

	if ( $NoTitle ) { $Title = "" }

	if ( $SelfProgress ) { $ProgressIndeterminate = "False" ; $ProgressMax = $SelfProgress ; $SelfAdmin = $true }
	else { $ProgressIndeterminate = "True" }

	$SplashRunspace = [runspacefactory]::CreateRunspace()
	$SplashRunspace.ApartmentState = "STA"
	$SplashRunspace.ThreadOptions = "ReuseThread"
	$SplashRunspace.Open()
	$SplashRunspace.SessionStateProxy.SetVariable( "hash", $Script:SplashHash )
	$SplashRunspace.SessionStateProxy.SetVariable( "LabelText", $LabelText )
	$SplashRunspace.SessionStateProxy.SetVariable( "Title", $Title )
	$SplashRunspace.SessionStateProxy.SetVariable( "ProgressBarVisibility", $ProgressBarVisibility )
	$SplashRunspace.SessionStateProxy.SetVariable( "ProgressIndeterminate", $ProgressIndeterminate )
	$SplashRunspace.SessionStateProxy.SetVariable( "ProgressMax", [double] $ProgressMax )
	$SplashRunspace.SessionStateProxy.SetVariable( "xml", ( [xml] ( Get-Content "$( ( Get-Item $PSCommandPath ).Directory.Parent.Parent.FullName )\GUI\Show-Splash.xaml" -Raw ) ) )
	$Script:SplashShell = [PowerShell]::Create()
	$Script:SplashShell.AddScript( {
		Add-Type -AssemblyName PresentationFramework

		$reader = New-Object System.Xml.XmlNodeReader $xml
		$hash.Window = [Windows.Markup.XamlReader]::Load( $reader )
		$hash.LoadingLabel = $hash.Window.FindName( "LoadingLabel" )
		$hash.Header = $hash.Window.FindName( "Header" )
		$hash.Progress = $hash.Window.FindName( "Progress" )

		$hash.Progress.IsIndeterminate = $ProgressIndeterminate
		$hash.Progress.Visibility = $ProgressBarVisibility
		$hash.Progress.Maximum = $ProgressMax
		$hash.Header.Content = $Title
		$hash.LoadingLabel.Content = $LabelText

		$hash.Window.ShowDialog()
	} ) | Out-Null
	# Open splash screen
	Start-SplashScreen

	if ( -not $SelfAdmin )
	{
		Start-Sleep -Seconds $Duration
		Close-SplashScreen
	}
	$Script:SplashHash.Shell = $script:SplashShell
}

function Start-SplashScreen
{
	<#
	.Synopsis
		Start runspace to display splash screen
	#>

	$Script:SplashShell.Runspace = $SplashRunspace
	$Script:SplashHandle = $Script:SplashShell.BeginInvoke()
}

function Update-SplashProgress
{
	<#
	.Synopsis
		Update the progressbar in the splash screen
	.Parameter Value
		Value to update the progressbar with
	#>

	param ( $Value )

	try { $Script:SplashHash.Window.Dispatcher.Invoke( "Normal", [action] { $Script:SplashHash.Progress.Value = $Value } ) } catch {}
}

function Update-SplashText
{
	<#
	.Synopsis
		Update the text in the splash screen
	.Parameter Text
		Text to update the splash screen with
	#>

	param (
		$Text,
		[switch] $Append
	)

	if ( $Append )
	{
		try { $Script:SplashHash.Window.Dispatcher.Invoke( "Normal", [action] { $Script:SplashHash.LoadingLabel.Content += $Text } ) } catch {}
	}
	else
	{
		try { $Script:SplashHash.Window.Dispatcher.Invoke( "Normal", [action] { $Script:SplashHash.LoadingLabel.Content = $Text } ) } catch {}
	}
}

$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.Parent.FullName
Import-LocalizedData -BindingVariable IntMsgTable -UICulture $culture -FileName "$( ( Get-Item $PSCommandPath ).BaseName ).psd1" -BaseDirectory "$RootDir\Localization"

$Converters = @"
using System;
using System.DirectoryServices;
using System.DirectoryServices.AccountManagement;
using System.Drawing;
using System.Globalization;
using System.Text.RegularExpressions;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Xaml;

namespace FetchalonConverters
{
	public class ADUserConverter : IValueConverter
	{
		/// <summary>Convert a SamAccountName (userId) to the username, according to AD</summary>
		public object Convert ( object value, Type targetType, object parameter, CultureInfo culture )
		{
			if (string.IsNullOrEmpty( ( string ) value ) || value == null )
			{
				return "";
			}
			else
			{
				string Id;
				if ( ( ( string ) value ).IndexOf( '(' ) == -1 )
				{
					Id = ( string ) value;
				}
				else
				{
					Id = ( ( string ) value ).Split( '(' )[1].Split( ')' )[0];
				}

				PrincipalContext pc = new PrincipalContext( ContextType.Domain, "CodeConverterADDomainName", "CodeConverterADContainer" );
				UserPrincipal up = new UserPrincipal( pc ) { SamAccountName = Id };
				PrincipalSearcher ps = new PrincipalSearcher(up);

				try
				{
					var u = ps.FindOne();
					if ( u == null )
						return value;
					else
						return u.Name;
				}
				catch ( Exception e )
				{
					return e.Message;
				}
			}
		}

		public object ConvertBack ( object value, Type targetType, object parameter, CultureInfo culture )
		{
			throw new NotImplementedException();
		}
	}

	public class ADGrpDistNameConverter : IValueConverter
	{
		/// <summary>Convert an AD-groups DistinguishedName to its name</summary>
		public object Convert ( object value, Type targetType, object parameter, CultureInfo culture )
		{
			DirectoryEntry de = new DirectoryEntry( "LDAP://CodeConverterADContainer" );
			DirectorySearcher adsSearcher = new DirectorySearcher( de )
			{
				Filter = "(DistinguishedName=" + (string)value + ")"
			};

			var res = ( adsSearcher.FindOne() ).GetDirectoryEntry();
			return res.Name.Split( '=' )[1];
		}

		public object ConvertBack ( object value, Type targetType, object parameter, CultureInfo culture )
		{
			throw new NotImplementedException();
		}
	}

	public class ADUserOtherTelephoneFormater : IValueConverter
	{
		/// <summary>Format items in an AD-users otherTelephone-collection</summary>
		public object Convert ( object value, Type targetType, object parameter, CultureInfo culture )
		{
			string[] outFormat;
			if ( Regex.IsMatch( ( ( string ) value ), @"\+\d\d8" ) )
			{
				outFormat = Regex.Split( ( ( string ) value ), @"(\+\d\d)(\d)(\d\d\d)(\d\d)" );
			}
			else
			{
				outFormat = Regex.Split( ( ( string ) value ), @"(\+\d\d)(\d\d)(\d\d\d)(\d\d)" );
			}
			string formated = ( ( string.Join( " ", outFormat ) ).Trim() ).Insert( 4, "0" );

			return ( object ) formated;
		}

		public object ConvertBack ( object value, Type targetType, object parameter, CultureInfo culture )
		{
			throw new NotImplementedException();
		}
	}

	public class StringDateToDate : IValueConverter
	{
		/// <summary>Convert string to DateTime</summary>
		public object Convert ( object value, Type targetType, object parameter, CultureInfo culture )
		{
			return ( object ) DateTime.Parse( ( string ) value );
		}

		public object ConvertBack ( object value, Type targetType, object parameter, CultureInfo culture )
		{
			throw new NotImplementedException();
		}
	}

	public class WidthLessThan : IValueConverter
	{
		public object Convert ( object value, Type targetType, object parameter, CultureInfo culture )
		{
			return double.Parse( value.ToString() ) < int.Parse( parameter.ToString() );
		}

		public object ConvertBack ( object value, Type targetTypes, object parameter, CultureInfo culture )
		{
			throw new NotImplementedException();
		}
	}

	public class MiVisible : IValueConverter
	{
		public object Convert ( object value, Type targetType, object parameter, CultureInfo culture )
		{
			return double.Parse( value.ToString() ) < int.Parse( parameter.ToString() );
		}

		public object ConvertBack ( object value, Type targetTypes, object parameter, CultureInfo culture )
		{
			throw new NotImplementedException();
		}
	}

	public class ValidComputer : IValueConverter
	{
		public object Convert ( object value, Type targetType, object parameter, CultureInfo culture )
		{
			if ( value == null )
			{
				return false;
			}
			else
			{
				DirectoryEntry de = new DirectoryEntry( "LDAP://CodeConverterADContainer" );
				DirectorySearcher adsSearcher = new DirectorySearcher( de )
				{
					Filter = "(Name=" + (string)value + ")"
				};

				try { return null != ( adsSearcher.FindOne() ).GetDirectoryEntry(); }
				catch { return false ; }
			}
		}

		public object ConvertBack ( object value, Type targetTypes, object parameter, CultureInfo culture )
		{
			throw new NotImplementedException();
		}
	}

	public class IcItemTemplateSelector : DataTemplateSelector
	{
		public DataTemplate BoolTpl { get; set; }
		public DataTemplate ConvertedUserTpl { get; set; }
		public DataTemplate DateTimeTpl { get; set; }
		public DataTemplate DefaultTpl { get; set; }
		public DataTemplate GroupTpl { get; set; }
		public DataTemplate StringTpl { get; set; }
		public DataTemplate UserTpl { get; set; }

		public override DataTemplate SelectTemplate ( object item, System.Windows.DependencyObject container )
		{
			try
			{
				if ( item.GetType() == typeof( bool ) )
				{
					return BoolTpl;
				}
				else if ( item.GetType() == typeof( DateTime ) )
				{
					return DateTimeTpl;
				}
				else if ( item.GetType() == typeof( String ) )
				{
					DirectoryEntry de = new DirectoryEntry( "LDAP://CodeConverterADContainer" );
					DirectorySearcher adsSearcher = new DirectorySearcher( de )
					{
						Filter = "(DistinguishedName=" + ( string ) item + ")"
					};

					var res = ( adsSearcher.FindOne() ).GetDirectoryEntry();
					var c = res.Properties["objectClass"].Count;
					string oc = res.Properties["objectClass"][c - 1].ToString();
					if ( oc.Equals( "user" ) )
					{
						return UserTpl;
					}
					else if ( oc.Equals( "group" ) )
					{
						return GroupTpl;
					}
					else
					{
						return StringTpl;
					}
				}
			}
			catch
			{}
			return DefaultTpl;
		}
	}
}
"@ -replace "CodeConverterADDomainName", "$( $IntMsgTable.CodeConverterADDomainName )" -replace "CodeConverterADContainer", "$( $IntMsgTable.CodeConverterADContainer )"

if ( $LoadConverters ) { LoadConverters }

$CallingScript = try { ( Get-Item $MyInvocation.PSCommandPath ) } catch { [pscustomobject]@{ BaseName = "NoScript" } }
try { $Host.UI.RawUI.WindowTitle = "$( $IntMsgTable.ConsoleWinTitlePrefix ): $( ( ( Get-Item $MyInvocation.PSCommandPath ).FullName -split "Script" )[1] )" } catch {}

Export-ModuleMember -Function BindControls, CreateWindow, CreatePage, CreateWindowExt,
							Close-SplashScreen, Show-Splash, Update-SplashProgress, Update-SplashText,
							Show-CustomMessageBox, Show-MessageBox
Export-ModuleMember -Variable Converters

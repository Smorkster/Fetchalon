<#
.Synopsis A module for functions creating and working with GUI's
.State Prod
.Author Smorkster
#>

param (
	[string] $culture = "sv-SE",
	[switch] $LoadConverters
)

function BindControls
{
	<#
	.Synopsis Create bindings between controls and an associated collections of predefined values
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
					{ [void] [System.Windows.MessageBox]::Show( "$( $control.CName ) $( $IntmsgTable.ErrControlDuplicate ) " ) }
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
					[void] $GenErrors.Add( "$n$( $IntmsgTable.ErrNoProperty ) '$p'")
					$syncHash.GenErrors.Add($_)
				}
			}
		}
		else
		{
			[void] $GenErrors.Add( "$( $IntmsgTable.ErrNoControl ) $n" )
			$syncHash.GenError.Add( $_ )
		}
	}

	# List errors from when binding controls and properties
	if ( $GenErrors.Count -gt 0 )
	{
		$ofs = "`n"
		[void] [System.Windows.MessageBox]::Show( "$( $IntmsgTable.ErrAtGen ):`n`n$GenErrors" )
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
		Write-Host "$( $IntmsgTable.ErrReadingXaml )`n`n" -Foreground Cyan
		Write-Host "Error" -Foreground Red
		Write-Host "$( $_.Exception )`n`n"
		Read-Host $IntmsgTable.ErrReadingXamlExit
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
	.Outputs A synchronized hashtable with the page and some usefull collections
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
		throw
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
	try
	{
		Add-Type -ReferencedAssemblies Microsoft.ActiveDirectory.Management, `
										PresentationFramework, `
										System.DirectoryServices, `
										System.DirectoryServices.AccountManagement, `
										System.Management.Automation, `
										System.Windows, `
										System.Xaml, `
										C:\Windows\WinSxS\x86_microsoft.activedirectory.management_31bf3856ad364e35_6.3.9600.19537_none_ad6ee7559191f544\Microsoft.ActiveDirectory.Management.dll,
										C:\Windows\Microsoft.NET\Framework\v4.0.30319\WPF\WindowsBase.dll -TypeDefinition $Converters -ErrorAction Stop
	}
	catch
	{
		Add-Type -ReferencedAssemblies Microsoft.ActiveDirectory.Management, `
										PresentationFramework, `
										System.DirectoryServices.AccountManagement, `
										System.DirectoryServices, `
										System.Management.Automation, `
										System.Xaml, `
										System.Windows, `
										C:\Windows\Microsoft.NET\Framework\v4.0.30319\WPF\WindowsBase.dll -TypeDefinition $Converters -ErrorAction Stop
	}
}

function Close-SplashScreen
{
	<#
	.Synopsis Close the splash screen
	.Parameter Duration
		Duration to wait before closing the splash screen
	#>

	param ( [int] $Duration )

	if ( $Duration )
	{
		Start-Sleep -Seconds $Duration
	}
	$Script:hash.Window.Dispatcher.Invoke( "Normal", [action]{ $Script:hash.Window.Close() } )
	$Script:Pwshell.EndInvoke( $handle ) | Out-Null
}

function Start-SplashScreen
{
	<#
	.Synopsis Start runspace to display splash screen
	#>

	$Script:Pwshell.Runspace = $runspace
	$Script:handle = $Script:Pwshell.BeginInvoke()
}

function Update-SplashProgress
{
	<#
	.Synopsis Update the progressbar in the splash screen
	.Parameter Value
		Value to update the progressbar with
	#>

	param ( $Value )

	try { $Script:hash.Window.Dispatcher.Invoke( "Normal", [action] { $Script:hash.Progress.Value = $Value } ) } catch {}
}

function Update-SplashText
{
	<#
	.Synopsis Update the text in the splash screen
	.Parameter Text
		Text to update the splash screen with
	#>

	param ( $Text )

	try { $Script:hash.Window.Dispatcher.Invoke( "Normal", [action] { $Script:hash.LoadingLabel.Content = $Text } ) } catch {}
}

function ShowSplash
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
	#>

	param (
		[string] $Text,
		[string] $Title = $IntmsgTable.StrDefaultMainTitle,
		[double] $Duration = 1.5,
		[string] $BorderColor = "Green",
		[double] $SelfProgress,
		[switch] $NoProgressBar,
		[switch] $NoTitle,
		[switch] $SelfAdmin
	)

	$LabelText = $Text
	$Script:hash = [hashtable]::Synchronized( @{} )

	if ( $NoProgressBar ) { $ProgressBarVisibility = "Collapsed" }
	else { $ProgressBarVisibility = "Visible" }

	if ( $NoTitle ) { $Title = "" }

	if ( $SelfProgress ) { $ProgressIndeterminate = "False" ; $ProgressMax = $SelfProgress ; $SelfAdmin = $true }
	else { $ProgressIndeterminate = "True" }

	$runspace = [runspacefactory]::CreateRunspace()
	$runspace.ApartmentState = "STA"
	$Runspace.ThreadOptions = "ReuseThread"
	$runspace.Open()
	$runspace.SessionStateProxy.SetVariable( "hash", $Script:hash )
	$runspace.SessionStateProxy.SetVariable( "LabelText", $LabelText )
	$runspace.SessionStateProxy.SetVariable( "Title", $Title )
	$runspace.SessionStateProxy.SetVariable( "ProgressBarVisibility", $ProgressBarVisibility )
	$runspace.SessionStateProxy.SetVariable( "ProgressIndeterminate", $ProgressIndeterminate )
	$runspace.SessionStateProxy.SetVariable( "ProgressMax", [double] $ProgressMax )
	$Script:Pwshell = [PowerShell]::Create()
	$Script:Pwshell.AddScript( {
		Add-Type -AssemblyName PresentationFramework
		$xml = [xml]@"
	<Window
		xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
		xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
		x:Name="WindowSplash" WindowStyle="None" WindowStartupLocation="CenterScreen"
		Background="Green" ShowInTaskbar ="False"
		SizeToContent="WidthAndHeight" ResizeMode = "NoResize" Topmost="True">
		<Window.Resources>
			<Style TargetType="Label"
				   x:Key="LblBaseStyle">
				<Setter Property="Foreground"
						Value="White" />
				<Style.Triggers>
					<Trigger Property="Content"
							 Value="">
						<Setter Property="Visibility"
								Value="Collapsed" />
					</Trigger>
				</Style.Triggers>
			</Style>
		</Window.Resources>
		<Grid>
			<Grid.RowDefinitions>
				<RowDefinition Height="Auto" />
				<RowDefinition/>
			</Grid.RowDefinitions>
			<Label Name="Header" Margin="5,0,0,0" Height="50" FontSize="30" Content="$Title" Style="{StaticResource LblBaseStyle}" />
			<Grid Grid.Row="1">
				<StackPanel Orientation="Vertical" HorizontalAlignment="Center" VerticalAlignment="Center" Margin="5">
					<Label Name="LoadingLabel" HorizontalAlignment="Center" VerticalAlignment="Center" FontSize="24" Margin="0" Content="$LabelText" Style="{StaticResource LblBaseStyle}" />
					<ProgressBar Name="Progress" IsIndeterminate="$ProgressIndeterminate" Foreground="White" HorizontalAlignment="Center" Width="350" Height="20" Visibility="$ProgressBarVisibility" Maximum="$ProgressMax" />
				</StackPanel>
			</Grid>
		</Grid>
	</Window>
"@
		$reader = New-Object System.Xml.XmlNodeReader $xml
		$hash.Window = [Windows.Markup.XamlReader]::Load( $reader )
		$hash.LoadingLabel = $hash.Window.FindName( "LoadingLabel" )
		$hash.Header = $hash.Window.FindName( "Header" )
		$hash.Progress = $hash.Window.FindName( "Progress" )
		$hash.Window.ShowDialog()
	} ) | Out-Null
	# Open splash screen
	Start-SplashScreen

	if ( -not $SelfAdmin )
	{
		Start-Sleep -Seconds $Duration
		Close-SplashScreen
	}
}

$Converters = @"
using System;
using System.DirectoryServices;
using System.DirectoryServices.AccountManagement;
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
		public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
		{
			if (string.IsNullOrEmpty((string)value) || value == null)
			{
				return "";
			}
			else
			{
				string Id;
				if (((string)value).IndexOf('(') == -1)
				{
					Id = (string)value;
				}
				else
				{
					Id = ((string)value).Split('(')[1].Split(')')[0];
				}

				PrincipalContext pc = new PrincipalContext(ContextType.Domain, "domain.test.com", "DC=domain,DC=test,DC=com");
				UserPrincipal up = new UserPrincipal(pc) { SamAccountName = Id };
				PrincipalSearcher ps = new PrincipalSearcher(up);
				var u = ps.FindOne();
				if (u == null) return value;
				else return u.Name;
			}
		}

		public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
		{
			throw new NotImplementedException();
		}
	}

	public class ADGrpDistNameConverter : IValueConverter
	{
		/// <summary>Convert an AD-groups DistinguishedName to its name</summary>
		public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
		{
			DirectoryEntry de = new DirectoryEntry("LDAP://DC=domain,DC=test,DC=com");
			DirectorySearcher adsSearcher = new DirectorySearcher(de)
			{
				Filter = "(DistinguishedName=" + (string)value + ")"
			};

			var res = (adsSearcher.FindOne()).GetDirectoryEntry();
			return res.Name.Split('=')[1];
		}

		public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
		{
			throw new NotImplementedException();
		}
	}

	public class ADUserOtherTelephoneFormater : IValueConverter
	{
		/// <summary>Format items in an AD-users otherTelephone-collection</summary>
		public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
		{
			string[] outFormat;
			if (Regex.IsMatch(((string)value), @"\+\d\d8"))
			{
				outFormat = Regex.Split(((string)value), @"(\+\d\d)(\d)(\d\d\d)(\d\d)");
			}
			else
			{
				outFormat = Regex.Split(((string)value), @"(\+\d\d)(\d\d)(\d\d\d)(\d\d)");
			}
			string formated = ((string.Join(" ", outFormat)).Trim()).Insert(4, "0");

			return (object)formated;
		}

		public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
		{
			throw new NotImplementedException();
		}
	}

	public class StringDateToDate : IValueConverter
	{
		/// <summary>Convert string to DateTime</summary>
		public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
		{
			return (object)DateTime.Parse((string)value); ;
		}

		public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
		{
			throw new NotImplementedException();
		}
	}

	public class WidthLessThan : IValueConverter
	{
		public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
		{
			return double.Parse(value.ToString()) < int.Parse(parameter.ToString());
		}

		public object ConvertBack(object value, Type targetTypes, object parameter, CultureInfo culture)
		{
			throw new NotImplementedException();
		}
	}

	public class MiVisible : IValueConverter
	{
		public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
		{
			return double.Parse(value.ToString()) < int.Parse(parameter.ToString());
		}

		public object ConvertBack(object value, Type targetTypes, object parameter, CultureInfo culture)
		{
			throw new NotImplementedException();
		}
	}

	public class ValidComputer : IValueConverter
	{
		public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
		{
			if ( value == null )
			{
				return false;
			}
			else
			{
				DirectoryEntry de = new DirectoryEntry("LDAP://DC=domain,DC=test,DC=com");
				DirectorySearcher adsSearcher = new DirectorySearcher(de)
				{
					Filter = "(Name=" + (string)value + ")"
				};

				try { return null != (adsSearcher.FindOne()).GetDirectoryEntry(); }
				catch { return false ; }
			}
		}

		public object ConvertBack(object value, Type targetTypes, object parameter, CultureInfo culture)
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
					DirectoryEntry de = new DirectoryEntry("LDAP://DC=domain,DC=test,DC=com");
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
"@

if ( $LoadConverters ) { LoadConverters }

$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.FullName
Import-LocalizedData -BindingVariable IntmsgTable -UICulture $culture -FileName "$( ( $PSCommandPath.Split( "\" ) | Select-Object -Last 1 ).Split( "." )[0] ).psd1" -BaseDirectory "$RootDir\Localization\$culture\Modules"

$CallingScript = try { ( Get-Item $MyInvocation.PSCommandPath ) } catch { [pscustomobject]@{ BaseName = "NoScript" } }
try { $Host.UI.RawUI.WindowTitle = "$( $IntmsgTable.ConsoleWinTitlePrefix ): $( ( ( Get-Item $MyInvocation.PSCommandPath ).FullName -split "Script" )[1] )" } catch {}

Export-ModuleMember -Function BindControls, CreateWindow, CreatePage, CreateWindowExt, Close-SplashScreen, Update-SplashProgress, Update-SplashText, ShowSplash

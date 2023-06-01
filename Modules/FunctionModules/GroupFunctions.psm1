<#
.Synopsis A collection of functions to run for a group object
.Description A collection of functions to run for a group object
.ObjectClass Group
.State Prod
.Author Smorkster (smorkster)
#>

param ( $culture = "sv-SE" )

$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.Parent.FullName

Import-LocalizedData -BindingVariable IntMsgTable -UICulture $culture -FileName "$( ( $PSCommandPath.Split( "\" ) | Select-Object -Last 1 ).Split( "." )[0] ).psd1" -BaseDirectory "$RootDir\Localization"

Export-ModuleMember -Function *

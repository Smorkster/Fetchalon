# Fetchalon
Fetch AD-objects, run module-functions or separate scripts and display them, or output from them, in a single GUI.

The purpose of this suite is to give IT-support personel a unified GUI to search for, and handle simple actions, for objects in Active Directory.

<br>

## Search explanation
The main GUI is operated mainly from the textbox at the top, where you enter something to search for. If the item is found, its parameters are displayed in a list in the area below.

You can search for:
  * AD-user
      * This search looks for SamAccountName
  * AD-group
    * This search looks for Name or id
  * Printerqueues that have an object in AD
    * This search looks for Name
  * IP-address
    * This search verifies if the address can be found with [System.Net.Dns]::GetHostByAddress(). If an host is found, check if hostname is an computer or printerqueue in AD
  * Directory-path - This looks for the full path. Does not correct spelling errors
  * File-path - This looks for the full path. Does not correct spelling errors
  * Powershell Get-cmdlets
    * You can run a Get-cmdlet, with an added pipeline. Although the textbox does not check for spelling or errors in the code. If the pipeline is successfull, the result will be displayed in the outputarea below. Otherwise the resulting errormessage will be displayed.
    * To check if an cmdlet pipeline was entered, the text is first checked if it starts with "(Get-\w*)\s*", then if a command with this name is loaded and available.

If no item is found, or an error occured, a message is displayed in the vieware under the searchbox.

If an AD-object, directory or file (in this text named SearchedItem) is found, its properties are loaded into two lists. One list that show a selection of properties, and one list that shows all properties. 

<br>

## GUI explanation
### Search area
At the top is the searchbox where you enter

To the left side of the menu, is an button you can use to show/hide the text for menuitem. This can be usefull if ou want more area to display SearchedItem or function output

<br>

### Menu area
There are three menus to the left, one for SearchedItem, one for function output history and one for functions, scripts
* For SearchedItem you can
    * Close - this removes SearchedItem for the GUI and resets controls
    * Detailed view - display the full list of properties of the SearcedItem
    * Copy - copy all properties of SearchedItem
    * Show / hide - this shows or hides the view for SearchedItem
* For the outputview, you can
    * Show / hide the view - this shows or hides the view for output
    * Output history - clicking this, displays a list for all output from functions, in descending order by time for output. Clicking an item, will display the output from that function run.
    * Each history item displays:
        * Time when the function was run
        * Name of the function that was run
        * Name of SearchedItem that the function was run for
* For functions/scripts/tools there are one toplevel menuitem for:
  * Each type of SearchedItem
  * One for "Other function"
  * One for functions operating on object in Office365/Azure. This is currently not implemented.
  * One for listing scripts (tools)
* The last (bottom) item is for sending feedback for functions and/or tools. The message will be sent to the author of the selected function/tool, and to the mailaddress for backoffice set in localization-file.

#### Menuitems visibility
A menuitem for a function or tool is not necessarily visible/usable all the time or for all users. By default all menuitems is visible, but there are rules that can be used that hides or makes them not usable at all.

##### Requiring the SearchedItem
A function can have three settings in the CodeInfo for requiring the current SearchedItem:
* Required - The function is requiring SearchedItem for its operations. With this setting, the corresponding menuitem will only be visible if SearchedItem is loaded and of the same objectclass as the function is operating on.
* Allowed - The function can take SearchedItem, but it is not required. The menuitem will always be visible.
* None - SearchedItem is ignored and the menuitem is always visible.

With the settings "Required" and "Allowed", if SearchedItem is loaded, the SearchedItem-object will be copied to the runspace where the function will execute. If the function takes any input, the property value for SamAccountName (Name if objectclass is "printQueue") of SearchedItem will be copied to the first textbox for userinput.

##### RequiredAdGroups
A function or tool can set a list of AD-groupnames that the operator must be member of to be able to use it. If the operator is not a direct member of any of the groups, a menuitem for the function/tool will not be created.

Groupmembership must be of the specific group, since there will not be any checking for permission inheritance.

##### AllowedUsers
A function can have a list of user identities, preferably SamAccountNames, for specific users that are allowed to use the function/tool. If a user-id is in this list, it supersedes the requirements of membership in any of the groups i RequiredAdGroups. If this setting in CodeInfo is set, and the operator is not listed, a menuitem for the function/tool will not be created.

<br>

### View / output area
To the right of the menuarea is the main viewing area where properties, function output and script GUI (see below) is displayed.

To display the different "views" the main GUI utilizes a Frame-control and uses navigation to load the views.

Above both property views are two buttons, one to select properties to display in selected view, and one to fetch extrainfo about SearchedItem.

#### Property view - selected properties
With this view the list of properties of SearchedItem is displayed. The properties you want to display are selected in the detailed properties view.

For each property, its name and value is displayed, and also two buttons. These buttons can:
* Run a propertyhandler. This will be displayed if a propertyhandler is loaded. Otherwise the button is hidden. The handler is loaded per propertyname and does not consider type of object. Object type filtering is planed for the future.
* Copy the property value.

#### Property view - detailed property list
This view will display all properties that have been found/fetched for SearchedItem. This view is simpler than selected view, in that it does not display items in lists, and does not show buttons for propertyhandlers or copying.

With the left button above this view, is a togglebutton. If it is clicked, you can select the properties you want to be displayed in selected view, by filling the attached checkbox. When done, click the toggle button again and the checked properties are loaded into the selected view.

The list of selected properties are saved to the usersettings (see below), and will be displayed the next time any object of same objectclass is searched for.

#### Output view
When a function or Get-cmdlet have finished, its output or error will be displayed in the output view. This view consists of:
* Title area
    * The title shows
        * The name of the cmdlet/function
        * Name of SearhedItem, if this was used in the function
        * Time the operation was finished
    * In the top right, are two buttons to copy
        * Data - the data from the output
        * Dataobject - an summary of the execution:
            * name and comment of function
            * SearchedItem
            * time and date
            * output from the function 
* Error info
* Output data
    * Depending on the type of the output, it will be displayed differently. The available outputtypes are
		* String - This will be displayed in a simple textblock
		* ObjectList - The data is displayed in a datagrid with a row for each pscustomobject and columns for each of the properties
		* List - The data is displayed in a listbox, mainly intended for a list of strings
            * If the list contains objects like belove, a list of hyperlinks will be created:<br>
		    [pscustomobject]@{ Address = $UrlToNavigateTo; Text = $TextToDisplayForTheLink ; Type = "Hyperlink" }
	* Two special situations for outputtype, that is set in the CodeInfo for a function:
        * None - If no data is returned from the function. If this is set, no outputhistory is put in the outputhistory-menu. This can be usefull for a simple function, i.e. one that only opens a webpage.
		* $null - This will be the value if OutputType-parameter is not set in CodeInfo of function. Output will then default to be displayed as String.
    
### Script/tool GUI view
If a tool is using an GUI created in WPF-XAML, its GUI can be displayed inside the Fetchalons main GUI window. This way, the number of windows will be limited, avoiding the desktop to be cluttered.

The GUI will be saved as a resource in the main window to enable navigation between views. Thus, clicking on the menuitem for a tool that have already been loaded, will display the tool in its state from when another view was displayed.

<br>

## Running functions / tools
When a menuitem is clicked a check is first made for what is to be run.
* If it is a tool, a second check is done:
  * Is the tool using the XAML-GUI functionality
    1. Load the XAML-code
    2. Import localization data and set it as DataContext for the tools Xaml-page
    3. Add the page-object to main GUI as a resource
    4. Import the module-file to make the functionality available
    5. Check if SearchedItem has same objectclass as the tools setting ObjectOperations in CodeInfo
        * If same - set a resource in the page-object with the name "SearchedItem" and SearchedItem as value
    6. Hide other views and navigate to the page-object in the resource to make it visible.
  * Is the script handling/creating GUI seperately
    * Check if the tool has already been opened
        * If opened, display the window
        * If not opened
            1. Create a PsCustomObject for storing the process. This will be stored in the menuitem for the tool. The object consists of
                * Async-handle pointer for runspace the process is running in
                * Runspace the process is running in
                * Eventlistener for process
                  * Waits for runspace where PowerShell is started. At event `InvocationStateChanged`, get process and MainWindowHandle for the script, and start Eventlistener for the process of the script
                * Eventlistener for runspace
                  * This listens for the event `Exited` from the process. When this occurs, remove the PsCustomObject-process object from the menuitem
                * An object that holds the process-object of PowerShell from starting the script
                  * This is used for identifying the window when it is to be displayed, in the first check after click on the menuitem
                * MainWindowHandle of the window that tool/script opened
                   * This is used for closing the window

During the function operations, a progressbar will be displayed above the Output-view, together with the function-name. The outputdata will be displayed differently depending on how it is formated.


## Writing functions
Functions are located in separate PSModule-files, one for each type of designated AD-objectclass, in the folder **Modules**. The files are:
  * **ComputerFunctions.psm1** - For AD-objects with objectclass _computer_
  * **DirectoryInfoFunctions.psm1** - For folder-objects, these will get objectclass set to _DirectoryInfo_ in the mainscript
  * **FileInfoFunctions.psm1** - For file-objects, these will get objectclass set to _FileInfo_ in the mainscript
  * **GroupFunctions.psm1** - For AD-objects with objectclass _group_
  * **PrintQueueFunctions.psm1** - For AD-objects with objectclass _printQueue_
  * **UserFunctions.psm1** - For AD-objects with objectclass _user_
  * **OtherFunctions.psm1** - This contains functions that does not depend on objectclass or AD-objects
  * **O365DistributionlistFunctions.psm1** - For Distributionlists in M365
  * **O365ResourceFunctions.psm1** - For Resource-objects in M365
  * **O365RoomFunctions.psm1** - For Room-objects in M365
  * **O365SharedMailboxFunctions.psm1** - For SharedMailbox-objects in M365
  * **O365UserFunctions.psm1** - For User-objects in M365
  * **SeparateToolsFunctions.psm1** - Used to start other tools and applications


When writing a function, the name must be unique. Good practice is to use approved verbs, and a descriptive wordcombination.

At the beginning, before any code, there must be CodeInfo to describe the function. Without this, the function will not be loaded into the GUI. For more detailed information about CodeInfo, see below.

After the CodeInfo, you can have the `param ( $InputData )` statement, and then continue with the code.

When the function is finished, return the data using normal `return`. See OutputType below for how the data is to be formated.

If an error has occurred, you can use the `throw` keyword inside the function to end operations with a message. This will be displayed as an error in the Output-view.

If you want to use language localization for strings, the variable will be available through the `IntMsgTable` hashtable that is imported when the module is loaded.

A function can have input in four different variations:
  * _None_
  * _SearchedItem_
  * _InputData_
  * _SearchedItem_ and _InputData_
    * When both are sent to the function, SearchedItem will always be the first parameter, and InputData the second.

### SearchedItem
If the function is to operating on the object that was searched for in the main GUI, as PsCustomObject with all available properties of the AD-object will be sent as a whole.

### InputData
When inputdata from the user is wanted, the data will be sent to the function as a hashtable as Name > String pairs. The entered inputdata will be available with the word that is set as the variable name in CodeInfo. The data will be sent formated as string, so any tokenization is up the author of the function.

<br>

## Writing tools
"Tool" is the name of scripts that can do a little bit more than the more simplified functions. These have their own GUI and will be loaded so that they can be reused, rather than run again.

When developing a tool, all files are placed in one folder, specific for that tool. The first decision to take, is if the GUI is to be placed inside the main GUI, or to have its own separate window. Depending on that decision, the scriptfile, and all of its assets, must be placed in the correct folder:
  * For tools with their own window, place the folder in the "SeparateTools"-folder
  * For tools that wants its GUI inside the main GUI, place the folder in the "PagedTools"-folder

### Separate tool
When creating a separate tool, all handling of any GUI will be up to the author.

### Paged tool
When creating a paged tool, there are some guidelines that must be followed:
  * The folder and all files, must have the same name
  * The folder must contain these files:
    * Tool.psd1 - This contains all localized strings.
    * Tool.psm1 - The main code for the tool.
    * Tool.xaml - The main GUI definition.
  * TODO The GUI must 

#### Tool.psd1
The localized hashtable will be used as part of the `DataContext` of the page (main window for the tool) and is accessible with the variablename `MsgTable`. The file must be formated as:

``` powershell
ConvertFrom-StringData @'
VarName = Some text
...
'@
```

#### Tool.psm1
This must be a PowerShell-module to enable easy switching of context when going between tool/functions/searching.

From the start an synchronized hashtable will be available with useful collections and hashtables. This will be available in $args[0] for the script.

The hashtable contains these keys:
  * **Bindings** - An hashtable containing an ObservableCollection for each found control in the XAML. These collections will contain binding objects for when binding dependency properties.
  * **Code** - An hashtable that can be used to place scriptblocks or other kind of code
  * **Controls** - An synchronized hashtable that contains all named controls in the XAML-file. If a controls does not have attribute Name="SomeName", it will not be detected and can not be found in **Controls**
  * **Data** - An hashtable intended to hold various data the author wants to use in the module code
    * **Data** will always have the variable "MainWindow" containing a reference the object for suite main window. This can be used to set as owner when calling Show-MessageBox from _GUIOps_
  * **DC** - An hashtable containing all binding-connections that was created at startup. This is very usefull when running code in a runspace, in that you do not have to call a GUI-dispatcher to invoke an action for every data update. Instead you call the binding by the name of the control and the index of the dependency property that was targeted for this binding.
    * To use a binding, reference the control by name inside **DC**, and then the index:
      * `$syncHash.DC.ProgressBar[0] = [double] 2` - here we update the value of a progressbar to '2'
  * **Errors** - An ArrayList intended for the author to store errors
  * **GenErrors** - An ArrayList that is mainly used to store errors when creating the Page-object. Though this will be available to the module
  * **Jobs** - Hashtable intended to store PsCustomObjects for runspace and its await handle
  * **Page** - This is the GUI XAML-page object of the tool that will be loaded inside the main GUI
  * **Root** - The full path of the folder for the suite

##### Binding control values 
When binding controlproperties, this should be done as early as possible in the code.

To set up what is to be bound, first create an ArrayList, then collect the properties for each control. Each entry must be a hashtable, formated per control and then a collection of propertynames and values:
```
@{ CName = <ControlName> ; Props = @( @{ PropName = <Property name> ; PropVal = <Intended property value> } ) }
```
Where:
  * CName = The name of the control set in XAML
  * Props = An collection of <PropName,PropVal> hashtables
  * PropName - The name of the dependency property to have bound, this must be available and correctly spelled. The binding function will append "Property" when setting the binding. So when i.e. binding value to a progressbar, only "Value" is needed
  * PropVal - The intended start value. This value will be used from start. Any value set in XAML will be overwritten.

The code for binding can thus look like this:

``` PowerShell
$controls = [System.Collections.ArrayList]::new()
[void]$controls.Add( @{ CName = "ProgressBar" ; Props = @( @{ PropName = "Value"; PropVal = [double] 0 } ; @{ PropName = "Maximum" ; PropVal = [double] 100 } ) } )
BindControls $syncHash $controls
```

When an menuitem gets clicked in the main window, this is what will happen:
  * If the tool is not loaded, the GUI and a synchronized hashtable (in this document named `hashtable`) is created. The hashtable is then sent to the module to make the controls available.
      1. A Page-object is created from the Xaml-file (see function `CreatePage` in the GUIOps-module)
      2. The creation will return the hashtable
      3. Any localized strings is imported and will be stored in `$hashtable.Data.msgTable`
         * To enable bindings for the strings in the Xaml-code, the localized strings will also be stored in an PsCustomObject in the DataContext of the Page-object
      4. The Page is then added as a resource in the main GUI window. This enables using navigation to the tool GUI.
         * The hashtable will also be available in the mainwindows resources with the name "LoadedPage<name of the tool>" to make all data available for debugging
      5. If the tool is "Send-Feedback", a list of all functions and tools is created and set as a resource for the tool. This so function/tool can be selected for feedback
      6. If SearchedItem has the same objectclass as specified in the ObjectOperations-parameter in the CodeInfo for the tool, SearchedItem will be stored as a resource for the tool, named `SearchedItem`. This way, the tool can start operating on the object when the tool is loaded
      7. With all objects created, the main GUI uses navigation to display the tool GUI
  * If the tool has already been loaded, the main GUI will navigate to the tools GUI

#### Tool.xaml
The Xaml-file _**must**_ have the top (root) element as a Page-control for the loading to work. The GUI will by default look like the rest of the main GUI, but all styling is up to the author.

Controls using text-fields can utilize bindings for the localized strings defined in the psd1-file by using this:
  * `{Binding ElementName=Window, Path=DataContext.MsgTable.StrCharLimits}`
    * The elementname must be the name the top element is given, in this example the page is named **Window**
    * The variablename of the localized string is used in the hashtable `MsgTable`, in this example **StrCharLimits**

Other than this, there is no limit on styling

<br>

## Available suite modules
These modules are imported when the main GUI is loaded and will automaticaly be available for all functions and tools.

### ConsoleOps.psm1
A collection of functions for doing operations inside a PowerShell-console. Available functions:
  * **AskDisplayOption** - Ask the user how data in specified file should be displayed
  * **GetConsolePasteInput** - Reads input from the console. The data is pasted with Ctrl + V
  * **GetUserChoice** - Display a question and run loop until a correct ansver, number up to MaxNum, or Y/N, is entered
  * **StartWait** - Initiates sleep with a progressbar and the defined text in the console
  * **TextToSpeech** - Use speech synthesizer to play a message

### FileOps.psm1
Functions to operate on files. Available functions:
  * **EndScript** - Print a message to inform that the script have finished and can be exited
  * **GetScriptInfo** - Get code information for assigned code. See CodeInfo
  * **GetUserInput** - Creates a file for input from user, then returns its content
  * **NewErrorLog** - Create a new errorlog object
  * **NewLog** - Create a new log object
  * **NewSurvey** - Create a new survey object
  * **WriteErrorlog** - Write error to errorlogfile
  * **WriteLog** - Writes to log-file
  * **WriteOutput** - Writes output to a file in the Output-folder
  * **WriteSurvey** - Write survey to file

### GUIOps.psm1
Functions to create GUI objects. Available functions:
  * **BindControls** - Create bindings between controls and an associated collections of predefined values
  * **CreatePage** - Create a synchronized hashtable for an WPF-page
  * **CreateWindow** - Creates a WPF-window, based on XAML-file with same name as the calling script
  * **CreateWindowExt** - Creates a synchronized hashtable for the window and binds listed properties of their controls to datacontext
  * **Show-MessageBox** - Display a messagebox with given text
  * **Show-Splash** - Shows a small window at the center of the screen with given text. To control the splash screen, these functions are available:
    * **Close-SplashScreen** - Close the splash screen
    * **Update-SplashProgress** - Update the progressbar in the splashscreen
    * **Update-SplashText** - Update the text in the splashscreen

### RemoteOps.psm1
Functions to operating on remote computer. Available functions:
  * **RunCycle** - Create a job that will check for updates for distributed applications
  * **SendToast** - Send a toastmessage to designated computer

### SysManOps.psm1
Functions for operating against SysMan. Available functions:
  * **ChangeInstallation** - Changes installed version of a deployed application for given computer
  * **GetSysManComputerId** - Get the internal id in SysMan for a given computer
  * **GetSysManUserId** - Get the internal id in SysMan for given user

<br>

## CodeInfo
CodeInfo is a section of parameters to descript the function or tool. It is formated like PowerShell's Comment Based Help. Most parameters are optional, but will make the function/tool easier to locate or will be more manageable.

The "**State**" parameter must be listed in the section, otherwise no menuitem will be created, and the function or tool can not be launched.

For functions, the CodeInfo _**must**_ be inside the '{}' brackets and before any code in functions, and before any code at the top of a tool script-file.

For tools the CodeInfo _**must**_ be at the start of the file.

### Parameters that can not be set in CodeInfo text
These parameters will be taken from functionname, filename
  * **Name** - Name of the function/tool. This will be the name of functions, or the name of the file for the tools psm1-file

#### Reserved for internal use
These are used by the main script for tools
  * **BaseDir** - Basedirectory of script file
  * **Localization** - File for localization for script
  * **PageObject** - Object for tool script to access controls and some default created lists
  * **Process** - Object for script process
  * **PS** - Full path of psm1 file for tools
  * **Xaml** - Full path for Xaml-file for tools
  * **Separate** - Indicate if the tool is loaded in separate window, or loaded with an Xaml-page in the main GUI. This will be set depending on if the tools files are located in the "SeparateTools" or "PagedTools" folder.

### Parameters available for both functions and tools
  * **AllowedUsers** - `[String[]]` List of user id's for people that are allowed to use funection/tool. This superseeds RequiredAdGroups
  * **Author** - `[String]` AD-name of author of tool/function
  * **Depends** - [Reserved for future use]
  * **Description** - `[String]` Description of function/tool. This is used for the tooltip of the menuitem
  * **MenuItem** - `[String]` A short string that is used as the text for the menuitem to describe the function/tool.
    * If this is not set, the text in Synopsis will be used.
    * If Synopsis is not set, the name of the function/tool will be used.
  * **RequiredAdGroups** - `[String[]]` A list of AD-groupnames the user must be a member of to be able to use. If the user is not a member, the function/tool will not be visible
  * **State** - `[String]` Production state of the function/tool.
    * Available values:
      * Test
      * Dev
      * Prod
  * **Synopsis** - `[String]` A short description of the function. This is displayed in the Output-view for functions, as tooltip for the textblock for functionname.

### Parameters available for functions only
  * **InputData** - `[String]` A variable that is to be used in the function. This can be listed multiple times in the following format: `.InputData VariableName Variabled description`
	  * This list will be sent to the function as a hashtable, so that the variablesnames can be used as listed, i.e.
	  * $InputData.VariableName
  * **NoRunspace** - `[None]` Used to signal that the function should not be run in a separate runspace. Can be useful if data is not properly sent to runspaces
  * **OutputType** - `[String]` How is the outputdata formated. If none or other than available is set, `[String]` will be used as default,
	  * If OutputType is set as List, the list can contain PsCustomObjects like belove and a list of hyperlinks will be created: `[pscustomobject]@{ Address = $UrlToNavigateTo; Text = $TextToDisplayForTheLink ; Type = "Hyperlink" }`
	  * Available types:
		  * String - This will be displayed in a simple textblock
		  * ObjectList - The data is displayed in a datagrid with a row for each pscustomobject and columns for each of the parameters
		  * List - The data is displayed in a listbox, mainly intended for a list of strings
		  * None - If no data is returned from the function. If this is used no outputhistory is put in the outputhistory-menu
		  * $null - This will be the value if OutputType-parameter is not set in function-info. Output will then default as String.
  * **SearchedItemRequest** - `[String]` Indicate if SearchedItem from the main GUI is to be copied to the function, and also if the function is dependet of it.
	  * If Required is set, the menuitem will not be visible if no AD-object is loaded from search or an AD-object of other objectclass was searched for.
	  * Available values:
		  * Allowed - Meaning that if no SearchedItem is loaded, the function can be used, is SearchedItem is loaded it will be sent to the function
		  * None - SearchedItem is ignored and the function will always be visible
		  * Required - SearchedItem is required for the function, if no AD-object is loaded, or object is of other objectclass, the menuitem is not visible

#### Parameters available for tools only
  * **ObjectOperations** - `[String]` What type of objectclass is the function/tool targeting.
    * If this is used, the menuitem for the tool will be inserted in the corresponding functions-menu. If SearchedItem is loaded, it will be copied to the `DataContext` of the tools main Page object when the tool is opened or made visible.
    * If this is not set, the menuitem for the tool will be inserted in the general "Tools"-menu.

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
  * Is the tool using the XAML-GUI functionality, import the module-file to make the functionality available
  * Is the script handling/creating GUI seperately, then check if the tool has already been opened
      * If opened, display the window
      * If not opened, run the script to start the tool

During the function operations, a progressbar will be displayed above the Output-view, together with the function-name. The outputdata will be displayed differently depending on how it is formated.

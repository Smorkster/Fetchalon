﻿ConvertFrom-StringData @'
CodeLockoutAddress = \\\\test.domain.com\\LockedoutLogs\$
CodeMsExchIgnoreOrg = OU=Org1
CodeOrgGrpCaptureRegex = CN=Org1_Wrk_(?<org>.{3})_PR_(?<role>.*_PC).*
CodeOrgGrpNamePrefix = CN=Org1_Wrk
CodeRegExAclIdentity = ^Domain.*_(C|R)$
ContentBtnClearPrintQueue = Clear queue
ContentBtnCopyOutputData = Data
ContentBtnCopyOutputObject = Dataobject
ContentBtnCopyValue = Copy
ContentBtnDirView = Show
ContentBtnEnterFunctionInput = Run script
ContentBtnFetch = Fetch
ContentBtnFileView = Show
ContentBtnGetExtraInfo = Fetch extra info
ContentBtnOpenHomeDirectory = Open in Explorer
ContentBtnOpenPrinterWebPage = Open printer in browser
ContentBtnRunVirusScan = Run virus check
ContentBtnSearch = Search
ContentBtnUserChangeActive = Save
ContentBtnUserChangeLockedOut = Save
ContentCbObjActive = Active
ContentCbSearchType = User, Computer, Group, Printer, All
ContentCbSearchTypeComputer = Computer
ContentCbSearchTypeGroup = AD-group
ContentCbSearchTypeGroupToolTip = Searching an AD group may take longer if the search term is not specific enough. Therefore, this search is not included by default.
ContentCbSearchTypePrinter = Printer
ContentCbSearchTypeUser = User
ContentChBGetComputerWarranty = Warranty period
ContentChBGetFromComputerProcesses = Processer
ContentChBGetFromComputerWmi = Computer (WMI)
ContentChBGetFromPrintQueuePrintJobs = Printer queue
ContentChBGetFromSysMan = SysMan
ContentChBGetFromUserLockOut = Lockout list
ContentDgObjadminDescriptionColDate = End date
ContentDgObjadminDescriptionColId = Permission
ContentDgProcessListColName = Name
ContentDgProcessListColProcessPercent = Percent CPU
ContentDgSearchResultsColNameCount = object)
ContentDgSearchResultsColNameTitle = Name (
ContentDgSearchResultsColObjClass = Objecttype
ContentGrpBSysManInfo = SysMan Info
ContentLblNoSearchResults = No AD objects
ContentLblSearchTypeTitle = Search for:
ContentLblUserADActiveCheck = AD Active
ContentLblUserADCheck = Available in AD
ContentLblUserADLockCheck = AD Unlocked
ContentLblUserADMailCheck = Email attribute set
ContentLblUserADmsECheck = msExchMailboxGuid
ContentLblUserOAccountCheck = O365-account created
ContentLblUserOExchCheck = Synced to Exchange
ContentLblUserOLicCheck = Has E3 license
ContentLblUserOLoginCheck = O365 login active
ContentLblUserOMigCheck = Member of O365-MigPilots
ContentLblUserPasswordNeedChange = The password has not changed since the new password policy was changed
ContentMiObjDetailedHide = Simplified view
ContentMiObjectContextSysMan = SysMan
ContentMiObjectContextSysManComputerUninstall = Uninstall system
ContentNoMembersOfList = < No values >
ContentRbPrintQueuePrintColorFalse = Black and white
ContentRbPrintQueuePrintColorTrue = Color printing
ContentSavePropValueButton = Save
ContentTblAdEnabled = Item marked 'Active' in AD
ContentTblADGroupsTitle = AD groups
ContentTbladminDescription = Local admin permission (with expiration date)
ContentTblADOwnerTitle = Owner
ContentTblBrdSMactiveDirectoryOperatingSystemNameVersion = Operating system
ContentTblComputerDNSHostName = DNS Hostname
ContentTblComputerLastLogonDate = Latest time for login
ContentTblComputerManagedBy = Owner / contact person
ContentTblComputerOperatingSystem = Operating system
ContentTblComputerSamAccountName = SamAccountName
ContentTblConnectedSharedAccount = Linked feature account
ContentTblCopyOutput = Copy:
ContentTblDataStreamsTitle = Alternative data streams
ContentTblDescriptionTitle = Description of the AD object
ContentTblDirectoryInventoryCountTitle = Folder contents
ContentTblDirectoryListTitle = Contents of the folder
ContentTblExtensionTitle = File extension
ContentTblFailedSearchText = No items matched your search
ContentTblFileSizeTitle = File size
ContentTblGetFromTitle = Get information from:
ContentTblGroupId = Id
ContentTblGroupOrgDn = HR placement
ContentTblLockedOut = Object locked in AD
ContentTblLockoutListTitle = List of lockouts in AD
ContentTblLogonWorkstations = Connected to computer
ContentTblMemberOf = MemberOf
ContentTblMembers = Members
ContentTblMiAboutText = Ifs and buts
ContentTblMiCloseObj = Close object view
ContentTblMiComputerFunctionsText = Computer
ContentTblMiConnectO365ServicesText = Connect O365 Services
ContentTblMiCopyObj = Copy everything
ContentTblMiCopyObjSelected = Copy selected
ContentTblMiGroupFunctionsText = Group
ContentTblMiHideExtraInfo = Hide extra information
ContentTblMiHideObj = Hide AD objects
ContentTblMiHideOutputView = Hide the output view
ContentTblMiO365Text = Office 365
ContentTblMiObjDetailed = Detailed view
ContentTblMiOtherFunctions = Other functions
ContentTblMiOutputHistoryText = Output history
ContentTblMiPrintQueueFunctionsText = Printer
ContentTblMiShowExtraInfo = Show extra information
ContentTblMiShowObj = View AD objects
ContentTblMiShowOutputView = Show the output view
ContentTblMiToolsText = Tools
ContentTblMiUserFunctionsText = User
ContentTblObjMenuTitle = Object activities
ContentTblOtherTelephone = Telephone number (according to AD)
ContentTblOutputErrorsTitle = Error in execution
ContentTblOutputMenuTitle = The output view
ContentTblOutputTitle = Data from
ContentTblPrintQueueDriverName = Driver
ContentTblPrintQueueLocation = Location
ContentTblPrintQueuePortName = IP-address
ContentTblPrintQueuePrintColor = Color printing
ContentTblPrintQueuePrintDuplexSupported = Double-sided printing
ContentTblPrintQueueShortServerName = Print server
ContentTblPropHandlerTitle = Handler
ContentTblPropHandlerTitleEmpty = No handler specified, button will not be displayed
ContentTblPropHandleTitleTitle = Text for button
ContentTblPropNameTT = Data source
ContentTblProxyAddresses = Proxy addresses
ContentTblReadPermissionsTitle = Read permission
ContentTblSearchHint = You can search by ID, group name, printer queue, IP address, or specify the path to a folder or file
ContentTblSMAzureDevicess = Registered mobile devices in Azure
ContentTblSMAzureMemberships = Azure membership
ContentTblSMclientLogins = Client logins
ContentTblSMManufacturerModel = Manufacturer / model
ContentTblSMPrintJobs = Print job
ContentTblSMProcessList = Active processes
ContentTblSMSerial = Serial number
ContentTblUserHomeDirectory = Home directory
ContentTblUserMail = E-mail
ContentTblUserPasswordLastSet = Password last changed
ContentTblUserUserPrincipalName = UserPrincipalName
ContentTblWarrantyTitle = Warranty period end date
ContentTblVisiblePropsTitle = Tick the values to be displayed in general view
ContentTblWritePermissionsTitle = Write permission
ContentTBtnObjectDetailed = Select attributes to display in the default view
ContentTTMiCloseObj = Close the view and forget the object
ContentTTMiCopyObj = Copy all data from the object
ContentTTMiCopyObjSelected = Copy selected data from the object
ContentTTMiObjDetailed = View detailed list
ContentTTMiObjDetailedHide = Show simplified list
ContentTTMiObjDetailedShow = View detailed list
ContentTTTblContentTblMiShowHideObj = Show/hide the view for AD objects
ContentTTTblContentTblMiShowHideOutputView = Show/hide the output view
ContentTTTblMiShowHideExtraInfo = Show/hide other information
DgSMPrintJobsColDocumentName = Document name
DgSMPrintJobsColJobStatus = Status
DgSMPrintJobsColSubmittedTime = Sent
DgSMPrintJobsColUserName = User
ErrForbiddenCmdLet = Banned CmdLet
ErrNoO365Connection = Not connected to the O365 services
ErrToolGuiNotPage = Gui is not defined with a Page object. The tool will therefore not be loaded
HDescCheckComputerOnline = Checks if the computer is online and reachable via scripts/tools
HDescClearPrintQueueJobs = Clear the printer queue
HDescGetSharedAccount = Fetching shared account connected to the computer
HDescMemberOf = Change the names to easy-to-read names
HDescOpenHomeDirectory = Open the folder in Windows Explorer
HDescOpenPrinterWebpage = Connect to the printer, via its IP, in Chrome
HTCheckComputerOnline = Check
HTClearPrintQueueJobs = Clear the printer queue
HTGetSharedAccount = Fetch shared account
HTMemberOf = Display easy to read
HTOpenHomeDirectory = Open in Explorer
HTOpenPrinterWebpage = Open the printer in Chrome
LogStrSearchItemTitle = AD-object
StrAccountNeverExpires = < No end date >
StrClearPrintJobs = Clears print queue
StrCompOperatingSystemVersion = version
StrCompUsesSharedAccount = The computer has a shared account linked to it. Investigating which account...
StrComputerOnline = Online:
StrConnectO365Title = Connect to the O365 services
StrCopyOutputEnteredInput = This was entered as input
StrCopyOutputForAdObject = for AD objects
StrCopyOutputMessageP1 = The following data has been retrieved
StrCopyOutputMessageP2 = from script/function
StrCopyOutputMessagePTime = The script was executed
StrCopyOutputSynopsis = Description of function
StrDefaultHandlerDescription = Run code for attributes
StrDefaultMainTitle = Fetchalon
StrDirFileCount = files
StrDirFolderCount = folder
StrDirItemsCount = object
StrErrorFetchingWarranty = Could not read warranty period. Try again.
StrGrpNameSharedCompName = SA_Client
StrIdPrefix = Prefix
StrIdPropName = IdName
StrLockoutComputer = Computer
StrLockoutDate = Date
StrLockoutDomain = Domain
StrNoLockoutsFound = No lockouts found in the last 7 days
StrNoLockoutsFoundTitle = No lockouts
StrNoOwner = < No owner listed >
StrNoPrintJobs = No print jobs queued
StrNoScriptOutput = < No output >
StrNotImplemented = Not implemented
StrNoValueSet = No value specified
StrOpensSeparateWindow = Opens in separate window
StrOrgDnPropName = OrgDn
StrOutputDataCopied = Data copied to clipboard
StrOutputDataObjectCopied = Item copied to clipboard
StrPropertyCopied = Data copied to clipboard
StrPropList = List of values
StrPsGetCmdlet = PowerShell Get CmdLet
StrRunHandler = Run attribute script
StrScriptRunningWithoutRunspace = Will run without a separate thread, the window can be locked
StrSearchedItemRequired = AD objects from search are required for this feature
StrSelectPropsDesc = Select by ticking the value to be displayed in the default view
StrSplash2 = Rearranging the furniture
StrSplash3 = Hacking CIA
StrSplashAddControlHandlers = Creating controls
StrSplashCreatingHandlers = Loading functions
StrSplashCreatingWindow = Creates main window
StrSplashFinished = Finished, good bye!
StrSplashReadingSettings = Loading settings
StrStartingTool = Launches tool
StrStringNotSpecified = < Not specified >
StrSysManApi = http://sysman.domain.com/SysMan/api/
StrVerbVirusScan = Search for threats
'@

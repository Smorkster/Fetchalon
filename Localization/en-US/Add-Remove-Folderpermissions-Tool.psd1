﻿ConvertFrom-StringData @'
CodeGetGGroupRead1 = "$( $Customer )_$( $entry )_file_UserR"
CodeGetGGroupRead2 = "$( $FolderName )$( $Customer )_$( $entry )_file_01_UserR"
CodeGetGGroupWrite1 = "$( $Customer )_$( $entry )_file_UserC"
CodeGetGGroupWrite2 = "$( $FolderName )$( $Customer )_$( $entry )_file_01_UserR"
CodeGetRGroupRead1 = "$( $Customer )_$( $entry )_file_UserR"
CodeGetRGroupRead2 = "$( $FolderName )$( $Customer )_$( $entry )_file_01_UserR"
CodeGetRGroupRead3 = "$( $FolderName )$( $Customer )_$( $entry )_file_02_UserR"
CodeGetRGroupRead4 = "$( $FolderName )$( $Customer )_$( $entry )_file_03_UserR"
CodeGetRGroupWrite1 = "$( $Customer )_$( $entry )_file_UserC"
CodeGetRGroupWrite2 = "$( $FolderName )$( $Customer )_$( $entry )_file_01_UserC"
CodeGetRGroupWrite3 = "$( $FolderName )$( $Customer )_$( $entry )_file_02_UserC"
CodeGetRGroupWrite4 = "$( $Customer )_$( $entry )_file_03_UserC"
CodeGetSGroupRead1 = "$( $Customer )_$( $entry )_file_UserR"
CodeGetSGroupRead2 = "$( $FolderName )$( $Customer )_$( $entry )_file_01_UserR"
CodeGetSGroupWrite1 = "$( $Customer )_$( $entry )_file_UserC"
CodeGetSGroupWrite2 = "$( $FolderName )$( $Customer )_$( $entry )_file_01_UserC"
ContentBtnPerform = Make changes
ContentBtnUndo = Abort
ContentChbUseSignature = Use signature in solution message
ContentTblDisk = Select disk
ContentTblFolderList = Select folder by double clicking
ContentTblFoldersChosen = Selected folders
ContentTblFolderSearch = Search (all or part of the name)
ContentTblLog = Work performed
ContentTblUsersForReadPermission = Read permission
ContentTblUsersForRemovePermission = Remove permission
ContentTblUsersForWritePermission = Write / read permission
ErrNotFoundGrpForGRead = Could not find AD group for Read on G for folder
ErrNotFoundGrpForGWrite = Could not find AD group for Write on G for folder
ErrNotFoundGrpForRRead = Could not find AD group for Read on R for folder
ErrNotFoundGrpForRWrite = Could not find AD group for Write on R for folder
ErrNotFoundGrpForSRead = Could not find AD group for Read on S for folder
ErrNotFoundGrpForSWrite = Could not find AD group for Write on S for folder
ErrNotFoundUser = No user found with id
LogInputGroups = Groups
LogInputRead = For read permission
LogInputRemove = For removal
LogInputWrite = For write permission
LogMessageGroups = Groups
LogMessageGroupsNotFound = These groups were not found
LogMessageRead = Read permission
LogMessageRemove = Permission removed
LogMessageUsersNotFound = These users were not found
LogMessageWrite = Write permission
StrConfirm1 = Do you for
StrConfirm2 = folders perform
StrConfirm3 = changes
StrConfirmDups = There are values listed for more than one permission group. Correct and run again.
StrConfirmDupsTitle = Duplicates
StrConfirmErr = Some values are not appointed to AD objects.
StrConfirmTitle = Continue?
StrDomain = Domain
StrEGroupDn = OrgDN
StrEGroupIdName = IdPropPrefix
StrEGroupOrg = IdPrefix
StrFinIntro = The following folders have received permission changes as shown below
StrFinished1 = changes made
StrFinished2 = A solution message has been copied to the clipboard
StrFinNoAccounts = No account found for the following
StrFinNoAdGroups = No permission groups found for the following folders
StrFinPermRead = Created read permission for
StrFinPermRem = Removed permission for
StrFinPermWrite = Created read/write permission for
StrGetFolders = Retrieving folders...
StrNoPerm = You lack the necessary permissions to run this script.
StrNoPermTitle = Permission issues
StrOpErrLogFile = \\Errorlogs\\
StrOpGroup = Rol_Drift
StrOpLogPath = \\\\domain.test.com\\FolderTool
StrOrgExcludeLDAP = Org7
StrPermRead = Read permission
StrPermReadWrite = Read/write permission
StrPermRemove = Remove permission
StrPreping = Preparing...
StrSDGroup = Rol_Servicedesk
StrSearchOtherPermRoutes = Checks other permissions for
StrSign = Sincerely
StrSignOp = Drift
StrSignSD = Servicedesk
StrStart = Applies group permissions
StrStartPrep = Fetching users for
StrTitle = Remove/Add folder permissions
StrTitleProgressGroups = Fetching AD groups
'@

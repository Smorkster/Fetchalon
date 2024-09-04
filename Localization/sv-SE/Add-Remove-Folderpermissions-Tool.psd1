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
ContentBtnPerform = Utför ändringar
ContentBtnUndo = Avbryt
ContentChbUseSignature = Använd signatur i lösningsmeddelande
ContentTblDisk = Välj disk
ContentTblFolderList = Välj mapp genom dubbeklick
ContentTblFoldersChosen = Valda mappar
ContentTblFolderSearch = Sök (hela eller del av namnet)
ContentTblLog = Utfört arbete
ContentTblUsersForReadPermission = Läs behörighet
ContentTblUsersForRemovePermission = Ta bort behörighet
ContentTblUsersForWritePermission = Skriv / läs behörighet
ErrNotFoundGrpForGRead = Hittade ingen AD-grupp för Read på G för mapp
ErrNotFoundGrpForGWrite = Hittade ingen AD-grupp för Write på G för mapp
ErrNotFoundGrpForRRead = Hittade ingen AD-grupp för Read på R för mapp
ErrNotFoundGrpForRWrite = Hittade ingen AD-grupp för Write på R för mapp
ErrNotFoundGrpForSRead = Hittade ingen AD-grupp för Read på S för mapp
ErrNotFoundGrpForSWrite = Hittade ingen AD-grupp för Write på S för mapp
ErrNotFoundUser = Hittade ingen användare med id
LogInputGroups = Grupper
LogInputRead = För läsbehörighet
LogInputRemove = För borttag
LogInputWrite = För skrivbehörighet
LogMessageGroups = Grupper
LogMessageGroupsNotFound = Dessa grupper hittades inte
LogMessageRead = Läsbehörighet
LogMessageRemove = Tagit bort behörighet
LogMessageUsersNotFound = Dessa användare hittades inte
LogMessageWrite = Skrivbehörighet
StrConfirm1 = Vill du för
StrConfirm2 = mappar utföra
StrConfirm3 = ändringar
StrConfirmDups = Det finns värden listat för fler än en behörighetsgrupp. Rätta till och kör igen.
StrConfirmDupsTitle = Dubbletter
StrConfirmErr = Vissa värden har inga AD-objekt.
StrConfirmTitle = Fortsätta?
StrDomain = Domain
StrEGroupDn = OrgDN
StrEGroupIdName = IdPropPrefix
StrEGroupOrg = IdPrefix
StrFinIntro = Följande mappar har fått behörighetsförändringar enligt nedan
StrFinished1 = ändringar utförda
StrFinished2 = Ett lösningsmeddelande har kopierats till clipboard
StrFinNoAccounts = Hittade inget konto för följande
StrFinNoAdGroups = Hittade inga behörighetsgrupper för följande mappar
StrFinPermRead = Skapat läsbehörighet för
StrFinPermRem = Tagit bort behörighet för
StrFinPermWrite = Skapat skriv-/läsbehörighet för
StrGetFolders = Hämtar mappar...
StrNoPerm = Du saknar nödvändiga rättigheter för att köra detta skript.
StrNoPermTitle = Behörighetsproblem
StrOpErrLogFile = \\Errorlogs\\
StrOpGroup = Rol_Drift
StrOpLogPath = \\\\domain.test.com\\FolderTool
StrOrgExcludeLDAP = Org7
StrPermRead = Läsbehörighet
StrPermReadWrite = Skriv-/läsbehörighet
StrPermRemove = Ta bort behörighet
StrPreping = Förbereder...
StrSDGroup = Rol_Servicedesk
StrSearchOtherPermRoutes = Kontrollerar andra behörigheter för
StrSign = Med vänliga hälsningar
StrSignOp = Drift
StrSignSD = Servicedesk
StrStart = Tillämpar gruppbehörigheter
StrStartPrep = Hämtar användare för
StrTitle = Ta bort/lägg till mappbehörigheter
StrTitleProgressGroups = Hämtar AD-grupper
'@

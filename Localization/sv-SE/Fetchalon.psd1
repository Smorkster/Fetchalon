﻿ConvertFrom-StringData @'
CodeLockoutAddress = \\\\test.domain.com\\LockedoutLogs\$
CodeMsExchIgnoreOrg = OU=Org1
CodeOrgGrpCaptureRegex = CN=Org1_Wrk_(?<org>.{3})_PR_(?<role>.*_PC).*
CodeOrgGrpNamePrefix = CN=Org1_Wrk
CodeRegExAclIdentity = ^Domain.*_(C|R)$
ContentBtnCopyOutputData = Data
ContentBtnCopyOutputObject = Dataobjekt
ContentBtnCopyValue = Kopiera
ContentBtnDirView = Visa
ContentBtnEnterFunctionInput = Kör skript
ContentBtnFetch = Hämta
ContentBtnFileView = Visa
ContentBtnGetExtraInfo = Hämta extra info
ContentBtnRunVirusScan = Kör virus kontroll
ContentBtnSearch = Sök
ContentChBGetComputerWarranty = Garantitid
ContentChBGetFromComputerProcesses = Processer
ContentChBGetFromPrintQueuePrintJobs = Kölista utskrifter
ContentChBGetFromSysMan = SysMan
ContentChBGetFromUserLockOut = Låsningslista
ContentDgSearchResultsColNameTitle = Namn (
ContentDgSearchResultsColObjClass = Objekttyp
ContentLblUserADActiveCheck = AD Aktiv
ContentLblUserADCheck = Finns i AD
ContentLblUserADLockCheck = AD Olåst
ContentLblUserADMailCheck = Mailattribut angivet
ContentLblUserADmsECheck = msExchMailboxGuid
ContentLblUserOAccountCheck = O365-konto skapat
ContentLblUserOExchCheck = Synkat till Exchange
ContentLblUserOLicCheck = Har E3-licens
ContentLblUserOLoginCheck = O365 inloggning aktiv
ContentMiObjDetailedHide = Förenklad vy
ContentNoMembersOfList = < Inga värden >
ContentSavePropValueButton = Spara
ContentTblAsterixWarning = När sökningstermen har en stjärna i början, tar sökningen längre tid. Försök vara så specifik som möjligt.
ContentTblCopyOutput = Kopiera:
ContentTblFailedSearchText = Inga objekt matchade sökningen
ContentTblGetFromTitle = Hämta information från:
ContentTblMiAboutText = Om och utifall att
ContentTblMiCloseObj = Stäng objektvy
ContentTblMiComputerFunctionsText = Dator
ContentTblMiConnectO365ServicesText = Anslut O365 Services
ContentTblMiCopyObj = Kopiera allt
ContentTblMiCopyObjSelected = Kopiera valda
ContentTblMiGroupFunctionsText = Grupp
ContentTblMiHideObj = Dölj AD-objekt
ContentTblMiHideOutputView = Dölj utdatavyn
ContentTblMiO365Text = Office 365
ContentTblMiObjDetailed = Detaljerad vy
ContentTblMiOtherFunctions = Andra funktioner
ContentTblMiOutputHistoryText = Historik output
ContentTblMiPrintQueueFunctionsText = Skrivare
ContentTblMiSeparateToolsText = Separata verktyg/applikationer
ContentTblMiShowObj = Visa AD-objekt
ContentTblMiShowOutputView = Visa utdatavyn
ContentTblMiToolsText = Verktyg
ContentTblMiUserFunctionsText = Användare
ContentTblObjMenuTitle = Objektaktiviteter
ContentTblOutputErrorsTitle = Fel vid körning
ContentTblOutputMenuTitle = Utdatavyn
ContentTblOutputTitle = Data från
ContentTblPropHandlerTitle = Handler finns för attributet
ContentTblPropHandlerTitleEmpty = Ingen handler finns, knapp kommer inte visas
ContentTblPropNameTT = Datakälla
ContentTblSearchHint = Du kan söka på id, gruppnamn, skrivarkö, IP-adress, eller ange sökväg till mapp eller fil. Stjärna kan användas som 'wildcard'.
ContentTblVisiblePropsTitle = Bocka för de värden som ska visas i allmän vy
ContentTBtnObjectDetailed = Välj attribut som ska visas i standardvyn
ContentTTMiCloseObj = Stäng vyn och glöm objektet
ContentTTMiCopyObj = Kopiera all data från objektet
ContentTTMiCopyObjSelected = Kopiera valda data från objektet
ContentTTMiObjDetailedHide = Visa förenklad lista
ContentTTMiObjDetailedShow = Visa detaljerad lista
ContentTTTblContentTblMiShowHideObj = Visa/dölj vyn för AD-objekt
ContentTTTblContentTblMiShowHideOutputView = Visa/dölj utdatavyn
ErrForbiddenCmdLet = Förbjuden CmdLet
ErrToolGuiNotPage = Gui är inte definierad med ett Page-objekt. Verktyg kommer därför inte laddas
LogStrPropHandlerRun = Kört handler för
LogStrSearchItemTitle = AD-objekt
StrAccountNeverExpires = < Inget slutdatum >
StrClearPrintJobs = Rensa skrivarkö
StrCompOperatingSystemVersion = version
StrComputerOnline = Online:
StrConnectO365Title = Anslut till O365-tjänsterna
StrCopyOutputEnteredInput = Detta angavs som indata
StrCopyOutputForAdObject = för AD-objekt
StrCopyOutputMessageP1 = Följande data har hämtats
StrCopyOutputMessageP2 = från skript/function
StrCopyOutputMessagePTime = Skriptet kördes
StrCopyOutputSynopsis = Funktionsbeskrivning
StrDefaultHandlerDescription = Kör kod för attribut
StrDefaultMainTitle = Fetchalon
StrDirFileCount = filer
StrDirFolderCount = mappar
StrDirItemsCount = objekt
StrGrpNameSharedCompName = Wrk_F_Klient
StrIdPrefix = Prefix
StrIdPropName = IdName
StrLockoutComputer = Dator
StrLockoutDate = Datum
StrLockoutDomain = Domän
StrManyConvertions = En parameter innehåller många värden, visning kan ev ta lite tid
StrNoLockoutsFound = Inga låsningar hittades under senaste 7 dagarna
StrNoLockoutsFoundTitle = Inga låsningar
StrNoOwner = < Ingen ägare angiven >
StrNoPrintJobs = Inga utskriftsjobb på kö
StrNoScriptOutput = < Ingen utdata >
StrOpensSeparateWindow = Öppnas i separat fönster
StrOrgDnPropName = OrgDn
StrOutputPropName = Attribut
StrOutputPropValue = Värde
StrPropertyCopied = Data kopierad till clipboard
StrPropListTitle1 = Lista med
StrPropListTitle2 = värden
StrPsGetCmdlet = PowerShell Get CmdLet
StrRunHandler = Kör attributskript
StrScriptRunningWithoutRunspace = Kommer köras utan separat tråd, fönstret kan låsas
StrSelectPropsDesc = Välj genom att bocka för det värde som ska visas i standardvyn
StrSplash2 = Möblerar om
StrSplashAddControlHandlers = Skapar kontroller
StrSplashCreatingHandlers = Läser in funktioner
StrSplashCreatingWindow = Skapar huvudfönster
StrSplashFinished = Klar, hej då!
StrSplashJoke1 = Hackar CIA
StrSplashJoke10 = Vinka till tittarna
StrSplashJoke11 = VEM VAR DET SOM KASTA?
StrSplashJoke2 = Hackar lök
StrSplashJoke3 = Vatten är nyttigt
StrSplashJoke4 = Ät en frukt
StrSplashJoke5 = Glöm inte handduken
StrSplashJoke6 = En herre utan mustasch kan aldrig...
StrSplashJoke7 = Kurre Träbock
StrSplashJoke8 = Go och glad, kexchoklad
StrSplashJoke9 = Ta alltid telefonnummer
StrSplashReadingSettings = Läser in inställningar
StrSysManApi = http://sysman.domain.com/SysMan/api/
StrVerbVirusScan = Sök efter hot
'@

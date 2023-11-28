﻿ConvertFrom-StringData @'
CodeAzureGrpName = ^(MB-)|(DL-)|(RES-)*\\w* (Funk)|(Dist)|(Resurs)|(Rum)
CodeMsExchIgnoreOrg = OU=Org1
CodeOrgGrpCaptureRegex = CN=Org1_Wrk_(?<org>.{3})_PR_(?<role>.*_PC).*
CodeOrgGrpNamePrefix = CN=Org1_Wrk
CodeRegExAclIdentity = ^Domain.*_(C|R)$
ContentBtnCopyOutputData = Data
ContentBtnCopyOutputObject = Dataobjekt
ContentBtnCopyValue = Kopiera
ContentBtnEnterFunctionInput = Kör skript
ContentBtnSearch = Sök
ContentDgSearchResultsColNameTitle = Namn (
ContentDgSearchResultsColObjClass = Objekttyp
ContentMiObjDetailedHide = Förenklad vy
ContentMiShowHideOutputViewHide = Dölj utdatavyn
ContentMiShowHideOutputViewNoOutput = Ingen utdata
ContentMiShowHideOutputViewShow = Visa utdatavyn
ContentNoMembersOfList = < Inga värden >
ContentSavePropValueButton = Spara
ContentTblAsterixWarning = När sökningstermen har en stjärna i början, tar sökningen längre tid. Försök vara så specifik som möjligt.
ContentTblCopyOutput = Kopiera:
ContentTblFailedSearchText = Inga objekt matchade sökningen
ContentTblFileInfoText = Fil
ContentTblMiAboutText = Om och utifall att
ContentTblMiCloseObj = Stäng objektvy
ContentTblMiComputerFunctionsText = Dator
ContentTblMiConnectO365ServicesText = Anslut O365 Services
ContentTblMiCopyObj = Kopiera allt
ContentTblMiCopyObjSelected = Kopiera valda
ContentTblMiDirectoryInfoFunctionsText = Mapp
ContentTblMiGetSysManInfo = Hämta extra info
ContentTblMiGetSysManInfoTt = Hämta information från SysMan
ContentTblMiGroupFunctionsText = Grupp
ContentTblMiHideObj = Dölj AD-objekt
ContentTblMiO365Distributionlist = Distributionslista (O365)
ContentTblMiO365Resource = Resurs (O365)
ContentTblMiO365Room = Rum (O365)
ContentTblMiO365SharedMailbox = Funktionsbrevlåda (O365)
ContentTblMiO365User = Användare (O365)
ContentTblMiObjDetailed = Detaljerad vy
ContentTblMiOtherFunctions = Andra funktioner
ContentTblMiOutputHistoryText = Historik output
ContentTblMiPrintQueueFunctionsText = Skrivare
ContentTblMiSeparateToolsText = Separata verktyg/applikationer
ContentTblMiShowObj = Visa AD-objekt
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
ContentTblSourceFilterTitle = Filtrera på datakälla
ContentTblVisiblePropsTitle = Bocka för de värden som ska visas i allmän vy
ContentTBtnObjectDetailed = Klicka här för att välja attribut som ska visas i standardvyn
ContentTTMiCloseObj = Stäng vyn och glöm objektet
ContentTTMiCopyObj = Kopiera all data från objektet
ContentTTMiCopyObjSelected = Kopiera valda data från objektet
ContentTTMiObjDetailedHide = Visa förenklad lista
ContentTTMiObjDetailedShow = Visa detaljerad lista
ContentTTTblContentTblMiShowHideObj = Visa/dölj vyn för AD-objekt
ContentTTTblContentTblMiShowHideOutputView = Visa/dölj utdatavyn
ErrForbiddenCmdLet = Förbjuden CmdLet
ErrSearchO365NotConnected = Ingen anslutning till Office 365 services, kan inte söka på Azure-grupper.
ErrToolGuiNotPage = Gui är inte definierad med ett Page-objekt. Verktyg kommer därför inte laddas
LogStrPropHandlerRun = Kört handler för
LogToolStarted = Startade
LogToolStartedError = Fel vid start av
LogStrSearchItemTitle = AD-objekt
StrAccountNeverExpires = < Inget slutdatum >
StrCompOperatingSystemVersion = version
StrComputerOnline = Online:
StrCopyOutputEnteredInput = Detta angavs som indata
StrCopyOutputForAdObject = för AD-objekt
StrCopyOutputMessageDataTitle = Utdata
StrCopyOutputMessageP1 = Följande data har hämtats
StrCopyOutputMessageP2 = från skript/function
StrCopyOutputMessagePFinish = Skriptet avslutades
StrCopyOutputMessagePStart = Skriptet startades
StrCopyOutputSynopsis = Funktionsbeskrivning
StrDefaultHandlerDescription = Kör kod för attribut
StrDefaultMainTitle = Fetchalon
StrGrpNameSharedCompName = Wrk_F_Klient
StrIdPrefix = Prefix
StrIdPropName = IdName
StrNoOwner = < Ingen ägare angiven >
StrNoScriptOutput = < Ingen utdata >
StrOpensSeparateWindow = Öppnas i separat fönster
StrOrgDnPropName = OrgDn
StrOutputPropName = Attribut
StrOutputPropValue = Värde
StrPHComputerOtherProcessListColId = ProcessID
StrPHComputerOtherProcessListColName = Namn
StrPHComputerOtherProcessListError = Fel uppstod vid anslutning till datorn
StrPropDataNotFetched = < Data ej hämtad >
StrPropertyCopied = kopierad till clipboard
StrPropListTitle1 = Lista med
StrPropListTitle2 = värden
StrPsGetCmdlet = PowerShell Get CmdLet
StrRunHandler = Kör attributskript
StrScriptRunningWithoutRunspace = Kommer köras utan separat tråd, fönstret kan låsas
StrSelectPropsDesc = Välj genom att bocka för det värde som ska visas i standardvyn
StrSplash2 = Möblerar om
StrSplashAddControlHandlers = Skapar kontroller
StrSplashCheckO365Roles = Kontrollerar Office365 roller
StrSplashConnectedO365 = Redan inloggad till Office365 online tjänster:
StrSplashConnectO365 = Logga in till Office365 online tjänster
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
StrSysAdmSANPrefix = sys
StrSysManApi = http://sysman.domain.com/SysMan/api/
'@

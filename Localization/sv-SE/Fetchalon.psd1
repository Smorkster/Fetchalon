﻿ConvertFrom-StringData @'
CodeAzureGrpName = ^(MB-)|(DL-)|(RES-)*\\w* (Funk)|(Dist)|(Resurs)|(Rum)
CodeMsExchIgnoreOrg = OU=Org1
CodeOrgGrpCaptureRegex = CN=Org1_Wrk_(?<org>.{3})_PR_(?<role>.*_PC).*
CodeOrgGrpNamePrefix = CN=Org1_Wrk
CodeRegExAclIdentity = ^Domain.*_(C|R)$
CodeRegExSharedAccName = ^Sa\w{2}\d{2}
ContentBtnCopyOutputData = Data
ContentBtnCopyOutputObject = Dataobjekt
ContentBtnCopyValue = Kopiera
ContentBtnEnterFunctionInput = Kör skript
ContentBtnNoteWarningUnderstood = Jag förstår
ContentBtnSearch = Sök
ContentDgSearchResultsColNameTitle = Namn (
ContentDgSearchResultsColObjClass = Objekttyp
ContentGbFunctionInputTitle = Input för funktionen
ContentMiObjDetailedHide = Förenklad vy
ContentMiShowHideOutputViewHide = Dölj utdatavyn
ContentMiShowHideOutputViewNoOutput = Ingen utdata
ContentMiShowHideOutputViewShow = Visa utdatavyn
ContentNoMembersOfList = < Inga värden >
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
ContentTblUnfinishedInputCountTitle = Nödvändiga värden kvar:
ContentTblVisiblePropsTitle = Bocka för de värden som ska visas i förenklad vy (standardvyn)
ContentTBtnObjectDetailed = Klicka här för att välja värden som ska visas i standardvyn
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
LogStrSearchItemTitle = AD-objekt
LogToolStarted = Startade
StrAccountNeverExpires = < Inget slutdatum >
StrAccountStatusOk = Aktiv
StrAdmPrefix = sys
StrCompOperatingSystemVersion = version
StrComputerOnline = Online-status:
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
StrNoRunspaceSplashInfo = Funktionen använder inte en individuell processtråd, och kan därför frysa hela fönstret tills den är klar
StrNoScriptOutput = < Ingen utdata >
StrNoteWarningInfo = Klicka på "Jag förstår" för att aktivera input och knapp för att starta
StrO365NotImplemented = Detta är inte implementerat
StrOpenMainWindowFound = Fetchalon är redan startat
StrOpensSeparateWindow = Öppnas i separat fönster
StrOrgDnPropName = OrgDn
StrOutputPropName = Attribut
StrOutputPropValue = Värde
StrPagedModuleUpdated = Verktyget har blivit uppdaterat sedan du senast läste in det.
StrPropDataNotFetched = < Data ej hämtad >
StrPropertyCopied = kopierad till clipboard
StrPropListTitle1 = Lista med
StrPropListTitle2 = värden
StrPsGetCmdlet = PowerShell Get CmdLet
StrRealPropName = Faktiskt attributnamn
StrRunHandler = Kör attributskript
StrScriptRunningWithoutRunspace = Använder inte separat processtråd, fönstret går inte att använda under tiden funktionen körs
StrSelectPropsDesc = Bocka för de värden som ska visas i standardvyn, klicka sedan här igen
StrSplash2 = Möblerar om
StrSplashAddControlHandlers = Skapar kontroller
StrSplashCheckO365Roles = Kontrollerar Office365 roller
StrSplashConnectedO365 = Redan inloggad till Office365 online tjänster:
StrSplashConnectO365 = Logga in till Office365 online tjänster
StrSplashCreatingHandlers = Läser in funktioner
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
StrSplashSkippingO365 = Skippar inloggningen till Office 365
StrSubMenuGroupTitleSuffix = -funktioner
StrSysManApi = http://sysman.domain.com/SysMan/api/
StrTextIdentifiedAs = Söktext identifierad som
StrTextIdentifiedAsAzureGroup = Azure-grupp
StrTextIdentifiedAsComputer = Datornamn
StrTextIdentifiedAsEmail = Mail-adress
StrTextIdentifiedAsFileDir = Fil eller mapp
StrTextIdentifiedAsGroupName = AD-grupp
StrTextIdentifiedAsID = Id
StrTextIdentifiedAsIpAddress = IP-adress
StrTextIdentifiedAsNoPatternAdSearch = inget fördefinierat mönster, gör allmän sökning i AD, tar lite längre tid
StrTextIdentifiedAsPsCmdlet = PowerShell-cmdlet
StrValidDateNotePrefixBetween = Giltig mellan
StrValidDateNotePrefixFrom = Giltig från
StrValidDateNotePrefixUntil = Giltig fram till
'@

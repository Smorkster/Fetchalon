ConvertFrom-StringData @'
CodeAllowedCompOrgs = Org1, Org2, Org3
CodeAllowedCompRoles = R1, R2, R3
CodeCompTypeRegEx = *_Wrk*_PC*
CodeSysManUrl = "http://sysman.test.com/SysMan/api/Log?name=&take=10000&skip=0&startDate=$processingStart&endDate=$processingEnd"
ContentBtnEndDate = End date
ContentBtnExport = Export to CSV
ContentBtnStart = Start
ContentBtnStartDate = Start date
ContentDescCompCol = Computer
ContentDescDateCol = Date
ContentDescDescriptionCol = Description
ContentDescRoleCol = PC-Role
ContentDescWTCol = WT
ContentInstCol = Installations
ContentUserCol = User
LogExport = Exported data
LogInstallations = Installations:
LogInstCount = installations
LogSearchEnd = end date:
LogSearchStart = Search period, start date:
LogUserCount = technicians, have made
StrAdmPrefix = sys
StrComputerNotFound = Computer not found in AD
StrErrorADLookup = AD check error
StrExportPathMessage = The list has been exported to
StrNoInstallations = No installation jobs found for specified days
StrOpCollect = Collects installation logs
StrOpRead = Reads SysMan log data
StrOpSetup = Configures for data collection from SysMan
StrOpUserImporting = Importing data
StrOpUserStart = Starting to send installation data for
StrOpWaitData = Waiting for data
StrOtherCompRole = Other computer type
StrWinTitle = SysMan - OS Installation Stats
'@

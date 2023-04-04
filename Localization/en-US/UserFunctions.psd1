ConvertFrom-StringData @'
SysManServerUrl = http://sysman.test.com/
StrGetFolderMembershipPropTitleGroup = AD-group
StrGetFolderMembershipPropTitleFolder = Folder
StrGetFolderMembershipPropTitlePermission = Permissiontype
StrGetFolderMembershipPropCodeNotMatch = .*_App_Office(key|_Templates).*
StrGetFolderMembershipPropCodeSplit1 = on
StrGetFolderMembershipPropCodeReplace1 = \\\\\\\\dfs\\\\gem\\$
StrGetFolderMembershipPropCodeReplace2 = \\\\\\\\dfs\\\\org2\\$
StrGetFolderMembershipPropValRead = Read
StrGetFolderMembershipPropValWrite = Write
StrCompareUserGroupsNoValidUsers = No active users found
'@

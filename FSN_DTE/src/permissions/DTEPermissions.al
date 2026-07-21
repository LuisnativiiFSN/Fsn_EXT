/// <summary>
/// Unknown DTE_Permissions (ID 50074).
/// </summary>
permissionset 50074 "DTE_Permissions"
{
    Assignable = true;
    IncludedPermissionSets = SUPER;
    Permissions =
        table "FSN DTE Transaction Header" = X,
        tabledata "FSN DTE Transaction Header" = RIMD;
    Access = Public;

}
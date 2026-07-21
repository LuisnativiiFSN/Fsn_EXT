page 50073 "FSN Rifas Excluded GroupsF"
{
    PageType = List;
    SourceTable = "FSN Rif. Excl. Cust Disc Group";
    ApplicationArea = all;
    UsageCategory = Administration;

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field(RifaNo; RifaNo)
                {
                }
                field(CustDiscGrp; CustDiscGrp)
                {
                }
            }
        }
    }

    actions
    {
    }
}


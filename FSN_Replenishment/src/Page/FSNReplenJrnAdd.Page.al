page 50103 "FSN Replen. Jrn. Add"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "FSN Replen. Jrnl. Add";
    Caption = 'FSN Replen. Jrn. Add';

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field("Item No."; "Item No.")
                {
                }
                field("Location Code"; "Location Code")
                {
                }
                field("Replen. Template Code"; "Replen. Template Code")
                {
                }
                field(Description; Description)
                {
                }
                field(Quantity; Quantity)
                {
                }
                field("Date Filter"; "Date Filter")
                {
                }
            }
        }
    }

    actions
    {
    }
}


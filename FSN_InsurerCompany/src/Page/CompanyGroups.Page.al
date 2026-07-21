page 50024 "FSN Company Groups"
{
    // WVILLALTA23SEPT19           - New page

    Caption = 'Company Groups';
    PageType = List;
    SourceTable = "FSN Company Group";
    ApplicationArea = all;
    UsageCategory = Lists;

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field("No."; "No.")
                {
                }
                field(Description; Description)
                {
                }
            }
        }
    }

    actions
    {
    }
}


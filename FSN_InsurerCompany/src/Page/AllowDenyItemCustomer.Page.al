page 50022 "FSN Allow/Deny Item Customer"
{
    PageType = List;
    SourceTable = "FSN Allow/Deny Item Customer";
    ApplicationArea = all;
    UsageCategory = Administration;
    Caption = 'Allow/Deny Item Customer';

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field("Line Type"; "Line Type")
                {
                }
                field("Entity No."; "Entity No.")
                {
                }
                field("Allow/Deny"; "Allow/Deny")
                {
                }
                field("Item Type"; "Item Type")
                {
                }
                field("No."; "No.")
                {
                }
                field(Description; Description)
                {
                    Editable = false;
                }
                field(Comment; Comment)
                {
                }
            }
        }
    }

    actions
    {
    }
}


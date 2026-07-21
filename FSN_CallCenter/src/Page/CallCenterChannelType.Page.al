page 50054 "FSN Call Center Channel Type"
{
    PageType = List;
    SourceTable = "FSN POS Setup Extend";

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field("Line No."; "Line No.")
                {
                }
                field("Data Extra 1"; "Data Extra 1")
                {
                    Caption = 'Description';
                }
                field("Data Extra 2"; "Data Extra 2")
                {
                    Caption = 'Prefix';
                }
                field("Action"; Active)
                {
                }
            }
        }
    }

    actions
    {
    }
}


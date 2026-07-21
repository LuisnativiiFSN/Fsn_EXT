page 50018 "FSN Item Information Type"
{
    Caption = 'Item Information Type';
    PageType = List;
    SourceTable = "FSN Item Info. Extend";

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field("Entry Type"; "Entry Type")
                {
                    Editable = false;
                }
                field("No."; "No.")
                {
                }
                field(Sort; Sort)
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

    trigger OnInsertRecord(BelowxRec: Boolean): Boolean
    begin
        TESTFIELD("Entry Type", "Entry Type"::TypeItemInformation);

    end;

    trigger OnOpenPage()
    begin
        FILTERGROUP(2);
        SETRANGE("Entry Type", "Entry Type"::TypeItemInformation);
        FILTERGROUP(0);
    end;
}


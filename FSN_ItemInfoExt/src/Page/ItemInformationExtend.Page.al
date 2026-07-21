page 50017 "FSN Item Information Extend"
{
    PageType = List;
    SourceTable = "FSN Item Info. Extend";
    ApplicationArea = ALL;
    UsageCategory = Administration;
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
                field(ID; ID)
                {
                }
                field("Free Text"; "Free Text")
                {
                    Caption = 'Free Text';
                }
                field(Description; Description)
                {
                    Caption = 'Item';
                    Editable = false;
                }
            }
        }
    }

    actions
    {
    }

    trigger OnInsertRecord(BelowxRec: Boolean): Boolean
    begin
        TESTFIELD("Entry Type", "Entry Type"::ItemInformation);
        TESTFIELD(ID);
    end;

    trigger OnOpenPage()
    begin
        FILTERGROUP(2);
        SETRANGE("Entry Type", "Entry Type"::ItemInformation);
        FILTERGROUP(0);
    end;
}


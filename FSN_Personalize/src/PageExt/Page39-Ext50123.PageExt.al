pageextension 50123 PageExtension50123 extends "General Journal"
{
    layout
    {
        addafter("Tax Group Code")
        {
            field("Debit Amount77396"; Rec."Debit Amount")
            {
                ApplicationArea = All;
            }
            field("Credit Amount09551"; Rec."Credit Amount")
            {
                ApplicationArea = All;
            }
        }
        modify(Amount)
        {
            Visible = false;
        }
        modify("Tax Area Code")
        {
            Visible = false;
        }
        modify("Tax Group Code")
        {
            Visible = false;
        }
        modify("Currency Code")
        {
            Visible = false;
        }
        modify("DIOT Type of Operation")
        {
            Visible = false;
        }
        modify("Deferral Code")
        {
            Visible = false;
        }
        modify("Shortcut Dimension 2 Code")
        {
            Visible = false;
        }
        moveafter("Bal. Account No."; "Shortcut Dimension 1 Code")
    }
}

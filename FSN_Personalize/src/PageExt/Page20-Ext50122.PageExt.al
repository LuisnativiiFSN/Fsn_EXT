pageextension 50122 "FSN Gen. Ledg. Entries" extends "General Ledger Entries"
{
    layout
    {
        modify("Global Dimension 2 Code")
        {
            Visible = false;
        }
        addafter("External Document No.")
        {
            field("User ID47453"; Rec."User ID")
            {
                ApplicationArea = All;
            }
        }
        modify("Gen. Prod. Posting Group")
        {
            Visible = false;
        }
        modify("Gen. Bus. Posting Group")
        {
            Visible = false;
        }
        modify("Gen. Posting Type")
        {
            Visible = false;
        }
        moveafter("External Document No."; "Global Dimension 1 Code")
        moveafter("Posting Date"; "Entry No.")
        addafter("G/L Account No.")
        {
            field("G/L Account Name73924"; Rec."G/L Account Name")
            {
                ApplicationArea = All;
            }
        }
        addafter(Description)
        {
            field("LSC Narration"; Rec."LSC Narration")
            {
                Caption = 'Comment';
                ApplicationArea = All;
            }
        }
    }
}

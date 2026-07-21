pageextension 50145 "FSN Post Purch Cr List Ext" extends "Posted Purchase Credit Memos"
{
    layout
    {
        addafter("Shortcut Dimension 2 Code")
        {
            field("Transaction Specification"; Rec."Transaction Specification")
            {
                ApplicationArea = All;
            }
        }
    }
}


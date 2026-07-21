pageextension 50150 "FSN Purch Cr Memo" extends "Posted Purchase Credit Memos"
{
    layout
    {
        addafter("Location Code")
        {
            field("DTE AuthNumber"; Rec."DTE AuthNumber")
            {
                ApplicationArea = All;
            }
            field("DTE Invoice"; Rec."DTE Invoice")
            {
                ApplicationArea = All;
            }
            field("Signature Validation"; Rec."Signature Validation")
            {
                ApplicationArea = All;
            }
            field("Vendor Order No."; Rec."Vendor Order No.")
            {
                ApplicationArea = All;
            }
            field("Order No."; "Order No.")
            {
                ApplicationArea = All;
            }
        }
    }
}
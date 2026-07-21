pageextension 50135 "FSN Posted Sales Invoices" extends "Posted Sales Invoices"
{
    layout
    {
        addafter("Shortcut Dimension 1 Code")
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
        }
    }
}
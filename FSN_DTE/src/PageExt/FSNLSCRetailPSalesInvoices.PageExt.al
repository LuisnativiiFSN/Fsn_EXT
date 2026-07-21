pageextension 50136 "FSN LSC Retail P. Sale Inv" extends "LSC Retail P. Sales Invoices"
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
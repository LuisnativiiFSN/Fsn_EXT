pageextension 50142 "FSN Legal Ledger Entry" extends "Legal Ledger Entry List"
{
    layout
    {

        addAfter(Number)
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
pageextension 50127 "FSN Posted Purchase Invoices" extends "Posted Purchase Invoices"
{
    layout
    {
        addafter(Corrective)
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
            field("FSN Withholding Tax Amount"; "FSN Withholding Tax Amount")
            {
                ApplicationArea = All;
            }
        }
    }
}

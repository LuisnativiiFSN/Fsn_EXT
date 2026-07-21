pageextension 50131 "FSN PostedPurchRcptListExt" extends "Posted Purchase Receipts"
{
    layout
    {
        addafter("Location Code")
        {

            field("DTE AuthNumber"; "DTE AuthNumber")
            {
                ApplicationArea = all;
            }
            field("DTE Invoice"; "DTE Invoice")
            {
                ApplicationArea = all;
            }
            field("Signature Validation"; "Signature Validation")
            {
                ApplicationArea = all;
            }
            field("FSN Withholding Tax Amount"; "FSN Withholding Tax Amount")
            {
                ApplicationArea = all;
            }
            field("No. Credit Memo Associated"; "No. Credit Memo Associated")
            {
                ApplicationArea = all;
            }
        }
    }
}
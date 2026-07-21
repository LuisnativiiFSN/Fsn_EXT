pageextension 50008 PageExtension50008 extends "Customer Ledger Entries"
{
    layout
    {
        addafter("Document No.")
        {
            field("External Document No.21020";Rec."External Document No.")
            {
                ApplicationArea = All;
            }
        }
    }
}

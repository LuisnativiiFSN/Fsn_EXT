pageextension 50025 PageExtension50025 extends "Posted Transfer Receipts"
{
    layout
    {
        addafter("Transfer-to Code")
        {
            field("Transfer Order No.07759"; Rec."Transfer Order No.")
            {
                ApplicationArea = All;
            }
            field("External Document No.98531";Rec."External Document No.")
            {
                ApplicationArea = All;
            }
        }
    }
}

pageextension 50060 "FSN Posted Transfer Receipts" extends "Posted Transfer Receipts"
{
    layout
    {
        addafter("Transfer-to Code")
        {
            field("Transfer Order No.67689"; Rec."Transfer Order No.")
            {
                ApplicationArea = All;
            }
            field("External Document No.98531"; Rec."External Document No.")
            {
                ApplicationArea = All;
            }
        }
    }
}

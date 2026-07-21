pageextension 50199 "RetailTransferOrderListExt" extends "LSC Retail Transfer Order List"
{
    layout
    {
        addafter("Store-to")
        {
            field("Posting Date"; Rec."Posting Date")
            {
                ApplicationArea = All;
            }
        }
    }
}
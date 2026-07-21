pageextension 50076 "FSN Discount Offer Lines" extends "LSC Discount Offer Lines"
{
    layout
    {
        addafter("Discount Amount Including VAT")
        {
            field("FSN Sell Out Type"; "FSN Sell Out Type")
            {
                ApplicationArea = all;
            }
            field("FSN Value Sell Out"; "FSN Value Sell Out")
            {
                ApplicationArea = all;
            }
        }
    }

    actions
    {
        // Add changes to page actions here
    }

    var
        myInt: Integer;
}
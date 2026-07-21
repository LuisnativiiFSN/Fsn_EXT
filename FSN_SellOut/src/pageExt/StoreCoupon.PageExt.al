pageextension 50078 "FSN Store Coupon" extends "LSC Store Coupon"
{
    layout
    {
        addafter("Buyer Group Code")
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
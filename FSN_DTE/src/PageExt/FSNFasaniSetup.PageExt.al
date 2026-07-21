pageextension 50167 "FSN Fasani Setup Ext" extends "FSN Fasani Setup"
{
    layout
    {
        addafter("Amt. Override Delivery")
        {

            field("DTE Store"; "DTE Store")
            {
                ApplicationArea = all;
            }
            field("DTE Terminal"; "DTE Terminal")
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
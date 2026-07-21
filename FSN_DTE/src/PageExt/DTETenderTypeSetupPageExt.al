pageextension 50161 "FSN DTE Tender Type Setup Ext" extends "LSC Tender Type Setup List"
{

    layout
    {
        addafter("Default Function")
        {

            field("DTE PaymentCode"; "DTE PaymentCode")
            {
                ApplicationArea = all;
            }

        }
    }
}

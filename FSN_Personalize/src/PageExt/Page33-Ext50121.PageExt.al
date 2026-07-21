pageextension 50121 "Customer Lookup_Ext" extends "Customer Lookup"
{
    Caption = 'Customer Lookup_Ext';
    layout
    {
        addafter("No.")
        {
            field("FSN DUI"; "FSN DUI")
            {
                ApplicationArea = All;
            }
        }

    }
}
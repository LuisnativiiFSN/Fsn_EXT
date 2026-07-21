pageextension 50005 "FSN barcode Ext" extends "LSC Item Barcodes"
{
    layout
    {
        addafter("Unit of Measure Code")
        {
            field("FSN Blocked"; Rec."FSN Blocked")
            {
                ApplicationArea = All;
                Caption = 'FSN Blocked';
            }
        }
    }
}
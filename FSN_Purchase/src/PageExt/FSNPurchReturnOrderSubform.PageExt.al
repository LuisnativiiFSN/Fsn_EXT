pageextension 50156 "FSN Purch Return Order Subform" extends "Purchase Return Order Subform"
{
    layout
    {
        addafter("No.")
        {
            field(Barcode; Rec."Barcode")
            {
                Caption = 'Barcode No.';
                ApplicationArea = All;
            }
        }
    }
}
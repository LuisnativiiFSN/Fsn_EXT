pageextension 50157 "FSN LSC Retail PRO Subform" extends "LSC Retail PRO Subform"
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
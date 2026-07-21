pageextension 50147 "FSN Post Sales Cr. Mem Subform" extends "Posted Sales Cr. Memo Subform"
{
    layout
    {
        addafter("Unit of Measure")
        {
            field("FSN Base Affect"; "FSN Base Affect")
            {
                Caption = 'FSN Bienes Afectos';

            }
        }
    }

    actions
    {
        // Add changes to page actions here
    }

    var
        myInt: Integer;
        P: Page "Sales Credit Memo";


}
pageextension 50146 "FSN Sales Cr. Memo Subform" extends "Sales Cr. Memo Subform"
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

}
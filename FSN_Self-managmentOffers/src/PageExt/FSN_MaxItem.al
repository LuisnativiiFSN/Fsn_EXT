pageextension 50038 "FSN Maximum billing Item" extends "LSC Item Status/Item Links"
{
    layout
    {
        addafter(Comment)
        {
            field(MaxVent; Rec."FSN Maximum billing")
            {
                Caption = 'Maximo de facturar';
                ApplicationArea = All;
            }
        }

        // Add changes to page layout here
    }

    actions
    {
        // Add changes to page actions here
    }

    var
        myInt: Integer;
        MaxVent: Integer;
}
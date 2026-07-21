pageextension 50037 "FSN Self MaxProduct" extends "LSC Item Status"
{
    layout
    {

        addafter("Sequence of Record")
        {

            field(MaxVent; Rec."FSN Maximum billing")
            {
                Caption = 'Maximo de facturar';
                ApplicationArea = All;
                Style = Favorable;
                // StyleExpr = "Default for new Items";
            }
        }
    }

    actions
    {
        // Add changes to page actions here
    }

    var
        myInt: Integer;
        MaxVent: Integer;
}
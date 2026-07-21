pageextension 50160 "FSN Applied Vendor Entries" extends "Applied Vendor Entries"
{
    layout
    {
        addafter(Description)
        {
            field("FSN Comment"; Rec."FSN Comment")
            {
                ApplicationArea = All;
                Caption = 'Código Autorizacion';
            }
            field("LSC Narration"; Rec."LSC Narration")
            {
                ApplicationArea = All;
                Caption = 'DTE';
            }

        }
    }
}

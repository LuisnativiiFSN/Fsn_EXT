pageextension 50159 "FSN Applied Customer Entries" extends "Applied Customer Entries"
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
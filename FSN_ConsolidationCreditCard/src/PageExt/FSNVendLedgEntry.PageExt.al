pageextension 50154 "FSN Vend Ledger Entries" extends "Vendor Ledger Entries"
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

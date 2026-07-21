pageextension 50153 "FSN Cust Ledger Entries" extends "Customer Ledger Entries"
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

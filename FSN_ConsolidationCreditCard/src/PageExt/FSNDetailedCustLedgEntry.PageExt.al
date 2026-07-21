pageextension 50158 "FSN Det. ust. Ledg. Entries" extends "Detailed Cust. Ledg. Entries"
{
    layout
    {
        addafter("Customer No.")
        {
            field("FSN Comment"; FSNComment)
            {
                ApplicationArea = All;
                Caption = 'Código Autorizacion';
            }
            field("LSC Narration"; LSCNarration)
            {
                ApplicationArea = All;
                Caption = 'DTE';
            }
        }
    }

    var
        CustLedgerEntry: Record "Cust. Ledger Entry";
        FSNComment, LSCNarration : Code[80];
    trigger OnAfterGetRecord()
    begin
        CustLedgerEntry.Reset();
        if Rec."Document Type" in [Rec."Document Type"::Invoice, Rec."Document Type"::"Credit Memo"] then
            if CustLedgerEntry.Get(Rec."Cust. Ledger Entry No.") then begin
                FSNComment := CustLedgerEntry."FSN Comment";
                LSCNarration := CustLedgerEntry."LSC Narration";
            end;
    end;


}

pageextension 50011 "FSN Retail Purch.Ret.Order" extends "LSC Retail Purch.Ret.Order Lst"
{
    layout
    {
        addafter("Assigned User ID")
        {
            field("Amount Including VAT95582"; Rec."Amount Including VAT")
            {
                ApplicationArea = All;
            }
            field(Amount61891; Rec.Amount)
            {
                ApplicationArea = All;
            }
            field("Status Record"; ValStatus(Rec))
            {
                Caption = 'Estado Registro';
                ApplicationArea = All;
                StyleExpr = StyleExprTxt;

            }

        }


    }
    trigger OnAfterGetRecord()
    var
        purchaseLine: Record "Purchase Line";
    begin
        purchaseLine.SetRange("Document No.", Rec."No.");
        purchaseLine.SetFilter("Return Qty. to Ship", '<>%1', 0);
        if purchaseLine.FindFirst() then begin
            if purchaseLine."Document Type" in [purchaseLine."Document Type"::"Credit Memo", purchaseLine."Document Type"::"Return Order"] then
                StyleExprTxt := 'Unfavorable'
            else
                StyleExprTxt := '';
        end else
            StyleExprTxt := '';

    end;

    var
        StyleExprTxt: Text;


    local procedure ValStatus(purchaseHeader: record "Purchase Header"): Text
    var
        purchaseLine: Record "Purchase Line";
        statusRecord: Text[20];
    begin
        purchaseLine.SetRange("Document No.", purchaseHeader."No.");
        purchaseLine.SetFilter("Return Qty. to Ship", '<>%1', 0);
        if purchaseLine.FindFirst() then
            statusRecord := 'Devolución Pendiente' else
            statusRecord := 'Devolución Completa';
        exit(statusRecord);
    end;
}

pageextension 50164 "Posted Sales Credit Memo" extends "Posted Sales Credit Memo"
{
    layout
    {
        // Add changes to page layout here
    }

    actions
    {
        // Add changes to page actions here
        addbefore("&Navigate")
        {
            action(DTE)
            {
                Caption = 'Ajustar DTE';
                ApplicationArea = All;
                Promoted = true;
                Image = ChangeBatch;
                PromotedCategory = Process;
                trigger OnAction()
                var
                    FSN_CorrectionDTE: Page "FSN Correction DTE";
                    PosMenuLine: Record "LSC POS Menu Line" temporary;
                begin
                    if (Rec."DTE AuthNumber" <> '') and (Rec."DTE Invoice" <> '') and (Rec."Signature Validation" <> '') then begin
                        PosMenuLine."Menu ID" := Rec."No.";
                        POSMenuLine."Set Current-Input" := Rec."DTE Invoice";
                        POSMenuLine."Current-Description" := Rec."DTE AuthNumber";
                        POSMenuLine."Current-Description2" := Rec."Signature Validation";
                        PosMenuLine."Post Parameter" := 'Nota de crédito venta regis.';
                        PosMenuLine.Insert();
                        FSN_CorrectionDTE.MenuLine(PosMenuLine);
                        if FSN_CorrectionDTE.RunModal() = ACTION::OK then begin
                            CurrPage.Update(false);
                        end;
                    end;
                end;
            }
        }
    }

    var
        myInt: Integer;
}
pageextension 50085 MyExtension extends "LSC Transaction Register"
{
    layout
    {
        // Add changes to page layout here
    }

    actions
    {
        // Add changes to page actions here
        addafter("F&unctions")
        {
            action(Borrado)
            {
                ApplicationArea = All;
                Image = ClearLog;

                trigger OnAction()
                begin
                    DeleteSoporte();
                end;
            }
        }
    }

    var
        myInt: Integer;

        Text001: Label 'El usuario %1 Desea eliminar los registros transaction header';
        Text002: Label 'Se eliminaron %1 registros por el usuario %2';
        TransHeader: Record "LSC Transaction Header";
        TransSalesE: Record "LSC Trans. Sales Entry";
        TransPayment: Record "LSC Trans. Payment Entry";
        TransInfocode: Record "LSC Trans. Infocode Entry";
        PosCardEntry: Record "LSC POS Card Entry";
        PosVoidesTLine: Record "LSC POS Voided Trans. Line";
        PosInvenEntry: Record "LSC Trans. Inventory Entry";
        TransINC: Record "LSC Trans. Inc./Exp. Entry";
        TransInv: Record "LSC Trans. Inv. Adjmt. Entry";
        TrnasHosp: Record "LSC Trans. Hospitality Entry";
        TransOrdH: Record "LSC Transaction Order Header";
        TransAdd: Record "LSC Trans. Add. Salesperson";
        TransDisc: Record "LSC Trans. Discount Entry";
        TrnasMixMath: Record "LSC Trans. Mix & Match Entry";
        TransDBene: Record "LSC Trans. Disc. Benefit Entry";
        TransCupon: Record "LSC Trans. Coupon Entry";
        TransPoint: Record "LSC Trans. Point Entry";
        TransHB: Record "LSC Transaction Header";


    procedure DeleteSoporte()
    var
        myInt: Integer;
        Cont: Integer;
        Windows: Dialog;
        TexB: label 'Transacciones eliminadas %1 de 2000';
    begin

        if not Confirm(StrSubstNo(Text001, UserId)) then
            exit;
        Cont := 0;
        TransHeader.Reset();
        TransHeader.SetFilter(Date, '<=%1', Today - 180);
        if TransHeader.Find('-') then begin
            repeat
                Cont := Cont + 1;
                Borrado(TransHeader);
                Windows.Open(StrSubstNo(TexB, Format(Cont)));
                Windows.Update();
                if cont = 2000 then begin
                    Message(StrSubstNo(Text002, Cont, UserId));
                    Windows.Close();
                    exit;
                end;
            until TransHeader.Next() = 0;
        end;
    end;

    Procedure Borrado(TransHeader: Record "LSC Transaction Header")
    var
        myInt: Integer;
    begin
        TransSalesE.Reset();
        TransSalesE.SetRange("Transaction No.", TransHeader."Transaction No.");
        TransSalesE.SetRange("Receipt No.", TransHeader."Receipt No.");
        if TransSalesE.Find('-') then
            repeat
                TransSalesE.Delete(false);
            until TransSalesE.Next() = 0;

        TransPayment.Reset();
        TransPayment.SetRange("Transaction No.", TransHeader."Transaction No.");
        TransPayment.SetRange("Receipt No.", TransHeader."Receipt No.");
        if TransPayment.Find('-') then
            repeat
                TransPayment.Delete(false);
            until TransPayment.Next() = 0;

        TransInfocode.Reset();
        TransInfocode.SetRange("Transaction No.", TransHeader."Transaction No.");
        TransInfocode.SetRange("Store No.", TransHeader."Store No.");
        if TransInfocode.Find('-') then
            repeat
                TransInfocode.Delete(false);
            until TransInfocode.Next() = 0;

        PosCardEntry.Reset();
        PosCardEntry.SetRange("Transaction No.", TransHeader."Transaction No.");
        PosCardEntry.SetRange("Receipt No.", TransHeader."Receipt No.");
        PosCardEntry.SetRange("Store No.", TransHeader."Store No.");
        if PosCardEntry.Find('-') then
            repeat
                PosCardEntry.Delete(false);
            until PosCardEntry.Next() = 0;

        PosVoidesTLine.Reset();
        PosVoidesTLine.SetRange("Receipt No.", TransHeader."Receipt No.");
        if PosVoidesTLine.Find('-') then
            repeat
                PosVoidesTLine.Delete(false);
            until PosVoidesTLine.Next() = 0;

        PosInvenEntry.Reset();
        PosInvenEntry.SetRange("Transaction No.", TransHeader."Transaction No.");
        PosInvenEntry.SetRange("Receipt No.", TransHeader."Receipt No.");
        PosInvenEntry.SetRange("Store No.", TransHeader."Store No.");
        if PosInvenEntry.Find('-') then
            repeat
                PosInvenEntry.Delete(false);
            until PosInvenEntry.Next() = 0;

        TransINC.Reset();
        TransINC.SetRange("Store No.", TransHeader."Store No.");
        TransINC.SetRange("POS Terminal No.", TransHeader."POS Terminal No.");
        TransINC.SetRange("Transaction No.", TransHeader."Transaction No.");
        if TransINC.Find('-') then
            repeat
                TransINC.Delete(false);
            until TransINC.Next() = 0;

        TransInv.Reset();
        TransInv.SetRange("Store No.", TransHeader."Store No.");
        TransInv.SetRange("POS Terminal No.", TransHeader."POS Terminal No.");
        TransInv.SetRange("Transaction No.", TransHeader."Transaction No.");
        if TransInv.Find('-') then
            repeat
                TransInv.Delete(false);
            until TransInv.Next() = 0;

        TrnasHosp.Reset();
        TrnasHosp.SetRange("Store No.", TransHeader."Store No.");
        TrnasHosp.SetRange("POS Terminal No.", TransHeader."POS Terminal No.");
        TrnasHosp.SetRange("Transaction No.", TransHeader."Transaction No.");
        if TrnasHosp.Find('-') then
            repeat
                TrnasHosp.Delete(false);
            until TrnasHosp.Next() = 0;

        TransOrdH.Reset();
        if TransOrdH.Get(TransHeader."Store No.", TransHeader."POS Terminal No.", TransHeader."Transaction No.") then
            TransOrdH.Delete(false);

        TransAdd.Reset();
        TransAdd.SetRange("Store No.", TransHeader."Store No.");
        TransAdd.SetRange("POS Terminal No.", TransHeader."POS Terminal No.");
        TransAdd.SetRange("Transaction No.", TransHeader."Transaction No.");
        if TransAdd.Find('-') then
            repeat
                TransAdd.Delete(false);
            until TransAdd.Next() = 0;

        TransDisc.Reset();
        TransDisc.SetRange("Store No.", TransHeader."Store No.");
        TransDisc.SetRange("POS Terminal No.", TransHeader."POS Terminal No.");
        TransDisc.SetRange("Transaction No.", TransHeader."Transaction No.");
        if TransDisc.Find('-') then
            repeat
                TransDisc.Delete(false);
            until TransDisc.Next() = 0;


        TrnasMixMath.Reset();
        TrnasMixMath.SetRange("Store No.", TransHeader."Store No.");
        TrnasMixMath.SetRange("POS Terminal No.", TransHeader."POS Terminal No.");
        TrnasMixMath.SetRange("Transaction No.", TransHeader."Transaction No.");
        if TrnasMixMath.Find('-') then
            repeat
                TrnasMixMath.Delete(false);
            until TrnasMixMath.Next() = 0;

        TransDBene.Reset();
        TransDBene.SetRange("Store No.", TransHeader."Store No.");
        TransDBene.SetRange("POS Terminal No.", TransHeader."POS Terminal No.");
        TransDBene.SetRange("Transaction No.", TransHeader."Transaction No.");
        if TransDBene.Find('-') then
            repeat
                TransDBene.Delete(false);
            until TransDBene.Next() = 0;

        TransCupon.Reset();
        TransCupon.SetRange("Store No.", TransHeader."Store No.");
        TransCupon.SetRange("POS Terminal No.", TransHeader."POS Terminal No.");
        TransCupon.SetRange("Transaction No.", TransHeader."Transaction No.");
        if TransCupon.Find('-') then
            repeat
                TransCupon.Delete(false);
            until TransCupon.Next() = 0;

        TransPoint.Reset();
        TransPoint.SetRange("Store No.", TransHeader."Store No.");
        TransPoint.SetRange("POS Terminal No.", TransHeader."POS Terminal No.");
        TransPoint.SetRange("Transaction No.", TransHeader."Transaction No.");
        if TransPoint.Find('-') then
            repeat
                TransPoint.Delete(false);
            until TransPoint.Next() = 0;

        TransHB.Reset();
        TransHB.SetRange("Store No.", TransHeader."Store No.");
        TransHB.SetRange("POS Terminal No.", TransHeader."POS Terminal No.");
        TransHB.SetRange("Transaction No.", TransHeader."Transaction No.");
        if TransHB.FindFirst() then
            TransHB.Delete(false);
    end;
}
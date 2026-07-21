codeunit 50082 "FSN AJUSTE LOTE"
{
    TableNo = "LSC Scheduler Job Header";
    trigger OnRun()
    begin
        case code of
            '':
                begin
                    GlobalRec := Rec;
                    AjusteCompleto();
                end;

        end;
    end;

    var
        GlobalRec: Record "LSC Scheduler Job Header";
        Lote: Record "FSN Lote Invalidate";
        TransSales: Record "LSC Trans. Sales Entry";
        TransSaleStatus: Record "LSC Trans. Sales Entry Status";

    local procedure AjusteCompleto()
    var
        TransSales: Record "LSC Trans. Sales Entry";
        Item: Record Item;
        Lote: Record "FSN Lote Invalidate";

    begin
        Lote.Reset();
        Lote.DeleteAll();

        TransSales.Reset();
        TransSales.SetFilter(Date, '>=%1', GlobalRec."Date");
        TransSales.SetFilter("Item No.", Item());
        if TransSales.Find('-') then begin
            repeat
                if ValidateRegistMov(TransSales) then begin
                    AjusteFecha(TransSales);
                    ValidateQuanity(TransSales);
                end;
            until TransSales.Next = 0;
        end;
    end;

    local procedure AjusteFecha(TransSales: Record "LSC Trans. Sales Entry")
    var
        myInt: Integer;
        ItemledgerEntry: Record "Item Ledger Entry";
        Parameter: Record "FSN Parameter";
    begin
        Parameter.Reset();
        if Parameter.Get('FSN', 'DEBUG') AND Parameter.Activo then begin
            if (TransSales."Lot No." = Parameter.Valor) and (TransSales."Store No." = Parameter.Descripcion) then
                myInt := 1;
        end;

        ItemledgerEntry.Reset();
        ItemledgerEntry.SetRange("Item No.", TransSales."Item No.");
        ItemledgerEntry.SetRange("Lot No.", TransSales."Lot No.");
        ItemledgerEntry.SetRange("Location Code", TransSales."Store No.");
        ItemledgerEntry.SetRange(Open, true);
        if ItemledgerEntry.FindFirst() then begin
            if TransSales."Expiration Date" <> ItemledgerEntry."Expiration Date" then begin
                TransSales."Expiration Date" := ItemledgerEntry."Expiration Date";
                TransSales.Modify();
            end;
        end;
    end;

    local procedure ValidateRegistMov(TransSales: Record "LSC Trans. Sales Entry"): Boolean
    var
        TransSalesStatus: Record "LSC Trans. Sales Entry Status";
    begin
        TransSalesStatus.Reset();
        TransSalesStatus.SetRange("Store No.", TransSales."Store No.");
        TransSalesStatus.SetRange("POS Terminal No.", TransSales."POS Terminal No.");
        TransSalesStatus.SetRange("Transaction No.", TransSales."Transaction No.");
        TransSalesStatus.SetRange("Line No.", TransSales."Line No.");
        TransSalesStatus.SetFilter(Status, '>%1', 0);
        if not TransSalesStatus.FindFirst() then
            exit(true);
    end;

    local procedure Item(): Text
    var
        Item: Record Item;
        Setfilter: Text;
    begin
        Item.Reset();
        Item.SetFilter("Item Tracking Code", '<>%1', '');
        if Item.Find('-') then begin
            repeat
                if Setfilter = '' then
                    Setfilter := Item."No."
                else
                    Setfilter := Setfilter + '|' + Item."No.";
            until Item.Next = 0;
        end;
        exit(Setfilter);
    end;

    local procedure ValidateQuanity(TransSales: Record "LSC Trans. Sales Entry")
    var
        TransSales2, TransSalesNew : Record "LSC Trans. Sales Entry";
        TransSalesTemp: Record "LSC Trans. Sales Entry" temporary;
        ItemLengerEntry, ItemLedgerEntry : Record "Item Ledger Entry";
        Remanente: Decimal;
        Vendidos: Decimal;
        Faltante: Decimal;
        Mensaje: Text[250];
        TransacHeader: Record "LSC Transaction Header";
        myInt: Integer;
        ExcludeFilter: Text;
    begin
        if (TransSales."Lot No." = 'SVF10750') then
            myInt := 1;

        TransSales2.Reset();
        TransSales2.SetRange("Store No.", TransSales."Store No.");
        TransSales2.SetRange("Item No.", TransSales."Item No.");
        TransSales2.SetFilter(Date, '>=%1', GlobalRec.Date);
        TransSales2.SetFilter("Lot No.", TransSales."Lot No.");
        if TransSales2.FindSet() then begin
            repeat
                if ValidateRegistMov(TransSales2) then
                    Vendidos += TransSales2.Quantity * -1;
            until TransSales2.Next() = 0;
        end;

        ItemLengerEntry.Reset();
        ItemLengerEntry.SetRange("Item No.", TransSales."Item No.");
        ItemLengerEntry.SetRange("Lot No.", TransSales."Lot No.");
        ItemLengerEntry.SetRange("Location Code", TransSales."Store No.");
        ItemLengerEntry.SetRange(Open, true);
        ItemLengerEntry.CalcSums("Remaining Quantity");
        ItemLengerEntry.CalcSums(Quantity);
        Remanente := ItemLengerEntry."Remaining Quantity";

        if Vendidos > Remanente then begin
            Faltante := Vendidos - Remanente;
            if (TransSales."Lot No." <> '') and (Remanente <> 0) then
                Mensaje := 'Cantidad de lote no es suficiente'
            else
                Mensaje := 'Lote no existe en el sistema o ya fue vendido';
            InsetLoteInvalido(TransSales, Mensaje, Faltante);
        end;

    end;

    local procedure InsetLoteInvalido(TransSales: Record "LSC Trans. Sales Entry"; var Mensaje: Text[250]; Faltante: Decimal)
    var
        LoteInvd: Record "FSN Lote Invalidate";
        me: Boolean;
    begin
        if TransSales."Lot No." = '#LOTCOMODIN' then
            me := true;


        if not LoteInvd.Get(TransSales."Store No.", TransSales."POS Terminal No.", TransSales."Transaction No.", TransSales."Line No.") then begin
            LoteInvd.Init();
            LoteInvd."Store No." := TransSales."Store No.";
            LoteInvd."POS Terminal No." := TransSales."POS Terminal No.";
            LoteInvd."Transaction No." := TransSales."Transaction No.";
            LoteInvd."Line No." := TransSales."Line No.";
            LoteInvd."Lot No." := TransSales."Lot No.";
            LoteInvd."Expiration Date" := TransSales."Expiration Date";
            LoteInvd."Item No." := TransSales."Item No.";
            LoteInvd.Quantity := TransSales.Quantity * -1;
            LoteInvd.Date := TransSales.Date;
            LoteInvd.Message := Mensaje;
            LoteInvd.Faltante := Faltante;
            LoteInvd.Insert();
        end;
    end;

}


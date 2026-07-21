page 50111 "FSN Lotes invalios"
{
    PageType = List;
    Caption = 'FSN Lotes invalidos';
    ApplicationArea = All;
    UsageCategory = Lists;
    SourceTable = "FSN Lote Invalidate";
    Editable = false;
    DeleteAllowed = false;
    InsertAllowed = false;
    layout
    {
        area(Content)
        {
            repeater(GroupName)
            {
                field("Lot No."; "Lot No.")
                {
                    ApplicationArea = All;
                }
                field("Expiration Date"; "Expiration Date")
                {
                    ApplicationArea = All;
                }
                field("Store No."; "Store No.")
                {
                    ApplicationArea = All;
                }

                field("Item No."; "Item No.")
                {
                    ApplicationArea = All;
                }
                field(Quantity; Quantity)
                {
                    ApplicationArea = All;
                    Caption = 'Cantidad venta';
                }
                field("Date"; "Date")
                {
                    ApplicationArea = All;
                    Caption = 'Fecha de Transaccion';
                }
                field(Faltante; Faltante)
                {
                    ApplicationArea = All;
                    Style = Attention;
                }
                field(Message; Message)
                {
                    ApplicationArea = All;
                    Caption = 'Mensaje';
                    Style = Attention;
                }


            }
        }
        area(Factboxes)
        {

        }
    }

    actions
    {
        area(processing)
        {
            group("&Functions")
            {
                Caption = '&Functions';
                action("&Correct Serial/Lot No.")
                {
                    ApplicationArea = All;
                    Caption = 'Corregir Lot No.';
                    Image = SerialNo;
                    Promoted = true;
                    PromotedCategory = Process;

                    trigger OnAction()
                    var
                        Response: Boolean;
                        Print: Text;
                        TransSalesE: Record "LSC Trans. Sales Entry";
                        LoteNuevoPage: Page "FSN Ajuste Trans. sales Lote";
                        ItemLedger, ItemLedgerFilter : record "Item Ledger Entry";
                    begin
                        Clear(SerialNoNotOnFileReport);

                        if TransactionStatus.Get("Store No.", "POS Terminal No.", "Transaction No.") then;
                        TransSalesE.Reset();
                        TransSalesE.SetRange("Store No.", Rec."Store No.");
                        TransSalesE.SetRange("POS Terminal No.", Rec."POS Terminal No.");
                        TransSalesE.SetRange("Transaction No.", Rec."Transaction No.");
                        TransSalesE.SetRange("Line No.", Rec."Line No.");
                        if TransSalesE.FindFirst() then;

                        ItemLedgerFilter(ItemLedgerFilter);
                        LoteNuevoPage.GlobalLote(Rec."Lot No.");
                        LoteNuevoPage.LookupMode(true);
                        LoteNuevoPage.SetTableView(ItemLedgerFilter);
                        if LoteNuevoPage.RunModal() = Action::LookupOK then begin
                            LoteNuevoPage.SetSelectionFilter(ItemLedgerFilter);
                            if ItemLedgerFilter.FindFirst() then;
                            if TransSalesE."Lot No." <> ItemLedgerFilter."Lot No." then begin
                                CambioLote(ItemLedgerFilter);
                                ValidacionLote(1);
                                CurrPage.Update(false);
                            end;
                        end;
                    end;
                }
                action("&Ajuste Lote")
                {
                    ApplicationArea = All;
                    Caption = 'Ajuste Lote';
                    Image = Lot;
                    Promoted = true;
                    PromotedCategory = Process;

                    trigger OnAction()
                    var
                        ItemJournalLine: Record "Item Journal Line";
                        LoteNuevoPage: Page "FSN Ajuste Trans. sales Lote";
                        ItemLedyey_, ItemLedgerFilter : Record "Item Ledger Entry";
                        Faltante: Decimal;
                        AjPos: Decimal;
                        ArrEntryNo: array[1000000] of Code[20];
                    begin
                        DeletJournal;
                        Faltante := Rec.Faltante;
                        ItemLedyey_.Reset();
                        ItemLedyey_.SetRange("Item No.", Rec."Item No.");
                        ItemLedyey_.SetFilter("Location Code", Rec."Store No.");
                        ItemLedyey_.SetRange("Lot No.", Rec."Lot No.");
                        ItemLedyey_.SetRange(Open, true);
                        if ItemLedyey_.FindFirst() then begin
                            TransSalesE.Reset();
                            TransSalesE.SetRange("Store No.", Rec."Store No.");
                            TransSalesE.SetRange("POS Terminal No.", Rec."POS Terminal No.");
                            TransSalesE.SetRange("Transaction No.", Rec."Transaction No.");
                            TransSalesE.SetRange("Line No.", Rec."Line No.");
                            if TransSalesE.FindFirst() then begin

                                Commit();
                                ItemLedgerFilter(ItemLedgerFilter);
                                LoteNuevoPage.GlobalLote(Rec."Lot No.");
                                LoteNuevoPage.LookupMode(true);
                                LoteNuevoPage.SetTableView(ItemLedgerFilter);
                                if LoteNuevoPage.RunModal() = Action::LookupOK then begin
                                    LoteNuevoPage.SetSelectionFilter(ItemLedgerFilter);
                                    if ItemLedgerFilter.Find('-') then begin
                                        repeat
                                            if (ItemLedgerFilter."Remaining Quantity" <= Faltante) then begin
                                                AjusteNegativo(ItemLedgerFilter, ItemLedgerFilter."Remaining Quantity");
                                                AjPos += ItemLedgerFilter."Remaining Quantity";
                                            end else begin
                                                AjusteNegativo(ItemLedgerFilter, Faltante);
                                                AjPos += Faltante;
                                            end;
                                            Faltante -= ItemLedgerFilter."Remaining Quantity";
                                        until (ItemLedgerFilter.Next() = 0) or (Faltante <= 0);
                                        AjusteLote(TransSalesE, ItemJournalLine, AjPos);
                                        CODEUNIT.Run(CODEUNIT::"Item Jnl.-Post", ItemJournalLine);
                                        ValidacionLote(2);
                                        CurrPage.Update(false);
                                    end;
                                end;
                            end;
                        end else
                            Message(Rec.Message);
                    end;

                }
            }
        }
    }


    var
        TransSalesE: Record "LSC Trans. Sales Entry";
        WarehouseEmployee: Record "Warehouse Employee";
        TransactionStatus: Record "LSC Transaction Status";
        SerialNoNotOnFileReport: Report "LSC Serial/Lot No not Valid";
        FaltanteNo: Decimal;
        LastEntryNo: Integer;

    trigger OnOpenPage()
    var
        Existent: Boolean;
        lOldFilterGroup: Integer;
    begin
        WarehouseEmployee.Reset();
        WarehouseEmployee.SetRange("User ID", USERID);
        if WarehouseEmployee.FindFirst() then
            IF WarehouseEmployee."Location Code" <> '' THEN begin
                lOldFilterGroup := FilterGroup;
                FilterGroup(10);
                SetRange("Store No.", WarehouseEmployee."Location Code");
                FilterGroup(lOldFilterGroup);
            end;
    end;

    procedure CallItemTracking(var ItemJnlLine: Record "Item Journal Line")
    var
        TrackingSpecification: Record "Tracking Specification" temporary;
        ReservEntry: Record "Reservation Entry";
        ItemTrackingLines: Page "Item Tracking Lines";
        IsHandled: Boolean;
    begin
        IsHandled := false;
        if IsHandled then
            exit;

        ItemJnlLine.TestField("Item No.");
        if not ItemJnlLine.ItemPosting then begin
            ReservEntry.InitSortingAndFilters(false);
            ItemJnlLine.SetReservationFilters(ReservEntry);
            ReservEntry.ClearTrackingFilter;
            if ReservEntry.IsEmpty() then
                exit;
        end;
        TrackingSpecification."Entry No." := NextEntryNo();
        TrackingSpecification.InitFromItemJnlLine(ItemJnlLine);
        TrackingSpecification.Validate("Quantity (Base)", ItemJnlLine.Quantity);
        TrackingSpecification.Validate("Location Code", ItemJnlLine."Location Code");
        TrackingSpecification.Validate("Lot No.", ItemJnlLine."Lot No.");
        TrackingSpecification.Insert(true);

        Reservation(ItemJnlLine);
    end;

    procedure NextEntryNo(): Integer
    begin
        LastEntryNo += 1;
        exit(LastEntryNo);
    end;

    procedure DeletJournal()
    var
        ItemJournalLine2: Record "Item Journal Line";
    begin
        ItemJournalLine2.Reset();
        ItemJournalLine2.SetRange("Journal Template Name", 'ITEM');
        ItemJournalLine2.SetRange("Journal Batch Name", 'LOTE');
        ItemJournalLine2.DeleteAll();

    end;

    local procedure AjusteLote(TransSalesEntry: Record "LSC Trans. Sales Entry"; var ItemJournalLine: Record "Item Journal Line"; Faltante: Decimal)
    var
    begin
        ItemJournalLine.Init();
        ItemJournalLine."Journal Template Name" := 'ITEM';
        ItemJournalLine."Journal Batch Name" := 'LOTE';
        ItemJournalLine."Line No." := InsertNewLine;
        ItemJournalLine."Entry Type" := ItemJournalLine."Entry Type"::"Positive Adjmt.";
        ItemJournalLine."Document No." := CreateDocNo(TransSalesEntry."Store No.", TransSalesEntry."POS Terminal No.", TransSalesEntry."Transaction No.");
        ItemJournalLine.Validate("Item No.", TransSalesEntry."Item No.");
        ItemJournalLine.Validate("Location Code", TransSalesEntry."Store No.");
        ItemJournalLine."Lot No." := TransSalesEntry."Lot No.";
        ItemJournalLine.Validate(Quantity, Faltante);
        ItemJournalLine."Posting Date" := Today();
        ItemJournalLine."Expiration Date" := TransSalesEntry."Expiration Date";
        ItemJournalLine."Source Code" := 'ITEMJNL';
        ItemJournalLine.Insert(true);
        CallItemTracking(ItemJournalLine);
    end;

    local procedure AjusteNegativo(ItemLedgerEntry: Record "Item Ledger Entry"; Faltantes: Decimal)
    var
        myInt: Integer;
        ItemJournalLine: Record "Item Journal Line";
    begin
        ItemJournalLine.Init();
        ItemJournalLine."Journal Template Name" := 'ITEM';
        ItemJournalLine."Journal Batch Name" := 'LOTE';
        ItemJournalLine."Line No." := InsertNewLine;
        ItemJournalLine."Entry Type" := ItemJournalLine."Entry Type"::"Negative Adjmt.";
        ItemJournalLine."Document No." := CreateDocNo(Rec."Store No.", Rec."POS Terminal No.", Rec."Transaction No.");
        ItemJournalLine.Validate("Item No.", ItemLedgerEntry."Item No.");
        ItemJournalLine.Validate("Location Code", ItemLedgerEntry."Location Code");
        ItemJournalLine.Validate(Quantity, Faltantes);
        ItemJournalLine."Lot No." := ItemLedgerEntry."Lot No.";
        ItemJournalLine."Posting Date" := Today();
        ItemJournalLine."Expiration Date" := ItemLedgerEntry."Expiration Date";
        ItemJournalLine."Source Code" := 'ITEMJNL';
        ItemJournalLine.Insert(true);

        CallItemTracking(ItemJournalLine);
    end;

    local procedure Reservation(ItemJournalLine: Record "Item Journal Line")
    var
        ReservationEntry: Record "Reservation Entry";
    begin
        ReservationEntry.Init();
        ReservationEntry."Entry No." := ReservationEntry.GetLastEntryNo() + 1;
        ReservationEntry.Validate("Item No.", ItemJournalLine."Item No.");
        ReservationEntry."Reservation Status" := ReservationEntry."Reservation Status"::Prospect;
        if ItemJournalLine."Entry Type" = ItemJournalLine."Entry Type"::"Negative Adjmt." then begin
            ReservationEntry.Positive := false;
            ReservationEntry.Validate("Quantity (Base)", ItemJournalLine.Quantity * -1);
            ReservationEntry.Validate(Quantity, ItemJournalLine.Quantity * -1);
            ReservationEntry."Source Subtype" := ReservationEntry."Source Subtype"::"3";
            ReservationEntry."Shipment Date" := Today;
        end else begin
            ReservationEntry.Positive := true;
            ReservationEntry.Validate("Quantity (Base)", ItemJournalLine.Quantity);
            ReservationEntry.Validate(Quantity, ItemJournalLine.Quantity);
            ReservationEntry."Expected Receipt Date" := Today;
            ReservationEntry."Source Subtype" := ReservationEntry."Source Subtype"::"2";
        end;
        ReservationEntry."Source Type" := 83;
        ReservationEntry."Lot No." := ItemJournalLine."Lot No.";
        ReservationEntry."Expiration Date" := ItemJournalLine."Expiration Date";
        ReservationEntry.Validate("Source ID", 'ITEM');
        ReservationEntry."Source Batch Name" := 'LOTE';
        ReservationEntry."Source Prod. Order Line" := 0;
        ReservationEntry."Source Ref. No." := ItemJournalLine."Line No.";
        ReservationEntry."Created By" := UserId;
        ReservationEntry.Insert(true);

    end;

    local procedure InsertNewLine(): Integer
    var
        ItemJournalLine: Record "Item Journal Line";
    begin
        ItemJournalLine.Reset();
        ItemJournalLine.SetRange("Journal Template Name", 'ITEM');
        ItemJournalLine.SetRange("Journal Batch Name", 'LOTE');
        if ItemJournalLine.FindLast() then
            exit(ItemJournalLine."Line No." + 10000)
        else
            exit(10000);
    end;



    local procedure AjustLot()
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
        Faltantes: Decimal;

    begin
        Faltantes := Rec.Faltante;
        ItemLedgerEntry.Reset();
        ItemLedgerEntry.SetRange("Item No.", Rec."Item No.");
        ItemLedgerEntry.SetFilter("Location Code", Rec."Store No.");
        ItemLedgerEntry.SetFilter("Lot No.", '<>%1&<>%2', Rec."Lot No.", '');
        ItemLedgerEntry.SetRange(Open, true);
        ItemLedgerEntry.SetFilter("Remaining Quantity", '>=%1', Rec.Faltante);
        if ItemLedgerEntry.FindFirst() then begin
            AjusteNegativo(ItemLedgerEntry, Rec.Faltante);
        end else begin
            ItemLedgerEntry.Reset();
            ItemLedgerEntry.SetRange("Item No.", Rec."Item No.");
            ItemLedgerEntry.SetFilter("Lot No.", '<>%1&<>%2', Rec."Lot No.", '');
            ItemLedgerEntry.SetFilter("Location Code", Rec."Store No.");
            ItemLedgerEntry.SetRange(Open, true);
            if ItemLedgerEntry.Find('-') then begin
                repeat
                    AjusteNegativo(ItemLedgerEntry, ItemLedgerEntry."Remaining Quantity");
                    Faltantes -= ItemLedgerEntry."Remaining Quantity";
                until (ItemLedgerEntry.Next = 0) or (Faltantes = 0);
            end;
        end;
    end;

    procedure CreateDocNo(StoreNo: Code[10]; POSTerminalNo: Code[10]; TransactionNo: Integer) DocNo: Code[50]
    var
        LText001: Label 'The length of the Document No. (%1) can not exceed 20 characters.\The Document No. is constructed by concatenating the Store No. (%2), POS Terminal No. (%3) and the Transaction No. (%4) separated by "-".\Please make sure the combined length of the Store No. and the POS Terminal No. does not exceed 10 characters.';
    begin
        DocNo := StoreNo + '-' +
          POSTerminalNo + '-' +
          Format(TransactionNo);
        if StrLen(DocNo) > 20 then
            Error(LText001, DocNo, StoreNo, POSTerminalNo, TransactionNo);
    end;

    local procedure ValidacionLote(Tipo: Integer)
    var
        TransalesEntry: Record "LSC Trans. Sales Entry";
        FSNLote: Record "FSN Lote Invalidate";
        Reman: Decimal;
    begin
        TransalesEntry.Reset();
        TransalesEntry.SetRange("Store No.", Rec."Store No.");
        TransalesEntry.SetRange("POS Terminal No.", Rec."Pos Terminal No.");
        TransalesEntry.SetRange("Transaction No.", Rec."Transaction No.");
        TransalesEntry.SetRange("Line No.", Rec."Line No.");
        if TransalesEntry.FindFirst() then
            if ValidateQuanity(TransalesEntry, Reman) then begin
                if Tipo = 2 then begin
                    FSNLote.SetRange("Store No.", Rec."Store No.");
                    FSNLote.SetRange("Lot No.", Rec."Lot No.");
                    FSNLote.DeleteAll();
                end else begin
                    FSNLote.SetRange("Store No.", Rec."Store No.");
                    FSNLote.SetRange("Lot No.", Rec."Lot No.");
                    FSNLote.SetRange("Pos Terminal No.", Rec."Pos Terminal No.");
                    FSNLote.SetRange("Transaction No.", Rec."Transaction No.");
                    FSNLote.DeleteAll();
                end;
            end else begin
                if TransalesEntry."Lot No." <> Rec."Lot No." then begin
                    Rec."Lot No." := TransalesEntry."Lot No.";
                    Rec."Expiration Date" := TransalesEntry."Expiration Date";
                    if Rec.Faltante <> FaltanteNo then
                        Rec.Faltante := FaltanteNo;

                    if (Rec."Lot No." <> '') and (Reman <> 0) then
                        Rec.Message := 'Cantidad de lote no es suficiente'
                    else
                        Rec.Message := 'Lote no existe en el sistema o ya fue vendido';

                    Rec.Modify(true);
                end else begin
                    if Rec.Faltante <> FaltanteNo then
                        Rec.Faltante := FaltanteNo;

                    if (Rec."Lot No." <> '') and (Reman <> 0) then
                        Rec.Message := 'Cantidad de lote no es suficiente'
                    else
                        Rec.Message := 'Lote no existe en el sistema o ya fue vendido';
                    Rec.Modify(true);
                end;
            end;
    end;

    local procedure ValidateQuanity(TransSales: Record "LSC Trans. Sales Entry"; var Remanente: Decimal): Boolean
    var
        TransSalesQ, TransSales2 : Record "LSC Trans. Sales Entry";
        TransSalesTemp: Record "LSC Trans. Sales Entry" temporary;
        ItemLengerEntry: Record "Item Ledger Entry";
        Vendidos: Decimal;
        Faltante: Decimal;
        Mensaje: Text[250];
        TransacHeader: Record "LSC Transaction Header";
        myInt: Integer;
        ExcludeFilter: Text;
    begin
        Remanente := 0;
        TransSales2.Reset();
        TransSales2.SetRange("Store No.", TransSales."Store No.");
        TransSales2.SetRange("Item No.", TransSales."Item No.");
        TransSales2.SetFilter(Date, '>=%1', DMY2Date(13, 1, 2025));
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
        Remanente := ItemLengerEntry."Remaining Quantity";

        FaltanteNo := Vendidos - Remanente;

        if Vendidos <= Remanente then
            exit(true)
        else
            exit(false)
    end;

    local procedure InsetLoteInvalido(TransSales: Record "LSC Trans. Sales Entry"; var Mensaje: Text[250]; Faltante: Decimal)
    var
        LoteInvd: Record "FSN Lote Invalidate";
    begin
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

    procedure ItemLedgerFilter(var ItemLedgerEntry: Record "Item Ledger Entry")

    begin
        ItemLedgerEntry.Reset();
        ItemLedgerEntry.SetRange("Item No.", Rec."Item No.");
        ItemLedgerEntry.SetFilter("Lot No.", '<>%1&<>%2', Rec."Lot No.", '');
        ItemLedgerEntry.SetRange("Location Code", Rec."Store No.");
        ItemLedgerEntry.SetRange(Open, true);
    end;

    procedure CambioLote(GlobalItemLedyer: Record "Item Ledger Entry")
    var
        TransSalesNew: Record "LSC Trans. Sales Entry";
    begin

        TransSalesNew.Reset();
        if TransSalesNew.Get(Rec."Store No.", Rec."POS Terminal No.", Rec."Transaction No.", Rec."Line No.") then begin
            TransSalesNew."Lot No." := GlobalItemLedyer."Lot No.";
            TransSalesNew."Expiration Date" := GlobalItemLedyer."Expiration Date";
            TransSalesNew."Serial No." := '';
            TransSalesNew."Serial/Lot No. Not Valid" := false;
            TransSalesNew.Modify(true);
        end;
    end;


}
codeunit 50062 ActualizacionNiveles
{
    TableNo = "LSC Scheduler Job Header";
    // WVILLALTA28FEB19                    - New functionality
    // WVILLALTA23ABR19                    - Set inventory CD = 0 when value´s item field "Barra" is empty

    trigger OnRun()
    begin
        GetInsertUpdateItemsAndInventory('CD', 'ITEM', 'DEFAULT', 'EBS');
    end;

    procedure GetInsertUpdateItemsAndInventory(WhsLogisticCode: Code[10]; ItemJrnTemplateCode: Code[10]; ItemBatchCode: Code[10]; JournalReasonCode: Code[10])
    var
        Item_l: Record Item;
        Item2_l: Record Item;
        ActualizacionNiveles_l: Record "FSN WMS Levels";
        Location_l: Record Location;
        ItemLedgerEntry_l: Record "Item Ledger Entry";
        ItemJournalLine_l: Record "Item Journal Line";
        ItemJournalBatch_l: Record "Item Journal Batch";
        ItemJrnTemplate_l: Record "Item Journal Template";
        QtyBaseAdjusment: Decimal;
        ItemStatusLink_l: Record "LSC Item Status Link";
        xItemStatusLink_l: Record "LSC Item Status Link" temporary;
        StatusCode: Code[10];
    begin

        IF (WhsLogisticCode = '') OR (ItemJrnTemplateCode = '') OR (ItemBatchCode = '') OR (JournalReasonCode = '') THEN
            EXIT;

        IF NOT ItemJrnTemplate_l.GET(ItemJrnTemplateCode) THEN
            EXIT;

        IF NOT ItemJournalBatch_l.GET(ItemJrnTemplateCode, ItemBatchCode) THEN
            EXIT;

        IF NOT Location_l.GET(WhsLogisticCode) THEN
            EXIT;

        IF NOT Location_l."LSC Location is a Warehouse" THEN
            EXIT;

        ClearJournalLines(ItemJournalBatch_l, JournalReasonCode);

        Item_l.RESET;
        IF Item_l.FINDFIRST THEN
            REPEAT
                IF ActualizacionNiveles_l.GET(Item_l."No.") THEN BEGIN
                    IF (ActualizacionNiveles_l.CodeBar <> Item_l."FSN Barcode No.") OR (ActualizacionNiveles_l."Unit of Measure" <> Item_l."Purch. Unit of Measure") THEN BEGIN
                        IF Item_l."FSN Barcode No." = '' THEN  //WVILLALTA23ABR19-
                            ActualizacionNiveles_l.InventoryCD := 0;    //WVILLALTA23ABR19-
                        ActualizacionNiveles_l.CodeBar := Item_l."FSN Barcode No.";
                        ActualizacionNiveles_l."Unit of Measure" := Item_l."Purch. Unit of Measure";
                        ActualizacionNiveles_l.MODIFY;
                    END;
                    StatusCode := GetItemFirstStatus(Item_l."No.");

                    IF (ActualizacionNiveles_l.NoNivelCD <> Item_l."FSN Warehouse Level") OR (StatusCode <> Item_l."FSN Item First Status") THEN
                        IF Item2_l.GET(ActualizacionNiveles_l.ItemNo) THEN BEGIN
                            Item2_l."FSN Item First Status" := StatusCode;

                            Item2_l."FSN Warehouse Level" := ActualizacionNiveles_l.NoNivelCD;
                            Item2_l.MODIFY(TRUE);
                        END;

                    /* QtyBaseAdjusment := GetInventoryDataDiff(Item_l, WhsLogisticCode, ActualizacionNiveles_l.InventoryCD);
                     IF QtyBaseAdjusment <> 0 THEN
                         UpdInventoryUseTemplate(Item_l, ItemJournalBatch_l, WhsLogisticCode, QtyBaseAdjusment, JournalReasonCode);*/
                END ELSE BEGIN
                    ActualizacionNiveles_l.INIT;
                    ActualizacionNiveles_l.ItemNo := Item_l."No.";
                    ActualizacionNiveles_l.CodeBar := Item_l."FSN Barcode No.";
                    ActualizacionNiveles_l.NoNivelCD := '';
                    ActualizacionNiveles_l.Fecha := TODAY;
                    ActualizacionNiveles_l.TIme := TIME;
                    ActualizacionNiveles_l."Unit of Measure" := Item_l."Purch. Unit of Measure";
                    ActualizacionNiveles_l.InventoryCD := 0;
                    ActualizacionNiveles_l.CodEBS := '';
                    ActualizacionNiveles_l.INSERT(true);

                    StatusCode := GetItemFirstStatus(Item_l."No.");
                    IF (ActualizacionNiveles_l.NoNivelCD <> Item_l."FSN Warehouse Level") OR (StatusCode <> Item_l."FSN Item First Status") THEN
                        IF Item2_l.GET(ActualizacionNiveles_l.ItemNo) THEN BEGIN
                            Item2_l."FSN Item First Status" := StatusCode;
                            Item2_l."FSN Warehouse Level" := ActualizacionNiveles_l.NoNivelCD;
                            Item2_l.MODIFY(TRUE);
                        END;
                END;
            UNTIL Item_l.NEXT = 0;
    end;

    procedure GetInventoryDataDiff(pItem_l: Record "Item"; LogisticCode: Code[10]; InventoryExternalData: Decimal): Decimal
    var
        ItemLedgerEntry_l: Record "Item Ledger Entry";
        ItemUnitofMeasure_l: Record "Item Unit of Measure";
    begin
        ItemLedgerEntry_l.RESET;
        ItemLedgerEntry_l.SETCURRENTKEY("Item No.", Open, "Variant Code", "Location Code");
        ItemLedgerEntry_l.SETRANGE(ItemLedgerEntry_l."Item No.", pItem_l."No.");
        ItemLedgerEntry_l.SETRANGE(ItemLedgerEntry_l.Open, TRUE);
        ItemLedgerEntry_l.SETRANGE(ItemLedgerEntry_l."Variant Code", '');
        ItemLedgerEntry_l.SETRANGE(ItemLedgerEntry_l."Location Code", LogisticCode);
        ItemLedgerEntry_l.CALCSUMS(ItemLedgerEntry_l."Remaining Quantity");
        IF (ItemLedgerEntry_l."Remaining Quantity" = 0) AND (InventoryExternalData = 0) THEN
            EXIT(0);

        IF ItemUnitofMeasure_l.GET(pItem_l."No.", pItem_l."Purch. Unit of Measure") THEN
            IF ((InventoryExternalData * ItemUnitofMeasure_l."Qty. per Unit of Measure") <> (ItemLedgerEntry_l."Remaining Quantity")) THEN
                EXIT((InventoryExternalData * ItemUnitofMeasure_l."Qty. per Unit of Measure") - (ItemLedgerEntry_l."Remaining Quantity"));
        EXIT(0);
    end;

    procedure GetItemFirstStatus(ItemNo: Code[20]) StatusCode: Code[10]
    var
        ItemStatusLink_l: Record "LSC Item Status Link";
        xItemStatusLink_l: Record "LSC Item Status Link" temporary;
        intPOS: Integer;
        lText001: Label 'ACTIVO';
    begin
        StatusCode := lText001;
        intPOS := 1;
        ItemStatusLink_l.RESET;
        ItemStatusLink_l.SETCURRENTKEY("Item No.", "Variant Dimension 1 Code", "Variant Code", "Store Group Code", "Location Code", "Starting Date");
        ItemStatusLink_l.SETRANGE(ItemStatusLink_l."Item No.", ItemNo);
        ItemStatusLink_l.SETRANGE(ItemStatusLink_l."Variant Dimension 1 Code", '');
        ItemStatusLink_l.SETRANGE(ItemStatusLink_l."Variant Code", '');
        ItemStatusLink_l.SETRANGE(ItemStatusLink_l."Location Code", '');
        ItemStatusLink_l.SETFILTER(ItemStatusLink_l."Starting Date", '=%1|<=%2', 0D, TODAY);
        IF ItemStatusLink_l.FIND('-') THEN
            REPEAT
                IF intPOS = 1 THEN BEGIN
                    StatusCode := ItemStatusLink_l."Status Code";
                    xItemStatusLink_l := ItemStatusLink_l;
                END ELSE BEGIN
                    IF (ItemStatusLink_l."Block Sale on POS" OR ItemStatusLink_l."Block Purchasing" OR ItemStatusLink_l."Block Transferring") AND
                      NOT (xItemStatusLink_l."Block Sale on POS" OR xItemStatusLink_l."Block Purchasing" OR xItemStatusLink_l."Block Transferring") THEN BEGIN
                        StatusCode := ItemStatusLink_l."Status Code";
                        xItemStatusLink_l := ItemStatusLink_l;
                    END;
                END;
                intPOS += 1;
            UNTIL ItemStatusLink_l.NEXT = 0;
    end;

    procedure UpdInventoryUseTemplate(pItem_l: Record Item; pItemJrnBatch_l: Record "Item Journal Batch"; LocationCode: Code[10]; QtyAdjustment: Decimal; ReasonCode: Code[10])
    var
        ItemJournalLine_l: Record "Item Journal Line";
        LineNo: Integer;
        lText001: Label 'AJUSTECD';
    begin
        IF QtyAdjustment = 0 THEN EXIT;
        ItemJournalLine_l.RESET;
        ItemJournalLine_l.SETCURRENTKEY("Journal Template Name", "Journal Batch Name", "Line No.");
        ItemJournalLine_l.SETRANGE(ItemJournalLine_l."Journal Template Name", pItemJrnBatch_l."Journal Template Name");
        ItemJournalLine_l.SETRANGE(ItemJournalLine_l."Journal Batch Name", pItemJrnBatch_l.Name);
        IF ItemJournalLine_l.FINDLAST THEN
            LineNo := ItemJournalLine_l."Line No." + 100
        ELSE
            LineNo := 11000;

        ItemJournalLine_l.INIT;
        ItemJournalLine_l."Journal Template Name" := pItemJrnBatch_l."Journal Template Name";
        ItemJournalLine_l."Journal Batch Name" := pItemJrnBatch_l.Name;
        ItemJournalLine_l."Line No." := LineNo;
        IF QtyAdjustment < 0 THEN
            ItemJournalLine_l."Entry Type" := ItemJournalLine_l."Entry Type"::"Negative Adjmt."
        ELSE
            ItemJournalLine_l."Entry Type" := ItemJournalLine_l."Entry Type"::"Positive Adjmt.";
        ItemJournalLine_l.VALIDATE(ItemJournalLine_l."Item No.", pItem_l."No.");
        ItemJournalLine_l.VALIDATE(ItemJournalLine_l."Document No.", lText001);
        ItemJournalLine_l.VALIDATE(ItemJournalLine_l."Location Code", LocationCode);
        ItemJournalLine_l.VALIDATE(ItemJournalLine_l."Unit of Measure Code", pItem_l."Base Unit of Measure");
        ItemJournalLine_l.VALIDATE(ItemJournalLine_l.Quantity, ABS(QtyAdjustment));
        ItemJournalLine_l."Document Date" := TODAY;
        ItemJournalLine_l.VALIDATE(ItemJournalLine_l."Posting Date", TODAY);
        ItemJournalLine_l.VALIDATE(ItemJournalLine_l."Return Reason Code", ReasonCode);
        IF ItemJournalLine_l.INSERT(TRUE) THEN; //Control Error
    end;

    procedure ClearJournalLines(pJournalBatch_l: Record "Item Journal Batch"; pReasonCode: Code[10])
    var
        ClearItemJournalLine: Record "Item Journal Line";
    begin
        ClearItemJournalLine.RESET;
        ClearItemJournalLine.SETRANGE(ClearItemJournalLine."Journal Template Name", pJournalBatch_l."Journal Template Name");
        ClearItemJournalLine.SETRANGE(ClearItemJournalLine."Journal Batch Name", pJournalBatch_l.Name);
        ClearItemJournalLine.SETRANGE(ClearItemJournalLine."Return Reason Code", pReasonCode);
        ClearItemJournalLine.DELETEALL;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Jnl.-Post", 'OnBeforeCode', '', true, true)]
    local procedure "Item Jnl.-Post_OnBeforeCode"
    (
        var ItemJournalLine: Record "Item Journal Line";
        var HideDialog: Boolean;
        var SuppressCommit: Boolean;
        var IsHandled: Boolean
    )
    begin
        HideDialog := true;
    end;
}
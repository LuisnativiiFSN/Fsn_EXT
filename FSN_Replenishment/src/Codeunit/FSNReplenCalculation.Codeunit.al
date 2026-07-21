codeunit 50007 "FSN Replen. Calculation"
{
    TableNo = "LSC Scheduler Job Header";
    trigger OnRun()
    begin
        if Rec.Code = 'TRANSFER' then
            ReplenTemplateTransfers();
        if Rec.Code = 'PURCHASE' then
            ReplenTemplatePurchases();
        if Rec.Code = 'CONSOLID' then begin
            SetAllPurchConsolidateNo;
            SetAllTransferConsolidateNo();
            RunBatchSendPurchase(Rec.Code);
        end;
        if Rec.Code = 'AUTBASH' then begin
            BatchAut;
        end;
        //JH23082024*********************
        //Se crean los pedidos compras, se llenaran los libros de reaprovisionamiento desde un sp
        if Rec.Code = 'PURCH-SP' then begin
            PurchaseSP;
        end;
        //JH23082024*********************

        //JH 26062024 ***Se comenta la siguiente linea ya que se hace un update por toda la tablaa
        //ValidateInventoryDec;

    end;

    var
        PG: Page "LSC Transf Replen. Jrnl Det.";
        NoSerie: Codeunit NoSeriesManagement;
        ReplenSetup: Record "LSC Replen. Setup";
        RQ: Codeunit "LSC Replen. Calculation";
        FRQ: Codeunit "FSN Replen. Calculation";
        RplJournBat: Record "LSC Replen. Journal Batch";
        contador: Integer;

    procedure BatchAut()
    var
        ReplenishmentJournalLines: Record "LSC Replen. Journal Lines";
        TransferOrder1: Record "Transfer Header";
        ReplenSetup1: Record "LSC Replen. Setup";
        NoSeriesMgt: Codeunit NoSeriesManagement;
        ConsolidateNo: Code[20];
        NoOfLinesSelected: Integer;
        BatchPostingStatus: Text[30];
        BatchPosting: Codeunit "LSC Batch Posting";
        JournalOnBatchPostingErr: Label 'Journal has been put on the Batch Posting Queue.';
        ReplenishmCreateTransfOrd: Codeunit "LSC Replen. Create Transf. Ord";
        ReplenishmentJournalBatch: Record "LSC Replen. Journal Batch";
        FirstTransferNo: Code[20];
        LastTransferNo: Code[20];
        FirstSalesOrderNo: Code[20];
        LastSalesOrderNo: Code[20];
        OrderCreatedMsg_g: Text;
        TransferNoCreatedMsg: Label 'Transfer number %1 was created.';
        TransferNoRangeCreatedMsg: Label 'Transfer numbers %1 through %2 were created.';
        SalesNoCreatedMsg: Label 'Sales number %1 was created.';
        SalesNoRangeCreatedMsg: Label 'Sales numbers %1 through %2 were created.';
        ConsolidateTxt: Label '. Consolidate No. %1';
        Recd: Record "LSC Replen. Journal Lines";
        RecdTemp: Record "LSC Replen. Journal Lines" temporary;
        ReplenTemplate: Record "LSC Replen. Template";
        Process: Boolean;
        fsnReplenCalc: Codeunit "FSN Replen. Calculation";

    begin

        ReplenishmentJournalBatch.Reset();
        ReplenishmentJournalBatch.SetRange(ReplenishmentJournalBatch."Next Run Date", TODAY);
        if ReplenishmentJournalBatch.Find('-') then begin
            repeat
                Process := true;
                if ReplenTemplate.Get(ReplenishmentJournalBatch."Replenishment Template Code") and (ReplenTemplate."Replenishment Type" <> ReplenTemplate."Replenishment Type"::Transfer) then
                    Process := false;

                if Process then
                    if (ReplenTemplate."Create Orders Automatically" <> ReplenTemplate."Create Orders Automatically"::"Create Orders Automatically") then
                        Process := false;
                //ReplenishmentJournalBatch.Get('CD-LUN-REF', 'DEFAULT');
                if Process then begin
                    BatchPostingStatus := BatchPosting.GetReplenishmentBatchStatus(ReplenishmentJournalBatch);

                    ReplenSetup1.Get();
                    ReplenSetup1.TestField("FSN Transfer Consolidate No.");

                    if BatchPostingStatus <> '' then
                        Error(JournalOnBatchPostingErr);

                    RecdTemp.DeleteAll();
                    Clear(RecdTemp);

                    Recd.Reset;
                    Recd.SetRange("Replenishment Template Code", ReplenishmentJournalBatch."Replenishment Template Code");
                    Recd.SetRange("Batch No.", ReplenishmentJournalBatch."Batch No.");
                    IF Recd.Find('-') then;

                    /*if not Confirm(CreateTOQst, false) then
                        exit;*/

                    if ReplenishmentJournalBatch.CheckThresholdBlockDocCreation(ReplenishmentJournalBatch."Replenishment Template Code", ReplenishmentJournalBatch."Batch No.") then
                        /*if not Confirm(ThresholdExceptionFoundDocCreationQst) then
                            exit;*/
                     Clear(ReplenishmCreateTransfOrd);

                    ReplenishmentJournalLines := Recd;
                    ReplenishmentJournalLines.Reset;
                    //CurrPage.SetSelectionFilter(ReplenishmentJournalLines);

                    NoOfLinesSelected := ReplenishmentJournalLines.Count;
                    if (NoOfLinesSelected = 1) then begin
                        ReplenishmentJournalLines.Reset;
                        ReplenishmentJournalLines.SetRange("Replenishment Template Code", Recd."Replenishment Template Code");
                        ReplenishmentJournalLines.SetRange("Batch No.", Recd."Batch No.");
                    end;

                    ReplenishmCreateTransfOrd.CreateTransfOrders(ReplenishmentJournalLines, FirstTransferNo, LastTransferNo, FirstSalesOrderNo, LastSalesOrderNo);

                    TransferOrder1.Reset();
                    if (FirstTransferNo <> '') then begin
                        ConsolidateNo := NoSeriesMgt.GetNextNo(ReplenSetup1."FSN Transfer Consolidate No.", today, true);

                        TransferOrder1.SetRange("No.", FirstTransferNo, LastTransferNo);
                        if TransferOrder1.Find('-') then
                            repeat
                                TransferOrder1."FSN Consolidate No." := ConsolidateNo;
                                TransferOrder1.Modify();
                            until TransferOrder1.Next() = 0;
                        fsnReplenCalc.TransferUpPitsConsolid('REPL-CONSOLID', FirstTransferNo, LastTransferNo, ConsolidateNo);
                    end;

                    Clear(OrderCreatedMsg_g);
                    if FirstTransferNo <> '' then
                        if FirstTransferNo = LastTransferNo then
                            OrderCreatedMsg_g := StrSubstNo(TransferNoCreatedMsg, FirstTransferNo)
                        else
                            OrderCreatedMsg_g := StrSubstNo(TransferNoRangeCreatedMsg, FirstTransferNo, LastTransferNo);

                    if FirstSalesOrderNo <> '' then begin
                        if OrderCreatedMsg_g <> '' then
                            OrderCreatedMsg_g := OrderCreatedMsg_g + '\\';
                        if FirstSalesOrderNo = LastSalesOrderNo then
                            OrderCreatedMsg_g := OrderCreatedMsg_g + StrSubstNo(SalesNoCreatedMsg, FirstSalesOrderNo)
                        else
                            OrderCreatedMsg_g := OrderCreatedMsg_g + StrSubstNo(SalesNoRangeCreatedMsg, FirstSalesOrderNo, LastSalesOrderNo);
                    end;
                    if ConsolidateNo <> '' then
                        OrderCreatedMsg_g := OrderCreatedMsg_g + StrSubstNo(ConsolidateTxt, ConsolidateNo);

                    /*if OrderCreatedMsg_g <> '' then
                        Message(OrderCreatedMsg_g);*/

                    if ConsolidateNo <> '' then begin
                        ReplenishmentJournalLines.Reset;
                        ReplenishmentJournalLines.SetRange("Replenishment Template Code", Recd."Replenishment Template Code");
                        ReplenishmentJournalLines.SetRange("Batch No.", Recd."Batch No.");
                        if ReplenishmentJournalLines.Find('-') then
                            repeat
                                ReplenishmentJournalLines.Delete();
                            until ReplenishmentJournalLines.Next() = 0;

                        ReplenishmentJournalBatch."Last Run Date" := TODAY;
                        ReplenishmentJournalBatch."Last Run Time" := Time;
                        ReplenishmentJournalBatch.Validate("Next Run Date", Today + 1);
                        ReplenishmentJournalBatch.Modify(TRUE);
                    end;
                end;
            until ReplenishmentJournalBatch.Next() = 0;
        end;
    end;

    procedure PurchaseSP()
    var
        ReplenishmentJournalLines: Record "LSC Replen. Journal Lines";
        PurchaseOrders: Record "Purchase Header";
        ReplenSetup1: Record "LSC Replen. Setup";
        NoSeriesMgt: Codeunit NoSeriesManagement;
        ConsolidateNo: Code[20];
        NoOfLinesSelected: Integer;
        BatchPostingStatus: Text[30];
        BatchPosting: Codeunit "LSC Batch Posting";
        JournalOnBatchPostingErr: Label 'Journal has been put on the Batch Posting Queue.';
        ReplenishmCreatePurchaseOrd: Codeunit "LSC Replen. Create Purch Order";
        ReplenishmentJournalBatch: Record "LSC Replen. Journal Batch";
        FirstPurchaseNo: Code[20];
        LastPurchaseNo: Code[20];
        OrderCreatedMsg_g: Text;
        PurchaseNoCreatedMsg: Label 'Purchase number %1 was created.';
        PurchaseNoRangeCreatedMsg: Label 'Purchase numbers %1 through %2 were created.';
        ConsolidateTxt: Label '. Consolidate No. %1';
        Recd: Record "LSC Replen. Journal Lines";
        RecdTemp: Record "LSC Replen. Journal Lines" temporary;
        ReplenTemplate: Record "LSC Replen. Template";
        Process: Boolean;

    begin
        //Verificar que la tarea no se haya ejecutado mas de una ves en el mismo día
        ReplenishmentJournalBatch.Reset();
        ReplenishmentJournalBatch.SetFilter("Replenishment Template Code", '%1|%2', '360-1', '360-L-M');
        ReplenishmentJournalBatch.SetRange(ReplenishmentJournalBatch."Next Run Date", TODAY);
        if ReplenishmentJournalBatch.Find('-') then begin
            repeat
                Process := true;
                if ReplenTemplate.Get(ReplenishmentJournalBatch."Replenishment Template Code") and (ReplenTemplate."Replenishment Type" <> ReplenTemplate."Replenishment Type"::Purchase) then
                    Process := false;

                if Process then
                    if (ReplenTemplate."Create Orders Automatically" <> ReplenTemplate."Create Orders Automatically"::"Create Orders Automatically") then
                        Process := false;
                //ReplenishmentJournalBatch.Get('CD-LUN-REF', 'DEFAULT');
                if Process then begin
                    BatchPostingStatus := BatchPosting.GetReplenishmentBatchStatus(ReplenishmentJournalBatch);

                    ReplenSetup1.Get();
                    ReplenSetup1.TestField("FSN Transfer Consolidate No.");

                    if BatchPostingStatus <> '' then
                        Error(JournalOnBatchPostingErr);

                    RecdTemp.DeleteAll();
                    Clear(RecdTemp);

                    Recd.Reset;
                    Recd.SetRange("Replenishment Template Code", ReplenishmentJournalBatch."Replenishment Template Code");
                    Recd.SetRange("Batch No.", ReplenishmentJournalBatch."Batch No.");
                    IF Recd.Find('-') then;

                    /*if not Confirm(CreateTOQst, false) then
                        exit;*/

                    if ReplenishmentJournalBatch.CheckThresholdBlockDocCreation(ReplenishmentJournalBatch."Replenishment Template Code", ReplenishmentJournalBatch."Batch No.") then
                        /*if not Confirm(ThresholdExceptionFoundDocCreationQst) then
                            exit;*/
                     Clear(ReplenishmCreatePurchaseOrd);


                    ReplenishmentJournalLines := Recd;
                    ReplenishmentJournalLines.Reset;
                    //CurrPage.SetSelectionFilter(ReplenishmentJournalLines);

                    NoOfLinesSelected := ReplenishmentJournalLines.Count;
                    if (NoOfLinesSelected = 1) then begin
                        ReplenishmentJournalLines.Reset;
                        ReplenishmentJournalLines.SetRange("Replenishment Template Code", Recd."Replenishment Template Code");
                        ReplenishmentJournalLines.SetRange("Batch No.", Recd."Batch No.");
                    end;
                    //Se crean las ordenes
                    ReplenishmCreatePurchaseOrd.CreatePurchaseOrders(ReplenishmentJournalLines, FirstPurchaseNo, LastPurchaseNo);

                    PurchaseOrders.Reset();
                    if (FirstPurchaseNo <> '') then begin
                        ConsolidateNo := NoSeriesMgt.GetNextNo(ReplenSetup1."FSN Transfer Consolidate No.", today, true);
                        PurchaseOrders.SetRange("No.", FirstPurchaseNo, LastPurchaseNo);
                        if PurchaseOrders.Find('-') then
                            repeat
                                PurchaseOrders."FSN Consolidate No." := ConsolidateNo;
                                PurchaseOrders.Modify();
                            until PurchaseOrders.Next() = 0;
                    end;

                    Clear(OrderCreatedMsg_g);
                    if FirstPurchaseNo <> '' then
                        if FirstPurchaseNo = LastPurchaseNo then
                            OrderCreatedMsg_g := StrSubstNo(PurchaseNoCreatedMsg, FirstPurchaseNo)
                        else
                            OrderCreatedMsg_g := StrSubstNo(PurchaseNoRangeCreatedMsg, FirstPurchaseNo, LastPurchaseNo);
                    /*
                    if FirstSalesOrderNo <> '' then begin
                        if OrderCreatedMsg_g <> '' then
                            OrderCreatedMsg_g := OrderCreatedMsg_g + '\\';
                        if FirstSalesOrderNo = LastSalesOrderNo then
                            OrderCreatedMsg_g := OrderCreatedMsg_g + StrSubstNo(SalesNoCreatedMsg, FirstSalesOrderNo)
                        else
                            OrderCreatedMsg_g := OrderCreatedMsg_g + StrSubstNo(SalesNoRangeCreatedMsg, FirstSalesOrderNo, LastSalesOrderNo);
                    end;
                    */
                    if ConsolidateNo <> '' then
                        OrderCreatedMsg_g := OrderCreatedMsg_g + StrSubstNo(ConsolidateTxt, ConsolidateNo);

                    /*if OrderCreatedMsg_g <> '' then
                        Message(OrderCreatedMsg_g);*/

                    if ConsolidateNo <> '' then begin
                        ReplenishmentJournalLines.Reset;
                        ReplenishmentJournalLines.SetRange("Replenishment Template Code", Recd."Replenishment Template Code");
                        ReplenishmentJournalLines.SetRange("Batch No.", Recd."Batch No.");
                        if ReplenishmentJournalLines.Find('-') then
                            repeat
                                ReplenishmentJournalLines.Delete();
                            until ReplenishmentJournalLines.Next() = 0;

                        ReplenishmentJournalBatch."Last Run Date" := TODAY;
                        ReplenishmentJournalBatch."Last Run Time" := Time;
                        ReplenishmentJournalBatch.Validate("Next Run Date", Today + 1);
                        ReplenishmentJournalBatch.Modify(TRUE);
                    end;
                end;
            until ReplenishmentJournalBatch.Next() = 0;
        end;
    end;

    procedure ReplenTemplatePurchases()
    var
        //REPORTReplenAutomRUN: Report "FSN Replen. Automatic Run";
        REPORTReplenAutomRUNPurchase: Report "FSN Replen. Aut. Run Purchase";
        repor: Codeunit "LSC Replen. Calculation";
        replaut: report "LSC Replen. Automatic Run";
        ReplenishmentTypeFilter: Option "Purchase and Transfer",Purchase,Transfer;
    begin
        /*Clear(REPORTReplenAutomRUN);
        REPORTReplenAutomRUN.SetFilterReplenType(ReplenishmentTypeFilter::Purchase);
        REPORTReplenAutomRUN.Execute('');*/
        Clear(REPORTReplenAutomRUNPurchase);
        REPORTReplenAutomRUNPurchase.Execute('');
    end;

    procedure ReplenTemplateTransfers()
    var
        //REPORTReplenAutomRUN: Report "FSN Replen. Automatic Run";
        REPORTReplenAutomRUNTransfer: Report "FSN Replen. Aut. Run Transfer";
        ReplenishmentTypeFilter: Option "Purchase and Transfer",Purchase,Transfer;
    begin
        /*Clear(REPORTReplenAutomRUN);
        REPORTReplenAutomRUN.SetFilterReplenType(ReplenishmentTypeFilter::Transfer);
        REPORTReplenAutomRUN.Execute('');*/

        Clear(REPORTReplenAutomRUNTransfer);
        REPORTReplenAutomRUNTransfer.Execute('');
    end;

    procedure VerifyMultipleReplenRecConsistency(var NewRec: Record "LSC Replen. Item Store Rec"; var OldRec: Record "LSC Replen. Item Store Rec"; eventPage: Boolean)
    var
        Item_l: Record Item;
        UOM: Record "Item Unit of Measure";
    begin
        if not eventPage then begin
            if ((NewRec."FSN Minimum" <> OldRec."FSN Minimum") or (NewRec."FSN Maximum" <> OldRec."FSN Maximum")) or
            (NewRec."Reorder Point" <> OldRec."Reorder Point") or (NewRec."Maximum Inventory" <> OldRec."Maximum Inventory") or
            (NewRec."FSN Purch. Multiple" <> OldRec."FSN Purch. Multiple") or (NewRec."FSN Transfer Multiple" <> OldRec."FSN Transfer Multiple") then
                if Item_l.Get(NewRec."Item No.") then
                    if UOM.Get(Item_l."No.", Item_l."Purch. Unit of Measure") then begin
                        NewRec."Reorder Point" := NewRec."FSN Minimum" * UOM."Qty. per Unit of Measure";
                        NewRec."Maximum Inventory" := NewRec."FSN Maximum" * UOM."Qty. per Unit of Measure";
                        NewRec."Purchase Order Multiple" := NewRec."FSN Purch. Multiple" * UOM."Qty. per Unit of Measure";
                        NewRec."Transfer Multiple" := NewRec."FSN Transfer Multiple" * UOM."Qty. per Unit of Measure";
                    end;

        end else begin
            if Item_l.Get(NewRec."Item No.") then
                if UOM.Get(Item_l."No.", Item_l."Purch. Unit of Measure") then begin
                    NewRec."Reorder Point" := NewRec."FSN Minimum" * UOM."Qty. per Unit of Measure";
                    NewRec."Maximum Inventory" := NewRec."FSN Maximum" * UOM."Qty. per Unit of Measure";
                    NewRec."Purchase Order Multiple" := NewRec."FSN Purch. Multiple" * UOM."Qty. per Unit of Measure";
                    NewRec."Transfer Multiple" := NewRec."FSN Transfer Multiple" * UOM."Qty. per Unit of Measure";
                end;
        end;
    end;

    local procedure VerifyReplenRecDescriptions(Rec: Record Item; xRec: Record Item)
    var
        ReplenItemStoreRec: Record "LSC Replen. Item Store Rec";
        ReplenItemStoreRec2: Record "LSC Replen. Item Store Rec";
    begin
        if (Rec."Item Category Code" <> xRec."Item Category Code") or
        (Rec."LSC Retail Product Code" <> xRec."LSC Retail Product Code") or
        (Rec."LSC Division Code" <> xRec."LSC Division Code") or
        (Rec."Purch. Unit of Measure" <> xRec."Purch. Unit of Measure") then begin
            ReplenItemStoreRec.Reset();
            ReplenItemStoreRec.SetRange(ReplenItemStoreRec."Item No.", Rec."No.");
            if ReplenItemStoreRec.Find('-') then
                repeat
                    ReplenItemStoreRec2 := ReplenItemStoreRec;

                    if (ReplenItemStoreRec."FSN Category Code" <> Rec."Item Category Code") or
                    (ReplenItemStoreRec."FSN Product Group Code" <> Rec."LSC Retail Product Code") or
                    (ReplenItemStoreRec."FSN Category Code" <> Rec."LSC Division Code") or
                    (Rec."Purch. Unit of Measure" <> xRec."Purch. Unit of Measure") then begin
                        ReplenItemStoreRec."FSN Product Group Code" := Rec."LSC Retail Product Code";
                        ReplenItemStoreRec."FSN Category Code" := Rec."Item Category Code";
                        ReplenItemStoreRec."FSN Division Code" := Rec."LSC Division Code";
                        if Rec."Purch. Unit of Measure" <> xRec."Purch. Unit of Measure" then begin
                            if (ReplenItemStoreRec."Maximum Inventory" <> 0) or
                                (ReplenItemStoreRec."Reorder Point" <> 0) then begin
                                ReplenItemStoreRec."Maximum Inventory" := 0;
                                ReplenItemStoreRec."Maximum Inventory" := 0;
                            end;

                        end;
                        ReplenItemStoreRec.Modify()
                    end;

                until ReplenItemStoreRec.next() = 0;
        end;
    end;

    procedure FSNInicializeReplenRec(var Rec: Record "LSC Replen. Item Store Rec")
    var
        Item: Record Item;
        UOM: record "Item Unit of Measure";
    begin
        if Item.Get(Rec."Item No.") then
            if UOM.Get(Item."No.", Item."Purch. Unit of Measure") then begin
                Rec."FSN Maximum" := 0;
                Rec."FSN Minimum" := 0;
                Rec."Maximum Inventory" := 0;
                Rec."Reorder Point" := 0;
                Rec."FSN Purch. Multiple" := 1;
                Rec."FSN Transfer Multiple" := 1;
                Rec."FSN Approach Multiple" := 0;
                Rec."Transfer Multiple" := UOM."Qty. per Unit of Measure";
                Rec."Purchase Order Multiple" := UOM."Qty. per Unit of Measure";
                Rec."FSN Product Group Code" := Item."LSC Retail Product Code";
                Rec."FSN Category Code" := Item."Item Category Code";
                Rec."FSN Division Code" := Item."LSC Division Code";
                Rec."Vendor No." := Item."Vendor No.";
            end;
    end;
    /*
        procedure ProcessApproachPurchMult(var pReplenDetails: Record "LSC Replen. Jrnl. Details"; pReplenItemRec: Record "LSC Replen. Item Store Rec"; UnitMeasure: Code[10])
        var
            Conversor: Decimal;
            ModDiv: Decimal;
            RelationDiv: Decimal;
            QtyPurch: Decimal;
            ReturnQty: Decimal;
            ReplenSetup1: Record "LSC Replen. Setup";
            UnitM: Record "Item Unit of Measure";
            pg: page "LSC Purchase Replen. Journal";
        begin
            if (pReplenItemRec."FSN Approach Multiple" < 2) or (pReplenItemRec."FSN Purch. Multiple" < 1) then
                exit;

            CLEAR(Conversor);
            CLEAR(ModDiv);
            if not UnitM.Get(pReplenDetails."Item No.", UnitMeasure) then
                UnitM."Qty. per Unit of Measure" := 1;

            pReplenItemRec."FSN Approach Multiple" := pReplenItemRec."FSN Approach Multiple" * UnitM."Qty. per Unit of Measure";

            if pReplenItemRec."FSN Purch. Multiple" < 2 then
                pReplenItemRec."FSN Purch. Multiple" := 1;

            if not (pReplenDetails.Quantity mod pReplenItemRec."FSN Purch. Multiple" = 0) then
                exit
            else
                QtyPurch := pReplenDetails.Quantity / pReplenItemRec."FSN Purch. Multiple";

            if (pReplenDetails.Quantity < 1) or (pReplenDetails."Calculation Type" <> pReplenDetails."Calculation Type"::"Stock Levels") then
                exit;
            if (pReplenItemRec."FSN Approach Multiple" < pReplenItemRec."FSN Purch. Multiple") or
                       (pReplenItemRec."FSN Approach Multiple" MOD pReplenItemRec."FSN Purch. Multiple" <> 0)
                   then
                exit;

            if (QtyPurch < pReplenItemRec."FSN Approach Multiple") and ((QtyPurch / pReplenItemRec."FSN Approach Multiple") < ReplenSetup1."FSN Approach Multiple %") then
                if pReplenItemRec."FSN Purch. Multiple" > 1 then
                    exit
                else begin
                    if QtyPurch <= 30 then//Min static
                        pReplenDetails.VALIDATE(Quantity, SetStaticMultipleLess(pReplenItemRec, QtyPurch, ReplenSetup1."FSN Approach Adjustment Type") * pReplenItemRec."FSN Purch. Multiple");
                    exit;
                end;

            Clear(RelationDiv);
            Clear(ReturnQty);
            RelationDiv := QtyPurch / pReplenItemRec."FSN Approach Multiple";
            CASE TRUE OF
                (RelationDiv < ReplenSetup1."FSN Approach Multiple %"):
                    BEGIN
                        ReturnQty := QtyPurch;
                    END;
                (RelationDiv >= ReplenSetup1."FSN Approach Multiple %") AND (RelationDiv <= (1 + ((100 - ReplenSetup1."FSN Approach Multiple %") / 100))):
                    BEGIN
                        ReturnQty := pReplenItemRec."FSN Approach Multiple";
                    END;
                (RelationDiv < 5):
                    BEGIN
                        ModDiv := ROUND(RelationDiv, 1, '=');
                        ReturnQty := pReplenItemRec."FSN Approach Multiple" * ModDiv;

                        IF (pReplenItemRec."FSN Maximum" <= ReturnQty) AND (ModDiv > 1) THEN
                            ReturnQty := pReplenItemRec."FSN Approach Multiple" * (ModDiv - 1);

                        IF (ReturnQty / QtyPurch) < (ReplenSetup1."FSN Approach Multiple %" / 100) THEN
                            ReturnQty := (ROUND(QtyPurch / 100, 0.1, '<') * 100);

                    END;
                (RelationDiv >= 5):
                    BEGIN
                        ModDiv := ReturnQty DIV pReplenItemRec."FSN Approach Multiple";
                        ReturnQty := (ModDiv + 1) * (pReplenItemRec."FSN Approach Multiple");
                        IF (pReplenItemRec."FSN Maximum" <= ReturnQty) AND (ModDiv > 1) THEN
                            ReturnQty := pReplenItemRec."FSN Approach Multiple" * (ModDiv);

                        IF (pReplenItemRec."FSN Maximum" <= ReturnQty) AND (ModDiv > 1) THEN
                            ReturnQty := pReplenItemRec."FSN Approach Multiple" * (ModDiv - 1);
                    END;
            END;

            case ReplenSetup1."FSN Approach Adjustment Type" of
                ReplenSetup1."FSN Approach Adjustment Type"::LowerOrHigher:
                    pReplenDetails.Validate(Quantity, (ReturnQty * pReplenItemRec."Purchase Order Multiple"));
                ReplenSetup1."FSN Approach Adjustment Type"::Lower:
                    begin
                        if ReturnQty > QtyPurch then
                            ReturnQty := QtyPurch;

                        pReplenDetails.Validate(Quantity, (ReturnQty * pReplenItemRec."Purchase Order Multiple"));
                    end;
                ReplenSetup1."FSN Approach Adjustment Type"::Higher:
                    begin
                        if ReturnQty < QtyPurch then
                            ReturnQty := QtyPurch;
                        pReplenDetails.Validate(Quantity, (ReturnQty * pReplenItemRec."Purchase Order Multiple"));
                    end;
            end;
            pReplenDetails.Modify(true);
            //pg.Update();
        end;

        local procedure SetStaticMultipleLess(pReplenItemRec: Record "LSC Replen. Item Store Rec"; pValue: Decimal; FSNApproachAdjustmentType: option LowerOrHigher,Higher,Lower) ReturnQty: Decimal
        var
            Conversor: Decimal;
            ModDiv: Decimal;
            RelationDiv: Decimal;
        begin
            ReturnQty := pValue;
            CASE TRUE OF
                (pValue > 5) AND (pValue < 10):
                    IF pReplenItemRec."FSN Maximum" >= 15 THEN
                        ReturnQty := 10;
                (pValue > 10) AND (pValue < 19):
                    IF pValue < 15 THEN
                        ReturnQty := 10
                    ELSE
                        IF (pReplenItemRec."FSN Maximum" >= 30) OR (pReplenItemRec."FSN Maximum" >= 10) THEN
                            ReturnQty := 20
                        ELSE
                            ReturnQty := 10;
                (pValue > 20):
                    BEGIN
                        Conversor := ROUND(pValue / 100, 0.1, '=');
                        ReturnQty := Conversor * 100;
                    END;
            END;
            case FSNApproachAdjustmentType of
                FSNApproachAdjustmentType::LowerOrHigher:
                    exit(ReturnQty);
                FSNApproachAdjustmentType::Lower:
                    begin
                        if ReturnQty > pValue then
                            ReturnQty := pValue;
                    end;
                FSNApproachAdjustmentType::Higher:
                    begin
                        if ReturnQty < pValue then
                            ReturnQty := pValue;
                    end;
            end;
        end;
    */

    //EVENTS
    [EventSubscriber(ObjectType::Table, Database::"LSC Replen. Item Store Rec", 'OnBeforeModifyEvent', '', true, true)]
    local procedure "Replen. Item Store Rec_OnBeforeModifyEvent"
    (
        var Rec: Record "LSC Replen. Item Store Rec";
        var xRec: Record "LSC Replen. Item Store Rec";
        RunTrigger: Boolean
    )
    begin
        VerifyMultipleReplenRecConsistency(Rec, xRec, false);
    end;

    [EventSubscriber(ObjectType::Table, Database::"LSC Replen. Item Store Rec", 'OnBeforeInsertEvent', '', true, true)]
    local procedure "Replen. Item Store Rec_OnBeforeInsertEvent"
    (
        var Rec: Record "LSC Replen. Item Store Rec";
        RunTrigger: Boolean
    )
    begin
        FSNInicializeReplenRec(Rec);
    end;


    [EventSubscriber(ObjectType::Table, Database::"Item", 'OnAfterModifyEvent', '', true, true)]
    local procedure "Item_OnAfterModifyEvent"
    (
        var Rec: Record "Item";
        var xRec: Record "Item";
        RunTrigger: Boolean
    )
    begin
        VerifyReplenRecDescriptions(Rec, xRec);
    end;

    [EventSubscriber(ObjectType::Page, Page::"LSC Purchase Replen. Journal", 'OnBeforeActionEvent', 'Create Purchase Orders', true, true)]
    local procedure "Purchase Replenishment Journal_OnBeforeActionEvent_[processing / P&osting] - Create Purchase Orders"(var Rec: Record "LSC Replen. Journal Lines")
    var
        Txt1: Label 'The schedule to run this template is DAILY. You can use the FSN Create Consolidated Orders action or change the schedule.';
        ReplenJrnlBatch: Record "LSC Replen. Journal Batch";
    begin
        ReplenJrnlBatch.Reset();
        ReplenJrnlBatch.SetRange("Replenishment Template Code", Rec."Replenishment Template Code");
        ReplenJrnlBatch.SetRange("Batch No.", Rec."Batch No.");
        if ReplenJrnlBatch.FindFirst() then
            if ReplenJrnlBatch."Run Frequency"::Daily = ReplenJrnlBatch."Run Frequency" then
                Error(Txt1);
    end;


    [EventSubscriber(ObjectType::Page, Page::"LSC Purchase Replen. Journal", 'OnBeforeActionEvent', 'Add Items to Journal', true, true)]
    local procedure "LSC Purchase Replen. Journal_OnBeforeActionEvent_[processing / F&unctions] - Add Items to Journal"(var Rec: Record "LSC Replen. Journal Lines")
    var
        Txt01: Label 'Debe usar el metodo FASANI Añadir productos al Diario';
    begin
        //error(Txt01);
    end;


    [EventSubscriber(ObjectType::Table, Database::"Sales Price", 'OnBeforeInsertEvent', '', true, true)]
    local procedure "Sales Price_OnBeforeInsertEvent"
    (
        var Rec: Record "Sales Price";
        RunTrigger: Boolean
    )
    var
        item1: Record Item;
    begin
        if item1.Get(Rec."Item No.") then
            Rec."FSN Attrib 1 Code" := Item1."LSC Attrib 1 Code";
    end;

    [EventSubscriber(ObjectType::Table, Database::"LSC Replen. Jrnl. Details", 'OnBeforeValidateEvent', 'Base Cubage', true, true)]
    local procedure "Replen. Jrnl. Details_OnBeforeValidateEvent_Base Cubage"
    (
        var Rec: Record "LSC Replen. Jrnl. Details";
        var xRec: Record "LSC Replen. Jrnl. Details";
        CurrFieldNo: Integer
    )
    var
        BackOrderTransfer_l: Record "FSN BackOrder Transfer Line";
        ReplenTemplate_l: Record "LSC Replen. Template";
        QtyBaseeStimate: Decimal;
    begin
        IF Rec."Item No." = 'A008867' then begin
            IF Rec."Location Code" in ['F02', 'F16'] then
                IF Rec."Item No." = 'A008867' then;
        end;
        if (Rec.Quantity <> 0) then
            if Rec."Calculation Type" = Rec."Calculation Type"::"Stock Levels" then begin
                QtyBaseeStimate := Rec."System Suggested Quantity" - Rec."Effective Inventory";
                if Rec.Quantity < QtyBaseeStimate then
                    if Rec.Quantity + Rec.Multiple < QtyBaseeStimate then
                        if ReplenTemplate_l.Get(Rec."Replenishment Template Code") and
                            (ReplenTemplate_l."Replenishment Type" = ReplenTemplate_l."Replenishment Type"::Transfer) then begin
                            BackOrderTransfer_l.Reset();
                            BackOrderTransfer_l."Replenishment Template Code" := 'TRANSFER';//Rec."Replenishment Template Code";
                            BackOrderTransfer_l."Batch No." := 'DEFAULT';//Rec."Batch No.";
                            BackOrderTransfer_l."Line No." := Rec."Line No.";
                            BackOrderTransfer_l."Detail Line No." := Rec."Detail Line No.";
                            BackOrderTransfer_l."Item No." := Rec."Item No.";
                            BackOrderTransfer_l."Variant Code" := Rec."Variant Code";
                            BackOrderTransfer_l.Description := Rec.Description;
                            BackOrderTransfer_l."System Suggested Quantity" := Rec."System Suggested Quantity";
                            BackOrderTransfer_l."Calculation Type" := Rec."Calculation Type";
                            BackOrderTransfer_l.Quantity := Rec.Quantity;
                            BackOrderTransfer_l."Location Code" := Rec."Location Code";
                            BackOrderTransfer_l."Replenishment Location Code" := Rec."Replenishment Location Code";
                            BackOrderTransfer_l."Effective Inventory" := Rec."Effective Inventory";
                            BackOrderTransfer_l."Average Daily Sales" := Rec."Average Daily Sales";
                            BackOrderTransfer_l."Required Coverage Days" := Rec."Required Coverage Days";
                            BackOrderTransfer_l.Decision := Rec.Decision;
                            BackOrderTransfer_l."Vendor No." := Rec."Vendor No.";
                            BackOrderTransfer_l."Vendor Name" := Rec."Vendor Name";
                            BackOrderTransfer_l."Forward Sales Forecast Factor" := Rec."Forward Sales Forecast Factor";
                            BackOrderTransfer_l."Quantity to Cross Dock" := Rec."Quantity to Cross Dock";
                            BackOrderTransfer_l."Replenished as Item No." := Rec."Replenished as Item No.";
                            BackOrderTransfer_l."Replenished as Location Code" := Rec."Replenished as Location Code";
                            BackOrderTransfer_l."Warehouse Effective Inventory" := Rec."Warehouse Effective Inventory";
                            BackOrderTransfer_l."Location Name" := Rec."Location Name";
                            BackOrderTransfer_l.Multiple := Rec.Multiple;
                            BackOrderTransfer_l."Quantity Origin" := Rec."Quantity Origin";
                            BackOrderTransfer_l."Planned Stock Demand" := Rec."Planned Stock Demand";
                            BackOrderTransfer_l.Date := Today;
                            if BackOrderTransfer_l.Insert() then;
                        end;
            end;
    end;

    local procedure CalculateLostSales(var ReplenJrnlDetails: Record "LSC Replen. Jrnl. Details")
    var
        parameter: Record "fsn Parameter";
        ReplenItemQty: Record "LSC Replen. Item Quantity";
        ItemUom: Record "Item Unit of Measure";
        item: Record Item;
        qtyInPurchUOM: Decimal;
    begin
        /*
        //?parametro para poder activar o desactivar la funcionalidad
        if not parameter.Get('Administracion', 'VentasPerdidas') then
            exit;

        //? Ventas perdidas
        if not ReplenItemQty.Get(ReplenJrnlDetails."Item No.", ReplenJrnlDetails."Variant Code", ReplenJrnlDetails."Location Code") then
            exit;
        if not parameter.Activo then
            exit;

        if ReplenItemQty.VP30D <= 0 then
            exit;

        if (ReplenJrnlDetails.Quantity + ReplenJrnlDetails."Effective Inventory") > ReplenItemQty.VP30D then
            exit;

        item.Get(ReplenJrnlDetails."Item No.");
        itemUom.Get(ReplenJrnlDetails."Item No.", item."Purch. Unit of Measure");

        qtyInPurchUOM := ReplenItemQty.VP30D / itemUom."Qty. per Unit of Measure";

        if qtyInPurchUOM > 10 then begin
            qtyInPurchUOM := 10 * itemUom."Qty. per Unit of Measure";
            ReplenItemQty.VP30D := qtyInPurchUOM;
            ReplenItemQty.Modify();
        end;

        //ReplenJrnlDetails.Quantity += Round(ReplenItemQty.VP30D, 1, '<');
        ReplenJrnlDetails.Quantity := Round(ReplenItemQty.VP30D, 1, '<') - ReplenJrnlDetails."Effective Inventory";
        ReplenJrnlDetails.Decision := ReplenJrnlDetails.Decision::"Based on Calculated Need";
        */
    end;


    [EventSubscriber(ObjectType::Page, Page::"LSC Transfer Replen. Journal", 'OnBeforeActionEvent', 'Create &Transfer Orders', true, true)]
    local procedure "Transfer Replenishment Journal_OnBeforeActionEvent_[processing / P&osting] - Create &Transfer Orders"(var Rec: Record "LSC Replen. Journal Lines")
    var
        Txt1: Label 'Must be use FSN Create Consolidate Transfer';
    begin
        //Error(Txt1); //Bloqueo de action Crear pedido transferencia
    end;


    [EventSubscriber(ObjectType::Page, Page::"LSC Purchase Replen. Journal", 'OnAfterActionEvent', 'Add Items to Journal', true, true)]
    local procedure "LSC Purchase Replen. Journal_OnAfterActionEvent_[processing / F&unctions] - Add Items to Journal"(var Rec: Record "LSC Replen. Journal Lines")
    var
        ReplenTemplate_g: Record "LSC Replen. Template";
    begin
        if ReplenTemplate_g.Get(Rec."Replenishment Template Code") then begin
            ReplenTemplate_g."FSN Consolidate No." := '';
            ReplenTemplate_g.Modify();
        end;
    end;

    procedure ValidateInventoryDec()
    var
        ReplentQuantity: Record "LSC Replen. Item Quantity";
    begin
        ReplentQuantity.Reset();
        if ReplentQuantity.Find('-') then
            repeat
                ReplentQuantity.Inventory := Round(ReplentQuantity.Inventory, 1);
                ReplentQuantity.Modify(true);
            until ReplentQuantity.Next() = 0;
    end;

    procedure ValidateInventoryDecItem(ItemCode: Code[20])
    var
        ReplentQuantity: Record "LSC Replen. Item Quantity";
    begin
        ReplentQuantity.Reset();
        ReplentQuantity.setrange(ReplentQuantity."Item No.", ItemCode);
        if ReplentQuantity.find('-') then begin
            repeat
                ReplentQuantity.Inventory := Round(ReplentQuantity.Inventory, 1);
                ReplentQuantity.Modify(true);
            until ReplentQuantity.Next() = 0;
        end;
    end;

    [EventSubscriber(ObjectType::Table, Database::"LSC Replen. Jrnl. Details", 'OnBeforeValidateEvent', 'Item No.', true, true)]
    local procedure "LSC Replen. Jrnl. Details_OnBeforeValidateEvent_Item No."
    (
        var Rec: Record "LSC Replen. Jrnl. Details";
        var xRec: Record "LSC Replen. Jrnl. Details";
        CurrFieldNo: Integer
    )
    begin
        IF Rec."Item No." = 'A008867' then begin
            IF Rec."Location Code" in ['F02', 'F16'] then
                IF Rec."Item No." = 'A008867' then;
        end;
        ValidateInventoryDecItem(Rec."Item No.");
    end;



    [EventSubscriber(ObjectType::Table, Database::"LSC Replen. Jrnl. Details", 'OnBeforeModifyEvent', '', true, true)]
    local procedure "LSC Replen. Jrnl. Details_OnBeforeModifyEvent"
    (
        var Rec: Record "LSC Replen. Jrnl. Details";
        var xRec: Record "LSC Replen. Jrnl. Details";
        RunTrigger: Boolean
    )
    var
        pReplenItemStoreRec: record "LSC Replen. Item Store Rec";
        ReplenItemQty: Record "LSC Replen. Item Quantity";
        ReplenSetup1: Record "LSC Replen. Setup";
        pItem: Record Item;
        pUOM: Record "Item Unit of Measure";
        FSNReplenAdd: Record "FSN Replen. Jrnl. Add";
        FSNReplenAdd2: Record "FSN Replen. Jrnl. Add";
        pConvertion: Decimal;
        pQty: Decimal;
        QuantityAdd: Decimal;
        AddExists: Boolean;
        pExit: Boolean;
        pQtyComp, pQtyPV30 : Decimal;
    begin
        //if Rec.IsTemporary then
        //    exit;

        if Rec."FSN Calculated" then
            exit;

        Clear(pExit);
        Clear(AddExists);
        Clear(QuantityAdd);

        //CalculateLostSales(Rec);


        pReplenItemStoreRec.Reset();
        pReplenItemStoreRec.SetRange("Location Code", Rec."Location Code");
        pReplenItemStoreRec.SetRange("Item No.", Rec."Item No.");
        pReplenItemStoreRec.SetRange("Variant Code", Rec."Variant Code");
        pReplenItemStoreRec.SetFilter("Active From Date", '<=%1|%2', Today, 0D);
        if pReplenItemStoreRec.Find('-') then begin

            if (Rec."Calculation Type" = Rec."Calculation Type"::"Stock Levels") then
                if (Rec."Effective Inventory") > pReplenItemStoreRec."Reorder Point" then
                    pExit := true;

            FSNReplenAdd.Reset();
            FSNReplenAdd.SetRange("Item No.", Rec."Item No.");
            FSNReplenAdd.SetRange("Replen. Template Code", Rec."Replenishment Template Code");
            FSNReplenAdd.SetRange("Location Code", Rec."Location Code");
            AddExists := FSNReplenAdd.Find('-');//If exists

            if pExit and not AddExists then begin
                Rec."FSN Calculated" := true;
                exit;
            end;


            pConvertion := 1;

            if not pExit or AddExists then
                if pItem.get(pReplenItemStoreRec."Item No.") then
                    if pItem."Base Unit of Measure" <> pItem."Purch. Unit of Measure" then
                        if pUOM.Get(pItem."No.", pItem."Purch. Unit of Measure") then begin
                            pConvertion := Round(pUOM."Qty. per Unit of Measure", 1, '=');
                        end;
            if (Rec."Calculation Type" = Rec."Calculation Type"::"Stock Levels") then begin
                if not pExit then begin
                    pQty := Rec.Quantity / pConvertion;
                    if (Rec."Effective Inventory" + Rec.Quantity) < pReplenItemStoreRec."Maximum Inventory" then
                        Rec.Quantity += pReplenItemStoreRec."Transfer Multiple";

                    if (Rec.Quantity = 0) and (pReplenItemStoreRec."Maximum Inventory" = pReplenItemStoreRec."Transfer Multiple") and
                    (pReplenItemStoreRec."Transfer Multiple" > 0) then begin
                        if (Rec."Effective Inventory" < pReplenItemStoreRec."Reorder Point") then
                            Rec.Quantity := pReplenItemStoreRec."Transfer Multiple";
                    end;
                end;
            end;


            if AddExists then begin
                Rec.Quantity += (FSNReplenAdd.Quantity * pConvertion);

                FSNReplenAdd2 := FSNReplenAdd;
                FSNReplenAdd2.Delete();
            end;
            if (Rec."Calculation Type" = Rec."Calculation Type"::"Stock Levels") then
                if not pExit then begin
                    if pQty = 1 then begin
                        if ((pReplenItemStoreRec."FSN Minimum" = 1) and (pReplenItemStoreRec."FSN Maximum" = 2)) OR
                         ((pReplenItemStoreRec."FSN Minimum" = 2) and (pReplenItemStoreRec."FSN Maximum" = 3)) OR
                         ((pReplenItemStoreRec."FSN Minimum" = 3) and (pReplenItemStoreRec."FSN Maximum" = 4)) then
                            Rec.Quantity := 2 * pConvertion;
                    end;

                    if (pQty = 2) and (pReplenItemStoreRec."Transfer Multiple" > pConvertion) then begin
                        if ((pReplenItemStoreRec."FSN Minimum" = 3) and (pReplenItemStoreRec."FSN Maximum" = 5)) OR
                            ((pReplenItemStoreRec."FSN Minimum" = 4) and (pReplenItemStoreRec."FSN Maximum" = 6)) OR
                         ((pReplenItemStoreRec."FSN Minimum" = 5) and (pReplenItemStoreRec."FSN Maximum" = 7)) OR
                         ((pReplenItemStoreRec."FSN Minimum" = 6) and (pReplenItemStoreRec."FSN Maximum" = 8))
                         then
                            Rec.Quantity := 3 * pConvertion;
                    end;

                    if (pReplenItemStoreRec."FSN Approach Multiple" > 0) and (Rec.Quantity > 0) then
                        if (Rec.Quantity mod pReplenItemStoreRec."FSN Approach Multiple") <> 0 then
                            NewCalcApproach(Rec, pReplenItemStoreRec."FSN Approach Multiple", pConvertion);
                end;

            pQtyComp := 0;
            pQtyPV30 := 0;
            ReplenItemQty.Reset();
            if ReplenItemQty.get(pReplenItemStoreRec."Item No.", pReplenItemStoreRec."Variant Code", pReplenItemStoreRec."Location Code") then begin
                if ReplenItemQty.VP30D <> 0 then begin
                    pQtyComp := Round((ReplenItemQty.VP30D / pConvertion), 1, '=');
                    if pQtyComp > 10 then
                        pQtyComp := 10;
                    pQtyComp := pQtyComp * pConvertion;
                    pQtyPV30 := Rec.Quantity;
                    if Rec.Quantity < pQtyComp then
                        pQtyPV30 := pQtyComp
                    else
                        if pQtyComp > Rec."Effective Inventory" then begin
                            pQtyPV30 := Round(Rec.Quantity + pQtyComp);
                        end;
                    Rec.Quantity := pQtyPV30;
                end;
            end;

        end;
        Rec."FSN Calculated" := true;

    end;

    local procedure NewCalcApproach(var pRec: Record "LSC Replen. Jrnl. Details"; pQtyApproach: Decimal; pConvert: decimal)
    var
        RepSetup: Record "LSC Replen. Setup";
        QtyPurch: decimal;
        nMultiply: Integer;
        moreHalf: Decimal;
        ApproachSep: Decimal;
        limLower, limHigher : Decimal;
        ium: Record "Item Unit of Measure";
    begin

        nMultiply := 0;
        limLower := 0;
        LimHigher := 0;
        QtyPurch := Round((pRec.Quantity / pConvert), 1, '<');
        RepSetup.get;
        ApproachSep := RepSetup."FSN Approach Multiple %" / 100;



        limLower := pQtyApproach - Round((pQtyApproach * ApproachSep), 1, '<');
        LimHigher := pQtyApproach + Round((pQtyApproach * ApproachSep), 1, '<');

        if (QtyPurch < limLower) then
            nMultiply := 0;

        if ((QtyPurch >= limLower) and (QtyPurch <= LimHigher)) then
            nMultiply := 1;

        if ((QtyPurch >= (limLower * 2)) and (QtyPurch <= (LimHigher * 2))) then
            nMultiply := 2;

        LimHigher := pQtyApproach * 3;
        if (QtyPurch > LimHigher) then begin
            nMultiply := Round((QtyPurch / pQtyApproach), 1, '<');
            moreHalf := nMultiply * pQtyApproach + (pQtyApproach * 0.5);
        end;

        case nMultiply of
            0:
                pRec.Quantity := pRec.Quantity;
            1:
                pRec.Quantity := pQtyApproach * pConvert;
            2:
                pRec.Quantity := pQtyApproach * nMultiply * pConvert;
            else begin
                begin
                    if RepSetup."FSN Approach Adjustment Type" = RepSetup."FSN Approach Adjustment Type"::LowerOrHigher then begin
                        if (QtyPurch < moreHalf) then
                            pRec.Quantity := nMultiply * pQtyApproach * pConvert;
                        if (QtyPurch >= moreHalf) then
                            pRec.Quantity := (nMultiply + 1) * pQtyApproach * pConvert;
                    end;
                    if RepSetup."FSN Approach Adjustment Type" = RepSetup."FSN Approach Adjustment Type"::Lower then
                        if (QtyPurch > (pQtyApproach * nMultiply)) then
                            pRec.Quantity := nMultiply * pQtyApproach * pConvert;

                    if RepSetup."FSN Approach Adjustment Type" = RepSetup."FSN Approach Adjustment Type"::Higher then
                        if (QtyPurch >= (pQtyApproach * nMultiply)) then
                            pRec.Quantity := (nMultiply + 1) * pQtyApproach * pConvert;

                end;
            end;
        end;
    end;

    //Se crea nuevo proceso
    /*
    local procedure NewCalcApproach(var pRec: Record "LSC Replen. Jrnl. Details"; pQtyApproach: Decimal; pConvert: decimal)
    var
        ReplenSetup1: Record "LSC Replen. Setup";
        NewQuantity: Decimal;
        Precision: Decimal;
        aproxSetup: Decimal;
    begin
        ReplenSetup1.get;
        aproxSetup := ReplenSetup1."FSN Approach Multiple %" / 100;
        pRec.Quantity := pConvert;
        NewQuantity := pRec.Quantity / pConvert;
        Precision := pRec.Quantity / pQtyApproach;

        if aproxSetup > 1 then
            exit;

        if aproxSetup <= 0 then
            exit;

        if Precision <= (1 + aproxSetup) then begin
            Precision := 1 - Precision;
            pRec.Quantity := NewAproxQuantity(pRec.Quantity, Precision, aproxSetup, pQtyApproach, pConvert, 1);
        end else
            if (Precision >= 2) and (Precision < 3) then begin
                Precision := Precision / 2;
                Precision := 1 - Precision;
                pRec.Quantity := NewAproxQuantity(pRec.Quantity, Precision, aproxSetup, pQtyApproach, pConvert, 2);
            end else
                if (Precision >= 3) and (Precision < 4) then begin
                    Precision := Precision / 3;
                    Precision := 1 - Precision;
                    pRec.Quantity := NewAproxQuantity(pRec.Quantity, Precision, aproxSetup, pQtyApproach, pConvert, 3);
                end else
                    if (Precision >= 4) then begin
                        pRec.Quantity := pQtyApproach * pConvert;
                    end;
    end;
    */

    local procedure NewAproxQuantity(pQty: Decimal; pPrecision: Decimal; pAproxSetup: Decimal; qApproach: decimal; pConvert: decimal; pMultiple: Decimal): Decimal
    begin
        if (pPrecision < 1) then
            if pPrecision <= pAproxSetup then
                pQty := (qApproach * pMultiple * pConvert);

        if (pPrecision > 1) then
            if pPrecision <= (1 + pAproxSetup) then
                pQty := (qApproach * pMultiple * pConvert);
        exit(pQty);
    end;

    [EventSubscriber(ObjectType::Table, Database::"LSC Replen. Jrnl. Details", 'OnAfterInsertEvent', '', true, true)]
    local procedure "LSC Replen. Jrnl. Details_OnAfterInsertEvent"
    (
        var Rec: Record "LSC Replen. Jrnl. Details";
        RunTrigger: Boolean
    )
    begin

        if Rec.Modify() then;
    end;
    /*
        [EventSubscriber(ObjectType::Table, Database::"LSC Replen. Journal Lines", 'OnBeforeModifyEvent', '', true, true)]
        local procedure "LSC Replen. Journal Lines_OnBeforeModifyEvent"
        (
            var Rec: Record "LSC Replen. Journal Lines";
            var xRec: Record "LSC Replen. Journal Lines";
            RunTrigger: Boolean
        )
        var
            FSNReplenAdd: Record "FSN Replen. Jrnl. Add";
            FSNReplenAdd2: Record "FSN Replen. Jrnl. Add";
            FSNRendTempl: Record "LSC Replen. Template";
            ValItemDetail: Record "LSC Replen. Jrnl. Details";
            QuantityVal: Decimal;

        begin
            IF FSNRendTempl.GET(Rec."Replenishment Template Code") and (Rec."Warehouse Location Code" = 'CD') THEN BEGIN
                ValItemDetail.Reset();
                ValItemDetail.SetRange(ValItemDetail."Replenishment Template Code", FSNRendTempl.Code);
                ValItemDetail.SetRange(ValItemDetail."Location Code", FSNRendTempl."Location Code");
                ValItemDetail.SetRange(ValItemDetail."Item No.", Rec."Item No.");
                if ValItemDetail.FindFirst() then begin
                    ProcessItemDetail(ValItemDetail, QuantityVal, Rec);
                    Rec.Quantity += QuantityVal;
                end;
            END;
        end;
    */
    /*
    procedure ProcessItemDetail(RecItemDetail: Record "LSC Replen. Jrnl. Details"; var ValQuantity: Decimal; JournalLine: Record "LSC Replen. Journal Lines")
    var
        FSNReplenAdd: Record "FSN Replen. Jrnl. Add";
        FSNReplenAdd2: Record "FSN Replen. Jrnl. Add";
        ReplenItemStoreRec1: Record "LSC Replen. Item Store Rec";
        pReplenItemStoreRec: Record "LSC Replen. Item Store Rec";
    begin
        ValQuantity := 0;

        ReplenItemStoreRec1.Reset();
        ReplenItemStoreRec1.SetRange("Location Code", RecItemDetail."Location Code");
        ReplenItemStoreRec1.SetRange("Item No.", RecItemDetail."Item No.");
        ReplenItemStoreRec1.SetFilter("Active From Date", '<=%1|%2', Today, 0D);
        IF ReplenItemStoreRec1.FindFirst() THEN BEGIN
            if ReplenItemStoreRec1."FSN Approach Multiple" > 1 then
                ProcessApproachPurchMult(RecItemDetail, ReplenItemStoreRec1, JournalLine."Unit of Measure Code");
        END;
    end;
*/

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"FSN Utility", 'OnInvokeGlobalChannelEvent', '', true, true)]
    local procedure "FSN Utility_OnInvokeGlobalChannelEvent"
    (
        var XMLRequest: Text;
        var XMLResponse: Text;
        var RequestID: Text[50];
        var POSMenuLine: Record "LSC POS Menu Line";
        var Processed: Boolean;
        var MsgResult: Text
    )
    var
        ReplenItemStore: Record "LSC Replen. Item Store Rec";
        ReplenT: Record "LSC Replen. Template";
    begin

        if RequestID = 'FSNREPLENSTOREITEM' then begin
            ReplenItemStore.RESET;
            ReplenItemStore.SETRANGE(ReplenItemStore."Item No.", POSMenuLine."Menu ID");
            ReplenItemStore.SETRANGE(ReplenItemStore."Location Code", POSMenuLine."POS Help ID");
            IF ReplenItemStore.FINDFIRST THEN BEGIN
                XMLRequest := Format(ReplenItemStore."FSN Maximum");
                XMLResponse := Format(ReplenItemStore."FSN Minimum");
            END;
        end;
        if RequestID = 'UPDASSOCRP' then begin
            ReplenT.Reset();
            ReplenT.SetRange("Replenishment Type", ReplenT."Replenishment Type"::Purchase);
            ReplenT.SetRange("Vendor No. Filter", POSMenuLine."Menu ID");
            if ReplenT.FindFirst() then
                repeat begin
                    ReplenT."Associated Credit Memo" := POSMenuLine.Disabled;
                    ReplenT.Modify();
                end until ReplenT.Next() = 0;

        end;
    end;



    [EventSubscriber(ObjectType::Report, Report::"LSC Add Items to Replen. Jrnl", 'OnAfterPreReport', '', true, true)]
    local procedure "LSC Add Items to Replen. Jrnl_OnAfterPreReport"
    (
        var CalculateInventory: Boolean;
        var Skip0Lines: Boolean
    )
    var
        Error000: Label 'Opcion "Calcular inventario" no valida para Añadir Productos al Diario Reaprov.';
    begin
        if CalculateInventory then begin
            CalculateInventory := false;
            error(Error000);
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC Replen. Calculation", 'OnInsertWorksheetLineOnBeforeSetReplenJournalLinesPar', '', true, true)]
    local procedure "LSC Replen. Calculation_OnInsertWorksheetLineOnBeforeSetReplenJournalLinesPar"(var ReplenJournalLines: Record "LSC Replen. Journal Lines")
    var
        InventoryLevels: Record "FSN WMS Levels";
        pReplenItemQuantityFilter: Record "LSC Replen. Item Quantity";
        gReplenTemplate: Record "LSC Replen. Template";
        lReplenItemQuantityWarehouse: Record "LSC Replen. Item Quantity";
        lItem: Record "Item";
        IUOM: Record "Item Unit of Measure";
    begin
        gReplenTemplate.Get(ReplenJournalLines."Replenishment Template Code");

        IF (ReplenJournalLines."Warehouse Location Code" = 'CD') AND
          (gReplenTemplate."Replenishment Type" = gReplenTemplate."Replenishment Type"::Transfer) THEN BEGIN
            ReplenJournalLines."Warehouse Effective Inventory" := 0;

            IF InventoryLevels.GET(ReplenJournalLines."Item No.") THEN begin
                ReplenJournalLines."Warehouse Effective Inventory" := InventoryLevels.InventoryCD;
                if lItem.Get(ReplenJournalLines."Item No.") and (lItem."Base Unit of Measure" <> lItem."Purch. Unit of Measure") then begin
                    if not IUOM.Get(lItem."No.", lItem."Purch. Unit of Measure") then
                        IUOM."Qty. per Unit of Measure" := 1;
                    ReplenJournalLines."Warehouse Effective Inventory" := (InventoryLevels.InventoryCD * IUOM."Qty. per Unit of Measure");
                end;
            end;

            /*IF InventoryLevels.GET(ReplenJournalLines."Item No.") THEN
                ReplenJournalLines."Warehouse Effective Inventory" := InventoryLevels.InventoryCD;*/
        END ELSE BEGIN

            /*IF (ReplenJournalLines."Warehouse Location Code" = 'CD') AND
              (gReplenTemplate."Replenishment Type" = gReplenTemplate."Replenishment Type"::Purchase) THEN BEGIN
                ReplenJournalLines."Warehouse Effective Inventory" := 0;

                IF InventoryLevels.GET(ReplenJournalLines."Item No.") THEN begin
                    //ReplenJournalLines."Warehouse Effective Inventory" := InventoryLevels.InventoryCD;

                    lReplenItemQuantityWarehouse.RESET;
                    lReplenItemQuantityWarehouse.SETRANGE("Item No.", ReplenJournalLines."Item No.");
                    lReplenItemQuantityWarehouse.SETRANGE("Location Code", ReplenJournalLines."Warehouse Location Code");
                    IF lReplenItemQuantityWarehouse.FINDSET THEN
                        REPEAT
                            ReplenJournalLines."Warehouse Effective Inventory" := ReplenJournalLines."Warehouse Effective Inventory" +
                              lReplenItemQuantityWarehouse.Inventory +
                              lReplenItemQuantityWarehouse."Quantity on Purchase Order" -
                              lReplenItemQuantityWarehouse."Quantity on Sales Order" +
                              lReplenItemQuantityWarehouse."Quantity in Transfer In" -
                              lReplenItemQuantityWarehouse."Quantity in Transfer Out" -
                              lReplenItemQuantityWarehouse."Unavailable Qty";
                        UNTIL lReplenItemQuantityWarehouse.NEXT = 0;
                end;*/
        END;

        //******************************************************************************************************
        /*IF lItem.GET(ReplenJournalLines."Item No.") THEN
            IF IUOM.GET(lItem."No.", lItem."Purch. Unit of Measure") THEN
                ReplenJournalLines.VALIDATE("Unit of Measure Code", IUOM.Code);*/
        //******************************************************************************************************

    end;


    [EventSubscriber(ObjectType::Page, Page::"LSC Purchase Replen. Journal", 'OnAfterGetRecordEvent', '', true, true)]
    local procedure "LSC Purchase Replen. Journal_OnAfterGetRecordEvent"(var Rec: Record "LSC Replen. Journal Lines")

    var
        lReplenItemQuantityWarehouse: Record "LSC Replen. Item Quantity";
        gBOUtils: codeunit "LSC BO Utils";
        lItemStatusLink: Record "LSC Item Status Link";
        gReplenTemplate: Record "LSC Replen. Template";
        replenJournalLineDetail: Record "LSC Replen. Jrnl. Details";
    begin
        lReplenItemQuantityWarehouse.RESET;
        lReplenItemQuantityWarehouse.SETRANGE("Item No.", Rec."Item No.");
        lReplenItemQuantityWarehouse.SETRANGE("Location Code", Rec."Warehouse Location Code");
        IF lReplenItemQuantityWarehouse.FINDSET THEN BEGIN
            case gReplenTemplate."Replenishment Type" of
                gReplenTemplate."Replenishment Type"::Purchase:
                    begin
                        if gBOUtils.IsBlockPurchasing(lReplenItemQuantityWarehouse."Item No.", '', lReplenItemQuantityWarehouse."Variant Code", '', lReplenItemQuantityWarehouse."Location Code", WorkDate, lItemStatusLink) then begin
                            replenJournalLineDetail.Reset();
                            replenJournalLineDetail.SetRange("Item No.", Rec."Item No.");
                            replenJournalLineDetail.SetRange("Line No.", Rec."Line No.");
                            replenJournalLineDetail.SetRange("Batch No.", Rec."Batch No.");
                            replenJournalLineDetail.SetRange("Replenishment Template Code", Rec."Replenishment Template Code");
                            if replenJournalLineDetail.FindSet() then begin
                                replenJournalLineDetail.Delete();
                            end;
                            Rec.Delete();
                            Commit();
                        end;
                    end;

                gReplenTemplate."Replenishment Type"::Transfer:
                    begin
                        if gBOUtils.IsBlockTransfering(lReplenItemQuantityWarehouse."Item No.", '', lReplenItemQuantityWarehouse."Variant Code", '', lReplenItemQuantityWarehouse."Location Code", WorkDate, lItemStatusLink) then begin
                            replenJournalLineDetail.Reset();
                            replenJournalLineDetail.SetRange("Item No.", Rec."Item No.");
                            replenJournalLineDetail.SetRange("Line No.", Rec."Line No.");
                            replenJournalLineDetail.SetRange("Batch No.", Rec."Batch No.");
                            replenJournalLineDetail.SetRange("Replenishment Template Code", Rec."Replenishment Template Code");
                            if replenJournalLineDetail.FindSet() then begin
                                replenJournalLineDetail.Delete();
                            end;
                            Rec.Delete();
                            Commit();
                        end;
                    end;

            end;
        END;
    end;
    /*
        //Agrega consolidado a las  transferencas automaticas
        [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC Replen. Create Transf. Ord", 'OnBeforeAutoReleaseReplenTransfer', '', true, true)]
        local procedure "LSC Replen. Create Transf. Ord_OnBeforeAutoReleaseReplenTransfer"
        (
            ReplenishmentTemplate: Record "LSC Replen. Template";
            FirstTransfNo: Code[20];
            LastTransfNo: Code[20];
            var IsHandled: Boolean
        )
        var
            TransfHeader: Record "Transfer Header";
            CT: Report "LSC Replen. Automatic Run";
            callc: Codeunit "LSC Replen. Calculation";
            jr: Report "LSC Add Items to Replen. Jrnl";
        begin

            TransfHeader.Reset;
            TransfHeader.SetRange("No.", FirstTransfNo, LastTransfNo);
            if TransfHeader.FindSet then
                repeat
                    if TransfHeader."FSN Consolidate No." = '' then begin
                        ReplenSetup.Get;
                        TransfHeader."FSN Consolidate No." := NoSerie.GetNextNo(ReplenSetup."FSN Transfer Consolidate No.", TODAY, TRUE);
                        TransfHeader.Modify();
                    END;
                until TransfHeader.Next = 0;

        end;*/
    /*
        //Agrega consolidado a los pedidos compras automaticos
        [EventSubscriber(ObjectType::Table, Database::"Purchase Header", 'OnBeforeInsertEvent', '', true, true)]
        local procedure "Purchase Header_OnBeforeInsertEvent"
        (
            var Rec: Record "Purchase Header";
            RunTrigger: Boolean
        )
        begin
            if not Rec.IsTemporary then begin
                ReplenSetup.Get;
                if Rec."LSC Created By Source Code" = ReplenSetup."Replen. Source Code" then begin
                    Rec."FSN Consolidate No." := NoSerie.GetNextNo(ReplenSetup."FSN Consolidate Serie No.", TODAY, TRUE);
                end;
            end;
        end;
    */
    /*
        [EventSubscriber(ObjectType::Table, Database::"LSC Replen. Jrnl. Details", 'OnBeforeInsertEvent', '', true, true)]
        local procedure "LSC Replen. Jrnl. Details_OnBeforeInsertEvent"
        (
            var Rec: Record "LSC Replen. Jrnl. Details";
            RunTrigger: Boolean
        )
        begin
            if Rec."Replenishment Template Code" = Rec."Replenishment Template Code" then begin
                if Rec."Replenishment Template Code" = Rec."Replenishment Template Code" then;
                //Rec.Decision := Rec.Decision::" ";
            end;
        end;
    */
    /*
    //NZEPEDA270624 Se usa subscripcion para validar el ingreso a la pagina 
    //JHERNANDEZ2800624 Se comenta ya que genera el error por cada accion, se hara el bloqueo por roles. 
    [EventSubscriber(ObjectType::Page, Page::"LSC Replen. Template List", 'OnOpenPageEvent', '', true, true)]
    local procedure "LSC Replen. Template List_OnOpenPageEvent"(var Rec: Record "LSC Replen. Template")
    var
        errortext01: label 'La pagina correcta es FSN Lista Libro Reaprov.';
    begin
        Error(errortext01);
    end;
    */
    procedure SetAllTransferConsolidateNo()
    var
        TransferOrders1: Record "Transfer Header";
        TransferOrders2: Record "Transfer Header";
        TransferOrdersTemp: Record "Transfer Header" temporary;
        Location: Record Location;
        ReplenSetup: Record "LSC Replen. Setup";
        NoSeriesMgt: Codeunit NoSeriesManagement;
        transfer_: Record "Transfer Line";
        NextSerieCode: Code[20];
        NextOrderNo: Code[20];
        LastOrderNo: Code[20];
        NewNumber: Boolean;
    begin

        ReplenSetup.Get();
        if ReplenSetup."FSN Transfer Consolidate No." = '' then
            exit;
        Clear(TransferOrdersTemp);
        Location.Reset();
        Location.SetRange("LSC Location is a Warehouse", true);
        if Location.findset() then
            repeat
                Clear(NextSerieCode);
                TransferOrders1.Reset();
                TransferOrders1.SetRange("Shipment Date", Today);
                TransferOrders1.SetRange("Transfer-from Code", Location.Code);
                if TransferOrders1.Find('-') then
                    repeat
                        if (TransferOrders1."FSN Consolidate No." = '') and (TransferOrders1."LSC Created By Source Code" <> '') then begin
                            NewNumber := NextSerieCode = '';
                            if not NewNumber then
                                NewNumber := LastOrderNo = '';

                            //Validar si el numero de pedido no es correlativo debe crear otro consolidado
                            if not NewNumber and (LastOrderNo <> '') then begin
                                NextOrderNo := IncStr(LastOrderNo);
                                NewNumber := NextOrderNo <> TransferOrders1."No.";
                            end;

                            //Validar sala se repite una sola vez por consolidado
                            if not NewNumber and (LastOrderNo <> '') then begin
                                TransferOrdersTemp.Reset();
                                TransferOrdersTemp.SetRange("FSN Consolidate No.", NextSerieCode);
                                TransferOrdersTemp.SetRange("Transfer-to Code", TransferOrders1."Transfer-to Code");
                                if TransferOrdersTemp.Find('-') then
                                    repeat
                                        NewNumber := true;
                                    until TransferOrdersTemp.Next() = 0;
                            end;

                            if NewNumber then begin
                                Clear(NextSerieCode);
                                Clear(NoSeriesMgt);
                                //NoSeriesMgt.SetParametersBeforeRun(ReplenSetup."FSN Consolidate Serie No.", today);
                                //if NoSeriesMgt.Run() then;
                                //NextSerieCode := NoSeriesMgt.GetNextNoAfterRun();
                                NextSerieCode := NoSeriesMgt.GetNextNo(ReplenSetup."FSN Consolidate Serie No.", Today, TRUE);
                            end;

                            if NextSerieCode <> '' then
                                if TransferOrders2.Get(TransferOrders1."No.") then begin
                                    TransferOrders2."FSN Consolidate No." := NextSerieCode;
                                    TransferOrders2.Modify();
                                    TransferOrdersTemp := TransferOrders2;
                                    TransferOrdersTemp.Insert();
                                end;

                            LastOrderNo := TransferOrders1."No.";
                        end;
                    until TransferOrders1.Next() = 0;
            until Location.next() = 0;
    end;

    procedure SetAllPurchConsolidateNo()
    var
        GetPurchPerVendor: Query "FSN Get Purchase per Vendor";
        PurchaseOrders: Record "Purchase Header";
        PurchaseOrders2: Record "Purchase Header";
        PurchaseOrdersTemps: Record "Purchase Header" temporary;
        ReplenSetup: Record "LSC Replen. Setup";
        NoSeriesMgt: Codeunit NoSeriesManagement;
        NextSerieCode: Code[20];
        NextOrderNo: Code[20];
        LastOrderNo: Code[20];
        NewNumber: Boolean;
    begin

        ReplenSetup.Get();
        if ReplenSetup."FSN Consolidate Serie No." = '' then
            exit;

        Clear(GetPurchPerVendor);
        PurchaseOrdersTemps.DeleteAll();
        //GetPurchPerVendor.SetRange(GetPurchPerVendor.Order_Date, WorkDate());
        GetPurchPerVendor.SetRange(GetPurchPerVendor.Order_Date, Today);//20240625D
        GetPurchPerVendor.Open();
        while GetPurchPerVendor.Read() do begin
            if GetPurchPerVendor.FSN_Consolidate_No_ = '' then begin
                Clear(NextSerieCode);
                PurchaseOrders.Reset();
                PurchaseOrders.SetRange("Document Type", PurchaseOrders."Document Type"::Order);
                PurchaseOrders.SetRange("Order Date", GetPurchPerVendor.Order_Date);
                if PurchaseOrders.Find('-') then
                    repeat
                        if (PurchaseOrders."FSN Consolidate No." = '') and (PurchaseOrders."LSC Created By Source Code" = 'REPLEN') then begin

                            NewNumber := NextSerieCode = '';
                            if not NewNumber then
                                NewNumber := LastOrderNo = '';

                            //Validar si el numero de pedido no es correlativo debe crear otro consolidado
                            if not NewNumber and (LastOrderNo <> '') then begin
                                NextOrderNo := IncStr(LastOrderNo);
                                NewNumber := NextOrderNo <> PurchaseOrders."No.";
                            end;

                            //Validar sala se repite una sola vez por consolidado
                            if not NewNumber and (LastOrderNo <> '') then begin
                                PurchaseOrdersTemps.Reset();
                                PurchaseOrdersTemps.SetFilter("FSN Consolidate No.", '%1', NextSerieCode);
                                PurchaseOrdersTemps.SetRange("Location Code", PurchaseOrders."Location Code");
                                if PurchaseOrdersTemps.Find('-') then
                                    repeat
                                        NewNumber := true;
                                    until PurchaseOrdersTemps.Next() = 0;
                            end;

                            //Validar si cambia proveedor debe crear otro consolidado
                            if not NewNumber and (LastOrderNo <> '') then begin
                                PurchaseOrdersTemps.Reset();
                                PurchaseOrdersTemps.SetRange("No.", LastOrderNo);
                                if PurchaseOrdersTemps.FindFirst() then
                                    repeat begin
                                        if PurchaseOrdersTemps."Buy-from Vendor No." <> PurchaseOrders."Buy-from Vendor No." then
                                            NewNumber := true;
                                    end until PurchaseOrdersTemps.Next() = 0;

                            end;
                            if NewNumber then begin
                                Clear(NextSerieCode);
                                Clear(NoSeriesMgt);
                                //NoSeriesMgt.SetParametersBeforeRun(ReplenSetup."FSN Consolidate Serie No.", today);
                                //if NoSeriesMgt.Run() then;
                                //NextSerieCode := NoSeriesMgt.GetNextNoAfterRun();
                                NextSerieCode := NoSeriesMgt.GetNextNo(ReplenSetup."FSN Consolidate Serie No.", Today, TRUE);
                            end;

                            if NextSerieCode <> '' then
                                if PurchaseOrders2.Get(PurchaseOrders."Document Type", PurchaseOrders."No.") then begin
                                    PurchaseOrders2."FSN Consolidate No." := NextSerieCode;
                                    PurchaseOrders2.Modify();
                                    PurchaseOrdersTemps := PurchaseOrders2;
                                    PurchaseOrdersTemps.Insert();
                                end;

                            LastOrderNo := PurchaseOrders."No.";
                        end;
                    until PurchaseOrders.Next() = 0;
            end;
        end;
        GetPurchPerVendor.Close();
    end;

    procedure RunBatchSendPurchase(Cod: Code[50])
    var
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line" temporary;
        Processed: Boolean;
        MsgResult: text;
        FSNUtility: Codeunit "FSN Utility";
    begin
        RequestID := Cod;
        FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);

    end;


    [EventSubscriber(ObjectType::Page, Page::"LSC Stock Request", 'OnBeforeActionEvent', '&Assign Request', true, true)]
    local procedure "LSC Stock Request_OnBeforeActionEvent_[processing / F&unctions] - &Assign Request"(var Rec: Record "LSC InStore Stock Req. Header")
    var
        ItemVendor: Record "Item Vendor";
        InStoreStockReqLine: Record "LSC InStore Stock Req. Line";
        Error000: Label 'El producto %1 no se encuentra relacionado con el proveedor %2 en Item Vendor';
    begin
        if Rec."Document Type" = Rec."Document Type"::"Purchase Order" then begin
            InStoreStockReqLine.Reset();
            InStoreStockReqLine.SetRange(InStoreStockReqLine."Document No.", Rec."No.");
            if InStoreStockReqLine.Find('-') then
                repeat
                    if not ItemVendor.Get(Rec."Vendor No.", InStoreStockReqLine."Item No.") then
                        Error(StrSubstNo(Error000, InStoreStockReqLine."Item No.", Rec."Vendor No."));
                until InStoreStockReqLine.Next() = 0;
        end;
    end;

    procedure TransferUpPitsConsolid(RequestIDComando: Code[50]; FirstTransferNo: Code[20]; LastTransferNo: Code[20]; ConsolidateNo: Code[20])
    var
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line" temporary;
        Processed: Boolean;
        MsgResult: text;
        FSNUtility: Codeunit "FSN Utility";
    begin
        RequestID := RequestIDComando;
        PosMenuLineTemp."Menu ID" := FirstTransferNo;
        PosMenuLineTemp.Command := LastTransferNo;
        PosMenuLineTemp."Post Command" := ConsolidateNo;
        FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
    end;
    //PurchVr55&ReplenVr57
    procedure UpdatePurchHeaderAssocCreditMemo(RequestIDComando: Code[50]; FirstPurchNo: Code[20]; LastPurchNo: Code[20])
    var
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line" temporary;
        Processed: Boolean;
        MsgResult: text;
        FSNUtility: Codeunit "FSN Utility";
    begin
        RequestID := RequestIDComando;
        PosMenuLineTemp."Menu ID" := FirstPurchNo;
        PosMenuLineTemp.Command := LastPurchNo;
        FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
    end;

    //********************


}

pageextension 50072 "FSN TransferReplenJournalExt" extends "LSC Transfer Replen. Journal"
{
    layout
    {
        addbefore(Quantity)
        {
            field("FSN Purch. Quantity"; QtyPurch)
            {
                Caption = 'FSN Cant. UM Compra';
                ApplicationArea = all;
                Editable = false;
                Style = Strong;
            }
            field("FSN Purch. Unit of Measure"; UOMPurch)
            {
                Caption = 'FSN Unidad Medida';
                ApplicationArea = all;
                Editable = false;
                Style = Strong;
            }
        }
    }

    actions
    {
        addafter("Create &Transfer Orders")
        {
            action("FSN Create Consolidate Transfer")
            {
                ApplicationArea = All;
                Caption = 'FSN Create Consolidate Transfer';
                Image = Process;
                Promoted = true;
                PromotedCategory = Category4;

                trigger OnAction()
                var
                    ReplenishmentJournalLines: Record "LSC Replen. Journal Lines";
                    TransferOrder1: Record "Transfer Header";
                    ReplenSetup1: Record "LSC Replen. Setup";
                    NoSeriesMgt: Codeunit NoSeriesManagement;
                    ConsolidateNo: Code[20];
                    NoOfLinesSelected: Integer;
                    fsnReplenCalc: Codeunit "FSN Replen. Calculation";
                begin
                    ReplenSetup1.Get();
                    ReplenSetup1.TestField("FSN Transfer Consolidate No.");

                    if BatchPostingStatus <> '' then
                        Error(JournalOnBatchPostingErr);

                    if not Confirm(CreateTOQst, false) then
                        exit;
                    if ReplenishmentJournalBatch.CheckThresholdBlockDocCreation("Replenishment Template Code", "Batch No.") then
                        if not Confirm(ThresholdExceptionFoundDocCreationQst) then
                            exit;
                    Clear(ReplenishmCreateTransfOrd);

                    ReplenishmentJournalLines := Rec;
                    ReplenishmentJournalLines.Reset;
                    CurrPage.SetSelectionFilter(ReplenishmentJournalLines);

                    NoOfLinesSelected := ReplenishmentJournalLines.Count;
                    if (NoOfLinesSelected = 1) and (GetFilters = '') then begin
                        ReplenishmentJournalLines.Reset;
                        ReplenishmentJournalLines.SetRange("Replenishment Template Code", "Replenishment Template Code");
                        ReplenishmentJournalLines.SetRange("Batch No.", "Batch No.");
                    end;

                    ReplenishmCreateTransfOrd.CreateTransfOrders(ReplenishmentJournalLines, FirstTransferNo, LastTransferNo, FirstSalesOrderNo, LastSalesOrderNo);
                    CurrPage.Update(false);

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

                    if OrderCreatedMsg_g <> '' then
                        Message(OrderCreatedMsg_g);

                    if ConsolidateNo <> '' then begin
                        ReplenishmentJournalLines.Reset;
                        ReplenishmentJournalLines.SetRange("Replenishment Template Code", "Replenishment Template Code");
                        ReplenishmentJournalLines.SetRange("Batch No.", "Batch No.");
                        if ReplenishmentJournalLines.Find('-') then
                            repeat
                                ReplenishmentJournalLines.Delete();
                            until ReplenishmentJournalLines.Next() = 0;
                    end;
                end;
            }
            action("View Matrix")
            {

                trigger OnAction()
                var
                    NewQuantity: Decimal;
                    NewSSQ: Decimal;
                    NewEffQty: Decimal;
                begin

                    IF Rec."Replenishment Template Code" = '' THEN
                        exit;
                    PAGE.RUNMODAL(PAGE::"FSN Replen. By Location", Rec);
                    CurrPage.UPDATE(FALSE);
                end;
            }
        }
    }
    trigger OnAfterGetRecord()
    var
        Item: Record Item;
        UOM: record "Item Unit of Measure";
    begin
        Clear(UOMPurch);
        Clear(QtyPurch);

        BatchPostingStatus := BatchPosting.GetReplenishmentBatchStatus(ReplenishmentJournalBatch);

        if not Item.Get(Rec."Item No.") then begin
            Clear(Item);
            Clear(UOM);
        end else
            if UOM.Get(Item."No.", Item."Purch. Unit of Measure") then
                UOMPurch := Item."Purch. Unit of Measure";
        IF Item."No." = 'A008867' then
            IF Item."No." = 'A008867' then;
        if UOM."Qty. per Unit of Measure" = 1 then
            UOM."Qty. per Unit of Measure" := 1;
        if Rec.Quantity = 0 then
            QtyPurch := 0
        else
            QtyPurch := Rec.Quantity / UOM."Qty. per Unit of Measure";
    end;

    var
        UOMPurch: Code[10];
        QtyPurch: Decimal;
        FirstTransferNo: Code[20];
        LastTransferNo: Code[20];
        BatchPostingStatus: Text[30];
        FirstSalesOrderNo: Code[20];
        LastSalesOrderNo: Code[20];
        BatchPosting: Codeunit "LSC Batch Posting";
        ConsolidateTxt: Label '. Consolidate No. %1';
        ReplenishmentJournalBatch: Record "LSC Replen. Journal Batch";
        ReplenishmCreateTransfOrd: Codeunit "LSC Replen. Create Transf. Ord";
        CreateTOQst: Label 'Do you want to Create Transfer Orders from this Journal?';
        TransferNoCreatedMsg: Label 'Transfer number %1 was created.';
        TransferNoRangeCreatedMsg: Label 'Transfer numbers %1 through %2 were created.';
        JournalOnBatchPostingErr: Label 'Journal has been put on the Batch Posting Queue.';
        ThresholdExceptionFoundDocCreationQst: Label 'One or more Threshold exceptions found, do you still wish to proceed to create Transfer Orders?';
        SalesNoCreatedMsg: Label 'Sales number %1 was created.';
        SalesNoRangeCreatedMsg: Label 'Sales numbers %1 through %2 were created.';
        OrderCreatedMsg_g: Text;
}
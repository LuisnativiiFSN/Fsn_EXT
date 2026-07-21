pageextension 50068 "FSN PurchReplenJournalExt" extends "LSC Purchase Replen. Journal"
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
        addafter(ReplLocation)
        {
            //field(GlobalConsolidateNo; GlobalConsolidateNo)
            field(GlobalConsolidateNo; RefreshConsolidateNo(Rec."Replenishment Template Code"))
            {
                Caption = 'New Consolidate No.';
                ApplicationArea = all;
                Editable = false;
                Style = Strong;
            }
        }

    }

    actions
    {
        addlast(processing)
        {
            action("Item Test Status")
            {
                Caption = 'Item Test Status';
                trigger OnAction()
                var

                    ReplenJrnDetails: Record "LSC Replen. Jrnl. Details";
                    Replen_Template: Record "LSC Replen. Template";
                    BOUtils_: Codeunit "LSC BO Utils";
                    ItemStatusLinks_: Record "LSC Item Status Link";
                    Replen_JrnLine: Record "LSC Replen. Journal Lines";
                    lText002: Label 'Validate successfull!';
                    lText001: Label 'Item %1 %2 is blocked for Purchasing. See Item Status Link %3 %4 %5';
                    lText003: Label 'Item %1 %2 is blocked for Transfering. See Item Status Link %3 %4 %5';
                    lText004: Label 'No articles for valid';
                begin
                    if Replen_Template.GET("Replenishment Template Code") then begin
                        Replen_JrnLine.RESET;
                        Replen_JrnLine.SETRANGE(Replen_JrnLine."Replenishment Template Code", "Replenishment Template Code");
                        Replen_JrnLine.SETRANGE(Replen_JrnLine."Batch No.", "Batch No.");
                        IF Replen_JrnLine.FIND('-') THEN
                            REPEAT

                                ReplenJrnDetails.RESET;
                                ReplenJrnDetails.SETCURRENTKEY("Replenishment Template Code", "Batch No.", "Line No.", "Detail Line No.");
                                ReplenJrnDetails.SETRANGE(ReplenJrnDetails."Replenishment Template Code", "Replenishment Template Code");
                                ReplenJrnDetails.SETRANGE(ReplenJrnDetails."Batch No.", "Batch No.");
                                ReplenJrnDetails.SETRANGE(ReplenJrnDetails."Line No.", Replen_JrnLine."Line No.");
                                IF ReplenJrnDetails.FINDSET THEN BEGIN
                                    IF Replen_Template."Replenishment Type" = Replen_Template."Replenishment Type"::Purchase THEN BEGIN
                                        IF BOUtils_.IsBlockPurchasing(ReplenJrnDetails."Item No.", '', ReplenJrnDetails."Variant Code", '',
                                          ReplenJrnDetails."Location Code", TODAY, ItemStatusLinks_) THEN
                                            ERROR(lText001, ReplenJrnDetails."Item No.", ReplenJrnDetails.Description,
                                            ReplenJrnDetails."Variant Code", ReplenJrnDetails."Location Code", TODAY);
                                    END ELSE
                                        IF BOUtils_.IsBlockTransfering(ReplenJrnDetails."Item No.", '', ReplenJrnDetails."Variant Code", '',
                                          ReplenJrnDetails."Location Code", TODAY, ItemStatusLinks_) THEN
                                            ERROR(lText002, ReplenJrnDetails."Item No.", ReplenJrnDetails.Description,
                                            ReplenJrnDetails."Variant Code", ReplenJrnDetails."Location Code", TODAY);
                                END ELSE
                                    ERROR(lText004);
                            UNTIL Replen_JrnLine.NEXT = 0;
                    END;
                    MESSAGE(lText002);
                end;

            }
            action("View Matrix")
            {
                Caption = 'View Matrix';
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
            action("New Consolidate No.")
            {
                ApplicationArea = All;
                Image = NewLotProperties;
                Promoted = true;
                PromotedCategory = Category4;
                Caption = 'New Consolidate No.';
                trigger OnAction()
                begin
                    if ReplenTemplate_g.Get(Rec."Replenishment Template Code") then begin
                        ReplenTemplate_g."FSN Consolidate No." := '';
                        ReplenSetup.TestField("FSN Consolidate Serie No.");
                        ReplenTemplate_g."FSN Consolidate No." := NoSeriesMgt.GetNextNo(ReplenSetup."FSN Consolidate Serie No.", Today, true);
                        ReplenTemplate_g.Modify();
                        //GlobalConsolidateNo := ReplenTemplate_g."FSN Consolidate No.";
                    end;
                end;
            }
            action("FSN Create Consolidate Orders")
            {
                ApplicationArea = All;
                Caption = '&FSN Create Consolidate Orders';
                Image = Process;
                Promoted = true;
                PromotedCategory = Category4;

                trigger OnAction()
                var
                    ReplenishmentJournalLines: Record "LSC Replen. Journal Lines";
                    PurchOrder: Record "Purchase Header";
                    FirstPurchOrderNo: Code[20];
                    LastPurchOrderNo: Code[20];
                    NoOfLinesSelected: Integer;
                    NewConsolidateNo: Code[20];
                    ReplenNo: Code[20];
                    replenCalculation: Codeunit "FSN Replen. Calculation";

                begin
                    Clear(NewConsolidateNo);

                    ReplenSetup.TestField("FSN Consolidate Serie No.");
                    NoSeriesMgt.GetNextNo(ReplenSetup."FSN Consolidate Serie No.", Today, false);

                    if BatchPostingStatus_g <> '' then
                        Error(Text023);

                    if not Confirm(Text006, false) then
                        exit;
                    if ReplenishmentJournalBatch_g.CheckThresholdBlockDocCreation("Replenishment Template Code", "Batch No.") then
                        if not Confirm(ThresholdExceptionFoundDocCreationQst) then
                            exit;
                    Clear(ReplenishmCreatePurchOrder);

                    ReplenishmentJournalLines := Rec;
                    ReplenishmentJournalLines.Reset;
                    CurrPage.SetSelectionFilter(ReplenishmentJournalLines);

                    NoOfLinesSelected := ReplenishmentJournalLines.Count;
                    if (NoOfLinesSelected = 1) and (GetFilters = '') then begin
                        ReplenishmentJournalLines.Reset;
                        ReplenishmentJournalLines.SetRange("Replenishment Template Code", "Replenishment Template Code");
                        ReplenishmentJournalLines.SetRange("Batch No.", "Batch No.");
                    end;
                    ReplenNo := Rec."Replenishment Template Code";
                    ReplenishmCreatePurchOrder.CreatePurchaseOrders(ReplenishmentJournalLines, FirstPurchOrderNo, LastPurchOrderNo);
                    //PurchVr55
                    ReplenTemplate_g.Get(Rec."Replenishment Template Code");
                    if ReplenTemplate_g."Associated Credit Memo" then
                        replenCalculation.UpdatePurchHeaderAssocCreditMemo('UPDASSOCPH', FirstPurchOrderNo, LastPurchOrderNo);
                    //**********
                    CurrPage.Update(false);

                    ReplenTemplate_g.Get(Rec."Replenishment Template Code");
                    if ReplenTemplate_g."FSN Consolidate No." <> '' then
                        NewConsolidateNo := ReplenTemplate_g."FSN Consolidate No."
                    else
                        NewConsolidateNo := NoSeriesMgt.GetNextNo(ReplenSetup."FSN Consolidate Serie No.", Today, true);

                    PurchOrder.Reset();
                    PurchOrder.SetRange("Document Type", PurchOrder."Document Type"::Order);
                    PurchOrder.SetRange("No.", FirstPurchOrderNo, LastPurchOrderNo);
                    if PurchOrder.Find('-') then
                        repeat
                            PurchOrder."FSN Consolidate No." := NewConsolidateNo;
                            PurchOrder.Modify();
                        until PurchOrder.Next() = 0;

                    if FirstPurchOrderNo <> '' then
                        if FirstPurchOrderNo = LastPurchOrderNo then
                            Message(Text010, FirstPurchOrderNo, NewConsolidateNo)
                        else
                            Message(Text011, FirstPurchOrderNo, LastPurchOrderNo, NewConsolidateNo)
                    else
                        Message(Text009, NewConsolidateNo);

                    if ReplenishmentTemplate_g.Get(ReplenNo) then begin
                        ReplenishmentTemplate_g."FSN Consolidate No." := '';
                        ReplenishmentTemplate_g.Modify();
                    end;
                end;
            }

            action("FASANI Añadir productos al Diario")
            {
                ApplicationArea = All;
                Caption = 'FASANI Añadir productos al Diario';
                Image = Process;
                Visible = FALSE;
                PromotedCategory = Category4;
                Promoted = true;

                trigger OnAction()
                var
                    ReportP: Report "FSN Full Replen. By Location";
                begin
                    ReportP.Run();
                end;
            }
        }
    }
    trigger OnOpenPage()
    begin

        BatchPostingStatus_g := BatchPostingStatus;
        ReplenSetup.Get();

    end;

    trigger OnAfterGetRecord()
    var
        Item: Record Item;
        UOM: record "Item Unit of Measure";
    begin
        Clear(UOMPurch);
        Clear(QtyPurch);

        if not Item.Get(Rec."Item No.") then begin
            Clear(Item);
            Clear(UOM);
        end else
            if UOM.Get(Item."No.", Item."Purch. Unit of Measure") then
                UOMPurch := Item."Purch. Unit of Measure";

        if UOM."Qty. per Unit of Measure" = 1 then
            UOM."Qty. per Unit of Measure" := 1;

        if Rec.Quantity = 0 then
            QtyPurch := 0
        else
            QtyPurch := Rec.Quantity / UOM."Qty. per Unit of Measure";

    end;

    local procedure RefreshConsolidateNo(pCode: Code[20]): Code[20]
    var
        ReplenTemplate_l: Record "LSC Replen. Template";
    begin
        if ReplenTemplate_l.Get(pCode) then
            exit(ReplenTemplate_l."FSN Consolidate No.")
        else
            exit('');
    end;

    var
        UOMPurch: Code[10];
        QtyPurch: Decimal;
        BatchPostingStatus_g: Text;
        ReplenTemplate_g: Record "LSC Replen. Template";
        Text006: Label 'Do you want to Create Purchase Orders from this Journal?';
        Text009: Label 'No Purchase Orders were created. Consolidate No. %2';
        Text010: Label 'Purchase Order %1 was created. Consolidate No. %2';
        Text011: Label 'Purchase Orders %1 to %2 were created. Consolidate No. %3';
        Text023: Label 'Journal has been put on the Batch Posting Queue.';
        ThresholdExceptionFoundDocCreationQst: Label 'One or more Threshold exceptions found, do you still wish to proceed to create Purchase Orders?';
        ReplenSetup: Record "LSC Replen. Setup";
        NoSeriesMgt: Codeunit NoSeriesManagement;
}
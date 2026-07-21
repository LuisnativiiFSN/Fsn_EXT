/*report 50006 "FSN Replen. Automatic Run"
{
    ApplicationArea = All;
    Caption = 'FSN Replen. Automatic Run';
    ProcessingOnly = true;
    UsageCategory = Tasks;
    ExecutionTimeout = '12:00:00';

    dataset
    {
        dataitem("Replen. Journal Batch"; "LSC Replen. Journal Batch")
        {
            DataItemTableView = WHERE("Run Frequency" = FILTER(<> "Run Manually"));
            RequestFilterFields = "Replenishment Template Code", "Batch No.", "Run Frequency";

            trigger OnAfterGetRecord()
            var
                ReplenItemQuantity: Record "LSC Replen. Item Quantity";
                ShouldBeSkipped: Boolean;
            begin
                if "Run Frequency" in ["Run Frequency"::Daily, "Run Frequency"::"Weekdays Only"] then
                    //if "Next Run Date" <= WorkDate then begin
                    if "Next Run Date" <= Today then begin
                        case Date2DWY(Today, 1) of
                            //case Date2DWY(WorkDate, 1) of
                            1:
                                ShouldBeSkipped := not "Include Mondays";
                            2:
                                ShouldBeSkipped := not "Include Tuesdays";
                            3:
                                ShouldBeSkipped := not "Include Wednesdays";
                            4:
                                ShouldBeSkipped := not "Include Thursdays";
                            5:
                                ShouldBeSkipped := not "Include Fridays";
                            6:
                                ShouldBeSkipped := not "Include Saturdays";
                            7:
                                ShouldBeSkipped := not "Include Sundays";
                        end;
                        if ShouldBeSkipped and not "Allowed to run on Any Day" then
                            CurrReport.Skip;
                    end;

                if ("Run Frequency" = "Run Frequency"::"Specific Day") and ("Next Run Date" = 0D) then
                    CurrReport.Skip;
                ReplenishmentTemplate.SetRange(Code, "Replenishment Template Code");
                if not ReplenishmentTemplate.FindFirst then
                    CurrReport.Skip;

                ReplenishmentTemplate.Get("Replenishment Template Code");

                ReplenItemQuantity.Reset;
                ReplenItemQuantity.FilterGroup(3);
                if not ((ReplenishmentTemplate."Replenishment Type" = ReplenishmentTemplate."Replenishment Type"::Purchase) and
                    (ReplenishmentTemplate."Purchase Order Type"
                    = ReplenishmentTemplate."Purchase Order Type"::"Purchase Orders for Receiving Locations"))
                then
                    ReplenItemQuantity.SetRange("Replenish From Warehouse", ReplenishmentTemplate."Location Code");
                ReplenItemQuantity.FilterGroup(0);

                if ReplenishmentTemplate."Item Division Filter" <> '' then begin
                    ReplenItemQuantity.SetCurrentKey("Replenish From Warehouse", "Item Division Code", "Item Category Code", "Retail Product Code");
                    ReplenItemQuantity.SetFilter("Item Division Code", ReplenishmentTemplate."Item Division Filter");
                end;

                if (ReplenishmentTemplate."Item Category Filter" <> '') or (ReplenishmentTemplate."Retail Product Filter" <> '') then begin
                    ReplenItemQuantity.SetCurrentKey("Replenish From Warehouse", "Item Division Code", "Item Category Code", "Retail Product Code");
                    if ReplenishmentTemplate."Item Category Filter" <> '' then
                        ReplenItemQuantity.SetFilter("Item Category Code", ReplenishmentTemplate."Item Category Filter");
                    if ReplenishmentTemplate."Retail Product Filter" <> '' then
                        ReplenItemQuantity.SetFilter("Retail Product Code", ReplenishmentTemplate."Retail Product Filter");
                end;

                if ReplenishmentTemplate."Item No. Filter" <> '' then begin
                    if (ReplenishmentTemplate."Item Category Filter" = '') and
                       (ReplenishmentTemplate."Retail Product Filter" = '')
                    then
                        ReplenItemQuantity.SetCurrentKey("Replenish From Warehouse", "Item No.");
                    ReplenItemQuantity.SetFilter("Item No.", ReplenishmentTemplate."Item No. Filter");
                end;

                if ReplenishmentTemplate."Vendor No. Filter" <> '' then begin
                    ReplenItemQuantity.SetCurrentKey("Replenish From Warehouse", "Vendor No.");
                    ReplenItemQuantity.SetFilter("Vendor No.", ReplenishmentTemplate."Vendor No. Filter");
                end;

                if ReplenishmentTemplate."Replenishm. Calc. Type Filter" <> '' then
                    ReplenItemQuantity.SetFilter("Replenishment Calculation Type", ReplenishmentTemplate."Replenishm. Calc. Type Filter");

                if ReplenishmentTemplate."Season Filter" <> '' then
                    ReplenItemQuantity.SetFilter("Season Code", ReplenishmentTemplate."Season Filter");

                if ReplenishmentTemplate."ABC Amount Filter" <> ReplenishmentTemplate."ABC Amount Filter"::" " then
                    ReplenItemQuantity.SetRange("ABC Amount", ReplenishmentTemplate."ABC Amount Filter");

                if ReplenishmentTemplate."ABC Profit Filter" <> ReplenishmentTemplate."ABC Profit Filter"::" " then
                    ReplenItemQuantity.SetRange("ABC Profit", ReplenishmentTemplate."ABC Profit Filter");

                if (ReplenishmentTemplate."Item Hierarchy Filter" <> '') and
                    (ReplenishmentTemplate."Item Hierarchy Level Filter" <> 0) and
                    (ReplenishmentTemplate."Item Hierarchy Value Filter" <> '')
                then begin
                    ReplenItemQuantity.SetFilter("Item Hierarchy Filter", ReplenishmentTemplate."Item Hierarchy Filter");
                    ReplenItemQuantity.SetRange("Item Hierarchy Level Filter", ReplenishmentTemplate."Item Hierarchy Level Filter");
                    ReplenItemQuantity.SetFilter("Item Hierarchy Value Filter", ReplenishmentTemplate."Item Hierarchy Value Filter");
                end;

                if ReplenishmentTemplate."Special Group Code Filter" <> '' then
                    ReplenItemQuantity.SetFilter("Special Group Code Filter", ReplenishmentTemplate."Special Group Code Filter");

                if (ReplenishmentTemplate."Item Attribute Code Filter" <> '') and
                    (ReplenishmentTemplate."Item Attribute Value Filter" <> '')
                then begin
                    ReplenItemQuantity.SetFilter("Item Attribute Code Filter", ReplenishmentTemplate."Item Attribute Code Filter");
                    ReplenItemQuantity.SetFilter("Item Attribute Value Filter", ReplenishmentTemplate."Item Attribute Value Filter");
                end;

                Clear(AddItemsToReplenishmJrnlReport);
                AddItemsToReplenishmJrnlReport.SetTableView(ReplenItemQuantity);
                AddItemsToReplenishmJrnlReport.SetReplenishmJournal("Replen. Journal Batch");
                AddItemsToReplenishmJrnlReport.UseRequestPage(false);
                AddItemsToReplenishmJrnlReport.RunModal;
                Commit;

                //Consolidate
                SetAllPurchConsolidateNo;
                SetAllTransferConsolidateNo();
            end;

            trigger OnPreDataItem()
            begin
                case ReplenishmentTypeFilter of
                    ReplenishmentTypeFilter::Purchase:
                        ReplenishmentTemplate.SetRange("Replenishment Type", ReplenishmentTemplate."Replenishment Type"::Purchase);
                    ReplenishmentTypeFilter::Transfer:
                        ReplenishmentTemplate.SetRange("Replenishment Type", ReplenishmentTemplate."Replenishment Type"::Transfer);
                    else
                        ReplenishmentTemplate.SetRange("Replenishment Type", ReplenishmentTemplate."Replenishment Type"::Purchase,
                          ReplenishmentTemplate."Replenishment Type"::Transfer);
                end;

                if GetFilter("Next Run Date") = '' then
                    SetRange("Next Run Date", 0D, today);
                //SetRange("Next Run Date", 0D, WorkDate);
            end;

            trigger OnPostDataItem()
            begin
            end;
        }
    }

    requestpage
    {

        layout
        {
            area(content)
            {
                group(Option)
                {
                    Caption = 'Option';
                    field(ReplenishmentTypeFilter; ReplenishmentTypeFilter)
                    {
                        ApplicationArea = All;
                        Caption = 'Replenishment Type Filter';
                    }
                }
            }
        }

        actions
        {
        }
    }

    labels
    {
    }
    procedure SetFilterReplenType(pReplenishmentTypeFilter: Option "Purchase and Transfer",Purchase,Transfer)
    begin
        ReplenishmentTypeFilter := pReplenishmentTypeFilter;
    end;

    procedure SetAllPurchConsolidateNo()
    var
        GetPurchPerVendor: Query "FSN Get Purchase per Vendor";
        PurchaseOrders: Record "Purchase Header";
        PurchaseOrders2: Record "Purchase Header";
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
        //GetPurchPerVendor.SetRange(GetPurchPerVendor.Order_Date, WorkDate());
        GetPurchPerVendor.SetRange(GetPurchPerVendor.Order_Date, today);
        GetPurchPerVendor.Open();
        while GetPurchPerVendor.Read() do begin
            if GetPurchPerVendor.FSN_Consolidate_No_ = '' then begin
                Clear(NextSerieCode);
                PurchaseOrders.Reset();
                PurchaseOrders.SetRange("Document Type", PurchaseOrders."Document Type"::Order);
                PurchaseOrders.SetRange("Order Date", GetPurchPerVendor.Order_Date);
                if PurchaseOrders.Find('-') then
                    repeat
                        if (PurchaseOrders."FSN Consolidate No." <> '') and (PurchaseOrders."LSC Created By Source Code" <> '') then begin

                            NewNumber := NextSerieCode = '';
                            if not NewNumber then
                                NewNumber := LastOrderNo = '';

                            if not NewNumber and (LastOrderNo <> '') then begin
                                NextOrderNo := IncStr(LastOrderNo);
                                NewNumber := NextOrderNo <> PurchaseOrders."No.";
                            end;

                            if NewNumber then begin
                                Clear(NextSerieCode);
                                Clear(NoSeriesMgt);
                                NoSeriesMgt.SetParametersBeforeRun(ReplenSetup."FSN Consolidate Serie No.", today);
                                if NoSeriesMgt.Run() then;
                                NextSerieCode := NoSeriesMgt.GetNextNoAfterRun();
                            end;
                            if NextSerieCode <> '' then
                                if PurchaseOrders2.Get(PurchaseOrders."Document Type", PurchaseOrders."No.") then begin
                                    PurchaseOrders2."FSN Consolidate No." := NextSerieCode;
                                    PurchaseOrders2.Modify();
                                end;

                            LastOrderNo := PurchaseOrders."No.";
                        end;
                    until PurchaseOrders.Next() = 0;
            end;
        end;
        GetPurchPerVendor.Close();
    end;

    procedure SetAllTransferConsolidateNo()
    var
        TransferOrders1: Record "Transfer Header";
        TransferOrders2: Record "Transfer Header";
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

                            if not NewNumber and (LastOrderNo <> '') then begin
                                NextOrderNo := IncStr(LastOrderNo);
                                NewNumber := NextOrderNo <> TransferOrders1."No.";
                            end;

                            if NewNumber then begin
                                Clear(NextSerieCode);
                                Clear(NoSeriesMgt);
                                NoSeriesMgt.SetParametersBeforeRun(ReplenSetup."FSN Consolidate Serie No.", today);
                                if NoSeriesMgt.Run() then;
                                NextSerieCode := NoSeriesMgt.GetNextNoAfterRun();
                            end;

                            if NextSerieCode <> '' then
                                if TransferOrders2.Get(TransferOrders1."No.") then begin
                                    TransferOrders2."FSN Consolidate No." := NextSerieCode;
                                    TransferOrders2.Modify();
                                end;

                            LastOrderNo := TransferOrders1."No.";
                        end;
                    until TransferOrders1.Next() = 0;
            until Location.next() = 0;
    end;


    var
        ReplenishmentTemplate: Record "LSC Replen. Template";
        AddItemsToReplenishmJrnlReport: Report "LSC Add Items to Replen. Jrnl";
        ReplenishmentTypeFilter: Option "Purchase and Transfer",Purchase,Transfer;
        ReplenSetup: Record "LSC Replen. Setup";
        NoSerie: Codeunit NoSeriesManagement;
}*/


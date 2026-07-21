codeunit 50000 "FSN Batch - Send Purchase Data"

{
    TableNo = "LSC Scheduler Job Header";
    trigger OnRun()
    begin
        if Rec.Code = 'RECPCOMM' then begin
            ClearRecepComMin();
            exit;
        end;
        if Rec.Code = 'REVCOST' then begin
            RevCost(Rec);
            exit;
        end;
        SendExternalOrders;
    end;

    var
        PurchaseOrder: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        cf: codeunit "LSC Picking/Receiving - Post";
        pp: codeunit "Purch.-Post";

    procedure SendExternalOrders()
    var
        FrontierTable: Record "FSN External Purch. Line";
        FASANIPurchSetup: Record "FSN Fasani Setup";
        Vendor_l: Record Vendor;
        Store_l: Record "LSC Store";
        Ok_: Boolean;
    begin

        PurchaseOrder.RESET;
        PurchaseOrder.SETCURRENTKEY("Document Type", Status, "Expected Receipt Date", Receive, Invoice, "Responsibility Center");
        PurchaseOrder.SETRANGE(PurchaseOrder."Document Type", PurchaseOrder."Document Type"::Order);
        PurchaseOrder.SETRANGE(PurchaseOrder.Status, PurchaseOrder.Status::Released);
        PurchaseOrder.SETFILTER(PurchaseOrder."FSN Consolidate No.", '<>%1', '');
        IF PurchaseOrder.FINDSET THEN
            REPEAT
                IF ((Vendor_l.GET(PurchaseOrder."Buy-from Vendor No.")) AND (PurchaseOrder."Location Code" <> 'CD')) OR ((Vendor_l.GET(PurchaseOrder."Buy-from Vendor No.")) AND (PurchaseOrder."Buy-from Vendor No." = 'PROV-000026')) THEN
                    IF TRUE THEN BEGIN
                        Ok_ := FALSE;
                        IF PurchaseOrder."LSC Store No." <> '' THEN
                            Ok_ := FASANIPurchSetup.GET(PurchaseOrder."LSC Store No.")
                        ELSE BEGIN
                            Store_l.RESET;
                            Store_l.SETCURRENTKEY(Store_l."Location Code");
                            Store_l.SETRANGE(Store_l."Location Code", PurchaseOrder."Location Code");
                            IF Store_l.FINDFIRST THEN
                                Ok_ := FASANIPurchSetup.GET(Store_l."No.");
                        END;
                        IF Ok_ THEN
                            IF FASANIPurchSetup."Use External Purch. Line" THEN BEGIN
                                FrontierTable.RESET;
                                FrontierTable.SETRANGE(FrontierTable."No.", PurchaseOrder."No.");
                                IF NOT FrontierTable.FINDFIRST THEN
                                    SendCreateExternalLines(PurchaseOrder);
                            END;
                    END;
            UNTIL PurchaseOrder.NEXT = 0;
    end;


    procedure SendCreateExternalLines(PurchaseHeader: Record "Purchase Header")
    var
        ExternalPurchLine: Record "FSN External Purch. Line";
        ItemREC: Record Item;
        PurchaseLine2: Record "Purchase Line";
        Vendor_l: Record Vendor;
    begin
        //WVILLALTA13DIC18 Completamente modificado
        PurchaseLine.RESET;
        PurchaseLine.SETCURRENTKEY(PurchaseLine."No.", PurchaseLine."Line No.");
        PurchaseLine.SETRANGE(PurchaseLine."Document No.", PurchaseHeader."No.");
        IF PurchaseLine.FINDSET THEN
            REPEAT
                IF NOT ExternalPurchLine.GET(PurchaseLine."Document No.", PurchaseLine."Line No.") THEN BEGIN
                    ExternalPurchLine.INIT;
                    ExternalPurchLine."No." := PurchaseLine."Document No.";
                    ExternalPurchLine."Line No." := PurchaseLine."Line No.";
                    ExternalPurchLine."Starting Date" := CURRENTDATETIME;
                    ExternalPurchLine."Location Code" := PurchaseHeader."Location Code";

                    IF NOT GUIALLOWED THEN
                        IF PurchaseLine."Location Code" = '' THEN
                            IF PurchaseLine2.GET(PurchaseLine."Document Type", PurchaseLine."Document No.", PurchaseLine."Line No.") THEN BEGIN
                                PurchaseLine2."Location Code" := PurchaseHeader."Location Code";
                                PurchaseLine2.MODIFY;
                            END;

                    ExternalPurchLine."Source No." := PurchaseHeader."No.";
                    IF Vendor_l.GET(PurchaseHeader."Buy-from Vendor No.") THEN
                        if Vendor_l."FSN Code Vendor" <> '' then
                            ExternalPurchLine."Vendor No." := Vendor_l."FSN Code Vendor"
                        else
                            ExternalPurchLine."Vendor No." := PurchaseHeader."Buy-from Vendor No.";

                    if ExternalPurchLine."Vendor No." = '' then
                        if Vendor_l.Get(PurchaseLine."Buy-from Vendor No.") then
                            ExternalPurchLine."Vendor No." := Vendor_l."FSN Code Vendor";

                    ExternalPurchLine."Vendor Name" := CopyStr(PurchaseHeader."Buy-from Vendor Name", 1, 50);
                    ExternalPurchLine."Vendor Invoice No." := '';
                    ExternalPurchLine."Item No." := PurchaseLine."No.";
                    IF ItemREC.GET(PurchaseLine."No.") THEN
                        ExternalPurchLine."Barcode No." := ItemREC."FSN Barcode No.";
                    ExternalPurchLine.Description := CopyStr(PurchaseLine.Description, 1, 50);
                    ExternalPurchLine.Quantity := PurchaseLine.Quantity;
                    ExternalPurchLine."Qty. to Receive" := 0;
                    ExternalPurchLine."Unit of Measure" := PurchaseLine."Unit of Measure Code";
                    if PurchaseLine."Direct Unit Cost" <> 0 then
                        ExternalPurchLine."Direct Unit Cost" := PurchaseLine."Direct Unit Cost";
                    IF ExternalPurchLine."Direct Unit Cost" = 0 THEN
                        ExternalPurchLine."Direct Unit Cost" := FindDirectUnitCost(PurchaseLine."No.", PurchaseLine."Variant Code",
                     PurchaseLine."Unit of Measure Code", PurchaseHeader."Buy-from Vendor No.", PurchaseLine.Quantity);  //WVILLALTA05ABR19-+
                    ExternalPurchLine.Amount := PurchaseLine.Amount;
                    ExternalPurchLine."Amount Including VAT" := PurchaseLine."Amount Including VAT";
                    ExternalPurchLine.Received := FALSE;
                    ExternalPurchLine.TransferComplete := FALSE;
                    ExternalPurchLine."Consolidado No." := PurchaseHeader."FSN Consolidate No.";
                    ExternalPurchLine.Rapidito := (PurchaseHeader."LSC Retail Purch Src Filter" = PurchaseHeader."LSC Retail Purch Src Filter"::" ");
                    ExternalPurchLine.INSERT(TRUE);
                END;
            UNTIL PurchaseLine.NEXT = 0;
        //Validar las lineas pendientes
        PurchaseHeader."FSN Outstanding Lines" := PurchHeaderOutQtyReceived(PurchaseHeader);
        PurchaseHeader.Modify();
    end;


    procedure FindDirectUnitCost(ItemNo: Code[20]; Variant: Code[10]; UnitOfMeasureCode: Code[20]; Vendor: Code[20]; Quantity: Decimal): Decimal
    var
        PurchasePrice: Record "Purchase Price";
        ItemUnitOfMeasure_l: Record "Unit of Measure";
    begin
        //FindDirectUnitCost
        IF ItemNo = '' THEN
            EXIT(0);

        PurchasePrice.RESET;
        PurchasePrice.SETCURRENTKEY("Item No.", "Vendor No.", "Starting Date", "Currency Code", "Variant Code", "Unit of Measure Code", "Minimum Quantity");
        PurchasePrice.SETRANGE("Item No.", ItemNo);
        PurchasePrice.SETRANGE("Vendor No.", Vendor);
        PurchasePrice.SETFILTER("Starting Date", '<=%1|%2', WORKDATE, 0D);
        PurchasePrice.SETFILTER("Currency Code", '%1', '');
        PurchasePrice.SETRANGE(PurchasePrice."Variant Code", Variant);
        PurchasePrice.SETRANGE(PurchasePrice."Unit of Measure Code", UnitOfMeasureCode);
        PurchasePrice.SETFILTER("Minimum Quantity", '<=%1', Quantity);
        PurchasePrice.SETFILTER("Ending Date", '>=%1|%2', WORKDATE, 0D);
        IF PurchasePrice.FINDLAST THEN
            EXIT(PurchasePrice."Direct Unit Cost");

        EXIT(0);
    end;


    /* [EventSubscriber(ObjectType::Code"FSN Utility"unit, Codeunit::"Purch.-Post", 'OnBeforePurchRcptLineInsert', '', true, true)]
    local procedure "Purch.-Post_OnBeforePurchRcptLineInsert"
    (
        var PurchRcptLine: Record "Purch. Rcpt. Line";
        var PurchRcptHeader: Record "Purch. Rcpt. Header";
        var PurchLine: Record "Purchase Line";
        CommitIsSupressed: Boolean;
        PostedWhseRcptLine: Record "Posted Whse. Receipt Line";
        var IsHandled: Boolean
    )
    begin
        //Remove this temp
        if PurchRcptLine.Quantity = 0 then
            IsHandled := true;
    end; */

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
        FSNBatchSendPurchData: Codeunit "FSN Batch - Send Purchase Data";
        scheduler: Record "LSC Scheduler Job Header";
    begin

        if RequestID = 'CONSOLID' then begin
            scheduler.init;
            FSNBatchSendPurchData.Run(scheduler);
        end;
    end;

    local procedure ClearRecepComMin()
    var
        recep: Record "LSC P/R Counting Header";
        recepLine: Record "LSC Picking / Receiving lines";
        purch: Record "Purchase Header";
    begin
        recep.Reset();
        recep.SetRange("Store No.", 'CD');
        recep.SetRange(Receiving, recep.Receiving::"Purchase Order");
        if recep.FindFirst() then
            repeat begin
                //Sin Lineas
                recepLine.Reset();
                recepLine.SetRange("Document No.", recep."No.");
                if not recepLine.FindFirst() then begin
                    recep.Delete();
                    exit;
                end;
                //pedido no existe
                purch.Reset();
                purch.SetRange("No.", recep."Reference No.");
                if not purch.FindFirst() then
                    recep.Delete();
            end until recep.Next() = 0;
    end;

    //PurchaseV67
    procedure SendCreateExternalLinesLotes(PurchaseHeader: Record "Purchase Header")
    var
        ExternalPurchLine: Record "FSN External Purch. Line";
        ItemREC: Record Item;
        PurchaseLine2: Record "Purchase Line";
        Vendor_l: Record Vendor;
        recepPurch: Record "LSC P/R Counting Header";
        recepPurchLine: Record "LSC Picking / Receiving lines";
    begin
        PurchaseLine.RESET;
        PurchaseLine.SETCURRENTKEY(PurchaseLine."No.", PurchaseLine."Line No.");
        PurchaseLine.SETRANGE(PurchaseLine."Document No.", PurchaseHeader."No.");
        IF PurchaseLine.FINDSET THEN BEGIN
            REPEAT

                recepPurch.Reset();
                recepPurch.SetRange("Reference No.", PurchaseHeader."No.");
                recepPurch.SetRange("FSN Authorized Reception", true);
                if recepPurch.FindFirst() then
                    repeat
                        recepPurchLine.Reset();
                        recepPurchLine.SetRange("Document No.", recepPurch."No.");
                        recepPurchLine.SetRange("Item No.", PurchaseLine."No.");
                        recepPurchLine.SetFilter(Quantity, '<>%1', 0);
                        if recepPurchLine.FindFirst() then
                            IF NOT ExternalPurchLine.GET(PurchaseLine."Document No.", PurchaseLine."Line No.") THEN BEGIN
                                ExternalPurchLine.INIT;
                                ExternalPurchLine."No." := PurchaseLine."Document No.";
                                ExternalPurchLine."Line No." := PurchaseLine."Line No.";
                                ExternalPurchLine."Starting Date" := CURRENTDATETIME;
                                ExternalPurchLine."Location Code" := PurchaseHeader."Location Code";

                                IF NOT GUIALLOWED THEN
                                    IF PurchaseLine."Location Code" = '' THEN
                                        IF PurchaseLine2.GET(PurchaseLine."Document Type", PurchaseLine."Document No.", PurchaseLine."Line No.") THEN BEGIN
                                            PurchaseLine2."Location Code" := PurchaseHeader."Location Code";
                                            PurchaseLine2.MODIFY;
                                        END;

                                ExternalPurchLine."Source No." := PurchaseHeader."No.";
                                IF Vendor_l.GET(PurchaseHeader."Buy-from Vendor No.") THEN
                                    if Vendor_l."FSN Code Vendor" <> '' then
                                        ExternalPurchLine."Vendor No." := Vendor_l."FSN Code Vendor"
                                    else
                                        ExternalPurchLine."Vendor No." := PurchaseHeader."Buy-from Vendor No.";

                                if ExternalPurchLine."Vendor No." = '' then
                                    if Vendor_l.Get(PurchaseLine."Buy-from Vendor No.") then
                                        ExternalPurchLine."Vendor No." := Vendor_l."FSN Code Vendor";

                                ExternalPurchLine."Vendor Name" := CopyStr(PurchaseHeader."Buy-from Vendor Name", 1, 50);
                                ExternalPurchLine."Vendor Invoice No." := '';
                                ExternalPurchLine."Item No." := PurchaseLine."No.";
                                IF ItemREC.GET(PurchaseLine."No.") THEN
                                    ExternalPurchLine."Barcode No." := ItemREC."FSN Barcode No.";
                                ExternalPurchLine.Description := CopyStr(PurchaseLine.Description, 1, 50);
                                ExternalPurchLine.Quantity := PurchaseLine.Quantity;
                                ExternalPurchLine."Qty. to Receive" := 0;
                                ExternalPurchLine."Unit of Measure" := PurchaseLine."Unit of Measure Code";
                                if PurchaseLine."Direct Unit Cost" <> 0 then
                                    ExternalPurchLine."Direct Unit Cost" := PurchaseLine."Direct Unit Cost";
                                IF ExternalPurchLine."Direct Unit Cost" = 0 THEN
                                    ExternalPurchLine."Direct Unit Cost" := FindDirectUnitCost(PurchaseLine."No.", PurchaseLine."Variant Code",
                                 PurchaseLine."Unit of Measure Code", PurchaseHeader."Buy-from Vendor No.", PurchaseLine.Quantity);  //WVILLALTA05ABR19-+
                                ExternalPurchLine.Amount := PurchaseLine.Amount;
                                ExternalPurchLine."Amount Including VAT" := PurchaseLine."Amount Including VAT";
                                ExternalPurchLine.Received := FALSE;
                                ExternalPurchLine.TransferComplete := FALSE;
                                ExternalPurchLine."Consolidado No." := PurchaseHeader."FSN Consolidate No.";
                                ExternalPurchLine.Rapidito := (PurchaseHeader."LSC Retail Purch Src Filter" = PurchaseHeader."LSC Retail Purch Src Filter"::" ");
                                ExternalPurchLine.INSERT(TRUE);
                                recepPurch."FSN Shared with EBS" := true;
                                recepPurch.Modify();
                                PurchaseHeader."FSN Shared with EBS" := true;
                                PurchaseHeader.Modify();
                            END ELSE BEGIN
                                recepPurch."FSN Shared with EBS" := true;
                                recepPurch.Modify();
                                PurchaseHeader."FSN Shared with EBS" := true;
                                PurchaseHeader.Modify();
                            END;
                    until recepPurch.Next() = 0;
            UNTIL PurchaseLine.NEXT = 0;
            //Validar las lineas pendientes
            PurchaseHeader."FSN Outstanding Lines" := PurchHeaderOutQtyReceived(PurchaseHeader);
            PurchaseHeader.Modify();
        END;

    end;
    //PurchaseV67
    procedure PurchHeaderOutQtyReceived(PurchHdr: Record "Purchase Header"): Integer
    var
        PurchaseLine: Record "Purchase Line";
        CountingHeaderVal: Record "LSC P/R Counting Header";
        LSCPickingReceivinglines: Record "LSC Picking / Receiving lines";
        PurchLineAlternative: Dictionary of [Code[20], Decimal];
        ItemNo: Code[20];
    begin
        PurchaseLine.Reset();
        PurchaseLine.SetRange("Document Type", PurchHdr."Document Type");
        PurchaseLine.SetRange("Document No.", PurchHdr."No.");
        if PurchaseLine.FindSet() then begin
            repeat
                if (PurchaseLine.Quantity - PurchaseLine."Quantity Received") <> 0 then
                    if not PurchLineAlternative.ContainsKey(PurchaseLine."No.") then
                        PurchLineAlternative.Add(PurchaseLine."No.", PurchaseLine.Quantity)
                    else
                        PurchLineAlternative.Set(PurchaseLine."No.", PurchLineAlternative.Get(PurchaseLine."No.") + PurchaseLine.Quantity);
            until PurchaseLine.Next() = 0;
        end;
        if PurchLineAlternative.Count > 0 then begin
            CountingHeaderVal.Reset();
            CountingHeaderVal.SetRange("Reference No.", PurchHdr."No.");
            CountingHeaderVal.SetRange("FSN Authorized Reception", true);
            CountingHeaderVal.SetRange("FSN Shared with EBS", true);
            if CountingHeaderVal.FindFirst() then
                repeat
                    LSCPickingReceivinglines.Reset();
                    LSCPickingReceivinglines.SetRange("Document No.", CountingHeaderVal."No.");
                    LSCPickingReceivinglines.SetFilter("Quantity", '<>0');
                    if LSCPickingReceivinglines.FindFirst() then
                        repeat begin
                            if PurchLineAlternative.ContainsKey(LSCPickingReceivinglines."Item No.") then
                                PurchLineAlternative.Set(LSCPickingReceivinglines."Item No.", PurchLineAlternative.Get(LSCPickingReceivinglines."Item No.") - LSCPickingReceivinglines.Quantity);
                        end until LSCPickingReceivinglines.Next() = 0;
                until CountingHeaderVal.Next() = 0;
        end;
        if PurchLineAlternative.Count > 0 then
            foreach ItemNo in PurchLineAlternative.Keys do begin
                if PurchLineAlternative.Get(ItemNo) = 0 then
                    PurchLineAlternative.Remove(ItemNo);
            end;
        if PurchLineAlternative.Count > 0 then
            exit(PurchLineAlternative.Count())
        else
            exit(0);
    end;



    procedure RecepComMinApi(No: Code[20]): Text
    var
        external: Codeunit "FSN External Purch. Manager";
        Response: Integer;
    begin
        exit(external.ProcessRecepComMin(2, 1, No));
    end;

    procedure RecepComMinApiTest(No: Code[20]): Text
    var
        json: JsonObject;
        MessResponse: Text;
    begin
        json.Add('Status', 0);
        json.Add('LastError', 'Error');
        json.WriteTo(MessResponse);
        exit(MessResponse);
    end;

    procedure RevCost(Scheduler: Record "LSC Scheduler Job Header")
    var
        ItemLedgEntry: Record "Item Ledger Entry";
        ValueEntry: Record "Value Entry";
        ItemApplnEntry: Record "Item Application Entry";
        AvgCostAdjmtEntryPoint: Record "Avg. Cost Adjmt. Entry Point";
        InvtSetup: Record "Inventory Setup";
        InvtAdjmt: Codeunit "Inventory Adjustment";
        FSNInvtAdjmt: Codeunit "FSN Inventory Adjustment";
        Item: Record Item;
        FilterItemAdjmt: Text;
        FilterItemSplit: list of [Text];
        FilterItemNo: Text;
        StartTime: DateTime;
        EndTime: DateTime;
        ExecutionTime: Duration;
        rec2: Codeunit "Change Average Cost Setting";
        TempAvgCostAdjmtEntryPoint: Record "Avg. Cost Adjmt. Entry Point" temporary;

    begin
        // Capturar el tiempo de inicio
        StartTime := CURRENTDATETIME;

        ItemApplnEntry.LockTable();
        if not ItemApplnEntry.FindLast then
            exit;

        ItemLedgEntry.LockTable();
        if not ItemLedgEntry.FindLast then
            exit;

        AvgCostAdjmtEntryPoint.LockTable();
        if AvgCostAdjmtEntryPoint.FindLast then;

        ValueEntry.LockTable();
        if not ValueEntry.FindLast then
            exit;

        //Por Rangos
        if Scheduler.Boolean then begin
            case Scheduler.Integer of
                1:
                    FilterItemAdjmt := GetItemCostAdjmt(1, 1, true, Scheduler.Date);
                2:
                    FilterItemAdjmt := GetItemCostAdjmtDesc;
                3:
                    FilterItemAdjmt := GetItemCostAdjmtValueDesc;
                else
                    FilterItemAdjmt := GetItemCostAdjmt(1, Scheduler.Integer, false, Scheduler.Date);
            end;
        end else
            FilterItemAdjmt := Scheduler.Text;

        if FilterItemAdjmt = '' then
            Message('No hay items para ajustar')
        else begin
            InvtSetup.Get();
            Item.Reset();
            FilterItemSplit := FilterItemAdjmt.Split('|');
            foreach FilterItemNo in FilterItemSplit do begin

                if Scheduler."Ending Time" < Time then
                    break;
                Item.SetFilter("No.", FilterItemNo);
                Item.SetRange("Cost is Adjusted", FALSE);
                if Item.FindFirst then begin
                    FSNInvtAdjmt.SetProperties(false, InvtSetup."Automatic Cost Posting");
                    FSNInvtAdjmt.SetFilterItem(Item);
                    FSNInvtAdjmt.MakeMultiLevelAdjmt;
                    Commit;
                    //FSNInvtAdjmt.CollectAvgCostAdjmtEntryPointToUpdate(TempAvgCostAdjmtEntryPoint, Item."No.");
                end;
            end;
        end;
        // Capturar el tiempo de finalización
        EndTime := CURRENTDATETIME;

        // Calcular el tiempo de ejecución
        ExecutionTime := EndTime - StartTime;

        // Mostrar el tiempo de ejecución
        Message('Tiempo de ejecución: %1', FORMAT(ExecutionTime));
    end;


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Inventory Adjustment", 'OnBeforeOpenWindow', '', true, true)]
    local procedure "Inventory Adjustment_OnBeforeOpenWindow"(var IsHandled: Boolean)
    begin
        IsHandled := true;
    end;


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Inventory Adjustment", 'OnBeforeUpdateWindow', '', true, true)]
    local procedure "Inventory Adjustment_OnBeforeUpdateWindow"(var IsHandled: Boolean)
    begin
        IsHandled := true;
    end;

    local procedure GetItemCostAdjmt(NumberStart: Integer; NumberEnd: Integer; byDateB: Boolean; ByDate: Date): Text
    var
        SqlConnection: DotNet SqlConnection;
        SqlCommand: DotNet SqlCommand;
        SqlDataReader: DotNet SqlDataReader;
        ConnectionString: Text[150];
        SqlString: Text;
        lTextConn: Label 'Data Source=%1;Initial Catalog=%2;Integrated Security=false; User ID=%3;Password=%4;';
        lTextSql: Label 'WITH AvgCostAdjmtEntryPointCounts AS (SELECT a.No_ ,count(b.[Item No_])[Lineas Value Entry] ,(SELECT COUNT(c.[Item no_]) FROM dbo.[FASANI$Avg_ Cost Adjmt_ Entry Point$437dbf0e-84ff-417a-965d-ed2bb9650972] c WHERE c.[Cost Is Adjusted] = 0 AND c.[Item No_] = a.[No_])[Lineas sin valorizar] ,(SELECT COUNT(c.[Item no_]) FROM dbo.[FASANI$Avg_ Cost Adjmt_ Entry Point$437dbf0e-84ff-417a-965d-ed2bb9650972] c WHERE c.[Item No_] = a.[No_])[Lineas costo ajustado total] FROM dbo.[FASANI$Item$437dbf0e-84ff-417a-965d-ed2bb9650972] a JOIN dbo.[FASANI$Value Entry$437dbf0e-84ff-417a-965d-ed2bb9650972] b ON a.No_ = b.[Item No_] JOIN [FASANI$Item$5ecfc871-5d82-43f1-9c54-59685e82318d] c on a.[No_]=c.[No_] and c.[LSC Division Code] in (''01'',''02'') GROUP BY a.No_ ,a.[Allow Online Adjustment] HAVING count(b.[Item No_])>=%1 AND count(b.[Item No_])<=%2 ) SELECT a.No_  FROM AvgCostAdjmtEntryPointCounts a WHERE NOT (a.[Lineas sin valorizar]=0 and a.[Lineas costo ajustado total]=0) AND NOT (a.[Lineas sin valorizar]=0) ORDER BY a.[Lineas sin valorizar] asc,a.No_,a.[Lineas Value Entry]  asc';
        lTextSql2: Text;
        FilterItemAdjmt: Text;
        DateText: Text;
    begin
        DateText := Format(ByDate, 10, '<Year4>-<Day,2>-<Month,2>');
        lTextSql2 := 'WITH AvgCostAdjmtEntryPointCounts AS (SELECT a.No_ , count(b.[Item No_])[Lineas Value Entry] , (SELECT COUNT(c.[Item no_]) FROM dbo.[FASANI$Avg_ Cost Adjmt_ Entry Point$437dbf0e-84ff-417a-965d-ed2bb9650972] c WHERE c.[Cost Is Adjusted] = 0 AND c.[Item No_] = a.[No_])[Lineas sin valorizar] FROM dbo.[FASANI$Item$437dbf0e-84ff-417a-965d-ed2bb9650972] a JOIN dbo.[FASANI$Value Entry$437dbf0e-84ff-417a-965d-ed2bb9650972] b ON a.No_ = b.[Item No_] JOIN [FASANI$Item$5ecfc871-5d82-43f1-9c54-59685e82318d] c on a.[No_]=c.[No_] and c.[LSC Division Code] in (''01'',''02'') GROUP BY a.No_ ,a.[Allow Online Adjustment] ) select [Item No_],MIN([Valuation Date]) fecha ,d.[Lineas sin valorizar],d.[Lineas Value Entry] from [FASANI$Avg_ Cost Adjmt_ Entry Point$437dbf0e-84ff-417a-965d-ed2bb9650972] a JOIN [FASANI$Item$5ecfc871-5d82-43f1-9c54-59685e82318d] c on a.[Item No_]=c.[No_] and c.[LSC Division Code] in (''01'',''02'') JOIN AvgCostAdjmtEntryPointCounts d on d.No_=a.[Item No_] where [Cost Is Adjusted]=0 and [Valuation Date]=''' + DateText + ' 00:00:00.000'' group by [Item No_],d.[Lineas sin valorizar],d.[Lineas Value Entry] ORDER BY d.[Lineas sin valorizar] asc';
        ConnectionString := STRSUBSTNO(lTextConn, 'FSNSRV02\BCENTRAL', 'BCENTRAL', 'consulta', 'consulta$01');
        SqlConnection := SqlConnection.SqlConnection(ConnectionString);
        if not byDateB then
            SqlString := STRSUBSTNO(lTextSql, NumberStart, NumberEnd)
        else
            SqlString := STRSUBSTNO(lTextSql2, NumberStart, NumberEnd);
        SqlConnection.Open();
        SqlCommand := SqlConnection.CreateCommand();
        SqlCommand.CommandText := SqlString;
        SqlDataReader := SqlCommand.ExecuteReader();
        while SqlDataReader.Read() do begin
            if FilterItemAdjmt <> '' then
                FilterItemAdjmt := FilterItemAdjmt + '|';
            FilterItemAdjmt := FilterItemAdjmt + SqlDataReader.GetString(0);
        end;
        SqlConnection.Close();
        exit(FilterItemAdjmt);
    end;

    local procedure GetItemCostAdjmtDesc(): Text
    var
        SqlConnection: DotNet SqlConnection;
        SqlCommand: DotNet SqlCommand;
        SqlDataReader: DotNet SqlDataReader;
        ConnectionString: Text[150];
        SqlString: Text;
        lTextConn: Label 'Data Source=%1;Initial Catalog=%2;Integrated Security=false; User ID=%3;Password=%4;';
        FilterItemAdjmt: Text;
        DateText: Text;
    begin
        ConnectionString := STRSUBSTNO(lTextConn, 'FSNSRV02\BCENTRAL', 'BCENTRAL', 'consulta', 'consulta$01');
        SqlConnection := SqlConnection.SqlConnection(ConnectionString);
        SqlString := 'WITH PrimerasFechas AS (SELECT [Item No_], MIN([Valuation Date]) [Value Date] from dbo.[FASANI$Avg_ Cost Adjmt_ Entry Point$437dbf0e-84ff-417a-965d-ed2bb9650972] a with (nolock) WHERE [Cost Is Adjusted] = 0 GROUP BY [Item No_] ), ListaProductos AS (SELECT a.[Item No_], COUNT(*) [Lineas Pendientes], b.[Value Date], (SELECT COUNT(1) FROM dbo.[FASANI$Value Entry$437dbf0e-84ff-417a-965d-ed2bb9650972]  bb with (nolock) WHERE bb.[Item No_]=a.[Item No_]) [Lineas Value] FROM dbo.[FASANI$Avg_ Cost Adjmt_ Entry Point$437dbf0e-84ff-417a-965d-ed2bb9650972] a with (nolock) INNER JOIN [FASANI$Item$5ecfc871-5d82-43f1-9c54-59685e82318d] c with (nolock) on a.[Item No_]=c.[No_] and c.[LSC Division Code] in (''01'',''02'') INNER JOIN PrimerasFechas b on b.[Item No_]=a.[Item No_] WHERE [Cost Is Adjusted] = 0 GROUP BY a.[Item No_],b.[Value Date]) SELECT TOP 1000 a.[Item No_] FROM ListaProductos a ORDER BY a.[Lineas Pendientes] ASC, a.[Item No_] ASC';
        SqlConnection.Open();
        SqlCommand := SqlConnection.CreateCommand();
        SqlCommand.CommandText := SqlString;
        SqlDataReader := SqlCommand.ExecuteReader();
        while SqlDataReader.Read() do begin
            if FilterItemAdjmt <> '' then
                FilterItemAdjmt := FilterItemAdjmt + '|';
            FilterItemAdjmt := FilterItemAdjmt + SqlDataReader.GetString(0);
        end;
        SqlConnection.Close();
        exit(FilterItemAdjmt);
    end;

    local procedure GetItemCostAdjmtValueDesc(): Text
    var
        SqlConnection: DotNet SqlConnection;
        SqlCommand: DotNet SqlCommand;
        SqlDataReader: DotNet SqlDataReader;
        ConnectionString: Text[150];
        SqlString: Text;
        lTextConn: Label 'Data Source=%1;Initial Catalog=%2;Integrated Security=false; User ID=%3;Password=%4;';
        FilterItemAdjmt: Text;
        DateText: Text;
    begin
        ConnectionString := STRSUBSTNO(lTextConn, 'FSNSRV02\BCENTRAL', 'BCENTRAL', 'consulta', 'consulta$01');
        SqlConnection := SqlConnection.SqlConnection(ConnectionString);
        SqlString := 'WITH PrimerasFechas AS (SELECT [Item No_], MIN([Valuation Date]) [Value Date] from dbo.[FASANI$Avg_ Cost Adjmt_ Entry Point$437dbf0e-84ff-417a-965d-ed2bb9650972] a with (nolock) WHERE [Cost Is Adjusted] = 0 GROUP BY [Item No_] ), ListaProductos AS (SELECT a.[Item No_], COUNT(*) [Lineas Pendientes], b.[Value Date], (SELECT COUNT(1) FROM dbo.[FASANI$Value Entry$437dbf0e-84ff-417a-965d-ed2bb9650972]  bb with (nolock) WHERE bb.[Item No_]=a.[Item No_]) [Lineas Value] FROM dbo.[FASANI$Avg_ Cost Adjmt_ Entry Point$437dbf0e-84ff-417a-965d-ed2bb9650972] a with (nolock) INNER JOIN [FASANI$Item$5ecfc871-5d82-43f1-9c54-59685e82318d] c with (nolock) on a.[Item No_]=c.[No_] and c.[LSC Division Code] in (''01'',''02'') INNER JOIN PrimerasFechas b on b.[Item No_]=a.[Item No_] WHERE [Cost Is Adjusted] = 0 GROUP BY a.[Item No_],b.[Value Date]) SELECT TOP 1000 a.[Item No_] FROM ListaProductos a ORDER BY a.[Lineas Value] asc,a.[Lineas Pendientes] ASC';
        SqlConnection.Open();
        SqlCommand := SqlConnection.CreateCommand();
        SqlCommand.CommandText := SqlString;
        SqlDataReader := SqlCommand.ExecuteReader();
        while SqlDataReader.Read() do begin
            if FilterItemAdjmt <> '' then
                FilterItemAdjmt := FilterItemAdjmt + '|';
            FilterItemAdjmt := FilterItemAdjmt + SqlDataReader.GetString(0);
        end;
        SqlConnection.Close();
        exit(FilterItemAdjmt);
    end;

}


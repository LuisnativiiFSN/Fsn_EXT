codeunit 50085 "FSN Picking/Receiving - Post"
{
    /// <summary>
    /// Codeunit Picking/Receiving - Post (ID 10001315).
    /// </summary>
    Permissions = TableData "G/L Entry" = rimd;
    TableNo = "LSC P/R Counting Header";

    trigger OnRun()
    begin
        CountingHeader.Copy(Rec);
        TransferSplitAllowed := false;
        case CountingHeader.Type of
            CountingHeader.Type::Scanned, CountingHeader.Type::Leading:
                Code_Scanning;
            CountingHeader.Type::"Difference Entered":
                Code_Difference;
        end;
        Rec := CountingHeader;
    end;

    var
        ReceivinglinesTemp: array[2] of Record "LSC Picking / Receiving lines" temporary;
        CountingHeader: Record "LSC P/R Counting Header";
        CountingLines: Record "LSC Picking / Receiving lines";
        "Pic/RecSetup": Record "LSC Inventory Management Setup";
        PurchOrder: Record "Purchase Header";
        SalesOrder: Record "Sales Header";
        TransferHeader: Record "Transfer Header";
        PostSetup: Record "LSC P/R Counting Posting Setup";
        Item: Record Item;
        ItemJnlLine: Record "Item Journal Line";
        PurchLine: Record "Purchase Line";
        TransLines: Record "Transfer Line";
        PostedHeader: Record "LSC Posted P/R Counting Header";
        PostedLines: Record "LSC Posted P/R Counting Lines";
        LogRecord: Record "LSC Receiving/Picking Logfile";
        PickingHeader: Record "LSC P/R Counting Header";
        PickingLines: Record "LSC Picking / Receiving lines";
        PurchPaySetup: Record "Purchases & Payables Setup";
        ASNPurchaseOrderLine_G: Record "Purchase Line";
        PurchaseHeaderTEMP: Record "Purchase Header" temporary;
        PickingReceivingConfirm: Codeunit "LSC Picking/Receiving Confirm";
        NoSeriesMgt: Codeunit NoSeriesManagement;
        BatchPosting: Codeunit "LSC Batch Posting";
        CurrDocumentPostingDate: Date;
        SourceNo: Code[20];
        LogNo: Code[20];
        NewPostedReceiptNo: Code[20];
        ASNNewVersionNo: Integer;
        SetStatusPostMethod: Integer;
        SourceLineNo: Integer;
        StatusPost: Integer;
        LogLineNo: Integer;
        LogTableId: Integer;
        SourceType: Option " ",Customer,Vendor,Item;
        LogDocType: Option Quote,"Order",Invoice,"Credit Memo","Blanket Order","Return Order","Transfer Out","Transfer In";
        PickReturnOrder: Boolean;
        TransferSplitAllowed: Boolean;
        ASNDocumentInUse_G: Boolean;
        CalledFromASNDocLineDiff: Boolean;
        Text004: Label 'Has to be confirmed before posting.';
        Text006: Label 'Item tracking %1 mismatch for item %2';
        Text007: Label 'Item reservation %1 mismatch for item %2';
        Text010: Label 'Closed';
        Text011: Label 'Part. receipt,Closed';
        Text012: Label 'Part. shipment,Closed';
        Text013: Label 'Vendor Invoice No. %1 already exists for Vendor %2. See Purchase Order %3.';

    local procedure Code_Scanning()
    var
        ReturnOrder: Record "Purchase Header";
        ReturnOrderLine: Record "Purchase Line";
        ASNDeliveryDocumentLine_L: Record "LSC ASN Delivery Document Line";
        ASNDeliveryDocument_L: Record "LSC ASN Delivery Document";
        PostedASNDeliveryDocument_L: Record "LSC Posted ASN Del. Document";
        PostedASNDeliveryDocLine_L: Record "LSC Posted ASN Del. Doc. Line";
        PickingReceivingConfirm: Codeunit "LSC Picking/Receiving Confirm";
        NothingToPostTxt: Label 'Nothing to post';
    begin
        PurchPaySetup.Get;
        "Pic/RecSetup".Get;

        if CountingHeader.Status = CountingHeader.Status::"Not Confirmed" then
            Error(Text004);

        PickingReceivingConfirm.CheckSerialAndLotNos(CountingHeader);

        if CountingHeader.Receiving <> CountingHeader.Receiving::"ASN Delivery Document" then begin
            CompressReceivingLines(CountingHeader);
            CountingHeader.Get(CountingHeader."No.");
        end;

        if SetStatusPostMethod > 0 then
            StatusPost := SetStatusPostMethod
        else
            StatusPost := 2; // Partial

        if StatusPost = 0 then
            exit;

        case StatusPost of
            1:
                CountingHeader."Retail Status" := CountingHeader."Retail Status"::"Part. receipt";
            2:
                CountingHeader."Retail Status" := CountingHeader."Retail Status"::"Closed - ok";
        end;

        CountingHeader.TestField("Counted Date");
        CountingHeader.TestField("Reference No.");

        CountingLines.SetRange("Document No.", CountingHeader."No.");
        if CountingLines.IsEmpty then
            Error(NothingToPostTxt);

        if StatusPost = 1 then begin
            CountingLines.SetRange(Quantity, 0);
            CountingLines.DeleteAll;
            CountingLines.SetRange(Quantity);
        end;

        if FindReturnOrder(ReturnOrder) then begin
            ReturnOrderLine.SetRange("Document Type", ReturnOrder."Document Type");
            ReturnOrderLine.SetRange("Document No.", ReturnOrder."No.");
            ReturnOrderLine.DeleteAll;
        end;

        if CountingHeader."Posted No." = '' then begin
            CountingHeader.TestField("Posted Number Series");
            if CountingHeader."Number Series" = CountingHeader."Posted Number Series" then
                CountingHeader."Posted No." := CountingHeader."No."
            else
                CountingHeader."Posted No." := NoSeriesMgt.GetNextNo(CountingHeader."Posted Number Series", WorkDate, true);
            CountingHeader.Modify;
            Commit;
        end;

        GetSourceHeader;

        case CountingHeader."Counting Type" of
            CountingHeader."Counting Type"::Receiving:
                PostSetup.SetRange("Counting Type", PostSetup."Counting Type"::Receiving);
            CountingHeader."Counting Type"::Picking:
                PostSetup.SetRange("Counting Type", PostSetup."Counting Type"::Picking);
        end;

        if "Pic/RecSetup"."Receiving Posting" = "Pic/RecSetup"."Receiving Posting"::"Full Posting" then
            if CountingHeader.Receiving in [CountingHeader.Receiving::"Purchase Order", CountingHeader.Receiving::"Purchase Order(create)"] then
                CheckVendorInvoiceNo(CountingHeader, CountingHeader."Reference No.");
        PurchaseHeaderTEMP.Reset;
        PurchaseHeaderTEMP.DeleteAll;
        if CountingLines.FindSet then
            SourceLineNo := GetSourceLineNo;
        repeat
            ASNDocumentInUse_G := false;
            if (CountingHeader."Counting Type" = CountingHeader."Counting Type"::Receiving) and (CountingHeader.Receiving = CountingHeader.Receiving::"ASN Delivery Document") and
               (CountingLines."ASN Delivery Doc. Line No." <> 0) and (CountingLines.Quantity <> 0)
            then
                if ASNDeliveryDocumentLine_L.Get(CountingHeader."Reference No.", CountingLines."ASN Delivery Doc. Line No.") then begin
                    ASNPurchaseOrderLine_G."Document Type" := ASNPurchaseOrderLine_G."Document Type"::Order;
                    if ASNPurchaseOrderLine_G.Get(ASNPurchaseOrderLine_G."Document Type", ASNDeliveryDocumentLine_L."Purchase Order No.",
                       ASNDeliveryDocumentLine_L."Purchase Order Line No.")
                    then begin
                        ASNDocumentInUse_G := true;
                        if not PurchaseHeaderTEMP.Get(ASNPurchaseOrderLine_G."Document Type", ASNPurchaseOrderLine_G."Document No.") then begin
                            PurchaseHeaderTEMP."Document Type" := ASNPurchaseOrderLine_G."Document Type";
                            PurchaseHeaderTEMP."No." := ASNPurchaseOrderLine_G."Document No.";
                            PurchaseHeaderTEMP.Insert;
                            if "Pic/RecSetup"."Receiving Posting" = "Pic/RecSetup"."Receiving Posting"::"Full Posting" then
                                CheckVendorInvoiceNo(CountingHeader, PurchaseHeaderTEMP."No.");
                        end;
                    end;
                end;
            if not Item.Get(CountingLines."Item No.") then
                Item.Init;
            if CountingLines."Qty. per Unit of Measure" = 0 then
                CountingLines."Qty. per Unit of Measure" := 1;
            case CountingLines."Posting Action" of
                CountingLines."Posting Action"::"To location":
                    if CountingHeader.Receiving = CountingHeader.Receiving::"Purchase Order(create)" then
                        AddToOrder
                    else
                        ToLocation;
                PostSetup."Posting Action"::Return:
                    ReturnQuantity;
                PostSetup."Posting Action"::"Adjust Order":
                    AddToOrder;
                else
                    if ActionIsCreateDoc(CountingHeader) then
                        UpdateSourceLine(CountingLines."Quantity (base)", CountingLines."Difference (base)", CountingLines)
                    else
                        UpdateSourceLine(CountingLines."Quantity (base)", 0, CountingLines);
            end;
            case StatusPost of
                1:
                    if CountingLines.Status = CountingLines.Status::"Not enough" then begin
                        CountingLines.Status := CountingLines.Status::" ";
                        CountingLines.Difference := 0;
                        CountingLines."Difference (base)" := 0;
                    end;
                2:
                    DefineCloseStatus;
            end;
            if CountingLines."Posting Action" = CountingLines."Posting Action"::Return then
                CountingLines.Status := CountingLines.Status::Return;
        until CountingLines.Next = 0;

        UpdateSourceStatus;
        PostSourceDocument;

        PostedHeader.Init;
        PostedHeader.TransferFields(CountingHeader);
        PostedHeader."No." := CountingHeader."Posted No.";
        if not PostedHeader.Insert then
            PostedHeader.Modify;

        if CountingLines.FindSet then
            repeat
                PostedLines.Init;
                PostedLines.TransferFields(CountingLines);
                PostedLines."Document No." := PostedHeader."No.";
                if not PostedLines.Insert then
                    PostedLines.Modify;
            until CountingLines.Next = 0;

        if (CountingHeader."Counting Type" = CountingHeader."Counting Type"::Receiving) and (CountingHeader.Receiving = CountingHeader.Receiving::"ASN Delivery Document") then begin
            LogRecord.Reset;
            LogRecord.SetRange("Table ID", Database::"LSC ASN Delivery Document");
            LogRecord.SetRange("Document Type", LogRecord."Document Type"::Order);
            LogRecord.SetRange("No.", CountingHeader."Reference No.");
            if LogRecord.FindLast then
                LogLineNo := LogRecord."Line No.";
            LogRecord.Init;
            LogRecord."Table ID" := Database::"LSC ASN Delivery Document";
            LogRecord."Document Type" := LogRecord."Document Type"::Order;
            LogRecord."No." := CountingHeader."Reference No.";
            LogLineNo := LogLineNo + 10000;
            LogRecord."Line No." := LogLineNo;
            LogRecord.Status := LogRecord.Status::"Closed - ok";
            LogRecord."User ID" := UserId;
            LogRecord.Date := Today;
            LogRecord.Time := Time;
            LogRecord.Insert;
            PurchaseHeaderTEMP.Reset;
            if PurchaseHeaderTEMP.FindSet then
                repeat
                    LogRecord.Reset;
                    LogRecord.SetRange("Table ID", Database::"Purchase Header");
                    LogRecord.SetRange("Document Type", LogRecord."Document Type"::Order);
                    LogRecord.SetRange("No.", PurchaseHeaderTEMP."No.");
                    if LogRecord.FindLast then
                        LogLineNo := LogRecord."Line No.";
                    LogRecord.Init;
                    LogRecord."Table ID" := Database::"Purchase Header";
                    LogRecord."Document Type" := LogRecord."Document Type"::Order;
                    LogRecord."No." := PurchaseHeaderTEMP."No.";
                    LogLineNo := LogLineNo + 10000;
                    LogRecord."Line No." := LogLineNo;
                    LogRecord.Status := CountingHeader."Retail Status";
                    LogRecord."User ID" := UserId;
                    LogRecord.Date := Today;
                    LogRecord.Time := Time;
                    LogRecord.Insert;
                until PurchaseHeaderTEMP.Next = 0;
            if ASNDeliveryDocument_L.Get(CountingHeader."Reference No.") then begin
                PostedASNDeliveryDocument_L.TransferFields(ASNDeliveryDocument_L);
                PostedASNDeliveryDocument_L."Date Posted" := Today;
                PostedASNDeliveryDocument_L."Time Posted" := Time;
                PostedASNDeliveryDocument_L."Posted By" := UserId;
                PostedASNDeliveryDocument_L."Version No." := ASNNewVersionNo;
                PostedASNDeliveryDocument_L.Insert;
                ASNDeliveryDocumentLine_L.SetRange("Document No.", CountingHeader."Reference No.");
                CountingLines.Reset;
                CountingLines.SetRange("Document No.", CountingHeader."No.");
                if ASNDeliveryDocumentLine_L.FindSet then
                    repeat
                        CountingLines.SetRange("Item No.", ASNDeliveryDocumentLine_L."Item No.");
                        CountingLines.SetFilter(Quantity, '<>0');
                        if ASNDeliveryDocumentLine_L."Variant Code" <> '' then
                            CountingLines.SetRange("Variant Code", ASNDeliveryDocumentLine_L."Variant Code");
                        CountingLines.SetRange("ASN Delivery Doc. Line No.", ASNDeliveryDocumentLine_L."Line No.");
                        if CountingLines.FindFirst then begin
                            ASNDeliveryDocumentLine_L."Quantity Posted" := ASNDeliveryDocumentLine_L."Quantity Posted" + CountingLines.Quantity;
                            if ASNDeliveryDocumentLine_L."Quantity Posted" = ASNDeliveryDocumentLine_L."Quantity Delivered" then
                                ASNDeliveryDocumentLine_L.Posted := true;
                            ASNDeliveryDocumentLine_L.Modify;
                        end;
                        PostedASNDeliveryDocLine_L.TransferFields(ASNDeliveryDocumentLine_L);
                        PostedASNDeliveryDocLine_L."Version No." := ASNNewVersionNo;
                        PostedASNDeliveryDocLine_L.Insert;
                    until ASNDeliveryDocumentLine_L.Next = 0;
                CountingLines.Reset;
                CountingLines.SetRange("Document No.", CountingHeader."No.");
                ASNDeliveryDocument_L.Reset;
                ASNDeliveryDocument_L.SetRange("Document No.", CountingHeader."Reference No.");
                ASNDeliveryDocumentLine_L.SetRange(Posted, false);
                if ASNDeliveryDocumentLine_L.IsEmpty then
                    ASNDeliveryDocument_L.Delete(true);
            end;
        end
        else begin
            LogRecord.Init;
            LogRecord."Table ID" := LogTableId;
            LogRecord."Document Type" := LogDocType;
            LogRecord."No." := LogNo;
            LogRecord."Line No." := LogLineNo + 10000;
            LogRecord.Status := CountingHeader."Retail Status";
            LogRecord."User ID" := UserId;
            LogRecord.Date := WorkDate;
            LogRecord.Time := Time;
            LogRecord.Insert;
        end;

        CountingLines.DeleteAll;
        CountingHeader.Delete;
    end;

    local procedure Code_Difference()
    var
        ReturnOrder: Record "Purchase Header";
        ReturnOrderLine: Record "Purchase Line";
    begin
        PurchPaySetup.Get;
        "Pic/RecSetup".Get;

        if CountingHeader.Status = CountingHeader.Status::"Not Confirmed" then
            Error(Text004);

        case CountingHeader."Counting Type" of
            CountingHeader."Counting Type"::Receiving:
                if "Pic/RecSetup"."Receiving Post Method" = "Pic/RecSetup"."Receiving Post Method"::"Close confirmation" then
                    case CountingHeader."Retail Status" of
                        CountingHeader."Retail Status"::"Part. receipt":
                            StatusPost := StrMenu(Text011, 1);
                        else
                            StatusPost := StrMenu(Text011, 2);
                    end
                else
                    if (CountingHeader.Status = CountingHeader.Status::Ok) then
                        StatusPost := 2
                    else
                        StatusPost := 1;
            CountingHeader."Counting Type"::Picking:
                case CountingHeader."Retail Status" of
                    CountingHeader."Retail Status"::"Part. receipt":
                        StatusPost := StrMenu(Text012, 1);
                    else
                        StatusPost := StrMenu(Text012, 2);
                end;
        end;

        if StatusPost = 0 then
            exit;

        case StatusPost of
            1:
                CountingHeader."Retail Status" := CountingHeader."Retail Status"::"Part. receipt";
            2:
                CountingHeader."Retail Status" := CountingHeader."Retail Status"::"Closed - ok";
        end;

        CountingHeader.TestField("Counted Date");
        CountingHeader.TestField("Reference No.");

        if StatusPost = 1 then begin
            CountingLines.SetRange("Qty. Difference", 0);
            CountingLines.DeleteAll;
            CountingLines.SetRange("Qty. Difference");
            CountingLines.SetRange("Status Difference", CountingLines."Status Difference"::" ");
            CountingLines.DeleteAll;
            CountingLines.SetRange("Status Difference");
        end;

        if FindReturnOrder(ReturnOrder) then begin
            ReturnOrderLine.SetRange("Document Type", ReturnOrder."Document Type");
            ReturnOrderLine.SetRange("Document No.", ReturnOrder."No.");
            ReturnOrderLine.DeleteAll;
        end;

        if CountingHeader."Posted No." = '' then begin
            CountingHeader.TestField("Posted Number Series");
            if CountingHeader."Number Series" = CountingHeader."Posted Number Series" then
                CountingHeader."Posted No." := CountingHeader."No."
            else
                CountingHeader."Posted No." := NoSeriesMgt.GetNextNo(CountingHeader."Posted Number Series", WorkDate, true);
            CountingHeader.Modify(true);
            Commit;
        end;

        PostedHeader.Init;
        PostedHeader.TransferFields(CountingHeader);
        PostedHeader."No." := CountingHeader."Posted No.";
        if not PostedHeader.Insert then
            PostedHeader.Modify(true);

        GetSourceHeader;

        case CountingHeader."Counting Type" of
            CountingHeader."Counting Type"::Receiving:
                PostSetup.SetRange("Counting Type", PostSetup."Counting Type"::Receiving);
            CountingHeader."Counting Type"::Picking:
                PostSetup.SetRange("Counting Type", PostSetup."Counting Type"::Picking);
        end;

        case CountingHeader."Counting Type" of
            CountingHeader."Counting Type"::Receiving:
                case CountingHeader.Receiving of
                    CountingHeader.Receiving::"Purchase Order", CountingHeader.Receiving::"Purchase Order(create)":
                        ProcessPurchDocLines_Diff(CountingHeader);
                    CountingHeader.Receiving::"Sales Return Order":
                        ProcessSalesDocLines_Diff(CountingHeader);
                    CountingHeader.Receiving::"Transfer In":
                        ProcessTransDocLines_Diff(CountingHeader);
                    CountingHeader.Receiving::"ASN Delivery Document":
                        ProcessASNDeliveryDocLines_Diff(CountingHeader);
                end;
            CountingHeader."Counting Type"::Picking:
                case CountingHeader.Picking of
                    CountingHeader.Picking::"Purchase Return Order", CountingHeader.Picking::"Purchase Return Order (create)":
                        ProcessPurchDocLines_Diff(CountingHeader);
                    CountingHeader.Picking::"Sales Order", CountingHeader.Picking::"Sales Order (create)":
                        ProcessSalesDocLines_Diff(CountingHeader);
                    CountingHeader.Picking::"Transfer Out", CountingHeader.Picking::"Transfer Out (create)":
                        ProcessTransDocLines_Diff(CountingHeader);
                end;
        end;

        UpdateSourceStatus;
        PostSourceDocument;

        LogRecord.Reset;
        LogRecord.SetRange("Table ID", LogTableId);
        LogRecord.SetRange("Document Type", LogDocType);
        LogRecord.SetRange("No.", LogNo);
        if LogRecord.FindLast then
            LogLineNo := LogRecord."Line No.";

        LogRecord.Init;
        LogRecord."Table ID" := LogTableId;
        LogRecord."Document Type" := LogDocType;
        LogRecord."No." := LogNo;
        LogRecord."Line No." := LogLineNo + 10000;
        LogRecord.Status := CountingHeader."Retail Status";
        LogRecord."User ID" := UserId;
        LogRecord.Date := WorkDate;
        LogRecord.Time := Time;
        LogRecord.Insert;
        CountingLines.DeleteAll;
        CountingHeader.Delete;
    end;

    local procedure GetSourceHeader()
    begin
        case CountingHeader."Counting Type" of
            CountingHeader."Counting Type"::Receiving:
                case CountingHeader.Receiving of
                    CountingHeader.Receiving::"Purchase Order":
                        GetSourcePurchase(0);
                    CountingHeader.Receiving::"Purchase Order(create)":
                        CreatePurchOrder;
                    CountingHeader.Receiving::"Sales Return Order":
                        GetSourceSales(1);
                    CountingHeader.Receiving::"Transfer In":
                        GetSourceTransfer(1);
                    CountingHeader.Receiving::"ASN Delivery Document":
                        GetSourceASNDeliveryDocument;
                end;
            CountingHeader."Counting Type"::Picking:
                case CountingHeader.Picking of
                    CountingHeader.Picking::"Sales Order":
                        GetSourceSales(0);
                    CountingHeader.Picking::"Purchase Return Order":
                        GetSourcePurchase(1);
                    CountingHeader.Picking::"Transfer Out":
                        GetSourceTransfer(0);
                    CountingHeader.Picking::"Sales Order (create)":
                        CreateSalesOrder;
                    CountingHeader.Picking::"Purchase Return Order (create)":
                        CreatePurchReturnOrder;
                    CountingHeader.Picking::"Transfer Out (create)":
                        CreateTransferFromOrder;
                end;
        end;
    end;

    local procedure PostItemLedger(TypeOfEntry: Option Purchase,Sale,"Positive Adjmt.","Negative Adjmt.",Transfer,Consumption,Output; LocationCode: Code[10]; QuantityToPost: Decimal)
    var
        ItemJnlPostLine: Codeunit "Item Jnl.-Post Line";
    begin
        ItemJnlLine.Init;
        ItemJnlLine.Validate("Item No.", CountingLines."Item No.");
        ItemJnlLine.Validate("Variant Code", CountingLines."Variant Code");
        if CurrDocumentPostingDate <> 0D then
            ItemJnlLine.Validate("Posting Date", CurrDocumentPostingDate)
        else
            ItemJnlLine.Validate("Posting Date", CountingHeader."Counted Date");
        ItemJnlLine.Validate("Entry Type", TypeOfEntry);
        ItemJnlLine.Validate("Location Code", LocationCode);
        if CountingLines."Unit of Measure Code" <> '' then
            ItemJnlLine.Validate("Unit of Measure Code", CountingLines."Unit of Measure Code");
        ItemJnlLine."Document No." := CountingHeader."Posted No.";
        ItemJnlLine.Validate(Quantity, QuantityToPost);
        ItemJnlLine.Validate("Invoiced Quantity", 0);
        ItemJnlLine."External Document No." := CountingHeader."Reference No.";
        ItemJnlLine.Description := StrSubstNo('%1 %2', Format(CountingHeader."Counting Type"), CountingHeader."Reference No.");
        ItemJnlLine."Reason Code" := CountingLines."Reason Code";
        ItemJnlLine."Return Reason Code" := CountingLines."Reason Code";
        ItemJnlLine."Source No." := SourceNo;
        ItemJnlLine."Source Type" := SourceType;
        ItemJnlLine.Validate("Shortcut Dimension 1 Code", CountingLines."Shortcut Dimension 1 Code");
        case CountingHeader."Counting Type" of
            CountingHeader."Counting Type"::Receiving:
                ItemJnlLine."Source Code" := "Pic/RecSetup"."Receiving Source Code";
            CountingHeader."Counting Type"::Picking:
                ItemJnlLine."Source Code" := "Pic/RecSetup"."Picking Source Code";
        end;
        ItemJnlPostLine.Run(ItemJnlLine);
    end;

    local procedure GetSourceLineNo(): Integer
    begin
        case CountingHeader."Counting Type" of
            CountingHeader."Counting Type"::Receiving:
                case CountingHeader.Receiving of
                    CountingHeader.Receiving::"Purchase Order":
                        exit(GetPurchaseLineNo);
                    CountingHeader.Receiving::"Purchase Order(create)":
                        exit(0);
                    CountingHeader.Receiving::"Sales Return Order":
                        exit(GetSalesLineNo);
                    CountingHeader.Receiving::"Transfer In":
                        exit(GetTransferLineNo);
                end;
            CountingHeader."Counting Type"::Picking:
                case CountingHeader.Picking of
                    CountingHeader.Picking::"Sales Order (create)", CountingHeader.Picking::"Purchase Return Order (create)", CountingHeader.Picking::"Transfer Out (create)":
                        exit(0);
                    CountingHeader.Picking::"Sales Order":
                        exit(GetSalesLineNo);
                    CountingHeader.Picking::"Purchase Return Order":
                        exit(GetPurchaseLineNo);
                    CountingHeader.Picking::"Transfer Out":
                        exit(GetTransferLineNo);
                end;
        end;
    end;

    local procedure UpdateSourceLine(QuantityToReceive: Decimal; QuantityToAdd: Decimal; pPRLineRec: Record "LSC Picking / Receiving lines")
    begin
        case CountingHeader."Counting Type" of
            CountingHeader."Counting Type"::Receiving:
                case CountingHeader.Receiving of
                    CountingHeader.Receiving::"Purchase Order", CountingHeader.Receiving::"Purchase Order(create)", CountingHeader.Receiving::"ASN Delivery Document":
                        UpdatePurchaseLine(0, QuantityToReceive, QuantityToAdd, pPRLineRec);
                    CountingHeader.Receiving::"Sales Return Order":
                        UpdateSalesLine(1, QuantityToReceive, QuantityToAdd, pPRLineRec);
                    CountingHeader.Receiving::"Transfer In":
                        UpdateTransferLine(1, QuantityToReceive, QuantityToAdd, pPRLineRec);
                end;
            CountingHeader."Counting Type"::Picking:
                case CountingHeader.Picking of
                    CountingHeader.Picking::"Sales Order (create)", CountingHeader.Picking::"Sales Order":
                        UpdateSalesLine(0, QuantityToReceive, QuantityToAdd, pPRLineRec);
                    CountingHeader.Picking::"Purchase Return Order", CountingHeader.Picking::"Purchase Return Order (create)":
                        UpdatePurchaseLine(1, QuantityToReceive, QuantityToAdd, pPRLineRec);
                    CountingHeader.Picking::"Transfer Out", CountingHeader.Picking::"Transfer Out (create)":
                        UpdateTransferLine(0, QuantityToReceive, QuantityToAdd, pPRLineRec);
                end;
        end;
    end;

    local procedure ToLocation()
    begin
        CountingLines.TestField("To Location");
        case CountingLines.Status of
            CountingLines.Status::"Too many":
                begin
                    PostItemLedger(ItemJnlLine."Entry Type"::"Positive Adjmt.".AsInteger(), CountingLines."To Location", CountingLines.Difference);
                    UpdateSourceLine(CountingLines."Ordered Qty. (base)", 0, CountingLines);
                end;
            CountingLines.Status::"Not found", CountingLines.Status::"Not ordered":
                PostItemLedger(ItemJnlLine."Entry Type"::"Positive Adjmt.".AsInteger(), CountingLines."To Location", CountingLines.Quantity);
        end;
    end;

    local procedure AddToOrder()
    begin
        UpdateSourceLine(CountingLines."Quantity (base)", CountingLines."Difference (base)", CountingLines);
    end;

    local procedure ReturnQuantity()
    var
        ReturnOrder: Record "Purchase Header";
        ReturnOrderLine: Record "Purchase Line";
        ReturnOrderLine2: Record "Purchase Line";
        lQty: Decimal;
        ReturnLineNo: Integer;
    begin
        if CountingHeader.Picking = CountingHeader.Picking::"Purchase Return Order (create)" then
            exit;

        CountingLines.TestField("Reason Code");
        CountingLines.TestField("To Location");

        UpdateSourceLine(CountingLines."Quantity (base)", CountingLines."Difference (base)", CountingLines);

        if CountingLines.Difference <> 0 then
            lQty := CountingLines.Difference
        else
            lQty := CountingLines.Quantity;

        if CountingHeader."Location Code" <> CountingLines."To Location" then begin
            PostItemLedger(ItemJnlLine."Entry Type"::"Negative Adjmt.".AsInteger(), CountingHeader."Location Code", lQty);
            PostItemLedger(ItemJnlLine."Entry Type"::"Positive Adjmt.".AsInteger(), CountingLines."To Location", lQty);
        end;

        if not FindReturnOrder(ReturnOrder) then begin
            CreateReturnOrder(ReturnOrder, CountingLines."To Location");
            ReturnLineNo := 10000;
        end else begin
            ReturnOrderLine2.SetRange("Document No.", ReturnOrder."No.");
            if ReturnOrderLine2.FindLast() then begin
                ReturnLineNo := ReturnOrderLine2."Line No.";
                ReturnLineNo += 10000;
            end;
        end;

        ReturnOrderLine.Init;
        ReturnOrderLine."Document Type" := ReturnOrder."Document Type";
        ReturnOrderLine."Document No." := ReturnOrder."No.";
        ReturnOrderLine."Line No." := ReturnLineNo;
        ReturnOrderLine.Insert;
        ReturnOrderLine.Validate(Type, ReturnOrderLine.Type::Item);
        ReturnOrderLine.Validate("No.", CountingLines."Item No.");
        ReturnOrderLine.Validate("Variant Code", PurchLine."Variant Code");
        ReturnOrderLine.Description := CopyStr(CountingLines.Description, 1, MaxStrLen(ReturnOrderLine.Description));
        ReturnOrderLine.Validate("Unit of Measure Code", CountingLines."Unit of Measure Code");
        if CountingLines.Difference <> 0 then
            ReturnOrderLine.Validate(Quantity, CountingLines.Difference)
        else
            ReturnOrderLine.Validate(Quantity, CountingLines.Quantity);
        ReturnOrderLine.Validate("Shortcut Dimension 1 Code", CountingLines."Shortcut Dimension 1 Code");
        ReturnOrderLine."Return Reason Code" := CountingLines."Reason Code";
        ReturnOrderLine.Validate("Location Code", CountingLines."To Location");
        ReturnOrderLine.Validate("Direct Unit Cost", PurchLine."Direct Unit Cost");
        ReturnOrderLine.Modify;

        if PickReturnOrder then begin
            PickingLines.Init;
            PickingLines."Document No." := PickingHeader."No.";
            PickingLines."Line No." := ReturnLineNo;
            PickingLines.Validate("Item No.", ReturnOrderLine."No.");
            PickingLines.Validate("Variant Code", ReturnOrderLine."Variant Code");
            PickingLines.Validate(Quantity, ReturnOrderLine.Quantity);
            PickingLines.Validate("Unit of Measure Code", ReturnOrderLine."Unit of Measure Code");
            PickingLines.Insert;
        end;
    end;

    local procedure FindReturnOrder(var ReturnOrder: Record "Purchase Header"): Boolean
    begin
        if CountingHeader."Posted No." = '' then
            exit(false)
        else begin
            ReturnOrder.SetRange("Document Type", ReturnOrder."Document Type"::"Return Order");
            ReturnOrder.SetRange("LSC Reciving/Picking No.", CountingHeader."Posted No.");
            exit(ReturnOrder.FindFirst);
        end;
    end;

    local procedure CreateReturnOrder(var ReturnOrder: Record "Purchase Header"; pLocationCode: Code[10])
    begin
        ReturnOrder.Init;
        ReturnOrder."Document Type" := ReturnOrder."Document Type"::"Return Order";
        ReturnOrder."No." := '';
        ReturnOrder.Insert(true);

        ReturnOrder.Validate("Posting Date", CountingHeader."Counted Date");
        ReturnOrder.Validate("Buy-from Vendor No.", PurchOrder."Buy-from Vendor No.");
        if ReturnOrder."Pay-to Vendor No." <> PurchOrder."Pay-to Vendor No." then
            ReturnOrder.Validate("Pay-to Vendor No.", PurchOrder."Pay-to Vendor No.");
        if ReturnOrder."Currency Code" <> PurchOrder."Currency Code" then
            ReturnOrder.Validate("Currency Code", PurchOrder."Currency Code");
        if CountingHeader."Location Code" <> pLocationCode then
            ReturnOrder.Validate("Location Code", pLocationCode);
        ReturnOrder."LSC Reciving/Picking No." := CountingHeader."Posted No.";
        ReturnOrder.Modify(true);

        PickingHeader.Init;
        PickingHeader."Counting Type" := PickingHeader."Counting Type"::Picking;
        PickingHeader."No." := '';
        PickingHeader.Picking := PickingHeader.Picking::"Purchase Return Order";
        PickingHeader."Location Code" := ReturnOrder."Location Code";
        PickingHeader.Insert(true);
        PickingHeader.Validate("Reference No.", ReturnOrder."No.");
        PickingHeader."Counted Date" := ReturnOrder."Posting Date";
        PickingHeader.Modify;

        PickReturnOrder := true;
    end;

    local procedure DefineCloseStatus()
    begin
        if CountingLines.Status <> CountingLines.Status::" " then
            CountingHeader."Retail Status" := CountingHeader."Retail Status"::"Closed - difference";
    end;

    local procedure UpdateSourceStatus()
    begin
        if StatusPost = 2 then
            CloseOrder;
        case LogTableId of
            Database::"Purchase Header":
                begin
                    PurchOrder."LSC Retail Status" := CountingHeader."Retail Status";
                    if CountingHeader."Counted Date" <> 0D then
                        PurchOrder."Posting Date" := CountingHeader."Counted Date";
                    if CountingHeader."Retail Status" = CountingHeader."Retail Status"::"Closed - ok" then
                        if (PurchOrder."Vendor Invoice No." = '') and (CountingHeader."Vendor Invoice No." <> '') then
                            PurchOrder."Vendor Invoice No." := CountingHeader."Vendor Invoice No.";
                    OnBeforeModifyPurchHeaderInUpdateSourceStatus(CountingHeader, PurchOrder);
                    PurchOrder.Modify;
                end;
            Database::"Sales Header":
                begin
                    if CountingHeader."Counted Date" <> 0D then
                        SalesOrder."Posting Date" := CountingHeader."Counted Date";
                    SalesOrder."LSC Retail Status" := CountingHeader."Retail Status";
                    OnBeforeModifySalesOrderInUpdateSourceStatus(CountingHeader, SalesOrder);
                    SalesOrder.Modify;
                end;
            Database::"Transfer Header":
                begin
                    if CountingHeader."Counted Date" <> 0D then
                        TransferHeader."Posting Date" := CountingHeader."Counted Date";
                    OnBeforeModifyTransferHeaderInUpdateSourceStatus(CountingHeader, TransferHeader);
                    TransferHeader.Modify;
                end;
        end;
    end;

    local procedure CloseOrder()
    var
        PickingReceivingLines: Record "LSC Picking / Receiving lines";
        OutstandingLinesTEMP: Record "LSC Picking / Receiving lines" temporary;
        PurchaseLine: Record "Purchase Line";
        SalesLine: Record "Sales Line";
        TransferLine: Record "Transfer Line";
    begin
        if CountingHeader."Retail Status" = CountingHeader."Retail Status"::"Closed - difference" then
            exit;

        PickingReceivingLines.Reset;
        PickingReceivingLines.SetRange("Document No.", CountingHeader."No.");
        PickingReceivingLines.SetFilter(Status, '<>%1', PickingReceivingLines.Status::" ");
        if PickingReceivingLines.FindFirst then begin
            CountingHeader."Retail Status" := CountingHeader."Retail Status"::"Closed - difference";
            exit;
        end;
        case CountingHeader."Counting Type" of
            CountingHeader."Counting Type"::Receiving:
                begin
                    OutstandingLinesTEMP.Reset;
                    OutstandingLinesTEMP.DeleteAll;
                    case CountingHeader.Receiving of
                        CountingHeader.Receiving::"Purchase Order":
                            begin
                                PurchaseLine.Reset;
                                PurchaseLine.SetRange("Document Type", PurchaseLine."Document Type"::Order);
                                PurchaseLine.SetRange("Document No.", CountingHeader."Reference No.");
                                PurchaseLine.SetRange(Type, PurchaseLine.Type::Item);
                                PurchaseLine.SetFilter("No.", '<>%1', '');
                                if PurchaseLine.FindSet then
                                    repeat
                                        if PurchaseLine."Qty. Received (Base)" < PurchaseLine."Quantity (Base)" then
                                            UpdateOutstandingQty(PurchaseLine."No.", PurchaseLine."Quantity (Base)" - PurchaseLine."Qty. Received (Base)", OutstandingLinesTEMP);
                                    until PurchaseLine.Next = 0;
                            end;
                        CountingHeader.Receiving::"Sales Return Order":
                            begin
                                SalesLine.Reset;
                                SalesLine.SetRange("Document Type", SalesLine."Document Type"::"Return Order");
                                SalesLine.SetRange("Document No.", CountingHeader."Reference No.");
                                SalesLine.SetRange(Type, SalesLine.Type::Item);
                                SalesLine.SetFilter("No.", '<>%1', '');
                                if SalesLine.FindSet then
                                    repeat
                                        if SalesLine."Return Qty. Received (Base)" < SalesLine."Quantity (Base)" then
                                            UpdateOutstandingQty(SalesLine."No.", SalesLine."Quantity (Base)" - SalesLine."Return Qty. Received (Base)", OutstandingLinesTEMP);
                                    until SalesLine.Next = 0;
                            end;
                        CountingHeader.Receiving::"Transfer In":
                            begin
                                TransferLine.Reset;
                                TransferLine.SetRange("Document No.", CountingHeader."Reference No.");
                                TransferLine.SetFilter("Item No.", '<>%1', '');
                                TransferLine.SetRange("Derived From Line No.", 0);
                                if TransferLine.FindSet then
                                    repeat
                                        if TransferLine."Qty. Received (Base)" < TransferLine."Quantity (Base)" then
                                            UpdateOutstandingQty(TransferLine."Item No.", TransferLine."Quantity (Base)" - TransferLine."Qty. Received (Base)", OutstandingLinesTEMP);
                                    until TransferLine.Next = 0;
                            end;
                    end;
                    OutstandingLinesTEMP.Reset;
                    if OutstandingLinesTEMP.FindFirst then begin
                        PickingReceivingLines.Reset;
                        PickingReceivingLines.SetRange("Document No.", CountingHeader."No.");
                        PickingReceivingLines.SetFilter("Quantity (base)", '<>0');
                        if PickingReceivingLines.FindSet then
                            repeat
                                UpdateOutstandingQty(PickingReceivingLines."Item No.", -PickingReceivingLines."Quantity (base)", OutstandingLinesTEMP);
                            until PickingReceivingLines.Next = 0;
                    end;
                    OutstandingLinesTEMP.Reset;
                    if OutstandingLinesTEMP.FindFirst then begin
                        CountingHeader."Retail Status" := CountingHeader."Retail Status"::"Closed - difference";
                        exit;
                    end;
                end;
            CountingHeader."Counting Type"::Picking:
                begin
                    OutstandingLinesTEMP.Reset;
                    OutstandingLinesTEMP.DeleteAll;
                    case CountingHeader.Picking of
                        CountingHeader.Picking::"Sales Order":
                            begin
                                SalesLine.Reset;
                                SalesLine.SetRange("Document Type", SalesLine."Document Type"::Order);
                                SalesLine.SetRange("Document No.", CountingHeader."Reference No.");
                                SalesLine.SetRange(Type, SalesLine.Type::Item);
                                SalesLine.SetFilter("No.", '<>%1', '');
                                if SalesLine.FindSet then
                                    repeat
                                        if SalesLine."Qty. Shipped (Base)" < SalesLine."Quantity (Base)" then
                                            UpdateOutstandingQty(SalesLine."No.", SalesLine."Quantity (Base)" - SalesLine."Qty. Shipped (Base)", OutstandingLinesTEMP);
                                    until SalesLine.Next = 0;
                            end;
                        CountingHeader.Picking::"Purchase Return Order":
                            begin
                                PurchaseLine.Reset;
                                PurchaseLine.SetRange("Document Type", PurchaseLine."Document Type"::"Return Order");
                                PurchaseLine.SetRange("Document No.", CountingHeader."Reference No.");
                                PurchaseLine.SetRange(Type, PurchaseLine.Type::Item);
                                PurchaseLine.SetFilter("No.", '<>%1', '');
                                if PurchaseLine.FindSet then
                                    repeat
                                        if PurchaseLine."Return Qty. Shipped (Base)" < PurchaseLine."Quantity (Base)" then
                                            UpdateOutstandingQty(PurchaseLine."No.", PurchaseLine."Quantity (Base)" - PurchaseLine."Return Qty. Shipped (Base)", OutstandingLinesTEMP);
                                    until PurchaseLine.Next = 0;
                            end;
                        CountingHeader.Picking::"Transfer Out":
                            begin
                                TransferLine.Reset;
                                TransferLine.SetRange("Document No.", CountingHeader."Reference No.");
                                TransferLine.SetFilter("Item No.", '<>%1', '');
                                TransferLine.SetRange("Derived From Line No.", 0);
                                if TransferLine.FindSet then
                                    repeat
                                        if TransferLine."Qty. Shipped (Base)" < TransferLine."Quantity (Base)" then
                                            UpdateOutstandingQty(TransferLine."Item No.", TransferLine."Quantity (Base)" - TransferLine."Qty. Received (Base)", OutstandingLinesTEMP);
                                    until TransferLine.Next = 0;
                            end;
                    end;
                    OutstandingLinesTEMP.Reset;
                    if OutstandingLinesTEMP.FindFirst then begin
                        PickingReceivingLines.Reset;
                        PickingReceivingLines.SetRange("Document No.", CountingHeader."No.");
                        PickingReceivingLines.SetFilter("Quantity (base)", '<>0');
                        if PickingReceivingLines.FindSet then
                            repeat
                                UpdateOutstandingQty(PickingReceivingLines."Item No.", -PickingReceivingLines."Quantity (base)", OutstandingLinesTEMP);
                            until PickingReceivingLines.Next = 0;
                    end;
                    OutstandingLinesTEMP.Reset;
                    if OutstandingLinesTEMP.FindFirst then begin
                        CountingHeader."Retail Status" := CountingHeader."Retail Status"::"Closed - difference";
                        exit;
                    end;
                end;
        end;
    end;

    local procedure PostSourceDocument()
    var
        PurchRcptLine_L: Record "Purch. Rcpt. Line";
        ASNDeliveryDocumentLine_L: Record "LSC ASN Delivery Document Line";
        PostedASNDeliveryDocument_L: Record "LSC Posted ASN Del. Document";
        PurchaseLine: Record "Purchase Line";
        PurchPost: Codeunit "Purch.-Post";
        SalesPost: Codeunit "Sales-Post";
        TransferShipPost: Codeunit "TransferOrder-Post Shipment";
        TransferReceivePost: Codeunit "TransferOrder-Post Receipt";
    begin
        case CountingHeader."Counting Type" of
            CountingHeader."Counting Type"::Receiving:
                begin
                    if "Pic/RecSetup"."Receiving Posting" = "Pic/RecSetup"."Receiving Posting"::None then
                        exit;

                    case CountingHeader.Receiving of
                        CountingHeader.Receiving::"Purchase Order", CountingHeader.Receiving::"Purchase Order(create)":
                            begin
                                PurchOrder."LSC Reciving/Picking No." := CountingHeader."Posted No.";
                                PurchOrder.Receive := true;
                                if CountingHeader."Vendor Invoice No." <> '' then
                                    PurchOrder."Vendor Invoice No." := CountingHeader."Vendor Invoice No.";
                                if "Pic/RecSetup"."Receiving Posting" = "Pic/RecSetup"."Receiving Posting"::"Full Posting" then begin
                                    if PurchPaySetup."Ext. Doc. No. Mandatory" then
                                        PurchOrder.TestField("Vendor Invoice No.");
                                    PurchOrder.Invoice := true;
                                end else
                                    PurchOrder.Invoice := false;

                                PurchPost.Run(PurchOrder);
                            end;
                        CountingHeader.Receiving::"Sales Return Order":
                            begin
                                if "Pic/RecSetup"."Receiving Posting" = "Pic/RecSetup"."Receiving Posting"::None then
                                    exit;
                                SalesOrder."LSC Receiving/Picking No." := CountingHeader."Posted No.";
                                SalesOrder.Receive := true;
                                if "Pic/RecSetup"."Receiving Posting" = "Pic/RecSetup"."Receiving Posting"::"Full Posting" then
                                    SalesOrder.Invoice := true
                                else
                                    SalesOrder.Invoice := false;
                                SalesPost.Run(SalesOrder);
                            end;
                        CountingHeader.Receiving::"Transfer In":
                            begin
                                if "Pic/RecSetup"."Receiving Posting" = "Pic/RecSetup"."Receiving Posting"::None then
                                    exit;
                                TransferHeader."LSC Reciving/Picking No." := CountingHeader."Posted No.";
                                PickingReceivingPreReleaseTransferOrder(TransferHeader);
                                TransferReceivePost.Run(TransferHeader);
                            end;
                        CountingHeader.Receiving::"ASN Delivery Document":
                            begin
                                PostedASNDeliveryDocument_L.Reset;
                                PostedASNDeliveryDocument_L.SetRange("Document No.", CountingHeader."Reference No.");
                                if PostedASNDeliveryDocument_L.FindLast then
                                    ASNNewVersionNo := PostedASNDeliveryDocument_L."Version No." + 1
                                else
                                    ASNNewVersionNo := 1;
                                PurchaseHeaderTEMP.Reset;
                                if PurchaseHeaderTEMP.FindSet then
                                    repeat
                                        NewPostedReceiptNo := PurchOrder."Last Receiving No.";
                                        PurchOrder.Get(PurchaseHeaderTEMP."Document Type", PurchaseHeaderTEMP."No.");
                                        PurchOrder."LSC Reciving/Picking No." := CountingHeader."Posted No.";
                                        PurchOrder.Receive := true;
                                        if CountingHeader."Vendor Invoice No." <> '' then
                                            PurchOrder."Vendor Invoice No." := CountingHeader."Vendor Invoice No.";
                                        if "Pic/RecSetup"."Receiving Posting" = "Pic/RecSetup"."Receiving Posting"::"Full Posting" then begin
                                            if StatusPost = 2 then begin
                                                PurchaseLine.SetRange("Document Type", PurchOrder."Document Type");
                                                PurchaseLine.SetRange("Document No.", PurchOrder."No.");
                                                if PurchaseLine.FindSet() then
                                                    repeat
                                                        if PurchaseLine.Quantity > PurchaseLine."Quantity Received" + PurchaseLine."Qty. to Receive" then begin
                                                            PurchaseLine.SuspendStatusCheck(true);
                                                            PurchaseLine.Validate(Quantity, PurchaseLine."Quantity Received" + PurchaseLine."Qty. to Receive");
                                                            PurchaseLine.Modify();
                                                        end;
                                                    until PurchaseLine.next() = 0;
                                            end;
                                            if PurchPaySetup."Ext. Doc. No. Mandatory" then
                                                PurchOrder.TestField("Vendor Invoice No.");
                                            PurchOrder.Invoice := true;
                                        end else
                                            PurchOrder.Invoice := false;
                                        PurchOrder.Modify;
                                        Clear(PurchPost);
                                        PurchOrder."Your Reference" := CountingHeader."Reference No." + '-' + Format(ASNNewVersionNo);
                                        PurchPost.Run(PurchOrder);
                                        if PurchOrder."Last Receiving No." <> NewPostedReceiptNo then
                                            NewPostedReceiptNo := PurchOrder."Last Receiving No.";
                                        if NewPostedReceiptNo <> '' then begin
                                            ASNDeliveryDocumentLine_L.Reset;
                                            ASNDeliveryDocumentLine_L.SetCurrentKey("Document No.", "Purchase Order No.", "Purchase Order Line No.");
                                            ASNDeliveryDocumentLine_L.SetRange("Document No.", CountingHeader."Reference No.");
                                            ASNDeliveryDocumentLine_L.SetRange("Purchase Order No.", PurchOrder."No.");
                                            PurchRcptLine_L.Reset;
                                            PurchRcptLine_L.SetRange("Document No.", NewPostedReceiptNo);
                                            PurchRcptLine_L.SetFilter(Quantity, '<>0');
                                            if PurchRcptLine_L.FindSet then
                                                repeat
                                                    ASNDeliveryDocumentLine_L.SetRange("Purchase Order Line No.", PurchRcptLine_L."Line No.");
                                                    if ASNDeliveryDocumentLine_L.FindFirst then begin
                                                        ASNDeliveryDocumentLine_L.Validate("Quantity Received (Base)",
                                                          ASNDeliveryDocumentLine_L."Quantity Received (Base)" + PurchRcptLine_L."Quantity (Base)");
                                                        ASNDeliveryDocumentLine_L.Modify;
                                                    end;
                                                until PurchRcptLine_L.Next = 0;
                                        end;
                                    until PurchaseHeaderTEMP.Next = 0;
                            end;
                    end;
                end;
            CountingHeader."Counting Type"::Picking:
                begin
                    case CountingHeader.Picking of
                        CountingHeader.Picking::"Sales Order (create)", CountingHeader.Picking::"Sales Order":
                            begin
                                if "Pic/RecSetup"."Picking Posting" = "Pic/RecSetup"."Picking Posting"::None then
                                    exit;
                                SalesOrder."LSC Receiving/Picking No." := CountingHeader."Posted No.";
                                SalesOrder.Ship := true;
                                if "Pic/RecSetup"."Picking Posting" = "Pic/RecSetup"."Picking Posting"::"Full Posting" then
                                    SalesOrder.Invoice := true
                                else
                                    SalesOrder.Invoice := false;
                                SalesPost.Run(SalesOrder);
                            end;
                        CountingHeader.Picking::"Purchase Return Order", CountingHeader.Picking::"Purchase Return Order (create)":
                            begin
                                if "Pic/RecSetup"."Picking Posting" = "Pic/RecSetup"."Picking Posting"::None then
                                    exit;
                                PurchOrder."LSC Reciving/Picking No." := CountingHeader."Posted No.";
                                PurchOrder.Ship := true;
                                if "Pic/RecSetup"."Picking Posting" = "Pic/RecSetup"."Picking Posting"::"Full Posting" then begin
                                    PurchOrder.TestField("Vendor Cr. Memo No.");
                                    PurchOrder.Invoice := true;
                                end else
                                    PurchOrder.Invoice := false;

                                PurchPost.Run(PurchOrder);
                            end;
                        CountingHeader.Picking::"Transfer Out", CountingHeader.Picking::"Transfer Out (create)":
                            begin
                                if "Pic/RecSetup"."Picking Posting" = "Pic/RecSetup"."Picking Posting"::None then
                                    exit;
                                if not TransferSplitAllowed then begin
                                    TransLines.Reset;
                                    TransLines.SetRange("Document No.", TransferHeader."No.");
                                    TransLines.SetRange(Quantity, 0);
                                    if TransLines.FindSet then
                                        TransLines.DeleteAll;
                                    TransLines.Reset;
                                end;
                                TransferHeader."LSC Reciving/Picking No." := CountingHeader."Posted No.";
                                PickingReceivingPreReleaseTransferOrder(TransferHeader);
                                CODEUNIT.Run(Codeunit::"Release Transfer Document", TransferHeader);
                                TransferShipPost.Run(TransferHeader);
                            end;
                    end;
                end;
        end;
    end;

    local procedure GetSourcePurchase(DocType: Option "Order",ReturnOrder)
    var
        Vendor: Record Vendor;
    begin
        case DocType of
            DocType::Order:
                PurchOrder.Get(PurchOrder."Document Type"::Order, CountingHeader."Reference No.");
            DocType::ReturnOrder:
                PurchOrder.Get(PurchOrder."Document Type"::"Return Order", CountingHeader."Reference No.");
        end;
        GetSourcePurchaseEx(PurchOrder, DocType);
    end;

    local procedure GetSourcePurchaseEx(var PurchOrder_P: Record "Purchase Header"; DocType: Option "Order",ReturnOrder)
    var
        Vendor: Record Vendor;
        PurchLine_L: Record "Purchase Line";
    begin
        PurchOrder_P.TestField("Buy-from Vendor No.");
        SourceNo := PurchOrder_P."Buy-from Vendor No.";
        SourceType := SourceType::Vendor;
        Vendor.Get(PurchOrder_P."Buy-from Vendor No.");
        if Vendor.Blocked = Vendor.Blocked::All then
            Vendor.TestField(Blocked, 0);
        if PurchOrder_P."Pay-to Vendor No." <> Vendor."No." then begin
            Vendor.Get(PurchOrder_P."Pay-to Vendor No.");
            if Vendor.Blocked = Vendor.Blocked::All then
                Vendor.TestField(Blocked, 0);
        end;

        LogRecord.SetRange("Table ID", Database::"Purchase Header");
        LogRecord.SetRange("Document Type", PurchOrder_P."Document Type");
        LogRecord.SetRange("No.", PurchOrder_P."No.");
        if LogRecord.FindLast then
            LogLineNo := LogRecord."Line No.";
        LogTableId := Database::"Purchase Header";
        LogDocType := PurchOrder."Document Type".AsInteger();
        LogNo := PurchOrder_P."No.";

        PurchLine_L.SetRange("Document Type", PurchOrder_P."Document Type");
        PurchLine_L.SetRange("Document No.", PurchOrder_P."No.");
        PurchLine_L.SetRange(Type, PurchLine_L.Type::Item);
        case DocType of
            DocType::Order:
                PurchLine_L.SetFilter("Qty. to Receive", '<>%1', 0);
            DocType::ReturnOrder:
                PurchLine_L.SetFilter("Return Qty. to Ship", '<>%1', 0);
        end;
        if PurchLine_L.FindSet then
            repeat
                PurchLine_L.SuspendStatusCheck(true);
                case DocType of
                    DocType::Order:
                        PurchLine_L.Validate("Qty. to Receive", 0);
                    DocType::ReturnOrder:
                        PurchLine_L.Validate("Return Qty. to Ship", 0);
                end;
                PurchLine_L.Modify;
            until PurchLine_L.Next = 0;

        ResetReservEntries(Database::"Purchase Line", PurchOrder_P."Document Type".AsInteger(), PurchOrder_P."No.");
        CurrDocumentPostingDate := PurchOrder_P."Posting Date";
    end;

    local procedure GetSourceSales(DocType: Option "Order",ReturnOrder)
    var
        Customer: Record Customer;
        SalesLine: Record "Sales Line";
    begin
        case DocType of
            DocType::Order:
                SalesOrder.Get(SalesOrder."Document Type"::Order, CountingHeader."Reference No.");
            DocType::ReturnOrder:
                SalesOrder.Get(SalesOrder."Document Type"::"Return Order", CountingHeader."Reference No.");
        end;
        SalesOrder.TestField("Sell-to Customer No.");
        SourceNo := SalesOrder."Sell-to Customer No.";
        SourceType := SourceType::Customer;
        Customer.Get(SalesOrder."Sell-to Customer No.");
        Customer.TestField(Blocked, 0);
        if SalesOrder."Bill-to Customer No." <> Customer."No." then begin
            Customer.Get(SalesOrder."Bill-to Customer No.");
            Customer.TestField(Blocked, 0);
        end;

        LogRecord.SetRange("Table ID", Database::"Sales Header");
        LogRecord.SetRange("Document Type", SalesOrder."Document Type");
        LogRecord.SetRange("No.", SalesOrder."No.");
        if LogRecord.FindLast then
            LogLineNo := LogRecord."Line No.";
        LogTableId := Database::"Sales Header";
        LogDocType := SalesOrder."Document Type".AsInteger();
        LogNo := SalesOrder."No.";

        SalesLine.SetRange("Document Type", SalesOrder."Document Type");
        SalesLine.SetRange("Document No.", SalesOrder."No.");
        SalesLine.SetRange(Type, SalesLine.Type::Item);
        if SalesLine.FindSet then
            repeat
                SalesLine.SuspendStatusCheck(true);
                case DocType of
                    DocType::ReturnOrder:
                        SalesLine.Validate("Return Qty. to Receive", 0);
                    DocType::Order:
                        SalesLine.Validate("Qty. to Ship", 0);
                end;
                SalesLine.Modify;
            until SalesLine.Next = 0;

        ResetReservEntries(Database::"Sales Line", SalesOrder."Document Type".AsInteger(), SalesOrder."No.");
    end;

    local procedure GetSourceTransfer(TransType: Option Ship,Receive)
    begin
        TransferHeader.Get(CountingHeader."Reference No.");
        TransferHeader.TestField("Transfer-from Code");
        TransferHeader.TestField("Transfer-to Code");

        LogRecord.SetRange("Table ID", Database::"Transfer Header");
        case TransType of
            TransType::Ship:
                LogRecord.SetRange("Document Type", LogRecord."Document Type"::"Transfer Out");
            TransType::Receive:
                LogRecord.SetRange("Document Type", LogRecord."Document Type"::"Transfer In");
        end;
        LogRecord.SetRange("No.", TransferHeader."No.");
        if LogRecord.FindLast then
            LogLineNo := LogRecord."Line No.";
        LogTableId := Database::"Transfer Header";
        case TransType of
            TransType::Ship:
                LogDocType := LogDocType::"Transfer Out";
            TransType::Receive:
                LogDocType := LogDocType::"Transfer In";
        end;
        LogNo := TransferHeader."No.";

        TransLines.BlockDynamicTracking(true);
        TransLines.SetRange("Document No.", TransferHeader."No.");
        TransLines.SetRange("Derived From Line No.", 0);
        if TransLines.FindSet then
            repeat
                case TransType of
                    TransType::Ship:
                        TransLines.Validate("Qty. to Ship", 0);
                    TransType::Receive:
                        TransLines.Validate("Qty. to Receive", 0);
                end;
                TransLines.Modify;
            until TransLines.Next = 0;
        TransLines.BlockDynamicTracking(false);

        if TransType = TransType::Ship then begin
            ResetReservEntries(Database::"Transfer Line", 0, TransferHeader."No.");
            ResetReservEntries(Database::"Transfer Line", 1, TransferHeader."No.");
        end else
            ResetReservEntries(Database::"Transfer Line", 1, TransferHeader."No.");
    end;

    local procedure GetSourceASNDeliveryDocument()
    var
        ASNDeliveryDocumentLine_L: Record "LSC ASN Delivery Document Line";
        ASNDeliveryDocumentOrders_L: Record "LSC ASN Del. Document Orders";
        PurchaseOrder_L: Record "Purchase Header";
    begin
        ASNDeliveryDocumentLine_L.SetRange("Document No.", CountingHeader."Reference No.");
        if not ASNDeliveryDocumentLine_L.FindFirst then
            exit;
        ASNDeliveryDocumentLine_L.TryToUpdateASNOrderTable(ASNDeliveryDocumentLine_L);
        ASNDeliveryDocumentOrders_L.Reset;
        ASNDeliveryDocumentOrders_L.SetRange("Document No.", CountingHeader."Reference No.");
        if ASNDeliveryDocumentOrders_L.FindSet then
            repeat
                if PurchaseOrder_L.Get(PurchaseOrder_L."Document Type"::Order, ASNDeliveryDocumentOrders_L."Purchase Order No.") then
                    GetSourcePurchaseEx(PurchaseOrder_L, 0);
            until ASNDeliveryDocumentOrders_L.Next = 0;
    end;

    local procedure UpdatePurchaseLine(DocType: Option "Order",ReturnOrder; QuantityToReceive: Decimal; QuantityToAdd: Decimal; pPRLineRec: Record "LSC Picking / Receiving lines")
    var
        ASNDeliveryDocumentLine_L: Record "LSC ASN Delivery Document Line";
        TemQuantity: Decimal;
        QtyToUseCurrLine: Decimal;
        TempDirectUnitCost: Decimal;
        TempLineDisc: Decimal;
        CurrLine: Integer;
        MaxLine: Integer;
        ePurcaseHeaderNotFound: Label 'Purchase Order %1 not found.';
    begin
        if CountingHeader.Receiving = CountingHeader.Receiving::"ASN Delivery Document" then begin
            if ASNPurchaseOrderLine_G."Document No." <> '' then
                if not PurchOrder.get(ASNPurchaseOrderLine_G."Document Type", ASNPurchaseOrderLine_G."Document No.") then
                    Error(ePurcaseHeaderNotFound, ASNPurchaseOrderLine_G."Document No.");
            pPRLineRec."Item No." := ASNPurchaseOrderLine_G."No.";
            pPRLineRec."Variant Code" := ASNPurchaseOrderLine_G."Variant Code";
            PurchLine := ASNPurchaseOrderLine_G;
        end;

        PurchLine.Reset;
        PurchLine.SetRange("Document Type", PurchOrder."Document Type");
        PurchLine.SetRange("Document No.", PurchOrder."No.");
        PurchLine.SetRange(Type, PurchLine.Type::Item);
        PurchLine.SetRange("No.", pPRLineRec."Item No.");
        PurchLine.SetRange("Variant Code", pPRLineRec."Variant Code");
        if (CountingHeader.Receiving = CountingHeader.Receiving::"ASN Delivery Document") and
           (pPRLineRec."ASN Delivery Doc. Line No." <> 0)
        then
            if ASNDeliveryDocumentLine_L.Get(CountingHeader."Reference No.", pPRLineRec."ASN Delivery Doc. Line No.") then
                if ASNDeliveryDocumentLine_L."Purchase Order No." = PurchOrder."No." then
                    PurchLine.SetRange("Line No.", ASNDeliveryDocumentLine_L."Purchase Order Line No.");
        if not PurchLine.FindSet then begin
            SourceLineNo := SourceLineNo + 10000;
            PurchLine.Init;
            PurchLine."Document Type" := PurchOrder."Document Type";
            PurchLine."Document No." := PurchOrder."No.";
            PurchLine."Line No." := SourceLineNo;
            PurchLine.Insert;
            PurchLine.SuspendStatusCheck(true);
            PurchLine.Validate(Type, PurchLine.Type::Item);
            PurchLine.Validate("No.", pPRLineRec."Item No.");
            PurchLine.Validate("Variant Code", pPRLineRec."Variant Code");
            PurchLine.Validate("Unit of Measure Code", pPRLineRec."Unit of Measure Code");
            if PurchLine."Qty. per Unit of Measure" = 0 then
                PurchLine."Qty. per Unit of Measure" := 1;
            PurchLine.Validate(Quantity, QuantityToReceive / PurchLine."Qty. per Unit of Measure");
            PurchLine.Validate("Shortcut Dimension 1 Code", pPRLineRec."Shortcut Dimension 1 Code");
            PurchLine.Modify;
            InsertPurchLineResEntry(pPRLineRec, PurchOrder, PurchLine, QuantityToReceive);
        end else begin
            MaxLine := PurchLine.Count;
            repeat
                CurrLine := CurrLine + 1;
                PurchLine.SuspendStatusCheck(true);
                if PurchLine."Qty. per Unit of Measure" = 0 then
                    PurchLine."Qty. per Unit of Measure" := 1;
                case DocType of
                    DocType::Order:
                        TemQuantity := PurchLine."Qty. to Receive";
                    DocType::ReturnOrder:
                        TemQuantity := PurchLine."Return Qty. to Ship";
                end;

                TempDirectUnitCost := PurchLine."Direct Unit Cost";
                TempLineDisc := PurchLine."Line Discount %";

                if QuantityToAdd <> 0 then
                    if pPRLineRec."Posting Action" = pPRLineRec."Posting Action"::"Adjust Order" then
                        PurchLine.Validate(Quantity, PurchLine.Quantity + QuantityToAdd / PurchLine."Qty. per Unit of Measure");
                QuantityToAdd := 0;

                if (TempDirectUnitCost <> 0) and (TempDirectUnitCost <> PurchLine."Direct Unit Cost") then
                    PurchLine.Validate("Direct Unit Cost", TempDirectUnitCost);
                if (TempLineDisc <> 0) and (TempLineDisc <> PurchLine."Line Discount %") then
                    PurchLine.Validate("Line Discount %", TempLineDisc);
                if CurrLine < MaxLine then
                    if QuantityToReceive > (PurchLine."Outstanding Qty. (Base)" - TemQuantity / PurchLine."Qty. per Unit of Measure") then
                        QtyToUseCurrLine := PurchLine."Outstanding Qty. (Base)" - TemQuantity / PurchLine."Qty. per Unit of Measure"
                    else
                        QtyToUseCurrLine := QuantityToReceive
                else
                    QtyToUseCurrLine := QuantityToReceive;

                case DocType of
                    DocType::Order:
                        begin
                            PurchLine.Validate("Qty. to Receive", TemQuantity + QtyToUseCurrLine / PurchLine."Qty. per Unit of Measure");
                            if pPRLineRec."Posting Action" = pPRLineRec."Posting Action"::"Adjust Order" then
                                PurchLine.Validate(Quantity, PurchLine."Quantity Received" + PurchLine."Qty. to Receive");
                        end;
                    DocType::ReturnOrder:
                        PurchLine.Validate("Return Qty. to Ship", TemQuantity + QtyToUseCurrLine / PurchLine."Qty. per Unit of Measure");
                end;
                PurchLine.Validate("Shortcut Dimension 1 Code", pPRLineRec."Shortcut Dimension 1 Code");
                PurchLine.Modify;
                if CurrLine = 1 then
                    InsertPurchLineResEntry(pPRLineRec, PurchOrder, PurchLine, QtyToUseCurrLine);
                QuantityToReceive := QuantityToReceive - QtyToUseCurrLine;
            until PurchLine.Next = 0;
        end;
        OnAfterUpdatePurchaseLine(CountingHeader, pPRLineRec, PurchOrder);
    end;

    local procedure UpdateSalesLine(DocType: Option "Order",ReturnOrder; QuantityToReceive: Decimal; QuantityToAdd: Decimal; pPRLineRec: Record "LSC Picking / Receiving lines")
    var
        SalesLine: Record "Sales Line";
        TemQuantity: Decimal;
        CurrLine: Integer;
        MaxLine: Integer;
        QtyToUseCurrLine: Decimal;
        TempLineDisc: Decimal;
    begin
        SalesLine.Reset;
        SalesLine.SetRange("Document Type", SalesOrder."Document Type");
        SalesLine.SetRange("Document No.", SalesOrder."No.");
        SalesLine.SetRange(Type, SalesLine.Type::Item);
        SalesLine.SetRange("No.", pPRLineRec."Item No.");
        SalesLine.SetRange("Variant Code", pPRLineRec."Variant Code");
        if not SalesLine.FindSet then begin
            SourceLineNo := SourceLineNo + 10000;
            SalesLine.Init;
            SalesLine."Document Type" := SalesOrder."Document Type";
            SalesLine."Document No." := SalesOrder."No.";
            SalesLine."Line No." := SourceLineNo;
            SalesLine.Insert;
            SalesLine.SuspendStatusCheck(true);
            SalesLine.Validate(Type, SalesLine.Type::Item);
            SalesLine.Validate("No.", pPRLineRec."Item No.");
            SalesLine."Cross-Reference No." := pPRLineRec.Barcode;
            if SalesLine."Cross-Reference No." = '' then
                SalesLine."Cross-Reference No." := pPRLineRec."Item No.";
            SalesLine.Validate("Variant Code", pPRLineRec."Variant Code");
            SalesLine.Validate("Unit of Measure Code", pPRLineRec."Unit of Measure Code");
            if SalesLine."Qty. per Unit of Measure" = 0 then
                SalesLine."Qty. per Unit of Measure" := 1;
            SalesLine.Validate(Quantity, QuantityToReceive / SalesLine."Qty. per Unit of Measure");
            SalesLine.Validate("Shortcut Dimension 1 Code", pPRLineRec."Shortcut Dimension 1 Code");
            SalesLine.Modify;
            InsertSalesLineResEntry(pPRLineRec, SalesOrder, SalesLine, QuantityToReceive);
        end else begin
            MaxLine := SalesLine.Count;
            repeat
                CurrLine := CurrLine + 1;
                SalesLine.SuspendStatusCheck(true);
                if SalesLine."Qty. per Unit of Measure" = 0 then
                    SalesLine."Qty. per Unit of Measure" := 1;
                case DocType of
                    DocType::Order:
                        TemQuantity := SalesLine."Qty. to Ship";
                    DocType::ReturnOrder:
                        TemQuantity := SalesLine."Return Qty. to Receive";
                end;

                TempLineDisc := SalesLine."Line Discount %";
                if QuantityToAdd <> 0 then
                    SalesLine.Validate(Quantity, SalesLine.Quantity + QuantityToAdd / SalesLine."Qty. per Unit of Measure");
                QuantityToAdd := 0;
                if (TempLineDisc <> 0) and (TempLineDisc <> SalesLine."Line Discount %") then
                    SalesLine.Validate("Line Discount %", TempLineDisc);
                if CurrLine < MaxLine then
                    if QuantityToReceive > (SalesLine."Outstanding Qty. (Base)" - TemQuantity / SalesLine."Qty. per Unit of Measure") then
                        QtyToUseCurrLine := SalesLine."Outstanding Qty. (Base)" - TemQuantity / SalesLine."Qty. per Unit of Measure"
                    else
                        QtyToUseCurrLine := QuantityToReceive
                else
                    QtyToUseCurrLine := QuantityToReceive;

                case DocType of
                    DocType::ReturnOrder:
                        SalesLine.Validate("Return Qty. to Receive", TemQuantity + QtyToUseCurrLine / SalesLine."Qty. per Unit of Measure");
                    DocType::Order:
                        SalesLine.Validate("Qty. to Ship", TemQuantity + QtyToUseCurrLine / SalesLine."Qty. per Unit of Measure");
                end;
                SalesLine.Validate("Shortcut Dimension 1 Code", pPRLineRec."Shortcut Dimension 1 Code");
                SalesLine.Modify;
                if CurrLine = 1 then
                    InsertSalesLineResEntry(pPRLineRec, SalesOrder, SalesLine, QtyToUseCurrLine);
                QuantityToReceive := QuantityToReceive - QtyToUseCurrLine;
            until SalesLine.Next = 0;
        end;
    end;

    local procedure UpdateTransferLine(TransferType: Option Ship,Receive; QuantityToReceive: Decimal; QuantityToAdd: Decimal; pPRLineRec: Record "LSC Picking / Receiving lines")
    var
        TempQuantity: Decimal;
        QtyToUseCurrLine: Decimal;
        MaxLine: Integer;
        CurrLine: Integer;
    begin
        TransLines.Reset();
        TransLines.SetRange("Document No.", TransferHeader."No.");
        TransLines.SetRange("Item No.", pPRLineRec."Item No.");
        TransLines.SetRange("Variant Code", pPRLineRec."Variant Code");
        TransLines.SetRange("Derived From Line No.", 0);
        if not TransLines.FindSet() then begin
            SourceLineNo := SourceLineNo + 10000;
            TransLines.Init;
            TransLines."Document No." := TransferHeader."No.";
            TransLines."Line No." := SourceLineNo;
            TransLines.Insert;
            TransLines.Validate("Item No.", pPRLineRec."Item No.");
            TransLines.Validate("Variant Code", pPRLineRec."Variant Code");
            TransLines.Validate("Unit of Measure Code", pPRLineRec."Unit of Measure Code");
            if TransLines."Qty. per Unit of Measure" = 0 then
                TransLines."Qty. per Unit of Measure" := 1;
            TransLines.Validate(Quantity, QuantityToReceive / TransLines."Qty. per Unit of Measure");
            case TransferType of
                TransferType::Ship:
                    TransLines.Validate("Qty. to Ship", TransLines.Quantity);
                TransferType::Receive:
                    TransLines.Validate("Qty. to Receive", TransLines.Quantity);
            end;
            TransLines.Validate("Shortcut Dimension 1 Code", pPRLineRec."Shortcut Dimension 1 Code");
            TransLines.Modify;
            if TransferType = TransferType::Ship then
                InsertTransLineOutResEntry(pPRLineRec, TransferHeader, TransLines, QuantityToReceive)
            else
                InsertTransLineInResEntry(pPRLineRec, TransferHeader, TransLines, QuantityToReceive);
        end
        else begin
            MaxLine := TransLines.Count;
            repeat
                CurrLine += 1;
                if TransLines."Qty. per Unit of Measure" = 0 then
                    TransLines."Qty. per Unit of Measure" := 1;
                case TransferType of
                    TransferType::Ship:
                        TempQuantity := TransLines."Qty. to Ship";
                    TransferType::Receive:
                        TempQuantity := TransLines."Qty. to Receive";
                end;
                TransLines.Validate(Quantity, TransLines.Quantity + QuantityToAdd / TransLines."Qty. per Unit of Measure");
                if CurrLine < MaxLine THEN
                    if QuantityToReceive > (TransLines."Qty. to Receive (Base)" - TempQuantity / TransLines."Qty. per Unit of Measure") then
                        QtyToUseCurrLine := TransLines."Qty. to Receive (Base)" - TempQuantity / TransLines."Qty. per Unit of Measure"
                    else
                        QtyToUseCurrLine := QuantityToReceive
                else
                    QtyToUseCurrLine := QuantityToReceive;
                case TransferType of
                    TransferType::Ship:
                        TransLines.Validate("Qty. to Ship", TempQuantity + (QtyToUseCurrLine / TransLines."Qty. per Unit of Measure"));
                    TransferType::Receive:
                        TransLines.Validate("Qty. to Receive", TempQuantity + (QtyToUseCurrLine / TransLines."Qty. per Unit of Measure"));
                end;
                TransLines."Shortcut Dimension 1 Code" := pPRLineRec."Shortcut Dimension 1 Code";
                TransLines.Modify;
                if CurrLine = 1 then begin
                    if TransferType = TransferType::Ship then
                        InsertTransLineOutResEntry(pPRLineRec, TransferHeader, TransLines, QtyToUseCurrLine)
                    else
                        InsertTransLineInResEntry(pPRLineRec, TransferHeader, TransLines, QtyToUseCurrLine);
                end;
                QuantityToReceive := QuantityToReceive - QtyToUseCurrLine;
            until TransLines.Next() = 0;
        end;
    end;

    local procedure GetSalesLineNo(): Integer
    var
        SalesLine: Record "Sales Line";
    begin
        SalesLine.SetRange("Document Type", SalesOrder."Document Type");
        SalesLine.SetRange("Document No.", SalesOrder."No.");
        if SalesLine.FindLast then
            exit(SalesLine."Line No.");
    end;

    local procedure GetPurchaseLineNo(): Integer
    begin
        PurchLine.Reset;
        PurchLine.SetRange("Document Type", PurchOrder."Document Type");
        PurchLine.SetRange("Document No.", PurchOrder."No.");
        if PurchLine.FindLast then
            exit(PurchLine."Line No.");
    end;

    local procedure GetTransferLineNo(): Integer
    begin
        TransLines.Reset;
        TransLines.SetRange("Document No.", TransferHeader."No.");
        if TransLines.FindLast then
            exit(TransLines."Line No.");
    end;

    local procedure CreateSalesOrder()
    var
        lStoreRec: Record "LSC Store";
        lUserRec: Record "LSC Retail User";
    begin
        if lUserRec.Get(UserId) then;
        SalesOrder.Init;
        SalesOrder."Document Type" := SalesOrder."Document Type"::Order;
        SalesOrder."No." := '';
        SalesOrder.Insert(true);

        SalesOrder.Validate("Posting Date", CountingHeader."Counted Date");
        SalesOrder.Validate("Sell-to Customer No.", CountingHeader."Reference No.");
        SalesOrder.Validate("Location Code", CountingHeader."Location Code");
        lStoreRec.FindStore(CountingHeader."Location Code", lStoreRec);
        if lStoreRec.IsEmpty then
            if lStoreRec.Get(lUserRec."Store No.") then;

        if not lStoreRec.IsEmpty then
            if lStoreRec."Global Dimension 1 Code" <> '' then
                SalesOrder.Validate("Shortcut Dimension 1 Code", lStoreRec."Global Dimension 1 Code");

        SalesOrder.Modify;

        LogRecord.SetRange("Table ID", Database::"Sales Header");
        LogRecord.SetRange("Document Type", SalesOrder."Document Type");
        LogRecord.SetRange("No.", SalesOrder."No.");
        if LogRecord.FindLast then
            LogLineNo := LogRecord."Line No.";
        LogTableId := Database::"Sales Header";
        LogDocType := SalesOrder."Document Type".AsInteger();
        LogNo := SalesOrder."No.";
    end;

    local procedure CreatePurchReturnOrder()
    begin
        PurchOrder.Init;
        PurchOrder."Document Type" := PurchOrder."Document Type"::"Return Order";
        PurchOrder."No." := '';
        PurchOrder.Insert(true);

        PurchOrder.Validate("Posting Date", CountingHeader."Counted Date");
        PurchOrder.Validate("Buy-from Vendor No.", CountingHeader."Reference No.");
        PurchOrder.Validate("Location Code", CountingHeader."Location Code");
        PurchOrder.Validate("Vendor Cr. Memo No.", CountingHeader."Vendor Cr. Memo No.");
        PurchOrder.Modify;

        LogRecord.SetRange("Table ID", Database::"Purchase Header");
        LogRecord.SetRange("Document Type", PurchOrder."Document Type");
        LogRecord.SetRange("No.", PurchOrder."No.");
        if LogRecord.FindLast then
            LogLineNo := LogRecord."Line No.";
        LogTableId := Database::"Purchase Header";
        LogDocType := PurchOrder."Document Type".AsInteger();
        LogNo := PurchOrder."No.";
    end;

    local procedure CreateTransferFromOrder()
    var
        lStoreRec: Record "LSC Store";
    begin
        TransferHeader.Init;
        TransferHeader."No." := '';
        TransferHeader.Insert(true);

        TransferHeader.Validate("LSC Store-from", CountingHeader."Store No.");
        TransferHeader.Validate("Transfer-from Code", CountingHeader."Location Code");
        if lStoreRec.FindStore(CountingHeader."Reference No.", lStoreRec) then
            TransferHeader.Validate("LSC Store-to", lStoreRec."No.")
        else
            TransferHeader.Validate("LSC Store-to", CountingHeader."Reference No.");
        TransferHeader.Validate("Transfer-to Code", CountingHeader."Reference No.");
        TransferHeader.Validate("Posting Date", CountingHeader."Counted Date");
        TransferHeader.Modify;

        LogRecord.SetRange("Table ID", Database::"Transfer Header");
        LogRecord.SetRange("Document Type", LogRecord."Document Type"::"Transfer Out");
        LogRecord.SetRange("No.", TransferHeader."No.");
        if LogRecord.FindLast then
            LogLineNo := LogRecord."Line No.";
        LogTableId := Database::"Transfer Header";
        LogDocType := LogRecord."Document Type"::"Transfer Out";
        LogNo := TransferHeader."No.";
    end;

    local procedure CreatePurchOrder()
    begin
        PurchOrder.Init;
        PurchOrder."Document Type" := PurchOrder."Document Type"::Order;
        PurchOrder."No." := '';
        PurchOrder.Insert(true);

        PurchOrder.Validate("Posting Date", CountingHeader."Counted Date");
        PurchOrder.Validate("Buy-from Vendor No.", CountingHeader."Reference No.");
        PurchOrder.Validate("Location Code", CountingHeader."Location Code");
        PurchOrder."Vendor Invoice No." := CountingHeader."Vendor Invoice No.";
        PurchOrder.Modify;

        LogRecord.SetRange("Table ID", Database::"Purchase Header");
        LogRecord.SetRange("Document Type", PurchOrder."Document Type");
        LogRecord.SetRange("No.", PurchOrder."No.");
        if LogRecord.FindLast then
            LogLineNo := LogRecord."Line No.";
        LogTableId := Database::"Purchase Header";
        LogDocType := PurchOrder."Document Type".AsInteger();
        LogNo := PurchOrder."No.";
    end;

    local procedure ProcessSalesDocLines_Diff(pPRHeaderRec: Record "LSC P/R Counting Header")
    var
        lPRHeaderRec: Record "LSC P/R Counting Header";
        lSalesLinesRec: Record "Sales Line";
        lPRLineRec2: Record "LSC Picking / Receiving lines";
    begin
        lPRHeaderRec.Get(pPRHeaderRec."No.");

        lSalesLinesRec.Reset;
        if lPRHeaderRec.Receiving = lPRHeaderRec.Receiving::"Sales Return Order" then
            lSalesLinesRec.SetRange("Document Type", lSalesLinesRec."Document Type"::"Return Order")
        else
            lSalesLinesRec.SetRange("Document Type", lSalesLinesRec."Document Type"::Order);
        lSalesLinesRec.SetRange("Document No.", lPRHeaderRec."Reference No.");

        SourceLineNo := GetSourceLineNo;

        if lSalesLinesRec.FindSet then
            repeat
                CountingLines.Reset;
                CountingLines.SetRange("Document No.", lPRHeaderRec."No.");
                CountingLines.SetRange("Item No.", lSalesLinesRec."No.");
                if CountingLines.FindFirst then begin
                    if CountingLines."Qty. per Unit of Measure" = 0 then
                        CountingLines."Qty. per Unit of Measure" := 1;
                    if not Item.Get(CountingLines."Item No.") then
                        Item.Init;

                    case CountingLines."Posting Action" of
                        CountingLines."Posting Action"::"To location":
                            ToLocation;
                        PostSetup."Posting Action"::Return:
                            ReturnQuantity;
                        PostSetup."Posting Action"::"Adjust Order":
                            AddToOrder;
                        else
                            UpdateSourceLine(CountingLines."Quantity (base)", 0, CountingLines);
                    end;

                    case StatusPost of
                        1:
                            if CountingLines.Status = CountingLines.Status::"Not enough" then begin
                                CountingLines.Status := CountingLines.Status::" ";
                                CountingLines.Difference := 0;
                                CountingLines."Difference (base)" := 0;
                            end;
                        2:
                            DefineCloseStatus;
                    end;

                    if CountingLines."Posting Action" = CountingLines."Posting Action"::Return then
                        CountingLines.Status := CountingLines.Status::Return;
                    PostedLines.Init;
                    PostedLines.TransferFields(CountingLines);
                    PostedLines."Document No." := PostedHeader."No.";
                    if not PostedLines.Insert then
                        PostedLines.Modify;
                end
                else begin
                    lPRLineRec2.Init;
                    lPRLineRec2."Document No." := CountingHeader."No.";
                    lPRLineRec2."Item No." := lSalesLinesRec."No.";
                    UpdateSourceLine(lSalesLinesRec."Outstanding Qty. (Base)", 0, lPRLineRec2);
                end;
            until lSalesLinesRec.Next = 0;

        CountingLines.Reset;
        CountingLines.SetRange("Document No.", lPRHeaderRec."No.");
        CountingLines.SetRange("Status Difference", CountingLines."Status Difference"::Return);
        CountingLines.SetRange(Quantity, 0);
        CountingLines.SetFilter("Qty. Difference", '<>%1', 0);
        if CountingLines.FindSet then
            repeat
                case CountingLines."Posting Action" of
                    CountingLines."Posting Action"::"To location":
                        ToLocation;
                    PostSetup."Posting Action"::Return:
                        ReturnQuantity;
                    PostSetup."Posting Action"::"Adjust Order":
                        AddToOrder;
                    else
                        UpdateSourceLine(CountingLines."Quantity (base)", 0, CountingLines);
                end;

                case StatusPost of
                    1:
                        if CountingLines.Status = CountingLines.Status::"Not enough" then begin
                            CountingLines.Status := CountingLines.Status::" ";
                            CountingLines.Difference := 0;
                            CountingLines."Difference (base)" := 0;
                        end;
                    2:
                        DefineCloseStatus;
                end;

                if CountingLines."Posting Action" = CountingLines."Posting Action"::Return then
                    CountingLines.Status := CountingLines.Status::Return;
                PostedLines.Init;
                PostedLines.TransferFields(CountingLines);
                PostedLines."Document No." := PostedHeader."No.";
                PostedLines.Quantity := PostedLines."Qty. Difference";
                PostedLines."Quantity (base)" := PostedLines."Qty. Difference (base)";
                PostedLines.Difference := PostedLines."Qty. Difference";
                PostedLines."Difference (base)" := PostedLines."Qty. Difference (base)";

                if not PostedLines.Insert then
                    PostedLines.Modify;
            until CountingLines.Next = 0;

        CountingLines.Reset;
        CountingLines.SetRange("Document No.", lPRHeaderRec."No.");
        CountingLines.SetRange("Status Difference", CountingLines."Status Difference"::"Not ordered");
        CountingLines.SetFilter("Qty. Difference", '<>%1', 0);
        if CountingLines.FindSet then
            repeat
                case CountingLines."Posting Action" of
                    CountingLines."Posting Action"::"To location":
                        ToLocation;
                    PostSetup."Posting Action"::Return:
                        ReturnQuantity;
                    PostSetup."Posting Action"::"Adjust Order":
                        AddToOrder;
                    else
                        UpdateSourceLine(CountingLines."Quantity (base)", 0, CountingLines);
                end;

                case StatusPost of
                    1:
                        if CountingLines.Status = CountingLines.Status::"Not enough" then begin
                            CountingLines.Status := CountingLines.Status::" ";
                            CountingLines.Difference := 0;
                            CountingLines."Difference (base)" := 0;
                        end;
                    2:
                        DefineCloseStatus;
                end;

                if CountingLines."Posting Action" = CountingLines."Posting Action"::Return then
                    CountingLines.Status := CountingLines.Status::Return;
                PostedLines.Init;
                PostedLines.TransferFields(CountingLines);
                PostedLines."Document No." := PostedHeader."No.";
                if not PostedLines.Insert then
                    PostedLines.Modify;
            until CountingLines.Next = 0;
    end;

    local procedure ProcessTransDocLines_Diff(pPRHeaderRec: Record "LSC P/R Counting Header")
    var
        lPRHeaderRec: Record "LSC P/R Counting Header";
        lTransferLinesRec: Record "Transfer Line";
        lPRLineRec2: Record "LSC Picking / Receiving lines";
    begin
        lPRHeaderRec.Get(pPRHeaderRec."No.");

        lTransferLinesRec.Reset;
        lTransferLinesRec.SetRange("Document No.", lPRHeaderRec."Reference No.");
        lTransferLinesRec.SetRange("Derived From Line No.", 0);

        SourceLineNo := GetSourceLineNo;

        if lTransferLinesRec.FindSet then
            repeat
                CountingLines.Reset;
                CountingLines.SetRange("Document No.", lPRHeaderRec."No.");
                CountingLines.SetRange("Item No.", lTransferLinesRec."Item No.");
                if CountingLines.FindFirst then begin
                    if CountingLines."Qty. per Unit of Measure" = 0 then
                        CountingLines."Qty. per Unit of Measure" := 1;
                    if not Item.Get(CountingLines."Item No.") then
                        Item.Init;

                    case CountingLines."Posting Action" of
                        CountingLines."Posting Action"::"To location":
                            ToLocation;
                        PostSetup."Posting Action"::Return:
                            ReturnQuantity;
                        PostSetup."Posting Action"::"Adjust Order":
                            AddToOrder;
                        else
                            UpdateSourceLine(CountingLines."Quantity (base)", 0, CountingLines);
                    end;
                    case StatusPost of
                        1:
                            if CountingLines.Status = CountingLines.Status::"Not enough" then begin
                                CountingLines.Status := CountingLines.Status::" ";
                                CountingLines.Difference := 0;
                                CountingLines."Difference (base)" := 0;
                            end;
                        2:
                            DefineCloseStatus;
                    end;

                    if CountingLines."Posting Action" = CountingLines."Posting Action"::Return then
                        CountingLines.Status := CountingLines.Status::Return;
                    PostedLines.Init;
                    PostedLines.TransferFields(CountingLines);
                    PostedLines."Document No." := PostedHeader."No.";
                    if not PostedLines.Insert then
                        PostedLines.Modify;
                end
                else begin
                    lPRLineRec2.Init;
                    lPRLineRec2."Document No." := CountingHeader."No.";
                    lPRLineRec2."Item No." := lTransferLinesRec."Item No.";
                    UpdateSourceLine(lTransferLinesRec."Outstanding Qty. (Base)", 0, lPRLineRec2);
                end;
            until lTransferLinesRec.Next = 0;

        CountingLines.Reset;
        CountingLines.SetRange("Document No.", lPRHeaderRec."No.");
        CountingLines.SetRange("Status Difference", CountingLines."Status Difference"::Return);
        CountingLines.SetRange(Quantity, 0);
        CountingLines.SetFilter("Qty. Difference", '<>%1', 0);
        if CountingLines.FindSet then
            repeat
                case CountingLines."Posting Action" of
                    CountingLines."Posting Action"::"To location":
                        ToLocation;
                    PostSetup."Posting Action"::Return:
                        ReturnQuantity;
                    PostSetup."Posting Action"::"Adjust Order":
                        AddToOrder;
                    else
                        UpdateSourceLine(CountingLines."Quantity (base)", 0, CountingLines);
                end;

                case StatusPost of
                    1:
                        if CountingLines.Status = CountingLines.Status::"Not enough" then begin
                            CountingLines.Status := CountingLines.Status::" ";
                            CountingLines.Difference := 0;
                            CountingLines."Difference (base)" := 0;
                        end;
                    2:
                        DefineCloseStatus;
                end;

                if CountingLines."Posting Action" = CountingLines."Posting Action"::Return then
                    CountingLines.Status := CountingLines.Status::Return;
                PostedLines.Init;
                PostedLines.TransferFields(CountingLines);
                PostedLines."Document No." := PostedHeader."No.";
                PostedLines.Quantity := PostedLines."Qty. Difference";
                PostedLines."Quantity (base)" := PostedLines."Qty. Difference (base)";
                PostedLines.Difference := PostedLines."Qty. Difference";
                PostedLines."Difference (base)" := PostedLines."Qty. Difference (base)";

                if not PostedLines.Insert then
                    PostedLines.Modify;
            until CountingLines.Next = 0;

        CountingLines.Reset;
        CountingLines.SetRange("Document No.", lPRHeaderRec."No.");
        CountingLines.SetRange("Status Difference", CountingLines."Status Difference"::"Not ordered");
        CountingLines.SetFilter("Qty. Difference", '<>%1', 0);
        if CountingLines.FindSet then
            repeat
                case CountingLines."Posting Action" of
                    CountingLines."Posting Action"::"To location":
                        ToLocation;
                    PostSetup."Posting Action"::Return:
                        ReturnQuantity;
                    PostSetup."Posting Action"::"Adjust Order":
                        AddToOrder;
                    else
                        UpdateSourceLine(CountingLines."Quantity (base)", 0, CountingLines);
                end;

                case StatusPost of
                    1:
                        if CountingLines.Status = CountingLines.Status::"Not enough" then begin
                            CountingLines.Status := CountingLines.Status::" ";
                            CountingLines.Difference := 0;
                            CountingLines."Difference (base)" := 0;
                        end;
                    2:
                        DefineCloseStatus;
                end;

                if CountingLines."Posting Action" = CountingLines."Posting Action"::Return then
                    CountingLines.Status := CountingLines.Status::Return;
                PostedLines.Init;
                PostedLines.TransferFields(CountingLines);
                PostedLines."Document No." := PostedHeader."No.";
                if not PostedLines.Insert then
                    PostedLines.Modify;
            until CountingLines.Next = 0;
    end;

    local procedure ProcessPurchDocLines_Diff(pPRHeaderRec: Record "LSC P/R Counting Header")
    var
        lPRHeaderRec: Record "LSC P/R Counting Header";
        lPurchLinesRec: Record "Purchase Line";
        lPRLineRec2: Record "LSC Picking / Receiving lines";
    begin
        lPRHeaderRec.Get(pPRHeaderRec."No.");
        lPurchLinesRec.Reset;
        if lPRHeaderRec.Receiving = lPRHeaderRec.Receiving::"Purchase Order" then
            lPurchLinesRec.SetRange("Document Type", lPurchLinesRec."Document Type"::Order)
        else
            lPurchLinesRec.SetRange("Document Type", lPurchLinesRec."Document Type"::"Return Order");
        lPurchLinesRec.SetRange("Document No.", lPRHeaderRec."Reference No.");

        SourceLineNo := GetSourceLineNo;

        if lPurchLinesRec.FindSet then
            repeat
                CountingLines.Reset;
                CountingLines.SetRange("Document No.", lPRHeaderRec."No.");
                CountingLines.SetRange("Item No.", lPurchLinesRec."No.");
                if CountingLines.FindFirst then begin
                    if CountingLines."Qty. per Unit of Measure" = 0 then
                        CountingLines."Qty. per Unit of Measure" := 1;
                    if not Item.Get(CountingLines."Item No.") then
                        Item.Init;

                    case CountingLines."Posting Action" of
                        CountingLines."Posting Action"::"To location":
                            ToLocation;
                        PostSetup."Posting Action"::Return:
                            ReturnQuantity;
                        PostSetup."Posting Action"::"Adjust Order":
                            AddToOrder;
                        else
                            UpdateSourceLine(CountingLines."Quantity (base)", 0, CountingLines);
                    end;

                    case StatusPost of
                        1:
                            if CountingLines.Status = CountingLines.Status::"Not enough" then begin
                                CountingLines.Status := CountingLines.Status::" ";
                                CountingLines.Difference := 0;
                                CountingLines."Difference (base)" := 0;
                            end;
                        2:
                            DefineCloseStatus;
                    end;

                    if CountingLines."Posting Action" = CountingLines."Posting Action"::Return then
                        CountingLines.Status := CountingLines.Status::Return;
                    PostedLines.Init;
                    PostedLines.TransferFields(CountingLines);
                    PostedLines."Document No." := PostedHeader."No.";
                    if not PostedLines.Insert then
                        PostedLines.Modify;
                end
                else begin
                    lPRLineRec2.Init;
                    lPRLineRec2."Document No." := CountingHeader."No.";
                    lPRLineRec2."Item No." := lPurchLinesRec."No.";
                    UpdateSourceLine(lPurchLinesRec."Outstanding Qty. (Base)", 0, lPRLineRec2);
                end;
            until lPurchLinesRec.Next = 0;

        CountingLines.Reset;
        CountingLines.SetRange("Document No.", lPRHeaderRec."No.");
        CountingLines.SetRange("Status Difference", CountingLines."Status Difference"::Return);
        CountingLines.SetRange(Quantity, 0);
        CountingLines.SetFilter("Qty. Difference", '<>%1', 0);
        if CountingLines.FindSet then
            repeat
                case CountingLines."Posting Action" of
                    CountingLines."Posting Action"::"To location":
                        ToLocation;
                    PostSetup."Posting Action"::Return:
                        ReturnQuantity;
                    PostSetup."Posting Action"::"Adjust Order":
                        AddToOrder;
                    else
                        UpdateSourceLine(CountingLines."Quantity (base)", 0, CountingLines);
                end;

                case StatusPost of
                    1:
                        if CountingLines.Status = CountingLines.Status::"Not enough" then begin
                            CountingLines.Status := CountingLines.Status::" ";
                            CountingLines.Difference := 0;
                            CountingLines."Difference (base)" := 0;
                        end;
                    2:
                        DefineCloseStatus;
                end;

                if CountingLines."Posting Action" = CountingLines."Posting Action"::Return then
                    CountingLines.Status := CountingLines.Status::Return;
                PostedLines.Init;
                PostedLines.TransferFields(CountingLines);
                PostedLines."Document No." := PostedHeader."No.";
                PostedLines.Quantity := PostedLines."Qty. Difference";
                PostedLines."Quantity (base)" := PostedLines."Qty. Difference (base)";
                PostedLines.Difference := PostedLines."Qty. Difference";
                PostedLines."Difference (base)" := PostedLines."Qty. Difference (base)";

                if not PostedLines.Insert then
                    PostedLines.Modify;
            until CountingLines.Next = 0;

        CountingLines.Reset;
        CountingLines.SetRange("Document No.", lPRHeaderRec."No.");
        CountingLines.SetRange("Status Difference", CountingLines."Status Difference"::"Not ordered");
        CountingLines.SetFilter("Qty. Difference", '<>%1', 0);
        if CountingLines.FindSet then
            repeat
                case CountingLines."Posting Action" of
                    CountingLines."Posting Action"::"To location":
                        ToLocation;
                    PostSetup."Posting Action"::Return:
                        ReturnQuantity;
                    PostSetup."Posting Action"::"Adjust Order":
                        AddToOrder;
                    else
                        UpdateSourceLine(CountingLines."Quantity (base)", 0, CountingLines);
                end;

                case StatusPost of
                    1:
                        if CountingLines.Status = CountingLines.Status::"Not enough" then begin
                            CountingLines.Status := CountingLines.Status::" ";
                            CountingLines.Difference := 0;
                            CountingLines."Difference (base)" := 0;
                        end;
                    2:
                        DefineCloseStatus;
                end;

                if CountingLines."Posting Action" = CountingLines."Posting Action"::Return then
                    CountingLines.Status := CountingLines.Status::Return;
                PostedLines.Init;
                PostedLines.TransferFields(CountingLines);
                PostedLines."Document No." := PostedHeader."No.";
                if not PostedLines.Insert then
                    PostedLines.Modify;
            until CountingLines.Next = 0;
    end;

    local procedure ProcessASNDeliveryDocLines_Diff(pPRHeaderRec: Record "LSC P/R Counting Header")
    var
        ASNDeliveryDocumentLine_L: Record "LSC ASN Delivery Document Line";
        PurchaseLineTEMP: Record "Purchase Line" temporary;
    begin
        CalledFromASNDocLineDiff := true;
        PurchaseLineTEMP.Reset;
        PurchaseLineTEMP.DeleteAll;
        ASNDeliveryDocumentLine_L.Reset;
        ASNDeliveryDocumentLine_L.SetRange("Document No.", pPRHeaderRec."Reference No.");
        ASNDeliveryDocumentLine_L.SetFilter("Purchase Order No.", '<>%1', '');
        if ASNDeliveryDocumentLine_L.FindSet then
            repeat
                if not PurchaseLineTEMP.Get(0, ASNDeliveryDocumentLine_L."Purchase Order No.", 0) then begin
                    Clear(PurchaseLineTEMP);
                    PurchaseLineTEMP."Document No." := ASNDeliveryDocumentLine_L."Purchase Order No.";
                    PurchaseLineTEMP.Insert;
                end;
            until ASNDeliveryDocumentLine_L.Next = 0;
    end;

    [Scope('OnPrem')]
    procedure InStoreDocExists(): Boolean
    begin
        exit(false);
    end;

    [Scope('OnPrem')]
    procedure SplitPurchaseLine(var pPurchaseLine: Record "Purchase Line"; var pPickReceivLines: Record "LSC Picking / Receiving lines")
    var
        TempTrackingSpec: Record "Tracking Specification" temporary;
        RemQty: Decimal;
        LineNo: Integer;
        SignFactor: Integer;
    begin
        LineNo := 0;

        pPickReceivLines.Reset;
        pPickReceivLines.DeleteAll;

        if pPurchaseLine."Document Type" = pPurchaseLine."Document Type"::Order then
            SignFactor := 1
        else
            SignFactor := -1;

        FindReservEntries(TempTrackingSpec, Database::"Purchase Line",
          pPurchaseLine."Document Type".AsInteger(), pPurchaseLine."Document No.", '', 0, pPurchaseLine."Line No.");

        if not TempTrackingSpec.IsEmpty then begin
            if SignFactor > 0 then
                RemQty := pPurchaseLine."Qty. to Receive"
            else
                RemQty := pPurchaseLine."Return Qty. to Ship";
            TempTrackingSpec.Reset;
            if TempTrackingSpec.FindSet then
                repeat
                    if pPurchaseLine."Qty. per Unit of Measure" <> TempTrackingSpec."Qty. per Unit of Measure" then
                        Error(Text006, pPurchaseLine.FieldCaption("Qty. per Unit of Measure"), pPurchaseLine."No.");
                    RemQty := RemQty - (SignFactor * TempTrackingSpec."Qty. to Handle");
                    CreateSplitLine(pPurchaseLine."No.", pPurchaseLine."Variant Code",
                      (SignFactor * TempTrackingSpec."Qty. to Handle (Base)"),
                      pPurchaseLine."Unit of Measure Code", TempTrackingSpec."Qty. per Unit of Measure",
                      TempTrackingSpec."Serial No.", TempTrackingSpec."Lot No.", TempTrackingSpec."Expiration Date",
                      LineNo, pPickReceivLines);
                    OnAfterCreateSplitLine(pPickReceivLines, pPurchaseLine, true);
                until TempTrackingSpec.Next = 0;
            if RemQty <> 0 then
                Error(Text006, pPurchaseLine.FieldCaption(Quantity), pPurchaseLine."No.");
        end else begin
            CreateSplitLine(pPurchaseLine."No.", pPurchaseLine."Variant Code",
              pPurchaseLine."Outstanding Qty. (Base)",
              pPurchaseLine."Unit of Measure Code", pPurchaseLine."Qty. per Unit of Measure",
              '', '', 0D, LineNo, pPickReceivLines);
            OnAfterCreateSplitLine(pPickReceivLines, pPurchaseLine, false);
        end;
    end;

    [Scope('OnPrem')]
    procedure SplitSalesLine(var pSalesLine: Record "Sales Line"; var pPickReceivLines: Record "LSC Picking / Receiving lines")
    var
        TempTrackingSpec: Record "Tracking Specification" temporary;
        RemQty: Decimal;
        LineNo: Integer;
        SignFactor: Integer;
    begin
        LineNo := 0;

        pPickReceivLines.Reset;
        pPickReceivLines.DeleteAll;

        if pSalesLine."Document Type" = pSalesLine."Document Type"::Order then
            SignFactor := -1
        else
            SignFactor := 1;

        FindReservEntries(TempTrackingSpec, Database::"Sales Line",
          pSalesLine."Document Type".AsInteger(), pSalesLine."Document No.", '', 0, pSalesLine."Line No.");

        if not TempTrackingSpec.IsEmpty then begin
            if SignFactor < 0 then
                RemQty := pSalesLine."Qty. to Ship"
            else
                RemQty := pSalesLine."Return Qty. to Receive";
            TempTrackingSpec.Reset;
            if TempTrackingSpec.FindSet then
                repeat
                    if pSalesLine."Qty. per Unit of Measure" <> TempTrackingSpec."Qty. per Unit of Measure" then
                        Error(Text006, pSalesLine.FieldCaption("Qty. per Unit of Measure"), pSalesLine."No.");
                    RemQty := RemQty - (SignFactor * TempTrackingSpec."Qty. to Handle");
                    CreateSplitLine(pSalesLine."No.", pSalesLine."Variant Code",
                      (SignFactor * TempTrackingSpec."Qty. to Handle (Base)"),
                      pSalesLine."Unit of Measure Code", TempTrackingSpec."Qty. per Unit of Measure",
                      TempTrackingSpec."Serial No.", TempTrackingSpec."Lot No.", TempTrackingSpec."Expiration Date",
                      LineNo, pPickReceivLines);
                until TempTrackingSpec.Next = 0;
            if RemQty <> 0 then
                Error(Text006, pSalesLine.FieldCaption(Quantity), pSalesLine."No.");
        end else
            CreateSplitLine(pSalesLine."No.", pSalesLine."Variant Code",
              pSalesLine."Outstanding Qty. (Base)",
              pSalesLine."Unit of Measure Code", pSalesLine."Qty. per Unit of Measure",
              '', '', 0D, LineNo, pPickReceivLines);
    end;

    [Scope('OnPrem')]
    procedure SplitTransLine(pTransferType: Option Ship,Receive; var pTransferLine: Record "Transfer Line"; var pPickReceivLines: Record "LSC Picking / Receiving lines")
    var
        TempTrackingSpec: Record "Tracking Specification" temporary;
        RemQty: Decimal;
        LineNo: Integer;
        SignFactor: Integer;
    begin
        LineNo := 0;

        pPickReceivLines.Reset;
        pPickReceivLines.DeleteAll;

        SignFactor := 1;

        if pTransferType = pTransferType::Ship then
            FindReservEntries(TempTrackingSpec, Database::"Transfer Line", 1, pTransferLine."Document No.", '', 0, pTransferLine."Line No.")
        else
            FindReservEntries(TempTrackingSpec, Database::"Transfer Line",
              1, pTransferLine."Document No.", '', pTransferLine."Line No.", GetDerivedLineNo(pTransferLine));

        if not TempTrackingSpec.IsEmpty then begin
            if pTransferType = pTransferType::Ship then
                RemQty := pTransferLine."Outstanding Qty. (Base)"
            else
                RemQty := pTransferLine."Qty. in Transit (Base)";
            TempTrackingSpec.Reset;
            if TempTrackingSpec.FindSet then
                repeat
                    if pTransferLine."Qty. per Unit of Measure" <> TempTrackingSpec."Qty. per Unit of Measure" then
                        Error(Text006, pTransferLine.FieldCaption("Qty. per Unit of Measure"), pTransferLine."Item No.");
                    RemQty := RemQty - (SignFactor * TempTrackingSpec."Qty. to Handle");
                    CreateSplitLine(pTransferLine."Item No.", pTransferLine."Variant Code",
                      (SignFactor * TempTrackingSpec."Qty. to Handle (Base)"),
                      pTransferLine."Unit of Measure Code", TempTrackingSpec."Qty. per Unit of Measure",
                      TempTrackingSpec."Serial No.", TempTrackingSpec."Lot No.", TempTrackingSpec."Expiration Date",
                      LineNo, pPickReceivLines);
                until TempTrackingSpec.Next = 0;
            if RemQty <> 0 then
                Error(Text006, pTransferLine.FieldCaption(Quantity), pTransferLine."Item No.");
        end else begin
            if pTransferType = pTransferType::Ship then
                RemQty := pTransferLine."Outstanding Qty. (Base)"
            else
                RemQty := pTransferLine."Qty. in Transit (Base)";
            CreateSplitLine(pTransferLine."Item No.", pTransferLine."Variant Code",
              RemQty,
              pTransferLine."Unit of Measure Code", pTransferLine."Qty. per Unit of Measure",
              '', '', 0D,
              LineNo, pPickReceivLines);
        end;
    end;

    local procedure CreateSplitLine(pItemNo: Code[20]; pVariantCode: Code[10]; pQtyBase: Decimal; pUOM: Code[10]; pQtyPerUOM: Decimal; pSerialNo: Code[50]; pLotNo: Code[50]; pExpirationDate: Date; var pLineNo: Integer; var pPickReceivLines: Record "LSC Picking / Receiving lines")
    begin
        pLineNo := pLineNo + 10000;

        if pQtyPerUOM = 0 then
            pQtyPerUOM := 1;

        pPickReceivLines.Init;
        pPickReceivLines."Line No." := pLineNo;
        pPickReceivLines."Item No." := pItemNo;
        pPickReceivLines."Variant Code" := pVariantCode;
        pPickReceivLines."Unit of Measure Code" := pUOM;
        pPickReceivLines.Quantity := pQtyBase / pQtyPerUOM;
        pPickReceivLines."Serial No." := pSerialNo;
        pPickReceivLines."Lot No." := pLotNo;
        pPickReceivLines."Expiration Date" := pExpirationDate;
        pPickReceivLines.Insert;
    end;

    local procedure FindReservEntries(var pTrackingSpecBuffer: Record "Tracking Specification" temporary; pType: Integer; pSubtype: Integer; pID: Code[20]; pBatchName: Code[10]; pProdOrderLine: Integer; pRefNo: Integer)
    var
        ReservEntry: Record "Reservation Entry";
    begin
        ReservEntry.SetCurrentKey("Source ID", "Source Ref. No.", "Source Type", "Source Subtype", "Source Batch Name",
          "Source Prod. Order Line", "Reservation Status", "Shipment Date", "Expected Receipt Date");
        ReservEntry.SetRange("Source ID", pID);
        ReservEntry.SetRange("Source Ref. No.", pRefNo);
        ReservEntry.SetRange("Source Type", pType);
        ReservEntry.SetRange("Source Subtype", pSubtype);
        ReservEntry.SetRange("Source Batch Name", pBatchName);
        ReservEntry.SetRange("Source Prod. Order Line", pProdOrderLine);
        if ReservEntry.FindSet then
            repeat
                if (ReservEntry."Lot No." <> '') or (ReservEntry."Serial No." <> '') then begin
                    pTrackingSpecBuffer.TransferFields(ReservEntry);
                    pTrackingSpecBuffer."Qty. to Handle" := pTrackingSpecBuffer.CalcQty(pTrackingSpecBuffer."Qty. to Handle (Base)");
                    pTrackingSpecBuffer."Qty. to Invoice" := pTrackingSpecBuffer.CalcQty(pTrackingSpecBuffer."Qty. to Invoice (Base)");
                    pTrackingSpecBuffer.Insert;
                end;
            until ReservEntry.Next = 0;
    end;

    local procedure ResetReservEntries(pType: Integer; pSubtype: Integer; pID: Code[20])
    var
        ReservEntry: Record "Reservation Entry";
    begin
        ReservEntry.SetCurrentKey("Source ID", "Source Ref. No.", "Source Type", "Source Subtype", "Source Batch Name",
          "Source Prod. Order Line", "Reservation Status", "Shipment Date", "Expected Receipt Date");
        ReservEntry.SetRange("Source ID", pID);
        ReservEntry.SetRange("Source Type", pType);
        ReservEntry.SetRange("Source Subtype", pSubtype);
        if ReservEntry.FindSet then
            repeat
                if (ReservEntry."Lot No." <> '') or (ReservEntry."Serial No." <> '') then begin
                    ReservEntry."Qty. to Handle (Base)" := 0;
                    ReservEntry."Qty. to Invoice (Base)" := 0;
                    ReservEntry.Modify;
                end;
            until ReservEntry.Next = 0;
    end;

    local procedure DeleteReservEntries(pType: Integer; pSubtype: Integer; pID: Code[20]; pItemNo: Code[20]; pVariantCode: Code[20]; pSerialNo: Code[50]; pLotNo: Code[50]; var pReservEntryTemp: Record "Reservation Entry" temporary): Decimal
    var
        ReservEntry: Record "Reservation Entry";
        ReservEntry2: Record "Reservation Entry";
        QtyBase: Decimal;
    begin
        QtyBase := 0;

        ReservEntry.SetCurrentKey("Source ID", "Source Ref. No.", "Source Type", "Source Subtype", "Source Batch Name",
          "Source Prod. Order Line", "Reservation Status", "Shipment Date", "Expected Receipt Date");
        ReservEntry.SetRange("Source ID", pID);
        ReservEntry.SetRange("Source Type", pType);
        ReservEntry.SetRange("Source Subtype", pSubtype);
        ReservEntry.SetRange("Item No.", pItemNo);
        ReservEntry.SetRange("Variant Code", pVariantCode);
        ReservEntry.SetRange("Serial No.", pSerialNo);
        ReservEntry.SetRange("Lot No.", pLotNo);
        if ReservEntry.FindSet then
            repeat
                QtyBase := QtyBase + ReservEntry."Quantity (Base)";
                ReservEntry.Delete;
                if ReservEntry."Reservation Status" = ReservEntry."Reservation Status"::Reservation then begin
                    ReservEntry2.Get(ReservEntry."Entry No.", not ReservEntry.Positive);
                    pReservEntryTemp.Init;
                    pReservEntryTemp := ReservEntry2;
                    pReservEntryTemp.Insert;
                    ReservEntry2.Delete;
                end;
            until ReservEntry.Next = 0;

        exit(QtyBase);
    end;

    local procedure InsertPurchLineResEntry(var pPRLineRec: Record "LSC Picking / Receiving lines"; var pPurchHeader: Record "Purchase Header"; var pPurchLine: Record "Purchase Line"; pQtyToUseBase: Decimal)
    var
        ResEntry: Record "Reservation Entry";
        ResEntryTemp: Record "Reservation Entry" temporary;
        QtyBase: Decimal;
        RemQty: Decimal;
        EntryNo: Integer;
    begin
        if (pPRLineRec."Serial No." = '') and (pPRLineRec."Lot No." = '') then
            exit;

        QtyBase := DeleteReservEntries(Database::"Purchase Line", pPurchHeader."Document Type".AsInteger(), pPurchHeader."No.",
          pPurchLine."No.", pPurchLine."Variant Code", pPRLineRec."Serial No.", pPRLineRec."Lot No.", ResEntryTemp);

        ResEntry.Reset;
        if ResEntry.FindLast then
            EntryNo := ResEntry."Entry No."
        else
            EntryNo := 0;

        ResEntryTemp.Reset;
        if ResEntryTemp.FindSet then begin
            RemQty := QtyBase;
            repeat
                if pPurchHeader."Document Type" = pPurchHeader."Document Type"::Order then
                    RemQty := RemQty + ResEntryTemp."Quantity (Base)"
                else
                    RemQty := RemQty - ResEntryTemp."Quantity (Base)";
                EntryNo := EntryNo + 1;
                ResEntry.Init;
                ResEntry := ResEntryTemp;
                ResEntry."Entry No." := EntryNo;
                ResEntry.Insert;
                if pPurchHeader."Document Type" = pPurchHeader."Document Type"::Order then
                    ResEntry.Positive := true
                else
                    ResEntry.Positive := false;
                ResEntry."Source Type" := Database::"Purchase Line";
                ResEntry."Source Subtype" := pPurchHeader."Document Type".AsInteger();
                ResEntry."Source ID" := pPurchHeader."No.";
                ResEntry."Source Ref. No." := pPurchLine."Line No.";
                ResEntry."Source Prod. Order Line" := 0;
                ResEntry."Quantity (Base)" := -ResEntryTemp."Quantity (Base)";
                ResEntry."Qty. to Handle (Base)" := -ResEntryTemp."Qty. to Handle (Base)";
                ResEntry.Quantity := ResEntry."Quantity (Base)" / ResEntry."Qty. per Unit of Measure";
                ResEntry."Qty. to Invoice (Base)" := -ResEntryTemp."Qty. to Invoice (Base)";
                ResEntry.Insert;
            until ResEntryTemp.Next = 0;
            if RemQty <> 0 then
                Error(Text007, pPurchLine.FieldCaption(Quantity), pPurchLine."No.");
        end else begin
            ResEntry.Init;
            EntryNo := EntryNo + 1;
            ResEntry."Entry No." := EntryNo;
            if pPurchHeader."Document Type" = pPurchHeader."Document Type"::Order then
                ResEntry.Positive := true
            else
                ResEntry.Positive := false;
            ResEntry."Item No." := pPurchLine."No.";
            ResEntry."Variant Code" := pPurchLine."Variant Code";
            ResEntry.Description := pPurchLine.Description;
            ResEntry."Location Code" := pPurchLine."Location Code";
            ResEntry."Reservation Status" := ResEntry."Reservation Status"::Surplus;
            ResEntry."Source Type" := Database::"Purchase Line";
            ResEntry."Source Subtype" := pPurchHeader."Document Type".AsInteger();
            ResEntry."Source ID" := pPurchHeader."No.";
            ResEntry."Source Ref. No." := pPurchLine."Line No.";
            ResEntry."Source Prod. Order Line" := 0;
            ResEntry."Qty. per Unit of Measure" := pPurchLine."Qty. per Unit of Measure";
            if ResEntry."Qty. per Unit of Measure" = 0 then
                ResEntry."Qty. per Unit of Measure" := 1;
            if ResEntry.Positive then begin
                if QtyBase = 0 then
                    ResEntry."Quantity (Base)" := pQtyToUseBase
                else
                    ResEntry."Quantity (Base)" := QtyBase;
                ResEntry."Qty. to Handle (Base)" := pQtyToUseBase;
            end else begin
                if QtyBase = 0 then
                    ResEntry."Quantity (Base)" := -pQtyToUseBase
                else
                    ResEntry."Quantity (Base)" := QtyBase;
                ResEntry."Qty. to Handle (Base)" := -pQtyToUseBase;
            end;
            ResEntry.Quantity := ResEntry."Quantity (Base)" / ResEntry."Qty. per Unit of Measure";
            ResEntry."Qty. to Invoice (Base)" := ResEntry."Qty. to Handle (Base)";
            ResEntry."Expected Receipt Date" := pPurchLine."Requested Receipt Date";
            ResEntry."Expiration Date" := pPRLineRec."Expiration Date";
            ResEntry."Serial No." := pPRLineRec."Serial No.";
            ResEntry."Lot No." := pPRLineRec."Lot No.";
            ResEntry.Insert;
        end;
    end;

    local procedure InsertSalesLineResEntry(var pPRLineRec: Record "LSC Picking / Receiving lines"; var pSalesHeader: Record "Sales Header"; var pSalesLine: Record "Sales Line"; pQtyToUseBase: Decimal)
    var
        ResEntry: Record "Reservation Entry";
        ResEntryTemp: Record "Reservation Entry" temporary;
        QtyBase: Decimal;
        RemQty: Decimal;
        EntryNo: Integer;
    begin
        if (pPRLineRec."Serial No." = '') and (pPRLineRec."Lot No." = '') then
            exit;

        QtyBase := DeleteReservEntries(Database::"Sales Line", pSalesHeader."Document Type".AsInteger(), pSalesHeader."No.",
          pSalesLine."No.", pSalesLine."Variant Code", pPRLineRec."Serial No.", pPRLineRec."Lot No.", ResEntryTemp);

        ResEntry.Reset;
        if ResEntry.FindLast then
            EntryNo := ResEntry."Entry No."
        else
            EntryNo := 0;

        ResEntryTemp.Reset;
        if ResEntryTemp.FindSet then begin
            RemQty := -QtyBase;
            repeat
                if pSalesHeader."Document Type" = pSalesHeader."Document Type"::Order then
                    RemQty := RemQty - ResEntryTemp."Quantity (Base)"
                else
                    RemQty := RemQty + ResEntryTemp."Quantity (Base)";
                EntryNo := EntryNo + 1;
                ResEntry.Init;
                ResEntry := ResEntryTemp;
                ResEntry."Entry No." := EntryNo;
                ResEntry.Insert;
                if pSalesHeader."Document Type" = pSalesHeader."Document Type"::Order then
                    ResEntry.Positive := false
                else
                    ResEntry.Positive := true;
                ResEntry."Source Type" := Database::"Sales Line";
                ResEntry."Source Subtype" := pSalesHeader."Document Type".AsInteger();
                ResEntry."Source ID" := pSalesHeader."No.";
                ResEntry."Source Ref. No." := pSalesLine."Line No.";
                ResEntry."Source Prod. Order Line" := 0;
                ResEntry."Quantity (Base)" := -ResEntryTemp."Quantity (Base)";
                ResEntry."Qty. to Handle (Base)" := -ResEntryTemp."Qty. to Handle (Base)";
                ResEntry.Quantity := ResEntry."Quantity (Base)" / ResEntry."Qty. per Unit of Measure";
                ResEntry."Qty. to Invoice (Base)" := -ResEntryTemp."Qty. to Invoice (Base)";
                ResEntry.Insert;
            until ResEntryTemp.Next = 0;
            if RemQty <> 0 then
                Error(Text007, pSalesLine.FieldCaption(Quantity), pSalesLine."No.");
        end else begin
            ResEntry.Init;
            EntryNo := EntryNo + 1;
            ResEntry."Entry No." := EntryNo;
            if pSalesHeader."Document Type" = pSalesHeader."Document Type"::Order then
                ResEntry.Positive := false
            else
                ResEntry.Positive := true;
            ResEntry."Item No." := pSalesLine."No.";
            ResEntry."Variant Code" := pSalesLine."Variant Code";
            ResEntry.Description := pSalesLine.Description;
            ResEntry."Location Code" := pSalesLine."Location Code";
            ResEntry."Reservation Status" := ResEntry."Reservation Status"::Surplus;
            ResEntry."Source Type" := Database::"Sales Line";
            ResEntry."Source Subtype" := pSalesHeader."Document Type".AsInteger();
            ResEntry."Source ID" := pSalesHeader."No.";
            ResEntry."Source Ref. No." := pSalesLine."Line No.";
            ResEntry."Source Prod. Order Line" := 0;
            ResEntry."Qty. per Unit of Measure" := pSalesLine."Qty. per Unit of Measure";
            if ResEntry."Qty. per Unit of Measure" = 0 then
                ResEntry."Qty. per Unit of Measure" := 1;
            if ResEntry.Positive then begin
                if QtyBase = 0 then
                    ResEntry."Quantity (Base)" := pQtyToUseBase
                else
                    ResEntry."Quantity (Base)" := QtyBase;
                ResEntry."Qty. to Handle (Base)" := pQtyToUseBase;
            end else begin
                if QtyBase = 0 then
                    ResEntry."Quantity (Base)" := -pQtyToUseBase
                else
                    ResEntry."Quantity (Base)" := QtyBase;
                ResEntry."Qty. to Handle (Base)" := -pQtyToUseBase;
            end;
            ResEntry.Quantity := ResEntry."Quantity (Base)" / ResEntry."Qty. per Unit of Measure";
            ResEntry."Qty. to Invoice (Base)" := ResEntry."Qty. to Handle (Base)";
            ResEntry."Shipment Date" := pSalesLine."Shipment Date";
            ResEntry."Expiration Date" := pPRLineRec."Expiration Date";
            ResEntry."Serial No." := pPRLineRec."Serial No.";
            ResEntry."Lot No." := pPRLineRec."Lot No.";
            ResEntry.Insert;
        end;
    end;

    local procedure InsertTransLineOutResEntry(var pPRLineRec: Record "LSC Picking / Receiving lines"; var pTransferHeader: Record "Transfer Header"; var pTransferLine: Record "Transfer Line"; pQtyToUseBase: Decimal)
    var
        ResEntry: Record "Reservation Entry";
        ResEntryTemp1: Record "Reservation Entry" temporary;
        ResEntryTemp2: Record "Reservation Entry" temporary;
        QtyBase: Decimal;
        RemQty: Decimal;
        EntryNo: Integer;
    begin
        if (pPRLineRec."Serial No." = '') and (pPRLineRec."Lot No." = '') then
            exit;

        QtyBase := DeleteReservEntries(Database::"Transfer Line", 0, TransferHeader."No.",
          pTransferLine."Item No.", pTransferLine."Variant Code", pPRLineRec."Serial No.", pPRLineRec."Lot No.", ResEntryTemp1);
        QtyBase := DeleteReservEntries(Database::"Transfer Line", 1, TransferHeader."No.",
          pTransferLine."Item No.", pTransferLine."Variant Code", pPRLineRec."Serial No.", pPRLineRec."Lot No.", ResEntryTemp2);

        ResEntry.Reset;
        if ResEntry.FindLast then
            EntryNo := ResEntry."Entry No."
        else
            EntryNo := 0;

        ResEntryTemp1.Reset;
        if ResEntryTemp1.FindSet then begin
            RemQty := QtyBase;
            repeat
                RemQty := RemQty - ResEntryTemp1."Quantity (Base)";
                EntryNo := EntryNo + 1;
                ResEntry.Init;
                ResEntry := ResEntryTemp1;
                ResEntry."Entry No." := EntryNo;
                ResEntry.Insert;
                ResEntry.Positive := false;
                ResEntry."Source Type" := Database::"Transfer Line";
                ResEntry."Source ID" := pTransferHeader."No.";
                ResEntry."Source Ref. No." := pTransferLine."Line No.";
                ResEntry."Source Prod. Order Line" := 0;
                ResEntry."Quantity (Base)" := -ResEntryTemp1."Quantity (Base)";
                ResEntry."Qty. to Handle (Base)" := -ResEntryTemp1."Qty. to Handle (Base)";
                ResEntry.Quantity := ResEntry."Quantity (Base)" / ResEntry."Qty. per Unit of Measure";
                ResEntry."Qty. to Invoice (Base)" := -ResEntryTemp1."Qty. to Invoice (Base)";
                ResEntry.Insert;
            until ResEntryTemp1.Next = 0;
            if RemQty <> 0 then
                Error(Text007, pTransferLine.FieldCaption(Quantity), pTransferLine."Item No.");
        end else begin
            ResEntry.Init;
            EntryNo := EntryNo + 1;
            ResEntry."Entry No." := EntryNo;
            ResEntry."Item No." := pTransferLine."Item No.";
            ResEntry."Variant Code" := pTransferLine."Variant Code";
            ResEntry.Description := pTransferLine.Description;
            ResEntry."Reservation Status" := ResEntry."Reservation Status"::Surplus;
            ResEntry."Source Type" := Database::"Transfer Line";
            ResEntry."Source ID" := pTransferHeader."No.";
            ResEntry."Source Ref. No." := pTransferLine."Line No.";
            ResEntry."Source Prod. Order Line" := 0;
            ResEntry."Qty. per Unit of Measure" := pTransferLine."Qty. per Unit of Measure";
            if ResEntry."Qty. per Unit of Measure" = 0 then
                ResEntry."Qty. per Unit of Measure" := 1;
            ResEntry."Shipment Date" := pTransferLine."Shipment Date";
            ResEntry."Expiration Date" := pPRLineRec."Expiration Date";
            ResEntry."Serial No." := pPRLineRec."Serial No.";
            ResEntry."Lot No." := pPRLineRec."Lot No.";
            ResEntry.Positive := false;
            ResEntry."Source Subtype" := 0;
            ResEntry."Location Code" := pTransferHeader."Transfer-from Code";
            ResEntry."Shipment Date" := pTransferLine."Shipment Date";
            ResEntry."Expected Receipt Date" := 0D;
            if QtyBase = 0 then
                ResEntry."Quantity (Base)" := -pQtyToUseBase
            else
                ResEntry."Quantity (Base)" := -QtyBase;
            ResEntry."Qty. to Handle (Base)" := -pQtyToUseBase;
            ResEntry.Quantity := ResEntry."Quantity (Base)" / ResEntry."Qty. per Unit of Measure";
            ResEntry."Qty. to Invoice (Base)" := ResEntry."Qty. to Handle (Base)";
            ResEntry.Insert;
        end;

        ResEntryTemp2.Reset;
        if ResEntryTemp2.FindSet then begin
            RemQty := QtyBase;
            repeat
                RemQty := RemQty + ResEntryTemp2."Quantity (Base)";
                EntryNo := EntryNo + 1;
                ResEntry.Init;
                ResEntry := ResEntryTemp2;
                ResEntry."Entry No." := EntryNo;
                ResEntry.Insert;
                ResEntry.Positive := true;
                ResEntry."Source Type" := Database::"Transfer Line";
                ResEntry."Source ID" := pTransferHeader."No.";
                ResEntry."Source Ref. No." := pTransferLine."Line No.";
                ResEntry."Source Prod. Order Line" := 0;
                ResEntry."Quantity (Base)" := -ResEntryTemp2."Quantity (Base)";
                ResEntry."Qty. to Handle (Base)" := -ResEntryTemp2."Qty. to Handle (Base)";
                ResEntry.Quantity := ResEntry."Quantity (Base)" / ResEntry."Qty. per Unit of Measure";
                ResEntry."Qty. to Invoice (Base)" := -ResEntryTemp2."Qty. to Invoice (Base)";
                ResEntry.Insert;
            until ResEntryTemp2.Next = 0;
            if RemQty <> 0 then
                Error(Text007, pTransferLine.FieldCaption(Quantity), pTransferLine."Item No.");
        end else begin
            ResEntry.Init;
            EntryNo := EntryNo + 1;
            ResEntry."Entry No." := EntryNo;
            ResEntry."Item No." := pTransferLine."Item No.";
            ResEntry."Variant Code" := pTransferLine."Variant Code";
            ResEntry.Description := pTransferLine.Description;
            ResEntry."Reservation Status" := ResEntry."Reservation Status"::Surplus;
            ResEntry."Source Type" := Database::"Transfer Line";
            ResEntry."Source ID" := pTransferHeader."No.";
            ResEntry."Source Ref. No." := pTransferLine."Line No.";
            ResEntry."Source Prod. Order Line" := 0;
            ResEntry."Qty. per Unit of Measure" := pTransferLine."Qty. per Unit of Measure";
            if ResEntry."Qty. per Unit of Measure" = 0 then
                ResEntry."Qty. per Unit of Measure" := 1;
            ResEntry."Shipment Date" := pTransferLine."Shipment Date";
            ResEntry."Expiration Date" := pPRLineRec."Expiration Date";
            ResEntry."Serial No." := pPRLineRec."Serial No.";
            ResEntry."Lot No." := pPRLineRec."Lot No.";
            ResEntry.Positive := true;
            ResEntry."Source Subtype" := 1;
            ResEntry."Location Code" := pTransferHeader."Transfer-to Code";
            ResEntry."Shipment Date" := 0D;
            ResEntry."Expected Receipt Date" := pTransferLine."Shipment Date";
            if QtyBase = 0 then
                ResEntry."Quantity (Base)" := pQtyToUseBase
            else
                ResEntry."Quantity (Base)" := QtyBase;
            ResEntry."Qty. to Handle (Base)" := pQtyToUseBase;
            ResEntry.Quantity := ResEntry."Quantity (Base)" / ResEntry."Qty. per Unit of Measure";
            ResEntry."Qty. to Invoice (Base)" := ResEntry."Qty. to Handle (Base)";
            ResEntry.Insert;
        end;
    end;

    local procedure InsertTransLineInResEntry(var pPRLineRec: Record "LSC Picking / Receiving lines"; var pTransferHeader: Record "Transfer Header"; var pTransferLine: Record "Transfer Line"; pQtyToUseBase: Decimal)
    var
        ResEntry: Record "Reservation Entry";
        ResEntryTemp: Record "Reservation Entry" temporary;
        QtyBase: Decimal;
        RemQty: Decimal;
        EntryNo: Integer;
    begin
        if (pPRLineRec."Serial No." = '') and (pPRLineRec."Lot No." = '') then
            exit;

        QtyBase := DeleteReservEntries(Database::"Transfer Line", 1, TransferHeader."No.",
          pTransferLine."Item No.", pTransferLine."Variant Code", pPRLineRec."Serial No.", pPRLineRec."Lot No.", ResEntryTemp);

        ResEntry.Reset;
        if ResEntry.FindLast then
            EntryNo := ResEntry."Entry No."
        else
            EntryNo := 0;

        ResEntryTemp.Reset;
        if ResEntryTemp.FindSet then begin
            RemQty := QtyBase;
            repeat
                RemQty := RemQty + ResEntryTemp."Quantity (Base)";
                EntryNo := EntryNo + 1;
                ResEntry.Init;
                ResEntry := ResEntryTemp;
                ResEntry."Entry No." := EntryNo;
                ResEntry.Insert;
                ResEntry.Positive := true;
                ResEntry."Source Type" := Database::"Transfer Line";
                ResEntry."Source ID" := pTransferHeader."No.";
                ResEntry."Source Ref. No." := GetDerivedLineNo(pTransferLine);
                ResEntry."Source Prod. Order Line" := pTransferLine."Line No.";
                ResEntry."Quantity (Base)" := -ResEntryTemp."Quantity (Base)";
                ResEntry."Qty. to Handle (Base)" := -ResEntryTemp."Qty. to Handle (Base)";
                ResEntry.Quantity := ResEntry."Quantity (Base)" / ResEntry."Qty. per Unit of Measure";
                ResEntry."Qty. to Invoice (Base)" := -ResEntryTemp."Qty. to Invoice (Base)";
                ResEntry.Insert;
            until ResEntryTemp.Next = 0;
            if RemQty <> 0 then
                Error(Text007, pTransferLine.FieldCaption(Quantity), pTransferLine."Item No.");
        end else begin
            ResEntry.Init;
            EntryNo := EntryNo + 1;
            ResEntry."Entry No." := EntryNo;
            ResEntry.Positive := true;
            ResEntry."Item No." := pTransferLine."Item No.";
            ResEntry."Variant Code" := pTransferLine."Variant Code";
            ResEntry.Description := pTransferLine.Description;
            ResEntry."Reservation Status" := ResEntry."Reservation Status"::Surplus;
            ResEntry."Source Type" := Database::"Transfer Line";
            ResEntry."Source Subtype" := 1;
            ResEntry."Source ID" := pTransferHeader."No.";
            ResEntry."Source Ref. No." := GetDerivedLineNo(pTransferLine);
            ResEntry."Source Prod. Order Line" := pTransferLine."Line No.";
            ResEntry."Qty. per Unit of Measure" := pTransferLine."Qty. per Unit of Measure";
            if ResEntry."Qty. per Unit of Measure" = 0 then
                ResEntry."Qty. per Unit of Measure" := 1;
            ResEntry."Shipment Date" := pTransferLine."Shipment Date";
            ResEntry."Expiration Date" := pPRLineRec."Expiration Date";
            ResEntry."Serial No." := pPRLineRec."Serial No.";
            ResEntry."Lot No." := pPRLineRec."Lot No.";
            ResEntry."Location Code" := pTransferHeader."Transfer-to Code";
            ResEntry."Shipment Date" := 0D;
            ResEntry."Expected Receipt Date" := pTransferLine."Shipment Date";
            if QtyBase = 0 then
                ResEntry."Quantity (Base)" := pQtyToUseBase
            else
                ResEntry."Quantity (Base)" := QtyBase;
            ResEntry."Qty. to Handle (Base)" := pQtyToUseBase;
            ResEntry.Quantity := ResEntry."Quantity (Base)" / ResEntry."Qty. per Unit of Measure";
            ResEntry."Qty. to Invoice (Base)" := ResEntry."Qty. to Handle (Base)";
            ResEntry.Insert;
        end;
    end;

    local procedure GetDerivedLineNo(var pTransferLine: Record "Transfer Line"): Integer
    var
        TransferLine: Record "Transfer Line";
    begin
        TransferLine.Reset;
        TransferLine.SetCurrentKey("Transfer-to Code", Status, "Derived From Line No.");
        TransferLine.SetRange("Transfer-to Code", pTransferLine."Transfer-to Code");
        TransferLine.SetRange("Derived From Line No.", pTransferLine."Line No.");
        if TransferLine.FindFirst then
            exit(TransferLine."Line No.")
        else
            exit(0);
    end;

    [Scope('OnPrem')]
    procedure ActionIsCreateDoc(var pCountingHeader: Record "LSC P/R Counting Header"): Boolean
    var
        lAnswer: Boolean;
    begin
        lAnswer := false;
        if (pCountingHeader.Receiving = pCountingHeader.Receiving::"Purchase Order(create)") or
           (pCountingHeader.Picking = pCountingHeader.Picking::"Sales Order (create)") or
           (pCountingHeader.Picking = pCountingHeader.Picking::"Purchase Return Order (create)") or
           (pCountingHeader.Picking = pCountingHeader.Picking::"Transfer Out (create)")
        then
            lAnswer := true;

        exit(lAnswer);
    end;

    local procedure UpdateOutstandingQty(ItemNo: Code[20]; QtyOutstandingBase: Decimal; var OutstandingLinesTMP: Record "LSC Picking / Receiving lines")
    var
        LastLineNo: Integer;
    begin
        OutstandingLinesTMP.Reset;
        OutstandingLinesTMP.SetRange("Item No.", ItemNo);
        if OutstandingLinesTMP.FindFirst then begin
            OutstandingLinesTMP.Quantity := OutstandingLinesTMP.Quantity + QtyOutstandingBase;
            if OutstandingLinesTMP.Quantity = 0 then
                OutstandingLinesTMP.Delete
            else
                OutstandingLinesTMP.Modify;
        end
        else begin
            OutstandingLinesTMP.Reset;
            if OutstandingLinesTMP.FindLast then
                LastLineNo := OutstandingLinesTMP."Line No."
            else
                LastLineNo := 0;
            Clear(OutstandingLinesTMP);
            OutstandingLinesTMP."Line No." := LastLineNo + 10000;
            OutstandingLinesTMP."Item No." := ItemNo;
            OutstandingLinesTMP.Quantity := QtyOutstandingBase;
            OutstandingLinesTMP.Insert;
        end;
    end;

    local procedure PickingReceivingPreReleaseTransferOrder(var TransferHeader_p: Record "Transfer Header")
    var
        TransLine: Record "Transfer Line";
    begin
        if TransferHeader_p.Status = TransferHeader_p.Status::Open then begin
            TransLine.SetRange("Document No.", TransferHeader_p."No.");
            TransLine.SetFilter(Quantity, '<>0');
            if TransLine.IsEmpty and (TransferHeader_p."LSC Reciving/Picking No." <> '') then
                TransferHeader_p.Status := TransferHeader_p.Status::Released;
        end;
    end;

    [Scope('OnPrem')]
    procedure CompressReceivingLines(var CountingHeader: Record "LSC P/R Counting Header")
    var
        Receivinglines: array[2] of Record "LSC Picking / Receiving lines";
        ReceivinglinesTemporary: Record "LSC Picking / Receiving lines" temporary;
        LastLineNo: Integer;
        NextLineNo: Integer;
        CountingHeaderStatus: Integer;
    begin
        CountingHeaderStatus := CountingHeader.Status;

        Receivinglines[1].LockTable;
        Receivinglines[1].SetRange("Document No.", CountingHeader."No.");
        if Receivinglines[1].FindLast then
            LastLineNo := Receivinglines[1]."Line No.";

        Clear(ReceivinglinesTemp[1]);
        ReceivinglinesTemp[1].DeleteAll;
        Clear(ReceivinglinesTemp[2]);
        ReceivinglinesTemp[2].DeleteAll;

        Receivinglines[1].SetCurrentKey("Document No.", "Item No.", "Variant Code", Status);
        Receivinglines[1].SetFilter("Line No.", '..%1', LastLineNo);
        if Receivinglines[1].FindSet then
            repeat
                ReceivinglinesTemp[1].Init;
                ReceivinglinesTemp[1] := Receivinglines[1];
                UpdateCompressedReceivingLines;
            until Receivinglines[1].Next = 0;
        // delete the original lines
        Receivinglines[1].Deleteall;

        // Recreate lines as compressed
        NextLineNo := LastLineNo;
        ReceivinglinesTemp[1].Reset;
        if ReceivinglinesTemp[1].FindSet then begin
            repeat
                Item.Get(ReceivinglinesTemp[1]."Item No.");
                NextLineNo := NextLineNo + 10000;
                Receivinglines[2].Init;
                Receivinglines[2]."Document No." := CountingHeader."No.";
                Receivinglines[2]."Line No." := NextLineNo;
                Receivinglines[2]."Purchase Order No." := ReceivinglinesTemp[1]."Purchase Order No.";
                Receivinglines[2]."ASN Delivery Doc. Line No." := ReceivinglinesTemp[1]."ASN Delivery Doc. Line No.";
                Receivinglines[2].Validate("Item No.", ReceivinglinesTemp[1]."Item No.");
                Receivinglines[2].Validate("Variant Code", ReceivinglinesTemp[1]."Variant Code");
                Receivinglines[2]."Ordered Qty." := ReceivinglinesTemp[1]."Ordered Qty. (base)";
                Receivinglines[2]."Ordered Qty. (base)" := ReceivinglinesTemp[1]."Ordered Qty. (base)";
                Receivinglines[2].Quantity := ReceivinglinesTemp[1]."Quantity (base)";
                Receivinglines[2]."Qty. Difference" := ReceivinglinesTemp[1]."Qty. Difference (base)";
                Receivinglines[2]."Qty. Difference (base)" := ReceivinglinesTemp[1]."Qty. Difference (base)";
                Receivinglines[2]."Unit of Measure Code" := Item."Base Unit of Measure";
                Receivinglines[2]."Serial No." := ReceivinglinesTemp[1]."Serial No.";
                Receivinglines[2]."Lot No." := ReceivinglinesTemp[1]."Lot No.";
                if (Receivinglines[2]."Serial No." <> '') or (Receivinglines[2]."Lot No." <> '') then
                    Receivinglines[2]."Expiration Date" := ReceivinglinesTemp[1]."Expiration Date";
                Receivinglines[2]."Posting Action" := ReceivinglinesTemp[1]."Posting Action";
                Receivinglines[2]."Reason Code" := ReceivinglinesTemp[1]."Reason Code";
                Receivinglines[2]."Purchase Order No." := ReceivinglinesTemp[1]."Purchase Order No.";
                Receivinglines[2]."To Location" := ReceivinglinesTemp[1]."To Location";
                // validate nessasary fields
                Receivinglines[2].Validate("Unit of Measure Code");
                // reinsert Posting Action after validate of UOM code
                Receivinglines[2]."Posting Action" := ReceivinglinesTemp[1]."Posting Action";
                Receivinglines[2].Validate("Serial No.");
                Receivinglines[2].Validate("Lot No.");
                if (Receivinglines[2]."Serial No." <> '') or (Receivinglines[2]."Lot No." <> '') then
                    Receivinglines[2].Validate("Expiration Date");
                Receivinglines[2].Insert(true);
            until ReceivinglinesTemp[1].Next = 0;
            CountingHeader.Get(CountingHeader."No.");
            CountingHeader.Status := CountingHeaderStatus;
            CountingHeader.Modify;
        end;
    end;

    local procedure UpdateCompressedReceivingLines()
    begin
        ReceivinglinesTemp[2].SetRange("Item No.", ReceivinglinesTemp[1]."Item No.");
        ReceivinglinesTemp[2].SetRange("Variant Code", ReceivinglinesTemp[1]."Variant Code");
        ReceivinglinesTemp[2].SetRange("Serial No.", ReceivinglinesTemp[1]."Serial No.");
        ReceivinglinesTemp[2].SetRange("Lot No.", ReceivinglinesTemp[1]."Lot No.");
        ReceivinglinesTemp[2].SetRange("Expiration Date", ReceivinglinesTemp[1]."Expiration Date");
        ReceivinglinesTemp[2].SetRange("Posting Action", ReceivinglinesTemp[1]."Posting Action");
        ReceivinglinesTemp[2].SetRange("Purchase Order No.", ReceivinglinesTemp[1]."Purchase Order No.");
        ReceivinglinesTemp[2].SetRange("ASN Delivery Doc. Line No.", ReceivinglinesTemp[1]."ASN Delivery Doc. Line No.");
        ReceivinglinesTemp[2].SetRange("Reason Code", ReceivinglinesTemp[1]."Reason Code");
        ReceivinglinesTemp[2].SetRange("To Location", ReceivinglinesTemp[1]."To Location");
        if ReceivinglinesTemp[2].FindFirst then begin
            ReceivinglinesTemp[2]."Quantity (base)" := ReceivinglinesTemp[2]."Quantity (base)" + ReceivinglinesTemp[1]."Quantity (base)";
            ReceivinglinesTemp[2]."Ordered Qty. (base)" := ReceivinglinesTemp[2]."Ordered Qty. (base)" + ReceivinglinesTemp[1]."Ordered Qty. (base)";
            ReceivinglinesTemp[2]."Qty. Difference (base)" := ReceivinglinesTemp[2]."Qty. Difference (base)" + ReceivinglinesTemp[1]."Qty. Difference (base)";
            ReceivinglinesTemp[2].Modify;
            Commit;
        end else
            ReceivinglinesTemp[1].Insert;
    end;

    procedure CheckVendorInvoiceNo(PRCountingHeader: Record "LSC P/R Counting Header"; PurchaseOrderNo: Code[20])
    var
        PurchaseHeader_L: Record "Purchase Header";
        VendorLedgerEntry_L: Record "Vendor Ledger Entry";
    begin
        PurchPaySetup.Get();
        if not PurchaseHeader_L.Get(PurchaseHeader_L."Document Type"::Order, PurchaseOrderNo) then
            exit;
        if not PurchPaySetup."Ext. Doc. No. Mandatory" then
            exit;
        if (PRCountingHeader."Retail Status" = PRCountingHeader."Retail Status"::"Closed - ok") and (PRCountingHeader."Vendor Invoice No." <> '') then
            exit;
        PurchaseHeader_L.TestField("Vendor Invoice No.");
        VendorLedgerEntry_L.Reset;
        VendorLedgerEntry_L.SetCurrentKey("Document No.");
        VendorLedgerEntry_L.SetRange("Document No.", PurchaseHeader_L."Vendor Invoice No.");
        VendorLedgerEntry_L.SetRange("Vendor No.", PurchaseHeader_L."Buy-from Vendor No.");
        if not VendorLedgerEntry_L.IsEmpty then
            Error(Text013, PurchaseHeader_L."Vendor Invoice No.", PurchaseHeader_L."Buy-from Vendor No.", PurchaseOrderNo);
    end;

    procedure SetReceivingPostMethod(StatusPost_P: Integer)
    begin
        SetStatusPostMethod := StatusPost_P;
    end;

    procedure GetRetailReceivingMenuOptions(): Text
    begin
        exit(Text011);
    end;

    procedure GetRetailPickingMenuOptions(): text
    begin
        exit(Text012);
    end;

    procedure GetStatusConfirmedError(): Text
    begin
        exit(Text004);
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterCreateSplitLine(var PickReceivLines: Record "LSC Picking / Receiving lines"; var pPurchaseLine: Record "Purchase Line"; IsEmpty: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterUpdatePurchaseLine(var CountingHeader: Record "LSC P/R Counting Header"; PickReceivLines: Record "LSC Picking / Receiving lines"; var PurchaseHeader: Record "Purchase Header")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeModifyPurchHeaderInUpdateSourceStatus(var CountingHeader: Record "LSC P/R Counting Header"; var PurchaseHeader: Record "Purchase Header")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeModifySalesOrderInUpdateSourceStatus(var CountingHeader: Record "LSC P/R Counting Header"; var SalesHeader: Record "Sales Header")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeModifyTransferHeaderInUpdateSourceStatus(var CountingHeader: Record "LSC P/R Counting Header"; var TransferHeader: Record "Transfer Header")
    begin
    end;

    [EventSubscriber(ObjectType::Table, 39, 'OnValidateQtyToReceiveOnAfterInitQty', '', false, false)]
    local procedure UpdatePurchaseOrderLineQty(var PurchaseLine: Record "Purchase Line"; var xPurchaseLine: Record "Purchase Line"; CallingFieldNo: Integer; var IsHandled: Boolean)
    var
        ASNDeliveryDocumentLine: Record "LSC ASN Delivery Document Line";
        ReceivingHeader: Record "LSC P/R Counting Header";
        ReceivingLines: Record "LSC Picking / Receiving lines";
    begin
        if PurchaseLine.Type <> PurchaseLine.Type::Item then
            exit;

        ASNDeliveryDocumentLine.SetRange("Purchase Order No.", PurchaseLine."Document No.");
        ASNDeliveryDocumentLine.SetRange("Purchase Order Line No.", PurchaseLine."Line No.");
        if ASNDeliveryDocumentLine.FindFirst() then begin
            ReceivingHeader.SetCurrentKey("Counting Type", Receiving, "Reference No.");
            ReceivingHeader.SetRange("Counting Type", ReceivingHeader."Counting Type"::Receiving);
            ReceivingHeader.SetRange(Receiving, ReceivingHeader.Receiving::"ASN Delivery Document");
            ReceivingHeader.SetRange("Reference No.", ASNDeliveryDocumentLine."Document No.");
            if ReceivingHeader.findfirst then begin
                ReceivingLines.SetRange("Document No.", ReceivingHeader."No.");
                ReceivingLines.SetRange("Item No.", ASNDeliveryDocumentLine."Item No.");
                ReceivingLines.SetRange("Variant Code", ASNDeliveryDocumentLine."Variant Code");
                Receivinglines.SetRange("ASN Delivery Doc. Line No.", ASNDeliveryDocumentLine."Line No.");
                if ReceivingLines.FindFirst() then
                    if ReceivingLines."Posting Action" = ReceivingLines."Posting Action"::"Adjust Order" then
                        IsHandled := true;
            end;
        end;
    end;
}

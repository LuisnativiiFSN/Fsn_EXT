codeunit 50060 DeleteOldPurchaseOrders
{
    // 
    // CSPNT061117 No tratar de borrar Purchase Line que tengan Warehouse Receipt Line relacionadas
    // CSPNT230118 Nueva funcion de la tabla Purchase Header para el borrado
    // WVILLALTA13DIC18          - Validacion extra, la cantidad en campo "Days" debe ser mayor a cero para procesar


    trigger OnRun()
    var
        rWarehouseReceiptLine: Record "Warehouse Receipt Line";
        vBorrar: Boolean;
        vEncontradas: Integer;
    begin
        PurchaseOrder.RESET;
        Store.RESET;
        DelDate.RESET;
        Counter := 0;

        //Store.SETRANGE("Location Profile", 'ALL');
        //Store.SETFILTER("No.", 'F98'); //WVILLALTA13DIC18-+
        //Store.SETRANGE("Global Dimension 1 Code", 'SALES'); Como segunda capa opcional
        IF Store.FIND('-') THEN
            REPEAT
                IF DelDate.GET(Store."No.") THEN
                    IF DelDate.Days > 0 THEN BEGIN //WVILLALTA13DIC18-+
                        EVALUATE(DaysAgo, '-' + FORMAT(DelDate.Days) + 'D');
                        PurchaseOrder.RESET;
                        PurchaseOrder.SETRANGE("Location Code", Store."Location Code");
                        PurchaseOrder.SETFILTER("Order Date", '<%1', CALCDATE(DaysAgo));
                        PurchaseOrder.SETRANGE("Document Type", PurchaseOrder."Document Type"::Order);
                        PurchaseOrder.SETFILTER(PurchaseOrder."Buy-from Vendor No.", '<>%1', '1185'); //DOLLAR Temporary WVILLALTA 03.21-+
                        IF PurchaseOrder.FIND('-') THEN
                            REPEAT
                                //CSPNT061117
                                vBorrar := TRUE;
                                //vEncontradas += 1;
                                PurchaseLines.RESET;
                                PurchaseLines.SETRANGE("Document No.", PurchaseOrder."No.");
                                //CSPNT061117
                                IF PurchaseLines.FIND('-') THEN BEGIN
                                    //CSPNT061117+
                                    /*REPEAT
                                      DeletedPurchHistory.INIT;
                                      DeletedPurchHistory.TRANSFERFIELDS(PurchaseLines);
                                      DeletedPurchHistory.INSERT;
                                    UNTIL PurchaseLines.NEXT = 0;
                                    //CSMQ140916-
                                    IF NOT PurchaseOrder.DELETE(TRUE) THEN BEGIN
                                      PurchaseOrder."General Comments" := 'DELPURCHORD. Error: Orden no se pudo eliminar';
                                      PurchaseOrder.MODIFY(TRUE);
                                    END;
                                    //CSMQ140916+
                                    Counter += 1;*///CSPNT061117-
                                    REPEAT
                                        rWarehouseReceiptLine.RESET;
                                        rWarehouseReceiptLine.SETRANGE("Location Code", PurchaseLines."Location Code");
                                        rWarehouseReceiptLine.SETRANGE("Source No.", PurchaseLines."Document No.");
                                        rWarehouseReceiptLine.SETRANGE("Source Line No.", PurchaseLines."Line No.");
                                        rWarehouseReceiptLine.SETRANGE("Item No.", PurchaseLines."No.");
                                        rWarehouseReceiptLine.SETRANGE(Quantity, PurchaseLines.Quantity);
                                        IF rWarehouseReceiptLine.FIND('-') THEN
                                            vBorrar := FALSE;
                                    UNTIL (vBorrar = FALSE) OR (PurchaseLines.NEXT <= 0);

                                    IF vBorrar THEN BEGIN
                                        PurchaseLines.FIND('-');
                                        REPEAT
                                            DeletedPurchHistory.INIT;
                                            DeletedPurchHistory."Document Type" := PurchaseLines."Document Type";
                                            DeletedPurchHistory."Buy-from Vendor No." := PurchaseLines."Buy-from Vendor No.";
                                            DeletedPurchHistory."Document No." := PurchaseLines."Document No.";
                                            DeletedPurchHistory."Line No." := PurchaseLines."Line No.";
                                            DeletedPurchHistory.Type := PurchaseLines.Type;
                                            DeletedPurchHistory."No." := PurchaseLines."No.";
                                            DeletedPurchHistory."Location Code" := PurchaseLines."Location Code";
                                            DeletedPurchHistory."Posting Group" := PurchaseLines."Posting Group";
                                            DeletedPurchHistory."Expected Receipt Date" := PurchaseLines."Expected Receipt Date";
                                            DeletedPurchHistory.Description := PurchaseLines.Description;
                                            DeletedPurchHistory."Description 2" := PurchaseLines."Description 2";
                                            DeletedPurchHistory."Unit of Measure" := PurchaseLines."Unit of Measure";
                                            DeletedPurchHistory.Quantity := PurchaseLines.Quantity;
                                            DeletedPurchHistory."Outstanding Quantity" := PurchaseLines."Outstanding Quantity";
                                            DeletedPurchHistory."Qty. to Invoice" := PurchaseLines."Qty. to Invoice";
                                            DeletedPurchHistory."Qty. to Receive" := PurchaseLines."Qty. to Receive";
                                            DeletedPurchHistory."Direct Unit Cost" := PurchaseLines."Direct Unit Cost";
                                            DeletedPurchHistory."Unit Cost (LCY)" := PurchaseLines."Unit Cost (LCY)";
                                            DeletedPurchHistory."VAT %" := PurchaseLines."VAT %";
                                            DeletedPurchHistory."Line Discount %" := PurchaseLines."Line Discount %";
                                            DeletedPurchHistory."Line Discount Amount" := PurchaseLines."Line Discount Amount";
                                            DeletedPurchHistory.Amount := PurchaseLines.Amount;
                                            DeletedPurchHistory."Amount Including VAT" := PurchaseLines."Amount Including VAT";
                                            DeletedPurchHistory."Unit Price (LCY)" := PurchaseLines."Unit Price (LCY)";
                                            DeletedPurchHistory."Allow Invoice Disc." := PurchaseLines."Allow Invoice Disc.";
                                            DeletedPurchHistory."Gross Weight" := PurchaseLines."Gross Weight";
                                            DeletedPurchHistory."Net Weight" := PurchaseLines."Net Weight";
                                            DeletedPurchHistory."Units per Parcel" := PurchaseLines."Units per Parcel";
                                            DeletedPurchHistory."Unit Volume" := PurchaseLines."Unit Volume";
                                            DeletedPurchHistory."Appl.-to Item Entry" := PurchaseLines."Appl.-to Item Entry";
                                            DeletedPurchHistory."Shortcut Dimension 1 Code" := PurchaseLines."Shortcut Dimension 1 Code";
                                            DeletedPurchHistory."Shortcut Dimension 2 Code" := PurchaseLines."Shortcut Dimension 2 Code";
                                            DeletedPurchHistory."Job No." := PurchaseLines."Job No.";
                                            DeletedPurchHistory."Indirect Cost %" := PurchaseLines."Indirect Cost %";
                                            DeletedPurchHistory."Outstanding Amount" := PurchaseLines."Outstanding Amount";
                                            DeletedPurchHistory."Qty. Rcd. Not Invoiced" := PurchaseLines."Qty. Rcd. Not Invoiced";
                                            DeletedPurchHistory."Amt. Rcd. Not Invoiced" := PurchaseLines."Amt. Rcd. Not Invoiced";
                                            DeletedPurchHistory."Quantity Received" := PurchaseLines."Quantity Received";
                                            DeletedPurchHistory."Receipt No." := PurchaseLines."Receipt No.";
                                            DeletedPurchHistory."Receipt Line No." := PurchaseLines."Receipt Line No.";
                                            DeletedPurchHistory."Profit %" := PurchaseLines."Profit %";
                                            DeletedPurchHistory."Pay-to Vendor No." := PurchaseLines."Pay-to Vendor No.";
                                            DeletedPurchHistory."Inv. Discount Amount" := PurchaseLines."Inv. Discount Amount";
                                            DeletedPurchHistory."Vendor Item No." := PurchaseLines."Vendor Item No.";
                                            DeletedPurchHistory."Sales Order No." := PurchaseLines."Sales Order No.";
                                            DeletedPurchHistory."Sales Order Line No." := PurchaseLines."Sales Order Line No.";
                                            DeletedPurchHistory."Drop Shipment" := PurchaseLines."Drop Shipment";
                                            DeletedPurchHistory."Gen. Bus. Posting Group" := PurchaseLines."Gen. Bus. Posting Group";
                                            DeletedPurchHistory."Gen. Prod. Posting Group" := PurchaseLines."Gen. Prod. Posting Group";
                                            DeletedPurchHistory."Transaction Type" := PurchaseLines."Transaction Type";
                                            DeletedPurchHistory."VAT Bus. Posting Group" := PurchaseLines."VAT Bus. Posting Group";
                                            DeletedPurchHistory."VAT Prod. Posting Group" := PurchaseLines."VAT Prod. Posting Group";
                                            DeletedPurchHistory."Outstanding Amount (LCY)" := PurchaseLines."Outstanding Amount (LCY)";
                                            DeletedPurchHistory."Amt. Rcd. Not Invoiced (LCY)" := PurchaseLines."Amt. Rcd. Not Invoiced (LCY)";
                                            DeletedPurchHistory."VAT Base Amount" := PurchaseLines."VAT Base Amount";
                                            DeletedPurchHistory."Unit Cost" := PurchaseLines."Unit Cost";
                                            DeletedPurchHistory."Line Amount" := PurchaseLines."Line Amount";
                                            DeletedPurchHistory."VAT Identifier" := PurchaseLines."VAT Identifier";
                                            DeletedPurchHistory."Outstanding Amt. Ex. VAT (LCY)" := DeletedPurchHistory."Outstanding Amt. Ex. VAT (LCY)";
                                            DeletedPurchHistory."Qty. per Unit of Measure" := PurchaseLines."Qty. per Unit of Measure";
                                            DeletedPurchHistory."Unit of Measure Code" := PurchaseLines."Unit of Measure Code";
                                            DeletedPurchHistory."Quantity (Base)" := PurchaseLines."Quantity (Base)";
                                            DeletedPurchHistory."Outstanding Qty. (Base)" := PurchaseLines."Outstanding Qty. (Base)";
                                            DeletedPurchHistory."Unit of Measure (Cross Ref.)" := PurchaseLines."Unit of Measure (Cross Ref.)";
                                            DeletedPurchHistory."Cross-Reference Type" := PurchaseLines."Cross-Reference Type";
                                            DeletedPurchHistory."Cross-Reference Type No." := PurchaseLines."Cross-Reference Type No.";
                                            DeletedPurchHistory."Item Category Code" := PurchaseLines."Item Category Code";
                                            DeletedPurchHistory."Planned Receipt Date" := PurchaseLines."Planned Receipt Date";
                                            DeletedPurchHistory."Order Date" := PurchaseLines."Order Date";
                                            DeletedPurchHistory."Allow Item Charge Assignment" := PurchaseLines."Allow Item Charge Assignment";
                                            DeletedPurchHistory.Division := PurchaseLines."LSC Division";
                                            //DeletedPurchHistory.TRANSFERFIELDS(PurchaseLines);
                                            DeletedPurchHistory.INSERT;
                                            //Asignar 0 a cantidad a facturar
                                            PurchaseLines."Qty. to Invoice" := 0;
                                            PurchaseLines."Qty. Rcd. Not Invoiced" := 0;
                                            PurchaseLines.MODIFY;
                                        UNTIL PurchaseLines.NEXT <= 0;

                                        //CSPNT230118IF NOT PurchaseOrder.DELETE(TRUE) THEN BEGIN
                                        DeleteFromJob(PurchaseOrder);
                                        IF NOT PurchaseOrder.DELETE THEN BEGIN
                                            PurchaseOrder."LSC General Comments" := 'DELPURCHORD. Error: Orden no se pudo eliminar';
                                            PurchaseOrder.MODIFY(TRUE);
                                        END;
                                        COMMIT;
                                        Counter += 1;
                                    END;

                                    //CSPNT061117
                                END  //CSMQ300117
                                     //CSPNT Borrar aunque no tenga lineas
                                ELSE BEGIN
                                    //CSPNT230118IF NOT PurchaseOrder.DELETE(TRUE) THEN BEGIN
                                    DeleteFromJob(PurchaseOrder);
                                    IF NOT PurchaseOrder.DELETE THEN BEGIN
                                        PurchaseOrder."LSC General Comments" := 'DELPURCHORD. Error: Orden no se pudo eliminar';
                                        PurchaseOrder.MODIFY(TRUE);
                                    END;
                                    Counter += 1;
                                END;
                            UNTIL PurchaseOrder.NEXT = 0;
                    END;
            UNTIL Store.NEXT = 0;

        //MESSAGE('Encontradas: %1, a borrar: %2',vEncontradas,Counter);

        //Si se desea mensaje de confirmacion
        /*IF Counter > 0 THEN
          IF Counter = 1 THEN
            MESSAGE('Proceso Finalizado, se elimino %1 orden de compra', Counter)
          ELSE
            MESSAGE('Proceso Finalizado, se eliminaron %1 ordenes de compra', Counter)
        ELSE
          MESSAGE('Proceso Finalizado, no se eliminaron ordenes de compra');*/

    end;

    procedure DeleteFromJob(PurchaceH: Record "Purchase Header")
    var
        DocGroupLine: Record "LSC Document Group Line";
        PurchLine: Record "Purchase Line";
    begin
        //CSPNT230118
        IF NOT UserSetupMgt.CheckRespCenter(1, PurchaceH."Responsibility Center") THEN
            ERROR(Text023, RespCenter.TABLECAPTION, UserSetupMgt.GetPurchasesFilter);

        Evaluate(PurchaceH."Applies-to ID", '');

        //LS -
        /*IF BOUtils.IsInStorePermitted THEN
            InStoreMgt.SendPurchaseDocDelete(Rec);*/
        //LS +

        //ApprovalMgt.DeleteApprovalEntry(DATABASE::"Purchase Header", PurchaceH."Document Type", PurchaceH."No.");
        PurchLine.LOCKTABLE;

        WhseRequest.SETRANGE("Source Type", DATABASE::"Purchase Line");
        WhseRequest.SETRANGE("Source Subtype", PurchaceH."Document Type");
        WhseRequest.SETRANGE("Source No.", PurchaceH."No.");
        WhseRequest.DELETEALL(TRUE);

        PurchLine.SETRANGE("Document Type", PurchaceH."Document Type");
        PurchLine.SETRANGE("Document No.", PurchaceH."No.");
        PurchLine.SETRANGE(Type, PurchLine.Type::"Charge (Item)");
        DeletePurchaseLines(PurchLine);
        PurchLine.SETRANGE(Type);
        DeletePurchaseLines(PurchLine);

        PurchCommentLine.SETRANGE("Document Type", PurchaceH."Document Type");
        PurchCommentLine.SETRANGE("No.", PurchaceH."No.");
        PurchCommentLine.DELETEALL;

        //LS -
        IF (PurchaceH."Document Type" = PurchaceH."Document Type"::Order) AND (BOUtils.IsOpenToBuyPermitted()) THEN
            OpenToBuyUtils.ReOpenOrder(PurchaceH."No.");

        IF PurchaceH."Document Type" = PurchaceH."Document Type"::Order THEN BEGIN
            DocGroupLine.RESET;
            DocGroupLine.SETRANGE("Reference Type", DocGroupLine."Reference Type"::Purchase);
            DocGroupLine.SETRANGE("Reference No.", PurchaceH."No.");
            IF NOT DocGroupLine.ISEMPTY THEN
                DocGroupLine.DELETEALL;
        END;
        //LS +
    end;

    procedure DeletePurchaseLines(var PurchLine: Record "Purchase Line")
    begin
        IF PurchLine.FINDSET THEN BEGIN
            //HandleItemTrackingDeletion;
            REPEAT
                PurchLine.SuspendStatusCheck(TRUE);
                PurchLine.DELETE(TRUE);
            UNTIL PurchLine.NEXT = 0;
        END;
    end;

    var
        PurchaseOrder: Record "Purchase Header";
        PurchaseLines: Record "Purchase Line";
        DeletedPurchHistory: Record "FSN Deleted Purchase Lines";
        //DeletedPurchHistory: Record "FSN Deleted Purch. Order Lines";
        DelDate: Record "FSN Fasani Setup";
        Counter: Integer;
        Store: Record "LSC Store";
        DaysAgo: DateFormula;
        UserSetupMgt: Codeunit "User Setup Management";
        RespCenter: Record "Responsibility Center";
        WhseRequest: Record "Warehouse Request";
        BOUtils: Codeunit "LSC BO Utils";
        InStoreMgt: Codeunit "LSC InStore Mgt";
        ApprovalMgt: Codeunit "Export F/O Consolidation";
        OpenToBuyUtils: Codeunit "LSC Open to Buy Utils";
        PurchCommentLine: Record "Purch. Comment Line";
        Text023: Label 'You cannot delete this document. Your identification is set up to process from %1 %2 only.';
}


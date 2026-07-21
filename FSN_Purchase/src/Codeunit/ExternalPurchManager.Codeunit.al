codeunit 50001 "FSN External Purch. Manager"
{
    Permissions = TableData "Purch. Inv. Header" = rim;
    TableNo = "LSC Scheduler Job Header";

    trigger OnRun()
    var
        Purch: Code[20];
        Invoice: Code[50];
        QryVendorPending: Query "FSN External Document Invoice";
        TextError: Text[50];
        _OptionValue: Option New,Received,ReceiptCreated,ErrorValidation,CloseErasePurch,PurchNotExists,Canceled;
        QryPurchConsistency: Query "FSN External Purc. Consistency";
    begin
        IF Code <> '' THEN
            GlobalSerieExternalDoc := Code;

        QryVendorPending.OPEN;
        WHILE QryVendorPending.READ DO BEGIN
            IF EVALUATE(Purch, QryVendorPending.No_) AND EVALUATE(Invoice, QryVendorPending.External_Document_No) THEN
                TextError := '';
            _OptionValue := QryVendorPending.Status_Sub_Line;
            IF (Purch <> '') AND (Invoice <> '') THEN
                IF NOT Sincronize(Purch, Invoice, _OptionValue, TextError) THEN
                    UpdateErrorLines(Purch, Invoice, TextError);
        END;
        QryVendorPending.CLOSE;

        QryPurchConsistency.SETRANGE(QryPurchConsistency.Status_Sub_Line, QryPurchConsistency.Status_Sub_Line::Received);
        QryPurchConsistency.OPEN;
        WHILE QryPurchConsistency.READ DO BEGIN
            SincronizeConsistency(QryPurchConsistency.No, QryPurchConsistency.Sum_Qty_to_Ship);
        END;

        if Rec.Code = 'PROSESSAPLAUT' then begin
            ProcessRecepComMin(2, Rec.Integer, Rec.Text);
        end;
    end;

    var
        gText001: Label 'Sub Linea %2 no existe tabla %1';
        gText002: Label 'No se puede crear recepcion LS. Error: %1';
        gText003: Label 'La cantidad a recibir no puede ser cero';
        gText004: Label 'Linea %1 cantidad a recibir %2 supera la solicitada %3';
        gText005: Label 'La recepción fue generada automatica (%1), ¿En verdad desea eliminarla?';
        gText006: Label 'No puede borrar una linea generada automaticamente';
        gText007: Label 'No puede modificar una recepción generada automaticamente';
        gText008: Label 'La cantidad del producto %1 no es correcta, debe ingresar %2 %3 o %4 %5, diferencia de %6';
        lTxt0: Label 'El costo del producto %1 no puede ser cero o estar vacio';
        GlobalPurchNo_: Code[20];
        GlobalInvoiceNo_: Code[50];
        GlobalSerieExternalDoc: Code[20];
        ExternalPurchSubLine: Record "FSN External Purch. Sub Line";
        ExternalPurchLine: Record "FSN External Purch. Line";
        cd: Codeunit "Purchase Post via Job Queue";
        WarehouseEmployee: Record "Warehouse Employee";
        Parameter: Record "FSN Parameter";
        lOldFilterGroup: Integer;
        Progress: Dialog;
        WindowIsOpen: Boolean;
        pWText000: Label 'Purchase Order Alternative';
        pWText001: Label 'Vendor #1 - #2';
        pWText002: Label 'Purchase Order actual #3';
        pWText003: Label 'Purchase Line Item No. #4';
        POSSESION: Codeunit "LSC POS Session";
        InAdjustVendorInvoiceNo: Boolean;


    procedure ProcessRecepComMin(StatusPost: Integer; Counter: Integer; NoRecep: Code[20]): Text
    var
        PRCountHeader: Record "LSC P/R Counting Header";
        PRCountH: Record "LSC P/R Counting Header";
        pg: Page "LSC Retail Receiving";
        PRPost: Codeunit "LSC Picking/Receiving - Post";
        PurchRcptHeader: Record "Purch. Rcpt. Header";
        RecePurchDte: Record "FSN Recep. Purch. DTE";
        PurchInvHeader: Record "Purch. Inv. Header";
        Print: Boolean;
        POSSESION: Codeunit "LSC POS Session";
        messageError: Text;
        DocSubType: Codeunit "Document Sub Type";
        i: Integer;
        e: Integer;
        LSCPRcountHeader: Record "LSC P/R Counting Header";
        ConfirRun: Boolean;
        json: JsonObject;
        MessResponse: Text;
    begin
        ConfirRun := false;
        PRCountHeader.Reset();
        PRCountHeader.SetCurrentKey("FSN Count AplitAunt");
        if NoRecep <> '' then
            PRCountHeader.SetRange("No.", NoRecep);
        //PRCountHeader.SetRange(PRCountHeader.Receiving, PRCountHeader.Receiving::"Purchase Order");
        //PRCountHeader.SetRange(PRCountHeader.Receiving, PRCountHeader.Receiving::"Transfer In");
        PRCountHeader.SetRange(PRCountHeader."FSN Status", PRCountHeader."FSN Status"::AplicandoAutomatico);
        if PRCountHeader.find('-') then
            repeat
                i += 1;
                messageError := '';
                POSSESION.SetValue('VSESSION', 'F20');
                PRPost.SetReceivingPostMethod(StatusPost);
                Commit();
                PRCountHeader."Counted Date" := Today();
                if not PRPost.Run(PRCountHeader) then
                    messageError := GetLastErrorText()
                else
                    ConfirRun := true;

                if (messageError = '') and (PRCountHeader.Receiving = PRCountHeader.Receiving::"Purchase Order") then begin
                    PurchRcptHeader.SetRange("Order No.", PRCountHeader."Reference No.");//28981
                    PurchRcptHeader.SetRange("LSC Receiving/Picking No.", PRCountHeader."Posted No.");
                    if PurchRcptHeader.FindFirst() then begin
                        PurchRcptHeader.SubTotal := PRCountHeader."Subtotal";
                        PurchRcptHeader."Tax" := PRCountHeader."Tax";
                        PurchRcptHeader."Total" := PRCountHeader."Total";
                        PurchRcptHeader.Modify();

                        PurchInvHeader.Reset();
                        PurchInvHeader.SetRange("Order No.", PRCountHeader."Reference No.");
                        PurchInvHeader.SetRange("Vendor Invoice No.", PRCountHeader."Vendor Invoice Number");
                        if PurchInvHeader.FindSet() then begin
                            PurchInvHeader."Subtotal" := PRCountHeader."Subtotal";
                            PurchInvHeader."Tax" := PRCountHeader."Tax";
                            PurchInvHeader."Total" := PRCountHeader."Total";
                            PurchInvHeader.Modify(true);
                        end;
                        //end;
                        Commit();
                    end;
                    PurchRcptHeader.SetRange("Order No.", PRCountHeader."Reference No.");
                    PurchRcptHeader.SetRange("LSC Receiving/Picking No.", PRCountHeader."Posted No.");
                    if PurchRcptHeader.FindFirst() then begin
                        invFSNUtilityDTE(PurchRcptHeader."No.", PRCountHeader."DTE AuthNumber", PRCountHeader."DTE Invoice", PRCountHeader."Signature Validation", PRCountHeader."No. Credit Memo Associated", 'PURCHINV', 0);
                    end;
                    Commit();

                    //JH06092024-Recepcion Compra DTE, Marcar que se ha utilizado el DTE
                    RecePurchDte.Reset();
                    RecePurchDte.SetRange("DTE Invoice", PRCountHeader."DTE Invoice");
                    if RecePurchDte.FindFirst() then begin
                        RecePurchDte."Record Processed" := true;
                        RecePurchDte.Modify();
                        Commit();
                    end;

                    //JN-NO BORRAR -
                    ExternalPurchLine.Reset();
                    ExternalPurchLine.SetRange("No.", PRCountHeader."Reference No.");
                    ExternalPurchLine.SetRange("Status Purchase", ExternalPurchLine."Status Purchase"::returned);
                    if ExternalPurchLine.Find('-') then begin
                        repeat
                            ExternalPurchLine."Status Purchase" := ExternalPurchLine."Status Purchase"::Solved;
                            ExternalPurchLine.Modify(true);
                        until ExternalPurchLine.Next() = 0;
                    end;
                    //JN-NO BORRAR +
                end else begin
                    PRCountH.Reset();
                    if PRCountH.Get(PRCountHeader."No.") then begin
                        PRCountH."FSN Count AplitAunt" := ValLastAplitAout();
                        PRCountH."FSN Message Process" := COPYSTR(messageError, 1, 249);
                        PRCountH.Modify();
                        Commit();
                    end;
                end;
            until (PRCountHeader.Next() = 0) or (i = Counter);
        json.Add('Status', ConfirRun);
        json.Add('LastError', messageError);
        json.WriteTo(MessResponse);
        exit(MessResponse);
    end;

    procedure ValLastAplitAout(): Integer
    var
        LSCPRcountHeader: Record "LSC P/R Counting Header";
    begin
        LSCPRcountHeader.SetCurrentKey("FSN Count AplitAunt");
        LSCPRcountHeader.SetFilter("FSN Count AplitAunt", '<>%1', 0);
        if LSCPRcountHeader.FindLast() then
            exit(LSCPRcountHeader."FSN Count AplitAunt" + 1)
        else
            exit(1);
    end;

    procedure Sincronize(PurchaseNo: Code[20]; VendorInvoiceNo: Code[50]; _OptionValue: Option New,Received,ReceiptCreated,ErrorValidation,CloseErasePurch,PurchNotExists,Canceled; var TextError: Text[50]) PostOk: Boolean
    var
        CompraHeader: Record "Purchase Header";
        CompraDetalle: Record "Purchase Line";
        CompraDetalle2: Record "Purchase Line";
        CreditosFiscales: Query "FSN External Document Invoice";
        lPurchaseOrder: Text[20];
        PagePurchase: Page "LSC Retail Purchase Order";
        IsWhsLogistic: Boolean;
        Location: Record "Location";
        PRHeader: Record "LSC P/R Counting Header";
        PRConfirm: Codeunit "LSC Picking/Receiving Confirm";
        PRLine: Record "LSC Picking / Receiving lines";
        ExternalPurchSubLine: Record "FSN External Purch. Sub Line";
        ExternalPurchLine: Record "FSN External Purch. Line";
        IsPosted, isCropVendorInvoice : Boolean;
        ExtSubLineFilters: Record "FSN External Purch. Sub Line";
        vendorInvoiceTxt: Text;
        vendorInvoiceList: List of [Text];
        Parameter: Record "FSN Parameter";
        InvMngSetup: Record "LSC Inventory Management Setup";
        Item: Record "Item";
    begin
        Clear(isCropVendorInvoice);
        IsWhsLogistic := FALSE;
        ExtSubLineFilters.RESET;
        ExtSubLineFilters.SETCURRENTKEY("No.", "External Document No.");
        ExtSubLineFilters.SETRANGE(ExtSubLineFilters."No.", PurchaseNo);
        ExtSubLineFilters.SETRANGE(ExtSubLineFilters."External Document No.", VendorInvoiceNo);
        ExtSubLineFilters.MARKEDONLY(TRUE);

        IF CompraHeader.GET(CompraHeader."Document Type"::Order, PurchaseNo) THEN BEGIN    //Si existe Pedido
            IF Location.GET(CompraHeader."Location Code") THEN
                IsWhsLogistic := Location."LSC Location is a Warehouse";

            vendorInvoiceTxt := VendorInvoiceNo;
            if vendorInvoiceTxt.Contains('-') then
                vendorInvoiceList := vendorInvoiceTxt.Split('-');
            if vendorInvoiceTxt.Contains('DTE') then begin
                vendorInvoiceList := vendorInvoiceTxt.Split('-');
                CompraHeader.validate("Vendor Invoice Number", DelChr(vendorInvoiceList.Get(vendorInvoiceList.Count), '<', '0'));
                CompraHeader.Validate("Vendor Invoice Serie", DelChr(vendorInvoiceList.Get(vendorInvoiceList.Count - 1), '=', '0'));
                CompraHeader."Unique Document No." := VendorInvoiceNo;
            end else begin
                CompraHeader.validate("Vendor Invoice Number", VendorInvoiceNo);
                CompraHeader.validate("Vendor Invoice Serie", PurchaseNo);
                CompraHeader."Unique Document No." := StrSubstNo('%1-%2', PurchaseNo, VendorInvoiceNo);
            end;

            GlobalPurchNo_ := PurchaseNo;
            GlobalInvoiceNo_ := VendorInvoiceNo;

            if StrLen(CompraHeader."Vendor Invoice No.") > 20 then
                CompraHeader."Vendor Invoice No." := VendorInvoiceNo;

            CompraHeader.Receive := TRUE;
            CompraHeader.Invoice := TRUE;

            if Parameter.Get('INVMNGSETUP', 'REC_INV') then
                if Parameter.Activo then begin
                    InvMngSetup.Reset();
                    if InvMngSetup.FindFirst() then begin
                        case InvMngSetup."Receiving Posting" of
                            InvMngSetup."Receiving Posting"::"Received Qty Only":
                                begin
                                    CompraHeader.Receive := true;
                                    CompraHeader.Invoice := false;
                                end;
                            InvMngSetup."Receiving Posting"::"Full Posting":
                                begin
                                    CompraHeader.Receive := true;
                                    CompraHeader.Invoice := true;
                                end;
                            InvMngSetup."Receiving Posting"::None:
                                begin
                                    CompraHeader.Receive := false;
                                    CompraHeader.Invoice := false;
                                end;
                        end;
                    end;
                end;

            CompraHeader.MODIFY;

            IF IsWhsLogistic THEN
                IF _OptionValue = _OptionValue::CloseErasePurch THEN BEGIN
                    IsPosted := Postear(PurchaseNo);
                    IF IsPosted THEN BEGIN
                        ExternalPurchSubLine.COPYFILTERS(ExtSubLineFilters);
                        IF ExternalPurchSubLine.FIND('-') THEN
                            ExternalPurchSubLine.MODIFYALL(ExternalPurchSubLine."Status Sub. Line", ExternalPurchSubLine."Status Sub. Line"::Received, TRUE);
                    END;
                    EXIT(IsPosted);
                END ELSE
                    IF (_OptionValue = _OptionValue::Canceled) OR (VendorInvoiceNo = 'CANCEL') THEN BEGIN
                        IF Postear(PurchaseNo) THEN BEGIN
                            ExternalPurchSubLine.COPYFILTERS(ExtSubLineFilters);
                            IF ExternalPurchSubLine.FIND('-') THEN
                                ExternalPurchSubLine.MODIFYALL(ExternalPurchSubLine."Status Sub. Line", ExternalPurchSubLine."Status Sub. Line"::Received, TRUE);
                        END;
                        EXIT(TRUE);
                    END;
            IF IsWhsLogistic THEN // Si la Factura existe, dar por recibido
                IF ValidateExistsLogisticDocument(CompraHeader) THEN BEGIN //! aqui no entra 
                    ExternalPurchSubLine.COPYFILTERS(ExtSubLineFilters);
                    IF ExternalPurchSubLine.FIND('-') THEN
                        ExternalPurchSubLine.MODIFYALL(ExternalPurchSubLine."Status Sub. Line", ExternalPurchSubLine."Status Sub. Line"::Received, TRUE);
                    EXIT(TRUE);
                END;

            CompraDetalle.RESET;
            CompraDetalle.SETFILTER("Document No.", PurchaseNo);
            CompraDetalle2.RESET;
            CompraDetalle2.SETFILTER("Document No.", PurchaseNo);
            CompraDetalle2.CALCSUMS(CompraDetalle2."Qty. to Receive", CompraDetalle2.Quantity);

            IF CompraDetalle.FIND('-') THEN BEGIN //Desplegar articulos
                IF NOT IsWhsLogistic THEN BEGIN
                    PRHeader.Init();
                    PRHeader.Validate(Receiving, PRHeader.Receiving::"Purchase Order");
                    PRHeader."Store No." := CompraHeader."Location Code";
                    PRHeader."Location Code" := CompraHeader."Location Code";
                    PRHeader.Insert(true);
                    PRHeader.VALIDATE("Reference No.", CompraHeader."No.");
                    PRHeader.Validate("Counted Date", Today());

                    IF (GlobalSerieExternalDoc <> '') AND (CompraHeader."Buy-from Vendor No." <> '1185') THEN//Dollar temp
                        PRHeader."Vendor Invoice No." := CopyStr(GlobalSerieExternalDoc + VendorInvoiceNo, 1, 20)
                    ELSE
                        if vendorInvoiceList.Count > 1 then begin
                            PRHeader."Vendor Invoice No." := CopyStr(DelChr(join(vendorInvoiceList.GetRange(1, vendorInvoiceList.Count - 1), '-'), '=', '0') + '-' + (DelChr(vendorInvoiceList.Get(vendorInvoiceList.Count), '<', '0')), 1, 20);
                            ExternalPurchSubLine.COPYFILTERS(ExtSubLineFilters);
                            IF ExternalPurchSubLine.FIND('-') THEN begin
                                PRHeader.Validate("Vendor Invoice Number", DelChr((vendorInvoiceList.Get(vendorInvoiceList.Count)), '<', '0'));
                                PRHeader.Validate("Vendor Invoice Serie", vendorInvoiceList.Get(1) + DelChr(vendorInvoiceList.Get(2), '=', '0'));
                                PRHeader."DTE Invoice" := ExternalPurchSubLine."External Document No.";
                                PRHeader."DTE AuthNumber" := ExternalPurchSubLine."DTE AuthNumber";
                                PRHeader."Signature Validation" := ExternalPurchSubLine."Signature Validation";
                                PRHeader."Unique Document No." := PRHeader."Vendor Invoice No.";
                            end;
                        end else
                            PRHeader."Vendor Invoice No." := CopyStr(DelChr(VendorInvoiceNo, '<', '0'), 1, 20);

                    IF PRHeader.Modify(true) THEN BEGIN
                        PRConfirm.InitCodeunit(TRUE);
                        PRConfirm.RUN(PRHeader);
                    END
                    ELSE
                        EXIT;
                END ELSE BEGIN
                    IF CompraDetalle2."Qty. to Receive" > 0 THEN BEGIN //Setear todo a cero
                        CompraDetalle.SETFILTER(CompraDetalle."Qty. to Receive", '<>0');
                        IF CompraDetalle.FINDSET(TRUE, TRUE) THEN
                            REPEAT
                                CompraDetalle.VALIDATE("Qty. to Receive", 0);
                                CompraDetalle.MODIFY;
                            UNTIL CompraDetalle.NEXT = 0;
                    END;
                END;
            END;

            ExternalPurchSubLine.COPYFILTERS(ExtSubLineFilters);
            ExternalPurchSubLine.SETFILTER(ExternalPurchSubLine."Qty. to Ship", '<>0');
            IF ExternalPurchSubLine.FIND('-') THEN
                REPEAT
                    IF NOT ExternalPurchLine.GET(ExternalPurchSubLine."No.", ExternalPurchSubLine."Line No.") THEN BEGIN
                        TextError := COPYSTR(STRSUBSTNO(gText001, ExternalPurchSubLine.TABLECAPTION, ExternalPurchSubLine."Line No."), 1, 50);
                        EXIT(FALSE);
                    END;

                    IF CompraDetalle.GET(CompraHeader."Document Type", ExternalPurchSubLine."No.", ExternalPurchSubLine."Line No.") THEN BEGIN
                        IF CompraDetalle.Quantity < (ExternalPurchSubLine."Qty. to Ship" + CompraDetalle."Quantity Received") THEN BEGIN
                            TextError := COPYSTR(STRSUBSTNO(gText004, ExternalPurchSubLine."Line No.",
                                  FORMAT((ExternalPurchSubLine."Qty. to Ship" + CompraDetalle."Quantity Received")), FORMAT(CompraDetalle.Quantity)), 1, 50);

                            IF NOT IsWhsLogistic THEN
                                PRHeader.DELETE(TRUE);

                            EXIT(FALSE);
                        END;
                        //15837
                        if (CompraDetalle."Direct Unit Cost" <> ExternalPurchSubLine."Unit Cost") and not (Abs(ExternalPurchSubLine."Unit Cost" - CompraDetalle."FSN Direct Unit Cost") >= 0.03) then begin
                            CompraDetalle."Direct Unit Cost" := ExternalPurchSubLine."Unit Cost";
                            CompraDetalle.Modify(true);
                        end;

                        IF IsWhsLogistic THEN BEGIN
                            CompraDetalle.VALIDATE("Qty. to Receive", ExternalPurchSubLine."Qty. to Ship");
                            CompraDetalle.MODIFY;
                        END ELSE BEGIN
                            PRLine.RESET;
                            PRLine.SETCURRENTKEY("Document No.", "Item No.", "Variant code", Status);
                            PRLine.SETRANGE(PRLine."Document No.", PRHeader."No.");
                            PRLine.SETRANGE(PRLine."Item No.", ExternalPurchSubLine."Item No.");
                            IF PRLine.FINDFIRST THEN BEGIN

                                PRLine.VALIDATE(Quantity, ExternalPurchSubLine."Qty. to Ship");
                                PRLine."FSN Checked" := TRUE;

                                ///15616
                                if ExternalPurchSubLine."Lot No." <> '' then begin
                                    if (Item.Get(PRLine."Item No.") and (Item."Item Tracking Code" <> '')) then begin
                                        PRLine."Lot No." := ExternalPurchSubLine."Lot No.";
                                        PRLine."Expiration Date" := ExternalPurchSubLine."Expiration Date";
                                    end;
                                end;

                                IF NOT PRLine.MODIFY THEN BEGIN
                                    TextError := COPYSTR(STRSUBSTNO(gText002, GETLASTERRORTEXT), 1, 50);
                                    PRHeader.DELETE(TRUE);
                                    EXIT(FALSE);
                                END;
                            END ELSE BEGIN
                                TextError := COPYSTR(STRSUBSTNO(gText001, PRLine.TABLECAPTION, ExternalPurchSubLine."Item No."), 1, 50);
                                PRHeader.DELETE(TRUE);
                                EXIT(FALSE);
                            END;
                        END;
                    END ELSE BEGIN
                        TextError := COPYSTR(STRSUBSTNO(gText001, CompraDetalle.TABLECAPTION, ExternalPurchSubLine."Line No."), 1, 50);
                        IF NOT IsWhsLogistic THEN
                            PRHeader.DELETE(TRUE);
                        EXIT(FALSE);
                    END;
                UNTIL ExternalPurchSubLine.NEXT = 0
            ELSE BEGIN
                TextError := gText003;

                IF NOT IsWhsLogistic THEN
                    PRHeader.DELETE(TRUE);

                EXIT(FALSE);
            END;
            COMMIT;
            IF IsWhsLogistic THEN BEGIN
                IF CODEUNIT.RUN(CODEUNIT::"Purch.-Post", CompraHeader) THEN//28981
                    ExternalPurchSubLine.MODIFYALL("Status Sub. Line", ExternalPurchSubLine."Status Sub. Line"::Received, TRUE)
                ELSE BEGIN
                    TextError := COPYSTR(GETLASTERRORTEXT, 1, 50);
                    EXIT(FALSE);
                END;
            END ELSE BEGIN
                ExternalPurchSubLine.COPYFILTERS(ExtSubLineFilters);
                ExternalPurchSubLine.SETFILTER(ExternalPurchSubLine."Qty. to Ship", '<>0');
                IF ExternalPurchSubLine.FIND('-') THEN
                    REPEAT
                        ExternalPurchSubLine."Status Sub. Line" := ExternalPurchSubLine."Status Sub. Line"::ReceiptCreated;
                        ExternalPurchSubLine."Retail Receiving No." := PRHeader."No.";
                        ExternalPurchSubLine."Eraser by User" := FALSE;
                        ExternalPurchSubLine.MODIFY(TRUE);
                    UNTIL ExternalPurchSubLine.NEXT = 0;

            END;
            COMMIT;

            RecalPR(PRHeader, PRLine);
            IF IsWhsLogistic THEN
                IF NOT Postear(PurchaseNo) THEN
                    ExternalPurchSubLine.MODIFYALL(ExternalPurchSubLine."Status Sub. Line", ExternalPurchSubLine."Status Sub. Line"::CloseErasePurch, TRUE);

            EXIT(TRUE);
        END ELSE BEGIN
            ExternalPurchSubLine.COPYFILTERS(ExtSubLineFilters);
            IF ExternalPurchSubLine.FIND('-') THEN;
            ExternalPurchSubLine.MODIFYALL(ExternalPurchSubLine."Status Sub. Line", ExternalPurchSubLine."Status Sub. Line"::PurchNotExists, TRUE);
            EXIT(TRUE);
        END;

    end;


    procedure Postear(var PurchaseNo: Code[20]) DeleteOk: Boolean
    var
        ReceiptLine: Record "Purch. Rcpt. Line";
        PurchaseOrder: Record "Purchase Header";
        ExternalPurchLine_l2: Record "FSN External Purch. Sub Line";
    begin
        ExternalPurchLine_l2.RESET;
        ExternalPurchLine_l2.SETRANGE(ExternalPurchLine_l2."No.", PurchaseNo);

        ReceiptLine.RESET;
        ReceiptLine.SETCURRENTKEY("Order No.", "Order Line No.");
        ReceiptLine.SETRANGE(ReceiptLine."Order No.", PurchaseNo);

        IF ExternalPurchLine_l2.FINDSET() THEN BEGIN
            ExternalPurchLine_l2.CALCSUMS(ExternalPurchLine_l2."Qty. to Ship");
            IF ReceiptLine.FINDSET() THEN BEGIN
                ReceiptLine.CALCSUMS(Quantity);
                IF ReceiptLine.Quantity = ExternalPurchLine_l2."Qty. to Ship" THEN
                    IF PurchaseOrder.GET(PurchaseOrder."Document Type"::Order, PurchaseNo) THEN
                        IF NOT PurchaseOrder.DELETE(TRUE) THEN
                            EXIT(FALSE);
            END ELSE
                IF GlobalInvoiceNo_ = 'CANCEL' THEN
                    IF PurchaseOrder.GET(PurchaseOrder."Document Type"::Order, PurchaseNo) THEN
                        IF NOT PurchaseOrder.DELETE(TRUE) THEN
                            EXIT(FALSE);
        END;

        EXIT(TRUE);
    end;


    procedure ValidateExistsLogisticDocument(Purchase: Record "Purchase Header") Exists: Boolean
    var
        VendorLedgerEntry: Record "Vendor Ledger Entry";
    begin
        VendorLedgerEntry.RESET;
        VendorLedgerEntry.SETCURRENTKEY(VendorLedgerEntry."External Document No.");
        VendorLedgerEntry.SETRANGE(VendorLedgerEntry."Vendor No.", Purchase."Buy-from Vendor No.");
        VendorLedgerEntry.SETRANGE(VendorLedgerEntry."External Document No.", Purchase."Vendor Invoice No.");
        EXIT(VendorLedgerEntry.FINDFIRST);
    end;


    procedure UpdateErrorLines(PurchNo_: Code[20]; Invoice_: Code[50]; TextError: Text[50])
    var
        ExternalPurchLine_l: Record "FSN External Purch. Line";
        ExtPurchSubLine_l: Record "FSN External Purch. Sub Line";
    begin

        ExtPurchSubLine_l.RESET;
        ExtPurchSubLine_l.SETRANGE(ExtPurchSubLine_l."No.", PurchNo_);
        ExtPurchSubLine_l.SETRANGE(ExtPurchSubLine_l."External Document No.", Invoice_);
        IF ExtPurchSubLine_l.FIND('-') THEN
            REPEAT
                ExtPurchSubLine_l.VALIDATE("Status Sub. Line", ExtPurchSubLine_l."Status Sub. Line"::ErrorValidation);
                IF ExternalPurchLine_l.GET(ExtPurchSubLine_l."No.", ExtPurchSubLine_l."Line No.") THEN BEGIN
                    ExternalPurchLine_l."Description Error" := TextError;
                    ExternalPurchLine_l.MODIFY;
                END;
                ExtPurchSubLine_l.MODIFY;
            UNTIL ExtPurchSubLine_l.NEXT = 0;

    end;


    procedure SincronizeConsistency(PurchNo_: Code[20]; Decimal: Integer)
    var
        PurchaseHeader_l: Record "Purchase Header";
        ExternalPurchSubLine_l: Record "FSN External Purch. Sub Line";
        Location_l: Record Location;
        OnlyOne: Boolean;
    begin
        IF NOT PurchaseHeader_l.GET(PurchaseHeader_l."Document Type"::Order, PurchNo_) THEN
            EXIT;

        IF NOT Location_l.GET(PurchaseHeader_l."Location Code") THEN
            EXIT;

        IF NOT Location_l."LSC Location is a Warehouse" THEN
            EXIT;

        GlobalInvoiceNo_ := '';
        OnlyOne := FALSE;

        ExternalPurchSubLine_l.RESET;
        ExternalPurchSubLine_l.SETCURRENTKEY("Status Sub. Line");
        ExternalPurchSubLine_l.SETRANGE(ExternalPurchSubLine_l."No.", PurchNo_);
        ExternalPurchSubLine_l.SETRANGE(ExternalPurchSubLine_l."Status Sub. Line", ExternalPurchSubLine_l."Status Sub. Line"::Received);
        OnlyOne := ExternalPurchSubLine_l.COUNT = 1;
        IF ExternalPurchSubLine_l.FINDFIRST THEN BEGIN
            IF OnlyOne THEN
                GlobalInvoiceNo_ := ExternalPurchSubLine."External Document No.";
            IF Postear(PurchNo_) THEN;
        END;
    end;

    procedure MarkReceivingExternalPurchDelete(ReceivingNo: Code[20]; PurchaseNo: Code[20])
    var
        ExternalPurchSubLine: Record "FSN External Purch. Sub Line";
    begin
        ExternalPurchSubLine.RESET;
        ExternalPurchSubLine.SETCURRENTKEY("Retail Receiving No.", "No.", "Eraser by User");
        ExternalPurchSubLine.SETRANGE(ExternalPurchSubLine."Retail Receiving No.", ReceivingNo);
        ExternalPurchSubLine.SETRANGE(ExternalPurchSubLine."No.", PurchaseNo);
        ExternalPurchSubLine.SETRANGE(ExternalPurchSubLine."Eraser by User", FALSE);
        ExternalPurchSubLine.MODIFYALL(ExternalPurchSubLine."Eraser by User", TRUE, TRUE);
    end;

    procedure IsAutomaticReceiving(ReceivingNo_: Code[20]; OrderNo_: Code[20]; TypeOrder: Integer): Boolean
    var
        ExternalPurchSubLine_l: Record "FSN External Purch. Sub Line";
    begin
        IF NOT (TypeOrder = 0) THEN EXIT(FALSE);

        ExternalPurchSubLine_l.RESET;
        ExternalPurchSubLine_l.SETCURRENTKEY(ExternalPurchSubLine_l."Retail Receiving No.", "No.", "Eraser by User");
        ExternalPurchSubLine_l.SETRANGE(ExternalPurchSubLine_l."Retail Receiving No.", ReceivingNo_);
        ExternalPurchSubLine_l.SETRANGE(ExternalPurchSubLine_l."No.", OrderNo_);
        EXIT(ExternalPurchSubLine_l.FINDFIRST);
    end;

    procedure join(GetRange: List of [Text]; arg: Text): Code[30]
    var
        iter: Text;
        result: Code[30];
    begin
        foreach iter in GetRange do begin
            result += iter + arg;
        end;
        exit(CopyStr(result, 1, StrLen(result) - StrLen(arg)));
    end;

    procedure removeLeftZero(vendorInvoiceNo: Text): Text
    var
        oldInvoiceNo, newInvoiceNo : Text;
        invoiceSplit: List of [Text];
    begin
        oldInvoiceNo := vendorInvoiceNo;
        invoiceSplit := oldInvoiceNo.Split('-');
        newInvoiceNo := invoiceSplit.Get(invoiceSplit.Count);

        repeat
            newInvoiceNo := CopyStr(newInvoiceNo, 2, StrLen(newInvoiceNo));
        until newInvoiceNo[1] <> '0';

        exit(newInvoiceNo);
    end;

    procedure RecalPR(Remision: Record "LSC P/R Counting Header"; RemLine: Record "LSC Picking / Receiving lines"): Text
    var
        PRHeader: Record "LSC P/R Counting Header";
        PRLines: Record "LSC Picking / Receiving lines";
        purchaseLine: Record "Purchase Line";
        TotalBase, subTotalBase, vatBase : Decimal;
        IUM: Record "Item Unit of Measure";
        Text001: Label 'El producto %1 no tiene unidad de medida';
        Currency: Record Currency;
        PurchHeader: Record "Purchase Header";
        ExternalPurchSubLine: Record "FSN External Purch. Sub Line";
        Cambio: Boolean;
        PRConfirm: Codeunit "LSC Picking/Receiving Confirm";
    begin
        Cambio := true;
        if not PRHeader.Get(Remision."No.") then
            exit;
        if not PurchHeader.Get(PurchHeader."Document Type"::Order, PRHeader."Reference No.") then
            exit;

        if PurchHeader."Currency Code" = '' then
            Currency.InitRoundingPrecision
        else
            Currency.Get(PurchHeader."Currency Code");
        PRLines.Reset();
        PRLines.SetRange("Document No.", RemLine."Document No.");
        PRLines.SetFilter(Quantity, '>%1', 0);
        if PRLines.FindFirst() then
            repeat
                purchaseLine.Reset();
                purchaseLine.SetRange("Document No.", PRHeader."Reference No.");
                purchaseLine.SetRange("No.", PRLines."Item No.");
                if purchaseLine.FindFirst() then begin
                    ExternalPurchSubLine.Reset();
                    ExternalPurchSubLine.SetRange("No.", PRHeader."Reference No.");
                    ExternalPurchSubLine.SetRange("Item No.", PRLines."Item No.");
                    if ExternalPurchSubLine.FindFirst() then begin
                        if IUM.Get(purchaseLine."No.", purchaseLine."Unit of Measure Code") then begin
                            if PRLines."Unit of Measure Code" <> purchaseLine."Unit of Measure Code" then begin
                                subTotalBase += Round(purchaseLine."Direct Unit Cost" * (PRLines.Quantity / IUM."Qty. per Unit of Measure"), Currency."Invoice Rounding Precision", Currency.InvoiceRoundingDirection);
                                vatBase += ((purchaseLine."Direct Unit Cost" * (PRLines.Quantity / IUM."Qty. per Unit of Measure")) * (purchaseLine."VAT %" / 100));
                            end else begin
                                subTotalBase += Round(ExternalPurchSubLine."Unit Cost" * (ExternalPurchSubLine.Quantity), Currency."Invoice Rounding Precision", Currency.InvoiceRoundingDirection);
                                vatBase += ((ExternalPurchSubLine."Unit Cost" * (ExternalPurchSubLine.Quantity)) * (purchaseLine."VAT %" / 100));
                            end;
                        end else
                            exit;
                    end;
                end;
            until PRLines.Next = 0;
        if Cambio then begin
            PRHeader.ConfirmarSubTotal := subTotalBase;
            PRHeader.ConfirmarTax := vatBase;
            PRHeader.ConfirmarTotal := subTotalBase + vatBase;
            IF PRHeader.Modify(true) THEN BEGIN
                PRConfirm.InitCodeunit(TRUE);
                PRConfirm.RUN(PRHeader);
            END
        end;
    end;

    [EventSubscriber(ObjectType::Page, Page::"LSC Retail Receiving List", 'OnDeleteRecordEvent', '', true, true)]
    local procedure "Retail Receiving List_OnDeleteRecordEvent"
    (
        var Rec: Record "LSC P/R Counting Header";
        var AllowDelete: Boolean
    )
    begin
        if IsAutomaticReceiving(Rec."No.", rec."Reference No.", Rec."Type") then
            if Confirm(StrSubstNo(gText005, Rec."No.")) then begin
                MarkReceivingExternalPurchDelete(Rec."No.", Rec."Reference No.");
            end
            else begin
                AllowDelete := false;
            end;
    end;

    //Event FASANI Section

    [EventSubscriber(ObjectType::Page, Page::"LSC Picking/Receiving Lines", 'OnDeleteRecordEvent', '', true, true)]
    local procedure "Picking/Receiving Lines_OnDeleteRecordEvent"
    (
        var Rec: Record "LSC Picking / Receiving lines";
        var AllowDelete: Boolean
    )
    var
        PRCountingHeader2: Record "LSC P/R Counting Header";
    begin
        if PRCountingHeader2.Get(Rec."Document No.") then
            if IsAutomaticReceiving(PRCountingHeader2."No.", PRCountingHeader2."Reference No.", PRCountingHeader2."Type") then begin
                Message(gText006);
                AllowDelete := false;
            end;
    end;

    [EventSubscriber(ObjectType::Page, Page::"LSC Retail Receiving", 'OnModifyRecordEvent', '', true, true)]
    local procedure "Retail Receiving_OnModifyRecordEvent"
    (
        var Rec: Record "LSC P/R Counting Header";
        var xRec: Record "LSC P/R Counting Header";
        var AllowModify: Boolean
    )
    begin
        if IsAutomaticReceiving(Rec."No.", rec."Reference No.", Rec."Type") then begin
            if (Rec."Reference No." <> xRec."Reference No.") or
                (Rec."Reference Name" <> xRec."Reference Name") or
                (Rec."Vendor Invoice No." <> xRec."Vendor Invoice No.") or
                (Rec."Type" <> xRec."Type"::Scanned) or
                (Rec."Store No." <> xRec."Store No.") or
                (Rec."Location Code" <> xRec."Location Code") or
                (Rec.Receiving <> xRec.Receiving)
            then begin
                Error(gText007);
                //AllowModify := false;
            end;
        end
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Purch.-Post", 'OnBeforePurchRcptHeaderInsert', '', true, true)]
    local procedure "Purch.-Post_OnBeforePurchRcptHeaderInsert"
    (
        var PurchRcptHeader: Record "Purch. Rcpt. Header";
        var PurchaseHeader: Record "Purchase Header";
        CommitIsSupressed: Boolean
    )
    begin
        //PurchaseV47-JH01
        PurchRcptHeader."FSN Vendor Invoice No." := PurchaseHeader."Vendor Invoice No.";

    end;

    [EventSubscriber(ObjectType::Page, Page::"LSC Picking/Receiving Lines", 'OnAfterValidateEvent', 'Quantity', true, true)]
    local procedure "LSC Picking/Receiving Lines_OnAfterValidateEvent_[content / Control1] - Quantity"(var Rec: Record "LSC Picking / Receiving lines")
    var
        PRHeader: Record "LSC P/R Counting Header";
        PRLines: Record "LSC Picking / Receiving lines";
        purchaseLine: Record "Purchase Line";
        TotalBase, subTotalBase, vatBase : Decimal;
        IUM: Record "Item Unit of Measure";
        Text001: Label 'El producto %1 no tiene unidad de medida';
        Currency: Record Currency;
        PurchHeader: Record "Purchase Header";
    begin
        if Rec."Qty. Difference" = 0 then
            Rec."Posting Action" := REc."Posting Action"::" ";

        if not PRHeader.Get(Rec."Document No.") then
            exit;
        if not PurchHeader.Get(PurchHeader."Document Type"::Order, PRHeader."Reference No.") then
            exit;

        if PurchHeader."Currency Code" = '' then
            Currency.InitRoundingPrecision
        else
            Currency.Get(PurchHeader."Currency Code");
        PRLines.Reset();
        PRLines.SetRange("Document No.", Rec."Document No.");
        PRLines.SetFilter("Line No.", '<>%1', Rec."Line No.");
        PRLines.SetFilter(Quantity, '>%1', 0);
        if PRLines.FindFirst() then
            repeat
                purchaseLine.Reset();
                purchaseLine.SetRange("Document No.", PRHeader."Reference No.");
                purchaseLine.SetRange("No.", PRLines."Item No.");
                if purchaseLine.FindFirst() then begin
                    if IUM.Get(purchaseLine."No.", purchaseLine."Unit of Measure Code") then begin
                        if PRLines."Unit of Measure Code" <> purchaseLine."Unit of Measure Code" then begin
                            //TotalBase += purchaseLine."Direct Unit Cost" * (PRLines.Quantity / IUM."Qty. per Unit of Measure") + ((purchaseLine."Direct Unit Cost" * (PRLines.Quantity / IUM."Qty. per Unit of Measure")) * (purchaseLine."VAT %" / 100));
                            subTotalBase += Round(purchaseLine."Direct Unit Cost" * (PRLines.Quantity / IUM."Qty. per Unit of Measure"), Currency."Invoice Rounding Precision", Currency.InvoiceRoundingDirection);
                            vatBase += ((purchaseLine."Direct Unit Cost" * (PRLines.Quantity / IUM."Qty. per Unit of Measure")) * (purchaseLine."VAT %" / 100));
                        end else begin
                            //TotalBase += purchaseLine."Direct Unit Cost" * (PRLines.Quantity) + ((purchaseLine."Direct Unit Cost" * (PRLines.Quantity)) * (purchaseLine."VAT %" / 100));
                            subTotalBase += Round(purchaseLine."Direct Unit Cost" * (PRLines.Quantity), Currency."Invoice Rounding Precision", Currency.InvoiceRoundingDirection);
                            vatBase += ((purchaseLine."Direct Unit Cost" * (PRLines.Quantity)) * (purchaseLine."VAT %" / 100));
                        end;

                    end else
                        Error(Text001, purchaseLine."No.");
                end;
            until PRLines.Next = 0;

        purchaseLine.Reset();
        purchaseLine.SetRange("Document No.", PRHeader."Reference No.");
        purchaseLine.SetRange("No.", Rec."Item No.");
        if purchaseLine.FindFirst() then begin
            if IUM.Get(purchaseLine."No.", purchaseLine."Unit of Measure Code") then begin
                if Rec."Unit of Measure Code" <> purchaseLine."Unit of Measure Code" then begin
                    //TotalBase += purchaseLine."Direct Unit Cost" * (Rec.Quantity / IUM."Qty. per Unit of Measure") + ((purchaseLine."Direct Unit Cost" * (Rec.Quantity / IUM."Qty. per Unit of Measure")) * (purchaseLine."VAT %" / 100));
                    subTotalBase += purchaseLine."Direct Unit Cost" * (Rec.Quantity / IUM."Qty. per Unit of Measure");
                    subTotalBase += Round(purchaseLine."Direct Unit Cost" * (PRLines.Quantity / IUM."Qty. per Unit of Measure"), Currency."Invoice Rounding Precision", Currency.InvoiceRoundingDirection);
                    vatBase += ((purchaseLine."Direct Unit Cost" * (Rec.Quantity / IUM."Qty. per Unit of Measure")) * (purchaseLine."VAT %" / 100));
                end else begin
                    //TotalBase += purchaseLine."Direct Unit Cost" * (Rec.Quantity) + ((purchaseLine."Direct Unit Cost" * (Rec.Quantity)) * (purchaseLine."VAT %" / 100));
                    subTotalBase += Round(purchaseLine."Direct Unit Cost" * (PRLines.Quantity), Currency."Invoice Rounding Precision", Currency.InvoiceRoundingDirection);
                    vatBase += ((purchaseLine."Direct Unit Cost" * (Rec.Quantity)) * (purchaseLine."VAT %" / 100));
                end;

            end else
                Error(Text001, purchaseLine."No.");
        end;
        PRHeader."Subtotal" := subTotalBase;
        PRHeader."Tax" := vatBase;
        PRHeader."Total" := subTotalBase + vatBase;
        PRHeader.Modify(true);
    end;

    [EventSubscriber(ObjectType::Page, Page::"LSC Picking/Receiving Lines", 'OnBeforeValidateEvent', 'Quantity', true, true)]
    local procedure "LSC Picking/Receiving Lines_OnBeforeValidateEvent_[content / Control1] - Quantity"(var Rec: Record "LSC Picking / Receiving lines")
    var
        lTxt0: Label 'Scanned is required';
        lTxt1: Label 'Quantity to be received is different from the quantity ordered';
        lTxt2: Label 'No puede modificar cantidades si la Recepcion esta Autorizada';
        FSNSetup: Record "FSN Fasani Setup";
        RetailSetup: Record "LSC Retail User";
        fsnParam: Record "FSN Parameter";
        parameterList: List of [Text];
        parameterValue: Text;
        RetailReceivingHeader: Page "LSC Retail Receiving";
        PRHeader: Record "LSC P/R Counting Header";
    begin
        if PRHeader.Get(Rec."Document No.") then
            if PRHeader."FSN Authorized Reception" then
                Error(lTxt2);

        if RetailSetup.Get(UserId()) then
            if RetailSetup."Store No." <> '' then
                if FSNSetup.Get(RetailSetup."Store No.") then
                    if FSNSetup."Receive Directly" then
                        exit;
        fsnParam.Reset();
        if fsnParam.Get('CONFCOM', 'CONFRDICOM') then
            if fsnParam.Activo then begin
                if RetailSetup.Get(UserId()) then begin
                    parameterList := fsnParam.Valor.Split('|');
                    foreach parameterValue in parameterList do begin
                        if RetailSetup.ID = parameterValue then
                            if (Rec."Difference") > 0 then begin
                                Error(lTxt1);
                            end;
                        exit;
                    end;
                end;
            end;
        Error(lTxt0);

    end;


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC Picking/Receiving - Post", 'OnBeforeModifyPurchHeaderInUpdateSourceStatus', '', true, true)]
    local procedure "LSC Picking/Receiving - Post_OnBeforeModifyPurchHeaderInUpdateSourceStatus"
    (
        var CountingHeader: Record "LSC P/R Counting Header";
        var PurchaseHeader: Record "Purchase Header"
    )
    begin
        PurchaseHeader."Vendor Invoice Number" := CountingHeader."Vendor Invoice Number";
        PurchaseHeader."Vendor Invoice Serie" := CountingHeader."Vendor Invoice Serie";
        PurchaseHeader."Unique Document No." := CountingHeader."Unique Document No.";
        PurchaseHeader."DTE AuthNumber" := CountingHeader."DTE AuthNumber";
        PurchaseHeader."DTE Invoice" := CountingHeader."DTE Invoice";
        PurchaseHeader."Signature Validation" := CountingHeader."Signature Validation";
    end;
    /*JH27052024 - ***********
        Se traslada la validacion sobre el iva y subtotal a la pagina LSC Retail Receiving

    **************************
    [EventSubscriber(ObjectType::Page, Page::"LSC Retail Receiving", 'OnBeforeActionEvent', 'Post', true, true)]
    local procedure "LSC Retail Receiving_OnBeforeActionEvent_[processing / &Posting] - Post"(var Rec: Record "LSC P/R Counting Header")
    begin
        if Page.RunModal(Page::"FSN Check Totals", Rec) <> Action::LookupOK then
            Error('Proceso cancelado');
    end;
    */

    /*[EventSubscriber(ObjectType::Page, Page::"LSC Retail Receiving", 'OnBeforeActionEvent', 'Post', true, true)]
    local procedure "LSC Retail Receiving_OnBeforeActionEvent_[processing / &Posting] - Post"(var Rec: Record "LSC P/R Counting Header")
    var
        PHeader: record "Purchase Header";
        PRLines: Record "LSC Picking / Receiving lines";
        purchaseLine: Record "Purchase Line";
        Vendor_l: Record Vendor;
        IUM: Record "Item Unit of Measure";
        Cantidad: Decimal;
        paramFSN: Record "FSN Parameter";
        paramAmount: Decimal;
        IVAPurchLine: Decimal;
        Purch: Record "Purchase Header";
    begin
        if Rec.Receiving = Rec.Receiving::"Purchase Order" then begin

            //Se trasladan validaciones a un metodo separado para reutilizar las mismas validaciones
            ValReceipt(Rec."No.");
            //**************************************************************************************

            //Reasignacion de valores manuales a sustituir los valores automaticos
            Rec.SubTotal := Rec.ConfirmarSubTotal;
            Rec.Tax := Rec.ConfirmarTax;
            Rec.Total := Rec.ConfirmarTotal;
            //US606-JH-Registrar fecha de contabilizacion con fecha del día. 
            Rec."Counted Date" := Today();
            //US606-JH-Registrar fecha de contabilizacion con fecha del día.
            Rec.Modify();


            if PHeader.Get(PHeader."Document Type"::Order, Rec."Reference No.") then begin
                PHeader."Vendor Invoice Serie" := Rec."Vendor Invoice Serie";
                PHeader."Vendor Invoice Number" := Rec."Vendor Invoice Number";
                PHeader."Vendor Invoice No." := Rec."Vendor Invoice No.";
                if PHeader."Withhold ISR No." = '' then
                    PHeader."Withhold ISR No." := Rec."Withhold ISR No.";
                if PHeader."Withhold Tax No." = '' then
                    PHeader."Withhold Tax No." := rec."Withhold Tax No.";
                if PHeader."Sub Type" = '' then
                    if Vendor_l.get(PHeader."Buy-from Vendor No.") then
                        PHeader."Sub Type" := Vendor_l."Default Sub Type";
                PHeader.Modify();
            end;

            PRLines.Reset();
            PRLines.SetRange("Document No.", Rec."No.");
            if PRLines.FindSet() then
                repeat
                    purchaseLine.Reset();
                    purchaseLine.SetRange("Document No.", Rec."Reference No.");
                    purchaseLine.SetRange("No.", PRLines."Item No.");
                    if purchaseLine.FindSet() then
                        repeat
                            if PRLines."Unit of Measure Code" <> purchaseLine."Unit of Measure Code" then
                                if IUM.Get(purchaseLine."No.", purchaseLine."Unit of Measure Code") then begin
                                    if not (PRLines.Quantity mod IUM."Qty. per Unit of Measure" = 0) then
                                        Error(gText008, PRLines."Item No.", PRLines."Ordered Qty. (base)", PRLines."Unit of Measure Code", purchaseLine.Quantity, purchaseLine."Unit of Measure Code", PRLines.Difference);
                                end;
                        until purchaseLine.Next = 0;
                until PRLines.Next = 0;
        end;
    end;*/

    [EventSubscriber(ObjectType::Page, Page::"LSC Retail Receiving", 'OnBeforeActionEvent', 'Post', true, true)]
    local procedure "LSC Retail Receiving_OnBeforeActionEvent_[processing / &Posting] - Post"(var Rec: Record "LSC P/R Counting Header")
    var
        PHeader: record "Purchase Header";
        PRLines: Record "LSC Picking / Receiving lines";
        purchaseLine: Record "Purchase Line";
        Vendor_l: Record Vendor;
        IUM: Record "Item Unit of Measure";
        Cantidad: Decimal;
        paramFSN: Record "FSN Parameter";
        paramAmount: Decimal;
        IVAPurchLine: Decimal;
        Purch: Record "Purchase Header";
        VATRoundActive: Boolean;
        NetLine: decimal;
        fsbParam: Record "FSN Parameter";
    begin
        VATRoundActive := false;
        VATRoundActive := (fsbParam.Get('APPLYINV', 'ROUNDVATRCM') and fsbParam.Activo);//Vat Control presicion.

        if Rec.Receiving = Rec.Receiving::"Purchase Order" then begin

            //Se trasladan validaciones a un metodo separado para reutilizar las mismas validaciones
            ValReceipt(Rec."No.");
            //**************************************************************************************

            //Reasignacion de valores manuales a sustituir los valores automaticos
            if not VATRoundActive then begin
                Rec.SubTotal := Rec.ConfirmarSubTotal;
                Rec.Tax := Rec.ConfirmarTax;
                Rec.Total := Rec.ConfirmarTotal;
                //US606-JH-Registrar fecha de contabilizacion con fecha del día. 
            end;
            Rec."Counted Date" := Today();
            //US606-JH-Registrar fecha de contabilizacion con fecha del día.
            Rec.Modify();


            if PHeader.Get(PHeader."Document Type"::Order, Rec."Reference No.") then begin
                PHeader."Vendor Invoice Serie" := Rec."Vendor Invoice Serie";
                PHeader."Vendor Invoice Number" := Rec."Vendor Invoice Number";
                PHeader."Vendor Invoice No." := Rec."Vendor Invoice No.";
                if PHeader."Withhold ISR No." = '' then
                    PHeader."Withhold ISR No." := Rec."Withhold ISR No.";
                if PHeader."Withhold Tax No." = '' then
                    PHeader."Withhold Tax No." := rec."Withhold Tax No.";
                if PHeader."Sub Type" = '' then
                    if Vendor_l.get(PHeader."Buy-from Vendor No.") then
                        PHeader."Sub Type" := Vendor_l."Default Sub Type";
                PHeader.Modify();
            end;

            PRLines.Reset();
            PRLines.SetRange("Document No.", Rec."No.");
            if PRLines.FindSet() then
                repeat
                    purchaseLine.Reset();
                    purchaseLine.SetRange("Document No.", Rec."Reference No.");
                    purchaseLine.SetRange("No.", PRLines."Item No.");
                    if purchaseLine.FindSet() then
                        repeat
                            if PRLines."Unit of Measure Code" <> purchaseLine."Unit of Measure Code" then
                                if IUM.Get(purchaseLine."No.", purchaseLine."Unit of Measure Code") then begin
                                    if not (PRLines.Quantity mod IUM."Qty. per Unit of Measure" = 0) then
                                        Error(gText008, PRLines."Item No.", PRLines."Ordered Qty. (base)", PRLines."Unit of Measure Code", purchaseLine.Quantity, purchaseLine."Unit of Measure Code", PRLines.Difference);
                                end;
                        until purchaseLine.Next = 0;
                until PRLines.Next = 0;
        end;
    end;


    [EventSubscriber(ObjectType::Page, Page::"LSC Retail Receiving", 'OnAfterActionEvent', 'Post', true, true)]
    local procedure "LSC Retail Receiving_OnAfterActionEvent_[processing / &Posting] - Post"(var Rec: Record "LSC P/R Counting Header")
    var
        PurchRcptHeader: Record "Purch. Rcpt. Header";
        PurchInvHeader: Record "Purch. Inv. Header";
        legderEntry: Record "Vendor Ledger Entry";
        PRLines: Record "LSC Picking / Receiving lines";
        purchaseLine: Record "Purchase Line";
        IUM: Record "Item Unit of Measure";
        Print: Boolean;
        Transfer: Record "Transfer Line";
        RecePurchDte: Record "FSN Recep. Purch. DTE";
        ExternalPurchLine: Record "FSN External Purch. Line";
        BatchPosting: Codeunit "LSC Batch Posting";
        PRPost: Codeunit "LSC Picking/Receiving - Post";
    begin
        if BatchPosting.IsBatchPostingActive(Enum::"LSC Batch Posting Q Doc Types"::"Retail Receiving", 0) then begin
            Rec."FSN Status" := Rec."FSN Status"::AplicandoAutomatico;
            Rec."FSN Authorized Reception" := true;
            Rec."FSN Date Authorized" := System.CreateDateTime(Today(), Time());
            Rec.Modify(true);
        end;
        PurchRcptHeader.SetRange("Order No.", Rec."Reference No.");
        PurchRcptHeader.SetRange("LSC Receiving/Picking No.", Rec."Posted No.");
        if PurchRcptHeader.FindFirst() then begin
            PurchRcptHeader.SubTotal := Rec."Subtotal";
            PurchRcptHeader."Tax" := Rec."Tax";
            PurchRcptHeader."Total" := Rec."Total";
            PurchRcptHeader.Modify();
            /*
            PurchRcptHeader."DTE AuthNumber" := Rec."DTE AuthNumber";
            PurchRcptHeader."DTE Invoice" := Rec."DTE Invoice";
            PurchRcptHeader."Signature Validation" := Rec."Signature Validation";
            */
            //COMMIT;
            //legderEntry.Reset();
            //legderEntry.SetRange("Document No.", PurchRcptHeader."No.");
            //if legderEntry.FindFirst() then begin
            PurchInvHeader.Reset();
            PurchInvHeader.SetRange("Order No.", Rec."Reference No.");
            PurchInvHeader.SetRange("Vendor Invoice No.", Rec."Vendor Invoice Number");
            if PurchInvHeader.FindSet() then begin
                PurchInvHeader."Subtotal" := Rec."Subtotal";
                PurchInvHeader."Tax" := Rec."Tax";
                PurchInvHeader."Total" := Rec."Total";
                PurchInvHeader.Modify(true);
            end;
            //end;
            Commit();
        end;
        PurchRcptHeader.Reset();
        PurchRcptHeader.SetRange("Order No.", Rec."Reference No.");
        PurchRcptHeader.SetRange("LSC Receiving/Picking No.", Rec."Posted No.");
        if PurchRcptHeader.FindFirst() then begin
            invFSNUtilityDTE(PurchRcptHeader."No.", Rec."DTE AuthNumber", Rec."DTE Invoice", Rec."Signature Validation", Rec."No. Credit Memo Associated", 'PURCHINV', 0);

            Commit();
            REPORT.RUNMODAL(50080, TRUE, FALSE, PurchRcptHeader);//JN28981
            //REPORT.RUNMODAL(10124, TRUE, FALSE, PurchRcptHeader);//JN28981
            Print := true;

            //JH06092024-Recepcion Compra DTE, Marcar que se ha utilizado el DTE
            RecePurchDte.Reset();
            RecePurchDte.SetRange("DTE Invoice", Rec."DTE Invoice");
            RecePurchDte.SetRange("DTE AuthNumber", Rec."DTE AuthNumber");
            RecePurchDte.SetRange("VAT Registration No.", Rec."Vendor No. / Customer No.");
            if RecePurchDte.FindFirst() then begin
                RecePurchDte."Record Processed" := true;
                RecePurchDte.Modify();
                Commit();
            end;
            //JH06092024
        end;

        Commit();




        PurchInvHeader.SETFILTER("Order No.", '=%1', Rec."Reference No.");
        PurchInvHeader.SETFILTER("Vendor Invoice No.", '=%1', Rec."Vendor Invoice No.");
        IF PurchInvHeader.FIND('-') THEN BEGIN
            REPORT.RUNMODAL(50078, TRUE, FALSE, PurchInvHeader);
            Print := true;
        END;
        //FRODRIGUEZ11ABR2019 -
        //FRODRIGUEZ11ABR2019 +

        //JN-NO BORRAR -
        ExternalPurchLine.Reset();
        ExternalPurchLine.SetRange("No.", Rec."Reference No.");
        ExternalPurchLine.SetRange("Status Purchase", ExternalPurchLine."Status Purchase"::returned);
        if ExternalPurchLine.Find('-') then begin
            repeat
                ExternalPurchLine."Status Purchase" := ExternalPurchLine."Status Purchase"::Solved;
                ExternalPurchLine.Modify(true);
            until ExternalPurchLine.Next() = 0;
        end;
        //JN-NO BORRAR +
    end;

    local procedure invFSNUtilityDTE("iNo": Code[20]; "DTE AuthNumber": Code[100]; "DTE Invoice": Code[100]; "Signature Validation": Code[100]; "No. Credit Memo Associated": Code[100]; DocumentType: Code[20]; WithHoldTax: Decimal)
    var
        FSNUtility: Codeunit "FSN Utility";
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        MsgResult: Text;
        POSMenuLineTemp: Record "LSC POS Menu Line" temporary;
        Processed: Boolean;
    begin
        case DocumentType of
            'PURCHINV':
                begin
                    RequestID := 'UPD-DTE-HISRECPUR';
                    POSMenuLineTemp."Menu ID" := 'UDP-HISRECPUR';
                end;
            'PURCHMEM':
                begin
                    RequestID := 'UPD-DTE-HISPURMEM';
                    POSMenuLineTemp."Menu ID" := 'UDP-HISPURMEM';
                end;
        end;
        XMLRequest := iNo;
        POSMenuLineTemp.Reset();
        POSMenuLineTemp.Init();
        POSMenuLineTemp."Profile ID" := 'FASANI';
        POSMenuLineTemp."Key No." := 1;
        POSMenuLineTemp."Set Current-Input" := "DTE Invoice";
        POSMenuLineTemp."Current-Description" := "DTE AuthNumber";
        POSMenuLineTemp."Current-Description2" := "Signature Validation";
        POSMenuLineTemp."Original Description" := "No. Credit Memo Associated";
        POSMenuLineTemp."Current-Price" := WithHoldTax;
        POSMenuLineTemp.Insert();
        FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
    end;

    [EventSubscriber(ObjectType::Page, Page::"LSC Retail Receiving", 'OnAfterActionEvent', 'Confirm', true, true)]
    local procedure "LSC Retail Receiving_OnAfterActionEvent_[processing / &Posting] - Confirm"(var Rec: Record "LSC P/R Counting Header")
    var
        fsnParam: Record "FSN Parameter";
        parameterValue: Text;
        parameterList: List of [Text];
        Text01: Label 'Para este proveedor es requerido hacer la recepción por medio DTE';
    begin
        CalcTototalReceComMin(Rec."No.");


        /*  fsnParam.Reset();
         if fsnParam.Get('CONFCOM', 'CONFPRODTE') then begin
             if fsnParam.Activo then begin
                 if fsnParam.Valor <> '' then begin
                     parameterList := fsnParam.Valor.Split('|');
                     foreach parameterValue in parameterList do begin
                         if Rec."Vendor No. / Customer No." = parameterValue then begin
                             Rec."FSN Automatic Search" := true;
                             if (fsnParam."Value Text 1" = Rec."No.") and (fsnParam."Value Text 1" <> '') then
                                 Rec."FSN Automatic Search" := false;
                             if Rec."FSN Automatic Search" then begin
                                 if Rec."DTE Invoice" = '' then
                                     Message(Text01);
                                 Rec.Modify(true);
                             end;
                         end;
                     end;
                 end;
             end;
         end; */
    end;

    [EventSubscriber(ObjectType::Table, Database::"Purchase Line", 'OnBeforeValidateQtyToInvoice', '', true, true)]
    local procedure "Purchase Line_OnBeforeValidateQtyToInvoice"
    (
        var PurchaseLine: Record "Purchase Line";
        var IsHandled: Boolean
    )
    begin

    end;
    //JH19072024 Validar que el costo de las lineas de dev compras sea diferente a cero
    [EventSubscriber(ObjectType::Page, Page::"Purchase Return Order", 'OnBeforeActionEvent', 'Post', true, true)]
    local procedure "Purchase Return Order_OnBeforeActionEvent_[processing / P&osting] - Post"(var Rec: Record "Purchase Header")
    var
        PRLines: Record "LSC Picking / Receiving lines";
        purchaseLine: Record "Purchase Line";
        TotalBase: Decimal;

    begin
        purchaseLine.Reset();
        purchaseLine.SetRange("Document No.", Rec."No.");
        purchaseLine.SetRange("Direct Unit Cost", 0);
        purchaseLine.SetFilter(Quantity, '<>%1', 0);
        if purchaseLine.FindFirst() then
            Error(lTxt0, purchaseLine."No.");

    end;

    //JH19072024 Validar que el costo de las lineas de dev compras sea diferente a cero
    [EventSubscriber(ObjectType::Page, Page::"Purchase Return Order", 'OnBeforeActionEvent', 'PostAndPrint', true, true)]
    local procedure "Purchase Return Order_OnBeforeActionEvent_[processing / P&osting] - PostAndPrint"(var Rec: Record "Purchase Header")
    var
        PRLines: Record "LSC Picking / Receiving lines";
        purchaseLine: Record "Purchase Line";
        TotalBase: Decimal;
    begin
        purchaseLine.Reset();
        purchaseLine.SetRange("Document No.", Rec."No.");
        purchaseLine.SetRange("Direct Unit Cost", 0);
        purchaseLine.SetFilter(Quantity, '<>%1', 0);
        if purchaseLine.FindFirst() then
            Error(lTxt0, purchaseLine."No.");

    end;

    //JH19072024 Validar que el costo de las lineas de dev compras sea diferente a cero
    [EventSubscriber(ObjectType::Page, Page::"LSC Retail Purch.Ret.Order Lst", 'OnBeforeActionEvent', 'P&ost', true, true)]
    local procedure "LSC Retail Purch.Ret.Order Lst_OnBeforeActionEvent_[processing / P&osting] - P&ost"(var Rec: Record "Purchase Header")
    var
        PRLines: Record "LSC Picking / Receiving lines";
        purchaseLine: Record "Purchase Line";
        TotalBase: Decimal;
    begin
        purchaseLine.Reset();
        purchaseLine.SetRange("Document No.", Rec."No.");
        purchaseLine.SetRange("Direct Unit Cost", 0);
        purchaseLine.SetFilter(Quantity, '<>%1', 0);
        if purchaseLine.FindFirst() then
            Error(lTxt0, purchaseLine."No.");

    end;

    //JH19072024 Validar que el costo de las lineas de dev compras sea diferente a cero
    [EventSubscriber(ObjectType::Page, Page::"LSC Retail Purch.Ret.Order Lst", 'OnBeforeActionEvent', 'Post and &Print', true, true)]
    local procedure "LSC Retail Purch.Ret.Order Lst_OnBeforeActionEvent_[processing / P&osting] - Post and &Print"(var Rec: Record "Purchase Header")
    var
        PRLines: Record "LSC Picking / Receiving lines";
        purchaseLine: Record "Purchase Line";
        TotalBase: Decimal;
    begin
        purchaseLine.Reset();
        purchaseLine.SetRange("Document No.", Rec."No.");
        purchaseLine.SetRange("Direct Unit Cost", 0);
        purchaseLine.SetFilter(Quantity, '<>%1', 0);
        if purchaseLine.FindFirst() then
            Error(lTxt0, purchaseLine."No.");

    end;

    //JH19072024 Validar que el costo de las lineas de dev compras sea diferente a cero
    [EventSubscriber(ObjectType::Page, Page::"LSC Retail Purch. Return Order", 'OnBeforeActionEvent', 'P&ost', true, true)]
    local procedure "LSC Retail Purch. Return Order_OnBeforeActionEvent_[processing / P&osting] - P&ost"(var Rec: Record "Purchase Header")
    var
        PRLines: Record "LSC Picking / Receiving lines";
        purchaseLine: Record "Purchase Line";
        TotalBase: Decimal;
    begin
        purchaseLine.Reset();
        purchaseLine.SetRange("Document No.", Rec."No.");
        purchaseLine.SetRange("Direct Unit Cost", 0);
        purchaseLine.SetFilter(Quantity, '<>%1', 0);
        if purchaseLine.FindFirst() then
            Error(lTxt0, purchaseLine."No.");

    end;
    //JH19072024 Validar que el costo de las lineas de dev compras sea diferente a cero
    [EventSubscriber(ObjectType::Page, Page::"LSC Retail Purch. Return Order", 'OnBeforeActionEvent', 'Post and &Print', true, true)]
    local procedure "LSC Retail Purch. Return Order_OnBeforeActionEvent_[processing / P&osting] - Post and &Print"(var Rec: Record "Purchase Header")
    var
        PRLines: Record "LSC Picking / Receiving lines";
        purchaseLine: Record "Purchase Line";
        TotalBase: Decimal;
    begin
        purchaseLine.Reset();
        purchaseLine.SetRange("Document No.", Rec."No.");
        purchaseLine.SetRange("Direct Unit Cost", 0);
        purchaseLine.SetFilter(Quantity, '<>%1', 0);
        if purchaseLine.FindFirst() then
            Error(lTxt0, purchaseLine."No.");

    end;


    [EventSubscriber(ObjectType::Page, Page::"Purchase Order", 'OnAfterActionEvent', 'Post', true, true)]
    local procedure "Purchase Order_OnAfterActionEvent_[processing / P&osting] - Post"(var Rec: Record "Purchase Header")

    begin
        if (Rec."Document Type"::Order = Rec."Document Type") or (Rec."Document Type"::Invoice = Rec."Document Type") then
            invFSNUtilityDTE(Rec."Last Receiving No.", Rec."DTE AuthNumber", Rec."DTE Invoice", Rec."Signature Validation", Rec."No. Credit Memo Associated", 'PURCHINV', Rec."FSN Withholding Tax Amount");
        if (Rec."Document Type"::"Credit Memo" = Rec."Document Type") or (Rec."Document Type"::"Return Order" = Rec."Document Type") then
            invFSNUtilityDTE(Rec."Last Receiving No.", Rec."DTE AuthNumber", Rec."DTE Invoice", Rec."Signature Validation", Rec."No. Credit Memo Associated", 'PURCHMEM', Rec."FSN Withholding Tax Amount");
        //Evaluar las repceciones facturadas/no facturadas
        /*if Rec.Invoice then begin
            UpdateRcptInvoiced(Rec."No.");
        end;*/
    end;



    [EventSubscriber(ObjectType::Table, Database::"Purchase Line", 'OnBeforeInsertEvent', '', true, true)]
    local procedure "Purchase Line_OnBeforeInsertEvent"
    (
        var Rec: Record "Purchase Line";
        RunTrigger: Boolean
    )
    begin
        Rec."FSN Direct Unit Cost" := Rec."Direct Unit Cost";
    end;

    [EventSubscriber(ObjectType::Table, Database::"Purchase Line", 'OnAfterInsertEvent', '', true, true)]
    local procedure "Purchase Line_OnAfeterInsertEvent"
   (
       var Rec: Record "Purchase Line";
       RunTrigger: Boolean
   )
    begin
        Rec."FSN Direct Unit Cost" := Rec."Direct Unit Cost";
    end;


    [EventSubscriber(ObjectType::Page, Page::"Purchase Order Subform", 'OnModifyRecordEvent', '', true, true)]
    local procedure "Purchase Order Subform_OnModifyRecordEvent"
    (
        var Rec: Record "Purchase Line";
        var xRec: Record "Purchase Line";
        var AllowModify: Boolean
    )
    begin
        Rec."FSN Direct Unit Cost" := Rec."Direct Unit Cost";
    end;


    [EventSubscriber(ObjectType::Table, Database::"Purchase Line", 'OnBeforeValidateEvent', 'Direct Unit Cost', true, true)]
    local procedure "Purchase Line_OnBeforeValidateEvent_Direct Unit Cost"
    (
        var Rec: Record "Purchase Line";
        var xRec: Record "Purchase Line";
        CurrFieldNo: Integer
    )
    begin
        Rec."FSN Direct Unit Cost" := Rec."Direct Unit Cost";
    end;

    [EventSubscriber(ObjectType::Table, Database::"Purchase Line", 'OnAfterValidateEvent', 'Direct Unit Cost', true, true)]
    local procedure "Purchase Line_OnAfterValidateEvent_Direct Unit Cost"
       (
           var Rec: Record "Purchase Line";
           var xRec: Record "Purchase Line";
           CurrFieldNo: Integer
       )
    begin
        Rec."FSN Direct Unit Cost" := Rec."Direct Unit Cost";
    end;


    [EventSubscriber(ObjectType::Page, Page::"LSC Retail Purchase Order", 'OnAfterActionEvent', 'Release', true, true)]
    local procedure "LSC Retail Purchase Order_OnAfterActionEvent_[processing / Action13] - Release"(var Rec: Record "Purchase Header")
    var
        PurchExternalManager: Codeunit "FSN Batch - Send Purchase Data";
        //Vendor_l: Record Vendor;
        Store_l: Record "LSC Store";
        FasaniPurchSetup_l: Record "FSN Fasani Setup";
        ExternalLines_l: Record "FSN External Purch. Line";
        IDSelected: Option " ","Only Selected","All Transfer";
        Ok_: Boolean;
        LSMenu: Text[100];
        lText001: Label 'External Lines already exists';
        lText002: Label 'Sincronized lines sussesfull...';
        lText003: Label 'Vendor %1 is not allowed for purchase external lines';
        lText004: Label 'Vendor and Status Released is required for this action';
        lText005: Label 'Location %1 is not allowed use puchase external lines';
        lText006: Label 'Consolidate cant be empty';
        lTextMenu: Label '&Purchase Selected %1, &All Purchase Orders';
        scheduler: Record "LSC Scheduler Job Header";
        fsnParam: Record "FSN Parameter";
        vendorParameterList: List of [Text];
        vendorParameter: Text;
    begin
        //Se verificó el codigo con William, indica que no aplica alterar este flujo, se hará desde la codeunit 50000
        /*
        fsnParam.Reset();
        if Rec."Location Code" = 'CD' then begin
            if fsnParam.Get('CONFCOM', 'CONFRELCOM') then
                if fsnParam.Activo then begin
                    vendorParameterList := fsnParam.Valor.Split('|');
                    foreach vendorParameter in vendorParameterList do begin
                        if Rec."Buy-from Vendor No." <> vendorParameter then
                            exit;
                    end;
                end else
                    exit;
        end;
        LSMenu := STRSUBSTNO(lTextMenu, Rec."No.");
        IDSelected := STRMENU(LSMenu, 1);

        CASE IDSelected OF
            0:
                EXIT;
            2:
                BEGIN
                    scheduler.init;
                    PurchExternalManager.RUN(scheduler);
                    MESSAGE(lText002);
                    EXIT;
                END;
        END;

        Ok_ := FALSE;
        IF (Rec."Buy-from Vendor No." = '') OR (Rec.Status <> Rec.Status::Released) THEN
            ERROR(lText004);

        IF Rec."FSN Consolidate No." = '' THEN
            ERROR(lText006);

        ExternalLines_l.RESET;
        ExternalLines_l.SETCURRENTKEY("No.", "Line No.");
        ExternalLines_l.SETRANGE(ExternalLines_l."No.", Rec."No.");
        IF ExternalLines_l.FINDFIRST THEN BEGIN
            MESSAGE(lText001);
            EXIT;
        END;

        IF Rec."LSC Store No." <> '' THEN
            Ok_ := FasaniPurchSetup_l.GET(Rec."LSC Store No.")
        ELSE BEGIN
            Store_l.RESET;
            Store_l.SETCURRENTKEY("Location Code");
            IF Store_l.FINDFIRST THEN
                Ok_ := FasaniPurchSetup_l.GET(Store_l."No.");
        END;
        IF Ok_ THEN BEGIN
            IF FasaniPurchSetup_l."Use External Purch. Line" THEN BEGIN
                PurchExternalManager.SendCreateExternalLines(Rec);
                MESSAGE(lText002);
                EXIT;
            END ELSE
                Ok_ := FALSE;
        END;
        IF NOT Ok_ THEN
            MESSAGE(STRSUBSTNO(lText005, Rec."Ship-to Name"));
        */
    end;

    [EventSubscriber(ObjectType::Page, Page::"LSC Retail Receiving", 'OnOpenPageEvent', '', true, true)]
    local procedure "LSC Retail Receiving_OnOpenPageEvent"(var Rec: Record "LSC P/R Counting Header")
    var
        UserIdValue: Text;
        RetailUser: Record "LSC Retail User";
        TransferHeader: Record "Transfer Header";
        FasaniSetup: Record "FSN Fasani Setup";
        DateDif: Integer;
        lText001: Label 'Actividad  bloqueada por tener transferencias ptes. de recibir mayor a %1 dias de antiguedad.';
        ErrorValue: Boolean;
        ErrorText: text;
    begin
        ErrorText := '';
        if RetailUser.Get(UserId) then
            if FasaniSetup.Get(RetailUser."Store No.") then
                if FasaniSetup."Use Check Transfer" then begin
                    IF FasaniSetup."Qty. Days Blocked" <> 0 THEN BEGIN//6 error 4 message
                        IF (ValidateTransferLines(FasaniSetup."Qty. Days Blocked", FasaniSetup."Days For Transfer In", FasaniSetup."Store No.") <> '') THEN
                            ERROR(STRSUBSTNO(lText001), FasaniSetup."Qty. Days Blocked")
                        ELSE begin
                            if Rec."No." <> '' then begin
                                ErrorText := ValidateTransferLines(FasaniSetup."Days For Transfer In", FasaniSetup."Days For Transfer In", FasaniSetup."Store No.");
                                if ErrorText <> '' then
                                    Message(ErrorText);
                            end;
                        END;
                    end ELSE
                        if Rec."No." <> '' then begin
                            IF FasaniSetup."Days For Transfer In" <> 0 THEN begin
                                ErrorText := ValidateTransferLines(FasaniSetup."Days For Transfer In", FasaniSetup."Days For Transfer In", FasaniSetup."Store No.");
                                if ErrorText <> '' then
                                    Message(ErrorText);
                            end;
                        end;
                end;
    end;

    [EventSubscriber(ObjectType::Page, Page::"LSC Retail Receiving", 'OnInsertRecordEvent', '', true, true)]
    local procedure "LSC Retail Receiving_OnInsertRecordEvent"
    (
        var Rec: Record "LSC P/R Counting Header";
        var xRec: Record "LSC P/R Counting Header";
        var AllowInsert: Boolean;
        BelowxRec: Boolean
    )
    var
        UserIdValue: Text;
        RetailUser: Record "LSC Retail User";
        TransferHeader: Record "Transfer Header";
        FasaniSetup: Record "FSN Fasani Setup";
        DateDif: Integer;
        lText001: Label 'Actividad  bloqueada por tener transferencias ptes. de recibir mayor a %1 dias de antiguedad.';
        ErrorValue: Boolean;
        ErrorText: text;
    begin
        ErrorText := '';
        if RetailUser.Get(UserId) then
            if FasaniSetup.Get(RetailUser."Store No.") then
                if FasaniSetup."Use Check Transfer" then begin
                    IF FasaniSetup."Qty. Days Blocked" <> 0 THEN BEGIN//6 error 4 message
                        IF (ValidateTransferLines(FasaniSetup."Qty. Days Blocked", FasaniSetup."Days For Transfer In", FasaniSetup."Store No.") = '') THEN BEGIN
                            ErrorText := ValidateTransferLines(FasaniSetup."Days For Transfer In", FasaniSetup."Days For Transfer In", FasaniSetup."Store No.");
                            if ErrorText <> '' then
                                Message(ErrorText);
                        END;
                    end
                    ELSE
                        IF FasaniSetup."Days For Transfer In" <> 0 THEN begin
                            ErrorText := ValidateTransferLines(FasaniSetup."Days For Transfer In", FasaniSetup."Days For Transfer In", FasaniSetup."Store No.");
                            if ErrorText <> '' then
                                Message(ErrorText);
                        end;
                end;
    end;

    procedure ValidateTransferLines(QtyDays: Integer; DaysTransferIn: Integer; Location: Code[20]): Text
    var
        TransferInLine: Record "Transfer Line";
        TransferOut: Record "Transfer Header";
        TransferRequestHeader: Record "Transfer Header";
        lText001: Label 'Tienes transferencias pendientes de recibir. Mayor o igual a %1 dias de antiguedad';
        lText002: Label 'Tienes transferencias ptes. de enviar. Mayor o igual a %1 dias de antiguedad, esta ocasionando transito a otra Tienda.';
        lText003: Label 'Tienes solicitudes de transferencia pendientes de enviar. Podrias estar ocacionando transitos para ti y otra tienda.';
    begin
        IF QtyDays <> 0 THEN BEGIN
            TransferInLine.SETRANGE("Transfer-to Code", Location);
            TransferInLine.SETFILTER(TransferInLine."Item No.", '<>%1', '');
            TransferInLine.SETFILTER("Quantity Shipped", '<>%1', 0);
            TransferInLine.SETRANGE(TransferInLine.Status, TransferInLine.Status::Released);
            TransferInLine.SETFILTER(TransferInLine."Shipment Date", '<=%1', TODAY - (QtyDays - 1));
            IF TransferInLine.FINDSET() THEN
                EXIT(STRSUBSTNO(lText001, FORMAT(DaysTransferIn)))
            ELSE BEGIN //1
                TransferOut.SETRANGE("Transfer-from Code", Location);
                TransferOut.SETRANGE("LSC Retail Status", TransferOut."LSC Retail Status"::Sent);
                TransferOut.SETFILTER(TransferOut."Shipment Date", '<=%1', TODAY - (QtyDays - 1));
                IF TransferOut.FINDSET() THEN
                    EXIT(STRSUBSTNO(lText002, FORMAT(DaysTransferIn)))
                ELSE BEGIN //2
                    TransferRequestHeader.SETRANGE("Transfer-to Code", Location);
                    TransferRequestHeader.SETFILTER("LSC Retail Status", '%1|%2', TransferOut."LSC Retail Status"::New, TransferOut."LSC Retail Status"::"Planned receive");
                    //TransferRequestHeader.SETRANGE("Retail Status",TransferOut."Retail Status"::New);
                    TransferRequestHeader.SETFILTER(TransferRequestHeader."Shipment Date", '<=%1', TODAY - (QtyDays - 1));
                    IF TransferRequestHeader.FINDSET() THEN
                        EXIT(lText003)
                    ELSE
                        EXIT('');
                END;//2
            END;//1
        END
        ELSE
            EXIT('');
    end;

    //JH021024-PURCH_VR_JH1

    [EventSubscriber(ObjectType::Page, Page::"LSC Stock Request", 'OnAfterActionEvent', '&Send Request', true, true)]
    local procedure "LSC Stock Request_OnAfterActionEvent_[processing / F&unctions] - &Send Request"(var Rec: Record "LSC InStore Stock Req. Header")
    var
        StockReqMgt: Codeunit "LSC InStore Stock Req Mgt";
        xStockReqHeader: Record "LSC InStore Stock Req. Header";
        reqLine: Record "LSC InStore Stock Req. Line";
        fsnParam: Record "FSN Parameter";
        item: Record "Item";
        vendorDiff: Boolean;
        itemVendor: Code[20];
        nameVendor: Code[50];
        vendor: Record Vendor;
        lTex001: Label 'La solicitud tiene productos con diferentes proveedores, no procede el envio automatico';
        lTex002: Label 'El pedido fue autorizado automaticamente, Proveedor %1, Pedido: %2';
    begin
        //Reset Variables
        reqLine.Reset();
        fsnParam.Reset();
        item.Reset();
        vendor.Reset();
        //valida tipo orden: compra, tipo proceso: Crear, Estado Req: Nuevo
        //if Rec."Document Type"::"Purchase Order" = Rec."Document Type" then
        if Rec."Process Type"::Create = Rec."Process Type" then
            if Rec."Req. Status"::Sent = Rec."Req. Status" then begin
                reqLine.SetRange("Document No.", Rec."No.");
                if reqLine.FindFirst() then
                    repeat begin
                        //Obtiene el vendedor por prod. y verifica que sea el mismo
                        if item.Get(reqLine."Item No.") then begin
                            itemVendor := item."Vendor No.";
                            if itemVendor <> item."Vendor No." then
                                vendorDiff := true;
                        end;
                    end until reqLine.Next() = 0;
            end;
        //Valida proveedor en paramefsn: activo
        fsnParam.SetRange(Grupo, 'SOLSTOCK');
        fsnParam.SetRange(Activo, true);
        fsnParam.SetRange(Codigo, itemVendor);
        if fsnParam.FindFirst() then begin
            //Cancela el proceso por proveedor diferentes en prod
            if vendorDiff then
                Error(lTex001);
            if vendor.Get(itemVendor) then
                if vendor.Name <> '' then
                    nameVendor := vendor."Name"
                else
                    nameVendor := vendor."Name 2";
            Rec."Document Type" := Rec."Document Type"::"Purchase Order";
            Rec."Vendor No." := itemVendor;
            Rec.TestField("Vendor No.");
            StockReqMgt.CreatePurchasOrder(Rec, itemVendor);
            if xStockReqHeader.Get(Rec."No.") then;
            Message(lTex002, nameVendor, xStockReqHeader."Reference No.");
        end;

    end;
    //JH021024-PURCH_VR_JH1

    [EventSubscriber(ObjectType::Table, Database::"Purchase Header", 'OnAfterValidateEvent', 'Buy-from Vendor No.', true, true)]
    local procedure "Purchase Header_OnAfterValidateEvent_Buy-from Vendor No."
    (
        var Rec: Record "Purchase Header";
        var xRec: Record "Purchase Header";
        CurrFieldNo: Integer
    )
    var
        vendor: Record Vendor;
    begin
        vendor.reset();
        if (Rec."Buy-from Vendor No." <> '') then
            if vendor.Get(Rec."Buy-from Vendor No.") then
                if vendor."Associated Credit Memo" then
                    Rec."Associated Credit Memo" := vendor."Associated Credit Memo";
    end;



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
        PurchOrder: Record "Purchase Header";
        PurchRcptHdr: Record "Purch. Rcpt. Header";
        RecCounHeader: record "LSC P/R Counting Header";
    begin

        if RequestID = 'UPDASSOCPH' then begin
            PurchOrder.Reset();
            PurchOrder.SetRange("Document Type", PurchOrder."Document Type"::Order);
            PurchOrder.SetRange("No.", POSMenuLine."Menu ID", POSMenuLine.Command);
            if PurchOrder.Find('-') then
                repeat
                    PurchOrder."Associated Credit Memo" := true;
                    PurchOrder.Modify();
                until PurchOrder.Next() = 0;
        end;

        if RequestID = 'FCPURCHDTE' then begin
            PurchOrder.Reset();//28981
            PurchOrder.SetRange(PurchOrder."Document Type", PurchOrder."Document Type"::Invoice);
            PurchOrder.SetRange(PurchOrder."No.", POSMenuLine.Command);
            if PurchOrder.FindFirst() then begin
                PurchOrder."DTE AuthNumber" := XMLRequest;
                PurchOrder."DTE Invoice" := XMLResponse;
                PurchOrder."Signature Validation" := MsgResult;
                PurchOrder.Modify();

            end;
        end;
        if RequestID = 'FSN-VENDOR-INV-NO' then begin
            PurchRcptHdr.Reset();
            if PurchRcptHdr.Get(POSMenuLine."Menu ID") then begin
                POSMenuLine."Data ID" := PurchRcptHdr."FSN Vendor Invoice No.";
            end;
        end;
        if RequestID = 'UPD-DTE-HISRECPURA' then begin
            RecCounHeader.Reset();
            if RecCounHeader.Get(POSMenuLine."Menu ID") then begin
                RecCounHeader."DTE Invoice" := POSMenuLine."Set Current-Input";
                RecCounHeader."DTE AuthNumber" := POSMenuLine."Current-Description";
                RecCounHeader."Signature Validation" := POSMenuLine."Current-Description2";
                RecCounHeader.Modify();
                Commit();
            end;
        end;
    end;

    procedure UpdateReplenAssocCreditMemo(RequestIDComando: Code[50]; NoVendor: Code[20]; Activo: Boolean)
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
        PosMenuLineTemp."Menu ID" := NoVendor;
        PosMenuLineTemp.Disabled := Activo;
        FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
    end;


    //JH-PURCH DTE REQUEST

    procedure UpdatePurchLineCost(var header: Record "LSC P/R Counting Header"; CodGeneracion: Code[50]; scannManual: Boolean)
    var
        //header: Record "LSC P/R Counting Header";
        PurchaseHeader: Record "Purchase Header";
        purchaseLine: Record "Purchase Line";
        PRConfirm: Codeunit "LSC Picking/Receiving Confirm";
        Text000: Label 'Costo no puede exceder mas $0.03';
        Text001: Label 'No se encontro el DTE enviado por el proveedor';
        Text002: Label 'Los productos de la recepción no coinciden con el DTE ingresado';
        Text004: Label 'Pendiente Configuración Parametro Proveedor sin Escaneo-> Grupo:CONFCOM Codigo:CONFPROCOM';
        Text005: Label 'Pendiente Configuración Parametro Proveedor sin Escaneo-> Grupo:CONFCOM Codigo:CONFSTOCOM';
        json, obj, obj2 : JsonObject;
        productList: JsonArray;
        product: JsonToken;
        resumen: JsonToken;
        property: JsonToken;
        itemNo: Code[20];
        CostDte: Decimal;
        QuantityDte: Integer;
        NumItemDte: Integer;
        CountedDate: Date;
        pickingLine: Record "LSC Picking / Receiving lines";
        parameterList: List of [Text];
        parameterValue: Text;
        fsnParam: Record "FSN Parameter";
        scann: Boolean;
    begin
        //if not header.Get(counting."No.") then
        //exit;
        header.ConfirmarSubTotal := 0;
        header.ConfirmarTax := 0;
        header.ConfirmarTotal := 0;

        json := IAApiConsultingPurchOrder(header."Reference No.", CodGeneracion, header."Vendor No. / Customer No.");
        if json.SelectToken('status', property) then
            if property.AsValue().AsInteger() <> 200 then begin
                Message(Text001);
                exit;
            end;

        if json.SelectToken('body.Resumen', resumen) then begin
            obj2 := resumen.AsObject();
            if obj2.SelectToken('SubTotal', property) then
                header.ConfirmarSubTotal := property.AsValue().AsDecimal();
            if obj2.SelectToken('IVA', property) then
                header.ConfirmarTax := property.AsValue().AsDecimal();
            if obj2.SelectToken('MontoTotalOperacion', property) then
                header.ConfirmarTotal := property.AsValue().AsDecimal();
        end;

        if json.SelectToken('body.FecEmi', property) then begin
            //header."Counted Date" := property.AsValue().AsDate();
            header."Counted Date" := Today(); //JH06092024-Recepcion Compra DTE, se toma la fecha actual
        end;

        header."FSN Automatic Search" := true;

        if scannManual then begin
            header.Modify(true);
            exit;
        end;

        if json.SelectToken('body.Productos', product) then
            productList := product.AsArray();
        if productList.Count = 0 then begin
            Message(Text001);
            exit;
        end;



        scann := true;
        Clear(parameterValue);
        fsnParam.Reset();
        if fsnParam.Get('CONFCOM', 'CONFPROCOM') then begin
            parameterList := fsnParam.Valor.Split('|');
            foreach parameterValue in parameterList do begin
                if header."Vendor No. / Customer No." = parameterValue then begin
                    scann := false;
                    break;
                end;
            end;
        end else
            Error(Text004);
        fsnParam.Reset();
        if fsnParam.Get('CONFCOM', 'CONFSTOCOM') then begin
            parameterList := fsnParam.Valor.Split('|');
            foreach parameterValue in parameterList do begin
                if header."Location Code" = parameterValue then begin
                    scann := false;
                    break;
                end;
            end;
        end else
            Error(Text005);
        PurchaseHeader.Reset();
        PurchaseHeader.SetCurrentKey("Document Type", "No.");
        PurchaseHeader.SetRange(PurchaseHeader."Document Type", PurchaseHeader."Document Type"::Order);
        PurchaseHeader.SetRange(PurchaseHeader."No.", header."Reference No.");
        if PurchaseHeader.FindFirst() then begin
            PurchaseHeader.Status := PurchaseHeader.Status::Open;
            PurchaseHeader.Modify(true);
            purchaseLine.Reset();
            purchaseLine.SetRange("Document No.", PurchaseHeader."No.");
            purchaseLine.SetFilter("Quantity Received", '%1', 0);
            if purchaseLine.FindFirst() then begin
                repeat begin

                    foreach product in productList do begin
                        CostDte := 0;
                        QuantityDte := 0;
                        obj := product.AsObject();
                        if obj.SelectToken('ItemNo_', property) then begin
                            if property.AsValue().AsText() = purchaseLine."No." then begin

                                if obj.SelectToken('NumItem', property) then
                                    NumItemDte := property.AsValue().AsInteger();

                                if obj.SelectToken('Quantity_DTE', property) then
                                    QuantityDte := property.AsValue().AsInteger();

                                if obj.SelectToken('Unit_Cost_DTE', property) then
                                    CostDte := property.AsValue().AsDecimal();

                                pickingLine.Reset();
                                pickingLine.SetRange("Document No.", header."No.");
                                pickingLine.SetRange("Item No.", purchaseLine."No.");
                                if pickingLine.FindFirst() then begin

                                    if not scann then begin
                                        if (-pickingLine."Difference") > 0 then begin
                                            if pickingLine.Quantity <> 0 then
                                                QuantityDte += pickingLine.Quantity;
                                            pickingLine.Validate(Quantity, QuantityDte);
                                        end;
                                    end;
                                    pickingLine."FSN Cantidad DTE" := QuantityDte;
                                    if CostDte <> purchaseLine."Direct Unit Cost" then begin
                                        if purchaseLine."FSN Direct Unit Cost" = 0 then
                                            purchaseLine."FSN Direct Unit Cost" := purchaseLine."Direct Unit Cost";
                                        if Abs(CostDte - purchaseLine."FSN Direct Unit Cost") >= 0.03 then
                                            pickingLine."FSN Revisar Costo" := true
                                        else begin
                                            purchaseLine.Validate("Direct Unit Cost", Abs(CostDte));
                                            purchaseLine.Modify(true);
                                        end;
                                    end;
                                    pickingLine."FSN Orden Facturado" := NumItemDte;
                                    pickingLine."FSN Escaneo Pendiente" := scann;
                                    pickingLine.Modify(true);
                                end;
                            end;
                        end;
                    end;
                end until purchaseLine.Next() = 0;
            end;
            header.Modify(true);
            PurchaseHeader.Status := PurchaseHeader.Status::Released;
            PurchaseHeader.Modify(true);
        end;
    end;


    procedure PurchRequestJson(NoOrden: Code[20]; CodGeneracion: Code[50]; CodProveedor: Code[20]): JsonObject
    var
        PurchLine: Record "Purchase Line";
        requestJson: JsonObject;
        propertyJson: JsonObject;
        orderJson: JsonObject;
        productosJson: JsonArray;
        purchlineText: Text;
        Item: Record Item;
        itemVendor: Record "Item Vendor";
    begin
        Clear(requestJson);
        Clear(propertyJson);
        Clear(orderJson);
        Clear(productosJson);
        PurchLine.reset();
        PurchLine.SetRange("Document No.", NoOrden);
        if PurchLine.FindFirst() then begin
            repeat begin
                Clear(propertyJson);
                propertyJson.Add('No_', purchLine."Document No.");
                propertyJson.Add('LineNo_', purchLine."Line No.");
                propertyJson.Add('ItemNo_', purchLine."No.");
                propertyJson.Add('Description', UpperCase(purchLine.Description));
                propertyJson.Add('Quantity', purchLine.Quantity);
                propertyJson.Add('Unit_Cost', purchLine."Unit Cost");
                propertyJson.Add('Quantity_DTE', 0);
                propertyJson.Add('Unit_Cost_DTE', 0);
                /* US-508*********
                Item.Reset();
                if Item.get(PurchLine."No.") then
                    if Item."Vendor Item No." <> '' then
                        propertyJson.Add('CodeDte', item."Vendor Item No.");
                ******************/
                //US-508**********
                itemVendor.Reset();
                itemVendor.SetRange("Item No.", PurchLine."No.");
                itemVendor.SetRange("Vendor No.", CodProveedor);
                if itemVendor.FindFirst() then
                    propertyJson.Add('CodeDte', itemVendor."Vendor Item No.");
                //US-508**********
                productosJson.Add(propertyJson);
            end until PurchLine.Next() = 0;
        end;
        orderJson.Add('Productos', productosJson);
        orderJson.WriteTo(purchlineText);
        requestJson.Add('orderJson', purchlineText);
        requestJson.Add('codigoGeneracion', CodGeneracion);
        exit(requestJson);
    end;

    local procedure JsonResponseTest(): Text
    var
        myInt: Integer;
    begin
        exit('{   "Productos": [     {       "Umbral": "Productos encontrados con umbral >= 80"     },     {       "NumItem": 24,       "No_": "PED00156081",     "Description": "LORATADINA LS 10MG X 10 TABLETAS",       "Quantity": 40.00000000000000000000,       "Unit_Cost": 3.08200000000000000000,       "Quantity_DTE": 40.0,       "Unit_Cost_DTE": 3.082,       "Encontrado": true,       "DescripcionDte": "LORATADINA LS 10 MG X 10 TABLETAS"     },     {       "NumItem": 41,       "No_": "PED00156081",       "Description": "PRIPAX 10 MG X 30 COMPRIMIDOS",       "Quantity": 1.00000000000000000000,       "Unit_Cost": 33.93040000000000000000,       "Quantity_DTE": 1.0,       "Unit_Cost_DTE": 33.93,       "Encontrado": true,       "DescripcionDte": "PRIPAX 10MG X 30 COMPRIMIDOS"     },     {       "NumItem": 16,       "No_": "PED00156081",       "Description": "REGENOL FORTE BEBIBLE X 12 SACHETS",       "Quantity": 12.00000000000000000000,       "Unit_Cost": 12.80370000000000000000,       "Quantity_DTE": 12.0,       "Unit_Cost_DTE": 12.8033,       "Encontrado": true,       "DescripcionDte": "REGENOL FORTE AMPOLLETA BEBIBLE X 12"     },     {       "NumItem": 46,       "No_": "PED00156081",       "Description": "SMECTA POLVO PARA SOLUCION ORAL X 10 SOBRES",       "Quantity": 4.00000000000000000000,       "Unit_Cost": 9.54500000000000000000,       "Quantity_DTE": 4.0,       "Unit_Cost_DTE": 9.545,       "Encontrado": true,       "DescripcionDte": "SMECTA X 10 SOBRES"     },     {       "NumItem": 48,       "No_": "PED00156081",       "Description": "LOCION CAPILAR REGENEX COMPLEX BELLEPON 250ML",       "Quantity": 2.00000000000000000000,       "Unit_Cost": 3.05000000000000000000,       "Quantity_DTE": 2.0,       "Unit_Cost_DTE": 3.05,       "Encontrado": true,       "DescripcionDte": "BELLEPON LOCION CAPILAR 250 ML"     },     {       "NumItem": 7,       "No_": "PED00156081",       "Description": "DESODORANTE ARM - HAMMER MAX ACTIVE SPORT 73GRS",       "Quantity": 1.00000000000000000000,       "Unit_Cost": 2.47000000000000000000,       "Quantity_DTE": 1.0,       "Unit_Cost_DTE": 2.47,       "Encontrado": true,       "DescripcionDte": "ARM HAMMER MAX ACTIVE SPORT"     },     {       "NumItem": 30,       "No_": "PED00156081",       "Description": "ENERGYSIL FORTE BEBIBLE X 12 SACHETS",       "Quantity": 18.00000000000000000000,       "Unit_Cost": 6.28460000000000000000,       "Quantity_DTE": 18.0,       "Unit_Cost_DTE": 6.2844,       "Encontrado": true,       "DescripcionDte": "ENERGYSIL FORTE SOLUCIÓN  X 12 SACHETS"     },     {       "NumItem": 29,       "No_": "PED00156081",       "Description": "BRONCOHELIX C JARABE 120ML",       "Quantity": 12.00000000000000000000,       "Unit_Cost": 7.09000000000000000000,       "Quantity_DTE": 12.0,       "Unit_Cost_DTE": 7.0883,       "Encontrado": true,       "DescripcionDte": "BRONCOHELIX-C JARABE 120ML"     },     {       "NumItem": 33,       "No_": "PED00156081",       "Description": "BICARBONATO DE SODIO LS 1/2 LIBRA",       "Quantity": 3.00000000000000000000,       "Unit_Cost": 1.40700000000000000000,       "Quantity_DTE": 3.0,       "Unit_Cost_DTE": 1.4067,       "Encontrado": true,       "DescripcionDte": "BICARBONATO DE SODIO X 227 G"     },     {       "NumItem": 28,       "No_": "PED00156081",       "Description": "TRAMADEX PLUS X 10 TABLETAS",       "Quantity": 12.00000000000000000000,       "Unit_Cost": 10.67310000000000000000,       "Quantity_DTE": 12.0,       "Unit_Cost_DTE": 10.6733,       "Encontrado": true,       "DescripcionDte": "TRAMADEX PLUS TABLETAS RECUBIERTAS X 10"     },     {       "NumItem": 34,       "No_": "PED00156081",       "Description": "SULFASIL SUSPENSION ORAL 120ML (TRIMETROPRIN+SULFA",       "Quantity": 3.00000000000000000000,       "Unit_Cost": 3.32990000000000000000,       "Quantity_DTE": 3.0,       "Unit_Cost_DTE": 3.33,       "Encontrado": true,       "DescripcionDte": "SULFASIL SUSPENSION X 120 ML"     },     {       "NumItem": 35,       "No_": "PED00156081",       "Description": "HONGOSIL FORTE CREMA 2% TUBO X 20 GRAMOS",       "Quantity": 12.00000000000000000000,       "Unit_Cost": 2.34500000000000000000,       "Quantity_DTE": 12.0,       "Unit_Cost_DTE": 2.345,       "Encontrado": true,       "DescripcionDte": "HONGOSIL FORTE CREMA 2% X 20 GR"     },     {       "NumItem": 22,       "No_": "PED00156081",       "Description": "ACNESIL CREMA TUBO X 20 GRAMOS",       "Quantity": 2.00000000000000000000,       "Unit_Cost": 1.83580000000000000000,       "Quantity_DTE": 2.0,       "Unit_Cost_DTE": 1.835,       "Encontrado": true,       "DescripcionDte": "ACNESIL 20 GRS"     },     {       "NumItem": 40,       "No_": "PED00156081",       "Description": "CEPILLO DENTAL KIN SUAVE",       "Quantity": 3.00000000000000000000,       "Unit_Cost": 2.79350000000000000000,       "Quantity_DTE": 3.0,       "Unit_Cost_DTE": 2.7933,       "Encontrado": true,       "DescripcionDte": "CEPILLO KIN SUAVE BIMATERIAL"     },     {       "NumItem": 10,       "No_": "PED00156081",       "Description": "DIXI 35 X 21 TABLETAS",       "Quantity": 3.00000000000000000000,       "Unit_Cost": 5.99720000000000000000,       "Quantity_DTE": 3.0,       "Unit_Cost_DTE": 6.0,       "Encontrado": true,       "DescripcionDte": "DIXI 35 X 21 TABLETAS"     },     {       "NumItem": 1,       "No_": "PED00156081",       "Description": "HERPESAN GEL 2% TUBO X 5 GRAMOS",       "Quantity": 2.00000000000000000000,       "Unit_Cost": 6.00000000000000000000,       "Quantity_DTE": 2.0,       "Unit_Cost_DTE": 6.0,       "Encontrado": true,       "DescripcionDte": "HERPESAN GEL 5 GRAMOS"     },     {       "NumItem": 44,       "No_": "PED00156081",       "Description": "KIN GINGIVAL COLUTORIO 250 ML",       "Quantity": 4.00000000000000000000,       "Unit_Cost": 11.90520000000000000000,       "Quantity_DTE": 4.0,       "Unit_Cost_DTE": 11.905,       "Encontrado": true,       "DescripcionDte": "KIN GINGIVAL COMPLEX COLUTORIO 250ML"     },     {       "NumItem": 15,       "No_": "PED00156081",       "Description": "NO + ZANCUDOS LOCION SPRAY 130 ML",       "Quantity": 11.00000000000000000000,       "Unit_Cost": 2.60630000000000000000,       "Quantity_DTE": 11.0,       "Unit_Cost_DTE": 2.6064,       "Encontrado": true,       "DescripcionDte": "NO + ZANCUDOS LOCION REPELENTE 130 ML"     },     {       "NumItem": 23,       "No_": "PED00156081",       "Description": "ANTIGRIP-SIL X 1 AMPOLLA 5 ML",       "Quantity": 48.00000000000000000000,       "Unit_Cost": 1.78220000000000000000,       "Quantity_DTE": 48.0,       "Unit_Cost_DTE": 1.7823,       "Encontrado": true,       "DescripcionDte": "ANTIGRIP AMPOLLA X 5 ML."     },     {       "NumItem": 3,       "No_": "PED00156081",       "Description": "ROWACHOL X 100 PERLAS",       "Quantity": 1.00000000000000000000,       "Unit_Cost": 16.70400000000000000000,       "Quantity_DTE": 1.0,       "Unit_Cost_DTE": 16.7,       "Encontrado": true,       "DescripcionDte": "ROWACHOL X 100 CAPSULAS"     },     {       "NumItem": 2,       "No_": "PED00156081",       "Description": "ROWATINEX X 100 PERLAS",       "Quantity": 4.00000000000000000000,       "Unit_Cost": 16.70400000000000000000,       "Quantity_DTE": 4.0,       "Unit_Cost_DTE": 16.705,       "Encontrado": true,       "DescripcionDte": "ROWATINEX X 100 CAPSULAS"     },     {       "NumItem": 36,       "No_": "PED00156081",       "Description": "SENSIKIN ENJUAGUE BUCAL FRASCO X 500 ML",       "Quantity": 2.00000000000000000000,       "Unit_Cost": 10.95870000000000000000,       "Quantity_DTE": 2.0,       "Unit_Cost_DTE": 10.96,       "Encontrado": true,       "DescripcionDte": "SENSIKIN ENJUAGUE BUCAL 500 ML."     },     {       "NumItem": 37,       "No_": "PED00156081",       "Description": "SENSIKIN PASTA DENTRIFICA TUBO X 75 ML",       "Quantity": 2.00000000000000000000,       "Unit_Cost": 9.78400000000000000000,       "Quantity_DTE": 2.0,       "Unit_Cost_DTE": 9.785,       "Encontrado": true,       "DescripcionDte": "SENSIKIN PASTA DENTIFRICA 75 ML."     },     {       "NumItem": 39,       "No_": "PED00156081",       "Description": "SUPRAMYCINA 100MG X 10 TABLETAS",       "Quantity": 3.00000000000000000000,       "Unit_Cost": 4.59190000000000000000,       "Quantity_DTE": 3.0,       "Unit_Cost_DTE": 4.59,       "Encontrado": true,       "DescripcionDte": "SUPRAMYCINA 100 MG. CAJA X 10 TABLETAS"     },     {       "NumItem": 8,       "No_": "PED00156081",       "Description": "TERMOMETRO DIGITAL SUIZOS",       "Quantity": 12.00000000000000000000,       "Unit_Cost": 3.67830000000000000000,       "Quantity_DTE": 12.0,       "Unit_Cost_DTE": 3.6783,       "Encontrado": true,       "DescripcionDte": "TERMOMETRO DIGITAL"     },     {       "NumItem": 19,       "No_": "PED00156081",       "Description": "TOSSIL X 100 CARAMELOS",       "Quantity": 6.00000000000000000000,       "Unit_Cost": 3.32320000000000000000,       "Quantity_DTE": 6.0,       "Unit_Cost_DTE": 3.3233,       "Encontrado": true,       "DescripcionDte": "TOSSIL CARAMELOS BOL. X100"     },     {       "NumItem": 32,       "No_": "PED00156081",       "Description": "VITASIL C CON ROSA DE MOSQUETA X 50 TABLETAS",       "Quantity": 24.00000000000000000000,       "Unit_Cost": 5.92950000000000000000,       "Quantity_DTE": 24.0,       "Unit_Cost_DTE": 5.9296,       "Encontrado": true,       "DescripcionDte": "VITASIL C CON ROSA MOSQUETA 500mg X 50"     },     {       "NumItem": 26,       "No_": "PED00156081",       "Description": "VITASIL OMEGA-3 X 50 CAPSULAS DE GELATINA BLANDA",       "Quantity": 36.00000000000000000000,       "Unit_Cost": 6.61960000000000000000,       "Quantity_DTE": 36.0,       "Unit_Cost_DTE": 6.6197,       "Encontrado": true,       "DescripcionDte": "VITASIL OMEGA 3 X 50 CAPSULAS"     },     {       "NumItem": 27,       "No_": "PED00156081",       "Description": "LEVOSIL 500MG X 10 TABLETAS (LEVOFLOXACINA)",       "Quantity": 6.00000000000000000000,       "Unit_Cost": 18.13690000000000000000,       "Quantity_DTE": 6.0,       "Unit_Cost_DTE": 18.1367,       "Encontrado": true,       "DescripcionDte": "LEVOSIL X 10 TABLETAS"     },     {       "NumItem": 20,       "No_": "PED00156081",       "Description": "AZITROSIL 500MG X 3 TABLETAS",       "Quantity": 20.00000000000000000000,       "Unit_Cost": 6.11710000000000000000,       "Quantity_DTE": 20.0,       "Unit_Cost_DTE": 6.117,       "Encontrado": true,       "DescripcionDte": "AZITROSIL X 3 TABLETAS"     },     {       "Umbral": "Productos encontrados con umbral >= 70"     },     {       "NumItem": 18,       "No_": "PED00156081",       "Description": "BELLAFACE X 21 COMPRIMIDOS",       "Quantity": 3.00000000000000000000,       "Unit_Cost": 9.81060000000000000000,       "Quantity_DTE": 3.0,       "Unit_Cost_DTE": 9.81,       "Encontrado": true,       "DescripcionDte": "BELLAFACE X 21 TABLETAS"     },     {       "NumItem": 42,       "No_": "PED00156081",       "Description": "ANTIGRIP COMBINADO AM-PM X 6 SOBRES DE 2 TABLETAS",       "Quantity": 18.00000000000000000000,       "Unit_Cost": 1.51420000000000000000,       "Quantity_DTE": 18.0,       "Unit_Cost_DTE": 1.5144,       "Encontrado": true,       "DescripcionDte": "ANTIGRIP COMBINADO X6 SOBRES (3AM +3PM )"     },     {       "NumItem": 43,       "No_": "PED00156081",       "Description": "DICLOSIL POTASICO 50MG X 10 TABLETAS (DICLOFENACO)",       "Quantity": 12.00000000000000000000,       "Unit_Cost": 2.71350000000000000000,       "Quantity_DTE": 12.0,       "Unit_Cost_DTE": 2.7133,       "Encontrado": true,       "DescripcionDte": "DICLOSIL TABLETAS RECUBIERTAS X 10"     },     {       "NumItem": 25,       "No_": "PED00156081",       "Description": "DOLOCRIM FORTE TARRO MEDIANO",       "Quantity": 10.00000000000000000000,       "Unit_Cost": 2.68670000000000000000,       "Quantity_DTE": 10.0,       "Unit_Cost_DTE": 2.687,       "Encontrado": true,       "DescripcionDte": "DOLOCRIM FORTE 113 GR."     },     {       "NumItem": 49,       "No_": "PED00156081",       "Description": "OSTEO-BI FLEX COMPLEX X 60 TABLETAS",       "Quantity": 3.00000000000000000000,       "Unit_Cost": 16.60260000000000000000,       "Quantity_DTE": 3.0,       "Unit_Cost_DTE": 16.6033,       "Encontrado": true,       "DescripcionDte": "OSTEO BI-FLEX COMPLEX 60 TAB"     },     {       "NumItem": 45,       "No_": "PED00156081",       "Description": "CRESADEX 20MG X 30 COMPRIMIDOS",       "Quantity": 1.00000000000000000000,       "Unit_Cost": 30.22860000000000000000,       "Quantity_DTE": 1.0,       "Unit_Cost_DTE": 30.23,       "Encontrado": true,       "DescripcionDte": "CRESADEX 20 MG X 30 TAB"     },     {       "NumItem": 6,       "No_": "PED00156081",       "Description": "ALGODÓN SUIZO SKY COTTON X 1 LIBRA",       "Quantity": 2.00000000000000000000,       "Unit_Cost": 2.25600000000000000000,       "Quantity_DTE": 2.0,       "Unit_Cost_DTE": 2.255,       "Encontrado": true,       "DescripcionDte": "ALGODON SUIZO DE 1 LIBRA"     },     {       "NumItem": 9,       "No_": "PED00156081",       "Description": "JERINGA NIPRO 3CC X 22-1Y1/2 X 100 UNIDADES",       "Quantity": 2.00000000000000000000,       "Unit_Cost": 6.90000000000000000000,       "Quantity_DTE": 2.0,       "Unit_Cost_DTE": 6.9,       "Encontrado": true,       "DescripcionDte": "JERINGA 3CC 22 X 1 1/2 CAJA X 100 NIPRO"     },     {       "NumItem": 5,       "No_": "PED00156081",       "Description": "SOLIDAGO COMPOSITUM SUIS X 1 AMPOLLA",       "Quantity": 5.00000000000000000000,       "Unit_Cost": 6.16810000000000000000,       "Quantity_DTE": 5.0,       "Unit_Cost_DTE": 6.168,       "Encontrado": true,       "DescripcionDte": "SOLIDAGO COMP. X 1 AMPOLLAS"     },     {       "NumItem": 17,       "No_": "PED00156081",       "Description": "BABYSIL CREMA PROTECTORA ANTIPAÑALITIS TUBO 50G",       "Quantity": 4.00000000000000000000,       "Unit_Cost": 2.46560000000000000000,       "Quantity_DTE": 4.0,       "Unit_Cost_DTE": 2.465,       "Encontrado": true,       "DescripcionDte": "BABYSIL CREMA 50 GRS."     },     {       "Umbral": "Productos encontrados con umbral >= 60"     },     {       "NumItem": 47,       "No_": "PED00156081",       "Description": "SHAMPOO BELLEPON MATIZADOR Y LUCES 440ML",       "Quantity": 2.00000000000000000000,       "Unit_Cost": 2.66000000000000000000,       "Quantity_DTE": 2.0,       "Unit_Cost_DTE": 2.66,       "Encontrado": true,       "DescripcionDte": "BELLEPON MATIZ/LUCES SH. 440ML."     },     {       "NumItem": 31,       "No_": "PED00156081",       "Description": "NO+PARASITOS INFANTIL SUSPENSION ORAL X 10ML",       "Quantity": 6.00000000000000000000,       "Unit_Cost": 5.94960000000000000000,       "Quantity_DTE": 6.0,       "Unit_Cost_DTE": 5.95,       "Encontrado": true,       "DescripcionDte": "NO+PARÁSITOS (QUINFAMIDA/MEBENDAZOL) SUSPENSIÓN INFANTIL X 10 ML"     },     {       "NumItem": 4,       "No_": "PED00156081",       "Description": "ALGODÓN SUIZO SKY COTTON BOLSA X 25 GRAMOS",       "Quantity": 6.00000000000000000000,       "Unit_Cost": 0.27200000000000000000,       "Quantity_DTE": 6.0,       "Unit_Cost_DTE": 0.2717,       "Encontrado": true,       "DescripcionDte": "ALGODON SUIZO DE 25 GRS."     },     {       "NumItem": 38,       "No_": "PED00156081",       "Description": "TRAMAL 100MG INYECTABLE X 5 AMPOLLAS 2ML",       "Quantity": 1.00000000000000000000,       "Unit_Cost": 4.91280000000000000000,       "Quantity_DTE": 1.0,       "Unit_Cost_DTE": 4.91,       "Encontrado": true,       "DescripcionDte": "TRAMAL 100 MG. INYECT. CAJA X 5 AMP."     },     {       "NumItem": 11,       "No_": "PED00156081",       "Description": "VITASIL E 400 U.I.X 30 PERLAS",       "Quantity": 20.00000000000000000000,       "Unit_Cost": 5.17240000000000000000,       "Quantity_DTE": 20.0,       "Unit_Cost_DTE": 5.1725,       "Encontrado": true,       "DescripcionDte": "VITASIL E-400  X 30 CAPSULAS"     },     {       "NumItem": 13,       "No_": "PED00156081",       "Description": "DEXA-VITASIL INYECTABLE (NEUROTROPAS+DEXAMETASONA)",       "Quantity": 36.00000000000000000000,       "Unit_Cost": 4.24780000000000000000,       "Quantity_DTE": 36.0,       "Unit_Cost_DTE": 4.2478,       "Encontrado": true,       "DescripcionDte": "DEXA-VITASIL 2 ML. X 2 AMP."     },     {       "Umbral": "Productos encontrados con umbral >= 50"     },     {       "NumItem": 21,       "No_": "PED00156081",       "Description": "BABYSIL CREMA PROTECTORA ANTIPAÑALITIS NEW 226G",       "Quantity": 1.00000000000000000000,       "Unit_Cost": 6.51910000000000000000,       "Quantity_DTE": 1.0,       "Unit_Cost_DTE": 6.52,       "Encontrado": true,       "DescripcionDte": "BABYSIL CREMA TARRO X 226 GRAMOS"     },     {       "NumItem": 14,       "No_": "PED00156081",       "Description": "DOLO-VITASIL INYECTABLE (NEUROTROPAS+DICLOFENACO)",       "Quantity": 20.00000000000000000000,       "Unit_Cost": 3.77570000000000000000,       "Quantity_DTE": 20.0,       "Unit_Cost_DTE": 3.779,       "Encontrado": true,       "DescripcionDte": "DOLO-VITASIL 2 ML X 1 AMPOLLA"     },     {       "NumItem": 12,       "No_": "PED00156081",       "Description": "VITASIL INYECTABLE 25,000 (NEUROTROPAS+COMPLEJO B)",       "Quantity": 36.00000000000000000000,       "Unit_Cost": 4.09100000000000000000,       "Quantity_DTE": 36.0,       "Unit_Cost_DTE": 4.0936,       "Encontrado": true,       "DescripcionDte": "VITASIL INY. 25000 X 2 ML"     },     {       "Umbral": "Productos encontrados con umbral >= 40"     },     {       "Umbral": "Productos encontrados con umbral >= 30"     }   ] }');
    end;

    procedure IAApiConsultingPurchOrder(NoPurchOrden: Code[20]; CodGeneracion: Code[50]; CodProveedor: Code[20]): JsonObject
    var
        requestHeader, contentHeader : HttpHeaders;
        request: HttpRequestMessage;
        body: HttpContent;
        json: JsonObject;
        content, token : Text;
        uri: Text;
        response: JsonObject;
        isEnabled: Boolean;
        fsnParam: Record "FSN Parameter";
        Text000: Label 'Pendiente Configuración Parametro API Consulta DTE-> Grupo:CONFCOM Codigo:DTE_PURCH_API';
    begin
        fsnParam.Reset();
        if fsnParam.Get('CONFCOM', 'DTE_PURCH_API') then
            uri := fsnParam."Web Uri"
        else
            Error(Text000);
        json := PurchRequestJson(NoPurchOrden, CodGeneracion, CodProveedor);
        json.WriteTo(content);
        body.WriteFrom(content);
        Body.GetHeaders(contentHeader);
        contentHeader.Clear();
        contentHeader.Add('Content-Type', 'application/json');
        request.GetHeaders(requestHeader);
        requestHeader.Clear();
        request.Content := body;
        //token := getCredentials();
        //requestheader.Add('Authorization', 'Bearer ' + token);
        response := Post(uri, request);
        SaveJson(NoPurchOrden, 'request', content);
        response.WriteTo(content);
        SaveJson(NoPurchOrden, 'response', content);
        exit(response);
    end;


    procedure Post(Uri: Text; request: HttpRequestMessage): JsonObject;
    var
        client: HttpClient;
        contentHeader: HttpHeaders;
        response: HttpResponseMessage;
        content: HttpContent;
        status: Integer;
        res: Text;
        jResponse: JsonObject;
        json: JsonObject;
    begin
        request.Method := 'POST';
        request.SetRequestUri(uri);
        client.Send(request, response);
        content := response.Content;
        status := response.HttpStatusCode;

        if status = 200 then begin
            content.ReadAs(res);
            jResponse.ReadFrom(res);
            json.Add('status', status);
            json.Add('body', jResponse);
        end else
            json.Add('status', status);
        exit(json);
    end;


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC Picking/Receiving Confirm", 'OnBeforeModifyCountingLines', '', true, true)]
    local procedure "LSC Picking/Receiving Confirm_OnBeforeModifyCountingLines"
    (
        var CountingLines: Record "LSC Picking / Receiving lines";
        PickingReceivingLine_L: Record "LSC Picking / Receiving lines"
    )
    begin
        CountingLines."FSN Escaneo Pendiente" := PickingReceivingLine_L."FSN Escaneo Pendiente";
        CountingLines."FSN Revisar Costo" := PickingReceivingLine_L."FSN Revisar Costo";
        CountingLines."FSN Orden Facturado" := PickingReceivingLine_L."FSN Orden Facturado";
        CountingLines."FSN Cantidad DTE" := PickingReceivingLine_L."FSN Cantidad DTE";
        CountingLines."Expiration Date" := PickingReceivingLine_L."Expiration Date";
    end;
    //JH-PURCH DTE REQUEST


    [EventSubscriber(ObjectType::Table, Database::"Purchase Line", 'OnAfterUpdateVATOnLines', '', true, true)]
    local procedure "Purchase Line_OnAfterUpdateVATOnLines"
    (
        var PurchHeader: Record "Purchase Header";
        var PurchLine: Record "Purchase Line";
        var VATAmountLine: Record "VAT Amount Line";
        QtyType: Option
    )
    var
        purchRecept: Record "Purch. Rcpt. Header";
    begin
        purchRecept.Reset();
        purchRecept.SetRange("Order No.", PurchHeader."No.");
        purchRecept.SetRange("Buy-from Vendor No.", PurchHeader."Buy-from Vendor No.");
        purchRecept.SetRange("No.", PurchHeader."Last Receiving No.");
        if purchRecept.FindFirst() then begin
            purchRecept."FSN VAT Difference" := VATAmountLine."VAT Difference";
            purchRecept.Modify(true);
            Commit();
        end;
    end;

    procedure ValReceipt(DocumentNo: Code[20])
    var
        PHeader: Record "LSC P/R Counting Header";
        PRLines: Record "LSC Picking / Receiving lines";
        purchaseLine: Record "Purchase Line";
        paramFSN: Record "FSN Parameter";
        paramAmount: Decimal;
        IVAPurchLine: Decimal;
        Purch: Record "Purchase Header";
        Text001: Label 'Confirmar %1 no puede ser valor cero';
        Text002: Label 'Limite para el calculo manual de %1 es (más o menos) %2';
        Text003: Label 'Pendiente Configuración Parametro de Diferencia Compras-> Grupo:CONFCOM Codigo:CONFDIFCOM';
        Text004: Label 'El campo %1 no puede ser cero o estar vacio';
        Text005: Label 'Confirmar IVA excede del 13% aplicado al Confirmar Subtotal';
        Text006: Label 'El monto Subtotal y Confirmar Subtotal manualmente deben ser exactos';
        Text007: Label 'El Pedido %1 tiene activo el campo Nota Credito Asociada';
        Text008: Label 'No se puede registrar la recepción del pedido con DTE de Mascara';
        Text009: Label 'No se puede registar la recepción del pedido con Lineas Pendiente de Escaneo';
        Text010: Label 'Error al obtener el No. de Documento %1 probablemente fue eliminado o no existe';
        Text011: Label 'Recepción %1 no se puede registrar, Prod. %2 con estado %3';
        Text012: Label 'No se puede registrar la recepción Campo DTE vacio';
        Text013: Label '%1 is required for item %2 %3.';
        Text015: Label 'El monto Total y Confirmar Total manualmente deben ser exactos';
        Text014: Label 'No se pueden recibir más unidades de las solicitadas, recibidas o autorizadas, Prod. %1, Cantidad Autorizadas %2';
        FSNAuthorized: Boolean;
        PurchRcptHdr: Record "Purch. Rcpt. Header";
        PurchHdr: Record "Purchase Header";
        PHeaderByOrdenNo: Record "LSC P/R Counting Header";
        ItemQuantityDict: Dictionary of [Code[20], Decimal];
        QuantityI: Decimal;
        Item: Code[20];
    begin


        //Actualizar los totales 
        CalcTototalReceComMin(DocumentNo);

        if not PHeader.Get(DocumentNo) then
            Error(Text010, DocumentNo);
        //PurchaseV47-JH01
        //Validar campos
        if PHeader."FSN Automatic Search" then begin
            if PHeader."DTE Invoice" = 'DTE-03-00000000-000000000000000' then
                Error(Text008);
            if PHeader."DTE Invoice" = '' then
                Error(Text012);
        end;

        if PHeader."DTE Invoice" <> '' then begin
            if PHeader."DTE AuthNumber" = '' then
                Error('El campo Codigo Generacion no puede estar vacio.');
            PurchHdr.Reset();
            PurchHdr.SetRange("No.", PHeader."Reference No.");
            if PurchHdr.FindFirst() then begin
                PurchHdr."DTE Invoice" := PHeader."DTE Invoice";
                PurchHdr."DTE AuthNumber" := PHeader."DTE AuthNumber";
                invFSNUtilityDTESearch(PurchHdr, 'SELE-DTE-HISRCPT');
            end;

        end;

        if PHeader."Vendor Invoice No." = '' then
            Error(Text004, 'No. Factura Proveedor');

        if PHeader."Counted Date" = 0D then
            Error(Text004, 'Fecha Contado');

        if PHeader.ConfirmarSubTotal = 0.0 then
            Error(Text004, 'Confirmar Subtotal');

        if (PHeader.Tax <> 0.0) and (PHeader.ConfirmarTax = 0.0) then
            Error(Text004, 'Confirmar IVA');

        if PHeader.ConfirmarTotal = 0.0 then
            Error(Text004, 'Confirmar Total');



        PRLines.Reset();
        PRLines.SetRange("Document No.", PHeader."No.");
        PRLines.SetRange("FSN Escaneo Pendiente", true);
        if PRLines.FindFirst() then
            Error(Text009);

        PRLines.Reset();
        PRLines.SetRange("Document No.", PHeader."No.");
        PRLines.SetFilter(Quantity, '<>%1', 0);
        PRLines.SetFilter("Posting Action", '<>%1', PRLines."Posting Action"::" ");
        if PRLines.FindFirst() then
            Error(Text011, PHeader."No.", PRLines."Item No.", PRLines."Posting Action");

        //PurchVr55 -Ingresar No. Nota Credito x Desc
        if PHeader."No. Credit Memo Associated" = '' then begin

            if PHeader.Receiving::"Purchase Order" = PHeader.Receiving then begin
                Purch.Reset();
                Purch.SetRange("No.", PHeader."Reference No.");
                Purch.SetRange("Associated Credit Memo", true);
                if Purch.FindFirst() then begin
                    Message(Text007, PHeader."Reference No.");
                    Error(Text004, 'No. Nota Credito');
                end;
            end;
        end;
        //PurchVr55


        //JN-NO BORRAR -
        if (PHeader."FSN Reason Option" = PHeader."FSN Reason Option"::Otros) or (PHeader."FSN Reason Option" = PHeader."FSN Reason Option"::Courier) then
            Error(Text004, 'Descripción de Rechazo');
        //JN-NO BORRAR +
        //PurchaseV47-JH01

        paramFSN.Reset();
        if paramFSN.Get('CONFCOM', 'CONFDIFCOM') then begin
            if paramFSN.Activo then
                Evaluate(paramAmount, Format(paramFSN.Valor));
        end else
            Error(Text003);

        if PHeader.Tax = 0.0 then begin
            if PHeader.ConfirmarTax <> PHeader.Tax then
                Error(Text002, 'IVA', Format(0));

            if PHeader.SubTotal <> PHeader.ConfirmarSubTotal then
                Error(Text006);

            if PHeader.Total <> PHeader.ConfirmarTotal then
                Error(Text015);
        end else begin
            if (Round(PHeader.SubTotal, 0.01, '=')) <> (Round(PHeader.ConfirmarSubTotal, 0.01, '=')) then
                Error(Text006);

            if PHeader.ConfirmarTax > PHeader.Tax then begin
                if (Round(PHeader.ConfirmarTax, 0.01, '=') - Round(PHeader.Tax, 0.01, '=')) > paramAmount then begin
                    Error(Text002, 'IVA', Format(paramFSN.Valor));
                end;
            end else begin
                if (Round(PHeader.Tax, 0.01, '=') - Round(PHeader.ConfirmarTax, 0.01, '=')) > paramAmount then begin
                    Error(Text002, 'IVA', Format(paramFSN.Valor));
                end;
            end;

            if PHeader.ConfirmarTotal > PHeader.Total then begin
                if (Round(PHeader.ConfirmarTotal, 0.01, '=') - Round(PHeader.Total, 0.01, '=')) > paramAmount then begin
                    Error(Text002, 'Total', Format(paramFSN.Valor));
                end;
            end else begin
                if (Round(PHeader.Total, 0.01, '=') - Round(PHeader.ConfirmarTotal, 0.01, '=')) > paramAmount then begin
                    Error(Text002, 'Total', Format(paramFSN.Valor));
                end;
            end;
        end;

        PRLines.Reset();
        PRLines.SetRange("Document No.", PHeader."No.");
        PRLines.SetFilter("Lot No.", '<>%1', '');
        PRLines.SetFilter("Expiration Date", '%1', 0D);
        if PRLines.FindFirst() then
            Error(Text013, PRLines.FieldCaption("Expiration Date"), PRLines."Item No.", PRLines.Description);

        //US-588 Validar al autorizar que las cantiades no sobrepasen las solicitadas
        PHeaderByOrdenNo.Reset();
        PHeaderByOrdenNo.SetFilter("No.", '<>%1', PHeader."No.");
        PHeaderByOrdenNo.SetRange("Reference No.", PHeader."Reference No.");
        PHeaderByOrdenNo.SetRange("FSN Authorized Reception", true);
        if PHeaderByOrdenNo.FindFirst then begin
            repeat begin
                PRLines.Reset();
                PRLines.SetRange("Document No.", PHeaderByOrdenNo."No.");
                PRLines.SetFilter("Quantity", '<>%1', 0);
                if PRLines.FindFirst() then begin
                    repeat begin
                        if ItemQuantityDict.ContainsKey(PRLines."Item No.") then begin
                            ItemQuantityDict.Get(PRLines."Item No.", QuantityI); // Obtener el valor actual
                            ItemQuantityDict.Set(PRLines."Item No.", PRLines.Quantity + QuantityI); // Actualizar el valor
                        end else
                            ItemQuantityDict.Add(PRLines."Item No.", PRLines.Quantity); // Si no existe, agregarlo al diccionario
                    end until PRLines.Next() = 0;
                end;
            end until PHeaderByOrdenNo.Next() = 0;
            PRLines.Reset();
            PRLines.SetRange("Document No.", PHeader."No.");
            PRLines.SetFilter("Quantity", '<>%1', 0);
            if PRLines.FindFirst() then begin
                repeat begin
                    if ItemQuantityDict.ContainsKey(PRLines."Item No.") then begin
                        ItemQuantityDict.Get(PRLines."Item No.", QuantityI);
                        if (PRLines.Quantity + QuantityI) > PRLines."Ordered Qty." then
                            Error(Text014, PRLines."Item No.", QuantityI);
                    end;
                end until PRLines.Next() = 0;
            end;
        end;
        PRLines.Reset();
        PRLines.SetRange("Document No.", PHeader."No.");
        PRLines.SetFilter("Quantity", '<>%1', 0);
        if PRLines.FindFirst() then begin
            repeat begin
                if PRLines.Quantity > PRLines."Ordered Qty." then
                    Error(Text014, PRLines."Item No.", PRLines.Quantity);
            end until PRLines.Next() = 0;
        end;
        //US-588
    end;

    //Se comenta por que se encuentra error al enviar a cola, se actualiza la cantidad y el costo cuando ya esta preparado el pedido
    //US-530 *****
    /*
    [EventSubscriber(ObjectType::Table, Database::"Job Queue Entry", 'OnBeforeInsertEvent', '', true, true)]
    local procedure "Job Queue Entry_OnBeforeInsertEvent"
    (
        var Rec: Record "Job Queue Entry";
        RunTrigger: Boolean
    )
    var
        POSSESSION: Codeunit "LSC POS Session";
    begin

        IF POSSESSION.GetValue('MOVINVOICENO') <> '' THEN begin
            Rec."FSN Vendor Invoice No" := POSSESSION.GetValue('MOVINVOICENO');
            POSSESSION.SetValue('MOVINVOICENO', '');
        end;

        IF POSSESSION.GetValue('MOVORDERHRC') <> '' THEN begin
            Rec."FSN HRC No" := POSSESSION.GetValue('MOVORDERHRC');
            POSSESSION.SetValue('MOVORDERHRC', '');
        end;

        IF POSSESSION.GetValue('MOVORDER') <> '' THEN begin
            Rec."FSN Order No" := POSSESSION.GetValue('MOVORDER');
            POSSESSION.SetValue('MOVORDER', '');
        end;
    end;

        [EventSubscriber(ObjectType::Page, Page::"Purchase Order", 'OnClosePageEvent', '', true, true)]
        local procedure "Purchase Order_OnClosePageEvent"(var Rec: Record "Purchase Header")
        var
            POSSESSION: Codeunit "LSC POS Session";
        begin
            POSSESSION.SetValue('MOVINVOICENO', '');
            POSSESSION.SetValue('MOVORDERHRC', '');
            POSSESSION.SetValue('MOVORDER', '');
        end;


        [EventSubscriber(ObjectType::Codeunit, Codeunit::"Purch.-Post", 'OnBeforePostPurchaseDoc', '', true, true)]
        local procedure "Purch.-Post_OnBeforePostPurchaseDoc"
        (
            var PurchaseHeader: Record "Purchase Header";
            PreviewMode: Boolean;
            CommitIsSupressed: Boolean;
            var HideProgressWindow: Boolean;
            var ItemJnlPostLine: Codeunit "Item Jnl.-Post Line"
        )
        var
            PurchRcptHeader: Record "Purch. Rcpt. Header";
            JobQueueEntry: Record "Job Queue Entry";
            pag: page "Job Queue Entries";
        begin
            IF NOT (POSSESSION.GetValue('IDQUEUEENTRY') IN [' ', '']) THEN BEGIN
                Evaluate(IDQ, POSSESSION.GetValue('IDQUEUEENTRY'));
                JobQueueEntry.Reset();
                JobQueueEntry.SetRange(ID, IDQ);
                JobQueueEntry.SetRange(JobQueueEntry."FSN Order No", PurchaseHeader."No.");
                if JobQueueEntry.FindFirst() then begin
                    if PurchRcptHeader.Get(JobQueueEntry."FSN HRC No") then
                        ProcessQueueEntryOrder(PurchRcptHeader, PurchaseHeader);
                end;
            END;
        end;
        //US-530 *****
        */

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Job Queue Dispatcher", 'OnBeforeHandleRequest', '', true, true)]
    local procedure "Job Queue Dispatcher_OnBeforeHandleRequest"(var JobQueueEntry: Record "Job Queue Entry")
    var
        PurchRcptHeader: Record "Purch. Rcpt. Header";
        PurchaseHeader: Record "Purchase Header";
    begin
        PurchaseHeader.Reset();
        PurchRcptHeader.Reset();
        if JobQueueEntry."Job Queue Category Code" = 'CONT_COMP' then begin
            if PurchaseHeader.Get(PurchaseHeader."Document Type"::Order, JobQueueEntry."FSN Order No") then
                if PurchRcptHeader.Get(JobQueueEntry."FSN HRC No") then
                    ProcessQueueEntryPurchOrder(PurchRcptHeader, PurchaseHeader, JobQueueEntry);
        end;
    end;


    procedure ProcessQueueEntryPurchOrder(PurchRcptHeader: Record "Purch. Rcpt. Header"; var PurchaseHeader: Record "Purchase Header"; JobQueueEntry: Record "Job Queue Entry")
    var
        PurchaseLine: Record "Purchase Line";
        PurchRcptLine: Record "Purch. Rcpt. Line";
        invoiceList: List of [Text];
        invoice: Text;
        Ret: Record "Purch. Withh. Contribution";
        WithhSocSecTax: Codeunit "Withholding - Contribution";
        "DTE AuthNumber": Code[100];
        "DTE Invoice": Code[100];
        "Signature Validation": Code[100];
        FSNRecepPurchDTE: Record "FSN Recep. Purch. DTE";
    begin
        PurchaseHeader.Status := PurchaseHeader.Status::Open;
        PurchaseHeader."Posting Date" := PurchRcptHeader."Posting Date";
        PurchaseHeader.Modify(true);
        PurchaseLine.Reset();
        PurchaseLine.SetRange("Document Type", PurchaseHeader."Document Type");
        PurchaseLine.SetRange("Document No.", PurchaseHeader."No.");
        if PurchaseLine.FindFirst() then begin
            repeat begin
                PurchaseLine.Validate(PurchaseLine."Qty. to Invoice", 0);
                PurchaseLine.Modify();
            end until PurchaseLine.Next() = 0;
        end;
        if PurchaseHeader.Get(PurchaseHeader."Document Type"::Order, PurchRcptHeader."Order No.") then;
        PurchRcptLine.Reset();
        PurchRcptLine.SetRange("Document No.", PurchRcptHeader."No.");
        PurchRcptLine.SetFilter(Quantity, '<>%1', 0);
        if PurchRcptLine.find('-') then
            repeat
                if PurchaseLine.Get(PurchaseHeader."Document Type", PurchaseHeader."No.", PurchRcptLine."Line No.") then begin
                    PurchaseLine.Validate("Qty. to Invoice", PurchRcptLine.Quantity);
                    PurchaseLine.Modify(true);
                end;
            until PurchRcptLine.next = 0;
        invFSNUtilityDTE(PurchRcptHeader."No.", "DTE AuthNumber", "DTE Invoice", "Signature Validation");
        invoice := PurchRcptHeader."FSN Vendor Invoice No.";
        if invoice.Contains('-') then begin
            invoiceList := invoice.Split('-');
            if invoice.Contains('DTE') then begin
                if "DTE Invoice" <> '' then begin
                    invoice := "DTE Invoice";
                    invoiceList := invoice.Split('-');
                    PurchaseHeader.Validate("Vendor Invoice Number", DelChr((invoiceList.Get(invoiceList.Count)), '<', '0'));
                    PurchaseHeader.Validate("Vendor Invoice Serie", invoiceList.Get(1) + DelChr(invoiceList.Get(2), '=', '0'));
                    PurchaseHeader."DTE Invoice" := "DTE Invoice";
                    PurchaseHeader."DTE AuthNumber" := "DTE AuthNumber";
                    PurchaseHeader."Signature Validation" := "Signature Validation";
                    //US606-JH Ingresar la fecha de emisión del DTE
                    if "DTE AuthNumber" <> '' then begin
                        FSNRecepPurchDTE.Reset();
                        FSNRecepPurchDTE.SetFilter("DTE AuthNumber", '%1', "DTE AuthNumber");
                        if FSNRecepPurchDTE.FindFirst() then
                            PurchaseHeader."Document Date" := DT2Date(FSNRecepPurchDTE."Issue Date");
                    end;
                end else begin
                    PurchaseHeader.Validate("Vendor Invoice Serie", invoiceList.Get(1));
                    PurchaseHeader.Validate("Vendor Invoice Number", DelChr((invoiceList.Get(invoiceList.Count)), '<', '0'));
                end;
            end else begin
                PurchaseHeader.Validate("Vendor Invoice Number", DelChr((invoiceList.Get(invoiceList.Count)), '<', '0'));
                PurchaseHeader.Validate("Vendor Invoice Serie", invoiceList.Get(1));
            end;
            PurchaseHeader."Vendor Invoice No." := PurchaseHeader."Vendor Invoice Serie" + '-' + PurchaseHeader."Vendor Invoice Number";
            PurchaseHeader."Unique Document No." := PurchaseHeader."Vendor Invoice No.";
        end else
            PurchaseHeader."Vendor Invoice No." := PurchRcptHeader."FSN Vendor Invoice No.";
        PurchaseHeader."Last Receiving No." := PurchRcptHeader."No.";
        PurchaseHeader."FSN VAT Difference" := PurchRcptHeader."FSN VAT Difference";
        PurchaseHeader."Job Queue Entry ID" := JobQueueEntry.ID;
        WithhSocSecTax.CalculateWithholdingTax(PurchaseHeader, FALSE);
        if Ret.Get(Ret."Document Type"::Order, PurchaseHeader."No.") then
            PurchaseHeader."FSN Withholding Tax Amount" := Ret."Withholding Tax Amount Others";
        PurchaseHeader.Status := PurchaseHeader.Status::Released;
        PurchaseHeader.Modify(true);

    end;


    /*
        procedure ProcessQueueEntryOrder(Rec: Record "Purch. Rcpt. Header"; var PurchaseHeader: Record "Purchase Header")
        var
            PurchaseLine: Record "Purchase Line";
            PurchRcptLine: Record "Purch. Rcpt. Line";
            invoiceList: List of [Text];
            invoice: Text;
            util: Codeunit "FSN External Purch. Manager";
            PO: Page "Purchase Order";
            guion: Integer;
            POSSESSION: Codeunit "LSC POS Session";
            "DTE AuthNumber", "DTE Invoice", "Signature Validation" : Code[100];
            WithhSocSecTax: Codeunit "Withholding - Contribution";
            Ret: Record "Purch. Withh. Contribution";
        begin

            Clear(PurchaseHeader);

                    if PurchaseHeader.Get(PurchaseHeader."Document Type"::Order, Rec."Order No.") then begin
                        PurchaseHeader.Status := PurchaseHeader.Status::Open;
                        PurchaseHeader.Modify(true);
                        PurchaseLine.Reset();
                        PurchaseLine.SetRange("Document Type", PurchaseHeader."Document Type");
                        PurchaseLine.SetRange("Document No.", PurchaseHeader."No.");
                        if PurchaseLine.FindFirst() then begin
                            repeat begin
                                PurchaseLine.Validate(PurchaseLine."Qty. to Invoice", 0);
                                PurchaseLine.Modify();
                            end until PurchaseLine.Next() = 0;
                        end;
                        PurchRcptLine.Reset();
                        PurchRcptLine.SetRange("Document No.", Rec."No.");
                        PurchRcptLine.SetFilter(Quantity, '<>%1', 0);
                        if PurchRcptLine.find('-') then
                            repeat
                                if PurchaseLine.Get(PurchaseHeader."Document Type", PurchaseHeader."No.", PurchRcptLine."Line No.") then begin
                                    PurchaseLine.Validate("Qty. to Invoice", PurchRcptLine.Quantity);
                                    //PurchaseLine.Validate("Direct Unit Cost", PurchRcptLine."Direct Unit Cost");
                                    PurchaseLine.Modify(true);
                                end;
                            until PurchRcptLine.next = 0;
                        PurchaseHeader.Status := PurchaseHeader.Status::Released;
                        PurchaseHeader.Modify(true);
                    end;

            PurchaseHeader.Reset();
            PurchaseHeader.SetRange("Document Type", PurchaseHeader."Document Type"::Order);
            PurchaseHeader.SetRange("No.", Rec."Order No.");
            if PurchaseHeader.FindFirst() then begin
                invoice := rec."FSN Vendor Invoice No.";
                if invoice.Contains('-') then begin
                    invoiceList := invoice.Split('-');
                    if invoice.Contains('DTE') then begin
                        if "DTE Invoice" <> '' then begin
                            invoice := "DTE Invoice";
                            invoiceList := invoice.Split('-');
                            PurchaseHeader.Validate("Vendor Invoice Number", DelChr(invoiceList.Get(invoiceList.Count), '<', '0'));
                            PurchaseHeader.Validate("Vendor Invoice Serie", invoiceList.Get(1) + invoiceList.Get(2));
                            PurchaseHeader."DTE Invoice" := "DTE Invoice";
                            PurchaseHeader."DTE AuthNumber" := "DTE AuthNumber";
                            PurchaseHeader."Signature Validation" := "Signature Validation";
                        end else begin
                            PurchaseHeader.Validate("Vendor Invoice Number", DelChr(invoiceList.Get(invoiceList.Count), '<', '0'));
                            PurchaseHeader.Validate("Vendor Invoice Serie", invoiceList.Get(1));
                        end;
                    end else begin
                        PurchaseHeader.Validate("Vendor Invoice Number", DelChr(invoiceList.Get(invoiceList.Count), '<', '0'));
                        PurchaseHeader.Validate("Vendor Invoice Serie", invoiceList.Get(1));
                    end;
                    PurchaseHeader."Vendor Invoice No." := rec."FSN Vendor Invoice No.";
                    PurchaseHeader."Unique Document No." := rec."FSN Vendor Invoice No.";
                end else
                    PurchaseHeader."Vendor Invoice No." := Rec."FSN Vendor Invoice No.";
                PurchaseHeader."Sub Type" := PurchaseHeader."Sub Type";
                PurchaseHeader."Last Receiving No." := Rec."No.";
                PurchaseHeader."FSN VAT Difference" := Rec."FSN VAT Difference";
                WithhSocSecTax.CalculateWithholdingTax(PurchaseHeader, FALSE);
                if Ret.Get(Ret."Document Type"::Order, PurchaseHeader."No.") then
                    PurchaseHeader."FSN Withholding Tax Amount" := Ret."Withholding Tax Amount Others";
                PurchaseHeader.Modify(true);
            end;
        end;
        */

    local procedure invFSNUtilityDTE("iNo": Code[20]; var "DTE AuthNumber": Code[100]; var "DTE Invoice": Code[100]; var "Signature Validation": Code[100])
    var
        FSNUtility: Codeunit "FSN Utility";
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        MsgResult: Text;
        POSMenuLineTemp: Record "LSC POS Menu Line" temporary;
        Processed: Boolean;
    begin
        RequestID := 'DTE-LIBROIVA';
        XMLRequest := iNo;
        FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
        "DTE AuthNumber" := PosMenuLineTemp."Current-Description";
        "DTE Invoice" := PosMenuLineTemp."Set Current-Input";
        "Signature Validation" := PosMenuLineTemp."Current-Description2";

    end;
    //US-530 *****
    /* 
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Job Queue Dispatcher", 'OnBeforeHandleRequest', '', true, true)]
    local procedure "Job Queue Dispatcher_OnBeforeHandleRequest"(var JobQueueEntry: Record "Job Queue Entry")
    var
        POSSESSION: Codeunit "LSC POS Session";
    begin
        POSSESSION.SetValue('IDQUEUEENTRY', JobQueueEntry.ID);
    end;
    */
    //US-530 *****
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Job Queue Dispatcher", 'OnAfterHandleRequest', '', true, true)]
    local procedure "Job Queue Dispatcher_OnAfterHandleRequest"
    (
        var JobQueueEntry: Record "Job Queue Entry";
        WasSuccess: Boolean;
        JobQueueExecutionTime: Integer
    )
    var
        POSSESSION: Codeunit "LSC POS Session";
        PurchRcptHeader: Record "Purch. Rcpt. Header";
        JobQueueLogEntry: Record "Job Queue Log Entry";
        IDQ: Guid;
    begin
        JobQueueLogEntry.Reset();
        JobQueueLogEntry.SetRange(ID, JobQueueEntry.ID);
        IF JobQueueLogEntry.FindLast() then
            if PurchRcptHeader.Get(JobQueueEntry."FSN HRC No") then begin
                PurchRcptHeader."FSN last message" := JobQueueLogEntry."Error Message";
                if (StrPos(JobQueueLogEntry."Error Message", 'Se bloqueó un registro de la tabla') > 0) OR
                    (StrPos(JobQueueLogEntry."Error Message", 'La actividad fue bloqueada por otro usuario') > 0) then
                    PurchRcptHeader."FSN last message" := 'Reprocesando Mov. ' + JobQueueLogEntry."Error Message";
                if JobQueueLogEntry.Status::Error = JobQueueLogEntry.Status then
                    PurchRcptHeader."FSN last message" := 'Error ' + JobQueueLogEntry."Error Message";
                PurchRcptHeader.Modify();
            end;
        //POSSESSION.SetValue('IDQUEUEENTRY', '');
    end;

    [EventSubscriber(ObjectType::Page, Page::"Purchase Order", 'OnModifyRecordEvent', '', true, true)]
    local procedure "Purchase Order_OnModifyRecordEvent"
  (
      var Rec: Record "Purchase Header";
      var xRec: Record "Purchase Header";
      var AllowModify: Boolean
  )
    var
        POSSESSION: Codeunit "LSC POS Session";
        PurchRcptHeader: Record "Purch. Rcpt. Header";
    begin
        //US-515****
        /*
        IF POSSESSION.GetValue('MOVINVOICENO') <> '' THEN
            if POSSESSION.GetValue('MOVINVOICENO') <> Rec."Vendor Invoice No." then
                if PurchRcptHeader.Get(POSSESSION.GetValue('MOVORDERHRC')) then begin
                    POSSESSION.SetValue('MOVINVOICENO', Rec."Vendor Invoice No.");
                    PurchRcptHeader."FSN Vendor Invoice No." := Rec."Vendor Invoice No.";
                    PurchRcptHeader.Modify();
                end;
        */
        //US-515****
        if PurchRcptHeader.Get(Rec."Last Receiving No.") then begin
            PurchRcptHeader."FSN Vendor Invoice No." := Rec."Vendor Invoice No.";
            PurchRcptHeader.Modify();
        end;

        if (Rec."Document Type"::Order = Rec."Document Type") or (Rec."Document Type"::Invoice = Rec."Document Type") then
            invFSNUtilityDTE(Rec."Last Receiving No.", Rec."DTE AuthNumber", Rec."DTE Invoice", Rec."Signature Validation", Rec."No. Credit Memo Associated", 'PURCHINV', Rec."FSN Withholding Tax Amount");
        if (Rec."Document Type"::"Credit Memo" = Rec."Document Type") or (Rec."Document Type"::"Return Order" = Rec."Document Type") then
            invFSNUtilityDTE(Rec."Last Receiving No.", Rec."DTE AuthNumber", Rec."DTE Invoice", Rec."Signature Validation", Rec."No. Credit Memo Associated", 'PURCHMEM', Rec."FSN Withholding Tax Amount");
        Rec."Unique Document No." := Rec."Vendor Invoice No.";
        Rec.Modify();
    end;

    procedure SaveJson(NoPurchOrden: Code[20]; outfile: Code[20]; json: text)
    var
        FileMgt: Codeunit "File Management";
        FilterString: Text;
        FileSystem: DotNet StreamWriter;
        SRFTXN: Text;
        fsnParam: Record "FSN Parameter";
        Text001: Label 'Pendiente Configuración Parametro Consulta Automatica DTE-> Grupo:CONFCOM Codigo:PURCJSONDTE';
    begin
        fsnParam.Reset();
        if fsnParam.Get('CONFCOM', 'PURCJSONDTE') then begin
            if fsnParam.Activo then begin
                FilterString := 'C:\temp\DTEPurch\' + NoPurchOrden + '-' + outfile + '.json';
                IF not FileMgt.ClientDirectoryExists('C:\temp\DTEPurch') THEN BEGIN
                    FileSystem := FileSystem.StreamWriter(FilterString);
                    FileSystem.Write(json);
                    FileSystem.Close();
                END;
            end;
        end else
            Error(Text001);
    end;

    [EventSubscriber(ObjectType::Page, Page::"LSC Retail Receiving List", 'OnDeleteRecordEvent', '', true, true)]
    local procedure "LSC Retail Receiving List_OnDeleteRecordEvent"
    (
        var Rec: Record "LSC P/R Counting Header";
        var AllowDelete: Boolean
    )
    var
        fsnParam: Record "FSN Parameter";
        parameterList: List of [Text];
        parameterValue: Text;
        Text001: Label 'La recepción %1 autorizada o con salida aplicada ya no puede eliminarse';

    begin
        AllowDelete := false;
        if (Rec."FSN Authorized Reception") OR (Rec."FSN Status" = Rec."FSN Status"::AplicandoAutomatico) then begin
            fsnParam.Reset();
            if fsnParam.Get('CONFCOM', 'CONFDELCOM') then begin
                if fsnParam.Activo then begin
                    if (fsnParam."Value Text 1" = UserId()) and (fsnParam."Value Text 1" <> '') then
                        AllowDelete := true
                    else begin
                        parameterList := fsnParam.Valor.Split('|');
                        foreach parameterValue in parameterList do begin
                            if Rec."No." = parameterValue then begin
                                AllowDelete := true;
                            end;
                        end;
                    end;
                end else
                    AllowDelete := false;
            end;
        end else
            AllowDelete := true;

        if not AllowDelete then
            Message(Text001, Rec."No.");
    end;

    //PurchaseV67
    procedure SendExtPurchLineLotes(RecePurch: Record "LSC P/R Counting Header")
    var
        lText001: Label 'External Lines already exists';
        lText002: Label 'Sincronized lines sussesfull...';
        lText003: Label 'Vendor %1 is not allowed for purchase external lines';
        lText004: Label 'Vendor and Status Released is required for this action';
        lText005: Label 'Location %1 is not allowed use puchase external lines';
        lText006: Label 'Consolidate cant be empty';
        lText007: Label 'Purchase Order not found';
        Ok_: Boolean;
        Store_l: Record "LSC Store";
        FasaniPurchSetup_l: Record "FSN Fasani Setup";
        ExternalLines_l: Record "FSN External Purch. Line";
        PurchExternalManager: Codeunit "FSN Batch - Send Purchase Data";
        Purch: Record "Purchase Header";
    begin
        Purch.Reset();
        if not Purch.get(Purch."Document Type"::Order, RecePurch."Reference No.") then
            Error(lText007);
        Ok_ := FALSE;
        IF (Purch."Buy-from Vendor No." = '') OR (Purch.Status <> Purch.Status::Released) THEN
            ERROR(lText004);

        IF Purch."FSN Consolidate No." = '' THEN
            ERROR(lText006);

        ExternalLines_l.RESET;
        ExternalLines_l.SETCURRENTKEY("No.", "Line No.");
        ExternalLines_l.SETRANGE(ExternalLines_l."No.", Purch."No.");
        IF ExternalLines_l.FINDFIRST THEN BEGIN
            MESSAGE(lText001);
            EXIT;
        END;

        IF Purch."LSC Store No." <> '' THEN
            Ok_ := FasaniPurchSetup_l.GET(Purch."LSC Store No.")
        ELSE BEGIN
            Store_l.RESET;
            Store_l.SETCURRENTKEY("Location Code");
            IF Store_l.FINDFIRST THEN
                Ok_ := FasaniPurchSetup_l.GET(Store_l."No.");
        END;
        IF Ok_ THEN BEGIN
            IF FasaniPurchSetup_l."Use External Purch. Line" THEN BEGIN
                PurchExternalManager.SendCreateExternalLinesLotes(Purch);
                MESSAGE(lText002);
                EXIT;
            END ELSE
                Ok_ := FALSE;
        END;
        IF NOT Ok_ THEN
            MESSAGE(STRSUBSTNO(lText005, Purch."Ship-to Name"));
    end;


    [EventSubscriber(ObjectType::Table, Database::"Purchase Header", 'OnBeforeInsertEvent', '', true, true)]
    local procedure "Purchase Header_OnBeforeInsertEvent"
    (
        var Rec: Record "Purchase Header";
        RunTrigger: Boolean
    )
    begin
        IF Rec."Document Type" = Rec."Document Type" THEN;
    end;


    [EventSubscriber(ObjectType::Table, Database::"Purchase Header", 'OnBeforeModifyEvent', '', true, true)]
    local procedure "Purchase Header_OnBeforeModifyEvent"
    (
        var Rec: Record "Purchase Header";
        var xRec: Record "Purchase Header";
        RunTrigger: Boolean
    )
    var
        Vendor: Record Vendor;
        JobQueueEntry: Record "Job Queue Entry";
        JobQueueEntryConfig: Record "Job Queue Entry";
        UserSecurity: Record User;
    begin
        IF Rec."Document Type" = Rec."Document Type"::Order THEN BEGIN
            IF Rec."Withhold Tax No." = '' THEN begin
                if Vendor.get(Rec."Buy-from Vendor No.") then
                    Rec."Withhold Tax No." := Vendor."Withholding Tax Code";
            end;
            //US-530****
            IF Rec."Job Queue Status"::"Scheduled for Posting" = Rec."Job Queue Status" then begin
                JobQueueEntry.Reset();
                JobQueueEntry.SetRange(ID, Rec."Job Queue Entry ID");
                JobQueueEntry.SetRange("Job Queue Category Code", 'CONT_COMP');
                JobQueueEntry.SetRange("Object ID to Run", 98);
                if JobQueueEntry.FindLast() then begin
                    JobQueueEntry."FSN HRC No" := Rec."Last Receiving No.";
                    JobQueueEntry."FSN Order No" := Rec."No.";
                    JobQueueEntryConfig.Reset();
                    JobQueueEntryConfig.SetFilter("Object ID to Run", '%1', 50015);
                    JobQueueEntryConfig.SetRange("Object Type to Run", JobQueueEntryConfig."Object Type to Run"::Report);
                    if JobQueueEntryConfig.FindFirst() then begin
                        JobQueueEntry."Maximum No. of Attempts to Run" := JobQueueEntryConfig."Maximum No. of Attempts to Run";
                        JobQueueEntry."Rerun Delay (sec.)" := JobQueueEntryConfig."Rerun Delay (sec.)";
                        JobQueueEntry."Run on Mondays" := JobQueueEntryConfig."Run on Mondays";
                        JobQueueEntry."Run on Tuesdays" := JobQueueEntryConfig."Run on Tuesdays";
                        JobQueueEntry."Run on Thursdays" := JobQueueEntryConfig."Run on Thursdays";
                        JobQueueEntry."Run on Wednesdays" := JobQueueEntryConfig."Run on Wednesdays";
                        JobQueueEntry."Run on Fridays" := JobQueueEntryConfig."Run on Fridays";
                        JobQueueEntry."Run on Saturdays" := JobQueueEntryConfig."Run on Saturdays";
                        JobQueueEntry."Run on Sundays" := JobQueueEntryConfig."Run on Sundays";
                        JobQueueEntry."Starting Time" := JobQueueEntryConfig."Starting Time";
                        JobQueueEntry."Ending Time" := JobQueueEntryConfig."Ending Time";
                        JobQueueEntry."Earliest Start Date/Time" := JobQueueEntryConfig."Earliest Start Date/Time";
                        JobQueueEntry."Expiration Date/Time" := JobQueueEntryConfig."Expiration Date/Time";
                        JobQueueEntry."No. of Minutes between Runs" := JobQueueEntryConfig."No. of Minutes between Runs";
                    end;
                    JobQueueEntry.Modify();
                end;
            end;
            //US-530****

        END;
    end;

    procedure CalcWithHold(var Purchase: Record "Purchase Header")
    var
        PurchaseLine: Record "Purchase Line";
        NewAmount: Decimal;
        NewPurchaseLine: Record "Purchase Line";
        NextLine: Integer;
        SpecialCalcJouranal: Record "Special Calc Journal";
        Montott: Decimal;
        SpecialCacl: Record "Special Calc Journal";
        SpecialC: Record "Special Calc Group";
        SpecialCalcSet: Record "Special Calc Setup";
        Vendor: Record Vendor;
        PurchaseHeader: Record "Purchase Header";
        LedgerVenRef: Record "Vendor Ledger Entry";
        WithHoldTax: Record "Computed Withholding Tax";
        WhtAmt: Decimal;
        pa: Page "Navigate";
    begin
        if not (Purchase."Document Type" in [Purchase."Document Type"::"Credit Memo", Purchase."Document Type"::"Return Order"]) then exit;

        Montott := 0;
        PurchaseLine.SETRANGE("Document Type", Purchase."Document Type");
        PurchaseLine.SETRANGE("Document No.", Purchase."No.");
        PurchaseLine.SETRANGE("Attached to Line No.", 0);
        if PurchaseLine.FINDFIRST then begin
            repeat
                //Get Conf. Cacl Spec3
                SpecialCalcSet.SetRange(Target, SpecialCalcSet.Target::Compras);
                SpecialCalcSet.SetRange(SubType, Purchase."Sub Type");
                SpecialCalcSet.SetRange("VAT Prod. Posting Group", PurchaseLine."VAT Prod. Posting Group");
                if SpecialCalcSet.FindFirst() then begin
                    if PurchaseHeader."Prices Including VAT" then begin
                        PurchaseLine."Direct Unit Cost" := ROUND(PurchaseLine."Direct Unit Cost" / (1 + PurchaseLine."VAT %" / 100), 1);
                        PurchaseLine."Line Discount Amount" := ROUND(PurchaseLine."Line Discount Amount" / (1 + PurchaseLine."VAT %" / 100), 1)
                    end;
                    Montott += ROUND(PurchaseLine.Quantity * PurchaseLine."Direct Unit Cost", 0.01) - PurchaseLine."Line Discount Amount";
                    Purchase."FSN Withholding Tax Amount" := ROUND(Montott * (SpecialCalcSet."Amount %" / 100), SpecialCalcSet."Calc Round");
                end;
            until PurchaseLine.NEXT = 0;
        end;
    end;

    procedure CalcTototalReceComMin(DocumentNo: Code[20])
    var
        PRHeader: Record "LSC P/R Counting Header";
        PRLines: Record "LSC Picking / Receiving lines";
        purchaseLine: Record "Purchase Line";
        subTotalBase, vatBase, TotalBase : Decimal;
        PRHeaderAutho: Record "LSC P/R Counting Header";
        PRLinesAutho: Record "LSC Picking / Receiving lines";
        IUM: Record "Item Unit of Measure";
        Text001: Label 'El producto %1 no tiene unidad de medida';
        job: Codeunit "Purchase Post via Job Queue";
        Currency: Record Currency;
        PurchHeader: Record "Purchase Header";
        DirectUnitCost: Decimal;
    begin
        if not PRHeader.Get(DocumentNo) then
            exit;
        if not PurchHeader.Get(PurchHeader."Document Type"::Order, PRHeader."Reference No.") then
            exit;

        if PurchHeader."Currency Code" = '' then
            Currency.InitRoundingPrecision
        else
            Currency.Get(PurchHeader."Currency Code");

        PRLines.Reset();
        PRLines.SetRange("Document No.", DocumentNo);
        PRLines.SetFilter(Quantity, '>%1', 0);
        if PRLines.FindFirst() then
            repeat
                purchaseLine.Reset();
                purchaseLine.SetRange("Document No.", PRHeader."Reference No.");
                purchaseLine.SetRange("No.", PRLines."Item No.");
                if purchaseLine.FindFirst() then begin
                    DirectUnitCost := purchaseLine."Direct Unit Cost";
                    if IUM.Get(purchaseLine."No.", purchaseLine."Unit of Measure Code") then begin
                        if PRLines."Unit of Measure Code" <> purchaseLine."Unit of Measure Code" then begin
                            //TotalBase += DirectUnitCost * (PRLines.Quantity / IUM."Qty. per Unit of Measure") + (DirectUnitCost * (PRLines.Quantity / IUM."Qty. per Unit of Measure")) * (purchaseLine."VAT %" / 100);
                            subTotalBase += Round(DirectUnitCost * (PRLines.Quantity / IUM."Qty. per Unit of Measure"), Currency."Invoice Rounding Precision", Currency.InvoiceRoundingDirection);
                            vatBase += (DirectUnitCost * (PRLines.Quantity / IUM."Qty. per Unit of Measure")) * (purchaseLine."VAT %" / 100);
                        end else begin
                            //TotalBase += DirectUnitCost * (PRLines.Quantity) + (DirectUnitCost * (PRLines.Quantity)) * (purchaseLine."VAT %" / 100);
                            subTotalBase += Round(DirectUnitCost * (PRLines.Quantity), Currency."Invoice Rounding Precision", Currency.InvoiceRoundingDirection);
                            vatBase += (DirectUnitCost * (PRLines.Quantity)) * (purchaseLine."VAT %" / 100);

                        end;
                    end else
                        Error(Text001, purchaseLine."No.");
                end;
            until PRLines.Next = 0;
        PRHeader."Subtotal" := subTotalBase;//Round(subTotalBase, Currency."Invoice Rounding Precision", Currency.InvoiceRoundingDirection);
        PRHeader."Tax" := vatBase;//Round(vatBase, Currency."Invoice Rounding Precision", Currency.InvoiceRoundingDirection);
        PRHeader."Total" := subTotalBase + vatBase;//Round(TotalBase, Currency."Invoice Rounding Precision", Currency.InvoiceRoundingDirection);
        //US606-JH-Registrar fecha de contabilizacion con fecha del día. 
        PRHeader."Counted Date" := Today();
        //US606-JH-Registrar fecha de contabilizacion con fecha del día.
        PRHeader.Modify();
        Commit();
    end;

    procedure RemoveLeftZeroVendorInvoiceNo(InputString: Text): Text
    var
        FirstSixDigits: Text[6];
        RemainingString: Text;
        FirstSixDigitsInt: Integer;
    begin
        FirstSixDigits := CopyStr(InputString, 1, 6);
        if Evaluate(FirstSixDigitsInt, FirstSixDigits) and (FirstSixDigitsInt > 0) then
            RemainingString := CopyStr(InputString, 7)
        else
            RemainingString := InputString;

        exit(FirstSixDigits + DelChr(RemainingString, '<', '0'));
    end;

    procedure OnLookupDte(var PurchaseHeader: Record "Purchase Header"): Boolean
    var
        RPurchDte: Record "FSN Recep. Purch. DTE";
        Vendor: Record Vendor;
        Actional: Action;
        ExtPurch: Codeunit "FSN External Purch. Manager";
        invoiceList: List of [Text];
        invoice: Text;
        util: Codeunit "FSN External Purch. Manager";
        lTex001: Label 'La recepción debe tener al menos una linea antes de seleccionar DTE';
        lTex002: Label 'Registro vendedor no tiene NIT';
        lTex003: Label 'Este DTE ya fue registrado';
        lTex004: Label 'DTE no valido debe contener 31 caracteres incluyendo guiones: Ej DTE-03-M0010000-000000000000000';
    begin
        Vendor.Reset();
        Vendor.SetRange("No.", PurchaseHeader."Buy-from Vendor No.");
        if Vendor.FindFirst() then
            if Vendor."VAT Registration No." = '' then
                Message(lTex002);
        RPurchDte.Reset();
        RPurchDte.SetFilter("Issue Date", '>01/01/2025');
        RPurchDte.SetFilter("VAT Registration No.", '%1|%2', DelChr(Vendor."VAT Registration No.", '=', '-'), Vendor."VAT Registration No.");
        if PurchaseHeader."DTE Invoice" <> '' then
            RPurchDte.SetRange("DTE Invoice", PurchaseHeader."DTE Invoice");
        if PAGE.RunModal(PAGE::"FSN Recep. Purch. DTE", RPurchDte) = Action::LookupOK then begin
            invoice := RPurchDte."DTE Invoice";
            if invoice.Contains('-') AND invoice.Contains('DTE') AND (invoice <> '') then begin
                invoiceList := invoice.Split('-');
                PurchaseHeader.Validate("Vendor Invoice Number", DelChr((invoiceList.Get(invoiceList.Count)), '<', '0'));
                PurchaseHeader.Validate("Vendor Invoice Serie", invoiceList.Get(1) + DelChr(invoiceList.Get(2), '=', '0'));
                PurchaseHeader."DTE Invoice" := RPurchDte."DTE Invoice";
                PurchaseHeader."DTE AuthNumber" := RPurchDte."DTE AuthNumber";
                PurchaseHeader."Signature Validation" := RPurchDte."Signature Validation";
                PurchaseHeader."Unique Document No." := PurchaseHeader."Vendor Invoice No.";
                exit(true);
            end else
                Message(lTex004);
        end;
        exit(false);
    end;

    procedure OnValidateDte(var PurchaseHeader: Record "Purchase Header"): Boolean
    var
        invoiceList: List of [Text];
        invoice: Text;
        util: Codeunit "FSN External Purch. Manager";
        RPurchDte: Record "FSN Recep. Purch. DTE";
        Vendor: Record Vendor;
        lTex001: Label 'La recepción debe tener al menos una linea antes de seleccionar DTE';
        lTex002: Label 'Registro Proveedor no tiene NIT';
        lTex003: Label 'Este DTE ya fue registrado';
        lTex004: Label 'DTE no valido debe contener 31 caracteres incluyendo guiones: Ej DTE-03-M0010000-000000000000000';
        lTex005: Label 'No se puede registrar la recepción del pedido con DTE de Mascara';
        lTex006: Label 'Pendiente Configuración Parametro Consulta Automatica DTE-> Grupo:CONFCOM Codigo:CONFDTECOM';
    begin
        if PurchaseHeader."DTE Invoice" <> '' then
            if StrLen(PurchaseHeader."DTE Invoice") = 31 then begin
                if PurchaseHeader."DTE Invoice" <> 'DTE-03-M0010000-000000000000000' then begin
                    Vendor.Reset();
                    Vendor.SetRange("No.", PurchaseHeader."Buy-from Vendor No.");
                    if Vendor.FindFirst() then
                        if Vendor."VAT Registration No." = '' then
                            Message(lTex002);
                    RPurchDte.Reset();
                    RPurchDte.SetFilter("Issue Date", '>01/01/2025');
                    RPurchDte.SetFilter("VAT Registration No.", '%1|%2', DelChr(Vendor."VAT Registration No.", '=', '-'), Vendor."VAT Registration No.");
                    RPurchDte.SetRange("DTE Invoice", PurchaseHeader."DTE Invoice");
                    if RPurchDte.FindFirst() then begin
                        invoice := RPurchDte."DTE Invoice";
                        if invoice.Contains('-') AND invoice.Contains('DTE') AND (invoice <> '') then begin
                            invoiceList := invoice.Split('-');
                            PurchaseHeader.Validate("Vendor Invoice Number", DelChr((invoiceList.Get(invoiceList.Count)), '<', '0'));
                            PurchaseHeader.Validate("Vendor Invoice Serie", invoiceList.Get(1) + DelChr(invoiceList.Get(2), '=', '0'));
                            PurchaseHeader."DTE Invoice" := RPurchDte."DTE Invoice";
                            PurchaseHeader."DTE AuthNumber" := RPurchDte."DTE AuthNumber";
                            PurchaseHeader."Signature Validation" := RPurchDte."Signature Validation";
                            PurchaseHeader."Unique Document No." := PurchaseHeader."Vendor Invoice No.";
                            exit(true);
                        end;
                    end else begin
                        invoice := PurchaseHeader."DTE Invoice";
                        if invoice.Contains('-') AND invoice.Contains('DTE') AND (invoice <> '') then begin
                            invoiceList := invoice.Split('-');
                            PurchaseHeader.Validate("Vendor Invoice Number", DelChr((invoiceList.Get(invoiceList.Count)), '<', '0'));
                            PurchaseHeader.Validate("Vendor Invoice Serie", invoiceList.Get(1) + DelChr(invoiceList.Get(2), '=', '0'));
                            PurchaseHeader."Unique Document No." := PurchaseHeader."Vendor Invoice No.";
                            exit(true);
                        end;
                    end;
                end else
                    Error(lTex005);
            end else
                Error(lTex004);
        exit(false);
    end;


    /*  [EventSubscriber(ObjectType::Page, Page::"LSC Retail Receiving", 'OnAfterValidateEvent', 'Reference No.', true, true)]
        local procedure "LSC Retail Receiving_OnAfterValidateEvent_[content / Receiving] - Reference No."(var Rec: Record "LSC P/R Counting Header")
        var
            fsnParam: Record "FSN Parameter";
            parameterValue: Text;
            parameterList: List of [Text];
            Text01: Label 'Para este proveedor es requerido hacer la recepción por medio DTE';
        begin
            fsnParam.Reset();
            if fsnParam.Get('CONFCOM', 'CONFPRODTE') then begin
                if fsnParam.Activo then begin
                    if fsnParam.Valor <> '' then begin
                        parameterList := fsnParam.Valor.Split('|');
                        foreach parameterValue in parameterList do begin
                            if Rec."Vendor No. / Customer No." = parameterValue then begin
                                Rec."FSN Automatic Search" := true;
                                if (fsnParam."Value Text 1" = Rec."No.") and (fsnParam."Value Text 1" <> '') then
                                    Rec."FSN Automatic Search" := false;
                                if Rec."FSN Automatic Search" then begin
                                    if Rec."DTE Invoice" = '' then
                                        Message(Text01);
                                    Rec.Modify(true);
                                end;
                            end;
                        end;
                    end;
                end;
            end;
        end;
     */
    //US-515****Desactivar el autocompletar de la codeunit 70405 "IDS Count Headaer"
    [EventSubscriber(ObjectType::Table, database::"LSC P/R Counting Header", 'OnAfterValidateEvent', 'Reference No.', false, false)]
    procedure OnAfterValidateEvent(var Rec: Record "LSC P/R Counting Header"; var xRec: record "LSC P/R Counting Header"; CurrFieldNo: Integer)
    var
        PHeader: Record "Purchase Header";
        SHeader: Record "Sales Header";
        recx: Record "LSC P/R Counting Header";
    begin
        if not (CurrFieldNo in [0, 11]) then exit;

        CASE Rec."Counting Type" OF
            Rec."Counting Type"::Receiving:
                BEGIN
                    CASE Rec.Receiving OF
                        Rec.Receiving::"Purchase Order", Rec.Receiving::"Purchase Order(create)":
                            begin
                                PHeader.SETRANGE("Document Type", PHeader."Document Type"::Order);
                                PHeader.SETRANGE("No.", Rec."Reference No.");
                                IF PHeader.FINDFIRST() THEN begin
                                    Rec.validate("Sub Type", PHeader."Sub Type");
                                    Rec."Identif. Type" := PHeader."Identif. Type";
                                    Rec."Identif. No." := PHeader."Identif. No.";
                                    Rec."Withhold Tax No." := PHeader."Withhold Tax No.";
                                    Rec."Withhold ISR No." := PHeader."Withhold ISR No.";
                                    REC."Resolution Date" := PHeader."Resolution Date";
                                    Rec."Vendor Invoice Serie" := '';
                                    Rec."Vendor Invoice Number" := '';
                                    Rec."Vendor Invoice No." := '';
                                    Rec."Unique Document No." := '';
                                    Rec."DTE AuthNumber" := '';
                                    Rec."DTE Invoice" := '';
                                    Rec."Signature Validation" := '';
                                    Rec.Modify();
                                end;

                            END;

                        Rec.Receiving::"Sales Return Order":
                            BEGIN
                                SHeader.SETRANGE(SHeader."Document Type", SHeader."Document Type"::"Return Order");
                                SHeader.SETRANGE("No.", Rec."Reference No.");
                                IF SHeader.FINDFIRST() THEN begin
                                    Rec.Validate("Sub Type", SHeader."Sub Type");
                                    Rec.Modify();
                                end;
                            END;
                    end;
                end;
            Rec."Counting Type"::Picking:
                case rec.Picking of
                    REC.Picking::"Purchase Return Order", Rec.Picking::"Purchase Return Order (create)":
                        begin
                            PHeader.SETRANGE(PHeader."Document Type", PHeader."Document Type"::"Return Order");
                            PHeader.SETRANGE("No.", Rec."Reference No.");
                            IF PHeader.FINDFIRST() THEN begin
                                Rec.Validate("Sub Type", PHeader."Sub Type");
                                Rec."Identif. Type" := PHeader."Identif. Type";
                                Rec."Identif. No." := PHeader."Identif. No.";
                                Rec."Withhold Tax No." := PHeader."Withhold Tax No.";
                                Rec."Withhold ISR No." := PHeader."Withhold ISR No.";
                                REC."Resolution Date" := PHeader."Resolution Date";
                                Rec."Vendor Invoice Serie" := PHeader."Vendor Invoice Serie";
                                Rec."Vendor Invoice Number" := PHeader."Vendor Invoice Number";
                                Rec."Vendor Invoice No." := PHeader."Vendor Invoice No.";
                                Rec."Unique Document No." := PHeader."Unique Document No.";
                                Rec.Modify();
                            end;
                        end;
                    Rec.Picking::"Sales Order", Rec.Picking::"Sales Order (create)":
                        begin
                            SHeader.SETRANGE(SHeader."Document Type", SHeader."Document Type"::Order);
                            SHeader.SETRANGE("No.", Rec."Reference No.");
                            IF SHeader.FINDFIRST() THEN begin
                                Rec.Validate("Sub Type", SHeader."Sub Type");
                                Rec.Modify();
                            end;
                        end;
                end;

        end;
    end;


    //US-515****
    //US-516****
    /*
        [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Jnl.-Post Line", 'OnCheckExpirationDateOnBeforeAssignExpirationDate', '', true, true)]
        local procedure "Item Jnl.-Post Line_OnCheckExpirationDateOnBeforeAssignExpirationDate"
        (
            var TempTrackingSpecification: Record "Tracking Specification";
            ExistingExpirationDate: Date;
            var IsHandled: Boolean
        )
        begin
            if TempTrackingSpecification."Expiration Date" <> 0D then
                ExistingExpirationDate := TempTrackingSpecification."Expiration Date";
        end;


        [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Tracking Management", 'OnBeforeTempHandlingSpecificationInsert', '', true, true)]
        local procedure "Item Tracking Management_OnBeforeTempHandlingSpecificationInsert"
        (
            var TempTrackingSpecification: Record "Tracking Specification";
            ReservationEntry: Record "Reservation Entry"
        )
        begin
            TempTrackingSpecification."Expiration Date" := ReservationEntry."Expiration Date";
        end;
    */
    //US-516****

    //US-524
    procedure UpdateRcptInvoiced(OrderNo: Code[20]): Boolean
    var
        purchRcptHeader: Record "Purch. Rcpt. Header";
        purchRcptLine:
                Record "Purch. Rcpt. Line";
        RcptNotInvoiced:
                Boolean;
    begin
        /*
        Buscar todas las recepciones sin facturar por numero de pedido.
        Buscar todas las lineas evaluar cantidad recibida sea igual a la cantidad 
            facturada Recepcion = Facturada caso contrario Recepcion = No Facturada
        Con la primera linea que encuentre diferencias se marca con no factura y sale del ciclo optimizando la busqueda
        Retorna true si hay recepciones sin facturar
        */
        RcptNotInvoiced := false;
        purchRcptHeader.Reset();
        purchRcptHeader.SetRange("Order No.", OrderNo);
        purchRcptHeader.SetRange(Invoiced, false);
        if purchRcptHeader.FindFirst() then begin
            repeat
                purchRcptLine.Reset();
                purchRcptLine.SetRange("Document No.", purchRcptHeader."No.");
                purchRcptLine.SetFilter("Quantity", '<>%1', 0);
                if purchRcptLine.FindFirst() then
                    repeat
                        if (purchRcptLine.Quantity - purchRcptLine."Quantity Invoiced") = 0 then
                            purchRcptHeader.Invoiced := true
                        else begin
                            purchRcptHeader.Invoiced := false;
                            RcptNotInvoiced := true;
                        end;
                    until (purchRcptLine.Next() = 0) or (RcptNotInvoiced);
                purchRcptHeader.Modify(true);
            until purchRcptHeader.Next() = 0;
        end;
        exit(RcptNotInvoiced);
    end;


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Purch.-Post", 'OnAfterUpdateInvoicedQtyOnPurchRcptLine', '', true, true)]
    local procedure "Purch.-Post_OnAfterUpdateInvoicedQtyOnPurchRcptLine"
    (
        var PurchInvHeader: Record "Purch. Inv. Header";
        var PurchRcptLine: Record "Purch. Rcpt. Line";
        var PurchaseLine: Record "Purchase Line";
        var TempTrackingSpecification: Record "Tracking Specification";
        TrackingSpecificationExists: Boolean;
        var QtyToBeInvoiced: Decimal;
        var QtyToBeInvoicedBase: Decimal;
        var PurchaseHeader: Record "Purchase Header";
        CommitIsSuppressed: Boolean
    )
    var
        purchRcptHeader: Record "Purch. Rcpt. Header";
        purchRcptLine2: Record "Purch. Rcpt. Line";
    begin
        /*
        Buscar todas las recepciones sin facturar por numero de pedido.
        Buscar todas las lineas evaluar cantidad recibida sea igual a la cantidad 
            facturada Recepcion = Facturada caso contrario Recepcion = No Facturada
        Con la primera linea que encuentre diferencias se marca con no factura y sale del ciclo optimizando la busqueda
        */

        purchRcptHeader.Reset();
        purchRcptHeader.SetRange("Order No.", PurchaseHeader."No.");
        if purchRcptHeader.FindFirst() then begin
            repeat
                purchRcptLine2.Reset();
                purchRcptLine2.SetRange("Document No.", purchRcptHeader."No.");
                if purchRcptLine2.FindFirst() then begin
                    purchRcptLine2.SetFilter("Qty. Rcd. Not Invoiced", '<>%1', 0);
                    if purchRcptLine2.FindFirst() then
                        purchRcptHeader.Invoiced := false
                    else begin
                        purchRcptHeader.Invoiced := true;
                        purchRcptHeader."FSN last message" := '';
                    end;

                end;
                purchRcptHeader.Modify();
            until purchRcptHeader.Next() = 0;
        end;
    end;

    //US-530****
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Job Queue - Enqueue", 'OnAfterEnqueueJobQueueEntry', '', true, true)]
    local procedure "Job Queue - Enqueue_OnAfterEnqueueJobQueueEntry"(var JobQueueEntry: Record "Job Queue Entry")
    var
        PurchaseHeader: Record "Purchase Header";
    begin
        PurchaseHeader.Reset();
        if JobQueueEntry."Job Queue Category Code" = 'CONT_COMP' then begin
            PurchaseHeader.SetFilter("Job Queue Entry ID", '%1', JobQueueEntry.ID);
            PurchaseHeader.SetRange("Document Type", PurchaseHeader."Document Type"::Order);
            if PurchaseHeader.FindFirst() then begin
                JobQueueEntry."FSN HRC No" := PurchaseHeader."Last Receiving No.";
                JobQueueEntry."FSN Order No" := PurchaseHeader."No.";

                JobQueueEntry.Modify();
            end;
        end;
    end;
    //US-530****
    procedure CalculatePurchaseSubPageTotalsInvoice(var TotalPurchaseHeader: Record "Purchase Header"; var TotalPurchaseLine: Record "Purchase Line"; var VATAmount: Decimal; var InvoiceDiscountAmount: Decimal; var InvoiceDiscountPct: Decimal)
    var
        PurchaseLine2: Record "Purchase Line";
        TotalPurchaseLine2: Record "Purchase Line";
        PurchasesPayablesSetup: Record "Purchases & Payables Setup";
        PurchCalcDiscount: Codeunit "Purch.-Calc.Discount";
    begin


        PurchasesPayablesSetup.GetRecordOnce;
        TotalPurchaseLine2.Copy(TotalPurchaseLine);
        TotalPurchaseLine2.Reset();
        TotalPurchaseLine2.SetRange("Document Type", TotalPurchaseHeader."Document Type");
        TotalPurchaseLine2.SetRange("Document No.", TotalPurchaseHeader."No.");
        TotalPurchaseLine2.SetRange("Document No.", TotalPurchaseHeader."No.");

        if PurchasesPayablesSetup."Calc. Inv. Discount" and (TotalPurchaseHeader."No." <> '') and
           (TotalPurchaseHeader."Vendor Posting Group" <> '')
        then begin
            TotalPurchaseHeader.CalcFields("Recalculate Invoice Disc.");
            if TotalPurchaseHeader."Recalculate Invoice Disc." then
                if TotalPurchaseLine2.FindFirst then begin
                    PurchCalcDiscount.CalculateInvoiceDiscountOnLine(TotalPurchaseLine2);
                end;
        end;

        TotalPurchaseLine2.CalcSums(Amount, "Amount Including VAT", "Line Amount", "Inv. Discount Amount");
        VATAmount := TotalPurchaseLine2."Amount Including VAT" - TotalPurchaseLine2.Amount;
        InvoiceDiscountAmount := TotalPurchaseLine2."Inv. Discount Amount";

        TotalPurchaseLine := TotalPurchaseLine2;
    end;



    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Purch.-Post", 'OnAfterPostPurchaseDoc', '', true, true)]
    local procedure "Purch.-Post_OnAfterPostPurchaseDoc"//baleman
    (
        var PurchaseHeader: Record "Purchase Header";
        var GenJnlPostLine: Codeunit "Gen. Jnl.-Post Line";
        PurchRcpHdrNo: Code[20];
        RetShptHdrNo: Code[20];
        PurchInvHdrNo: Code[20];
        PurchCrMemoHdrNo: Code[20];
        CommitIsSupressed: Boolean
    )
    var
        PurchInvHeader: Record "Purch. Inv. Header";
        PurchCrMemoHeader: Record "Purch. Cr. Memo Hdr.";
        PurchRcptHdr: Record "Purch. Rcpt. Header";
        User: Record User;
    begin
        PurchInvHeader.Reset();
        PurchCrMemoHeader.Reset();
        User.Reset();
        with PurchaseHeader do begin
            case "Document Type" of
                "Document Type"::Invoice:
                    begin
                        if PurchInvHeader.Get(PurchInvHdrNo) then
                            if User.Get(PurchaseHeader.SystemCreatedBy) then begin
                                PurchInvHeader."User ID" := User."User Name";
                                PurchInvHeader.Modify();
                            end;
                        if PurchRcptHdr.Get(PurchRcpHdrNo) then begin
                            PurchRcptHdr.SubTotal := PurchaseHeader.SubTotal;
                            PurchRcptHdr.Tax := PurchaseHeader."Tax";
                            PurchRcptHdr.Total := PurchaseHeader.Total;
                            PurchRcptHdr.Modify();
                        end;

                    end;
                "Document Type"::"Credit Memo":
                    begin
                        if PurchCrMemoHeader.Get(PurchCrMemoHdrNo) then begin
                            PurchCrMemoHeader."Order No." := PurchaseHeader."Vendor Authorization No.";
                            PurchCrMemoHeader.Modify();
                        end;
                        if PurchCrMemoHeader.Get(PurchCrMemoHdrNo) then begin
                            if User.Get(PurchaseHeader.SystemCreatedBy) then begin
                                PurchCrMemoHeader."User ID" := User."User Name";
                                PurchCrMemoHeader.Modify();
                            end;
                        end;
                    end;
                "Document Type"::"Return Order":
                    begin
                        if PurchCrMemoHeader.Get(PurchCrMemoHdrNo) then begin
                            PurchCrMemoHeader."Order No." := PurchaseHeader."Vendor Authorization No.";
                            PurchCrMemoHeader.Modify();
                        end;
                    end;
                "Document Type"::Order:
                    begin
                        if PurchRcptHdr.Get(PurchRcpHdrNo) then begin
                            PurchRcptHdr.SubTotal := PurchaseHeader.SubTotal;
                            PurchRcptHdr.Tax := PurchaseHeader."Tax";
                            PurchRcptHdr.Total := PurchaseHeader.Total;
                            PurchRcptHdr.Modify();
                        end;
                    end;
            end;

        end;
    end;


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnAfterPostSalesDoc', '', true, true)]
    local procedure "Sales-Post_OnAfterPostSalesDoc"
    (
        var SalesHeader: Record "Sales Header";
        var GenJnlPostLine: Codeunit "Gen. Jnl.-Post Line";
        SalesShptHdrNo: Code[20];
        RetRcpHdrNo: Code[20];
        SalesInvHdrNo: Code[20];
        SalesCrMemoHdrNo: Code[20];
        CommitIsSuppressed: Boolean;
        InvtPickPutaway: Boolean;
        var CustLedgerEntry: Record "Cust. Ledger Entry";
        WhseShip: Boolean;
        WhseReceiv: Boolean
    )
    var
        SalesInvHeader: Record "Sales Invoice Header";
        SalesCrMemoHeader: Record "Sales Cr.Memo Header";
        User: Record User;
    begin
        SalesInvHeader.Reset();
        SalesCrMemoHeader.Reset();
        User.Reset();
        with SalesHeader do begin
            case "Document Type" of
                "Document Type"::Invoice:
                    begin
                        if SalesInvHeader.Get(SalesInvHdrNo) then
                            if User.Get(SalesHeader.SystemCreatedBy) then begin
                                SalesInvHeader."User ID" := User."User Name";
                                SalesInvHeader.Modify();
                            end;
                    end;
                "Document Type"::"Credit Memo":
                    begin
                        if SalesCrMemoHeader.Get(SalesCrMemoHdrNo) then
                            if User.Get(SalesHeader.SystemCreatedBy) then begin
                                SalesCrMemoHeader."User ID" := User."User Name";
                                SalesCrMemoHeader.Modify();
                            end;
                    end;
            end;

        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Purch.-Post", 'OnBeforePostPurchaseDoc', '', true, true)]
    local procedure "Purch.-Post_OnBeforePostPurchaseDoc"
    (
        var PurchaseHeader: Record "Purchase Header";
        PreviewMode: Boolean;
        CommitIsSupressed: Boolean;
        var HideProgressWindow: Boolean;
        var ItemJnlPostLine: Codeunit "Item Jnl.-Post Line"
    )
    var
        PurchInvHeader: Record "Purch. Inv. Header";
        PurchCrMemoHeader: Record "Purch. Cr. Memo Hdr.";
        PurchRcptHdr: Record "Purch. Rcpt. Header";
        User: Record User;
        lTex001: Label 'El %1 %2 Ya fue registrado';
        CountingHeader: Record "LSC P/R Counting Header";
        fsnParam: Record "FSN Parameter";
    begin

        if PurchaseHeader.Invoice then begin
            //Verificiar si es registro con DTE verificar que los campos no esten vacios
            if PurchaseHeader."DTE Invoice" <> '' then begin
                if PurchaseHeader."DTE AuthNumber" = '' then
                    Error('El campo Codigo Generacion no puede estar vacio.');
                if PurchaseHeader."Signature Validation" = '' then
                    Error('El campo Sello Validacion no puede estar vacio.');
                with PurchaseHeader do begin
                    case "Document Type" of
                        "Document Type"::Invoice, "Document Type"::Order:
                            invFSNUtilityDTESearch(PurchaseHeader, 'SELE-DTE-HISPURCINV');
                        "Document Type"::"Credit Memo", "Document Type"::"Return Order":
                            invFSNUtilityDTESearch(PurchaseHeader, 'SELE-DTE-HISPURCMEM');
                    end;
                end;
            end;
        end;
        //US-606-JH Validar que el campo Autorizacion Proveedor no este vacio
        if PurchaseHeader."Document Type" = PurchaseHeader."Document Type"::"Return Order" then
            if PurchaseHeader."Vendor Authorization No." = '' then
                Error('El campo Autorizacion Proveedor no puede estar vacio.');
        //US-606-JH Validar que el campo Autorizacion Proveedor no este vacio

        CountingHeader.reset;
        CountingHeader.setrange("Posted No.", PurchaseHeader."LSC Reciving/Picking No.");
        if CountingHeader.find('-') then
            if (CountingHeader."Counting Type" = CountingHeader."Counting Type"::Receiving) and
           (CountingHeader.Receiving = CountingHeader.Receiving::"Purchase Order")
        then begin
                if fsnParam.Get('APPLYINV', CountingHeader."Store No.") and fsnParam.Activo then
                    if ValidateDTEAgainstReceptionRecord(CountingHeader) then
                        PurchaseHeader.Invoice := true;
            end;
    end;

    local procedure ValidateDTEAgainstReceptionRecord(PHeader: Record "LSC P/R Counting Header"): boolean
    var
        Vendor_l: Record Vendor;
        RecePurchDte_l: Record "FSN Recep. Purch. DTE";
        PurchRcptHeader: Record "Purch. Rcpt. Header";
        PurchInvHeader: Record "Purch. Inv. Header";
        VendorNo_l: Code[20];
        VendorVATClean_l: Text[20];
        OrderNo: Code[20];
        ReceiptsCount: Integer;
        InvoicesCount: Integer;
        DocumentOK: boolean;
        Text001: Label 'No se encontró el proveedor en la recepción %1. Campo "%2" vacío.';
        Text002: Label 'No existe el proveedor %1 en la tabla Vendor.';
        Text003: Label 'El proveedor %1 no tiene valor en "%2".';
        Text004: Label 'No se puede validar DTE en recepción %1. Campo "%2" vacío.';
        Text005: Label 'No se encontró registro en "%1" para VAT "%2" y DTE AuthNumber "%3".';
        Text006: Label 'No coincide "%1". Recepción: "%2" / DTE: "%3".';
        Text007: Label 'No coincide "%1". Recepción: %2 / DTE: %3.';
    begin
        VendorNo_l := PHeader."Vendor No. / Customer No.";
        if VendorNo_l = '' then
            exit(false);
        //Error(Text001, PHeader."No.", PHeader.FieldCaption("Vendor No. / Customer No."));

        if not Vendor_l.Get(VendorNo_l) then
            exit(false);
        //Error(Text002, VendorNo_l);

        if Vendor_l."VAT Registration No." = '' then
            exit(false);
        //Error(Text003, VendorNo_l, Vendor_l.FieldCaption("VAT Registration No."));

        VendorVATClean_l := CopyStr(NormalizeVAT(Vendor_l."VAT Registration No."), 1, MaxStrLen(VendorVATClean_l));
        if VendorVATClean_l = '' then
            exit(false);
        //Error(Text003, VendorNo_l, Vendor_l.FieldCaption("VAT Registration No."));

        //recepcion sin factura = falso 
        //si no hay ninguna recepcion seguir validano
        OrderNo := PHeader."Reference No.";
        if OrderNo <> '' then begin
            PurchRcptHeader.Reset();
            PurchRcptHeader.SetRange("Order No.", OrderNo);
            ReceiptsCount := PurchRcptHeader.Count;
            if ReceiptsCount > 0 then begin
                PurchInvHeader.Reset();
                PurchInvHeader.SetRange("Order No.", OrderNo);
                InvoicesCount := PurchInvHeader.Count;
                if InvoicesCount = 0 then
                    exit(false);
                if InvoicesCount <> ReceiptsCount then
                    exit(false);
            end;
        end;


        /*if PHeader."DTE AuthNumber" = '' then
            exit(false);*/
        //Error(Text004, PHeader."No.", PHeader.FieldCaption("DTE AuthNumber"));
        Clear(DocumentOK);
        RecePurchDte_l.Reset();
        RecePurchDte_l.SetRange("VAT Registration No.", VendorVATClean_l);
        RecePurchDte_l.SetRange("DTE AuthNumber", PHeader."DTE AuthNumber");
        if not RecePurchDte_l.FindFirst() then
            exit(false);
        //Error(Text005, RecePurchDte_l.TableCaption, VendorVATClean_l, PHeader."DTE AuthNumber");

        if RecePurchDte_l."DTE AuthNumber" <> PHeader."DTE AuthNumber" then
            exit(false);
        //Error(Text006, PHeader.FieldCaption("DTE AuthNumber"), PHeader."DTE AuthNumber", RecePurchDte_l."DTE AuthNumber");

        if RecePurchDte_l."DTE Invoice" <> PHeader."DTE Invoice" then
            exit(false);
        //Error(Text006, PHeader.FieldCaption("DTE Invoice"), PHeader."DTE Invoice", RecePurchDte_l."DTE Invoice");

        /*IF RecePurchDte_l."Signature Validation" = '' THEN
            exit(false);*/

        if RecePurchDte_l."Signature Validation" <> PHeader."Signature Validation" then
            exit(false);
        //Error(Text006, PHeader.FieldCaption("Signature Validation"), PHeader."Signature Validation", RecePurchDte_l."Signature Validation");

        if Round(RecePurchDte_l.Subtotal, 0.01) <> Round(PHeader.SubTotal, 0.01) then
            exit(false);
        //Error(Text007, PHeader.FieldCaption(SubTotal), Round(PHeader.SubTotal, 0.01), Round(RecePurchDte_l.Subtotal, 0.01));

        if Round(RecePurchDte_l.IVA, 0.01) <> Round(PHeader.Tax, 0.01) then
            exit(false);
        //Error(Text007, PHeader.FieldCaption(Tax), Round(PHeader.Tax, 0.01), Round(RecePurchDte_l.IVA, 0.01));
        exit(true);
    end;

    local procedure NormalizeVAT(VATRegistrationNo: Text): Text
    begin
        exit(DelChr(VATRegistrationNo, '=', '- '));
    end;

    local procedure invFSNUtilityDTESearch(PurchHdr: Record "Purchase Header"; RequestID: Text[50])
    var
        FSNUtility: Codeunit "FSN Utility";
        XMLRequest: Text;
        XMLResponse: Text;
        MsgResult: Text;
        POSMenuLineTemp: Record "LSC POS Menu Line" temporary;
        Processed: Boolean;
    begin
        XMLRequest := PurchHdr."DTE AuthNumber";
        POSMenuLineTemp.Reset();
        POSMenuLineTemp.Init();
        POSMenuLineTemp."Profile ID" := 'FASANI';
        POSMenuLineTemp."Menu ID" := 'SEARCHDTE';
        POSMenuLineTemp."Key No." := 1;
        POSMenuLineTemp."Set Current-Input" := PurchHdr."DTE Invoice";
        POSMenuLineTemp."Current-Description" := PurchHdr."DTE AuthNumber";
        POSMenuLineTemp."Current-Description2" := PurchHdr."Signature Validation";
        POSMenuLineTemp."Current-RECEIPT" := PurchHdr."Buy-from Vendor No.";
        POSMenuLineTemp.Insert();
        FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Release Purchase Document", 'OnAfterReleasePurchaseDoc', '', true, true)]
    local procedure "Release Purchase Document_OnAfterReleasePurchaseDoc"
    (
        var PurchaseHeader: Record "Purchase Header";
        PreviewMode: Boolean;
        var LinesWereModified: Boolean
    )
    var
        PurchaseLine: Record "Purchase Line";
        SpecialCalcJnl: Record "Special Calc Journal";
        SpecilCalc: Record "Special Calc Group";
    begin
        PurchaseLine.SETRANGE("Document No.", PurchaseHeader."No.");
        PurchaseLine.SETRANGE("Document Type", PurchaseHeader."Document Type");
        PurchaseLine.SetFilter("Unit of Measure Code", '%1', '');
        PurchaseLine.SETRANGE(Type, PurchaseLine.Type::"G/L Account");
        IF PurchaseLine.FINDFIRST THEN
            REPEAT
                SpecialCalcJnl.RESET;
                SpecialCalcJnl.SETRANGE("Document Type", PurchaseLine."Document Type");
                SpecialCalcJnl.SETRANGE("Document No.", PurchaseLine."Document No.");
                SpecialCalcJnl.SetRange("Line New", PurchaseLine."Line No.");
                SpecialCalcJnl.SetFilter("Calc Amount", '<>%1', 0);
                IF SpecialCalcJnl.FINDFIRST THEN begin
                    PurchaseHeader."FSN Withholding Tax Amount" := SpecialCalcJnl."Calc Amount";
                    PurchaseHeader.Modify();
                end;
            UNTIL PurchaseLine.NEXT = 0;


    end;


    [EventSubscriber(ObjectType::Table, Database::"LSC Picking / Receiving lines", 'OnBeforeValidateLotNo', '', true, true)]
    local procedure "LSC Picking / Receiving lines_OnBeforeValidateLotNo"
    (
        var PickingReceivingLines: Record "LSC Picking / Receiving lines";
        xPickingReceivingLines: Record "LSC Picking / Receiving lines";
        CallingFieldNo: Integer;
        var IsHandled: Boolean
    )
    var
        PickingRecHeader: Record "LSC P/R Counting Header";
        ReservationEntry: Record "Reservation Entry";
        Text001: Label 'Antes de asignar un Lote, el campo Cantidad debe ser diferente de cero o vacio';
        ExpirationDate: Date;
    begin
        if PickingReceivingLines.Quantity <> 0 then
            if (PickingReceivingLines."Lot No." <> '') then
                if PickingRecHeader.Get(PickingReceivingLines."Document No.") then begin
                    //Verificar si la reserva ya existe, evaluar por medio del lote anterior y eliminarla
                    ReservationEntry.Reset();
                    ReservationEntry.SetRange(ReservationEntry."Item No.", PickingReceivingLines."Item No.");
                    ReservationEntry.SetRange(ReservationEntry."Lot No.", xPickingReceivingLines."Lot No.");
                    ReservationEntry.SetRange(ReservationEntry."Source ID", PickingRecHeader."Reference No.");
                    IF ReservationEntry.FindFirst() then begin
                        ExpirationDate := ReservationEntry."Expiration Date";
                        ReservationEntry.Delete(true);
                    end;
                    CreateResEntry(PickingReceivingLines, PickingRecHeader);
                end;
    end;

    //Desde la recepcion se guarda informacion de producto con Numero de lote si no existe.
    procedure CreateResEntry(PickRecLine: Record "LSC Picking / Receiving lines"; PickingRecHeader: Record "LSC P/R Counting Header")
    var
        myInt: Integer;
        ReservEntry: Record "Reservation Entry";
        UOMMgt: Codeunit "Unit of Measure Management";
        PurchLine: Record "Purchase Line";
    begin
        ReservEntry."Entry No." := 0;
        ReservEntry."Reservation Status" := ReservEntry."Reservation Status"::Surplus;
        ReservEntry."Source Type" := 39;
        ReservEntry."Source Subtype" := ReservEntry."Source Subtype"::"1";
        ReservEntry."Item No." := PickRecLine."Item No.";
        ReservEntry."Lot No." := PickRecLine."Lot No.";
        ReservEntry."Expiration Date" := PickRecLine."Expiration Date";
        ReservEntry."New Expiration Date" := PickRecLine."Expiration Date";
        ReservEntry."Source ID" := PickingRecHeader."Reference No.";
        ReservEntry."Variant Code" := PickRecLine."Variant Code";
        ReservEntry."Location Code" := PickingRecHeader."Location Code";
        ReservEntry.Description := PickRecLine.Description;
        ReservEntry."Creation Date" := WorkDate;
        ReservEntry."Created By" := UserId;
        ReservEntry."Expected Receipt Date" := 0D;
        ReservEntry."Shipment Date" := 0D;
        ReservEntry.Positive := (PickRecLine.Quantity > 0);
        ReservEntry."Qty. per Unit of Measure" := PickRecLine."Qty. per Unit of Measure";
        ReservEntry."Quantity (Base)" := PickRecLine."Quantity (base)";
        if (ReservEntry."Quantity (Base)" <> 0) and ((ReservEntry.Quantity = 0)) then
            ReservEntry.Quantity := Round(PickRecLine."Quantity (Base)" / PickRecLine."Qty. per Unit of Measure", UOMMgt.QtyRndPrecision);
        ReservEntry."Qty. to Handle (Base)" := ReservEntry."Quantity (Base)";
        ReservEntry."Qty. to Invoice (Base)" := ReservEntry."Quantity (Base)";
        PurchLine.Reset();
        PurchLine.SetRange(PurchLine."Document No.", PickingRecHeader."Reference No.");
        PurchLine.SetRange(PurchLine."No.", PickRecLine."Item No.");
        if PurchLine.FindFirst() then
            ReservEntry."Source Ref. No." := PurchLine."Line No."
        else
            ReservEntry."Source Ref. No." := PickRecLine."Line No.";
        ReservEntry."Item Tracking" := ReservEntry."Item Tracking"::"Lot No.";
        ReservEntry."Untracked Surplus" := ReservEntry."Untracked Surplus" and not ReservEntry.Positive;
        ReservEntry.Insert(true);
    end;

    //US-606-JH Eliminar reservacion entry despues de eliminar la recepcion

    [EventSubscriber(ObjectType::Table, Database::"LSC Picking / Receiving lines", 'OnAfterDeleteEvent', '', true, true)]
    local procedure "LSC Picking / Receiving lines_OnAfterDeleteEvent"
    (
        var Rec: Record "LSC Picking / Receiving lines";
        RunTrigger: Boolean
    )
    var
        ReservationEntry: Record "Reservation Entry";
        PickingRecHeader: Record "LSC P/R Counting Header";
    begin
        if (Rec."Lot No." <> '') then begin
            if Rec.Quantity <> 0 then
                if PickingRecHeader.Get(Rec."Document No.") then begin
                    //Verificar si la reserva ya existe, evaluar por medio del lote anterior y eliminarla
                    ReservationEntry.Reset();
                    ReservationEntry.SetRange(ReservationEntry."Item No.", Rec."Item No.");
                    ReservationEntry.SetRange(ReservationEntry."Lot No.", Rec."Lot No.");
                    ReservationEntry.SetRange(ReservationEntry."Source ID", PickingRecHeader."Reference No.");
                    IF ReservationEntry.FindFirst() then
                        ReservationEntry.Delete(true);
                end;
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Purch.-Post (Yes/No)", 'OnBeforeOnRun', '', true, true)]
    local procedure "Purch.-Post (Yes/No)_OnBeforeOnRun"(var PurchaseHeader: Record "Purchase Header")
    begin
        //US-606-JH Validar que el campo Autorizacion Proveedor no este vacio
        if PurchaseHeader."Document Type" = PurchaseHeader."Document Type"::"Return Order" then
            if PurchaseHeader."Vendor Authorization No." = '' then
                Error('El campo Autorizacion Proveedor no puede estar vacio.');
        //US-606-JH Validar que el campo Autorizacion Proveedor no este vacio
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Job Queue Dispatcher", 'OnBeforeRun', '', true, true)]
    local procedure "Job Queue Dispatcher_OnBeforeRun"
 (
     var JobQueueEntry: Record "Job Queue Entry";
     var Skip: Boolean
 )
    var
        RecRef: RecordRef;
        PurchHeader: Record "Purchase Header";
        POSSESION: Codeunit "LSC POS Session";
    begin
        IF JobQueueEntry."Object ID to Run" = 98 THEN begin
            RecRef.Get(JobQueueEntry."Record ID to Process");
            RecRef.SetTable(PurchHeader);
            if PurchHeader.Find then begin
                IF PurchHeader."Assigned User ID" <> '' then
                    POSSESION.SetValue('VSESSION', PurchHeader."Assigned User ID")
                ELSE
                    POSSESION.SetValue('VSESSION', USERID);
            end;
        end;
    end;

    [EventSubscriber(ObjectType::Table, Database::"LSC Picking / Receiving lines", 'OnAfterValidateEvent', 'Expiration Date', true, true)]
    local procedure "LSC Picking / Receiving lines_OnAfterValidateEvent_Expiration Date"
    (
        var Rec: Record "LSC Picking / Receiving lines";
        var xRec: Record "LSC Picking / Receiving lines";
        CurrFieldNo: Integer
    )
    var
        PickingRecHeader: Record "LSC P/R Counting Header";
        ReservationEntry: Record "Reservation Entry";
        Text001: Label 'Antes de asignar una fecha de expiración, el campo Cantidad debe ser diferente de cero o vacio';
        ExpirationDate: Date;
    begin
        if Rec.Quantity <> 0 then
            if (Rec."Lot No." <> '') then
                if PickingRecHeader.Get(Rec."Document No.") then begin
                    ReservationEntry.Reset();
                    ReservationEntry.SetRange(ReservationEntry."Item No.", Rec."Item No.");
                    ReservationEntry.SetRange(ReservationEntry."Lot No.", Rec."Lot No.");
                    ReservationEntry.SetRange(ReservationEntry."Source ID", PickingRecHeader."Reference No.");
                    IF ReservationEntry.FindFirst() then begin
                        ReservationEntry."Expiration Date" := Rec."Expiration Date";
                        ReservationEntry."New Expiration Date" := Rec."Expiration Date";
                        ReservationEntry.Modify(true);
                    end;
                end;
    end;


    [EventSubscriber(ObjectType::Table, Database::"LSC Picking / Receiving lines", 'OnAfterValidateEvent', 'Serial No.', true, true)]
    local procedure "LSC Picking / Receiving lines_OnAfterValidateEvent_Serial No."
    (
        var Rec: Record "LSC Picking / Receiving lines";
        var xRec: Record "LSC Picking / Receiving lines";
        CurrFieldNo: Integer
    )
    begin
        if Rec."Serial No." = '' then
            if Rec."Lot No." <> '' then
                if xRec."Expiration Date" <> 0D then begin
                    Rec."Expiration Date" := xRec."Expiration Date";

                end;
    end;

    /*
    Programar Analisis
    Habilitar la accion si las recep fueron compartidad con EBS (accion)
    Recibir el proveedor
    Obtener las lineas de la recepcion seleccionada
    Verificar y descartar las lineas

        Que este en el historico de recepciones (validar el pedido)
        Que tengan una cantidad igual a la del pedido 
        Validar las otras recepciones autorizadas y validar que la suma sea diferente a la cantidad del pedido
        Verificar que cada linea de producto este relacionado con la tabla item vendor con el dato recibido
        Mostrar un box con la previa antes de registrar
        Registrar y mostrar el numero de pedido creado
    */


    procedure CreatePurchaseOrderAlternative(Vend: Record Vendor; PurchHdr: Record "Purchase Header")
    var
        PurchHdrVal: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        CountingHeaderVal: Record "LSC P/R Counting Header";
        ItemVendor: Record "Item Vendor";
        LSCPickingReceivinglines: Record "LSC Picking / Receiving lines";
        PurchLineAlternative: Dictionary of [Code[20], Integer];
        ItemNo: Code[20];

    begin
        OpenWindow();
        updateWindow(Vend."No.", Vend.Name, PurchHdr."No.", '');
        Sleep(10);
        PurchHdrVal.Reset();
        PurchHdrVal.SetRange("Your Reference", PurchHdr."No.");
        PurchHdrVal.SetRange("Buy-from Vendor No.", Vend."No.");
        if PurchHdrVal.FindFirst() then
            Error('Ya existe un pedido de compra alternativo para el proveedor %1 con el No. %2', Vend."No.", PurchHdrVal."No.");

        PurchaseLine.Reset();
        PurchaseLine.SetRange("Document Type", PurchHdr."Document Type");
        PurchaseLine.SetRange("Document No.", PurchHdr."No.");
        //PurchaseLine.SetRange("Quantity Received", 0);
        if PurchaseLine.FindSet() then begin
            repeat
                if (PurchaseLine.Quantity - PurchaseLine."Quantity Received") <> 0 then
                    if not PurchLineAlternative.ContainsKey(PurchaseLine."No.") then
                        PurchLineAlternative.Add(PurchaseLine."No.", (PurchaseLine.Quantity - PurchaseLine."Quantity Received"))
                    else
                        PurchLineAlternative.Set(PurchaseLine."No.", PurchLineAlternative.Get(PurchaseLine."No.") + (PurchaseLine.Quantity - PurchaseLine."Quantity Received"));
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
        end else
            Message('No se encontraron lineas pendientes de recepción del pedido %1', PurchHdr."No.");
        Sleep(10);
        if PurchLineAlternative.Count > 0 then
            foreach ItemNo in PurchLineAlternative.Keys do begin
                if PurchLineAlternative.Get(ItemNo) = 0 then
                    PurchLineAlternative.Remove(ItemNo);
            end;
        if PurchLineAlternative.Count > 0 then begin
            foreach ItemNo in PurchLineAlternative.Keys do begin
                ItemVendor.Reset();
                ItemVendor.SetRange("Vendor No.", Vend."No.");
                ItemVendor.SetRange("Item No.", ItemNo);
                if not ItemVendor.FindFirst() then
                    PurchLineAlternative.Remove(ItemNo)
                else
                    updateWindow(Vend."No.", Vend.Name, PurchHdr."No.", ItemNo);
                Sleep(10);
            end;
        end else
            Message('No se encontraron lineas pendientes de recepción del pedido %1', PurchHdr."No.");
        Sleep(10);
        if PurchLineAlternative.Count > 0 then
            InsertPurchOrderAlternative(Vend."No.", PurchHdr, PurchLineAlternative)
        else
            Message('Los productos pendientes no estan relacionado con el proveedor %1', Vend."No.");
        Progress.CLOSE();
    end;

    procedure InsertPurchOrderAlternative(VendorNo: Code[20]; PurchaseHeader: Record "Purchase Header"; PurchLineAlternative: Dictionary of [Code[20], Integer])
    var
        PurchHdr: Record "Purchase Header";
        PurchLn: Record "Purchase Line";
        PurchLnVal: Record "Purchase Line";
        PurchHdrVal: Record "Purchase Header";
        ItemNo: Code[20];
    begin
        /*
        PurchHdrVal.Reset();
        PurchHdrVal.SetRange("Document Type", PurchHdrVal."Document Type"::Order);
        PurchHdrVal.SetRange("Your Reference", PurchaseHeader."No.");
        if PurchHdrVal.FindFirst() then
            Error('Ya existe un pedido de compra alternativo para el proveedor %1 con el No. %2', VendorNo, PurchHdrVal."No.");
        */
        Sleep(100);

        PurchHdr.Reset();
        PurchHdr.Init();
        PurchHdr."Document Type" := PurchHdr."Document Type"::Order;
        PurchHdr.Validate("Buy-from Vendor No.", VendorNo);
        PurchHdr.InitInsert();
        if not PurchHdr.Insert() then begin
            Error('No se pudo insertar el pedido de compra alternativo para el proveedor %1', VendorNo);
        end;
        PurchHdr.Validate("Location Code", PurchaseHeader."Location Code");
        PurchHdr.Status := PurchHdr.Status::Open;
        PurchHdr."Your Reference" := PurchaseHeader."No.";
        PurchHdr.Modify();

        foreach ItemNo in PurchLineAlternative.Keys do begin
            PurchLn.Init();
            PurchLn."Document No." := PurchHdr."No.";
            PurchLn."Line No." := GetNextLineNo(PurchHdr);
            PurchLn.Validate("Document Type", PurchLn."Document Type"::Order);
            PurchLn.Validate("Type", PurchLn.Type::Item);
            PurchLn.Validate("No.", ItemNo);
            PurchLn.Validate(Quantity, Abs(PurchLineAlternative.Get(ItemNo)));
            PurchLnVal.Reset();
            PurchLnVal.SetRange("Document Type", PurchaseHeader."Document Type");
            PurchLnVal.SetRange("Document No.", PurchaseHeader."No.");
            PurchLnVal.SetRange("No.", ItemNo);
            if PurchLnVal.FindFirst() then begin
                PurchLn.Validate("Unit of Measure Code", PurchLnVal."Unit of Measure Code");
                PurchLn.Validate("Unit Cost", PurchLnVal."Unit Cost");
            end;
            PurchLn.Insert();
        end;
        PurchHdr.Status := PurchHdr.Status::Released;
        PurchHdr.Modify();
        Message('Pedido de compra alternativo creado para el Proveedor %1 con el No.  %2', VendorNo, PurchHdr."No.");
    end;

    procedure GetNextLineNo(PurchHeader: Record "Purchase Header") NextLineNo: Integer
    var
        PurchLine: Record "Purchase Line";
    begin
        NextLineNo := 0;
        PurchLine.Reset();
        PurchLine.SetRange("Document Type", PurchLine."Document Type"::Order);
        PurchLine.SetRange("Document No.", PurchHeader."No.");
        PurchLine.SetAscending("Line No.", true);
        if PurchLine.FindLast() then
            NextLineNo := PurchLine."Line No.";
        NextLineNo += 10000; // Incremento estándar
    end;

    local procedure OpenWindow()
    var
    begin
        Progress.Open(pWText000 + pWText001 + pWText002 + pWText003);
        if not WindowIsOpen then
            WindowIsOpen := true;
    end;

    local procedure UpdateWindow(VendorNo: Code[50]; NameVendor: Code[100]; NoOrder: Code[50]; ItemNo: Code[20])
    var
    begin
        if not WindowIsOpen then
            OpenWindow;
        Progress.update(1, VendorNo);
        Progress.update(2, NameVendor);
        Progress.update(3, NoOrder);
        Progress.update(4, ItemNo);
    end;

    [EventSubscriber(ObjectType::Page, Page::"Purchase Return Order List", 'OnOpenPageEvent', '', true, true)]
    local procedure "Purchase Return Order List_OnOpenPageEvent"(var Rec: Record "Purchase Header")
    var
        Existent: Boolean;
    begin
        if not SessionParametro() then
            exit;
        WarehouseEmployee.Reset();
        WarehouseEmployee.SetRange("User ID", USERID);
        if WarehouseEmployee.FindFirst() then
            IF WarehouseEmployee."Location Code" <> '' THEN begin//ok
                lOldFilterGroup := Rec.FilterGroup;
                Rec.FilterGroup(10);
                Rec.SetRange(rec."Location Code", WarehouseEmployee."Location Code");
                rec.FilterGroup(lOldFilterGroup);
            end;
    end;

    [EventSubscriber(ObjectType::Page, Page::"LSC Retail Purch.Ret.Order Lst", 'OnOpenPageEvent', '', true, true)]
    local procedure "LSC Retail Purch.Ret.Order Lst_OnOpenPageEvent"(var Rec: Record "Purchase Header")
    var
        Existent: Boolean;
    begin
        if not SessionParametro() then
            exit;
        WarehouseEmployee.Reset();
        WarehouseEmployee.SetRange("User ID", USERID);
        if WarehouseEmployee.FindFirst() then
            IF WarehouseEmployee."Location Code" <> '' THEN begin//ok
                lOldFilterGroup := Rec.FilterGroup;
                Rec.FilterGroup(10);
                Rec.SetRange(rec."Location Code", WarehouseEmployee."Location Code");
                rec.FilterGroup(lOldFilterGroup);
            end;
    end;

    [EventSubscriber(ObjectType::Page, Page::"LSC Stock Request List", 'OnOpenPageEvent', '', true, true)]
    local procedure "LSC Stock Request List_OnOpenPageEvent"(var Rec: Record "LSC InStore Stock Req. Header")
    var
        Existent: Boolean;
    begin
        if not SessionParametro() then
            exit;
        WarehouseEmployee.Reset();
        WarehouseEmployee.SetRange("User ID", USERID);
        if WarehouseEmployee.FindFirst() then
            IF WarehouseEmployee."Location Code" <> '' THEN begin//ok
                lOldFilterGroup := Rec.FilterGroup;
                Rec.FilterGroup(10);
                Rec.SetRange(Rec."Store No.", WarehouseEmployee."Location Code");
                rec.FilterGroup(lOldFilterGroup);
            end;
    end;

    [EventSubscriber(ObjectType::Page, Page::"LSC Retail Receiving List", 'OnOpenPageEvent', '', true, true)]
    local procedure "LSC Retail Receiving List_OnOpenPageEvent"(var Rec: Record "LSC P/R Counting Header")
    var
        Existent: Boolean;
    begin
        if not SessionParametro() then
            exit;
        WarehouseEmployee.Reset();
        WarehouseEmployee.SetRange("User ID", USERID);
        if WarehouseEmployee.FindFirst() then
            IF WarehouseEmployee."Location Code" <> '' THEN begin//ok
                lOldFilterGroup := Rec.FilterGroup;
                Rec.FilterGroup(10);
                Rec.SetRange(rec."Location Code", WarehouseEmployee."Location Code");
                rec.FilterGroup(lOldFilterGroup);
            end;
    end;

    [EventSubscriber(ObjectType::Page, Page::"LSC Transfer Requests", 'OnOpenPageEvent', '', true, true)]
    local procedure "LSC Transfer Requests_OnOpenPageEvent"(var Rec: Record "Transfer Header")
    var
        Existent: Boolean;
        lFilterFrom: Text;
        lFilterTo: Text;
        lOldFilterGroup: Integer;
    begin
        if not SessionParametro() then
            exit;
        WarehouseEmployee.Reset();
        WarehouseEmployee.SetRange("User ID", USERID);
        if WarehouseEmployee.FindFirst() then begin
            if WarehouseEmployee."Location Code" <> '' then begin
                Rec.SetRange("LSC Store-from");
                Rec.FilterGroup(10);
                Rec.SetCurrentKey("LSC Retail Status", "Transfer-from Code");////????
                Rec.SetRange("Transfer-to Code", WarehouseEmployee."Location Code");
                Rec.FilterGroup(lOldFilterGroup);
            end;
        end;
    end;

    /*[EventSubscriber(ObjectType::Page, Page::"LSC Transfers To Be Picked", 'OnOpenPageEvent', '', true, true)]
    local procedure "LSC Transfers To Be Picked_OnOpenPageEvent"(var Rec: Record "Transfer Header")
    begin
        if not SessionParametro() then
            exit;
        //Veryficar la posibilidad de filtrar por el usuario en dos campos
        WarehouseEmployee.Reset();
        WarehouseEmployee.SetRange("User ID", USERID);
        if WarehouseEmployee.FindFirst() then begin
            if WarehouseEmployee."Location Code" <> '' then begin
                Rec.SetRange("LSC Store-from");
                Rec.FilterGroup(10);
                Rec.SetCurrentKey("LSC Retail Status", "Transfer-from Code");
                Rec.SetRange("LSC Retail Status", Rec."LSC Retail Status"::Sent);///????
                Rec.SetRange("LSC Store-from", WarehouseEmployee."Location Code");
                Rec.FilterGroup(lOldFilterGroup); // Restaura el grupo de filtro
            end;
        end;
    end;*/

    [EventSubscriber(ObjectType::Page, Page::"Warehouse Receipts", 'OnOpenPageEvent', '', true, true)]
    local procedure "Warehouse Receipts_OnOpenPageEvent"(var Rec: Record "Warehouse Receipt Header")
    begin
        if not SessionParametro() then
            exit;
        WarehouseEmployee.Reset();
        WarehouseEmployee.SetRange("User ID", USERID);
        if WarehouseEmployee.FindFirst() then
            IF WarehouseEmployee."Location Code" <> '' THEN begin//ok
                lOldFilterGroup := Rec.FilterGroup;
                Rec.FilterGroup(10);
                Rec.SetRange(rec."Location Code", WarehouseEmployee."Location Code");
                rec.FilterGroup(lOldFilterGroup);
            end;
    end;

    [EventSubscriber(ObjectType::Page, Page::"Posted Transfer Receipts", 'OnOpenPageEvent', '', true, true)]
    local procedure "Posted Transfer Receipts_OnOpenPageEvent"(var Rec: Record "Transfer Receipt Header")
    begin
        if not SessionParametro() then
            exit;
        WarehouseEmployee.Reset();
        WarehouseEmployee.SetRange("User ID", USERID);
        if WarehouseEmployee.FindFirst() then begin
            if WarehouseEmployee."Location Code" <> '' then begin//ok
                Rec.SetRange("LSC Store-from");
                Rec.FilterGroup(11);
                Rec.SetCurrentKey("Transfer-from Code");
                Rec.SetRange("Transfer-to Code", WarehouseEmployee."Location Code");//????
                Rec.FilterGroup(lOldFilterGroup); // Restaura el grupo de filtro
            end;
        end;
    end;

    [EventSubscriber(ObjectType::Page, Page::"Posted Purchase Receipts", 'OnOpenPageEvent', '', true, true)]
    local procedure "Posted Purchase Receipts_OnOpenPageEvent"(var Rec: Record "Purch. Rcpt. Header")
    begin
        if not SessionParametro() then
            exit;
        WarehouseEmployee.Reset();
        WarehouseEmployee.SetRange("User ID", USERID);
        WarehouseEmployee.SetFilter("Location Code", '<>%1', '');
        if WarehouseEmployee.FindFirst() then//ok
            IF WarehouseEmployee."Location Code" <> '' THEN begin
                lOldFilterGroup := Rec.FilterGroup;
                Rec.FilterGroup(10);
                Rec.SetRange(rec."Location Code", WarehouseEmployee."Location Code");
                rec.FilterGroup(lOldFilterGroup);
            end;
    end;

    [EventSubscriber(ObjectType::Page, Page::"Posted Return Shipments", 'OnOpenPageEvent', '', true, true)]
    local procedure "Posted Return Shipments_OnOpenPageEvent"(var Rec: Record "Return Shipment Header")
    begin
        if not SessionParametro() then
            exit;
        WarehouseEmployee.Reset();
        WarehouseEmployee.SetRange("User ID", USERID);
        WarehouseEmployee.SetFilter("Location Code", '<>%1', '');
        if WarehouseEmployee.FindFirst() then
            IF WarehouseEmployee."Location Code" <> '' THEN begin//ok
                lOldFilterGroup := Rec.FilterGroup;
                Rec.FilterGroup(10);
                Rec.SetRange(rec."Location Code", WarehouseEmployee."Location Code");
                rec.FilterGroup(lOldFilterGroup);
            end;
    end;

    [EventSubscriber(ObjectType::Page, Page::"Posted Purchase Invoices", 'OnOpenPageEvent', '', true, true)]
    local procedure "Posted Purchase Invoices_OnOpenPageEvent"(var Rec: Record "Purch. Inv. Header")
    begin
        if not SessionParametro() then
            exit;
        WarehouseEmployee.Reset();
        WarehouseEmployee.SetRange("User ID", USERID);
        WarehouseEmployee.SetFilter("Location Code", '<>%1', '');
        if WarehouseEmployee.FindFirst() then
            IF WarehouseEmployee."Location Code" <> '' THEN begin
                lOldFilterGroup := Rec.FilterGroup;//ok
                Rec.FilterGroup(10);
                Rec.SetRange(rec."Location Code", WarehouseEmployee."Location Code");
                rec.FilterGroup(lOldFilterGroup);
            end;
    end;

    [EventSubscriber(ObjectType::Page, Page::"Posted Purchase Credit Memos", 'OnOpenPageEvent', '', true, true)]
    local procedure "Posted Purchase Credit Memos_OnOpenPageEvent"(var Rec: Record "Purch. Cr. Memo Hdr.")
    begin
        if not SessionParametro() then
            exit;
        WarehouseEmployee.Reset();
        WarehouseEmployee.SetRange("User ID", USERID);
        WarehouseEmployee.SetFilter("Location Code", '<>%1', '');
        if WarehouseEmployee.FindFirst() then
            IF WarehouseEmployee."Location Code" <> '' THEN begin//ok
                lOldFilterGroup := Rec.FilterGroup;
                Rec.FilterGroup(10);
                Rec.SetRange(rec."Location Code", WarehouseEmployee."Location Code");
                rec.FilterGroup(lOldFilterGroup);
            end;
    end;

    [EventSubscriber(ObjectType::Page, Page::"Posted Assembly Orders", 'OnOpenPageEvent', '', true, true)]
    local procedure "Posted Assembly Orders_OnOpenPageEvent"(var Rec: Record "Posted Assembly Header")
    begin
        if not SessionParametro() then
            exit;
        WarehouseEmployee.Reset();
        WarehouseEmployee.SetRange("User ID", USERID);
        WarehouseEmployee.SetFilter("Location Code", '<>%1', '');
        if WarehouseEmployee.FindFirst() then
            IF WarehouseEmployee."Location Code" <> '' THEN begin
                lOldFilterGroup := Rec.FilterGroup;
                Rec.FilterGroup(10);
                Rec.SetRange(rec."Location Code", WarehouseEmployee."Location Code");//OK
                rec.FilterGroup(lOldFilterGroup);
            end;
    end;

    [EventSubscriber(ObjectType::Page, Page::"Sales Invoice List", 'OnOpenPageEvent', '', true, true)]
    local procedure "Sales Invoice List_OnOpenPageEvent"(var Rec: Record "Sales Header")
    begin
        if not SessionParametro() then
            exit;
        WarehouseEmployee.Reset();
        WarehouseEmployee.SetRange("User ID", USERID);
        WarehouseEmployee.SetFilter("Location Code", '<>%1', '');
        if WarehouseEmployee.FindFirst() then
            IF WarehouseEmployee."Location Code" <> '' THEN begin
                lOldFilterGroup := Rec.FilterGroup;
                Rec.FilterGroup(10);
                Rec.SetRange("Package Tracking No.", WarehouseEmployee."Location Code");
                Rec.SetRange(rec."Location Code", 'F01');//OK
                rec.FilterGroup(lOldFilterGroup);
            end;
        POSSESION.SetValue('F-VENTA', USERID);
    end;

    [EventSubscriber(ObjectType::Page, Page::"Sales Invoice List", 'OnClosePageEvent', '', true, true)]
    local procedure "Sales Invoice List_OnClosePageEvent"(var Rec: Record "Sales Header")
    begin
        POSSESION.SetValue('F-VENTA', '');
    end;

    [EventSubscriber(ObjectType::Page, Page::"Sales Invoice", 'OnInsertRecordEvent', '', true, true)]
    local procedure "Sales Invoice_OnInsertRecordEvent"
    (
        var Rec: Record "Sales Header";
        var xRec: Record "Sales Header";
        var AllowInsert: Boolean;
        BelowxRec: Boolean
    )
    begin
        if not SessionParametro() then
            exit;
        WarehouseEmployee.Reset();
        WarehouseEmployee.SetRange("User ID", USERID);
        WarehouseEmployee.SetFilter("Location Code", '<>%1', '');
        if WarehouseEmployee.FindFirst() then
            IF WarehouseEmployee."Location Code" <> '' THEN begin
                Rec.Validate("Location Code", 'F01');
                Rec."Package Tracking No." := WarehouseEmployee."Location Code";
            end;
    end;

    [EventSubscriber(ObjectType::Page, Page::"Sales Invoice", 'OnNewRecordEvent', '', true, true)]
    local procedure "Sales Invoice_OnNewRecordEvent"
    (
        var Rec: Record "Sales Header";
        BelowxRec: Boolean
    )
    begin
        if not SessionParametro() then
            exit;
        WarehouseEmployee.Reset();
        WarehouseEmployee.SetRange("User ID", USERID);
        WarehouseEmployee.SetFilter("Location Code", '<>%1', '');
        if WarehouseEmployee.FindFirst() then
            IF WarehouseEmployee."Location Code" <> '' THEN begin
                Rec.Validate("Location Code", 'F01');
                Rec."Package Tracking No." := WarehouseEmployee."Location Code";
            end;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Sales Header", 'OnBeforeValidateEvent', 'Location Code', true, true)]
    local procedure "Sales Header_OnBeforeValidateEvent_Location Code"
    (
        var Rec: Record "Sales Header";
        var xRec: Record "Sales Header";
        CurrFieldNo: Integer
    )
    begin
        if not SessionParametro() then
            exit;
        WarehouseEmployee.Reset();
        WarehouseEmployee.SetRange("User ID", USERID);
        WarehouseEmployee.SetFilter("Location Code", '<>%1', '');
        if WarehouseEmployee.FindFirst() then
            IF WarehouseEmployee."Location Code" <> '' THEN begin
                Rec."Location Code" := 'F01';
                Rec."Package Tracking No." := WarehouseEmployee."Location Code";
                Rec."LSC Store No." := 'F01';
                xRec."Location Code" := 'F01';
                xRec."Package Tracking No." := WarehouseEmployee."Location Code";
                xRec."LSC Store No." := 'F01';
            end;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Sales Header", 'OnBeforeInitInsert', '', true, true)]
    local procedure "Sales Header_OnBeforeInitInsert"
    (
        var SalesHeader: Record "Sales Header";
        xSalesHeader: Record "Sales Header";
        var IsHandled: Boolean
    )
    begin
        if not SessionParametro() then
            exit;
        WarehouseEmployee.Reset();
        WarehouseEmployee.SetRange("User ID", USERID);
        WarehouseEmployee.SetFilter("Location Code", '<>%1', '');
        if WarehouseEmployee.FindFirst() then
            IF WarehouseEmployee."Location Code" <> '' THEN begin
                SalesHeader.Validate("Location Code", 'F01');
                SalesHeader.Validate("LSC Store No.", 'F01');
                SalesHeader."Package Tracking No." := WarehouseEmployee."Location Code";
            end;
    end;

    [EventSubscriber(ObjectType::Page, Page::"Sales Invoice", 'OnModifyRecordEvent', '', true, true)]
    local procedure "Sales Invoice_OnModifyRecordEvent"
    (
        var Rec: Record "Sales Header";
        var xRec: Record "Sales Header";
        var AllowModify: Boolean
    )
    begin
        if not SessionParametro() then
            exit;
        WarehouseEmployee.Reset();
        WarehouseEmployee.SetRange("User ID", USERID);
        WarehouseEmployee.SetFilter("Location Code", '<>%1', '');
        if WarehouseEmployee.FindFirst() then
            IF WarehouseEmployee."Location Code" <> '' THEN begin
                if Rec."Location Code" <> 'F01' then begin
                    Rec.Validate("Location Code", 'F01');
                    Rec."Package Tracking No." := WarehouseEmployee."Location Code";
                end;
            end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Reference Management", 'OnSalesReferenceNoLookupOnAfterSetFilters', '', true, true)]
    local procedure "Item Reference Management_OnSalesReferenceNoLookupOnAfterSetFilters"
    (
        var ItemReference: Record "Item Reference";
        SalesLine: Record "Sales Line"
    )
    var
        Item: Record Item;
    begin
        if not SessionParametro() then
            exit;
        WarehouseEmployee.Reset();
        WarehouseEmployee.SetRange("User ID", USERID);
        WarehouseEmployee.SetFilter("Location Code", '<>%1', '');
        if WarehouseEmployee.FindFirst() then
            IF WarehouseEmployee."Location Code" <> '' THEN begin
                if (SalesLine."Location Code" = 'F01') and (SalesLine."Package Tracking No." = WarehouseEmployee."Location Code") then begin
                    Item.Reset();
                    Item.SetRange("LSC Division Code", '06');
                end;
            end;
    end;

    [EventSubscriber(ObjectType::Page, Page::"LSC Retail P. Sales Invoices", 'OnOpenPageEvent', '', true, true)]
    local procedure "LSC Retail P. Sales Invoices_OnOpenPageEvent"(var Rec: Record "Sales Invoice Header")
    begin
        if not SessionParametro() then
            exit;
        WarehouseEmployee.Reset();
        WarehouseEmployee.SetRange("User ID", USERID);
        WarehouseEmployee.SetFilter("Location Code", '<>%1', '');
        if WarehouseEmployee.FindFirst() then
            IF WarehouseEmployee."Location Code" <> '' THEN begin
                Rec.Validate("Location Code", 'F01');
                Rec."Package Tracking No." := WarehouseEmployee."Location Code";
            end;
    end;

    [EventSubscriber(ObjectType::Page, Page::"Item Lookup", 'OnAfterGetRecordEvent', '', true, true)]
    local procedure "Item Lookup_OnAfterGetRecordEvent"(var Rec: Record "Item")
    begin
        if not SessionParametro() then
            exit;
        IF POSSESION.GetValue('F-VENTA') <> '' THEN begin
            WarehouseEmployee.Reset();
            WarehouseEmployee.SetRange("User ID", POSSESION.GetValue('F-VENTA'));
            if WarehouseEmployee.FindFirst() then
                IF WarehouseEmployee."Location Code" <> '' THEN begin
                    Rec.SetRange("LSC Division Code", '06');
                end;
        end;
    end;

    procedure SessionParametro(): Boolean
    var
        valor: Text;
        usuario: Text;
        Inuser: Integer;
        p: Page 99009501;
    begin
        //Inuser := StrLen(UserId);
        Inuser := StrLen(UserId);
        if Inuser > 20 then
            usuario := CopyStr(UserId, 8)
        else
            usuario := UserId;
        exit((Parameter.Get('SESSIONR', usuario)) AND (Parameter.Activo));
    end;


    // Code editado DTE abreviado LN 

    [EventSubscriber(ObjectType::Table, Database::"Purchase Header", 'OnBeforeInsertEvent', '', true, true)]
    local procedure PurchaseHeader_OnBeforeInsertEvent(var Rec: Record "Purchase Header"; RunTrigger: Boolean)
    begin
        EnsureUniqueVendorInvoiceNo(Rec);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Purchase Header", 'OnBeforeModifyEvent', '', true, true)]
    local procedure PurchaseHeader_OnBeforeModifyEvent(var Rec: Record "Purchase Header"; var xRec: Record "Purchase Header"; RunTrigger: Boolean)
    begin
        if (Rec."Vendor Invoice No." <> xRec."Vendor Invoice No.") or
           (Rec."Buy-from Vendor No." <> xRec."Buy-from Vendor No.") or
           (Rec."Pay-to Vendor No." <> xRec."Pay-to Vendor No.") then
            EnsureUniqueVendorInvoiceNo(Rec);
    end;

    local procedure EnsureUniqueVendorInvoiceNo(var PurchHdr: Record "Purchase Header")
    var
        PH: Record "Purchase Header";
        PurchInvHeader: Record "Purch. Inv. Header";
        Candidate: Text[35];
        BaseNo: Text[35];
        Iter: Integer;
        MaxLen: Integer;
        PayToVendor: Code[20];
        Suffix: Text[10];
        Avail: Integer;
    begin
        if InAdjustVendorInvoiceNo then
            exit;

        BaseNo := Format(PurchHdr."Vendor Invoice No.");
        if BaseNo = '' then
            exit;

        InAdjustVendorInvoiceNo := true;
        MaxLen := 35;
        PayToVendor := PurchHdr."Pay-to Vendor No.";
        if PayToVendor = '' then
            PayToVendor := PurchHdr."Buy-from Vendor No.";

        Candidate := CopyStr(BaseNo, 1, MaxLen);
        Iter := 0;

        PH.Reset();
        PH.SetRange("Buy-from Vendor No.", PurchHdr."Buy-from Vendor No.");
        PH.SetRange("Document Type", PurchHdr."Document Type");
        PH.SetFilter("No.", '<>%1', PurchHdr."No.");

        repeat
            PH.SetRange("Vendor Invoice No.", Candidate);
            if not PH.FindFirst() then begin
                PurchInvHeader.Reset();
                PurchInvHeader.SetRange("Pay-to Vendor No.", PayToVendor);
                PurchInvHeader.SetRange("Vendor Invoice No.", Candidate);
                if not PurchInvHeader.FindFirst() then
                    break;
            end;

            if StrLen(Candidate) < MaxLen then
                Candidate := CopyStr(Candidate + '.', 1, MaxLen)
            else begin
                Suffix := '.' + Format(Iter + 1);
                Avail := MaxLen - StrLen(Suffix);
                if Avail < 1 then
                    Avail := 1;
                Candidate := CopyStr(BaseNo, 1, Avail) + CopyStr(Suffix, 1, MaxLen - Avail);
            end;
            Iter += 1;
        until Iter > 50;

        if PurchHdr."Vendor Invoice No." <> Candidate then
            PurchHdr.Validate("Vendor Invoice No.", Candidate);

        InAdjustVendorInvoiceNo := false;
    end;

    //----------------------------------------------------------------------------------------------------------------------------------------------------------------------------

    // Al copiar líneas hacia una devolución, asegura un solo HRC y guarda el Order No. en Nº pedido proveedor.

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Copy Document Mgt.", 'OnAfterCopyPurchaseLinesToDoc', '', false, false)]
    local procedure OnAfterCopyPurchaseLinesToDoc(FromDocType: Option; var ToPurchaseHeader: Record "Purchase Header"; var FromPurchRcptLine: Record "Purch. Rcpt. Line"; var FromPurchInvLine: Record "Purch. Inv. Line"; var FromReturnShipmentLine: Record "Return Shipment Line"; var FromPurchCrMemoLine: Record "Purch. Cr. Memo Line"; var LinesNotCopied: Integer; var MissingExCostRevLink: Boolean; RecalculateLines: Boolean; IncludeHeader: Boolean)
    begin
        if ToPurchaseHeader."Document Type" <> ToPurchaseHeader."Document Type"::"Return Order" then
            exit;

        EnsureSingleReceiptHeader(ToPurchaseHeader);
        CleanInvoiceHeadersAfterItems(ToPurchaseHeader);

        // Tomar el Order No. del histórico (Purch. Rcpt. Line) y guardarlo en "Vendor Order No." cuando aplica.
        if (FromPurchRcptLine."Order No." <> '') and (ToPurchaseHeader."Vendor Order No." = '') then begin
            ToPurchaseHeader.Validate("Vendor Order No.", FromPurchRcptLine."Order No.");
            ToPurchaseHeader.Modify(true);
        end;
    end;

    // Antes de insertar línea en devolución, valida duplicados de HRC y único Receipt No.
    [EventSubscriber(ObjectType::Table, Database::"Purchase Line", 'OnBeforeInsertEvent', '', false, false)]
    local procedure OnBeforeInsertPurchaseLine(var Rec: Record "Purchase Line"; RunTrigger: Boolean)
    begin
        if Rec."Document Type" <> Rec."Document Type"::"Return Order" then
            exit;

        EnsureNoDuplicateReceiptHeader(Rec);
        ValidateSingleReceiptPerReturnOrder(Rec);
    end;

    // Antes de modificar línea en devolución, repite las validaciones de HRC y Receipt No.
    [EventSubscriber(ObjectType::Table, Database::"Purchase Line", 'OnBeforeModifyEvent', '', false, false)]
    local procedure OnBeforeModifyPurchaseLine(var Rec: Record "Purchase Line"; var xRec: Record "Purchase Line"; RunTrigger: Boolean)
    begin
        if Rec."Document Type" <> Rec."Document Type"::"Return Order" then
            exit;

        EnsureNoDuplicateReceiptHeader(Rec);
        ValidateSingleReceiptPerReturnOrder(Rec);
    end;

    // Garantiza que solo exista un encabezado de recepción (HRC) y elimina duplicados del mismo código.
    local procedure EnsureSingleReceiptHeader(var ToPurchaseHeader: Record "Purchase Header")
    var
        PurchLine: Record "Purchase Line";
        HeaderCategory: Option Unknown,Receipt,ReturnReceipt,Invoice,CreditNote;
        BaseReceiptCode: Text;
        DuplicateHeaders: List of [Integer];
        LineToDelete: Integer;
    begin
        PurchLine.Reset();
        PurchLine.SetCurrentKey("Document Type", "Document No.", "Line No.");
        PurchLine.SetRange("Document Type", ToPurchaseHeader."Document Type");
        PurchLine.SetRange("Document No.", ToPurchaseHeader."No.");

        if not PurchLine.FindFirst() then
            exit;

        HeaderCategory := GetHeaderCategory(PurchLine);

        // Facturas, recep. devolución y notas de crédito se insertan sin validación adicional.
        if IsHeaderExemptFromValidation(HeaderCategory) then
            exit;

        // Solo validamos cuando el encabezado corresponde a una recepción copiada.
        if HeaderCategory <> HeaderCategory::Receipt then
            exit;

        if not IsReceiptHeaderLine(PurchLine) then
            Error('La primera línea debe ser el histórico de recepción (Nº recepción ...). Copie nuevamente las líneas de recepción.');

        BaseReceiptCode := ExtractReceiptCodeFromHeader(PurchLine);

        while PurchLine.Next() <> 0 do begin
            if IsReceiptHeaderLine(PurchLine) then begin
                if ExtractReceiptCodeFromHeader(PurchLine) = BaseReceiptCode then
                    DuplicateHeaders.Add(PurchLine."Line No.")
                else
                    Error('Solo se permite un histórico de recepción por devolución. Elimine líneas de recepción adicionales y vuelva a copiar.');
            end;
        end;

        if DuplicateHeaders.Count > 0 then begin
            PurchLine.Reset();
            PurchLine.SetRange("Document Type", ToPurchaseHeader."Document Type");
            PurchLine.SetRange("Document No.", ToPurchaseHeader."No.");
            foreach LineToDelete in DuplicateHeaders do begin
                if PurchLine.Get(ToPurchaseHeader."Document Type", ToPurchaseHeader."No.", LineToDelete) then
                    PurchLine.Delete(true);
            end;
        end;
    end;

    // Detecta si una línea es el encabezado de recepción según formato de descripción y campos vacíos.
    local procedure IsReceiptHeaderLine(PurchLine: Record "Purchase Line"): Boolean
    var
        DescUpper: Text;
        PosRecep: Integer;
        CleanDesc: Text;
    begin
        if not IsHeaderLineCandidate(PurchLine) then
            exit(false);

        DescUpper := UpperCase(PurchLine.Description);
        CleanDesc := DelChr(DescUpper, '<', ' ');
        PosRecep := StrPos(CleanDesc, 'RECEPC');

        exit((CleanDesc <> '') and (PosRecep = 4));
    end;

    // Revisa si la línea cumple condiciones de “encabezado” (sin artículo, sin cantidades, sin montos).
    local procedure IsHeaderLineCandidate(PurchLine: Record "Purchase Line"): Boolean
    begin
        if PurchLine."No." <> '' then
            exit(false);
        if PurchLine.Type <> PurchLine.Type::" " then
            exit(false);

        if (PurchLine.Quantity <> 0) or (PurchLine."Line Amount" <> 0) or (PurchLine."Direct Unit Cost" <> 0) or (PurchLine."Unit Cost" <> 0) then
            exit(false);

        if (PurchLine."Location Code" <> '') or (PurchLine."Unit of Measure Code" <> '') then
            exit(false);

        if PurchLine."Receipt No." <> '' then
            exit(false);

        exit(true);
    end;

    // Extrae el código de recepción (HRC) desde la descripción del encabezado.
    local procedure ExtractReceiptCodeFromHeader(PurchLine: Record "Purchase Line"): Text
    var
        CleanDesc: Text;
        PosReceipt: Integer;
        TextAfterReceipt: Text;
        FirstSpace: Integer;
        ReceiptCode: Text;
        LenClean: Integer;
    begin
        CleanDesc := UpperCase(DelChr(PurchLine.Description, '<', ' '));
        CleanDesc := ConvertStr(CleanDesc, ':', ' ');

        PosReceipt := StrPos(CleanDesc, 'RECEP');
        if PosReceipt = 0 then
            exit('');

        LenClean := StrLen(CleanDesc);
        TextAfterReceipt := CopyStr(CleanDesc, PosReceipt, LenClean - PosReceipt + 1);
        FirstSpace := StrPos(TextAfterReceipt, ' ');
        if FirstSpace = 0 then
            exit('');

        ReceiptCode := CopyStr(TextAfterReceipt, FirstSpace + 1, StrLen(TextAfterReceipt) - FirstSpace);

        FirstSpace := StrPos(ReceiptCode, ' ');
        if FirstSpace > 0 then
            ReceiptCode := CopyStr(ReceiptCode, 1, FirstSpace - 1);

        exit(ReceiptCode);
    end;

    // Clasifica el encabezado: recepción, recep. devolución, factura o nota de crédito según descripción.
    local procedure GetHeaderCategory(PurchLine: Record "Purchase Line"): Option Unknown,Receipt,ReturnReceipt,Invoice,CreditNote
    var
        CleanDesc: Text;
        HeaderType: Option Unknown,Receipt,ReturnReceipt,Invoice,CreditNote;
    begin
        if not IsHeaderLineCandidate(PurchLine) then
            exit(HeaderType::Unknown);

        CleanDesc := UpperCase(DelChr(PurchLine.Description, '<', ' '));

        if StrPos(CleanDesc, 'Nº RECEP. DEVOL') = 1 then
            exit(HeaderType::ReturnReceipt);

        if StrPos(CleanDesc, 'Nº RECEPC') = 1 then
            exit(HeaderType::Receipt);

        if (StrPos(CleanDesc, 'Nº FACTURA') = 1) or (StrPos(CleanDesc, 'Nº FAC.') = 1) then
            exit(HeaderType::Invoice);

        if StrPos(CleanDesc, 'Nº NOTA CREDITO') = 1 then
            exit(HeaderType::CreditNote);

        exit(HeaderType::Unknown);
    end;

    // Indica si el encabezado es factura/devolución/NC y por tanto se omite la validación de HRC.
    local procedure IsHeaderExemptFromValidation(HeaderCategory: Option Unknown,Receipt,ReturnReceipt,Invoice,CreditNote): Boolean
    begin
        exit((HeaderCategory = HeaderCategory::Invoice) or
             (HeaderCategory = HeaderCategory::ReturnReceipt) or
             (HeaderCategory = HeaderCategory::CreditNote));
    end;

    // Impide agregar otro encabezado distinto al HRC existente y valida que el código coincida.
    local procedure EnsureNoDuplicateReceiptHeader(var PurchaseLine: Record "Purchase Line")
    var
        ExistingLine: Record "Purchase Line";
        BaseCode: Text;
        ExistingCode: Text;
        ExistingReceiptCode: Text;
        ExistingCategory: Option Unknown,Receipt,ReturnReceipt,Invoice,CreditNote;
        NewCategory: Option Unknown,Receipt,ReturnReceipt,Invoice,CreditNote;
    begin
        // Solo aplica a líneas de encabezado (sin número, sin qty, etc.).
        if not IsHeaderLineCandidate(PurchaseLine) then
            exit;

        // Si es la primera línea del documento (no hay nada insertado aún), no validar mezcla ni HRC.
        if not DocumentHasAnyLine(PurchaseLine."Document Type", PurchaseLine."Document No.") then
            exit;

        ExistingCategory := GetExistingHeaderCategory(PurchaseLine."Document Type", PurchaseLine."Document No.");
        NewCategory := GetHeaderCategory(PurchaseLine);

        // Si ya existe un encabezado, solo se permite insertar otro del mismo tipo (Factura/Recep.Dev/NC/HRC).
        if (ExistingCategory <> ExistingCategory::Unknown) and (NewCategory <> ExistingCategory) then
            Error('No se pueden combinar tipos de documentos');

        // Si ya existe un HRC, no permitir ningún otro encabezado distinto a recepción del mismo HRC.
        ExistingReceiptCode := GetExistingReceiptCode(PurchaseLine."Document Type", PurchaseLine."Document No.");
        if ExistingReceiptCode <> '' then begin
            if not IsReceiptHeaderLine(PurchaseLine) then
                Error('Ya existe el histórico de recepción %1. No se permiten otros encabezados.', ExistingReceiptCode);
            BaseCode := ExtractReceiptCodeFromHeader(PurchaseLine);
            if (BaseCode <> '') and (BaseCode <> ExistingReceiptCode) then
                Error('Solo se permite un histórico de recepción por devolución');
        end;

        if not IsReceiptHeaderLine(PurchaseLine) then
            exit;

        BaseCode := ExtractReceiptCodeFromHeader(PurchaseLine);

        ExistingLine.Reset();
        ExistingLine.SetRange("Document Type", PurchaseLine."Document Type");
        ExistingLine.SetRange("Document No.", PurchaseLine."Document No.");
        ExistingLine.SetFilter("Line No.", '<>%1', PurchaseLine."Line No.");

        if ExistingLine.FindSet() then
            repeat
                if IsReceiptHeaderLine(ExistingLine) then begin
                    ExistingCode := ExtractReceiptCodeFromHeader(ExistingLine);
                    if ExistingCode <> BaseCode then
                        Error('Solo se permite un histórico de recepción por devolución. Elimine líneas de recepción adicionales y vuelva a copiar.');
                end;
            until ExistingLine.Next() = 0;
    end;

    // Devuelve el código de HRC ya presente en el documento (si existe).
    local procedure GetExistingReceiptCode(DocType: Enum "Purchase Document Type"; DocNo: Code[20]): Text
    var
        PL: Record "Purchase Line";
    begin
        PL.Reset();
        PL.SetCurrentKey("Document Type", "Document No.", "Line No.");
        PL.SetRange("Document Type", DocType);
        PL.SetRange("Document No.", DocNo);
        if PL.FindFirst() then
            repeat
                if IsReceiptHeaderLine(PL) then
                    exit(ExtractReceiptCodeFromHeader(PL));
            until PL.Next() = 0;

        exit('');
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Purch.-Post", 'OnBeforeReturnShptHeaderInsert', '', false, false)]
    local procedure PurchPost_OnBeforeReturnShptHeaderInsert(var ReturnShptHeader: Record "Return Shipment Header"; PurchHeader: Record "Purchase Header")
    begin
        if PurchHeader."Document Type" <> PurchHeader."Document Type"::"Return Order" then
            exit;

        if PurchHeader."Vendor Order No." <> '' then
            ReturnShptHeader.Validate("FSNVendor Order No.", PurchHeader."Vendor Order No.");
    end;

    [EventSubscriber(ObjectType::Table, Database::"Return Shipment Line", 'OnBeforeInsertEvent', '', false, false)]
    local procedure ReturnShipmentLine_OnBeforeInsert(var Rec: Record "Return Shipment Line"; RunTrigger: Boolean)
    var
        ReturnShptHeader: Record "Return Shipment Header";
    begin
        if Rec."Vendor Order No." <> '' then
            exit;
        if Rec."Document No." = '' then
            exit;

        if ReturnShptHeader.Get(Rec."Document No.") then
            if ReturnShptHeader."FSNVendor Order No." <> '' then
                Rec."Vendor Order No." := ReturnShptHeader."FSNVendor Order No.";
    end;

    // Devuelve la categoría del primer encabezado existente en el documento (si hay).
    local procedure GetExistingHeaderCategory(DocType: Enum "Purchase Document Type"; DocNo: Code[20]): Option Unknown,Receipt,ReturnReceipt,Invoice,CreditNote
    var
        PL: Record "Purchase Line";
        Cat: Option Unknown,Receipt,ReturnReceipt,Invoice,CreditNote;
    begin
        PL.Reset();
        PL.SetCurrentKey("Document Type", "Document No.", "Line No.");
        PL.SetRange("Document Type", DocType);
        PL.SetRange("Document No.", DocNo);
        if PL.FindFirst() then
            repeat
                if IsHeaderLineCandidate(PL) then
                    exit(GetHeaderCategory(PL));
            until PL.Next() = 0;

        exit(Cat::Unknown);
    end;

    // Texto amigable para el tipo de encabezado.
    local procedure CategoryToText(Category: Option Unknown,Receipt,ReturnReceipt,Invoice,CreditNote): Text
    begin
        case Category of
            Category::Receipt:
                exit('Recepción');
            Category::ReturnReceipt:
                exit('Recepción devolución');
            Category::Invoice:
                exit('Factura');
            Category::CreditNote:
                exit('Nota de crédito');
        end;

        exit('Desconocido');
    end;

    // Indica si el documento ya tiene alguna línea guardada.
    local procedure DocumentHasAnyLine(DocType: Enum "Purchase Document Type"; DocNo: Code[20]): Boolean
    var
        PL: Record "Purchase Line";
    begin
        PL.SetRange("Document Type", DocType);
        PL.SetRange("Document No.", DocNo);
        exit(PL.FindFirst());
    end;

    // Elimina encabezados de factura duplicados que queden después de haber insertado líneas de artículos.
    // Si la segunda factura tiene un número distinto a la ya insertada, se bloquea con error.
    local procedure CleanInvoiceHeadersAfterItems(var ToPurchaseHeader: Record "Purchase Header")
    var
        PL: Record "Purchase Line";
        LinesToDelete: List of [Integer];
        LineNoToDelete: Integer;
        ItemsSeen: Boolean;
        Cat: Option Unknown,Receipt,ReturnReceipt,Invoice,CreditNote;
        FirstInvoiceCode: Text;
        NewInvoiceCode: Text;
    begin
        PL.Reset();
        PL.SetCurrentKey("Document Type", "Document No.", "Line No.");
        PL.SetRange("Document Type", ToPurchaseHeader."Document Type");
        PL.SetRange("Document No.", ToPurchaseHeader."No.");

        if not PL.FindFirst() then
            exit;

        ItemsSeen := false;
        FirstInvoiceCode := '';

        repeat
            if IsHeaderLineCandidate(PL) then begin
                Cat := GetHeaderCategory(PL);
                if Cat = Cat::Invoice then begin
                    if FirstInvoiceCode = '' then
                        FirstInvoiceCode := ExtractInvoiceCodeFromHeader(PL);

                    if ItemsSeen then begin
                        NewInvoiceCode := ExtractInvoiceCodeFromHeader(PL);
                        if (FirstInvoiceCode <> '') and (NewInvoiceCode <> '') and (NewInvoiceCode <> FirstInvoiceCode) then
                            Error('No se puede copiar una factura distinta (%1). Ya existe la factura %2 en la devolución.', NewInvoiceCode, FirstInvoiceCode);

                        LinesToDelete.Add(PL."Line No.");
                    end;
                end;
            end else
                ItemsSeen := true;
        until PL.Next() = 0;

        if LinesToDelete.Count > 0 then begin
            PL.Reset();
            PL.SetRange("Document Type", ToPurchaseHeader."Document Type");
            PL.SetRange("Document No.", ToPurchaseHeader."No.");
            foreach LineNoToDelete in LinesToDelete do begin
                if PL.Get(ToPurchaseHeader."Document Type", ToPurchaseHeader."No.", LineNoToDelete) then
                    PL.Delete(true);
            end;
        end;
    end;

    // Extrae el número de factura desde el encabezado de factura (Descripción empieza con "Nº FACTURA" o "Nº FAC.").
    local procedure ExtractInvoiceCodeFromHeader(PurchLine: Record "Purchase Line"): Text
    var
        Desc: Text;
        DescUpper: Text;
        PrefixLen: Integer;
        HeaderType: Option Unknown,Receipt,ReturnReceipt,Invoice,CreditNote;
        Tail: Text;
        SepPosSpace: Integer;
        SepPosDash: Integer;
        SepPosColon: Integer;
        CutPos: Integer;
    begin
        if GetHeaderCategory(PurchLine) <> HeaderType::Invoice then
            exit('');

        Desc := DelChr(PurchLine.Description, '<', ' ');
        DescUpper := UpperCase(Desc);

        if StrPos(DescUpper, 'Nº FACTURA') = 1 then
            PrefixLen := StrLen('Nº FACTURA')
        else
            if StrPos(DescUpper, 'Nº FAC.') = 1 then
                PrefixLen := StrLen('Nº FAC.')
            else
                exit('');

        Tail := CopyStr(Desc, PrefixLen + 1);
        Tail := DelChr(Tail, '<', ' ');
        Tail := DelChr(Tail, '>', ' ');

        SepPosSpace := StrPos(Tail, ' ');
        SepPosDash := StrPos(Tail, '-');
        SepPosColon := StrPos(Tail, ':');

        CutPos := 0;
        if (SepPosSpace > 0) then
            CutPos := SepPosSpace;
        if (SepPosDash > 0) and ((CutPos = 0) or (SepPosDash < CutPos)) then
            CutPos := SepPosDash;
        if (SepPosColon > 0) and ((CutPos = 0) or (SepPosColon < CutPos)) then
            CutPos := SepPosColon;

        if CutPos > 0 then
            exit(CopyStr(Tail, 1, CutPos - 1));

        exit(Tail);
    end;

    // Asegura que todas las líneas con Receipt No. usen el mismo número dentro de la devolución.
    local procedure ValidateSingleReceiptPerReturnOrder(var PurchaseLine: Record "Purchase Line")
    var
        ExistingLine: Record "Purchase Line";
        ExistingReceiptNo: Code[20];
    begin
        if PurchaseLine."Receipt No." = '' then
            exit;

        ExistingLine.Reset();
        ExistingLine.SetRange("Document Type", PurchaseLine."Document Type");
        ExistingLine.SetRange("Document No.", PurchaseLine."Document No.");
        ExistingLine.SetFilter("Line No.", '<>%1', PurchaseLine."Line No.");
        ExistingLine.SetFilter("Receipt No.", '<>%1', '');

        if ExistingLine.FindFirst() then begin
            ExistingReceiptNo := ExistingLine."Receipt No.";
            if ExistingReceiptNo <> PurchaseLine."Receipt No." then
                Error('Solo se permite asociar una recepción por devolución. Ya existe la recepción %1.', ExistingReceiptNo);
        end;
    end;
}

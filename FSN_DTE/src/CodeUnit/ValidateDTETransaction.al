codeunit 50051 "DTE Validate Transaction"
{
    trigger OnRun()
    begin

    end;

    var
        gPosTransaction: Codeunit "LSC POS Transaction";
        POSGUI: Codeunit "LSC POS GUI";
        DEFAULT_UOM: Label '99';
        TEXTl000: Label 'Call IT Support: \Item %1 need to have Unit of Measure asigned in your configuration.';
        TEXTl001: label 'Call IT Support: \Store %1 need to have "Responsability Center" asigned in your configuration.';
        TEXTl002: label 'Call IT Support: \Store %1 need to have Email and Phone No. asigned in your configuration.';
        TEXTl003: label 'Call IT Support: \establishment Type and both establishment Code are Required for Store %1.';
        TEXTl004: label 'Call IT Support: \TPV Code registed in MH is required for TPV %1.';
        TEXTl005: label 'Check Client Info: \Email Is required';
        TEXTl006: label 'Check Client Info: \Name is Required';
        TEXTl007: label 'Check Clien Info: \Address is Required';
        TEXTl008: label 'Check Client Info: \City and County are Required';
        TEXTl009: label 'Check Client Info: \Postal Code is Required';
        TEXTl010: label 'Call IT Support: \Fields "DTE District" and "DTE State" are required for Post Code %1, City %2, County %3.';
        TEXTl011: label 'Check Client Info: \Phone No. is Required for Customer %1.';
        TEXTl012: label 'Check Client Info: \"NRC" is Required for Customer %1.';
        TEXTl013: label 'Check Client Info: \Tax ID Type is Required for Customer %1.';
        TEXTl014: label 'Check Client Info: \Foreigner ID is Required for Customer %1.';
        TEXTl015: label 'Check Client Info: \DUI is Required for Customer %1.';
        TEXTl016: label 'Check Client Info: \NIT is Required for Customer %1.';
        TEXTl017: label 'Call IT Support: \name is Required for Company Information';
        TEXTl018: label 'Call IT Support: \NRC is Required for Company Information';
        TEXTl019: label 'Call IT Support: \NIT is Required for Company Information';
        TEXTl020: label 'DTE: “FSN NRC Descripción” de la empresa es requerido para Facturación electrónica MH, no puede ser vacío en ficha Información empresa';
        TEXTl021: label 'DTE: “DTE Active Code” de la empresa es requerido para Facturación electrónica MH, no puede ser vacío en ficha Información empresa';
        TEXTl023: label 'Check Client Info: \“DTE Active Code” is Required for Customer %1.';
        TEXTl024: label 'Check Client Info: \“Secondary customer” is Required for Customer %1.';
        TEXTl025: label 'Correo electronico es requerido para el cliente o beneficiario';
        POSSESSION: Codeunit "LSC POS Session";

    procedure ValidateCompany(var ErrorMessage: text): Boolean
    var
        CompanyInformation: Record "Company Information";
    begin
        CompanyInformation.get();

        if ErrorMessage = '' then begin
            if CompanyInformation.Name = '' then
                ErrorMessage := (TEXTl017);
        end;

        if ErrorMessage = '' then begin
            if CompanyInformation."VAT Registration No." = '' then
                ErrorMessage := (TEXTl018);
        end;

        if ErrorMessage = '' then begin
            if CompanyInformation."Federal ID No." = '' then
                ErrorMessage := (TEXTl019);
        end;

        if ErrorMessage <> '' then
            exit(true)
        else
            exit(false);
    end;

    procedure ValidateDataCustomer(transaction: Record "LSC POS Transaction"; vCustomer: Record Customer; var ErrorMessage: text): Boolean
    var
        vPostCode: Record "Post Code";
        docType: Enum "FSN Transaction Document Type";
        FSNElectronicInvoice: Codeunit "FSN Electronic Invoice";
    begin
        if transaction."FSN Document Type" in [docType::Ticket, docType::Nothing] then
            exit(false);

        if ErrorMessage = '' then begin
            if (vCustomer."E-Mail" = '') and (transaction."FSN Document Type" = docType::"Credito Fiscal") then
                ErrorMessage := TEXTl005;

            if vCustomer."FSN Request Beneficiary" then begin//20251008
                if ValBeneficiariesExclude(vCustomer."No.") then begin
                    if FSNElectronicInvoice.getCustGenericEmailBeneficaryCC(transaction) = '' then
                        ErrorMessage := (StrSubstNo(TEXTl025, vCustomer."No."));
                END;
            end;

        end;

        if ErrorMessage = '' then begin
            if (vCustomer."Phone No." = '') or ((StrLen(vCustomer."Phone No.") <> 8) and (vCustomer."FSN Foreign document" = '') and (transaction."FSN Document Type" = docType::"Credito Fiscal")) then
                ErrorMessage := (StrSubstNo(TEXTl011, vCustomer."No."));
        end;

        if ErrorMessage = '' then begin
            if vCustomer.Name = '' then
                ErrorMessage := TEXTl006;
        end;

        if ErrorMessage = '' then begin
            if (((vCustomer.Address = '') or (StrLen(vCustomer.Address) < 18)) and (transaction."FSN Document Type" = docType::"Credito Fiscal")) then
                ErrorMessage := TEXTl007;
        end;

        if ErrorMessage = '' then begin
            if (vCustomer."DTE Activity Code" = '') and (transaction."FSN Document Type" = docType::"Credito Fiscal") then
                ErrorMessage := (StrSubstNo(TEXTl023, vCustomer."No."));
        end;

        if ErrorMessage = '' then begin
            if (((vCustomer.City = '') or (vCustomer.County = '')) and (transaction."FSN Document Type" = docType::"Credito Fiscal")) then begin
                ErrorMessage := TEXTl008;
            end else begin
                vPostCode.Reset();
                vPostCode.SetRange(City, vCustomer.city);
                vPostCode.SetRange(County, vCustomer.County);
                if not vPostCode.FindSet() then begin
                    ErrorMessage := TEXTl009;
                end else begin
                    if (vPostCode."DTE District" = '') or (vPostCode."DTE State" = '') then
                        ErrorMessage := (StrSubstNo(TEXTl010, vCustomer."Post Code", vCustomer.City, vCustomer.County));
                end;
            end;
        end;

        if ErrorMessage = '' then begin
            if not (vCustomer."DTE Tax ID Type" in [vCustomer."DTE Tax ID Type"::"Carnet de Residente", vCustomer."DTE Tax ID Type"::DUI,
            vCustomer."DTE Tax ID Type"::NIT, vCustomer."DTE Tax ID Type"::Otros, vCustomer."DTE Tax ID Type"::Pasaporte]) then begin
                ErrorMessage := (StrSubstNo(TEXTl013, vCustomer."No."));
            end else begin
                case vCustomer."DTE Tax ID Type" of
                    vCustomer."DTE Tax ID Type"::Pasaporte,
                        vCustomer."DTE Tax ID Type"::"Carnet de Residente":
                        begin
                            if vCustomer."FSN Foreign document" = '' then
                                ErrorMessage := (StrSubstNo(TEXTl014, vCustomer."No."));
                        end;

                    vCustomer."DTE Tax ID Type"::DUI:
                        begin
                            if vCustomer."FSN DUI" = '' then
                                ErrorMessage := (StrSubstNo(TEXTl015, vCustomer."No."));
                        end;

                    vCustomer."DTE Tax ID Type"::NIT:
                        begin
                            if vCustomer."VAT Registration No." = '' then
                                ErrorMessage := (StrSubstNo(TEXTl016, vCustomer."No."));
                        end;
                end;
            end;
        end;

        if ErrorMessage = '' then begin
            if (vCustomer."FSN NRC" = '') and (transaction."FSN Document Type" in [docType::"Credito Fiscal", docType::"Nota Credito"]) then
                ErrorMessage := (StrSubstNo(TEXTl012, vCustomer."No."));
        end;

        if ErrorMessage <> '' then
            exit(true)
        else
            exit(false);
    end;
    //Validate Unit of Measure
    procedure ValidateUnitOfMeasure(vtransSalesEntry: Record "LSC Trans. Sales Entry"): Text
    var
        unitOfMeasure: Record "Unit of Measure";
        item: Record Item;
    begin
        if not item.Get(vtransSalesEntry."Item No.") or not unitOfMeasure.Get(vtransSalesEntry."Unit of Measure") then
            exit(DEFAULT_UOM);

        if item."DTE Unit Of Measure" <> '' then
            exit(item."DTE Unit Of Measure");

        if unitOfMeasure."DTE UnitOfMeasure" <> '' then
            exit(unitOfMeasure."DTE UnitOfMeasure");

        exit(DEFAULT_UOM);
    end;

    procedure ValidateDataStore(vStore: Record "LSC Store"; var vPHoneNo: Text[30]; var vEMail: Text[80]; var vMessError: Text): Boolean
    var
        myInt: Integer;
        RespCenter: Record "Responsibility Center";
    begin
        Clear(vPHoneNo);
        Clear(vEMail);
        Clear(vMessError);
        if RespCenter.Get(vStore."Responsibility Center") then begin// Validacionde de email y numero de telefono no esten vacios
            vPHoneNo := RespCenter."Phone No.";
            vEMail := RespCenter."E-Mail";
            if (vPHoneNo = '') or (vEMail = '') then begin
                vMessError := StrSubstNo(TEXTl002, RespCenter.Code);
            end;
        end else
            vMessError := StrSubstNo(TEXTl001, vStore."No.");

        if vMessError = '' then//Validacion de DTE en LSC Store
            if (vStore."DTE TypeEstablishment" = '') or (vStore."DTE CodeEstablishment" = '') or (vStore."DTE CodeEstablishmentMH" = '') then begin
                vMessError := (StrSubstNo(TEXTl003, vStore."No."));
            end;

        if vMessError <> '' then
            exit(true)
        else
            exit(false);
    end;

    local procedure requireResetCustomer(Receipt: Code[20]): Boolean;
    var
        lines: Record "LSC POS Trans. Line";
    begin
        lines.Reset();
        lines.SetCurrentKey("Receipt No.", "Line No.");
        lines.SetRange("Receipt No.", Receipt);
        if lines.FindLast() then
            if (lines."Entry Type" = lines."Entry Type"::FreeText)
                and (lines."Entry Status" = 0)
                and (lines."Text Type" in [lines."Text Type"::"Cust. Text",
                    lines."Text Type"::"Member Text"]) then
                exit(false)
            else
                exit(true);
        exit(false);

    end;

    local procedure verifyReturnDate(PosTransaction: Record "LSC POS Transaction"): Boolean
    var
        oldTransaction: Record "LSC Transaction Header";
        days: Integer;
        LIMTED_DAYS: Integer;
        ERROR_MESSAGE: label 'No se puede realizar una devolucion de mas de %1 dias';
    begin
        LIMTED_DAYS := 90; //! este valor debe ser parametrizable 

        if not oldTransaction.Get(PosTransaction."Retrieved from Store No.", PosTransaction."Retrieved from POS Term. No.", PosTransaction."Retrieved from Trans. No.") then
            exit(false);

        days := Abs(Today - oldTransaction.Date);
        if days > LIMTED_DAYS then begin
            Message(ERROR_MESSAGE, LIMTED_DAYS);
            exit(true);
        end;
    end;

    local procedure ReturCustomerSec(POSTransaction: Record "LSC POS Transaction")
    var
        myInt: Integer;
        attribute: Record "LSC Attribute Value";
        TransInfocode: Record "LSC Trans. Infocode Entry";
        infocode: Record "LSC POS Trans. Infocode Entry";
    begin
        attribute.SetRange("Attribute Code", 'CLIENTES');
        attribute.SetRange("Link Type", attribute."Link Type"::Customer);
        attribute.SetRange("Link Field 1", POSTransaction."Customer No.");
        attribute.SetRange("Attribute Value", 'SUB CLIENTE PV');
        IF attribute.find('-') then begin
            TransInfocode.Reset();
            TransInfocode.SetRange("Transaction No.", POSTransaction."Retrieved from Trans. No.");
            TransInfocode.SetRange("Store No.", POSTransaction."Retrieved from Store No.");
            TransInfocode.SetRange("POS Terminal No.", POSTransaction."Retrieved from POS Term. No.");
            TransInfocode.SetRange("Line No.", 40);
            if TransInfocode.Find('-') then begin
                infocode.Init();
                infocode."Receipt No." := POSTransaction."Receipt No.";
                infocode."Transaction Type" := 0;
                infocode."Line No." := 40;
                infocode.Infocode := 'TEXT';
                infocode.Information := TransInfocode.Information;
                infocode."POS Terminal No." := POSTransaction."POS Terminal No.";
                infocode."Store No." := POSTransaction."Store No.";
                infocode.Date := Today();
                infocode.Time := Time();
                infocode."Staff ID" := POSTransaction."Staff ID";
                if not infocode.Insert(true) then
                    infocode.Modify(true);
            end;
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction", 'OnItemNoPressed', '', true, true)]
    local procedure "LSC POS Transaction_OnItemNoPressed"
    (
        REC: Record "LSC POS Transaction";
        CurrInput: Text;
        var Handled: Boolean
    )
    var
        vItem: Record Item;
    begin
        if vItem.Get(CurrInput) then begin //Validacion que lleve unidad de medida base
            if vItem."Base Unit of Measure" = '' then begin
                Handled := true;
                CurrInput := '';
                gPosTransaction.SetCurrInput(CurrInput);// limpia el Input
                POSGUI.PosMessage(StrSubstNo(TEXTl000, vItem."No."));
            end;
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Controller", 'OnButtonPressed', '', false, false)]
    local procedure OnButtonPressed(var POSMenuLine: Record "LSC POS Menu Line"; var handled: Boolean);
    var
        transaction: Record "LSC POS Transaction";
        posTransCode: Codeunit "LSC POS Transaction";
        POSTransLineExists: Record "LSC POS Trans. Line";
        lText004: Label 'La transaccion debe tener al menos un articulo';
    begin
        if POSMenuLine.Command = 'TOTAL' then begin
            //? validacion para impedir que se haga una devolucion de mas de 90 dias
            if not transaction.Get(posTransCode.GetReceiptNo()) then
                exit;
            if transaction."Sale Is Return Sale" then
                Handled := verifyReturnDate(transaction);

            if Handled then
                exit;
        end;
        //JH200624 Validar que la transaccion no tenga descuadre entre venta y pagos
        if (POSMenuLine.Command = 'TENDER_K') or (POSMenuLine.Command = 'POST') then begin
            IF not (transaction."Entry Status" = transaction."Entry Status"::Voided) then begin
                if not transaction.Get(posTransCode.GetReceiptNo()) then
                    exit;
                if (transaction.Rounded <> 0) or (transaction."Trans. Sale/Pmt. Diff." <> 0) then
                    Error('Transacción con error, verifique y reingresela nuevamente');
            end;
        end;
    end;

    //JH310724 Validar Balance = 0 antes de postear la transaccion
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Post Utility", 'OnBeforeProcessTransaction', '', true, true)]
    local procedure "LSC POS Post Utility_OnBeforeProcessTransaction"
    (
        var PosTrans: Record "LSC POS Transaction";
        var TransSalesTaxEntryTEMP: Record "LSC Trans. SalesTax Entry"
    )
    var
        Difference: Decimal;
        Store: Record "LSC Store";
    begin
        IF not (PosTrans."Entry Status" = PosTrans."Entry Status"::Voided) then begin
            Store.Get(PosTrans."Store No.");
            Difference := (abs(PosTrans."Gross Amount") * -1) + PosTrans.Payment + (PosTrans."Income/Exp. Amount" * -1);
            if Abs(Difference) > Store."Allowed Diff. in Trans." then
                Error('Transacción con error, verifique y reingresela nuevamente');
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction", 'OnBeforePostTransaction', '', false, false)]
    local procedure OnBeforePostTransaction(var Rec: Record "LSC POS Transaction");
    var
        transLine: record "LSC POS Trans. Line";
        parameter: Record "FSN Parameter";
    begin
        //? parametro de tipologia
        IF not (Rec."Entry Status" = Rec."Entry Status"::Voided) then begin
            Parameter.SetRange(Grupo, 'TPVBLOCK');
            parameter.SetRange(Valor, 'TIPOLOGIA0');
            parameter.SetRange(Activo, true);
            if parameter.FindSet() then
                transLine.SetFilter(Number, '<>%1', Parameter.Codigo);
            transLine.setRange("Receipt No.", Rec."Receipt No.");
            transLine.SetRange("Entry Type", transLine."Entry Type"::Item);
            if (Rec."Customer No." = '') and (transLine.Count > 0) then
                Error('La transaccion no puede ser realizada sin un cliente seleccionado');
        end;
    end;


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnBeforeTotalExecuted', '', true, true)]
    local procedure "LSC POS Transaction Events_OnBeforeTotalExecuted"
   (
    var POSTransaction: Record "LSC POS Transaction";
    var IsHandled: Boolean
   )
    var
        DTEStore: Record "LSC Store";
        DTETerminal: Record "LSC POS Terminal";
        gPHoneNo: Text[30];
        gEMail: Text[80];
        gMessage: Text;
        gCustomer: Record Customer;
        infocode: Record "LSC POS Trans. Infocode Entry";
        subCustomer: Record Customer;
        attribute: Record "LSC Attribute Value";
        POSInfo: Record "LSC POS Trans. Infocode Entry";
        POSTransLine: Record "LSC POS Trans. Line";
        IncExt: Record "LSC Income/Expense Account";
        TransInfocode: Record "LSC Trans. Infocode Entry";
    begin


        if POSTransaction."Sale Is Return Sale" then begin
            ReturCustomerSec(POSTransaction);
        end;

        attribute.SetRange("Attribute Code", 'CLIENTES');
        attribute.SetRange("Link Type", attribute."Link Type"::Customer);
        attribute.SetRange("Link Field 1", POSTransaction."Customer No.");
        attribute.SetRange("Attribute Value", 'SUB CLIENTE PV');
        IF attribute.find('-') then begin
            POSInfo.Reset();
            POSInfo.SetRange("Receipt No.", POSTransaction."Receipt No.");
            POSInfo.SetRange("Line No.", 40);
            if not POSInfo.Find('-') then begin
                IsHandled := true;
                Error(StrSubstNo(TEXTl024, POSTransaction."Customer No."));
            end;
        end;

        IF NOT IsHandled THEN
            if requireResetCustomer(POSTransaction."Receipt No.") then
                if (POSTransaction."Customer No." <> '') AND (POSTransaction."FSN Document Type" IN [POSTransaction."FSN Document Type"::"Credito Fiscal"]) then begin
                    if POSTransaction."Member Card No." <> '' then
                        gPosTransaction.InputMemberCard(POSTransaction."Member Card No.")
                    else
                        if POSTransaction."Customer No." <> '' then
                            gPosTransaction.SelectCustPressed(POSTRAnsaction."Customer No.");
                end;
        if (attribute."Attribute Value" <> 'SUB CLIENTE PV') then
            if gCustomer.Get(POSTransaction."Customer No.") and (gCustomer."LSC Retail Customer Group" = 'COMODIN') and (POSTransaction."FSN Document Type" = POSTransaction."FSN Document Type"::Factura) then
                exit;

        clear(gPHoneNo);
        Clear(gEMail);
        Clear(gMessage);

        if NOT IsHandled then begin
            if DTEStore.Get(POSTransaction."Store No.") then
                if ValidateDataStore(DTEStore, gPHoneNo, gEMail, gMessage) then begin // Validacionde de email y numero de telefono no esten vacios
                    IsHandled := true;
                    Error(gMessage);
                end;
        end;

        if NOT IsHandled then begin
            if DTETerminal.Get(POSTransaction."POS Terminal No.") then begin//Validacion del DTE en la Terminal
                IF DTETerminal."DTE CodeSellingPointMH" = '' THEN begin
                    IsHandled := true;
                    Error(StrSubstNo(TEXTl004, DTETerminal."No."));
                end;
            end;
        end;

        if NOT IsHandled then begin
            if gCustomer.get(POSTransaction."Customer No.") then begin// Validacion de Data de cliente para facturaccion electronica MH.
                infocode.SetRange("Store No.", POSTransaction."Store No.");
                infocode.SetRange("Receipt No.", POSTransaction."Receipt No.");
                infocode.SetRange("Transaction Type", 0);
                infocode.SetRange("Line No.", 40);
                infocode.SetRange("Infocode", 'TEXT');
                if infocode.FindSet() then
                    if subCustomer.Get(infocode.Information) then begin
                        gCustomer := subCustomer;
                    end;

                if ValidateDataCustomer(POSTransaction, gCustomer, gMessage) then begin
                    IsHandled := true;
                    Error(gMessage);
                end;
            end;
        end;

        if NOT IsHandled then begin
            if ValidateCompany(gMessage) then begin
                IsHandled := true;
                Error(gMessage);
            end;
        end;

    end;


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"TransferOrder-Post Shipment", 'OnBeforeTransferOrderPostShipment', '', true, true)]
    local procedure "TransferOrder-Post Shipment_OnBeforeTransferOrderPostShipment"
    (
        var TransferHeader: Record "Transfer Header";
        var CommitIsSuppressed: Boolean
    )
    var
        FSN_DTE: Record "FSN DTE Transaction Header";
        NoSeries: Record "No. Series";
        FromStore: Record "LSC Store";
        NoSerie: Codeunit "NoSeriesManagement";
        NextSerie: Code[20];
        TEXT002: Label 'No se encuentra numero de serie %1';
        StoreFiltDTE: Record "LSC Store";
        TerminalFiltDTE: Record "LSC POS Terminal";
    begin

        ValInventoryTransfer(TransferHeader);
        if TransferHeader."Transfer-from Code" <> 'CD' then
            SendDTE(TransferHeader, TRUE);//28981

    end;

    [EventSubscriber(ObjectType::Page, Page::"LSC Retail TO. tb. Picked Sub.", 'OnInsertRecordEvent', '', true, true)]
    local procedure "LSC Retail TO. tb. Picked Sub._OnInsertRecordEvent"
(
    var Rec: Record "Transfer Line";
    var xRec: Record "Transfer Line";
    var AllowInsert: Boolean;
    BelowxRec: Boolean
)
    var
        Transfer: Record "Transfer Header";
        ErrorTExt01: Label 'No puede agregar mas producto, Transferencia %1 ya certificada';
        FSN_DTE: Record "FSN DTE Transaction Header";
    begin
        if Transfer.GET(Rec."Document No.") then begin
            IF FSN_DTE.GET(COPYSTR(Transfer."No.", 1, 10), COPYSTR(Transfer."No.", 11, 10), 0) THEN BEGIN
                IF (FSN_DTE."DTE AuthNumber" <> '') AND (FSN_DTE."Signature Validation" <> '') THEN
                    Error(StrSubstNo(ErrorTExt01, Transfer."No."));
            END;

        END;
    end;


    [EventSubscriber(ObjectType::Page, Page::"Transfer Order Subform", 'OnInsertRecordEvent', '', true, true)]
    local procedure "Transfer Order Subform_OnInsertRecordEvent"
    (
        var Rec: Record "Transfer Line";
        var xRec: Record "Transfer Line";
        var AllowInsert: Boolean;
        BelowxRec: Boolean
    )
    VAR
        Transfer: Record "Transfer Header";
        ErrorTExt01: Label 'No puede agregar mas producto, Transferencia %1 ya certificada';
        FSN_DTE: Record "FSN DTE Transaction Header";
    begin
        if Transfer.GET(Rec."Document No.") then begin
            IF FSN_DTE.GET(COPYSTR(Transfer."No.", 1, 10), COPYSTR(Transfer."No.", 11, 10), 0) THEN BEGIN
                IF (FSN_DTE."DTE AuthNumber" <> '') AND (FSN_DTE."Signature Validation" <> '') THEN
                    Error(StrSubstNo(ErrorTExt01, Transfer."No."));
            END;
        END;
    end;


    [EventSubscriber(ObjectType::Page, Page::"Transfer Order", 'OnModifyRecordEvent', '', true, true)]
    local procedure "Transfer Order_OnModifyRecordEvent"
    (
        var Rec: Record "Transfer Header";
        var xRec: Record "Transfer Header";
        var AllowModify: Boolean
    )
    var
        ERRORD: label 'No puede modificar documento externo.';
    begin
        if Rec."External Document No." <> xRec."External Document No." then
            Error(ERRORD);
    end;

    procedure ValInventoryTransfer(Transfer: Record "Transfer Header")
    var
        TransferLine: Record "Transfer Line";
        TransLine: Record "Transfer Line";
        ItemUnitOfMens: Record "Item Unit of Measure";
        itemLedEntry: Record "Item Ledger Entry";
        QuantityTransfer: Decimal;
        ERROR001: Label 'Inventatio insuficiente para el producto %1';
        ERROR002: Label 'Dispone cantidad insuficiente del producto %1 en inventario.';
        ERROR003: Label 'FSN No puedes recibir más de %1 unidades.';
        ERROR004: Label 'FSN Actualmente no hay artículos en tránsito.';
        ERROR005: Label 'No hay lineas que certificar.';
        QtyinTransit: Decimal;
        QtyinTransitBase: Decimal;
    begin

        IF Transfer."Transfer-from Code" = 'CD' then
            EXIT;

        with Transfer do begin
            TransLine.Reset();
            TransLine.SetRange("Document No.", Transfer."No.");
            TransLine.SetRange("Derived From Line No.", 0);
            TransLine.SetFilter(Quantity, '<>0');
            TransLine.SetFilter("Qty. to Ship", '<>0');
            if TransLine.IsEmpty() then
                Error(ERROR005);
        end;

        TransferLine.reset;
        TransferLine.SetRange("Document No.", Transfer."No.");
        TransferLine.setRange("Derived From Line No.", 0);
        if TransferLine.Find('-') then begin
            repeat
                if (TransferLine.Quantity <> TransferLine."Qty. in Transit") then
                    IF TransferLine."Qty. to Ship" <> 0 THEN BEGIN
                        if ItemUnitOfMens.get(TransferLine."Item No.", TransferLine."Unit of Measure") then begin
                            IF ItemUnitOfMens."Qty. per Unit of Measure" <> 0 THEN
                                QuantityTransfer := TransferLine."Qty. to Ship" * ItemUnitOfMens."Qty. per Unit of Measure";
                            //QuantityTransfer := TransferLine.Quantity * ItemUnitOfMens."Qty. per Unit of Measure";

                            itemLedEntry.Reset();
                            itemLedEntry.SetRange("Location Code", Transfer."Transfer-from Code");
                            itemLedEntry.SetRange("Item No.", TransferLine."Item No.");
                            itemLedEntry.CalcSums(Quantity);
                            if itemLedEntry.Quantity <= 0 then
                                Error(STRSUBSTNO(ERROR001, TransferLine."Item No."));

                            if QuantityTransfer > itemLedEntry.Quantity then
                                Error(STRSUBSTNO(ERROR002, TransferLine."Item No."));


                        end;
                    END;
            until TransferLine.Next() = 0;
        end;
    end;

    procedure SendDTE(var Transfer: Record "Transfer Header"; Production: Boolean)
    var
        ToStore: Record "LSC Store";
        FromStore: Record "LSC Store";
        Json: Text;
        TransferLIne: Record "Transfer Line";
        FSN_DTE: Record "FSN DTE Transaction Header";
        NoSerie: Codeunit "NoSeriesManagement";
        NoSeries: Record "No. Series";
        NextSerie: Code[35];
        Item_l: Record Item;
        UM_l: Record "Item Unit of Measure";
        TotalCost: Decimal;
        i: Integer;
        OD: Codeunit "FSN OData Conexion";
        e: Boolean;
        p: Record "LSC POS Menu Line";
        UnitCost: Decimal;
        TotalLine: Decimal;
        codeMH: Text[10];
        CodeNameMH: Text[10];
        DTEAuth_: Text[50];
        DTESign_: Text[50];
        NoText: array[2] of Text[75];
        FSN: Codeunit "FSN Utility";
        TxtDollars: Text;
        RespCenter: Record "Responsibility Center";
        StoreFiltDTE: Record "LSC Store";
        TerminalFiltDTE: Record "LSC POS Terminal";
        jsonInfo, SellerInfo, AddressInfo, BuyerInfo, TaxInfo, BuyerAddressInfo, TranfLineInfo, TotalInfo, DiscountsInfo, adendaInfo : JsonObject;
        JSonStringInformation: Text;
        sb: DotNet StringBuilder;
        Array1, Array2 : JsonArray;
        jValue: JsonValue;
        TransNo: Integer;
        TEXT001: Label 'Error al generar remision electronica.';
        TEXT002: Label 'No se encuentra numero de serie %1';
        TEXT003: Label 'Procesando DTE, Espere.......';
        pg: Page "LSC Retail TO. tb. Picked";
        FSNParameter: Record "FSN Fasani Setup";
        Windows: Dialog;
        TokenDTE: Text;
        FSNParameterV: Record "FSN Parameter";
        UnitOfMesesure: Record "Unit of Measure";
        POSCode: Record "Post Code";
        NewdescriptionVal: Text;
        QTY: Decimal;
    begin

        CLEAR(FSN_DTE);
        CLEAR(e);

        IF FSNParameter.GET(Transfer."LSC Store-from") then begin
            if (FSNParameter."DTE Store" = '') or (FSNParameter."DTE Terminal" = '') then
                exit
        end else
            exit;


        IF STRLEN(Transfer."No.") > 10 THEN BEGIN//28981
            IF FSN_DTE.GET(COPYSTR(Transfer."No.", 1, 10), COPYSTR(Transfer."No.", 11, 10), 0) THEN BEGIN
                IF Transfer."External Document No." <> FSN_DTE."DTE Invoice" THEN BEGIN
                    Transfer."External Document No." := FSN_DTE."DTE Invoice";
                    Transfer.MODIFY;
                END;
                e := TRUE;

                IF (FSN_DTE."DTE AuthNumber" <> '') AND (FSN_DTE."Signature Validation" <> '') THEN
                    exit;

            END;
        END ELSE
            IF FSN_DTE.GET(Transfer."No.", '1', 0) THEN BEGIN
                IF Transfer."External Document No." <> FSN_DTE."DTE Invoice" THEN BEGIN
                    Transfer."External Document No." := FSN_DTE."DTE Invoice";
                    Transfer.MODIFY;
                END;

                e := TRUE;

                IF (FSN_DTE."DTE AuthNumber" <> '') AND (FSN_DTE."Signature Validation" <> '') THEN
                    EXIT;
            END;
        FromStore.GET(Transfer."LSC Store-from");
        ToStore.GET(Transfer."LSC Store-to");
        StoreFiltDTE.GET(Transfer."LSC Store-from");
        IF not FSNParameter.GET(Transfer."LSC Store-from") then
            EXIT;
        RespCenter.Get(StoreFiltDTE."No.");
        TerminalFiltDTE.Reset();
        TerminalFiltDTE.SetRange("Store No.", StoreFiltDTE."No.");
        TerminalFiltDTE.SetRange(TerminalFiltDTE."DTE CodeSellingPointMH", 'P002');
        IF TerminalFiltDTE.FindFirst() THEN;
        IF NOT e THEN BEGIN
            FSN_DTE.INIT;
            FSN_DTE."Store No." := COPYSTR(Transfer."No.", 1, 10);
            IF STRLEN(Transfer."No.") > 10 THEN
                FSN_DTE."POS Terminal No." := COPYSTR(Transfer."No.", 11, 10)
            ELSE
                FSN_DTE."POS Terminal No." := '1';
            FSN_DTE."DTE AuthNumber" := COPYSTR(UpperCase(CreateGuid()), 2, 36);
            FSN_DTE."Transaction No." := 0;
            FSN_DTE."Creating Date" := TODAY;
            FSN_DTE."Document Type" := '04';

            IF NOT NoSeries.Get((COPYSTR(FromStore."No.", 1, 5) + 'TRDTE')) THEN
                ERROR(STRSUBSTNO(TEXT002, (COPYSTR(FromStore."No.", 1, 5) + 'TRDTE')));
            NextSerie := NoSerie.GetNextNo((COPYSTR(FromStore."No.", 1, 5) + 'TRDTE'), TODAY, TRUE);
            FSN_DTE."DTE EnrolledTimeStamp" := NextSerie;
            StoreFiltDTE.GET(Transfer."LSC Store-from");
            RespCenter.Get(StoreFiltDTE."No.");
            TerminalFiltDTE.Reset();
            TerminalFiltDTE.SetRange("Store No.", StoreFiltDTE."No.");
            TerminalFiltDTE.SetRange(TerminalFiltDTE."DTE CodeSellingPointMH", 'P002');
            IF TerminalFiltDTE.FindFirst() THEN;
            //IF FSNParameter.GET(Transfer."Store-from") AND (FSNParameter."DTE Store" <> '') AND (FSNParameter."DTE Terminal" <> '') THEN
            FSN_DTE."DTE Invoice" := 'DTE-04-' + FSNParameter."DTE Store" + FSNParameter."DTE Terminal" + '-' + NextSerie;
            //ELSE
            //FSN_DTE."DTE Invoice" := 'DTE-04-00' + COPYSTR(Transfer."Store-from",2,2) + '0000-' +  NextSerie;
            if not FSN_DTE.INSERT(TRUE) then
                FSN_DTE.Modify(TRUE);

            Transfer."External Document No." := FSN_DTE."DTE Invoice";
            Transfer.MODIFY;
        END;

        IF NOT Production THEN
            EXIT;
        COMMIT;
        i := 0;

        IF FromStore."No." = 'DIFERENCIA' THEN
            CodeNameMH := 'AUX1'
        ELSE
            CodeNameMH := FSNParameter."DTE Store";

        codeMH := FSNParameter."DTE Store";

        jsonInfo.Add('GUID', FSN_DTE."DTE AuthNumber");
        jsonInfo.Add('DocumentType', '04');
        jsonInfo.Add('OperationType', '01');
        jsonInfo.Add('IssuedDate', FORMAT(DATE2DMY(TODAY, 3)) + '-' + FORMAT(DATE2DMY(TODAY, 2)) + '-' + FORMAT(DATE2DMY(TODAY, 1)));
        jsonInfo.Add('IssuedTime', FORMAT(TIME, 9));
        jsonInfo.Add('IdShop', CodeNameMH);
        jsonInfo.Add('Secuencial', FSN_DTE."DTE EnrolledTimeStamp");
        if Evaluate(TransNo, FSN_DTE."DTE EnrolledTimeStamp") then;
        jsonInfo.Add('TransNo', FSN_DTE."DTE EnrolledTimeStamp");
        jsonInfo.Add('PrintTicket', false);
        jValue.SetValueToNull();
        jsonInfo.Add('Contingency', jValue);

        SellerInfo.Add('Name', 'Farmacia San Nicolas S.A. de C.V.');
        SellerInfo.Add('NRC', '406-5');
        SellerInfo.Add('NIT', '0614-221265-001-4');
        SellerInfo.Add('CodeSellingPoint', 'P002');
        SellerInfo.Add('CodeSellingPointMH', 'P002');
        SellerInfo.Add('TypeEstablishment', '01');
        SellerInfo.Add('CodeEstablishment', CodeNameMH);
        SellerInfo.Add('codeEstablishmentMH', codeMH);
        SellerInfo.Add('Phone', '2555-5555');
        SellerInfo.Add('Email', RespCenter."E-Mail");
        SellerInfo.Add('ActivityCode', '46491');
        SellerInfo.Add('ActivityDesc', 'Venta al por mayor de productos medicinales, cosméticos, perfumería y productos de limpieza');

        jsonInfo.Add('Seller', SellerInfo);

        AddressInfo.Add('AddressLine', FromStore.Address);

        POSCode.Reset();
        POSCode.SetRange(Code, FromStore."Post Code");
        if POSCode.FindFirst() then begin
            AddressInfo.Add('District', format(POSCode."DTE District"));//20251212
            AddressInfo.Add('State', format(POSCode."DTE State"));
        end else begin
            AddressInfo.Add('District', '14');
            AddressInfo.Add('State', '06');
        end;

        SellerInfo.Add('Address', AddressInfo);

        jsonInfo.Add('Buyer', BuyerInfo);
        BuyerInfo.Add('NRC', '406-5');

        BuyerInfo.Add('TaxInformation', TaxInfo);
        TaxInfo.Add('ID', '36');
        TaxInfo.Add('Value', '0614-221265-001-4');

        BuyerInfo.Add('ActivityCode', '46491');
        BuyerInfo.Add('ActivityDesc', 'Venta al por mayor de productos medicinales, cosméticos, perfumería y productos de limpieza');
        BuyerInfo.Add('Name', 'Farmacia San Nicolas S.A. de C.V.');
        BuyerInfo.Add('ComercialName', ToStore.Name);
        BuyerInfo.Add('Phone', '22253733');
        BuyerInfo.Add('Email', RespCenter."E-Mail");

        BuyerInfo.Add('Address', BuyerAddressInfo);
        BuyerAddressInfo.Add('AddressLine', ToStore.Address);

        POSCode.Reset();
        POSCode.SetRange(Code, ToStore."Post Code");//20251212
        if POSCode.FindFirst() then begin
            BuyerAddressInfo.Add('District', POSCode."DTE District");
            BuyerAddressInfo.Add('State', POSCode."DTE State");
        end else begin
            BuyerAddressInfo.Add('District', '14');
            BuyerAddressInfo.Add('State', '06');
        end;

        BuyerInfo.Add('BienTitulo', '04');

        TotalCost := 0;
        i := 0;

        TransferLIne.RESET;
        TransferLIne.SETRANGE(TransferLIne."Document No.", Transfer."No.");
        TransferLIne.SETRANGE(TransferLIne."Derived From Line No.", 0);
        TransferLIne.SETFILTER(TransferLIne.Quantity, '>0');
        TransferLIne.FIND('-');
        REPEAT

            Item_l.GET(TransferLIne."Item No.");
            /* UM_l.GET(TransferLIne."Item No.", TransferLIne."Unit of Measure");*/
            IF Item_l."Unit Cost" = 0 THEN
                Item_l."Unit Cost" := 0.01;

            if not UM_l.GET(TransferLIne."Item No.", TransferLIne."Unit of Measure") then begin
                UnitOfMesesure.Reset();
                UnitOfMesesure.SetRange(UnitOfMesesure.Description, TransferLIne."Unit of Measure");
                if UnitOfMesesure.FindFirst() then
                    UM_l.GET(TransferLIne."Item No.", UnitOfMesesure.Code);
            end;

            UnitCost := Item_l."Unit Cost" * UM_l."Qty. per Unit of Measure";
            TotalCost += ROUND(UnitCost * TransferLIne.Quantity, 0.01);
            TotalLine := ROUND(UnitCost * TransferLIne.Quantity, 0.01);
            UnitCost := ROUND(TotalLine / TransferLIne.Quantity, 0.00001);

            if not ValidateLotAndExpireDateDescription(TransferLIne, Array1) then begin
                Clear(TranfLineInfo);
                TranfLineInfo.Add('Code', TransferLIne."Item No.");
                TranfLineInfo.Add('Name', DELCHR(TransferLIne.Description, '=', '"'));
                TranfLineInfo.Add('UnitOfMeasure', '59');
                TranfLineInfo.Add('ProductType', '1');
                TranfLineInfo.Add('Quantity', DELCHR(FORMAT(TransferLIne.Quantity), '=', ','));
                TranfLineInfo.Add('SuggestedSalePrice', '0.00');
                TranfLineInfo.Add('Discount', '0.00');
                TranfLineInfo.Add('NO_GRAVADO', '0.00');
                TranfLineInfo.Add('VENTA_NO_SUJETA', '0.00');
                TranfLineInfo.Add('VENTA_EXENTA', '0.00');
                TranfLineInfo.Add('VENTA_GRAVADA', DELCHR(FORMAT(ROUND(TotalLine)), '=', ','));
                TranfLineInfo.Add('Total', DELCHR(FORMAT(ROUND(TotalLine)), '=', ','));
                TranfLineInfo.Add('price', DELCHR(FORMAT(ROUND(UnitCost)), '=', ','));
                /*TranfLineInfo.Add('VENTA_GRAVADA', serializeDecimal(TotalLine));
                TranfLineInfo.Add('Total', serializeDecimal(TotalLine));
                TranfLineInfo.Add('price', serializeDecimal(UnitCost));*/
                jValue.SetValueToNull();
                TranfLineInfo.Add('Document', jValue);
                Array1.Add(TranfLineInfo);
            end;
        UNTIL TransferLIne.NEXT = 0;

        jsonInfo.Add('ProductList', Array1);

        CLEAR(NoText);
        CLEAR(FSN);
        //TxtDollars := FSN.FormatNoText1(NoText, ABS(ROUND(TotalCost * 0.13, 0.01) + TotalCost));
        TxtDollars := FSN.Num2Text(ABS(ROUND(TotalCost * 0.13, 0.01) + TotalCost));

        jValue.SetValueToNull();
        jsonInfo.Add('PaymentList', jValue);

        jsonInfo.Add('Totals', TotalInfo);
        TotalInfo.Add('SubTotal', DELCHR(FORMAT(ROUND(TotalCost)), '=', ','));
        TotalInfo.Add('TOTAL_NO_GRAVADO', '0.00');
        TotalInfo.Add('TOTAL_NO_SUJETA', '0.00');

        TotalInfo.Add('Discounts', DiscountsInfo);
        DiscountsInfo.Add('Exento', '0.00');
        DiscountsInfo.Add('Gravado', '0.00');

        TotalInfo.Add('TOTAL_EXENTO', '0.00');
        TotalInfo.Add('TOTAL_GRAVADO', DELCHR(FORMAT(ROUND(TotalCost)), '=', ','));
        TotalInfo.Add('IVA', FORMAT(ROUND(TotalCost * 0.13, 0.01)));
        TotalInfo.Add('IvaPercibido', '0.00');
        TotalInfo.Add('IvaRetenido', '0.00');
        TotalInfo.Add('RetencionRenta', '0.00');
        TotalInfo.Add('InWords', TxtDollars);
        TotalInfo.Add('Amount', DELCHR(FORMAT(ROUND(TotalCost * 0.13, 0.01) + ROUND(TotalCost)), '=', ','));

        adendaInfo.Add('name', 'SucDestino');
        adendaInfo.Add('data', 'SucDestino');
        adendaInfo.Add('value', ToStore.Name + ' ' + Transfer."No.");
        Array2.Add(adendaInfo);

        jsonInfo.Add('adenda', Array2);

        jsonInfo.WriteTo(JSonStringInformation);
        sb := sb.StringBuilder();
        sb.Append(JSonStringInformation);
        //Message(JSonStringInformation);

        Windows.OPEN(TEXT003);
        Windows.UPDATE;
        IF FSNParameterV.GET('DTE_INVOICE', 'TRANS_TOKEN') THEN;//20250310
        GetTokenAPIDTE(FSNParameterV, '', Transfer."No.", DTESign_, TokenDTE);
        DTERemission(JSonStringInformation, Transfer."No.", DTESign_, DTEAuth_, TokenDTE);
        Windows.Close();

        IF DTEAuth_ <> '' THEN BEGIN
            FSN_DTE."DTE AuthNumber" := DTEAuth_;
            FSN_DTE."Signature Validation" := DTESign_;
            FSN_DTE.MODIFY(TRUE);
            COMMIT;

        END ELSE
            ERROR(TEXT001);
    end;

    procedure ValidateLotAndExpireDateDescription(TransferLIne: Record "Transfer Line"; var Array1: JsonArray): Boolean
    var
        ReservationEntry: Record "Reservation Entry";
        Item_l: Record Item;
        UM_l: Record "Item Unit of Measure";
        UnitOfMesesure: Record "Unit of Measure";
        jValue: JsonValue;
        TranfLineInfo: JsonObject;
        TotalLine: Decimal;
        UnitCost: Decimal;
        Newdescription: label '%1 | L: %2 | LV: %3';
        QtyReservation: Decimal;
        ReservationVal: Boolean;
    begin

        ReservationVal := false;
        ReservationEntry.Reset();
        ReservationEntry.SetRange(ReservationEntry."Source ID", TransferLIne."Document No.");
        ReservationEntry.SetRange(ReservationEntry."Item No.", TransferLIne."Item No.");
        ReservationEntry.SetRange(ReservationEntry."Source Ref. No.", TransferLIne."Line No.");
        ReservationEntry.SetRange(ReservationEntry."Source Subtype", ReservationEntry."Source Subtype"::"1");
        IF ReservationEntry.Find('-') THEN BEGIN
            repeat
                ReservationVal := true;

                Item_l.GET(TransferLIne."Item No.");
                IF Item_l."Unit Cost" = 0 THEN
                    Item_l."Unit Cost" := 0.01;

                if not UM_l.GET(TransferLIne."Item No.", TransferLIne."Unit of Measure") then begin
                    UnitOfMesesure.Reset();
                    UnitOfMesesure.SetRange(UnitOfMesesure.Description, TransferLIne."Unit of Measure");
                    if UnitOfMesesure.FindFirst() then
                        UM_l.GET(TransferLIne."Item No.", UnitOfMesesure.Code);
                end;

                QtyReservation += ReservationEntry.Quantity;

                //Calculo de costo segun Qty de reservation entry
                UnitCost := Item_l."Unit Cost" * UM_l."Qty. per Unit of Measure";
                TotalLine := ROUND(UnitCost * ReservationEntry.Quantity, 0.01);
                UnitCost := ROUND(TotalLine / ReservationEntry.Quantity, 0.00001);

                Clear(TranfLineInfo);
                TranfLineInfo.Add('Code', TransferLIne."Item No.");
                TranfLineInfo.Add('Name', DELCHR(StrSubstNo(Newdescription, TransferLIne.Description, ReservationEntry."Lot No.",
                        Format(ReservationEntry."Expiration Date")), '=', '"'));
                TranfLineInfo.Add('UnitOfMeasure', '59');
                TranfLineInfo.Add('ProductType', '1');
                TranfLineInfo.Add('Quantity', DELCHR(FORMAT(ReservationEntry.Quantity), '=', ','));
                TranfLineInfo.Add('SuggestedSalePrice', '0.00');
                TranfLineInfo.Add('Discount', '0.00');
                TranfLineInfo.Add('NO_GRAVADO', '0.00');
                TranfLineInfo.Add('VENTA_NO_SUJETA', '0.00');
                TranfLineInfo.Add('VENTA_EXENTA', '0.00');
                TranfLineInfo.Add('VENTA_GRAVADA', DELCHR(FORMAT(ROUND(TotalLine)), '=', ','));
                TranfLineInfo.Add('Total', DELCHR(FORMAT(ROUND(TotalLine)), '=', ','));
                TranfLineInfo.Add('price', DELCHR(FORMAT(ROUND(UnitCost)), '=', ','));
                jValue.SetValueToNull();
                TranfLineInfo.Add('Document', jValue);
                Array1.Add(TranfLineInfo);
            UNTIL ReservationEntry.Next() = 0;
        END;

        if ReservationVal then
            if TransferLIne.Quantity > QtyReservation then begin
                ReservationVal := true;

                TotalLine := ROUND((Item_l."Unit Cost" * UM_l."Qty. per Unit of Measure") * (TransferLIne.Quantity - QtyReservation), 0.01);
                UnitCost := ROUND(TotalLine / (TransferLIne.Quantity - QtyReservation), 0.00001);

                Clear(TranfLineInfo);
                TranfLineInfo.Add('Code', TransferLIne."Item No.");
                TranfLineInfo.Add('Name', DELCHR(TransferLIne.Description, '=', '"'));
                TranfLineInfo.Add('UnitOfMeasure', '59');
                TranfLineInfo.Add('ProductType', '1');
                TranfLineInfo.Add('Quantity', DELCHR(FORMAT(TransferLIne.Quantity - QtyReservation), '=', ','));
                TranfLineInfo.Add('SuggestedSalePrice', '0.00');
                TranfLineInfo.Add('Discount', '0.00');
                TranfLineInfo.Add('NO_GRAVADO', '0.00');
                TranfLineInfo.Add('VENTA_NO_SUJETA', '0.00');
                TranfLineInfo.Add('VENTA_EXENTA', '0.00');
                TranfLineInfo.Add('VENTA_GRAVADA', DELCHR(FORMAT(ROUND(TotalLine)), '=', ','));
                TranfLineInfo.Add('Total', DELCHR(FORMAT(ROUND(TotalLine)), '=', ','));
                TranfLineInfo.Add('price', DELCHR(FORMAT(ROUND(UnitCost)), '=', ','));
                jValue.SetValueToNull();
                TranfLineInfo.Add('Document', jValue);
                Array1.Add(TranfLineInfo);
            end;

        exit(ReservationVal);
    end;

    procedure ValLotVenceDescription(TransferLIne: Record "Transfer Line"; var Array1: JsonArray): Boolean
    var
        Item_l: Record Item;
        Newdescription: label '%1 | L: %2 | LV: %3';
        ReservationEntry: Record "Reservation Entry";
        jValue: JsonValue;
        TranfLineInfo: JsonObject;
    begin

        ReservationEntry.Reset();
        ReservationEntry.SetRange(ReservationEntry."Source ID", TransferLIne."Document No.");
        ReservationEntry.SetRange(ReservationEntry."Item No.", TransferLIne."Item No.");
        ReservationEntry.SetRange(ReservationEntry."Source Ref. No.", TransferLIne."Line No.");
        ReservationEntry.SetRange(ReservationEntry."Source Subtype", ReservationEntry."Source Subtype"::"1");
        IF ReservationEntry.Find('-') THEN BEGIN
            repeat
                IF ReservationEntry."Lot No." <> '' THEN BEGIN
                    Clear(TranfLineInfo);
                    TranfLineInfo.Add('Code', TransferLIne."Item No.");
                    TranfLineInfo.Add('Name', DELCHR(StrSubstNo(Newdescription, TransferLIne.Description, ReservationEntry."Lot No.",
                         Format(ReservationEntry."Expiration Date")), '=', '"'));
                    TranfLineInfo.Add('UnitOfMeasure', '59');
                    TranfLineInfo.Add('ProductType', '1');
                    TranfLineInfo.Add('Quantity', DELCHR(FORMAT(ReservationEntry.Quantity), '=', ','));
                    TranfLineInfo.Add('SuggestedSalePrice', '0.00');
                    TranfLineInfo.Add('Discount', '0.00');
                    TranfLineInfo.Add('NO_GRAVADO', '0.00');
                    TranfLineInfo.Add('VENTA_NO_SUJETA', '0.00');
                    TranfLineInfo.Add('VENTA_EXENTA', '0.00');
                    TranfLineInfo.Add('VENTA_GRAVADA', '0.00');
                    TranfLineInfo.Add('Total', '0.00');
                    TranfLineInfo.Add('price', '0.00');

                    jValue.SetValueToNull();
                    TranfLineInfo.Add('Document', jValue);
                    Array1.Add(TranfLineInfo);
                END;
            until ReservationEntry.Next() = 0;
            exit(true);
        END;
        exit(false);
    end;


    [EventSubscriber(ObjectType::Table, Database::"Reservation Entry", 'OnBeforeInsertEvent', '', true, true)]
    local procedure "Reservation Entry_OnBeforeInsertEvent"
    (
        var Rec: Record "Reservation Entry";
        RunTrigger: Boolean
    )
    var
        DateFilt: date;
    begin

        if not Rec.IsTemporary then begin
            if Evaluate(DateFilt, '') then;
            if (Rec."Expiration Date" = DateFilt) then begin
                FiltLotLedgerEntry(Rec."Item No.", Rec."Lot No.", DateFilt);
                Rec."Expiration Date" := DateFilt;
            end;
        end;

    end;


    procedure FiltLotLedgerEntry(ItemCode: Code[20]; lotNo: Text[50]; var expDate: Date)
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
    begin
        ItemLedgerEntry.Reset();
        ItemLedgerEntry.SetRange("Item No.", ItemCode);
        ItemLedgerEntry.SetRange("Lot No.", lotNo);
        if ItemLedgerEntry.FindFirst() then
            expDate := ItemLedgerEntry."Expiration Date"
        else
            expDate := 0D;
    end;

    procedure DTETransferLine(TransferHeader: Record "Transfer Header"): JsonArray
    var
        TransferLIne: Record "Transfer Line";
        TranfLineInfo: JsonObject;
        Item_l: Record Item;
        UM_l: Record "Item Unit of Measure";
        UnitCost: Decimal;
        TotalCost: Decimal;
        TotalLine: Decimal;
        Array: JsonArray;
    begin
        TransferLIne.RESET;
        TransferLIne.SETRANGE(TransferLIne."Document No.", TransferHeader."No.");
        TransferLIne.SETRANGE(TransferLIne."Derived From Line No.", 0);
        TransferLIne.SETFILTER(TransferLIne.Quantity, '>0');
        TransferLIne.FIND('-');
        REPEAT

            Item_l.GET(TransferLIne."Item No.");
            UM_l.GET(TransferLIne."Item No.", TransferLIne."Unit of Measure");
            IF Item_l."Unit Cost" = 0 THEN
                Item_l."Unit Cost" := 0.01;

            UnitCost := Item_l."Unit Cost" * UM_l."Qty. per Unit of Measure";
            TotalCost += ROUND(UnitCost * TransferLIne.Quantity, 0.01);
            TotalLine := ROUND(UnitCost * TransferLIne.Quantity, 0.01);
            UnitCost := ROUND(TotalLine / TransferLIne.Quantity, 0.00001);

            Clear(TranfLineInfo);
            TranfLineInfo.Add('Code', TransferLIne."Item No.");
            TranfLineInfo.Add('Name', TransferLIne.Description);
            TranfLineInfo.Add('UnitOfMeasure', '59');
            TranfLineInfo.Add('ProductType', '1');
            TranfLineInfo.Add('Quantity', DELCHR(FORMAT(TransferLIne.Quantity)));
            TranfLineInfo.Add('SuggestedSalePrice', '0.00');
            TranfLineInfo.Add('Discount', '0.00');
            TranfLineInfo.Add('NO_GRAVADO', '0.00');
            TranfLineInfo.Add('VENTA_NO_SUJETA', '0.00');
            TranfLineInfo.Add('VENTA_EXENTA', '0.00');
            TranfLineInfo.Add('VENTA_GRAVADA', DELCHR(FORMAT(TotalLine)));
            TranfLineInfo.Add('Total', DELCHR(FORMAT(TotalLine)));
            TranfLineInfo.Add('price', DELCHR(FORMAT(UnitCost)));
            TranfLineInfo.Add('Document', 'null');
            array.Add(TranfLineInfo);
        until TransferLIne.Next() = 0;
        exit(Array);
    end;


    /*[EventSubscriber(ObjectType::Codeunit, Codeunit::"TransferOrder-Post + Print", 'OnAfterPost', '', true, true)]
    local procedure "TransferOrder-Post + Print_OnAfterPost"
    (
        var TransHeader: Record "Transfer Header";
        Selection: Option
    )
    begin
        CASE Selection of
            1:
                begin
                    SendDTE(TransHeader, TRUE);
                end;
        END;
    end;*/

    procedure GetTokenAPIDTE(FSNParameter: Record "FSN Parameter"; pBody: Text; Number: Code[20]; var DTESignature: Text[50]; var TokenDTE: Text): Text
    var
        HttpResponseMessage: DotNet HttpResponseMessage;
        result: Text[1024];
        JArray: DotNet JArray;
        JObject: DotNet JObject;
        jObjectFilt: JsonObject;
        JToken: DotNet JToken;
        p: Record "LSC POS Menu Line";
        RESPONSEGLOBAL: Text;
        BODYGLOBAL: Text;
        SRFREQUEST: Text;
        SRFBANVALUE: Text;
        OD: Codeunit "FSN OData Conexion";
        requestHeader, contentHeader : HttpHeaders;
        body: HttpContent;
        request: HttpRequestMessage;
        CodeResultS: Integer;
        response: JsonObject;
        token: JsonToken;
        jTok: JsonToken;
        requestObject: JsonObject;
        JsonTokenValText: Text;
        sb: DotNet StringBuilder;
        JsonInfo, date_txt : Text;
        date: Date;
    begin

        IF FSNParameter.GET('DTE_INVOICE', 'TRANS_TOKEN') THEN
            IF FSNParameter.Activo THEN BEGIN


                if fsnParameter."String Parameters 1 Json" <> '' then begin
                    JsonInfo := fsnParameter."String Parameters 1 Json" + fsnParameter."String Parameters 2 Json";
                    jObjectFilt.ReadFrom(JsonInfo);

                    if jObjectFilt.SelectToken('expirationDate', jTok) then begin
                        date_txt := jTok.AsValue().AsText();
                        Evaluate(date, date_txt);
                        if Today() < date then begin
                            jObjectFilt.SelectToken('token', jTok);
                            TokenDTE := jTok.AsValue().AsText();
                            exit(TokenDTE);
                        end;
                    end;
                end;

                requestObject.Add('username', FSNParameter.SetFilterData1);
                requestObject.Add('password', FSNParameter.SetFilterData2);

                requestObject.WriteTo(JsonTokenValText);
                sb := sb.StringBuilder();
                sb.Append(JsonTokenValText);

                pBody := JsonTokenValText;
                SRFREQUEST := FSNParameter."Web Uri";
                SRFBANVALUE := 'application/json';

                RESPONSEGLOBAL := '';
                //NEW 28981
                body.WriteFrom(pBody);
                body.GetHeaders(contentHeader);
                contentHeader.Clear();
                contentHeader.Add('Content-Type', 'application/json');
                request.GetHeaders(requestHeader);
                requestHeader.Clear();
                request.Content := body;
                response := Post(SRFREQUEST, request, CodeResultS);

                if CodeResultS = 200 then begin
                    IF response.SelectToken('token', token) THEN begin
                        RESPONSEGLOBAL := token.AsValue().AsText();
                        TokenDTE := token.AsValue().AsText();
                    end;

                    FSNParameter."String Parameters 1 Json" := CopyStr(Format(response), 1, 250);
                    FSNParameter."String Parameters 2 Json" := CopyStr(Format(response), 251, 250);
                    FSNParameter.Modify();
                    Commit();
                END;

                IF RESPONSEGLOBAL = '' THEN BEGIN

                    IF response.SelectToken('statusMesage', token) THEN
                        result := token.AsValue().AsText();

                    p."Primary Key" := Number + '_R';
                    SaveXML(p, 1, format(response));
                    p."Primary Key" := Number;
                    SaveXML(p, 1, pBody);

                    ERROR(STRSUBSTNO('No se pudo crear remision electronica \%1', result));
                END;

                EXIT(RESPONSEGLOBAL);

                RESPONSEGLOBAL := '';
            END;

    end;

    procedure DTERemission(pBody: Text; Number: Code[20]; var DTESignature: Text[50]; var DTEAuth: Text[50]; var TokenV: Text): Text[50]
    var
        Parameters: DotNet Dictionary_Of_T_U;
        HttpResponseMessage: DotNet HttpResponseMessage;
        result: Text[1024];
        JArray: DotNet JArray;
        JObject: DotNet JObject;
        JToken: DotNet JToken;
        //DriverTip: Record "50075";
        //PostedDriverTip: Record "50076";
        p: Record "LSC POS Menu Line";
        RESPONSEGLOBAL: Text;
        BODYGLOBAL: Text;
        SRFREQUEST: Text;
        SRFBANVALUE: Text;
        OD: Codeunit "FSN OData Conexion";
        requestHeader, contentHeader : HttpHeaders;
        body: HttpContent;
        request: HttpRequestMessage;
        CodeResultS: Integer;
        response: JsonObject;
        token: JsonToken;
        FSNParameter: Record "FSN Parameter";
    begin

        IF FSNParameter.GET('DTE_INVOICE', 'TRANSFER') THEN
            IF FSNParameter.Activo THEN BEGIN
                BODYGLOBAL := pBody;
                SRFREQUEST := FSNParameter."Web Uri";
                SRFBANVALUE := 'application/json';

                RESPONSEGLOBAL := '';
                //NEW
                body.WriteFrom(pBody);
                body.GetHeaders(contentHeader);
                contentHeader.Clear();
                contentHeader.Add('Content-Type', 'application/json');
                request.GetHeaders(requestHeader);
                requestHeader.Clear();
                request.Content := body;
                if TokenV <> '' then
                    requestheader.Add('Authorization', 'Bearer ' + TokenV);
                response := Post(SRFREQUEST, request, CodeResultS);

                if CodeResultS = 200 then begin
                    IF response.SelectToken('authNumber', token) THEN begin
                        RESPONSEGLOBAL := token.AsValue().AsText();
                        DTEAuth := token.AsValue().AsText();
                    end;

                    IF response.SelectToken('selloRecepcion', token) THEN
                        DTESignature := token.AsValue().AsText();
                END;

                IF RESPONSEGLOBAL = '' THEN BEGIN

                    IF response.SelectToken('statusMessage', token) THEN
                        result := token.AsValue().AsText();

                    p."Primary Key" := Number + '_R';
                    SaveXML(p, 1, format(response));
                    p."Primary Key" := Number;
                    SaveXML(p, 1, pBody);

                    ERROR(STRSUBSTNO('No se pudo crear remision electronica \%1', result));
                END;

                EXIT(RESPONSEGLOBAL);

                RESPONSEGLOBAL := '';
            END;
    end;

    procedure Post(Uri: Text; request: HttpRequestMessage; var CodeResult: Integer): JsonObject;
    var
        client: HttpClient;
        response: HttpResponseMessage;
        content: HttpContent;
        status: Integer;
        res: Text;
        jResponse: JsonObject;
    begin
        CodeResult := 0;
        request.Method := 'POST';
        request.SetRequestUri(uri);
        client.Send(request, response);
        content := response.Content;
        status := response.HttpStatusCode;
        //if status = 200 then begin
        content.ReadAs(res);
        jResponse.ReadFrom(res);
        CodeResult := status;
        exit(jResponse);
        //end;
    end;

    procedure SendDTENAV(var Transfer: Record "Transfer Header"; Production: Boolean)
    var
        ToStore: Record "LSC Store";
        FromStore: Record "LSC Store";
        Json: Text;
        TransferLIne: Record "Transfer Line";
        FSN_DTE: Record "FSN DTE Transaction Header";
        NoSerie: Codeunit "NoSeriesManagement";
        NextSerie: Code[35];
        Item_l: Record Item;
        UM_l: Record "Item Unit of Measure";
        TotalCost: Decimal;
        i: Integer;
        OD: Codeunit "FSN OData Conexion";
        e: Boolean;
        p: Record "LSC POS Menu Line";
        UnitCost: Decimal;
        TotalLine: Decimal;
        codeMH: Text[10];
        CodeNameMH: Text[10];
        DTEAuth_: Text[50];
        DTESign_: Text[50];
        NoText: array[2] of Text[75];
        FSN: Codeunit "FSN Utility";
        TxtDollars: Text;
        RespCenter: Record "Responsibility Center";
        StoreFiltDTE: Record "LSC Store";
        TerminalFiltDTE: Record "LSC POS Terminal";
        jsonInfo, SellerInfo, AddressInfo, BuyerInfo, TaxInfo, BuyerAddressInfo, ProductListInfo : JsonObject;
        JSonStringInformation: Text;
        sb: DotNet StringBuilder;
    begin

        CLEAR(FSN_DTE);
        CLEAR(e);

        IF STRLEN(Transfer."No.") > 10 THEN BEGIN
            IF FSN_DTE.GET(COPYSTR(Transfer."No.", 1, 10), COPYSTR(Transfer."No.", 11, 10), 0) THEN BEGIN
                IF Transfer."External Document No." <> FSN_DTE."DTE Invoice" THEN BEGIN
                    Transfer."External Document No." := FSN_DTE."DTE Invoice";
                    Transfer.MODIFY;
                END;
                e := TRUE;
                IF FSN_DTE."DTE AuthNumber" <> '' THEN
                    EXIT;
            END;
        END ELSE
            IF FSN_DTE.GET(Transfer."No.", '1', 0) THEN BEGIN
                IF Transfer."External Document No." <> FSN_DTE."DTE Invoice" THEN BEGIN
                    Transfer."External Document No." := FSN_DTE."DTE Invoice";
                    Transfer.MODIFY;
                END;

                e := TRUE;
                IF FSN_DTE."DTE AuthNumber" <> '' THEN
                    EXIT;
            END;
        FromStore.GET(Transfer."LSC Store-from");
        ToStore.GET(Transfer."LSC Store-to");
        StoreFiltDTE.GET(Transfer."LSC Store-from");
        RespCenter.Get(StoreFiltDTE."No.");
        TerminalFiltDTE.Reset();
        TerminalFiltDTE.SetRange("Store No.", StoreFiltDTE."No.");
        TerminalFiltDTE.SetRange(TerminalFiltDTE."DTE CodeSellingPointMH", 'P002');
        IF TerminalFiltDTE.FindFirst() THEN;
        IF NOT e THEN BEGIN
            FSN_DTE.INIT;
            FSN_DTE."Store No." := COPYSTR(Transfer."No.", 1, 10);
            IF STRLEN(Transfer."No.") > 10 THEN
                FSN_DTE."POS Terminal No." := COPYSTR(Transfer."No.", 11, 10)
            ELSE
                FSN_DTE."POS Terminal No." := '1';
            FSN_DTE."Transaction No." := 0;
            FSN_DTE."Creating Date" := TODAY;
            FSN_DTE."Document Type" := '04';

            NextSerie := NoSerie.GetNextNo((COPYSTR(FromStore."No.", 1, 5) + 'TRDTE'), TODAY, TRUE);
            FSN_DTE."DTE EnrolledTimeStamp" := NextSerie;
            StoreFiltDTE.GET(Transfer."LSC Store-from");
            RespCenter.Get(StoreFiltDTE."No.");
            TerminalFiltDTE.Reset();
            TerminalFiltDTE.SetRange("Store No.", StoreFiltDTE."No.");
            TerminalFiltDTE.SetRange(TerminalFiltDTE."DTE CodeSellingPointMH", 'P002');
            IF TerminalFiltDTE.FindFirst() THEN;
            //IF FSNParameter.GET(Transfer."Store-from") AND (FSNParameter."DTE Store" <> '') AND (FSNParameter."DTE Terminal" <> '') THEN
            FSN_DTE."DTE Invoice" := 'DTE-04-' + StoreFiltDTE."DTE CodeEstablishmentMH" + TerminalFiltDTE."DTE CodeSellingPointMH" + '-' + NextSerie;
            //ELSE
            //FSN_DTE."DTE Invoice" := 'DTE-04-00' + COPYSTR(Transfer."Store-from",2,2) + '0000-' +  NextSerie;
            FSN_DTE.INSERT(true);

            Transfer."External Document No." := FSN_DTE."DTE Invoice";
            Transfer.MODIFY;
        END;

        IF NOT Production THEN
            EXIT;
        COMMIT;
        i := 0;

        IF FromStore."No." = 'DIFERENCIA' THEN
            CodeNameMH := 'AUX1'
        ELSE
            CodeNameMH := StoreFiltDTE."DTE CodeEstablishmentMH";

        codeMH := StoreFiltDTE."DTE CodeEstablishmentMH";

        Json :=
        '{' +
        '"DocumentType":"04",' +
        '"OperationType":"01",' +
        '"IssuedDate":"' + FORMAT(DATE2DMY(TODAY, 3)) + '-' + FORMAT(DATE2DMY(TODAY, 2)) + '-' + FORMAT(DATE2DMY(TODAY, 1)) + '",' +
        '"IssuedTime":"' + FORMAT(TIME, 9) + '",' +
        '"IdShop":"' + CodeNameMH + '",' +
        '"Secuencial":"' + FSN_DTE."DTE EnrolledTimeStamp" + '",' +
        '"TransNo":"' + FSN_DTE."DTE EnrolledTimeStamp" + '",' +
        '"PrintTicket":false,' +
        '"Contingency":null,' +
        '"Seller":{' +
        '"Name":"Farmacia San Nicolas S.A. de C.V.",' +
        '"NRC":"406-5",' +
        '"NIT":"0614-221265-001-4",' +
        '"CodeSellingPoint":"' + 'P002' + '",' +
        '"CodeSellingPointMH":"' + 'P002' + '",' +
        '"TypeEstablishment":"01",' +
        '"CodeEstablishment":"' + CodeNameMH + '",' +
        '"codeEstablishmentMH":"' + codeMH + '",' +
        '"Phone":"2555-5555",' +
        '"Email":"' + RespCenter."E-Mail" + '",' +
        '"ActivityCode":"46491",' +
        '"ActivityDesc":"Venta al por mayor de productos medicinales, cosméticos, perfumería y productos de limpieza",' +
        '"Address":{' +
        '"AddressLine":"' + FromStore.Address + '",' +
        '"District":"05",' +
        '"State":"01"' +
        '}' +
        '},';

        Json +=
        '"Buyer":{' +
        '"NRC":"406-5",' +
        '"TaxInformation":{' +
        '"ID":"36",' +
        '"Value":"0614-221265-001-4"' +
        '},' +
        '"ActivityCode":"46491",' +
        '"ActivityDesc":"Venta al por mayor de productos medicinales, cosméticos, perfumería y productos de limpieza",' +
        '"Name":"Farmacia San Nicolas S.A. de C.V.",' +
        '"ComercialName":"' + ToStore.Name + '",' +
        '"Phone":"22253733",' +
        '"Email":"' + RespCenter."E-Mail" + '",' +
        '"Address":{' +
        '"AddressLine":"' + ToStore.Address + '",' +
        '"District":"11",' +
        '"State":"05"' +
        '},' +
        '"BienTitulo":"04"' +
        '},' +
        '"ProductList":[';

        TotalCost := 0;
        i := 0;

        TransferLIne.RESET;
        TransferLIne.SETRANGE(TransferLIne."Document No.", Transfer."No.");
        TransferLIne.SETRANGE(TransferLIne."Derived From Line No.", 0);
        TransferLIne.SETFILTER(TransferLIne.Quantity, '>0');
        TransferLIne.FIND('-');
        REPEAT
            IF i > 0 THEN
                Json += ',';

            i += 1;


            Item_l.GET(TransferLIne."Item No.");
            UM_l.GET(TransferLIne."Item No.", TransferLIne."Unit of Measure");
            IF Item_l."Unit Cost" = 0 THEN
                Item_l."Unit Cost" := 0.01;

            UnitCost := Item_l."Unit Cost" * UM_l."Qty. per Unit of Measure";
            TotalCost += ROUND(UnitCost * TransferLIne.Quantity, 0.01);
            TotalLine := ROUND(UnitCost * TransferLIne.Quantity, 0.01);
            UnitCost := ROUND(TotalLine / TransferLIne.Quantity, 0.00001);

            Json +=
              '{' +
              '"Code":"' + TransferLIne."Item No." + '",' +
              '"Name":"' + DELCHR(TransferLIne.Description, '=', '"') + '",' +
              '"UnitOfMeasure":"59",' +
              '"ProductType":"1",' +
              '"Quantity":"' + DELCHR(FORMAT(TransferLIne.Quantity), '=', ',') + '",' +
              '"SuggestedSalePrice":"0.00",' +
              '"Discount":"0.00",' +
              '"NO_GRAVADO":"0.00",' +
              '"VENTA_NO_SUJETA":"0.00",' +
              '"VENTA_EXENTA":"0.00",' +
              '"VENTA_GRAVADA":"' + DELCHR(FORMAT(TotalLine), '=', ',') + '",' +
              '"Total":"' + DELCHR(FORMAT(TotalLine), '=', ',') + '",' +
              '"price":"' + DELCHR(FORMAT(UnitCost), '=', ',') + '",' +
              '"Document":null' +
              '}';

        UNTIL TransferLIne.NEXT = 0;

        CLEAR(NoText);
        CLEAR(FSN);
        //TxtDollars := FSN.FormatNoText1(NoText, ABS(ROUND(TotalCost * 0.13, 0.01) + TotalCost));
        TxtDollars := FSN.Num2Text(ABS(ROUND(TotalCost * 0.13, 0.01) + TotalCost));

        Json +=
        '],' +
        '"PaymentList":null,' +
        '"Totals":{' +
        '"SubTotal":"' + DELCHR(FORMAT(TotalCost), '=', ',') + '",' +
        '"TOTAL_NO_GRAVADO":"0.00",' +
        '"TOTAL_NO_SUJETA":"0.00",' +
        '"Discounts":{' +
        '"Exento":"0.00",' +
        '"Gravado":"0.00"' +
        '},' +
        '"TOTAL_EXENTO":"0.00",' +
        '"TOTAL_GRAVADO":"' + DELCHR(FORMAT(TotalCost), '=', ',') + '",' +
        '"IVA":"' + FORMAT(ROUND(TotalCost * 0.13, 0.01)) + '",' +
        '"IvaPercibido":"0.00",' +
        '"IvaRetenido":"0.00",' +
        '"RetencionRenta":"0.00",' +
        '"InWords":"' + TxtDollars + '",' +
        '"Amount":"' + DELCHR(FORMAT(ROUND(TotalCost * 0.13, 0.01) + TotalCost), '=', ',') + '"' +
        '},' +
        '"adenda":[' +
        '{' +
        '"name":"SucDestino",' +
        '"data":"SucDestino",' +
        '"value":"' + ToStore.Name + ' ' + Transfer."No." + '"' +
        '}' +
        ']' +
        '}';

        //DTERemission(Json, Transfer."No.", DTESign_, DTEAuth_);

        IF DTEAuth_ <> '' THEN BEGIN
            FSN_DTE."DTE AuthNumber" := DTEAuth_;
            FSN_DTE."Signature Validation" := DTESign_;
            FSN_DTE.MODIFY(true);
            COMMIT;

        END ELSE
            ERROR('Error al generar remision electronica.');
    end;

    procedure SaveXML(pParameter: Record "LSC POS Menu Line"; pType: Integer; pText: Text)
    var
        FileMgt: Codeunit "File Management";
        FilterString: Text;
        FileSystem: DotNet StreamWriter;
        SRFTXN: Text;
    begin
        FilterString := 'C:\temp\WSFSN\' + pParameter."Primary Key" + pParameter."Current-RECEIPT" + '.xml';
        IF not FileMgt.ClientDirectoryExists('C:\temp\WSFSN') THEN BEGIN
            FileSystem := FileSystem.StreamWriter(FilterString);
            CASE pType OF
                0:
                    FileSystem.Write(SRFTXN);
                1:
                    FileSystem.Write(pText);
            END;
            FileSystem.Close();
        END;
    end;

    local procedure serializeDecimal(mount: Decimal): Text
    begin
        exit(DelChr(Format(Abs(mount)), '=', ','));
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
        PurchRcptHeader: Record "Purch. Rcpt. Header";
        POSMenuLineTemp: Record "LSC POS Menu Line" temporary;
        PurchCrMemo: Record "Purch. Cr. Memo Hdr.";
        PurchInvHeader: Record "Purch. Inv. Header";
        SalesInvHeader: Record "Sales Invoice Header";
        SalesCrMemo: Record "Sales Cr.Memo Header";
        FSNDte: Record "FSN DTE Transaction Header";
        CurrentYear: Integer;
        YearStart: Date;
        YearEnd: Date;
        lTex001: Label 'El %1 %2 Ya fue registrado';
        FSN_CorrectionDTE: Page "FSN Correction DTE";
        SalesHeader: Record "Sales Header";
    begin

        if RequestID = 'VENDING' then begin
            IF SalesHeader.GET(SalesHeader."Document Type"::Invoice, XMLRequest) THEN BEGIN
                SalesHeader."DTE Invoice" := POSMenuLine."Set Current-Input";
                SalesHeader."DTE AuthNumber" := POSMenuLine."Current-Description";
                SalesHeader."Signature Validation" := POSMenuLine."Current-Description2";
                SalesHeader."External Document No." := POSMenuLine."Set Current-Input";
                SalesHeader.Modify(true);
            END;
        end;

        CurrentYear := Date2DMY(WorkDate, 3);
        YearStart := DMY2Date(1, 1, CurrentYear);
        YearEnd := DMY2Date(31, 12, CurrentYear);

        if RequestID = 'DTE-LIBROIVA' then begin
            IF PurchRcptHeader.Get(XMLRequest) THEN begin
                POSMenuLineTemp.Reset();
                POSMenuLineTemp.Init();
                POSMenuLineTemp."Profile ID" := 'FASANI';
                POSMenuLineTemp."Menu ID" := 'LIVDTE';
                POSMenuLineTemp."Key No." := 1;
                POSMenuLineTemp."Set Current-Input" := PurchRcptHeader."DTE Invoice";
                POSMenuLineTemp."Current-Description" := PurchRcptHeader."DTE AuthNumber";
                POSMenuLineTemp."Current-Description2" := PurchRcptHeader."Signature Validation";
                POSMenuLineTemp.Insert();
                POSMenuLine := POSMenuLineTemp;
            end;
        end;
        if RequestID = 'UPD-DTE-HISRECPUR' then begin
            PurchRcptHeader.Reset();
            PurchRcptHeader.SetFilter("No.", '%1', XMLRequest);
            if PurchRcptHeader.FindFirst() then begin
                PurchRcptHeader."DTE Invoice" := POSMenuLine."Set Current-Input";
                PurchRcptHeader."DTE AuthNumber" := POSMenuLine."Current-Description";
                PurchRcptHeader."Signature Validation" := POSMenuLine."Current-Description2";
                PurchRcptHeader."No. Credit Memo Associated" := POSMenuLine."Original Description";
                PurchRcptHeader."FSN Withholding Tax Amount" := POSMenuLine."Current-Price";
                PurchRcptHeader.Modify(true);
            end;
        end;
        if RequestID = 'UPD-DTE-HISPURMEM' then begin
            PurchCrMemo.Reset();
            PurchCrMemo.SetFilter("No.", '%1', XMLRequest);
            if PurchCrMemo.FindFirst() then begin
                PurchCrMemo."DTE Invoice" := POSMenuLine."Set Current-Input";
                PurchCrMemo."DTE AuthNumber" := POSMenuLine."Current-Description";
                PurchCrMemo."Signature Validation" := POSMenuLine."Current-Description2";
                PurchCrMemo."FSN Withholding Tax Amount" := POSMenuLine."Current-Price";
                PurchCrMemo.Modify(true);
            end;
        end;
        if RequestID = 'SELE-DTE-HISPURCINV' then begin
            //Purchase
            //Validar DTE
            PurchInvHeader.Reset();
            PurchInvHeader.SetFilter("DTE Invoice", '%1', POSMenuLine."Set Current-Input");
            PurchInvHeader.SetFilter("Buy-from Vendor No.", '%1', POSMenuLine."Current-RECEIPT");
            PurchInvHeader.SetRange("Posting Date", YearStart, YearEnd);
            if PurchInvHeader.FindFirst() then
                Error(lTex001, PurchInvHeader.FieldCaption("DTE Invoice"), POSMenuLine."Set Current-Input");
            //Validar Codigo Generacion
            PurchInvHeader.Reset();
            PurchInvHeader.SetFilter("DTE AuthNumber", '%1', POSMenuLine."Current-Description");
            if PurchInvHeader.FindFirst() then
                Error(lTex001, PurchInvHeader.FieldCaption("DTE AuthNumber"), POSMenuLine."Current-Description");
            //Validar Sello de Recepcion
            PurchInvHeader.Reset();
            PurchInvHeader.SetFilter("Signature Validation", '%1', POSMenuLine."Current-Description2");
            if PurchInvHeader.FindFirst() then
                Error(lTex001, PurchInvHeader.FieldCaption("Signature Validation"), POSMenuLine."Current-Description2");
        end;
        if RequestID = 'SELE-DTE-HISPURCMEM' then begin
            //Purchase
            //Validar DTE
            PurchCrMemo.Reset();
            PurchCrMemo.SetFilter("DTE Invoice", '%1', POSMenuLine."Set Current-Input");
            PurchCrMemo.SetFilter("Buy-from Vendor No.", '%1', POSMenuLine."Current-RECEIPT");
            PurchCrMemo.SetRange("Posting Date", YearStart, YearEnd);
            if PurchCrMemo.FindFirst() then
                Error(lTex001, PurchCrMemo.FieldCaption("DTE Invoice"), POSMenuLine."Set Current-Input");
            //Validar Codigo Generacion
            PurchCrMemo.Reset();
            PurchCrMemo.SetFilter("DTE AuthNumber", '%1', POSMenuLine."Current-Description");
            if PurchCrMemo.FindFirst() then
                Error(lTex001, PurchCrMemo.FieldCaption("DTE AuthNumber"), POSMenuLine."Current-Description");
            //Validar Sello de Recepcion
            PurchCrMemo.Reset();
            PurchCrMemo.SetFilter("Signature Validation", '%1', POSMenuLine."Current-Description2");
            if PurchCrMemo.FindFirst() then
                Error(lTex001, PurchCrMemo.FieldCaption("Signature Validation"), POSMenuLine."Current-Description2");
        end;
        if RequestID = 'SELE-DTE-HISRCPT' then begin
            //Purchase
            //Validar DTE
            PurchRcptHeader.Reset();
            PurchRcptHeader.SetFilter("DTE Invoice", '%1', POSMenuLine."Set Current-Input");
            PurchRcptHeader.SetFilter("Buy-from Vendor No.", '%1', POSMenuLine."Current-RECEIPT");
            PurchRcptHeader.SetRange("Posting Date", YearStart, YearEnd);
            if PurchRcptHeader.FindFirst() then
                Error(lTex001, PurchRcptHeader.FieldCaption("DTE Invoice"), POSMenuLine."Set Current-Input");
            //Validar Codigo Generacion
            PurchRcptHeader.Reset();
            PurchRcptHeader.SetFilter("DTE AuthNumber", '%1', POSMenuLine."Current-Description");
            if PurchRcptHeader.FindFirst() then
                Error(lTex001, PurchRcptHeader.FieldCaption("DTE AuthNumber"), POSMenuLine."Current-Description");

        end;
        if RequestID = 'DTE-CUSTLEDGENTRY' then begin
            FSNDte.Reset();
            FSNDte.SetRange("Store No.", POSMenuLine."Current-MENU2");
            FSNDte.SetRange("POS Terminal No.", POSMenuLine."Current-MENU3");
            FSNDte.SetRange("Transaction No.", POSMenuLine."POS Key Code");
            if FSNDte.FindFirst() then begin
                POSMenuLineTemp."Set Current-Input" := FSNDte."DTE Invoice";
                POSMenuLineTemp."Current-Description" := FSNDte."DTE AuthNumber";
                POSMenuLineTemp."Current-Description2" := FSNDte."Signature Validation";
                POSMenuLine := POSMenuLineTemp;
            end;
        end;
        if RequestID = 'DTE-VENDLEDGENTRY' then begin
            PurchInvHeader.Reset();
            PurchInvHeader.SetRange("No.", POSMenuLine."Menu ID");
            if PurchInvHeader.FindFirst() then begin
                POSMenuLine."Set Current-Input" := PurchInvHeader."DTE Invoice";
                POSMenuLine."Current-Description" := PurchInvHeader."DTE AuthNumber";
                POSMenuLine."Current-Description2" := PurchInvHeader."Signature Validation";
            end;
        end;
        if RequestID = 'DTE-CUST-INV-BC' then begin
            SalesInvHeader.Reset();
            SalesInvHeader.SetRange("No.", POSMenuLine."Menu ID");
            if SalesInvHeader.FindFirst() then begin
                POSMenuLine."Set Current-Input" := SalesInvHeader."DTE Invoice";
                POSMenuLine."Current-Description" := SalesInvHeader."DTE AuthNumber";
                POSMenuLine."Current-Description2" := SalesInvHeader."Signature Validation";
            end;
        end;
        if RequestID = 'DTE-CUST-SCRM-BC' then begin
            PurchInvHeader.Reset();
            PurchInvHeader.SetRange("No.", POSMenuLine."Menu ID");
            if PurchInvHeader.FindFirst() then begin
                POSMenuLine."Set Current-Input" := PurchInvHeader."DTE Invoice";
                POSMenuLine."Current-Description" := PurchInvHeader."DTE AuthNumber";
                POSMenuLine."Current-Description2" := PurchInvHeader."Signature Validation";
            end;
        end;
        if RequestID = 'DTE-VEND-INV-BC' then begin
            SalesInvHeader.Reset();
            SalesInvHeader.SetRange("No.", POSMenuLine."Menu ID");
            if SalesInvHeader.FindFirst() then begin
                POSMenuLine."Set Current-Input" := SalesInvHeader."DTE Invoice";
                POSMenuLine."Current-Description" := SalesInvHeader."DTE AuthNumber";
                POSMenuLine."Current-Description2" := SalesInvHeader."Signature Validation";
            end;
        end;
        if RequestID = 'DTE-VEND-PCRM-BC' then begin
            PurchCrMemo.Reset();
            PurchCrMemo.SetRange("No.", POSMenuLine."Menu ID");
            if PurchCrMemo.FindFirst() then begin
                POSMenuLine."Set Current-Input" := PurchCrMemo."DTE Invoice";
                POSMenuLine."Current-Description" := PurchCrMemo."DTE AuthNumber";
                POSMenuLine."Current-Description2" := PurchCrMemo."Signature Validation";
            end;
        end;
        IF RequestID = 'DTE-OPEN-PAGE' THEN BEGIN
            FSN_CorrectionDTE.MenuLine(PosMenuLine);
            FSN_CorrectionDTE.RunModal();
        END;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnBeforePostSalesDoc', '', true, true)]
    local procedure "Sales-Post_OnBeforePostSalesDoc"
    (
      var SalesHeader: Record "Sales Header";
      CommitIsSuppressed: Boolean;
      PreviewMode: Boolean;
      var HideProgressWindow: Boolean
    )
    var
        SalesInvHeader: Record "Sales Invoice Header";
        SalesCrMemo: Record "Sales Cr.Memo Header";
        lTex001: Label 'El %1 %2 Ya fue registrado';
    begin
        //Verificiar si es registro con DTE verificar que los campos no esten vacios
        if SalesHeader."DTE Invoice" <> '' then begin
            if SalesHeader."DTE AuthNumber" = '' then
                Error('El campo Codigo Generacion no puede estar vacio.');
            if SalesHeader."Signature Validation" = '' then
                Error('El campo Sello Validacion no puede estar vacio.');
            with SalesHeader do
                case "Document Type" of
                    "Document Type"::Invoice, "Document Type"::Order:
                        begin
                            //Sales
                            //Validar DTE
                            SalesInvHeader.Reset();
                            SalesInvHeader.SetFilter("DTE Invoice", '%1', SalesHeader."DTE Invoice");
                            SalesInvHeader.SetFilter("Sell-to Customer No.", '%1', SalesHeader."Sell-to Customer No.");
                            if SalesInvHeader.FindFirst() then
                                Error(lTex001, SalesInvHeader.FieldCaption("DTE Invoice"), SalesHeader."DTE Invoice");
                            //Validar Codigo Generacion
                            SalesInvHeader.Reset();
                            SalesInvHeader.SetFilter("DTE AuthNumber", '%1', SalesHeader."DTE AuthNumber");
                            if SalesInvHeader.FindFirst() then
                                Error(lTex001, SalesInvHeader.FieldCaption("DTE AuthNumber"), SalesHeader."DTE AuthNumber");
                            //Validar Sello de Recepcion
                            SalesInvHeader.Reset();
                            SalesInvHeader.SetFilter("Signature Validation", '%1', SalesHeader."Signature Validation");
                            if SalesInvHeader.FindFirst() then
                                Error(lTex001, SalesInvHeader.FieldCaption("Signature Validation"), SalesHeader."Signature Validation");

                        end;
                    "Document Type"::"Credit Memo", "Document Type"::"Return Order":
                        begin
                            //Sales
                            //Validar DTE
                            SalesCrMemo.Reset();
                            SalesCrMemo.SetFilter("DTE Invoice", '%1', SalesHeader."DTE Invoice");
                            SalesCrMemo.SetFilter("Sell-to Customer No.", '%1', SalesHeader."Sell-to Customer No.");
                            if SalesCrMemo.FindFirst() then
                                Error(lTex001, SalesCrMemo.FieldCaption("DTE Invoice"), SalesHeader."DTE Invoice");
                            //Validar Codigo Generacion
                            SalesCrMemo.Reset();
                            SalesCrMemo.SetFilter("DTE AuthNumber", '%1', SalesHeader."DTE AuthNumber");
                            if SalesCrMemo.FindFirst() then
                                Error(lTex001, SalesCrMemo.FieldCaption("DTE AuthNumber"), SalesHeader."DTE AuthNumber");
                            //Validar Sello de Recepcion
                            SalesCrMemo.Reset();
                            SalesCrMemo.SetFilter("Signature Validation", '%1', SalesHeader."Signature Validation");
                            if SalesCrMemo.FindFirst() then
                                Error(lTex001, SalesCrMemo.FieldCaption("Signature Validation"), SalesHeader."Signature Validation");
                        end;
                end;
        end;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Purch. Inv. Header", 'OnAfterInsertEvent', '', true, true)]
    local procedure "Purch. Inv. Header_OnAfterInsertEvent"
        (
            var Rec: Record "Purch. Inv. Header";
            RunTrigger: Boolean
        )
    var
        ErrorMessage: Text;
    begin
        // Solo validar si RunTrigger es True (no durante eliminaciones)
        if not RunTrigger then
            exit;

        // Validar datos DTE después de que la factura se registre
        ValidatePurchInvHeaderDTE(Rec, ErrorMessage);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Purch. Cr. Memo Hdr.", 'OnAfterInsertEvent', '', true, true)]
    local procedure "Purch. Cr. Memo Hdr_OnAfterInsertEvent"
    (
        var Rec: Record "Purch. Cr. Memo Hdr.";
        RunTrigger: Boolean
    )
    var
        ErrorMessage: Text;
    begin
        // Solo validar si RunTrigger es True (no durante eliminaciones)
        if not RunTrigger then
            exit;

        // Validar datos DTE después de que la nota de crédito se registre
        ValidatePurchCrMemoHeaderDTE(Rec, ErrorMessage);
    end;

    procedure ValidatePurchInvHeaderDTE(var PurchInvHeader: Record "Purch. Inv. Header"; var ErrorMessage: Text)
    var
        PurchInvHeader2: Record "Purch. Inv. Header";
        PurchCrMemoHdr: Record "Purch. Cr. Memo Hdr.";
        DTEInvoice: Code[31];
        SignatureValidation: Text[50];
        DTEAuthNumber: Code[36];
        CurrentYear: Integer;
        DuplicateCount: Integer;
        lText001: Label 'El campo %1 "%2" ya existe en el documento %3 %4. No se permiten valores duplicados.';
        lText002: Label 'El DTE "%1" ya ha sido duplicado. No se permite duplicar más de una vez por año.';
    begin
        /* ErrorMessage := '';

         // Evitar validar documentos cancelados o vacíos
         if PurchInvHeader."No." = '' then
             exit;

         DTEInvoice := PurchInvHeader."DTE Invoice";
         DTEAuthNumber := PurchInvHeader."DTE AuthNumber";
         SignatureValidation := PurchInvHeader."Signature Validation";

         // Si no hay datos DTE, no validar
         if (DTEInvoice = '') and (DTEAuthNumber = '') and (SignatureValidation = '') then
             exit;

         CurrentYear := Date2DMY(PurchInvHeader."Posting Date", 3);

         // VALIDACIÓN 1: DTE no puede duplicarse más de una vez por año POR PROVEEDOR
         if DTEInvoice <> '' then begin
             DuplicateCount := 0;

             // Contar en facturas del mismo año, mismo proveedor (excluyendo el documento actual)
             PurchInvHeader2.Reset();
             PurchInvHeader2.SetRange("DTE Invoice", DTEInvoice);
             PurchInvHeader2.SetRange("Buy-from Vendor No.", PurchInvHeader."Buy-from Vendor No.");
             PurchInvHeader2.SetFilter("No.", '<>%1', PurchInvHeader."No.");
             PurchInvHeader2.SetFilter("Posting Date", '%1..%2', DMY2Date(1, 1, CurrentYear), DMY2Date(31, 12, CurrentYear));
             // Excluir documentos con Amount=0 (cancelados)
             PurchInvHeader2.SetFilter("Amount", '<>0');
             DuplicateCount := DuplicateCount + PurchInvHeader2.Count;

             // Contar en notas de crédito del mismo año, mismo proveedor
             PurchCrMemoHdr.Reset();
             PurchCrMemoHdr.SetRange("DTE Invoice", DTEInvoice);
             PurchCrMemoHdr.SetRange("Buy-from Vendor No.", PurchInvHeader."Buy-from Vendor No.");
             PurchCrMemoHdr.SetFilter("Posting Date", '%1..%2', DMY2Date(1, 1, CurrentYear), DMY2Date(31, 12, CurrentYear));
             // Excluir documentos con Amount=0 (cancelados)
             PurchCrMemoHdr.SetFilter("Amount", '<>0');
             DuplicateCount := DuplicateCount + PurchCrMemoHdr.Count;

             // Si ya existe otra en el año para el mismo proveedor, error
             if DuplicateCount >= 1 then begin
                 ErrorMessage := StrSubstNo(lText002, DTEInvoice, CurrentYear);
                 Error(ErrorMessage);
             end;
         end;

         // VALIDACIÓN 2: Sello de Validación nunca se puede repetir
         if SignatureValidation <> '' then begin
             PurchInvHeader2.Reset();
             PurchInvHeader2.SetRange("Signature Validation", SignatureValidation);
             PurchInvHeader2.SetFilter("No.", '<>%1', PurchInvHeader."No.");
             PurchInvHeader2.SetFilter("Amount", '<>0');
             if PurchInvHeader2.FindFirst() then begin
                 ErrorMessage := StrSubstNo(lText001, 'Sello de Validación', SignatureValidation, 'Factura', PurchInvHeader2."No.");
                 Error(ErrorMessage);
             end;

             PurchCrMemoHdr.Reset();
             PurchCrMemoHdr.SetRange("Signature Validation", SignatureValidation);
             PurchCrMemoHdr.SetFilter("Amount", '<>0');
             if PurchCrMemoHdr.FindFirst() then begin
                 ErrorMessage := StrSubstNo(lText001, 'Sello de Validación', SignatureValidation, 'Nota Crédito', PurchCrMemoHdr."No.");
                 Error(ErrorMessage);
             end;
         end;

         // VALIDACIÓN 3: Código de Autorización nunca se puede repetir
         if DTEAuthNumber <> '' then begin
             PurchInvHeader2.Reset();
             PurchInvHeader2.SetRange("DTE AuthNumber", DTEAuthNumber);
             PurchInvHeader2.SetFilter("No.", '<>%1', PurchInvHeader."No.");
             PurchInvHeader2.SetFilter("Amount", '<>0');
             if PurchInvHeader2.FindFirst() then begin
                 ErrorMessage := StrSubstNo(lText001, 'Código de Autorización', DTEAuthNumber, 'Factura', PurchInvHeader2."No.");
                 Error(ErrorMessage);
             end;

             PurchCrMemoHdr.Reset();
             PurchCrMemoHdr.SetRange("DTE AuthNumber", DTEAuthNumber);
             PurchCrMemoHdr.SetFilter("Amount", '<>0');
             if PurchCrMemoHdr.FindFirst() then begin
                 ErrorMessage := StrSubstNo(lText001, 'Código de Autorización', DTEAuthNumber, 'Nota Crédito', PurchCrMemoHdr."No.");
                 Error(ErrorMessage);
             end;
         end;*/
    end;

    procedure ValidatePurchCrMemoHeaderDTE(var PurchCrMemoHdr: Record "Purch. Cr. Memo Hdr."; var ErrorMessage: Text)
    var
        PurchInvHeader: Record "Purch. Inv. Header";
        PurchCrMemoHdr2: Record "Purch. Cr. Memo Hdr.";
        DTEInvoice: Code[31];
        SignatureValidation: Text[50];
        DTEAuthNumber: Code[36];
        CurrentYear: Integer;
        DuplicateCount: Integer;
        lText001: Label 'El campo %1 "%2" ya existe en el documento %3 %4. No se permiten valores duplicados.';
        lText002: Label 'El DTE "%1" ya ha sido duplicado. No se permite duplicar más de una vez por año.';
    begin
        //ErrorMessage := '';

        // Evitar validar documentos cancelados o vacíos
        /*if PurchCrMemoHdr."No." = '' then
            exit;

        DTEInvoice := PurchCrMemoHdr."DTE Invoice";
        DTEAuthNumber := PurchCrMemoHdr."DTE AuthNumber";
        SignatureValidation := PurchCrMemoHdr."Signature Validation";

        // Si no hay datos DTE, no validar
        if (DTEInvoice = '') and (DTEAuthNumber = '') and (SignatureValidation = '') then
            exit;

        CurrentYear := Date2DMY(PurchCrMemoHdr."Posting Date", 3);

        // VALIDACIÓN 1: DTE no puede duplicarse más de una vez por año POR PROVEEDOR
        if DTEInvoice <> '' then begin
            DuplicateCount := 0;

            // Contar en facturas del mismo año, mismo proveedor
            PurchInvHeader.Reset();
            PurchInvHeader.SetRange("DTE Invoice", DTEInvoice);
            PurchInvHeader.SetRange("Buy-from Vendor No.", PurchCrMemoHdr."Buy-from Vendor No.");
            PurchInvHeader.SetFilter("Posting Date", '%1..%2', DMY2Date(1, 1, CurrentYear), DMY2Date(31, 12, CurrentYear));
            // Excluir documentos con Amount=0 (cancelados)
            PurchInvHeader.SetFilter("Amount", '<>0');
            DuplicateCount := DuplicateCount + PurchInvHeader.Count;

            // Contar en notas de crédito del mismo año, mismo proveedor (excluyendo el documento actual)
            PurchCrMemoHdr2.Reset();
            PurchCrMemoHdr2.SetRange("DTE Invoice", DTEInvoice);
            PurchCrMemoHdr2.SetRange("Buy-from Vendor No.", PurchCrMemoHdr."Buy-from Vendor No.");
            PurchCrMemoHdr2.SetFilter("No.", '<>%1', PurchCrMemoHdr."No.");
            PurchCrMemoHdr2.SetFilter("Posting Date", '%1..%2', DMY2Date(1, 1, CurrentYear), DMY2Date(31, 12, CurrentYear));
            // Excluir documentos con Amount=0 (cancelados)
            PurchCrMemoHdr2.SetFilter("Amount", '<>0');
            DuplicateCount := DuplicateCount + PurchCrMemoHdr2.Count;

            // Si ya existe otra en el año para el mismo proveedor, error
            if DuplicateCount >= 1 then begin
                ErrorMessage := StrSubstNo(lText002, DTEInvoice, CurrentYear);
                Error(ErrorMessage);
            end;
        end;

        // VALIDACIÓN 2: Sello de Validación nunca se puede repetir
        if SignatureValidation <> '' then begin
            PurchInvHeader.Reset();
            PurchInvHeader.SetRange("Signature Validation", SignatureValidation);
            PurchInvHeader.SetFilter("Amount", '<>0');
            if PurchInvHeader.FindFirst() then begin
                ErrorMessage := StrSubstNo(lText001, 'Sello de Validación', SignatureValidation, 'Factura', PurchInvHeader."No.");
                Error(ErrorMessage);
            end;

            PurchCrMemoHdr2.Reset();
            PurchCrMemoHdr2.SetRange("Signature Validation", SignatureValidation);
            PurchCrMemoHdr2.SetFilter("No.", '<>%1', PurchCrMemoHdr."No.");
            PurchCrMemoHdr2.SetFilter("Amount", '<>0');
            if PurchCrMemoHdr2.FindFirst() then begin
                ErrorMessage := StrSubstNo(lText001, 'Sello de Validación', SignatureValidation, 'Nota Crédito', PurchCrMemoHdr2."No.");
                Error(ErrorMessage);
            end;
        end;

        // VALIDACIÓN 3: Código de Autorización nunca se puede repetir
        if DTEAuthNumber <> '' then begin
            PurchInvHeader.Reset();
            PurchInvHeader.SetRange("DTE AuthNumber", DTEAuthNumber);
            PurchInvHeader.SetFilter("Amount", '<>0');
            if PurchInvHeader.FindFirst() then begin
                ErrorMessage := StrSubstNo(lText001, 'Código de Autorización', DTEAuthNumber, 'Factura', PurchInvHeader."No.");
                Error(ErrorMessage);
            end;

            PurchCrMemoHdr2.Reset();
            PurchCrMemoHdr2.SetRange("DTE AuthNumber", DTEAuthNumber);
            PurchCrMemoHdr2.SetFilter("No.", '<>%1', PurchCrMemoHdr."No.");
            PurchCrMemoHdr2.SetFilter("Amount", '<>0');
            if PurchCrMemoHdr2.FindFirst() then begin
                ErrorMessage := StrSubstNo(lText001, 'Código de Autorización', DTEAuthNumber, 'Nota Crédito', PurchCrMemoHdr2."No.");
                Error(ErrorMessage);
            end;
        end;*/
    end;

    [EventSubscriber(ObjectType::Table, Database::"VAT Ledger", 'OnBeforeInsertEvent', '', true, true)]
    local procedure "VAT Ledger_OnBeforeInsertEvent"
    (
        var Rec: Record "VAT Ledger";
        RunTrigger: Boolean
    )
    var
        SalesCrMemoHeader: Record "Sales Cr.Memo Header";
        SalesCrMemoLine: Record "Sales Cr.Memo Line";
        BaseAff: Decimal;
        Parameter: Record "FSN Parameter";
    begin
        if (SalesCrMemoHeader.Get(Rec."Document No.")) then begin
            if Parameter.Get('SUBTYPE', SalesCrMemoHeader."Sub Type") THEN BEGIN
                BaseAff := 0;
                SalesCrMemoLine.Reset();
                SalesCrMemoLine.SetCurrentKey("Document No.", "Line No.");
                SalesCrMemoLine.SetRange("Document No.", Rec."Document No.");
                if SalesCrMemoLine.Find('-') then
                    repeat
                        BaseAff := BaseAff + SalesCrMemoLine."FSN Base Affect";
                    until SalesCrMemoLine.Next() = 0;
                Rec."Base Affect Goods" := BaseAff;
            END;
        end;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Sales Header", 'OnBeforeModifyEvent', '', true, true)]
    local procedure "Sales Header_OnBeforeModifyEvent"
    (
        var Rec: Record "Sales Header";
        var xRec: Record "Sales Header";
        RunTrigger: Boolean
    )
    var
        SalesLine: Record "Sales Line";
        Parameter: Record "FSN Parameter";
    begin
        Parameter.Reset();
        Parameter.SetCurrentKey(Grupo, Codigo);
        Parameter.SetRange(Grupo, 'SUBTYPE');
        Parameter.SetRange(Codigo, Rec."Sub Type");
        IF not Parameter.FindFirst() then begin
            SalesLine.Reset();
            SalesLine.SetRange("Document No.", Rec."No.");
            if SalesLine.Find('-') then
                repeat
                    SalesLine."FSN Base Affect" := 0;
                    SalesLine.Modify(true);
                    Commit();
                until SalesLine.Next() = 0;
        end;
    end;

    procedure ValBeneficiary(posTransac: Record "LSC POS Transaction")
    var
        caption: Label 'Ingrese correo del beneficiario';
        Result: Action;
        CustomerL: Record Customer;
        InfoEntry: Record "LSC POS Trans. Infocode Entry";

    begin

        if not getCustGenericEmail(posTransac, InfoEntry) then begin
            CustomerL.RESET;
            CustomerL.SETRANGE(CustomerL."No.", posTransac."Customer No.");
            IF CustomerL.FINDFIRST THEN begin
                IF CustomerL."FSN Request Beneficiary" THEN BEGIN
                    POSSESSION.SetValue('#MAILB', 'TRUE');
                    POSGUI.OpenAlphabeticKeyboard(CopyStr(StrSubstNo(caption), 1, 50), '', Result, true);
                END;
            END;
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Controller", 'OnKeyboardResult', '', true, true)]
    local procedure "LSC POS Controller_OnKeyboardResult"
(
    payload: Text;
    inputValue: Text;
    resultOK: Boolean;
    var processed: Boolean
)
    var
        PosTransactionB: Record "LSC POS Transaction";
        InfoText: Label 'El correo "%1" no tiene un formato válido.';
    BEGIN
        IF POSSESSION.GetValue('#MAILB') = 'TRUE' THEN
            IF resultOK THEN begin
                if PosTransactionB.get(gPosTransaction.GetReceiptNo()) then begin
                    if not EsCorreoValido(inputValue) then begin
                        POSSESSION.SetValue('#MAILB', 'FALSE');
                        Message(InfoText, inputValue);
                        exit;
                    end else
                        InsetEmailCustBeneficiary(PosTransactionB, inputValue);
                end;
                POSSESSION.SetValue('#MAILB', 'FALSE');
            END ELSE
                POSSESSION.SetValue('#MAILB', 'FALSE');
    END;

    procedure EsCorreoValido(Correo: Text): Boolean
    var
        RegEx: DotNet Regex; // Microsoft.Dynamics.Nav.Runtime: Regex
    begin
        exit(RegEx.IsMatch(Correo, '^[\w\.-]+@[\w\.-]+\.\w{2,}$'));
    end;

    procedure InsetEmailCustBeneficiary(posTransaB: Record "LSC POS Transaction"; mail: Text)
    var
        xPOStemp: Record "LSC POS Trans. Line";
        InfoEntry: Record "LSC POS Trans. Infocode Entry";
    begin

        if getCustGenericEmailValue(posTransaB, InfoEntry, mail) then begin
            xPOStemp.Reset();
            xPOStemp.SetRange(xPOStemp."Store No.", posTransaB."Store No.");
            xPOStemp.SetRange(xPOStemp."POS Terminal No.", posTransaB."POS Terminal No.");
            xPOStemp.SetRange(xPOStemp."Receipt No.", posTransaB."Receipt No.");
            xPOStemp.SetRange(xPOStemp."Entry Type", xPOStemp."Entry Type"::FreeText);
            xPOStemp.SetRange(xPOStemp."Entry Status", xPOStemp."Entry Status"::" ");
            if xPOStemp.Find('-') then begin
                repeat
                    IF ((COPYSTR(xPOStemp.Description, 1, 4)) = 'MAIL') then begin
                        xPOStemp.Description := COPYSTR('MAIL : ' + mail, 1, 50);
                        xPOStemp.Modify(true);

                        InfoEntry.Information := CopyStr(mail, 1, 100);
                        InfoEntry.Modify();
                    end;
                until xPOStemp.Next() = 0;
            end;
        end else begin
            xPOStemp.INIT();
            xPOStemp."Store No." := posTransaB."Store No.";
            xPOStemp."POS Terminal No." := posTransaB."POS Terminal No.";
            xPOStemp."Receipt No." := posTransaB."Receipt No.";
            xPOStemp."Entry Type" := xPOStemp."Entry Type"::FreeText;
            xPOStemp."Line No." := LastPosTransLine(posTransaB) + 10000;
            xPOStemp."Entry Status" := 0;
            xPOStemp."Text Type" := 4;
            xPOStemp.Description := COPYSTR('MAIL : ' + mail, 1, 50);
            xPOStemp."FSN Remission No." := 'ENERGETICAS';
            if not xPOStemp.INSERT(TRUE) then
                xPOStemp.Modify(TRUE);

            InfoEntry.Init();
            InfoEntry."Store No." := xPOStemp."Store No.";
            InfoEntry."POS Terminal No." := xPOStemp."POS Terminal No.";
            InfoEntry."Receipt No." := xPOStemp."Receipt No.";
            InfoEntry."Transaction Type" := 0;
            InfoEntry."Line No." := 90;
            InfoEntry.Infocode := 'EMAILTEXT';
            InfoEntry.Information := CopyStr(mail, 1, 100);
            InfoEntry.Date := Today;
            InfoEntry.Time := Time;
            if not InfoEntry.Insert() then
                InfoEntry.Modify();
        end;
    end;

    local procedure getCustGenericEmailValue(posTransacB: Record "LSC POS Transaction"; var InfoEntry: Record "LSC POS Trans. Infocode Entry"; mail: Text): Boolean
    var

    begin
        InfoEntry.Reset();
        InfoEntry.SetRange(InfoEntry."Store No.", posTransacB."Store No.");
        InfoEntry.SetRange(InfoEntry."POS Terminal No.", posTransacB."POS Terminal No.");
        InfoEntry.SetRange(InfoEntry."Receipt No.", posTransacB."Receipt No.");
        InfoEntry.SetRange(InfoEntry.Infocode, 'EMAILTEXT');
        InfoEntry.SetRange(InfoEntry."Line No.", 90);
        if InfoEntry.FindFirst() then
            exit(true)
        else begin
            InfoEntry.Init();
            InfoEntry."Store No." := posTransacB."Store No.";
            InfoEntry."POS Terminal No." := posTransacB."POS Terminal No.";
            InfoEntry."Receipt No." := posTransacB."Receipt No.";
            InfoEntry."Transaction Type" := 0;
            InfoEntry."Line No." := 90;
            InfoEntry.Infocode := 'EMAILTEXT';
            InfoEntry.Information := CopyStr(mail, 1, 100);
            InfoEntry.Date := Today;
            InfoEntry.Time := Time;
            if not InfoEntry.Insert() then
                InfoEntry.Modify();
            exit(true);
        end;
    end;

    procedure LastPosTransLine(posTransaB: Record "LSC POS Transaction"): Integer
    var
        xPOStemp: Record "LSC POS Trans. Line";
    begin
        xPOStemp.Reset();
        xPOStemp.SetRange(xPOStemp."Store No.", posTransaB."Store No.");
        xPOStemp.SetRange(xPOStemp."POS Terminal No.", posTransaB."POS Terminal No.");
        xPOStemp.SetRange(xPOStemp."Receipt No.", posTransaB."Receipt No.");
        if xPOStemp.FindLast() then
            exit(xPOStemp."Line No.");
    end;

    local procedure getCustGenericEmail(posTransacB: Record "LSC POS Transaction"; var InfoEntry: Record "LSC POS Trans. Infocode Entry"): Boolean
    var

    begin
        InfoEntry.Reset();
        InfoEntry.SetRange(InfoEntry."Store No.", posTransacB."Store No.");
        InfoEntry.SetRange(InfoEntry."POS Terminal No.", posTransacB."POS Terminal No.");
        InfoEntry.SetRange(InfoEntry."Receipt No.", posTransacB."Receipt No.");
        InfoEntry.SetRange(InfoEntry.Infocode, 'EMAILTEXT');
        InfoEntry.SetRange(InfoEntry."Line No.", 90);
        exit(InfoEntry.FindFirst());
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Controller", 'OnPOSEvent', '', true, true)]
    local procedure "LSC POS Controller_OnPOSEvent"
    (
    var PosEvent: Codeunit "LSC POS Event";
    var SuppressEvent: Boolean
    )
    var
        POSLines: Codeunit "LSC POS Trans. Lines";
        POSLine_l: Record "LSC POS Trans. Line";
        POSTransaction: Record "LSC POS Transaction";
        CustomerL: Record Customer;
        caption: Label 'Ingrese correo del beneficiario';
        Result: Action;
        InfoEntry: Record "LSC POS Trans. Infocode Entry";
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line" temporary;
        MsgResult: text;
        FSNUtility: Codeunit "FSN Utility";
        Processedv: Boolean;
        TEXT000: Label 'D: El cliente %1 no esta permitido para ingresar correo electronico.';
    begin
        if PosEvent.ActivePanel = '#POS' THEN
            if PosEvent.EventType in [
                Enum::"LSC POS Event Type"::DATAROWDOUBLECLICK
            ] then begin
                RequestID := 'FSNCC';
                Processedv := false;
                FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processedv, MsgResult);
                If not Processedv then begin
                    POSLines.GetCurrentLine(POSLine_l);
                    if (POSLine_l."Entry Type" = POSLine_l."Entry Type"::FreeText) and
                        (POSLine_l."Entry Status" = POSLine_l."Entry Status"::" ") and ((COPYSTR(POSLine_l.Description, 1, 4) = 'MAIL')) THEN
                        if POSTransaction.get(POSLine_l."Receipt No.") then begin
                            CustomerL.RESET;
                            CustomerL.SETRANGE(CustomerL."No.", POSTransaction."Customer No.");
                            IF CustomerL.FINDFIRST THEN begin
                                IF CustomerL."FSN Request Beneficiary" THEN BEGIN
                                    if ValBeneficiariesExclude(POSTransaction."Customer No.") then begin
                                        POSSESSION.SetValue('#MAILB', 'TRUE');
                                        POSGUI.OpenAlphabeticKeyboard(CopyStr(StrSubstNo(caption), 1, 50), '', Result, true);
                                    end else
                                        POSGUI.PosMessage(StrSubstNo(TEXT000, CustomerL.Name));
                                END;
                            END;
                        end;
                end;
            end;
    end;

    procedure ValBeneficiariesExclude(CustCode: Code[20]): Boolean
    var
        ParameterBf: Record "FSN Parameter";
    begin
        if ParameterBf.get('BENEFICIARIES', 'EXCLUDE') and ParameterBf.Activo then begin
            IF (StrPos(ParameterBf."String Parameters 1 Json" + ParameterBf."String Parameters 2 Json", CustCode) > 0) then
                exit(true)
            else
                exit(false);
        end;
        exit(false);
    end;

    //------------------------------------DTE FAC VENTA----------------------------------------//
    /*
    Table Ext: Document Sub Type
        Campos: "DTE Serie No", "DTE Certify" 

    Page Ext: "Document Sub Type Card"
        Campo: "DTE Serie No", "DTE Certify"

    Table Ext: Sales Line
        Campos: "FSN fac No", "FSN Line No"
    
    */

    //DTE FACTURAS VENTA
    procedure DTESalesInvoice(var SalesHeader: Record "Sales Header")
    var
        DocumentType: Record "Document Sub Type";
        DocumentTypeValidate: Record "Document Sub Type";
        FSN_DTE: Record "FSN DTE Transaction Header";
        FSNFasaniSetup: Record "FSN Fasani Setup";
        NoSeries: Record "No. Series";
        FromStore: Record "LSC Store";
        SalesLine: Record "Sales Line";
        Item_l: Record Item;
        UM_l: Record "Item Unit of Measure";
        NoSerie: Codeunit "NoSeriesManagement";
        FSN: Codeunit "FSN Utility";
        TEXT001: Label 'Error al generar Factura venta Electronica.';
        TEXT002: Label 'No se encuentra numero de serie %1';
        TEXT003: Label 'Procesando Factura Venta DTE, Espere.......';
        EText000: Label 'No existe parametro DTE_INVOICE, PURCHASE';
        Etext001: label 'No Serie es obligatorio para Sub Typo documento %1';
        Etext002: Label 'No se encontraron lineas que procesar para el documento de tipo %1 con el número %2.';
        Etext003: Label 'Actividad Economica es obligatoria para el cliente %1';
        Etext004: Label 'Debe especificar Cod Almacen';
        Etext005: Label 'No hay Lín. venta dentro del filtro. Filltros: Nº documento: %1';
        e: Boolean;
        NextSerie: Code[20];
        TransNo, i : Integer;
        CodeNameMH, codeMH : Text[10];
        TotalCost, TotalLine, TotalLineExcVat, UnitCost : Decimal;
        TxtDollars, JSonStringInformation, MessageError, TokenDTE, paymentMethodText : Text;
        NoText: array[2] of Text[75];
        jValue: JsonValue;
        Array1, Array2 : JsonArray;
        sb: DotNet StringBuilder;
        Windows: Dialog;
        jsonInfo, SellerInfo, AddressInfo, BuyerInfo, TaxInfo, BuyerAddressInfo, PurchLineInfo, TotalInfo, DiscountsInfo, adendaInfo, documentInfo : JsonObject;
        PurchaseInvoicePage: Page "Purchase Invoice";
        DTESign_, DTEAuth_ : Text[50];
        FSNParameter: Record "FSN Parameter";
        FSNDTETaxIDType: Enum "FSN DTE Tax ID Type";
        Customer: Record Customer;
        FSNElectInvoice: Codeunit "FSN Electronic Invoice";
        postCode: Record "Post Code";
        dteParameter: Record "DTE Parameter";
        SalesLineVal: Record "Sales Line";
        DocMessageType: Integer;
        TotalExento, TotalGravado, Vat : Decimal;
        DTEdocumentNumber: Code[36];
        DocType: Code[2];
        DocDate: Date;
        SalesInvHeader: Record "Sales Invoice Header";
        Location: Code[20];
        DistLocation: Record Location;
        existLine: Boolean;
        SubTypeDocument: Record "Document Sub Type";
        UnitOfMesesure: Record "Unit of Measure";
    begin

        IF SalesHeader."Location Code" = '' THEN begin
            if DistLocation.get('CD') then
                Location := DistLocation.Code;
        end else
            Location := SalesHeader."Location Code";

        IF not FSNParameter.GET('DTE_INVOICE', 'PURCHASE') THEN
            Error(EText000);

        if Customer.Get(SalesHeader."Sell-to Customer No.") then begin
            if SubTypeDocument.get(SalesHeader."Sub Type") then
                if not (SubTypeDocument.Prefix in ['1', '01']) then begin
                    if Customer."DTE Activity Code" = '' then
                        Error(StrSubstNo(Etext003, Customer."No."));
                end;
            Customer.TestField("DTE Tax ID Type");
        end;

        if DocumentType.GET(SalesHeader."Sub Type") then begin
            if DocumentType."DTE Certify" then begin
                if DocumentType."DTE Serie No" = '' then
                    ERROR(STRSUBSTNO(Etext001, DocumentType.Code));
            end;
        end;

        SalesLineVal.Reset();
        SalesLineVal.SetRange("Document Type", SalesHeader."Document Type");
        SalesLineVal.SetRange("Document No.", SalesHeader."No.");
        SalesLineVal.SetFilter(Type, '>0');
        SalesLineVal.SetFilter(Quantity, '<>0');
        if not SalesLineVal.Find('-') then
            Error(Etext002, SalesHeader."Document Type", SalesHeader."No.");
        SalesLineVal.SetRange(Type, SalesLineVal.Type::Item);
        if SalesLineVal.FindSet then
            repeat
                if SalesLineVal.IsInventoriableItem then
                    SalesLineVal.TestField("Location Code");
            until SalesLineVal.Next() = 0;
        SalesLineVal.SetFilter(Type, '>0');

        CLEAR(FSN_DTE);
        CLEAR(e);

        IF STRLEN(SalesHeader."No.") > 10 THEN BEGIN
            IF FSN_DTE.GET(COPYSTR(SalesHeader."No.", 1, 10), COPYSTR(SalesHeader."No.", 11, 10), 0) THEN BEGIN
                IF SalesHeader."External Document No." <> FSN_DTE."DTE Invoice" THEN BEGIN
                    SalesHeader."External Document No." := FSN_DTE."DTE Invoice";
                    SalesHeader."DTE Invoice" := FSN_DTE."DTE Invoice";
                    SalesHeader.MODIFY;
                END;
                e := TRUE;

                IF (FSN_DTE."DTE AuthNumber" <> '') AND (FSN_DTE."Signature Validation" <> '') THEN
                    exit;

            END;
        END ELSE
            IF FSN_DTE.GET(SalesHeader."No.", '1', 0) THEN BEGIN
                IF SalesHeader."External Document No." <> FSN_DTE."DTE Invoice" THEN BEGIN
                    SalesHeader."External Document No." := FSN_DTE."DTE Invoice";
                    SalesHeader."DTE Invoice" := FSN_DTE."DTE Invoice";
                    SalesHeader.MODIFY;
                END;

                e := TRUE;

                IF (FSN_DTE."DTE AuthNumber" <> '') AND (FSN_DTE."Signature Validation" <> '') THEN
                    EXIT;
            END;

        IF FSNFasaniSetup.GET(Location) then begin
            if (FSNFasaniSetup."DTE Store" = '') or (FSNFasaniSetup."DTE Terminal" = '') then
                exit
        end else
            exit;

        FromStore.GET(Location);
        FSNFasaniSetup.GET(Location);
        CodeNameMH := FSNFasaniSetup."DTE Store";
        codeMH := FSNFasaniSetup."DTE Store";
        IF NOT e THEN BEGIN
            FSN_DTE.INIT;
            FSN_DTE."Store No." := COPYSTR(SalesHeader."No.", 1, 10);
            IF STRLEN(SalesHeader."No.") > 10 THEN
                FSN_DTE."POS Terminal No." := COPYSTR(SalesHeader."No.", 11, 10)
            ELSE
                FSN_DTE."POS Terminal No." := '1';
            FSN_DTE."DTE AuthNumber" := COPYSTR(UpperCase(CreateGuid()), 2, 36);
            FSN_DTE."Transaction No." := 0;
            FSN_DTE."Creating Date" := TODAY;
            FSN_DTE."Document Type" := DocumentType.Prefix;

            IF NOT NoSeries.Get(DocumentType."DTE Serie No") THEN
                ERROR(STRSUBSTNO(TEXT002, DocumentType."DTE Serie No"));
            NextSerie := NoSerie.GetNextNo(DocumentType."DTE Serie No", TODAY, TRUE);
            FSN_DTE."DTE EnrolledTimeStamp" := NextSerie;

            FSN_DTE."DTE Invoice" := 'DTE-' + DocumentType.Prefix + '-' + FSNFasaniSetup."DTE Store" + FSNFasaniSetup."DTE Terminal" + '-' + NextSerie;

            if not FSN_DTE.INSERT(TRUE) then
                FSN_DTE.Modify(TRUE);

            //SalesHeader."Vendor Invoice Number" := NextSerie;
            SalesHeader."External Document No." := FSN_DTE."DTE Invoice";
            SalesHeader."DTE Invoice" := FSN_DTE."DTE Invoice";
            if SalesHeader.MODIFY then;
        END;

        jsonInfo.Add('documentType', DocumentType.Prefix);
        jsonInfo.Add('operationType', '01');

        //FORMATO DE FECHA
        ValDateTime(jsonInfo);

        jsonInfo.Add('idShop', CodeNameMH);
        jsonInfo.Add('secuencial', FSN_DTE."DTE EnrolledTimeStamp");
        if Evaluate(TransNo, FSN_DTE."DTE EnrolledTimeStamp") then;
        jsonInfo.Add('transNo', FSN_DTE."DTE EnrolledTimeStamp");
        jsonInfo.Add('printTicket', false);
        jsonInfo.Add('isJustTicketPrinting', false);
        jsonInfo.Add('printName', '');
        jsonInfo.Add('guid', FSN_DTE."DTE AuthNumber");
        jValue.SetValueToNull();
        jsonInfo.Add('contingency', jValue);

        SellerInfo.Add('name', 'Farmacia San Nicolas S.A. de C.V.');
        SellerInfo.Add('nrc', '406-5');
        SellerInfo.Add('nit', '0614-221265-001-4');
        SellerInfo.Add('codeSellingPoint', 'P002');
        SellerInfo.Add('codeSellingPointMH', 'P002');
        SellerInfo.Add('typeEstablishment', '01');
        SellerInfo.Add('codeEstablishment', CodeNameMH);
        SellerInfo.Add('codeEstablishmentMH', codeMH);
        SellerInfo.Add('phone', '2555-5555');
        //SellerInfo.Add('email', 'joseph.nehemias28981@gmail.com');
        SellerInfo.Add('Email', 'dte@farmaciasannicolas.com');
        SellerInfo.Add('activityCode', '46491');
        SellerInfo.Add('activityDesc', 'Venta al por mayor de productos medicinales, cosméticos, perfumería y productos de limpieza');

        jsonInfo.Add('seller', SellerInfo);

        AddressInfo.Add('addressLine', FromStore.Address);
        AddressInfo.Add('district', '05');
        AddressInfo.Add('state', '01');

        SellerInfo.Add('address', AddressInfo);

        BuyerInfo.Add('IsGenericCustomer', false);
        IF Customer."FSN NRC" <> '' THEN
            BuyerInfo.Add('nrc', Customer."FSN NRC")
        ELSE
            BuyerInfo.Add('nrc', '');
        //Get Information Customer
        BuyerInfo.Add('taxInformation', getTaxInformation(customer));

        if SubTypeDocument.get(SalesHeader."Sub Type") then begin
            if SubTypeDocument.Prefix in ['1', '01'] then begin
                if customer."DTE Activity Code" = '' then begin
                    BuyerInfo.Add('activityCode', '10005');
                    BuyerInfo.Add('activityDesc', 'Otros');
                end else begin
                    BuyerInfo.Add('activityCode', customer."DTE Activity Code");

                    dteParameter.SetRange("Code", customer."DTE Activity Code");
                    dteParameter.SetRange("Type", dteParameter.Type::"Person Activity");
                    if dteParameter.FindSet() then
                        BuyerInfo.Add('activityDesc', dteParameter.Description)
                    else
                        BuyerInfo.Add('activityDesc', '');
                end;

            end else begin
                BuyerInfo.Add('activityCode', customer."DTE Activity Code");

                dteParameter.SetRange("Code", customer."DTE Activity Code");
                dteParameter.SetRange("Type", dteParameter.Type::"Person Activity");
                if dteParameter.FindSet() then
                    BuyerInfo.Add('activityDesc', dteParameter.Description)
                else
                    BuyerInfo.Add('activityDesc', '');
            end;
        end;

        BuyerInfo.Add('name', serializeName(customer.Name));
        BuyerInfo.Add('comercialName', customer.Name);
        BuyerInfo.Add('phone', customer."Phone No.");
        if customer."E-Mail" <> '' then
            BuyerInfo.Add('email', customer."E-Mail")
        else
            BuyerInfo.Add('email', 'ventas@sannicolas.com.sv');
        //BuyerInfo.Add('email', 'joseph.nehemias28981@gmail.com');
        jsonInfo.Add('buyer', BuyerInfo);


        BuyerAddressInfo.Add('addressLine', customer.Address);
        postCode.SetRange(Code, customer."Post Code");
        if not postCode.FindFirst() then begin
            BuyerAddressInfo.Add('district', '14');
            BuyerAddressInfo.Add('state', '06');
        end else begin
            if postCode."DTE District" <> '' then
                BuyerAddressInfo.Add('district', postCode."DTE District")
            else
                BuyerAddressInfo.Add('district', '01');

            if postCode."DTE State" <> '' then
                BuyerAddressInfo.Add('state', postCode."DTE State")
            else
                BuyerAddressInfo.Add('state', '06');
        end;

        BuyerInfo.Add('address', BuyerAddressInfo);
        BuyerInfo.Add('bienTitulo', '04');

        TotalCost := 0;
        i := 0;
        TotalLineExcVat := 0;
        existLine := false;
        SalesLine.RESET;
        SalesLine.SETRANGE(SalesLine."Document No.", SalesHeader."No.");
        SalesLine.SETRANGE(SalesLine.Type, SalesLine.Type::Item);
        SalesLine.SETFILTER(SalesLine.Quantity, '>0');
        if SalesLine.FIND('-') then
            REPEAT
                existLine := true;
                Item_l.GET(SalesLine."No.");
                if not UM_l.GET(SalesLine."No.", SalesLine."Unit of Measure") then begin
                    UnitOfMesesure.Reset();
                    UnitOfMesesure.SetRange(Description, SalesLine."Unit of Measure");
                    if UnitOfMesesure.FindFirst() then
                        UM_l.GET(SalesLine."No.", UnitOfMesesure.Code);
                end;
                IF Item_l."Unit Cost" = 0 THEN
                    Item_l."Unit Cost" := 0.01;

                UnitCost := SalesLine."Unit Price" * UM_l."Qty. per Unit of Measure";
                TotalCost += ROUND(UnitCost * SalesLine.Quantity, 0.01);
                if SalesLine."VAT %" = 0 then begin
                    TotalLineExcVat := ROUND(UnitCost * SalesLine.Quantity, 0.01);
                    UnitCost := ROUND(TotalLineExcVat / SalesLine.Quantity, 0.00001);
                    TotalExento += ROUND(UnitCost * SalesLine.Quantity, 0.01);
                end else begin
                    Vat += ROUND(SalesLine.Amount - SalesLine."Amount Including VAT", 0.01) * -1;
                    TotalLine := ROUND(UnitCost * SalesLine.Quantity, 0.01);
                    UnitCost := ROUND(TotalLine / SalesLine.Quantity, 0.00001);
                    TotalGravado += ROUND(UnitCost * SalesLine.Quantity, 0.01);
                end;

                Clear(PurchLineInfo);
                PurchLineInfo.Add('code', SalesLine."No.");
                PurchLineInfo.Add('name', DELCHR(SalesLine.Description, '=', '"'));
                PurchLineInfo.Add('unitOfMeasure', '59');
                PurchLineInfo.Add('productType', '1');
                PurchLineInfo.Add('quantity', DELCHR(FORMAT(SalesLine.Quantity), '=', ','));
                PurchLineInfo.Add('suggestedSalePrice', '0.00');
                PurchLineInfo.Add('discount', '0.00');
                PurchLineInfo.Add('nO_GRAVADO', '0.00');
                PurchLineInfo.Add('VENTA_NO_SUJETA', '0.00');

                if SalesLine."VAT %" = 0 then begin
                    PurchLineInfo.Add('VENTA_EXENTA', DELCHR(FORMAT(ROUND(TotalLineExcVat)), '=', ','));
                    PurchLineInfo.Add('VENTA_GRAVADA', '0.00');
                    PurchLineInfo.Add('total', DELCHR(FORMAT(ROUND(TotalLineExcVat)), '=', ','));
                end else begin
                    PurchLineInfo.Add('VENTA_EXENTA', '0.00');
                    PurchLineInfo.Add('VENTA_GRAVADA', DELCHR(FORMAT(ROUND(TotalLine)), '=', ','));
                    PurchLineInfo.Add('total', DELCHR(FORMAT(ROUND(TotalLine)), '=', ','));
                end;
                //PurchLineInfo.Add('price', DELCHR(FORMAT(ROUND(UnitCost)), '=', ','));
                PurchLineInfo.Add('price', DELCHR(FORMAT(UnitCost), '=', ','));

                jValue.SetValueToNull();
                //1 FISICO
                //2 ELECTRONICO
                Clear(documentInfo); // <- Limpia el objeto antes de agregar nuevas claves
                IF DocumentType.Prefix in ['05', '5'] THEN begin//080925
                    if SalesInvHeader.get(SalesLine."FSN fac No") then
                        if DocumentTypeValidate.get(SalesInvHeader."Sub Type") then begin
                            case DocumentTypeValidate.Prefix of
                                '03':
                                    begin
                                        returnFacSales(SalesLine."FSN fac No", DTEdocumentNumber, DocType, DocDate);
                                        documentInfo.Add('documentNumber', DTEdocumentNumber);
                                        documentInfo.Add('documentType', DocType);
                                        documentInfo.Add('generationType', '2');
                                        documentInfo.Add('issuedDate', Format(DocDate, 0, '<Year4>-<Month,2>-<Day,2>'));
                                        PurchLineInfo.Add('document', documentInfo);
                                    end;

                            end;
                        end;
                end else
                    PurchLineInfo.Add('document', jValue);

                Array1.Add(PurchLineInfo);
            UNTIL SalesLine.Next() = 0;

        SalesLine.RESET;
        SalesLine.SETRANGE(SalesLine."Document No.", SalesHeader."No.");
        SalesLine.SETRANGE(SalesLine.Type, SalesLine.Type::"G/L Account");
        SalesLine.SETFILTER(SalesLine.Quantity, '>0');
        if SalesLine.FIND('-') then begin
            TotalExento := 0;
            TotalGravado := 0;
            REPEAT
                existLine := true;
                TotalCost += SalesLine.Amount;
                if SalesLine."VAT %" = 0 then begin
                    TotalLineExcVat := SalesLine.Amount;
                    UnitCost := 0;
                    TotalExento += SalesLine.Amount;
                    UnitCost := SalesLine.Amount;
                end else begin
                    Vat += ROUND(SalesLine.Amount - SalesLine."Amount Including VAT", 0.01) * -1;
                    TotalLine := SalesLine.Amount;
                    UnitCost := 0;
                    TotalGravado += SalesLine.Amount;
                    UnitCost := SalesLine.Amount;
                end;

                Clear(PurchLineInfo);
                PurchLineInfo.Add('code', '000002');
                PurchLineInfo.Add('name', DELCHR(SalesLine.Description, '=', '"'));
                PurchLineInfo.Add('unitOfMeasure', '99');
                PurchLineInfo.Add('productType', '2');
                PurchLineInfo.Add('quantity', DELCHR(FORMAT(SalesLine.Quantity), '=', ','));
                PurchLineInfo.Add('suggestedSalePrice', '0.00');
                PurchLineInfo.Add('discount', '0.00');
                PurchLineInfo.Add('nO_GRAVADO', '0.00');
                PurchLineInfo.Add('VENTA_NO_SUJETA', '0.00');

                if SalesLine."VAT %" = 0 then begin
                    PurchLineInfo.Add('VENTA_EXENTA', DELCHR(FORMAT(ROUND(TotalLineExcVat, 0.01)), '=', ','));
                    PurchLineInfo.Add('VENTA_GRAVADA', '0.00');
                    PurchLineInfo.Add('total', DELCHR(FORMAT(ROUND(TotalLineExcVat, 0.01)), '=', ','));
                end else begin
                    PurchLineInfo.Add('VENTA_EXENTA', '0.00');
                    PurchLineInfo.Add('VENTA_GRAVADA', DELCHR(FORMAT(ROUND(TotalLine, 0.02)), '=', ','));
                    PurchLineInfo.Add('total', DELCHR(FORMAT(ROUND(TotalLine, 0.02)), '=', ','));
                end;
                //PurchLineInfo.Add('price', DELCHR(FORMAT(ROUND(UnitCost)), '=', ','));
                PurchLineInfo.Add('price', DELCHR(FORMAT(UnitCost), '=', ','));

                jValue.SetValueToNull();
                //1 FISICO
                //2 ELECTRONICO
                Clear(documentInfo); // <- Limpia el objeto antes de agregar nuevas claves
                IF DocumentType.Prefix in ['05', '5'] THEN begin//080925
                    if SalesInvHeader.get(SalesLine."FSN fac No") then
                        if DocumentTypeValidate.get(SalesInvHeader."Sub Type") then begin
                            case DocumentTypeValidate.Prefix of
                                '03':
                                    begin
                                        returnFacSales(SalesLine."FSN fac No", DTEdocumentNumber, DocType, DocDate);
                                        documentInfo.Add('documentNumber', DTEdocumentNumber);
                                        documentInfo.Add('documentType', DocType);
                                        documentInfo.Add('generationType', '2');
                                        documentInfo.Add('issuedDate', Format(DocDate, 0, '<Year4>-<Month,2>-<Day,2>'));
                                        PurchLineInfo.Add('document', documentInfo);
                                    end;

                            end;
                        end;
                end else
                    PurchLineInfo.Add('document', jValue);

                Array1.Add(PurchLineInfo);
            UNTIL SalesLine.Next() = 0;
        end;

        if not existLine then
            Error(StrSubstNo(Etext005, SalesHeader."No."));



        jsonInfo.Add('productList', Array1);

        CLEAR(NoText);
        CLEAR(FSN);

        TxtDollars := FSN.Num2Text(ABS(ROUND(Vat) + TotalCost));

        jValue.SetValueToNull();
        jsonInfo.Add('paymentList', getPaymentList(paymentMethodText, '4', DELCHR(FORMAT(ROUND(Vat) + ROUND(TotalCost)), '=', ',')));
        TotalInfo.Add('subTotal', DELCHR(FORMAT(ROUND(TotalCost)), '=', ','));
        TotalInfo.Add('TOTAL_NO_GRAVADO', '0.00');
        TotalInfo.Add('TOTAL_NO_SUJETA', '0.00');

        jsonInfo.Add('Totals', TotalInfo);

        DiscountsInfo.Add('exento', '0.00');
        DiscountsInfo.Add('gravado', '0.00');
        TotalInfo.Add('discounts', DiscountsInfo);

        TotalInfo.Add('TOTAL_EXENTO', DELCHR(FORMAT(ROUND(TotalExento)), '=', ','));
        TotalInfo.Add('TOTAL_GRAVADO', DELCHR(FORMAT(ROUND(TotalGravado)), '=', ','));
        TotalInfo.Add('IVA', FORMAT(ROUND(Vat)));
        TotalInfo.Add('ivaPercibido', '0.00');
        TotalInfo.Add('ivaRetenido', '0.00');
        TotalInfo.Add('retencionRenta', '0.00');
        TotalInfo.Add('inWords', TxtDollars);
        IF DocumentType.Prefix = '03' THEN
            TotalInfo.Add('amount', DELCHR(FORMAT(ROUND(Vat) + ROUND(TotalCost)), '=', ','))
        ELSE
            TotalInfo.Add('amount', DELCHR(FORMAT(ROUND(TotalCost)), '=', ','));

        adendaInfo.Add('name', 'SucDestino');
        adendaInfo.Add('data', 'SucDestino');
        adendaInfo.Add('value', FromStore.Name + ' ' + FromStore."No.");//090725
        Array2.Add(adendaInfo);

        jsonInfo.Add('adenda', Array2);

        jsonInfo.WriteTo(JSonStringInformation);
        sb := sb.StringBuilder();
        sb.Append(JSonStringInformation);
        //Message(JSonStringInformation);

        Windows.OPEN(TEXT003);
        Windows.UPDATE;
        FSNParameter.Reset();
        IF FSNParameter.GET('DTE_INVOICE', 'PURCH_TOKEN') THEN;
        GetTokenAPIDTE(FSNParameter, '', SalesHeader."No.", DTESign_, TokenDTE);//28981

        IF SalesHeader."Document Type" = SalesHeader."Document Type"::"Credit Memo" THEN
            DocMessageType := 3
        else
            DocMessageType := 2;

        DTEcertify(DocMessageType, JSonStringInformation, SalesHeader."No.", DTESign_, DTEAuth_, TokenDTE);

        Windows.Close();

        IF DTEAuth_ <> '' THEN BEGIN
            SalesHeader."DTE AuthNumber" := DTEAuth_;
            SalesHeader."Signature Validation" := DTESign_;
            SalesHeader.Modify(true);
            FSN_DTE."DTE AuthNumber" := DTEAuth_;
            FSN_DTE."Signature Validation" := DTESign_;
            FSN_DTE.MODIFY(TRUE);
            COMMIT;

        END ELSE
            ERROR(TEXT001);
    end;
    //FORMATO DE FECHA
    procedure ValDateTime(var json: JsonObject);
    var
        month: Integer;
    begin
        json.Add('IssuedDate', FORMAT(DATE2DMY(TODAY, 3)) + '-' + FORMAT(DATE2DMY(TODAY, 2)) + '-' + FORMAT(DATE2DMY(TODAY, 1)));
        json.Add('IssuedTime', FORMAT(TIME, 9));
    end;

    //Get Information Customer
    procedure getTaxInformation(customer: Record Customer): JsonObject
    var
        json: JsonObject;
        token: JsonToken;
        value: Text;
    begin
        if customer."LSC Retail Customer Group" <> 'COMODIN' then
            json.Add('ID', Format(customer."DTE Tax ID Type".AsInteger()))
        else
            json.Add('ID', Format(customer."DTE Tax ID Type"::Otros));

        case customer."DTE Tax ID Type" of
            customer."DTE Tax ID Type"::DUI:
                value := customer."FSN DUI";
            customer."DTE Tax ID Type"::NIT:
                value := customer."VAT Registration No.";
            customer."DTE Tax ID Type"::Pasaporte,
            customer."DTE Tax ID Type"::"Carnet de Residente":
                value := customer."FSN Foreign document";
            customer."DTE Tax ID Type"::Otros:
                value := '123456789';
            else
                value := customer."FSN DUI";
        end;
        json.Add('Value', value);

        exit(json);
    end;

    //Excluye caracteres especiales
    procedure serializeName(Description: Text[100]): Text
    begin
        if Description.Contains('''') then
            Description := Description.Replace('''', '');

        if Description.Contains('"') then
            Description := Description.Replace('"', '');

        if Description.Contains('*') then
            Description := Description.Replace('*', '');

        if Description.Contains('/') then
            Description := Description.Replace('/', '');

        exit(Description);
    end;

    //si es devolucion, filtra el documento
    procedure returnFacSales(DocumentNo: Code[20]; var DTEdocumentNumber: Code[36]; var DocType: Code[2]; var DocDate: Date)
    var
        FSN_DTE: Record "FSN DTE Transaction Header";
        SalesInvHeader: Record "Sales Invoice Header";
    begin
        Clear(DTEdocumentNumber);
        Clear(DocType);
        Clear(DocDate);
        IF FSN_DTE.GET(COPYSTR(DocumentNo, 1, 10), COPYSTR(DocumentNo, 11, 10), 0) THEN BEGIN
            if SalesInvHeader.get(DocumentNo) then begin
                DTEdocumentNumber := FSN_DTE."DTE AuthNumber";
                DocType := FSN_DTE."Document Type";
                DocDate := SalesInvHeader."Pmt. Discount Date";
            end;
        end;
    end;

    //Lista de medias de pago
    local procedure getPaymentList(var paymentMethod: Text; PayCode: Code[10]; Amount: Text): JsonToken
    var
        dtePaymentType: Enum "DTE Payment Methods";
        bin: Record "FSN BIN Bank";
        array: JsonArray;
        json: JsonObject;
        value: Decimal;
        json_value: JsonValue;
        POSSESION: Codeunit "LSC POS Session";
    begin

        Clear(json);
        json.Add('ReferenceNumber', '');
        json.Add('ElectronicPaymentNum', '');
        json_value.SetValueToNull();
        json.Add('CreditPurchase', json_value);
        case PayCode of
            '1':
                begin
                    json.Add('paymentType', Format(dtePaymentType::Cash.AsInteger()));
                    paymentMethod += 'EFECTIVO';
                end;
            '2':
                begin
                    json.Add('paymentType', Format(dtePaymentType::Check.AsInteger()));
                    paymentMethod += 'CHEQUE';
                end;
            '4':
                begin
                    json.Add('paymentType', Format(dtePaymentType::Payable.AsInteger()));
                    paymentMethod += 'AL CREDITO';
                end;
            '16':
                begin
                    json.Add('paymentType', Format(dtePaymentType::Bitcoin.AsInteger()));
                    paymentMethod := 'BITCOIN';
                end;
            '10',
            '7':
                begin
                    json.Add('paymentType', Format(dtePaymentType::"Coupon or Voucher".AsInteger()));
                    paymentMethod := 'CUPON O VOUCHER';
                end;
            '25':
                begin
                    json.Add('paymentType', Format(dtePaymentType::GiftCard.AsInteger()));
                    paymentMethod := 'TARJETA DE REGALO';
                end;
            else begin
                json.Add('paymentType', '99');
                paymentMethod := 'OTROS';
            end;
        end;
        json.Add('amount', Amount);
        array.Add(json);
        exit(array.AsToken());
    end;

    //se invoca para certificar
    procedure DTEcertify(DocumentType: Integer; pBody: Text; Number: Code[20]; var DTESignature: Text[50]; var DTEAuth: Text[50]; var TokenV: Text): Text[50]
    var
        Parameters: DotNet Dictionary_Of_T_U;
        HttpResponseMessage: DotNet HttpResponseMessage;
        result: Text[1024];
        JArray: DotNet JArray;
        JObject: DotNet JObject;
        JToken: DotNet JToken;
        p: Record "LSC POS Menu Line";
        RESPONSEGLOBAL: Text;
        BODYGLOBAL: Text;
        SRFREQUEST: Text;
        SRFBANVALUE: Text;
        OD: Codeunit "FSN OData Conexion";
        requestHeader, contentHeader : HttpHeaders;
        body: HttpContent;
        request: HttpRequestMessage;
        CodeResultS: Integer;
        response: JsonObject;
        token: JsonToken;
        FSNParameter: Record "FSN Parameter";
        MText000: Label 'DTE: No se pudo crear Factura Compra electronica \%1';
        MText001: Label 'DTE: No se pudo crear Factura venta electronica \%1';
        MText002: Label 'DTE: No se pudo crear Notas de Crédito de venta electronica \%1';
        MText003: Label 'DTE: No se pudo crear Notas de Crédito de compra electronica \%1';
        PrintMessage: Text;
        FSN: Record "FSN Fasani Setup";
    begin

        IF FSNParameter.GET('DTE_INVOICE', 'PURCHASE') THEN
            IF FSNParameter.Activo THEN BEGIN

                case DocumentType of
                    1://FACTURA COMPRAS
                        PrintMessage := MText000;
                    2://FACTURA VENTA
                        PrintMessage := MText001;
                    3://Notas de Crédito
                        PrintMessage := MText002;
                    4://Notas de Crédito de compra
                        PrintMessage := MText003;
                end;

                BODYGLOBAL := pBody;
                SRFREQUEST := FSNParameter."Web Uri" + 'GenerateInvoice';
                SRFBANVALUE := 'application/json';

                RESPONSEGLOBAL := '';
                body.WriteFrom(pBody);
                body.GetHeaders(contentHeader);
                contentHeader.Clear();
                contentHeader.Add('Content-Type', 'application/json');
                request.GetHeaders(requestHeader);
                requestHeader.Clear();
                request.Content := body;
                if TokenV <> '' then
                    requestheader.Add('Authorization', 'Bearer ' + TokenV);
                response := PostC(SRFREQUEST, request, CodeResultS);

                if CodeResultS = 200 then begin
                    IF response.SelectToken('authNumber', token) THEN begin
                        RESPONSEGLOBAL := token.AsValue().AsText();
                        DTEAuth := token.AsValue().AsText();
                    end;

                    IF response.SelectToken('selloRecepcion', token) THEN
                        DTESignature := token.AsValue().AsText();
                END;

                IF RESPONSEGLOBAL = '' THEN BEGIN

                    IF response.SelectToken('statusMessage', token) THEN begin
                        result := token.AsValue().AsText();

                        p."Primary Key" := Number + '_R';
                        SaveXML(p, 1, format(response));
                        p."Primary Key" := Number;
                        SaveXML(p, 1, pBody);
                    end;

                    ERROR(STRSUBSTNO(PrintMessage, format(response)));
                END;

                EXIT(RESPONSEGLOBAL);

                RESPONSEGLOBAL := '';
            END;
    end;

    //Se controla error de comunicacion para mostrar el mensaje en la cola de proyecto
    procedure PostC(Uri: Text; request: HttpRequestMessage; var CodeResult: Integer): JsonObject;
    var
        client: HttpClient;
        response: HttpResponseMessage;
        content: HttpContent;
        status: Integer;
        res: Text;
        jResponse: JsonObject;
    begin
        CodeResult := 0;
        request.Method := 'POST';
        request.SetRequestUri(uri);
        if client.Send(request, response) then begin
            content := response.Content;
            status := response.HttpStatusCode;
            //if status = 200 then begin
            content.ReadAs(res);
            jResponse.ReadFrom(res);
            CodeResult := status;
        end;
        exit(jResponse);
        //end;
    end;

    //Se valida que no pueda mesclarce Facturas con Creditos fiscales en la nota de credito
    procedure ValidateTypeDocument(var SalesHeader: Record "Sales Header"; var MessageText: Text): Boolean
    var
        myInt: Integer;
        SalesLine: Record "Sales Line";
        SalesInvoceHeader: Record "Sales Invoice Header";
        DocumentTypeValidate: Record "Document Sub Type";
        ValPrefix: text[2];
        Text000: label 'No se puede procesar 2 tipos de documentos diferentes';
    begin
        ValPrefix := '00';
        Clear(MessageText);
        SalesLine.Reset();
        SalesLine.SetRange(SalesLine."Document No.", SalesHeader."No.");
        SalesLine.SetRange(SalesLine.Type, SalesLine.Type::Item);
        if SalesLine.Find('-') then begin
            repeat
                if SalesInvoceHeader.get(SalesLine."FSN fac No") then
                    if DocumentTypeValidate.get(SalesInvoceHeader."Sub Type") then begin
                        if ValPrefix = '00' then
                            ValPrefix := DocumentTypeValidate.Prefix;

                        if DocumentTypeValidate.Prefix <> ValPrefix then begin
                            MessageText := Text000;
                            exit(false);
                        end;
                    end;
            until SalesLine.Next() = 0;
        end;

        Clear(MessageText);
        SalesLine.Reset();
        SalesLine.SetRange(SalesLine."Document No.", SalesHeader."No.");
        SalesLine.SetRange(SalesLine.Type, SalesLine.Type::"G/L Account");
        if SalesLine.Find('-') then begin
            repeat
                if SalesInvoceHeader.get(SalesLine."FSN fac No") then
                    if DocumentTypeValidate.get(SalesInvoceHeader."Sub Type") then begin
                        if ValPrefix = '00' then
                            ValPrefix := DocumentTypeValidate.Prefix;

                        if DocumentTypeValidate.Prefix <> ValPrefix then begin
                            MessageText := Text000;
                            exit(false);
                        end;
                    end;
            until SalesLine.Next() = 0;
        end;
        exit(true);
    end;

    //Se procesa la certificacion
    local procedure ProcessCreditNotSales(var SalesHeader: Record "Sales Header"): Code[20]
    var
        myInt: Integer;
        SalesLine: Record "Sales Line";
        DocumentTypeValidate: Record "Document Sub Type";
        SalesInvHeader: Record "Sales Invoice Header";
        ErrorText: Text;
        FSN_DTE: Record "FSN DTE Transaction Header";
        JsonObjectNull: JsonObject;
    begin

        clear(ErrorText);
        if not ValidateTypeDocument(SalesHeader, ErrorText) then
            error(ErrorText);

        SalesLine.Reset();
        SalesLine.SetRange(SalesLine."Document No.", SalesHeader."No.");
        SalesLine.SetRange(SalesLine.Type, SalesLine.Type::Item);
        if SalesLine.Find('-') then begin
            repeat
                if SalesInvHeader.get(SalesLine."FSN fac No") then
                    if DocumentTypeValidate.get(SalesHeader."Sub Type") then begin
                        case DocumentTypeValidate.Prefix of//5 documento completo, 99 mas de un documento
                            '99':
                                begin
                                    if not ValReturnFacSalesExist(SalesLine."FSN fac No", SalesHeader, ErrorText) then
                                        Error(ErrorText);

                                    IF FSN_DTE.GET(COPYSTR(SalesLine."FSN fac No", 1, 10), COPYSTR(SalesLine."FSN fac No", 11, 10), 0) THEN
                                        if FSN_DTE.Status = FSN_DTE.Status::Send then begin
                                            JsonObjectNull := CreateAnulationFacVenta(FSN_DTE, SalesHeader);
                                            GenerateAndSendAnulation(FSN_DTE, SalesHeader, JsonObjectNull);
                                        end;
                                end;

                            '05':
                                begin
                                    DTESalesInvoice(SalesHeader);
                                    exit;
                                end;

                        end;
                    end;
            until SalesLine.Next() = 0;
        end;

        SalesLine.Reset();
        SalesLine.SetRange(SalesLine."Document No.", SalesHeader."No.");
        SalesLine.SetRange(SalesLine.Type, SalesLine.Type::"G/L Account");
        if SalesLine.Find('-') then begin
            repeat
                if SalesInvHeader.get(SalesLine."FSN fac No") then
                    if DocumentTypeValidate.get(SalesHeader."Sub Type") then begin
                        case DocumentTypeValidate.Prefix of//5 documento completo, 99 mas de un documento
                            '99':
                                begin
                                    if not ValReturnFacSalesExist(SalesLine."FSN fac No", SalesHeader, ErrorText) then
                                        Error(ErrorText);

                                    IF FSN_DTE.GET(COPYSTR(SalesLine."FSN fac No", 1, 10), COPYSTR(SalesLine."FSN fac No", 11, 10), 0) THEN
                                        if FSN_DTE.Status = FSN_DTE.Status::Send then begin
                                            JsonObjectNull := CreateAnulationFacVenta(FSN_DTE, SalesHeader);
                                            GenerateAndSendAnulation(FSN_DTE, SalesHeader, JsonObjectNull);
                                        end;
                                end;

                            '05':
                                begin
                                    DTESalesInvoice(SalesHeader);
                                    exit;
                                end;

                        end;
                    end;
            until SalesLine.Next() = 0;
        end;
    end;

    // se valida que se encuentren todas las lineas integradas para revertir, para tipo de documento Factura.
    procedure ValReturnFacSalesExist(DocumentNo: Code[20]; SalesHeader: Record "Sales Header"; var MessageText: Text): Boolean
    var
        myInt: Integer;
        SalesInvoceLine: Record "Sales Invoice Line";
        SalesLine: Record "Sales Line";
        text000: label 'No se puede procesar, faltan lineas de produtos para la Factura %1';
    begin
        SalesInvoceLine.Reset();
        SalesInvoceLine.SetRange("Document No.", DocumentNo);
        if SalesInvoceLine.Find('-') then
            repeat
                SalesLine.Reset();
                SalesLine.SetRange(SalesLine."FSN fac No", SalesInvoceLine."Document No.");
                SalesLine.SetRange(SalesLine."FSN Line No", SalesInvoceLine."Line No.");
                if not SalesLine.FindFirst() then begin
                    MessageText := StrSubstNo(text000, SalesLine."FSN fac No");
                    exit(false);
                end;

            until SalesInvoceLine.Next() = 0;
        exit(True);

    end;

    //crea el Json para anular el documento
    local procedure CreateAnulationFacVenta(dteTransaction: Record "FSN DTE Transaction Header"; var SalesHeader: Record "Sales Header"): JsonObject
    var
        json, customerTaxID : JsonObject;
        jValue: JsonValue;
        jToken: JsonToken;
        company: Record "Company Information";
        customer: Record Customer;
        transSales: Record "LSC Trans. Sales Entry";
        _terminal: Text;
        docTye: Enum "FSN DTE Tax ID Type";
    begin
        company.Get();

        //? Verificar los datos del cliente
        if not customer.Get(SalesHeader."Sell-to Customer No.") then
            exit(json);

        json.Add('nit', company."Federal ID No.");
        json.Add('tipoDte', dteTransaction."Document Type");
        json.Add('docGUID', dteTransaction."DTE AuthNumber");
        json.Add('fechaEmision', dteTransaction."Creating Date");
        jValue.SetValueToNull();
        json.Add('newDocGUID', jValue);
        json.Add('nombreEstablecimiento', company.Name);
        json.Add('tipoAnulacion', 2);
        json.Add('motivoAnulacion', 'error en el documento');
        json.Add('nombreResponsable', company.Name);
        json.Add('numDocumentoResponsable', company."Federal ID No.");
        json.Add('tipoDocumentoResponsable', Format(docTye::NIT.AsInteger()));
        json.Add('nombreSolicitante', customer.Name);
        //? obtener la informacion del cliente
        customerTaxID := getTaxInformation(customer);
        if customer."LSC Retail Customer Group" <> 'COMODIN' then begin
            customerTaxID.SelectToken('Value', jToken);
            json.Add('numDocumentoSolicitante', jToken);
            customerTaxID.SelectToken('ID', jToken);
            json.Add('tipoDocumentoSolicitante', jToken);
        end ELSE begin
            json.Add('numDocumentoSolicitante', jValue);
            json.Add('tipoDocumentoSolicitante', jValue);
        end;
        exit(json);
    end;


    //recibe el Json y anula el documento de venta
    procedure GenerateAndSendAnulation(FSN_DTE: Record "FSN DTE Transaction Header"; var SalesHeader: Record "Sales Header"; json: JsonObject)
    var
        requestHeader, contentHeader : HttpHeaders;
        isEnabled: Boolean;
        body: HttpContent;
        request: HttpRequestMessage;
        content: Text;
        uri: Text;
        response: JsonObject;
        FSNParameter: Record "FSN Parameter";
        DTESign_: text[50];
        TokenDTE: text;
        api: Codeunit "DTE API Connection";
    begin

        IF FSNParameter.GET('DTE_INVOICE', 'PURCHASE') THEN
            IF FSNParameter.Activo THEN BEGIN

                uri := FSNParameter."Web Uri" + 'CancelInvoice';
                json.WriteTo(content);
                body.WriteFrom(content);
                body.GetHeaders(contentHeader);
                contentHeader.Clear();
                contentHeader.Add('Content-Type', 'application/json');
                request.GetHeaders(requestHeader);
                requestHeader.Clear();
                request.Content := body;
                IF FSNParameter.GET('DTE_INVOICE', 'PURCH_TOKEN') THEN;
                GetTokenAPIDTE(FSNParameter, '', SalesHeader."No.", DTESign_, TokenDTE);//28981
                requestHeader.Add('Authorization', 'Bearer ' + TokenDTE);
                response := api.Post(uri, request);
                UpdateInvoice(FSN_DTE, json, response);
            end;
    end;

    //recibe el reponse y evalua la repuesta
    local procedure UpdateInvoice(dteTransaction: Record "FSN DTE Transaction Header"; request: JsonObject; response: JsonObject)
    var
        jToken: JsonToken;
        jObject: JsonObject;

        text002: Label 'Failed to generate invoice Sales';
    begin
        if (not response.SelectToken('status', jToken)) or (jToken.AsValue().AsInteger() <> 200) then begin
            Error(text002);
            exit;
        end;

        if request.Get('docGUID', jToken) then;
        dteTransaction.Status := dteTransaction.Status::Anulled;
        dteTransaction.Modify(true);
    end;


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Copy Document Mgt.", 'OnBeforeCopySalesInvLinesToBuffer', '', true, true)]
    local procedure "Copy Document Mgt._OnBeforeCopySalesInvLinesToBuffer"
(
    var FromSalesLine: Record "Sales Line";
    var FromSalesInvLine: Record "Sales Invoice Line";
    var ToSalesHeader: Record "Sales Header"
)
    begin
        FromSalesLine."FSN fac No" := FromSalesInvLine."Document No.";//120925
        FromSalesLine."FSN Line No" := FromSalesInvLine."Line No.";
    end;

    //Se hace .get el record para evitar el error de que se ha actualizado el dato de la tabla
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales Post via Job Queue", 'OnBeforeReleaseSalesDoc', '', true, true)]
    local procedure "Sales Post via Job Queue_OnBeforeReleaseSalesDoc"(var SalesHeader: Record "Sales Header")
    begin
        if SalesHeader."Document Type" IN [SalesHeader."Document Type"::Invoice, SalesHeader."Document Type"::"Credit Memo"] then
            if SalesHeader.get(SalesHeader."Document Type", SalesHeader."No.") then;
    end;

    //se certifica factura venta y nota de credito venta, se comento las ventas ya que se certifican en la cola de proyecto,
    //caso contrario se habilita para se certifiquen desde el registrar
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post (Yes/No)", 'OnAfterConfirmPost', '', true, true)]
    local procedure "Sales-Post (Yes/No)_OnAfterConfirmPost"(var SalesHeader: Record "Sales Header")
    var
        DocSubType: Record "Document Sub Type";
        p: Page "Sales Credit Memo";
        parameter: Record "FSN Parameter";
    begin

        /*if parameter.get('DTE_INVOICE', 'PURCHASE') and parameter.Activo then begin
            //RegistrarL
            if SalesHeader."Document Type" IN [SalesHeader."Document Type"::Invoice] then
                if DocSubType.Get(SalesHeader."Sub Type") and DocSubType."DTE Certify" then
                    DTESalesInvoice(SalesHeader);

            if SalesHeader."Document Type" IN [SalesHeader."Document Type"::"Credit Memo"] then
                if DocSubType.Get(SalesHeader."Sub Type") and DocSubType."DTE Certify" then begin
                    ValDocumentRegistCreditNo(SalesHeader);
                    ProcessCreditNotSales(SalesHeader);
                end;
        end;*/
    end;

    [EventSubscriber(ObjectType::Page, Page::"Sales Credit Memo", 'OnBeforeActionEvent', 'Release', true, true)]
    local procedure "Sales Credit Memo_OnBeforeActionEvent_[processing / Action7] - Release"(var Rec: Record "Sales Header")
    begin
        ValDocumentRegistCreditNo(Rec);
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
        SalesHeader: Record "Sales Header";
        POSSESION: Codeunit "LSC POS Session";
        DocumentSubTypeValue: Record "Document Sub Type";
        FSN_DTE: Record "FSN DTE Transaction Header";
        parameter: Record "FSN Parameter";
    begin
        //se controla si se encuentra certificada cuando se le da registrar y se envia a la cola de proyecto 
        //si no se procesa la certificacion
        //DTE para Facturas Venta
        if parameter.Get('DTE_INVOICE', 'PURCHASE') and parameter.Activo then begin
            IF JobQueueEntry."Object ID to Run" in [88] THEN begin
                IF RecRef.Get(JobQueueEntry."Record ID to Process") THEN BEGIN
                    RecRef.SetTable(SalesHeader);
                    if SalesHeader.Find then begin
                        if SalesHeader."Document Type" IN [SalesHeader."Document Type"::Invoice] then
                            if DocumentSubTypeValue.Get(SalesHeader."Sub Type") then begin
                                if DocumentSubTypeValue."DTE Certify" then
                                    DTESalesInvoice(SalesHeader);
                            end;

                        if SalesHeader."Document Type" IN [SalesHeader."Document Type"::"Credit Memo"] then
                            if DocumentSubTypeValue.Get(SalesHeader."Sub Type") and DocumentSubTypeValue."DTE Certify" then begin
                                ProcessCreditNotSales(SalesHeader);
                            end;

                    end;
                END;
            end;
        end;
    end;

    //se controla que no se pueda eliminar la cola de proyecto si ya se certifico.
    [EventSubscriber(ObjectType::Table, Database::"Job Queue Entry", 'OnBeforeDeleteEvent', '', true, true)]
    local procedure "Job Queue Entry_OnBeforeDeleteEvent"
    (
        var Rec: Record "Job Queue Entry";
        RunTrigger: Boolean
    )
    var
        SalesHeader: Record "Sales Header";
        PurchHeader: Record "Purchase Header";
        FSN_DTE: Record "FSN DTE Transaction Header";
        RecRef: RecordRef;
        Errortext: Label 'No puede eliminar Cola de proyecto ya certificada';
    begin
        IF Rec."Object ID to Run" = 88 THEN begin
            /*if RecRef.Get(Rec."Record ID to Process") then begin//28981
                RecRef.SetTable(SalesHeader);
                if SalesHeader.Find then
                    IF FSN_DTE.GET(COPYSTR(SalesHeader."No.", 1, 10), COPYSTR(SalesHeader."No.", 11, 10), 0) THEN BEGIN
                        IF SalesHeader."External Document No." = FSN_DTE."DTE Invoice" THEN BEGIN
                            IF (FSN_DTE."DTE AuthNumber" <> '') AND (FSN_DTE."Signature Validation" <> '') THEN
                                Error(Errortext);
                        END;
                    END;
            end;*/
        end;
    end;

    // se valida que no se pueda modificar documento externo con sub tipo documento activo para DTE
    [EventSubscriber(ObjectType::Page, Page::"Sales Invoice", 'OnBeforeValidateEvent', 'External Document No.', true, true)]
    local procedure "Sales Invoice_OnBeforeValidateEvent_[content / General] - External Document No."(var Rec: Record "Sales Header")
    VAR
        DocumentSubTypeValue: Record "Document Sub Type";
        ERR001: label 'No puede modificar N° Documento Externo con sub tipo documento activo para DTE';
        ERR002: label 'No puede modificar N° Documento Externo, para Factura Venta(Vending)';
        FSNUtility: Codeunit "FSN Utility";
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        Processed: Boolean;
        PosMenuLineTemp: Record "LSC POS Menu Line" temporary;
        ErrorMessage: text;
    begin
        if DocumentSubTypeValue.Get(Rec."Sub Type") then begin
            if DocumentSubTypeValue."DTE Certify" then
                ERROR(ERR001);
        end;

        Processed := false;
        RequestID := 'VENDINGVAL';
        XMLRequest := Rec."No.";
        FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, ErrorMessage);

        if Processed then
            ERROR(ERR002);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales Batch Post Mgt.", 'OnBeforeRunBatch', '', true, true)]
    local procedure "Sales Batch Post Mgt._OnBeforeRunBatch"
    (
        var SalesHeader: Record "Sales Header";
        var ReplacePostingDate: Boolean;
        PostingDate: Date;
        ReplaceDocumentDate: Boolean;
        Ship: Boolean;
        Invoice: Boolean
    )
    var
        DocumentSubTypeValue: Record "Document Sub Type";
    begin
        if DocumentSubTypeValue.Get(SalesHeader."Sub Type") then begin
            /*if DocumentSubTypeValue."DTE Certify" then
                DTESalesInvoice(SalesHeader);*/
        end;
    end;


    //manda a certificar la ejecucion de la cola de proyecto
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Batch Processing Mgt.", 'OnBeforeBatchShouldBeProcessedInBackground', '', true, true)]
    local procedure "Batch Processing Mgt._OnBeforeBatchShouldBeProcessedInBackground"
     (
         var RecRef: RecordRef;
         var IsProcessed: Boolean
     )
    var
        SalesHeader: Record "Sales Header";
        DocumentSubTypeValue: Record "Document Sub Type";
        Parameter: Record "FSN Parameter";
    begin

        if Parameter.Get('DTE_INVOICE', 'PURCHASE') and Parameter.Activo then begin
            RecRef.SetTable(SalesHeader);
            if SalesHeader.FindSet() then
                repeat

                    if SalesHeader."Document Type" IN [SalesHeader."Document Type"::Invoice] then
                        if DocumentSubTypeValue.Get(SalesHeader."Sub Type") and DocumentSubTypeValue."DTE Certify" then
                            DTESalesInvoice(SalesHeader);

                    if SalesHeader."Document Type" IN [SalesHeader."Document Type"::"Credit Memo"] then
                        if DocumentSubTypeValue.Get(SalesHeader."Sub Type") and DocumentSubTypeValue."DTE Certify" then begin
                            ProcessCreditNotSales(SalesHeader);
                        end;

                until SalesHeader.Next() = 0;
            RecRef.GetTable(SalesHeader);
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Approvals Mgmt.", 'OnBeforePrePostApprovalCheckSales', '', true, true)]
    local procedure "Approvals Mgmt._OnBeforePrePostApprovalCheckSales"
(
    var SalesHeader: Record "Sales Header";
    var IsHandled: Boolean
)
    VAR
        DocumentSubTypeValue: Record "Document Sub Type";
    begin
        /*if DocumentSubTypeValue.Get(SalesHeader."Sub Type") then begin
            if DocumentSubTypeValue."DTE Certify" then
                DTESalesInvoice(SalesHeader);
            IF SalesHeader.GET(SalesHeader."Document Type", SalesHeader."No.") THEN;
        end;*/
    end;

    [EventSubscriber(ObjectType::Table, Database::"Sales Line", 'OnBeforeInsertEvent', '', true, true)]
    local procedure "Sales Line_OnBeforeInsertEvent"
    (
        var Rec: Record "Sales Line";
        RunTrigger: Boolean
    )
    begin
        if Rec."Document No." = Rec."Document No." then
            if Rec."Document No." = Rec."Document No." then;
    end;

    //Se valida si el subTipo documento se encuentra activo para certificar DTE
    procedure ValSubTypeDTE(SubType: code[20]): Boolean
    var
        myInt: Integer;
        DocumentTypeValidate: Record "Document Sub Type";
    begin
        if DocumentTypeValidate.get(SubType) then
            IF DocumentTypeValidate."DTE Certify" THEN
                exit(false)
            ELSE
                exit(true);

    end;

    //Se valida que el documento cargado este certificados
    procedure ValDocumentRegistCreditNo(SalesHeader: Record "Sales Header")
    var
        myInt: Integer;
        SalesLine: Record "Sales Line";
        DocumentType: Record "Document Sub Type";
        SalesInvHeader: Record "Sales Invoice Header";
        DocumentTypeValidate: Record "Document Sub Type";
        DTEdocumentNumber: Code[36];
        DocType: Code[2];
        DocDate: Date;
        TEXTM000: Label 'N° documento %1 no se encuentra certificado';
    begin
        if DocumentType.get(SalesHeader."Sub Type") then
            if DocumentType."DTE Certify" then
                IF DocumentType.Prefix in ['05', '5'] THEN begin//080925
                    SalesLine.RESET;
                    SalesLine.SETRANGE(SalesLine."Document No.", SalesHeader."No.");
                    SalesLine.SETRANGE(SalesLine.Type, SalesLine.Type::Item);
                    SalesLine.SETFILTER(SalesLine.Quantity, '>0');
                    IF SalesLine.FIND('-') THEN
                        REPEAT
                            if SalesInvHeader.get(SalesLine."FSN fac No") then
                                if DocumentTypeValidate.get(SalesInvHeader."Sub Type") then begin
                                    case DocumentTypeValidate.Prefix of
                                        '03':
                                            begin
                                                returnFacSales(SalesLine."FSN fac No", DTEdocumentNumber, DocType, DocDate);
                                                if DTEdocumentNumber = '' then
                                                    Error(StrSubstNo(TEXTM000, SalesLine."FSN fac No"));
                                            end;

                                    end;
                                end;
                        UNTIL SalesLine.Next() = 0;

                    SalesLine.RESET;
                    SalesLine.SETRANGE(SalesLine."Document No.", SalesHeader."No.");
                    SalesLine.SETRANGE(SalesLine.Type, SalesLine.Type::"G/L Account");
                    SalesLine.SETFILTER(SalesLine.Quantity, '>0');
                    IF SalesLine.FIND('-') THEN
                        REPEAT
                            if SalesInvHeader.get(SalesLine."FSN fac No") then
                                if DocumentTypeValidate.get(SalesInvHeader."Sub Type") then begin
                                    case DocumentTypeValidate.Prefix of
                                        '03':
                                            begin
                                                returnFacSales(SalesLine."FSN fac No", DTEdocumentNumber, DocType, DocDate);
                                                if DTEdocumentNumber = '' then
                                                    Error(StrSubstNo(TEXTM000, SalesLine."FSN fac No"));
                                            end;

                                    end;
                                end;
                        UNTIL SalesLine.Next() = 0;
                end;
    end;

    [EventSubscriber(ObjectType::Page, Page::"Sales Cr. Memo Subform", 'OnDeleteRecordEvent', '', true, true)]
    local procedure "Sales Cr. Memo Subform_OnDeleteRecordEvent"
    (
        var Rec: Record "Sales Line";
        var AllowDelete: Boolean
    )
    var
        SalesHeader: Record "Sales Header";
        DocumentTypeValidate: Record "Document Sub Type";
        TXT000: Label 'No puede eliminar lineas de documento tipo Dev Consumidor Final';
    begin
        if SalesHeader.Get(Rec."Document Type", Rec."Document No.") then
            if DocumentTypeValidate.Get(SalesHeader."Sub Type") then
                if (DocumentTypeValidate."DTE Certify") and (DocumentTypeValidate.Prefix = '99') then
                    Error(TXT000);
    end;


}

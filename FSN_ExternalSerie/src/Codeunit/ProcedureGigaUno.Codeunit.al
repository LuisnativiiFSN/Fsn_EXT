codeunit 50012 "FSN Procedure Giga Uno"
{
    TableNo = "LSC POS Menu Line";

    trigger OnRun()
    begin
        GlobalGigaUnoRec := Rec;
        case Command OF
            'NCFCRF':
                ValidateGigaUnoDocument(Command);
            'NCFFCF':
                ValidateGigaUnoDocument(Command);
            ELSE
        end;
    end;

    var
        GlobalGigaUnoRec: Record "LSC POS Menu Line";
        PosTransG: Record "LSC POS Transaction";
        POSGUI: Codeunit "LSC POS GUI";
        NoSeriesMgt: Codeunit NoSeriesManagement;
        POSSession: codeunit "LSC POS Session";
        lText002: Label 'You cannot new numbers from the number series %1';
        lText003: Label 'There is no Serial Code';
        Texto: array[2] of text[75];
        printUtility: Codeunit "FSN Utility";
        PosTrans: Codeunit "LSC POS Transaction";
        TotFac: Text[100];
        vDecimalesTextoFactura: Text[100];
        XmlReport: XmlPort "FSN XmlPortTransactionReport";

    //llama al procedimiento InsertCorrTK para insert del correlativo con el comando 'START'
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnAfterStartNewTransaction', '', true, true)]
    local procedure "POS Transaction Events_OnAfterStartNewTransaction"(var POSTransaction: Record "LSC POS Transaction")
    begin
        InsertCorrTK(POSTransaction);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnBeforeTotalExecuted', '', true, true)]
    local procedure "LSC POS Transaction Events_OnBeforeTotalExecuted"
    (
        var POSTransaction: Record "LSC POS Transaction";
        var IsHandled: Boolean
    )
    var
        POSTransLine_l: Record "LSC POS Trans. Line";
        lText001: label 'Cantidad de lineas es %1, excede el limite de lineas que son %2 para Tipo documento %3';
        ItemParameter: Record "FSN Parameter";
        LineNo: Integer;
        Terminal: Record "LSC POS Terminal";
        nos: Record "No. Series Line";
        num: Integer;
        Parametros: Record "FSN Parameter";
        transLine: Record "LSC POS Trans. Line";
        incomeExpense: Record "LSC Income/Expense Account";
        onlyTicket: Boolean;
        TxtN: Text;
    begin

        transLine.SetRange("Store No.", POSTransaction."Store No.");
        transLine.SetRange("POS Terminal No.", POSTransaction."POS Terminal No.");
        transLine.SetRange("Receipt No.", POSTransaction."Receipt No.");
        transLine.setRange("Entry Type", transLine."Entry Type"::IncomeExpense);
        transLine.setRange("Entry Status", transLine."Entry Status"::" ");
        if transLine.FindFirst() then
            repeat
                if incomeExpense.GET(transLine."Store No.", transLine.number) then
                    onlyTicket := incomeExpense."Only Ticket";
            until (transLine.Next() = 0) or onlyTicket;

        IsHandled := blockCustomerInDocumentType(POSTransaction, onlyTicket);

        IF IsHandled then
            exit;

        IF NOT IsHandled THEN
            IF NOT InsertCorrTK(POSTransaction) THEN
                IsHandled := true;


        IF NOT IsHandled THEN begin
            IF (POSTransaction."FSN Document Type" IN [POSTransaction."FSN Document Type"::Factura, POSTransaction."FSN Document Type"::"Credito Fiscal"])
              AND NOT POSTransaction."FSN Remission No." THEN BEGIN
                LineNo := 20;

                ItemParameter.Reset();
                ItemParameter.SetCurrentKey(Grupo, Codigo);
                ItemParameter.SetRange(ItemParameter.Grupo, 'POS');
                ItemParameter.SetRange(ItemParameter.Codigo, 'ITEMLINE');
                ItemParameter.SetFilter(ItemParameter.Valor, '<>%1', ' ');
                if ItemParameter.FindFirst() then
                    LineNo := ItemParameter."Limit Value";

                POSTransLine_l.RESET;
                POSTransLine_l.SETCURRENTKEY("Receipt No.", "Entry Type", "Entry Status");
                POSTransLine_l.SETRANGE(POSTransLine_l."Receipt No.", POSTransaction."Receipt No.");
                POSTransLine_l.SETRANGE(POSTransLine_l."Entry Type", POSTransLine_l."Entry Type"::Item);
                POSTransLine_l.SETFILTER(POSTransLine_l."Entry Status", '<>%1', POSTransLine_l."Entry Status"::Voided);
                IF (POSTransLine_l.COUNT) > LineNo THEN BEGIN
                    POSGUI.PosMessage(STRSUBSTNO(lText001, FORMAT(POSTransLine_l.COUNT), LineNo, POSTransaction."FSN Document Type"));
                    IsHandled := true;
                END;
            END;
        end;
        Parametros.Reset();
        Parametros.SetRange(Grupo, 'DOCFACT');
        Parametros.SetRange(Codigo, 'DFAC');
        if Parametros.FindFirst() then
            if Parametros.Activo then begin
                if not excludeOfValidation(POSTransaction) then
                    if (POSTransaction."FSN Document Type" = POSTransaction."FSN Document Type"::Ticket) then begin
                        if POSTransaction."Retrieved from Receipt No." = '' then
                            if Terminal.Get(POSTransaction."POS Terminal No.") then begin
                                POSTransaction."FSN Document Type" := POSTransaction."FSN Document Type"::Factura;
                                POSTransaction."FSN No. Serie NCF" := Terminal."FSN No. Serie NCF Cons. Final";
                                nos.Reset();
                                nos.SetRange("Series Code", Terminal."FSN No. Serie NCF Cons. Final");
                                if Nos.FindFirst() then begin
                                    POSTransaction."FSN NCF" := NoSeriesMgt.GetNextNo(nos."Series Code", Today, true);
                                    POSTransaction."FSN Correlative" := POSTransaction."FSN NCF";
                                end;
                                POSTransaction.Modify();
                                POSSession.SetValue('DocTrans', FORMAT(POSTransaction."FSN Document Type"::Factura));
                            end;
                    end;
            end;
    end;

    //CAMBIO DE VALIDACION DE CLIENTE DTE A EXTERNALSERIES
    local procedure blockCustomerInDocumentType(var POSTransaction: Record "LSC POS Transaction"; onlyTicket: Boolean): Boolean;
    var
        customer: Record Customer;
        attribute: Record "LSC Attribute Value";
        PosTransLine: Record "LSC POS Trans. Line";
    begin
        if POSTransaction."Sale Is Return Sale" then
            exit(false);

        PosTransLine.RESET;
        PosTransLine.SETCURRENTKEY(PosTransLine."Receipt No.", PosTransLine."Entry Type", PosTransLine."Entry Status");
        PosTransLine.SETRANGE(PosTransLine."Receipt No.", POSTransaction."Receipt No.");
        PosTransLine.SETFILTER(PosTransLine."Entry Type", '%1|%2', PosTransLine."Entry Type"::Item, PosTransLine."Entry Type"::IncomeExpense);
        PosTransLine.SETFILTER(PosTransLine."Entry Status", '<>%1', PosTransLine."Entry Status"::Voided);
        IF NOT PosTransLine.FINDFIRST THEN BEGIN
            EXIT(true);
        END;

        PosTransLine.Reset();
        PosTransLine.SetRange("Receipt No.", POSTransaction."Receipt No.");
        PosTransLine.SetRange("POS Terminal No.", POSTransaction."POS Terminal No.");
        PosTransLine.SetRange("Entry Type", PosTransLine."Entry Type"::Item);
        PosTransLine.SetFilter("FSN Remission No.", '<>%1', '');
        IF PosTransLine.FindFirst() then begin
            if (POSTransaction."FSN Document Type" = POSTransaction."FSN Document Type"::Ticket) then begin
                Message('CO-ASEGURO no pueden ser facturado con tipo de documento Ticket');
                exit(true);
            end;
        end;

        if onlyTicket then begin
            if POSTransaction."FSN Document Type" <> POSTransaction."FSN Document Type"::Ticket then begin
                Message('No puede realizar transacciones diferentes a Ticket');
                exit(true);
            end;
        end else begin
            if not customer.Get(POSTransaction."Customer No.") then
                exit(true);

            attribute.SetRange("Attribute Code", 'CLIENTES');
            attribute.SetRange("Link Type", attribute."Link Type"::Customer);
            attribute.SetRange("Link Field 1", Customer."No.");

            attribute.SetRange("Attribute Value", 'SOLO CREDITO FISCAL');
            if attribute.FindSet() then begin
                if POSTransaction."FSN Document Type" <> POSTransaction."FSN Document Type"::"Credito Fiscal" then begin
                    Message('El cliente ' + customer.Name + ' no puede realizar transacciones diferentes a Credito Fiscal');
                    exit(true);
                end;
            end;

            if customer."FSN Customer VAT Type" = customer."FSN Customer VAT Type"::Perception then
                if POSTransaction."FSN Document Type" <> POSTransaction."FSN Document Type"::"Credito Fiscal" then begin
                    Message('El cliente percepcion ' + customer.Name + ' no puede realizar transacciones diferentes a Credito Fiscal');
                    exit(true);
                end;

            attribute.SetRange("Attribute Value", 'SOLO FACTURA');
            if attribute.FindSet() then begin
                if POSTransaction."FSN Document Type" <> POSTransaction."FSN Document Type"::Factura then begin
                    Message('El cliente ' + customer.Name + ' no puede realizar transacciones diferentes a Factura');
                    exit(true);
                end;
            end;
        end;
    end;

    //valida que serie no este terminada
    procedure ValidateSerie(CodeSerie: Code[20]): Boolean
    var
        NoSeriesLine: Record "No. Series Line";
    begin

        NoSeriesLine.reset;
        NoSeriesLine.SetRange(NoSeriesLine."Series Code", CodeSerie);
        if NoSeriesLine.FindFirst then begin
            IF NoSeriesLine."Ending No." = NoSeriesLine."Last No. Used" THEN BEGIN
                POSGUI.PosMessage(StrSubstNo(lText002, CodeSerie));
                exit(false);
            end else begin
                exit(true);
            end;
        end else begin
            POSGUI.PosMessage(lText003);
            exit(false);
        end;
    end;

    //Hace insertde correlativo al iniciar transaccion con comando START o  Escanear producto.
    procedure InsertCorrTK(var POSTransaction: Record "LSC POS Transaction"): Boolean;
    var
        noSerieInsert: Text;
        POSTerminalInsert: Record "LSC POS Terminal";
        NoSeriesLine: Record "No. Series Line";
        DocumentTypeText: Text;
        ValidateExtSerie: Boolean;
        lText001: Label 'There is no Serial Code for ticket';
    begin
        clear(noSerieInsert);
        POSTerminalInsert.get(POSTransaction."POS Terminal No.");
        if POSTransaction."FSN No. Serie NCF" = '' then begin
            if POSTerminalInsert."FSN No. Serie NCF Ticket" = '' then begin
                POSTransaction."FSN Document Type" := POSTransaction."FSN Document Type"::Ticket;
                POSTransaction.Modify;
                POSGUI.PosMessage(lText001);
                exit(false);
            end else begin
                ValidateExtSerie := ValidateSerie(POSTerminalInsert."FSN No. Serie NCF Ticket");
                if ValidateExtSerie then begin
                    noSerieInsert := NoSeriesMgt.GetNextNo(format(POSTerminalInsert."FSN No. Serie NCF Ticket"), Today, FALSE);
                    if noSerieInsert <> '' then begin
                        ValidateDocumentType(FORMAT(POSTransaction."FSN Document Type"::Ticket));
                        POSTransaction."FSN Document Type" := POSTransaction."FSN Document Type"::Ticket;
                        POSTransaction."FSN No. Serie NCF" := POSTerminalInsert."FSN No. Serie NCF Ticket";
                        POSTransaction."FSN NCF" := noSerieInsert;
                        POSTransaction."FSN Correlative" := noSerieInsert;
                        POSTransaction.Modify;
                        exit(true);
                    end else begin
                        exit(false);
                    end;
                end else begin
                    POSGUI.PosMessage(lText001);
                    exit(false);
                end;
            end;
        end else begin
            exit(true);
        end;
    end;

    //valida que exista numero de Serie
    procedure ValidateGigaUnoDocument(ComandoCF: Code[20])
    var
        POSTerminalG: Record "LSC POS Terminal";
        CustomerG: Record Customer;
        NoSerieLineGiga: Record "No. Series Line";
        posTransactionV: Record "LSC POS Transaction";
        NoSerie: Text;
        GigaValidate: Boolean;
        ValidateExtSerie: Boolean;
        TypeDocument: Text;
        lText001: Label 'You must select a customer for document type CCF or CF.';
        lText002: Label 'Debe asignar cliente para tipo documento.';
        TipoDoc: Code[20];
        NoSeries: Record "No. Series";
        Text000: label 'No Serie';
        eposInterface: Codeunit "LSC POS Control Interface";
        Menss000: Label 'No se puede cambiar tipo documento en dovoluciones';
    begin
        Clear(TipoDoc);
        clear(NoSerie);
        POSSession.SetValue('#CodSerie', ' ');
        POSSession.SetValue('#ComandSerie', ' ');
        IF posTransactionV.Get(GlobalGigaUnoRec."Current-RECEIPT") then begin
            ValInconExt(posTransactionV);
            if posTransactionV."FSN Document Type" <> posTransactionV."FSN Document Type"::"Devolucion Factura" then begin
                PosTerminalG.GET(posTransactionV."POS Terminal No.");
                if CustomerG.get(posTransactionV."Customer No.") then begin
                    case ComandoCF of
                        'NCFCRF':
                            TipoDoc := POSTerminalG."FSN No. Serie Credito Fiscal";
                        'NCFFCF':
                            TipoDoc := POSTerminalG."FSN No. Serie NCF Cons. Final";
                        else
                            POSGUI.PosMessage(lText003);
                            exit;
                    end;
                    NoSeries.Reset();
                    if NoSeries.Get(TipoDoc) then begin
                        POSSession.SetValue('#CodSerie', TipoDoc);
                        if NoSeries."Manual Nos." then begin
                            POSSession.SetValue('#ComandSerie', ComandoCF);
                            POSGUI.OpenNumericKeyboard(Text000, 0, '', 0, ComandoCF);
                        end else begin
                            if ValidateSerie(TipoDoc) then begin
                                NoSerie := NoSeriesMgt.GetNextNo(TipoDoc, Today, FALSE);
                                if NoSerie <> '' then begin
                                    if GlobalGigaUnoRec.Command = 'NCFCRF' then begin
                                        ValidateDocumentType(FORMAT(POSTransG."FSN Document Type"::"Credito Fiscal"));
                                    end else begin
                                        ValidateDocumentType(FORMAT(POSTransG."FSN Document Type"::Factura));
                                    end;
                                    posTransactionV."FSN DUI" := CustomerG."FSN DUI";
                                    posTransactionV."FSN Customer Name" := CustomerG.Name;
                                    posTransactionV."FSN No. Serie NCF" := TipoDoc;
                                    posTransactionV."FSN NCF" := NoSerie;
                                    posTransactionV."FSN Correlative" := NoSerie;
                                    posTransactionV."FSN NRC" := CustomerG."FSN NRC";
                                    posTransactionV."FSN Direction" := CustomerG.Address;
                                    posTransactionV."Address 2" := CustomerG."Address 2";
                                    if GlobalGigaUnoRec.Command = 'NCFCRF' then
                                        posTransactionV."FSN Document Type" := POSTransG."FSN Document Type"::"Credito Fiscal"
                                    else
                                        posTransactionV."FSN Document Type" := POSTransG."FSN Document Type"::Factura;
                                    posTransactionV.Modify;
                                end else begin
                                    exit;
                                end;
                            end else begin
                                if GlobalGigaUnoRec.Command = 'NCFCRF' then
                                    posTransactionV."FSN Document Type" := POSTransG."FSN Document Type"::"Credito Fiscal"
                                else
                                    posTransactionV."FSN Document Type" := POSTransG."FSN Document Type"::Factura;
                                posTransactionV.Modify;
                                exit;
                            end;
                        end;
                    end else begin
                        POSGUI.PosMessage(lText003);
                    end;
                end else begin
                    Message(lText002);
                end;
            end else
                Message(Menss000);
        end;
    end;

    //se filtra numero de serie que este en estado abierto.
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"NoSeriesManagement", 'OnNoSeriesLineFilterOnBeforeFindLast', '', true, true)]
    local procedure "NoSeriesManagement_OnNoSeriesLineFilterOnBeforeFindLast"(var NoSeriesLine: Record "No. Series Line")
    var
    begin
        NoSeriesLine.SetRange(Open, true);
    end;


    //Result procedure Numero Serie OpenNumericKeyboard
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Controller", 'OnNumpadResult', '', true, true)]
    local procedure "LSC POS Controller_OnNumpadResult"
    (
        payload: Text;
        inputValue: Text;
        resultOK: Boolean;
        var processed: Boolean
    )
    var
        ValueInt: Integer;
    begin
        if payload in ['NCFCRF', 'NCFFCF'] then begin
            ValueNoSerie(inputValue, payload);
            processed := true;
        end;
    end;

    procedure ValueNoSerie(NoSerie: Text; payloadComand: Text): Boolean
    var
        posTransactionS: Record "LSC POS Transaction";
        PosTerminalG: Record "LSC POS Terminal";
        CustomerG: Record Customer;
        TipoDoc: Code[20];
    begin
        if NoSerie <> '' then begin
            IF posTransactionS.Get(PosTrans.GetReceiptNo()) then begin
                PosTerminalG.GET(posTransactionS."POS Terminal No.");
                CustomerG.get(posTransactionS."Customer No.");

                case payloadComand of
                    'NCFCRF':
                        TipoDoc := POSTerminalG."FSN No. Serie Credito Fiscal";
                    'NCFFCF':
                        TipoDoc := POSTerminalG."FSN No. Serie NCF Cons. Final";
                    else
                        POSGUI.PosMessage(lText003);
                        exit;
                end;

                posTransactionS."FSN DUI" := CustomerG."FSN DUI";
                posTransactionS."FSN Customer Name" := CustomerG.Name;
                posTransactionS."FSN No. Serie NCF" := TipoDoc;
                posTransactionS."FSN NCF" := NoSerie;
                posTransactionS."FSN Correlative" := NoSerie;
                posTransactionS."FSN NRC" := CustomerG."FSN NRC";
                posTransactionS."FSN Direction" := CustomerG.Address;
                posTransactionS."Address 2" := CustomerG."Address 2";
                if payloadComand = 'NCFCRF' then begin
                    posTransactionS."FSN Document Type" := POSTransG."FSN Document Type"::"Credito Fiscal";
                    ValidateDocumentType(FORMAT(POSTransG."FSN Document Type"::"Credito Fiscal"));
                end else begin
                    posTransactionS."FSN Document Type" := POSTransG."FSN Document Type"::Factura;
                    ValidateDocumentType(FORMAT(POSTransG."FSN Document Type"::Factura));
                end;
                posTransactionS.Modify;
                exit(true);
            end;
        end else begin
            IF posTransactionS.Get(PosTrans.GetReceiptNo()) then
                ValidateDocumentType(FORMAT(posTransactionS."FSN Document Type"::Ticket));
            exit(false);
        end;
    end;

    //hace insert de numero de Serie en Transaction Header
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Post Utility", 'OnAfterInsertTransHeader', '', true, true)]
    local procedure "POS Post Utility_OnAfterInsertTransHeader"
    (
        var Transaction: Record "LSC Transaction Header";
        var POSTrans: Record "LSC POS Transaction"
    )
    var
        NoSerie: text;
        ResulParam: Boolean;
        NoSerieLine: Record "No. Series Line";
        NoSerieM: Record "No. Series";
        HeaderExt: Record "FSN Transaction Header Ext";
        TransactionHeaderLoc2: Record "LSC Transaction Header";
        NoSerieMgt: Codeunit NoSeriesManagement;
        NoSerieNCF: Code[20];
        NoSeries: Record "No. Series";
    begin
        clear(NoSerieNCF);
        IF POSTrans."Entry Status" <> POSTrans."Entry Status"::Voided THEN BEGIN

            if NoSerieM.Get(POSTrans."FSN No. Serie NCF") and (NoSerieM."Manual Nos.") then
                NoSerieNCF := POSTrans."FSN NCF"
            else
                NoSerieNCF := NoSeriesMgt.GetNextNo(POSTrans."FSN No. Serie NCF", Today, TRUE);

            Transaction."FSN Correlative" := NoSerieNCF;
            Transaction."FSN NCF" := NoSerieNCF;
            Transaction."FSN DUI" := POSTrans."FSN DUI";
            Transaction."FSN No. Serie NCF" := POSTrans."FSN No. Serie NCF";
            Transaction."FSN NFC Affected" := POSTrans."FSN NFC Affected";
            Transaction."FSN Direction" := PosTrans."FSN Direction";
            Transaction."Address 2" := PosTrans."Address 2";
            Transaction."FSN NRC" := PosTrans."FSN NRC";
            Transaction."FSN Document Type" := POSTrans."FSN Document Type";
            Transaction.Rounded := 0;
            Transaction."FSN Remission No." := POSTrans."FSN Remission No.";
            Transaction."Retencion Amount" := POSTrans."FSN Retention Amount";
            Transaction."Perception Amount" := POSTrans."FSN Perception Amount";
            //Si se registra en transaction header agrega el ultimo utilizado.

            NoSerieLine.reset;
            NoSerieMgt.SetNoSeriesLineFilter(NoSerieLine, Transaction."FSN No. Serie NCF", Today);
            if NoSerieLine.FindFirst then begin
                Transaction."FSN Resolution" := FORMAT(NoSerieLine."Authorization Code");
                Transaction."Legal Serie" := NoSerieLine.Series;
                Transaction."FSN Fiscal Serie" := NoSerieLine.Series;
                Transaction."Legal Number" := NoSerieNCF;

                if POSTrans."Sale Is Return Sale" then begin
                    IF POSTrans."FSN Document Type" in [POSTrans."FSN Document Type"::"Nota Credito", POSTrans."FSN Document Type"::"Devolucion Factura"] THEN begin
                        Transaction."Sub Type" := NoSerieLine."FSN SubType Code";
                    end ELSE begin
                        Transaction."Sub Type" := NoSerieLine."FSN Return SubType Code";
                    end;
                end else
                    Transaction."Sub Type" := NoSerieLine."FSN SubType Code";

                if Transaction."FSN Document Type" in [Transaction."FSN Document Type"::"Credito Fiscal",
                Transaction."FSN Document Type"::Factura, Transaction."FSN Document Type"::"Nota Credito"] then begin
                    ResulParam := GigaUnoIsActive(Transaction."Store No.", Transaction."POS Terminal No.");
                    //if ResulParam then begin
                    TransactionHeaderLoc2.Reset;
                    TransactionHeaderLoc2.SetRange("Store No.", Transaction."Store No.");
                    TransactionHeaderLoc2.SetRange("POS Terminal No.", Transaction."POS Terminal No.");
                    if TransactionHeaderLoc2.FindLast then;

                    HeaderExt.init;
                    HeaderExt."Store No." := Transaction."Store No.";
                    HeaderExt."POS Terminal No." := Transaction."POS Terminal No.";
                    HeaderExt."Transaction No." := TransactionHeaderLoc2."Transaction No." + 1;
                    HeaderExt."Receipt No." := Transaction."Receipt No.";
                    HeaderExt."Numero de Factura" := Transaction."FSN NCF";
                    HeaderExt.Fecha := Transaction."Date";
                    HeaderExt.Hora := Transaction."Time";
                    HeaderExt."Nombre Cliente" := Transaction."FSN Customer Name";
                    HeaderExt.DUI := Transaction."FSN DUI";
                    HeaderExt.Serie := NoSerieLine.Series;
                    IF Evaluate(HeaderExt.Desde, NoSerieLine."Starting No.") THEN;
                    IF Evaluate(HeaderExt.Hasta, NoSerieLine."Ending No.") THEN;
                    HeaderExt.Resolucion := Format(NoSerieLine."FSN Autorization");
                    HeaderExt."Fecha Autorizacion" := NoSerieLine."FSN Date Autorization";
                    HeaderExt.Insert;
                    //end;
                end;
            end;
            ValidateDocumentType(FORMAT(PosTransG."FSN Document Type"::Ticket));
        end else begin
            ValidateDocumentType(FORMAT(POSTrans."FSN Document Type"::Ticket));
        end;
    end;

    //Valida que se encuentre activo gigaUno en parametro varios
    procedure GigaUnoIsActive(Store: Code[20]; POSTpv: Code[10]): Boolean
    var
        PosTerminalgU: Record "LSC POS Terminal";
        ParamVarios: Record "FSN Parameter";
        InitNo: Integer;
        lText001: Label 'The Store is not active in Parameter Various';
        lText002: Label 'The Store is not found in Parameter Various';
    begin

        ParamVarios.reset;
        ParamVarios.SetRange(ParamVarios.Grupo, 'GIGAUNO');
        ParamVarios.SetRange(ParamVarios.Codigo, POSTpv);
        if ParamVarios.FindFirst then begin
            if NOT ParamVarios.Activo then begin
                exit(false);
            end else begin
                exit(true);
            end;
        end else begin
            exit(false);
        end;
    end;

    //Agrega tipo Documento en PV DocTrans
    procedure ValidateDocumentType(Doc: Text) ResultDoc: Text
    var
    begin
        POSSession.SetValue('DocTrans', FORMAT(Doc));
        ResultDoc := Doc;
    end;

    //Validate Devolucion
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction", 'OnProcessRefundSelection', '', true, true)]
    local procedure "POS Transaction_OnProcessRefundSelection"
    (
        OriginalTransaction: Record "LSC Transaction Header";
        var POSTransaction: Record "LSC POS Transaction";
        isPostVoid: Boolean
    )
    var
        TipoDoc: Code[20];
        NoSerie: Text;
        ValidateExtSerie: Boolean;
        PosTerminalValidate: Record "LSC POS Terminal";
        POSTransLine: Record "LSC POS Trans. Line";
    begin
        Clear(TipoDoc);
        IF OriginalTransaction."FSN Document Type" = OriginalTransaction."FSN Document Type"::Ticket THEN BEGIN
            ValidateDocumentType(FORMAT(POSTransaction."FSN Document Type"::Ticket));
            POSTransaction."FSN NFC Affected" := OriginalTransaction."FSN NCF";
            POSTransaction.Modify;
        END;

        IF OriginalTransaction."FSN Document Type" = OriginalTransaction."FSN Document Type"::"Credito Fiscal" THEN BEGIN
            PosTerminalValidate.GET(POSTransaction."POS Terminal No.");
            TipoDoc := PosTerminalValidate."FSN No. Serie Nota de Credito";
            if TipoDoc <> '' then begin
                ValidateExtSerie := ValidateSerie(TipoDoc);
                if ValidateExtSerie then begin
                    NoSerie := NoSeriesMgt.GetNextNo(TipoDoc, Today, FALSE);
                    if NoSerie <> '' then begin
                        ValidateDocumentType(FORMAT(POSTransaction."FSN Document Type"::"Nota Credito"));
                        POSTransaction."FSN No. Serie NCF" := TipoDoc;
                        POSTransaction."FSN NCF" := NoSerie;
                        POSTransaction."FSN Correlative" := NoSerie;
                        POSTransaction."FSN NFC Affected" := OriginalTransaction."FSN NCF";
                        posTransaction."FSN Document Type" := posTransaction."FSN Document Type"::"Nota Credito";
                        POSTransaction.Modify;
                    end else begin
                        exit;
                    end;
                end else begin
                    POSTransLine.reset;
                    POSTransLine.setrange(POSTransLine."Receipt No.", POSTransaction."Receipt No.");
                    if POSTransLine.Find('-') then begin
                        repeat
                            POSTransLine.VoidLine();
                        UNTIL POSTransLine.NEXT = 0;
                    end;
                    exit;
                end;
            end else begin
                POSGUI.PosMessage(lText003);
                posTransaction."FSN Document Type" := posTransaction."FSN Document Type"::"Nota Credito";
                POSTransaction.Modify;
                exit;
            end;
        END;

        IF OriginalTransaction."FSN Document Type" = OriginalTransaction."FSN Document Type"::Factura THEN BEGIN
            PosTerminalValidate.GET(POSTransaction."POS Terminal No.");
            TipoDoc := PosTerminalValidate."FSN No. Serie Devolucion";
            if TipoDoc <> '' then begin
                ValidateExtSerie := ValidateSerie(TipoDoc);
                if ValidateExtSerie then
                    NoSerie := NoSeriesMgt.GetNextNo(TipoDoc, Today, FALSE);
                if NoSerie <> '' then begin
                    ValidateDocumentType(FORMAT(POSTransaction."FSN Document Type"::"Devolucion Factura"));
                    POSTransaction."FSN No. Serie NCF" := TipoDoc;
                    POSTransaction."FSN NCF" := NoSerie;
                    POSTransaction."FSN Correlative" := NoSerie;
                    POSTransaction."FSN NFC Affected" := OriginalTransaction."FSN NCF";
                    posTransaction."FSN Document Type" := posTransaction."FSN Document Type"::"Devolucion Factura";
                    POSTransaction.Modify;
                end else begin
                    exit;
                end;
            end else begin
                POSGUI.PosMessage(lText003);
                posTransaction."FSN Document Type" := posTransaction."FSN Document Type"::"Devolucion Factura";
                POSTransaction.Modify;
                exit;
            end;
        END;
    end;

    /////////////////////////////////////////////////////////////////////////////////////////////
    procedure WSGenerarFacturao(var Transaction: Record "LSC Transaction Header"; Tray: Integer; IsHandledE: Boolean)
    var
        rTransInfo: Record "LSC Trans. Infocode Entry";
        SalesEntry: Record "LSC Trans. Sales Entry";
        POSTerminal: Record "LSC POS Terminal";
        ParentItem: Record "Item";
        TotalVentG: Decimal;
        TotalVent: Decimal;
        TotalNoSuj: Decimal;
        TotalPercepcion: Decimal;
        TotalRetencion: Decimal;
        TotalLetras: Text[100];
        rCompanyInfo: Record "Company Information";
        rCustomer: Record "Customer";
        vCopia: Integer;
        vIdDocumento: Integer;
        vResolucionCopia: Text;
        vSerieCopia: Text;
        vDesdeCopia: Integer;
        vHastaCopia: Integer;
        vNcfCopia: Text;
        vGiroEmpresa: Text;
        vSucursal: Text;
        vDireccionSucursal: Text;
        vNitEmpresa: Text;
        vNrcEmpresa: Text;
        vNombreCliente: Text;
        vDireccionCliente: Text;
        vDuiCliente: Text;
        vNitCliente: Text;
        vNrcCliente: Text;
        vGiroCliente: Text;
        vFecha: Text;
        vSumas: Decimal;
        vVentasNoSujetas: Decimal;
        vVentasExentas: Decimal;
        vVentasAfectas: Decimal;
        vSubTotal: Decimal;
        vIvaNormal: Decimal;
        vCesc: Decimal;
        vIvaRetenido: Decimal;
        vIvaPercibido: Decimal;
        vMonto: Decimal;
        vPOS: Text;
        vCajero: Text;
        vVendedor: Text;
        vFormaPago: Text;
        vTotalLetras: Text;
        xmlDetalles: Text;
        xml1: Text[1024];
        xml2: Text[1024];
        xml3: Text[1024];
        xml4: Text[1024];
        xmlDetallesBig: BigText;
        xmlBig: BigText;
        url: Text;
        soapActionUrl: Text;
        sb: DotNet StringBuilder;
        uriObj: DotNet Uri;
        lgRequest: DotNet HttpWebRequest;
        stream: DotNet StreamWriter;
        lgResponse: DotNet HttpWebResponse;
        str: DotNet Stream;
        reader: DotNet XmlTextReader;
        document: DotNet XmlDocument;
        ascii: DotNet Encoding;
        credentials: DotNet CredentialCache;
        xmlnodelist: DotNet XmlNodeList;
        xmlnode: DotNet XmlNode;
        xmlelement: DotNet XmlElement;
        nodos: Integer;
        vDetalleCodigo: Text;
        vDetalleProducto: Text;
        vDetalleCantidad: Integer;
        vDetallePrecio: Decimal;
        vDetalleDescuento: Decimal;
        vDetalleVentasNoSujetas: Decimal;
        vDetalleVentasExentas: Decimal;
        vDetalleVentasAfectas: Decimal;
        vDetalleVentasAfectasItem: Decimal;
        vDetalleCostoNeto: Decimal;
        vDetalleTotal: Decimal;
        vInfoAmountTotal: Decimal;
        vIP: Text[20];
        xmlFinal: File;
        xmlStream: OutStream;
        vReimpresionR: Integer;
        vResolucionR: Text[30];
        vFechaAutorizacionR: Text[30];
        vSerieR: Text[30];
        vDesdeR: Text[30];
        vHastaR: Text[30];
        vNCFR: Text[30];
        EsRemision: Boolean;
        xTitular: Text[70];
        xBenef: Text[70];
        xTrnHdrExt: Record "FSN Transaction Header Ext";
        vGrupoDescuentoCliente: Text;
        TotFac: Text;
        lStore: Record "LSC Store";
        PARAM: Record "FSN Parameter";
        vDecimalesTextoFactura: text;
        FSNUTILITY: Codeunit "FSN Utility";
        Value: array[10] of text[100];
        IsHandled: Boolean;
        PaymEntry: Record "LSC Trans. Payment Entry";
        TenderType: Record "LSC Tender Type";
        jContador: Integer;
        iContador: Integer;
        vAgregarSalesPersonNo: Integer;
        vMediosPago: array[30] of text[90];
        xmlt: Text;
        TransIncExpEntry: Record "LSC Trans. Inc./Exp. Entry";
        AcoutIncEcp: Record "LSC Income/Expense Account";
        IncExpAmount: Decimal;
    begin
        PARAM.RESET;
        PARAM.SetRange(PARAM.Grupo, 'GIGAUNO');
        PARAM.SetRange(PARAM.Codigo, Transaction."POS Terminal No.");
        if PARAM.FINDFIRST then begin
            if PARAM.Activo then begin
                vIP := PARAM.IP;
                vDetalleCodigo := ' ';
                vDetalleProducto := ' ';
                vDetalleCantidad := 0;
                vDetallePrecio := 0;
                vDetalleDescuento := 0;
                vDetalleVentasNoSujetas := 0;
                vDetalleVentasExentas := 0;
                vDetalleVentasAfectas := 0;
                vDetalleVentasAfectasItem := 0;
                vDetalleCostoNeto := 0;
                vDetalleTotal := 0;
                vInfoAmountTotal := 0;

                vCopia := 4;
                vResolucionCopia := ' ';
                vSerieCopia := ' ';
                vDesdeCopia := 0;
                vHastaCopia := 0;
                vNcfCopia := ' ';

                vGiroEmpresa := ' ';
                vSucursal := ' ';
                vDireccionSucursal := ' ';
                vNitEmpresa := ' ';
                vNrcEmpresa := ' ';

                vNombreCliente := ' ';
                vDireccionCliente := ' ';
                vDuiCliente := ' ';
                vNitCliente := ' ';
                //CSPNT280916
                vNrcCliente := ' ';
                vGiroCliente := ' ';

                vFecha := '';
                vSumas := 0;
                vVentasNoSujetas := 0;
                vVentasExentas := 0;
                vVentasAfectas := 0;
                vSubTotal := 0;
                vIvaNormal := 0;
                vCesc := 0;
                vIvaRetenido := 0;
                vIvaPercibido := 0;
                vMonto := 0;
                vPOS := ' ';
                vCajero := ' ';
                vVendedor := ' ';
                vFormaPago := ' ';
                vTotalLetras := ' ';
                xTitular := ' ';
                xBenef := ' ';
                IncExpAmount := 0;
                TotFac := '';
                vDecimalesTextoFactura := '';

                IF (Transaction."FSN Document Type" = Transaction."FSN Document Type"::Factura) AND NOT EsRemision THEN BEGIN

                    vIdDocumento := 1;
                    vCopia := 3;
                END
                ELSE
                    IF (Transaction."FSN Document Type" = Transaction."FSN Document Type"::"Credito Fiscal") AND NOT EsRemision THEN BEGIN
                        vIdDocumento := 2;
                        vCopia := 4;
                    END
                    ELSE
                        IF (Transaction."FSN Document Type" = Transaction."FSN Document Type"::"Nota Credito") AND NOT EsRemision THEN BEGIN
                            vIdDocumento := 3;
                            vCopia := 4;
                        END
                        ELSE
                            IF EsRemision THEN BEGIN
                                IF Transaction."FSN Document Type" = Transaction."FSN Document Type"::Factura THEN BEGIN
                                    vIdDocumento := 1;
                                    vCopia := 3;
                                END
                                ELSE BEGIN
                                    IF Transaction."Customer No." = 'C000002' THEN BEGIN
                                        vIdDocumento := 2;
                                        vCopia := 4;
                                    END
                                    ELSE BEGIN
                                        IF (Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie NCF Cons. Final") THEN BEGIN
                                            vIdDocumento := 1;
                                            vCopia := 3;
                                        END
                                        ELSE BEGIN
                                            vIdDocumento := 2;
                                            vCopia := 4;
                                        END;
                                    END;
                                END;
                            END;

                if Tray = 1 then
                    vReimpresionR := Tray;

                IF IsHandledE THEN BEGIN
                    IsHandled := IsHandledE;
                END ELSE
                    IsHandled := false;
                OnAfterAddItems(Transaction, IsHandled);

                SalesEntry.RESET;
                SalesEntry.SETRANGE("Store No.", Transaction."Store No.");
                SalesEntry.SETRANGE("POS Terminal No.", Transaction."POS Terminal No.");
                SalesEntry.SETRANGE("Transaction No.", Transaction."Transaction No.");
                IF SalesEntry.FIND('-') and IsHandled THEN
                    REPEAT
                        ParentItem.Get(SalesEntry."Item No.");
                        vDetalleProducto := COPYSTR(ParentItem.Description, 1, 40);
                        vDetalleCantidad := -SalesEntry.Quantity;
                        vDetalleDescuento := SalesEntry."Discount Amount";

                        if (Transaction."FSN Document Type" = Transaction."FSN Document Type"::"Credito Fiscal") then begin
                            vDetalleVentasAfectasItem := ROUND(SalesEntry."Price" / 1.13, 0.01);
                            vDetalleVentasAfectas := -ROUND(SalesEntry."Net Amount");
                            TotalVent += -ROUND(SalesEntry."Net Amount");
                            vInfoAmountTotal := vInfoAmountTotal + SalesEntry."Net Amount";
                        end else
                            if (Transaction."FSN Document Type" = Transaction."FSN Document Type"::"Nota Credito") then begin
                                vDetalleVentasAfectasItem := -ROUND(SalesEntry."Price" / 1.13, 0.01);
                                vDetalleVentasAfectas := ROUND(SalesEntry."Net Amount");
                                TotalVent += -ROUND(SalesEntry."Net Amount" / 1.13, 0.01);
                                vInfoAmountTotal := vInfoAmountTotal + SalesEntry."Net Amount";
                            end else begin
                                vDetalleVentasAfectasItem := ROUND(SalesEntry."Price");
                                vDetalleVentasAfectas := -ROUND(SalesEntry."Net Amount" + SalesEntry."VAT Amount", 0.01, '=');
                                TotalVent += -ROUND(SalesEntry."Net Amount" + SalesEntry."VAT Amount", 0.01, '=');
                                vInfoAmountTotal := 0;
                            end;

                        xmlDetalles := '<DetalleDocumento>' +
                                        '<Codigo>' + vDetalleCodigo + '</Codigo>' +
                                        '<Producto>' + DELCHR(DELCHR(DELCHR(vDetalleProducto, '=', '>'), '=', '<'), '=', '&') + '</Producto>' +
                                        '<Cantidad>' + DELCHR(FORMAT(vDetalleCantidad), '=', ',') + '</Cantidad>' +
                                        '<Precio>' + DELCHR(FORMAT(vDetalleVentasAfectasItem), '=', ',') + '</Precio>';

                        IF vDetalleDescuento <> 0 THEN
                            xmlDetalles := xmlDetalles + '<Descuento>' + DELCHR(FORMAT(vDetalleDescuento), '=', ',') + '</Descuento>';
                        IF vDetalleVentasNoSujetas <> 0 THEN
                            xmlDetalles := xmlDetalles + '<VentasNoSujetas>' + DELCHR(FORMAT(vDetalleVentasNoSujetas), '=', ',') + '</VentasNoSujetas>';
                        IF vDetalleVentasExentas <> 0 THEN
                            xmlDetalles := xmlDetalles + '<VentasExentas>' + DELCHR(FORMAT(vDetalleVentasExentas), '=', ',') + '</VentasExentas>';
                        IF vDetalleVentasAfectas <> 0 THEN
                            xmlDetalles := xmlDetalles + '<VentasAfectas>' + DELCHR(FORMAT(vDetalleVentasAfectas), '=', ',') + '</VentasAfectas>';
                        xmlDetalles := xmlDetalles + '<CostoNeto>' + DELCHR(FORMAT(vDetalleCostoNeto), '=', ',') + '</CostoNeto>' +
                                        '<Total>' + DELCHR(FORMAT(vDetalleVentasAfectas), '=', ',') + '</Total>' +
                                      '</DetalleDocumento>';
                        xmlDetallesBig.ADDTEXT(xmlDetalles);

                        vDetalleCodigo := ' ';
                        vDetalleProducto := ' ';
                        vDetalleCantidad := 0;
                        vDetallePrecio := 0;
                        vDetalleDescuento := 0;
                        vDetalleVentasNoSujetas := 0;
                        vDetalleVentasExentas := 0;
                        vDetalleVentasAfectas := 0;
                        vDetalleCostoNeto := 0;
                        vDetalleTotal := 0;
                        //TotalVent += -ROUND(SalesEntry."Net Amount" / 1.13, 0.01);
                        vVendedor := SalesEntry."Sales Staff";
                    UNTIL SalesEntry.NEXT = 0;
                IsHandled := false;
                xmlDetalles := '';
                OnBeforeAddItems(Transaction, xmlDetalles, IsHandled);

                if IsHandled then
                    xmlDetallesBig.ADDTEXT(xmlDetalles);

                TotalRetencion := ABS(Transaction."FSN Retention Amount");
                vPOS := Transaction."POS Terminal No.";
                vCajero := Transaction."Staff ID";
                vDecimalesTextoFactura := FSNUTILITY.Num2Text(ABS(Transaction.Payment));
                TotalLetras := TotFac;
                Value[1] := TotalLetras;
                vTotalLetras := vDecimalesTextoFactura + ' DOLARES';

                xTrnHdrExt.Reset;
                xTrnHdrExt.SetRange(xTrnHdrExt."Store No.", Transaction."Store No.");
                xTrnHdrExt.SetRange(xTrnHdrExt."POS Terminal No.", Transaction."POS Terminal No.");
                xTrnHdrExt.SetRange(xTrnHdrExt."Receipt No.", Transaction."Receipt No.");
                IF xTrnHdrExt.FINDFIRST THEN BEGIN
                    vResolucionR := xTrnHdrExt.Resolucion;
                    vFechaAutorizacionR := xTrnHdrExt."Fecha Autorizacion";
                    vSerieR := xTrnHdrExt.Serie;
                    vDesdeR := FORMAT(xTrnHdrExt.Desde);
                    vHastaR := FORMAT(xTrnHdrExt.Hasta);
                    vNCFR := Transaction."FSN NCF";
                    IF (Transaction."FSN Document Type" = Transaction."FSN Document Type"::"Nota Credito") AND NOT EsRemision THEN BEGIN
                        xTrnHdrExt."Nombre Cliente" := Transaction."FSN Customer Name";
                        xTrnHdrExt.DUI := Transaction."FSN DUI";
                        xTrnHdrExt.NIT := Transaction."FSN NIT";
                        xTrnHdrExt.MODIFY;
                    END;
                END;

                TransIncExpEntry.Reset();
                TransIncExpEntry.SetRange(TransIncExpEntry."Store No.", Transaction."Store No.");
                TransIncExpEntry.SetRange(TransIncExpEntry."POS Terminal No.", Transaction."POS Terminal No.");
                TransIncExpEntry.SETRANGE(TransIncExpEntry."Transaction No.", Transaction."Transaction No.");
                IF TransIncExpEntry.Find('-') THEN BEGIN
                    repeat
                        if AcoutIncEcp.Get(TransIncExpEntry."Store No.", TransIncExpEntry."No.") then begin
                            IF (Transaction."FSN Document Type" = Transaction."FSN Document Type"::"Credito Fiscal") or (Transaction."FSN Document Type" = Transaction."FSN Document Type"::"Nota Credito") THEN
                                IncExpAmount := -Round(TransIncExpEntry."Net Amount")
                            else
                                IncExpAmount := -Round(TransIncExpEntry.Amount);

                            xmlDetalles := '<DetalleDocumento><Producto>' + 'INC/EXP: ' + AcoutIncEcp.Description + '</Producto>';
                            xmlDetalles := xmlDetalles + '<VentasAfectas>' + DELCHR(FORMAT(IncExpAmount), '=', ',') + '</VentasAfectas></DetalleDocumento>';
                            xmlDetallesBig.ADDTEXT(xmlDetalles);
                        end;
                    UNTIL TransIncExpEntry.Next() = 0;
                END;

                rCompanyInfo.GET();
                //DATOS COMPANIA
                vGiroEmpresa := rCompanyInfo."Giro No.";
                lStore.GET(Transaction."Store No.");
                vSucursal := lStore.Name;
                vDireccionSucursal := lStore.Address;
                vNitEmpresa := rCompanyInfo."Federal ID No.";
                vNrcEmpresa := rCompanyInfo."FSN NRC";

                //DATOS CLIENTE
                IF rCustomer.GET(Transaction."Customer No.") THEN BEGIN
                    vNombreCliente := COPYSTR(rCustomer.Name, 1, 67);
                    vDireccionCliente := rCustomer.Address;
                    vDuiCliente := rCustomer."FSN DUI";
                    vNitCliente := rCustomer."VAT Registration No.";
                    IF rCustomer."FSN NRC Description" <> '' THEN
                        vNrcCliente := rCustomer."FSN NRC";
                    //vGiroCliente := rCustomer.Name;
                    vGiroCliente := rCustomer."FSN NRC Description";
                    vGrupoDescuentoCliente := rCustomer."Customer Disc. Group";

                    IF rCustomer."FSN Request Beneficiary" THEN BEGIN
                        CLEAR(rTransInfo);
                        rTransInfo.SETFILTER("Transaction No.", '%1', Transaction."Transaction No.");
                        rTransInfo.SETFILTER("Store No.", '%1', Transaction."Store No.");
                        rTransInfo.SETFILTER("POS Terminal No.", '%1', Transaction."POS Terminal No.");
                        //rTransInfo.SETFILTER(NotaRemision, '%1', 'ENERGETICAS');//REVISAR
                        rTransInfo.SETFILTER(Information, 'TITULAR*');
                        IF rTransInfo.FIND('-') THEN BEGIN
                            xTitular := COPYSTR(rTransInfo.Information, 11, 70);
                            vNombreCliente := xTitular;
                            //xTitular := '';
                        END;
                        /// Encontrando al beneficiario
                        CLEAR(rTransInfo);
                        rTransInfo.SETFILTER("Transaction No.", '%1', Transaction."Transaction No.");
                        rTransInfo.SETFILTER("Store No.", '%1', Transaction."Store No.");
                        rTransInfo.SETFILTER("POS Terminal No.", '%1', Transaction."POS Terminal No.");
                        //rTransInfo.SETFILTER(NotaRemision, '%1', 'ENERGETICAS');//REVISAR
                        rTransInfo.SETFILTER(Information, 'BENEFICIARIO*');
                        IF rTransInfo.FIND('-') THEN
                            xBenef := COPYSTR(rTransInfo.Information, 16, 70);
                    END;
                END;

                vFecha := FORMAT(Transaction.Date) + ' ' + FORMAT(Transaction."Time when Trans. Closed");

                IF NOT Transaction."Sale Is Return Sale" THEN BEGIN
                    IF rCustomer.GET(Transaction."Customer No.") THEN
                        IF rCustomer."Gen. Bus. Posting Group" = 'EXTERIOR' THEN BEGIN
                            vVentasExentas := ABS(TotalVent);
                        END else
                            vVentasExentas := 0;
                    vVentasAfectas := ABS(TotalVent);
                    vSumas := ABS(TotalVent);
                    //vSumas := ROUND(TotalVent * 1.13, 0.01);
                    vIvaNormal := ROUND(-vInfoAmountTotal * 0.13, 0.01);
                    vIvaRetenido := TotalRetencion;
                END ELSE
                    IF (Transaction."Sale Is Return Sale") AND (Transaction."FSN Document Type" = Transaction."FSN Document Type"::"Nota Credito") THEN BEGIN
                        IF rCustomer.GET(Transaction."Customer No.") THEN
                            IF rCustomer."Gen. Bus. Posting Group" = 'EXTERIOR' THEN BEGIN
                                vVentasExentas := ABS(TotalVent);
                            END else
                                vVentasExentas := 0;
                        vVentasAfectas := ABS(TotalVent);
                        vSumas := ABS(TotalVent);
                        //vSumas := ROUND(TotalVent * 1.13, 0.01);
                        vIvaNormal := ROUND(-vInfoAmountTotal * 0.13, 0.01);
                        vIvaRetenido := TotalRetencion;
                    END
                    ELSE BEGIN
                        vVentasAfectas := ABS(TotalVentG);
                    END;

                IF NOT Transaction."Sale Is Return Sale" THEN BEGIN
                    IF Transaction."FSN Document Type" = Transaction."FSN Document Type"::"Nota Credito" THEN BEGIN
                        vMonto := ABS(TotalVent + vIvaNormal + TotalNoSuj + TotalPercepcion - TotalRetencion + vCesc);
                    END
                    ELSE BEGIN
                        vMonto := ABS(TotalVent + vIvaNormal + TotalNoSuj + TotalPercepcion - TotalRetencion + vCesc);
                    END;
                END
                ELSE
                    IF Transaction."Sale Is Return Sale" AND (Transaction."FSN Document Type" = Transaction."FSN Document Type"::"Nota Credito") THEN BEGIN
                        vMonto := ABS(TotalVent + vIvaNormal + TotalNoSuj + TotalPercepcion - TotalRetencion + vCesc);
                    END
                    ELSE BEGIN
                        vMonto := ABS(TotalVent + vIvaNormal + TotalNoSuj + TotalPercepcion - TotalRetencion + vCesc);
                    END;

                PaymEntry.reset;
                PaymEntry.SetRange("Store No.", Transaction."Store No.");
                PaymEntry.SetRange("POS Terminal No.", Transaction."POS Terminal No.");
                PaymEntry.SETRANGE("Receipt No.", Transaction."Receipt No.");
                IF PaymEntry.FIND('-') THEN
                    jContador := 1;
                REPEAT
                    vAgregarSalesPersonNo := 0;
                    FOR iContador := 1 TO 30 DO BEGIN
                        TenderType.RESET;
                        TenderType.SETRANGE(Code, PaymEntry."Tender Type");
                        IF TenderType.FIND('-') THEN;
                        IF TenderType.Description = vMediosPago[iContador] THEN
                            vAgregarSalesPersonNo += 1;
                    END;
                    IF vAgregarSalesPersonNo = 0 THEN BEGIN
                        vMediosPago[jContador] := TenderType.Description;
                        jContador += 1;
                    END;
                UNTIL PaymEntry.NEXT = 0;
                Value[1] := 'Medios pago: ';
                FOR iContador := 1 TO jContador DO BEGIN
                    vFormaPago := vFormaPago + vMediosPago[iContador] + ' ';
                END;

                url := 'http://' + vIP + ':9393/WSImpresiones.asmx?op=ImprimirDocumento';
                //url := 'http://10.0.20.7:2103/WSImpresiones.asmx?op=ImprimirDocumento';
                soapActionUrl := '"http://tempuri.org/ImprimirDocumento"';

                xml1 := '<?xml version="1.0" encoding="utf-8"?>' +
                  '<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soap:Body>' +
                      '<ImprimirDocumento xmlns="http://tempuri.org/">' +
                        '<reimpresion>' + FORMAT(vReimpresionR) + '</reimpresion>' +
                        '<copia>' + FORMAT(vCopia) + '</copia>' +
                        '<idDocumento>' + FORMAT(vIdDocumento) + '</idDocumento>' +
                        '<datosGenerales>' +
                          '<resolucionCopia>' + vResolucionR + '</resolucionCopia>' +
                          //CSPNT121216
                          '<fechaAutorizacion>' + vFechaAutorizacionR + '</fechaAutorizacion>' +
                          '<serieCopia>' + vSerieR + '</serieCopia>' +
                          '<desdeCopia>' + FORMAT(vDesdeR) + '</desdeCopia>' +
                          '<hastaCopia>' + FORMAT(vHastaR) + '</hastaCopia>' +
                          '<ncfCopia>' + vNCFR + '</ncfCopia>' +
                          '<giroEmpresa>' + vGiroEmpresa + '</giroEmpresa>' +
                          '<sucursalEmpresa>' + vSucursal + '</sucursalEmpresa>' +
                          '<direccionSucursal>' + vDireccionSucursal + '</direccionSucursal>' +
                          '<nitEmpresa>' + vNitEmpresa + '</nitEmpresa>' +
                          '<nrcEmpresa>' + vNrcEmpresa + '</nrcEmpresa>';

                xml2 := '<nombreCliente>' + DELCHR(DELCHR(DELCHR(vNombreCliente, '=', '>'), '=', '<'), '=', '&') + '</nombreCliente>' +
                          '<direccionCliente>' + DELCHR(DELCHR(DELCHR(vDireccionCliente, '=', '>'), '=', '<'), '=', '&') + '</direccionCliente>' +
                          '<titularCliente>' + xTitular + '</titularCliente>' +
                          '<beneficiarioCliente>' + xBenef + '</beneficiarioCliente>' +
                          '<duiCliente>' + vDuiCliente + '</duiCliente>' +
                          '<nitCliente>' + vNitCliente + '</nitCliente>' +
                          '<nrcCliente>' + vNrcCliente + '</nrcCliente>' +
                          '<giroCliente>' + DELCHR(DELCHR(DELCHR(vGiroCliente, '=', '>'), '=', '<'), '=', '&') + '</giroCliente>';

                xml3 := '<fecha>' + CopyStr(vFecha, 1, 17) + '</fecha>' +
                          '<sumas>' + DELCHR(FORMAT(vSumas), '=', ',') + '</sumas>' +
                          '<ventasNoSujetas>' + DELCHR(FORMAT(vVentasNoSujetas), '=', ',') + '</ventasNoSujetas>' +
                          '<ventasExentas>' + DELCHR(FORMAT(vVentasExentas), '=', ',') + '</ventasExentas>' +
                          '<ventasAfectas>' + DELCHR(FORMAT(vVentasAfectas), '=', ',') + '</ventasAfectas>' +
                          '<subTotal>' + DELCHR(FORMAT(vSumas), '=', ',') + '</subTotal>' +
                          '<ivaNormal>' + DELCHR(FORMAT(vIvaNormal), '=', ',') + '</ivaNormal>' +
                          '<cesc>' + DELCHR(FORMAT(vCesc), '=', ',') + '</cesc>' +
                          '<ivaRetenido>' + DELCHR(FORMAT(vIvaRetenido), '=', ',') + '</ivaRetenido>' +
                          '<ivaPercibido>' + DELCHR(FORMAT(vIvaPercibido), '=', ',') + '</ivaPercibido>' +
                          '<monto>' + DELCHR(FORMAT(vMonto), '=', ',') + '</monto>' +
                          '<pos>' + vPOS + '</pos>' +
                          '<cajero>' + vCajero + '</cajero>' +
                          '<vendedor>' + vVendedor + '</vendedor>' +
                          '<formaPago>' + vFormaPago + '</formaPago>' +
                          '<totalLetras>' + vTotalLetras + '</totalLetras>' +
                        '</datosGenerales>' +
                        '<listaProductos>';

                //        xmlDetalles

                xml4 := '</listaProductos>' +
                      '</ImprimirDocumento>' +
                    '</soap:Body>' +
                  '</soap:Envelope>';
                xmlBig.ADDTEXT(xml1 + xml2 + xml3);
                xmlBig.ADDTEXT(xmlDetallesBig);
                xmlBig.ADDTEXT(xml4);
                sb := sb.StringBuilder();

                sb.Append(xmlBig);

                IF xmlFinal.CREATE('C:\Temp\' + Transaction."Receipt No." + ' P ' + vFormaPago + '.xml') THEN BEGIN
                    xmlFinal.CREATEOUTSTREAM(xmlStream);
                    xmlStream.WRITE(sb.ToString);
                    xmlFinal.CLOSE;
                END;
                uriObj := uriObj.Uri(url);
                lgRequest := lgRequest.CreateDefault(uriObj);
                lgRequest.Method := 'POST';
                lgRequest.Host := vIP;
                lgRequest.ContentType := 'text/xml; charset=utf-8';
                lgRequest.Headers.Add('SOAPAction', soapActionUrl);
                lgRequest.Timeout := 90000;
                stream := stream.StreamWriter(lgRequest.GetRequestStream(), ascii.UTF8);
                stream.Write(sb.ToString());
                stream.Close();
                //IF lgRequest.UseDefaultCredentials(TRUE) THEN
                lgResponse := lgRequest.GetResponse();
                str := lgResponse.GetResponseStream();
                reader := reader.XmlTextReader(str);
                document := document.XmlDocument();
                document.Load(reader);
                xmlnodelist := document.SelectNodes('//*');
                document.Save('C:\temp\' + Transaction."Receipt No." + ' R ' + vFormaPago + '.xml');
                //nodos := xmlnodelist.Count;
                nodos := 11;
            end;
        end;
    end;

    //////////////////////////////////////////////REMISSION//////////////////////////////////////////////
    procedure WSGenerarFacturaRemision(var Transaction: Record "LSC Transaction Header"; Tray: Integer)
    var
        xmlDetalles: Text;
        xml1: Text[1024];
        xml2: Text[1024];
        xml3: Text[1024];
        xml4: Text[1024];
        xmlDetallesBig: BigText;
        xmlBig: BigText;
        url: Text;
        soapActionUrl: Text;
        sb: DotNet StringBuilder;
        uriObj: DotNet Uri;
        lgRequest: DotNet HttpWebRequest;
        stream: DotNet StreamWriter;
        lgResponse: DotNet HttpWebResponse;
        str: DotNet Stream;
        reader: DotNet XmlTextReader;
        document: DotNet DocumentXml;
        ascii: DotNet Encoding;
        xmlnodelist: DotNet NodeListXml;
        xmlnode: DotNet NodeXml;
        xmlelement: DotNet XmlElement;
        xTitular: Text[70];
        xBenef: Text[70];
        //RemissionMgt: Codeunit "50050";
        lPOSTerminal: Record "LSC POS Terminal";
        lCompInfo: Record "Company Information";
        lSalesInfoRemission: Record "LSC Trans. Sales Entry";
        //lGigaUno: Record "50047";
        RemissionHeaderTmp: Record "FSN Remission Header" temporary;
        lRemissionHeader: Record "FSN Remission Header";
        lCompany: Record "FSN Company Insurer";
        lSalesPersonTmp: Record "LSC Staff" temporary;
        lPayments: Record "LSC POS Trans. Line" temporary;
        lTransactionHeaderExt: Record "FSN Transaction Header Ext";
        lCustomer: Record Customer;
        lStore: Record "LSC Store";
        FSNUTILITY: Codeunit "FSN Utility";
        _TextRemission: Text[50];
        _IP: Code[20];
        _POS: Code[10];
        _StaffID: Code[20];
        _RePrint: Integer;
        _CopyNo: Integer;
        _IDDocument: Integer;
        _Date: Text[50];
        _Sums: Decimal;
        _SaleNoSujeta: Decimal;
        _SaleExent: Decimal;
        _SaleAfect: Decimal;
        _SubTotal: Decimal;
        _VAT: Decimal;
        _Cesc: Decimal;
        _VATRet: Decimal;
        _VATPerc: Decimal;
        _AmountXML: Decimal;
        _SalesStaff: Text;
        _PaymentText: Text;
        _TotalTexts: Text;
        _TotalE: Decimal;
        _TotalG: Decimal;
        _ValueZero: Decimal;
        _Sign: Decimal;
        xmlFinal: File;
        xmlStream: OutStream;
        _PrintDateRemission: Boolean;
        lRemissionLine: Record "FSN Remission Line";
        AmountsArr: array[3] of Decimal;
        lText000: Label 'Cant operation permise (Re Print)';
        NoTicket: Text[75];
        CompanyInsurer: Record "FSN Company Insurer";
        TransHeader: Record "LSC Transaction Header";
        vDetalleCodigo: Text;
        vDetalleProducto: Text;
        vDetalleCantidad: Integer;
        vDetallePrecio: Decimal;
        vDetalleDescuento: Decimal;
        vDetalleVentasNoSujetas: Decimal;
        vDetalleVentasExentas: Decimal;
        vDetalleVentasAfectas: Decimal;
        vDetalleCostoNeto: Decimal;
        vDetalleTotal: Decimal;
        item: Record Item;
        ItemName: Text;
        ItemTranslate: Record "Item Translation";
        rVATPostingSetup: Record "VAT Posting Setup";
        Impuesto: Decimal;
        PARAM: Record "FSN Parameter";
        PaymEntry: Record "LSC Trans. Payment Entry";
        TenderType: Record "LSC Tender Type";
        SalesEntry: Record "LSC Trans. Sales Entry";
        RetailSetup: Record "LSC Retail Setup";
        rBarras: Record "LSC Barcodes";
    begin
        _RePrint := 0;
        _Sign := 1;

        IF Tray = 1 then
            _RePrint := Tray;

        IF NOT Transaction."Sale Is Return Sale" THEN
            _Sign := -1;

        CLEAR(lCustomer);
        IF lCustomer.GET(Transaction."Customer No.") THEN;

        lStore.GET(Transaction."Store No.");
        lCompInfo.GET;
        lPOSTerminal.GET(Transaction."POS Terminal No.");
        PARAM.RESET;
        PARAM.SetRange(PARAM.Grupo, 'GIGAUNO');
        PARAM.SetRange(PARAM.Codigo, Transaction."POS Terminal No.");
        PARAM.FINDFIRST;
        _IP := PARAM.IP;
        _POS := Transaction."POS Terminal No.";
        _StaffID := Transaction."Staff ID";
        _CopyNo := 4;
        _ValueZero := 0;
        _Sums := 0;

        xTitular := '';
        xBenef := '';

        _Date := FORMAT(Transaction.Date) + ' ' + FORMAT(Transaction."Time when Trans. Closed");

        //Remission Details
        RemissionHeaderTmp.RESET;
        RemissionHeaderTmp.DELETEALL;
        lSalesPersonTmp.RESET;
        lSalesPersonTmp.DELETEALL;
        lPayments.RESET;
        lPayments.DELETEALL;

        lSalesInfoRemission.RESET;
        lSalesInfoRemission.SETRANGE(lSalesInfoRemission."Store No.", Transaction."Store No.");
        lSalesInfoRemission.SETRANGE(lSalesInfoRemission."POS Terminal No.", Transaction."POS Terminal No.");
        lSalesInfoRemission.SETRANGE(lSalesInfoRemission."Transaction No.", Transaction."Transaction No.");
        IF lSalesInfoRemission.FINDFIRST THEN
            REPEAT
                IF NOT RemissionHeaderTmp.GET(RemissionHeaderTmp."Document Type"::Remission, lSalesInfoRemission."FSN Remission No.") THEN BEGIN
                    IF lRemissionHeader.GET(lRemissionHeader."Document Type"::Remission, lSalesInfoRemission."FSN Remission No.") THEN BEGIN
                        lRemissionHeader.GET(lRemissionHeader."Document Type"::Remission, lSalesInfoRemission."FSN Remission No.");
                        _TextRemission := '';
                        _PrintDateRemission := FALSE;
                        IF lCompany.GET(lRemissionHeader."Company No.") THEN BEGIN
                            _PrintDateRemission := lCompany."Print Date In Invoice";
                            _TextRemission := lCompany."Coinsurance Text Add";
                        END;
                        RemissionHeaderTmp.INIT();
                        RemissionHeaderTmp."Document Type" := RemissionHeaderTmp."Document Type"::Remission;
                        RemissionHeaderTmp."No." := lSalesInfoRemission."FSN Remission No.";
                        IF _PrintDateRemission THEN
                            RemissionHeaderTmp."External Document No." := COPYSTR(_TextRemission + lRemissionHeader."External Document No." + ' ' + FORMAT(lRemissionHeader."Document Date"), 1, 40)
                        ELSE
                            RemissionHeaderTmp."External Document No." := COPYSTR(_TextRemission + lRemissionHeader."External Document No.", 1, 40);

                        RemissionHeaderTmp.Amount := 0;
                        RemissionHeaderTmp."VAT Amount" := 0;
                        RemissionHeaderTmp."Amount Including VAT" := 0;
                        RemissionHeaderTmp."Disc. Amount" := 0;
                        RemissionHeaderTmp.INSERT();

                        AmountsArr[1] := 0;
                        AmountsArr[2] := 0;
                        AmountsArr[3] := 0;
                        lRemissionLine.RESET;
                        lRemissionLine.SETCURRENTKEY("Document Type", "Document No.", Type);
                        lRemissionLine.SETRANGE(lRemissionLine."Document Type", lRemissionHeader."Document Type");
                        lRemissionLine.SETRANGE(lRemissionLine."Document No.", lRemissionHeader."No.");
                        lRemissionLine.SETFILTER(lRemissionLine.Type, '<>%1', lRemissionLine.Type::Comission);
                        IF lRemissionLine.FIND('-') THEN
                            REPEAT
                                IF lRemissionLine.Type = lRemissionLine.Type::Item THEN BEGIN
                                    AmountsArr[1] += lRemissionLine.Amount;
                                    AmountsArr[2] += lRemissionLine."VAT Amount";
                                    AmountsArr[3] += lRemissionLine."Amount Including VAT";
                                END ELSE BEGIN
                                    AmountsArr[1] -= lRemissionLine.Amount;
                                    AmountsArr[2] -= lRemissionLine."VAT Amount";
                                    AmountsArr[3] -= lRemissionLine."Amount Including VAT";
                                END;
                            UNTIL lRemissionLine.NEXT = 0;
                        RemissionHeaderTmp.Amount := AmountsArr[1];
                        RemissionHeaderTmp."VAT Amount" := AmountsArr[2];
                        RemissionHeaderTmp."Amount Including VAT" := AmountsArr[3];
                        RemissionHeaderTmp.MODIFY;
                    END ELSE BEGIN
                        RemissionHeaderTmp.INIT();
                        RemissionHeaderTmp."Document Type" := RemissionHeaderTmp."Document Type"::Remission;
                        RemissionHeaderTmp."No." := lSalesInfoRemission."FSN Remission No.";
                        RemissionHeaderTmp.Amount := 0;//-lSalesInfoRemission."Net Amount";
                        RemissionHeaderTmp."VAT Amount" := 0;//-lSalesInfoRemission."VAT Amount";
                        RemissionHeaderTmp."Disc. Amount" := 0;//-lSalesInfoRemission."Discount Amount";
                        RemissionHeaderTmp."Amount Including VAT" := 0;//-(lSalesInfoRemission."Net Amount" + lSalesInfoRemission."VAT Amount");
                        RemissionHeaderTmp.INSERT();
                        IF RemissionHeaderTmp.GET(RemissionHeaderTmp."Document Type"::Remission, lSalesInfoRemission."FSN Remission No.") THEN BEGIN
                            RemissionHeaderTmp.Amount -= lSalesInfoRemission."Net Amount";
                            RemissionHeaderTmp."VAT Amount" -= lSalesInfoRemission."VAT Amount";
                            RemissionHeaderTmp."Disc. Amount" -= lSalesInfoRemission."Discount Amount";
                            RemissionHeaderTmp."Amount Including VAT" -= lSalesInfoRemission."Net Amount" + lSalesInfoRemission."VAT Amount";
                            RemissionHeaderTmp.MODIFY;
                        END;
                    END;
                END ELSE BEGIN
                    IF NOT lRemissionHeader.GET(lRemissionHeader."Document Type"::Remission, lSalesInfoRemission."FSN Remission No.") THEN BEGIN
                        RemissionHeaderTmp.Amount -= lSalesInfoRemission."Net Amount";
                        RemissionHeaderTmp."VAT Amount" -= lSalesInfoRemission."VAT Amount";
                        RemissionHeaderTmp."Disc. Amount" -= lSalesInfoRemission."Discount Amount";
                        RemissionHeaderTmp."Amount Including VAT" -= lSalesInfoRemission."Net Amount" + lSalesInfoRemission."VAT Amount";
                        RemissionHeaderTmp.MODIFY;
                    END;
                END;

                IF NOT lSalesPersonTmp.GET(lSalesInfoRemission."Sales Staff") THEN BEGIN
                    lSalesPersonTmp.INIT();
                    lSalesPersonTmp.ID := lSalesInfoRemission."Sales Staff";
                    lSalesPersonTmp.INSERT;
                END;
            UNTIL lSalesInfoRemission.NEXT = 0;

        RemissionHeaderTmp.RESET;
        IF RemissionHeaderTmp.FIND('-') THEN
            REPEAT

                IF (Transaction."FSN No. Serie NCF" = lPOSTerminal."FSN No. Serie NCF Cons. Final") THEN BEGIN
                    IF RemissionHeaderTmp."VAT Amount" = 0 THEN
                        _TotalG += RemissionHeaderTmp.Amount
                    ELSE
                        _TotalG += RemissionHeaderTmp.Amount + RemissionHeaderTmp."VAT Amount"
                END ELSE BEGIN
                    _VAT += RemissionHeaderTmp."VAT Amount";
                    IF RemissionHeaderTmp."VAT Amount" = 0 THEN
                        _TotalE += RemissionHeaderTmp.Amount
                    ELSE
                        _TotalG += RemissionHeaderTmp.Amount;
                END;

            UNTIL RemissionHeaderTmp.NEXT = 0;

        _TotalE := _TotalE;
        _TotalG := _TotalG;
        _VAT := _VAT;

        _Sums := _TotalE + _TotalG;
        _SaleExent := _TotalE;
        _SaleAfect := _TotalG;
        _SalesStaff := '';
        _PaymentText := '';
        _SaleNoSujeta := 0;
        _ValueZero := 0;

        lSalesPersonTmp.RESET;
        IF lSalesPersonTmp.FIND('-') THEN
            REPEAT
                _SalesStaff += lSalesPersonTmp.ID + ' ';
            UNTIL lSalesPersonTmp.NEXT = 0;

        PaymEntry.RESET;
        PaymEntry.SETRANGE(PaymEntry."Store No.", Transaction."Store No.");
        PaymEntry.SETRANGE(PaymEntry."POS Terminal No.", Transaction."POS Terminal No.");
        PaymEntry.SETRANGE(PaymEntry."Transaction No.", Transaction."Transaction No.");
        IF PaymEntry.FINDFIRST THEN
            REPEAT
                IF NOT lPayments.GET(PaymEntry."Tender Type", 0) THEN BEGIN
                    lPayments.INIT();
                    lPayments."Receipt No." := PaymEntry."Tender Type";
                    IF TenderType.GET(PaymEntry."Store No.", PaymEntry."Tender Type") THEN
                        lPayments.Description := TenderType.Description;
                    lPayments.INSERT();
                END;
            UNTIL PaymEntry.NEXT = 0;

        lPayments.RESET;
        IF lPayments.FIND('-') THEN
            REPEAT
                _PaymentText := _PaymentText + lPayments.Description + ' ';
            UNTIL lPayments.NEXT = 0;

        RemissionHeaderTmp.RESET;
        RemissionHeaderTmp.SETCURRENTKEY("External Document No.");

        //OLOPEZ290721 AGREGANDO LINEAS DE ITEMS EN COMPROBANTE DE CREDITO FISCAL PARA MEDIPROCESOS
        CLEAR(NoTicket);
        TransHeader.RESET;
        TransHeader.SETRANGE(TransHeader."Receipt No.", lRemissionLine."Receipt No. Coinsurance");
        IF TransHeader.FINDFIRST THEN
            NoTicket := TransHeader."FSN NCF";

        vDetalleCodigo := ' ';
        vDetalleProducto := ' ';
        vDetalleCantidad := 0;
        vDetallePrecio := 0;
        vDetalleDescuento := 0;
        vDetalleVentasNoSujetas := 0;
        vDetalleVentasExentas := 0;
        vDetalleVentasAfectas := 0;
        vDetalleCostoNeto := 0;
        vDetalleTotal := 0;

        CLEAR(CompanyInsurer);
        CompanyInsurer.SETRANGE(CompanyInsurer."No.", lRemissionHeader."Company No.");
        CompanyInsurer.SETRANGE(CompanyInsurer."Customer No.", lRemissionHeader."Customer No.");

        IF (CompanyInsurer.FINDFIRST) THEN
            IF ((CompanyInsurer."Usar Remision" = FALSE) AND (RemissionHeaderTmp.COUNT = 1)) THEN BEGIN  //VALIDANDO QUE USE REMISION Y ENCABEZADO SEA IGUAL A UNO
                CLEAR(SalesEntry);
                SalesEntry.SETRANGE("Store No.", Transaction."Store No.");
                SalesEntry.SETRANGE("POS Terminal No.", Transaction."POS Terminal No.");
                SalesEntry.SETRANGE("Transaction No.", Transaction."Transaction No.");
                IF SalesEntry.FIND('-') THEN
                    REPEAT

                        IF (Transaction."Sale Is Return Sale") AND (Transaction."FSN Document Type" = Transaction."FSN Document Type"::"Nota Credito") THEN
                            vDetalleCantidad := SalesEntry.Quantity
                        ELSE
                            vDetalleCantidad := -SalesEntry.Quantity;

                        RetailSetup.GET();
                        IF item.GET(SalesEntry."Item No.") THEN BEGIN
                            IF (SalesEntry."Barcode No." <> '') THEN BEGIN
                                IF rBarras.GET(SalesEntry."Barcode No.") THEN
                                    ItemName := COPYSTR(rBarras.Description, 1, 50)
                                ELSE
                                    ItemName := COPYSTR(item.Description, 1, 50);
                            END
                            ELSE BEGIN
                                ItemName := COPYSTR(item.Description, 1, 50);
                            END;
                        END
                        ELSE
                            ItemName := SalesEntry."Item No.";

                        IF lCustomer."Language Code" <> '' THEN
                            IF ItemTranslate.GET(SalesEntry."Item No.", SalesEntry."Variant Code", lCustomer."Language Code") THEN
                                IF ItemTranslate.Description <> '' THEN
                                    ItemName := ItemTranslate.Description;

                        rVATPostingSetup.RESET;
                        rVATPostingSetup.SETRANGE(rVATPostingSetup."VAT Bus. Posting Group", SalesEntry."VAT Bus. Posting Group");
                        rVATPostingSetup.SETRANGE(rVATPostingSetup."VAT Prod. Posting Group", SalesEntry."VAT Code");
                        IF rVATPostingSetup.FINDFIRST THEN
                            Impuesto := rVATPostingSetup."VAT %";

                        vDetalleProducto := DELCHR(ItemName, '=', '&');



                        IF Transaction."FSN Document Type" = Transaction."FSN Document Type"::"Credito Fiscal" THEN BEGIN
                            vDetallePrecio := ROUND((SalesEntry.Price / (1 + (Impuesto / 100))), 0.0001);
                            vDetalleVentasAfectas := -SalesEntry."Net Amount";
                        END
                        ELSE
                            IF Transaction."Sale Is Return Sale" AND (Transaction."FSN Document Type" = Transaction."FSN Document Type"::"Nota Credito") THEN BEGIN
                                vDetallePrecio := ROUND((SalesEntry.Price / (1 + (Impuesto / 100))), 0.0001);
                                vDetalleVentasAfectas := SalesEntry."Net Amount";
                            END
                            ELSE
                                IF Transaction."FSN Document Type" = Transaction."FSN Document Type"::Factura THEN BEGIN
                                    vDetallePrecio := ROUND(SalesEntry."Net Amount" / SalesEntry.Quantity, 0.01);
                                    vDetalleVentasAfectas := -SalesEntry."Net Amount";
                                END;

                        IF SalesEntry."Discount Amount" <> 0 THEN BEGIN
                            IF Transaction."Sale Is Return Sale" THEN BEGIN
                                IF Transaction."FSN Document Type" = Transaction."FSN Document Type"::"Nota Credito" THEN BEGIN
                                    vDetalleDescuento := (ROUND((SalesEntry."Discount Amount" / (1 + (Impuesto / 100))), 0.01));
                                END ELSE BEGIN
                                    vDetalleDescuento := SalesEntry."Discount Amount";
                                END;
                                vDetalleDescuento := -vDetalleDescuento;
                            END ELSE BEGIN
                                IF Transaction."FSN Document Type" = Transaction."FSN Document Type"::Factura THEN BEGIN
                                    vDetalleDescuento := (ROUND((SalesEntry."Discount Amount"), 0.01));
                                END ELSE BEGIN
                                    vDetalleDescuento := (ROUND((SalesEntry."Discount Amount" / (1 + (Impuesto / 100))), 0.01));
                                END;
                            END;
                        END;

                        xmlDetalles := '<DetalleDocumento>' +
                                         '<Codigo>' + vDetalleCodigo + '</Codigo>' +
                                         '<Producto>' + DELCHR(DELCHR(DELCHR(vDetalleProducto, '=', '>'), '=', '<'), '=', '&') + '</Producto>' +
                                         '<Cantidad>' + DELCHR(FORMAT(vDetalleCantidad), '=', ',') + '</Cantidad>';

                        IF vDetallePrecio <> 0 THEN
                            xmlDetalles := xmlDetalles + '<Precio>' + DELCHR(FORMAT(vDetallePrecio), '=', ',') + '</Precio>';

                        //olopez191121  IF vDetalleDescuento <> 0 THEN
                        //olopez191121    xmlDetalles := xmlDetalles + '<Descuento>' + DELCHR(FORMAT(vDetalleDescuento),'=',',') + '</Descuento>';

                        IF vDetalleVentasNoSujetas <> 0 THEN
                            xmlDetalles := xmlDetalles + '<VentasNoSujetas>' + DELCHR(FORMAT(vDetalleVentasNoSujetas), '=', ',') + '</VentasNoSujetas>';
                        IF vDetalleVentasExentas <> 0 THEN
                            xmlDetalles := xmlDetalles + '<VentasExentas>' + DELCHR(FORMAT(vDetalleVentasExentas), '=', ',') + '</VentasExentas>';
                        IF vDetalleVentasAfectas <> 0 THEN
                            xmlDetalles := xmlDetalles + '<VentasAfectas>' + DELCHR(FORMAT(vDetalleVentasAfectas), '=', ',') + '</VentasAfectas>';
                        xmlDetalles := xmlDetalles +
                                        '<CostoNeto>' + DELCHR(FORMAT(vDetalleCostoNeto), '=', ',') + '</CostoNeto>' +
                                        '<Total>' + DELCHR(FORMAT(vDetalleVentasAfectas), '=', ',') + '</Total>' +
                                      '</DetalleDocumento>';
                        xmlDetallesBig.ADDTEXT(xmlDetalles);

                        vDetalleCodigo := ' ';
                        vDetalleProducto := ' ';
                        vDetalleCantidad := 0;
                        vDetallePrecio := 0;
                        vDetalleDescuento := 0;
                        vDetalleVentasNoSujetas := 0;
                        vDetalleVentasExentas := 0;
                        vDetalleVentasAfectas := 0;
                        vDetalleCostoNeto := 0;
                        vDetalleTotal := 0;

                    UNTIL SalesEntry.NEXT = 0;

                //AGREGANDO NUMERO DE TICKET
                IF NOT Transaction."Sale Is Return Sale" THEN BEGIN
                    xmlDetalles := '<DetalleDocumento><Producto>' + 'COPAGO REF. ' + NoTicket + '</Producto></DetalleDocumento>';
                    xmlDetallesBig.ADDTEXT(xmlDetalles);
                END;
            END ELSE BEGIN  //OLOPEZ290721


                IF RemissionHeaderTmp.FINDFIRST THEN
                    REPEAT
                        /*RemissionHeaderTmp.Amount := RemissionHeaderTmp.Amount * _Sign;
                        RemissionHeaderTmp."VAT Amount" := RemissionHeaderTmp."VAT Amount" * _Sign;
                        RemissionHeaderTmp."Disc. Amount" := RemissionHeaderTmp."Disc. Amount" * _Sign;
                        RemissionHeaderTmp."Amount Including VAT" := RemissionHeaderTmp."Amount Including VAT" * _Sign;*/

                        xmlDetalles := '<DetalleDocumento>' +
                          '<Codigo>' + RemissionHeaderTmp."No." + '</Codigo>' +
                          '<Producto>' + DELCHR(DELCHR(RemissionHeaderTmp."External Document No.", '=', '>'), '=', '<') + '</Producto>' +
                          '<Cantidad>1</Cantidad>';

                        IF (Transaction."FSN No. Serie NCF" = lPOSTerminal."FSN No. Serie NCF Cons. Final") THEN BEGIN
                            xmlDetalles += '<Precio>' + DELCHR(FORMAT(RemissionHeaderTmp."Amount Including VAT"), '=', ',') + '</Precio>';
                            IF lCustomer."LSC Print Document Invoice" THEN
                                IF RemissionHeaderTmp."Disc. Amount" <> 0 THEN
                                    xmlDetalles := xmlDetalles + '<Descuento>' + DELCHR(FORMAT(RemissionHeaderTmp."Disc. Amount"), '=', ',') + '</Descuento>';
                            IF _SaleNoSujeta <> 0 THEN
                                xmlDetalles := xmlDetalles + '<VentasNoSujetas>' + DELCHR(FORMAT(_SaleNoSujeta), '=', ',') + '</VentasNoSujetas>';

                            IF (RemissionHeaderTmp."Amount Including VAT" = 0) OR (RemissionHeaderTmp."VAT Amount" <> 0) THEN
                                xmlDetalles := xmlDetalles + '<VentasAfectas>' + DELCHR(FORMAT(RemissionHeaderTmp."Amount Including VAT"), '=', ',') + '</VentasAfectas>'
                            ELSE
                                xmlDetalles := xmlDetalles + '<VentasExentas>' + DELCHR(FORMAT(RemissionHeaderTmp."Amount Including VAT"), '=', ',') + '</VentasExentas>';

                        END ELSE BEGIN
                            xmlDetalles += '<Precio>' + DELCHR(FORMAT(RemissionHeaderTmp.Amount), '=', ',') + '</Precio>';
                            IF lCustomer."LSC Print Document Invoice" THEN
                                IF RemissionHeaderTmp."Disc. Amount" <> 0 THEN
                                    xmlDetalles := xmlDetalles + '<Descuento>' + DELCHR(FORMAT(RemissionHeaderTmp."Disc. Amount"), '=', ',') + '</Descuento>';
                            IF _SaleNoSujeta <> 0 THEN
                                xmlDetalles := xmlDetalles + '<VentasNoSujetas>' + DELCHR(FORMAT(_SaleNoSujeta), '=', ',') + '</VentasNoSujetas>';

                            IF (RemissionHeaderTmp.Amount = 0) OR (RemissionHeaderTmp."VAT Amount" <> 0) THEN
                                xmlDetalles := xmlDetalles + '<VentasAfectas>' + DELCHR(FORMAT(RemissionHeaderTmp.Amount), '=', ',') + '</VentasAfectas>'
                            ELSE
                                xmlDetalles := xmlDetalles + '<VentasExentas>' + DELCHR(FORMAT(RemissionHeaderTmp.Amount), '=', ',') + '</VentasExentas>';
                        END;

                        xmlDetalles := xmlDetalles + '<CostoNeto>' + DELCHR(FORMAT(_ValueZero), '=', ',') + '</CostoNeto>' +
                                        '<Total>' + DELCHR(FORMAT(_ValueZero), '=', ',') + '</Total>' +
                                      '</DetalleDocumento>';

                        xmlDetallesBig.ADDTEXT(xmlDetalles);
                        vDetalleCodigo := ' ';
                        vDetalleProducto := ' ';
                        vDetalleCantidad := 0;
                        vDetallePrecio := 0;
                        vDetalleDescuento := 0;
                        vDetalleVentasNoSujetas := 0;
                        vDetalleVentasExentas := 0;
                        vDetalleVentasAfectas := 0;
                        vDetalleCostoNeto := 0;
                        vDetalleTotal := 0;

                    UNTIL RemissionHeaderTmp.NEXT = 0;
            END; //OLOPEZ290721

        _VATPerc := ABS(Transaction."Perception Amount");
        _VATRet := ABS(Transaction."Retencion Amount");
        _AmountXML := ABS(_TotalG + _VAT + _TotalE + _SaleNoSujeta + _VATPerc - _VATRet + _Cesc);

        IF Transaction."FSN Document Type" = Transaction."FSN Document Type"::Factura THEN BEGIN
            _IDDocument := 1;
            _CopyNo := 3;
        END ELSE
            IF Transaction."FSN Document Type" = Transaction."FSN Document Type"::"Credito Fiscal" THEN BEGIN
                _IDDocument := 2;
                _CopyNo := 4;
            END ELSE
                IF Transaction."FSN Document Type" = Transaction."FSN Document Type"::"Nota Credito" THEN BEGIN
                    _IDDocument := 3;
                    _CopyNo := 4;
                END;
        /*
        _Sums := _Sums * _Sign;
        _SaleExent := _SaleExent * _Sign;
        _SaleAfect := _SaleAfect * _Sign;
        _VAT := _VAT * _Sign;
        _VATPerc := _VATPerc * _Sign;
        _VATRet := _VATRet * _Sign;
        */
        lTransactionHeaderExt.GET(Transaction."Store No.", Transaction."POS Terminal No.", Transaction."Transaction No.");

        //FormatNoText1(Texto, ABS(ROUND(_AmountXML, 0.01, '=')));
        //printUtility.FormatNoText1(Texto, ABS(ROUND(_AmountXML, 0.01, '=')));
        printUtility.Num2Text(_AmountXML);
        _TotalTexts := FSNUTILITY.Num2Text(ABS(Transaction.Payment)) + ' DOLARES';

        //*************************************** XML *******************************************************//
        url := 'http://' + _IP + ':9393/WSImpresiones.asmx?op=ImprimirDocumento';
        soapActionUrl := '"http://tempuri.org/ImprimirDocumento"';

        xml1 := '<?xml version="1.0" encoding="utf-8"?>' +
          '<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soap:Body>' +
              '<ImprimirDocumento xmlns="http://tempuri.org/">' +
                '<reimpresion>' + FORMAT(_RePrint) + '</reimpresion>' + //
                '<copia>' + FORMAT(_CopyNo) + '</copia>' +                    //
                '<idDocumento>' + FORMAT(_IDDocument) + '</idDocumento>' +  //
                '<datosGenerales>' +
                  '<resolucionCopia>' + lTransactionHeaderExt.Resolucion + '</resolucionCopia>' + //

                  '<fechaAutorizacion>' + lTransactionHeaderExt."Fecha Autorizacion" + '</fechaAutorizacion>' +//
                  '<serieCopia>' + lTransactionHeaderExt.Serie + '</serieCopia>' +//
                  '<desdeCopia>' + FORMAT(lTransactionHeaderExt.Desde) + '</desdeCopia>' +   //
                  '<hastaCopia>' + FORMAT(lTransactionHeaderExt.Hasta) + '</hastaCopia>' +   //
                  '<ncfCopia>' + Transaction."FSN NCF" + '</ncfCopia>' +                  //
                  '<giroEmpresa>' + lCompInfo."FSN NRC Description" + '</giroEmpresa>' +    //
                  '<sucursalEmpresa>' + lStore.Name + '</sucursalEmpresa>' + //
                  '<direccionSucursal>' + lStore.Address + '</direccionSucursal>' + //
                  '<nitEmpresa>' + lCompInfo."VAT Registration No." + '</nitEmpresa>' + //
                  '<nrcEmpresa>' + lCompInfo."FSN NRC" + '</nrcEmpresa>';  //

        xml2 := '<nombreCliente>' + DELCHR(DELCHR(DELCHR(lCustomer.Name, '=', '>'), '=', '<'), '=', '&') + '</nombreCliente>' + //
                  '<direccionCliente>' + DELCHR(DELCHR(DELCHR(lCustomer.Address, '=', '>'), '=', '<'), '=', '&') + '</direccionCliente>' + //
                  '<titularCliente>' + xTitular + '</titularCliente>' + //
                  '<beneficiarioCliente>' + xBenef + '</beneficiarioCliente>' + //
                  '<duiCliente>' + lCustomer."FSN DUI" + '</duiCliente>' + //
                  '<nitCliente>' + lCustomer."VAT Registration No." + '</nitCliente>' + //
                  '<nrcCliente>' + lCustomer."FSN NRC" + '</nrcCliente>' +  //
                  '<giroCliente>' + DELCHR(DELCHR(DELCHR(lCustomer."FSN NRC Description", '=', '>'), '=', '<'), '=', '&') + '</giroCliente>'; //

        xml3 := '<fecha>' + _Date + '</fecha>' + //
                  '<sumas>' + DELCHR(FORMAT(_Sums), '=', ',') + '</sumas>' + //
                  '<ventasNoSujetas>' + DELCHR(FORMAT(_SaleNoSujeta), '=', ',') + '</ventasNoSujetas>' +//
                  '<ventasExentas>' + DELCHR(FORMAT(_SaleExent), '=', ',') + '</ventasExentas>' +  //
                  '<ventasAfectas>' + DELCHR(FORMAT(_SaleAfect), '=', ',') + '</ventasAfectas>' + //
                  '<subTotal>' + DELCHR(FORMAT(_Sums), '=', ',') + '</subTotal>' + //
                  '<ivaNormal>' + DELCHR(FORMAT(_VAT), '=', ',') + '</ivaNormal>' +//
                  '<cesc>' + DELCHR(FORMAT(_Cesc), '=', ',') + '</cesc>' + //
                  '<ivaRetenido>' + DELCHR(FORMAT(_VATRet), '=', ',') + '</ivaRetenido>' +//
                  '<ivaPercibido>' + DELCHR(FORMAT(_VATPerc), '=', ',') + '</ivaPercibido>' +//
                  '<monto>' + DELCHR(FORMAT(_AmountXML), '=', ',') + '</monto>' + //
                  '<pos>' + _POS + '</pos>' + //
                  '<cajero>' + _StaffID + '</cajero>' +//
                  '<vendedor>' + _SalesStaff + '</vendedor>' +//
                  '<formaPago>' + _PaymentText + '</formaPago>' +  //
                  '<totalLetras>' + _TotalTexts + '</totalLetras>' +//
                '</datosGenerales>' +
                '<listaProductos>';

        xml4 := '</listaProductos>' +
              '</ImprimirDocumento>' +
            '</soap:Body>' +
          '</soap:Envelope>';
        xmlBig.ADDTEXT(xml1 + xml2 + xml3);
        xmlBig.ADDTEXT(xmlDetallesBig);

        xmlBig.ADDTEXT(xml4);
        vDetalleCodigo := ' ';
        vDetalleProducto := ' ';
        vDetalleCantidad := 0;
        vDetallePrecio := 0;
        vDetalleDescuento := 0;
        vDetalleVentasNoSujetas := 0;
        vDetalleVentasExentas := 0;
        vDetalleVentasAfectas := 0;
        vDetalleCostoNeto := 0;
        vDetalleTotal := 0;

        sb := sb.StringBuilder();

        sb.Append(xmlBig);
        IF xmlFinal.CREATE('C:\Temp\' + Transaction."Receipt No." + ' P ' + _PaymentText + '.xml') THEN BEGIN
            xmlFinal.CREATEOUTSTREAM(xmlStream);
            xmlStream.WRITE(sb.ToString);
            xmlFinal.CLOSE;
        END;
        uriObj := uriObj.Uri(url);
        lgRequest := lgRequest.CreateDefault(uriObj);
        lgRequest.Method := 'POST';
        lgRequest.Host := _IP;
        lgRequest.ContentType := 'text/xml; charset=utf-8';
        lgRequest.Headers.Add('SOAPAction', soapActionUrl);
        lgRequest.Timeout := 90000;
        stream := stream.StreamWriter(lgRequest.GetRequestStream(), ascii.UTF8);
        stream.Write(sb.ToString());
        stream.Close();
        lgResponse := lgRequest.GetResponse();
        str := lgResponse.GetResponseStream();
        reader := reader.XmlTextReader(str);
        document := document.XmlDocument();
        document.Load(reader);
        xmlnodelist := document.SelectNodes('//*');
        document.Save('C:\temp\' + Transaction."Receipt No." + ' R ' + _PaymentText + '.xml');

    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeAddItems(var TransHeader: Record "LSC Transaction Header"; var XML: Text; var IsHandled: Boolean)
    begin

    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterAddItems(var TransHeader: Record "LSC Transaction Header"; var IsHandled: Boolean)
    begin

    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Print Utility", 'OnIsPostPrintOK', '', true, true)]
    local procedure "LSC POS Print Utility_OnIsPostPrintOK"
    (
        var IsPrintOK: Boolean;
        var LastErrorText: Text;
        var Handled: Boolean
    )
    begin
        IsPrintOK := false;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Print Utility", 'OnBeforePrintSalesSlip', '', true, true)]
    local procedure "LSC POS Print Utility_OnBeforePrintSalesSlip"
    (
        var Transaction: Record "LSC Transaction Header";
        var PrintBuffer: Record "LSC POS Print Buffer";
        var PrintBufferIndex: Integer;
        var LinesPrinted: Integer;
        var IsHandled: Boolean;
        var ReturnValue: Boolean
    )
    begin
        if getParams() then
            exit;

        if (Transaction."FSN Document Type" in [Transaction."FSN Document Type"::"Credito Fiscal", Transaction."FSN Document Type"::Factura, Transaction."FSN Document Type"::"Nota Credito"]) then begin
            IsHandled := true;
            if (Transaction."FSN Remission No.") then begin
                //WSGenerarFacturaRemision(Transaction, 4)
                WSGenerarFactura(Transaction, 4, true);
            end else begin
                WSGenerarFactura(Transaction, 4, true);
            end;
        end;
    end;

    local procedure getParams(): Boolean
    var
        parameter: Record "FSN Parameter";
        session: Codeunit "LSC POS Session";
    begin
        parameter.SetRange(Grupo, 'DTE_INVOICE');
        parameter.SetRange(Codigo, session.TerminalNo());
        parameter.SetRange(Valor, 'WS');
        exit(parameter.FindFirst() and parameter.Activo);
    end;

    local procedure excludeOfValidation(var POSTransaction: Record "LSC POS Transaction"): Boolean
    var
        transLine: Record "LSC POS Trans. Line";
        incomeExpense: Record "LSC Income/Expense Account";
        terminal: Record "LSC POS Terminal";
        noSerie: Record "No. Series line";
        onlyTicket: Boolean;
    begin
        transLine.SetRange("Store No.", POSTransaction."Store No.");
        transLine.SetRange("POS Terminal No.", POSTransaction."POS Terminal No.");
        transLine.SetRange("Receipt No.", POSTransaction."Receipt No.");
        transLine.setRange("Entry Type", transLine."Entry Type"::IncomeExpense);
        transLine.setRange("Entry Status", transLine."Entry Status"::" ");
        if not transLine.FindFirst() then
            exit(false);

        repeat
            if not incomeExpense.GET(transLine."Store No.", transLine.number) then
                exit(false);
            onlyTicket := incomeExpense."Only Ticket";
        until (transLine.Next() = 0) or onlyTicket;

        if (POSTransaction."FSN Document Type" <> POSTransaction."FSN Document Type"::Ticket) and onlyTicket then begin
            POSTransaction."FSN Document Type" := POSTransaction."FSN Document Type"::Ticket;
            if terminal.get(POSTransaction."POS Terminal No.") then;
            POSTransaction."FSN No. Serie NCF" := terminal."FSN No. Serie NCF Ticket";
            noSerie.SetRange("Series Code", terminal."FSN No. Serie NCF Ticket");
            if noSerie.FindFirst() then
                POSTransaction."FSN NCF" := noSerie.GetNextSequenceNo(true);
            POSTransaction.MODIFY;
        end;

        exit(onlyTicket);
    end;

    local procedure verifyIncomeExpenseTenderType(Request: Text; var Processed: Boolean; var MsgResult: Text)
    var
        incomeExpense: Record "LSC Income/Expense Account";
        tenderType: Record "LSC Tender Type";
        jObject: JsonObject;
        jToken: JsonToken;
        storeNo, IncExpCode, tenderK, paymentIn : Text;
        TenderList: List of [Text];
    begin
        jObject.ReadFrom(Request);

        if jObject.SelectToken('storeNo', jToken) then
            storeNo := jToken.AsValue().AsText();
        if jObject.SelectToken('IncExpCode', jToken) then
            IncExpCode := jToken.AsValue().AsText();
        if jObject.SelectToken('tenderK', jToken) then
            tenderK := jToken.AsValue().AsText();

        if not incomeExpense.GET(storeNo, IncExpCode) then begin
            Processed := false;
            MsgResult := 'No existe la cuenta de ingreso/gasto';
            exit;
        end;

        if not tenderType.Get(storeNo, tenderK) then begin
            Processed := false;
            MsgResult := 'No existe el tipo de pago';
            exit;
        end;

        if incomeExpense."Payment in" = '' then begin
            Processed := true;
            exit;
        end;

        paymentIn := incomeExpense."Payment in";

        if not paymentIn.Contains('|') and (paymentIn <> tenderK) then begin
            Processed := true;
            MsgResult := 'El tipo de pago no es valido para la cuenta de ingreso/gasto';
            exit;
        end;

        TenderList := paymentIn.Split('|');
        if not TenderList.Contains(tenderK) then begin
            Processed := true;
            MsgResult := 'El tipo de pago no es valido para la cuenta de ingreso/gasto';
            exit;
        end;

        Processed := true;
    end;

    procedure WSGenerarFactura(TransactionTemp: Record "LSC Transaction Header" temporary; Tray: Integer; IsHandledE: Boolean)
    var
        PARAM: Record "FSN Parameter";
        TransactionExtTemp: Record "FSN Transaction Header Ext";
        url: Text;
        soapActionUrl: Text;
        xml1: Text;
        xmlFinal: File;
        XmlOutFile: File;
        xmlStream: OutStream;
        sb: DotNet StringBuilder;
        uriObj: DotNet Uri;
        lgRequest: DotNet HttpWebRequest;
        stream: DotNet StreamWriter;
        ascii: DotNet Encoding;
        lgResponse: DotNet HttpWebResponse;
        str: DotNet Stream;
        reader: DotNet XmlTextReader;
        document: DotNet XmlDocument;
        xmlnodelist: DotNet XmlNodeList;
        xmlBig: BigText;
        vReimpresionR: Integer;
        vIdDocumento: Integer;
        vCopia: Integer;
        EsRemision: Boolean;
        POSTerminal: Record "LSC POS Terminal";
        PaymEntry: Record "LSC Trans. Payment Entry";
        lPayments: Record "LSC POS Trans. Line" temporary;
        TenderType: Record "LSC Tender Type";
        _PaymentText: Text;
        xmlnode: DotNet xmlnode;
        DocumentXML: Text;
        XmlPortTr: XmlPort "FSN XmlPortTransactionReport";
        XmlOutFileName: Text;
        XmlOutStream: OutStream;
        TextNodeREsult: Text;
    begin

        TransactionExtTemp.Reset();
        TransactionExtTemp.SetCurrentKey("Store No.", "POS Terminal No.", "Transaction No.");
        TransactionExtTemp.SetRange(TransactionExtTemp."Store No.", TransactionTemp."Store No.");
        TransactionExtTemp.SetRange(TransactionExtTemp."POS Terminal No.", TransactionTemp."POS Terminal No.");
        TransactionExtTemp.SetRange(TransactionExtTemp."Transaction No.", TransactionTemp."Transaction No.");
        if TransactionExtTemp.FindFirst() then begin
            PaymEntry.RESET;
            PaymEntry.SETRANGE(PaymEntry."Store No.", TransactionTemp."Store No.");
            PaymEntry.SETRANGE(PaymEntry."POS Terminal No.", TransactionTemp."POS Terminal No.");
            PaymEntry.SETRANGE(PaymEntry."Transaction No.", TransactionTemp."Transaction No.");
            IF PaymEntry.FINDFIRST THEN
                REPEAT
                    IF NOT lPayments.GET(PaymEntry."Tender Type", 0) THEN BEGIN
                        lPayments.INIT();
                        lPayments."Receipt No." := PaymEntry."Tender Type";
                        IF TenderType.GET(PaymEntry."Store No.", PaymEntry."Tender Type") THEN
                            lPayments.Description := TenderType.Description;
                        lPayments.INSERT();
                    END;
                UNTIL PaymEntry.NEXT = 0;

            lPayments.RESET;
            IF lPayments.FIND('-') THEN
                REPEAT
                    _PaymentText := _PaymentText + lPayments.Description + ' ';
                UNTIL lPayments.NEXT = 0;

            XmlOutFileName := ('C:\temp\' + TransactionExtTemp."Receipt No." + ' P ' + _PaymentText + '.xml');
            XmlOutFile.Create(XmlOutFileName);
            XmlOutFile.CreateOutStream(XmlOutStream);
            XmlPortTr.SetTransaccionHeaderExt(TransactionExtTemp);
            XmlPortTr.SetDestination(XmlOutStream);
            XmlPortTr.Export();
            XmlOutFile.Close();

            document := document.XmlDocument();//28981
            document.Load(XmlOutFileName);
            TextNodeREsult := document.OuterXml();
            if TextNodeREsult <> '' then begin
                xmlnodelist := document.SelectNodes('//*');
                xmlnode := xmlnodelist.Item(0);
                DocumentXML := xmlnode.InnerXml;
            end;

            PARAM.RESET;
            PARAM.SetRange(PARAM.Grupo, 'GIGAUNO');
            PARAM.SetRange(PARAM.Codigo, TransactionTemp."POS Terminal No.");
            if PARAM.FINDFIRST then begin
                if PARAM.Activo then begin

                    POSTerminal.GET(TransactionTemp."POS Terminal No.");
                    IF (TransactionTemp."FSN Document Type" = TransactionTemp."FSN Document Type"::Factura) AND NOT EsRemision THEN BEGIN

                        vIdDocumento := 1;
                        vCopia := 3;
                    END
                    ELSE
                        IF (TransactionTemp."FSN Document Type" = TransactionTemp."FSN Document Type"::"Credito Fiscal") AND NOT EsRemision THEN BEGIN
                            vIdDocumento := 2;
                            vCopia := 4;
                        END
                        ELSE
                            IF (TransactionTemp."FSN Document Type" = TransactionTemp."FSN Document Type"::"Nota Credito") AND NOT EsRemision THEN BEGIN
                                vIdDocumento := 3;
                                vCopia := 4;
                            END
                            ELSE
                                IF EsRemision THEN BEGIN
                                    IF TransactionTemp."FSN Document Type" = TransactionTemp."FSN Document Type"::Factura THEN BEGIN
                                        vIdDocumento := 1;
                                        vCopia := 3;
                                    END
                                    ELSE BEGIN
                                        IF TransactionTemp."Customer No." = 'C000002' THEN BEGIN
                                            vIdDocumento := 2;
                                            vCopia := 4;
                                        END
                                        ELSE BEGIN
                                            IF (TransactionTemp."FSN No. Serie NCF" = POSTerminal."FSN No. Serie NCF Cons. Final") THEN BEGIN
                                                vIdDocumento := 1;
                                                vCopia := 3;
                                            END
                                            ELSE BEGIN
                                                vIdDocumento := 2;
                                                vCopia := 4;
                                            END;
                                        END;
                                    END;
                                END;

                    if Tray = 1 then
                        vReimpresionR := Tray;

                    url := 'http://' + PARAM.IP + ':9393/WSImpresiones.asmx?op=ImprimirDocumento';
                    soapActionUrl := '"http://tempuri.org/ImprimirDocumento"';

                    xml1 := '<?xml version="1.0" encoding="utf-8"?>' +
                      '<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
                        '<soap:Body>' +
                          '<ImprimirDocumento xmlns="http://tempuri.org/">' +
                            '<reimpresion>' + FORMAT(vReimpresionR) + '</reimpresion>' +
                            '<copia>' + FORMAT(vCopia) + '</copia>' +
                            '<idDocumento>' + FORMAT(vIdDocumento) + '</idDocumento>' +
                            DocumentXML +
                          '</ImprimirDocumento>' +
                        '</soap:Body>' +
                    '</soap:Envelope>';
                    xmlBig.ADDTEXT(xml1);

                    sb := sb.StringBuilder();
                    sb.Append(xmlBig);

                    uriObj := uriObj.Uri(url);
                    lgRequest := lgRequest.CreateDefault(uriObj);
                    lgRequest.Method := 'POST';
                    lgRequest.Host := PARAM.IP;
                    lgRequest.ContentType := 'text/xml; charset=utf-8';
                    lgRequest.Headers.Add('SOAPAction', soapActionUrl);
                    lgRequest.Timeout := 90000;
                    stream := stream.StreamWriter(lgRequest.GetRequestStream(), ascii.UTF8);
                    stream.Write(sb.ToString());
                    stream.Close();
                    //IF lgRequest.UseDefaultCredentials(TRUE) THEN
                    lgResponse := lgRequest.GetResponse();
                    str := lgResponse.GetResponseStream();
                    reader := reader.XmlTextReader(str);
                    document := document.XmlDocument();
                    document.Load(reader);
                    xmlnodelist := document.SelectNodes('//*');
                    document.Save('C:\temp\' + TransactionTemp."Receipt No." + ' R ' + _PaymentText + '.xml');
                    //nodos := xmlnodelist.Count;
                end;
            end;
        end;
    end;


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Post Utility", 'SalesEntryOnBeforeInsert', '', true, true)]
    local procedure "LSC POS Post Utility_SalesEntryOnBeforeInsert"
    (
        var pPOSTransLine: Record "LSC POS Trans. Line";
        var pTransSalesEntry: Record "LSC Trans. Sales Entry"
    )
    begin
        pTransSalesEntry."FSN Remission No." := pPOSTransLine."FSN Remission No.";
    end;

    //Asigna serie cuando es pedido de call
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnAfterGetContext', '', true, true)]
    local procedure "LSC POS Transaction Events_OnAfterGetContext"
    (
        var POSTransaction: Record "LSC POS Transaction";
        var POSTransLine: Record "LSC POS Trans. Line";
        var CurrInput: Text
    )
    var
        POSTransC: Codeunit "LSC POS Transaction";
    begin
        if POSTransC.GetReceiptNo() <> '' then
            InsertCorrTK(POSTransaction);
    end;


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnAfterCalcTotals', '', true, true)]
    local procedure "LSC POS Transaction Events_OnAfterCalcTotals"
    (
        var Rec: Record "LSC POS Transaction";
        var Balance: Decimal;
        var RealBalance: Decimal
    )
    var
        TransLine: Record "LSC POS Trans. Line";
        Customer: Record Customer;
        RetailSetup: Record "LSC Retail Setup";
        OK: Boolean;
        NetAmount: Decimal;
        Perception: Decimal;
    begin
        RetailSetup.Get();
        Rec.CalcFields("Net Amount");
        if Rec."Net Amount" <= RetailSetup."FSN Retention Amt. Limit" then begin
            if Rec."FSN Retention Amount" <> 0 then
                Rec."FSN Retention Amount" := 0;
            exit;
        end;

        if Rec."Net Amount" <= RetailSetup."FSN Perception Amt. Limit" then begin
            if Rec."FSN Perception Amount" <> 0 then
                Rec."FSN Perception Amount" := 0;
            exit;
        end;

        if Rec."Customer No." = '' then
            exit;

        if not Customer.Get(Rec."Customer No.") then
            exit;

        TransLine.Reset();
        TransLine.SetCurrentKey("Receipt No.", "Entry Type", "Entry Status");
        TransLine.SetRange("Receipt No.", Rec."Receipt No.");
        TransLine.SetRange("Entry Type", TransLine."Entry Type"::Item);
        TransLine.SetRange("Entry Status", TransLine."Entry Status"::" ");
        if TransLine.Find('-') then
            repeat
                if TransLine."VAT Amount" <> 0 then begin
                    if TransLine."VAT Amount" <> 0 then
                        NetAmount += TransLine."Net Amount";
                end;
            until (TransLine.Next() = 0) or (OK);

        Rec."FSN Retention Amount" := 0;
        Rec."FSN Perception Amount" := 0;
        Rec.Rounded := 0;

        if NetAmount >= RetailSetup."FSN Retention Amt. Limit" then begin
            if Customer."FSN Customer VAT Type" = Customer."FSN Customer VAT Type"::Retention then begin
                Rec."FSN Retention Amount" := Round(NetAmount * 0.01, 0.01);
                IF NOT InsertIncExpLine(Rec, Rec."FSN Retention Amount", Customer."FSN Customer VAT Type"::Retention) THEN
                    balance := balance - Rec."FSN Retention Amount";
            end;
        end;

        if NetAmount >= RetailSetup."FSN Perception Amt. Limit" then begin
            if Customer."FSN Customer VAT Type" = Customer."FSN Customer VAT Type"::Perception then begin
                Rec."FSN Perception Amount" := Round(NetAmount * 0.01, 0.01);
                IF NOT InsertIncExpLine(Rec, Rec."FSN Perception Amount", Customer."FSN Customer VAT Type"::Perception) THEN
                    Balance := Balance + Rec."FSN Perception Amount";
            end;
        end;
    end;

    procedure InsertIncExpLine(RecPosTransaction: Record "LSC POS Transaction"; PaymentAmount: Decimal; Tcliente: Integer): Boolean
    var
        NewLine: Record "LSC POS Trans. Line";
        LineRec: Record "LSC POS Trans. Line";
        IncExpAccount: Record "LSC Income/Expense Account";
        POSLINES: Codeunit "LSC POS Trans. Lines";
        InfoTextDescription: Text;
        POSTransC: Codeunit "LSC POS Transaction";
        ValInsert: Boolean;
    begin
        DPerceReten(RecPosTransaction);
        IncExpAccount.Reset();
        IncExpAccount.SetRange("Store No.", RecPosTransaction."Store No.");
        if Tcliente = 2 then
            IncExpAccount.SetRange(Description, 'RETENCION 1%');
        if Tcliente = 1 then
            IncExpAccount.SetRange(Description, 'PERCEPCION 1%');
        IF IncExpAccount.FindFirst() THEN BEGIN

            NewLine.Reset();
            NewLine.SetRange(NewLine."Receipt No.", RecPosTransaction."Receipt No.");
            NewLine.SetRange(NewLine."Entry Type", NewLine."Entry Type"::IncomeExpense);
            NewLine.SetRange(NewLine."Entry Status", NewLine."Entry Status"::" ");
            NewLine.SetRange(NewLine.Number, IncExpAccount."No.");
            if not NewLine.FindFirst() then begin
                NewLine.Init();
                NewLine."Receipt No." := RecPosTransaction."Receipt No.";
                ValInsert := true;
            end;

            NewLine."Store No." := RecPosTransaction."Store No.";
            NewLine."POS Terminal No." := RecPosTransaction."POS Terminal No.";
            NewLine."Entry Type" := NewLine."Entry Type"::IncomeExpense;
            NewLine.Validate(Number, IncExpAccount."No.");

            if Tcliente = 2 then
                NewLine.Validate(Amount, (PaymentAmount * -1))
            else
                NewLine.Validate(Amount, PaymentAmount);

            if ValInsert then
                NewLine.InsertLine
            else begin
                NewLine.Quantity := 1;
                NewLine.Price := PaymentAmount;
                NewLine."Net Price" := PaymentAmount;
                NewLine.UpdateAmounts();
                NewLine.Modify(true);
            end;
            Commit;
            LineRec := NewLine;
            POSLINES.SetCurrentLine(LineRec);
            exit(true);
        END ELSE
            exit(false);
    end;

    procedure DPerceReten(POSTrans: Record "LSC POS Transaction")
    var
        myInt: Integer;
        transLine: Record "LSC POS Trans. Line";
        IncExpAccount: Record "LSC Income/Expense Account";
        filter: Text;
    begin
        filter := '16|17';

        transLine.SetRange("Store No.", POSTrans."Store No.");
        transLine.SetRange("Entry Type", transLine."Entry Type"::IncomeExpense);
        transLine.SetRange("POS Terminal No.", POSTrans."POS Terminal No.");
        transLine.SetRange("Receipt No.", POSTrans."Receipt No.");
        transLine.SetFilter(Number, filter);
        transLine.DeleteAll();
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
        TmpTrans: Record "LSC Transaction Header";
    begin
        if RequestID = 'PRINTCOPY' then begin
            TmpTrans.reset;
            TmpTrans.SetCurrentKey("Store No.", "POS Terminal No.", "Transaction No.");
            TmpTrans.SetRange("Store No.", POSMenuLine."POS Help ID");
            TmpTrans.SetRange("POS Terminal No.", POSMenuLine."Current-POSID");
            TmpTrans.SetRange("Transaction No.", POSMenuLine."Key No.");
            if TmpTrans.FindFirst() then begin
                if (TmpTrans."FSN Document Type" in [TmpTrans."FSN Document Type"::"Credito Fiscal", TmpTrans."FSN Document Type"::Factura, TmpTrans."FSN Document Type"::"Nota Credito"]) then
                    WSGenerarFactura(TmpTrans, 1, true);
            end;
        end;
    end;

    [EventSubscriber(ObjectType::Table, Database::"LSC Replen. Template", 'OnBeforeInsertEvent', '', true, true)]
    local procedure "LSC Replen. Template_OnBeforeInsertEvent"
    (
        var Rec: Record "LSC Replen. Template";
        RunTrigger: Boolean
    )
    var
        ReplenishmentJournalBatch: Record "LSC Replen. Journal Batch";
        Text0001: Label 'GENERICO';

    begin
        if Rec.Code <> '' then begin
            ReplenishmentJournalBatch.Init;
            ReplenishmentJournalBatch."Replenishment Template Code" := Rec.Code;
            ReplenishmentJournalBatch."Batch No." := Text0001;
            ReplenishmentJournalBatch.Description := 'Sección por Defecto Reaprov.';
            ReplenishmentJournalBatch."Buyer ID" := Rec."Buyer ID";
            ReplenishmentJournalBatch."Buyer Group Code" := Rec."Buyer Group Code";
            ReplenishmentJournalBatch.Insert;
            RunTrigger := false;
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnAfterIncExpLine', '', true, true)]
    local procedure "LSC POS Transaction Events_OnAfterIncExpLine"
    (
        var POSTransaction: Record "LSC POS Transaction";
        var POSTransLine: Record "LSC POS Trans. Line";
        var CurrInput: Text
    )
    var
        POSTransC: Codeunit "LSC POS Transaction";
        transLine: Record "LSC POS Trans. Line";
        incomeExpense: Record "LSC Income/Expense Account";
    begin
        if incomeExpense.Get(POSTransaction."Store No.", POSTransLine.Number) then;
        if incomeExpense."Locked in Sales" then begin
            transLine.setRange("Store No.", POSTransaction."Store No.");
            transLine.SetRange("POS Terminal No.", POSTransaction."POS Terminal No.");
            transLine.SetRange("Receipt No.", POSTransaction."Receipt No.");
            transLine.SetRange("Entry Type", transLine."Entry Type"::Item);
            transLine.SetRange("Entry Status", transLine."Entry Status"::" ");
            if (transLine.count = 0) then
                exit;

            PosTransC.SetCurrInput(CurrInput);
            PosTransC.VoidLinePressed();

            Message('No se puede agregar %1 porque ya se agregaron productos. \La linea sera anulada', incomeExpense.Description);
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"FSN Utility", 'OnInvokeGlobalChannelEvent', '', false, false)]
    local procedure OnInvokeGlobalChannelEvent(var XMLRequest: Text; var XMLResponse: Text; var RequestID: Text[50]; var POSMenuLine: Record "LSC POS Menu Line"; var Processed: Boolean; var MsgResult: Text);
    begin
        if RequestID = 'TENDER_INCEXP' then begin
            verifyIncomeExpenseTenderType(XmlRequest, Processed, MsgResult);
        end;
    end;



    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnAfterInsertItemLine', '', true, true)]
    local procedure "LSC POS Transaction Events_OnAfterInsertItemLine"
    (
        var POSTransaction: Record "LSC POS Transaction";
        var POSTransLine: Record "LSC POS Trans. Line";
        var CurrInput: Text
    )
    var
        posTransC: Codeunit "LSC POS Transaction";
        transLine: Record "LSC POS Trans. Line";
        incomeExpense: Record "LSC Income/Expense Account";
    begin
        with transLine do begin
            SetRange("Store No.", POSTransaction."Store No.");
            setRange("POS Terminal No.", POSTransaction."POS Terminal No.");
            SetRange("Receipt No.", POSTransaction."Receipt No.");
            SetRange("Entry Type", "Entry Type"::IncomeExpense);
            SetRange("Entry Status", "Entry Status"::" ");
            if not Findset() then
                exit;
            repeat
                if incomeExpense.Get("Store No.", number) then;
                if incomeExpense."Locked in Sales" then begin
                    PosTransC.SetCurrInput(CurrInput);
                    PosTransC.VoidLinePressed();
                    Message('No se pueden agregar productos porque ya se agrego %1. \La linea sera anulada', incomeExpense.Description);
                end;
            until Next() = 0;
        end;
    end;

    procedure ValInconExt(POSTransaction: Record "LSC Pos Transaction")
    var
        myInt: Integer;
        POSTransLineVal: Record "LSC POS Trans. Line";
        incomeExpense: Record "LSC Income/Expense Account";
        TEXTV000: Label 'No puede cambiar tipo Documento con cuenta ingreso gasto %1';
    begin
        POSTransLineVal.Reset();
        POSTransLineVal.SetRange("Receipt No.", POSTransaction."Receipt No.");
        POSTransLineVal.SetRange(POSTransLineVal."Entry Status", 0);
        POSTransLineVal.SetRange("Entry Type", POSTransLineVal."Entry Type"::IncomeExpense);
        if POSTransLineVal.find('-') then begin
            repeat
                if incomeExpense.get(POSTransaction."Store No.", POSTransLineVal.Number) then
                    if incomeExpense."Only Ticket" then begin
                        Error(StrSubstNo(TEXTV000, incomeExpense.Description));
                    end;
            until POSTransLineVal.Next() = 0;
        end;
    end;


}
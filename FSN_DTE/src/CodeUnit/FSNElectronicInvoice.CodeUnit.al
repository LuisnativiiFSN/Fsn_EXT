/// <summary>
/// Codeunit FSN Electronic Invoice (ID 50049).
/// </summary>
codeunit 50049 "FSN Electronic Invoice"
{
    TableNo = "LSC POS Menu Line";

    trigger OnRun()
    begin
        case Rec.Command of
            'CREATE_INVOICE':
                begin
                    //gTransaction.SetRange("Receipt No.", Rec.Cu);
                    GenerateAndSendInvoice(gTransaction);
                end;
        end;
    end;

    #region [variables]
    var
        api: Codeunit "DTE API Connection";
        gTransaction: Record "LSC Transaction Header";
        transactionTmp: Record "LSC Transaction Header" temporary;
        tranSalesEntryTmp: Record "LSC Trans. Sales Entry" temporary;
        transSalesEntryTmp2: Record "LSC Trans. Sales Entry" temporary;
        totalIVA_g: decimal;
        totalNeto_g: decimal;
        totalTotal_g: decimal;
        IsRemission_g: Boolean;
        fsnParameter, fsnParametercaja : Record "FSN Parameter";
        companyActivityCode: label '46491';
        companyActivityDesc: label 'Venta de productos farmacéuticos y medicinales';
        PARAMETER_ERROR: Label 'Parameters for DTE API connection not configured';
        BASIC_EMAIL: Label 'sannsicolas@gmail.com';
        text001: Label 'Issuing Electronic Invoice...';
        text002: Label 'Failed to generate invoice';
        DTEValTrans: Codeunit "DTE Validate Transaction";
        RemissionHeaderTmp: Record "FSN Remission Header" temporary;
        TransactionHeaderExtTmp: Record "LSC Transaction Header" temporary;
        POSSESION: Codeunit "LSC POS Session";
        DifAmount: array[4] of decimal;
    //1 Variacion por item, 2 variación iva, 3 variacion gravada, 4 suma de ingreso/gasto
    #endregion

    #region [Procedures]
    /// <summary>
    /// SendWithContingency.
    /// Send the invoice to the web service with contingency.
    /// </summary>
    /// <param name="transaction">Record "LSC Transaction Header".</param>
    [Normal]
    procedure SendWithContingency(transaction: Record "LSC Transaction Header")
    var
        uri: Text;
        body: HttpContent;
        initialTime, finalTime : Time;
        content, token : Text;
        request: HttpRequestMessage;
        docTye: Enum "FSN DTE Tax ID Type";
        company: Record "Company Information";
        requestHeader, contentHeader : HttpHeaders;
        contingency, json, response : JsonObject;
    begin
        if not getParams() then
            exit;

        company.Get();
        uri := fsnParameter."Web Uri" + 'GenerateInvoice';
        json := CreateInvoice(transaction);

        json.Replace('OperationType', '02');

        initialTime := transaction.Time - 1800000;
        finalTime := transaction.Time + 1800000;

        contingency.Add('type', 3);
        contingency.Add('description', 'fallo en el sistema');
        contingency.Add('name', company.Name);
        contingency.Add('documentType', Format(docTye::NIT.AsInteger()));
        contingency.Add('documentNumber', company."Federal ID No.");
        contingency.Add('dateStartContingency', Format(transaction.Date));
        contingency.Add('timeStartContingency', Format(initialTime));
        contingency.Add('dateEndContingency', Format(transaction.Date));
        contingency.Add('timeEndContingency', Format(finalTime));

        json.Replace('Contingency', contingency);

        json.WriteTo(content);
        body.WriteFrom(content);

        Body.GetHeaders(contentHeader);
        contentHeader.Clear();
        contentHeader.Add('Content-Type', 'application/json');

        request.GetHeaders(requestHeader);
        requestHeader.Clear();
        request.Content := body;

        token := getCredentials();
        requestheader.Add('Authorization', 'Bearer ' + token);

        response := api.Post(uri, request);
        saveInvoice(json, response, transaction);
    end;
    /// <summary>
    /// CreateInvoice.
    /// create a JSON object with the information of the invoice to be sent to the web service.
    /// </summary>
    /// <param name="transaction">Record "LSC Transaction Header".</param>
    /// <returns>Return value of type JsonObject.</returns>
    [Normal]
    procedure CreateInvoice(transaction: Record "LSC Transaction Header"): JsonObject
    var
        json: JsonObject;
        staff: JsonObject;
        jValue: JsonValue;
        paymentMethod, sellerCode, holder, beneficiary, coaseguro : Text;
        globalDiscount: Decimal;
        transSalesEntry: Record "LSC Trans. Sales Entry";
        remission_header: Record "FSN Remission Header";
        keys, values : List of [Text];
        PAYMENT_METHOD_KEY: Label 'Payment Method';
        HOLDER_KEY: Label 'Holder';
        BENEFICIARY_KEY: Label 'Beneficiary';
        SELLER_CODE_KEY: Label 'Seller code';
        CASHIER_CODE_KEY: Label 'Cashier code';
        CODE_KEY: Label 'Code';
        SIG_CODE_KEY: Label 'Signature';
        HEADLINE_CODE_KEY: Label 'Headline';
        AUTH_CODE_KEY: Label 'Authorizer Code';
        GIFTCARD_CODE_KEY: Label 'Total Discount';
        RPN_KEY: Label 'ACTIONADD';
        streamWriter: DotNet StreamWriter;
        directory: DotNet Directory;
        fileName: Text;
        currentDate, newPath, store, terminal, transNo : Text;
        JSonString: Text;
        JsonFinal: File;
        sb: DotNet StringBuilder;
        JsonStream: OutStream;
        ParametJ: Record "FSN Parameter";
        NicopuPaymentEntry: Record "LSC Trans. Payment Entry";
        Nicopu: Decimal;
        NicopuSUM: Decimal;
        Tienda: Record "LSC Store";
    begin
        globalDiscount := 0;
        jValue.SetValueToNull();
        OnBeforeCreateInvoice(transaction);

        json.Add('DocumentType', getDocumentType(transaction));
        json.Add('OperationType', '01');

        validateDateTime(json, transaction);

        json.Add('IdShop', transaction."Store No.");
        //! this node is not used
        //json.Add('Secuencial', getSequential(transaction));
        json.Add('Secuencial', jValue);
        IF POSSESION.GetValue('PAGEDTE') <> 'TRUE' THEN
            json.Add('printTicket', True)
        else
            json.Add('printTicket', false);
        json.Add('isJustTicketPrinting', GetPrintError());
        json.Add('printName', getPrintName(transaction));

        if transaction."FSN Document Type" = transaction."FSN Document Type"::"Nota de Remision" then
            json.Add('TransNo', Format(transaction."Receipt No."))
        else
            json.Add('TransNo', Format(transaction."Transaction No."));

        json.Add('Contingency', jValue);
        json.Add('Seller', getStore(transaction));
        json.Add('Buyer', getCustomer(transaction));

        if transaction."FSN Document Type" = transaction."FSN Document Type"::"Nota de Remision" then begin
            tranSalesEntryTmp.Reset();
            if tranSalesEntryTmp.Find('-') then
                json.Add('ProductList', getProductList(tranSalesEntryTmp, transaction."FSN Document Type", sellerCode, globalDiscount));
        end else begin
            transSalesEntry.SetCurrentKey("Store No.", "POS Terminal No.", "Transaction No.", "Line No.");
            transSalesEntry.SetRange("Store No.", transaction."Store No.");
            transSalesEntry.SetRange("POS Terminal No.", transaction."POS Terminal No.");
            transSalesEntry.SetRange("Transaction No.", transaction."Transaction No.");
            if transSalesEntry.FindSet() then
                json.Add('ProductList', getProductList(transSalesEntry, transaction."FSN Document Type", sellerCode, globalDiscount))
            else begin
                transSalesEntry."Store No." := transaction."Store No.";
                transSalesEntry."POS Terminal No." := transaction."POS Terminal No.";
                transSalesEntry."Transaction No." := transaction."Transaction No.";
                json.Add('ProductList', getProductList(transSalesEntry, transaction."FSN Document Type", sellerCode, globalDiscount))
            end;
        end;

        json.Add('PaymentList', getPaymentList(transaction, paymentMethod, globalDiscount));

        //wvillalta remission
        if IsRemission_g then
            json.Add('Totals', getTotalsRemission(transaction, globalDiscount))
        else
            json.Add('Totals', getTotals(transaction, globalDiscount));

        //agregar los datos a la adenda
        if paymentMethod <> '' then begin
            keys.Add(PAYMENT_METHOD_KEY);
            values.Add(paymentMethod);
        end;

        getHolderAndBeneficiary(transaction, holder, beneficiary);

        checkActionAdd(keys, values);

        if holder <> '' then begin
            keys.Add(HOLDER_KEY);
            values.Add(holder);
        end;

        if beneficiary <> '' then begin
            keys.Add(BENEFICIARY_KEY);
            values.Add(beneficiary);

            keys.Add(SIG_CODE_KEY);
            values.Add('_________________________');
        end;

        if sellerCode <> '' then begin
            keys.Add(SELLER_CODE_KEY);
            values.Add(sellerCode);
        end;

        if transaction."Staff ID" <> '' then begin
            keys.Add(CASHIER_CODE_KEY);
            values.Add(transaction."Staff ID");
        end;

        if transaction."FSN Remission No." then //wvilalta remission
            if globalDiscount <> 0 then begin
                getRemissionCoinsurance(keys, values, transaction);
            end;
        if not transaction."FSN Remission No." then
            if (globalDiscount <> 0) and ((TransactionHeaderExtTmp."Net Income/Exp. Amount" <> 0) or (TransactionHeaderExtTmp."Income/Exp. Amount" <> 0)) then begin
                keys.Add(GIFTCARD_CODE_KEY);
                values.Add('DESCUENTO POR GIFTCARD');
            end;

        Clear(Nicopu);
        Clear(NicopuSUM);

        NicopuPaymentEntry.RESET;
        NicopuPaymentEntry.SetRange(NicopuPaymentEntry."Store No.", transaction."Store No.");
        NicopuPaymentEntry.SetRange(NicopuPaymentEntry."POS Terminal No.", transaction."POS Terminal No.");
        NicopuPaymentEntry.SetRange(NicopuPaymentEntry."Transaction No.", transaction."Transaction No.");
        NicopuPaymentEntry.SetRange(NicopuPaymentEntry."Tender Type", '11');
        NicopuPaymentEntry.SetRange(NicopuPaymentEntry."Safe type", NicopuPaymentEntry."Safe type"::" ");
        if NicopuPaymentEntry.Find('-') then begin
            repeat
                NicopuSUM := NicopuSUM + NicopuPaymentEntry."Amount Tendered";
                Nicopu := Nicopu + NicopuPaymentEntry."Amount in Currency";
            until NicopuPaymentEntry.Next() = 0;
        end;

        if Nicopu <> 0 then begin
            keys.Add('NICOPUNTOS USADOS ');
            values.Add(Format(Nicopu));
        end;

        //keys remission whitout document
        if not IsRemission_g then begin
            if (transaction."FSN Document Type" in [transaction."FSN Document Type"::Factura, transaction."FSN Document Type"::"Credito Fiscal"]) then begin
                if transSalesEntry.FindSet() then
                    if remission_header.Get(0, transSalesEntry."FSN Remission No.") and (transSalesEntry."FSN Remission No." <> '') then begin
                        keys.Add(CODE_KEY);
                        values.Add(remission_header."Insured Parent Card No.");
                        keys.Add(HEADLINE_CODE_KEY);
                        values.Add(remission_header."Insured Parent Name");
                        keys.Add(BENEFICIARY_KEY);
                        values.Add(remission_header."Insured Name");

                        IF remission_header."Authorization No." <> '' then begin
                            keys.Add(AUTH_CODE_KEY);
                            values.Add(remission_header."Authorization No.");
                        end;

                        if (remission_header."Customer No." <> transaction."Customer No.") AND (remission_header."Customer Disc. Group" = 'RPN') then begin
                            keys.Add(RPN_KEY);
                            values.Add(remission_header."Customer Disc. Group");
                        end;

                        keys.Add(SIG_CODE_KEY);
                        values.Add('_________________________');
                    end;
            end;
        end;
        keys.Add('internal_control');
        values.Add(transaction."Store No." + transaction."POS Terminal No." + Format(transaction."Transaction No."));
        keys.Add('Nombre tienda');
        if Tienda.Get(transaction."Store No.") then
            values.Add(Tienda.Name);

        json.Add('adenda', getAdenda(keys, values));


        OnAfterCreateInvoice(transaction, json);
        ParametJ.Reset();
        ParametJ.SetRange(Grupo, 'DTE');
        ParametJ.SetRange(Codigo, 'SAVEJSON');
        ParametJ.SetRange(Activo, true);
        IF ParametJ.FindFirst() then begin
            json.WriteTo(JSonString);
            sb := sb.StringBuilder();
            sb.Append(JSonString);
            if JsonFinal.Create('C:\Temp\DTETEST\' + transaction."Receipt No." + '.json') then begin
                JsonFinal.CreateOutStream(JsonStream);
                JsonStream.Write(sb.ToString);
                JsonFinal.Close();
            end;
        end;
        exit(json);
    end;

    /// <summary>
    /// GenerateAndSendAnulation.
    /// Generate a JSON object with the information of the invoice to be sent to the web service.
    /// </summary>
    /// <param name="Transaction">VAR Record "LSC Transaction Header".</param>
    [Normal]
    procedure GenerateAndSendAnulation(var Transaction: Record "LSC Transaction Header")
    var
        requestHeader, contentHeader : HttpHeaders;
        isEnabled: Boolean;
        body: HttpContent;
        request: HttpRequestMessage;
        json: JsonObject;
        content: Text;
        uri: Text;
        response: JsonObject;
    begin
        isEnabled := getParams();

        if not isEnabled then
            isEnabled := getParamsMaster();

        if not isEnabled then
            Error(PARAMETER_ERROR);

        uri := fsnParameter."Web Uri" + 'CancelInvoice';
        json := CreateAnulation(Transaction);
        json.WriteTo(content);
        body.WriteFrom(content);
        body.GetHeaders(contentHeader);
        contentHeader.Clear();
        contentHeader.Add('Content-Type', 'application/json');
        request.GetHeaders(requestHeader);
        requestHeader.Clear();
        request.Content := body;
        requestHeader.Add('Authorization', 'Bearer ' + getCredentials());
        response := api.Post(uri, request);
        UpdateInvoice(json, response);
    end;

    /// <summary>
    /// GenerateAndSendInvoice.
    /// create a JSON object with the information of the invoice to be sent to the web service.
    /// </summary>
    /// <returns>Return value of type JsonObject.</returns>
    [Normal]
    Procedure GenerateAndSendInvoice(transaction: Record "LSC Transaction Header")
    var
        requestHeader, contentHeader : HttpHeaders;
        request: HttpRequestMessage;
        body: HttpContent;
        json: JsonObject;
        content, token : Text;
        uri: Text;
        response: JsonObject;
        isEnabled: Boolean;
    begin
        isEnabled := getParams();

        if not isEnabled then
            isEnabled := getParamsMaster();

        if not isEnabled then
            Error(PARAMETER_ERROR);

        uri := fsnParameter."Web Uri" + 'GenerateInvoice';
        json := CreateInvoice(transaction);
        json.WriteTo(content);
        body.WriteFrom(content);


        Body.GetHeaders(contentHeader);
        contentHeader.Clear();
        contentHeader.Add('Content-Type', 'application/json');

        request.GetHeaders(requestHeader);
        requestHeader.Clear();
        request.Content := body;

        token := getCredentials();
        requestheader.Add('Authorization', 'Bearer ' + token);

        response := api.Post(uri, request);
        saveInvoice(json, response, transaction);
    end;

    /// <summary>
    /// saveInvoice.
    /// this procedure save the invoice information in the table "FSN DTE Transaction Header".
    /// </summary>
    /// <param name="response">JsonObject.</param>
    /// <param name="transaction">Record "LSC Transaction Header".</param>
    /// <param name="request">JsonObject.</param>
    [Normal]
    procedure saveInvoice(request: JsonObject; response: JsonObject; transaction: Record "LSC Transaction Header")
    var
        dteTransaction: Record "FSN DTE Transaction Header";
        jToken: JsonToken;
        jObject: JsonObject;
        ParametJ: Record "FSN Parameter";
        json: JsonObject;
        sb: DotNet StringBuilder;
        xmlFinal: File;
        xmlStream: OutStream;
        JsonFinal: File;
        JsonStream: OutStream;
        JSonString: Text;
        POSMenuLine: Record "LSC POS Menu Line" temporary;
    begin
        IF POSSESION.GetValue('DTEJOB') = 'TRUE' THEN
            exit;

        if (not response.SelectToken('status', jToken)) or (jToken.AsValue().AsInteger() <> 200) then begin
            //createLog(request, response, transaction);//da error que no encuentra el directorio
            Message(text002);
            exit;
        end;

        response.Get('body', jToken);
        jObject := jToken.AsObject();

        if jObject.SelectToken('authNumber', jToken) and not (JToken.AsValue().IsNull) then
            dteTransaction."DTE AuthNumber" := jToken.AsValue().AsText();

        if jObject.SelectToken('issuedTimeStamp', jToken) and not (JToken.AsValue().IsNull) then
            dteTransaction."DTE IssuedTimeStamp" := CopyStr(jToken.AsValue().AsText(), 1, 19);

        if jObject.SelectToken('enrolledTimeStamp', jToken) and not (JToken.AsValue().IsNull) then
            dteTransaction."DTE EnrolledTimeStamp" := CopyStr(jToken.AsValue().AsText(), 1, 19);

        if jObject.SelectToken('dtEinvoice', jToken) and not (JToken.AsValue().IsNull) then
            dteTransaction."DTE Invoice" := jToken.AsValue().AsText();

        if jObject.SelectToken('ticketType', jtoken) and not (JToken.AsValue().IsNull) then
            dteTransaction."Document Type" := jToken.AsValue().AsText();

        if jObject.SelectToken('selloRecepcion', jtoken) and not (JToken.AsValue().IsNull) then
            if (JToken.AsValue().AsText() <> '') then begin
                dteTransaction."Signature Validation" := jtoken.AsValue().AsText();


                if jToken.AsValue().AsText() = '04' then begin

                    sendToRemission(jObject);

                    if jObject.SelectToken('transNo', jToken) and not (JToken.AsValue().IsNull) then
                        dteTransaction."Store No." := jToken.AsValue().AsText();

                    dteTransaction."POS Terminal No." := '2';

                    dteTransaction."Transaction No." := 0;
                end else begin
                    if jObject.SelectToken('idShop', jToken) and not (JToken.AsValue().IsNull) then
                        dteTransaction."Store No." := jToken.AsValue().AsText();

                    if jObject.SelectToken('transNo', jToken) and not (JToken.AsValue().IsNull) then
                        dteTransaction."Transaction No." := jToken.AsValue().AsInteger();

                    dteTransaction."POS Terminal No." := transaction."POS Terminal No.";
                end;


                if jObject.SelectToken('generationDate', jToken) then
                    dteTransaction."Creating Date" := jToken.AsValue().AsDate();

                if jObject.SelectToken('secuencial', jToken) then
                    changeSequential(transaction, jToken.AsValue().AsText());


                if dteTransaction.Insert(true) then;
            end;

        /*POSMenuLine."POS Help ID" := transaction."Store No.";
        POSMenuLine."Current-POSID" := transaction."POS Terminal No.";
        POSMenuLine."Key No." := transaction."Transaction No.";
        printInvoice(POSMenuLine);*/
        if POSSESION.GetValue('DTEMESSAGE') <> 'TRUE' then
            Message(text001);

        onAfterSaveInvoice(request, response, transaction, dteTransaction);
    end;

    /// <summary>
    /// trimTerminal.
    /// this procedure remove the '#' character from the terminal.
    /// </summary>
    /// <param name="_terminal">Text.</param>
    /// <returns>Return value of type Text.</returns>
    [Normal]
    procedure trimTerminal(_terminal: Text): Text
    var
        newTerminal: Text;
    begin
        //? Verifica si tiene un '#' en el terminal para eliminarlo
        if _terminal.Contains('#') then
            newTerminal := DelChr(_terminal, '=', '#');

        exit(newTerminal);
    end;
    #endregion

    #region [Local Procedures]

    local procedure checkActionAdd(var keys: List of [Text]; var values: List of [Text])
    var
        parameter: Record "FSN Parameter";
    begin
        if parameter.Get('DTE_INVOICE', 'ACTIONADD') and parameter.activo then begin
            keys.Add(parameter.codigo);
            values.Add(parameter.valor);
        end
    end;

    local procedure convertJsonToTransaction(var jsonRequest: Text)
    var
        json, obj : JsonObject;
        array: JsonArray;
        token: JsonToken;
        terminal: text;
        lineNo, qty : Integer;
        netAmount, mount : Decimal;
        posTerminal: Record "LSC POS Terminal";
        itemUnitOfMeasure: Record "Item Unit of Measure";
    begin
        lineNo := 1000;
        json.ReadFrom(jsonRequest);
        transactionTmp.Init();

        transactionTmp."Transaction No." := 123456789;
        transactionTmp."FSN Document Type" := transactionTmp."FSN Document Type"::"Nota de Remision";

        if json.SelectToken('No', token) then
            transactionTmp."Receipt No." := token.AsValue().AsText();

        if json.SelectToken('CompanyCode', token) then
            transactionTmp."Customer No." := token.AsValue().AsText();

        if json.SelectToken('CreateDate', token) then
            transactionTmp."Date" := Today();

        if json.SelectToken('CreateTime', token) then
            transactionTmp."Time" := Time();

        if json.SelectToken('StoreNo', token) then
            transactionTmp."Store No." := token.AsValue().AsText();

        if json.SelectToken('TerminalNo', token) then begin
            terminal := token.AsValue().AsText();
            if terminal = '' then
                terminal := getMasterTerminal();

            transactionTmp."POS Terminal No." := terminal
        end;

        transactionTmp."FSN NCF" := getRemissionSequence(terminal);

        if json.SelectToken('netAmount', token) then begin
            mount := token.AsValue().AsDecimal();
            mount := Round(mount, 0.01);
            transactionTmp."Net Amount" := mount;
        end;

        if json.SelectToken('vatAmount', token) then begin
            mount := token.AsValue().AsDecimal();
            mount := Round(mount, 0.01);
            transactionTmp.Payment := mount;
            transactionTmp."Gross Amount" := mount;
        end;

        if json.SelectToken('Items', token) then
            array := token.AsArray();

        transactionTmp.Insert();

        if array.Count = 0 then
            exit;

        foreach token in array do begin
            tranSalesEntryTmp.Init();
            obj := token.AsObject();

            tranSalesEntryTmp."Receipt No." := transactionTmp."Receipt No.";
            tranSalesEntryTmp."Store No." := transactionTmp."Store No.";
            tranSalesEntryTmp."POS Terminal No." := transactionTmp."POS Terminal No.";
            tranSalesEntryTmp."Transaction No." := transactionTmp."Transaction No.";
            tranSalesEntryTmp."Line No." := lineNo;

            if obj.SelectToken('No', token) then
                tranSalesEntryTmp."Item No." := token.AsValue().AsText();

            if obj.SelectToken('UOM', token) then
                tranSalesEntryTmp."Unit of Measure" := token.AsValue().AsText();

            if obj.SelectToken('Quantity', token) then begin
                if itemUnitOfMeasure.Get(tranSalesEntryTmp."Item No.", tranSalesEntryTmp."Unit of Measure") then
                    qty := itemUnitOfMeasure."Qty. per Unit of Measure" * token.AsValue().AsDecimal()
                else
                    qty := token.AsValue().AsDecimal();
                tranSalesEntryTmp.Quantity := qty;
            end;

            if obj.SelectToken('unitPrice', token) then
                tranSalesEntryTmp."price" := token.AsValue().AsDecimal();

            if obj.SelectToken('discountAmount', token) then
                tranSalesEntryTmp."Discount Amount" := token.AsValue().AsDecimal();

            if obj.SelectToken('VatAmount', token) then begin
                tranSalesEntryTmp."VAT Amount" := token.AsValue().AsDecimal();
                netAmount := token.AsValue().AsDecimal() / 1.13;
                netAmount := Round(netAmount, 0.01);
                tranSalesEntryTmp."Net Amount" := netAmount;
            end;

            if obj.SelectToken('sellerCode', token) then
                tranSalesEntryTmp."Sales Staff" := token.AsValue().AsText();

            lineNo += 1000;
            tranSalesEntryTmp.Insert();
        end;
    end;

    local procedure CreateAnulation(var Transaction: Record "LSC Transaction Header"): JsonObject
    var
        json, customerTaxID : JsonObject;
        jValue: JsonValue;
        jToken: JsonToken;
        company: Record "Company Information";
        customer: Record Customer;
        transSales: Record "LSC Trans. Sales Entry";
        dteTransaction: Record "FSN DTE Transaction Header";
        _terminal: Text;
        docTye: Enum "FSN DTE Tax ID Type";
    begin
        company.Get();

        //? Verificar los datos de la transaccion a anular
        transSales.SetRange("Store No.", Transaction."Store No.");
        transSales.SetRange("POS Terminal No.", Transaction."POS Terminal No.");
        transSales.SetRange("Transaction No.", Transaction."Transaction No.");
        if not transSales.FindSet() then
            exit(json);

        if not dteTransaction.Get(
            transSales."Orig Trans Store",
            transSales."Orig Trans Pos",
            transSales."Orig Trans No."
        ) then
            exit(json);

        //? Verificar los datos del cliente
        if not customer.Get(Transaction."Customer No.") then
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

    local procedure createLog(request: JsonObject; response: JsonObject; transaction: Record "LSC Transaction Header")
    var
        streamWriter: DotNet StreamWriter;
        directory: DotNet Directory;
        localpath: Label 'D:\Soporte\DTE';//16012000
        fileName: Text;
        jToken: JsonToken;
        currentDate, newPath, store, terminal, transNo : Text;
        jsonText: Text;
    begin
        if not directory.Exists(localpath) then
            directory.CreateDirectory(localpath);
        currentDate := Format(Today(), 0, '<Closing><Day,2>-<Month,2>-<Year>');
        newPath := localpath + '/' + currentDate;
        if not directory.Exists(newPath) then
            directory.CreateDirectory(newPath);

        if request.SelectToken('IdShop', jToken) then
            store := jToken.AsValue().AsText();

        terminal := transaction."POS Terminal No.";

        if request.SelectToken('TransNo', jToken) then
            transNo := jToken.AsValue().AsText();

        request.WriteTo(jsonText);
        fileName := Format(newPath + StrSubstNo('/%1_%2_%3_Request.json', store, terminal, transNo));
        streamWriter := streamWriter.StreamWriter(fileName);
        streamWriter.Write(jsonText);
        streamWriter.Close();

        response.WriteTo(jsonText);
        fileName := Format(newPath + StrSubstNo('/%1_%2_%3_Response.json', store, terminal, transNo));
        streamWriter := streamWriter.StreamWriter(fileName);
        streamWriter.Write(jsonText);
        streamWriter.Close();
    end;

    local procedure evaluateTotalByDocumentType(transaction: Record "LSC Transaction Header"): Variant
    var
        documentType: Enum "FSN Transaction Document Type";
        salesEntry: Record "LSC Trans. Sales Entry";
        transIncome: Record "LSC Trans. Inc./Exp. Entry";
        subTotal: Decimal;
    begin
        Clear(totalIVA_g);
        Clear(totalTotal_g);
        Clear(totalNeto_g);
        case transaction."FSN Document Type" of
            transaction."FSN Document Type"::"Credito Fiscal", transaction."FSN Document Type"::"Nota Credito": //wvillalta coinsurance
                begin
                    subTotal := 0;
                    salesEntry.SetRange("Store No.", transaction."Store No.");
                    salesEntry.SetRange("POS Terminal No.", transaction."POS Terminal No.");
                    salesEntry.SetRange("Transaction No.", transaction."Transaction No.");
                    // if not salesEntry.FindSet() then
                    //   exit(serializeDecimal(transaction."Net Amount"));
                    if salesEntry.find('-') then
                        repeat
                            if transaction."FSN Document Type" = transaction."FSN Document Type"::"Credito Fiscal" then
                                if salesEntry."Net Amount" < 0 then
                                    subTotal += salesEntry."Net Amount";
                            if transaction."FSN Document Type" = transaction."FSN Document Type"::"Nota Credito" then
                                if salesEntry."Net Amount" > 0 then
                                    subTotal += salesEntry."Net Amount";

                            totalIVA_g += salesEntry."VAT Amount";
                        until salesEntry.Next() = 0;

                    transIncome.reset();
                    transIncome.SetRange("Store No.", transaction."Store No.");
                    transIncome.SetRange("POS Terminal No.", transaction."POS Terminal No.");
                    transIncome.SetRange("Transaction No.", transaction."Transaction No.");
                    if transIncome.Find('-') then
                        repeat
                            if not (transIncome."No." in ['16', '17']) then begin
                                if transIncome."Account Type" = transIncome."Account Type"::"Income" then
                                    subTotal += transIncome."Net Amount";
                                totalIVA_g += transIncome."VAT Amount";
                            end;
                        until transIncome.Next() = 0;


                    totalNeto_g := subTotal;
                    exit(serializeDecimal(subTotal));                       //wvillalta coinsurance
                end;
            transaction."FSN Document Type"::Factura:
                begin
                    subTotal := 0;
                    salesEntry.SetRange("Store No.", transaction."Store No.");
                    salesEntry.SetRange("POS Terminal No.", transaction."POS Terminal No.");
                    salesEntry.SetRange("Transaction No.", transaction."Transaction No.");
                    if salesEntry.FindSet() then
                        repeat
                            if salesEntry."Total Rounded Amt." < 0 then
                                subTotal += salesEntry."Net Amount" + salesEntry."VAT Amount";
                        until salesEntry.Next() = 0;

                    transIncome.reset();
                    transIncome.SetRange("Store No.", transaction."Store No.");
                    transIncome.SetRange("POS Terminal No.", transaction."POS Terminal No.");
                    transIncome.SetRange("Transaction No.", transaction."Transaction No.");
                    if transIncome.Find('-') then
                        repeat
                            if not (transIncome."No." in ['16']) then begin
                                if transIncome."Account Type" = transIncome."Account Type"::"Income" then
                                    subTotal += transIncome."Net Amount" + transIncome."VAT Amount";
                            end;
                        until transIncome.Next() = 0;

                    exit(serializeDecimal(subTotal));
                end;
            else
                exit(serializeDecimal(transaction."Net Amount"));
        end;
    end;

    local procedure getActivityDesc(DTEActivityCode: Code[6]): Text
    var
        dteParameter: Record "DTE Parameter";
    begin
        dteParameter.SetRange("Code", DTEActivityCode);
        dteParameter.SetRange("Type", dteParameter.Type::"Person Activity");
        if not dteParameter.FindSet() then
            exit('');

        exit(dteParameter.Description);
    end;

    local procedure InsertCountry(customer: Record Customer): Text
    var
        myInt: Integer;
        postCode: Record "Post Code";
        countryCode: Record "Country/Region";
    begin
        countryCode.SetRange(Code, customer."Country/Region Code");
        if countryCode.FindFirst() then
            exit(countryCode.Name);
    end;

    local procedure getAddress(customer: Record Customer): JsonToken
    var
        postCode: Record "Post Code";
        json: JsonObject;
    begin
        if (customer."LSC Retail Customer Group" = 'COMODIN') OR (customer.Address = '') then
            exit;

        json.Add('AddressLine', customer.Address + ', ' + InsertCountry(customer));
        postCode.SetRange(Code, customer."Post Code");
        if not postCode.FindFirst() then begin
            json.Add('District', '14');
            json.Add('State', '06');
            Json.Add('Country', 'SV');
        end else begin
            if postCode."DTE District" <> '' then
                json.Add('District', postCode."DTE District")
            else
                json.Add('District', '01');

            if postCode."DTE State" <> '' then
                json.Add('State', postCode."DTE State")
            else
                json.Add('State', '06');

            if postCode."Country/Region Code" <> '' then
                json.Add('Country', postCode."Country/Region Code")
        end;
        exit(json.AsToken());
    end;

    local procedure getAddress(store: Record "LSC Store"): JsonObject
    var
        postCode: Record "Post Code";
        json: JsonObject;
        value: JsonValue;
    begin
        json.Add('AddressLine', store.Address);
        postCode.SetRange(Code, store."Post Code");
        if not postCode.FindFirst() then begin
            json.Add('District', '14');
            json.Add('State', '06');
        end else begin
            if postCode."DTE District" <> '' then
                json.Add('District', postCode."DTE District")
            else
                json.Add('District', '01');

            if postCode."DTE State" <> '' then
                json.Add('State', postCode."DTE State")
            else
                json.Add('State', '06');
        end;
        exit(json);
    end;

    local procedure getAdenda(keys: List of [Text]; values: List of [Text]): JsonToken
    var
        array: JsonArray;
        json: JsonObject;
        lenght, i : Integer;
    begin
        lenght := keys.Count;

        if lenght = 0 then
            exit;

        if lenght > 10 then begin
            keys.RemoveRange(1, lenght - 10);
            values.RemoveRange(1, lenght - 10);
        end;

        for i := 1 to keys.Count do begin
            Clear(json);
            json.Add('Name', keys.Get(i));
            json.Add('Data', keys.Get(i));
            json.Add('Value', values.Get(i));
            array.Add(json);
        end;

        exit(array.AsToken());
    end;

    local procedure getBienTitulo(transaction: Record "LSC Transaction Header"): JsonValue
    var
        jValue: JsonValue;
    begin
        jValue.SetValueToNull();

        if transaction."FSN Document Type" = transaction."FSN Document Type"::"Nota de Remision" then
            jValue.SetValue('02');

        exit(jValue);
    end;

    local procedure getCredentials(): Text
    var
        requestObject, jObject : JsonObject;
        jToken: JsonToken;
        date: Date;
        posSession: Codeunit "LSC POS Session";
        PASSWORD: Label 'Pa$$w0rd';
        fulljson: Text;
        uri, content, date_txt : Text;
        headers: HttpHeaders;
        body: HttpContent;
        request: HttpRequestMessage;
        Terminal: Record "LSC POS Terminal";
    begin
        if fsnParameter."String Parameters 1 Json" <> '' then begin
            fulljson := fsnParameter."String Parameters 1 Json" + fsnParameter."String Parameters 2 Json";
            jObject.ReadFrom(fulljson);
        end;
        if jObject.SelectToken('expirationDate', jToken) then begin
            date_txt := jToken.AsValue().AsText();
            if not Evaluate(date, date_txt, 9) then
                if Evaluate(date, date_txt, 0) then;
            if Today() < date then begin
                jObject.SelectToken('token', jToken);
                exit(jToken.AsValue().AsText());
            end;
        end;
        if POSSESION.StoreNo() <> '' then
            requestObject.Add('username', POSSESION.StoreNo())
        else
            if Terminal.Get(fsnParameter.Codigo) then
                requestObject.Add('username', Terminal."Store No.");

        requestObject.Add('password', PASSWORD);

        uri := fsnParameter."Web Uri" + 'GetCredentials';
        requestObject.WriteTo(content);
        body.WriteFrom(content);
        body.GetHeaders(headers);
        headers.Clear();
        headers.Add('Content-Type', 'application/json');
        request.Content := body;

        jObject := api.Post(uri, request);

        if jObject.SelectToken('status', jToken) and (jToken.AsValue().AsInteger() <> 200) then
            Error('Error al obtener las credenciales del servicio web');

        jObject.Get('body', jToken);
        jToken.AsObject().WriteTo(fulljson);
        fsnParameter."String Parameters 1 Json" := CopyStr(fulljson, 1, 250);
        fsnParameter."String Parameters 2 Json" := CopyStr(fulljson, 251, 250);
        fsnParameter.Modify();
        Commit();
        jObject := jToken.AsObject();
        jObject.Get('token', jToken);

        exit(jToken.AsValue().AsText());
    end;

    local procedure getCreditPurchase(var posCardEntry: Record "LSC POS Card Entry"): JsonToken
    var
        creditPurchase: JsonObject;
    begin
        //if posCardEntry."EFT Batch No." <> 'PLAZOS' then begin
        creditPurchase.Add('PaymentTerm', '01');
        creditPurchase.Add('Period', '0');
        /*end else begin
            creditPurchase.Add('PaymentTerm', '02');
            creditPurchase.Add('Period', posCardEntry."FSN Points/Terms");1
        end;*/
        exit(creditPurchase.AsToken());
    end;

    local procedure getCustomer(transaction: Record "LSC Transaction Header"): JsonObject
    var
        customer: Record Customer;
        json: JsonObject;
        token: JsonToken;
        value: Integer;
        jsonIsNull: JsonValue;
        jValue: JsonValue;
    begin
        if not customer.Get(transaction."Customer No.") then
            exit(json);

        evaluateSubCustomer(customer, transaction);
        jValue.SetValueToNull();
        if customer."LSC Retail Customer Group" = 'COMODIN' then
            json.Add('IsGenericCustomer', true);

        if customer."LSC Retail Customer Group" <> 'COMODIN' then
            json.Add('NRC', customer."FSN NRC")
        else
            json.Add('NRC', '');

        json.Add('TaxInformation', getTaxInformation(customer));
        json.Add('ActivityCode', customer."DTE Activity Code");
        json.Add('ActivityDesc', getActivityDesc(customer."DTE Activity Code"));

        if customer."LSC Retail Customer Group" <> 'COMODIN' then
            json.Add('Name', serializeName(customer.Name))
        else
            if getCustGenericName(transaction) <> '' then
                json.Add('Name', getCustGenericName(transaction))
            else
                json.Add('Name', 'CLIENTE GENERAL');

        json.Add('ComercialName', customer.Name);
        json.Add('Phone', customer."Phone No.");

        if customer."LSC Retail Customer Group" <> 'COMODIN' then
            json.Add('Email', customer."E-Mail")
        else
            if getCustGenericEmail(transaction) <> '' then
                json.Add('Email', getCustGenericEmail(transaction))
            else
                json.Add('Email', jValue);

        if customer."LSC Retail Customer Group" = 'SINCORREO' then begin
            customer."E-Mail" := '';
            json.Remove('Email');
            json.Add('Email', customer."E-Mail");
        end;

        if customer."FSN Request Beneficiary" then begin
            if getCustGenericEmailBeneficary(transaction) <> '' then begin
                json.Remove('Email');
                json.Add('Email', getCustGenericEmailBeneficary(transaction));
            end;
        end;


        json.Add('Address', getAddress(customer));
        json.Add('BienTitulo', getBienTitulo(transaction));

        exit(json);
    end;

    local procedure getDocumentPerItem(transSalesEntry: Record "LSC Trans. Sales Entry"): JsonToken
    var
        json, auxJson : JsonObject;
        auxToken: JsonToken;
        jValue: JsonValue;
        fsnUtility: Codeunit "FSN Utility";
        xmlReq, xmlRes, reqID, msgResult : Text;
        processed: Boolean;
        menuLine: Record "LSC POS Menu Line";
        dteTransaction: Record "FSN DTE Transaction Header";
        TranHeaderOrigin: Record "LSC Transaction Header";
    begin
        if (transSalesEntry."Orig Trans Pos" <> '') and (transSalesEntry."Orig Trans Store" <> '') and
        (transSalesEntry."Orig Trans No." <> 0) then begin
            if not dteTransaction.Get(transSalesEntry."Orig Trans Store", transSalesEntry."Orig Trans Pos", transSalesEntry."Orig Trans No.") then begin
                if TranHeaderOrigin.Get(transSalesEntry."Orig Trans Store", transSalesEntry."Orig Trans Pos", transSalesEntry."Orig Trans No.") and
                (TranHeaderOrigin."FSN Fiscal Serie" <> '') and
                (TranHeaderOrigin.Date < DMY2Date(1, 7, 2023)) and
                (TranHeaderOrigin."FSN Document Type" = TranHeaderOrigin."FSN Document Type"::"Credito Fiscal") then begin
                    json.Add('DocumentNumber', TranHeaderOrigin."FSN Fiscal Serie" + '-' + TranHeaderOrigin."FSN NCF");
                    json.Add('IssuedDate', TranHeaderOrigin.Date);
                    json.Add('DocumentType', '03');
                    json.Add('GenerationType', '1');
                    exit(json.AsToken());
                end;
                exit;
            end;
            json.Add('DocumentNumber', dteTransaction."DTE AuthNumber");
            json.Add('IssuedDate', dteTransaction."Creating Date");
            json.Add('DocumentType', dteTransaction."Document Type");
            json.Add('GenerationType', '2');
            exit(json.AsToken());
        end else
            if (transSalesEntry."FSN Remission No." <> '') then begin
                //TODO: cambio temporal
                exit;
                xmlReq := transSalesEntry."FSN Remission No.";
                reqID := 'DTE_REMISSION_DATA';
                fsnUtility.InvokeGlobalChannel(xmlReq, xmlRes, reqID, menuLine, processed, msgResult);

                if not (processed) then begin
                    exit;
                end;

                auxJson.ReadFrom(xmlRes);

                auxJson.SelectToken('authNumber', auxToken);
                if auxToken.AsValue().AsText() = '' then begin
                    exit;
                end;
                json.Add('DocumentNumber', auxToken);

                auxJson.SelectToken('IssuedDate', auxToken);
                json.Add('IssuedDate', auxToken);

                json.Add('DocumentType', '04');
                json.Add('GenerationType', '2');

                exit(json.AsToken());
            end;
    end;

    local procedure getDocumentType(transaction: Record "LSC Transaction Header"): Text
    begin
        case transaction."FSN Document Type" of
            "FSN Transaction Document Type"::Factura:
                exit('01');
            "FSN Transaction Document Type"::"Credito Fiscal":
                exit('03');
            "FSN Transaction Document Type"::"Nota de Remision":
                exit('04');
            "FSN Transaction Document Type"::"Nota Credito":
                exit('05');
        end;
    end;

    local procedure getItemName(transSalasEntry: Record "LSC Trans. Sales Entry"): Text
    var
        barcode: Record "LSC Barcodes";
        Item_l: Record Item;
        Infocode: Record "LSC Trans. Infocode Entry";
        Receta: Text;
        DescriptionVariant: Text;
    begin

        DescriptionVariant := DescriptionVariants(transSalasEntry);
        IF DescriptionVariant <> '' THEN
            EXIT(DescriptionVariant);


        Infocode.Reset();
        Infocode.SetRange("Store No.", transSalasEntry."Store No.");
        Infocode.SetRange("POS Terminal No.", transSalasEntry."POS Terminal No.");
        Infocode.SetRange("Transaction No.", transSalasEntry."Transaction No.");
        Infocode.SetRange("Line No.", transSalasEntry."Line No.");
        Infocode.SetRange(Infocode, 'NRECETA');
        IF Infocode.FindFirst() then
            Receta := Infocode.Information;

        barcode.Reset();
        barcode.SetCurrentKey("Item No.", "Variant Code", "Unit of Measure Code");
        barcode.SetRange("Item No.", transSalasEntry."Item No.");
        barcode.SetRange("Unit of Measure Code", transSalasEntry."Unit of Measure");
        if barcode.FindSet() then
            if Receta = '' then
                exit(barcode.Description)
            else
                exit(serializeName(barcode.Description) + ' ' + 'NRECETA ' + Receta);

        if Item_l.get(transSalasEntry."Item No.") then
            if Receta = '' then
                exit(Item_l.Description)
            else
                exit(serializeName(Item_l.Description) + ' ' + 'NRECETA ' + Receta);


    end;

    procedure DescriptionVariants(transSalasEntry: Record "LSC Trans. Sales Entry"): Text
    var
        myInt: Integer;
        POSinfocodeSubCode: Record "LSC information Subcode";
        TableSpecInfocode: Record "LSC Table Specific Infocode";
        InfoCodeRec: Record "LSC Infocode";
        TrInfEntry: Record "LSC Trans. Infocode Entry";
    begin
        TableSpecInfocode.SetCurrentKey("Table ID", Value, "Infocode Code");
        TableSpecInfocode.SetRange(TableSpecInfocode."Table ID", Database::Item);
        TableSpecInfocode.SETRANGE(Value, transSalasEntry."Item No.");
        TableSpecInfocode.SETRANGE("Infocode Code", transSalasEntry."Item No.");
        if TableSpecInfocode.FindFirst() then begin
            IF InfoCodeRec.Get(TableSpecInfocode."Infocode Code") AND (InfoCodeRec.Prompt = 'VARIANTES') THEN BEGIN
                TrInfEntry.Reset();
                TrInfEntry.SetRange("Store No.", transSalasEntry."Store No.");
                TrInfEntry.SetRange("POS Terminal No.", transSalasEntry."POS Terminal No.");
                TrInfEntry.SetRange("Transaction No.", transSalasEntry."Transaction No.");
                TrInfEntry.SetRange("Line No.", transSalasEntry."Line No.");
                TrInfEntry.SetRange(TrInfEntry.Infocode, InfoCodeRec.Code);
                if TrInfEntry.FindFirst() then begin
                    POSinfocodeSubCode.RESET();
                    POSinfocodeSubCode.SetRange("Code", InfoCodeRec.Code);
                    POSinfocodeSubCode.SetRange(POSinfocodeSubCode.Subcode, TrInfEntry.Information);
                    IF POSinfocodeSubCode.FINDFIRST THEN
                        exit(POSinfocodeSubCode.Description);
                end;
            END;
        END ELSE
            exit('');
    end;

    local procedure getParams(): Boolean;
    var
        posSession: Codeunit "LSC POS Session";
    begin
        fsnParameter.SetCurrentKey(Grupo, Codigo);
        fsnParameter.SetRange(Grupo, 'DTE_INVOICE');
        fsnParameter.SetRange(Codigo, posSession.TerminalNo());
        fsnParameter.SetRange(valor, 'WS');
        if not fsnParameter.FindFirst() then
            exit(false);

        exit(fsnParameter.Activo);
    end;

    local procedure getParamsMaster(): Boolean
    var
        lscRetailUser: Record "LSC Retail User";
    begin
        if not lscRetailUser.Get('FASANI\LSADMIN') then
            exit(false);

        fsnParameter.SetCurrentKey(Grupo, Codigo);
        fsnParameter.SetRange(Grupo, 'DTE_INVOICE');
        fsnParameter.SetRange(Codigo, lscRetailUser."POS Terminal");
        fsnParameter.SetRange(valor, 'WS');
        if not fsnParameter.FindFirst() then
            exit(false);

        exit(fsnParameter.Activo);
    end;

    local procedure getMasterTerminal(): Text
    var
        lscRetailUser: Record "LSC Retail User";
    begin
        if not lscRetailUser.Get('FASANI\LSADMIN') then
            exit('');

        exit(lscRetailUser."POS Terminal");
    end;

    local procedure getPaymentList(transaction: Record "LSC Transaction Header"; var paymentMethod: Text; var globalDiscount: Decimal): JsonToken
    var
        customer: Record Customer;
        posCardEntry: Record "LSC POS Card Entry";
        transPaymentEntry: Record "LSC Trans. Payment Entry";
        transPaymentEntry2: Record "LSC Trans. Payment Entry";
        dtePaymentType: Enum "DTE Payment Methods";
        bin: Record "FSN BIN Bank";
        array: JsonArray;
        json: JsonObject;
        value: Decimal;
        json_value: JsonValue;
    begin
        if transaction."FSN Document Type" = transaction."FSN Document Type"::"Nota de Remision" then
            exit;


        transPaymentEntry.SetCurrentKey("Store No.", "POS Terminal No.", "Transaction No.", "Line No.");
        transPaymentEntry.setRange("Receipt No.", transaction."Receipt No.");
        transPaymentEntry.setRange("Store No.", transaction."Store No.");
        transPaymentEntry.setRange("POS Terminal No.", transaction."POS Terminal No.");
        transPaymentEntry.setRange("Change Line", false);
        transPaymentEntry.SetFilter("Amount Tendered", '<>0');
        if (not transPaymentEntry.FindSet()) then begin
            //json.Add('paymentType', Format(dtePaymentType::Other.AsInteger()));
            //json.Add('amount', DelChr(Format(Abs(transaction."Gross Amount")), '=', ','));
            json_value.SetValueToNull();
            //array.Add(json_value);
            exit(json_value.AsToken());
        end else
            repeat
                Clear(json);
                json.Add('ReferenceNumber', '');
                json.Add('ElectronicPaymentNum', '');
                json_value.SetValueToNull();
                json.Add('CreditPurchase', json_value);
                if transPaymentEntry."Amount Tendered" <> 0 then
                    case transPaymentEntry."Tender Type" of
                        '1':
                            begin
                                json.Add('paymentType', Format(dtePaymentType::Cash.AsInteger()));
                                IF POSSESION.GetValue('PAGEDTE') <> 'TRUE' THEN
                                    AbrirCaja();
                                /*if transaction.Payment = 0 then begin
                                    paymentMethod := 'TARJETA DE REGALO';
                                    globalDiscount := Abs(transPaymentEntry."Amount Tendered");
                                    exit;
                                end else*/
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
                        '20':
                            begin
                                posCardEntry.SetCurrentKey("Store No.", "POS Terminal No.", "Transaction No.", "Line No.");
                                posCardEntry.setRange("Receipt No.", transaction."Receipt No.");
                                posCardEntry.setRange("Store No.", transaction."Store No.");
                                posCardEntry.setRange("POS Terminal No.", transaction."POS Terminal No.");
                                if (posCardEntry.FindSet() and (posCardEntry.Count >= 1)) then begin
                                    if posCardEntry."Card Type" = 'CREDIT' then begin
                                        json.Add('paymentType', Format(dtePaymentType::"Credit Card".AsInteger()));
                                        json.Replace('CreditPurchase', getCreditPurchase(posCardEntry));
                                        paymentMethod := 'TARJETA DE CREDITO';
                                    end else begin
                                        json.Add('paymentType', Format(dtePaymentType::"Debit Card".AsInteger()));
                                        paymentMethod := 'TARJETA DE DEBITO';
                                    end;
                                end else begin
                                    json.Add('paymentType', Format(dtePaymentType::"Credit Card".AsInteger()));
                                    paymentMethod := 'TARJETA DE CREDITO';
                                end;
                                json.Replace('ReferenceNumber', posCardEntry."EFT Trans. No.");
                            end;
                        '5':
                            begin
                                json.Add('paymentType', Format(dtePaymentType::"Credit Card".AsInteger()));
                                json.Replace('ReferenceNumber', posCardEntry."EFT Trans. No.");
                                json.Replace('CreditPurchase', getCreditPurchase(posCardEntry));
                                paymentMethod := 'TARJETA DE CREDITO';
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
                if IsRemission_g then begin
                    transSalesEntryTmp2.Reset();
                    transSalesEntryTmp2.CalcSums("Net Amount", "VAT Amount");
                    json.Add('amount', DelChr(Format(Abs(transSalesEntryTmp2."Net Amount" + transSalesEntryTmp2."VAT Amount")), '=', ','));
                end else
                    if transPaymentEntry."Tender Type" = '1' then begin
                        transPaymentEntry2.CopyFilters(transPaymentEntry);
                        transPaymentEntry2.SetRange("Change Line");
                        transPaymentEntry2.SetRange("Tender Type", '1');
                        transPaymentEntry2.CalcSums("Amount Tendered");
                        json.Add('amount', DelChr(Format(Abs(transPaymentEntry2."Amount Tendered")), '=', ','));
                    end else begin
                        json.Add('amount', DelChr(Format(Abs(transPaymentEntry."Amount Tendered")), '=', ','));
                    end;

                array.Add(json);
            until transPaymentEntry.Next() = 0;
        exit(array.AsToken());
    end;

    local procedure getPrice(
        docType: Enum "FSN Transaction Document Type";
        transSalesEntry: Record "LSC Trans. Sales Entry"
    ): Text
    var
        qtyText: Text;
        discText: Text;
        disc: Decimal;
        qty: Decimal;
        totalprice: Decimal;
        price: Decimal;
        vatPostSetup: Record "VAT Posting Setup";
    begin
        totalprice := Abs(transSalesEntry."Net Amount");
        qtyText := getQty(transSalesEntry);
        discText := getProductDisc(docType, transSalesEntry);
        Evaluate(disc, discText);
        Evaluate(qty, qtyText);

        if docType = docType::Factura then begin
            if vatPostSetup.Get(transSalesEntry."VAT Bus. Posting Group", transSalesEntry."VAT Code") then;
            totalprice := totalprice + disc;
            if vatPostSetup."VAT %" <> 0 then
                totalprice += Abs(transSalesEntry."VAT Amount");
        end else
            totalprice := totalprice + disc;

        price := Round(totalprice / qty, 0.0001);
        exit(serializeDecimal(price));
    end;

    local procedure getProductDisc(
        docType: Enum "FSN Transaction Document Type";
        transSalesEntry: Record "LSC Trans. Sales Entry"
    ): Text
    var
        quantity: Text;
        disc: Decimal;
    begin
        if docType = docType::Factura then
            exit(serializeDecimal(transSalesEntry."Discount Amount"));

        disc := transSalesEntry."Discount Amount" / 1.13;
        disc := Round(disc, 0.000001);
        exit(serializeDecimal(disc));
    end;

    ///0116
    local procedure GetDiscRemiss(trans: Record "LSC Transaction Header"; var transSalesEntry: Record "LSC Trans. Sales Entry"): Text
    var
        myInt: Integer;
        remission_line: Record "FSN Remission Line";
    begin
        if (trans."FSN Remission No.") and (transSalesEntry."Discount Amount" = 0) then begin
            remission_line.Reset();
            remission_line.SetRange("Document No.", transSalesEntry."FSN Remission No.");
            remission_line.SetRange("No.", transSalesEntry."Item No.");
            remission_line.SetRange("Unit of Measure", transSalesEntry."Unit of Measure");
            if remission_line.find('-') then begin
                transSalesEntry."Discount Amount" := Round(remission_line."Discount Amount");

                exit(serializeDecimal(Round(remission_line."Discount Amount")));
            end;
        end else
            exit(serializeDecimal(transSalesEntry."Discount Amount"));
    end;

    local procedure getProductList(
        var transSalesEntry: Record "LSC Trans. Sales Entry";
        docType: Enum "FSN Transaction Document Type";
        var sellerCode: Text;
        var globalDiscount: Decimal
    ): JsonArray
    var
        item: Record Item;
        vatPostingSetup: Record "VAT Posting Setup";
        dt: Enum "FSN Transaction Document Type";
        prodType, tempPrice, tempQty : Text;
        mount, price, qty : Decimal;
        array: JsonArray;
        json: JsonObject;
        value: JsonValue;
        trans: Record "LSC Transaction Header";
        remission_line: Record "FSN Remission Line";
        TransLine: record "LSC Trans. Sales Entry";
        TransIncomeExpense: Record "LSC Trans. Inc./Exp. Entry";
        IncomExp: Record "LSC Income/Expense Account";
    begin
        Clear(DifAmount);
        Clear(TransactionHeaderExtTmp);

        if docType in [docType::"Credito Fiscal", docType::"Nota Credito"] then begin
            TransLine.CopyFilters(transSalesEntry);
            TransLine.SetRange("VAT Code", 'IVA 13');
            TransLine.CalcSums("Net Amount", "VAT Amount", "Total Rounded Amt.");
            if Round(TransLine."Total Rounded Amt." / 1.13, 0.01) <> TransLine."Net Amount" then
                DifAmount[1] := Round(TransLine."Total Rounded Amt." / 1.13, 0.01) - TransLine."Net Amount";

            if Round(((DifAmount[1] + TransLine."Net Amount") * 0.13), 0.01) <> TransLine."VAT Amount" then
                DifAmount[2] := Round(((DifAmount[1] + TransLine."Net Amount") * 0.13), 0.01) - TransLine."VAT Amount";
            DifAmount[3] := DifAmount[1];
        end;

        //wvillalta remission
        Clear(trans);
        if trans.Get(transSalesEntry."Store No.", transSalesEntry."POS Terminal No.", transSalesEntry."Transaction No.") then;

        /*if trans."FSN Remission No." then
            if getLinesRemission(transSalesEntry) then begin
                IsRemission_g := true;
                transSalesEntryTmp2.Reset();
                if transSalesEntryTmp2.Find('-') then
                    repeat
                        Clear(json);
                        json.Add('Code', 'REM');
                        json.Add('Name', transSalesEntryTmp2."Posting Exception Key");
                        json.Add('UnitOfMeasure', '99');
                        json.Add('ProductType', '1');
                        json.Add('Quantity', '1');
                        json.Add('SuggestedSalePrice', '0.00');
                        json.Add('Discount', '0.0');
                        json.Add('NO_GRAVADO', '0.00');
                        json.Add('VENTA_NO_SUJETA', '0.00');

                        json.Add('VENTA_EXENTA', '0.00');
                        if (docType in [docType::"Credito Fiscal", docType::"Nota Credito", docType::"Nota de Remision"]) then begin
                            mount := transSalesEntryTmp2."Net Amount";
                        end else begin
                            mount := transSalesEntryTmp2."Net Amount" + transSalesEntryTmp2."VAT Amount";
                        end;
                        json.Add('VENTA_GRAVADA', serializeDecimal(mount));
                        json.Add('Total', serializeDecimal(mount));

                        value.SetValueToNull();
                        json.Add('price', serializeDecimal(mount));
                        json.Add('Document', value);
                        array.Add(json.AsToken());

                    until transSalesEntryTmp2.Next() = 0;
                exit(array);
            end;//wvillalta remission
            */
        if transSalesEntry.Find('-') then
            repeat
                Clear(json);
                if item.Get(transSalesEntry."Item No.") then begin//15837
                    case true of
                        (docType = docType::"Nota de Remision") and (item."LSC Division Code" = '05'):
                            begin

                            end;
                        ((docType = docType::"Credito Fiscal") and (transSalesEntry."Net Amount" > 0)) OR ((docType = docType::Factura) and (transSalesEntry."Net Amount" > 0)) OR ((docType = docType::"Nota Credito") and (transSalesEntry."Net Amount" < 0)):
                            begin
                                //   globalDiscount := globalDiscount + transSalesEntry."Total Rounded Amt.";
                            end;
                        else begin
                            json.Add('Code', item."No.");
                            json.Add('Name', getItemName(transSalesEntry));
                            prodType := getProductType(item);
                            json.Add('ProductType', prodType);
                            if prodType = '2' then
                                json.Add('UnitOfMeasure', '99')
                            else
                                json.Add('UnitOfMeasure', DTEValTrans.ValidateUnitOfMeasure(transSalesEntry));//28981 //? 59 = Unidad
                            json.Add('Quantity', getQty(transSalesEntry));
                            json.Add('SuggestedSalePrice', Format(item."DTE SuggestedSalePrice"));
                            if trans."FSN Remission No." then//1601
                                json.Add('Discount', GetDiscRemiss(trans, transSalesEntry))
                            else
                                json.Add('Discount', getProductDisc(docType, transSalesEntry));
                            json.Add('NO_GRAVADO', '0.00');
                            json.Add('VENTA_NO_SUJETA', '0.00');
                            //? tipo de impuesto
                            if vatPostingSetup.Get(transSalesEntry."VAT Bus. Posting Group", transSalesEntry."VAT Code") then;
                            case true of
                                vatPostingSetup."VAT %" = 0:
                                    begin
                                        json.Add('VENTA_EXENTA', serializeDecimal(transSalesEntry."Net amount"));
                                        json.Add('VENTA_GRAVADA', '0.00');
                                        json.Add('Total', serializeDecimal(transSalesEntry."Net amount"));
                                    end;
                                else begin
                                    json.Add('VENTA_EXENTA', '0.00');
                                    if (docType in [dt::"Credito Fiscal", dt::"Nota Credito", dt::"Nota de Remision"]) then begin
                                        mount := transSalesEntry."Net Amount";
                                    end else begin
                                        mount := transSalesEntry."Net Amount" + transSalesEntry."VAT Amount";
                                    end;
                                    json.Add('VENTA_GRAVADA', serializeDecimal(mount));
                                    json.Add('Total', serializeDecimal(mount));
                                end;
                            end;
                            if (transSalesEntry."Net Amount" + transSalesEntry."VAT Amount") = 0 then begin
                                tempPrice := getProductDisc(docType, transSalesEntry);
                                Evaluate(price, tempPrice);
                                tempQty := getQty(transSalesEntry);
                                Evaluate(qty, tempQty);
                                json.Add('price', serializeDecimal(Round(price / qty, 0.0001)));
                            end else
                                json.Add('price', getPrice(docType, transSalesEntry));

                            json.Add('Document', getDocumentPerItem(transSalesEntry));
                            array.Add(json.AsToken());
                        end;
                    end;
                end;
                if docType = docType::"Credito Fiscal" then
                    if transSalesEntry."Net Amount" > 0 then
                        /* if transSalesEntry."VAT Code" = 'IVA 13' then
                             globalDiscount += Round(transSalesEntry."Total Rounded Amt." / 1.13, 0.01)
                         else*/
                        globalDiscount += transSalesEntry."Net Amount";

                if docType = docType::"Nota Credito" then
                    if transSalesEntry."Net Amount" < 0 then
                        /*if transSalesEntry."VAT Code" = 'IVA 13' then
                            globalDiscount += Round(transSalesEntry."Total Rounded Amt." / 1.13, 0.01)
                        else*/
                        globalDiscount += transSalesEntry."Net Amount";

                if docType = docType::"Factura" then
                    if transSalesEntry."Total Rounded Amt." > 0 then
                        globalDiscount += transSalesEntry."Total Rounded Amt.";

                sellerCode := transSalesEntry."Sales Staff";
            until transSalesEntry.Next() = 0;

        TransIncomeExpense.RESET;
        TransIncomeExpense.SetRange("Store No.", trans."Store No.");
        TransIncomeExpense.SetRange("POS Terminal No.", trans."POS Terminal No.");
        TransIncomeExpense.SetRange("Transaction No.", trans."Transaction No.");
        if TransIncomeExpense.Find('-') then
            if not (TransIncomeExpense."No." in ['16', '17']) then
                repeat
                    if TransIncomeExpense."Account Type" = TransIncomeExpense."Account Type"::Income then begin
                        Clear(IncomExp);
                        if not IncomExp.get(TransIncomeExpense."Store No.", TransIncomeExpense."No.") then
                            IncomExp.Description := IncomExp.TableCaption;
                        Clear(json);
                        json.Add('Code', TransIncomeExpense."No.");
                        json.Add('Name', IncomExp.Description);
                        json.Add('UnitOfMeasure', '99');
                        json.Add('ProductType', '2');
                        json.Add('Quantity', '1');
                        json.Add('SuggestedSalePrice', '0.00');
                        json.Add('Discount', '0.0');
                        json.Add('NO_GRAVADO', '0.00');
                        json.Add('VENTA_NO_SUJETA', '0.00');
                        if (docType in [docType::"Credito Fiscal", docType::"Nota Credito", docType::"Nota de Remision"]) then begin
                            mount := TransIncomeExpense."Net Amount";
                        end else begin
                            mount := TransIncomeExpense."Net Amount" + TransIncomeExpense."VAT Amount";
                        end;
                        if TransIncomeExpense."VAT Code" = 'IVA 13' then begin
                            json.Add('VENTA_EXENTA', '0.00');
                            json.Add('VENTA_GRAVADA', serializeDecimal(mount));
                            TransactionHeaderExtTmp."Net Total Taxable Amount" += mount;
                        end else begin
                            json.Add('VENTA_EXENTA', serializeDecimal(mount));
                            json.Add('VENTA_GRAVADA', '0.00');
                            TransactionHeaderExtTmp."Total Exempt Amount" += mount;
                        end;
                        json.Add('Total', serializeDecimal(mount));

                        value.SetValueToNull();
                        json.Add('price', serializeDecimal(mount));
                        json.Add('Document', value);
                        array.Add(json.AsToken());
                    end else begin
                        if (docType in [docType::"Credito Fiscal", docType::"Nota Credito", docType::"Nota de Remision"]) then begin
                            if TransIncomeExpense."VAT Code" = 'IVA 13' THEN
                                TransactionHeaderExtTmp."Income/Exp. Amount" += TransIncomeExpense."Net Amount"
                            else
                                TransactionHeaderExtTmp."Net Income/Exp. Amount" += TransIncomeExpense."Net Amount";

                            globalDiscount += TransIncomeExpense."Net Amount";
                        end else begin
                            if TransIncomeExpense."VAT Code" = 'IVA 13' THEN
                                TransactionHeaderExtTmp."Income/Exp. Amount" += TransIncomeExpense."Net Amount" + TransIncomeExpense."VAT Amount"
                            else
                                TransactionHeaderExtTmp."Net Income/Exp. Amount" += TransIncomeExpense."Net Amount";

                            globalDiscount += TransIncomeExpense."Net Amount" + TransIncomeExpense."VAT Amount";
                        end;
                    end;
                until TransIncomeExpense.Next() = 0;
        exit(array);
    end;

    local procedure getProductType(item: Record Item): text
    begin
        case item."LSC Division Code" of
            '04'://SERVICIOS
                exit('2');
            '03'://AMBOS
                exit('3');
            else//BIENES
                exit('1');
        end;
    end;

    local procedure getQty(transSalesEntry: Record "LSC Trans. Sales Entry"): Text
    var
        unitOfMeasure: Record "Item Unit of Measure";
        qty: Decimal;
    begin
        qty := (-transSalesEntry.Quantity);

        if unitOfMeasure.Get(transSalesEntry."Item No.", transSalesEntry."Unit of Measure") then begin
            qty := qty / unitOfMeasure."Qty. per Unit of Measure";
        end;

        qty := Round(qty, 0.000001);
        exit(serializeDecimal(qty));
    end;

    local procedure getRemissionSequence(terminal: Text): Code[20]
    var
        sequential: Text;
        series: Record "No. Series Line";
        SERIE_NOT_FOUND: Label 'Series not found';
    begin
        sequential := 'REM' + terminal.Split('#').Get(2);
        series.SetRange("Series Code", sequential);
        if not series.FindSet() then
            Error(SERIE_NOT_FOUND);

        sequential := series.GetNextSequenceNo(true);
        exit(sequential);
    end;

    local procedure getSequential(transaction: Record "LSC Transaction Header"): Text
    begin
        exit(CopyStr(transaction."FSN NCF", 1, 15));
    end;

    local procedure getStore(transaction: Record "LSC Transaction Header"): JsonObject
    var
        company: Record "Company Information";
        terminal: Record "LSC POS Terminal";
        store: Record "LSC Store";
        json: JsonObject;
        token: JsonToken;
        value: Variant;
        _terminal: Text;
        gPHoneNo: Text[30];
        gEMail: Text[80];
        gMessage: Text;

    begin
        if not (store.Get(transaction."Store No.") and terminal.Get(transaction."POS Terminal No.")) then
            exit(json);

        company.Get();
        DTEValTrans.ValidateDataStore(store, gPHoneNo, gEMail, gMessage);//28981

        json.Add('Name', company.Name);
        json.Add('NRC', company."VAT Registration No.");
        json.Add('NIT', company."Federal ID No.");
        _terminal := trimTerminal(transaction."POS Terminal No.");
        json.Add('CodeSellingPoint', _terminal);
        json.Add('CodeSellingPointMH', terminal."DTE CodeSellingPointMH");
        json.Add('TypeEstablishment', store."DTE TypeEstablishment");
        json.Add('CodeEstablishment', store."DTE CodeEstablishment");
        json.Add('CodeEstablishmentMH', store."DTE CodeEstablishmentMH");
        json.Add('Phone', gPHoneNo);
        json.Add('Email', gEMail);
        json.Add('ActivityCode', companyActivityCode);
        json.Add('ActivityDesc', companyActivityDesc);
        json.Add('Address', getAddress(store));

        exit(json);
    end;

    local procedure getTaxInformation(customer: Record Customer): JsonObject
    var
        json: JsonObject;
        token: JsonToken;
        value: Text;
    begin
        if customer."LSC Retail Customer Group" <> 'COMODIN' then
            json.Add('ID', Format(customer."DTE Tax ID Type".AsInteger()))
        else
            json.Add('ID', Format(customer."DTE Tax ID Type"::Otros.AsInteger()));

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

    local procedure getTotals(var transaction: Record "LSC Transaction Header"; globalDiscount: Decimal): JsonObject
    var
        fsnUtility: Codeunit "FSN Utility";
        dt: Enum "FSN Transaction Document Type";
        json: JsonObject;
        discount: JsonObject;
        value: Variant;
        netAmount, amount : Decimal;
        subTotal: Text;
        txt: Text;
        Parameter: Record "FSN Parameter";
    begin
        subTotal := evaluateTotalByDocumentType(transaction);
        json.Add('SubTotal', subTotal);
        json.Add('TOTAL_NO_GRAVADO', '0.00');
        json.Add('TOTAL_NO_SUJETA', '0.00');
        //? validar el tipo de venta en tipo de documento 

        transaction.CalcFields("Total Exempt Discount");
        transaction.CalcFields("Total Tax Discount");

        if Parameter.Get('DTE_INVOICE', 'GRAVADO') then begin
            if (transaction."Total Exempt Amount" <> 0) and (transaction."FSN Document Type" = transaction."FSN Document Type"::Factura) then
                discount.Add('Exento', serializeDecimal(transaction."Total Exempt Amount"))
            else
                discount.Add('Exento', '0.00');

            if (globalDiscount <> 0) then begin
                discount.Add('Gravado', serializeDecimal(globalDiscount - transaction."Total Exempt Amount"));
            end else
                discount.Add('Gravado', '0.00');
            json.Add('Discounts', discount);
        end else begin
            discount.Add('Exento', '0.00');
            if (globalDiscount <> 0) then begin
                discount.Add('Gravado', serializeDecimal(globalDiscount));
            end else
                discount.Add('Gravado', '0.00');
            json.Add('Discounts', discount);
        end;

        transaction.CalcFields("Total Exempt Amount");
        transaction.CalcFields("VAT Total Taxable Amount");
        transaction.CalcFields("Net Total Taxable Amount");

        if (transaction."FSN Document Type" = dt::"Nota de Remision") then begin
            netAmount := transaction."Net Amount";
            totalNeto_g := netAmount;
            totalIVA_g := netAmount * 0.13;
        end else
            netAmount := transaction."Net Total Taxable Amount";

        json.Add('TOTAL_EXENTO', serializeDecimal(transaction."Total Exempt Amount"
                                                + TransactionHeaderExtTmp."Total Exempt Amount"
                                                + TransactionHeaderExtTmp."Net Income/Exp. Amount"));

        if (transaction."FSN Document Type" in [dt::"Credito Fiscal", dt::"Nota Credito", dt::"Nota de Remision"]) then begin
            amount := netAmount - globalDiscount;
            //totalNeto_g -= transaction."Total Exempt Amount";
            json.Add('TOTAL_GRAVADO', serializeDecimal(totalNeto_g
                                                    //+ DifAmount[3]
                                                    + TransactionHeaderExtTmp."Net Total Taxable Amount" - transaction."Total Exempt Amount"));
            //json.Add('IVA', serializeDecimal(totalIVA_g + DifAmount[2]));
            amount := totalIVA_g + totalNeto_g;
            json.Add('IVA', serializeDecimal(amount - (totalNeto_g
                                                    //+ DifAmount[3]
                                                    + TransactionHeaderExtTmp."Net Total Taxable Amount")));
        end else begin
            amount := transaction."VAT Total Taxable Amount"
                        - globalDiscount
                        + TransactionHeaderExtTmp."Net Total Taxable Amount"
                        + TransactionHeaderExtTmp."Income/Exp. Amount";
            json.Add('TOTAL_GRAVADO', serializeDecimal(amount));
            json.Add('IVA', '0.00');
        end;
        //DifAmount[2] := 0;

        json.Add('IvaPercibido', serializeDecimal(transaction."Perception Amount"));
        json.Add('IvaRetenido', serializeDecimal(transaction."Retencion Amount"));
        json.Add('RetencionRenta', '0.00');
        //? Transformar a texto
        txt := fsnUtility.Num2Text(transaction.Payment);
        json.Add('InWords', txt + ' DOLARES');
        json.Add('Amount', serializeDecimal(transaction.Payment));

        exit(json);
    end;

    local procedure getTotalsRemission(var transaction: Record "LSC Transaction Header"; globalDiscount: Decimal): JsonObject
    var
        fsnUtility: Codeunit "FSN Utility";
        dt: Enum "FSN Transaction Document Type";
        json: JsonObject;
        discount: JsonObject;
        value: Variant;
        netAmount, amount : Decimal;
        subTotal: Text;
        txt: Text;
    begin
        transSalesEntryTmp2.Reset();
        transSalesEntryTmp2.CalcSums("Net Amount", "VAT Amount", "Total Rounded Amt.");

        if transaction."FSN Document Type" = transaction."FSN Document Type"::Factura then
            subTotal := serializeDecimal(transSalesEntryTmp2."Total Rounded Amt.")
        else
            subTotal := serializeDecimal(transSalesEntryTmp2."Net Amount");

        json.Add('SubTotal', subTotal);
        json.Add('TOTAL_NO_GRAVADO', '0.00');
        json.Add('TOTAL_NO_SUJETA', '0.00');
        //? validar el tipo de venta en tipo de documento

        globalDiscount := 0;
        discount.Add('Exento', '0.00');

        discount.Add('Gravado', '0.00');
        json.Add('Discounts', discount);

        json.Add('TOTAL_EXENTO', '0.00');
        if (transaction."FSN Document Type" in [dt::"Credito Fiscal", dt::"Nota Credito", dt::"Nota de Remision"]) then begin
            amount := transSalesEntryTmp2."Net Amount";
            json.Add('TOTAL_GRAVADO', serializeDecimal(transSalesEntryTmp2."Net Amount"));
            json.Add('IVA', serializeDecimal(transSalesEntryTmp2."VAT Amount"));
            //amount := amount + (netAmount * 0.13);
        end else begin
            //amount := transaction."VAT Total Taxable Amount" - globalDiscount;
            json.Add('TOTAL_GRAVADO', serializeDecimal(transSalesEntryTmp2."Net Amount" + transSalesEntryTmp2."VAT Amount"));
            json.Add('IVA', '0.00');
        end;

        json.Add('IvaPercibido', serializeDecimal(transaction."Perception Amount"));
        json.Add('IvaRetenido', serializeDecimal(transaction."Retencion Amount"));
        json.Add('RetencionRenta', '0.00');
        //? Transformar a texto
        txt := fsnUtility.Num2Text(transSalesEntryTmp2."Net Amount" + transSalesEntryTmp2."VAT Amount");
        json.Add('InWords', txt + ' DOLARES');
        json.Add('Amount', serializeDecimal(transSalesEntryTmp2."Net Amount" + transSalesEntryTmp2."VAT Amount"));

        exit(json);
    end;

    local procedure sendToRemission(jObject: JsonObject)
    var
        req, res, ID, result : Text;
        jToken: JsonToken;
        processed: Boolean;
        menuline: Record "LSC POS Menu Line";
        fsnUtility: Codeunit "FSN Utility";
        remision: Record "FSN Remission Header";
    begin
        if not jObject.SelectToken('TransNo', jToken) then
            exit;
        if not remision.Get(remision."Document Type"::Remission, jToken.AsValue().AsText()) then
            exit;

        if jObject.SelectToken('dteInvoice', jToken) then begin
            remision."External Document No." := jToken.AsValue().AsText();
            remision.Modify();
        end;
    end;

    local procedure serializeDecimal(mount: Decimal): Text
    begin
        exit(DelChr(Format(Abs(mount)), '=', ','));
    end;

    local procedure UpdateInvoice(request: JsonObject; response: JsonObject)
    var
        jToken: JsonToken;
        jObject: JsonObject;
        dteTransaction: Record "FSN DTE Transaction Header";
    begin
        if (not response.SelectToken('status', jToken)) or (jToken.AsValue().AsInteger() <> 200) then begin
            Message(text002);
            exit;
        end;

        if request.Get('docGUID', jToken) then;
        dteTransaction.SetRange("DTE AuthNumber", jToken.AsValue().AsText());
        if dteTransaction.FindFirst() then begin
            dteTransaction.Status := dteTransaction.Status::Anulled;
            dteTransaction.Modify(true);
        end;
    end;

    local procedure getLinesRemission(var SalesEntry: Record "LSC Trans. Sales Entry"): Boolean
    var
        remission: Record "FSN Remission Header";
        company: Record "FSN Company Insurer";
        lRemissionHeader: Record "FSN Remission Header";
        CompanyInsurer: Record "FSN Company Insurer";
        _TextRemission: Text[50];
        _PrintDateRemission: Boolean;
        lCompany: Record "FSN Company Insurer";
        AmountsArr: array[3] of Decimal;
        lRemissionLine: Record "FSN Remission Line";
        RemissionB: Boolean;
        DocumentlineNo: Integer;
    begin
        //wvillalta remission
        IsRemission_g := false;
        RemissionHeaderTmp.DeleteAll();
        transSalesEntryTmp2.DeleteAll();

        if SalesEntry."FSN Remission No." = '' then
            exit(false);

        repeat
            IF NOT RemissionHeaderTmp.GET(RemissionHeaderTmp."Document Type"::Remission, SalesEntry."FSN Remission No.") THEN BEGIN
                IF lRemissionHeader.GET(lRemissionHeader."Document Type"::Remission, SalesEntry."FSN Remission No.") THEN BEGIN
                    lRemissionHeader.GET(lRemissionHeader."Document Type"::Remission, SalesEntry."FSN Remission No.");
                    _TextRemission := '';
                    _PrintDateRemission := FALSE;
                    IF lCompany.GET(lRemissionHeader."Company No.") THEN BEGIN
                        _PrintDateRemission := lCompany."Print Date In Invoice";
                        _TextRemission := lCompany."Coinsurance Text Add";
                    END;
                    RemissionHeaderTmp.INIT();
                    RemissionHeaderTmp."Document Type" := RemissionHeaderTmp."Document Type"::Remission;
                    RemissionHeaderTmp."No." := SalesEntry."FSN Remission No.";
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
                    RemissionHeaderTmp.Amount -= AmountsArr[1];
                    RemissionHeaderTmp."VAT Amount" -= AmountsArr[2];
                    RemissionHeaderTmp."Amount Including VAT" -= AmountsArr[3];
                    RemissionHeaderTmp.MODIFY;

                END ELSE BEGIN
                    RemissionHeaderTmp.INIT();
                    RemissionHeaderTmp."Document Type" := RemissionHeaderTmp."Document Type"::Remission;
                    RemissionHeaderTmp."No." := SalesEntry."FSN Remission No.";
                    RemissionHeaderTmp.Amount := 0;//-lSalesInfoRemission."Net Amount";
                    RemissionHeaderTmp."VAT Amount" := 0;//-lSalesInfoRemission."VAT Amount";
                    RemissionHeaderTmp."Disc. Amount" := 0;//-lSalesInfoRemission."Discount Amount";
                    RemissionHeaderTmp."Amount Including VAT" := 0;//-(lSalesInfoRemission."Net Amount" + lSalesInfoRemission."VAT Amount");
                    RemissionHeaderTmp.INSERT();
                    IF RemissionHeaderTmp.GET(RemissionHeaderTmp."Document Type"::Remission, SalesEntry."FSN Remission No.") THEN BEGIN
                        RemissionHeaderTmp.Amount += SalesEntry."Net Amount";
                        RemissionHeaderTmp."VAT Amount" += SalesEntry."VAT Amount";
                        RemissionHeaderTmp."Disc. Amount" += SalesEntry."Discount Amount";
                        RemissionHeaderTmp."Amount Including VAT" += SalesEntry."Net Amount" + SalesEntry."VAT Amount";
                        RemissionHeaderTmp.MODIFY;
                    END;
                END;
            END ELSE BEGIN
                IF NOT lRemissionHeader.GET(lRemissionHeader."Document Type"::Remission, SalesEntry."FSN Remission No.") THEN BEGIN
                    RemissionHeaderTmp.Amount += SalesEntry."Net Amount";
                    RemissionHeaderTmp."VAT Amount" += SalesEntry."VAT Amount";
                    RemissionHeaderTmp."Disc. Amount" += SalesEntry."Discount Amount";
                    RemissionHeaderTmp."Amount Including VAT" += SalesEntry."Net Amount" + SalesEntry."VAT Amount";
                    if not RemissionHeaderTmp.MODIFY then
                        RemissionHeaderTmp.INSERT();
                END;
            END;
        until SalesEntry.Next() = 0;

        CLEAR(CompanyInsurer);
        CompanyInsurer.SETRANGE(CompanyInsurer."No.", lRemissionHeader."Company No.");
        CompanyInsurer.SETRANGE(CompanyInsurer."Customer No.", lRemissionHeader."Customer No.");
        IF (CompanyInsurer.FINDFIRST) THEN
            IF ((CompanyInsurer."Usar Remision" = false) AND (RemissionHeaderTmp.COUNT = 1)) THEN
                exit(false);

        DocumentlineNo := 0;
        RemissionHeaderTmp.Reset();
        if RemissionHeaderTmp.Find('-') then
            repeat
                transSalesEntryTmp2.Init();
                transSalesEntryTmp2.Quantity := 1;
                transSalesEntryTmp2.Counter := 300;//remission
                transSalesEntryTmp2."VAT Amount" := Round(RemissionHeaderTmp."VAT Amount", 0.01);
                //VATGravado := VATGravado + Round(RemissionHeaderTmp.Amount, 0.01);
                //VATAmt := VATAmt + Round(RemissionHeaderTmp."VAT Amount", 0.01);
                transSalesEntryTmp2."Net Amount" := Round(RemissionHeaderTmp.Amount, 0.01);
                transSalesEntryTmp2.Price := round(RemissionHeaderTmp."VAT Amount" + RemissionHeaderTmp.Amount, 0.01);
                transSalesEntryTmp2."Posting Exception Key" := DELCHR(DELCHR(RemissionHeaderTmp."External Document No.", '=', '>'), '=', '<');
                DocumentlineNo += 1;
                transSalesEntryTmp2."Line No." := DocumentlineNo;
                transSalesEntryTmp2."Discount Amt. For Printing" := 0;
                transSalesEntryTmp2."Total Rounded Amt." := Round(remission.Amount + remission."VAT Amount", 0.01);
                transSalesEntryTmp2.Insert();
            until RemissionHeaderTmp.Next() = 0;

        transSalesEntryTmp2.Reset();
        exit(transSalesEntryTmp2.find('-'));
    end;

    local procedure existsDTE(var POSMenuLine: Record "LSC POS Menu Line"): Boolean
    var
        dte: Record "FSN DTE Transaction Header";
    begin
        dte.SetRange("Store No.", POSMenuLine."POS Help ID");
        dte.SetRange("POS Terminal No.", POSMenuLine."Current-POSID");
        dte.SetRange("Transaction No.", POSMenuLine."Key No.");

        exit(dte.FindFirst());
    end;

    local procedure printInvoice(POSMenuLine: Record "LSC POS Menu Line")
    var
        request: HttpRequestMessage;
        requestHeader: HttpHeaders;

        dte: Record "FSN DTE Transaction Header";
        api: Codeunit "DTE API Connection";
        uri: Text;
    begin
        dte.SetRange("Store No.", POSMenuLine."POS Help ID");
        dte.SetRange("POS Terminal No.", POSMenuLine."Current-POSID");
        dte.SetRange("Transaction No.", POSMenuLine."Key No.");
        if not dte.FindFirst() then
            exit;

        if not getParams() then
            Error(PARAMETER_ERROR);

        uri := fsnParameter."Web Uri" + 'GetInvoice';
        uri += StrSubstNo('/?invoiceRequest=%1&printTicket=true&printName=%2', dte."DTE AuthNumber", fsnParameter."Value Text 1" + fsnParameter."Value Text 2");
        request.GetHeaders(requestHeader);
        requestHeader.Clear();
        requestHeader.Add('Authorization', 'Bearer ' + getCredentials());
        api.Get(uri, request);
    end;

    local procedure getHolderAndBeneficiary(transaction: Record "LSC Transaction Header"; var holder: Text; var beneficiary: Text)
    var
        infocode: Record "LSC Trans. Infocode Entry";
    begin
        infocode.SetRange("Store No.", transaction."Store No.");
        infocode.SetRange("POS Terminal No.", transaction."POS Terminal No.");
        infocode.SetRange("Transaction No.", transaction."Transaction No.");
        infocode.SetFilter(Information, 'TITULAR*|BENEFICIARIO*');
        if infocode.Find('-') then
            repeat
                if infocode.Information.Contains('TITULAR') then
                    holder := CopyStr(infocode.Information, 11, 70)
                else
                    beneficiary := CopyStr(infocode.Information, 16, 70)
            until infocode.Next() = 0;
    end;

    local procedure evaluateSubCustomer(var customer: Record Customer; transaction: Record "LSC Transaction Header")
    var
        attribute: Record "LSC Attribute Value";
        infocode: Record "LSC Trans. Infocode Entry";
        subCustomer: Record Customer;
    begin
        attribute.SetRange("Attribute Code", 'CLIENTES');
        attribute.SetRange("Link Type", attribute."Link Type"::"Customer");
        attribute.SetRange("Link Field 1", customer."No.");
        attribute.SetRange("Attribute Value", 'SUB CLIENTE PV');
        if not attribute.FindSet() then
            exit;

        infocode.SetRange("Store No.", transaction."Store No.");
        infocode.SetRange("POS Terminal No.", transaction."POS Terminal No.");
        infocode.SetRange("Transaction No.", transaction."Transaction No.");
        infocode.SetRange("Transaction Type", 0);
        infocode.SetRange("Line No.", 40);
        infocode.SetRange("Infocode", 'TEXT');
        if not infocode.FindSet() then
            exit;

        if not subCustomer.Get(infocode.Information) then
            exit;

        customer := subCustomer;
    end;

    local procedure getCustGenericName(transaction: Record "LSC Transaction Header"): Code[100]
    var
        infocode: Record "LSC Trans. Infocode Entry";
    begin

        infocode.SetRange("Store No.", transaction."Store No.");
        infocode.SetRange("POS Terminal No.", transaction."POS Terminal No.");
        infocode.SetRange("Transaction No.", transaction."Transaction No.");
        infocode.SetRange("Transaction Type", 0);
        infocode.SetRange("Line No.", 48);
        infocode.SetRange("Infocode", 'TEXT');
        if infocode.FindFirst() then
            exit(infocode.Information);
    end;

    local procedure getCustGenericEmail(transaction: Record "LSC Transaction Header"): Code[100]
    var
        infocode: Record "LSC Trans. Infocode Entry";
    begin

        infocode.SetRange("Store No.", transaction."Store No.");
        infocode.SetRange("POS Terminal No.", transaction."POS Terminal No.");
        infocode.SetRange("Transaction No.", transaction."Transaction No.");
        infocode.SetRange("Transaction Type", 0);
        infocode.SetRange("Line No.", 49);
        infocode.SetRange("Infocode", 'TEXT');
        if infocode.FindFirst() then
            exit(infocode.Information);
    end;

    local procedure getCustGenericEmailBeneficary(transaction: Record "LSC Transaction Header"): Code[100]
    var
        infocode: Record "LSC Trans. Infocode Entry";
    begin
        infocode.Reset();
        infocode.SetRange("Store No.", transaction."Store No.");
        infocode.SetRange("POS Terminal No.", transaction."POS Terminal No.");
        infocode.SetRange("Transaction No.", transaction."Transaction No.");
        infocode.SetRange("Transaction Type", 0);
        infocode.SetRange("Line No.", 90);
        infocode.SetRange("Infocode", 'EMAILTEXT');
        if infocode.FindFirst() then
            exit(infocode.Information)
        else
            exit('');
    end;

    procedure getCustGenericEmailBeneficaryCC(transaction: Record "LSC POS Transaction"): Code[100]
    var
        infocode: Record "LSC POS Trans. Infocode Entry";
    begin
        infocode.Reset();
        infocode.SetRange(infocode."Store No.", transaction."Store No.");
        infocode.SetRange(infocode."POS Terminal No.", transaction."POS Terminal No.");
        infocode.SetRange(infocode."Receipt No.", transaction."Receipt No.");
        infocode.SetRange("Transaction Type", 0);
        infocode.SetRange("Line No.", 90);
        infocode.SetRange("Infocode", 'EMAILTEXT');
        if infocode.FindFirst() then
            exit(infocode.Information)
        else
            exit('');
    end;

    local procedure loadDTEPortable(var json: Text)
    var
        transNo: Integer;
        store, terminal : Code[20];
        dte: Record "FSN DTE Transaction Header";
        jObject: JsonObject;
        jToken: JsonToken;
    begin
        jObject.ReadFrom(json);

        //? sala
        if jObject.SelectToken('store', jToken) then begin
            store := jToken.AsValue().AsText();
        end;

        //? terminal
        if jObject.SelectToken('terminal', jToken) then
            terminal := jToken.AsValue().AsText();

        dte.SetRange("Store No.", store);
        dte.SetRange("POS Terminal No.", terminal);
        dte.SetRange("Transaction No.", 0);
        if not dte.FindSet() then
            dte.Init();

        //? fecha
        if jObject.SelectToken('date', jToken) then
            dte."DTE IssuedTimeStamp" := jToken.AsValue().AsText();

        dte."Creating Date" := Today();

        if jObject.SelectToken('EnrolledTimeStamp', jToken) then
            dte."DTE EnrolledTimeStamp" := jToken.AsValue().AsText();

        //? sello
        if jObject.SelectToken('SelloRecepcion', jToken) then
            dte."Signature Validation" := jToken.AsValue().AsText();

        dte."Store No." := store;

        dte."POS Terminal No." := terminal;

        //? recibo
        if jObject.SelectToken('receipt', jToken) then
            dte."Receipt No." := jToken.AsValue().AsText();

        //? tipo de documento
        if jObject.SelectToken('docType', jToken) then
            dte."Document Type" := StrSubstNo('0%1', jToken.AsValue().AsInteger());

        //? numero de documento
        if jObject.SelectToken('dteNumber', jToken) then
            dte."DTE Invoice" := jToken.AsValue().AsText();

        //? numero de autorizacion
        if jObject.SelectToken('authNumber', jToken) then
            dte."DTE AuthNumber" := jToken.AsValue().AsText();

        if not dte.Insert(true) then
            dte.Modify(true);
    end;

    local procedure checkDTE(var Transaction: Record "LSC Transaction Header"): Boolean
    var
        dte: Record "FSN DTE Transaction Header";
    begin
        dte.SetRange("Store No.", Transaction."Store No.");
        dte.SetRange("POS Terminal No.", Transaction."POS Terminal No.");
        dte.SetRange("Receipt No.", Transaction."Receipt No.");
        if not dte.FindSet() then
            exit(false);

        dte.Rename(Transaction."Store No.", Transaction."POS Terminal No.", Transaction."Transaction No.");
        exit(true);
    end;

    local procedure getPrintName(transaction: Record "LSC Transaction Header"): Text
    var
        parameter: Record "FSN Parameter";
    begin
        if not parameter.Get('DTE_INVOICE', transaction."POS Terminal No.") then
            exit;

        if (parameter."Value Text 1" = '') or (parameter."Value Text 2" = '') then
            exit;

        exit(Parameter."Value Text 1" + parameter."Value Text 2");
    end;

    local procedure GetPrintError(): Boolean
    var
        parameter: Record "FSN Parameter";
    begin
        parameter.Reset();
        parameter.SetRange(Grupo, 'DTE_INVOICE');
        parameter.SetRange(Codigo, 'ERRORWS');
        parameter.SetRange(Activo, true);
        if (parameter.FindFirst()) or (POSSESION.GetValue('DTECONT') = 'TRUE') then begin
            POSSESION.SetValue('DTECONT', '');
            exit(true);
        end else
            exit(false);
    end;

    local procedure getCoinsurance(transaction: Record "LSC Transaction Header"): Text
    var
        transLine: Record "LSC Trans. Sales Entry";
        remissionLine: Record "FSN Remission Line";
    begin
        transLine.SetRange("Store No.", transaction."Store No.");
        transLine.SetRange("POS Terminal No.", transaction."POS Terminal No.");
        transLine.SetRange("Transaction No.", transaction."Transaction No.");
        if not transLine.FindSet() then
            exit('');

        remissionLine.SetRange("Document Type", remissionLine."Document Type"::Remision);
        remissionLine.SetRange("Document No.", transLine."FSN Remission No.");
        remissionLine.setRange(Type, remissionLine.Type::Coinsurance);
        if remissionLine.FindSet() then
            exit(remissionLine.Description + ' $' + Format(remissionLine."Amount Including VAT"));
    end;

    local procedure getRemissionCoinsurance(var keys: List of [Text]; var values: List of [Text]; transaction: Record "LSC Transaction Header")
    var
        transLine: Record "LSC Trans. Sales Entry";
        item: Record Item;
        remission: Record "FSN Remission Header";
    begin
        transLine.SetRange("Store No.", transaction."Store No.");
        transLine.SetRange("POS Terminal No.", transaction."POS Terminal No.");
        transLine.SetRange("Transaction No.", transaction."Transaction No.");
        if not transLine.FindSet() then
            exit;

        remission.SetRange("Document Type", remission."Document Type"::Remission);
        remission.SetRange("No.", transLine."FSN Remission No.");
        if not remission.FindSet() then
            exit;

        transLine.Reset();
        transLine.SetRange("Receipt No.", remission."Receipt No. Coinsurance");
        if not transLine.FindSet() then
            exit;

        repeat
            item.Get(transLine."Item No.");
            keys.Add(CopyStr(item.Description, 1, 20));
            values.Add(Format(transLine.Price));
        until transLine.Next() = 0;
    end;

    local procedure serializeName(Description: Text[100]): Text
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

    procedure AbrirCaja()
    var
        myInt: Integer;
        Process: DotNet Process;
        Ev: DotNet Environment;
        Parameter: Record "FSN Parameter";
    begin
        Parameter.Reset();
        Parameter.SetRange(Grupo, 'DRAWER');
        Parameter.SetRange(Codigo, 'OPEN');
        IF (Parameter.FindFirst()) AND (Parameter.Activo) THEN
            Process.Start('C:\Drawer\Release\OpenDrawer.exe');
    end;

    local procedure changeSequential(var transaction: Record "LSC Transaction Header"; seq: Text)
    begin
        transaction."Legal Number" := seq;
        transaction."FSN NCF" := seq;
        transaction."FSN Correlative" := seq;

        if transaction.Modify(true) then;
    end;

    local procedure validateDateTime(var json: JsonObject; transaction: Record "LSC Transaction Header")
    var
        month: Integer;
    begin
        //month := Date2DMY(transaction.date, 2);
        //hotfix to validate DTE's in october
        /*if month = 10 then
            json.Add('IssuedDate', '2023-10-31')
        else*/
        json.Add('IssuedDate', transaction.Date);
        json.Add('IssuedTime', transaction.Time);
    end;
    #endregion

    #region [Suscriptions]
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Print Utility", 'OnBeforePrintSalesSlip', '', false, false)]
    local procedure OnBeforePrintSalesSlip(var Sender: Codeunit "LSC POS Print Utility"; var Transaction: Record "LSC Transaction Header"; var PrintBuffer: Record "LSC POS Print Buffer"; var PrintBufferIndex: Integer; var LinesPrinted: Integer; var IsHandled: Boolean; var ReturnValue: Boolean);
    var
        json: JsonObject;
        txt: Text;
        TransPaym: Record "LSC Trans. Payment Entry";
    begin
        POSSESION.SetValue('PAGEDTE', '');
        if not getParams() then
            exit;

        if checkDTE(Transaction) then
            exit;

        if (Transaction."Sale Is Return Sale") and
        (Transaction."FSN Document Type" <> Transaction."FSN Document Type"::"Nota Credito") then begin

            GenerateAndSendAnulation(Transaction);
            exit;
        end;

        if not (Transaction."FSN Document Type" in [Transaction."FSN Document Type"::Ticket]) then begin
            IsHandled := true;
            GenerateAndSendInvoice(Transaction);
        end;

        if (Transaction."FSN Document Type" in [Transaction."FSN Document Type"::Ticket]) then begin
            TransPaym.Reset();
            TransPaym.SetRange("Transaction No.", Transaction."Transaction No.");
            TransPaym.SetRange("POS Terminal No.", Transaction."POS Terminal No.");
            TransPaym.SetRange("Store No.", Transaction."Store No.");
            TransPaym.SetRange("Tender Type", '1');
            if TransPaym.FindFirst() then
                AbrirCaja();
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"FSN Utility", 'OnInvokeGlobalChannelEvent', '', false, false)]
    local procedure OnInvokeGlobalChannelEvent(var XMLRequest: Text; var XMLResponse: Text; var RequestID: Text[50]; var POSMenuLine: Record "LSC POS Menu Line"; var Processed: Boolean; var MsgResult: Text);
    begin
        if (RequestID = 'GENERATE_REMISSION') then begin
            if not getParamsMaster() then
                exit;

            convertJsonToTransaction(XMLRequest);
            GenerateAndSendInvoice(transactionTmp);
            Processed := true;
        end;

        if (RequestID = 'PRINT_DTE') then begin
            if not (existsDTE(POSMenuLine)) then begin
                Processed := false;
                exit;
            end;

            printInvoice(POSMenuLine);
            Processed := true;
        end;

        if (RequestID = 'LOAD_DTEP') then begin
            loadDTEPortable(XMLRequest);
        end;
    end;

    [EventSubscriber(ObjectType::Table, Database::"FSN Remission Header", 'OnAfterModifyEvent', '', true, true)]
    local procedure "FSN Remission Header_OnAfterModifyEvent"
    (
        var Rec: Record "FSN Remission Header";
        var xRec: Record "FSN Remission Header";
        RunTrigger: Boolean
    )
    var
        insurer: Record "FSN Company Insurer";
        COMPANY_NOT_FOUND: label 'Company not found';
        NOT_CERTIFICATE: label 'Not certificate';
    begin
        if Rec.Status = Rec.Status::Pending then
            exit;

        if not getParamsMaster() then
            exit;

        if not insurer.Get(Rec."Company No.") then
            Error(COMPANY_NOT_FOUND);

        if (Rec."auth Number" = '') and (insurer."Usar Remision" = true) and (RunTrigger) then
            Error(NOT_CERTIFICATE);
    end;


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Controller", 'OnButtonPressed', '', false, false)]
    local procedure OnButtonPressed(var POSMenuLine: Record "LSC POS Menu Line"; var handled: Boolean);
    var
        transaction: Record "LSC Transaction Header";
        posCtrl: Codeunit "LSC POS Control Interface";
        recID: RecordId;
        recRef: RecordRef;
        Text0001: Label 'Contingencia activada';
        Pos: Codeunit "LSC POS OPOS Utility";
    begin

        IF POSMenuLine.Command in ['TD_OPEN_DR', 'REM_TENDER'] then begin
            AbrirCaja();
        end;

        if POSMenuLine.Command = 'CONTINGDTE' then begin
            POSSESION.SetValue('DTECONT', 'TRUE');
            Message(Text0001);
        end;

        if not (POSMenuLine.Command = 'PRINT_C_EXT') then
            exit;

        if not posCtrl.GetActiveLookupRecordID(recID) then
            exit;

        recRef.Get(recID);
        recRef.SetTable(transaction);

        POSMenuLine."POS Help ID" := transaction."Store No.";
        POSMenuLine."Current-POSID" := transaction."POS Terminal No.";
        POSMenuLine."Key No." := transaction."Transaction No.";

        if not (existsDTE(POSMenuLine)) then begin
            handled := false;
            exit;
        end;

        printInvoice(POSMenuLine);

        handled := true;
    end;
    #endregion

    #region [Events]
    [IntegrationEvent(false, false)]
    local procedure OnAfterCreateInvoice(transaction: Record "LSC Transaction Header"; var json: JsonObject)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeCreateInvoice(var transaction: Record "LSC Transaction Header")
    begin
    end;

    [IntegrationEvent(false, false)]
    [Scope('OnPrem')]
    local procedure onAfterSaveInvoice(request: JsonObject; response: JsonObject; var transaction: Record "LSC Transaction Header"; var DTETransaction: Record "FSN DTE Transaction Header")
    begin
    end;
    #endregion
}
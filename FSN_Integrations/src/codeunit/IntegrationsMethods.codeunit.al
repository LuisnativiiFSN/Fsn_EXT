/// <summary>
/// Codeunit 50053 FSN Integrations Methods.\
/// this codeunit is used to call the FSN Integrations to load data to BC
/// </summary>
codeunit 50054 "FSN Integrations Methods"
{
    TableNo = "LSC POS Menu Line";
    trigger OnRun()
    var
        json: Text;
    begin
        case Rec.Command of
            'SET_NEW_TRANS':
                setTransactionToNew();
        end;
    end;

    #region [variables]
    var
        integration: Enum "FSN Integrations";
        Hardw: Codeunit "LSC POS Hardware Interface";
        POSGUI: Codeunit "LSC POS GUI";
        POSSESSION: Codeunit "LSC POS Session";
        "Status WS": Option None,Pending,Send,InProcess,Transfered;
        SUB_TYPE: Label 'APP_INTEGRATION';
        NoSeriesMgt: Codeunit NoSeriesManagement;
        lText002: Label 'You cannot new numbers from the number series %1';
        lText003: Label 'There is no Serial Code';
        PseudoMeth: Codeunit "Pseudo Obeserver Methods";
        POSSESION: Codeunit "LSC POS Session";
        Tex0001: Label 'Transacciones de punto express no puede llevar lineas de productos';
        Tex0016: Label 'Termine transaccion para abrir panel PuntoXpress';
        Tex0002: Label 'Transacciones de PuntoXpress no pueden cambiar tipo documento';
    #endregion

    #region [Internal Methods]
    local procedure setTransactionToNew()
    var
        posTrans: Record "LSC POS Transaction";
        posTransCode: Codeunit "LSC POS Transaction";
    begin
        posTrans.Get(posTransCode.GetReceiptNo());
        posTrans."FSN Sub Type" := SUB_TYPE;
        posTrans."Sales Staff" := posTrans."Store No.";
        posTrans.Modify(true);
        Commit();
    end;
    #endregion

    #region [exposed services]

    /// <summary>
    /// getDataStore.
    /// </summary>
    /// <param name="ip">Text.</param>
    /// <returns>Return value of type Text.</returns>
    [ServiceEnabled]
    procedure getDataStore(ip: Text): Text
    var
        parameters: Record "FSN Parameter";
    begin
        parameters.SetRange(Grupo, 'INTEGRACION');
        parameters.SetRange(ip, ip);
        if parameters.FindFirst() then;

        exit(parameters."String Parameters 1 Json");
    end;
    /// <summary>
    /// getTransactionNo.\
    /// Este metodo retorna el numero de transaccion para cargar los datos de la transaccion.
    /// </summary>
    /// <param name="storeNo">string - max[20].</param>
    /// <param name="Terminal">string - max[20].</param>
    /// <returns>Retorna el codigo de la transaccion - string - max[20].</returns>
    [ServiceEnabled]
    procedure getTransactionNo(storeNo: Text[20]; Terminal: Text[20]): Text[20]
    var
        transactionNo: Text[20];
        terminalNo: Text[20];
        posTransaction: Record "LSC POS Transaction";
    begin
        terminalNo := generateTerminalNo(Terminal);
        posTransaction.setRange("Store No.", storeNo);
        posTransaction.setRange("POS Terminal No.", terminalNo);
        posTransaction.setRange("FSN Sub Type", SUB_TYPE);
        if posTransaction.FindLast() then
            transactionNo := posTransaction."Receipt No.";

        exit(transactionNo);
    end;

    /// <summary>
    /// loadTransaction.
    /// cargar los datos de la transaccion.
    /// </summary>
    /// <param name="json">string</param>
    /// <returns>confirma si la transaccion termino de cargar toda la informacion - boolean</returns>
    [ServiceEnabled]
    procedure loadTransaction(json: Text): Boolean
    var
        jObject: JsonObject;
        posTrans: Record "LSC POS Transaction";
    begin
        jObject.ReadFrom(json);
        setTransaction(jObject, posTrans);
        setItems(jObject, posTrans);
        setCustomer(jObject, posTrans);
        setPayment(jObject);
        setInfoCode(jObject, posTrans);
        additionalActions(jObject, posTrans);
        exit(true);
    end;


    [ServiceEnabled]
    procedure DesPXpress(var Response: Text): Boolean
    var
        requestHeader, contentHeader : HttpHeaders;
        request: HttpRequestMessage;
        body: HttpContent;
        json: JsonObject;
        content, token : Text;
        uri: Text;
        jObject: JsonObject;
        isEnabled: Boolean;
        jToken: JsonToken;
        PaymentAmount: Decimal;
        TMovimiento: Integer;
        TServicio: Integer;
        ReciboPEx: Code[20];
        Autorizacion, serviceName : Text;
        Sala, Terminal : Text;
        ErroTerminal: Label 'Se debe de descargar en %1';
        Pseudo: Codeunit "Pseudo Obeserver Methods";
        PosTransa: Record "LSC POS Transaction";
        POSTransC: Codeunit "LSC POS Transaction";
        Comodin, NCliente : Text;
        Customer: Record Customer;
        POSFunc: Codeunit "LSC POS Functions";
        WebServi: Record "FSN WebServiceTable";
        numero: Integer;
        TransactionHeader: Record "LSC Transaction Header";
    begin

        if jObject.ReadFrom(Response) then;

        if jObject.SelectToken('StoreNo', jToken) and not (JToken.AsValue().IsNull) then
            Sala := jToken.AsValue().AsText();

        if jObject.SelectToken('Terminal', jToken) and not (JToken.AsValue().IsNull) then
            Terminal := generateTerminalNoPE(jToken.AsValue().AsText());


        PosTransa.Reset();
        PosTransa.SetRange("Store No.", Sala);
        PosTransa.SetRange("POS Terminal No.", Terminal);
        PosTransa.SetRange("Original Date", Today);
        PosTransa.SetRange("FSN Sub Type", SUB_TYPE);
        if not PosTransa.FindLast() then
            exit(false);

        if jObject.SelectToken('TransactionNo', jToken) then
            if not jToken.AsValue().IsNull then
                ReciboPEx := jToken.AsValue().AsText();

        if WebServi.Get(ReciboPEx) and (WebServi."Status WS" = WebServi."Status WS"::Send) then begin
            TransactionHeader.Reset();
            TransactionHeader.SetRange("Receipt No.", WebServi."Order No.");
            if TransactionHeader.FindFirst() then
                if TransactionHeader."Entry Status" <> TransactionHeader."Entry Status"::Voided then
                    exit(true);
        end;


        if jObject.SelectToken('TypeService', jToken) then
            if not jToken.AsValue().IsNull then begin
                TServicio := jToken.AsValue().AsChar();
                Pseudo.addLine(PosTransa, jToken.AsValue().AsText());
            end;

        if jObject.SelectToken('TypeMovement', jToken) then
            if not jToken.AsValue().IsNull then
                TMovimiento := jToken.AsValue().AsChar();

        if jObject.SelectToken('Amount', jToken) then
            if not jToken.AsValue().IsNull then
                PaymentAmount := jToken.AsValue().AsDecimal();

        if jObject.SelectToken('Authorization', jToken) then
            if not jToken.AsValue().IsNull then begin
                //GUARDAR EN UN INFOCODIGO
                Autorizacion := jToken.AsValue().AsText();
                //addInfocode(PosTransa, 'PUNTOEXPRESS',);
                Pseudo.addLine(PosTransa, 'Autorizacion: ' + Autorizacion);
            end;

        if jObject.SelectToken('ServiceCode', jToken) then
            if not jToken.AsValue().IsNull then begin
                //GUARDAR EN UN INFOCODIGO
                Pseudo.addLine(PosTransa, jToken.AsValue().AsText());
            end;

        if jObject.SelectToken('ServiceName', jToken) then
            if not jToken.AsValue().IsNull then begin
                //GUARDAR EN UN INFOCODIGO
                serviceName := jToken.AsValue().AsText();
                Pseudo.addLine(PosTransa, 'Servicio: ' + serviceName);
            end;

        if jObject.SelectToken('AuthService', jToken) then
            if not jToken.AsValue().IsNull then;

        if jObject.SelectToken('CustomerName', jToken) then
            if not jToken.AsValue().IsNull then
                NCliente := jToken.AsValue().AsText();

        if jObject.SelectToken('Reference', jToken) then
            if not jToken.AsValue().IsNull then
                Pseudo.addInfocode(PosTransa, 'PUNTOEXPRESS', 'N° Referencia: ' + jToken.AsValue().AsText(), 51);


        POSSession.init();
        POSSession.SetHardwareProfile(getHardwareProfile(PosTransa."POS Terminal No."));
        POSSession.SetStore(PosTransa."Store No.");
        POSSession.SetTerminal(PosTransa."POS Terminal No.");
        POSSession.SetStaff(PosTransa."Sales Staff");
        PosFunc.initPosFunctions();
        POSFunc.PosTransDiscLoadData(PosTransa."Receipt No.", true);

        Pseudo.addInfocode(PosTransa, 'PUNTOEXPRESS', serviceName + ' ' + Autorizacion, 52);

        Pseudo.InsertIncExpLine(PosTransa, PaymentAmount, TMovimiento, TServicio);
        Pseudo.LogIntegration('PUNTO EXPRESS', ReciboPEx, PosTransa."Receipt No.", "Status WS"::InProcess, PaymentAmount, serviceName, Autorizacion);
        if not (ValidateCustomerLine(PosTransa)) then begin
            Comodin := CopyStr(PosTransa."Store No.", 2);
            Evaluate(numero, Comodin);
            Comodin := 'G' + Format(numero);
            if Customer.get(Comodin) then
                addCustomerLine(PosTransa, Customer, integration::PXPRESS);
            PosTransa."Customer No." := Comodin;
            if NCliente <> '' then
                PosTransa.Comment := NCliente;
        end;
        PosTransa."FSN Sub Type" := '';
        PosTransa.Modify(true);
        Commit();
        addPaymentLine(PosTransa, PaymentAmount, '1', 'Efectivo');
        TOTALRUN(PosTransa);
        exit(true);
    end;
    #endregion

    #region [local procedures]
    local procedure generateTerminalNoPE(terminal: Text[20]): Text[20]
    var
        prefix: Label 'PV';
    begin
        terminal := DelStr(terminal, 1, 2);
        exit(prefix + '#' + terminal);
    end;

    local procedure ValidateCustomerLine(PosTransa: Record "LSC POS Transaction"): Boolean
    var
        PosTransLine: Record "LSC POS Trans. Line";
    begin
        PosTransLine.Reset();
        PosTransLine.SetRange("Receipt No.", PosTransa."Receipt No.");
        PosTransLine.SetRange("Text Type", PosTransLine."Text Type"::"Cust. Text");
        PosTransLine.SetRange("Entry Status", PosTransLine."Entry Status"::" ");
        if PosTransLine.FindFirst() then
            exit(true)
        else
            exit(false);
    end;

    local procedure TOTALRUN(postransa: Record "LSC POS Transaction"): Boolean
    var
        myInt: Integer;
        Menuline: Record "LSC POS Menu Line";
        POSTrasnC: Codeunit "LSC POS Transaction";
    begin
        Commit();
        Menuline.Init();
        Menuline.Command := 'TOTAL';
        POSTrasnC.Run(Menuline);
        exit(true);
    end;


    local procedure RegTransacc(postransa: Record "LSC POS Transaction"): Boolean
    var
        myInt: Integer;
        Menuline: Record "LSC POS Menu Line";
        POSTrasnC: Codeunit "LSC POS Transaction";
    begin
        Commit();
        Menuline.Init();
        Menuline.Command := 'POST';
        POSTrasnC.Run(Menuline);
        exit(true);
    end;

    local procedure addCustomerLine(var posTrans: Record "LSC POS Transaction"; var customer: Record "Customer"; integrationType: Integer)
    var
        transLine: Record "LSC POS Trans. Line";
    begin
        posTrans."Customer No." := customer."No.";
        posTrans.Modify(true);

        transLine.Init();
        transLine.Validate("Receipt No.", posTrans."Receipt No.");
        transLine.Validate("Store No.", posTrans."Store No.");
        transLine.Validate("POS Terminal No.", posTrans."POS Terminal No.");
        transLine.Validate("Line No.", getLine(posTrans, 'new'));
        transLine.Validate("Entry Type", transLine."Entry Type"::FreeText);
        transLine.Validate("Description", StrSubstNo('Clie: %1', customer.Name));
        transLine.Validate("Text Type", transLine."Text Type"::"Cust. Text");
        transLine.Insert(true);

    end;

    local procedure addCustomText(var posTrans: Record "LSC POS Transaction"; text: Text)
    var
        transLine: Record "LSC POS Trans. Line";
    begin
        transLine.Init();
        transLine.Validate("Receipt No.", posTrans."Receipt No.");
        transLine.Validate("Store No.", posTrans."Store No.");
        transLine.Validate("POS Terminal No.", posTrans."POS Terminal No.");
        transLine.Validate("Line No.", getLine(posTrans, 'new'));
        transLine.Validate("Entry Type", transLine."Entry Type"::FreeText);
        transLine.Validate("Description", text);
        transLine.Validate("Text Type", transLine."Text Type"::"Freetext Input");
        transLine.Insert(true);
    end;

    local procedure additionalActions(jObject: JsonObject; posTrans: Record "LSC POS Transaction")
    var
        jtoken: JsonToken;
        type: Integer;
    begin
        jObject.SelectToken('Type', jToken);
        type := jToken.AsValue().AsInteger();
        case type of
            integration::DTEP.AsInteger():
                begin
                    sendDTE(jObject);
                end;
            integration::ONLIFE.AsInteger():
                begin
                    addComments(jObject, posTrans);
                end;
        end;
    end;

    local procedure addPaymentLine(
        transaction: Record "LSC POS Transaction";
        amount: Decimal;
        tenderType: Text;
        description: Text
    )
    var
        transLine: Record "LSC POS Trans. Line";
    begin
        transLine.Init();
        transLine.Validate("Receipt No.", transaction."Receipt No.");
        transLine.Validate("Store No.", transaction."Store No.");
        transLine.Validate("POS Terminal No.", transaction."POS Terminal No.");
        transLine.Validate("Line No.", getLine(transaction, 'new'));
        transLine.Validate("Entry Type", transLine."Entry Type"::Payment);
        transLine.Validate(Number, tenderType);
        transLine.Validate("Description", description);
        transLine.Validate("Amount", amount);
        transLine.Validate(Quantity, 1);
        transLine.Insert(true);
        //posTransCode.CalcTotals();
    end;

    local procedure addDocumentLine(var posTrans: Record "LSC POS Transaction"; var Tipo: Integer)
    var
        transLine: Record "LSC POS Trans. Line";
    begin
        transLine.Init();
        transLine.Validate("Receipt No.", posTrans."Receipt No.");
        transLine.Validate("Store No.", posTrans."Store No.");
        transLine.Validate("POS Terminal No.", posTrans."POS Terminal No.");
        transLine.Validate("Line No.", 32);
        transLine.Validate("Entry Type", transLine."Entry Type"::FreeText);
        if Tipo = 1 then
            transLine.Validate("Description", 'Cliente solicito Factura')
        else
            transLine.Validate("Description", 'Cliente solicito Credito Fiscal');

        transLine.Validate("Text Type", transLine."Text Type"::"Cust. Text");
        transLine.Insert(true);
    end;

    local procedure addPosCard(
        transaction: Record "LSC POS Transaction";
        authCode: Text[9];
        BIN: Text[9];
        input: Text
    )
    var
        posCard: Record "LSC POS Card Entry";
        amount: Decimal;
    begin
        Evaluate(amount, input);
        posCard.Init();
        posCard.Validate("Receipt No.", transaction."Receipt No.");
        posCard.Validate("Store No.", transaction."Store No.");
        posCard.Validate("POS Terminal No.", transaction."POS Terminal No.");
        posCard.Validate("Line No.", getLine(transaction, 'payment'));
        posCard.Validate("Entry No.", getEntryNo(transaction));
        posCard.Validate("Auth.Code", authCode);
        posCard.Validate("FSN BIN No.", BIN);
        posCard.Validate("Amount", amount);
        posCard.Validate("Tender Type", '20');
        posCard.Validate("EFT Batch No.", 'STORE');
        posCard.Validate("Authorisation Ok", true);
        posCard.Insert(true);
    end;

    local procedure createCustomer(jCustomerObj: JsonObject) customer: Record "Customer";
    var
        jToken: JsonToken;
        defaultCustomer: Record "Customer";
        posFunc: Record "LSC POS Func. Profile";
    begin
        if posFunc.Get('#FASANI') then;
        if defaultCustomer.Get(posFunc."New Customer Defaults") then;
        customer.Init();
        customer := defaultCustomer;
        jCustomerObj.SelectToken('Id', jToken);
        customer.Validate("No.", jToken.AsValue().AsText());
        jCustomerObj.SelectToken('Name', jToken);
        customer.Validate(Name, jToken.AsValue().AsText());
        jCustomerObj.SelectToken('Post_code', jToken);
        customer.Validate("Post Code", jToken.AsValue().AsText());
        jCustomerObj.SelectToken('Correo', jToken);
        customer.Validate("E-Mail", jToken.AsValue().AsText());
        jCustomerObj.SelectToken('DUI', jToken);
        customer.Validate("FSN DUI", jToken.AsValue().AsText());
        jCustomerObj.SelectToken('NIT', jToken);
        customer.Validate("VAT Registration No.", jToken.AsValue().AsText());
        jCustomerObj.SelectToken('Tipo_documento', jToken);
        customer.Validate("DTE Tax ID Type", jToken.AsValue().AsInteger());
        jCustomerObj.SelectToken('Telefono', jToken);
        customer.Validate("Phone No.", jToken.AsValue().AsText());
        jCustomerObj.SelectToken('Direccion', jToken);
        customer.Validate("Address", jToken.AsValue().AsText());
        jCustomerObj.SelectToken('NRC', jToken);
        customer.Validate("FSN NRC", jToken.AsValue().AsText());
        jCustomerObj.SelectToken('Dte_activitiCode', jToken);
        customer.Validate("DTE Activity Code", jToken.AsValue().AsText());
        customer.Insert(true);
        exit(customer);
    end;

    /// <summary>
    /// createCustomerOnlife.
    /// </summary>
    /// <param name="jCustomerObj">JsonObject.</param>
    /// <param name="PosTrans">Record "LSC POS Transaction".</param>
    /// <returns>Return variable customer of type Record "Customer".</returns>
    procedure createCustomerOnlife(jCustomerObj: JsonObject; PosTrans: Record "LSC POS Transaction") customer: Record "Customer";
    var
        jToken: JsonToken;
        defaultCustomer: Record "Customer";
        posFunc: Record "LSC POS Func. Profile";
        Tipo: Integer;
    begin
        if posFunc.Get('#FASANI') then;
        if defaultCustomer.Get(posFunc."New Customer Defaults") then;

        customer.Reset();
        jCustomerObj.SelectToken('DUI', jToken);
        if not jToken.AsValue().IsNull then
            customer.SetRange("FSN DUI", jToken.AsValue().AsText());

        if not customer.FindFirst() then begin
            customer.Init();
            customer := defaultCustomer;
            jCustomerObj.SelectToken('Id', jToken);
            customer."No." := '';
        end;

        jCustomerObj.SelectToken('Name', jToken);
        if not jToken.AsValue().IsNull then
            customer.Validate(Name, jToken.AsValue().AsText());
        jCustomerObj.SelectToken('Post_code', jToken);
        if not jToken.AsValue().IsNull then
            customer.Validate("Post Code", jToken.AsValue().AsText());
        jCustomerObj.SelectToken('Correo', jToken);
        if not jToken.AsValue().IsNull then
            customer.Validate("E-Mail", jToken.AsValue().AsText());
        jCustomerObj.SelectToken('DUI', jToken);
        if not jToken.AsValue().IsNull then
            customer.Validate("FSN DUI", jToken.AsValue().AsText());
        jCustomerObj.SelectToken('NIT', jToken);
        if not jToken.AsValue().IsNull then
            customer.Validate("VAT Registration No.", jToken.AsValue().AsText());
        jCustomerObj.SelectToken('Tipo_documento', jToken);
        if not jToken.AsValue().IsNull then begin
            customer.Validate("DTE Tax ID Type", jToken.AsValue().AsInteger());
            Tipo := jToken.AsValue().AsInteger();
            addDocumentLine(PosTrans, Tipo);
        end;
        jCustomerObj.SelectToken('Telefono', jToken);
        if not jToken.AsValue().IsNull then
            customer.Validate("Phone No.", jToken.AsValue().AsText());
        jCustomerObj.SelectToken('Direccion', jToken);
        if not jToken.AsValue().IsNull then
            customer.Validate("Address", jToken.AsValue().AsText());
        jCustomerObj.SelectToken('NRC', jToken);
        if not jToken.AsValue().IsNull then
            customer.Validate("FSN NRC", jToken.AsValue().AsText());
        jCustomerObj.SelectToken('Dte_activitiCode', jToken);
        if not jToken.AsValue().IsNull then
            customer.Validate("DTE Activity Code", jToken.AsValue().AsText());
        if not customer.Insert(true) then
            customer.Modify(true);
        exit(customer);
    end;

    local procedure generateTerminalNo(terminal: Text[20]): Text[20]
    var
        prefix: Label 'PV';
    begin
        repeat
            terminal := DelStr(terminal, 1, 1);
        until terminal[1] <> '0';

        exit(prefix + '#' + terminal);
    end;

    local procedure getEntryNo(transaction: Record "LSC POS Transaction"): Integer
    var
        posCard: Record "LSC POS Card Entry";
    begin
        posCard.SetCurrentKey("Store No.", "POS Terminal No.", "Entry No.");
        posCard.SetRange("Store No.", transaction."Store No.");
        posCard.SetRange("POS Terminal No.", transaction."POS Terminal No.");
        if posCard.FindLast() then
            exit(posCard."Entry No." + 1);
    end;

    local procedure getHardwareProfile(POSTerminalNo: Code[10]): Code[10]
    var
        posTerminal: Record "LSC POS Terminal";
    begin
        if not posTerminal.Get(POSTerminalNo) then
            exit('##DEFAULT');

        exit(posTerminal."Hardware Profile");
    end;

    local procedure getLine(transaction: Record "LSC POS Transaction"; type: text): Integer
    var
        transLine: Record "LSC POS Trans. Line";
    begin
        transLine.SetCurrentKey("Receipt No.", "Line No.");
        transLine.SetRange("Receipt No.", transaction."Receipt No.");
        case type of
            'new':
                begin
                    if transLine.FindLast() then
                        exit(transLine."Line No." + 10000)
                    else
                        exit(10000);
                end;
            'payment':
                begin
                    transLine.SetRange("Entry Type", transLine."Entry Type"::Payment);
                    if transLine.FindLast() then
                        exit(transLine."Line No.");
                end;
        end;
    end;

    local procedure getTransaction(json: JsonObject): Record "LSC POS Transaction"
    var
        transaction: Record "LSC POS Transaction";
        jTransactionObj: JsonObject;
        jTransactionTkn: JsonToken;
    begin
        json.SelectToken('Store', jTransactionTkn);
        jTransactionObj := jTransactionTkn.AsObject();

        jTransactionObj.SelectToken('No', jTransactionTkn);
        transaction.SetRange("Store No.", jTransactionTkn.AsValue().AsText());

        jTransactionObj.SelectToken('Terminal', jTransactionTkn);
        transaction.SetRange("POS Terminal No.", generateTerminalNo(jTransactionTkn.AsValue().AsText()));

        json.SelectToken('TransactionNo', jTransactionTkn);
        transaction.SetRange("Receipt No.", jTransactionTkn.AsValue().AsText());

        if transaction.FindFirst() then
            exit(transaction);
    end;

    local procedure insertItems(json: JsonArray; posTrans: Record "LSC POS Transaction")
    var
        transLine: Record "LSC POS Trans. Line";
        barcode: Record "LSC Barcodes";
        jToken: JsonToken;
        jItemObj: JsonObject;
        jItemTkn: JsonToken;
        lineNo: Integer;
        value: Text;
    begin
        foreach jToken in json do begin
            barcode.Reset();
            jItemObj := jToken.AsObject();

            lineNo := getLine(posTrans, 'new');
            //? basic line data
            transLine.Init();
            transLine.Validate("Receipt No.", posTrans."Receipt No.");
            transLine.Validate("Store No.", posTrans."Store No.");
            transLine.Validate("POS Terminal No.", posTrans."POS Terminal No.");
            transLine.Validate("Line No.", lineNo);
            transLine.Validate("Parent Line", lineNo);
            transLine.Validate("Sales Staff", posTrans."Sales Staff");
            transLine.Validate("Entry Type", transLine."Entry Type"::Item);
            transLine.Validate("FSN Additional Action", transLine."FSN Additional Action"::ConfirmScann);

            //? set unit of measure code
            if not jItemObj.SelectToken('UOM', jItemTkn) then
                jItemObj.SelectToken('uom', jItemTkn);
            value := jItemTkn.AsValue().AsText();
            barcode.SetRange("Unit of Measure Code", value);
            transLine.Validate("Unit of Measure", value);

            //? set item no.
            if not jItemObj.SelectToken('Code', jItemTkn) then
                jItemObj.SelectToken('code', jItemTkn);
            value := jItemTkn.AsValue().AsText();
            barcode.SetRange("Item No.", value);

            if barcode.FindFirst() then
                transLine.validate("Barcode No.", barcode."Barcode No.");

            transLine.Validate(Number, value);

            //? set quantity

            if not jItemObj.SelectToken('Quantity', jItemTkn) then
                jItemObj.SelectToken('quantity', jItemTkn);
            transLine.Validate("Quantity", jItemTkn.AsValue().AsInteger());

            transline.Insert(true);
        end;
    end;

    local procedure sendDTE(jObject: JsonObject)
    var
        jtoken: JsonToken;
        jDTEObj: JsonObject;
        fsnUtility: Codeunit "FSN Utility";
        id: Text[20];
        request, response, msg : Text;
        menuLine: Record "LSC POS Menu Line";
        process: Boolean;
    begin
        jObject.SelectToken('DTE', jToken);
        jDTEObj := jToken.AsObject();

        jObject.SelectToken('TransactionNo', jToken);
        jDTEObj.Add('receipt', jToken);

        jObject.SelectToken('Store', jToken);
        jObject := jToken.AsObject();

        jObject.SelectToken('No', jToken);
        jDTEObj.Add('store', jToken);

        jObject.SelectToken('Terminal', jToken);
        jDTEObj.Add('terminal', generateTerminalNo(jToken.AsValue().AsText()));

        jDTEObj.WriteTo(request);
        id := 'LOAD_DTEP';
        fsnUtility.InvokeGlobalChannel(request, response, id, menuLine, process, msg);
    end;

    local procedure setCustomer(json: JsonObject; var posTrans: Record "LSC POS Transaction")
    var
        integrationType: Integer;
        customer, customer2 : Record "Customer";
        jToken: JsonToken;
        jCustomerObj: JsonObject;
        ParameterI: Record "FSN Parameter";
    begin
        json.SelectToken('Customer', jToken);
        jCustomerObj := jToken.AsObject();
        json.selectToken('Type', jToken);
        integrationType := jToken.AsValue().AsInteger();
        case integrationType of
            integration::UBER.AsInteger():
                begin
                    //TODO: set a sub customer
                    jCustomerObj.SelectToken('Name', jToken);
                    addCustomText(posTrans, jToken.AsValue().AsText());
                    if not customer.get('UBER') then
                        exit;
                end;
            integration::DTEP.AsInteger():
                begin
                    //? set a DTEP customer and set name to sub customer
                    jCustomerObj.SelectToken('Id', jToken);
                    if not customer.get(jToken.AsValue().AsText()) then
                        customer := createCustomer(jCustomerObj);
                end;
            integration::ONLIFE.AsInteger():
                begin
                    //TODO: set a sub customer
                    jCustomerObj.SelectToken('Name', jToken);
                    addCustomText(posTrans, jToken.AsValue().AsText());

                    ParameterI.Reset();
                    if ParameterI.Get('ONLIFE', 'CUST2') AND ParameterI.Activo then begin
                        customer2 := createCustomerOnlife(jCustomerObj, posTrans);

                        if integrationType = integration::ONLIFE.AsInteger() then
                            addSecundaryCustomer(posTrans, customer2);
                    end;

                    if not customer.get('PV#143C23083') then
                        exit;
                end;
        end;
        addCustomerLine(posTrans, customer, integrationType);
    end;

    local procedure setPayment(json: JsonObject)
    var
        transaction: Record "LSC POS Transaction";
        transLine: Record "LSC POS Trans. Line";
        jToken: JsonToken;
        jPaymentObj: JsonObject;
        jPaymentTkn: JsonToken;
        input: Decimal;
        authCode, BIN : Text[9];
        amount: Decimal;
        type: Integer;
    begin
        //? verify transaction type
        json.SelectToken('Type', jToken);
        if jToken.AsValue().AsInteger() = integration::UBER.AsInteger() then
            exit;

        transaction := getTransaction(json);

        json.SelectToken('Payment', jToken);
        jPaymentObj := jToken.AsObject();

        jPaymentObj.SelectToken('Type', jPaymentTkn);
        type := jPaymentTkn.AsValue().AsInteger();

        jPaymentObj.SelectToken('Amount', jPaymentTkn);
        input := jPaymentTkn.AsValue().AsDecimal();

        if type in [0, 1] then
            addPaymentLine(transaction, input, '4', 'Venta al Crédito');
        /*case type of
            0:
                begin
                    //? set cash payment
                    addPaymentLine(transaction, input, '1', 'Efectivo');
                end;
            1:
                begin
                    //? set credit card payment
                    addPaymentLine(transaction, input, '20', 'Tarjeta');

                    jPaymentObj.SelectToken('CardData', jToken);
                    jPaymentObj := jToken.AsObject();

                    jPaymentObj.SelectToken('AuthCode', jToken);
                    authCode := jToken.AsValue().AsText();

                    jPaymentObj.SelectToken('BIN', jToken);
                    BIN := jToken.AsValue().AsText();

                    addPosCard(transaction, authCode, BIN, input);
                end;

        end;*/
    end;

    local procedure setTransaction(json: JsonObject; var posTrans: Record "LSC POS Transaction")
    var
        POSSession: Codeunit "LSC POS Session";
        PosFunc: Codeunit "LSC POS Functions";
    begin
        posTrans := getTransaction(json);
        POSSession.init();
        POSSession.SetHardwareProfile(getHardwareProfile(posTrans."POS Terminal No."));
        POSSession.SetStore(posTrans."Store No.");
        POSSession.SetTerminal(posTrans."POS Terminal No.");
        POSSession.SetStaff(posTrans."Sales Staff");
        PosFunc.initPosFunctions();
        POSFunc.PosTransDiscLoadData(posTrans."Receipt No.", true);
    end;

    local procedure addSecundaryCustomer(var posTrans: Record "LSC POS Transaction"; var customer: Record Customer)
    var
        infocode: Record "LSC POS Trans. Infocode Entry";
    begin
        infocode.Init();
        infocode."Receipt No." := posTrans."Receipt No.";
        infocode."Transaction Type" := 0;
        infocode."Line No." := 40;
        infocode.Infocode := 'TEXT';
        infocode.Information := customer."No.";
        infocode."POS Terminal No." := posTrans."POS Terminal No.";
        infocode."Store No." := posTrans."Store No.";
        infocode.Date := Today();
        infocode.Time := Time();
        infocode."Staff ID" := posTrans."Staff ID";

        if not infocode.Insert(true) then
            infocode.Modify(true);
    end;

    local procedure addComments(jObject: JsonObject; posTrans: Record "LSC POS Transaction")
    var
        jToken: JsonToken;
        commentList: JsonArray;
    begin
        if not jObject.SelectToken('OrderDescription', jToken) then
            jObject.SelectToken('orderDescription', jToken);

        commentList := jToken.AsArray();

        if commentList.Count() = 0 then
            exit;

        foreach jToken in commentList do
            addCustomText(posTrans, jToken.AsValue().AsText());
    end;

    local procedure setInfoCode(json: JsonObject; posTrans: Record "LSC POS Transaction")
    var
        jToken: JsonToken;
        integrationType: Integer;
    begin
        json.selectToken('Type', jToken);
        integrationType := jToken.AsValue().AsInteger();
        case integrationType of
            integration::ONLIFE.AsInteger():
                begin
                    if json.SelectToken('OnlifeNumOrder', jToken) then
                        addInfocode(posTrans, 'Nº PEDIDO', jToken.AsValue().AsText());
                end;
        end;
    end;

    local procedure SearchReceipt()
    var
        FSNWebService: Record "FSN WebServiceTable";
    begin
        FSNWebService.Reset();
        FSNWebService.SetRange(Date, Today);
        FSNWebService.SetRange(Store, POSSESION.StoreNo());
        FSNWebService.SetRange(Terminal, POSSESION.TerminalNo());
        FSNWebService.SetRange("WS Request", 'PUNTO EXPRESS');
        FSNWebService.SetRange("Status WS", FSNWebService."Status WS"::Pending);
        if FSNWebService.FindLast() then begin

        end;
    end;

    local procedure addInfocode(posTrans: Record "LSC POS Transaction"; arg: Text; value: Text)
    var
        infocode: Record "LSC POS Trans. Infocode Entry";
    begin
        infocode.Init();
        infocode."Receipt No." := posTrans."Receipt No.";
        infocode."Transaction Type" := infocode."Transaction Type"::Header;
        infocode."Line No." := 50;
        infocode.Infocode := arg;
        infocode.Information := value;
        infocode."POS Terminal No." := posTrans."POS Terminal No.";
        infocode."Store No." := posTrans."Store No.";
        infocode.Date := Today();
        infocode.Time := Time();
        infocode."Staff ID" := posTrans."Staff ID";

        if not infocode.Insert(true) then
            infocode.Modify(true);
    end;
    #endregion

    #region [Public Procedures]
    /// <summary>
    /// setItems.
    /// this method is used to set the items to the transaction.
    /// </summary>
    /// <param name="json">JsonObject.</param>
    /// <param name="posTrans">Record "LSC POS Transaction".</param>
    procedure setItems(json: JsonObject; posTrans: Record "LSC POS Transaction")
    var
        token: JsonToken;
    begin
        if not json.Get('ProductList', token) then
            json.Get('productList', token);
        insertItems(token.AsArray(), posTrans);
    end;

    procedure DPerceReten(POSTrans: Record "LSC POS Transaction"): Boolean
    var
        myInt: Integer;
        transLine: Record "LSC POS Trans. Line";
        IncExpAccount: Record "LSC Income/Expense Account";
        filter: Text;
    begin
        filter := '18|19|20|21';

        transLine.SetRange("Store No.", POSTrans."Store No.");
        transLine.SetRange("Entry Type", transLine."Entry Type"::IncomeExpense);
        transLine.SetRange("POS Terminal No.", POSTrans."POS Terminal No.");
        transLine.SetRange("Receipt No.", POSTrans."Receipt No.");
        transLine.SetFilter(Number, filter);
        if transLine.FindFirst() then
            exit(true);
    end;
    #endregion

    #region [Subscriptions]
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnBeforeTotalExecuted', '', true, true)]
    local procedure "LSC POS Transaction Events_OnBeforeTotalExecuted"
    (
     var POSTransaction: Record "LSC POS Transaction";
     var IsHandled: Boolean
    )
    var
        posTransCode: Codeunit "LSC POS Transaction";
        WSTable: Record "FSN WebServiceTable";
    begin
        if POSTransaction."FSN Sub Type" = SUB_TYPE then begin
            posTransCode.SelectCustPressed(POSTransaction."Customer No.");
            if POSTransaction."Customer No." = '' then begin
                IsHandled := true;
            end;
        end;
    end;
    #endregion

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnAfterCalcTotals', '', true, true)]
    local procedure "LSC POS Transaction Events_OnAfterCalcTotals"
    (
        var Rec: Record "LSC POS Transaction";
        var Balance: Decimal;
        var RealBalance: Decimal
    )
    var
        NAmount, Porcentaje : Decimal;
        posTransCode: Codeunit "LSC POS Transaction";
        parame: Record "FSN Parameter";
        postransL: Record "LSC POS Trans. Line";
    begin

        Porcentaje := Rec."Gross Amount" * 0.10;

        if Rec."FSN Sub Type" = SUB_TYPE then
            if (Balance <> 0) and (Porcentaje > Balance) then begin
                postransL.Reset();
                postransL.SetRange("Receipt No.", Rec."Receipt No.");
                postransL.SetRange("Entry Type", postransL."Entry Type"::Payment);
                postransL.SetRange("Entry Status", postransL."Entry Status"::" ");
                if postransL.FindFirst() then begin
                    if (Balance > -0.05) and (Balance < 0.05) then begin
                        NAmount := Balance + postransL.Amount;
                        postransL.Amount := NAmount;
                        postransL.Modify(true);
                        Commit();
                    end;
                end;
            end;
    end;

    local procedure ValidatePrBC(PosTransac: Record "LSC POS Transaction"): Boolean
    var
        FSNWebService: Record "FSN WebServiceTable";
    begin
        if FSNWebService.Get(PosTransac."Receipt No.") then begin
            if FSNWebService."WS Request" = 'SEND_POSTRANS_BACKUP_BC' then begin
                exit(true);
            end;
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Controller", 'OnButtonPressed', '', true, true)]
    local procedure "LSC POS Controller_OnButtonPressed"
    (
        var POSMenuLine: Record "LSC POS Menu Line";
        var handled: Boolean
    )
    var
        POSGUI: Codeunit "LSC POS GUI";
        FSNWebService: Record "FSN WebServiceTable";
        FSNWebServiceTemp: Record "FSN WebServiceTable" temporary;
        eposInterface: Codeunit "LSC POS Control Interface";
        RecRefTMP: RecordRef;
        POSTransaction: Codeunit "LSC POS Transaction";
        POSTrans: Record "LSC POS Transaction";
        POSTransTemp: Record "LSC POS Transaction" temporary;
        EPosCtrl: Codeunit "LSC POS Control Interface";
        Recibo: Code[20];
        userRetail: Record "LSC Retail User";
        terminal: Record "LSC POS Terminal";
        explorer: Record "LSC POS Browser Control";
        transLine: Record "LSC POS Trans. Line";
        LastSlipNo, RC : Code[20];
        Store: Text;
        TEXT005: Label 'Debe agregar un Cliente para la transacción de PUNTOXPRESS';
        POSTransactionFunctions: Codeunit "LSC POS Transaction Functions";
    begin
        if (POSMenuLine.Command = 'IMPRIMIR') then begin//100781
            if POSTrans.Get(POSTransaction.GetReceiptNo()) AND (POSTrans."FSN Document Type" = POSTrans."FSN Document Type"::Ticket) then begin
                if ValDES(POSTrans) then begin
                    Store := POSTrans."Store No.";
                    POSTransaction.SetCurrInput(Store);
                    POSTransaction.ProcessSalesPerson;
                    POSTransaction.SetPOSState('PAYMENT');
                    TOTALRUN(POSTrans);
                    RegTransacc(POSTrans);
                end;
            end;
        end;

        if POSMenuLine.Command = 'RECETAS' then begin
            POSGUI.OpenAlphabeticKeyboard('N° Receta:', '', false, 'INTEGRACION', 250);
        end;

        IF POSMenuLine.Command = 'PUNTOEXPRESS' then begin
            if POSTrans.Get(POSTransaction.GetReceiptNo()) then begin
                if POSTrans."Customer No." = '' then begin
                    Message(TEXT005);
                    exit;
                end;
                Store := POSTrans."Store No.";
                POSTransaction.SetCurrInput(Store);
                POSTransaction.ProcessSalesPerson;
                if ((not ValidatePrBC(POSTrans)) and (not ValdtItem(POSTrans)) and not (DPerceReten(POSTrans))) then begin
                    PseudoMeth.AutentificationPuntoExpress();
                    if UserId = '' then
                        exit;
                    if not userRetail.Get(UserId) then
                        exit;
                    if not terminal.Get(userRetail."POS Terminal") then
                        exit;
                    if not explorer.Get(terminal."Menu Profile", '#POSPUNTOEX') then
                        exit;
                    POSSESION.SetValue('RECPEX', POSTrans."Receipt No.");
                    EPosCtrl.ShowPanel('#PUNTOEXPRESS');
                    EPosCtrl.RefreshPosPanel(explorer."Interface Profile ID", '#PUNTOEXPRESS', terminal."Menu Profile");
                end else
                    Message(Tex0016);
            end;
        end;

        if POSMenuLine.Command = 'VALPROCESSPEX' then begin
            if POSTrans.Get(POSSESION.GetValue('RECPEX')) then begin
                if FSNWebService.Get(POSTrans."Receipt No.") then
                    if PseudoMeth.ValProcess(POSTrans, FSNWebService) then;

            end;
        end;

        IF POSMenuLine.Command = 'DPEXPRESS' then begin
            if POSTrans.Get(POSSESION.GetValue('RECPEX')) then begin
                if FSNWebService.Get(POSTrans."Receipt No.") then;
                PseudoMeth.DescargaPuntoExpress(POSTrans, FSNWebService);
            end;
        end;

        IF POSMenuLine.Command = 'PUNTOEXPRESSDOW' then begin
            if POSTrans.Get(POSTransaction.GetReceiptNo()) then begin
                if (not ValdtItem(POSTrans)) and not (DPerceReten(POSTrans)) then begin
                    FSNWebService.Reset();
                    FSNWebService.SetRange(Store, POSSESION.StoreNo());
                    FSNWebService.SetRange(Terminal, POSSESION.TerminalNo());
                    FSNWebService.SetRange("WS Request", 'PUNTO EXPRESS');
                    FSNWebService.SetRange("Status WS", FSNWebService."Status WS"::Send);
                    if FSNWebService.Find('-') then begin
                        repeat
                            FSNWebServiceTemp := FSNWebService;
                            FSNWebServiceTemp.Insert();
                        until FSNWebService.Next() = 0;
                    end;
                    Commit();
                    RecRefTmp.GETTABLE(FSNWebServiceTemp);
                    POSTransaction.LookUpEx(true, 'INFO_PPEX', '', RecRefTmp);
                end else
                    Message(Tex0016);
            end;
        end;

        IF (POSMenuLine.Command = 'CANCEL') AND (POSMenuLine."Post Command" = 'PXCANCEL') THEN begin
            If POSTrans.Get(POSTransaction.GetReceiptNo()) then begin
                if FSNWebService.Get(POSTrans."Receipt No.") then
                    if PseudoMeth.ValProcess(POSTrans, FSNWebService) then;
            end;
        end;
        //PROCESO PARA ANULACION DE PUNTO EXPRESS
        //HABILITAR EN CASO DE SOLICITARLO
        //16012000
        /*  IF POSMenuLine.Command = 'PUNTOEXPRESSVOID' THEN begin
            FSNWebService.Reset();
            FSNWebService.SetRange("Status WS", FSNWebService."Status WS"::Send);
            FSNWebService.SetRange(Date, Today);
            FSNWebService.SetRange(Store, POSSESION.StoreNo());
            FSNWebService.SetRange(Terminal, POSSESION.TerminalNo());
            FSNWebService.SetRange("WS Request", 'PUNTO EXPRESS');
            if FSNWebService.Find('-') then begin
                FSNWebServiceTemp := FSNWebService;
                FSNWebServiceTemp.Insert();
            end;
            Commit();
            RecRefTmp.GETTABLE(FSNWebServiceTemp);
            POSTransaction.LookUpEx(true, 'INFO_PPEXVOID', '', RecRefTmp);
            END;*/
    end;

    local procedure ValidateDocumentType(Doc: Text) ResultDoc: Text
    var
    begin
        POSSession.SetValue('DocTrans', FORMAT(Doc));
        ResultDoc := Doc;
    end;


    local procedure ChangeSubtype(POSTransaction: Record "LSC POS Transaction")
    var
        myInt: Integer;
        FsnWeb: Record "FSN WebServiceTable";
        PosTrans: Record "LSC POS Transaction";
    begin
        if PosTrans.Get(POSTransaction."Receipt No.") then begin
            PosTrans."FSN Sub Type" := '';
            PosTrans.Modify(true);
            Commit();
        end;
    end;

    procedure ValdtItem(POSTrans: Record "LSC POS Transaction"): Boolean
    var
        myInt: Integer;
        transLine: Record "LSC POS Trans. Line";
    begin
        transLine.SetRange("Store No.", POSTrans."Store No.");
        transLine.SetRange("POS Terminal No.", POSTrans."POS Terminal No.");
        transLine.SetRange("Receipt No.", POSTrans."Receipt No.");
        transLine.SetRange("Entry Type", transLine."Entry Type"::Item);
        IF transLine.FindFirst() then
            exit(true);
    end;

    procedure ValDES(POSTrans: Record "LSC POS Transaction"): Boolean
    var
        myInt: Integer;
        transLine: Record "LSC POS Trans. Line";
    begin
        transLine.SetRange("Store No.", POSTrans."Store No.");
        transLine.SetRange("POS Terminal No.", POSTrans."POS Terminal No.");
        transLine.SetRange("Receipt No.", POSTrans."Receipt No.");
        transLine.SetRange("Entry Status", transLine."Entry Status"::" ");
        transLine.SetRange("Entry Type", transLine."Entry Type"::IncomeExpense);
        IF transLine.FindFirst() then
            exit(true);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnBeforeInsertItemLine', '', true, true)]
    local procedure "LSC POS Transaction Events_OnBeforeInsertItemLine"
    (
        var POSTransaction: Record "LSC POS Transaction";
        var POSTransLine: Record "LSC POS Trans. Line";
        var CurrInput: Text
    )
    var
        PosTransLine2: Record "LSC POS Trans. Line";//15837
        WSTable: Record "FSN WebServiceTable";
    begin
        if (POSTransaction."FSN Sub Type" = SUB_TYPE) then begin
            if WSTable.Get(POSTransaction."Receipt No.") then;
            PosTransLine2.Reset();
            PosTransLine2.SetRange("Receipt No.", POSTransaction."Receipt No.");
            PosTransLine2.SetRange("Entry Status", PosTransLine2."Entry Status"::" ");
            PosTransLine2.SetRange("Entry Type", PosTransLine2."Entry Type"::IncomeExpense);
            if (PosTransLine2.Find('-')) or not (PseudoMeth.ValProcess(POSTransaction, WSTable)) then begin
                Error(Tex0001);
                exit;
            end;
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Controller", 'OnLookupResult', '', true, true)]
    local procedure "LSC POS Controller_OnLookupResult"
    (
        LookupID: Text;
        FilterText: Text;
        resultOK: Boolean;
        var processed: Boolean
    )
    var
        EPosCtrl: Codeunit "LSC POS Control Interface";
        Recibo: CODE[20];
        TransHeader: Record "lsc transaction header";
        POSTransTemp: Record "LSC POS Transaction" temporary;
        FSNWebService: Record "FSN WebServiceTable";
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line" Temporary;
        FSNUtility: Codeunit "FSN Utility";
        MsgResult: Text;
    begin
        IF LookupID in ['INFO_PPEX', 'INFO_PEX'] then begin
            IF EPosCtrl.GetLookupKeyValue(LookupID) <> '' then begin
                Recibo := EPosCtrl.GetLookupKeyValue(LookupID);
                IF FSNWebService.Get(Recibo) THEN begin
                    TransHeader.Reset();
                    TransHeader.SetRange("Receipt No.", FSNWebService."Order No.");
                    if TransHeader.FindFirst() then begin
                        RequestID := 'PRINTCOPY';//manda a DAF
                        XMLRequest := TransHeader."Receipt No.";
                        FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
                    end;
                end;
            end;
        end;

        //PROCESO PARA ANULACION DE PUNTO EXPRESS
        //HABILITAR EN CASO DE SOLICITARLO
        //16012000
        /*IF LookupID in ['INFO_PPEXVOID'] then begin
            IF EPosCtrl.GetLookupKeyValue(LookupID) <> '' then begin
                Recibo := EPosCtrl.GetLookupKeyValue(LookupID);
                if POSTrans.Get(POSTransaction.GetReceiptNo()) then begin
                    if FSNWebService.Get(Recibo) then;
                    PseudoMeth.VoidPuntoExpress(POSTrans, FSNWebService);
                end;
            end;
        end;*/
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Controller", 'OnKeyboardResult', '', true, true)]
    local procedure "EPOS Controler_OnKeyboardResult"
   (
       payload: Text;
       inputValue: Text;
       resultOK: Boolean;
       var processed: Boolean
   )
    var

        company: Enum "FSN Integrations";
        Postrans: Codeunit "LSC POS Transaction";
        POSTransac: Record "LSC POS Transaction";
    begin
        if resultOK then
            if (payload = 'INTEGRACION') and (inputValue <> '') then begin
                if POSTransac.Get(Postrans.GetReceiptNo()) then
                    addInfocode(POSTransac, 'MEDICPRO', inputValue);
                PseudoMeth.loadRecipesProducts(inputValue, company::MEDICPRO);
            end else begin
                if (payload = 'INTEGRACION') then
                    Message('Debe ingresar un N° de Receta');
            end;
        processed := true;
    end;
}
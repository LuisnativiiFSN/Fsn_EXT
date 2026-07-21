/// <summary>
/// Codeunit Pseudo Obeserver Methods (ID 50055).
/// </summary>
codeunit 50056 "Pseudo Obeserver Methods"
{
    TableNo = "LSC Scheduler Job Header";

    trigger OnRun()
    begin
        case Rec.Code of
            'PRINT_NEW_ORDERS':
                checkNewOrder(Rec.Description);
        end;
    end;

    var
        fsnParameter: Record "FSN Parameter";
        "Status WS": Option None,Pending,Send,InProcess,Transfered;
        POSSESSION: Codeunit "LSC POS Session";

    #region [Task Methods]
    /// <summary>
    /// checkNewOrder.
    /// Este metodo se encarga de evaluar si se han creado nuevos pedidos y los envia a la cola de impresion.
    /// </summary>
    /// <param name="integrationType">Text.</param>
    procedure checkNewOrder(integrationType: Text)
    var
        ordersList: List of [Text];
        orderMessage: Text;
    begin
        if integrationType = 'UberEatsOrder' then
            ordersList := getOrdersList(integrationType)
        else
            ordersList := getOrdersListOn(integrationType);

        if ordersList.Count = 0 then
            exit;
        //TODO: Enviar a cola de impresion
        foreach orderMessage in ordersList do begin
            printAndConfirmOrder(orderMessage);
        end;
    end;
    #endregion

    #region [Utility Methods]
    /// <summary>
    /// loadRecipesProducts.
    /// this method is used to load the products of a recipe.
    /// </summary>
    /// <param name="recipe">Text.</param>
    /// <param name="integration">Enum "FSN Integrations".</param>
    /// <returns>Boolean.</returns>
    procedure loadRecipesProducts(recipe: Text; integration: Enum "FSN Integrations"): Boolean
    var
        integrationMethods: Codeunit "FSN Integrations Methods";
        userRetail: Record "LSC Retail User";
        terminal: Record "LSC POS Terminal";
        explorer: Record "LSC POS Browser Control";
        posTrans_codeunit: Codeunit "LSC POS Transaction";
        posTrans: Record "LSC POS Transaction";
        uri: Text;
        model, response : JsonObject;
        token: JsonToken;
        JsCustomer: JsonObject;
        Dui: Text;
    begin
        model := getJsonOfIntegration(integration);
        //TODO: solicitar los datos de la receta
        if UserId = '' then
            Error('No se ha podido obtener el usuario');

        if not userRetail.Get(UserId) then
            Error('No se ha podido obtener el usuario');

        if not terminal.Get(userRetail."POS Terminal") then
            Error('No se ha podido obtener el terminal');

        if not explorer.Get(terminal."Menu Profile", '#POSHTML') then
            Error('No se ha podido obtener el explorador');

        if not model.SelectToken('uri', token) then
            Error('No se ha podido obtener la uri');

        uri := token.AsValue().AsText();
        uri := explorer.URL + StrSubstNo(uri, recipe);

        if not model.SelectToken('method', token) then
            Error('No se ha podido obtener el metodo');

        response := apiRequest(uri, token.AsValue().AsText());

        if not response.SelectToken('status', token) or (token.AsValue().AsInteger() <> 200) then
            Error('No se ha podido obtener los datos');

        if not response.SelectToken('body', token) then
            Error('No se ha podido obtener los datos');

        response.ReadFrom(token.AsValue().AsText());

        if not response.SelectToken('result', token) then
            Error('No se ha podido obtener los datos');

        response := token.AsObject();

        if response.SelectToken('type', token) then begin
            if token.AsValue().AsInteger() <> integration.AsInteger() then
                Error('EL pedido no coincide con el dato solicitado');
        end else
            Error('No se ha podido obtener los datos');

        if not posTrans.Get(posTrans_codeunit.GetReceiptNo()) then
            Error('No se ha podido obtener la transaccion');

        integrationMethods.setItems(response, posTrans);

        if response.SelectToken('customer', token) then begin
            response := token.AsObject();

            if response.SelectToken('dui', token) then begin
                if not token.AsValue().IsNull then
                    Dui := DelChr(DelChr(token.AsValue().AsText(), '=', '_'), '=', '-');

                if Dui <> '' then begin
                    Dui := CopyStr(Dui, 1, 8) + '-' + CopyStr(Dui, 9);
                    InsertCustmerVip(Dui);
                end;
            end;
        end;

        exit(true);
    end;

    /// <summary>
    /// InsertCustmerVip.
    /// </summary>
    /// <param name="DUI">Text.</param>
    procedure InsertCustmerVip(DUI: Text)
    var
        MemberAcc: Record "LSC Member Account";
        MemberShip: Record "LSC Membership Card";
        POSTransCodeunit: Codeunit "LSC POS Transaction";
        Customer: Record Customer;
    begin
        Customer.Reset();
        Customer.SetRange("FSN DUI", DUI);
        if Customer.FindFirst() then begin
            MemberAcc.Reset();
            MemberAcc.SetRange("Linked To Customer No.", Customer."No.");
            if MemberAcc.FindFirst() then begin
                MemberShip.Reset();
                MemberShip.SetRange("Account No.", MemberAcc."No.");
                MemberShip.SetFilter("Last Valid Date", '>=%1', Today);
                if MemberShip.Find('+') then
                    POSTransCodeunit.InputMemberCard(MemberShip."Card No.")
                else
                    POSTransCodeunit.SelectCustPressed(MemberAcc."Linked To Customer No.");
            end else
                POSTransCodeunit.SelectCustPressed(Customer."No.");
        end;
    end;

    local procedure getOrdersList(IntegrationType: Text): List of [Text]
    var
        list: List of [Text];
        uri, uid, name : Text;
        userRetail: Record "LSC Retail User";
        terminal: Record "LSC POS Terminal";
        explorer: Record "LSC POS Browser Control";
        response, jObject : JsonObject;
        jToken, auxToken : JsonToken;
        jArray: JsonArray;
    begin
        if UserId = '' then
            exit(list);

        if not userRetail.Get(UserId) then
            exit(list);

        if not terminal.Get(userRetail."POS Terminal") then
            exit(list);

        if not explorer.Get(terminal."Menu Profile", '#POSHTML') then
            exit(list);

        uri := explorer.URL + StrSubstNo('%1/GetOrdersNews?idUberStore=%2', IntegrationType, terminal."Store No.");

        response := apiRequest(uri, 'GET');

        if not response.SelectToken('status', jToken) or (jToken.AsValue().AsInteger() <> 200) then
            exit(list);

        if not response.SelectToken('body', jToken) then
            exit(list);

        jArray.ReadFrom(jToken.AsValue().AsText());

        if jArray.Count = 0 then
            exit(list);

        foreach auxToken in jArray do begin
            jObject := auxToken.AsObject();
            jObject.SelectToken('orderId', jToken);
            uid := jToken.AsValue().AsText();
            jObject.SelectToken('customerName', jToken);
            name := jToken.AsValue().AsText();
            list.Add(StrSubstNo('%1||%2||%3', IntegrationType, uid, name));
        end;

        exit(list);
    end;

    /// <summary>
    /// getOrdersListOn.
    /// </summary>
    /// <param name="IntegrationType">Text.</param>
    /// <returns>Return value of type List of [Text].</returns>
    procedure getOrdersListOn(IntegrationType: Text): List of [Text]
    var
        list: List of [Text];
        uri, uid, name, description : Text;
        userRetail: Record "LSC Retail User";
        terminal: Record "LSC POS Terminal";
        explorer: Record "LSC POS Browser Control";
        response, jObject : JsonObject;
        JObjectO: DotNet JObject;
        jToken, jToken2, auxToken, DJosn : JsonToken;
        jArray: JsonArray;
        Parameter: Record "FSN Parameter";
        ODATACnn: Codeunit "FSN OData Conexion";
        Resp, cantidad : Text;
    begin
        if UserId = '' then
            exit(list);

        if not userRetail.Get(UserId) then
            exit(list);

        if not terminal.Get(userRetail."POS Terminal") then
            exit(list);

        if Parameter.Get('INTEGRACION', 'ONLIFE') then begin

            uri := Parameter."Web Uri" + StrSubstNo('%1/GetOrderDetailsNotPrint/%2', IntegrationType, terminal."Store No.");

            response := apiRequest(uri, 'GET');

            if not response.SelectToken('status', jToken) or (jToken.AsValue().AsInteger() <> 200) then
                exit(list);

            if not response.SelectToken('body', jToken) then
                exit(list);

            jArray.ReadFrom(jToken.AsValue().AsText());

            if jArray.Count = 0 then
                exit(list);

            foreach auxToken in jArray do begin
                jObject := auxToken.AsObject();
                jObject.SelectToken('id', jToken);
                uid := jToken.AsValue().AsText();
                jObject.SelectToken('clientName', jToken);
                name := jToken.AsValue().AsText();
                jObject.SelectToken('orderDetails', jToken);
                jArray := jToken.AsArray();
                foreach DJosn in jArray do begin
                    jObject := DJosn.AsObject();
                    jObject.SelectToken('quantity', jToken);
                    cantidad := jToken.AsValue().AsText();
                    jObject.SelectToken('description', jToken);
                    description += CopyStr(cantidad + ' ' + jToken.AsValue().AsText() + '               ', 1, 35);
                end;
                list.Add(StrSubstNo('%1||%2||%3||%4', IntegrationType, uid, name, description));
                description := '';
            end;
        end;
        exit(list);
    end;

    local procedure getApp(integrationType: Text): Text
    begin
        case integrationType of
            'UberEatsOrder':
                exit('UBER EATS');
            'Onlife':
                exit('ONLIFE');
            else
                exit('');
        end;
    end;

    local procedure printAndConfirmOrder(OrderMessage: Text)
    var
        posFunc: CodeUnit "LSC POS Functions";
        printer: Codeunit "LSC POS Print Utility";
        posTrans: Record "LSC POS Transaction";
        nodes: List of [Text];
        Value: array[10] of Text[250];
        dstr: Text;
        Servicio: Text;
        xToInt, xInt : Integer;
        xNewText: Text[50];
        xFreeText: Text;
        DSTR1: Text[80];
    begin
        posTrans.FindLast();
        printer.OpenReceiptPrinter(2, 'PR', '', 0, posTrans."Receipt No.");
        nodes := OrderMessage.Split('||');
        printer.PrintLine(2, '');
        dstr := StrSubstNo('Pedido de %1', nodes.Get(3));
        printer.PrintLine(2, printer.FormatLine(dstr, true, true, false, false));
        printer.PrintLine(2, '');
        dstr := StrSubstNo('App: %1', getApp(nodes.Get(1)));
        printer.PrintLine(2, printer.FormatLine(dstr, false, true, false, false));
        dstr := StrSubstNo('Orden: %1', nodes.Get(2));
        printer.PrintLine(2, printer.FormatLine(dstr, false, true, false, false));
        if getApp(nodes.Get(1)) = 'ONLIFE' then begin
            printer.PrintLine(2, '');
            printer.PrintLine(2, 'Descripcion:');
            xFreeText := StrSubstNo(nodes.Get(4));
            DSTR1 := '#L######################################';
            xToInt := (STRLEN(xFreeText) DIV 35) + 1;
            FOR xInt := 1 TO xToInt DO BEGIN
                xNewText := COPYSTR(xFreeText, 1, 35);
                Value[1] := xNewText;
                IF xInt > 1 THEN
                    Value[1] := xNewText;
                printer.PrintLine(2, printer.FormatLine(printer.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                xFreeText := COPYSTR(xFreeText, 36);
            END;
        end;

        printer.PrintLine(2, '');
        printer.PrintLine(2, 'revisar la pagina de pedidos');
        printer.PrintLine(2, 'para confirmar el pedido');
        printer.PrintSeperator(2);
        printer.ClosePrinter(2);
        Servicio := getApp(nodes.Get(1));
        if Servicio = 'ONLIFE' then
            confirmPrintedOrderOn(nodes.Get(1), nodes.Get(2))
        else
            confirmPrintedOrder(nodes.Get(1), nodes.Get(2));
    end;

    local procedure confirmPrintedOrderOn(integrationType: Text; orderId: Text)
    var
        uri: Text;
        userRetail: Record "LSC Retail User";
        terminal: Record "LSC POS Terminal";
        explorer: Record "LSC POS Browser Control";
        Parameter: Record "FSN Parameter";
    begin
        if UserId = '' then
            exit;

        if not userRetail.Get(UserId) then
            exit;

        if not terminal.Get(userRetail."POS Terminal") then
            exit;

        if Parameter.Get('INTEGRACION', 'ONLIFE') then begin

            uri := Parameter."Web Uri" + StrSubstNo('%1/UpdatePrintTicket/%2', integrationType, orderId);

            apiRequest(uri, 'PUT');
        end;
    end;

    local procedure confirmPrintedOrder(integrationType: Text; orderId: Text)
    var
        uri: Text;
        userRetail: Record "LSC Retail User";
        terminal: Record "LSC POS Terminal";
        explorer: Record "LSC POS Browser Control";
    begin
        if UserId = '' then
            exit;

        if not userRetail.Get(UserId) then
            exit;

        if not terminal.Get(userRetail."POS Terminal") then
            exit;

        if not explorer.Get(terminal."Menu Profile", '#POSHTML') then
            exit;

        uri := explorer.URL + StrSubstNo('%1/PrintedOrder?idOrderUberEats=%2&IsPrinted=true', integrationType, orderId);

        apiRequest(uri, 'PUT');
    end;

    local procedure getparam(arg: Text): Boolean
    var
        param: Record "FSN Parameter";
    begin
        if param.Get('INTEGRACION', arg) then;

        exit(param.Activo);
    end;

    local procedure getJsonOfIntegration(integration: Enum "FSN Integrations"): JsonObject
    var
        json: JsonObject;
    begin
        case integration of
            integration::MEDICPRO:
                begin
                    json.Add('uri', 'MedicPro/GetDataBC?MedicProNumOrder=%1');
                    json.Add('method', 'GET');
                    exit(json);
                end;
        end;
    end;

    //PROCESO PARA ANULACION DE PUNTO EXPRESS
    //HABILITAR EN CASO DE SOLICITARLO
    //16012000
    /*procedure VoidPuntoExpress(PosTransa: Record "LSC POS Transaction"; FSNWeb: Record "FSN WebServiceTable")
    var
        myInt: Integer;
        requestHeader, contentHeader : HttpHeaders;
        request: HttpRequestMessage;
        body: HttpContent;
        json: JsonObject;
        content, token : Text;
        response, jObject : JsonObject;
        uri: Text;
        jToken: JsonToken;

    begin
        if not getParamsMaster() then
            exit;
        //uri := fsnParameter."Web Uri" + 'api/CollectorPayment/NullifyTransaction?idTransaccion=12123343434';
        uri := fsnParameter."Web Uri" + 'api/CollectorPayment/NullifyTransaction?idTransaccion=%1';


        uri := StrSubstNo(uri, DelChr(FSNWeb.LastSlipNo, '=', '#'));


        request.GetHeaders(requestHeader);
        requestHeader.Clear();
        token := getCredentials(PosTransa);
        requestheader.Add('Authorization', 'Bearer ' + token);
        token := getCredentials(PosTransa);


        response := PostAnulacion(uri, request);//16012000

        if not response.SelectToken('status', jToken) or (jToken.AsValue().AsInteger() <> 200) then
            exit;
        LogIntegration('PUNTO EXPRESS', FSNWeb.LastSlipNo, PosTransa."Receipt No.", "Status WS"::None, PosTransa.Payment);
        addLine(PosTransa, 'ANULACION PUNTO EXPRESS');

    end;*/

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
        if not transLine.FindFirst() then
            exit(true);
    end;

    procedure ValProcess(PosTransa: Record "LSC POS Transaction"; FSNwEB: Record "FSN WebServiceTable"): Boolean
    var
        requestHeader, contentHeader : HttpHeaders;
        request: HttpRequestMessage;
        body: HttpContent;
        json: JsonObject;
        content, token : Text;
        uri: Text;
        response, jObject : JsonObject;
        isEnabled: Boolean;
        jToken: JsonToken;
        PaymentAmount: Decimal;
        TMovimiento: Integer;
        TServicio: Integer;
        ReciboPEx: Code[20];
        Autorizacion, serviceName : Text;
        ErroTerminal: Label 'Se debe de descargar en %1';
    begin
        if not getParamsMaster() then
            exit;
        uri := fsnParameter."Web Uri" + 'api/CollectorPayment/DownloadOrder';
        Body.GetHeaders(contentHeader);
        contentHeader.Clear();

        json.Add('transaction', DelChr(FSNwEB.LastSlipNo, '=', '#'));
        //json.Add('store', 'F30');
        json.Add('store', PosTransa."Store No.");
        json.Add('sellingPoint', DelChr(FSNwEB.Terminal, '=', '#'));

        json.WriteTo(content);
        body.WriteFrom(content);

        Body.GetHeaders(contentHeader);
        contentHeader.Clear();
        contentHeader.Add('Content-Type', 'application/json');

        request.GetHeaders(requestHeader);
        requestHeader.Clear();
        request.Content := body;

        token := getCredentials(PosTransa);
        requestheader.Add('Authorization', 'Bearer ' + token);

        response := Post(uri, request);//16012000

        if response.SelectToken('status', jToken) AND (jToken.AsValue().AsInteger() <> 200) then begin
            exit(true);
        end;
    end;

    procedure ActualizacionPuntoXpress(PosTransa: Record "LSC POS Transaction"; FSNwEB: Record "FSN WebServiceTable")
    var
        requestHeader, contentHeader : HttpHeaders;
        request: HttpRequestMessage;
        body: HttpContent;
        json: JsonObject;
        content, token : Text;
        uri: Text;
        response, jObject : JsonObject;
        isEnabled: Boolean;
        jToken: JsonToken;
        PaymentAmount: Decimal;
        TMovimiento: Integer;
        TServicio: Integer;
        ReciboPEx: Code[20];
        Autorizacion, serviceName : Text;
    begin
        if not getParamsMaster() then
            exit;
        uri := fsnParameter."Web Uri" + 'api/CollectorPayment/UpdateRegisteredBC';
        Body.GetHeaders(contentHeader);
        contentHeader.Clear();

        json.Add('transaction', DelChr(FSNwEB.LastSlipNo, '=', '#'));
        json.Add('store', PosTransa."Store No.");
        json.Add('sellingPoint', DelChr(FSNwEB.Terminal, '=', '#'));
        json.Add('ipStore', IpAddres(PosTransa));

        json.WriteTo(content);
        body.WriteFrom(content);

        Body.GetHeaders(contentHeader);
        contentHeader.Clear();
        contentHeader.Add('Content-Type', 'application/json');

        request.GetHeaders(requestHeader);
        requestHeader.Clear();
        request.Content := body;

        token := getCredentials(PosTransa);
        requestheader.Add('Authorization', 'Bearer ' + token);

        response := Post(uri, request);//16012000
    end;

    procedure DescargaPuntoExpress(PosTransa: Record "LSC POS Transaction"; FSNwEB: Record "FSN WebServiceTable")
    var
        requestHeader, contentHeader : HttpHeaders;
        request: HttpRequestMessage;
        body: HttpContent;
        json: JsonObject;
        content, token : Text;
        uri: Text;
        response, jObject : JsonObject;
        isEnabled: Boolean;
        jToken: JsonToken;
        PaymentAmount: Decimal;
        TMovimiento: Integer;
        TServicio: Integer;
        ReciboPEx: Code[20];
        Autorizacion, serviceName : Text;
        ErroTerminal: Label 'Se debe de descargar en %1';
    begin
        if not getParamsMaster() then
            exit;
        uri := fsnParameter."Web Uri" + 'api/CollectorPayment/DownloadOrder';
        Body.GetHeaders(contentHeader);
        contentHeader.Clear();

        json.Add('transaction', DelChr(FSNwEB.LastSlipNo, '=', '#'));
        json.Add('store', PosTransa."Store No.");
        json.Add('sellingPoint', DelChr(FSNwEB.Terminal, '=', '#'));

        //json.Add('transaction', '0000PV375000020034');
        //json.Add('store', 'F52');
        //json.Add('sellingPoint', 'PV375');

        json.WriteTo(content);
        body.WriteFrom(content);


        Body.GetHeaders(contentHeader);
        contentHeader.Clear();
        contentHeader.Add('Content-Type', 'application/json');

        request.GetHeaders(requestHeader);
        requestHeader.Clear();
        request.Content := body;

        token := getCredentials(PosTransa);
        requestheader.Add('Authorization', 'Bearer ' + token);

        response := Post(uri, request);//16012000

        if not response.SelectToken('status', jToken) or (jToken.AsValue().AsInteger() <> 200) then begin
            LogIntegration('PUNTO EXPRESS', FSNWeb.LastSlipNo, PosTransa."Receipt No.", "Status WS"::None, PosTransa.Payment, '', '');
            exit;
        end;


        if not response.SelectToken('body', jToken) then
            exit;

        jObject := jToken.AsObject();
        /* if jObject.SelectToken('storeNo', jToken) then
             if not jToken.AsValue().IsNull then
                 if not (PosTransa."Store No." = jToken.AsValue().AsText()) then
                     exit;

        if jObject.SelectToken('terminal', jToken) then
            if not jToken.AsValue().IsNull then
                if not (DelChr(PosTransa."POS Terminal No.", '=', '#') = jToken.AsValue().AsText()) then
                    Error(StrSubstNo(ErroTerminal, jToken.AsValue().AsText()));*/

        if jObject.SelectToken('transactionNo', jToken) then
            if not jToken.AsValue().IsNull then
                ReciboPEx := jToken.AsValue().AsText();
        //if not (DelChr(PosTransa."Receipt No.", '=', '#') = jToken.AsValue().AsText()) then     

        if jObject.SelectToken('typeService', jToken) then
            if not jToken.AsValue().IsNull then
                TServicio := jToken.AsValue().AsChar();

        if jObject.SelectToken('typeMovement', jToken) then
            if not jToken.AsValue().IsNull then
                TMovimiento := jToken.AsValue().AsChar();

        if jObject.SelectToken('amount', jToken) then
            if not jToken.AsValue().IsNull then
                PaymentAmount := jToken.AsValue().AsDecimal();

        if jObject.SelectToken('authorization', jToken) then
            if not jToken.AsValue().IsNull then begin
                //GUARDAR EN UN INFOCODIGO
                Autorizacion := jToken.AsValue().AsText();
                //addInfocode(PosTransa, 'PUNTOEXPRESS',);
                addLine(PosTransa, 'Autorizacion: ' + Autorizacion);
            end;

        if jObject.SelectToken('serviceCode', jToken) then
            if not jToken.AsValue().IsNull then begin
                //GUARDAR EN UN INFOCODIGO

                addLine(PosTransa, jToken.AsValue().AsText());
            end;

        if jObject.SelectToken('serviceName', jToken) then
            if not jToken.AsValue().IsNull then begin
                //GUARDAR EN UN INFOCODIGO
                serviceName := jToken.AsValue().AsText();
                addLine(PosTransa, 'Servicio: ' + serviceName);
            end;


        if jObject.SelectToken('authService', jToken) then
            if not jToken.AsValue().IsNull then;

        addInfocode(PosTransa, 'PUNTOEXPRESS', serviceName + ' ' + Autorizacion, 52);
        InsertIncExpLine(PosTransa, PaymentAmount, TMovimiento, TServicio);

        //160115837
    end;

    procedure InsertIncExpLine(RecPosTransaction: Record "LSC POS Transaction"; var PaymentAmount: Decimal; TMovimiento: Integer; TServicio: Integer): Boolean
    var
        NewLine: Record "LSC POS Trans. Line";
        LineRec: Record "LSC POS Trans. Line";
        IncExpAccount: Record "LSC Income/Expense Account";
        POSLINES: Codeunit "LSC POS Trans. Lines";
        InfoTextDescription: Text;
        POSTransC: Codeunit "LSC POS Transaction";
        ValInsert: Boolean;
        POSSESION: Codeunit "LSC POS Session";
        PosFunction: Codeunit "LSC POS Functions";
        EPosContext: Codeunit "LSC POS Controller";
        POSPriceUtili: Codeunit "LSC POS Price Utility";
        POSPeriod: Codeunit "LSC POS Trans. Discounts";
        OposUtil: Codeunit "LSC POS OPOS Utility";
        PosTerminal: Record "LSC POS Terminal";
        POSCtrl: Codeunit "LSC POS Control Interface";

    begin
        POSTransC.SetPOSTransaction(RecPosTransaction);
        POSCtrl.SetClientType(0);
        /*if PosTerminal.Get(RecPosTransaction."POS Terminal No.") then;
        if POSSESION.SetHardwareProfile(PosTerminal."Hardware Profile") then;
        IF POSSESION.SetFunctionalityProfile('#FASANI') then;*/

        IncExpAccount.Reset();
        IncExpAccount.SetRange("Store No.", RecPosTransaction."Store No.");
        if (TServicio = 1) and (TMovimiento = 2) then
            IncExpAccount.SetRange(Description, 'COLECTORES PXPRESS');
        if (TServicio = 2) and (TMovimiento = 2) then
            IncExpAccount.SetRange(Description, 'RECARGAS CEL. PXPRESS');
        if (TServicio = 3) and (TMovimiento = 2) then
            IncExpAccount.SetRange(Description, 'CORRESPONSAL PXPRESS');
        if TServicio = 4 then
            IncExpAccount.SetRange(Description, 'ANULACION PXPRESS');
        if (TServicio = 5) or (TMovimiento = 1) then
            IncExpAccount.SetRange(Description, 'SALIDAS PXPRESS');
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
            POSPriceUtili.InitGlobals(NewLine, false);
            PosFunction.PosTransDiscLoad(RecPosTransaction."Receipt No.");
            PosFunction.PosTransDiscFlush;
            if TMovimiento in [5, 1] then begin
                PaymentAmount := PaymentAmount * -1;
                NewLine.Validate(Amount, PaymentAmount)
            end else
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

    procedure LogIntegration(TypeIntegration: Code[20];
        ReciptTransac: Code[20];
        DescRecip: Code[20];
        Status: Integer;
        Monto: Decimal;
        ServiceName: Text;
        Autorization: Text)
    var
        FSNWebService: Record "FSN WebServiceTable";
    begin
        if not FSNWebService.Get(ReciptTransac) then
            FSNWebService.Init();
        FSNWebService.LastSlipNo := ReciptTransac;
        FSNWebService.Store := POSSESSION.StoreNo();
        FSNWebService.Terminal := POSSESSION.TerminalNo();
        FSNWebService.Date := Today;
        FSNWebService.Time := Time;
        FSNWebService.Amount := Monto;
        FSNWebService."Status WS" := Status;
        FSNWebService."Order No." := DescRecip;
        FSNWebService."WS Request" := TypeIntegration;
        FSNWebService."Value Text 1" := ServiceName;
        FSNWebService."Last Error Text" := Autorization;

        if not FSNWebService.Insert(true) then
            FSNWebService.Modify(true);
    end;

    procedure AutentificationPuntoExpress(): Text;
    var
        url, usuario, Pass : Text;
        POSTransaction: Record "LSC POS Transaction";
        POSTransactionC: Codeunit "LSC POS Transaction";
    begin
        if not getParamsMaster() then
            exit('');
        url := fsnParameter."Web Uri" + 'Home/index?' + fsnParameter.Valor;
        if POSTransaction.Get(POSTransactionC.GetReceiptNo()) then begin
            //url := StrSubstNo(url, fsnParameter."Value Text 1", fsnParameter."Value Text 2", DelChr(POSTransaction."Receipt No.", '=', '#'), 'F30', DelChr(POSTransaction."POS Terminal No.", '=', '#'));
            url := StrSubstNo(url, fsnParameter."Value Text 1", fsnParameter."Value Text 2", DelChr(POSTransaction."Receipt No.", '=', '#'), POSTransaction."Store No.", DelChr(POSTransaction."POS Terminal No.", '=', '#'), IpAddres(POSTransaction));
            ModifyURL(url);
            exit(url);
        end;
    end;

    local procedure IpAddres(postrans: Record "LSC POS Transaction"): Text
    var
        fsnparameter: Record "FSN Parameter";
    begin
        fsnparameter.Reset();
        fsnparameter.SetRange(Grupo, 'KINPOS');
        fsnparameter.SetRange(Codigo, postrans."POS Terminal No.");
        if fsnparameter.FindFirst() then
            exit(fsnparameter.Descripcion);
    end;

    local procedure ModifyURL(URL: Text)
    var
        userRetail: Record "LSC Retail User";
        terminal: Record "LSC POS Terminal";
        explorer: Record "LSC POS Browser Control";
    begin
        if UserId = '' then
            exit;

        if not userRetail.Get(UserId) then
            exit;

        if not terminal.Get(userRetail."POS Terminal") then
            exit;

        if not explorer.Get(terminal."Menu Profile", '#POSPUNTOEX') then
            exit;

        explorer.URL := URL;
        explorer.Modify(true);

    end;

    local procedure getParamsMaster(): Boolean
    var
        lscRetailUser: Record "LSC Retail User";
    begin
        if not lscRetailUser.Get('FASANI\LSADMIN') then
            exit(false);
        fsnParameter.SetCurrentKey(Grupo, Codigo);
        fsnParameter.SetRange(Grupo, 'INTEGRATION');
        fsnParameter.SetRange(Codigo, 'PUNTOEXPRESS');
        fsnParameter.SetRange(Activo, true);
        if not fsnParameter.FindFirst() then
            exit(false);
        exit(fsnParameter.Activo);
    end;
    #endregion

    #region [API Conection Methods]
    local procedure apiRequest(Uri: Text; Method: Text): JsonObject
    var
        HttpClient: HttpClient;
        RequestMessage: HttpRequestMessage;
        ResponseMessage: HttpResponseMessage;
        ResponseContent: Text;
        json: JsonObject;
    begin
        RequestMessage.Method := Method;
        RequestMessage.SetRequestUri(Uri);

        HttpClient.Send(RequestMessage, ResponseMessage);
        ResponseMessage.Content.ReadAs(ResponseContent);

        json.Add('status', ResponseMessage.HttpStatusCode);
        json.Add('body', ResponseContent);

        exit(json);
    end;

    local procedure getCredentials(POSTransaction: Record "LSC POS Transaction"): Text
    var
        requestObject, jObject : JsonObject;
        jToken: JsonToken;
        date: Date;
        posSession: Codeunit "LSC POS Session";
        PASSWORD: Label 'Pa$$w0rd';
        fulljson: Text;
        uri, content, date_txt : Text;
        DATEpEXP: Date;
        headers: HttpHeaders;
        body: HttpContent;
        request: HttpRequestMessage;
        DatePart: Text;
        InputDate: Text;
    begin
        if (fsnParameter."String Parameters 1 Json" <> '') and (fsnParameter."String Parameters 2 Json" <> '') then begin
            date_txt := fsnParameter."String Parameters 2 Json";
            Evaluate(date, date_txt);
            if Today() < date then begin
                exit(fsnParameter."String Parameters 1 Json");
            end;
        end;

        uri := fsnParameter."Web Uri" + 'api/Authentication/UserAuthentication?' + StrSubstNo(fsnParameter.Valor, fsnParameter."Value Text 1", fsnParameter."Value Text 2", DelChr(POSTransaction."Receipt No.", '=', '#'), POSTransaction."Store No.", DelChr(POSTransaction."POS Terminal No.", '=', '#'));

        jObject := apiRequestExpress(uri, 'GET');

        if jObject.SelectToken('status', jToken) and (jToken.AsValue().AsInteger() <> 200) then
            Error('Error al obtener las credenciales del servicio web');

        jObject.Get('body', jToken);
        requestObject := jToken.AsObject();
        if requestObject.SelectToken('token', jToken) then
            if not jToken.AsValue().IsNull then
                fsnParameter."String Parameters 1 Json" := JToken.AsValue().AsText();

        if requestObject.SelectToken('expirationDate', jToken) then
            if not jToken.AsValue().IsNull then begin
                DatePart := DelChr(DelChr(JToken.AsValue().AsText(), '=', 'AM'), '=', 'PM');
                fsnParameter."String Parameters 2 Json" := COPYSTR(DatePart, 1, STRPOS(DatePart, ' ') - 1);
            end;

        fsnParameter.Modify();
        Commit();

        exit(fsnParameter."String Parameters 1 Json");
    end;

    procedure apiRequestExpress(Uri: Text; Method: Text): JsonObject;
    var
        client: HttpClient;
        contentHeader: HttpHeaders;
        response: HttpResponseMessage;
        content: HttpContent;
        status: Integer;
        res: Text;
        jResponse: JsonObject;
        json: JsonObject;
        request: HttpRequestMessage;
        t: Codeunit "Type Helper";
    begin
        request.Method := Method;
        request.SetRequestUri(uri);
        client.Send(request, response);
        content := response.Content;
        status := response.HttpStatusCode;
        content.ReadAs(res);
        jResponse.ReadFrom(res);
        json.Add('status', status);
        json.Add('body', jResponse);
        exit(json);
    end;

    procedure Post(Uri: Text; request: HttpRequestMessage): JsonObject;
    var
        client: HttpClient;
        contentHeader: HttpHeaders;
        response: HttpResponseMessage;
        content: HttpContent;
        status: Integer;
        res: Text;
        jResponse, Jsonc : JsonObject;
        json: JsonObject;
    begin
        request.Method := 'POST';
        request.SetRequestUri(uri);

        client.Send(request, response);

        content := response.Content;
        status := response.HttpStatusCode;
        content.ReadAs(res);
        if not jResponse.ReadFrom(res) then;
        json.Add('status', status);
        json.Add('body', jResponse);

        exit(json);
    end;

    procedure PostAnulacion(Uri: Text; request: HttpRequestMessage): JsonObject;
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
        json.Add('status', status);

        exit(json);

    end;

    procedure addInfocode(posTrans: Record "LSC POS Transaction"; arg: Text; value: Text; Line_: Integer)
    var
        infocode: Record "LSC POS Trans. Infocode Entry";
    begin
        infocode.Init();
        infocode."Receipt No." := posTrans."Receipt No.";
        infocode."Transaction Type" := infocode."Transaction Type"::Header;
        infocode."Line No." := Line_;
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

    procedure addLine(
            transaction: Record "LSC POS Transaction";
            description: Text)
    var
        transLine: Record "LSC POS Trans. Line";
    begin
        transLine.Init();
        transLine.Validate("Receipt No.", transaction."Receipt No.");
        transLine.Validate("Store No.", transaction."Store No.");
        transLine.Validate("POS Terminal No.", transaction."POS Terminal No.");
        transLine.Validate("Line No.", getLine(transaction, 'new'));
        transLine.Validate("Entry Type", transLine."Entry Type"::FreeText);
        transLine.Validate("Description", description);
        transLine.Insert(true);
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
    #endregion

    #region [Subscription Methods]
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC Hospitality POS Startup", 'OnIdleTimerTickEvent', '', false, false)]
    local procedure OnIdleTimerTickEvent(ActiveDiningArea: Record "LSC Dining Area"; var HospitalityTypeTemp: Record "LSC Hospitality Type" temporary; ActiveServiceFlow: Record "LSC Hospitality Service Flow");
    begin
        if getparam('UBEREATS') then
            checkNewOrder('UberEatsOrder');

        if getparam('ONLIFE') then
            checkNewOrder('Onlife');
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnBeforePostPOSTransaction', '', true, true)]
    local procedure "LSC POS Transaction Events_OnBeforePostPOSTransaction"(var POSTransaction: Record "LSC POS Transaction")
    var
        FSNWeb: Record "FSN WebServiceTable";
    begin
        if not ((POSTransaction."Sale Is Return Sale") or (POSTransaction."Entry Status" = POSTransaction."Entry Status"::Voided)) then begin
            FSNWeb.Reset();
            FSNWeb.SetRange("Order No.", POSTransaction."Receipt No.");
            FSNWeb.SetRange("Status WS", FSNWeb."Status WS"::InProcess);
            FSNWeb.SetRange("WS Request", 'PUNTO EXPRESS');
            IF FSNWeb.FindFirst() then begin
                if not DPerceReten(POSTransaction) then begin
                    LogIntegration('PUNTO EXPRESS', FSNWeb.LastSlipNo, POSTransaction."Receipt No.", "Status WS"::Send, POSTransaction.Payment, FSNWeb."Value Text 1", FSNWeb."Last Error Text");
                    ActualizacionPuntoXpress(POSTransaction, FSNWeb);
                end;
            end;
        end;
    end;
    #endregion



}
codeunit 50068 "FSN Wompi Integration"
{
    trigger OnRun()
    begin

    end;

    var
        myInt: Integer;
        GlobalParametroW: Record "FSN Parameter";
        POSSESSION: Codeunit "LSC POS Session";

    //Guardar Tarjeta
    procedure SedFormSaveCreditCard(Receipt: Code[20]; LineNo: Integer; Card: Text[50]; expirationMonth: Integer; expirationYear: Integer; DocuemntType: Text; NoDocuemnt: Text; cellPhoneNumber: Text; email: Text; var CodeResultS: Integer): Text
    var
        JSonString: Text;
        ResponseWS: Text;
        jsonInit, expiration, customerDocument, notificationMeans : JsonObject;
        api: Codeunit "FSN POS Card Integration";
        requestHeader, contentHeader : HttpHeaders;
        body: HttpContent;
        request: HttpRequestMessage;
        uri: Text;
        response: JsonObject;
        sb: DotNet StringBuilder;
        xmlFinal: File;
        xmlStream: OutStream;
        Parameterfilt: Record "FSN Parameter";

    begin

        uri := '';
        //expirationMonth := 11;
        //expirationYear := 24;

        GlobalParametro('CREATECC');
        if not GlobalParametroW.Activo then
            exit;

        uri := GlobalParametroW."Web Uri";

        jsonInit.Add('pan', Card);

        expiration.Add('expirationMonth', expirationMonth);
        expiration.Add('expirationYear', expirationYear);

        jsonInit.Add('expiration', expiration);

        customerDocument.Add('documentNumber', NoDocuemnt);
        customerDocument.Add('documentType', DocuemntType);

        jsonInit.Add('customerDocument', customerDocument);

        notificationMeans.Add('cellPhoneNumber', cellPhoneNumber);
        notificationMeans.Add('email', email);

        jsonInit.Add('notificationMeans', notificationMeans);

        jsonInit.WriteTo(JSonString);

        sb := sb.StringBuilder();
        sb.Append(JSonString);

        if Parameterfilt.get('WOMPI', 'SAVEJSONTOKEN') then begin
            IF Parameterfilt.Activo THEN
                if xmlFinal.Create('C:\Temp\WOMPITOKEN\' + Receipt + '-' + Format(LineNo) + '-' + 'WOMPITOKEN' + '.json') then begin
                    xmlFinal.CreateOutStream(xmlStream);
                    xmlStream.Write(sb.ToString());
                    xmlFinal.Close();
                end;
        end;

        body.WriteFrom(JSonString);
        body.GetHeaders(contentHeader);
        contentHeader.Clear();
        contentHeader.Add('Content-Type', 'application/json');
        request.GetHeaders(requestHeader);
        requestHeader.Clear();
        request.Content := body;
        response := api.Post(uri, request, CodeResultS);

        exit(Format(response));
    end;

    //filtrar tarjetas
    procedure FilterCreditCard(DocuemntType: Text; NoDocuemnt: Text; var CodeResultS: Integer): Text
    var
        JSonString: Text;
        ResponseWS: Text;
        jsonInit, expiration, customerDocument, notificationMeans : JsonObject;
        api: Codeunit "FSN POS Card Integration";
        requestHeader, contentHeader : HttpHeaders;
        body: HttpContent;
        request: HttpRequestMessage;
        uri: Text;
        response: JsonObject;

    begin

        uri := '';

        GlobalParametro('FILTERCC');
        if not GlobalParametroW.Activo then
            exit;

        uri := GlobalParametroW."Web Uri";

        jsonInit.Add('documentNumber', NoDocuemnt);
        jsonInit.Add('documentType', DocuemntType);

        jsonInit.WriteTo(JSonString);
        body.WriteFrom(JSonString);
        body.GetHeaders(contentHeader);
        contentHeader.Clear();
        contentHeader.Add('Content-Type', 'application/json');
        request.GetHeaders(requestHeader);
        requestHeader.Clear();
        request.Content := body;
        response := api.Post(uri, request, CodeResultS);

        //Message(Format(response));
        exit(format(response));
    end;

    //SalesTransaction
    procedure SalesTransactionCreditCard(lastDigits: text; expirationMonth: Integer; expirationYear: Integer; amount: Decimal; CustomerID: Text; var CodeResultS: Integer): Text
    var
        JSonString: Text;
        ResponseWS: Text;
        jsonInit, expiration, ValAmount, notificationMeans : JsonObject;
        api: Codeunit "FSN POS Card Integration";
        requestHeader, contentHeader : HttpHeaders;
        body: HttpContent;
        request: HttpRequestMessage;
        uri: Text;
        response: JsonObject;
    begin

        uri := '';

        GlobalParametro('SALESCC');
        if not GlobalParametroW.Activo then
            exit;

        uri := GlobalParametroW."Web Uri" + '?customerId=' + CustomerID;

        jsonInit.Add('lastDigits', lastDigits);

        expiration.Add('expirationMonth', Format(expirationMonth));
        expiration.Add('expirationYear', Format(expirationYear));

        jsonInit.Add('expiration', expiration);

        jsonInit.Add('amount', Format(amount));

        jsonInit.WriteTo(JSonString);
        body.WriteFrom(JSonString);
        body.GetHeaders(contentHeader);
        contentHeader.Clear();
        contentHeader.Add('Content-Type', 'application/json');
        request.GetHeaders(requestHeader);
        requestHeader.Clear();
        request.Content := body;

        response := api.Post(uri, request, CodeResultS);

        exit(Format(response));


    end;

    procedure GlobalParametro(codew: Code[20])
    var
        myInt: Integer;

    begin
        GlobalParametroW.Reset();
        GlobalParametroW.SetRange(Grupo, 'WOMPI');
        GlobalParametroW.SetRange(Codigo, codew);
        if GlobalParametroW.FindFirst() then;

    end;

    procedure ConvertLastDateToParameter(pLastCardDate: Text[5]): Text[5]
    var
        _Int: Integer;
    begin
        pLastCardDate := CopyStr(pLastCardDate, 1, 2) + '/' + CopyStr(pLastCardDate, 3, 4);
    END;
}
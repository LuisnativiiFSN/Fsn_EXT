codeunit 50035 "FSN Card External Conextion"
{
    TableNo = 99008906;

    trigger OnRun()
    begin
        GlobalRec.Copy(Rec);
        CASE Command OF
            'KINPOS_READ':
                ExecutePinpadWeb();
            'KINPOS_SALE':
                KinPosRequestSale(Rec);
            'BINLIST':
                GetBinJsonBinList(Parameter);
            'BAC':
                BACProcessrResponse(Rec);
        END;
    end;

    var
        Text001: Label 'Error Service, %1';
        Text002: Label 'Description error not found (%1)';
        Text003: Label 'Transaction succesfull!!. (Trans. %1)';
        Text004: Label 'Points %1 , equivalent to $%2. (Transaction %3)';
        Text006: Label 'Mode: %1 message: %2 . Validate data';
        Text007: Label 'Generic error SERFINSA';
        Text008: Label 'Command not exists %1';
        Text009: Label 'Error to load json response';
        Text010: Label 'Input amount is not correct';
        SRFEMVVALUE: Text;
        SRFBANVALUE: Text;
        SRFPINVALUE: Text;
        SRFSEQNOVALUE: Text;
        SRFREQUEST: Text;
        SRFRSECURITY: Text;
        SRFBDPARAMETERS: Text;
        SRFTXN: Text;
        _Int: Integer;
        RESPONSEGLOBAL: Text;
        StringNet: DotNet String;
        GlobalsFSNParameters: Record "FSN Parameter";
        GlobalRec: Record "LSC POS Menu Line";
        RetailSetup: Record "LSC Retail Setup";
        ODATACnn: codeunit "FSN OData Conexion";
        XMLDOMMgt: Codeunit "LSC XML DOM Mgt.";
        POSFunc: Codeunit "LSC POS Functions";
        POSCardIntegration: codeunit "FSN POS Card Integration";
        BOUtil: Codeunit "LSC BO Utils";
        FSNUtility: Codeunit "FSN Utility";

    procedure InitGlobalsFSNParameters(pParameters: Record "FSN Parameter")
    begin
        GlobalsFSNParameters.COPY(pParameters);
    end;

    procedure InitRequestGlobals(pSRFEMVVALUE: Text; pSRFBANVALUE: Text; pSRFREQUEST: Text; pSRFRSECURITY: Text; pSRFBDPARAMETERS: Text; pSRFTXN: Text; pRESPGLOBAL: Text; pSRFPINVALUE: Text; pSRFSEQNOVALUE: Text)
    begin
        SRFEMVVALUE := pSRFEMVVALUE;
        SRFBANVALUE := pSRFBANVALUE;
        SRFPINVALUE := pSRFPINVALUE;
        SRFSEQNOVALUE := pSRFSEQNOVALUE;
        SRFREQUEST := pSRFREQUEST;
        SRFRSECURITY := pSRFRSECURITY;
        SRFBDPARAMETERS := pSRFBDPARAMETERS;
        SRFTXN := pSRFTXN;
        RESPONSEGLOBAL := pRESPGLOBAL;
    end;

    procedure GetPinpadWebParameters(pFSNParameter: Record "FSN Parameter") Response: Text
    var
        jObject: JsonObject;
    begin
        Clear(jObject);
        jObject.Add('StopBits', '1');
        jObject.Add('Baudrate', '15200');
        jObject.Add('ComPort', pFSNParameter."Port Text");
        jObject.Add('DataBits', '1');
        jObject.Add('Parity', 'None');
        jObject.Add('Timeout', FORMAT(pFSNParameter.Timeuot));
        jObject.Add('OpenChannel', true);
        jObject.Add('UsecontactAmount', true);
        jObject.Add('setPrintBeforeSendData', true);
        jObject.WriteTo(Response);

        //json := '{"StopBits": "1","Baudrate": "15200","ComPort": "COM3","DataBits": "1","Parity": "None","Timeout": "40000","OpenChannel": "true","UsecontactAmount": "true","setPrintBeforeSendData": "true"}';
    end;

    procedure ExecutePinpadWeb()
    var
        IP_PORT: Text[150];
        url: Text;
        soapActionUrl: Text;
        sb: DotNet StringBuilder;
        uriObj: DotNet Uri;
        lgRequest: DotNet HttpWebRequest;
        stream: DotNet StreamWriter;
        lgResponse: DotNet HttpWebResponse;
        str: DotNet Stream;
        xDocument: XmlDocument;
        ascii: DotNet Encoding;
        xnodelist: XmlNodeList;
        xNode: XmlNode;
        xNodeFind: XmlNode;
        xmlRequest: Text;
        xmlFinal: File;
        xmlStream: OutStream;
        JObject: JsonObject;
        ok: Boolean;
    begin
        IP_PORT := GlobalsFSNParameters.Valor; //IP for read from pinpad

        url := 'http://' + IP_PORT + '/WSPinpad.asmx?op=ReadCard';
        soapActionUrl := 'http://tempuri.org/ReadCard';
        xmlRequest := '<Envelope xmlns="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<Body>' +
                '<ReadCard xmlns="http://tempuri.org/">' +
                    '<jsonDCLParameter>' + SRFREQUEST + '</jsonDCLParameter>' +
                    '<AmountString>' + GlobalRec.Parameter + '</AmountString>' +
                '</ReadCard>' +
            '</Body>' +
        '</Envelope>';


        sb := sb.StringBuilder();
        sb.Append(xmlRequest);
        IF xmlFinal.CREATE('C:\Temp\' + '2' + ' Pinpad.xml') THEN BEGIN
            xmlFinal.CREATEOUTSTREAM(xmlStream);
            xmlStream.WRITE(sb.ToString);
            xmlFinal.CLOSE;
        END;
        uriObj := uriObj.Uri(url);
        lgRequest := lgRequest.CreateDefault(uriObj);
        lgRequest.Method := 'POST';
        lgRequest.Host := IP_PORT;
        lgRequest.ContentType := 'text/xml; charset=utf-8';
        lgRequest.Headers.Add('SOAPAction', soapActionUrl);
        lgRequest.Timeout := 60000;
        stream := stream.StreamWriter(lgRequest.GetRequestStream(), ascii.UTF8);
        stream.Write(sb.ToString());
        stream.Close();
        lgResponse := lgRequest.GetResponse();
        str := lgResponse.GetResponseStream();
        xDocument := XmlDocument.Create();
        XMLDOMMgt.LoadXMLNodeFromInStream(str, xNode);
        xNode.SelectNodes('*', xnodelist);
        if xnodelist.Count > 0 then begin
            if xnodelist.Get(1, xNodeFind) then
                ok := true
            else
                if xnodelist.Get(0, xNodeFind) then
                    ok := true;
        end;

        Clear(RESPONSEGLOBAL);
        if ok then
            ok := JObject.ReadFrom(xNodeFind.AsXmlElement().InnerText);
        IF ok then begin
            JObject.WriteTo(RESPONSEGLOBAL);
        END;
    end;

    procedure GetPOSCardReqEntryTmpFromResponsePinpadWeb(jsonTxt: Text; var pPOSCardReqEntryTmp: Record "FSN POS Card Request Entry" temporary; var pBAN: Text; var pEMV: Text; var pErrorText: Text; var pin: Text; var posEntryMode: Text; var seqNo: Text)
    var
        JObject: JsonObject;
        JToken: JsonToken;
        Jvalue: Text;
        lTxt0: Label 'Json value (pinpad read) is empty';
    begin
        Clear(pErrorText);
        IF jsonTxt = '' then begin
            pErrorText := lTxt0;
            exit;
        end;

        pPOSCardReqEntryTmp.RESET;
        pPOSCardReqEntryTmp.DELETEALL;
        CLEAR(pPOSCardReqEntryTmp);

        pPOSCardReqEntryTmp.INIT();
        pPOSCardReqEntryTmp."Entry No." := 0;
        pPOSCardReqEntryTmp."Date Key" := TODAY;

        if not JObject.ReadFrom(jsonTxt) then begin
            pErrorText := lTxt0;
            exit;
        end;
        if GetJsonValueAsText('descriptionerror', JObject, JToken, pErrorText, Jvalue) then
            if Jvalue <> 'null' then
                pErrorText := Jvalue;
        if GetJsonValueAsText('cardban', JObject, JToken, pErrorText, Jvalue) then
            pBAN := Jvalue;
        if GetJsonValueAsText('cardemv', JObject, JToken, pErrorText, Jvalue) then
            pEMV := Jvalue;
        if GetJsonValueAsText('pan', JObject, JToken, pErrorText, Jvalue) then
            pPOSCardReqEntryTmp."Card Filter" := CopyStr((Jvalue), 1, MaxStrLen(pPOSCardReqEntryTmp."Retailer ID"));//Card No.
        if GetJsonValueAsText('mode', JObject, JToken, pErrorText, Jvalue) then
            pPOSCardReqEntryTmp."Entry Mode" := CopyStr((Jvalue), 1, MaxStrLen(pPOSCardReqEntryTmp."Entry Mode"));
        if GetJsonValueAsText('lastdate', JObject, JToken, pErrorText, Jvalue) then
            pPOSCardReqEntryTmp."Card Last Date" := CopyStr((Jvalue), 1, MaxStrLen(pPOSCardReqEntryTmp."Card Last Date"));
        if GetJsonValueAsText('lastdigits', JObject, JToken, pErrorText, Jvalue) then
            pPOSCardReqEntryTmp."Cast Last Numbers" := CopyStr((Jvalue), 1, MaxStrLen(pPOSCardReqEntryTmp."Cast Last Numbers"));
        if GetJsonValueAsText('bin', JObject, JToken, pErrorText, Jvalue) then
            pPOSCardReqEntryTmp.BIN := CopyStr((Jvalue), 1, MaxStrLen(pPOSCardReqEntryTmp.BIN));
        if GetJsonValueAsText('responseread', JObject, JToken, pErrorText, Jvalue) then
            pPOSCardReqEntryTmp."Authorization Code" := CopyStr((Jvalue), 1, MaxStrLen(pPOSCardReqEntryTmp."Authorization Code"));
        if GetJsonValueAsText('pin', JObject, JToken, pErrorText, Jvalue) then
            pin := CopyStr((Jvalue), 1);
        if GetJsonValueAsText('posEntryMode', JObject, JToken, pErrorText, Jvalue) then
            posEntryMode := CopyStr((Jvalue), 1);
        if GetJsonValueAsText('seqNo', JObject, JToken, pErrorText, Jvalue) then
            seqNo := CopyStr((Jvalue), 1);

        pPOSCardReqEntryTmp."Response Web Ok" := pPOSCardReqEntryTmp."Authorization Code" = 'PP';
        pPOSCardReqEntryTmp.INSERT;
    end;

    local procedure GetJsonValueAsText(TokenName: Text[50]; jObject: JsonObject; jToken: JsonToken; Var pErrorTxt: Text; var Jvalue: Text): Boolean
    var
        lTxt0: Label 'Token %1 not foun in read Pinpad Web';
    begin
        if pErrorTxt <> '' then
            exit(false);
        if not jObject.SelectToken(TokenName, jToken) then begin
            pErrorTxt := StrSubstNo(lTxt0, TokenName);
            exit(false);
        end else
            if not jToken.IsValue then begin
                pErrorTxt := StrSubstNo(lTxt0, TokenName);
                exit(false);
            end else
                if jToken.AsValue().IsNull then
                    Jvalue := ''
                else
                    Jvalue := jToken.AsValue().AsText();
        //jToken.WriteTo(Jvalue);
        exit(true);

    end;

    procedure KinPosRequestSale(pParameters: Record "LSC POS Menu Line")
    var
        pError: Boolean;
        ResponseTextWS: Text;
        JObject: JsonObject;
        POSCardRequestEntryTmp: Record "FSN POS Card Request Entry" temporary;
        POSCardRequestEntry: Record "FSN POS Card Request Entry";
    begin
        SRFCreateRequestDCL_RS232(pParameters);
        SRFSecurityTextX();
        SRFCreateJsonDBParameters(pParameters);

        ResponseTextWS := WSPayments(pError, JObject);

        IF pError THEN
            ERROR(ResponseTextWS);

        xmlSFRToParameters(ResponseTextWS, JObject, POSCardRequestEntryTmp);

        POSCardRequestEntry.GET(pParameters."POS Key Code", DMY2DATE(pParameters.XPos, pParameters.YPos, pParameters.Width), pParameters."Current-POSID");
        POSCardRequestEntry."Amount Input" := POSCardRequestEntryTmp."Amount Input";
        POSCardRequestEntry."Trans Audit No" := POSCardRequestEntryTmp."Trans Audit No";
        POSCardRequestEntry."Trans Authorization" := POSCardRequestEntryTmp."Trans Authorization";
        POSCardRequestEntry."Trans Date" := POSCardRequestEntryTmp."Trans Date";
        POSCardRequestEntry."Trans Reference" := POSCardRequestEntryTmp."Trans Reference";
        POSCardRequestEntry."Trans Time" := POSCardRequestEntryTmp."Trans Time";
        POSCardRequestEntry."Trans Tipo Mssg" := POSCardRequestEntryTmp."Trans Tipo Mssg";
        POSCardRequestEntry."Authorization Code" := POSCardRequestEntryTmp."Authorization Code";
        POSCardRequestEntry.Folio := POSCardRequestEntryTmp.Folio;
        POSCardRequestEntry.Invoice := POSCardRequestEntryTmp.Invoice;
        POSCardRequestEntry."Network ID" := POSCardRequestEntryTmp."Network ID";
        POSCardRequestEntry.Points := POSCardRequestEntryTmp.Points;
        POSCardRequestEntry."Response Web Ok" := POSCardRequestEntryTmp."Response Web Ok";
        POSCardRequestEntry."Send Audit No" := POSCardRequestEntryTmp."Send Audit No";
        POSCardRequestEntry.MODIFY(TRUE);
    end;

    local procedure xmlSFRToParameters(ResponseTextWS: Text; var pJObject: JsonObject; var POSCardRequestEntryTmp: Record "FSN POS Card Request Entry" temporary)
    var
        JToken: JsonToken;
        SpecialToken: Text;
        Points: Decimal;
        PointInCurrencyText: Text[50];
        PoinsInCurrency: Decimal;
        varText: Text;
    begin
        POSCardRequestEntryTmp.Reset();
        Clear(POSCardRequestEntryTmp);
        /*if not pjObject.ReadFrom(ResponseTextWS) then
            Error(Text009);*/

        if pJObject.SelectToken('cliente_trans_respuesta', JToken) then
            if JToken.IsValue then
                POSCardRequestEntryTmp."Authorization Code" := COPYSTR(JToken.AsValue().AsText(), 1, 10);

        POSCardRequestEntryTmp."Response Web Ok" := POSCardRequestEntryTmp."Authorization Code" = '00';

        if GlobalsFSNParameters.Descripcion = 'TESTDEBUG' then                  //testing
            POSCardRequestEntryTmp."Amount Input" := GlobalRec."Current-INPUT"
        else                                                                    //testing
            if pJObject.SelectToken('cliente_trans_monto', JToken) then
                if JToken.IsValue then
                    POSCardRequestEntryTmp."Amount Input" := COPYSTR(JToken.AsValue().AsText(), 1, MAXSTRLEN(POSCardRequestEntryTmp."Amount Input"));

        if POSCardRequestEntryTmp."Amount Input" = '' then
            POSCardRequestEntryTmp."Amount Input" := GlobalRec."Current-INPUT";

        if pJObject.SelectToken('cliente_trans_networkid', JToken) then
            if JToken.IsValue then
                POSCardRequestEntryTmp."Network ID" := COPYSTR(JToken.AsValue().AsText(), 1, MAXSTRLEN(POSCardRequestEntryTmp."Network ID"));
        if pJObject.SelectToken('cliente_trans_trantime', JToken) then
            if JToken.IsValue then
                POSCardRequestEntryTmp."Trans Time" := COPYSTR(JToken.AsValue().AsText(), 1, MAXSTRLEN(POSCardRequestEntryTmp."Trans Time"));
        if pJObject.SelectToken('cliente_trans_trandate', JToken) then
            if JToken.IsValue then
                POSCardRequestEntryTmp."Trans Date" := COPYSTR(JToken.AsValue().AsText(), 1, MAXSTRLEN(POSCardRequestEntryTmp."Trans Date"));
        if pJObject.SelectToken('cliente_trans_referencia', JToken) then
            if JToken.IsValue then
                POSCardRequestEntryTmp."Trans Reference" := COPYSTR(JToken.AsValue().AsText(), 1, MAXSTRLEN(POSCardRequestEntryTmp."Trans Reference"));
        if GlobalsFSNParameters.Descripcion = 'TESTDEBUG' then begin                                                 //testing
            POSCardRequestEntryTmp."Trans Authorization" := Format(Time, 0, '<Hours12><Minutes,2><Seconds,2>');
            if StrLen(POSCardRequestEntryTmp."Trans Authorization") < 6 then
                POSCardRequestEntryTmp."Trans Authorization" := '0' + POSCardRequestEntryTmp."Trans Authorization";
        end else                                                                                                        //testing
            if pJObject.SelectToken('cliente_trans_autoriza', JToken) then
                if JToken.IsValue then
                    POSCardRequestEntryTmp."Trans Authorization" := COPYSTR(JToken.AsValue().AsText(), 1, MAXSTRLEN(POSCardRequestEntryTmp."Trans Authorization"));

        if pJObject.SelectToken('cliente_trans_auditno', JToken) then
            if JToken.IsValue then
                POSCardRequestEntryTmp."Trans Audit No" := COPYSTR(JToken.AsValue().AsText(), 1, MAXSTRLEN(POSCardRequestEntryTmp."Trans Audit No"));

        if pJObject.SelectToken('cliente_trans_tokenspec', JToken) then
            if JToken.IsValue then
                SpecialToken := JToken.AsValue().AsText();

        IF SRFTXN IN ['MANCOMPRAMIL', 'BANCOMPRAMIL', 'EMVCOMPRAMIL'] THEN BEGIN

            IF SpecialToken <> '' THEN
                IF STRPOS(SpecialToken, '_P') > 0 THEN
                    POSCardRequestEntryTmp.Points := COPYSTR(SpecialToken, STRPOS(SpecialToken, '_P') + 2, 12);

            IF GlobalsFSNParameters.Grupo = 'KINPOSCUSCATLAN' THEN
                POSCardRequestEntryTmp.Points := POSCardRequestEntryTmp."Amount Input";

        END;

        IF GlobalRec."Current-GUEST" = 2 THEN BEGIN
            POSCardRequestEntryTmp."Response Web Ok" := FALSE;

            IF GlobalsFSNParameters.Grupo = 'KINPOSCUSCATLAN' THEN BEGIN
                CLEAR(Points);
                IF EVALUATE(Points, POSCardRequestEntryTmp."Amount Input") THEN
                    Points := Points * 100;

                CLEAR(PoinsInCurrency);
                IF EVALUATE(PoinsInCurrency, POSCardRequestEntryTmp."Amount Input") THEN
                    PoinsInCurrency := PoinsInCurrency;
            END ELSE BEGIN
                IF STRPOS(SpecialToken, '_P') > 1 THEN
                    varText := COPYSTR(SpecialToken, STRPOS(SpecialToken, '_P') + 2, 12)
                ELSE
                    varText := '0';

                IF STRPOS(SpecialToken, '_M') > 1 THEN
                    PointInCurrencyText := COPYSTR(SpecialToken, STRPOS(SpecialToken, '_M') + 2, 12)
                ELSE
                    PointInCurrencyText := '0';

                EVALUATE(Points, varText);
                EVALUATE(PoinsInCurrency, PointInCurrencyText);
            END;
            IF Points <> 0 THEN
                Points := Points / 100;
            IF PoinsInCurrency <> 0 THEN
                PoinsInCurrency := PoinsInCurrency / 100;

            POSCardRequestEntryTmp.Points := GetTextInput(Points);
            //POSCardRequestEntryTmp."Enter Input" := FORMAT(Points);
            POSCardRequestEntryTmp."Amount Input" := GetTextInput(PoinsInCurrency);

            IF POSCardRequestEntryTmp."Authorization Code" IN ['00'] THEN
                POSCardRequestEntryTmp."Authorization Code" := 'OK';
            /*
            POSCardRequestEntryTmp.Points := GetTextInput(Points);
            POSCardRequestEntryTmp."Enter Input" := FORMAT(Points);
            POSCardRequestEntryTmp."Amount Input" := GetTextInput(PoinsInCurrency); 
            */
        END;


        /*
        //var jval = jObject.GetValue("cliente_trans_autoriza");
        auth = getValueAsText(jObject,"cliente_trans_autoriza");
        refer = getValueAsText(jObject, "cliente_trans_referencia");
        time = getValueAsText(jObject, "cliente_trans_trantime");
        date = getValueAsText(jObject, "cliente_trans_trandate");
        msg = getValueAsText(jObject, "cliente_trans_tipomensaje");
        rescode = getValueAsText(jObject, "cliente_trans_respuesta");
        resamt = getValueAsText(jObject, "cliente_trans_monto");
        network = getValueAsText(jObject, "cliente_trans_networkid");
        msgesp = getValueAsText(jObject, "cliente_trans_tokenspec");
        audit = getValueAsText(jObject, "cliente_trans_auditno");
        */
    end;

    procedure SRFCreateRequestDCL_RS232(pParameters: Record "LSC POS Menu Line" temporary)
    var
        CLIENTE_TRANS_AUDITNO: Text[100];
        CLIENTE_TRANS_AUTORIZA: Text[100];
        CLIENTE_TRANS_MODOENTRA: Text[100];
        CLIENTE_TRANS_MONTO: Text[100];
        CLIENTE_TRANS_RECIBOID: Text[100];
        CLIENTE_TRANS_REFERENCIA: Text[100];
        CLIENTE_TRANS_RETAILERID: Text[100];
        CLIENTE_TRANS_TARJETABAN: Text;
        CLIENTE_TRANS_TARJETAEMV: Text;
        CLIENTE_TRANS_TARJETAMAN: Text;
        CLIENTE_TRANS_TARJETAVEN: Text[100];
        CLIENTE_TRANS_TERMINALID: Text[100];
        CLIENTE_TRANS_TOKENCVV: Text[100];
        CLIENTE_TRANS_TOKENFOLIO: Text[100];
        CLIENTE_TRANS_TOKENPLAZO: Text[100];
        CLIENTE_TRANS_TRANDATE: Text[100];
        CLIENTE_TRANS_TRANTIME: Text[100];
        CLIENTE_TRANS_PINBLOCK: Text[100];
        CLIENTE_TRANS_CARDSEQNO: Text[100];
        POSTransRequestNew: Record "FSN POS Card Request Entry";
        POSTransRequestOld: Record "FSN POS Card Request Entry";
        Int_: Integer;
        Decimal_: Decimal;
        Date_: Date;
    begin
        SRFREQUEST := '';

        Date_ := DMY2DATE(pParameters.XPos, pParameters.YPos, pParameters.Width);
        if POSTransRequestNew.GET(pParameters."POS Key Code", Date_, pParameters."Current-POSID") then;
        IF POSTransRequestNew."Void Number" <> 0 THEN
            POSTransRequestOld.GET(POSTransRequestNew."Void Number", POSTransRequestNew."Void Date Key", POSTransRequestNew."Void Dist. Location");

        CLIENTE_TRANS_AUDITNO := POSTransRequestNew."Send Audit No";
        CLIENTE_TRANS_AUTORIZA := POSTransRequestOld."Trans Authorization";
        CLIENTE_TRANS_MODOENTRA := POSTransRequestNew."Entry Mode";
        CLIENTE_TRANS_MONTO := POSTransRequestNew."Enter Input";
        CLIENTE_TRANS_RECIBOID := POSTransRequestNew."Receipt ID";
        CLIENTE_TRANS_REFERENCIA := POSTransRequestOld."Trans Reference";
        CLIENTE_TRANS_RETAILERID := POSTransRequestNew."Retailer ID";
        CLIENTE_TRANS_TARJETABAN := SRFBANVALUE;
        CLIENTE_TRANS_TARJETAEMV := SRFEMVVALUE;
        CLIENTE_TRANS_TARJETAMAN := pParameters."Post Parameter";
        CLIENTE_TRANS_TARJETAVEN := POSTransRequestNew."Card Last Date";
        CLIENTE_TRANS_TERMINALID := POSTransRequestNew."Terminal ID";

        CLIENTE_TRANS_TOKENCVV := '1611 ' + POSTransRequestNew.CVV;
        CLIENTE_TRANS_TOKENFOLIO := POSTransRequestOld.Folio;
        CLIENTE_TRANS_TOKENPLAZO := 'Z0 TOKEN=PLZO' + POSTransRequestNew.Plazo;//Plazo
        CLIENTE_TRANS_TRANDATE := POSTransRequestOld."Trans Date";
        CLIENTE_TRANS_TRANTIME := POSTransRequestOld."Trans Time";

        CLIENTE_TRANS_PINBLOCK := SRFPINVALUE;
        CLIENTE_TRANS_CARDSEQNO := SRFSEQNOVALUE;

        IF pParameters."Data ID" <> '' THEN
            CLIENTE_TRANS_TOKENPLAZO := '45' + POSTransRequestNew.Plazo + pParameters."Period Access";

        CASE pParameters.Parameter OF
            'BANCHECKINN',
            'BANCHECKINNA',
            'BANCHECKOUT',
            'BANCHECKOUTA':
                BEGIN
                END;
            'BANCOMPRADEV':
                BEGIN
                    SRFREQUEST := '{' +
                      '"CLIENTE_TRANS_MONTO":"' + CLIENTE_TRANS_MONTO + '",' +
                      '"CLIENTE_TRANS_AUDITNO":"' + CLIENTE_TRANS_AUDITNO + '",' +
                      '"CLIENTE_TRANS_MODOENTRA":"' + CLIENTE_TRANS_MODOENTRA + '",' +
                      '"CLIENTE_TRANS_TARJETABAN":"' + CLIENTE_TRANS_TARJETABAN + '",' +
                      '"CLIENTE_TRANS_TERMINALID":"' + CLIENTE_TRANS_TERMINALID + '",' +
                      '"CLIENTE_TRANS_RETAILERID":"' + CLIENTE_TRANS_RETAILERID + '",' +
                      '"CLIENTE_TRANS_RECIBOID":"' + CLIENTE_TRANS_RECIBOID + '"}';

                END;
            'BANCONMILLA':
                BEGIN
                    SRFREQUEST := '{' +
                      '"CLIENTE_TRANS_AUDITNO":"' + CLIENTE_TRANS_AUDITNO + '",' +
                      '"CLIENTE_TRANS_MODOENTRA":"' + CLIENTE_TRANS_MODOENTRA + '",' +
                      '"CLIENTE_TRANS_TARJETABAN":"' + CLIENTE_TRANS_TARJETABAN + '",' +
                      '"CLIENTE_TRANS_TERMINALID":"' + CLIENTE_TRANS_TERMINALID + '",' +
                      '"CLIENTE_TRANS_RETAILERID":"' + CLIENTE_TRANS_RETAILERID + '",' +
                      '"CLIENTE_TRANS_RECIBOID":"' + CLIENTE_TRANS_RECIBOID + '"}';

                END;
            'BANCOMPRAMIL':
                BEGIN
                    SRFREQUEST := '{' +
                      '"CLIENTE_TRANS_MONTO":"' + CLIENTE_TRANS_MONTO + '",' +
                      '"CLIENTE_TRANS_AUDITNO":"' + CLIENTE_TRANS_AUDITNO + '",' +
                      '"CLIENTE_TRANS_MODOENTRA":"' + CLIENTE_TRANS_MODOENTRA + '",' +
                      '"CLIENTE_TRANS_TARJETABAN":"' + CLIENTE_TRANS_TARJETABAN + '",' +
                      '"CLIENTE_TRANS_TERMINALID":"' + CLIENTE_TRANS_TERMINALID + '",' +
                      '"CLIENTE_TRANS_RETAILERID":"' + CLIENTE_TRANS_RETAILERID + '",' +
                      '"CLIENTE_TRANS_RECIBOID":"' + CLIENTE_TRANS_RECIBOID + '"}';

                END;
            'BANCOMPRAMILA':
                BEGIN
                    SRFREQUEST := '{' +
                      '"CLIENTE_TRANS_TARJETAMAN":"' + CLIENTE_TRANS_TARJETAMAN + '",' +
                      '"CLIENTE_TRANS_MONTO":"' + CLIENTE_TRANS_MONTO + '",' +
                      '"CLIENTE_TRANS_AUDITNO":"' + CLIENTE_TRANS_AUDITNO + '",' +
                      '"CLIENTE_TRANS_TRANTIME":"' + CLIENTE_TRANS_TRANTIME + '",' +
                      '"CLIENTE_TRANS_TRANDATE":"' + CLIENTE_TRANS_TRANDATE + '",' +
                      '"CLIENTE_TRANS_TARJETAVEN":"' + CLIENTE_TRANS_TARJETAVEN + '",' +
                      '"CLIENTE_TRANS_MODOENTRA":"' + CLIENTE_TRANS_MODOENTRA + '",' +
                      '"CLIENTE_TRANS_REFERENCIA":"' + CLIENTE_TRANS_REFERENCIA + '",' +
                      '"CLIENTE_TRANS_AUTORIZA":"' + CLIENTE_TRANS_AUTORIZA + '",' +
                      '"CLIENTE_TRANS_TERMINALID":"' + CLIENTE_TRANS_TERMINALID + '",' +
                      '"CLIENTE_TRANS_RETAILERID":"' + CLIENTE_TRANS_RETAILERID + '",' +
                      '"CLIENTE_TRANS_RECIBOID":"' + CLIENTE_TRANS_RECIBOID + '"}';

                END;
            'BANCOMPRANOR':
                BEGIN
                    SRFREQUEST := '{' +
                      '"CLIENTE_TRANS_MONTO":"' + CLIENTE_TRANS_MONTO + '",' +
                      '"CLIENTE_TRANS_AUDITNO":"' + CLIENTE_TRANS_AUDITNO + '",' +
                      '"CLIENTE_TRANS_MODOENTRA":"' + CLIENTE_TRANS_MODOENTRA + '",' +
                      '"CLIENTE_TRANS_TARJETABAN":"' + CLIENTE_TRANS_TARJETABAN + '",' +
                      '"CLIENTE_TRANS_TERMINALID":"' + CLIENTE_TRANS_TERMINALID + '",' +
                      '"CLIENTE_TRANS_RETAILERID":"' + CLIENTE_TRANS_RETAILERID + '",' +
                      '"CLIENTE_TRANS_RECIBOID":"' + CLIENTE_TRANS_RECIBOID + '"}';

                END;
            'BANCOMPRANORA':
                BEGIN
                    SRFREQUEST := '{' +
                      '"CLIENTE_TRANS_TARJETAMAN":"' + CLIENTE_TRANS_TARJETAMAN + '",' +
                      '"CLIENTE_TRANS_MONTO":"' + CLIENTE_TRANS_MONTO + '",' +
                      '"CLIENTE_TRANS_AUDITNO":"' + CLIENTE_TRANS_AUDITNO + '",' +
                      '"CLIENTE_TRANS_TRANTIME":"' + CLIENTE_TRANS_TRANTIME + '",' +
                      '"CLIENTE_TRANS_TRANDATE":"' + CLIENTE_TRANS_TRANDATE + '",' +
                      '"CLIENTE_TRANS_TARJETAVEN":"' + CLIENTE_TRANS_TARJETAVEN + '",' +
                      '"CLIENTE_TRANS_MODOENTRA":"' + CLIENTE_TRANS_MODOENTRA + '",' +
                      '"CLIENTE_TRANS_REFERENCIA":"' + CLIENTE_TRANS_REFERENCIA + '",' +
                      '"CLIENTE_TRANS_AUTORIZA":"' + CLIENTE_TRANS_AUTORIZA + '",' +
                      '"CLIENTE_TRANS_TERMINALID":"' + CLIENTE_TRANS_TERMINALID + '",' +
                      '"CLIENTE_TRANS_RETAILERID":"' + CLIENTE_TRANS_RETAILERID + '",' +
                      '"CLIENTE_TRANS_RECIBOID":"' + CLIENTE_TRANS_RECIBOID + '"}';

                END;
            'BANCOMPRAPLA':
                BEGIN
                    SRFREQUEST := '{' +
                      '"CLIENTE_TRANS_MONTO":"' + CLIENTE_TRANS_MONTO + '",' +
                      '"CLIENTE_TRANS_AUDITNO":"' + CLIENTE_TRANS_AUDITNO + '",' +
                      '"CLIENTE_TRANS_MODOENTRA":"' + CLIENTE_TRANS_MODOENTRA + '",' +
                      '"CLIENTE_TRANS_TARJETABAN":"' + CLIENTE_TRANS_TARJETABAN + '",' +
                      '"CLIENTE_TRANS_TERMINALID":"' + CLIENTE_TRANS_TERMINALID + '",' +
                      '"CLIENTE_TRANS_RETAILERID":"' + CLIENTE_TRANS_RETAILERID + '",' +
                      '"CLIENTE_TRANS_RECIBOID":"' + CLIENTE_TRANS_RECIBOID + '",' +
                      '"CLIENTE_TRANS_TOKENPLAZO":"' + CLIENTE_TRANS_TOKENPLAZO + '"}';

                END;
            'BANCOMPRAPLAA':
                BEGIN
                    SRFREQUEST := '{' +
                      '"CLIENTE_TRANS_TARJETAMAN":"' + CLIENTE_TRANS_TARJETAMAN + '",' +
                      '"CLIENTE_TRANS_MONTO":"' + CLIENTE_TRANS_MONTO + '",' +
                      '"CLIENTE_TRANS_AUDITNO":"' + CLIENTE_TRANS_AUDITNO + '",' +
                      '"CLIENTE_TRANS_TRANTIME":"' + CLIENTE_TRANS_TRANTIME + '",' +
                      '"CLIENTE_TRANS_TRANDATE":"' + CLIENTE_TRANS_TRANDATE + '",' +
                      '"CLIENTE_TRANS_TARJETAVEN":"' + CLIENTE_TRANS_TARJETAVEN + '",' +
                      '"CLIENTE_TRANS_MODOENTRA":"' + CLIENTE_TRANS_MODOENTRA + '",' +
                      '"CLIENTE_TRANS_REFERENCIA":"' + CLIENTE_TRANS_REFERENCIA + '",' +
                      '"CLIENTE_TRANS_AUTORIZA":"' + CLIENTE_TRANS_AUTORIZA + '",' +
                      '"CLIENTE_TRANS_TERMINALID":"' + CLIENTE_TRANS_TERMINALID + '",' +
                      '"CLIENTE_TRANS_RETAILERID":"' + CLIENTE_TRANS_RETAILERID + '",' +
                      '"CLIENTE_TRANS_RECIBOID":"' + CLIENTE_TRANS_RECIBOID + '",' +
                      '"CLIENTE_TRANS_TOKENPLAZO":"' + CLIENTE_TRANS_TOKENPLAZO + '"}';

                END;
            'EMVCHECKINN',
            'EMVCHECKOUT',
            'EMVCHECKOUTA':
                begin

                end;
            'EMVCOMPRANOR':
                BEGIN
                    SRFREQUEST := '{' +
                      '"CLIENTE_TRANS_MONTO":"' + CLIENTE_TRANS_MONTO + '",' +
                      '"CLIENTE_TRANS_AUDITNO":"' + CLIENTE_TRANS_AUDITNO + '",' +
                      '"CLIENTE_TRANS_MODOENTRA":"' + CLIENTE_TRANS_MODOENTRA + '",' +
                      '"CLIENTE_TRANS_TARJETABAN":"' + CLIENTE_TRANS_TARJETABAN + '",' +
                      '"CLIENTE_TRANS_TARJETAEMV":"' + CLIENTE_TRANS_TARJETAEMV + '",' +
                      '"CLIENTE_TRANS_TERMINALID":"' + CLIENTE_TRANS_TERMINALID + '",' +
                      '"CLIENTE_TRANS_RETAILERID":"' + CLIENTE_TRANS_RETAILERID + '",' +
                      '"CLIENTE_TRANS_RECIBOID":"' + CLIENTE_TRANS_RECIBOID + '"}';

                END;
            'EMVCOMPRANORA':
                BEGIN
                    SRFREQUEST := '{' +
                      '"CLIENTE_TRANS_TARJETAMAN":"' + CLIENTE_TRANS_TARJETAMAN + '",' +
                      '"CLIENTE_TRANS_MONTO":"' + CLIENTE_TRANS_MONTO + '",' +
                      '"CLIENTE_TRANS_AUDITNO":"' + CLIENTE_TRANS_AUDITNO + '",' +
                      '"CLIENTE_TRANS_TRANTIME":"' + CLIENTE_TRANS_TRANTIME + '",' +
                      '"CLIENTE_TRANS_TRANDATE":"' + CLIENTE_TRANS_TRANDATE + '",' +
                      '"CLIENTE_TRANS_TARJETAVEN":"' + CLIENTE_TRANS_TARJETAVEN + '",' +
                      '"CLIENTE_TRANS_MODOENTRA":"' + CLIENTE_TRANS_MODOENTRA + '",' +
                      '"CLIENTE_TRANS_REFERENCIA":"' + CLIENTE_TRANS_REFERENCIA + '",' +
                      '"CLIENTE_TRANS_AUTORIZA":"' + CLIENTE_TRANS_AUTORIZA + '",' +
                      '"CLIENTE_TRANS_TERMINALID":"' + CLIENTE_TRANS_TERMINALID + '",' +
                      '"CLIENTE_TRANS_RETAILERID":"' + CLIENTE_TRANS_RETAILERID + '",' +
                      '"CLIENTE_TRANS_RECIBOID":"' + CLIENTE_TRANS_RECIBOID + '"}';

                END;
            'EMVCONMILLA':
                BEGIN
                    SRFREQUEST := '{' +
                      '"CLIENTE_TRANS_AUDITNO":"' + CLIENTE_TRANS_AUDITNO + '",' +
                      '"CLIENTE_TRANS_MODOENTRA":"' + CLIENTE_TRANS_MODOENTRA + '",' +
                      '"CLIENTE_TRANS_TARJETABAN":"' + CLIENTE_TRANS_TARJETABAN + '",' +
                      '"CLIENTE_TRANS_TARJETAEMV":"' + CLIENTE_TRANS_TARJETAEMV + '",' +
                      '"CLIENTE_TRANS_TERMINALID":"' + CLIENTE_TRANS_TERMINALID + '",' +
                      '"CLIENTE_TRANS_RETAILERID":"' + CLIENTE_TRANS_RETAILERID + '",' +
                      '"CLIENTE_TRANS_RECIBOID":"' + CLIENTE_TRANS_RECIBOID + '"}';
                END;
            'EMVCOMPRAMIL':
                BEGIN
                    SRFREQUEST := '{' +
                      '"CLIENTE_TRANS_MONTO":"' + CLIENTE_TRANS_MONTO + '",' +
                      '"CLIENTE_TRANS_AUDITNO":"' + CLIENTE_TRANS_AUDITNO + '",' +
                      '"CLIENTE_TRANS_MODOENTRA":"' + CLIENTE_TRANS_MODOENTRA + '",' +
                      '"CLIENTE_TRANS_TARJETABAN":"' + CLIENTE_TRANS_TARJETABAN + '",' +
                      '"CLIENTE_TRANS_TARJETAEMV":"' + CLIENTE_TRANS_TARJETAEMV + '",' +
                      '"CLIENTE_TRANS_TERMINALID":"' + CLIENTE_TRANS_TERMINALID + '",' +
                      '"CLIENTE_TRANS_RETAILERID":"' + CLIENTE_TRANS_RETAILERID + '",' +
                      '"CLIENTE_TRANS_RECIBOID":"' + CLIENTE_TRANS_RECIBOID + '"}';

                END;
            'EMVCOMPRAMILA':
                BEGIN
                    SRFREQUEST := '{' +
                      '"CLIENTE_TRANS_TARJETAMAN":"' + CLIENTE_TRANS_TARJETAMAN + '",' +
                      '"CLIENTE_TRANS_MONTO":"' + CLIENTE_TRANS_MONTO + '",' +
                      '"CLIENTE_TRANS_AUDITNO":"' + CLIENTE_TRANS_AUDITNO + '",' +
                      '"CLIENTE_TRANS_TRANTIME":"' + CLIENTE_TRANS_TRANTIME + '",' +
                      '"CLIENTE_TRANS_TRANDATE":"' + CLIENTE_TRANS_TRANDATE + '",' +
                      '"CLIENTE_TRANS_TARJETAVEN":"' + CLIENTE_TRANS_TARJETAVEN + '",' +
                      '"CLIENTE_TRANS_MODOENTRA":"' + CLIENTE_TRANS_MODOENTRA + '",' +
                      '"CLIENTE_TRANS_REFERENCIA":"' + CLIENTE_TRANS_REFERENCIA + '",' +
                      '"CLIENTE_TRANS_AUTORIZA":"' + CLIENTE_TRANS_AUTORIZA + '",' +
                      '"CLIENTE_TRANS_TERMINALID":"' + CLIENTE_TRANS_TERMINALID + '",' +
                      '"CLIENTE_TRANS_RETAILERID":"' + CLIENTE_TRANS_RETAILERID + '",' +
                      '"CLIENTE_TRANS_RECIBOID":"' + CLIENTE_TRANS_RECIBOID + '"}';

                END;
            'EMVCOMPRAPLA':
                BEGIN
                    SRFREQUEST := '{' +
                      '"CLIENTE_TRANS_MONTO":"' + CLIENTE_TRANS_MONTO + '",' +
                      '"CLIENTE_TRANS_AUDITNO":"' + CLIENTE_TRANS_AUDITNO + '",' +
                      '"CLIENTE_TRANS_MODOENTRA":"' + CLIENTE_TRANS_MODOENTRA + '",' +
                      '"CLIENTE_TRANS_TARJETABAN":"' + CLIENTE_TRANS_TARJETABAN + '",' +
                      '"CLIENTE_TRANS_TARJETAEMV":"' + CLIENTE_TRANS_TARJETAEMV + '",' +
                      '"CLIENTE_TRANS_TERMINALID":"' + CLIENTE_TRANS_TERMINALID + '",' +
                      '"CLIENTE_TRANS_RETAILERID":"' + CLIENTE_TRANS_RETAILERID + '",' +
                      '"CLIENTE_TRANS_RECIBOID":"' + CLIENTE_TRANS_RECIBOID + '",' +
                      '"CLIENTE_TRANS_TOKENPLAZO":"' + CLIENTE_TRANS_TOKENPLAZO + '"}';

                END;
            'EMVCOMPRAPLAA':
                BEGIN
                    SRFREQUEST := '{' +
                      '"CLIENTE_TRANS_TARJETAMAN":"' + CLIENTE_TRANS_TARJETAMAN + '",' +
                      '"CLIENTE_TRANS_MONTO":"' + CLIENTE_TRANS_MONTO + '",' +
                      '"CLIENTE_TRANS_AUDITNO":"' + CLIENTE_TRANS_AUDITNO + '",' +
                      '"CLIENTE_TRANS_TRANTIME":"' + CLIENTE_TRANS_TRANTIME + '",' +
                      '"CLIENTE_TRANS_TRANDATE":"' + CLIENTE_TRANS_TRANDATE + '",' +
                      '"CLIENTE_TRANS_TARJETAVEN":"' + CLIENTE_TRANS_TARJETAVEN + '",' +
                      '"CLIENTE_TRANS_MODOENTRA":"' + CLIENTE_TRANS_MODOENTRA + '",' +
                      '"CLIENTE_TRANS_REFERENCIA":"' + CLIENTE_TRANS_REFERENCIA + '",' +
                      '"CLIENTE_TRANS_AUTORIZA":"' + CLIENTE_TRANS_AUTORIZA + '",' +
                      '"CLIENTE_TRANS_TERMINALID":"' + CLIENTE_TRANS_TERMINALID + '",' +
                      '"CLIENTE_TRANS_RETAILERID":"' + CLIENTE_TRANS_RETAILERID + '",' +
                      '"CLIENTE_TRANS_RECIBOID":"' + CLIENTE_TRANS_RECIBOID + '",' +
                      '"CLIENTE_TRANS_TOKENPLAZO":"' + CLIENTE_TRANS_TOKENPLAZO + '"}';

                END;
            'MANCHECKINN',
            'MANCHECKOUT':
                begin

                end;
            'MANCOMPRAMIL':
                BEGIN
                    SRFREQUEST := '{' +
                      '"CLIENTE_TRANS_TARJETAMAN":"' + CLIENTE_TRANS_TARJETAMAN + '",' +
                      '"CLIENTE_TRANS_MONTO":"' + CLIENTE_TRANS_MONTO + '",' +
                      '"CLIENTE_TRANS_AUDITNO":"' + CLIENTE_TRANS_AUDITNO + '",' +
                      '"CLIENTE_TRANS_TARJETAVEN":"' + CLIENTE_TRANS_TARJETAVEN + '",' +
                      '"CLIENTE_TRANS_MODOENTRA":"' + CLIENTE_TRANS_MODOENTRA + '",' +
                      '"CLIENTE_TRANS_TERMINALID":"' + CLIENTE_TRANS_TERMINALID + '",' +
                      '"CLIENTE_TRANS_RETAILERID":"' + CLIENTE_TRANS_RETAILERID + '",' +
                      '"CLIENTE_TRANS_RECIBOID":"' + CLIENTE_TRANS_RECIBOID + '",' +
                      '"CLIENTE_TRANS_TOKENCVV":"' + CLIENTE_TRANS_TOKENCVV + ' Z0 REDMILLA"}';
                END;
            'MANCOMPRAMILA':
                BEGIN
                    SRFREQUEST := '{' +
                      '"CLIENTE_TRANS_TARJETAMAN":"' + CLIENTE_TRANS_TARJETAMAN + '",' +
                      '"CLIENTE_TRANS_MONTO":"' + CLIENTE_TRANS_MONTO + '",' +
                      '"CLIENTE_TRANS_AUDITNO":"' + CLIENTE_TRANS_AUDITNO + '",' +
                      '"CLIENTE_TRANS_TRANTIME":"' + CLIENTE_TRANS_TRANTIME + '",' +
                      '"CLIENTE_TRANS_TRANDATE":"' + CLIENTE_TRANS_TRANDATE + '",' +
                      '"CLIENTE_TRANS_TARJETAVEN":"' + CLIENTE_TRANS_TARJETAVEN + '",' +
                      '"CLIENTE_TRANS_MODOENTRA":"' + CLIENTE_TRANS_MODOENTRA + '",' +
                      '"CLIENTE_TRANS_REFERENCIA":"' + CLIENTE_TRANS_REFERENCIA + '",' +
                      '"CLIENTE_TRANS_AUTORIZA":"' + CLIENTE_TRANS_AUTORIZA + '",' +
                      '"CLIENTE_TRANS_TERMINALID":"' + CLIENTE_TRANS_TERMINALID + '",' +
                      '"CLIENTE_TRANS_RETAILERID":"' + CLIENTE_TRANS_RETAILERID + '",' +
                      '"CLIENTE_TRANS_RECIBOID":"' + CLIENTE_TRANS_RECIBOID + '"}';
                END;
            'EMVCOMPRAPIN':
                BEGIN
                    SRFREQUEST := '{' +
                      '"CLIENTE_TRANS_MONTO":"' + CLIENTE_TRANS_MONTO + '",' +
                      '"CLIENTE_TRANS_AUDITNO":"' + CLIENTE_TRANS_AUDITNO + '",' +
                      '"CLIENTE_TRANS_MODOENTRA":"' + CLIENTE_TRANS_MODOENTRA + '",' +
                      '"CLIENTE_TRANS_TERMINALID":"' + CLIENTE_TRANS_TERMINALID + '",' +
                      '"CLIENTE_TRANS_RETAILERID":"' + CLIENTE_TRANS_RETAILERID + '",' +
                      '"CLIENTE_TRANS_RECIBOID":"' + CLIENTE_TRANS_RECIBOID + '",' +
                      '"CLIENTE_TRANS_TARJETABAN":"' + CLIENTE_TRANS_TARJETABAN + '",' +
                      '"CLIENTE_TRANS_TARJETAEMV":"' + CLIENTE_TRANS_TARJETAEMV + '",' +
                      '"CLIENTE_TRANS_CARDSEQNO":"' + CLIENTE_TRANS_CARDSEQNO + '",' +
                      '"CLIENTE_TRANS_PINBLOCK":"' + CLIENTE_TRANS_PINBLOCK + '"}';
                END;
            'MANCOMPRANOR':
                BEGIN
                    SRFREQUEST := '{' +
                      '"CLIENTE_TRANS_TARJETAMAN":"' + CLIENTE_TRANS_TARJETAMAN + '",' +
                      '"CLIENTE_TRANS_MONTO":"' + CLIENTE_TRANS_MONTO + '",' +
                      '"CLIENTE_TRANS_AUDITNO":"' + CLIENTE_TRANS_AUDITNO + '",' +
                      '"CLIENTE_TRANS_TARJETAVEN":"' + CLIENTE_TRANS_TARJETAVEN + '",' +
                      '"CLIENTE_TRANS_MODOENTRA":"' + CLIENTE_TRANS_MODOENTRA + '",' +
                      '"CLIENTE_TRANS_TERMINALID":"' + CLIENTE_TRANS_TERMINALID + '",' +
                      '"CLIENTE_TRANS_RETAILERID":"' + CLIENTE_TRANS_RETAILERID + '",' +
                      '"CLIENTE_TRANS_RECIBOID":"' + CLIENTE_TRANS_RECIBOID + '",' +
                      '"CLIENTE_TRANS_TOKENCVV":"' + CLIENTE_TRANS_TOKENCVV + '"}';
                END;
            'MANCOMPRANORA':
                BEGIN
                    SRFREQUEST := '{' +
                      '"CLIENTE_TRANS_TARJETAMAN":"' + CLIENTE_TRANS_TARJETAMAN + '",' +
                      '"CLIENTE_TRANS_MONTO":"' + CLIENTE_TRANS_MONTO + '",' +
                      '"CLIENTE_TRANS_AUDITNO":"' + CLIENTE_TRANS_AUDITNO + '",' +
                      '"CLIENTE_TRANS_TRANTIME":"' + CLIENTE_TRANS_TRANTIME + '",' +
                      '"CLIENTE_TRANS_TRANDATE":"' + CLIENTE_TRANS_TRANDATE + '",' +
                      '"CLIENTE_TRANS_TARJETAVEN":"' + CLIENTE_TRANS_TARJETAVEN + '",' +
                      '"CLIENTE_TRANS_MODOENTRA":"' + CLIENTE_TRANS_MODOENTRA + '",' +
                      '"CLIENTE_TRANS_REFERENCIA":"' + CLIENTE_TRANS_REFERENCIA + '",' +
                      '"CLIENTE_TRANS_AUTORIZA":"' + CLIENTE_TRANS_AUTORIZA + '",' +
                      '"CLIENTE_TRANS_TERMINALID":"' + CLIENTE_TRANS_TERMINALID + '",' +
                      '"CLIENTE_TRANS_RETAILERID":"' + CLIENTE_TRANS_RETAILERID + '",' +
                      '"CLIENTE_TRANS_RECIBOID":"' + CLIENTE_TRANS_RECIBOID + '"}';
                END;
            'MANCOMPRAPLA':
                BEGIN
                    SRFREQUEST := '{' +
                      '"CLIENTE_TRANS_TARJETAMAN":"' + CLIENTE_TRANS_TARJETAMAN + '",' +
                      '"CLIENTE_TRANS_MONTO":"' + CLIENTE_TRANS_MONTO + '",' +
                      '"CLIENTE_TRANS_AUDITNO":"' + CLIENTE_TRANS_AUDITNO + '",' +
                      '"CLIENTE_TRANS_TARJETAVEN":"' + CLIENTE_TRANS_TARJETAVEN + '",' +
                      '"CLIENTE_TRANS_MODOENTRA":"' + CLIENTE_TRANS_MODOENTRA + '",' +
                      '"CLIENTE_TRANS_TERMINALID":"' + CLIENTE_TRANS_TERMINALID + '",' +
                      '"CLIENTE_TRANS_RETAILERID":"' + CLIENTE_TRANS_RETAILERID + '",' +
                      '"CLIENTE_TRANS_RECIBOID":"' + CLIENTE_TRANS_RECIBOID + '",';
                    IF pParameters."Data ID" = '' THEN
                        SRFREQUEST += '"CLIENTE_TRANS_TOKENCVV":"' + CLIENTE_TRANS_TOKENCVV + ' Z0 TOKEN=PLZO' + POSTransRequestNew.Plazo + '"}' //Plazo
                    ELSE
                        SRFREQUEST += '"CLIENTE_TRANS_TOKENPLAZO":"' + CLIENTE_TRANS_TOKENPLAZO + ' ' + CLIENTE_TRANS_TOKENCVV + '"}';
                END;
            'MANCOMPRAPLAA':
                BEGIN
                    SRFREQUEST := '{' +
                      '"CLIENTE_TRANS_TARJETAMAN":"' + CLIENTE_TRANS_TARJETAMAN + '",' +
                      '"CLIENTE_TRANS_MONTO":"' + CLIENTE_TRANS_MONTO + '",' +
                      '"CLIENTE_TRANS_AUDITNO":"' + CLIENTE_TRANS_AUDITNO + '",' +
                      '"CLIENTE_TRANS_TRANTIME":"' + CLIENTE_TRANS_TRANTIME + '",' +
                      '"CLIENTE_TRANS_TRANDATE":"' + CLIENTE_TRANS_TRANDATE + '",' +
                      '"CLIENTE_TRANS_TARJETAVEN":"' + CLIENTE_TRANS_TARJETAVEN + '",' +
                      '"CLIENTE_TRANS_MODOENTRA":"' + CLIENTE_TRANS_MODOENTRA + '",' +
                      '"CLIENTE_TRANS_REFERENCIA":"' + CLIENTE_TRANS_REFERENCIA + '",' +
                      '"CLIENTE_TRANS_AUTORIZA":"' + CLIENTE_TRANS_AUTORIZA + '",' +
                      '"CLIENTE_TRANS_TERMINALID":"' + CLIENTE_TRANS_TERMINALID + '",' +
                      '"CLIENTE_TRANS_RETAILERID":"' + CLIENTE_TRANS_RETAILERID + '",' +
                      '"CLIENTE_TRANS_RECIBOID":"' + CLIENTE_TRANS_RECIBOID + '"}';
                END;
            'MANCONMILLA':
                BEGIN
                    SRFREQUEST := '{' +
                      '"CLIENTE_TRANS_TARJETAMAN":"' + CLIENTE_TRANS_TARJETAMAN + '",' +
                      '"CLIENTE_TRANS_AUDITNO":"' + CLIENTE_TRANS_AUDITNO + '",' +
                      '"CLIENTE_TRANS_TARJETAVEN":"' + CLIENTE_TRANS_TARJETAVEN + '",' +
                      '"CLIENTE_TRANS_MODOENTRA":"' + CLIENTE_TRANS_MODOENTRA + '",' +
                      '"CLIENTE_TRANS_TERMINALID":"' + CLIENTE_TRANS_TERMINALID + '",' +
                      '"CLIENTE_TRANS_RETAILERID":"' + CLIENTE_TRANS_RETAILERID + '",' +
                      '"CLIENTE_TRANS_RECIBOID":"' + CLIENTE_TRANS_RECIBOID + '"}';
                END;
            ELSE
                ERROR(STRSUBSTNO(Text008, pParameters.Parameter));
        END;

        IF SRFREQUEST = '' THEN
            ERROR(STRSUBSTNO(Text008, pParameters.Parameter));

        SRFREQUEST := '{"message":' + SRFREQUEST + '}';

        SRFTXN := pParameters.Parameter;//Command
    end;

    procedure GetResponseGlobals(): Text
    begin
        EXIT(RESPONSEGLOBAL);
    end;

    PROCEDURE GetBinJsonBinList(BIN: Code[50]): Boolean;
    VAR
        ParametrosVarios_l: Record "FSN Parameter";
        HttpWebRequest: DotNet HttpWebRequest;
        HttpWebResponse: DotNet HttpWebResponse;
        StreamReader: DotNet StreamReader;
        Address: Text[250];
        BodyText: Text;
        HashCode: Integer;
    BEGIN

        IF NOT ParametrosVarios_l.GET('BIN', 'BINLIST') THEN EXIT(FALSE);
        IF (ParametrosVarios_l.Valor = '') OR NOT ParametrosVarios_l.Activo THEN EXIT(FALSE);

        Address := DELCHR(ParametrosVarios_l.Valor, '=', ' ') + DELCHR(BIN, '=', ' ');
        HttpWebRequest := HttpWebRequest.HttpWebRequest();
        HttpWebRequest := HttpWebRequest.Create(Address);
        HttpWebRequest.Timeout(60000);
        HttpWebRequest.Method('GET');
        HttpWebRequest.ContentType('application/json');
        HashCode := HttpWebRequest.GetHashCode();
        HttpWebResponse := HttpWebResponse.HttpWebResponse();
        HttpWebResponse := HttpWebRequest.GetResponse();
        StreamReader := StreamReader.StreamReader(HttpWebResponse.GetResponseStream());
        BodyText := StreamReader.ReadToEnd();

        JsonToFillTableBinBank(BodyText, BIN);
    END;

    LOCAL PROCEDURE JsonToFillTableBinBank(pDocument: Text; pBIN: Code[20]);
    VAR
        BinTable: Record "FSN BIN Bank";
        JArray: JsonArray;
        JObject: JsonObject;
        JToken: JsonToken;
        JTokenValue: JsonToken;
    BEGIN
        IF (pDocument = '') OR BinTable.GET(pBIN) THEN
            EXIT;

        BinTable.RESET;
        CLEAR(BinTable);

        BinTable.INIT;
        BinTable."BIN/IIN" := pBIN;

        JObject.ReadFrom(pDocument);
        JObject.SelectToken('number', JToken);
        if JToken.IsObject() then begin
            if JToken.SelectToken('length', JTokenValue) then
                if JTokenValue.IsValue then
                    BinTable.Length := JTokenValue.AsValue().AsInteger();
            if JToken.SelectToken('luhn', JTokenValue) then
                if JTokenValue.IsValue then
                    BinTable.Luhn := JTokenValue.AsValue().AsBoolean();
        END;

        if JObject.SelectToken('scheme', JTokenValue) then
            if JTokenValue.IsValue then
                BinTable."Scheme Text" := JTokenValue.AsValue().AsText();
        if JObject.SelectToken('type', JTokenValue) then
            if JTokenValue.IsValue then
                BinTable."Card Type" := JTokenValue.AsValue().AsText();
        if JObject.SelectToken('brand', JTokenValue) then
            if JTokenValue.IsValue then
                BinTable.Brand := JTokenValue.AsValue().AsText();
        if JObject.SelectToken('prepaid', JTokenValue) then
            if JTokenValue.IsValue then
                BinTable.Prepaid := JTokenValue.AsValue().AsBoolean();

        if JObject.SelectToken('country', JToken) then
            if JToken.IsObject then begin
                if JToken.SelectToken('numeric', JTokenValue) then
                    if JTokenValue.IsValue then
                        BinTable.Numeric := JTokenValue.AsValue().AsInteger();
                if JToken.SelectToken('alpha2', JTokenValue) then
                    if JTokenValue.IsValue then
                        BinTable."Country Alpha 2" := JTokenValue.AsValue().AsText();
                if JToken.SelectToken('currency', JTokenValue) then
                    if JTokenValue.IsValue then
                        BinTable.Currency := JTokenValue.AsValue().AsText();
            END;

        if JObject.SelectToken('bank', JTokenValue) then
            if JTokenValue.IsValue then
                BinTable."Bank Name" := JTokenValue.AsValue().AsText();

        IF BinTable."Scheme Text" = 'amex' THEN//Static
            BinTable."Extra Data" := 'CREDOMATIC'
        ELSE
            BinTable."Extra Data" := 'ATH';

        BinTable.Source := BinTable.Source::Web;
        BinTable."Show POS Data" := FALSE;
        BinTable."Tender Type Default" := '';
        BinTable.INSERT(TRUE);
    END;


    procedure SRFSecurityTextX()
    begin
        SRFRSECURITY := GlobalsFSNParameters."String Parameters 1 Json";
    end;


    procedure SRFGetErrorCodeText(pCodeResponse: Text[10]): Text[100]
    var
        TraslateText: Text[100];
    begin
        CASE pCodeResponse OF
            '00':
                TraslateText := 'AUTORIZADO';
            '01':
                TraslateText := 'LLAMAR AL EMISOR';
            '02':
                TraslateText := 'LLAMAR AL EMISOR';
            '03':
                TraslateText := 'LLAMAR AL EMISOR';
            '04':
                TraslateText := 'TARJETA BLOQUEADA';
            '05':
                TraslateText := 'LLAMAR AL EMISOR';
            '07':
                TraslateText := 'TARJETA BLOQUEADA';
            '12':
                TraslateText := 'TRANSACCION INVALIDA';
            '13':
                TraslateText := 'MONTO INVALIDO';
            '14':
                TraslateText := 'LLAMAR AL EMISOR';
            '15':
                TraslateText := 'EMISOR NO DISPONIBLE';
            '19':
                TraslateText := 'REINTENTE TRANSACCION';
            '25':
                TraslateText := 'LLAMAR AL EMISOR';
            '30':
                TraslateText := 'ERROR DE FORMATO';
            '39':
                TraslateText := 'NO ES CUENTA DE CREDITO';
            '31':
                TraslateText := 'BANCO NO SOPORTADO';
            '41':
                TraslateText := 'TARJETA BLOQUEADA';
            '43':
                TraslateText := 'TARJETA BLOQUEADA';
            '48':
                TraslateText := 'CREDENCIAL INVALIDA';
            '50':
                TraslateText := 'LLAMAR AL EMISOR';
            '51':
                TraslateText := 'FONDOS INSUFICIENTES';
            '52':
                TraslateText := 'NO ES CUENTA DE CHEQUES';
            '53':
                TraslateText := 'NO ES CUENTA DE AHORROS';
            '54':
                TraslateText := 'TARJETA EXPIRADA';
            '55':
                TraslateText := 'PIN INCORRECTO';
            '56':
                TraslateText := 'TARJETA NO VALIDA';
            '57':
                TraslateText := 'TRANSACCION NO PERMITIDA';
            '58':
                TraslateText := 'TRANSACCION NO PERMITIDA';
            '59':
                TraslateText := 'SOSPECHA DE FRAUDE';
            '61':
                TraslateText := 'ACTIVIDAD DE LIMITE EXCEDIDO';
            '62':
                TraslateText := 'TARJETA RESTRINGIDA';
            '65':
                TraslateText := 'MAXIMO PERMITIDO ALCANZADO';
            '75':
                TraslateText := 'INTENTOS DE PIN EXCEDIDO';
            '82':
                TraslateText := 'NO HSM';
            '83':
                TraslateText := 'CUENTA NO EXISTE';
            '84':
                TraslateText := 'CUENTA NO EXISTE';
            '85':
                TraslateText := 'REGISTRO NO ENCONTRADO';
            '86':
                TraslateText := 'AUTORIZACION NO VALIDA';
            '87':
                TraslateText := 'CVV2 INVALIDO';
            '88':
                TraslateText := 'ERROR EN LOG DE TRANSACCIONES';
            '89':
                TraslateText := 'RUTA DE SERVICIO NO VALIDA';
            '91':
                TraslateText := 'EMISOR NO DISPONIBLE';
            '92':
                TraslateText := 'EMISOR NO DISPONIBLE';
            '93':
                TraslateText := 'TRANSACCION NO PUEDE SER PROCESADA';
            '94':
                TraslateText := 'TRANSACCION DUPLICADA';
            '96':
                TraslateText := 'SISTEMA NO DISPONIBLE';
            '97':
                TraslateText := 'TOKEN DE SEGURIDAD INVALIDO';
            'D0':
                TraslateText := 'SISTEMA NO DISPONIBLE';
            'D1':
                TraslateText := 'COMERCIO INVALIDO';
            'H0':
                TraslateText := 'FOLIO YA EXISTE';
            'H1':
                TraslateText := 'CHECK IN EXISTENTE';
            'H2':
                TraslateText := 'SERVICIO DE RESERVACION NO PERMITIDO';
            'H3':
                TraslateText := 'RESERVA NO ENCONTRADA EN EL SISTEMA';
            'H4':
                TraslateText := 'TARJETA NO ENCONTRADA CHECK IN';
            'H5':
                TraslateText := 'EXCEDE SOBREGIRO DE CHECK IN';
            'N0':
                TraslateText := 'AUTORIZACION INHABILITADA';
            'N1':
                TraslateText := 'TARJETA INVALIDA';
            'N2':
                TraslateText := 'PREAUTORIZACIONES COMPLETAS';
            'N3':
                TraslateText := 'MONTO MAXIMO ALCANZADO';
            'N4':
                TraslateText := 'MONTO MAXIMO ALCANZADO';
            'N5':
                TraslateText := 'MAXIMO DEVOLUCIONES ALCANZADO';
            'N6':
                TraslateText := 'MAXIMO PERMITIDO ALCANZADO';
            'N7':
                TraslateText := 'LLAMAR AL EMISOR';
            'N8':
                TraslateText := 'CUENTA SOBREGIRADA';
            'N9':
                TraslateText := 'INTENTOS PERMITIDOS ALCANZADO';
            'O0':
                TraslateText := 'LLAMAR AL EMISOR';
            'O1':
                TraslateText := 'NEG FILE PROBLEM';
            'O2':
                TraslateText := 'MONTO DE RETIRO NO PERMITIDO';
            'O3':
                TraslateText := 'DELINQUENT';
            'O4':
                TraslateText := 'LIMITE EXCEDIDO';
            'O7':
                TraslateText := 'FORCE POST';
            'O8':
                TraslateText := 'SIN CUENTA';
            'O5':
                TraslateText := 'PIN REQUERIDO';
            'O6':
                TraslateText := 'DIGITO VERIFICADOR INVALIDO';
            'R8':
                TraslateText := 'TARJETA BLOQUEADA';
            'T1':
                TraslateText := 'MONTO INVALIDO';
            'T2':
                TraslateText := 'FECHA DE TRANSACCION INVALIDA';
            'T5':
                TraslateText := 'LLAMAR AL EMISOR';

            ELSE
                TraslateText := STRSUBSTNO(Text002, pCodeResponse);
        END;
        EXIT(TraslateText);
    end;


    procedure WSPayments(var pError: Boolean; var JObject: JsonObject) ResponseLocal: Text
    var
        IP: Text[150];
        url: Text;
        soapActionUrl: Text;
        sb: DotNet StringBuilder;
        uriObj: DotNet Uri;
        lgRequest: DotNet HttpWebRequest;
        stream: DotNet StreamWriter;
        lgResponse: DotNet HttpWebResponse;
        str: DotNet Stream;
        xDocument: DotNet XmlDocument;
        ascii: DotNet Encoding;
        xnodelist: DotNet XmlNodeList;
        xNode: Dotnet XmlNode;
        Reader: DotNet XmlTextReader;
        xmlRequest: Text;
        xmlFinal: File;
        xmlStream: OutStream;
        ok: Boolean;
    begin
        IP := GlobalsFSNParameters.IP;

        url := GlobalsFSNParameters."Web Uri";
        soapActionUrl := GlobalsFSNParameters."Web Action";

        xmlRequest := '<?xml version="1.0" encoding="utf-8"?>' +
        '<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
          '<soap:Body>' +
            '<cardtransactionsjSon xmlns="http://tempuri.org/">' +
              '<security>' + SRFRSECURITY + '</security>' +
              '<txt>' + SRFTXN + '</txt>' +
              '<request>' + SRFREQUEST + '</request>' +
              '<IsVoid>false</IsVoid>' +
              '<pError>false</pError>' +
              '<OriginType>1</OriginType>' +
              '<InfoLocation>' + SRFBDPARAMETERS + '</InfoLocation>' +
            '</cardtransactionsjSon>' +
          '</soap:Body>' +
        '</soap:Envelope>';

        sb := sb.StringBuilder();
        sb.Append(xmlRequest);
        IF xmlFinal.CREATE('C:\Temp\' + '1' + ' cP.xml') THEN BEGIN
            xmlFinal.CREATEOUTSTREAM(xmlStream);
            xmlStream.WRITE(sb.ToString);
            xmlFinal.CLOSE;
        END;
        uriObj := uriObj.Uri(url);
        lgRequest := lgRequest.CreateDefault(uriObj);
        lgRequest.Method := 'POST';
        lgRequest.Host := IP;
        lgRequest.ContentType := 'text/xml; charset=utf-8';
        lgRequest.Headers.Add('SOAPAction', soapActionUrl);
        lgRequest.Timeout := 60000;
        stream := stream.StreamWriter(lgRequest.GetRequestStream(), ascii.UTF8);
        stream.Write(sb.ToString());
        stream.Close();
        lgResponse := lgRequest.GetResponse();
        str := lgResponse.GetResponseStream();
        Reader := Reader.XmlTextReader(str);
        xDocument := xDocument.XmlDocument();
        xDocument.Load(Reader);
        xNodelist := xdocument.SelectNodes('//*');
        xDocument.Save('C:\temp\' + '1' + ' cR.xml');
        xNodelist := xDocument.GetElementsByTagName('cardtransactionsjSonResult');
        xNode := xnodelist.Item(0);
        ok := true;

        ResponseLocal := 'OK';
        if ok then
            ok := JObject.ReadFrom(xNode.FirstChild.InnerText);

        IF not ok then begin
            ResponseLocal := Text007;
            pError := TRUE
        END;
    end;

    procedure SRFCreateJsonDBParameters(pParameters: Record "LSC POS Menu Line" temporary)
    var
        Date_: Date;
        dbCnn: Text;
        POSTransRequestNew: Record "FSN POS Card Request Entry";
        DistributionLocation: Record "LSC Distribution Location";
        ENCRYPTBYPASSPHRASE: Label 'xRecord';
    begin
        SRFBDPARAMETERS := '';
        Date_ := DMY2DATE(pParameters.XPos, pParameters.YPos, pParameters.Width);
        POSTransRequestNew.GET(pParameters."POS Key Code", Date_, pParameters."Current-POSID");
        //RetailSetup.GET();
        DistributionLocation.GET(GlobalsFSNParameters."Distribution Location Ext.");

        SRFBDPARAMETERS := '{"parameters":{' +
          '"DayKey":"' + FORMAT(DATE2DMY(POSTransRequestNew."Date Key", 1)) + '",' +
          '"MonthKey":"' + FORMAT(DATE2DMY(POSTransRequestNew."Date Key", 2)) + '",' +
          '"YearKey":"' + FORMAT(DATE2DMY(POSTransRequestNew."Date Key", 3)) + '",' +
          '"EntryNo":"' + FORMAT(POSTransRequestNew."Entry No.") + '",' +
          '"Location":"' + POSTransRequestNew."Distribution Location" + '",' +
          '"DB":"' + DistributionLocation."Db. Path && Name" + '",' +//DB Rows Affected
          '"CnnDB":"' + 'DBTIENDA' + '",' +//Obsolete
          '"CnnIP":"' + pParameters.Description + '",' +
          '"CnnServer":"' + DistributionLocation."Db Server Name" + '",' +
          '"CnnUser":"' + DistributionLocation."User ID" + '",' +
          '"CnnPsw":"' + DistributionLocation.Password + '",' +
          '"CnnPhrase":"' + ENCRYPTBYPASSPHRASE + '"}}';
    end;


    procedure SaveXML(pParameter: Record "LSC POS Menu Line"; pType: Integer; pText: Text)
    var
        FileMgt: Codeunit "File Management";
        FilterString: Text;
        FileSystem: DotNet StreamWriter;
    begin
        FilterString := 'C:\temp\WSFSN\' + pParameter."Primary Key" + pParameter."Current-RECEIPT" + '.xml';
        //IF FileMgt.ClientDirectoryExists('C:\temp\WSFSN') THEN BEGIN
        FileSystem := FileSystem.StreamWriter(FilterString);
        CASE pType OF
            0:
                FileSystem.Write(SRFTXN);
            1:
                FileSystem.Write(pText);
        END;
        FileSystem.Close();
        //END;
    end;


    procedure BACProcessrResponse(pParameters: Record "LSC POS Menu Line" temporary)
    var
        xml: Text;
        document: DotNet XmlDocument;
        Convert: DotNet JsonConvert;
        JObject: DotNet JObject;
        NewJsonTxt: Text;
        RecordNew: Record "FSN POS Card Request Entry";
        PointsTxt: Text[250];
        PointsDecimal: Decimal;
        PointsBalance: Decimal;
    begin

        xml := SRFREQUEST;
        //MESSAGE(FORMAT(xml));
        SaveXML(pParameters, 1, xml);
        JObject := JObject.JObject();
        document := document.XmlDocument();
        document.LoadXml(xml);
        NewJsonTxt := Convert.SerializeXmlNode(document);
        JObject := JObject.Parse(NewJsonTxt);
        JObject := JObject.SelectToken('EMVStreamResponse');

        RecordNew.RESET;
        RecordNew.SETRANGE(RecordNew."Entry No.", pParameters."Current-LINE");
        RecordNew.SETRANGE(RecordNew."Date Key", DMY2DATE(pParameters.XPos, pParameters.YPos, pParameters.Width));
        RecordNew.SETRANGE(RecordNew."Distribution Location", pParameters."Current-POSID");
        IF RecordNew.FIND('-') THEN BEGIN
            RecordNew."Authorization Code" := ODATACnn.GetValueAsText(JObject, 'responseCode');
            RecordNew."Trans Authorization" := ODATACnn.GetValueAsText(JObject, 'authorizationNumber');
            RecordNew."Trans Time" := ODATACnn.GetValueAsText(JObject, 'hostTime');
            RecordNew."Trans Date" := ODATACnn.GetValueAsText(JObject, 'hostDate');
            RecordNew.Invoice := ODATACnn.GetValueAsText(JObject, 'invoice');
            RecordNew."Trans Reference" := ODATACnn.GetValueAsText(JObject, 'referenceNumber');
            IF pParameters.Parameter = 'POINTS' THEN BEGIN
                RecordNew."Amount Input" := RecordNew."Enter Input";
                RecordNew.Points := ODATACnn.GetValueAsText(JObject, 'salesAmount');
            END ELSE
                RecordNew."Amount Input" := ODATACnn.GetValueAsText(JObject, 'salesAmount');
            RecordNew."Trans Audit No" := ODATACnn.GetValueAsText(JObject, 'systemTraceNumber');
            RecordNew."Trans Tipo Mssg" := ODATACnn.GetValueAsText(JObject, 'transactionId');
            RecordNew."Entry Mode" := ODATACnn.GetValueAsText(JObject, 'entryMode');
            IF NOT (pParameters.Parameter = 'POINTS_INQUIRY') THEN BEGIN
                RecordNew."Response Web Ok" := RecordNew."Authorization Code" = '00';
            END ELSE BEGIN
                IF RecordNew."Authorization Code" = '00' THEN BEGIN
                    RecordNew."Response Web Ok" := FALSE;
                    RecordNew."Authorization Code" := 'OK';
                    PointsTxt := RecordNew."Amount Input";
                    IF PointsTxt = '' THEN
                        PointsTxt := '0';

                    CLEAR(PointsDecimal);
                    IF EVALUATE(PointsDecimal, PointsTxt) THEN;
                    RecordNew."Amount Input" := FORMAT(ROUND(PointsDecimal * 0.006, 1));
                    RecordNew.Points := FORMAT(ROUND(PointsDecimal, 1));
                END;
            END;
            RecordNew."Terminal ID" := pParameters."POS Help ID";
            RecordNew."Entity Name" := 'CREDOMATIC';
            RecordNew.MODIFY(TRUE);
        END;

        CASE pParameters.Parameter OF
            'SALE', 'PAYMENT_PLAN', 'VOID', 'POINTS':
                BEGIN
                    IF RecordNew."Response Web Ok" THEN
                        MESSAGE(STRSUBSTNO(Text003, FORMAT(pParameters."Current-LINE")))
                    ELSE
                        MESSAGE(ODATACnn.GetValueAsText(JObject, 'responseCodeDescription'));
                END;
            'POINTS_INQUIRY':
                BEGIN
                    IF RecordNew."Authorization Code" = 'OK' THEN BEGIN
                        MESSAGE(STRSUBSTNO(Text004, RecordNew.Points, RecordNew."Amount Input", FORMAT(pParameters."Current-LINE")));
                    END ELSE
                        MESSAGE(ODATACnn.GetValueAsText(JObject, 'responseCodeDescription'));
                END;
        END;
    end;
    //BOTH
    procedure GetTextInput(pValue: Decimal): Text[12]
    var
        _VaueReturn: Text[12];
    begin
        _VaueReturn := FORMAT(pValue, 0, '<Precision,2:2><Standard Format,0>');
        StringNet := _VaueReturn;
        StringNet := StringNet.Replace('.', '');
        _VaueReturn := StringNet.Replace(',', '');
        IF STRLEN(_VaueReturn) > 12 THEN
            ERROR(Text010);
        _VaueReturn := POSFunc.ZeroPad(_VaueReturn, 12);
        EXIT(_VaueReturn);
    end;

    procedure JsonToXmlFillTableTransactorNode(pParameters: Record "LSC POS Menu Line"; pString: Text; CSWebServiceTableTmp: Record "FSN WebServiceTable" temporary)
    var
        xmlnodelist: DotNet XmlNodeList;
        xmlnode: DotNet XmlNode;
        _Index: Integer;
        _ValueDecimal: Decimal;
        document: DotNet XmlDocument;
        pPOSCardReqEntry: Record "FSN POS Card Request Entry";
        jTokenValue: Text[100];
        Phone: Text[50];
        JSonConvert: DotNet JsonConvert;
        RetailSetup_l: Record "LSC Retail Setup";
        POSTransactionCU: Codeunit "LSC POS Transaction";
        POSTransaction: Record "LSC POS Transaction";
        PagosLineNo: Integer;
        FreeText: Text;
        TenderTypeSetup_l: Record "LSC Tender Type Setup";
        JArray: JsonArray;
        JObject: JsonObject;
        JToken: JsonToken;
        JValue: JsonToken;
        ManualExit: Boolean;
        BINList: Record "FSN BIN Bank";
        StaffTxt: Text[100];
        NewCustomerCode: Code[20];
        Customer_l: Record Customer;
        StrPosInt: Integer;
        Keylink: Text;
        POSTransInfocode_l: Record "LSC POS Trans. Infocode Entry";
        POSTransLine_l: Record "LSC POS Trans. Line";
        lText001: Label 'Staff: ';
        lText002: Label 'Store Suggest: ';
        lText003: Label 'Pedido generado automatico: PARA LLEVAR. %1';
        lText004: Label 'Origin: ';
    begin


        if pString = '' then
            exit;

        ManualExit := FALSE;
        RetailSetup_l.GET;

        if not JObject.ReadFrom(pString) then
            exit;

        //JObject := JObject.JObject();
        //JObject := JObject.Parse(pString);
        if JObject.SelectToken('manual', JToken) then begin
            //JToken := JObject.SelectToken('manual');

            //CLEAR(MostrarPagos);
            //MostrarPagos.INIT;
            //MostrarPagos."No. Recibo" := pParameters."Current-RECEIPT";

            POSTransLine_l.RESET;
            POSTransLine_l.SETCURRENTKEY("Receipt No.", "Entry Type", "Entry Status");
            POSTransLine_l.SETRANGE(POSTransLine_l."Receipt No.", pParameters."Current-RECEIPT");
            POSTransLine_l.SETRANGE(POSTransLine_l."Entry Type", POSTransLine_l."Entry Type"::Payment);
            POSTransLine_l.SETRANGE(POSTransLine_l."Entry Status", 0);
            IF POSTransLine_l.FIND('-') THEN
                PagosLineNo := POSTransLine_l."Line No."
            ELSE
                PagosLineNo := 1;

            /*MostrarPagos.Linea := PagosLineNo;
            MostrarPagos."Tender Type" := pParameters."Current-SALESORDER";*/

            IF not TenderTypeSetup_l.GET(pParameters."Current-SALESORDER") THEN
                TenderTypeSetup_l.Init();
            //MostrarPagos."Funcion en CC" := TenderTypeSetup_l."Function in CC";

            CLEAR(pPOSCardReqEntry);
            Phone := '';
            jTokenValue := '';
            StaffTxt := '';

            //IF NOT ISNULL(JToken) THEN BEGIN

            /*
            jTokenValue := COPYSTR(GetValueAsText(JToken, 'number'), 1, 30);
            jTokenValue := DELCHR(jTokenValue, '=', '-');
            MostrarPagos."Numero Tarjeta / Cheque" := LSExtFunc.Encrypt(jTokenValue);
            IF STRLEN(jTokenValue) > 6 THEN
                MostrarPagos.BIN := COPYSTR(jTokenValue, 1, 6);
            IF MostrarPagos.BIN <> '' THEN
                IF BINList.GET(MostrarPagos.BIN) THEN
                    MostrarPagos."Nombre Banco" := COPYSTR(BINList."Bank Name", 1, 150);
            jTokenValue := COPYSTR(GetValueAsText(JToken, 'cvv'), 1, 3);
            MostrarPagos."Num. Verificacion" := LSExtFunc.Encrypt(jTokenValue);
            jTokenValue := COPYSTR(GetValueAsText(JToken, 'lastdate'), 1, 4);
            MostrarPagos."Fecha Expiracion" := COPYSTR(jTokenValue, 1, 2) + '/' + COPYSTR(jTokenValue, 3, 2);
            jTokenValue := COPYSTR(GetValueAsText(JToken, 'amountmanual'), 1, 20);
            IF EVALUATE(MostrarPagos.Monto, jTokenValue) THEN;
            Phone := COPYSTR(GetValueAsText(JToken, 'phonemanual'), 1, 50);
            jTokenValue := COPYSTR(GetValueAsText(JToken, 'personaldocument'), 1, 20);
            MostrarPagos.DUI := jTokenValue;
            IF (MostrarPagos.DUI <> '') OR
              (MostrarPagos.Monto <> 0) OR
              (MostrarPagos."Num. Verificacion" <> '') THEN BEGIN

                IF MostrarPagos."Cod. Aut./ Reserva" <> '' THEN
                    MostrarPagos.Proceso := MostrarPagos.Proceso::YaFueCobrado;

                IF MostrarPagos."Funcion en CC" = MostrarPagos."Funcion en CC"::Change THEN BEGIN
                    jTokenValue := COPYSTR(GetValueAsText(JToken, 'amountchange'), 1, 20);
                    IF jTokenValue <> '' THEN
                        IF EVALUATE(MostrarPagos."Cambio Para", jTokenValue) THEN;
                    IF (MostrarPagos."Cambio Para" = 0) AND (MostrarPagos.Monto <> 0) THEN BEGIN
                        MostrarPagos."Cambio Para" := ((MostrarPagos.Monto DIV 5) + 1) * 5;
                    END;
                END;

                MostrarPagos.INSERT;
                //COMMIT;

                IF POSTransaction.GET(pParameters."Current-RECEIPT") THEN
                    IF TenderTypeSetup_l."FSN Function in CC" = TenderTypeSetup_l."FSN Function in CC"::Card THEN BEGIN
                        POSTransLine_l.RESET;
                        POSTransLine_l.SETCURRENTKEY("Receipt No.", "Entry Type", "Entry Status");
                        POSTransLine_l.SETRANGE(POSTransLine_l."Receipt No.", pParameters."Current-RECEIPT");
                        POSTransLine_l.SETRANGE(POSTransLine_l."Entry Type", POSTransLine_l."Entry Type"::Payment);
                        POSTransLine_l.SETRANGE(POSTransLine_l."Entry Status", 0);
                        IF POSTransLine_l.FINDFIRST THEN
                            POSCommandExt.InsertByShowPayment(POSTransLine_l, MostrarPagos.BIN, MostrarPagos, POSTransaction);//WVILLALTA 9.20+
                        IF Phone <> '' THEN BEGIN
                            POSTransaction."Sell-to Contact No." := Phone;
                            POSTransaction.MODIFY;
                        END;
                        StaffTxt := '';
                        IF POSTransaction."Sales Staff" <> '' THEN
                            StaffTxt := lText001 + POSTransaction."Sales Staff";
                    END;

                ManualExit := TRUE;

                CSWebServiceTableTmp.INIT();
                CSWebServiceTableTmp.LastSlipNo := pParameters."Current-RECEIPT";
                CSWebServiceTableTmp.Store := POSTransaction."Store No.";
                CSWebServiceTableTmp.Terminal := POSTransaction."POS Terminal No.";
                CSWebServiceTableTmp."Order No." := '';
                CSWebServiceTableTmp.Date := TODAY;
                CSWebServiceTableTmp.Time := TIME;
                CSWebServiceTableTmp."Sell-to Contact No." := POSTransaction."Sell-to Contact No.";
                CSWebServiceTableTmp.Amount := MostrarPagos.Monto;
                CSWebServiceTableTmp."Customer No." := POSTransaction."Customer No.";
                IF Customer_l.GET(POSTransaction."Customer No.") THEN BEGIN
                    CSWebServiceTableTmp.Mail := Customer_l."E-Mail";
                    StrPosInt := STRPOS(Customer_l.Name, ' ');
                    IF StrPosInt > 0 THEN BEGIN
                        CSWebServiceTableTmp."First Name" := COPYSTR(Customer_l.Name, 1, StrPosInt);
                        CSWebServiceTableTmp."Last Name" := COPYSTR(Customer_l.Name, StrPosInt, MAXSTRLEN(CSWebServiceTableTmp."Last Name"));
                    END;
                    IF Customer_l.DUI <> '' THEN BEGIN
                        CSWebServiceTableTmp."Document Personal" := Customer_l.DUI;
                        CSWebServiceTableTmp."Document Type" := CSWebServiceTableTmp."Document Type"::DUI;
                    END ELSE
                        IF Customer_l."No. Extranjero" <> '' THEN BEGIN
                            CSWebServiceTableTmp."Document Personal" := Customer_l."No. Extranjero";
                            CSWebServiceTableTmp."Document Type" := CSWebServiceTableTmp."Document Type"::Pasaport;
                        END ELSE
                            IF Customer_l.NRC <> '' THEN BEGIN
                                CSWebServiceTableTmp."Document Personal" := Customer_l.NRC;
                                CSWebServiceTableTmp."Document Type" := CSWebServiceTableTmp."Document Type"::NRC;
                            END;
                END;
                CSWebServiceTableTmp.INSERT;
                //END;
            END;
            //COMMIT;

            JToken := JObject.SelectToken('DeliveryContactAddress');//Delivery order
            IF NOT ISNULL(JToken) THEN BEGIN
                IF CSWebServiceTableTmp.GET(pParameters."Current-RECEIPT") THEN BEGIN
                    jTokenValue := COPYSTR(GetValueAsText(JToken, 'DCAphone'), 1, 20);
                    IF jTokenValue <> '' THEN
                        IF jTokenValue <> CSWebServiceTableTmp."Sell-to Contact No." THEN BEGIN
                            CSWebServiceTableTmp."Sell-to Contact No." := jTokenValue;
                            IF POSTransaction.GET(pParameters."Current-RECEIPT") THEN BEGIN
                                POSTransaction."Sell-to Contact No." := CSWebServiceTableTmp."Sell-to Contact No.";
                                POSTransaction.MODIFY;
                            END;
                        END;
                    jTokenValue := COPYSTR(GetValueAsText(JToken, 'DCAtypeaddress'), 1, 20);
                    IF CSWebServiceTableTmp.Store = 'EC' THEN BEGIN//Static use ecommerce
                        CSWebServiceTableTmp."Order Type" := CSWebServiceTableTmp."Order Type"::HomeOfficeDelivery;
                        IF jTokenValue = '3' THEN //Takeaway = 3
                            CSWebServiceTableTmp."Order Type" := CSWebServiceTableTmp."Order Type"::HomeOfficeTakeaway;
                    END ELSE BEGIN
                        CSWebServiceTableTmp."Order Type" := CSWebServiceTableTmp."Order Type"::FromStoreDelivery;
                        IF jTokenValue = '3' THEN //Takeaway = 3
                            CSWebServiceTableTmp."Order Type" := CSWebServiceTableTmp."Order Type"::FromStoreTakeaway;
                    END;
                    CSWebServiceTableTmp.MODIFY;

                    POSTransInfocode_l.INIT;
                    POSTransInfocode_l."Receipt No." := CSWebServiceTableTmp.LastSlipNo;
                    POSTransInfocode_l."Transaction Type" := 0;
                    POSTransInfocode_l."Line No." := 888;//Internal FSN
                    POSTransInfocode_l.Infocode := 'TEXT';
                    POSTransInfocode_l."Entry Line No." := 0;
                    POSTransInfocode_l.Information := BOUtil.CombineValue(2, CSWebServiceTableTmp."Sell-to Contact No.", jTokenValue, '', '', '');
                    POSTransInfocode_l."Store No." := CSWebServiceTableTmp.Store;
                    POSTransInfocode_l.Date := TODAY;
                    POSTransInfocode_l.Time := TIME;
                    POSTransInfocode_l."POS Terminal No." := CSWebServiceTableTmp.Terminal;
                    POSTransInfocode_l."Staff ID" := POSTransaction."Sales Staff";
                    IF NOT POSTransInfocode_l.INSERT(TRUE) THEN
                        POSTransInfocode_l.MODIFY(TRUE);

                    IF jTokenValue = '2' THEN BEGIN
                        POSTransInfocode_l."Line No." := 889;//Internal FSN
                        jTokenValue := COPYSTR(GetValueAsText(JToken, 'DCAstreetname'), 1, MAXSTRLEN(POSTransInfocode_l.Information));
                        POSTransInfocode_l.Information := jTokenValue;
                        IF NOT POSTransInfocode_l.INSERT(TRUE) THEN
                            POSTransInfocode_l.MODIFY(TRUE);

                        jTokenValue := COPYSTR(GetValueAsText(JToken, 'DCAaddress'), 1, MAXSTRLEN(POSTransInfocode_l.Information));
                        IF jTokenValue <> '' THEN BEGIN
                            POSTransInfocode_l.Infocode := 'DDIRECTION';
                            POSTransInfocode_l."Line No." := 6;
                            POSTransInfocode_l.Information := jTokenValue;
                            IF NOT POSTransInfocode_l.INSERT(TRUE) THEN
                                POSTransInfocode_l.MODIFY(TRUE);
                        END;
                    END;
                END;
            END;

            JToken := JObject.SelectToken('freetext');
            IF NOT ISNULL(JToken) THEN BEGIN
                FreeText := COPYSTR(GetValueAsText(JToken, 'instructions'), 1, 500);
                IF FreeText <> '' THEN
                    InitLineFreeText(FreeText, pParameters."Current-RECEIPT");

                FreeText := COPYSTR(GetValueAsText(JToken, 'storeno'), 1, 10);
                IF FreeText <> '' THEN BEGIN
                    IF CSWebServiceTableTmp.GET(pParameters."Current-RECEIPT") THEN BEGIN
                        CSWebServiceTableTmp."Store Selected" := FreeText;
                        CSWebServiceTableTmp.MODIFY;
                    END;

                    IF StaffTxt <> '' THEN
                        FreeText := lText002 + FreeText + ' ' + StaffTxt + ' ' + lText004 + ' ' + CSWebServiceTableTmp.Store;
                    InitLineFreeText(FreeText, pParameters."Current-RECEIPT");
                END;
            END;
            */
            exit;
        end;//manual
    end;

    local procedure BitworksCard(pData: Text; pPOSMenuLine: Record "LSC POS Menu Line"): Boolean
    var
        xmlnodelist: DotNet XmlNodeList;
        xmlnode: DotNet XmlNode;
        _Index: Integer;
        _ValueDecimal: Decimal;
        document: DotNet XmlDocument;
        pPOSCardReqEntry: Record "FSN POS Card Request Entry";
        jTokenValue: Text[100];
        Phone: Text[50];
        JSonConvert: DotNet JsonConvert;
        FSNParameter_l: Record "FSN Parameter";
        POSTransactionCU: Codeunit "LSC POS Transaction";
        POSTransaction_l: Record "LSC POS Transaction";
        PagosLineNo: Integer;
        FreeText: Text;
        TenderTypeSetup_l: Record "LSC Tender Type Setup";
        JArray: JsonArray;
        JObject: JsonObject;
        JToken: JsonToken;
        JValue: JsonToken;
        ManualExit: Boolean;
        BINList: Record "FSN BIN Bank";
        StaffTxt: Text[100];
        NewCustomerCode: Code[20];
        Customer_l: Record Customer;
        StrPosInt: Integer;
        Keylink: Text;
        POSTransInfocode_l: Record "LSC POS Trans. Infocode Entry";
        POSTransLine_l: Record "LSC POS Trans. Line";
        lText001: Label 'Staff: ';
        lText002: Label 'Store Suggest: ';
        lText003: Label 'Pedido generado automatico: PARA LLEVAR. %1';
        lText004: Label 'Origin: ';
    begin
        RetailSetup.Get();
        if not FSNParameter_l.Get('KINPOS', RetailSetup."Distribution Location") then
            FSNParameter_l.Init();

        if not JObject.ReadFrom(pData) then
            exit(false);
        CLEAR(pPOSCardReqEntry);
        if JObject.SelectToken('transactor', JToken) then begin
            pPOSCardReqEntry.INIT();
            pPOSCardReqEntry."Distribution Location" := RetailSetup."Distribution Location";
            pPOSCardReqEntry."Store No." := RetailSetup."Local Store No.";
            pPOSCardReqEntry."Date Key" := TODAY;
            pPOSCardReqEntry.VALIDATE("Entry No.");
            pPOSCardReqEntry.Date := CURRENTDATETIME;
            pPOSCardReqEntry."Receipt No." := pPOSMenuLine."Current-RECEIPT"; //pParameters."Current-RECEIPT";

            POSTransLine_l.RESET;
            POSTransLine_l.SETCURRENTKEY("Receipt No.", "Entry Type", "Entry Status");
            POSTransLine_l.SETRANGE(POSTransLine_l."Receipt No.", pPOSCardReqEntry."Receipt No.");
            POSTransLine_l.SETRANGE(POSTransLine_l."Entry Type", POSTransLine_l."Entry Type"::Payment);
            POSTransLine_l.SETRANGE(POSTransLine_l."Entry Status", 0);
            IF POSTransLine_l.FIND('-') THEN
                pPOSCardReqEntry."Line No." := POSTransLine_l."Line No."
            ELSE
                pPOSCardReqEntry."Line No." := 1;
            pPOSCardReqEntry."Send Audit No" := POSCardIntegration.GenerateReceiptID(pPOSCardReqEntry."Entry No.");
            if JToken.SelectToken('mode', jValue) then
                if JValue.IsValue then
                    if not JValue.AsValue().IsNull then
                        pPOSCardReqEntry.Command := JValue.AsValue().AsText();
            if pPOSCardReqEntry.Command = '' then
                pPOSCardReqEntry.Command := 'NORMAL';
            if JToken.SelectToken('retailerid', jValue) then
                if JValue.IsValue then
                    if not JValue.AsValue().IsNull then
                        pPOSCardReqEntry."Retailer ID" := JValue.AsValue().AsText();
            if JToken.SelectToken('terminalid', jValue) then
                if JValue.IsValue then
                    if not JValue.AsValue().IsNull then
                        pPOSCardReqEntry."Terminal ID" := JValue.AsValue().AsText();
            if JToken.SelectToken('authorization', jValue) then
                if JValue.IsValue then
                    if not JValue.AsValue().IsNull then
                        pPOSCardReqEntry."Trans Authorization" := JValue.AsValue().AsText();
            if JToken.SelectToken('reference', jValue) then
                if JValue.IsValue then
                    if not JValue.AsValue().IsNull then
                        pPOSCardReqEntry."Trans Reference" := CopyStr(JValue.AsValue().AsText(), 1, MaxStrLen(pPOSCardReqEntry."Trans Reference"));
            if JToken.SelectToken('amount', jValue) then
                if JValue.IsValue then
                    if not JValue.AsValue().IsNull then
                        pPOSCardReqEntry."Amount Input" := JValue.AsValue().AsText();
            Keylink := BOUtil.CombineValue(5, FORMAT(pPOSCardReqEntry."Entry No."), FORMAT(DATE2DMY(pPOSCardReqEntry."Date Key", 1))
                              , FORMAT(DATE2DMY(pPOSCardReqEntry."Date Key", 2)), FORMAT(DATE2DMY(pPOSCardReqEntry."Date Key", 3))
                              , pPOSCardReqEntry."Distribution Location");
            Keylink := COPYSTR(Keylink, 1, 50);

            Clear(jTokenValue);
            if JToken.SelectToken('mask', jValue) then
                if JValue.IsValue then
                    if not JValue.AsValue().IsNull then
                        jTokenValue := JValue.AsValue().AsText();

            IF jTokenValue <> '' THEN
                IF STRLEN(jTokenValue) > 6 THEN BEGIN
                    pPOSCardReqEntry.BIN := pPOSMenuLine.Parameter;//BIN
                    pPOSCardReqEntry."Cast Last Numbers" := COPYSTR(jTokenValue, STRLEN(jTokenValue) - 3, 4);
                    pPOSCardReqEntry."Trans Tipo Mssg" := COPYSTR(jTokenValue, 1, 30);
                END;
            pPOSCardReqEntry."Response Web Ok" := pPOSCardReqEntry."Trans Authorization" <> '';
            IF pPOSCardReqEntry."Response Web Ok" THEN
                pPOSCardReqEntry."Authorization Code" := '00';

            pPOSCardReqEntry.Points := '';
            pPOSCardReqEntry."Entity Name" := 'SERFINSA';//Static
            pPOSCardReqEntry."Type Request" := pPOSCardReqEntry."Type Request"::WebPage;
            pPOSCardReqEntry.User := USERID;
            pPOSCardReqEntry.INSERT;
        end;

        Exit(BitworksWStable(pData, pPOSMenuLine, pPOSCardReqEntry));
    end;

    local procedure BitworksWStable(pData: Text; pPosMenuLine: Record "LSC POS Menu Line"; pPOSCardReqEntry: Record "FSN POS Card Request Entry"): Boolean;
    var
        xmlnodelist: DotNet XmlNodeList;
        xmlnode: DotNet XmlNode;
        _Index: Integer;
        _ValueDecimal: Decimal;
        document: DotNet XmlDocument;
        pPOSCardEntry: Record "LSC POS Card Entry";
        jTokenValue: Text[100];
        Phone: Text[50];
        JSonConvert: DotNet JsonConvert;
        FSNParameter_l: Record "FSN Parameter";
        POSTransactionCU: Codeunit "LSC POS Transaction";
        POSTransaction_l: Record "LSC POS Transaction";
        PagosLineNo: Integer;
        FreeText: Text;
        TenderTypeSetup_l: Record "LSC Tender Type Setup";
        JArray: JsonArray;
        JObject: JsonObject;
        JToken: JsonToken;
        JValue: JsonToken;
        ManualExit: Boolean;
        BINList: Record "FSN BIN Bank";
        StaffTxt: Text[100];
        NewCustomerCode: Code[20];
        Customer_l: Record Customer;
        StrPosInt: Integer;
        Keylink: Text;
        POSTransInfocode_l: Record "LSC POS Trans. Infocode Entry";
        POSTransLine_l: Record "LSC POS Trans. Line";
        CSWebServiceTableTmp: Record "FSN WebServiceTable";
        lText001: Label 'Staff: ';
        lText002: Label 'Store Suggest: ';
        lText003: Label 'Pedido generado automatico: PARA LLEVAR. %1';
        lText004: Label 'Origin: ';
    begin
        if not POSTransaction_l.Get(pPosMenuLine."Current-RECEIPT") then
            exit(false);
        if not JObject.ReadFrom(pData) then
            exit(false);

        if JObject.SelectToken('transactor', JToken) then begin
            //if JObject.SelectToken('transactor', JToken) then begin

            if JToken.SelectToken('phone', JValue) then
                if JValue.IsValue then
                    Phone := JValue.AsValue().AsText();

            CSWebServiceTableTmp.INIT();
            CSWebServiceTableTmp.LastSlipNo := pPosMenuLine."Current-RECEIPT";
            if JToken.SelectToken('delivery', JValue) then
                if JValue.IsValue then
                    jTokenValue := JValue.AsValue().AsText();
            IF jTokenValue IN ['1', '2'] THEN BEGIN
                CASE jTokenValue OF
                    '2':
                        BEGIN
                            CSWebServiceTableTmp."Order Type" := CSWebServiceTableTmp."Order Type"::Takeaway;
                            CSWebServiceTableTmp.Actions := CSWebServiceTableTmp.Actions::"SetDelivery And Mail";
                        END;
                    '1':
                        CSWebServiceTableTmp."Order Type" := CSWebServiceTableTmp."Order Type"::Delivery;
                    ELSE
                        CSWebServiceTableTmp."Order Type" := CSWebServiceTableTmp."Order Type"::None;
                END;

                if JToken.SelectToken('amount', JValue) then
                    if JValue.IsValue then
                        CSWebServiceTableTmp.Amount := JValue.AsValue().AsDecimal();
                if CSWebServiceTableTmp.Amount = 0 then begin
                    POSTransaction_l.CalcFields(Payment);
                    CSWebServiceTableTmp.Amount := POSTransaction_l.Payment;
                end;
                if JToken.SelectToken('firstname', JValue) then
                    if JValue.IsValue then
                        CSWebServiceTableTmp."First Name" := JValue.AsValue().AsText();
                if JToken.SelectToken('lastname', JValue) then
                    if JValue.IsValue then
                        CSWebServiceTableTmp."Last Name" := JValue.AsValue().AsText();
                if JToken.SelectToken('personaldocument', JValue) then
                    if JValue.IsValue then
                        CSWebServiceTableTmp."Document Personal" := JValue.AsValue().AsText();
                Clear(jTokenValue);
                if JToken.SelectToken('typedocument', JValue) then
                    if JValue.IsValue then
                        jTokenValue := JValue.AsValue().AsText();
                CASE jTokenValue OF
                    '1':
                        CSWebServiceTableTmp."Document Type" := CSWebServiceTableTmp."Document Type"::DUI;
                    ELSE
                        CSWebServiceTableTmp."Document Type" := CSWebServiceTableTmp."Document Type"::None;
                END;
                if JToken.SelectToken('store', JValue) then
                    if JValue.IsValue then
                        CSWebServiceTableTmp."Store Selected" := CopyStr(JValue.AsValue().AsText(), 1, 10);

                IF POSTransaction_l.GET(CSWebServiceTableTmp.LastSlipNo) THEN
                    CSWebServiceTableTmp."Customer No." := POSTransaction_l."Customer No.";
                if JToken.SelectToken('mail', JValue) then
                    if JValue.IsValue then
                        CSWebServiceTableTmp.Mail := CopyStr(JValue.AsValue().AsText(), 1, 80);

                CSWebServiceTableTmp.INSERT;

                IF CSWebServiceTableTmp."Order Type" = CSWebServiceTableTmp."Order Type"::Takeaway THEN
                    FSNUtility.POSNewLineFreeText(POSTransaction_l."Receipt No.", 0, STRSUBSTNO(lText003, CSWebServiceTableTmp."Store Selected"), 0);
            END;
        END;
        IF (Phone <> '') AND POSTransaction_l.GET(CSWebServiceTableTmp.LastSlipNo) THEN BEGIN
            NewCustomerCode := '';
            NewCustomerCode := GetFirstCustomer(CSWebServiceTableTmp, POSTransaction_l, Phone);
            IF NewCustomerCode <> '' THEN BEGIN
                POSTransaction_l."Customer No." := NewCustomerCode;
                CSWebServiceTableTmp."Customer No." := NewCustomerCode;
                CSWebServiceTableTmp.MODIFY;
            END;
            Phone := DELCHR(Phone, '=', '-');
            Phone := DELCHR(Phone, '=', ' ');
            POSTransaction_l."Sell-to Contact No." := Phone;
            POSTransaction_l.MODIFY;
        END;
        COMMIT;
        SetCustomerNameInTrans(NewCustomerCode, POSTransaction_l);
        POSTransLine_l.RESET;                                                                    //WVILLALTA 9.20-
        POSTransLine_l.SETCURRENTKEY("Receipt No.", "Entry Type", "Entry Status");
        POSTransLine_l.SETRANGE(POSTransLine_l."Receipt No.", CSWebServiceTableTmp.LastSlipNo);
        POSTransLine_l.SETRANGE(POSTransLine_l."Entry Type", POSTransLine_l."Entry Type"::Payment);
        POSTransLine_l.SETRANGE(POSTransLine_l."Entry Status", 0);
        POSTransLine_l.SETFILTER(POSTransLine_l.Number, '<>%1', '1');
        IF POSTransLine_l.FINDFIRST THEN begin
            if TenderTypeSetup_l.Get(POSTransLine_l.Number)
            and (TenderTypeSetup_l."FSN Function in CC" = TenderTypeSetup_l."FSN Function in CC"::Card)
            and (pPOSCardReqEntry."Entry No." > 0)
            then begin
                POSCardIntegration.InitPOSCardEntryByPOSTransLine(POSTransLine_l
                                                        , POSTransaction_l
                                                        , 'PREPAYMENT');
                POSCardIntegration.GetLastRecord(pPOSCardEntry, POSTransaction_l."Store No."
                                                        , POSTransaction_l."POS Terminal No."
                                                        , POSTransaction_l."Receipt No."
                                                        , POSTransLine_l."Line No.");
                POSCardIntegration.UpdatePOSCardEntryAuthorization(pPOSCardEntry, pPOSCardReqEntry);
                pPOSCardEntry.Modify(true);
            end;
        end;

        IF SRFBANVALUE <> '' THEN BEGIN
            SRFBANVALUE := 'ECOMMERCE No.: ' + SRFBANVALUE;
            FSNUtility.POSNewLineFreeText(POSTransaction_l."Receipt No.", 0, SRFBANVALUE, 0);
        END;
        exit(true);
    end;

    local procedure GetFirstCustomer(pCSWebTable: Record "FSN WebServiceTable"; pParameterTrans: Record "LSC POS Transaction"; pPhone: Text[30]) ResponseCode: Code[20]
    var
        Customer_l: Record Customer;
        SearchNew: Boolean;
        SearchDocument: Code[50];
    begin
        ResponseCode := pParameterTrans."Customer No.";

        SearchDocument := '';
        SearchNew := FALSE;
        IF pParameterTrans."Member Card No." <> '' THEN
            EXIT(ResponseCode);

        IF pParameterTrans."Customer No." <> '' THEN
            IF Customer_l.GET(pParameterTrans."Customer No.") THEN
                SearchNew := (Customer_l."LSC Retail Customer Group" = 'COMODIN');

        IF SearchNew THEN BEGIN
            CASE pCSWebTable."Document Type" OF
                pCSWebTable."Document Type"::DUI:
                    BEGIN
                        IF pCSWebTable."Document Personal" <> '' THEN BEGIN
                            Customer_l.RESET;
                            Customer_l.SETCURRENTKEY("FSN DUI");
                            Customer_l.SETRANGE(Customer_l."FSN DUI", pCSWebTable."Document Personal");
                            IF Customer_l.FINDFIRST THEN BEGIN
                                ResponseCode := Customer_l."No.";
                                EXIT(ResponseCode);
                            END ELSE BEGIN
                                SearchDocument := DELCHR(pCSWebTable."Document Personal", '=', '-');
                                SearchDocument := DELCHR(pCSWebTable."Document Personal", '=', ' ');
                                Customer_l.SETRANGE(Customer_l."FSN DUI", SearchDocument);
                                IF Customer_l.FINDFIRST AND (SearchDocument <> '') THEN BEGIN
                                    ResponseCode := Customer_l."No.";
                                    EXIT(ResponseCode);
                                END;
                            END;
                            SearchDocument := DELCHR(pCSWebTable."Document Personal", '=', '-');
                            SearchDocument := DELCHR(pCSWebTable."Document Personal", '=', ' ');
                            IF SearchDocument <> '' THEN BEGIN
                                SearchDocument := COPYSTR(SearchDocument, 1, STRLEN(SearchDocument) - 1) + '-' + COPYSTR(SearchDocument, STRLEN(SearchDocument), 1);
                                Customer_l.SETRANGE(Customer_l."FSN DUI", SearchDocument);
                                IF Customer_l.FINDFIRST AND (SearchDocument <> '') THEN BEGIN
                                    ResponseCode := Customer_l."No.";
                                    EXIT(ResponseCode);
                                END;
                            END;
                        END;
                    END;
            END;
            IF (pPhone = '') THEN
                EXIT(ResponseCode);

            Customer_l.RESET;
            Customer_l.SETCURRENTKEY("Phone No.");
            Customer_l.SETRANGE(Customer_l."Phone No.", pPhone);
            IF Customer_l.FIND('-') THEN
                REPEAT
                    IF pCSWebTable."First Name" <> '' THEN
                        IF STRPOS(Customer_l.Name, pCSWebTable."First Name") > 0 THEN BEGIN
                            ResponseCode := Customer_l."No.";
                            EXIT(ResponseCode);
                        END;
                UNTIL Customer_l.NEXT = 0;
        END;
    end;

    procedure SetCustomerNameInTrans(pNewCustomer: Code[20]; pParametersTrans: Record "LSC POS Transaction")
    var
        Customer_l: Record Customer;
        POSTransLine2: Record "LSC POS Trans. Line";
        LastLineNo: Integer;
        lText001: Label 'Customer: ';
    begin
        IF pParametersTrans."Receipt No." = '' THEN
            EXIT;

        IF NOT Customer_l.GET(pNewCustomer) OR (pNewCustomer = '') THEN
            EXIT;

        POSTransLine2.RESET;
        POSTransLine2.SETRANGE("Receipt No.", pParametersTrans."Receipt No.");
        POSTransLine2.SETRANGE("Entry Type", POSTransLine2."Entry Type"::FreeText);
        POSTransLine2.SETRANGE("Entry Status", 0);
        POSTransLine2.SETFILTER("Card/Customer/Coup.Item No", '<>%1', '');
        IF POSTransLine2.FIND('-') THEN
            POSTransLine2.DELETE(TRUE);

        POSTransLine2.SETRANGE("Entry Type");
        POSTransLine2.SETRANGE("Card/Customer/Coup.Item No");
        POSTransLine2.SETRANGE("Entry Status");
        IF POSTransLine2.FINDLAST THEN
            LastLineNo := POSTransLine2."Line No."
        ELSE
            LastLineNo := 0;
        POSTransLine2.INIT;
        POSTransLine2."Receipt No." := pParametersTrans."Receipt No.";
        POSTransLine2."Store No." := pParametersTrans."Store No.";
        POSTransLine2."POS Terminal No." := pParametersTrans."POS Terminal No.";
        POSTransLine2."Line No." := LastLineNo + 10000;
        POSTransLine2.Description := COPYSTR(lText001 + '(' + pParametersTrans."Customer Disc. Group" + ') ' + Customer_l.Name, 1, MAXSTRLEN(POSTransLine2.Description));
        POSTransLine2."Entry Type" := POSTransLine2."Entry Type"::FreeText;
        POSTransLine2."Card/Customer/Coup.Item No" := Customer_l."No.";
        POSTransLine2."Text Type" := POSTransLine2."Text Type"::"Cust. Text";
        POSTransLine2.INSERT(TRUE);
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
    begin
        if RequestID = 'JSON_BITWORKS' then begin
            if BitworksCard(XMLRequest, POSMenuLine) then begin
                Processed := true;
            end;
        end;
    end;

    procedure DecryptCardNumber(EncryptedString: Text; "Receipt No.": Code[20]): Text
    var
        TransLine: Record "LSC POS Trans. Line";
        DeliveryOrder: Record "LSC Delivery Order";
        sb: DotNet StringBuilder;
        htmlReq: DotNet HttpWebRequest;
        htmlRes: DotNet HttpWebResponse;
        uriObj: DotNet Uri;
        stream: DotNet StreamWriter;
        str: DotNet Stream;
        xDocument: DotNet XmlDocument;
        xNode: Dotnet XmlNode;
        Reader: DotNet XmlTextReader;
        ascii: DotNet Encoding;
        sw: DotNet StringWriter;
        xw: DotNet XmlTextWriter;
        xmlRequest: Text;
        xmlResponse: Text;
        url: Text;
        soapActionUrl: Text;
        IP: Text[150];
        VoidPayment: Boolean;
        xmlFinal: File;
        xmlStream: OutStream;
    begin
        Clear(VoidPayment);
        TransLine.Reset();
        transline.SetCurrentKey("Receipt No.", "Line No.");
        TransLine.SetRange("Receipt No.", "Receipt No.");
        TransLine.SetRange("Entry Type", TransLine."Entry Type"::Payment);
        TransLine.SetFilter("Entry Status", '<>%1', TransLine."Entry Status"::Voided);
        if TransLine.FindLast() then
            VoidPayment := true;

        if DeliveryOrder.Get("Receipt No.") and not VoidPayment and ("Receipt No." <> '') then begin
            IP := GlobalsFSNParameters.IP;
            url := GlobalsFSNParameters."Web Uri";
            soapActionUrl := GlobalsFSNParameters."Web Action";
            xmlRequest := '<?xml version="1.0" encoding="utf-8"?>' +
                            '<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
                            '<soap:Body>' +
                            '<DecryptString xmlns="http://tempuri.org/">' +
                            '<toDecrypt>' + EncryptedString + '</toDecrypt>' +
                            '</DecryptString>' +
                            '</soap:Body>' +
                            '</soap:Envelope>';

            sb := sb.StringBuilder();
            sb.Append(xmlRequest);
            if xmlFinal.Create('C:\Temp\decrypt.xml') then begin
                xmlFinal.CreateOutStream(xmlStream);
                xmlStream.Write(sb.ToString);
                xmlFinal.Close();
            end;
            uriObj := uriObj.Uri(url);
            htmlReq := htmlReq.CreateDefault(uriObj);
            htmlReq.Method := 'POST';
            htmlReq.ContentType := 'text/xml; charset=utf-8';
            htmlReq.Headers.Add('SOAPAction', soapActionUrl);
            htmlReq.Timeout := 60000;
            stream := stream.StreamWriter(htmlReq.GetRequestStream(), ascii.UTF8);
            stream.Write(sb.ToString());
            stream.Close();
            htmlRes := htmlReq.GetResponse();
            str := htmlRes.GetResponseStream();
            xDocument := xDocument.XmlDocument();
            Reader := Reader.XmlTextReader(str);
            xDocument.Load(Reader);
            xNode := xDocument.GetElementsByTagName('DecryptStringResult').Item(0);
            xw := xw.XmlTextWriter(sw);
            xNode.WriteTo(xw);
            exit(sw.ToString());
        end else begin
            exit(Decrypt(EncryptedString));
        end;
    end;
}
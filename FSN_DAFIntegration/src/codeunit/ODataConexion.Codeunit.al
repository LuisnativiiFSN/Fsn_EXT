codeunit 50045 "OData Conexion 2"
{
    TableNo = "LSC POS Menu Line";
    SingleInstance = true;
    trigger OnRun()
    begin
        //WVILLALTA18JUL19 #MENULINE

        CASE Command OF
            /* '':
                 EXIT;
             'BINLIST':
                 GetBinJsonBinList(Parameter);
             'KINPOS_SALE':
                 KinPosRequestSale(Rec);//WVILLALTA28OCT19
                                        //'KINPOS_VOID' : KinPosRequestVoid(Rec); WVILLALTA18FEB2020 Delete.
                                        //'KINPOS_BEEP' : KinPosBeep(Rec);WVILLALTA18FEB2020 Delete.
                                        //'RIFA_TRANS_CUST' : RifaTransactionCustomerOLEDB(Rec);
             'MANCOMPRANOR',//WVILLALTA15ENE20-
           'MANCOMPRANORA',
           'MANCONMILLA',
           'MANCOMPRAMIL',
           'MANCOMPRAMILA',
           'MANCOMPRAPLA',
           'MANCOMPRAPLAA':
                 SRFSendRequestBuy(Rec); //WVILLALTA26SEPT19-+
                                         //'FSN_GET_INVENTORY' : GetInventoryLookUpServer(Rec);
                                         //'FSN_GET_CALLOPEN' : GetCallOpen(Rec); //WVILLALTACC2.0
                                         //'FSN_INVENTORY_TR' : GetInventoryLookUpServerTR(Rec);//WVILLALTA13MAY2020-+
             'DISTANCE_API':
                 GetDistanceMatrixJson(Rec);*/
            'DAF_API':
                DAFProcessAPI(Rec);
            /*'BITWORKTRANS':
                JsonToXmlFillTableTransactorNode(Rec); //WVILLALTA11MAR20+*/
            'SAVEXML':
                SaveXML(Rec);
        /*'WSECONEXION':
            PrintWSE("Current-RECEIPT", BODYGLOBAL, 'POS', Parameter, Rec); //JNEHEMIAS130521-+*/
        END;
    end;

    var
        BaseUrl: Text;
        WSCompanyName: Text;
        NAVServerInstance: Text;
        rParametros: Record "FSN Parameter";
        _Int: Integer;
        _Decimal: Decimal;
        POSSession: Codeunit "LSC POS Session";
        POSEFT: Codeunit "LSC POS EFT Utility";
        Text000: Label 'Connection fail';
        Window: Dialog;
        Text001_2: Label 'swipe or insert card in POS SERFINSA';
        Text002_2: Label 'Performing automatic return. POS SERFINSA';
        Text001: Label 'Error Service, %1';
        Text002: Label 'Description error not found (%1)';
        Text003: Label 'Transaction succesfull!!. (Trans. %1)';
        Text004: Label 'Points %1 , equivalent to $%2. (Transaction %3)';
        Text005: Label 'Cant be empty';
        Text006: Label 'Mode: %1 message: %2 . Validate data';
        Text007: Label 'Generic error SERFINSA';
        //POSCardIntegration: Codeunit 50088;
        cLSExternalFunc: Codeunit "LSC External Functions Util";
        // MostrarPagos: Record 50045;
        SRFEMVVALUE: Text;
        SRFBANVALUE: Text;
        SRFREQUEST: Text;
        SRFRSECURITY: Text;
        SRFBDPARAMETERS: Text;
        SRFTXN: Text;
        RESPONSEGLOBAL: Text;
        BODYGLOBAL: Text;
        Text008: Label 'Command not exists %1';
        Text009: Label 'Setup parameter not exits %1, %2';
        Text010: Label '%1 not exists. Values %1 %2 %3 %4';
        GlobalsFSNParameters: Record "FSN Parameter";
        GlobalsCSWebServiceTableTmp: Record "FSN WebServiceTable" temporary;
        BOUtil: Codeunit "LSC BO Utils";
        oDataConection: Codeunit "FSN OData Conexion";

    procedure DAFProcessAPI(pParameters: Record "LSC POS Menu Line" temporary): Boolean
    var
        Parameters: DotNet Dictionary_Of_T_U;
        HttpResponseMessage: Dotnet HttpResponseMessage;
        result: Text;
        JArray: DotNet JArray;
        JObject: DotNet JObject;
        JToken: DotNet JToken;
        DriverTip: Record "FSN Delivery Trip";
        PostedDriverTip: Record "FSN Posted Delivery Trip";
        FSNParam: Record "FSN Parameter";
    begin
        BODYGLOBAL := '';

        IF pParameters."Post Command" = 'NEWORDER' THEN BEGIN
            if FSNParam.get('DAFJSON', 'SAVEXML') AND FSNParam.Activo THEN begin
                SRFEMVVALUE := SRFTXN;
                pParameters."Primary Key" := pParameters."Current-RECEIPT";
                //SaveXML(pParameters);
            end;
            JObject := JObject.Parse(SRFTXN);
            SRFTXN := JObject.ToString();
        END;

        Parameters := Parameters.Dictionary();
        Parameters.Add('baseurl', SRFREQUEST);
        Parameters.Add('restmethod', pParameters."POS Help ID");
        Parameters.Add('path', SRFBDPARAMETERS);
        Parameters.Add('accept', SRFBANVALUE);
        CASE pParameters."Post Command" OF
            'GETTOKEN':
                BEGIN
                    BODYGLOBAL := '';
                    Parameters.Add('httpcontent', BODYGLOBAL);
                END;
            'NEWORDER', 'CANCELORDER', 'CHECKORDER', 'TIMEINVOICE', 'GETTRIPS', 'GETTRIP', 'ENDTRIP', 'UPDATEDATEINVOICE':
                BEGIN
                    Parameters.Add('bearer', SRFRSECURITY);
                    IF NOT (pParameters."Post Command" IN ['CHECKORDER', 'GETTRIP', 'GETTRIPS']) THEN
                        Parameters.Add('httpcontent', SRFTXN);
                    BODYGLOBAL := SRFTXN;
                END;
        END;

        CallRESTWebService(Parameters, HttpResponseMessage);

        result := HttpResponseMessage.Content.ReadAsStringAsync.Result;

        JObject := JObject.Parse(result);

        RESPONSEGLOBAL := '';
        CASE pParameters."Post Command" OF
            'GETTOKEN':
                BEGIN
                    IF oDataConection.GetValueAsText(JObject, 'statusCode') = '200' THEN BEGIN
                        JToken := JObject.SelectToken('data');
                        IF NOT ISNULL(JToken) THEN
                            RESPONSEGLOBAL := oDataConection.GetValueAsText(JToken, 'token');
                    END ELSE
                        EXIT;
                END;
            'ENDTRIP':
                BEGIN
                    CASE TRUE OF
                        (oDataConection.GetValueAsInteger(JObject, 'result') = 0):
                            BEGIN
                                JToken := JObject.SelectToken('data');
                                IF NOT ISNULL(JToken) THEN
                                    CASE oDataConection.GetValueAsInteger(JToken, 'status') OF
                                        6:
                                            RESPONSEGLOBAL := 'CANCEL';
                                        7:
                                            RESPONSEGLOBAL := 'OK';
                                        ELSE
                                            RESPONSEGLOBAL := oDataConection.GetValueAsText(JObject, 'message');
                                    END;

                                IF RESPONSEGLOBAL = '' THEN
                                    RESPONSEGLOBAL := 'ERROR datos';
                            END;
                        (oDataConection.GetValueAsInteger(JObject, 'result') = 1):
                            BEGIN
                                RESPONSEGLOBAL := 'OK';
                            END;
                        ELSE
                            RESPONSEGLOBAL := 'ERROR';
                    END;
                END;

            'GETTRIP', 'GETTRIPS':
                BEGIN
                    CASE TRUE OF
                        (oDataConection.GetValueAsText(JObject, 'statusCode') = '200') AND (oDataConection.GetValueAsInteger(JObject, 'result') = 1):
                            BEGIN
                                IF pParameters."Post Command" = 'GETTRIPS' THEN
                                    RESPONSEGLOBAL := JObject.ToString()
                                ELSE BEGIN
                                    JToken := JObject.SelectToken('data');
                                    IF NOT ISNULL(JToken) THEN
                                        RESPONSEGLOBAL := JToken.ToString();
                                END;
                                //SRFEMVVALUE := RESPONSEGLOBAL;
                                //SaveXML(pParameters);
                            END;
                        (oDataConection.GetValueAsText(JObject, 'statusCode') = '404') AND (oDataConection.GetValueAsInteger(JObject, 'result') = 0):
                            BEGIN
                                RESPONSEGLOBAL := 'NOT';
                            END;
                        ELSE
                            RESPONSEGLOBAL := 'ERROR';
                    END;
                END;
            'NEWORDER', 'CANCELORDER', 'TIMEINVOICE':
                BEGIN
                    CASE oDataConection.GetValueAsText(JObject, 'result') OF
                        '1':
                            BEGIN
                                RESPONSEGLOBAL := 'OK';
                            END;
                        ELSE BEGIN
                            IF (pParameters."Post Command" = 'CANCELORDER') AND
                              (oDataConection.GetValueAsText(JObject, 'statusCode') = '404') THEN//Not exists
                                RESPONSEGLOBAL := 'OK'
                            ELSE
                                RESPONSEGLOBAL := 'ERROR: ' +
                                  COPYSTR(JObject.ToString(), 1, MAXSTRLEN(DriverTip.Comment));
                        END;
                    END;
                END;
            'CHECKORDER':
                BEGIN
                    //IF (GetValueAsText(JObject,'result') = '1') THEN
                    DAFUpdateTrip(JObject, pParameters)
                END;
        END;
    end;

    procedure CallRESTWebService(var Parameters: DotNet Dictionary_Of_T_U; var HttpResponseMessage: DotNet HttpResponseMessage): Boolean
    var
        HttpContent: DotNet HttpContent;
        HttpClient: DotNet HttpClient;
        AuthHeaderValue: DotNet AuthenticationHeaderValue;
        EntityTagHeaderValue: DotNet EntityTagHeaderValue;
        Uri: DotNet Uri;
        bytes: DotNet Array;
        Encoding: DotNet Encoding;
        Convert: DotNet Convert;
        HttpRequestMessage: DotNet HttpRequestMessage;
        HttpMethod: DotNet HttpMethod;
        StringContent: DotNet StringContent;
        FilterString: Text;
        FileSystem: DotNet StreamWriter;
        Net: DotNet ServicePointManager;
        SecurityProtocol: DotNet SecurityProtocolType;
    begin
        Net.SecurityProtocol := SecurityProtocol.Tls12;

        HttpClient := HttpClient.HttpClient();

        HttpClient.BaseAddress := Uri.Uri(FORMAT(Parameters.Item('baseurl')));

        HttpRequestMessage := HttpRequestMessage.HttpRequestMessage(HttpMethod.HttpMethod(UPPERCASE(FORMAT(Parameters.Item('restmethod')))), FORMAT(Parameters.Item('path')));

        IF Parameters.ContainsKey('accept') THEN
            HttpRequestMessage.Headers.Add('Accept', FORMAT(Parameters.Item('accept')));

        IF Parameters.ContainsKey('username') THEN BEGIN
            bytes := Encoding.ASCII.GetBytes(STRSUBSTNO('%1:%2', FORMAT(Parameters.Item('username')), FORMAT(Parameters.Item('password'))));
            AuthHeaderValue := AuthHeaderValue.AuthenticationHeaderValue('Basic', Convert.ToBase64String(bytes));
            HttpRequestMessage.Headers.Authorization := AuthHeaderValue;
        END;

        IF Parameters.ContainsKey('bearer') THEN BEGIN
            bytes := Encoding.ASCII.GetBytes(STRSUBSTNO('%1', FORMAT(Parameters.Item('bearer'))));
            AuthHeaderValue := AuthHeaderValue.AuthenticationHeaderValue('bearer', SRFRSECURITY);
            HttpRequestMessage.Headers.Authorization := AuthHeaderValue;
        END;

        IF Parameters.ContainsKey('Bearer') THEN BEGIN
            bytes := Encoding.ASCII.GetBytes(STRSUBSTNO('%1', FORMAT(Parameters.Item('Bearer'))));
            AuthHeaderValue := AuthHeaderValue.AuthenticationHeaderValue('Bearer', SRFRSECURITY);
            HttpRequestMessage.Headers.Authorization := AuthHeaderValue;
        END;

        IF Parameters.ContainsKey('etag') THEN
            HttpRequestMessage.Headers.IfMatch.Add(Parameters.Item('etag'));

        IF Parameters.ContainsKey('httpcontent') THEN BEGIN
            StringContent := StringContent.StringContent(BODYGLOBAL, Encoding.UTF8(), SRFBANVALUE);
            HttpRequestMessage.Content := StringContent;

        END;
        HttpResponseMessage := HttpClient.SendAsync(HttpRequestMessage).Result;

        EXIT(HttpResponseMessage.IsSuccessStatusCode);
    end;

    procedure InitRequestGlobals(pSRFEMVVALUE: Text; pSRFBANVALUE: Text; pSRFREQUEST: Text; pSRFRSECURITY: Text; pSRFBDPARAMETERS: Text; pSRFTXN: Text)
    begin
        SRFEMVVALUE := pSRFEMVVALUE;
        SRFBANVALUE := pSRFBANVALUE;
        SRFREQUEST := pSRFREQUEST;
        SRFRSECURITY := pSRFRSECURITY;
        SRFBDPARAMETERS := pSRFBDPARAMETERS;
        SRFTXN := pSRFTXN;
        RESPONSEGLOBAL := '';
    end;


    procedure GetResponseGlobals(): Text
    begin
        EXIT(RESPONSEGLOBAL);//WVILLALTA13MAY2020-+
    end;

    procedure GetValueAsText(JObject: DotNet JObject; PropertyName: Text) ReturnValue: Text
    begin
        ReturnValue := '';
        IF NOT ISNULL(JObject.GetValue(PropertyName)) THEN
            ReturnValue := JObject.GetValue(PropertyName).ToString;
    end;

    procedure GetValueAsInteger(JObject: DotNet JObject; PropertyName: Text) ReturnValue: Integer
    var
        DotNetInteger: DotNet Int32;
    begin
        ReturnValue := 0;
        IF NOT ISNULL(JObject.GetValue(PropertyName)) THEN
            ReturnValue := DotNetInteger.Parse(JObject.GetValue(PropertyName).ToString);
    end;

    procedure DAFUpdateTrip(JObject: DotNet JObject; var pParameters: Record "LSC POS Menu Line" temporary): Boolean
    var
        JToken: DotNet JToken;
        DriverTip: Record 50075;
        PostedDriverTip: Record 50076;
        DOrder: Record "LSC Delivery Order";
        PDOrder: Record "LSC Posted Delivery Order";
        StatusTrip: Integer;
        jDateInit: Date;
        jTimeInit: Time;
        jDateEnd: Date;
        jTimeEnd: Time;
        jNewLatitude: Decimal;
        jNewLongitude: Decimal;
        NotExists: Boolean;
        resultInt: Text;
        lText001: Label 'Status in API %1';
        PaqExitosa: Boolean;
        Index: Integer;
    begin
        IF NOT DriverTip.GET(pParameters."Current-RECEIPT") THEN
            EXIT(FALSE);

        resultInt := oDataConection.GetValueAsText(JObject, 'result');

        IF resultInt = '0' THEN BEGIN
            NotExists := (oDataConection.GetValueAsText(JObject, 'statusCode') = '404');
            IF NOT NotExists THEN
                EXIT(FALSE);
        END;

        IF NOT NotExists THEN
            JToken := JObject.SelectToken('data');

        IF NotExists THEN
            //StatusTrip := 5
            StatusTrip := -1
        ELSE
            StatusTrip := oDataConection.GetValueAsInteger(JToken, 'idStatus');

        DriverTip.Comment := '';
        DriverTip."CallCenter WS Status" := DriverTip."CallCenter WS Status"::"Changed-Not Sent";

        CASE StatusTrip OF
            -1:
                BEGIN
                    IF (DriverTip."Trip. Status" = DriverTip."Trip. Status"::"No Started") AND
                      (DriverTip."General Status" = DriverTip."General Status"::ERROR) THEN BEGIN
                        DriverTip.Sent := FALSE;
                        DriverTip."General Status" := DriverTip."General Status"::InProcess;
                        DriverTip.MODIFY;
                    END;
                END;
            1, 2:
                BEGIN
                    IF DriverTip."Trip. Status" = DriverTip."Trip. Status"::"No Started" THEN BEGIN
                        DriverTip."Trip. Status" := DriverTip."Trip. Status"::"Search Driver";
                        DriverTip."General Status" := DriverTip."General Status"::InProcess;
                        DriverTip.Sent := TRUE;
                        DriverTip.MODIFY;
                    END;
                END;
            3:
                BEGIN
                    if not (DriverTip."Trip. Status" = DriverTip."Trip. Status"::"Assigned Driver") then begin
                        DriverTip."Trip. Status" := DriverTip."Trip. Status"::"Assigned Driver";
                        DriverTip."General Status" := DriverTip."General Status"::InProcess;
                        DriverTip.Sent := TRUE;
                        DriverTip.MODIFY;
                    end;
                END;
            4:
                BEGIN
                    DriverTip."Trip. Status" := DriverTip."Trip. Status"::"Trip Finalized";
                    DriverTip.Sent := TRUE;
                    jDateInit := oDataConection.GetValueAsDate(JToken, 'collectedAtDate');
                    jTimeInit := oDataConection.GetValueAsTime(JToken, 'collectedAtTime');
                    jDateEnd := oDataConection.GetValueAsDate(JToken, 'deliveredAtDate');
                    jTimeEnd := oDataConection.GetValueAsTime(JToken, 'deliveredAtTime');
                    IF jDateInit <> 0D THEN
                        DriverTip."Trip Open Time" := CREATEDATETIME(jDateInit, jTimeInit);

                    IF jDateEnd <> 0D THEN
                        DriverTip."Trip Finalize Time" := CREATEDATETIME(jDateEnd, jTimeEnd);

                    DriverTip."General Status" := DriverTip."General Status"::Completed;
                    DriverTip.MODIFY;
                END;
            5, 8:
                BEGIN
                    //IF StatusTrip = 8 THEN BEGIN
                    DriverTip.Sent := TRUE;
                    DriverTip."Trip. Status" := DriverTip."Trip. Status"::"Cancelled in APP";
                    DriverTip."General Status" := DriverTip."General Status"::Cancelled;
                    DriverTip.Comment := STRSUBSTNO(lText001, FORMAT(StatusTrip));
                    DriverTip.MODIFY;
                    //END;
                END;
            6:
                BEGIN
                    IF DriverTip."Trip. Status" <> DriverTip."Trip. Status"::"Search Driver" THEN BEGIN
                        DriverTip.Sent := TRUE;
                        DriverTip."General Status" := DriverTip."General Status"::InProcess;
                        DriverTip."Trip. Status" := DriverTip."Trip. Status"::"Search Driver";
                        IF NOT DOrder.GET(DriverTip."Order No.") AND NOT PDOrder.GET(DriverTip."Order No.") THEN
                            DriverTip."Trip. Status" := DriverTip."Trip. Status"::"Cancelled In CC";
                        DriverTip.MODIFY;
                    END;
                END;
        END;

        //ORDENCREADA = 1; ORDENENCOLA = 2; ORDENASIGNADA = 3; ORDENFINALIZADA = 4; ORDENCANCELADA = 5;ORDENSINREASIGNAR = 6;ORDENCONPROBLEMA = 7, FINALIZADO SIN APP=8
    end;

    procedure SaveXML(pParameter: Record "LSC POS Menu Line")
    var
        FileMgt: Codeunit "File Management";
        FilterString: Text;
        FileSystem: DotNet StreamWriter;
    begin
        FilterString := 'C:\temp\WSFSN\' + pParameter."Primary Key" + pParameter.Parameter + '.xml';
        FileSystem := FileSystem.StreamWriter(FilterString);
        FileSystem.Write(SRFEMVVALUE);
        FileSystem.Close();
    end;
}


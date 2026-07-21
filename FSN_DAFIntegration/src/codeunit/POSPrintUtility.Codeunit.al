codeunit 50047 "POS Print Utility" ///99008903
{
    SingleInstance = true;

    var
        POSSESSION: Codeunit "LSC POS Session";
        GlobalBearer: Text;
        DAFIntegration: Codeunit "FSN DAF Integration";
        GlobalParameter: Record "FSN Parameter";

    procedure FillPrintCIDDelivery(var pCashDeclTmp3: Record "LSC POS Cash Declaration" temporary; pPosTrans: Record "LSC POS Transaction")
    var
        DeliveryTrip_l: Record "FSN Delivery Trip";
        TransPayment: Record "LSC Trans. Payment Entry";
        TransHdr: Record "LSC Transaction Header";
        TenderTypeStp: Record "LSC Tender Type Setup";
        TenderType_l: Record "LSC Tender Type";
        DelFuncExt: Codeunit "FSN Delivery Func. Extend";
    begin
        pCashDeclTmp3.RESET;
        pCashDeclTmp3.DELETEALL;
        CLEAR(pCashDeclTmp3);

        DeliveryTrip_l.RESET;
        DeliveryTrip_l.SETRANGE(DeliveryTrip_l."Store No.", POSSESSION.StoreNo);
        //DeliveryTrip_l.SETRANGE(DeliveryTrip_l."POS Terminal No.",POSSESSION.TerminalNo);
        DeliveryTrip_l.SETRANGE(DeliveryTrip_l."Trip. Status", DeliveryTrip_l."Trip. Status"::"Trip Starting");
        DeliveryTrip_l.SETRANGE(DeliveryTrip_l."General Status", DeliveryTrip_l."General Status"::InProcess);
        IF DeliveryTrip_l.FIND('-') THEN
            REPEAT
                TransHdr.RESET;
                TransHdr.SETCURRENTKEY("Receipt No.", Date);
                TransHdr.SETRANGE(TransHdr."Receipt No.", DeliveryTrip_l."Order No.");
                IF TransHdr.FINDFIRST THEN BEGIN
                    TransPayment.RESET;
                    TransPayment.SETCURRENTKEY("Store No.", "POS Terminal No.", "Transaction No.", "Line No.");
                    TransPayment.SETRANGE(TransPayment."Store No.", TransHdr."Store No.");
                    TransPayment.SETRANGE(TransPayment."POS Terminal No.", TransHdr."POS Terminal No.");
                    TransPayment.SETRANGE(TransPayment."Transaction No.", TransHdr."Transaction No.");
                    IF TransPayment.FINDFIRST THEN
                        REPEAT
                            IF TenderTypeStp.GET(TransPayment."Tender Type") AND
                              DelFuncExt.VerifyTenderForDriverAmt(TenderTypeStp, 0) THEN BEGIN
                                IF NOT pCashDeclTmp3.GET(pPosTrans."Receipt No.", TransPayment."Tender Type", TransPayment."Currency Code", TransPayment."Card No.") THEN BEGIN
                                    pCashDeclTmp3.INIT;
                                    pCashDeclTmp3."Receipt No." := pPosTrans."Receipt No.";
                                    pCashDeclTmp3."Tender Type" := TransPayment."Tender Type";
                                    pCashDeclTmp3."Currency Code" := TransPayment."Currency Code";
                                    pCashDeclTmp3."Card No." := TransPayment."Card No.";
                                    pCashDeclTmp3.Description := COPYSTR(TenderTypeStp.Description + '(En Ruta)', 1, MAXSTRLEN(pCashDeclTmp3.Description));
                                    IF TenderType_l.GET(TransPayment."Store No.", TransPayment."Tender Type") THEN
                                        pCashDeclTmp3.Description := COPYSTR(TenderType_l.Description + '(En Ruta)', 1, MAXSTRLEN(pCashDeclTmp3.Description));
                                    pCashDeclTmp3."First Float Entry" := TenderTypeStp."FSN Function in CC" = TenderTypeStp."FSN Function in CC"::Change;
                                    pCashDeclTmp3.INSERT;
                                END;
                                pCashDeclTmp3.Amount += TransPayment."Amount Tendered";
                                pCashDeclTmp3.MODIFY;
                            END;
                        UNTIL TransPayment.NEXT = 0;
                END;
                IF DeliveryTrip_l.Change > 0 THEN BEGIN
                    pCashDeclTmp3.SETRANGE(pCashDeclTmp3."First Float Entry", TRUE);
                    IF pCashDeclTmp3.FIND('-') THEN BEGIN
                        pCashDeclTmp3.Amount += DeliveryTrip_l.Change;
                        pCashDeclTmp3.MODIFY;
                    END;
                    pCashDeclTmp3.RESET;
                END;
            UNTIL DeliveryTrip_l.NEXT = 0;
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
        ValueInt: Integer;
    begin
        if RequestID = 'RUNPAGEDAF' then begin
            if Evaluate(ValueInt, XMLResponse) then;
            FinalizeTripInDAF(XMLRequest, '', ValueInt, MsgResult);

        end;
    end;

    procedure FinalizeTripInDAF(pDriver: Code[20]; pStore: Code[10]; pTrip: Integer; var RESTULTxt: Text): Boolean
    var
        DelDriverTrip: Record "LSC Delivery Driver Trip";
        POSMenuLineTMP: Record "LSC POS Menu Line" temporary;
        JSonString: Text;
        Path: Text;
        url: Text;
        ContentType: Text[50];
        OdataCNN: Codeunit "OData Conexion 2";
        Ok: Boolean;
        Response: Text;
        JArray: DotNet JArray;
        JObject: DotNet JObject;
        JToken: DotNet JToken;
        JTokenChild: DotNet JToken;
        WindowsJson: Codeunit "FSN Windows Forms NET";
        pDataType: Option String,Decimal,Int,Bool;
        lText001: Label 'Cant be stablish conextion. %1';
        lText002: Label 'Token not found';
    begin
        /*DelDriverTrip.GET(pDriver,pStore,pTrip);
        DelDriverTrip.TESTFIELD(Status,DelDriverTrip.Status::Closed);
        DelDriverTrip."Date Finalized" := TODAY;
        DelDriverTrip."Time Finalized" := TIME;
        
        DelDriverTrip.TESTFIELD(DelDriverTrip."DAF Trip No.");
        */
        GlobalParameter.GET('DAF', 'DAF_API');


        GlobalBearer := GetTokenAPI;
        IF GlobalBearer = '' THEN BEGIN
            MESSAGE('No se puede acceder a DAF');
            EXIT(FALSE);
        END;

        POSMenuLineTMP.RESET;
        CLEAR(POSMenuLineTMP);
        POSMenuLineTMP.Command := 'DAF_API';
        POSMenuLineTMP."Post Command" := 'ENDTRIP';
        POSMenuLineTMP."POS Help ID" := 'PUT';
        POSMenuLineTMP.INSERT;

        Path := GlobalParameter."Web Uri" + 'Route/FinishRouteNAV';
        url := GlobalParameter."Web Uri" + 'Route/FinishRouteNAV';
        ContentType := 'application/json';

        WindowsJson.ClearJsonNote();
        WindowsJson.AddSimpleJsonNote('idRoute', FORMAT(pTrip), pDataType::Int);
        WindowsJson.AddSimpleJsonNote('idMotorcyclist', pDriver, pDataType::String);
        WindowsJson.AddSimpleJsonNote('Date', (FORMAT(DATE2DMY(TODAY, 3)) + '-' +
                                                   FORMAT(DATE2DMY(TODAY, 2)) + '-' +
                                                   FORMAT(DATE2DMY(TODAY, 1))), pDataType::String);
        WindowsJson.AddSimpleJsonNote('staffId', POSSESSION.StaffID(), pDataType::String);
        WindowsJson.AddSimpleJsonNote('Time', (FORMAT(TIME, 2, '<Hours24,2>') + ':' +
                                                   FORMAT(TIME, 2, '<Minutes,2>') + ':' +
                                                   FORMAT(TIME, 2, '<Seconds,2>') + '.0'), pDataType::String);

        JSonString := WindowsJson.CloseGetJsonNote();

        /*JSonString :=
        '{' +
             '"idRoute": 129,' +
             '"idMotorcyclist": "01363887-0",' +
             '"staffId": "11938",' +
             '"Date": "2021-01-06",' +
             '"Time": "13:20:00"' +
        '}';*/

        OdataCNN.InitRequestGlobals('', ContentType, url, GlobalBearer, Path, JSonString);
        COMMIT;
        Ok := OdataCNN.RUN(POSMenuLineTMP);

        Response := OdataCNN.GetResponseGlobals();

        RESTULTxt := Response;
        EXIT(RESTULTxt = 'OK');

    end;

    local procedure GetTokenAPI(): Text
    var
        POSMenuLineTMP: Record "LSC POS Menu Line" temporary;
        JSonString: Text;
        Path: Text;
        url: Text;
        ContentType: Text[50];
        OdataCNN: Codeunit "OData Conexion 2";
        Ok: Boolean;
    begin
        POSMenuLineTMP.RESET;
        CLEAR(POSMenuLineTMP);
        POSMenuLineTMP.Command := 'DAF_API';
        POSMenuLineTMP."Post Command" := 'GETTOKEN';
        POSMenuLineTMP."POS Help ID" := 'POST';
        POSMenuLineTMP.INSERT;

        Path := GlobalParameter."Web Uri" + 'Motorcyclist/Login?' + GlobalParameter.Valor; //Credentials
        url := GlobalParameter."Web Uri" + 'Motorcyclist/Login';
        ContentType := 'application/json';

        OdataCNN.InitRequestGlobals('', ContentType, url, '', Path, '');
        COMMIT;
        Ok := OdataCNN.RUN(POSMenuLineTMP);

        EXIT(OdataCNN.GetResponseGlobals());
    end;

}


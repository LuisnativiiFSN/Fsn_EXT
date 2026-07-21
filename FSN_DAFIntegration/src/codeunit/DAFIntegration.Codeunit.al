codeunit 50043 "FSN DAF Integration" //50350
{


    TableNo = "LSC POS Menu Line";
    SingleInstance = true;
    trigger OnRun()
    begin
        InicializeGlobalsDAF;
        // SendOrders;
    end;

    var
        GlobalBearer: Text;
        RetailSetup: Record "LSC Retail Setup";
        FSNSetup: Record "FSN Fasani Setup";
        GENERAL_: Label 'GENERAL';
        EMPTY_: Label 'VACIO';
        TIPOLOGIA_: Label 'TIPOLOGIA';
        GlobalParametes: Record "FSN Parameter";
        DeliveryFunctionsExtend: Codeunit "FSN Delivery Func. Extend";
        Text001: Label '%1 %2 %3';
        POSSESSION: Codeunit "LSC POS Session";
        Text002: Label 'Unauthorized for use DAF';
        Text003: Label 'Cant be stablish conextion. %1';
        Text004: Label 'Token not found';
        TokenLastTime: Time;
        TokenLastDate: Date;
        Text005: Label '%1 not exists. %2 %3';
        GlobalTokenDAF: Text;
        GlobalLastTimeTokenDAF: Time;
        GlobalLastDateTokenDAF: Date;

    procedure SendOrders()
    var
        DeliveryTrips: Record "FSN Delivery Trip";
        PostedTrips: Record "FSN Posted Delivery Trip";
        DateTimeCheck: DateTime;
        DelOrder: Record "LSC Delivery Order";
    begin
        CLEAR(GlobalBearer);
        InicializeGlobalsDAF;
        IF NOT GlobalParametes.Activo THEN
            EXIT;
        GlobalBearer := GetTokenAPIDAF;
        IF GlobalBearer = '' THEN
            EXIT;

        //CheckInvoice
        // SetTimeInvoice;

        //Create in API
        DeliveryTrips.RESET;
        DeliveryTrips.SETCURRENTKEY("Trip. Status", "General Status", "Restaurant WS Estatus");
        DeliveryTrips.SETRANGE(DeliveryTrips."Trip. Status", DeliveryTrips."Trip. Status"::"No Started");
        IF DeliveryTrips.FINDSET(TRUE, FALSE) THEN
            REPEAT
                SendOrderDAF(DeliveryTrips, TRUE);
            UNTIL DeliveryTrips.NEXT = 0;

        COMMIT;

        //Cancel in API
        DeliveryTrips.RESET;
        DeliveryTrips.SETCURRENTKEY("Trip. Status", "General Status", "Restaurant WS Estatus");
        DeliveryTrips.SETFILTER(DeliveryTrips."General Status", '<>%1', DeliveryTrips."General Status"::Cancelled);
        DeliveryTrips.SETFILTER(DeliveryTrips."Trip. Status", '%1|%2|%3'
                                , DeliveryTrips."Trip. Status"::"Cancelled In CC"
                                , DeliveryTrips."Trip. Status"::"Cancelled In Rest."
                                , DeliveryTrips."Trip. Status"::"Cancelled in APP");
        IF DeliveryTrips.FINDSET(TRUE, FALSE) THEN
            REPEAT
                CancelOrderDAF(DeliveryTrips, FALSE);
            UNTIL DeliveryTrips.NEXT = 0;

        COMMIT;

        //Modify in API
        DeliveryTrips.RESET;
        DeliveryTrips.SETCURRENTKEY("Trip. Status", "General Status", "Restaurant WS Estatus");
        DeliveryTrips.SETRANGE(DeliveryTrips."Trip. Status", DeliveryTrips."Trip. Status"::Modified);
        DeliveryTrips.SETRANGE(DeliveryTrips.Sent, TRUE);
        IF DeliveryTrips.FINDSET(TRUE, FALSE) THEN
            REPEAT
                SendOrderDAF(DeliveryTrips, FALSE);
            UNTIL DeliveryTrips.NEXT = 0;


        //Conversion takeaway (Cancel in API)
        DeliveryTrips.RESET;
        DeliveryTrips.SETCURRENTKEY("Trip. Status", "General Status", "Restaurant WS Estatus");
        DeliveryTrips.SETFILTER(DeliveryTrips."General Status", '<>%1', DeliveryTrips."General Status"::Void);
        DeliveryTrips.SETRANGE(DeliveryTrips."Trip. Status", DeliveryTrips."Trip. Status"::"Changed To Takeaway");
        DeliveryTrips.SETRANGE(DeliveryTrips.Sent, TRUE);
        IF DeliveryTrips.FINDSET(TRUE, FALSE) THEN
            REPEAT
                CancelOrderDAF(DeliveryTrips, TRUE);
            UNTIL DeliveryTrips.NEXT = 0;

        COMMIT;

        //Check status in API
        DateTimeCheck := CREATEDATETIME(TODAY, (TIME - 10800000));//3 hour

        DeliveryTrips.RESET;
        DeliveryTrips.SETCURRENTKEY("Trip. Status", "General Status", "Restaurant WS Estatus");
        DeliveryTrips.SETRANGE(DeliveryTrips."General Status", DeliveryTrips."General Status"::InProcess);
        DeliveryTrips.SETFILTER(DeliveryTrips."Trip. Status", '%1|%2'
                                , DeliveryTrips."Trip. Status"::"Search Driver"
                                , DeliveryTrips."Trip. Status"::"Assigned Driver");
        IF DeliveryTrips.FINDSET(TRUE, FALSE) THEN
            REPEAT
                IF DeliveryTrips."Confirm Time" < DateTimeCheck THEN
                    CheckTrip(DeliveryTrips);
            UNTIL DeliveryTrips.NEXT = 0;

        DeliveryTrips.RESET;
        DeliveryTrips.SETCURRENTKEY("Trip. Status", "General Status", "Restaurant WS Estatus");
        DeliveryTrips.SETRANGE(DeliveryTrips."General Status", DeliveryTrips."General Status"::ERROR);
        DeliveryTrips.SETRANGE(DeliveryTrips."Trip. Status", DeliveryTrips."Trip. Status"::"No Started");
        IF DeliveryTrips.FINDSET(TRUE, FALSE) THEN
            REPEAT
                CheckTrip(DeliveryTrips);
            UNTIL DeliveryTrips.NEXT = 0;

        COMMIT;

        //Posted in NAV
        DeliveryTrips.RESET;
        DeliveryTrips.SETCURRENTKEY("Trip. Status", "General Status", "Restaurant WS Estatus");
        DeliveryTrips.SETFILTER(DeliveryTrips."General Status", '%1|%2|%3'
                                  , DeliveryTrips."General Status"::Cancelled
                                  , DeliveryTrips."General Status"::Completed
                                  , DeliveryTrips."General Status"::Void);
        IF DeliveryTrips.FIND('-') THEN
            REPEAT

                IF (DeliveryTrips."General Status" = DeliveryTrips."General Status"::Cancelled) OR
                    ((DeliveryTrips."General Status" = DeliveryTrips."General Status"::Void) AND NOT DelOrder.GET(DeliveryTrips."Order No.")) OR
                    ((DeliveryTrips."General Status" = DeliveryTrips."General Status"::Completed) AND
                    (DeliveryTrips."Status API" IN [DeliveryTrips."Status API"::SentTimeInvoice])) OR
                    ((DeliveryTrips."General Status" = DeliveryTrips."General Status"::Completed) AND
                    (DeliveryTrips."Sup Type Order" > 1))

                THEN BEGIN

                    PostedTrips.TRANSFERFIELDS(DeliveryTrips);
                    PostedTrips."CallCenter WS Status" := PostedTrips."CallCenter WS Status"::"Changed-Sent";
                    IF NOT PostedTrips.INSERT THEN
                        PostedTrips.MODIFY;

                    DeliveryTrips.DELETE;
                END;
            UNTIL DeliveryTrips.NEXT = 0;
    end;

    procedure CheckTrip(pDeliveryTrip: Record "FSN Delivery Trip")
    var
        POSMenuLineTMP: Record "LSC POS Menu Line" temporary;
        JSonString: Text;
        Path: Text;
        url: Text;
        ContentType: Text[50];
        OdataCNN: Codeunit "OData Conexion 2";
        Ok: Boolean;
        Response: Text;
    begin
        POSMenuLineTMP.RESET;
        CLEAR(POSMenuLineTMP);
        POSMenuLineTMP."Current-RECEIPT" := pDeliveryTrip."Order No.";
        POSMenuLineTMP.Command := 'DAF_API';
        POSMenuLineTMP."Post Command" := 'CHECKORDER';
        POSMenuLineTMP."POS Help ID" := 'GET';
        POSMenuLineTMP.INSERT;

        IF STRPOS(pDeliveryTrip."Order No.", '#') > 0 THEN
            Path := GlobalParametes."Web Uri" + 'Order/GetOrderId?noOrder=' +
              COPYSTR(pDeliveryTrip."Order No.", 1, STRPOS(pDeliveryTrip."Order No.", '#') - 1) + '%23' + COPYSTR(pDeliveryTrip."Order No.", STRPOS(pDeliveryTrip."Order No.", '#') + 1)
        ELSE
            Path := GlobalParametes."Web Uri" + 'Order/GetOrderId?noOrder=' + pDeliveryTrip."Order No.";

        url := GlobalParametes."Web Uri" + 'Order/GetOrderId';
        ContentType := 'application/json';

        OdataCNN.InitRequestGlobals('', ContentType, url, GlobalBearer, Path, '');
        COMMIT;
        Ok := OdataCNN.RUN(POSMenuLineTMP);

        Response :=
          OdataCNN.GetResponseGlobals();
    end;

    procedure UpdateDateInvoice(TransHeader: Record "LSC Transaction Header"; DTETransa: Record "FSN DTE Transaction Header")
    var
        POSMenuLineTMP: Record "LSC POS Menu Line" temporary;
        JSonString: Text;
        Path: Text;
        url: Text;
        ContentType: Text[50];
        OdataCNN: Codeunit "OData Conexion 2";
        Ok: Boolean;
        Response: Text;
        WindowsJson: Codeunit "FSN Windows Forms NET";
        pDataType: Option String,Decimal,Int,Bool;
        DelTrip: Record "FSN Delivery Trip";
    begin
        InicializeGlobalsDAF;
        GlobalBearer := GetTokenAPIDAF;

        WindowsJson.ClearJsonNote();
        WindowsJson.AddSimpleJsonNote('noOrder', TransHeader."Receipt No.", pDataType::String);
        WindowsJson.AddSimpleJsonNote('printDate', (FORMAT(DATE2DMY(TransHeader.Date, 3)) + '-' +
                                                   FORMAT(DATE2DMY(TransHeader.Date, 2)) + '-' +
                                                   FORMAT(DATE2DMY(TransHeader.Date, 1))), pDataType::String);
        WindowsJson.AddSimpleJsonNote('printTime', Format(TransHeader.Time), pDataType::String);
        WindowsJson.AddSimpleJsonNote('transaction_No', Format(TransHeader."Transaction No."), pDataType::String);
        WindowsJson.AddSimpleJsonNote('dteInvoice', DTETransa."DTE Invoice", pDataType::String);
        WindowsJson.AddSimpleJsonNote('dteAuthorization', DTETransa."DTE AuthNumber", pDataType::String);
        WindowsJson.AddSimpleJsonNote('postTerminalNum', DTETransa."POS Terminal No.", pDataType::String);
        JSonString := WindowsJson.CloseGetJsonNote();
        POSMenuLineTMP.RESET;
        CLEAR(POSMenuLineTMP);

        POSMenuLineTMP."Current-RECEIPT" := TransHeader."Receipt No.";
        POSMenuLineTMP.Command := 'DAF_API';
        POSMenuLineTMP."Post Command" := 'UpdateDateInvoice';
        POSMenuLineTMP."POS Help ID" := 'PUT';
        POSMenuLineTMP.INSERT;

        Path := GlobalParametes."Web Uri" + 'Order/UpdateDateInvoice';
        url := GlobalParametes."Web Uri" + 'Order/UpdateDateInvoice';
        ContentType := 'application/json';

        OdataCNN.InitRequestGlobals('', ContentType, url, GlobalBearer, Path, JSonString);
        COMMIT;
        Ok := OdataCNN.RUN(POSMenuLineTMP);

        Response := OdataCNN.GetResponseGlobals();

        if DelTrip.Get(TransHeader."Receipt No.") then begin
            if DelTrip."POS Terminal No." <> DTETransa."POS Terminal No." then begin
                DelTrip."POS Terminal No." := DTETransa."POS Terminal No.";
                DelTrip.MODIFY;
            end;
        end;
    end;

    procedure CancelOrderDAF(pDelTrip: Record "FSN Delivery Trip"; pIsConvert: Boolean)
    var
        POSMenuLineTMP: Record "LSC POS Menu Line" temporary;
        JSonString: Text;
        Path: Text;
        url: Text;
        ContentType: Text[50];
        OdataCNN: Codeunit "OData Conexion 2";
        Ok: Boolean;
        Response: Text;
    begin
        IF pDelTrip."Trip. Status" = pDelTrip."Trip. Status"::"Cancelled in APP" THEN BEGIN
            pDelTrip."General Status" := pDelTrip."General Status"::Cancelled;
            pDelTrip.MODIFY;
            EXIT;
        END;

        POSMenuLineTMP.RESET;
        CLEAR(POSMenuLineTMP);
        POSMenuLineTMP.Command := 'DAF_API';
        POSMenuLineTMP."Post Command" := 'CANCELORDER';
        POSMenuLineTMP."POS Help ID" := 'PUT';
        POSMenuLineTMP.INSERT;

        Path := GlobalParametes."Web Uri" + 'Order/CancelOrder?IdOrder=' + pDelTrip."Order No.";
        url := GlobalParametes."Web Uri" + 'Order/CancelOrder';
        ContentType := 'application/json';

        OdataCNN.InitRequestGlobals('', ContentType, url, GlobalBearer, Path, '');
        COMMIT;
        Ok := OdataCNN.RUN(POSMenuLineTMP);

        Response :=
          OdataCNN.GetResponseGlobals();

        IF NOT pIsConvert THEN
            pDelTrip."General Status" := pDelTrip."General Status"::ERROR;

        IF Response = 'OK' THEN BEGIN
            pDelTrip."General Status" := pDelTrip."General Status"::Cancelled;
            IF pIsConvert THEN
                pDelTrip."General Status" := pDelTrip."General Status"::Void;

            pDelTrip.MODIFY;
        END;
    end;

    procedure SendOrderDAF(pDeliveryTripTMP: Record "FSN Delivery Trip"; pIsNew: Boolean)
    var
        JSonString: Text;
        ResponseWS: Text;
        Ok: Boolean;
        Path: Text;
        url: Text;
        ContentType: Text[50];
        OdataCNN: Codeunit "OData Conexion 2";
        POSMenuLineTMP: Record "LSC POS Menu Line" temporary;
        EMPTY: Label 'EMPTY';
        lText001: Label 'Data not exists';
        lText002: Label 'Response not Found';
        FSNSetup: Record "FSN Fasani Setup";
        lText003: Label 'Inactive in DAF';
        WindowsJson: Codeunit "FSN Windows Forms NET";
        pDataType: Option String,Decimal,Int,Bool;
        Staff_l: Record "LSC Staff";
        DTETransa: Record "FSN DTE Transaction Header";
        TransHeader: Record "LSC Transaction Header";
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line";
        Processed: Boolean;
        MsgResult: Text;
        FSNUtility: Codeunit "FSN Utility";
        sb: DotNet StringBuilder;
        xmlFinal: File;
        xmlStream: OutStream;
        TransacH: Record "LSC Transaction Header";
        infocode: Record "LSC Trans. Infocode Entry";
        ClientSec: Code[20];
        subCustomer: Record Customer;
        DelStreet: Record "LSC Delivery Street";
        StoreLink: Record "FSN Store Link";
        DelContAdr: Record "LSC Delivery Contact Address";
        Longitud: Decimal;
        Latitud: Decimal;
        PosInfocode: Record "LSC POS Trans. Infocode Entry";
        fsnParam2, fsnParam1 : Record "FSN Parameter";
        DelOrder: Record "LSC Delivery Order";
        DelStreet_l: Record "LSC Delivery Street";
        JResponse: JsonObject;
        Jtoken: JsonToken;
        Respo: Text[100];
        PostedDelivery: Record "LSC Posted Delivery Order";
        FSNWSTable: Record "FSN WebServiceTable";
        FSNParameterValue: Record "FSN Parameter";
    begin
        IF GlobalBearer = '' THEN BEGIN
            InicializeGlobalsDAF;
            GlobalBearer := GetTokenAPIDAF;
            IF GlobalBearer = '' THEN
                EXIT;
        END;
        TransHeader.Reset();
        TransHeader.SetRange("Receipt No.", pDeliveryTripTMP."Order No.");
        if TransHeader.Find('-') then
            if DTETransa.Get(TransHeader."Store No.", TransHeader."POS Terminal No.", TransHeader."Transaction No.") then;
        PosInfocode.Reset();
        PosInfocode.SetRange("Receipt No.", pDeliveryTripTMP."Order No.");
        PosInfocode.SetRange("Line No.", 40);
        PosInfocode.SetRange(Infocode, 'TEXT');
        if PosInfocode.FindSet() then begin
            if subCustomer.Get(infocode.Information) then
                ClientSec := infocode.Information;
        end;

        WindowsJson.ClearJsonNote();
        WindowsJson.AddSimpleJsonNote('noOrder', pDeliveryTripTMP."Order No.", pDataType::String);

        FSNWSTable.Reset();
        if FSNWSTable.Get(pDeliveryTripTMP."Order No.") then
            IF (FSNWSTable."Order No." <> '') and (FSNWSTable."WS Request" = 'SEND_POSTRANS_BACKUP') THEN
                WindowsJson.AddSimpleJsonNote('noOrderBitworks', FSNWSTable."Order No.", pDataType::String);

        IF pDeliveryTripTMP."Customer No." = '' THEN begin
            pDeliveryTripTMP."Customer No." := 'G1';
            WindowsJson.AddSimpleJsonNote('codeClient', pDeliveryTripTMP."Customer No.", pDataType::String);
        end else
            WindowsJson.AddSimpleJsonNote('codeClient', pDeliveryTripTMP."Customer No.", pDataType::String);
        WindowsJson.AddSimpleJsonNote('nameClient', pDeliveryTripTMP."Contact Name", pDataType::String);

        IF pDeliveryTripTMP.StaffID = '' then begin
            WindowsJson.AddSimpleJsonNote('staffId', 'F20CC', pDataType::String);
        end else
            WindowsJson.AddSimpleJsonNote('staffId', pDeliveryTripTMP.StaffID, pDataType::String);

        IF pDeliveryTripTMP."Taker Order" = '' then begin
            WindowsJson.AddSimpleJsonNote('salesStaff', 'F20CC', pDataType::String);
        end else
            WindowsJson.AddSimpleJsonNote('salesStaff', pDeliveryTripTMP."Taker Order", pDataType::String);

        IF Staff_l.GET(pDeliveryTripTMP."Taker Order") THEN
            WindowsJson.AddSimpleJsonNote('salesStaffName', Staff_l."Name on Receipt", pDataType::String)
        ELSE
            WindowsJson.AddSimpleJsonNote('salesStaffName', '', pDataType::String);
        WindowsJson.AddSimpleJsonNote('grid', pDeliveryTripTMP.Grid, pDataType::String);
        WindowsJson.AddSimpleJsonNote('routeType', pDeliveryTripTMP."Rute Type", pDataType::String);
        WindowsJson.AddSimpleJsonNote('noOrderDependent', pDeliveryTripTMP."Order No. Dependent", pDataType::String);
        WindowsJson.AddSimpleJsonNote('price', FORMAT(pDeliveryTripTMP."Order Amount", 0, '<Precision,2:2><Standard Format,2>'), pDataType::String);
        WindowsJson.AddSimpleJsonNote('change', FORMAT(pDeliveryTripTMP.Change, 0, '<Precision,2:2><Standard Format,2>'), pDataType::String);

        WindowsJson.AddSimpleJsonNote('createDate', (FORMAT(DATE2DMY(DT2DATE(pDeliveryTripTMP."Order Create DateTime"), 3)) + '-' +
                                                   FORMAT(DATE2DMY(DT2DATE(pDeliveryTripTMP."Order Create DateTime"), 2)) + '-' +
                                                   FORMAT(DATE2DMY(DT2DATE(pDeliveryTripTMP."Order Create DateTime"), 1))), pDataType::String);

        WindowsJson.AddSimpleJsonNote('createTime', (FORMAT(pDeliveryTripTMP."Order Create DateTime", 2, '<Hours24,2>') + ':' +
                                                   FORMAT(pDeliveryTripTMP."Order Create DateTime", 2, '<Minutes,2>') + ':' +
                                                   FORMAT(pDeliveryTripTMP."Order Create DateTime", 2, '<Seconds,2>') + '.0'), pDataType::String);

        WindowsJson.AddSimpleJsonNote('ActivationDate', (FORMAT(DATE2DMY(DT2DATE(pDeliveryTripTMP."Order Activate DateTime"), 3)) + '-' +
                                                   FORMAT(DATE2DMY(DT2DATE(pDeliveryTripTMP."Order Activate DateTime"), 2)) + '-' +
                                                   FORMAT(DATE2DMY(DT2DATE(pDeliveryTripTMP."Order Activate DateTime"), 1))), pDataType::String);

        WindowsJson.AddSimpleJsonNote('ActivationTime', (FORMAT(pDeliveryTripTMP."Order Activate DateTime", 2, '<Hours24,2>') + ':' +
                                                   FORMAT(pDeliveryTripTMP."Order Activate DateTime", 2, '<Minutes,2>') + ':' +
                                                   FORMAT(pDeliveryTripTMP."Order Activate DateTime", 2, '<Seconds,2>') + '.0'), pDataType::String);

        WindowsJson.AddSimpleJsonNote('adress', pDeliveryTripTMP."Order Address", pDataType::String);
        WindowsJson.AddSimpleJsonNote('adressType', FORMAT(pDeliveryTripTMP."Address Type"), pDataType::String);
        WindowsJson.AddSimpleJsonNote('referencePoint', pDeliveryTripTMP."Point Ref", pDataType::String);
        WindowsJson.AddSimpleJsonNote('latitude', FORMAT(pDeliveryTripTMP.Latitude, 0, '<Precision,10:10><Standard Format,2>'), pDataType::String);
        WindowsJson.AddSimpleJsonNote('longitude', FORMAT(pDeliveryTripTMP.Longitude, 0, '<Precision,10:10><Standard Format,2>'), pDataType::String);
        WindowsJson.AddSimpleJsonNote('phoneNumber', pDeliveryTripTMP."Phone No.", pDataType::String);
        WindowsJson.AddSimpleJsonNote('idStore', pDeliveryTripTMP."Store No.", pDataType::String);//1601
        WindowsJson.AddSimpleJsonNote('transationNo', FORMAT(pDeliveryTripTMP."Trans. No."), pDataType::String);
        WindowsJson.AddSimpleJsonNote('postTerminalNum', pDeliveryTripTMP."POS Terminal No.", pDataType::String);
        WindowsJson.AddSimpleJsonNote('confirmDate', (FORMAT(DATE2DMY(DT2DATE(pDeliveryTripTMP."Confirm Time"), 3)) + '-' +
                                                   FORMAT(DATE2DMY(DT2DATE(pDeliveryTripTMP."Confirm Time"), 2)) + '-' +
                                                   FORMAT(DATE2DMY(DT2DATE(pDeliveryTripTMP."Confirm Time"), 1))), pDataType::String);

        WindowsJson.AddSimpleJsonNote('confirmTime', (FORMAT(pDeliveryTripTMP."Confirm Time", 2, '<Hours24,2>') + ':' +
                                                   FORMAT(pDeliveryTripTMP."Confirm Time", 2, '<Minutes,2>') + ':' +
                                                   FORMAT(pDeliveryTripTMP."Confirm Time", 2, '<Seconds,2>') + '.0'), pDataType::String);

        WindowsJson.AddSimpleJsonNote('priority', FORMAT(pDeliveryTripTMP.Priority), pDataType::String);
        WindowsJson.AddSimpleJsonNote('paymentMotorcyclist', FORMAT(pDeliveryTripTMP."Trip Amount", 0, '<Precision,2:2><Standard Format,2>'), pDataType::String);
        WindowsJson.AddSimpleJsonNote('CardinalPoint', pDeliveryTripTMP."Cardinal Point", pDataType::String);
        WindowsJson.AddSimpleJsonNote('PaymentType', pDeliveryTripTMP."Payment Name", pDataType::String);
        WindowsJson.AddSimpleJsonNote('clusterIdentifier', pDeliveryTripTMP."Group ID", pDataType::String);
        WindowsJson.AddSimpleJsonNote('groupingCounter', FORMAT(pDeliveryTripTMP."Group Quantity"), pDataType::String);
        WindowsJson.AddSimpleJsonNote('codeClient2', ClientSec, pDataType::String);
        WindowsJson.AddSimpleJsonNote('dteInvoice', DTETransa."DTE Invoice", pDataType::String);
        WindowsJson.AddSimpleJsonNote('dteAuthorization', DTETransa."DTE AuthNumber", pDataType::String);
        WindowsJson.AddSimpleJsonNote('SalesEntry', GetOrderType(pDeliveryTripTMP), pDataType::Int);
        if DelOrder.Get(pDeliveryTripTMP."Order No.") then begin
            if DelOrder."Order Type Option" = 4 then
                WindowsJson.AddSimpleJsonNote('deliveryType', '2', pDataType::String)
            else
                WindowsJson.AddSimpleJsonNote('deliveryType', '1', pDataType::String);
            DelStreet_l.RESET;
            DelStreet_l.SETRANGE(DelStreet_l."FSN Alter Key", DelOrder."FSN Alter Key");
            IF DelStreet_l.FINDFIRST THEN begin
                WindowsJson.AddSimpleJsonNote('alterKey', format(DelOrder."FSN Alter Key"), pDataType::Int);
                WindowsJson.AddSimpleJsonNote('StreetName', DelStreet_l."FSN Street Name", pDataType::String);
            end;
        end else begin
            if PostedDelivery.Get(pDeliveryTripTMP."Order No.") then begin
                if PostedDelivery."Order Type Option" = 4 then
                    WindowsJson.AddSimpleJsonNote('deliveryType', '2', pDataType::String)
                else
                    WindowsJson.AddSimpleJsonNote('deliveryType', '1', pDataType::String);
            end;
            DelStreet_l.RESET;
            DelStreet_l.SETRANGE(DelStreet_l."FSN Street Name", PostedDelivery."FSN Street Name");
            IF DelStreet_l.FINDFIRST THEN begin
                WindowsJson.AddSimpleJsonNote('alterKey', format(DelStreet_l."FSN Alter Key"), pDataType::Int);
                WindowsJson.AddSimpleJsonNote('StreetName', DelStreet_l."FSN Street Name", pDataType::String);
            end;
        end;

        if FSNParameterValue.Get('PROCESS', 'ROBOT') and FSNParameterValue.Activo then begin
            WindowsJson.AddSimpleJsonNote('IsBigPackage', 'true', pDataType::Bool);
        end;

        //'IsBigPackage' //20251203

        JSonString := WindowsJson.CloseGetJsonNote();


        IF pIsNew THEN BEGIN
            Path := GlobalParametes."Web Uri" + 'Order/CreateOrder';
            url := GlobalParametes."Web Uri" + 'Order/CreateOrder';
        END ELSE BEGIN
            Path := GlobalParametes."Web Uri" + 'Order/UpdateOrder';
            url := GlobalParametes."Web Uri" + 'Order/UpdateOrder';
        END;

        ContentType := 'application/json-patch+json';

        CLEAR(POSMenuLineTMP);
        POSMenuLineTMP.Command := 'DAF_API';
        POSMenuLineTMP."Post Command" := 'NEWORDER';

        IF pIsNew THEN
            POSMenuLineTMP."POS Help ID" := 'POST'
        ELSE
            POSMenuLineTMP."POS Help ID" := 'PUT';

        POSMenuLineTMP."Current-RECEIPT" := pDeliveryTripTMP."Order No.";
        POSMenuLineTMP.INSERT;
        //16012000

        IF (POSSESSION.GetValue('ORDERDAF') <> '') then begin
            Ok := FSNSetup.GET(pDeliveryTripTMP."Store No.") AND FSNSetup."Use DAF API";

            CLEAR(OdataCNN);
            OdataCNN.InitRequestGlobals('', ContentType, url, GlobalBearer, Path, JSonString);
            COMMIT;
            Ok := OdataCNN.RUN(POSMenuLineTMP);
            ResponseWS := OdataCNN.GetResponseGlobals;
            CASE TRUE OF
                ResponseWS = 'OK':
                    BEGIN
                        pDeliveryTripTMP."General Status" := pDeliveryTripTMP."General Status"::InProcess;
                        pDeliveryTripTMP."Trip. Status" := pDeliveryTripTMP."Trip. Status"::"Search Driver";
                        pDeliveryTripTMP."CallCenter WS Status" := pDeliveryTripTMP."CallCenter WS Status"::"Changed-Not Sent";
                        pDeliveryTripTMP.Sent := TRUE;
                        pDeliveryTripTMP.Comment := '';
                        pDeliveryTripTMP.MODIFY;
                    END;
                STRPOS(ResponseWS, 'ERROR:') > 0:
                    BEGIN
                        sb := sb.StringBuilder();
                        sb.Append(JSonString);
                        if xmlFinal.Create('C:\Temp\' + pDeliveryTripTMP."Order No." + '.json') then begin
                            xmlFinal.CreateOutStream(xmlStream);
                            xmlStream.Write(sb.ToString());
                            xmlFinal.Close();
                        end;
                        IF NOT pIsNew THEN BEGIN
                            pDeliveryTripTMP."General Status" := pDeliveryTripTMP."General Status"::InProcess;
                            pDeliveryTripTMP."Trip. Status" := pDeliveryTripTMP."Trip. Status"::"Search Driver";
                            pDeliveryTripTMP."CallCenter WS Status" := pDeliveryTripTMP."CallCenter WS Status"::"Changed-Not Sent";
                            pDeliveryTripTMP.Comment := '';
                        END ELSE BEGIN
                            pDeliveryTripTMP."General Status" := pDeliveryTripTMP."General Status"::ERROR;
                            fsnParam2.Reset();
                            if fsnParam2.Get('DAFJSON', 'RESP') AND (fsnParam2.Activo) then begin
                                if JResponse.ReadFrom(ResponseWS) then
                                    if JResponse.Get('message', Jtoken) then
                                        if not Jtoken.AsValue().IsNull then
                                            Respo := CopyStr(Jtoken.AsValue().AsText(), 1, 100);
                                pDeliveryTripTMP.Comment := COPYSTR(Respo, 1, MAXSTRLEN(pDeliveryTripTMP.Comment));
                            end ELSE
                                pDeliveryTripTMP.Comment := COPYSTR(ResponseWS, 1, MAXSTRLEN(pDeliveryTripTMP.Comment));
                        END;
                        pDeliveryTripTMP.MODIFY;
                    END;
                ResponseWS = '':
                    BEGIN
                        pDeliveryTripTMP."General Status" := pDeliveryTripTMP."General Status"::ERROR;
                        pDeliveryTripTMP.Comment := COPYSTR(GETLASTERRORTEXT, 1, MAXSTRLEN(pDeliveryTripTMP.Comment));
                        pDeliveryTripTMP.MODIFY;
                    END;
                ELSE BEGIN
                    pDeliveryTripTMP."General Status" := pDeliveryTripTMP."General Status"::ERROR;
                    pDeliveryTripTMP.Comment := COPYSTR(ResponseWS, 1, MAXSTRLEN(pDeliveryTripTMP.Comment));
                    pDeliveryTripTMP.MODIFY;
                END;
            end;
        end else begin

            Ok := false;


            IF NOT Ok THEN BEGIN
                pDeliveryTripTMP."General Status" := pDeliveryTripTMP."General Status"::Void;
                pDeliveryTripTMP."Trip. Status" := pDeliveryTripTMP."Trip. Status"::"Assign Manual";
                pDeliveryTripTMP."CallCenter WS Status" := pDeliveryTripTMP."CallCenter WS Status"::"Changed-Not Sent";
                pDeliveryTripTMP.Comment := lText003;
                pDeliveryTripTMP.MODIFY;
                EXIT;
            END;
        end;
    END;

    local procedure saveJson(pJson: Text; pOrderNo: Text)
    var
        sb: DotNet StringBuilder;
        xmlFinal: File;
        xmlStream: OutStream;
    begin
        sb := sb.StringBuilder();
        sb.Append(pJson);
        if xmlFinal.Create('C:\Temp\' + pOrderNo + '.json') then begin
            xmlFinal.CreateOutStream(xmlStream);
            xmlStream.Write(sb.ToString());
            xmlFinal.Close();
        end;
    end;

    local procedure GetOrderType(pDeliveryTrip: Record "FSN Delivery Trip"): Text
    var
        type: Enum "FSN DAF OrderType";
        transLine: Record "LSC POS Trans. Line";
        OrderNo: Text;
        itemFilter: Label 'a3256|B0000757|B0000758';
    begin
        OrderNo := pDeliveryTrip."Order No.";

        transLine.Setrange("Receipt No.", OrderNo);
        transLine.SetRange("Entry Type", transLine."Entry Type"::Item);
        transLine.SetFilter(Number, itemFilter);

        case true of
            pDeliveryTrip."Customer No." = 'PV#143C23083':
                exit(Format(type::"Onlife".AsInteger()));

            OrderNo.Contains('APP'):
                exit(Format(type::"E-Commerce".AsInteger()));

            OrderNo.Contains('000PV#1000'):
                exit(Format(type::"E-Commerce".AsInteger()));

            transLine.FindSet():
                exit(Format(type::Packaging.AsInteger()));

            else
                exit(Format(type::"Call Center".AsInteger()));
        end;
    end;

    local procedure MiddleDeliveryType(deliveryTrip: Record "FSN Delivery Trip"): Text
    begin
        if deliveryTrip."Address Type" = 4 then
            exit('2')
        else
            exit('1')
        //exit(EvaluateItemParameter(deliveryTrip, 'deliveryType', '1'));//Validar funcionamiento de parametro
    end;

    procedure InicializeGlobalsDAF()
    begin
        RetailSetup.GET;
        IF GlobalParametes.GET('DAF', 'DAF_API') THEN;
    end;

    procedure GetTokenAPIDAF(): Text
    var
        POSMenuLineTMP: Record "LSC POS Menu Line" temporary;
        JSonString: Text;
        Path: Text;
        url: Text;
        ContentType: Text[50];
        OdataCNN: Codeunit "OData Conexion 2";
        Ok: Boolean;
        TokenLastTime: Time;
        TokenLastDate: Date;
    begin

        GetLastTokenDaff(GlobalBearer, TokenLastTime, TokenLastDate);
        IF (GlobalBearer = '') OR (TokenLastDate <> TODAY) THEN
            GlobalBearer := ''
        ELSE
            EXIT(GlobalBearer);

        POSMenuLineTMP.RESET;
        CLEAR(POSMenuLineTMP);
        POSMenuLineTMP.Command := 'DAF_API';
        POSMenuLineTMP."Post Command" := 'GETTOKEN';
        POSMenuLineTMP."POS Help ID" := 'POST';
        POSMenuLineTMP.INSERT;

        Path := GlobalParametes."Web Uri" + 'Motorcyclist/Login?' + GlobalParametes.Valor; //Credentials
        url := GlobalParametes."Web Uri" + 'Motorcyclist/Login';
        ContentType := 'application/json';

        OdataCNN.InitRequestGlobals('', ContentType, url, '', Path, '');
        COMMIT;
        Ok := OdataCNN.RUN(POSMenuLineTMP);

        GlobalBearer := OdataCNN.GetResponseGlobals();
        IF GlobalBearer <> '' THEN
            SetTokenDaff(GlobalBearer, TIME, TODAY);

        EXIT(GlobalBearer);

    end;

    procedure CreateTripFromDAF(pDriverID: Code[20]; pStore: Code[10]; pTripCount: Integer; var Msg: Text): Boolean
    var
        DelTripTmp: Record "FSN Delivery Trip" temporary;
        DelTrip: Record "FSN Delivery Trip";
        DelTripPosted: Record "FSN Posted Delivery Trip";
        DelOrder: Record "LSC Delivery Order";
        PosDelOrder: Record "LSC Posted Delivery Order";
        DelDriverTrip: Record "LSC Delivery Driver Trip";
        lText001: Label 'Cant be stablish conextion. %1';
        lText002: Label 'Token not found';
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
        SetCount: Integer;
        Counter1: Integer;
        lText003: Label 'Error conextion DAF';
        lText004: Label 'There is no trip in DAF for %1 %2';
        DelFuncExt: Codeunit "FSN Delivery Func. Extend";
        lText005: Label 'Driver %1 ALREADY orders assigned';
        StaffTable: Record "LSC Staff";
        lText006: Label 'Orders suggest for DAF not avaliable in POS %1';
        lText007: Label 'Trip ID isnt valid!. "Trip No. %1"';
        MsgNotOrders: Text;
    begin
        IF StaffTable.GET(pDriverID) THEN;
        DelDriverTrip.GET(pDriverID, pStore, pTripCount);

        DelTrip.RESET;
        DelTrip.SETRANGE(DelTrip."Driver ID", pDriverID);
        DelTrip.SETRANGE(DelTrip."Store No.", pStore);
        DelTrip.SETRANGE(DelTrip."Trip No. (LS Retail)", pTripCount);
        IF DelTrip.FINDFIRST THEN BEGIN
            Msg := STRSUBSTNO(lText005, StaffTable."Name on Receipt");
            EXIT(FALSE);
        END;

        DelTripTmp.RESET;
        DelTripTmp.DELETEALL;
        CLEAR(DelTripTmp);

        InicializeGlobalsDAF;
        IF NOT (GlobalParametes."Value Text 1" IN ['GETTRIP', 'GETTRIP-ENDTRIP']) OR NOT GlobalParametes.Activo THEN BEGIN
            Msg := Text002;
            EXIT(FALSE);
        END;

        GlobalBearer := GetTokenAPIDAF();
        IF GlobalBearer = '' THEN BEGIN
            Msg := STRSUBSTNO(lText001, lText002);
            EXIT(FALSE);
        END;

        POSMenuLineTMP.RESET;
        CLEAR(POSMenuLineTMP);
        POSMenuLineTMP.Command := 'DAF_API';
        POSMenuLineTMP."Post Command" := 'GETTRIP';
        POSMenuLineTMP."POS Help ID" := 'GET';
        POSMenuLineTMP.INSERT;

        Path := GlobalParametes."Web Uri" + 'Motorcyclist/GetRouteByMotorcyclistNAV?idMotorcyclist=' + pDriverID + '&store=' + pStore;
        url := GlobalParametes."Web Uri" + 'Motorcyclist/GetRouteByMotorcyclistNAV';
        ContentType := 'application/json';

        OdataCNN.InitRequestGlobals('', ContentType, url, GlobalBearer, Path, '');
        COMMIT;
        Ok := OdataCNN.RUN(POSMenuLineTMP);

        Response := '';
        Response :=
          OdataCNN.GetResponseGlobals();

        CASE TRUE OF
            Response = 'NOT':
                Msg := STRSUBSTNO(lText004, pDriverID, pStore);
            Response IN ['ERROR', '']:
                Msg := STRSUBSTNO(lText001, GETLASTERRORTEXT);
            ELSE BEGIN
                JObject := JObject.Parse(Response);
                JArray := JObject.SelectToken('detailRequests');
                IF NOT JArray.HasValues THEN BEGIN
                    Msg := STRSUBSTNO(lText004, pDriverID, pStore);
                    EXIT(FALSE);
                END;

                Counter1 := JArray.Count();
                SetCount := 0;
                WHILE Counter1 > SetCount DO BEGIN
                    JTokenChild := JArray.Item(SetCount);
                    IF NOT ISNULL(JTokenChild) THEN BEGIN
                        DelTripTmp.INIT;
                        DelTripTmp."Order No." := COPYSTR(OdataCNN.GetValueAsText(JTokenChild, 'noOrder'), 1, 20);
                        DelTripTmp."Phone No." := COPYSTR(OdataCNN.GetValueAsText(JTokenChild, 'phoneNumber'), 1, 20);
                        DelTripTmp."Contact Name" := COPYSTR(OdataCNN.GetValueAsText(JTokenChild, 'customerName'), 1, 50);
                        IF OdataCNN.GetValueAsInteger(JTokenChild, 'idStatus') = 3 THEN
                            IF NOT DelTripTmp.INSERT THEN
                                DelTripTmp.MODIFY;
                    END;
                    SetCount += 1;
                END;
            END;
        END;

        DelTripTmp.RESET;
        IF DelTripTmp.FIND('-') THEN
            REPEAT
                IF DelOrder.GET(DelTripTmp."Order No.") THEN
                    CreateTripDAF(DelOrder, TRUE)
                ELSE
                    IF PosDelOrder.GET(DelTripTmp."Order No.") THEN BEGIN
                        CLEAR(DelOrder);
                        DelOrder.TRANSFERFIELDS(PosDelOrder);
                        CreateTripDAF(DelOrder, TRUE);
                    END;

                IF DelTrip.GET(DelTripTmp."Order No.") THEN BEGIN
                    IF DelTrip."Trip. Status" IN [0, 1, 2, 6, 7, 8, 9, 10, 11] THEN BEGIN
                        //No Started,Search Driver,Assign Manual,Assigned Driver,Trip Starting,Trip Finalized
                        //,Cancelled In CC,Cancelled In Rest.,Changed To Takeaway,Order Not Found,Cancelled in APP,Modified
                        IF DelTripPosted.GET(DelTripTmp."Order No.") AND (DelTripPosted."Trip. Status" IN [5]) THEN BEGIN
                            DelTripTmp.Comment := FORMAT(DelTripPosted."Trip. Status");
                            DelTripTmp.MODIFY;
                            DelTrip.DELETE;
                        END ELSE BEGIN
                            DelTrip.VALIDATE("Trip. Status", DelTrip."Trip. Status"::"Assigned Driver");
                            DelTrip."Driver ID" := pDriverID;
                            DelTrip."Trip No. (LS Retail)" := DelDriverTrip."Trip Counter";
                            DelTrip.MODIFY;
                            DelTripTmp.DELETE;
                        END;
                    END ELSE BEGIN
                        DelTripTmp.Comment := FORMAT(DelTrip."Trip. Status");
                        DelTripTmp.MODIFY
                    END;
                END;
            UNTIL DelTripTmp.NEXT = 0;

        IF Msg <> '' THEN
            EXIT(FALSE);

        CLEAR(MsgNotOrders);
        IF DelTripTmp.FIND('-') THEN
            MsgNotOrders := STRSUBSTNO(lText006, '');
        REPEAT
            MsgNotOrders += '\' + STRSUBSTNO(Text001, DelTripTmp."Phone No.", DelTripTmp."Contact Name", DelTripTmp.Comment);
        UNTIL DelTripTmp.NEXT = 0;

        IF MsgNotOrders <> '' THEN
            Msg := MsgNotOrders;

        DelDriverTrip.GET(DelDriverTrip."Driver ID", DelDriverTrip."Store No.", DelDriverTrip."Trip Counter");
        DelDriverTrip."Functionality Type" := DelDriverTrip."Functionality Type"::Automatic;
        DelFuncExt.UpdateValuesDelDriverTripExt(DelDriverTrip);
        IF DelDriverTrip."No. of Orders" = 0 THEN
            ERROR(STRSUBSTNO(MsgNotOrders));

        DelDriverTrip."DAF Trip No." := OdataCNN.GetValueAsInteger(JObject, 'idRoute');
        IF DelDriverTrip."DAF Trip No." = 0 THEN
            ERROR(STRSUBSTNO(lText007, DelDriverTrip."DAF Trip No."));
        DelDriverTrip.MODIFY;

        EXIT(TRUE);
    end;


    procedure FinalizeTripInDAF(pDriver: Code[20]; pStore: Code[10]; pTrip: Integer; var RESTULTxt: Text): Boolean
    var
        DelDriverTrip: Record "LSC Delivery Driver Trip";
        DelTrip: Record "FSN Delivery Trip";
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
        DelDriverTrip.GET(pDriver, pStore, pTrip);
        DelDriverTrip.TESTFIELD(Status, DelDriverTrip.Status::Closed);
        DelDriverTrip."Date Finalized" := TODAY;
        DelDriverTrip."Time Finalized" := TIME;

        InicializeGlobalsDAF;
        IF NOT (GlobalParametes."Value Text 1" IN ['GETTRIP-ENDTRIP']) THEN BEGIN
            RESTULTxt := 'OK';
            EXIT(TRUE);
        END;
        DelDriverTrip.TESTFIELD(DelDriverTrip."DAF Trip No.");

        GlobalBearer := GetTokenAPIDAF;
        IF GlobalBearer = '' THEN BEGIN
            RESTULTxt := STRSUBSTNO(Text003, Text004);
            EXIT(FALSE);
        END;

        POSMenuLineTMP.RESET;
        CLEAR(POSMenuLineTMP);
        POSMenuLineTMP.Command := 'DAF_API';
        POSMenuLineTMP."Post Command" := 'ENDTRIP';
        POSMenuLineTMP."POS Help ID" := 'PUT';
        POSMenuLineTMP.INSERT;

        Path := GlobalParametes."Web Uri" + 'Route/FinishRouteNAV';
        url := GlobalParametes."Web Uri" + 'Route/FinishRouteNAV';
        ContentType := 'application/json';

        WindowsJson.ClearJsonNote();
        WindowsJson.AddSimpleJsonNote('idRoute', FORMAT(DelDriverTrip."DAF Trip No."), pDataType::Int);
        WindowsJson.AddSimpleJsonNote('idMotorcyclist', pDriver, pDataType::String);
        WindowsJson.AddSimpleJsonNote('Date', (FORMAT(DATE2DMY(DelDriverTrip."Date Finalized", 3)) + '-' +
                                                   FORMAT(DATE2DMY(DelDriverTrip."Date Finalized", 2)) + '-' +
                                                   FORMAT(DATE2DMY(DelDriverTrip."Date Finalized", 1))), pDataType::String);
        WindowsJson.AddSimpleJsonNote('staffId', POSSESSION.StaffID(), pDataType::String);
        WindowsJson.AddSimpleJsonNote('Time', (FORMAT(DelDriverTrip."Time Finalized", 2, '<Hours24,2>') + ':' +
                                                   FORMAT(DelDriverTrip."Time Finalized", 2, '<Minutes,2>') + ':' +
                                                   FORMAT(DelDriverTrip."Time Finalized", 2, '<Seconds,2>') + '.0'), pDataType::String);

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

    procedure CheckTripsFromDAF(pStore: Code[10]; var Msg: Text): Boolean
    var
        DelTripTmp: Record "FSN Delivery Trip" temporary;
        StaffTmp: Record "LSC Staff" temporary;
        Staff_l: Record "LSC Staff";
        DelTrip: Record "FSN Delivery Trip";
        DelTripPosted: Record "FSN Posted Delivery Trip";
        DelOrder: Record "LSC Delivery Order";
        PosDelOrder: Record "LSC Posted Delivery Order";
        DelDriverTrip: Record "LSC Delivery Driver Trip";
        lText001: Label 'Cant be stablish conextion. %1';
        lText002: Label 'Token not found';
        POSMenuLineTMP: Record "LSC POS Menu Line" temporary;
        DelDriverTrip_l: Record "LSC Delivery Driver Trip";
        JSonString: Text;
        Path: Text;
        url: Text;
        ContentType: Text[50];
        OdataCNN: Codeunit "OData Conexion 2";
        Ok: Boolean;
        Response: Text;
        JArrayParent: DotNet JArray;
        JArray: DotNet JArray;
        JObject: DotNet JObject;
        JToken: DotNet JToken;
        JTokenChild: DotNet JToken;
        SetCount: Integer;
        SetCountParent: Integer;
        Counter1: Integer;
        lText003: Label 'Error conextion DAF';
        lText004: Label 'There is no trip in DAF for %1 %2';
        CounterParent: Integer;
        DelFuncExt: Codeunit "FSN Delivery Func. Extend";
        lText005: Label 'Driver %1 ALREADY orders assigned';
        StaffTable: Record "LSC Staff";
        lText006: Label 'Orders suggest for DAF not avaliable in POS %1';
        lText007: Label 'Trip ID isnt valid!. "Trip No. %1"';
        MsgNotOrders: Text;
        FileRead: DotNet File;
        FilterString: Text;
        CodeError: Code[30];
        StaffStoreLinks: Record "LSC STAFF Store Link";
        lText008: Label 'NOT EXISTS';
        lText009: Label 'ORDERS NOT FOUND';
        PosDelTrip: Record "FSN Posted Delivery Trip";
    begin
        DelTripTmp.RESET;
        DelTripTmp.DELETEALL;
        CLEAR(DelTripTmp);
        StaffTmp.RESET;
        StaffTmp.DELETEALL;
        CLEAR(StaffTmp);
        InicializeGlobalsDAF;

        IF NOT (GlobalParametes."Value Text 1" IN ['GETTRIP', 'GETTRIP-ENDTRIP']) OR NOT GlobalParametes.Activo THEN BEGIN
            Msg := Text002;
            EXIT(FALSE);
        END;

        GlobalBearer := GetTokenAPIDAF;
        IF GlobalBearer = '' THEN BEGIN
            Msg := STRSUBSTNO(lText001, lText002);
            EXIT(FALSE);
        END;

        POSMenuLineTMP.RESET;
        CLEAR(POSMenuLineTMP);
        POSMenuLineTMP.Command := 'DAF_API';
        POSMenuLineTMP."Post Command" := 'GETTRIPS';
        POSMenuLineTMP."POS Help ID" := 'GET';
        POSMenuLineTMP.INSERT;

        Path := GlobalParametes."Web Uri" + 'Motorcyclist/GetMotorcyclistRoutesNAV?store=' + pStore;
        url := GlobalParametes."Web Uri" + 'Motorcyclist/GetMotorcyclistRoutesNAV';
        ContentType := 'application/json';

        OdataCNN.InitRequestGlobals('', ContentType, url, GlobalBearer, Path, '');
        COMMIT;
        Ok := OdataCNN.RUN(POSMenuLineTMP);

        Response := '';
        Response := OdataCNN.GetResponseGlobals();


        OdataCNN.InitRequestGlobals(Response, '', '', '', '', '');
        POSMenuLineTMP.Command := 'SAVEXML';
        POSMenuLineTMP.Parameter := 'GETTRIPS';
        POSMenuLineTMP.MODIFY;
        Ok := OdataCNN.RUN(POSMenuLineTMP);
        COMMIT;
        //Msg := Response;

        CASE TRUE OF
            Response = 'NOT':
                Msg := STRSUBSTNO(lText004, '', pStore);
            Response IN ['ERROR', '']:
                Msg := STRSUBSTNO(lText001, GETLASTERRORTEXT);
            ELSE BEGIN
                JObject := JObject.Parse(Response);
                JArrayParent := JObject.SelectToken('data');
                IF NOT JArrayParent.HasValues THEN BEGIN
                    Msg := STRSUBSTNO(lText004, '', pStore);
                    EXIT(FALSE);
                END;

                CounterParent := JArrayParent.Count();
                SetCountParent := 0;
                WHILE CounterParent > SetCountParent DO BEGIN
                    JObject := JArrayParent.Item(SetCountParent);
                    StaffTmp.INIT;
                    StaffTmp.ID := COPYSTR(OdataCNN.GetValueAsText(JObject, 'idMotorcyclist'), 1, 20);
                    StaffTmp."First Name" := 'OK';
                    IF NOT Staff_l.GET(StaffTmp.ID) THEN
                        StaffTmp."First Name" := lText008
                    ELSE
                        StaffTmp."Name on Receipt" := Staff_l."Name on Receipt";

                    IF StaffTmp."First Name" = 'OK' THEN BEGIN
                        JArray := JObject.SelectToken('detailRequests');
                        IF NOT JArray.HasValues THEN
                            StaffTmp."First Name" := '';
                    END;

                    StaffTmp."Continue on TS errors" := TRUE;
                    IF NOT StaffTmp.INSERT THEN
                        StaffTmp.MODIFY;

                    IF StaffTmp."First Name" = 'OK' THEN BEGIN
                        CLEAR(CodeError);
                        StaffTmp."Continue on TS errors" :=
                          InitDeliveryDriverTripFromDAF(DelDriverTrip, StaffTmp.ID, pStore, OdataCNN.GetValueAsInteger(JObject, 'idRoute'), CodeError);

                        Counter1 := JArray.Count();
                        SetCount := 0;
                        IF DelDriverTrip.Status <> DelDriverTrip.Status::Closed THEN//Already trip starting
                            WHILE (Counter1 > SetCount) AND StaffTmp."Continue on TS errors" DO BEGIN
                                JTokenChild := JArray.Item(SetCount);

                                IF NOT ISNULL(JTokenChild) AND
                                  StaffTmp."Continue on TS errors" AND
                                  (OdataCNN.GetValueAsInteger(JTokenChild, 'idStatus') <= 4) THEN BEGIN

                                    DelTripTmp."Order No." := COPYSTR(OdataCNN.GetValueAsText(JTokenChild, 'noOrder'), 1, 20);
                                    DelTripTmp."Trip No. (LS Retail)" := DelDriverTrip."Trip Counter";

                                    if PosDelTrip.Get(DelTripTmp."Order No.") then
                                        PosDelTrip.Delete(true);

                                    //ORDENCREADA = 1; ORDENENCOLA = 2; ORDENASIGNADA = 3; ORDENFINALIZADA = 4; ORDENCANCELADA = 5;ORDENSINREASIGNAR = 6;ORDENCONPROBLEMA = 7, FINALIZADO SIN APP=8
                                    IF NOT (DelTrip.GET(DelTripTmp."Order No.") AND (DelTrip."Trip. Status" = DelTrip."Trip. Status"::"Trip Starting") AND (DelOrder."Driver ID" <> '')) THEN BEGIN
                                        IF OdataCNN.GetValueAsInteger(JTokenChild, 'idStatus') <= 4 THEN
                                            IF DelOrder.GET(DelTripTmp."Order No.") THEN
                                                CreateTripDAF(DelOrder, TRUE)
                                            ELSE
                                                IF PosDelOrder.GET(DelTripTmp."Order No.") THEN BEGIN
                                                    CLEAR(DelOrder);
                                                    DelOrder.TRANSFERFIELDS(PosDelOrder);
                                                    CreateTripDAF(DelOrder, TRUE);
                                                END;

                                        IF DelTrip.GET(DelTripTmp."Order No.") THEN BEGIN
                                            IF DelTrip."Trip. Status" IN [0, 1, 2, 6, 7, 8, 9, 10, 11] THEN BEGIN
                                                IF DelTripPosted.GET(DelTripTmp."Order No.") AND (DelTripPosted."Trip. Status" IN [5]) THEN BEGIN
                                                    DelTripTmp.Comment := FORMAT(DelTripPosted."Trip. Status");
                                                    DelTrip.DELETE;
                                                END ELSE BEGIN
                                                    DelTrip.VALIDATE("Trip. Status", DelTrip."Trip. Status"::"Assigned Driver");
                                                    DelTrip."Driver ID" := DelDriverTrip."Driver ID";
                                                    DelTrip."Trip No. (LS Retail)" := DelDriverTrip."Trip Counter";
                                                    DelTrip.MODIFY;
                                                END;
                                            END;
                                        END;
                                    END;//Already in trip startin
                                END;
                                SetCount += 1;
                            END;

                        IF StaffTmp."Continue on TS errors" THEN BEGIN
                            DelFuncExt.UpdateValuesDelDriverTripExt(DelDriverTrip);
                            DelDriverTrip.TESTFIELD(DelDriverTrip."DAF Trip No.");
                            IF DelDriverTrip."No. of Orders" = 0 THEN BEGIN
                                IF StaffStoreLinks.GET(DelDriverTrip."Driver ID", DelDriverTrip."Store No.") THEN BEGIN
                                    StaffStoreLinks."On Call" := FALSE;
                                    StaffStoreLinks.MODIFY(TRUE);
                                END;
                                DelDriverTrip.DELETE;
                                StaffTmp."First Name" := lText009;
                                StaffTmp.MODIFY;
                            END ELSE BEGIN
                                DelDriverTrip.MODIFY;

                            END;
                        END ELSE BEGIN
                            StaffTmp."First Name" := CodeError;
                            StaffTmp.MODIFY;
                        END;
                    END;
                    SetCountParent += 1;
                END;//while parent
            END;
        END;

        IF Msg <> '' THEN
            EXIT(FALSE);

        CLEAR(MsgNotOrders);
        StaffTmp.RESET;
        StaffTmp.SETFILTER("First Name", '<>%1', 'OK');
        IF StaffTmp.FIND('-') THEN
            REPEAT

                IF MsgNotOrders = '' THEN
                    MsgNotOrders := STRSUBSTNO(lText006, '');
                MsgNotOrders += '\' + STRSUBSTNO(Text001, StaffTmp.ID, StaffTmp."Name on Receipt", StaffTmp."First Name");
            UNTIL StaffTmp.NEXT = 0
        ELSE
            MsgNotOrders := 'OK';

        MESSAGE(MsgNotOrders);

        EXIT(TRUE);

    end;

    local procedure InitDeliveryDriverTripFromDAF(var OldDeliveryDriverTrip: Record "LSC Delivery Driver Trip"; pDriverId: Code[20]; pStore: Code[10]; pRouteDAFID: Integer; var pErroCode: Code[30]): Boolean
    var
        StaffStoreLinks: Record "LSC STAFF Store Link";
        OldDeliveryDriverTrip2: Record "LSC Delivery Driver Trip";
        lText001: Label 'HAS ANOTHER OLD ROUTE';
        lText002: Label 'DRIVER NOT AVAILABLE';
    begin
        CLEAR(pErroCode);
        IF NOT StaffStoreLinks.GET(pDriverId, pStore) THEN BEGIN
            StaffStoreLinks.INIT();
            StaffStoreLinks."Staff ID" := pDriverId;
            StaffStoreLinks."Store No." := pStore;
            StaffStoreLinks."Delivery Driver" := TRUE;
            StaffStoreLinks."On Call" := TRUE;
            StaffStoreLinks.INSERT(TRUE);
        END;
        IF NOT StaffStoreLinks."Delivery Driver" OR NOT StaffStoreLinks."On Call" THEN BEGIN
            StaffStoreLinks."Delivery Driver" := TRUE;
            StaffStoreLinks."On Call" := TRUE;
            StaffStoreLinks.MODIFY(TRUE);
        END;

        //StaffStoreLinks.CALCFIELDS(StaffStoreLinks."Current Trip No.");
        //IF StaffStoreLinks."Current Trip No." = 0 THEN
        OldDeliveryDriverTrip.RESET;
        OldDeliveryDriverTrip.SETCURRENTKEY("Driver ID", "Store No.", "Trip Counter");
        OldDeliveryDriverTrip.SETRANGE(OldDeliveryDriverTrip."Driver ID", StaffStoreLinks."Staff ID");
        OldDeliveryDriverTrip.SETRANGE(OldDeliveryDriverTrip."Store No.", StaffStoreLinks."Store No.");
        OldDeliveryDriverTrip.SETFILTER(OldDeliveryDriverTrip.Status, '%1|%2', OldDeliveryDriverTrip.Status::Open, OldDeliveryDriverTrip.Status::Closed);
        IF NOT OldDeliveryDriverTrip.FINDFIRST THEN
            CreateOpenTrip(pDriverId, pStore, 0, 0, FALSE, FALSE); //OldDeliveryDriverTrip.CreateOpenTrip(pDriverId, pStore, 0, 0, FALSE, FALSE);

        //StaffStoreLinks.CALCFIELDS(StaffStoreLinks."Current Trip No.");
        OldDeliveryDriverTrip.FINDFIRST;
        //OldDeliveryDriverTrip.GET(pDriverId,pStore,StaffStoreLinks."Current Trip No.");
        IF (OldDeliveryDriverTrip."Functionality Type" = OldDeliveryDriverTrip."Functionality Type"::Automatic) AND (pRouteDAFID = OldDeliveryDriverTrip."DAF Trip No.") THEN
            EXIT(TRUE);

        IF (OldDeliveryDriverTrip."Functionality Type" = OldDeliveryDriverTrip."Functionality Type"::Automatic) AND
          (pRouteDAFID <> OldDeliveryDriverTrip."DAF Trip No.") AND
          (OldDeliveryDriverTrip."No. of Orders" > 0) THEN BEGIN
            pErroCode := lText001;
            EXIT(FALSE);
        END;
        IF OldDeliveryDriverTrip.Status <> OldDeliveryDriverTrip.Status::Open THEN BEGIN
            pErroCode := lText002;
            EXIT(FALSE);
        END;
        OldDeliveryDriverTrip."DAF Trip No." := pRouteDAFID;
        OldDeliveryDriverTrip."Functionality Type" := 1;
        OldDeliveryDriverTrip.MODIFY(TRUE);
        EXIT(TRUE);
    end;

    procedure CreateOpenTrip(DriverID: Code[20]; StoreNo: Code[10]; OrgFloat: Decimal; AddedFloat: Decimal; ResetTrip: Boolean; ResetFloat: Boolean)
    var
        DriverTrip: Record "LSC Delivery Driver Trip";
        NewTripCounter: Integer;
        NewTripNo: Integer;
        NewDriverTrip: Record "LSC Delivery Driver Trip";
        OldTrip: Record "LSC Delivery Driver Trip";
    begin
        DriverTrip.RESET;
        DriverTrip.SETRANGE("Driver ID", DriverID);
        DriverTrip.SETRANGE("Store No.", StoreNo);
        IF DriverTrip.FINDLAST THEN BEGIN
            NewTripCounter := DriverTrip."Trip Counter" + 1;
            NewTripNo := DriverTrip."Trip No." + 1;

            OldTrip.RESET;
            OldTrip.SETRANGE("Driver ID", DriverID);
            OldTrip.SETRANGE("Store No.", StoreNo);
            OldTrip.SETRANGE(OldTrip."Date Opened", TODAY);
            IF NOT OldTrip.FIND('-') THEN
                //IF ResetTrip THEN
                //IF CONFIRM(STRSUBSTNO(Text001,DriverTrip.FIELDCAPTION("Trip No."),DriverTrip."Trip No."),FALSE) THEN
                NewTripNo := 1;

        END ELSE BEGIN
            NewTripCounter := 1;
            NewTripNo := 1;
            //NewTripStartFloat := OrgFloat + AddedFloat;
        END;
        NewDriverTrip.INIT;
        NewDriverTrip."Driver ID" := DriverID;
        NewDriverTrip."Store No." := StoreNo;
        NewDriverTrip."Trip Counter" := NewTripCounter;
        NewDriverTrip."Trip No." := NewTripNo;
        NewDriverTrip.Status := NewDriverTrip.Status::Open;
        //NewDriverTrip."Starting Float" := NewTripStartFloat;
        NewDriverTrip.INSERT(TRUE);
    end;

    procedure CreateTripDAF(pDelOrder: Record "LSC Delivery Order"; pOnlyCreate: Boolean)
    var
        DelTrip: Record "FSN Delivery Trip";
        POSInfocode: Record "LSC POS Trans. Infocode Entry";
        POSTrLine: Record "LSC POS Trans. Line";
        POSTrans: Record "LSC POS Transaction";
        UseDaf: Boolean;
        IsNewTrip: Boolean;
        PostCodeCountry: Record "Post Code";
        DelStreet: Record "LSC Delivery Street";
        Tender: Record "LSC Tender Type Setup";
        lText001: Label 'Mixto';
        CustomerL: Record Customer;
        Timer1: Time;
        DelFunctExt: Codeunit "FSN Delivery Func. Extend";
        TimeValue: time;
        DateValue: Date;
        pDelOrderFilter: Record "LSC Delivery Order";
        TransHeder: Record "LSC Transaction Header";
        DelContAdr: Record "LSC Delivery Contact Address";
        StoreLink: Record "FSN Store Link";
        TransInfocode: Record "LSC Trans. Infocode Entry";
        WSTable: Record "FSN WebServiceTable";
        lat, lon : Decimal;
    begin
        IsNewTrip := NOT DelTrip.GET(pDelOrder."Order No.");
        UseDaf := FSNSetup.GET(pDelOrder."Restaurant No.") AND FSNSetup."Use DAF API";
        if Evaluate(TimeValue, POSSESSION.GetValue('DEL-PickupTime')) then;
        if Evaluate(DateValue, POSSESSION.GetValue('DEL-PickupDate')) then;
        IF IsNewTrip THEN BEGIN
            /*IF pDelOrder."Order Type Option" = 4 THEN //Takeaway
                EXIT;*/

            IF NOT pOnlyCreate THEN //WVILLALTA 12.20-
                                    //WVILLALTA 12.20+
                IF NOT UseDaf THEN
                    EXIT;
            CLEAR(DelTrip);
            DelTrip.INIT;
            DelTrip."Order No." := pDelOrder."Order No.";
            DelTrip."Create Time" := CURRENTDATETIME;
            DelTrip."Trip Open Time" := 0DT;
            DelTrip."Trip Finalize Time" := 0DT;
            DelTrip."Driver ID" := '';
            DelTrip."Driver Name" := '';
        END ELSE BEGIN
            IF pDelOrder."Order Type Option" = 4 THEN BEGIN//Takeaway
                DelTrip."Trip. Status" := DelTrip."Trip. Status"::"Changed To Takeaway";
                IF NOT DelTrip.Sent THEN
                    DelTrip."General Status" := DelTrip."General Status"::Void;
                DelTrip.MODIFY;
                EXIT;
            END;
        END;
        RetailSetup.GET;

        DelTrip."Contact No." := pDelOrder."Phone No.";
        DelTrip."Phone No." := pDelOrder."Phone No.";
        DelTrip."Confirm Time" := CURRENTDATETIME;
        DelTrip."Store No." := pDelOrder."Restaurant No.";
        DelTrip."Address Type" := pDelOrder."Order Type Option";
        DelTrip."Pre-Order" := pDelOrder."Pre-Order"::"On Hold";
        IF pDelOrder."Created at Call Center" <> '' THEN
            DelTrip."From CallCenter No." := pDelOrder."Created at Call Center"
        ELSE
            DelTrip."From CallCenter No." := RetailSetup."Local Store No.";
        DelTrip."Pre-Order" := pDelOrder."Pre-Order";
        DelTrip."Order Create DateTime" := CREATEDATETIME(pDelOrder."Date Created", pDelOrder."Time Created");
        if (POSSESSION.GetValue('DEL-PickupTime') <> '') and (POSSESSION.GetValue('DEL-PickupDate') <> '') then
            DelTrip."Order Activate DateTime" := CREATEDATETIME(DateValue, TimeValue)
        else
            DelTrip."Order Activate DateTime" := CREATEDATETIME(pDelOrder."Order Date", pDelOrder."Contact Pickup Time");
        DelTrip."Rute Type" := 'NORMAL';
        DelTrip."Order No. Dependent" := '';
        DelTrip."Order Confirm DateTime" := CREATEDATETIME(pDelOrder."FSN Confirm Date", pDelOrder."FSN Confirm Time");

        DelTrip."General Status" := DelTrip."General Status"::InProcess;
        DelTrip."Trip. Status" := DelTrip."Trip. Status"::"Assign Manual";
        IF UseDaf THEN
            DelTrip."Trip. Status" := DelTrip."Trip. Status"::"No Started";

        DelTrip."Restaurant WS Estatus" := 0;
        DelTrip."Sup Type Order" := GetSubTypeRec(DelTrip);
        IF DelTrip."Sup Type Order" IN [2, 3] THEN BEGIN
            IF CancelTypologyType(DelTrip) THEN BEGIN
                DelTrip."General Status" := DelTrip."General Status"::Cancelled;
                DelTrip."Trip. Status" := DelTrip."Trip. Status"::"Cancelled In CC";
            END;
        END ELSE
            DelTrip.Comment := '';

        IF POSTrans.GET(pDelOrder."Order No.") THEN;
        DelTrip."Customer No." := POSTrans."Customer No.";

        TransHeder.Reset();
        TransHeder.SetRange("Receipt No.", pDelOrder."Order No.");
        if TransHeder.FindFirst() then begin
            DelTrip."Customer No." := TransHeder."Customer No.";
        end;

        IF DelTrip."Customer No." = '' THEN
            DelTrip."Customer No." := GENERAL_;

        DelTrip."Contact Name" := pDelOrder.Name;
        IF DelTrip."Contact Name" = '' THEN
            IF CustomerL.GET(POSTrans."Customer No.") AND (CustomerL.Name <> '') THEN
                DelTrip."Contact Name" := CustomerL.Name
            ELSE
                DelTrip."Customer No." := GENERAL_;

        DelTrip."Taker Order" := pDelOrder."Order Taker";
        DelTrip.StaffID := POSTrans."Staff ID";
        IF DelTrip.StaffID = '' THEN
            DelTrip.StaffID := DelTrip."Taker Order";
        IF DelTrip."Taker Order" = '' THEN
            DelTrip."Taker Order" := DelTrip.StaffID;

        DelTrip.Grid := pDelOrder."Grid Code";
        IF DelTrip.Grid = '' THEN
            DelTrip.Grid := EMPTY_;

        CASE TRUE OF
            (pDelOrder.Directions <> '') OR (pDelOrder."FSN Directions" <> ''):
                DelTrip."Order Address" := CopyStr(DelChr(RemoveSpecialCharacters(pDelOrder.Directions + ' ' + pDelOrder."FSN Directions"), '=', '|'), 1, 250);
            POSInfocode.GET(pDelOrder."Order No.", 0, 6, 'DDIRECTION', 0):
                DelTrip."Order Address" := RemoveSpecialCharacters(POSInfocode.Information);
            pDelOrder.Address <> '':
                DelTrip."Order Address" := CopyStr(DelChr(RemoveSpecialCharacters(pDelOrder.Directions + ' ' + pDelOrder."FSN Directions"), '=', '|'), 1, 250);
        END;

        if StrLen(DelTrip."Order Address") < 30 then begin
            if POSInfocode.GET(pDelOrder."Order No.", 0, 6, 'DDIRECTION', 0) then begin
                DelTrip."Order Address" := DelChr(RemoveSpecialCharacters(POSInfocode.Information), '=', '|');
            end else
                if TransInfocode.Get(TransHeder."Store No.", TransHeder."POS Terminal No.", TransHeder."Transaction No.", 0, 6, 'DDIRECTION', 0) then
                    DelTrip."Order Address" := DelChr(RemoveSpecialCharacters(TransInfocode.Information), '=', '|');
        end;

        pDelOrder.CALCFIELDS(pDelOrder."FSN DS Restriction");
        DelTrip."Order Address 2" := pDelOrder."Address 2" + '. ' + pDelOrder."FSN DS Restriction";
        IF PostCodeCountry.GET(pDelOrder."Post Code", pDelOrder.City) THEN
            DelTrip."Point Ref" := PostCodeCountry.City + ', ' + PostCodeCountry.County + ' ';


        DelTrip."POS Terminal No." := POSTrans."POS Terminal No.";

        if DelTrip."POS Terminal No." = '' then
            DelTrip."POS Terminal No." := TransHeder."POS Terminal No.";

        if DelTrip."POS Terminal No." = '' then
            DelTrip."POS Terminal No." := POSSESSION.TerminalNo();



        IF (pDelOrder."Pre-Order" = pDelOrder."Pre-Order"::"On Hold") THEN BEGIN
            IF (pDelOrder."FSN Sort" = 0) THEN
                //DelTrip.Priority := -90;
                /*Timer1 := pDelOrder."Contact Pickup Time";
                Timer1 := Timer1 - 1800000;*/
            DelTrip."Order Activate DateTime" := CREATEDATETIME(DateValue, TimeValue);
            if Format(DelTrip."Order Activate DateTime") = '' then
                DelTrip."Order Activate DateTime" := CREATEDATETIME(pDelOrder."Order Date", pDelOrder."Contact Pickup Time");
        END;
        DelTrip."Payment Name" := '';
        DelTrip."Order Amount" := 0;
        DelTrip."Trip Amount" := 0;

        DelFunctExt.RecalctDriverAmtOnChangeFieldChange(DelTrip, DelTrip.Change, 0);//WVILLALTA 01.21-
                                                                                    //WVILLALTA 01.21+
        GetCardinal(DelTrip, pDelOrder);

        ChekGroups(DelTrip, TRUE);

        if DelTrip."Group ID" = '' then
            DelTrip."Group ID" := pDelOrder."Order No.";

        if DelTrip.Longitude = DelTrip.Latitude then begin
            if WSTable.Get(DelTrip."Order No.") then begin
                if WSTable."Order Type" = WSTable."Order Type"::Delivery then
                    if Evaluate(lat, CopyStr(wsTable."Value Text 1", 1, StrPos(wsTable."Value Text 1", ',') - 1))
                        and
                        Evaluate(lon, CopyStr(wsTable."Value Text 1", StrPos(wsTable."Value Text 1", ',') + 1, StrLen(wsTable."Value Text 1"))) then begin
                        DelTrip.Longitude := lon;
                        DelTrip.Latitude := lat;
                    end;
            end;
        end;

        IF IsNewTrip THEN
            DelTrip.INSERT
        ELSE BEGIN
            IF DelTrip.Sent THEN
                DelTrip."Trip. Status" := DelTrip."Trip. Status"::Modified;
            DelTrip.MODIFY;
        END;

        IF DelTrip."Trip. Status" IN [DelTrip."Trip. Status"::Modified, DelTrip."Trip. Status"::"No Started"] THEN
            SendOrderDAF(DelTrip, IsNewTrip);
    end;

    local procedure RemoveSpecialCharacters(input: Text): Text
    var
        i: Integer;
        output: Text;
    begin
        output := '';
        for i := 1 to StrLen(input) do begin
            if (input[i] in ['A' .. 'Z', 'a' .. 'z', '0' .. '9', ' ', '-']) then
                output := output + input[i];
        end;
        exit(output);
    end;

    procedure GetSubTypeRec(pDelTripTMP: Record "FSN Delivery Trip"): Integer
    var
        POSTransLines: Record "LSC POS Trans. Line";
        CountLines: Integer;
    begin
        POSTransLines.RESET;
        POSTransLines.SETCURRENTKEY("Receipt No.", "Entry Type", "Entry Status");
        POSTransLines.SETRANGE(POSTransLines."Receipt No.", pDelTripTMP."Order No.");
        POSTransLines.SETRANGE(POSTransLines."Entry Type", POSTransLines."Entry Type"::Item);
        POSTransLines.SETRANGE(POSTransLines."Entry Status", 0);
        CountLines := POSTransLines.COUNT;

        IF CountLines > 1 THEN
            EXIT(pDelTripTMP."Sup Type Order")
        ELSE BEGIN
            POSTransLines.SETRANGE(POSTransLines.Number, '70107');
            IF POSTransLines.FINDFIRST THEN BEGIN
                IF (pDelTripTMP."Sup Type Order" + 2) = 4 THEN
                    EXIT(pDelTripTMP."Sup Type Order");
                EXIT(pDelTripTMP."Sup Type Order" + 2);
            END;
        END;
        EXIT(pDelTripTMP."Sup Type Order");
    end;

    procedure CancelTypologyType(var pDelTrip: Record "FSN Delivery Trip"): Boolean
    var
        POSLine: Record "LSC POS Trans. Line";
        POSInfocode: Record "LSC POS Trans. Infocode Entry";
        lText001: Label '%1 %2 not apply for DAF APP';
    begin
        POSLine.RESET;
        POSLine.SETCURRENTKEY("Receipt No.", "Entry Type", "Entry Status");
        POSLine.SETRANGE(POSLine."Receipt No.", pDelTrip."Order No.");
        POSLine.SETRANGE(POSLine."Entry Type", POSLine."Entry Type"::Item);
        POSLine.SETRANGE(POSLine."Entry Status", 0);
        POSLine.SETRANGE(POSLine.Number, '70107');
        IF NOT POSLine.FINDFIRST THEN
            EXIT(TRUE);

        POSInfocode.RESET;
        POSInfocode.SETCURRENTKEY("Receipt No.", Infocode, "Transaction Type", "Line No.");
        POSInfocode.SETRANGE(POSInfocode."Receipt No.", pDelTrip."Order No.");
        POSInfocode.SETRANGE(POSInfocode.Infocode, 'CC_TIPO_0');
        POSInfocode.SETRANGE(POSInfocode."Line No.", POSLine."Line No.");
        IF NOT POSInfocode.FINDFIRST THEN
            EXIT(TRUE);

        IF POSInfocode.Information IN ['02-TIPO2', '06-TIPO6', '07-TIPO7', '16-TIPO16'] THEN
            EXIT(FALSE);

        pDelTrip.Comment := COPYSTR(STRSUBSTNO(lText001, POSInfocode.TABLECAPTION, POSInfocode.Information), 1, MAXSTRLEN(pDelTrip.Comment));
        EXIT(TRUE);
    end;

    procedure GetCardinal(var pDelTrip: Record "FSN Delivery Trip"; pOrder: Record "LSC Delivery Order")
    var
        StoreOk: Boolean;
        StreetOk: Boolean;
        DelCont: Record "LSC Delivery Contact Address";
        DelStreet: Record "LSC Delivery Street";
        StoreDistance: Record "LSC Store";
        StreetName: Text[250];
    begin
        StoreOk := StoreDistance.GET(pOrder."Restaurant No.");

        IF pOrder."FSN Alter Key" > 0 THEN BEGIN
            DelStreet.RESET;
            DelStreet.SETRANGE(DelStreet."FSN Alter Key", pOrder."FSN Alter Key");
            StreetOk := DelStreet.FINDFIRST;
        END;
        IF NOT StreetOk THEN BEGIN
            IF STRPOS(pOrder.Address, ' ') > 0 THEN
                StreetName := COPYSTR(StreetName, STRPOS(StreetName, ' ') + 1, STRLEN(StreetName));

            DelStreet.RESET;
            DelStreet.SETRANGE(DelStreet."Street Name", StreetName);
            DelStreet.SETRANGE(DelStreet."Post Code", pOrder."Post Code");
            StreetOk := DelStreet.FINDFIRST;
        END;
        IF NOT StreetOk AND DelCont.GET(pOrder."Phone No.", pOrder."Order Type Option" + 1) AND (DelCont."Street Name" <> '') THEN BEGIN
            DelStreet.RESET;
            DelStreet.SETRANGE(DelStreet."Street Name", DelCont."Street Name");
            DelStreet.SETRANGE(DelStreet."Post Code", DelCont."Post Code");
            StreetOk := DelStreet.FINDFIRST;
        END;
        pDelTrip.Longitude := 0;
        pDelTrip.Latitude := 0;
        IF StreetOk THEN BEGIN
            pDelTrip.Longitude := DelStreet."FSN Longitude";
            pDelTrip.Latitude := DelStreet."FSN Latitude";
        END;

        IF (STRLEN(pOrder."Order No.") <= 10) OR NOT StoreOk OR NOT StreetOk THEN BEGIN
            IF STRLEN(pOrder."Order No.") <= 10 THEN
                pDelTrip."Cardinal Point" := pOrder."Order No."
            ELSE
                pDelTrip."Cardinal Point" := COPYSTR(pOrder."Order No.", STRLEN(pOrder."Order No.") - 10, 10);
            EXIT;
        END;

        IF (StoreDistance.Latitude = 0) OR
          (StoreDistance.Longitude = 0) OR
          (DelStreet."FSN Latitude" = 0) OR
          (DelStreet."FSN Longitude" = 0) THEN BEGIN
            pDelTrip."Cardinal Point" := COPYSTR(pOrder."Order No.", 1, MAXSTRLEN(pDelTrip."Cardinal Point"));
        END;

        IF DelStreet."FSN Latitude" <= StoreDistance.Latitude THEN BEGIN
            IF DelStreet."FSN Longitude" <= StoreDistance.Longitude THEN
                pDelTrip."Cardinal Point" := 'SE'
            ELSE
                pDelTrip."Cardinal Point" := 'SO';
        END ELSE BEGIN
            IF DelStreet."FSN Longitude" <= StoreDistance.Longitude THEN
                pDelTrip."Cardinal Point" := 'NE'
            ELSE
                pDelTrip."Cardinal Point" := 'NO';
        END;
    end;

    procedure ChekGroups(var pRec: Record "FSN Delivery Trip"; pInCreate: Boolean): Boolean
    var
        DelOrder: Record "LSC Delivery Order";
        PostDelOrder: Record "LSC Posted Delivery Order";
        DelOrder2: Record "LSC Delivery Order";
        PostDelOrder2: Record "LSC Posted Delivery Order";
        DelTrip: Record "FSN Delivery Trip";
        GroupID: Code[20];
        GroupCount: Integer;
        GroupDate: Date;
    begin
        CLEAR(GroupID);
        IF DelOrder.GET(pRec."Order No.") THEN BEGIN
            IF DelOrder."External Order No." <> '' THEN
                GroupID := DelOrder."External Order No."
            ELSE BEGIN
                GroupID := DelOrder."Order No.";
            END;
            GroupDate := DelOrder."Order Date";
        END;

        DelOrder2.SETCURRENTKEY("External Order No.");
        DelOrder2.SETRANGE(DelOrder2."External Order No.", GroupID);
        DelOrder2.SETRANGE(DelOrder2."Order Date", GroupDate);
        DelOrder2.SETRANGE(DelOrder2."Restaurant No.", DelOrder."Restaurant No.");
        DelOrder2.SETRANGE(DelOrder2."Order Type Option", DelOrder."Order Type Option");
        DelOrder2.SETFILTER(DelOrder2."Call Cent. Web Service Status", '<>3&<>6&<>8&<>9');
        //Not Used,New-Not Sent,Changed-Not Sent,Cancelled-Not Sent,New-Sent,Changed-Sent,Cancelled-Sent,Finalized in Rest.,Cancelled in Rest.,Cancelled New-Not Sent,New-Not Confirmed
        GroupCount := DelOrder2.COUNT;
        GroupCount += 1;


        pRec."Group ID" := GroupID;
        pRec."Group Quantity" := GroupCount;

        DelTrip.RESET;
        DelTrip.SETCURRENTKEY("Group ID", "Group Quantity");
        DelTrip.SETFILTER(DelTrip."Order No.", '<>%1', pRec."Order No.");
        DelTrip.SETRANGE(DelTrip."Group ID", pRec."Group ID");
        IF DelTrip.FIND('-') THEN
            REPEAT
                IF (DelTrip."Group Quantity" <> GroupCount) AND
                  (DelTrip."General Status" = DelTrip."General Status"::InProcess) THEN BEGIN

                    DelTrip."Trip. Status" := DelTrip."Trip. Status"::Modified;
                    DelTrip."Group Quantity" := GroupCount;
                    DelTrip.MODIFY;
                END;
            UNTIL DelTrip.NEXT = 0;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Controller", 'OnButtonPressed', '', true, true)]
    local procedure "LSC POS Controller_OnButtonPressed"
    (
        var POSMenuLine: Record "LSC POS Menu Line";
        var handled: Boolean
    )
    var
        DriverTrip: Record "FSN Delivery Trip";
        DeliveryDriverTrip: Record "LSC Delivery Driver Trip";
        PAGEDriverTripView: Page "FSN Driver Trip View";
        POSGUI: Codeunit "LSC POS GUI";
    begin
        if (POSMenuLine.Command = 'DRIVER') then begin
            handled := true;
            DeliveryDriverTrip.RESET;
            DeliveryDriverTrip.SETCURRENTKEY("Driver ID", "Store No.", "Trip Counter");
            DeliveryDriverTrip.SETRANGE(DeliveryDriverTrip."Driver ID", POSMenuLine.Parameter);
            DeliveryDriverTrip.SETRANGE(DeliveryDriverTrip."Store No.", POSSESSION.StoreNo);
            IF DeliveryDriverTrip.FINDLAST THEN BEGIN
                PAGEDriverTripView.SetDriverID(DeliveryDriverTrip."Trip Counter", DeliveryDriverTrip."Driver ID", DeliveryDriverTrip."Store No.");
                PAGEDriverTripView.EDITABLE(TRUE);
                PAGEDriverTripView.Run();
            END;
        end;

        if POSMenuLine."Command" = 'LIQ-MAN-DAF' then begin
            POSGUI.OpenAlphabeticKeyboard('N° Ruta:', '', false, 'DAF_ROUTE_SEARCH', 250);
        end;

        if POSMenuLine."Command" = 'DAF-MANUAL' then begin
            POSGUI.OpenAlphabeticKeyboard('N° Ruta:', '', false, 'DAF_MANUAL_SEND', 250);
        end;

        if POSMenuLine.Command = 'TESTDAF' then begin
            POSGUI.OpenAlphabeticKeyboard('N° Ruta:', '', false, 'DAF-TEST', 250);
        end;
    end;

    procedure SetTokenDaff(Token: Text; LastTime: Time; LastDate: Date)
    begin
        GlobalTokenDAF := Token;
        GlobalLastTimeTokenDAF := LastTime;
        GlobalLastDateTokenDAF := LastDate;
    end;

    procedure GetLastTokenDaff(var Token: Text; var LastTime: Time; var LastDate: Date)
    begin
        Token := GlobalTokenDAF;
        LastTime := GlobalLastTimeTokenDAF;
        LastDate := GlobalLastDateTokenDAF;
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
        PdelOrder: Record "LSC Delivery Order";
        RetailSetupBK: Record "LSC Retail Setup";
        pDelTrip: Record "FSN Delivery Trip";
        pIsConvert: Boolean;
        RetailSetup_l: Record "LSC Retail Setup";
        Trans: Record "LSC Transaction Header";
        Paramet: Record "FSN Parameter";
        DTETrans: Record "FSN DTE Transaction Header";
    begin
        if RequestID = 'DEL-TRANSFSN' then begin
            IF pDelOrder.Get(XMLRequest) THEN begin
                if PdelOrder."Created at Call Center" = '' then begin
                    PdelOrder."Created at Call Center" := 'F20';
                    PdelOrder.Modify();
                end;
                POSSESSION.SetValue('ORDERDAF', 'TRUE');
                CreateTripDAF(pDelOrder, false);
                POSSESSION.SetValue('ORDERDAF', '');
            end;
        end;

        if RequestID = 'DEL-CANCELDAF' then begin
            if pDelTrip.GET(XMLRequest) then begin
                IF pDelOrder.GET(XMLRequest) AND (NOT (pDelOrder."Call Cent. Web Service Status" IN [pDelOrder."Call Cent. Web Service Status"::"New-Not Sent",
                                                                    pDelOrder."Call Cent. Web Service Status"::"New-Not Confirmed"])) THEN BEGIN
                    CancelOrderDAF(pDelTrip, pIsConvert);
                end;
            end;
        end;

        if RequestID = 'RENCONF_DAF' then begin
            if pDelTrip.GET(XMLRequest) then begin
                POSSESSION.SetValue('ORDERDAF', 'TRUE');
                Paramet.Reset();
                if Paramet.Get('DAF', 'NEWSEND') AND Paramet.Activo then
                    SendOrderDAF(pDelTrip, true)
                ELSE
                    SendOrderDAF(pDelTrip, false);
                POSSESSION.SetValue('ORDERDAF', '');
            end;
        end;

        if RequestID = 'DAF-TEST' then begin
            TmpTrans.Reset();
            TmpTrans.SetRange("Receipt No.", XMLRequest);
            IF TmpTrans.FindSet() then begin
                IF DTETrans.Get(TmpTrans."Store No.", TmpTrans."POS Terminal No.", TmpTrans."Transaction No.") then begin
                    UpdateDateInvoice(TmpTrans, DTETrans);
                    MsgResult := 'TRUE';
                end;
            end;
        end;
    end;


    [EventSubscriber(ObjectType::Table, Database::"FSN DTE Transaction Header", 'OnBeforeInsertEvent', '', true, true)]
    local procedure "FSNDTETransaction_OnBeforeInsertEvent"
  (
      var Rec: Record "FSN DTE Transaction Header";
      RunTrigger: Boolean
    )
    var
        Delorder: Record "LSC Delivery Order";
        PosDelOrder: Record "LSC Posted Delivery Order";
        transaction: Record "LSC Transaction Header";
    begin
        if transaction.Get(Rec."Store No.", Rec."POS Terminal No.", Rec."Transaction No.") then
            if Delorder.Get(transaction."Receipt No.") or PosDelOrder.Get(transaction."Receipt No.") then
                UpdateDateInvoice(transaction, Rec);
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
        Api: Codeunit "DTE API Connection";
        Session: Codeunit "LSC POS Session";
        parameter: Record "FSN Parameter";
        posPrint: Codeunit "POS Print Utility";
        pDelTrip: Record "FSN Delivery Trip";
        Done: Boolean;
        OrderResult: JsonObject;
        Credentials: Text;
        sStatus: JsonToken;
        sBody: JsonToken;
        sData: JsonToken;
        sToken: JsonToken;
        sIdMotor: JsonToken;
        sStore: JsonToken;
        idMotorcyclist: Text;
        store: Text;
        result: Boolean;
        resultTxt: Text;
        idRoute: Integer;
        transaction: Record "LSC Transaction Header";
        DTETransaction: Record "FSN DTE Transaction Header";
        Parameterfsn: Record "FSN Parameter";
    begin
        if resultOK then begin
            if (payload = 'DAF_ROUTE_SEARCH') and (inputValue <> '') then begin
                if parameter.Get('DAF', 'DAF_API') then begin
                    Credentials := getCredentials();
                    if (Credentials <> '') then begin
                        getOrderResult(inputValue, Credentials, parameter, OrderResult);

                        if (OrderResult.SelectToken('status', sStatus)) and (sStatus.AsValue().AsInteger() = 200) then begin
                            // Get Info of OrderResult
                            if OrderResult.SelectToken('body', sBody) then begin
                                sData.ReadFrom(sBody.AsValue().AsText());
                                if sData.SelectToken('data', sToken) then begin
                                    if sToken.SelectToken('idMotorcyclist', sIdMotor) then idMotorcyclist := sIdMotor.AsValue().AsText();
                                    if sToken.SelectToken('store', sStore) then store := sStore.AsValue().AsText();
                                end;
                            end;
                            Evaluate(idRoute, inputValue);
                            result := posPrint.FinalizeTripInDAF(idMotorcyclist, store, idRoute, resultTxt);

                            if result then
                                Message('Ruta liquidada correctamente')
                            else begin
                                if resultTxt = '' then
                                    Message('Error al liquidar ruta')
                                else
                                    Message(resultTxt);
                            end;
                        end
                        else
                            Message('Ruta no encontrada');
                    end
                    else
                        Message('Sin conexión a DAF');
                end
                else
                    Message('Sin conexión a DAF');
            end
            else
                if (payload = 'DAF_ROUTE_SEARCH') then
                    Message('Debe ingresar un N° de ruta');

            if (payload = 'DAF_MANUAL_SEND') and (inputValue <> '') then begin
                if pDelTrip.GET(inputValue) then begin
                    POSSESSION.SetValue('ORDERDAF', 'TRUE');
                    Parameterfsn.Reset();
                    if Parameterfsn.Get('DAF', 'NEWSEND') AND Parameterfsn.Activo then
                        SendOrderDAF(pDelTrip, true)
                    ELSE
                        SendOrderDAF(pDelTrip, false);
                    POSSESSION.SetValue('ORDERDAF', '');
                end;
            end;

            if (payload = 'DAF-TEST') and (inputValue <> '') then begin
                transaction.Reset();
                transaction.SetRange("Receipt No.", inputValue);
                IF transaction.FindSet() then begin
                    IF DTETransaction.Get(transaction."Store No.", transaction."POS Terminal No.", transaction."Transaction No.") then
                        UpdateDateInvoice(transaction, DTETransaction);
                end;
            end;

            processed := true;
        end;
    end;

    local procedure getOrderResult(idRoute: Text; Credentials: Text; parameter: Record "FSN Parameter"; var OrderResult: JsonObject): Text
    var
        Api: Codeunit "DTE API Connection";
        headers: HttpHeaders;
        request: HttpRequestMessage;
        uri: Text;
    begin
        request.GetHeaders(headers);
        headers.Clear();
        headers.Add('Authorization', 'Bearer ' + Credentials);
        uri := parameter."Web Uri" + 'Route/GetRouteDetail?idRoute=' + idRoute;
        OrderResult := Api.Get(uri, request);
    end;

    procedure getCredentials(): Text
    var
        Api: Codeunit "DTE API Connection";
        parameter: Record "FSN Parameter";
        credentialObject: JsonObject;
        credentialResult: JsonObject;
        body: HttpContent;
        headers: HttpHeaders;
        request: HttpRequestMessage;
        uri: Text;
        sBody: JsonToken;
        sData: JsonToken;
        sToken: JsonToken;
    begin
        if parameter.Get('DAF', 'DAF_API') then begin
            body.GetHeaders(headers);
            headers.Clear();
            headers.Add('Content-Type', 'application/json');
            request.Content := body;
            uri := parameter."Web Uri" + 'Motorcyclist/Login?' + parameter.Valor;
            credentialResult := Api.Post(uri, request);
            IF credentialResult.SelectToken('body', sBody) then
                IF sBody.SelectToken('data', sData) then
                    IF sData.AsObject().SelectToken('token', sToken) then exit(sToken.AsValue().AsText())
        end;
    end;

    local procedure EvaluateItemParameter(pDeliveryTripTMP: Record "FSN Delivery Trip"; value: Text; defaultValue: Text): Text
    var
        transLine: Record "LSC POS Trans. Line";
        parameter: Record "FSN Parameter";
    begin
        transLine.SetRange("Receipt No.", pDeliveryTripTMP."Order No.");
        transLine.SetRange("Entry Type", transLine."Entry Type"::Item);
        transLine.SetRange("Entry Status", transLine."Entry Status"::" ");
        if transLine.Find('-') then
            repeat
                if parameter.Get('DAF', transLine.Number) then;
                if parameter.activo and (parameter.Descripcion = value) then
                    exit(parameter.Valor);
            until transLine.Next() = 0;

        exit(defaultValue);
    end;

}
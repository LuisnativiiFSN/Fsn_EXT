codeunit 50053 "FSN Call Center SenOrder"
{
    TableNo = "LSC Scheduler Job Header";
    trigger OnRun()

    begin
        jobQueueEntry := Rec;
        case jobQueueEntry.Code of
            'V-SENDORDER':
                VALIDATESENORDER;
            'V-PERDIDAD':
                VentaPerdida();
            'CLEAR-LOG':
                ClearLog();
            'E-SENDORDER':
                EcommerceProcessOrder();
        end;
    end;

    var
        jobQueueEntry: Record "LSC Scheduler Job Header";
        DelOrdT: Record "LSC Delivery Order";
        OrderNo: Code[20];
        POSSESSION: Codeunit "LSC POS Session";
        DelOrd: Record "LSC Delivery Order";
        OfflineCCSetup: Record "LSC Offline Call Center Setup";
        DelCont: Record Contact;
        DelOrderM: Codeunit "LSC Delivery Order Management";
        DelPosComm: Codeunit "LSC Delivery POS Commands";
        DelOrderChanges: Boolean;
        PosTrChange: Boolean;
        PosTrFound: Boolean;
        ErrorText: Text;
        Windows: Dialog;
        Text056: Label 'Enviado al restaurante con éxito.';
        Text054: Label 'Communication Error occurred.';
        LoadingText: Label 'Procesando Pedido, Espere.......';
        FSNSalesChannel: Record "FSN Sales Channel";
        lText002: Label 'Debe establecerse un canal de ventas';
        POSGUI: Codeunit "LSC POS GUI";
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line" Temporary;
        Processed: Boolean;
        MsgResult: Text;
        SendToCallCenter: Boolean;
        POSCARD: Record "LSC POS Card Entry";
        PosTrans: Record "LSC POS Transaction";
        myInt: Integer;
        PosTransaction: Record "LSC POS Transaction";
        DelOrder: Record "LSC Delivery Order";
        FSNUtility: Codeunit "FSN Utility";
        FSNDeliveryFunct: Codeunit "FSN Delivery Functions Extend";
        OfflineCCWSClient: codeunit "LSC Offl. CC Web Serv. Client";
        StyleStatus: Option None,Standard,StandardAccent,Strong,StrongAccent,Attention,AttentionAccent,Favorable,Unfavorable,Ambiguous,Subordinate;
        StyleStatusText: Text;
        Exists: Boolean;
        GlobalParametroPQ: Record "FSN Parameter";

    procedure VALIDATESENORDER()
    var
        myInt: Integer;
        Parameter: Record "FSN Parameter";
    begin
        Parameter.Reset();
        Parameter.SetRange(Grupo, 'SENDERROR');
        Parameter.SetRange(Codigo, 'DELIVERY');
        IF Parameter.FindFirst() then;
        DelOrdT.Reset();
        DelOrdT.SetRange("Date Created", Today);
        DelOrdT.SetRange("General Status", DelOrdT."General Status"::ERROR);
        if DelOrdT.Find('-') then begin
            repeat
                if DelOrdT."Call Cent. Web Service Status" in
                    [DelOrdT."Call Cent. Web Service Status"::"New-Not Sent",
                    DelOrdT."Call Cent. Web Service Status"::"New-Not Confirmed",
                    DelOrdT."Call Cent. Web Service Status"::"Changed-Not Sent"] then begin
                    IF NOT (Parameter.Activo) then begin
                        VTRANSACTIONSALES(DelOrdT."Order No.");
                        if not Exists then
                            ProcessOrderT(DelOrdT."Order No.");
                    end ELSE
                        ProcessOrderT(DelOrdT."Order No.");
                end;
            until DelOrdT.Next() = 0;
        end;
    end;

    procedure ProcessOrderT(OrderNo: Code[20])
    var
        PosTransac: Record "LSC POS Transaction";
        CalendarValidationError: Text[250];
        CalendarDebugMsg: Text[250];
    begin
        PosTrChange := false;
        PosTrFound := true;
        Windows.OPEN(LoadingText);
        Windows.UPDATE;
        DelOrd.Reset();

        if PosTransac.Get(OrderNo) then
            if (CopyStr(PosTransac."Receipt No.", 1, 10) = '00000APP01') OR
                (CopyStr(PosTransac."Receipt No.", 1, 10) = '00000APP02') OR
                   (CopyStr(PosTransac."Receipt No.", 1, 10) = '000PV#1000') then begin
                exit;
            end;

        SendToCallCenter := false;
        ValTime(OrderNo);
        if DelOrd.Get(OrderNo) then begin
            // NUEVA VALIDACIÓN: Verificar que la tienda está abierta en la fecha/hora programada usando la lógica de calendario
            if not FSNDeliveryFunct.ValidateStoreOpenForDeliveryOrder(DelOrd, CalendarValidationError, CalendarDebugMsg) then begin
                DelOrd.Reset();
                if DelOrd.Get(OrderNo) then begin
                    DelOrd."General Status" := DelOrd."General Status"::ERROR;
                    DelOrd."Call Cent. Web Service Status" := DelOrd."Call Cent. Web Service Status"::"New-Not Sent";
                    DelOrd.Modify();
                    Commit;
                end;
                Windows.Close();
                Error(CalendarValidationError);
            end;

            DelCont.Reset();
            if DelCont.get(DelOrd."Phone No.") then begin
                DelCont."LSC Next Order Selection" := DelOrd."Order Type Option";
                DelCont."LSC Next Order Restaurant" := DelOrd."Restaurant No.";
                DelCont."LSC Next Order Date" := DelOrd."Order Date";
                if DelOrd."Pre-Order" = DelOrd."Pre-Order"::"On Hold" then begin
                    DelCont."LSC Next Order Time" := DelOrd."Contact Pickup Time";
                end else
                    DelCont."LSC Next Order Time" := Time;
                DelCont."LSC Next Delivery Tender" := DelOrd."Tender Type";
                DelCont."LSC Pre-Order Print DateTime" := DelOrd."Pre-Order Print DateTime";
                DelCont."LSC Next Estimated Prod. Time" := DelOrd."Estimated Prod. Time (Min.)";
                DelCont.Modify;
                DelOrderM.UpdateOrder(OrderNo, DelCont, false, false, true);
            end;

            if (DelOrd."Call Cent. Web Service Status" = DelOrd."Call Cent. Web Service Status"::"New-Not Sent") or
   (DelOrd."Call Cent. Web Service Status" = DelOrd."Call Cent. Web Service Status"::"New-Sent") or
                (DelOrd."Call Cent. Web Service Status" = DelOrd."Call Cent. Web Service Status"::"New-Not Confirmed") or
   (DelOrd."Call Cent. Web Service Status" = DelOrd."Call Cent. Web Service Status"::"Changed-Sent") or
   (DelOrd."Call Cent. Web Service Status" = DelOrd."Call Cent. Web Service Status"::"Changed-Not Sent") then
                SendToCallCenter := true;

            if SendToCallCenter then begin
                //if DelPosComm.SendDeliveryOrder(DelOrd, DelOrderChanges, ErrorText) then begin
                POSCARD.Reset();//crea linea para media de pago tarjeta
                POSCARD.SetRange("Receipt No.", DelOrd."Order No.");
                if POSCARD.FindFirst() then begin
                    RequestID := 'DEL-TRANSCARDFSN';
                    MsgResult := Format(DelOrd."General Status");
                    XMLRequest := DelOrd."Order No.";
                    FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
                end;

                if SendDeliveryOrder(DelOrd, DelOrderChanges, ErrorText) then begin
                    OfflineCCSetup.Get;
                    DelOrd.Reset();
                    DelOrd.Get(OrderNo);

                    if ValidatePaqueteria then begin
                        RequestID := 'SENPQC807';//manda Formulario
                        MsgResult := Format(DelOrd."General Status");
                        XMLRequest := DelOrd."Order No.";
                        FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
                    end else begin
                        RequestID := 'DEL-TRANSFSN';//manda a DAF
                        MsgResult := Format(DelOrd."General Status");
                        XMLRequest := DelOrd."Order No.";
                        FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
                    end;

                    if DelOrd."Call Cent. Web Service Status" in
                      [DelOrd."Call Cent. Web Service Status"::"New-Not Sent", DelOrd."Call Cent. Web Service Status"::"New-Not Confirmed"] then
                        DelOrd."Call Cent. Web Service Status" := DelOrd."Call Cent. Web Service Status"::"New-Sent";

                    if DelOrd."Call Cent. Web Service Status" = DelOrd."Call Cent. Web Service Status"::"Changed-Not Sent" then
                        DelOrd."Call Cent. Web Service Status" := DelOrd."Call Cent. Web Service Status"::"Changed-Sent";

                    DelOrd."General Status" := DelOrd."General Status"::"In Process";
                    if (DelOrd."Assigned to Driver") or (DelOrd."Process Status" = DelOrd."Process Status"::Finished) then
                        DelOrd."General Status" := DelOrd."General Status"::Confirmed;

                    DelOrd.Modify();
                    Commit;

                    if OfflineCCSetup."Show Msg. on Successful Send" then;

                    POSSESSION.SetValue('CLEARCURRORDER', 'true');


                end else begin
                    DelOrd.Reset();
                    if DelOrd.Get(OrderNo) then begin
                        if DelOrd."Call Cent. Web Service Status" = DelOrd."Call Cent. Web Service Status"::"New-Not Confirmed" then
                            DelOrd."Call Cent. Web Service Status" := DelOrd."Call Cent. Web Service Status"::"New-Not Sent";
                        DelOrd."General Status" := DelOrd."General Status"::ERROR;
                        DelOrd.Modify();
                        ProStyleStutus(Format(DelOrd."General Status"));
                    end;
                    Commit;
                end;
            end;
            Commit();
        end;
        Windows.Close();
    end;

    local procedure EcommerceProcessOrder()
    var
        myInt: Integer;
        FSNwebService: Record "FSN WebServiceTable";
        FSNEcommerce: Codeunit "FSN Ecommerce Functions";
        ECCenter: Codeunit "FSN Ecommerce CallCenter Mgt.";
    begin
        FSNwebService.Reset();
        FSNwebService.SetRange("WS Request", 'SEND_POSTRANS_BACKUP');
        FSNwebService.SetRange("Status WS", FSNwebService."Status WS"::Pending);
        FSNwebService.SetRange(Date, Today);
        IF FSNwebService.Find('-') THEN begin
            repeat
                If (FSNwebService."Store Selected" = '') and (FSNwebService."Order Type" = FSNwebService."Order Type"::Delivery) then
                    ECCenter.SendDeliveryBackup(FSNwebService.LastSlipNo);
                FSNEcommerce.UpdateTRansactionEcommerce(FSNwebService.LastSlipNo);
            until FSNwebService.Next() = 0;
        end;
    end;

    procedure SendDeliveryOrder(DelOrderToSend: Record "LSC Delivery Order"; DelOrderOnly: Boolean; var EstimErrorText: Text[1024]): Boolean
    var
        ProcessError: Boolean;
        CreateHospOrderUtils: Codeunit LSCCreateHospOrderUtils;
        ResponseCode: Code[30];
        ErrorText: Text;
    begin
        //si no se ha enviado
        if DelOrderToSend."Call Cent. Web Service Status" in
          [DelOrderToSend."Call Cent. Web Service Status"::"New-Not Sent",
          DelOrderToSend."Call Cent. Web Service Status"::"New-Not Confirmed",
          DelOrderToSend."Call Cent. Web Service Status"::"Changed-Not Sent"]
        then begin
            OfflineCCWSClient.SendDelOrder(DelOrderToSend."Order No.", DelOrderToSend."Restaurant No.", ProcessError, EstimErrorText);
            //exit(not ProcessError);
        end;
        //si ya se envio y se desea reconfirmar
        if DelOrderToSend."Call Cent. Web Service Status" in [DelOrderToSend."Call Cent. Web Service Status"::"Changed-Sent",
        DelOrderToSend."Call Cent. Web Service Status"::"New-Sent"] then begin
            if DelOrderOnly then
                OfflineCCWSClient.SendDelOrderNoTrans(DelOrderToSend."Order No.", DelOrderToSend."Restaurant No.", ProcessError, EstimErrorText)
            else
                OfflineCCWSClient.SendDelOrder(DelOrderToSend."Order No.", DelOrderToSend."Restaurant No.", ProcessError, EstimErrorText);
            //exit(not ProcessError);
        end;

        exit(true);
    end;

    procedure ProStyleStutus(TextStatus: Text)
    var
        myInt: Integer;
    begin
        if not (TextStatus in ['ERROR', 'Cancelled']) then
            StyleStatusText := Format(StyleStatus::Favorable)
        else
            StyleStatusText := Format(StyleStatus::Unfavorable);
    end;

    procedure ValTime(OrdN: Code[20])
    var
        myInt: Integer;
        PosTrans: Record "LSC POS Transaction";
        HospSetup: Record "LSC Hospitality Setup";
        DelOrderIn: Record "LSC Delivery Order";
    begin
        if DelOrderIn.Get(OrdN) then begin
            if (DelOrderIn."Order Date" <= Today) AND (DelOrderIn."Contact Pickup Time" < Time) then begin
                DelOrderIn."Order Date" := Today;
                DelOrderIn."Contact Pickup Time" := Time;
                DelOrderIn.Modify();
                Commit();
            end;
            POSSESSION.SetValue('DEL-PickupDate', Format(DelOrderIn."Order Date"));
            POSSESSION.SetValue('DEL-PickupTime', format(DelOrderIn."Contact Pickup Time"));
        end;
    end;

    procedure VTRANSACTIONSALES(Recibo: code[20])
    var
        POSTRANS: Record "LSC POS Transaction";
        DELORDER: Record "LSC Delivery Order";
        SqlConnection: DotNet SqlConnection;
        SqlCommand: DotNet SqlCommand;
        SqlDataReader: DotNet SqlDataReader;
        ConnectionString: Text[125];
        SqlString: Text;
        DisLocation: Record "LSC Distribution Location";
        lTextConn: Label 'Data Source=%1;Initial Catalog=%2;Integrated Security=false; User ID=%3;Password=%4;';
        lTextSimbol: Label '''''';
        Receipt: code[20];
        Tran: Integer;
        DelConta: Record Contact;
    begin
        if POSTRANS.get(Recibo) then begin
            if DelOrd.Get(Recibo) then begin
                Receipt := DelOrd."Order No.";
                if DisLocation.GET('HO') then;
                if DelConta.Get(DelOrd."Phone No.") then begin
                    ValidateTimeOnRestChange(DelConta, errorText, false, DelOrd);
                    IF POSSESSION.GetValue('VALRESTAURAN') = 'FALSE' then begin
                        ConnectionString := STRSUBSTNO(lTextConn, DisLocation."Db Server Name", DisLocation."Db. Path && Name", DisLocation."User ID", DisLocation.Password);
                        SqlConnection := SqlConnection.SqlConnection(ConnectionString);
                        SqlString := 'Select [Transaction No_] from [BCENTRAL].[FSN].[FASANI$LSC Transaction Header]' +
                                     'WHERE [Receipt No_]=''' + Receipt + ''' ';
                        SqlConnection.Open();
                        SqlCommand := SqlConnection.CreateCommand();
                        SqlCommand.CommandText := SqlString;
                        Exists := false;
                        SqlDataReader := SqlCommand.ExecuteReader();
                        IF SqlDataReader.Read() THEN begin
                            Exists := true;
                            Tran := SqlDataReader.GetInt32(0);
                        end;
                        SqlConnection.Close();
                        if Exists then begin
                            PosDeliv(DelOrd, POSTRANS)
                        end;
                    end;
                end;
            end;
        end;
    end;


    procedure PosDeliv(DelivOrder: Record "LSC Delivery Order"; POSTrans: Record "LSC POS Transaction")
    var
        POSDelOrd: Record "LSC Posted Delivery Order";
    begin
        DelivOrder.Delete();
        POSTrans.Delete();
    end;

    /*procedure ValidateTimeOnRestChange(var ContTmp: Record Contact; var ErrorText: Text; FromWS: Boolean)
    var
        TimeCalculation: Option Finished,Started;
        FromDateTime: DateTime;
        ToDateTime: DateTime;
        ClosedInPeriod: Option Open,"Closed within Period","Closed at End Point";
        OrderDateTime: DateTime;
        HospFunc: Codeunit "LSC Hospitality Functions";
        TimeErrorText: text;
        GetEstimJobOnCallCenter: boolean;
        OrderProdTime: Integer;
        TimeOrder: Time;
        DateOrder: Date;
        SText061: Label 'El restaurante %1 está cerrado dentro del período de %2 a %3.\Seleccione otro restaurante o cambie la hora del pedido.';
        SText025: Label 'El restaurante %1 no está abierto en %2.\Seleccione otro restaurante o cambie la hora del pedido.';

    begin
        GetEstimJobOnCallCenter := false;
        if ContTmp."LSC Pre-Order Print DateTime" = 0DT then begin    //not a pre-order
            if FromWS then begin
                if ContTmp."LSC Next Order Date" = DT2Date(CurrentDateTime) then begin
                    if (ContTmp."LSC Next Order Time" = 0T) or (ContTmp."LSC Next Order Time" < DT2Time(CurrentDateTime)) then
                        OrderDateTime := CurrentDateTime
                    else
                        OrderDateTime := CreateDateTime(ContTmp."LSC Next Order Date", ContTmp."LSC Next Order Time");
                end else
                    if ContTmp."LSC Next Order Date" > DT2Date(CurrentDateTime) then
                        OrderDateTime := CreateDateTime(ContTmp."LSC Next Order Date", ContTmp."LSC Next Order Time");
            end else
                OrderDateTime := CurrentDateTime;
            if not HospFunc.FindProductionTime(
                     ContTmp."LSC Next Order Restaurant", 0, '', OrderDateTime, TimeCalculation::Finished,
                     TimeErrorText, GetEstimJobOnCallCenter, OrderProdTime, FromDateTime, ToDateTime, ClosedInPeriod)
            then begin
                if OrderDateTime <> 0DT then begin
                    if ClosedInPeriod = ClosedInPeriod::"Closed within Period" then begin
                        ErrorText := StrSubstNo(SText061, ContTmp."LSC Next Order Restaurant", DT2Time(FromDateTime), DT2Time(ToDateTime));
                    end else begin
                        ErrorText := StrSubstNo(SText025, ContTmp."LSC Next Order Restaurant", DT2Time(OrderDateTime));
                    end;
                    ContTmp."LSC Next Order Date" := DT2Date(OrderDateTime);
                    ContTmp."LSC Next Order Time" := DT2Time(OrderDateTime);
                    ContTmp."LSC Next Estimated Prod. Time" := OrderProdTime;
                end else begin
                    ContTmp."LSC Next Estimated Prod. Time" := 0;
                    ErrorText := TimeErrorText;
                end;
            end;
            ContTmp."LSC Next Order Date" := DT2Date(OrderDateTime);
            ContTmp."LSC Next Order Time" := DT2Time(OrderDateTime);
            ContTmp."LSC Next Estimated Prod. Time" := OrderProdTime;
        end else begin            // a pre-order
            OrderProdTime := 0;
            OrderDateTime := CreateDateTime(ContTmp."LSC Next Order Date", ContTmp."LSC Next Order Time");
            if not HospFunc.FindProductionTime(
                     ContTmp."LSC Next Order Restaurant", 0, '', OrderDateTime, TimeCalculation::Started,
                     TimeErrorText, GetEstimJobOnCallCenter, OrderProdTime, FromDateTime, ToDateTime, ClosedInPeriod)
            then begin
                if OrderDateTime <> 0DT then begin
                    if ClosedInPeriod = ClosedInPeriod::"Closed within Period" then begin
                        TimeOrder := ContTmp."LSC Next Order Time";
                        DateOrder := ContTmp."LSC Next Order Date";
                        ErrorText := StrSubstNo(SText061, ContTmp."LSC Next Order Restaurant", DT2Time(FromDateTime), DT2Time(ToDateTime));
                    end else begin
                        TimeOrder := ContTmp."LSC Next Order Time";
                        DateOrder := ContTmp."LSC Next Order Date";
                        ErrorText := StrSubstNo(SText025, ContTmp."LSC Next Order Restaurant", DT2Time(OrderDateTime));
                    end;
                    ContTmp."LSC Next Estimated Prod. Time" := OrderProdTime;
                end else begin
                    ContTmp."LSC Next Estimated Prod. Time" := 0;
                    ErrorText := TimeErrorText;
                end;
            end;
            ContTmp."LSC Pre-Order Print DateTime" := OrderDateTime - (5 * 60000);
            ContTmp."LSC Next Estimated Prod. Time" := OrderProdTime;
        end;
        if ErrorText <> '' then
            POSSESSION.SetValue('VALRESTAURAN', 'TRUE')
        ELSE
            POSSESSION.SetValue('VALRESTAURAN', 'FALSE')
    end;*/

    procedure ValidateTimeOnRestChange(var ContTmp: Record Contact; var ErrorText: Text; FromWS: Boolean; DelOrder: Record "LSC Delivery Order")
    var
        TimeCalculation: Option Finished,Started;
        FromDateTime: DateTime;
        ToDateTime: DateTime;
        ClosedInPeriod: Option Open,"Closed within Period","Closed at End Point";
        OrderDateTime: DateTime;
        HospFunc: Codeunit "LSC Hospitality Functions";
        TimeErrorText: text;
        GetEstimJobOnCallCenter: boolean;
        OrderProdTime: Integer;
        TimeOrder: Time;
        DateOrder: Date;
        SText061: Label 'El restaurante %1 está cerrado dentro del período de %2 a %3.\Seleccione otro restaurante o cambie la hora del pedido.';
        SText025: Label 'El restaurante %1 no está abierto en %2.\Seleccione otro restaurante o cambie la hora del pedido.';
        CalType: Option All,"Opening Hours",Receiving,"Rest. Order Taking",,,,Other;
    begin
        if OrderTypeOptionValue(DelOrder) then
            CalType := CalType::"Rest. Order Taking"
        else
            CalType := CalType::"Opening Hours";

        GetEstimJobOnCallCenter := false;
        if ContTmp."LSC Pre-Order Print DateTime" = 0DT then begin    //not a pre-order
            if FromWS then begin
                if ContTmp."LSC Next Order Date" = DT2Date(CurrentDateTime) then begin
                    if (ContTmp."LSC Next Order Time" = 0T) or (ContTmp."LSC Next Order Time" < DT2Time(CurrentDateTime)) then
                        OrderDateTime := CurrentDateTime
                    else
                        OrderDateTime := CreateDateTime(ContTmp."LSC Next Order Date", ContTmp."LSC Next Order Time");
                end else
                    if ContTmp."LSC Next Order Date" > DT2Date(CurrentDateTime) then
                        OrderDateTime := CreateDateTime(ContTmp."LSC Next Order Date", ContTmp."LSC Next Order Time");
            end else
                OrderDateTime := CurrentDateTime;
            if not FindProductionTime(CalType,
                   ContTmp."LSC Next Order Restaurant", 0, '', OrderDateTime, TimeCalculation::Finished,
                   TimeErrorText, GetEstimJobOnCallCenter, OrderProdTime, FromDateTime, ToDateTime, ClosedInPeriod)
          then begin
                if OrderDateTime <> 0DT then begin
                    if ClosedInPeriod = ClosedInPeriod::"Closed within Period" then begin
                        ErrorText := StrSubstNo(SText061, ContTmp."LSC Next Order Restaurant", DT2Time(FromDateTime), DT2Time(ToDateTime));
                    end else begin
                        ErrorText := StrSubstNo(SText025, ContTmp."LSC Next Order Restaurant", DT2Time(OrderDateTime));
                    end;
                    ContTmp."LSC Next Order Date" := DT2Date(OrderDateTime);
                    ContTmp."LSC Next Order Time" := DT2Time(OrderDateTime);
                    ContTmp."LSC Next Estimated Prod. Time" := OrderProdTime;
                end else begin
                    ContTmp."LSC Next Estimated Prod. Time" := 0;
                    ErrorText := TimeErrorText;
                end;
            end;
            ContTmp."LSC Next Order Date" := DT2Date(OrderDateTime);
            ContTmp."LSC Next Order Time" := DT2Time(OrderDateTime);
            ContTmp."LSC Next Estimated Prod. Time" := OrderProdTime;
        end else begin            // a pre-order
            OrderProdTime := 0;
            OrderDateTime := CreateDateTime(ContTmp."LSC Next Order Date", ContTmp."LSC Next Order Time");
            //if not HospFunc.FindProductionTime(
            if not FindProductionTime(CalType,
                 ContTmp."LSC Next Order Restaurant", 0, '', OrderDateTime, TimeCalculation::Started,
                 TimeErrorText, GetEstimJobOnCallCenter, OrderProdTime, FromDateTime, ToDateTime, ClosedInPeriod)
        then begin
                if OrderDateTime <> 0DT then begin
                    if ClosedInPeriod = ClosedInPeriod::"Closed within Period" then begin
                        TimeOrder := ContTmp."LSC Next Order Time";
                        DateOrder := ContTmp."LSC Next Order Date";
                        ErrorText := StrSubstNo(SText061, ContTmp."LSC Next Order Restaurant", DT2Time(FromDateTime), DT2Time(ToDateTime));
                    end else begin
                        TimeOrder := ContTmp."LSC Next Order Time";
                        DateOrder := ContTmp."LSC Next Order Date";
                        ErrorText := StrSubstNo(SText025, ContTmp."LSC Next Order Restaurant", DT2Time(OrderDateTime));
                    end;
                    ContTmp."LSC Next Estimated Prod. Time" := OrderProdTime;
                end else begin
                    ContTmp."LSC Next Estimated Prod. Time" := 0;
                    ErrorText := TimeErrorText;
                end;
            end;
            ContTmp."LSC Pre-Order Print DateTime" := OrderDateTime - (5 * 60000);
            ContTmp."LSC Next Estimated Prod. Time" := OrderProdTime;
        end;
        if ErrorText <> '' then
            POSSESSION.SetValue('VALRESTAURAN', 'TRUE')
        ELSE
            POSSESSION.SetValue('VALRESTAURAN', 'FALSE')
    end;

    procedure OrderTypeOptionValue(DelOrdType: Record "LSC Delivery Order"): Boolean
    var
        myInt: Integer;
        RetalCalendar: Record "LSC Retail Calendar";
        RetailCalendarLine: Record "LSC Retail Calendar Line";
    begin
        //28981
        IF DelOrdType."Order Type Option" = 4 then begin
            RetalCalendar.SetCurrentKey("Calendar Type", "Group Type", ID);
            RetalCalendar.SetRange("Calendar Type", RetalCalendar."Calendar Type"::"Rest. Order Taking");
            RetalCalendar.SetRange("Group Type", RetalCalendar."Group Type"::Store);
            RetalCalendar.SetRange(ID, DelOrdType."Restaurant No.");
            if RetalCalendar.FindFirst() then begin
                RetailCalendarLine.reset;
                RetailCalendarLine.SetRange(RetailCalendarLine."Calendar Type", RetalCalendar."Calendar Type");
                RetailCalendarLine.SetRange(RetailCalendarLine."Group Type", RetalCalendar."Group Type");
                RetailCalendarLine.SetRange(RetailCalendarLine."Calendar ID", RetalCalendar.ID);
                if RetailCalendarLine.FindFirst() then
                    exit(true)
                else
                    exit(false);
            end else
                exit(false);
        end else
            exit(false);
    end;

    procedure FindProductionTime(CalType: Option All,"Opening Hours",Receiving,"Rest. Order Taking",,,,Other; RestaurantNo: Code[10]; SchemeType: Option "Order","Product Group","Special Group",Item; SchemeCode: Code[20]; var DateTimeIn: DateTime; TimeCalc: Option Finish,Start; var ErrorText: Text[250]; GetEstimJobOnCC: Boolean; var ProdTimeLength: Integer; var TimeFrom: DateTime; var TimeTo: DateTime; var OpenStatus: Option Open,"Closed within Period","Closed at End Point"): Boolean
    var
        ProdTimingScheme: Record "LSC Rest. Prod. Timing Scheme";
        Store: Record "LSC Store";
        HospSetup: Record "LSC Hospitality Setup";
        RetailCalMgt: Codeunit "LSC Retail Calendar Management";
        MultiFactor: Integer;
        LoadLevel: Option Medium,Low,High,Intense,"None";
        Precision: BigInteger;
        Text001: Label 'El valor del campo %1 en %2 no está establecido.';
    begin
        ErrorText := '';
        case TimeCalc of
            TimeCalc::Finish:
                begin
                    MultiFactor := 1;
                    TimeFrom := DateTimeIn;
                end;
            TimeCalc::Start:
                begin
                    MultiFactor := -1;
                    TimeTo := DateTimeIn;
                end;
        end;
        Store.Get(RestaurantNo);
        case Store."Time Rounding Precision" of
            Store."Time Rounding Precision"::"No Rounding":
                Precision := 1000;
            Store."Time Rounding Precision"::"5 min":
                Precision := 1000 * 60 * 5;
            Store."Time Rounding Precision"::"10 min":
                Precision := 1000 * 60 * 10;
            Store."Time Rounding Precision"::"15 min":
                Precision := 1000 * 60 * 15;
            Store."Time Rounding Precision"::"20 min":
                Precision := 1000 * 60 * 20;
            Store."Time Rounding Precision"::"30 min":
                Precision := 1000 * 60 * 30;
        end;
        ProdTimeLength := 0;

        if not RetailCalMgt.StoreOpenAtTime(
                 RestaurantNo, CalType, DT2Date(DateTimeIn), DT2Time(DateTimeIn))
        then begin
            OpenStatus := OpenStatus::"Closed at End Point";
            exit(false);
        end;

        if (TimeCalc = TimeCalc::Finish) and (Store."Normal Order Timing" = Store."Normal Order Timing"::"Estimated Timing") then begin
            if not GetEstimJobOnCC then begin
                Store.CalcFields("Estim. Prod. Time");
                Store."Rest. Estim. Prod. Time (Min.)" := Store."Estim. Prod. Time";
            end;
            ProdTimeLength := Round(Store."Rest. Estim. Prod. Time (Min.)", 1);
            if (ProdTimeLength < Store."Max. Order Timing (Min.)") and (ProdTimeLength <> 0) then begin
                if DateTimeIn <= CurrentDateTime then
                    DateTimeIn := RoundDateTime(DateTimeIn + (MultiFactor * ProdTimeLength * 60000), Precision, '>');
                case TimeCalc of
                    TimeCalc::Finish:
                        TimeTo := DateTimeIn;
                    TimeCalc::Start:
                        TimeFrom := DateTimeIn;
                end;
                RetailCalMgt.GetStoreOpenStatusInPeriod(
                  RestaurantNo, CalType, TimeFrom, TimeTo, OpenStatus);
                exit((OpenStatus = OpenStatus::Open));
            end;
        end;

        LoadLevel := FindProductionLoad(RestaurantNo, DT2Date(DateTimeIn), DT2Time(DateTimeIn), TimeCalc);

        if ProdTimingScheme.Get(RestaurantNo, SchemeType, SchemeCode) and
           (LoadLevel in [LoadLevel::Low, LoadLevel::Medium, LoadLevel::High, LoadLevel::Intense])
        then begin
            case LoadLevel of
                LoadLevel::Low:
                    ProdTimeLength := ProdTimingScheme."Low Load Prod. Time (Min.)";
                LoadLevel::Medium:
                    ProdTimeLength := ProdTimingScheme."Medium Load Prod. Time (Min.)";
                LoadLevel::High:
                    ProdTimeLength := ProdTimingScheme."High Load Prod. Time (Min.)";
                LoadLevel::Intense:
                    ProdTimeLength := ProdTimingScheme."Intense Load Prod. Time (Min.)";
            end;
            if DateTimeIn <= CurrentDateTime then
                DateTimeIn := RoundDateTime(DateTimeIn + (MultiFactor * ProdTimeLength * 60000), Precision, '>');
            case TimeCalc of
                TimeCalc::Finish:
                    TimeTo := DateTimeIn;
                TimeCalc::Start:
                    TimeFrom := DateTimeIn;
            end;
            RetailCalMgt.GetStoreOpenStatusInPeriod(
              RestaurantNo, CalType, TimeFrom, TimeTo, OpenStatus);
            exit((OpenStatus = OpenStatus::Open));
        end else begin

            HospSetup.Get;
            if HospSetup."Order Process Time (Min.)" <> 0 then begin
                ProdTimeLength := HospSetup."Order Process Time (Min.)";
                if DateTimeIn <= CurrentDateTime then
                    DateTimeIn := RoundDateTime(DateTimeIn + (MultiFactor * ProdTimeLength * 60000), Precision, '>');
                case TimeCalc of
                    TimeCalc::Finish:
                        TimeTo := DateTimeIn;
                    TimeCalc::Start:
                        TimeFrom := DateTimeIn;
                end;
                RetailCalMgt.GetStoreOpenStatusInPeriod(
                  RestaurantNo, CalType, TimeFrom, TimeTo, OpenStatus);
                exit((OpenStatus = OpenStatus::Open));
            end else begin
                if DateTimeIn <= CurrentDateTime then
                    DateTimeIn := 0DT;
                ErrorText := StrSubstNo(Text001, HospSetup.FieldCaption("Order Process Time (Min.)"), HospSetup.TableCaption);
                exit(false);
            end;
        end;
    end;

    procedure FindProductionLoad(Restaurant: Code[10]; DateIn: Date; TimeIn: Time; TimeCalc: Option Finish,Start): Integer
    var
        CurrentLoadSchedule: Record "LSC Rest. Current Load Schd";
        DefaultLoadSchedule: Record "LSC Rest. Default Load Schd";
        DayOfWeek: Integer;
    begin
        CurrentLoadSchedule.Reset;
        CurrentLoadSchedule.SetRange("Store No.", Restaurant);
        CurrentLoadSchedule.SetRange(Date, DateIn);
        if CurrentLoadSchedule.FindSet then begin
            repeat
                CurrentLoadSchedule.CalcFields("Time To");
                case TimeCalc of
                    TimeCalc::Finish:
                        if (TimeIn >= CurrentLoadSchedule."Time From") and (TimeIn < CurrentLoadSchedule."Time To") then
                            exit(CurrentLoadSchedule."Load Level");
                    TimeCalc::Start:
                        if (TimeIn > CurrentLoadSchedule."Time From") and (TimeIn <= CurrentLoadSchedule."Time To") then
                            exit(CurrentLoadSchedule."Load Level");
                end;
            until CurrentLoadSchedule.Next = 0;
        end;

        DefaultLoadSchedule.Reset;
        DefaultLoadSchedule.SetRange("Store No.", Restaurant);
        if DefaultLoadSchedule.FindSet then begin
            repeat
                case TimeCalc of
                    TimeCalc::Finish:
                        if (TimeIn >= DefaultLoadSchedule."Time From") and (TimeIn < DefaultLoadSchedule."Time To") then begin
                            DayOfWeek := Date2DWY(DateIn, 1);
                            case DayOfWeek of
                                1:
                                    exit(DefaultLoadSchedule."Monday Load");
                                2:
                                    exit(DefaultLoadSchedule."Tuesday Load");
                                3:
                                    exit(DefaultLoadSchedule."Wednesday Load");
                                4:
                                    exit(DefaultLoadSchedule."Thursday Load");
                                5:
                                    exit(DefaultLoadSchedule."Friday Load");
                                6:
                                    exit(DefaultLoadSchedule."Saturday Load");
                                7:
                                    exit(DefaultLoadSchedule."Sunday Load");
                            end;
                        end;
                    TimeCalc::Start:
                        if (TimeIn > DefaultLoadSchedule."Time From") and (TimeIn <= DefaultLoadSchedule."Time To") then begin
                            DayOfWeek := Date2DWY(DateIn, 1);
                            case DayOfWeek of
                                1:
                                    exit(DefaultLoadSchedule."Monday Load");
                                2:
                                    exit(DefaultLoadSchedule."Tuesday Load");
                                3:
                                    exit(DefaultLoadSchedule."Wednesday Load");
                                4:
                                    exit(DefaultLoadSchedule."Thursday Load");
                                5:
                                    exit(DefaultLoadSchedule."Friday Load");
                                6:
                                    exit(DefaultLoadSchedule."Saturday Load");
                                7:
                                    exit(DefaultLoadSchedule."Sunday Load");
                            end;
                        end;
                end;
            until DefaultLoadSchedule.Next = 0;
        end;

        exit(99); //No Load Schedule exists for the specified time
    end;

    procedure ValidatePaqueteria(): Boolean
    var
        myInt: Integer;
        PosTransLine: Record "LSC POS Trans. Line";
        Paqueteria: Boolean;
    begin
        GlobalParametro();
        PosTransLine.Reset();
        PosTransLine.SetRange("Receipt No.", DelOrdT."Order No.");
        PosTransLine.SetRange("Entry Type", PosTransLine."Entry Type"::Item);
        PosTransLine.SetRange(Number, GlobalParametroPQ.Valor);
        if PosTransLine.FindFirst() then begin
            exit(true);
        end else
            exit(false)
    end;

    procedure GlobalParametro()
    var
        myInt: Integer;

    begin
        GlobalParametroPQ.Reset();
        GlobalParametroPQ.SetRange(Grupo, 'PAQUETERIA');
        GlobalParametroPQ.SetRange(Codigo, 'C807');
        if GlobalParametroPQ.FindFirst() then;

    end;

    procedure SalesChanel(PosTrans: Record "LSC POS Transaction")
    var
        SalesChan: Record "FSN Sales Channel";
        POSSetupExtend: Record "FSN POS Setup Extend";
        Description: Text[50];
        Exists: Boolean;
        OrderVal: Record "LSC Delivery Order";
        WebServiceTable: Record "FSN WebServiceTable";
    begin
        OrderVal.Reset();
        if OrderVal.Get(PosTrans."Receipt No.") then
            if WebServiceTable.Get(PosTrans."Receipt No.") then begin
                CLEAR(Description);
                Exists := TRUE;
                POSSetupExtend.RESET;
                POSSetupExtend.SETRANGE(POSSetupExtend.Type, POSSetupExtend.Type::CallCenter);
                POSSetupExtend.SETRANGE(POSSetupExtend."Line Type", POSSetupExtend."Line Type"::Parameter);
                POSSetupExtend.SETRANGE(POSSetupExtend."Value No.", 'CHANNELTYPE');
                if WebServiceTable.Store = 'APP' THEN
                    POSSetupExtend.SETRANGE(POSSetupExtend."Line No.", 5)
                ELSE
                    POSSetupExtend.SETRANGE(POSSetupExtend."Line No.", 8);
                POSSetupExtend.SETRANGE(POSSetupExtend."Store No.", '');
                IF POSSetupExtend.FindFirst() THEN;

                if SalesChan.Get(OrderVal."Order No.") then begin
                    SalesChan.INIT;
                    SalesChan."Receipt No" := OrderVal."Order No.";
                end;

                SalesChan."POS Terminal No" := '';
                SalesChan."Store No" := OrderVal."Restaurant No.";
                SalesChan.PhoneNo := OrderVal."Phone No.";
                SalesChan.Date := OrderVal."Order Date";
                SalesChan.Time := OrderVal."Contact Pickup Time";
                SalesChan.SalesStaff := OrderVal."Order Taker";
                SalesChan."Amount Incl. VAT" := OrderVal."Amount Incl. VAT";
                SalesChan.TypeChannel := Format(POSSetupExtend."Line No.");
                SalesChan.SalesChannel := POSSetupExtend."Data Extra 1";
                SalesChan."Pending Processing" := false;
                SalesChan.Ticket := '';
                SalesChan.Voided := NOT Exists;
                SalesChan.Comment := 'Automatic';
                IF NOT SalesChan.INSERT(TRUE) THEN
                    SalesChan.MODIFY(TRUE);
            end;
    end;

    procedure VentaPerdida()
    var
        ReplenSales: Record "FSN Replen. Sales Adj. Line";
        TransacHed: Record "LSC Transaction Header";
    begin
        TransacHed.Reset();
        TransacHed.SetRange(Date, Today());
        if TransacHed.Find('-') then begin
            repeat
                ReplenSales.Reset();
                ReplenSales.SetRange("Receipt No.", TransacHed."Receipt No.");
                ReplenSales.SetRange(Aprobada, false);
                if ReplenSales.Find('-') then
                    repeat
                        ReplenSales.Aprobada := true;
                        ReplenSales.Modify();
                        Commit();
                    until ReplenSales.Next() = 0;
            until TransacHed.Next() = 0;
        end;
    end;


    procedure ClearLog()
    var
        myInt: Integer;
        WsLog: Record "LSC WS Request Log";
    begin
        WsLog.Reset();
        WsLog.DeleteAll();
    end;
}
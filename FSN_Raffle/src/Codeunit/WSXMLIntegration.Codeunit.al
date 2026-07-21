codeunit 50087 "FSN WS XML Integration"
{

    trigger OnRun()
    begin
        GLOBALLANGUAGE(2058);
        SELECTLATESTVERSION;

        CASE gWSConfig OF
            'RIFA_TRANS_CUST':////////////
                RifaTransactionCustomer(gRequest);//WVILLALTA05DIC19-+
            'FSN_CHECK_RIFAS_TRANSAC':///////////
                CheckRifaTransac(gRequest, gResponse);//WVILLALTA 12.20
            'PREMIOS_DISP':////////////
                RifaPremiosDiscp(gRequest, gRifaNo, gStoreNo);//srv
            'PREMIOS_DISP_PARAMETER':////////////
                RifaPremiosParameter(gRequest, gRifaNo, gStoreNo);//srv
            'UPDATE_PREMIO':
                RifaPremiosUpdate(gRequest, gRifaNo, gStoreNo);//srv
            'UPDATE_PREMIO_PARAMETER':
                RifaPremiosUpdateParameter(gRequest, gRifaNo, gStoreNo);
        END;
    end;

    var
        test: text;
        gRequest: Text;
        gResponse: Text;
        gWSConfig: Text[50];
        gRifaNo: Code[30];
        gStoreNo: Code[10];
        WSFunc: Codeunit "LSC WS Functions";
        BOUtils: Codeunit "LSC BO Utils";
        gLocalProcess: Boolean;
        Globals: Codeunit "LSC POS Session";
        Text000: Label 'Request Node %1 not found in request';
        Text001: Label 'Invalid value %1 in Request Node %2';
        Text002: Label 'Request Source %1 not found in xml setup';
        Text003: Label 'Response Source %1 not found in xml setup';
        Text005: Label 'Invalid Response Node List in xml setup';
        Text101: Label '%1 %2 no existe';
        Text102: Label '%1 cannot be converted to %2 ';
        Text103: Label '%1 %2';
        Text104: Label 'Unable to update %1 %2';
        Text105: Label '%1 %2 is %3';
        Text106: Label 'Record %1 already exists. Value %2';
        Text107: Label 'Data is empty';
        Text108: Label 'Length string is %1, must be %2';

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

    begin
        if RequestID = 'FSN_CHECK_RIFAS_TRANSAC' then
            CheckRifaTransac(XMLRequest, XMLResponse);
    end;

    procedure CheckRifaTransac(var pxmlRequest: Text; var pxmlResponse: Text)
    var
        ReqXml: XmlDocument;
        ResXml: XmlDocument;
        ResXml2: XmlDocument;
        BodyNode: XmlNode;
        Node: XmlNode;
        LineNode: XmlNode;
        NodeList: XmlNodeList;
        RequestID: Text[30];
        RequestNodeList: array[3] of Text[50];
        ResponseNodeList: array[5] of Text[50];
        ParentNodeIndex: Integer;
        ParentNodeList: array[5] of Text[50];
        NodeName: Text[50];
        NodeBuffer: Record "LSC WS Node Buffer" temporary;
        ReqNodeList: Record "LSC WS Node Buffer" temporary;
        Response_Code: Code[30];
        Response_Text: Text[1024];
        UpdateAction: Text[30];
        AddOnly: Boolean;
        UpdateReplCounter: Boolean;
        ReplCounter: Integer;
        RecRefTemp: RecordRef;
        PosHeaderTmp: Record "LSC POS Transaction" temporary;
        PosLineTmp: Record "LSC POS Trans. Line" temporary;
        RecRef: RecordRef;
        //RemissionHeader: Record "50052";
        //RemissionLine: Record "50053";
        FlowFieldBuffer: Record "LSC FlowField Buffer" temporary;
        UpdateFieldList: Record "Field" temporary;
        TableNodeList: Record "LSC WS Node Buffer" temporary;
        RecRefTemp2: array[32] of RecordRef;
        PosHeaderTmp2: Record "LSC POS Transaction" temporary;
        PosLineTmp2: Record "LSC POS Trans. Line" temporary;
        //RemissionLineTmp2: Record "50053" temporary;
        //RemissionMgt: Codeunit "50050";
        _Counter: Integer;
        RecRefTempLine: RecordRef;
        UpdateFieldListLine: Record "Field" temporary;
        FlowFieldBufferLine: Record "LSC FlowField Buffer" temporary;
        Resp: Label 'No se pudo';
        cod: Label '51';
        //RemissionHeaderTmp3: Record "50052" temporary;
        //RemissionLineTmp3: Record "50053" temporary;
        lError: Text[30];
        _Key: RecordID;
        RifasMgt: Codeunit "FSN Rifasmanagement";
        RifaID: Code[20];
        RifaExists: Boolean;
        Msg: Text;
        RifaApply: Boolean;
        AmountResp: Decimal;
        RifaTable: Record "FSN Rifas";
        ResNodeList: Record "LSC WS Node Buffer" temporary;
        ReqXmlText: Text;
    begin

        RequestID := 'FSN_CHECK_RIFAS_TRANSAC';
        WSFunc.LoadRequest(pxmlRequest, ReqXml, RequestID, RequestNodeList, ResponseNodeList, ParentNodeIndex, ParentNodeList, BodyNode, Response_Code, Response_Text);

        //Get List of request nodes
        PosHeaderTmp.RESET;
        PosHeaderTmp.DELETEALL;
        CLEAR(PosHeaderTmp);
        PosHeaderTmp2.RESET;
        PosHeaderTmp2.DELETEALL;
        CLEAR(PosHeaderTmp2);
        PosLineTmp.RESET;
        PosLineTmp.DELETEALL;
        CLEAR(PosLineTmp);
        PosLineTmp2.RESET;
        PosLineTmp2.DELETEALL;
        CLEAR(PosLineTmp2);

        //Get Tables
        IF Response_Code = '0000' THEN BEGIN
            RecRefTemp.GETTABLE(PosLineTmp);
            WSFunc.GetTableChildNodes(RequestID, 0, BodyNode, ParentNodeIndex, ParentNodeList, 'LSC POS Trans. Line', RecRefTemp,
              FlowFieldBuffer, 1, UpdateFieldList, Response_Code, Response_Text);
        END;
        IF Response_Code = '0000' THEN BEGIN
            RecRefTempLine.GETTABLE(PosHeaderTmp);
            WSFunc.GetTableChildNodes(RequestID, 0, BodyNode, ParentNodeIndex, ParentNodeList, 'LSC POS Transaction', RecRefTempLine,
              FlowFieldBufferLine, 1, UpdateFieldListLine, Response_Code, Response_Text);
        END;
        IF Response_Code <> '0000' THEN BEGIN
            WSFunc.ErrorResponse(RequestID, ResponseNodeList, Response_Code, Response_Text, gLocalProcess, pxmlResponse);
            EXIT;
        END;

        //Process Request
        IF Response_Code = '0000' THEN BEGIN
            UpdateFieldList.SETRANGE(TableNo, 1);

            ReplCounter := 0;
            RecRefTemp.GETTABLE(PosHeaderTmp);
            RecRef.GETTABLE(PosHeaderTmp2);
            WSFunc.UpdateTableByTempTable(AddOnly, RecRefTemp, RecRef, ReplCounter, UpdateFieldList);
        END;
        IF Response_Code = '0000' THEN BEGIN
            UpdateFieldListLine.SETRANGE(TableNo, 1);

            ReplCounter := 0;
            RecRefTemp.GETTABLE(PosLineTmp);
            RecRef.GETTABLE(PosLineTmp2);
            WSFunc.UpdateTableByTempTable(AddOnly, RecRefTemp, RecRef, ReplCounter, UpdateFieldList);
        END;

        /* metodos de rifa */
        IF Response_Code = '0000' THEN BEGIN
            CLEAR(RifaID);
            RifaExists := PosLineTmp2.FIND('-');
            IF RifaExists THEN
                RifaExists := PosHeaderTmp2.FIND('-');
            IF RifaExists THEN BEGIN
                RifaID := RifasMgt.HayRifasActivas(PosHeaderTmp2."Store No.");
                RifaExists := RifaID <> '';
                IF RifaExists THEN
                    RifaExists := RifaTable.GET(RifaID);
            END;

            IF RifaExists THEN BEGIN
                RifaApply := RifasMgt.CheckApplyPosTmp(PosLineTmp2, PosHeaderTmp2, Msg, RifaApply, RifaTable);
            END;
        END;

        IF Response_Code <> '0000' THEN BEGIN
            WSFunc.ErrorResponse(RequestID, ResponseNodeList, Response_Code, Response_Text, gLocalProcess, pxmlResponse);
            EXIT;
        END;

        //Process Response Doc
        WSFunc.InitParentResNodeList(ResponseNodeList, ParentNodeIndex, ParentNodeList);
        //Respose Tables
        WSFunc.AddChildNodeTableList(RequestID, 1, ParentNodeIndex, ParentNodeList, 'LSC POS Trans. Line', TableNodeList,
          Response_Code, Response_Text);
        IF Response_Code = '0000' THEN BEGIN
            IF TableNodeList.FINDLAST THEN;
            RecRef.GETTABLE(PosLineTmp2);
            RecRefTemp2[TableNodeList."Entry No."].OPEN(TableNodeList."Table No.", TRUE);
            WSFunc.CopyTableToTempTable(RecRef, RecRefTemp2[TableNodeList."Entry No."], FlowFieldBuffer);
        END;

        IF Response_Code <> '0000' THEN BEGIN
            WSFunc.ErrorResponse(RequestID, ResponseNodeList, Response_Code, Response_Text, gLocalProcess, pxmlResponse);
            EXIT;
        END;
        WSFunc.CreateResponse(ResXml, RequestID, ResponseNodeList, BodyNode); //Revisar
        //WsFunc.LoadRequest(rq, ReqXml, RequestID, RequestNodeList, ResponseNodeList, ParentNodeIndex, ParentNodeList, BodyNode, Response_Code, Response_Text);
        //Set Tables
        TableNodeList.RESET;
        IF TableNodeList.FIND('-') THEN
            REPEAT
                WSFunc.SetTableChildNodes(RequestID, 1, BodyNode, ParentNodeIndex, ParentNodeList, TableNodeList.Source,
                  RecRefTemp2[TableNodeList."Entry No."], FlowFieldBuffer, Response_Code, Response_Text);
            UNTIL (TableNodeList.NEXT = 0) OR (Response_Code <> '0000');


        IF Response_Code = '0000' THEN
            WSFunc.AddChildNodeListText(RequestID, 1, ParentNodeIndex, ParentNodeList, 'RifaExists', FORMAT(RifaExists, 0, 9),
              ResNodeList, Response_Code, Response_Text);
        IF Response_Code = '0000' THEN
            WSFunc.AddChildNodeListText(RequestID, 1, ParentNodeIndex, ParentNodeList, 'RifaApply', FORMAT(RifaApply, 0, 9),
              ResNodeList, Response_Code, Response_Text);
        IF Response_Code = '0000' THEN
            WSFunc.AddChildNodeListText(RequestID, 1, ParentNodeIndex, ParentNodeList, 'Msg', Msg,
              ResNodeList, Response_Code, Response_Text);
        IF Response_Code = '0000' THEN
            WSFunc.AddChildNodeListText(RequestID, 1, ParentNodeIndex, ParentNodeList, 'AmountResp', FORMAT(PosHeaderTmp2.Prepayment, 0, 9),
              ResNodeList, Response_Code, Response_Text);

        IF Response_Code = '0000' THEN
            WSFunc.AppendChildNodeList(BodyNode, ResNodeList);

        IF Response_Code <> '0000' THEN BEGIN
            WSFunc.ErrorResponse(RequestID, ResponseNodeList, Response_Code, Response_Text, gLocalProcess, pxmlResponse);
            EXIT;
        END;
        pxmlResponse := format(ResXml);

    end;

    procedure RifaTransactionCustomer(Request: Text)
    var
        RetailSetup: Record "LSC Retail Setup";
        BOUTIL: Codeunit "LSC BO Utils";
        Rifa: Code[20];
        Customer: Code[20];
        DistLocation: Code[10];
    begin
        Rifa := '';
        Customer := '';
        DistLocation := '';
        Rifa := BOUTIL.SeparateCombinedValue(1, COPYSTR(Request, 1, 100));
        Customer := BOUTIL.SeparateCombinedValue(2, COPYSTR(Request, 1, 100));
        DistLocation := BOUTIL.SeparateCombinedValue(3, COPYSTR(Request, 1, 100));
        RifaTransactionCustomerExec(Rifa, Customer, DistLocation);//28981
    end;

    procedure RifaPremiosDiscp(Request: Text; pRifaNo: Code[30]; pStore: Code[20])
    var
        RetailSetup: Record "LSC Retail Setup";
        BOUTIL: Codeunit "LSC BO Utils";
        Rifa: Code[20];
        Customer: Code[20];
        DistLocation: Code[10];
    begin
        Rifa := '';
        Customer := '';
        DistLocation := '';
        DistLocation := BOUTIL.SeparateCombinedValue(3, COPYSTR(Request, 1, 100));
        RifaTransactionDisp(pRifaNo, pStore, DistLocation);
    end;

    procedure RifaPremiosParameter(Request: Text; pRifaNo: Code[30]; pStore: Code[20])
    var
        RetailSetup: Record "LSC Retail Setup";
        BOUTIL: Codeunit "LSC BO Utils";
        Rifa: Code[20];
        Customer: Code[20];
        DistLocation: Code[10];
    begin
        Rifa := '';
        Customer := '';
        DistLocation := '';
        DistLocation := BOUTIL.SeparateCombinedValue(3, COPYSTR(Request, 1, 100));
        RifaParameterDay(pRifaNo, pStore, DistLocation);//28981
    end;

    procedure RifaPremiosUpdate(Request: Text; pRifaNo: Code[30]; pStore: Code[20])
    var
        RetailSetup: Record "LSC Retail Setup";
        BOUTIL: Codeunit "LSC BO Utils";
        Rifa: Code[20];
        Customer: Code[20];
        DistLocation: Code[10];
    begin
        Rifa := '';
        Customer := '';
        DistLocation := '';
        DistLocation := BOUTIL.SeparateCombinedValue(3, COPYSTR(Request, 1, 100));
        ActualizarDisponibilidad(pRifaNo, pStore, DistLocation);
    end;

    procedure RifaPremiosUpdateParameter(Request: Text; pRifaNo: Code[30]; pStore: Code[20])
    var
        RetailSetup: Record "LSC Retail Setup";
        BOUTIL: Codeunit "LSC BO Utils";
        Rifa: Code[20];
        Customer: Code[20];
        DistLocation: Code[10];
    begin
        Rifa := '';
        Customer := '';
        DistLocation := '';
        DistLocation := BOUTIL.SeparateCombinedValue(3, COPYSTR(Request, 1, 100));
        ActualizarDispParameter(pRifaNo, pStore, DistLocation);
    end;

    procedure RifaTransactionCustomerExec(RifaCode: Code[20]; Customer: Code[20]; DistLocation: Code[10])
    var
        SqlConnection: DotNet SqlConnection;
        SqlCommand: DotNet SqlCommand;
        SqlDataReader: DotNet SqlDataReader;
        ConnectionString: Text[125];
        SqlString: Text;
        Exists: Boolean;
        STRTODAY_START: Text[20];
        STRTODAY_END: Text[20];
        DisLocation: Record "LSC Distribution Location";
        ForCount: Integer;
        Rifas: Record "FSN Rifas";
        lTextConn: Label 'Data Source=%1;Initial Catalog=%2;Integrated Security=false; User ID=%3;Password=%4;';
        lTextSimbol: Label '''''';
        PARAMETER: Record "FSN parameter";
        ProsessQuery: Boolean;
        F_Date: Text;
        F_Mes: Text;
        F_Dia: Text;
        FF_Date: Text;
        FF_Mes: Text;
        FF_Dia: Text;
    begin
        //WVILLALTA05DIC196-
        DisLocation.GET(DistLocation);

        ConnectionString := STRSUBSTNO(lTextConn, DisLocation."Db Server Name", DisLocation."Db. Path && Name", DisLocation."User ID", DisLocation.Password);
        SqlConnection := SqlConnection.SqlConnection(ConnectionString);
        Rifas.GET(RifaCode);

        STRTODAY_START := FORMAT(Date2DMY(TODAY - 330, 3)) + FORMAT(Date2DMY(TODAY - 330, 2)) + FORMAT(Date2DMY(TODAY - 330, 1));
        STRTODAY_END := FORMAT(Date2DMY(Today, 3)) + FORMAT(Date2DMY(Today, 2)) + FORMAT(Date2DMY(Today, 1));
        IF Rifas.FechaInicio <> 0D THEN begin
            F_Date := FORMAT(Date2DMY(Rifas.FechaInicio, 3));
            F_Mes := FORMAT(Date2DMY(Rifas.FechaInicio, 2));
            F_Dia := FORMAT(Date2DMY(Rifas.FechaInicio, 1));
        end;

        IF Rifas.FechaFin <> 0D THEN begin
            FF_Date := FORMAT(Date2DMY(Rifas.FechaFin, 3));
            FF_Mes := FORMAT(Date2DMY(Rifas.FechaFin, 2));
            FF_Dia := FORMAT(Date2DMY(Rifas.FechaFin, 1));
        end;
        if PARAMETER.Get('VALHORIFA', 'HO') then begin
            if PARAMETER.Activo then begin
                if PARAMETER.Valor = DistLocation then
                    ProsessQuery := true
                else
                    ProsessQuery := false;
            end else
                ProsessQuery := false;
        end else
            ProsessQuery := false;

        if ProsessQuery then begin
            SqlString := 'SELECT [Receipt No][RCPT] from' +
                       '[DBTIENDA].[dbo].[FASANI$RifasHistorialF] f JOIN ' +
                       ' [DBTIENDA].[dbo].[FASANI$Transaction Header] t ' +
                       'ON f.[Store No]=t.[Store No_] ' +
                       'AND f.[Receipt No]=t.[Receipt No_] ' +
                       'WHERE t.Date >= DATEFROMPARTS(' + F_Date + ',' + F_Mes + ',' + F_Dia + ') AND t.Date <= DATEFROMPARTS(' + FF_Date + ',' + FF_Mes + ',' + FF_Dia +
                       ') AND f.[Rifa No]=''' + RifaCode + ''' ' +
                       'AND t.[Customer No_]=''' + Customer + ''' ' +
                       'AND f.Ganador = ''1''';
        end else begin
            IF DisLocation.Code = 'HO' THEN BEGIN
                SqlString := 'SELECT [Receipt No][RCPT] from ' +
                            '[BCENTRAL].[dbo].[FASANI$FSN RifasHistorialF$594b3331-6f78-498d-9bf2-c068ca153252] f JOIN ' +
                            '[BCENTRAL].[dbo].[FASANI$LSC Transaction Header$5ecfc871-5d82-43f1-9c54-59685e82318d] t ' +
                            'ON f.[Store No]=t.[Store No_] ' +
                            'AND f.[Receipt No]=t.[Receipt No_] ' +
                            'WHERE t.Date >= DATEFROMPARTS(' + F_Date + ',' + F_Mes + ',' + F_Dia + ') AND t.Date <= DATEFROMPARTS(' + FF_Date + ',' + FF_Mes + ',' + FF_Dia + ') ' +
                            'AND f.[Rifa No]=''' + RifaCode + ''' ' +
                            'AND t.[Customer No_]=''' + Customer + ''' ' +
                            'AND f.Ganador = ''1''';
            END ELSE begin
                SqlString := 'SELECT [Receipt No][RCPT] from ' +
         '[DBTIENDA].[dbo].[FASANI$FSN RifasHistorialF$594b3331-6f78-498d-9bf2-c068ca153252] f JOIN ' +
         '[DBTIENDA].[dbo].[FASANI$LSC Transaction Header$5ecfc871-5d82-43f1-9c54-59685e82318d] t ' +
         'ON f.[Store No]=t.[Store No_] ' +
         'AND f.[Receipt No]=t.[Receipt No_] ' +
         'WHERE t.Date >= DATEFROMPARTS(' + F_Date + ',' + F_Mes + ',' + F_Dia + ') AND t.Date <= DATEFROMPARTS(' + FF_Date + ',' + FF_Mes + ',' + FF_Dia + ') ' +
         'AND f.[Rifa No]=''' + RifaCode + ''' ' +
         'AND t.[Customer No_]=''' + Customer + ''' ' +
         'AND f.Ganador = ''1''';
            end;
        end;


        SqlConnection.Open();
        SqlCommand := SqlConnection.CreateCommand();
        SqlCommand.CommandText := SqlString;
        SqlDataReader := SqlCommand.ExecuteReader();
        Exists := FALSE;
        IF SqlDataReader.Read() THEN
            Exists := TRUE;

        gResponse := RifaCode;
        IF Exists THEN
            gResponse := '';

        SqlDataReader.Close();
        SqlConnection.Close();


        //WVILLALTA05DIC196+
    end;

    procedure SetXMLRequest(pRequest: Text; pWSConfig: Text[50])
    begin
        gRequest := pRequest;
        gResponse := '';
        gWSConfig := pWSConfig;
    end;

    procedure SetXMLRequestDisponible(pRequest: Text; RifaNo: Code[30]; StoreNo: Code[10]; pWSConfig: Text[50])
    begin
        gRequest := pRequest;
        gResponse := '';
        gWSConfig := pWSConfig;
        gRifaNo := RifaNo;
        gStoreNo := StoreNo;
    end;

    procedure GetXMLResponse(var pXMLResponse: Text; var pXMLConfig: Text[50])
    begin
        pXMLResponse := gResponse;
        pXMLConfig := gWSConfig;
    end;

    procedure RifaTransactionDisp(RifaCode: Code[30]; pStoreNo: Code[10]; DistLocation: Code[10])
    var
        SqlConnection: DotNet SqlConnection;
        SqlCommand: DotNet SqlCommand;
        SqlDataReader: DotNet SqlDataReader;
        ConnectionString: Text[125];
        SqlString: Text;
        Exists: Boolean;
        STRTODAY_START: Text[20];
        STRTODAY_END: Text[20];
        DisLocation: Record "LSC Distribution Location";
        ForCount: Integer;
        Rifas: Record "FSN Rifas";
        lTextConn: Label 'Data Source=%1;Initial Catalog=%2;Integrated Security=false; User ID=%3;Password=%4;';
        lTextSimbol: Label '''''';
        PARAMETER: Record "FSN parameter";
        ProsessQuery: Boolean;
    begin
        DisLocation.GET(DistLocation);

        ConnectionString := STRSUBSTNO(lTextConn, DisLocation."Db Server Name", DisLocation."Db. Path && Name", DisLocation."User ID", DisLocation.Password);
        SqlConnection := SqlConnection.SqlConnection(ConnectionString);
        Rifas.GET(RifaCode);

        if PARAMETER.Get('VALHORIFA', 'HO') then begin
            if PARAMETER.Activo then begin
                if PARAMETER.Valor = DistLocation then
                    ProsessQuery := true
                else
                    ProsessQuery := false;
            end else
                ProsessQuery := false;
        end else
            ProsessQuery := false;

        if ProsessQuery then begin
            SqlString := 'select [No Rifa][RESUL] FROM [DBTIENDA].[dbo].[FASANI$RifasTiendas]' + 'where [No Rifa] = ''' + RifaCode + ''' and [Store No] = ''' + pStoreNo + ''' AND PremiosTotales = PremiosOtorgados';
        end else
            SqlString := 'select [No Rifa][RESUL] FROM [BCENTRAL].[dbo].[FASANI$FSN RifasTiendas$594b3331-6f78-498d-9bf2-c068ca153252]' + 'where [No Rifa] = ''' + RifaCode + ''' and [Store No] = ''' + pStoreNo + ''' AND PremiosTotales = PremiosOtorgados';
        //SqlString := 'select [No Rifa][RESUL] FROM [DBTIENDA].[dbo].[FASANI$RifasTiendas]' + 'where [No Rifa] = ''' + RifaCode + ''' and [Store No] = ''' + pStoreNo + ''' AND PremiosTotales = PremiosOtorgados';

        SqlConnection.Open();
        SqlCommand := SqlConnection.CreateCommand();
        SqlCommand.CommandText := SqlString;
        SqlDataReader := SqlCommand.ExecuteReader();
        Exists := FALSE;
        IF SqlDataReader.Read() THEN begin
            Exists := TRUE;
        end;
        SqlDataReader.Close();
        SqlConnection.Close();

        gResponse := RifaCode;
        IF Exists THEN
            gResponse := '';
    end;

    procedure RifaParameterDay(RifaCode: Code[30]; pStoreNo: Code[10]; DistLocation: Code[10])
    var
        SqlConnection: DotNet SqlConnection;
        SqlCommand: DotNet SqlCommand;
        SqlDataReader: DotNet SqlDataReader;
        ConnectionString: Text[125];
        SqlString: Text;
        Exists: Boolean;
        STRTODAY_START: Text[20];
        STRTODAY_END: Text[20];
        DisLocation: Record "LSC Distribution Location";
        ForCount: Integer;
        Rifas: Record "FSN Rifas";
        lTextConn: Label 'Data Source=%1;Initial Catalog=%2;Integrated Security=false; User ID=%3;Password=%4;';
        lTextSimbol: Label '''''';
        PARAMETER: Record "FSN parameter";
        ProsessQuery: Boolean;
        F_Date: Text;
        F_Mes: Text;
        F_Dia: Text;
        FF_Date: Text;
        FF_Mes: Text;
        FF_Dia: Text;
    begin
        DisLocation.GET(DistLocation);

        ConnectionString := STRSUBSTNO(lTextConn, DisLocation."Db Server Name", DisLocation."Db. Path && Name", DisLocation."User ID", DisLocation.Password);
        SqlConnection := SqlConnection.SqlConnection(ConnectionString);
        Rifas.GET(RifaCode);

        //STRTODAY_START := FORMAT(Date2DMY(TODAY, 3)) + '-' + FORMAT(Date2DMY(TODAY, 2)) + '-' + FORMAT(Date2DMY(TODAY, 1));
        //STRTODAY_END := FORMAT(Date2DMY(Today, 3)) + '-' + FORMAT(Date2DMY(Today, 2)) + '-' + FORMAT(Date2DMY(Today, 1));

        F_Date := FORMAT(Date2DMY(Today, 3));
        F_Mes := FORMAT(Date2DMY(Today, 2));
        F_Dia := FORMAT(Date2DMY(Today, 1));

        FF_Date := FORMAT(Date2DMY(Today, 3));
        FF_Mes := FORMAT(Date2DMY(Today, 2));
        FF_Dia := FORMAT(Date2DMY(Today, 1));


        if PARAMETER.Get('VALHORIFA', 'HO') then begin
            if PARAMETER.Activo then begin
                if PARAMETER.Valor = DistLocation then
                    ProsessQuery := true
                else
                    ProsessQuery := false;
            end else
                ProsessQuery := false;
        end else
            ProsessQuery := false;

        if ProsessQuery then begin
            SqlString := 'SELECT [No Rifa][RESUL] FROM [DBTIENDA].[dbo].[FASANI$RifasParam] where [No Rifa] = ''' + RifaCode + ''' and [Store No] = ''' + pStoreNo + ''' and Fecha <= DATEFROMPARTS(' + F_Date + ',' + F_Mes + ',' + F_Dia + ') and FechaFin >= DATEFROMPARTS(' + FF_Date + ',' + FF_Mes + ',' + FF_Dia + ') and PremiosTotales = PremiosOtorgados';
        end else
            SqlString := 'SELECT [No Rifa][RESUL] FROM [BCENTRAL].[dbo].[FASANI$FSN RifasParam$594b3331-6f78-498d-9bf2-c068ca153252] where [No Rifa] = ''' + RifaCode + ''' and [Store No] = ''' + pStoreNo + ''' and Fecha <= DATEFROMPARTS(' + F_Date + ',' + F_Mes + ',' + F_Dia + ') and FechaFin >= DATEFROMPARTS(' + FF_Date + ',' + FF_Mes + ',' + FF_Dia + ') and PremiosTotales = PremiosOtorgados';
        //SqlString := 'select [No Rifa][RESUL] FROM [DBTIENDA].[dbo].[FASANI$RifasTiendas]' + 'where [No Rifa] = ''' + RifaCode + ''' and [Store No] = ''' + pStoreNo + ''' AND PremiosTotales = PremiosOtorgados';

        SqlConnection.Open();
        SqlCommand := SqlConnection.CreateCommand();
        SqlCommand.CommandText := SqlString;
        SqlDataReader := SqlCommand.ExecuteReader();
        Exists := FALSE;
        IF SqlDataReader.Read() THEN begin
            Exists := TRUE;
        end;
        SqlDataReader.Close();
        SqlConnection.Close();

        gResponse := RifaCode;
        IF Exists THEN
            gResponse := '';
    end;

    procedure ActualizarDisponibilidad(RifaCode: Code[30]; pStoreNo: Code[10]; DistLocation: Code[10])
    var
        SqlConnection: DotNet SqlConnection;
        SqlCommand: DotNet SqlCommand;
        SqlDataReader: DotNet SqlDataReader;
        ConnectionString: Text[125];
        SqlString: Text;
        Exists: Boolean;
        STRTODAY_START: Text[20];
        STRTODAY_END: Text[20];
        DisLocation: Record "LSC Distribution Location";
        ForCount: Integer;
        Rifas: Record "FSN Rifas";
        lTextConn: Label 'Data Source=%1;Initial Catalog=%2;Integrated Security=false; User ID=%3;Password=%4;';
        lTextSimbol: Label '''''';
        PARAMETER: Record "FSN parameter";
        ProsessQuery: Boolean;
    begin
        DisLocation.GET(DistLocation);

        ConnectionString := STRSUBSTNO(lTextConn, DisLocation."Db Server Name", DisLocation."Db. Path && Name", DisLocation."User ID", DisLocation.Password);
        SqlConnection := SqlConnection.SqlConnection(ConnectionString);
        Rifas.GET(RifaCode);

        STRTODAY_START := FORMAT(Date2DMY(TODAY, 1)) + '-' + FORMAT(Date2DMY(TODAY, 2)) + '-' + FORMAT(Date2DMY(TODAY, 3));
        STRTODAY_END := FORMAT(Date2DMY(Today, 1)) + '-' + FORMAT(Date2DMY(Today, 2)) + '-' + FORMAT(Date2DMY(Today, 3));

        if PARAMETER.Get('VALHORIFA', 'HO') then begin
            if PARAMETER.Activo then begin
                if PARAMETER.Valor = DistLocation then
                    ProsessQuery := true
                else
                    ProsessQuery := false;
            end else
                ProsessQuery := false;
        end else
            ProsessQuery := false;

        if ProsessQuery then
            SqlString := 'UPDATE [DBTIENDA].[dbo].[FASANI$RifasTiendas] ' + 'SET PremiosOtorgados = case when [PremiosOtorgados] = 0 then 1 else [PremiosOtorgados] + 1 end ' + 'where [No Rifa] = ''' + RifaCode + ''' and [Store No] = ''' + pStoreNo + '''' + ' UPDATE [DBTIENDA].[dbo].[FASANI$RifasParam] SET PremiosOtorgados = case when [PremiosOtorgados] = 0 then 1 else [PremiosOtorgados] + 1 end where [No Rifa] = ''' + RifaCode + ''' and [Store No] = ''' + pStoreNo + ''' and Fecha <= ''' + STRTODAY_START + ''' and FechaFin >= ''' + STRTODAY_END + ''''
        else
            SqlString := 'UPDATE [BCENTRAL].[dbo].[FASANI$FSN RifasTiendas$594b3331-6f78-498d-9bf2-c068ca153252] SET PremiosOtorgados = case when [PremiosOtorgados] = 0 then 1 else [PremiosOtorgados] + 1 end where [No Rifa] = ''' + RifaCode + ''' and [Store No] = ''' + pStoreNo + '''';



        SqlConnection.Open();
        SqlCommand := SqlConnection.CreateCommand();
        SqlCommand.CommandText := SqlString;
        SqlDataReader := SqlCommand.ExecuteReader();
        Exists := true;
        IF SqlDataReader.Read() THEN
            Exists := false;

        SqlDataReader.Close();
        SqlConnection.Close();

        gResponse := RifaCode;
        IF not Exists THEN
            gResponse := 'MISCOMMUNICATION';
    end;

    procedure ActualizarDispParameter(RifaCode: Code[30]; pStoreNo: Code[10]; DistLocation: Code[10])
    var
        SqlConnection: DotNet SqlConnection;
        SqlCommand: DotNet SqlCommand;
        SqlDataReader: DotNet SqlDataReader;
        ConnectionString: Text[125];
        SqlString: Text;
        Exists: Boolean;
        STRTODAY_START: Text[20];
        STRTODAY_END: Text[20];
        DisLocation: Record "LSC Distribution Location";
        ForCount: Integer;
        Rifas: Record "FSN Rifas";
        lTextConn: Label 'Data Source=%1;Initial Catalog=%2;Integrated Security=false; User ID=%3;Password=%4;';
        lTextSimbol: Label '''''';
        PARAMETER: Record "FSN parameter";
        ProsessQuery: Boolean;
        F_Date: Text;
        F_Mes: Text;
        F_Dia: Text;
        FF_Date: Text;
        FF_Mes: Text;
        FF_Dia: Text;
    begin
        DisLocation.GET(DistLocation);

        ConnectionString := STRSUBSTNO(lTextConn, DisLocation."Db Server Name", DisLocation."Db. Path && Name", DisLocation."User ID", DisLocation.Password);
        SqlConnection := SqlConnection.SqlConnection(ConnectionString);
        Rifas.GET(RifaCode);

        /*STRTODAY_START := FORMAT(Date2DMY(TODAY, 3)) + '-' + FORMAT(Date2DMY(TODAY, 2)) + '-' + FORMAT(Date2DMY(TODAY, 1));
        STRTODAY_END := FORMAT(Date2DMY(Today, 3)) + '-' + FORMAT(Date2DMY(Today, 2)) + '-' + FORMAT(Date2DMY(Today, 1));*/

        F_Date := FORMAT(Date2DMY(Today, 3));
        F_Mes := FORMAT(Date2DMY(Today, 2));
        F_Dia := FORMAT(Date2DMY(Today, 1));

        FF_Date := FORMAT(Date2DMY(Today, 3));
        FF_Mes := FORMAT(Date2DMY(Today, 2));
        FF_Dia := FORMAT(Date2DMY(Today, 1));

        if PARAMETER.Get('VALHORIFA', 'HO') then begin
            if PARAMETER.Activo then begin
                if PARAMETER.Valor = DistLocation then
                    ProsessQuery := true
                else
                    ProsessQuery := false;
            end else
                ProsessQuery := false;
        end else
            ProsessQuery := false;

        if ProsessQuery then
            SqlString := 'UPDATE [DBTIENDA].[dbo].[FASANI$RifasParam] SET PremiosOtorgados = case when [PremiosOtorgados] = 0 then 1 else [PremiosOtorgados] + 1 end where [No Rifa] = ''' + RifaCode + ''' and [Store No] = ''' + pStoreNo + ''' and Fecha <= ''' + STRTODAY_START + ''' and FechaFin >= ''' + STRTODAY_END + ''''
        else
            SqlString := 'UPDATE [BCENTRAL].[dbo].[FASANI$FSN RifasParam$594b3331-6f78-498d-9bf2-c068ca153252] SET PremiosOtorgados = case when [PremiosOtorgados] = 0 then 1 else [PremiosOtorgados] + 1 end where [No Rifa] = ''' + RifaCode + ''' and [Store No] = ''' + pStoreNo + ''' and Fecha <= DATEFROMPARTS(' + F_Date + ',' + F_Mes + ',' + F_Dia + ') and FechaFin >= DATEFROMPARTS(' + FF_Date + ',' + FF_Mes + ',' + FF_Dia + ')';

        SqlConnection.Open();
        SqlCommand := SqlConnection.CreateCommand();
        SqlCommand.CommandText := SqlString;
        SqlDataReader := SqlCommand.ExecuteReader();
        Exists := true;
        IF SqlDataReader.Read() THEN
            Exists := false;

        SqlDataReader.Close();
        SqlConnection.Close();

        gResponse := RifaCode;
        IF not Exists THEN
            gResponse := 'MISCOMMUNICATION';
    end;

}


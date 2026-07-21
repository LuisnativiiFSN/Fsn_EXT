codeunit 50029 "FSN Ecommerce Functions"
{

    trigger OnRun()
    var
        _Code: Code[50];
        _PosTransaction: Record "LSC POS Transaction";
    begin

        SELECTLATESTVERSION;
        _Code := GlobalCommand;
        IF _Code = '' THEN
            _Code := 'SENDORDERS';

        CASE _Code OF
            'SENDORDERS':
                SendToServerOrders('DELIVERY', 5);
            'SENDORDER':
                BEGIN
                    IF _PosTransaction.GET(GlobalReceipt) THEN
                        SendToServerOrder(_PosTransaction);
                END;
            'MANUAL':
                XMLManualSend();
            'FSN_ECOMM_ITEMCROSS_X':
                XGetCrossItems();
            'FSN_ECOMM_CHECK_DELSTORE_X':
                XCheckOrderDelivery(FALSE);
            'FSN_ECOMM_CHECK_DELTAKEAWAY_X':
                XCheckOrderDelivery(TRUE);
        END;
    end;

    var
        GlobalCommand: Text[50];
        GlobalReceipt: Code[20];
        salas: Text;
        GlobalRequest: Text;
        GlobalResponse: Text;
        gLocalProcess: Boolean;
        Text001: Label 'Georeference cant be empty (Latitude, Longitude)';
        Text002: Label 'Must be store for takeaway';
        Text003: Label 'Must be select other store for takeaway';
        Text004: Label 'No suggested stores in the area';
        Text006: Label 'Out of cover';
        PosFuncProfile: Record "LSC POS Func. Profile";
        WSFunc: Codeunit "LSC WS Functions";
        WebServiceSetup: Record "LSC Web Service Setup";
        WSRequest: Record "LSC WS Request";
        WebServicesConn: Codeunit "LSC Web Services Connection";
        XMLDomMgt: Codeunit "LSC XML DOM Mgt.";
        gRequestID: Code[30];


    procedure SendToServerOrders(pSalesType: Text[30]; pRepeatUntilInt: Integer)
    var
        pPOSTransaction: Record "LSC POS Transaction";
        pPOSTransaction2: Record "LSC POS Transaction";
        CSWebTable: Record "FSN WebServiceTable";
        DeliveryOrder: Record "LSC Delivery Order";
        pStore: Record "LSC Store";
        pError: Boolean;
        pErrorText: Text[1024];
        CounterExit: Boolean;
        pInt: Integer;
    begin
        CounterExit := FALSE;
        pInt := pRepeatUntilInt;

        pPOSTransaction.RESET;
        pPOSTransaction.SETCURRENTKEY("Store No.", "Sales Type", "Transaction Type", "Index Field");
        pPOSTransaction.SETRANGE(pPOSTransaction."Sales Type", COPYSTR(pSalesType, 1, 20));
        pPOSTransaction.SETRANGE(pPOSTransaction."Entry Status", pPOSTransaction."Entry Status"::Suspended);
        IF pPOSTransaction.FINDSET THEN
            REPEAT
                IF pRepeatUntilInt > 0 THEN BEGIN
                    pInt -= 1;
                    CounterExit := pInt = 0;
                END;
                IF CSWebTable.GET(pPOSTransaction."Receipt No.") THEN BEGIN
                    IF pStore.GET(pPOSTransaction."Store No.") then
                        PosFuncProfile.GET(pStore."Functionality Profile");

                    IF SendPosTransClient('SEND_POSTRANS_BACKUP', pPOSTransaction, pError, pErrorText) THEN BEGIN
                        IF pPOSTransaction2.GET(pPOSTransaction."Receipt No.") THEN
                            IF NOT DeliveryOrder.GET(pPOSTransaction."Receipt No.") THEN
                                pPOSTransaction2.DELETE(TRUE);
                    END;
                END;
                COMMIT;
            UNTIL (pPOSTransaction.NEXT = 0) OR CounterExit;
    end;

    procedure SendToServerOrder(pPOSTransaction: Record "LSC POS Transaction")
    var
        pPOSTransaction2: Record "LSC POS Transaction";
        pStore: Record "LSC Store";
        pError: Boolean;
        pErrorText: Text[1024];
        CSWebTable: Record "FSN WebServiceTable";
        DeliveryOrder: Record "LSC Delivery Order";
    begin
        CLEAR(CSWebTable);
        if CSWebTable.GET(pPOSTransaction."Receipt No.") then;//Found

        if pStore.GET(pPOSTransaction."Store No.") then
            POSFuncProfile.GET(pStore."Functionality Profile");

        SetPosFuncProfile(POSFuncProfile);
        if SendPosTransClient('SEND_POSTRANS_BACKUP', pPOSTransaction, pError, pErrorText) THEN BEGIN
            if pPOSTransaction2.GET(pPOSTransaction."Receipt No.") THEN
                if NOT DeliveryOrder.GET(pPOSTransaction."Receipt No.") THEN
                    pPOSTransaction2.DELETE(TRUE);
        END;
    end;

    local procedure XMLManualSend()
    var
        WebServicesConn: Codeunit "LSC Web Services Connection";
        WebServerList: Record "LSC WS Server Buffer" temporary;
        pRequestID: Text[30];
        pxmlRequest: Text;
        pxmlResponse: Text;
    begin
        WebServerList.INIT;
        WebServerList."Entry No." := 1;
        WebServerList."Local Request" := FALSE;

        XMLGetText(pxmlRequest, WebServerList);
        WebServerList.INSERT;

        IF pxmlRequest <> '' THEN
            WebServicesConn.SendRequest('SEND_POSTRANS_BACKUP', WebServerList, pxmlRequest, pxmlResponse);
    end;

    local procedure XMLGetText(var XML: Text; WebServerList: Record "LSC WS Server Buffer" temporary)
    var
        File: DotNet File;
        FilterString: Text;
        XMLDocument: DotNet XmlDocument;
        Parameters: Record "FSN Parameter";
    begin
        IF Parameters.GET('ECOMM', 'XRESEND') THEN
            IF Parameters.Valor <> '' THEN BEGIN
                FilterString := Parameters.Valor;
                XML := File.ReadAllText(FilterString);
                WebServerList."Dist. Location" := Parameters."Distribution Location Ext.";
            END;
    end;

    procedure ClearGlobals()
    begin
        GlobalCommand := '';
        GlobalReceipt := '';
        CLEAR(GlobalRequest);
        CLEAR(GlobalResponse);
    end;

    procedure ClearTableTmp(var pPOSTransLineTMP: Record "LSC POS Trans. Line" temporary)
    begin
        pPOSTransLineTMP.RESET;
        pPOSTransLineTMP.DELETEALL();
        CLEAR(pPOSTransLineTMP);
    end;

    procedure SetCommandGlobals(pCommand: Text[50]; pReceipt: Code[20])
    begin
        GlobalCommand := pCommand;
        GlobalReceipt := pReceipt;
    end;


    procedure SetRequestGlobals(var pGlobalRequest: Text; pCommand: Text[50]): Text
    begin
        GlobalRequest := pGlobalRequest;
        GlobalCommand := pCommand;
    end;


    procedure GetResponseGlobals(): Text
    begin
        EXIT(GlobalResponse);
    end;

    procedure SetPosFuncProfile(var pPosFuncProfile: Record "LSC POS Func. Profile")
    begin
        //SetPosFuncProfile
        PosFuncProfile := pPosFuncProfile;
    end;

    procedure XCheckOrderDelivery(pIsTakeaway: Boolean)
    var
        ContactTMP: Record "LSC Delivery Contact Address" temporary;
        OrderTMP: Record "LSC POS Trans. Line" temporary;
        POSTransLTMP: Record "LSC POS Trans. Line" temporary;
        StoreTMP: Record "LSC Store" temporary;
        DeliveryStreet_l: Record "LSC Delivery Street";
        DeliveryStreetTMP: Record "LSC Delivery Street" temporary;
        StoreLink_l: Record "FSN Store Link";
        Parameters: Record "FSN Parameter";
        Lat: Decimal;
        Lon: Decimal;
        TextError: Text;
        StringVar: Text;
        RequestItemXML: Text;
        Item_l: Record Item;
        Store_l: Record "LSC Store";
        lText001: Label 'Georeference cant be empty (Latitude, Longitude)';
    begin
        DeliveryStreetTMP.RESET;
        DeliveryStreetTMP.DELETEALL;
        CLEAR(DeliveryStreetTMP);
        StoreTMP.RESET;
        StoreTMP.DELETEALL;
        CLEAR(StoreTMP);
        CLEAR(TextError);
        CLEAR(StringVar);

        XmlToDelContactTMP(ContactTMP, GlobalRequest);
        XmlToDelOrderTMP(OrderTMP, GlobalRequest);
        XmlToPOSTransLineTMP(POSTransLTMP, GlobalRequest);

        if Parameters.Get('ECOMM', 'XCHECK') then;

        IF pIsTakeaway THEN BEGIN
            IF OrderTMP."Store No." = '' THEN BEGIN
                GlobalResponse := XCreateDefaultResp(Text002, '0001');
                EXIT;
            END;
            StoreLink_l.RESET;
            StoreLink_l.SETCURRENTKEY(StoreLink_l.Sort, StoreLink_l."Km Between Points");
            StoreLink_l.SETRANGE(StoreLink_l.Type, StoreLink_l.Type::StoreGroup);
            StoreLink_l.SETRANGE(StoreLink_l."Parent Code", OrderTMP."Store No.");
            StoreLink_l.SETFILTER(StoreLink_l."Store No.", '<>%1&<>%2', '', OrderTMP."Store No.");
            StoreLink_l.SETFILTER(StoreLink_l."Link Type", '<2');//Call stores
            IF StoreLink_l.FIND('-') THEN
                REPEAT

                    StoreTMP.INIT;
                    StoreTMP."No." := StoreLink_l."Store No.";
                    StoreTMP."Fraud Sort Field" := StoreLink_l."Km Between Points";
                    IF StoreTMP."No." <> OrderTMP."Store No." THEN
                        IF StoreTMP.INSERT THEN;

                UNTIL StoreLink_l.NEXT = 0
            ELSE BEGIN
                StoreTMP.INIT;
                StoreTMP."No." := OrderTMP."Store No.";
                StoreTMP.INSERT;
            END;
        END ELSE BEGIN
            IF EVALUATE(Lat, ContactTMP.Latitude) AND EVALUATE(Lon, ContactTMP.Longitude) THEN;
            IF NOT ((Lat <> 0) AND (Lon <> 0)) THEN BEGIN
                GlobalResponse := XCreateDefaultResp(Text001, '0001');
                EXIT;
            END;

            StoreLink_l.RESET;
            StoreLink_l.SETRANGE(StoreLink_l.Type, StoreLink_l.Type::StoreSetup);
            StoreLink_l.SETFILTER(StoreLink_l."Link Type", '%1|%2|%3'
                    , StoreLink_l."Link Type"::DeliveryStore, StoreLink_l."Link Type"::NormalStore, StoreLink_l."Link Type"::None);
            IF StoreLink_l.FIND('-') THEN
                REPEAT
                    IF NOT StoreTMP.GET(StoreLink_l."Parent Code") THEN BEGIN
                        StoreTMP."No." := StoreLink_l."Parent Code";
                        StoreTMP.Name := StoreLink_l."Parent Code Name";
                        StoreTMP."Fraud Sort Field" := GetDistanceGeographic(Lat, Lon, StoreLink_l."Parent Latitude", StoreLink_l."Parent Longitude");
                        IF StoreTMP."Fraud Sort Field" <= 5 THEN
                            StoreTMP.INSERT;
                    END;
                UNTIL StoreLink_l.NEXT = 0;
        END;

        StoreTMP.SETCURRENTKEY("Fraud Sort Field");
        IF StoreTMP.FIND('-') THEN BEGIN
            IF pIsTakeaway THEN
                RequestItemXML := XmlFromItemInventoryTransTMP(POSTransLTMP, StoreTMP, OrderTMP."Store No.")
            ELSE
                RequestItemXML := XmlFromItemInventoryTransTMP(POSTransLTMP, StoreTMP, StoreTMP."No.");


        END ELSE BEGIN
            IF NOT Item_l.GET(Parameters."Value Text 1") THEN//Setup Item
                Item_l.INIT;
            OrderTMP.Number := Item_l."No.";
            OrderTMP."Unit of Measure" := Item_l."Base Unit of Measure";
            OrderTMP."Delivery User ID" := Item_l."No." + Item_l."Base Unit of Measure";
            OrderTMP."Cost Price" := Item_l."LSC Unit Price Incl. VAT";
            OrderTMP."Add. Charge Exists" := TRUE;
            OrderTMP.MODIFY;
        END;
        XCompareInventoryDelivery(RequestItemXML, pIsTakeaway, OrderTMP, ContactTMP, POSTransLTMP);

    end;


    procedure XCreateDefaultResp(pTextError: Text; pCodeError: Text[10]): Text
    var
        xmlDocument: DotNet XmlDocument;
        xNode: DotNet XmlNode;
        xChild: DotNet XmlNode;
    begin
        xCreateDocDefault(xmlDocument, xNode, 'Response', pTextError, pCodeError);
        EXIT(xmlDocument.OuterXml);
    end;


    procedure xCreateDocDefault(var xmlDocument: DotNet XmlDocument; var xNodeBody: DotNet XmlNode; xBodyName: Text[50]; pRespText: Text; pRespCode: Text[50])
    var
        xChild: DotNet XmlNode;
    begin
        xmlDocument := xmlDocument.XmlDocument();

        xNodeBody := xmlDocument.CreateProcessingInstruction('xml', 'version="1.0" encoding="utf-8" standalone="no"');
        xmlDocument.AppendChild(xNodeBody);

        xNodeBody := xmlDocument.CreateNode('element', xBodyName, '');
        xmlDocument.AppendChild(xNodeBody);
        IF GlobalCommand <> '' THEN BEGIN
            xChild := xmlDocument.CreateNode('element', 'Request_ID', '');
            xChild.InnerText := GlobalCommand;
            xNodeBody.AppendChild(xChild);
        END;
        xChild := xmlDocument.CreateNode('element', 'Response_Text', '');
        xChild.InnerText := pRespText;
        xNodeBody.AppendChild(xChild);
        xChild := xmlDocument.CreateNode('element', 'Response_Code', '');
        xChild.InnerText := pRespCode;
        xNodeBody.AppendChild(xChild);
    end;


    procedure xSetAttributeNode(var xChild: DotNet XmlNode; xNodeName: Text[50]; xInnerText: Text)
    var
        Attribute: DotNet XmlAttribute;
    begin
        Attribute := xChild.OwnerDocument.CreateAttribute(xNodeName);
        Attribute.Value := xInnerText;
        xChild.Attributes.SetNamedItem(Attribute);
    end;


    procedure XGetCrossItems()
    var
        SQLRead: Codeunit "FSN SQL Data Reader";
        SqlDataReaderNET: DotNet SqlDataReader;
        POSTransLineTMP: Record "LSC POS Trans. Line" temporary;
        Parameters: Record "FSN Parameter";
        lText001: Label 'Conection Error DB';
        lText002: Label 'Cant be suggest items';
        QueryTxt: Text;
        Index: Integer;
        StringVal: Text;
        TextError: Text;
        XmlString: Text;
        DistLoc: Code[20];
        SP: Text[250];
    begin

        Clear(DistLoc);
        Clear(SP);
        XmlToPOSTransLineTMP(POSTransLineTMP, GlobalRequest);
        if Parameters.Get('ECOMM', 'XCROSSITEM') then begin
            DistLoc := Parameters."Distribution Location Ext.";
            SP := Parameters.Valor;
        end;

        Index := 1;
        CLEAR(StringVal);
        CLEAR(TextError);
        IF POSTransLineTMP.FIND('-') THEN
            REPEAT
                IF POSTransLineTMP.Number <> '' THEN
                    StringVal += POSTransLineTMP.Number + ',';
                Index += 1;
            UNTIL (POSTransLineTMP.NEXT = 0) OR (Index > 9);

        StringVal := COPYSTR(StringVal, 1, STRLEN(StringVal) - 1);
        QueryTxt := SP + ' ''' + StringVal + ''',''' + GlobalCommand + '''';

        XmlString := SQLCall(DistLoc, QueryTxt);

        GlobalResponse := XmlString;
    end;


    procedure xGetResponseOnly(var xmlDocument: DotNet XmlDocument; xBodyName: Text[50]) Resp: Text
    var
        xRespBody: DotNet XmlNode;
    begin
        xBodyName := '/' + xBodyName;

        xRespBody := xmlDocument.SelectSingleNode(xBodyName);
        Resp := xRespBody.OuterXml;
        EXIT(Resp);
    end;


    procedure XCompareInventoryDelivery(pRequestXML: Text; pIsTakeaway: Boolean; var pOrderTMP: Record "LSC POS Trans. Line" temporary; var pContactTMP: Record "LSC Delivery Contact Address"; var pPosLineTMP: Record "LSC POS Trans. Line")
    var
        QueryTxt: Text;
        Index: Integer;
        XmlString: Text;
        lText001: Label 'Conection Error DB';
        lText002: Label 'Cant be suggest items';
        POSTransLineTMP: Record "LSC POS Trans. Line" temporary;
        StoreTMP: Record "LSC Store" temporary;
        TextError: Text;
        xmlDocument: DotNet XmlDocument;
        xmlResponse: DotNet XmlDocument;
        xNode: DotNet XmlNode;
        xNodeRes: DotNet XmlNode;
        xChild: DotNet XmlNode;
        xChildFields: DotNet XmlNode;
        WSFunc: Codeunit "LSC WS Functions";
        ResponseNodeList: array[5] of Text[50];
        RequestNodeList: array[3] of Text[50];
        ParentNodeIndex: Integer;
        ParentNodeList: array[5] of Text[50];
        TableNodeList: Record "LSC WS Node Buffer" temporary;
        Response_Code: Code[30];
        Response_Text: Text[1024];
        RequestID: Text[30];
        RecRef: RecordRef;
        RecRefTemp: array[32] of RecordRef;
        FlowFieldBuffer: Record "LSC FlowField Buffer" temporary;
        UpdateFieldList: Record "Field" temporary;
        Req: Text;
        WJSonHeader: Codeunit "FSN Windows Forms NET";
        Odata: Codeunit "FSN OData Conexion";
        FileMgt: Codeunit "File Management";
        FilterString: Text;
        FileSystem: DotNet StreamWriter;
        Parameters: Record "FSN Parameter";
        DistLoc: Code[20];
        SP: Text[250];
    begin
        Clear(DistLoc);
        Clear(SP);
        if Parameters.Get('ECOMM', 'XINVENTORY') then begin
            DistLoc := Parameters."Distribution Location Ext.";
            SP := Parameters.Valor;
        end;

        IF pOrderTMP."Add. Charge Exists" THEN BEGIN
            xCreateDocDefault(xmlResponse, xNodeRes, 'Response', Text006, '0000');  //Hour setup
            xNode := xmlResponse.CreateNode('element', 'Response_Body', '');
            xNodeRes.AppendChild(xNode);

            IF pOrderTMP.FIND('-') THEN BEGIN
                xChild := xmlResponse.CreateNode('element', 'Order', '');
                xNode.AppendChild(xChild);

                xChildFields := xmlResponse.CreateNode('element', WJSonHeader.NameConvert(pOrderTMP.FIELDNAME(pOrderTMP.Description)), '');
                xChildFields.InnerText := STRSUBSTNO('ENVIO PAQUETERIA EN %1 HORAS', FORMAT(48));//Hour setup
                xChild.AppendChild(xChildFields);
                xChildFields := xmlResponse.CreateNode('element', WJSonHeader.NameConvert(pOrderTMP.FIELDNAME(pOrderTMP."Delivery User ID")), '');
                xChildFields.InnerText := pOrderTMP."Delivery User ID";
                xChild.AppendChild(xChildFields);
                xChildFields := xmlResponse.CreateNode('element', WJSonHeader.NameConvert(pOrderTMP.FIELDNAME(pOrderTMP.Number)), '');
                xChildFields.InnerText := pOrderTMP.Number;
                xChild.AppendChild(xChildFields);
                xChildFields := xmlResponse.CreateNode('element', WJSonHeader.NameConvert(pOrderTMP.FIELDNAME(pOrderTMP."Unit of Measure")), '');
                xChildFields.InnerText := pOrderTMP."Unit of Measure";
                xChild.AppendChild(xChildFields);
                xChildFields := xmlResponse.CreateNode('element', WJSonHeader.NameConvert(pOrderTMP.FIELDNAME(pOrderTMP."Cost Price")), '');
                xChildFields.InnerText := FORMAT(pOrderTMP."Cost Price");
                xChild.AppendChild(xChildFields);
                xChildFields := xmlResponse.CreateNode('element', WJSonHeader.NameConvert(pOrderTMP.FIELDNAME(pOrderTMP."Add. Charge Exists")), '');
                xChildFields.InnerText := FORMAT(pOrderTMP."Add. Charge Exists");
                xChild.AppendChild(xChildFields);
            END;

            pPosLineTMP.RESET;
            IF pPosLineTMP.FIND('-') THEN
                REPEAT
                    xChild := xmlResponse.CreateNode('element', 'Lines', '');
                    xNode.AppendChild(xChild);

                    xChildFields := xmlResponse.CreateNode('element', WJSonHeader.NameConvert(pPosLineTMP.FIELDNAME(pPosLineTMP."Delivery User ID")), '');
                    xChildFields.InnerText := pPosLineTMP."Delivery User ID";
                    xChild.AppendChild(xChildFields);
                    xChildFields := xmlResponse.CreateNode('element', WJSonHeader.NameConvert(pPosLineTMP.FIELDNAME(pPosLineTMP.Number)), '');
                    xChildFields.InnerText := pPosLineTMP.Number;
                    xChild.AppendChild(xChildFields);
                    xChildFields := xmlResponse.CreateNode('element', WJSonHeader.NameConvert(pPosLineTMP.FIELDNAME(pPosLineTMP."Unit of Measure")), '');
                    xChildFields.InnerText := pPosLineTMP."Unit of Measure";
                    xChild.AppendChild(xChildFields);
                    xChildFields := xmlResponse.CreateNode('element', WJSonHeader.NameConvert(pPosLineTMP.FIELDNAME(pPosLineTMP."Remaining Quantity")), '');
                    xChildFields.InnerText := FORMAT(pPosLineTMP."Remaining Quantity");
                    xChild.AppendChild(xChildFields);
                    xChildFields := xmlResponse.CreateNode('element', WJSonHeader.NameConvert(pPosLineTMP.FIELDNAME(pPosLineTMP.Quantity)), '');
                    xChildFields.InnerText := FORMAT(pPosLineTMP.Quantity);
                    xChild.AppendChild(xChildFields);
                    xChildFields := xmlResponse.CreateNode('element', WJSonHeader.NameConvert(pPosLineTMP.FIELDNAME(pPosLineTMP.Marked)), '');
                    xChildFields.InnerText := 'true';
                    xChild.AppendChild(xChildFields);

                UNTIL pPosLineTMP.NEXT = 0;

            GlobalResponse := xGetResponseOnly(xmlResponse, 'Response');
            EXIT;
        END;

        xmlDocument := xmlDocument.XmlDocument();
        xmlDocument.LoadXml(pRequestXML);
        xNode := xmlDocument.SelectSingleNode('/Data');
        QueryTxt := xNode.OuterXml();

        IF pIsTakeaway THEN
            QueryTxt := SP + ' ''' + QueryTxt + ''',''' + GlobalCommand + ''',1'
        ELSE
            QueryTxt := SP + ' ''' + QueryTxt + ''',''' + GlobalCommand + ''',0';

        XmlString := SQLCall(DistLoc, QueryTxt);
        GlobalResponse := XmlString;
        if Parameters.Descripcion <> '' then begin // path
            FilterString := 'C:\temp\NUMBERS\DELEVAL' + pContactTMP."Phone No." + '.xml';
            FileSystem := FileSystem.StreamWriter(FilterString);
            FileSystem.Write(QueryTxt + '-[' + pContactTMP."Post Code" + ']-' + pContactTMP.Latitude + '-' + FORMAT(pContactTMP.Longitude));
            FileSystem.Close();



            FilterString := 'C:\temp\NUMBERS\DELEVAL' + pContactTMP."Phone No." + '-R.xml';
            FileSystem := FileSystem.StreamWriter(FilterString);
            FileSystem.Write(GlobalResponse + '-[' + pContactTMP."Post Code" + ']-' + pContactTMP.Latitude + '-' + FORMAT(pContactTMP.Longitude));
            FileSystem.Close();
        end;
    end;


    procedure XmlToPOSTransLineTMP(var pPOSTransLineTmp: Record "LSC POS Trans. Line" temporary; pjSonTxt: Text)
    var
        xmlDocument: DotNet XmlDocument;
        xNode: DotNet XmlNode;
        xNodeList: DotNet XmlNodeList;
        xChildNodes: DotNet XmlNodeList;
        xChild: DotNet XmlNode;
        i: Integer;
        j: Integer;
        c: Integer;
        k: Integer;
        Dec_: Decimal;
        Int_: Integer;
        WindowsNet: Codeunit "FSN Windows Forms NET";
    begin
        ClearTableTmp(pPOSTransLineTmp);
        xmlDocument := xmlDocument.XmlDocument();
        xmlDocument.LoadXml(pjSonTxt);
        xNodeList := xmlDocument.SelectNodes('/Data/Lines');
        i := xNodeList.Count();
        j := 0;
        WHILE i > j DO BEGIN
            xNode := xNodeList.Item(j);
            IF NOT ISNULL(xNode) THEN BEGIN
                pPOSTransLineTmp.INIT;
                pPOSTransLineTmp."Receipt No." := 'X';
                pPOSTransLineTmp."Line No." := j;

                xChildNodes := xNode.ChildNodes();
                c := xChildNodes.Count();
                k := 0;
                WHILE c > k DO BEGIN
                    xChild := xChildNodes.Item(k);
                    IF NOT ISNULL(xChild) THEN
                        CASE xChild.Name OF
                            WindowsNet.NameConvert(pPOSTransLineTmp.FIELDNAME(Number)):
                                pPOSTransLineTmp.Number := xChild.InnerText;
                            WindowsNet.NameConvert(pPOSTransLineTmp.FIELDNAME(pPOSTransLineTmp."Unit of Measure")):
                                pPOSTransLineTmp."Unit of Measure" := xChild.InnerText;
                            WindowsNet.NameConvert(pPOSTransLineTmp.FIELDNAME(pPOSTransLineTmp.Quantity)):
                                BEGIN
                                    IF EVALUATE(Dec_, xChild.InnerText) THEN
                                        pPOSTransLineTmp.Quantity := Dec_;
                                END;
                            WindowsNet.NameConvert(pPOSTransLineTmp.FIELDNAME(pPOSTransLineTmp.Marked)):
                                BEGIN
                                    IF EVALUATE(Int_, xChild.InnerText) THEN
                                        IF Int_ = 1 THEN
                                            pPOSTransLineTmp.Marked := TRUE;
                                END;
                        END;
                    k += 1;
                END;
                IF pPOSTransLineTmp.Number <> '' THEN
                    pPOSTransLineTmp.INSERT;

            END;
            j += 1;
        END;
    end;


    procedure XmlToDelContactTMP(var pDelContactAddTmp: Record "LSC Delivery Contact Address" temporary; pjSonTxt: Text)
    var
        xmlDocument: DotNet XmlDocument;
        xNode: DotNet XmlNode;
        xNodeList: DotNet XmlNodeList;
        xChildNodes: DotNet XmlNodeList;
        xChild: DotNet XmlNode;
        i: Integer;
        j: Integer;
        c: Integer;
        k: Integer;
        POSTrans: Record "LSC POS Trans. Line";
        WindosFunctNet: Codeunit "FSN Windows Forms NET";
    begin
        pDelContactAddTmp.RESET;
        pDelContactAddTmp.DELETEALL;
        CLEAR(pDelContactAddTmp);

        xmlDocument := xmlDocument.XmlDocument();
        xmlDocument.LoadXml(pjSonTxt);
        xNodeList := xmlDocument.SelectNodes('/Data/Contact');
        i := xNodeList.Count();
        IF i > 0 THEN BEGIN
            xNode := xNodeList.Item(0);
            IF NOT ISNULL(xNode) THEN BEGIN
                pDelContactAddTmp.INIT;

                xChildNodes := xNode.ChildNodes();
                c := xChildNodes.Count();
                k := 0;
                WHILE c > k DO BEGIN
                    xChild := xChildNodes.Item(k);
                    IF NOT ISNULL(xChild) THEN
                        CASE xChild.Name OF
                            WindosFunctNet.NameConvert(pDelContactAddTmp.FIELDNAME(pDelContactAddTmp."Phone No.")):
                                pDelContactAddTmp."Phone No." := xChild.InnerText;
                            WindosFunctNet.NameConvert(pDelContactAddTmp.FIELDNAME(pDelContactAddTmp.Latitude)):
                                pDelContactAddTmp.Latitude := xChild.InnerText;
                            WindosFunctNet.NameConvert(pDelContactAddTmp.FIELDNAME(pDelContactAddTmp.Longitude)):
                                pDelContactAddTmp.Longitude := xChild.InnerText;
                            WindosFunctNet.NameConvert(pDelContactAddTmp.FIELDNAME(pDelContactAddTmp."Post Code")):
                                pDelContactAddTmp."Post Code" := xChild.InnerText;
                        END;
                    k += 1;
                END;
                IF pDelContactAddTmp."Phone No." <> '' THEN
                    pDelContactAddTmp.INSERT;
            END;
        END;
    end;


    procedure XmlToDelOrderTMP(var pOrderTmp: Record "LSC POS Trans. Line" temporary; pjSonTxt: Text)
    var
        xmlDocument: DotNet XmlDocument;
        xNode: DotNet XmlNode;
        xNodeList: DotNet XmlNodeList;
        xChildNodes: DotNet XmlNodeList;
        xChild: DotNet XmlNode;
        i: Integer;
        j: Integer;
        c: Integer;
        k: Integer;
        Dec_: Decimal;
        WindosFunctNet: Codeunit "FSN Windows Forms NET";
    begin
        pOrderTmp.RESET;
        pOrderTmp.DELETEALL;
        CLEAR(pOrderTmp);

        xmlDocument := xmlDocument.XmlDocument();
        xmlDocument.LoadXml(pjSonTxt);
        xNodeList := xmlDocument.SelectNodes('/Data/Order');
        i := xNodeList.Count();
        IF i > 0 THEN BEGIN
            xNode := xNodeList.Item(0);
            IF NOT ISNULL(xNode) THEN BEGIN
                pOrderTmp.INIT;
                pOrderTmp."Receipt No." := 'R';

                xChildNodes := xNode.ChildNodes();
                c := xChildNodes.Count();
                k := 0;
                WHILE c > k DO BEGIN
                    xChild := xChildNodes.Item(k);
                    IF NOT ISNULL(xChild) THEN
                        CASE xChild.Name OF
                            WindosFunctNet.NameConvert(pOrderTmp.FIELDNAME(pOrderTmp."Store No.")):
                                pOrderTmp."Store No." := xChild.InnerText;
                            WindosFunctNet.NameConvert(pOrderTmp.FIELDNAME(pOrderTmp.Amount)):
                                BEGIN
                                    IF EVALUATE(Dec_, xChild.InnerText) THEN
                                        pOrderTmp.Amount := Dec_;
                                END;
                        END;
                    k += 1;
                END;
                IF pOrderTmp."Receipt No." <> '' THEN
                    pOrderTmp.INSERT;
            END;
        END;
    end;


    procedure XmlToSoreTMP(var pStoreTMP: Record "LSC Store" temporary; pXMLString: Text)
    var
        xmlDocument: DotNet XmlDocument;
        xNode: DotNet XmlNode;
        xNodeList: DotNet XmlNodeList;
        xChildNodes: DotNet XmlNodeList;
        xChild: DotNet XmlNode;
        i: Integer;
        j: Integer;
        c: Integer;
        k: Integer;
        Dec_: Decimal;
        WindosFunctNet: Codeunit "FSN Windows Forms NET";
    begin
        pStoreTMP.RESET;
        pStoreTMP.DELETEALL;
        CLEAR(pStoreTMP);

        xmlDocument := xmlDocument.XmlDocument();
        xmlDocument.LoadXml(pXMLString);
        xNodeList := xmlDocument.SelectNodes('/Data/StoreLinks');
        i := xNodeList.Count();
        IF i > 0 THEN BEGIN
            xNode := xNodeList.Item(0);
            IF NOT ISNULL(xNode) THEN BEGIN
                pStoreTMP.INIT;

                xChildNodes := xNode.ChildNodes();
                c := xChildNodes.Count();
                k := 0;
                WHILE c > k DO BEGIN
                    xChild := xChildNodes.Item(k);
                    IF NOT ISNULL(xChild) THEN
                        CASE xChild.Name OF
                            WindosFunctNet.NameConvert(pStoreTMP.FIELDNAME(pStoreTMP."No.")):
                                pStoreTMP."No." := xChild.InnerText;
                            WindosFunctNet.NameConvert(pStoreTMP.FIELDNAME(pStoreTMP."Fraud Sort Field")):
                                BEGIN
                                    IF EVALUATE(Dec_, xChild.InnerText) THEN
                                        pStoreTMP."Fraud Sort Field" := Dec_;
                                END;
                        END;
                    k += 1;
                END;
                IF pStoreTMP."No." <> '' THEN
                    IF pStoreTMP.INSERT THEN;
            END;
        END;
    end;


    procedure XmlFromPOSTransLineTMP(var pPtlTmp: Record "LSC POS Trans. Line" temporary): Text
    var
        xmlDocument: DotNet XmlDocument;
        xNode: DotNet XmlNode;
        xChildFields: DotNet XmlNode;
        xChild: DotNet XmlNode;
        WJSonHeader: Codeunit "FSN Windows Forms NET";
    begin
        xCreateDocDefault(xmlDocument, xNode, 'Response', '', '0000');

        pPtlTmp.RESET;
        IF pPtlTmp.FIND('-') THEN
            REPEAT
                xChild := xmlDocument.CreateNode('element', 'Lines', '');
                xNode.AppendChild(xChild);

                xChildFields := xmlDocument.CreateNode('element', WJSonHeader.NameConvert(pPtlTmp.FIELDNAME(pPtlTmp.Number)), '');
                xChildFields.InnerText := pPtlTmp.Number + pPtlTmp."Unit of Measure";
                xChild.AppendChild(xChildFields);
                xChildFields := xmlDocument.CreateNode('element', WJSonHeader.NameConvert(pPtlTmp.FIELDNAME(Quantity)), '');
                xChildFields.InnerText := FORMAT(pPtlTmp.Quantity);
                xChild.AppendChild(xChildFields);
                xChildFields := xmlDocument.CreateNode('element', WJSonHeader.NameConvert(pPtlTmp.FIELDNAME("Customer Qty Used")), '');
                xChildFields.InnerText := FORMAT(pPtlTmp."Customer Qty Used");
                xChild.AppendChild(xChildFields);

            UNTIL pPtlTmp.NEXT = 0;


        GlobalResponse := xmlDocument.OuterXml;
    end;


    procedure XmlFromItemInventoryTransTMP(var pPOSTransLineTMP: Record "LSC POS Trans. Line" temporary; var pStoreTMP: Record "LSC Store" temporary; pStoreDefault: Code[10]): Text
    var
        ItemSetupTMP: Record "FSN Inventory Internal Log" temporary;
        ItemUM: Record "Item Unit of Measure";
        xmlDocument: DotNet XmlDocument;
        xNode: DotNet XmlNode;
        xChildFields: DotNet XmlNode;
        xChild: DotNet XmlNode;
        Attribute: DotNet XmlAttribute;
        WJSonHeader: Codeunit "FSN Windows Forms NET";
        WSFunc: Codeunit "LSC WS Functions";
    begin
        ItemSetupTMP.RESET;
        ItemSetupTMP.DELETEALL;
        CLEAR(ItemSetupTMP);
        IF pPOSTransLineTMP.FIND('-') THEN
            REPEAT
                IF NOT ItemSetupTMP.GET(pPOSTransLineTMP.Number) THEN BEGIN
                    ItemSetupTMP.INIT;
                    ItemSetupTMP."No." := pPOSTransLineTMP.Number;
                    ItemSetupTMP."Qty. per UM" := 0;
                    ItemSetupTMP.INSERT;
                END;
                IF NOT ItemUM.GET(pPOSTransLineTMP.Number, pPOSTransLineTMP."Unit of Measure") THEN BEGIN
                    ItemUM.INIT;
                    ItemUM."Qty. per Unit of Measure" := 1;
                END;
                ItemSetupTMP."Qty. per UM" += pPOSTransLineTMP.Quantity * ItemUM."Qty. per Unit of Measure";
                ItemSetupTMP.MODIFY;

                pPOSTransLineTMP.Counter := 0;
                pPOSTransLineTMP.MODIFY;
            UNTIL pPOSTransLineTMP.NEXT = 0;

        xCreateDocDefault(xmlDocument, xNode, 'Data', '', '0000');
        IF pPOSTransLineTMP.FIND('-') THEN
            REPEAT
                IF NOT ItemSetupTMP.GET(pPOSTransLineTMP.Number) THEN BEGIN
                    ItemSetupTMP.INIT;
                    ItemSetupTMP."Qty. per UM" := 0;
                END;

                pPOSTransLineTMP.Counter := ItemSetupTMP."Qty. per UM";
                pPOSTransLineTMP.MODIFY;

                xChild := xmlDocument.CreateNode('element', 'Lines', '');
                xSetAttributeNode(xChild, WJSonHeader.NameConvert(pPOSTransLineTMP.FIELDNAME(pPOSTransLineTMP.Number)), pPOSTransLineTMP.Number);
                xSetAttributeNode(xChild, WJSonHeader.NameConvert(pPOSTransLineTMP.FIELDNAME(pPOSTransLineTMP."Unit of Measure")), pPOSTransLineTMP."Unit of Measure");
                xSetAttributeNode(xChild, WJSonHeader.NameConvert(pPOSTransLineTMP.FIELDNAME(pPOSTransLineTMP.Counter)), DELCHR(FORMAT(ROUND(pPOSTransLineTMP.Counter, 1)), '=', ','));
                xSetAttributeNode(xChild, WJSonHeader.NameConvert(pPOSTransLineTMP.FIELDNAME(pPOSTransLineTMP."Store No.")), pStoreDefault);
                xNode.AppendChild(xChild);

            UNTIL pPOSTransLineTMP.NEXT = 0;

        IF pStoreTMP.FIND('-') THEN
            REPEAT

                xChild := xmlDocument.CreateNode('element', 'StoreLinks', '');
                xSetAttributeNode(xChild, WJSonHeader.NameConvert(pStoreTMP.FIELDNAME(pStoreTMP."No.")), pStoreTMP."No.");
                xSetAttributeNode(xChild, WJSonHeader.NameConvert(pStoreTMP.FIELDNAME(pStoreTMP."Fraud Sort Field")), DELCHR(FORMAT(ROUND(pStoreTMP."Fraud Sort Field", 0.01)), '=', ','));
                xNode.AppendChild(xChild);
            UNTIL pStoreTMP.NEXT = 0;

        EXIT(xmlDocument.OuterXml);
    end;


    procedure XmlFromALLTables(var pOrderTMP: Record "LSC POS Trans. Line" temporary; var pPOSTransLinesTMP: Record "LSC POS Trans. Line" temporary; var pStoresTMP: Record "LSC Store" temporary; var pContactTMP: Record "LSC Delivery Contact Address" temporary; pIsTakeaway: Boolean)
    var
        xmlResponse: DotNet XmlDocument;
        xNodeRes: DotNet XmlNode;
        ErrText: Text;
    begin
        IF pIsTakeaway THEN
            ErrText := Text003
        ELSE
            ErrText := Text004;

        xCreateDocDefault(xmlResponse, xNodeRes, 'Response', ErrText, '3001');
    end;


    procedure SQLCall(pDistribLocation: Code[10]; pQuery: Text) Msg: Text
    var
        SQLRead: Codeunit "FSN SQL Data Reader";
        SqlDataReaderNET: DotNet SqlDataReader;
        QueryTxt: Text;
        Index: Integer;
        StringVal: Text;
        lText001: Label 'Conection Error DB';
        lText002: Label 'Cant be suggest items';
        POSTransLineTMP: Record "LSC POS Trans. Line" temporary;
        TextError: Text;
        xmlDocument: DotNet XmlDocument;
        xNode: DotNet XmlNode;
    begin

        CLEAR(TextError);
        SQLRead.ClearParams();
        SQLRead.SetDistributionLocation(pDistribLocation);
        SQLRead.SetQuery(pQuery);
        SQLRead.SetAction('OPEN');
        COMMIT;
        IF SQLRead.RUN THEN;
        IF NOT SQLRead.IsConnect THEN
            ERROR(lText001);

        SQLRead.SetAction('POST');
        COMMIT;
        IF SQLRead.RUN THEN;

        Index := 0;
        SQLRead.GetDataReader(SqlDataReaderNET);
        IF NOT ISNULL(SqlDataReaderNET) THEN
            WHILE SqlDataReaderNET.Read() AND (Index = 0) DO BEGIN
                Msg := SqlDataReaderNET.Item('Data');
                Index += 1;
            END;

        IF Index = 0 THEN
            TextError := lText002;

        SQLRead.SetAction('CLOSE');
        COMMIT;
        IF SQLRead.RUN THEN;
        SQLRead.ClearParams();

        IF TextError <> '' THEN BEGIN
            xCreateDocDefault(xmlDocument, xNode, 'Data', TextError, '9999');
            Msg := xmlDocument.OuterXml;
        END;
    end;

    procedure SendPosTransClient(pRequestID: Text[30]; var pPOSTransaction: Record "LSC POS Transaction"; var pProcessError: Boolean; var pErrorText: Text[1024]): Boolean
    var
        ReqXml: XmlDocument;
        ResXml: XmlDocument;
        BodyNode: XmlNode;
        Node: XmlNode;
        LineNode: XmlNode;
        NodeList: XmlNodeList;
        xmlRequest: Text;
        xmlResponse: Text;
        RequestID: Text[30];
        RequestNodeList: array[3] of Text[50];
        ResponseNodeList: array[5] of Text[50];
        ParentNodeIndex: Integer;
        ParentNodeList: array[5] of Text[50];
        NodeName: Text[50];
        Response_Code: Code[30];
        ReqNodeList: Record "LSC WS Node Buffer" temporary;
        NodeBuffer: Record "LSC WS Node Buffer" temporary;
        Index: Integer;
        RecRef: RecordRef;
        POSTransaction: Record "LSC POS Transaction";
        POSTransLine: Record "LSC POS Trans. Line";
        POSTransPeriodicDisc: Record "LSC POS Trans. Per. Disc. Type";
        POSTransInfocodeEntry: Record "LSC POS Trans. Infocode Entry";
        POSDataEntry: Record "LSC POS Data Entry";
        VoucherEntries: Record "LSC Voucher Entries";
        OfferPosCalculation: Record "LSC Offer Pos Calculation";
        RecRefTemp: RecordRef;
        POSTransactionTemp: Record "LSC POS Transaction" temporary;
        POSTransLineTemp: Record "LSC POS Trans. Line" temporary;
        POSTransPeriodicDiscTemp: Record "LSC POS Trans. Per. Disc. Type" temporary;
        POSTransInfocodeEntryTemp: Record "LSC POS Trans. Infocode Entry" temporary;
        POSDataEntryTemp: Record "LSC POS Data Entry" temporary;
        VoucherEntriesTemp: Record "LSC Voucher Entries" temporary;
        OfferPosCalculationTemp: Record "LSC Offer Pos Calculation" temporary;
        //PosTrLineDisplStatRoutTemp: Record "Pos Tr. Line Displ. Stat. Rout" temporary;
        FlowFieldBuffer: Record "LSC FlowField Buffer" temporary;
        POSCardRequestEntry: Record "FSN POS Card Request Entry";
        POSCardRequestEntryTmp: Record "FSN POS Card Request Entry" temporary;
        CSTable: Record "FSN WebServiceTable";
        CSTableTmp: Record "FSN WebServiceTable" temporary;
        POSCardEntries: Record "LSC POS Card Entry";
        POSCardEntriesTMP: Record "LSC POS Card Entry" temporary;
        DeliveryContAddress: Record "LSC Delivery Contact Address";
        DeliveryContAddressTemp: Record "LSC Delivery Contact Address" temporary;
        OdataCNN: Codeunit "FSN OData Conexion";
        POSMenuLine: Record "LSC POS Menu Line";
        StringXML: Text;
        FilterString: Text;
        FileSystem: DotNet StreamWriter;
        Directory: DotNet DirNet;
        RequestSetup: Record "LSC WS Request Setup";
    begin
        //SendPosTrans
        //GetWebServiceSetup;
        WebServiceSetup.GET;
        RequestID := pRequestID;
        Response_Code := '0000';

        IF NOT InitRequest(ReqXml, RequestID, RequestNodeList, ResponseNodeList, ParentNodeIndex, ParentNodeList, BodyNode, pProcessError, pErrorText) THEN
            EXIT(FALSE);

        IF NOT WSFunc.AddChildNodeListText(RequestID, 0, ParentNodeIndex, ParentNodeList, 'Update_Action', 'Update-Add',
           ReqNodeList, Response_Code, pErrorText)
        THEN BEGIN
            pProcessError := TRUE;
            EXIT(FALSE);
        END;
        WSFunc.AppendChildNodeList(BodyNode, ReqNodeList);

        //POS Transaction
        POSTransaction.SETRANGE("Receipt No.", pPOSTransaction."Receipt No.");
        RecRef.GETTABLE(POSTransaction);
        RecRefTemp.GETTABLE(POSTransactionTemp);
        WSFunc.CopyTableToTempTable(RecRef, RecRefTemp, FlowFieldBuffer);
        IF NOT WSFunc.SetTableChildNodes(RequestID, 0, BodyNode, ParentNodeIndex, ParentNodeList, 'LSC POS Transaction',
          RecRefTemp, FlowFieldBuffer, Response_Code, pErrorText)
        THEN BEGIN
            pProcessError := TRUE;
            EXIT(FALSE);
        END;

        //POS Trans. Line
        POSTransLine.SETRANGE("Receipt No.", pPOSTransaction."Receipt No.");
        RecRef.GETTABLE(POSTransLine);
        RecRefTemp.GETTABLE(POSTransLineTemp);
        WSFunc.CopyTableToTempTable(RecRef, RecRefTemp, FlowFieldBuffer);
        IF NOT WSFunc.SetTableChildNodes(RequestID, 0, BodyNode, ParentNodeIndex, ParentNodeList, 'LSC POS Trans. Line',
          RecRefTemp, FlowFieldBuffer, Response_Code, pErrorText)
        THEN BEGIN
            pProcessError := TRUE;
            EXIT(FALSE);
        END;

        //POS Trans. Periodic Disc.
        POSTransPeriodicDisc.SETRANGE("Receipt No.", pPOSTransaction."Receipt No.");
        RecRef.GETTABLE(POSTransPeriodicDisc);
        RecRefTemp.GETTABLE(POSTransPeriodicDiscTemp);
        WSFunc.CopyTableToTempTable(RecRef, RecRefTemp, FlowFieldBuffer);
        IF NOT WSFunc.SetTableChildNodes(RequestID, 0, BodyNode, ParentNodeIndex, ParentNodeList, 'LSC POS Trans. Per. Disc. Type',
          RecRefTemp, FlowFieldBuffer, Response_Code, pErrorText)
        THEN BEGIN
            pProcessError := TRUE;
            EXIT(FALSE);
        END;

        //POS Trans. Infocode Entry
        POSTransInfocodeEntry.SETRANGE("Receipt No.", pPOSTransaction."Receipt No.");
        RecRef.GETTABLE(POSTransInfocodeEntry);
        RecRefTemp.GETTABLE(POSTransInfocodeEntryTemp);
        WSFunc.CopyTableToTempTable(RecRef, RecRefTemp, FlowFieldBuffer);
        IF NOT WSFunc.SetTableChildNodes(RequestID, 0, BodyNode, ParentNodeIndex, ParentNodeList, 'LSC POS Trans. Infocode Entry',
          RecRefTemp, FlowFieldBuffer, Response_Code, pErrorText)
        THEN BEGIN
            pProcessError := TRUE;
            EXIT(FALSE);
        END;

        //POS Data Entry
        POSDataEntry.RESET;
        POSDataEntry.SETCURRENTKEY("Created by Receipt No.");
        POSDataEntry.SETRANGE("Created by Receipt No.", pPOSTransaction."Receipt No.");
        RecRef.GETTABLE(POSDataEntry);
        RecRefTemp.GETTABLE(POSDataEntryTemp);
        WSFunc.CopyTableToTempTable(RecRef, RecRefTemp, FlowFieldBuffer);

        POSDataEntry.RESET;
        POSDataEntry.SETCURRENTKEY("Applied by Receipt No.");
        POSDataEntry.SETRANGE("Applied by Receipt No.", pPOSTransaction."Receipt No.");
        RecRef.GETTABLE(POSDataEntry);
        RecRefTemp.GETTABLE(POSDataEntryTemp);
        WSFunc.CopyTableToTempTable(RecRef, RecRefTemp, FlowFieldBuffer);

        IF NOT WSFunc.SetTableChildNodes(RequestID, 0, BodyNode, ParentNodeIndex, ParentNodeList, 'LSC POS Data Entry',
          RecRefTemp, FlowFieldBuffer, Response_Code, pErrorText)
        THEN BEGIN
            pProcessError := TRUE;
            EXIT(FALSE);
        END;

        //Voucher Entries
        VoucherEntries.SETCURRENTKEY("Receipt Number", "Store No.", "POS Terminal No.");
        VoucherEntries.SETRANGE("Receipt Number", pPOSTransaction."Receipt No.");
        RecRef.GETTABLE(VoucherEntries);
        RecRefTemp.GETTABLE(VoucherEntriesTemp);
        WSFunc.CopyTableToTempTable(RecRef, RecRefTemp, FlowFieldBuffer);
        IF NOT WSFunc.SetTableChildNodes(RequestID, 0, BodyNode, ParentNodeIndex, ParentNodeList, 'LSC Voucher Entries',
          RecRefTemp, FlowFieldBuffer, Response_Code, pErrorText)
        THEN BEGIN
            pProcessError := TRUE;
            EXIT(FALSE);
        END;

        //Offer Pos Calculation
        OfferPosCalculation.SETRANGE("Receipt No.", pPOSTransaction."Receipt No.");
        RecRef.GETTABLE(OfferPosCalculation);
        RecRefTemp.GETTABLE(OfferPosCalculationTemp);
        WSFunc.CopyTableToTempTable(RecRef, RecRefTemp, FlowFieldBuffer);
        IF NOT WSFunc.SetTableChildNodes(RequestID, 0, BodyNode, ParentNodeIndex, ParentNodeList, 'LSC Offer Pos Calculation',
          RecRefTemp, FlowFieldBuffer, Response_Code, pErrorText)
        THEN BEGIN
            pProcessError := TRUE;
            EXIT(FALSE);
        END;

        POSCardRequestEntry.SETRANGE("Receipt No.", pPOSTransaction."Receipt No.");
        RecRef.GETTABLE(POSCardRequestEntry);
        RecRefTemp.GETTABLE(POSCardRequestEntryTmp);
        WSFunc.CopyTableToTempTable(RecRef, RecRefTemp, FlowFieldBuffer);
        IF NOT WSFunc.SetTableChildNodes(RequestID, 0, BodyNode, ParentNodeIndex, ParentNodeList, 'FSN POS Card Request Entry',
          RecRefTemp, FlowFieldBuffer, Response_Code, pErrorText)
        THEN BEGIN
            pProcessError := TRUE;
            EXIT(FALSE);
        END;

        //CS Web Service Table
        CSTable.SETRANGE(CSTable.LastSlipNo, pPOSTransaction."Receipt No.");
        RecRef.GETTABLE(CSTable);
        RecRefTemp.GETTABLE(CSTableTmp);
        WSFunc.CopyTableToTempTable(RecRef, RecRefTemp, FlowFieldBuffer);
        IF NOT WSFunc.SetTableChildNodes(RequestID, 0, BodyNode, ParentNodeIndex, ParentNodeList, 'FSN WebServiceTable',
          RecRefTemp, FlowFieldBuffer, Response_Code, pErrorText)
        THEN BEGIN
            pProcessError := TRUE;
            EXIT(FALSE);
        END;

        POSCardEntries.SETRANGE(POSCardEntries."Receipt No.", pPOSTransaction."Receipt No.");
        RecRef.GETTABLE(POSCardEntries);
        RecRefTemp.GETTABLE(POSCardEntriesTMP);
        WSFunc.CopyTableToTempTable(RecRef, RecRefTemp, FlowFieldBuffer);
        IF NOT WSFunc.SetTableChildNodes(RequestID, 0, BodyNode, ParentNodeIndex, ParentNodeList, 'LSC POS Card Entry',
          RecRefTemp, FlowFieldBuffer, Response_Code, pErrorText)
        THEN BEGIN
            pProcessError := TRUE;
            EXIT(FALSE);
        END;

        DeliveryContAddress.SetRange("Phone No.", pPOSTransaction."Sell-to Contact No.");
        RecRef.GetTable(DeliveryContAddress);
        RecRefTemp.GetTable(DeliveryContAddressTemp);
        WSFunc.CopyTableToTempTable(RecRef, RecRefTemp, FlowFieldBuffer);
        if not WSFunc.SetTableChildNodes(RequestID, 0, BodyNode, ParentNodeIndex, ParentNodeList, 'LSC Delivery Contact Address',
          RecRefTemp, FlowFieldBuffer, Response_Code, pErrorText)
        then begin
            pProcessError := true;
            exit(false);
        end;

        //xmlRequest := ReqXml.OuterXml;
        xmlRequest := XMLDomMgt.ReturnInnerTextfromXMLDocument(ReqXml);
        StringXML := xmlRequest;

        //comprobar si existe la carpeta, si no existe crearla
        if not Directory.Exists('C:\temp\WSFSN\') then
            Directory.CreateDirectory('C:\temp\WSFSN\');

        //guardar el xml en la carpeta
        if Directory.Exists('C:\temp\WSFSN\') then begin
            if RequestID = 'SEND_POSTRANS_BACKUP' then begin
                FilterString := 'C:\temp\WSFSN\' + pRequestID + '_' + CSTable."Order No." + '.xml';
                FileSystem := FileSystem.StreamWriter(FilterString);
                FileSystem.Write(StringXML);
                FileSystem.Close();
            end else begin
                FilterString := 'C:\temp\WSFSN\' + pRequestID + '.xml';
                FileSystem := FileSystem.StreamWriter(FilterString);
                FileSystem.Write(StringXML);
                FileSystem.Close();
            end;

            pProcessError := FALSE;
            Commit();
            EXIT(TRUE);

        end;
    end;
    //PROCESO ANTERIOR
    /*procedure SendPosTransRequest(pRequest_ID: Text[30]; var pxmlRequest: Text; var pxmlResponse: Text)
    var
        ReqXml: XmlDocument;
        ResXml: XmlDocument;
        BodyNode: XmlNode;
        Node: DotNet XmlNode;
        LineNode: DotNet XmlNode;
        RequestID: Text[30];
        RequestNodeList: array[3] of Text[50];
        ResponseNodeList: array[5] of Text[50];
        ParentNodeIndex: Integer;
        ParentNodeList: array[5] of Text[50];
        NodeName: Text[50];
        TableNodeList: Record "LSC WS Node Buffer" temporary;
        ReqNodeList: Record "LSC WS Node Buffer" temporary;
        Response_Code: Code[30];
        Response_Text: Text[1024];
        UpdateAction: Text[30];
        AddOnly: Boolean;
        RecRefTemp: array[32] of RecordRef;
        RecRef: RecordRef;
        FlowFieldBuffer: Record "LSC FlowField Buffer" temporary;
        UpdateFieldList: Record "Field" temporary;
        CSWebServiceTableTmp: Record "FSN WebServiceTable";
        Storel: Record "LSC Store";
        POSMenuLineTmp: Record "LSC POS Menu Line";
        FSNEcommerceCallCenterMgt: Codeunit "FSN Ecommerce CallCenter Mgt.";
    begin
        //SendPOSTrans
        RequestID := pRequest_ID;
        WSFunc.LoadRequest(pxmlRequest, ReqXml, RequestID, RequestNodeList, ResponseNodeList, ParentNodeIndex, ParentNodeList, BodyNode, Response_Code, Response_Text);

        //Get List of request nodes
        IF Response_Code = '0000' THEN
            WSFunc.AddChildNodeListText(RequestID, 0, ParentNodeIndex, ParentNodeList, 'Update_Action', '',
              ReqNodeList, Response_Code, Response_Text);
        IF Response_Code = '0000' THEN
            WSFunc.GetChildNodeList(0, BodyNode, ReqNodeList, Response_Code, Response_Text);
        IF Response_Code = '0000' THEN BEGIN
            ReqNodeList.RESET;
            IF ReqNodeList.FIND('-') THEN
                REPEAT
                    IF ReqNodeList.Source = 'Update_Action' THEN BEGIN
                        UpdateAction := ReqNodeList."Text Value";
                        IF NOT ((UpdateAction = 'Add') OR (UpdateAction = 'Update-Add')) THEN BEGIN
                            Response_Code := '0030';
                            Response_Text := STRSUBSTNO(Text001, ReqNodeList."Text Value", ReqNodeList."Node Name");
                        END;
                    END;
                UNTIL (ReqNodeList.NEXT = 0) OR (Response_Code <> '0000');
        END;

        //Get Tables
        IF Response_Code = '0000' THEN
            WSFunc.AddChildNodeTableList(RequestID, 0, ParentNodeIndex, ParentNodeList, 'LSC POS Transaction', TableNodeList,
              Response_Code, Response_Text);
        IF Response_Code = '0000' THEN
            WSFunc.AddChildNodeTableList(RequestID, 0, ParentNodeIndex, ParentNodeList, 'LSC POS Trans. Line', TableNodeList,
              Response_Code, Response_Text);
        IF Response_Code = '0000' THEN
            WSFunc.AddChildNodeTableList(RequestID, 0, ParentNodeIndex, ParentNodeList, 'LSC POS Trans. Per. Disc. Type', TableNodeList,
              Response_Code, Response_Text);
        IF Response_Code = '0000' THEN
            WSFunc.AddChildNodeTableList(RequestID, 0, ParentNodeIndex, ParentNodeList, 'LSC POS Trans. Infocode Entry', TableNodeList,
              Response_Code, Response_Text);
        IF Response_Code = '0000' THEN
            WSFunc.AddChildNodeTableList(RequestID, 0, ParentNodeIndex, ParentNodeList, 'LSC POS Data Entry', TableNodeList,
              Response_Code, Response_Text);
        IF Response_Code = '0000' THEN
            WSFunc.AddChildNodeTableList(RequestID, 0, ParentNodeIndex, ParentNodeList, 'LSC Voucher Entries', TableNodeList,
              Response_Code, Response_Text);
        IF Response_Code = '0000' THEN
            WSFunc.AddChildNodeTableList(RequestID, 0, ParentNodeIndex, ParentNodeList, 'LSC Offer Pos Calculation', TableNodeList,
              Response_Code, Response_Text);
        IF Response_Code = '0000' THEN
            WSFunc.AddChildNodeTableList(RequestID, 0, ParentNodeIndex, ParentNodeList, 'FSN POS Card Request Entry', TableNodeList,
              Response_Code, Response_Text);
        IF Response_Code = '0000' THEN
            WSFunc.AddChildNodeTableList(RequestID, 0, ParentNodeIndex, ParentNodeList, 'FSN WebServiceTable', TableNodeList,
              Response_Code, Response_Text);
        IF Response_Code = '0000' THEN
            WSFunc.AddChildNodeTableList(RequestID, 0, ParentNodeIndex, ParentNodeList, 'LSC POS Card Entry', TableNodeList,
              Response_Code, Response_Text);

        IF Response_Code = '0000' THEN BEGIN
            TableNodeList.RESET;
            IF TableNodeList.FIND('-') THEN
                REPEAT
                    RecRefTemp[TableNodeList."Entry No."].OPEN(TableNodeList."Table No.", TRUE);
                    WSFunc.GetTableChildNodes(RequestID, 0, BodyNode, ParentNodeIndex, ParentNodeList, TableNodeList.Source,
                      RecRefTemp[TableNodeList."Entry No."], FlowFieldBuffer, TableNodeList."Entry No.", UpdateFieldList,
                      Response_Code, Response_Text);
                UNTIL (TableNodeList.NEXT = 0) OR (Response_Code <> '0000');
        END;

        IF Response_Code <> '0000' THEN BEGIN
            WSFunc.ErrorResponse(RequestID, ResponseNodeList, Response_Code, Response_Text, gLocalProcess, pxmlResponse);
            EXIT;
        END;

        //Process Request
        IF UpdateAction = 'Add' THEN
            AddOnly := TRUE
        ELSE
            AddOnly := FALSE;

        //Update Table
        IF TableNodeList.FIND('-') THEN
            REPEAT
                UpdateFieldList.SETRANGE(TableNo, TableNodeList."Entry No.");
                RecRef.OPEN(TableNodeList."Table No.");
                WSFunc.UpdateTableByTempTable(AddOnly, RecRefTemp[TableNodeList."Entry No."], RecRef, 0, UpdateFieldList);
                RecRef.CLOSE;
            UNTIL TableNodeList.NEXT = 0;


        IF Response_Code = '0000' THEN BEGIN
            TableNodeList.SETRANGE(TableNodeList."Table No.", DATABASE::"FSN WebServiceTable");
            IF TableNodeList.FIND('-') THEN
                RecRef.GETTABLE(CSWebServiceTableTmp);
            WSFunc.UpdateTableByTempTable(AddOnly, RecRefTemp[TableNodeList."Entry No."], RecRef, 0, UpdateFieldList);
            RecRef.GETTABLE(CSWebServiceTableTmp);
            IF CSWebServiceTableTmp.FIND('-') THEN
                REPEAT
                    IF (CSWebServiceTableTmp."Order Type" <> CSWebServiceTableTmp."Order Type"::None) AND
                      Storel.GET(CSWebServiceTableTmp."Store Selected") THEN BEGIN
                        POSMenuLineTmp.DELETEALL;
                        CLEAR(POSMenuLineTmp);
                        POSMenuLineTmp.INIT();
                        POSMenuLineTmp.Command := 'SEND_ORDERBACKUP';
                        POSMenuLineTmp."Current-RECEIPT" := CSWebServiceTableTmp.LastSlipNo;
                        POSMenuLineTmp.INSERT;
                        COMMIT;
                        IF FSNEcommerceCallCenterMgt.RUN(POSMenuLineTmp) THEN;
                    END;
                UNTIL CSWebServiceTableTmp.NEXT = 0;
            RecRef.CLOSE;
        END;

        //Process Response Doc
        WSFunc.InitParentResNodeList(ResponseNodeList, ParentNodeIndex, ParentNodeList);
        WSFunc.CreateResponse(ResXml, RequestID, ResponseNodeList, BodyNode);

        ResXml.WriteTo(pxmlResponse);

    end;*/

    //NUEVO PROCESO DE PREFACTURA
    procedure SendPosTransRequest(pRequest_ID: Text[30]; var pxmlRequest: Text; var pxmlResponse: Text)
    var
        ReqXml: XmlDocument;
        ResXml: XmlDocument;
        BodyNode: XmlNode;
        Node: DotNet XmlNode;
        LineNode: DotNet XmlNode;
        RequestID: Text[30];
        RequestNodeList: array[3] of Text[50];
        ResponseNodeList: array[5] of Text[50];
        ParentNodeIndex: Integer;
        ParentNodeList: array[5] of Text[50];
        NodeName: Text[50];
        TableNodeList: Record "LSC WS Node Buffer" temporary;
        ReqNodeList: Record "LSC WS Node Buffer" temporary;
        Response_Code: Code[30];
        Response_Text: Text[1024];
        UpdateAction: Text[30];
        AddOnly: Boolean;
        RecRefTemp: array[32] of RecordRef;
        RecRef: RecordRef;
        FlowFieldBuffer: Record "LSC FlowField Buffer" temporary;
        UpdateFieldList: Record "Field" temporary;
        CSWebServiceTableTmp: Record "FSN WebServiceTable" temporary;
        Storel: Record "LSC Store";
        POSMenuLineTmp: Record "LSC POS Menu Line" temporary;
        FSNEcommerceCallCenterMgt: Codeunit "FSN Ecommerce CallCenter Mgt.";
        sb: DotNet StringBuilder;
        xmlFinal: File;
        xmlStream: OutStream;
        xmlRequest: Text;
        FileSystem: DotNet StreamWriter;
        Directory: DotNet DirNet;
        FilterString: Text;
        StringXML: Text;
        JObject: DotNet JObject;
        document: DotNet XmlDocument;
        NewJson: Text;
        Convert: DotNet JsonConvert;
        FileManagement: Codeunit "File Management";
        Receipt: Text;
        POSSESSION: Codeunit "LSC POS Session";
        ValDelivery: Boolean;
        WSTable: Record "FSN WebServiceTable";
        EcCallCenterMgt: Codeunit "FSN Ecommerce CallCenter Mgt.";
        POSTransTmp: Record "LSC POS Transaction" temporary;
        Carpeta: Text;
        DelContactAddress: Record "LSC Delivery Contact Address";
        DelStreet: Record "LSC Delivery Street";
        ErrorText000: Label 'Street Name no encontrado';
        EvalTake: Integer;
        parameter: Record "FSN Parameter";
    begin
        ValDelivery := false;
        Receipt := '';
        POSSESSION.SetValue('FSNRECEIPTVALIDATECC', '');
        POSSESSION.SetValue('FSNRECEIPTPOSCC', '');
        //SendPOSTrans
        RequestID := pRequest_ID;
        WSFunc.LoadRequest(pxmlRequest, ReqXml, RequestID, RequestNodeList, ResponseNodeList, ParentNodeIndex, ParentNodeList, BodyNode, Response_Code, Response_Text);

        xmlRequest := XMLDomMgt.ReturnInnerTextfromXMLDocument(ReqXml);
        StringXML := pxmlRequest;

        IF Response_Code = '0000' THEN
            POSSESSION.SetValue('FSNRECEIPTVALIDATECC', 'TRUE');
        //Get List of request nodes
        IF Response_Code = '0000' THEN
            WSFunc.AddChildNodeListText(RequestID, 0, ParentNodeIndex, ParentNodeList, 'Update_Action', '',
              ReqNodeList, Response_Code, Response_Text);
        IF Response_Code = '0000' THEN
            WSFunc.GetChildNodeList(0, BodyNode, ReqNodeList, Response_Code, Response_Text);
        IF Response_Code = '0000' THEN BEGIN
            ReqNodeList.RESET;
            IF ReqNodeList.FIND('-') THEN
                REPEAT
                    IF ReqNodeList.Source = 'Update_Action' THEN BEGIN
                        UpdateAction := ReqNodeList."Text Value";
                        IF NOT ((UpdateAction = 'Add') OR (UpdateAction = 'Update-Add')) THEN BEGIN
                            Response_Code := '0030';
                            Response_Text := STRSUBSTNO(Text001, ReqNodeList."Text Value", ReqNodeList."Node Name");
                        END;
                    END;
                UNTIL (ReqNodeList.NEXT = 0) OR (Response_Code <> '0000');
        END;

        //Get Tables
        IF Response_Code = '0000' THEN
            WSFunc.AddChildNodeTableList(RequestID, 0, ParentNodeIndex, ParentNodeList, 'LSC POS Transaction', TableNodeList,
              Response_Code, Response_Text);
        IF Response_Code = '0000' THEN
            WSFunc.AddChildNodeTableList(RequestID, 0, ParentNodeIndex, ParentNodeList, 'LSC POS Trans. Line', TableNodeList,
              Response_Code, Response_Text);
        IF Response_Code = '0000' THEN
            WSFunc.AddChildNodeTableList(RequestID, 0, ParentNodeIndex, ParentNodeList, 'LSC POS Trans. Per. Disc. Type', TableNodeList,
              Response_Code, Response_Text);
        IF Response_Code = '0000' THEN
            WSFunc.AddChildNodeTableList(RequestID, 0, ParentNodeIndex, ParentNodeList, 'LSC POS Trans. Infocode Entry', TableNodeList,
              Response_Code, Response_Text);
        IF Response_Code = '0000' THEN
            WSFunc.AddChildNodeTableList(RequestID, 0, ParentNodeIndex, ParentNodeList, 'LSC POS Data Entry', TableNodeList,
              Response_Code, Response_Text);
        IF Response_Code = '0000' THEN
            WSFunc.AddChildNodeTableList(RequestID, 0, ParentNodeIndex, ParentNodeList, 'LSC Voucher Entries', TableNodeList,
              Response_Code, Response_Text);
        IF Response_Code = '0000' THEN
            WSFunc.AddChildNodeTableList(RequestID, 0, ParentNodeIndex, ParentNodeList, 'LSC Offer Pos Calculation', TableNodeList,
              Response_Code, Response_Text);
        IF Response_Code = '0000' THEN
            WSFunc.AddChildNodeTableList(RequestID, 0, ParentNodeIndex, ParentNodeList, 'FSN POS Card Request Entry', TableNodeList,
              Response_Code, Response_Text);
        IF Response_Code = '0000' THEN
            WSFunc.AddChildNodeTableList(RequestID, 0, ParentNodeIndex, ParentNodeList, 'FSN WebServiceTable', TableNodeList,
              Response_Code, Response_Text);
        IF Response_Code = '0000' THEN
            WSFunc.AddChildNodeTableList(RequestID, 0, ParentNodeIndex, ParentNodeList, 'LSC POS Card Entry', TableNodeList,
              Response_Code, Response_Text);
        IF Response_Code = '0000' THEN
            WSFunc.AddChildNodeTableList(RequestID, 0, ParentNodeIndex, ParentNodeList, 'LSC Delivery Contact Address', TableNodeList,
              Response_Code, Response_Text);
        IF Response_Code = '0000' THEN
            WSFunc.AddChildNodeTableList(RequestID, 0, ParentNodeIndex, ParentNodeList, 'Contact', TableNodeList,
              Response_Code, Response_Text);

        IF Response_Code = '0000' THEN BEGIN
            TableNodeList.RESET;
            IF TableNodeList.FIND('-') THEN
                REPEAT
                    RecRefTemp[TableNodeList."Entry No."].OPEN(TableNodeList."Table No.", TRUE);
                    WSFunc.GetTableChildNodes(RequestID, 0, BodyNode, ParentNodeIndex, ParentNodeList, TableNodeList.Source,
                      RecRefTemp[TableNodeList."Entry No."], FlowFieldBuffer, TableNodeList."Entry No.", UpdateFieldList,
                      Response_Code, Response_Text);
                UNTIL (TableNodeList.NEXT = 0) OR (Response_Code <> '0000');
        END;

        IF Response_Code <> '0000' THEN BEGIN
            WSFunc.ErrorResponse(RequestID, ResponseNodeList, Response_Code, Response_Text, gLocalProcess, pxmlResponse);
            EXIT;
        END;

        //Process Request
        IF UpdateAction = 'Add' THEN
            AddOnly := TRUE
        ELSE
            AddOnly := FALSE;

        clear(POSTransTmp);
        POSTransTmp.DeleteAll();
        clear(CSWebServiceTableTmp);
        CSWebServiceTableTmp.DeleteAll();

        //Update Table
        IF TableNodeList.FIND('-') THEN
            REPEAT
                UpdateFieldList.SETRANGE(TableNo, TableNodeList."Entry No.");
                RecRef.OPEN(TableNodeList."Table No.");
                WSFunc.UpdateTableByTempTable(AddOnly, RecRefTemp[TableNodeList."Entry No."], RecRef, 0, UpdateFieldList);
                RecRef.CLOSE;
            UNTIL TableNodeList.NEXT = 0;

        if Response_Code = '0000' then begin//28981
            TableNodeList.SETRANGE(TableNodeList."Table No.", DATABASE::"LSC POS Transaction");
            IF TableNodeList.FIND('-') THEN
                RecRef.GETTABLE(POSTransTmp);
            WSFunc.UpdateTableByTempTable(AddOnly, RecRefTemp[TableNodeList."Entry No."], RecRef, 0, UpdateFieldList);
            RecRef.GETTABLE(POSTransTmp);
            IF POSTransTmp.Find('-') THEN
                REPEAT
                    Receipt := POSTransTmp."Receipt No.";
                UNTIL POSTransTmp.next() = 0;
            RecRef.CLOSE;
        end;

        IF Response_Code = '0000' THEN BEGIN
            TableNodeList.SETRANGE(TableNodeList."Table No.", DATABASE::"FSN WebServiceTable");
            IF TableNodeList.FIND('-') THEN
                RecRef.GETTABLE(CSWebServiceTableTmp);
            WSFunc.UpdateTableByTempTable(AddOnly, RecRefTemp[TableNodeList."Entry No."], RecRef, 0, UpdateFieldList);
            RecRef.GETTABLE(CSWebServiceTableTmp);
            IF CSWebServiceTableTmp.Find('-') THEN begin
                REPEAT
                    parameter.Reset();
                    if parameter.get('PREFABC', 'SENDPOSTRANSBACKUPBC') then begin
                        if not parameter.Activo then begin
                            IF (CSWebServiceTableTmp."Order Type" IN [CSWebServiceTableTmp."Order Type"::FromStoreDelivery]) THEN BEGIN
                                POSMenuLineTmp.DELETEALL;
                                CLEAR(POSMenuLineTmp);
                                POSMenuLineTmp.INIT();
                                POSMenuLineTmp.Command := 'SENDDELIVERYBACKUP'; //'SEND_ORDERBACKUP';
                                POSMenuLineTmp."Current-RECEIPT" := CSWebServiceTableTmp.LastSlipNo;
                                POSMenuLineTmp.INSERT;
                                COMMIT;
                                IF FSNEcommerceCallCenterMgt.RUN(POSMenuLineTmp) THEN;
                            END;
                        end;
                    end;
                UNTIL CSWebServiceTableTmp.NEXT = 0;
            end;
            RecRef.CLOSE;
        END;

        //Process Response Doc
        WSFunc.InitParentResNodeList(ResponseNodeList, ParentNodeIndex, ParentNodeList);
        WSFunc.CreateResponse(ResXml, RequestID, ResponseNodeList, BodyNode);

        FilterString := 'C:\temp\FSNTEST\' + Receipt + '.xml';
        if not Directory.Exists('C:\temp\FSNTEST\') then
            Directory.CreateDirectory('C:\temp\FSNTEST\');
        FileSystem := FileSystem.StreamWriter(FilterString);
        FileSystem.Write(StringXML);
        FileSystem.Close();

        ResXml.WriteTo(pxmlResponse);

        Commit();

        if Response_Code = '0000' then begin
            parameter.Reset();
            if parameter.get('PREFABC', 'SENDPOSTRANSBACKUPBC') then begin
                if parameter.Activo then begin
                    WSTable.Reset();
                    IF WSTable.Get(Receipt) THEN begin
                        if WSTable."Order Type" = WSTable."Order Type"::FromStoreDelivery then begin
                            if Evaluate(EvalTake, WSTable."Value Text 1") then;
                            if DelContactAddress.get(WSTable."Sell-to Contact No.", EvalTake) then begin
                                DelStreet.Reset();
                                DelStreet.SetRange("FSN Street Name", DelContactAddress."Street Name");
                                if DelStreet.FindFirst() then begin
                                    WSTable."Value Text 1" := Format(DelStreet."FSN Latitude") + ',' + Format(DelStreet."FSN Longitude");
                                    WSTable.Modify();
                                    UpdateTRansactionEcommerce(WSTable.LastSlipNo);
                                end else begin
                                    WSTable."Status WS" := WSTable."Status WS"::Pending;
                                    WSTable."Last Error Text" := ErrorText000;
                                    WSTable.Modify();
                                    UpdateOrder(WSTable);
                                    exit;
                                end;
                            end;
                        end else
                            UpdateTRansactionEcommerce(WSTable.LastSlipNo);
                    end;
                end else
                    UpdateTRansactionNewProcess(Receipt);
            end else
                UpdateTRansactionNewProcess(Receipt);
        end;
        //UpdateTRansaction(Receipt);

    end;

    procedure UpdateTRansactionNewProcess(ReceiptTrans: Code[20])
    var
        WebServiceTable: Record "FSN WebServiceTable";
        POSTransLine, ValInventoryPosTransLine, POSLine : Record "LSC POS Trans. Line";
        POSTPeriodicType: Record "LSC POS Trans. Per. Disc. Type";
        POSTransInfocodeEntry: Record "LSC POS Trans. Infocode Entry";
        POSDataEntry: Record "LSC POS Data Entry";
        VoucherEntry: Record "LSC Voucher Entries";
        POSCardRequestEntry, POSCardReq_1 : Record "FSN POS Card Request Entry";
        POSCardEntry_l, PosCardEntry2 : Record "LSC POS Card Entry";
        POSCardEntryTmp: Record "LSC POS Card Entry" temporary;
        PosCardReqIn: Record "FSN POS Card Request Inherit";
        TerminalAsig: Record "LSC CC POS Term. Assignm.";
        POSTransaction: Record "LSC POS Transaction";
        FsnTakeOrder: Page "FSN Take Order CC";
        DelOrder: Record "LSC Delivery Order";
        onlineorder: boolean;
        ErrorText: text;
        DelCont: Record Contact;
        DelInventoryMHt: Codeunit "FSN Delivery Inventory Mgt.";
        ErrorText01: Label 'Sala no sugerida por inventario, Store Select mas cercano';
        ErrorText02: Label 'No enviado por producto paqueteria';
        ErrorText03: Label 'No enviado a tienda destino';
        ErrorText04: Label 'Enviado con Exito';
        ErrorText05: Label 'Item attribute 2 block for send';
        FSNUtility: Codeunit "FSN Utility";
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        MsgResult: Text;
        POSMenuLineTemp: Record "LSC POS Menu Line" temporary;
        Processed: Boolean;
        EcommerceMgt: Codeunit "FSN Ecommerce CallCenter Mgt.";
        error: Boolean;
        Item_l: Record Item;
        Parameter: Record "FSN Parameter";
        FilterCustomer: Record Customer;
        POSSESSION: Codeunit "LSC POS Session";
        SalesTypeRec: Record "LSC Sales Type";
        DelFuntion: Codeunit "FSN Delivery Functions Extend";
        OferPosCalculetion: Record "LSC Offer Pos Calculation";
        LSCFuntion: Codeunit "LSC POS Functions";
        POSTranslineTem: Record "LSC POS Trans. Line" temporary;
        POSTransDiscount: Codeunit "LSC POS Trans. Discounts";
        VatSetup: Record "VAT Posting Setup";
        HospSetup: record "LSC Hospitality Setup";
        FSNCallCOrder: Codeunit "FSN Call Center SenOrder";
        FSNDeliveryFuntion: Codeunit "FSN Delivery Functions Extend";
        PosTransV: Record "LSC Pos Transaction";
        DelOrderV: Record "LSC Delivery Order";
        PosTransVf: Record "LSC POS Transaction";
        DelContacAddress: Record "LSC Delivery Contact Address";

    begin
        POSSESSION.SetValue('FSNRECEIPTVALIDATECC', '');
        POSSESSION.SetValue('FSNRECEIPTPOSCC', '');
        //UpdateReceiptOrder
        if WebServiceTable.get(ReceiptTrans) then begin
            IF Parameter.GET('PREFACC', WebServiceTable."Store Selected") THEN
                IF Parameter.Activo THEN begin

                    if WebServiceTable."Store Selected" <> '' then begin
                        if WebServiceTable."Order Type" in [WebServiceTable."Order Type"::Takeaway, WebServiceTable."Order Type"::FromStoreDelivery,
                        WebServiceTable."Order Type"::FromStoreTakeaway, WebServiceTable."Order Type"::Delivery] then
                            if not (EcommerceMgt.ValidateServerInventoryTR(WebServiceTable.LastSlipNo, WebServiceTable."Store Selected", error, errorText)) then begin

                                WebServiceTable."Status WS" := WebServiceTable."Status WS"::Pending;
                                WebServiceTable."Last Error Text" := ErrorText01;
                                WebServiceTable.Modify();
                                UpdateOrder(WebServiceTable);

                                /*if PosTransVf.Get(WebServiceTable.LastSlipNo) then begin
                                    if DelOrderV.get(PosTransVf."Receipt No.") then
                                        POSInsertReplenSalesHist(DelOrderV, PosTransVf, WebServiceTable);
                                end;*/

                                exit;
                            end;

                        TerminalAsig.Reset();
                        IF TerminalAsig.Get('F20', WebServiceTable."Store Selected") THEN BEGIN
                            //POS Transaction.
                            POSTransaction.Reset();
                            if POSTransaction.Get(ReceiptTrans) then begin
                                POSTransaction."Store No." := TerminalAsig."Restaurant No.";
                                POSTransaction."POS Terminal No." := TerminalAsig."Rest. POS Terminal";
                                POSTransaction."Created on POS Terminal" := TerminalAsig."Rest. POS Terminal";
                                POSTransaction."Entry Status" := POSTransaction."Entry Status"::" ";
                                POSTransaction."Sell-to Contact No." := WebServiceTable."Sell-to Contact No.";
                                if POSTransaction.Comment = '' then
                                    POSTransaction.Comment := CopyStr(WebServiceTable."First Name" + ' ' + WebServiceTable."Last Name", 1, 100);
                                POSTransaction.Modify(true);
                            end;

                            if NOT (WebServiceTable."Order Type" in [WebServiceTable."Order Type"::Takeaway, WebServiceTable."Order Type"::FromStoreTakeaway]) then
                                FiltLatLog(WebServiceTable, DelContacAddress);

                            CreateDelOrderDeliveryNewProcess(WebServiceTable, POSTransaction, DelContacAddress);

                            DelOrder.Reset();
                            if DelOrder.Get(ReceiptTrans) then begin
                                IF POSTransaction.Get(ReceiptTrans) THEN BEGIN
                                    if (DelOrder."Pre-Order" = DelOrder."Pre-Order"::"On Hold") and (DelOrder."Order Date" <> Today) then begin
                                        HospSetup.Get();

                                        if POSTransaction."Sales Type" <> HospSetup."Pre-Order Sales Type" then begin
                                            POSTransaction."Original Sales Type" := DelOrder."Sales Type";
                                            POSTransaction."Sales Type" := HospSetup."Pre-Order Sales Type";
                                            if SalesTypeRec.Get(HospSetup."Pre-Order Sales Type") then begin
                                                if SalesTypeRec."VAT Bus. Posting Group" <> '' then
                                                    POSTransaction.Validate("VAT Bus.Posting Group", SalesTypeRec."VAT Bus. Posting Group");
                                                if SalesTypeRec."Price Group" <> '' then
                                                    POSTransaction.Validate("Price Group Code", SalesTypeRec."Price Group");
                                            end;
                                        end;
                                    end else begin
                                        if SalesTypeRec.Get(DelOrder."Sales Type") then begin
                                            POSTransaction."Sales Type" := DelOrder."Sales Type";
                                            if SalesTypeRec."VAT Bus. Posting Group" <> '' then
                                                POSTransaction.Validate("VAT Bus.Posting Group", SalesTypeRec."VAT Bus. Posting Group");
                                            if SalesTypeRec."Price Group" <> '' then
                                                POSTransaction.Validate("Price Group Code", SalesTypeRec."Price Group");
                                        end;
                                    END;
                                end;
                                IF WebServiceTable."Distribution Location" <> '' THEN begin
                                    POSTransaction."Staff ID" := 'BOT';
                                    POSTransaction."Sales Staff" := 'BOT';

                                end else begin
                                    POSTransaction."Staff ID" := 'F20CC';
                                    POSTransaction."Sales Staff" := 'F20CC';
                                end;
                                if POSTransaction.Comment IN ['', ' '] then
                                    POSTransaction.Comment := DelOrder.Name;
                                POSTransaction.Modify(true);
                            end;

                            //POS Trans. Line.
                            POSTransLine.Reset();
                            POSTransLine.SetRange("Receipt No.", ReceiptTrans);
                            if POSTransLine.Find('-') then begin
                                repeat
                                    POSTransLine."Store No." := TerminalAsig."Restaurant No.";
                                    POSTransLine."POS Terminal No." := TerminalAsig."Rest. POS Terminal";

                                    if WebServiceTable."Distribution Location" <> '' then begin
                                        POSTransLine."Sales Staff" := 'BOT';
                                        POSTransLine."Created by Staff ID" := 'BOT'
                                    end else begin
                                        POSTransLine."Sales Staff" := 'F20CC';
                                        POSTransLine."Created by Staff ID" := 'F20CC';
                                    end;

                                    if POSTransLine."Entry Type" = POSTransLine."Entry Type"::Item then begin
                                        POSTransaction.Reset();
                                        if POSTransaction.Get(POSTransLine."Receipt No.") then begin
                                            if POSTransaction."Price Group Code" <> POSTransLine."Price Group Code" then
                                                POSTransLine."Price Group Code" := POSTransaction."Price Group Code";
                                            if VatSetup.Get(POSTransLine."VAT Bus. Posting Group", POSTransLine."VAT Prod. Posting Group") then
                                                POSTransLine."VAT Calculation Type" := VatSetup."VAT Calculation Type";
                                        end;
                                    end;
                                    POSTransLine.Modify();
                                until POSTransLine.Next() = 0;
                            end;

                            //LSC POS Trans. Per. Disc. Type
                            POSTPeriodicType.Reset();
                            POSTPeriodicType.SetRange("Receipt No.", ReceiptTrans);
                            if POSTPeriodicType.Find('-') then begin
                                repeat
                                    POSTPeriodicType."POS Terminal No." := TerminalAsig."Rest. POS Terminal";
                                    POSTPeriodicType.Modify(true);
                                until POSTPeriodicType.Next() = 0;
                            end;


                            //LSC POS Trans. Infocode Entry
                            POSTransInfocodeEntry.Reset();
                            POSTransInfocodeEntry.SetRange(POSTransInfocodeEntry."Receipt No.", ReceiptTrans);
                            if POSTransInfocodeEntry.Find('-') then begin
                                repeat
                                    POSTransInfocodeEntry."Store No." := TerminalAsig."Restaurant No.";
                                    POSTransInfocodeEntry."POS Terminal No." := TerminalAsig."Rest. POS Terminal";
                                    POSTransInfocodeEntry.Modify();
                                until POSTransInfocodeEntry.Next() = 0;
                            end;

                            //LSC POS Data Entry
                            POSDataEntry.Reset();
                            POSDataEntry.SetRange("Created by Receipt No.", ReceiptTrans);
                            if POSDataEntry.Find('-') then begin
                                repeat
                                    POSDataEntry."Created in Store No." := TerminalAsig."Restaurant No.";
                                    POSDataEntry.Modify();
                                until POSDataEntry.Next() = 0;
                            end;

                            //LSC Voucher Entries
                            VoucherEntry.Reset();
                            VoucherEntry.SetRange("Receipt Number", ReceiptTrans);
                            if VoucherEntry.Find('-') then begin
                                repeat
                                    VoucherEntry."Store No." := TerminalAsig."Restaurant No.";
                                    VoucherEntry."POS Terminal No." := TerminalAsig."Rest. POS Terminal";
                                    VoucherEntry.Modify();
                                until VoucherEntry.Next() = 0;
                            end;

                            //FSN POS Card Request Entry
                            POSCardRequestEntry.Reset();
                            POSCardRequestEntry.SetRange("Receipt No.", ReceiptTrans);
                            if POSCardRequestEntry.Find('-') then begin
                                repeat
                                    POSCardRequestEntry."Store No." := TerminalAsig."Restaurant No.";
                                    POSCardRequestEntry.Modify();
                                until POSCardRequestEntry.Next() = 0;
                            end;


                            POSCardEntry_l.RESET;
                            POSCardEntry_l.SETRANGE(POSCardEntry_l."Receipt No.", ReceiptTrans);
                            IF POSCardEntry_l.FIND('-') THEN
                                REPEAT
                                    POSCardEntryTmp := POSCardEntry_l;
                                    POSCardEntryTmp."Store No." := TerminalAsig."Restaurant No.";
                                    POSCardEntryTmp."POS Terminal No." := TerminalAsig."Rest. POS Terminal";
                                    POSCardEntryTmp."Entry No." := DelFuntion.NextEntryNo(TerminalAsig."Restaurant No.", TerminalAsig."Rest. POS Terminal");
                                    IF NOT (POSCardEntryTmp.INSERT) THEN begin
                                        POSCardEntryTmp.MODIFY;
                                    end else begin
                                        PosCardEntry2 := POSCardEntryTmp;
                                        PosCardEntry2.Insert();
                                        POSCardEntry_l.Delete();
                                        POSCardEntryTmp.Delete();
                                    end;
                                UNTIL POSCardEntry_l.NEXT = 0;

                            POSCardReq_1.Reset();
                            POSCardReq_1.SetRange(POSCardReq_1."Receipt No.", ReceiptTrans);
                            if POSCardReq_1.Find('-') then begin
                                repeat
                                    POSCardReq_1."Store No." := TerminalAsig."Restaurant No.";
                                    POSCardReq_1.Modify();
                                until POSCardReq_1.Next() = 0;
                            end;

                            PosCardReqIn.Reset();
                            PosCardReqIn.SetRange(PosCardReqIn."Receipt No. Inherit", ReceiptTrans);
                            if PosCardReqIn.Find('-') then begin
                                repeat
                                    PosCardReqIn."Store No. Inherit" := TerminalAsig."Restaurant No.";
                                    PosCardReqIn.Modify();
                                until PosCardReqIn.Next() = 0;
                            end;


                            POSCardEntry_l.Reset();//crea linea para media de pago tarjeta
                            POSCardEntry_l.SetRange("Receipt No.", ReceiptTrans);
                            if POSCardEntry_l.FindFirst() then begin
                                RequestID := 'DEL-TRANSCARDFSN';
                                MsgResult := Format(DelOrder."General Status");
                                XMLRequest := ReceiptTrans;
                                FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
                            end;

                            //Commit();

                            DelOrder.Reset();
                            if DelOrder.get(ReceiptTrans) then begin
                                DelCont.Reset();
                                if not DelCont.get(DelOrder."Phone No.") then begin
                                    DelCont.Init();
                                    DelCont."No." := DelOrder."Phone No.";
                                end;
                                DelCont."Phone No." := DelOrder."Phone No.";
                                DelCont."LSC Next Order Selection" := DelOrder."Order Type Option";
                                DelCont."LSC Next Order Restaurant" := DelOrder."Restaurant No.";
                                DelCont."LSC Next Order Date" := DelOrder."Order Date";
                                DelCont."LSC Next Order Time" := DelOrder."Contact Pickup Time";
                                DelCont."LSC Next Delivery Tender" := DelOrder."Tender Type";
                                DelCont."LSC Pre-Order Print DateTime" := DelOrder."Pre-Order Print DateTime";
                                DelCont."LSC Next Estimated Prod. Time" := DelOrder."Estimated Prod. Time (Min.)";
                                if not DelCont.insert then
                                    DelCont.Modify;

                                POSLine.RESET;
                                POSLine.SETRANGE(POSLine."Receipt No.", WebServiceTable.LastSlipNo);
                                POSLine.SETRANGE(POSLine."Entry Type", POSLine."Entry Type"::Item);
                                POSLine.SETRANGE(POSLine."Entry Status", 0);
                                IF POSLine.FIND('-') THEN
                                    REPEAT
                                        IF Item_l.GET(POSLine.Number) THEN
                                            IF Item_l."LSC Attrib 2 Code" IN ['PAQUETERIA-C807'] THEN BEGIN
                                                if Parameter.Get('PAQUETERIA', Item_l."No.") then
                                                    if Parameter.Activo then begin
                                                        WebServiceTable."Last Error Text" := ErrorText02;
                                                        WebServiceTable.MODIFY;
                                                        EXIT;
                                                    end;
                                            END;
                                    UNTIL POSLine.NEXT = 0;

                                SalesChanel(DelOrder, WebServiceTable);


                                POSLine.RESET;
                                POSLine.SETRANGE(POSLine."Receipt No.", WebServiceTable.LastSlipNo);
                                POSLine.SETRANGE(POSLine."Entry Type", POSLine."Entry Type"::Item);
                                POSLine.SETRANGE(POSLine."Entry Status", 0);
                                IF POSLine.FIND('-') THEN
                                    REPEAT
                                        IF Item_l.GET(POSLine.Number) THEN
                                            IF Item_l."LSC Attrib 2 Code" IN ['CONTROLADOS', 'MONOFARMACO-CONTROLADO', 'POLIFARMACO-CONTROLADO'] THEN BEGIN
                                                WebServiceTable."Last Error Text" := ErrorText05;
                                                WebServiceTable.MODIFY;
                                                EXIT;
                                            END;
                                    UNTIL POSLine.NEXT = 0;

                                FSNCallCOrder.ValidateTimeOnRestChange(DelCont, errorText, false, DelOrder);
                                if errorText <> '' then begin
                                    if not (WebServiceTable."Order Type" in [WebServiceTable."Order Type"::Takeaway, WebServiceTable."Order Type"::FromStoreTakeaway]) then
                                        WebServiceTable."Store Selected" := SalesSugEcommerce(WebServiceTable);
                                    WebServiceTable."Status WS" := WebServiceTable."Status WS"::Pending;
                                    WebServiceTable."Last Error Text" := CopyStr(errorText, 1, 100);
                                    WebServiceTable.Modify();

                                    UpdateOrder(WebServiceTable);
                                    exit;
                                end;

                                if FsnTakeOrder.SendDeliveryOrder(DelOrder, onlineorder, ErrorText) then begin
                                    if ErrorText = '' then begin
                                        DelOrder.Reset();
                                        DelOrder.Get(ReceiptTrans);
                                        if DelOrder."Call Cent. Web Service Status" in
                                            [DelOrder."Call Cent. Web Service Status"::"New-Not Sent", DelOrder."Call Cent. Web Service Status"::"New-Not Confirmed"] then
                                            DelOrder."Call Cent. Web Service Status" := DelOrder."Call Cent. Web Service Status"::"New-Sent";

                                        if DelOrder."Call Cent. Web Service Status" = DelOrder."Call Cent. Web Service Status"::"Changed-Not Sent" then
                                            DelOrder."Call Cent. Web Service Status" := DelOrder."Call Cent. Web Service Status"::"Changed-Sent";


                                        DelOrder."General Status" := DelOrder."General Status"::"In Process";
                                        if (DelOrder."Assigned to Driver") or (DelOrder."Process Status" = DelOrder."Process Status"::Finished) then
                                            DelOrder."General Status" := DelOrder."General Status"::Confirmed;
                                        DelOrder.Modify();

                                        POSSESSION.SetValue('DEL-PickupDate', Format(DelOrder."Order Date"));
                                        POSSESSION.SetValue('DEL-PickupTime', format(DelOrder."Contact Pickup Time"));


                                        RequestID := 'DEL-TRANSFSN';//manda a DAF
                                        MsgResult := Format(DelOrder."General Status");
                                        XMLRequest := DelOrder."Order No.";
                                        FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);


                                        WebServiceTable."Status WS" := WebServiceTable."Status WS"::InProcess;
                                        WebServiceTable."Last Error Text" := 'SENT';
                                        WebServiceTable."Key Number Text 1" := 1;
                                        WebServiceTable.Modify();
                                    end else begin
                                        DelOrder.Reset();
                                        DelOrder.Get(ReceiptTrans);
                                        if DelOrder."Call Cent. Web Service Status" = DelOrder."Call Cent. Web Service Status"::"New-Not Confirmed" then
                                            DelOrder."Call Cent. Web Service Status" := DelOrder."Call Cent. Web Service Status"::"New-Not Sent";
                                        DelOrder."General Status" := DelOrder."General Status"::ERROR;
                                        DelOrder.Modify();

                                        WebServiceTable."Status WS" := WebServiceTable."Status WS"::Pending;
                                        WebServiceTable."Last Error Text" := ErrorText03;
                                        WebServiceTable.Modify();
                                    end;
                                end else begin
                                    DelOrder.Reset();
                                    DelOrder.Get(ReceiptTrans);
                                    if DelOrder."Call Cent. Web Service Status" = DelOrder."Call Cent. Web Service Status"::"New-Not Confirmed" then
                                        DelOrder."Call Cent. Web Service Status" := DelOrder."Call Cent. Web Service Status"::"New-Not Sent";
                                    DelOrder."General Status" := DelOrder."General Status"::ERROR;
                                    DelOrder.Modify();

                                    WebServiceTable."Status WS" := WebServiceTable."Status WS"::Pending;
                                    WebServiceTable."Last Error Text" := ErrorText03;
                                    WebServiceTable.Modify();
                                end;
                                //message(ErrorText);
                            end;
                        end;
                    end else begin
                        if not (WebServiceTable."Order Type" in [WebServiceTable."Order Type"::Takeaway, WebServiceTable."Order Type"::FromStoreTakeaway]) then
                            WebServiceTable."Store Selected" := SalesSugEcommerce(WebServiceTable);

                        WebServiceTable."Status WS" := WebServiceTable."Status WS"::Pending;
                        WebServiceTable."Last Error Text" := ErrorText01;
                        WebServiceTable.Modify();

                        UpdateOrder(WebServiceTable);

                        /*if PosTransVf.Get(WebServiceTable.LastSlipNo) then begin
                            if DelOrderV.get(PosTransVf."Receipt No.") then
                                POSInsertReplenSalesHist(DelOrderV, PosTransVf, WebServiceTable);
                        end;*/

                    end;
                end;
        end;
    end;

    procedure FiltLatLog(var WebServiceTable: Record "FSN WebServiceTable"; var DelContacAddress: Record "LSC Delivery Contact Address")
    var
        delS: Record "LSC Delivery Street";
        AddressTypeInt: integer;
        storelink: Record "FSN Store Link";
        DeliveryFuntionExt: Codeunit "FSN Delivery Functions Extend";
        distance: Decimal;
        Parameter: Record "FSN Parameter";
        Valuedistance: Decimal;
    begin

        if WebServiceTable."Value Text 1" <> '' then
            if Evaluate(AddressTypeInt, WebServiceTable."Value Text 1") then begin
                DelContacAddress.reset;
                DelContacAddress.SetRange("Phone No.", WebServiceTable."Sell-to Contact No.");
                DelContacAddress.SetRange("Address Type", AddressTypeInt);
                if DelContacAddress.FindFirst() then begin
                    delS.reset;
                    delS.SetRange(delS."Street Name", DelContacAddress."Street Name");
                    if delS.FindFirst() then begin
                        IF Parameter.GET('PREFACC', WebServiceTable."Store Selected") THEN;
                        WebServiceTable."Value Text 1" := Format(delS."FSN Latitude") + ',' + Format(delS."FSN Longitude");

                        if evaluate(Valuedistance, Parameter.Valor) then;

                        distance := DeliveryFuntionExt.GetDistanceGeopraphic(storelink."Parent Latitude", storelink."Parent Longitude", delS."FSN Latitude", delS."FSN Longitude");
                        if not (distance <= Valuedistance) then
                            WebServiceTable."Last Error Text" := 'La dirección del cliente se encuentra a ' + Format(distance) + ' km de la tienda seleccionada.';

                        WebServiceTable.Modify();
                    end;
                end;
            end;
    end;

    //crea delivery order
    procedure CreateDelOrderDeliveryNewProcess(WSTable: Record "FSN WebServiceTable"; POSTransactionV: Record "LSC POS Transaction"; DelCustAddr: Record "LSC Delivery Contact Address")
    var
        DelOrder: Record "LSC Delivery Order";
        //DelCustAddr: Record "LSC Delivery Contact Address";
        POSInfocodeEntry: Record "LSC POS Trans. Infocode Entry";
        BOUTIL: Codeunit "LSC BO Utils";
        Delstret: Record "LSC Delivery Street";
        TypeText: text;
        TypeInt: integer;
        SalesTypes: Record "LSC Sales Type";
        Direction: text[250];
        FSNAlterKey: Integer;
        DelContac: Record Contact;
    begin

        clear(TypeText);
        POSInfocodeEntry.Reset();
        POSInfocodeEntry.SETRANGE("Receipt No.", WSTable.LastSlipNo);
        POSInfocodeEntry.SETRANGE(Infocode, 'DDIRECTION');
        IF POSInfocodeEntry.find('-') THEN
            repeat
                Direction := Direction + POSInfocodeEntry.Information;
            until POSInfocodeEntry.Next() = 0;

        if WSTable."Order Type" in [WSTable."Order Type"::Takeaway, WSTable."Order Type"::FromStoreTakeaway] then begin
            Delstret.Reset();
            if Delstret.get('GENERICO OTROS', 1, '614') then begin
                DelCustAddr.Reset();
                DelCustAddr.SetRange("Address Type", DelCustAddr."Address Type"::Other);
                DelCustAddr.SetRange("Phone No.", wsTable."Sell-to Contact No.");
                if not DelCustAddr.FindFirst() then begin
                    DelCustAddr.Init();
                    DelCustAddr."Phone No." := wsTable."Sell-to Contact No.";
                    DelCustAddr."Address Type" := DelCustAddr."Address Type"::Other
                end;


                DelCustAddr."Street Name" := Delstret."Street Name";
                DelCustAddr."FSN Street Name" := Delstret."Street Name";
                DelCustAddr."Post Code" := Delstret."Post Code";
                DelCustAddr."Restaurant No." := Delstret."Restaurant No.";
                DelCustAddr.Directions := CopyStr(Direction, 1, 100);
                DelCustAddr."FSN Direction" := Direction;
                FSNAlterKey := Delstret."FSN Alter Key";

                DelContac.Reset();
                if not DelContac.Get(wsTable."Sell-to Contact No.") then begin
                    DelContac.Init();
                    DelContac."No." := wsTable."Sell-to Contact No.";
                    DelContac.Name := wsTable."First Name" + ' ' + wsTable."Last Name";
                    DelContac."Search Name" := wsTable."First Name";
                end;

                DelContac."Phone No." := wsTable."Sell-to Contact No.";
                if not DelContac.Insert(true) then
                    DelContac.Modify(true);

                if not DelCustAddr.Insert(true) then
                    DelCustAddr.Modify(True);
            end;
        end;

        Delstret.reset;
        if DelContac.Get(wsTable."Sell-to Contact No.") then;
        if not DelOrder.Get(WSTable.LastSlipNo) then begin
            DelOrder.Init;
            DelOrder."Order No." := WSTable.LastSlipNo;

        end;
        DelOrder."Restaurant No." := WSTable."Store Selected";
        DelOrder.Validate("General Status", DelOrder."General Status"::"In Process");
        DelOrder."Call Cent. Web Service Status" := DelOrder."Call Cent. Web Service Status"::"New-Not Confirmed";
        DelOrder."Phone No." := WSTable."Sell-to Contact No.";
        DelOrder."Order Date" := TODAY;
        if WSTable."Order Type" in [WSTable."Order Type"::Takeaway, WSTable."Order Type"::FromStoreTakeaway] then
            DelOrder.Validate("Order Type Option", 4)
        else
            DelOrder.Validate("Order Type Option", 3);
        DelOrder.Address := DelCustAddr."Street Name";
        DelOrder."Address 2" := DelCustAddr."Address 2";
        DelOrder.City := DelCustAddr.City;
        DelOrder."Created at Call Center" := 'F20';
        DelOrder."Post Code" := DelCustAddr."Post Code";
        DelOrder.Directions := DelCustAddr.Directions;
        DelOrder."Grid Code" := DelCustAddr."Grid Code";
        DelOrder."Contact Pickup Time" := WSTable.Time;
        DelOrder."Date Created" := Today;
        DelOrder."Time Created" := WSTable.Time;
        if WSTable."Distribution Location" <> '' then
            DelOrder."Order Taker" := 'BOT'
        else
            DelOrder."Order Taker" := 'F20CC';
        IF WSTable."First Name" = '' THEN BEGIN
            DelOrder.Name := CopyStr(DelContac.Name, 1, 100);
            DelOrder."Bill-to Name" := CopyStr(DelContac.Name, 1, 100);
        END ELSE BEGIN
            DelOrder.Name := CopyStr(WSTable."First Name" + ' ' + WSTable."Last Name", 1, 100);
            DelOrder."Bill-to Name" := CopyStr(WSTable."First Name" + ' ' + WSTable."Last Name", 1, 100);
        END;
        /*if SalesTypes.Get(POSTransactionV."Sales Type") then
            DelOrder."Sales Type" := SalesTypes.Code;*/
        DelOrder."FSN Alter Key" := FSNAlterKey;
        DelOrder."FSN Directions" := DelCustAddr."FSN Direction";
        DelOrder."FSN Street Name" := DelCustAddr."Street Name";
        if not DelOrder.Insert(true) then
            DelOrder.Modify(true);

        Commit();
    end;

    procedure UpdateTRansaction(ReceiptTrans: Code[20])
    var
        WebServiceTable: Record "FSN WebServiceTable";
        POSTransLine: Record "LSC POS Trans. Line";
        POSTPeriodicType: Record "LSC POS Trans. Per. Disc. Type";
        POSTransInfocodeEntry: Record "LSC POS Trans. Infocode Entry";
        POSDataEntry: Record "LSC POS Data Entry";
        VoucherEntry: Record "LSC Voucher Entries";
        OffPosCalculation: Record "LSC Offer Pos Calculation";
        POSCardRequestEntry: Record "FSN POS Card Request Entry";
        POSCardEntry: Record "LSC POS Card Entry";
        TerminalAsig: Record "LSC CC POS Term. Assignm.";
        POSTransaction: Record "LSC POS Transaction";
        FsnTakeOrder: Page "FSN Take Order CC";
        DelOrder: Record "LSC Delivery Order";
        SalesType: Integer;
        onlineorder: boolean;
        ErrorText: text;
        DelCont: Record Contact;
    begin

        //UpdateReceiptOrder
        if WebServiceTable.get(ReceiptTrans) then begin
            if WebServiceTable."Store Selected" <> '' then begin
                IF (WebServiceTable."Order Type" <> WebServiceTable."Order Type"::Delivery) THEN BEGIN
                    TerminalAsig.Reset();
                    IF TerminalAsig.Get(WebServiceTable.Store, WebServiceTable."Store Selected") THEN BEGIN

                        //POS Transaction.
                        if POSTransaction.Get(ReceiptTrans) then begin
                            POSTransaction."Store No." := TerminalAsig."Restaurant No.";
                            POSTransaction."POS Terminal No." := TerminalAsig."Rest. POS Terminal";
                            POSTransaction.Modify(true);
                        end;

                        CreateDelOrderDelivery(WebServiceTable, POSTransaction);

                        //POS Trans. Line.
                        POSTransLine.Reset();
                        POSTransLine.SetRange("Receipt No.", ReceiptTrans);
                        if POSTransLine.Find('-') then begin
                            repeat
                                POSTransLine."Store No." := TerminalAsig."Restaurant No.";
                                POSTransLine."POS Terminal No." := TerminalAsig."Rest. POS Terminal";
                                POSTransLine.Modify();
                            until POSTransLine.Next() = 0;
                        end;

                        //LSC POS Trans. Per. Disc. Type
                        POSTPeriodicType.Reset();
                        POSTPeriodicType.SetRange("Receipt No.", ReceiptTrans);
                        if POSTPeriodicType.Find('-') then begin
                            repeat
                                POSTPeriodicType."POS Terminal No." := TerminalAsig."Rest. POS Terminal";
                                POSTPeriodicType.Modify();
                            until POSTPeriodicType.Next() = 0;
                        end;

                        //LSC POS Trans. Infocode Entry
                        POSTransInfocodeEntry.Reset();
                        POSTransInfocodeEntry.SetRange(POSTransInfocodeEntry."Receipt No.", ReceiptTrans);
                        if POSTransInfocodeEntry.Find('-') then begin
                            repeat
                                POSTransInfocodeEntry."Store No." := TerminalAsig."Restaurant No.";
                                POSTransInfocodeEntry."POS Terminal No." := TerminalAsig."Rest. POS Terminal";
                                POSTransInfocodeEntry.Modify();
                            until POSTransInfocodeEntry.Next() = 0;
                        end;

                        //LSC POS Data Entry
                        POSDataEntry.Reset();
                        POSDataEntry.SetRange("Created by Receipt No.", ReceiptTrans);
                        if POSDataEntry.Find('-') then begin
                            repeat
                                POSDataEntry."Created in Store No." := TerminalAsig."Restaurant No.";
                                POSDataEntry.Modify();
                            until POSDataEntry.Next() = 0;
                        end;

                        //LSC Voucher Entries
                        VoucherEntry.Reset();
                        VoucherEntry.SetRange("Receipt Number", ReceiptTrans);
                        if VoucherEntry.Find('-') then begin
                            repeat
                                VoucherEntry."Store No." := TerminalAsig."Restaurant No.";
                                VoucherEntry."POS Terminal No." := TerminalAsig."Rest. POS Terminal";
                                VoucherEntry.Modify();
                            until VoucherEntry.Next() = 0;
                        end;

                        //FSN POS Card Request Entry
                        POSCardRequestEntry.Reset();
                        POSCardRequestEntry.SetRange("Receipt No.", ReceiptTrans);
                        if POSCardRequestEntry.Find('-') then begin
                            repeat
                                POSCardRequestEntry."Store No." := TerminalAsig."Restaurant No.";
                                POSCardRequestEntry.Modify();
                            until POSCardRequestEntry.Next() = 0;
                        end;

                        //LSC POS Card Entry
                        /*POSCardEntry.Reset();
                        POSCardEntry.SetRange("Receipt No.", ReceiptTrans);
                        if POSCardEntry.Find('-') then begin
                            repeat
                                POSCardEntry."Store No." := TerminalAsig."Restaurant No.";
                                POSCardEntry."POS Terminal No." := TerminalAsig."Rest. POS Terminal";
                                POSCardEntry.Modify();
                            until POSCardEntry.Next() = 0;
                        end;*/
                        Commit();

                        if DelOrder.get(ReceiptTrans) then begin
                            DelCont.Reset();
                            if not DelCont.get(DelOrder."Phone No.") then begin
                                DelCont.Init();
                                DelCont."No." := DelOrder."Phone No.";
                            end;
                            DelCont."LSC Next Order Selection" := DelOrder."Order Type Option";
                            DelCont."LSC Next Order Restaurant" := DelOrder."Restaurant No.";
                            DelCont."LSC Next Order Date" := DelOrder."Order Date";
                            DelCont."LSC Next Order Time" := DelOrder."Contact Pickup Time";
                            DelCont."LSC Next Delivery Tender" := DelOrder."Tender Type";
                            DelCont."LSC Pre-Order Print DateTime" := DelOrder."Pre-Order Print DateTime";
                            DelCont."LSC Next Estimated Prod. Time" := DelOrder."Estimated Prod. Time (Min.)";
                            if not DelCont.insert then
                                DelCont.Modify;

                            FsnTakeOrder.SendDeliveryOrder(DelOrder, onlineorder, ErrorText);
                            if ErrorText <> '' then;
                            //message(ErrorText);
                        end;
                    end;
                end;
            end;
        end;
    end;

    //Proceso de Ecommerce desde NAV
    procedure SendPosTransRequestEcommerce(pRequest_ID: Text[30]; var pxmlRequest: Text; var pxmlResponse: Text)
    var
        ReqXml: XmlDocument;
        ResXml: XmlDocument;
        BodyNode: XmlNode;
        Node: DotNet XmlNode;
        LineNode: DotNet XmlNode;
        RequestID: Text[30];
        RequestNodeList: array[3] of Text[50];
        ResponseNodeList: array[5] of Text[50];
        ParentNodeIndex: Integer;
        ParentNodeList: array[5] of Text[50];
        NodeName: Text[50];
        TableNodeList: Record "LSC WS Node Buffer" temporary;
        ReqNodeList: Record "LSC WS Node Buffer" temporary;
        Response_Code: Code[30];
        Response_Text: Text[1024];
        UpdateAction: Text[30];
        AddOnly: Boolean;
        RecRefTemp: array[32] of RecordRef;
        RecRef: RecordRef;
        FlowFieldBuffer: Record "LSC FlowField Buffer" temporary;
        UpdateFieldList: Record "Field" temporary;
        CSWebServiceTableTmp: Record "FSN WebServiceTable" temporary;
        Storel: Record "LSC Store";
        POSMenuLineTmp: Record "LSC POS Menu Line" temporary;
        FSNEcommerceCallCenterMgt: Codeunit "FSN Ecommerce CallCenter Mgt.";
        sb: DotNet StringBuilder;
        xmlFinal: File;
        xmlStream: OutStream;
        xmlRequest: Text;
        FileSystem: DotNet StreamWriter;
        Directory: DotNet DirNet;
        FilterString: Text;
        StringXML: Text;
        JObject: DotNet JObject;
        document: DotNet XmlDocument;
        NewJson: Text;
        Convert: DotNet JsonConvert;
        FileManagement: Codeunit "File Management";
        Receipt: Text;
        POSSESSION: Codeunit "LSC POS Session";
        ValDelivery: Boolean;
        WSTable: Record "FSN WebServiceTable";
        EcCallCenterMgt: Codeunit "FSN Ecommerce CallCenter Mgt.";
        POSTransTmp: Record "LSC POS Transaction" temporary;
        Carpeta: Text;
        CSWebTable: Record "FSN WebServiceTable";
    begin
        ValDelivery := false;
        Receipt := '';
        POSSESSION.SetValue('FSNRECEIPTVALIDATECC', '');
        POSSESSION.SetValue('FSNRECEIPTPOSCC', '');
        //SendPOSTrans
        RequestID := pRequest_ID;
        WSFunc.LoadRequest(pxmlRequest, ReqXml, RequestID, RequestNodeList, ResponseNodeList, ParentNodeIndex, ParentNodeList, BodyNode, Response_Code, Response_Text);

        xmlRequest := XMLDomMgt.ReturnInnerTextfromXMLDocument(ReqXml);
        StringXML := pxmlRequest;

        JObject := JObject.JObject();
        document := document.XmlDocument();
        document.LoadXml(StringXML);
        NewJson := Convert.SerializeXmlNode(document);
        JObject := JObject.Parse(NewJson);
        JObject := JObject.SelectToken('Request');
        JObject := JObject.SelectToken('Request_Body');
        JObject := JObject.SelectToken('ReceiptNo');
        Receipt := Format(JObject);

        IF Response_Code = '0000' THEN
            POSSESSION.SetValue('FSNRECEIPTVALIDATECC', 'TRUE');
        //Get List of request nodes
        IF Response_Code = '0000' THEN
            WSFunc.AddChildNodeListText(RequestID, 0, ParentNodeIndex, ParentNodeList, 'Update_Action', '',
              ReqNodeList, Response_Code, Response_Text);
        IF Response_Code = '0000' THEN
            WSFunc.GetChildNodeList(0, BodyNode, ReqNodeList, Response_Code, Response_Text);
        IF Response_Code = '0000' THEN BEGIN
            ReqNodeList.RESET;
            IF ReqNodeList.FIND('-') THEN
                REPEAT
                    IF ReqNodeList.Source = 'Update_Action' THEN BEGIN
                        UpdateAction := ReqNodeList."Text Value";
                        IF NOT ((UpdateAction = 'Add') OR (UpdateAction = 'Update-Add')) THEN BEGIN
                            Response_Code := '0030';
                            Response_Text := STRSUBSTNO(Text001, ReqNodeList."Text Value", ReqNodeList."Node Name");
                        END;
                    END;
                UNTIL (ReqNodeList.NEXT = 0) OR (Response_Code <> '0000');
        END;

        IF CSWebTable.GET(Receipt) AND (Receipt <> '') THEN BEGIN  //NEHE
            WSFunc.InitParentResNodeList(ResponseNodeList, ParentNodeIndex, ParentNodeList);
            WSFunc.CreateResponse(ResXml, RequestID, ResponseNodeList, BodyNode);

            ResXml.WriteTo(pxmlResponse);
            //pxmlResponse := ResXml.OuterXml;
        END;                                                             //NEHE

        //Get Tables
        IF Response_Code = '0000' THEN
            WSFunc.AddChildNodeTableList(RequestID, 0, ParentNodeIndex, ParentNodeList, 'LSC POS Transaction', TableNodeList,
              Response_Code, Response_Text);
        IF Response_Code = '0000' THEN
            WSFunc.AddChildNodeTableList(RequestID, 0, ParentNodeIndex, ParentNodeList, 'LSC POS Trans. Line', TableNodeList,
              Response_Code, Response_Text);
        IF Response_Code = '0000' THEN
            WSFunc.AddChildNodeTableList(RequestID, 0, ParentNodeIndex, ParentNodeList, 'LSC POS Trans. Per. Disc. Type', TableNodeList,
              Response_Code, Response_Text);
        IF Response_Code = '0000' THEN
            WSFunc.AddChildNodeTableList(RequestID, 0, ParentNodeIndex, ParentNodeList, 'LSC POS Trans. Infocode Entry', TableNodeList,
              Response_Code, Response_Text);
        IF Response_Code = '0000' THEN
            WSFunc.AddChildNodeTableList(RequestID, 0, ParentNodeIndex, ParentNodeList, 'LSC POS Data Entry', TableNodeList,
              Response_Code, Response_Text);
        IF Response_Code = '0000' THEN
            WSFunc.AddChildNodeTableList(RequestID, 0, ParentNodeIndex, ParentNodeList, 'LSC Voucher Entries', TableNodeList,
              Response_Code, Response_Text);
        IF Response_Code = '0000' THEN
            WSFunc.AddChildNodeTableList(RequestID, 0, ParentNodeIndex, ParentNodeList, 'LSC Offer Pos Calculation', TableNodeList,
              Response_Code, Response_Text);
        IF Response_Code = '0000' THEN
            WSFunc.AddChildNodeTableList(RequestID, 0, ParentNodeIndex, ParentNodeList, 'FSN POS Card Request Entry', TableNodeList,
              Response_Code, Response_Text);
        IF Response_Code = '0000' THEN
            WSFunc.AddChildNodeTableList(RequestID, 0, ParentNodeIndex, ParentNodeList, 'FSN WebServiceTable', TableNodeList,
              Response_Code, Response_Text);
        IF Response_Code = '0000' THEN
            WSFunc.AddChildNodeTableList(RequestID, 0, ParentNodeIndex, ParentNodeList, 'LSC POS Card Entry', TableNodeList,
              Response_Code, Response_Text);
        IF Response_Code = '0000' THEN
            WSFunc.AddChildNodeTableList(RequestID, 0, ParentNodeIndex, ParentNodeList, 'LSC Delivery Contact Address', TableNodeList,
              Response_Code, Response_Text);
        IF Response_Code = '0000' THEN
            WSFunc.AddChildNodeTableList(RequestID, 0, ParentNodeIndex, ParentNodeList, 'Contact', TableNodeList,
              Response_Code, Response_Text);

        IF Response_Code = '0000' THEN BEGIN
            TableNodeList.RESET;
            IF TableNodeList.FIND('-') THEN
                REPEAT
                    RecRefTemp[TableNodeList."Entry No."].OPEN(TableNodeList."Table No.", TRUE);
                    WSFunc.GetTableChildNodes(RequestID, 0, BodyNode, ParentNodeIndex, ParentNodeList, TableNodeList.Source,
                      RecRefTemp[TableNodeList."Entry No."], FlowFieldBuffer, TableNodeList."Entry No.", UpdateFieldList,
                      Response_Code, Response_Text);
                UNTIL (TableNodeList.NEXT = 0) OR (Response_Code <> '0000');
        END;

        IF Response_Code <> '0000' THEN BEGIN
            WSFunc.ErrorResponse(RequestID, ResponseNodeList, Response_Code, Response_Text, gLocalProcess, pxmlResponse);
            EXIT;
        END;

        //Process Request
        IF UpdateAction = 'Add' THEN
            AddOnly := TRUE
        ELSE
            AddOnly := FALSE;

        clear(POSTransTmp);
        POSTransTmp.DeleteAll();
        clear(CSWebServiceTableTmp);
        CSWebServiceTableTmp.DeleteAll();

        //Update Table
        IF TableNodeList.FIND('-') THEN
            REPEAT
                UpdateFieldList.SETRANGE(TableNo, TableNodeList."Entry No.");
                RecRef.OPEN(TableNodeList."Table No.");
                WSFunc.UpdateTableByTempTable(AddOnly, RecRefTemp[TableNodeList."Entry No."], RecRef, 0, UpdateFieldList);
                RecRef.CLOSE;
            UNTIL TableNodeList.NEXT = 0;

        if Response_Code = '0000' then begin//28981
            TableNodeList.SETRANGE(TableNodeList."Table No.", DATABASE::"LSC POS Transaction");
            IF TableNodeList.FIND('-') THEN
                RecRef.GETTABLE(POSTransTmp);
            WSFunc.UpdateTableByTempTable(AddOnly, RecRefTemp[TableNodeList."Entry No."], RecRef, 0, UpdateFieldList);
            RecRef.GETTABLE(POSTransTmp);
            IF POSTransTmp.Find('-') THEN
                REPEAT
                    Receipt := POSTransTmp."Receipt No.";
                UNTIL POSTransTmp.next() = 0;
            RecRef.CLOSE;
        end;

        IF Response_Code = '0000' THEN BEGIN
            TableNodeList.SETRANGE(TableNodeList."Table No.", DATABASE::"FSN WebServiceTable");
            IF TableNodeList.FIND('-') THEN
                RecRef.GETTABLE(CSWebServiceTableTmp);
            WSFunc.UpdateTableByTempTable(AddOnly, RecRefTemp[TableNodeList."Entry No."], RecRef, 0, UpdateFieldList);
            RecRef.GETTABLE(CSWebServiceTableTmp);
            IF CSWebServiceTableTmp.Find('-') THEN begin
                REPEAT
                    //UpdateTRansactionEcommerce(Receipt);
                    IF CSWebServiceTableTmp."Order Type" in [CSWebServiceTableTmp."Order Type"::Delivery] THEN BEGIN
                        POSMenuLineTmp.DELETEALL;
                        CLEAR(POSMenuLineTmp);
                        POSMenuLineTmp.INIT();
                        if CSWebServiceTableTmp."Order Type" = CSWebServiceTableTmp."Order Type"::Takeaway then
                            POSMenuLineTmp.Command := 'SEND_ORDERBACKUP' //'Takeway';
                        else
                            POSMenuLineTmp.Command := 'SENDDELIVERYBACKUP'; //'Delivery';
                        POSMenuLineTmp."Current-RECEIPT" := CSWebServiceTableTmp.LastSlipNo;
                        POSMenuLineTmp.INSERT;
                        COMMIT;
                        IF FSNEcommerceCallCenterMgt.RUN(POSMenuLineTmp) THEN;
                    END;
                UNTIL CSWebServiceTableTmp.NEXT = 0;
            end;
            RecRef.CLOSE;
        END;

        //Process Response Doc
        WSFunc.InitParentResNodeList(ResponseNodeList, ParentNodeIndex, ParentNodeList);
        WSFunc.CreateResponse(ResXml, RequestID, ResponseNodeList, BodyNode);

        FilterString := 'C:\temp\FSNTEST\' + pRequest_ID + '_' + CSWebServiceTableTmp."Order No." + '.xml';
        if not Directory.Exists('C:\temp\FSNTEST\') then
            Directory.CreateDirectory('C:\temp\FSNTEST\');
        FileSystem := FileSystem.StreamWriter(FilterString);
        FileSystem.Write(StringXML);
        FileSystem.Close();

        ResXml.WriteTo(pxmlResponse);

        Commit();
        if Response_Code = '0000' then begin
            UpdateTRansactionEcommerce(Receipt);
        end;
    end;

    //consulta de inventario local
    procedure GetInventoryUM(POSTransLineTemp: Record "LSC POS Trans. Line" temporary; StoreVal: Code[10]): Decimal
    var
        InventoryLookUpTable: Record "LSC Inventory Lookup Table";
        Divisor: Decimal;
        UM: Record "Item Unit of Measure";
        InventoryValue: Decimal;
        StoreCode: Text[20];
    begin
        IF POSTransLineTemp."Entry Type" = POSTransLineTemp."Entry Type"::Item THEN BEGIN
            Divisor := 1;
            IF UM.GET(POSTransLineTemp.Number, POSTransLineTemp."Unit of Measure") THEN
                IF UM."Qty. per Unit of Measure" <> 0 THEN
                    Divisor := UM."Qty. per Unit of Measure";

            InventoryValue := 0;
            IF InventoryLookUpTable.GET(POSTransLineTemp.Number, POSTransLineTemp."Variant Code", StoreVal, POSTransLineTemp."Lot No.", POSTransLineTemp."Serial No.") THEN
                InventoryValue := InventoryLookUpTable."Net Inventory" / Divisor;
            IF (InventoryValue > 1000000) OR (InventoryValue < -1000000) THEN BEGIN
                IF (InventoryValue > 1000000) THEN
                    EXIT(+1000000.00)
                ELSE
                    EXIT(-1000000.00);
            END ELSE
                EXIT(ROUND(InventoryValue, 0.1, '='));

        END;
        EXIT(0.0);
    end;

    procedure UpdateTRansactionEcommerce(ReceiptTrans: Code[20])
    var
        WebServiceTable: Record "FSN WebServiceTable";
        POSTransLine, ValInventoryPosTransLine, POSLine : Record "LSC POS Trans. Line";
        POSTPeriodicType: Record "LSC POS Trans. Per. Disc. Type";
        POSTransInfocodeEntry: Record "LSC POS Trans. Infocode Entry";
        POSDataEntry: Record "LSC POS Data Entry";
        VoucherEntry: Record "LSC Voucher Entries";
        POSCardRequestEntry, POSCardReq_1 : Record "FSN POS Card Request Entry";
        POSCardEntry_l, PosCardEntry2 : Record "LSC POS Card Entry";
        POSCardEntryTmp: Record "LSC POS Card Entry" temporary;
        PosCardReqIn: Record "FSN POS Card Request Inherit";
        TerminalAsig: Record "LSC CC POS Term. Assignm.";
        POSTransaction: Record "LSC POS Transaction";
        FsnTakeOrder: Page "FSN Take Order CC";
        DelOrder: Record "LSC Delivery Order";
        onlineorder: boolean;
        ErrorText: text;
        DelCont: Record Contact;
        DelInventoryMHt: Codeunit "FSN Delivery Inventory Mgt.";
        ErrorText01: Label 'Sala no sugerida por inventario, Store Select mas cercano';
        ErrorText02: Label 'No enviado por producto paqueteria';
        ErrorText03: Label 'No enviado a tienda destino';
        ErrorText04: Label 'Enviado con Exito';
        ErrorText05: Label 'Item attribute 2 block for send';
        FSNUtility: Codeunit "FSN Utility";
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        MsgResult: Text;
        POSMenuLineTemp: Record "LSC POS Menu Line" temporary;
        Processed: Boolean;
        EcommerceMgt: Codeunit "FSN Ecommerce CallCenter Mgt.";
        error: Boolean;
        Item_l: Record Item;
        Parameter: Record "FSN Parameter";
        FilterCustomer: Record Customer;
        POSSESSION: Codeunit "LSC POS Session";
        SalesTypeRec: Record "LSC Sales Type";
        DelFuntion: Codeunit "FSN Delivery Functions Extend";
        OferPosCalculetion: Record "LSC Offer Pos Calculation";
        LSCFuntion: Codeunit "LSC POS Functions";
        POSTranslineTem: Record "LSC POS Trans. Line" temporary;
        POSTransDiscount: Codeunit "LSC POS Trans. Discounts";
        VatSetup: Record "VAT Posting Setup";
        HospSetup: record "LSC Hospitality Setup";
        FSNCallCOrder: Codeunit "FSN Call Center SenOrder";

    begin
        POSSESSION.SetValue('FSNRECEIPTVALIDATECC', '');
        POSSESSION.SetValue('FSNRECEIPTPOSCC', '');
        //UpdateReceiptOrder
        if WebServiceTable.get(ReceiptTrans) then begin
            if WebServiceTable."Store Selected" <> '' then begin
                if WebServiceTable."Order Type" in [WebServiceTable."Order Type"::Takeaway, WebServiceTable."Order Type"::FromStoreDelivery,
                WebServiceTable."Order Type"::FromStoreTakeaway, WebServiceTable."Order Type"::Delivery] then
                    if not (EcommerceMgt.ValidateServerInventoryTR(WebServiceTable.LastSlipNo, WebServiceTable."Store Selected", error, errorText)) then begin
                        WebServiceTable."Status WS" := WebServiceTable."Status WS"::Pending;
                        WebServiceTable."Last Error Text" := ErrorText01;
                        WebServiceTable.Modify();
                        UpdateOrder(WebServiceTable);
                        exit;
                    end;

                TerminalAsig.Reset();
                IF TerminalAsig.Get('F20', WebServiceTable."Store Selected") THEN BEGIN
                    //POS Transaction.
                    POSTransaction.Reset();
                    if POSTransaction.Get(ReceiptTrans) then begin
                        POSTransaction."Store No." := TerminalAsig."Restaurant No.";
                        POSTransaction."POS Terminal No." := TerminalAsig."Rest. POS Terminal";
                        POSTransaction."Created on POS Terminal" := TerminalAsig."Rest. POS Terminal";
                        POSTransaction."Entry Status" := POSTransaction."Entry Status"::" ";
                        if POSTransaction.Comment = '' then
                            POSTransaction.Comment := CopyStr(WebServiceTable."First Name" + ' ' + WebServiceTable."Last Name", 1, 100);
                        POSTransaction.Modify(true);
                    end;

                    if (CopyStr(WebServiceTable.LastSlipNo, 1, 10) = '00000APP01') OR
                        (CopyStr(WebServiceTable.LastSlipNo, 1, 10) = '00000APP02') OR
                            (CopyStr(WebServiceTable.LastSlipNo, 1, 10) = '000PV#1000') then begin
                        CreateDelOrderDeliveryEcommerce2(WebServiceTable, POSTransaction)
                    end else
                        CreateDelOrderDeliveryEcommerce(WebServiceTable, POSTransaction);

                    DelOrder.Reset();
                    if DelOrder.Get(ReceiptTrans) then begin
                        IF POSTransaction.Get(ReceiptTrans) THEN BEGIN
                            if (DelOrder."Pre-Order" = DelOrder."Pre-Order"::"On Hold") and (DelOrder."Order Date" <> Today) then begin
                                HospSetup.Get();
                                if POSTransaction."Sales Type" <> HospSetup."Pre-Order Sales Type" then begin
                                    POSTransaction."Original Sales Type" := DelOrder."Sales Type";
                                    POSTransaction."Sales Type" := HospSetup."Pre-Order Sales Type";
                                    if SalesTypeRec.Get(HospSetup."Pre-Order Sales Type") then begin
                                        if SalesTypeRec."VAT Bus. Posting Group" <> '' then
                                            POSTransaction.Validate("VAT Bus.Posting Group", SalesTypeRec."VAT Bus. Posting Group");
                                        if SalesTypeRec."Price Group" <> '' then
                                            POSTransaction.Validate("Price Group Code", SalesTypeRec."Price Group");
                                    end;
                                end;
                            end else begin
                                if SalesTypeRec.Get(DelOrder."Sales Type") then begin
                                    POSTransaction."Sales Type" := DelOrder."Sales Type";
                                    if SalesTypeRec."VAT Bus. Posting Group" <> '' then
                                        POSTransaction.Validate("VAT Bus.Posting Group", SalesTypeRec."VAT Bus. Posting Group");
                                    if SalesTypeRec."Price Group" <> '' then
                                        POSTransaction.Validate("Price Group Code", SalesTypeRec."Price Group");
                                end;
                            END;
                        end;
                        IF WebServiceTable."Distribution Location" <> '' THEN begin
                            POSTransaction."Staff ID" := 'BOT';
                            POSTransaction."Sales Staff" := 'BOT';

                        end else begin
                            POSTransaction."Staff ID" := 'F20CC';
                            POSTransaction."Sales Staff" := 'F20CC';
                        end;
                        POSTransaction.Modify(true);
                    end;

                    //POS Trans. Line.
                    POSTransLine.Reset();
                    POSTransLine.SetRange("Receipt No.", ReceiptTrans);
                    if POSTransLine.Find('-') then begin
                        repeat
                            POSTransLine."Store No." := TerminalAsig."Restaurant No.";
                            POSTransLine."POS Terminal No." := TerminalAsig."Rest. POS Terminal";

                            if WebServiceTable."Distribution Location" <> '' then begin
                                POSTransLine."Sales Staff" := 'BOT';
                                POSTransLine."Created by Staff ID" := 'BOT'
                            end else begin
                                POSTransLine."Sales Staff" := 'F20CC';
                                POSTransLine."Created by Staff ID" := 'F20CC';
                            end;

                            if POSTransLine."Entry Type" = POSTransLine."Entry Type"::Item then begin
                                POSTransaction.Reset();
                                if POSTransaction.Get(POSTransLine."Receipt No.") then begin
                                    if POSTransaction."Price Group Code" <> POSTransLine."Price Group Code" then
                                        POSTransLine."Price Group Code" := POSTransaction."Price Group Code";
                                    if VatSetup.Get(POSTransLine."VAT Bus. Posting Group", POSTransLine."VAT Prod. Posting Group") then
                                        POSTransLine."VAT Calculation Type" := VatSetup."VAT Calculation Type";
                                end;
                            end;
                            POSTransLine.Modify();
                        until POSTransLine.Next() = 0;
                    end;

                    //LSC POS Trans. Per. Disc. Type
                    POSTPeriodicType.Reset();
                    POSTPeriodicType.SetRange("Receipt No.", ReceiptTrans);
                    if POSTPeriodicType.Find('-') then begin
                        repeat
                            POSTPeriodicType."POS Terminal No." := TerminalAsig."Rest. POS Terminal";
                            POSTPeriodicType.Modify(true);
                        until POSTPeriodicType.Next() = 0;
                    end;


                    //LSC POS Trans. Infocode Entry
                    POSTransInfocodeEntry.Reset();
                    POSTransInfocodeEntry.SetRange(POSTransInfocodeEntry."Receipt No.", ReceiptTrans);
                    if POSTransInfocodeEntry.Find('-') then begin
                        repeat
                            POSTransInfocodeEntry."Store No." := TerminalAsig."Restaurant No.";
                            POSTransInfocodeEntry."POS Terminal No." := TerminalAsig."Rest. POS Terminal";
                            POSTransInfocodeEntry.Modify();
                        until POSTransInfocodeEntry.Next() = 0;
                    end;

                    //LSC POS Data Entry
                    POSDataEntry.Reset();
                    POSDataEntry.SetRange("Created by Receipt No.", ReceiptTrans);
                    if POSDataEntry.Find('-') then begin
                        repeat
                            POSDataEntry."Created in Store No." := TerminalAsig."Restaurant No.";
                            POSDataEntry.Modify();
                        until POSDataEntry.Next() = 0;
                    end;

                    //LSC Voucher Entries
                    VoucherEntry.Reset();
                    VoucherEntry.SetRange("Receipt Number", ReceiptTrans);
                    if VoucherEntry.Find('-') then begin
                        repeat
                            VoucherEntry."Store No." := TerminalAsig."Restaurant No.";
                            VoucherEntry."POS Terminal No." := TerminalAsig."Rest. POS Terminal";
                            VoucherEntry.Modify();
                        until VoucherEntry.Next() = 0;
                    end;

                    //FSN POS Card Request Entry
                    POSCardRequestEntry.Reset();
                    POSCardRequestEntry.SetRange("Receipt No.", ReceiptTrans);
                    if POSCardRequestEntry.Find('-') then begin
                        repeat
                            POSCardRequestEntry."Store No." := TerminalAsig."Restaurant No.";
                            POSCardRequestEntry.Modify();
                        until POSCardRequestEntry.Next() = 0;
                    end;


                    POSCardEntry_l.RESET;
                    POSCardEntry_l.SETRANGE(POSCardEntry_l."Receipt No.", ReceiptTrans);
                    IF POSCardEntry_l.FIND('-') THEN
                        REPEAT
                            POSCardEntryTmp := POSCardEntry_l;
                            POSCardEntryTmp."Store No." := TerminalAsig."Restaurant No.";
                            POSCardEntryTmp."POS Terminal No." := TerminalAsig."Rest. POS Terminal";
                            POSCardEntryTmp."Entry No." := DelFuntion.NextEntryNo(TerminalAsig."Restaurant No.", TerminalAsig."Rest. POS Terminal");
                            IF NOT (POSCardEntryTmp.INSERT) THEN begin
                                POSCardEntryTmp.MODIFY;
                            end else begin
                                PosCardEntry2 := POSCardEntryTmp;
                                PosCardEntry2.Insert();
                                POSCardEntry_l.Delete();
                                POSCardEntryTmp.Delete();
                            end;
                        UNTIL POSCardEntry_l.NEXT = 0;

                    POSCardReq_1.Reset();
                    POSCardReq_1.SetRange(POSCardReq_1."Receipt No.", ReceiptTrans);
                    if POSCardReq_1.Find('-') then begin
                        repeat
                            POSCardReq_1."Store No." := TerminalAsig."Restaurant No.";
                            POSCardReq_1.Modify();
                        until POSCardReq_1.Next() = 0;
                    end;

                    PosCardReqIn.Reset();
                    PosCardReqIn.SetRange(PosCardReqIn."Receipt No. Inherit", ReceiptTrans);
                    if PosCardReqIn.Find('-') then begin
                        repeat
                            PosCardReqIn."Store No. Inherit" := TerminalAsig."Restaurant No.";
                            PosCardReqIn.Modify();
                        until PosCardReqIn.Next() = 0;
                    end;


                    POSCardEntry_l.Reset();//crea linea para media de pago tarjeta
                    POSCardEntry_l.SetRange("Receipt No.", ReceiptTrans);
                    if POSCardEntry_l.FindFirst() then begin
                        RequestID := 'DEL-TRANSCARDFSN';
                        MsgResult := Format(DelOrder."General Status");
                        XMLRequest := ReceiptTrans;
                        FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
                    end;

                    //Commit();

                    DelOrder.Reset();
                    if DelOrder.get(ReceiptTrans) then begin
                        DelCont.Reset();
                        if not DelCont.get(DelOrder."Phone No.") then begin
                            DelCont.Init();
                            DelCont."No." := DelOrder."Phone No.";
                        end;
                        DelCont."Phone No." := DelOrder."Phone No.";
                        DelCont."LSC Next Order Selection" := DelOrder."Order Type Option";
                        DelCont."LSC Next Order Restaurant" := DelOrder."Restaurant No.";
                        DelCont."LSC Next Order Date" := DelOrder."Order Date";
                        DelCont."LSC Next Order Time" := DelOrder."Contact Pickup Time";
                        DelCont."LSC Next Delivery Tender" := DelOrder."Tender Type";
                        DelCont."LSC Pre-Order Print DateTime" := DelOrder."Pre-Order Print DateTime";
                        DelCont."LSC Next Estimated Prod. Time" := DelOrder."Estimated Prod. Time (Min.)";
                        if not DelCont.insert then
                            DelCont.Modify;

                        POSLine.RESET;
                        POSLine.SETRANGE(POSLine."Receipt No.", WebServiceTable.LastSlipNo);
                        POSLine.SETRANGE(POSLine."Entry Type", POSLine."Entry Type"::Item);
                        POSLine.SETRANGE(POSLine."Entry Status", 0);
                        IF POSLine.FIND('-') THEN
                            REPEAT
                                IF Item_l.GET(POSLine.Number) THEN
                                    IF Item_l."LSC Attrib 2 Code" IN ['PAQUETERIA-C807'] THEN BEGIN
                                        if Parameter.Get('PAQUETERIA', Item_l."No.") then
                                            if Parameter.Activo then begin
                                                WebServiceTable."Last Error Text" := ErrorText02;
                                                WebServiceTable.MODIFY;
                                                EXIT;
                                            end;
                                    END;
                            UNTIL POSLine.NEXT = 0;

                        SalesChanel(DelOrder, WebServiceTable);


                        POSLine.RESET;
                        POSLine.SETRANGE(POSLine."Receipt No.", WebServiceTable.LastSlipNo);
                        POSLine.SETRANGE(POSLine."Entry Type", POSLine."Entry Type"::Item);
                        POSLine.SETRANGE(POSLine."Entry Status", 0);
                        IF POSLine.FIND('-') THEN
                            REPEAT
                                IF Item_l.GET(POSLine.Number) THEN
                                    IF Item_l."LSC Attrib 2 Code" IN ['CONTROLADOS', 'MONOFARMACO-CONTROLADO', 'POLIFARMACO-CONTROLADO'] THEN BEGIN
                                        WebServiceTable."Last Error Text" := ErrorText05;
                                        WebServiceTable.MODIFY;
                                        EXIT;
                                    END;
                            UNTIL POSLine.NEXT = 0;

                        FSNCallCOrder.ValidateTimeOnRestChange(DelCont, errorText, false, DelOrder);
                        if errorText <> '' then begin
                            if not (WebServiceTable."Order Type" in [WebServiceTable."Order Type"::Takeaway, WebServiceTable."Order Type"::FromStoreTakeaway]) then
                                WebServiceTable."Store Selected" := SalesSugEcommerce(WebServiceTable);
                            WebServiceTable."Status WS" := WebServiceTable."Status WS"::Pending;
                            WebServiceTable."Last Error Text" := CopyStr(errorText, 1, 100);
                            WebServiceTable.Modify();

                            UpdateOrder(WebServiceTable);
                            exit;
                        end;

                        if FsnTakeOrder.SendDeliveryOrder(DelOrder, onlineorder, ErrorText) then begin
                            if ErrorText = '' then begin
                                DelOrder.Reset();
                                DelOrder.Get(ReceiptTrans);
                                if DelOrder."Call Cent. Web Service Status" in
                                    [DelOrder."Call Cent. Web Service Status"::"New-Not Sent", DelOrder."Call Cent. Web Service Status"::"New-Not Confirmed"] then
                                    DelOrder."Call Cent. Web Service Status" := DelOrder."Call Cent. Web Service Status"::"New-Sent";

                                if DelOrder."Call Cent. Web Service Status" = DelOrder."Call Cent. Web Service Status"::"Changed-Not Sent" then
                                    DelOrder."Call Cent. Web Service Status" := DelOrder."Call Cent. Web Service Status"::"Changed-Sent";


                                DelOrder."General Status" := DelOrder."General Status"::"In Process";
                                if (DelOrder."Assigned to Driver") or (DelOrder."Process Status" = DelOrder."Process Status"::Finished) then
                                    DelOrder."General Status" := DelOrder."General Status"::Confirmed;
                                DelOrder.Modify();

                                POSSESSION.SetValue('DEL-PickupDate', Format(DelOrder."Order Date"));
                                POSSESSION.SetValue('DEL-PickupTime', format(DelOrder."Contact Pickup Time"));


                                RequestID := 'DEL-TRANSFSN';//manda a DAF
                                MsgResult := Format(DelOrder."General Status");
                                XMLRequest := DelOrder."Order No.";
                                FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);


                                WebServiceTable."Status WS" := WebServiceTable."Status WS"::InProcess;
                                WebServiceTable."Last Error Text" := 'SENT';
                                WebServiceTable."Key Number Text 1" := 1;
                                WebServiceTable.Modify();
                            end else begin
                                DelOrder.Reset();
                                DelOrder.Get(ReceiptTrans);
                                if DelOrder."Call Cent. Web Service Status" = DelOrder."Call Cent. Web Service Status"::"New-Not Confirmed" then
                                    DelOrder."Call Cent. Web Service Status" := DelOrder."Call Cent. Web Service Status"::"New-Not Sent";
                                DelOrder."General Status" := DelOrder."General Status"::ERROR;
                                DelOrder.Modify();

                                WebServiceTable."Status WS" := WebServiceTable."Status WS"::Pending;
                                WebServiceTable."Last Error Text" := ErrorText03;
                                WebServiceTable.Modify();
                            end;
                        end else begin
                            DelOrder.Reset();
                            DelOrder.Get(ReceiptTrans);
                            if DelOrder."Call Cent. Web Service Status" = DelOrder."Call Cent. Web Service Status"::"New-Not Confirmed" then
                                DelOrder."Call Cent. Web Service Status" := DelOrder."Call Cent. Web Service Status"::"New-Not Sent";
                            DelOrder."General Status" := DelOrder."General Status"::ERROR;
                            DelOrder.Modify();

                            WebServiceTable."Status WS" := WebServiceTable."Status WS"::Pending;
                            WebServiceTable."Last Error Text" := ErrorText03;
                            WebServiceTable.Modify();
                        end;
                        //message(ErrorText);
                    end;
                end;
            end else begin
                if not (WebServiceTable."Order Type" in [WebServiceTable."Order Type"::Takeaway, WebServiceTable."Order Type"::FromStoreTakeaway]) then
                    WebServiceTable."Store Selected" := SalesSugEcommerce(WebServiceTable);
                WebServiceTable."Status WS" := WebServiceTable."Status WS"::Pending;
                WebServiceTable."Last Error Text" := ErrorText01;
                WebServiceTable.Modify();

                UpdateOrder(WebServiceTable);

            end;
        end;
    end;

    procedure POSInsertReplenSalesHist(pDelOrder: Record "LSC Delivery Order"; pPOSTrans: Record "LSC POS Transaction"; WebServiceTable: Record "FSN WebServiceTable")
    var
        DelStreet: Record "LSC Delivery Street";
        Ptline: Record "LSC POS Trans. Line";
        InventoryLookup: Record "LSC Inventory Lookup Table";
        IsInventoryOK: Boolean;
        InsertOK: Boolean;
        Item_l: Record "Item";
        Item_TMP: Record "FSN Inventory Internal Log" temporary;
        ItemInternalLog: Record "FSN Inventory Internal Log";
        ReplenAdjLine: Record "FSN Replen. Sales Adj. Line";
        AdjNextLine: Record "FSN Replen. Sales Adj. Line";
        i: Integer;
        lText000: Label 'Del. for %1, default %2. In order %3 Inv. %4';
        lText001: Label 'Del. para %1, por defecto APP/CC GENERICO OTROS. En orden %2 Inv. %3';
        FSNDeliveryFunctionsExtend: Codeunit "FSN Delivery Functions Extend";
    begin
        IF (pDelOrder."Order Type Option" in [4]) OR (WebServiceTable."Customer No." = '') THEN
            EXIT;

        IF pDelOrder."FSN Alter Key" = 0 THEN
            EXIT;

        DelStreet.RESET;
        DelStreet.SETRANGE(DelStreet."FSN Alter Key", pDelOrder."FSN Alter Key");
        IF NOT DelStreet.FINDFIRST THEN
            EXIT;

        IF pDelOrder."Restaurant No." = DelStreet."Restaurant No." THEN
            EXIT;

        /*if DelStreet."Restaurant No." = '' then
            exit;*/

        Item_TMP.RESET;
        Item_TMP.DELETEALL;

        Ptline.RESET;
        Ptline.SETCURRENTKEY("Receipt No.", "Entry Type", "Entry Status");
        Ptline.SETRANGE(Ptline."Receipt No.", pDelOrder."Order No.");
        Ptline.SETRANGE(Ptline."Entry Type", Ptline."Entry Type"::Item);
        Ptline.SETRANGE(Ptline."Entry Status", 0);
        IF Ptline.FIND('-') THEN
            REPEAT
                CLEAR(InsertOK);
                IF ItemInternalLog.GET(Ptline.Number) THEN
                    InsertOK := ItemInternalLog."Calculate Inventory" = ItemInternalLog."Calculate Inventory"::Yes
                ELSE
                    InsertOK := TRUE;
                IF InsertOK THEN BEGIN
                    IF NOT Item_TMP.GET(Ptline.Number) THEN BEGIN
                        Item_TMP.INIT;
                        Item_TMP."No." := Ptline.Number;
                        Item_TMP."Qty. per UM" := 0;
                        Item_TMP.INSERT;
                    END;
                    Item_TMP."Qty. per UM" += (FSNDeliveryFunctionsExtend.DivisorQtyPerUM(Ptline.Number, Ptline."Unit of Measure") * Ptline.Quantity);
                    Item_TMP.MODIFY;
                END;
            UNTIL Ptline.NEXT = 0;

        CLEAR(InsertOK);

        Item_TMP.RESET;
        IF Item_TMP.FIND('-') THEN
            REPEAT
                InventoryLookup.RESET;
                CLEAR(InventoryLookup);

                IsInventoryOK := TRUE;
                //IsInventoryOK := InventoryLookup.GET(Item_TMP."No.", '', DelStreet."Restaurant No.", '', '');
                IsInventoryOK := InventoryLookup.GET(Item_TMP."No.", '', pDelOrder."Restaurant No.", '', '');
                IF IsInventoryOK THEN
                    IsInventoryOK := Item_TMP."Qty. per UM" <= InventoryLookup."Net Inventory";

                IF NOT IsInventoryOK AND Item_l.GET(Item_TMP."No.") THEN BEGIN
                    CLEAR(InsertOK);
                    ReplenAdjLine.RESET;
                    ReplenAdjLine.SETCURRENTKEY("Customer ID", Date, "Item No.");
                    ReplenAdjLine.SETRANGE(ReplenAdjLine."Customer ID", pPOSTrans."Customer No.");
                    ReplenAdjLine.SETFILTER(ReplenAdjLine.Date, '>=%1&<=%2', TODAY - 3, TODAY);
                    ReplenAdjLine.SETRANGE(ReplenAdjLine."Item No.", Item_TMP."No.");
                    IF ReplenAdjLine.FIND('-') THEN BEGIN
                        InsertOK := (ReplenAdjLine."Unit of Measure" = Item_l."Base Unit of Measure");
                        IF NOT ReplenAdjLine.Aprobada THEN BEGIN
                            ReplenAdjLine."Receipt No." := pDelOrder."Order No.";
                            ReplenAdjLine.MODIFY;
                        END;
                    END;
                    IF NOT InsertOK THEN BEGIN
                        ReplenAdjLine.INIT;
                        ReplenAdjLine."Item No." := Item_TMP."No.";
                        ReplenAdjLine.Date := TODAY;
                        ReplenAdjLine."Location Code" := pDelOrder."Restaurant No.";
                        //ReplenAdjLine."Location Code" := DelStreet."Restaurant No.";
                        AdjNextLine.RESET;
                        AdjNextLine.SETCURRENTKEY("Item No.", Date, "Location Code", "Line No.");
                        AdjNextLine.SETRANGE(AdjNextLine."Item No.", Item_TMP."No.");
                        AdjNextLine.SETRANGE(AdjNextLine.Date, TODAY);
                        //AdjNextLine.SETRANGE(AdjNextLine."Location Code", DelStreet."Restaurant No.");
                        AdjNextLine.SETRANGE(AdjNextLine."Location Code", pDelOrder."Restaurant No.");
                        IF AdjNextLine.FIND('+') THEN
                            ReplenAdjLine."Line No." := AdjNextLine."Line No." + 1
                        ELSE
                            ReplenAdjLine."Line No." := 1000;
                        ReplenAdjLine."Barcode No." := Item_l."FSN Barcode No.";
                        ReplenAdjLine."Variant Code" := '';
                        ReplenAdjLine.Description := Item_l.Description;
                        ReplenAdjLine.Quantity := ROUND(Item_TMP."Qty. per UM" - InventoryLookup."Net Inventory", 1);//WVILLALTA 11.21
                        IF InventoryLookup."Net Inventory" < 0 THEN
                            ReplenAdjLine.Quantity := ROUND(Item_TMP."Qty. per UM", 1);
                        ReplenAdjLine."Unit of Measure" := Item_l."Base Unit of Measure";
                        ReplenAdjLine.StaffID := pDelOrder."Order Taker";
                        IF ReplenAdjLine.StaffID = '' THEN
                            ReplenAdjLine.StaffID := pPOSTrans."Sales Staff";
                        ReplenAdjLine.Aprobada := FALSE;
                        ReplenAdjLine.Telefono := pDelOrder."Phone No.";
                        ReplenAdjLine."Replication Counter" := 0;
                        ReplenAdjLine."Customer ID" := WebServiceTable."Customer No.";
                        /*ReplenAdjLine.Comment := COPYSTR(STRSUBSTNO(lText000, pDelOrder."Restaurant No.", DelStreet."Restaurant No.", FORMAT(Item_TMP."Qty. per UM")
                                                        , FORMAT(InventoryLookup."Net Inventory")), 1, MAXSTRLEN(ReplenAdjLine.Comment));*/
                        ReplenAdjLine.Comment := COPYSTR(STRSUBSTNO(lText001, pDelOrder."Restaurant No.", FORMAT(Item_TMP."Qty. per UM")
                                                       , FORMAT(InventoryLookup."Net Inventory")), 1, MAXSTRLEN(ReplenAdjLine.Comment));
                        ReplenAdjLine."Receipt No." := pDelOrder."Order No.";
                        ReplenAdjLine."Adjustment Mode" := ReplenAdjLine."Adjustment Mode"::DeliveryAutomatic;
                        ReplenAdjLine."Location Code Source" := pDelOrder."Restaurant No.";
                        ReplenAdjLine.INSERT;
                    END;
                END;
            UNTIL Item_TMP.NEXT = 0;
    end;



    procedure UpdateOrder(WebServiceT: Record "FSN WebServiceTable")
    var
        POSTransLine, ValInventoryPosTransLine, POSLine : Record "LSC POS Trans. Line";
        POSTPeriodicType: Record "LSC POS Trans. Per. Disc. Type";
        POSTransInfocodeEntry: Record "LSC POS Trans. Infocode Entry";
        POSDataEntry: Record "LSC POS Data Entry";
        VoucherEntry: Record "LSC Voucher Entries";
        POSCardRequestEntry, POSCardReq_1 : Record "FSN POS Card Request Entry";
        POSCardEntry_l, PosCardEntry2 : Record "LSC POS Card Entry";
        POSCardEntryTmp: Record "LSC POS Card Entry" temporary;
        PosCardReqIn: Record "FSN POS Card Request Inherit";
        TerminalAsig: Record "LSC CC POS Term. Assignm.";
        POSTransaction: Record "LSC POS Transaction";
        FsnTakeOrder: Page "FSN Take Order CC";
        DelOrder: Record "LSC Delivery Order";
        onlineorder: boolean;
        ErrorText: text;
        DelCont: Record Contact;
        DelInventoryMHt: Codeunit "FSN Delivery Inventory Mgt.";
        ErrorText01: Label 'Sala no sugerida por inventario, Store Select mas cercano';
        ErrorText02: Label 'No enviado por producto paqueteria';
        ErrorText03: Label 'No enviado a tienda destino';
        ErrorText04: Label 'Enviado con Exito';
        FSNUtility: Codeunit "FSN Utility";
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        MsgResult: Text;
        POSMenuLineTemp: Record "LSC POS Menu Line" temporary;
        Processed: Boolean;
        EcommerceMgt: Codeunit "FSN Ecommerce CallCenter Mgt.";
        error: Boolean;
        Item_l: Record Item;
        Parameter: Record "FSN Parameter";
        FilterCustomer: Record Customer;
        POSSESSION: Codeunit "LSC POS Session";
        SalesTypeRec: Record "LSC Sales Type";
        DelFuntion: Codeunit "FSN Delivery Functions Extend";
        OferPosCalculetion: Record "LSC Offer Pos Calculation";
        LSCFuntion: Codeunit "LSC POS Functions";
        POSTranslineTem: Record "LSC POS Trans. Line" temporary;
        POSTransDiscount: Codeunit "LSC POS Trans. Discounts";
        VatSetup: Record "VAT Posting Setup";
        HospSetup: record "LSC Hospitality Setup";
    begin
        if WebServiceT."Store Selected" <> '' then begin
            TerminalAsig.Reset();
            IF TerminalAsig.Get('F20', WebServiceT."Store Selected") THEN BEGIN
                //POS Transaction.
                POSTransaction.Reset();
                if POSTransaction.Get(WebServiceT.LastSlipNo) then begin
                    POSTransaction."Store No." := TerminalAsig."Restaurant No.";
                    POSTransaction."POS Terminal No." := TerminalAsig."Rest. POS Terminal";
                    POSTransaction."Created on POS Terminal" := TerminalAsig."Rest. POS Terminal";
                    POSTransaction."Entry Status" := POSTransaction."Entry Status"::" ";
                    //WebServiceTable.Store := TerminalAsig."Restaurant No.";
                    //WebServiceTable.Terminal := TerminalAsig."Rest. POS Terminal";
                    //WebServiceTable.Modify();
                    if POSTransaction.Comment = '' then
                        POSTransaction.Comment := CopyStr(WebServiceT."First Name" + ' ' + WebServiceT."Last Name", 1, 100);
                    POSTransaction.Modify(true);
                end;

                if (CopyStr(WebServiceT.LastSlipNo, 1, 10) = '00000APP01') OR
                    (CopyStr(WebServiceT.LastSlipNo, 1, 10) = '00000APP02') OR
                        (CopyStr(WebServiceT.LastSlipNo, 1, 10) = '000PV#1000') then begin
                    CreateDelOrderDeliveryEcommerce2(WebServiceT, POSTransaction)
                end else
                    CreateDelOrderDeliveryEcommerce(WebServiceT, POSTransaction);

                DelOrder.Reset();
                if DelOrder.Get(WebServiceT.LastSlipNo) then begin
                    IF POSTransaction.Get(WebServiceT.LastSlipNo) THEN BEGIN
                        if (DelOrder."Pre-Order" = DelOrder."Pre-Order"::"On Hold") and (DelOrder."Order Date" <> Today) then begin
                            HospSetup.Get();
                            if POSTransaction."Sales Type" <> HospSetup."Pre-Order Sales Type" then begin
                                POSTransaction."Original Sales Type" := DelOrder."Sales Type";
                                POSTransaction."Sales Type" := HospSetup."Pre-Order Sales Type";
                                if SalesTypeRec.Get(HospSetup."Pre-Order Sales Type") then begin
                                    if SalesTypeRec."VAT Bus. Posting Group" <> '' then
                                        POSTransaction.Validate("VAT Bus.Posting Group", SalesTypeRec."VAT Bus. Posting Group");
                                    if SalesTypeRec."Price Group" <> '' then
                                        POSTransaction.Validate("Price Group Code", SalesTypeRec."Price Group");
                                end;
                            end;
                        end else begin
                            if SalesTypeRec.Get(DelOrder."Sales Type") then begin
                                POSTransaction."Sales Type" := DelOrder."Sales Type";
                                if SalesTypeRec."VAT Bus. Posting Group" <> '' then
                                    POSTransaction.Validate("VAT Bus.Posting Group", SalesTypeRec."VAT Bus. Posting Group");
                                if SalesTypeRec."Price Group" <> '' then
                                    POSTransaction.Validate("Price Group Code", SalesTypeRec."Price Group");
                            end;
                        END;
                    end;

                    if WebServiceT."Distribution Location" <> '' then begin
                        POSTransaction."Staff ID" := 'BOT';
                        POSTransaction."Sales Staff" := 'BOT';
                    end else begin
                        POSTransaction."Staff ID" := 'F20CC';
                        POSTransaction."Sales Staff" := 'F20CC';
                    end;
                    POSTransaction.Modify(true);
                end;

                DelOrder.Reset();
                if DelOrder.Get(WebServiceT.LastSlipNo) then begin
                    if SalesTypeRec.Get(DelOrder."Sales Type") then begin
                        IF POSTransaction.Get(WebServiceT.LastSlipNo) THEN BEGIN
                            POSTransaction."Sales Type" := DelOrder."Sales Type";
                            if SalesTypeRec."VAT Bus. Posting Group" <> '' then
                                POSTransaction.Validate("VAT Bus.Posting Group", SalesTypeRec."VAT Bus. Posting Group");
                            if SalesTypeRec."Price Group" <> '' then
                                POSTransaction.Validate("Price Group Code", SalesTypeRec."Price Group");
                            if POSTransaction."Staff ID" = '' then
                                if WebServiceT."Distribution Location" <> '' then
                                    POSTransaction."Staff ID" := 'BOT'
                                else
                                    POSTransaction."Staff ID" := 'F20CC';
                            if POSTransaction."Sales Staff" = '' then
                                if WebServiceT."Distribution Location" <> '' then
                                    POSTransaction."Sales Staff" := 'BOT'
                                else
                                    POSTransaction."Sales Staff" := 'F20CC';
                            POSTransaction.Modify(true);
                        END;
                    end;
                end;

                //POS Trans. Line.
                POSTransLine.Reset();
                POSTransLine.SetRange("Receipt No.", WebServiceT.LastSlipNo);
                if POSTransLine.Find('-') then begin
                    repeat
                        POSTransLine."Store No." := TerminalAsig."Restaurant No.";
                        POSTransLine."POS Terminal No." := TerminalAsig."Rest. POS Terminal";

                        if WebServiceT."Distribution Location" <> '' then begin
                            POSTransLine."Sales Staff" := 'BOT';
                            POSTransLine."Created by Staff ID" := 'BOT'
                        end else begin
                            POSTransLine."Sales Staff" := 'F20CC';
                            POSTransLine."Created by Staff ID" := 'F20CC';
                        end;

                        if POSTransLine."Entry Type" = POSTransLine."Entry Type"::Item then begin
                            POSTransaction.Reset();
                            if POSTransaction.Get(POSTransLine."Receipt No.") then begin
                                if POSTransaction."Price Group Code" <> POSTransLine."Price Group Code" then
                                    POSTransLine."Price Group Code" := POSTransaction."Price Group Code";
                                if VatSetup.Get(POSTransLine."VAT Bus. Posting Group", POSTransLine."VAT Prod. Posting Group") then
                                    POSTransLine."VAT Calculation Type" := VatSetup."VAT Calculation Type";

                            end;
                        end;
                        POSTransLine.Modify();
                    until POSTransLine.Next() = 0;
                end;


                //LSC POS Trans. Per. Disc. Type
                POSTPeriodicType.Reset();
                POSTPeriodicType.SetRange("Receipt No.", WebServiceT.LastSlipNo);
                if POSTPeriodicType.Find('-') then begin
                    repeat
                        POSTPeriodicType."POS Terminal No." := TerminalAsig."Rest. POS Terminal";
                        POSTPeriodicType.Modify(true);
                    until POSTPeriodicType.Next() = 0;
                end;


                //LSC POS Trans. Infocode Entry
                POSTransInfocodeEntry.Reset();
                POSTransInfocodeEntry.SetRange(POSTransInfocodeEntry."Receipt No.", WebServiceT.LastSlipNo);
                if POSTransInfocodeEntry.Find('-') then begin
                    repeat
                        POSTransInfocodeEntry."Store No." := TerminalAsig."Restaurant No.";
                        POSTransInfocodeEntry."POS Terminal No." := TerminalAsig."Rest. POS Terminal";
                        POSTransInfocodeEntry.Modify();
                    until POSTransInfocodeEntry.Next() = 0;
                end;

                //LSC POS Data Entry
                POSDataEntry.Reset();
                POSDataEntry.SetRange("Created by Receipt No.", WebServiceT.LastSlipNo);
                if POSDataEntry.Find('-') then begin
                    repeat
                        POSDataEntry."Created in Store No." := TerminalAsig."Restaurant No.";
                        POSDataEntry.Modify();
                    until POSDataEntry.Next() = 0;
                end;

                //LSC Voucher Entries
                VoucherEntry.Reset();
                VoucherEntry.SetRange("Receipt Number", WebServiceT.LastSlipNo);
                if VoucherEntry.Find('-') then begin
                    repeat
                        VoucherEntry."Store No." := TerminalAsig."Restaurant No.";
                        VoucherEntry."POS Terminal No." := TerminalAsig."Rest. POS Terminal";
                        VoucherEntry.Modify();
                    until VoucherEntry.Next() = 0;
                end;

                //FSN POS Card Request Entry
                POSCardRequestEntry.Reset();
                POSCardRequestEntry.SetRange("Receipt No.", WebServiceT.LastSlipNo);
                if POSCardRequestEntry.Find('-') then begin
                    repeat
                        POSCardRequestEntry."Store No." := TerminalAsig."Restaurant No.";
                        POSCardRequestEntry.Modify();
                    until POSCardRequestEntry.Next() = 0;
                end;


                POSCardEntry_l.RESET;
                POSCardEntry_l.SETRANGE(POSCardEntry_l."Receipt No.", WebServiceT.LastSlipNo);
                IF POSCardEntry_l.FIND('-') THEN
                    REPEAT
                        POSCardEntryTmp := POSCardEntry_l;
                        POSCardEntryTmp."Store No." := TerminalAsig."Restaurant No.";
                        POSCardEntryTmp."POS Terminal No." := TerminalAsig."Rest. POS Terminal";
                        POSCardEntryTmp."Entry No." := DelFuntion.NextEntryNo(TerminalAsig."Restaurant No.", TerminalAsig."Rest. POS Terminal");
                        IF NOT (POSCardEntryTmp.INSERT) THEN begin
                            POSCardEntryTmp.MODIFY;
                        end else begin
                            PosCardEntry2 := POSCardEntryTmp;
                            PosCardEntry2.Insert();
                            POSCardEntry_l.Delete();
                            POSCardEntryTmp.Delete();
                        end;
                    UNTIL POSCardEntry_l.NEXT = 0;

                POSCardReq_1.Reset();
                POSCardReq_1.SetRange(POSCardReq_1."Receipt No.", WebServiceT.LastSlipNo);
                if POSCardReq_1.Find('-') then begin
                    repeat
                        POSCardReq_1."Store No." := TerminalAsig."Restaurant No.";
                        POSCardReq_1.Modify();
                    until POSCardReq_1.Next() = 0;
                end;

                PosCardReqIn.Reset();
                PosCardReqIn.SetRange(PosCardReqIn."Receipt No. Inherit", WebServiceT.LastSlipNo);
                if PosCardReqIn.Find('-') then begin
                    repeat
                        PosCardReqIn."Store No. Inherit" := TerminalAsig."Restaurant No.";
                        PosCardReqIn.Modify();
                    until PosCardReqIn.Next() = 0;
                end;


                POSCardEntry_l.Reset();//crea linea para media de pago tarjeta
                POSCardEntry_l.SetRange("Receipt No.", WebServiceT.LastSlipNo);
                if POSCardEntry_l.FindFirst() then begin
                    RequestID := 'DEL-TRANSCARDFSN';
                    MsgResult := Format(DelOrder."General Status");
                    XMLRequest := WebServiceT.LastSlipNo;
                    FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
                end;

                //Commit();

                DelOrder.Reset();
                if DelOrder.get(WebServiceT.LastSlipNo) then begin
                    DelCont.Reset();
                    if not DelCont.get(DelOrder."Phone No.") then begin
                        DelCont.Init();
                        DelCont."No." := DelOrder."Phone No.";
                    end;
                    DelCont."Phone No." := DelOrder."Phone No.";
                    DelCont."LSC Next Order Selection" := DelOrder."Order Type Option";
                    DelCont."LSC Next Order Restaurant" := DelOrder."Restaurant No.";
                    DelCont."LSC Next Order Date" := DelOrder."Order Date";
                    DelCont."LSC Next Order Time" := DelOrder."Contact Pickup Time";
                    DelCont."LSC Next Delivery Tender" := DelOrder."Tender Type";
                    DelCont."LSC Pre-Order Print DateTime" := DelOrder."Pre-Order Print DateTime";
                    DelCont."LSC Next Estimated Prod. Time" := DelOrder."Estimated Prod. Time (Min.)";
                    if not DelCont.insert then
                        DelCont.Modify;

                    POSLine.RESET;
                    POSLine.SETRANGE(POSLine."Receipt No.", WebServiceT.LastSlipNo);
                    POSLine.SETRANGE(POSLine."Entry Type", POSLine."Entry Type"::Item);
                    POSLine.SETRANGE(POSLine."Entry Status", 0);
                    IF POSLine.FIND('-') THEN
                        REPEAT
                            IF Item_l.GET(POSLine.Number) THEN
                                IF Item_l."LSC Attrib 2 Code" IN ['PAQUETERIA-C807'] THEN BEGIN
                                    if Parameter.Get('PAQUETERIA', Item_l."No.") then
                                        if Parameter.Activo then begin
                                            WebServiceT."Last Error Text" := ErrorText02;
                                            WebServiceT.MODIFY;
                                            EXIT;
                                        end;
                                END;
                        UNTIL POSLine.NEXT = 0;

                    DelOrder."General Status" := DelOrder."General Status"::"In Process";
                    DelOrder."Call Cent. Web Service Status" := DelOrder."Call Cent. Web Service Status"::"New-Not Confirmed";
                    DelOrder.Modify();

                    SalesChanel(DelOrder, WebServiceT);


                end;
            end;
        end;
    end;

    procedure SalesChanel(OrderVal: Record "LSC Delivery Order"; WebServiceTable: Record "FSN WebServiceTable")
    var
        SalesChan: Record "FSN Sales Channel";
        POSSetupExtend: Record "FSN POS Setup Extend";
        Description: Text[50];
        Exists: Boolean;
    begin
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

    procedure SalesSugEcommerce(WSTable: Record "FSN WebServiceTable"): Code[10]
    var
        myInt: Integer;
        storeLink: record "FSN Store Link";
        lat: Decimal;
        lon: Decimal;
        storeLink_tmp2: record "FSN Store Link" temporary;
        StoreLink2: Record "FSN Store Link";
        km: Decimal;
        Delstret: Record "LSC Delivery Street";
        km2: Decimal;
        store, store2 : Record "LSC Store";
        store_tmp, store_tmp2 : Record "LSC Store" temporary;
        OrderType: Option Home,Work,Other,Takeout;
        EcomMgt: Codeunit "FSN Ecommerce CallCenter Mgt.";
    begin
        if Evaluate(lat, CopyStr(wsTable."Value Text 1", 1, StrPos(wsTable."Value Text 1", ',') - 1))
                    and
                    Evaluate(lon, CopyStr(wsTable."Value Text 1", StrPos(wsTable."Value Text 1", ',') + 1, StrLen(wsTable."Value Text 1")))
                        then begin

            ///15398 
            storeLink.Reset();
            storeLink.SetRange(Type, storeLink.Type::StoreSetup);
            if storeLink.Find('-') then
                repeat
                    store_tmp2.Init();
                    store_tmp2."Fraud Sort Field" := EcomMgt.GetDistanceGeopraphic(
                        lat,
                        lon,
                        storeLink."Parent Latitude",
                        storeLink."Parent Longitude"
                    );
                    store_tmp2."No." := storeLink."Parent Code";
                    if store_tmp2."Fraud Sort Field" <= 5 then
                        if store_tmp2.Insert() then;
                until storeLink.Next() = 0;

            store_tmp2.Reset();
            store_tmp2.SetCurrentKey("Fraud Sort Field");
            if store_tmp2.Find('-') then;
            exit(store_tmp2."No.");

        end;
    end;

    //crea delivery order y actualiza delivery contac address para prefactura
    procedure CreateDelOrderDeliveryEcommerce(WSTable: Record "FSN WebServiceTable"; POSTransactionV: Record "LSC POS Transaction")
    var
        DelOrder: Record "LSC Delivery Order";
        DelCustAddr: Record "LSC Delivery Contact Address";
        POSInfocodeEntry: Record "LSC POS Trans. Infocode Entry";
        BOUTIL: Codeunit "LSC BO Utils";
        Delstret: Record "LSC Delivery Street";
        TypeText: text;
        TypeInt: integer;
        SalesTypes: Record "LSC Sales Type";
        Direction: text[250];
        FSNAlterKey: Integer;
        DelContac: Record Contact;
    begin

        clear(TypeText);
        POSInfocodeEntry.Reset();
        POSInfocodeEntry.SETRANGE("Receipt No.", WSTable.LastSlipNo);
        POSInfocodeEntry.SETRANGE(Infocode, 'DDIRECTION');
        IF POSInfocodeEntry.find('-') THEN
            repeat
                Direction := Direction + POSInfocodeEntry.Information;
            until POSInfocodeEntry.Next() = 0;

        if WSTable."Order Type" in [WSTable."Order Type"::Takeaway, WSTable."Order Type"::FromStoreTakeaway] then begin
            Delstret.Reset();
            if Delstret.get('GENERICO OTROS', 1, '614') then begin
                DelCustAddr.Reset();
                DelCustAddr.SetRange("Address Type", DelCustAddr."Address Type"::Other);
                DelCustAddr.SetRange("Phone No.", wsTable."Sell-to Contact No.");
                if not DelCustAddr.FindFirst() then begin
                    DelCustAddr.Init();
                    DelCustAddr."Phone No." := wsTable."Sell-to Contact No.";
                    DelCustAddr."Address Type" := DelCustAddr."Address Type"::Other
                end;


                DelCustAddr."Street Name" := Delstret."Street Name";
                DelCustAddr."FSN Street Name" := Delstret."Street Name";
                DelCustAddr."Post Code" := Delstret."Post Code";
                DelCustAddr."Restaurant No." := Delstret."Restaurant No.";
                DelCustAddr.Directions := CopyStr(Direction, 1, 100);
                DelCustAddr."FSN Direction" := Direction;
                FSNAlterKey := Delstret."FSN Alter Key";

                DelContac.Reset();
                if not DelContac.Get(wsTable."Sell-to Contact No.") then begin
                    DelContac.Init();
                    DelContac."No." := wsTable."Sell-to Contact No.";
                end;

                DelContac."Phone No." := wsTable."Sell-to Contact No.";
                DelContac.Name := wsTable."First Name" + ' ' + wsTable."Last Name";
                DelContac."Search Name" := wsTable."First Name";
                if not DelContac.Insert(true) then
                    DelContac.Modify(true);

                if not DelCustAddr.Insert(true) then
                    DelCustAddr.Modify(True);
            end;
        end else
            StretNoEcommerce(WSTable, Direction, DelCustAddr, DelContac, FSNAlterKey);

        if not DelOrder.Get(WSTable.LastSlipNo) then begin
            DelOrder.Init;
            DelOrder."Order No." := WSTable.LastSlipNo;

        end;
        DelOrder."Restaurant No." := WSTable."Store Selected";
        DelOrder.Validate("General Status", DelOrder."General Status"::"In Process");
        DelOrder."Call Cent. Web Service Status" := DelOrder."Call Cent. Web Service Status"::"New-Not Confirmed";
        DelOrder."Phone No." := WSTable."Sell-to Contact No.";
        DelOrder."Order Date" := TODAY;
        if WSTable."Order Type" in [WSTable."Order Type"::Takeaway, WSTable."Order Type"::FromStoreTakeaway] then
            DelOrder.Validate("Order Type Option", 4)
        else
            DelOrder.Validate("Order Type Option", 3);
        DelOrder.Address := DelCustAddr."Street Name";
        DelOrder."Address 2" := DelCustAddr."Address 2";
        DelOrder.City := DelCustAddr.City;
        DelOrder."Created at Call Center" := 'F20';
        DelOrder."Post Code" := DelCustAddr."Post Code";
        DelOrder.Directions := DelCustAddr.Directions;
        DelOrder."Grid Code" := DelCustAddr."Grid Code";
        DelOrder."Contact Pickup Time" := WSTable.Time;
        DelOrder."Date Created" := Today;
        DelOrder."Time Created" := WSTable.Time;
        if WSTable."Distribution Location" <> '' then
            DelOrder."Order Taker" := 'BOT'
        else
            DelOrder."Order Taker" := 'F20CC';
        DelOrder.Name := CopyStr(WSTable."First Name" + ' ' + WSTable."Last Name", 1, 100);
        DelOrder."Bill-to Name" := CopyStr(WSTable."First Name" + ' ' + WSTable."Last Name", 1, 100);
        /*if SalesTypes.Get(POSTransactionV."Sales Type") then
            DelOrder."Sales Type" := SalesTypes.Code;*/
        DelOrder."FSN Alter Key" := FSNAlterKey;
        DelOrder."FSN Directions" := DelCustAddr."FSN Direction";
        DelOrder."FSN Street Name" := DelCustAddr."Street Name";
        if not DelOrder.Insert(true) then
            DelOrder.Modify(true);

        Commit();
    end;

    //crea delivery order y actualiza delivery contac address para pedidos de APP y Ecommerce
    procedure CreateDelOrderDeliveryEcommerce2(WSTable: Record "FSN WebServiceTable"; POSTransactionV: Record "LSC POS Transaction")
    var
        DelOrder: Record "LSC Delivery Order";
        DelCustAddr: Record "LSC Delivery Contact Address";
        POSInfocodeEntry: Record "LSC POS Trans. Infocode Entry";
        BOUTIL: Codeunit "LSC BO Utils";
        Delstret: Record "LSC Delivery Street";
        TypeText: text;
        TypeInt: integer;
        SalesTypes: Record "LSC Sales Type";
        Direction: text[250];
        FSNAlterKey: Integer;
        DelContac: Record Contact;
        OrderDateTime: datetime;
        OrderTime: Time;
        OrderDate: Date;
    begin
        OrderDate := 0D;
        clear(TypeText);
        POSInfocodeEntry.Reset();
        POSInfocodeEntry.SETRANGE("Receipt No.", WSTable.LastSlipNo);
        POSInfocodeEntry.SETRANGE(Infocode, 'DDIRECTION');
        IF POSInfocodeEntry.find('-') THEN
            repeat
                Direction := Direction + POSInfocodeEntry.Information;
            until POSInfocodeEntry.Next() = 0;

        //if WSTable."Order Type" in [WSTable."Order Type"::Takeaway, WSTable."Order Type"::FromStoreTakeaway] then begin
        Delstret.Reset();
        if Delstret.get('GENERICO OTROS', 1, '614') then begin
            DelCustAddr.Reset();
            DelCustAddr.SetRange("Address Type", DelCustAddr."Address Type"::Other);
            DelCustAddr.SetRange("Phone No.", wsTable."Sell-to Contact No.");
            if not DelCustAddr.FindFirst() then begin
                DelCustAddr.Init();
                DelCustAddr."Phone No." := wsTable."Sell-to Contact No.";
                DelCustAddr."Address Type" := DelCustAddr."Address Type"::Other
            end;


            DelCustAddr."Street Name" := Delstret."Street Name";
            DelCustAddr."FSN Street Name" := Delstret."Street Name";
            DelCustAddr."Post Code" := Delstret."Post Code";
            DelCustAddr."Restaurant No." := Delstret."Restaurant No.";
            DelCustAddr.Directions := CopyStr(Direction, 1, 100);
            DelCustAddr."FSN Direction" := CopyStr(Direction, 100, 250);
            ;
            FSNAlterKey := Delstret."FSN Alter Key";

            DelContac.Reset();
            if not DelContac.Get(wsTable."Sell-to Contact No.") then begin
                DelContac.Init();
                DelContac."No." := wsTable."Sell-to Contact No.";
            end;

            if NOT (WSTable."Order Type" IN [WSTable."Order Type"::Takeaway, WSTable."Order Type"::FromStoreTakeaway]) then begin
                POSInfocodeEntry.Reset();
                POSInfocodeEntry.SetRange(POSInfocodeEntry."Receipt No.", WSTable.LastSlipNo);
                POSInfocodeEntry.SetRange(POSInfocodeEntry.Infocode, 'ORDATETIME');
                POSInfocodeEntry.SetRange(POSInfocodeEntry."Line No.", 999);
                if POSInfocodeEntry.FindFirst() then
                    if Evaluate(OrderDateTime, POSInfocodeEntry.Information) then begin
                        OrderTime := DT2Time(OrderDateTime);
                        OrderDate := DT2Date(OrderDateTime);
                        DelContac."LSC Next Order Date" := OrderDate;
                        DelContac."LSC Next Order Time" := OrderTime;
                        DelContac."LSC Pre-Order Print DateTime" := OrderDateTime;
                    end;
            end;

            DelContac."Phone No." := wsTable."Sell-to Contact No.";
            DelContac.Name := wsTable."First Name" + ' ' + wsTable."Last Name";
            DelContac."Search Name" := wsTable."First Name";
            if not DelContac.Insert(true) then
                DelContac.Modify(true);

            if not DelCustAddr.Insert(true) then
                DelCustAddr.Modify(True);
        end;
        //end else
        //    StretNoEcommerce(WSTable, Direction, DelCustAddr, DelContac, FSNAlterKey);

        if not DelOrder.Get(WSTable.LastSlipNo) then begin
            DelOrder.Init;
            DelOrder."Order No." := WSTable.LastSlipNo;

        end;
        DelOrder."Restaurant No." := WSTable."Store Selected";
        DelOrder.Validate("General Status", DelOrder."General Status"::"In Process");
        DelOrder."Call Cent. Web Service Status" := DelOrder."Call Cent. Web Service Status"::"New-Not Confirmed";
        DelOrder."Phone No." := WSTable."Sell-to Contact No.";

        IF OrderDate <> 0D THEN begin
            DelOrder."Order Date" := DelContac."LSC Next Order Date";
            DelOrder."Contact Pickup Time" := DelContac."LSC Next Order Time";
            if DelContac."LSC Pre-Order Print DateTime" <> 0DT then begin
                DelOrder."Pre-Order Print DateTime" := DelContac."LSC Pre-Order Print DateTime";
                DelOrder."Pre-Order" := DelOrder."Pre-Order"::"On Hold";
            END;
        END ELSE begin
            DelOrder."Order Date" := TODAY;
            DelOrder."Contact Pickup Time" := WSTable.Time;
        end;


        if WSTable."Order Type" in [WSTable."Order Type"::Takeaway, WSTable."Order Type"::FromStoreTakeaway] then
            DelOrder.Validate("Order Type Option", 4)
        else
            DelOrder.Validate("Order Type Option", 3);
        DelOrder.Address := DelCustAddr."Street Name";
        DelOrder."Address 2" := DelCustAddr."Address 2";
        DelOrder.City := DelCustAddr.City;
        DelOrder."Created at Call Center" := 'F20';
        DelOrder."Post Code" := DelCustAddr."Post Code";
        DelOrder.Directions := DelCustAddr.Directions;
        DelOrder."Grid Code" := DelCustAddr."Grid Code";
        DelOrder."Date Created" := Today;
        DelOrder."Time Created" := WSTable.Time;
        if WSTable."Distribution Location" <> '' then
            DelOrder."Order Taker" := 'BOT'
        else
            DelOrder."Order Taker" := 'F20CC';
        DelOrder.Name := CopyStr(WSTable."First Name" + ' ' + WSTable."Last Name", 1, 100);
        DelOrder."Bill-to Name" := CopyStr(WSTable."First Name" + ' ' + WSTable."Last Name", 1, 100);
        /*if SalesTypes.Get(POSTransactionV."Sales Type") then
            DelOrder."Sales Type" := SalesTypes.Code;*/
        DelOrder."FSN Alter Key" := FSNAlterKey;
        DelOrder."FSN Directions" := DelCustAddr."FSN Direction";
        DelOrder."FSN Street Name" := DelCustAddr."Street Name";
        if not DelOrder.Insert(true) then
            DelOrder.Modify(true);

        Commit();
    end;

    procedure StretNoEcommerce(wsTable: Record "FSN WebServiceTable"; AddressText: text[250]; var DelCont: Record "LSC Delivery Contact Address"; var DelContac: Record Contact; var StreetKey: Integer)
    var
        myInt: Integer;
        storeLink: record "FSN Store Link";
        lat: Decimal;
        lon: Decimal;
        storeLink_tmp2: record "FSN Store Link" temporary;
        StoreLink2: Record "FSN Store Link";
        km: Decimal;
        Delstret: Record "LSC Delivery Street";
        km2: Decimal;
        store, store2 : Record "LSC Store";
        store_tmp, store_tmp2 : Record "LSC Store" temporary;
        OrderType: Option Home,Work,Other,Takeout;
        EcomMgt: Codeunit "FSN Ecommerce CallCenter Mgt.";
    begin
        if Evaluate(lat, CopyStr(wsTable."Value Text 1", 1, StrPos(wsTable."Value Text 1", ',') - 1))
            and
            Evaluate(lon, CopyStr(wsTable."Value Text 1", StrPos(wsTable."Value Text 1", ',') + 1, StrLen(wsTable."Value Text 1")))
                then begin

            StoreLink.Reset();
            storeLink.SetRange(Type, storeLink.Type::StoreSetup);
            storeLink.SetRange("Parent Code", wsTable."Store Selected");
            if storeLink.Find('-') then
                repeat
                    store_tmp2.Init();
                    store_tmp2."Fraud Sort Field" := EcomMgt.GetDistanceGeopraphic(
                        lat,
                        lon,
                        storeLink."Parent Latitude",
                        storeLink."Parent Longitude"
                    );
                    store_tmp2."No." := storeLink."Parent Code";
                    if store_tmp2."Fraud Sort Field" <= 5 then
                        if store_tmp2.Insert() then;
                until storeLink.Next() = 0;
            store_tmp2.Reset();
            store_tmp2.SetCurrentKey("Fraud Sort Field");
            if store_tmp2.Find('-') then;


            StoreLink2.Reset();
            StoreLink2.SetRange(Type, StoreLink2."Link Type"::NormalStore);
            StoreLink2.SetRange(Type, StoreLink2.Type::StreetAlterKey);//NEW
            StoreLink2.SetFilter("Km Distance Driver", '<>%1', 0);//NEW
            StoreLink2.SetRange("Store No.", wsTable."Store Selected");
            StoreLink2.SetFilter("Km Between Points", '<=%1', store_tmp2."Fraud Sort Field");
            if StoreLink2.Find('-') then
                repeat
                    IF CopyStr(StoreLink2."Parent Code Name", 1, 6) <> 'FASANI' then begin
                        store_tmp2.Init();
                        store_tmp2."Fraud Sort Field" := EcomMgt.GetDistanceGeopraphic(
                            lat,
                            lon,
                            StoreLink2."Parent Latitude",
                            StoreLink2."Parent Longitude"
                        );
                        store_tmp2."No." := StoreLink2."Parent Code";
                        if store_tmp2."Fraud Sort Field" <= 5 then
                            if store_tmp2.Insert() then;
                    END;
                until StoreLink2.Next() = 0;

            store_tmp2.Reset();
            store_tmp2.SetCurrentKey("Fraud Sort Field");
            if store_tmp2.Find('-') then;


            Delstret.Reset();
            Delstret.SetRange("FSN Alter Key Text", store_tmp2."No.");
            if Delstret.FindFirst() then begin
                DelCont.Reset();
                DelCont.SetRange("Address Type", DelCont."Address Type"::Other);
                DelCont.SetRange("Phone No.", wsTable."Sell-to Contact No.");
                if not DelCont.FindFirst() then begin
                    DelCont.Init();
                    DelCont."Phone No." := wsTable."Sell-to Contact No.";
                    DelCont."Address Type" := DelCont."Address Type"::Other
                end;


                DelCont."Street Name" := Delstret."Street Name";
                DelCont."FSN Street Name" := Delstret."Street Name";
                DelCont."Post Code" := Delstret."Post Code";
                DelCont."Restaurant No." := Delstret."Restaurant No.";
                DelCont.Directions := CopyStr(AddressText, 1, 100);
                DelCont."FSN Direction" := AddressText;
                DelCont.Latitude := Format(lat);
                DelCont.Longitude := Format(lon);
                StreetKey := Delstret."FSN Alter Key";

                DelContac.Reset();
                if not DelContac.Get(wsTable."Sell-to Contact No.") then begin
                    DelContac.Init();
                    DelContac."No." := wsTable."Sell-to Contact No.";
                end;

                DelContac.Name := wsTable."First Name" + ' ' + wsTable."Last Name";
                DelContac."Search Name" := wsTable."First Name";
                if not DelContac.Insert(true) then
                    DelContac.Modify(true);

                if not DelCont.Insert(true) then
                    DelCont.Modify(True);
            end;
        end;
    end;


    /////////////////// FIN PROCESO ECOMMERCE

    procedure UpdateTRansactionV(ReceiptTrans: Code[20])
    var
        WebServiceTable: Record "FSN WebServiceTable";
        POSTransLine: Record "LSC POS Trans. Line";
        POSTPeriodicType: Record "LSC POS Trans. Per. Disc. Type";
        POSTransInfocodeEntry: Record "LSC POS Trans. Infocode Entry";
        POSDataEntry: Record "LSC POS Data Entry";
        VoucherEntry: Record "LSC Voucher Entries";
        OffPosCalculation: Record "LSC Offer Pos Calculation";
        POSCardRequestEntry: Record "FSN POS Card Request Entry";
        POSCardEntry: Record "LSC POS Card Entry";
        TerminalAsig: Record "LSC CC POS Term. Assignm.";
        POSTransaction: Record "LSC POS Transaction";
        FsnTakeOrder: Page "FSN Take Order CC";
        DelOrder: Record "LSC Delivery Order";
        SalesType: Integer;
        onlineorder: boolean;
        ErrorText: text;
        DelCont: Record Contact;
    begin

        //UpdateReceiptOrder
        if WebServiceTable.get(ReceiptTrans) then begin
            if WebServiceTable."Store Selected" <> '' then begin

                TerminalAsig.Reset();
                IF TerminalAsig.Get(WebServiceTable.Store, WebServiceTable."Store Selected") THEN BEGIN

                    //POS Transaction.
                    /*if POSTransaction.Get(ReceiptTrans) then begin
                        POSTransaction."Store No." := TerminalAsig."Restaurant No.";
                        POSTransaction."POS Terminal No." := TerminalAsig."Rest. POS Terminal";
                        POSTransaction.Modify(true);
                    end;*/

                    CreateDelOrderDelivery(WebServiceTable, POSTransaction);

                    //POS Trans. Line.
                    POSTransLine.Reset();
                    POSTransLine.SetRange("Receipt No.", ReceiptTrans);
                    if POSTransLine.Find('-') then begin
                        repeat
                            POSTransLine."Store No." := TerminalAsig."Restaurant No.";
                            POSTransLine."POS Terminal No." := TerminalAsig."Rest. POS Terminal";
                            POSTransLine.Modify();
                        until POSTransLine.Next() = 0;
                    end;

                    //LSC POS Trans. Per. Disc. Type
                    POSTPeriodicType.Reset();
                    POSTPeriodicType.SetRange("Receipt No.", ReceiptTrans);
                    if POSTPeriodicType.Find('-') then begin
                        repeat
                            POSTPeriodicType."POS Terminal No." := TerminalAsig."Rest. POS Terminal";
                            POSTPeriodicType.Modify();
                        until POSTPeriodicType.Next() = 0;
                    end;

                    //LSC POS Trans. Infocode Entry
                    POSTransInfocodeEntry.Reset();
                    POSTransInfocodeEntry.SetRange(POSTransInfocodeEntry."Receipt No.", ReceiptTrans);
                    if POSTransInfocodeEntry.Find('-') then begin
                        repeat
                            POSTransInfocodeEntry."Store No." := TerminalAsig."Restaurant No.";
                            POSTransInfocodeEntry."POS Terminal No." := TerminalAsig."Rest. POS Terminal";
                            POSTransInfocodeEntry.Modify();
                        until POSTransInfocodeEntry.Next() = 0;
                    end;

                    //LSC POS Data Entry
                    POSDataEntry.Reset();
                    POSDataEntry.SetRange("Created by Receipt No.", ReceiptTrans);
                    if POSDataEntry.Find('-') then begin
                        repeat
                            POSDataEntry."Created in Store No." := TerminalAsig."Restaurant No.";
                            POSDataEntry.Modify();
                        until POSDataEntry.Next() = 0;
                    end;

                    //LSC Voucher Entries
                    VoucherEntry.Reset();
                    VoucherEntry.SetRange("Receipt Number", ReceiptTrans);
                    if VoucherEntry.Find('-') then begin
                        repeat
                            VoucherEntry."Store No." := TerminalAsig."Restaurant No.";
                            VoucherEntry."POS Terminal No." := TerminalAsig."Rest. POS Terminal";
                            VoucherEntry.Modify();
                        until VoucherEntry.Next() = 0;
                    end;

                    //FSN POS Card Request Entry
                    POSCardRequestEntry.Reset();
                    POSCardRequestEntry.SetRange("Receipt No.", ReceiptTrans);
                    if POSCardRequestEntry.Find('-') then begin
                        repeat
                            POSCardRequestEntry."Store No." := TerminalAsig."Restaurant No.";
                            POSCardRequestEntry.Modify();
                        until POSCardRequestEntry.Next() = 0;
                    end;

                    //LSC POS Card Entry
                    /*POSCardEntry.Reset();
                    POSCardEntry.SetRange("Receipt No.", ReceiptTrans);
                    if POSCardEntry.Find('-') then begin
                        repeat
                            POSCardEntry."Store No." := TerminalAsig."Restaurant No.";
                            POSCardEntry."POS Terminal No." := TerminalAsig."Rest. POS Terminal";
                            POSCardEntry.Modify();
                        until POSCardEntry.Next() = 0;
                    end;*/
                    Commit();

                    if DelOrder.get(ReceiptTrans) then begin
                        DelCont.Reset();
                        if not DelCont.get(DelOrder."Phone No.") then begin
                            DelCont.Init();
                            DelCont."No." := DelOrder."Phone No.";
                        end;
                        DelCont."LSC Next Order Selection" := DelOrder."Order Type Option";
                        DelCont."LSC Next Order Restaurant" := DelOrder."Restaurant No.";
                        DelCont."LSC Next Order Date" := DelOrder."Order Date";
                        DelCont."LSC Next Order Time" := DelOrder."Contact Pickup Time";
                        DelCont."LSC Next Delivery Tender" := DelOrder."Tender Type";
                        DelCont."LSC Pre-Order Print DateTime" := DelOrder."Pre-Order Print DateTime";
                        DelCont."LSC Next Estimated Prod. Time" := DelOrder."Estimated Prod. Time (Min.)";
                        if not DelCont.insert then
                            DelCont.Modify;

                        //message(ErrorText);
                    end;
                end;
            end;
        end;
    end;
    ////////

    procedure CreateDelOrderDelivery(WSTable: Record "FSN WebServiceTable"; POSTransactionV: Record "LSC POS Transaction")
    var
        DelOrder: Record "LSC Delivery Order";
        DelCustAddr: Record "LSC Delivery Contact Address";
        POSInfocodeEntry: Record "LSC POS Trans. Infocode Entry";
        BOUTIL: Codeunit "LSC BO Utils";
        DelStreet_l: Record "LSC Delivery Street";
        TypeText: text;
        TypeInt: integer;
        FSNAlterKey: Integer;
        SalesTypes: Record "LSC Sales Type";
    begin

        clear(TypeText);
        IF POSInfocodeEntry.GET(WSTable.LastSlipNo, 0, 888, 'TEXT', 0) THEN
            TypeText := BOUTIL.SeparateCombinedValue(2, POSInfocodeEntry.Information);//28981

        IF EVALUATE(TypeInt, TypeText) THEN begin
            IF DelCustAddr.GET(WSTable."Sell-to Contact No.", TypeInt) THEN BEGIN

                DelStreet_l.Reset();
                DelStreet_l.SetRange("Street Name", DelCustAddr."Street Name");//CopyStr(Rec.Address, 3, 30)
                DelStreet_l.SetRange("Number from", 1);
                if DelCustAddr."Post Code" <> '' then
                    DelStreet_l.SetRange("Post Code", DelCustAddr."Post Code");
                if DelStreet_l.FindFirst() then begin
                    FSNAlterKey := DelStreet_l."FSN Alter Key";
                    DelCustAddr."Street Name" := DelStreet_l."Street Name";
                    DelCustAddr.Modify();
                end;
                if not DelOrder.Get(WSTable.LastSlipNo) then begin
                    DelOrder.Init;
                    DelOrder."Order No." := WSTable.LastSlipNo;

                end;
                DelOrder."Restaurant No." := WSTable."Store Selected";
                DelOrder.Validate("General Status", DelOrder."General Status"::"In Process");
                DelOrder."Call Cent. Web Service Status" := DelOrder."Call Cent. Web Service Status"::"New-Not Confirmed";
                DelOrder."Phone No." := WSTable."Sell-to Contact No.";
                DelOrder."Order Date" := TODAY;
                DelOrder.Validate("Order Type Option", TypeInt);
                DelOrder.Address := DelCustAddr."Street Name";
                DelOrder."Address 2" := DelCustAddr."Address 2";
                DelOrder.City := DelCustAddr.City;
                DelOrder."Created at Call Center" := 'F20';
                DelOrder."Post Code" := DelCustAddr."Post Code";
                DelOrder.Directions := DelCustAddr.Directions;
                DelOrder."Grid Code" := DelCustAddr."Grid Code";
                if SalesTypes.Get(POSTransactionV."Sales Type") then
                    DelOrder."Sales Type" := SalesTypes.Code;
                DelOrder."FSN Alter Key" := FSNAlterKey;
                DelOrder."FSN Directions" := DelCustAddr."FSN Direction";
                DelOrder."FSN Street Name" := DelCustAddr."Street Name";
                if not DelOrder.Insert(true) then
                    DelOrder.Modify(true);

                Commit();
            END;
        end;
    end;



    /////////////////////////////////////FIN NUEVO PROCESO//////////////////////////////////////////////

    procedure InitRequest(var pReqXml: XmlDocument; pRequestID: Code[30]; var pRequestNodeList: array[3] of Text[50]; var pResponseNodeList: array[5] of Text[50]; var pParentNodeIndex: Integer; var pParentNodeList: array[5] of Text[50]; var pNode: XmlNode; var pProcessError: Boolean; var pErrorText: Text[1024]): Boolean
    begin
        //InitRequest

        IF NOT RequestSetupOk(pRequestID, pErrorText) THEN BEGIN
            pProcessError := TRUE;
            EXIT(FALSE);
        END;

        WSFunc.GetHeaderReqNodes(pRequestID, pRequestNodeList);
        WSFunc.GetHeaderResNodes(pRequestID, pResponseNodeList);

        WSFunc.CreateRequest(pReqXml, pRequestID, pRequestNodeList, pParentNodeIndex, pParentNodeList, pNode);

        EXIT(TRUE);
    end;

    local procedure RequestSetupOk(pRequestID: Text[30]; var pErrorText: Text[1024]): Boolean
    var
        lText001: Label 'Web service module is not active';
        lText002: Label 'Web request %1 not found';
        lText003: Label 'Web request %1 is not active';
    begin
        //RequestSetupOk

        IF NOT WebServiceSetup."Web Service is Active" THEN BEGIN
            pErrorText := lText001;
            EXIT(FALSE);
        END;

        IF NOT WSRequest.GET(pRequestID) THEN BEGIN
            pErrorText := STRSUBSTNO(lText002, pRequestID);
            EXIT(FALSE);
        END;

        IF NOT WSRequest."Web Request is Active" THEN BEGIN
            pErrorText := STRSUBSTNO(lText003, pRequestID);
            EXIT(FALSE);
        END;

        IF NOT WSFunc.XMLHeaderSetupOk(pRequestID, pErrorText) THEN
            EXIT(FALSE);

        EXIT(TRUE);
    end;

    local procedure SendRequest(pRequestID: Text[30]; var pxmlRequest: Text; var pxmlResponse: Text)
    var
        WebServerList: Record "LSC WS Server Buffer" temporary;
    begin
        //SendRequest
        GetWebServerList(pRequestID, WebServerList);

        WebServicesConn.SendRequest(pRequestID, WebServerList, pxmlRequest, pxmlResponse);
    end;

    local procedure GetWebServerList(pRequestID: Text[30]; var pWebServerList: Record "LSC WS Server Buffer" temporary)
    var
        FuncProfileWebServer: Record "LSC POS Func. Profile Web Serv";
        WebServerExt: Record "LSC Web Req. Type Server Ext." temporary;// "Web Request Type Server Ext." temporary;
        WSRequest: Record "LSC WS Request";
        ServerExt: Record "LSC Web Req. Type Server Ext.";//"Web Request Type Server Ext.";
        UseBase: Boolean;
        LineNo: Integer;
    begin
        //GetWebURIList
        LineNo := 0;
        IF PosFuncProfile."Profile ID" <> '' THEN BEGIN
            //LS7.1-15 -
            IF PosFuncProfile."Profile ID" = '##TESTCONN' THEN BEGIN //Internal key word.
                LineNo := LineNo + 1;
                pWebServerList.INIT;
                pWebServerList."Entry No." := LineNo;
                pWebServerList."Local Request" := FALSE;
                pWebServerList."Dist. Location" := PosFuncProfile."Online Trans. Backup";
                pWebServerList.INSERT;
            END ELSE BEGIN
                //LS7.1-15 -
                FuncProfileWebServer.RESET;
                FuncProfileWebServer.SETCURRENTKEY("Profile ID", "Request ID", Priority);
                FuncProfileWebServer.ASCENDING(FALSE);
                FuncProfileWebServer.SETRANGE("Profile ID", PosFuncProfile."Profile ID");
                FuncProfileWebServer.SETRANGE("Request ID", pRequestID);
                IF NOT FuncProfileWebServer.FIND('-') THEN
                    FuncProfileWebServer.SETRANGE("Request ID", '');
                IF FuncProfileWebServer.FIND('-') THEN
                    REPEAT
                        LineNo := LineNo + 1;
                        pWebServerList.INIT;
                        pWebServerList."Entry No." := LineNo;
                        pWebServerList."Local Request" := FuncProfileWebServer."Local Request";
                        pWebServerList."Dist. Location" := FuncProfileWebServer."Dist. Location";
                        pWebServerList.INSERT;
                    UNTIL FuncProfileWebServer.NEXT = 0;
            END; //LS7.1-15
        END ELSE BEGIN
            LineNo := LineNo + 1;
            pWebServerList.INIT;
            pWebServerList."Entry No." := LineNo;
            pWebServerList."Local Request" := webServiceSetup."Only Local Request";
            pWebServerList."Dist. Location" := '';
            pWebServerList.INSERT;
        END;
    end;

    procedure GetDistanceGeographic(pLat1: Decimal; pLong1: Decimal; pLat2: Decimal; pLong2: Decimal): Decimal
    var
        LS_NetMath: DotNet Math;
        PI: Decimal;
        lLat: Decimal;
        lLong: Decimal;
        DataDiff: Decimal;
    begin

        PI := 3.14159265358979323;
        lLat := (pLat1 - pLat2) * (PI / 180);
        lLong := (pLong1 - pLong2) * (PI / 180);
        pLat1 := pLat1 * (PI / 180);
        pLat2 := pLat2 * (PI / 180);

        DataDiff :=
          LS_NetMath.Pow(LS_NetMath.Sin(lLat / 2), 2) +
          LS_NetMath.Cos(pLat1) *
          LS_NetMath.Cos(pLat2) *
          LS_NetMath.Pow(LS_NetMath.Sin(lLong / 2), 2);

        DataDiff := 2 *
          LS_NetMath.Atan2(LS_NetMath.Sqrt(DataDiff), LS_NetMath.Sqrt(1 - DataDiff));

        DataDiff := DataDiff * 6378;
        DataDiff := ROUND(DataDiff, 0.01, '<');

        EXIT(DataDiff);
    end;

    /********************  EVENTS    **********************/

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC WS Request", 'OnBeforeWebRequestRun', '', true, true)]
    local procedure "WS Request_OnBeforeWebRequestRun"
    (
        RequestID: Text[30];
        var gxmlRequest: Text;
        var gxmlResponse: Text;
        var StopRun: Boolean
    )
    var
        Parameterfilter: Record "FSN Parameter";
    begin
        case RequestID of
            'SEND_POSTRANS_BACKUP_BC':
                begin
                    SendPosTransRequest(RequestID, gxmlRequest, gxmlResponse);
                    StopRun := true;
                end;

            'OFFLINECC_SENDORDER':
                begin
                    SendOfflineCCRequest(RequestID, gxmlRequest, gxmlResponse);
                    StopRun := true;
                end;
            'SEND_POSTRANS_BACKUP':
                begin
                    SendPosTransRequestEcommerce(RequestID, gxmlRequest, gxmlResponse);
                    StopRun := true;
                end;
        end
    end;

    local procedure SendOfflineCCRequest(pRequestID: Text[30]; var pxmlRequest: Text; var pxmlResponse: Text)
    var
        OffCallCenter: Record "LSC Offline Call Center";
        POSTransLineTmp: Record "LSC POS Trans. Line" temporary;
        POSTransTmp: Record "LSC POS Transaction" temporary;
        POSTrans: Record "LSC POS Transaction";
        DelOrderTmp: Record "LSC Delivery Order" temporary;
        DelOrder: Record "LSC Delivery Order";
        POSTransLine: Record "LSC POS Trans. Line";
        POStransHeader: Record "LSC POS Transaction";
        DelPosComm: Codeunit "LSC Delivery POS Commands";
        CCWebReq: Codeunit "LSC Offl. CC Web Serv. Req";
        ReqXml: XmlDocument;
        ResXml: XmlDocument;
        TopNode: XmlNode;
        BodyNode: XmlNode;
        RequestID: Text[30];
        RequestNodeList: array[3] of Text[50];
        ResponseNodeList: array[5] of Text[50];
        ParentNodeIndex: Integer;
        ParentNodeList: array[5] of Text[50];
        TableNodeList: Record "LSC WS Node Buffer" temporary;
        ReqNodeList: Record "LSC WS Node Buffer" temporary;
        Response_Code: Code[30];
        Response_Text: Text[1024];
        UpdateAction: Text[30];
        AddOnly: Boolean;
        RecRefTemp: array[32] of RecordRef;
        RecRef: RecordRef;
        FlowFieldBuffer: Record "LSC FlowField Buffer" temporary;
        UpdateFieldList: Record "Field" temporary;
        OrderNo: Code[20];
        CancelNewOrder: Boolean;
        WarningCode: Code[10];
        WarningText: Text;
        Text000: Label 'Request Node %1 not found in request';
        Text099: Label '%1;%2';
        Receipt: Text;
        ValEcommerceMgt: Codeunit "FSN Ecommerce CallCenter Mgt.";
        POSSESSION: Codeunit "LSC POS Session";
        ValStore: Code[10];
        ValTerminal: Code[10];
        ValCust: Record Customer;
    begin
        ValStore := '';
        ValTerminal := '';
        Receipt := '';
        //SendPOSTrans
        RequestID := pRequestID;
        Response_Code := '0000';
        Response_Text := '';

        //Process Request Doc
        WSFunc.GetHeaderReqNodes(RequestID, RequestNodeList);
        WSFunc.GetHeaderResNodes(RequestID, ResponseNodeList);

        reqxml := XmlDocument.create;
        XMLDomMgt.LoadXMLDocumentFromText(pxmlRequest, ReqXml);
        XMLDomMgt.FindNodeFromXMLDocumentRoot(reqxml, RequestNodeList[1], TopNode);

        ParentNodeIndex := 1;
        ParentNodeList[ParentNodeIndex] := RequestNodeList[3];
        if not XMLDomMgt.FindNode(TopNode, RequestNodeList[3], BodyNode) then begin
            Response_Code := '0020';
            Response_Text := StrSubstNo(Text000, RequestNodeList[3]);
        end;

        //Get List of request nodes
        if Response_Code = '0000' then
            WSFunc.AddChildNodeListText(RequestID, 0, ParentNodeIndex, ParentNodeList, 'Update_Action', '',
              ReqNodeList, Response_Code, Response_Text);
        if Response_Code = '0000' then
            WSFunc.GetChildNodeList(0, BodyNode, ReqNodeList, Response_Code, Response_Text);
        if Response_Code = '0000' then begin
            ReqNodeList.Reset;
            if ReqNodeList.FindSet() then
                repeat
                    if ReqNodeList.Source = 'Update_Action' then begin
                        UpdateAction := ReqNodeList."Text Value";
                        if not ((UpdateAction = 'Add') or (UpdateAction = 'Update-Add')) then begin
                            Response_Code := '0030';
                            Response_Text := StrSubstNo(Text001, ReqNodeList."Text Value", ReqNodeList."Node Name");
                        end;
                    end;
                until (ReqNodeList.Next = 0) or (Response_Code <> '0000');
        end;

        //Get Tables
        if Response_Code = '0000' then
            WSFunc.AddChildNodeTableList(RequestID, 0, ParentNodeIndex, ParentNodeList, 'LSC POS Transaction', TableNodeList,
              Response_Code, Response_Text);
        if Response_Code = '0000' then
            WSFunc.AddChildNodeTableList(RequestID, 0, ParentNodeIndex, ParentNodeList, 'LSC POS Trans. Line', TableNodeList,
              Response_Code, Response_Text);
        if Response_Code = '0000' then
            WSFunc.AddChildNodeTableList(RequestID, 0, ParentNodeIndex, ParentNodeList, 'LSC POS Trans. Per. Disc. Type', TableNodeList,
              Response_Code, Response_Text);
        if Response_Code = '0000' then
            WSFunc.AddChildNodeTableList(RequestID, 0, ParentNodeIndex, ParentNodeList, 'LSC POS Trans. Infocode Entry', TableNodeList,
              Response_Code, Response_Text);
        if Response_Code = '0000' then
            WSFunc.AddChildNodeTableList(RequestID, 0, ParentNodeIndex, ParentNodeList, 'LSC POS Data Entry', TableNodeList,
              Response_Code, Response_Text);
        if Response_Code = '0000' then
            WSFunc.AddChildNodeTableList(RequestID, 0, ParentNodeIndex, ParentNodeList, 'LSC Voucher Entries', TableNodeList,
              Response_Code, Response_Text);
        if Response_Code = '0000' then
            WSFunc.AddChildNodeTableList(RequestID, 0, ParentNodeIndex, ParentNodeList, 'LSC Offer Pos Calculation', TableNodeList,
              Response_Code, Response_Text);
        if Response_Code = '0000' then
            WSFunc.AddChildNodeTableList(RequestID, 0, ParentNodeIndex, ParentNodeList, 'LSC POS Mix & Match Entry', TableNodeList,
              Response_Code, Response_Text);
        if Response_Code = '0000' then
            WSFunc.AddChildNodeTableList(RequestID, 0, ParentNodeIndex, ParentNodeList, 'LSC POS Trans. InfoData Entry', TableNodeList,
              Response_Code, Response_Text);
        if Response_Code = '0000' then
            WSFunc.AddChildNodeTableList(RequestID, 0, ParentNodeIndex, ParentNodeList, 'LSC Delivery Order', TableNodeList,
              Response_Code, Response_Text);
        if Response_Code = '0000' then
            WSFunc.AddChildNodeTableList(RequestID, 0, ParentNodeIndex, ParentNodeList, 'Contact', TableNodeList,
              Response_Code, Response_Text);
        if Response_Code = '0000' then
            WSFunc.AddChildNodeTableList(RequestID, 0, ParentNodeIndex, ParentNodeList, 'Rlshp. Mgt. Comment Line', TableNodeList,
              Response_Code, Response_Text);
        if Response_Code = '0000' then
            WSFunc.AddChildNodeTableList(RequestID, 0, ParentNodeIndex, ParentNodeList, 'LSC Delivery Contact Address', TableNodeList,
              Response_Code, Response_Text);
        if Response_Code = '0000' then
            WSFunc.AddChildNodeTableList(RequestID, 0, ParentNodeIndex, ParentNodeList, 'LSC POS Card Entry', TableNodeList,
              Response_Code, Response_Text);

        if Response_Code = '0000' then begin
            TableNodeList.Reset;
            if TableNodeList.FindSet() then
                repeat
                    RecRefTemp[TableNodeList."Entry No."].Open(TableNodeList."Table No.", true);
                    WSFunc.GetTableChildNodes(RequestID, 0, BodyNode, ParentNodeIndex, ParentNodeList, TableNodeList.Source,
                      RecRefTemp[TableNodeList."Entry No."], FlowFieldBuffer, TableNodeList."Entry No.", UpdateFieldList,
                      Response_Code, Response_Text);
                until (TableNodeList.Next = 0) or (Response_Code <> '0000');
        end;


        if Response_Code <> '0000' then
            Error(StrSubstNo(Text099, Response_Code, Response_Text));

        //Process Request
        if UpdateAction = 'Add' then
            AddOnly := true
        else
            AddOnly := false;

        Clear(POSTransLineTmp);
        POSTransLineTmp.DeleteAll;
        Clear(POSTransTmp);
        POSTransTmp.DeleteAll();
        //Update Table
        if TableNodeList.FindSet() then
            repeat
                UpdateFieldList.SetRange(TableNo, TableNodeList."Entry No.");
                case TableNodeList."Table No." of
                    Database::"LSC POS Trans. Line":
                        begin
                            RecRef.GetTable(POSTransLineTmp);
                            WSFunc.UpdateTableByTempTable(AddOnly, RecRefTemp[TableNodeList."Entry No."], RecRef, 0, UpdateFieldList);
                            RecRef.GetTable(POSTransLineTmp);
                            //CCWebReq.DeletePOSTransLines;
                            POSTransLine.Reset();
                            POSTransLine.SetRange("Receipt No.", POSTransLineTmp."Receipt No.");
                            if POSTransLineTmp."Receipt No." <> '' then
                                POSTransLine.DeleteAll(true);
                            Commit;
                            SelectLatestVersion;
                            if POSTransLineTmp.FindSet() then
                                repeat
                                    if POSTransLineTmp."Entry Type" = POSTransLineTmp."Entry Type"::Item then begin
                                        POSTransLineTmp."FSN Additional Action" := POSTransLineTmp."FSN Additional Action"::ConfirmScann;
                                    end;
                                    CCWebReq.UpdatePOSTrLineAndSplit(POSTransLineTmp);
                                until POSTransLineTmp.Next = 0;
                            Commit;
                            CCWebReq.UpdatePOSTrLineShift;
                            RecRef.Close;
                            Commit;
                        end;
                    Database::"LSC Delivery Order":
                        begin
                            RecRef.GetTable(DelOrderTmp);
                            WSFunc.UpdateTableByTempTable(AddOnly, RecRefTemp[TableNodeList."Entry No."], RecRef, 0, UpdateFieldList);
                            RecRef.GetTable(DelOrderTmp);
                            if DelOrderTmp.FindSet() then
                                repeat
                                    if OffCallCenter.Get() and (DelOrderTmp."Created at Call Center" = '') then
                                        DelOrderTmp."Created at Call Center" := OffCallCenter."No.";
                                    CCWebReq.UpdateDeliveryOrder(DelOrderTmp, CancelNewOrder);
                                    OrderNo := DelOrderTmp."Order No.";
                                until DelOrderTmp.Next = 0;
                            RecRef.Close;
                            Commit;
                        end;
                    else begin
                        RecRef.Open(TableNodeList."Table No.");
                        WSFunc.UpdateTableByTempTable(AddOnly, RecRefTemp[TableNodeList."Entry No."], RecRef, 0, UpdateFieldList);
                        RecRef.Close;
                    end;
                end;
            until TableNodeList.Next = 0;

        if Response_Code = '0000' then begin
            TableNodeList.SETRANGE(TableNodeList."Table No.", DATABASE::"LSC POS Transaction");
            IF TableNodeList.FIND('-') THEN
                RecRef.GETTABLE(POSTransTmp);
            WSFunc.UpdateTableByTempTable(AddOnly, RecRefTemp[TableNodeList."Entry No."], RecRef, 0, UpdateFieldList);
            RecRef.GETTABLE(POSTransTmp);
            IF POSTransTmp.FIND('-') THEN
                REPEAT
                    Receipt := POSTransTmp."Receipt No.";
                    ValStore := POSTransTmp."Store No.";
                    ValTerminal := POSTransTmp."POS Terminal No.";
                    IF ValCust.GET(POSTransTmp."Customer No.") THEN begin
                        IF ValCust."Customer Disc. Group" <> POSTransTmp."Customer Disc. Group" THEN begin
                            ValCust."Customer Disc. Group" := POSTransTmp."Customer Disc. Group";
                            ValCust.Modify(true);
                        end;
                    end;
                UNTIL POSTransTmp.next() = 0;
        end;

        Commit;

        if CancelNewOrder then begin
            DelOrder.Get(OrderNo);
            DelPosComm.CancelOrder(DelOrder, false, true, WarningCode, WarningText);
        end;

        //Process Response Doc
        WSFunc.InitParentResNodeList(ResponseNodeList, ParentNodeIndex, ParentNodeList);
        WSFunc.CreateResponse(ResXml, RequestID, ResponseNodeList, BodyNode);

        pxmlResponse := XMLDomMgt.ReturnInnerTextfromXMLDocument(ResXml);
        //Valida que si el pedido esta en Trans. Header lo elimina.
        ValEcommerceMgt.ValOrderStatus(Receipt, ValStore, ValTerminal);
    end;


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnAfterTotalExecuted', '', true, true)]
    local procedure "LSC POS Transaction Events_OnAfterTotalExecuted"(var POSTransaction: Record "LSC POS Transaction")
    var
        ErrorText: Text;
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line" temporary;
        Processed: Boolean;
        MsgResult: text;
        FSNUtility: Codeunit "FSN Utility";
        LSCPosTransLine: Record "LSC POS Trans. Line";
    begin
        RequestID := 'FSNCC';
        Processed := false;
        FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
        If Processed then begin
            LSCPosTransLine.Reset();
            LSCPosTransLine.SetRange(LSCPosTransLine."Store No.", POSTransaction."Store No.");
            LSCPosTransLine.SetRange(LSCPosTransLine."POS Terminal No.", POSTransaction."POS Terminal No.");
            LSCPosTransLine.SetRange(LSCPosTransLine."Receipt No.", POSTransaction."Receipt No.");
            LSCPosTransLine.SetRange(LSCPosTransLine."Entry Status", LSCPosTransLine."Entry Status"::" ");
            LSCPosTransLine.SetRange(LSCPosTransLine."Entry Type", LSCPosTransLine."Entry Type"::Item);
            LSCPosTransLine.SetFilter(LSCPosTransLine.Number, '=%1|%2', 'A7436', 'A6454');
            if LSCPosTransLine.FindFirst() then begin
                if POSTransaction."Customer Disc. Group" <> 'VIP' then begin
                    POSTransaction."Customer Disc. Group" := 'VIP';
                    POSTransaction.Modify(true);
                    RecalcProcess(POSTransaction);
                end;
            END;
        END;
    end;

    procedure RecalcProcess(VAR POSTransactionTB: Record "LSC POS Transaction")
    var
        POSTransPerDisc: Record "LSC POS Trans. Per. Disc. Type";
        POSTransLine2: Record "LSC POS Trans. Line";
        OfferPOSCalc: Record "LSC Offer Pos Calculation";
        PosPriceUtil: Codeunit "LSC POS Price Utility";
        DT: Record "LSC POS Trans. Per. Disc. Type";
        POSPrepaymentUtil: Codeunit "LSC POS Prepayment Mgt.";
        lPrice: Decimal;
        lQty: Decimal;
        PromOnCustDiscGroup: Boolean;
        PosFunc: Codeunit "LSC POS Functions";
    begin
        //aplicar el cambio de precio
        ProcessCustomer(POSTransactionTB);
        POSTransactionTB.Get(POSTransactionTB."Receipt No.");
        POSTransPerDisc.Reset();
        POSTransPerDisc.SetCurrentKey(DiscType);
        POSTransPerDisc.SetRange(DiscType, POSTransPerDisc.DiscType::Customer);
        POSTransPerDisc.SetRange("Receipt No.", POSTransactionTB."Receipt No.");
        if POSTransPerDisc.Find('-') then begin
            repeat
                POSTransLine2.Get(POSTransPerDisc."Receipt No.", POSTransPerDisc."Line No.");
                PosPriceUtil.InsertTransDiscPercent(POSTransLine2, 0, POSTransPerDisc.DiscType::Customer.Asinteger(), '');
                POSTransLine2.CalcPrices;
                if not PosFuncProfile."Disable POS Prepayment" then
                    POSPrepaymentUtil.SetPosTransLinePrepaymentPct(POSTransLine2);
                POSTransLine2.Modify(true);
            until POSTransPerDisc.Next = 0;
        end;

        PosFunc.ChangeVATBusOnLine(POSTransactionTB);
        PromOnCustDiscGroup := PosPriceUtil.IsPromotionForCustDiscGroup(POSTransactionTB."Customer Disc. Group", POSTransactionTB);
        POSTransLine2.Reset();
        POSTransLine2.SetRange("Receipt No.", POSTransactionTB."Receipt No.");
        POSTransLine2.SetRange("Entry Type", POSTransLine2."Entry Type"::Item);
        if POSTransLine2.FinD('-') then
            repeat
                Clear(OfferPOSCalc);
                OfferPOSCalc.SetRange("Receipt No.", POSTransLine2."Receipt No.");
                OfferPOSCalc.SetRange("Trans. Line No.", POSTransLine2."Line No.");
                OfferPOSCalc.DeleteAll();
                PosPriceUtil.insertTransDiscPercent(POSTransLine2, 0, POSTransPerDisc.DiscType::"Periodic Disc.".Asinteger(), '');
                if PromOnCustDiscGroup then begin
                    lPrice := POSTransLine2.Price;
                    lQty := POSTransLine2.Quantity;
                    PosPriceUtil.insertTransDiscPercent(POSTransLine2, 0, DT.DiscType::"Periodic Disc.".Asinteger(), '');
                    POSTransLine2."Promotion No." := '';
                    POSTransLine2."Mix & Match Line No." := 0;
                    PosPriceUtil.insertTransDiscAmount(POSTransLine2, 0, DT.DiscType::"Periodic Disc.".Asinteger(), '');
                    if not POSTransLine2."Price Change" then
                        PosPriceUtil.CalcPrice(POSTransLine2, FALSE);
                    if (lPrice <> POSTransLine2.Price) then begin
                        POSTransLine2.Validate(Quantity, lQty);
                        POSTransLine2.Modify(true);
                    end;
                end;
                PosPriceUtil.initGlobals(POSTransLine2, TRUE);
                PosPriceUtil.FindPeriodicOffers(POSTransLine2);
                POSTransLine2.Modify(true);
            until POSTransLine2.NEXT = 0;

        PosPriceUtil.CalcPeriodicOnTotalPressed(POSTransactionTB);
        PosFunc.RecalcSlip(POSTransactionTB);
    end;

    procedure ProcessCustomer(REC: Record "LSC POS transaction")
    var
        OfferPosCalc: Record "LSC Offer Pos Calculation";
        PosMixMatchEntry: Record "LSC POS Mix & Match Entry";
        POSTransLine2: Record "LSC POS Trans. Line";
        DT: Record "LSC POS Trans. Per. Disc. Type";
        POSTransPerDisc: Record "LSC POS Trans. Per. Disc. Type";
        PosFunc: Codeunit "LSC POS Functions";
        PosOfferExt: Codeunit "LSC POS Offer Ext. Utility";
        PosPriceUtil: Codeunit "LSC POS Price Utility";
        LocalizationExt: Codeunit "LSC Retail Localization Ext.";
        PromOnCustDiscGroup: Boolean;
        lPrice: Decimal;
        lQty: Decimal;
        OfferType: Option "Periodic Disc.",Customer,InfoCode,Total,Line,Promotion,Deal,"Total Discount","Tender Type","Item Point","Line Discount";
    begin
        PromOnCustDiscGroup := PosPriceUtil.IsPromotionForCustDiscGroup(REC."Customer Disc. Group", REC);
        POSTransLine2.Reset;
        POSTransLine2.SetRange("Receipt No.", REC."Receipt No.");
        POSTransLine2.SetRange("Entry Type", POSTransLine2."Entry Type"::Item);
        if POSTransLine2.FindSet then
            repeat
                Clear(OfferPosCalc);
                OfferPosCalc.SetRange("Receipt No.", POSTransLine2."Receipt No.");
                OfferPosCalc.SetRange("Trans. Line No.", POSTransLine2."Line No.");
                OfferPosCalc.DeleteAll;
                if LocalizationExt.IsNALocalizationEnabled then begin
                    PosMixMatchEntry.SetRange("Receipt No.", POSTransLine2."Receipt No.");
                    PosMixMatchEntry.SetRange("Line No.", POSTransLine2."Line No.");
                    PosMixMatchEntry.DeleteAll;
                end;
                PosPriceUtil.InsertTransDiscPercent(POSTransLine2, 0, POSTransPerDisc.DiscType::"Periodic Disc.".AsInteger(), '');
                if PromOnCustDiscGroup then begin
                    lPrice := POSTransLine2.Price;
                    lQty := POSTransLine2.Quantity;
                    PosPriceUtil.InsertTransDiscPercent(POSTransLine2, 0, DT.DiscType::"Periodic Disc.".AsInteger(), '');
                    POSTransLine2."Promotion No." := '';
                    POSTransLine2."Mix & Match Line No." := 0;
                    PosPriceUtil.InsertTransDiscAmount(POSTransLine2, 0, DT.DiscType::"Periodic Disc.".AsInteger(), '');
                    if not POSTransLine2."Price Change" then
                        PosPriceUtil.CalcPrice(POSTransLine2, false);
                    if (lPrice <> POSTransLine2.Price) then begin
                        POSTransLine2.Validate(Quantity, lQty);
                        POSTransLine2.Modify(true);
                    end;
                end;
                PosFunc.ClearPosTransLineOffers(POSTransLine2);
                PosPriceUtil.InitGlobals(POSTransLine2, true);
                PosPriceUtil.FindPeriodicOffers(POSTransLine2);
                PosFunc.AddPosTransLineOffers(POSTransLine2);
                POSTransLine2.Modify(true);
            until POSTransLine2.Next = 0;
        PosPriceUtil.CalcPeriodicOnTotalPressed(REC);
        PosFunc.RecalcSlip(REC);
        PosOfferExt.ReCalcOfferSeq(REC, OfferType::"Total Discount");
    end;
}


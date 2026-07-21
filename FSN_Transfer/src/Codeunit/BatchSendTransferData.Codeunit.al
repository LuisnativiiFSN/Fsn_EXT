codeunit 50002 "FSN Batch - Send Transfer Data"
{
    trigger OnRun()
    begin

        SendTransferData;
        LockFasaniPurchaseSetup;
    end;

    var
        TransferOrder: Record "Transfer Header";
        fsnParameter: Record "FSN Parameter";
        api: Codeunit "DTE API Connection";

    // p: Page 5768;

    //Lanza pedido creado desde solicitud Stock
    [EventSubscriber(ObjectType::Table, Database::"LSC InStore Stock Req. Header", 'OnAfterModifyEvent', '', true, true)]
    local procedure "LSC InStore Stock Req. Header_OnAfterModifyEvent"
    (
        var Rec: Record "LSC InStore Stock Req. Header";
        var xRec: Record "LSC InStore Stock Req. Header";
        RunTrigger: Boolean
    )
    var
        xPurchaseHeader: Record "Purchase Header";
        ReleasePurchDoc: codeunit "Release Purchase Document";

    begin
        if (Rec.Status = Rec.Status::Closed) and (Rec."Req. Status" = Rec."Req. Status"::Accepted)
        and (Rec."Reference Type" = Rec."Reference Type"::Purchase) and (Rec."Reference No." <> '') then
            if xPurchaseHeader.get(xPurchaseHeader."Document Type"::Order, Rec."Reference No.") then begin
                if xPurchaseHeader.Status = xPurchaseHeader.Status::Open then
                    ReleasePurchDoc.PerformManualRelease(xPurchaseHeader);
            end;
    end;

    procedure SendTransferData()
    var
        Location_l: Record "Location";
        TransferHeader_l, TransferHeader_2 : Record "Transfer Header";
        ExternalData_l: Record "PITS_WMScd2suc";
    begin
        //WVILLALTA02ABR19 New function
        Location_l.RESET;
        Location_l.SETRANGE(Location_l."Require Receive", TRUE);
        Location_l.SETRANGE(Location_l."Require Shipment", TRUE);
        Location_l.SETRANGE(Location_l."LSC Location is a Warehouse", TRUE); //need CD only?
        IF Location_l.FINDFIRST THEN
            REPEAT
                TransferHeader_l.RESET;
                TransferHeader_l.SETRANGE(TransferHeader_l.Status, TransferHeader_l.Status::Released);
                TransferHeader_l.SETRANGE(TransferHeader_l."Transfer-from Code", Location_l.Code);
                IF TransferHeader_l.FINDSET THEN
                    REPEAT
                        /*if TransferHeader_l."No." = 'HO790949' then
                            DellExternal(TransferHeader_l);-*/
                        ExternalData_l.RESET;
                        ExternalData_l.SETCURRENTKEY("Source No.", "Item No.");
                        ExternalData_l.SETRANGE(ExternalData_l."Source No.", TransferHeader_l."No.");
                        IF NOT ExternalData_l.FINDFIRST THEN begin
                            SendLines(TransferHeader_l);
                        end;
                    UNTIL TransferHeader_l.NEXT = 0;
            UNTIL Location_l.NEXT = 0;
    end;

    //JH09092024 AplicandoAutomatico
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Release Transfer Document", 'OnAfterReleaseTransferDoc', '', true, true)]
    local procedure "Release Transfer Document_OnAfterReleaseTransferDoc"(var TransferHeader: Record "Transfer Header")
    begin
        SendTransferDataAutomatic(TransferHeader);
    end;

    procedure SendTransferDataAutomatic(transferH: Record "Transfer Header")
    var
        Location_l: Record "Location";
        ExternalData_l: Record "PITS_WMScd2suc";
        TransferHeader_l: Record "Transfer Header";
    begin

        Location_l.RESET;
        Location_l.SETRANGE(Location_l."Require Receive", TRUE);
        Location_l.SETRANGE(Location_l."Require Shipment", TRUE);
        Location_l.SetRange("Code", transferH."Transfer-from Code");
        Location_l.SETRANGE(Location_l."LSC Location is a Warehouse", TRUE); //need CD only?
        IF Location_l.FINDFIRST THEN begin
            ExternalData_l.RESET;
            ExternalData_l.SETCURRENTKEY("Source No.", "Item No.");
            ExternalData_l.SETRANGE(ExternalData_l."No.", transferH."No.");
            IF NOT ExternalData_l.FINDFIRST THEN
                SendLines(transferH);
        end;
    end;

    //JH09092024

    procedure SendLines(pTransferHeader: Record "Transfer Header")
    var
        ExternalTransferLine_l: Record "PITS_WMScd2suc";
        TransferLine_l: Record "Transfer Line";
        Item_l: Record "Item";
        ExtMgr: Codeunit "FSN External Transfer Manager";
        PreferredFromCode: Code[10];
    begin

        // Decide Transfer-from Code based on LICITACION attribute presence across the order
        PreferredFromCode := ExtMgr.GetPreferredTransferFromCode(pTransferHeader);

        TransferLine_l.RESET;
        TransferLine_l.SETRANGE(TransferLine_l."Document No.", pTransferHeader."No.");
        TransferLine_l.SETRANGE("Derived From Line No.", 0);
        IF TransferLine_l.FINDSET THEN
            REPEAT
                ExternalTransferLine_l.INIT;
                ExternalTransferLine_l."No." := TransferLine_l."Document No.";
                ExternalTransferLine_l."Line No." := TransferLine_l."Line No.";
                ExternalTransferLine_l."Starting Date" := TODAY;
                ExternalTransferLine_l."Ending Date" := 0D;
                ExternalTransferLine_l."Transfer-from Code" := PreferredFromCode;
                ExternalTransferLine_l."Transfer-to Code" := pTransferHeader."Transfer-to Code";
                ExternalTransferLine_l."Source No." := pTransferHeader."No.";
                IF Item_l.GET(TransferLine_l."Item No.") THEN BEGIN
                    ExternalTransferLine_l.Costo_NAV := Item_l."Unit Cost";
                    ExternalTransferLine_l."Barcode No." := Item_l."FSN Barcode No.";
                    ExternalTransferLine_l."Shelf No." := Item_l."FSN Warehouse Level";
                    ExternalTransferLine_l.Puesto := Item_l."FSN Showcase No.";
                END;
                ExternalTransferLine_l."Item No." := TransferLine_l."Item No.";
                ExternalTransferLine_l.Description := TransferLine_l.Description;
                ExternalTransferLine_l.Quantity := TransferLine_l.Quantity;
                ExternalTransferLine_l."Unit of Measure" := TransferLine_l."Unit of Measure Code";
                ExternalTransferLine_l."Consolidated From No." := pTransferHeader."FSN Consolidate No.";
                ExternalTransferLine_l.Rapidito := pTransferHeader."FSN Consolidate No." = '';
                IF ExternalTransferLine_l.INSERT(TRUE) THEN;
            UNTIL TransferLine_l.NEXT = 0;

        CreateHeaders(pTransferHeader."No.", pTransferHeader."FSN Consolidate No." = '');
    end;


    procedure CreateHeaders(OrderNo: Code[20]; Rapidito: Boolean)
    var
        ExternalDateLines: Record "PITS_WMScd2suc";
        ExternalHeaders: Record "PITS_WMScd2sucHeaders";
        i: Integer;
        LevelArray: array[100, 2] of Integer;
        NumberInArray: Integer;
        LengthArray: Integer;
    begin
        //WVILLALTA02ABR19 New function

        FOR i := 0 TO 10 DO BEGIN
            ExternalDateLines.RESET;
            ExternalDateLines.SETCURRENTKEY("Source No.", "Shelf No.");
            ExternalDateLines.SETRANGE(ExternalDateLines."No.", OrderNo);
            IF i = 0 THEN
                ExternalDateLines.SETFILTER(ExternalDateLines."Shelf No.", '%1|%2', '', '0')
            ELSE
                ExternalDateLines.SETRANGE(ExternalDateLines."Shelf No.", FORMAT(i));
            IF ExternalDateLines.COUNT > 0 THEN BEGIN
                ExternalHeaders.INIT;
                ExternalHeaders.No_ := OrderNo;
                ExternalHeaders."Source No_" := OrderNo;
                ExternalHeaders.Nivel := i;
                ExternalHeaders.Rapidito := Rapidito;
                ExternalHeaders."Starting Date" := TODAY;
                ExternalHeaders."Ending Date" := 0D;
                ExternalHeaders."Hora Creado" := CURRENTDATETIME;
                ExternalHeaders.Lineas := ExternalDateLines.COUNT;
                IF NOT ExternalHeaders.INSERT(TRUE) THEN
                    IF NOT ExternalHeaders.MODIFY(TRUE) THEN;
            END;
        END;
    end;


    procedure LockFasaniPurchaseSetup()
    var
        purchSetup: Record "FSN Fasani Setup";
    begin
        purchSetup.SETFILTER(purchSetup."Next Datetime Lock", '<=%1', CURRENTDATETIME);
        IF purchSetup.FINDSET(TRUE, FALSE) THEN BEGIN
            REPEAT
                purchSetup."Use Check Transfer" := TRUE;
                purchSetup."Exchange Block/Auth." := TRUE;
                purchSetup."Exchange Block/Request" := TRUE;
                purchSetup.MODIFY;
            UNTIL purchSetup.NEXT = 0;

        END;
    end;

    local procedure sendDTE(var TransferHeader: Record "Transfer Header"; production: Boolean)
    var
        toStore, fromStore : Record "LSC Store";
        fromTerminal: Record "LSC POS Terminal";
        dte: Record "FSN DTE Transaction Header";
        utility: Codeunit "FSN Utility";
        toresponsability, fromresponsability : Record "Responsibility Center";
        json, seller, buyer, taxInfo, address, product, totals, discounts, adendaItem, response : JsonObject;
        productList, adenda : JsonArray;
        jvalue: JsonValue;
        transferLines: Record "Transfer Line";
        series: Codeunit NoSeriesManagement;
        nextSerie: Code[35];
        item: Record Item;
        uom_item: Record "Item Unit of Measure";
        totalCost, unitCost, totalLine : Decimal;
        OD: Codeunit "FSN OData Conexion";
        e, return : Boolean;
        posMenu: Record "LSC POS Menu Line";
        codeMH, codeNameMH : Text[10];
        dteAuth, dteSign : Text[50];
        noText: Text[75];
        txtDollars: Text;
        requestHeader, contentHeader : HttpHeaders;
        request: HttpRequestMessage;
        body: HttpContent;
        content, uri : Text;
        parameter: Record "FSN Parameter";
    begin
        Clear(e);

        if StrLen(TransferHeader."No.") > 10 then begin
            if dte.Get(CopyStr(TransferHeader."No.", 1, 10), CopyStr(TransferHeader."No.", 11, 10), 0) then begin
                if dte."DTE Invoice" <> TransferHeader."External Document No." then begin
                    TransferHeader."External Document No." := dte."DTE Invoice";
                    TransferHeader.Modify();
                end;
                e := true;
                if dte."DTE AuthNumber" <> '' then
                    exit;
            end;
        end else
            if dte.Get(TransferHeader."No.", '1', 0) then begin
                if dte."DTE Invoice" <> TransferHeader."External Document No." then begin
                    TransferHeader."External Document No." := dte."DTE Invoice";
                    TransferHeader.Modify();
                end;
                e := true;
                if dte."DTE AuthNumber" <> '' then
                    exit;
            end;

        //? filtrar los datos a usar en el DTE
        fromStore.Get(TransferHeader."LSC Store-from");
        toStore.Get(TransferHeader."LSC Store-to");
        fromTerminal.SetRange("Store No.", fromStore."No.");
        fromTerminal.SetRange("Menu Profile", '#FSNSLAVE');
        fromTerminal.FindFirst();
        fromresponsability.Get(fromStore."Responsibility Center");
        toresponsability.Get(toStore."Responsibility Center");

        //? verificar si es produccion o no
        if not production then exit;

        Commit();

        //? verificar si es sala de diferencia para ajuste
        if fromStore."No." = 'DIFERENCIA' then
            codeNameMH := 'AUX1'
        else
            codeNameMH := fromStore."DTE CodeEstablishment";
        codeMH := fromStore."DTE CodeEstablishmentMH";

        //! jvalue = NULL
        jvalue.SetValueToNull();

        //? llenar informacion general del json
        json.Add('DocumentType', '04');
        json.Add('OperationType', '01');
        json.Add('IssuedDate', Format(Today(), 10, 9));
        json.Add('IssuedTime', Format(Time(), 9));
        json.Add('IdShop', fromStore."No.");
        json.Add('Secuencial', jvalue);
        json.Add('TransNo', nextSerie);
        json.Add('PrintTicket', false);
        json.Add('Contingency', jvalue);

        //? agregar a sala de envio
        seller.Add('Name', 'Farmacia San Nicolas S.A. de C.V.');
        seller.Add('NRC', '406-5');
        seller.Add('NIT', '0614-221265-001-4');
        seller.Add('CodeSellingPoint', fromTerminal."DTE CodeSellingPointMH");
        seller.Add('CodeSellingPointMH', fromTerminal."DTE CodeSellingPointMH");
        seller.Add('TypeEstablishment', '01');
        seller.Add('CodeEstablishment', codeNameMH);
        seller.Add('CodeEstablishmentMH', codeMH);
        seller.Add('Phone', '2555-5555');
        seller.Add('Email', fromresponsability."E-Mail");
        seller.Add('ActivityCode', '46491');
        seller.Add('ActivityDesc', '"Venta al por mayor de productos medicinales, cosméticos, perfumería y productos de limpieza');

        //? agregar direccion de sala de envio
        Clear(address);
        address.Add('AddressLine', fromStore.Address);
        address.Add('District', '05');
        address.Add('State', '01');

        //? concatenar json
        seller.Add('Address', address);
        json.Add('Seller', seller);

        //? agregar sala de recepcion
        buyer.Add('NRC', '406-5');

        //? documento de sala de recepcion
        taxInfo.Add('ID', '36');
        taxInfo.Add('Value', '0614-221265-001-4');
        buyer.Add('TaxInformation', taxInfo);

        buyer.Add('ActivityCode', '46491');
        buyer.Add('ActivityDesc', 'Venta al por mayor de productos medicinales, cosméticos, perfumería y productos de limpieza');
        buyer.Add('Name', 'Farmacia San Nicolas S.A. de C.V.');
        buyer.Add('ComercialName', toStore.Name);
        buyer.Add('Phone', '22253733');
        buyer.Add('Email', toresponsability."E-Mail");

        //? agregar direccion de sala de recepcion
        Clear(address);
        address.Add('AddressLine', toStore.Address);
        address.Add('District', '05');
        address.Add('State', '01');

        //? concatenar json
        buyer.Add('Address', address);
        buyer.Add('BienTitulo', '04');
        json.Add('Buyer', buyer);

        //? agregar lineas
        transferLines.SetRange("Document No.", TransferHeader."No.");
        transferLines.SetRange("Derived From Line No.", 0);
        transferLines.SetFilter(Quantity, '>0');
        transferLines.FindSet();
        repeat
            Clear(product);

            totalLine := Round(transferLines.Quantity * unitCost, 0.01);
            totalCost += totalLine;
            unitCost := Round(totalLine / transferLines.Quantity, 0.00001);

            //? agregar informacion de producto
            product.Add('Code', transferLines."Item No.");
            product.Add('Description', DelChr(transferLines.Description, '=', '"'));
            product.Add('UnitOfMeasure', '59');
            product.Add('ProductType', '1');
            product.Add('Quantity', transferLines.Quantity);
            product.Add('SuggestedSalePrice', '0.00');
            product.Add('Discount', '0.00');
            product.Add('NO_GRAVADO', '0.00');
            product.Add('VENTA_NO_SUJETA', '0.00');
            product.Add('VENTA_EXENTA', '0.00');
            product.Add('VENTA_GRAVADA', DelChr(Format(totalLine), '=', ','));
            product.Add('Total', DelChr(Format(totalLine), '=', ','));
            product.Add('UnitPrice', DelChr(Format(unitCost), '=', ','));
            product.Add('Document', jvalue);

            productList.Add(product);
        until transferLines.Next() = 0;

        txtDollars := utility.Num2Text(Round(totalCost + (totalCost * 0.13), 0.01));

        json.Add('ProductList', productList);
        json.Add('PaymentList', jvalue);

        //? agregar totales
        totals.Add('SubTotal', DelChr(Format(totalCost), '=', ','));
        totals.Add('TOTAL_NO_GRAVADO', '0.00');
        totals.Add('TOTAL_NO_SUJETA', '0.00');
        discounts.Add('Exento', '0.00');
        discounts.Add('Gravado', '0.00');
        totals.Add('Discounts', discounts);
        totals.Add('TOTAL_EXENTO', '0.00');
        totals.Add('TOTAL_GRAVADO', DelChr(Format(totalCost), '=', ','));
        totals.Add('IVA', Format(Round(totalCost * 0.13, 0.01)));
        totals.Add('ivaPercibido', '0.00');
        totals.Add('ivaRetenido', '0.00');
        totals.Add('RetencionRenta', '0.00');
        totals.Add('InWords', txtDollars);
        totals.Add('Amount', DelChr(Format(Round((totalCost + (totalCost * 0.13)), 0.01)), '=', ','));
        json.Add('Totals', totals);

        //? agregar adenda
        adendaItem.Add('Name', 'SucDestino');
        adendaItem.Add('data', 'SucDestino');
        adendaItem.Add('value', StrSubstNo('%1 %2', toStore.Name, TransferHeader."No."));
        adenda.Add(adendaItem);
        json.Add('Adenda', adenda);

        //? enviar json a API de DTE
        if not getParamsMaster() then
            Error('No se encontraron parametros para el envio de DTE');

        uri := parameter."Web Uri" + 'GenerateInvoice';
        json.WriteTo(content);
        body.WriteFrom(content);

        body.GetHeaders(contentHeader);
        contentHeader.Clear();
        contentHeader.Add('Content-Type', 'application/json');

        request.GetHeaders(requestHeader);
        requestHeader.Clear();
        request.Content := body;
        requestHeader.Add('Authorization', 'Bearer ' + getCredentials());

        response := api.Post(uri, request);
        saveDTE(json, response, TransferHeader);
    end;

    local procedure getCredentials(): Text
    var
        requestObject, jObject : JsonObject;
        jToken: JsonToken;
        date: Date;
        posSession: Codeunit "LSC POS Session";
        PASSWORD: Label 'Pa$$w0rd';
        fulljson: Text;
        uri, content, date_txt : Text;
        headers: HttpHeaders;
        body: HttpContent;
        request: HttpRequestMessage;
    begin
        if fsnParameter."String Parameters 1 Json" <> '' then begin
            fulljson := fsnParameter."String Parameters 1 Json" + fsnParameter."String Parameters 2 Json";
            jObject.ReadFrom(fulljson);
        end;
        if jObject.SelectToken('expirationDate', jToken) then begin
            date_txt := jToken.AsValue().AsText();
            Evaluate(date, date_txt);
            if Today() < date then begin
                jObject.SelectToken('token', jToken);
                exit(jToken.AsValue().AsText());
            end;
        end;

        requestObject.Add('username', posSession.StoreNo());
        requestObject.Add('password', PASSWORD);

        uri := fsnParameter."Web Uri" + 'GetCredentials';
        requestObject.WriteTo(content);
        body.WriteFrom(content);
        body.GetHeaders(headers);
        headers.Clear();
        headers.Add('Content-Type', 'application/json');
        request.Content := body;

        jObject := api.Post(uri, request);

        if jObject.SelectToken('status', jToken) and (jToken.AsValue().AsInteger() <> 200) then
            Error('Error al obtener las credenciales del servicio web');

        jObject.Get('body', jToken);
        jToken.AsObject().WriteTo(fulljson);
        fsnParameter."String Parameters 1 Json" := CopyStr(fulljson, 1, 250);
        fsnParameter."String Parameters 2 Json" := CopyStr(fulljson, 251, 250);
        fsnParameter.Modify();
        Commit();
        jObject := jToken.AsObject();
        jObject.Get('token', jToken);

        exit(jToken.AsValue().AsText());
    end;

    local procedure getParamsMaster(): Boolean
    var
        lscRetailUser: Record "LSC Retail User";
    begin
        if not lscRetailUser.Get('FASANI\LSADMIN') then
            exit(false);

        fsnParameter.SetCurrentKey(Grupo, Codigo);
        fsnParameter.SetRange(Grupo, 'DTE_INVOICE');
        fsnParameter.SetRange(Codigo, lscRetailUser."POS Terminal");
        fsnParameter.SetRange(valor, 'WS');
        if not fsnParameter.FindFirst() then
            exit(false);

        exit(fsnParameter.Activo);
    end;

    local procedure saveDTE(request: JsonObject; response: JsonObject; var TransferHeader: Record "Transfer Header")
    var
        dteTransaction: Record "FSN DTE Transaction Header";
        jToken: JsonToken;
        jObject: JsonObject;
    begin
        if response.SelectToken('status', JToken) then;
        if jToken.AsValue().AsInteger() <> 200 then
            Error('Error al enviar el DTE');

        response.Get('body', jToken);
        jObject := jToken.AsObject();

        if jObject.SelectToken('authNumber', jToken) then
            dteTransaction."DTE AuthNumber" := jToken.AsValue().AsText();

        if jObject.SelectToken('issuedTimeStamp', jToken) then
            dteTransaction."DTE IssuedTimeStamp" := jToken.AsValue().AsText();

        if jObject.SelectToken('enrolledTimeStamp', jToken) then
            dteTransaction."DTE EnrolledTimeStamp" := jToken.AsValue().AsText();

        if jObject.SelectToken('dtEinvoice', jToken) then
            dteTransaction."DTE Invoice" := jToken.AsValue().AsText();

        if jObject.SelectToken('ticketType', jtoken) then
            dteTransaction."Document Type" := jToken.AsValue().AsText();

        if jObject.SelectToken('selloRecepcion', jtoken) then
            dteTransaction."Signature Validation" := jtoken.AsValue().AsText();

        if StrLen(TransferHeader."No.") > 10 then begin
            dteTransaction."Store No." := CopyStr(TransferHeader."No.", 1, 10);
            dteTransaction."POS Terminal No." := CopyStr(TransferHeader."No.", 11, 10);
        end else begin
            dteTransaction."Store No." := TransferHeader."No.";
            dteTransaction."POS Terminal No." := '1';
        end;

        dteTransaction."Transaction No." := 0;
        if jObject.SelectToken('generationDate', jToken) then
            dteTransaction."Creating Date" := jToken.AsValue().AsDate();

        TransferHeader."External Document No." := dteTransaction."DTE Invoice";
        TransferHeader.Modify();

        if not dteTransaction.INSERT() then
            if not dteTransaction.MODIFY() then
                Error('Error al guardar el DTE');
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"TransferOrder-Post Shipment", 'OnBeforeInsertTransShptLine', '', true, true)]
    local procedure "TransferOrder-Post Shipment_OnBeforeInsertTransShptLine"
    (
        var TransShptLine: Record "Transfer Shipment Line";
        TransLine: Record "Transfer Line";
        CommitIsSuppressed: Boolean;
        var IsHandled: Boolean
    )
    begin
        if TransShptLine.Quantity = 0 then
            IsHandled := true;
    end;


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"TransferOrder-Post Receipt", 'OnBeforeInsertTransRcptLine', '', true, true)]
    local procedure "TransferOrder-Post Receipt_OnBeforeInsertTransRcptLine"
    (
        var TransRcptLine: Record "Transfer Receipt Line";
        TransLine: Record "Transfer Line";
        CommitIsSuppressed: Boolean;
        var IsHandled: Boolean
    )
    var
        TransLine2: Record "Transfer Line";
    begin
        TransLine2.SetRange("Document No.", TransLine."Document No.");
        TransLine2.SetRange("Derived From Line No.", TransLine."Line No.");
        if TransLine2.Find('-') then begin
            if TransLine2."Qty. to Receive" <> TransLine."Qty. to Receive" then begin
                TransLine2."Qty. to Receive" := TransLine."Qty. to Receive";
                TransLine2."Qty. to Receive (Base)" := TransLine."Qty. to Receive (Base)";
                TransLine2.Modify(true);
            end;
        end;

        if TransRcptLine.Quantity = 0 then
            IsHandled := true;
    end;

    [EventSubscriber(ObjectType::Table, Database::"LSC InStore Stock Req. Line", 'OnBeforeInsertEvent', '', true, true)]
    local procedure "LSC InStore Stock Req. Line_OnBeforeInsertEvent"
    (
        var Rec: Record "LSC InStore Stock Req. Line";
        RunTrigger: Boolean
    )
    var
        Barcodes2: Record "LSC Barcodes";
        Item2: Record Item;
    begin
        if (Rec."Item No." <> '') and Item2.Get(Rec."Item No.") then begin
            Rec."FSN Attrib 1 Code" := Item2."LSC Attrib 1 Code";

            if (rec."FSN Barcode No." = '') or (Rec."Unit of Measure Code" = '') then begin
                Rec."FSN Attrib 1 Code" := Item2."LSC Attrib 1 Code";

                Barcodes2.Reset();
                Barcodes2.SetRange("Item No.", Rec."Item No.");
                Barcodes2.SetRange("Unit of Measure Code", Item2."Purch. Unit of Measure");
                if Barcodes2.FindFirst() then begin
                    Rec.Validate("Unit of Measure Code", Barcodes2."Unit of Measure Code");
                    Rec."FSN Barcode No." := Barcodes2."Barcode No.";
                end;
            end;
        end;
    end;


    [EventSubscriber(ObjectType::Table, Database::"Transfer Line", 'OnBeforeInsertEvent', '', true, true)]
    local procedure "Transfer Line_OnBeforeInsertEvent"
    (
        var Rec: Record "Transfer Line";
        RunTrigger: Boolean
    )
    var
        Barcodes2: Record "LSC Barcodes";
        Item2: Record Item;
        TransferHeader: Record "Transfer Header";
    begin

        if Rec."Derived From Line No." <> 0 then
            exit;

        if (Rec."Item No." <> '') and Item2.Get(Rec."Item No.") then begin
            Rec."FSN Attrib 1 Code" := Item2."LSC Attrib 1 Code";

            if (rec."FSN Barcode No." = '') or (Rec."Unit of Measure Code" = '') then begin
                Rec."FSN Attrib 1 Code" := Item2."LSC Attrib 1 Code";

                if TransferHeader.Get(Rec."Document No.") then
                    Rec."In-Transit Code" := TransferHeader."In-Transit Code";


                if TransferHeader."LSC Created By Source Code" <> '' then begin
                    Barcodes2.Reset();
                    Barcodes2.SetRange("Item No.", Rec."Item No.");
                    Barcodes2.SetRange("Unit of Measure Code", Item2."Purch. Unit of Measure");
                    if Barcodes2.FindFirst() then begin
                        Rec.Validate("Unit of Measure Code", Barcodes2."Unit of Measure Code");//28981
                        Rec."FSN Barcode No." := Barcodes2."Barcode No.";
                    end;
                end

            end;
        end;
    end;

    //Valida codigo de barra ingresado,se valida si se agrega el producto que tome unidad de medida Purch. Unit of Measure y filtre codifo de barra
    [EventSubscriber(ObjectType::Page, Page::"LSC Retail TO. tb. Picked Sub.", 'OnBeforeValidateEvent', 'Item No.', true, true)]
    local procedure "LSC Retail TO. tb. Picked Sub._OnBeforeValidateEvent_[content / Control1] - Item No."(var Rec: Record "Transfer Line")
    var
        Barcodes2: Record "LSC Barcodes";
        Item2: Record Item;
        pg: Page "LSC Retail TO. tb. Picked Sub.";
    begin
        if (Rec."Item No." <> '') and Item2.Get(Rec."Item No.") then begin
            Rec."FSN Attrib 1 Code" := Item2."LSC Attrib 1 Code";

            if (rec."FSN Barcode No." = '') or (Rec."Unit of Measure Code" = '') then begin
                Rec."FSN Attrib 1 Code" := Item2."LSC Attrib 1 Code";

                Barcodes2.Reset();
                Barcodes2.SetRange("Item No.", Rec."Item No.");
                Barcodes2.SetRange("Unit of Measure Code", Item2."Purch. Unit of Measure");
                if Barcodes2.FindFirst() then begin
                    Rec.Validate("Unit of Measure Code", Barcodes2."Unit of Measure Code");
                    Rec."FSN Barcode No." := Barcodes2."Barcode No.";
                end;
            end;
            pg.ValStatusScann;
        end;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Transfer Line", 'OnBeforeModifyEvent', '', true, true)]
    local procedure "Transfer Line_OnBeforeModifyEvent"
    (
        var Rec: Record "Transfer Line";
        var xRec: Record "Transfer Line";
        RunTrigger: Boolean
    )
    var
        TEXT000: Label 'No puede cambiar cantidades ya confirmadas';
    begin
        if (Rec.Quantity <> xRec.Quantity) and REc."FSN Checked" then
            Error(TEXT000);
    end;

    /*  [EventSubscriber(ObjectType::Codeunit, Codeunit::"TransferOrder-Post (Yes/No)", 'OnBeforePost', '', true, true)]
        local procedure "TransferOrder-Post (Yes/No)_OnBeforePost"
        (
            var TransHeader: Record "Transfer Header";
            var IsHandled: Boolean
        )
        var
            TransLine: Record "Transfer Line";
            Text000: Label 'Tiene lineas pendientes de escanear';
        begin
            TransLine.Reset();
            TransLine.SetRange("Document No.", TransHeader."No.");
            if TransLine.Find('-') then begin
                repeat
                    if not TransLine."FSN Checked" then begin
                        IsHandled := true;
                        Error(Text000);
                    end;
                until TransLine.Next() = 0;
            end;
        end;
    */
    //? aplicar el DTE a la transferencia
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"TransferOrder-Post Shipment", 'OnAfterCheckInvtPostingSetup', '', false, false)]
    local procedure OnAfterCheckInvtPostingSetup(var TransferHeader: Record "Transfer Header"; var TempWhseShipmentHeader: Record "Warehouse Shipment Header" temporary; var SourceCode: Code[10]);
    begin
        //sendDTE(TransferHeader, true);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Transfer Line", 'OnAfterModifyEvent', '', true, true)]
    local procedure "Transfer Line_OnAfterModifyEvent"
    (
        var Rec: Record "Transfer Line";
        var xRec: Record "Transfer Line";
        RunTrigger: Boolean
    )
    var
        th: Record "Transfer Header";
        item: Record Item;
        um: Record "Item Unit of Measure";
    begin
        if th.Get(Rec."Document No.") and (th."LSC Transfer Type" = th."LSC Transfer Type"::Replenishment) then
            if item.get(rec."Item No.") and (item."Base Unit of Measure" <> item."Purch. Unit of Measure") then
                if Rec."Unit of Measure Code" <> item."Purch. Unit of Measure" then
                    if um.Get(rec."Item No.", item."Purch. Unit of Measure") then begin
                        Rec.Validate("Unit of Measure Code", item."Purch. Unit of Measure");
                        Rec.Validate(Quantity, Round(Rec.Quantity / um."Qty. per Unit of Measure", 1));
                        Rec.Modify();
                    end;
    end;
}
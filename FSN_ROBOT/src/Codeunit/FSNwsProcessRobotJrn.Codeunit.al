codeunit 50067 "FSN WS Process Robot Jrn"
{
    trigger OnRun()
    begin

    end;

    var
        myInt: Integer;
        FSNPosProRobot: Codeunit "FSN POS Process Robot";

    [ServiceEnabled]

    //Aplica ajuste Positivo 
    procedure PosAdjTUseItemJrnTemplate(Request: Text; var ErrorText: Text): Boolean
    var
        DocumentNo: Code[20];
        StoreNo: Code[20];
        ItemNo: Code[20];
        jObject: JsonObject;
        jToken: JsonToken;
        JsonArray: JsonArray;
        JsonItem: JsonObject;
        TEXT002: Label 'Los datos ya se encuentran registrados en Item Ledger Entry.';
        ItemJrnTemplete: Record "Item Journal Template";
        ItemJrnBatch: Record "Item Journal Batch";
        ItemJrnLine: Record "Item Journal Line";
        ErrorTextConfig: Text;
        POSMenuLineTemp: Record "LSC POS Menu Line" temporary;
    begin
        ErrorText := '';
        clear(POSMenuLineTemp);
        POSMenuLineTemp.DeleteAll();
        // Leer el JSON de entrada
        if jObject.ReadFrom(Request) then begin

            if not ValJsonInformation(jObject, DocumentNo, StoreNo, ErrorText) then
                exit(false);

            if NOT ValidateConfigJnl(StoreNo, DocumentNo, ItemJrnTemplete, ItemJrnBatch, ErrorText, true) then
                exit(false);

            if jObject.Get('ProductDetail', jToken) then // Seleccionar el arreglo
                if jToken.IsArray then begin // Verificar que el token es un arreglo y convertirlo
                    JsonArray := jToken.AsArray();

                    ValJsonArrayDetail(JsonArray, DocumentNo, StoreNo, POSMenuLineTemp);

                    if POSMenuLineTemp.Find('-') then begin
                        repeat

                            if not ValidateExistJrnLine(ItemJrnLine, POSMenuLineTemp, ItemJrnBatch.Name) then
                                InsertLineAdjTUseItemJrnTemplate(ItemJrnLine, POSMenuLineTemp, ItemJrnTemplete, ItemJrnBatch, true);

                        until POSMenuLineTemp.Next() = 0;
                    end;

                    if ErrorText = '' then begin
                        if not ItemJrnLine.IsEmpty then begin
                            if not ProcessJnlPost(ItemJrnLine, ErrorText) then
                                exit(false)
                            else
                                exit(true);
                        end else begin
                            ErrorText := TEXT002;
                            exit(false);
                        end;
                    end else begin
                        exit(false);
                    end;
                end;
        end;
    end;

    //Aplica ajuste negativo 
    procedure ValNegAdjTItemJrnTemplate(Request: Text; var ErrorText: Text): Boolean
    var
        DocumentNo: Code[20];
        StoreNo: Code[20];
        jObject: JsonObject;
        jToken: JsonToken;
        JsonArray: JsonArray;
        JsonItem: JsonObject;
        TEXT000: Label 'Numero Documento no puede ser Null o vacio.';
        TEXT001: Label 'No Store no puede ser Null o vacio.';
        TEXT002: Label 'Los datos ya se encuentran registrados en Item Ledger Entry.';
        TEXT003: Label 'Ajuste no aplicado';
        ItemJrnTemplete: Record "Item Journal Template";
        ItemJrnBatch: Record "Item Journal Batch";
        ItemJrnLine: Record "Item Journal Line";
        ErrorTextConfig: Text;
        POSTransaction: Record "LSC POS Transaction";
        POSMenuLineTemp: Record "LSC POS Menu Line" temporary;
    begin
        ErrorText := '';
        clear(POSMenuLineTemp);
        POSMenuLineTemp.DeleteAll();
        // Leer el JSON de entrada
        if jObject.ReadFrom(Request) then begin
            if not ValJsonInformation(jObject, DocumentNo, StoreNo, ErrorText) then
                exit(false);

            if NOT ValidateConfigJnl(StoreNo, DocumentNo, ItemJrnTemplete, ItemJrnBatch, ErrorText, true) then
                exit(false);

            if jObject.Get('ProductDetail', jToken) then // Seleccionar el arreglo
                if jToken.IsArray then begin // se verifica que el token sea un arreglo y convertirlo
                    JsonArray := jToken.AsArray();

                    ValJsonArrayDetail(JsonArray, DocumentNo, StoreNo, POSMenuLineTemp);

                    if POSMenuLineTemp.Find('-') then begin
                        repeat

                            if not ValidateExistJrnLine(ItemJrnLine, POSMenuLineTemp, ItemJrnBatch.Name) then
                                InsertLineAdjTUseItemJrnTemplate(ItemJrnLine, POSMenuLineTemp, ItemJrnTemplete, ItemJrnBatch, false);

                        until POSMenuLineTemp.Next() = 0;
                    end;

                    if ErrorText = '' then begin
                        if not ItemJrnLine.IsEmpty then begin
                            if not ProcessJnlPost(ItemJrnLine, ErrorText) then
                                exit(false)
                            else
                                exit(true);
                        end else begin
                            ErrorText := TEXT002;
                            exit(false);
                        end;
                    end else begin
                        exit(false);
                    end;
                end;
        end;
    end;

    procedure SaveInfocode(var OrderNo: Code[20]; var Terminal: Code[20]; var Box: Text)
    var
        myInt: Integer;
        InfoEntry: Record "LSC POS Trans. Infocode Entry";
        TEXT000: Label 'Caja %1';
        Transaction: Record "LSC POS Transaction";
        transLine: Record "LSC POS Trans. Line";
    begin
        if Transaction.get(OrderNo) then begin
            if Terminal <> '' then begin
                Terminal := InsStr(Terminal, '#', 3);
                InfoEntry.Init();
                InfoEntry."Store No." := Transaction."Store No.";
                InfoEntry."POS Terminal No." := Transaction."POS Terminal No.";
                InfoEntry."Receipt No." := Transaction."Receipt No.";
                InfoEntry."Transaction Type" := 0;
                InfoEntry."Line No." := 70;
                InfoEntry.Infocode := 'TEXT';
                InfoEntry.Information := Terminal;
                InfoEntry.Date := Today;
                InfoEntry.Time := Time;
                if not InfoEntry.Insert() then
                    InfoEntry.Modify();
            end;

            if Box <> '' then begin
                InfoEntry.Reset();
                InfoEntry.Init();
                InfoEntry."Store No." := Transaction."Store No.";
                InfoEntry."POS Terminal No." := Transaction."POS Terminal No.";
                InfoEntry."Receipt No." := Transaction."Receipt No.";
                InfoEntry."Transaction Type" := 0;
                InfoEntry."Line No." := 80;
                InfoEntry.Infocode := 'TEXT';
                InfoEntry.Information := Box;
                InfoEntry.Date := Today;
                InfoEntry.Time := Time;
                if not InfoEntry.Insert() then
                    InfoEntry.Modify();

                transLine.Init();
                transLine.Validate("Receipt No.", transaction."Receipt No.");
                transLine.Validate("Store No.", transaction."Store No.");
                transLine.Validate("POS Terminal No.", transaction."POS Terminal No.");
                transLine.Validate("Line No.", 80);
                transLine.Validate("Entry Type", transLine."Entry Type"::FreeText);
                transLine.Validate("Description", StrSubstNo(TEXT000, Format(Box)));
                if not transLine.Insert(true) then
                    transLine.Modify();
            end;
        end;
    end;

    //GUARDADO DE ALERTA DE INVENTARIO INSUFICIENTE
    procedure InvetAlertRobot(var OrderNo: Code[20]; Item: Code[20]; QuantityInv: Decimal; Quantity: Decimal; LineNo: Integer; UnitOfm: Code[10]): Text
    var
        TEXT000: Label 'Inventario del robot insuficiente – Artículo %1, Cantidad %2';
        Transaction: Record "LSC POS Transaction";
        transLine: Record "LSC POS Trans. Line";
        FSNPOSProcessRobot: Codeunit "FSN POS Process Robot";
        POSMenuLineTemp: Record "LSC POS Menu Line" temporary;
        ItemJrnLine: Record "Item Journal Line";
        ItemJrnBatch: Record "Item Journal Batch";
        ItemJrnTemplete: Record "Item Journal Template";
        ErrorTextConfig: Text;
        ErrorTextAplyJnl: Text;
        NegPos: Boolean;
        FSNParameter: Record "FSN Parameter";
        ItemLedgerEntry_l: Record "Item Ledger Entry";
    begin
        if Transaction.get(OrderNo) then begin
            NegPos := true; //Ajuste positivo

            IF FSNParameter.Get('ROBOT', 'PROCESS') THEN;

            POSMenuLineTemp.Init();
            POSMenuLineTemp."Profile ID" := 'ROBOT';
            POSMenuLineTemp."Current-RECEIPT" := OrderNo;
            POSMenuLineTemp."Current-SALESORDER" := Transaction."Store No.";
            POSMenuLineTemp."Menu ID" := Item;
            POSMenuLineTemp."Current-UOM" := UnitOfm;
            POSMenuLineTemp."Key No." := LineNo;
            POSMenuLineTemp."Current-Price" := Quantity;

            if NOT ValidateConfigJnl(Transaction."Store No.", Transaction."Receipt No.", ItemJrnTemplete, ItemJrnBatch, ErrorTextConfig, NegPos) then;

            //se valida que no exista Jrn Line o si ya estan registrados en item ledger entry,  si no se crean la linea.
            if not ValidateItemLedgerEntry(POSMenuLineTemp, ItemLedgerEntry_l, FSNParameter."Distribution Location Ext.", NegPos) then
                if not ValidateExistJrnLine(ItemJrnLine, POSMenuLineTemp, ItemJrnBatch.Name) then begin
                    transLine.Init();
                    transLine.Validate("Receipt No.", transaction."Receipt No.");
                    transLine.Validate("Store No.", transaction."Store No.");
                    transLine.Validate("POS Terminal No.", transaction."POS Terminal No.");
                    transLine.Validate("Line No.", FSNPOSProcessRobot.getLine(transaction, 'new'));
                    transLine.Validate("Entry Type", transLine."Entry Type"::FreeText);
                    transLine.Validate("Description", StrSubstNo(TEXT000, Item, Format(Quantity)));
                    if not transLine.Insert(true) then
                        transLine.Modify();

                    InsertLineAdjTUseItemJrnTemplate(ItemJrnLine, POSMenuLineTemp, ItemJrnTemplete, ItemJrnBatch, NegPos);//aplica ajuste negativo a la bodega del robot
                end;

            /*if not ItemJrnLine.IsEmpty then begin
                if not ProcessJnlPost(ItemJrnLine, ErrorTextAplyJnl) then
                    exit(ErrorTextAplyJnl)
                else
                    exit('true');
            END else*/
            exit('true');
        end;
    end;

    procedure ValJsonInformation(RequestJson: JsonObject; var DocumentNo: Code[20]; var StoreNo: Code[20]; var ErrorText: Text): Boolean
    var
        jObject: JsonObject;
        jToken: JsonToken;
        TEXT000: Label 'Numero Documento no puede ser Null o vacio.';
        TEXT001: Label 'No Store no puede ser Null o vacio.';
    begin

        if RequestJson.Get('DocumentNo', jToken) and not (JToken.AsValue().IsNull) then begin
            if jToken.AsValue().AsText() <> '' then
                DocumentNo := jToken.AsValue().AsText()
            else begin
                ErrorText := TEXT000;
                exit(false);
            end;
        end else begin
            ErrorText := TEXT000;
            exit(false);
        end;

        if RequestJson.Get('Store', jToken) and not (JToken.AsValue().IsNull) then begin
            if jToken.AsValue().AsText() <> '' then
                StoreNo := jToken.AsValue().AsText()
            else begin
                ErrorText := TEXT001;
                exit(false);
            end;
        end else begin
            ErrorText := TEXT001;
            exit(false);
        end;

        exit(true);
    end;

    procedure ValJsonArrayDetail(JsonArray: JsonArray; DocumentNo: Code[20]; StoreNo: Code[20]; var POSMenuLineTemp: Record "LSC POS Menu Line" temporary)
    var
        jToken: JsonToken;
        JsonItem: JsonObject;

    begin
        Clear(POSMenuLineTemp);
        POSMenuLineTemp.DeleteAll();
        foreach jToken in JsonArray do begin
            if jToken.IsObject then begin // Verificar que sea un objeto
                JsonItem := jToken.AsObject();

                POSMenuLineTemp.Init();
                POSMenuLineTemp."Profile ID" := 'ROBOT';
                POSMenuLineTemp."Current-RECEIPT" := DocumentNo;
                POSMenuLineTemp."Current-SALESORDER" := StoreNo;

                if JsonItem.Get('Code', jToken) then
                    POSMenuLineTemp."Menu ID" := jToken.AsValue().AsText();

                if JsonItem.Get('PackagingUnit', jToken) then
                    POSMenuLineTemp."Current-UOM" := jToken.AsValue().AsText();

                if JsonItem.Get('LineNo', jToken) then
                    POSMenuLineTemp."Key No." := jToken.AsValue().AsInteger();

                if JsonItem.Get('Quantity', jToken) then
                    POSMenuLineTemp."Current-Price" := jToken.AsValue().AsInteger();

                POSMenuLineTemp.Insert();

            END;
        END;
    end;

    //recibe los datos para crear Item Journal line
    procedure InsertLineAdjTUseItemJrnTemplate(VAR ItemJournalLine_l: Record "Item Journal Line"; POSMenuLineTemp: Record "LSC POS Menu Line" temporary; ItemJrnTemplate_l: Record "Item Journal Template"; ItemJrnBatch_l: Record "Item Journal Batch"; NegPos: Boolean): Boolean
    var
        FSNParameter: Record "FSN Parameter";
        Item: Record Item;
        ItemLedgerEntry_l: Record "Item Ledger Entry";
    begin

        IF FSNParameter.Get('ROBOT', 'PROCESS') THEN;

        IF NOT ValidateItemLedgerEntry(POSMenuLineTemp, ItemLedgerEntry_l, FSNParameter."Distribution Location Ext.", NegPos) THEN BEGIN
            ItemJournalLine_l.INIT;
            ItemJournalLine_l.VALIDATE("Journal Template Name", ItemJrnBatch_l."Journal Template Name");
            ItemJournalLine_l.VALIDATE("Journal Batch Name", ItemJrnBatch_l.Name);
            ItemJournalLine_l."Line No." := LineNo(ItemJrnBatch_l.Name);
            ItemJournalLine_l."Document Line No." := POSMenuLineTemp."Key No.";
            ItemJournalLine_l."Posting Date" := TODAY;
            if NegPos then
                ItemJournalLine_l."Entry Type" := ItemJournalLine_l."Entry Type"::"Positive Adjmt."
            else
                ItemJournalLine_l."Entry Type" := ItemJournalLine_l."Entry Type"::"Negative Adjmt.";
            ItemJournalLine_l.VALIDATE(ItemJournalLine_l."Item No.", POSMenuLineTemp."Menu ID");
            ItemJournalLine_l.VALIDATE("Unit of Measure Code", POSMenuLineTemp."Current-UOM");
            ItemJournalLine_l.VALIDATE(Quantity, POSMenuLineTemp."Current-Price");
            ItemJournalLine_l.VALIDATE("Location Code", FSNParameter."Distribution Location Ext.");
            IF ItemJrnBatch_l."Reason Code" <> '' THEN
                ItemJournalLine_l."Reason Code" := ItemJrnBatch_l."Reason Code"
            ELSE
                ItemJournalLine_l."Reason Code" := ItemJrnTemplate_l."Reason Code";
            ItemJournalLine_l.Type := ItemJournalLine_l.Type::"Work Center";
            ItemJournalLine_l."Source Code" := ItemJrnTemplate_l."Source Code";
            ItemJournalLine_l."Document No." := POSMenuLineTemp."Current-RECEIPT";
            ItemJournalLine_l."Order No." := POSMenuLineTemp."Current-RECEIPT";
            ItemJournalLine_l."External Document No." := POSMenuLineTemp."Current-RECEIPT";

            if Item.Get(ItemJournalLine_l."Item No.") THEN
                if Item."Item Tracking Code" <> '' then begin
                    ItemJournalLine_l."Lot No." := '#LOTCOMODIN';
                end;

            IF NOT ItemJournalLine_l.INSERT() then
                ItemJournalLine_l.Modify();
        END;
    end;

    //Se valida configuracion en FSN Parameter y almacenes
    procedure ValidateConfigJnl(StoreNo: Code[20]; DocumentNo: Code[20]; var ItemJrnTemplate_l: Record "Item Journal Template"; var ItemJrnBatch_l: Record "Item Journal Batch"; var ErrorText: Text; NegPos: Boolean): Boolean
    var
        FSNParameter: Record "FSN Parameter";
        lText001: Label 'plantilla diario producto %1 no está configurado.';
        lText002: Label 'El número de orden de transferencia no pueden estar vacíos';
        lText003: Label 'El código de transferencia almacen no pueden estar vacíos';
        lText004: Label 'Error en configuracion de tienda o ubicación';
        lText005: Label 'plantilla diario prod. %1 no está configurada en Parametros FSN, Campo Valor';
        lText006: Label 'No existe configuracion grupo ROBOT, codigo PROCESS en Parametros FSN';
        lText007: Label 'Libro diario producto %1 no es de tipo Producto';
        lText008: Label 'Secciones diario prod. %1 no está configurada en Parametros FSN, Campo FiltroData1';
        lText009: Label 'Secciones diario productos %1 no está configurado en Item Journal Batch.';
        lText010: Label 'Secciones diario prod. %1 no está configurada en Parametros FSN, Campo FiltroData2';
        Location_l: Record "Location";
        NewLocation_l: Record "Location";
        Store_l: Record "LSC Store";
        Ok_: Boolean;
        Void: Boolean;
    begin

        ErrorText := '';
        IF (DocumentNo = '') THEN BEGIN
            ErrorText := lText002;
            EXIT(FALSE);
        END;

        Ok_ := Store_l.GET(StoreNo);
        Ok_ := Location_l.GET(StoreNo);
        Void := FALSE;

        IF NOT Ok_ THEN BEGIN
            ErrorText := lText004;
            EXIT(FALSE);
        END;

        if not FSNParameter.get('ROBOT', 'PROCESS') then begin
            ErrorText := lText006;
            exit(false);
        end;

        if FSNParameter.Valor = '' then begin
            ErrorText := STRSUBSTNO(lText005, 'ROBOT');
            EXIT(FALSE);
        end;

        IF NOT ItemJrnTemplate_l.GET(FSNParameter.Valor) THEN BEGIN
            ErrorText := STRSUBSTNO(lText001, 'ROBOT');
            EXIT(FALSE);
        END;

        IF (ItemJrnTemplate_l.Type <> ItemJrnTemplate_l.Type::Item) THEN BEGIN
            ErrorText := STRSUBSTNO(lText007, ItemJrnTemplate_l.Name);
            EXIT(FALSE);
        END;

        if NegPos then begin
            if FSNParameter.SetFilterData1 = '' then begin
                ErrorText := STRSUBSTNO(lText008, 'VENTA');
                EXIT(FALSE);
            end;
        end else
            if FSNParameter.SetFilterData2 = '' then begin
                ErrorText := STRSUBSTNO(lText010, 'TRANSFERRO');
                EXIT(FALSE);
            end;

        if NegPos then begin
            IF not ItemJrnBatch_l.GET(ItemJrnTemplate_l.Name, FSNParameter.SetFilterData1) THEN begin
                Ok_ := false;
                ErrorText := STRSUBSTNO(lText009, 'VENTA');
                EXIT(FALSE);
            end;
        end else
            IF not ItemJrnBatch_l.GET(ItemJrnTemplate_l.Name, FSNParameter.SetFilterData2) THEN begin
                Ok_ := false;
                ErrorText := STRSUBSTNO(lText009, 'TRANSFERRO');
                EXIT(FALSE);
            end;
        exit(true);
    end;

    //Recibe Item Journal Line y aplica el ajuste
    procedure ProcessJnlPost(ItemJournalLine_l: Record "Item Journal Line"; var ErrorText: Text): Boolean
    var
        Ok_: Boolean;
    begin

        COMMIT;
        Ok_ := CODEUNIT.RUN(CODEUNIT::"Item Jnl.-Post", ItemJournalLine_l);
        //Si contiene
        IF NOT Ok_ THEN BEGIN
            ErrorText := GETLASTERRORTEXT;
            EXIT(FALSE);
        END;
        EXIT(TRUE);
    end;

    //Retornal la ultima Linea y hace el ingremento por 10000
    local procedure LineNo(BatchName: Code[10]): Integer
    var
        myInt: Integer;
        ItemJrnLine: Record "Item Journal Line";
    begin
        ItemJrnLine.reset;
        ItemJrnLine.SetRange(ItemJrnLine."Journal Template Name", 'ROBOT');
        ItemJrnLine.SetRange(ItemJrnLine."Journal Batch Name", BatchName);
        IF ItemJrnLine.Find('+') then
            exit(ItemJrnLine."Line No." + 10000)
        ELSE
            exit(10000);

    end;

    //Validate si existe jrnLine
    procedure ValidateExistJrnLine(var ItemJrnLine: Record "Item Journal Line"; POSMenuLineTemp: Record "LSC POS Menu Line" temporary; BatchName: Code[10]): Boolean
    var
        FSNParameter: Record "FSN Parameter";
    begin
        if FSNParameter.Get('ROBOT', 'PROCESS') then;
        ItemJrnLine.reset;
        ItemJrnLine.SetRange(ItemJrnLine."Journal Template Name", FSNParameter.Valor);
        ItemJrnLine.SetRange(ItemJrnLine."Journal Batch Name", BatchName);
        ItemJrnLine.SetRange(ItemJrnLine."Document No.", POSMenuLineTemp."Current-RECEIPT");
        ItemJrnLine.SetRange(ItemJrnLine."Document Line No.", POSMenuLineTemp."Key No.");
        ItemJrnLine.SetRange(ItemJrnLine."Item No.", POSMenuLineTemp."Menu ID");
        ItemJrnLine.SetRange(ItemJrnLine."Unit of Measure Code", POSMenuLineTemp."Current-UOM");
        exit(ItemJrnLine.FindFirst());

    end;

    procedure ValidateItemLedgerEntry(POSMenuLineTemp: Record "LSC POS Menu Line" temporary; VAR ItemLedgerEntry_l: Record "Item Ledger Entry"; "Code": Code[10]; NegPos: Boolean): Boolean
    begin
        ItemLedgerEntry_l.RESET;
        ItemLedgerEntry_l.SETCURRENTKEY("Document No.", "Document Type", "Document Line No.");
        ItemLedgerEntry_l.SETRANGE(ItemLedgerEntry_l."Document No.", POSMenuLineTemp."Current-RECEIPT");
        IF NegPos THEN
            ItemLedgerEntry_l.SETRANGE(ItemLedgerEntry_l."Entry Type", ItemLedgerEntry_l."Entry Type"::"Positive Adjmt.")
        ELSE
            ItemLedgerEntry_l.SETRANGE(ItemLedgerEntry_l."Entry Type", ItemLedgerEntry_l."Entry Type"::"Negative Adjmt.");
        ItemLedgerEntry_l.SETRANGE(ItemLedgerEntry_l."Document Line No.", POSMenuLineTemp."Key No.");
        ItemLedgerEntry_l.SETRANGE(ItemLedgerEntry_l."Location Code", Code);
        ItemLedgerEntry_l.SETRANGE(ItemLedgerEntry_l."Item No.", POSMenuLineTemp."Menu ID");
        EXIT(ItemLedgerEntry_l.FINDFIRST);
    end;


    [EventSubscriber(ObjectType::Table, Database::"Item Tracking Code", 'OnAfterIsSpecific', '', true, true)]
    local procedure "Item Tracking Code_OnAfterIsSpecific"
    (
        ItemTrackingCode: Record "Item Tracking Code";
        var Specific: Boolean
    )
    var
        FSNParameter: Record "FSN Parameter";
    begin
        if FSNParameter.Get('ROBOT', 'PROCESS') and FSNParameter.Activo THEN
            Specific := false;
    end;

    //Cambia a false HideDialog para no pedir confirmacion del ajuste 
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Jnl.-Post", 'OnBeforeCode', '', true, true)]
    local procedure "Item Jnl.-Post_OnBeforeCode"
    (
        var ItemJournalLine: Record "Item Journal Line";
        var HideDialog: Boolean;
        var SuppressCommit: Boolean;
        var IsHandled: Boolean
    )
    var
    begin
        if ItemJournalLine."Journal Template Name" = 'ROBOT' then
            HideDialog := true;
    end;

    //para evitar validacion lot 
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Jnl.-Post Line", 'OnBeforeTrackingSpecificationMissingErr', '', true, true)]
    local procedure "Item Jnl.-Post Line_OnBeforeTrackingSpecificationMissingErr"
    (
        ItemJournalLine: Record "Item Journal Line";
        var IsHandled: Boolean
    )
    begin
        if ItemJournalLine."Journal Template Name" = 'ROBOT' then
            IsHandled := true;
    end;
}
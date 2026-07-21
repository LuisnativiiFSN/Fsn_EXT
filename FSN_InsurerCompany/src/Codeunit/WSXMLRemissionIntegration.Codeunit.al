codeunit 50023 "FSN WS XML Remss. Integration"
{
    trigger OnRun()
    begin
        GLOBALLANGUAGE(2058);
        SELECTLATESTVERSION;

        CASE gWSConfig OF
            'FSN_SEND_REMISSION':
                SendRemission(gRequest, gResponse);
            'FSN_GET_NEW_INSURED':
                GetNewInsured(gRequest, gResponse);
            'FSN_POST_REMISSION':
                PostRemission(gRequest, gResponse);
            'FSN_RETURN_STATUS_REMISSION':
                ReturnStatusRemission(gRequest, gResponse);
            'FSN_VOID_REMISSION':
                VoidRemission(gRequest, gResponse);
            'FSN_GET_REMISSION_HEADER':
                GetRemissionHeader(gRequest, gResponse);
        END;
    end;

    var
        gRequest: Text;
        gResponse: Text;
        gWSConfig: Text[50];
        WSFunc: Codeunit "LSC WS Functions";
        gLocalProcess: Boolean;
        Text001: Label 'Invalid value %1 in Request Node %2';
        Text101: Label '%1 %2 no existe';
        Text103: Label '%1 %2';

    procedure SetXMLRequest(pRequest: Text; pWSConfig: Text[50])
    begin
        gRequest := pRequest;
        gResponse := '';
        gWSConfig := pWSConfig;
    end;


    procedure GetXMLResponse(var pXMLResponse: Text; var pXMLConfig: Text[50])
    begin
        pXMLResponse := gResponse;
        pXMLConfig := gWSConfig;
    end;

    procedure GetNewInsured(var pxmlRequest: Text; var pxmlResponse: Text)
    var
        ReqXml: XmlDocument;
        ResXml: XmlDocument;
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
        InsuredLlinksTmp: Record "FSN Insured Links" temporary;
        InsuredLinksTmp2: Record "FSN Insured Links" temporary;
        RecRef: RecordRef;
        InsuredLlinks: Record "FSN Insured Links";
        FlowFieldBuffer: Record "LSC FlowField Buffer" temporary;
        UpdateFieldList: Record "Field" temporary;
        TableNodeList: Record "LSC WS Node Buffer" temporary;
        RecRefTemp2: array[32] of RecordRef;
        RemissionMgt: Codeunit "FSN Remission Mgt.";
        lCompanyInsurer: Record "FSN Company Insurer";
    begin

        RequestID := 'FSN_GET_NEW_INSURED';
        WSFunc.LoadRequest(pxmlRequest, ReqXml, RequestID, RequestNodeList, ResponseNodeList, ParentNodeIndex, ParentNodeList, BodyNode, Response_Code, Response_Text);

        //Get List of request nodes
        InsuredLinksTmp2.RESET;
        InsuredLinksTmp2.DELETEALL;

        IF Response_Code = '0000' THEN
            WSFunc.AddChildNodeListText(RequestID, 0, ParentNodeIndex, ParentNodeList, 'Update_Action', '',
              ReqNodeList, Response_Code, Response_Text);

        IF Response_Code = '0000' THEN
            WSFunc.GetChildNodeList(0, BodyNode, ReqNodeList, Response_Code, Response_Text);
        IF Response_Code = '0000' THEN BEGIN
            ReqNodeList.RESET;
            IF ReqNodeList.FIND('-') THEN
                REPEAT
                    CASE ReqNodeList.Source OF
                        'Update_Action':
                            BEGIN
                                UpdateAction := ReqNodeList."Text Value";
                                IF NOT ((UpdateAction = 'Add') OR (UpdateAction = 'Update-Add')) THEN BEGIN
                                    Response_Code := '0030';
                                    Response_Text := STRSUBSTNO(Text001, ReqNodeList."Text Value", ReqNodeList."Node Name");
                                END;
                            END;
                    END;

                UNTIL (ReqNodeList.NEXT = 0) OR (Response_Code <> '0000');
        END;

        //Get Table
        IF Response_Code = '0000' THEN BEGIN
            RecRefTemp.GETTABLE(InsuredLlinksTmp);
            WSFunc.GetTableChildNodes(RequestID, 0, BodyNode, ParentNodeIndex, ParentNodeList, 'FSN Insured Links', RecRefTemp,
              FlowFieldBuffer, 1, UpdateFieldList, Response_Code, Response_Text);
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
        IF Response_Code = '0000' THEN BEGIN
            UpdateFieldList.SETRANGE(TableNo, 1);

            ReplCounter := 0;
            RecRefTemp.GETTABLE(InsuredLlinksTmp);
            RecRef.GETTABLE(InsuredLinksTmp2);
            WSFunc.UpdateTableByTempTable(AddOnly, RecRefTemp, RecRef, ReplCounter, UpdateFieldList);
        END;
        CLEARLASTERROR();
        RemissionMgt.CreateUpdInsuredWithTempTables(InsuredLinksTmp2, UpdateAction, RequestID);
        IF NOT RemissionMgt.RUN THEN BEGIN
            Response_Code := '0101';
            Response_Text := GETLASTERRORTEXT;
        END;

        //Process Response Doc
        WSFunc.InitParentResNodeList(ResponseNodeList, ParentNodeIndex, ParentNodeList);

        //Rest Table-
        WSFunc.AddChildNodeTableList(RequestID, 1, ParentNodeIndex, ParentNodeList, 'FSN Insured Links', TableNodeList,
          Response_Code, Response_Text);
        IF Response_Code = '0000' THEN BEGIN
            IF TableNodeList.FINDLAST THEN;

            IF InsuredLlinks.GET(InsuredLinksTmp2."Company No.", InsuredLinksTmp2.Card) THEN BEGIN //Temporary evaluate
                InsuredLlinks.SETRECFILTER;
                RecRef.GETTABLE(InsuredLlinks);
                RecRefTemp2[TableNodeList."Entry No."].OPEN(TableNodeList."Table No.", TRUE);
                WSFunc.CopyTableToTempTable(RecRef, RecRefTemp2[TableNodeList."Entry No."], FlowFieldBuffer);
            END ELSE BEGIN
                Response_Code := '1001';
                Response_Text := STRSUBSTNO(Text101, InsuredLlinks.TABLECAPTION, STRSUBSTNO(Text103, InsuredLinksTmp2."Company No.", InsuredLinksTmp2.Card));
            END;
        END;

        IF Response_Code <> '0000' THEN BEGIN
            WSFunc.ErrorResponse(RequestID, ResponseNodeList, Response_Code, Response_Text, gLocalProcess, pxmlResponse);
            EXIT;
        END;

        //Company Insured
        WSFunc.AddChildNodeTableList(RequestID, 1, ParentNodeIndex, ParentNodeList, 'FSN Company Insurer', TableNodeList,
          Response_Code, Response_Text);
        IF Response_Code = '0000' THEN BEGIN
            IF TableNodeList.FINDLAST THEN;

            IF lCompanyInsurer.GET(InsuredLinksTmp2."Company No.") THEN BEGIN //Temporary evaluate
                lCompanyInsurer.SETRECFILTER;
                RecRef.GETTABLE(lCompanyInsurer);
                RecRefTemp2[TableNodeList."Entry No."].OPEN(TableNodeList."Table No.", TRUE);
                WSFunc.CopyTableToTempTable(RecRef, RecRefTemp2[TableNodeList."Entry No."], FlowFieldBuffer);
            END ELSE BEGIN
                Response_Code := '1001';
                Response_Text := STRSUBSTNO(Text101, lCompanyInsurer.TABLECAPTION, STRSUBSTNO(Text103, InsuredLinksTmp2."Company No.", ''));
            END;
        END;
        //Rest Table+

        WSFunc.CreateResponse(ResXml, RequestID, ResponseNodeList, BodyNode);

        //Set Tables
        TableNodeList.RESET;
        IF TableNodeList.FIND('-') THEN
            REPEAT
                WSFunc.SetTableChildNodes(RequestID, 1, BodyNode, ParentNodeIndex, ParentNodeList, TableNodeList.Source,
                  RecRefTemp2[TableNodeList."Entry No."], FlowFieldBuffer, Response_Code, Response_Text);
            UNTIL (TableNodeList.NEXT = 0) OR (Response_Code <> '0000');

        IF Response_Code <> '0000' THEN BEGIN
            WSFunc.ErrorResponse(RequestID, ResponseNodeList, Response_Code, Response_Text, gLocalProcess, pxmlResponse);
            EXIT;
        END;

        ResXml.WriteTo(pxmlResponse);
    end;


    procedure SendRemission(var pxmlRequest: Text; var pxmlResponse: Text)
    var
        ReqXml: XmlDocument;
        ResXml: XmlDocument;
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
        RemissionHeaderTmp: Record "FSN Remission Header" temporary;
        RemissionLineTmp: Record "FSN Remission Line" temporary;
        RecRef: RecordRef;
        RemissionHeader: Record "FSN Remission Header";
        RemissionLine: Record "FSN Remission Line";
        FlowFieldBuffer: Record "LSC FlowField Buffer" temporary;
        UpdateFieldList: Record "Field" temporary;
        TableNodeList: Record "LSC WS Node Buffer" temporary;
        RecRefTemp2: array[32] of RecordRef;
        RemissionHeaderTmp2: Record "FSN Remission Header" temporary;
        RemissionLineTmp2: Record "FSN Remission Line" temporary;
        RemissionMgt: Codeunit "FSN Remission Mgt.";
        _Counter: Integer;
        RecRefTempLine: RecordRef;
        UpdateFieldListLine: Record "Field" temporary;
        FlowFieldBufferLine: Record "LSC FlowField Buffer" temporary;
        RemissionHeaderTmp3: Record "FSN Remission Header" temporary;
        RemissionLineTmp3: Record "FSN Remission Line" temporary;
        lError: Text[30];
        _Key: RecordID;
        xmlFinal: File;
        xmlStream: OutStream;
        sb: Text;
    begin

        /*IF xmlFinal.CREATE('C:\Temp\FSN_SEND_REMISSION_TEST.xml') THEN BEGIN
            sb := pxmlRequest;
            xmlFinal.CREATEOUTSTREAM(xmlStream);
            xmlStream.WriteText(sb);
            xmlFinal.CLOSE;
        end;*/

        RequestID := 'FSN_SEND_REMISSION';
        WSFunc.LoadRequest(pxmlRequest, ReqXml, RequestID, RequestNodeList, ResponseNodeList, ParentNodeIndex, ParentNodeList, BodyNode, Response_Code, Response_Text);

        //Get List of request nodes
        RemissionHeaderTmp.RESET;
        RemissionHeaderTmp.DELETEALL;
        CLEAR(RemissionHeaderTmp);
        RemissionLineTmp.RESET;
        RemissionLineTmp.DELETEALL;
        CLEAR(RemissionLineTmp);
        RemissionHeaderTmp2.RESET;
        RemissionHeaderTmp2.DELETEALL;
        CLEAR(RemissionHeaderTmp2);
        RemissionLineTmp2.RESET;
        RemissionLineTmp2.DELETEALL;
        CLEAR(RemissionLineTmp2);

        IF Response_Code = '0000' THEN
            WSFunc.AddChildNodeListText(RequestID, 0, ParentNodeIndex, ParentNodeList, 'Update_Action', '',
              ReqNodeList, Response_Code, Response_Text);

        IF Response_Code = '0000' THEN
            WSFunc.GetChildNodeList(0, BodyNode, ReqNodeList, Response_Code, Response_Text);
        IF Response_Code = '0000' THEN BEGIN
            ReqNodeList.RESET;
            IF ReqNodeList.FIND('-') THEN
                REPEAT
                    CASE ReqNodeList.Source OF
                        'Update_Action':
                            BEGIN
                                UpdateAction := ReqNodeList."Text Value";
                                IF NOT ((UpdateAction = 'Add') OR (UpdateAction = 'Update-Add')) THEN BEGIN
                                    Response_Code := '0030';
                                    Response_Text := STRSUBSTNO(Text001, ReqNodeList."Text Value", ReqNodeList."Node Name");
                                END;
                            END;
                    END;
                UNTIL (ReqNodeList.NEXT = 0) OR (Response_Code <> '0000');
        END;


        //Get Tables
        IF Response_Code = '0000' THEN BEGIN
            RecRefTemp.GETTABLE(RemissionHeaderTmp);
            WSFunc.GetTableChildNodes(RequestID, 0, BodyNode, ParentNodeIndex, ParentNodeList, 'FSN Remission Header', RecRefTemp,
              FlowFieldBuffer, 1, UpdateFieldList, Response_Code, Response_Text);
        END;
        IF Response_Code = '0000' THEN BEGIN
            RecRefTempLine.GETTABLE(RemissionLineTmp);
            WSFunc.GetTableChildNodes(RequestID, 0, BodyNode, ParentNodeIndex, ParentNodeList, 'FSN Remission Line', RecRefTempLine,
              FlowFieldBufferLine, 1, UpdateFieldListLine, Response_Code, Response_Text);
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

        IF Response_Code = '0000' THEN BEGIN
            UpdateFieldList.SETRANGE(TableNo, 1);

            ReplCounter := 0;
            RecRefTemp.GETTABLE(RemissionHeaderTmp);
            RecRef.GETTABLE(RemissionHeaderTmp2);
            WSFunc.UpdateTableByTempTable(AddOnly, RecRefTemp, RecRef, ReplCounter, UpdateFieldList);
        END;
        IF Response_Code = '0000' THEN BEGIN
            UpdateFieldListLine.SETRANGE(TableNo, 1);

            ReplCounter := 0;
            RecRefTemp.GETTABLE(RemissionLineTmp);
            RecRef.GETTABLE(RemissionLineTmp2);
            WSFunc.UpdateTableByTempTable(AddOnly, RecRefTemp, RecRef, ReplCounter, UpdateFieldList);
        END;

        CLEARLASTERROR();
        RemissionMgt.CreateUpdRemissionWithTempTables(RemissionHeaderTmp2, RemissionLineTmp2, UpdateAction, RequestID);
        IF NOT RemissionMgt.RUN THEN BEGIN
            lError := '0101';
            Response_Code := lError;
            Response_Text := GETLASTERRORTEXT;
        END ELSE
            RemissionHeaderTmp."No." := RemissionMgt.GetCurrRemission;

        IF Response_Code <> '0000' THEN BEGIN
            WSFunc.ErrorResponse(RequestID, ResponseNodeList, Response_Code, Response_Text, gLocalProcess, pxmlResponse);
            EXIT;
        END;

        //Process Response Doc
        WSFunc.InitParentResNodeList(ResponseNodeList, ParentNodeIndex, ParentNodeList);

        //Respose Tables
        WSFunc.AddChildNodeTableList(RequestID, 1, ParentNodeIndex, ParentNodeList, 'FSN Remission Header', TableNodeList,
          Response_Code, Response_Text);
        IF Response_Code = '0000' THEN BEGIN
            IF TableNodeList.FINDLAST THEN;

            IF RemissionHeader.GET(RemissionHeaderTmp."Document Type", RemissionHeaderTmp."No.") THEN BEGIN
                RemissionHeader.SETRECFILTER;
                RemissionHeader.Amount := RemissionMgt.GetRemissionAmount(RemissionHeader."Document Type", RemissionHeader."No.");
                RemissionHeader."Amount Including VAT" := RemissionMgt.GetRemissionAmountIncVAT(RemissionHeader."Document Type", RemissionHeader."No.");
                RemissionHeader."Deductible Manual" := RemissionMgt.GetRemissionManualDeductible(RemissionHeader."Document Type", RemissionHeader."No.");
                RemissionHeader."Document Total" := RemissionHeader."Amount Including VAT";
                RemissionHeader."Deductible Amount" := RemissionHeader."Deductible Manual";
                RecRef.GETTABLE(RemissionHeader);

                //WVILLALTA Set FlowField Manual
                IF NOT FlowFieldBuffer.GET(DATABASE::"FSN Remission Header", RecRef.RECORDID, RemissionHeader.FIELDNO("Coinsurance Value")) THEN BEGIN
                    FlowFieldBuffer."Table No." := DATABASE::"FSN Remission Header";
                    FlowFieldBuffer.Key := RecRef.RECORDID;
                    FlowFieldBuffer."Field No." := RemissionHeader.FIELDNO("Coinsurance Value");
                    FlowFieldBuffer."Decimal Value" := RemissionMgt.GetRemissionCoinsurance(RemissionHeader."Document Type", RemissionHeader."No.");
                    FlowFieldBuffer.INSERT;
                END;
                IF NOT FlowFieldBuffer.GET(DATABASE::"FSN Remission Header", RecRef.RECORDID, RemissionHeader.FIELDNO("Coinsurance Value")) THEN BEGIN
                    FlowFieldBuffer."Table No." := DATABASE::"FSN Remission Header";
                    FlowFieldBuffer.Key := RecRef.RECORDID;
                    FlowFieldBuffer."Field No." := RemissionHeader.FIELDNO(Comission);
                    FlowFieldBuffer."Decimal Value" := RemissionMgt.GetRemissionComission(RemissionHeader."Document Type", RemissionHeader."No.");
                    FlowFieldBuffer.INSERT;
                END;

                RecRefTemp2[TableNodeList."Entry No."].OPEN(TableNodeList."Table No.", TRUE);
                WSFunc.CopyTableToTempTable(RecRef, RecRefTemp2[TableNodeList."Entry No."], FlowFieldBuffer);
            END ELSE BEGIN
                Response_Code := '1001';
                Response_Text := STRSUBSTNO(Text101, RemissionHeader.TABLECAPTION, STRSUBSTNO(Text103, RemissionHeaderTmp."Document Type", RemissionHeaderTmp."No."));
            END;
        END;

        IF Response_Code <> '0000' THEN BEGIN
            WSFunc.ErrorResponse(RequestID, ResponseNodeList, Response_Code, Response_Text, gLocalProcess, pxmlResponse);
            EXIT;
        END;

        //Line
        WSFunc.AddChildNodeTableList(RequestID, 1, ParentNodeIndex, ParentNodeList, 'FSN Remission Line', TableNodeList,
          Response_Code, Response_Text);
        IF Response_Code = '0000' THEN BEGIN
            IF TableNodeList.FINDLAST THEN;

            ProcessMINSAL(RemissionHeader);

            RemissionLine.RESET;
            RemissionLine.SETRANGE(RemissionLine."Document Type", RemissionHeader."Document Type");
            RemissionLine.SETRANGE(RemissionLine."Document No.", RemissionHeader."No.");
            IF RemissionLine.FIND('-') THEN BEGIN
                RecRef.GETTABLE(RemissionLine);
                RecRefTemp2[TableNodeList."Entry No."].OPEN(TableNodeList."Table No.", TRUE);
                WSFunc.CopyTableToTempTable(RecRef, RecRefTemp2[TableNodeList."Entry No."], FlowFieldBuffer);
            END ELSE BEGIN
                RemissionLineTmp3.RESET;
                RemissionLineTmp3.DELETEALL;
                CLEAR(RemissionLineTmp3);
                RecRef.GETTABLE(RemissionLineTmp3);
                RecRefTemp2[TableNodeList."Entry No."].OPEN(TableNodeList."Table No.", TRUE);
                WSFunc.CopyTableToTempTable(RecRef, RecRefTemp2[TableNodeList."Entry No."], FlowFieldBuffer);

            END;
        END;

        WSFunc.CreateResponse(ResXml, RequestID, ResponseNodeList, BodyNode);

        //Set Tables
        TableNodeList.RESET;
        IF TableNodeList.FIND('-') THEN
            REPEAT
                WSFunc.SetTableChildNodes(RequestID, 1, BodyNode, ParentNodeIndex, ParentNodeList, TableNodeList.Source,
                  RecRefTemp2[TableNodeList."Entry No."], FlowFieldBuffer, Response_Code, Response_Text);
            UNTIL (TableNodeList.NEXT = 0) OR (Response_Code <> '0000');

        IF Response_Code <> '0000' THEN BEGIN
            WSFunc.ErrorResponse(RequestID, ResponseNodeList, Response_Code, Response_Text, gLocalProcess, pxmlResponse);
            EXIT;
        END;

        ResXml.WriteTo(pxmlResponse);

    end;

    procedure GetFindLastLine(DocumentNo: Code[20]): Integer
    var
        myInt: Integer;
        lRemissionLine: Record "FSN Remission Line";
    begin

        lRemissionLine.RESET;
        lRemissionLine.SetRange(lRemissionLine."Document Type", lRemissionLine."Document Type"::Remision);
        lRemissionLine.SetRange(lRemissionLine."Document No.", DocumentNo);
        IF lRemissionLine.FINDLAST THEN
            exit(lRemissionLine."Line No." + 10000)
        else
            exit(10000);
    end;

    procedure ProcessMINSAL(RemissionHeader: Record "FSN Remission Header")
    var
    begin

        if RemissionHeader."Company No." = 'MINSAL' then
            ValProdApply(RemissionHeader);
    end;

    procedure ValProdApply(remissionHeader: record "FSN Remission Header")
    var
        FSNParameter: record "FSN Parameter";
        PROD: Code[20];
    begin
        Clear(PROD);
        FSNParameter.Reset();
        FSNParameter.SetRange(FSNParameter.Grupo, 'MINSAL');
        IF FSNParameter.Find('-') then
            repeat
                IF PROD <> FSNParameter.Valor THEN BEGIN
                    PROD := FSNParameter.Valor;
                    GetQtyProdMinsal(RemissionHeader, FSNParameter.Valor);
                END;
            until FSNParameter.Next = 0;
    end;

    procedure GetQtyProdMinsal(RemissionHeader: Record "FSN Remission Header"; ProvFilt: Code[20])
    var
        myInt: Integer;
        FSNParameter: record "FSN Parameter";
        RemissionLine: Record "FSN Remission Line";
        IsMinsal: Boolean;
        Qty: Decimal;
    begin
        IsMinsal := false;
        FSNParameter.Reset();
        FSNParameter.SetRange(FSNParameter.Grupo, 'MINSAL');
        FSNParameter.SetRange(FSNParameter.Valor, ProvFilt);
        if FSNParameter.Find('-') then
            repeat
                if FSNParameter.Activo then begin
                    RemissionLine.RESET;
                    RemissionLine.SETRANGE(RemissionLine."Document Type", RemissionHeader."Document Type");
                    RemissionLine.SETRANGE(RemissionLine."Document No.", RemissionHeader."No.");
                    RemissionLine.SETRANGE(RemissionLine."No.", FSNParameter.Codigo);
                    if RemissionLine.FindFirst() then begin
                        Qty += RemissionLine.Quantity * FSNParameter."Limit Value";
                        IsMinsal := true;
                    end;
                end;
            until FSNParameter.Next = 0;

        if IsMinsal then begin
            if Qty <> 0 then
                ValMISAL(RemissionHeader, Qty, FSNParameter.Valor)
            else
                MotExistMinsalDeleteLine(RemissionHeader, FSNParameter.Valor);
        end else
            MotExistMinsalDeleteLine(RemissionHeader, FSNParameter.Valor);
    end;

    procedure VALMISAL(RemissionHeader: record "FSN Remission Header"; var Qty: Decimal; ProdValue: Code[20])
    var
        RemissionLineFiltVal: Record "FSN Remission Line";
        Item: Record Item;
        Barcodes: Record "LSC Barcodes";
        FSNParameter: record "FSN Parameter";
        ItemUOM: Record "Item Unit of Measure";
        GetRemissionLine: Record "FSN Remission Line";
    begin

        if Item.Get(ProdValue) then
            if not GetRemissionExist(RemissionHeader, GetRemissionLine, ProdValue) then begin
                RemissionLineFiltVal.INIT();
                RemissionLineFiltVal."Document Type" := RemissionLineFiltVal."Document Type"::Remision;
                RemissionLineFiltVal."Document No." := RemissionHeader."No.";
                RemissionLineFiltVal."Line No." := GetFindLastLine(RemissionHeader."No.");
                RemissionLineFiltVal.Type := RemissionLineFiltVal.Type::Item;
                RemissionLineFiltVal.Barcode := Item."FSN Barcode No.";
                if ItemUOM.Get(Item."No.", Item."Sales Unit of Measure") then;
                RemissionLineFiltVal."No." := Item."No.";
                RemissionLineFiltVal.Description := Item.Description;
                RemissionLineFiltVal.Validate("Unit of Measure", ItemUOM.Code);
                RemissionLineFiltVal.Validate(Quantity, Qty);
                RemissionLineFiltVal."Store No." := RemissionHeader."Store No.";
                RemissionLineFiltVal.Scanned := true;
                RemissionLineFiltVal.insert(TRUE);
            end else begin
                if GetRemissionLine.Quantity <> Qty then begin
                    GetRemissionLine.Validate(Quantity, Qty);
                    GetRemissionLine.Modify(TRUE);
                end;
            end;
        Qty := 0;
    end;

    procedure GetRemissionExist(ValRemissionHeader: Record "FSN Remission Header"; var GetRemissionLine: Record "FSN Remission Line"; ProdValue: Code[20]): Boolean
    var
        myInt: Integer;
    begin
        GetRemissionLine.Reset();
        GetRemissionLine.SetRange(GetRemissionLine."Document Type", ValRemissionHeader."Document Type");
        GetRemissionLine.SetRange(GetRemissionLine."Document No.", ValRemissionHeader."No.");
        GetRemissionLine.SetRange(GetRemissionLine."No.", ProdValue);
        if GetRemissionLine.FindFirst() then
            exit(true)
        else
            exit(false);
    end;

    procedure ProdIsMInsal(prod: Code[20]): Boolean
    var
        fsnparameter: record "FSN Parameter";
    begin
        fsnparameter.Reset();
        fsnparameter.SetRange(fsnparameter.Grupo, 'MINSAL');
        fsnparameter.SetRange(fsnparameter.Valor, prod);
        fsnparameter.SetRange(fsnparameter.Activo, true);
        if fsnparameter.FindFirst() then
            exit(true)
        else
            exit(false);
    end;

    procedure MotExistMinsalDeleteLine(RemissionHeader: Record "FSN Remission Header"; CodValue: Code[20])
    var
        RemissionLine: Record "FSN Remission Line";
    begin
        RemissionLine.RESET;
        RemissionLine.SETRANGE(RemissionLine."Document Type", RemissionHeader."Document Type");
        RemissionLine.SETRANGE(RemissionLine."Document No.", RemissionHeader."No.");
        RemissionLine.SETRANGE(RemissionLine."No.", CodValue);
        IF RemissionLine.FINDFIRST THEN
            RemissionLine.DELETE(TRUE);
    end;

    procedure PostRemission(var pxmlRequest: Text; var pxmlResponse: Text)
    var
        ReqXml: XmlDocument;
        ResXml: XmlDocument;
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
        RemissionHeaderTmp: Record "FSN Remission Header" temporary;
        RemissionHeaderTmp2: Record "FSN Remission Header" temporary;
        RemissionLineTmp: Record "FSN Remission Line" temporary;
        RecRef: RecordRef;
        RemissionHeader: Record "FSN Remission Header";
        RemissionLine: Record "FSN Remission Line";
        FlowFieldBuffer: Record "LSC FlowField Buffer" temporary;
        UpdateFieldList: Record "Field" temporary;
        TableNodeList: Record "LSC WS Node Buffer" temporary;
        RecRefTemp2: array[32] of RecordRef;
        RemissionMgt: Codeunit "FSN Remission Mgt.";
        _Counter: Integer;
        FSNCompanyInsurer: Record "FSN Company Insurer";
        RemissionHeaderValue: Record "FSN Remission Header";
    begin

        RequestID := 'FSN_POST_REMISSION';
        WSFunc.LoadRequest(pxmlRequest, ReqXml, RequestID, RequestNodeList, ResponseNodeList, ParentNodeIndex, ParentNodeList, BodyNode, Response_Code, Response_Text);

        //Get List of request nodes
        RemissionHeaderTmp.RESET;
        RemissionHeaderTmp.DELETEALL;
        CLEAR(RemissionHeaderTmp);
        RemissionHeaderTmp2.RESET;
        RemissionHeaderTmp2.DELETEALL;
        CLEAR(RemissionHeaderTmp2);

        //Get Tables
        IF Response_Code = '0000' THEN BEGIN
            RecRefTemp.GETTABLE(RemissionHeaderTmp);
            WSFunc.GetTableChildNodes(RequestID, 0, BodyNode, ParentNodeIndex, ParentNodeList, 'FSN Remission Header', RecRefTemp,
              FlowFieldBuffer, 1, UpdateFieldList, Response_Code, Response_Text);
        END;
        IF Response_Code <> '0000' THEN BEGIN
            WSFunc.ErrorResponse(RequestID, ResponseNodeList, Response_Code, Response_Text, gLocalProcess, pxmlResponse);
            EXIT;
        END;

        //Process Request
        IF Response_Code = '0000' THEN BEGIN
            UpdateFieldList.SETRANGE(TableNo, 1);

            ReplCounter := 0;
            RecRefTemp.GETTABLE(RemissionHeaderTmp);
            RecRef.GETTABLE(RemissionHeaderTmp2);
            WSFunc.UpdateTableByTempTable(AddOnly, RecRefTemp, RecRef, ReplCounter, UpdateFieldList);
        END;

        CLEARLASTERROR();
        RemissionMgt.SetRemissionHeaderTempTables(RemissionHeaderTmp2, RequestID);
        IF NOT RemissionMgt.RUN THEN BEGIN
            Response_Code := '0101';
            Response_Text := GETLASTERRORTEXT;
        END ELSE
            RemissionHeaderTmp."No." := RemissionMgt.GetCurrRemission;

        IF Response_Code <> '0000' THEN BEGIN
            WSFunc.ErrorResponse(RequestID, ResponseNodeList, Response_Code, Response_Text, gLocalProcess, pxmlResponse);
            EXIT;
        END;

        //Process Response Doc
        WSFunc.InitParentResNodeList(ResponseNodeList, ParentNodeIndex, ParentNodeList);

        //Respose Tables
        WSFunc.AddChildNodeTableList(RequestID, 1, ParentNodeIndex, ParentNodeList, 'FSN Remission Header', TableNodeList,
          Response_Code, Response_Text);
        IF Response_Code = '0000' THEN BEGIN
            IF TableNodeList.FINDLAST THEN;

            IF RemissionHeader.GET(RemissionHeaderTmp."Document Type", RemissionHeaderTmp."No.") THEN BEGIN
                RemissionHeader.SETRECFILTER;
                RemissionHeader.CALCFIELDS(RemissionHeader.Amount, RemissionHeader."Amount Including VAT",
                  RemissionHeader."Coinsurance Value", RemissionHeader."Document Total", RemissionHeader.Comission,
                  RemissionHeader."Deductible Amount");
                RecRef.GETTABLE(RemissionHeader);
                RecRefTemp2[TableNodeList."Entry No."].OPEN(TableNodeList."Table No.", TRUE);
                WSFunc.CopyTableToTempTable(RecRef, RecRefTemp2[TableNodeList."Entry No."], FlowFieldBuffer);
            END ELSE BEGIN
                Response_Code := '1001';
                Response_Text := STRSUBSTNO(Text101, RemissionHeader.TABLECAPTION, STRSUBSTNO(Text103, RemissionHeaderTmp."Document Type", RemissionHeaderTmp."No."));
            END;
        END;

        IF Response_Code <> '0000' THEN BEGIN
            WSFunc.ErrorResponse(RequestID, ResponseNodeList, Response_Code, Response_Text, gLocalProcess, pxmlResponse);
            EXIT;
        END;

        //Lines
        WSFunc.AddChildNodeTableList(RequestID, 1, ParentNodeIndex, ParentNodeList, 'FSN Remission Line', TableNodeList,
          Response_Code, Response_Text);
        IF Response_Code = '0000' THEN BEGIN
            IF TableNodeList.FINDLAST THEN;

            RemissionLine.RESET;
            RemissionLine.SETRANGE(RemissionLine."Document Type", RemissionHeader."Document Type");
            RemissionLine.SETRANGE(RemissionLine."Document No.", RemissionHeader."No.");
            IF RemissionLine.FIND('-') THEN BEGIN
                RecRef.GETTABLE(RemissionLine);
                RecRefTemp2[TableNodeList."Entry No."].OPEN(TableNodeList."Table No.", TRUE);
                WSFunc.CopyTableToTempTable(RecRef, RecRefTemp2[TableNodeList."Entry No."], FlowFieldBuffer);
            END ELSE BEGIN
                Response_Code := '1001';
                Response_Text := STRSUBSTNO(Text101, RemissionLine.TABLECAPTION, STRSUBSTNO(Text103, RemissionHeader."Document Type", RemissionHeader."No."));
            END;
        END;

        //Response
        WSFunc.CreateResponse(ResXml, RequestID, ResponseNodeList, BodyNode);

        //Set Tables
        TableNodeList.RESET;
        IF TableNodeList.FIND('-') THEN
            REPEAT
                WSFunc.SetTableChildNodes(RequestID, 1, BodyNode, ParentNodeIndex, ParentNodeList, TableNodeList.Source,
                  RecRefTemp2[TableNodeList."Entry No."], FlowFieldBuffer, Response_Code, Response_Text);
            UNTIL (TableNodeList.NEXT = 0) OR (Response_Code <> '0000');

        IF Response_Code <> '0000' THEN BEGIN
            WSFunc.ErrorResponse(RequestID, ResponseNodeList, Response_Code, Response_Text, gLocalProcess, pxmlResponse);
            EXIT;
        END;
        resXml.WriteTo(pxmlResponse);

        if RemissionHeaderValue.Get(RemissionHeader."Document Type", RemissionHeader."No.") then begin
            IF FSNCompanyInsurer.Get(RemissionHeaderValue."Company No.") AND (FSNCompanyInsurer.Policy = 'CERRADO') THEN begin
                RemissionHeaderValue."Posting Date" := TODAY;
                RemissionHeaderValue.Status := RemissionHeaderValue.Status::Exclude;
                RemissionHeaderValue.ModifyTrigger();
                RemissionHeaderValue.Modify(true);
            end;
        end;
    end;


    procedure ReturnStatusRemission(var pxmlRequest: Text; var pxmlResponse: Text)
    var
        ReqXml: XmlDocument;
        ResXml: XmlDocument;
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
        RemissionHeaderTmp: Record "FSN Remission Header" temporary;
        RemissionHeaderTmp2: Record "FSN Remission Header" temporary;
        RemissionLineTmp: Record "FSN Remission Line" temporary;
        RecRef: RecordRef;
        RemissionHeader: Record "FSN Remission Header";
        RemissionLine: Record "FSN Remission Line";
        FlowFieldBuffer: Record "LSC FlowField Buffer" temporary;
        UpdateFieldList: Record "Field" temporary;
        TableNodeList: Record "LSC WS Node Buffer" temporary;
        RecRefTemp2: array[32] of RecordRef;
        RemissionMgt: Codeunit "FSN Remission Mgt.";
        _Counter: Integer;
    begin

        RequestID := 'FSN_RETURN_STATUS_REMISSION';
        WSFunc.LoadRequest(pxmlRequest, ReqXml, RequestID, RequestNodeList, ResponseNodeList, ParentNodeIndex, ParentNodeList, BodyNode, Response_Code, Response_Text);

        //Get List of request nodes
        RemissionHeaderTmp.RESET;
        RemissionHeaderTmp.DELETEALL;
        CLEAR(RemissionHeaderTmp);
        RemissionHeaderTmp2.RESET;
        RemissionHeaderTmp2.DELETEALL;
        CLEAR(RemissionHeaderTmp2);

        //Get Tables
        IF Response_Code = '0000' THEN BEGIN
            RecRefTemp.GETTABLE(RemissionHeaderTmp);
            WSFunc.GetTableChildNodes(RequestID, 0, BodyNode, ParentNodeIndex, ParentNodeList, 'FSN Remission Header', RecRefTemp,
              FlowFieldBuffer, 1, UpdateFieldList, Response_Code, Response_Text);
        END;
        IF Response_Code <> '0000' THEN BEGIN
            WSFunc.ErrorResponse(RequestID, ResponseNodeList, Response_Code, Response_Text, gLocalProcess, pxmlResponse);
            EXIT;
        END;

        //Process Request
        IF Response_Code = '0000' THEN BEGIN
            UpdateFieldList.SETRANGE(TableNo, 1);

            ReplCounter := 0;
            RecRefTemp.GETTABLE(RemissionHeaderTmp);
            RecRef.GETTABLE(RemissionHeaderTmp2);
            WSFunc.UpdateTableByTempTable(AddOnly, RecRefTemp, RecRef, ReplCounter, UpdateFieldList);
        END;

        CLEARLASTERROR();
        RemissionMgt.SetRemissionHeaderTempTables(RemissionHeaderTmp2, RequestID);
        IF NOT RemissionMgt.RUN THEN BEGIN
            Response_Code := '0101';
            Response_Text := GETLASTERRORTEXT;
        END ELSE
            RemissionHeaderTmp."No." := RemissionMgt.GetCurrRemission;

        IF Response_Code <> '0000' THEN BEGIN
            WSFunc.ErrorResponse(RequestID, ResponseNodeList, Response_Code, Response_Text, gLocalProcess, pxmlResponse);
            EXIT;
        END;

        //Process Response Doc
        WSFunc.InitParentResNodeList(ResponseNodeList, ParentNodeIndex, ParentNodeList);

        //Respose Tables
        WSFunc.AddChildNodeTableList(RequestID, 1, ParentNodeIndex, ParentNodeList, 'FSN Remission Header', TableNodeList,
          Response_Code, Response_Text);
        IF Response_Code = '0000' THEN BEGIN
            IF TableNodeList.FINDLAST THEN;

            IF RemissionHeader.GET(RemissionHeaderTmp."Document Type", RemissionHeaderTmp."No.") THEN BEGIN
                RemissionHeader.SETRECFILTER;
                RemissionHeader.CALCFIELDS(RemissionHeader.Amount, RemissionHeader."Amount Including VAT",
                  RemissionHeader."Coinsurance Value", RemissionHeader."Document Total", RemissionHeader.Comission,
                  RemissionHeader."Deductible Amount");
                RecRef.GETTABLE(RemissionHeader);
                RecRefTemp2[TableNodeList."Entry No."].OPEN(TableNodeList."Table No.", TRUE);
                WSFunc.CopyTableToTempTable(RecRef, RecRefTemp2[TableNodeList."Entry No."], FlowFieldBuffer);
            END ELSE BEGIN
                Response_Code := '1001';
                Response_Text := STRSUBSTNO(Text101, RemissionHeader.TABLECAPTION, STRSUBSTNO(Text103, RemissionHeaderTmp."Document Type", RemissionHeaderTmp."No."));
            END;
        END;

        IF Response_Code <> '0000' THEN BEGIN
            WSFunc.ErrorResponse(RequestID, ResponseNodeList, Response_Code, Response_Text, gLocalProcess, pxmlResponse);
            EXIT;
        END;

        //Lines
        WSFunc.AddChildNodeTableList(RequestID, 1, ParentNodeIndex, ParentNodeList, 'FSN Remission Line', TableNodeList,
          Response_Code, Response_Text);
        IF Response_Code = '0000' THEN BEGIN
            IF TableNodeList.FINDLAST THEN;

            RemissionLine.RESET;
            RemissionLine.SETRANGE(RemissionLine."Document Type", RemissionHeader."Document Type");
            RemissionLine.SETRANGE(RemissionLine."Document No.", RemissionHeader."No.");
            IF RemissionLine.FIND('-') THEN BEGIN
                RecRef.GETTABLE(RemissionLine);
                RecRefTemp2[TableNodeList."Entry No."].OPEN(TableNodeList."Table No.", TRUE);
                WSFunc.CopyTableToTempTable(RecRef, RecRefTemp2[TableNodeList."Entry No."], FlowFieldBuffer);
            END ELSE BEGIN
                Response_Code := '1001';
                Response_Text := STRSUBSTNO(Text101, RemissionLine.TABLECAPTION, STRSUBSTNO(Text103, RemissionHeader."Document Type", RemissionHeader."No."));
            END;
        END;

        //Response
        WSFunc.CreateResponse(ResXml, RequestID, ResponseNodeList, BodyNode);

        //Set Tables
        TableNodeList.RESET;
        IF TableNodeList.FIND('-') THEN
            REPEAT
                WSFunc.SetTableChildNodes(RequestID, 1, BodyNode, ParentNodeIndex, ParentNodeList, TableNodeList.Source,
                  RecRefTemp2[TableNodeList."Entry No."], FlowFieldBuffer, Response_Code, Response_Text);
            UNTIL (TableNodeList.NEXT = 0) OR (Response_Code <> '0000');

        IF Response_Code <> '0000' THEN BEGIN
            WSFunc.ErrorResponse(RequestID, ResponseNodeList, Response_Code, Response_Text, gLocalProcess, pxmlResponse);
            EXIT;
        END;
        resXml.WriteTo(pxmlResponse);
    end;


    procedure VoidRemission(var pxmlRequest: Text; var pxmlResponse: Text)
    var
        ReqXml: XmlDocument;
        ResXml: XmlDocument;
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
        RemissionHeaderTmp: Record "FSN Remission Header" temporary;
        RemissionHeaderTmp2: Record "FSN Remission Header" temporary;
        RemissionLineTmp: Record "FSN Remission Line" temporary;
        RecRef: RecordRef;
        RemissionHeader: Record "FSN Remission Header";
        RemissionLine: Record "FSN Remission Line";
        FlowFieldBuffer: Record "LSC FlowField Buffer" temporary;
        UpdateFieldList: Record "Field" temporary;
        TableNodeList: Record "LSC WS Node Buffer" temporary;
        RecRefTemp2: array[32] of RecordRef;
        RemissionMgt: Codeunit "FSN Remission Mgt.";
        _Counter: Integer;
    begin

        RequestID := 'FSN_VOID_REMISSION';
        WSFunc.LoadRequest(pxmlRequest, ReqXml, RequestID, RequestNodeList, ResponseNodeList, ParentNodeIndex, ParentNodeList, BodyNode, Response_Code, Response_Text);

        //Get List of request nodes
        RemissionHeaderTmp.RESET;
        RemissionHeaderTmp.DELETEALL;
        CLEAR(RemissionHeaderTmp);
        RemissionHeaderTmp2.RESET;
        RemissionHeaderTmp2.DELETEALL;
        CLEAR(RemissionHeaderTmp2);

        //Get Tables
        IF Response_Code = '0000' THEN BEGIN
            RecRefTemp.GETTABLE(RemissionHeaderTmp);
            WSFunc.GetTableChildNodes(RequestID, 0, BodyNode, ParentNodeIndex, ParentNodeList, 'FSN Remission Header', RecRefTemp,
              FlowFieldBuffer, 1, UpdateFieldList, Response_Code, Response_Text);
        END;
        IF Response_Code <> '0000' THEN BEGIN
            WSFunc.ErrorResponse(RequestID, ResponseNodeList, Response_Code, Response_Text, gLocalProcess, pxmlResponse);
            EXIT;
        END;

        //Process Request
        IF Response_Code = '0000' THEN BEGIN
            UpdateFieldList.SETRANGE(TableNo, 1);

            ReplCounter := 0;
            RecRefTemp.GETTABLE(RemissionHeaderTmp);
            RecRef.GETTABLE(RemissionHeaderTmp2);
            WSFunc.UpdateTableByTempTable(AddOnly, RecRefTemp, RecRef, ReplCounter, UpdateFieldList);
        END;

        CLEARLASTERROR();
        RemissionMgt.SetRemissionHeaderTempTables(RemissionHeaderTmp2, RequestID);
        IF NOT RemissionMgt.RUN THEN BEGIN
            Response_Code := '0101';
            Response_Text := GETLASTERRORTEXT;
        END ELSE
            RemissionHeaderTmp."No." := RemissionMgt.GetCurrRemission;

        IF Response_Code <> '0000' THEN BEGIN
            WSFunc.ErrorResponse(RequestID, ResponseNodeList, Response_Code, Response_Text, gLocalProcess, pxmlResponse);
            EXIT;
        END;

        //Process Response Doc
        WSFunc.InitParentResNodeList(ResponseNodeList, ParentNodeIndex, ParentNodeList);

        //Respose Tables
        WSFunc.AddChildNodeTableList(RequestID, 1, ParentNodeIndex, ParentNodeList, 'FSN Remission Header', TableNodeList,
          Response_Code, Response_Text);
        IF Response_Code = '0000' THEN BEGIN
            IF TableNodeList.FINDLAST THEN;

            IF RemissionHeader.GET(RemissionHeaderTmp."Document Type", RemissionHeaderTmp."No.") THEN BEGIN
                RemissionHeader.SETRECFILTER;
                RemissionHeader.CALCFIELDS(RemissionHeader.Amount, RemissionHeader."Amount Including VAT",
                  RemissionHeader."Coinsurance Value", RemissionHeader."Document Total", RemissionHeader.Comission,
                  RemissionHeader."Deductible Amount");
                RecRef.GETTABLE(RemissionHeader);
                RecRefTemp2[TableNodeList."Entry No."].OPEN(TableNodeList."Table No.", TRUE);
                WSFunc.CopyTableToTempTable(RecRef, RecRefTemp2[TableNodeList."Entry No."], FlowFieldBuffer);
            END ELSE BEGIN
                Response_Code := '1001';
                Response_Text := STRSUBSTNO(Text101, RemissionHeader.TABLECAPTION, STRSUBSTNO(Text103, RemissionHeaderTmp."Document Type", RemissionHeaderTmp."No."));
            END;
        END;

        IF Response_Code <> '0000' THEN BEGIN
            WSFunc.ErrorResponse(RequestID, ResponseNodeList, Response_Code, Response_Text, gLocalProcess, pxmlResponse);
            EXIT;
        END;

        //Lines
        WSFunc.AddChildNodeTableList(RequestID, 1, ParentNodeIndex, ParentNodeList, 'FSN Remission Line', TableNodeList,
          Response_Code, Response_Text);
        IF Response_Code = '0000' THEN BEGIN
            IF TableNodeList.FINDLAST THEN;

            RemissionLine.RESET;
            RemissionLine.SETRANGE(RemissionLine."Document Type", RemissionHeader."Document Type");
            RemissionLine.SETRANGE(RemissionLine."Document No.", RemissionHeader."No.");
            IF RemissionLine.FIND('-') THEN BEGIN
                RecRef.GETTABLE(RemissionLine);
                RecRefTemp2[TableNodeList."Entry No."].OPEN(TableNodeList."Table No.", TRUE);
                WSFunc.CopyTableToTempTable(RecRef, RecRefTemp2[TableNodeList."Entry No."], FlowFieldBuffer);
            END ELSE BEGIN
                Response_Code := '1001';
                Response_Text := STRSUBSTNO(Text101, RemissionLine.TABLECAPTION, STRSUBSTNO(Text103, RemissionHeader."Document Type", RemissionHeader."No."));
            END;
        END;

        //Response
        WSFunc.CreateResponse(ResXml, RequestID, ResponseNodeList, BodyNode);

        //Set Tables
        TableNodeList.RESET;
        IF TableNodeList.FIND('-') THEN
            REPEAT
                WSFunc.SetTableChildNodes(RequestID, 1, BodyNode, ParentNodeIndex, ParentNodeList, TableNodeList.Source,
                  RecRefTemp2[TableNodeList."Entry No."], FlowFieldBuffer, Response_Code, Response_Text);
            UNTIL (TableNodeList.NEXT = 0) OR (Response_Code <> '0000');

        IF Response_Code <> '0000' THEN BEGIN
            WSFunc.ErrorResponse(RequestID, ResponseNodeList, Response_Code, Response_Text, gLocalProcess, pxmlResponse);
            EXIT;
        END;
        resXml.WriteTo(pxmlResponse);
    end;


    procedure GetRemissionHeader(var pxmlRequest: Text; var pxmlResponse: Text)
    var
        ReqXml: XmlDocument;
        ResXml: XmlDocument;
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
        RemissionHeaderTmp: Record "FSN Remission Header" temporary;
        RemissionHeaderTmp2: Record "FSN Remission Header" temporary;
        RemissionLineTmp: Record "FSN Remission Line" temporary;
        RecRef: RecordRef;
        RemissionHeader: Record "FSN Remission Header";
        RemissionLine: Record "FSN Remission Line";
        FlowFieldBuffer: Record "LSC FlowField Buffer" temporary;
        UpdateFieldList: Record "Field" temporary;
        TableNodeList: Record "LSC WS Node Buffer" temporary;
        RecRefTemp2: array[32] of RecordRef;
        RemissionMgt: Codeunit "FSN Remission Mgt.";
        _Counter: Integer;
    begin

        RequestID := 'FSN_GET_REMISSION_HEADER';
        WSFunc.LoadRequest(pxmlRequest, ReqXml, RequestID, RequestNodeList, ResponseNodeList, ParentNodeIndex, ParentNodeList, BodyNode, Response_Code, Response_Text);

        //Get List of request nodes
        RemissionHeaderTmp.RESET;
        RemissionHeaderTmp.DELETEALL;
        CLEAR(RemissionHeaderTmp);
        RemissionHeaderTmp2.RESET;
        RemissionHeaderTmp2.DELETEALL;
        CLEAR(RemissionHeaderTmp2);

        //Get Tables
        IF Response_Code = '0000' THEN BEGIN
            RecRefTemp.GETTABLE(RemissionHeaderTmp);
            WSFunc.GetTableChildNodes(RequestID, 0, BodyNode, ParentNodeIndex, ParentNodeList, 'FSN Remission Header', RecRefTemp,
              FlowFieldBuffer, 1, UpdateFieldList, Response_Code, Response_Text);
        END;
        IF Response_Code <> '0000' THEN BEGIN
            WSFunc.ErrorResponse(RequestID, ResponseNodeList, Response_Code, Response_Text, gLocalProcess, pxmlResponse);
            EXIT;
        END;

        //Process Request
        IF Response_Code = '0000' THEN BEGIN
            UpdateFieldList.SETRANGE(TableNo, 1);

            ReplCounter := 0;
            RecRefTemp.GETTABLE(RemissionHeaderTmp);
            RecRef.GETTABLE(RemissionHeaderTmp2);
            WSFunc.UpdateTableByTempTable(AddOnly, RecRefTemp, RecRef, ReplCounter, UpdateFieldList);
        END;


        CLEARLASTERROR();
        RemissionMgt.SetRemissionHeaderTempTables(RemissionHeaderTmp2, RequestID);

        IF Response_Code <> '0000' THEN BEGIN
            WSFunc.ErrorResponse(RequestID, ResponseNodeList, Response_Code, Response_Text, gLocalProcess, pxmlResponse);
            EXIT;
        END;

        //Process Response Doc
        WSFunc.InitParentResNodeList(ResponseNodeList, ParentNodeIndex, ParentNodeList);

        //Respose Tables
        WSFunc.AddChildNodeTableList(RequestID, 1, ParentNodeIndex, ParentNodeList, 'FSN Remission Header', TableNodeList,
          Response_Code, Response_Text);
        IF Response_Code = '0000' THEN BEGIN
            IF TableNodeList.FINDLAST THEN;

            IF RemissionHeader.GET(RemissionHeaderTmp2."Document Type", RemissionHeaderTmp2."No.") THEN BEGIN
                RemissionHeader.SETRECFILTER;

                RemissionHeader.Amount := RemissionMgt.GetRemissionAmount(RemissionHeader."Document Type", RemissionHeader."No.");
                RemissionHeader."Amount Including VAT" := RemissionMgt.GetRemissionAmountIncVAT(RemissionHeader."Document Type", RemissionHeader."No.");
                RemissionHeader."Deductible Manual" := RemissionMgt.GetRemissionManualDeductible(RemissionHeader."Document Type", RemissionHeader."No.");
                RemissionHeader."Document Total" := RemissionHeader."Amount Including VAT";
                RemissionHeader.Comission := RemissionMgt.GetRemissionComission(RemissionHeader."Document Type", RemissionHeader."No.");
                RemissionHeader."Deductible Amount" := RemissionHeader."Deductible Manual";
                RecRef.GETTABLE(RemissionHeader);

                //WVILLALTA Set FlowField Manual
                IF NOT FlowFieldBuffer.GET(DATABASE::"FSN Remission Header", RecRef.RECORDID, RemissionHeader.FIELDNO("Coinsurance Value")) THEN BEGIN
                    FlowFieldBuffer."Table No." := DATABASE::"FSN Remission Header";
                    FlowFieldBuffer.Key := RecRef.RECORDID;
                    FlowFieldBuffer."Field No." := RemissionHeader.FIELDNO("Coinsurance Value");
                    FlowFieldBuffer."Decimal Value" := RemissionMgt.GetRemissionCoinsurance(RemissionHeader."Document Type", RemissionHeader."No.");
                    FlowFieldBuffer.INSERT;
                END;
                IF NOT FlowFieldBuffer.GET(DATABASE::"FSN Remission Header", RecRef.RECORDID, RemissionHeader.FIELDNO(Comission)) THEN BEGIN
                    FlowFieldBuffer."Table No." := DATABASE::"FSN Remission Header";
                    FlowFieldBuffer.Key := RecRef.RECORDID;
                    FlowFieldBuffer."Field No." := RemissionHeader.FIELDNO(Comission);
                    FlowFieldBuffer."Decimal Value" := RemissionMgt.GetRemissionComission(RemissionHeader."Document Type", RemissionHeader."No.");
                    FlowFieldBuffer.INSERT;
                END;

                RecRefTemp2[TableNodeList."Entry No."].OPEN(TableNodeList."Table No.", TRUE);
                WSFunc.CopyTableToTempTable(RecRef, RecRefTemp2[TableNodeList."Entry No."], FlowFieldBuffer);
            END ELSE BEGIN
                Response_Code := '1001';
                Response_Text := STRSUBSTNO(Text101, RemissionHeader.TABLECAPTION, STRSUBSTNO(Text103, RemissionHeaderTmp."Document Type", RemissionHeaderTmp."No."));
            END;
        END;

        IF Response_Code <> '0000' THEN BEGIN
            WSFunc.ErrorResponse(RequestID, ResponseNodeList, Response_Code, Response_Text, gLocalProcess, pxmlResponse);
            EXIT;
        END;

        //Response
        WSFunc.CreateResponse(ResXml, RequestID, ResponseNodeList, BodyNode);

        //Set Tables
        TableNodeList.RESET;
        IF TableNodeList.FIND('-') THEN
            REPEAT
                WSFunc.SetTableChildNodes(RequestID, 1, BodyNode, ParentNodeIndex, ParentNodeList, TableNodeList.Source,
                  RecRefTemp2[TableNodeList."Entry No."], FlowFieldBuffer, Response_Code, Response_Text);
            UNTIL (TableNodeList.NEXT = 0) OR (Response_Code <> '0000');

        IF Response_Code <> '0000' THEN BEGIN
            WSFunc.ErrorResponse(RequestID, ResponseNodeList, Response_Code, Response_Text, gLocalProcess, pxmlResponse);
            EXIT;
        END;
        resXml.WriteTo(pxmlResponse);
    end;
}


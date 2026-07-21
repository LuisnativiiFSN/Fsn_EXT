codeunit 50097 "FSN Global Record Infocode"
{
    SingleInstance = true;
    TableNo = "LSC POS Menu Line";

    trigger OnRun()
    begin
        GlobalRec.COPY(Rec);
        case "Pos Event Type" of
            "Pos Event Type"::BUTTONPRESS:
                CASE Command OF
                    'DEL-INFO-SAVE':
                        DelZoomInfoOnValidate(Rec);
                    'DEL-ZOOM-INFO':
                        ShowPanel();//DelZoomInfo(Rec);
                END;
            "Pos Event Type"::ZOOMFIELDVALIDATION:
                DelZoomInfoOnValidate(Rec);

        end;

        IF "Pos Event Type" = "Pos Event Type"::ZOOMFIELDVALIDATION THEN
            DelZoomInfoOnValidate(Rec);
    end;

    var
        GlobalRec: Record "LSC POS Menu Line";
        GlobalSalesOrderTmp: Record "FSN Instruccion" temporary;
        PanelSalesOrderTmp: Record "FSN Instruccion" temporary;
        DelOrderInfoTmp: Record "LSC Delivery Order" temporary;
        POSCardEntryTmp: Record "LSC POS Card Entry" temporary;
        RecRefTmp: RecordRef;
        RecRefData: RecordRef;
        WSFunc: Codeunit "LSC WS Functions";
        POSCtrl: Codeunit "LSC POS Control Interface";
        POSGUI: Codeunit "LSC POS GUI";
        EPosControlEvent: Codeunit "LSC POS Control Event";
        EPOSCtrlFunct: Codeunit "LSC POS Zoom Functions";
        GlobalTokenDAF: Text;
        GlobalLastTimeTokenDAF: Time;
        GlobalLastDateTokenDAF: Date;
        Text001: Label 'None';
        Text002: Label 'Mixto';
        Text003: Label 'Ticket';
        Text004: Label 'Cant be fiscal credit';
        Text005: Label 'Customer request %1';
        Text006: Label 'Need customer in transaction. Document type %1';
        PosFunc: Codeunit "LSC POS Functions";
        receiptNo: Code[20];
        RecRef_g: RecordRef;
        PosGui_g: Codeunit "LSC POS GUI";
        PosContext_g: Codeunit "LSC POS Context";
        PosCtrl_g: Codeunit "LSC POS Control Interface";
        PosSession_g: Codeunit "LSC POS Session";
        WebServicesClient_g: Codeunit "LSC Web Services Client";
        InstruccionContactTEMP_g: Record "FSN Instruccion" temporary;
        NewRecord_g: Boolean;
        xRecAccountNo_g: Code[20];
        xRecContactNo_g: Code[20];
        BasicInfoMemberContactTEMP_g: Record "FSN Instruccion" temporary;
        ContactRecZoomCtrlID_g: Code[20];
        ContactDataTableID_g: Code[20];
        ReciboNo: Code[20];

    procedure SetRecTmp(pRecRefTmp: RecordRef)
    var
        UpdateFieldList_l: Record "Field" temporary;
    begin

        IF pRecRefTmp.NUMBER = DATABASE::"FSN Instruccion" THEN BEGIN
            GlobalSalesOrderTmp.RESET;
            GlobalSalesOrderTmp.DELETEALL;
            RecRefTmp.GETTABLE(GlobalSalesOrderTmp);
            WSFunc.UpdateTableByTempTable(TRUE, pRecRefTmp, RecRefTmp, 0, UpdateFieldList_l);
        END;
    end;

    procedure GetRecTmp(var pRecRefTmp: RecordRef; pTableNo: Integer)
    begin
        IF pTableNo = DATABASE::"FSN Instruccion" THEN
            pRecRefTmp.GETTABLE(GlobalSalesOrderTmp);
    end;

    procedure ShowPanel()
    var
        result: Boolean;
    begin
        ShowSpecificPanel('#INTRUCCION');
    end;

    procedure ShowSpecificPanel(PanelID: code[20])
    var
        FuncProfile_g: Record "LSC POS Func. Profile";
        Cliente_p: code[20];
    begin
        ReciboNo := GlobalRec."Current-RECEIPT";
        FuncProfile_g.Get(PosSession_g.FunctionalityProfileID);
        WebServicesClient_g.SetPosFuncProfile(FuncProfile_g);
        GetValuesFromTable(PanelSalesOrderTmp);

        ShowRecZoom(RecRefData, DelZoomInfoEditID, DelZoomInfoEditID, TRUE);
        Commit();
        DelZoomInfoDelivery(true);
        // SetInfo(true);
        PosCtrl_g.ShowPanelModal(PanelID);
    end;

    local procedure ShowRecZoom(RecRefTable: RecordRef; ZoomControlID: code[20]; DataTableID: code[20]; allowEdit: boolean)
    begin
        RecRefTable.GetTable(PanelSalesOrderTmp);
        PosCtrl_g.ShowRecordZoom(RecRefTable, ZoomControlID, DataTableID, true);
        //SetInfo(false);
        DelZoomInfoDelivery(false);
    end;

    local procedure GetDeliveryOrderInfo(): Boolean;
    begin
        if BasicInfoMemberContactTEMP_g."FSN Comentario 1" <> '' then begin
            InstruccionContactTEMP_g.TransferFields(BasicInfoMemberContactTEMP_g);
            exit(true);
        end;
        exit(False);
    end;

    local procedure SetInfo(SendContext_p: Boolean)
    var
        Info_1: Text;
        Info_2: Text;
        Info_3: Text;
        Info_4: Text;
        Info_5: Text;
    begin

        Info_1 := 'tel';
        Info_2 := 'Nom';
        Info_3 := 'MedP';
        Info_4 := 'Dir';
        Info_5 := 'Inst';
        PosContext_g.SetKeyValue('<#INFO1>', Info_1);
        PosContext_g.SetKeyValue('<#INFO2>', Info_2);
        PosContext_g.SetKeyValue('<#INFO3>', Info_3);
        PosContext_g.SetKeyValue('<#INFO4>', Info_4);
        PosContext_g.SetKeyValue('<#INFO5>', Info_5);

        if SendContext_p then
            PosCtrl_g.SendContext(PosContext_g)
        else
            PosCtrl_g.AddContext(PosContext_g);
    end;


    local procedure DelZoomInfoDelivery(SendContext_p: Boolean)
    var
        DelOrder: Record "LSC Delivery Order";
        RecRefLocal: RecordRef;
    begin
        DelOrderInfoTmp.RESET;
        CLEAR(DelOrderInfoTmp);
        RecRefLocal.GETTABLE(DelOrderInfoTmp);
        IF RecRefLocal.ISTEMPORARY THEN
            RecRefLocal.DELETEALL;

        IF DelOrder.GET(ReciboNo) THEN BEGIN
            DelOrderInfoTmp := DelOrder;

            PosContext_g.SetKeyValue('<#INFO1>', DelOrder."Phone No."); //telefono
            PosContext_g.SetKeyValue('<#INFO2>', DelOrder.Name); //Nombre
            PosContext_g.SetKeyValue('<#INFO3>', Format(DelOrder."Tender Type")); //medio pago//None,Cash,Card,Invoice,Prepaid,Mixto
            PosContext_g.SetKeyValue('<#INFO4>', DelOrder.Address); //Direccion
            PosContext_g.SetKeyValue('<#INFO5>', DelOrder."FSN DS Restriction"); //Instrccion

            if SendContext_p then
                PosCtrl_g.SendContext(PosContext_g)
            else
                PosCtrl_g.AddContext(PosContext_g);
            DelOrderInfoTmp.INSERT;
        END;
    end;

    local procedure DelZoomInformation(var pSalesOrderTmp: Record "FSN Instruccion" temporary): Boolean
    var
        PosTrans: Record "LSC POS Transaction";
        TenderTypeSetup: Record "LSC Tender Type Setup";
        PosLines: Record "LSC POS Trans. Line";
        pDelOrder: Record "LSC Delivery Order";
        POSInfo: Record "LSC POS Trans. Infocode Entry";
        PosTransLine: Record "LSC POS Trans. Line";
        TextValue: Text;
    begin
        pSalesOrderTmp.Reset();
        pSalesOrderTmp.DELETEALL;
        Clear(pSalesOrderTmp);

        Commit();
        POSCtrl.GetRecordZoomData(RecRefData, DelZoomInfoEditID);
        RecRefData.SETTABLE(PanelSalesOrderTmp);

        CLEAR(PosTransLine);
        PosTransLine.SetRange("Receipt No.", ReciboNo); //filtra por numero de recibo
        PosTransLine.SetRange("Entry Type", PosTransLine."Entry Type"::Payment); //Filtra la linea por forma de pago
        PosTransLine.SetRange("Entry Status", PosTransLine."Entry Status"::" ");//filtra la linea por estado cero - linea activa
        IF not PosTransLine.FindFirst() THEN
            PosTransLine.Init();

        pSalesOrderTmp.ReceiptNo := ReciboNo;
        pSalesOrderTmp.StoreNo := PosTrans."Store No.";
        pSalesOrderTmp."Primary Phone" := PosTrans."Sell-to Contact No.";
        pSalesOrderTmp."First Name" := COPYSTR(PosTrans.Comment, 1, MAXSTRLEN(pSalesOrderTmp."First Name"));
        IF pDelOrder.GET(ReciboNo) THEN BEGIN
            pSalesOrderTmp."Primary Phone" := pDelOrder."Phone No.";
            pSalesOrderTmp."First Name" := COPYSTR(pDelOrder.Name, 1, MAXSTRLEN(pSalesOrderTmp."First Name"));
        END;

        CASE PosTransLine.COUNT OF
            0:
                pSalesOrderTmp.EntryTypeDescription := Text001;
            1:
                BEGIN
                    PosTransLine.FINDFIRST;
                    IF TenderTypeSetup.GET(PosTransLine."Entry Type") THEN
                        pSalesOrderTmp.EntryTypeDescription := TenderTypeSetup.Description;
                END;
            2:
                pSalesOrderTmp.EntryTypeDescription := Text002;
        END;

        TextValue := PanelSalesOrderTmp.StoreNo;
        IF TextValue = PosTrans."Store No." THEN
            TextValue := '';


        POSNewLineFreeText(ReciboNo, 25, TextValue, 2);
        TextValue := PanelSalesOrderTmp."FSN Mensaje 2"; //moto 2
        POSNewLineFreeText(ReciboNo, 26, TextValue, 3);//Private
        TextValue := PanelSalesOrderTmp.Region;
        POSNewLineFreeText(ReciboNo, 27, TextValue, 3);//Private
        TextValue := PanelSalesOrderTmp."FSN Comentario 1"; //comentario 1
        POSNewLineFreeText(ReciboNo, 28, TextValue, 2);
        TextValue := PanelSalesOrderTmp."FSN Comentario 2"; //comentario 2
        POSNewLineFreeText(ReciboNo, 29, TextValue, 2);
        TextValue := PanelSalesOrderTmp."FSN Comentario 3"; //comentario 3
        POSNewLineFreeText(ReciboNo, 30, TextValue, 2);
        TextValue := PanelSalesOrderTmp."FSN Mensaje 1"; //moto 1
        POSNewLineFreeText(ReciboNo, 31, TextValue, 3);//Private

        CASE PanelSalesOrderTmp."Document Type Sales" OF
            PanelSalesOrderTmp."Document Type Sales"::Factura:
                SetDocumentType('Factura', ReciboNo);
            PanelSalesOrderTmp."Document Type Sales"::"Credito Fiscal":
                SetDocumentType('Credito Fiscal', ReciboNo);
            ELSE
                SetDocumentType(' ', ReciboNo);
        END;

        pSalesOrderTmp.SetRange(pSalesOrderTmp.ReceiptNo, ReciboNo);
        if not pSalesOrderTmp.FindFirst() then
            pSalesOrderTmp.INSERT(TRUE)
        ELSE
            pSalesOrderTmp.MODIFY(TRUE);


        EXIT(TRUE);
    end;

    local procedure loadModal(ModalPanel: Code[20]): Boolean
    var
    begin
        PosCtrl.ShowPanelModal(ModalPanel, '');
        exit(true);
    end;

    local procedure GetValuesFromTable(var pSalesOrderTmp: Record "FSN Instruccion" temporary)
    var
        PosTrans: Record "LSC POS Transaction";
        PosLines: Record "LSC POS Trans. Line";
        TextValue: Text;
        WebRequestFunctions: Codeunit "LSC Web Request Functions";
        BufferUtility: Codeunit "LSC Buffer Utility";
        FuncProfile_g: Record "LSC POS Func. Profile";
        PosSession_g: Codeunit "LSC POS Session";
        WebServicesClient_g: Codeunit "LSC Web Services Client";
        instrunccion: Record "FSN Instruccion";
        TenderTypeSetup: Record "LSC Tender Type Setup";
        pDelOrder: Record "LSC Delivery Order";
        POSInfo: Record "LSC POS Trans. Infocode Entry";
        PosTransLine: Record "LSC POS Trans. Line";
    begin
        CLEAR(PosTransLine);
        PosTransLine.SetRange("Receipt No.", ReciboNo); //filtra por numero de recibo
        PosTransLine.SetRange("Entry Type", PosTransLine."Entry Type"::Payment); //Filtra la linea por forma de pago
        PosTransLine.SetRange("Entry Status", PosTransLine."Entry Status"::" ");//filtra la linea por estado cero - linea activa
        IF not PosTransLine.FindFirst() THEN
            PosTransLine.Init();

        pSalesOrderTmp.ReceiptNo := ReciboNo;
        pSalesOrderTmp.StoreNo := PosTrans."Store No.";
        pSalesOrderTmp."Primary Phone" := PosTrans."Sell-to Contact No.";
        pSalesOrderTmp."First Name" := COPYSTR(PosTrans.Comment, 1, MAXSTRLEN(pSalesOrderTmp."First Name"));
        IF pDelOrder.GET(ReciboNo) THEN BEGIN
            pSalesOrderTmp."Primary Phone" := pDelOrder."Phone No.";
            pSalesOrderTmp."First Name" := COPYSTR(pDelOrder.Name, 1, MAXSTRLEN(pSalesOrderTmp."First Name"));
        END;

        CASE PosTransLine.COUNT OF
            0:
                pSalesOrderTmp.EntryTypeDescription := Text001;
            1:
                BEGIN
                    PosTransLine.FINDFIRST;
                    IF TenderTypeSetup.GET(PosTransLine."Entry Type") THEN
                        pSalesOrderTmp.EntryTypeDescription := TenderTypeSetup.Description;
                END;
            2:
                pSalesOrderTmp.EntryTypeDescription := Text002;
        END;

        //Range Comments 25 - 50
        IF PosLines.GET(ReciboNo, 25) THEN
            pSalesOrderTmp.StoreNo := PosLines.Description;
        //IF PosLines.GET(pParameter."Current-RECEIPT",26) THEN
        IF POSInfo.GET(ReciboNo, 0, 26, 'TEXT', 0) THEN
            pSalesOrderTmp."FSN Mensaje 2" := POSInfo.Information;
        //IF PosLines.GET(pParameter."Current-RECEIPT",27) THEN
        IF POSInfo.GET(ReciboNo, 0, 27, 'TEXT', 0) THEN
            pSalesOrderTmp.Region := POSInfo.Information;
        IF PosLines.GET(ReciboNo, 28) THEN
            pSalesOrderTmp."FSN Comentario 1" := PosLines.Description;
        IF PosLines.GET(ReciboNo, 29) THEN
            pSalesOrderTmp."FSN Comentario 2" := PosLines.Description;
        IF PosLines.GET(ReciboNo, 30) THEN
            pSalesOrderTmp."FSN Comentario 3" := PosLines.Description;
        //IF PosLines.GET(pParameter."Current-RECEIPT",31) THEN
        IF POSInfo.GET(ReciboNo, 0, 31, 'TEXT', 0) THEN
            pSalesOrderTmp."FSN Mensaje 1" := POSInfo.Information;

        IF PosLines.GET(ReciboNo, 32) THEN
            pSalesOrderTmp."Document Type Sales" := pSalesOrderTmp."Document Type Sales"::Factura
        ELSE
            IF PosLines.GET(ReciboNo, 33) THEN
                pSalesOrderTmp."Document Type Sales" := pSalesOrderTmp."Document Type Sales"::"Credito Fiscal"
            ELSE
                pSalesOrderTmp."Document Type Sales" := pSalesOrderTmp."Document Type Sales"::" ";

        pSalesOrderTmp.SetRange(pSalesOrderTmp.ReceiptNo, ReciboNo);

    end;

    local procedure DelZoomInfoOnValidate(Parameter: Record "LSC POS Menu Line")
    var
        FieldNumber: Integer;
        FieldValue: Text;
        POSTrans: Record "LSC POS Transaction";
        Custom: Record Customer;
        FASANIServerUtil: Codeunit "FSN Utility"; //Fasani server utility
        TextError_: Text[100];
        Terminal: Record "LSC POS Terminal";
        WebRequestFunctions: Codeunit "LSC Web Request Functions";
        BufferUtility: Codeunit "LSC Buffer Utility";
    begin
        CLEARLASTERROR;
        COMMIT;
        POSCtrl.GetRecordZoomData(RecRefData, DelZoomInfoEditID);
        RecRefData.SETTABLE(PanelSalesOrderTmp);

        FieldValue := GETLASTERRORTEXT;
        IF FieldValue <> '' THEN BEGIN
            POSGUI.PosMessage(COPYSTR(GETLASTERRORTEXT, 1, 250));
            EXIT;
        END;

        DelZoomInformation(PanelSalesOrderTmp);

        IF PanelSalesOrderTmp."Document Type Sales" IN [PanelSalesOrderTmp."Document Type Sales"::"Credito Fiscal",
                                                    PanelSalesOrderTmp."Document Type Sales"::Factura] THEN BEGIN
            POSTrans.GET(PanelSalesOrderTmp.ReceiptNo);
            IF (POSTrans."Customer No." = '') OR NOT (Custom.GET(POSTrans."Customer No.")) THEN BEGIN
                POSGUI.PosMessage(STRSUBSTNO(Text006, FORMAT(PanelSalesOrderTmp."Document Type Sales"::Factura)));
                EXIT;
            END;

            IF NOT FASANIServerUtil.ValidateCustData(Custom, TextError_, FALSE, TRUE) THEN BEGIN
                POSGUI.PosMessage(TextError_);
                EXIT;
            END;
            POSTrans.CALCFIELDS(POSTrans."Gross Amount", POSTrans."Income/Exp. Amount");

            Terminal.GET(POSTrans."POS Terminal No.");
            CASE PanelSalesOrderTmp."Document Type Sales" OF
                PanelSalesOrderTmp."Document Type Sales"::"Credito Fiscal":
                    POSTrans."FSN No. Serie NCF" := Terminal."FSN No. Serie Credito Fiscal";
                PanelSalesOrderTmp."Document Type Sales"::Factura:
                    POSTrans."FSN No. Serie NCF" := Terminal."FSN No. Serie NCF Cons. Final";
            END;

            IF NOT FASANIServerUtil.ValidateTypeDocumentAndCustom(POSTrans,
                  (POSTrans."Gross Amount" + POSTrans."Income/Exp. Amount"), TextError_, TRUE) THEN BEGIN

                POSGUI.PosMessage(TextError_);
                EXIT;
            END;
        END;
        POSCtrl.HidePanel('#INTRUCCION', TRUE);
    end;

    procedure DelZoomInfoEditID(): Code[20]
    begin
        EXIT('#INSTRUCCIONZOOM');
    end;

    procedure ZoomVoucherManual(pPOSCardEntry: Record "LSC POS Card Entry")
    begin
        COMMIT;
        POSCardEntryTmp.RESET;
        POSCardEntryTmp.DELETEALL;

        POSCardEntryTmp := pPOSCardEntry;
        POSCardEntryTmp.INSERT;

        RecRefData.GETTABLE(POSCardEntryTmp);
        POSCtrl.ShowRecordZoom(RecRefData, '#VOUCHERDATA', '#VOUCHERDATA', TRUE);

        IF loadModal('#DEL-VOUCHER') THEN BEGIN
            POSCtrl.GetRecordZoomData(RecRefData, '#VOUCHERDATA');
            RecRefData.SETTABLE(POSCardEntryTmp);
            pPOSCardEntry."Auth.code" := POSCardEntryTmp."Auth.code";
            pPOSCardEntry."EFT Terminal ID" := POSCardEntryTmp."EFT Terminal ID";
            pPOSCardEntry."FSN Print Amount" := POSCardEntryTmp."FSN Print Amount";
            pPOSCardEntry."FSN BIN No." := POSCardEntryTmp."FSN BIN No.";
            IF pPOSCardEntry.MODIFY THEN;
        END;
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

    procedure POSNewLineFreeText(Receipt: Code[20]; LinkNumber: Integer; TextVal: Text; Type: Option Normal,Typology,Payments,Infocode)
    var
        pPOSTrans: Record "LSC POS Transaction";
        pPOSTransLine: Record "LSC POS Trans. Line";
        pNextLine: Integer;
        NewLine: Record "LSC POS Trans. Line";
        POSInfo: Record "LSC POS Trans. Infocode Entry";
        POSSESSION: Codeunit "LSC POS Session";
        Text001: Label 'Error to insert instrucction, field was ocuped for %1';
    begin
        IF NOT pPOSTrans.GET(Receipt) THEN
            EXIT;

        IF TextVal = '' THEN BEGIN
            IF (Type = Type::Payments) AND (LinkNumber <> 0) THEN BEGIN
                pPOSTransLine.RESET;
                pPOSTransLine.SETRANGE(pPOSTransLine."Receipt No.", Receipt);
                pPOSTransLine.SETRANGE(pPOSTransLine."Line No.", LinkNumber);
                pPOSTransLine.SETRANGE(pPOSTransLine."Entry Type", pPOSTransLine."Entry Type"::FreeText);
                pPOSTransLine.SETRANGE(pPOSTransLine."Text Type", pPOSTransLine."Text Type"::"Freetext Input");
                pPOSTransLine.DELETEALL;
            END;
            IF (Type = Type::Infocode) AND (LinkNumber <> 0) THEN BEGIN
                POSInfo.RESET;
                POSInfo.SETRANGE(POSInfo."Receipt No.", Receipt);
                POSInfo.SETRANGE(POSInfo."Transaction Type", 0);
                POSInfo.SETRANGE(POSInfo."Line No.", LinkNumber);
                POSInfo.SETRANGE(POSInfo.Infocode, 'TEXT');
                POSInfo.SETRANGE(POSInfo."Entry Line No.", 0);
                POSInfo.DELETEALL;
            END;
            EXIT;
        END;
        IF (Type = Type::Infocode) AND (LinkNumber <> 0) THEN BEGIN
            POSInfo.INIT;
            POSInfo."Receipt No." := pPOSTrans."Receipt No.";
            POSInfo."Transaction Type" := 0;
            POSInfo."Line No." := LinkNumber;
            POSInfo.Infocode := 'TEXT';
            POSInfo.Information := TextVal;
            POSInfo."Store No." := pPOSTrans."Store No.";
            POSInfo.Date := TODAY();
            POSInfo.Time := TIME();
            POSInfo."POS Terminal No." := pPOSTrans."POS Terminal No.";
            IF pPOSTrans."Sales Staff" <> '' THEN
                POSInfo."Staff ID" := pPOSTrans."Sales Staff"
            ELSE
                POSInfo."Staff ID" := POSSESSION.StaffID;
            IF NOT POSInfo.INSERT(TRUE) THEN
                POSInfo.MODIFY(TRUE);
            EXIT;
        END;

        IF LinkNumber = 0 THEN BEGIN
            pNextLine := 10000;
            pPOSTransLine.RESET;
            pPOSTransLine.SETCURRENTKEY("Receipt No.", "Line No.");
            pPOSTransLine.SETRANGE(pPOSTransLine."Receipt No.", Receipt);
            IF pPOSTransLine.FINDLAST THEN
                pNextLine := pPOSTransLine."Line No." + 10000;
        END ELSE
            pNextLine := LinkNumber;

        IF LinkNumber <> 0 THEN
            IF pPOSTransLine.GET(Receipt, LinkNumber) THEN BEGIN
                IF (pPOSTransLine."Entry Type" <> pPOSTransLine."Entry Type"::FreeText) OR
                  (pPOSTransLine."Text Type" <> pPOSTransLine."Text Type"::"Freetext Input") THEN
                    ERROR(STRSUBSTNO(Text001, FORMAT(pPOSTransLine."Entry Type")));

                IF pPOSTransLine.Description = TextVal THEN
                    EXIT;
                pPOSTransLine.VALIDATE(Description, COPYSTR(TextVal, 1, MAXSTRLEN(pPOSTransLine.Description)));
                pPOSTransLine.MODIFY(TRUE);
                EXIT;
            END;
        CLEAR(NewLine);
        NewLine."Store No." := pPOSTrans."Store No.";
        NewLine."POS Terminal No." := pPOSTrans."POS Terminal No.";
        NewLine."Receipt No." := pPOSTrans."Receipt No.";
        NewLine."Guest/Seat No." := 0;
        NewLine."Restaurant Menu Type" := 0;

        NewLine."Receipt No." := Receipt;
        NewLine."Entry Type" := NewLine."Entry Type"::FreeText;
        NewLine."Text Type" := NewLine."Text Type"::"Freetext Input";
        NewLine.VALIDATE(NewLine.Description, COPYSTR(TextVal, 1, MAXSTRLEN(NewLine.Description)));
        NewLine."Line No." := pNextLine;
        NewLine.INSERT(TRUE);
    end;

    procedure SetDocumentType(pParameter: Code[30]; pReceipt: Code[20])
    var
        pSalesOrder: Record "FSN Instruccion";
        POSTrans: Record "LSC POS Transaction";
        Terminal: Record "LSC POS Terminal";
        FASANIServerUtil: Codeunit "FSN Utility";
        TextError_: Text[150];
        Text002: Label 'Customer request %1';
    begin

        POSTrans.GET(pReceipt);
        POSTrans.CALCFIELDS(POSTrans."Gross Amount", POSTrans."Income/Exp. Amount");

        Terminal.GET(POSTrans."POS Terminal No.");
        CASE pParameter OF
            'Credito Fiscal':
                POSTrans."FSN No. Serie NCF" := Terminal."FSN No. Serie Credito Fiscal";
            'Factura':
                POSTrans."FSN No. Serie NCF" := Terminal."FSN No. Serie NCF Cons. Final";
        END;

        IF NOT FASANIServerUtil.ValidateTypeDocumentAndCustom(POSTrans,
             (POSTrans."Gross Amount" + POSTrans."Income/Exp. Amount"), TextError_, TRUE) THEN BEGIN

            POSGUI.PosMessage(TextError_);
            EXIT;
        END;

        CASE pParameter OF
            ' ':
                BEGIN
                    POSNewLineFreeText(pReceipt, 32, '', 2);
                    POSNewLineFreeText(pReceipt, 33, '', 2);
                END;
            'Factura':
                BEGIN
                    POSNewLineFreeText(pReceipt, 32, STRSUBSTNO(Text002, FORMAT(pSalesOrder."Document Type Sales"::Factura)), 2);
                    POSNewLineFreeText(pReceipt, 33, '', 2);
                END;
            'Credito Fiscal':
                BEGIN
                    POSNewLineFreeText(pReceipt, 32, '', 2);
                    POSNewLineFreeText(pReceipt, 33, STRSUBSTNO(Text002, FORMAT(pSalesOrder."Document Type Sales"::"Credito Fiscal")), 2);
                END;
        END;
    end;
}


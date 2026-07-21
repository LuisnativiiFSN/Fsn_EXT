codeunit 50004 "FSN External Transfer Manager"
{
    TableNo = "LSC Scheduler Job Header";

    trigger OnRun()
    var
        ExTransferM: Codeunit "FSN External Transfer Manager";
        JobH: Record "LSC Scheduler Job Header";
        i: Integer;
    begin

        IF Rec."Code" = 'GETRE' THEN begin
            if rec.Integer > 0 then
                last := Rec.Integer
            else
                last := 50;
            GetReceipts('');
        end;

        if Rec.Code = 'TRANS-AUTO' then begin
            SendAndRegister();
        end;

        if Rec.Code = 'WR-REG' then begin
            RegisterPITSTransfer(Rec.Text);
            exit;
        end;


        if Rec.Code = 'APPLY' THEN BEGIN
            GetReceiptsApply();
            EXIT;
        END;

        if Rec.Code = 'PITS-RCPT' THEN BEGIN
            CreateDirectReceiptsFromPITS(Rec.Text, Rec.Integer);
            EXIT;
        END;

        IF Rec.Code = 'ALL' THEN BEGIN
            JobH.Integer := -1;
            IF ExTransferM.RUN(JobH) THEN;
            JobH.Integer := 0;
            JobH.Code := '';
            JobH.Text := '-4D';
            IF ExTransferM.RUN(JobH) THEN;
            IF ExTransferM.RUN(JobH) THEN;
            IF ExTransferM.RUN(JobH) THEN;
            IF ExTransferM.RUN(JobH) THEN;
            EXIT;
        END;

        IF Rec."Code" = 'DELETE' THEN
            GetDeleteTransferRecordSet
        ELSE
            IF Store.GET(Rec.Code) THEN BEGIN
                StoreSelect_g := Rec.Code;
                FOR i := 1 TO 10 DO
                    GetTransferRecordSet(Rec.Text, Rec.Integer);
            END ELSE begin
                GetTransferRecordSet(Rec.Text, Rec.Integer);
            end;


    end;

    var
        Text000: Label 'Cant be change in field %1 ';
        Text001: Label '%1 Not exists in %2';
        Text002: Label 'Lines not exists in %1';
        Text003: Label 'Debug Error: %1';
        WhseValidateSourceLine: Codeunit "Whse. Validate Source Line";
        ReasonCode_g: Code[10];
        StoreSelect_g: Code[10];
        Store: Record "LSC Store";
        ItemJrnlTemplate_g: Record "Item Journal Template";
        ItemJrnlBatch_g: Record "Item Journal Batch";
        ItemJrnlLine_g: Record "Item Journal Line";
        last: Integer;
        WarehouseReceiptNo: Code[20];
        ConfirRun: Boolean;
        LastError: Text;
        POSSESION: Codeunit "LSC POS Session";

    procedure GetTransferRecordSet(Text: Text[100]; "Integer": Integer)
    var
        QryTransferInvoice: Query "FSN External Transfer Invoice";
        ExternalTransferData_l: Record "PITS_WMScd2suc";
        ExternalTransferHeaders_l: Record PITS_WMScd2sucHeaders;
        TransferHeader_l: Record "Transfer Header";
        WarehouseShipHeader_l: Record "Warehouse Shipment Header";
        WareHouseShipLine_l: Record "Warehouse Shipment Line";
        GetSourceDocOutbound: Codeunit "Get Source Doc. Outbound";
        Ok_Agent, FilterF30 : Boolean;
        WsheShipCode: Code[20];
        ExternalDocument: Code[35];
        LastTransferOrderErrorNo: Code[20];
        ErrorText: Text[150];
        DateFilter: Date;
        i: Integer;
        LevelNo: Integer;
        lText000: Label 'Transfer not completed, error not found';
    begin
        LastTransferOrderErrorNo := '';

        GetDateFilter(Text, DateFilter);

        FilterF30 := Integer = -1;

        IF Integer = 0 THEN
            Integer := 100;
        i := 1;

        IF NOT JrnlInicializeGlobals('TF_REPL', 'DEFAULT', 'TRANSFER', ErrorText) THEN EXIT; //Not used in BC

        CLEAR(QryTransferInvoice);
        QryTransferInvoice.SETRANGE(QryTransferInvoice.Starting_Date, DateFilter, TODAY);
        QryTransferInvoice.SETRANGE(QryTransferInvoice.Completado, FALSE);
        QryTransferInvoice.SETRANGE(QryTransferInvoice.Shipped, TRUE);


        IF FilterF30 THEN
            QryTransferInvoice.SETRANGE(Transfer_to_Code, 'F30')
        ELSE
            IF StoreSelect_g <> '' THEN
                QryTransferInvoice.SETFILTER(Transfer_to_Code, StoreSelect_g);


        QryTransferInvoice.OPEN;
        WHILE QryTransferInvoice.READ AND (i <= Integer) DO BEGIN
            i := i + 1;
            IF (QryTransferInvoice.Remision <> '') AND (QryTransferInvoice.SourceNo = QryTransferInvoice.Shipment) THEN BEGIN //Entry Version 3.0
                Ok_Agent := FALSE;
                ErrorText := '';
                LevelNo := 0;
                ExternalDocument := QryTransferInvoice.Remision;


                IF LastTransferOrderErrorNo <> '' THEN
                    IF LastTransferOrderErrorNo <> QryTransferInvoice.No THEN
                        LastTransferOrderErrorNo := '';

                JrnlClearAll;

                IF LastTransferOrderErrorNo = '' THEN BEGIN

                    RecoveryConsistencyTransfer(QryTransferInvoice.No, ExternalDocument);//Evaluate consistency priority Remision Key

                    IF ExternalDocument = '' THEN
                        ExternalDocument := QryTransferInvoice.Remision;

                    IF ValidateTransferHeader(QryTransferInvoice.No, ErrorText, TransferHeader_l) THEN
                        IF ClearQtyTransferLines(QryTransferInvoice.No, ErrorText) THEN
                            IF SetQtyAndPostLines(TransferHeader_l, ExternalDocument, ErrorText) THEN
                                Ok_Agent := TRUE;

                    IF Ok_Agent THEN
                        ErrorText := ''
                    ELSE BEGIN
                        IF ErrorText = '' THEN
                            ErrorText := lText000;
                        LastTransferOrderErrorNo := QryTransferInvoice.No;
                    END;

                    ExternalTransferData_l.RESET;
                    ExternalTransferData_l.SETCURRENTKEY("Source No.", "Item No.");
                    ExternalTransferData_l.SETRANGE(ExternalTransferData_l."Source No.", QryTransferInvoice.No);
                    ExternalTransferData_l.SETRANGE(ExternalTransferData_l."No. Remision", ExternalDocument);
                    IF Ok_Agent THEN
                        ExternalTransferData_l.MODIFYALL(ExternalTransferData_l.Completado, TRUE);

                    IF ExternalTransferData_l.FINDFIRST THEN
                        IF NOT EVALUATE(LevelNo, ExternalTransferData_l."Shelf No.") THEN
                            LevelNo := 0;

                    ExternalTransferHeaders_l.RESET;
                    ExternalTransferHeaders_l.SETCURRENTKEY(No_, "Source No_", Nivel);
                    ExternalTransferHeaders_l.SETRANGE(ExternalTransferHeaders_l.No_, QryTransferInvoice.No);
                    ExternalTransferHeaders_l.SETRANGE(ExternalTransferHeaders_l."Source No_", QryTransferInvoice.No);
                    ExternalTransferHeaders_l.SETRANGE(ExternalTransferHeaders_l.Nivel, LevelNo);
                    IF NOT ExternalTransferHeaders_l.FINDFIRST THEN
                        ExternalTransferHeaders_l.SETRANGE(ExternalTransferHeaders_l.Nivel);
                    IF NOT ExternalTransferHeaders_l.FINDFIRST THEN
                        ExternalTransferHeaders_l.SETRANGE(ExternalTransferHeaders_l.No_);
                    IF ExternalTransferHeaders_l.FINDFIRST THEN BEGIN
                        IF Ok_Agent THEN BEGIN
                            ExternalTransferHeaders_l."Ultimo Error" := '';
                            ExternalTransferHeaders_l.Completado := Ok_Agent;
                        END ELSE
                            ExternalTransferHeaders_l."Ultimo Error" := COPYSTR(ExternalDocument + ' ' + ErrorText, 1, 150);
                        ExternalTransferHeaders_l.MODIFY(TRUE);
                    END;
                    COMMIT;
                END; //LastOrderError
            END;/* ELSE
                IF (QryTransferInvoice.Remision <> '') AND (QryTransferInvoice.SourceNo <> QryTransferInvoice.Shipment) THEN BEGIN //Entry Version 1.0;
                    UseOldVersion(TRUE, 50, QryTransferInvoice.Shipment);
                END;*///Not used in BC
        END;
        QryTransferInvoice.CLOSE;
    end;

    procedure ValidateTransferHeader(TransferNo: Code[20]; var ErrorText: Text; var TransferHeader_l: Record "Transfer Header"): Boolean
    var
        lText001: Label 'Status Transfer Header cant %1';
    begin
        IF TransferHeader_l.GET(TransferNo) THEN
            IF TransferHeader_l.Status <> TransferHeader_l.Status::Released THEN BEGIN
                ErrorText := STRSUBSTNO(lText001, FORMAT(TransferHeader_l.Status));
                EXIT(FALSE);
            END ELSE
                EXIT(TRUE);

        ErrorText := STRSUBSTNO(Text001, TransferNo, TransferHeader_l.TABLECAPTION);
        EXIT(FALSE);
    end;

    procedure ClearQtyTransferLines(TransferNo: Code[20]; var ErrorText: Text): Boolean
    var
        TransferHeader_l: Record "Transfer Header";
        TransferLine_l: Record "Transfer Line";
    begin
        TransferLine_l.RESET;
        TransferLine_l.SETRANGE(TransferLine_l."Document No.", TransferNo);
        TransferLine_l.SetRange("Derived From Line No.", 0);
        IF NOT TransferLine_l.FINDFIRST THEN
            ErrorText := STRSUBSTNO(Text002, TransferLine_l.TABLECAPTION)
        ELSE
            REPEAT
                TransferLine_l.VALIDATE("Qty. to Ship", 0);
                TransferLine_l.MODIFY(TRUE);
            UNTIL (TransferLine_l.NEXT = 0) OR (ErrorText <> '');
        EXIT(ErrorText = '');
    end;

    procedure SetQtyAndPostLines(pTransferHeader: Record "Transfer Header"; RemisionNo: Code[35]; var ErrorText: Text): Boolean
    var
        TransferLine_l: Record "Transfer Line";
        TransferLine2_l: Record "Transfer Line";
        ExternalTransferLine_l: Record "PITS_WMScd2suc";
        ExternalTransferLine2_l: Record "PITS_WMScd2suc";
        PITSSubLn: Record "PITS Sub Line";
        TransferHeader2_l: Record "Transfer Header";
        Location_l: Record "Location";
        WhseRqst: Record "Warehouse Request";
        WhseRcptHeader: Record "Warehouse Receipt Header";
        WhseRcptLines_l: Record "Warehouse Receipt Line";
        WhseRcptLines2_l: Record "Warehouse Receipt Line";
        GetSourceDocuments: Report "Get Source Documents";
        LocationFilter: Text;
        CreateWsheReceipt: Boolean;
        RecoveryConsistency: Boolean;
        lText004: Label 'No create lines in Warehoouse Receipt No. %1';
        lText005: Label 'Outstanding Quantity must be equal to quantity ordered, Item %1';
        lText001: Label 'Line %1 item is diferent %2 , %3';
        lText002: Label 'External Quantity %1 cant be greater than %2, item %3';
        lText003: Label 'Transfer Line %1 %2 not exists';
    begin
        CreateWsheReceipt := FALSE;
        RecoveryConsistency := FALSE;
        ExternalTransferLine_l.RESET;
        ExternalTransferLine_l.SETCURRENTKEY("No.", TransferComplete, Shipped, Completado);
        ExternalTransferLine_l.SETRANGE(ExternalTransferLine_l."No.", pTransferHeader."No.");
        ExternalTransferLine_l.SETFILTER(ExternalTransferLine_l.Completado, '=%1|=%2', TRUE, FALSE);
        ExternalTransferLine_l.SETRANGE(ExternalTransferLine_l.Shipped, TRUE);
        ExternalTransferLine_l.SETRANGE(ExternalTransferLine_l."No. Remision", RemisionNo);
        if NOT ExternalTransferLine_l.FINDFIRST then
            ErrorText := STRSUBSTNO(Text001, pTransferHeader."No.", ExternalTransferLine_l.TABLECAPTION)
        else
            repeat
                if TransferLine_l.GET(ExternalTransferLine_l."Source No.", ExternalTransferLine_l."Line No.") then begin
                    TransferLine2_l := TransferLine_l;
                    if ExternalTransferLine_l."Item No." <> TransferLine_l."Item No." THEN
                        ErrorText := STRSUBSTNO(lText001, FORMAT(TransferLine_l."Line No."), ExternalTransferLine_l."Item No.", TransferLine_l."Item No.")

                    else
                        if TransferLine_l.Quantity < ExternalTransferLine_l."Qty. to Ship" then
                            ErrorText := STRSUBSTNO(lText002, FORMAT(ExternalTransferLine_l."Qty. to Ship"), FORMAT(TransferLine_l."Outstanding Quantity"), TransferLine_l."Item No.")
                        else
                            if TransferLine_l."Outstanding Quantity" <> TransferLine_l.Quantity then begin //One receipt
                                ErrorText := STRSUBSTNO(lText005, TransferLine_l."Item No.");

                                RecoveryConsistency := RecoveryConsistencyWhsReceipt(TransferLine_l."Document No.", TransferLine_l."Item No.", RemisionNo,
                                                          ErrorText, CreateWsheReceipt);
                            end;

                    if NOT RecoveryConsistency then begin
                        if ErrorText = '' then
                            if CheckWarehouse(TransferLine_l."Transfer-from Code", TRUE, ErrorText, TransferLine_l) then
                                ValidateChangeRecord(TransferLine_l, TransferLine2_l, ErrorText);

                        //JrnlValidateInventory(TransferLine_l."Item No.", TransferLine_l."Transfer-from Code", TransferLine_l."Variant Code",TransferLine_l."Qty. to Ship (Base)", TransferLine_l."Unit of Measure Code", ErrorText);

                        if ErrorText = '' then begin
                            TransferLine_l.Validate(TransferLine_l."Qty. to Ship", ExternalTransferLine_l."Qty. to Ship");
                            TransferLine_l.MODIFY(TRUE);
                            PITSSubLn.Reset();
                            PITSSubLn.SetRange("No.", ExternalTransferLine_l."No.");
                            PITSSubLn.SetRange("Line No.", ExternalTransferLine_l."Line No.");
                            PITSSubLn.SetRange("No. Remision", ExternalTransferLine_l."No. Remision");
                            if PITSSubLn.FindFirst() then
                                repeat begin
                                    SetLoteNoTransfer(pTransferHeader, TransferLine_l, PITSSubLn.Lote, PITSSubLn.Quantity, PITSSubLn."Expiration Date");
                                end until PITSSubLn.Next() = 0;
                        end;
                    end;
                end else
                    ErrorText := STRSUBSTNO(lText003, ExternalTransferLine_l."Source No.", FORMAT(ExternalTransferLine_l."Line No."));
            UNTIL (ExternalTransferLine_l.NEXT = 0) OR (ErrorText <> '') OR RecoveryConsistency;

        IF RecoveryConsistency THEN
            ErrorText := '';

        IF RecoveryConsistency AND NOT CreateWsheReceipt THEN
            EXIT(TRUE);

        //IF ErrorText = '' THEN
        //IF NOT JrnlItemsPost(ErrorText) THEN EXIT(FALSE);

        IF NOT (ErrorText = '') THEN
            EXIT(FALSE)
        ELSE
            IF NOT TransferHeader2_l.GET(pTransferHeader."No.") THEN
                ErrorText := STRSUBSTNO(Text001, pTransferHeader."No.", TransferHeader2_l.TABLECAPTION)
            ELSE BEGIN
                TransferHeader2_l."External Document No." := RemisionNo;
                TransferHeader2_l.MODIFY;

                IF NOT RecoveryConsistency THEN
                    RecoveryConsistency := PostTransferShipment(TransferHeader2_l, ErrorText);

                IF RecoveryConsistency THEN BEGIN
                    WhseRqst.SETRANGE(Type, WhseRqst.Type::Inbound);
                    WhseRqst.SETRANGE("Source Type", DATABASE::"Transfer Line");
                    WhseRqst.SETRANGE("Source Subtype", 1);
                    WhseRqst.SETRANGE("Source No.", TransferHeader2_l."No.");
                    WhseRqst.SETRANGE("Document Status", WhseRqst."Document Status"::Released);
                    IF WhseRqst.FINDSET THEN BEGIN
                        REPEAT
                            IF Location_l.RequireReceive(WhseRqst."Location Code") THEN
                                LocationFilter += WhseRqst."Location Code" + '|';
                        UNTIL WhseRqst.NEXT = 0;
                        IF LocationFilter <> '' THEN
                            LocationFilter := COPYSTR(LocationFilter, 1, STRLEN(LocationFilter) - 1);
                        WhseRqst.SETFILTER("Location Code", LocationFilter);
                    END;

                    IF WhseRqst.FINDFIRST THEN BEGIN
                        if not GuiAllowed then begin
                            ErrorText := 'No se puede ejecutar Get Source Documents en sesion sin UI.';
                            exit(false);
                        end;

                        COMMIT;
                        GetSourceDocuments.SetHideDialog(TRUE);
                        GetSourceDocuments.USEREQUESTPAGE(FALSE);
                        GetSourceDocuments.SETTABLEVIEW(WhseRqst);
                        GetSourceDocuments.RUNMODAL;
                        GetSourceDocuments.GetLastReceiptHeader(WhseRcptHeader);
                    END;

                    IF WhseRcptHeader."No." = '' THEN
                        ErrorText := COPYSTR(STRSUBSTNO(lText003, GETLASTERRORTEXT), 1, 150)
                    ELSE BEGIN
                        WhseRcptLines_l.RESET;
                        WhseRcptLines_l.SETRANGE(WhseRcptLines_l."No.", WhseRcptHeader."No.");
                        IF NOT WhseRcptLines_l.FINDFIRST THEN
                            ErrorText := STRSUBSTNO(lText004, WhseRcptHeader."No.")
                        ELSE BEGIN
                            ExternalTransferLine2_l.RESET;
                            ExternalTransferLine2_l.SETCURRENTKEY("No.", "Line No.");
                            ExternalTransferLine2_l.SETRANGE(ExternalTransferLine2_l."No.", WhseRcptLines_l."Source No.");
                            IF ExternalTransferLine2_l.FINDSET THEN
                                REPEAT
                                    WhseRcptLines2_l.RESET;
                                    WhseRcptLines2_l.SETCURRENTKEY("No.", "Source Type", "Source Subtype", "Source No.", "Source Line No.");
                                    WhseRcptLines2_l.SETRANGE(WhseRcptLines2_l."No.", WhseRcptHeader."No.");
                                    WhseRcptLines2_l.SETRANGE(WhseRcptLines2_l."Source Type", 5741);
                                    WhseRcptLines2_l.SETRANGE(WhseRcptLines2_l."Source Subtype", 1);
                                    WhseRcptLines2_l.SETRANGE(WhseRcptLines2_l."Source No.", ExternalTransferLine2_l."Source No.");
                                    WhseRcptLines2_l.SETRANGE(WhseRcptLines2_l."Source Line No.", ExternalTransferLine2_l."Line No.");
                                    IF WhseRcptLines2_l.FINDFIRST THEN
                                        IF WhseRcptLines2_l."Item No." = ExternalTransferLine2_l."Item No." THEN BEGIN
                                            WhseRcptLines2_l."Sorting Sequence No." := ExternalTransferLine2_l.Order;
                                            IF WhseRcptLines2_l.MODIFY THEN;
                                        END;
                                UNTIL ExternalTransferLine2_l.NEXT = 0;
                        END;
                    END;
                END;
            END;
        EXIT(ErrorText = '');
    end;

    procedure GetDateFilter(Text: Text[100]; var NewDateFilter: Date)
    var
        Int: Integer;
        J: Integer;
        IntEval: Integer;
        DateFilter: Date;
        Ok_: Boolean;
        Done: Boolean;
        Text2: Text[100];
        CacDateFormula: DateFormula;
    begin
        IF Text = '' THEN BEGIN
            NewDateFilter := TODAY - 7;
            EXIT;
        END;
        Text := '<' + Text + '>';
        IF EVALUATE(CacDateFormula, Text) THEN BEGIN
            NewDateFilter := CALCDATE(Text, TODAY);
            IF NewDateFilter > TODAY THEN
                NewDateFilter := TODAY - 7;
        END ELSE
            NewDateFilter := TODAY - 7;
    end;

    local procedure PostTransferShipment(pTransferHeader: Record "Transfer Header"; var ErrorText: Text): Boolean
    var
        TransferPostShipment: Codeunit "TransferOrder-Post Shipment";
    begin
        COMMIT;
        IF NOT CODEUNIT.RUN(CODEUNIT::"TransferOrder-Post Shipment", pTransferHeader) THEN BEGIN
            ErrorText := COPYSTR(GETLASTERRORTEXT, 1, 150);
            EXIT(FALSE);
        END ELSE
            EXIT(TRUE);
    end;

    local procedure CheckWarehouse(TransferFromCode: Code[20]; Receive: Boolean; var ErrorText: Text; CurrTransferLine: Record "Transfer Line"): Boolean
    var
        ShowDialog: Option " ",Message,Error;
        DialogText: Text[50];
        Location: Record "Location";
        WhseValidateSourceLine: Codeunit "Whse. Validate Source Line";
        lText001: Label 'Warehouse %1 is required for %2 = %3.';
        lText002: Label 'You cannot rename a %1. %2';
    begin
        WITH CurrTransferLine DO BEGIN
            IF NOT Location.GET(TransferFromCode) THEN
                ErrorText := STRSUBSTNO(Text001, TransferFromCode, Location.TABLECAPTION);

            IF Location."Directed Put-away and Pick" THEN BEGIN
                ShowDialog := ShowDialog::Error;
                IF Receive THEN
                    DialogText := Location.GetRequirementText(Location.FIELDNO("Require Receive"))
                ELSE
                    DialogText := Location.GetRequirementText(Location.FIELDNO("Require Shipment"));
            END ELSE BEGIN
                IF Receive AND (Location."Require Receive" OR Location."Require Put-away") THEN BEGIN
                    IF WhseValidateSourceLine.WhseLinesExist(
                         DATABASE::"Transfer Line",
                         1,
                         "Document No.",
                         "Line No.",
                         0,
                         Quantity)
                    THEN
                        ShowDialog := ShowDialog::Error
                    ELSE
                        IF Location."Require Receive" THEN
                            ShowDialog := ShowDialog::Message;
                    IF Location."Require Receive" THEN
                        DialogText := Location.GetRequirementText(Location.FIELDNO("Require Receive"))
                    ELSE
                        DialogText := Location.GetRequirementText(Location.FIELDNO("Require Put-away"));
                END;

                IF NOT Receive AND (Location."Require Shipment" OR Location."Require Pick") THEN BEGIN
                    IF WhseValidateSourceLine.WhseLinesExist(
                         DATABASE::"Transfer Line",
                         0,
                         "Document No.",
                         "Line No.",
                         0,
                         Quantity)
                    THEN
                        ShowDialog := ShowDialog::Error
                    ELSE
                        IF Location."Require Shipment" THEN
                            ShowDialog := ShowDialog::Message;
                    IF Location."Require Shipment" THEN
                        DialogText := Location.GetRequirementText(Location.FIELDNO("Require Shipment"))
                    ELSE
                        DialogText := Location.GetRequirementText(Location.FIELDNO("Require Pick"));
                END;
            END;

            CASE ShowDialog OF
                ShowDialog::Message:
                    EXIT(TRUE);
                ShowDialog::Error:
                    BEGIN
                        ErrorText := STRSUBSTNO(lText002, DialogText, FIELDCAPTION("Line No."), "Line No.");
                        EXIT(FALSE);
                    END;
            END;
        END;
    end;

    local procedure ValidateChangeRecord(NewTransLine: Record "Transfer Line"; OldTransLine: Record "Transfer Line"; var ErrorText: Text)
    var
        WhseLineFound: Boolean;
        TableCaptionValue: Text[100];
        lText001: Label 'Can not change value to field %1. Line %2';
    begin
        WITH NewTransLine DO BEGIN
            WhseLineFound := WhseValidateSourceLine.WhseLinesExist(DATABASE::"Transfer Line", 0, "Document No.", "Line No.", 0, Quantity);
            IF NOT WhseLineFound THEN
                WhseLineFound := WhseValidateSourceLine.WhseLinesExist(DATABASE::"Transfer Line", 1, "Document No.", "Line No.", 0, Quantity);
            IF WhseLineFound THEN BEGIN
                IF "Item No." <> OldTransLine."Item No." THEN
                    ErrorText := FIELDCAPTION("Item No.");

                IF "Variant Code" <> OldTransLine."Variant Code" THEN
                    ErrorText := FIELDCAPTION("Variant Code");

                IF "Unit of Measure Code" <> OldTransLine."Unit of Measure Code" THEN
                    ErrorText := FIELDCAPTION("Unit of Measure Code");

                IF Quantity <> OldTransLine.Quantity THEN
                    ErrorText := FIELDCAPTION(Quantity);

                IF "Qty. to Ship" <> OldTransLine."Qty. to Ship" THEN
                    ErrorText := FIELDCAPTION("Qty. to Ship");

                IF "Qty. to Receive" <> OldTransLine."Qty. to Receive" THEN
                    ErrorText := FIELDCAPTION("Qty. to Receive");

            END;
            IF ErrorText <> '' THEN
                ErrorText := STRSUBSTNO(lText001, ErrorText, FORMAT(OldTransLine."Line No."));
        END;
    end;

    local procedure JrnlInicializeGlobals(TemplateCode: Code[10]; BatchCode: Code[10]; ReasonCode: Code[10]; var ErrorText: Text): Boolean
    var
        lText001: Label 'Journal: Template, Batch, and Reason cant be empty';
    begin
        IF (TemplateCode = '') OR (BatchCode = '') OR (ReasonCode = '') THEN BEGIN
            ErrorText := lText001;
            EXIT(FALSE);
        END;
        IF NOT ItemJrnlTemplate_g.GET(TemplateCode) THEN BEGIN
            ErrorText := STRSUBSTNO(Text001, TemplateCode, ItemJrnlTemplate_g.TABLECAPTION);
            EXIT(FALSE);
        END;
        IF NOT ItemJrnlBatch_g.GET(TemplateCode, BatchCode) THEN BEGIN
            ErrorText := STRSUBSTNO(Text001, BatchCode, ItemJrnlBatch_g.TABLECAPTION);
            EXIT(FALSE);
        END;
        ReasonCode_g := ReasonCode;
        ///Not used in BC
        EXIT(TRUE);
    end;

    local procedure JrnlClearAll()
    begin

        ItemJrnlLine_g.RESET;
        ItemJrnlLine_g.SETRANGE(ItemJrnlLine_g."Journal Template Name", ItemJrnlTemplate_g.Name);
        ItemJrnlLine_g.SETRANGE(ItemJrnlLine_g."Journal Batch Name", ItemJrnlBatch_g.Name);
        ItemJrnlLine_g.DELETEALL;
        //Not used in BC
    end;

    local procedure JrnlValidateInventory(ItemNo: Code[20]; TransferFromCode: Code[20]; VariantCode: Code[10]; QuantityToShipBase: Decimal; UnitOfMeasureCode: Code[10]; var ErrorText: Text): Boolean
    var
        ItemLedgerEntry_l: Record "Item Ledger Entry";
        TransferLine_l: Record "Transfer Line";
        ItemStatusLink: Record "LSC Item Status Link";
        Item_l: Record "Item";
        BOUtils: Codeunit "LSC BO Utils";
        QuantityBaseToShip: Decimal;
        InventoryBaseDataDiff: Decimal;
        NextLineNo: Integer;
        lText001: Label 'Item %1 is bloqued for Positive Adjusment in Location %2';
        lText002: Label 'Item %1 Qty out - Inventory is negative ';
        lText003: Label 'Item %1 is bloqued for transfering in Location %2';
        lText004: Label 'Item %1 inventory is not enough %2';
        ItemJournalLine_l: Record "Item Journal Line";//Not used in BC
    begin
        IF BOUtils.IsBlockTransfering(ItemNo, '', VariantCode, '', TransferFromCode, TODAY, ItemStatusLink) THEN BEGIN
            ErrorText := STRSUBSTNO(lText003, ItemNo, TransferFromCode);
            EXIT(FALSE);
        END;

        ItemLedgerEntry_l.RESET;
        ItemLedgerEntry_l.SETCURRENTKEY("Item No.", Open, "Variant Code", "Location Code");
        ItemLedgerEntry_l.SETRANGE(ItemLedgerEntry_l."Item No.", ItemNo);
        ItemLedgerEntry_l.SETRANGE(ItemLedgerEntry_l.Open, TRUE);
        ItemLedgerEntry_l.SETRANGE(ItemLedgerEntry_l."Variant Code");
        ItemLedgerEntry_l.SETRANGE(ItemLedgerEntry_l."Location Code", TransferFromCode);
        ItemLedgerEntry_l.CALCSUMS(ItemLedgerEntry_l."Remaining Quantity");

        TransferLine_l.RESET;
        TransferLine_l.SETRANGE(TransferLine_l."Transfer-from Code", TransferFromCode);
        TransferLine_l.SETRANGE(TransferLine_l."Item No.", ItemNo);
        TransferLine_l.CALCSUMS(TransferLine_l."Outstanding Qty. (Base)");
        InventoryBaseDataDiff := TransferLine_l."Outstanding Qty. (Base)" - ItemLedgerEntry_l."Remaining Quantity";

        //JH24052024-Error validacion, se corrige segun BC PROD
        /*if InventoryBaseDataDiff <= 0 then
            exit(true)
        else begin
            ErrorText := StrSubstNo(lText004, ItemNo, Format(ItemLedgerEntry_l."Remaining Quantity"));
            exit(false);
        end;*/

        IF InventoryBaseDataDiff <= 0 THEN EXIT(TRUE);

        IF BOUtils.IsBlockPositiveAdjustm(ItemNo, '', VariantCode, '', TransferFromCode, TODAY, ItemStatusLink) THEN BEGIN
            ErrorText := STRSUBSTNO(lText001, ItemNo, TransferFromCode);
            EXIT(FALSE);
        END;//Not used in BC

        IF BOUtils.IsBlockTransfering(ItemNo, '', VariantCode, '', TransferFromCode, TODAY, ItemStatusLink) THEN BEGIN
            ErrorText := STRSUBSTNO(lText003, ItemNo, TransferFromCode);
            EXIT(FALSE);
        END;

        ItemJournalLine_l.RESET;
        ItemJournalLine_l.SETCURRENTKEY("Journal Template Name", "Journal Batch Name", "Line No.");
        ItemJournalLine_l.SETRANGE(ItemJournalLine_l."Journal Template Name", ItemJrnlTemplate_g.Name);
        ItemJournalLine_l.SETRANGE(ItemJournalLine_l."Journal Batch Name", ItemJrnlBatch_g.Name);
        IF ItemJournalLine_l.FINDLAST THEN
            NextLineNo := ItemJournalLine_l."Line No." + 100
        ELSE
            NextLineNo := 11000;

        IF Item_l.GET(ItemNo) THEN
            IF Item_l."Base Unit of Measure" <> '' THEN
                IF NOT JrnlFill(NextLineNo, ItemNo, TransferFromCode, Item_l."Base Unit of Measure", InventoryBaseDataDiff, TRUE, ErrorText) THEN
                    EXIT(FALSE);
        //Not used in BC
        EXIT(FALSE);
    end;

    local procedure JrnlFill(LineNo: Integer; ItemNo: Code[20]; LocationCode: Code[10]; UnitOfMeasureCode: Code[10]; QtyBaseAdjusment: Decimal; IsPositiveAdjmt: Boolean; var ErrorText: Text): Boolean
    begin
        ItemJrnlLine_g.INIT;
        ItemJrnlLine_g."Journal Template Name" := ItemJrnlTemplate_g.Name;
        ItemJrnlLine_g."Journal Batch Name" := ItemJrnlBatch_g.Name;
        IF IsPositiveAdjmt THEN
            ItemJrnlLine_g."Entry Type" := ItemJrnlLine_g."Entry Type"::"Positive Adjmt."
        ELSE
            ItemJrnlLine_g."Entry Type" := ItemJrnlLine_g."Entry Type"::"Negative Adjmt.";
        ItemJrnlLine_g.VALIDATE("Posting Date", TODAY);
        ItemJrnlLine_g."Line No." := LineNo;
        ItemJrnlLine_g."Document No." := 'TRANSFER';
        ItemJrnlLine_g.VALIDATE("Item No.", ItemNo);
        ItemJrnlLine_g.VALIDATE("Location Code", LocationCode);
        ItemJrnlLine_g.VALIDATE("Unit of Measure Code", UnitOfMeasureCode);
        ItemJrnlLine_g.VALIDATE(Quantity, QtyBaseAdjusment);
        ItemJrnlLine_g."Document Date" := TODAY;
        ItemJrnlLine_g."Reason Code" := ReasonCode_g;
        IF NOT ItemJrnlLine_g.INSERT(TRUE) THEN BEGIN
            ErrorText := COPYSTR(GETLASTERRORTEXT, 1, 150);
            EXIT(FALSE);
        END;
        //Not used in BC
        EXIT(TRUE);
    end;

    local procedure JrnlItemsPost(var ErrorText: Text): Boolean
    begin
        COMMIT;

        ItemJrnlLine_g.RESET;
        ItemJrnlLine_g.SETRANGE(ItemJrnlLine_g."Journal Template Name", ItemJrnlTemplate_g.Name);
        ItemJrnlLine_g.SETRANGE(ItemJrnlLine_g."Journal Batch Name", ItemJrnlBatch_g.Name);
        IF ItemJrnlLine_g.FINDFIRST THEN
            IF CODEUNIT.RUN(CODEUNIT::"Item Jnl.-Post", ItemJrnlLine_g) THEN
                EXIT(TRUE)
            ELSE BEGIN
                ErrorText := COPYSTR(GETLASTERRORTEXT, 1, 150);
                EXIT(FALSE);
            END;
        //Not used in BC
        EXIT(TRUE);
    end;

    procedure RecoveryConsistencyWhsReceipt(TransferOrderNo: Code[20]; ItemNo: Code[20]; ExternalDoc: Code[35]; var ErrorText: Text; var CreateWsheReceipt: Boolean): Boolean
    var
        ExternalTransferLine_l: Record "PITS_WMScd2suc";
        TransferLine_l: Record "Transfer Line";
        ConsistencyExists: Boolean;
    begin
        CreateWsheReceipt := TRUE;

        ExternalTransferLine_l.RESET;
        ExternalTransferLine_l.SETCURRENTKEY("Source No.", "Item No.");
        ExternalTransferLine_l.SETRANGE(ExternalTransferLine_l."No.", TransferOrderNo);
        ExternalTransferLine_l.SETRANGE(ExternalTransferLine_l."No. Remision", ExternalDoc);
        IF ExternalTransferLine_l.FINDSET THEN
            REPEAT
                ConsistencyExists := FALSE;
                IF TransferLine_l.GET(ExternalTransferLine_l."No.", ExternalTransferLine_l."Line No.") THEN
                    IF TransferLine_l."Quantity Shipped" = ExternalTransferLine_l."Qty. to Ship" THEN BEGIN
                        ConsistencyExists := TRUE;

                        TransferLine_l.CALCFIELDS("Whse. Inbnd. Otsdg. Qty (Base)");
                        IF (TransferLine_l."Whse. Inbnd. Otsdg. Qty (Base)" + TransferLine_l."Qty. Received (Base)") = TransferLine_l."Qty. Shipped (Base)" THEN
                            CreateWsheReceipt := FALSE;

                    END;
            UNTIL (ExternalTransferLine_l.NEXT = 0) OR NOT ConsistencyExists;

        EXIT(ConsistencyExists);
    end;

    procedure RecoveryConsistencyTransfer(TransferOrderNo: Code[20]; var ExternalDocument: Code[35])
    var
        TransferLine_l: Record "Transfer Line";
        ExternalTransferData_l: Record "PITS_WMScd2suc";
        WsheReceiptLine_l: Record "Warehouse Receipt Line";
        "Stop": Boolean;
    begin
        TransferLine_l.RESET;
        TransferLine_l.SETCURRENTKEY("Document No.", "Line No.");
        TransferLine_l.SETRANGE(TransferLine_l."Document No.", TransferOrderNo);
        TransferLine_l.SETFILTER(TransferLine_l."Quantity Shipped", '<>0');
        TransferLine_l.CALCSUMS(TransferLine_l."Quantity Shipped", TransferLine_l."Quantity Received");

        IF TransferLine_l."Quantity Shipped" = 0 THEN
            EXIT;

        IF TransferLine_l."Quantity Shipped" = TransferLine_l."Quantity Received" THEN
            EXIT;

        WsheReceiptLine_l.RESET;
        WsheReceiptLine_l.SETRANGE(WsheReceiptLine_l."Source Type", 5741);
        WsheReceiptLine_l.SETRANGE(WsheReceiptLine_l."Source Subtype", 1);
        WsheReceiptLine_l.SETRANGE(WsheReceiptLine_l."Source No.", TransferOrderNo);
        WsheReceiptLine_l.CALCSUMS(WsheReceiptLine_l.Quantity);
        IF TransferLine_l."Quantity Shipped" = (WsheReceiptLine_l.Quantity + TransferLine_l."Quantity Received") THEN
            EXIT;

        Stop := FALSE;
        TransferLine_l.RESET;
        TransferLine_l.SETCURRENTKEY("Document No.", "Line No.");
        TransferLine_l.SETRANGE(TransferLine_l."Document No.", TransferOrderNo);
        TransferLine_l.SETFILTER(TransferLine_l."Quantity Shipped", '<>0');
        IF TransferLine_l.FINDSET then
            repeat
                TransferLine_l.CALCFIELDS("Whse. Inbnd. Otsdg. Qty (Base)");
                Stop := TransferLine_l."Quantity Shipped" > (TransferLine_l."Whse. Inbnd. Otsdg. Qty (Base)" + TransferLine_l."Quantity Received");
                IF Stop THEN BEGIN
                    IF ExternalTransferData_l.GET(TransferLine_l."Document No.", TransferLine_l."Line No.") THEN
                        ExternalDocument := ExternalTransferData_l."No. Remision";
                END;
            until (TransferLine_l.NEXT = 0) or Stop;
    end;

    procedure GetDeleteTransferRecordSet()
    var
        QryTransferConfirmed: Query "FSN Transfer Consistency";
    begin
        QryTransferConfirmed.OPEN;
        WHILE QryTransferConfirmed.READ DO BEGIN
            DeleteTransfer(QryTransferConfirmed.Source_No);
        END;
        QryTransferConfirmed.CLOSE;
    end;

    procedure DeleteTransfer(TransferOrderNo: Code[20])
    var
        ExternalTransferData_l: Record "PITS_WMScd2suc";
        TransferLine_l: Record "Transfer Line";
        TransferHeader_l: Record "Transfer Header";
        ReleaseTransferDoc: Codeunit "Release Transfer Document";
        FSNExtTransfManager: Codeunit "FSN External Transfer Manager";
    begin
        ExternalTransferData_l.RESET;
        ExternalTransferData_l.SETCURRENTKEY("Source No.", "Shelf No.");
        ExternalTransferData_l.SETRANGE(ExternalTransferData_l."No.", TransferOrderNo);
        ExternalTransferData_l.CALCSUMS(ExternalTransferData_l."Qty. to Ship");

        TransferLine_l.RESET;
        TransferLine_l.SETRANGE(TransferLine_l."Document No.", TransferOrderNo);
        //TransferLine_l.CALCSUMS(TransferLine_l."Quantity Received");                                //WVILLALTA 06.21-
        TransferLine_l.CALCSUMS(TransferLine_l."Quantity Received", TransferLine_l."Quantity Shipped");//WVILLALTA 06.21+

        IF ExternalTransferData_l."Qty. to Ship" > 0 THEN
            //IF (ExternalTransferData_l."Qty. to Ship" = TransferLine_l."Quantity Received") THEN
            IF (ExternalTransferData_l."Qty. to Ship" = TransferLine_l."Quantity Received") AND //WVILLALTA 06.21-
            (TransferLine_l."Quantity Shipped" = TransferLine_l."Quantity Received") THEN     //WVILLALTA 06.21+
                IF TransferHeader_l.GET(TransferOrderNo) THEN BEGIN
                    FSNExtTransfManager.DeleteTransferALL(TransferHeader_l);
                    /*ReleaseTransferDoc.Reopen(TransferHeader_l);
                    IF TransferHeader_l.DELETE(TRUE) THEN;*/
                END;
    end;

    procedure DeleteTransferALL(TransferHeader: Record "Transfer Header")
    var
        ReleaseTransferDoc: Codeunit "Release Transfer Document";

    begin
        ReleaseTransferDoc.Reopen(TransferHeader);
        IF TransferHeader.DELETE(TRUE) THEN;
    end;

    procedure UseOldVersion(IgnoreErrors: Boolean; Limite: Integer; WsheShipmentCode: Code[20])
    begin
        //Not used in BC
    end;

    local procedure CheckLineStatus(Header: Record "Transfer Header")
    var
        Transferline_l: Record "Transfer Line";
        Msg: Label '%1 is pending scanner';
        Location: Record Location;
    begin
        Transferline_l.Reset();
        Transferline_l.SetRange("Document No.", Header."No.");
        if Transferline_l.Find('-') then begin
            Location.Get(Transferline_l."Transfer-from Code");
            if Location."LSC Location is a Warehouse" then
                exit;
            repeat
                if not Transferline_l."FSN Checked" then
                    Error(StrSubstNo(Msg, Transferline_l.Description));
            until Transferline_l.Next() = 0;
        end;

    end;

    [EventSubscriber(ObjectType::Table, Database::"Transfer Header", 'OnBeforeModifyEvent', '', true, true)]
    local procedure "Transfer Header_OnBeforeModifyEvent"
    (
        var Rec: Record "Transfer Header";
        var xRec: Record "Transfer Header";
        RunTrigger: Boolean
    )
    begin
        if (Rec."FSN Internal Control" = '') and (xRec."FSN Internal Control" <> '') then
            Rec."FSN Internal Control" := xRec."FSN Internal Control";

        if (xRec."FSN Internal Control" = '') and (Rec."FSN Internal Control" <> '') then
            xRec."FSN Internal Control" := Rec."FSN Internal Control";
    end;

    [EventSubscriber(ObjectType::Page, Page::"LSC Retail Transfer Order", 'OnBeforeActionEvent', 'P&ost', true, true)]
    local procedure "LSC Retail Transfer Order_OnBeforeActionEvent_[processing / P&osting] - P&ost"(var Rec: Record "Transfer Header")
    begin
        CheckLineStatus(Rec);
    end;

    [EventSubscriber(ObjectType::Page, Page::"LSC Retail Transfer Order", 'OnBeforeActionEvent', 'Post and &Print', true, true)]
    local procedure "LSC Retail Transfer Order_OnBeforeActionEvent_[processing / P&osting] - Post and &Print"(var Rec: Record "Transfer Header")
    begin
        CheckLineStatus(Rec);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"TransferOrder-Post Receipt", 'OnBeforeTransRcptHeaderInsert', '', true, true)]
    local procedure "TransferOrder-Post Receipt_OnBeforeTransRcptHeaderInsert"
    (
        var TransferReceiptHeader: Record "Transfer Receipt Header";
        TransferHeader: Record "Transfer Header"
    )
    begin
        if TransferReceiptHeader."Posting Date" <> Today then begin
            TransferReceiptHeader."Posting Date" := Today;
        end;
        TransferReceiptHeader."FSN Internal Control" := TransferHeader."FSN Internal Control";
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"TransferOrder-Post Shipment", 'OnAfterTransferOrderPostShipment', '', true, true)]
    local procedure "TransferOrder-Post Shipment_OnAfterTransferOrderPostShipment"
    (
        var TransferHeader: Record "Transfer Header";
        CommitIsSuppressed: Boolean;
        var TransferShipmentHeader: Record "Transfer Shipment Header"
    )
    begin
        TransferShipmentHeader."FSN Internal Control" := TransferHeader."FSN Internal Control";
        TransferShipmentHeader.Modify(true);
    end;

    [EventSubscriber(ObjectType::Page, Page::"Transfer Order", 'OnDeleteRecordEvent', '', true, true)]
    local procedure "Transfer Order_OnDeleteRecordEvent"
    (
        var Rec: Record "Transfer Header";
        var AllowDelete: Boolean
    )
    begin
        if Rec."FSN Internal Control" <> '' then
            Error('No se puede eliminar transferencias creadas desde facturas ventas');
    end;

    /*[EventSubscriber(ObjectType::Table, Database::"Purch. Inv. Header", 'OnBeforeInsertEvent', '', true, true)]
    local procedure "Purch. Inv. Header_OnBeforeInsertEvent"
    (
        var Rec: Record "Purch. Inv. Header";
        RunTrigger: Boolean
    )
    begin
        if Rec."Posting Date" <> Today then begin
            Rec."Posting Date" := Today;
        end;
    end;
    */

    [EventSubscriber(ObjectType::Table, Database::"Return Shipment Header", 'OnBeforeInsertEvent', '', true, true)]
    local procedure "Return Shipment Header_OnBeforeInsertEvent"
    (
        var Rec: Record "Return Shipment Header";
        RunTrigger: Boolean
    )
    begin
        if Rec."Posting Date" <> Today then begin
            Rec."Posting Date" := Today;
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Purch.-Post", 'OnBeforePurchRcptHeaderInsert', '', true, true)]
    local procedure "Purch.-Post_OnBeforePurchRcptHeaderInsert"
    (
        var PurchRcptHeader: Record "Purch. Rcpt. Header";
        var PurchaseHeader: Record "Purchase Header";
        CommitIsSupressed: Boolean
    )
    begin
        if PurchRcptHeader."Posting Date" <> Today then
            PurchRcptHeader."Posting Date" := Today;
    end;

    procedure GetReceipts(NoReceipt: Code[20]): Boolean
    var
        WareHouseReceiptHeader: Record "Warehouse Receipt Header";
        WhseReceiptLine1: Record "Warehouse Receipt Line";
        i: Integer;
        WareHouseReceiptHeader2: Record "Warehouse Receipt Header";
        ExternalMngrApplication: Codeunit "FSN External Transfer Manager";
        SchedulerJob: Record "LSC Scheduler Job Header";
    begin
        WareHouseReceiptHeader.RESET;
        i := 0;
        WareHouseReceiptHeader.SETRANGE(Status, WareHouseReceiptHeader.Status::AplicandoAutomatico);
        WareHouseReceiptHeader.SetFilter(WareHouseReceiptHeader."Vendor Shipment No.", '<>%1', '');//28981
        if NoReceipt <> '' then
            WareHouseReceiptHeader.SETRANGE("No.", NoReceipt);
        IF WareHouseReceiptHeader.FIND('-') THEN
            REPEAT
                Clear(ExternalMngrApplication);
                ExternalMngrApplication.SetWarehouseReceiptNo(WareHouseReceiptHeader."No.");
                SchedulerJob.Reset();
                SchedulerJob.Code := 'APPLY';
                if ExternalMngrApplication.Run(SchedulerJob) then;

                i += 1;
            /*WareHouseReceiptHeader2 := WareHouseReceiptHeader;
            WareHouseReceiptHeader2."Vendor Shipment No." := WareHouseReceiptHeader."FSN External Document No.";
            WareHouseReceiptHeader2.MODIFY;*/
            /*
                            i += 1;
                            WhseReceiptLine1.RESET;
                            WhseReceiptLine1.SETRANGE(WhseReceiptLine1."No.", WareHouseReceiptHeader."No.");
                            IF WhseReceiptLine1.FIND('-') THEN
                                CodeReceipt(WhseReceiptLine1);
                            COMMIT;*/
            UNTIL (WareHouseReceiptHeader.NEXT = 0) OR (i = last);
    end;

    procedure SetWarehouseReceiptNo(No: Code[20])
    begin
        WarehouseReceiptNo := No;
    end;

    procedure GetReceiptsApply()
    var
        WareHouseReceiptHeader: Record "Warehouse Receipt Header";
        WhseReceiptLine1: Record "Warehouse Receipt Line";
        i: Integer;
        WareHouseReceiptHeader2: Record "Warehouse Receipt Header";

    begin
        WareHouseReceiptHeader.RESET;
        WareHouseReceiptHeader.SETRANGE("No.", WarehouseReceiptNo);
        IF WareHouseReceiptHeader.FIND('-') THEN begin

            WhseReceiptLine1.RESET;
            WhseReceiptLine1.SETRANGE(WhseReceiptLine1."No.", WareHouseReceiptHeader."No.");
            IF WhseReceiptLine1.FIND('-') THEN
                CodeReceipt(WhseReceiptLine1);
            COMMIT;
        end;
    end;

    procedure CreateTransferReceiptHistory(WRNumber: Code[20])
    var
        WhseRcptHeader: Record "Warehouse Receipt Header";
        TransRcptHeader: Record "Transfer Receipt Header";
        PITSLine: Record PITS_WMScd2suc;
        TransRcptLine: Record "Transfer Receipt Line";
        Item: Record Item;
        ItemUoM: Record "Item Unit of Measure";
        LineNo: Integer;
        QtyPerUnitOfMeasure: Decimal;
        lText001: Label 'No se encontró el WR %1 para crear histórico';
        lText002: Label 'Histórico de transferencia creado: %1';
        lText003: Label 'Validación de estado fallida: Hay líneas PITS con estado diferente a Registrado (2) en el WR %1. Estado actual requerido: Registrado';
    begin
        // Verificar que existe el WR
        if not WhseRcptHeader.Get(WRNumber) then
            Error(lText001, WRNumber);

        // VALIDACIÓN CRÍTICA: Verificar que todas las líneas están en estado Registrado (2)
        PITSLine.RESET;
        PITSLine.SETRANGE("FSN Warehouse Receipt No.", WRNumber);
        PITSLine.SETFILTER("Qty. to Ship", '>0');
        PITSLine.SETFILTER(Quantity, '>0');
        PITSLine.SETFILTER("FSN TransferHistorico", '<>2');  // Buscar líneas que NO sean Registrado (2)
        if PITSLine.FINDFIRST then
            Error(lText003, WRNumber);

        // Si ya existe el histórico para este WR, limpiar líneas y reutilizar header
        if not TransRcptHeader.Get(WRNumber) then begin
            TransRcptHeader.INIT;
            TransRcptHeader."No." := WRNumber;
            TransRcptHeader.INSERT(TRUE);
        end;

        // Copiar datos del Warehouse Receipt al Transfer Receipt Header
        TransRcptHeader."Transfer-from Code" := 'CD';
        TransRcptHeader."Transfer-to Code" := WhseRcptHeader."Location Code";
        TransRcptHeader."Posting Date" := Today;
        TransRcptHeader."Shipment Date" := WhseRcptHeader."Assignment Date";
        TransRcptHeader."Receipt Date" := Today;
        TransRcptHeader."External Document No." := WhseRcptHeader."Vendor Shipment No."; // DTE
        TransRcptHeader."Transfer Order No." := WhseRcptHeader."FSN External Document No."; // TR
        TransRcptHeader."Transfer Order Date" := WhseRcptHeader."Assignment Date";
        TransRcptHeader.MODIFY(TRUE);

        // Limpiar líneas previas si existieran
        TransRcptLine.RESET;
        TransRcptLine.SETRANGE("Document No.", WRNumber);
        if TransRcptLine.FINDFIRST then
            TransRcptLine.DELETEALL;

        // Crear Transfer Receipt Lines copiando datos de las PITS Lines
        PITSLine.RESET;
        PITSLine.SETRANGE("FSN Warehouse Receipt No.", WRNumber);
        PITSLine.SETFILTER("Qty. to Ship", '>0');

        if PITSLine.FINDSET then begin
            repeat
                TransRcptLine.INIT;
                TransRcptLine."Document No." := WRNumber;
                TransRcptLine."Line No." := PITSLine."Line No.";
                TransRcptLine."Item No." := PITSLine."Item No.";
                TransRcptLine.Description := PITSLine.Description;
                TransRcptLine.Quantity := PITSLine."Qty. to Ship";
                TransRcptLine."Unit of Measure Code" := PITSLine."Unit of Measure";
                TransRcptLine."Unit of Measure" := PITSLine."Unit of Measure";

                // Consultar Item Unit of Measure para obtener Qty. per Unit of Measure
                // Buscar primero el Item
                QtyPerUnitOfMeasure := 1;
                if Item.Get(PITSLine."Item No.") then begin
                    // Buscar Item Unit of Measure usando Item No. y el Code del Unit of Measure (COMPIRX14)
                    if ItemUoM.Get(PITSLine."Item No.", PITSLine."Unit of Measure") then begin
                        QtyPerUnitOfMeasure := ItemUoM."Qty. per Unit of Measure";
                        TransRcptLine."Qty. per Unit of Measure" := ItemUoM."Qty. per Unit of Measure";
                    end;
                end;

                // Calcular Quantity (Base) = Quantity * Qty. per Unit of Measure
                TransRcptLine."Quantity (Base)" := PITSLine."Qty. to Ship" * QtyPerUnitOfMeasure;

                TransRcptLine."Transfer-from Code" := 'CD';
                TransRcptLine."Transfer-to Code" := PITSLine."Transfer-to Code";
                TransRcptLine."Transfer Order No." := PITSLine."No."; // TR
                TransRcptLine."Receipt Date" := WhseRcptHeader."Posting Date";
                TransRcptLine.INSERT(TRUE);
            until PITSLine.NEXT = 0;
        end;

        // Marcar PITS Lines como completadas en histórico (FSN TransferHistorico = Historico)
        PITSLine.RESET;
        PITSLine.SETRANGE("FSN Warehouse Receipt No.", WRNumber);
        PITSLine.SETFILTER("Qty. to Ship", '>0');
        if PITSLine.FINDSET(FALSE, FALSE) then begin
            repeat
                if PITSLine.GET(PITSLine."No.", PITSLine."Line No.") then begin
                    PITSLine."FSN TransferHistorico" := PITSLine."FSN TransferHistorico"::Historico;
                    PITSLine.MODIFY(FALSE);
                    COMMIT;  // Commit después de cada registro para liberar bloqueos
                end;
            until PITSLine.NEXT = 0;
        end;

        // Eliminar WR Header temporal (solo de Warehouse Receipt Header)
        if WhseRcptHeader.Delete(false) then begin
            COMMIT;
            // Marcar PITS Lines como WR Eliminado (FSN TransferHistorico = 4)
            PITSLine.RESET;
            PITSLine.SETRANGE("FSN Warehouse Receipt No.", WRNumber);
            PITSLine.SETFILTER("Qty. to Ship", '>0');
            if PITSLine.FINDSET(FALSE, FALSE) then begin
                repeat
                    if PITSLine.GET(PITSLine."No.", PITSLine."Line No.") then begin
                        PITSLine."FSN TransferHistorico" := PITSLine."FSN TransferHistorico"::"WR Eliminado";
                        PITSLine.MODIFY(FALSE);
                        COMMIT;  // Commit después de cada registro
                    end;
                until PITSLine.NEXT = 0;
            end;
        end;

        Message(lText002, WRNumber);
    end;

    local procedure CodeReceipt(var WhseReceiptLineRec: Record "Warehouse Receipt Line")
    var
        WhseReceiptLine: Record "Warehouse Receipt Line";
        WhsePostReceipt: codeunit "Whse.-Post Receipt";
    begin
        WhseReceiptLine.COPY(WhseReceiptLineRec);
        WITH WhseReceiptLine DO BEGIN
            FIND;
            WhsePostReceipt.SetHideValidationDialog(TRUE);
            ConfirRun := WhsePostReceipt.RUN(WhseReceiptLine);

            LastError := COPYSTR(GETLASTERRORTEXT, 1, 150);
            CLEAR(WhsePostReceipt);
        END;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Jnl.-Post", 'OnBeforeCode', '', true, true)]
    local procedure "Item Jnl.-Post_OnBeforeCode"
    (
        var ItemJournalLine: Record "Item Journal Line";
        var HideDialog: Boolean;
        var SuppressCommit: Boolean;
        var IsHandled: Boolean
    )
    begin
        if ItemJournalLine."Journal Template Name" = 'TF_REPL' then
            HideDialog := true;
    end;

    [EventSubscriber(ObjectType::Page, Page::"LSC Retail Receiving", 'OnAfterActionEvent', 'Confirm', true, true)]
    local procedure "LSC Retail Receiving_OnAfterActionEvent_[processing / &Posting] - Confirm"(var Rec: Record "LSC P/R Counting Header")
    var
        TransHeader: Record "Transfer Header";
        TransfLine: Record "Transfer Line";
        PRLines: Record "LSC Picking / Receiving lines";
        PRHeader: Record "LSC P/R Counting Header";
        IUM: Record "Item Unit of Measure";
        PRConfirm: Codeunit "LSC Picking/Receiving Confirm";
        ReserVE: Record "Reservation Entry";
    begin
        if TransHeader.Get(Rec."Reference No.") then begin
            if not (TransHeader."Transfer-from Code" in ['RECETARIO', 'CD']) AND NOT (TransHeader."Transfer-to Code" in ['RECETARIO', 'CD']) then
                if Rec.Receiving = Rec.Receiving::"Transfer In" then
                    if PRHeader.Get(Rec."No.") then begin
                        PRLines.Reset();
                        PRLines.SetRange("Document No.", Rec."No.");
                        if PRLines.find('-') then
                            repeat
                                TransfLine.Reset();
                                TransfLine.SetRange("Document No.", Rec."Reference No.");
                                TransfLine.SetRange("Item No.", PRLines."Item No.");
                                if TransfLine.FindFirst() then
                                    if ((PRLines.Quantity) < TransfLine.Quantity) or (PRLines."Unit of Measure Code" <> TransfLine."Unit of Measure Code") then begin
                                        if PRLines."Unit of Measure Code" <> TransfLine."Unit of Measure Code" then
                                            if IUM.Get(TransfLine."Item No.", TransfLine."Unit of Measure Code") then begin
                                                PRLines.Validate("Unit of Measure Code", TransfLine."Unit of Measure Code");
                                            end;
                                        ReserVE.Reset();
                                        ReserVE.SetRange("Source ID", TransfLine."Document No.");
                                        ReserVE.SetRange("Source Prod. Order Line", TransfLine."Line No.");
                                        ReserVE.SetRange("Item No.", TransfLine."Item No.");
                                        ReserVE.SetRange("Location Code", TransfLine."Transfer-to Code");
                                        if ReserVE.FindFirst() then
                                            PRLines.Validate("Lot No.", ReserVE."Lot No.");
                                        PRLines.Validate(Quantity, PRLines."Ordered Qty.");
                                        PRLines.Modify(true);
                                    end;
                            until PRLines.Next() = 0;
                    end;
            if PRHeader.Get(Rec."No.") then begin
                PRConfirm.InitCodeunit(true);
                PRConfirm.Run(PRHeader);
            end;
        end;
    end;

    [EventSubscriber(ObjectType::Page, Page::"LSC Retail Transfer Requests", 'OnBeforeActionEvent', '&Send Request', true, true)]
    local procedure "LSC Retail Transfer Requests_OnBeforeActionEvent_[processing / F&unctions] - &Send Request"(var Rec: Record "Transfer Header")
    var
        Error000: Label '"Tienda Origen" no puede ser vacio';
        Error001: Label '"Transfer. desde-cód." no puede ser vacio';
        Error002: Label '"A-Tienda" no puede ser vacio';
        Error003: Label '"Transfer. a-cód." no puede ser vacio';
    begin

        if Rec."LSC Store-from" = '' then
            Error(error000);

        if Rec."Transfer-from Code" = '' then
            Error(error001);

        if Rec."LSC Store-to" = '' then
            Error(error002);

        if Rec."Transfer-to Code" = '' then
            Error(error003);
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
        pits: Record "PITS_WMScd2suc";
        pitsheader: Record "PITS_WMScd2sucHeaders";
    begin
        if RequestID = 'REPL-CONSOLID' then begin
            pits.Reset();
            pits.SetRange("No.", POSMenuLine."Menu ID", POSMenuLine.Command);
            if pits.Find('-') then
                repeat
                    pits."Consolidated From No." := POSMenuLine."Post Command";
                    pits.TransferComplete := false;
                    pits.Rapidito := false;
                    pits.Modify()
                until pits.Next() = 0;
            pitsheader.Reset();
            pitsheader.SetRange(No_, POSMenuLine."Menu ID", POSMenuLine.Command);
            pitsheader.SetRange("Source No_", POSMenuLine."Menu ID", POSMenuLine.Command);
            if pitsheader.Find('-') then
                repeat
                    pitsheader.Transfer := false;
                    pitsheader.Rapidito := false;
                    pitsheader.Modify()
                until pitsheader.Next() = 0;
        end;
    end;

    procedure GetReceiptsApi(No: Code[20]): Text
    var
        WareHouseReceiptHeader: Record "Warehouse Receipt Header";
        WhseReceiptLine: Record "Warehouse Receipt Line";
        WhsePostReceipt: codeunit "Whse.-Post Receipt";
        jsonRes: JsonObject;
        JsonMes: Text;
    begin
        ConfirRun := false;
        LastError := '';
        WareHouseReceiptHeader.RESET;
        WareHouseReceiptHeader.SETRANGE(Status, WareHouseReceiptHeader.Status::AplicandoAutomatico);
        WareHouseReceiptHeader.SetFilter(WareHouseReceiptHeader."Vendor Shipment No.", '<>%1', '');
        WareHouseReceiptHeader.SETRANGE("No.", No);
        IF WareHouseReceiptHeader.FIND('-') THEN begin
            WhseReceiptLine.RESET;
            WhseReceiptLine.SETRANGE(WhseReceiptLine."No.", WareHouseReceiptHeader."No.");
            IF WhseReceiptLine.FindFirst() then begin
                WareHouseReceiptHeader.SetHideValidationDialog(TRUE);
                ConfirRun := WhsePostReceipt.RUN(WhseReceiptLine);
                if not ConfirRun then
                    LastError := COPYSTR(GETLASTERRORTEXT, 1, 500);
            end;
        end else
            LastError := 'El Registro ' + No + ' No existe, No Esta En estatus AplicandoAutomatico o El campo No. Proveedor Esta vacio';
        jsonRes.Add('Status', ConfirRun);
        jsonRes.Add('LastError', LastError);
        jsonRes.WriteTo(JsonMes);
        EXIT(JsonMes);
    end;

    procedure GetWRReceipts(No: Code[20]): Text
    var
        WareHouseReceiptHeader: Record "Warehouse Receipt Header";
        WhseReceiptLine: Record "Warehouse Receipt Line";
        jsonRes: JsonObject;
        ReceiptsJson: JsonArray;
        HeaderJson: JsonObject;
        LinesJson: JsonArray;
        LineJson: JsonObject;
        JsonMes: Text;
    begin
        LastError := '';
        Clear(ReceiptsJson);

        WareHouseReceiptHeader.RESET;
        WareHouseReceiptHeader.SETRANGE(Status, WareHouseReceiptHeader.Status::AplicandoAutomatico);
        WareHouseReceiptHeader.SetFilter("No.", 'WR*');
        if No <> '' then
            WareHouseReceiptHeader.SETRANGE("No.", No);

        if WareHouseReceiptHeader.FINDSET then
            repeat
                Clear(HeaderJson);
                HeaderJson.Add('No', WareHouseReceiptHeader."No.");
                HeaderJson.Add('LocationCode', WareHouseReceiptHeader."Location Code");
                HeaderJson.Add('VendorShipmentNo', WareHouseReceiptHeader."Vendor Shipment No.");
                HeaderJson.Add('ExternalDocumentNo', WareHouseReceiptHeader."FSN External Document No.");
                HeaderJson.Add('PostingDate', Format(WareHouseReceiptHeader."Posting Date", 0, 9));
                HeaderJson.Add('AssignmentDate', Format(WareHouseReceiptHeader."Assignment Date", 0, 9));
                HeaderJson.Add('Status', Format(WareHouseReceiptHeader.Status));

                Clear(LinesJson);
                WhseReceiptLine.RESET;
                WhseReceiptLine.SETRANGE(WhseReceiptLine."No.", WareHouseReceiptHeader."No.");
                if WhseReceiptLine.FINDSET then
                    repeat
                        Clear(LineJson);
                        LineJson.Add('LineNo', WhseReceiptLine."Line No.");
                        LineJson.Add('ItemNo', WhseReceiptLine."Item No.");
                        LineJson.Add('Description', WhseReceiptLine.Description);
                        LineJson.Add('UnitOfMeasure', WhseReceiptLine."Unit of Measure Code");
                        LineJson.Add('Quantity', WhseReceiptLine.Quantity);
                        LineJson.Add('QtyToReceive', WhseReceiptLine."Qty. to Receive");
                        LinesJson.Add(LineJson);
                    until WhseReceiptLine.Next() = 0;

                HeaderJson.Add('Lines', LinesJson);
                ReceiptsJson.Add(HeaderJson);
            until WareHouseReceiptHeader.Next() = 0;

        if (No <> '') and (ReceiptsJson.Count = 0) then
            LastError := 'El Registro ' + No + ' No existe o no está en estatus AplicandoAutomatico';

        jsonRes.Add('Status', LastError = '');
        jsonRes.Add('LastError', LastError);
        jsonRes.Add('Receipts', ReceiptsJson);
        jsonRes.WriteTo(JsonMes);
        exit(JsonMes);
    end;

    procedure ProcessWRJson(ReceiptsJsonText: Text): Text
    var
        RootObj: JsonObject;
        ReceiptsToken: JsonToken;
        ReceiptsArray: JsonArray;
        ReceiptToken: JsonToken;
        ReceiptObj: JsonObject;
        NoToken: JsonToken;
        WRNo: Code[20];
        ResultObj: JsonObject;
        ResultsArray: JsonArray;
        ResultLine: JsonObject;
        ResultText: Text;
        LastErr: Text;
        AnyError: Boolean;
        i: Integer;
        JobH: Record "LSC Scheduler Job Header";
        WhseRcptHeader: Record "Warehouse Receipt Header";
        WasError: Boolean;
        lTextWRMissing: Label 'WR %1 no existe o ya fue eliminado.';
    begin
        AnyError := false;
        Clear(ResultsArray);

        if not RootObj.ReadFrom(ReceiptsJsonText) then begin
            ResultObj.Add('Status', false);
            ResultObj.Add('LastError', 'JSON inválido');
            ResultObj.Add('Results', ResultsArray);
            ResultObj.WriteTo(ResultText);
            exit(ResultText);
        end;

        if not RootObj.Get('Receipts', ReceiptsToken) then begin
            ResultObj.Add('Status', false);
            ResultObj.Add('LastError', 'No existe el nodo Receipts');
            ResultObj.Add('Results', ResultsArray);
            ResultObj.WriteTo(ResultText);
            exit(ResultText);
        end;

        ReceiptsArray := ReceiptsToken.AsArray();
        for i := 0 to ReceiptsArray.Count() - 1 do begin
            ReceiptsArray.Get(i, ReceiptToken);
            ReceiptObj := ReceiptToken.AsObject();

            Clear(ResultLine);
            if ReceiptObj.Get('No', NoToken) then
                WRNo := CopyStr(NoToken.AsValue().AsText(), 1, MaxStrLen(WRNo))
            else
                WRNo := '';

            ResultLine.Add('No', WRNo);

            if WRNo = '' then begin
                AnyError := true;
                ResultLine.Add('Status', false);
                ResultLine.Add('Error', 'WR No. vacío');
            end else begin
                if not WhseRcptHeader.Get(WRNo) then begin
                    if IsWRAlreadyProcessed(WRNo) then begin
                        ResultLine.Add('Status', true);
                        ResultLine.Add('Error', '');
                    end else begin
                        AnyError := true;
                        ResultLine.Add('Status', false);
                        ResultLine.Add('Error', StrSubstNo(lTextWRMissing, WRNo));
                    end;
                end else begin
                    WasError := WhseRcptHeader."FSN Proc Status" = WhseRcptHeader."FSN Proc Status"::Error;
                    if not WasError then begin
                        WhseRcptHeader."FSN Proc Status" := WhseRcptHeader."FSN Proc Status"::Procesando;
                        WhseRcptHeader."FSN Proc Error" := '';
                        WhseRcptHeader.Modify(true);
                        COMMIT;
                    end;

                    JobH.Init();
                    JobH.Code := 'WR-REG';
                    JobH.Text := WRNo;
                    if CODEUNIT.RUN(CODEUNIT::"FSN External Transfer Manager", JobH) then begin
                        ResultLine.Add('Status', true);
                        ResultLine.Add('Error', '');
                        if WhseRcptHeader.Get(WRNo) then begin
                            WhseRcptHeader."FSN Proc Status" := WhseRcptHeader."FSN Proc Status"::PorProcesar;
                            WhseRcptHeader."FSN Proc Error" := '';
                            WhseRcptHeader.Modify(true);
                            COMMIT;
                        end;
                    end else begin
                        AnyError := true;
                        LastErr := GetLastErrorText();
                        ResultLine.Add('Status', false);
                        ResultLine.Add('Error', LastErr);
                        if WhseRcptHeader.Get(WRNo) then begin
                            WhseRcptHeader.Status := WhseRcptHeader.Status::AplicandoAutomatico; // Revertir a estatus inicial para reintentos
                            WhseRcptHeader."FSN Proc Status" := WhseRcptHeader."FSN Proc Status"::Error;
                            WhseRcptHeader."FSN Proc Error" := CopyStr(LastErr, 1, MaxStrLen(WhseRcptHeader."FSN Proc Error"));
                            WhseRcptHeader.Modify(true);
                            COMMIT;
                        end;
                    end;
                end;
            end;

            ResultsArray.Add(ResultLine);
        end;

        ResultObj.Add('Status', not AnyError);
        ResultObj.Add('LastError', '');
        ResultObj.Add('Results', ResultsArray);
        ResultObj.WriteTo(ResultText);
        exit(ResultText);
    end;

    local procedure IsWRAlreadyProcessed(WRNumber: Code[20]): Boolean
    var
        PITSLine: Record PITS_WMScd2suc;
        AllFinal: Boolean;
    begin
        PITSLine.Reset();
        PITSLine.SetRange("FSN Warehouse Receipt No.", WRNumber);
        PITSLine.SetFilter("Qty. to Ship", '>0');
        if not PITSLine.FindSet(false, false) then
            exit(false);

        AllFinal := true;
        repeat
            if (PITSLine."FSN TransferHistorico" <> PITSLine."FSN TransferHistorico"::Historico) and
               (PITSLine."FSN TransferHistorico" <> PITSLine."FSN TransferHistorico"::"WR Eliminado") then begin
                AllFinal := false;
                break;
            end;
        until PITSLine.Next() = 0;

        exit(AllFinal);
    end;

    procedure CreateReservationEntry(TransHeader: Record "Transfer Header"; ItemNo: Code[20]; LineNo: Integer; QtyPerUnit: Decimal; QtyShip: Decimal; LotNo: Code[20]; Shipment: Boolean; ExpirationDate: Date)
    var
        ReservationEntry: Record "Reservation Entry";
    begin
        ReservationEntry.Init();
        ReservationEntry."Creation Date" := TransHeader."Posting Date";
        ReservationEntry."Lot No." := LotNo;
        ReservationEntry."Source Type" := DATABASE::"Transfer Line";
        ReservationEntry."Item No." := ItemNo;
        ReservationEntry."Source ID" := TransHeader."No.";
        ReservationEntry."Source Ref. No." := LineNo;
        ReservationEntry."Reservation Status" := ReservationEntry."Reservation Status"::Surplus;
        ReservationEntry."Action Message Adjustment" := 0;
        ReservationEntry."Suppressed Action Msg." := false;
        ReservationEntry."Planning Flexibility" := ReservationEntry."Planning Flexibility"::Unlimited;
        ReservationEntry.Correction := false;
        ReservationEntry."Item Tracking" := ReservationEntry."Item Tracking"::"Lot No.";
        ReservationEntry."Untracked Surplus" := false;
        ReservationEntry."Expiration Date" := ExpirationDate;
        if Shipment then begin
            ReservationEntry."Location Code" := TransHeader."Transfer-from Code";
            ReservationEntry.Positive := false;
            ReservationEntry.Quantity := -1 * QtyShip;
            ReservationEntry."Quantity (Base)" := -1 * QtyShip;
            ReservationEntry."Qty. per Unit of Measure" := QtyPerUnit;
            ReservationEntry."Qty. to Handle (Base)" := -1 * QtyShip;
            ReservationEntry."Qty. to Invoice (Base)" := -1 * QtyShip;
            ReservationEntry."Shipment Date" := TransHeader."Shipment Date";
            ReservationEntry."Source Subtype" := 0;
        end else begin
            ReservationEntry."Location Code" := TransHeader."Transfer-to Code";
            ReservationEntry.Positive := true;
            ReservationEntry."Quantity (Base)" := QtyShip;
            ReservationEntry."Qty. per Unit of Measure" := QtyPerUnit;
            ReservationEntry.Quantity := QtyShip;
            ReservationEntry."Qty. to Handle (Base)" := QtyShip;
            ReservationEntry."Qty. to Invoice (Base)" := QtyShip;
            ReservationEntry."Expected Receipt Date" := TransHeader."Receipt Date";
            ReservationEntry."Source Subtype" := 1;
        end;
        ReservationEntry.Insert();
    end;

    procedure ValItemTracking(ItemNo: Code[20]): Boolean
    var
        Item: Record Item;
        ItemTrackingCode: Record "Item Tracking Code";
    begin
        Item.Get(ItemNo);
        if '' <> Item."Item Tracking Code" then
            if ItemTrackingCode.Get(Item."Item Tracking Code") then
                EXIT(true);
        EXIT(false);
    end;

    procedure SetLoteNoTransfer(TransHeader: Record "Transfer Header"; TransLine: Record "Transfer Line"; LotNo: Code[20]; QtyShip: Decimal; ExpirationDate: Date)
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
        ReservationEntry: Record "Reservation Entry";
        QtyPending: Decimal;
        FoundLotNo: Boolean;
    begin
        QtyPending := 0;
        FoundLotNo := false;

        if not ValItemTracking(TransLine."Item No.") then
            EXIT;

        //Validar que no exista la linea creada
        ReservationEntry.RESET;
        ReservationEntry.SETRANGE("Source ID", TransLine."Document No.");
        ReservationEntry.SETRANGE("Source Ref. No.", TransLine."Line No.");
        ReservationEntry.SETRANGE("Item No.", TransLine."Item No.");
        ReservationEntry.SETRANGE("Lot No.", LotNo);
        if ReservationEntry.FindFirst() then
            exit;

        /********************************************
        Regla 1: Buscar en el Item Ledger Entry
        a) Si se encuentra un registro
            a.1) Si el lote es igual al lote del registro
            a.2) Si la cantidad pendiente es igual o mayor a la cantidad a buscar
            a.3) Retornar el lote
       ********************************************/
        ItemLedgerEntry.RESET();
        ItemLedgerEntry.SETRANGE("Location Code", 'CD');
        ItemLedgerEntry.SETRANGE("Item Tracking", ItemLedgerEntry."Item Tracking"::"Lot No.");
        ItemLedgerEntry.SETRANGE("Item No.", TransLine."Item No.");
        ItemLedgerEntry.SETRANGE("Lot No.", LotNo);
        ItemLedgerEntry.SETRANGE(Open, true);
        ItemLedgerEntry.SETRANGE(Positive, true);
        if ItemLedgerEntry.Find('-') then begin
            repeat begin
                if ItemLedgerEntry."Remaining Quantity" >= QtyShip then begin
                    CreateReservationEntry(TransHeader, TransLine."Item No.", TransLine."Line No.", TransLine."Qty. per Unit of Measure", QtyShip, LotNo, True, ExpirationDate);
                    CreateReservationEntry(TransHeader, TransLine."Item No.", TransLine."Line No.", TransLine."Qty. per Unit of Measure", QtyShip, LotNo, False, ExpirationDate);
                    FoundLotNo := true;
                end;
            end until (ItemLedgerEntry.Next() = 0) or FoundLotNo;
            if FoundLotNo then
                exit;
        end;
        /********************************************
        Regla 2: Buscar en el Item Ledger Entry
        a) Si se encuentra un registro
            a.1) Si el lote es igual al lote del registro
            a.2) Si la cantidad pendiente es menor a la cantidad a buscar
            a.3) Ordenar por fecha de creación
            a.4) Buscar el lote más antiguo y hacer la reservación hasta agotar la cantidad a buscar
            a.3) Retornar el lote
        ********************************************/
        QtyPending := QtyShip;
        ItemLedgerEntry.RESET();
        ItemLedgerEntry.SETRANGE("Location Code", 'CD');
        ItemLedgerEntry.SETRANGE("Item Tracking", ItemLedgerEntry."Item Tracking"::"Lot No.");
        ItemLedgerEntry.SETRANGE("Item No.", TransLine."Item No.");
        ItemLedgerEntry.SETRANGE(Open, true);
        ItemLedgerEntry.SETRANGE(Positive, true);
        if ItemLedgerEntry.FindFirst() then begin
            repeat begin
                if ItemLedgerEntry."Remaining Quantity" >= QtyPending then begin
                    CreateReservationEntry(TransHeader, TransLine."Item No.", TransLine."Line No.", TransLine."Qty. per Unit of Measure", QtyPending, ItemLedgerEntry."Lot No.", True, ExpirationDate);
                    CreateReservationEntry(TransHeader, TransLine."Item No.", TransLine."Line No.", TransLine."Qty. per Unit of Measure", QtyPending, ItemLedgerEntry."Lot No.", False, ExpirationDate);
                    QtyPending := 0;
                    FoundLotNo := true;
                end else begin
                    CreateReservationEntry(TransHeader, TransLine."Item No.", TransLine."Line No.", TransLine."Qty. per Unit of Measure", ItemLedgerEntry."Remaining Quantity", ItemLedgerEntry."Lot No.", True, ExpirationDate);
                    CreateReservationEntry(TransHeader, TransLine."Item No.", TransLine."Line No.", TransLine."Qty. per Unit of Measure", ItemLedgerEntry."Remaining Quantity", ItemLedgerEntry."Lot No.", False, ExpirationDate);
                    QtyPending -= ItemLedgerEntry."Remaining Quantity";
                end;
                if QtyPending = 0 then
                    break;
            end until (ItemLedgerEntry.Next() = 0) or FoundLotNo;
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnAfterPostSalesDoc', '', true, true)]
    local procedure "Sales-Post_OnAfterPostSalesDoc"
    (
        var SalesHeader: Record "Sales Header";
        var GenJnlPostLine: Codeunit "Gen. Jnl.-Post Line";
        SalesShptHdrNo: Code[20];
        RetRcpHdrNo: Code[20];
        SalesInvHdrNo: Code[20];
        SalesCrMemoHdrNo: Code[20];
        CommitIsSuppressed: Boolean;
        InvtPickPutaway: Boolean;
        var CustLedgerEntry: Record "Cust. Ledger Entry";
        WhseShip: Boolean;
        WhseReceiv: Boolean
    )
    var
        SalesLine: Record "Sales Line";
        TransferLine: Record "Transfer Line";
        RealseTransf: Codeunit "Release Transfer Document";
        POSSESION: Codeunit "LSC POS Session";
        TransHeader: Record "Transfer Header";
        TransferPostShipment: Codeunit "TransferOrder-Post Shipment";
        RegisterRe: Codeunit "LSC Picking/Receiving Confirm";
        NoteText: Text;
    begin
        if (SalesHeader."Location Code" = 'F01') and (SalesHeader."Package Tracking No." <> '') then begin
            if POSSESION.GetValue('VSESSION') = '' then
                POSSESION.SetValue('VSESSION', UserId);
            CreateTransfer(TransHeader, SalesHeader);
            NoteText := 'Transferencia creada desde la factura de venta: ' + SalesInvHdrNo;
            AddNoteToTransferOrder(TransHeader, NoteText);
            InsertTransferLine(TransHeader, SalesHeader);
            Commit();
            if TransHeader.Get(TransHeader."No.") then begin
                if ValidateInventory(TransHeader) then begin
                    RealseTransf.Run(TransHeader);
                    if TransHeader.Get(TransHeader."No.") then
                        TransferPostShipment.Run(TransHeader);
                    Commit();
                    //Creación automática de recepción
                    if TransHeader.Get(TransHeader."No.") then
                        CreateReception(TransHeader);
                end;
            end;
        end;
    end;

    local procedure ValidateInventory(TransFerHeader: Record "Transfer Header"): Boolean
    var
        myInt: Integer;
        TransferLine: Record "Transfer Line";
        itemLedEntry: Record "Item Ledger Entry";
        ItemUnitOfMens: Record "Item Unit of Measure";
        QuantityTransfer: Decimal;
        ERROR001: Label 'Inventatio insuficiente para el producto %1';
        TransHeaderM: Record "Transfer Header";
        InventoryOK: Boolean;
    begin
        TransferLine.reset;
        TransferLine.SetRange("Document No.", TransFerHeader."No.");
        TransferLine.setRange("Derived From Line No.", 0);
        if TransferLine.Find('-') then begin
            repeat
                if (TransferLine.Quantity <> TransferLine."Qty. in Transit") then
                    IF TransferLine."Qty. to Ship" <> 0 THEN BEGIN
                        if ItemUnitOfMens.get(TransferLine."Item No.", TransferLine."Unit of Measure") then begin
                            IF ItemUnitOfMens."Qty. per Unit of Measure" <> 0 THEN
                                QuantityTransfer := TransferLine."Qty. to Ship" * ItemUnitOfMens."Qty. per Unit of Measure";
                            //QuantityTransfer := TransferLine.Quantity * ItemUnitOfMens."Qty. per Unit of Measure";

                            itemLedEntry.Reset();
                            itemLedEntry.SetRange("Location Code", TransFerHeader."Transfer-from Code");
                            itemLedEntry.SetRange("Item No.", TransferLine."Item No.");
                            itemLedEntry.CalcSums(Quantity);
                            if itemLedEntry.Quantity <= 0 then begin
                                AddNoteToTransferOrder(TransFerHeader, (STRSUBSTNO(ERROR001, TransferLine."Item No.")));
                                InventoryOK := false;
                                if TransHeaderM.Get(TransFerHeader."No.") then
                                    if TransHeaderM."LSC Retail Status" <> TransHeaderM."LSC Retail Status"::Sent then begin
                                        TransHeaderM."LSC Retail Status" := TransHeaderM."LSC Retail Status"::Sent;
                                        TransHeaderM.Modify(TRUE);
                                    end;
                            end else
                                InventoryOK := true;
                        end;
                    END;
            until TransferLine.Next() = 0;
            exit(InventoryOK);
        end;
    end;

    local procedure SendAndRegister()
    var
        TransferHeader: Record "Transfer Header";
    begin
        TransferHeader.RESET;
        TransferHeader.SETRANGE("LSC Retail Status", TransferHeader."LSC Retail Status"::Sent);
        TransferHeader.SetFilter("FSN Internal Control", '<>%1', '');
        if TransferHeader.Find('-') then
            repeat
                if TransferHeader."LSC Buyer ID" <> '' then
                    POSSESION.SetValue('VSESSION', TransferHeader."LSC Buyer ID")
                else
                    POSSESION.SetValue('VSESSION', UserId);
                if ValidateInventory(TransferHeader) then
                    RecepTrans(TransferHeader);
            until TransferHeader.Next() = 0;
    end;

    local procedure RecepTrans(TransHeaderO: Record "Transfer Header")
    var
        myInt: Integer;
        TransHeader: Record "Transfer Header";
        RealseTransf: Codeunit "Release Transfer Document";
        POSSESION: Codeunit "LSC POS Session";
        TransferPostShipment: Codeunit "TransferOrder-Post Shipment";
        RegisterRe: Codeunit "LSC Picking/Receiving Confirm";
    begin
        if TransHeader.Get(TransHeaderO."No.") then begin
            if TransHeader."Posting Date" <> Today then
                TransHeader."Posting Date" := Today;
            if TransHeader."Receipt Date" <> Today then
                TransHeader."Receipt Date" := Today;
            TransHeader.Modify(true);
            RealseTransf.Run(TransHeader);
            if TransHeader.Get(TransHeader."No.") then
                TransferPostShipment.Run(TransHeader);
            Commit();
            //Creación automática de recepción
            if TransHeader.Get(TransHeader."No.") then
                CreateReception(TransHeader);
        end;
    end;

    //Crear transferecia interna
    local procedure CreateTransfer(var TransHeader: Record "Transfer Header"; salesHeader: Record "Sales Header"): Boolean
    var
        RecordLink: Record "Record Link";
        OutStream: OutStream;
    begin
        TransHeader.INIT;
        TransHeader.Validate("Transfer-from Code", salesHeader."Package Tracking No.");
        TransHeader.Validate("Transfer-to Code", salesHeader."Location Code");
        TransHeader.Validate("In-Transit Code", 'OWN LOG.');
        if TransHeader.Insert(TRUE) then begin
            TransHeader.Validate("LSC Store-from", salesHeader."Package Tracking No.");
            TransHeader.Validate("LSC Store-to", salesHeader."Location Code");
            TransHeader."FSN Internal Control" := salesHeader."No.";
            TransHeader.Modify(TRUE);
            Commit();
        end;
    end;

    procedure AddNoteToTransferOrder(var TransferHeader: Record "Transfer Header"; NoteText: Text)
    var
        RecordLink: Record "Record Link";
        RecordLinkManagement: Codeunit "Record Link Management";
    begin
        RecordLink.Init();
        RecordLink."Record ID" := TransferHeader.RecordId;
        RecordLink.Type := RecordLink.Type::Note;
        RecordLink.Description := CopyStr(NoteText, 1, MaxStrLen(RecordLink.Description));
        RecordLink."User ID" := UserId();
        RecordLink.Created := CurrentDateTime();
        RecordLink.Company := CompanyName();
        RecordLink.Insert(true);
        RecordLinkManagement.WriteNote(RecordLink, NoteText);
        RecordLink.Modify(true);
        Commit();
    end;
    //Insertar productos a la transferencia
    local procedure InsertTransferLine(var TransHeader: Record "Transfer Header"; salesHeader: Record "Sales Header"): Boolean
    var
        TransLine: Record "Transfer Line";
        salesLine: Record "Sales Line";
        SalesInvLine: Record "Sales Invoice Line";
    begin
        SalesInvLine.RESET;
        SalesInvLine.SETRANGE("Document No.", salesHeader."No.");
        SalesInvLine.SETRANGE("Type", salesLine.Type::Item);
        if SalesInvLine.Find('-') then
            repeat
                TransLine.INIT;
                TransLine.Validate("Document No.", TransHeader."No.");
                TransLine.Validate("Line No.", TransLine."Line No." + 10000);
                TransLine.Validate("Item No.", SalesInvLine."No.");
                TransLine.Validate("Unit of Measure Code", SalesInvLine."Unit of Measure Code");
                TransLine.Validate(Quantity, SalesInvLine.Quantity);
                TransLine.Insert(TRUE);
                Commit();
                TransLine.Validate("Qty. to Ship", TransLine.Quantity);
                TransLine."FSN Checked" := true;
                TransLine.Modify(TRUE);
                Commit();
            until SalesInvLine.NEXT = 0;
        Commit();
    end;

    local procedure CreateReception(TransFerHeader: Record "Transfer Header")
    var
        PRHeader: Record "LSC P/R Counting Header";
        PRConfirm: Codeunit "LSC Picking/Receiving Confirm";
        PRLine: Record "LSC Picking / Receiving lines";
        RegisC: Codeunit "FSN Picking/Receiving - Post";
        DteRegister: Record "FSN DTE Transaction Header";
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line" temporary;
        Processed: Boolean;
        MsgResult: text;
        FSNUtility: Codeunit "FSN Utility";
    begin
        PRHeader.Init();
        PRHeader.Validate(Receiving, PRHeader.Receiving::"Transfer In");
        PRHeader."Store No." := TransFerHeader."Transfer-to Code";
        PRHeader."Location Code" := TransFerHeader."Transfer-to Code";
        PRHeader.Insert(true);
        PRHeader.VALIDATE("Reference No.", TransFerHeader."No.");
        PRHeader.Validate("Counted Date", Today());
        if PRHeader.Modify(true) then begin
            PRConfirm.InitCodeunit(TRUE);
            PRConfirm.RUN(PRHeader);
            Commit();
            DteRegister.Reset();
            DteRegister.SetRange("DTE Invoice", TransFerHeader."External Document No.");
            if DteRegister.FindFirst() then begin
                RequestID := 'UPD-DTE-HISRECPURA';
                PosMenuLineTemp.Init();
                PosMenuLineTemp."Menu ID" := PRHeader."No.";
                PosMenuLineTemp."Set Current-Input" := DteRegister."DTE Invoice";
                PosMenuLineTemp."Current-Description" := DteRegister."DTE AuthNumber";
                PosMenuLineTemp."Current-Description2" := DteRegister."Signature Validation";
                FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
            end;
            //Error(format(PRHeader."Counted Date"));
            PRLine.Reset();
            PRLine.SetRange("Document No.", PRHeader."No.");
            if PRLine.find('-') then
                repeat
                    if PRLine.Quantity <> PRLine."Ordered Qty." then begin
                        PRLine.Validate(Quantity, PRLine."Ordered Qty.");
                        PRLine.Modify(true);
                    end;
                until PRLine.Next() = 0;
            IF PRHeader."Counted Date" <> Today THEN begin
                PRHeader.Validate("Counted Date", Today());
                PRHeader.Modify(true);
            end;
            PRConfirm.InitCodeunit(TRUE);
            PRConfirm.RUN(PRHeader);
            Commit();
            RegisC.Run(PRHeader);
        end;
    END;

    local procedure HasFirstItemWithAttribute(var pTransferHeader: Record "Transfer Header"; AttributeName: Text[100]): Boolean
    var
        TransferLine: Record "Transfer Line";
        Item: Record Item;
    begin
        if AttributeName = '' then
            exit(false);

        // Solo se evalua el primer articulo
        TransferLine.Reset();
        TransferLine.SetCurrentKey("Document No.", "Line No.");
        TransferLine.SetRange("Document No.", pTransferHeader."No.");
        TransferLine.SetRange("Derived From Line No.", 0);

        if not TransferLine.FindFirst() then
            exit(false);

        // 1) ve el (FSN Attrib 1 Code) asignado a atributname
        if (TransferLine."FSN Attrib 1 Code" <> '') and (UpperCase(TransferLine."FSN Attrib 1 Code") = UpperCase(AttributeName)) then
            exit(true);

        // 2) revisa el campo perzanalizado disponible (LSC Attrib 1 Code)
        if (TransferLine."Item No." <> '') and Item.Get(TransferLine."Item No.") then
            if (Item."LSC Attrib 1 Code" <> '') and (UpperCase(Item."LSC Attrib 1 Code") = UpperCase(AttributeName)) then
                exit(true);

        exit(false);
    end;

    procedure GetPreferredTransferFromCode(var pTransferHeader: Record "Transfer Header"): Code[10]
    var
        HasLicitation: Boolean;
    begin
        // Si el origen no es 'CD', devolver el código original sin aplicar lógica de LICITACION.
        if UpperCase(pTransferHeader."Transfer-from Code") <> 'CD' then
            exit(pTransferHeader."Transfer-from Code");

        // Evaluar solo el primer artículo para el atributo LICITACION.
        HasLicitation := HasFirstItemWithAttribute(pTransferHeader, 'LICITACION');
        if HasLicitation then
            exit('FCD')
        else
            exit('CDF');
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Purch.-Post (Yes/No)", 'OnAfterConfirmPost', '', false, false)]
    local procedure OnAfterConfirmPost(PurchaseHeader: Record "Purchase Header")
    begin
        ValidateVendorItemsOnReturn(PurchaseHeader);
    end;

    local procedure ValidateVendorItemsOnReturn(var PurchaseHeader: Record "Purchase Header")
    var
        PurchaseLine: Record "Purchase Line";
        ItemVendor: Record "Item Vendor";
    begin
        if PurchaseHeader."Document Type" <> PurchaseHeader."Document Type"::"Return Order" then
            exit;

        if PurchaseHeader."Buy-from Vendor No." = '' then
            exit;

        PurchaseLine.SetRange("Document Type", PurchaseHeader."Document Type");
        PurchaseLine.SetRange("Document No.", PurchaseHeader."No.");

        if PurchaseLine.FindSet() then
            repeat
                if (PurchaseLine.Type = PurchaseLine.Type::Item) and (PurchaseLine."No." <> '') then begin
                    ItemVendor.SetRange("Item No.", PurchaseLine."No.");
                    ItemVendor.SetRange("Vendor No.", PurchaseHeader."Buy-from Vendor No.");
                    if not ItemVendor.FindFirst() then
                        Error(ErrItemVendorMissing, PurchaseLine."No.", PurchaseHeader."Buy-from Vendor No.");
                end;
            until PurchaseLine.Next() = 0;
    end;

    procedure CreateDirectReceiptsFromPITS(FilterTR: Code[20]; MaxWR: Integer)
    var
        PITSLine: Record PITS_WMScd2suc;
        PITSLineDTE: Record PITS_WMScd2suc;
        PITSLineTemp: Record PITS_WMScd2suc;
        WhseRcptHeader: Record "Warehouse Receipt Header";
        NoSeries: Codeunit NoSeriesManagement;
        NextWhseRcptNo: Code[20];
        LocationCode: Code[10];
        CurrentDTE: Code[35];
        CurrentTR: Code[20];
        StartingDate: Date;
        EndingDate: Date;
        WRCreatedCount: Integer;
        i: Integer;
        lText001: Label 'No hay líneas PITS con cantidad mayor a 0';
        lText002: Label 'Error creando Recepción de Almacén para TR %1, DTE %2: %3';
        lText003: Label 'Ubicación destino vacía en líneas de TR %1, DTE %2';
        lText006: Label 'Se alcanzó el limite de %1 encabezados creados';
        lText010: Label 'WR creados: %1. Rango WR: %2 - %3. DTEs: %4. TRs: %5.';
        LastDTE: Code[35];
        DTECount: Integer;
        TRList: List of [Code[20]];
        FirstWRNo: Code[20];
        LastWRNo: Code[20];
        ValidationError: Text;
        ValidationShelfNo: Code[10];
        lText011: Label 'No hay líneas candidatas para TR %1 (Completado=FALSE, Histórico=Abierto, Qty to Ship>0, Quantity>0, No. Remisión no vacío).';
        lText013: Label 'Proceso PITS-RCPT finalizado. WR creados: %1. Rango WR: %2 - %3. DTEs: %4. TRs: %5. Omitidos por validación: %6. Omitidos por ubicación vacía: %7. Límite alcanzado: %8.';
        lText014: Label 'Detalle validación omitida: TR=%1, DTE=%2, Shelf=%3, Motivo=%4.';
        lText015: Label 'Detalle ubicación omitida: TR=%1, DTE=%2, Shelf=%3, Motivo=%4.';
        ValidationSkippedCount: Integer;
        MissingLocationCount: Integer;
        LimitReached: Boolean;
        LimitText: Text[100];
        FirstValidationTR: Code[20];
        FirstValidationDTE: Code[35];
        FirstValidationShelf: Code[10];
        FirstValidationReason: Text[250];
        FirstMissingLocTR: Code[20];
        FirstMissingLocDTE: Code[35];
        FirstMissingLocShelf: Code[10];
        FirstMissingLocReason: Text[250];
        ValidationDetailText: Text[350];
        MissingLocationDetailText: Text[350];
    begin
        // Inicializar contador
        WRCreatedCount := 0;
        ValidationSkippedCount := 0;
        MissingLocationCount := 0;
        LimitReached := false;
        FirstValidationTR := '';
        FirstValidationDTE := '';
        FirstValidationShelf := '';
        FirstValidationReason := '';
        FirstMissingLocTR := '';
        FirstMissingLocDTE := '';
        FirstMissingLocShelf := '';
        FirstMissingLocReason := '';

        // PASO 1: Recorrer lineas en orden de DTE sin cargar toda la tabla
        PITSLine.RESET;
        PITSLine.SETCURRENTKEY("No. Remision", Completado, "FSN TransferHistorico");
        PITSLine.SetLoadFields("No. Remision");
        PITSLine.SETRANGE(Completado, FALSE);
        PITSLine.SETRANGE("FSN TransferHistorico", PITSLine."FSN TransferHistorico"::Abierto);
        PITSLine.SETFILTER("Qty. to Ship", '>0');
        PITSLine.SETFILTER(Quantity, '>0');
        PITSLine.SETFILTER("No. Remision", '<>%1', ''); // No procesar líneas sin DTE

        if FilterTR <> '' then
            PITSLine.SETRANGE("No.", FilterTR);

        if not PITSLine.FINDSET(FALSE, FALSE) then begin
            if FilterTR <> '' then
                SavePITSHeaderLastError(FilterTR, '', StrSubstNo(lText011, FilterTR));
            if GuiAllowed then
                if FilterTR <> '' then
                    Message(lText011, FilterTR)
                else
                    Message(lText001);
            exit;
        end;

        LastDTE := '';
        repeat
            if (MaxWR > 0) and (WRCreatedCount >= MaxWR) then begin
                LimitReached := true;
            end;

            if not LimitReached then begin
                CurrentDTE := PITSLine."No. Remision";
                if CurrentDTE <> LastDTE then begin
                    LastDTE := CurrentDTE;
                    // Verificar limite si se requiere
                    if (MaxWR > 0) and (WRCreatedCount >= MaxWR) then begin
                        LimitReached := true;
                    end;

                    if not LimitReached then begin
                        // Obtener ubicación, fechas y TR de la primera línea de este DTE
                        PITSLineDTE.RESET;
                        if FilterTR <> '' then
                            PITSLineDTE.SETRANGE("No.", FilterTR);
                        PITSLineDTE.SETRANGE("No. Remision", CurrentDTE);
                        PITSLineDTE.SETRANGE(Completado, FALSE);
                        PITSLineDTE.SETRANGE("FSN TransferHistorico", PITSLineDTE."FSN TransferHistorico"::Abierto);
                        PITSLineDTE.SETFILTER("Qty. to Ship", '>0');
                        PITSLineDTE.SETFILTER(Quantity, '>0');

                        if PITSLineDTE.FINDFIRST then begin
                            LocationCode := PITSLineDTE."Transfer-to Code";
                            StartingDate := PITSLineDTE."Starting Date";
                            EndingDate := PITSLineDTE."Ending Date";
                            CurrentTR := PITSLineDTE."No.";

                            if LocationCode <> '' then begin
                                ValidationError := '';
                                ValidationShelfNo := '';
                                if HasMatchingTransferLines(CurrentTR, CurrentDTE, ValidationError, ValidationShelfNo) then begin
                                    // Si ya pasó validaciones para crear WR, limpiar error previo del nivel/shelf.
                                    ClearPITSHeaderLastError(CurrentTR, PITSLineDTE."Shelf No.");

                                    // Crear cabecera de Warehouse Receipt para este DTE
                                    NextWhseRcptNo := NoSeries.GetNextNo('WHSE_RCPT', TODAY, TRUE);
                                    WhseRcptHeader.INIT;
                                    WhseRcptHeader."No." := NextWhseRcptNo;
                                    WhseRcptHeader."Location Code" := LocationCode;
                                    WhseRcptHeader."Posting Date" := EndingDate;
                                    WhseRcptHeader."Assignment Date" := StartingDate;
                                    WhseRcptHeader."Vendor Shipment No." := CurrentDTE; // DTE
                                    WhseRcptHeader."FSN External Document No." := CurrentTR; // TR

                                    if WhseRcptHeader.INSERT(TRUE) then begin
                                        WRCreatedCount += 1;
                                        if WRCreatedCount = 1 then
                                            FirstWRNo := NextWhseRcptNo;
                                        LastWRNo := NextWhseRcptNo;
                                        DTECount += 1;
                                        if not TRList.Contains(CurrentTR) then
                                            TRList.Add(CurrentTR);

                                        // Marcar TODAS las líneas de este DTE como procesadas
                                        PITSLineTemp.RESET;
                                        if FilterTR <> '' then
                                            PITSLineTemp.SETRANGE("No.", FilterTR);
                                        PITSLineTemp.SETRANGE("No. Remision", CurrentDTE);
                                        PITSLineTemp.SETRANGE(Completado, FALSE);
                                        PITSLineTemp.SETRANGE("FSN TransferHistorico", PITSLineTemp."FSN TransferHistorico"::Abierto);
                                        PITSLineTemp.SETFILTER("Qty. to Ship", '>0');
                                        PITSLineTemp.SETFILTER(Quantity, '>0');

                                        if PITSLineTemp.FINDSET(FALSE, FALSE) then begin
                                            repeat
                                                if PITSLine.GET(PITSLineTemp."No.", PITSLineTemp."Line No.") then begin
                                                    PITSLine.Completado := TRUE;
                                                    PITSLine."FSN Warehouse Receipt No." := NextWhseRcptNo;
                                                    PITSLine."FSN TransferHistorico" := PITSLine."FSN TransferHistorico"::Lanzado;
                                                    PITSLine.MODIFY(FALSE);
                                                    COMMIT; // Commit después de cada línea para evitar bloqueos
                                                end;
                                            until PITSLineTemp.NEXT = 0;
                                        end;

                                        // Actualizar Transfer Line con el estado de WR creado
                                        UpdateTransferLineAfterWRCreation(CurrentTR);
                                    end else
                                        SavePITSHeaderLastError(CurrentTR, PITSLineDTE."Shelf No.", StrSubstNo(lText002, CurrentTR, CurrentDTE, GetLastErrorText()));
                                end else begin
                                    ValidationSkippedCount += 1;
                                    if FirstValidationTR = '' then begin
                                        FirstValidationTR := CurrentTR;
                                        FirstValidationDTE := CurrentDTE;
                                        FirstValidationShelf := ValidationShelfNo;
                                        FirstValidationReason := CopyStr(ValidationError, 1, MaxStrLen(FirstValidationReason));
                                    end;
                                    SavePITSHeaderLastError(CurrentTR, ValidationShelfNo, ValidationError);
                                end;
                            end else begin
                                MissingLocationCount += 1;
                                ValidationError := StrSubstNo(lText003, CurrentTR, CurrentDTE);
                                if FirstMissingLocTR = '' then begin
                                    FirstMissingLocTR := CurrentTR;
                                    FirstMissingLocDTE := CurrentDTE;
                                    FirstMissingLocShelf := PITSLineDTE."Shelf No.";
                                    FirstMissingLocReason := CopyStr(ValidationError, 1, MaxStrLen(FirstMissingLocReason));
                                end;
                                SavePITSHeaderLastError(CurrentTR, PITSLineDTE."Shelf No.", ValidationError);
                            end;
                        end;
                    end;
                end;
            end;
        until (PITSLine.NEXT = 0) or LimitReached;

        if LimitReached then
            LimitText := StrSubstNo(lText006, MaxWR)
        else
            LimitText := 'No';

        ValidationDetailText := '';
        if ValidationSkippedCount > 0 then
            ValidationDetailText := StrSubstNo(lText014, FirstValidationTR, FirstValidationDTE, FirstValidationShelf, FirstValidationReason);

        MissingLocationDetailText := '';
        if MissingLocationCount > 0 then
            MissingLocationDetailText := StrSubstNo(lText015, FirstMissingLocTR, FirstMissingLocDTE, FirstMissingLocShelf, FirstMissingLocReason);

        if GuiAllowed then
            Message(lText013 + '\\' + ValidationDetailText + '\\' + MissingLocationDetailText,
              WRCreatedCount,
              FirstWRNo,
              LastWRNo,
              DTECount,
              TRList.Count,
              ValidationSkippedCount,
              MissingLocationCount,
              LimitText);
    end;

    local procedure HasMatchingTransferLines(TR: Code[20]; DTE: Code[35]; var FailReason: Text; var FailShelfNo: Code[10]): Boolean
    var
        TransferLine: Record "Transfer Line";
        PITSLineCompare: Record PITS_WMScd2suc;
        lText001: Label 'No hay líneas PITS válidas para TR %1 y DTE %2.';
        lText002: Label 'No existe Transfer Line para TR %1, Line No. %2.';
        lText003: Label 'Transfer Line derivada detectada en TR %1, Line No. %2 (Derived From Line No.=%3).';
        lText004: Label 'No se creó WR para TR %1, DTE %2. Línea %3, Item %4: Qty. to Ship (%5) no puede ser mayor que Quantity (%6).';
    begin
        FailReason := '';
        FailShelfNo := '';

        PITSLineCompare.Reset();
        PITSLineCompare.SetRange("No.", TR);
        PITSLineCompare.SetRange("No. Remision", DTE);
        PITSLineCompare.SetRange(Completado, false);
        PITSLineCompare.SetRange("FSN TransferHistorico", PITSLineCompare."FSN TransferHistorico"::Abierto);
        PITSLineCompare.SetFilter("Qty. to Ship", '>0');
        PITSLineCompare.SetFilter(Quantity, '>0');
        PITSLineCompare.SetLoadFields("No.", "Line No.", "Item No.", "Qty. to Ship", Quantity, "Shelf No.");
        if not PITSLineCompare.FindSet(false, false) then begin
            FailReason := StrSubstNo(lText001, TR, DTE);
            exit(false);
        end;

        TransferLine.SetCurrentKey("Document No.", "Line No.");
        repeat
            if PITSLineCompare."Qty. to Ship" > PITSLineCompare.Quantity then begin
                FailShelfNo := PITSLineCompare."Shelf No.";
                FailReason := StrSubstNo(
                    lText004,
                    TR,
                    DTE,
                    Format(PITSLineCompare."Line No."),
                    PITSLineCompare."Item No.",
                    Format(PITSLineCompare."Qty. to Ship"),
                    Format(PITSLineCompare.Quantity));
                exit(false);
            end;

            if not TransferLine.Get(TR, PITSLineCompare."Line No.") then begin
                FailShelfNo := PITSLineCompare."Shelf No.";
                FailReason := StrSubstNo(lText002, TR, Format(PITSLineCompare."Line No."));
                exit(false);
            end;
            if TransferLine."Derived From Line No." <> 0 then begin
                FailShelfNo := PITSLineCompare."Shelf No.";
                FailReason := StrSubstNo(lText003, TR, Format(TransferLine."Line No."), Format(TransferLine."Derived From Line No."));
                exit(false);
            end;
        until PITSLineCompare.Next() = 0;

        exit(true);
    end;

    local procedure SavePITSHeaderLastError(TR: Code[20]; ShelfNo: Code[10]; ErrorText: Text)
    var
        ExternalTransferHeader: Record PITS_WMScd2sucHeaders;
        LevelNo: Integer;
    begin
        if (TR = '') or (ErrorText = '') then
            exit;

        ExternalTransferHeader.Reset();
        ExternalTransferHeader.SetCurrentKey(No_, "Source No_", Nivel);
        ExternalTransferHeader.SetRange(No_, TR);

        if Evaluate(LevelNo, ShelfNo) then
            ExternalTransferHeader.SetRange(Nivel, LevelNo);

        if not ExternalTransferHeader.FindFirst() then begin
            ExternalTransferHeader.SetRange(Nivel);
            if not ExternalTransferHeader.FindFirst() then
                exit;
        end;

        // Sobrescribe siempre el error previo con el más reciente
        ExternalTransferHeader."Ultimo Error" := '';
        ExternalTransferHeader."Ultimo Error" := CopyStr(ErrorText, 1, MaxStrLen(ExternalTransferHeader."Ultimo Error"));
        ExternalTransferHeader.Modify(true);
    end;

    local procedure ClearPITSHeaderLastError(TR: Code[20]; ShelfNo: Code[10])
    var
        ExternalTransferHeader: Record PITS_WMScd2sucHeaders;
        LevelNo: Integer;
    begin
        if TR = '' then
            exit;

        ExternalTransferHeader.Reset();
        ExternalTransferHeader.SetCurrentKey(No_, "Source No_", Nivel);
        ExternalTransferHeader.SetRange(No_, TR);

        if Evaluate(LevelNo, ShelfNo) then
            ExternalTransferHeader.SetRange(Nivel, LevelNo);

        if not ExternalTransferHeader.FindFirst() then begin
            ExternalTransferHeader.SetRange(Nivel);
            if not ExternalTransferHeader.FindFirst() then
                exit;
        end;

        if ExternalTransferHeader."Ultimo Error" <> '' then begin
            ExternalTransferHeader."Ultimo Error" := '';
            ExternalTransferHeader.Modify(true);
        end;
    end;

    local procedure UpdateTransferLineAfterWRCreation(TR: Code[20])
    var
        TransferLine: Record "Transfer Line";
        PITSLine: Record PITS_WMScd2suc;
        LineQuantity: Decimal;
        LineQuantityBase: Decimal;
    begin
        // Actualizar Transfer Line después de crear WR
        // Solo actualizar las líneas específicas que fueron procesadas en este WR
        PITSLine.RESET;
        PITSLine.SETFILTER("No.", TR);
        PITSLine.SETFILTER("Qty. to Ship", '>0');
        PITSLine.SETFILTER(Quantity, '>0');

        if PITSLine.FINDSET then begin
            repeat
                // Buscar Transfer Line específica por Document No. Y Line No.
                if TransferLine.GET(TR, PITSLine."Line No.") then begin
                    LineQuantity := TransferLine.Quantity;
                    LineQuantityBase := TransferLine."Quantity (Base)";
                    TransferLine."Qty. to Ship" := LineQuantity;
                    TransferLine."Qty. to Ship (Base)" := LineQuantityBase;
                    TransferLine."Quantity Shipped" := 0;
                    TransferLine."Qty. Shipped (Base)" := 0;
                    TransferLine."Qty. in Transit" := 0;
                    TransferLine."Qty. in Transit (Base)" := 0;
                    TransferLine."Outstanding Quantity" := LineQuantity;
                    TransferLine."Outstanding Qty. (Base)" := LineQuantityBase;
                    TransferLine."Qty. to Receive" := LineQuantity;
                    TransferLine."Qty. to Receive (Base)" := LineQuantityBase;
                    TransferLine."Quantity Received" := 0;
                    TransferLine."Qty. Received (Base)" := 0;
                    TransferLine."In-Transit Code" := '';
                    TransferLine."Completely Shipped" := false;
                    TransferLine."Completely Received" := false;
                    TransferLine.MODIFY(TRUE);
                end;
            until PITSLine.NEXT = 0;
        end;
    end;

    local procedure UpdateTransferLineAfterHistoricalCreation(TR: Code[20]; WRNumber: Code[20])
    var
        TransferLine: Record "Transfer Line";
        PITSLine: Record PITS_WMScd2suc;
        LineQuantity: Decimal;
        LineQuantityBase: Decimal;
    begin
        // Actualizar Transfer Line después de crear histórico
        // Solo actualizar las líneas específicas del WR procesado
        PITSLine.RESET;
        PITSLine.SETRANGE("FSN Warehouse Receipt No.", WRNumber);
        PITSLine.SETFILTER("No.", TR);
        PITSLine.SETFILTER("Qty. to Ship", '>0');
        PITSLine.SETFILTER(Quantity, '>0');

        if PITSLine.FINDSET then begin
            repeat
                // Buscar Transfer Line específica por Document No. Y Line No.
                if TransferLine.GET(TR, PITSLine."Line No.") then begin
                    LineQuantity := TransferLine.Quantity;
                    LineQuantityBase := TransferLine."Quantity (Base)";
                    TransferLine."Qty. to Ship" := 0;
                    TransferLine."Qty. to Ship (Base)" := 0;
                    TransferLine."Quantity Shipped" := LineQuantity;
                    TransferLine."Qty. Shipped (Base)" := LineQuantityBase;
                    TransferLine."Qty. in Transit" := 0;
                    TransferLine."Qty. in Transit (Base)" := 0;
                    TransferLine."Outstanding Quantity" := 0;
                    TransferLine."Outstanding Qty. (Base)" := 0;
                    TransferLine."Qty. to Receive" := 0;
                    TransferLine."Qty. to Receive (Base)" := 0;
                    TransferLine."Quantity Received" := LineQuantity;
                    TransferLine."Qty. Received (Base)" := LineQuantityBase;
                    TransferLine."In-Transit Code" := 'OWN LOG.';
                    TransferLine."Completely Shipped" := true;
                    TransferLine."Completely Received" := true;
                    TransferLine.MODIFY(TRUE);
                end;
            until PITSLine.NEXT = 0;
        end;
    end;

    procedure RegisterPITSTransfer(WRNumber: Code[20]): Boolean
    var
        PITSLine: Record PITS_WMScd2suc;
        PITSLineRead: Record PITS_WMScd2suc;
        ItemJnlLine: Record "Item Journal Line";
        ItemJnlTemplate: Record "Item Journal Template";
        ItemJnlBatch: Record "Item Journal Batch";
        WhseRcptHeader: Record "Warehouse Receipt Header";
        Item: Record Item;
        ItemLedgerEntry: Record "Item Ledger Entry";
        LineNo: Integer;
        DTE: Code[35];
        TR: Code[30];
        lText001: Label 'No se encontró el WR %1';
        lText002: Label 'No hay líneas PITS para el WR %1';
        lText003: Label 'Error al registrar WR %1: %2';
        lText004: Label 'Validación de estado fallida: Hay líneas PITS con estado diferente a Lanzado (1) en el WR %1. Estado actual requerido: Lanzado';
        ErrorList: Text;
        HasErrors: Boolean;
        TrackingFailReason: Text;
        IsTrackingItem: Boolean;
        RecoveryErrorText: Text;
        ResumeAfterPosting: Boolean;
    begin
        if not WhseRcptHeader.Get(WRNumber) then
            Error(lText001, WRNumber);

        DTE := WhseRcptHeader."Vendor Shipment No.";
        TR := WhseRcptHeader."FSN External Document No.";

        ResumeAfterPosting := false;
        RecoveryErrorText := '';
        if WhseRcptHeader."FSN Proc Status" = WhseRcptHeader."FSN Proc Status"::Error then begin
            if TryRecoverErrorWR(WhseRcptHeader, RecoveryErrorText) then
                ResumeAfterPosting := true
            else begin
                if RecoveryErrorText <> '' then begin
                    WhseRcptHeader."FSN Proc Status" := WhseRcptHeader."FSN Proc Status"::Error;
                    WhseRcptHeader."FSN Proc Error" := CopyStr(RecoveryErrorText, 1, MaxStrLen(WhseRcptHeader."FSN Proc Error"));
                    WhseRcptHeader.Modify(true);
                    COMMIT;
                end;
                Error(lText003, WRNumber, RecoveryErrorText);
            end;
        end;

        if not ResumeAfterPosting then begin
            // VALIDACIÓN CRÍTICA: Verificar que NO hay líneas con estado incorrecto
            PITSLine.RESET;
            PITSLine.SETRANGE("FSN Warehouse Receipt No.", WRNumber);
            PITSLine.SETFILTER("Qty. to Ship", '>0');
            PITSLine.SETFILTER(Quantity, '>0');
            PITSLine.SETFILTER("FSN TransferHistorico", '<>1');  // Buscar líneas que NO sean Lanzado (1)
            if PITSLine.FINDFIRST then
                Error(lText004, WRNumber);

            // Solo procesar líneas con estado Lanzado (1) - USAR FINDSET(FALSE, FALSE) para evitar bloqueos
            PITSLineRead.RESET;
            PITSLineRead.SETRANGE("FSN Warehouse Receipt No.", WRNumber);
            PITSLineRead.SETRANGE("FSN TransferHistorico", PITSLineRead."FSN TransferHistorico"::Lanzado);
            PITSLineRead.SETFILTER("Qty. to Ship", '>0');
            PITSLineRead.SETFILTER(Quantity, '>0');

            if not PITSLineRead.FINDSET(FALSE, FALSE) then
                Error(lText002, WRNumber);

            if not ItemJnlTemplate.Get('TRANSFERIN') then
                Error('No se encontró la plantilla TRANSFERIN');

            if not ItemJnlBatch.Get('TRANSFERIN', 'CD2SUC') then
                Error('No se encontró el lote CD2SUC');

            ItemJnlLine.RESET;
            ItemJnlLine.SETRANGE("Journal Template Name", 'TRANSFERIN');
            ItemJnlLine.SETRANGE("Journal Batch Name", 'CD2SUC');
            ItemJnlLine.DELETEALL;

            LineNo := 10000;
            HasErrors := false;
            ErrorList := '';

            // Crear Item Journal Lines - usar variable de solo lectura PITSLineRead
            repeat
                IsTrackingItem := false;
                if Item.Get(PITSLineRead."Item No.") then
                    IsTrackingItem := Item."Item Tracking Code" <> '';

                if IsTrackingItem then begin
                    if not CreateTrackingJournalLinesFromSubLines(PITSLineRead, WRNumber, DTE, TR, LineNo, TrackingFailReason) then begin
                        HasErrors := true;
                        ErrorList += '\Línea ' + Format(PITSLineRead."Line No.") + ' / Item ' + PITSLineRead."Item No." + ' / DTE ' + PITSLineRead."No. Remision" + ': ' + TrackingFailReason;
                    end;
                end else begin
                    ItemJnlLine.INIT;
                    ItemJnlLine."Journal Template Name" := 'TRANSFERIN';
                    ItemJnlLine."Journal Batch Name" := 'CD2SUC';
                    ItemJnlLine."Line No." := LineNo;
                    ItemJnlLine.VALIDATE("Posting Date", TODAY);
                    ItemJnlLine.VALIDATE("Entry Type", ItemJnlLine."Entry Type"::Transfer);
                    ItemJnlLine.VALIDATE("Document No.", WRNumber);
                    ItemJnlLine.VALIDATE("Item No.", PITSLineRead."Item No.");
                    if PITSLineRead."Unit of Measure" <> '' then
                        ItemJnlLine.VALIDATE("Unit of Measure Code", PITSLineRead."Unit of Measure");
                    ItemJnlLine.VALIDATE("Location Code", 'CD');
                    ItemJnlLine.VALIDATE("New Location Code", PITSLineRead."Transfer-to Code");
                    ItemJnlLine.VALIDATE(Quantity, PITSLineRead."Qty. to Ship");
                    ItemJnlLine."External Document No." := DTE;
                    ItemJnlLine."Order No." := TR;
                    ItemJnlLine.VALIDATE("Order Line No.", PITSLineRead."Line No.");
                    ItemJnlLine.INSERT(TRUE);
                    LineNo += 10000;
                end;
            until PITSLineRead.NEXT = 0;

            // Si hay errores de tracking, mostrarlos y salir
            if HasErrors then
                Error('Errores de tracking en WR %1:\%2', WRNumber, ErrorList);

            COMMIT;

            // Postear Item Journal
            ItemJnlLine.RESET;
            ItemJnlLine.SETRANGE("Journal Template Name", 'TRANSFERIN');
            ItemJnlLine.SETRANGE("Journal Batch Name", 'CD2SUC');
            if ItemJnlLine.FINDFIRST then begin
                if not CODEUNIT.RUN(CODEUNIT::"Item Jnl.-Post", ItemJnlLine) then begin
                    Error(lText003, WRNumber, GETLASTERRORTEXT);
                end;
            end;

            COMMIT;
        end;

        if not MarkPITSLinesAsRegistrado(WRNumber, RecoveryErrorText) then
            Error(lText003, WRNumber, RecoveryErrorText);

        // Crear histórico en Transfer Receipt Header y Lines después del registro exitoso
        CreateTransferReceiptHistory(WRNumber);

        // Actualizar Transfer Line con el estado final después de crear histórico (solo para el WR específico)
        UpdateTransferLineAfterHistoricalCreation(TR, WRNumber);

        exit(true);
    end;

    local procedure TryRecoverErrorWR(var WhseRcptHeader: Record "Warehouse Receipt Header"; var ErrorText: Text): Boolean
    var
        PITSLine: Record PITS_WMScd2suc;
        Item: Record Item;
        ItemJnlLine: Record "Item Journal Line";
        ItemJnlTemplate: Record "Item Journal Template";
        ItemJnlBatch: Record "Item Journal Batch";
        MissingBase: Decimal;
        ExpectedBase: Decimal;
        PostedBase: Decimal;
        QtyPerUom: Decimal;
        NeedPosting: Boolean;
        NextLineNo: Integer;
        DTE: Code[35];
        TR: Code[30];
        QtyTolerance: Decimal;
        TrackingFailReason: Text;
        IsTrackingItem: Boolean;
        lText001: Label 'No hay líneas PITS para el WR %1.';
        lText002: Label 'No se encontró el artículo %1.';
        lText003: Label 'Inconsistencia ILE en WR %1, línea %2, item %3. ILE=%4, Esperado=%5.';
        lText004: Label 'No se encontró la plantilla TRANSFERIN.';
        lText005: Label 'No se encontró el lote CD2SUC.';
        lText006: Label 'Error al registrar WR %1: %2';
    begin
        ErrorText := '';
        QtyTolerance := 0.00001;
        DTE := WhseRcptHeader."Vendor Shipment No.";
        TR := WhseRcptHeader."FSN External Document No.";

        PITSLine.Reset();
        PITSLine.SetRange("FSN Warehouse Receipt No.", WhseRcptHeader."No.");
        PITSLine.SetFilter("Qty. to Ship", '>0');
        PITSLine.SetFilter(Quantity, '>0');
        if not PITSLine.FindSet(false, false) then begin
            ErrorText := StrSubstNo(lText001, WhseRcptHeader."No.");
            exit(false);
        end;

        NeedPosting := false;
        NextLineNo := 10000;

        repeat
            if not Item.Get(PITSLine."Item No.") then begin
                ErrorText := StrSubstNo(lText002, PITSLine."Item No.");
                exit(false);
            end;

            QtyPerUom := GetQtyPerUOM(PITSLine."Item No.", PITSLine."Unit of Measure");
            if QtyPerUom = 0 then
                QtyPerUom := 1;

            ExpectedBase := PITSLine."Qty. to Ship" * QtyPerUom;
            PostedBase := GetPostedQtyBaseForLine(WhseRcptHeader."No.", TR, PITSLine."Line No.");

            if PostedBase > (ExpectedBase + QtyTolerance) then begin
                ErrorText := StrSubstNo(lText003, WhseRcptHeader."No.", Format(PITSLine."Line No."), PITSLine."Item No.",
                    Format(PostedBase), Format(ExpectedBase));
                exit(false);
            end;

            MissingBase := ExpectedBase - PostedBase;
            if MissingBase > QtyTolerance then begin
                if not NeedPosting then begin
                    if not ItemJnlTemplate.Get('TRANSFERIN') then begin
                        ErrorText := lText004;
                        exit(false);
                    end;
                    if not ItemJnlBatch.Get('TRANSFERIN', 'CD2SUC') then begin
                        ErrorText := lText005;
                        exit(false);
                    end;

                    ItemJnlLine.Reset();
                    ItemJnlLine.SetRange("Journal Template Name", 'TRANSFERIN');
                    ItemJnlLine.SetRange("Journal Batch Name", 'CD2SUC');
                    ItemJnlLine.DeleteAll();
                    NeedPosting := true;
                end;

                IsTrackingItem := Item."Item Tracking Code" <> '';
                if IsTrackingItem then begin
                    TrackingFailReason := '';
                    if not CreateMissingTrackingJournalLinesFromSubLines(PITSLine, WhseRcptHeader."No.", DTE, TR, MissingBase, NextLineNo, TrackingFailReason) then begin
                        ErrorText := TrackingFailReason;
                        exit(false);
                    end;
                end else begin
                    if not CreateMissingJournalLineNonTracking(PITSLine, WhseRcptHeader."No.", DTE, TR, MissingBase, QtyPerUom, NextLineNo, ErrorText) then
                        exit(false);
                end;
            end;
        until PITSLine.Next() = 0;

        if NeedPosting then begin
            COMMIT;
            ItemJnlLine.Reset();
            ItemJnlLine.SetRange("Journal Template Name", 'TRANSFERIN');
            ItemJnlLine.SetRange("Journal Batch Name", 'CD2SUC');
            if ItemJnlLine.FindFirst() then
                if not CODEUNIT.RUN(CODEUNIT::"Item Jnl.-Post", ItemJnlLine) then begin
                    ErrorText := StrSubstNo(lText006, WhseRcptHeader."No.", GetLastErrorText());
                    exit(false);
                end;
            COMMIT;
        end;

        exit(true);
    end;

    local procedure CreateMissingJournalLineNonTracking(PITSLine: Record PITS_WMScd2suc; WRNumber: Code[20]; DTE: Code[35]; TR: Code[30]; MissingBase: Decimal; QtyPerUom: Decimal; var NextLineNo: Integer; var ErrorText: Text): Boolean
    var
        ItemJnlLine: Record "Item Journal Line";
        MissingQtyUom: Decimal;
        QtyTolerance: Decimal;
    begin
        QtyTolerance := 0.00001;
        if QtyPerUom = 0 then begin
            ErrorText := StrSubstNo('Unidad de medida inválida para item %1.', PITSLine."Item No.");
            exit(false);
        end;

        MissingQtyUom := MissingBase / QtyPerUom;
        if MissingQtyUom <= QtyTolerance then
            exit(true);

        ItemJnlLine.Init();
        ItemJnlLine."Journal Template Name" := 'TRANSFERIN';
        ItemJnlLine."Journal Batch Name" := 'CD2SUC';
        ItemJnlLine."Line No." := NextLineNo;
        ItemJnlLine.Validate("Posting Date", Today);
        ItemJnlLine.Validate("Entry Type", ItemJnlLine."Entry Type"::Transfer);
        ItemJnlLine.Validate("Document No.", WRNumber);
        ItemJnlLine.Validate("Item No.", PITSLine."Item No.");
        if PITSLine."Unit of Measure" <> '' then
            ItemJnlLine.Validate("Unit of Measure Code", PITSLine."Unit of Measure");
        ItemJnlLine.Validate("Location Code", 'CD');
        ItemJnlLine.Validate("New Location Code", PITSLine."Transfer-to Code");
        ItemJnlLine.Validate(Quantity, MissingQtyUom);
        ItemJnlLine."External Document No." := DTE;
        ItemJnlLine."Order No." := TR;
        ItemJnlLine.Validate("Order Line No.", PITSLine."Line No.");
        ItemJnlLine.Insert(true);
        NextLineNo += 10000;
        exit(true);
    end;

    local procedure CreateMissingTrackingJournalLinesFromSubLines(PITSLine: Record PITS_WMScd2suc; WRNumber: Code[20]; DTE: Code[35]; TR: Code[30]; MissingBase: Decimal; var NextLineNo: Integer; var FailReason: Text): Boolean
    var
        PITSSubLine: Record "PITS Sub Line";
        ItemJnlLine: Record "Item Journal Line";
        ItemTrackingCode: Record "Item Tracking Code";
        ItemLedgerEntry: Record "Item Ledger Entry";
        Item: Record Item;
        LotNo: Code[50];
        ExpirationDate: Date;
        QtyPerUom: Decimal;
        RemainingMissingBase: Decimal;
        SubLineBase: Decimal;
        PostedLotBase: Decimal;
        RemainingLotBase: Decimal;
        UseBase: Decimal;
        UseQtyUom: Decimal;
        SelectedSubLineRemision: Code[35];
        QtyTolerance: Decimal;
        AvailableQtyByLot: Dictionary of [Code[50], Decimal];
        AllocatedQtyByLot: Dictionary of [Code[50], Decimal];
        AvailableLotKeys: List of [Code[50]];
        AvailableLotQty: Decimal;
        FreeLotQty: Decimal;
        LotExpirationByLot: Dictionary of [Code[50], Date];
        LotsByExpiration: List of [Code[50]];
        MinExpirationDate: Date;
        MinExpirationLot: Code[50];
        CurrentExpirationDate: Date;
        LotScanIdx: Integer;
        TotalAvailableQty: Decimal;
        AvailableLotsDetail: Text;
        FinalLotsDetail: Text;
        lText001: Label 'No se encontró el artículo %1.';
        lText002: Label 'El artículo %1 tiene Item Tracking Code vacío.';
        lText003: Label 'No se encontró el Item Tracking Code %1 para el artículo %2.';
        lText004: Label 'No hay lotes en PITS Sub Line para TR %1, Line No. %2, Item %3.';
        lText005: Label 'Lote vacío en PITS Sub Line para TR %1, Line No. %2, Item %3.';
        lText006: Label 'No tiene fecha de vencimiento válida para lote %1.';
        lText007: Label 'Faltante sin lotes suficientes para TR %1, Line No. %2, Item %3. Faltante=%4. Disponible total=%5. Remaining por lote=%6. Libre tras auto-cuadre=%7.';
    begin
        FailReason := '';
        QtyTolerance := 0.00001;
        RemainingMissingBase := MissingBase;

        if not Item.Get(PITSLine."Item No.") then begin
            FailReason := StrSubstNo(lText001, PITSLine."Item No.");
            exit(false);
        end;

        if Item."Item Tracking Code" = '' then begin
            FailReason := StrSubstNo(lText002, PITSLine."Item No.");
            exit(false);
        end;

        if not ItemTrackingCode.Get(Item."Item Tracking Code") then begin
            FailReason := StrSubstNo(lText003, Item."Item Tracking Code", PITSLine."Item No.");
            exit(false);
        end;

        QtyPerUom := GetQtyPerUOM(PITSLine."Item No.", PITSLine."Unit of Measure");
        if QtyPerUom = 0 then
            QtyPerUom := 1;

        TotalAvailableQty := 0;
        AvailableLotsDetail := '';
        ItemLedgerEntry.Reset();
        ItemLedgerEntry.SetRange("Item No.", PITSLine."Item No.");
        ItemLedgerEntry.SetRange("Location Code", 'CD');
        ItemLedgerEntry.SetRange(Open, true);
        ItemLedgerEntry.SetRange(Positive, true);
        ItemLedgerEntry.SetFilter("Remaining Quantity", '<>%1', 0);
        if ItemLedgerEntry.FindSet(false, false) then
            repeat
                LotNo := ItemLedgerEntry."Lot No.";
                if LotNo <> '' then begin
                    AvailableLotQty := ItemLedgerEntry."Remaining Quantity";
                    TotalAvailableQty += AvailableLotQty;
                    CurrentExpirationDate := ItemLedgerEntry."Expiration Date";
                    if not LotExpirationByLot.ContainsKey(LotNo) then
                        LotExpirationByLot.Add(LotNo, CurrentExpirationDate)
                    else begin
                        LotExpirationByLot.Get(LotNo, ExpirationDate);
                        if (CurrentExpirationDate <> 0D) and ((ExpirationDate = 0D) or (CurrentExpirationDate < ExpirationDate)) then
                            LotExpirationByLot.Set(LotNo, CurrentExpirationDate);
                    end;

                    if AvailableQtyByLot.ContainsKey(LotNo) then begin
                        AvailableQtyByLot.Get(LotNo, FreeLotQty);
                        AvailableQtyByLot.Set(LotNo, FreeLotQty + AvailableLotQty);
                    end else begin
                        AvailableQtyByLot.Add(LotNo, AvailableLotQty);
                        AvailableLotKeys.Add(LotNo);
                    end;
                end;
            until ItemLedgerEntry.Next() = 0;

        for LotScanIdx := 1 to AvailableLotKeys.Count do begin
            MinExpirationDate := 99991231D;
            MinExpirationLot := '';

            foreach LotNo in AvailableLotKeys do begin
                if not LotsByExpiration.Contains(LotNo) then begin
                    CurrentExpirationDate := 99991231D;
                    if LotExpirationByLot.ContainsKey(LotNo) then
                        LotExpirationByLot.Get(LotNo, CurrentExpirationDate);

                    if CurrentExpirationDate < MinExpirationDate then begin
                        MinExpirationDate := CurrentExpirationDate;
                        MinExpirationLot := LotNo;
                    end;
                end;
            end;

            if MinExpirationLot <> '' then
                LotsByExpiration.Add(MinExpirationLot);
        end;

        foreach LotNo in AvailableLotKeys do begin
            AvailableQtyByLot.Get(LotNo, AvailableLotQty);
            if AvailableLotsDetail = '' then
                AvailableLotsDetail := StrSubstNo('%1=%2', LotNo, Format(AvailableLotQty))
            else
                AvailableLotsDetail += ', ' + StrSubstNo('%1=%2', LotNo, Format(AvailableLotQty));
        end;

        PITSSubLine.Reset();
        PITSSubLine.SetRange("No.", PITSLine."No.");
        PITSSubLine.SetRange("Line No.", PITSLine."Line No.");
        PITSSubLine.SetRange("Item No.", PITSLine."Item No.");

        if PITSLine."No. Remision" <> '' then begin
            PITSSubLine.SetRange("No. Remision", PITSLine."No. Remision");
            if PITSSubLine.FindSet(false, false) then
                SelectedSubLineRemision := PITSLine."No. Remision"
            else
                PITSSubLine.SetRange("No. Remision");
        end;

        if SelectedSubLineRemision = '' then begin
            if not PITSSubLine.FindLast() then begin
                FailReason := StrSubstNo(lText004, PITSLine."No.", Format(PITSLine."Line No."), PITSLine."Item No.");
                exit(false);
            end;
            SelectedSubLineRemision := PITSSubLine."No. Remision";
            PITSSubLine.SetRange("No. Remision", SelectedSubLineRemision);
            if not PITSSubLine.FindSet(false, false) then begin
                FailReason := StrSubstNo(lText004, PITSLine."No.", Format(PITSLine."Line No."), PITSLine."Item No.");
                exit(false);
            end;
        end;

        repeat
            if RemainingMissingBase <= QtyTolerance then
                break;

            LotNo := PITSSubLine.Lote;
            if LotNo = '' then begin
                FailReason := StrSubstNo(lText005, PITSLine."No.", Format(PITSLine."Line No."), PITSLine."Item No.");
                exit(false);
            end;

            SubLineBase := PITSSubLine.Quantity * QtyPerUom;
            PostedLotBase := GetPostedQtyBaseForLineLot(WRNumber, TR, PITSLine."Line No.", LotNo);
            RemainingLotBase := SubLineBase - PostedLotBase;
            if RemainingLotBase > QtyTolerance then begin
                AvailableLotQty := 0;
                if AvailableQtyByLot.ContainsKey(LotNo) then
                    AvailableQtyByLot.Get(LotNo, AvailableLotQty);

                if AllocatedQtyByLot.ContainsKey(LotNo) then begin
                    AllocatedQtyByLot.Get(LotNo, FreeLotQty);
                    AvailableLotQty -= FreeLotQty;
                end;

                if AvailableLotQty < 0 then
                    AvailableLotQty := 0;

                UseBase := RemainingLotBase;
                if UseBase > AvailableLotQty then
                    UseBase := AvailableLotQty;
                if UseBase > RemainingMissingBase then
                    UseBase := RemainingMissingBase;

                if UseBase > QtyTolerance then begin
                    UseQtyUom := UseBase / QtyPerUom;
                    if UseQtyUom > QtyTolerance then begin
                        ExpirationDate := PITSSubLine."Expiration Date";
                        if ExpirationDate = 0D then begin
                            ItemLedgerEntry.Reset();
                            ItemLedgerEntry.SetRange("Item No.", PITSLine."Item No.");
                            ItemLedgerEntry.SetRange("Lot No.", LotNo);
                            ItemLedgerEntry.SetFilter("Expiration Date", '<>%1', 0D);
                            if ItemLedgerEntry.FindFirst() then
                                ExpirationDate := ItemLedgerEntry."Expiration Date";
                        end;

                        if ItemTrackingCode."Use Expiration Dates" and (ExpirationDate = 0D) then begin
                            FailReason := StrSubstNo(lText006, LotNo);
                            exit(false);
                        end;

                        ItemJnlLine.Init();
                        ItemJnlLine."Journal Template Name" := 'TRANSFERIN';
                        ItemJnlLine."Journal Batch Name" := 'CD2SUC';
                        ItemJnlLine."Line No." := NextLineNo;
                        ItemJnlLine.Validate("Posting Date", Today);
                        ItemJnlLine.Validate("Entry Type", ItemJnlLine."Entry Type"::Transfer);
                        ItemJnlLine.Validate("Document No.", WRNumber);
                        ItemJnlLine.Validate("Item No.", PITSLine."Item No.");
                        if PITSLine."Unit of Measure" <> '' then
                            ItemJnlLine.Validate("Unit of Measure Code", PITSLine."Unit of Measure");
                        ItemJnlLine.Validate("Location Code", 'CD');
                        ItemJnlLine.Validate("New Location Code", PITSLine."Transfer-to Code");
                        ItemJnlLine.Validate(Quantity, UseQtyUom);
                        ItemJnlLine."External Document No." := DTE;
                        ItemJnlLine."Order No." := TR;
                        ItemJnlLine.Validate("Order Line No.", PITSLine."Line No.");
                        ItemJnlLine."Lot No." := LotNo;
                        ItemJnlLine."Expiration Date" := ExpirationDate;
                        ItemJnlLine.Insert(true);
                        if not EnsureTrackingSpecForItemJnlLine(ItemJnlLine, LotNo, ItemJnlLine."Expiration Date", FailReason) then
                            exit(false);

                        if AllocatedQtyByLot.ContainsKey(LotNo) then begin
                            AllocatedQtyByLot.Get(LotNo, FreeLotQty);
                            AllocatedQtyByLot.Set(LotNo, FreeLotQty + UseBase);
                        end else
                            AllocatedQtyByLot.Add(LotNo, UseBase);

                        NextLineNo += 10000;
                        RemainingMissingBase -= UseBase;
                    end;
                end;
            end;
        until PITSSubLine.Next() = 0;

        if RemainingMissingBase > QtyTolerance then begin
            foreach LotNo in LotsByExpiration do begin
                if RemainingMissingBase <= QtyTolerance then
                    break;

                AvailableQtyByLot.Get(LotNo, AvailableLotQty);
                FreeLotQty := AvailableLotQty;
                if AllocatedQtyByLot.ContainsKey(LotNo) then begin
                    AllocatedQtyByLot.Get(LotNo, UseBase);
                    FreeLotQty -= UseBase;
                end;

                if FreeLotQty > QtyTolerance then begin
                    UseBase := FreeLotQty;
                    if UseBase > RemainingMissingBase then
                        UseBase := RemainingMissingBase;

                    if UseBase > QtyTolerance then begin
                        ExpirationDate := 0D;
                        ItemLedgerEntry.Reset();
                        ItemLedgerEntry.SetRange("Item No.", PITSLine."Item No.");
                        ItemLedgerEntry.SetRange("Lot No.", LotNo);
                        ItemLedgerEntry.SetFilter("Expiration Date", '<>%1', 0D);
                        if ItemLedgerEntry.FindFirst() then
                            ExpirationDate := ItemLedgerEntry."Expiration Date";

                        if ItemTrackingCode."Use Expiration Dates" and (ExpirationDate = 0D) then begin
                            FailReason := StrSubstNo(lText006, LotNo);
                            exit(false);
                        end;

                        UseQtyUom := UseBase / QtyPerUom;

                        ItemJnlLine.Init();
                        ItemJnlLine."Journal Template Name" := 'TRANSFERIN';
                        ItemJnlLine."Journal Batch Name" := 'CD2SUC';
                        ItemJnlLine."Line No." := NextLineNo;
                        ItemJnlLine.Validate("Posting Date", Today);
                        ItemJnlLine.Validate("Entry Type", ItemJnlLine."Entry Type"::Transfer);
                        ItemJnlLine.Validate("Document No.", WRNumber);
                        ItemJnlLine.Validate("Item No.", PITSLine."Item No.");
                        if PITSLine."Unit of Measure" <> '' then
                            ItemJnlLine.Validate("Unit of Measure Code", PITSLine."Unit of Measure");
                        ItemJnlLine.Validate("Location Code", 'CD');
                        ItemJnlLine.Validate("New Location Code", PITSLine."Transfer-to Code");
                        ItemJnlLine.Validate(Quantity, UseQtyUom);
                        ItemJnlLine."External Document No." := DTE;
                        ItemJnlLine."Order No." := TR;
                        ItemJnlLine.Validate("Order Line No.", PITSLine."Line No.");
                        ItemJnlLine."Lot No." := LotNo;
                        ItemJnlLine."Expiration Date" := ExpirationDate;
                        ItemJnlLine.Insert(true);
                        if not EnsureTrackingSpecForItemJnlLine(ItemJnlLine, LotNo, ItemJnlLine."Expiration Date", FailReason) then
                            exit(false);

                        if AllocatedQtyByLot.ContainsKey(LotNo) then begin
                            AllocatedQtyByLot.Get(LotNo, FreeLotQty);
                            AllocatedQtyByLot.Set(LotNo, FreeLotQty + UseBase);
                        end else
                            AllocatedQtyByLot.Add(LotNo, UseBase);

                        NextLineNo += 10000;
                        RemainingMissingBase -= UseBase;
                    end;
                end;
            end;
        end;

        if RemainingMissingBase > QtyTolerance then begin
            FinalLotsDetail := '';
            foreach LotNo in AvailableLotKeys do begin
                AvailableQtyByLot.Get(LotNo, AvailableLotQty);
                if AllocatedQtyByLot.ContainsKey(LotNo) then begin
                    AllocatedQtyByLot.Get(LotNo, FreeLotQty);
                    AvailableLotQty -= FreeLotQty;
                end;

                if FinalLotsDetail = '' then
                    FinalLotsDetail := StrSubstNo('%1=%2', LotNo, Format(AvailableLotQty))
                else
                    FinalLotsDetail += ', ' + StrSubstNo('%1=%2', LotNo, Format(AvailableLotQty));
            end;

            FailReason := StrSubstNo(
                lText007,
                PITSLine."No.",
                Format(PITSLine."Line No."),
                PITSLine."Item No.",
                Format(RemainingMissingBase),
                Format(TotalAvailableQty),
                AvailableLotsDetail,
                FinalLotsDetail);
            exit(false);
        end;

        exit(true);
    end;

    local procedure MarkPITSLinesAsRegistrado(WRNumber: Code[20]; var ErrorText: Text): Boolean
    var
        PITSLine: Record PITS_WMScd2suc;
    begin
        ErrorText := '';
        PITSLine.Reset();
        PITSLine.SetRange("FSN Warehouse Receipt No.", WRNumber);
        PITSLine.SetFilter("Qty. to Ship", '>0');
        if PITSLine.FindSet(false, false) then begin
            repeat
                if PITSLine."FSN TransferHistorico" <> PITSLine."FSN TransferHistorico"::Registrado then begin
                    PITSLine."FSN TransferHistorico" := PITSLine."FSN TransferHistorico"::Registrado;
                    PITSLine.Modify(false);
                    COMMIT;
                end;
            until PITSLine.Next() = 0;
        end;
        exit(true);
    end;

    local procedure GetQtyPerUOM(ItemNo: Code[20]; UomCode: Code[10]): Decimal
    var
        ItemUoM: Record "Item Unit of Measure";
    begin
        if (UomCode <> '') and ItemUoM.Get(ItemNo, UomCode) then
            exit(ItemUoM."Qty. per Unit of Measure");
        exit(1);
    end;

    local procedure GetPostedQtyBaseForLine(WRNumber: Code[20]; TR: Code[30]; LineNo: Integer): Decimal
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
    begin
        ItemLedgerEntry.Reset();
        ItemLedgerEntry.SetRange("Document No.", WRNumber);
        ItemLedgerEntry.SetRange("Order No.", TR);
        ItemLedgerEntry.SetRange("Order Line No.", LineNo);
        ItemLedgerEntry.SetRange("Entry Type", ItemLedgerEntry."Entry Type"::Transfer);
        ItemLedgerEntry.SetRange(Positive, true);
        ItemLedgerEntry.SetFilter("Location Code", '<>%1', 'CD');
        ItemLedgerEntry.CalcSums(Quantity);
        exit(ItemLedgerEntry.Quantity);
    end;

    local procedure GetPostedQtyBaseForLineLot(WRNumber: Code[20]; TR: Code[30]; LineNo: Integer; LotNo: Code[50]): Decimal
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
    begin
        ItemLedgerEntry.Reset();
        ItemLedgerEntry.SetRange("Document No.", WRNumber);
        ItemLedgerEntry.SetRange("Order No.", TR);
        ItemLedgerEntry.SetRange("Order Line No.", LineNo);
        ItemLedgerEntry.SetRange("Entry Type", ItemLedgerEntry."Entry Type"::Transfer);
        ItemLedgerEntry.SetRange(Positive, true);
        ItemLedgerEntry.SetRange("Lot No.", LotNo);
        ItemLedgerEntry.SetFilter("Location Code", '<>%1', 'CD');
        ItemLedgerEntry.CalcSums(Quantity);
        exit(ItemLedgerEntry.Quantity);
    end;

    local procedure CreateTrackingJournalLinesFromSubLines(PITSLine: Record PITS_WMScd2suc; WRNumber: Code[20]; DTE: Code[35]; TR: Code[30]; var NextLineNo: Integer; var FailReason: Text): Boolean
    var
        PITSSubLine: Record "PITS Sub Line";
        ItemJnlLine: Record "Item Journal Line";
        ItemTrackingCode: Record "Item Tracking Code";
        ItemLedgerEntry: Record "Item Ledger Entry";
        Item: Record Item;
        LotNo: Code[50];
        LotKey: Code[50];
        ExpirationDate: Date;
        SavedExpirationDate: Date;
        AvailableLotQty: Decimal;
        RequiredLotQty: Decimal;
        UsedLotQty: Decimal;
        FreeLotQty: Decimal;
        TakeQty: Decimal;
        TotalSubLineQty: Decimal;
        QtyDiff: Decimal;
        ShortfallQty: Decimal;
        ImbalanceDetail: Text;
        InsertedLineCount: Integer;
        SelectedSubLineRemision: Code[35];
        RequestedQtyByLot: Dictionary of [Code[50], Decimal];
        RequestedLotKeys: List of [Code[50]];
        AvailableQtyByLot: Dictionary of [Code[50], Decimal];
        OldestLotKeys: List of [Code[50]];
        LotKeysByLowStock: List of [Code[50]];
        ProcessedLot: Dictionary of [Code[50], Boolean];
        MinLotKey: Code[50];
        MinAvailableQty: Decimal;
        HasMinLot: Boolean;
        LotScanNo: Integer;
        EffectiveQtyByLot: Dictionary of [Code[50], Decimal];
        EffectiveLotKeys: List of [Code[50]];
        LotExpirationByLot: Dictionary of [Code[50], Date];
        AvailableLotsDetail: Text;
        TotalAvailableQty: Decimal;
        TraceText: Text;
        TraceLineCount: Integer;
        lText001: Label 'No se encontró el artículo %1.';
        lText002: Label 'El artículo %1 tiene Item Tracking Code vacío.';
        lText003: Label 'No se encontró el Item Tracking Code %1 para el artículo %2.';
        lText004: Label 'No hay lotes en PITS Sub Line para TR %1, Line No. %2, Item %3.';
        lText005: Label 'Lote vacío en PITS Sub Line para TR %1, Line No. %2, Item %3.';
        lText006: Label 'Cantidad de lote inválida (%1) en PITS Sub Line para lote %2.';
        lText007: Label 'No tiene fecha de vencimiento válida para lote %1 (PITS Sub Line o Item Ledger Entry).';
        lText008: Label 'Falta inventario por lotes para auto-cuadre del item %1 en CD. Faltante=%2.';
        lText009: Label 'Suma de lotes inválida para TR %1, Line No. %2, Item %3. Suma lotes=%4 debe ser igual a Qty. to Ship=%5.';
        lText010: Label 'Lote descuadrado %1. Requerido=%2, Disponible=%3.';
        lText011: Label 'No hay inventario disponible en CD para item %1 (Remaining Quantity <> 0).';
        lText012: Label 'Auto-cuadre incompleto para item %1. Disponible total=%2. Requerido total=%3. Faltante=%4. Lotes=%5. Detalle=%6';
        lText013: Label 'No se generaron líneas efectivas para TR %1, Line No. %2, Item %3.';
    begin
        FailReason := '';
        ImbalanceDetail := '';
        InsertedLineCount := 0;
        TraceText := '';
        TraceLineCount := 0;

        AppendTrace(TraceText, TraceLineCount, StrSubstNo('Inicio TR=%1, Line=%2, Item=%3', PITSLine."No.", Format(PITSLine."Line No."), PITSLine."Item No."));

        if not Item.Get(PITSLine."Item No.") then begin
            FailReason := CopyStr(TraceText + '\' + StrSubstNo(lText001, PITSLine."Item No."), 1, MaxStrLen(FailReason));
            exit(false);
        end;
        AppendTrace(TraceText, TraceLineCount, StrSubstNo('Item encontrado %1', PITSLine."Item No."));

        if Item."Item Tracking Code" = '' then begin
            FailReason := CopyStr(TraceText + '\' + StrSubstNo(lText002, PITSLine."Item No."), 1, MaxStrLen(FailReason));
            exit(false);
        end;
        AppendTrace(TraceText, TraceLineCount, StrSubstNo('Item Tracking Code validado %1', Item."Item Tracking Code"));

        if not ItemTrackingCode.Get(Item."Item Tracking Code") then begin
            FailReason := CopyStr(TraceText + '\' + StrSubstNo(lText003, Item."Item Tracking Code", PITSLine."Item No."), 1, MaxStrLen(FailReason));
            exit(false);
        end;
        AppendTrace(TraceText, TraceLineCount, StrSubstNo('Item Tracking Code encontrado %1', Item."Item Tracking Code"));

        PITSSubLine.Reset();
        PITSSubLine.SetRange("No.", PITSLine."No.");
        PITSSubLine.SetRange("Line No.", PITSLine."Line No.");
        PITSSubLine.SetRange("Item No.", PITSLine."Item No.");

        // Primero intentar por la remision de la linea WR. Si no existe,
        // usar la remision mas reciente de sublineas para evitar arrastre de lotes antiguos incorrectos.
        if PITSLine."No. Remision" <> '' then begin
            PITSSubLine.SetRange("No. Remision", PITSLine."No. Remision");
            if PITSSubLine.FindSet(false, false) then
                SelectedSubLineRemision := PITSLine."No. Remision"
            else
                PITSSubLine.SetRange("No. Remision");
        end;

        if SelectedSubLineRemision = '' then begin
            if not PITSSubLine.FindLast() then begin
                FailReason := CopyStr(TraceText + '\' + StrSubstNo(lText004, PITSLine."No.", Format(PITSLine."Line No."), PITSLine."Item No."), 1, MaxStrLen(FailReason));
                exit(false);
            end;
            SelectedSubLineRemision := PITSSubLine."No. Remision";
            AppendTrace(TraceText, TraceLineCount, StrSubstNo('No. Remision tomado desde la ultima sublinea: %1', SelectedSubLineRemision));
            PITSSubLine.SetRange("No. Remision", SelectedSubLineRemision);
            if not PITSSubLine.FindSet(false, false) then begin
                FailReason := CopyStr(TraceText + '\' + StrSubstNo(lText004, PITSLine."No.", Format(PITSLine."Line No."), PITSLine."Item No."), 1, MaxStrLen(FailReason));
                exit(false);
            end;
        end;

        AppendTrace(TraceText, TraceLineCount, StrSubstNo('Leyendo sublineas con remision %1', SelectedSubLineRemision));
        TotalSubLineQty := 0;
        repeat
            LotNo := PITSSubLine.Lote;
            if LotNo = '' then begin
                FailReason := CopyStr(TraceText + '\' + StrSubstNo(lText005, PITSLine."No.", Format(PITSLine."Line No."), PITSLine."Item No."), 1, MaxStrLen(FailReason));
                exit(false);
            end;
            AppendTrace(TraceText, TraceLineCount, StrSubstNo('Sublinea lote=%1 qty=%2', LotNo, Format(PITSSubLine.Quantity)));

            if PITSSubLine.Quantity <= 0 then begin
                FailReason := CopyStr(TraceText + '\' + StrSubstNo(lText006, Format(PITSSubLine.Quantity), LotNo), 1, MaxStrLen(FailReason));
                exit(false);
            end;

            ExpirationDate := PITSSubLine."Expiration Date";
            if ExpirationDate = 0D then begin
                ItemLedgerEntry.Reset();
                ItemLedgerEntry.SetRange("Item No.", PITSLine."Item No.");
                ItemLedgerEntry.SetRange("Lot No.", LotNo);
                ItemLedgerEntry.SetFilter("Expiration Date", '<>%1', 0D);
                if ItemLedgerEntry.FindFirst() then
                    ExpirationDate := ItemLedgerEntry."Expiration Date";
            end;

            // No fallar aquí si el lote original no existe o no tiene inventario.
            // La validación estricta de vencimiento se ejecuta sobre los lotes efectivos
            // que sí quedarán en el diario después del auto-cuadre.

            if RequestedQtyByLot.ContainsKey(LotNo) then begin
                RequestedQtyByLot.Get(LotNo, RequiredLotQty);
                RequiredLotQty += PITSSubLine.Quantity;
                RequestedQtyByLot.Set(LotNo, RequiredLotQty);
            end else begin
                RequestedQtyByLot.Add(LotNo, PITSSubLine.Quantity);
                RequestedLotKeys.Add(LotNo);
            end;

            if (ExpirationDate <> 0D) and (not LotExpirationByLot.ContainsKey(LotNo)) then
                LotExpirationByLot.Add(LotNo, ExpirationDate)
            else
                if (ExpirationDate <> 0D) and LotExpirationByLot.ContainsKey(LotNo) then begin
                    LotExpirationByLot.Get(LotNo, SavedExpirationDate);
                    if SavedExpirationDate = 0D then
                        LotExpirationByLot.Set(LotNo, ExpirationDate);
                end;

            if not LotExpirationByLot.ContainsKey(LotNo) then
                LotExpirationByLot.Add(LotNo, 0D);

            if not EffectiveQtyByLot.ContainsKey(LotNo) then begin
                EffectiveQtyByLot.Add(LotNo, 0);
                EffectiveLotKeys.Add(LotNo);
            end;

            TotalSubLineQty += PITSSubLine.Quantity;
        until PITSSubLine.Next() = 0;

        AppendTrace(TraceText, TraceLineCount, StrSubstNo('Suma total sublineas=%1 vs Qty. to Ship=%2', Format(TotalSubLineQty), Format(PITSLine."Qty. to Ship")));

        QtyDiff := Abs(TotalSubLineQty - PITSLine."Qty. to Ship");
        if QtyDiff > 0.00001 then begin
            FailReason := CopyStr(TraceText + '\' + StrSubstNo(
                lText009,
                PITSLine."No.",
                Format(PITSLine."Line No."),
                PITSLine."Item No.",
                Format(TotalSubLineQty),
                Format(PITSLine."Qty. to Ship")), 1, MaxStrLen(FailReason));
            exit(false);
        end;

        AppendTrace(TraceText, TraceLineCount, 'Validacion de inventario en CD por lote');
        // Cargar disponibilidad por lote en CD (SUM(Remaining Quantity) por lote).
        ItemLedgerEntry.Reset();
        ItemLedgerEntry.SetRange("Item No.", PITSLine."Item No.");
        ItemLedgerEntry.SetRange("Location Code", 'CD');
        ItemLedgerEntry.SetRange(Open, true);
        ItemLedgerEntry.SetRange(Positive, true);
        ItemLedgerEntry.SetFilter("Remaining Quantity", '<>%1', 0);
        if ItemLedgerEntry.FindSet(false, false) then
            repeat
                LotNo := ItemLedgerEntry."Lot No.";
                if (LotNo <> '') and (ItemLedgerEntry."Remaining Quantity" > 0) then begin
                    if AvailableQtyByLot.ContainsKey(LotNo) then begin
                        AvailableQtyByLot.Get(LotNo, AvailableLotQty);
                        AvailableLotQty += ItemLedgerEntry."Remaining Quantity";
                        AvailableQtyByLot.Set(LotNo, AvailableLotQty);
                    end else begin
                        AvailableQtyByLot.Add(LotNo, ItemLedgerEntry."Remaining Quantity");
                        OldestLotKeys.Add(LotNo);
                    end;

                    if (not LotExpirationByLot.ContainsKey(LotNo)) and (ItemLedgerEntry."Expiration Date" <> 0D) then
                        LotExpirationByLot.Add(LotNo, ItemLedgerEntry."Expiration Date")
                    else
                        if LotExpirationByLot.ContainsKey(LotNo) then begin
                            LotExpirationByLot.Get(LotNo, SavedExpirationDate);
                            if (SavedExpirationDate = 0D) and (ItemLedgerEntry."Expiration Date" <> 0D) then
                                LotExpirationByLot.Set(LotNo, ItemLedgerEntry."Expiration Date");
                        end;
                end;
            until ItemLedgerEntry.Next() = 0
        else begin
            FailReason := CopyStr(TraceText + '\' + StrSubstNo(lText011, PITSLine."Item No."), 1, MaxStrLen(FailReason));
            exit(false);
        end;

        AppendTrace(TraceText, TraceLineCount, StrSubstNo('Lotes disponibles detectados=%1', Format(OldestLotKeys.Count)));

        // Ordenar lotes por menor cantidad disponible (ascendente) para el auto-cuadre.
        for LotScanNo := 1 to OldestLotKeys.Count do begin
            HasMinLot := false;
            MinLotKey := '';
            MinAvailableQty := 0;

            foreach LotKey in OldestLotKeys do begin
                if not ProcessedLot.ContainsKey(LotKey) then begin
                    AvailableQtyByLot.Get(LotKey, AvailableLotQty);

                    if (not HasMinLot) or (AvailableLotQty < MinAvailableQty) then begin
                        HasMinLot := true;
                        MinLotKey := LotKey;
                        MinAvailableQty := AvailableLotQty;
                    end;
                end;
            end;

            if HasMinLot then begin
                LotKeysByLowStock.Add(MinLotKey);
                ProcessedLot.Add(MinLotKey, true);
            end;
        end;

        // Separar lotes cuadrados y descuadrados; los descuadrados aportan al faltante a re-cuadrar.
        ShortfallQty := 0;
        foreach LotKey in RequestedLotKeys do begin
            RequestedQtyByLot.Get(LotKey, RequiredLotQty);

            AvailableLotQty := 0;
            if AvailableQtyByLot.ContainsKey(LotKey) then
                AvailableQtyByLot.Get(LotKey, AvailableLotQty);

            if AvailableLotQty >= RequiredLotQty then
                EffectiveQtyByLot.Set(LotKey, RequiredLotQty)
            else begin
                EffectiveQtyByLot.Set(LotKey, 0);
                ShortfallQty += RequiredLotQty;
                AppendTrace(TraceText, TraceLineCount, StrSubstNo('Lote descuadrado %1 requerido=%2 disponible=%3', LotKey, Format(RequiredLotQty), Format(AvailableLotQty)));

                if ImbalanceDetail = '' then
                    ImbalanceDetail := StrSubstNo(lText010, LotKey, Format(RequiredLotQty), Format(AvailableLotQty))
                else
                    ImbalanceDetail += '\' + StrSubstNo(lText010, LotKey, Format(RequiredLotQty), Format(AvailableLotQty));
            end;
        end;

        AppendTrace(TraceText, TraceLineCount, StrSubstNo('Faltante total para auto-cuadre=%1', Format(ShortfallQty)));

        // Auto-cuadre: completar faltante usando lotes con menor inventario disponible primero.
        if ShortfallQty > 0.00001 then begin
            TotalAvailableQty := 0;
            AvailableLotsDetail := '';
            foreach LotKey in LotKeysByLowStock do begin
                AvailableQtyByLot.Get(LotKey, AvailableLotQty);
                TotalAvailableQty += AvailableLotQty;

                if AvailableLotsDetail = '' then
                    AvailableLotsDetail := StrSubstNo('%1=%2', LotKey, Format(AvailableLotQty))
                else
                    AvailableLotsDetail += ', ' + StrSubstNo('%1=%2', LotKey, Format(AvailableLotQty));
            end;

            foreach LotKey in LotKeysByLowStock do begin
                if ShortfallQty <= 0.00001 then
                    break;

                AvailableQtyByLot.Get(LotKey, AvailableLotQty);
                UsedLotQty := 0;
                if EffectiveQtyByLot.ContainsKey(LotKey) then
                    EffectiveQtyByLot.Get(LotKey, UsedLotQty);

                FreeLotQty := AvailableLotQty - UsedLotQty;
                if FreeLotQty > 0.00001 then begin
                    AppendTrace(TraceText, TraceLineCount, StrSubstNo('Auto-cuadre lote candidato %1 disponible=%2 libre=%3 faltante=%4', LotKey, Format(AvailableLotQty), Format(FreeLotQty), Format(ShortfallQty)));
                    if FreeLotQty >= ShortfallQty then
                        TakeQty := ShortfallQty
                    else
                        TakeQty := FreeLotQty;

                    if not EffectiveQtyByLot.ContainsKey(LotKey) then begin
                        EffectiveQtyByLot.Add(LotKey, 0);
                        EffectiveLotKeys.Add(LotKey);
                    end;

                    EffectiveQtyByLot.Get(LotKey, UsedLotQty);
                    EffectiveQtyByLot.Set(LotKey, UsedLotQty + TakeQty);
                    ShortfallQty -= TakeQty;
                    AppendTrace(TraceText, TraceLineCount, StrSubstNo('Auto-cuadre aplicado lote %1 toma=%2 faltante_restante=%3', LotKey, Format(TakeQty), Format(ShortfallQty)));
                end;
            end;

            if ShortfallQty > 0.00001 then begin
                if ImbalanceDetail = '' then
                    FailReason := CopyStr(TraceText + '\' + StrSubstNo(lText012, PITSLine."Item No.", Format(TotalAvailableQty), Format(PITSLine."Qty. to Ship"), Format(ShortfallQty), AvailableLotsDetail, StrSubstNo(lText008, PITSLine."Item No.", Format(ShortfallQty))), 1, MaxStrLen(FailReason))
                else
                    FailReason := CopyStr(TraceText + '\' + StrSubstNo(lText012, PITSLine."Item No.", Format(TotalAvailableQty), Format(PITSLine."Qty. to Ship"), Format(ShortfallQty), AvailableLotsDetail, ImbalanceDetail), 1, MaxStrLen(FailReason));
                exit(false);
            end;
        end;

        AppendTrace(TraceText, TraceLineCount, 'Inicio insercion de lineas efectivas en diario');

        // Insertar líneas del diario usando lotes efectivos (lotes originales cuadrados + lotes agregados por auto-cuadre).
        foreach LotKey in EffectiveLotKeys do begin
            EffectiveQtyByLot.Get(LotKey, RequiredLotQty);
            if RequiredLotQty <= 0.00001 then
                RequiredLotQty := 0
            else begin
                AppendTrace(TraceText, TraceLineCount, StrSubstNo('Insertando lote efectivo %1 qty=%2', LotKey, Format(RequiredLotQty)));

                ExpirationDate := 0D;
                if LotExpirationByLot.ContainsKey(LotKey) then
                    LotExpirationByLot.Get(LotKey, ExpirationDate);

                if ExpirationDate = 0D then begin
                    ItemLedgerEntry.Reset();
                    ItemLedgerEntry.SetRange("Item No.", PITSLine."Item No.");
                    ItemLedgerEntry.SetRange("Lot No.", LotKey);
                    ItemLedgerEntry.SetFilter("Expiration Date", '<>%1', 0D);
                    if ItemLedgerEntry.FindFirst() then
                        ExpirationDate := ItemLedgerEntry."Expiration Date";
                end;

                if ItemTrackingCode."Use Expiration Dates" and (ExpirationDate = 0D) then begin
                    FailReason := CopyStr(TraceText + '\' + StrSubstNo(lText007, LotKey), 1, MaxStrLen(FailReason));
                    exit(false);
                end;

                ItemJnlLine.Init();
                ItemJnlLine."Journal Template Name" := 'TRANSFERIN';
                ItemJnlLine."Journal Batch Name" := 'CD2SUC';
                ItemJnlLine."Line No." := NextLineNo;
                ItemJnlLine.Validate("Posting Date", Today);
                ItemJnlLine.Validate("Entry Type", ItemJnlLine."Entry Type"::Transfer);
                ItemJnlLine.Validate("Document No.", WRNumber);
                ItemJnlLine.Validate("Item No.", PITSLine."Item No.");
                if PITSLine."Unit of Measure" <> '' then
                    ItemJnlLine.Validate("Unit of Measure Code", PITSLine."Unit of Measure");
                ItemJnlLine.Validate("Location Code", 'CD');
                ItemJnlLine.Validate("New Location Code", PITSLine."Transfer-to Code");
                ItemJnlLine.Validate(Quantity, RequiredLotQty);
                ItemJnlLine."External Document No." := DTE;
                ItemJnlLine."Order No." := TR;
                ItemJnlLine.Validate("Order Line No.", PITSLine."Line No.");

                ItemJnlLine."Lot No." := LotKey;
                ItemJnlLine."Expiration Date" := ExpirationDate;

                ItemJnlLine.Insert(true);
                if not EnsureTrackingSpecForItemJnlLine(ItemJnlLine, LotKey, ItemJnlLine."Expiration Date", FailReason) then
                    exit(false);

                NextLineNo += 10000;
                InsertedLineCount += 1;
                AppendTrace(TraceText, TraceLineCount, StrSubstNo('Linea insertada correctamente lote %1', LotKey));
            end;
        end;

        if InsertedLineCount = 0 then begin
            FailReason := CopyStr(TraceText + '\' + StrSubstNo(lText013, PITSLine."No.", Format(PITSLine."Line No."), PITSLine."Item No."), 1, MaxStrLen(FailReason));
            exit(false);
        end;

        exit(true);
    end;

    local procedure EnsureTrackingSpecForItemJnlLine(ItemJnlLine: Record "Item Journal Line"; LotNo: Code[50]; ExpirationDate: Date; var FailReason: Text): Boolean
    var
        ReservationEntry: Record "Reservation Entry";
        ItemLedgerEntry: Record "Item Ledger Entry";
        Item: Record Item;
        NextEntryNo: Integer;
        ExistingExpirationDate: Date;
        SignFactor: Integer;
    begin
        FailReason := '';

        if (LotNo = '') then begin
            FailReason := 'No se pudo crear tracking specification: lote vacío.';
            exit(false);
        end;

        if ItemJnlLine."Quantity (Base)" = 0 then begin
            FailReason := 'No se pudo crear tracking specification: Quantity (Base)=0.';
            exit(false);
        end;

        // Determinar SignFactor igual que Item Jnl.-Post Line codeunit 22, líneas 3904-3907
        // Para Transfer: SignFactor = -1 cuando no es PostponeReservationHandling
        if ItemJnlLine."Entry Type" = ItemJnlLine."Entry Type"::Transfer then
            SignFactor := -1
        else
            SignFactor := 1;

        // Buscar fecha de caducidad existente PRIMERO
        ExistingExpirationDate := 0D;
        ItemLedgerEntry.Reset();
        ItemLedgerEntry.SetRange("Item No.", ItemJnlLine."Item No.");
        ItemLedgerEntry.SetRange("Variant Code", ItemJnlLine."Variant Code");
        ItemLedgerEntry.SetRange("Lot No.", LotNo);
        ItemLedgerEntry.SetFilter("Expiration Date", '<>%1', 0D);
        if ItemLedgerEntry.FindFirst() then
            ExistingExpirationDate := ItemLedgerEntry."Expiration Date";

        // Usar fecha existente si hay una registrada, sino usar la del parámetro
        if ExistingExpirationDate = 0D then
            ExistingExpirationDate := ExpirationDate;

        // Evitar duplicados: DELETE primero todos los Reservation Entries que coincidan
        ReservationEntry.Reset();
        ReservationEntry.SetRange("Source Type", DATABASE::"Item Journal Line");
        ReservationEntry.SetRange("Source Subtype", ItemJnlLine."Entry Type".AsInteger());
        ReservationEntry.SetRange("Source ID", ItemJnlLine."Journal Template Name");
        ReservationEntry.SetRange("Source Batch Name", ItemJnlLine."Journal Batch Name");
        ReservationEntry.SetRange("Source Ref. No.", ItemJnlLine."Line No.");
        ReservationEntry.SetRange("Item No.", ItemJnlLine."Item No.");
        ReservationEntry.SetRange("Lot No.", LotNo);
        if ReservationEntry.FindSet() then
            ReservationEntry.DeleteAll();

        // Obtener el siguiente Entry No.
        ReservationEntry.Reset();
        NextEntryNo := ReservationEntry.GetLastEntryNo() + 1;

        // Obtener descripción del item
        if Item.Get(ItemJnlLine."Item No.") then;

        // Crear Reservation Entry con estado Surplus
        // CRÍTICO: Aplicar SignFactor como lo hace Item Jnl.-Post Line (línea 4024)
        ReservationEntry.Init();
        ReservationEntry."Entry No." := NextEntryNo;
        ReservationEntry.Positive := SignFactor > 0;
        ReservationEntry."Item No." := ItemJnlLine."Item No.";
        ReservationEntry."Location Code" := ItemJnlLine."Location Code";
        ReservationEntry."Quantity (Base)" := SignFactor * Abs(ItemJnlLine."Quantity (Base)");
        ReservationEntry."Reservation Status" := ReservationEntry."Reservation Status"::Surplus;
        ReservationEntry."Creation Date" := WorkDate();
        ReservationEntry."Created By" := UserId;
        ReservationEntry."Source Type" := DATABASE::"Item Journal Line";
        ReservationEntry."Source Subtype" := ItemJnlLine."Entry Type".AsInteger();
        ReservationEntry."Source ID" := ItemJnlLine."Journal Template Name";
        ReservationEntry."Source Batch Name" := ItemJnlLine."Journal Batch Name";
        ReservationEntry."Source Prod. Order Line" := 0;
        ReservationEntry."Source Ref. No." := ItemJnlLine."Line No.";
        ReservationEntry.Description := CopyStr(Item.Description, 1, MaxStrLen(ReservationEntry.Description));
        ReservationEntry."Variant Code" := ItemJnlLine."Variant Code";
        ReservationEntry."Serial No." := '';
        ReservationEntry."Lot No." := LotNo;
        ReservationEntry."Package No." := '';
        ReservationEntry."Expiration Date" := ExistingExpirationDate;
        ReservationEntry."Qty. per Unit of Measure" := ItemJnlLine."Qty. per Unit of Measure";
        ReservationEntry.Quantity := SignFactor * Abs(ItemJnlLine.Quantity);
        ReservationEntry."Qty. to Handle (Base)" := SignFactor * Abs(ItemJnlLine."Quantity (Base)");
        ReservationEntry."Qty. to Invoice (Base)" := SignFactor * Abs(ItemJnlLine."Quantity (Base)");
        ReservationEntry."Expected Receipt Date" := ItemJnlLine."Posting Date";
        ReservationEntry."Shipment Date" := ItemJnlLine."Posting Date";
        ReservationEntry."Planning Flexibility" := ReservationEntry."Planning Flexibility"::Unlimited;
        ReservationEntry."New Serial No." := '';
        ReservationEntry."New Lot No." := LotNo;
        ReservationEntry."New Package No." := '';
        ReservationEntry."New Expiration Date" := ExistingExpirationDate;

        if not ReservationEntry.Insert(true) then begin
            FailReason := 'No se pudo insertar Reservation Entry. ' + GetLastErrorText();
            exit(false);
        end;

        exit(true);
    end;

    local procedure ValidateTrackingForPITSLine(PITSLine: Record PITS_WMScd2suc; var LotNo: Code[50]; var ExpirationDate: Date; var FailReason: Text): Boolean
    var
        Item: Record Item;
        ItemTrackingCode: Record "Item Tracking Code";
        ItemLedgerEntry: Record "Item Ledger Entry";
        TotalRemainingQty: Decimal;
        lText001: Label 'No se encontró el artículo %1.';
        lText002: Label 'El artículo %1 tiene Item Tracking Code vacío.';
        lText003: Label 'No se encontró el Item Tracking Code %1 para el artículo %2.';
        lText004: Label 'No tiene lote (No. Pedido) para artículo con seguimiento.';
        lText005: Label 'No tiene fecha de vencimiento válida (Date Updated o Item Ledger Entry) para lote %1.';
        lText006: Label 'Inventario insuficiente para el artículo %1 en CD. Disponible=%2, Requerido=%3.';
    begin
        FailReason := '';
        LotNo := '';
        ExpirationDate := 0D;

        if not Item.Get(PITSLine."Item No.") then begin
            FailReason := StrSubstNo(lText001, PITSLine."Item No.");
            exit(false);
        end;

        if Item."Item Tracking Code" = '' then begin
            FailReason := StrSubstNo(lText002, PITSLine."Item No.");
            exit(false);
        end;

        if not ItemTrackingCode.Get(Item."Item Tracking Code") then begin
            FailReason := StrSubstNo(lText003, Item."Item Tracking Code", PITSLine."Item No.");
            exit(false);
        end;

        LotNo := PITSLine."No. Pedido";
        if LotNo = '' then begin
            FailReason := lText004;
            exit(false);
        end;

        if PITSLine."Date Updated" <> 0DT then
            ExpirationDate := DT2Date(PITSLine."Date Updated");

        if ExpirationDate = 0D then begin
            ItemLedgerEntry.Reset();
            ItemLedgerEntry.SetRange("Item No.", PITSLine."Item No.");
            ItemLedgerEntry.SetRange("Lot No.", LotNo);
            ItemLedgerEntry.SetFilter("Expiration Date", '<>%1', 0D);
            if ItemLedgerEntry.FindFirst() then
                ExpirationDate := ItemLedgerEntry."Expiration Date";
        end;

        if ItemTrackingCode."Use Expiration Dates" and (ExpirationDate = 0D) then begin
            FailReason := StrSubstNo(lText005, LotNo);
            exit(false);
        end;

        TotalRemainingQty := 0;
        ItemLedgerEntry.Reset();
        ItemLedgerEntry.SetRange("Location Code", 'CD');
        ItemLedgerEntry.SetRange("Item No.", PITSLine."Item No.");
        ItemLedgerEntry.SetRange(Open, true);
        ItemLedgerEntry.SetRange(Positive, true);
        ItemLedgerEntry.SetFilter("Remaining Quantity", '<>%1', 0);
        if ItemLedgerEntry.FindSet(false, false) then
            repeat
                TotalRemainingQty += ItemLedgerEntry."Remaining Quantity";
                if (ExpirationDate = 0D) and (ItemLedgerEntry."Expiration Date" <> 0D) then
                    ExpirationDate := ItemLedgerEntry."Expiration Date";
            until ItemLedgerEntry.Next() = 0;

        if TotalRemainingQty < PITSLine."Qty. to Ship" then begin
            FailReason := StrSubstNo(lText006, PITSLine."Item No.", Format(TotalRemainingQty), Format(PITSLine."Qty. to Ship"));
            exit(false);
        end;

        exit(true);
    end;

    local procedure AppendTrace(var TraceText: Text; var TraceLineCount: Integer; StageText: Text)
    var
        TraceEntry: Text;
    begin
        TraceLineCount += 1;
        TraceEntry := StrSubstNo('%1. %2', Format(TraceLineCount), StageText);
        if TraceText = '' then
            TraceText := TraceEntry
        else
            TraceText += '\' + TraceEntry;
    end;


    var
        ErrItemVendorMissing: Label 'El producto %1 no está asociado al proveedor %2 .', Comment = '%1 Item No., %2 Vendor No.';
}

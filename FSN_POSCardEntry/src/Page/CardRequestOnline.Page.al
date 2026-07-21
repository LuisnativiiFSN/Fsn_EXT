page 50066 "FSN Card Request Online"
{
    DeleteAllowed = false;
    InsertAllowed = false;
    ModifyAllowed = true;
    PageType = Card;
    UsageCategory = Administration;
    ApplicationArea = all;
    PromotedActionCategories = 'Process,Check,Report,Vouchers';
    SourceTable = "LSC POS Card Entry";

    layout
    {
        area(content)
        {
            group(Transactor)
            {
                Visible = VisibleTransactorModal;
                field("Receipt No."; "Receipt No.")
                {
                    Editable = false;
                }
                field("Tender Type"; "Tender Type")
                {
                    Caption = 'Tender Type';
                    Editable = false;
                    Visible = false;
                }
                field(NumDecript; NumDecript)
                {
                    Caption = 'Card Number';
                    Editable = EditFields;
                    Visible = VisibleTextBoxPayments;
                    ShowMandatory = VisibleTokenModal;

                    trigger OnValidate()
                    begin
                        if "Authorisation Ok" then
                            exit;
                        OnValidateCardNumber(NumDecript);
                    end;
                }
                field("Nombre Tarjeta"; "FSN Bank Name")
                {
                    Editable = EditFields;
                    Visible = VisibleTextBoxPayments;

                    trigger OnValidate()
                    begin
                        "FSN Bank Name" := UPPERCASE("FSN Bank Name");
                        IF "FSN Bank Name" IN ['WOMPI', 'ECOMMERCE'] then //Word reserve
                            Error(Text023);
                    end;
                }
                field(LastValidDate; LastDate)
                {
                    Caption = 'LastValidDate';
                    Editable = EditFields;
                    Visible = VisibleTextBoxPayments;
                    ShowMandatory = VisibleTokenModal;

                    trigger OnValidate()
                    begin
                        "Expiry Date" := POSCardIntegration.ConvertLastDateToParameter(LastDate);
                    end;
                }
                field("Auth.code"; "Auth.code")
                {
                    Editable = BlockProcess;
                }
                field(tokenWompi; tokenWompi)
                {
                    Caption = 'GUARDAR TARJETA';
                    Editable = true;
                    Visible = tokenWompiVisible;

                    trigger OnValidate()
                    var
                    begin
                        ValInformationCustomerToken();
                    end;
                }
                field(CVV; "FSN CVV")
                {
                    Caption = 'CVV';
                    Editable = EditFields;
                    Visible = false;

                    trigger OnValidate()
                    begin
                        IF STRLEN("EFT POS Terminal No.") > 3 THEN
                            Error(Text014);
                    end;
                }
                field(gDUI; gDUI)
                {
                    Caption = 'DUI';
                    Editable = EditFields;
                    Visible = VisibleTextBoxPayments;

                    trigger OnValidate()
                    begin
                        IF gDUI <> '' THEN
                            FSNUtility.POSNewLineFreeText("Receipt No.", 36, STRSUBSTNO(Text015, gDUI), 2)
                        ELSE
                            FSNUtility.POSNewLineFreeText("Receipt No.", 36, '', 2);
                    end;
                }
                field(Amount; Amount)
                {
                    Editable = false;
                }
                field("EFT Terminal ID"; "EFT Terminal ID")
                {
                    Visible = false;
                }
                field("BIN No."; "FSN BIN No.")
                {
                    Visible = VisibleTextBoxPayments;
                }
                field(PrintAmount; "FSN Print Amount")
                {
                    Visible = VisibleTextBoxPayments;
                }
            }
            group(Wompi)
            {
                Visible = VisibleWompiModal;
                field(NombreTarjetaWP; "FSN Bank Name")
                {
                    Caption = 'Nombre Tarjeta WP';
                    Editable = false;
                }
                field(BIN_NoWP; gBIN)
                {
                    Caption = 'BIN WP';
                    DrillDown = false;
                    Editable = false;
                    Lookup = false;
                    trigger OnValidate()
                    begin
                        IF STRLEN(gBIN) <> 6 THEN
                            ERROR(Text024);

                        "FSN BIN No." := gBIN;
                        "FSN Last Digits" := '0000';
                        "Expiry Date" := '0000';
                    end;
                }
                field(Auth_code_WP; "Auth.code")
                {
                    Caption = 'Auth code WP';
                    Width = 6;

                    trigger OnValidate()
                    begin
                        NumberTransIsFalse("Auth.code");
                    end;
                }
                field("EFT Trans. No."; "EFT Trans. No.")
                {
                    Caption = 'Reference WP';

                    trigger OnValidate()
                    begin
                        NumberTransIsFalse("EFT Trans. No.");
                    end;
                }
                field(AmountW; Amount)
                {
                    Editable = false;
                }
                field(OriginalAmt; "FSN Print Amount")
                {
                    Caption = 'Original Amount';
                }
            }
            group(tokenGroup)
            {
                Visible = VisibleTokenModal;
                Caption = 'Datos para guardar tarjeta';


                field(DocumentType; DocumentType)
                {
                    Caption = 'Tipo Documento :.';
                    ToolTip = 'Tipo Documento DUI,Doc Extrangero';
                    ApplicationArea = All;
                    ShowMandatory = VisibleTokenModal;
                    Editable = true;

                }

                field(DUI; DocumentNo)
                {
                    Caption = 'No Documento :.';
                    ToolTip = 'Numero Documento';
                    ApplicationArea = All;
                    ShowMandatory = VisibleTokenModal;
                    Editable = true;
                    trigger OnValidate()
                    var
                        myInt: Integer;
                        Text015: Label 'Owner Card ::%1';
                        FSNUtility: Codeunit "FSN Utility";
                    begin
                        IF DocumentType = DocumentType::DUI THEN
                            FSNUtility.POSNewLineFreeText("Receipt No.", 36, STRSUBSTNO(Text015, DocumentNo), 2)
                    end;

                }

                field(cellPhoneNumber; cellPhoneNumber)
                {
                    Caption = 'Telefono :.';
                    ApplicationArea = All;
                    ShowMandatory = VisibleTokenModal;
                    Editable = true;

                }
                field(email; email)
                {
                    Caption = 'Email :.';
                    ApplicationArea = All;
                    ShowMandatory = VisibleTokenModal;
                    Editable = true;

                }
            }

            group(separado)
            {
                Visible = VisibleTokenModal;
                Caption = ' ';
                field(separador; '')
                {
                    ApplicationArea = All;
                    Editable = false;
                    Visible = false;

                }
            }

            field(Type; gType)
            {
                Caption = 'Buy Type';
                Editable = EditFields;
                trigger OnValidate()
                var
                    fsnParameterWompi: record "FSN Parameter";
                begin
                    IF "Authorisation Ok" THEN
                        EXIT;

                    IF gType = gType::Wompi THEN begin
                        RetailSetup.GET;
                        IF NOT fsnParameterWompi.GET('KINPOS', 'WOMPI') THEN
                            fsnParameterWompi.INIT;
                        IF NOT CONFIRM(Text022) THEN begin
                            gType := gType::Normal;
                            EXIT;
                        end;

                    end;

                    case gType of
                        gType::Normal:
                            begin
                                if Rec."EFT Device Name" = 'WOMPI' then
                                    ShowModalWompi(false, false);
                                Rec."EFT Device Name" := 'MANCOMPRANOR';
                            end;
                        gType::"A Plazo":
                            BEGIN
                                if Rec."EFT Device Name" = 'WOMPI' then
                                    ShowModalWompi(false, false);
                                Rec."EFT Device Name" := 'MANCOMPRAPLA';
                            END;
                        gType::Puntos:
                            begin
                                if Rec."EFT Device Name" = 'WOMPI' then
                                    ShowModalWompi(false, false);
                                Rec."EFT Device Name" := 'MANCOMPRAMIL';
                            end;
                        gType::Wompi:
                            begin
                                tokenWompi := false;
                                VisibleTokenModal := false;
                                ShowModalWompi(true, false);
                                ClearData;
                                Rec."FSN Bank Name" := 'WOMPI';
                                "EFT Merchant No." := fsnParameterWompi."Value Text 1";
                                "EFT Terminal ID" := fsnParameterWompi."Value Text 2";
                                "FSN BIN No." := '0000';
                                gBIN := "FSN BIN No.";
                                "EFT Device Name" := 'WOMPI';
                                "FSN Last Digits" := '0000';
                                "Expiry Date" := '0000';
                                "FSN Print Amount" := Amount;
                            end;
                    end;
                end;
            }
            field(Plazos; pPlazos)
            {
                Caption = 'Plazos';
                Editable = (gType = 2);
                trigger OnValidate()
                begin
                    case pPlazos of
                        pPlazos::"3 Mes":
                            Rec."FSN Points/Terms" := '03';
                        pPlazos::"6 Meses":
                            Rec."FSN Points/Terms" := '06';
                        pPlazos::"9 Meses":
                            Rec."FSN Points/Terms" := '09';
                    End;
                end;
            }
        }
    }

    actions
    {
        area(processing)
        {
            group(Process)
            {
                Image = Process;
                Caption = 'Process';
                action("Process Pay")
                {
                    Caption = 'Processing';
                    Enabled = VisibleTextBoxPayments;
                    Image = Apply;
                    Promoted = true;
                    PromotedIsBig = true;
                    trigger OnAction()
                    var
                        _BuyType: Integer;
                        _EntryLinkEntry: Integer;
                        _Plazo: Integer;
                        _Coupon: Code[20];
                        _Description: Text[50];
                        lText1: Label 'Coupon %1, is not valid for BIN %2';
                        Bacrec: Label 'Utilizar pos de BAC';
                        Text030: Label 'Información enviada a pos de BAC\%1';
                        WompiIntegration: Codeunit "FSN Wompi Integration";
                        expirationMonth: Integer;
                        expirationYear: Integer;
                        TEXT000: Label 'Mes invalido %1';
                        TEXT001: Label 'Año invalido %1';
                        TEXT002: Label 'Code Result: %1 \ Sin procesar, validar los datos';
                        TEXT003: Label 'Code Result: %1 \ %2';
                        TEXT004: Label 'Media de pago ya autorizada';
                        TEXT005: Label 'Card: %1 \Expire Date: %2 \ Amount: %3 \Process?';
                        CodeResult: Text;
                        MessageResult: Text;
                        ReponseText: Text;
                        json, obj : JsonObject;
                        token: JsonToken;
                        transactionResult: JsonObject;
                        FechaText: Text[5];
                        CodeResultS: Integer;
                        POSGUI: Codeunit "LSC POS GUI";
                        POSCardReqEntry: Record "FSN POS Card Request Entry";
                        authCodeValue: text[20];
                        POSCardIntegration: Codeunit "FSN POS Card Integration";
                        ErrorText: Text;
                        POSTransLineToken: Record "LSC POS Trans. Line";
                    begin
                        IF NOT FSNCC() THEN
                            POSSESSION.SetValue('SALESCCPROCESSCUS', '');

                        if POSSESSION.GetValue('SALESCCPROCESSCUS') = '' then begin
                            if FSNCC() then begin
                                if tokenWompi then begin
                                    ErrorText := '';
                                    ValDataFrom(ErrorText);
                                    if ErrorText <> '' then
                                        Error(ErrorText);

                                    if tokenWompi then begin
                                        POSTransLineToken.Reset();
                                        POSTransLineToken.SetRange(POSTransLineToken."Receipt No.", "Receipt No.");
                                        POSTransLineToken.SetRange(POSTransLineToken."Entry Type", POSTransLineToken."Entry Type"::Payment);
                                        POSTransLineToken.SetRange(POSTransLineToken."Entry Status", POSTransLineToken."Entry Status"::" ");
                                        POSTransLineToken.SetRange(POSTransLineToken."Line No.", "Line No.");
                                        POSTransLineToken.SetRange(POSTransLineToken."FSN token Message", false);
                                        if POSTransLineToken.FindFirst() then begin
                                            if not ("FSN Bank Name" = 'WOMPI') then
                                                ProcessTokenCard();
                                        end;

                                    end;
                                end;
                            end;

                            IF "Authorisation Ok" OR ("FSN Bank Name" = 'WOMPI') THEN
                                EXIT;

                            TypeTextMsg := '';
                            TypeTextMsg2 := TypeTextMsg;
                            CASE gType OF
                                0:
                                    TypeTextMsg := 'Compra Normal';
                                1:
                                    TypeTextMsg := 'Compra Puntos';
                                2:
                                    BEGIN
                                        TypeTextMsg := 'Compra Plazo';
                                        TypeTextMsg2 := FORMAT(pPlazos);
                                    END;
                                ELSE
                                    ERROR(STRSUBSTNO(Text005, FORMAT(gType)));
                            END;
                            IF STRPOS("Expiry Date", '/') > 0 THEN BEGIN
                                "Expiry Date" := POSCardIntegration.ConvertLastDateToParameter("Expiry Date");
                                MODIFY;
                                GET("Store No.", "POS Terminal No.", "Receipt No.", "Line No.");
                            END;
                            _BuyType := gType;
                            _DateContext := TODAY;
                            POSCardIntegration.SetGlobalCommandInt(_BuyType);
                            POSCardIntegration.SetGlobalDateContext(_DateContext);
                            POSCardIntegration.TestRequireFields(Rec, 2);
                            CASE pPlazos OF
                                0:
                                    _Plazo := 3;
                                1:
                                    _Plazo := 6;
                                2:
                                    _Plazo := 9;
                            END;
                            POSCardIntegration.SetGlobalPlazoInt(_Plazo);
                            IF NOT CONFIRM(STRSUBSTNO(Text010, NumDecript,
                                           POSCardIntegration.ConvertLastDateFromParameter(Rec."Expiry Date"),
                                          FORMAT(Rec.Amount),
                                          TypeTextMsg,
                                          TypeTextMsg2)) THEN
                                EXIT;
                            IF NOT POSCardController.CheckCouponBINValid(Rec."Receipt No.", Rec."FSN BIN No.", _Coupon, _Description) then
                                Error(STRSUBSTNO(lText1, _Description, Rec."FSN BIN No."));
                            if BINList.Get(Rec."FSN BIN No.") then;

                            IF NOT POSCardIntegration.ValildateManualRequest(Rec, _EntryLinkEntry, 'SERFINSA') THEN BEGIN
                                Rec.GET(Rec."Store No.", Rec."POS Terminal No.", Rec."Entry No.");
                                EXIT;
                            END;

                            If not ((BINList."Emisor Setup Code" <> '')) then begin
                                IF _EntryLinkEntry = 0 THEN
                                    ERROR(Text006);

                                POSCardIntegration.SendRequest(_EntryLinkEntry, Rec, _Plazo);
                                COMMIT;
                                RetailSetup.GET;

                                POSCardRequestEntry.GET(_EntryLinkEntry, _DateContext, RetailSetup."Distribution Location");
                                IF POSCardRequestEntry."Response Web Ok" THEN
                                    POSCardIntegration.TransferInfoToCardEntry(POSCardRequestEntry, Rec);
                                Rec.GET(Rec."Store No.", Rec."POS Terminal No.", Rec."Entry No.");
                                EditFields := not Rec."Authorisation Ok";
                                CurrPage.Update(false);
                                /*POSCardIntegration.SendRequest(_EntryLinkEntry, Rec, 0);*/
                                Message(POSCardIntegration.ProcessMessageTrans(_EntryLinkEntry, Rec));
                            end else begin
                                Message(Text030, Bacrec);
                            end;

                        end else begin
                            tokenWompi := false;
                            VisibleTokenModal := false;
                            IF "Authorisation Ok" THEN
                                Error(TEXT004);

                            if LastDate = '' then begin
                                expirationMonth := 0;
                                expirationYear := 0;
                                exit;
                            end;

                            FechaText := LastDate;
                            FechaText := DELCHR(FechaText, '=', '/');

                            Evaluate(expirationMonth, CopyStr(FechaText, 1, 2));
                            Evaluate(expirationYear, CopyStr(FechaText, 3, 4));

                            IF (expirationMonth > 12) OR (expirationMonth < 0) THEN
                                Error(TEXT000, expirationMonth);

                            expirationYear += 2000;

                            IF (expirationYear > 2099) OR (expirationYear < 2000) THEN
                                Error(TEXT001, expirationYear);

                            CASE gType OF
                                0:
                                    TypeTextMsg := 'Compra Normal';
                                1:
                                    TypeTextMsg := 'Compra Puntos';
                                2:
                                    BEGIN
                                        TypeTextMsg := 'Compra Plazo';
                                        TypeTextMsg2 := FORMAT(pPlazos);
                                    END;
                                ELSE
                                    ERROR(STRSUBSTNO(Text005, FORMAT(gType)));
                            end;

                            IF POSGUI.PosConfirm(STRSUBSTNO(TEXT005, NumDecript, Rec."Expiry Date", FORMAT(Rec.Amount)), TRUE) THEN BEGIN
                                ReponseText := WompiIntegration.SalesTransactionCreditCard(Rec."FSN Last Digits", expirationMonth, expirationYear, Amount, POSSESSION.GetValue('SALESCCPROCESSCUS'), CodeResultS);

                                if NOT (ReponseText IN ['', '{}']) then begin
                                    json.ReadFrom(ReponseText);

                                    if json.SelectToken('transactionResult', token) then
                                        transactionResult := token.AsObject();

                                    if transactionResult.SelectToken('resultCode', token) then
                                        if not token.AsValue().IsNull then
                                            CodeResult := token.AsValue().AsText();

                                    if transactionResult.SelectToken('message', token) then
                                        if not token.AsValue().IsNull then
                                            MessageResult := token.AsValue().AsText();

                                    /*if transactionResult.SelectToken('authCode', token) then 
                                        authCodeValue := token.AsValue().AsText();*/

                                    if transactionResult.SelectToken('authCode', token) then
                                        if token.IsValue then begin
                                            if not token.AsValue().IsNull then
                                                authCodeValue := token.AsValue().AsText();
                                        end;


                                    IF CodeResult = '00' THEN begin
                                        EditFields := false;
                                        "Authorisation Ok" := true;
                                        POSCardIntegration.SetGlobalDateContext(Today);
                                        Modify();

                                        _BuyType := gType;
                                        POSCardIntegration.SetGlobalCommandInt(_BuyType);
                                        IF NOT POSCardIntegration.ValildateManualRequest(Rec, _EntryLinkEntry, 'WOMPI') THEN;

                                        POSCardReqEntry.Reset();
                                        POSCardReqEntry.SetRange(POSCardReqEntry."Receipt No.", Rec."Receipt No.");
                                        POSCardReqEntry.SetRange(POSCardReqEntry."Line No.", Rec."Line No.");
                                        IF POSCardReqEntry.FindFirst() then begin
                                            POSCardReqEntry."Response Web Ok" := TRUE;
                                            POSCardReqEntry."Authorization Code" := CodeResult;
                                            POSCardReqEntry."Trans Authorization" := authCodeValue;
                                            POSCardReqEntry.Modify(true);
                                            POSCardIntegration.TransferInfoToCardEntry(POSCardReqEntry, Rec);
                                        end;
                                    end;

                                    Message(StrSubstNo(TEXT003, CodeResult, MessageResult));
                                end else
                                    Error(STRSUBSTNO(TEXT002, CodeResultS));
                            END;
                        end;
                    end;
                }
            }
            group(Check)
            {
                Caption = 'Check';
                Image = Check;
                action("Check Points")
                {
                    Caption = 'Check Points';
                    Enabled = VisibleTextBoxPayments;
                    Image = Currency;
                    Promoted = true;
                    PromotedCategory = Process;
                    PromotedIsBig = true;

                    trigger OnAction()
                    var
                        _BuyType: Integer;
                        _EntryLinkEntry: Integer;
                        _Coupon: Code[20];
                        _Description: Text[50];
                        lText1: Label 'Coupon %1, is not valid for BIN %2';
                    begin

                        IF "Authorisation Ok" OR ("FSN Bank Name" = 'WOMPI') THEN
                            EXIT;

                        _BuyType := gType;
                        gCommand := 'MANCONMILLA';
                        POSCardIntegration.SetGlobalCommandManual(gCommand);
                        POSCardIntegration.SetGlobalDateContext(TODAY);

                        if "FSN Bank Name" <> '' then
                            POSCardIntegration.TestRequireFields(Rec, 1);

                        IF NOT POSCardController.CheckCouponBINValid(Rec."Receipt No.", Rec."FSN BIN No.", _Coupon, _Description) then
                            Error(STRSUBSTNO(lText1, _Description, Rec."FSN BIN No."));

                        IF NOT POSCardIntegration.ValildateManualRequest(Rec, _EntryLinkEntry, 'SERFINSA') THEN BEGIN
                            Rec.GET(Rec."Store No.", Rec."POS Terminal No.", Rec."Entry No.");
                            EXIT;
                        END;

                        POSCardIntegration.SendRequest(_EntryLinkEntry, Rec, 0);
                        Message(POSCardIntegration.ProcessMessagePoints(_EntryLinkEntry, Rec));
                    end;
                }
                action("Recovery Info.")
                {
                    Caption = 'Recovery Info.';
                    Promoted = true;
                    PromotedCategory = Process;
                    PromotedIsBig = true;
                    Visible = VisibleTextBoxPayments;
                    Image = LotInfo;

                    trigger OnAction()
                    var
                        lCardEntry: Record "LSC POS Card Entry";
                        lDelOrder: Record "LSC Delivery Order";
                        AmountDec: Decimal;
                        Int_: Integer;
                        TextError: Text;
                        OK: Boolean;
                    begin
                        COMMIT;
                        IF "Authorisation Ok" OR ("FSN Bank Name" = 'WOMPI') THEN
                            EXIT;

                        IF "Authorisation Ok" THEN BEGIN
                            DIALOG.MESSAGE(Text017);
                            EXIT;
                        END;

                        OK := FALSE;
                        POSCardRequestEntry.RESET;
                        POSCardRequestEntry.SETCURRENTKEY("Receipt No.", "Line No.", "Cast Last Numbers", "Enter Input", "Response Web Ok");
                        POSCardRequestEntry.SETRANGE(POSCardRequestEntry."Receipt No.", "Receipt No.");
                        POSCardRequestEntry.SETRANGE(POSCardRequestEntry."Response Web Ok", TRUE);
                        IF POSCardRequestEntry.FIND('-') THEN
                            REPEAT

                                AmountDec := 0;
                                IF STRLEN(POSCardRequestEntry."Amount Input") > 2 THEN
                                    IF STRPOS(POSCardRequestEntry."Amount Input", '.') > 0 THEN
                                        EVALUATE(AmountDec, POSCardRequestEntry."Amount Input")
                                    ELSE BEGIN
                                        EVALUATE(Int_, POSCardRequestEntry."Amount Input");
                                        AmountDec := Int_ / 100;
                                    END;


                                lCardEntry.RESET;
                                lCardEntry.SETRANGE(lCardEntry."Receipt No.", POSCardRequestEntry."Receipt No.");
                                lCardEntry.SETRANGE(lCardEntry."Line No.", POSCardRequestEntry."Line No.");
                                IF NOT lCardEntry.FIND('-') THEN
                                    IF CONFIRM(
                                        STRSUBSTNO(Text016,
                                        FORMAT(POSCardRequestEntry."Date Key"),
                                        STRSUBSTNO('******%1', POSCardRequestEntry."Cast Last Numbers"),
                                        FORMAT(AmountDec)
                                        )) THEN BEGIN

                                        IF NOT POSCardIntegration.CreateTransacInherit(POSCardRequestEntry, Rec, AmountDec, TextError) THEN
                                            ERROR(TextError);
                                        EXIT;
                                    END;

                            UNTIL (POSCardRequestEntry.NEXT = 0) OR OK;
                        lCardEntry.RESET;
                        lCardEntry.SETRANGE(lCardEntry."Receipt No.", "Receipt No.");
                        lCardEntry.SETFILTER("Line No.", '<>%1', "Line No.");
                        IF lCardEntry.FIND('+') THEN
                            REPEAT
                                IF lCardEntry."EFT Additional ID" <> '' THEN BEGIN
                                    Rec."EFT Additional ID" := lCardEntry."EFT Additional ID";
                                    "Expiry Date" := lCardEntry."Expiry Date";
                                    "FSN BIN No." := lCardEntry."FSN BIN No.";
                                    "FSN CVV" := lCardEntry."FSN CVV";
                                    "FSN Last Digits" := lCardEntry."FSN Last Digits";
                                    "FSN Bank Name" := lCardEntry."FSN Bank Name";
                                    MODIFY;
                                    EXIT;
                                END;
                            UNTIL lCardEntry.NEXT(-1) = 0;

                        IF NOT lDelOrder.GET("Receipt No.") THEN
                            EXIT;
                        IF lDelOrder."External Order No." = '' THEN
                            EXIT;

                        lCardEntry.RESET;
                        lCardEntry.SETRANGE(lCardEntry."Receipt No.", lDelOrder."External Order No.");
                        IF lCardEntry.FIND('-') THEN
                            REPEAT
                                IF lCardEntry."EFT Additional ID" <> '' THEN BEGIN
                                    "EFT Additional ID" := lCardEntry."EFT Additional ID";
                                    "Expiry Date" := lCardEntry."Expiry Date";
                                    "FSN BIN No." := lCardEntry."FSN BIN No.";
                                    "FSN CVV" := lCardEntry."FSN CVV";
                                    "FSN Last Digits" := lCardEntry."FSN Last Digits";
                                    "FSN Bank Name" := lCardEntry."FSN Bank Name";
                                    MODIFY;
                                END;
                            UNTIL lCardEntry.NEXT = 0;
                        EXIT;
                    end;
                }
            }
            group(Vouchers)
            {
                Caption = 'Vouchers';
                Image = VoucherGroup;
                action(ToReuse)
                {
                    Caption = 'To Reuse';
                    Enabled = VisibleTextBoxPayments;
                    Image = CopyDocument;
                    Promoted = true;
                    PromotedCategory = Category4;
                    PromotedIsBig = true;

                    trigger OnAction()
                    var
                        AmountDec: Decimal;
                        Int_: Integer;
                        TextError: Text;
                        lTxt0: Label 'DUI cant be empty';
                    begin
                        COMMIT;
                        IF "Authorisation Ok" OR ("FSN Bank Name" = 'WOMPI') THEN begin
                            EXIT;
                            /* if gDUI = '' then begin
                                Message(lTxt0);
                                exit;*/
                        end;

                        IF "Authorisation Ok" THEN BEGIN
                            DIALOG.MESSAGE(Text017);
                            EXIT;
                        END;
                        CLEAR(PageVouchers);
                        IF PageVouchers.RUNMODAL = ACTION::LookupOK THEN BEGIN
                        END;

                        COMMIT;

                        LastTransRequest.RESET;
                        CLEAR(LastTransRequest);
                        PageVouchers.GetLastRecord(LastTransRequest);
                        IF LastTransRequest."Entry No." = 0 THEN
                            EXIT;

                        IF (LastTransRequest."Void Number" > 0) THEN
                            IF NOT (Amount = 0) THEN
                                ERROR(Text026);

                        COMMIT;
                        IF STRLEN(LastTransRequest."Amount Input") > 2 THEN
                            IF STRPOS(LastTransRequest."Amount Input", '.') > 0 THEN
                                EVALUATE(AmountDec, LastTransRequest."Amount Input")
                            ELSE BEGIN
                                EVALUATE(Int_, LastTransRequest."Amount Input");
                                AmountDec := Int_ / 100;
                            END;

                        TenderTypeSetup.GET("Tender Type");
                        IF TenderTypeSetup."FSN Used By Specific BIN" THEN BEGIN
                            IF NOT BINList.GET(Rec."FSN BIN No.") THEN
                                ERROR(STRSUBSTNO(Text020, TenderTypeSetup.Description, Rec."FSN BIN No."))
                            ELSE
                                IF BINList."Tender Type Default" <> Rec."Tender Type" THEN
                                    ERROR(STRSUBSTNO(Text020, TenderTypeSetup.Description, Rec."FSN BIN No."));
                        END ELSE BEGIN
                            IF BINList.GET(Rec."FSN BIN No.") AND (BINList."Tender Type Default" <> '') THEN
                                IF BINList."Tender Type Default" <> Rec."Tender Type" THEN
                                    ERROR(STRSUBSTNO(Text020, TenderTypeSetup.Description, Rec."FSN BIN No."));
                        END;

                        IF CONFIRM(
                                STRSUBSTNO(Text016,
                                FORMAT(LastTransRequest."Date Key"),
                                STRSUBSTNO('******%1', LastTransRequest."Cast Last Numbers"),
                                FORMAT(AmountDec)
                                ))
                        THEN BEGIN
                            IF NOT ((LastTransRequest."Void Number" > 0) AND (Amount = 0)) THEN
                                IF NOT POSCardIntegration.CreateTransacInherit(LastTransRequest, Rec, AmountDec, TextError) THEN
                                    ERROR(TextError);
                            POSCardIntegration.TransferInfoToCardEntry(LastTransRequest, Rec);

                            LastCard.SetRange("Receipt No.", LastTransRequest."Receipt No.");
                            LastCard.SetRange("Line No.", LastTransRequest."Line No.");
                            LastCard.SetRange("Store No.", LastTransRequest."Store No.");
                            LastCard.SetRange("Res.code", LastTransRequest."Authorization Code");
                            LastCard.Find('-');
                        END;
                        Rec.GET(Rec."Store No.", Rec."POS Terminal No.", Rec."Entry No.");
                        Rec."EFT Additional ID" := LastCard."EFT Additional ID";
                        Rec."FSN Last Digits" := LastCard."FSN Last Digits";
                        Rec.Modify();
                        CLEAR(PageVouchers);
                    end;
                }

                /*
                action(WompiData)
                {
                    Caption = 'Wompi Data';
                    Image = TotalValueInsured;
                    Promoted = true;
                    PromotedCategory = Category4;

                    trigger OnAction()
                    var
                        pParameterWP: Record "FSN Parameter";
                    begin
                        RetailSetup.GET;
                        IF NOT pParameterWP.GET('KINPOS', 'WOMPI') THEN
                            pParameterWP.INIT;

                        COMMIT;
                        IF "Authorisation Ok" THEN
                            EXIT;

                        IF NOT VisibleWompiModal THEN BEGIN
                            IF NOT CONFIRM(Text022) THEN
                                EXIT;

                            ClearData;
                            "FSN Bank Name" := 'WOMPI';
                            "EFT Merchant No." := pParameterWP."Value Text 1";
                            "EFT Terminal ID" := pParameterWP."Value Text 2";
                            "FSN BIN No." := '0000';
                            "FSN Last Digits" := '0000';
                            "Expiry Date" := '0000';
                            MODIFY;
                            ShowModalWompi(TRUE, false);
                        END ELSE BEGIN
                            COMMIT;
                            IF NOT CONFIRM(Text021) THEN
                                EXIT;

                            ClearData;
                            MODIFY;
                            ShowModalWompi(FALSE, false);
                        END;
                    end;
                }
                */
            }
            /*  group("Validar-Bac")
                      {
                          Image = CashFlow;

                          action(ValidarBac)
                          {
                              Image = Bank;
                              ApplicationArea = All;
                              Promoted = true;
                              PromotedIsBig = true;

                              trigger OnAction()
                              var
                                  _BuyType: Integer;
                                  _EntryLinkEntry: Integer;
                                  _Plazo: Integer;
                                  _Coupon: Code[20];
                                  _Description: Text[50];
                                  lText1: Label 'Coupon %1, is not valid for BIN %2';
                                  MessageExrror: Label 'No se encontro recibo';
                                  Notval: label 'No se encontraron datos que validar';
                                  COD: Code[20];
                              //COD: Text;
                              begin
                                  COD := 'F2000000000000000171';
                                  BAC.GetReceip(COD);
                                  //BAC.ResPBac(COD);
                              end;
                          }

}*/
            /* action(CreateCard)
            {
                Caption = 'Wompi Guardar Tarjeta';
                Image = CopyDocument;
                Promoted = true;
                PromotedIsBig = true;

                trigger OnAction()
                var
                    AmountDec: Decimal;
                    Int_: Integer;
                    TextError: Text;
                    lTxt0: Label 'DUI cant be empty';
                    WcreateCC: Page "FSN Wompi Create Credit Card";
                begin
                    WcreateCC.SETGLOBALVALUE(Rec);
                    WcreateCC.RunModal();



                END;
             }*/

            action(FilterCreditCArd)
            {
                Caption = 'Wompi Filtrar Tarjeta';
                Image = CopyDocument;
                Promoted = true;
                PromotedIsBig = true;

                trigger OnAction()
                var
                    FilterCC: Page "FSN Filter Credit Card Wompi";
                begin
                    FilterCC.SETGLOBALVALUE(Rec);
                    FilterCC.RunModal();
                END;
            }
        }
    }

    trigger OnAfterGetRecord()
    var
        textc: Text;
        POSTransLineToken: Record "LSC POS Trans. Line";
        POSTransactionC: Codeunit "LSC POS Transaction";
    begin
        CLEAR(NumDecript);
        CLEAR(NumVerif);
        CLEAR(LastDate);
        CLEAR(gDUI);
        CLEAR(gBIN);
        IF "Authorisation Ok" THEN
            NumDecript := '****-****-****-' + Rec."FSN Last Digits"
        ELSE
            if Rec."EFT Additional ID" <> '' then begin
                IF FSNCC() THEN BEGIN
                    if POSSESSION.GetValue('SALESCCPROCESSCUS') <> '' then begin
                        NumDecript := '****-****-****-' + Rec."FSN Last Digits";
                    end else begin
                        if STRPOS(Rec."EFT Additional ID", 'XXXXXX') = 0 then
                            NumDecript := SeparateCharCard(Decrypt(Rec."EFT Additional ID"))
                        else
                            NumDecript := '****-****-****-' + Rec."FSN Last Digits";
                    end;
                end else
                    NumDecript := SeparateCharCard(Decrypt(Rec."EFT Additional ID"));
            end;

        NumVerif := "EFT POS Terminal No.";
        LastDate := POSCardIntegration.ConvertLastDateFromParameter("Expiry Date");

        IF POSTransLine.GET("Receipt No.", 36) THEN
            IF STRPOS(POSTransLine.Description, '::') > 0 THEN
                gDUI := COPYSTR(POSTransLine.Description, STRPOS(POSTransLine.Description, '::') + 2)
            ELSE
                gDUI := COPYSTR(POSTransLine.Description, 1, 20);


        if gDUI = '' then
            Client(PosTran.GetReceiptNo());
        gBIN := Rec."FSN BIN No.";

        case Rec."EFT Device Name" of
            'MANCOMPRANOR':
                gType := gType::Normal;
            'MANCOMPRAPLA':
                gType := gType::"A Plazo";
            'MANCOMPRAMIL':
                gType := gType::Puntos;
            'WOMPI':
                gType := gType::Wompi;
            else
                gType := gType::Normal;
        end;
        if gType = gType::Wompi then
            ShowModalWompi(true, true)
        else
            ShowModalWompi(false, true);

        IF FSNCC() THEN BEGIN
            POSTransLineToken.Reset();
            POSTransLineToken.SetRange(POSTransLineToken."Receipt No.", "Receipt No.");
            POSTransLineToken.SetRange(POSTransLineToken."Line No.", "Line No.");
            POSTransLineToken.SetRange(POSTransLineToken."FSN token Wompi", true);
            if POSTransLineToken.FindFirst() then begin
                tokenWompi := true;
                VisibleTokenModal := true;
                ValInformationCustomerToken();
            end else begin
                tokenWompi := false;
                VisibleTokenModal := false;
            end;
        end else begin
            tokenWompi := false;
            VisibleTokenModal := false;
        end;
    end;

    trigger OnModifyRecord(): Boolean
    begin
        EditFields := NOT "Authorisation Ok";
    end;

    trigger OnOpenPage()
    begin
        EditFields := NOT "Authorisation Ok";
        TextBoxModeManual := BlockProcess;
        VisibleTextBoxPayments := NOT BlockProcess;
        if FSNCC() then
            tokenWompiVisible := true
        else
            tokenWompiVisible := false;

    end;

    trigger OnClosePage()
    var
        myInt: Integer;
    begin
        IF FSNCC THEN BEGIN
            if POSSESSION.GetValue('SALESCCPROCESSCUS') <> '' then begin
                IF not (Rec."Authorisation Ok") then begin
                    NumDecript := '';
                    POSSESSION.SetValue('SALESCCPROCESSCUS', '');
                    OnValidateCardNumber(NumDecript);
                end;
            end;
        END;
    end;

    var
        POSCardRequestEntry: Record "FSN POS Card Request Entry";
        POSTransLine: Record "LSC POS Trans. Line";
        POSCardIntegration: Codeunit "FSN POS Card Integration";
        POSCardController: Codeunit "FSN POS Card Controller";
        FSNUtility: Codeunit "FSN Utility";
        PosTran: Codeunit "LSC POS Transaction";
        RetailSetup: Record "LSC Retail Setup";
        PageVouchers: Page "FSN Card Search Request OK";
        LastTransRequest: Record "FSN POS Card Request Entry";
        TenderTypeSetup: Record "LSC Tender Type Setup";
        BINList: Record "FSN BIN Bank";
        NumDecript: Text[30];
        NumVerif: Text[10];
        LastDate: Text[5];
        gType: Option Normal,Puntos,"A Plazo",Wompi;
        gCommand: Text[50];
        pPlazos: Option "3 Mes","6 Meses","9 Meses";
        gDUI: Text[20];
        gBIN: Text[6];
        TypeTextMsg: Text[50];
        TypeTextMsg2: Text[50];
        EditFields: Boolean;
        _DateContext: Date;
        Text005: Label 'Error transaction type %1 is not avaliable';
        Text006: Label 'Cant create link for transaction';
        Text010: Label '%4 %5 \Card: %1 \Expire Date: %2 \ Amount: %3 \Process?';
        Text011: Label '%1 : must be format: MM/YY';
        Text012: Label '%1 : Month cant be higher to 12 and less to Zero. (MM/YY)';
        Text013: Label '%1 : Year must be higher to 2000 and less to 2100. (MM/YY)';
        Text014: Label 'CVV length cant be higher to 3';
        Text015: Label 'Owner Card ::%1';
        Text016: Label 'Date %1\Card: %2 \Amount: %3 \Re use voucher?';
        Text017: Label 'Transaction is already sucessfull';
        Text020: Label 'Tender Type %1 not allowed for BIN %2';
        Text021: Label '->Change to NORMAL modal\->Data will clean.\Continue?';
        Text022: Label '->Change modal to WOMPI\->Data will clean.\Continue?';
        Text023: Label 'WOMPI o ECOMMERCE we are reserved';
        Text024: Label 'BIN must be 6 digits.';
        Text025: Label 'Number is false';
        Text026: Label 'Cant be re use Reverse';
        BlockProcess: Boolean;
        TextBoxModeManual: Boolean;
        VisibleTextBoxPayments: Boolean;
        VisibleWompiModal: Boolean;
        VisibleTokenModal: Boolean;
        VisibleTransactorModal: Boolean;
        LastCard: Record "LSC POS Card Entry";
        BAC: Codeunit "FSN Pos Card BAC";
        POSCardExternalCnn: codeunit "FSN Card External Conextion";
        POSSESSION: Codeunit "LSC POS Session";
        GlobalUltDigit: text;
        tokenWompi: Boolean;
        email: Text;
        DocumentType: Option DUI,CarnetResidente;
        DocumentNo: text[10];
        cellPhoneNumber: text[8];
        separador: Text;
        tokenWompiVisible: Boolean;

    procedure GetLine(pRec: Record "LSC POS Card Entry")
    begin
        Clear(Rec);
        Rec.Get(pRec."Store No.", pRec."POS Terminal No.", pRec."Entry No.");
    end;


    procedure SeparateCharCard(Card: Text[150]): Text[150]
    var
        _i: Integer;
        Number: Text[150];
    begin

        IF Card <> '' THEN BEGIN
            Number := Card;
            Card := '';
            FOR _i := 1 TO STRLEN(Number) DO BEGIN
                Card += COPYSTR(Number, _i, 1);
                IF (_i MOD 4 = 0) AND (_i < STRLEN(Number)) THEN
                    Card += '-';
            END;
        END;
        IF Card = '' THEN
            EXIT(Number);

        EXIT(Card)
    end;


    procedure ValidateCard(CardInput: Text[150]): Text[150]
    var
        Dec: Decimal;
        tmpTarjeta: Text[150];
        i: Integer;
        _int: Integer;
        j: Text[1];
    begin
        tmpTarjeta := '';
        FOR i := 1 TO STRLEN(CardInput) DO BEGIN
            j := COPYSTR(CardInput, i, 1);
            IF EVALUATE(_int, j) AND (j <> '-') THEN
                tmpTarjeta += j;
        END;

        IF (STRLEN(tmpTarjeta) > 13) AND (STRLEN(tmpTarjeta) < 17) THEN
            EXIT(tmpTarjeta);

        EXIT('');
    end;

    procedure SetProcessAvaliable(pAvaliable: Boolean)
    begin
        BlockProcess := NOT pAvaliable;
    end;


    procedure ShowModalWompi(pShowModalWompi: Boolean; pOnOpenPage: Boolean)
    begin
        VisibleWompiModal := pShowModalWompi;
        VisibleTransactorModal := NOT pShowModalWompi;
        if not pOnOpenPage then
            if not pShowModalWompi then begin
                OnValidateCardNumber(Decrypt(Rec."Card Number"));
            end;
    end;

    local procedure OnValidateCardNumber(CardNumber: Text[150])
    var
        Card: Text[150];
    begin

        Card := ValidateCard(NumDecript);
        Rec."EFT Additional ID" := Encrypt(Card);
        Rec."Auth.code" := '';//Clear from wompi
        Rec."FSN BIN No." := '';
        Rec."FSN Bank Name" := '';
        Rec."FSN Last Digits" := '';
        IF STRLEN(Card) >= 6 THEN BEGIN
            Rec."FSN BIN No." := COPYSTR(Card, 1, 6);
            Rec."FSN Last Digits" := COPYSTR(Card, STRLEN(Card) - 3);

            IF BINList.GET(Rec."FSN BIN No.") THEN
                Rec."FSN Bank Name" := BINList."Bank Name";
        END;

        MODIFY;
        Rec.GET(Rec."Store No.", Rec."POS Terminal No.", Rec."Entry No.");
    end;

    procedure ClearData()
    begin
        Rec."FSN Bank Name" := '';
        Rec."FSN Operation Name" := '';
        Rec."EFT Device Name" := '';
        Rec."Expiry Date" := '';
        Rec."Auth.code" := '';
        Rec."EFT Additional ID" := '';
        Rec.Encrypted := FALSE;
        Rec."FSN Last Digits" := '';
        Rec."FSN BIN No." := '';
        Rec."EFT Merchant No." := '';
        Rec."EFT Terminal ID" := '';
        Rec."EFT Trans. No." := '';
        CLEAR(NumDecript);
        CLEAR(NumVerif);
        CLEAR(LastDate);
        CLEAR(gBIN);
    end;


    procedure NumberTransIsFalse(pValue: Text[20])
    var
        pInt: Integer;
        Err: Boolean;
    begin
        CLEAR(Err);
        IF pValue = '' THEN
            EXIT;

        IF EVALUATE(pInt, pValue) THEN
            IF pInt = 0 THEN
                Err := TRUE;

        IF Err OR (STRLEN(pValue) < 6) THEN
            ERROR(Text025);
    end;

    procedure Client(Rec: Code[20])
    var
        myInt: Integer;
        Cust: Record Customer;
        Pline: Record "LSC POS Trans. Line";
    begin
        Pline.Reset();
        Pline.SetRange("Receipt No.", Rec);
        Pline.SetRange("Entry Status", Pline."Entry Status"::" ");
        Pline.SetRange("Text Type", Pline."Text Type"::"Cust. Text");
        if Pline.FindFirst() then begin
            Cust.SetRange("No.", Pline."Card/Customer/Coup.Item No");
            if Cust.Find('-') then
                gDUI := Cust."FSN DUI";
            IF gDUI <> '' THEN
                FSNUtility.POSNewLineFreeText("Receipt No.", 36, STRSUBSTNO(Text015, gDUI), 2)

        end;
    end;

    procedure ProcessTokenCard()
    var
        CardRequestOnline: Page "FSN Card Request Online View";
        PAGEProcessOnline: page "FSN Card Request Online";
        TEXT000: Label 'Desea guardar informacion de la tarjeta?';
        TEXT001: Label 'Guardando Informacion, Espere.......';
        TEXT002: Label 'Debe completar la informacion';
        TEXT003: Label 'Media de pago ya AUTORIZADA';
        TEXT004: Label 'Fecha Expiracion invalida %1';
        TEXT005: Label 'Code Result: %1 \ ERROR Debe validar los datos';
        TEXT006: Label 'Code Result: %1 \ Datos enviados con exito, validar mensaje de texto con el cliente.';
        Error: Text;
        Windows: Dialog;
        ReponseResult: Text;
        json, obj : JsonObject;
        token: JsonToken;
        cid: Text;
        FechaText: Text[5];
        CodeResult: Integer;
        expirationMonth: Integer;
        expirationYear: Integer;
        WompiIntegration: Codeunit "FSN Wompi Integration";
        POSGUI: Codeunit "LSC POS GUI";
        POSTransLineToken: Record "LSC POS Trans. Line";
    begin
        //IF not (Rec."Authorisation Ok") then begin
        Error := '';
        if NumDecript <> '' then begin
            NumDecript := DelChr(NumDecript, '=', '-');
            if POSGUI.PosConfirm(TEXT000, true) then begin
                //ValDataFrom(Error);
                if Error = '' then begin
                    Windows.OPEN(TEXT001);
                    Windows.UPDATE;

                    FechaText := LastDate;
                    FechaText := DELCHR(FechaText, '=', '/');

                    Evaluate(expirationMonth, CopyStr(FechaText, 1, 2));
                    Evaluate(expirationYear, CopyStr(FechaText, 3, 4));

                    IF (expirationMonth > 12) OR (expirationMonth < 0) THEN
                        Message(STRSUBSTNO(TEXT004, expirationMonth));

                    expirationYear += 2000;

                    IF (expirationYear > 2099) OR (expirationYear < 2000) THEN
                        Error(STRSUBSTNO(TEXT004, expirationYear));

                    ReponseResult := WompiIntegration.SedFormSaveCreditCard(Rec."Receipt No.", Rec."Line No.", NumDecript, expirationMonth, expirationYear, Format(DocumentType), DocumentNo, cellPhoneNumber, email, CodeResult);

                    IF CodeResult = 200 THEN begin
                        POSTransLineToken.Reset();
                        POSTransLineToken.SetRange(POSTransLineToken."Receipt No.", "Receipt No.");
                        POSTransLineToken.SetRange(POSTransLineToken."Entry Type", POSTransLineToken."Entry Type"::Payment);
                        POSTransLineToken.SetRange(POSTransLineToken."Entry Status", POSTransLineToken."Entry Status"::" ");
                        POSTransLineToken.SetRange(POSTransLineToken."Line No.", "Line No.");
                        if POSTransLineToken.FindFirst() then begin
                            POSTransLineToken."FSN token Message" := true;
                            POSTransLineToken.Modify();
                        end;

                        Message(StrSubstNo(TEXT006, 00)); //OnValidateCardNumber(Card)
                    END ELSE
                        ERROR(STRSUBSTNO(TEXT005, CodeResult));
                    Windows.Close();
                    CurrPage.Close();
                end else begin
                    Message(Error);
                    exit;
                end;
            end;
        end else
            Error(TEXT002);
        //end else
        //    Error(TEXT003);
    end;


    procedure ValDataFrom(var errormessage: Text)
    var
        myInt: Integer;
        TEXT000: Label 'Se debe completar la información';
        TEXT001: Label 'Fecha Expiracion no puede ser vacio';
        TEXT002: Label 'Numero de Documento no puede ser vacio';
        TEXT003: Label 'Numero de telefono no puede ser vacio';
        TEXT004: Label 'Correo electronico no puede ser vacio';
    begin
        if NumDecript <> '' then begin
            if LastDate = '' then
                errormessage := TEXT001;

            if DocumentNo = '' then
                errormessage := TEXT002;

            if cellPhoneNumber = '' then
                errormessage := TEXT003;

            if email = '' then
                errormessage := TEXT004;

        end;
    end;

    procedure ValInformationCustomerToken()
    var
        Transaction: Record "LSC POS Transaction";
        Customer: Record Customer;
        DelOrder: Record "LSC Delivery Order";
        POSTransLineToken: Record "LSC Pos Trans. Line";
    begin
        if gType <> gType::Wompi then begin
            IF Transaction.Get("Receipt No.") THEN BEGIN
                if Customer.get(Transaction."Customer No.") then begin
                    email := Customer."E-Mail";

                    DocumentType := DocumentType::DUI;
                    DocumentNo := customer."FSN DUI";

                    if DelOrder.Get(Rec."Receipt No.") then
                        cellPhoneNumber := DelOrder."Phone No.";

                    POSTransLineToken.Reset();
                    POSTransLineToken.SetRange(POSTransLineToken."Receipt No.", Transaction."Receipt No.");
                    POSTransLineToken.SetRange(POSTransLineToken."Entry Type", POSTransLineToken."Entry Type"::Payment);
                    POSTransLineToken.SetRange(POSTransLineToken."Entry Status", POSTransLineToken."Entry Status"::" ");
                    POSTransLineToken.SetRange(POSTransLineToken."Line No.", "Line No.");
                    if POSTransLineToken.FindFirst() then
                        if POSTransLineToken."FSN token Wompi" <> tokenWompi then begin
                            POSTransLineToken."FSN token Wompi" := tokenWompi;
                            POSTransLineToken.Modify();
                        end;

                    VisibleTokenModal := tokenWompi;
                END;
            end;
        end else begin
            tokenWompi := false;
            VisibleTokenModal := false;
        end;
    end;

    procedure FSNCC(): Boolean
    var
        myInt: Integer;
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line";
        Processed: Boolean;
        MsgResult: Text;
    begin
        RequestID := 'FSNCC';
        Processed := false;
        FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
        exit(Processed);
    END;
}
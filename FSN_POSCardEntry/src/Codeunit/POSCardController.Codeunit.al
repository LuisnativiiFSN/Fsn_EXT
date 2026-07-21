/// <summary>
/// Codeunit FSN POS Card Controller (ID 50037).
/// </summary>
codeunit 50037 "FSN POS Card Controller"
{

    TableNo = 99008906;

    trigger OnRun()
    var
        POSTransaction_l: Record "LSC POS Transaction";
        CurrInput_l: Text;
        ErrorText: Text[250];
        _ExitOnly: Boolean;
        NewCurrInput: Text[20];
    begin
        GlobalRec.Copy(Rec);
        CurrInput_l := POSTransactionCU.GetCurrInput;
        POSTransLineCU.GetCurrentLine(POSTransLine);

        _Ok := TRUE;
        Clear(_ExitOnly);
        Clear(ErrorText);
        Clear(NewCurrInput);
        IF POSTransaction_l.GET(POSTransactionCU.GetReceiptNo) THEN BEGIN
            CASE Command OF
                'VOID', 'VOID_L':
                    _Ok := BlockDeleteTransData(POSTransaction_l, ErrorText, _ExitOnly, Rec);
                'VOID_TR':
                    BEGIN
                        SetPosManual(POSTransaction_l, FALSE);
                    END;
                'KINPOS_INACTIVE':
                    BEGIN
                        SetPosManual(POSTransaction_l, FALSE);
                    END;
                'KINPOS_FORM':
                    BEGIN
                        if (POSSession.GetValue('#INACTIVE_KINPOS') = 'AUTOMATIC') then
                            ShowPosForm(POSTransaction_l, FALSE)
                        else
                            AssigmentVoucherDataManualMode();
                    END;
                'KINPOS_FORM_SELECT':
                    begin
                        ShowPosFormSelect(POSTransaction_l, 'KINPOSF');
                    end;
                /*'KINPOS_MANUAL':
                    begin
                        ShowManual(POSTransLine, POSTransaction_l);
                    end;*///Obsolete
                'KINPOS_REPORT':
                    BEGIN
                        PosCardEntriesReport(POSTransaction_l);
                    END;
                'KINPOS_AUTHRETURN':
                    AssigmentAuthorizationInReturn;
            END;
        END;
    end;

    var
        _Ok: Boolean;
        GlobalRec: Record "LSC POS Menu Line";
        POSTransLine: Record "LSC POS Trans. Line";
        POSTransaction: Record "LSC POS Transaction";
        POSSession: Codeunit "LSC POS Session";
        POS: codeunit "LSC POS Transaction";
        POSGUI: Codeunit "LSC POS GUI";
        BOUTIL: Codeunit "LSC BO Utils";
        POSCardIntegration: Codeunit "FSN POS Card Integration";
        POSTransactionCU: Codeunit "LSC POS Transaction";
        POSTransLineCU: Codeunit "LSC POS Trans. Lines";
        RetailSetup: Record "LSC Retail Setup";
        GlobalPosCardEntryReturn: Record "LSC POS Card Entry";
        TenderTypeSetup: Record "LSC Tender Type Setup";
        Text001: Label 'Terms (3, 6 or 9)';
        Text002: Label 'POS Card Entry not exists.';
        Text003: Label 'Original authorization number:';
        Text004: Label 'You want try to use the POS Serfinsa?';
        Text005: Label 'Error %1. \%2';
        Text006: Label 'Voucher information not found!. fill data vocuher in Manual mode';
        Text008: Label 'Change to voucher %1 ?';
        Text011: Label 'You can switch to MANUAL mode if you want';
        Text012: Label 'BIN, Print Amount and Authorization code cant be emtpy';
        Text017: Label 'Real value Vaucher is %1 and Payment line is %2';

    procedure CreateLinkPosCardEntry(pNewLine: Record "LSC POS Trans. Line"; CurrentInput: Text; POSSTATE: Text[50]; pHeader: Record "LSC POS Transaction")
    begin
        if TenderTypeSetup.Get(pNewLine.Number) then
            if TenderTypeSetup."FSN Function in CC" <> TenderTypeSetup."FSN Function in CC"::Card then
                exit;
        if POSCardIntegration.IsManualSetup() then begin
            POSCardIntegration.InitPOSCardEntryByPOSTransLine(pNewLine, pHeader, 'PREPAYMENT');
            exit;
        end;

        if pHeader."Sale Is Return Sale" then
            CreateLinkPosCardEntryReturnSale(pNewLine, CurrentInput, POSSTATE, pHeader)
        else
            CreateLinkPosCardEntrySale(pNewLine, CurrentInput, POSSTATE, pHeader)
    end;

    local procedure AssigmentVoucherDataManualMode()
    var
        i: Integer;
        RecRef: RecordRef;
        posCardEntryTmp: Record "LSC POS Card Entry" temporary;
        POSCtrl: Codeunit "LSC POS Controller";
        POSCtrlInterface: Codeunit "LSC POS Control Interface";
        PosContext_g: Codeunit "LSC POS Context";
    begin
        posCardEntryTmp.Reset();
        Clear(posCardEntryTmp);
        posCardEntryTmp."FSN Print Amount" := POSTransactionCU.GetOutstandingBalance();
        posCardEntryTmp.Insert(true);
        RecRef.GETTABLE(posCardEntryTmp);
        POSCtrlInterface.ShowRecordZoom(RecRef, '#VOUCHERDATA', '#VOUCHERDATA', TRUE);
        //PosContext_g.SetKeyValue('<#VOUCHERDATA>', Format('12'));
        POSCtrlInterface.ShowPanelModal('#DEL-VOUCHER', 'VOUCHERDATA');
    end;

    local procedure AssigmentAuthorizationInReturn()
    var
        ready: Boolean;
    begin
        POSTransaction.Get(POS.GetReceiptNo());
        if not POSTransaction."Sale Is Return Sale" then begin
            POSSession.SetValue('KINPOSAUTHRETURN', '');
            exit;
        end;

        if (POSSession.GetValue('#INACTIVE_KINPOS') = 'AUTOMATIC') then begin
            Clear(ready);
            GlobalPosCardEntryReturn.SETRANGE(GlobalPosCardEntryReturn."Store No.", POSTransaction."Retrieved from Store No.");
            GlobalPosCardEntryReturn.SETRANGE(GlobalPosCardEntryReturn."POS Terminal No.", POSTransaction."Retrieved from POS Term. No.");
            GlobalPosCardEntryReturn.SETRANGE(GlobalPosCardEntryReturn."Transaction No.", POSTransaction."Retrieved from Trans. No.");
            GlobalPosCardEntryReturn.SETRANGE(GlobalPosCardEntryReturn."Receipt No.", POSTransaction."Retrieved from Receipt No.");
            if GlobalPosCardEntryReturn.Find('-') then
                repeat
                    if (GlobalPosCardEntryReturn.Cashback = 0) and GlobalPosCardEntryReturn."Authorisation Ok" then
                        ready := true;
                until (GlobalPosCardEntryReturn.Next() = 0) or ready;
            POSSession.SetValue('KINPOSAUTHRETURN', '');

            if ready then
                POSGUI.OpenNumericKeyboard(Text003, 0, '', 0, 'KINPOSRETURN');
        end;

    end;

    /// <summary>
    /// Create POS Card Entry Default for Return Sale
    /// </summary>
    /// <param name="pStore No.">No of Store</param>
    /// <param name="pPOS Terminal No.">Terminal of Store</param>
    /// <param name="pTransaction No.">No. of transaction</param>
    /// <param name="pReceipt No.">Receipt No.</param>
    /// <param name="pTender Type">Tender Type</param>
    /// <param name="pAmount">Amount</param>
    local procedure CreatePOSCardEntryDefault("pStore No.": code[10]; "pPOS Terminal No.": Code[10]; "pTransaction No.": Integer; "pReceipt No.": Code[20]; "pTender Type": Code[10]; pAmount: Decimal)
    var
        POSCardEntry: Record "LSC POS Card Entry";
    begin
        POSCardEntry.Init();
        POSCardEntry."Store No." := "pStore No.";
        POSCardEntry."POS Terminal No." := "pPOS Terminal No.";
        POSCardEntry."Transaction No." := "pTransaction No.";
        POSCardEntry."Receipt No." := "pReceipt No.";
        POSCardEntry."Tender Type" := "pTender Type";
        POSCardEntry.Amount := pAmount;
        POSCardEntry."Entry No." := 0;
        POSCardEntry."Line No." := 40000;
        POSCardEntry."Auth.code" := '000000';
        POSCardEntry."EFT Batch No." := 'STORE';
        POSCardEntry."FSN Print Amount" := pAmount;
        POSCardEntry."FSN BIN No." := '000000';
        if not POSCardEntry.Insert(True) then
            POSCardEntry.Modify(true);
    end;

    procedure CreateLinkPosCardEntryReturnSale(pNewLine: Record "LSC POS Trans. Line"; CurrentInput: Text; POSSTATE: Text[50]; pHeader: Record "LSC POS Transaction")
    var
        PosCardEntry_l: Record "LSC POS Card Entry";
        PosCardEntryReturn_l: Record "LSC POS Card Entry";
        PostedDelOrder_l: Record "LSC Posted Delivery Order";
        _ReturnExit: Boolean;
        lErrorText: Text;
        result: Action;
        lText008: Label 'Original authorization number:';
        lText009: Label 'Authorization number not match';
        lText010: Label 'Records not exists in POS Card Entry. or Already return';
        lText011: Label 'NO automatic return will be sent to POS SERFINSA. Transaction Date is% 1';
    begin

        _ReturnExit := FALSE;
        if TenderTypeSetup.Get(pNewLine.Number) then
            if TenderTypeSetup."FSN Function in CC" <> TenderTypeSetup."FSN Function in CC"::Card then
                exit;

        IF pHeader."Sale Is Return Sale" THEN BEGIN
            PosCardEntry_l.RESET;
            PosCardEntry_l.SETCURRENTKEY("Store No.", "POS Terminal No.", "Receipt No.");
            PosCardEntry_l.SETRANGE(PosCardEntry_l."Store No.", pHeader."Retrieved from Store No.");
            PosCardEntry_l.SETRANGE(PosCardEntry_l."POS Terminal No.", pHeader."Retrieved from POS Term. No.");
            PosCardEntry_l.SETRANGE(PosCardEntry_l."Transaction No.", pHeader."Retrieved from Trans. No.");
            PosCardEntry_l.SETRANGE(PosCardEntry_l."Receipt No.", pHeader."Retrieved from Receipt No.");
            PosCardEntry_l.SETRANGE(PosCardEntry_l."Tender Type", pNewLine.Number);
            PosCardEntry_l.SETRANGE(PosCardEntry_l.Amount, pNewLine.Amount);
            //parche 11/01/2023
            if not PosCardEntry_l.find('-') then
                CreatePOSCardEntryDefault(pHeader."Retrieved from Store No.", pHeader."Retrieved from POS Term. No.", pHeader."Retrieved from Trans. No.", pHeader."Retrieved from Receipt No.", pNewLine.Number, pNewLine.Amount);

            IF PosCardEntry_l.find('-') THEN
                REPEAT
                    IF (PosCardEntry_l.Cashback = 0) or not PosCardEntry_l."MSR input" THEN BEGIN
                        GlobalPosCardEntryReturn.Copy(PosCardEntry_l);

                        if (PosCardEntry_l."Transaction Type" = PosCardEntry_l."Transaction Type"::" ") AND
                            (POSSession.GetValue('#INACTIVE_KINPOS') = 'AUTOMATIC') and
                            PosCardEntry_l."MSR input" AND PosCardEntry_l."Authorisation Ok" then begin

                            IF TODAY <> PosCardEntry_l.Date THEN
                                POSGUI.PosMessage((STRSUBSTNO(lText011, FORMAT(PosCardEntry_l.Date))))
                            ELSE begin

                                if POSSession.GetValue('KINPOSAUTHRETURN') <> PosCardEntry_l."Auth.code" THEN BEGIN
                                    pNewLine.VoidLine();
                                    COMMIT;
                                    ERROR(lText009);
                                END;
                                IF NOT POSCardIntegration.KinPosSendVoidRequest(lErrorText, pNewLine, PosCardEntry_l) THEN BEGIN
                                    pNewLine.VoidLine();
                                    COMMIT;
                                    ERROR(lErrorText);
                                END ELSE BEGIN
                                    PosCardEntry_l.Cashback := PosCardEntry_l.Amount;
                                    PosCardEntry_l.MODIFY(TRUE);
                                    exit;
                                END;

                            END;
                        END;
                        Clear(PosCardEntryReturn_l);
                        PosCardEntryReturn_l.INIT();
                        PosCardEntryReturn_l.TRANSFERFIELDS(PosCardEntry_l);
                        PosCardEntryReturn_l."MSR input" := FALSE;
                        PosCardEntryReturn_l."Authorisation Ok" := FALSE;
                        PosCardEntryReturn_l."Res.code" := '';
                        PosCardEntryReturn_l."Transaction Type" := PosCardEntryReturn_l."Transaction Type"::"Void Refund";
                        PosCardEntryReturn_l."Store No." := pNewLine."Store No.";
                        PosCardEntryReturn_l."POS Terminal No." := pNewLine."POS Terminal No.";
                        PosCardEntryReturn_l."Transaction No." := 0;
                        PosCardEntryReturn_l.Date := TODAY;
                        PosCardEntryReturn_l.Time := TIME;
                        PosCardEntryReturn_l."Receipt No." := pNewLine."Receipt No.";
                        PosCardEntryReturn_l."Line No." := pNewLine."Line No.";
                        PosCardEntryReturn_l."Entry No." := POSCardIntegration.NextEntryNo(PosCardEntryReturn_l."Store No.", PosCardEntryReturn_l."POS Terminal No.");
                        _ReturnExit := PosCardEntryReturn_l.INSERT(TRUE);

                        PosCardEntry_l.Cashback := PosCardEntry_l.Amount;
                        PosCardEntry_l.MODIFY(TRUE);
                    END;
                UNTIL (PosCardEntry_l.NEXT = 0) OR _ReturnExit
            ELSE
                ERROR(lText010);

            IF NOT _ReturnExit THEN begin
                pNewLine.VoidLine();
                ERROR(lText010);
            end;

            EXIT;
        END;

    end;

    procedure CreateLinkPosCardEntrySale(pNewLine: Record "LSC POS Trans. Line"; CurrentInput: Text; POSSTATE: Text[50]; pHeader: Record "LSC POS Transaction")
    var
        PosCardEntry_l: Record "LSC POS Card Entry";
        PosCardEntryTmp: Record "LSC POS Card Entry" temporary;
        TenderSetup_l: Record "LSC Tender Type Setup";
        _Next: Boolean;
        _KinPosUsed: Boolean;
        BINExists: Boolean;
        lErrorText: Text;
        CardExists: Option Nothing,WithoutAuthorization;
        Keyl: Text;
    begin
        Clear(lErrorText);
        Clear(CardExists);

        BINExists := FALSE;
        IF (pNewLine."Entry Type" <> pNewLine."Entry Type"::Payment) OR (pNewLine.Amount = 0) OR
          (pNewLine."Entry Status" = pNewLine."Entry Status"::Voided) THEN
            EXIT;

        PosCardEntry_l.Reset();
        Clear(PosCardEntry_l);
        IF POSCardIntegration.GetLastRecord(PosCardEntry_l, pNewLine."Store No.", pNewLine."POS Terminal No.",
                                            pNewLine."Receipt No.", pNewLine."Line No.") then
            if PosCardEntry_l."Authorisation Ok" and (PosCardEntry_l.Amount = pNewLine.Amount) then
                exit
            else
                CardExists := CardExists::WithoutAuthorization;

        IF TenderSetup_l.GET(pNewLine.Number) THEN
            IF TenderSetup_l."FSN Function in CC" = TenderSetup_l."FSN Function in CC"::Card THEN BEGIN

                IF (POSSession.GetValue('#INACTIVE_KINPOS') = 'AUTOMATIC') THEN BEGIN
                    if not POSCardIntegration.ValidateTerms(POSSession.GetValue('#FORM_KINPOS_ID'), pNewLine, lErrorText) then begin
                        pNewLine.VoidLine();
                        POSSession.SetValue('#ERROR_PINPAD', 'ERROR');
                        COMMIT;
                        ERROR(lErrorText);
                    end;

                    _KinPosUsed := FALSE;
                    _Next := TRUE;
                    _KinPosUsed := POSCardIntegration.KinPosSendRequest(lErrorText, pNewLine, (CardExists = CardExists::WithoutAuthorization));

                    IF NOT _KinPosUsed THEN
                        WHILE _Next AND NOT _KinPosUsed DO BEGIN
                            IF POSGUI.PosConfirm(STRSUBSTNO(Text005, COPYSTR(lErrorText, 1, 150), Text004), FALSE) THEN BEGIN
                                SLEEP(5000);
                                _KinPosUsed := POSCardIntegration.KinPosSendRequest(lErrorText, pNewLine, (CardExists = CardExists::WithoutAuthorization))
                            END ELSE BEGIN
                                pNewLine.VoidLine();
                                POSSession.SetValue('#ERROR_PINPAD', 'ERROR');
                                COMMIT;
                                ERROR(Text011);
                            END;
                        END;

                    IF _KinPosUsed THEN BEGIN
                        SetPosManual(pHeader, TRUE);
                        EXIT;
                    END;
                END else begin
                    Keyl := POSSession.GetValue('KINPOSDATAMAN');
                    PosCardEntryTmp."Auth.code" := BOUTIL.SeparateCombinedValue(1, Keyl);
                    PosCardEntryTmp."EFT Transaction ID" := BOUTIL.SeparateCombinedValue(2, Keyl);
                    if Evaluate(PosCardEntryTmp."FSN Print Amount", PosCardEntryTmp."EFT Transaction ID") then;
                    PosCardEntryTmp."FSN BIN No." := BOUTIL.SeparateCombinedValue(3, Keyl);

                    Clear(PosCardEntry_l);
                    if POSCardIntegration.GetLastRecord(PosCardEntry_l, pNewLine."Store No.", pNewLine."POS Terminal No.", pNewLine."Receipt No.", pNewLine."Line No.") then begin
                        if PosCardEntry_l."Transaction No." = 0 then begin
                            if PosCardEntry_l."Authorisation Ok" then begin
                                POSSession.SetValue('KINPOSDATAMAN', '');
                                exit;
                            end;
                            PosCardEntry_l."Auth.code" := PosCardEntryTmp."Auth.code";
                            PosCardEntry_l."FSN Print Amount" := PosCardEntryTmp."FSN Print Amount";
                            PosCardEntry_l.Amount := pNewLine.Amount;
                            PosCardEntry_l."FSN BIN No." := PosCardEntryTmp."FSN BIN No.";
                            PosCardEntry_l.Modify(true);
                        end;
                    end;

                    POSCardIntegration.InitPOSCardEntryByPOSTransLine(pNewLine, pHeader, 'STORE');
                    POSCardIntegration.GetLastRecord(PosCardEntry_l, pNewLine."Store No.", pNewLine."POS Terminal No.", pNewLine."Receipt No.", pNewLine."Line No.");
                    PosCardEntry_l."Auth.code" := PosCardEntryTmp."Auth.code";
                    PosCardEntry_l."FSN Print Amount" := PosCardEntryTmp."FSN Print Amount";
                    PosCardEntry_l.Amount := pNewLine.Amount;
                    PosCardEntry_l."FSN BIN No." := PosCardEntryTmp."FSN BIN No.";
                    POSCardIntegration.UpdatePOSCardEntryByBIN(PosCardEntry_l, PosCardEntryTmp."FSN BIN No.");
                    PosCardEntry_l.Modify(true);
                    POSSession.SetValue('KINPOSDATAMAN', '');
                end;
            END;//BinBank

        SetPosManual(pHeader, TRUE);
    end;

    procedure AddServicesBeforeCOMMIT(Transaction: Record "LSC POS Transaction")
    var
        lPOSCardEntry: Record "LSC POS Card Entry";
    begin
        IF Transaction."Entry Status" = Transaction."Entry Status"::Voided THEN BEGIN
            lPOSCardEntry.RESET;
            lPOSCardEntry.SETRANGE(lPOSCardEntry."Store No.", Transaction."Store No.");
            lPOSCardEntry.SETRANGE(lPOSCardEntry."POS Terminal No.", Transaction."POS Terminal No.");
            lPOSCardEntry.SETRANGE(lPOSCardEntry."Receipt No.", Transaction."Retrieved from Receipt No.");
            lPOSCardEntry.MODIFYALL(lPOSCardEntry.Cashback, 0, true);

            lPOSCardEntry.RESET;
            lPOSCardEntry.SETRANGE(lPOSCardEntry."Store No.", Transaction."Store No.");
            lPOSCardEntry.SETRANGE(lPOSCardEntry."POS Terminal No.", Transaction."POS Terminal No.");
            lPOSCardEntry.SETRANGE(lPOSCardEntry."Receipt No.", Transaction."Receipt No.");
            lPOSCardEntry.SETRANGE(lPOSCardEntry."Transaction No.", 0);
            lPOSCardEntry.SetRange(lPOSCardEntry."Authorisation Ok", false);
            lPOSCardEntry.DELETEALL(true);
        END;
    end;

    procedure PosCardEntriesReport(pPOSTransaction: Record "LSC POS Transaction")
    var
        fechaCorte: DateFormula;
        fechaGuardar: Date;
    begin
        fechaGuardar := today;
        if Evaluate(fechaCorte, GlobalRec.Parameter) then
            fechaGuardar := CalcDate(fechaCorte, TODAY);
        POSCardIntegration.PrintCardEntryReport(fechaGuardar, pPOSTransaction."POS Terminal No.", 2);
        //POSCardIntegration.PrintCardEntryReport(TODAY, pPOSTransaction."POS Terminal No.", 2);
    end;

    procedure SetPosManual(pPOSTransacction: Record "LSC POS Transaction"; pActiveAutomatic: Boolean)
    var
        MessageStatus: Text[50];
        lParameters: Record "FSN Parameter";
    begin
        IF NOT lParameters.GET('KINPOS', pPOSTransacction."POS Terminal No.") THEN
            POSSession.SetValue('#INACTIVE_KINPOS', 'MANUAL')
        ELSE
            IF NOT lParameters.Activo THEN
                POSSession.SetValue('#INACTIVE_KINPOS', 'MANUAL')
            ELSE
                IF pActiveAutomatic THEN BEGIN
                    POSSession.SetValue('#INACTIVE_KINPOS', 'AUTOMATIC');
                END ELSE BEGIN
                    MessageStatus := 'AUTOMATIC';
                    IF POSSession.GetValue('#INACTIVE_KINPOS') = 'AUTOMATIC' THEN
                        MessageStatus := 'MANUAL';

                    IF NOT (GlobalRec.Command IN ['VOID_TR']) THEN BEGIN
                        IF POSGUI.PosConfirm(STRSUBSTNO(Text008, MessageStatus), TRUE) THEN
                            POSSession.SetValue('#INACTIVE_KINPOS', MessageStatus);
                    END ELSE
                        POSSession.SetValue('#INACTIVE_KINPOS', MessageStatus);
                END;
        ShowPosForm(pPOSTransacction, TRUE);
    end;

    procedure ShowPosForm(pPOSTransacction: Record "LSC POS Transaction"; pActiveDefault: Boolean)
    var
        lParameters: Record "FSN Parameter";
        IsManual: Boolean;
    begin
        POSSession.SetValue('KINPOSDATAMAN', '');
        POSSession.SetValue('KINPOSDATAMAN', '');
        Clear(IsManual);
        IsManual := POSCardIntegration.IsManualSetup();


        lParameters.RESET;
        lParameters.SETRANGE(lParameters.Grupo, 'KINPOSF');
        lParameters.SETCURRENTKEY(Grupo, Codigo);
        IF NOT lParameters.FINDFIRST THEN
            EXIT;

        if not IsManual then //Manual
            IF pActiveDefault OR (POSSession.GetValue('#INACTIVE_KINPOS') <> 'AUTOMATIC') THEN BEGIN
                POSSession.SetValue('#FORM_KINPOS_NAME', lParameters.Valor);
                POSSession.SetValue('#FORM_KINPOS_ID', lParameters.Codigo);
                POSSession.SetValue('#FORM_KINPOS_PLZO', '');
                EXIT;
            END;
        POSTransactionCU.LookUp(true, lParameters.Grupo, '');

    end;

    procedure ShowPosFormSelect(pPOSTransacction: Record "LSC POS Transaction"; pFromLookUp: Code[20])
    var
        LookRespCode: Code[20];
        lParameters: Record "FSN Parameter";
    begin

        LookRespCode := POSGUI.GetLookupKeyValue(pFromLookUp);
        IF LookRespCode = '' THEN
            EXIT;

        lParameters.GET(pFromLookUp, LookRespCode);
        IF lParameters.Descripcion = 'CONMILLA' THEN BEGIN
            PointsWSCardBanks(pPOSTransacction);
            lParameters.Reset();
            lParameters.SetRange(Grupo, 'KINPOSF');
            if lParameters.FindFirst() then;
            POSSession.SetValue('#FORM_KINPOS_NAME', lParameters.Valor);
            POSSession.SetValue('#FORM_KINPOS_ID', lParameters.Codigo);
            POSSession.SetValue('#FORM_KINPOS_PLZO', '');
            EXIT;
        END;

        POSSession.SetValue('#FORM_KINPOS_NAME', lParameters.Valor);
        POSSession.SetValue('#FORM_KINPOS_ID', lParameters.Codigo);

        if lParameters.Descripcion = 'PLZO' then
            POSGUI.OpenNumericKeyboard(Text001, 0, '3', 0, 'KINPOSPLZO')
        else
            POSSession.SetValue('#FORM_KINPOS_PLZO', '');

    end;
    /*
    local procedure ShowManual(POSLine: Record "LSC POS Trans. Line"; POSTrans: record "LSC POS Transaction")
    var
        PAGEProcessOnline: page "FSN Card Request Online";
        POSCardEntryl: Record "LSC POS Card Entry";
    begin
        if not ((POSLine."Entry Status" = POSLine."Entry Status"::" ") and (POSLine."Entry Type" = POSLine."Entry Type"::Payment)) then
            exit;

        RetailSetup.Get();
        if POSCardIntegration.GetLastRecord(POSCardEntryl, RetailSetup."Local Store No.", RetailSetup."Distribution Location", POSLine."Receipt No.", POSLine."Line No.") then begin
            PAGEProcessOnline.SetProcessAvaliable(true);
            PAGEProcessOnline.SetTableView(POSCardEntryl);
            PAGEProcessOnline.Run();
        end else
            POSGUI.PosMessage(Text002);
    end;*/

    procedure BlockDeleteTransData(pREC: Record "LSC POS Transaction"; var pErrorText: Text; var pExitOnly: Boolean; pParameters: Record "LSC POS Menu Line"): Boolean
    var
        lText001: Label 'Payment card online exists. Cant be delete transaction or Line';
        ParametersVar_l: Record "FSN Parameter";
        POSCardRequestEntry_l: Record "FSN POS Card Request Entry";
    begin
        IF pParameters.Command IN ['VOID_L', 'VOID'] THEN BEGIN
            POSCardRequestEntry_l.RESET;
            POSCardRequestEntry_l.SETCURRENTKEY("Receipt No.", "Line No.", "Cast Last Numbers", "Enter Input", "Response Web Ok");
            POSCardRequestEntry_l.SETRANGE(POSCardRequestEntry_l."Receipt No.", POSTransLine."Receipt No.");
            IF pParameters.Command = 'VOID_L' THEN
                POSCardRequestEntry_l.SETRANGE(POSCardRequestEntry_l."Line No.", POSTransLine."Line No.");

            POSCardRequestEntry_l.SETRANGE(POSCardRequestEntry_l."Response Web Ok", TRUE);
            IF POSCardRequestEntry_l.FINDFIRST THEN BEGIN
                IF NOT (ParametersVar_l.GET('DELTRANSSRF', 'OK') AND ParametersVar_l.Activo) THEN BEGIN
                    pErrorText := lText001;
                    pExitOnly := FALSE;
                    EXIT(FALSE);
                END;
            END;
        END;
        EXIT(TRUE);
    end;


    procedure PointsWSCardBanks(pPOSTransaction: Record "LSC POS Transaction")
    var
        POSCardIntegration: Codeunit "FSN POS Card Integration";
        lText001: Label 'Points: %1 \Amount $%2';
        pPoint: Decimal;
        pPointAmt: Decimal;
        pErrorText: Text;
    begin
        IF POSCardIntegration.KinPosSendPointsRequest(pPOSTransaction, pPointAmt, pPoint, pErrorText) THEN
            POSGUI.PosMessage(STRSUBSTNO(lText001, FORMAT(pPoint), FORMAT(pPointAmt)))
        ELSE
            POSGUI.PosMessage(pErrorText);
    end;

    procedure CheckCouponBINValid(ReceiptNo: Code[20]; BIN: Code[10]; var rCouponCode: Code[20]; var rCouponDescription: Text[50]): Boolean
    var
        CouponLines: Record "LSC POS Trans. Line";
        BINRestric: Record "FSN BIN Bank";
    begin
        CLEAR(rCouponCode);
        CLEAR(rCouponDescription);

        CouponLines.RESET;
        CouponLines.SETCURRENTKEY("Receipt No.", "Entry Type", "Entry Status");
        CouponLines.SETRANGE(CouponLines."Receipt No.", ReceiptNo);
        CouponLines.SETRANGE(CouponLines."Entry Type", CouponLines."Entry Type"::Coupon);
        CouponLines.SETRANGE(CouponLines."Entry Status", 0);
        IF CouponLines.FIND('-') THEN
            REPEAT
                BINRestric.RESET;
                BINRestric.SETCURRENTKEY("Coupon Code");
                BINRestric.SETRANGE(BINRestric."Coupon Code", CouponLines."Coupon Code");
                IF BINRestric.FIND('-') THEN BEGIN
                    BINRestric.SETRANGE(BINRestric."BIN/IIN", BIN);
                    IF NOT BINRestric.FIND('-') THEN BEGIN
                        rCouponCode := CouponLines."Coupon Code";
                        rCouponDescription := CouponLines.Description;
                        EXIT(FALSE);
                    END;
                END;
            UNTIL CouponLines.NEXT = 0;

        EXIT(TRUE);
    end;

    procedure CheckDataPaymentDeliverySend(pOrder: Code[20]; var pErrorText: Text[250]): Boolean
    var
        //POSTrans: Record "LSC POS Transaction";
        //Voucher: Record "LSC Voucher Entries";
        //Terminal: Record "LSC POS Terminal";
        //FASANIServerUtil: Codeunit "FSN Utility";
        //CountLines: Integer;
        POSLine: Record "LSC POS Trans. Line";
        Tender: Record "LSC Tender Type Setup";
        CardEntry: Record "LSC POS Card Entry";
        BOUTIL: Codeunit "LSC BO Utils";
        POSCardReqEntry: Record "FSN POS Card Request Entry";

        d: Integer;
        m: Integer;
        y: Integer;
        txt: Text;
        dec: Decimal;
        e: Integer;
    begin
        pErrorText := '';

        POSLine.RESET;
        POSLine.SETCURRENTKEY("Receipt No.", "Entry Type", "Entry Status");
        POSLine.SETRANGE(POSLine."Receipt No.", pOrder);
        POSLine.SETRANGE(POSLine."Entry Type", POSLine."Entry Type"::Payment);
        POSLine.SETRANGE(POSLine."Entry Status", 0);
        IF POSLine.FIND('-') THEN
            REPEAT
                Tender.GET(POSLine.Number);
                CASE Tender."FSN Function in CC" OF
                    Tender."FSN Function in CC"::Card:
                        BEGIN
                            if not POSCardIntegration.GetLastRecord(CardEntry, POSLine."Store No.", POSLine."POS Terminal No.", POSLine."Receipt No.", POSLine."Line No.") then
                                //IF NOT CardEntry.GET(POSLine."Store No.", POSLine."POS Terminal No.", POSLine."Receipt No.", POSLine."Line No.") THEN
                                pErrorText := Text003
                            ELSE
                                IF NOT CardEntry."Authorisation Ok" THEN BEGIN
                                    IF (CardEntry."Card Number" = '') OR (CardEntry."Expiry Date" = '')
                                      OR (CardEntry."FSN Bank Name" = '') OR (CardEntry."FSN Last Digits" = '') THEN
                                        pErrorText := Text003;

                                END ELSE BEGIN
                                    IF CardEntry."FSN Operation Name" <> '' THEN BEGIN
                                        txt := BOUTIL.SeparateCombinedValue(1, CardEntry."FSN Operation Name");
                                        EVALUATE(e, txt);
                                        txt := BOUTIL.SeparateCombinedValue(2, CardEntry."FSN Operation Name");
                                        EVALUATE(d, txt);
                                        txt := BOUTIL.SeparateCombinedValue(3, CardEntry."FSN Operation Name");
                                        EVALUATE(m, txt);
                                        txt := BOUTIL.SeparateCombinedValue(4, CardEntry."FSN Operation Name");
                                        EVALUATE(y, txt);

                                        IF POSCardReqEntry.GET(e, DMY2DATE(d, m, y), BOUTIL.SeparateCombinedValue(5, CardEntry."FSN Operation Name")) THEN BEGIN

                                            txt := POSCardReqEntry."Amount Input";
                                            IF EVALUATE(dec, txt) THEN
                                                IF STRPOS(POSCardReqEntry."Amount Input", '.') = 0 THEN
                                                    dec := dec / 100;

                                            IF dec <> CardEntry."FSN Print Amount" THEN
                                                pErrorText := STRSUBSTNO(Text017, FORMAT(dec), FORMAT(CardEntry."FSN Print Amount"));

                                        END;
                                    END;
                                END;
                        END;

                END;
            UNTIL POSLine.NEXT = 0;

        EXIT((pErrorText = ''));
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Post Utility", 'OnBeforeInsertPaymentEntry', '', true, true)]
    local procedure "LSC POS Post Utility_OnBeforeInsertPaymentEntry"
    (
        var POSTransaction: Record "LSC POS Transaction";
        var POSTransLine: Record "LSC POS Trans. Line";
        var TransPaymentEntry: Record "LSC Trans. Payment Entry"
    )
    var
        POSCardEntryl: Record "LSC POS Card Entry";
        TransactionHeaderLoc2: Record "LSC Transaction Header";
        NextNo: Integer;
    begin
        NextNo := TransPaymentEntry."Transaction No.";

        TransactionHeaderLoc2.Reset;
        TransactionHeaderLoc2.SetRange("Store No.", POSTransLine."Store No.");
        TransactionHeaderLoc2.SetRange("POS Terminal No.", POSTransLine."POS Terminal No.");
        if NextNo = 0 then
            if TransactionHeaderLoc2.FindLast then
                NextNo := TransactionHeaderLoc2."Transaction No." + 1
            else
                NextNo := 1;

        if TenderTypeSetup.Get(POSTransLine.Number) then
            if TenderTypeSetup."FSN Function in CC" = TenderTypeSetup."FSN Function in CC"::Card then begin
                POSCardIntegration.GetLastRecord(POSCardEntryl, POSTransLine."Store No.", POSTransLine."POS Terminal No."
                    , POSTransLine."Receipt No.", POSTransLine."Line No.");

                POSCardEntryl."Transaction No." := NextNo;
                POSCardEntryl.Modify(true);
            end
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Controller", 'OnNumpadResult', '', true, true)]
    local procedure "LSC POS Controller_OnNumpadResult"
    (
        payload: Text;
        inputValue: Text;
        resultOK: Boolean;
        var processed: Boolean
    )
    var
        PlzoInt: Integer;
        lErrorTxt: Text;
        PosTransLine: Record "LSC POS Trans. Line";
        PosCardEntryReturn: Record "LSC POS Card Entry";
        lText0: Label 'Authorization number not match';
    begin
        if payload = 'KINPOSPLZO' then begin
            IF EVALUATE(PlzoInt, inputValue) THEN
                IF PlzoInt IN [3, 6, 9] THEN
                    POSSession.SetValue('#FORM_KINPOS_PLZO', inputValue)
                else
                    POSGUI.OpenNumericKeyboard(Text001, 0, '3', 0, 'KINPOSPLZO');
            processed := true;
        end;

        if payload = 'KINPOSRETURN' then begin
            POSSession.SetValue('KINPOSAUTHRETURN', inputValue);
            processed := true;
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnAfterInsertPaymentLine', '', true, true)]
    local procedure "LSC POS Transaction Events_OnAfterInsertPaymentLine"
    (
        var POSTransaction: Record "LSC POS Transaction";
        var POSTransLine: Record "LSC POS Trans. Line";
        var CurrInput: Text;
        var TenderTypeCode: Code[10]
    )
    begin
        CreateLinkPosCardEntry(POSTransLine, CurrInput, 'PAYMENT', POSTransaction);
    end;


    //Callcenter
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Controller", 'OnButtonPressed', '', true, true)]
    local procedure "EPOS Controler_OnButtonPressed"
    (
        var POSMenuLine: Record "LSC POS Menu Line";
        var handled: Boolean
    )
    var
        PosCardEntry_l: Record "LSC POS Card Entry";
    begin
        //Confirm order
        if (POSMenuLine.Command = 'DEL-TAKEORDFUNC') and
            (POSMenuLine.Parameter = 'ORDER-CLOSEPANEL') then begin
            if POSSESSION.GetValue('CURRORDER') = '' then
                exit;

            if POSTransaction.Get(POSSESSION.GetValue('CURRORDER')) then begin
                POSCardIntegration.TransferInfoToPOSTransLine(POSTransaction);
            end;
        end;
        //Cancel order
        if (POSMenuLine.Command = 'TENDER_K') then begin
            if POSTransaction.Get(POSTransactionCU.GetReceiptNo()) then;
            if TenderTypeSetup.Get(POSMenuLine.Parameter) and (TenderTypeSetup."FSN Function in CC" = TenderTypeSetup."FSN Function in CC"::Card) then
                if (POSSession.GetValue('#INACTIVE_KINPOS') <> 'AUTOMATIC') then
                    if not POSCardIntegration.IsManualSetup() then
                        if not POSTransaction."Sale Is Return Sale" then
                            if (POSSession.GetValue('KINPOSDATAMAN') = '') then begin
                                POSGUI.PosMessage(Text006);
                                handled := true;
                            end;
        end;
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
        RequestInherit: Record "FSN POS Card Request Inherit";
    begin
        if RequestID = 'DEL-TRANSCARDFSN' then begin
            IF MsgResult <> 'ERROR' THEN begin
                if XMLRequest = '' then
                    exit;
                POSTransaction.Reset();
                POSTransaction.SetRange("Receipt No.", XMLRequest);
                if POSTransaction.Find('-') then begin
                    POSCardIntegration.TransferInfoToPOSTransLine(POSTransaction);
                end;
            end;
        end;
        if RequestID = 'DEL-CANCELCARD' then begin
            IF MsgResult <> 'ERROR' THEN begin
                POSTransaction.Reset();
                POSTransaction.SetRange("Receipt No.", XMLRequest);
                if POSTransaction.Find('-') then begin
                    RequestInherit.SetRange("Receipt No. Inherit", XMLRequest);
                    RequestInherit.SetRange("Store No. Inherit", POSTransaction."Store No.");
                    if RequestInherit.FindFirst() then
                        RequestInherit.Delete(true);
                    if TenderTypeSetup.Get(POSMenuLine.Parameter) and (TenderTypeSetup."FSN Function in CC" = TenderTypeSetup."FSN Function in CC"::Card) then
                        if (POSSession.GetValue('#INACTIVE_KINPOS') <> 'AUTOMATIC') then
                            if not POSCardIntegration.IsManualSetup() then
                                if not POSTransaction."Sale Is Return Sale" then
                                    if (POSSession.GetValue('KINPOSDATAMAN') = '') then begin
                                        POSGUI.PosMessage(Text006);
                                    end;
                end;
            END;
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Controller", 'OnModalPanelResult', '', true, true)]
    local procedure "LSC POS Controller_OnModalPanelResult"
    (
        panelID: Text;
        resultOK: Boolean;
        payload: Text;
        var processed: Boolean
    )
    var
        PosInterface: Codeunit "LSC POS Control Interface";
        recRef: RecordRef;
        poscardEntryTmp: Record "LSC POS Card Entry" temporary;
        poscardEntryTmp2: Record "LSC POS Card Entry" temporary;
    begin
        if not ((panelID = '#DEL-VOUCHER') and (payload = 'VOUCHERDATA')) then
            exit;

        poscardEntryTmp.Reset();
        poscardEntryTmp.Init();
        recRef.GetTable(poscardEntryTmp);
        PosInterface.GetRecordZoomData(recRef, '#VOUCHERDATA');
        poscardEntryTmp2."Auth.code" := recRef.Field(poscardEntryTmp.FieldNo("Auth.code")).Value;
        poscardEntryTmp2."FSN Print Amount" := recRef.Field(poscardEntryTmp.FieldNo("FSN Print Amount")).Value;
        poscardEntryTmp2."FSN BIN No." := recRef.Field(poscardEntryTmp.FieldNo("FSN BIN No.")).Value;

        if (poscardEntryTmp2."Auth.code" <> '') and (poscardEntryTmp2."FSN Print Amount" <> 0) and
            (poscardEntryTmp2."FSN BIN No." <> '') then
            POSSession.SetValue('KINPOSDATAMAN',
                BOUTIL.CombineValue(3, Format(recRef.Field(poscardEntryTmp.FieldNo("Auth.code")).Value)
                                    , Format(recRef.Field(poscardEntryTmp.FieldNo("FSN Print Amount")).Value)
                                    , Format(recRef.Field(poscardEntryTmp.FieldNo("FSN BIN No.")).Value)
                                    , '', ''))
        else begin
            POSSession.SetValue('KINPOSDATAMAN', '');
            POSGUI.PosMessage(Text012);
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC Hospitality POS Startup", 'OnAfterExecuteCommand', '', true, true)]
    local procedure "LSC Hospitality POS Startup_OnAfterExecuteCommand"
    (
    MenuLine: Record "LSC POS Menu Line";
    CurrentReceipt: Code[20];
    var HospitalityTypeTemp: Record "LSC Hospitality Type";
    ActiveDiningArea: Record "LSC Dining Area";
    ActiveServiceFlow: Record "LSC Hospitality Service Flow"
    )
    begin
        if MenuLine.Command in ['HOSP-ORDEREDIT', 'DELEDIT'] then
            if GlobalRec."Current-RECEIPT" <> '' then
                POSCardIntegration.TransformInfoToPosCardEntry(GlobalRec."Current-RECEIPT")
            else
                if (POSSESSION.GetValue('CURRORDER') <> 'NEWSALE') then
                    POSCardIntegration.TransformInfoToPosCardEntry(POSSESSION.GetValue('CURRORDER'));

        /* if MenuLine.Command IN ['START', 'SUSPEND'] then begin
            if POSTransaction.Get(MenuLine."Current-RECEIPT") then;
            SetPosManual(POSTransaction, TRUE);
        end; */

    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Controller", 'OnPOSEvent', '', true, true)]
    local procedure "LSC POS Controller_OnPOSEvent"
        (
        var PosEvent: Codeunit "LSC POS Event";
        var SuppressEvent: Boolean
        )
    var
        POSLines: Codeunit "LSC POS Trans. Lines";
        POSLine_l: Record "LSC POS Trans. Line";
        PAGEProcessOnline: page "FSN Card Request Online";
        POSCardEntryl: Record "LSC POS Card Entry";
        RetailSetup: Record "LSC Retail Setup";
        VoucherManualView: Page "FSN Card Request Online View";
        OfflineCCFunc: Codeunit "LSC Offl. CC Functions";
        PosTransaction: Codeunit "LSC POS Transaction";
        ParameterFSN: Record "FSN Parameter";
    begin
        if PosEvent.ActivePanel = '#POS' THEN
            if PosEvent.EventType in [
                Enum::"LSC POS Event Type"::DATAROWDOUBLECLICK
            ] then begin
                POSLines.GetCurrentLine(POSLine_l);
                if (POSLine_l."Entry Type" = POSLine_l."Entry Type"::Payment) AND
                    (POSLine_l."Entry Status" = POSLine_l."Entry Status"::" ") THEN begin

                    RetailSetup.Get();
                    if POSCardIntegration.GetLastRecord(POSCardEntryl, POSLine_l."Store No.", POSLine_l."POS Terminal No.", POSLine_l."Receipt No.", POSLine_l."Line No.") then begin
                        IF ParameterFSN.Get('KINPOS', RetailSetup."Local Store No.") THEN begin
                            IF ParameterFSN.Descripcion = 'MANUAL' THEN begin
                                PAGEProcessOnline.SetProcessAvaliable(true);
                                PAGEProcessOnline.SetTableView(POSCardEntryl);
                                PAGEProcessOnline.RunModal();
                                SuppressEvent := true;
                            end;
                        end else begin
                            IF ParameterFSN.Get('KINPOS', POSLine_l."POS Terminal No.") THEN begin
                                IF ParameterFSN.Descripcion <> 'MANUAL' THEN begin
                                    POSCardEntryl.Reset();
                                    POSCardEntryl.SetRange(POSCardEntryl."Receipt No.", PosTransaction.GetReceiptNo());
                                    if POSCardEntryl.FindFirst() then begin
                                        if not OfflineCCFunc.CallCenterOffline(POSCardEntryl."Store No.") then begin
                                            VoucherManualView.SETRECORD(POSCardEntryl);
                                            VoucherManualView.LOOKUPMODE(true);
                                            VoucherManualView.RUNMODAL;
                                        end else
                                            POSGUI.PosMessage(Text002);
                                    end else
                                        POSGUI.PosMessage(Text002);
                                end;
                            end;
                        end;
                    end;
                end;
            end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnBeforeTotalExecuted', '', true, true)]
    local procedure "LSC POS Transaction Events_OnBeforeTotalExecuted"
    (
     var POSTransaction: Record "LSC POS Transaction";
     var IsHandled: Boolean
    )
    var
        TransLine: Record "LSC POS Trans. Line";
        POSCardEntryl: Record "LSC POS Card Entry";
        DeliveryOrder: Record "LSC Delivery Order";
        lText000: Label 'Código de Autorización no puede ser vacío para media de pago Tarjeta.';
        VTenderTypeSetup: Record "LSC Tender Type Setup";
        VCardTransLine: Record "LSC POS Trans. Line";
        POSCardIn: Codeunit "FSN POS Card Integration";
        tray: Integer;
    begin
        VCardTransLine.Reset();
        VCardTransLine.SetRange("Receipt No.", POSTransaction."Receipt No.");
        VCardTransLine.SetRange("Entry Type", VCardTransLine."Entry Type"::Payment);
        VCardTransLine.SetFilter(VCardTransLine."Entry Status", '<>%1', VCardTransLine."Entry Status"::Voided);
        if VCardTransLine.Find('-') then begin
            repeat
                if VTenderTypeSetup.Get(VCardTransLine.Number) and (VTenderTypeSetup."FSN Function in CC" = VTenderTypeSetup."FSN Function in CC"::Card) then
                    POSCardIntegration.TransformInfoToPosCardEntry(POSTransaction."Receipt No.");
            until VCardTransLine.Next() = 0;
        end;

        if not IsHandled then
            if DeliveryOrder.Get(POSTransaction."Receipt No.") then begin
                POSCardEntryl.Reset();
                POSCardEntryl.SetRange("Receipt No.", DeliveryOrder."Order No.");
                if POSCardEntryl.Find('-') then
                    repeat
                        TransLine.Reset();
                        TransLine.SetRange("Receipt No.", POSCardEntryl."Receipt No.");
                        TransLine.SetRange("Line No.", POSCardEntryl."Line No.");
                        TransLine.SetRange("Entry Type", TransLine."Entry Type"::Payment);
                        TransLine.SetFilter(TransLine."Entry Status", '<>%1', TransLine."Entry Status"::Voided);
                        if TransLine.FindFirst() then begin
                            if TenderTypeSetup.Get(TransLine.Number) and (TenderTypeSetup."FSN Function in CC" = TenderTypeSetup."FSN Function in CC"::Card) then
                                if (POSCardEntryl."Auth.code" = '') then begin
                                    IsHandled := true;
                                    Message(lText000);
                                end else begin
                                    if TransLine."Entry Status" = TransLine."Entry Status"::" " then begin
                                        tray := 2;
                                        if POSSession.GetValue('FSNPRINTVOUCHER') = '1' then begin
                                            POSCardIn.PrintCardVoucher(POSCardEntryl, TransLine."Receipt No.", false, false, tray);
                                            POSSession.SetValue('FSNPRINTVOUCHER', '0');
                                        end;
                                    end;
                                end;
                        end;
                    until POSCardEntryl.Next() = 0;
            end;

    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnAfterRunCommand', '', true, true)]
    local procedure "LSC POS Transaction Events_OnAfterRunCommand"
    (
        var POSTransaction: Record "LSC POS Transaction";
        var POSTransLine: Record "LSC POS Trans. Line";
        var CurrInput: Text;
        var Command: Code[20];
        var POSMenuLine: Record "LSC POS Menu Line"
    )
    begin
        if POSMenuLine.Command IN ['START', 'SUSPEND'] then begin
            if POSTransaction.Get(POSMenuLine."Current-RECEIPT") then;
            SetPosManual(POSTransaction, TRUE);
        end;
    end;

    [EventSubscriber(ObjectType::Table, Database::"LSC POS Card Entry", 'OnBeforeModifyEvent', '', true, true)]
    local procedure "LSC POS Card Entry_OnBeforeModifyEvent"
    (
        var Rec: Record "LSC POS Card Entry";
        var xRec: Record "LSC POS Card Entry";
        RunTrigger: Boolean
    )
    begin
        if Rec.Date <> Today then
            Rec.Date := Today;
    end;


    [EventSubscriber(ObjectType::Table, Database::"LSC POS Card Entry", 'OnBeforeInsertEvent', '', true, true)]
    local procedure "LSC POS Card Entry_OnBeforeInsertEvent"
    (
        var Rec: Record "LSC POS Card Entry";
        RunTrigger: Boolean
    )
    begin
        if Rec.Date <> Today then
            Rec.Date := Today;
    end;
}
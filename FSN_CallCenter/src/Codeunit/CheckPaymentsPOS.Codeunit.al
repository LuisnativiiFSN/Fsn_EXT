codeunit 50021 "FSN Check Payments POS"
{

    trigger OnRun()
    begin
    end;

    var
        Text001: Label '%1 Not exists, Value %2';
        Text002: Label 'Vertify payments';
        Text003: Label 'Check data card payments';
        Text004: Label 'Member point %1 are not enough for payment %2';
        Text005: Label 'Mixto';
        Text006: Label 'Limit Amount for delivery is $%1';
        Text007: Label 'Limit Amount for delivery cross transaction is $%1';
        Text008: Label 'Store delivery %1 and store Transac %2 no match';
        Text009: Label 'Amount in cross orders for contact ($ %1) is less to allowed $( %2)';
        Text010: Label 'Changes in transaction require recalc payment';
        Text011: Label 'Transaction have payments Online. %1';
        Text012: Label 'Transaction have balance pending.';
        Text013: Label 'Data Entry linked to total discount not exists.';
        Text014: Label 'Total Discount is %1 not match entry data amount %2';
        Text015: Label 'PAY: %1 %2 %3';
        Text016: Label 'Change $%1 for $%2';
        Text017: Label 'Real value Vaucher is %1 and Payment line is %2';
        Text018: Label 'User %1 not privilegies of manager';
        Text019: Label 'Error in credentials %1';
        POSSESSION: Codeunit "LSC POS Session";
        POSGUI: Codeunit "LSC POS GUI";
        POSView: Codeunit "LSC POS View";
        RetailSetup: Record "LSC Retail Setup";
        ePOSControlInterface: Codeunit "LSC POS Control Interface";
        DeliveryOrderManagement: Codeunit "LSC Delivery Order Management";
        FSNUtility: Codeunit "FSN Utility";
        gTextRetCusGrp: Label 'COMODIN';

    procedure CheckDataPaymentDeliverySend(pOrder: Code[20]; var pErrorText: Text[250]): Boolean
    var
        POSTrans: Record "LSC POS Transaction";
        POSLine: Record "LSC POS Trans. Line";
        Tender: Record "LSC Tender Type Setup";
        CardEntry: Record "LSC POS Card Entry";
        Voucher: Record "LSC Voucher Entries";
        Terminal: Record "LSC POS Terminal";
        FASANIServerUtil: Codeunit "FSN Utility";
        CountLines: Integer;
        BOUTIL: Codeunit "LSC BO Utils";
        POSCardReqEntry: Record "FSN POS Card Request Entry";
        d: Integer;
        m: Integer;
        y: Integer;
        txt: Text;
        dec: Decimal;
        e: Integer;
        posTransInfocodeEntry: Record "LSC POS Trans. Infocode Entry";
        TEXTv000: label 'Media de pago EFECTIVO DOMICILIO debe de obtener una sala asignada, \\ Debe anular line de media de pago y volverla agregar para asignar sala.';
    begin
        pErrorText := '';

        POSLine.RESET;
        POSLine.SETCURRENTKEY("Receipt No.", "Entry Type", "Entry Status");
        POSLine.SETRANGE("Receipt No.", pOrder);
        POSLine.SETRANGE("Entry Type", POSLine."Entry Type"::Payment);
        POSLine.SETRANGE("Entry Status", 0);
        POSLine.SETRANGE(POSLine.Number, '21');
        IF POSLine.FINDFIRST THEN BEGIN
            posTransInfocodeEntry.Reset();
            posTransInfocodeEntry.SetCurrentKey("Receipt No.", "Transaction Type", "Line No.", Infocode);
            posTransInfocodeEntry.SetRange("Receipt No.", POSLine."Receipt No.");
            posTransInfocodeEntry.SetRange(posTransInfocodeEntry."Transaction Type", posTransInfocodeEntry."Transaction Type"::"Payment Entry");
            posTransInfocodeEntry.SetRange(posTransInfocodeEntry."Line No.", POSLine."Line No.");
            posTransInfocodeEntry.SetRange(posTransInfocodeEntry.Infocode, 'OREFECT');
            if NOT posTransInfocodeEntry.FindFirst() then begin
                Error(TEXTv000);
                EXIT(FALSE);
            end;
        END;

        POSLine.RESET;
        POSLine.SETCURRENTKEY("Receipt No.", "Entry Type", "Entry Status");
        POSLine.SETRANGE("Receipt No.", pOrder);
        POSLine.SETRANGE("Entry Type", POSLine."Entry Type"::Payment);
        POSLine.SETRANGE("Entry Status", 0);
        POSLine.SETRANGE(POSLine."FSN Additional Action", POSLine."FSN Additional Action"::ConfirmPayment);
        IF POSLine.FINDFIRST THEN BEGIN
            pErrorText := Text010;
            EXIT(FALSE);
        END;

        CardEntry.RESET;
        CardEntry.SETRANGE(CardEntry."Receipt No.", pOrder);
        CardEntry.MODIFYALL(CardEntry."Replication Counter", 0);

        IF NOT ValidateGiftMixTotalDiscount(pOrder, pErrorText) THEN
            EXIT(FALSE);

        IF NOT POSTrans.GET(pOrder) THEN BEGIN
            pErrorText := STRSUBSTNO(Text001, POSTrans.TABLECAPTION, pOrder);
            EXIT(FALSE);
        END;

        POSTrans.CALCFIELDS(POSTrans."Gross Amount", POSTrans.Payment, POSTrans."Line Discount", POSTrans."Total Discount", POSTrans."Income/Exp. Amount");
        IF ((POSTrans."Gross Amount" + POSTrans."Line Discount" + POSTrans."Income/Exp. Amount") -
            (POSTrans."Line Discount" + POSTrans.Payment)) <> 0 THEN BEGIN
            pErrorText := Text002;
            EXIT(FALSE);
        END;

        IF Terminal.GET(POSTrans."POS Terminal No.") THEN BEGIN

            CASE TRUE OF
                POSLine.GET(pOrder, 33) AND
              (POSLine."Entry Type" = POSLine."Entry Type"::FreeText) AND
              (POSLine."Entry Status" = 0):
                    POSTrans."FSN No. Serie NCF" := Terminal."FSN No. Serie Credito Fiscal";

                POSLine.GET(pOrder, 32) AND
              (POSLine."Entry Type" = POSLine."Entry Type"::FreeText) AND
              (POSLine."Entry Status" = 0):
                    POSTrans."FSN No. Serie NCF" := Terminal."FSN No. Serie NCF Cons. Final";
            END;

            POSTrans.CalcFields("Gross Amount");
            IF POSTrans."Gross Amount" <> 0 THEN BEGIN
                IF NOT FASANIServerUtil.ValidateTypeDocumentAndCustom(POSTrans,
                    (POSTrans."Gross Amount" + POSTrans."Income/Exp. Amount"), pErrorText, TRUE) THEN
                    EXIT(FALSE);
            END;

        END;

        POSLine.RESET;
        POSLine.SETCURRENTKEY("Receipt No.", "Entry Type", "Entry Status");
        POSLine.SETRANGE(POSLine."Receipt No.", POSTrans."Receipt No.");
        POSLine.SETRANGE(POSLine."Entry Type", POSLine."Entry Type"::Payment);
        POSLine.SETRANGE(POSLine."Entry Status", 0);
        IF POSLine.FIND('-') THEN
            REPEAT
                Tender.GET(POSLine.Number);
                CASE Tender."FSN Function in CC" OF
                    Tender."FSN Function in CC"::Card:
                        BEGIN
                            /* IF NOT CardEntry.GET(POSLine."Store No.", POSLine."POS Terminal No.", POSLine."Receipt No.", POSLine."Line No.") THEN
                                 pErrorText := Text003
                             ELSE
                                 IF NOT CardEntry."Authorisation Ok" THEN BEGIN
                                     IF (CardEntry."Card Number" = '') OR (CardEntry."Expiry Date" = '')
                                       OR (CardEntry."FSN Bank Name" = '') OR (CardEntry."FSN Last Digits" = '') THEN
                                         pErrorText := Text003;

                                 END ELSE BEGIN //WVILLALTA 02.20-
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
                                 END;           //WVILLALTA 02.20+
                                 */
                        END;
                    Tender."FSN Function in CC"::Member:
                        BEGIN
                            IF POSLine."Amount In Currency" > POSTrans."Starting Point Balance" THEN
                                pErrorText := STRSUBSTNO(Text004, FORMAT(POSLine."Amount In Currency"), FORMAT(POSTrans."Starting Point Balance"));
                        END;
                END;
                //Normal,Card,Check,Change,Member
                IF POSLine.Number = '25' THEN BEGIN   //WVLLALTA 04.21-
                    IF NOT Voucher.GET(POSLine."Store No.", POSLine."POS Terminal No.", 0, POSLine."Line No.", POSLine."Receipt No.") THEN
                        pErrorText := STRSUBSTNO(Text017, '0', FORMAT(POSLine.Amount))
                    ELSE
                        IF POSLine.Amount <> Voucher.Amount THEN
                            pErrorText := STRSUBSTNO(Text017, FORMAT(Voucher.Amount), FORMAT(POSLine.Amount));
                END;                                  //WVLLALTA 04.21-
            UNTIL POSLine.NEXT = 0;

        EXIT((pErrorText = ''));
    end;

    procedure CheckTotalAmountDeliverySetup(OrderNo: Code[20]; var pMsgError: Text[250]): Boolean
    var
        pDelOrder: Record "LSC Delivery Order";
        DelOrders: Record "LSC Delivery Order";
        FasaniSetup: Record "FSN Fasani Setup";
        AmtSums: Decimal;
        DeliveryTripTMP: Record "FSN Delivery Trip" temporary;
        CurrAmt: Decimal;
        MyStoreAmt: Decimal;
        OtherStoreAmt: Decimal;
        NumberOrderStore: Integer;
        NumberOrderOtherStore: Integer;
        NewTotal: Decimal;
        NewSubTotal: Decimal;
        NewPayments: Decimal;
        NewBalance: Decimal;
        TenderName: Text[50];
        POSLine: Record "LSC POS Trans. Line";
        WSTable: Record "FSN WebServiceTable";
    begin
        if not pDelOrder.Get(OrderNo) then
            exit;

        CLEAR(pMsgError);

        DeliveryTripTMP.RESET;
        DeliveryTripTMP.DELETEALL;
        CLEAR(DeliveryTripTMP);
        IF NOT FasaniSetup.GET(pDelOrder."Restaurant No.") THEN
            EXIT(TRUE);

        CurrAmt := 0;
        AmtSums := 0;
        MyStoreAmt := 0;
        OtherStoreAmt := 0;
        NumberOrderStore := 0;
        NumberOrderOtherStore := 0;

        POSLine.RESET;
        POSLine.SETCURRENTKEY("Receipt No.", "Entry Type", "Entry Status");
        POSLine.SETRANGE("Receipt No.", pDelOrder."Order No.");
        POSLine.SETRANGE("Entry Type", POSLine."Entry Type"::Item);
        POSLine.SETRANGE("Entry Status", 0);
        IF POSLine.COUNT = 1 THEN BEGIN
            POSLine.SETRANGE(POSLine.Number, '70107');
            IF POSLine.FINDFIRST THEN
                EXIT(TRUE);
        END;

        DelOrders.RESET;
        DelOrders.SETCURRENTKEY("Phone No.");
        DelOrders.SETRANGE(DelOrders."Phone No.", pDelOrder."Phone No.");
        DelOrders.SETFILTER(DelOrders."General Status", '<>%1', pDelOrder."General Status"::Cancelled);
        IF DelOrders.FINDSET THEN
            REPEAT
                LoadContextPaymentsDelivery(NewTotal, NewSubTotal, NewPayments, NewBalance, TenderName, DelOrders);

                AmtSums += NewPayments;
                DeliveryTripTMP."Order Amount" := NewPayments;
                DeliveryTripTMP."Order No." := DelOrders."Order No.";
                DeliveryTripTMP."Store No." := DelOrders."Restaurant No.";
                IF DeliveryTripTMP.INSERT THEN;

                IF DelOrders."Order No." = pDelOrder."Order No." THEN
                    CurrAmt := NewPayments;

            UNTIL DelOrders.NEXT = 0;

        IF WSTable.GET(pDelOrder."Order No.") THEN BEGIN
            IF (WSTable.Store IN ['APP', 'EC']) AND (CurrAmt >= 12.0) THEN //Static
                EXIT(TRUE);
        END;

        IF (CurrAmt = 0) OR
           (CurrAmt >= FasaniSetup."Amount Delivery") OR
           (FasaniSetup."Amt. Override Delivery" <= AmtSums) THEN
            EXIT(TRUE);


        DeliveryTripTMP.RESET;
        DeliveryTripTMP.SETRANGE(DeliveryTripTMP."Store No.", pDelOrder."Restaurant No.");
        NumberOrderStore := DeliveryTripTMP.COUNT;
        DeliveryTripTMP.CALCSUMS("Order Amount");
        MyStoreAmt := DeliveryTripTMP."Order Amount";

        DeliveryTripTMP.RESET;
        DeliveryTripTMP.SETFILTER(DeliveryTripTMP."Store No.", '<>%1', pDelOrder."Restaurant No.");
        NumberOrderOtherStore := DeliveryTripTMP.COUNT;
        DeliveryTripTMP.CALCSUMS("Order Amount");
        OtherStoreAmt := DeliveryTripTMP."Order Amount";

        IF CheckCustomPayTrip(pDelOrder) AND
          ((CurrAmt + 0.01) >= 8) THEN //Static
            EXIT(TRUE);

        IF MyStoreAmt >= FasaniSetup."Amount Delivery" THEN
            EXIT(TRUE);

        IF (MyStoreAmt >= FasaniSetup."Amount Cross Delivery") AND
          (NumberOrderOtherStore > 0) AND
          ((FasaniSetup."Amount Delivery" + FasaniSetup."Amount Cross Delivery") <= AmtSums) THEN
            EXIT(TRUE);

        IF ((FasaniSetup."Amount Delivery" + FasaniSetup."Amount Cross Delivery") > AmtSums) AND (NumberOrderOtherStore > 0) THEN
            pMsgError := STRSUBSTNO(Text009, FORMAT(AmtSums), FORMAT((FasaniSetup."Amount Delivery" + FasaniSetup."Amount Cross Delivery")))

        ELSE
            IF (NumberOrderOtherStore > 0) AND (CurrAmt < FasaniSetup."Amount Cross Delivery") THEN
                pMsgError := STRSUBSTNO(Text007, FORMAT((FasaniSetup."Amount Cross Delivery")))

            ELSE
                pMsgError := STRSUBSTNO(Text006, FasaniSetup."Amount Delivery");

        IF pMsgError <> '' THEN
            EXIT(FALSE);

        EXIT(TRUE);
    end;

    procedure LoadContextPaymentsDelivery(var NewTotal: Decimal; var NewSubTotal: Decimal; var NewPayments: Decimal; var NewBalance: Decimal; var TenderName: Text[50]; pDelOrder: Record "LSC Delivery Order")
    var
        POSTrans: Record "LSC POS Transaction";
        POSLine: Record "LSC POS Trans. Line";
    begin
        IF POSTrans.GET(pDelOrder."Order No.") THEN BEGIN //28981
            POSTrans.CALCFIELDS(POSTrans."Gross Amount", POSTrans.Payment, POSTrans."Line Discount", POSTrans."Total Discount", POSTrans."Income/Exp. Amount");
            POSLine.RESET;
            POSLine.SETCURRENTKEY("Receipt No.", "Entry Type", "Entry Status");
            POSLine.SETRANGE(POSLine."Receipt No.", POSTrans."Receipt No.");
            POSLine.SETRANGE(POSLine."Entry Type", POSLine."Entry Type"::Payment);
            POSLine.SETRANGE(POSLine."Entry Status", 0);
            CASE POSLine.COUNT OF
                0:
                    TenderName := '';
                1:
                    BEGIN
                        POSLine.FINDFIRST;
                        TenderName := POSLine.Description;
                    END;
                ELSE
                    TenderName := Text005;
            END;

            NewTotal := POSTrans."Gross Amount" + POSTrans."Line Discount" + POSTrans."Income/Exp. Amount";
            NewSubTotal := NewTotal - POSTrans."Line Discount";
            NewPayments := POSTrans.Payment;
            NewBalance := NewSubTotal - POSTrans.Payment;
        END;
    end;

    local procedure CheckCustomPayTrip(pDelOrder: Record "LSC Delivery Order"): Boolean
    var
        POSTransLinePAY: Record "LSC POS Trans. Line";
    begin
        POSTransLinePAY.RESET;
        POSTransLinePAY.SETCURRENTKEY("Receipt No.", "Entry Type", "Entry Status");
        POSTransLinePAY.SETRANGE(POSTransLinePAY."Receipt No.", pDelOrder."Order No.");
        POSTransLinePAY.SETRANGE(POSTransLinePAY."Entry Type", POSTransLinePAY."Entry Type"::Item);
        POSTransLinePAY.SETRANGE(POSTransLinePAY."Entry Status", 0);
        POSTransLinePAY.SETRANGE(POSTransLinePAY.Number, 'A104405');
        EXIT(POSTransLinePAY.FINDFIRST);
    end;

    procedure ValidateGiftMixTotalDiscount(pOrder: Code[20]; var pErrorText: Text[250]): Boolean
    var
        POSLine: Record "LSC POS Trans. Line";
        Voucher: Record "LSC Voucher Entries";
    begin
        POSLine.RESET;
        POSLine.SETCURRENTKEY("Receipt No.", "Entry Type", "Entry Status");
        POSLine.SETRANGE(POSLine."Receipt No.", pOrder);
        POSLine.SETRANGE(POSLine."Entry Type", POSLine."Entry Type"::TotalDiscount);
        POSLine.SETRANGE(POSLine."Entry Status", 0);
        IF POSLine.FIND('-') THEN
            REPEAT
                Voucher.RESET;
                Voucher.SETRANGE(Voucher."Store No.", POSLine."Store No.");
                Voucher.SETRANGE(Voucher."POS Terminal No.", POSLine."POS Terminal No.");
                Voucher.SETRANGE(Voucher."Line No.", POSLine."Line No.");
                Voucher.SETRANGE(Voucher."Receipt Number", pOrder);
                Voucher.SETRANGE(Voucher.Voided, FALSE);
                IF NOT Voucher.FINDFIRST THEN BEGIN
                    pErrorText := Text013;
                    EXIT(FALSE);
                END;
                IF POSLine.Amount <> Voucher.Amount THEN BEGIN
                    pErrorText := STRSUBSTNO(Text014, FORMAT(POSLine.Amount), FORMAT(Voucher.Amount));
                    EXIT(FALSE);
                END;
            UNTIL POSLine.NEXT = 0;

        EXIT(TRUE);
    end;

    procedure GetDelOrderTenderType(var pDelOrder: Record "LSC Delivery Order")
    var
        TransLinePAY: Record "LSC POS Trans. Line";
        POSLine: Record "LSC POS Trans. Line";
        TenderTypeSetup_l: Record "LSC Tender Type Setup";
    begin

        pDelOrder."Tender Type" := pDelOrder."Tender Type"::None;

        TransLinePAY.RESET;
        TransLinePAY.SETCURRENTKEY("Receipt No.", "Entry Type", "Entry Status");
        TransLinePAY.SETRANGE(TransLinePAY."Receipt No.", pDelOrder."Order No.");
        TransLinePAY.SETRANGE(TransLinePAY."Entry Type", TransLinePAY."Entry Type"::Payment);
        TransLinePAY.SETRANGE(TransLinePAY."Entry Status", 0);
        CASE TransLinePAY.COUNT OF
            0:
                ;//None
            1:
                BEGIN
                    TransLinePAY.FINDFIRST;
                    IF TenderTypeSetup_l.GET(TransLinePAY.Number) THEN BEGIN
                        CASE TenderTypeSetup_l."FSN Function in CC" OF
                            TenderTypeSetup_l."FSN Function in CC"::Card:
                                pDelOrder."Tender Type" := pDelOrder."Tender Type"::Card;
                            TenderTypeSetup_l."FSN Function in CC"::Change:
                                pDelOrder."Tender Type" := pDelOrder."Tender Type"::Cash;
                            TenderTypeSetup_l."FSN Function in CC"::Check:
                                pDelOrder."Tender Type" := pDelOrder."Tender Type"::Prepaid;
                            TenderTypeSetup_l."FSN Function in CC"::CustomerAccount:
                                pDelOrder."Tender Type" := pDelOrder."Tender Type"::Invoice;
                        END;
                    END;
                END;
            ELSE
                pDelOrder."Tender Type" := pDelOrder."Tender Type"::None;
        END;
        IF pDelOrder."FSN Cash Change" <> 0 THEN BEGIN
            TransLinePAY.SETRANGE(TransLinePAY.Number, '1');  //WVILLALTA 11.20-
            IF NOT TransLinePAY.FIND('-') THEN
                pDelOrder."FSN Cash Change" := 0
            ELSE
                IF NOT (POSLine.GET(pDelOrder."Order No.", 1) AND (POSLine."Entry Status" = 0)) THEN
                    pDelOrder."FSN Cash Change" := 0;
        END;
    end;

    procedure InsertDelChangePayment(pReceipt: Code[20]; pPOSTransLine: Record "LSC POS Trans. Line")
    var
        DelOrder: Record "LSC Delivery Order";
        POSTransCodeUnit: Codeunit "LSC POS Transaction";
        TrsLine: Record "LSC POS Trans. Line";
        lText002: Label 'Change $%1 for $%2';
        lText001: Label 'Change for:';
        Change: Decimal;
        AmtTmp: Text;
        AmtDec: Decimal;
    begin

        //AmtTmp := POSTransCodeUnit.OpenNumericKeyboard(lText001, 0, FORMAT(ROUND(pPOSTransLine.Amount, 0.01, '=')), '');
        POSSESSION.SetValue('VALCHANGEFSN', Format(pPOSTransLine."Line No."));
        POSGUI.OpenNumericKeyboard(lText001, 0, '', 0, 'CHANGEPAYMENTFSN');
    end;

    //Result procedure SendNoTelefono
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Controller", 'OnNumpadResult', '', true, true)]
    local procedure "LSC POS Controller_OnNumpadResult"
    (
        payload: Text;
        inputValue: Text;
        resultOK: Boolean;
        var processed: Boolean
    )
    var
        ValueInt: Integer;
    begin
        if payload = 'CHANGEPAYMENTFSN' THEN BEGIN//28981
            ValueChangePayment(inputValue);
            processed := true;
        END;
    end;

    procedure ValueChangePayment(AmtTmp: Text)
    var
        LineInt: Integer;
        ChangeInt: Integer;
        TransactionH: Record "LSC Transaction Header";
        UlTransactionNo: Integer;
        AmtDec: Decimal;
        pPOSTransLine: Record "LSC POS Trans. Line";
        TrsLine: Record "LSC POS Trans. Line";
        DelOrder: Record "LSC Delivery Order";
        Change: Decimal;
        Text001: Label 'El dato %1 no es valido';
    begin
        IF ((AmtTmp <> '') AND EVALUATE(AmtDec, AmtTmp)) THEN BEGIN
            IF Evaluate(LineInt, POSSESSION.GetValue('VALCHANGEFSN')) then;

            pPOSTransLine.Reset();
            pPOSTransLine.SetRange(pPOSTransLine."Receipt No.", POSSESSION.GetValue('CURRORDER'));
            pPOSTransLine.SetRange(pPOSTransLine."Line No.", LineInt);
            if pPOSTransLine.FindFirst() then begin
                POSSESSION.SetValue('VALCHANGEFSN', '');
                if pPOSTransLine.Number = '1' then begin
                    AmtDec := ROUND(AmtDec, 0.01, '=');
                    IF AmtDec < pPOSTransLine.Amount THEN
                        AmtDec := pPOSTransLine.Amount;

                    IF DelOrder.GET(pPOSTransLine."Receipt No.") THEN BEGIN

                        Change := AmtDec + pPOSTransLine.Amount;

                        AmtTmp := STRSUBSTNO(Text015, COPYSTR(pPOSTransLine.Description, 1, 18),
                          STRSUBSTNO(Text016,
                            FORMAT((AmtDec - ROUND(pPOSTransLine.Amount, 0.01, '=')), 0, '<Precision,2:2><Standard Format,2>'),
                            FORMAT((AmtDec), 0, '<Precision,2:2><Standard Format,2>')), '');


                        POSNewLineFreeText(pPOSTransLine."Receipt No.", 37, '', 2);
                        POSNewLineFreeText(pPOSTransLine."Receipt No.", 7, AmtTmp, 2);
                        IF TrsLine.GET(pPOSTransLine."Receipt No.", 1) THEN BEGIN
                            IF (TrsLine."Entry Status" <> 0) AND (TrsLine."Entry Type" = TrsLine."Entry Type"::FreeText) THEN
                                TrsLine."Entry Status" := 0;
                            TrsLine."Parent Line" := pPOSTransLine."Line No.";
                            TrsLine.MODIFY;
                        END;

                        DelOrder."FSN Cash Change" := AmtDec - ROUND(pPOSTransLine.Amount, 0.01, '=');
                        DelOrder.MODIFY;

                        COMMIT;

                    END;
                end;
            end;
        END ELSE BEGIN
            POSGUI.PosMessage(STRSUBSTNO(Text001, AmtTmp));
        END;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnBeforeInsertPaymentLine', '', true, true)]
    local procedure "LSC POS Transaction Events_OnBeforeInsertPaymentLine"
(
    var POSTransaction: Record "LSC POS Transaction";
    var POSTransLine: Record "LSC POS Trans. Line";
    var CurrInput: Text;
    var TenderTypeCode: Code[10];
    Balance: Decimal;
    PaymentAmount: Decimal;
    STATE: Code[10];
    var isHandled: Boolean
)
    var
        DelOrder: Record "LSC Delivery Order";
        AmtTmp: Text[100];
        AmtSubText: Text;
    begin
        if TenderTypeCode = '1' then begin
            if DelOrder.Get(POSTransaction."Receipt No.") then begin
                if PaymentAmount > Balance then begin
                    DelOrder."FSN Cash Change" := PaymentAmount - Balance;
                    DelOrder.Modify();
                    COMMIT;
                    AmtTmp := STRSUBSTNO(Text015, COPYSTR('Efectivo', 1, 18),
                          STRSUBSTNO(Text016,
                            FORMAT((ROUND(PaymentAmount - Balance, 0.01, '=')), 0, '<Precision,2:2><Standard Format,2>'),
                            FORMAT((PaymentAmount), 0, '<Precision,2:2><Standard Format,2>')), '');
                    POSNewLineFreeText(POSTransLine."Receipt No.", 7, AmtTmp, 2);
                end;
            end;
        end;
    end;

    procedure InsertAllFreeTextPayments(pParameters: Record "LSC POS Menu Line")
    var
        POSPaymentLines: Record "LSC POS Trans. Line";
        POSTransInfocode: Record "LSC POS Trans. Infocode Entry";
        PosLines: Record "LSC POS Trans. Line";
        AmtDec: Decimal;
        AmtText: Text[100];
        AmtSubText: Text;
        j: Integer;
        p: Integer;
        Ok_: Boolean;
        DelOrder: Record "LSC Delivery Order";
    begin
        j := 2;
        POSPaymentLines.RESET;
        POSPaymentLines.SETCURRENTKEY("Receipt No.", "Entry Type", "Entry Status");
        POSPaymentLines.SETRANGE(POSPaymentLines."Receipt No.", pParameters."Current-RECEIPT");
        POSPaymentLines.SETRANGE(POSPaymentLines."Entry Type", POSPaymentLines."Entry Type"::Payment);
        POSPaymentLines.SETRANGE(POSPaymentLines."Entry Status", 0);
        IF POSPaymentLines.FINDSET THEN
            REPEAT
                IF POSPaymentLines.Number <> '1' THEN BEGIN
                    p := 1;
                    CLEAR(AmtSubText);
                    POSTransInfocode.RESET;
                    POSTransInfocode.SETRANGE(POSTransInfocode."Receipt No.", POSPaymentLines."Receipt No.");
                    POSTransInfocode.SETRANGE(POSTransInfocode."Transaction Type", 2);
                    POSTransInfocode.SETRANGE(POSTransInfocode."Line No.", POSPaymentLines."Line No.");
                    POSTransInfocode.SETFILTER(POSTransInfocode.Status, '<2');
                    IF POSTransInfocode.FINDSET THEN
                        REPEAT
                            AmtSubText += ' ' + POSTransInfocode.Information;
                            p += 1;
                        UNTIL (POSTransInfocode.NEXT = 0) OR (p > 3);
                    AmtText := STRSUBSTNO(Text015, COPYSTR(POSPaymentLines.Description, 1, 18),
                      '$' + FORMAT((ROUND(POSPaymentLines.Amount, 0.01, '=')), 0, '<Precision,2:2><Standard Format,2>'),
                      AmtSubText);

                    AmtText := COPYSTR(AmtText, 1, 100);
                    POSNewLineFreeText(POSPaymentLines."Receipt No.", j, AmtText, 2);
                    IF PosLines.GET(POSPaymentLines."Receipt No.", j) THEN BEGIN
                        IF (PosLines."Entry Status" <> 0) OR (PosLines."Parent Line" <> POSPaymentLines."Line No.") THEN BEGIN
                            PosLines."Entry Status" := 0;
                            PosLines."Parent Line" := POSPaymentLines."Line No.";
                            PosLines.MODIFY;
                        END;
                    END;

                    j += 1;
                END ELSE BEGIN
                    POSNewLineFreeText(POSPaymentLines."Receipt No.", 37, '', 2);
                    Ok_ := PosLines.GET(POSPaymentLines."Receipt No.", 1);
                    IF NOT Ok_ OR (Ok_ AND (PosLines."Entry Status" <> 0)) THEN BEGIN
                        AmtDec := ((ROUND(POSPaymentLines.Amount, 0.01, '=') DIV 5) + 1) * 5;
                        AmtText := STRSUBSTNO(Text015, COPYSTR(POSPaymentLines.Description, 1, 18),
                          STRSUBSTNO(Text016,
                            FORMAT((AmtDec - ROUND(POSPaymentLines.Amount, 0.01, '=')), 0, '<Precision,2:2><Standard Format,2>'),
                            FORMAT((AmtDec), 0, '<Precision,2:2><Standard Format,2>')), '');

                        POSNewLineFreeText(POSPaymentLines."Receipt No.", 1, AmtText, 2);
                        IF PosLines.GET(POSPaymentLines."Receipt No.", 1) THEN BEGIN
                            IF (PosLines."Entry Status" <> 0) OR (PosLines."Parent Line" <> POSPaymentLines."Line No.") THEN BEGIN
                                PosLines."Entry Status" := 0;
                                PosLines."Parent Line" := POSPaymentLines."Line No.";
                                PosLines.MODIFY;
                            END;
                        END;
                        IF DelOrder.GET(POSPaymentLines."Receipt No.") THEN BEGIN //WVILLALTA 11.20-
                            DelOrder."FSN Cash Change" := AmtDec - ROUND(POSPaymentLines.Amount, 0.01, '=');
                            DelOrder.MODIFY;
                        END;                                                      //WVILLALTA 11.20+
                    END;
                END;
            UNTIL POSPaymentLines.NEXT = 0;
        COMMIT;
    end;

    procedure POSNewLineFreeText(Receipt: Code[20]; LinkNumber: Integer; TextVal: Text; Type: Option Normal,Typology,Payments,Infocode)
    var
        pPOSTrans: Record "LSC POS Transaction";
        pPOSTransLine: Record "LSC POS Trans. Line";
        pNextLine: Integer;
        NewLine: Record "LSC POS Trans. Line";
        POSInfo: Record "LSC POS Trans. Infocode Entry";
        Text026: Label 'Error insert tipology, field was ocuped for %1';
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
                    ERROR(STRSUBSTNO(Text026, FORMAT(pPOSTransLine."Entry Type")));

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

    procedure ValidateTotalPressed(TotalPOSTransaction: Record "LSC POS Transaction"; Balance: Decimal; RealBalance: Decimal): Boolean
    var
        Customer_l: Record "Customer";
        lText001: Label 'No esta permitido facturar en Credito fiscal a este cliente.';
        lText002: Label 'El cliente es requerido para facturar en Credito fiscal.';
        GlobalParameter: Record "FSN Parameter";
        POSTransLine: Record "LSC POS Trans. Line";
        POSTransInfoRequired: Record "LSC POS Trans. Infocode Entry";
        lText003: Label 'El articulo %1 requiere una entrada de texto obligatoria. Anule la linea e intente de nuevo.';
        POSTransLineExists: Record "LSC POS Trans. Line";
        lText004: Label 'La transaccion debe tener al menos un articulo';
        ErrorText: Text[100];
        lText005: Label 'Tiene articulos pendientes de confirmar escaneo.';
        DeliveryOrder_l: Record "LSC Delivery Order";
        lText009: Label 'El pedido DELIVERY no esta asignado a un motorista \ ¿ Facturar de todas formas?';
        DELIVERY_: Label 'DELIVERY';
        TransactionHeader_l: Record "LSC Transaction Header";
        lText010: Label 'Ya existe una transacción valida con recibo %1, Anule y haga nueva transacción';
        lCoupon: Record "LSC Coupon Header";
        lText011: Label 'No hay cupon aplicado, el Infocodigo requiere un Cupon aplicado en transaccción';
        lTerminal: Record "LSC POS Terminal";
        lText012: Label 'No puede ser Ticket cuando hay cupon en transacción';
        POSCardEntry_l: Record "LSC POS Card Entry";
        lText013: Label 'Aviso!\POS esta en modo %1';
        RestricOption_: Option Normal,NameOnly,ExcpName,All;
    begin

        //WVILLALTA18JUL19  #PMT-
        TransactionHeader_l.RESET;
        TransactionHeader_l.SETCURRENTKEY("Store No.", "Wrong Shift", "POS Terminal No.", "Receipt No.", "Entry Status");
        TransactionHeader_l.SETRANGE(TransactionHeader_l."Store No.", TotalPOSTransaction."Store No.");
        TransactionHeader_l.SETRANGE(TransactionHeader_l."POS Terminal No.", TotalPOSTransaction."POS Terminal No.");
        TransactionHeader_l.SETRANGE(TransactionHeader_l."Receipt No.", TotalPOSTransaction."Receipt No.");
        TransactionHeader_l.SETRANGE(TransactionHeader_l."Entry Status", TransactionHeader_l."Entry Status"::" ");
        IF TransactionHeader_l.FINDFIRST THEN BEGIN
            POSGUI.PosMessage(STRSUBSTNO(lText010, TotalPOSTransaction."Receipt No."));
            EXIT(FALSE);
        END;

        COMMIT;

        IF TotalPOSTransaction."Sale Is Return Sale" THEN BEGIN
            POSCardEntry_l.RESET;
            POSCardEntry_l.SETRANGE(POSCardEntry_l."Store No.", TotalPOSTransaction."Retrieved from Store No.");
            POSCardEntry_l.SETRANGE(POSCardEntry_l."POS Terminal No.", TotalPOSTransaction."Retrieved from POS Term. No.");
            POSCardEntry_l.SETRANGE(POSCardEntry_l."Transaction No.", TotalPOSTransaction."Retrieved from Trans. No.");
            POSCardEntry_l.SETRANGE(POSCardEntry_l."Transaction Type", POSCardEntry_l."Transaction Type"::Sale);
            POSCardEntry_l.SETRANGE(POSCardEntry_l."MSR input", TRUE);
            POSCardEntry_l.SETRANGE(POSCardEntry_l."Authorisation Ok", TRUE);
            IF POSCardEntry_l.FINDFIRST AND (POSCardEntry_l.Date = TODAY) THEN
                POSGUI.PosMessage(STRSUBSTNO(lText013, POSSESSION.GetValue('#INACTIVE_KINPOS')));
        END;

        IF LinePendingConfirmScannExists(TotalPOSTransaction."Receipt No.") THEN BEGIN
            POSGUI.PosMessage(lText005);
            EXIT(FALSE);
        END;

        IF NOT TotalPOSTransaction."Sale Is Return Sale" AND (TotalPOSTransaction."Entry Status" <> TotalPOSTransaction."Entry Status"::Voided) THEN BEGIN
            lTerminal.GET(TotalPOSTransaction."POS Terminal No.");
            POSTransLine.RESET;
            POSTransLine.SETCURRENTKEY("Receipt No.", "Entry Type", "Entry Status");
            POSTransLine.SETRANGE(POSTransLine."Receipt No.", TotalPOSTransaction."Receipt No.");
            POSTransLine.SETRANGE(POSTransLine."Entry Type", POSTransLine."Entry Type"::Coupon);
            POSTransLine.SETRANGE(POSTransLine."Entry Status", POSTransLine."Entry Status"::" ");
            IF POSTransLine.FINDFIRST THEN
                REPEAT
                    lCoupon.GET(POSTransLine."Coupon Code");
                    IF lCoupon."FSN Infocode" <> '' THEN
                        IF (TotalPOSTransaction."FSN No. Serie NCF" = lTerminal."FSN No. Serie NCF Ticket") OR (TotalPOSTransaction."FSN No. Serie NCF" = '') THEN BEGIN
                            POSGUI.PosMessage(lText012);
                            EXIT(FALSE);
                        END;//Tempora GLAXO
                UNTIL POSTransLine.NEXT = 0;
        END;

        POSTransLineExists.RESET;
        POSTransLineExists.SETCURRENTKEY(POSTransLineExists."Receipt No.", POSTransLineExists."Entry Type", POSTransLineExists."Entry Status");
        POSTransLineExists.SETRANGE(POSTransLineExists."Receipt No.", TotalPOSTransaction."Receipt No.");
        POSTransLineExists.SETFILTER(POSTransLineExists."Entry Type", '%1|%2', POSTransLineExists."Entry Type"::Item, POSTransLineExists."Entry Type"::IncomeExpense);
        POSTransLineExists.SETFILTER(POSTransLineExists."Entry Status", '<>%1', POSTransLineExists."Entry Status"::Voided);
        IF NOT POSTransLineExists.FINDFIRST THEN BEGIN
            POSGUI.PosMessage(lText004);
            EXIT(FALSE);
        END;

        IF TotalPOSTransaction."Customer No." <> '' THEN
            Customer_l.GET(TotalPOSTransaction."Customer No.");

        IF NOT TotalPOSTransaction."Sale Is Return Sale" THEN BEGIN
            RestricOption_ := RestricOption_::Normal;
            if TotalPOSTransaction."FSN Document Type" <> TotalPOSTransaction."FSN Document Type"::Ticket then begin
                IF Customer_l."LSC Retail Customer Group" <> 'COMODIN' then begin
                    TotalPOSTransaction.CalcFields("Gross Amount");
                    if TotalPOSTransaction."Gross Amount" <> 0 then begin
                        IF NOT FSNUTILITY.ValidateExtraCustomer(TotalPOSTransaction."Receipt No.", TRUE, FALSE, Customer_l, ErrorText, RestricOption_) THEN BEGIN//28981
                            IF ErrorText <> '' THEN
                                POSGUI.PosMessage(ErrorText);
                            EXIT(FALSE);
                        end;
                    end;
                end;
            END;
        END;
        EXIT(TRUE);
    end;

    procedure ValidateExtraCustomer(Receipt_l: Code[20]; IsTotalEvent: Boolean; IsNew: Boolean; CustomerTEMP: Record "Customer"; var ErrorText: Text[100]; var RestricOption_l: Option Normal,NameOnly,ExcpName,All) Response_: Boolean
    var
        Customer_l: Record "Customer";
        CardExtists: Boolean;
        VATPostingSetup_l: Record "VAT Posting Setup";
        TransREC: Record "LSC POS Transaction";
        FirstMemberShipCard: Text[100];
        COMODIN_: Label 'COMODIN';
        lText001: Label 'Es obligatorio que lleve informacion de Titular/Beneficiario';
        lText002: Label '% no configurado';
        lText003: Label 'Error grave: cliente no encontrado o no es Unico, este es un error de Programacion';
        lText004: Label 'Cliente %1 tiene opcion de Bloqueado, no puede usarlo en transacciones';
    begin
        ErrorText := '';
        RestricOption_l := RestricOption_l::Normal;

        IF IsTotalEvent THEN BEGIN
            TransREC.GET(Receipt_l);
            TransREC.CALCFIELDS(TransREC."Gross Amount");
            IF TransREC."Customer No." <> '' THEN BEGIN
                Customer_l.GET(TransREC."Customer No.");
                IF Customer_l.Blocked <> Customer_l.Blocked::" " THEN BEGIN
                    ErrorText := STRSUBSTNO(lText004, Customer_l.Name);
                    EXIT(FALSE);
                END;

                IF Customer_l."FSN Request Beneficiary" THEN
                    IF NOT FSNUtility.ValidateInfocodeBeneficiarioExtists(TransREC) THEN BEGIN //Method Search infocode
                        ErrorText := lText001;
                        EXIT(FALSE);
                    END;
            END;

            TransREC.CalcFields("Gross Amount");
            IF TransREC."Gross Amount" <> 0 THEN BEGIN
                IF NOT ValidateTypeDocumentAndCustom(TransREC, TransREC."Gross Amount", ErrorText, IsTotalEvent) THEN //Method Type Doc.
                    EXIT(FALSE);
            END;
        END
        ELSE BEGIN
            IF CustomerTEMP.ISEMPTY THEN BEGIN
                ErrorText := lText003;
                EXIT(FALSE);
            END;

            IF NOT IsNew THEN BEGIN
                Customer_l.GET(CustomerTEMP."No.");
                IF Customer_l."LSC Retail Customer Group" = COMODIN_ THEN
                    RestricOption_l := RestricOption_l::NameOnly
                ELSE
                    IF Customer_l."FSN EBS Reference" <> '' THEN
                        RestricOption_l := RestricOption_l::ExcpName
                    ELSE
                        IF FSNUtility.ValidateFirstMembershipCardActive(Customer_l."No.", FirstMemberShipCard) THEN //Method Get FirstCard
                            RestricOption_l := RestricOption_l::ExcpName;

                IF RestricOption_l = RestricOption_l::NameOnly THEN
                    EXIT(TRUE);

            END;
            IF NOT ValidateCustData(CustomerTEMP, ErrorText, FALSE, IsTotalEvent) THEN //Method Cust Data
                EXIT(FALSE);

            IF NOT IsTotalEvent THEN
                IF NOT ValidateDuplicateCustDocuments(CustomerTEMP, ErrorText, IsNew) THEN
                    EXIT(FALSE);

        END;//TotalEvent
        EXIT(TRUE);
    end;

    procedure ValidateDuplicateCustDocuments(CustomerTEMP: Record "Customer"; var ErrorText: Text[100]; IsNew: Boolean) Duplicate: Boolean
    var
        RegEx: DotNet Regex;
        CustomerSearch_l: Record "Customer";
        FORMAT_DUI: Label '[0-9]{8}-[0-9]{1}';
        FORMAT_NIT: Label '[0-9]{4}-[0-9]{6}-[0-9]{3}-[0-9]{1}';
        lText005: Label 'DUI %1 ya existe para Cliente ID %2 %3';
        lText006: Label 'NRC %1 ya existe para Cliente ID %2 %3';
        lText007: Label 'NIT %1 ya existe para Cliente ID %2 %3';
        lText008: Label 'Doc. Extranjero %1 ya existe para Cliente ID %2 %3';
        lText009: Label 'El formato de DUI debe ser ########-#';
        lText010: Label 'El formato de NIT debe ser ####-######-###-#';
    begin
        CLEAR(CustomerSearch_l);
        CustomerSearch_l.RESET;
        IF NOT IsNew THEN
            CustomerSearch_l.SETFILTER(CustomerSearch_l."No.", '<>%1', CustomerTEMP."No.");//Initialize constant filter

        CustomerSearch_l.SETRANGE(CustomerSearch_l."FSN NRC", CustomerTEMP."FSN NRC");
        IF CustomerTEMP."FSN EBS Reference" = '' THEN  //WVILLALTA08ENE19 #RACC-+
            IF CustomerTEMP."FSN NRC Description" <> '' THEN
                IF CustomerSearch_l.FINDFIRST THEN
                    ErrorText := COPYSTR(STRSUBSTNO(lText006, CustomerTEMP."FSN NRC", CustomerSearch_l."No.", CustomerSearch_l.Name), 1, 100);

        CustomerSearch_l.SETRANGE(CustomerSearch_l."FSN NRC");
        CustomerSearch_l.SETRANGE(CustomerSearch_l."VAT Registration No.", CustomerTEMP."VAT Registration No.");
        IF ErrorText = '' THEN
            IF (CustomerTEMP."VAT Registration No." <> '') THEN
                IF NOT RegEx.IsMatch(CustomerTEMP."VAT Registration No.", FORMAT_NIT) THEN
                    ErrorText := lText010
                ELSE
                    IF CustomerSearch_l.FINDFIRST THEN
                        IF CustomerTEMP."FSN EBS Reference" = '' THEN
                            ErrorText := COPYSTR(STRSUBSTNO(lText007, CustomerTEMP."VAT Registration No.", CustomerSearch_l."No.", CustomerSearch_l.Name), 1, 100);

        CustomerSearch_l.SETRANGE(CustomerSearch_l."VAT Registration No.");
        CustomerSearch_l.SETRANGE(CustomerSearch_l."FSN DUI", CustomerTEMP."FSN DUI");
        IF ErrorText = '' THEN
            IF CustomerTEMP."FSN DUI" <> '' THEN
                IF NOT RegEx.IsMatch(CustomerTEMP."FSN DUI", FORMAT_DUI) THEN
                    ErrorText := lText009
                ELSE
                    IF CustomerSearch_l.FINDFIRST THEN
                        ErrorText := COPYSTR(STRSUBSTNO(lText005, CustomerTEMP."FSN DUI", CustomerSearch_l."No.", CustomerSearch_l.Name), 1, 100);

        CustomerSearch_l.SETRANGE(CustomerSearch_l."FSN DUI");
        CustomerSearch_l.SETRANGE(CustomerSearch_l."FSN Foreign document", CustomerTEMP."FSN Foreign document");
        IF (CustomerTEMP."FSN Foreign document" <> '') THEN
            IF (ErrorText = '') THEN
                IF CustomerSearch_l.FINDFIRST THEN
                    ErrorText := COPYSTR(STRSUBSTNO(lText008, CustomerTEMP."FSN Foreign document", CustomerSearch_l."No.", CustomerSearch_l.Name), 1, 100);

        IF ErrorText <> '' THEN
            EXIT(FALSE);

        EXIT(TRUE);
    end;

    procedure ValidateCustData(CustomerTEMP: Record "Customer"; var ErrorText: Text[100]; IsNew: Boolean; IsTotalEvent: Boolean) Response_: Boolean
    var
        RegEx: DotNet Regex;
        //VATPostingSetup_l: Record "VAT Posting Setup";
        FORMAT_DUI: Label '[0-9]{8}-[0-9]{1}';
        FORMAT_NIT: Label '[0-9]{4}-[0-9]{6}-[0-9]{3}-[0-9]{1}';
        lText001: Label 'Debe ser mayor de edad si tiene DUI o Doc. Extranjero';
        lText002: Label 'Cliente tipo empresa requiere informacion NRC, Giro(Descriptivo) y NIT';
        lText003: Label 'El formato de DUI debe ser ########-#';
        lText004: Label 'El formato de NIT debe ser ####-######-###-#';
        lText005: Label 'Un cliente no puede tener DUI y No. Extranjero. Debe ser un documento.';
        lText006: Label '%1 no configurado';
        lText007: Label 'Cliente persona debe tener al menos %1 o %2';
        lText008: Label 'Cliente tipo empresa requiere informacion NRC, Giro(Descriptivo) y DUI';
        VATBusPostingGroup_l: Record "VAT Business Posting Group";
    begin

        //VATPostingSetup_l.SETRANGE(VATPostingSetup_l."VAT Bus. Posting Group", CustomerTEMP."VAT Bus. Posting Group");
        VATBusPostingGroup_l.SETRANGE(VATBusPostingGroup_l.Code, CustomerTEMP."VAT Bus. Posting Group");
        IF NOT VATBusPostingGroup_l.FINDFIRST THEN BEGIN
            ErrorText := COPYSTR(STRSUBSTNO(lText006, CustomerTEMP.FIELDCAPTION("VAT Bus. Posting Group")), 1, 100);
            EXIT(FALSE);
        END;

        VATBusPostingGroup_l.GET(CustomerTEMP."VAT Bus. Posting Group");

        IF (CustomerTEMP."FSN DUI" <> '') AND (CustomerTEMP."FSN Foreign document" <> '') THEN
            ErrorText := lText005;

        IF IsNew THEN
            IF (CustomerTEMP."FSN DUI" <> '') OR (CustomerTEMP."FSN Foreign document" <> '') THEN
                IF NOT ((CustomerTEMP."FSN Birthday" <> 0D) AND (CustomerTEMP."FSN Birthday" <= CALCDATE('<-18Y>', TODAY))) THEN
                    ErrorText := lText001;

        IF NOT (CustomerTEMP."FSN Customer Type" = CustomerTEMP."FSN Customer Type"::Company) THEN BEGIN
            IF (CustomerTEMP."FSN DUI" = '') AND (CustomerTEMP."FSN Foreign document" = '') THEN
                ErrorText := STRSUBSTNO(lText007, CustomerTEMP.FIELDCAPTION("FSN DUI"), CustomerTEMP.FIELDCAPTION("FSN Foreign document"));
        END ELSE BEGIN
            IF (CustomerTEMP."FSN NRC" = '') OR (CustomerTEMP."FSN NRC Description" = '') OR (CustomerTEMP."VAT Registration No." = '')
              OR (STRLEN(CustomerTEMP."FSN NRC") < 5) THEN
                IF NOT IsTotalEvent THEN
                    ErrorText := lText002;
        END;

        IF ErrorText <> '' THEN
            EXIT(FALSE);

        IF (CustomerTEMP."VAT Registration No." <> '') THEN
            IF NOT RegEx.IsMatch(CustomerTEMP."VAT Registration No.", FORMAT_NIT) THEN
                ErrorText := lText004;

        IF ErrorText = '' THEN
            IF CustomerTEMP."FSN DUI" <> '' THEN
                IF NOT RegEx.IsMatch(CustomerTEMP."FSN DUI", FORMAT_DUI) THEN
                    ErrorText := lText003;

        IF ErrorText <> '' THEN
            EXIT(FALSE);

        EXIT(TRUE);
    end;

    procedure ValidateTypeDocumentAndCustom(POSTransaction_l: Record "LSC POS Transaction"; GrossAmount: Decimal; var ErrorText: Text[100]; IsTotalEvent: Boolean) Response_: Boolean
    var
        POSTerminal_l: Record "LSC POS Terminal";
        Customer_l: Record "Customer";
        RetailSetup: Record "LSC Retail Setup";
        lText001: Label 'No esta permitido facturar en Credito fiscal a este cliente. %1';
        lText002: Label 'El cliente es requerido para facturar en Credito fiscal o Factura.';
        lText003: Label 'Cliente con RETENCION debe cambiar a Factura comsumidor final';
        lText004: Label 'Cliente con PERCEPCION debe cambiar a Credito Fiscal';
        lText007: Label 'Venta igual o superior a $ %1 requiere un NIT valido';
        lText008: Label 'El cliente es requerido por venta igual o superior a $ %1';
        lText010: Label 'Se requiere un cliente tipo EMPRESA para facturar con Credito Fiscal.';
        lText011: Label 'Credito Fiscal requiere cliente con NRC, GIRO y NIT valido';
        lText012: Label 'Venta igual o superior a $ %1 requiere un DUI valido';
        lText013: Label 'Credito Fiscal requiere cliente con NRC, GIRO y DUI valido';
    begin
        ErrorText := '';
        POSTerminal_l.GET(POSTransaction_l."POS Terminal No.");
        RetailSetup.GET;

        IF POSTransaction_l."Customer No." <> '' THEN
            Customer_l.GET(POSTransaction_l."Customer No.")
        ELSE
            IF (POSTransaction_l."FSN Document Type" <> POSTransaction_l."FSN Document Type"::Ticket) then
                IF POSTransaction_l."FSN No. Serie NCF" <> '' THEN
                    ErrorText := lText002;

        IF POSTransaction_l."Customer No." <> '' THEN BEGIN
            IF NOT ValidateCustData(Customer_l, ErrorText, FALSE, IsTotalEvent) THEN //Method Cust Data
                EXIT(FALSE);

            IF POSTransaction_l."FSN Document Type" = POSTransaction_l."FSN Document Type"::"Credito Fiscal" THEN
                IF Customer_l."LSC Retail Customer Group" = gTextRetCusGrp THEN
                    ErrorText := COPYSTR(STRSUBSTNO(lText001, gTextRetCusGrp), 1, 100);

            /*IF POSTransaction_l."FSN Document Type" = POSTransaction_l."FSN Document Type"::"Credito Fiscal" THEN
                IF (Customer_l."FSN NRC" = '') OR (Customer_l."FSN NRC Description" = '') OR (Customer_l."VAT Registration No." = '')
              OR (STRLEN(Customer_l."FSN NRC Description") < 5) THEN
                    ErrorText := lText011;*/

            IF POSTransaction_l."FSN Document Type" = POSTransaction_l."FSN Document Type"::"Credito Fiscal" THEN
                IF (Customer_l."FSN NRC" = '') OR (Customer_l."FSN NRC Description" = '') OR (Customer_l."FSN DUI" = '')
                OR (STRLEN(Customer_l."FSN NRC Description") < 5) THEN
                    ErrorText := lText013;
        END;

        IF ErrorText = '' THEN
            IF RetailSetup."FSN Amount Limit Whitout Cust." > 0 THEN
                IF GrossAmount >= RetailSetup."FSN Amount Limit Whitout Cust." THEN
                    IF NOT (POSTransaction_l."Customer No." <> '') THEN
                        ErrorText := COPYSTR(STRSUBSTNO(lText008, FORMAT(RetailSetup."FSN Amount Limit Whitout Cust.")), 1, 100);

        IF GrossAmount >= RetailSetup."FSN Limit whitout VAT Reg. No." THEN begin//This value not exists in BD
            //IF Customer_l."VAT Registration No." = '' THEN
            IF Customer_l."FSN DUI" = '' THEN
                IF NOT (Customer_l."FSN Foreign document" <> '') THEN
                    ErrorText := COPYSTR(STRSUBSTNO(lText012, FORMAT(RetailSetup."FSN Limit whitout VAT Reg. No.")), 1, 100);//Value 200
                                                                                                                             //ErrorText := COPYSTR(STRSUBSTNO(lText007, FORMAT(RetailSetup."FSN Limit whitout VAT Reg. No.")), 1, 100);//Value 200
        end;

        IF ErrorText = '' THEN BEGIN
            IF POSTransaction_l."Customer No." <> '' THEN BEGIN
                IF Customer_l."FSN Customer VAT Type" = Customer_l."FSN Customer VAT Type"::Perception THEN
                    IF RetailSetup."FSN Perception Amt. Limit" > 0 THEN
                        IF GrossAmount >= RetailSetup."FSN Perception Amt. Limit" THEN
                            IF POSTransaction_l."FSN No. Serie NCF" <> POSTerminal_l."FSN No. Serie Credito Fiscal" THEN
                                ErrorText := lText004;

                IF Customer_l."FSN Customer VAT Type" = Customer_l."FSN Customer VAT Type"::Retention THEN
                    IF RetailSetup."FSN Retention Amt. Limit" > 0 THEN
                        IF GrossAmount >= RetailSetup."FSN Retention Amt. Limit" THEN
                            IF POSTransaction_l."FSN No. Serie NCF" <> POSTerminal_l."FSN No. Serie NCF Cons. Final" THEN
                                ErrorText := lText003;
            END;
        END;

        IF ErrorText <> '' THEN
            EXIT(FALSE);

        EXIT(TRUE);

    end;

    procedure LinePendingConfirmScannExists(ReceiptNo: Code[20]): Boolean
    var
        POSTransLine2: Record "LSC POS Trans. Line";
    begin
        POSTransLine2.RESET;
        POSTransLine2.SETCURRENTKEY("Receipt No.", "Line No.");
        POSTransLine2.SETRANGE(POSTransLine2."Receipt No.", ReceiptNo);
        POSTransLine2.SETRANGE(POSTransLine2."Entry Type", POSTransLine2."Entry Type"::Item);
        POSTransLine2.SETRANGE(POSTransLine2."Entry Status", 0);
        POSTransLine2.SETRANGE(POSTransLine2."FSN Additional Action", POSTransLine2."FSN Additional Action"::ConfirmScann);
        EXIT(POSTransLine2.FINDFIRST);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Controller", 'OnButtonPressed', '', true, true)]
    local procedure "EPOS Controler_OnButtonPressed"
    (
     var POSMenuLine: Record "LSC POS Menu Line";
     var handled: Boolean
    )
    var
        ErrorValidation: Text;
        deliveryOrder: Record "LSC Delivery Order";
        POSGUI: Codeunit "LSC POS GUI";
    begin
        if not handled then
            if (POSMenuLine.Command = 'DEL-TAKEORDFUNC') and
                 (POSMenuLine.Parameter in ['ORDER-CLOSEPANEL', 'ORDER-CONFIRMNEW']) then begin
                if POSSESSION.GetValue('CURRORDER') = '' then
                    exit;

                IF NOT CheckDataPaymentDeliverySend(POSSESSION.GetValue('CURRORDER'), ErrorValidation) THEN BEGIN
                    handled := TRUE;
                    POSGUI.PosMessage(ErrorValidation);
                    EXIT;
                END;
            end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Controller", 'OnButtonPressed', '', true, true)]
    local procedure "EPOS Controler_OnButtonPressed2"
    (
    var POSMenuLine: Record "LSC POS Menu Line";
    var handled: Boolean
    )
    var
        ErrorValidation: Text;
        deliveryOrderTmp: Record "LSC Delivery Order" temporary;
        ZoomDelOrder: Record "LSC Delivery Order";
        recRef: RecordRef;
        ePosControlInterface: Codeunit "LSC POS Control Interface";
        pStaffID: Code[20];
        pPassword: Text;
        pWorkShift: Code[1];
        pReasonText: Text[80];
        lText001: Label '%1 \Continue?';
    begin
        if not handled then
            if (POSMenuLine.Command = 'DEL-TAKEORDFUNC') and
                         (POSMenuLine.Parameter in ['ORDER-CLOSEPANEL', 'ORDER-CONFIRMNEW']) then begin
                if POSSESSION.GetValue('CURRORDER') = '' then
                    exit;
                recRef.GetTable(ZoomDelOrder);
                ePosControlInterface.GetRecordZoomData(recRef, '#DEL-ORDER-DETZOOM');
                Clear(deliveryOrderTmp);
                deliveryOrderTmp.Address := recRef.Field(ZoomDelOrder.FieldNo(Address)).Value;
                IF (deliveryOrderTmp.Address <> '') THEN
                    IF NOT CheckTotalAmountDeliverySetup(POSSESSION.GetValue('CURRORDER'), ErrorValidation) THEN BEGIN
                        IF POSGUI.PosConfirm(STRSUBSTNO(lText001, ErrorValidation), FALSE) THEN BEGIN
                            handled := true;

                            ePosControlInterface.ShowPanelModal('#FSNLOGIN', 'CCAUTHORIZA');

                        END;
                    end;
            end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnBeforeTotalExecuted', '', true, true)]
    local procedure "POS Transaction Events_OnBeforeTotalExecuted"
    (
    var POSTransaction: Record "LSC POS Transaction";
    var IsHandled: Boolean
    )
    var
        Balance: Decimal;
        RealBalance: Decimal;
        POSLine: Record "LSC POS Trans. Line";
        DelOrd: Record "LSC Delivery Order";
        DELBalance: Decimal;
        RetailSetup_l: Record "LSC Retail Setup";
    begin
        if not IsHandled then begin
            IF NOT ValidateTotalPressed(POSTransaction, Balance, RealBalance) then
                IsHandled := true;
        end;
        RetailSetup_l.Get();
        if RetailSetup_l."FSN Is Local Receipt" and (RetailSetup_l."FSN Last Slipt No." <> '') then begin
            if Evaluate(DELBalance, POSSESSION.GetValue('Balance')) then begin
                if DELBalance = 0 then begin
                    POSLine.Reset();
                    POSLine.SetRange("Receipt No.", POSTransaction."Receipt No.");
                    POSLine.SetRange("Entry Status", POSLine."Entry Status"::" ");
                    POSLine.SetRange(POSLine."Entry Type", POSLine."Entry Type"::Payment);
                    if POSLine.find('-') then
                        repeat
                            if POSLine."FSN Additional Action" = POSLine."FSN Additional Action"::ConfirmPayment then begin
                                POSLine."FSN Additional Action" := POSLine."FSN Additional Action"::Nothing;
                                POSLine.Modify();
                            end
                        until POSLine.Next() = 0;
                end;
            end;
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
        SetNewStaffID: Text;
        StaffID: Text;
        Password: Text;
        Workshift: Text;
        Manager: Boolean;
        pReasonText: Text[80];
        UserPersonalization2: Record "User Personalization";
        lText002: Label 'User %1 is not RETAIL MANAGER';
        pInt: Integer;
        tStaff: Record "LSC Staff";
    begin
        Clear(Manager);
        if (payload = 'CCAUTHORIZA') and (panelID = '#FSNLOGIN') then begin
            processed := true;
            if resultOK then begin
                Manager := true;
                StaffID := ePOSControlInterface.GetInputText(POSSession.StaffInputID);
                Password := ePOSControlInterface.GetInputText(POSSession.PasswordInputID);
                Workshift := CopyStr(ePOSControlInterface.GetInputText(POSSession.WorkShiftInputID), 1, 1);
                if StaffID = '' then
                    exit;
                SetNewStaffID := StaffID;
                if not POSSESSION.Login(true, StaffID, Password, Workshift, pReasonText) then begin
                    POSGUI.PosMessage(StrSubstNo(Text019, pReasonText));
                    exit;
                end;
                DeliveryOrderManagement.OrderClosePanelPressed();
            end;
        end;

        if (payload = 'LINECLOGIN') and (panelID = '#FSNLOGIN') then begin
            processed := true;
            if resultOK then begin
                Manager := true;
                StaffID := ePOSControlInterface.GetInputText(POSSession.StaffInputID);
                Password := ePOSControlInterface.GetInputText(POSSession.PasswordInputID);
                Workshift := CopyStr(ePOSControlInterface.GetInputText(POSSession.WorkShiftInputID), 1, 1);
                if StaffID = '' then
                    exit;
                SetNewStaffID := StaffID;
                if not POSSESSION.Login(true, StaffID, Password, Workshift, pReasonText) then begin
                    POSGUI.PosMessage(StrSubstNo(Text019, pReasonText));
                    exit;
                end;
                Message(POSSESSION.StaffID());
                tStaff.Reset();
                tStaff.SetCurrentKey(ID);
                tStaff.SetRange(ID, StaffID);
                tStaff.SetRange("Permission Group", 'MANAGER');
                IF NOT (tStaff.FINDFIRST) AND (EVALUATE(pInt, StaffID)) THEN BEGIN
                    POSGUI.PosMessage(STRSUBSTNO(lText002, StaffID));
                    EXIT;
                END;
                //DeliveryOrderManagement.OrderClosePanelPressed();
            end;
        end;
    end;

}


codeunit 50042 "Check Payments POS"
{
    // WVILLALTA 11.20             - Field: Change, in "Delivery Order" table
    // WVILLALTA 04.21             - Validate GIFTCARD


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
        RetailSetup: Record "LSC Retail Setup";
        Text011: Label 'Transaction have payments Online. %1';
        Text012: Label 'Transaction have balance pending.';
        Text013: Label 'Data Entry linked to total discount not exists.';
        Text014: Label 'Total Discount is %1 not match entry data amount %2';
        Text015: Label 'PAY: %1 %2 %3';
        Text016: Label 'Change $%1 for $%2';
        Text017: Label 'Real value Vaucher is %1 and Payment line is %2';
        POSSESSION: Codeunit "LSC POS Session";
        POSGUI: Codeunit "LSC POS GUI";

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
    begin
        pErrorText := '';

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
            (POSTrans."Line Discount" + POSTrans.Payment)) - POSTrans."FSN Retention Amount" <> 0 THEN BEGIN
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

            IF NOT FASANIServerUtil.ValidateTypeDocumentAndCustom(POSTrans,
                (POSTrans."Gross Amount" + POSTrans."Income/Exp. Amount"), pErrorText, TRUE) THEN
                EXIT(FALSE);

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
                            IF NOT CardEntry.GET(POSLine."Store No.", POSLine."POS Terminal No.", POSLine."Receipt No.", POSLine."Line No.") THEN
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

    procedure CheckTotalAmountDeliverySetup(pDelOrder: Record "LSC Delivery Order"; var pMsgError: Text[250]): Boolean
    var
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
        POSTrans.GET(pDelOrder."Order No.");
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

    procedure ValidateDeleteTransaction(pOrder: Code[20]; var pErrorText: Text[250]): Boolean
    var
        CardEntry: Record "LSC POS Card Entry";
        POSLine: Record "LSC POS Trans. Line";
    begin
        RetailSetup.GET;
        CLEAR(pErrorText);

        CardEntry.RESET;
        CardEntry.SETRANGE(CardEntry."Receipt No.", pOrder);
        CardEntry.SETRANGE(CardEntry."Authorisation Ok", TRUE);
        IF CardEntry.FINDFIRST THEN
            REPEAT
                IF POSLine.GET(CardEntry."Receipt No.", CardEntry."Line No.") AND (POSLine."Entry Status" = 0) THEN
                    pErrorText := STRSUBSTNO(Text011, CardEntry."FSN Bank Name");

            UNTIL (CardEntry.NEXT = 0) OR (pErrorText <> '');

        EXIT(pErrorText = '');
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

    procedure DeleteForce(OrderNo: Code[20])
    var
        CardEntry: Record "LSC POS Card Entry";
    begin
        CardEntry.RESET;
        CardEntry.SETRANGE(CardEntry."Receipt No.", OrderNo);
        CardEntry.DELETEALL;
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
                            TenderTypeSetup_l."Default Function"::Customer:
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
        lText001: Label 'Change for:';
        AmtTmp: Text;
        AmtDec: Decimal;
        lText002: Label 'Change $%1 for $%2';
        //DelFuncExt: Codeunit "50028";
        Change: Decimal;
        TrsLine: Record "LSC POS Trans. Line";
    begin
        AmtTmp := POSTransCodeUnit.OpenNumericKeyboard(lText001, 0, FORMAT(ROUND(pPOSTransLine.Amount, 0.01, '=')), '');
        IF NOT ((AmtTmp <> '') AND EVALUATE(AmtDec, AmtTmp)) THEN
            EXIT;

        AmtDec := ROUND(AmtDec, 0.01, '=');
        IF AmtDec < pPOSTransLine.Amount THEN
            AmtDec := pPOSTransLine.Amount;

        IF DelOrder.GET(pPOSTransLine."Receipt No.") THEN BEGIN

            Change := AmtDec - pPOSTransLine.Amount;

            AmtTmp := STRSUBSTNO(Text015, COPYSTR(pPOSTransLine.Description, 1, 18),
              STRSUBSTNO(Text016,
                FORMAT((AmtDec - ROUND(pPOSTransLine.Amount, 0.01, '=')), 0, '<Precision,2:2><Standard Format,2>'),
                FORMAT((AmtDec), 0, '<Precision,2:2><Standard Format,2>')), '');


            POSNewLineFreeText(pPOSTransLine."Receipt No.", 37, '', 2);
            POSNewLineFreeText(pPOSTransLine."Receipt No.", 1, AmtTmp, 2);
            IF TrsLine.GET(pPOSTransLine."Receipt No.", 1) THEN BEGIN
                IF (TrsLine."Entry Status" <> 0) AND (TrsLine."Entry Type" = TrsLine."Entry Type"::FreeText) THEN
                    TrsLine."Entry Status" := 0;
                TrsLine."Parent Line" := pPOSTransLine."Line No.";
                TrsLine.MODIFY;
            END;

            DelOrder."FSN Cash Change" := AmtDec - ROUND(pPOSTransLine.Amount, 0.01, '=');
            DelOrder.MODIFY;

            COMMIT;
            //  END;
        END;


    end;

    procedure InsertAllFreeTextPayments(pParameters: Record "LSC POS Menu Line")
    var
        POSPaymentLines: Record "LSC POS Trans. Line";
        POSTransInfocode: Record "LSC POS Trans. Infocode Entry";
        //DelFuncExt: Codeunit "50028";
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
                        IF DelOrder.GET(POSPaymentLines."Receipt No.") THEN BEGIN
                            DelOrder."FSN Cash Change" := AmtDec - ROUND(POSPaymentLines.Amount, 0.01, '=');
                            DelOrder.MODIFY;
                        END;
                    END;
                END;
            UNTIL POSPaymentLines.NEXT = 0;
        COMMIT;
    end;

    /////////////////////////////////////////////////////////////////////////////////////////////////////////
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
        FSNUtility: Codeunit "FSN Utility";
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

        //WVILLALTA18JUL19  #PMT+

        IF TotalPOSTransaction."Sale Is Return Sale" THEN BEGIN //WVILLALTA10MAR2020-
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

        IF NOT ValidateSerie(TotalPOSTransaction) THEN BEGIN
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

        IF NOT TotalPOSTransaction."Sale Is Return Sale" THEN
            RestricOption_ := RestricOption_::Normal;
        IF NOT FSNUtility.ValidateExtraCustomer(TotalPOSTransaction."Receipt No.", TRUE, FALSE, Customer_l, ErrorText, RestricOption_) THEN BEGIN
            IF ErrorText <> '' THEN
                POSGUI.PosMessage(ErrorText);
            EXIT(FALSE);

        END;
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

    procedure ValidateSerie(POSTrans: Record "LSC POS Transaction"): Boolean
    var
        lText001: Label 'There is no Serial Code for %1';
    begin
        IF POSTrans."FSN NCF" = '' then begin
            POSGUI.PosMessage(STRSUBSTNO(lText001, POSTrans."FSN Document Type"));
            EXIT(FALSE);
        end else begin
            EXIT(TRUE);
        end;
    end;

    /*[EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnBeforeTotalExecuted', '', true, true)]
    local procedure "POS Transaction Events_OnBeforeTotalExecuted"
(
    var POSTransaction: Record "LSC POS Transaction";
    var IsHandled: Boolean
)
    var
        Balance: Decimal;
        RealBalance: Decimal;
    begin
        IF NOT ValidateTotalPressed(POSTransaction, Balance, RealBalance) then
            IsHandled := true;
    end;
*/

}


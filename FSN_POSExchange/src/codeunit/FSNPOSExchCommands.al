codeunit 50008 "FSN POS Exch. Commands"
{
    TableNo = "LSC POS Menu Line";

    trigger OnRun()
    begin
        GlobalRec := Rec;
        IF PosTrans.GET("Current-RECEIPT") THEN BEGIN
            CASE Command OF
                'POSEXCHANGE':
                    POSExchangePage;
                'POSEXCHANGETOTAL':
                    ValidatePOSExchange(PosTrans);
                ELSE
                    Message(Text001);
                    EXIT;
            END;
        END;
    END;

    var
        PosTrans: Record "LSC POS Transaction";
        GlobalRec: Record "LSC POS Menu Line";
        sl: Record "LSC POS Trans. Line";
        Text001: Label 'Comando no encontrado';
        POSGUI: Codeunit "LSC POS GUI";
        PosPrint: Codeunit "LSC POS Print Utility";

    procedure POSExchangePage()
    var
        PagePOSExchange: Page "FSN POS Exchange Trans. Line";
    begin
        PagePOSExchange.SETGLOBALVALUE(PosTrans);
        PagePOSExchange.RUN;
    end;

    procedure ValidatePOSExchange(POSTransaction_: Record "LSC POS Transaction") POSExch: Boolean
    var
        POSExchangeTrans_l: Record "FSN POS Exchange Transaction";
        lText001: Label 'POS Exchange have a record out Type Exchange Line %1 , Item %2. delete or modify record for continue.';
        lText002: Label 'POS Exchange have Quantity Zero (0) in Line %1 , Item %2. Delete or modify record for continue.';
        MessageTxt: Text;
        lText003: Label 'Confirm delivered the exchanges? \';
        lText004: Label 'Delete or modify record for continue. (Exchanges)';
    begin

        POSExchangeTrans_l.RESET;
        POSExchangeTrans_l.SETRANGE(POSExchangeTrans_l."Receipt No.", POSTransaction_."Receipt No.");
        POSExchangeTrans_l.SETRANGE(POSExchangeTrans_l.Status, POSExchangeTrans_l.Status::Open);
        IF POSExchangeTrans_l.FINDSET THEN
            REPEAT
                IF (POSExchangeTrans_l."POS Exchange No." = '') OR (POSExchangeTrans_l.Quantity <= 0) THEN BEGIN
                    IF POSExchangeTrans_l."POS Exchange No." = '' THEN
                        POSGUI.PosMessage(STRSUBSTNO(lText001, POSExchangeTrans_l."Line No.", POSExchangeTrans_l.GetItemDescription(POSExchangeTrans_l."Item No.")))
                    ELSE
                        POSGUI.PosMessage(STRSUBSTNO(lText002, POSExchangeTrans_l."Line No.", POSExchangeTrans_l.GetItemDescription(POSExchangeTrans_l."Item No.")));
                    EXIT(FALSE);
                END;
            UNTIL POSExchangeTrans_l.NEXT = 0
        ELSE
            EXIT(TRUE);

        MessageTxt := lText003;
        IF POSExchangeTrans_l.FINDSET THEN
            REPEAT
                MessageTxt := MessageTxt + FORMAT(POSExchangeTrans_l.Quantity) + '-' + POSExchangeTrans_l.GetItemDescription(POSExchangeTrans_l."Item No.") + '\';
            UNTIL POSExchangeTrans_l.NEXT = 0;

        IF POSGUI.PosConfirm(MessageTxt, TRUE) THEN BEGIN
            IF POSExchangeTrans_l.FIND('-') THEN
                repeat
                    posexchangetrans_l.Validate("Replication Counter");
                    POSExchangeTrans_l.Status := POSExchangeTrans_l.Status::Released;
                    POSExchangeTrans_l.Modify(false);
                until POSExchangeTrans_l.NEXT = 0;
        END ELSE BEGIN
            POSGUI.PosMessage(lText004);
            EXIT(FALSE);
        END;

        EXIT(TRUE);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Post Utility", 'OnAfterPostTransaction', '', true, true)]
    local procedure "POS Post Utility_OnAfterPostTransaction"(var TransactionHeader_p: Record "LSC Transaction Header")
    var
        POSExchangeTrans_l: Record "FSN POS Exchange Transaction";
        Item: Record "Item";
        Header: Record "LSC POS Print Setup Header";
        InfoNumber: Text[30];
        DoIt: Boolean;
        QtyLeft: Decimal;
        QtyOne: Decimal;
        POSExchSetup_l: Record "FSN POS Exchange Setup";
        Ok_: Boolean;
        POSPrint: Codeunit "LSC POS Print Utility";
        POSExchTrans: Record "FSN POS Exchange Transaction";
        POSExchTrans2: Record "FSN POS Exchange Transaction";
    begin

        /*IF TransactionHeader_p."Entry Status" = TransactionHeader_p."Entry Status"::Voided THEN
            EXIT;*/

        POSExchTrans.RESET;
        POSExchTrans.SETRANGE(POSExchTrans."Receipt No.", TransactionHeader_p."Receipt No.");
        POSExchTrans.SETRANGE(POSExchTrans."Transaction No.", 0);
        IF POSExchTrans.FIND('-') THEN
            REPEAT
                POSExchTrans2.INIT;
                POSExchTrans2 := POSExchTrans;
                POSExchTrans2."Transaction No." := TransactionHeader_p."Transaction No.";
                POSExchTrans2."Store No." := TransactionHeader_p."Store No.";
                POSExchTrans2."POS Terminal No." := TransactionHeader_p."POS Terminal No.";
                POSExchTrans2.Status := POSExchTrans2.Status::Released;
                POSExchTrans2.Validate("Replication Counter");
                POSExchTrans2.INSERT;
                POSExchTrans.DELETE;
            UNTIL POSExchTrans.NEXT = 0;
        POSExchangeTrans_l.RESET;
        POSExchangeTrans_l.SETRANGE(POSExchangeTrans_l."Receipt No.", TransactionHeader_p."Receipt No.");
        POSExchangeTrans_l.SETRANGE(POSExchangeTrans_l."Transaction No.", TransactionHeader_p."Transaction No.");
        POSExchangeTrans_l.SETRANGE(POSExchangeTrans_l."Store No.", TransactionHeader_p."Store No.");
        POSExchangeTrans_l.SETRANGE(POSExchangeTrans_l."POS Terminal No.", TransactionHeader_p."POS Terminal No.");
        IF POSExchangeTrans_l.FIND('-') THEN
            REPEAT
                IF POSExchSetup_l.GET(POSExchangeTrans_l."POS Exchange No.") THEN
                    IF POSExchSetup_l."Print Setup ID" <> '' THEN
                        IF Header.GET(POSExchSetup_l."Print Setup ID") THEN
                            IF Item.GET(POSExchangeTrans_l."Item No.") THEN BEGIN
                                Ok_ := POSPrint.PrintExtra(TransactionHeader_p, Header, 0, TransactionHeader_p.Payment, POSExchangeTrans_l.Quantity, Item."No.", Item.Description, '', 1, POSExchangeTrans_l."Line No."
                                , '', '', '', POSExchangeTrans_l."Sales Staff", '');

                            END;
            UNTIL POSExchangeTrans_l.NEXT = 0;
        EXIT;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Print Utility", 'OnPrintExtraSlipFieldNameValue', '', true, true)]
    local procedure "LSC POS Print Utility_OnPrintExtraSlipFieldNameValue"
    (
        Transaction: Record "LSC Transaction Header";
        var FieldName: array[20] of Text[2];
        var FieldValue: array[20] of Text[50];
        var LastIndex: Integer
    )
    var
        MyFieldName: array[7] of Text[2];
        MyFieldValue: array[7] of Text[50];
        Customer: Record Customer;
    begin
        MyFieldName[1] := 'RC';
        MyFieldValue[1] := Transaction."Receipt No.";
        MyFieldName[2] := 'SN';
        MyFieldValue[2] := Transaction."Store No.";

        if Customer.Get(Transaction."Customer No.") Then begin
            MyFieldName[3] := 'CN';
            MyFieldValue[3] := Customer.Name;
            MyFieldName[4] := 'TL';
            MyFieldValue[4] := Customer."Phone No.";
        end;

        FieldName[15] := MyFieldName[3];
        FieldValue[15] := MyFieldValue[3];
        FieldName[16] := MyFieldName[4];
        FieldValue[16] := MyFieldValue[4];
        FieldName[19] := MyFieldName[1];
        FieldValue[19] := MyFieldValue[1];
        FieldName[20] := MyFieldName[2];
        FieldValue[20] := MyFieldValue[2];

        LastIndex := 20;
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
        IF (ItemJournalLine."Reason Code" = 'CANJE') or (ItemJournalLine."Reason Code" = 'CANJES') THEN
            HideDialog := true;
    end;


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnBeforeTotalExecuted', '', true, true)]
    local procedure "LSC POS Transaction Events_OnBeforeTotalExecuted"
    (
        var POSTransaction: Record "LSC POS Transaction";
        var IsHandled: Boolean
    )
    begin
        if not IsHandled then
            IsHandled := not ValidatePOSExchange(POSTransaction);
    end;

}
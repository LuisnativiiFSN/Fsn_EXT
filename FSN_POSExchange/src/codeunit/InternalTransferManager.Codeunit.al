codeunit 50009 "FSN Internal Transfer Manager"
{


    TableNo = "LSC Scheduler Job Header";

    trigger OnRun()
    begin
        CASE Integer OF
            DATABASE::"FSN POS Exchange Transaction":
                BEGIN
                    UpdateItemsBC;
                    InicializePOSExchRequests(Code);
                    JobExitAppliedAll();
                    JobLiquidateAllAutomatic();
                    COMMIT;

                    CheckWSTableTransfer();
                END;
        END;

        if code = 'LIQUIDATECREDITNOTE' then begin
            JobLiquidateAllCreditNote();
            COMMIT;
        end;
    end;

    var
        NoSeriesInternalMov: Code[10];
        AllowedChangeMenssageProcess: Boolean;

    procedure Inicialize()
    var
        InvSetup: Record "Inventory Setup";
    begin
        IF NoSeriesInternalMov = '' THEN
            IF InvSetup.GET THEN
                NoSeriesInternalMov := InvSetup."Internal Movement Nos.";
        //Message(NoSeriesInternalMov);
        //NoSeriesInternalMov := 'A-BLK'; //JH010624 Se comenta para que tome serie segun configuracion
    end;

    procedure InicializePOSExchRequests("Transfer-to": Code[10])
    var
        POSTransExch_l: Record "FSN POS Exchange Transaction";
        Ok_: Boolean;
        Location_l: Record "Location";
        lText001: Label 'Location for use-In Transit not exists.';
    begin
        Ok_ := TRUE;
        IF "Transfer-to" <> '' THEN
            Ok_ := Location_l.GET("Transfer-to");

        IF NOT Ok_ THEN
            EXIT;

        POSTransExch_l.RESET;
        POSTransExch_l.SETRANGE(POSTransExch_l."Use Inventory", TRUE);
        POSTransExch_l.SETRANGE(POSTransExch_l.Complete, FALSE);
        IF POSTransExch_l.FINDSET THEN
            REPEAT
                if POSTransExch_l."Receipt No." = '0000PV#500000006425' then
                    if POSTransExch_l."Receipt No." = '0000PV#500000006425' then;
                InicializeFields(POSTransExch_l, "Transfer-to");
            UNTIL POSTransExch_l.NEXT = 0;
    end;

    procedure InicializeFields(ExchangeLine_l: Record "FSN POS Exchange Transaction"; var "Transfer-to": Code[10])
    var
        POSTransExch_l: Record "FSN POS Exchange Transaction";
        POSExchSetup_l: Record "FSN POS Exchange Setup";
        Ok_: Boolean;
        ErrorText: Text[100];
        Location_l: Record "Location";
        NoSeriesMgt: Codeunit "NoSeriesManagement";
        InvSetup_l: Record "Inventory Setup";
        Item_l: Record "Item";
        PurchPrice_l: Record "Purchase Price";
        ItemUnitofMeasure_l: Record "Item Unit of Measure";
        PriceExitst: Boolean;
    begin
        Inicialize;
        Ok_ := NoSeriesInternalMov <> '';

        IF Ok_ THEN  //WVILLALTA11FEB19 v2-
            IF ExchangeLine_l.Complete AND ExchangeLine_l."Use Inventory" AND
              (ExchangeLine_l."Transfer Order No." = '') AND (ExchangeLine_l.Status = ExchangeLine_l.Status::Released) THEN BEGIN
                ExchangeLine_l."Transfer Order No." := NoSeriesMgt.GetNextNo(NoSeriesInternalMov, TODAY, TRUE);
                ExchangeLine_l.Status := ExchangeLine_l.Status::"Exit Applied";
                ExchangeLine_l.MODIFY
            END;       //WVILLALTA11FEB19 v2+

        IF Ok_ THEN
            IF (ExchangeLine_l."Transfer Order No." = '') OR (ExchangeLine_l."Transfer-to Code" = '') OR
              (ExchangeLine_l."Transfer-to Code" <> "Transfer-to") OR (ExchangeLine_l."Unit Cost" = 0) THEN BEGIN

                POSTransExch_l.GET(ExchangeLine_l."Receipt No.", ExchangeLine_l."Transaction No.", ExchangeLine_l."Line No.",
                  ExchangeLine_l."Store No.", ExchangeLine_l."POS Terminal No.");

                IF POSTransExch_l."Transfer Order No." = '' THEN
                    POSTransExch_l."Transfer Order No." := NoSeriesMgt.GetNextNo(NoSeriesInternalMov, TODAY, TRUE);

                /*IF (POSTransExch_l."Transfer-to Code" = '') OR (POSTransExch_l."Transfer-to Code" <> "Transfer-to") THEN BEGIN
                  IF "Transfer-to" = '' THEN
                    IF POSExchSetup_l.GET(ExchangeLine_l."POS Exchange No.") THEN
                      "Transfer-to" := POSExchSetup_l."Transfer-to Code";
                  POSTransExch_l."Transfer-to Code" := "Transfer-to";
                END;*///WVILLALTA31OCT19-+

                IF POSExchSetup_l.GET(ExchangeLine_l."POS Exchange No.") THEN BEGIN//WVILLALTA01NOV19-
                    IF (POSTransExch_l."Transfer-to Code" = '') AND (POSExchSetup_l."Transfer-to Code" <> '') THEN
                        "Transfer-to" := POSExchSetup_l."Transfer-to Code";

                    IF POSTransExch_l."Transfer-to Code" = '' THEN
                        POSTransExch_l."Transfer-to Code" := "Transfer-to";

                    IF POSTransExch_l.Request = POSTransExch_l.Request::None THEN
                        IF POSExchSetup_l."Control Type" = POSExchSetup_l."Control Type"::DeliveryToVendor THEN
                            POSTransExch_l.Request := POSTransExch_l.Request::DeliveryToVendor;

                    IF POSTransExch_l."Autorization Type" = POSTransExch_l."Autorization Type"::None THEN
                        IF POSExchSetup_l."Authorization Type" = POSExchSetup_l."Authorization Type"::WebPage THEN
                            POSTransExch_l."Autorization Type" := POSTransExch_l."Autorization Type"::WebPage;

                END;//WVILLALTA01NOV19+

                IF POSTransExch_l."Unit Cost" = 0 THEN
                    IF Item_l.GET(ExchangeLine_l."Item No.") THEN
                        IF ItemUnitofMeasure_l.GET(ExchangeLine_l."Item No.", ExchangeLine_l."Unit of Measure") THEN BEGIN
                            PriceExitst := FALSE;
                            PurchPrice_l.RESET;
                            PurchPrice_l.SETCURRENTKEY("Item No.", "Vendor No.", "Starting Date", "Currency Code", "Variant Code", "Unit of Measure Code", "Minimum Quantity");
                            PurchPrice_l.SETRANGE(PurchPrice_l."Item No.", ExchangeLine_l."Item No.");
                            PurchPrice_l.SETRANGE(PurchPrice_l."Vendor No.", Item_l."Vendor No.");
                            PurchPrice_l.SETRANGE(PurchPrice_l."Unit of Measure Code", ExchangeLine_l."Unit of Measure");
                            IF PurchPrice_l.FINDSET THEN
                                REPEAT
                                    IF ((PurchPrice_l."Starting Date" >= TODAY) OR (PurchPrice_l."Starting Date" = 0D)) AND
                                      ((PurchPrice_l."Ending Date" <= TODAY) OR (PurchPrice_l."Ending Date" = 0D)) AND
                                      (PurchPrice_l."Minimum Quantity" >= ExchangeLine_l.Quantity) THEN BEGIN
                                        PriceExitst := TRUE;
                                        POSTransExch_l."Unit Cost" := PurchPrice_l."Direct Unit Cost";
                                    END;
                                UNTIL (PurchPrice_l.NEXT = 0) OR PriceExitst;
                            IF NOT PriceExitst THEN
                                POSTransExch_l."Unit Cost" := Item_l."Last Direct Cost" * ItemUnitofMeasure_l."Qty. per Unit of Measure";
                        END;

                POSTransExch_l.MODIFY;
            END;

    end;

    procedure ValidateInventory(ItemNo: Code[20]; UnitOfMeasureCode: Code[10]; Quantity: Integer; LocationFromCode: Code[10]; var ErrorText: Text[100]; IsShip: Boolean) Result_: Boolean
    var
        ItemLedgerEntry_l: Record "Item Ledger Entry";
        QuantityToShipBase: Decimal;
        Ok_: Boolean;
        lText001: Label 'Inventory is not enough for item %1';
        ItemUnitOfMeasure_l: Record "Item Unit of Measure";
        ExchangeLine2_l: Record "FSN POS Exchange Transaction";
        Store_l: Record "LSC Store";
        Location_l: Record "Location";
        lText002: Label 'Setup Location is not correct';
        lText003: Label 'Quantity base cant be Zero';
        TransferLine_l: Record "Transfer Line";
    begin
        ErrorText := '';
        QuantityToShipBase := 0;

        IF NOT Location_l.GET(LocationFromCode) THEN BEGIN
            ErrorText := lText002;
            EXIT(FALSE);
        END;

        Ok_ := ItemUnitOfMeasure_l.GET(ItemNo, UnitOfMeasureCode);
        IF Ok_ THEN
            QuantityToShipBase := Quantity * ItemUnitOfMeasure_l."Qty. per Unit of Measure";

        IF QuantityToShipBase = 0 THEN BEGIN
            ErrorText := lText003;
            EXIT(FALSE);
        END;
        TransferLine_l.RESET;
        TransferLine_l.SETRANGE(TransferLine_l."Item No.", ItemNo);
        TransferLine_l.SETRANGE(TransferLine_l."Transfer-from Code", Location_l.Code);
        TransferLine_l.CALCSUMS(TransferLine_l."Qty. to Ship (Base)");
        QuantityToShipBase := QuantityToShipBase + TransferLine_l."Qty. to Ship (Base)";

        ItemLedgerEntry_l.RESET;
        ItemLedgerEntry_l.SETCURRENTKEY("Item No.", Open, "Variant Code", "Location Code");
        ItemLedgerEntry_l.SETRANGE(ItemLedgerEntry_l."Item No.", ItemNo);
        ItemLedgerEntry_l.SETRANGE(ItemLedgerEntry_l.Open, TRUE);
        ItemLedgerEntry_l.SETRANGE(ItemLedgerEntry_l."Variant Code", '');
        ItemLedgerEntry_l.SETRANGE(ItemLedgerEntry_l."Location Code", Location_l.Code);
        ItemLedgerEntry_l.CALCSUMS(ItemLedgerEntry_l."Remaining Quantity");
        IF (ItemLedgerEntry_l."Remaining Quantity" - QuantityToShipBase) < 0 THEN BEGIN
            ErrorText := COPYSTR(STRSUBSTNO(lText001, ExchangeLine2_l.GetItemDescription(ItemNo)), 1, 100);
            EXIT(FALSE);
        END;

        EXIT(TRUE);
    end;

    procedure ValidateInventoryExt(ItemNo: Code[20]; UnitOfMeasureCode: Code[10]; Quantity: Integer; LocationFromCode: Code[10]; var ErrorText: Text[100]; IsShip: Boolean) Result_: Boolean
    var
        ItemLedgerEntry_l: Record "Item Ledger Entry";
        QuantityToShipBase: Decimal;
        Ok_: Boolean;
        lText001: Label 'Inventory is not enough for item %1';
        ItemUnitOfMeasure_l: Record "Item Unit of Measure";
        ExchangeLine2_l: Record "FSN POS Exchange Transaction";
        Store_l: Record "LSC Store";
        Location_l: Record "Location";
        lText002: Label 'Setup Location is not correct';
        lText003: Label 'Quantity base cant be Zero';
    begin
        ErrorText := '';
        QuantityToShipBase := 0;

        IF NOT Location_l.GET(LocationFromCode) THEN BEGIN
            ErrorText := lText002;
            EXIT(FALSE);
        END;

        Ok_ := ItemUnitOfMeasure_l.GET(ItemNo, UnitOfMeasureCode);
        IF Ok_ THEN
            QuantityToShipBase := Quantity * ItemUnitOfMeasure_l."Qty. per Unit of Measure";

        IF QuantityToShipBase = 0 THEN BEGIN
            ErrorText := lText003;
            EXIT(FALSE);
        END;

        ItemLedgerEntry_l.RESET;
        ItemLedgerEntry_l.SETCURRENTKEY("Item No.", Open, "Variant Code", "Location Code");
        ItemLedgerEntry_l.SETRANGE(ItemLedgerEntry_l."Item No.", ItemNo);
        ItemLedgerEntry_l.SETRANGE(ItemLedgerEntry_l.Open, TRUE);
        ItemLedgerEntry_l.SETRANGE(ItemLedgerEntry_l."Variant Code", '');
        ItemLedgerEntry_l.SETRANGE(ItemLedgerEntry_l."Location Code", Location_l.Code);
        ItemLedgerEntry_l.CALCSUMS(ItemLedgerEntry_l."Remaining Quantity");
        IF (ItemLedgerEntry_l."Remaining Quantity" - QuantityToShipBase) < 0 THEN BEGIN
            ErrorText := COPYSTR(STRSUBSTNO(lText001, ExchangeLine2_l.GetItemDescription(ItemNo)), 1, 100);
            EXIT(FALSE);
        END;

        EXIT(TRUE);
    end;

    procedure ValidateTransaction(ExchangeLine: Record "FSN POS Exchange Transaction"; var Void: Boolean; var ErrorText: Text[100]): Boolean
    var
        TransactionHeader_l: Record "LSC Transaction Header";
        lText001: Label 'Waiting replication transaction %1 %2 %3 ...';
        ExchangeLine_l: Record "FSN POS Exchange Transaction";
    begin
        ErrorText := '';
        Void := FALSE;
        IF NOT TransactionHeader_l.GET(ExchangeLine."Store No.", ExchangeLine."POS Terminal No.",
          ExchangeLine."Transaction No.") AND (ExchangeLine."Transaction Date" = TransactionHeader_l.Date) //VALIDAR FECHA  

          THEN BEGIN
            ErrorText := COPYSTR(STRSUBSTNO(lText001, ExchangeLine."Store No.", ExchangeLine."POS Terminal No.",
              FORMAT(ExchangeLine."Transaction No.")), 1, 100);
            EXIT(FALSE);
        END ELSE BEGIN
            Void := TransactionHeader_l."Entry Status" = TransactionHeader_l."Entry Status"::Voided;
            IF Void THEN BEGIN
                ExchangeLine_l.GET(ExchangeLine."Receipt No.", ExchangeLine."Transaction No.", ExchangeLine."Line No.",
                  ExchangeLine."Store No.", ExchangeLine."POS Terminal No.");
                ExchangeLine_l.Status := ExchangeLine_l.Status::Void;
                ExchangeLine_l.MODIFY;
            END;
            EXIT(TRUE);
        END;
    end;

    procedure RecoveryExchange(POSExchangeLine: Record "FSN POS Exchange Transaction"): Boolean
    var
        Store_l: Record "LSC Store";
    begin
    end;

    procedure TransferReceiptExists(POSExchangeLine: Record "FSN POS Exchange Transaction"; IsShip: Boolean): Boolean
    var
        ItemLedgerEntry_l: Record "Item Ledger Entry";
        "Code": Code[10];
        Store_l: Record "LSC Store";
    begin
        if Store_l.GET(POSExchangeLine."Store No.") then begin
            Code := Store_l."Location Code";

            ItemLedgerEntry_l.RESET;
            ItemLedgerEntry_l.SETCURRENTKEY("Document No.", "Document Type", "Document Line No.");
            ItemLedgerEntry_l.SETRANGE(ItemLedgerEntry_l."Document No.", POSExchangeLine."Transfer Order No.");
            IF IsShip THEN
                ItemLedgerEntry_l.SETRANGE(ItemLedgerEntry_l."Document Type", ItemLedgerEntry_l."Document Type"::"Transfer Shipment")
            ELSE
                ItemLedgerEntry_l.SETRANGE(ItemLedgerEntry_l."Document Type", ItemLedgerEntry_l."Document Type"::"Transfer Receipt");
            ItemLedgerEntry_l.SETRANGE(ItemLedgerEntry_l."Document Line No.", POSExchangeLine."Line No.");
            ItemLedgerEntry_l.SETRANGE(ItemLedgerEntry_l."Location Code", Code);
            ItemLedgerEntry_l.SETRANGE(ItemLedgerEntry_l."Item No.", POSExchangeLine."Item No.");
            EXIT(ItemLedgerEntry_l.FINDFIRST);
        end;
    end;

    procedure NegAdmjExists(POSExchangeLine: Record "FSN POS Exchange Transaction"; IsShip: Boolean): Boolean
    var
        ItemLedgerEntry_l: Record "Item Ledger Entry";
        "Code": Code[10];
        Location_l: Record "Location";
    begin

        Location_l.GET(POSExchangeLine."Transfer-to Code");
        Code := Location_l.Code;

        ItemLedgerEntry_l.RESET;
        ItemLedgerEntry_l.SETCURRENTKEY("Item No.", "Entry Type", "Variant Code", "Drop Shipment", "Location Code", "Posting Date");

        ItemLedgerEntry_l.SETRANGE(ItemLedgerEntry_l."Item No.", POSExchangeLine."Item No.");
        ItemLedgerEntry_l.SETRANGE(ItemLedgerEntry_l."Entry Type", ItemLedgerEntry_l."Entry Type"::"Negative Adjmt.");
        ItemLedgerEntry_l.SETRANGE(ItemLedgerEntry_l."Location Code", Code);
        ItemLedgerEntry_l.SETRANGE(ItemLedgerEntry_l."Document No.", POSExchangeLine."Transfer Order No.");
        ItemLedgerEntry_l.SETRANGE(ItemLedgerEntry_l."Document Line No.", POSExchangeLine."Line No.");

        EXIT(ItemLedgerEntry_l.FINDFIRST);
    end;

    procedure JobExitAppliedAll()
    var
        ExchangeTransaction_l: Record "FSN POS Exchange Transaction";
    begin
        ExchangeTransaction_l.RESET;
        ExchangeTransaction_l.SETCURRENTKEY(Status, "Transfer Order No.");
        ExchangeTransaction_l.SETRANGE(ExchangeTransaction_l.Status, ExchangeTransaction_l.Status::Released);
        ExchangeTransaction_l.SETFILTER(ExchangeTransaction_l."Transfer Order No.", '<>%1', '');
        ExchangeTransaction_l.SETRANGE(ExchangeTransaction_l.Complete, FALSE);
        IF ExchangeTransaction_l.FINDSET THEN
            REPEAT
                //Message(FORMAT(ExchangeTransaction_l."Transaction No."));//
                TryPostExchange(ExchangeTransaction_l);
            UNTIL ExchangeTransaction_l.NEXT = 0;
        ExchangeTransaction_l.SETRANGE(ExchangeTransaction_l."Transfer Order No.");//WVILLALTA 02.20-
        ExchangeTransaction_l.SETRANGE(ExchangeTransaction_l.Complete, FALSE);
        ExchangeTransaction_l.SETRANGE(ExchangeTransaction_l."Use Inventory", FALSE);
        IF ExchangeTransaction_l.FINDSET THEN
            REPEAT
                SendHistoryNotUseInventory(ExchangeTransaction_l);
            UNTIL ExchangeTransaction_l.NEXT = 0;
        //WVILLALTA 02.20+
    end;

    procedure JobLiquidateAllCreditNote()
    var
        ExchangeTransaction_l: Record "FSN POS Exchange Transaction";
    begin
        ExchangeTransaction_l.RESET;
        ExchangeTransaction_l.SETCURRENTKEY(Status, "Transfer Order No.");
        ExchangeTransaction_l.SETRANGE(ExchangeTransaction_l.Status, ExchangeTransaction_l.Status::"Liquidate CreditNote");
        ExchangeTransaction_l.SETRANGE(ExchangeTransaction_l.Complete, TRUE);
        IF ExchangeTransaction_l.FINDSET THEN
            REPEAT
                TryLiquideExchange(ExchangeTransaction_l);
            UNTIL ExchangeTransaction_l.NEXT = 0;
    end;

    procedure JobLiquidateAllAutomatic()
    var
        ExchangeTransaction_l: Record "FSN POS Exchange Transaction";
    begin
        ExchangeTransaction_l.RESET;
        ExchangeTransaction_l.SETCURRENTKEY(Status, "Transfer Order No.");
        ExchangeTransaction_l.SETRANGE(ExchangeTransaction_l.Status,
          ExchangeTransaction_l.Status::"Liquidate Product", ExchangeTransaction_l.Status::"Liquidate CreditNote");
        ExchangeTransaction_l.SETRANGE(ExchangeTransaction_l.Complete, TRUE);
        IF ExchangeTransaction_l.FINDSET THEN
            REPEAT
                TryLiquideExchange(ExchangeTransaction_l);
            UNTIL ExchangeTransaction_l.NEXT = 0;
    end;

    procedure TryPostExchange(ExchangeTrans_l: Record "FSN POS Exchange Transaction"): Boolean
    var
        Ok_: Boolean;
        ErrorText: Text[100];
        ExchangeTrans2_l: Record "FSN POS Exchange Transaction";
        PostedExchange_l: Record "POS Posted Exchange Trans.";
        lText001: Label 'Entry Ledger not found! (%1 %2 %3)';
        lText002: Label 'The transaction number cannot be zero';
    begin

        if ExchangeTrans_l."Transaction No." = 0 then begin
            ExchangeTrans2_l.INIT;
            ExchangeTrans2_l := ExchangeTrans_l;
            ExchangeTrans2_l."Process Message" := lText002;
            ExchangeTrans2_l.MODIFY;
            EXIT(TRUE);
        end;

        if ExchangeTrans_l."Receipt No." = '0000PV#500000006425' then
            if ExchangeTrans_l."Receipt No." = '0000PV#500000006425' then;
        ErrorText := '';
        IF PostedExchange_l.GET(ExchangeTrans_l."Receipt No.", ExchangeTrans_l."Transaction No.", ExchangeTrans_l."Line No.",
          ExchangeTrans_l."Store No.", ExchangeTrans_l."POS Terminal No.") THEN BEGIN
            ExchangeTrans2_l.GET(ExchangeTrans_l."Receipt No.", ExchangeTrans_l."Transaction No.", ExchangeTrans_l."Line No.",
              ExchangeTrans_l."Store No.", ExchangeTrans_l."POS Terminal No.");
            ExchangeTrans2_l.DELETE;
            EXIT(TRUE);
        END;
        IF NOT POSTUseItemJrnTemplate(ExchangeTrans_l, ErrorText, TRUE) THEN BEGIN
            ExchangeTrans2_l.GET(ExchangeTrans_l."Receipt No.", ExchangeTrans_l."Transaction No.", ExchangeTrans_l."Line No.",
              ExchangeTrans_l."Store No.", ExchangeTrans_l."POS Terminal No.");
            ExchangeTrans2_l."Process Message" := ErrorText;
            ExchangeTrans2_l.MODIFY;
            Ok_ := FALSE;
        END ELSE BEGIN
            ExchangeTrans2_l.GET(ExchangeTrans_l."Receipt No.", ExchangeTrans_l."Transaction No.", ExchangeTrans_l."Line No.",
              ExchangeTrans_l."Store No.", ExchangeTrans_l."POS Terminal No.");//WVILLALTA11FEB19-
            IF NOT ExchangeTrans2_l."Use Inventory" OR (ExchangeTrans2_l.Status = ExchangeTrans2_l.Status::Void) THEN BEGIN
                CLEAR(PostedExchange_l);
                PostedExchange_l.INIT;
                PostedExchange_l.TRANSFERFIELDS(ExchangeTrans2_l);
                PostedExchange_l."Posting Date" := TODAY;
                PostedExchange_l."User NAV" := USERID;
                IF PostedExchange_l.INSERT THEN BEGIN
                    //ExchangeTrans2_l.GET(ExchangeTrans_l."Receipt No.",ExchangeTrans_l."Transaction No.",ExchangeTrans_l."Line No.",
                    //ExchangeTrans_l."Store No.",ExchangeTrans_l."POS Terminal No.");WVILLALTA11FEB19+
                    ExchangeTrans2_l.DELETE;
                    EXIT(TRUE);//WVILLALTA23ABR19-+
                END;
            END;
            ExchangeTrans2_l.GET(ExchangeTrans_l."Receipt No.", ExchangeTrans_l."Transaction No.", ExchangeTrans_l."Line No.",
                  ExchangeTrans_l."Store No.", ExchangeTrans_l."POS Terminal No.");
            IF TransferReceiptExists(ExchangeTrans2_l, TRUE) THEN BEGIN //WVILLALTA01NOV19-
                ExchangeTrans2_l.Status := ExchangeTrans2_l.Status::"Exit Applied";
                ExchangeTrans2_l."Process Message" := '';
                ExchangeTrans2_l.Complete := TRUE;
            END ELSE
                ExchangeTrans2_l."Process Message" := COPYSTR(STRSUBSTNO(lText001, ExchangeTrans2_l."Transfer Order No.",
                  ExchangeTrans2_l."Line No.", ExchangeTrans2_l."Store No."), 1, 100);//WVILLALTA01NOV19+
            ExchangeTrans2_l.MODIFY;
            EXIT(TRUE);
        END;
    end;

    procedure TryLiquideExchange(ExchangeTrans_l: Record "FSN POS Exchange Transaction"): Boolean
    var
        Ok_: Boolean;
        ErrorText: Text[100];
        ExchangeTrans2_l: Record "FSN POS Exchange Transaction";
        PostedExchange_l: Record "POS Posted Exchange Trans.";
        lText001: Label '%1 not found in Item Ledger Entry!. Try process';
        lText002: Label 'The transaction number cannot be zero';
    begin
        if ExchangeTrans_l."Transaction No." = 0 then begin
            ExchangeTrans2_l.INIT;
            ExchangeTrans2_l := ExchangeTrans_l;
            ExchangeTrans2_l."Process Message" := lText002;
            ExchangeTrans2_l.MODIFY;
            EXIT(TRUE);
        end;

        ErrorText := '';
        IF PostedExchange_l.GET(ExchangeTrans_l."Receipt No.", ExchangeTrans_l."Transaction No.", ExchangeTrans_l."Line No.",
          ExchangeTrans_l."Store No.", ExchangeTrans_l."POS Terminal No.") THEN BEGIN
            ExchangeTrans2_l.GET(ExchangeTrans_l."Receipt No.", ExchangeTrans_l."Transaction No.", ExchangeTrans_l."Line No.",
              ExchangeTrans_l."Store No.", ExchangeTrans_l."POS Terminal No.");
            ExchangeTrans2_l.DELETE;
            EXIT(TRUE);
        END;

        IF NOT POSTUseItemJrnTemplate(ExchangeTrans_l, ErrorText, FALSE) THEN BEGIN
            ExchangeTrans2_l.INIT;
            ExchangeTrans2_l := ExchangeTrans_l;
            ExchangeTrans2_l."Process Message" := ErrorText;
            ExchangeTrans2_l.MODIFY;
            Ok_ := FALSE;
        END ELSE BEGIN
            ExchangeTrans2_l.GET(ExchangeTrans_l."Receipt No.", ExchangeTrans_l."Transaction No.", ExchangeTrans_l."Line No.",
              ExchangeTrans_l."Store No.", ExchangeTrans_l."POS Terminal No.");//WVILLALTA11FEB19-

            IF ExchangeTrans2_l.Status = ExchangeTrans2_l.Status::"Liquidate Product" THEN//WVILLALTA01NOV19-
                Ok_ := TransferReceiptExists(ExchangeTrans2_l, FALSE);
            IF ExchangeTrans2_l.Status = ExchangeTrans2_l.Status::"Liquidate CreditNote" THEN
                Ok_ := NegAdmjExists(ExchangeTrans2_l, FALSE);
            IF ExchangeTrans2_l.Status = ExchangeTrans2_l.Status::Void THEN
                Ok_ := TRUE;

            IF NOT Ok_ THEN BEGIN
                //ExchangeTrans2_l."Process Message" := STRSUBSTNO(lText001,FORMAT(ExchangeTrans2_l.Status));
                ExchangeTrans2_l.MODIFY;
                EXIT(FALSE);
            END;//WVILLALTA01NOV19+

            CLEAR(PostedExchange_l);
            PostedExchange_l.INIT;
            PostedExchange_l.TRANSFERFIELDS(ExchangeTrans2_l);
            //IF ExchangeTrans2_l.Status = ExchangeTrans2_l.Status::"Liquidate Product" THEN BEGIN
            //  PostedExchange_l."External Document No." := '';
            //  PostedExchange_l."Amount Doc. Inc. VAT" := 0;
            //END;
            /*IF AllowedChangeMenssageProcess THEN
                          PostedExchange_l."Process Message" := ExchangeTrans_l."Process Message"
                      ELSE
                          PostedExchange_l."Process Message" := '';*///WVILLALTA16ENE2020-

            PostedExchange_l."Process Message" := ExchangeTrans_l."Process Message";//WVILLALTA16ENE2020+

            PostedExchange_l."Posting Date" := TODAY;
            PostedExchange_l."User NAV" := USERID;
            IF PostedExchange_l.INSERT THEN BEGIN
                //ExchangeTrans2_l.GET(ExchangeTrans_l."Receipt No.",ExchangeTrans_l."Transaction No.",ExchangeTrans_l."Line No.",
                //ExchangeTrans_l."Store No.",ExchangeTrans_l."POS Terminal No.");//WVILLALTA11FEB19+
                ExchangeTrans2_l.DELETE;
                Ok_ := TRUE;
            END;
        END;
        EXIT(Ok_);
    end;

    procedure POSTUseItemJrnTemplate(ExchangeTrans: Record "FSN POS Exchange Transaction"; var ErrorText: Text[100]; IsShip: Boolean): Boolean
    var
        POSExchangeSetup: Record "FSN POS Exchange Setup";
        ItemJrnTemplate_l: Record "Item Journal Template";
        ItemJrnBatch_l: Record "Item Journal Batch";
        lText001: Label 'Item Journal Template %1 not configured for products liquide';
        lText002: Label 'Item Journal Batch not found for liquide products';
        ItemJournalLine_l, ItemJournalLine_2 : Record "Item Journal Line";
        Ok_: Boolean;
        lText003: Label 'Item Journal %1 is not type Transfer';
        Void: Boolean;
        Location_l: Record "Location";
        NewLocation_l: Record "Location";
        Store_l: Record "LSC Store";
        lText004: Label 'Error setup Store -Location or Item Batch';
        lText005: Label 'Is not possible liquidate in status %1';
        lText006: Label 'External Document and Total Amount Doc. cant be empty';
        lText007: Label '"Transfer Order No." or "Transfer-fo Code" cant be empty';
        lText008: Label 'You have pending Require: %1';
        lText009: Label 'Transfer Receipt not exists! (From %1 to %2)';
        lText010: Label 'You have pending Autorization  number type : %1';
    begin
        ErrorText := '';
        IF (ExchangeTrans."Transfer Order No." = '') OR (ExchangeTrans."Transfer-to Code" = '') THEN BEGIN
            ErrorText := lText007;
            EXIT(FALSE);
        END;

        //WVILLALTA02DIC19-
        IF IsShip THEN
            IF (ExchangeTrans."Autorization Type" = ExchangeTrans."Autorization Type"::WebPage) AND (ExchangeTrans."Web Authorization No." = '') THEN BEGIN
                ErrorText := STRSUBSTNO(lText010, FORMAT(ExchangeTrans."Autorization Type"));
                EXIT(FALSE);
            END;

        IF NOT IsShip THEN BEGIN
            IF ExchangeTrans.Request = ExchangeTrans.Request::DeliveryToVendor THEN BEGIN
                ErrorText := STRSUBSTNO(lText008, FORMAT(ExchangeTrans.Request));
                EXIT(FALSE);
            END;
            IF NOT TransferReceiptExists(ExchangeTrans, TRUE) THEN BEGIN
                ErrorText := STRSUBSTNO(lText009, ExchangeTrans."Store No.", ExchangeTrans."Transfer-to Code");
                EXIT(FALSE);
            END;
        END;//WVILLALTA02DIC19+

        IF NOT IsShip THEN BEGIN
            IF NOT (ExchangeTrans.Status IN [ExchangeTrans.Status::"Liquidate Product", ExchangeTrans.Status::"Liquidate CreditNote",
              ExchangeTrans.Status::Void]) THEN BEGIN
                ErrorText := STRSUBSTNO(lText005, FORMAT(ExchangeTrans.Status));
                EXIT(FALSE);
            END;
            IF (ExchangeTrans.Status = ExchangeTrans.Status::"Liquidate CreditNote") AND
                ((ExchangeTrans."External Document No." = '') OR (ExchangeTrans."Amount Doc. Inc. VAT" = 0)) THEN BEGIN
                ErrorText := lText006;
                EXIT(FALSE);
            END;
            IF ExchangeTrans.Status = ExchangeTrans.Status::"Liquidate CreditNote" THEN
                EXIT(NegAdjTUseItemJrnTemplate(ExchangeTrans, ErrorText, IsShip));
        END;

        IF NOT ExchangeTrans."Use Inventory" OR (ExchangeTrans.Status = ExchangeTrans.Status::Void) THEN
            EXIT(TRUE);

        Ok_ := Store_l.GET(ExchangeTrans."Store No.") AND (ExchangeTrans."Transfer-to Code" <> '');
        IF Ok_ THEN
            IF IsShip THEN BEGIN
                Ok_ := Location_l.GET(Store_l."Location Code");
                Ok_ := NewLocation_l.GET(ExchangeTrans."Transfer-to Code");
            END ELSE BEGIN
                Ok_ := NewLocation_l.GET(Store_l."Location Code");
                Ok_ := Location_l.GET(ExchangeTrans."Transfer-to Code");
            END;

        IF NOT Ok_ THEN BEGIN
            ErrorText := lText004;
            EXIT(FALSE);
        END;
        IF TransferReceiptExists(ExchangeTrans, IsShip) THEN
            EXIT(TRUE);

        Void := FALSE;
        IF NOT ValidateTransaction(ExchangeTrans, Void, ErrorText) THEN
            EXIT(FALSE)
        ELSE
            IF Void THEN
                EXIT(TRUE);

        IF NOT (ExchangeTrans.Status = ExchangeTrans.Status::"Liquidate CreditNote") THEN BEGIN
            Ok_ := ValidateInventory(ExchangeTrans."Item No.", ExchangeTrans."Unit of Measure", ExchangeTrans.Quantity, Location_l.Code, ErrorText, IsShip);
            IF NOT Ok_ THEN
                EXIT(FALSE);
        end;

        Ok_ := POSExchangeSetup.GET(ExchangeTrans."POS Exchange No.");
        IF NOT ItemJrnTemplate_l.GET(POSExchangeSetup."Item Journal Template") OR NOT Ok_ THEN BEGIN
            ErrorText := COPYSTR(STRSUBSTNO(lText001, POSExchangeSetup."Item Journal Template"), 1, 100);
            EXIT(FALSE);
        END;

        IF (ItemJrnTemplate_l.Type <> ItemJrnTemplate_l.Type::Transfer) THEN BEGIN
            ErrorText := COPYSTR(STRSUBSTNO(lText003, POSExchangeSetup."Item Journal Template"), 1, 100);
            EXIT(FALSE);
        END;

        ItemJrnBatch_l.RESET;
        ItemJrnBatch_l.SETRANGE(ItemJrnBatch_l."Journal Template Name", ItemJrnTemplate_l.Name);
        Ok_ := ItemJrnBatch_l.FINDFIRST;


        //VALIDAR NO CREAR MOV. DESPUES DE LA NOTA DE CREDITO 
        IF Ok_ THEN BEGIN
            IF NOT (ExchangeTrans.Status = ExchangeTrans.Status::"Liquidate CreditNote") THEN BEGIN
                ItemJournalLine_l.RESET;
                ItemJournalLine_l.SETRANGE(ItemJournalLine_l."Journal Template Name", ItemJrnBatch_l."Journal Template Name");
                ItemJournalLine_l.SETRANGE(ItemJournalLine_l."Journal Batch Name", ItemJrnBatch_l.Name);
                ItemJournalLine_l.DELETEALL;

                CLEAR(ItemJournalLine_l);
                ItemJournalLine_l.INIT;
                ItemJournalLine_l.VALIDATE("Journal Template Name", ItemJrnTemplate_l.Name);
                ItemJournalLine_l.VALIDATE("Journal Batch Name", ItemJrnBatch_l.Name);
                ItemJournalLine_l."Line No." := 10000;
                ItemJournalLine_l."Document Line No." := ExchangeTrans."Line No.";
                ItemJournalLine_l."Posting Date" := TODAY;
                ItemJournalLine_l."Entry Type" := ItemJournalLine_l."Entry Type"::Transfer;
                IF IsShip THEN
                    ItemJournalLine_l."Document Type" := ItemJournalLine_l."Document Type"::"Transfer Shipment"
                ELSE
                    ItemJournalLine_l."Document Type" := ItemJournalLine_l."Document Type"::"Transfer Receipt";
                ItemJournalLine_l.VALIDATE(ItemJournalLine_l."Item No.", ExchangeTrans."Item No.");
                ItemJournalLine_l.VALIDATE("Unit of Measure Code", ExchangeTrans."Unit of Measure");
                ItemJournalLine_l.VALIDATE(Quantity, ExchangeTrans.Quantity);
                ItemJournalLine_l.VALIDATE("Location Code", Location_l.Code);
                IF ItemJrnBatch_l."Reason Code" <> '' THEN
                    ItemJournalLine_l."Reason Code" := ItemJrnBatch_l."Reason Code"
                ELSE
                    ItemJournalLine_l."Reason Code" := ItemJrnTemplate_l."Reason Code";
                ItemJournalLine_l.Type := ItemJournalLine_l.Type::"Work Center";
                ItemJournalLine_l."Source Code" := ItemJrnTemplate_l."Source Code";
                ItemJournalLine_l.VALIDATE("New Location Code", NewLocation_l.Code);
                ItemJournalLine_l."Document No." := ExchangeTrans."Transfer Order No.";
                ItemJournalLine_l."Order Type" := ItemJournalLine_l."Order Type"::Transfer;
                ItemJournalLine_l."Order No." := ExchangeTrans."Transfer Order No.";
                ItemJournalLine_l."External Document No." := ExchangeTrans."Transfer Order No.";
                ItemJournalLine_l.INSERT(TRUE);
                Commit();
                ItemJournalLine_2.Get(ItemJournalLine_l."Journal Template Name", ItemJournalLine_l."Journal Batch Name", ItemJournalLine_l."Line No.");
                Ok_ := CODEUNIT.RUN(CODEUNIT::"Item Jnl.-Post", ItemJournalLine_2);
                //Continue?
                IF NOT Ok_ THEN BEGIN
                    ErrorText := COPYSTR(GETLASTERRORTEXT, 1, 100);
                    EXIT(FALSE);
                END;
                EXIT(TRUE);
            END ELSE BEGIN
                ErrorText := lText004;
                EXIT(FALSE);
            END;
        end ELSE BEGIN
            EXIT(Ok_);
        END;
    end;

    procedure NegAdjTUseItemJrnTemplate(ExchangeTrans: Record "FSN POS Exchange Transaction"; var ErrorText: Text[100]; IsShip: Boolean): Boolean
    var
        POSExchangeSetup: Record "FSN POS Exchange Setup";
        ItemJrnTemplate_l: Record "Item Journal Template";
        NewItemJrnTemplate_l: Record "Item Journal Template";
        ItemJrnBatch_l: Record "Item Journal Batch";
        lText001: Label 'Item Journal Template %1 not configured for products liquide';
        lText002: Label 'Item Journal Batch not found for liquide products';
        NewItemJrnBatch_l: Record "Item Journal Batch";
        ItemJournalLine_l: Record "Item Journal Line";
        Ok_: Boolean;
        lText003: Label 'Item Journal %1 is not type Item';
        Void: Boolean;
        Location_l: Record "Location";
        lText004: Label 'Error setup Store -Location or Item Batch';
        lText005: Label 'Is not possible liquidate credit note  in status %1';
        lText006: Label 'External Document and Total Amount Doc. cant be empty';
        lText007: Label '"Transfer Order No." or "Transfer-fo Code" cant be empty';
        lText008: Label 'Is not complete Exit Applied Inventory';
    begin
        ErrorText := '';
        IF (ExchangeTrans."Transfer Order No." = '') OR (ExchangeTrans."Transfer-to Code" = '') THEN BEGIN
            ErrorText := lText007;
            EXIT(FALSE);
        END;

        IF NOT (ExchangeTrans.Status = ExchangeTrans.Status::"Liquidate CreditNote") THEN BEGIN
            ErrorText := STRSUBSTNO(lText005, FORMAT(ExchangeTrans.Status));
            EXIT(FALSE);
        END;
        IF (ExchangeTrans."External Document No." = '') OR (ExchangeTrans."Amount Doc. Inc. VAT" = 0) THEN BEGIN
            ErrorText := lText006;
            EXIT(FALSE);
        END;

        IF NOT ExchangeTrans."Use Inventory" THEN
            EXIT(TRUE);

        //WVILLALTA13MAY19-
        IF NOT ExchangeTrans.Complete THEN BEGIN
            ErrorText := lText008;
            EXIT(FALSE);
        END;
        //WVILLALTA13MAY19+

        Ok_ := Location_l.GET(ExchangeTrans."Transfer-to Code");

        IF NOT Ok_ THEN BEGIN
            ErrorText := lText004;
            EXIT(FALSE);
        END;
        IF NegAdmjExists(ExchangeTrans, IsShip) THEN
            EXIT(TRUE);

        IF NOT (ExchangeTrans.Status = ExchangeTrans.Status::"Liquidate CreditNote") THEN BEGIN
            Ok_ := ValidateInventory(ExchangeTrans."Item No.", ExchangeTrans."Unit of Measure", ExchangeTrans.Quantity, Location_l.Code, ErrorText, IsShip);
            IF NOT Ok_ THEN
                EXIT(FALSE);
        end;

        Ok_ := POSExchangeSetup.GET(ExchangeTrans."POS Exchange No.");

        IF NOT ItemJrnTemplate_l.GET(POSExchangeSetup."Item Journal Template") THEN BEGIN
            ErrorText := COPYSTR(STRSUBSTNO(lText001, POSExchangeSetup."Item Journal Template"), 1, 100);
            EXIT(FALSE);
        END;
        ItemJrnBatch_l.RESET;
        ItemJrnBatch_l.SETRANGE(ItemJrnBatch_l."Journal Template Name", ItemJrnTemplate_l.Name);
        Ok_ := ItemJrnBatch_l.FINDFIRST;

        IF NOT NewItemJrnTemplate_l.GET('ITEM') OR NOT Ok_ THEN BEGIN
            ErrorText := COPYSTR(STRSUBSTNO(lText001, 'ITEM'), 1, 100);
            EXIT(FALSE);
        END;

        IF (NewItemJrnTemplate_l.Type <> NewItemJrnTemplate_l.Type::Item) THEN BEGIN
            ErrorText := COPYSTR(STRSUBSTNO(lText003, POSExchangeSetup."Item Journal Template"), 1, 100);
            EXIT(FALSE);
        END;

        Ok_ := NewItemJrnBatch_l.GET(NewItemJrnTemplate_l.Name, ItemJrnBatch_l.Name);

        IF Ok_ THEN BEGIN
            IF NOT (ExchangeTrans.Status = ExchangeTrans.Status::"Liquidate CreditNote") THEN BEGIN
                ItemJournalLine_l.RESET;
                ItemJournalLine_l.SETRANGE(ItemJournalLine_l."Journal Template Name", NewItemJrnBatch_l."Journal Template Name");
                ItemJournalLine_l.SETRANGE(ItemJournalLine_l."Journal Batch Name", NewItemJrnBatch_l.Name);
                ItemJournalLine_l.DELETEALL;

                CLEAR(ItemJournalLine_l);
                ItemJournalLine_l.INIT;
                ItemJournalLine_l.VALIDATE("Journal Template Name", NewItemJrnTemplate_l.Name);
                ItemJournalLine_l.VALIDATE("Journal Batch Name", NewItemJrnBatch_l.Name);
                ItemJournalLine_l."Line No." := 10000;
                ItemJournalLine_l."Document Line No." := ExchangeTrans."Line No.";
                ItemJournalLine_l."Posting Date" := TODAY;
                ItemJournalLine_l."Entry Type" := ItemJournalLine_l."Entry Type"::"Negative Adjmt.";
                ItemJournalLine_l.VALIDATE(ItemJournalLine_l."Item No.", ExchangeTrans."Item No.");
                ItemJournalLine_l.VALIDATE("Unit of Measure Code", ExchangeTrans."Unit of Measure");
                ItemJournalLine_l.VALIDATE(Quantity, ExchangeTrans.Quantity);
                ItemJournalLine_l.VALIDATE("Location Code", Location_l.Code);
                IF NewItemJrnBatch_l."Reason Code" <> '' THEN
                    ItemJournalLine_l."Reason Code" := NewItemJrnBatch_l."Reason Code"
                ELSE
                    ItemJournalLine_l."Reason Code" := NewItemJrnTemplate_l."Reason Code";
                ItemJournalLine_l.Type := ItemJournalLine_l.Type::"Work Center";
                ItemJournalLine_l."Source Code" := NewItemJrnTemplate_l."Source Code";
                ItemJournalLine_l."Document No." := ExchangeTrans."Transfer Order No.";
                ItemJournalLine_l."Order No." := ExchangeTrans."Transfer Order No.";
                ItemJournalLine_l."External Document No." := ExchangeTrans."Transfer Order No.";
                ItemJournalLine_l.INSERT(TRUE);
                COMMIT;
                Ok_ := CODEUNIT.RUN(CODEUNIT::"Item Jnl.-Post", ItemJournalLine_l);
                //Continue?
                IF NOT Ok_ THEN BEGIN
                    ErrorText := COPYSTR(GETLASTERRORTEXT, 1, 100);
                    EXIT(FALSE);
                END;
                EXIT(TRUE);
            END ELSE BEGIN
                ErrorText := lText004;
                EXIT(FALSE);
            END;
        end ELSE BEGIN
            EXIT(Ok_);
        END;
    end;

    procedure SetModifyMessageProcess(AllowedModifyMessage: Boolean)
    begin
        AllowedChangeMenssageProcess := AllowedModifyMessage;
    end;

    procedure SendHistoryNotUseInventory(pRec: Record "FSN POS Exchange Transaction")
    var
        ExchangeSetup_l: Record "FSN POS Exchange Setup";
        PostedExchange_l: Record "POS Posted Exchange Trans.";
        Item_l: Record "Item";
        PurchPrice_l: Record "Purchase Price";
        ItemUnitofMeasure_l: Record "Item Unit of Measure";
        PriceExitst: Boolean;
    begin
        //WVILLALTA 02.20 New
        IF pRec."Use Inventory" THEN
            EXIT;

        IF ExchangeSetup_l.GET(pRec."POS Exchange No.")
          AND NOT ExchangeSetup_l."Use Inventory"
          AND NOT pRec."Use Inventory" THEN BEGIN
            IF NOT PostedExchange_l.GET(pRec."Receipt No.", pRec."Transaction No.", pRec."Line No.", pRec."Store No.", pRec."POS Terminal No.") THEN BEGIN
                PostedExchange_l.INIT;
                PostedExchange_l.TRANSFERFIELDS(pRec);
                PostedExchange_l."Process Message" := '';
                PostedExchange_l."Posting Date" := TODAY;
                PostedExchange_l."User NAV" := USERID;

                IF PostedExchange_l."Unit Cost" = 0 THEN
                    IF Item_l.GET(PostedExchange_l."Item No.") THEN
                        IF ItemUnitofMeasure_l.GET(PostedExchange_l."Item No.", PostedExchange_l."Unit of Measure") THEN BEGIN
                            PriceExitst := FALSE;
                            PurchPrice_l.RESET;
                            PurchPrice_l.SETCURRENTKEY("Item No.", "Vendor No.", "Starting Date", "Currency Code", "Variant Code", "Unit of Measure Code", "Minimum Quantity");
                            PurchPrice_l.SETRANGE(PurchPrice_l."Item No.", PostedExchange_l."Item No.");
                            PurchPrice_l.SETRANGE(PurchPrice_l."Vendor No.", Item_l."Vendor No.");
                            PurchPrice_l.SETRANGE(PurchPrice_l."Unit of Measure Code", PostedExchange_l."Unit of Measure");
                            IF PurchPrice_l.FINDSET THEN
                                REPEAT
                                    IF ((PurchPrice_l."Starting Date" >= TODAY) OR (PurchPrice_l."Starting Date" = 0D)) AND
                                      ((PurchPrice_l."Ending Date" <= TODAY) OR (PurchPrice_l."Ending Date" = 0D)) AND
                                      (PurchPrice_l."Minimum Quantity" >= PostedExchange_l.Quantity) THEN BEGIN
                                        PriceExitst := TRUE;
                                        PostedExchange_l."Unit Cost" := PurchPrice_l."Direct Unit Cost";
                                    END;
                                UNTIL (PurchPrice_l.NEXT = 0) OR PriceExitst;

                            IF NOT PriceExitst THEN
                                PostedExchange_l."Unit Cost" := Item_l."Last Direct Cost" * ItemUnitofMeasure_l."Qty. per Unit of Measure";
                        END;

                PostedExchange_l.INSERT;
                pRec.GET(pRec."Receipt No.", pRec."Transaction No.", pRec."Line No.", pRec."Store No.", pRec."POS Terminal No.");
                pRec.DELETE;
            END;
        END;
    end;

    procedure CheckWSTableTransfer()
    var
        WSTable: Record "FSN WebServiceTable";
    begin
        //WVILLALTA 03.21-
        //WVILLALTA 03.21+
        WSTable.RESET;
        WSTable.SETCURRENTKEY("Status WS", Date, "Order Type");
        //WSTable.SETRANGE(WSTable."WS Request",'FSN_POST_TRANS');
        WSTable.SETRANGE(WSTable.Actions, WSTable.Actions::Transfer);
        WSTable.SETFILTER(WSTable."Status WS", '<>%1', WSTable."Status WS"::Transfered);
        IF WSTable.FIND('-') THEN
            REPEAT
                POSTWSUseItemJrnTem(WSTable);
            UNTIL WSTable.NEXT = 0;
    end;

    procedure ValidateNoExistsWStableLine(pPosLineTmp: Record "LSC POS Trans. Line" temporary; var pWsTable: Record "FSN WebServiceTable"; pCodeRequest: Code[10]; pCodeInvoiced: Code[10]; pIsReverse: Boolean): Boolean
    var
        LedgerEntries: Record "Item Ledger Entry";
        NoSeriesMgt: Codeunit "NoSeriesManagement";
    begin
        //WVILLALTA 03.21-
        //WVILLALTA 03.21+
        LedgerEntries.SETCURRENTKEY("Document No.", "Document Type", "Document Line No.");
        LedgerEntries.SETRANGE(LedgerEntries."Document No.", pPosLineTmp."Receipt No.");
        LedgerEntries.SETRANGE(LedgerEntries."Document Type", LedgerEntries."Document Type"::"Transfer Shipment");
        LedgerEntries.SETRANGE(LedgerEntries."Document Line No.", pPosLineTmp."Line No.");

        LedgerEntries.SETRANGE(LedgerEntries."Entry Type", LedgerEntries."Entry Type"::Transfer);
        LedgerEntries.SETRANGE(LedgerEntries."Item No.", pPosLineTmp.Number);
        IF pIsReverse THEN
            LedgerEntries.SETRANGE(LedgerEntries."Location Code", pCodeInvoiced)
        ELSE
            LedgerEntries.SETRANGE(LedgerEntries."Location Code", pCodeRequest);
        IF LedgerEntries.FINDFIRST THEN BEGIN
            IF LedgerEntries."Order No." <> '' THEN BEGIN
                pWsTable."Order No." := LedgerEntries."Order No.";
                pWsTable.MODIFY;
            END;
            EXIT(FALSE);
        END;
        IF pWsTable."Order No." = '' THEN BEGIN
            pWsTable."Order No." := NoSeriesMgt.GetNextNo('FSN_POST_T', TODAY, TRUE);//static serie
            pWsTable.MODIFY;
        END;
        EXIT(TRUE);
    end;

    procedure POSTWSUseItemJrnTem(pWSTable: Record "FSN WebServiceTable")
    var
        ItemJrnTemplate_l: Record "Item Journal Template";
        ItemJrnBatch_l: Record "Item Journal Batch";
        ItemJournalLine_l: Record "Item Journal Line";
        Item_l: Record "Item";
        Ok_: Boolean;
        Void: Boolean;
        FromLocation: Record "Location";
        ToLocation: Record "Location";
        StoreRequest: Record "LSC Store";
        StoreInvoice: Record "LSC Store";
        TransSalesEntries: Record "LSC Trans. Sales Entry";
        Transaction: Record "LSC Transaction Header";
        NoSeriesMgt: Codeunit "NoSeriesManagement";
        IsSend: Boolean;
        CountLines: Integer;
        SumGrossAmt: Decimal;
        Line: Integer;
        lTxt1: Label 'Posted sucessfull. %1 Lines';
        lTxt2: Label '%1 transfered of %2, %3 lines. ';
        lTxt3: Label '%1 not exists %2';
        ItemCode: Code[20];
        POSLineTmp: Record "LSC POS Trans. Line" temporary;
        ItemTotalsTmp: Record "FSN Inventory Internal Log" temporary;
        ErrTxt: Text;
        lTxt4: Label 'Key transaction not found';
        lTxt5: Label 'Item Journal not found';
        lTxt6: Label '%1 is not valid. %2';
        lTxt7: Label 'Error %1 setup';
        lTxt8: Label 'No inventory %1 %2';
    begin
        //WVILLALTA 03.21-
        //WVILLALTA 03.21+
        CLEAR(Ok_);
        CLEAR(CountLines);
        CLEAR(SumGrossAmt);
        CLEAR(IsSend);

        IF (pWSTable."Key Number Text 1" = 0) OR (pWSTable."Store Selected" = '') OR (pWSTable."Value Text 1" = '') THEN BEGIN
            UpdErrorMessageWSTable(pWSTable, lTxt4);
            EXIT;
        END;

        IF ItemJrnTemplate_l.GET('TRANSFERIN') AND (ItemJrnTemplate_l.Type = ItemJrnTemplate_l.Type::Transfer) THEN
            IF ItemJrnBatch_l.GET(ItemJrnTemplate_l.Name, 'RECETTRANS') THEN
                Ok_ := TRUE;
        IF NOT Ok_ THEN BEGIN
            UpdErrorMessageWSTable(pWSTable, lTxt5);
            EXIT;
        END;

        IF NOT Transaction.GET(pWSTable."Store Selected", pWSTable."Value Text 1", pWSTable."Key Number Text 1") THEN BEGIN
            UpdErrorMessageWSTable(pWSTable, STRSUBSTNO(lTxt3, Transaction.TABLECAPTION, pWSTable."Store Selected"));
            EXIT;
        END;
        IF NOT (Transaction."Entry Status" = Transaction."Entry Status"::" ") OR
          (Transaction."Transaction Type" <> Transaction."Transaction Type"::Sales) THEN BEGIN
            UpdErrorMessageWSTable(pWSTable, STRSUBSTNO(lTxt6, Transaction.FIELDCAPTION(Transaction."Transaction Type"), Transaction.TABLECAPTION));
            EXIT;
        END;
        /*IF pWSTable."Order No." = '' THEN BEGIN
          pWSTable."Order No." := NoSeriesMgt.GetNextNo('FSN_POST_T',TODAY,TRUE);//static serie
          pWSTable.MODIFY;
        END;*/

        CLEAR(Ok_);
        IF StoreRequest.GET(pWSTable.Store) AND (pWSTable.Store <> '') THEN
            IF StoreInvoice.GET(pWSTable."Store Selected") AND (pWSTable."Store Selected" <> '') THEN
                IF FromLocation.GET(StoreRequest."Location Code") AND (StoreRequest."Location Code" <> '') THEN
                    IF ToLocation.GET(StoreInvoice."Location Code") AND (StoreInvoice."Location Code" <> '') THEN
                        Ok_ := TRUE;
        IF NOT Ok_ THEN BEGIN
            UpdErrorMessageWSTable(pWSTable, STRSUBSTNO(lTxt7, ToLocation.TABLECAPTION));
            EXIT;
        END;

        POSLineTmp.RESET;
        POSLineTmp.DELETEALL;
        CLEAR(POSLineTmp);
        ItemTotalsTmp.RESET;
        ItemTotalsTmp.DELETEALL;
        CLEAR(ItemTotalsTmp);

        TransSalesEntries.RESET;
        TransSalesEntries.SETRANGE(TransSalesEntries."Store No.", Transaction."Store No.");
        TransSalesEntries.SETRANGE(TransSalesEntries."POS Terminal No.", Transaction."POS Terminal No.");
        TransSalesEntries.SETRANGE(TransSalesEntries."Transaction No.", Transaction."Transaction No.");
        IF NOT TransSalesEntries.FINDSET THEN BEGIN
            UpdErrorMessageWSTable(pWSTable, STRSUBSTNO(lTxt3, TransSalesEntries.TABLECAPTION, ''));
            EXIT;
        END;
        REPEAT
            CLEAR(Ok_);
            Ok_ := Item_l.GET(TransSalesEntries."Item No.");
            IF Ok_ THEN BEGIN
                CLEAR(POSLineTmp);
                POSLineTmp."Receipt No." := TransSalesEntries."Receipt No.";
                POSLineTmp."Line No." := TransSalesEntries."Line No.";
                POSLineTmp."Entry Type" := POSLineTmp."Entry Type"::Item;
                POSLineTmp.Number := TransSalesEntries."Item No.";
                POSLineTmp."Unit of Measure" := Item_l."Sales Unit of Measure";
                POSLineTmp.Quantity := TransSalesEntries.Quantity;
                POSLineTmp.Marked := Item_l."LSC No Stock Posting";//Not transfer
                POSLineTmp.Amount := TransSalesEntries."Total Rounded Amt.";
                POSLineTmp.INSERT;
                IF NOT ItemTotalsTmp.GET(TransSalesEntries."Item No.") THEN BEGIN
                    ItemTotalsTmp."No." := TransSalesEntries."Item No.";
                    ItemTotalsTmp.Inventory := 0;
                    ItemTotalsTmp.INSERT;
                END;
                ItemTotalsTmp.Inventory += TransSalesEntries.Quantity;
                ItemTotalsTmp.MODIFY;
            END;
        UNTIL (TransSalesEntries.NEXT = 0) OR NOT Ok_;

        pWSTable.GET(pWSTable.LastSlipNo);
        IF NOT Ok_ THEN BEGIN
            UpdErrorMessageWSTable(pWSTable, STRSUBSTNO(lTxt3, ItemCode, Item_l.TABLECAPTION));
            EXIT;
        END;

        POSLineTmp.RESET;
        IF POSLineTmp.FIND('-') THEN
            REPEAT
                IF POSLineTmp.Marked THEN BEGIN
                    CountLines += 1;
                    SumGrossAmt += POSLineTmp.Amount;
                END ELSE BEGIN
                    CLEAR(IsSend);
                    IsSend := POSLineTmp.Quantity <= 0;

                    CLEAR(ErrTxt);
                    CLEAR(Ok_);
                    ItemCode := POSLineTmp.Number;
                    Ok_ := ItemTotalsTmp.GET(POSLineTmp.Number);
                    IF Ok_ THEN
                        IF IsSend THEN
                            Ok_ := ValidateInventoryExt(POSLineTmp.Number, POSLineTmp."Unit of Measure", -ItemTotalsTmp.Inventory, FromLocation.Code, ErrTxt, TRUE)
                        ELSE
                            Ok_ := ValidateInventoryExt(POSLineTmp.Number, POSLineTmp."Unit of Measure", ItemTotalsTmp.Inventory, ToLocation.Code, ErrTxt, TRUE);

                    IF Ok_ THEN
                        IF ValidateNoExistsWStableLine(POSLineTmp, pWSTable, FromLocation.Code, ToLocation.Code, (NOT IsSend)) THEN BEGIN

                            ItemJournalLine_l.RESET;
                            ItemJournalLine_l.SETRANGE(ItemJournalLine_l."Journal Template Name", ItemJrnBatch_l."Journal Template Name");
                            ItemJournalLine_l.SETRANGE(ItemJournalLine_l."Journal Batch Name", ItemJrnBatch_l.Name);
                            ItemJournalLine_l.DELETEALL;

                            CLEAR(ItemJournalLine_l);
                            ItemJournalLine_l.INIT;
                            ItemJournalLine_l.VALIDATE("Journal Template Name", ItemJrnTemplate_l.Name);
                            ItemJournalLine_l.VALIDATE("Journal Batch Name", ItemJrnBatch_l.Name);
                            ItemJournalLine_l."Line No." := POSLineTmp."Line No.";
                            ItemJournalLine_l."Document Line No." := POSLineTmp."Line No.";
                            Line := POSLineTmp."Line No.";
                            ItemJournalLine_l."Posting Date" := TODAY;
                            ItemJournalLine_l."Entry Type" := ItemJournalLine_l."Entry Type"::Transfer;
                            ItemJournalLine_l."Document Type" := ItemJournalLine_l."Document Type"::"Transfer Shipment";

                            ItemJournalLine_l.VALIDATE(ItemJournalLine_l."Item No.", POSLineTmp.Number);
                            ItemJournalLine_l.VALIDATE("Unit of Measure Code", Item_l."Sales Unit of Measure");
                            ItemJournalLine_l.VALIDATE(Quantity, ABS(POSLineTmp.Quantity));//positive ever

                            IF IsSend THEN
                                ItemJournalLine_l.VALIDATE("Location Code", FromLocation.Code)
                            ELSE
                                ItemJournalLine_l.VALIDATE("Location Code", ToLocation.Code);

                            ItemJournalLine_l."Reason Code" := ItemJrnBatch_l."Reason Code";
                            ItemJournalLine_l.Type := ItemJournalLine_l.Type::"Work Center";
                            ItemJournalLine_l."Source Code" := ItemJrnTemplate_l."Source Code";

                            IF IsSend THEN
                                ItemJournalLine_l.VALIDATE("New Location Code", ToLocation.Code)
                            ELSE
                                ItemJournalLine_l.VALIDATE("New Location Code", FromLocation.Code);
                            ItemJournalLine_l."Document No." := pWSTable.LastSlipNo;
                            ItemJournalLine_l."Order Type" := ItemJournalLine_l."Order Type"::Transfer;
                            ItemJournalLine_l."Order No." := pWSTable."Order No.";
                            ItemJournalLine_l."External Document No." := pWSTable."Order No.";
                            ItemJournalLine_l.INSERT(TRUE);
                            COMMIT;
                            Ok_ := CODEUNIT.RUN(CODEUNIT::"Item Jnl.-Post", ItemJournalLine_l);
                            //Continue?
                            IF Ok_ AND
                              NOT ValidateNoExistsWStableLine(POSLineTmp, pWSTable, FromLocation.Code, ToLocation.Code, (NOT IsSend)) THEN BEGIN

                                CountLines += 1;
                                SumGrossAmt += POSLineTmp.Amount;
                            END;
                        END ELSE BEGIN
                            CountLines += 1;
                            SumGrossAmt += POSLineTmp.Amount;
                        END;
                END;
            UNTIL (POSLineTmp.NEXT = 0) OR NOT Ok_;

        pWSTable.GET(pWSTable.LastSlipNo);
        IF NOT Ok_ THEN BEGIN
            IF ErrTxt <> '' THEN
                UpdErrorMessageWSTable(pWSTable, ErrTxt)
            ELSE
                UpdErrorMessageWSTable(pWSTable, STRSUBSTNO(lTxt8, ItemCode, Item_l.TABLECAPTION));
        END ELSE BEGIN
            IF SumGrossAmt = Transaction."Gross Amount" THEN BEGIN
                pWSTable."Status WS" := pWSTable."Status WS"::Transfered;
                pWSTable."Last Error Text" := STRSUBSTNO(lTxt1, FORMAT(CountLines));
            END ELSE
                pWSTable."Last Error Text" := STRSUBSTNO(lTxt2, FORMAT(SumGrossAmt), FORMAT(Transaction."Gross Amount"), FORMAT(Line));
            pWSTable.MODIFY;
        END;

    end;

    procedure UpdErrorMessageWSTable(pWSTable: Record "FSN WebServiceTable"; pTxt: Text[100])
    begin
        //WVILLALTA 03.21-
        //WVILLALTA 03.21+
        IF pWSTable."Last Error Text" <> pTxt THEN BEGIN
            pWSTable."Last Error Text" := pTxt;
            pWSTable.MODIFY;
        END;
    end;

    local procedure UpdateItemsBC()
    var
        POSTransExch: Record "FSN POS Exchange Transaction";
        SetupExch: Record "FSN POS Exchange Setup";
        Transaction: Record "FSN POS Exchange Transaction";
        Eraser: Boolean;
        POSExch2: Record "FSN POS Exchange Transaction";
        POSExchHistory: Record "POS Posted Exchange Trans.";
    begin

        SetupExch.RESET;
        SetupExch.SETRANGE(SetupExch."Use Inventory", FALSE);
        IF SetupExch.FIND('-') THEN
            REPEAT
                SetupExch."Use Inventory" := TRUE;
                SetupExch.MODIFY;
            UNTIL SetupExch.NEXT = 0;


        POSTransExch.RESET;
        POSTransExch.SETRANGE(POSTransExch."Use Inventory", FALSE);
        IF POSTransExch.FIND('-') THEN
            REPEAT

                POSExch2 := POSTransExch;
                POSExch2."Use Inventory" := TRUE;
                POSExch2.MODIFY;
            UNTIL POSTransExch.NEXT = 0;


        POSTransExch.RESET;
        POSTransExch.SETRANGE(POSTransExch.Status, POSTransExch.Status::Released);
        POSTransExch.SETRANGE(POSTransExch."Use Inventory", FALSE);
        IF POSTransExch.FIND('-') THEN
            REPEAT

                IF SetupExch.GET(POSTransExch."POS Exchange No.") THEN BEGIN
                    //IF (POSTransExch."Use Inventory" <> SetupExch."Use Inventory") OR
                    IF (POSTransExch."Transaction Date" = 0D) THEN BEGIN

                        POSTransExch."Use Inventory" := TRUE;//SetupExch."Use Inventory";

                        IF POSTransExch."Transaction Date" = 0D THEN BEGIN
                            IF Transaction.GET(POSTransExch."Store No.", POSTransExch."POS Terminal No.", POSTransExch."Transaction No.") THEN
                                POSTransExch."Transaction Date" := Transaction."Posting Date";
                        END;

                        POSTransExch.MODIFY;
                    END;
                END;

            UNTIL POSTransExch.NEXT = 0;

        POSTransExch.RESET;
        POSTransExch.SETRANGE(POSTransExch.Status, POSTransExch.Status::Released);
        POSTransExch.SETRANGE(POSTransExch."Transaction No.", 0);
        IF POSTransExch.FIND('-') THEN
            REPEAT

                Eraser := FALSE;

                POSExch2.RESET;
                POSExch2.SETRANGE(POSExch2."Receipt No.", POSTransExch."Receipt No.");
                POSExch2.SETRANGE(POSExch2."Line No.", POSTransExch."Line No.");
                POSExch2.SETRANGE(POSExch2."Store No.", POSTransExch."Store No.");
                POSExch2.SETFILTER(POSExch2."Transaction No.", '>0');
                IF POSExch2.FINDFIRST THEN BEGIN
                    POSTransExch.DELETE;
                    Eraser := TRUE;
                END;

                POSExchHistory.RESET;
                POSExchHistory.SETRANGE(POSExchHistory."Receipt No.", POSTransExch."Receipt No.");
                POSExchHistory.SETRANGE(POSExchHistory."Store No.", POSTransExch."Store No.");
                POSExchHistory.SETRANGE(POSExchHistory."Line No.", POSTransExch."Line No.");
                POSExchHistory.SETFILTER(POSExchHistory."Item No.", '<>%1', '');
                IF NOT Eraser THEN
                    IF POSExchHistory.FINDFIRST THEN BEGIN
                        POSTransExch.DELETE;
                        Eraser := TRUE;
                    END;

                IF NOT Eraser THEN BEGIN
                    Transaction.RESET;
                    Transaction.SETRANGE(Transaction."Store No.", POSTransExch."Store No.");
                    Transaction.SETRANGE(Transaction."Receipt No.", POSTransExch."Receipt No.");
                    IF Transaction.FINDFIRST THEN BEGIN
                        Transaction.Delete();
                        //IF POSExch2.INSERT() THEN;
                    END;
                END;

            UNTIL POSTransExch.NEXT = 0;
        COMMIT;
    end;

    [EventSubscriber(ObjectType::Page, Page::"Purchase Credit Memo", 'OnDeleteRecordEvent', '', true, true)]
    local procedure "Purchase Credit Memo_OnDeleteRecordEvent"
    (
        var Rec: Record "Purchase Header";
        var AllowDelete: Boolean
    )
    var
        CanjeTable: Record "FSN POS Exchange Transaction";
    begin
        CanjeTable.Reset();
        CanjeTable.SetRange("External Document No.", Rec."No.");
        if CanjeTable.Find('-') then begin
            repeat
                CanjeTable.Status := CanjeTable.Status::"Exit Applied";
                CanjeTable."External Document No." := '';
                CanjeTable."Amount Doc. Inc. VAT" := 0.0;
                CanjeTable.Modify(true);
            until CanjeTable.Next() = 0;
        end;
    end;

    [EventSubscriber(ObjectType::Page, Page::"Purch. Cr. Memo Subform", 'OnDeleteRecordEvent', '', true, true)]
    local procedure "Purch. Cr. Memo Subform_OnDeleteRecordEvent"
    (
        var Rec: Record "Purchase Line";
        var AllowDelete: Boolean
    )
    var
        PurchaseHeader: Record "Purchase Header";
        CanjeTable: Record "FSN POS Exchange Transaction";

    begin
        PurchaseHeader.Reset();
        PurchaseHeader.SetRange("No.", Rec."Document No.");
        if PurchaseHeader.FindFirst() then begin
            CanjeTable.Reset();
            CanjeTable.SetRange("External Document No.", PurchaseHeader."No.");
            CanjeTable.SetRange("Item No.", Rec."No.");
            CanjeTable.SetRange("Unit of Measure", Rec."Unit of Measure Code");
            if CanjeTable.Find('-') then begin
                repeat
                    CanjeTable.Status := CanjeTable.Status::"Exit Applied";
                    CanjeTable."External Document No." := '';
                    CanjeTable."Amount Doc. Inc. VAT" := 0.0;
                    CanjeTable.Modify(true);
                until CanjeTable.Next() = 0;
            end;
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Purch.-Post", 'OnAfterPostPurchaseDoc', '', true, true)]
    local procedure "Purch.-Post_OnAfterPostPurchaseDoc"
    (
        var PurchaseHeader: Record "Purchase Header";
        var GenJnlPostLine: Codeunit "Gen. Jnl.-Post Line";
        PurchRcpHdrNo: Code[20];
        RetShptHdrNo: Code[20];
        PurchInvHdrNo: Code[20];
        PurchCrMemoHdrNo: Code[20];
        CommitIsSupressed: Boolean
    )
    var
        CanjeTable: Record "FSN POS Exchange Transaction";
    begin
        CanjeTable.Reset();
        CanjeTable.SetRange("External Document No.", PurchaseHeader."No.");
        if CanjeTable.Find('-') then begin
            repeat
                CanjeTable.Status := CanjeTable.Status::"Liquidate CreditNote";
                CanjeTable."External Document No." := PurchCrMemoHdrNo;
                CanjeTable.Modify(true);
            until CanjeTable.Next() = 0;
        end;
    end;

    /*-------------Factura Venta----------------*/
    [EventSubscriber(ObjectType::Page, Page::"Sales Invoice Subform", 'OnDeleteRecordEvent', '', true, true)]
    local procedure "Sales Invoice Subform_OnDeleteRecordEvent"
    (
        var Rec: Record "Sales Line";
        var AllowDelete: Boolean
    )
    var
        SalesHeader: Record "Sales Header";
        CanjeTable: Record "FSN POS Exchange Transaction";

    begin
        SalesHeader.Reset();
        SalesHeader.SetRange("No.", Rec."Document No.");
        if SalesHeader.FindFirst() then begin
            CanjeTable.Reset();
            CanjeTable.SetRange("External Document No.", SalesHeader."No.");
            CanjeTable.SetRange("Item No.", Rec."No.");
            CanjeTable.SetRange("Unit of Measure", Rec."Unit of Measure Code");
            if CanjeTable.Find('-') then begin
                repeat
                    CanjeTable.Status := CanjeTable.Status::"Exit Applied";
                    CanjeTable."External Document No." := '';
                    CanjeTable."Amount Doc. Inc. VAT" := 0.0;
                    CanjeTable.Modify(true);
                until CanjeTable.Next() = 0;
            end;
        end;
    end;



    [EventSubscriber(ObjectType::Page, Page::"Sales Invoice", 'OnDeleteRecordEvent', '', true, true)]
    local procedure "Sales Invoice_OnDeleteRecordEvent"
    (
        var Rec: Record "Sales Header";
        var AllowDelete: Boolean
    )
    var
        CanjeTable: Record "FSN POS Exchange Transaction";
    begin
        CanjeTable.Reset();
        CanjeTable.SetRange("External Document No.", Rec."No.");
        if CanjeTable.Find('-') then begin
            repeat
                CanjeTable.Status := CanjeTable.Status::"Exit Applied";
                CanjeTable."External Document No." := '';
                CanjeTable."Amount Doc. Inc. VAT" := 0.0;
                CanjeTable.Modify(true);
            until CanjeTable.Next() = 0;
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
        CanjeTable: Record "FSN POS Exchange Transaction";
    begin
        CanjeTable.Reset();
        CanjeTable.SetRange("External Document No.", SalesHeader."No.");
        if CanjeTable.Find('-') then begin
            repeat
                CanjeTable.Status := CanjeTable.Status::"Liquidate CreditNote";
                CanjeTable."External Document No." := SalesInvHdrNo;
                CanjeTable.Modify(true);
            until CanjeTable.Next() = 0;
        end;
    end;
}
codeunit 50027 "FSN Delivery Inventory Mgt."
{
    TableNo = "LSC POS Menu Line";
    trigger OnRun()
    var
        POSTransLinel: Record "LSC POS Trans. Line";
        POSTransactionl: Record "LSC POS Transaction";
    begin
        GlobalRec.Copy(Rec);
        case Command of
            'FSN_GET_INVENTORY'://Internal code function, is not menu button
                GetInventoryLookUpServer(Rec);
            'LOOKUPINV'://Internal code function, is not menu button
                InventoryLookup(Rec);
            'LOOKUPINVLINE':
                InventoryLookupLine(Rec);
            'SUGESTCUST':
                CustomValidateCustomer(Rec);
            'FSN_VALIDATEINVENTORY_ECC':
                ValidateInventoryECC(Rec);
        end;
    end;


    var


        POSSESSION: Codeunit "LSC POS Session";
        POSTransaction: Codeunit "LSC POS Transaction";
        POSGUI: Codeunit "LSC POS GUI";
        FSNDelStoreLink: Codeunit "FSN Delivery Store Link";
        DeliveryOrder: Record "LSC Delivery Order";
        DeliveryStreet: Record "LSC Delivery Street";
        InventoryLookUpTableTmp: Record "LSC Inventory Lookup Table" temporary;
        InventoryLookUpTable: Record "LSC Inventory Lookup Table";
        LinesCount: Integer;
        SRFRSECURITY: Text;
        SRFREQUEST: Text;
        Text000: Label 'Cant process inventory lookup, Inventory is show at hour %1 ';
        Text001: Label '%1 [%2] \';
        Text002: Label 'Generic error. unknown';
        Text003: Label 'Inventory incomplete, change store suggest \%1 %2';
        Text008: Label 'Inventory is not enough for %1 items.\Not store suggest.';
        Text009: Label 'Cant be changed store %1';
        GlobalRec: Record "LSC POS Menu Line";
        GlobalError: Boolean;
        GlobalText: Text;
        RecRef_g: RecordRef;
        DeliveryOrderManagement: Codeunit "LSC Delivery Order Management";


    procedure CustomValidateCustomer(cMenuLine: Record "LSC POS Menu Line")
    var
        myInt: Integer;
        PosTrans: Record "LSC POS Transaction";
        CustLocal: Record Customer;
        rMembersAccount: Record "LSC Member Account";
        DelFuncExtend: Codeunit "FSN Delivery Functions Extend";
        FirstCard: Text[100];
        TEXT000: Label 'Se encontro un cliente asociado\ %1 \Cargar Cliente?';
        TEXT001: Label 'No se encontro ningun cliente con este numero';
    begin
        PosTrans.Reset();
        PosTrans.SetCurrentKey("Receipt No.");
        PosTrans.SetRange("Store No.", POSSESSION.StoreNo());
        PosTrans.SetRange("POS Terminal No.", POSSESSION.TerminalNo());
        PosTrans.SetRange("Receipt No.", cMenuLine."Current-RECEIPT");
        if PosTrans.FindFirst() then begin
            if not PosTrans."Sale Is Return Sale" then begin
                IF PosTrans."Sell-to Contact No." <> '' THEN BEGIN
                    CustLocal.RESET;
                    CustLocal.SETRANGE("Phone No.", PosTrans."Sell-to Contact No.");
                    IF CustLocal.FINDFIRST THEN BEGIN
                        if CustLocal."Customer Disc. Group" <> 'VIP' then begin
                            POSTransaction.SelectCustPressed(CustLocal."No.");
                        end else begin
                            DelFuncExtend.GetFirstCardSuggest(CustLocal."No.", FirstCard);
                            IF FirstCard <> '' THEN BEGIN
                                POSTransaction.InputMemberCard(FirstCard);
                                EXIT;
                            END;
                        end;
                    END
                    ELSE BEGIN
                        POSGUI.PosMessage(TEXT001);
                        EXIT;
                    END;
                END;
            end;
        end;
    end;

    procedure InventoryLookup(pMenuLine: Record "LSC POS Menu Line")
    var
        POSCtrl: Codeunit "LSC POS Control Interface";
        lRecordID: RecordId;
        lRecordRef: RecordRef;
        RecRef: RecordRef;
        ItemFilt: Record Item;
        POSTransLineTemp: Record "LSC POS Trans. Line" temporary;
        POSTrans: Codeunit "LSC POS Transaction";
        InvLoTable: Record "LSC Inventory Lookup Table";
        InvLoTableTemp: Record "LSC Inventory Lookup Table" temporary;
    begin

        Clear(POSTransLineTemp);
        POSTransLineTemp.DeleteAll();
        Clear(InvLoTableTemp);
        InvLoTableTemp.DeleteAll();
        if POSCtrl.GetActiveLookupRecordID(lRecordID) then begin
            if lRecordRef.Get(lRecordID) then begin
                lRecordRef.SetTable(ItemFilt);
                POSTransLineTemp.Init();
                POSTransLineTemp."Entry Type" := POSTransLineTemp."Entry Type"::Item;
                POSTransLineTemp."Line No." := 1000;
                POSTransLineTemp."Receipt No." := pMenuLine."Current-RECEIPT";
                POSTransLineTemp."Store No." := POSSESSION.StoreNo();
                POSTransLineTemp."POS Terminal No." := pMenuLine."Current-POSID";
                POSTransLineTemp.Number := ItemFilt."No.";
                POSTransLineTemp.Description := ItemFilt.Description;
                POSTransLineTemp."Unit of Measure" := ItemFilt."Base Unit of Measure";
                POSTransLineTemp."Variant Code" := '';
                POSTransLineTemp."Entry Status" := POSTransLineTemp."Entry Status"::" ";
                POSTransLineTemp.Insert();

                ValidateServerInventoryLine(POSTransLineTemp, 1);

                InvLoTable.Reset();
                InvLoTable.SetRange("Item No.", ItemFilt."No.");
                IF InvLoTable.Find('-') THEN
                    repeat
                        InvLoTableTemp.Init();
                        InvLoTableTemp := InvLoTable;
                        InvLoTableTemp.Insert();
                    until InvLoTable.Next() = 0;
                RecRef.GETTABLE(InvLoTableTemp);
                POSTrans.LookUpEx(true, 'INV_LU2', '', RecRef);
            END;
        end;
    end;

    procedure InventoryLookupLine(pMenuLine: Record "LSC POS Menu Line")
    var
        myInt: Integer;
        EPosCtrl: Codeunit "LSC POS Control Interface";
        OrderN: Text;
        POSLines: Codeunit "LSC POS Trans. Lines";
        POSLine_l: Record "LSC POS Trans. Line";
        POSTransLineTemp: Record "LSC POS Trans. Line" temporary;
        InvLoTableTemp: Record "LSC Inventory Lookup Table" temporary;
        ItemFilt: Record Item;
        InvLoTable: Record "LSC Inventory Lookup Table";
        RecRef: RecordRef;
        POSTrans: Codeunit "LSC POS Transaction";

    begin
        /*Clear(POSTransLineTemp);
        POSTransLineTemp.DeleteAll();
        Clear(InvLoTableTemp);
        InvLoTableTemp.DeleteAll();
        POSLines.GetCurrentLine(POSLine_l);
        if (POSLine_l."Entry Type" = POSLine_l."Entry Type"::Item) then begin
            if ItemFilt.Get(POSLine_l.Number) then begin
                POSTransLineTemp.Init();
                POSTransLineTemp."Entry Type" := POSTransLineTemp."Entry Type"::Item;
                POSTransLineTemp."Line No." := 1000;
                POSTransLineTemp."Receipt No." := pMenuLine."Current-RECEIPT";
                POSTransLineTemp."Store No." := POSSESSION.StoreNo();
                POSTransLineTemp."POS Terminal No." := pMenuLine."Current-POSID";
                POSTransLineTemp.Number := ItemFilt."No.";
                POSTransLineTemp.Description := ItemFilt.Description;
                POSTransLineTemp."Unit of Measure" := ItemFilt."Base Unit of Measure";
                POSTransLineTemp."Variant Code" := '';
                POSTransLineTemp."Entry Status" := POSTransLineTemp."Entry Status"::" ";
                POSTransLineTemp.Insert();

                ValidateServerInventoryLine(POSTransLineTemp, 1);

                InvLoTable.Reset();
                InvLoTable.SetRange("Item No.", ItemFilt."No.");
                IF InvLoTable.Find('-') THEN
                    repeat
                        InvLoTableTemp.Init();
                        InvLoTableTemp := InvLoTable;
                        InvLoTableTemp.Insert();
                    until InvLoTable.Next() = 0;
                RecRef.GETTABLE(InvLoTableTemp);
                POSTrans.LookUpEx(true, 'INV_LU2', '', RecRef);
                EXIT;
            end;
        end;*/
    end;


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC Data Table SourceExpr Util", 'OnGetSourceExpr', '', true, true)]
    local procedure "LSC Data Table SourceExpr Util_OnGetSourceExpr"
    (
        var Handled: Boolean;
        var returnTxt: Text;
        var pLookupSetupID: Code[10];
        var pSourceExprID: Code[10];
        var pRecRef: RecordRef;
        var pPosTransLine: Record "LSC POS Trans. Line"
    )
    var
        PosTransLineTmp: Record "LSC POS Trans. Line" temporary;
        InvLoTable: Record "LSC Inventory Lookup Table";
        POSTrans: Codeunit "LSC POS Transaction";
        RetailSetup: Record "LSC Retail Setup";
        FSNDeliveryInvMgt: codeunit "FSN Delivery Inventory Mgt.";
        delOrder: Record "LSC Delivery Order";
        deliverOrTemp: Record "LSC Delivery Order" temporary;
    begin
        clear(RecRef_g);
        if pSourceExprID = 'SUCURSAL' then begin
            returnTxt := TagStoreName(pRecRef);
            Handled := true;
            exit
        end;

        IF pSourceExprID = 'HO-STRLINK' THEN begin
            if POSSESSION.GetValue('CURRORDER') <> '' then begin
                if delOrder.Get(POSSESSION.GetValue('CURRORDER')) then begin
                    pRecRef.SetTable(deliverOrTemp);
                    IF (delOrder.Address <> deliverOrTemp.Address) THEN
                        delOrder.Address := deliverOrTemp.Address;
                    IF (delOrder."Address 2" <> deliverOrTemp."Address 2") THEN
                        delOrder."Address 2" := deliverOrTemp."Address 2";
                    IF (delOrder.City <> deliverOrTemp.City) THEN
                        delOrder.City := deliverOrTemp.City;
                    IF delOrder."FSN Street Name" <> deliverOrTemp."FSN Street Name" THEN
                        delOrder."FSN Street Name" := deliverOrTemp."FSN Street Name";
                    IF delOrder."FSN Alter Key" <> deliverOrTemp."FSN Alter Key" THEN
                        delOrder."FSN Alter Key" := deliverOrTemp."FSN Alter Key";
                    IF delOrder.Directions <> deliverOrTemp.Directions THEN
                        delOrder.Directions := deliverOrTemp.Directions;
                    delOrder.Modify();
                end;
            end;
        end;

        /*if pSourceExprID = 'INV_ITEM' then begin
            if RetailSetup.FindFirst() then
                if RetailSetup."FSN Is Local Receipt" then begin
                    pRecRef.SetTable(PosTransLineTmp);
                    if (PosTransLineTmp."Entry Type" = PosTransLineTmp."Entry Type"::Item) AND (PosTransLineTmp."Entry Status" <> PosTransLineTmp."Entry Status"::Voided) then
                        if PosTransLineTmp."Receipt No." = POSTrans.GetReceiptNo() then begin
                            if delOrder.Get(POSTrans.GetReceiptNo()) then begin
                                FSNDeliveryInvMgt.ValidateServerInventoryLine(PosTransLineTmp, 1);
                                InvLoTable.Reset();
                                InvLoTable.SetCurrentKey("Item No.", "Variant Code", "Store No.");
                                InvLoTable.SetRange("Item No.", PosTransLineTmp.Number);
                                InvLoTable.SetRange("Variant Code", PosTransLineTmp."Variant Code");
                                InvLoTable.SetRange("Store No.", delOrder."Restaurant No.");
                                if InvLoTable.FindFirst() then begin
                                    returnTxt := Format(InvLoTable."Net Inventory");
                                    Handled := true;
                                    exit
                                end;
                            end;
                        end;
                end;
        end;*/
    end;

    procedure TagStoreName(pRecRefTemp: RecordRef): text
    var
        fieldRef: FieldRef;
        InvLoTable: Record "LSC Inventory Lookup Table";
        Store: Code[20];
        StoreLick: Record "LSC Store";

    begin
        FieldRef := pRecRefTemp.Field(InvLoTable.FieldNo("Store No."));
        Store := FieldRef.Value;

        StoreLick.Reset();
        IF StoreLick.Get(Store) THEN
            EXIT(StoreLick.Name)
        ELSE
            exit('');
    end;


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnAfterInsertItemLine', '', true, true)]
    local procedure "LSC POS Transaction Events_OnAfterInsertItemLine"
    (
        var POSTransaction: Record "LSC POS Transaction";
        var POSTransLine: Record "LSC POS Trans. Line";
        var CurrInput: Text
    )
    var
        FSNDeliveryInvMgt: codeunit "FSN Delivery Inventory Mgt.";
        RetailSetup: Record "LSC Retail Setup";
    begin
        /*if POSTransLine."Entry Type" = POSTransLine."Entry Type"::Item then begin
            if RetailSetup.FindFirst() then begin
                if RetailSetup."FSN Is Local Receipt" then
                    FSNDeliveryInvMgt.ValidateServerInventoryLine(POSTransLine, 1);
            end;
        end;*/
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC Hospitality POS Startup", 'OnBeforeExecuteCommand', '', true, true)]
    local procedure "LSC Hospitality POS Startup_OnBeforeExecuteCommand"
    (
        MenuLine: Record "LSC POS Menu Line";
        CurrentReceipt: Code[20];
        var CommandRun: Boolean;
        var HospitalityTypeTemp: Record "LSC Hospitality Type";
        ActiveDiningArea: Record "LSC Dining Area";
        ActiveServiceFlow: Record "LSC Hospitality Service Flow";
        var IsHandled: Boolean
    )
    var
        delOrder: Record "LSC Delivery Order";//28981
        posTrans: Record "LSC POS Transaction";
        POSSESSION: Codeunit "LSC POS Session";
        POSMenuLineV: Record "LSC POS Menu Line";
        DelPanelUtility: Codeunit "LSC Del. POS Panel Utilities";
        EPosCtrl: Codeunit "LSC POS Control Interface";
    begin
        if not (MenuLine.Command IN ['DELCONFIRM', 'DEL-CHEK-PHONE']) then
            exit;
        if IsHandled then
            exit;
        if delOrder.Get(MenuLine."Current-RECEIPT") then
            if posTrans.Get(delOrder."Order No.") then begin
                if POSSESSION.StoreNo() <> delOrder."Restaurant No." then begin
                    POSSESSION.SetTempStoreTerminal(posTrans."Store No.", posTrans."POS Terminal No.", DelOrder."Sales Type");
                end;
            end;


        /*if delOrder.Get(MenuLine."Current-RECEIPT") then begin
            POSSESSION.SetValue('CURRORDER', MenuLine."Current-RECEIPT");
            EPosCtrl.HidePanel(POSSESSION.DelOpenOrdersPanelID, true);
        end;*/

        /*POSMenuLineV.Reset();
        POSMenuLineV.SetCurrentKey("Profile ID", "Menu ID", "Key No.");
        POSMenuLineV.SetRange(POSMenuLineV."Profile ID", '#FSN-CC');
        POSMenuLineV.SetRange(POSMenuLineV."Menu ID", '#DEL-OPENORDERSMENU');
        POSMenuLineV.SetRange(POSMenuLineV."Key No.", 1);
        if POSMenuLineV.FindFirst() then begin
            Commit();
            IF DelPanelUtility.RUN(POSMenuLineV) THEN BEGIN
                DelPanelUtility.HandleDelOpenOrdersPanel;
                DeliveryOrderManagement.ProcessInputOnSelectingOrderOnOrderTaking;
            END;
        end;*/
    end;

    procedure ValidateServerinventoryTransac(pPOSTransaction: Record "LSC POS Transaction"; pPostCommand: Text[50])
    var
        POSTransLineBK: Record "LSC POS Trans. Line";
        StoreTmp: Record "LSC Store" temporary;
        POSMenuLineTmp: Record "LSC POS Menu Line" temporary;
        POSMenuLine_l: Record "LSC POS Menu Line";
        DeliveryOrder: Codeunit "LSC Delivery Order Management";
        DeliveryOrder_l: Record "LSC Delivery Order";
        CommSalesGroupMember_l: Record "LSC Cmsn Salesp. Grp Member"; //"LSC Commission Salesp. Grp Member";
        EPOSControlInterface: Codeunit "LSC POS Control Interface";
        EPosCtrl: codeunit "LSC POS Control Interface";
        POSView: Codeunit "LSC POS View";
        POSTrans: Codeunit "LSC POS Transaction";
        DeliveryOrdert: Record "LSC Delivery Order";
        PageDeliveryTakeOrder: Page "FSN Take Order CC";
        poscnt: Codeunit "LSC POS Controller";
        HospitalityPOSStartup: Codeunit "LSC Hospitality POS Startup";
        HosPosStartup: Codeunit "LSC Hospitality POS Startup";
        POSMenuLineV: Record "LSC POS Menu Line";
        DelPanelUtility: Codeunit "LSC Del. POS Panel Utilities";
        TmpMenuLine: Record "LSC POS Menu Line" temporary;
        PosCommand: Record "LSC POS Command";
        EPosContext: Codeunit "LSC POS Context";
    begin
        LinesCount := 0;

        IF DeliveryOrder_l.GET(pPOSTransaction."Receipt No.") AND
          (DeliveryOrder_l."Call Cent. Web Service Status" IN
            [DeliveryOrder_l."Call Cent. Web Service Status"::"Not Used",
             DeliveryOrder_l."Call Cent. Web Service Status"::"New-Not Sent",
             DeliveryOrder_l."Call Cent. Web Service Status"::"New-Not Confirmed"]) THEN BEGIN

            InventoryLookUpTableTmp.RESET;
            InventoryLookUpTableTmp.DELETEALL;
            CLEAR(InventoryLookUpTableTmp);

            POSTransLineBK.RESET;
            POSTransLineBK.SETCURRENTKEY("Receipt No.", "Entry Type", "Entry Status");
            POSTransLineBK.SETRANGE(POSTransLineBK."Receipt No.", pPOSTransaction."Receipt No.");
            POSTransLineBK.SETRANGE(POSTransLineBK."Entry Type", POSTransLineBK."Entry Type"::Item);
            POSTransLineBK.SETRANGE(POSTransLineBK."Entry Status", POSTransLineBK."Entry Status"::" ");
            IF POSTransLineBK.FINDSET THEN
                REPEAT
                    ValidateServerInventoryLine(POSTransLineBK, 0);

                    IF NOT InventoryLookUpTableTmp.GET(POSTransLineBK.Number, POSTransLineBK."Variant Code"
                                  , POSTransLineBK."Store No.", POSTransLineBK."Lot No.", POSTransLineBK."Serial No.") THEN BEGIN

                        InventoryLookUpTableTmp."Phys. Inventory" := 1;
                        InventoryLookUpTableTmp."Net Inventory" := 0;
                        InventoryLookUpTableTmp."Total Sales" := 0;

                        IF InventoryLookUpTable.GET(POSTransLineBK.Number, POSTransLineBK."Variant Code"
                                    , POSTransLineBK."Store No.", POSTransLineBK."Lot No.", POSTransLineBK."Serial No.") THEN
                            InventoryLookUpTableTmp."Net Inventory" := InventoryLookUpTable."Net Inventory";

                        InventoryLookUpTableTmp."Item No." := POSTransLineBK.Number;
                        InventoryLookUpTableTmp."Variant Code" := POSTransLineBK."Variant Code";
                        InventoryLookUpTableTmp."Store No." := pPOSTransaction."Store No.";
                        InventoryLookUpTableTmp.Location := pPOSTransaction."Store No.";
                        InventoryLookUpTableTmp."Lot No." := POSTransLineBK."Lot No.";
                        InventoryLookUpTableTmp."Serial No." := POSTransLineBK."Serial No.";
                        InventoryLookUpTableTmp.INSERT;
                    END;

                    InventoryLookUpTableTmp."Total Sales" += POSTransLineBK.Quantity * DivisorQtyPerUM(POSTransLineBK.Number, POSTransLineBK."Unit of Measure");
                    IF InventoryLookUpTableTmp."Net Inventory" < InventoryLookUpTableTmp."Total Sales" THEN //use <= for maximum inventory
                        InventoryLookUpTableTmp."Phys. Inventory" := 0;

                    InventoryLookUpTableTmp.MODIFY;

                UNTIL POSTransLineBK.NEXT = 0;

            POSSESSION.SetValue('#LINEC', Format(LinesCount));
            IF LinesCount > 0 THEN BEGIN
                IF pPostCommand = 'CHECKCHANGE' THEN
                    EXIT;
                IF pPostCommand = 'SUGGESTSTORE' THEN BEGIN
                    SuggestChangeStoreLink(pPOSTransaction, TRUE)
                END ELSE
                    POSGUI.PosMessage(STRSUBSTNO(Text008, FORMAT(LinesCount)));
            END;
        END;

        DeliveryOrder_l.reset();
        IF DeliveryOrder_l.GET(pPOSTransaction."Receipt No.") then begin
            POSSESSION.SetValue('RUN_DELIVERY', '');//PARA QUE NO MUESTRE PANEL CUANDO EXISTA NUMERO DE ORDEN

            //#DEL-ORDER

            EPosCtrl.ShowPanel(POSSession.OfflinePanelID);

            POSSESSION.SetValue('CURRORDER', pPOSTransaction."Receipt No.");
            POSSESSION.SetValue('CURRORDER2', pPOSTransaction."Receipt No.");

            PageDeliveryTakeOrder.VisiblePosTransLine(true);
            PageDeliveryTakeOrder.SETGLOBALVALUE(DeliveryOrder_l);
            PageDeliveryTakeOrder.RUN;

            /*TmpMenuLine."Profile ID" := '#FSN-CC';
            TmpMenuLine."Key No." := 1;
            TmpMenuLine.Command := 'DELCONFIRM';
            TmpMenuLine."Current-POSID" := pPOSTransaction."POS Terminal No.";
            TmpMenuLine."Current-StaffID" := pPOSTransaction."Staff ID";
            TmpMenuLine."Current-SHIFT" := '';
            TmpMenuLine."Current-RECEIPT" := pPOSTransaction."Receipt No.";
            TmpMenuLine."Current-SALESORDER" := '';
            TmpMenuLine."Current-SALESTYPE" := pPOSTransaction."Sales Type";
            IF DeliveryOrderManagement.RUN(TmpMenuLine) THEN;*/


            /*DeliveryOrderManagement.OnTakeOrderPanelOpen;
            DeliveryOrderManagement.LoadCurrentTrans;
            DeliveryOrderManagement.LoadComments;
            DeliveryOrderManagement.LoadTakeOrderPanel;
            DeliveryOrderManagement.LoadContact;
            DeliveryOrderManagement.InitSelDelTypeKey;
            DeliveryOrderManagement.InitSelPmtKey;
            DeliveryOrderManagement.LoadContext(true);*/
            //EPosCtrl.ShowPanelModal('#DEL-ORDER', '{"j":{"FUNCTIONTYPE":"TAKEDELORDER","ORIGIN":"10001216"},"t":"10000991"}');
            //EPosCtrl.PostEvent('RUNCOMMAND', 'SHOWPANELMODAL', '#DEL-ORDER', '');
        end;
    end;


    procedure ValidateServerInventoryLine(var pPOSTransLine: Record "LSC POS Trans. Line"; ActionType: Integer)
    var
        TSU: Codeunit "LSC POS Trans. Server Utility";
        ItemInventoryLog: Record "FSN Inventory Internal Log";
        InventoryLookUpTable: Record "LSC Inventory Lookup Table";
        Timer1: Time;
        DelContactAddress_l: Record "LSC Delivery Contact Address";
        LongText: Text;
        DivisorQtyPerValue: Decimal;
        pErrorInt: Integer;
        pErrorText: Text;
        Done_: Boolean;
        QtyTransaction: Decimal;
        NotCalculate: Boolean;
        InventoryInLookUpNet: Decimal;
        DiffTime: Integer;
        WebServiceMode: Integer;
        StoreLinkTmp: Record "FSN Store Link" temporary;
        StoreLinkLocal: Record "FSN Store Link";
        RecRefTmp: RecordRef;
        FSNInventoryLog: Record "FSN Inventory Internal Log";
        HorsInt: Integer;
        HoursLogInt: Integer;
        DiferentMinutes: Integer;
        ValidateDif: boolean;
    begin

        WebServiceMode := 1;//1=NAVServer 2=Pre Calc
        FSNInventoryLog.Reset();
        if FSNInventoryLog.Get(pPOSTransLine.Number) then begin
            if FSNInventoryLog.Date = Today then begin//<Hours12>
                if Evaluate(HorsInt, FORMAT(TIME, 2, '<Minutes,2>')) then;
                if Evaluate(HoursLogInt, FORMAT(FSNInventoryLog.Time, 2, '<Minutes,2>')) then;
                DiferentMinutes := ABS(HorsInt - HoursLogInt);
                if DiferentMinutes > 7 then
                    WebServiceMode := 2;
            end else begin
                WebServiceMode := 2;
            end;
        end else begin
            WebServiceMode := 2;
        end;

        Done_ := FALSE;
        NotCalculate := FALSE;
        IF WebServiceMode = 2 THEN
            DiffTime := 900000//15 min. //DiffTime := 420000//7 min. age
        ELSE
            DiffTime := 600000;//10 min. age

        IF (pPOSTransLine."Entry Type" = pPOSTransLine."Entry Type"::Item) AND (pPOSTransLine."Entry Status" <> pPOSTransLine."Entry Status"::Voided) THEN BEGIN
            pErrorInt := 0;
            pErrorText := '';
            IF ItemInventoryLog.GET(pPOSTransLine.Number) THEN BEGIN
                Timer1 := TIME - DiffTime;
                IF ItemInventoryLog.Date = TODAY THEN
                    Done_ := Timer1 < ItemInventoryLog.Time;

                NotCalculate := ItemInventoryLog."Calculate Inventory" = ItemInventoryLog."Calculate Inventory"::No;
            END ELSE BEGIN
                ItemInventoryLog.INIT();
                ItemInventoryLog."No." := pPOSTransLine.Number;
                ItemInventoryLog.Description := pPOSTransLine.Description;
                ItemInventoryLog."Store No. Request" := pPOSTransLine."Store No.";
                ItemInventoryLog."Terminal No. Request" := pPOSTransLine."POS Terminal No.";
                ItemInventoryLog.Time := 0T;
                ItemInventoryLog.Inventory := 0;
                ItemInventoryLog."Unit Of Measure" := pPOSTransLine."Unit of Measure";
                ItemInventoryLog."Receipt No. Request" := pPOSTransLine."Receipt No.";
                ItemInventoryLog.INSERT(TRUE);
            END;

            IF NotCalculate THEN
                EXIT;

            IF NOT Done_ THEN BEGIN
                IF WebServiceMode = 1 THEN
                    Done_ := TSU.GetItemInventoryLookupTable(pPOSTransLine.Number, pPOSTransLine."Variant Code", '', '', pErrorText);//NAV Server
                                                                                                                                     //Done_ := TSU.GetItemInventoryLookupTable(pPOSTransLine.Number, pPOSTransLine."Variant Code", '', '', pErrorInt);//NAV Server
                IF WebServiceMode = 2 THEN BEGIN
                    Done_ := RequestInventoryWS(pPOSTransLine.Number, pPOSTransLine."Variant Code", '', pPOSTransLine."Store No.", pPOSTransLine."POS Terminal No.", '', '');//Pre calc-
                    IF ItemInventoryLog.GET(pPOSTransLine.Number) THEN
                        Timer1 := TIME - DiffTime;
                    IF ItemInventoryLog.Date = TODAY THEN
                        Done_ := Timer1 < ItemInventoryLog.Time;
                    IF NOT Done_ THEN
                        pErrorInt := 1;
                END;

                IF Done_ AND (WebServiceMode = 1) THEN BEGIN
                    ItemInventoryLog.GET(pPOSTransLine.Number);

                    ItemInventoryLog.Description := pPOSTransLine.Description;
                    ItemInventoryLog."Store No. Request" := pPOSTransLine."Store No.";
                    ItemInventoryLog."Terminal No. Request" := pPOSTransLine."POS Terminal No.";
                    IF InventoryLookUpTable.GET(pPOSTransLine.Number, pPOSTransLine."Variant Code", pPOSTransLine."Store No.", pPOSTransLine."Lot No.", pPOSTransLine."Serial No.") THEN
                        ItemInventoryLog.Inventory := InventoryLookUpTable."Net Inventory"
                    ELSE
                        ItemInventoryLog.Inventory := 0;
                    ItemInventoryLog."Unit Of Measure" := pPOSTransLine."Unit of Measure";
                    ItemInventoryLog."Receipt No. Request" := pPOSTransLine."Receipt No.";
                    ItemInventoryLog.MODIFY(TRUE);
                END;

            END;

            InventoryInLookUpNet := 0;
            IF InventoryLookUpTable.GET(pPOSTransLine.Number, pPOSTransLine."Variant Code", pPOSTransLine."Store No.", pPOSTransLine."Lot No.", pPOSTransLine."Serial No.") THEN
                InventoryInLookUpNet := InventoryLookUpTable."Net Inventory"
            ELSE
                InventoryInLookUpNet := 0;


            pErrorText := '';
            IF pErrorInt <> 0 THEN
                pErrorText := STRSUBSTNO(Text000, FORMAT(ItemInventoryLog.Time));

            QtyTransaction := GetQuantityTransaction(pPOSTransLine."Receipt No.", pPOSTransLine.Number);

            DivisorQtyPerValue := DivisorQtyPerUM(pPOSTransLine.Number, pPOSTransLine."Unit of Measure");
            CASE ActionType OF
                0:
                    BEGIN
                        IF (InventoryInLookUpNet / DivisorQtyPerValue) < (QtyTransaction / DivisorQtyPerValue) THEN
                            LinesCount += 1;
                        EXIT;
                    END;
                1:
                    BEGIN
                        IF ((InventoryInLookUpNet / DivisorQtyPerValue) < (QtyTransaction / DivisorQtyPerValue)) THEN BEGIN
                            LongText := '';
                            IF pErrorInt <> 0 THEN
                                LongText := pErrorText + '\';
                            IF DeliveryOrder.GET(pPOSTransLine."Receipt No.") THEN BEGIN
                                DeliveryStreet.RESET;
                                DeliveryStreet.SETRANGE(DeliveryStreet."FSN Alter Key", DeliveryOrder."FSN Alter Key");
                                IF DeliveryStreet.FINDFIRST THEN BEGIN

                                    StoreLinkTmp.RESET;
                                    StoreLinkTmp.DELETEALL;

                                    StoreLinkLocal.RESET;
                                    StoreLinkLocal.SETRANGE(StoreLinkLocal.Type, StoreLinkLocal.Type::StreetAlterKey);
                                    StoreLinkLocal.SETRANGE(StoreLinkLocal."Parent Code", DeliveryStreet."FSN Alter Key Text");
                                    StoreLinkLocal.SETFILTER(StoreLinkLocal."Km Between Points", '<=%1', DeliveryStreet."FSN Distance Allow Km.");
                                    IF DeliveryStreet."FSN Distance Order Type" = DeliveryStreet."FSN Distance Order Type"::"Distance Driver" THEN BEGIN
                                        StoreLinkLocal.SETCURRENTKEY(Sort, "Km Distance Driver");
                                        StoreLinkLocal.SETFILTER(StoreLinkLocal."Km Distance Driver", '>0&<=%1', DeliveryStreet."FSN Distance Show Km.");
                                    END;
                                    IF StoreLinkLocal.FINDFIRST THEN
                                        REPEAT

                                            StoreLinkTmp.INIT();
                                            StoreLinkTmp := StoreLinkLocal;
                                            StoreLinkTmp."Time Driver Min." := 0; //Tmp inventory
                                            IF InventoryLookUpTable.GET(pPOSTransLine.Number, pPOSTransLine."Variant Code", StoreLinkLocal."Store No.", pPOSTransLine."Lot No.", pPOSTransLine."Serial No.") THEN
                                                StoreLinkTmp."Time Driver Min." := //Tmp inventory
                                    ROUND(InventoryLookUpTable."Net Inventory" / DivisorQtyPerValue, 0.1, '<');

                                            StoreLinkTmp.INSERT;
                                        UNTIL StoreLinkLocal.NEXT = 0;

                                END;
                                //END;
                            END;

                            FSNDelStoreLink.DelStreetModifyPriority(DeliveryStreet, StoreLinkTmp);
                            StoreLinkTmp.RESET;
                            IF StoreLinkTmp.FIND('-') THEN BEGIN
                                COMMIT;
                                RecRefTmp.GETTABLE(StoreLinkTmp);
                                IF DeliveryStreet."FSN Distance Order Type" = DeliveryStreet."FSN Distance Order Type"::"Distance Driver" THEN
                                    POSTransaction.LookUpEx(FALSE, '#STORELINKS_DISTIDRI', '', RecRefTmp)
                                ELSE
                                    POSTransaction.LookUpEx(FALSE, '#STORELINKS_DISTITEM', '', RecRefTmp);
                                RecRefTmp.CLOSE;
                            END; //ELSE//
                                 //POSGUI.PosMessage(STRSUBSTNO(Text001, '', pPOSTransLine."Store No.", InventoryInLookUpNet));
                        END ELSE
                            IF pErrorInt <> 0 THEN
                                POSGUI.PosMessage(pErrorText);

                    END;
            END;
        END;
    end;

    procedure SuggestChangeStoreLink(pPOSTransaction: Record "LSC POS Transaction"; pPopUpShow: Boolean)
    var
        StoreLink_l: Record "FSN Store Link";
        StoreLinkTmp: Record "FSN Store Link" temporary;
        Store_l: Record "LSC Store";
        DelOrder_l: Record "LSC Delivery Order";
        DelStreet_l: Record "LSC Delivery Street";
        DelContAddress_l: Record "LSC Delivery Contact Address";
        POSTransLineBK: Record "LSC POS Trans. Line";
        CompleteOk: Boolean;
        StoreOk: Code[10];
        CrossOk: Boolean;
        POSTransLinesTMP: Record "LSC POS Trans. Line" temporary;
        RecRefTMP: RecordRef;
        Line: Integer;
        Items: Record "Item";
        Stores: Record "LSC Store";
        ReceiptResponseLookUp: Code[30];
        CommSalesGroupMember_l: Record "LSC Cmsn Salesp. Grp Member";
        FSNSetup: Record "FSN Fasani Setup";
        TypeStreetFilterOk: Boolean;
        HospFunc: Codeunit "LSC Hospitality Functions";
        SchemeType: Option "Order","Product Group","Special Group",Item;
        SchemeCode: Code[20];
        DateTimeIn: DateTime;
        TimeCalc: Option Finish,Start;
        ErrorText: Text[250];
        GetEstimJobOnCC: Boolean;
        ProdTimeLength: Integer;
        TimeFrom: DateTime;
        TimeTo: DateTime;
        OpenStatus: Option Open,"Closed within Period","Closed at End Point";
        IsOpen: Boolean;
        FSNDeliveryFuncExt: Codeunit "FSN Delivery Functions Extend";
    begin

        IF NOT DelOrder_l.GET(pPOSTransaction."Receipt No.") THEN
            EXIT;

        if pPopUpShow then
            if POSSESSION.GetValue('#_CHANGESTORE') <> '' then begin
                if not Store_l.Get(POSSESSION.GetValue('#_CHANGESTORE')) then
                    exit;

                IF (DelOrder_l."Order Date" <> 0D) AND (DelOrder_l."Contact Pickup Time" <> 0T) THEN
                    DateTimeIn := CREATEDATETIME(DelOrder_l."Order Date", DelOrder_l."Contact Pickup Time")
                ELSE
                    DateTimeIn := CURRENTDATETIME;

                if not HospFunc.FindProductionTime(
                              Store_l."No.", 0, '', DateTimeIn, 0,
                              ErrorText, FALSE, ProdTimeLength, TimeFrom, TimeTo, OpenStatus) then begin
                    POSGUI.PosMessage(StrSubstNo(Text009, ErrorText));
                    exit;
                end;
                IF POSGUI.PosConfirm(STRSUBSTNO(Text003, Store_l."No.", Store_l.Name), FALSE) THEN
                    FSNDeliveryFuncExt.ChangeStore(pPOSTransaction."Receipt No.", StoreOk, 0);
                exit;
            end;


        DelStreet_l.RESET;
        DelStreet_l.SETRANGE(DelStreet_l."FSN Alter Key", DelOrder_l."FSN Alter Key");
        IF NOT DelStreet_l.FINDFIRST THEN
            EXIT;

        CompleteOk := FALSE;
        CLEAR(StoreOk);
        StoreLinkTmp.RESET;
        StoreLinkTmp.DELETEALL;
        CLEAR(StoreLinkTmp);

        TypeStreetFilterOk := FSNSetup.GET(pPOSTransaction."Store No.") AND FSNSetup."Use DAF API";

        StoreLink_l.RESET;
        StoreLink_l.SETCURRENTKEY(Sort, StoreLink_l."Km Between Points");
        IF DelStreet_l."FSN Distance Order Type" = DelStreet_l."FSN Distance Order Type"::"Distance Driver" THEN
            StoreLink_l.SETCURRENTKEY(Sort, "Km Distance Driver");

        StoreLink_l.SETRANGE(StoreLink_l.Type, StoreLink_l.Type::StreetAlterKey);
        StoreLink_l.SETRANGE(StoreLink_l."Parent Code", COPYSTR(DelStreet_l."FSN Alter Key Text", 1, MAXSTRLEN(StoreLink_l."Parent Code")));
        StoreLink_l.SETFILTER(StoreLink_l."Store No.", '<>%1&<>%2', '', pPOSTransaction."Store No.");
        StoreLink_l.SETFILTER(StoreLink_l."Km Between Points", '<=%1', DelStreet_l."FSN Distance Allow Km.");
        IF DelStreet_l."FSN Distance Order Type" = DelStreet_l."FSN Distance Order Type"::"Distance Driver" THEN
            StoreLink_l.SETFILTER(StoreLink_l."Km Distance Driver", '>0&<=%1', DelStreet_l."FSN Distance Allow Km.");

        IF NOT TypeStreetFilterOk THEN
            StoreLink_l.SETFILTER(StoreLink_l."Link Type", '<>%1', StoreLink_l."Link Type"::NormalStore);

        IF StoreLink_l.FINDSET THEN
            REPEAT
                IF (DelOrder_l."Order Date" <> 0D) AND (DelOrder_l."Contact Pickup Time" <> 0T) THEN
                    DateTimeIn := CREATEDATETIME(DelOrder_l."Order Date", DelOrder_l."Contact Pickup Time")
                ELSE
                    DateTimeIn := CURRENTDATETIME;

                IsOpen := HospFunc.FindProductionTime(
                          StoreLink_l."Store No.", 0, '', DateTimeIn, 0,
                          ErrorText, FALSE, ProdTimeLength, TimeFrom, TimeTo, OpenStatus);

                IF IsOpen THEN BEGIN
                    StoreLinkTmp := StoreLink_l;
                    IF StoreLinkTmp.INSERT THEN;
                END;

            UNTIL (StoreLink_l.NEXT = 0);

        FSNDelStoreLink.DelStreetModifyPriority(DelStreet_l, StoreLinkTmp);

        StoreLinkTmp.RESET;                             //Step 1
        StoreLinkTmp.SETCURRENTKEY(Sort, "Km Between Points");
        IF DelStreet_l."FSN Distance Order Type" = DelStreet_l."FSN Distance Order Type"::"Distance Driver" THEN
            StoreLinkTmp.SETCURRENTKEY(Sort, "Km Distance Driver");
        IF StoreLinkTmp.FIND('-') THEN
            REPEAT
                StoreOk := StoreLinkTmp."Store No.";
                CompleteOk := CompareInventoryInStore(StoreLinkTmp."Store No.", FALSE);
            UNTIL (StoreLinkTmp.NEXT = 0) OR CompleteOk;

        IF CompleteOk THEN BEGIN
            IF NOT Store_l.GET(StoreOk) THEN
                EXIT;

            IF POSGUI.PosConfirm(STRSUBSTNO(Text003, Store_l."No.", Store_l.Name), FALSE) THEN
                FSNDeliveryFuncExt.ChangeStore(pPOSTransaction."Receipt No.", StoreOk, 0);

            EXIT;
        END;

        CrossOk := FALSE;                             //Step 2
        StoreLinkTmp.RESET;
        StoreLinkTmp.SETCURRENTKEY(Sort, "Km Between Points");
        IF DelStreet_l."FSN Distance Order Type" = DelStreet_l."FSN Distance Order Type"::"Distance Driver" THEN
            StoreLinkTmp.SETCURRENTKEY(Sort, "Km Distance Driver");
        IF StoreLinkTmp.FIND('-') THEN
            REPEAT
                StoreOk := StoreLinkTmp."Store No.";
                CompleteOk := CompareInventoryInStore(StoreLinkTmp."Store No.", TRUE);

            UNTIL (StoreLinkTmp.NEXT = 0) OR CompleteOk;

        IF NOT Store_l.GET(StoreOk) THEN BEGIN
            COMMIT;
            POSGUI.PosMessage(STRSUBSTNO(Text008, FORMAT(LinesCount)));
            EXIT;
        END;
        IF CompleteOk THEN BEGIN
            CrossOk := TRUE;
            InventoryLookUpTableTmp.RESET;
            InventoryLookUpTableTmp.SETRANGE(InventoryLookUpTableTmp."Phys. Inventory", 0);
            InventoryLookUpTableTmp.MODIFYALL(InventoryLookUpTableTmp.Location, StoreOk);
            InventoryLookUpTableTmp.MODIFYALL(InventoryLookUpTableTmp."Phys. Inventory", 1);
        END;

        IF NOT CompleteOk THEN BEGIN
            //Multiple Store

        END;

        IF NOT CompleteOk THEN BEGIN
            COMMIT;
            InventoryLookUpTableTmp.RESET;
            InventoryLookUpTableTmp.SETRANGE(InventoryLookUpTableTmp."Phys. Inventory", 0);
            POSGUI.PosMessage(STRSUBSTNO(Text008, FORMAT(InventoryLookUpTableTmp.COUNT)));
            EXIT;
        END;
        COMMIT;
        POSTransLinesTMP.RESET;
        CLEAR(POSTransLinesTMP);

        Line := 10000;
        InventoryLookUpTableTmp.RESET;
        IF InventoryLookUpTableTmp.FIND('-') THEN
            REPEAT
                POSTransLinesTMP.INIT;
                POSTransLinesTMP."Receipt No." := pPOSTransaction."Receipt No.";
                POSTransLinesTMP."Line No." := Line;
                POSTransLinesTMP.Number := InventoryLookUpTableTmp."Item No.";
                POSTransLinesTMP.Quantity := InventoryLookUpTableTmp."Total Sales";
                POSTransLinesTMP."Store No." := InventoryLookUpTableTmp.Location;//Only filter
                IF Items.GET(POSTransLinesTMP.Number) THEN;
                POSTransLinesTMP.Description := Items.Description;

                IF Stores.GET(InventoryLookUpTableTmp.Location) THEN;
                POSTransLinesTMP."Delivery User ID" := Stores.Name;
                POSTransLinesTMP.INSERT;
                Line += 10000;
            UNTIL InventoryLookUpTableTmp.NEXT = 0;

        RecRefTMP.GETTABLE(POSTransLinesTMP);
        ReceiptResponseLookUp :=
          POSTransaction.LookUpEx(FALSE, 'CROSSTRANSACC', '', RecRefTMP);
        COMMIT;
    end;

    procedure CompareInventoryInStore(pStoreNo: Code[10]; pFilterNotSucessful: Boolean): Boolean
    begin
        InventoryLookUpTableTmp.RESET;
        IF pFilterNotSucessful THEN
            InventoryLookUpTableTmp.SETRANGE(InventoryLookUpTableTmp."Phys. Inventory", 0);

        IF InventoryLookUpTableTmp.FINDSET THEN
            REPEAT
                IF NOT InventoryLookUpTable.GET(InventoryLookUpTableTmp."Item No.", InventoryLookUpTableTmp."Variant Code"
                          , pStoreNo, InventoryLookUpTableTmp."Lot No.", InventoryLookUpTableTmp."Serial No.") THEN
                    EXIT(FALSE);

                IF InventoryLookUpTable."Net Inventory" < InventoryLookUpTableTmp."Total Sales" THEN
                    EXIT(FALSE);

            UNTIL InventoryLookUpTableTmp.NEXT = 0;

        EXIT(TRUE);
    end;

    procedure RequestInventoryWS(ItemNo: Code[20]; VariantNo: Code[10]; StoreNo: Code[10]; StoreNoAcces: Code[10]; TerminalNo: Code[10]; RequestID: Text[30]; XmlInit: Text): Boolean
    var
        pPosMenuLineTmp: Record "LSC POS Menu Line" temporary;
        FSNInventoryMgt: Codeunit "FSN Delivery Inventory Mgt.";
        FuncProfileWebServer: Record "LSC POS Func. Profile Web Serv"; //"POS Func. Profile Web Server";
        lResponse: Text;
        lError: Boolean;
    begin
        Clear(lError);
        FuncProfileWebServer.RESET;
        FuncProfileWebServer.SETCURRENTKEY("Profile ID", "Request ID", Priority);
        FuncProfileWebServer.SETRANGE(FuncProfileWebServer."Profile ID", POSSESSION.FunctionalityProfileID());
        FuncProfileWebServer.SETRANGE(FuncProfileWebServer."Request ID", 'FSN_GET_INVENTORY');
        FuncProfileWebServer.FINDLAST;

        pPosMenuLineTmp.RESET;
        pPosMenuLineTmp.DELETEALL;
        pPosMenuLineTmp.Command := FuncProfileWebServer."Request ID";
        IF RequestID <> '' THEN
            pPosMenuLineTmp.Command := RequestID;
        pPosMenuLineTmp."Post Command" := ItemNo;
        pPosMenuLineTmp."Post Parameter" := StoreNo;//28981
        pPosMenuLineTmp."Store Access" := StoreNoAcces;
        pPosMenuLineTmp."Pos Access" := TerminalNo;
        pPosMenuLineTmp."Current-POSID" := FuncProfileWebServer."Dist. Location";
        //VariantNo select all Variants
        pPosMenuLineTmp.INSERT;
        COMMIT;

        IF FSNInventoryMgt.RUN(pPosMenuLineTmp) THEN; //Control try catch

        IF RequestID = 'FSN_INVENTORY_TR' THEN BEGIN
            lResponse := FSNInventoryMgt.GetResponse(lError);
            IF lResponse = 'OK' THEN
                EXIT(TRUE);

            EXIT(FALSE);
        END;
    end;

    procedure GetQuantityTransaction(Receipt: Code[20]; ItemCode: Code[20]): Decimal
    var
        POSTransLineBK: Record "LSC POS Trans. Line";
        Qty: Decimal;
    begin
        Qty := 0;
        POSTransLineBK.RESET;
        POSTransLineBK.SETCURRENTKEY("Receipt No.", "Entry Type", "Entry Status");
        POSTransLineBK.SETRANGE(POSTransLineBK."Receipt No.", Receipt);
        POSTransLineBK.SETRANGE(POSTransLineBK."Entry Type", POSTransLineBK."Entry Type"::Item);
        POSTransLineBK.SETRANGE(POSTransLineBK."Entry Status", POSTransLineBK."Entry Status"::" ");
        POSTransLineBK.SETRANGE(POSTransLineBK.Number, ItemCode);
        IF POSTransLineBK.FINDSET THEN
            REPEAT
                Qty += POSTransLineBK.Quantity * DivisorQtyPerUM(POSTransLineBK.Number, POSTransLineBK."Unit of Measure");
            UNTIL POSTransLineBK.NEXT = 0;

        EXIT(Qty);
    end;

    procedure DivisorQtyPerUM(pItemNo: Code[20]; pUM: Code[10]): Decimal
    var
        ItemUnitOfMeasure_l: Record "Item Unit of Measure";
    begin

        IF NOT ItemUnitOfMeasure_l.GET(pItemNo, pUM) THEN
            EXIT(1.0);

        IF ItemUnitOfMeasure_l."Qty. per Unit of Measure" = 0 THEN
            EXIT(1.0)
        ELSE
            EXIT(ItemUnitOfMeasure_l."Qty. per Unit of Measure");
    end;


    /***************************         Call Web Service in OnRun                           *******************************/

    procedure ValidateInventoryECC(pParameter: Record "LSC POS Menu Line")
    var
        POSTransLineBK: Record "LSC POS Trans. Line";
        ItemUM: Record "Item Unit of Measure";
        ItemLogTmp: Record "FSN Inventory Internal Log" temporary;
        InvLookUpTable: Record "LSC Inventory Lookup Table";
        InventoryValue: Decimal;
        Divisor: Decimal;
    begin
        POSTransLineBK.RESET;
        POSTransLineBK.SETCURRENTKEY("Receipt No.", "Entry Type", "Entry Status");
        POSTransLineBK.SETRANGE(POSTransLineBK."Receipt No.", pParameter."Current-RECEIPT");
        POSTransLineBK.SETRANGE(POSTransLineBK."Entry Type", POSTransLineBK."Entry Type"::Item);
        POSTransLineBK.SETRANGE(POSTransLineBK."Entry Status", POSTransLineBK."Entry Status"::" ");
        POSTransLineBK.SetFilter(POSTransLineBK.Number, '<>%1&<>%2', 'A3256', '70107');
        IF POSTransLineBK.FIND('-') THEN
            REPEAT
                IF ItemUM.GET(POSTransLineBK.Number, POSTransLineBK."Unit of Measure") THEN
                    IF ItemUM."Qty. per Unit of Measure" <> 0 THEN
                        Divisor := ItemUM."Qty. per Unit of Measure";//DMEDINA10FEB2020+

                InventoryValue := 0;
                IF InventoryLookUpTable.GET(POSTransLineBK.Number, POSTransLineBK."Variant Code", POSTransLineBK."Store No.", POSTransLineBK."Lot No.", POSTransLineBK."Serial No.") THEN
                    InventoryValue := InventoryLookUpTable."Net Inventory" / Divisor;
                if POSTransLineBK.Quantity / Divisor > InventoryValue then begin
                    GlobalText := 'Cantidad no disponible para el articulo ' + POSTransLineBK.Number + ' en el almacén ' + POSTransLineBK."Store No.";
                    exit;
                end;
            UNTIL POSTransLineBK.NEXT = 0;
    end;

    procedure GetInventoryLookUpServer(pParameter: Record "LSC POS Menu Line")
    var
        ResponseXml: Text;
        WsFunc: Codeunit "LSC WS Functions";
        InvLookTmp: Record "LSC Inventory Lookup Table" temporary;
        InvLookTmp2: Record "LSC Inventory Lookup Table" temporary;
        ReqXml: XmlDocument;
        BodyNode: XmlNode;
        RequestID: Text[30];
        RequestNodeList: array[3] of Text[50];
        ResponseNodeList: array[5] of Text[50];
        ParentNodeIndex: Integer;
        ParentNodeList: array[5] of Text[50];
        Response_Code: Code[30];
        Response_Text: Text[1024];
        ReplCounter: Integer;
        RecRefTemp: RecordRef;
        RecRef: RecordRef;
        InvLookUpTable: Record "LSC Inventory Lookup Table";
        FlowFieldBuffer: Record "LSC FlowField Buffer" temporary;
        UpdateFieldList: Record "Field" temporary;
        TableNodeList: Record "LSC WS Node Buffer" temporary;
        ItemInventoryLog: Record "FSN Inventory Internal Log";
        DistributionLoc: Record "LSC Distribution Location";
        Item_l: Record Item;
        WSTable: Record "FSN WebServiceTable";
        Parameter: Record "FSN Parameter";
        POSTransLineBK: Record "LSC POS Trans. Line";
        ItemLogTmp: Record "FSN Inventory Internal Log" temporary;
        ItemUM: Record "Item Unit of Measure";
        pErrorText: Text;
        XmlRoot: Text;
    begin
        Clear(GlobalError);
        Clear(GlobalText);
        DistributionLoc.Get(pParameter."Current-POSID");

        SetLookUpSecurityText(pParameter, DistributionLoc);
        SetLookUpRequestText(pParameter);
        if WSTable.get(pParameter."Current-RECEIPT") then begin
            if WSTable."WS Request" = 'SEND_POSTRANS_BACKUP' then BEGIN
                Parameter.Reset();
                Parameter.Get('WS', 'INVENTORYTRANSAC');
                DistributionLoc.Reset();
                DistributionLoc.Get(Parameter.Valor);

                POSTransLineBK.RESET;
                POSTransLineBK.SETCURRENTKEY("Receipt No.", "Entry Type", "Entry Status");
                POSTransLineBK.SETRANGE(POSTransLineBK."Receipt No.", pParameter."Current-RECEIPT");
                POSTransLineBK.SETRANGE(POSTransLineBK."Entry Type", POSTransLineBK."Entry Type"::Item);
                POSTransLineBK.SETRANGE(POSTransLineBK."Entry Status", POSTransLineBK."Entry Status"::" ");
                IF POSTransLineBK.FIND('-') THEN
                    REPEAT
                        IF NOT ItemLogTmp.GET(POSTransLineBK.Number) THEN BEGIN
                            ItemLogTmp.INIT;
                            ItemLogTmp."No." := POSTransLineBK.Number;
                            ItemLogTmp."Qty. per UM" := 0;
                            ItemLogTmp.INSERT;
                        END;
                        IF ItemUM.GET(POSTransLineBK.Number, POSTransLineBK."Unit of Measure") THEN
                            ItemLogTmp."Qty. per UM" += POSTransLineBK.Quantity * ItemUM."Qty. per Unit of Measure"
                        ELSE
                            ItemLogTmp."Qty. per UM" += POSTransLineBK.Quantity;

                        ItemLogTmp.MODIFY;

                    UNTIL POSTransLineBK.NEXT = 0;

                ItemLogTmp.RESET;
                IF NOT ItemLogTmp.FIND('-') THEN BEGIN
                    pErrorText := STRSUBSTNO(Text002, pParameter."Current-RECEIPT");
                    EXIT;
                END;

                XmlRoot := '&lt;ROOT&gt;';
                ItemLogTmp.RESET;
                IF ItemLogTmp.FIND('-') THEN
                    REPEAT
                        XmlRoot += '&lt;Detail Item="' + ItemLogTmp."No." + '" Quantity="' + FORMAT(ItemLogTmp."Qty. per UM") + '" VariantCode="" StoreNo="' + pParameter."Store Access" + '" LocationCode=""/&gt;';
                    UNTIL ItemLogTmp.NEXT = 0;
                XmlRoot += '&lt;/ROOT&gt;';
                ///041225
                SetLookUpSecurityTextEcommerce(pParameter, DistributionLoc);
                SetLookUpRequestTexteCOMMERCE(XmlRoot);
                ResponseXml := WSInventoryEcommerce(GlobalError, DistributionLoc);
                if ResponseXml = 'OK' then begin
                    GlobalText := ResponseXml;
                    exit;
                end else begin
                    GlobalText := ResponseXml;
                    exit;
                end;

            END else
                ResponseXml := WSInventory(GlobalError, DistributionLoc);
        end else
            ResponseXml := WSInventory(GlobalError, DistributionLoc);
        if GlobalError then begin
            GlobalText := ResponseXml;
            Message(GlobalText);
            exit;
        end;

        RequestID := 'FSN_GET_INVENTORY';

        WsFunc.LoadRequest(ResponseXml, ReqXml, RequestID, RequestNodeList, ResponseNodeList, ParentNodeIndex, ParentNodeList, BodyNode, Response_Code, Response_Text);
        IF Response_Code = '0000' THEN BEGIN
            RecRefTemp.GETTABLE(InvLookTmp);
            WsFunc.GetTableChildNodes(RequestID, 1, BodyNode, ParentNodeIndex, ParentNodeList, 'LSC Inventory Lookup Table', RecRefTemp,
              FlowFieldBuffer, 1, UpdateFieldList, Response_Code, Response_Text);
        END;
        IF Response_Code = '0000' THEN BEGIN
            UpdateFieldList.SETRANGE(TableNo, 1);

            ReplCounter := 0;
            RecRefTemp.GETTABLE(InvLookTmp);
            RecRef.GETTABLE(InvLookTmp2);
            WsFunc.UpdateTableByTempTable(FALSE, RecRefTemp, RecRef, ReplCounter, UpdateFieldList);
        END;
        IF InvLookTmp2.FIND('-') THEN
            REPEAT
                InvLookUpTable := InvLookTmp2;
                IF NOT InvLookUpTable.MODIFY THEN
                    InvLookUpTable.INSERT;
            UNTIL InvLookTmp2.NEXT = 0;

        IF InvLookTmp2.FIND('-') THEN BEGIN
            IF ItemInventoryLog.GET(InvLookTmp2."Item No.") THEN BEGIN
                IF Item_l.GET(InvLookTmp2."Item No.") THEN;
                ItemInventoryLog."Store No. Request" := pParameter."Post Parameter";
                ItemInventoryLog."Terminal No. Request" := pParameter."Current-POSID";
                IF InvLookTmp2.GET(pParameter.Command, '', pParameter."Store Access", '', '') THEN
                    ItemInventoryLog.Inventory := InvLookTmp2."Net Inventory";
                ItemInventoryLog."Unit Of Measure" := '';
                ItemInventoryLog."Receipt No. Request" := pParameter."Current-RECEIPT";
                IF pParameter."Post Parameter" = '' THEN
                    ItemInventoryLog.MODIFY(TRUE)
                ELSE BEGIN
                    ItemInventoryLog."Last Date Store" := TODAY;
                    ItemInventoryLog."Last Time Store" := TIME;
                    ItemInventoryLog."Last Store" := pParameter."Post Parameter";
                    ItemInventoryLog.MODIFY;
                END;
            END;
        END;

        if Response_Code = '0000' then
            GlobalText := 'OK'
        else
            GlobalText := Response_Text;
    end;

    Local procedure SetLookUpSecurityText(pParameter: Record "LSC POS Menu Line"; DistributionLocation: Record "LSC Distribution Location")
    var
        ENCRYPTBYPASSPHRASE: Label 'xRecord2';
    begin
        DistributionLocation.GET(pParameter."Current-POSID");
        SRFRSECURITY := '{' +
          '"user":"' + DistributionLocation."User ID" + '",' +
          '"pss":"' + DistributionLocation.Password + '",' +
          '"dbase":"' + DistributionLocation."Db. Path && Name" + '",' +
          '"dbinstance":"' + COPYSTR(DistributionLocation."Db Server Name", STRPOS(DistributionLocation."Db Server Name", '\') + 1, STRLEN(DistributionLocation."Db Server Name")) + '",' +
          '"locationip":"' + DistributionLocation."Distribution Server" + '",' +
          '"cnnphrase":"' + ENCRYPTBYPASSPHRASE + '",' +
          '"store":"' + pParameter."Store Access" + '"}';
    end;


    Local procedure SetLookUpSecurityTextEcommerce(pParameter: Record "LSC POS Menu Line"; DistributionLocation: Record "LSC Distribution Location")
    var
        ENCRYPTBYPASSPHRASE: Label 'xRecord2';
    begin
        SRFRSECURITY := '{' +
          '"user":"' + DistributionLocation."User ID" + '",' +
          '"pss":"' + DistributionLocation.Password + '",' +
          '"dbase":"' + DistributionLocation."Db. Path && Name" + '",' +
          '"dbinstance":"' + COPYSTR(DistributionLocation."Db Server Name", STRPOS(DistributionLocation."Db Server Name", '\') + 1, STRLEN(DistributionLocation."Db Server Name")) + '",' +
          '"locationip":"' + DistributionLocation."Distribution Server" + '",' +
          '"cnnphrase":"' + ENCRYPTBYPASSPHRASE + '",' +
          '"store":"' + pParameter."Store Access" + '"}';
    end;

    local procedure SetLookUpRequestText(pParamters: Record "LSC POS Menu Line")
    begin
        SRFREQUEST := '{' +
                  '"item":"' + pParamters."Post Command" + '",' +
                  '"variant":"' + '' + '",' +
                  '"store":"' + pParamters."Post Parameter" + '"}';
    end;

    procedure SetLookUpRequestTexteCOMMERCE(NodeText: Text)
    begin
        SRFREQUEST := NodeText;
    end;

    procedure WSInventory(var pError: Boolean; DistributionLocation: Record "LSC Distribution Location") ResponseLocal: Text
    var
        IP: Text[150];
        url: Text;
        soapActionUrl: Text;
        sb: DotNet StringBuilder;
        uriObj: DotNet Uri; //DotNet Uri;
        lgRequest: DotNet HttpWebRequest;
        stream: DotNet StreamWriter;
        lgResponse: DotNet HttpWebResponse;
        str: DotNet Stream;
        reader: DotNet XmlTextReader;
        document: DotNet XmlDocument;
        ascii: DotNet Encoding;
        credentials: DotNet CredentialCache;
        xmlnodelist: DotNet XmlNodeList;
        xmlnode: DotNet XmlNode;
        xmlelement: DotNet XmlElement;
        nodos: Integer;
        xmlRequest: Text;
        xmlFinal: File;
        xmlStream: OutStream;
        i: Integer;
        NewLineNo: Integer;
        Index: Integer;
        JSonConvert: DotNet JsonConvert;
        JSonObject: DotNet JObject;
        JSonToken: DotNet JToken;
        String1: Text;
        String2: Text;
        XmlJson: DotNet XmlDocument;
        lTxt1: Label '%1 %2 no activo en Parametros';
        lTxt2: Label 'Distribution location is not configured';
        lTxt3: Label 'los campos IP,Web Uri y Web Action deben estar configurados en Parametros';
        FSNParameter: Record "FSN Parameter";
    begin

        FSNParameter.Reset();
        FSNParameter.SetRange(FSNParameter.Grupo, 'WS');
        FSNParameter.SetRange(FSNParameter.Codigo, 'INVENTORYCC');
        if FSNParameter.FindFirst() then begin
            if FSNParameter.Activo then begin
                if (FSNParameter.IP = '') or (FSNParameter."Web Uri" = '') or (FSNParameter."Web Action" = '') then begin
                    ResponseLocal := lTxt3;
                    pError := true;
                end else begin
                    IP := FSNParameter.IP;
                    url := FSNParameter."Web Uri";
                    soapActionUrl := FSNParameter."Web Action";

                    xmlRequest := '<?xml version="1.0" encoding="utf-8"?>' +
                    '<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
                      '<soap:Body>' +
                        '<GET_INVENTORY_LOOKUP xmlns="http://tempuri.org/">' +
                          '<xsecurity>' + SRFRSECURITY + '</xsecurity>' +
                          '<xcommand>' + '' + '</xcommand>' +
                          '<wsrequest>' + SRFREQUEST + '</wsrequest>' +
                        '</GET_INVENTORY_LOOKUP>' +
                      '</soap:Body>' +
                    '</soap:Envelope>';

                    sb := sb.StringBuilder();
                    sb.Append(xmlRequest);
                    IF xmlFinal.CREATE('C:\Temp\' + 'GET_INVENTORY_LOOKUP' + '-P.xml') THEN BEGIN
                        xmlFinal.CREATEOUTSTREAM(xmlStream);
                        xmlStream.WRITE(sb.ToString);
                        xmlFinal.CLOSE;
                    END;
                    uriObj := uriObj.Uri(url);
                    lgRequest := lgRequest.CreateDefault(uriObj);
                    lgRequest.Method := 'POST';
                    lgRequest.Host := IP;
                    lgRequest.ContentType := 'text/xml; charset=utf-8';
                    lgRequest.Headers.Add('SOAPAction', soapActionUrl);
                    lgRequest.Timeout := 10000;
                    stream := stream.StreamWriter(lgRequest.GetRequestStream(), ascii.UTF8);
                    stream.Write(sb.ToString());
                    stream.Close();
                    lgResponse := lgRequest.GetResponse();
                    str := lgResponse.GetResponseStream();
                    reader := reader.XmlTextReader(str);
                    document := document.XmlDocument();
                    document.Load(reader);
                    xmlnodelist := document.SelectNodes('//*');
                    document.Save('C:\temp\' + 'GET_INVENTORY_LOOKUP' + '-R.xml');
                    nodos := 11;

                    Index := 0;
                    WHILE (Index < xmlnodelist.Count) DO BEGIN
                        xmlnode := xmlnodelist.Item(Index);
                        IF NOT ISNULL(xmlnode) THEN BEGIN
                            CASE xmlnode.Name OF
                                'GET_INVENTORY_LOOKUPResult':
                                    ResponseLocal := xmlnode.FirstChild.InnerText;
                            END;
                        END;
                        Index += 1;
                    END;
                    IF ResponseLocal = '' THEN BEGIN
                        ResponseLocal := Text002;
                        pError := TRUE
                    END;
                end;
            end else begin
                ResponseLocal := StrSubstNo(lTxt1, FSNParameter.Grupo, FSNParameter.Codigo);
                pError := true;
            end;
        end;
    end;

    procedure WSInventoryEcommerce(var pError: Boolean; DistributionLocation: Record "LSC Distribution Location") ResponseLocal: Text
    var
        IP: Text[150];
        url: Text;
        soapActionUrl: Text;
        sb: DotNet StringBuilder;
        uriObj: DotNet Uri; //DotNet Uri;
        lgRequest: DotNet HttpWebRequest;
        stream: DotNet StreamWriter;
        lgResponse: DotNet HttpWebResponse;
        str: DotNet Stream;
        reader: DotNet XmlTextReader;
        document: DotNet XmlDocument;
        ascii: DotNet Encoding;
        credentials: DotNet CredentialCache;
        xmlnodelist: DotNet XmlNodeList;
        xmlnode: DotNet XmlNode;
        xmlelement: DotNet XmlElement;
        nodos: Integer;
        xmlRequest: Text;
        xmlFinal: File;
        xmlStream: OutStream;
        i: Integer;
        NewLineNo: Integer;
        Index: Integer;
        JSonConvert: DotNet JsonConvert;
        JSonObject: DotNet JObject;
        JSonToken: DotNet JToken;
        String1: Text;
        String2: Text;
        XmlJson: DotNet XmlDocument;
        lTxt1: Label '%1 %2 no activo en Parametros';
        lTxt2: Label 'Distribution location is not configured';
        lTxt3: Label 'los campos IP,Web Uri y Web Action deben estar configurados en Parametros';
        FSNParameter: Record "FSN Parameter";
    begin

        FSNParameter.Reset();
        FSNParameter.SetRange(FSNParameter.Grupo, 'WS');
        FSNParameter.SetRange(FSNParameter.Codigo, 'INVENTORYTRANSAC');
        if FSNParameter.FindFirst() then begin
            if FSNParameter.Activo then begin
                if (FSNParameter.IP = '') or (FSNParameter."Web Uri" = '') or (FSNParameter."Web Action" = '') then begin
                    ResponseLocal := lTxt3;
                    pError := true;
                end else begin
                    IP := FSNParameter.IP;
                    url := FSNParameter."Web Uri";
                    soapActionUrl := FSNParameter."Web Action";

                    xmlRequest := '<?xml version="1.0" encoding="utf-8"?>' +
                    '<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
                        '<soap:Body>' +
                            '<FSN_INVENTORY_TR xmlns="http://tempuri.org/">' +
                                '<xsecurity>' + SRFRSECURITY + '</xsecurity>' +
                                '<xcommand>FSN_INVENTORY_TR</xcommand>' +
                                '<wsrequest>' + SRFREQUEST + '</wsrequest>' +
                            '</FSN_INVENTORY_TR>' +
                        '</soap:Body>' +
                    '</soap:Envelope>';

                    sb := sb.StringBuilder();
                    sb.Append(xmlRequest);
                    IF xmlFinal.CREATE('C:\Temp\' + 'GET_INVENTORY_LOOKUP_TR' + '-P.xml') THEN BEGIN
                        xmlFinal.CREATEOUTSTREAM(xmlStream);
                        xmlStream.WRITE(sb.ToString);
                        xmlFinal.CLOSE;
                    END;
                    uriObj := uriObj.Uri(url);
                    lgRequest := lgRequest.CreateDefault(uriObj);
                    lgRequest.Method := 'POST';
                    lgRequest.Host := IP;
                    lgRequest.ContentType := 'text/xml; charset=utf-8';
                    lgRequest.Headers.Add('SOAPAction', soapActionUrl);
                    lgRequest.Timeout := 10000;
                    stream := stream.StreamWriter(lgRequest.GetRequestStream(), ascii.UTF8);
                    stream.Write(sb.ToString());
                    stream.Close();
                    lgResponse := lgRequest.GetResponse();
                    str := lgResponse.GetResponseStream();
                    reader := reader.XmlTextReader(str);
                    document := document.XmlDocument();
                    document.Load(reader);
                    xmlnodelist := document.SelectNodes('//*');
                    document.Save('C:\temp\' + 'GET_INVENTORY_LOOKUP_TR' + '-R.xml');
                    nodos := 11;

                    Index := 0;
                    WHILE (Index < xmlnodelist.Count) DO BEGIN
                        xmlnode := xmlnodelist.Item(Index);
                        IF NOT ISNULL(xmlnode) THEN BEGIN
                            CASE xmlnode.Name OF
                                'FSN_INVENTORY_TRResult':
                                    ResponseLocal := xmlnode.FirstChild.InnerText;
                            END;
                        END;
                        Index += 1;
                    END;
                    IF ResponseLocal = '' THEN BEGIN
                        ResponseLocal := Text002;
                        pError := TRUE
                    END;
                end;
            end else begin
                ResponseLocal := StrSubstNo(lTxt1, FSNParameter.Grupo, FSNParameter.Codigo);
                pError := true;
            end;
        end;
    end;

    procedure GetResponse(var pError: Boolean) pResponse: Text
    begin
        pError := GlobalError;
        exit(GlobalText);
    end;

    procedure EcommersInventary(POSMenuLine: Record "LSC POS Menu Line"): Boolean
    var
        myInt: Integer;
    begin
        GetInventoryLookUpServer(POSMenuLine);
        if GlobalText = 'OK' then
            exit(true)
        else
            exit(false);
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
        RetailSetup: Record "LSC Retail Setup";
    begin

        if RequestID = 'FSNCC' then begin
            IF RetailSetup.FindFirst() THEN begin
                Processed := RetailSetup."FSN Is Local Receipt";
            end;
        end;
    end;
}
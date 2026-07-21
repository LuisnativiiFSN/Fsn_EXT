codeunit 50044 "FSN Delivery Func. Extend"
{
    // WVILLALTA22ENE2020                 - New Delivery functions
    // WVILLALTA10FEB2020                 - Suggest store full inventory
    // WVILLALTA23MAR2020                 - Ecommerce list
    // WVILLALTA29ABR2020                 - Check order status in restaurant
    // WVILLALTA06MAY2020                 - Send mail quotation outher machine
    // WVILLALTA11MAY2020                 - Change lookup table to 50064 filter types origins
    // WVILLALTA12MAY2020                 - Filter value table 50064 in lookup Table
    // WVILLALTA13MAY2020                 - Validate inventory of Transaction.
    // WVILLALTA 7.20                     - DAF Integrated
    // WVILLALTA 8.20                     - Payment control
    // WVILLALTA 9.20                     - Reprint card voucher
    // WVILLALTA 10.20                    - Print FreeText tender types,DAF Groups
    // WVILLALTA 02.20                    - Block DRIVER_ON

    TableNo = "LSC POS Menu Line";
    SingleInstance = true;
    trigger OnRun()
    var
        POSTransLine: Record "LSC POS Trans. Line";
        POSTransaction: Record "LSC POS Transaction";
    begin
        GlobalRec.COPY(Rec);

        CASE Command OF
            'ASSIGN_EXT':
                AssignExt(FALSE);
            'CHECK_DAF':
                CheckTripDAFExt;
            /* 'COPYTEXTTRANS':
                 CopyFunction("Current-RECEIPT");
             'DEL-CHECK-CONTACT':
                 MGTCheckOrdersContact(Rec);
             'DEL-ECOMM-INF':
                 GetEcommerceInfo(Rec);
             'DEL-ORDER-EXT':
                 EXOCreateOrderOnDemand(Rec);*/
            //olopez 'DRIVER_EXT':
            //olopezDriverExt; //WVILLALTA 12.20
            'DRIVER_ONOFF':
                DriverOnOffExt();
            'POST':
                CreateTripForDelivery(GetTransaction());

        END;
    end;

    var
        RecRef: RecordRef;
        PostedDeliveryTrip: Record "FSN Posted Delivery Trip";
        TenderTypeSetup: Record "LSC Tender Type Setup";
        RetailSetup: Record "LSC Retail Setup";
        InventoryLookUpTable_l: Record "LSC Inventory Lookup Table";
        InventoryLookUpTableTmp: Record "LSC Inventory Lookup Table" temporary;
        DeliveryOrderBK: Record "LSC Delivery Order";
        DelContactAddressBK: Record "LSC Delivery Contact Address";
        DeliveryStreetBK: Record "LSC Delivery Street";
        POSTransactionBK: Record "LSC POS Transaction";
        HospitalitySetupBK: Record "LSC Hospitality Setup";
        CSWebServiceTableBK: Record "FSN WebServiceTable";
        ContacBK: Record Contact;
        RetailSetupBK: Record "LSC Retail Setup";
        RetailSetupGlobals: Record "LSC Retail Setup";
        GlobalRec: Record "LSC POS Menu Line";
        CCPOSTermBK: Record "LSC CC POS Term. Assignm.";
        POSFunction: Codeunit "LSC POS Functions";
        POSTransaction: Codeunit "LSC POS Transaction";
        POSSESSION: Codeunit "LSC POS Session";
        POSView: Codeunit "LSC POS View";
        POSGUI: Codeunit "LSC POS GUI";
        TSUtil: Codeunit "LSC POS Trans. Server Utility";
        HospPosComm: Codeunit "LSC Hospitality POS Commands";
        DelOrderMgt: Codeunit "LSC Delivery Order Management";
        BOUTIL: Codeunit "LSC BO Utils";
        POSCtrl: Codeunit "LSC POS Control Interface";
        DeliveryOrderManagement: Codeunit "LSC Delivery Order Management";
        LSExtFunc: Codeunit "LSC External Functions Util";
        ActiveDataGrid: Text;
        ActiveKey: Code[30];
        gLatitude: Decimal;
        SuperOrderID: Decimal;
        gLongitude: Decimal;
        LinesCount: Integer;
        Band: Boolean;
        IFoundIt: Boolean;
        Text000: Label 'Cant process inventory lookup, Inventory is show at hour %1 ';
        Text001: Label '%1 [%2] \';
        Text002: Label 'Inventory is not enough for %1 items.';
        Text003: Label 'Inventory incomplete, change store suggest \%1 %2';
        Text004: Label 'Inventory is not enough, no no suggestions';
        Text005: Label 'OPTION %1';
        Text006: Label 'For Store %1 - %2';
        Text007: Label '%1 - %2 .......... Request %3 Inventory %4 (Complete)';
        Text008: Label 'Inventory is not enough for %1 items.\Not store suggest.';
        Text009: Label 'Order %1 not exists or havent items';
        Text010: Label 'Response WS is not sucessfull.';
        Text011: Label '%1 do you want continue?';
        Text012: Label 'Order must be items';
        Text013: Label 'Order document type TICKET.\Want to continue?';
        Text014: Label 'Send Order to: %1\Store: %2\Want to continue?';
        Text015: Label 'Lookup %1 , not found %2 - %3';
        Text016: Label 'Call typified like SALE';
        Text017: Label 'Comment';
        Text018: Label 'Balance is greater that total';
        Text019: Label 'Receipt No. Not available';
        Text020: Label 'New linked order created %1';
        Text021: Label 'Value %1 - %2 is invalid';
        Text022: Label 'Function not allowed in Status %1';
        Text023: Label 'None';
        Text024: Label 'Mixto';
        Text025: Label 'Ticket';
        Text026: Label 'Error insert tipology, field was ocuped for %1';
        Text027: Label 'Limit Amount for delivery is $%1';
        Text028: Label 'Limit Amount for delivery cross transaction is $%1';
        Text029: Label 'Store delivery %1 and store Transac %2 no match';
        Text030: Label 'Amount in cross orders for contact ($ %1) is less to allowed $( %2)';
        Text031: Label 'Item %1 is assigned to store %2';
        // pExtOrderTmp: Record 10001236 temporary;
        Text032: Label 'Customer request %1';
        Text033: Label 'Changes in transaction require recalc payment';
        Text034: Label '%1 Not exists, Value %2';
        Text035: Label 'Vertify payments';
        Text036: Label 'Check data card payments';
        Text037: Label 'Member point %1 are not enough for payment %2';
        //CheckPaymentsUtil: Codeunit 50021;
        Text038: Label 'Last Valid Time for street %1 is %2.\%3';
        Text039: Label 'Cant be insert payment for reprint voucher,\amount transaction must be zero';
        Text040: Label 'Select a valid street.';
        Text041: Label 'PAY: %1 %2 %3';
        Text201: Label 'There are %1 order(s) with priority.\ Priority is %2 \Contact. %3';
        Text202: Label 'EXPRESS';

    #region [Internal procedures]
    local procedure GetTransaction(): Record "LSC POS Transaction"
    var
        POSTransaction: Record "LSC POS Transaction";
        POSTrans_C: Codeunit "LSC POS Transaction";
    begin
        POSTransaction.Get(POSTrans_C.GetReceiptNo());
        exit(POSTransaction);
    end;
    #endregion

    #region [External procedures]
    procedure DriverOnOffExt()
    var
        StaffStoreLink_l: Record "LSC STAFF Store Link";
        DeliveryDriverTrip_l: Record "LSC Delivery Driver Trip";
        DeliveryTrip_l: Record "FSN Delivery Trip";
        lTxt1: Label 'Active motorcycle - %1';
        lTxt2: Label 'Inactive motorcycle - %1';
        lTxt3: Label 'Driver have asociate orders';
    begin
        ActiveDataGrid := POSCtrl.ActiveDataGrid;
        ActiveKey := POSCtrl.GetDataGridKeyValue(ActiveDataGrid);

        IF NOT StaffStoreLink_l.GET(ActiveKey, POSSESSION.StoreNo()) THEN
            EXIT;
        StaffStoreLink_l.CALCFIELDS(StaffStoreLink_l."Staff Name on Receipt");

        HospitalitySetupBK.GET;
        DeliveryDriverTrip_l.RESET;
        DeliveryDriverTrip_l.SETCURRENTKEY("Driver ID", "Store No.", "Trip Counter");
        DeliveryDriverTrip_l.SETRANGE(DeliveryDriverTrip_l."Driver ID", StaffStoreLink_l."Staff ID");
        DeliveryDriverTrip_l.SETRANGE(DeliveryDriverTrip_l."Store No.", StaffStoreLink_l."Store No.");

        IF GlobalRec.Parameter = 'ON' THEN BEGIN
            MESSAGE('SOLO DAF PUEDE ACTIVAR UN MOTOCICLISTA');

            IF StaffStoreLink_l."On Call" THEN
                MESSAGE('YA ESTA ACTIVO')
            ELSE BEGIN
                StaffStoreLink_l."On Call" := TRUE;
                StaffStoreLink_l.MODIFY;
                DeliveryDriverTrip_l.SETRANGE(DeliveryDriverTrip_l.Status, DeliveryDriverTrip_l.Status::Open);
                IF NOT DeliveryDriverTrip_l.FIND('-') THEN BEGIN
                    DeliveryDriverTrip_l.SETCURRENTKEY("Date Opened");
                    DeliveryDriverTrip_l.SETRANGE(DeliveryDriverTrip_l.Status);
                    DeliveryDriverTrip_l.SETRANGE(DeliveryDriverTrip_l."Date Opened", TODAY);
                    DeliveryDriverTrip_l.SETRANGE(DeliveryDriverTrip_l."Driver ID", StaffStoreLink_l."Staff ID");
                    CreateTrip(StaffStoreLink_l."Staff ID", StaffStoreLink_l."Store No.", 0, 0, (NOT DeliveryDriverTrip_l.FINDFIRST), FALSE);
                END;
                MESSAGE(STRSUBSTNO('SE ACTIVO MOTO %1', StaffStoreLink_l."Staff Name on Receipt"));
            END;
        END ELSE
            IF GlobalRec.Parameter = 'OFF' THEN BEGIN
                IF DeliveryDriverTrip_l.FINDLAST THEN
                    DeliveryTrip_l.RESET;
                DeliveryTrip_l.SETRANGE(DeliveryTrip_l."Store No.", DeliveryDriverTrip_l."Store No.");
                DeliveryTrip_l.SETRANGE(DeliveryTrip_l."Driver ID", DeliveryDriverTrip_l."Driver ID");
                DeliveryTrip_l.SETRANGE(DeliveryTrip_l."Trip No. (LS Retail)", DeliveryDriverTrip_l."Trip Counter");

                //IF (DeliveryDriverTrip_l.Status <> DeliveryDriverTrip_l.Status::Open) OR DeliveryTrip_l.FIND('-') THEN
                IF DeliveryTrip_l.FIND('-') THEN
                    MESSAGE('El moto debe estar sin pedidos asignados')
                ELSE BEGIN
                    DriverOffCall(StaffStoreLink_l."Staff ID", StaffStoreLink_l."Store No.");
                    StaffStoreLink_l."On Call" := FALSE;
                    StaffStoreLink_l.MODIFY;
                    MESSAGE(STRSUBSTNO('SE INACTIVO MOTO %1', StaffStoreLink_l."Staff Name on Receipt"));
                END;
            END;
        POSCtrl.RefreshDataGrid(HospitalitySetupBK."Driver List Panel ID");
    end;

    procedure AssignExt(pUnassign: Boolean)
    var
        DelOrderMgt: Codeunit "LSC Delivery Order Management";
        DriverID: Code[20];
        DeliveryDriverTrip_l: Record "LSC Delivery Driver Trip";
        DeliveryTrip_l: Record "FSN Delivery Trip";
        DAFIntegrated: Codeunit "FSN DAF Integration";
        DelOrder: Record "LSC Delivery Order";
        Staff_l: Record "LSC Staff";
        Txt1: Label 'Trip status in %1 %2';
        Txt2: Label '%1 Already %2 %3';
    begin
        COMMIT;
        IF NOT DeliveryTrip_l.GET(GlobalRec."Current-RECEIPT") THEN
            IF DelOrder.GET(GlobalRec."Current-RECEIPT") THEN
                DAFIntegrated.CreateTripDAF(DelOrder, true);
        //DAFIntegrated.CreateTripDAF(Order, TRUE);

        IF NOT DeliveryTrip_l.GET(GlobalRec."Current-RECEIPT") THEN
            EXIT;

        IF NOT pUnassign THEN BEGIN
            IF DeliveryTrip_l."Trip No. (LS Retail)" > 0 THEN BEGIN
                MESSAGE(STRSUBSTNO(Txt2, DeliveryTrip_l.FIELDCAPTION(DeliveryTrip_l."Order No."), DeliveryTrip_l."Order No.", FORMAT(DeliveryTrip_l."Trip. Status"::"Assigned Driver")));
                EXIT;
            END;

            IF GlobalRec."Post Command" = 'FROMQUEUE' THEN
                DriverID := GlobalRec."Post Parameter"
            ELSE
                DriverID := PopupDeliveryDriver;
            IF DriverID = '' THEN
                EXIT;

            DeliveryDriverTrip_l.RESET;
            DeliveryDriverTrip_l.SETCURRENTKEY("Driver ID", "Store No.", "Trip Counter");
            DeliveryDriverTrip_l.SETRANGE(DeliveryDriverTrip_l."Driver ID", DriverID);
            DeliveryDriverTrip_l.SETRANGE(DeliveryDriverTrip_l."Store No.", DeliveryTrip_l."Store No.");
            IF NOT DeliveryDriverTrip_l.FINDLAST THEN
                EXIT;

        END ELSE BEGIN
            IF NOT DeliveryTrip_l.GET(GlobalRec."Current-RECEIPT") THEN
                EXIT;
            IF NOT DeliveryDriverTrip_l.GET(GlobalRec.Parameter, GlobalRec."Store Access", GlobalRec."Current-LINE") THEN
                EXIT;
        END;

        IF pUnassign THEN BEGIN
            DriverID := GlobalRec.Parameter;
            //DeliveryTrip_l.GET(GlobalRec."Current-RECEIPT");
        END;

        //DeliveryDriverTrip_l.RESET;
        //DeliveryDriverTrip_l.SETCURRENTKEY("Driver ID","Store No.","Trip Counter");
        //DeliveryDriverTrip_l.SETRANGE(DeliveryDriverTrip_l."Driver ID",DriverID);
        //DeliveryDriverTrip_l.SETRANGE(DeliveryDriverTrip_l."Store No.",DeliveryTrip_l."Store No.");
        //IF NOT DeliveryDriverTrip_l.FINDLAST THEN
        //EXIT
        //ELSE BEGIN

        IF GlobalRec."Post Command" <> 'REOPEN' THEN
            IF DeliveryDriverTrip_l."Functionality Type" = DeliveryDriverTrip_l."Functionality Type"::Automatic THEN BEGIN
                MESSAGE(STRSUBSTNO(Txt1, DeliveryDriverTrip_l.FIELDCAPTION("Functionality Type"), FORMAT(DeliveryDriverTrip_l."Functionality Type")));
                EXIT;
            END;

        IF GlobalRec."Post Command" <> 'REOPEN' THEN
            IF DeliveryDriverTrip_l.Status <> DeliveryDriverTrip_l.Status::Open THEN BEGIN
                MESSAGE(STRSUBSTNO(Txt1, DeliveryDriverTrip_l.FIELDCAPTION(Status), FORMAT(DeliveryDriverTrip_l.Status)));
                EXIT;
            END;

        IF pUnassign THEN BEGIN

            DeliveryTrip_l.VALIDATE("Trip. Status", DeliveryTrip_l."Trip. Status"::"Assign Manual");
            IF NOT DelOrder.GET(DeliveryTrip_l."Order No.") THEN BEGIN
                DeliveryTrip_l."General Status" := DeliveryTrip_l."General Status"::InQueue;
                DeliveryTrip_l.MODIFY;
            END ELSE BEGIN
                //DeliveryTrip_l."General Status" := DeliveryTrip_l."General Status"::InProcess;
                DeliveryTrip_l.DELETE;
            END;
        END ELSE BEGIN
            DeliveryTrip_l.VALIDATE("Trip. Status", DeliveryTrip_l."Trip. Status"::"Assigned Driver");
            DeliveryTrip_l."Trip No. (LS Retail)" := DeliveryDriverTrip_l."Trip Counter";
            DeliveryTrip_l."Driver ID" := DriverID;
            IF Staff_l.GET(DriverID) THEN
                DeliveryTrip_l."Driver Name" := Staff_l."Name on Receipt";

            DeliveryTrip_l.MODIFY;
        END;

        UpdateValuesDelDriverTripExt(DeliveryDriverTrip_l);
        DeliveryDriverTrip_l.MODIFY;

        //IF DeliveryDriverTrip_l."No. of Orders" = 0 THEN
        //SendTrip(DeliveryDriverTrip_l,2)
        //ELSE BEGIN
        //DeliveryDriverTrip_l.MODIFY;
        //END;

        //END;
    end;

    //funcion tomada de codeunit delivery order management
    procedure PopupDeliveryDriver(): Text
    var
        PopupMenuLine: Record "LSC POS Menu Line";
        PopupPosComm: Codeunit "LSC Pop-up POS Commands";
    begin
        PopupMenuLine.INIT;
        PopupMenuLine.Command := 'POPUPDELDRIVERS';
        PopupMenuLine."Pos Event Type" := PopupMenuLine."Pos Event Type"::BUTTONPRESS;
        PopupPosComm.RUN(PopupMenuLine);
        EXIT(PopupMenuLine."Current-INPUT");
    end;

    procedure UnAssignFromPageExt(pDelTrip: Record "FSN Delivery Trip"; pSource: Code[20]; pDelDriverTrip: Record "LSC Delivery Driver Trip")
    var
        lTxt1: Label 'Cant be quit form trip';
    begin
        GlobalRec."Current-RECEIPT" := pDelTrip."Order No.";
        GlobalRec."Store Access" := pDelDriverTrip."Store No.";
        GlobalRec.Parameter := pDelDriverTrip."Driver ID";
        GlobalRec."Current-LINE" := pDelDriverTrip."Trip Counter";
        GlobalRec."Post Command" := pSource;

        AssignExt(TRUE);
        IF pDelTrip.GET(pDelTrip."Order No.") THEN
            IF pDelTrip."Trip No. (LS Retail)" > 0 THEN
                ERROR(lTxt1);
    end;

    procedure GetDriverNameExt(IDStaff: Code[20]; NameReceipt: Text[15]) ReturnTxt: Text[50]
    var
        DeliveryDriverTrip_l: Record "LSC Delivery Driver Trip";
        lTxt1: Label '%1 [Open..]';
        lTxt2: Label '%1 [In Trip]';
    begin
        CLEAR(ReturnTxt);
        DeliveryDriverTrip_l.RESET;
        DeliveryDriverTrip_l.SETCURRENTKEY("Driver ID", "Store No.", "Trip Counter");
        DeliveryDriverTrip_l.SETRANGE(DeliveryDriverTrip_l."Driver ID", IDStaff);
        DeliveryDriverTrip_l.SETRANGE(DeliveryDriverTrip_l."Store No.", POSSESSION.StoreNo);
        IF DeliveryDriverTrip_l.FINDLAST THEN
            IF (DeliveryDriverTrip_l.Status = DeliveryDriverTrip_l.Status::Open) AND (DeliveryDriverTrip_l."No. of Orders" > 0) THEN
                ReturnTxt := STRSUBSTNO(lTxt1, NameReceipt)
            ELSE
                IF DeliveryDriverTrip_l.Status = DeliveryDriverTrip_l.Status::Closed THEN
                    ReturnTxt := STRSUBSTNO(lTxt2, NameReceipt);

        IF ReturnTxt = '' THEN
            ReturnTxt := NameReceipt;
    end;

    procedure SendTrip(var pDeliveryDriverTrip: Record "LSC Delivery Driver Trip"; pAction: Option Close,Finalize,Cancel,CancelNew)
    var
        DeliveryTrip_l: Record "FSN Delivery Trip";
        DelOrder: Record "LSC Delivery Order";
        PostedDelOrder: Record "LSC Posted Delivery Order";
        ToQueue: Boolean;
        Txt1: Label 'Send order to Queue?';
        Txt2: Label 'Cant be start trip, order %1 ';
        Txt3: Label 'Order must be invoiced.\%1\%2\%3';
        TransPayment: Record "LSC Trans. Payment Entry";
        TenderTypeStp: Record "LSC Tender Type Setup";
        TransHdr: Record "LSC Transaction Header";
        CanByChange: Boolean;
        DAF: Codeunit "FSN DAF Integration";
        RESULTTxt: Text;
        Txt4: Label 'Trip was cancel in DAF';
        Txt5: Label 'Cant be finalize trip. unknow error';
        PosDelError: Label 'This order number does not belong to a delivery order';
        StaffStoreLinks: Record "LSC STAFF Store Link";
    begin
        IF pAction = pAction::Finalize THEN
            IF pDeliveryDriverTrip."Functionality Type" = pDeliveryDriverTrip."Functionality Type"::Automatic THEN BEGIN
                DAF.FinalizeTripInDAF(pDeliveryDriverTrip."Driver ID", pDeliveryDriverTrip."Store No.", pDeliveryDriverTrip."Trip Counter", RESULTTxt);
                IF NOT (RESULTTxt = 'OK') THEN
                    IF RESULTTxt = '' THEN
                        ERROR(Txt5)
                    ELSE
                        IF RESULTTxt = 'CANCEL' THEN
                            ERROR(Txt4)
                        ELSE
                            ERROR(RESULTTxt);
            END;
        DeliveryTrip_l.RESET;
        DeliveryTrip_l.SETRANGE(DeliveryTrip_l."Store No.", pDeliveryDriverTrip."Store No.");
        DeliveryTrip_l.SETRANGE(DeliveryTrip_l."Driver ID", pDeliveryDriverTrip."Driver ID");
        DeliveryTrip_l.SETRANGE(DeliveryTrip_l."Trip No. (LS Retail)", pDeliveryDriverTrip."Trip Counter");
        IF DeliveryTrip_l.FIND('-') THEN
            REPEAT
                IF pAction = pAction::Close THEN
                    IF NOT ((DeliveryTrip_l."Order Amount" = 0) AND (DeliveryTrip_l."Trip Amount" = 0) AND (DeliveryTrip_l."Payment Name" = 'TIPOLOGIA')) THEN //WVILLALTA 01.21-                                                                                                                                           //WVILLALTA 01.21+
                        IF NOT PostedDelOrder.GET(DeliveryTrip_l."Order No.") THEN begin
                            TransHdr.Reset();
                            TransHdr.SetRange(TransHdr."Receipt No.", DeliveryTrip_l."Order No.");
                            IF NOT TransHdr.FindFirst() then
                                ERROR(STRSUBSTNO(Txt3, DeliveryTrip_l."Order No.", DeliveryTrip_l."Phone No.", DeliveryTrip_l."Order Amount"))
                            ELSE
                                IF NOT InsertPostedDeliveryOrder(TransHdr) then
                                    ERROR(PosDelError);
                        end;
                CASE pAction OF
                    pAction::Close:
                        BEGIN
                            DeliveryTrip_l.VALIDATE("Trip. Status", DeliveryTrip_l."Trip. Status"::"Trip Starting");
                            RecalctDriverAmtOnChangeFieldChange(DeliveryTrip_l, 0, 1);
                            DeliveryTrip_l.MODIFY;
                        END;
                    pAction::Finalize:
                        BEGIN
                            DeliveryTrip_l.VALIDATE("Trip. Status", DeliveryTrip_l."Trip. Status"::"Trip Finalized");
                            //DeliveryTrip_l.MODIFY;
                            PostTripExt(DeliveryTrip_l);
                        END;
                    pAction::Cancel, pAction::CancelNew:
                        BEGIN
                            DeliveryTrip_l.VALIDATE("General Status", DeliveryTrip_l."General Status"::InQueue);
                            DeliveryTrip_l.MODIFY;
                        END;
                END;
            UNTIL DeliveryTrip_l.NEXT = 0;

        CASE pAction OF
            pAction::Close:
                BEGIN
                    CloseTrip(pDeliveryDriverTrip."Driver ID", pDeliveryDriverTrip."Store No.");
                    IF pDeliveryDriverTrip.GET(pDeliveryDriverTrip."Driver ID", pDeliveryDriverTrip."Store No.", pDeliveryDriverTrip."Trip Counter") THEN BEGIN
                        UpdateValuesDelDriverTripExt(pDeliveryDriverTrip);
                        pDeliveryDriverTrip.MODIFY;
                    END;
                END;
            pAction::Finalize:
                BEGIN
                    pDeliveryDriverTrip.Status := pDeliveryDriverTrip.Status::Finalized;
                    pDeliveryDriverTrip."Date Finalized" := TODAY;
                    pDeliveryDriverTrip."Time Finalized" := TIME;
                    pDeliveryDriverTrip.MODIFY;
                    IF pDeliveryDriverTrip."Functionality Type" = pDeliveryDriverTrip."Functionality Type"::Automatic THEN
                        IF StaffStoreLinks.GET(pDeliveryDriverTrip."Driver ID", pDeliveryDriverTrip."Store No.") THEN BEGIN
                            StaffStoreLinks."On Call" := FALSE;
                            StaffStoreLinks.MODIFY(TRUE);
                        END ELSE
                            ;
                    CreateTrip(pDeliveryDriverTrip."Driver ID", pDeliveryDriverTrip."Store No."
                      , 0, 0, FALSE, TRUE);
                END;
            pAction::Cancel, pAction::CancelNew:
                BEGIN
                    pDeliveryDriverTrip.Status := pDeliveryDriverTrip.Status::Cancelled;
                    pDeliveryDriverTrip."Starting Float" := 0;
                    pDeliveryDriverTrip."Float Returned" := 0;
                    pDeliveryDriverTrip."No. of Orders" := 0;
                    pDeliveryDriverTrip."Gross Amount" := 0;
                    pDeliveryDriverTrip.MODIFY(TRUE);

                    IF pDeliveryDriverTrip."Functionality Type" = pDeliveryDriverTrip."Functionality Type"::Automatic THEN
                        IF StaffStoreLinks.GET(pDeliveryDriverTrip."Driver ID", pDeliveryDriverTrip."Store No.") THEN BEGIN
                            StaffStoreLinks."On Call" := FALSE;
                            StaffStoreLinks.MODIFY(TRUE);
                        END ELSE
                            CreateTrip(pDeliveryDriverTrip."Driver ID", pDeliveryDriverTrip."Store No."
                              , 0, 0, FALSE, FALSE);
                END;
        END;
    end;

    procedure SendTrip2(var pDeliveryDriverTrip: Record "LSC Delivery Driver Trip"; pAction: Option Close,Finalize,Cancel,CancelNew)
    var
        DeliveryTrip_l: Record "FSN Delivery Trip";
        DelOrder: Record "LSC Delivery Order";
        PostedDelOrder: Record "LSC Posted Delivery Order";
        ToQueue: Boolean;
        Txt1: Label 'Send order to Queue?';
        Txt2: Label 'Cant be start trip, order %1 ';
        Txt3: Label 'Order must be invoiced.\%1\%2\%3';
        TransPayment: Record "LSC Trans. Payment Entry";
        TenderTypeStp: Record "LSC Tender Type Setup";
        TransHdr: Record "LSC Transaction Header";
        CanByChange: Boolean;
        DAF: Codeunit "FSN DAF Integration";
        RESULTTxt: Text;
        Txt4: Label 'Trip was cancel in DAF';
        Txt5: Label 'Cant be finalize trip. unknow error';
        PosDelError: Label 'This order number does not belong to a delivery order';
        StaffStoreLinks: Record "LSC STAFF Store Link";
    begin
        IF pAction = pAction::Finalize THEN
            IF pDeliveryDriverTrip."Functionality Type" = pDeliveryDriverTrip."Functionality Type"::Automatic THEN BEGIN
                DAF.FinalizeTripInDAF(pDeliveryDriverTrip."Driver ID", pDeliveryDriverTrip."Store No.", pDeliveryDriverTrip."Trip Counter", RESULTTxt);
                IF NOT (RESULTTxt = 'OK') THEN
                    IF RESULTTxt = '' THEN
                        ERROR(Txt5)
                    ELSE
                        IF RESULTTxt = 'CANCEL' THEN
                            ERROR(Txt4)
                        ELSE
                            ERROR(RESULTTxt);
            END;
        DeliveryTrip_l.RESET;
        DeliveryTrip_l.SETRANGE(DeliveryTrip_l."Store No.", pDeliveryDriverTrip."Store No.");
        DeliveryTrip_l.SETRANGE(DeliveryTrip_l."Driver ID", pDeliveryDriverTrip."Driver ID");
        DeliveryTrip_l.SETRANGE(DeliveryTrip_l."Trip No. (LS Retail)", pDeliveryDriverTrip."Trip Counter");
        IF DeliveryTrip_l.FIND('-') THEN
            REPEAT
                /*IF pAction = pAction::Close THEN
                    IF NOT ((DeliveryTrip_l."Order Amount" = 0) AND (DeliveryTrip_l."Trip Amount" = 0) AND (DeliveryTrip_l."Payment Name" = 'TIPOLOGIA')) THEN //WVILLALTA 01.21-                                                                                                                                           //WVILLALTA 01.21+
                        IF NOT PostedDelOrder.GET(DeliveryTrip_l."Order No.") THEN begin
                            TransHdr.Reset();
                            TransHdr.SetRange(TransHdr."Receipt No.", DeliveryTrip_l."Order No.");
                            IF NOT TransHdr.FindFirst() then
                                ERROR(STRSUBSTNO(Txt3, DeliveryTrip_l."Order No.", DeliveryTrip_l."Phone No.", DeliveryTrip_l."Order Amount"))
                            ELSE
                                IF NOT InsertPostedDeliveryOrder(TransHdr) then
                                    ERROR(PosDelError);
                        end;*/
                CASE pAction OF
                    pAction::Close:
                        BEGIN
                            DeliveryTrip_l.VALIDATE("Trip. Status", DeliveryTrip_l."Trip. Status"::"Trip Starting");
                            RecalctDriverAmtOnChangeFieldChange(DeliveryTrip_l, 0, 1);
                            DeliveryTrip_l.MODIFY;
                        END;
                    pAction::Finalize:
                        BEGIN
                            DeliveryTrip_l.VALIDATE("Trip. Status", DeliveryTrip_l."Trip. Status"::"Trip Finalized");
                            //DeliveryTrip_l.MODIFY;
                            PostTripExt(DeliveryTrip_l);
                        END;
                    pAction::Cancel, pAction::CancelNew:
                        BEGIN
                            DeliveryTrip_l.VALIDATE("General Status", DeliveryTrip_l."General Status"::InQueue);
                            DeliveryTrip_l.MODIFY;
                        END;
                END;
            UNTIL DeliveryTrip_l.NEXT = 0;

        CASE pAction OF
            pAction::Close:
                BEGIN
                    CloseTrip(pDeliveryDriverTrip."Driver ID", pDeliveryDriverTrip."Store No.");
                    IF pDeliveryDriverTrip.GET(pDeliveryDriverTrip."Driver ID", pDeliveryDriverTrip."Store No.", pDeliveryDriverTrip."Trip Counter") THEN BEGIN
                        UpdateValuesDelDriverTripExt(pDeliveryDriverTrip);
                        pDeliveryDriverTrip.MODIFY;
                    END;
                END;
            pAction::Finalize:
                BEGIN
                    pDeliveryDriverTrip.Status := pDeliveryDriverTrip.Status::Finalized;
                    pDeliveryDriverTrip."Date Finalized" := TODAY;
                    pDeliveryDriverTrip."Time Finalized" := TIME;
                    pDeliveryDriverTrip.MODIFY;
                    IF pDeliveryDriverTrip."Functionality Type" = pDeliveryDriverTrip."Functionality Type"::Automatic THEN
                        IF StaffStoreLinks.GET(pDeliveryDriverTrip."Driver ID", pDeliveryDriverTrip."Store No.") THEN BEGIN
                            StaffStoreLinks."On Call" := FALSE;
                            StaffStoreLinks.MODIFY(TRUE);
                        END ELSE
                            ;
                    CreateTrip(pDeliveryDriverTrip."Driver ID", pDeliveryDriverTrip."Store No."
                      , 0, 0, FALSE, TRUE);
                END;
            pAction::Cancel, pAction::CancelNew:
                BEGIN
                    pDeliveryDriverTrip.Status := pDeliveryDriverTrip.Status::Cancelled;
                    pDeliveryDriverTrip."Starting Float" := 0;
                    pDeliveryDriverTrip."Float Returned" := 0;
                    pDeliveryDriverTrip."No. of Orders" := 0;
                    pDeliveryDriverTrip."Gross Amount" := 0;
                    pDeliveryDriverTrip.MODIFY(TRUE);

                    IF pDeliveryDriverTrip."Functionality Type" = pDeliveryDriverTrip."Functionality Type"::Automatic THEN
                        IF StaffStoreLinks.GET(pDeliveryDriverTrip."Driver ID", pDeliveryDriverTrip."Store No.") THEN BEGIN
                            StaffStoreLinks."On Call" := FALSE;
                            StaffStoreLinks.MODIFY(TRUE);
                        END ELSE
                            CreateTrip(pDeliveryDriverTrip."Driver ID", pDeliveryDriverTrip."Store No."
                              , 0, 0, FALSE, FALSE);
                END;
        END;
    end;

    //funcion de tabla Delivery Driver Trip
    procedure CreateTrip(DriverID: Code[20]; StoreNo: Code[10]; OrgFloat: Decimal; AddedFloat: Decimal; ResetTrip: Boolean; ResetFloat: Boolean)
    var
        DriverTrip: Record "LSC Delivery Driver Trip";
        NewTripCounter: Integer;
        NewTripNo: Integer;
        NewTripStartFloat: Decimal;
        NewDriverTrip: Record "LSC Delivery Driver Trip";
    begin
        DriverTrip.RESET;
        DriverTrip.SETRANGE("Driver ID", DriverID);
        DriverTrip.SETRANGE("Store No.", StoreNo);
        IF DriverTrip.FINDLAST THEN BEGIN
            NewTripCounter := DriverTrip."Trip Counter" + 1;
            NewTripNo := DriverTrip."Trip No." + 1;
            IF ResetTrip THEN
                IF CONFIRM(STRSUBSTNO(Text001, DriverTrip.FIELDCAPTION("Trip No."), DriverTrip."Trip No."), FALSE) THEN
                    NewTripNo := 1;
            IF ResetFloat THEN BEGIN
                DriverTrip."Float Returned" := DriverTrip."Starting Float" - OrgFloat;
                DriverTrip.MODIFY(TRUE);
                NewTripStartFloat := OrgFloat + AddedFloat
            END ELSE
                NewTripStartFloat := DriverTrip."Starting Float";
        END ELSE BEGIN
            NewTripCounter := 1;
            NewTripNo := 1;
            NewTripStartFloat := OrgFloat + AddedFloat;
        END;
        NewDriverTrip.INIT;
        NewDriverTrip."Driver ID" := DriverID;
        NewDriverTrip."Store No." := StoreNo;
        NewDriverTrip."Trip Counter" := NewTripCounter;
        NewDriverTrip."Trip No." := NewTripNo;
        NewDriverTrip.Status := NewDriverTrip.Status::Open;
        NewDriverTrip."Starting Float" := NewTripStartFloat;
        NewDriverTrip.INSERT(TRUE);
    end;

    procedure CloseTrip(DriverID: Code[20]; StoreNo: Code[10])
    var
        DriverTrip: Record "LSC Delivery Driver Trip";
    begin
        DriverTrip.RESET;
        DriverTrip.SETRANGE("Driver ID", DriverID);
        DriverTrip.SETRANGE("Store No.", StoreNo);
        DriverTrip.SETRANGE(Status, DriverTrip.Status::Open);
        IF DriverTrip.FINDLAST THEN BEGIN
            DriverTrip.Status := DriverTrip.Status::Closed;
            DriverTrip.MODIFY(TRUE);
        END;
    end;

    procedure DriverOffCall(DriverID: Code[20]; StoreNo: Code[10]): Boolean
    var
        DriverTrip: Record "LSC Delivery Driver Trip";
        DelOrd: Record "LSC Delivery Order";
        PosTrans: Record "LSC POS Transaction";
    begin
        DriverTrip.RESET;
        DriverTrip.SETRANGE("Driver ID", DriverID);
        DriverTrip.SETRANGE("Store No.", StoreNo);
        DriverTrip.SETFILTER(Status, '%1|%2', DriverTrip.Status::Open, DriverTrip.Status::Closed);
        IF DriverTrip.FINDFIRST THEN BEGIN
            DriverTrip.CALCFIELDS("No. of Orders (Open)");
            IF DriverTrip."No. of Orders (Open)" > 0 THEN BEGIN
                IF CONFIRM(STRSUBSTNO(Text002, DriverID), FALSE) THEN BEGIN
                    DelOrd.RESET;
                    DelOrd.SETCURRENTKEY("Driver ID", "Restaurant No.", "Trip Counter");
                    DelOrd.SETRANGE("Driver ID", DriverID);
                    DelOrd.SETRANGE("Restaurant No.", StoreNo);
                    DelOrd.SETRANGE("Trip Counter", DriverTrip."Trip Counter");
                    IF DelOrd.FINDFIRST THEN
                        REPEAT
                            AssignToOpen;
                            DelOrd.MODIFY(TRUE);
                            IF PosTrans.GET(DelOrd."Order No.") THEN BEGIN
                                PosTrans."Sales Staff" := '';
                                PosTrans.MODIFY();
                            END;
                        UNTIL DelOrd.NEXT = 0;
                END ELSE
                    EXIT(FALSE);
            END;
            DriverTrip.Status := DriverTrip.Status::Cancelled;
            DriverTrip.MODIFY(TRUE);
        END;
        EXIT(TRUE);
    end;

    //funcion tomada de delivery order
    procedure AssignToOpen()
    deliveryOrder: Record "LSC Delivery Order";
    begin
        deliveryOrder.VALIDATE("Assigned to Driver", FALSE);
        deliveryOrder."Driver ID" := '';
        deliveryOrder."Driver Phone No." := '';
        deliveryOrder."Trip Counter" := 0;
        IF deliveryOrder."Process Status" <> deliveryOrder."Process Status"::Finished THEN
            deliveryOrder.VALIDATE("General Status", deliveryOrder."General Status"::"In Process");
    end;

    procedure DeleteOrderFromQueue(pDelTrip: Record "FSN Delivery Trip"; pAction: Option CancelFromQueue,Post)
    begin
        COMMIT;
        CASE pAction OF
            pAction::CancelFromQueue:
                BEGIN
                    pDelTrip.VALIDATE(pDelTrip."Trip. Status", pDelTrip."Trip. Status"::"Cancelled In Rest.");
                    PostedDeliveryTrip.TRANSFERFIELDS(pDelTrip);
                    IF NOT PostedDeliveryTrip.INSERT THEN
                        PostedDeliveryTrip.MODIFY;
                    pDelTrip.DELETE
                END;
        END;
    end;

    procedure UpdateValuesDelDriverTripExt(var pDelDriverTrip: Record "LSC Delivery Driver Trip")
    var
        Deltrip: Record "FSN Delivery Trip";
    begin

        Deltrip.RESET;
        Deltrip.SETCURRENTKEY("Trip. Status", "General Status", "Restaurant WS Estatus");
        //Deltrip.SETRANGE(Deltrip."Trip. Status",Deltrip."Trip. Status"::"Assigned Driver");
        Deltrip.SETRANGE(Deltrip."General Status", Deltrip."General Status"::InProcess);
        Deltrip.SETRANGE(Deltrip."Trip No. (LS Retail)", pDelDriverTrip."Trip Counter");
        Deltrip.SETRANGE(Deltrip."Store No.", pDelDriverTrip."Store No.");
        Deltrip.SETRANGE(Deltrip."Driver ID", pDelDriverTrip."Driver ID");

        pDelDriverTrip."No. of Orders" := Deltrip.COUNT;
        Deltrip.CALCSUMS(Deltrip.Change, Deltrip."Order Amount", Deltrip."Trip Amount");

        IF NOT (pDelDriverTrip."Functionality Type" = pDelDriverTrip."Functionality Type"::Automatic) THEN
            pDelDriverTrip."DAF Trip No." := 0;
        pDelDriverTrip."Starting Float" := Deltrip.Change;
        pDelDriverTrip."Gross Amount" := Deltrip."Order Amount";
        pDelDriverTrip."Driver Amount" := Deltrip."Trip Amount";
    end;

    procedure VerifyTenderForDriverAmt(pTenderTypeSetup: Record "LSC Tender Type Setup"; pFilter: Integer): Boolean
    begin
        EXIT(pTenderTypeSetup."FSN Function in CC" IN [pTenderTypeSetup."FSN Function in CC"::Check
                                             //, pTenderTypeSetup."FSN Function in CC"::Card
                                             , pTenderTypeSetup."FSN Function in CC"::Change]);
    end;

    procedure RecalctDriverAmtOnChangeFieldChange(var pDelTrip: Record "FSN Delivery Trip"; pNewChange: Decimal; pEntryType: Integer)
    var
        POSTrans: Record "LSC POS Transaction";
        POSLine: Record "LSC POS Trans. Line";
        TransHdr: Record "LSC Transaction Header";
        TransPayment: Record "LSC Trans. Payment Entry";
        CanBeChange: Boolean;
        DeliveryOrder_l: Record "LSC Delivery Order";
        QtyTender: Integer;
        TenderTMP: Record "LSC Tender Type Setup" temporary;
        cambio: Decimal;
    begin
        //pEntryType 0 = OnChange

        pDelTrip."Order Amount" := 0;
        pDelTrip."Trip Amount" := 0;
        IF pEntryType = 0 THEN
            pDelTrip.Change := pNewChange;

        TenderTMP.RESET;
        TenderTMP.DELETEALL;

        CLEAR(CanBeChange);
        IF POSTrans.GET(pDelTrip."Order No.") THEN BEGIN
            POSLine.RESET;
            POSLine.SETRANGE(POSLine."Receipt No.", POSTrans."Receipt No.");
            POSLine.SETRANGE(POSLine."Entry Type", POSLine."Entry Type"::Payment);
            POSLine.SETRANGE(POSLine."Entry Status", 0);
            IF POSLine.FIND('-') THEN
                REPEAT
                    IF TenderTypeSetup.GET(POSLine.Number) THEN BEGIN
                        TenderTMP.Code := TenderTypeSetup.Code;
                        TenderTMP.Description := TenderTypeSetup.Description;
                        IF TenderTMP.INSERT THEN;

                        CanBeChange := TenderTypeSetup."FSN Function in CC" = TenderTypeSetup."FSN Function in CC"::Change;
                        IF VerifyTenderForDriverAmt(TenderTypeSetup, 0) THEN
                            pDelTrip."Trip Amount" += POSLine.Amount;
                        pDelTrip."Order Amount" += POSLine.Amount;
                    END;
                UNTIL POSLine.NEXT = 0;
            IF pDelTrip.Change = 0 THEN
                IF DeliveryOrder_l.GET(pDelTrip."Order No.") THEN
                    pDelTrip.Change := DeliveryOrder_l."FSN Cash Change";
            IF NOT CanBeChange THEN
                pDelTrip.Change := 0;

            pDelTrip."Trip Amount" += pDelTrip.Change;
        END ELSE BEGIN
            TransHdr.RESET;
            TransHdr.SETCURRENTKEY("Receipt No.", Date);
            TransHdr.SETRANGE(TransHdr."Receipt No.", pDelTrip."Order No.");
            IF TransHdr.FINDFIRST THEN BEGIN
                TransPayment.RESET;
                TransPayment.SETRANGE(TransPayment."Store No.", TransHdr."Store No.");
                TransPayment.SETRANGE(TransPayment."POS Terminal No.", TransHdr."POS Terminal No.");
                TransPayment.SETRANGE(TransPayment."Transaction No.", TransHdr."Transaction No.");
                IF TransPayment.FIND('-') THEN
                    REPEAT
                        IF TenderTypeSetup.GET(TransPayment."Tender Type") THEN BEGIN
                            TenderTMP.Code := TenderTypeSetup.Code;
                            TenderTMP.Description := TenderTypeSetup.Description;
                            IF TenderTMP.INSERT THEN;

                            CanBeChange := TenderTypeSetup."FSN Function in CC" = TenderTypeSetup."FSN Function in CC"::Change;
                            if TransPayment."Change Line" then
                                cambio := TransPayment."Amount Tendered";

                            IF VerifyTenderForDriverAmt(TenderTypeSetup, 0) THEN
                                pDelTrip."Trip Amount" += TransPayment."Amount Tendered";


                            pDelTrip."Order Amount" += TransPayment."Amount Tendered";
                        END;
                    UNTIL TransPayment.NEXT = 0;

                IF NOT CanBeChange THEN
                    pDelTrip.Change := 0;
                pDelTrip."Trip Amount" += cambio * -1;
                if pDelTrip.Change = 0 then
                    pDelTrip.Change := cambio;
            END;
        END;

        TenderTMP.RESET;
        CASE TenderTMP.COUNT OF
            0:
                pDelTrip."Payment Name" := 'TIPOLOGIA';
            1:
                BEGIN
                    TenderTMP.FINDFIRST;
                    pDelTrip."Payment Name" := TenderTMP.Description;
                END;
            ELSE
                pDelTrip."Payment Name" := Text024;
        END;
    end;

    procedure PostTripExt(DelTrip: Record "FSN Delivery Trip")
    var
        PostDelTrip: Record "FSN Posted Delivery Trip";
        PostedDeliveryOrd: Record "LSC Posted Delivery Order";
        TransactionHeader: Record "LSC Transaction Header";
    begin
        IF (DelTrip."Trip. Status" = DelTrip."Trip. Status"::"Trip Finalized") AND
          PostedDeliveryOrd.GET(DelTrip."Order No.") THEN BEGIN
            PostedDeliveryOrd."Time Assigned" := DT2TIME(DelTrip."Trip Open Time");
            PostedDeliveryOrd."Date Assigned" := DT2DATE(DelTrip."Trip Open Time");

            if PostedDeliveryOrd."Posting Date" = 0D then begin
                TransactionHeader.reset();
                TransactionHeader.SetRange(TransactionHeader."Store No.", DelTrip."Store No.");
                TransactionHeader.SetRange(TransactionHeader."POS Terminal No.", DelTrip."POS Terminal No.");
                TransactionHeader.SetRange(TransactionHeader."Receipt No.", DelTrip."Order No.");
                if TransactionHeader.FindFirst() then begin
                    PostedDeliveryOrd."Posting Date" := TransactionHeader.Date;
                    PostedDeliveryOrd."Posting Time" := TransactionHeader.Time;
                end else begin
                    PostedDeliveryOrd."Posting Date" := Today();
                    PostedDeliveryOrd."Posting Time" := Time;
                end;
            end;
            PostedDeliveryOrd.VALIDATE(PostedDeliveryOrd.Delivered, TRUE);
            PostedDeliveryOrd."Driver ID" := DelTrip."Driver ID";
            PostedDeliveryOrd."Trip Counter" := DelTriP."Trip No. (LS Retail)";
            PostedDeliveryOrd."Assigned to Driver" := TRUE;
            PostedDeliveryOrd.MODIFY;
        END;
        CLEAR(PostDelTrip);
        PostDelTrip.INIT;
        PostDelTrip.TRANSFERFIELDS(DelTrip);
        IF NOT PostDelTrip.INSERT THEN
            PostDelTrip.MODIFY;
        DelTrip.DELETE;
    end;

    procedure CheckTripDAFExt()
    var
        DAF: Codeunit "FSN DAF Integration";
        MsgTxt: Text;
    begin
        IF NOT DAF.CheckTripsFromDAF(POSSESSION.StoreNo(), MsgTxt) THEN
            POSGUI.PosMessage(COPYSTR(MsgTxt, 1, 250));
    end;

    procedure HOSPCommandDriverExt(): Code[30]
    var
        Parameter: Record "FSN Parameter";
    begin
        IF Parameter.GET('DAF', 'DAF_API') AND Parameter.Activo THEN
            EXIT(Parameter."Value Text 2");
        EXIT('DRIVER');
    end;

    procedure CreateTripForDelivery(pPOSTrans: Record "LSC POS Transaction")
    var
        DelOrder: Record "LSC Delivery Order";
        DelTrip: Record "FSN Delivery Trip";
        DAF: Codeunit "FSN DAF Integration";
    begin
        IF DelOrder.GET(pPOSTrans."Receipt No.") AND (DelOrder."Order Type Option" <> 4) THEN
            IF NOT DelTrip.GET(pPOSTrans."Receipt No.") THEN BEGIN
                DAF.CreateTripDAF(DelOrder, TRUE);

                IF DelTrip.GET(pPOSTrans."Receipt No.") THEN BEGIN
                    DelTrip."General Status" := DelTrip."General Status"::InQueue;
                    DelTrip.MODIFY;
                END;
            END;
    end;

    procedure InsertPostedDeliveryOrder(TransHdr: Record "LSC Transaction Header"): Boolean
    var
        myInt: Integer;
        DeliveryOrder: Record "LSC Delivery Order";
        PostedDeliveryOrder: Record "LSC Posted Delivery Order";
        FSNUtility: Codeunit "FSN Utility";
        posmenu: Record "LSC POS Menu Line";
    begin
        DeliveryOrder.Reset();
        DeliveryOrder.SetRange(DeliveryOrder."Order No.", TransHdr."Receipt No.");
        if NOT DeliveryOrder.Find('-') then
            exit(false);
        PostedDeliveryOrder.Init();
        PostedDeliveryOrder.TransferFields(DeliveryOrder);
        /* XMLRequest := DeliveryOrder."Order No.";
        XMLResponse := TransHdr."Receipt No.";
        RequestID := Txt1;
        //FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, posmenu, Processed, MsgResult); */
        if TransHdr."Entry Status" = TransHdr."Entry Status"::Voided then
            PostedDeliveryOrder."Rest. Web Service Status" := PostedDeliveryOrder."Rest. Web Service Status"::"Cancelled-Not Sent"
        else
            PostedDeliveryOrder."Rest. Web Service Status" := PostedDeliveryOrder."Rest. Web Service Status"::"Finalized-Not Sent";
        if PostedDeliveryOrder.Insert() then
            exit(true);

        DeliveryOrder.Delete(true);
    end;

    procedure ReportZValidate(var pTextError: Text): Boolean
    var
        StaffStoreLink_l: Record "LSC STAFF Store Link";
        lText001: Label 'You must liquidate the bikes %1';
        lText002: Label 'before printing the cut';
        DelTrip: Record "FSN Delivery Trip";
        TransHdr: Record "LSC Transaction Header";
    begin
        /*Filtrar numero de pedido de delivery trip, traer numero de terminal cuando se encuentre numero de pedido*/

        DelTrip.RESET;
        DelTrip.SETRANGE(DelTrip."Store No.", POSSESSION.StoreNo());
        DelTrip.SETRANGE(DelTrip."General Status", DelTrip."General Status"::InProcess);
        IF DelTrip.FIND('-') THEN BEGIN
            repeat
                TransHdr.SETRANGE(TransHdr."Receipt No.", DelTrip."Order No.");
                IF TransHdr.Find('-') AND (TransHdr."POS Terminal No." = POSSESSION.TerminalNo) then begin
                    pTextError := STRSUBSTNO(lText001, lText002);
                    EXIT(FALSE);
                end;
            until DelTrip.Next = 0

        END;
        EXIT(TRUE);
    end;
    #endregion

    #region [subscriptions]
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnBeforeVoidTransaction', '', true, true)]
    local procedure "LSC POS Transaction Events_OnBeforeVoidTransaction"(var POSTransaction: Record "LSC POS Transaction")
    var
        ePosControl: Codeunit "LSC POS Control Interface";
        RecNo: code[20];
    begin
        if IFoundIt then begin
            RecNo := ePosControl.GetDataGridKeyValue(ePosControl.ActiveDataGrid());
            POSTransaction.Reset();
            POSTransaction.Get(RecNo);
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Controller", 'OnButtonPressed', '', true, true)]
    local procedure "LSC POS Controller_OnButtonPressed"
    (
        var POSMenuLine: Record "LSC POS Menu Line";
        var handled: Boolean
    )
    var
        TextError: Text;
    begin
        if POSMenuLine.Command = 'FSNPRINT_Z' then begin
            /*  if not ReportZValidate(TextError) then begin
                Message(TextError);
                handled := true;
            end; */
        end;
    end;
    #endregion
}
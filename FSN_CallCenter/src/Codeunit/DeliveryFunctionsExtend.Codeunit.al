codeunit 50014 "FSN Delivery Functions Extend"
{
    TableNo = 99008906;
    trigger OnRun()
    begin
        GlobalRec.COPY(Rec);

        CASE Rec.Command OF
            'CTI':
                CTI();
            'COPYTEXTTRANS':
                CopyFunction("Current-RECEIPT");
            'CHANNEL_LKP':
                FSNCallCenterControl.ShowChannel();
            'CHANNEL_SELECT':
                FSNCallCenterControl.ChannelSelectedPressed();
            'DEL-CHEK-PHONE':
                DelCheckPhone();
            'DEL-ECOMM-INF':
                GetEcommerceInfo(Rec);
            'DEL-ORDER-EXT':
                EXOSelectLookupStore(Rec);
            'DEL_STORE_LINK':
                FSNDeliveryStoreLink.ShowPanelStoreSuggest(Rec);
            'INVENTORYTRANSLINE':
                BEGIN
                    IF POSTransLineBK.GET("Current-RECEIPT", "Current-LINE") THEN
                        FSNDeliveryInvMgt.ValidateServerInventoryLine(POSTransLineBK, 1);
                end;
            'INVENTORYTRANSAC':
                BEGIN
                    IF POSTransactionBK.GET("Current-RECEIPT") THEN
                        FSNDeliveryInvMgt.ValidateServerinventoryTransac(POSTransactionBK, Parameter);
                END;
            'FSN_GET_INVENTORY':
                FSNDeliveryInvMgt.GetInventoryLookUpServer(Rec);
            'PRINT_TENDER_TEXT':
                FSNCheckPayments.InsertAllFreeTextPayments(Rec);
            'SETDOCUMENTTYPE':
                SetDocumentType(Parameter, "Current-RECEIPT");
            'SETINITTRANSLOGIN':
                SetTransaction();
            'QUOTATION':
                begin
                    FSNQuotation.SetMenuLine(Rec);
                    FSNQuotation.SendQuotation(false, '');
                end;
            'SEND_ORDERBACKUP':
                FSNEcommerce.SendOrderBackup(Rec);
            'SUSPENDEXT':
                FSNEcommerce.GetTransSuspList(Rec);
            'SUSPENDEXT_SELECT':
                FSNEcommerce.GetTransSuspListSelect(Rec);
            'SUSPENDCREATEWS':
                FSNEcommerce.CreateWSTable(Rec."Current-RECEIPT");//TESING
            'PHONEFSN':
                begin
                    POSGUI.OpenNumericKeyboard(TextPhone, 0, '', 0, 'FSNPHONE');
                end;

        END;
    end;


    var
        CCcontroler: Codeunit "FSN CallCenter Controller";
        POSSESSION: Codeunit "LSC POS Session";
        POSGUI: Codeunit "LSC POS GUI";
        SuperOrderID: Decimal;
        GlobalRec: Record "LSC POS Menu Line";
        POSFunction: Codeunit "LSC POS Functions";
        POSTransaction: Codeunit "LSC POS Transaction";
        DeliveryOrderBK: Record "LSC Delivery Order";
        DelContactAddressBK: Record "LSC Delivery Contact Address";
        DeliveryStreetBK: Record "LSC Delivery Street";
        POSTransactionBK: Record "LSC POS Transaction";
        POSTransLineBK: Record "LSC POS Trans. Line";
        RetailSetupBK: Record "LSC Retail Setup";
        RetailUserBK: Record "LSC Retail User";
        POSTerminal: Record "LSC POS Terminal";
        CCPOSTermBK: Record "LSC CC POS Term. Assignm.";
        Store: Record "LSC Store";
        BOUTIL: Codeunit "LSC BO Utils";
        EPOSController: Codeunit "LSC POS Controller";
        EPOSControlInterface: Codeunit "LSC POS Control Interface";
        DeliveryOrderManagement: Codeunit "LSC Delivery Order Management";
        FSNDeliveryInvMgt: codeunit "FSN Delivery Inventory Mgt.";
        FSNDeliveryStoreLink: Codeunit "FSN Delivery Store Link";
        FSNCallCenterControl: Codeunit "FSN CallCenter Controller";
        FSNCheckPayments: Codeunit "FSN Check Payments POS";
        FSNEcommerce: Codeunit "FSN Ecommerce CallCenter Mgt.";
        FSNQuotation: Codeunit "FSN Quotation";
        LocalizationExt: Codeunit "LSC Retail Localization Ext.";
        Text000: Label 'Store %1 %2 is not assigment for call center';
        Text013: Label 'Order document type TICKET.\Want to continue?';
        Text014: Label 'Send Order to: %1\Store: %2\Want to continue?';
        Text016: Label 'Item marked not found';
        /*Text017: Label 'Comment';*/
        Text019: Label 'Receipt No. Not available';
        Text020: Label 'New linked order created %1';
        Text026: Label 'Error insert tipology, field was ocuped for %1';
        Text029: Label 'Store delivery %1 and store Transac %2 no match';
        Text031: Label 'Item %1 is assigned to store %2';
        Text032: Label 'Customer request %1';
        Text038: Label 'Last Valid Time for street %1 is %2.\%3';
        Text040: Label 'Select a valid street.';
        //Text042: Label 'Suggest unique %1 %2';
        Text043: Label 'Error credentials';
        PageDeliveryTakeOrder: Page "FSN Take Order CC";
        DeliveryOrderTemp: Record "LSC Delivery Order";
        DeliveryOrdert: Record "LSC Delivery Order";
        TextPhone: Label 'INSERTAR NO. TELEFONO';
        TakeOrder: Page "FSN Take Order CC";
        GlobalContact: Record "Contact" temporary;
        GlobalParametroPQ: Record "FSN Parameter";

    /////////////////////////////////////NEW PROCESS CALL/////////////////////////////////////////////////////////////

    [EventSubscriber(ObjectType::Table, Database::"LSC POS Transaction", 'OnBeforeModifyEvent', '', true, true)]
    local procedure "LSC POS Transaction_OnBeforeModifyEvent"
(
    var Rec: Record "LSC POS Transaction";
    var xRec: Record "LSC POS Transaction";
    RunTrigger: Boolean
)
    var
        cust: Record Customer;
        RetailSetup_l: Record "LSC Retail Setup";
    begin
        RetailSetup_l.Get();
        if RetailSetup_l."FSN Is Local Receipt" and (RetailSetup_l."FSN Last Slipt No." <> '') then begin
            IF POSSESSION.GetValue('VALFSN-SALESSTAFF') <> '' then begin
                if Rec."Sales Staff" <> POSSESSION.GetValue('VALFSN-SALESSTAFF') then
                    Rec."Sales Staff" := POSSESSION.GetValue('VALFSN-SALESSTAFF');
                POSSESSION.SetValue('VALFSN-SALESSTAFF', '');
            end;
            if Rec."Customer No." <> '' then
                if cust.Get(Rec."Customer No.") then begin
                    if Rec."VAT Bus.Posting Group" <> cust."VAT Bus. Posting Group" then
                        Rec."VAT Bus.Posting Group" := cust."VAT Bus. Posting Group";
                end;
            if POSSESSION.GetValue('VALSECC') <> '' then
                if Rec."Entry Status" = Rec."Entry Status"::Voided then begin
                    Rec."Entry Status" := Rec."Entry Status"::" ";
                    POSSESSION.SetValue('VALSECC', '');
                end;
        end;
    end;

    [EventSubscriber(ObjectType::Table, Database::"LSC POS Trans. Line", 'OnBeforeInsertEvent', '', true, true)]
    local procedure "LSC POS Trans. Line_OnBeforeInsertEvent"
(
    var Rec: Record "LSC POS Trans. Line";
    RunTrigger: Boolean
)
    begin
        if (Rec."Entry Type" = Rec."Entry Type"::FreeText) and (Rec."Line No." = 1)
        and (Rec.Description = 'Prepagado') then
            Rec.Description := 'CallCenter';
    end;


    [EventSubscriber(ObjectType::Table, Database::"LSC POS Trans. Line", 'OnBeforeModifyEvent', '', true, true)]
    local procedure "LSC POS Trans. Line_OnBeforeModifyEvent"
    (
        var Rec: Record "LSC POS Trans. Line";
        var xRec: Record "LSC POS Trans. Line";
        RunTrigger: Boolean
    )
    begin
        if (Rec."Entry Type" = Rec."Entry Type"::FreeText) and (Rec."Line No." = 1)
        and (Rec.Description = 'Prepagado') then
            Rec.Description := 'CallCenter';
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
        RetailSetup_l: Record "LSC Retail Setup";
    begin
        if not IsHandled then
            if MenuLine.Command = 'DELEDIT' then begin
                RetailSetup_l.Get();
                if RetailSetup_l."FSN Is Local Receipt" and (RetailSetup_l."FSN Last Slipt No." <> '') then begin
                    IF POSSESSION.GetValue('RUN_DELPROCESSFSN') = 'TRUE' THEN BEGIN
                        POSSESSION.SetValue('RUN_DELPROCESSFSN', 'FALSE');
                        IsHandled := true;
                    END;
                end;
            end;
    end;

    procedure OrderCancelPressed(OrderNo: Code[20])
    var
        CanceledOrderNo: Code[20];
        ChangeMade: Option OrderLines,OrderType,Address,Cancel,OrderTime,Restaurant,RestAddr;
        DeliveryOrder: Record "LSC Delivery Order";
        DelPosComm: codeunit "LSC Delivery POS Commands";
        Text082: Label 'Esta seguro de que deseas cancelar el pedido?';
        Log: Record "FSN Change Log Transaction";
        pIsConvert: Boolean;
    begin
        if DeliveryOrder.get(OrderNo) then begin
            if not Confirm(Text082, false) then
                exit;

            IF DeliveryOrder.GET(OrderNo) AND (NOT (DeliveryOrder."Call Cent. Web Service Status" IN [DeliveryOrder."Call Cent. Web Service Status"::"New-Not Sent",
                                                                        DeliveryOrder."Call Cent. Web Service Status"::"New-Not Confirmed", DeliveryOrder."Call Cent. Web Service Status"::"New-Sent"])) THEN BEGIN
                IF Log.FIND('+') THEN
                    Log."Entry No." := Log."Entry No." + 1;
                if Log."Entry No." = 0 then begin
                    Log."Entry No." := 1;
                end;
                Log."Receipt No." := DeliveryOrder."Order No.";
                IF STRLEN(DeliveryOrder."Phone No.") > 10 THEN
                    Log."Phone No." := COPYSTR(DeliveryOrder."Phone No.", STRLEN(DeliveryOrder."Phone No.") - 10, 10)
                ELSE
                    Log."Phone No." := DeliveryOrder."Phone No.";
                Log.Date := TODAY;
                Log."Log Time" := TIME;
                Log."User ID" := USERID;
                Log."Staff ID" := POSSESSION.StaffID();
                Log."Type of Change" := Log."Type of Change"::Deletion;
                If Log."Type of Change" = Log."Type of Change"::Deletion then begin
                    Log.Action := 'Cancelar';
                end;
                Log.INSERT();
            END;

            if not DeliveryOrderManagement.CheckChangeAllowed(ChangeMade::Cancel) then
                exit;

            if not DelPosComm.ProcessCancelOrder(DeliveryOrder, true) then
                exit;

            DPCProcessOrderCancel(POSSESSION.GetValue('CURRORDER'));

        end;

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
        if payload = 'FSNPHONE' THEN BEGIN
            ValueNoTelefono(inputValue);
            processed := true;
        END;

        if payload = 'EXTENTCTI' THEN BEGIN
            ValueNoExt(inputValue);
            processed := true;
        END;

        if (POSSESSION.GetValue('ONBUTTONPRESSEDFSN') = 'DELIVERY') and (payload = '{"j":{"FUNCTIONTYPE":"TAKEORDER","ORIGIN":"10001216"},"t":"10000991"}') then begin
            if inputValue = '' then begin
                POSSESSION.SetValue('ONBUTTONPRESSEDFSN', '');
                POSSESSION.SetValue('COUNTERCLICFSN', '');
            end;
        end;
    end;

    procedure ValueNoExt(Ext: Text)
    var
        ExtInt: Integer;
        FSNComutador: Record "FSN Commutator";
        TEXT01: Label 'El numero de Extension no es numerico';
        TEXT02: Label 'El numero de Extension no existe en comutadores.';
        TEXT03: Label 'El numero de extension %1 ya esta en uso por el Staff %2';
    begin
        if Evaluate(ExtInt, Ext) then begin
            FSNComutador.Reset();
            FSNComutador.SetRange(Extension, ExtInt);
            if FSNComutador.FindFirst() then begin
                FSNComutador.StaffID := POSSESSION.StaffID();
                FSNComutador.Date := Today;
                FSNComutador.Modify();
                Commit();
                CTI();
            end else
                Message(TEXT02);
        end else
            Message(TEXT01);
    end;

    procedure ValueNoTelefono(NoTelefonoResult: Text)
    var
        myInt: Integer;
        NoTelInt: Integer;
        TransactionH: Record "LSC Transaction Header";
        UlTransactionNo: Integer;
        Text001: Label 'El numero de telefono %1 no es valido';
        Text005: Label 'Quiere crear un nuevo contacto: %1?';
        Text033: Label 'Cliente para llevar sin nombre';
        DelOrder: Record "LSC Delivery Order";
        DelPosPanelsUtility: Codeunit "LSC Del. POS Panel Utilities";
        DelCont: Record Contact;
        HospSetup: Record "LSC Hospitality Setup";
        PosMenuLineTem: Record "LSC POS Menu Line";
        DelOrderM: Codeunit "LSC Delivery Order Management";
        DelContacAddr: Record "LSC Delivery Contact Address";
        DelStreet: Record "LSC Delivery Street";
        RestaurantNo: Code[10];
    begin
        POSSESSION.SetValue('PHONEORDER', '');
        CLEAR(UlTransactionNo);
        HospSetup.Get();
        IF (NoTelefonoResult <> '') THEN BEGIN
            IF (STRLEN(NoTelefonoResult) < 20) THEN BEGIN
                POSSESSION.SetValue('PHONEORDER', NoTelefonoResult);
                if not DelCont.Get(NoTelefonoResult) then begin
                    if Confirm(StrSubstNo(Text005, NoTelefonoResult), true) then begin
                        DelCont.Init;
                        DelCont.Validate("No.", NoTelefonoResult);
                        DelCont."Phone No." := NoTelefonoResult;
                        DelCont."LSC Next Order Restaurant" := 'F20';
                        DelCont.Type := DelCont.Type::Person;
                        DelCont."LSC Next Order Time" := Time;
                        DelCont."LSC Next Order Date" := today;
                        DelCont."LSC Next Order Selection" := DelCont."LSC Next Order Selection"::"Delivery Home";
                        DelCont.SetSkipDefault;
                        if NoTelefonoResult = HospSetup."Takeout No-Name No." then
                            DelCont.Validate(Name, Text033);
                        DelCont.Insert(true);
                        Commit;
                    end else begin
                        exit;
                    end;
                end else begin
                    DelCont."LSC Next Order Time" := Time;
                    DelCont."LSC Next Order Date" := Today;
                    DelCont.Modify();
                    Commit();
                end;

                DelOrder.Reset;
                DelOrder.SetCurrentKey("Phone No.");
                DelOrder.SetRange("Phone No.", NoTelefonoResult);
                DelOrder.SetFilter(
                  "General Status", '%1|%2',
                  DelOrder."General Status"::"In Process", DelOrder."General Status"::ERROR);
                if DelOrder.Find('-') then begin
                    DelPosPanelsUtility.RunDelOpenOrdersPanel(DelOrder, '#DEL-OPENORDERS')
                end else begin
                    DelContacAddr.Reset();
                    DelContacAddr.SetRange("Phone No.", NoTelefonoResult);
                    DelContacAddr.SetRange("Address Type", DelContacAddr."Address Type"::Home);
                    if DelContacAddr.FindFirst() then begin
                        DelStreet.Reset();
                        DelStreet.SetRange("Street Name", DelContacAddr."Street Name");
                        if DelStreet.FindFirst() then
                            RestaurantNo := DelStreet."Restaurant No."
                        else
                            RestaurantNo := 'F20';
                    end;

                    Clear(DeliveryOrderTemp);
                    DeliveryOrderTemp.Reset();
                    PageDeliveryTakeOrder.AfterClosingOrderTakeNew(NoTelefonoResult, RestaurantNo, DeliveryOrderTemp);
                    PageDeliveryTakeOrder.SetPosmenuLine(GlobalRec);
                    PageDeliveryTakeOrder.SETGLOBALVALUE(DeliveryOrderTemp);
                    PageDeliveryTakeOrder.RUN;
                end;
            END ELSE BEGIN
                POSGUI.PosMessage(STRSUBSTNO(Text001, NoTelefonoResult));
            END;
        END;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Controller", 'OnBeforeClosePOSPanelInLogoffPressed', '', true, true)]
    local procedure "LSC POS Controller_OnBeforeClosePOSPanelInLogoffPressed"
    (
        ActivePanelID: Text;
        StartupControllerCodeunit: Integer;
        var CancelClosing: Boolean
    )
    var
        DelOrder: Record "LSC Delivery Order";
        TmpMenuLine: Record "LSC POS Menu Line" temporary;
        POSMenuLineV: Record "LSC POS Menu Line";
        POSTransaction: Record "LSC POS Transaction";
        POSStartup: Codeunit "LSC Hospitality POS Startup";
        PosCommand: Record "LSC POS Command";
        DelPanelUtility: Codeunit "LSC Del. POS Panel Utilities";
        EPosCtrl: Codeunit "LSC POS Control Interface";
        DeliveryOrder_l: Record "LSC Delivery Order";
        RetailSetup_l: Record "LSC Retail Setup";
        DelInventoryMHt: Codeunit "FSN Delivery Inventory Mgt.";
    begin
        //POSSESSION.GetValue('CURRORDER2');
        //CancelClosing := true;
        RetailSetup_l.Get();
        if RetailSetup_l."FSN Is Local Receipt" then begin
            DelOrder.Reset();
            if DelOrder.Get(CCcontroler.GetReceipt()) then begin
                if POSTransaction.Get(DelOrder."Order No.") then begin
                    DelInventoryMHt.ValidateServerinventoryTransac(POSTransaction, 'SUGGESTSTORE');

                    //CancelClosing := true;

                    //EPosCtrl.ShowPanel(POSSession.OfflinePanelID);

                    /*POSSESSION.SetValue('CURRORDER2', '');
                    POSSESSION.SetValue('CURRORDER', DelOrder."Order No.");

                    TmpMenuLine."Profile ID" := '#FSN-CC';
                    TmpMenuLine."Key No." := 1;
                    TmpMenuLine.Command := 'DELCONFIRM';
                    TmpMenuLine."Current-POSID" := POSTransaction."POS Terminal No.";
                    TmpMenuLine."Current-StaffID" := POSTransaction."Staff ID";
                    TmpMenuLine."Current-SHIFT" := '';
                    TmpMenuLine."Current-RECEIPT" := POSTransaction."Receipt No.";
                    TmpMenuLine."Current-SALESORDER" := '';
                    TmpMenuLine."Current-SALESTYPE" := POSTransaction."Sales Type";
                    IF DeliveryOrderManagement.RUN(TmpMenuLine) THEN;*/

                    //---------------------------------------------------------------------------------------------//

                    /*POSMenuLineV.Reset();
                    POSMenuLineV.SetCurrentKey("Profile ID", "Menu ID", "Key No.");
                    POSMenuLineV.SetRange(POSMenuLineV."Profile ID", '#FSN-CC');
                    POSMenuLineV.SetRange(POSMenuLineV."Menu ID", '#DEL-OPENORDERSMENU');
                    POSMenuLineV.SetRange(POSMenuLineV."Key No.", 1);
                    if POSMenuLineV.FindFirst() then begin
                        Commit();
                        IF DelPanelUtility.RUN(POSMenuLineV) THEN BEGIN
                            DeliveryOrderManagement.ProcessInputOnSelectingOrderOnOrderTaking;
                        END;
                    end;*/

                    //----------------------------------------------------------------------------------------------//

                    /*TmpMenuLine."Profile ID" := '#FSN-CC';
                    TmpMenuLine."Key No." := 1;
                    TmpMenuLine.Command := 'DELCONFIRM';
                    TmpMenuLine."Current-POSID" := POSTransaction."POS Terminal No.";
                    TmpMenuLine."Current-StaffID" := POSTransaction."Staff ID";
                    TmpMenuLine."Current-SHIFT" := '';
                    TmpMenuLine."Current-RECEIPT" := DelOrder."Order No.";
                    TmpMenuLine."Current-SALESORDER" := '';
                    TmpMenuLine."Current-SALESTYPE" := POSTransaction."Sales Type";
                    //MGTOrderClosePanelPressed(POSSESSION.GetValue('CURRORDER'), handled, ErrorValidation);
                    if PosCommand.Get(TmpMenuLine.Command) then
                        CODEUNIT.Run(PosCommand."Run Codeunit", TmpMenuLine);*/
                end;
            end;
        end;
    end;


    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    procedure CTI()
    var
        FSNCallEntry: record "FSN Call Entry";
        FSNCommutator: Record "FSN Commutator";
        ActiveSession: Record "Active Session";
        SqlConnection: DotNet SqlConnection;
        SqlCommand: DotNet SqlCommand;
        SqlDataReader: DotNet SqlDataReader;
        ConnectionString: Text[150];
        SqlString: Text;
        Exists: Boolean;
        STRTODAY_START: Text[20];
        STRTODAY_END: Text[20];
        DisLocation: Record "LSC Distribution Location";
        ForCount: Integer;
        lTextConn: Label 'Data Source=%1;Initial Catalog=%2;Integrated Security=false; User ID=%3;Password=%4;';
        lTextSimbol: Label '''''';
        Result: Text;
        FSNParamenter: Record "FSN Parameter";
        Text01: label 'no existe codigo localizacion en grupo parametro LOCATIONCC';
        Text02: label 'no existe grupo LOCATIONCC para CTI en parametro FSN';
        Text03: label 'grupo LOCATIONCC no activo en parametros FSN';
        Text04: label 'No se encontro resultados de la extension de llamadas.';
        USERID: Text;
        TextExt: Label 'Ingrese Numero de Extension';
    begin
        Result := '';
        FSNParamenter.Reset();
        if FSNParamenter.Get('LOCATIONCC', 'CTI') then begin
            if FSNParamenter.Activo then begin
                IF ActiveSession.GET(SERVICEINSTANCEID, SESSIONID) THEN
                    IF DisLocation.Get(FSNParamenter.Valor) THEN begin
                        FSNCommutator.Reset();
                        FSNCommutator.SetRange(StaffID, POSSESSION.StaffID());
                        FSNCommutator.SetRange(Date, Today);
                        IF FSNCommutator.FindFirst() THEN begin
                            ConnectionString := STRSUBSTNO(lTextConn, DisLocation."Db Server Name", DisLocation."Db. Path && Name", DisLocation."User ID", DisLocation.Password);
                            SqlConnection := SqlConnection.SqlConnection(ConnectionString);

                            SqlString := 'SELECT top (1) [Phone No_] ' +
                            'FROM  [DBTIENDA].[fsn].[FASANI$FSN Call Entry]  ' +
                            'where Extension = ''' + Format(FSNCommutator.Extension) + '''' +
                            ' and Date = ''' + Format(Today) + ''' ORDER BY [Start Time] desc';

                            SqlConnection.Open();
                            SqlCommand := SqlConnection.CreateCommand();
                            SqlCommand.CommandText := SqlString;
                            SqlDataReader := SqlCommand.ExecuteReader();
                            Exists := FALSE;
                            IF SqlDataReader.Read() THEN
                                Exists := TRUE;

                            if Exists then begin
                                IF CopyStr(SqlDataReader.GetString(0), 1, 4) IN ['+503', '+502'] THEN
                                    Result := CopyStr(SqlDataReader.GetString(0), 5, 12)
                                ELSE
                                    Result := SqlDataReader.GetString(0);
                                //Message(format(ActiveSession."User ID"));
                                DeliveryOrderManagement.TakeOrder(Result);
                            end else
                                Message(Text04);

                            SqlDataReader.Close();
                            SqlConnection.Close();

                        end else
                            POSGUI.OpenNumericKeyboard(TextExt, 0, '', 0, 'EXTENTCTI');

                    end else
                        Message(Text01);
            end else
                Message(Text03);
        end else
            Message(Text02);
    end;

    procedure DelCheckPhone()
    var
        OrderN: Code[20];
        EPosCtrl: codeunit "LSC POS Control Interface";
    begin
        OrderN := EPosCtrl.GetDataGridKeyValue(EPosCtrl.ActiveDataGrid);
        if DeliveryOrderBK.Get(OrderN) then
            DeliveryOrderManagement.TakeOrder(DeliveryOrderBK."Phone No.")
        else
            DeliveryOrderManagement.TakeOrder('');
    end;

    procedure ChangeStore(OrderNo: Code[20]; NewStore: Code[10]; pTypeChange: Integer)
    var
        DeliveryOrder_l: Record "LSC Delivery Order";
        DeliveryOrderTmp: Record "LSC Delivery Order" temporary;
        POSTransaction_l: Record "LSC POS Transaction";
        POSTransactioTmp: Record "LSC POS Transaction" temporary;
        POSLine_l: Record "LSC POS Trans. Line";
        POSLine2_l: Record "LSC POS Trans. Line";
        POSLineTmp: Record "LSC POS Trans. Line" temporary;
        POSTransInfocode_l: Record "LSC POS Trans. Infocode Entry";
        POSTransInfocodeTmp: Record "LSC POS Trans. Infocode Entry" temporary;
        TransPerDisc: Record "LSC POS Trans. Per. Disc. Type";
        TransPerDiscTmp: Record "LSC POS Trans. Per. Disc. Type" temporary;
        CCPOSTerm_l: Record "LSC CC POS Term. Assignm.";
        RetailSetup_l: Record "LSC Retail Setup";
        StaffSession: Code[20];
        Windows: Dialog;
        WindowsText: Text[100];
        VoucherEntries_l: Record "LSC Voucher Entries";
        VoucherEntriesTmp: Record "LSC Voucher Entries" temporary;
        CSWebServiceTable_l: Record "FSN WebServiceTable";
        CSWebServiceTableTmp: Record "FSN WebServiceTable" temporary;
        POSCardEntry_l: Record "LSC POS Card Entry";
        POSCardEntryTmp: Record "LSC POS Card Entry" temporary;
        CCWSType: Option "None",Ecommerce,FromStore;
        lText001: Label '%1';
        lText002: Label 'Changing to store %1 ...';
        PosCardReqIn: Record "FSN POS Card Request Inherit";
        POSCardReq_1: Record "FSN POS Card Request Entry";
        PosCardEntry2: Record "LSC POS Card Entry";
        DelOrderV: Record "LSC Delivery Order";
        PosTransV: Record "LSC POS Transaction";
    begin
        //pTypeChange = 0 (On logoff POS)
        COMMIT;
        if DelOrderV.Get(OrderNo) then
            if PosTransV.Get(OrderNo) then
                POSInsertReplenSalesHist(DelOrderV, PosTransV);
        StaffSession := '';
        StaffSession := POSSESSION.StaffID();

        WindowsText := STRSUBSTNO(lText002, NewStore);
        Windows.OPEN(WindowsText);
        Windows.UPDATE;

        CLEAR(DeliveryOrderTmp);
        CLEAR(POSTransactioTmp);
        CLEAR(TransPerDiscTmp);
        CLEAR(POSTransInfocodeTmp);
        CLEAR(POSLineTmp);
        CLEAR(VoucherEntriesTmp);
        CLEAR(CSWebServiceTableTmp);
        CLEAR(POSCardEntryTmp);
        DeliveryOrderTmp.DELETEALL;
        POSTransactioTmp.DELETEALL;
        TransPerDiscTmp.DELETEALL;
        POSTransInfocodeTmp.DELETEALL;
        POSLineTmp.DELETEALL;
        VoucherEntriesTmp.DELETEALL;
        CSWebServiceTableTmp.DELETEALL;
        POSCardEntryTmp.DELETEALL;

        CCWSType := CCWSType::None;

        RetailSetup_l.GET;
        CCPOSTerm_l.GET(RetailSetup_l."Local Store No.", NewStore);

        IF DeliveryOrder_l.GET(OrderNo) THEN BEGIN
            DeliveryOrderTmp := DeliveryOrder_l;
            DeliveryOrderTmp."Restaurant No." := NewStore;
            DeliveryOrderTmp."Order Taker" := DeliveryOrder_l."Order Taker";
            DeliveryOrderTmp.INSERT;

            DeliveryOrder_l.DELETE;
            DeliveryOrder_l := DeliveryOrderTmp;
            DeliveryOrder_l.INSERT;
        END;

        IF CSWebServiceTable_l.GET(OrderNo) THEN BEGIN

            CCWSType := CCWSType::Ecommerce;
            IF NOT (CSWebServiceTable_l.Store IN ['EC', 'APP']) THEN
                if not (CSWebServiceTable_l."WS Request" = '') then
                    CCWSType := CCWSType::FromStore;

            CSWebServiceTableTmp := CSWebServiceTable_l;
            CSWebServiceTableTmp."Status WS" := CSWebServiceTableTmp."Status WS"::InProcess;
            CSWebServiceTableTmp.INSERT;

            CSWebServiceTable_l.DELETE;
            CSWebServiceTable_l := CSWebServiceTableTmp;
            CSWebServiceTable_l.INSERT;
        END;

        IF CSWebServiceTable_l."Distribution Location" <> '' then
            StaffSession := ('BOT');


        POSTransaction_l.GET(OrderNo);
        POSTransactioTmp := POSTransaction_l;
        POSTransactioTmp."Store No." := NewStore;
        POSTransactioTmp."POS Terminal No." := CCPOSTerm_l."Rest. POS Terminal";
        POSTransactioTmp."Created on POS Terminal" := CCPOSTerm_l."Rest. POS Terminal";
        POSTransactioTmp."Entry Status" := POSTransaction_l."Entry Status";
        IF DeliveryOrder_l."Phone No." <> '' THEN
            POSTransactioTmp."Sell-to Contact No." := DeliveryOrder_l."Phone No.";
        if POSTransaction_l."Sales Staff" IN ['F20', ''] then
            POSTransactioTmp."Sales Staff" := StaffSession
        else
            POSTransactioTmp."Sales Staff" := POSTransaction_l."Sales Staff";
        IF POSTransaction_l."Staff ID" <> '' then
            POSTransactioTmp."Staff ID" := POSTransaction_l."Staff ID"
        ELSE
            POSTransactioTmp."Staff ID" := StaffSession;
        IF POSTransaction_l."Entry Status" = POSTransaction_l."Entry Status"::Suspended THEN
            POSTransactioTmp."Entry Status" := POSTransactioTmp."Entry Status"::" ";
        IF pTypeChange <> 0 THEN BEGIN
            POSTransactioTmp."Trans. Date" := TODAY;
            POSTransactioTmp."Original Date" := TODAY;
            POSTransactioTmp."Trans Time" := TIME;
        END ELSE BEGIN
            IF POSTransactioTmp."Trans. Date" = 0D THEN
                POSTransactioTmp."Trans. Date" := TODAY;
            IF POSTransactioTmp."Original Date" = 0D THEN
                POSTransactioTmp."Original Date" := TODAY;
            IF POSTransactioTmp."Trans Time" = 0T THEN
                POSTransactioTmp."Trans Time" := TIME;
        END;

        POSTransactioTmp.INSERT;
        //POSTransaction_l.DELETE;
        POSTransaction_l := POSTransactioTmp;
        POSTransaction_l.Modify();
        Commit();
        //POSTransaction_l.INSERT;

        TransPerDisc.RESET;
        TransPerDisc.SETRANGE(TransPerDisc."Receipt No.", OrderNo);
        IF TransPerDisc.FIND('-') THEN
            REPEAT
                TransPerDiscTmp := TransPerDisc;
                TransPerDiscTmp."POS Terminal No." := CCPOSTerm_l."Rest. POS Terminal";
                TransPerDiscTmp.INSERT;
            UNTIL TransPerDisc.NEXT = 0;

        TransPerDisc.DELETEALL;
        TransPerDiscTmp.RESET;
        IF TransPerDiscTmp.FIND('-') THEN
            REPEAT
                TransPerDisc := TransPerDiscTmp;
                TransPerDisc.INSERT;
            UNTIL TransPerDiscTmp.NEXT = 0;

        POSTransInfocode_l.RESET;
        POSTransInfocode_l.SETRANGE(POSTransInfocode_l."Receipt No.", OrderNo);
        IF POSTransInfocode_l.FIND('-') THEN
            REPEAT
                POSTransInfocodeTmp := POSTransInfocode_l;
                POSTransInfocodeTmp."Store No." := NewStore;
                POSTransInfocodeTmp."POS Terminal No." := CCPOSTerm_l."Rest. POS Terminal";
                POSTransInfocodeTmp.INSERT;
            UNTIL POSTransInfocode_l.NEXT = 0;

        POSTransInfocode_l.DELETEALL;
        POSTransInfocodeTmp.RESET;
        IF POSTransInfocodeTmp.FIND('-') THEN
            REPEAT
                POSTransInfocode_l := POSTransInfocodeTmp;
                POSTransInfocode_l.INSERT;
            UNTIL POSTransInfocodeTmp.NEXT = 0;

        POSLine_l.RESET;
        POSLine_l.SETRANGE(POSLine_l."Receipt No.", OrderNo);
        IF POSLine_l.FIND('-') THEN
            REPEAT
                POSLineTmp := POSLine_l;
                POSLineTmp."Store No." := NewStore;
                POSLineTmp."POS Terminal No." := CCPOSTerm_l."Rest. POS Terminal";
                IF pTypeChange <> 0 THEN BEGIN
                    POSLineTmp."Trans. Date" := TODAY;
                    POSLineTmp."Trans. Time" := TIME;
                END;
                IF (POSLineTmp."Sales Staff" = '') AND (POSLineTmp."Entry Type" = POSLineTmp."Entry Type"::Item) THEN
                    POSLineTmp."Sales Staff" := POSLine_l."Sales Staff";
                IF CSWebServiceTable_l."Distribution Location" <> '' THEN
                    POSLineTmp."Sales Staff" := 'BOT' else
                    IF CCWSType = CCWSType::FromStore THEN
                        POSLineTmp."Sales Staff" := 'F20';//Static

                IF (POSLine_l."Entry Type" = POSLine_l."Entry Type"::Payment) AND (POSLine_l."Entry Status" = 0) THEN
                    POSLineTmp."FSN Additional Action" := POSLineTmp."FSN Additional Action"::ConfirmPayment;

                POSLineTmp.INSERT;
            UNTIL POSLine_l.NEXT = 0;

        POSLine_l.DELETEALL;
        POSLineTmp.RESET;
        IF POSLineTmp.FIND('-') THEN
            REPEAT
                POSLine_l := POSLineTmp;
                POSLine_l.INSERT;
            UNTIL POSLineTmp.NEXT = 0;

        VoucherEntries_l.RESET;
        VoucherEntries_l.SETRANGE(VoucherEntries_l."Receipt Number", OrderNo);
        IF VoucherEntries_l.FIND('-') THEN
            REPEAT
                VoucherEntriesTmp := VoucherEntries_l;
                VoucherEntriesTmp."Store No." := NewStore;
                VoucherEntriesTmp."POS Terminal No." := CCPOSTerm_l."Rest. POS Terminal";
                VoucherEntriesTmp.INSERT;
            UNTIL VoucherEntries_l.NEXT = 0;

        VoucherEntries_l.DELETEALL;
        VoucherEntriesTmp.RESET;
        IF VoucherEntriesTmp.FIND('-') THEN
            REPEAT
                VoucherEntries_l := VoucherEntriesTmp;
                VoucherEntries_l.INSERT;
            UNTIL VoucherEntriesTmp.NEXT = 0;

        POSCardEntry_l.RESET;
        POSCardEntry_l.SETRANGE(POSCardEntry_l."Receipt No.", OrderNo);
        IF POSCardEntry_l.FIND('-') THEN
            REPEAT
                POSCardEntryTmp := POSCardEntry_l;
                POSCardEntryTmp."Store No." := NewStore;
                POSCardEntryTmp."POS Terminal No." := CCPOSTerm_l."Rest. POS Terminal";
                POSCardEntryTmp."Entry No." := NextEntryNo(NewStore, CCPOSTerm_l."Rest. POS Terminal");
                IF NOT (POSCardEntryTmp.INSERT) THEN begin
                    POSCardEntryTmp.MODIFY;
                end else begin
                    PosCardEntry2 := POSCardEntryTmp;
                    PosCardEntry2.Insert();
                    POSCardEntry_l.Delete();
                    POSCardEntryTmp.Delete();
                end;
            UNTIL POSCardEntry_l.NEXT = 0;

        POSCardReq_1.Reset();
        POSCardReq_1.SetRange(POSCardReq_1."Receipt No.", OrderNo);
        if POSCardReq_1.Find('-') then begin
            repeat
                POSCardReq_1."Store No." := NewStore;
                POSCardReq_1.Modify();
                Commit();
            until POSCardReq_1.Next() = 0;
        end;

        PosCardReqIn.Reset();
        PosCardReqIn.SetRange(PosCardReqIn."Receipt No. Inherit", OrderNo);
        if PosCardReqIn.Find('-') then begin
            repeat
                PosCardReqIn."Store No. Inherit" := NewStore;
                PosCardReqIn.Modify();
                Commit();
            until PosCardReqIn.Next() = 0;
        end;

        Windows.CLOSE;

        POSSESSION.SetTempStoreTerminal(POSTransaction_l."Store No.", POSTransaction_l."POS Terminal No.", POSTransaction_l."Sales Type");

        COMMIT;
    end;

    procedure NextEntryNo(pStore: Code[10]; pTerm: Code[10]): Integer
    var
        CardEntry: Record "LSC POS Card Entry";
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line";
        Processed: Boolean;
        MsgResult: Text;
        FSNUtility: Codeunit "FSN Utility";
    begin
        //evaluar si es call y entry sea menor a 0 find firt menos 1
        RequestID := 'FSNCC';
        Processed := false;
        FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
        CardEntry.Reset();
        CardEntry.SetRange(CardEntry."Store No.", pStore);
        CardEntry.SetRange(CardEntry."POS Terminal No.", pTerm);
        IF not Processed THEN begin
            if CardEntry.FindLast() then begin
                exit(CardEntry."Entry No." + 1)
            end else begin
                exit(1);
            end;
        end else begin
            if CardEntry.FindFirst() then begin
                exit(CardEntry."Entry No." - 1)
            end else
                exit(-1);
        end;
    end;

    procedure ChangeStoreUpdDiscounts(pPOSTransaction: Record "LSC POS Transaction")
    var
        POSTransPerDisc: Record "LSC POS Trans. Per. Disc. Type";
        DT: Record "LSC POS Trans. Per. Disc. Type";
        POSTransLine2: Record "LSC POS Trans. Line";
        PosPriceUtil: Codeunit "LSC POS Price Utility";
        PosFuncProfile: Record "LSC POS Func. Profile";
        POSPrepaymentUtil: Codeunit "LSC POS Prepayment Mgt.";
        PosMixMatchEntry: Record "LSC POS Mix & Match Entry";
        OfferPosCalc: Record "LSC Offer Pos Calculation";
        Customer_l: Record Customer;
        PromOnCustDiscGroup: Boolean;
        lPrice: Decimal;
        lQty: Decimal;
    begin
        if not Customer_l.Get(pPOSTransaction."Customer No.") then
            Clear(Customer_l);

        POSTransPerDisc.Reset;
        POSTransPerDisc.SetCurrentKey(DiscType);
        POSTransPerDisc.SetRange(DiscType, POSTransPerDisc.DiscType::Customer);
        POSTransPerDisc.SetRange("Receipt No.", pPOSTransaction."Receipt No.");
        POSFunction.PosTransDiscSetTableFilter(1, POSTransPerDisc);
        if POSFunction.PosTransDiscFindRec(1, '-', POSTransPerDisc) then begin
            repeat
                POSTransLine2.Get(POSTransPerDisc."Receipt No.", POSTransPerDisc."Line No.");
                PosPriceUtil.InsertTransDiscPercent(POSTransLine2, 0, POSTransPerDisc.DiscType::Customer.AsInteger(), '');
                POSTransLine2.CalcPrices;
                if not PosFuncProfile."Disable POS Prepayment" then
                    POSPrepaymentUtil.SetPosTransLinePrepaymentPct(POSTransLine2);
                POSTransLine2.Modify(true);
            until POSFunction.PosTransDiscNextRec(1, 1, POSTransPerDisc) = 0;
        end;

        POSFunction.ChangeGenBusPostingGroup(pPOSTransaction);
        if POSSESSION.UseSalesTax and LocalizationExt.IsNALocalizationEnabled then begin
            if (pPOSTransaction."Customer No." <> '') and (pPOSTransaction."Tax Liable" <> Customer_l."Tax Liable") then
                pPOSTransaction."Tax Liable" := Customer_l."Tax Liable"
            else
                pPOSTransaction."Tax Liable" := true;
            pPOSTransaction.Modify;
            POSFunction.ChangeTAXOnLine(pPOSTransaction);
        end else
            POSFunction.ChangeVATBusOnLine(pPOSTransaction);

        //if pPOSTransaction."Customer Disc. Group" <> xCustomerDiscGroup then begin
        PromOnCustDiscGroup := PosPriceUtil.IsPromotionForCustDiscGroup(pPOSTransaction."Customer Disc. Group", pPOSTransaction);
        POSTransLine2.Reset;
        POSTransLine2.SetRange("Receipt No.", pPOSTransaction."Receipt No.");
        POSTransLine2.SetRange("Entry Type", POSTransLine2."Entry Type"::Item);
        if POSTransLine2.FindSet then
            repeat
                Clear(OfferPosCalc);
                OfferPosCalc.SetRange("Receipt No.", POSTransLine2."Receipt No.");
                OfferPosCalc.SetRange("Trans. Line No.", POSTransLine2."Line No.");
                OfferPosCalc.DeleteAll;
                if LocalizationExt.IsNALocalizationEnabled then begin
                    PosMixMatchEntry.SetRange("Receipt No.", POSTransLine2."Receipt No.");
                    PosMixMatchEntry.SetRange("Line No.", POSTransLine2."Line No.");
                    PosMixMatchEntry.DeleteAll;
                end;
                PosPriceUtil.InsertTransDiscPercent(POSTransLine2, 0, POSTransPerDisc.DiscType::"Periodic Disc.".AsInteger(), '');
                if PromOnCustDiscGroup then begin
                    lPrice := POSTransLine2.Price;
                    lQty := POSTransLine2.Quantity;
                    PosPriceUtil.InsertTransDiscPercent(POSTransLine2, 0, DT.DiscType::"Periodic Disc.".AsInteger(), '');
                    POSTransLine2."Promotion No." := '';
                    POSTransLine2."Mix & Match Line No." := 0;
                    PosPriceUtil.InsertTransDiscAmount(POSTransLine2, 0, DT.DiscType::"Periodic Disc.".AsInteger(), '');
                    if not POSTransLine2."Price Change" then
                        PosPriceUtil.CalcPrice(POSTransLine2, false);
                    if (lPrice <> POSTransLine2.Price) then begin
                        POSTransLine2.Validate(Quantity, lQty);
                        POSTransLine2.Modify(true);
                    end;
                end;
                POSFunction.ClearPosTransLineOffers(POSTransLine2);
                PosPriceUtil.InitGlobals(POSTransLine2, true);
                PosPriceUtil.FindPeriodicOffers(POSTransLine2);
                POSFunction.AddPosTransLineOffers(POSTransLine2);
                POSTransLine2.Modify(true);
            until POSTransLine2.Next = 0;
        PosPriceUtil.CalcPeriodicOnTotalPressed(pPOSTransaction);
        //end;// Ever calculate discount

        POSFunction.RecalcSlip(pPOSTransaction);
    end;

    procedure CopyFunction(ReceiptNo: Code[20])
    var
        html: Text;
        Barcodes_l: Record "LSC Barcodes";
        POSTransaction_l: Record "LSC POS Transaction";
        POSTransLineBK: Record "LSC POS Trans. Line";
        LinePayment: Record "LSC POS Trans. Line";
        TenderDescription: Text[100];
        Done_: Boolean;
        lText000: Label 'With pleasure I give you the detail of your quote:';
        lText001: Label '%1 %2 $%3 with discount %4 $%5';
        lText002: Label 'The total price to be canceled, with discounts applied, would be: $ %1';
        lText003: Label 'We have completely FREE home service';
        lText004: Label ' or we can have it ready at the branch of your choice. ';
        lText005: Label 'In which direction would you like us to deliver it?';
        lText006: Label '***Product %1 participates in exchange program %2';
        lText007: Label 'Combined';
        lText008: Label 'Tender type not found.';
        HTMLTextCopy: page TextCopy;
    begin
        html := '';
        html := '<table><tr><td>' + lText000 + '</td></tr>';

        LinePayment.Reset();
        LinePayment.SetCurrentKey("Receipt No.", "Entry Type", "Entry Status");
        LinePayment.SetRange("Receipt No.", ReceiptNo);
        LinePayment.SetRange("Entry Status", LinePayment."Entry Status"::" ");
        /*LinePayment.SetRange("Entry Type", LinePayment."Entry Type"::Payment);*/
        case LinePayment.Count() of
            0:
                begin
                    Message(lText008);
                    exit;
                end;
            1:
                begin
                    LinePayment.FindFirst();
                end;
            else begin
                LinePayment.FindFirst();
                LinePayment.Description := lText008;
            end;
        end;

        IF POSTransaction_l.GET(ReceiptNo) THEN BEGIN
            POSTransLineBK.RESET;
            POSTransLineBK.SetCurrentKey("Receipt No.", "Entry Type", "Entry Status");
            POSTransLineBK.SetRange(POSTransLineBK."Receipt No.", POSTransaction_l."Receipt No.");
            POSTransLineBK.SetRange("Entry Type", POSTransLineBK."Entry Type"::Item);
            POSTransLineBK.SetRange("Entry Status", POSTransLineBK."Entry Status"::" ");
            IF POSTransLineBK.FIND('-') THEN
                REPEAT
                    Barcodes_l.RESET;
                    Barcodes_l.SETCURRENTKEY("Item No.", "Variant Code", "Unit of Measure Code");
                    Barcodes_l.SETRANGE(Barcodes_l."Item No.", POSTransLineBK.Number);
                    Barcodes_l.SETRANGE(Barcodes_l."Unit of Measure Code", POSTransLineBK."Unit of Measure");
                    IF not Barcodes_l.FINDFIRST then begin
                        Barcodes_l.Init();
                        Barcodes_l.Description := POSTransLineBK.Description;
                    end;


                    html += '<tr><td>' + STRSUBSTNO(lText001, FORMAT(POSTransLineBK.Quantity), Barcodes_l.Description
                                , FORMAT(ROUND(POSTransLineBK.Price, 0.01, '='), 0, '<Precision,2:2><Standard Format,0>'), POSTransaction_l."Customer Disc. Group"
                                , FORMAT(ROUND((POSTransLineBK.Amount) / DivisorZero(POSTransLineBK.Quantity), 0.01, '='), 0, '<Precision,2:2><Standard Format,0>'))
                                + '</td></tr>';
                UNTIL POSTransLineBK.NEXT = 0;

            POSTransaction_l.CalcFields(POSTransaction_l."Gross Amount");


            html += '<tr><td>' + STRSUBSTNO(lText002, Format(POSTransaction_l."Gross Amount")) + '</td></tr>';
            html += '<tr><td>' + lText003 + '</td></tr>';
            html += '<tr><td>' + lText004 + '</td></tr>';
            html += '<tr><td>' + lText005 + '</td></tr>';
            html += '</table>';
            commit;
            HTMLTextCopy.CopyTxt(html);
            HTMLTextCopy.Run();
        END;
    end;

    procedure DivisorZero(pValue: Decimal): Decimal
    begin
        IF pValue = 0 THEN
            EXIT(1)
        ELSE
            EXIT(pValue);
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


    procedure DeleteDeliveryComplete(pOrder: Code[20])
    var
        POSTransaction_l: Record "LSC POS Transaction";
        DeliveryOrder_l: Record "LSC Delivery Order";
        VoucherEntries_l: Record "LSC Voucher Entries";
        POSDataEntries_l: Record "LSC POS Data Entry";
    begin
        IF DeliveryOrder_l.GET(pOrder) THEN
            DeliveryOrder_l.DELETE(TRUE);

        IF POSTransaction_l.GET(pOrder) THEN
            POSTransaction_l.DELETE(TRUE);

        VoucherEntries_l.RESET;
        VoucherEntries_l.SETRANGE(VoucherEntries_l."Receipt Number", pOrder);
        VoucherEntries_l.DELETEALL;

        POSDataEntries_l.RESET;
        POSDataEntries_l.SETRANGE(POSDataEntries_l."Created by Receipt No.", pOrder);
        POSDataEntries_l.DELETEALL;
    end;
    /*
        procedure CharPad(Str: Text[30]; Len: Integer; CharSet: Text[1]): Text[30]
        var
            WrkString: Text[250];
        begin
            WrkString := Str + PADSTR(CharSet, Len, CharSet);
            Str := COPYSTR(WrkString, 1, Len);
            EXIT(Str);
        end;
    */
    procedure SearchCardLoyalty(pCustomerNo: Code[20]; var pMemberShipCardTmp: Record "LSC Membership Card" temporary; pFirstOnly: Boolean; var pExists: Boolean)
    var
        MemberShipCard_l: Record "LSC Membership Card";
        MemberAccount_l: Record "LSC Member Account";
        Customer_l: Record "Customer";
        ExitOnly: Boolean;
    begin
        pMemberShipCardTmp.RESET;
        pMemberShipCardTmp.DELETEALL;
        IF Customer_l.GET(pCustomerNo) THEN BEGIN
            MemberAccount_l.RESET;
            MemberAccount_l.SETCURRENTKEY("No.");
            MemberAccount_l.SETRANGE(MemberAccount_l."Linked To Customer No.", Customer_l."No.");
            IF MemberAccount_l.FIND('-') THEN
                REPEAT
                    MemberShipCard_l.RESET;
                    MemberShipCard_l.SETCURRENTKEY("Account No.", "Contact No.", Status);
                    MemberShipCard_l.SETRANGE(MemberShipCard_l."Account No.", MemberAccount_l."No.");
                    MemberShipCard_l.SETRANGE(MemberShipCard_l.Status, MemberShipCard_l.Status::Active);
                    MemberShipCard_l.SETFILTER(MemberShipCard_l."Last Valid Date", '>=%1', TODAY);
                    IF MemberShipCard_l.FIND('-') THEN
                        REPEAT
                            pMemberShipCardTmp.INIT();
                            pMemberShipCardTmp := MemberShipCard_l;
                            ExitOnly := pMemberShipCardTmp.INSERT;
                            IF NOT pExists AND ExitOnly THEN
                                pExists := TRUE;
                        UNTIL (MemberShipCard_l.NEXT = 0) OR (ExitOnly AND pFirstOnly);
                UNTIL (MemberAccount_l.NEXT = 0) OR (ExitOnly AND pFirstOnly);
        END;
    end;

    procedure GetFirstCardSuggest(CustomerNo: Code[20]; var FirstMemberShipCard: Text[100])
    var
        MembershipCardTmp: Record "LSC Membership Card" temporary;
        Exists_: Boolean;
    begin
        FirstMemberShipCard := '';

        SearchCardLoyalty(CustomerNo, MembershipCardTmp, TRUE, Exists_);
        IF Exists_ THEN
            IF MembershipCardTmp.FIND('-') THEN
                FirstMemberShipCard := MembershipCardTmp."Card No.";
    end;

    procedure GetEcommerceInfo(pParameters: Record "LSC POS Menu Line")
    var
        //PageInfoAdd: Page "60011";

        POSGUI: Codeunit "LSC POS GUI";
        Record_: Code[30];
    begin
        Record_ := POSGUI.GetActiveLookupKeyValue();
        IF Record_ = '' THEN
            EXIT;
        /*
    PageInfoAdd.SetCurrentReceipt(Record_);
    PageInfoAdd.RUN;
    */
    end;


    procedure SetTransaction()
    var
        POSTransactionTable: Record "LSC POS Transaction";
        POSView: Codeunit "LSC POS View";
    begin
        IF POSView.GetReceiptNo() = '' THEN BEGIN
            POSTransactionTable.RESET;
            IF POSTransactionTable.FIND('-') THEN
                POSTransaction.SetPOSTransaction(POSTransactionTable); //Init first transaction in Login
        END;
    end;

    procedure SetDocumentType(pParameter: Code[30]; pReceipt: Code[20])
    var
        pExternalOrder: Record "LSC POS Transaction";
        POSTrans: Record "LSC POS Transaction";
        Terminal: Record "LSC POS Terminal";
        FASANIServerUtil: Codeunit "FSN Utility";
        TextError_: Text[150];
        DocumentType: Enum "FSN Transaction Document Type";
    begin

        POSTrans.GET(pReceipt);
        POSTrans.CALCFIELDS(POSTrans."Gross Amount", POSTrans."Income/Exp. Amount");

        Terminal.GET(POSTrans."POS Terminal No.");
        CASE pParameter OF
            'C':
                begin
                    POSTrans."FSN No. Serie NCF" := TerminaL."FSN No. Serie Credito Fiscal";
                    POSSession.SetValue('DocTrans', FORMAT(DocumentType::"Credito Fiscal"));
                    POSTrans."FSN Document Type" := POSTrans."FSN Document Type"::"Credito Fiscal";
                    POSTrans.Modify();
                    Commit();
                end;
            'F':
                begin
                    POSTrans."FSN No. Serie NCF" := Terminal."FSN No. Serie NCF Cons. Final";
                    POSSession.SetValue('DocTrans', FORMAT(DocumentType::Factura));
                    POSTrans."FSN Document Type" := POSTrans."FSN Document Type"::Factura;
                    POSTrans.Modify();
                    Commit();
                end;
            'T':
                BEGIN
                    POSTrans."FSN No. Serie NCF" := Terminal."FSN No. Serie NCF Ticket";
                    POSSession.SetValue('DocTrans', FORMAT(DocumentType::Ticket));
                    POSTrans."FSN Document Type" := POSTrans."FSN Document Type"::Ticket;
                    POSTrans.Modify();
                    Commit();
                END;
        END;

        POSTrans.CalcFields("Gross Amount");
        if POSTrans."Gross Amount" <> 0 then begin
            IF NOT FASANIServerUtil.ValidateTypeDocumentAndCustom(POSTrans,
                (POSTrans."Gross Amount" + POSTrans."Income/Exp. Amount"), TextError_, TRUE) THEN BEGIN

                POSGUI.PosMessage(TextError_);
                EXIT;
            END;
        end;

        CASE pParameter OF
            'T':
                BEGIN
                    POSNewLineFreeText(pReceipt, 32, '', 2);
                    POSNewLineFreeText(pReceipt, 33, '', 2);
                END;
            'F':
                BEGIN
                    POSNewLineFreeText(pReceipt, 32, STRSUBSTNO(Text032, FORMAT(DocumentType::Factura)), 2);
                    POSNewLineFreeText(pReceipt, 33, '', 2);
                END;
            'C':
                BEGIN
                    POSNewLineFreeText(pReceipt, 32, '', 2);
                    POSNewLineFreeText(pReceipt, 33, STRSUBSTNO(Text032, FORMAT(DocumentType::"Credito Fiscal")), 2);
                END;
        END;
    end;

    procedure MGTLoadConextSpecialOrder(pDelOrder: Record "LSC Delivery Order"): Text[30]
    var
        pLines: Record "LSC POS Trans. Line";
    begin
        SuperOrderID := 0;
        IF pDelOrder."Order No." <> '' THEN BEGIN
            pLines.RESET;
            pLines.SETCURRENTKEY("Receipt No.", "Entry Type", "Entry Status");
            pLines.SETRANGE(pLines."Receipt No.", pDelOrder."Order No.");
            pLines.SETRANGE(pLines."Entry Type", pLines."Entry Type"::Item);
            pLines.SETRANGE(pLines."Entry Status", pLines."Entry Status"::" ");
            pLines.SETRANGE(pLines.Number, 'A104394'); //Item config.
            IF pLines.FINDFIRST THEN BEGIN
                SuperOrderID := -100;
                EXIT('EXPRESS');
            END;
        END;
        EXIT('');
    end;

    procedure MGTCheckChangeAllowed(ChangeMadeIn: Option "Order Lines","Order Type",Address,Cancel,"Order Time",Restaurant,Restaddr; pDelOrder: Record "LSC Delivery Order"; pContactTMP: Record "Contact" temporary; var Message: Text[250]; var pBoolInExit: Boolean): Boolean
    var
        DelStreet: Record "LSC Delivery Street";
        StaffGroup: Record "LSC Staff";
        pStaffID: Code[20];
        pPassword: Text[20];
        pWorkShift: Code[1];
        pInt: Integer;
        UserPersonalization2: Record "User Personalization";
        lText001: Label '%1 \Continue?';
        POStrans: Record "LSC POS Transaction";
        lText002: Label 'User %1 is not RETAIL MANAGER';
        lText003: Label 'Inventory is complete';
        pReasonText: Text[80];
        POSControler: Codeunit "LSC POS Controller";
        PosView: codeunit "LSC POS View";
    begin
        COMMIT;
        pBoolInExit := FALSE;

        IF ChangeMadeIn = ChangeMadeIn::Restaurant THEN
            IF pDelOrder."Call Cent. Web Service Status" IN [pDelOrder."Call Cent. Web Service Status"::"Not Used",
                                                            pDelOrder."Call Cent. Web Service Status"::"New-Not Confirmed",
                                                            pDelOrder."Call Cent. Web Service Status"::"New-Not Sent"] THEN BEGIN

                IF POStrans.GET(pDelOrder."Order No.") THEN BEGIN
                    DelStreet.RESET;
                    DelStreet.SETRANGE(DelStreet."FSN Alter Key", pDelOrder."FSN Alter Key");
                    IF DelStreet.FINDFIRST THEN
                        IF DelStreet."FSN Distance Order Type" = DelStreet."FSN Distance Order Type"::"Distance Driver" THEN BEGIN
                            FSNDeliveryInvMgt.ValidateServerinventoryTransac(POStrans, 'CHECKCHANGE');
                            IF POSSESSION.GetValue('#LINEC') <> '0' THEN BEGIN
                                IF POSGUI.PosConfirm(STRSUBSTNO(lText001, lText003), FALSE) THEN BEGIN
                                    ePosControlInterface.ShowPanelModal('#FSNLOGIN', 'LINECLOGIN');
                                END ELSE BEGIN
                                    //POSGUI.PosMessage(lText003);
                                    EXIT(FALSE);
                                END;
                            END;
                        END;
                END;

                pBoolInExit := TRUE;
                EXIT(FALSE);
            END ELSE BEGIN
                //None
            END;

        EXIT(TRUE);
    end;

    procedure MGTOrderClosePanelPressed(OrderCode: Code[20]; var p_Handled: Boolean; var ErrorValidation: Text)
    var
        TextError: Text[250];
        DelOrderTmp: Record "LSC Delivery Order" temporary;
        DelContactTmp: Record Contact temporary;
        DelStreet_l: Record "LSC Delivery Street";
        EPosContext: Codeunit "LSC POS Context";
        FSNSalesChannel: Record "FSN Sales Channel";
        ZommDelOrder: RecordRef;
        ContextValue: Text;
        lText001: Label '%1 \Continue?';
        lText002: Label 'Must be set sales chanel';
    begin
        if p_Handled then
            exit;

        if not DeliveryOrderBK.Get(OrderCode) then begin
            p_Handled := true;
            ErrorValidation := STRSUBSTNO(Text029, DeliveryOrderBK."Restaurant No.", POSTransactionBK."Store No.");
        end;

        if not p_Handled then
            IF POSTransactionBK.GET(OrderCode) THEN
                IF DeliveryOrderBK."Restaurant No." <> POSTransactionBK."Store No." THEN BEGIN
                    p_Handled := true;
                    ErrorValidation := STRSUBSTNO(Text029, DeliveryOrderBK."Restaurant No.", POSTransactionBK."Store No.");
                END;

        if not p_Handled then begin
            POSTransLineBK.RESET;
            POSTransLineBK.SETCURRENTKEY("Receipt No.", "Entry Type", "Entry Status");
            POSTransLineBK.SETRANGE("Receipt No.", DeliveryOrderBK."Order No.");
            POSTransLineBK.SETRANGE("Entry Type", POSTransLineBK."Entry Type"::Item);
            POSTransLineBK.SETRANGE("Entry Status", POSTransLineBK."Entry Status"::" ");
            POSTransLineBK.SETFILTER(POSTransLineBK."Store No.", '<>%1', DeliveryOrderBK."Restaurant No.");
            if POSTransLineBK.FINDFIRST then begin
                p_Handled := true;
                POSGUI.PosMessage(STRSUBSTNO(Text031, POSTransLineBK.Description, POSTransLineBK."Store No."));
            end;

            if not POSTransLineBK.GET(OrderCode, 32) then //CCf
                if not POSTransLineBK.GET(OrderCode, 33) then //Fact
                    if not POSGUI.PosConfirm(Text013, FALSE) then begin
                        p_Handled := true;
                        exit;
                    end;

            ContextValue := EPosContext.GetValue('<#DEL-PickupDate>');
            if Evaluate(DelContactTmp."LSC Next Order Date", ContextValue) then;
            ContextValue := EPosContext.GetValue('<#DEL-PickupTime>');
            if Evaluate(DelContactTmp."LSC Next Order Time", ContextValue) then;


            DelOrderTmp.Init();
            ZommDelOrder.GetTable(DelOrderTmp);
            EPOSControlInterface.GetRecordZoomData(ZommDelOrder, '#DEL-ORDER-DETZOOM');
            DelOrderTmp."FSN Alter Key" := ZommDelOrder.Field(DelOrderTmp.FieldNo("FSN Alter Key")).Value;

            if not p_Handled then begin
                IF DelOrderTmp."FSN Alter Key" <> 0 THEN BEGIN
                    DelStreet_l.SETRANGE(DelStreet_l."FSN Alter Key", DelOrderTmp."FSN Alter Key");
                    IF DelStreet_l.FINDFIRST AND (DelStreet_l."FSN Last Valid Time" <> 0T) AND
                     (DelStreet_l."FSN Last Valid Time" < DelContactTmp."LSC Next Order Time") THEN BEGIN
                        p_Handled := true;
                        ErrorValidation := STRSUBSTNO(Text038, DelStreet_l."Street Name", FORMAT(DelStreet_l."FSN Last Valid Time"), DelStreet_l.Restriction);
                        exit;
                    END;
                END;
            end;
        end;
        IF Store.GET(DeliveryOrderBK."Restaurant No.") THEN;
        IF NOT POSGUI.PosConfirm(STRSUBSTNO(Text014, Store."No.", Store.Name), FALSE) THEN begin
            p_Handled := true;
            exit;
        end;

        if not FSNSalesChannel.Get(OrderCode) then begin
            p_Handled := true;
            ErrorValidation := lText002;
            exit;
        end;
        if (DelContactTmp."LSC Next Order Restaurant" = 'F20') OR (DeliveryOrderBK."Restaurant No." = 'F20') then begin
            p_Handled := true;
            ErrorValidation := Text040;
            exit;
        end;
    end;

    procedure GetAlterKeyNo(sName: Text[250]; sPostCode: code[20]): Integer
    var
        i: Integer;
        s: Text[250];
    begin
        Clear(i);
        Clear(s);
        if sName = '' then
            exit(0);

        if CopyStr(sName, 1, 1) = '1' then begin
            i := '1';
            s := CopyStr(sName, StrPos(sName, ' ') + 1);
        end else
            s := sName;

        DeliveryStreetBK.Reset();
        DeliveryStreetBK.SetRange("Street Name", s);
        DeliveryStreetBK.SetRange("Post Code", sPostCode);
        DeliveryStreetBK.SetRange("Number from", i);
        if not DeliveryStreetBK.FindFirst() then
            DeliveryStreetBK.SetRange("Number from");
        if DeliveryStreetBK.find('-') then begin
            exit(DeliveryStreetBK."FSN Alter Key");
        end else
            exit(0);
    end;

    procedure MGTOrderCancelNewPressed(var pDelOrder: Record "LSC Delivery Order"; var pContactTMP: Record "Contact" temporary; STATE: Option CreateNew,Confirm,Edit,Cancel): Boolean
    var
        POSTransLineBK: Record "LSC POS Trans. Line";
        POSTransaction_l: Record "LSC POS Transaction";
        TextError: Text[250];
        Store_l: Record "LSC Store";
    begin
        /*
        IF NOT CheckPaymentsUtil.ValidateDeleteTransaction(pDelOrder."Order No.", TextError) THEN
            IF NOT POSGUI.PosConfirm(STRSUBSTNO(Text011, TextError), FALSE) THEN
                EXIT(FALSE)
            ELSE
                CheckPaymentsUtil.DeleteForce(pDelOrder."Order No.");
        EXIT(TRUE);
        */
    end;


    procedure MGTOrderSetConfirmTime(OrderNo: Code[20])
    var
        DeliveryOrder_l: Record "LSC Delivery Order";
        PosTrans_l: Record "LSC POS Transaction";
        //DAFUtil: Codeunit "50035";
        POSTrans: Record "LSC POS Transaction";
        FSNCallEntry: Record "FSN Call Entry";
        ActiveSession: Record "Active Session";
        //ConmutadorFSN: Record "50060";
        TransHeader: Record "LSC Transaction Header";
        Ok_: Boolean;
    begin
        IF DeliveryOrder_l.GET(OrderNo) THEN BEGIN
            IF PosTrans_l.GET(OrderNo) THEN BEGIN
                IF PosTrans_l."Store No." <> DeliveryOrder_l."Restaurant No." THEN BEGIN
                    ChangeStore(OrderNo, DeliveryOrder_l."Restaurant No.", 0);
                    DeliveryOrder_l.GET(OrderNo);
                END;

                POSInsertReplenSalesHist(DeliveryOrder_l, PosTrans_l);
            END;


            MGTLoadConextSpecialOrder(DeliveryOrder_l);
            IF PosTrans_l.GET(OrderNo) THEN BEGIN
                DeliveryOrder_l."FSN Sort" := SuperOrderID;
                PosTrans_l."FSN Sort" := SuperOrderID;
                PosTrans_l.MODIFY;
            END;

            IF DeliveryOrder_l."Contact Pickup Time" = 0T THEN
                DeliveryOrder_l."Contact Pickup Time" := TIME;
            DeliveryOrder_l."FSN Confirm Date" := TODAY;
            DeliveryOrder_l."FSN Confirm Time" := TIME;
            //CheckPaymentsUtil.GetDelOrderTenderType(DeliveryOrder_l); //REVISAR
            DeliveryOrder_l.MODIFY;
            COMMIT;
            //DAFUtil.CreateTrip(DeliveryOrder_l); //REVISAR 
        END;

        /*
        COMMIT;
        FSNCallEntry.RESET;
        FSNCallEntry.SETCURRENTKEY(AppliedbyReceiptNo, "Phone No.", Extension);
        FSNCallEntry.SETRANGE(FSNCallEntry.AppliedbyReceiptNo, OrderNo);
        IF NOT FSNCallEntry.FINDFIRST THEN
            IF POSTrans.GET(OrderNo) THEN BEGIN
                ActiveSession.RESET;
                ActiveSession.SETRANGE(ActiveSession."User ID", USERID);
                IF ActiveSession.FINDLAST THEN BEGIN
                    Ok_ := FALSE;
                    ConmutadorFSN.RESET;
                    ConmutadorFSN.SETRANGE(ConmutadorFSN.Hostname, ActiveSession."Client Computer Name");
                    IF ConmutadorFSN.FINDLAST THEN BEGIN
                        FSNCallEntry.RESET;
                        FSNCallEntry.SETRANGE(FSNCallEntry.Fecha, TODAY);
                        FSNCallEntry.SETRANGE(FSNCallEntry.Extension, ConmutadorFSN.Extension);
                        FSNCallEntry.SETRANGE(FSNCallEntry.Finalizada, FALSE);
                        IF FSNCallEntry.FINDLAST THEN BEGIN
                            FSNCallEntry.AppliedbyReceiptNo := OrderNo;
                            FSNCallEntry.MODIFY;
                            Ok_ := TRUE;
                        END;
                    END;
                END;
                IF NOT Ok_ THEN BEGIN
                    FSNCallEntry.RESET;
                    FSNCallEntry.SETCURRENTKEY(AppliedbyReceiptNo, Telefono, Extension);
                    FSNCallEntry.SETRANGE(FSNCallEntry.Fecha, TODAY);
                    FSNCallEntry.SETRANGE(FSNCallEntry.Telefono, POSTrans."Sell-to Contact No.");
                    FSNCallEntry.SETRANGE(FSNCallEntry.AppliedbyReceiptNo, '');
                    IF FSNCallEntry.FIND('+') THEN BEGIN
                        FSNCallEntry.AppliedbyReceiptNo := OrderNo;
                        FSNCallEntry.MODIFY;
                        Ok_ := TRUE;
                    END;
                END;
                IF NOT Ok_ THEN BEGIN
                    TransHeader.RESET;
                    TransHeader.SETRANGE(TransHeader."Customer No.", POSTrans."Customer No.");
                    TransHeader.SETFILTER(TransHeader."Sell-to Contact No.", '<>%1', POSTrans."Sell-to Contact No.");
                    IF TransHeader.FIND('+') THEN BEGIN
                        FSNCallEntry.SETRANGE(FSNCallEntry.Telefono, TransHeader."Sell-to Contact No.");
                        IF FSNCallEntry.FIND('-') THEN BEGIN
                            FSNCallEntry.AppliedbyReceiptNo := OrderNo;
                            FSNCallEntry.MODIFY;
                        END;
                    END;
                END;
            END;
            */
    end;

    procedure MGTDelEcommList(pParameters: Record "LSC POS Menu Line") ReceiptLocal: Code[20]
    var
        CSWebTable: Record "FSN WebServiceTable";
        POSTrans: Record "LSC POS Transaction";
    begin
        /*
        ReceiptLocal :=
          POSTransaction.LookUp(FALSE, MGTLookupEcommerceID(), '');*/

        IF ReceiptLocal = '' THEN
            EXIT;

        IF NOT POSTrans.GET(ReceiptLocal) THEN
            IF CSWebTable.GET(ReceiptLocal) THEN BEGIN
                CSWebTable."Status WS" := CSWebTable."Status WS"::InProcess;
                CSWebTable.MODIFY;
                ReceiptLocal := '';
            END;
    end;

    procedure DPCProcessOrderCancel(DelOrderCode: Code[20])
    var
        SalesChannel: Record "FSN Sales Channel";
        DeliveryTripOld: Record "FSN Delivery Trip";
        PostedDelTripNew: Record "LSC Posted Delivery Order";
        Ok: Boolean;
    begin
        if not DeliveryOrderBK.Get(DelOrderCode) then
            exit;
        IF DeliveryOrderBK."Call Cent. Web Service Status" IN [DeliveryOrderBK."Call Cent. Web Service Status"::"New-Not Confirmed",
                                                         DeliveryOrderBK."Call Cent. Web Service Status"::"New-Not Sent", DeliveryOrderBK."Call Cent. Web Service Status"::"New-Sent",
                                                         DeliveryOrderBK."Call Cent. Web Service Status"::"Cancelled-Sent"] THEN BEGIN
            DeleteDeliveryComplete(DeliveryOrderBK."Order No.");
        END;
        if SalesChannel.GET(DeliveryOrderBK."Order No.") then begin
            SalesChannel.Voided := TRUE;
            SalesChannel.MODIFY;
        END;

        IF DeliveryTripOld.GET(DeliveryOrderBK."Order No.") THEN BEGIN
            IF DeliveryTripOld."Trip. Status" = DeliveryTripOld."Trip. Status"::"Search Driver" THEN BEGIN
                DeliveryTripOld."Trip. Status" := DeliveryTripOld."Trip. Status"::"Cancelled In CC";
                DeliveryTripOld."CallCenter WS Status" := DeliveryTripOld."CallCenter WS Status"::"Changed-Not Sent";
                DeliveryTripOld.MODIFY;
            END ELSE BEGIN
                IF DeliveryTripOld."Trip. Status" IN [DeliveryTripOld."Trip. Status"::"No Started"
                                                       , DeliveryTripOld."Trip. Status"::"Assign Manual"] THEN BEGIN

                    DeliveryTripOld."Trip Finalize Time" := CURRENTDATETIME;
                    DeliveryTripOld."Trip. Status" := DeliveryTripOld."Trip. Status"::"Cancelled In CC";
                    DeliveryTripOld."CallCenter WS Status" := DeliveryTripOld."CallCenter WS Status"::"Changed-Not Sent";
                    DeliveryTripOld."General Status" := DeliveryTripOld."General Status"::Cancelled;
                    DeliveryTripOld.MODIFY;

                END;
            END;
        END;
    end;


    procedure PFReadLocalVar(var LastSlipNo: Code[20]; var pPOSHeaderExists: Boolean; var pOrderNo: Code[20])
    var
        Transaction: Record "LSC Transaction Header";
        PosTrans: Record "LSC POS Transaction";
        TmpLastSlip: Text[30];
        FilterFrom: Text[30];
        FilterTo: Text[30];
        ExistingReceiptNo: Code[20];
    begin
        /*
        pPOSHeaderExists := pOrderNo <> '';
        POSSESSION.DeleteValue(MGTSessionSetOrderID);

        IF pPOSHeaderExists THEN BEGIN
            IF PosTrans.GET(pOrderNo) THEN BEGIN
                PosTrans."Staff ID" := POSSESSION.StaffID();
                PosTrans."Sales Staff" := POSSESSION.StaffID();
                PosTrans.MODIFY;
            END;
            EXIT;
        END;
        RetailSetupGlobals.GET;

        LastSlipNo := '0';
        TmpLastSlip := POSFunction.ZeroPad(RetailSetupGlobals."Distribution Location", 10) +
                       POSFunction.ZeroPad(LastSlipNo, 9);
        Transaction.RESET;
        Transaction.SETCURRENTKEY("Receipt No.", Date);

        FilterFrom := POSFunction.ZeroPad(RetailSetupGlobals."Distribution Location", 10) + POSFunction.ZeroPad('0', 9);
        FilterTo := POSFunction.ZeroPad(RetailSetupGlobals."Distribution Location", 10) + POSFunction.NumberPad('9', 9);
        Transaction.SETRANGE("Receipt No.", FilterFrom, FilterTo);

        ExistingReceiptNo := '';
        IF Transaction.FINDLAST THEN
            IF Transaction."Receipt No." > TmpLastSlip THEN
                ExistingReceiptNo := Transaction."Receipt No.";

        PosTrans.RESET;
        PosTrans.SETRANGE("Receipt No.", FilterFrom, FilterTo);
        IF PosTrans.FINDLAST THEN
            IF PosTrans."Receipt No." > TmpLastSlip THEN BEGIN
                IF PosTrans."Receipt No." > ExistingReceiptNo THEN
                    ExistingReceiptNo := PosTrans."Receipt No.";
            END;

        IF ExistingReceiptNo <> '' THEN
            LastSlipNo := ExistingReceiptNo;

        POSSESSION.SetValue('#CC_SLIP_OFFLINE', RetailSetupGlobals."Distribution Location");
        */
    end;

    /*
        procedure EXOCreatAutom(pHeader: Record "LSC POS Transaction"; pNewStore: Code[10])
        var
            DeliveryOrder_l: Record "LSC Delivery Order";
            DeliveryOrder2_l: Record "LSC Delivery Order";
            TextError: Text;
            StaffSession: Code[20];
            Windows: Dialog;
            WindowsText: Text[100];
            lText001: Label 'Creating Order...';
            NewReceipt: Code[20];
            NewReceipt2: Code[20];
            OrderNo: Code[20];
            HeaderExists: Boolean;
            Contact: Record Contact;
            TenderTypeSetup: Record "LSC Tender Type Setup";
            NewPosTrans: Record "LSC POS Transaction";
        begin
            IF (pHeader."Receipt No." = '') OR (pNewStore = '') THEN
                EXIT;

            DeliveryOrder_l.GET(pHeader."Receipt No.");
            OrderNo := DeliveryOrder_l."Order No.";

            WindowsText := STRSUBSTNO(lText001);
            Windows.OPEN(WindowsText);
            Windows.UPDATE;

            StaffSession := '';
            NewReceipt := '';
            RetailSetupBK.GET;

            CLEAR(NewReceipt2);
            CLEAR(NewReceipt);
            //POSSESSION.DeleteValue(MGTSessionSetOrderID());
            PFReadLocalVar(NewReceipt, HeaderExists, NewReceipt2);
            IF ((NewReceipt = '') OR (NewReceipt = '0')) THEN BEGIN
                POSGUI.PosMessage(Text019);
                EXIT;
            END;
            COMMIT;
            NewReceipt := EXOCreateAutomHeader(pHeader, NewReceipt, pNewStore);//Header new
            EXOCreateAutomLine(pHeader, OrderNo, NewReceipt);  //LinesCopy
            NewPosTrans.GET(NewReceipt);
            NewPosTrans.CALCFIELDS("Gross Amount");

            ChangeStoreUpdDiscounts(NewPosTrans);

            DeliveryOrder2_l.INIT;
            DeliveryOrder2_l.TRANSFERFIELDS(DeliveryOrder_l);
            DeliveryOrder2_l."Restaurant No." := NewPosTrans."Store No.";
            DeliveryOrder2_l."Order No." := NewPosTrans."Receipt No.";
            DeliveryOrder2_l."Contact Pickup Time" := TIME;
            DeliveryOrder2_l."Order Date" := TODAY;
            DeliveryOrder2_l."Printed OK" := FALSE;
            DeliveryOrder2_l."Call Cent. Web Service Status" := DeliveryOrder2_l."Call Cent. Web Service Status"::"New-Not Confirmed";
            DeliveryOrder2_l."External Order No." := DeliveryOrder_l."Order No.";
            DeliveryOrder2_l."Amount Incl. VAT" := NewPosTrans."Gross Amount";
            DeliveryOrder2_l.INSERT;

            Windows.CLOSE;
            COMMIT;

            POSGUI.PosMessage(STRSUBSTNO(Text020, DeliveryOrder_l."Order No."));
        end;

        local procedure EXOCreateAutomHeader(pHeader: Record "LSC POS Transaction"; NewReceipt: Code[20]; pNewStore: Code[10]): Code[20]
        var
            NewPosTrans: Record "LSC POS Transaction";
            OldPosTrans: Record "LSC POS Transaction";
            CCPOSTermLocal: Record "LSC CC POS Term. Assignm.";
        begin
            OldPosTrans.GET(pHeader."Receipt No.");
            RetailSetupBK.GET;
            CCPOSTermLocal.GET(RetailSetupBK."Local Store No.", pNewStore);

            NewPosTrans.INIT;
            NewPosTrans."Store No." := CCPOSTermLocal."Restaurant No.";
            NewPosTrans."POS Terminal No." := CCPOSTermLocal."Rest. POS Terminal";
            NewPosTrans."Created on POS Terminal" := CCPOSTermLocal."Rest. POS Terminal";
            NewPosTrans."Original Date" := TODAY;
            NewPosTrans."Time when Total Pressed" := TIME;
            NewPosTrans."Currency Factor" := 1;  //Always in Local Currency
            NewPosTrans."Trans. Date" := TODAY;
            NewPosTrans."Original Date" := TODAY;
            NewPosTrans."Trans Time" := TIME;

            NewPosTrans."Sales Staff" := OldPosTrans."Sales Staff";
            IF NewPosTrans."Sales Staff" = '' THEN
                NewPosTrans."Sales Staff" := POSSESSION.StaffID();
            IF NewPosTrans."Staff ID" = '' THEN
                NewPosTrans."Staff ID" := POSSESSION.StaffID();
            NewPosTrans."VAT Bus.Posting Group" := OldPosTrans."VAT Bus.Posting Group";
            NewPosTrans."Sale Is Return Sale" := FALSE;
            NewPosTrans."Sales Type" := OldPosTrans."Sales Type";

            NewPosTrans."Price Group Code" := OldPosTrans."Price Group Code";
            NewPosTrans."Customer No." := OldPosTrans."Customer No.";
            NewPosTrans."Customer Disc. Group" := OldPosTrans."Customer Disc. Group";
            NewPosTrans."Sell-to Contact No." := OldPosTrans."Sell-to Contact No.";
            NewPosTrans.Comment := OldPosTrans.Comment;
            NewPosTrans."Index Field" := OldPosTrans."Index Field";
            NewPosTrans."New Transaction" := FALSE;
            NewPosTrans."Transaction Type" := OldPosTrans."Transaction Type"::Sales;

            NewReceipt := INCSTR(NewReceipt);
            NewPosTrans."Receipt No." :=
                  POSFunction.ZeroPad(RetailSetupBK."Distribution Location", 10) +
                  POSFunction.ZeroPad(NewReceipt, 9);

            IF NOT NewPosTrans.INSERT THEN
                ERROR(Text019);

            EXIT(NewPosTrans."Receipt No.");
        end;

        local procedure EXOCreateAutomLine(pHeader: Record "LSC POS Transaction"; OldReceipt: Code[20]; NewReceipt: Code[20]): Code[1]
        var
            POSLine_l: Record "LSC POS Trans. Line";
            POSLine2_l: Record "LSC POS Trans. Line";
            NewLine: Record "LSC POS Trans. Line";
            LineNumber: Integer;
            NewPosTrans: Record "LSC POS Transaction";
            VoucherEntriesOld: Record "LSC Voucher Entries";
            VoucherEntriesNew: Record "LSC Voucher Entries";
            OfferPoscalculations: Record "LSC Offer Pos Calculation";
        begin
            NewPosTrans.GET(NewReceipt);
            LineNumber := 10000;

            POSLine_l.RESET;
            POSLine_l.SETCURRENTKEY("Receipt No.", "Entry Type", "Entry Status");
            POSLine_l.SETRANGE(POSLine_l."Receipt No.", OldReceipt);
            POSLine_l.SETRANGE(POSLine_l."Entry Type", POSLine_l."Entry Type"::Item);
            POSLine_l.SETRANGE(POSLine_l."Entry Status", POSLine_l."Entry Status"::" ");
            POSLine_l.SETRANGE(POSLine_l.Marked, TRUE);
            IF POSLine_l.FIND('-') THEN
                REPEAT
                    NewLine.INIT;
                    NewLine."Receipt No." := NewPosTrans."Receipt No.";
                    NewLine."Store No." := NewPosTrans."Store No.";
                    NewLine."POS Terminal No." := NewPosTrans."POS Terminal No.";
                    NewLine."Entry Type" := NewLine."Entry Type"::Item;
                    NewLine."Sales Staff" := NewPosTrans."Sales Staff";
                    NewLine.Description := '';
                    NewLine."Line No." := LineNumber;
                    LineNumber += 10000;

                    NewLine.VALIDATE(NewLine."Unit of Measure", POSLine_l."Unit of Measure");
                    NewLine.VALIDATE(Number, POSLine_l.Number);
                    NewLine.VALIDATE(Quantity, POSLine_l.Quantity);
                    NewLine.VALIDATE(Price, POSLine_l.Price);

                    NewLine.Description := POSLine_l.Description;
                    NewLine.VALIDATE("Sales Type", NewPosTrans."Sales Type");
                    NewLine."Parent Line" := POSLine_l."Line No.";
                    NewLine."Parent Line" := NewLine."Line No.";
                    NewLine."Parent Compression" := NewLine."Parent Compression"::No;
                    NewLine.CalcPrices;
                    NewLine."Prompted for IPO" := TRUE; //Always set Prompted for Item Point Offer to TRUE
                    NewLine.INSERT(TRUE);

                    IF VoucherEntriesOld.GET(POSLine_l."Store No.", POSLine_l."POS Terminal No.", 0, POSLine_l."Line No.", POSLine_l."Receipt No.")
                      THEN BEGIN
                        VoucherEntriesNew.TRANSFERFIELDS(VoucherEntriesOld);
                        VoucherEntriesNew."Receipt Number" := NewPosTrans."Receipt No.";
                        VoucherEntriesNew.INSERT;
                    END;
                UNTIL POSLine_l.NEXT = 0;

            IF POSLine_l.FIND('-') THEN
                REPEAT
                    POSLine2_l.GET(POSLine_l."Receipt No.", POSLine_l."Line No.");
                    POSLine2_l.VoidLine();

                    OfferPoscalculations.SETRANGE("Receipt No.", POSLine_l."Receipt No.");
                    OfferPoscalculations.SETRANGE("Trans. Line No.", POSLine_l."Line No.");
                    IF OfferPoscalculations.FINDFIRST THEN
                        OfferPoscalculations.DELETEALL;

                UNTIL POSLine_l.NEXT = 0;

            POSLine_l.RESET;
            POSLine_l.SETRANGE("Receipt No.", OldReceipt);
            POSLine_l.SETRANGE("Entry Type", POSLine_l."Entry Type"::FreeText);
            POSLine_l.SETRANGE("Entry Status", 0);
            POSLine_l.SETFILTER("Card/Customer/Coup.Item No", '<>%1', '');
            IF POSLine_l.FIND('-') THEN BEGIN
                POSLine2_l.TRANSFERFIELDS(POSLine_l);
                POSLine2_l."Line No." := LineNumber;
                POSLine2_l."Store No." := NewPosTrans."Store No.";
                POSLine2_l."Receipt No." := NewPosTrans."Receipt No.";
                POSLine2_l."POS Terminal No." := NewPosTrans."POS Terminal No.";
                POSLine2_l."Trans. Date" := TODAY;
                POSLine2_l."Trans. Time" := TIME;
                POSLine2_l.INSERT;
            END;
        end;
    */
    local procedure EXOSelectLookupStore(pParameter: Record "LSC POS Menu Line")
    var
        lTxt0: Label 'Create to store %1 %2';
        Store_l: Record "LSC Store";
        recRef: RecordRef;
    begin
        POSTransLineBK.Reset();
        POSTransLineBK.SetCurrentKey("Receipt No.", "Entry Type", "Entry Status");
        POSTransLineBK.SetRange("Receipt No.", POSTransaction.GetReceiptNo());
        POSTransLineBK.SetRange("Entry Type", POSTransLineBK."Entry Type"::Item);
        POSTransLineBK.SetRange("Entry Status", POSTransLineBK."Entry Status"::" ");
        POSTransLineBK.SetRange(Marked, true);
        if not POSTransLineBK.Find('-') then begin
            POSGUI.PosMessage(Text016);
            exit;
        end;

        if not Store_l.Get(POSSESSION.StoreNo()) then
            exit;
        if POSGUI.PosConfirm(StrSubstNo(lTxt0, Store_l."No.", Store_l.Name), true) then begin
            EXOCreateOrderOnDemand(Store_l."No.");
            exit;
        end;
        Store_l.Reset();
        recRef.GetTable(Store_l);
        POSTransaction.LookUpEx(true, '#DEL-ORDER-EXT', '', recRef);
    end;

    procedure EXOCreateOrderOnDemand(pStoreSelected: Code[10])
    var
        DeliveryOrder_l: Record "LSC Delivery Order";
        DeliveryOrder2_l: Record "LSC Delivery Order";
        TenderTypeSetup: Record "LSC Tender Type Setup";
        NewPosTrans: Record "LSC POS Transaction";
        Contact: Record Contact;
        Windows: Dialog;
        TextError: Text;
        HeaderExists: Boolean;
        StaffSession: Code[20];
        NewReceipt: Code[20];
        WindowsText: Text[100];
        OrderNo: Code[20];
        lText001: Label 'Creating Order...';
    begin
        OrderNo := POSTransaction.GetReceiptNo();
        IF (OrderNo = '') or (pStoreSelected = '') THEN
            EXIT;

        DeliveryOrder_l.GET(OrderNo);

        WindowsText := STRSUBSTNO(lText001);
        Windows.OPEN(WindowsText);
        Windows.UPDATE;

        StaffSession := '';
        RetailSetupBK.GET;

        IF ((RetailSetupBK."FSN Last Slipt No." = '') OR not RetailSetupBK."FSN Is Local Receipt") THEN BEGIN
            POSGUI.PosMessage(Text019);
            EXIT;
        END;

        NewReceipt := EXOCreateOrderHeader(OrderNo, pStoreSelected);//Header Copy
        EXOCreateOrderLine(OrderNo, NewReceipt);  //LinesCopy
        NewPosTrans.GET(NewReceipt);
        NewPosTrans.CALCFIELDS("Gross Amount");

        ChangeStoreUpdDiscounts(NewPosTrans);

        DeliveryOrder2_l.INIT;
        DeliveryOrder2_l.TRANSFERFIELDS(DeliveryOrder_l);
        DeliveryOrder2_l."Restaurant No." := NewPosTrans."Store No.";
        DeliveryOrder2_l."Order No." := NewPosTrans."Receipt No.";
        DeliveryOrder2_l."Contact Pickup Time" := TIME;
        DeliveryOrder2_l."Order Date" := TODAY;
        DeliveryOrder2_l."Printed OK" := FALSE;
        DeliveryOrder2_l."Call Cent. Web Service Status" := DeliveryOrder2_l."Call Cent. Web Service Status"::"New-Not Confirmed";
        DeliveryOrder2_l."External Order No." := DeliveryOrder_l."Order No.";
        DeliveryOrder2_l."Amount Incl. VAT" := NewPosTrans."Gross Amount";
        DeliveryOrder2_l.INSERT;
        Windows.CLOSE;
        COMMIT;

        /*IF pParameter.Parameter = 'SHOWMSG' THEN*/
        POSGUI.PosMessage(STRSUBSTNO(Text020, DeliveryOrder_l."Order No."));
    end;

    local procedure EXOCreateOrderHeader(pOrder: Code[20]; pStoreSelected: Code[10]): Code[20]
    var
        NewPosTrans: Record "LSC POS Transaction";
        OldPosTrans: Record "LSC POS Transaction";
    begin
        OldPosTrans.GET(pOrder);
        RetailUserBK.Get(UserId);
        CCPOSTermBK.Get(RetailUserBK."Store No.", pStoreSelected);
        CCPOSTermBK.TestField("Rest. POS Terminal");

        NewPosTrans.INIT;
        NewPosTrans."Store No." := CCPOSTermBK."Restaurant No."; //OldPosTrans."Store No.";
        NewPosTrans."POS Terminal No." := CCPOSTermBK."Rest. POS Terminal"; //OldPosTrans."POS Terminal No.";
        NewPosTrans."Created on POS Terminal" := CCPOSTermBK."Rest. POS Terminal";//OldPosTrans."POS Terminal No.";
        NewPosTrans."Original Date" := TODAY;
        NewPosTrans."Time when Total Pressed" := TIME;
        NewPosTrans."Currency Factor" := 1;  //Always in Local Currency
        NewPosTrans."Trans. Date" := TODAY;
        NewPosTrans."Original Date" := TODAY;
        NewPosTrans."Trans Time" := TIME;

        NewPosTrans."Sales Staff" := OldPosTrans."Sales Staff";
        IF NewPosTrans."Sales Staff" = '' THEN
            NewPosTrans."Sales Staff" := POSSESSION.StaffID();
        IF NewPosTrans."Staff ID" = '' THEN
            NewPosTrans."Staff ID" := POSSESSION.StaffID();
        NewPosTrans."VAT Bus.Posting Group" := OldPosTrans."VAT Bus.Posting Group";
        NewPosTrans."Sale Is Return Sale" := FALSE;
        NewPosTrans."Sales Type" := OldPosTrans."Sales Type";

        NewPosTrans."Price Group Code" := OldPosTrans."Price Group Code";
        NewPosTrans."Customer No." := OldPosTrans."Customer No.";
        NewPosTrans."Customer Disc. Group" := OldPosTrans."Customer Disc. Group";
        NewPosTrans."Sell-to Contact No." := OldPosTrans."Sell-to Contact No.";
        NewPosTrans.Comment := OldPosTrans.Comment;
        NewPosTrans."Index Field" := OldPosTrans."Index Field";
        NewPosTrans."New Transaction" := FALSE;
        NewPosTrans."Transaction Type" := OldPosTrans."Transaction Type"::Sales;

        /*NewReceipt := INCSTR(NewReceipt);
        NewPosTrans."Receipt No." :=
              POSFunction.ZeroPad(RetailSetupBK."Distribution Location", 10) +
              POSFunction.ZeroPad(NewReceipt, 9);*/

        IF NOT NewPosTrans.INSERT THEN//Receipt Automatic in call center
            ERROR(Text019);

        EXIT(NewPosTrans."Receipt No.");
    end;

    local procedure EXOCreateOrderLine(OldReceipt: Code[20]; NewReceipt: Code[20]): Code[1]
    var
        POSLine_l: Record "LSC POS Trans. Line";
        POSLine2_l: Record "LSC POS Trans. Line";
        NewLine: Record "LSC POS Trans. Line";
        LineNumber: Integer;
        NewPosTrans: Record "LSC POS Transaction";
        VoucherEntriesOld: Record "LSC Voucher Entries";
        VoucherEntriesNew: Record "LSC Voucher Entries";
        OfferPoscalculations: Record "LSC Offer Pos Calculation";
    begin
        NewPosTrans.GET(NewReceipt);
        LineNumber := 10000;

        POSLine_l.RESET;
        POSLine_l.SETCURRENTKEY("Receipt No.", "Entry Type", "Entry Status");
        POSLine_l.SETRANGE(POSLine_l."Receipt No.", OldReceipt);
        POSLine_l.SETRANGE(POSLine_l."Entry Type", POSLine_l."Entry Type"::Item);
        POSLine_l.SETRANGE(POSLine_l."Entry Status", POSLine_l."Entry Status"::" ");
        POSLine_l.SETRANGE(POSLine_l.Marked, TRUE);
        IF POSLine_l.FIND('-') THEN
            REPEAT
                NewLine.INIT;
                NewLine."Receipt No." := NewPosTrans."Receipt No.";
                NewLine."Store No." := NewPosTrans."Store No.";
                NewLine."POS Terminal No." := NewPosTrans."POS Terminal No.";
                NewLine."Entry Type" := NewLine."Entry Type"::Item;
                NewLine."Sales Staff" := NewPosTrans."Sales Staff";
                NewLine.Description := '';
                NewLine."Line No." := LineNumber;
                LineNumber += 10000;


                NewLine.VALIDATE(NewLine."Unit of Measure", POSLine_l."Unit of Measure");
                NewLine.VALIDATE(Number, POSLine_l.Number);
                NewLine.VALIDATE(Quantity, POSLine_l.Quantity);
                NewLine.VALIDATE(Price, POSLine_l.Price);

                NewLine.VALIDATE("Sales Type", NewPosTrans."Sales Type");

                NewLine."Parent Line" := POSLine_l."Line No.";
                NewLine.Description := POSLine_l.Description;
                NewLine."Parent Line" := NewLine."Line No.";
                NewLine."Parent Compression" := NewLine."Parent Compression"::No;
                NewLine.CalcPrices;
                NewLine."Prompted for IPO" := TRUE; //Always set Prompted for Item Point Offer to TRUE
                NewLine.INSERT(TRUE);

                IF VoucherEntriesOld.GET(POSLine_l."Store No.", POSLine_l."POS Terminal No.", 0, POSLine_l."Line No.", POSLine_l."Receipt No.")
                  then begin
                    VoucherEntriesNew.TRANSFERFIELDS(VoucherEntriesOld);
                    VoucherEntriesNew."Receipt Number" := NewPosTrans."Receipt No.";
                    VoucherEntriesNew.INSERT;
                end;
            UNTIL POSLine_l.NEXT = 0;

        IF POSLine_l.FIND('-') THEN
            REPEAT
                POSLine2_l.GET(POSLine_l."Receipt No.", POSLine_l."Line No.");
                POSLine2_l.VoidLine();

                OfferPoscalculations.SETRANGE("Receipt No.", POSLine_l."Receipt No.");
                OfferPoscalculations.SETRANGE("Trans. Line No.", POSLine_l."Line No.");
                IF OfferPoscalculations.FINDFIRST THEN
                    OfferPoscalculations.DELETEALL;

            UNTIL POSLine_l.NEXT = 0;

        POSLine_l.RESET;
        POSLine_l.SETRANGE("Receipt No.", OldReceipt);
        POSLine_l.SETRANGE("Entry Type", POSLine_l."Entry Type"::FreeText);
        POSLine_l.SETRANGE("Entry Status", 0);
        POSLine_l.SETFILTER("Card/Customer/Coup.Item No", '<>%1', '');
        IF POSLine_l.FIND('-') THEN BEGIN
            POSLine2_l.TRANSFERFIELDS(POSLine_l);
            POSLine2_l."Line No." := LineNumber;
            POSLine2_l."Store No." := NewPosTrans."Store No.";
            POSLine2_l."Receipt No." := NewPosTrans."Receipt No.";
            POSLine2_l."POS Terminal No." := NewPosTrans."POS Terminal No.";
            POSLine2_l."Trans. Date" := TODAY;
            POSLine2_l."Trans. Time" := TIME;
            POSLine2_l.INSERT;
        END;
    end;


    procedure POSNewLineFreeText(Receipt: Code[20]; LinkNumber: Integer; TextVal: Text; Type: Option Normal,Typology,Payments,Infocode)
    var
        pPOSTrans: Record "LSC POS Transaction";
        pPOSTransLine: Record "LSC POS Trans. Line";
        pNextLine: Integer;
        NewLine: Record "LSC POS Trans. Line";
        POSInfo: Record "LSC POS Trans. Infocode Entry";
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

    procedure POSInsertReplenSalesHist(pDelOrder: Record "LSC Delivery Order"; pPOSTrans: Record "LSC POS Transaction")
    var
        DelStreet: Record "LSC Delivery Street";
        Ptline: Record "LSC POS Trans. Line";
        InventoryLookup: Record "LSC Inventory Lookup Table";
        IsInventoryOK: Boolean;
        InsertOK: Boolean;
        Item_l: Record "Item";
        Item_TMP: Record "FSN Inventory Internal Log" temporary;
        ItemInternalLog: Record "FSN Inventory Internal Log";
        ReplenAdjLine: Record "FSN Replen. Sales Adj. Line";
        AdjNextLine: Record "FSN Replen. Sales Adj. Line";
        i: Integer;
        lText000: Label 'Del. for %1, default %2. In order %3 Inv. %4';
    begin
        IF (pDelOrder."Order Type Option" in [4, 3]) OR (pPOSTrans."Customer No." = '') THEN
            EXIT;

        IF pDelOrder."FSN Alter Key" = 0 THEN
            EXIT;

        DelStreet.RESET;
        DelStreet.SETRANGE(DelStreet."FSN Alter Key", pDelOrder."FSN Alter Key");
        IF NOT DelStreet.FINDFIRST THEN
            EXIT;
        IF pDelOrder."Restaurant No." = DelStreet."Restaurant No." THEN
            EXIT;

        if DelStreet."Restaurant No." = '' then
            exit;

        Item_TMP.RESET;
        Item_TMP.DELETEALL;

        Ptline.RESET;
        Ptline.SETCURRENTKEY("Receipt No.", "Entry Type", "Entry Status");
        Ptline.SETRANGE(Ptline."Receipt No.", pDelOrder."Order No.");
        Ptline.SETRANGE(Ptline."Entry Type", Ptline."Entry Type"::Item);
        Ptline.SETRANGE(Ptline."Entry Status", 0);
        IF Ptline.FIND('-') THEN
            REPEAT
                CLEAR(InsertOK);
                IF ItemInternalLog.GET(Ptline.Number) THEN
                    InsertOK := ItemInternalLog."Calculate Inventory" = ItemInternalLog."Calculate Inventory"::Yes
                ELSE
                    InsertOK := TRUE;
                IF InsertOK THEN BEGIN
                    IF NOT Item_TMP.GET(Ptline.Number) THEN BEGIN
                        Item_TMP.INIT;
                        Item_TMP."No." := Ptline.Number;
                        Item_TMP."Qty. per UM" := 0;
                        Item_TMP.INSERT;
                    END;
                    Item_TMP."Qty. per UM" += (DivisorQtyPerUM(Ptline.Number, Ptline."Unit of Measure") * Ptline.Quantity);
                    Item_TMP.MODIFY;
                END;
            UNTIL Ptline.NEXT = 0;

        CLEAR(InsertOK);

        Item_TMP.RESET;
        IF Item_TMP.FIND('-') THEN
            REPEAT
                InventoryLookup.RESET;
                CLEAR(InventoryLookup);

                IsInventoryOK := TRUE;
                IsInventoryOK := InventoryLookup.GET(Item_TMP."No.", '', DelStreet."Restaurant No.", '', '');
                IF IsInventoryOK THEN
                    IsInventoryOK := Item_TMP."Qty. per UM" <= InventoryLookup."Net Inventory";

                IF NOT IsInventoryOK AND Item_l.GET(Item_TMP."No.") THEN BEGIN
                    CLEAR(InsertOK);
                    ReplenAdjLine.RESET;
                    ReplenAdjLine.SETCURRENTKEY("Customer ID", Date, "Item No.");
                    ReplenAdjLine.SETRANGE(ReplenAdjLine."Customer ID", pPOSTrans."Customer No.");
                    ReplenAdjLine.SETFILTER(ReplenAdjLine.Date, '>=%1&<=%2', TODAY - 3, TODAY);
                    ReplenAdjLine.SETRANGE(ReplenAdjLine."Item No.", Item_TMP."No.");
                    IF ReplenAdjLine.FIND('-') THEN BEGIN
                        InsertOK := (ReplenAdjLine."Unit of Measure" = Item_l."Base Unit of Measure");
                        IF NOT ReplenAdjLine.Aprobada THEN BEGIN
                            ReplenAdjLine."Receipt No." := pDelOrder."Order No.";
                            ReplenAdjLine.MODIFY;
                        END;
                    END;
                    IF NOT InsertOK THEN BEGIN
                        ReplenAdjLine.INIT;
                        ReplenAdjLine."Item No." := Item_TMP."No.";
                        ReplenAdjLine.Date := TODAY;
                        ReplenAdjLine."Location Code" := DelStreet."Restaurant No.";
                        AdjNextLine.RESET;
                        AdjNextLine.SETCURRENTKEY("Item No.", Date, "Location Code", "Line No.");
                        AdjNextLine.SETRANGE(AdjNextLine."Item No.", Item_TMP."No.");
                        AdjNextLine.SETRANGE(AdjNextLine.Date, TODAY);
                        AdjNextLine.SETRANGE(AdjNextLine."Location Code", DelStreet."Restaurant No.");
                        IF AdjNextLine.FIND('+') THEN
                            ReplenAdjLine."Line No." := AdjNextLine."Line No." + 1
                        ELSE
                            ReplenAdjLine."Line No." := 1000;
                        ReplenAdjLine."Barcode No." := Item_l."FSN Barcode No.";
                        ReplenAdjLine."Variant Code" := '';
                        ReplenAdjLine.Description := Item_l.Description;
                        ReplenAdjLine.Quantity := ROUND(Item_TMP."Qty. per UM" - InventoryLookup."Net Inventory", 1);//WVILLALTA 11.21
                        IF InventoryLookup."Net Inventory" < 0 THEN
                            ReplenAdjLine.Quantity := ROUND(Item_TMP."Qty. per UM", 1);
                        ReplenAdjLine."Unit of Measure" := Item_l."Base Unit of Measure";
                        ReplenAdjLine.StaffID := pDelOrder."Order Taker";
                        IF ReplenAdjLine.StaffID = '' THEN
                            ReplenAdjLine.StaffID := pPOSTrans."Sales Staff";
                        ReplenAdjLine.Aprobada := FALSE;
                        ReplenAdjLine.Telefono := pDelOrder."Phone No.";
                        ReplenAdjLine."Replication Counter" := 0;
                        ReplenAdjLine."Customer ID" := pPOSTrans."Customer No.";
                        ReplenAdjLine.Comment := COPYSTR(STRSUBSTNO(lText000, pDelOrder."Restaurant No.", DelStreet."Restaurant No.", FORMAT(Item_TMP."Qty. per UM")
                                                        , FORMAT(InventoryLookup."Net Inventory")), 1, MAXSTRLEN(ReplenAdjLine.Comment));
                        ReplenAdjLine."Receipt No." := pDelOrder."Order No.";
                        ReplenAdjLine."Adjustment Mode" := ReplenAdjLine."Adjustment Mode"::DeliveryAutomatic;
                        ReplenAdjLine."Location Code Source" := pDelOrder."Restaurant No.";
                        ReplenAdjLine.INSERT;
                    END;
                END;
            UNTIL Item_TMP.NEXT = 0;
    end;


    procedure POSCheckReplenAdj()
    var
        ReplenSalesAdj: Record "FSN Replen. Sales Adj. Line";
        ReplenSalesAdj_tmp: Record "FSN Replen. Sales Adj. Line" temporary;
        DelOrder: Record "LSC Delivery Order";
        PostDelOrder: Record "LSC Posted Delivery Order";
        TransHdr: Record "LSC Transaction Header";
        ModifyOk: Boolean;
        DeleteOk: Boolean;
    begin
        ReplenSalesAdj.RESET;
        ReplenSalesAdj.SETCURRENTKEY("Adjustment Mode", Aprobada);
        ReplenSalesAdj.SETRANGE(ReplenSalesAdj."Adjustment Mode", ReplenSalesAdj."Adjustment Mode"::DeliveryAutomatic);
        ReplenSalesAdj.SETRANGE(ReplenSalesAdj.Aprobada, FALSE);
        IF ReplenSalesAdj.FIND('-') THEN
            REPEAT
                CLEAR(ModifyOk);
                CLEAR(DeleteOk);
                IF NOT DelOrder.GET(ReplenSalesAdj."Receipt No.") THEN
                    IF PostDelOrder.GET(ReplenSalesAdj."Receipt No.") THEN BEGIN
                        TransHdr.RESET;
                        TransHdr.SETCURRENTKEY("Receipt No.");
                        TransHdr.SETRANGE(TransHdr."Receipt No.", ReplenSalesAdj."Receipt No.");
                        IF TransHdr.FIND('+') THEN
                            IF TransHdr."Entry Status" = 0 THEN
                                ModifyOk := TRUE
                            ELSE
                                DeleteOk := TRUE;
                    END ELSE BEGIN
                        DeleteOk := TRUE;
                    END;

                IF DeleteOk THEN BEGIN
                    IF ReplenSalesAdj."Replication Counter" = 0 THEN
                        ReplenSalesAdj.DELETE
                    ELSE BEGIN
                        ReplenSalesAdj_tmp := ReplenSalesAdj;
                        ReplenSalesAdj_tmp.Quantity := 0;
                        ReplenSalesAdj_tmp.Aprobada := TRUE;
                        ReplenSalesAdj_tmp.INSERT();
                    END;
                END;
                IF NOT DeleteOk AND ModifyOk THEN BEGIN
                    ReplenSalesAdj_tmp := ReplenSalesAdj;
                    ReplenSalesAdj_tmp.Aprobada := TRUE;
                    ReplenSalesAdj_tmp.INSERT();
                END;
            UNTIL ReplenSalesAdj.NEXT = 0;

        ReplenSalesAdj_tmp.RESET;
        IF ReplenSalesAdj_tmp.FIND('-') THEN
            REPEAT
                IF ReplenSalesAdj.GET(ReplenSalesAdj_tmp."Item No.", ReplenSalesAdj_tmp.Date, ReplenSalesAdj_tmp."Location Code", ReplenSalesAdj_tmp."Line No.") THEN BEGIN
                    ReplenSalesAdj.Aprobada := TRUE;
                    ReplenSalesAdj.MODIFY(TRUE);
                END;
            UNTIL ReplenSalesAdj_tmp.NEXT = 0;
    end;



    procedure POSSessionCC(pStaffID: Code[20]; pPassword: Text[20]; pWorkShift: Code[1]; pIsManager: Boolean; var pReasonText: Text[80]; pLevel: Integer): Boolean
    var
        UserPersonalization2: Record "User Personalization";
        Txt1: Label 'Level permission is not valid';
        Txt2: Label 'User and Password is not valid';
        I: Integer;
        Staff_l: Record "LSC Staff";
        StaffPermissionGroup_l: Record "LSC STAFF PER Group";
    begin
        /*
        IF NOT POSGUI.PosLogin(pStaffID, pPassword, pWorkShift) THEN BEGIN
            pReasonText := Txt2;
            EXIT(FALSE);
        END;
        *///REVISAR
        IF NOT POSSESSION.Login(pIsManager, pStaffID, pPassword, pWorkShift, pReasonText) THEN
            EXIT(FALSE);

        IF pIsManager THEN BEGIN
            pReasonText := Txt1;
            IF Staff_l.GET(pStaffID) THEN
                IF StaffPermissionGroup_l.GET(Staff_l."Permission Group") THEN
                    IF StaffPermissionGroup_l."Manager Privileges" = StaffPermissionGroup_l."Manager Privileges"::Yes THEN
                        CLEAR(pReasonText);
            IF pReasonText <> '' THEN
                EXIT(FALSE);
        END;

        IF pLevel > 0 THEN BEGIN
            CLEAR(pReasonText);
            UserPersonalization2.RESET;
            UserPersonalization2.SETRANGE(UserPersonalization2."User ID", pStaffID);
            UserPersonalization2.SETRANGE(UserPersonalization2."Profile ID", 'RETAIL STORE MANAGER');
            IF NOT (UserPersonalization2.FINDFIRST) THEN
                pReasonText := Txt1
            ELSE
                IF NOT (EVALUATE(I, pStaffID)) THEN
                    pReasonText := Txt1;

            EXIT(pReasonText = '');
        END;
        EXIT(TRUE);
    end;

    procedure GetInventoryUM(precRef: RecordRef): Text
    var
        POSTransLineTemp: Record "LSC POS Trans. Line";
        InventoryLookUpTable: Record "LSC Inventory Lookup Table";
        Divisor: Decimal;
        UM: Record "Item Unit of Measure";
        InventoryValue: Decimal;
        StoreCode: Text[20];
    begin
        StoreCode := POSSESSION.GetValue('#_CHANGESTORE');
        precRef.SETTABLE(POSTransLineTemp);
        IF POSTransLineTemp."Entry Type" = POSTransLineTemp."Entry Type"::Item THEN BEGIN
            Divisor := 1;
            IF UM.GET(POSTransLineTemp.Number, POSTransLineTemp."Unit of Measure") THEN
                IF UM."Qty. per Unit of Measure" <> 0 THEN
                    Divisor := UM."Qty. per Unit of Measure";//DMEDINA10FEB2020+

            InventoryValue := 0;
            IF InventoryLookUpTable.GET(POSTransLineTemp.Number, POSTransLineTemp."Variant Code", POSTransLineTemp."Store No.", POSTransLineTemp."Lot No.", POSTransLineTemp."Serial No.") THEN
                InventoryValue := InventoryLookUpTable."Net Inventory" / Divisor;
            IF (InventoryValue > 1000000) OR (InventoryValue < -1000000) THEN BEGIN
                IF (InventoryValue > 1000000) THEN
                    EXIT('+1000000.00')
                ELSE
                    EXIT('-1000000.00' + ' ' + StoreCode);
            END ELSE
                EXIT(FORMAT(ROUND(InventoryValue, 0.1, '='), 0, '<Precision,1:1><Standard Format,0>') + ' ' + StoreCode);

        END;
        EXIT('0.0' + ' ' + StoreCode);
    end;

    procedure ValPosTransaction(Recib: Code[20]);
    var
        myInt: Integer;
        POSTransa: Record "LSC POS Transaction";
        CCPostermial: Record "LSC CC POS Term. Assignm.";
    begin
        if POSTransa.Get(Recib) then
            if CCPostermial.Get('F20', POSTransa."Store No.") then begin
                if POSTransa."POS Terminal No." <> CCPostermial."Rest. POS Terminal" then begin
                    POSTransa."POS Terminal No." := CCPostermial."Rest. POS Terminal";
                    POSTransa.Modify(true);
                end;
            end;
    end;


    procedure SedFormulario(DelOrder: Record "LSC Delivery Order"; PosTrans: record "LSC POS Transaction")
    var
        JSonString: Text;
        ResponseWS: Text;
        Ok: Boolean;
        Path: Text;
        url: Text;
        ContentType: Text[50];
        POSMenuLineTMP: Record "LSC POS Menu Line" temporary;
        EMPTY: Label 'EMPTY';
        lText001: Label 'Data not exists';
        lText002: Label 'Response not Found';
        FSNSetup: Record "FSN Fasani Setup";
        lText003: Label 'Inactive in DAF';
        WindowsJson: Codeunit "FSN Windows Forms NET";
        pDataType: Option String,Decimal,Int,Bool;
        Staff_l: Record "LSC Staff";
        F_fecha: DateTime;
        FSDelivery: Record "FSN Delivery Trip";
        json: JsonObject;
        staff: JsonObject;
        jValue: JsonValue;
        JsonArr: JsonArray;
        requestHeader, contentHeader : HttpHeaders;
        body: HttpContent;
        request: HttpRequestMessage;
        uri: Text;
        response: JsonObject;
        api: Codeunit "C807 CCONECTION";
        sede: Integer;
        Rest: Integer;
        GlobalInfo: Record "LSC POS Trans. Infocode Entry";
        TypeHelp: Codeunit "Type Helper";
        InputTime: Time;
        Hour: Integer;
        Minute: Integer;
        Second: Integer;
        Dia: date;
        sb: DotNet StringBuilder;
        xmlFinal: File;
        xmlStream: OutStream;
        Parametro: Record "FSN Parameter";
        TimeT: Time;
    begin
        GlobalParametro();
        if not GlobalParametroPQ.Activo then
            exit;

        GlobalInfo.SetRange("Receipt No.", DelOrder."Order No.");
        GlobalInfo.SetRange("Source Code", GlobalParametroPQ.Valor);
        GlobalInfo.SetRange("Transaction Type", GlobalInfo."Transaction Type"::"Sales Entry");
        if GlobalInfo.FindFirst() then begin
            if (CopyStr(GlobalInfo.Information, 1, 3) = 'FSN') or (CopyStr(GlobalInfo.Information, 1, 3) = 'ERI') then
                exit
        end;

        uri := GlobalParametroPQ."Web Uri" + '/SetRecolectaAsync';
        uri += '/?store=' + DelOrder."Restaurant No.";

        TimeT := (130000T);
        if Time() >= TimeT then
            F_fecha := CreateDateTime(Today() + 1, TimeT)
        else
            F_fecha := CreateDateTime(Today(), TimeT);

        json.Add('recolecta_fecha', (FORMAT(DATE2DMY(DT2DATE(F_fecha), 3)) + '-' +
                                                   FORMAT(DATE2DMY(DT2DATE(F_fecha), 2)) + '-' +
                                                   FORMAT(DATE2DMY(DT2DATE(F_fecha), 1)) + ' ' +
                                                   Format(F_fecha, 2, '<Hours24,2>') + ':' +
                                                   FORMAT(F_fecha, 2, '<Minutes,2>')));
        json.Add('recolecta_comentario', DelOrder."Restaurant No.");
        json.Add('tipo_entrega', 'NRML');
        json.Add('guias', Guia(PosTrans));

        json.WriteTo(JSonString);

        Parametro.Reset();
        Parametro.SetRange(Grupo, 'JSONP');
        Parametro.SetRange(Codigo, 'PAQUETERIA');

        IF Parametro.FindFirst() and Parametro.Activo then begin
            sb := sb.StringBuilder();
            sb.Append(JSonString);
            if xmlFinal.Create('C:\Temp\Paqueteria' + DelOrder."Order No." + '.json') then begin
                xmlFinal.CreateOutStream(xmlStream);
                xmlStream.Write(sb.ToString);
                xmlFinal.Close();
            end;
        end;

        body.WriteFrom(JSonString);
        body.GetHeaders(contentHeader);
        contentHeader.Clear();
        contentHeader.Add('Content-Type', 'application/json');
        request.GetHeaders(requestHeader);
        requestHeader.Clear();
        request.Content := body;
        response := api.Post(uri, request);
        Response(response);
    end;

    procedure Response(response: JsonObject)
    var
        myInt: Integer;
        jToken, jToken2 : JsonToken;
        JsonArr: JsonArray;
        _JObject: JsonObject;
        Enlace: Text;
        OrderOld: Code[20];
        Guia: Text;
        Pdf: Text;
        FilePath: Text;
        recolecta: Text;
        JsObj: JsonObject;

    begin
        if response.SelectToken('recolecta', JToken2) then
            if not jToken2.AsValue().IsNull then
                recolecta := JToken2.AsValue().AsText();

        if response.Get('guias', jToken) then begin
            JsonArr := JToken.AsArray();
            JsonArr.Get(0, JToken);
            _JObject := JToken.AsObject();
            if _JObject.SelectToken('seguimiento', JToken) then
                if not jToken.AsValue().IsNull then
                    Enlace := JToken.AsValue().AsText();
            if _JObject.SelectToken('orden', JToken) then
                if not jToken.AsValue().IsNull then
                    OrderOld := JToken.AsValue().AsText();
            if _JObject.SelectToken('guia', JToken) then
                if not jToken.AsValue().IsNull then
                    Guia := JToken.AsValue().AsText();

            FilePath := PDF(JToken);
            FSNQuotation.SendPaqueteria(Enlace, OrderOld, FilePath, recolecta);
            Insertline('recolecta : ' + recolecta, OrderOld);
            Insertline('Guia de C807 : ' + Guia, OrderOld);
            ChangeWebService(recolecta, OrderOld, Guia);
            InfocodeC807(Guia, OrderOld);
            POSSESSION.SetValue('GUIAC807', Guia);
        end else begin
            response.Get('message', jToken);
            if not jToken.AsValue().IsNull then
                Error(jToken.AsValue().AsText());
        end;
    end;

    local procedure ChangeWebService(Recolecta: Text; OrderOld: Code[20]; Guia: Text)
    var
        WebService: Record "FSN WebServiceTable";
    begin
        if WebService.Get(OrderOld) then begin
            WebService."C807 Guia" := Guia;
            WebService."C807 Recolecta" := Recolecta;
            WebService."C807 Status" := true;
            WebService.Modify(true);
        end;
    end;

    procedure PDF(JsonT: JsonToken): Text
    var
        json: JsonObject;
        myInt: Integer;
        document: DotNet XmlDocument;
        JObject: DotNet JObject;
        NewJson: Text;
        Convert: DotNet JsonConvert;
        Pdf2: text;
        JsonV: JsonValue;
        FileHandle: File;
        convet: DotNet Convert;
        ItemTenantMedia: Record "Tenant Media";
        By: DotNet Byte;
        InStr: InStream;
        OutStr: OutStream;
        TempBlob: Codeunit "Temp Blob";
        Base64Convert: Codeunit "Base64 Convert";
        Test, pdf, FilePath : Text;
        FileManagement: Codeunit "File Management";
        requestHeader, contentHeader : HttpHeaders;
        body: HttpContent;
        request: HttpRequestMessage;
        uri: Text;
        JsonArr: Codeunit "JSON Management";
        JSonString: Text;
        api: Codeunit "C807 CCONECTION";
        response: JsonObject;
        Jarray: JsonArray;
        ejem: Text;
        JsonArray: DotNet JArray;
        Lis: List of [Text];
        jToken: JsonToken;
        DelOrder: Record "LSC Delivery Order";
    begin
        IF DelOrder.Get(POSSESSION.GetValue('CURRORDER')) then;

        uri := GlobalParametroPQ."Web Uri" + '/ImprimirGuias';
        uri += '/?store=' + DelOrder."Restaurant No.";
        Jarray.Add(JsonT);
        json.Add('guias', Jarray);

        json.WriteTo(JSonString);
        body.WriteFrom(JSonString);
        body.GetHeaders(contentHeader);
        contentHeader.Clear();
        contentHeader.Add('Content-Type', 'application/json');
        request.GetHeaders(requestHeader);
        requestHeader.Clear();
        request.Content := body;
        response := api.Post(uri, request);
        if response.Get('pdf', jToken) then begin
            if not jToken.AsValue().IsNull then begin
                Pdf2 := JToken.AsValue().AsText();
                TempBlob.CreateOutStream(OutStr);
                Base64Convert.FromBase64(Pdf2, OutStr);
                TempBlob.CreateInStream(InStr);
                FilePath := 'GUIA.pdf';
                Test := FileManagement.InstreamExportToServerFile(InStr, FilePath);
                exit(Test);
            end;
        end;
    end;

    procedure Insertline(Guia: Text; OrderOld: code[20])
    var
        LinkNumber: Integer;
        pNextLine: Integer;
        NewPOSTransLine: Record "LSC POS Trans. Line";
        pPOSTransLine: Record "LSC POS Trans. Line";
        PosTrans: Record "LSC POS Transaction";
        Text1601: Label 'Guia de C807 : ';
    begin
        if PosTrans.Get(OrderOld) then;

        IF LinkNumber = 0 THEN BEGIN
            pNextLine := 10000;
            pPOSTransLine.RESET;
            pPOSTransLine.SETCURRENTKEY("Receipt No.", "Line No.");
            pPOSTransLine.SETRANGE(pPOSTransLine."Receipt No.", OrderOld);
            IF pPOSTransLine.FINDLAST THEN
                pNextLine := pPOSTransLine."Line No." + 10000;
        END ELSE
            pNextLine := LinkNumber;

        NewPOSTransLine.Init();
        NewPOSTransLine."Receipt No." := OrderOld;
        NewPOSTransLine."Store No." := PosTrans."Store No.";
        NewPOSTransLine."POS Terminal No." := PosTrans."POS Terminal No.";
        NewPOSTransLine."Entry Type" := NewPOSTransLine."Entry Type"::FreeText;
        NewPOSTransLine."Text Type" := NewPOSTransLine."Text Type"::"Freetext Input";
        NewPOSTransLine.VALIDATE(NewPOSTransLine.Description, COPYSTR(UpperCase(Guia), 1, MAXSTRLEN(NewPOSTransLine.Description)));
        NewPOSTransLine."Line No." := pNextLine;
        IF NewPOSTransLine.Insert(true) then;
    end;

    procedure InfocodeC807(Guia: Text; OrderOld: code[20]);
    var
        myInt: Integer;
        PosInfo: Record "LSC POS Trans. Infocode Entry";
        PosTransLine: Record "LSC POS Trans. Line";
    begin
        PosInfo.Reset();
        PosInfo.SetRange("Receipt No.", OrderOld);
        PosInfo.SetRange("Transaction Type", PosInfo."Transaction Type"::"Sales Entry");
        PosInfo.SetRange(Infocode, 'NGUIA');
        if PosInfo.FindFirst() then begin
            PosInfo.Information := Guia;
            PosInfo.Modify();
            Commit();
        end else begin
            PosTransLine.SetRange("Receipt No.", OrderOld);
            PosTransLine.SetRange("Entry Status", PosTransLine."Entry Status"::" ");
            PosTransLine.SetRange(Number, GlobalParametroPQ.Valor);
            if PosTransLine.FindFirst() then begin
                PosInfo.Init();
                PosInfo."Receipt No." := PosTransLine."Receipt No.";
                PosInfo."Store No." := PosTransLine."Store No.";
                PosInfo."Transaction Type" := PosInfo."Transaction Type"::"Sales Entry";
                PosInfo."Line No." := PosTransLine."Line No.";
                PosInfo.Infocode := 'NGUIA';
                PosInfo."Entry Line No." := 0;
                PosInfo.Information := Guia;
                PosInfo.Date := Today;
                PosInfo.Time := Time;
                PosInfo."POS Terminal No." := PosTransLine."POS Terminal No.";
                PosInfo."Staff ID" := PosTransLine."Sales Staff";
                PosInfo."Type of Input" := PosInfo."Type of Input"::Text;
                PosInfo.Amount := PosTransLine.Amount;
                PosInfo."Source Code" := PosTransLine.Number;
                PosInfo.Status := PosInfo.Status::Processed;
                PosInfo."Selected Quantity" := 1;
                PosInfo.Counter := 1;
                PosInfo.Insert();
            end;
        end;
    end;

    procedure Guia(PosTransaction: Record "LSC POS Transaction"): JsonArray
    var
        myInt: Integer;
        json: JsonObject;
        staff: JsonObject;
        jValue: JsonValue;
        PosTran: Record "LSC POS Transaction";
        Customer: Record Customer;
        Array: JsonArray;
        posCode: Record "Post Code";
        CodDep: Integer;
        CodMun: Integer;
        pcod: Integer;
        strc: Integer;
        WS: Record "FSN WebServiceTable";
        DelOrd: Record "LSC Delivery Order";
        PosTransLine: Record "LSC POS Trans. Line";
        WebTable: Record "FSN WebServiceTable";
        PosInfocode: Record "LSC POS Trans. Infocode Entry";
    begin
        if DelOrd.Get(PosTransaction."Receipt No.") then;
        if WebTable.Get(PosTransaction."Receipt No.") then;
        PosTransLine.Reset();
        PosTransLine.SetRange("Receipt No.", DelOrd."Order No.");
        PosTransLine.SetRange("Entry Type", PosTransLine."Entry Type"::Item);
        PosTransLine.SetRange(Number, GlobalParametroPQ.Valor);
        if PosTransLine.FindFirst() then;
        json.Add('orden', PosTransaction."Receipt No.");
        if PosTransaction."Customer No." <> '' then begin
            if Customer.Get(PosTransaction."Customer No.") then begin
                json.Add('nombre', Customer.Name);
                json.Add('direccion', DelOrd.Directions);
                json.Add('telefono', DelOrd."Phone No.");
                json.Add('correo', Customer."E-Mail");

                case WebTable."Value Text 1" of
                    'Servicio Entrega Regular':
                        begin
                            PosInfocode.reset();
                            PosInfocode.setrange("Receipt No.", PosTransaction."Receipt No.");
                            PosInfocode.setrange("Transaction Type", PosInfocode."Transaction Type"::"Payment Entry");
                            PosInfocode.setrange(Infocode, 'OREFECT');
                            PosInfocode.setrange(status, PosInfocode."status"::Processed);
                            PosInfocode.SetRange(Subcode, 'C807');
                            if PosInfocode.FindFirst() then begin
                                json.Add('tipo_servicio', 'CCE');
                                json.Add('monto_cce', WebTable.Amount);
                            end ELSE
                                json.Add('tipo_servicio', 'SER');
                        end;
                    'Cobro contra entrega':
                        begin
                            json.Add('tipo_servicio', 'CCE');
                            json.Add('monto_cce', WebTable.Amount);
                        end;
                end;

                if Customer.City <> '' then begin
                    posCode.Reset();
                    posCode.SetRange(Code, customer."Post Code");
                    if posCode.Find('-') then begin
                        json.Add('departamento_id', CodDepartamento(posCode));
                        json.Add('municipio_id', CodMunicipio(posCode));
                    end;
                end;
                json.Add('contacto', DelOrd."Phone No.");
                json.Add('referencia', DelOrd."Restaurant No." + ' ' + WebTable."Last Error Text");
                json.Add('indicaciones', DelOrd."Restaurant No.");
                json.Add('liquidacion_documentos', false);
                json.Add('detalle', Detalle(PosTransaction."Receipt No."));
                json.Add('documento', Documento(PosTransaction));
                Array.Add(json);
            end;
            exit(Array);
        end;
    end;

    procedure CodDepartamento(posCode: Record "Post Code"): Integer
    var
        myInt: Integer;
        CodD: Option ,,Ahuachapán,Cabañas,Chalatenango,Cuscatlán,"La Libertad","La Paz","La Unión",Morazán,"San Miguel","San Salvador","San Vicente","Santa Ana","Sonsonate",Usulután;
    begin
        if Format(CodD::"Ahuachapán") = posCode.City then
            exit(CodD::"Ahuachapán");

        if Format(CodD::"Cabañas") = posCode.City then
            exit(CodD::"Cabañas");

        if Format(CodD::Chalatenango) = posCode.City then
            exit(CodD::"Chalatenango");

        if Format(CodD::"Cuscatlán") = posCode.City then
            exit(CodD::"Cuscatlán");

        if Format(CodD::"La Libertad") = posCode.City then
            exit(CodD::"La Libertad");

        if Format(CodD::"La Paz") = posCode.City then
            exit(CodD::"La Paz");

        if Format(CodD::"La Unión") = posCode.City then
            exit(CodD::"La Unión");

        if Format(CodD::"Morazán") = posCode.City then
            exit(CodD::"Morazán");

        if Format(CodD::"San Miguel") = posCode.City then
            exit(CodD::"San Miguel");

        if Format(CodD::"San Salvador") = posCode.City then
            exit(CodD::"San Salvador");

        if Format(CodD::"San Vicente") = posCode.City then
            exit(CodD::"San Vicente");

        if Format(CodD::"Santa Ana") = posCode.City then
            exit(CodD::"Santa Ana");

        if Format(CodD::"Sonsonate") = posCode.City then
            exit(CodD::"Sonsonate");

        if Format(CodD::"Usulután") = posCode.City then
            exit(CodD::"Usulután");
    end;

    procedure CodMunicipio(posCode: Record "Post Code"): Integer
    var
        myInt: Integer;
    begin
        if posCode.City = 'Ahuachapán' then begin
            if posCode.County = 'Ahuachapán' then
                exit(2);
            if posCode.County = 'Apaneca' then
                exit(3);
            if posCode.County = 'Atiquizaya' then
                exit(4);
            if posCode.County = 'Concepción de Ataco' then
                exit(5);
            if posCode.County = 'El Refugio' then
                exit(6);
            if posCode.County = 'Guaymango' then
                exit(7);
            if posCode.County = 'Jujutla' then
                exit(8);
            if posCode.County = 'San Francisco Menéndez' then
                exit(9);
            if posCode.County = 'San Lorenzo' then
                exit(10);
            if posCode.County = 'San Pedro Puxtla' then
                exit(11);
            if posCode.County = 'Turín' then
                exit(12);
            if posCode.County = 'Tacuba' then
                exit(13);
        end;

        if posCode.City = 'Cabañas' then begin
            if posCode.County = 'Cinquera' then
                exit(14);
            if posCode.County = 'Dolores / Villa Dolores' then
                exit(15);
            if posCode.County = 'Guacotecti' then
                exit(16);
            if posCode.County = 'Ilobasco' then
                exit(17);
            if posCode.County = 'Jutiapa' then
                exit(18);
            if posCode.County = 'San Isidro' then
                exit(19);
            if posCode.County = 'Sensuntepeque' then
                exit(20);
            if posCode.County = 'Tejutepeque' then
                exit(21);
            if posCode.County = 'Victoria' then
                exit(22);
        end;
        if posCode.City = 'Chalatenango' then begin
            if posCode.County = 'Agua Caliente' then
                exit(23);
            if posCode.County = 'Arcatao' then
                exit(24);
            if posCode.County = 'Azacualpa' then
                exit(25);
            if posCode.County = 'Chalatenango' then
                exit(26);
            if posCode.County = 'Citalá' then
                exit(27);
            if posCode.County = 'Comalapa' then
                exit(28);
            if posCode.County = 'Concepción Quezaltepeque' then
                exit(29);
            if posCode.County = 'Dulce Nombre de María' then
                exit(30);
            if posCode.County = 'El Carrizal' then
                exit(31);
            if posCode.County = 'El Paraíso' then
                exit(32);
            if posCode.County = 'La Laguna' then
                exit(33);
            if posCode.County = 'La Palma' then
                exit(34);
            if posCode.County = 'La Reina' then
                exit(35);
            if posCode.County = 'Las Vueltas' then
                exit(36);
            if posCode.County = 'Nombre de Jesús' then
                exit(37);
            if posCode.County = 'Nueva Concepción' then
                exit(38);
            if posCode.County = 'Nueva Trinidad' then
                exit(39);
            if posCode.County = 'Ojos de Agua' then
                exit(40);
            if posCode.County = 'Potonico' then
                exit(41);
            if posCode.County = 'San Antonio de la Cruz' then
                exit(42);
            if posCode.County = 'San Antonio Los Ranchos' then
                exit(43);
            if posCode.County = 'San Fernando' then
                exit(44);
            if posCode.County = 'San Francisco Lempa' then
                exit(45);
            if posCode.County = 'San Francisco Morazán' then
                exit(46);
            if posCode.County = 'San Ignacio' then
                exit(47);
            if posCode.County = 'San Isidro Labrador' then
                exit(48);
            if posCode.County = 'San José Cancasque' then
                exit(49);
            if posCode.County = 'San José Las Flores' then
                exit(50);
            if posCode.County = 'San Luis del Carmen' then
                exit(51);
            if posCode.County = 'San Miguel de Mercedes' then
                exit(52);
            if posCode.County = 'San Rafael' then
                exit(53);
            if posCode.County = 'Santa Rita' then
                exit(54);
            if posCode.County = 'Tejutla' then
                exit(55);
        end;
        if posCode.City = 'Cuscatlán' then begin
            if posCode.County = 'Candelaria' then
                exit(56);
            if posCode.County = 'Cojutepeque' then
                exit(57);
            if posCode.County = 'El Carmen' then
                exit(58);
            if posCode.County = 'El Rosario' then
                exit(59);
            if posCode.County = 'Monte San Juan' then
                exit(60);
            if posCode.County = 'Oratorio de Concepción' then
                exit(61);
            if posCode.County = 'San Bartolomé Perulapía' then
                exit(62);
            if posCode.County = 'San Cristóbal' then
                exit(63);
            if posCode.County = 'San José Guayabal' then
                exit(64);
            if posCode.County = 'San Pedro Perulapán' then
                exit(65);
            if posCode.County = 'San Rafael Cedros' then
                exit(66);
            if posCode.County = 'San Ramón' then
                exit(67);
            if posCode.County = 'Santa Cruz Analquito' then
                exit(68);
            if posCode.County = 'Santa Cruz Michapa' then
                exit(69);
            if posCode.County = 'Suchitoto' then
                exit(70);
            if posCode.County = 'Tenancingo' then
                exit(71);
        end;
        if posCode.City = 'La Libertad' then begin
            if posCode.County = 'Antiguo Cuscatlán' then
                exit(72);
            if posCode.County = 'Chiltiupán' then
                exit(73);
            if posCode.County = 'Ciudad Arce' then
                exit(74);
            if posCode.County = 'Colón' then
                exit(75);
            if posCode.County = 'Comasagua' then
                exit(76);
            if posCode.County = 'Huizúcar' then
                exit(77);
            if posCode.County = 'Jayaque' then
                exit(78);
            if posCode.County = 'Jicalapa' then
                exit(79);
            if posCode.County = 'La Libertad' then
                exit(80);
            if posCode.County = 'Santa Tecla' then
                exit(81);
            if posCode.County = 'Nuevo Cuscatlán' then
                exit(82);
            if posCode.County = 'San Juan Opico' then
                exit(83);
            if posCode.County = 'Quezaltepeque' then
                exit(84);
            if posCode.County = 'Sacacoyo' then
                exit(85);
            if posCode.County = 'San José Villanueva' then
                exit(86);
            if posCode.County = 'San Matías' then
                exit(87);
            if posCode.County = 'San Pablo Tacachico' then
                exit(88);
            if posCode.County = 'Talnique' then
                exit(89);
            if posCode.County = 'Tamanique' then
                exit(90);
            if posCode.County = 'Teotepeque' then
                exit(91);
            if posCode.County = 'Tepecoyo' then
                exit(92);
            if posCode.County = 'Zaragoza' then
                exit(93);
            if posCode.County = 'Puerto La Libertad' then
                exit(901);
        end;
        if posCode.City = 'La Paz' then begin
            if posCode.County = 'Cuyultitán' then
                exit(94);
            if posCode.County = 'El Rosario / Rosario de La Paz' then
                exit(95);
            if posCode.County = 'Jerusalén' then
                exit(96);
            if posCode.County = 'Mercedes La Ceiba' then
                exit(97);
            if posCode.County = 'Olocuilta' then
                exit(98);
            if posCode.County = 'Paraíso de Osorio' then
                exit(99);
            if posCode.County = 'San Antonio Masahuat' then
                exit(100);
            if posCode.County = 'San Emigdio' then
                exit(101);
            if posCode.County = 'San Francisco Chinameca' then
                exit(102);
            if posCode.County = 'San Juan Nonualco' then
                exit(103);
            if posCode.County = 'San Juan Talpa' then
                exit(104);
            if posCode.County = 'San Juan Tepezontes' then
                exit(105);
            if posCode.County = 'San Luis La Herradura' then
                exit(106);
            if posCode.County = 'San Luis Talpa' then
                exit(107);
            if posCode.County = 'San Miguel Tepezontes' then
                exit(108);
            if posCode.County = 'San Pedro Masahuat' then
                exit(109);
            if posCode.County = 'San Pedro Nonualco' then
                exit(110);
            if posCode.County = 'San Rafael Obrajuelo' then
                exit(111);
            if posCode.County = 'Santa María Ostuma' then
                exit(112);
            if posCode.County = 'Santiago Nonualco' then
                exit(113);
            if posCode.County = 'Tapalhuaca' then
                exit(114);
            if posCode.County = 'Zacatecoluca' then
                exit(115);
        end;
        if posCode.City = 'La Unión' then begin
            if posCode.County = 'Anamorós' then
                exit(116);
            if posCode.County = 'Bolívar' then
                exit(117);
            if posCode.County = 'Concepción de Oriente' then
                exit(118);
            if posCode.County = 'Conchagua' then
                exit(119);
            if posCode.County = 'El Carmen' then
                exit(120);
            if posCode.County = 'El Sauce' then
                exit(121);
            if posCode.County = 'Intipucá' then
                exit(122);
            if posCode.County = 'La Unión' then
                exit(123);
            if posCode.County = 'Lilisque' then
                exit(124);
            if posCode.County = 'Meanguera del Golfo' then
                exit(125);
            if posCode.County = 'Nueva Esparta' then
                exit(126);
            if posCode.County = 'Pasaquina' then
                exit(127);
            if posCode.County = 'Polorós' then
                exit(128);
            if posCode.County = 'San Alejo' then
                exit(129);
            if posCode.County = 'San José' then
                exit(130);
            if posCode.County = 'Santa Rosa de Lima' then
                exit(131);
            if posCode.County = 'Yayantique' then
                exit(132);
            if posCode.County = 'Yucuaiquín' then
                exit(133);
        end;
        if posCode.City = 'Morazán' then begin
            if posCode.County = 'Arambala' then
                exit(134);
            if posCode.County = 'Cacaopera' then
                exit(135);
            if posCode.County = 'Chilanga' then
                exit(136);
            if posCode.County = 'Corinto' then
                exit(137);
            if posCode.County = 'Delicias de Concepción' then
                exit(138);
            if posCode.County = 'El Divisadero' then
                exit(139);
            if posCode.County = 'El Rosario' then
                exit(140);
            if posCode.County = 'Gualococti' then
                exit(141);
            if posCode.County = 'Guatajiagua' then
                exit(142);
            if posCode.County = 'Joateca' then
                exit(143);
            if posCode.County = 'Jocoaitique' then
                exit(144);
            if posCode.County = 'Jocoro' then
                exit(145);
            if posCode.County = 'Lolotiquillo' then
                exit(156);
            if posCode.County = 'Meanguera' then
                exit(147);
            if posCode.County = 'Osicala' then
                exit(148);
            if posCode.County = 'Perquín' then
                exit(149);
            if posCode.County = 'San Carlos' then
                exit(150);
            if posCode.County = 'San Fernando' then
                exit(151);
            if posCode.County = 'San Francisco Gotera' then
                exit(152);
            if posCode.County = 'San Isidro' then
                exit(153);
            if posCode.County = 'San Simón' then
                exit(154);
            if posCode.County = 'Sensembra' then
                exit(155);
            if posCode.County = 'Sociedad' then
                exit(156);
            if posCode.County = 'Torola' then
                exit(157);
            if posCode.County = 'Yamabal' then
                exit(158);
            if posCode.County = 'Yoloaiquín' then
                exit(159);
        end;
        if posCode.City = 'San Miguel' then begin
            if posCode.County = 'Carolina' then
                exit(160);
            if posCode.County = 'Chapeltique' then
                exit(161);
            if posCode.County = 'Chinameca' then
                exit(162);
            if posCode.County = 'Chirilagua' then
                exit(163);
            if posCode.County = 'Ciudad Barrios' then
                exit(164);
            if posCode.County = 'Comacarán' then
                exit(165);
            if posCode.County = 'El Tránsito' then
                exit(166);
            if posCode.County = 'Lolotique' then
                exit(167);
            if posCode.County = 'Moncagua' then
                exit(168);
            if posCode.County = 'Nueva Guadalupe' then
                exit(169);
            if posCode.County = 'Nuevo Edén de San Juan' then
                exit(170);
            if posCode.County = 'Quelepa' then
                exit(171);
            if posCode.County = 'San Antonio del Mosco' then
                exit(172);
            if posCode.County = 'San Gerardo' then
                exit(173);
            if posCode.County = 'San Jorge' then
                exit(174);
            if posCode.County = 'San Luis de la Reina' then
                exit(175);
            if posCode.County = 'San Miguel' then
                exit(176);
            if posCode.County = 'San Rafael Oriente' then
                exit(177);
            if posCode.County = 'Sesori' then
                exit(178);
            if posCode.County = 'Uluazapa' then
                exit(179);
        end;
        if posCode.City = 'San Salvador' then begin
            if posCode.County = 'Aguilares' then
                exit(180);
            if posCode.County = 'Ayutuxtepeque' then
                exit(181);
            if posCode.County = 'Apopa' then
                exit(182);
            if posCode.County = 'Delgado' then
                exit(183);
            if posCode.County = 'Cuscatancingo' then
                exit(184);
            if posCode.County = 'El Paisnal' then
                exit(185);
            if posCode.County = 'Guazapa' then
                exit(186);
            if posCode.County = 'Ilopango' then
                exit(187);
            if posCode.County = 'Mejicanos' then
                exit(188);
            if posCode.County = 'Nejapa' then
                exit(189);
            if posCode.County = 'Panchimalco' then
                exit(190);
            if posCode.County = 'Rosario de Mora' then
                exit(191);
            if posCode.County = 'San Marcos' then
                exit(192);
            if posCode.County = 'San Martín' then
                exit(193);
            if posCode.County = 'San Salvador' then
                exit(194);
            if posCode.County = 'Santiago Texacuangos' then
                exit(195);
            if posCode.County = 'Santo Tomás' then
                exit(196);
            if posCode.County = 'Soyapango' then
                exit(197);
            if posCode.County = 'Tonacatepeque' then
                exit(198);
        end;
        if posCode.City = 'San Vicente' then begin
            if posCode.County = 'Apastepeque' then
                exit(199);
            if posCode.County = 'Guadalupe' then
                exit(200);
            if posCode.County = 'San Cayetano Istepeque' then
                exit(201);
            if posCode.County = 'San Esteban Catarina' then
                exit(202);
            if posCode.County = 'San Ildefonso' then
                exit(203);
            if posCode.County = 'San Lorenzo' then
                exit(204);
            if posCode.County = 'San Sebastián' then
                exit(205);
            if posCode.County = 'San Vicente' then
                exit(206);
            if posCode.County = 'Santa Clara' then
                exit(207);
            if posCode.County = 'Santo Domingo' then
                exit(208);
            if posCode.County = 'Tecoluca' then
                exit(209);
            if posCode.County = 'Tepetitán' then
                exit(210);
            if posCode.County = 'Verapaz' then
                exit(211);
        end;
        if posCode.City = 'Santa Ana' then begin
            if posCode.County = 'Candelaria de la Frontera' then
                exit(212);
            if posCode.County = 'Chalchuapa' then
                exit(213);
            if posCode.County = 'Coatepeque' then
                exit(214);
            if posCode.County = 'El Congo' then
                exit(215);
            if posCode.County = 'El Porvenir' then
                exit(216);
            if posCode.County = 'Masahuat' then
                exit(217);
            if posCode.County = 'Metapán' then
                exit(218);
            if posCode.County = 'San Antonio Pajonal' then
                exit(219);
            if posCode.County = 'San Sebastián Salitrillo' then
                exit(220);
            if posCode.County = 'Santa Ana' then
                exit(221);
            if posCode.County = 'Santa Rosa Guachipilín' then
                exit(222);
            if posCode.County = 'Santiago de la Frontera' then
                exit(223);
            if posCode.County = 'Texistepeque' then
                exit(224);

        end;
        if posCode.City = 'Sonsonate' then begin
            if posCode.County = 'Acajutla' then
                exit(225);
            if posCode.County = 'Armenia' then
                exit(226);
            if posCode.County = 'Caluco' then
                exit(227);
            if posCode.County = 'Cuisnahuat' then
                exit(228);
            if posCode.County = 'Izalco' then
                exit(229);
            if posCode.County = 'Juayúa' then
                exit(230);
            if posCode.County = 'Nahuizalco' then
                exit(231);
            if posCode.County = 'Nahulingo' then
                exit(232);
            if posCode.County = 'Salcoatitán' then
                exit(233);
            if posCode.County = 'San Antonio del Monte' then
                exit(234);
            if posCode.County = 'San Julián' then
                exit(235);
            if posCode.County = 'Santa Catarina Masahuat' then
                exit(236);
            if posCode.County = 'Santa Isabel Ishuatán' then
                exit(237);
            if posCode.County = 'Santo Domingo de Guzmán' then
                exit(238);
            if posCode.County = 'Sonsonate' then
                exit(239);
            if posCode.County = 'Sonzacate' then
                exit(240);
        end;
        if posCode.City = 'Usulután' then begin
            if posCode.County = 'Alegría' then
                exit(241);
            if posCode.County = 'Berlín' then
                exit(242);
            if posCode.County = 'California' then
                exit(243);
            if posCode.County = 'Concepción Batres' then
                exit(244);
            if posCode.County = 'El Triunfo' then
                exit(245);
            if posCode.County = 'Ereguayquín' then
                exit(246);
            if posCode.County = 'Estanzuelas' then
                exit(247);
            if posCode.County = 'Jiquilisco' then
                exit(248);
            if posCode.County = 'Jucuapa' then
                exit(249);
            if posCode.County = 'Jucuarán' then
                exit(250);
            if posCode.County = 'Mercedes Umaña' then
                exit(251);
            if posCode.County = 'Nueva Granada' then
                exit(252);
            if posCode.County = 'Ozatlán' then
                exit(253);
            if posCode.County = 'Puerto El Triunfo' then
                exit(254);
            if posCode.County = 'San Agustín' then
                exit(255);
            if posCode.County = 'San Buenaventura' then
                exit(256);
            if posCode.County = 'San Dionisio' then
                exit(257);
            if posCode.County = 'San Francisco Javier' then
                exit(258);
            if posCode.County = 'Santa Elena' then
                exit(259);
            if posCode.County = 'Santa María' then
                exit(260);
            if posCode.County = 'Santiago de María' then
                exit(261);
            if posCode.County = 'Tecapán' then
                exit(262);
            if posCode.County = 'Usulután' then
                exit(263);
        end;
    end;

    procedure Detalle(Recibo: Code[20]): JsonArray
    var
        myInt: Integer;
        PosTransLine: Record "LSC POS Trans. Line";
        PosTransLineTmp: Record "LSC POS Trans. Line" temporary;
        json: JsonObject;
        staff: JsonObject;
        jValue: JsonValue;
        Arr: JsonArray;
        Peso: Decimal;
        Contenido: text;
        Unidad_m: Text;
        Unidad_Me: Option Lb,Kg;
        WebService: Record "FSN WebServiceTable";
    begin
        PosTransLine.Reset();
        PosTransLine.SetRange("Receipt No.", Recibo);
        PosTransLine.SetRange("Entry Status", PosTransLine."Entry Status"::" ");
        PosTransLine.SetRange("Entry Type", PosTransLine."Entry Type"::Item);
        if PosTransLine.Find('-') then begin
            repeat
                If PosTransLine.Number = GlobalParametroPQ.Valor then begin
                    PosTransLineTmp := PosTransLine;
                    PosTransLineTmp.Insert(true);
                end;
                Contenido += PosTransLine.Description + ' ';
                Unidad_m += PosTransLine."Unit of Measure";
            until PosTransLine.Next() = 0;

        end;
        WebService.Reset();
        if WebService.Get(Recibo) then begin
            json.Add('peso', WebService."C807 peso");
            json.Add('contenido', format(Contenido));
            json.Add('unidad_medida', Format(WebService."Unidad de medida"));
            Arr.Add(json);
            exit(Arr);

        end;
    end;

    procedure Documento(PosTr: Record "LSC POS Transaction"): JsonArray
    var
        myInt: Integer;
        json: JsonObject;
        staff: JsonObject;
        jValue: JsonValue;
        Arr: JsonArray;
    begin
        json.Add('tipo_id', 1);
        json.Add('numero', PosTr."Document No.");
        json.Add('observaciones', '');
        Arr.Add(json);
        exit(Arr);
    end;

    procedure GlobalParametro()
    var
        myInt: Integer;

    begin
        GlobalParametroPQ.Reset();
        GlobalParametroPQ.SetRange(Grupo, 'PAQUETERIA');
        GlobalParametroPQ.SetRange(Codigo, 'C807');
        if GlobalParametroPQ.FindFirst() then
            POSSESSION.SetValue('VALOR', GlobalParametroPQ.Valor);
    end;

    procedure ValidatePaqueteria(DeliveryOrder: Record "LSC Delivery Order"): Boolean
    var
        myInt: Integer;
        PosTransLine: Record "LSC POS Trans. Line";
        Paqueteria: Boolean;
    begin
        if GlobalParametroPQ.Valor = '' then
            GlobalParametro();

        PosTransLine.Reset();
        PosTransLine.SetRange("Receipt No.", DeliveryOrder."Order No.");
        PosTransLine.SetRange("Entry Type", PosTransLine."Entry Type"::Item);
        PosTransLine.SetRange(Number, GlobalParametroPQ.Valor);
        if PosTransLine.FindFirst() then begin
            exit(true);
        end else
            exit(false)
    end;

    procedure validateinfo(GlobalDelivery: Record "LSC Delivery Order"): Boolean
    var
        myInt: Integer;
        GlobalInfo: record "LSC POS Trans. Infocode Entry";
    begin
        GlobalInfo.SetRange("Receipt No.", GlobalDelivery."Order No.");
        GlobalInfo.SetRange("Source Code", GlobalParametroPQ.Valor);
        GlobalInfo.SetRange("Transaction Type", GlobalInfo."Transaction Type"::"Sales Entry");
        if GlobalInfo.FindFirst() then begin
            if (CopyStr(GlobalInfo.Information, 1, 3) = 'FSN') or (CopyStr(GlobalInfo.Information, 1, 3) = 'ERI') then
                exit(false)
            else
                exit(true);
        end else
            exit(true);
    end;

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //Validacion infocde de media de pago Efectivo domicilio
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Controller", 'OnLookupResult', '', false, false)]
    local procedure OnLookupResult(LookupID: Text; FilterText: Text; resultOK: Boolean; var processed: Boolean);
    var
        POSInterface: Codeunit "LSC POS Control Interface";
        TEXT000: label 'No es permitido seleccionar sala actual';
        TEXT001: label 'Debe Selecionar Sala';
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line";
        MsgResult: Text;
        FSNUtility: Codeunit "FSN Utility";
        DelOrder: Record "LSC Delivery Order";
        ProcessedCC: Boolean;
        posTransC: Codeunit "LSC POS Transaction";
        Command: Code[20];
    begin
        iF (LookupID = 'INFOCODE') and (FilterText = 'OREFECT') then begin
            RequestID := 'FSNCC';
            ProcessedCC := false;
            FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, ProcessedCC, MsgResult);
            if PosInterface.GetLookupKeyValue(LookupID) <> '' then begin
                IF NOT ProcessedCC THEN begin
                    if PosInterface.GetLookupKeyValue(LookupID) = POSSession.StoreNo() then
                        error(TEXT000);
                END ELSE BEGIN
                    if DelOrder.Get(POSSESSION.GetValue('CURRORDER')) then begin
                        if PosInterface.GetLookupKeyValue(LookupID) = DelOrder."Restaurant No." then
                            error(TEXT000);
                    end;
                END;
            end else begin
                error(TEXT001);
            end;
        end;

        iF (LookupID = 'EMPRESAS_ALIADAS') and (FilterText = '[EXECUTE]') then begin
            if PosInterface.GetLookupKeyValue(LookupID) <> '' then begin
                MsgResult := PosInterface.GetLookupKeyValue(LookupID);
                Command := PosInterface.GetLookupCommand(LookupID);
                if resultOK then begin
                    PosMenuLineTemp.Init();
                    PosMenuLineTemp.Command := Command;
                    PosMenuLineTemp.Parameter := MsgResult;
                    posTransC.run(PosMenuLineTemp);
                    MemberName(posTransC.GetReceiptNo());
                    processed := true;
                end;
            end;
        end;
    end;

    procedure MemberName(Receipt_No: Code[20])
    var
        myInt: Integer;
        LscPosTransLine: Record "LSC POS Trans. Line";
        LscPosTransact: Record "LSC POS Transaction";
    begin
        if LscPosTransact.Get(Receipt_No) then begin
            LscPosTransLine.Reset();
            LscPosTransLine.SetRange("Receipt No.", Receipt_No);
            LscPosTransLine.SetRange("Text Type", LscPosTransLine."Text Type"::"Member Text");
            LscPosTransLine.SetRange("Entry Status", 0);
            if LscPosTransLine.FindFirst() then begin
                LscPosTransLine.Description += LscPosTransact."Member Card No.";
                LscPosTransLine.Modify(true);
            end;
        end;
    end;

    //CONTROLLER ALL
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Controller", 'OnButtonPressed', '', true, true)]
    local procedure "EPOS Controler_OnButtonPressed"
    (
        var POSMenuLine: Record "LSC POS Menu Line";
        var handled: Boolean
    )
    var
        ErrorValidation: Text;
        DelOrd: Record "LSC Delivery Order";
        ExitPanel: Boolean;
        EPOSControlInterface: Codeunit "LSC POS Control Interface";
        Phone: Code[20];
        lTxt0: Label '%1 in %2 is not configured';
        lTxt1: Label 'Esta acción cancela el pedido actual. Tiene que insertar los productos nuevamente. ¿Desea continuar?';
        lTxt2: Label 'Esta acción cancela el pedido actual. ¿Desea continuar?';
        lTxt3: Label 'Estado del pedido %1';
        DelPanelUtility: Codeunit "LSC Del. POS Panel Utilities";
        DelOrderM: Codeunit "LSC Delivery Order Management";
        POSMenuLineV: Record "LSC POS Menu Line";
        SelOrderID: Code[20];
        PanelResponse: Integer;
        Windows: Dialog;
        LoadingText: Label 'Procesando y creando nuevo, Espere.......';
        OfflineCCWebServiceLog: Record "LSC Offl. CC Web Serv. Log";
        EPosCtrl: Codeunit "LSC POS Control Interface";
        DelPosComm: Codeunit "LSC Delivery POS Commands";
        ErrorText: Text;
        PosTrChange: Boolean;
        PosTrFound: Boolean;
        OfflineCCSetup: Record "LSC Offline Call Center Setup";
        Text056: Label 'Sent to Restaurant Sucessfully';
        Text054: Label 'Communication Error occurred.';
        DelContTEMP: Record Contact temporary;
        DelCont: Record Contact;
        DelOrderChanges: Boolean;
        test: text;
        DeliveryOrderTemp: Record "LSC Delivery Order" temporary;
        PageDeliveryTakeOrder: Page "FSN Take Order CC";
        Log: Record "FSN Change Log Transaction";
        OrderN: Code[20];
        GlobalMenuLine: Record "LSC POS Menu Line" temporary;
        HosPosStartup: Codeunit "LSC Hospitality POS Startup";
        StopPos: Boolean;
        orderNo: Code[20];
        DATA: Codeunit "LSC POS DataGrid Functions";
        POSTrans: Record "LSC POS Transaction";
        DelStreet_l: Record "LSC Delivery Street";
        Text000D: Label 'La última hora válida para la calle %1 es %2.\%3';
        AltrK: Integer;
        PostedDelOrder: Record "LSC Posted Delivery Order";
        Infocode: Record "LSC Trans. Infocode Entry";
        InfocodeTmp: Record "LSC Trans. Infocode Entry" temporary;
        RecRefTMP: RecordRef;
        PgePQ: Page "FSN PAQUETERIA";
        Barc: Record "LSC Barcodes";
        PosTransLine: Record "LSC POS Trans. Line";
        POSTransCodeunit: Codeunit "LSC POS Transaction";
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        MsgResult: Text;
        POSMenuLineTemp: Record "LSC POS Menu Line" temporary;
        Processed: Boolean;
        FSNUtility: Codeunit "FSN Utility";
        Text010: Label 'Desea crear paqueteria a la sala: %1';
        Item: Record Item;
        ItemTmp: Record Item temporary;
        ItemPaque: Code[30];
        Text011: Label 'Debe agregar primero la media de pago';
        storeSetting: Record "FSN Fasani Setup";
        PosT: Record "LSC POS Transaction";
        ReplenSales: Record "FSN Replen. Sales Adj. Line";
        ReplenSalesTemp: Record "FSN Replen. Sales Adj. Line" temporary;
    begin

        if POSMenuLine.Command = 'PAQUETERIA' then begin
            if PosT.Get(POSSESSION.GetValue('CURRORDER')) then
                if storeSetting.Get(PosT."Store No.") then
                    GlobalParametro();
            if GlobalParametroPQ.Activo then begin
                PosTransLine.Reset();
                PosTransLine.SetRange("Receipt No.", POSSESSION.GetValue('CURRORDER'));
                PosTransLine.SetRange("Entry Type", PosTransLine."Entry Type"::Item);
                PosTransLine.SetRange("Entry Status", PosTransLine."Entry Status"::" ");
                PosTransLine.SetRange(Number, GlobalParametroPQ.Valor);
                if not PosTransLine.FindFirst() then begin
                    Barc.Reset();
                    Barc.SetRange("Item No.", GlobalParametroPQ.Valor);
                    if Barc.FindFirst() then begin
                        POSTransCodeunit.PluKeyPressed(Barc."Barcode No.");
                    end;
                end else begin
                    if (POSSESSION.GetValue('Balance') in ['0.00', '0']) then begin
                        if DelOrd.Get(POSSESSION.GetValue('CURRORDER')) then begin
                            PgePQ.SETGLOBALVALUE(DelOrd);
                            PgePQ.SetRecord(DelOrd);
                            Commit();
                            if PgePQ.RunModal() = Action::OK then begin
                                If validateinfo(DelOrd) then begin
                                    IF not CONFIRM(STRSUBSTNO(Text010, DelOrd."Restaurant No.")) THEN
                                        exit;
                                end else
                                    exit;
                                IF POSSESSION.GetValue('GUIAC807') = '' then begin
                                    if ValidatePaqueteria(DelOrd) then begin
                                        RequestID := 'SENPQC807';//manda Formulario
                                        MsgResult := Format(DelOrd."General Status");
                                        XMLRequest := DelOrd."Order No.";
                                        FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);

                                        IF Log.FIND('+') THEN
                                            Log."Entry No." := Log."Entry No." + 1;
                                        if Log."Entry No." = 0 then begin
                                            Log."Entry No." := 1;
                                        end;
                                        Log."Receipt No." := DelOrd."Order No.";
                                        IF STRLEN(DelOrd."Phone No.") > 10 THEN
                                            Log."Phone No." := COPYSTR(DelOrd."Phone No.", STRLEN(DelOrd."Phone No.") - 10, 10)
                                        ELSE
                                            Log."Phone No." := DelOrd."Phone No.";
                                        Log.Date := TODAY;
                                        Log."Log Time" := TIME;
                                        Log."User ID" := USERID;
                                        Log."Staff ID" := POSSESSION.StaffID();
                                        Log."Type of Change" := Log."Type of Change"::Insertion;
                                        If Log."Type of Change" = Log."Type of Change"::Insertion then begin
                                            Log.Action := 'Paqueteria';
                                        end;
                                        Log.INSERT();
                                    end;
                                end;
                            end;
                        end;
                    end else
                        Message(Text011);
                end;
            end;
        end;


        if (POSMenuLine.Command = 'HISTORICO') then begin
            OrderN := EPosCtrl.GetDataGridKeyValue(EPosCtrl.ActiveDataGrid);
            PostedDelOrder.Reset();
            if PostedDelOrder.Get(OrderN) then begin
                Infocode.Reset();
                Infocode.SetRange("Transaction No.", PostedDelOrder."Transaction No.");
                Infocode.SetRange("Store No.", PostedDelOrder."Store No.");
                if Infocode.Find('-') then begin
                    repeat
                        InfocodeTmp.Init();
                        InfocodeTmp := Infocode;
                        InfocodeTmp.Insert();
                    until Infocode.Next() = 0;
                    COMMIT;
                    RecRefTmp.GETTABLE(InfocodeTmp);
                    POSTransaction.LookUpEx(true, 'INFO_LU2', '', RecRefTmp);
                end;
            end;
        end;

        if (POSMenuLine.Command = 'VENTAPERD') then begin
            ReplenSales.Reset();
            ReplenSales.SetFilter("Receipt No.", '<>%1', '');
            if ReplenSales.Find('-') then begin
                repeat
                    ReplenSalesTemp.Init();
                    ReplenSalesTemp := ReplenSales;
                    ReplenSalesTemp.Insert();
                until ReplenSales.Next() = 0;
                COMMIT;
                RecRefTmp.GETTABLE(ReplenSalesTemp);
                POSTransaction.LookUpEx(true, 'VEN_PERD', '', RecRefTmp);
            end;

        end;


        if POSSESSION.GetValue('PANELSTOP') = 'STOPT' then begin
            if (POSMenuLine.Command = 'SHOWPANEL') and (POSMenuLine.Parameter = POSSESSION.SalesPanelID) then begin
            end;
        end;


        if (POSMenuLine.Command = 'DEL-TAKEORDFUNC') and (POSMenuLine.Parameter = 'NEWORDERFSN') then begin
            //DelOrderM.OnTakeOrderPanelOpen;
            //DelOrderM.AfterClosingOrderTakeNew;
            EPosCtrl.HidePanel(POSSESSION.DelOpenOrdersPanelID(), true);
            Clear(DeliveryOrderTemp);
            DeliveryOrderTemp.Reset();
            PageDeliveryTakeOrder.SetPosmenuLine(POSMenuLine);
            PageDeliveryTakeOrder.SETGLOBALVALUE(DeliveryOrderTemp);
            PageDeliveryTakeOrder.RUN;
            handled := true;
        END;

        if (POSMenuLine.Command = 'DEL-TAKEORDFUNC') and (POSMenuLine.Parameter = 'EDITORDERFSN') then begin
            DelOrd.Reset();
            OrderN := EPosCtrl.GetDataGridKeyValue(EPosCtrl.ActiveDataGrid);
            ValPosTransaction(OrderN);
            IF DelOrd.Get(OrderN) then begin
                CCcontroler.SetReceipt(DelOrd."Order No.");
                PageDeliveryTakeOrder.SetPosmenuLine(POSMenuLine);
                PageDeliveryTakeOrder.SETGLOBALVALUE(DelOrd);
                PageDeliveryTakeOrder.RUN;
                EPosCtrl.HidePanel(POSSESSION.DelOpenOrdersPanelID, true);//15837
            end;
        end;
        if (POSMenuLine.Command = 'DELORDFSN') then begin
            DelOrd.Reset();
            OrderN := EPosCtrl.GetDataGridKeyValue(EPosCtrl.ActiveDataGrid);
            ValPosTransaction(OrderN);
            IF DelOrd.Get(OrderN) then begin
                CCcontroler.SetReceipt(DelOrd."Order No.");
                POSSESSION.SetValue('CURRORDER', DelOrd."Order No.");
                POSSESSION.SetValue('CLEARCURRORDER', 'true');
                POSTrans.reset;
                if POSTrans.Get(DelOrd."Order No.") then
                    POSSESSION.SetTempStoreTerminal(POSTrans."Store No.", POSTrans."POS Terminal No.", POSTrans."Sales Type");
                HosPosStartup.DirectEdit(true);
                /*PageDeliveryTakeOrder.SetPosmenuLine(POSMenuLine);
                PageDeliveryTakeOrder.SETGLOBALVALUE(DelOrd);
                PageDeliveryTakeOrder.RUN;*/
            end;
        end;


        PosTrChange := false;
        PosTrFound := true;
        if POSMenuLine.Command = 'LOGON'
        then begin
            Clear(ErrorValidation);
        end;
        //Confirm order
        if (POSMenuLine.Command = 'DEL-TAKEORDFUNC') and
        (POSMenuLine.Parameter = 'ORDER-CLOSEPANEL') then begin
            RetailSetupBK.Get;
            if not RetailSetupBK."FSN Is Local Receipt" or (RetailSetupBK."FSN Last Slipt No." = '') then begin
                handled := true;
                POSGUI.PosMessage(StrSubstNo(lTxt0, RetailSetupBK.FieldCaption("FSN Is Local Receipt"), RetailSetupBK.TableCaption));
                exit;
            end;

            if Evaluate(AltrK, POSSESSION.GetValue('#FSN-ALTERKEY')) then;
            DelStreet_l.RESET;
            DelStreet_l.SETRANGE(DelStreet_l."FSN Alter Key", AltrK);
            IF DelStreet_l.FINDFIRST THEN begin
                IF (DelStreet_l."FSN Last Valid Time" <> 0T) AND (POSSESSION.GetValue('DEL-PickupTime') > format(DelStreet_l."FSN Last Valid Time")) THEN BEGIN
                    Error(STRSUBSTNO(Text000D, DelStreet_l."Street Name", FORMAT(DelStreet_l."FSN Last Valid Time"), DelStreet_l.Restriction));
                    exit;
                END;
            end;

            if POSSESSION.GetValue('CURRORDER') = '' then
                exit;

            MGTOrderClosePanelPressed(POSSESSION.GetValue('CURRORDER'), handled, ErrorValidation);
            if handled and (ErrorValidation <> '') then
                POSGUI.PosMessage(ErrorValidation);
        end;

        //Finalizar y crear nuevo
        if (POSMenuLine.Command = 'DEL-TAKEORDFUNC') and (POSMenuLine.Parameter in ['ORDER-CONFIRMNEW']) then begin//28981
            ErrorText := 'ERROR';
            Clear(DelContTEMP);
            DelContTEMP.DeleteAll();
            RetailSetupBK.Get;
            if not RetailSetupBK."FSN Is Local Receipt" or (RetailSetupBK."FSN Last Slipt No." = '') then begin
                handled := true;
                POSGUI.PosMessage(StrSubstNo(lTxt0, RetailSetupBK.FieldCaption("FSN Is Local Receipt"), RetailSetupBK.TableCaption));
                exit;
            end;

            if POSSESSION.GetValue('CURRORDER') = '' then
                exit;

            MGTOrderClosePanelPressed(POSSESSION.GetValue('CURRORDER'), handled, ErrorValidation);
            if handled and (ErrorValidation <> '') then begin
                POSGUI.PosMessage(ErrorValidation);
            end else begin
                Windows.OPEN(LoadingText);
                Windows.UPDATE;
                DelOrd.Reset();
                if DelOrd.Get(POSSESSION.GetValue('CURRORDER')) then begin

                    DelOrderChanges := DelOrderM.DelOrderChangesMade(PosTrChange, POSSESSION.GetValue('CURRORDER'), PosTrFound);
                    if DelOrderChanges then begin
                        DelCont.Reset();
                        if DelCont.get(DelOrd."Phone No.") then begin
                            DelContTEMP.Init();
                            DelContTEMP := DelCont;
                            if DelContTEMP.Insert() then begin
                                DelContTEMP."LSC Next Order Selection" := DelOrd."Order Type Option";
                                DelContTEMP."LSC Next Order Restaurant" := DelOrd."Restaurant No.";
                                DelContTEMP."LSC Next Order Date" := DelOrd."Order Date";
                                DelContTEMP."LSC Next Order Time" := DelOrd."Contact Pickup Time";
                                DelContTEMP."LSC Next Delivery Tender" := DelOrd."Tender Type";
                                DelContTEMP."LSC Pre-Order Print DateTime" := DelOrd."Pre-Order Print DateTime";
                                DelContTEMP."LSC Next Estimated Prod. Time" := DelOrd."Estimated Prod. Time (Min.)";
                                DelContTEMP.Modify;
                                ErrorText := '';
                            end;
                            if ErrorText = '' then
                                DelOrderM.UpdateOrder(POSSESSION.GetValue('CURRORDER'), DelContTEMP, false, false, true);
                        end;
                    end;

                    if (DelOrd."Call Cent. Web Service Status" in [DelOrd."Call Cent. Web Service Status"::"New-Not Sent"
                    , DelOrd."Call Cent. Web Service Status"::"New-Not Confirmed", DelOrd."Call Cent. Web Service Status"::"Changed-Not Sent"]) then
                        ErrorText := '';

                    if ErrorText = '' then begin
                        if DelPosComm.SendDeliveryOrder(DelOrd, DelOrderChanges, ErrorText) then begin
                            OfflineCCSetup.Get;
                            DelOrd.Reset();
                            DelOrd.Get(POSSESSION.GetValue('CURRORDER'));

                            if DelOrd."Call Cent. Web Service Status" in
                              [DelOrd."Call Cent. Web Service Status"::"New-Not Sent", DelOrd."Call Cent. Web Service Status"::"New-Not Confirmed"] then
                                DelOrd."Call Cent. Web Service Status" := DelOrd."Call Cent. Web Service Status"::"New-Sent";

                            if DelOrd."Call Cent. Web Service Status" = DelOrd."Call Cent. Web Service Status"::"Changed-Not Sent" then
                                DelOrd."Call Cent. Web Service Status" := DelOrd."Call Cent. Web Service Status"::"Changed-Sent";

                            DelOrd."General Status" := DelOrd."General Status"::"In Process";
                            if (DelOrd."Assigned to Driver") or (DelOrd."Process Status" = DelOrd."Process Status"::Finished) then
                                DelOrd."General Status" := DelOrd."General Status"::Confirmed;

                            DelOrd.Modify();
                            Commit;

                            if OfflineCCSetup."Show Msg. on Successful Send" then
                                Message(Text056);

                        end else begin
                            DelOrd.Reset();
                            if DelOrd.Get(POSSESSION.GetValue('CURRORDER')) then begin
                                if DelOrd."Call Cent. Web Service Status" = DelOrd."Call Cent. Web Service Status"::"New-Not Confirmed" then
                                    DelOrd."Call Cent. Web Service Status" := DelOrd."Call Cent. Web Service Status"::"New-Not Sent";

                                DelOrd."General Status" := DelOrd."General Status"::ERROR;
                                DelOrd.Modify();
                                Commit();
                            end;
                            Commit;

                            Message(Text054);
                        end;
                    end;
                    if ErrorText = '' then begin
                        DeliveryOrderManagement.LoadContext(FALSE);
                        DeliveryOrderManagement.InitSelRestKey(0);
                        DeliveryOrderManagement.OrderCancelNewPressedFinalSteps;
                        POSMenuLineV.Reset();
                        POSMenuLineV.SetCurrentKey("Profile ID", "Menu ID", "Key No.");
                        POSMenuLineV.SetRange(POSMenuLineV."Profile ID", '#FSN-CC');
                        POSMenuLineV.SetRange(POSMenuLineV."Menu ID", '#DEL-OPENORDERSMENU');
                        POSMenuLineV.SetRange(POSMenuLineV."Key No.", 2);
                        if POSMenuLineV.FindFirst() then begin
                            Commit();
                            IF DelPanelUtility.RUN(POSMenuLineV) THEN BEGIN
                                DelPanelUtility.HandleDelOpenOrdersPanel;
                                DeliveryOrderManagement.ProcessInputOnSelectingOrderOnOrderTaking;
                            END;
                        end;
                    end else
                        Commit();
                end;
                Windows.Close();
            end;
        end;

        //Cancelar y crear nuevo 
        if (POSMenuLine.Command = 'DEL-TAKEORDFUNC') and
           ((POSMenuLine.Parameter in ['ORDER-CANCEL', 'ORDER-CANCELNEW'])) then begin

            IF DelOrd.GET(POSSESSION.GetValue('CURRORDER')) AND (NOT (DelOrd."Call Cent. Web Service Status" IN [DelOrd."Call Cent. Web Service Status"::"New-Not Sent",
                                                            DelOrd."Call Cent. Web Service Status"::"New-Not Confirmed", DelOrd."Call Cent. Web Service Status"::"New-Sent"])) THEN BEGIN
                IF Log.FIND('+') THEN
                    Log."Entry No." := Log."Entry No." + 1;
                if Log."Entry No." = 0 then begin
                    Log."Entry No." := 1;
                end;
                Log."Receipt No." := DelOrd."Order No.";
                IF STRLEN(DelOrd."Phone No.") > 10 THEN
                    Log."Phone No." := COPYSTR(DelOrd."Phone No.", STRLEN(DelOrd."Phone No.") - 10, 10)
                ELSE
                    Log."Phone No." := DelOrd."Phone No.";
                Log.Date := TODAY;
                Log."Log Time" := TIME;
                Log."User ID" := USERID;
                Log."Staff ID" := POSSESSION.StaffID();
                Log."Type of Change" := Log."Type of Change"::Deletion;
                If Log."Type of Change" = Log."Type of Change"::Deletion then begin
                    Log.Action := 'Cancelar';
                end;
                Log.INSERT();
            END;

            ExitPanel := false;
            Phone := '';
            if (DelOrd."Call Cent. Web Service Status" in [DelOrd."Call Cent. Web Service Status"::"New-Not Sent",
             DelOrd."Call Cent. Web Service Status"::"New-Not Confirmed", DelOrd."Call Cent. Web Service Status"::"New-Sent"]) then begin
                Phone := DelOrd."Phone No.";
                ExitPanel := true;
            end;

            if ExitPanel then
                ExitPanel := POSGUI.PosConfirm(lTxt1, true);

            if ExitPanel then begin
                //handled := true;
                if (Phone <> '') and (POSMenuLine.Parameter = 'ORDER-CANCELNEW') then begin
                    DelPanelUtility.GetOpenOrderResponse(SelOrderID, PanelResponse);
                    case PanelResponse of
                        1:
                            begin
                                IF POSSESSION.GetValue('CURRORDER') <> '' THEN
                                    OrderCancelPressed(POSSESSION.GetValue('CURRORDER'));
                                //DPCProcessOrderCancel(POSSESSION.GetValue('CURRORDER'));
                                DeliveryOrderManagement.ProcessInputOnSelectingOrderOnOrderTaking;
                            end;
                        2:
                            begin
                                POSMenuLineV.Reset();
                                POSMenuLineV.SetCurrentKey("Profile ID", "Menu ID", "Key No.");
                                POSMenuLineV.SetRange(POSMenuLineV."Profile ID", '#FSN-CC');
                                POSMenuLineV.SetRange(POSMenuLineV."Menu ID", '#DEL-OPENORDERSMENU');
                                POSMenuLineV.SetRange(POSMenuLineV."Key No.", 2);
                                if POSMenuLineV.FindFirst() then begin
                                    Commit();
                                    IF DelPanelUtility.RUN(POSMenuLineV) THEN BEGIN
                                        DelPanelUtility.HandleDelOpenOrdersPanel;
                                        IF POSSESSION.GetValue('CURRORDER') <> '' THEN
                                            OrderCancelPressed(POSSESSION.GetValue('CURRORDER'));
                                        //DPCProcessOrderCancel(POSSESSION.GetValue('CURRORDER'));
                                        DeliveryOrderManagement.ProcessInputOnSelectingOrderOnOrderTaking;
                                    END;
                                end;
                            end;
                    end;
                end;
                if (POSMenuLine.Parameter = 'ORDER-CANCEL') then begin
                    IF POSSESSION.GetValue('CURRORDER') <> '' THEN
                        OrderCancelPressed(POSSESSION.GetValue('CURRORDER'));
                    //DPCProcessOrderCancel(POSSESSION.GetValue('CURRORDER'));
                    handled := true;
                    EPOSControlInterface.HidePanel('#DEL-ORDER', false);
                end;
            end else begin
                Message(STRSUBSTNO(lTxt3, DelOrd."Call Cent. Web Service Status"));
                handled := true;
                exit;
            end;
        end;

        IF (POSMenuLine.Command = 'DEL-TAKEORDFUNC') AND (POSMenuLine.Parameter = 'DEL-GET-ORDERS') then begin
            DelOrd.Reset();
            if DelOrd.Get(POSSESSION.GetValue('CURRORDER')) then begin
                DelPanelUtility.RunDelOpenOrdersPanel(DelOrd, POSSESSION.DelOpenOrdersPanelID);
            end;

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
        if POSTerminal.Get(POSSESSION.TerminalNo()) then
            if (MenuLine.Command = 'HOSP-OPEN-POS-DIR') and (POSSESSION.GetValue('CURRORDER') = 'NEWSALE') then
                POSSESSION.SetValue('SALESTYPE', POSTerminal."Default Sales Type");

    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Controller", 'OnLookupResult', '', true, true)]
    local procedure "LSC POS Controller_OnLookupResult"
    (
        LookupID: Text;
        FilterText: Text;
        resultOK: Boolean;
        var processed: Boolean
    )
    var
        txtResult: Text[250];
        streetKey: Text[30];
        postCode: Code[20];
        iText: Text[50];
        i: Integer;
        recRef: RecordRef;
        DelTmp1: Record "LSC Delivery Order" temporary;
        DelStreetTmp: Record "LSC Delivery Street" temporary;
        DelStreetTmp2: Record "LSC Delivery Street" temporary;
        Store_l: Record "LSC Store";
        CallAssigmentStore: Record "LSC CC POS Term. Assignm.";
        POSTransLineCU: Codeunit "LSC POS Trans. Lines";
    begin
        Clear(i);
        clear(iText);
        clear(streetKey);
        clear(postCode);

        if (LookupID = '#FSN-DEL-STREET') then begin
            if resultOK then begin
                txtResult := EPOSControlInterface.GetLookupKeyValue(LookupID);
                streetKey := CopyStr(txtResult, 1, StrPos(txtResult, ';') - 1);
                txtResult := CopyStr(txtResult, StrPos(txtResult, ';') + 1);
                if StrPos(txtResult, ';') > 0 then begin
                    iText := CopyStr(txtResult, StrPos(txtResult, ';') + 1);
                    txtResult := CopyStr(txtResult, StrPos(txtResult, ';') + 1);
                end;
                if iText <> '' then
                    if Evaluate(i, iText) then;

                if (StrPos(txtResult, ';') = 0) and (txtResult <> '') then begin
                    postCode := txtResult;
                end;

                DeliveryStreetBK.Reset();
                DeliveryStreetBK.SetRange("Street Name", streetKey);
                DeliveryStreetBK.SetRange("Post Code", postCode);
                if i <> 0 then
                    DeliveryStreetBK.SetRange("Number from", i);
                if not DeliveryStreetBK.FindFirst() then
                    DeliveryStreetBK.SetRange("Number from");
                if DeliveryStreetBK.Find('-') then begin
                    if DeliveryStreetBK."FSN Alter Key" <> 0 then begin

                        DeliveryOrderManagement.HospAddress(('1 ' + streetKey));
                        DeliveryOrderManagement.OnValidateStreetOnClose('1');
                        recRef.GetTable(DelTmp1);
                        Commit();
                        EPOSControlInterface.GetRecordZoomData(recRef, '#DEL-ORDER-DETZOOM');

                        recRef.Field(DelTmp1.FieldNo("FSN Street Name")).Value := DeliveryStreetBK."FSN Street Name";
                        recRef.Field(DelTmp1.FieldNo("FSN Alter Key")).Value := DeliveryStreetBK."FSN Alter Key";
                        EPOSControlInterface.ShowRecordZoom(recRef, '#DEL-ORDER-DETZOOM', '#DEL-ORDERSDETZOOM', true);
                    end;

                end;
            end;
            processed := true;
        end;
        if (LookupID = '#DEL-ORDER-EXT') then begin
            RetailUserBK.Get(UserId);
            if resultOK then begin
                txtResult := EPOSControlInterface.GetLookupKeyValue(LookupID);
                if Store_l.Get(txtResult) then begin
                    if CCPOSTermBK.Get(RetailUserBK."Store No.", Store_l."No.") and (CCPOSTermBK."Rest. POS Terminal" <> '') then
                        EXOCreateOrderOnDemand(Store_l."No.")
                    else
                        POSGUI.PosMessage(StrSubstNo(Text000, Store_l."No.", Store_l.Name));
                end
            end;
            processed := true;
        end;
        if (LookupID = '#DELCHANGESTORE') then begin
            if resultOK then begin
                if Store_l.Get(POSGUI.GetLookupKeyValue(LookupID)) then begin
                    POSTransLineCU.RefreshLastCount();

                    POSSESSION.SetValue('#_CHANGESTORE', Store_l."No.");
                end;
            end;
            processed := true;
        end;
        if (LookupID = 'SALES_CHANNEL') then begin
            if resultOK then begin
                FSNCallCenterControl.ChannelSelectedPressed();
            end;
            processed := true;
        end;
    end;


    [EventSubscriber(ObjectType::Table, Database::"LSC Delivery Order", 'OnAfterInsertEvent', '', true, true)]
    local procedure "LSC Delivery Order_OnAfterInsertEvent"
    (
        var Rec: Record "LSC Delivery Order";
        RunTrigger: Boolean
    )
    var
        DelStreet_l: Record "LSC Delivery Street";
        DelConAdd_l: Record "LSC Delivery Contact Address";
        txtResult: Text[250];
        streetKey: text[100];
        iText: Text[100];
        i: Integer;
        postCode: Text[100];
    begin
        if Rec.IsTemporary then begin

            if StrPos(txtResult, ';') > 0 then begin
                streetKey := CopyStr(txtResult, 1, StrPos(txtResult, ';') - 1);
                txtResult := CopyStr(txtResult, StrPos(txtResult, ';') + 1);
                if StrPos(txtResult, ';') > 0 then begin
                    iText := CopyStr(txtResult, StrPos(txtResult, ';') + 1);
                    txtResult := CopyStr(txtResult, StrPos(txtResult, ';') + 1);
                end;
                if iText <> '' then
                    if Evaluate(i, iText) then;

                if (StrPos(txtResult, ';') = 0) and (txtResult <> '') then begin
                    postCode := txtResult;
                end;
                if streetKey <> '' then
                    Rec.Address := '1 ' + streetKey;
                if postCode <> '' then
                    Rec.validate("Post Code", postCode);
            end;

            if (CopyStr(Rec.Address, 1, 2) = '1 ') and (StrLen(Rec.Address) > 4) then begin
                DelStreet_l.Reset();
                DelStreet_l.SetRange("Street Name", CopyStr(Rec.Address, 3, 30));
                DelStreet_l.SetRange("Number from", 1);
                if Rec."Post Code" <> '' then
                    DelStreet_l.SetRange("Post Code", Rec."Post Code");
                if DelStreet_l.FindFirst() then begin
                    Rec."FSN Alter Key" := DelStreet_l."FSN Alter Key";
                    Rec."FSN Street Name" := DelStreet_l."FSN Street Name";
                    DelConAdd_l.Reset();
                    DelConAdd_l.SetRange("Phone No.", Rec."Phone No.");
                    if DelConAdd_l.Find('-') then
                        repeat
                            if STRLEN(DelConAdd_l."Street Name") > 30 then begin
                                DelConAdd_l."Street Name" := DelStreet_l."Street Name";
                                DelConAdd_l.Modify();
                                Commit();
                            end;

                        until DelConAdd_l.Next() = 0;
                end;
            end;
        end;
    end;

    [EventSubscriber(ObjectType::Table, Database::"LSC POS Transaction", 'OnBeforeInsertEvent', '', true, true)]
    local procedure "LSC POS Transaction_OnBeforeInsertEvent"
    (
        var Rec: Record "LSC POS Transaction";
        RunTrigger: Boolean
    )
    var
        RetailSetup_l: Record "LSC Retail Setup";
        NoSeriesMgt: Codeunit NoSeriesManagement;
    begin
        if not Rec.IsTemporary then begin
            RetailSetup_l.Get();
            if NOT (POSSESSION.GetValue('FSNRECEIPTVALIDATECC') = 'TRUE') then BEGIN
                if RetailSetup_l."FSN Is Local Receipt" and (RetailSetup_l."FSN Last Slipt No." <> '') then begin
                    Rec."Receipt No." := NoSeriesMgt.GetNextNo('CALLCERIE', Today, true);
                    //Rec."Receipt No." := IncStr(RetailSetup_l."FSN Last Slipt No.");
                    /*RetailSetup_l."FSN Last Slipt No." := Rec."Receipt No.";
                    RetailSetup_l.Modify();*/
                    /*if POSSESSION.GetValue('FSNRECEIPTVALIDATECC') = 'TRUE' then BEGIN
                        POSSESSION.SetValue('FSNRECEIPTPOSCC', Rec."Receipt No.");
                        POSSESSION.SetValue('FSNRECEIPTVALIDATECC', 'FALSE');
                    END;*/
                end;
            END;
        end;
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
        p: codeunit "LSC Data Table SourceExpr Util";
        delOrder: Record "LSC Delivery Order" temporary;
        DelPosTransaction: Record "LSC POS Transaction";
    begin
        if pSourceExprID = 'INV_ITEM' then begin
            returnTxt := GetInventoryUM(pRecRef);
            Handled := true;
        end;
        if pSourceExprID = 'HO-STRLINK' then begin
            returnTxt := FSNDeliveryStoreLink.GetStoreLinksSuggest(pRecRef);
            Handled := true;
        end;

        if pSourceExprID = 'GETAMOUNT' then begin
            pRecRef.SetTable(delOrder);
            IF DelPosTransaction.Get(delOrder."Order No.") THEN begin
                DelPosTransaction.CalcFields("Gross Amount");
                returnTxt := Format(DelPosTransaction."Gross Amount");
                Handled := true;
            end;
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS View", 'OnAfterLoginEx', '', true, true)]
    local procedure "LSC POS View_OnAfterLoginEx"()
    var
        Comutator: Record "FSN Commutator";
    begin
        IF POSSESSION.GetValue('NEWLOGOFFCTI') = 'TRUE' THEN BEGIN
            if POSSESSION.StaffID() <> '' THEN BEGIN
                Comutator.Reset();
                Comutator.SetRange(StaffID, POSSESSION.StaffID());
                IF Comutator.Find('-') THEN begin
                    repeat
                        Comutator.StaffID := '';
                        Comutator.Date := 0D;
                        Comutator.Modify();
                        Commit();
                    until Comutator.Next() = 0;
                end;
            END;
            POSSESSION.SetValue('NEWLOGOFFCTI', 'FALSE');
        END;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Controller", 'OnPOSEvent', '', true, true)]
    local procedure "LSC POS Controller_OnPOSEvent"
        (
        var PosEvent: Codeunit "LSC POS Event";
        var SuppressEvent: Boolean
        )
    var
        POSLines: Codeunit "LSC POS Trans. Lines";
        RecRef: RecordRef;
        POSLine_l: Record "LSC POS Trans. Line";
        POSDataTableColumn: Record "LSC POS Data Table Columns";
        EPosCtrl: Codeunit "LSC POS Control Interface";
        DelOrd: Record "LSC Delivery Order";
        OrderN: Code[20];
        Parameter: Record "FSN Parameter";
        HosPosStartup: Codeunit "LSC Hospitality POS Startup";
        POSTrans: Record "LSC POS Transaction";
        userRetail: Record "LSC Retail User";
        FSNCheckPayment: Codeunit "FSN Check Payments POS";
        TenderTypeSetup: Record "LSC Tender Type Setup";
        RetailSetup_l: Record "LSC Retail Setup";
        DelordeTm: Record "LSC Delivery Order" temporary;
        item: Record Item;
    begin
        RetailSetup_l.Get();

        if PosEvent.ActivePanel = '#POS' THEN
            if PosEvent.EventType in [
                Enum::"LSC POS Event Type"::DATAROWDOUBLECLICK
            ] then begin
                POSLines.GetCurrentLine(POSLine_l);
                if StrPos(PosEvent.Sender, '#JOURNALHOMIN') > 0 then
                    if (POSLine_l."Entry Type" = POSLine_l."Entry Type"::Item) AND
                        (POSLine_l."Entry Status" = POSLine_l."Entry Status"::" ") THEN begin


                        POSDataTableColumn.Reset();
                        POSDataTableColumn.SetRange(POSDataTableColumn."Data Table ID", '#JOURNALHOMIN');
                        POSDataTableColumn.SetRange(POSDataTableColumn."Table No.", Database::"LSC POS Trans. Line");
                        POSDataTableColumn.SetRange(POSDataTableColumn."Column No.", PosEvent.IntData2() + 1);
                        if POSDataTableColumn.FindFirst() then
                            if POSDataTableColumn."Source Expr. ID" = 'INV_ITEM' then begin
                                Store.Reset();
                                POSTransaction.LookUpEx(true, '#DELCHANGESTORE', '', RecRef);
                                SuppressEvent := true;
                            end;
                    end;

                if RetailSetup_l."FSN Is Local Receipt" and (RetailSetup_l."FSN Last Slipt No." <> '') then begin
                    //Ingresa el monto de cambio de efectivo
                    if (POSLine_l."Entry Type" = POSLine_l."Entry Type"::Payment) AND
                                    (POSLine_l."Entry Status" = POSLine_l."Entry Status"::" ") THEN begin
                        if TenderTypeSetup.Get(POSLine_l.Number) and Not (TenderTypeSetup."FSN Function in CC" = TenderTypeSetup."FSN Function in CC"::Card) then
                            FSNCheckPayment.InsertDelChangePayment(POSLine_l."Receipt No.", POSLine_l);
                    END;

                    if PosEvent.EventType in [Enum::"LSC POS Event Type"::BUTTONPRESS] then begin
                        SuppressEvent := ValidateButtonDoubleClicPressed(PosEvent.StrData(), PosEvent.StrData2());
                    END;

                    if (PosEvent.ActivePanel = '#LOGIN') and (POSSESSION.StaffID() = '') then
                        POSSESSION.SetValue('NEWLOGOFFCTI', 'TRUE');

                    if PosEvent.ActivePanel = '#POS' THEN
                        CCcontroler.SetReceipt(POSSESSION.GetValue('CURRORDER'));
                end;
            end;

        if RetailSetup_l."FSN Is Local Receipt" and (RetailSetup_l."FSN Last Slipt No." <> '') then begin
            if PosEvent.ActivePanel = '#DEL-OPENORDERS' THEN BEGIN
                if PosEvent.EventType in [
                        Enum::"LSC POS Event Type"::DATAROWDOUBLECLICK] then begin
                    DelOrd.Reset();
                    OrderN := EPosCtrl.GetDataGridKeyValue(EPosCtrl.ActiveDataGrid);
                    ValPosTransaction(OrderN);
                    IF DelOrd.Get(OrderN) then begin
                        if Parameter.Get('RUN_DELPROCESSFSN') then begin
                            if Parameter.Activo then begin
                                CCcontroler.SetReceipt(DelOrd."Order No.");
                                POSSESSION.SetValue('RUN_DELIVERY', '');
                                POSSESSION.SetValue('RUN_DELPROCESSFSN', 'TRUE');
                                POSSESSION.SetValue('CURRORDER', DelOrd."Order No.");
                                POSSESSION.SetValue('CLEARCURRORDER', 'true');
                                PageDeliveryTakeOrder.VisiblePosTransLine(true);
                                PageDeliveryTakeOrder.SETGLOBALVALUE(DelOrd);
                                PageDeliveryTakeOrder.LookupMode(true);
                                SuppressEvent := true;
                                PageDeliveryTakeOrder.RUN;
                                EPosCtrl.HidePanel(POSSESSION.DelOpenOrdersPanelID, true);
                            end else
                                POSSESSION.SetValue('RUN_DELPROCESSFSN', 'FALSE');
                        end else
                            POSSESSION.SetValue('RUN_DELPROCESSFSN', 'FALSE');
                    end;
                END;
            END;

            if PosEvent.ActivePanel = '#OFFLINE' THEN BEGIN
                if PosEvent.EventType in [
                    Enum::"LSC POS Event Type"::DATAROWDOUBLECLICK
                ] then begin
                    DelOrd.Reset();
                    OrderN := EPosCtrl.GetDataGridKeyValue(EPosCtrl.ActiveDataGrid);
                    ValPosTransaction(OrderN);
                    IF DelOrd.Get(OrderN) then begin
                        if Parameter.Get('RUN_DELPROCESSFSN') then begin
                            if Parameter.Activo then begin
                                CCcontroler.SetReceipt(DelOrd."Order No.");
                                POSSESSION.SetValue('RUN_DELIVERY', '');
                                POSSESSION.SetValue('RUN_DELPROCESSFSN', 'TRUE');
                                POSSESSION.SetValue('CURRORDER', DelOrd."Order No.");
                                POSSESSION.SetValue('CLEARCURRORDER', 'true');
                                PageDeliveryTakeOrder.VisiblePosTransLine(true);
                                PageDeliveryTakeOrder.SETGLOBALVALUE(DelOrd);
                                PageDeliveryTakeOrder.LookupMode(true);
                                PageDeliveryTakeOrder.RUN;
                                //HosPosStartup.DirectEdit(true);
                            end else
                                POSSESSION.SetValue('RUN_DELPROCESSFSN', 'FALSE');
                        end else begin
                            POSSESSION.SetValue('RUN_DELPROCESSFSN', 'FALSE');
                            SuppressEvent := true;
                        end;
                    end;
                end;
            END;
        end;
    end;

    /*[EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Controller", 'OnPOSEvent', '', true, true)]
    local procedure "LSC POS Controller_OnPOSEvent"
        (
        var PosEvent: Codeunit "LSC POS Event";
        var SuppressEvent: Boolean
        )
    var
        POSLines: Codeunit "LSC POS Trans. Lines";
        RecRef: RecordRef;
        POSLine_l: Record "LSC POS Trans. Line";
        POSDataTableColumn: Record "LSC POS Data Table Columns";
        EPosCtrl: Codeunit "LSC POS Control Interface";
        DelOrd: Record "LSC Delivery Order";
        OrderN: Code[20];
        Parameter: Record "FSN Parameter";
        HosPosStartup: Codeunit "LSC Hospitality POS Startup";
        POSTrans: Record "LSC POS Transaction";
        userRetail: Record "LSC Retail User";
        FSNCheckPayment: Codeunit "FSN Check Payments POS";
        TenderTypeSetup: Record "LSC Tender Type Setup";
        RetailSetup_l: Record "LSC Retail Setup";
        DelordeTm: Record "LSC Delivery Order" temporary;
        item: Record Item;
    begin
        RetailSetup_l.Get();

        if PosEvent.ActivePanel = '#POS' THEN
            if PosEvent.EventType in [
                Enum::"LSC POS Event Type"::DATAROWDOUBLECLICK
            ] then begin
                POSLines.GetCurrentLine(POSLine_l);
                if StrPos(PosEvent.Sender, '#JOURNALHOMIN') > 0 then
                    if (POSLine_l."Entry Type" = POSLine_l."Entry Type"::Item) AND
                        (POSLine_l."Entry Status" = POSLine_l."Entry Status"::" ") THEN begin

                        POSDataTableColumn.Reset();
                        POSDataTableColumn.SetRange(POSDataTableColumn."Data Table ID", '#JOURNALHOMIN');
                        POSDataTableColumn.SetRange(POSDataTableColumn."Table No.", Database::"LSC POS Trans. Line");
                        POSDataTableColumn.SetRange(POSDataTableColumn."Column No.", PosEvent.IntData2() + 1);
                        if POSDataTableColumn.FindFirst() then
                            if POSDataTableColumn."Source Expr. ID" = 'INV_ITEM' then begin
                                Store.Reset();
                                POSTransaction.LookUpEx(true, '#DELCHANGESTORE', '', RecRef);
                                SuppressEvent := true;
                            end;
                    end;
            end;
        if RetailSetup_l."FSN Is Local Receipt" and (RetailSetup_l."FSN Last Slipt No." <> '') then begin
            if (POSLine_l."Entry Type" = POSLine_l."Entry Type"::Payment) AND
                                                       (POSLine_l."Entry Status" = POSLine_l."Entry Status"::" ") THEN begin
                if TenderTypeSetup.Get(POSLine_l.Number) and Not (TenderTypeSetup."FSN Function in CC" = TenderTypeSetup."FSN Function in CC"::Card) then
                    FSNCheckPayment.InsertDelChangePayment(POSLine_l."Receipt No.", POSLine_l);

                if PosEvent.EventType in [Enum::"LSC POS Event Type"::BUTTONPRESS] then begin
                    SuppressEvent := ValidateButtonDoubleClicPressed(PosEvent.StrData(), PosEvent.StrData2());
                END;

                if (PosEvent.ActivePanel = '#LOGIN') and (POSSESSION.StaffID() = '') then
                    POSSESSION.SetValue('NEWLOGOFFCTI', 'TRUE');

                if PosEvent.ActivePanel = '#POS' THEN
                    CCcontroler.SetReceipt(POSSESSION.GetValue('CURRORDER'));
            end;
        end;

        if RetailSetup_l."FSN Is Local Receipt" and (RetailSetup_l."FSN Last Slipt No." <> '') then begin

            if PosEvent.ActivePanel = '#OFFLINE' THEN BEGIN
                if PosEvent.EventType in [
                                 Enum::"LSC POS Event Type"::DATAROWDOUBLECLICK
                                 ] then begin
                    DelOrd.Reset();
                    OrderN := EPosCtrl.GetDataGridKeyValue(EPosCtrl.ActiveDataGrid);
                    ValPosTransaction(OrderN);
                    IF DelOrd.Get(OrderN) then begin
                        if Parameter.Get('RUN_DELPROCESSFSN') then begin
                            if Parameter.Activo then begin
                                CCcontroler.SetReceipt(DelOrd."Order No.");
                                POSSESSION.SetValue('RUN_DELIVERY', '');
                                POSSESSION.SetValue('RUN_DELPROCESSFSN', 'TRUE');
                                POSSESSION.SetValue('CURRORDER', DelOrd."Order No.");
                                POSSESSION.SetValue('CLEARCURRORDER', 'true');
                                PageDeliveryTakeOrder.VisiblePosTransLine(true);
                                PageDeliveryTakeOrder.SETGLOBALVALUE(DelOrd);
                                PageDeliveryTakeOrder.LookupMode(true);
                                PageDeliveryTakeOrder.RUN;
                            end else
                                POSSESSION.SetValue('RUN_DELPROCESSFSN', 'FALSE');
                        end else begin
                            POSSESSION.SetValue('RUN_DELPROCESSFSN', 'FALSE');
                            SuppressEvent := true;
                        end;
                    end;
                end;
                if PosEvent.ActivePanel = '#DEL-OPENORDERS' THEN BEGIN
                    if PosEvent.EventType in [
                        Enum::"LSC POS Event Type"::DATAROWDOUBLECLICK] then begin
                        DelOrd.Reset();
                        OrderN := EPosCtrl.GetDataGridKeyValue(EPosCtrl.ActiveDataGrid);
                        ValPosTransaction(OrderN);
                        IF DelOrd.Get(OrderN) then begin
                            if Parameter.Get('RUN_DELPROCESSFSN') then begin
                                if Parameter.Activo then begin
                                    CCcontroler.SetReceipt(DelOrd."Order No.");
                                    POSSESSION.SetValue('RUN_DELIVERY', '');
                                    POSSESSION.SetValue('RUN_DELPROCESSFSN', 'TRUE');
                                    POSSESSION.SetValue('CURRORDER', DelOrd."Order No.");
                                    POSSESSION.SetValue('CLEARCURRORDER', 'true');
                                    PageDeliveryTakeOrder.VisiblePosTransLine(true);
                                    PageDeliveryTakeOrder.SETGLOBALVALUE(DelOrd);
                                    PageDeliveryTakeOrder.LookupMode(true);
                                    SuppressEvent := true;
                                    PageDeliveryTakeOrder.RUN;
                                end else
                                    POSSESSION.SetValue('RUN_DELPROCESSFSN', 'FALSE');
                            end else
                                POSSESSION.SetValue('RUN_DELPROCESSFSN', 'FALSE');
                        end;

                    END;
                end;
            END;
        end;
    end;*/

    procedure ValidateButtonDoubleClicPressed(CommandV: Code[20]; ParameterV: Text[100]): Boolean
    var
        counter: Integer;
        FSNParameter: Record "FSN Parameter";
        TEXTV000: Label 'No es permitido más de un Clic';
    begin
        FSNParameter.SetCurrentKey(Grupo, Codigo);
        FSNParameter.SetRange(Grupo, 'DOUBLECLIC');
        FSNParameter.SetRange(Codigo, CommandV);
        FSNParameter.SetRange(Valor, ParameterV);
        IF FSNParameter.FindFirst() then begin
            if FSNParameter.Activo then begin
                if CommandV = POSSESSION.GetValue('ONBUTTONPRESSEDFSN') THEN BEGIN
                    IF Evaluate(counter, POSSESSION.GetValue('COUNTERCLICFSN')) THEN begin
                        counter += 1;
                        case counter of
                            1:
                                begin
                                    POSSESSION.SetValue('COUNTERCLICFSN', FORMAT(counter));
                                    exit(false);
                                end;
                            2:
                                begin
                                    counter := 0;
                                    POSSESSION.SetValue('ONBUTTONPRESSEDFSN', '');
                                    POSSESSION.SetValue('COUNTERCLICFSN', FORMAT(counter));
                                    //Message(TEXTV000);
                                    exit(true);
                                end;
                        end;
                    end;
                END ELSE begin
                    counter := 1;
                    POSSESSION.SetValue('ONBUTTONPRESSEDFSN', CommandV);
                    POSSESSION.SetValue('COUNTERCLICFSN', FORMAT(counter));
                end;
            end;
        end else begin
            POSSESSION.SetValue('ONBUTTONPRESSEDFSN', '');
            POSSESSION.SetValue('COUNTERCLICFSN', '');
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Controller", 'OnPOSCommand', '', true, true)]
    local procedure "LSC POS Controller_OnPOSCommand"
    (
        var ActivePanel: Record "LSC POS Panel";
        var PosMenuLine: Record "LSC POS Menu Line"
    )
    var
        orderNo: Code[20];
    begin
        if (PosMenuLine.Command = 'LOGOFF') OR (PosMenuLine."Post Command" = 'LOGOFF') then
            POSSESSION.SetValue('#_CHANGESTORE', '');

        /*if (PosMenuLine.Command = 'CANCEL2') then begin
            orderNo := PosMenuLine.Parameter;
            PageDeliveryTakeOrder.PROCESSPOS('F0200000000000002247');
        end;*/

    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnAfterSelectCustomer', '', true, true)]
    local procedure "LSC POS Transaction Events_OnAfterSelectCustomer"
         (
             var POSTransaction: Record "LSC POS Transaction";
             var POSTransLine: Record "LSC POS Trans. Line";
             var CurrInput: Text
         )
    var
        Cust: Record Customer;
        Member: Record "LSC Membership Card";
        AccMember: Record "LSC Member Account";
        Lpo: Record "LSC POS Menu Line";
        PosTransL2: Record "LSC POS Trans. Line";
        Cont: Integer;
        RetailSetup_l: Record "LSC Retail Setup";
    begin
        RetailSetup_l.Get();
        if RetailSetup_l."FSN Is Local Receipt" and (RetailSetup_l."FSN Last Slipt No." <> '') then begin
            if POSTransaction."Member Card No." <> '' then
                if Member.Get(POSTransaction."Customer No.") then begin
                    AccMember.Reset();
                    if AccMember.Get(Member."Account No.") then begin
                        if AccMember."Linked To Customer No." <> POSTransaction."Customer No." then begin
                            POSTransaction."Member Card No." := '';
                            POSTransaction.Modify();
                            Commit();
                        end;
                    end;
                end else begin
                    POSTransaction."Member Card No." := '';
                    POSTransaction.Modify();
                    Commit();
                end;

            PosTransL2.Reset();
            PosTransL2.SetRange("Receipt No.", POSTransaction."Receipt No.");
            PosTransL2.SetRange("Entry Type", PosTransL2."Entry Type"::FreeText);
            PosTransL2.SetRange("Text Type", PosTransL2."Text Type"::"Cust. Text");
            if PosTransL2.Find('-') then begin
                repeat
                    if PosTransL2."Card/Customer/Coup.Item No" = POSTransaction."Customer No." then begin
                        if (PosTransL2."Entry Status" = PosTransL2."Entry Status"::Voided) then begin
                            PosTransL2.Delete();
                            Commit();
                        end;
                        cont := 0;
                        if Cont <> 1 then begin
                            if Cust.Get(PosTransL2."Card/Customer/Coup.Item No") then begin
                                PosTransL2.Description := CopyStr(PosTransL2.Description + ' ' + '(' + Cust."Customer Disc. Group" + ')', 1, 100);
                                PosTransL2.Modify();
                                Commit();
                                Cont := 1;
                            end;
                        end;
                    end else begin
                        PosTransL2.Delete();
                    end;
                until PosTransL2.Next() = 0;
            end;

            POSTransLine.Reset();
            POSTransLine.SetRange("Receipt No.", POSTransaction."Receipt No.");
            POSTransLine.SetRange("Entry Type", POSTransLine."Entry Type"::FreeText);
            POSTransLine.SetRange("Text Type", POSTransLine."Text Type"::"Member Text");
            if POSTransLine.Find('-') then begin
                repeat
                    if POSTransLine."Card/Customer/Coup.Item No" <> '' then
                        if (POSTransLine."Card/Customer/Coup.Item No" <> POSTransaction."Customer No.") then begin
                            POSTransLine.Delete();
                            Commit();
                        end;
                until POSTransLine.Next() = 0;
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
        RetailSetup_l: Record "LSC Retail Setup";
        POSTrans: Record "LSC POS Transaction";
        Suggest: Integer;
        JsonObj: JsonObject;
        JsonArray: JsonArray;
        JsonToken: JsonToken;
        JsonItem: JsonObject;
    begin
        if RequestID = 'SENPQC807' then begin
            IF pDelOrder.Get(XMLRequest) THEN begin
                if POSTrans.Get(XMLRequest) then begin
                    SedFormulario(pDelOrder, POSTrans);
                end;
            end;
        end;

        //consulta de sala sugerida de prefactura BC
        if RequestID = 'SALE-PREFCONSULT' then begin
            if Evaluate(Suggest, XMLRequest) then
                XMLResponse := TakeOrder.GetStoreLinksSuggest(Suggest);
        end;

        if RequestID = 'CREATEORDER' then begin
            if LeerJsonEjemplo(XMLRequest) then begin
                XMLResponse := 'OK';
            end;
        end;
    end;

    procedure LeerJsonEjemplo(JsonText: Text): Boolean
    var
        JsonObj, Json : JsonObject;
        ProductosArray: JsonArray;
        ProductoToken, JToken : JsonToken;
        ProductoObj: JsonObject;
        i: Integer;
        StoreNo: Text;
        Terminal: Text;
        TransactionNo: Integer;
        ItemNo: Text;
        UnitOfMesurie: Text;
        Quantity: Integer;
        TransactionHeader: Record "LSC Transaction Header";
    begin
        if not Json.ReadFrom(JsonText) then
            Error('JSON inválido');

        if Json.SelectToken('order', JToken) then
            JsonObj := JToken.AsObject()
        else
            exit(false);
        // Leer campos principales
        if JsonObj.SelectToken('StoreNo', JToken) then
            if not JToken.AsValue().IsNull then
                StoreNo := JToken.AsValue().AsText();

        if JsonObj.SelectToken('Terminal', JToken) then
            if not JToken.AsValue().IsNull then
                Terminal := JToken.AsValue().AsText();

        if JsonObj.SelectToken('TransactionNo', JToken) then
            if not JToken.AsValue().IsNull then
                TransactionNo := JToken.AsValue().AsInteger();

        if TransactionHeader.Get(StoreNo, Terminal, TransactionNo) then;

        if JsonObj.SelectToken('Productos', JToken) then
            ProductosArray := (jToken.AsArray());

        if ProductosArray.Count = 0 then
            exit;
        // Leer array de productos
        foreach ProductoToken in ProductosArray do begin
            ProductoObj := ProductoToken.AsObject();

            if ProductoObj.SelectToken('ItemNo', JToken) then
                if not JToken.AsValue().IsNull then
                    ItemNo := JToken.AsValue().AsText();

            if ProductoObj.SelectToken('UnitOfMesurie', JToken) then
                if not JToken.AsValue().IsNull then
                    UnitOfMesurie := JToken.AsValue().AsText();

            if ProductoObj.SelectToken('Quantity', JToken) then
                if not JToken.AsValue().IsNull then
                    Quantity := Abs(JToken.AsValue().AsInteger());

            // Aquí puedes usar los valores como necesites
            insertItems(ItemNo, UnitOfMesurie, Quantity, TransactionHeader);
        end;
        exit(true);
    end;


    local procedure insertItems(ItemNo: Text; UnitOfMesurie: Text; Quantity: Integer; TransactionHeader: Record "LSC Transaction Header")//AC15837P
    var
        transLine: Record "LSC POS Trans. Line";
        barcode: Record "LSC Barcodes";
        jToken: JsonToken;
        jItemObj: JsonObject;
        jItemTkn: JsonToken;
        lineNo: Integer;
        value: Text;
        DeliveryOrder: Record "LSC Delivery Order";
        posTrans: Record "LSC POS Transaction";
        Item: Record Item;
        DT: Record "LSC POS Trans. Per. Disc. Type";
        OfferPosCalc: Record "LSC Offer Pos Calculation";
        PosPriceUtil: Codeunit "LSC POS Price Utility";
        PosFunc: Codeunit "LSC POS Functions";
    begin
        if DeliveryOrder.Get(POSSESSION.GetValue('CURRORDER')) THEN begin
            DeliveryOrder."External Order No." := TransactionHeader."Receipt No.";
            DeliveryOrder.Modify(true);
        end else begin
            CreateNewOrder(TransactionHeader);
            if DeliveryOrder.Get(POSSESSION.GetValue('CURRORDER')) THEN begin
                DeliveryOrder."External Order No." := TransactionHeader."Receipt No.";
                DeliveryOrder.Modify(true);
            end;
        end;
        if posTrans.Get(DeliveryOrder."Order No.") then begin
            lineNo := getLine(posTrans, 'new');
            //? basic line data
            transLine.Init();
            transLine.Validate("Receipt No.", posTrans."Receipt No.");
            transLine.Validate("Store No.", posTrans."Store No.");
            transLine.Validate("POS Terminal No.", posTrans."POS Terminal No.");
            transLine.Validate("Line No.", lineNo);
            transLine.Validate("Parent Line", lineNo);
            transLine.Validate("Sales Staff", posTrans."Sales Staff");
            transLine.Validate("Entry Type", transLine."Entry Type"::Item);
            transLine.Validate("Created by Staff ID", posTrans."Staff ID");
            transLine."Sales Type" := posTrans."Sales Type";

            //? set unit of measure code
            transLine.Validate("Unit of Measure", UnitOfMesurie);
            //? set item no.
            Item.Reset();
            Item.SETRANGE("No.", ItemNo);
            if Item.FindFirst() then begin
                barcode.SetRange("Item No.", Item."No.");
                if barcode.FindFirst() then
                    transLine.validate("Barcode No.", barcode."Barcode No.");
                POSFunc.PosTransDiscLoadData(posTrans."Receipt No.", true);
                transLine.Validate(Number, ItemNo);
                transLine.Validate(Quantity, 0);
                transLine."Entry Status" := 0;
                transLine."Discount %" := 0;
                transLine."Discount Amount" := 0;
                transLine."Disc. Info Line No." := 0;
                transLine."Discount Triggered" := false;
                transLine."Quantity Discounted" := 0;
                PosPriceUtil.InsertTransDiscPercent(transLine, 0, DT.DiscType::"Periodic Disc.".AsInteger(), '');
                transLine."Promotion No." := '';
                transLine."Mix & Match Line No." := 0;
                PosPriceUtil.InsertTransDiscAmount(transLine, 0, DT.DiscType::"Periodic Disc.".AsInteger(), '');
                Clear(OfferPosCalc);
                OfferPosCalc.SetRange("Receipt No.", transLine."Receipt No.");
                OfferPosCalc.SetRange("Trans. Line No.", transLine."Line No.");
                OfferPosCalc.DeleteAll;
                PosFunc.ClearPosTransLineOffers(transLine);
                PosPriceUtil.CalcPrice(transLine, true);
                if transLine.Insert(true) then;
                transLine.Validate("Quantity", Quantity);
                if transLine.Modify(true) then;
            end;
        end;
    end;

    local procedure CreateNewOrder(TransactionHeader: Record "LSC Transaction Header")
    var
        myInt: Integer;
        EPosCtrl: Codeunit "LSC POS Control Interface";
        POSMenuLine: Record "LSC POS Menu Line";
    begin

        POSSESSION.SetValue('PHONEORDER', TransactionHeader."Sell-to Contact No.");
        InsetN(TransactionHeader);
        EPosCtrl.HidePanel(POSSESSION.DelOpenOrdersPanelID(), true);
        Clear(DeliveryOrderTemp);
        DeliveryOrderTemp.Reset();
        if DeliveryOrderTemp.Get(POSSESSION.GetValue('CURRORDER')) THEN;
        PageDeliveryTakeOrder.SetPosmenuLine(POSMenuLine);
        PageDeliveryTakeOrder.SETGLOBALVALUE(DeliveryOrderTemp);
        PageDeliveryTakeOrder.RUN;
    end;

    procedure NewOrder(Restaurante: Code[10]; DeliveryOrderType: Option Home,Work,Other,Takeout)
    var
        myInt: Integer;
        POSMenuLineV: Record "LSC POS Menu Line";
        DelPanelUtility: Codeunit "LSC Del. POS Panel Utilities";
        DelContTEMP: Record Contact;

    begin
        if Restaurante = '' then
            Restaurante := 'F20';
        if POSSESSION.GetValue('PHONEORDER') <> '' then begin
            if DelContTEMP.get(POSSESSION.GetValue('PHONEORDER')) then BEGIN
                DelContTEMP."LSC Next Order Date" := Today;
                DelContTEMP."LSC Next Order Time" := Time;
                DelContTEMP."LSC Pre-Order Print DateTime" := 0DT;
                DelContTEMP."LSC Next Order Selection" := DeliveryOrderType;
                if DelContTEMP."LSC Next Order Restaurant" = '' then
                    DelContTEMP."LSC Next Order Restaurant" := Restaurante;
                DelContTEMP.Modify();
                Commit();
                //UpdateAddress(DeliveryOrderType);
            END;
        end;
    end;

    local procedure InsetN(TransactionHeader: Record "LSC Transaction Header")
    var
        myInt: Integer;
        DelContacAddress: Record "LSC Delivery Contact Address";
        DelContTEMP: Record Contact;
        Globals: Record "LSC Delivery Order";
    begin
        DelContacAddress.Reset();
        DelContacAddress.SetRange("Phone No.", POSSESSION.GetValue('PHONEORDER'));
        if DelContacAddress.FindFirst() then
            AfterClosingOrderTakeNew(POSSESSION.GetValue('PHONEORDER'), DelContacAddress."Restaurant No.", Globals);
        //Cargar datos a variables 
        NewOrder(TransactionHeader."Store No.", DelContacAddress."Address Type");
        if DelContTEMP.get(POSSESSION.GetValue('PHONEORDER')) then begin
            POSSESSION.SetValue('DEL-PickupDate', Format(Today));
            POSSESSION.SetValue('DEL-PickupTime', Format(Time));
        end;
    end;

    procedure AfterClosingOrderTakeNew(PhoneNoT: Code[30]; RestaurantNo: Code[10]; var DOrder: Record "LSC Delivery Order")
    var
        LastSlipNo: Code[20];
        OrderNo: Code[20];
        TransHdr: Record "LSC Transaction Header";
        PosTrans: Record "LSC POS Transaction";
        LocalStore: Record "LSC Store";
        CallCenterPOSTermAssignm: Record "LSC CC POS Term. Assignm.";
        Text089: Label 'No se encontró ninguna entrada en la tabla %1 para el centro de llamadas %2 y el restaurante %3';
        Text085: Label 'Se debe dedicar un %1 para el centro de llamadas %2 y el restaurante %3 en la tabla %4';
        Text090: Label 'Ocurrió un error al insertar en la tabla %1. Intentar otra vez.';
        DelOrder: Record "LSC Delivery Order";
        PosTerminal: Record "LSC POS Terminal";
        PosFunc: Codeunit "LSC POS Functions";
        SalesType: Integer;
        SalesTypes: Record "LSC Sales Type";
        POSTransaction: Record "LSC POS Transaction";
        OrderDateTime: DateTime;
        errorText: Text;
        POSMenuLineTemp: Record "LSC POS Menu Line";
        HosPosStartup: Codeunit "LSC Hospitality POS Startup";
        RetailSetup_l: Record "LSC Retail Setup";
        NoSeriesMgt: Codeunit NoSeriesManagement;
        DeliveryContAddress: Record "LSC Delivery Contact Address";
        DelOrdManagement: Codeunit "LSC Delivery Order Management";
        DelContTEMP: Record Contact;
        DStreet: Record "LSC Delivery Street";
        PosInfocode: Record "LSC POS Trans. Infocode Entry";
    begin
        IF RestaurantNo = '' then
            RestaurantNo := 'F20';
        if DelContTEMP.get(PhoneNoT) then;
        SalesType := 1;
        LocalStore.Get('F20');
        PosTerminal.Get(POSSESSION.TerminalNo);
        DelContTEMP."LSC Next Order Selection" := DelContTEMP."LSC Next Order Selection"::"Delivery Home";
        DelContTEMP."LSC Next Order Date" := Today;
        DelContTEMP."LSC Next Order Time" := Time;
        DelContTEMP."LSC Next Order Restaurant" := RestaurantNo;
        DelContTEMP.Modify();
        Commit();

        if LocalStore."No." <> RestaurantNo then begin  // order is made in call center, need to change store and pos terminal
            if not CallCenterPOSTermAssignm.Get(LocalStore."No.", RestaurantNo) then begin
                Message(StrSubstNo(Text089, CallCenterPOSTermAssignm.TableCaption, LocalStore."No.", RestaurantNo));
                exit;
            end;

            if CallCenterPOSTermAssignm."Rest. POS Terminal" = '' then begin
                Message(
                  StrSubstNo(
                    Text085, PosTerminal.TableCaption, LocalStore."No.", RestaurantNo, CallCenterPOSTermAssignm.TableCaption));
                exit;
            end;

            POSSESSION.SetTempStoreTerminal(RestaurantNo, CallCenterPOSTermAssignm."Rest. POS Terminal", DOrder."Sales Type");
        end;

        RetailSetup_l.Get();
        if RetailSetup_l."FSN Is Local Receipt" and (RetailSetup_l."FSN Last Slipt No." <> '') then begin
            //LastSlipNo := NoSeriesMgt.GetNextNo('CALLCERIE', Today, true);
            //RetailSetup_l."FSN Last Slipt No." := LastSlipNo;
            //RetailSetup_l.Modify();
        end;

        DOrder.Validate("Order Type Option", SalesType);

        PosFunc.ReadLocalVar(LastSlipNo);

        OrderNo := PosFunc.InsertTmpTrans(LastSlipNo, '', DelOrder."Sales Type", 0, false, '');
        PosTrans.Get(OrderNo);

        Commit;

        //OrderNo := PosFunc.InsertTmpTrans(LastSlipNo, '', DelOrder."Sales Type", 0, false, '');
        //OrderNo := InsertTmpTrans(LastSlipNo, '', DOrder."Sales Type", 0, false, '');
        //PosTrans.Get(OrderNo);
        POSSESSION.SetValue('CURRORDER', OrderNo);
        //Commit;

        if not DelOrdManagement.UpdateOrder(OrderNo, DelContTEMP, true, true, true) then begin
            POSSESSION.SetTempStoreTerminal('', '', DOrder."Sales Type");
            Message(StrSubstNo(Text090, DOrder.TableCaption));
            exit;
        end else begin
            if SalesTypes.Get(DOrder."Sales Type") then begin
                IF POSTransaction.Get(POSSESSION.GetValue('CURRORDER')) THEN BEGIN
                    POSTransaction."New Transaction" := false;
                    POSTransaction."Transaction Type" := POSTransaction."Transaction Type"::Sales;
                    POSTransaction."Trans. Date" := Today;
                    POSTransaction."Original Date" := Today;
                    POSTransaction."Trans Time" := Time;
                    IansertNewLinePosTransLine(POSTransaction);
                    if SalesTypes."VAT Bus. Posting Group" <> '' then
                        POSTransaction."VAT Bus.Posting Group" := SalesTypes."VAT Bus. Posting Group";
                    if SalesTypes."Price Group" <> '' then
                        POSTransaction."Price Group Code" := SalesTypes."Price Group";
                    POSTransaction."Sales Type" := SalesTypes.Code;
                    POSTransaction.Modify(true);
                    Commit();
                END;
            end;
        end;

        DOrder.Reset();
        IF DOrder.Get(POSSESSION.GetValue('CURRORDER')) then begin
            if DeliveryContAddress.Get(DOrder."Phone No.", DeliveryContAddress."Address Type"::Home) then begin
                DOrder.Validate("Order Type Option", SalesType);
                DOrder."Order Date" := Today;
                DOrder."Contact Pickup Time" := time;
                DOrder.Address := '1' + ' ' + DeliveryContAddress."Street Name";
                DOrder."Address 2" := DeliveryContAddress."Address 2";
                DOrder.City := DeliveryContAddress.City;
                DOrder."Created at Call Center" := 'F20';
                IF DOrder."Restaurant No." = '' THEN
                    DOrder."Restaurant No." := 'F20';
                if DOrder."Contact Pickup Time" = 0T THEN
                    DOrder."Contact Pickup Time" := time;
                IF DOrder."Order Date" = 0D THEN
                    DOrder."Order Date" := Today;
                DOrder."Post Code" := DeliveryContAddress."Post Code";
                DOrder.Directions := DeliveryContAddress.Directions;
                DOrder."FSN Directions" := DeliveryContAddress."FSN Direction";
                DOrder."Grid Code" := DeliveryContAddress."Grid Code";
                DOrder."Sales Type" := SalesTypes.Code;
                DStreet.Reset();
                DStreet.SetRange("Street Name", DeliveryContAddress."Street Name");
                if DStreet.FindFirst() then
                    DOrder."FSN Alter Key" := DStreet."FSN Alter Key";
                DOrder."FSN Street Name" := DeliveryContAddress."Street Name";
                DOrder.Modify();
                Commit();
            end;

            PosInfocode.Init;
            PosInfocode."Receipt No." := PosTrans."Receipt No.";
            PosInfocode."Transaction Type" := 0;
            PosInfocode."Line No." := 1;
            PosInfocode.Infocode := 'DNAME';
            PosInfocode.Information := DOrder.Name;
            PosInfocode."Store No." := PosTrans."Store No.";
            PosInfocode.Date := Today();
            PosInfocode.Time := Time();
            PosInfocode."POS Terminal No." := POSSESSION.TerminalNo;
            PosInfocode."Staff ID" := DOrder."Order Taker";
            if not PosInfocode.Insert(true) then
                PosInfocode.Modify(true);

            if DOrder.Address <> '' then begin
                PosInfocode.Infocode := 'DADDRESS';
                PosInfocode."Line No." := 2;
                PosInfocode.Information := DOrder.Address;
                if not PosInfocode.Insert(true) then
                    PosInfocode.Modify(true);
            end;

            if DOrder."Address 2" <> '' then begin
                PosInfocode.Infocode := 'DADDRESS2';
                PosInfocode."Line No." := 3;
                PosInfocode.Information := DOrder."Address 2";
                if not PosInfocode.Insert(true) then
                    PosInfocode.Modify(true);
            end;

            Commit;

            if DOrder.City <> '' then begin
                PosInfocode.Infocode := 'DCITYZIP';
                PosInfocode."Line No." := 4;
                PosInfocode.Information := DOrder.City + ' ' + DOrder."Post Code";
                if not PosInfocode.Insert(true) then
                    PosInfocode.Modify(true);
            end;

            if DOrder."Grid Code" <> '' then begin
                PosInfocode.Infocode := 'DGRID';
                PosInfocode."Line No." := 5;
                PosInfocode.Information := DOrder."Grid Code";
                if not PosInfocode.Insert(true) then
                    PosInfocode.Modify(true);
            end;

            if DOrder.Directions <> '' then begin
                PosInfocode.Infocode := 'DDIRECTION';
                PosInfocode."Line No." := 6;
                PosInfocode.Information := DOrder.Directions;
                if not PosInfocode.Insert(true) then
                    PosInfocode.Modify(true);
            end;
        end;


        if not DOrder.Get(OrderNo) then begin
            Message(StrSubstNo(Text090, DOrder.TableCaption));
            exit;
        end;
    end;

    procedure IansertNewLinePosTransLine(LscPosTransaction: Record "LSC POS Transaction")
    var
        myInt: Integer;
        InsertPOSTransLine: Record "LSC POS Trans. Line";
    begin
        InsertPOSTransLine.reset;
        InsertPOSTransLine.SetRange(InsertPOSTransLine."Store No.", LscPosTransaction."Store No.");
        InsertPOSTransLine.SetRange(InsertPOSTransLine."POS Terminal No.", LscPosTransaction."POS Terminal No.");
        InsertPOSTransLine.SetRange(InsertPOSTransLine."Receipt No.", LscPosTransaction."Receipt No.");
        InsertPOSTransLine.SetRange(InsertPOSTransLine."Line No.", 1);
        IF not InsertPOSTransLine.FindFirst() THEN BEGIN
            InsertPOSTransLine.Init();
            InsertPOSTransLine."Store No." := LscPosTransaction."Store No.";
            InsertPOSTransLine."POS Terminal No." := LscPosTransaction."POS Terminal No.";
            InsertPOSTransLine."Receipt No." := LscPosTransaction."Receipt No.";
            InsertPOSTransLine."Line No." := 1;
            InsertPOSTransLine."Entry Type" := InsertPOSTransLine."Entry Type"::FreeText;
            InsertPOSTransLine.Description := 'CallCenter';
            InsertPOSTransLine.INSERT(True);
        END;
    end;

    local procedure getLine(transaction: Record "LSC POS Transaction"; type: text): Integer
    var
        transLine: Record "LSC POS Trans. Line";
    begin
        transLine.SetCurrentKey("Receipt No.", "Line No.");
        transLine.SetRange("Receipt No.", transaction."Receipt No.");
        case type of
            'new':
                begin
                    if transLine.FindLast() then
                        exit(transLine."Line No." + 10000)
                    else
                        exit(10000);
                end;
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnBeforeTotalExecuted', '', false, false)]
    local procedure OnBeforeTotalExecuted(var POSTransaction: Record "LSC POS Transaction"; var IsHandled: Boolean);
    var
        store: Record "LSC Store";
        input: Text;
        storelink: Record "FSN Store Link";
        destinationStreet: Record "LSC Delivery Street";
        deliveryOrder: Record "LSC Delivery Order";
        defaultSetting, storeSetting : Record "FSN FASANI Setup";
        posTransCode: CodeUnit "LSC POS Transaction";
        distance, distance2 : Decimal;
        DelOrder: Record "LSC Delivery Order";
        Parameter: Record "FSN Parameter";
    begin

        IF NOT Parameter.Get('COBRO', 'COTIGENCIA') then
            if (DelOrder.Get(POSTransaction."Receipt No.")) then begin
                if (DelOrder."External Order No." = '') and not (DelOrder."Order Type Option" = 4) then
                    ValidateCostDelivery(POSTransaction);
            end;

        Parameter.Reset();
        parameter.SetRange("Grupo", 'DISTAN');
        parameter.SetRange(Codigo, 'COBRO');
        if parameter.FindFirst() and (parameter.Activo) then begin
            store.Get(POSTransaction."Store No.");
            if store."Menu Profile" <> '#FSN-CC' then
                exit;

            DelOrder.Reset();

            if (DelOrder.Get(POSTransaction."Receipt No.")) and (DelOrder."External Order No." = '') and not (DelOrder."Order Type Option" = 4) then begin
                //? extraer ubicaciones
                storelink.SetRange("Parent Code", store."No.");
                storeLink.SetRange(Type, storeLink.Type::StoreSetup);
                if storelink.FindFirst() then;

                deliveryOrder.SetRange("Order No.", POSTransaction."Receipt No.");
                if deliveryOrder.FindFirst() then;

                destinationStreet.SetRange("FSN Alter Key", deliveryOrder."FSN Alter Key");
                if destinationStreet.FindFirst() then;

                distance := getDistance(storelink."Parent Latitude", storelink."Parent Longitude", destinationStreet."FSN Latitude", destinationStreet."FSN Longitude");
                distance2 := GetDistanceGeopraphic(storelink."Parent Latitude", storelink."Parent Longitude", destinationStreet."FSN Latitude", destinationStreet."FSN Longitude");

                if defaultSetting.Get('') then;
                if storeSetting.Get(store."No.") then;

                removePreviusDelivery(POSTransaction, defaultSetting, storeSetting);

                if (distance <= 8.00) then begin
                    POSTransaction.CalcFields("Gross Amount");
                    if POSTransaction."Gross Amount" <= 9.99 then begin
                        if storeSetting."Delivery < $9.99" <> '' then
                            input := storeSetting."Delivery < $9.99"
                        else
                            input := defaultSetting."Delivery < $9.99";
                    end else
                        if POSTransaction."Gross Amount" <= 39.99 then begin
                            if storeSetting."Delivery < $39.99" <> '' then
                                input := storeSetting."Delivery < $39.99"
                            else
                                input := defaultSetting."Delivery < $39.99";
                        end;
                end else begin
                    if storeSetting."C807 Delivery" <> '' then
                        input := storeSetting."C807 Delivery"
                    else
                        input := defaultSetting."C807 Delivery";
                end;
                posTransCode.setCurrInput(input);
                posTransCode.ItemNoPressed();
            end;
        end;
    end;

    procedure ValidateCostDelivery(var POSTransaction: Record "LSC POS Transaction")
    var
        posTransCode: CodeUnit "LSC POS Transaction";
        defaultSetting, storeSetting : Record "FSN FASANI Setup";
        input: Text;
        FSNWebServiceTable: Record "FSN WebServiceTable";
        DelOrder: Record "LSC Delivery Order";
    begin
        //DelOrder."External Order No.";
        IF DelOrder.GET(POSTransaction."Receipt No.") THEN BEGIN
            if FSNWebServiceTable.get(POSTransaction."Receipt No.") then begin
                if FSNWebServiceTable."Store" in ['APP', 'EC'] then
                    exit;
            end else
                if DelOrder."External Order No." <> '' then
                    if FSNWebServiceTable.get(DelOrder."External Order No.") then begin
                        if FSNWebServiceTable."Store" in ['APP', 'EC'] then
                            exit;
                    end;
        END;

        if store.get(POSTransaction."Store No.") then;

        if defaultSetting.Get('') then;
        if storeSetting.Get(store."No.") then;

        VoidCostDeliveryLine(POSTransaction, defaultSetting, storeSetting);

        POSTransaction.CalcFields("Gross Amount");
        /*if POSTransaction."Gross Amount" <= 19.99 then begin
            if storeSetting."Delivery < $19.99" <> '' then begin
                input := storeSetting."Delivery < $19.99";
                ValidateCostDeliveryLine(POSTransaction, input);
            end;
        end;*/

        if (POSTransaction."Gross Amount" >= 10.00) and (POSTransaction."Gross Amount" <= 29.99) then begin
            if storeSetting."Delivery < $29.99" <> '' then begin
                input := storeSetting."Delivery < $29.99";
                ValidateCostDeliveryLine(POSTransaction, input);
            end;
        end;

        if (POSTransaction."Gross Amount" >= 30.00) and (POSTransaction."Gross Amount" <= 39.99) then begin
            if storeSetting."Delivery < $39.99" <> '' then begin
                input := storeSetting."Delivery < $39.99";
                ValidateCostDeliveryLine(POSTransaction, input);
            end;
        end;

        if input <> '' then begin
            posTransCode.setCurrInput(input);
            posTransCode.ItemNoPressed();
        end;
    end;

    procedure ValidateCostDeliveryLine(var POSTransaction: Record "LSC POS Transaction"; var input: Text): boolean
    var
        POSTransLine: Record "LSC POS Trans. Line";
    begin
        POSTransLine.reset;
        POSTransLine.SetRange("Store No.", POSTransaction."Store No.");
        POSTransLine.SetRange("POS Terminal No.", POSTransaction."POS Terminal No.");
        POSTransLine.SetRange("Receipt No.", POSTransaction."Receipt No.");
        POSTransLine.SetRange(POSTransLine."Entry Type", POSTransLine."Entry Type"::Item);
        POSTransLine.SetRange(POSTransLine.Number, input);
        if POSTransLine.Find('-') then
            clear(input);
    end;

    local procedure VoidCostDeliveryLine(POSTrans: Record "LSC POS Transaction"; defaultSetting: Record "FSN Fasani Setup"; storeSetting: Record "FSN Fasani Setup")
    var
        transLine: Record "LSC POS Trans. Line";
        filter: Text;
    begin


        /*if defaultSetting."Delivery < $9.99" <> '' then
            filter := defaultSetting."Delivery < $9.99";

        if storeSetting."Delivery < $9.99" <> '' then
            filter := '|' + storeSetting."Delivery < $9.99";*/

        if defaultSetting."Delivery < $39.99" <> '' then
            filter += '|' + defaultSetting."Delivery < $39.99";

        if storeSetting."Delivery < $39.99" <> '' then
            filter += '|' + storeSetting."Delivery < $39.99";

        /*if defaultSetting."C807 Delivery" <> '' then
            filter += '|' + defaultSetting."C807 Delivery";

        if storeSetting."C807 Delivery" <> '' then
            filter += '|' + storeSetting."C807 Delivery";*/

        if defaultSetting."Delivery < $29.99" <> '' then
            filter += '|' + defaultSetting."Delivery < $29.99";

        if storeSetting."Delivery < $29.99" <> '' then
            filter += '|' + storeSetting."Delivery < $29.99";

        if filter.StartsWith('|') then
            filter := CopyStr(filter, 2);

        if filter = '' then
            exit;

        transLine.SetRange("Store No.", POSTrans."Store No.");
        transLine.SetRange("POS Terminal No.", POSTrans."POS Terminal No.");
        transLine.SetRange("Receipt No.", POSTrans."Receipt No.");
        transLine.SetFilter(Number, filter);
        transLine.DeleteAll();
    end;

    local procedure getDistance(latA: Decimal; lonA: Decimal; latB: Decimal; lonB: Decimal): Decimal
    var
        parameter: Record "FSN Parameter";
        uri, res : Text;
        client: HttpClient;
        request: HttpRequestMessage;
        response: HttpResponseMessage;
        content: HttpContent;
        value: Decimal;
    begin
        parameter.SetRange("Grupo", 'DAF');
        parameter.SetRange(Codigo, 'DAF_KM');
        if parameter.FindFirst() and (parameter.Activo) then begin
            client.Timeout := 10000;
            request.Method := 'GET';
            uri := StrSubstNo('%1Order/CalculateDistance?latitudeA=%2&longitudeA=%3&latitudeB=%4&longitudeB=%5', parameter."Web Uri", latA, lonA, latB, lonB);
            request.SetRequestUri(uri);
            client.Send(request, response);

            content := response.Content;
            if response.IsSuccessStatusCode then begin
                content.ReadAs(res);
                Evaluate(value, res);
                exit(value);
            end else
                Error(StrSubstNo('Error al obtener la distancia \Error: %1', response.HttpStatusCode));
        end;
    end;

    local procedure removePreviusDelivery(POSTrans: Record "LSC POS Transaction"; defaultSetting: Record "FSN Fasani Setup"; storeSetting: Record "FSN Fasani Setup")
    var
        transLine: Record "LSC POS Trans. Line";
        filter: Text;
    begin
        if defaultSetting."Delivery < $9.99" <> '' then
            filter := defaultSetting."Delivery < $9.99";

        if storeSetting."Delivery < $9.99" <> '' then
            filter := '|' + storeSetting."Delivery < $9.99";

        if defaultSetting."Delivery < $39.99" <> '' then
            filter += '|' + defaultSetting."Delivery < $39.99";

        if storeSetting."Delivery < $39.99" <> '' then
            filter += '|' + storeSetting."Delivery < $39.99";

        if defaultSetting."C807 Delivery" <> '' then
            filter += '|' + defaultSetting."C807 Delivery";

        if storeSetting."C807 Delivery" <> '' then
            filter += '|' + storeSetting."C807 Delivery";

        if defaultSetting."Delivery < $29.99" <> '' then
            filter += '|' + defaultSetting."Delivery < $29.99";

        if storeSetting."Delivery < $29.99" <> '' then
            filter += '|' + storeSetting."Delivery < $29.99";

        if filter.StartsWith('|') then
            filter := CopyStr(filter, 2);

        if filter = '' then
            exit;

        transLine.SetRange("Store No.", POSTrans."Store No.");
        transLine.SetRange("POS Terminal No.", POSTrans."POS Terminal No.");
        transLine.SetRange("Receipt No.", POSTrans."Receipt No.");
        transLine.SetFilter(Number, filter);
        transLine.DeleteAll();
    end;

    procedure GetDistanceGeopraphic(lat: Decimal; lon: Decimal; ParentLatitude: Decimal; ParentLongitude: Decimal): Decimal
    var
        pi, dataDiff, _lat, _lon : Decimal;
        math: DotNet MathNet;
    begin
        pi := 3.14159265358979323;

        _lat := (lat - ParentLatitude) * (pi / 180);
        _lon := (lon - ParentLongitude) * (pi / 180);

        lat := lat * (pi / 180);
        ParentLatitude := ParentLatitude * (pi / 180);

        dataDiff := math.Pow(math.Sin(_lat / 2), 2) + math.Cos(lat) * math.Cos(ParentLatitude) * math.Pow(math.Sin(_lon / 2), 2);

        exit(6371 * (2 * math.Atan2(math.Sqrt(dataDiff), math.Sqrt(1 - dataDiff))));
    end;

    // Validación de calendario para confirmación de pedido (usa nueva lógica de temporales/normales)
    procedure ValidateStoreOpenForDeliveryOrder(DelOrder: Record "LSC Delivery Order"; var ErrorText: Text[250]; var DebugMessage: Text[250]): Boolean
    var
        CalendarType: Integer;
        StepText: Text[250];
        RestNo: Code[10];
        TheDate: Date;
        TheTime: Time;
    begin
        Clear(ErrorText);
        Clear(DebugMessage);

        RestNo := DelOrder."Restaurant No.";
        TheDate := DelOrder."Order Date";
        TheTime := DelOrder."Contact Pickup Time";

        if (RestNo = '') or (RestNo = 'F20') then begin
            ErrorText := 'Tienda no asignada';
            DebugMessage := 'No se puede validar: tienda vacía o F20';
            exit(false);
        end;

        // Determinar CalendarType basado en Order Type Option
        CalendarType := GetCalendarTypeForOrderOption(DelOrder."Order Type Option");

        // 1) Cerrado + Include All Week Days = false (LineType=2, CalendarType=1)
        if ValidateClosedCalendarStepForDelivery(1, RestNo, TheDate, TheTime, CalendarType, false, StepText) then begin
            DebugMessage := StepText;
            ErrorText := StrSubstNo('La tienda %1 está cerrada el %2 a las %3 por horario de cierre.', RestNo, Format(TheDate), Format(TheTime));
            exit(false);
        end;

        // 2) Cerrado + Include All Week Days = true (LineType=2, CalendarType=1)
        if ValidateClosedCalendarStepForDelivery(2, RestNo, TheDate, TheTime, CalendarType, true, StepText) then begin
            DebugMessage := StepText;
            ErrorText := StrSubstNo('La tienda %1 está cerrada el %2 a las %3 por horario de cierre.', RestNo, Format(TheDate), Format(TheTime));
            exit(false);
        end;

        // 3) Temporal + Include All Week Days = false
        if ValidateCalendarStepForDelivery(3, 'Temporal', RestNo, TheDate, TheTime, CalendarType, 1, false, true, StepText) then begin
            DebugMessage := StepText;
            exit(true);
        end;

        // 4) Temporal + Include All Week Days = true
        if ValidateCalendarStepForDelivery(4, 'Temporal', RestNo, TheDate, TheTime, CalendarType, 1, true, false, StepText) then begin
            DebugMessage := StepText;
            exit(true);
        end;

        // 5) Normal + Include All Week Days = false
        if ValidateCalendarStepForDelivery(5, 'Normal', RestNo, TheDate, TheTime, CalendarType, 0, false, true, StepText) then begin
            DebugMessage := StepText;
            exit(true);
        end;

        // 6) Normal + Include All Week Days = true
        if ValidateCalendarStepForDelivery(6, 'Normal', RestNo, TheDate, TheTime, CalendarType, 0, true, false, StepText) then begin
            DebugMessage := StepText;
            exit(true);
        end;

        // Si ningún paso pasó, devolver último mensaje de fallo
        DebugMessage := StepText;
        ErrorText := StrSubstNo('La tienda %1 no está abierta el %2 a las %3. Verifique la configuración del calendario.', RestNo, Format(TheDate), Format(TheTime));
        exit(false);
    end;

    local procedure ValidateClosedCalendarStepForDelivery(StepNo: Integer; RestNo: Code[10]; TheDate: Date; TheTime: Time; CalendarType: Integer; IncludeAllWeekDays: Boolean; var DebugText: Text[250]): Boolean
    var
        RCL: Record "LSC Retail Calendar Line";
        InfiniteDate: Date;
        HasLines: Boolean;
        DateOk: Boolean;
        TimeOk: Boolean;
        HasEndDate: Boolean;
        DateRangeText: Text[80];
        TimeRangeText: Text[40];
    begin
        InfiniteDate := DMY2Date(1, 1, 1753);
        HasLines := false;
        Clear(DebugText);

        RCL.Reset();
        RCL.SetCurrentKey("Calendar ID", "Calendar Type", "Line Type", "Include All Week Days", "Starting Date", "Time From");
        RCL.SetRange("Calendar ID", RestNo);
        RCL.SetRange("Calendar Type", CalendarType);
        RCL.SetRange("Line Type", 2);
        RCL.SetRange("Include All Week Days", IncludeAllWeekDays);
        RCL.SetFilter("Starting Date", '<=%1', TheDate);

        if RCL.FindSet() then
            repeat
                HasLines := true;
                HasEndDate := (RCL."Ending Date" <> 0D) and (RCL."Ending Date" <> InfiniteDate);

                if HasEndDate then
                    DateOk := (RCL."Starting Date" <= TheDate) and (TheDate <= RCL."Ending Date")
                else
                    if IncludeAllWeekDays then
                        DateOk := (RCL."Starting Date" <= TheDate)
                    else
                        DateOk := (RCL."Starting Date" = TheDate);

                if DateOk then begin
                    TimeOk := (TheTime >= RCL."Time From") and (TheTime < RCL."Time To");
                    if TimeOk then begin
                        if HasEndDate then
                            DateRangeText := Format(RCL."Starting Date") + ' -> ' + Format(RCL."Ending Date")
                        else
                            if IncludeAllWeekDays then
                                DateRangeText := Format(RCL."Starting Date") + ' -> INFINITO'
                            else
                                DateRangeText := Format(RCL."Starting Date");

                        TimeRangeText := Format(RCL."Time From") + ' - ' + Format(RCL."Time To");
                        DebugText := StrSubstNo('Validación %1 Cerrado CERRADA | Sala %2 | CalendarType=%3 | LineType=2 | IncludeAllWeekDays=%4 | Fecha=%5 | Hora=%6 | Rango=%7', StepNo, RestNo, CalendarType, IncludeAllWeekDays, DateRangeText, Format(TheTime), TimeRangeText);
                        exit(true);
                    end;
                end;
            until RCL.Next() = 0;

        if HasLines then
            DebugText := StrSubstNo('Validación %1 Cerrado OK | Sala %2 | CalendarType=%3 | LineType=2 | IncludeAllWeekDays=%4 | Fecha=%5 | Hora=%6 | No coincide con rango de cierre', StepNo, RestNo, CalendarType, IncludeAllWeekDays, Format(TheDate), Format(TheTime))
        else
            DebugText := StrSubstNo('Validación %1 Cerrado OK | Sala %2 | CalendarType=%3 | LineType=2 | IncludeAllWeekDays=%4 | Fecha=%5 | Hora=%6 | Sin líneas de cierre', StepNo, RestNo, CalendarType, IncludeAllWeekDays, Format(TheDate), Format(TheTime));

        exit(false);
    end;

    local procedure GetCalendarTypeForOrderOption(OrderTypeOption: Integer): Integer
    begin
        // Regla de negocio: Order Type Option 4 = Para llevar = CalendarType 3, resto = Delivery = CalendarType 1
        if OrderTypeOption = 4 then
            exit(3)
        else
            exit(1);
    end;

    local procedure ValidateCalendarStepForDelivery(StepNo: Integer; StepKind: Text[20]; RestNo: Code[10]; TheDate: Date; TheTime: Time; CalendarType: Integer; LineType: Integer; IncludeAllWeekDays: Boolean; ExactDateOnly: Boolean; var DebugText: Text[250]): Boolean
    var
        RCL: Record "LSC Retail Calendar Line";
        InfiniteDate: Date;
        HasLines: Boolean;
        DateOk: Boolean;
        TimeOk: Boolean;
        HasEndDate: Boolean;
        DateRangeText: Text[80];
        TimeRangeText: Text[40];
    begin
        InfiniteDate := DMY2Date(1, 1, 1753);
        HasLines := false;
        Clear(DebugText);

        RCL.Reset();
        RCL.SetCurrentKey("Calendar ID", "Calendar Type", "Line Type", "Include All Week Days", "Starting Date", "Time From");
        RCL.SetRange("Calendar ID", RestNo);
        RCL.SetRange("Calendar Type", CalendarType);
        RCL.SetRange("Line Type", LineType);
        RCL.SetRange("Include All Week Days", IncludeAllWeekDays);
        RCL.SetFilter("Starting Date", '<=%1', TheDate);

        if RCL.FindSet() then
            repeat
                HasLines := true;

                HasEndDate := (RCL."Ending Date" <> 0D) and (RCL."Ending Date" <> InfiniteDate);

                // Aplicar reglas de rango según especificación:
                // 1) Con Ending Date: rango inclusivo [Starting Date..Ending Date]
                // 2) Sin Ending Date + IncludeAllWeekDays=0: solo día exacto de Starting Date
                // 3) Sin Ending Date + IncludeAllWeekDays=1: desde Starting Date infinito
                if HasEndDate then
                    DateOk := (RCL."Starting Date" <= TheDate) and (TheDate <= RCL."Ending Date")
                else
                    if IncludeAllWeekDays then
                        DateOk := (RCL."Starting Date" <= TheDate)
                    else
                        DateOk := (RCL."Starting Date" = TheDate);

                if DateOk then begin
                    TimeOk := (TheTime >= RCL."Time From") and (TheTime < RCL."Time To");
                    if TimeOk then begin
                        if ExactDateOnly then
                            DateRangeText := Format(RCL."Starting Date")
                        else
                            DateRangeText := Format(RCL."Starting Date") + ' -> ' + Format(RCL."Ending Date");

                        TimeRangeText := Format(RCL."Time From") + ' - ' + Format(RCL."Time To");
                        DebugText := StrSubstNo('✓ Validación %1 %2 OK | Sala %3 | CalendarType=%4 | LineType=%5 | IncludeAllWeekDays=%6 | Fecha=%7 | Hora=%8 | Rango=%9', StepNo, StepKind, RestNo, CalendarType, LineType, IncludeAllWeekDays, DateRangeText, Format(TheTime), TimeRangeText);
                        exit(true);
                    end;
                end;
            until RCL.Next() = 0;

        if HasLines then begin
            DebugText := StrSubstNo('✗ Validación %1 %2 FAIL | Sala %3 | CalendarType=%4 | LineType=%5 | IncludeAllWeekDays=%6 | Fecha=%7 | Hora=%8 | Fuera de vigencia', StepNo, StepKind, RestNo, CalendarType, LineType, IncludeAllWeekDays, Format(TheDate), Format(TheTime));
        end else begin
            DebugText := StrSubstNo('✗ Validación %1 %2 FAIL | Sala %3 | CalendarType=%4 | LineType=%5 | IncludeAllWeekDays=%6 | Fecha=%7 | Hora=%8 | Sin líneas configuradas', StepNo, StepKind, RestNo, CalendarType, LineType, IncludeAllWeekDays, Format(TheDate), Format(TheTime));
        end;

        exit(false);
    end;
}